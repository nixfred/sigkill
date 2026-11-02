#!/usr/bin/env bash
# SIGKILL headless quality gate.
#
#   scripts/check.sh          check the repo this script lives in
#   scripts/check.sh <dir>    check another copy of the project (used to prove the gate can fail)
#
# Steps: gdparse every .gd file, headless import, headless run of 300 frames, and the
# headless movement, cannon, derezz, code rain, AI detector, guide adapter, boot sequence,
# guide HUD, model load, round, net, combat, room, weapon, settings, relay, rail, bullet time, WebSocket relay, fork bomb, light trail, code-rain vision, root and sudo, spectate top, fork() shotgun, grep seeker, rm -rf cannon, cron mines, viewmodel, enemy art, arena art, enemy motion, graphics, daemon AI, ping, daemon variety, ICE, ICEbreaker, Black ICE, freeze ray, pipe chain, /dev/null, SIGHUP, unlocks, opener, opener real-data, opener fall, trailer, opener link, opener end, mission, ruins and mission 1 to 7 tests, and (step 63, C43) the audit visor test with the mission tests run again with the visor on, and (step 64, C44) the credits test, and (step 65, W1) the process hunt test, and (step 66, W2) the folder map test, and (step 67, W3) the theme shift test, and (step 68, W4) the keybind gunplay test, and (step 69, W5) the packet tracer test (tests/movement_test.gd,
# tests/cannon_test.gd, tests/derezz_test.gd, tests/code_rain_test.gd,
# tests/ai_detector_test.gd, tests/guide_adapter_test.gd, tests/boot_sequence_test.gd,
# tests/guide_hud_test.gd, tests/model_load_test.gd, tests/round_test.gd,
# tests/net_test.gd, tests/combat_test.gd, tests/room_test.gd, tests/weapon_test.gd,
# tests/settings_test.gd, tests/relay_test.gd, tests/rail_test.gd, tests/bullet_time_test.gd, tests/relay_ws_test.gd, tests/fork_bomb_test.gd, tests/light_trail_test.gd, tests/code_rain_vision_test.gd, tests/root_sudo_test.gd, tests/spectate_top_test.gd, tests/fork_shotgun_test.gd, tests/grep_seeker_test.gd, tests/rm_rf_cannon_test.gd, tests/cron_mines_test.gd, tests/viewmodel_test.gd, tests/enemy_art_test.gd, tests/arena_art_test.gd, tests/enemy_motion_test.gd, tests/graphics_test.gd, tests/daemon_ai_test.gd, tests/ping_test.gd, tests/daemon_variety_test.gd, tests/ice_test.gd, tests/breaker_test.gd, tests/black_ice_test.gd, tests/freeze_ray_test.gd, tests/pipe_chain_test.gd, tests/dev_null_test.gd, tests/sighup_test.gd, tests/unlocks_test.gd, tests/opener_test.gd, tests/opener_real_test.gd, tests/opener_fall_test.gd, tests/trailer_test.gd, tests/opener_link_test.gd, tests/opener_end_test.gd, tests/mission_test.gd, tests/ruins_test.gd, tests/mission1_test.gd, tests/mission2_test.gd, tests/mission3_test.gd, tests/mission4_test.gd, tests/mission5_test.gd, tests/mission6_test.gd, tests/mission7_test.gd, tests/visor_test.gd, tests/credits_test.gd, tests/proc_hunt_test.gd, tests/folder_map_test.gd, tests/theme_shift_test.gd, tests/keybind_test.gd, tests/packet_tracer_test.gd, tests/gamepad_test.gd) at a fixed frame rate. The
# visor test reads a fake process table it builds in its own folder under user:// (fake stat and status files beside
# poisoned ones it must never open; removed at the end), never the machine's own. The AI tests use fakes only: fixture files,
# stub agent CLIs, the fakes in tests/support and fake model servers (a stateful fake
# Ollama for model loading) on 127.0.0.1. No real agent or model server is ever run or
# reached. The settings and unlocks tests keep their settings and progress files in a temporary folder; no headless run
# ever reads or writes the player's own. The opener real-data test reads only a fake home folder it builds in its own
# folder under user:// (fake theme, host and uptime files, a pinned clock) and removes it at the end; never the real one;
# the opener fall test likewise, with fake homes of invented folders (or none) of its own. The trailer test renders
# nothing: it checks the teaser tool's shot list and demo-only rules, keeps its one privacy file in its own folder under
# user:// (never the player's settings), and runs the tool headless, where it refuses to draw. The opener link test (C41)
# plays the opener on invented data with a guide link on a fake detector and stub adapters (the real Claude Code adapter
# only on the stub CLI under tests/fixtures/ai/guide, recording its arguments in the test's own folder under user://,
# removed at the end); no real agent is ever run. The opener end test (C42) plays the forge, the kill and the title on
# invented data, the first launch on settings files in its own folder under user:// (removed at the end; never the
# player's), and the kept AI answer on a stub adapter; it renders the score in code and reads nothing of the machine. The
# mission test (C35) plays the hidden test range and mission 1 in the arena with the scripted guide only (no AI is called),
# keeps its mission and progress saves in its own folder under user:// (removed at the end; never the player's), and
# hosts its one match on 127.0.0.1. The mission 1 test (C37) plays mission 1 through in its ruins with a scripted sure
# shot and the scripted guide only (no AI is called), its saves in its own folder under user:// (removed at the end); the
# mission 2 test (M2) plays mission 2 through in its own district the same way, and the mission 3 to 7 tests (M3 to M7) theirs. The relay test and the WebSocket relay test run the
# relay (relay/) as its own process bound to 127.0.0.1 only, and stop it with its stop file. The net, combat, room, weapon, settings, rail, bullet time, fork bomb, light trail, code-rain vision, root and sudo, spectate top, fork() shotgun, grep seeker, rm -rf cannon, cron mines, daemon AI, ping, daemon variety, ICE, ICEbreaker, Black ICE, freeze ray, pipe chain, /dev/null, SIGHUP and unlocks tests run a host and joiners in this one process over
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
run_godot "enemy motion test" --fixed-fps 60 --script res://tests/enemy_motion_test.gd
run_godot "graphics test" --fixed-fps 60 --script res://tests/graphics_test.gd
run_godot "daemon AI test" --fixed-fps 60 --script res://tests/daemon_ai_test.gd
run_godot "ping test" --fixed-fps 60 --script res://tests/ping_test.gd
run_godot "daemon variety test" --fixed-fps 60 --script res://tests/daemon_variety_test.gd
run_godot "ICE test" --fixed-fps 60 --script res://tests/ice_test.gd
run_godot "ICEbreaker test" --fixed-fps 60 --script res://tests/breaker_test.gd
run_godot "Black ICE test" --fixed-fps 60 --script res://tests/black_ice_test.gd
run_godot "freeze ray test" --fixed-fps 60 --script res://tests/freeze_ray_test.gd
run_godot "pipe chain test" --fixed-fps 60 --script res://tests/pipe_chain_test.gd
run_godot "dev null test" --fixed-fps 60 --script res://tests/dev_null_test.gd
run_godot "SIGHUP test" --fixed-fps 60 --script res://tests/sighup_test.gd
run_godot "unlocks test" --fixed-fps 60 --script res://tests/unlocks_test.gd
run_godot "opener test" --fixed-fps 60 --script res://tests/opener_test.gd
run_godot "opener real-data test" --fixed-fps 60 --script res://tests/opener_real_test.gd
run_godot "opener fall test" --fixed-fps 60 --script res://tests/opener_fall_test.gd
run_godot "trailer test" --fixed-fps 60 --script res://tests/trailer_test.gd
run_godot "opener link test" --fixed-fps 60 --script res://tests/opener_link_test.gd
run_godot "opener end test" --fixed-fps 60 --script res://tests/opener_end_test.gd
run_godot "mission test" --fixed-fps 60 --script res://tests/mission_test.gd
run_godot "ruins test" --fixed-fps 60 --script res://tests/ruins_test.gd
run_godot "mission 1 test" --fixed-fps 60 --script res://tests/mission1_test.gd
run_godot "mission 2 test" --fixed-fps 60 --script res://tests/mission2_test.gd
run_godot "mission 3 test" --fixed-fps 60 --script res://tests/mission3_test.gd
run_godot "mission 4 test" --fixed-fps 60 --script res://tests/mission4_test.gd
run_godot "mission 5 test" --fixed-fps 60 --script res://tests/mission5_test.gd
run_godot "mission 6 test" --fixed-fps 60 --script res://tests/mission6_test.gd
run_godot "mission 7 test" --fixed-fps 60 --script res://tests/mission7_test.gd

# 63. The Audit Trail visor (C43): its own test, then the seven mission tests again with the visor on from the start
# (--visor, which every arena of the run takes): each mission still completes, its cards fire and the ending plays once
# with the visor drawing throughout, and each run's visor says it drew (its "audit visor: on" line, most lines > 0).
# One step: it passes only when all eight runs are clean.
visor_step() {
	local label="audit visor test, and missions 1 to 7 again with the visor on"
	local out rc bad=0 n
	out=$(nice -n 10 timeout 300 godot --headless --path "$root" --fixed-fps 60 --script res://tests/visor_test.gd 2>&1)
	rc=$?
	if [ "$rc" -ne 0 ] || grep -E -q "$ERROR_PATTERN" <<<"$out"; then
		fail "$label: the visor test: exit $rc or error lines"
		grep -E "^FAIL|$ERROR_PATTERN" <<<"$out" | head -20 >&2
		printf '%s\n' "$out" | tail -5 >&2
		bad=1
	fi
	for n in 1 2 3 4 5 6 7; do
		out=$(nice -n 10 timeout 300 godot --headless --path "$root" --fixed-fps 60 --script "res://tests/mission${n}_test.gd" -- --visor 2>&1)
		rc=$?
		if [ "$rc" -ne 0 ] || grep -E -q "$ERROR_PATTERN" <<<"$out"; then
			fail "$label: mission $n with the visor on: exit $rc or error lines"
			grep -E "^FAIL|$ERROR_PATTERN" <<<"$out" | head -20 >&2
			bad=1
		elif ! grep -E -q '^audit visor: on \(--visor\): most lines [1-9]' <<<"$out"; then
			fail "$label: mission $n: the visor never drew"
			bad=1
		fi
	done
	if [ "$bad" -eq 0 ]; then
		ok "$label: exit 0, no error lines, the visor drew in every run"
	fi
}
visor_step

# 64. The credits roll (C44): the roll after the ending, once per ending and nowhere else, its last row, every
# contributor CREDITS.md names, skip and the way back to the menu, the Esc menu's replay locked until the ending.
run_godot "credits test" --fixed-fps 60 --script res://tests/credits_test.gd

# 65. Live process enemies (W1): the process hunt on fake tables only (the mapping's fixtures, the demo table, a fake
# process table under the test's folder): a pegged core a boss, a browser's tabs a swarm, the rest daemons; forks and
# exits following the table; the caps; the real layer off by default, reading only stat and status; kills simulated, no
# signal, kill or execute path anywhere in its code; the visor's lineage over live enemies.
run_godot "process hunt test" --fixed-fps 60 --script res://tests/proc_hunt_test.gd

# 66. Filesystem maps (W2): the folder map on fake folder trees only (the game's own demo home, folders made up in the
# test, a fake home under the test's folder): folders as rooms, a room's height and scale from its size, its business
# from its files, subfolders as doors; node_modules as the maze (every cell reachable, its way out, its ways down,
# endless); the reader's caps (depth, entries, time, the frame's budget), hidden folders skipped, links never followed
# out of the root, no file opened, nothing changed; the real layer off by default; nothing in the map able to write,
# remove, rename, move or run anything; through a door and back, into the maze and out; the visor's breadcrumb.
run_godot "folder map test" --fixed-fps 60 --script res://tests/folder_map_test.gd

# 67. Theme-shift levels (W3): the game's own six palettes only (the real layer never turned on; its reader tried on a
# made-up theme file under the test's folder): every palette loads whole and credited, the grade takes the game's colours
# to the theme's own and recolours every themed surface (one grade over the 3D view, the HUD and the menu), each theme
# its own district; palette-only daemons shown exactly in their own palette, concealed in the others with their tells
# (ripple, chirp, the visor's box), never hitting or hit while concealed; the shift's tear running and completing, the
# register with it, lurkers waking and the old theme's conceal hiding; the next theme's world after the reload; the
# results card; the tear over a reload; the real layer off by default and reading only colour values; nothing in the
# mode able to write, switch or run anything.
run_godot "theme shift test" --fixed-fps 60 --script res://tests/theme_shift_test.gd

# 68. Keybind gunplay (W4): the game's own built-in shortcut table only (the real layer never turned on; its reader tried
# on made-up bind files under the test's folder): every drill's chord resolves to its Omarchy shortcut and meaning, the
# stand-in for Super collides with no game key, no Ctrl+Alt combo anywhere, every card's text matches the table; the
# chord holding the player and the game's own actions while it is held; each shortcut's effect (a terminal blasting
# open, a window folding shut, a split, a float and its tile, full screen, a workspace) through the drills, the waves and
# the results card; the visor's windows; the real layer off by default and reading only combos and action names; nothing
# in the mode able to call the compositor, send a key press, write, switch or run anything; the arena's keys unchanged.
run_godot "keybind gunplay test" --fixed-fps 60 --script res://tests/keybind_test.gd

# 69. The packet tracer (W5): the game's own invented network only (no real layer exists): every machine name and
# address shown anywhere in the mode the table's own (a made-up subnet); nothing in the mode able to open a socket,
# resolve a name, run a program, touch a file or the input map; no new key (the burst is the jump, again is Enter) and no
# Ctrl+Alt combo; the arena standing in the network; a port boarding a packet and the ride carrying the player across,
# fire free; a drop under the rider survivable (the fall, the retransmit, a little hurt) and dodgeable (a torn link
# refused, a burst outrunning the tear); the route held by an island's fighters, a retransmit swarm sent again, a
# man-in-the-middle holding a packet, a stale route sending it the wrong way; the SYN flood, the results card, Enter's
# again; a fall off an island retransmitted; the visor's route; the Esc menu's entry; the arena's keys unchanged.
run_godot "packet tracer test" --fixed-fps 60 --script res://tests/packet_tracer_test.gd

# 70. Gamepad: every pad button and axis in the input map once, for any pad, behind each action's key or mouse button,
# and kept through a rebind and a reset; pads ignored while the window is unfocused; then through real pad events into
# the real player, the left stick moves, A jumps, RB draws the next weapon, a wavering held trigger fires as many shots
# as a held click, and Start opens the menu and closes it; in the menu the D-pad and the left stick move focus, A presses, and B backs
# out of Missions, a rebind's wait and the menu.
run_godot "gamepad test" --fixed-fps 60 --script res://tests/gamepad_test.gd

if [ "$failures" -ne 0 ]; then
	printf 'CHECK FAILED: %d problem(s)\n' "$failures" >&2
	exit 1
fi
echo "CHECK PASSED"
