#!/usr/bin/env bash
# PreToolUse (Bash): before `git commit`, scan staged diff for secrets. Exit 2 blocks the call.
cmd=$(jq -r '.tool_input.command // empty' 2>/dev/null)
echo "$cmd" | grep -Eq '(^|[;&|[:space:]])git[[:space:]]+(-C[[:space:]]+[^[:space:]]+[[:space:]]+)?commit' || exit 0
diff=$(git diff --cached 2>/dev/null) || exit 0
files=$(git diff --cached --name-only 2>/dev/null)
hits=""
echo "$files" | grep -Eq '(^|/)(\.env(\..*)?|id_rsa|id_ed25519|.*\.pem|credentials(\.json)?|\.secrets)$' && hits="staged file looks like a secret file"
added=$(echo "$diff" | grep -E '^\+[^+]')
echo "$added" | grep -Eq 'ghp_[A-Za-z0-9]{20,}|github_pat_[A-Za-z0-9_]{20,}|AKIA[0-9A-Z]{16}|sk-[A-Za-z0-9_-]{20,}|-----BEGIN [A-Z ]*PRIVATE KEY-----|xox[baprs]-[A-Za-z0-9-]{10,}|AIza[0-9A-Za-z_-]{35}' && hits="${hits:+$hits; }token/private key pattern in staged diff"
echo "$added" | grep -Eiq '(api[_-]?key|secret|passw(or)?d|token)[[:space:]]*[:=][[:space:]]*["'\''][^"'\'' ]{12,}["'\'']' && hits="${hits:+$hits; }hardcoded credential assignment in staged diff"
if [ -n "$hits" ]; then
  echo "Commit blocked: possible secret ($hits). Review 'git diff --cached', unstage, and warn the user." >&2
  exit 2
fi
exit 0
