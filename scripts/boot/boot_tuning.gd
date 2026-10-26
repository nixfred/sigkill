class_name BootTuning
extends Resource
## Every number and colour that shapes the boot screen (scenes/boot.tscn): how fast its
## lines type, the pauses between them, the "thinking" spinner, the GPU readout's pace,
## how long it waits before the arena, its text sizes and its colours. The default instance
## is resources/boot.tres; scripts/boot/boot_sequence.gd reads only from this resource. The
## colours default to the palette in scripts/palette.gd. Units are milliseconds,
## characters and pixels.

const Palette = preload("res://scripts/palette.gd")

@export_group("Typing")
## How fast each line types out, in characters per second.
@export var chars_per_second: float = 90.0
## Pause after a line has finished typing, before the next one starts.
@export var line_pause_ms: int = 180

@export_group("Handshake")
## How often the "thinking" spinner turns while the AI is asked.
@export var spinner_frame_ms: int = 90
## Demo-data mode only: how long the fake handshake "thinks" before its canned answer.
@export var demo_link_ms: int = 900
## Demo-data mode only: the latency shown for the canned answer.
@export var demo_latency_ms: int = 842

@export_group("Readout")
## Time between two GPU readings. Never under 1 second.
@export var gpu_interval_ms: int = 1000

@export_group("Handoff")
## Wait after the last line before the arena starts on its own.
@export var auto_continue_ms: int = 1600

@export_group("Text")
## Size of the "SIGKILL boot" title line, in pixels.
@export var title_font_size: int = 30
## Size of every other line.
@export var line_font_size: int = 20
## Size of the hint line at the bottom.
@export var hint_font_size: int = 14
## Opacity of the hint line, from 0 to 1.
@export_range(0.0, 1.0) var hint_alpha: float = 0.7

@export_group("Colours")
## The title line.
@export var title_color: Color = Palette.TEAL
## Ordinary lines and the AI's answer.
@export var text_color: Color = Palette.MINT
## The opt-in question and its keys.
@export var prompt_color: Color = Palette.HOSTILE_AMBER
## A link that failed or was skipped.
@export var warn_color: Color = Palette.HOSTILE_RED

const CPS_FIRST := 5.0
const CPS_LAST := 5000.0
const PAUSE_LAST_MS := 5000
const SPINNER_FIRST_MS := 30
const SPINNER_LAST_MS := 1000
const DEMO_LAST_MS := 10000
const GPU_FIRST_MS := 1000
const GPU_LAST_MS := 60000
const CONTINUE_LAST_MS := 30000
const FONT_FIRST := 8
const FONT_LAST := 96


## Everything wrong with these values, or empty when they are safe to use.
func problems() -> PackedStringArray:
	var out := PackedStringArray()
	if not is_finite(chars_per_second) or chars_per_second < CPS_FIRST or chars_per_second > CPS_LAST:
		out.append("chars_per_second must be between %d and %d" % [CPS_FIRST, CPS_LAST])
	if line_pause_ms < 0 or line_pause_ms > PAUSE_LAST_MS:
		out.append("line_pause_ms must be between 0 and %d" % PAUSE_LAST_MS)
	if spinner_frame_ms < SPINNER_FIRST_MS or spinner_frame_ms > SPINNER_LAST_MS:
		out.append("spinner_frame_ms must be between %d and %d" % [SPINNER_FIRST_MS, SPINNER_LAST_MS])
	for field in ["demo_link_ms", "demo_latency_ms"]:
		var value: int = get(field)
		if value < 0 or value > DEMO_LAST_MS:
			out.append("%s must be between 0 and %d" % [field, DEMO_LAST_MS])
	if gpu_interval_ms < GPU_FIRST_MS or gpu_interval_ms > GPU_LAST_MS:
		out.append("gpu_interval_ms must be between %d and %d" % [GPU_FIRST_MS, GPU_LAST_MS])
	if auto_continue_ms < 0 or auto_continue_ms > CONTINUE_LAST_MS:
		out.append("auto_continue_ms must be between 0 and %d" % CONTINUE_LAST_MS)
	for field in ["title_font_size", "line_font_size", "hint_font_size"]:
		var size: int = get(field)
		if size < FONT_FIRST or size > FONT_LAST:
			out.append("%s must be between %d and %d" % [field, FONT_FIRST, FONT_LAST])
	if not is_finite(hint_alpha) or hint_alpha < 0.0 or hint_alpha > 1.0:
		out.append("hint_alpha must be between 0 and 1")
	return out
