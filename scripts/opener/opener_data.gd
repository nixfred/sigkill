class_name OpenerData
extends RefCounted
## Everything the opener (C38 to C42, PRD 5.7) shows of "your machine", handed over in one place: the user and the
## host for the prompt, the terminal's palette, folder names to scroll (and how many entries each holds, for C40's
## city), the uptime that ticks, and recent file times for the late-night line. The opener (scripts/opener/
## opener.gd) starts it as it starts, takes the values once (as soon as is_ready(), or at its take_by second
## regardless) and drops it as it ends.
##
## Two implementations: DemoOpenerData (C38), fixed, invented values, nothing read from anywhere, always ready; and
## RealOpenerData (C39), read from the player's own machine on its own thread, only when the player has said yes
## (Settings, Privacy and AI, "opener data"): names, entry counts, times, the theme's colours and the uptime, never
## a file's contents, each value the demo's wherever its own could not be read in time. Whatever an implementation
## returns, the opener shows it only through clean() and its own caps, keeps it only while it plays, and never
## saves, logs or sends it.
##
## Times are local wall-clock seconds: seconds since 1970-01-01 00:00 on the machine's own clock (unix time plus
## the zone's offset), so Time's conversions of them read the local hour and date.

## The widest user or host name the prompt shows, and the widest folder name, in terminal cells (a wide character
## counts two; scripts/opener/cell_width.gd).
const NAME_LONGEST := 32
const FOLDER_LONGEST := 60
## Invisible characters that change how text around them is shown (bidirectional overrides and isolates, the
## marks, the word joiners, the byte-order mark, the soft hyphen, the annotation marks, a zero-width space): a
## name could hide or reorder what the terminal shows with them, so clean() drops them. The joiner stays: emoji
## are built with it.
const HIDDEN_FORMATS := [[0x00AD, 0x00AD], [0x061C, 0x061C], [0x200B, 0x200B], [0x200E, 0x200F], [0x202A, 0x202E], [0x2060, 0x2064], [0x2066, 0x2069], [0xFEFF, 0xFEFF], [0xFFF9, 0xFFFB]]


## "demo" (invented values) or "real" (read from the machine, C39).
func kind() -> String:
	return ""


## Starts reading, if this reads anything (C39's reader, on its own thread). The opener calls it as it starts.
func start() -> void:
	pass


## Whether every value is in. The opener takes them as soon as this is true, or at its take_by second regardless.
func is_ready() -> bool:
	return true


## The opener is taking the values now: none may change after this (a read still going stops where it is, and
## what it has not got stays the demo's), so every value the opener reads belongs with the others.
func settle() -> void:
	pass


## The opener is done with this: anything read is let go. Called as the opener ends, however it ends.
func drop() -> void:
	pass


## The user name for the prompt's `<user>@<host>:~$`.
func user() -> String:
	return ""


## The host name for the prompt.
func host() -> String:
	return ""


## The terminal's colours; null means the default demo palette.
func palette() -> OpenerPalette:
	return null


## Folder names to scroll past, as paths under the home folder ("code/homelab"), in the order shown.
func folders() -> PackedStringArray:
	return PackedStringArray()


## How many entries each of folders() holds, in the same order (-1 where not counted); empty when none are known.
## C40's tree fall builds its towers from these.
func folder_counts() -> PackedInt32Array:
	return PackedInt32Array()


## The process running hottest, for the red beat at the bottom of the fall (C40; PRD 5.7: "their top CPU process,
## named, pulses red at the bottom"); "" when unknown, and the opener shows the demo's. Nothing reads processes yet
## (C39's reader reads none and C40 added no reads), so every source but the demo leaves it "".
func top_process() -> String:
	return ""


## Seconds since the machine booted, as the opener starts; the opener ticks it on from there.
func uptime_s() -> int:
	return 0


## Recent file modification times, local wall-clock seconds (mtimes only, never which files).
func file_times() -> PackedInt64Array:
	return PackedInt64Array()


## The local wall-clock time as the opener starts, on the same scale, so a file time reads as "last night" or a
## weekday; 0 when unknown.
func now() -> int:
	return 0


## `text` as the fake terminal may show it: control characters, escape sequences and the HIDDEN_FORMATS dropped (a
## name can never move the cursor, colour the screen, break the line or reorder what is shown), tabs and line
## breaks as spaces, the ends trimmed, and at most `longest` cells wide, the cut marked "..." and never made
## inside a character's cluster (a wide character counts two cells, a combining mark none).
static func clean(text: String, longest: int) -> String:
	var out := ""
	var i := 0
	while i < text.length():
		var c := text.unicode_at(i)
		if c == 0x1b:
			# An escape sequence: ESC, then for CSI "[" parameters up to a final letter; anything else, one more.
			i += 1
			if i < text.length() and text[i] == "[":
				i += 1
				while i < text.length() and not (text.unicode_at(i) >= 0x40 and text.unicode_at(i) <= 0x7e):
					i += 1
			i += 1
			continue
		if c == 0x09 or c == 0x0a or c == 0x0d:
			out += " "
		elif c >= 0x20 and c != 0x7f and not (c >= 0x80 and c <= 0x9f) and not _hidden_format(c):
			out += char(c)
		i += 1
	out = out.strip_edges()
	if longest > 3 and CellWidth.total(out) > longest:
		var widths := CellWidth.of_text(out)
		var used := 0
		var cut := 0
		for at in out.length():
			if widths[at] > 0:
				if used + widths[at] > longest - 3:
					break
				used += widths[at]
			cut = at + 1
		out = out.left(cut) + "..."
	return out


static func _hidden_format(c: int) -> bool:
	for r in HIDDEN_FORMATS:
		if c >= r[0] and c <= r[1]:
			return true
	return false
