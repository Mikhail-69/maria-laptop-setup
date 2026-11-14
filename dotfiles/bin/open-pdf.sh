#!/usr/bin/env bash
# Ctrl+Alt+5 / Ctrl+NumPad-4
# Opens the first PDF found in the usual book folders.
source "$HOME/.local/bin/_hotkeys.sh"

dir="$(first_existing_dir "$HOME/Documents/Books" "$HOME/Документы/Книги" "$HOME/Documents" "$HOME/Документы")" || {
    notify "Папка с книгами не найдена: положи PDF в ~/Документы/Книги"
    exit 1
}

pdf="$(find "$dir" -maxdepth 2 -type f -iname '*.pdf' 2>/dev/null | head -1)"
if [[ -z "$pdf" ]]; then
    notify "В $dir нет PDF-файлов"
    exit 1
fi

if command -v evince >/dev/null 2>&1; then
    nohup evince "$pdf" >/dev/null 2>&1 &
else
    nohup xdg-open "$pdf" >/dev/null 2>&1 &
fi
