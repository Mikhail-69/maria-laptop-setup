#!/usr/bin/env bash
# Stage 06: Steam, Proton (GE), MangoHud, GameMode.

source "$(dirname "${BASH_SOURCE[0]}")/lib/common.sh"

stage_start "06 gaming: steam, proton, mangohud, gamemode"

if is_done 06 && [[ "${FORCE:-0}" != "1" ]]; then
    ok "stage 06 already done (FORCE=1 to rerun)"
    exit 0
fi

require_sudo
apt_refresh

section "graphics stack"
install_apt \
    mesa-vulkan-drivers vulkan-tools mesa-utils \
    libgl1-mesa-dri libglx-mesa0 \
    gamemode mangohud \
    libgamemode0=libgamemode0t64

section "steam"
install_snap steam

section "steam library paths"
if ! is_dry; then
    mkdir -p "$HOME/.steam/steam/compatibilitytools.d"
    mkdir -p "$HOME/.local/share/Steam/compatibilitytools.d"
fi

section "proton-ge (protonup-ng)"
if command -v protonup-ng >/dev/null 2>&1 && ! is_dry; then
    ok "protonup-ng already installed"
else
    run pipx install protonup-ng --force
fi
if is_dry; then
    printf '+ protonup-ng -d ~/.steam/steam/compatibilitytools.d -y\n'
else
    if command -v protonup-ng >/dev/null 2>&1; then
        protonup-ng --dir "$HOME/.steam/steam/compatibilitytools.d" -y \
            || warn "GE-Proton was not downloaded, run 'protonup-ng' manually later"
    else
        warn "protonup-ng is not on PATH yet, open a new terminal and run: protonup-ng"
    fi
fi

mark_done 06
ok "stage 06 finished"
