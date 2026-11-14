#!/usr/bin/env bash
# Stage 08: VS Code, the same extensions (minus Flutter/Dart/C#/Kubernetes),
# and the user settings.

source "$(dirname "${BASH_SOURCE[0]}")/lib/common.sh"

stage_start "08 vscode: editor, extensions, settings"

if is_done 08 && [[ "${FORCE:-0}" != "1" ]]; then
    ok "stage 08 already done (FORCE=1 to rerun)"
    exit 0
fi

require_sudo

section "microsoft package repository"
if ! is_dry; then
    $SUDO install -m 0755 -d /etc/apt/keyrings
    curl -fsSL https://packages.microsoft.com/keys/microsoft.asc \
        | $SUDO gpg --dearmor --yes -o /etc/apt/keyrings/microsoft.gpg
    $SUDO chmod go+r /etc/apt/keyrings/microsoft.gpg
    printf 'deb [arch=%s signed-by=/etc/apt/keyrings/microsoft.gpg] https://packages.microsoft.com/repos/code stable main\n' \
        "$(dpkg --print-architecture)" \
        | $SUDO tee /etc/apt/sources.list.d/vscode.list >/dev/null
    $SUDO apt-get update -qq || warn "microsoft repository refresh failed"
fi
install_apt code

section "user settings"
settings="$HOME/.config/Code/User/settings.json"
if is_dry; then
    printf '+ write %s\n' "$settings"
else
    mkdir -p "$(dirname "$settings")"
    if [[ -f "$settings" && ! -f "$settings.laptop-setup.bak" ]]; then
        cp "$settings" "$settings.laptop-setup.bak"
    fi
    cp "$REPO_DIR/dotfiles/vscode-settings.json" "$settings"
    ok "settings.json written"
fi

section "extensions"
if is_dry; then
    printf '+ code --install-extension <each id from assets/vscode-extensions.txt>\n'
else
    mapfile -t wanted < <(grep -vE '^\s*(#|$)' "$REPO_DIR/assets/vscode-extensions.txt")
    mapfile -t installed < <(code --list-extensions 2>/dev/null || true)
    failed=()
    for id in "${wanted[@]}"; do
        if printf '%s\n' "${installed[@]}" | grep -qxF "$id"; then
            continue
        fi
        if code --install-extension "$id" --force >/dev/null 2>&1; then
            ok "installed $id"
        else
            failed+=("$id")
        fi
    done
    ok "extensions: ${#wanted[@]} wanted, ${#installed[@]} were present, ${#failed[@]} failed"
    if ((${#failed[@]})); then
        warn "failed: ${failed[*]}"
    fi
fi

mark_done 08
ok "stage 08 finished"
