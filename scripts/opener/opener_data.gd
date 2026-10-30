class_name OpenerData
extends RefCounted
## Everything the opener (C38 to C42, PRD 5.7) shows of "your machine", handed over in one place: the user and the
## host for the prompt, the terminal's palette, folder names to scroll, the uptime that ticks, and recent file
## times for the late-night line. The opener (scripts/opener/opener.gd) reads only this, once, as it starts.
##
## C38 ships one implementation, DemoOpenerData: fixed, invented values, nothing read from anywhere. C39 adds the
## real reader behind these same methods (opt-in, read-only names, counts, times and theme colours, a fake-data
## fallback). Whatever an implementation returns, the opener shows it only through clean() and its own caps, keeps
## it only while it plays, and never saves, logs or sends it.
##
## Times are local wall-clock seconds: seconds since 1970-01-01 00:00 on the machine's own clock (unix time plus
## the zone's offset), so Time's conversions of them read the local hour and date.

## The longest user or host name the prompt shows, and the longest folder name.
const NAME_LONGEST := 32
const FOLDER_LONGEST := 60


## "demo" (invented values) or "real" (read from the machine, C39).
func kind() -> String:
	return ""


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


## `text` as the fake terminal may show it: control characters and escape sequences dropped (a name can never
## move the cursor, colour the screen or break the line), tabs and line breaks as spaces, the ends trimmed, and at
## most `longest` characters, the cut marked "...".
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
		elif c >= 0x20 and c != 0x7f and not (c >= 0x80 and c <= 0x9f):
			out += char(c)
		i += 1
	out = out.strip_edges()
	if longest > 3 and out.length() > longest:
		out = out.left(longest - 3) + "..."
	return out
