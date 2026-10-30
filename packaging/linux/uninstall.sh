#!/usr/bin/env bash
# SIGKILL user-local uninstall (pre-alpha): removes exactly the three files ./install.sh put in your home,
#
#   ~/.local/bin/sigkill
#   ~/.local/share/applications/sigkill.desktop
#   ~/.local/share/icons/hicolor/scalable/apps/sigkill.svg
#
# and nothing else: no folder, no other file. A path that is a link or not a plain file, a binary that is not
# a program, or a launcher entry that is not SIGKILL's is left alone and named. The game's settings and
# unlocks stay in ~/.local/share/godot/app_userdata/SIGKILL/; delete that folder yourself to lose them.
#
#   ./uninstall.sh

set -euo pipefail

case "${HOME:-}" in
	/*) ;;
	*) echo "HOME is not set to an absolute folder; nothing removed." >&2; exit 1 ;;
esac

bin="$HOME/.local/bin/sigkill"
desktop="$HOME/.local/share/applications/sigkill.desktop"
icon="$HOME/.local/share/icons/hicolor/scalable/apps/sigkill.svg"

# Whether `path` is the kind of file install.sh puts there.
ours() {
	local path=$1
	[ -f "$path" ] && [ ! -L "$path" ] || return 1
	case "$path" in
		"$bin") [ "$(head -c 4 "$path" | od -An -c | tr -d ' ')" = "177ELF" ] ;;
		"$desktop") grep -qx 'Name=SIGKILL' "$path" ;;
		*) return 0 ;;
	esac
}

for target in "$bin" "$desktop" "$icon"; do
	if [ ! -e "$target" ] && [ ! -L "$target" ]; then
		echo "not there:  $target"
	elif ours "$target"; then
		rm -f -- "$target"
		echo "removed:    $target"
	else
		echo "left alone: $target (not the file install.sh puts there)" >&2
	fi
done
echo "Your settings and unlocks are still in ~/.local/share/godot/app_userdata/SIGKILL/."
