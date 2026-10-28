#!/usr/bin/env bash
# SIGKILL headless quality gate.
#
#   scripts/check.sh          check the repo this script lives in
#   scripts/check.sh <dir>    check another copy of the project (used to prove the gate can fail)
#
# Steps: gdparse every .gd file, headless import, headless run of 300 frames, and the
# headless movement, cannon, derezz, code rain, AI detector, guide adapter, boot sequence,
# guide HUD, model load, round, net, combat, room, weapon, settings, relay, rail, bullet time, WebSocket relay, fork bomb, light trail, code-rain vision, root and sudo, spectate top, fork() shotgun, grep seeker, rm -rf cannon, cron mines, viewmodel, enemy art and arena art tests (tests/movement_test.gd,
# tests/cannon_test.gd, tests/derezz_test.gd, tests/code_rain_test.gd,
# tests/ai_detector_test.gd, tests/guide_adapter_test.gd, tests/boot_sequence_test.gd,
# tests/guide_hud_test.gd, tests/model_load_test.gd, tests/round_test.gd,
# tests/net_test.gd, tests/combat_test.gd, tests/room_test.gd, tests/weapon_test.gd,
# tests/settings_test.gd, tests/relay_test.gd, tests/rail_test.gd, tests/bullet_time_test.gd, tests/relay_ws_test.gd, tests/fork_bomb_test.gd, tests/light_trail_test.gd, tests/code_rain_vision_test.gd, tests/root_sudo_test.gd, tests/spectate_top_test.gd, tests/fork_shotgun_test.gd, tests/grep_seeker_test.gd, tests/rm_rf_cannon_test.gd, tests/cron_mines_test.gd, tests/viewmodel_test.gd, tests/enemy_art_test.gd, tests/arena_art_test.gd) at a fixed frame rate. The AI tests use fakes only: fixture files,
# stub agent CLIs, the fakes in tests/support and fake model servers (a stateful fake
# Ollama for model loading) on 127.0.0.1. No real agent or model server is ever run or
# reached. The settings test keeps its settings files in a temporary folder; no headless run
# ever reads or writes the player's own. The relay test and the WebSocket relay test run the
# relay (relay/) as its own process bound to 127.0.0.1 only, and stop it with its stop file. The net, combat, room, weapon, settings, rail, bullet time, fork bomb, light trail, code-rain vision, root and sudo, spectate top, fork() shotgun, grep seeker, rm -rf cannon and cron mines tests run a host and joiners in this one process over
# ENet on 127.0.0.1 only, on ports the system hands out; the room test's fake rendezvous
# is on 127.0.0.1 too. The main scene is the boot screen; under --headless, with
# nothing handed in, it skips the AI link and goes straight to the arena, so the 300-frame
# run makes no call and still runs the arena.
# All steps always run, so one invocation shows everything that is wrong.
# Exit 0 only when every step is clean. Exit 1 on any parse error, any ERROR or
# SCRIPT ERROR line, or a nonzero Godot exit code. Exit 2 means the gate itself
# could not run (missing tool or project).
#
# Safety: every Godot call is --headless, so no window or editor ever opens and no
# GPU is used. The script only reads the project. Godot writes its cache to .godot/,
# which git ignores.

set -u -o pipefail

ERROR_PATTERN='SCRIPT ERROR|Parse Error|ERROR'

here=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
root=$(cd "${1:-$here/..}" 2>/dev/null && pwd) || { echo "FAIL: project dir not found: ${1:-}" >&2; exit 2; }
[ -f "$root/project.godot" ] || { echo "FAIL: no project.godot in $root" >&2; exit 2; }
cd "$root" || exit 2

command -v godot >/dev/null || { echo "FAIL: godot not found on PATH" >&2; exit 2; }
for tool in nice timeout grep find sort head tail; do
	command -v "$tool" >/dev/null || { echo "FAIL: required tool not found on PATH: $tool" >&2; exit 2; }
done
if command -v gdparse >/dev/null; then
	parse=(gdparse)
elif command -v uvx >/dev/null; then
	parse=(uvx --quiet --from 'gdtoolkit==4.*' gdparse)
else
	echo "FAIL: need gdparse (gdtoolkit 4) or uvx on PATH" >&2
	exit 2
fi

failures=0
fail() { printf 'FAIL: %s\n' "$*" >&2; failures=$((failures + 1)); }
ok() { printf 'ok:   %s\n' "$*"; }

# 1. Syntax: gdparse every script.
mapfile -t scripts < <(find . -name '*.gd' -not -path './.godot/*' -not -path './.git/*' | sort)
if [ "${#scripts[@]}" -eq 0 ]; then
	fail "no .gd files found"
elif out=$("${parse[@]}" "${scripts[@]}" 2>&1); then
	ok "gdparse: ${#scripts[@]} scripts parse"
else
	fail "gdparse reported syntax errors"
	printf '%s\n' "$out" >&2
fi

# 2 and 3. Godot, headless: import, then run 300 frames of the main scene (the boot
# screen, which a headless run sends straight to the arena).
run_godot() {
	local label=$1
	shift
	local out rc bad=0
	out=$(nice -n 10 timeout 300 godot --headless --path "$root" "$@" 2>&1)
	rc=$?
	if [ "$rc" -ne 0 ]; then
		fail "$label: godot exit code $rc"
		bad=1
	fi
	# Here-string, not `printf | grep -q`: with pipefail, grep -q exits at the first match,
	# printf then dies of SIGPIPE on large output, and the test would report a false pass.
	if grep -E -q "$ERROR_PATTERN" <<<"$out"; then
		fail "$label: error lines in Godot output"
		printf '%s\n' "$out" | grep -E "$ERROR_PATTERN" | head -20 >&2
		bad=1
	fi
	if [ "$bad" -eq 0 ]; then
		ok "$label: exit 0, no error lines"
	else
		# Every FAIL line of the step first (a flaky check is named even when it is not in the
		# tail), then the tail.
		grep -E '^FAIL' <<<"$out" >&2
		printf '%s\n' "$out" | tail -15 >&2
	fi
}

run_godot "import" --import
run_godot "run 300 frames" --quit-after 300
run_godot "movement test" --fixed-fps 60 --script res://tests/movement_test.gd
run_godot "cannon test" --fixed-fps 60 --script res://tests/cannon_test.gd
run_godot "derezz test" --fixed-fps 60 --script res://tests/derezz_test.gd
run_godot "code rain test" --fixed-fps 60 --script res://tests/code_rain_test.gd
run_godot "AI detector test" --fixed-fps 60 --script res://tests/ai_detector_test.gd
run_godot "guide adapter test" --fixed-fps 60 --script res://tests/guide_adapter_test.gd
run_godot "boot sequence test" --fixed-fps 60 --script res://tests/boot_sequence_test.gd
run_godot "guide HUD test" --fixed-fps 60 --script res://tests/guide_hud_test.gd
run_godot "model load test" --fixed-fps 60 --script res://tests/model_load_test.gd
run_godot "round test" --fixed-fps 60 --script res://tests/round_test.gd
run_godot "net test" --fixed-fps 60 --script res://tests/net_test.gd
run_godot "combat test" --fixed-fps 60 --script res://tests/combat_test.gd
run_godot "room test" --fixed-fps 60 --script res://tests/room_test.gd
run_godot "weapon test" --fixed-fps 60 --script res://tests/weapon_test.gd
run_godot "settings test" --fixed-fps 60 --script res://tests/settings_test.gd
run_godot "relay test" --fixed-fps 60 --script res://tests/relay_test.gd
run_godot "rail test" --fixed-fps 60 --script res://tests/rail_test.gd
run_godot "bullet time test" --fixed-fps 60 --script res://tests/bullet_time_test.gd
run_godot "WebSocket relay test" --fixed-fps 60 --script res://tests/relay_ws_test.gd
run_godot "fork bomb test" --fixed-fps 60 --script res://tests/fork_bomb_test.gd
run_godot "light trail test" --fixed-fps 60 --script res://tests/light_trail_test.gd
run_godot "code-rain vision test" --fixed-fps 60 --script res://tests/code_rain_vision_test.gd
run_godot "root and sudo test" --fixed-fps 60 --script res://tests/root_sudo_test.gd
run_godot "spectate top test" --fixed-fps 60 --script res://tests/spectate_top_test.gd
run_godot "fork() shotgun test" --fixed-fps 60 --script res://tests/fork_shotgun_test.gd
run_godot "grep seeker test" --fixed-fps 60 --script res://tests/grep_seeker_test.gd
run_godot "rm -rf cannon test" --fixed-fps 60 --script res://tests/rm_rf_cannon_test.gd
run_godot "cron mines test" --fixed-fps 60 --script res://tests/cron_mines_test.gd
run_godot "viewmodel test" --fixed-fps 60 --script res://tests/viewmodel_test.gd
run_godot "enemy art test" --fixed-fps 60 --script res://tests/enemy_art_test.gd
run_godot "arena art test" --fixed-fps 60 --script res://tests/arena_art_test.gd

if [ "$failures" -ne 0 ]; then
	printf 'CHECK FAILED: %d problem(s)\n' "$failures" >&2
	exit 1
fi
echo "CHECK PASSED"
