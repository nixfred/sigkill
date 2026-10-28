#!/usr/bin/env bash
# SIGKILL: play from source.
#
#   scripts/play.sh                  the game, from the boot screen
#   scripts/play.sh -- --demo        launch options after --, as with `godot --path .` (see the README)
#
# A fresh clone has no import cache yet, so the first run imports the project once, headless, then
# launches. Nothing is installed or changed outside the project: Godot keeps its cache in .godot/,
# which git ignores.

set -u -o pipefail

root=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd) || exit 2
command -v godot >/dev/null || { echo "Godot 4 is not on PATH: sudo pacman -S --needed godot" >&2; exit 2; }

if [ ! -f "$root/.godot/global_script_class_cache.cfg" ]; then
	echo "First run: importing the project once (headless, about a minute)..."
	godot --headless --path "$root" --import > /dev/null 2>&1 || { echo "the import failed; run: godot --headless --path \"$root\" --import" >&2; exit 1; }
fi
exec godot --path "$root" "$@"
