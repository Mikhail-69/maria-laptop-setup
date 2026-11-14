#!/usr/bin/env bash
# PostToolUse (Edit|Write): format the changed file with a formatter if one is available.
# Never fails the tool call.
f=$(jq -r '.tool_input.file_path // empty' 2>/dev/null)
[ -n "$f" ] && [ -f "$f" ] || exit 0
dir=$(dirname "$f")
find_bin() { # local node_modules first, then PATH
  local d="$dir"
  while [ "$d" != "/" ]; do
    [ -x "$d/node_modules/.bin/$1" ] && { echo "$d/node_modules/.bin/$1"; return; }
    d=$(dirname "$d")
  done
  command -v "$1"
}
case "$f" in
  *.js|*.jsx|*.ts|*.tsx|*.json|*.css|*.scss|*.html|*.md|*.yaml|*.yml)
    p=$(find_bin prettier) && [ -n "$p" ] && "$p" --write "$f" >/dev/null 2>&1 ;;
  *.py)
    r=$(command -v ruff) && [ -n "$r" ] && { "$r" format "$f"; "$r" check --fix -q "$f"; } >/dev/null 2>&1 ;;
  *.go)  command -v gofmt >/dev/null && gofmt -w "$f" >/dev/null 2>&1 ;;
  *.rs)  command -v rustfmt >/dev/null && rustfmt "$f" >/dev/null 2>&1 ;;
esac
exit 0
