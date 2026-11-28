#!/usr/bin/env bash
set -u

if [ "$#" -ne 1 ]; then
  echo "Usage: $0 res://path/to/test.gd" >&2
  exit 2
fi

log_file="$(mktemp)"
godot --headless --path . --script "$1" >"$log_file" 2>&1
status=$?
cat "$log_file"
if [ "$status" -ne 0 ] || grep -Eq 'SCRIPT ERROR:|Parse Error:|Compile Error:|Failed to load script|FAIL ' "$log_file"; then
  rm -f "$log_file"
  echo "Godot test failed: $1" >&2
  exit 1
fi
rm -f "$log_file"
