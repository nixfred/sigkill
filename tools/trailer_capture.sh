#!/usr/bin/env bash
# SIGKILL teaser footage (T1): renders the shot list of tools/trailer.gd with Godot's Movie Maker on a
# private virtual display, one clip a shot, demo data only, and writes shots.json beside the clips.
#
#   tools/trailer_capture.sh <work-dir> [shot-id ...]
#
# It renders from a clean copy of this repository's HEAD (TRAILER_COMMIT=<ref> picks another), made with
# `git archive` into <work-dir>/src-<commit>, so nothing but committed files goes in. With no shot ids it
# renders every shot; ids render just those (`tools/trailer_capture.sh <work-dir> --list` lists them).
# <work-dir> must exist and be empty, or be one this script made before (it keeps a marker file in it).
#
# What it leaves in <work-dir>:
#   out/<id>.mp4      the clip: H.264 1920x1080 at 60 fps, the game's own sound as AAC 48 kHz stereo
#   out/shots.json    every clip in the running order: its file, where it starts and ends in that order,
#                     its length, a line on what is in it and its loudest moments (from its own sound)
#   out/sheets/<id>.png  eight frames of the clip side by side, to judge it at a glance
#   movies/<id>.avi   the raw take, Movie Maker's own (Motion JPEG and PCM), warm-up included
#   logs/<id>.log     Godot's output for the take
#   runs/<stamp>-<id>/   that take's fresh, empty user data, settings and caches
# This script deletes nothing; remove <work-dir> yourself when done.
#
# Safety, as tools/capture_shots.sh: Xvnc on display :98 (TRAILER_DISPLAY to change it) with no TCP
# listener, its VNC side on a unix socket only the owner can open, a fresh random cookie as its only way
# in; Godot on X11 only, with no Wayland socket it could reach, an empty private XDG_RUNTIME_DIR and fresh
# user data each take, so no player settings, progress or opener data are read. Movie Maker mixes the
# sound into the file and plays nothing aloud. Demo data only: tools/trailer.gd refuses to run with the
# opener's real data on, without --demo, or headless. Xvnc is stopped by its own PID when the run ends.

set -u -o pipefail

here=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
repo=$(cd "$here/.." && pwd)
usage() { echo "usage: $0 <work-dir> [shot-id ...]   (or: $0 <work-dir> --list)" >&2; exit 2; }
work=$(cd "${1:-}" 2>/dev/null && pwd) || usage
shift
marker="$work/.sigkill-trailer"
if [ -n "$(ls -A "$work")" ] && [ ! -f "$marker" ]; then
	echo "$work is not empty and is not a trailer work folder" >&2
	exit 2
fi
for tool in git tar Xvnc godot xauth mcookie ffmpeg ffprobe jq awk; do
	command -v "$tool" >/dev/null || { echo "need $tool" >&2; exit 2; }
done
touch "$marker"

commit=$(git -C "$repo" rev-parse --verify "${TRAILER_COMMIT:-HEAD}^{commit}") || { echo "no such commit" >&2; exit 2; }
short=${commit:0:12}
src="$work/src-$short"
if [ ! -f "$src/project.godot" ]; then
	mkdir -p "$src"
	git -C "$repo" archive "$commit" | tar -x -C "$src" || { echo "git archive failed" >&2; exit 1; }
	# This copy only, never the repo: Movie Maker's Motion JPEG at near its best (the default is 0.75), and the
	# window's base size 1920x1080 (Movie Maker records the project's base size; --resolution alone is not enough).
	printf '[display]\n\nwindow/size/viewport_width=1920\nwindow/size/viewport_height=1080\n\n[editor]\n\nmovie_writer/video_quality=0.95\n' > "$src/override.cfg"
fi
mkdir -p "$work/movies" "$work/logs" "$work/runs" "$work/out/sheets" "$work/headless"
chmod 700 "$work/runs"
# Headless runs (the import and the list) get fresh private folders too: nothing of the player's is read.
quiet=(env -u WAYLAND_DISPLAY -u HYPRLAND_INSTANCE_SIGNATURE -u DISPLAY XDG_DATA_HOME="$work/headless/data"
	XDG_CONFIG_HOME="$work/headless/config" XDG_CACHE_HOME="$work/headless/cache")
if [ ! -d "$src/.godot" ]; then
	"${quiet[@]}" nice -n 10 godot --headless --path "$src" --import > "$work/logs/import.log" 2>&1 \
		|| { echo "import failed: see $work/logs/import.log" >&2; exit 1; }
fi
mapfile -t all < <("${quiet[@]}" godot --headless --path "$src" --script res://tools/trailer.gd -- --list 2>/dev/null | sed -n 's/^trailer: shot //p')
[ "${#all[@]}" -gt 0 ] || { echo "tools/trailer.gd listed no shots" >&2; exit 1; }
if [ "${1:-}" = "--list" ]; then
	printf '%s\n' "${all[@]}"
	exit 0
fi
shots=("$@")
[ "${#shots[@]}" -gt 0 ] || shots=("${all[@]}")
for id in "${shots[@]}"; do
	printf '%s\n' "${all[@]}" | grep -qx -- "$id" || { echo "no shot named $id (see --list)" >&2; exit 2; }
done

display="${TRAILER_DISPLAY:-98}"
if [ -e "/tmp/.X11-unix/X$display" ] || [ -e "/tmp/.X$display-lock" ]; then
	echo "display :$display is taken (or its lock file is stale; check /tmp/.X$display-lock)" >&2
	exit 2
fi
auth="$work/xauthority"
(umask 077 && : > "$auth")
xauth -q -f "$auth" add ":$display" MIT-MAGIC-COOKIE-1 "$(mcookie)" || { echo "could not make the display's cookie" >&2; exit 1; }
(Xvnc ":$display" -auth "$auth" -nolisten tcp -rfbport -1 -rfbunixpath "$work/vnc.sock" -rfbunixmode 384 \
	-SecurityTypes None -geometry 1920x1080 -depth 24 > "$work/logs/xvnc.log" 2>&1 &)
for _ in $(seq 1 50); do
	[ -S "/tmp/.X11-unix/X$display" ] && [ -f "/tmp/.X$display-lock" ] && break
	sleep 0.1
done
xvnc_pid=$(tr -d ' \n' < "/tmp/.X$display-lock" 2>/dev/null)
# Only ever stop the server this run started: the PID must be an Xvnc.
[ -n "$xvnc_pid" ] && [ "$(cat "/proc/$xvnc_pid/comm" 2>/dev/null)" = "Xvnc" ] \
	|| { echo "Xvnc did not start: see $work/logs/xvnc.log" >&2; exit 1; }
trap 'kill "$xvnc_pid" 2>/dev/null; for _ in $(seq 1 50); do kill -0 "$xvnc_pid" 2>/dev/null || break; sleep 0.1; done' EXIT

# One take: a fresh Godot with fresh user data, the shot played once under Movie Maker, then the frames
# between the shot's own roll and cut marks kept (the warm-up before them is the shaders compiling).
take() {
	local id=$1 run log movie roll cut
	run="$work/runs/$(date +%Y%m%d-%H%M%S)-$id"
	mkdir -p "$run/data" "$run/config" "$run/cache" "$run/xdg"
	chmod 700 "$run/xdg"
	log="$work/logs/$id.log"
	movie="$work/movies/$id.avi"
	env -u WAYLAND_DISPLAY -u HYPRLAND_INSTANCE_SIGNATURE XDG_SESSION_TYPE=x11 XDG_RUNTIME_DIR="$run/xdg" \
		XDG_DATA_HOME="$run/data" XDG_CONFIG_HOME="$run/config" XDG_CACHE_HOME="$run/cache" XAUTHORITY="$auth" \
		DISPLAY=":$display" nice -n 10 timeout 1800 godot --display-driver x11 --rendering-driver vulkan \
		--resolution 1920x1080 --position 0,0 --fixed-fps 60 --write-movie "$movie" --path "$src" \
		--script res://tools/trailer.gd -- --demo "--shot=$id" > "$log" 2>&1
	local status=$?
	roll=$(sed -n 's/^trailer: roll at frame \([0-9]*\)$/\1/p' "$log" | tail -1)
	cut=$(sed -n 's/^trailer: cut at frame \([0-9]*\)$/\1/p' "$log" | tail -1)
	if [ "$status" -ne 0 ] || [ -z "$roll" ] || [ -z "$cut" ] || [ "$cut" -le "$roll" ]; then
		echo "$id: take failed (exit $status, roll ${roll:-none}, cut ${cut:-none}): see $log" >&2
		grep -E 'trailer: refused|SCRIPT ERROR|ERROR' "$log" | head -5 >&2
		return 1
	fi
	local meta="$run/data/godot/app_userdata/SIGKILL/trailer/$id.json"
	[ -f "$meta" ] || { echo "$id: the take wrote no $id.json" >&2; return 1; }
	cp "$meta" "$work/out/.$id.take.json"
	# 48 kHz at 60 fps: 800 samples a frame.
	ffmpeg -v error -y -i "$movie" \
		-vf "trim=start_frame=$roll:end_frame=$cut,setpts=PTS-STARTPTS" \
		-af "atrim=start_sample=$((roll * 800)):end_sample=$((cut * 800)),asetpts=PTS-STARTPTS" \
		-c:v libx264 -preset slow -crf 14 -pix_fmt yuv420p -profile:v high -r 60 -g 30 \
		-c:a aac -b:a 320k -ar 48000 -ac 2 -movflags +faststart "$work/out/$id.mp4" \
		|| { echo "$id: encoding failed" >&2; return 1; }
	local format
	format=$(ffprobe -v error -show_entries stream=codec_type,width,height,r_frame_rate -of csv=p=0 "$work/out/$id.mp4" | sort | tr '\n' ' ')
	[ "$format" = "audio,0/0 video,1920,1080,60/1 " ] || { echo "$id: the clip is not 1920x1080 at 60 fps with sound: $format" >&2; return 1; }
	# The loudest moments: the sound's peak in every frame's 800 samples, the top six at least 0.3 s apart
	# and within 24 dB of the loudest.
	ffmpeg -v error -i "$work/out/$id.mp4" -vn \
		-af "asetnsamples=n=800:p=0,astats=metadata=1:reset=1,ametadata=print:key=lavfi.astats.Overall.Peak_level:file=-" \
		-f null - 2>/dev/null \
		| awk '/pts_time:/ { split($0, a, "pts_time:"); t = a[2] + 0 } /Peak_level=/ { split($0, b, "="); v = b[2]; if (v != "-inf") print t, v + 0 }' \
		| sort -k2,2gr \
		| awk 'NR == 1 { top = $2 } { if ($2 < top - 24) exit; ok = 1; for (i = 1; i <= n; i++) if ((ts[i] - $1) ^ 2 < 0.09) ok = 0; if (ok) { n++; ts[n] = $1; printf "{\"t\":%.3f,\"peak_db\":%.1f}\n", $1, $2 } if (n == 6) exit }' \
		| jq -s 'sort_by(.t)' > "$work/out/.$id.peaks.json"
	local frames
	frames=$(ffprobe -v error -count_frames -select_streams v:0 -show_entries stream=nb_read_frames -of csv=p=0 "$work/out/$id.mp4")
	ffmpeg -v error -y -i "$work/out/$id.mp4" -vf "select='not(mod(n\,$(( (frames + 7) / 8 ))))',scale=480:-1,tile=8x1" \
		-frames:v 1 -update 1 "$work/out/sheets/$id.png" || true
	echo "$id: $((cut - roll)) frames, $(du -h "$work/out/$id.mp4" | cut -f1)"
}

failed=0
for id in "${shots[@]}"; do
	take "$id" || failed=$((failed + 1))
done

# shots.json: every clip there is in out/, in the shot list's order, laid end to end.
{
	for id in "${all[@]}"; do
		[ -f "$work/out/$id.mp4" ] && [ -f "$work/out/.$id.take.json" ] || continue
		jq -n --arg file "$id.mp4" --argjson take "$(cat "$work/out/.$id.take.json")" \
			--argjson peaks "$(cat "$work/out/.$id.peaks.json" 2>/dev/null || echo '[]')" \
			--arg duration "$(ffprobe -v error -show_entries format=duration -of csv=p=0 "$work/out/$id.mp4")" \
			--arg bytes "$(stat -c %s "$work/out/$id.mp4")" \
			'{file: $file, id: $take.id, description: $take.description, duration: ($duration | tonumber), bytes: ($bytes | tonumber),
			  loudest: [$peaks[] | . as $p | $p + {sounds: [$take.sounds[] | select(.t >= $p.t - 0.12 and .t <= $p.t + 0.02) | .name] | unique}],
			  events: $take.events}'
	done
} | jq -s 'reduce .[] as $c ({at: 0, clips: []}; .clips += [$c + {start: (.at * 1000 | round / 1000), end: ((.at + $c.duration) * 1000 | round / 1000)}] | .at += $c.duration)
	| {about: "SIGKILL teaser footage (T1): real in-game clips on demo data, rendered by tools/trailer_capture.sh. start and end place each clip in the running order; loudest are the peaks of its own sound (seconds into the clip) with the sounds that started just before.", commit: $commit, fps: 60, width: 1920, height: 1080, total: (.at * 1000 | round / 1000), clips: .clips}' \
	--arg commit "$commit" > "$work/out/shots.json"
echo "trailer: $(jq '.clips | length' "$work/out/shots.json") clips, $(jq .total "$work/out/shots.json") s, in $work/out (shots.json); $failed failed"
[ "$failed" -eq 0 ]
