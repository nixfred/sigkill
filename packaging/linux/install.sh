#!/usr/bin/env bash
# SIGKILL user-local install (pre-alpha). Run it from the unpacked release folder:
#
#   ./install.sh
#
# Copies three files into your own home, and nothing anywhere else:
#
#   sigkill.x86_64   ->  ~/.local/bin/sigkill
#   sigkill.desktop  ->  ~/.local/share/applications/sigkill.desktop   (Exec and TryExec point at the line above)
#   sigkill.svg      ->  ~/.local/share/icons/hicolor/scalable/apps/sigkill.svg
#
# No sudo, no system folders, no MIME or link handlers, nothing run and nothing else changed (it makes
# those three folders if they are missing). Running it again replaces the three files with this folder's.
# ./uninstall.sh removes exactly those three files. The game keeps its settings and unlocks in
# ~/.local/share/godot/app_userdata/SIGKILL/, which neither script touches.

set -euo pipefail

here=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)

if [ "$(id -u)" -eq 0 ]; then
	echo "Run ./install.sh as yourself, not as root: it installs into your own home only." >&2
	exit 1
fi
case "${HOME:-}" in
	/*) ;;
	*) echo "HOME is not set to an absolute folder; nothing installed." >&2; exit 1 ;;
esac
# The launcher entry names the binary by its full path; a path with these characters would need escaping.
case "$HOME" in
	*[\"\`\$\\%]* | *$'\n'*) echo "Your home folder's path has a character a launcher entry cannot hold (\" \` \$ \\ %); nothing installed. Run $here/sigkill.x86_64 directly instead." >&2; exit 1 ;;
esac

bin="$HOME/.local/bin/sigkill"
desktop="$HOME/.local/share/applications/sigkill.desktop"
icon="$HOME/.local/share/icons/hicolor/scalable/apps/sigkill.svg"

for file in sigkill.x86_64 sigkill.desktop sigkill.svg; do
	if [ ! -f "$here/$file" ]; then
		echo "Missing $file next to install.sh: run it from the unpacked release folder. Nothing installed." >&2
		exit 1
	fi
done
for target in "$bin" "$desktop" "$icon"; do
	if [ -L "$target" ] || { [ -e "$target" ] && [ ! -f "$target" ]; }; then
		echo "$target is there and is not a plain file, so it is left alone and nothing is installed. Move it away and run ./install.sh again." >&2
		exit 1
	fi
done

mkdir -p "${bin%/*}" "${desktop%/*}" "${icon%/*}"
install -m 755 "$here/sigkill.x86_64" "$bin"
install -m 644 "$here/sigkill.svg" "$icon"
# A launcher entry cannot use ~ or $HOME, so Exec and TryExec get the binary's full path.
staged="$desktop.installing"
while IFS= read -r line || [ -n "$line" ]; do
	case "$line" in
		Exec=*) printf 'Exec="%s"\n' "$bin" ;;
		TryExec=*) printf 'TryExec=%s\n' "$bin" ;;
		*) printf '%s\n' "$line" ;;
	esac
done < "$here/sigkill.desktop" > "$staged"
chmod 644 "$staged"
mv -f "$staged" "$desktop"

echo "Installed SIGKILL:"
echo "  $bin"
echo "  $desktop"
echo "  $icon"
case ":$PATH:" in
	*":$HOME/.local/bin:"*) echo "Start it from your app launcher, or type: sigkill" ;;
	*) echo "Start it from your app launcher, or run: $bin   (~/.local/bin is not on your PATH)" ;;
esac
