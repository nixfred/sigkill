class_name SpectateTopTuning
extends Resource
## Every number of spectate as top (C23, PRD 5.3 "dead players watch a live process-table
## style HUD of the match"): how often the table refreshes (and, in a match, how often the host
## sends its numbers), the three windows of its load average, how many process rows it shows
## and the first game PID. The default instance is resources/spectate_top.tres; the table is
## scripts/hud/spectate_top.gd, its record scripts/hud/top_ledger.gd. Fiction only: every PID,
## user and command in it is game data, never a real process, user or path.

@export_group("Refresh")
## Seconds between refreshes of the table, like top's delay; in a match also how often the
## host sends every player its numbers. Never more than once a second.
@export var refresh_s: float = 1.0

@export_group("Load average")
## The three windows of the load average, in seconds of play: the match's kills in each.
@export var load_short_s: float = 10.0
@export var load_mid_s: float = 30.0
@export var load_long_s: float = 60.0

@export_group("Rows")
## Process rows shown at most; the viewer's own row always among them.
@export var max_rows: int = 8
## The first game PID: each process's is this plus its join order in the match (the arena,
## alone: the player first, then the dummies).
@export var pid_base: int = 100

const REFRESH_FIRST_S := 1.0
const REFRESH_LAST_S := 10.0
const WINDOW_FIRST_S := 1.0
const WINDOW_LAST_S := 600.0
const ROWS_FIRST := 2
const ROWS_LAST := 16
const PID_FIRST := 1
## Past every PID a match can hand out: the base plus far more joins than any match sees.
const PID_LAST := 99999
const PID_BASE_LAST := 30000


## The three load windows, shortest first.
func windows() -> Array:
	return [load_short_s, load_mid_s, load_long_s]


## Everything wrong with these values, or empty when they are safe to use.
func problems() -> PackedStringArray:
	var out := PackedStringArray()
	if not is_finite(refresh_s) or refresh_s < REFRESH_FIRST_S or refresh_s > REFRESH_LAST_S:
		out.append("refresh_s must be between %s and %s" % [REFRESH_FIRST_S, REFRESH_LAST_S])
	var last := 0.0
	for pair in [["load_short_s", load_short_s], ["load_mid_s", load_mid_s], ["load_long_s", load_long_s]]:
		var w: float = pair[1]
		if not is_finite(w) or w < WINDOW_FIRST_S or w > WINDOW_LAST_S or w <= last:
			out.append("%s must be between %s and %s, and longer than the window before it" % [pair[0], WINDOW_FIRST_S, WINDOW_LAST_S])
		last = w if is_finite(w) else last
	if max_rows < ROWS_FIRST or max_rows > ROWS_LAST:
		out.append("max_rows must be between %d and %d" % [ROWS_FIRST, ROWS_LAST])
	if pid_base < PID_FIRST or pid_base > PID_BASE_LAST:
		out.append("pid_base must be between %d and %d" % [PID_FIRST, PID_BASE_LAST])
	return out
