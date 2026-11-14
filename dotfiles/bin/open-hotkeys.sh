#!/usr/bin/env bash
# Ctrl+Alt+4 / Ctrl+NumPad-0
# Opens the local hotkey cheat sheet.
source "$HOME/.local/bin/_hotkeys.sh"

sheet=""
for candidate in "$HOME/Документы/hotkeys.md" "$HOME/Documents/hotkeys.md"; do
    [[ -f "$candidate" ]] && sheet="$candidate" && break
done

if [[ -z "$sheet" ]]; then
    notify "Файл hotkeys.md не найден"
    exit 1
fi

if command -v code >/dev/null 2>&1; then
    nohup code "$sheet" >/dev/null 2>&1 &
else
    nohup xdg-open "$sheet" >/dev/null 2>&1 &
fi
