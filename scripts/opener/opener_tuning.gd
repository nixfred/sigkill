class_name OpenerTuning
extends Resource
## Every time and strength that shapes the opener (C38: PRD 5.7's 0:00 to 0:35; C40: 0:35 to 1:10; C41: 1:10 to
## 1:35; C42: 1:35 to 2:00): the fake crash, the black, the terminal's arrival, when each line starts and the latest it may end, how fast
## each types, the folder scroll, the hold, the 3 seconds the terminal ignores typing, the shrink-away, the fall and its
## landing, the link to the player's AI and the copy of them, the sounds and the screen's look. Times are seconds from the moment the opener starts. The default is
## resources/opener.tres; scripts/opener/opener.gd reads only this. The words themselves are the PRD's and live in
## the opener as constants, never here; the camera's way through the machine is scripts/opener/tree_fall.gd's.
##
## The PRD's windows hold whatever the data: the prompt types inside 0:00 to 0:15, every line after it inside
## 0:15 to 0:35, the shrink-away inside 0:35 to 0:50, the fall from 0:50 to 1:10, the link and the copy inside 1:10 to
## 1:35 (whenever the player's AI answers, or does not), the forge, the kill and the title inside 1:35 to 2:00 (whenever
## the player fires, or does not by fire_by). A line given more to type than its
## time (a long user name, say) types faster to fit (Typist.fit).
##
## C42's moments inside the forge and after the shot are the score's (scripts/opener/opener_score.gd, in sixteenths and
## beats), so what is seen lands on what is heard; here are the forge's start (C41's hand-off), when the player may fire
## and when the rifle fires on its own, and how long the kill and the title run after the shot.

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
## The cursor drops to a line of its own, the torn band at the very end, and the hold until the shrink-away beat.
@export var rest_at := 34.8
@export var tear_at := 35.4
@export var tear_s := 0.07
@export var hold_until := 36.0

@export_group("Shrink-away")
## From hold_until a fresh prompt waits, and the terminal ignores typing for this long (PRD 5.7: "The fake terminal
## ignores typing for 3 seconds"); then "you're in now." types itself at that prompt.
@export var ignore_s := 3.0
@export var in_at := 39.0
@export var in_end := 40.2
## The terminal's window shrinks away: the camera pulls back from it into the machine (scripts/opener/tree_fall.gd).
@export var shrink_at := 40.8

@export_group("Fall")
## The fall down the directory tree begins, lands on the pit's rim and hands off: C41's beat starts here.
@export var fall_at := 50.0
@export var land_at := 68.4
@export var handoff_at := 69.6

@export_group("Link")
## The one call to the player's AI starts here, as the fall begins, so its answer is in by the link beat (it never
## shows: the screen is the fall). "Linking your agent..." types itself from link_at to link_end, the signal climbs the
## pit's walls from signal_at, and the answer shows from answer_from at the earliest; at answer_by the beat goes on
## regardless, with the scripted line if no answer came (the opener never waits on the AI).
@export var ask_at := 50.0
@export var link_at := 70.2
@export var link_end := 71.6
@export var signal_at := 70.6
@export var answer_from := 73.6
@export var answer_by := 77.0

@export_group("Copy")
## The scripted guide's line types itself from guide_at, done by guide_end at the latest, with its beat before "They
## look like you."; the copy of you walks up out of the pit from copy_at and stands before you at copy_stop.
@export var guide_at := 81.4
@export var guide_end := 85.8
@export var guide_beat := 0.8
@export var copy_at := 82.6
@export var copy_stop := 93.6
## The hand-off to C42: the kill -9 forge starts here, on the score's bar line (the bed ends here).
@export var forge_at := 94.4

@export_group("Kill")
## The player may fire from fire_from (the forge's end, the score's wait loop); the rifle fires on its own at fire_by,
## so the opener never waits longer. The shot lands on the next sixteenth of the press.
@export var fire_from := 104.0
@export var fire_by := 107.2
## From the shot to the end: the derezz, the kill feed, the whisper, the black, the title slam and its riff, the title
## torn away. end_at is the latest end (a shot at fire_by), inside 2:00.
@export var end_after := 10.8
@export var end_at := 118.0

@export_group("Sound")
## Linear volumes: the stuck buzz, the crackle at its fullest, the hum, a key.
@export var buzz_volume := 0.55
@export var crackle_volume := 0.5
@export var hum_volume := 0.32
@export var key_volume := 0.4
## The shrink-away's rush, the fall's wind at its fastest, the landing, and the hot process's beat near the bottom.
@export var whoosh_volume := 0.6
@export var wind_volume := 0.5
@export var thud_volume := 0.7
@export var beat_volume := 0.42
## The link's carrier as the signal climbs, its lock when the answer lands, the copy's rise and each of its steps.
@export var link_volume := 0.4
@export var lock_volume := 0.5
@export var rise_volume := 0.55
@export var step_volume := 0.6
## C42: the score (on the Music bus), the keys of `kill -9`, the forge's charge, break, print and lock, the copy's keys,
## and the rail's shot.
@export var score_volume := 0.62
@export var forge_key_volume := 0.55
@export var forge_volume := 0.5
@export var copy_key_volume := 0.5
@export var shot_volume := 0.7

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
	var order := [["live_s", live_s], ["glitch_from", glitch_from], ["glitch_full", glitch_full], ["cut_at", cut_at], ["terminal_at", terminal_at], ["prompt_at", prompt_at], ["prompt_end", prompt_end], ["thanks_at", thanks_at], ["thanks_end", thanks_end], ["install_at", install_at], ["install_end", install_end], ["folders_at", folders_at], ["folders_end", folders_end], ["uptime_at", uptime_at], ["since_at", since_at], ["since_end", since_end], ["late_at", late_at], ["late_end", late_end], ["rest_at", rest_at], ["tear_at", tear_at], ["hold_until", hold_until], ["in_at", in_at], ["in_end", in_end], ["shrink_at", shrink_at], ["fall_at", fall_at], ["land_at", land_at], ["handoff_at", handoff_at], ["link_at", link_at], ["link_end", link_end], ["answer_from", answer_from], ["answer_by", answer_by], ["guide_at", guide_at], ["guide_end", guide_end], ["copy_stop", copy_stop], ["forge_at", forge_at], ["fire_from", fire_from], ["fire_by", fire_by], ["end_at", end_at]]
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
	if absf(ignore_s - 3.0) > 0.25:
		out.append("the terminal does not ignore typing for 3 seconds")
	if in_at < hold_until + ignore_s:
		out.append("\"you're in now.\" comes before the 3 seconds are up")
	if hold_until < 35.0 or in_end > 50.0 or shrink_at > 50.0:
		out.append("the shrink-away beat outside 0:35 to 0:50")
	if fall_at - shrink_at < 6.0:
		out.append("the shrink-away is too short to read as a camera move")
	if fall_at < 49.0 or fall_at > 51.0:
		out.append("the fall does not start at 0:50")
	if land_at > 70.0 or handoff_at > 70.5:
		out.append("the fall ends after 1:10")
	if link_at < 70.0 or link_at > 70.5:
		out.append("the link does not start at 1:10")
	if ask_at < 0.0 or ask_at > link_at:
		out.append("the AI is asked after the link beat starts")
	if signal_at < link_at or signal_at > answer_from:
		out.append("the signal climbs outside the link beat")
	if answer_by - link_at > 8.0:
		out.append("the link waits more than 8 s on the AI")
	if copy_at < answer_by or copy_at > guide_end:
		out.append("the copy comes before the link is done or after the guide's line")
	if copy_stop - copy_at < 6.0:
		out.append("the copy's walk is too short to read")
	if guide_end - guide_at < 2.0 or guide_beat <= 0.0 or guide_beat > 2.0:
		out.append("the guide's line has no room to type")
	if forge_at > 95.5:
		out.append("the copy's beat ends after 1:35")
	if absf(forge_at - OpenerScore.BED_AT - OpenerScore.BED_BARS * OpenerScore.BAR_S) > 0.02:
		out.append("the forge is not on the score's bar line")
	if absf(fire_from - forge_at - OpenerScore.FORGE_BARS * OpenerScore.BAR_S) > 0.02:
		out.append("the player may fire before or after the forge ends")
	if fire_by <= fire_from or fire_by - fire_from > 4.0:
		out.append("the opener waits more than 4 s for the shot")
	if end_after < OpenerScore.SLAM_BEATS * OpenerScore.BEAT_S + 2.0 * OpenerScore.BAR_S + 1.0 or end_after > OpenerScore.STINGER_S:
		out.append("the title has no room after the shot")
	if absf(end_at - fire_by - end_after) > 0.05:
		out.append("the end is not fire_by and the title after it")
	if end_at > 120.0:
		out.append("the opener runs past 2:00")
	return out
