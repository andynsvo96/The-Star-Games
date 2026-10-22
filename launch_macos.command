#!/bin/zsh
set -u

PROJECT_DIR="${0:A:h}"
if command -v godot >/dev/null 2>&1; then
  GODOT_BIN="$(command -v godot)"
elif [[ -x "/Applications/Godot.app/Contents/MacOS/Godot" ]]; then
  GODOT_BIN="/Applications/Godot.app/Contents/MacOS/Godot"
else
  echo "Godot 4.7 was not found."
  echo "Install Godot.app in /Applications or add godot to PATH, then run this file again."
  read "?Press Return to close."
  exit 1
fi

exec "$GODOT_BIN" --path "$PROJECT_DIR"
