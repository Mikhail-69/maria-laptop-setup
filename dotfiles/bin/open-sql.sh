#!/usr/bin/env bash
# Ctrl+Alt+6 / Ctrl+NumPad-5
# Opens the SQL client if one is installed.
source "$HOME/.local/bin/_hotkeys.sh"

for candidate in dbeaver dbeaver-ce; do
    if command -v "$candidate" >/dev/null 2>&1; then
        nohup "$candidate" >/dev/null 2>&1 &
        exit 0
    fi
done

notify "DBeaver не установлен"
exit 1
