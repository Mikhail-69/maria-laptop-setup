#!/usr/bin/env bash
# Stage 03: AI tooling (CLI + desktop) and the global configs that go with it.
# Nothing is signed in here: install only.

source "$(dirname "${BASH_SOURCE[0]}")/lib/common.sh"

stage_start "03 ai: claude, codex, opencode"

if is_done 03 && [[ "${FORCE:-0}" != "1" ]]; then
    ok "stage 03 already done (FORCE=1 to rerun)"
    exit 0
fi

require_sudo

section "claude code (cli)"
if command -v claude >/dev/null 2>&1 && ! is_dry; then
    ok "claude already installed ($(claude --version 2>/dev/null | head -1))"
else
    run_sh 'curl -fsSL https://claude.ai/install.sh | bash'
fi

section "codex (cli)"
if command -v codex >/dev/null 2>&1 && ! is_dry; then
    ok "codex already installed"
else
    run_sh 'curl -fsSL https://chatgpt.com/codex/install.sh | CODEX_NON_INTERACTIVE=true sh'
fi

section "opencode (cli)"
if command -v opencode >/dev/null 2>&1 && ! is_dry; then
    ok "opencode already installed"
else
    run_sh 'curl -fsSL https://opencode.ai/install | bash'
fi

section "claude desktop"
install_deb_from_repo \
    "https://downloads.claude.ai/claude-desktop/apt/stable/dists/stable/main/binary-amd64/Packages" \
    claude-desktop

section "codex desktop (chatgpt app)"
install_deb_from_repo \
    "https://persistent.oaistatic.com/codex-app-prod/linux/deb/dists/stable/main/binary-amd64/Packages" \
    chatgpt

section "claude config: CLAUDE.md, settings, hooks, skills"
render_template "$REPO_DIR/ai/claude/CLAUDE.md" "$HOME/.claude/CLAUDE.md"
render_template "$REPO_DIR/ai/claude/settings.json" "$HOME/.claude/settings.json"
for hook in "$REPO_DIR"/ai/claude/hooks/*.sh; do
    render_template "$hook" "$HOME/.claude/hooks/$(basename "$hook")"
    chmod +x "$HOME/.claude/hooks/$(basename "$hook")" 2>/dev/null || true
done
if is_dry; then
    printf '+ copy skills -> ~/.claude/skills\n'
else
    mkdir -p "$HOME/.claude/skills"
    cp -a "$REPO_DIR"/ai/skills/. "$HOME/.claude/skills/"
    ok "claude skills installed: $(find "$HOME/.claude/skills" -maxdepth 1 -mindepth 1 -type d | wc -l)"
fi

section "codex config: AGENTS.md, config.toml, hooks, rules, skills"
render_template "$REPO_DIR/ai/codex/AGENTS.md" "$HOME/.codex/AGENTS.md"
render_template "$REPO_DIR/ai/codex/config.toml" "$HOME/.codex/config.toml"
render_template "$REPO_DIR/ai/codex/hooks.json" "$HOME/.codex/hooks.json"
render_template "$REPO_DIR/ai/codex/rules/ssh.rules" "$HOME/.codex/rules/ssh.rules"
if is_dry; then
    printf '+ copy codex hooks and skills\n'
else
    mkdir -p "$HOME/.codex/hooks" "$HOME/.codex/skills"
    sed -e "s|/home/mikhail|$HOME|g" "$REPO_DIR/ai/codex/hooks/workflow.py" > "$HOME/.codex/hooks/workflow.py"
    cp -a "$REPO_DIR"/ai/codex/skills/. "$HOME/.codex/skills/" 2>/dev/null || true
    ok "codex config installed"
fi

section "opencode config: AGENTS.md, opencode.jsonc, commands, plugins, skills"
render_template "$REPO_DIR/ai/opencode/AGENTS.md" "$HOME/.config/opencode/AGENTS.md"
render_template "$REPO_DIR/ai/opencode/opencode.jsonc" "$HOME/.config/opencode/opencode.jsonc"
if is_dry; then
    printf '+ copy opencode commands, plugins and skills\n'
else
    mkdir -p "$HOME/.config/opencode/commands" \
             "$HOME/.config/opencode/plugins" \
             "$HOME/.config/opencode/skills"
    cp -a "$REPO_DIR"/ai/opencode/commands/. "$HOME/.config/opencode/commands/"
    cp -a "$REPO_DIR"/ai/opencode/plugins/. "$HOME/.config/opencode/plugins/"
    # coucou.js stores the absolute path of the coucou hook, so it is templated.
    render_template "$REPO_DIR/ai/opencode/plugins/coucou.js" \
        "$HOME/.config/opencode/plugins/coucou.js"
    cp -a "$REPO_DIR"/ai/skills/. "$HOME/.config/opencode/skills/"
    # Provider keys are referenced as {file:~/.config/opencode/secrets/...}.
    # Create the directory only; keys are never stored in the repository.
    mkdir -p "$HOME/.config/opencode/secrets"
    chmod 700 "$HOME/.config/opencode/secrets"
    ok "opencode config installed"
fi

section "verify paths after install"
for bin in claude codex opencode; do
    if is_dry; then
        continue
    fi
    if command -v "$bin" >/dev/null 2>&1; then
        ok "$bin: $(command -v "$bin")"
    else
        warn "$bin not on PATH yet, open a new terminal (it is installed in ~/.local/bin or ~/.bun/bin)"
    fi
done

mark_done 03
ok "stage 03 finished (nothing signed in, by design)"
