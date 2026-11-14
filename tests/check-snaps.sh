#!/usr/bin/env bash
# Verifies that every snap name referenced by the stage scripts exists in the
# Snap Store. snapd is not available in containers, so the store API is used.

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

command -v curl >/dev/null 2>&1 || { echo "curl is required" >&2; exit 1; }
command -v jq >/dev/null 2>&1 || { echo "jq is required" >&2; exit 1; }

mapfile -t snaps < <(
    grep -hoE '^[[:space:]]*install_snap[[:space:]]+[a-zA-Z0-9._-]+' "$ROOT"/*.sh \
        | awk '{print $2}' | sort -u
)

if ((${#snaps[@]} == 0)); then
    echo "no snap names found" >&2
    exit 1
fi

missing=()
for name in "${snaps[@]}"; do
    if curl -fsS -H "Snap-Device-Series: 16" \
        "https://api.snapcraft.io/v2/snaps/info/${name}" \
        | jq -e '.name' >/dev/null 2>&1; then
        echo "ok   $name"
    else
        echo "FAIL $name"
        missing+=("$name")
    fi
done

echo "snaps checked: ${#snaps[@]}"

if ((${#missing[@]})); then
    echo "snaps not found in the store: ${missing[*]}" >&2
    exit 1
fi

echo "all snaps resolve"
