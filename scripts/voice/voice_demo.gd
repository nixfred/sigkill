class_name VoiceDemo
extends RefCounted
## Voice commands' demo (W7, PRD 5.5): the arena with a simulated feed, so a player with no transcript program sees the
## voice HUD, the commands and your AI's cover drone at work. Reached from the Esc menu ("Voice commands"; "Leave voice
## commands" ends it), or with --voice on a demo or test run. One world mode at a time with the others: it is the regular
## arena, its daemons and rounds as ever, with this feed in place of the player's own.
##
## The feed is a script of made-up lines (SCRIPT), scripted in-process: no program, no file, no socket. Each line
## "arrives" at its time on the demo's clock, the script going round every LOOP_S with its ids still climbing; answer()
## gives the newest lines as the JSON a real feed would, so they go through the very same reading (VoiceFeed.digest) as a
## real one: talk acted on, the TV's lines skipped, a "Larry, tell" line refused, a mishearing or two understood. Its
## lines are the game's own fake text; even so, none of it is ever shown, kept or logged (the voice HUD shows only a
## matched command's name, as with a real feed).

const FLAG := "--voice"
const RELOAD_LABEL := "$ tail -f transcript"
## The script goes round every LOOP_S seconds.
const LOOP_S := 64.0
## The newest lines an answer holds (a real feed's "recent lines").
const ANSWER_LINES := 16
## [seconds into the loop, media (0 talk, 1 or 2 a TV or other media), the line]. Made-up talk only.
const SCRIPT := [
	[2.5, 0, "ok it's loading, here we go"],
	[5.0, 1, "and after the break, the weekend forecast"],
	[8.0, 0, "Reload!"],
	[13.0, 0, "Larry, cover me!"],
	[17.0, 1, "remember to reload your basket before checkout"],
	[20.0, 0, "nice, that was close"],
	[24.0, 0, "drop a breaker"],
	[29.0, 0, "Larry, tell me the score"],
	[33.0, 0, "visor"],
	[39.0, 0, "pause."],
	[43.0, 0, "resume"],
	[47.0, 2, "visor sale ends tonight at midnight"],
	[49.0, 0, "visa"],
	[53.0, 0, "re-load, please"],
	[58.0, 0, "how many are left?"],
]

static var queued := false
static var _flag_taken := false


static func queue() -> void:
	queued = true


static func clear() -> void:
	queued = false


static func take_flag(args: PackedStringArray) -> void:
	if _flag_taken:
		return
	_flag_taken = true
	if args.has(FLAG) and (args.has("--demo") or OS.get_cmdline_args().has("--script")):
		queue()


## As the arena loads: the flag taken once a run. True when the demo should begin (alone, no mission).
static func prepare(args: PackedStringArray, online: bool) -> bool:
	take_flag(args)
	return queued and not online and MissionRunner.pending() == ""


## The demo feed's answer `t` seconds after it began: its newest ANSWER_LINES lines (those arrived by then) as a real
## feed's JSON, ids climbing across loops, each with a field the reader ignores.
static func answer(t: float) -> PackedByteArray:
	var rows: Array = []
	var loop := floori(maxf(t, 0.0) / LOOP_S)
	for l in range(maxi(loop - 1, 0), loop + 1):
		for i in SCRIPT.size():
			var at: float = l * LOOP_S + float(SCRIPT[i][0])
			if at <= t:
				rows.append({"id": l * SCRIPT.size() + i + 1, "media": SCRIPT[i][1], "text": SCRIPT[i][2], "source": "demo"})
	if rows.size() > ANSWER_LINES:
		rows = rows.slice(rows.size() - ANSWER_LINES)
	return JSON.stringify(rows).to_utf8_buffer()


## Seconds into the loop of the script's next line after `t` (for the HUD's "next line" pulse and the captures).
static func next_after(t: float) -> float:
	var into := fmod(maxf(t, 0.0), LOOP_S)
	for line in SCRIPT:
		if float(line[0]) > into:
			return t + float(line[0]) - into
	return t + LOOP_S - into + float(SCRIPT[0][0])
