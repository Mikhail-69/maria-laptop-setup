#!/usr/bin/env bash
# Stage 04: communication, media, work and networking applications.
# Nothing is signed in: install only.

source "$(dirname "${BASH_SOURCE[0]}")/lib/common.sh"
# shellcheck source=versions.env
source "$REPO_DIR/versions.env"

stage_start "04 apps: communication, media, work, networking"

if is_done 04 && [[ "${FORCE:-0}" != "1" ]]; then
    ok "stage 04 already done (FORCE=1 to rerun)"
    exit 0
fi

require_sudo
apt_refresh

section "google chrome"
install_deb_url "https://dl.google.com/linux/direct/google-chrome-stable_current_amd64.deb"

section "discord (deb, not snap)"
install_deb_url "https://discord.com/api/download?platform=linux&format=deb" "" "discord.deb"

section "spotify (official repository)"
if ! is_dry; then
    $SUDO install -m 0755 -d /etc/apt/keyrings
    curl -fsSL https://download.spotify.com/debian/pubkey_C85668DF69375001.gpg \
        | $SUDO gpg --dearmor --yes -o /etc/apt/keyrings/spotify.gpg
    $SUDO chmod go+r /etc/apt/keyrings/spotify.gpg
    printf 'deb [signed-by=/etc/apt/keyrings/spotify.gpg] https://repository.spotify.com stable non-free\n' \
        | $SUDO tee /etc/apt/sources.list.d/spotify.list >/dev/null
    $SUDO apt-get update -qq || warn "spotify repository refresh failed"
fi
install_apt spotify-client

section "yandex music"
install_deb_url \
    "https://music-desktop-application.s3.yandex.net/stable/Yandex_Music_amd64_${YANDEX_MUSIC_VERSION}.deb" \
    "" "yandex-music.deb"

section "zoom workplace"
install_deb_url "https://zoom.us/client/latest/zoom_amd64.deb"

section "mts link"
install_deb_url "https://apps.webinar.ru/weteams/linkchats-desktop.deb"

section "coucou"
COUCOU_URL="$(github_asset "Louis-CFM/coucou" 'Coucou-Linux-.*amd64\.deb$')"
install_deb_url "$COUCOU_URL" "" "coucou.deb"

section "happ (install only, no subscription)"
install_deb_url "https://github.com/Happ-proxy/happ-desktop/releases/latest/download/Happ.linux.x64.deb"

section "flclashx (install only, no subscription)"
install_deb_url "https://github.com/pluralplay/FlClashX/releases/latest/download/FlClashX-linux-amd64.deb"

section "deepseek desktop"
install_snap deepseek-desktop

section "localsend"
install_snap localsend

section "notepad++ (snap build, runs through wine)"
install_snap notepad-plus-plus

section "draw.io"
DRAWIO_URL="$(github_asset "jgraph/drawio-desktop" 'drawio-amd64-.*\.deb$')"
install_deb_url "$DRAWIO_URL" "" "drawio.deb"

section "dbeaver community"
install_deb_url "https://dbeaver.io/files/dbeaver-ce_latest_amd64.deb"

section "camunda modeler (latest release)"
CAMUNDA_URL="$(github_asset "camunda/camunda-modeler" 'camunda-modeler-.*-linux-x64\.tar\.gz$')"
CAMUNDA_FILE="$DOWNLOAD_DIR/camunda-modeler.tar.gz"
download "$CAMUNDA_URL" "$CAMUNDA_FILE"
if is_dry; then
    printf '+ extract %s -> /opt/camunda-modeler\n' "$CAMUNDA_FILE"
else
    $SUDO rm -rf /opt/camunda-modeler
    $SUDO mkdir -p /opt/camunda-modeler
    $SUDO tar -xzf "$CAMUNDA_FILE" -C /opt/camunda-modeler --strip-components=1
    $SUDO ln -sf /opt/camunda-modeler/camunda-modeler /usr/local/bin/camunda-modeler
    $SUDO tee /usr/share/applications/camunda-modeler.desktop >/dev/null <<'EOF'
[Desktop Entry]
Type=Application
Name=Camunda Modeler
Exec=/opt/camunda-modeler/camunda-modeler %U
Terminal=false
Categories=Development;
EOF
    ok "camunda modeler installed"
fi

section "vk desktop (zip build)"
VK_URL="$(github_asset "danyadev/vk-desktop" 'VK\.Desktop\.linux\.x64\.zip$')"
VK_FILE="$DOWNLOAD_DIR/vk-desktop.zip"
download "$VK_URL" "$VK_FILE"
if is_dry; then
    printf '+ extract %s -> /opt/vk-desktop\n' "$VK_FILE"
else
    $SUDO rm -rf /opt/vk-desktop
    $SUDO mkdir -p /opt/vk-desktop
    $SUDO unzip -qo "$VK_FILE" -d /opt/vk-desktop
    VK_BIN="$(find /opt/vk-desktop -maxdepth 3 -type f -name 'vk-desktop*' -perm -u+x | head -1)"
    if [[ -z "$VK_BIN" ]]; then
        warn "vk-desktop binary not found after unpacking, check /opt/vk-desktop"
    else
        $SUDO ln -sf "$VK_BIN" /usr/local/bin/vk-desktop
        $SUDO tee /usr/share/applications/vk-desktop.desktop >/dev/null <<EOF
[Desktop Entry]
Type=Application
Name=VK Messenger
Exec=$VK_BIN %U
Terminal=false
Categories=Network;Chat;
EOF
        ok "vk desktop installed: $VK_BIN"
    fi
fi

section "rustdesk (remote support)"
RUSTDESK_URL="$(github_asset "rustdesk/rustdesk" '-x86_64\.deb$')"
install_deb_url "$RUSTDESK_URL" "" "rustdesk.deb"

section "tailscale"
if ! is_dry; then
    curl -fsSL https://pkgs.tailscale.com/stable/ubuntu/noble.noarmor.gpg \
        | $SUDO tee /usr/share/keyrings/tailscale-archive-keyring.gpg >/dev/null
    curl -fsSL https://pkgs.tailscale.com/stable/ubuntu/noble.list \
        | $SUDO tee /etc/apt/sources.list.d/tailscale.list >/dev/null
    $SUDO apt-get update -qq || warn "tailscale repository refresh failed"
fi
install_apt tailscale

section "libreoffice"
if ! is_dry; then
    if dpkg -l libreoffice-core >/dev/null 2>&1; then
        ok "libreoffice already installed"
    else
        install_apt libreoffice
    fi
fi

section "web whiteboards as app shortcuts"
# FigJam, Miro and Excalidraw have no Linux desktop client that we can rely on,
# so they are installed as Chrome app windows.
pwa_shortcut "FigJam" "https://figma.com/board"
pwa_shortcut "Miro" "https://miro.com/app/dashboard/"
pwa_shortcut "Excalidraw" "https://excalidraw.com"

mark_done 04
ok "stage 04 finished"
