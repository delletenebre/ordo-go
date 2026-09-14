#!/bin/sh
set -eu
ordo_dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
ordo_engine=${GODOT:-}
if [ -z "$ordo_engine" ]; then
  if command -v godot >/dev/null 2>&1; then ordo_engine=$(command -v godot)
  elif command -v godot4 >/dev/null 2>&1; then ordo_engine=$(command -v godot4)
  elif [ -x /Applications/Godot.app/Contents/MacOS/Godot ]; then ordo_engine=/Applications/Godot.app/Contents/MacOS/Godot
  elif [ -x "$HOME/Downloads/Godot.app/Contents/MacOS/Godot" ]; then ordo_engine="$HOME/Downloads/Godot.app/Contents/MacOS/Godot"
  else echo 'Укажите GODOT=/path/to/godot или откройте project.godot в редакторе.'; exit 1
  fi
fi
exec "$ordo_engine" --path "$ordo_dir" "$@"
