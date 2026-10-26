#!/usr/bin/env bash
# SIGKILL headless quality gate.
#
#   scripts/check.sh          check the repo this script lives in
#   scripts/check.sh <dir>    check another copy of the project (used to prove the gate can fail)
#
# Steps: gdparse every .gd file, headless import, headless run of 300 frames, and the
# headless movement, cannon and derezz tests (tests/movement_test.gd, tests/cannon_test.gd,
# tests/derezz_test.gd) at a fixed frame rate.
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

# 2 and 3. Godot, headless: import, then run 300 frames of the main scene.
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
		printf '%s\n' "$out" | tail -15 >&2
	fi
}

run_godot "import" --import
run_godot "run 300 frames" --quit-after 300
run_godot "movement test" --fixed-fps 60 --script res://tests/movement_test.gd
run_godot "cannon test" --fixed-fps 60 --script res://tests/cannon_test.gd
run_godot "derezz test" --fixed-fps 60 --script res://tests/derezz_test.gd

if [ "$failures" -ne 0 ]; then
	printf 'CHECK FAILED: %d problem(s)\n' "$failures" >&2
	exit 1
fi
echo "CHECK PASSED"
