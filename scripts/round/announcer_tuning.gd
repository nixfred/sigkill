class_name AnnouncerTuning
extends Resource
## Every number of the round loop and its announcer (C12, scripts/round/round_hud.gd): how
## long a round and the break after it last, the pace and thresholds of the in-round
## callouts, the cap on the end-of-round line, and where the round line, the callouts and
## the summary panel sit. The default instance is resources/announcer.tres. Units are
## seconds, characters and pixels.

@export_group("Round")
## Length of one round, in seconds of game time.
@export var round_seconds: float = 90.0
## Break between rounds, with the summary panel up; the dummies reset at its end.
@export var intermission_seconds: float = 12.0

@export_group("Callouts")
## Shortest gap between two in-round callouts; one that comes sooner is dropped.
@export var callout_min_interval_s: float = 4.0
## How long a callout stays on screen.
@export var callout_seconds: float = 2.0
## Hits in a row that earn a streak callout (and every multiple of it).
@export var streak_callout: int = 3
## Misses in a row that earn a callout (and every multiple of it).
@export var miss_run_callout: int = 10

@export_group("Announcer")
## Most characters of the end-of-round line shown, the AI's or SIGKILL's. At most 240.
@export var text_max_chars: int = 240

@export_group("Layout")
## Size of the round line under the daemon count.
@export var round_font_size: int = 16
## Size of an in-round callout.
@export var callout_font_size: int = 26
## Size of the summary panel's text.
@export var summary_font_size: int = 15
## Widest the summary panel gets; never wider than the screen allows.
@export var summary_width: int = 560
## Distance from the top of the screen to the summary panel.
@export var summary_top: int = 120

const ROUND_FIRST_S := 1.0
const ROUND_LAST_S := 3600.0
const BREAK_FIRST_S := 1.0
const BREAK_LAST_S := 600.0
const CALLOUT_GAP_FIRST_S := 0.5
const CALLOUT_GAP_LAST_S := 60.0
const CALLOUT_SHOW_FIRST_S := 0.25
const CALLOUT_SHOW_LAST_S := 10.0
const RUN_FIRST := 2
const RUN_LAST := 1000
const TEXT_FIRST := 20
## The hard ceiling on the end-of-round line, whatever the tuning says.
const TEXT_LAST := 240
const FONT_FIRST := 8
const FONT_LAST := 96
const WIDTH_FIRST := 240
const WIDTH_LAST := 1600
const TOP_LAST := 600


## Everything wrong with these values, or empty when they are safe to use.
func problems() -> PackedStringArray:
	var out := PackedStringArray()
	_range(out, "round_seconds", ROUND_FIRST_S, ROUND_LAST_S)
	_range(out, "intermission_seconds", BREAK_FIRST_S, BREAK_LAST_S)
	_range(out, "callout_min_interval_s", CALLOUT_GAP_FIRST_S, CALLOUT_GAP_LAST_S)
	_range(out, "callout_seconds", CALLOUT_SHOW_FIRST_S, CALLOUT_SHOW_LAST_S)
	for field in ["streak_callout", "miss_run_callout"]:
		var run: int = get(field)
		if run < RUN_FIRST or run > RUN_LAST:
			out.append("%s must be between %d and %d" % [field, RUN_FIRST, RUN_LAST])
	if text_max_chars < TEXT_FIRST or text_max_chars > TEXT_LAST:
		out.append("text_max_chars must be between %d and %d" % [TEXT_FIRST, TEXT_LAST])
	for field in ["round_font_size", "callout_font_size", "summary_font_size"]:
		var size: int = get(field)
		if size < FONT_FIRST or size > FONT_LAST:
			out.append("%s must be between %d and %d" % [field, FONT_FIRST, FONT_LAST])
	if summary_width < WIDTH_FIRST or summary_width > WIDTH_LAST:
		out.append("summary_width must be between %d and %d" % [WIDTH_FIRST, WIDTH_LAST])
	if summary_top < 0 or summary_top > TOP_LAST:
		out.append("summary_top must be between 0 and %d" % TOP_LAST)
	return out


func _range(out: PackedStringArray, field: String, first: float, last: float) -> void:
	var value: float = get(field)
	if not is_finite(value) or value < first or value > last:
		out.append("%s must be between %s and %s" % [field, first, last])
