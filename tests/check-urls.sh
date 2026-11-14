#!/usr/bin/env bash
# Verifies that every external artifact referenced by the scripts is reachable:
# installer scripts, vendor repositories, .deb downloads, GitHub releases,
# Firefox add-ons and GNOME extensions.
#
# GITHUB_TOKEN is optional but recommended: unauthenticated GitHub API calls are
# rate limited per IP.

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=../versions.env
source "$ROOT/versions.env"

command -v curl >/dev/null 2>&1 || { echo "curl is required" >&2; exit 1; }
command -v jq >/dev/null 2>&1 || { echo "jq is required" >&2; exit 1; }

FAILED=0
CHECKED=0

ok() { printf 'ok   %s\n' "$1"; }
bad() { printf 'FAIL %s (%s)\n' "$1" "${2:-}"; FAILED=$((FAILED + 1)); }

check_url() {
    local url="$1" code
    CHECKED=$((CHECKED + 1))
    code="$(curl -sIL -o /dev/null -w '%{http_code}' --max-time 40 "$url" || echo 000)"
    if [[ "$code" =~ ^2 ]]; then
        ok "$url"
    else
        bad "$url" "HTTP $code"
    fi
}

github_auth_header() {
    if [[ -n "${GITHUB_TOKEN:-}" ]]; then
        printf 'Authorization: Bearer %s' "$GITHUB_TOKEN"
    else
        printf 'X-GitHub-Api-Version: 2022-11-28'
    fi
}

check_github_asset() {
    local repo="$1" pattern="$2" url
    CHECKED=$((CHECKED + 1))
    url="$(curl -fsSL -H "$(github_auth_header)" \
        "https://api.github.com/repos/${repo}/releases?per_page=10" \
        | jq -r --arg p "$pattern" \
            '.[] | .assets[] | select(.name | test($p)) | .browser_download_url' \
        | head -1 || true)"
    if [[ -z "$url" ]]; then
        bad "${repo} /${pattern}/" "no matching asset"
        return
    fi
    if [[ "$url" =~ ^https:// ]]; then
        ok "$repo -> $(basename "$url")"
    else
        bad "$repo" "unexpected url $url"
    fi
}

check_amo_addon() {
    local id="$1" enc file
    enc="${id//\{/%7B}"
    enc="${enc//\}/%7D}"
    CHECKED=$((CHECKED + 1))
    file="$(curl -fsSL --max-time 40 \
        "https://addons.mozilla.org/api/v5/addons/addon/${enc}/" \
        | jq -r '.current_version.file.url // empty' 2>/dev/null || true)"
    if [[ -n "$file" ]]; then
        ok "addons.mozilla.org: $id"
    else
        bad "addons.mozilla.org: $id" "not found"
    fi
}

echo "== installer scripts =="
check_url "https://claude.ai/install.sh"
check_url "https://chatgpt.com/codex/install.sh"
check_url "https://opencode.ai/install"
check_url "https://astral.sh/uv/install.sh"
check_url "https://bun.sh/install"

echo "== apt repositories =="
check_url "https://cli.github.com/packages/githubcli-archive-keyring.gpg"
check_url "https://download.docker.com/linux/ubuntu/gpg"
check_url "https://packages.microsoft.com/keys/microsoft.asc"
check_url "https://packages.microsoft.com/repos/code/dists/stable/Release"
check_url "https://download.spotify.com/debian/pubkey_C85668DF69375001.gpg"
check_url "https://repository.spotify.com/dists/stable/Release"
check_url "https://pkgs.tailscale.com/stable/ubuntu/noble.noarmor.gpg"
check_url "https://pkgs.tailscale.com/stable/ubuntu/noble.list"
check_url "https://downloads.claude.ai/claude-desktop/apt/stable/dists/stable/main/binary-amd64/Packages"
check_url "https://persistent.oaistatic.com/codex-app-prod/linux/deb/dists/stable/main/binary-amd64/Packages"

echo "== direct downloads =="
check_url "https://dl.google.com/linux/direct/google-chrome-stable_current_amd64.deb"
check_url "https://discord.com/api/download?platform=linux&format=deb"
check_url "https://zoom.us/client/latest/zoom_amd64.deb"
check_url "https://apps.webinar.ru/weteams/linkchats-desktop.deb"
check_url "https://dbeaver.io/files/dbeaver-ce_latest_amd64.deb"
check_url "https://music-desktop-application.s3.yandex.net/stable/Yandex_Music_amd64_${YANDEX_MUSIC_VERSION}.deb"
check_url "https://go.dev/dl/go${GO_VERSION}.linux-amd64.tar.gz"
check_url "https://fedorapeople.org/groups/virt/virtio-win/direct-downloads/stable-virtio/virtio-win.iso"

echo "== github releases =="
check_github_asset "Louis-CFM/coucou" 'Coucou-Linux-.*amd64\.deb$'
check_github_asset "jgraph/drawio-desktop" 'drawio-amd64-.*\.deb$'
check_github_asset "camunda/camunda-modeler" 'camunda-modeler-.*-linux-x64\.tar\.gz$'
check_github_asset "danyadev/vk-desktop" 'VK\.Desktop\.linux\.x64\.zip$'
check_github_asset "rustdesk/rustdesk" '-x86_64\.deb$'
check_github_asset "Happ-proxy/happ-desktop" 'Happ\.linux\.x64\.deb$'
check_github_asset "pluralplay/FlClashX" 'FlClashX-linux-amd64\.deb$'

echo "== fixed github assets =="
check_url "https://github.com/Happ-proxy/happ-desktop/releases/latest/download/Happ.linux.x64.deb"
check_url "https://github.com/pluralplay/FlClashX/releases/latest/download/FlClashX-linux-amd64.deb"
check_url "https://github.com/mbezruchko/Snowhush/releases/latest/download/snowhush-x86_64.deb"

echo "== firefox add-ons =="
while IFS= read -r id; do
    [[ -z "$id" || "$id" == \#* ]] && continue
    check_amo_addon "$id"
done < <(grep -vE '^\s*(#|$)' "$ROOT/assets/firefox-addons.txt")

echo "== gnome extensions =="
for uuid in \
    blur-my-shell@aunetx \
    caffeine@patapon.info \
    clipboard-indicator@tudmotu.com \
    night-light-slider-updated@vilsbeg.codeberg.org; do
    check_url "https://extensions.gnome.org/download-extension/${uuid}.shell-extension.zip?shell_version=46"
done

echo
echo "checked: $CHECKED, failed: $FAILED"

if ((FAILED > 0)); then
    exit 1
fi

echo "all urls resolve"
