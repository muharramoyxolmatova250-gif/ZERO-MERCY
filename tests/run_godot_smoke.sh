#!/usr/bin/env bash
set -u

log_file="$(mktemp)"
godot --headless --path . --quit-after 5 >"$log_file" 2>&1
status=$?
cat "$log_file"
if [ "$status" -ne 0 ] || grep -Eq 'SCRIPT ERROR:|Parse Error:|Compile Error:|Failed to load script' "$log_file"; then
  rm -f "$log_file"
  echo "Godot startup smoke test failed." >&2
  exit 1
fi
rm -f "$log_file"
