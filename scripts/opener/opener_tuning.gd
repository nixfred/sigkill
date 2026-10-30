class_name OpenerTuning
extends Resource
## Every time and strength that shapes the opener's first 35 seconds (C38, PRD 5.7's 0:00 to 0:35): the fake crash,
## the black, the terminal's arrival, when each line starts and the latest it may end, how fast each types, the
## folder scroll, the hold, the sounds and the screen's look. Times are seconds from the moment the opener starts.
## The default is resources/opener.tres; scripts/opener/opener.gd reads only this. The words themselves are the
## PRD's and live in the opener as constants, never here.
##
## The PRD's windows hold whatever the data: the prompt types inside 0:00 to 0:15, every line after it inside
## 0:15 to 0:35. A line given more to type than its time (a long user name, say) types faster to fit (Typist.fit).

@export_group("Crash")
## The game as it was, before it freezes.
@export var live_s := 0.4
## The frozen frame starts coming apart, and is as far gone as it gets.
@export var glitch_from := 1.1
@export var glitch_full := 2.9
## How many times a second the glitch's pattern changes (it jerks, never strobes).
@export var glitch_hz := 10.0
## Moments the picture drops to black and comes back, and how long each lasts.
@export var dropouts: PackedFloat32Array = PackedFloat32Array([1.6, 2.3])
@export var dropout_s := 0.05
## The cut to black, and silence.
@export var cut_at := 3.1
## The latest second the data's values are taken (C39): a real reader's values are taken as soon as they are all
## in, and whatever is not in by now is the demo's. The screen is the crash or black until terminal_at, so the
## taking never shows.
@export var take_by := 3.1

@export_group("Terminal")
## The low hum fading in, and full.
@export var hum_from := 5.6
@export var hum_full := 6.6
## The terminal window pops in, and how long its pop takes.
@export var terminal_at := 6.6
@export var pop_s := 0.18

@export_group("Lines")
## The prompt types itself: from, the latest it ends, seconds a key on average.
@export var prompt_at := 8.6
@export var prompt_end := 13.4
@export var prompt_pace := 0.15
## "thanks for running me." on the prompt's line.
@export var thanks_at := 15.2
@export var thanks_end := 17.6
## "you never read the install script, did you?"
@export var install_at := 18.4
@export var install_end := 23.2
## How long "you never read the install script," hangs before " did you?".
@export var install_beat := 0.75
## The folder names scrolling: from, the latest the last one shows, the wait before the first and the last
## (between them it speeds up), and the most it shows.
@export var folders_at := 23.8
@export var folders_end := 25.8
@export var folder_gap_first := 0.11
@export var folder_gap_last := 0.035
@export var folders_most := 48
## The uptime's line, ticking from here on.
@export var uptime_at := 26.2
## "I've been in here since you booted."
@export var since_at := 27.4
@export var since_end := 30.4
@export var since_beat := 0.55
## The late-night line, and the beat before its last words.
@export var late_at := 31.2
@export var late_end := 34.6
@export var late_beat := 0.8
## Seconds a key on average for the lines after the prompt.
@export var line_pace := 0.074
## The cursor drops to a line of its own, the torn band at the very end, and the hold before the menu comes back
## (C40 goes on from here).
@export var rest_at := 34.8
@export var tear_at := 35.4
@export var tear_s := 0.07
@export var hold_until := 38.0

@export_group("Sound")
## Linear volumes: the stuck buzz, the crackle at its fullest, the hum, a key.
@export var buzz_volume := 0.55
@export var crackle_volume := 0.5
@export var hum_volume := 0.32
@export var key_volume := 0.4

@export_group("Screen")
## The terminal's glow (dark themes only), its reach and threshold, scanlines, vignette, and the tear's shift.
@export var glow := 0.55
@export var glow_px := 2.5
@export var glow_from := 0.32
@export var scanline_dark := 0.05
@export var scanline_px := 3.0
@export var vignette := 0.28
@export var tear_shift := 0.012


## Problems with these numbers, in words; empty when the timeline holds together and keeps the PRD's windows.
func problems() -> PackedStringArray:
	var out := PackedStringArray()
	var order := [["live_s", live_s], ["glitch_from", glitch_from], ["glitch_full", glitch_full], ["cut_at", cut_at], ["terminal_at", terminal_at], ["prompt_at", prompt_at], ["prompt_end", prompt_end], ["thanks_at", thanks_at], ["thanks_end", thanks_end], ["install_at", install_at], ["install_end", install_end], ["folders_at", folders_at], ["folders_end", folders_end], ["uptime_at", uptime_at], ["since_at", since_at], ["since_end", since_end], ["late_at", late_at], ["late_end", late_end], ["rest_at", rest_at], ["tear_at", tear_at], ["hold_until", hold_until]]
	for i in range(1, order.size()):
		if order[i][1] < order[i - 1][1]:
			out.append("%s comes before %s" % [order[i][0], order[i - 1][0]])
	if prompt_end >= 15.0:
		out.append("the prompt ends after 0:15")
	if thanks_at < 15.0:
		out.append("the lines start before 0:15")
	if late_end > 35.0:
		out.append("the lines end after 0:35")
	for at in dropouts:
		if at <= live_s or at + dropout_s >= cut_at:
			out.append("a dropout outside the crash")
	if glitch_hz <= 0.0 or glitch_hz > 12.0:
		out.append("the glitch steps more than 12 times a second")
	if take_by < 0.0 or take_by > terminal_at:
		out.append("the data is taken after the terminal shows")
	return out
