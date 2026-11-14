#!/usr/bin/env bash
# Verifies that every apt package referenced by the stage scripts exists in
# Ubuntu 24.04. Runs inside an ubuntu:24.04 container in CI, after apt update.
#
# Packages that come from a vendor repository (VS Code, gh, Docker, Spotify,
# Tailscale, Claude Desktop, ChatGPT) are skipped here: their repositories are
# checked by tests/check-urls.sh instead.

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

VENDOR_PACKAGES=(
    code gh
    docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
    spotify-client tailscale
    claude-desktop chatgpt
)

is_vendor() {
    local package
    for package in "${VENDOR_PACKAGES[@]}"; do
        [[ "$package" == "$1" ]] && return 0
    done
    return 1
}

if ! command -v apt-cache >/dev/null 2>&1; then
    echo "apt-cache not found" >&2
    exit 1
fi

# Collect the arguments of every install_apt call, including line continuations.
collect_specs() {
    awk '
        /^[[:space:]]*install_apt([[:space:]]|$)/ { inblock = 1 }
        inblock {
            line = $0
            sub(/\\[[:space:]]*$/, "", line)
            sub(/^[[:space:]]*install_apt[[:space:]]*/, "", line)
            count = split(line, parts, /[[:space:]]+/)
            for (i = 1; i <= count; i++) {
                if (parts[i] != "") print parts[i]
            }
            if ($0 !~ /\\[[:space:]]*$/) inblock = 0
        }
    ' "$ROOT"/*.sh | sort -u
}

exists() {
    apt-cache show "$1" >/dev/null 2>&1
}

missing=()
checked=0

while IFS= read -r spec; do
    [[ -z "$spec" || "$spec" == \#* ]] && continue

    # "name=fallback|other" means: any of these names is acceptable.
    name="${spec%%=*}"
    if is_vendor "$name"; then
        continue
    fi

    checked=$((checked + 1))
    if exists "$name"; then
        continue
    fi

    if [[ "$spec" == *=* ]]; then
        fallback="${spec#*=}"
        IFS='|' read -ra alternatives <<< "$fallback"
        found=0
        for alternative in "${alternatives[@]}"; do
            if exists "$alternative"; then
                found=1
                break
            fi
        done
        ((found)) && continue
    fi

    missing+=("$spec")
done < <(collect_specs)

echo "apt packages checked: $checked"

if ((${#missing[@]})); then
    echo "missing in Ubuntu 24.04:" >&2
    printf '  %s\n' "${missing[@]}" >&2
    exit 1
fi

echo "all apt packages resolve"
