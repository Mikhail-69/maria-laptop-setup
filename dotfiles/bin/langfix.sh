#!/usr/bin/env bash
# Ctrl+Alt+7 / Ctrl+NumPad-7
# Swaps the keyboard layout of the selected text (RU <-> EN).
# Works on X11. On a Wayland session, xdotool cannot inject keys into other
# windows: log out and pick "Ubuntu on Xorg" on the login screen.
source "$HOME/.local/bin/_hotkeys.sh"

target="$HOME/.local/share/langfix/langfix_xclip.py"
if [[ ! -f "$target" ]]; then
    notify "langfix не установлен"
    exit 1
fi

for dep in xclip xdotool; do
    if ! command -v "$dep" >/dev/null 2>&1; then
        notify "Не хватает $dep"
        exit 1
    fi
done

exec python3 "$target"
