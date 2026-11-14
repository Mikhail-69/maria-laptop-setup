#!/usr/bin/env bash
# Stage 01: base system packages, codecs, fonts, utilities, shell aliases.
# Safe to re-run.

source "$(dirname "${BASH_SOURCE[0]}")/lib/common.sh"

stage_start "01 base: packages, codecs, shell"

if is_done 01 && [[ "${FORCE:-0}" != "1" ]]; then
    ok "stage 01 already done (FORCE=1 to rerun)"
    exit 0
fi

require_sudo
apt_refresh

# Accept the Microsoft core fonts EULA up front, otherwise the package stalls.
if ! is_dry; then
    echo ttf-mscorefonts-installer msttcorefonts/accepted-mscorefonts-eula select true \
        | $SUDO debconf-set-selections
fi

section "core utilities"
install_apt \
    curl wget gnupg ca-certificates apt-transport-https software-properties-common \
    lsb-release unzip zip p7zip-full xz-utils jq tree \
    htop btop ncdu iotop \
    fd-find ripgrep bat eza fzf zoxide tmux trash-cli thefuck \
    build-essential cmake pkg-config \
    python3 python3-venv python3-pip pipx \
    libfuse2=libfuse2t64 \
    xclip xdotool wmctrl \
    xdg-user-dirs libnotify-bin evince \
    file-roller

section "fonts and localization"
install_apt \
    fonts-jetbrains-mono fonts-liberation fonts-noto-core fonts-noto-color-emoji \
    hunspell-ru language-pack-ru language-pack-gnome-ru \
    ttf-mscorefonts-installer

section "media and codecs"
install_apt \
    ubuntu-restricted-extras \
    ffmpeg vlc mpv yt-dlp \
    gstreamer1.0-plugins-good gstreamer1.0-plugins-bad gstreamer1.0-plugins-ugly \
    gstreamer1.0-libav

section "desktop utilities"
install_apt \
    gnome-tweaks gnome-shell-extension-manager gnome-disk-utility \
    gparted timeshift \
    flameshot \
    cups system-config-printer sane-utils simple-scan

section "flatpak and flathub"
install_apt flatpak
if ! is_dry; then
    flatpak remote-add --if-not-exists --system flathub https://flathub.org/repo/flathub.flatpakrepo \
        || warn "flathub remote was not added"
fi

section "automatic security updates"
if is_dry; then
    printf '+ write /etc/apt/apt.conf.d/20auto-upgrades\n'
else
    printf '%s\n' \
        'APT::Periodic::Update-Package-Lists "1";' \
        'APT::Periodic::Unattended-Upgrade "1";' \
        'APT::Periodic::AutocleanInterval "7";' \
        | $SUDO tee /etc/apt/apt.conf.d/20auto-upgrades >/dev/null
    $SUDO systemctl enable --now unattended-upgrades >/dev/null 2>&1 || \
        warn "unattended-upgrades service could not be enabled"
fi

section "shell: bash aliases, thefuck"
render_template "$REPO_DIR/dotfiles/bash_aliases" "$HOME/.bash_aliases"

if ! is_dry; then
    touch "$HOME/.bashrc"
    if ! grep -q "laptop-setup: thefuck" "$HOME/.bashrc"; then
        {
            printf '\n# laptop-setup: thefuck\n'
            printf 'if command -v thefuck >/dev/null 2>&1; then\n'
            printf '    eval "$(thefuck --alias)"\n'
            printf 'fi\n'
        } >> "$HOME/.bashrc"
    fi
    if ! grep -q "laptop-setup: local bin" "$HOME/.bashrc"; then
        {
            printf '\n# laptop-setup: local bin\n'
            printf 'case ":$PATH:" in *":$HOME/.local/bin:"*) ;; *) PATH="$HOME/.local/bin:$PATH" ;; esac\n'
            printf 'export PATH\n'
        } >> "$HOME/.bashrc"
    fi
fi

section "git identity"
render_template "$REPO_DIR/dotfiles/gitconfig" "$HOME/.gitconfig"
chmod 600 "$HOME/.gitconfig" 2>/dev/null || true

mark_done 01
ok "stage 01 finished"
