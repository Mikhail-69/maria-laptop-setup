#!/usr/bin/env bash
# Stage 11: verify what is installed and print what still needs a human.
# This is the real test: it runs on the laptop, not in CI.

source "$(dirname "${BASH_SOURCE[0]}")/lib/common.sh"

stage_start "11 verify"

PASS=0
FAIL=0
TODO=()

check() {
    local label="$1"; shift
    if "$@" >/dev/null 2>&1; then
        printf '  %sok%s   %s\n' "$C_GREEN" "$C_RESET" "$label"
        PASS=$((PASS + 1))
    else
        printf '  %sno%s   %s\n' "$C_RED" "$C_RESET" "$label"
        FAIL=$((FAIL + 1))
    fi
}

have_cmd() { command -v "$1"; }
have_pkg() { dpkg -l "$1" 2>/dev/null | grep -q '^ii'; }
have_snap() { snap list 2>/dev/null | awk 'NR>1{print $1}' | grep -qx "$1"; }
have_path() { [[ -e "$1" ]]; }

section "system"
check "Ubuntu 24.04" bash -c '. /etc/os-release && [[ "$VERSION_ID" == "24.04" ]]'
check "timezone Europe/Moscow" bash -c '[[ "$(timedatectl show -p Timezone --value)" == "Europe/Moscow" ]]'

section "development"
check "git" have_cmd git
check "gh" have_cmd gh
check "VS Code" have_cmd code
check "docker" have_cmd docker
check "docker compose plugin" bash -c 'docker compose version'
check "java" have_cmd java
check "go" have_cmd go
check "uv" have_cmd uv
check "bun" have_cmd bun
check "PyCharm" bash -c 'snap list pycharm-community'
check "thefuck" have_cmd thefuck

section "AI tooling"
check "claude cli" have_cmd claude
check "codex cli" have_cmd codex
check "opencode cli" have_cmd opencode
check "claude desktop" have_pkg claude-desktop
check "codex desktop (chatgpt)" have_pkg chatgpt
check ".claude/CLAUDE.md" have_path "$HOME/.claude/CLAUDE.md"
check ".claude/hooks" have_path "$HOME/.claude/hooks/block-secrets-on-commit.sh"
check ".claude/skills (15)" bash -c '[[ $(find "$HOME/.claude/skills" -maxdepth 1 -mindepth 1 -type d | wc -l) -ge 15 ]]'
check ".codex/AGENTS.md" have_path "$HOME/.codex/AGENTS.md"
check ".codex/hooks/workflow.py" have_path "$HOME/.codex/hooks/workflow.py"
check ".config/opencode/opencode.jsonc" have_path "$HOME/.config/opencode/opencode.jsonc"
check ".config/opencode/plugins/coucou.js" have_path "$HOME/.config/opencode/plugins/coucou.js"

section "applications"
check "google chrome" have_cmd google-chrome
check "discord" bash -c 'command -v discord >/dev/null || dpkg -l discord 2>/dev/null | grep -q "^ii"'
check "spotify" have_pkg spotify-client
check "yandex music" have_pkg yandexmusic
check "zoom" bash -c 'command -v zoom >/dev/null || dpkg -l zoom 2>/dev/null | grep -q "^ii"'
check "mts link" bash -c 'command -v mts-link >/dev/null || dpkg -l mts-link 2>/dev/null | grep -q "^ii"'
check "coucou" have_pkg coucou
check "happ" have_pkg happ
check "flclashx" have_pkg flclashx
check "deepseek desktop" have_snap deepseek-desktop
check "localsend" have_snap localsend
check "notepad++" have_snap notepad-plus-plus
check "draw.io" bash -c 'command -v drawio >/dev/null || dpkg -l drawio 2>/dev/null | grep -q "^ii"'
check "dbeaver" bash -c 'command -v dbeaver >/dev/null || dpkg -l dbeaver-ce 2>/dev/null | grep -q "^ii"'
check "camunda modeler" have_path /opt/camunda-modeler/camunda-modeler
check "vk desktop" have_path /opt/vk-desktop
check "rustdesk" have_pkg rustdesk
check "tailscale" have_cmd tailscale
check "libreoffice" bash -c 'command -v libreoffice >/dev/null || dpkg -l libreoffice-core 2>/dev/null | grep -q "^ii"'
check "vlc" have_cmd vlc
check "PWA: FigJam" have_path "$HOME/.local/share/applications/FigJam.desktop"
check "PWA: Miro" have_path "$HOME/.local/share/applications/Miro.desktop"
check "PWA: Excalidraw" have_path "$HOME/.local/share/applications/Excalidraw.desktop"

section "desktop"
check "GNOME: snowhush" bash -c 'gnome-extensions list --enabled | grep -qx snowhush@mbezruchko.github.io'
check "GNOME: blur-my-shell" bash -c 'gnome-extensions list --enabled | grep -qx blur-my-shell@aunetx'
check "GNOME: caffeine" bash -c 'gnome-extensions list --enabled | grep -qx caffeine@patapon.info'
check "GNOME: clipboard-indicator" bash -c 'gnome-extensions list --enabled | grep -qx clipboard-indicator@tudmotu.com'
check "hotkey launchers" have_path "$HOME/.local/bin/open-github.sh"
check "langfix" have_path "$HOME/.local/share/langfix/langfix_xclip.py"
check "keybindings (14)" bash -c '[[ $(dconf read /org/gnome/settings-daemon/plugins/media-keys/custom-keybindings | grep -o custom | wc -l) -eq 14 ]]'

section "gaming"
check "steam" have_snap steam
check "mangohud" have_cmd mangohud
check "gamemoderun" have_cmd gamemoderun
check "GE-Proton" bash -c 'ls -d "$HOME/.steam/steam/compatibilitytools.d"/GE-Proton* 2>/dev/null | grep -q .'

section "firefox"
check "firefox" have_cmd firefox
check "add-ons (>=15)" bash -c 'p=$(find "$HOME/snap/firefox/common/.mozilla/firefox" "$HOME/.mozilla/firefox" -maxdepth 2 -type d -name extensions 2>/dev/null | head -1); [[ -n "$p" && $(ls "$p"/*.xpi 2>/dev/null | wc -l) -ge 15 ]]'

section "vscode extensions"
check "extensions (>=35)" bash -c '[[ $(code --list-extensions 2>/dev/null | wc -l) -ge 35 ]]'

section "virtualization"
check "libvirtd running" bash -c 'systemctl is-active --quiet libvirtd'
check "virt-manager" have_cmd virt-manager
check "virtio-win.iso" have_path /var/lib/libvirt/images/virtio-win.iso
check "windows VM defined" bash -c 'virsh list --all 2>/dev/null | grep -q Windows11'

section "users"
check "user maria" bash -c 'id maria'
check "user mikhail" bash -c 'id mikhail'

printf '\n%s%d checks passed, %d failed%s\n' "$C_BOLD" "$PASS" "$FAIL" "$C_RESET"

TODO+=(
    "Sign in to Firefox account (optional): add-ons are already installed."
    "Sign in to VS Code / GitHub when needed: nothing is authenticated."
    "Run 'gh auth login' to make git push work."
    "Sign in to claude, codex, opencode, Claude Desktop and the ChatGPT app."
    "Set the RustDesk permanent password: Settings -> Security -> Enable permanent password."
    "Run 'sudo tailscale up' and authenticate to join the tailnet."
    "Open Steam -> Settings -> Compatibility -> enable Steam Play for all titles."
    "Install Windows 11 in the VM, then run vm/post-install.ps1 inside it."
    "Activate Windows with the product key, then sign in to Microsoft 365 for Office and Visio."
    "Install 1C separately (see MANUAL.md)."
    "Log out and back in so new GNOME extensions and groups take effect."
)

printf '\n%sStill manual:%s\n' "$C_BOLD" "$C_RESET"
for item in "${TODO[@]}"; do
    printf '  - %s\n' "$item"
done

if ((FAIL > 0)); then
    exit 1
fi
