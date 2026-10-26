class_name HudTuning
extends Resource
## Every number and colour of the guide HUD (scripts/hud/guide_hud.gd): where it sits,
## its text sizes, the ask box and answer caps, how long answers and notices stay up, the
## session cap on AI calls, the spinner and GPU pace, the demo values and the colours. The
## default instance is resources/hud.tres; the guide HUD reads only from this resource.
## The colours default to the palette in scripts/palette.gd. Units are pixels,
## characters and milliseconds.

const Palette = preload("res://scripts/palette.gd")

@export_group("Layout")
## Distance from the screen edges.
@export var margin: int = 18
## Widest the ask box and the answer panel get; never wider than the screen allows.
@export var panel_width: int = 520
## Room kept clear under the answer panel for the arena's hint line.
@export var panel_bottom_gap: int = 36
## Size of the "your AI" badge.
@export var badge_font_size: int = 18
## Size of the latency, GPU and status lines.
@export var line_font_size: int = 14
## Size of the answer and the ask box.
@export var answer_font_size: int = 16
## Opacity of the panel behind the answer and the ask box, from 0 to 1.
@export_range(0.0, 1.0) var panel_alpha: float = 0.78

@export_group("Ask")
## Most characters the ask box takes. The guide tuning's typed-text cap applies too.
@export var ask_max_chars: int = 160
## Most characters of an answer shown.
@export var answer_max_chars: int = 420
## Most lines of an answer shown.
@export var answer_max_lines: int = 6
## How long an answer stays on screen.
@export var answer_ms: int = 14000
## How long a short notice (cooldown, limit reached, AI off) stays on screen.
@export var notice_ms: int = 3500

@export_group("Pacing")
## Most AI calls in one game session, the boot handshake included.
@export var session_call_cap: int = 40
## How often the "thinking" spinner turns.
@export var spinner_frame_ms: int = 90
## Time between two GPU readings. Never under 1 second.
@export var gpu_interval_ms: int = 1000

@export_group("Demo")
## Demo-data mode only: how long the canned answer "thinks".
@export var demo_answer_ms: int = 900
## Demo-data mode only: the latency shown for it.
@export var demo_latency_ms: int = 842
## Demo-data mode only: how long the fake model load takes.
@export var demo_load_ms: int = 1500

@export_group("Colours")
## The badge while an AI is linked.
@export var badge_color: Color = Palette.TEAL
## Ordinary lines and the answer.
@export var text_color: Color = Palette.MINT
## The badge and lines while the AI is off, and the opt-in question.
@export var off_color: Color = Palette.HOSTILE_AMBER
## A call that failed.
@export var warn_color: Color = Palette.HOSTILE_RED

const MARGIN_LAST := 200
const PANEL_FIRST := 240
const PANEL_LAST := 1600
const GAP_LAST := 400
const FONT_FIRST := 8
const FONT_LAST := 96
const ASK_LAST := 500
const ANSWER_FIRST := 8
const ANSWER_LAST := 600
const LINES_LAST := 20
const SHOW_FIRST_MS := 500
const SHOW_LAST_MS := 120000
const CAP_LAST := 1000
const SPINNER_FIRST_MS := 30
const SPINNER_LAST_MS := 1000
const GPU_FIRST_MS := 1000
const GPU_LAST_MS := 60000
const DEMO_LAST_MS := 10000


## Everything wrong with these values, or empty when they are safe to use.
func problems() -> PackedStringArray:
	var out := PackedStringArray()
	if margin < 0 or margin > MARGIN_LAST:
		out.append("margin must be between 0 and %d" % MARGIN_LAST)
	if panel_width < PANEL_FIRST or panel_width > PANEL_LAST:
		out.append("panel_width must be between %d and %d" % [PANEL_FIRST, PANEL_LAST])
	if panel_bottom_gap < 0 or panel_bottom_gap > GAP_LAST:
		out.append("panel_bottom_gap must be between 0 and %d" % GAP_LAST)
	for field in ["badge_font_size", "line_font_size", "answer_font_size"]:
		var size: int = get(field)
		if size < FONT_FIRST or size > FONT_LAST:
			out.append("%s must be between %d and %d" % [field, FONT_FIRST, FONT_LAST])
	if not is_finite(panel_alpha) or panel_alpha < 0.0 or panel_alpha > 1.0:
		out.append("panel_alpha must be between 0 and 1")
	if ask_max_chars < 1 or ask_max_chars > ASK_LAST:
		out.append("ask_max_chars must be between 1 and %d" % ASK_LAST)
	if answer_max_chars < ANSWER_FIRST or answer_max_chars > ANSWER_LAST:
		out.append("answer_max_chars must be between %d and %d" % [ANSWER_FIRST, ANSWER_LAST])
	if answer_max_lines < 1 or answer_max_lines > LINES_LAST:
		out.append("answer_max_lines must be between 1 and %d" % LINES_LAST)
	for field in ["answer_ms", "notice_ms"]:
		var shown: int = get(field)
		if shown < SHOW_FIRST_MS or shown > SHOW_LAST_MS:
			out.append("%s must be between %d and %d" % [field, SHOW_FIRST_MS, SHOW_LAST_MS])
	if session_call_cap < 1 or session_call_cap > CAP_LAST:
		out.append("session_call_cap must be between 1 and %d" % CAP_LAST)
	if spinner_frame_ms < SPINNER_FIRST_MS or spinner_frame_ms > SPINNER_LAST_MS:
		out.append("spinner_frame_ms must be between %d and %d" % [SPINNER_FIRST_MS, SPINNER_LAST_MS])
	if gpu_interval_ms < GPU_FIRST_MS or gpu_interval_ms > GPU_LAST_MS:
		out.append("gpu_interval_ms must be between %d and %d" % [GPU_FIRST_MS, GPU_LAST_MS])
	for field in ["demo_answer_ms", "demo_latency_ms", "demo_load_ms"]:
		var value: int = get(field)
		if value < 0 or value > DEMO_LAST_MS:
			out.append("%s must be between 0 and %d" % [field, DEMO_LAST_MS])
	return out
