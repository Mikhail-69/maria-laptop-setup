#!/usr/bin/env python3
"""Adapt staged secret checks and file formatting to Codex hook payloads."""
import json
import os
from pathlib import Path
import re
import shlex
import shutil
import subprocess
import sys


def run(args, cwd):
    return subprocess.run(args, cwd=cwd, capture_output=True, text=True, timeout=10)


def check(data):
    tool = data.get("tool_input", {})
    command = tool.get("command", tool.get("cmd", ""))
    # Inspect shell command positions, not arbitrary quoted source text.
    if not re.search(r"(?:^\s*|[;&|]\s*|\$\(\s*)git\s+[^\n]*\bcommit\b", command):
        return 0
    cwd = Path(tool.get("workdir") or data.get("cwd") or os.getcwd())
    try:
        lexer = shlex.shlex(command, posix=True, punctuation_chars=";&|")
        lexer.whitespace_split = True
        parts = list(lexer)
        # Resolve common "cd repo && git commit" and "git -C repo commit" forms.
        if parts[:1] == ["cd"] and len(parts) > 2 and parts[2] == "&&":
            cwd = (cwd / parts[1]).resolve()
            parts = parts[3:]
        start = next(i for i, value in enumerate(parts) if value == "git")
        args = parts[start + 1:]
        while args and args[0] == "-C":
            cwd = (cwd / args[1]).resolve()
            args = args[2:]
        if not args or args[0] != "commit":
            raise ValueError("unsupported git invocation")
        # Earlier shell commands could change the index or repository.
        if start or any(value in parts for value in [";", "||", "|"]) or "&&" in parts:
            raise ValueError("compound commit command")
        if any(value in {"-a", "--all", "-i", "--include", "-o", "--only", "--"}
               or (value.startswith("-") and not value.startswith("--") and "a" in value[1:])
               for value in args[1:]):
            raise ValueError("stage changes separately before committing")
        names = run(["git", "diff", "--cached", "--name-only", "-z"], cwd)
        diff = run(["git", "diff", "--cached", "--no-ext-diff", "--no-textconv"], cwd)
        if names.returncode or diff.returncode:
            raise ValueError("cannot inspect staged changes")
        for name in names.stdout.split("\0"):
            path = Path(name)
            if (path.name == ".env" or path.name.startswith(".env.")
                    or path.name in {".secrets", "id_rsa", "id_ed25519", "credentials", "credentials.json"}
                    or path.suffix == ".pem" or "secrets" in path.parts):
                raise ValueError("staged secret file")
        added = "\n".join(line[1:] for line in diff.stdout.splitlines()
                          if line.startswith("+") and not line.startswith("+++"))
        patterns = [
            r"ghp_[A-Za-z0-9]{20,}|github_pat_[A-Za-z0-9_]{20,}|AKIA[0-9A-Z]{16}",
            r"sk-[A-Za-z0-9_-]{20,}|-----BEGIN [A-Z ]*PRIVATE KEY-----",
            r"xox[baprs]-[A-Za-z0-9-]{10,}|AIza[0-9A-Za-z_-]{35}",
            r"""(?i)(api[_-]?key|secret|passw(or)?d|token)\s*[:=]\s*["'][^"' ]{12,}["']""",
        ]
        if any(re.search(pattern, added) for pattern in patterns):
            raise ValueError("possible credential in staged diff")
        return 0
    except (ValueError, IndexError, StopIteration, OSError, subprocess.TimeoutExpired) as error:
        print(f"Commit blocked: {error}. Inspect staged changes and use a standalone git commit.", file=sys.stderr)
        return 2


def format_files(data):
    tool = data.get("tool_input", {})
    patch = tool.get("command", tool.get("patch", ""))
    names = re.findall(r"^\*\*\* (?:Add File|Update File|Move to): (.+)$", patch, re.MULTILINE)
    if tool.get("file_path"):
        names.append(tool["file_path"])
    cwd = Path(data.get("cwd") or os.getcwd()).resolve()
    for name in dict.fromkeys(names):
        path = (cwd / name).resolve()
        # Do not format paths outside the hook working directory or credentials.
        if not path.is_relative_to(cwd) or not path.is_file():
            continue
        if any(part in {"secrets", ".ssh", ".aws"} for part in path.parts) or path.name.startswith(".env"):
            continue
        args = None
        if path.suffix in {".js", ".jsx", ".ts", ".tsx", ".json", ".css", ".scss", ".html", ".md", ".yaml", ".yml"}:
            binary = next((parent / "node_modules/.bin/prettier" for parent in path.parents
                           if os.access(parent / "node_modules/.bin/prettier", os.X_OK)), None)
            binary = binary or shutil.which("prettier")
            if binary:
                args = [str(binary), "--write", str(path)]
        else:
            formatter = {".py": ("ruff", "format"), ".go": ("gofmt", "-w"),
                         ".rs": ("rustfmt",)}.get(path.suffix)
            if formatter and shutil.which(formatter[0]):
                args = [*formatter, str(path)]
        if args:
            try:
                result = run(args, cwd)
                if result.returncode:
                    print(f"Formatter failed for {path.name}; run the project formatter.", file=sys.stderr)
            except (OSError, subprocess.TimeoutExpired):
                print(f"Formatter unavailable for {path.name}.", file=sys.stderr)
    return 0


if __name__ == "__main__":
    payload = json.load(sys.stdin)
    sys.exit(check(payload) if sys.argv[1] == "check" else format_files(payload))
