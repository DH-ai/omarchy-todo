#!/usr/bin/env bash
set -euo pipefail

config_dir="${XDG_CONFIG_HOME:-$HOME/.config}/omarchy"
state_dir="${XDG_STATE_HOME:-$HOME/.local/state}/omarchy"
shell_file="$config_dir/shell.json"
plugin_dir="$config_dir/plugins/dhruv.todo"
project_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
backup="$shell_file.bak.$(date +%Y%m%d%H%M%S)"

command -v jq >/dev/null || { echo "jq is required" >&2; exit 1; }
test -f "$shell_file" || { echo "Missing $shell_file" >&2; exit 1; }

mkdir -p "$plugin_dir" "$state_dir"
cp "$shell_file" "$backup"
cp "$project_dir/plugin/dhruv.todo/manifest.json" "$plugin_dir/manifest.json"
cp "$project_dir/plugin/dhruv.todo/Todo.qml" "$plugin_dir/Todo.qml"

tmp_file="$(mktemp)"
jq '
  if ([.bar.layout.center[].id] | index("dhruv.todo")) then .
  else .bar.layout.center |= (.[:-1] + [{"id":"dhruv.todo"}] + [.[-1]])
  end
' "$shell_file" > "$tmp_file"
mv "$tmp_file" "$shell_file"

echo "Installed dhruv.todo. Backup: $backup"
echo "Run: omarchy restart shell"
