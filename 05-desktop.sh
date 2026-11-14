#!/usr/bin/env bash
# Stage 05: GNOME extensions, Snowhush, hotkeys, timezone.
# Desktop-only: must be run from the graphical session of the target user,
# not with sudo.

source "$(dirname "${BASH_SOURCE[0]}")/lib/common.sh"

stage_start "05 desktop: GNOME, Snowhush, hotkeys"

if is_done 05 && [[ "${FORCE:-0}" != "1" ]]; then
    ok "stage 05 already done (FORCE=1 to rerun)"
    exit 0
fi

if [[ "$(id -u)" -eq 0 ]]; then
    die "run this stage as the desktop user, not root"
fi

require_sudo

section "gnome shell packages"
install_apt \
    gnome-shell-extensions \
    gnome-shell-extension-appindicator \
    gnome-shell-extension-manager \
    gnome-shell-extension-prefs \
    dconf-cli

section "extensions from extensions.gnome.org"
GNOME_SHELL_VERSION="$(gnome-shell --version 2>/dev/null | grep -oE '[0-9]+' | head -1 || true)"
GNOME_SHELL_VERSION="${GNOME_SHELL_VERSION:-46}"
info "gnome-shell major version: $GNOME_SHELL_VERSION"

install_gnome_org_extension() {
    local uuid="$1"
    local zip="$DOWNLOAD_DIR/${uuid}.zip"
    local url="https://extensions.gnome.org/download-extension/${uuid}.shell-extension.zip?shell_version=${GNOME_SHELL_VERSION}"

    if is_dry; then
        printf '+ gnome-extensions install %s\n' "$url"
        return 0
    fi
    if gnome-extensions list 2>/dev/null | grep -qx "$uuid"; then
        ok "$uuid already installed"
    else
        download "$url" "$zip"
        gnome-extensions install --force "$zip" >/dev/null 2>&1 \
            || warn "could not install $uuid"
    fi
    gnome-extensions enable "$uuid" 2>/dev/null \
        || warn "$uuid will be enabled after re-login"
}

install_gnome_org_extension "blur-my-shell@aunetx"
install_gnome_org_extension "caffeine@patapon.info"
install_gnome_org_extension "clipboard-indicator@tudmotu.com"
install_gnome_org_extension "night-light-slider-updated@vilsbeg.codeberg.org"

if ! is_dry; then
    gnome-extensions enable drive-menu@gnome-shell-extensions.gcampax.github.com 2>/dev/null || true
fi

section "snowhush"
install_gnome_extension "$REPO_DIR/assets/snowhush" "snowhush@mbezruchko.github.io"
if ! is_dry && [[ -x "$HOME/.local/share/gnome-shell/extensions/snowhush@mbezruchko.github.io/bin/snowhush" ]]; then
    ok "snowhush engine is executable"
fi

section "hotkey launchers"
if is_dry; then
    printf '+ install hotkey scripts into ~/.local/bin\n'
else
    mkdir -p "$HOME/.local/bin"
    for script in "$REPO_DIR"/dotfiles/bin/*.sh; do
        name="$(basename "$script")"
        sed -e "s|/home/mikhail|$HOME|g" -e "s|__HOME__|$HOME|g" "$script" > "$HOME/.local/bin/$name"
        chmod +x "$HOME/.local/bin/$name"
    done
    ok "installed $(find "$HOME/.local/bin" -maxdepth 1 -name '*.sh' | wc -l) launcher scripts"
fi

section "langfix"
if is_dry; then
    printf '+ install langfix into ~/.local/share/langfix\n'
else
    mkdir -p "$HOME/.local/share/langfix"
    cp "$REPO_DIR/dotfiles/langfix/langfix_xclip.py" "$HOME/.local/share/langfix/langfix_xclip.py"
    chmod +x "$HOME/.local/share/langfix/langfix_xclip.py"
fi

section "hotkey cheat sheet"
DOCS_DIR="$(xdg-user-dir DOCUMENTS 2>/dev/null || true)"
DOCS_DIR="${DOCS_DIR:-$HOME/Documents}"
if is_dry; then
    printf '+ write %s/hotkeys.md\n' "$DOCS_DIR"
else
    mkdir -p "$DOCS_DIR"
    cp "$REPO_DIR/dotfiles/hotkeys.md" "$DOCS_DIR/hotkeys.md"
    ok "cheat sheet: $DOCS_DIR/hotkeys.md"
fi

section "keybindings"
render_template "$REPO_DIR/dotfiles/dconf/media-keys.dconf" "$STATE_DIR/media-keys.dconf"
if is_dry; then
    printf '+ dconf load /org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/ < %s\n' "$STATE_DIR/media-keys.dconf"
else
    dconf load /org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/ \
        < "$STATE_DIR/media-keys.dconf" \
        || warn "dconf load failed, are you in a graphical session?"
    dconf write /org/gnome/shell/keybindings/screenshot "['Print']" 2>/dev/null || true
    dconf write /org/gnome/shell/keybindings/show-screenshot-ui "['<Shift><Super>s']" 2>/dev/null || true
    ok "keybindings applied"
fi

section "timezone"
run $SUDO timedatectl set-timezone Europe/Moscow

mark_done 05
ok "stage 05 finished (log out once so new extensions load)"
