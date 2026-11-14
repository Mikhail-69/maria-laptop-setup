#!/usr/bin/env bash
# Launch GitHub MCP server with the PAT read at runtime (token is not stored in claude config).
token_file="$HOME/.config/opencode/secrets/github-pat"
GITHUB_PERSONAL_ACCESS_TOKEN="$(cat "$token_file")"
export GITHUB_PERSONAL_ACCESS_TOKEN
exec npx -y @modelcontextprotocol/server-github
