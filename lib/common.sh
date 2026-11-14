#!/usr/bin/env bash
# Shared helpers for every stage script.
# Sourced, never executed directly.

set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
export REPO_DIR
export STATE_DIR="${STATE_DIR:-$HOME/.local/state/laptop-setup}"
export LOG_FILE="$STATE_DIR/setup.log"
export DOWNLOAD_DIR="${DOWNLOAD_DIR:-/tmp/laptop-setup-downloads}"
export DRY_RUN="${DRY_RUN:-0}"

if [[ -t 1 ]]; then
    C_RED=$'\033[0;31m'
    C_GREEN=$'\033[0;32m'
    C_YELLOW=$'\033[0;33m'
    C_BLUE=$'\033[0;34m'
    C_BOLD=$'\033[1m'
    C_RESET=$'\033[0m'
else
    C_RED='' C_GREEN='' C_YELLOW='' C_BLUE='' C_BOLD='' C_RESET=''
fi

mkdir -p "$STATE_DIR" "$DOWNLOAD_DIR"

log()  { printf '%s\n' "$*" | tee -a "$LOG_FILE" >/dev/null; printf '%s\n' "$*"; }
info() { log "${C_BLUE}[info]${C_RESET} $*"; }
ok()   { log "${C_GREEN}[ ok ]${C_RESET} $*"; }
warn() { log "${C_YELLOW}[warn]${C_RESET} $*"; }
err()  { log "${C_RED}[fail]${C_RESET} $*"; }
die()  { err "$*"; exit 1; }

section() {
    log ""
    log "${C_BOLD}== $* ==${C_RESET}"
}

is_dry() { [[ "$DRY_RUN" == "1" ]]; }

# Run a command, or print it when DRY_RUN=1.
run() {
    if is_dry; then
        printf '+ %s\n' "$*"
    else
        "$@"
    fi
}

# Run a shell snippet (pipes, redirections), or print it when DRY_RUN=1.
run_sh() {
    if is_dry; then
        printf '+ %s\n' "$*"
    else
        bash -c "$*"
    fi
}

# Mark a stage as finished. Markers live outside the repo, so a fresh clone
# still reruns everything.
mark_done() {
    [[ "$DRY_RUN" == "1" ]] && return 0
    date -Iseconds > "$STATE_DIR/done-$1"
}

is_done() {
    [[ -f "$STATE_DIR/done-$1" ]]
}

version_ge() {
    # version_ge 1.2.3 1.2 -> true
    [[ "$(printf '%s\n%s\n' "$1" "$2" | sort -V | head -1)" == "$2" ]]
}

require_sudo() {
    if [[ "$(id -u)" -eq 0 ]]; then
        SUDO=""
        return 0
    fi
    if is_dry; then
        SUDO="sudo"
        return 0
    fi
    command -v sudo >/dev/null 2>&1 || die "sudo not found"
    sudo -v || die "sudo authentication failed"
    SUDO="sudo"
}

apt_refresh() {
    if is_dry; then
        printf '+ %s\n' "$SUDO apt-get update"
        return 0
    fi
    $SUDO apt-get update -qq
}

apt_available() {
    apt-cache show "$1" >/dev/null 2>&1
}

# install_apt pkg [pkg...]
# Skips names that apt cannot resolve and reports them instead of failing the
# whole stage. Optional fallbacks are passed as "name=fallback".
install_apt() {
    local resolved=() skipped=()
    local spec name fallback picked candidate
    local -a candidates
    for spec in "$@"; do
        name="${spec%%=*}"
        fallback=""
        [[ "$spec" == *=* ]] && fallback="${spec#*=}"
        if is_dry; then
            resolved+=("$name")
            continue
        fi
        if apt_available "$name"; then
            resolved+=("$name")
            continue
        fi
        picked=""
        if [[ -n "$fallback" ]]; then
            IFS='|' read -ra candidates <<< "$fallback"
            for candidate in "${candidates[@]}"; do
                if apt_available "$candidate"; then
                    picked="$candidate"
                    break
                fi
            done
        fi
        if [[ -n "$picked" ]]; then
            resolved+=("$picked")
        else
            skipped+=("$name")
        fi
    done

    if ((${#skipped[@]})); then
        warn "not available in this release, skipped: ${skipped[*]}"
    fi
    ((${#resolved[@]})) || return 0
    info "apt install: ${resolved[*]}"
    if is_dry; then
        printf '+ %s apt-get install -y %s\n' "$SUDO" "${resolved[*]}"
        return 0
    fi
    DEBIAN_FRONTEND=noninteractive $SUDO apt-get install -y --no-install-recommends "${resolved[@]}" \
        || $SUDO apt-get install -y "${resolved[@]}"
}

snap_installed() {
    snap list 2>/dev/null | awk 'NR>1 {print $1}' | grep -qx "$1"
}

# install_snap name [--classic] [--candidate]
install_snap() {
    local name="$1"; shift
    if is_dry; then
        printf '+ snap install %s %s\n' "$name" "$*"
        return 0
    fi
    if snap_installed "$name"; then
        ok "snap $name already installed"
        return 0
    fi
    info "snap install $name $*"
    $SUDO snap install "$name" "$@"
}

download() {
    local url="$1" out="$2"
    if [[ -s "$out" ]]; then
        ok "cached $(basename "$out")"
        return 0
    fi
    info "download $url"
    run curl -fL --retry 3 --connect-timeout 20 -o "$out" "$url"
}

# install_deb_url URL [sha256] [filename]
# Downloads a .deb and installs it with apt so that dependencies resolve.
install_deb_url() {
    local url="$1" expect="${2:-}" name="${3:-}"
    local file
    if [[ -n "$name" ]]; then
        file="$DOWNLOAD_DIR/$name"
    else
        file="$DOWNLOAD_DIR/$(basename "${url%%\?*}")"
    fi
    download "$url" "$file"
    if [[ -n "$expect" ]] && ! is_dry; then
        local actual
        actual="$(sha256sum "$file" | awk '{print $1}')"
        [[ "$actual" == "$expect" ]] || die "checksum mismatch for $file"
    fi
    if is_dry; then
        printf '+ %s apt-get install -y %s\n' "$SUDO" "$file"
        return 0
    fi
    DEBIAN_FRONTEND=noninteractive $SUDO apt-get install -y "$file" \
        || { $SUDO dpkg -i "$file" || true; $SUDO apt-get install -y -f; }
}

# install_deb_from_repo PACKAGES_INDEX_URL PACKAGE
# Picks the newest version listed in an APT Packages index, downloads that exact
# .deb and installs it. Used for vendor repos that publish their key inside the
# package itself (claude-desktop, chatgpt).
install_deb_from_repo() {
    local index="$1" pkg="$2"
    local base rel ver file

    base="${index%%/dists/*}"
    rel="$(curl -fsSL "$index" | awk -v pkg="$pkg" '
        BEGIN { RS = ""; FS = "\n" }
        {
            name = ""; v = ""; f = ""
            for (i = 1; i <= NF; i++) {
                if ($i ~ /^Package: /)  name = substr($i, 10)
                if ($i ~ /^Version: /)  v = substr($i, 10)
                if ($i ~ /^Filename: /) f = substr($i, 11)
            }
            if (name == pkg && f != "") print v "\t" f
        }' | sort -V | tail -1)"

    [[ -n "$rel" ]] || die "package $pkg not found in $index"
    ver="${rel%%$'\t'*}"
    file="${rel#*$'\t'}"
    info "$pkg $ver"
    install_deb_url "$base/$file"
}

# github_asset OWNER/REPO REGEX
# Resolves the newest release asset whose name matches REGEX (first match).
github_asset() {
    local repo="$1" pattern="$2" url
    url="$(curl -fsSL "https://api.github.com/repos/$repo/releases?per_page=10" \
        | jq -r --arg p "$pattern" '
            .[] | .assets[] | select(.name | test($p)) | .browser_download_url
          ' | head -1)"
    [[ -n "$url" ]] || die "no asset matching /$pattern/ in $repo"
    printf '%s' "$url"
}

# install_gnome_extension SRC_DIR UUID
install_gnome_extension() {
    local src="$1" uuid="$2"
    local dest="$HOME/.local/share/gnome-shell/extensions/$uuid"
    info "gnome extension $uuid -> $dest"
    run mkdir -p "$dest"
    run cp -a "$src/." "$dest/"
    run chmod +x "$dest/bin/"* 2>/dev/null || true
    if is_dry; then
        return 0
    fi
    gnome-extensions enable "$uuid" 2>/dev/null \
        || warn "extension $uuid will need a re-login before it can be enabled"
}

# pwa_shortcut NAME URL [ICON]
pwa_shortcut() {
    local name="$1" url="$2" icon="${3:-}"
    local dir="$HOME/.local/share/applications"
    local file="$dir/$name.desktop"
    info "PWA shortcut $name"
    if is_dry; then
        printf '+ write %s\n' "$file"
        return 0
    fi
    mkdir -p "$dir"
    {
        printf '[Desktop Entry]\n'
        printf 'Type=Application\n'
        printf 'Name=%s\n' "$name"
        printf 'Exec=google-chrome --app=%s --class=%s\n' "$url" "$name"
        printf 'Terminal=false\n'
        printf 'Categories=Network;\n'
        [[ -n "$icon" ]] && printf 'Icon=%s\n' "$icon"
    } > "$file"
    chmod +x "$file"
    update-desktop-database "$dir" 2>/dev/null || true
}

# render_template SRC DEST
render_template() {
    # Replaces /home/mikhail and __HOME__ with the real home directory.
    local src="$1" dest="$2"
    if is_dry; then
        printf '+ render %s -> %s\n' "$src" "$dest"
        return 0
    fi
    mkdir -p "$(dirname "$dest")"
    sed -e "s|/home/mikhail|$HOME|g" -e "s|__HOME__|$HOME|g" "$src" > "$dest"
}

stage_start() {
    section "$1"
    mkdir -p "$STATE_DIR"
    log "stage log: $LOG_FILE"
}
