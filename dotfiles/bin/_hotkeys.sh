#!/usr/bin/env bash
# Shared helpers for hotkey launchers. Sourced by the scripts in this folder.

notify() {
    if command -v notify-send >/dev/null 2>&1; then
        notify-send --app-name="Hotkeys" "$1"
    else
        printf '%s\n' "$1" >&2
    fi
}

open_url() {
    if ! command -v xdg-open >/dev/null 2>&1; then
        notify "xdg-open не найден"
        exit 1
    fi
    nohup xdg-open "$1" >/dev/null 2>&1 &
}

first_existing_dir() {
    local candidate
    for candidate in "$@"; do
        if [[ -d "$candidate" ]]; then
            printf '%s\n' "$candidate"
            return 0
        fi
    done
    return 1
}
