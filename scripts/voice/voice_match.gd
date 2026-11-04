class_name VoiceMatch
extends RefCounted
## Voice commands' words (W7, PRD 5.5): which command, if any, one line of talk is. Loose on purpose (a feed's line
## arrives with its own case, punctuation and small mishearings), strict where it matters: the line, once its wake word and
## a few filler words are taken off, must BE a command (everyday talk that only mentions one never fires it), and a line
## that begins "Larry, tell" is never a command at all (another program acts on those).
##
## The line's text lives only inside command_of(): it is cut into words, matched, and dropped. Nothing here keeps, prints,
## logs or hands on any of it; only the matched command's id leaves.

## Each command: its name (the only words the game ever shows or logs about a line), its phrases (as the matcher reads
## them: lower case, filler taken off) and the key or menu path that does the same thing without a voice.
const COMMANDS := {
	&"cover": {"name": "cover me", "phrases": ["cover me", "cover", "back me up", "give me cover"], "key": "P"},
	&"breaker": {"name": "drop a breaker", "phrases": ["drop breaker", "breaker", "run breaker", "drop icebreaker", "icebreaker", "ice breaker", "drop ice breaker"], "key": "U"},
	&"reload": {"name": "reload", "phrases": ["reload", "reload weapon", "reload gun"], "key": "E"},
	&"visor": {"name": "visor", "phrases": ["visor", "visor on", "visor off", "toggle visor", "audit visor", "audit trail"], "key": "I"},
	&"pause": {"name": "pause", "phrases": ["pause", "pause game", "sigstop", "sig stop", "stop time", "slow time", "slow motion"], "key": "F"},
	&"resume": {"name": "resume", "phrases": ["resume", "continue", "sigcont", "sig cont", "unpause", "resume game"], "key": "F again"},
}
## The order the HUD and the docs list them in.
const ORDER := [&"cover", &"breaker", &"reload", &"visor", &"pause", &"resume"]
## Words a line may open with before the wake word ("hey Larry"), the wake word itself (and how a feed tends to spell it),
## and the filler taken off anywhere ("reload now please").
const OPENERS := ["hey", "ok", "okay", "yo", "hi", "oi"]
const WAKE := ["larry", "lary", "larri", "larrys"]
const FILLER := ["please", "pls", "plz", "now", "quick", "quickly", "a", "an", "the", "uh", "um", "umm", "er", "erm", "just", "ok", "okay", "hey", "yo"]
## Never a command (the brief: another program acts on these): a line whose words open with these, after any opener.
const BLOCKED := ["larry", "tell"]
## Mishearings no edit distance reaches, by what they stand for (joined words, no spaces).
const ALIASES := {"visa": "visor", "vizor": "visor", "viser": "visor", "vyzor": "visor", "visors": "visor", "reloads": "reload", "realod": "reload", "paws": "pause", "breakers": "breaker", "braker": "breaker"}
## Real words an edit away from a command phrase that mean something else (a whole line of "over" or "cause" fired cover
## me or pause), found by running the matcher over a word list: never a command, whatever the distance says.
const NOT_COMMANDS := ["over", "hover", "lover", "mover", "rover", "dover", "clover", "coder", "comer", "corer", "cove",
	"coves", "coven", "covet", "covert", "cower", "beaker", "vigor", "cause", "parse", "passe", "showtime", "presume",
	"continua", "continuo"]
## A line longer than this many words, or characters, is talk, never a command.
const WORDS_LAST := 8
const CHARS_LAST := 160


## The command line `text` is, or &"" for none. Pure: nothing is kept.
static func command_of(text: String) -> StringName:
	if text.length() > CHARS_LAST:
		return &""
	var words := words_of(text)
	if words.is_empty() or blocked(words):
		return &""
	words = _core(words)
	if words.is_empty() or words.size() > WORDS_LAST:
		return &""
	var joined := "".join(words)
	if ALIASES.has(joined):
		joined = ALIASES[joined]
	if NOT_COMMANDS.has(joined):
		return &""
	var best := &""
	var best_d := 99
	var tie := false
	for id in ORDER:
		for phrase in COMMANDS[id]["phrases"]:
			var p: String = (phrase as String).replace(" ", "")
			var d := distance(joined, p)
			if d > tolerance(p):
				continue
			if d < best_d:
				best_d = d
				best = id
				tie = false
			elif d == best_d and best != id:
				tie = true
	return &"" if tie else best


## True for a line of words that opens "Larry, tell" (after "hey" or the like): never a command.
static func blocked(words: PackedStringArray) -> bool:
	var i := 0
	while i < words.size() and OPENERS.has(words[i]):
		i += 1
	return i + 1 < words.size() and WAKE.has(words[i]) and words[i + 1] == BLOCKED[1]


## The words of `text`: lower case, anything but letters and digits a space, runs folded.
static func words_of(text: String) -> PackedStringArray:
	var out := ""
	for c in text.to_lower():
		var u := c.unicode_at(0)
		out += c if (u >= 0x61 and u <= 0x7A) or (u >= 0x30 and u <= 0x39) else " "
	return out.split(" ", false)


## The words a command is matched on: the opener and wake word off the front, filler out, one word said twice once
## ("reload reload"), a phrase said twice once ("cover me cover me").
static func _core(words: PackedStringArray) -> PackedStringArray:
	var i := 0
	while i < words.size() and OPENERS.has(words[i]):
		i += 1
	if i < words.size() and WAKE.has(words[i]):
		i += 1
	var out := PackedStringArray()
	for j in range(i, words.size()):
		var w := words[j]
		if FILLER.has(w) or WAKE.has(w):
			continue
		if not out.is_empty() and out[out.size() - 1] == w:
			continue
		out.append(w)
	var half := out.size() / 2
	if out.size() >= 2 and out.size() % 2 == 0 and out.slice(0, half) == out.slice(half):
		out = out.slice(0, half)
	return out


## How many edits a phrase (joined, no spaces) forgives: none under 5 letters, one under 10, two after.
static func tolerance(phrase: String) -> int:
	if phrase.length() < 5:
		return 0
	return 1 if phrase.length() < 10 else 2


## The edit distance between `a` and `b` (insert, delete, change, and two letters swapped), capped at 9.
static func distance(a: String, b: String) -> int:
	if absi(a.length() - b.length()) > 3:
		return 9
	var rows: Array[PackedInt32Array] = []
	for i in a.length() + 1:
		var row := PackedInt32Array()
		row.resize(b.length() + 1)
		row[0] = i
		rows.append(row)
	for j in b.length() + 1:
		rows[0][j] = j
	for i in range(1, a.length() + 1):
		for j in range(1, b.length() + 1):
			var cost := 0 if a[i - 1] == b[j - 1] else 1
			var best := mini(mini(rows[i - 1][j] + 1, rows[i][j - 1] + 1), rows[i - 1][j - 1] + cost)
			if i > 1 and j > 1 and a[i - 1] == b[j - 2] and a[i - 2] == b[j - 1]:
				best = mini(best, rows[i - 2][j - 2] + 1)
			rows[i][j] = best
	return mini(rows[a.length()][b.length()], 9)


## A command's name ("cover me"), or "" for none.
static func name_of(id: StringName) -> String:
	return str(COMMANDS[id]["name"]) if COMMANDS.has(id) else ""
