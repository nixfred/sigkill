#!/usr/bin/env bash
# SIGKILL demo-data stills (A1): runs tools/capture_shots.gd on a private virtual display, never on
# the desktop, and leaves the stills in <work-dir>/shots/.
#
#   tools/capture_shots.sh <project-copy> <work-dir> [set]
#
# <project-copy> is a clean copy of the project (`git archive <commit>` into a fresh folder); a
# copy with no import cache is imported headless first. <work-dir> must exist and be empty: the
# display's socket, Godot's user data, settings and caches all live in it, so nothing of the
# player's own is read or written. [set] picks the stills (tools/capture_shots.gd): a1, the default,
# a2, a3, a2b, a4, c27b, c28, a5, i1, i2, i3, c29, c30, c31, c32, c33, c38, c39, c40 or c41. CAPTURE_AT=<s>,<s>,... (c40 and c41 only, an aid for tuning
# the look) shoots the opener at those seconds instead. This script deletes nothing; remove <work-dir> yourself.
#
# Safety: Xvnc on display :97 (CAPTURE_DISPLAY to change it) with no TCP listener at all, its VNC
# side on a unix socket only the owner can open, and a fresh random cookie in <work-dir> as its only
# way in, so no other program can join the display; Godot on X11 only, with no Wayland socket it
# could fall back to, and no sound; Xvnc is stopped by its own PID when the run ends. Demo data only.

set -u -o pipefail

copy=$(cd "${1:-}" 2>/dev/null && pwd) || { echo "usage: $0 <project-copy> <work-dir>" >&2; exit 2; }
work=$(cd "${2:-}" 2>/dev/null && pwd) || { echo "usage: $0 <project-copy> <work-dir>" >&2; exit 2; }
[ -f "$copy/project.godot" ] || { echo "no project.godot in $copy" >&2; exit 2; }
[ -z "$(ls -A "$work")" ] || { echo "$work is not empty" >&2; exit 2; }
shot_set="${3:-a1}"
[[ "$shot_set" =~ ^[a-z0-9]+$ ]] || { echo "the set is a short lowercase word: a1, a2, a3, a2b, a4, c27b, c28, a5, i1, i2, i3, c29, c30, c31, c32, c33, c38, c39, c40 or c41" >&2; exit 2; }
at_arg=()
if [ -n "${CAPTURE_AT:-}" ]; then
	[[ "$CAPTURE_AT" =~ ^[0-9.,]+$ ]] || { echo "CAPTURE_AT is seconds and commas" >&2; exit 2; }
	at_arg=("--at=$CAPTURE_AT")
fi
display="${CAPTURE_DISPLAY:-97}"
# A lock file left by a crashed server names a PID that may be someone else's by now: refuse it.
if [ -e "/tmp/.X11-unix/X$display" ] || [ -e "/tmp/.X$display-lock" ]; then
	echo "display :$display is taken (or its lock file is stale; check /tmp/.X$display-lock)" >&2
	exit 2
fi
for tool in Xvnc godot xauth mcookie; do
	command -v "$tool" >/dev/null || { echo "need $tool" >&2; exit 2; }
done

mkdir -p "$work/data" "$work/config" "$work/cache" "$work/run" "$work/shots"
chmod 700 "$work/run"
(umask 077 && touch "$work/xauthority")
xauth -q -f "$work/xauthority" add ":$display" MIT-MAGIC-COOKIE-1 "$(mcookie)" \
	|| { echo "could not make the display's cookie" >&2; exit 1; }
private=(env -u WAYLAND_DISPLAY -u HYPRLAND_INSTANCE_SIGNATURE XDG_SESSION_TYPE=x11
	XDG_RUNTIME_DIR="$work/run" XDG_DATA_HOME="$work/data" XDG_CONFIG_HOME="$work/config"
	XDG_CACHE_HOME="$work/cache" XAUTHORITY="$work/xauthority")

if [ ! -d "$copy/.godot" ]; then
	"${private[@]}" nice -n 10 godot --headless --path "$copy" --import > "$work/import.log" 2>&1 \
		|| { echo "import failed: see $work/import.log" >&2; exit 1; }
fi

(Xvnc ":$display" -auth "$work/xauthority" -nolisten tcp -rfbport -1 -rfbunixpath "$work/vnc.sock" \
	-rfbunixmode 384 -SecurityTypes None -geometry 1920x1080 -depth 24 > "$work/xvnc.log" 2>&1 &)
for _ in $(seq 1 50); do
	[ -S "/tmp/.X11-unix/X$display" ] && [ -f "/tmp/.X$display-lock" ] && break
	sleep 0.1
done
xvnc_pid=$(tr -d ' \n' < "/tmp/.X$display-lock" 2>/dev/null)
# Only ever stop the server this run started: the PID must be an Xvnc.
[ -n "$xvnc_pid" ] && [ "$(cat "/proc/$xvnc_pid/comm" 2>/dev/null)" = "Xvnc" ] \
	|| { echo "Xvnc did not start: see $work/xvnc.log" >&2; exit 1; }
trap 'kill "$xvnc_pid" 2>/dev/null; for _ in $(seq 1 50); do kill -0 "$xvnc_pid" 2>/dev/null || break; sleep 0.1; done' EXIT

"${private[@]}" DISPLAY=":$display" nice -n 10 timeout 600 godot --display-driver x11 \
	--rendering-driver vulkan --audio-driver Dummy --resolution 1920x1080 --position 0,0 \
	--fixed-fps 60 --path "$copy" --script res://tools/capture_shots.gd -- --demo "--set=$shot_set" "${at_arg[@]}" \
	> "$work/capture.log" 2>&1
status=$?
shots="$work/data/godot/app_userdata/SIGKILL/shots"
[ -d "$shots" ] && mv "$shots"/*.png "$work/shots/" 2>/dev/null
echo "capture exit $status: $(ls "$work/shots" | wc -l) stills in $work/shots"
exit "$status"
