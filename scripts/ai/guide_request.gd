extends RefCounted
## What the game may tell the player's AI guide, built from a whitelist (PRD 5.4: "only game
## stats and what the player types"). Only the named stats below get in, each checked for
## its type and range or its fixed list of values; anything else handed in, such as a file
## name, a path, a host name or a process name, is dropped without a trace. The player's
## typed text is capped and has its control and direction-changing characters removed.
## Nothing here reads the system; it only filters what the game passes in.

## The fixed instructions every guide gets, as its system prompt where the agent allows one.
const PREAMBLE := "You are the in-game guide in SIGKILL, a first-person shooter. Answer the player in at most three short lines. Use only the game stats and the player's message below. Do not use tools, do not read or write files, and do not run commands."

## The only stats a request can carry: [kind, low, high] for numbers, ["enum", values].
const STATS := {
	"shots_fired": ["int", 0, 1000000],
	"hits_landed": ["int", 0, 1000000],
	"kills": ["int", 0, 100000],
	"deaths": ["int", 0, 100000],
	"streak": ["int", 0, 100000],
	"targets_left": ["int", 0, 10000],
	"accuracy_percent": ["float", 0.0, 100.0],
	"round_seconds": ["float", 0.0, 86400.0],
	"weapon": ["enum", ["terminal_cannon"]],
	"mode": ["enum", ["practice", "deathmatch", "hunt"]],
}
## Characters removed from typed text besides control characters: direction overrides and
## isolates, marks and zero-width characters that could hide or reorder text.
const INVISIBLE := [0x061C, 0x200B, 0x200C, 0x200D, 0x200E, 0x200F, 0x202A, 0x202B, 0x202C, 0x202D, 0x202E, 0x2060, 0x2066, 0x2067, 0x2068, 0x2069, 0xFEFF]
const C0_LAST := 0x1F
const DELETE := 0x7F
const C1_FIRST := 0x80
const C1_LAST := 0x9F
const SPACE := 0x20
## Typed text is cut to this many times the cap before cleaning.
const INPUT_SLACK := 4

## The accepted stats, name to value, in STATS order when listed.
var stats := {}
## The player's text, cleaned and capped.
var text := ""


## A request from whatever the game hands in: only whitelisted stats survive.
static func build(raw_stats: Dictionary, typed: String, max_chars: int) -> RefCounted:
	var request = load("res://scripts/ai/guide_request.gd").new()
	for name in STATS:
		if raw_stats.has(name):
			var value = _accept(STATS[name], raw_stats[name])
			if value != null:
				request.stats[name] = value
	request.text = clean_text(typed, max_chars)
	return request


static func _accept(rule: Array, value: Variant) -> Variant:
	match rule[0]:
		"int":
			if typeof(value) == TYPE_INT and value >= rule[1] and value <= rule[2]:
				return value
		"float":
			if (typeof(value) == TYPE_FLOAT or typeof(value) == TYPE_INT) and is_finite(float(value)) and float(value) >= rule[1] and float(value) <= rule[2]:
				return float(value)
		"enum":
			if typeof(value) == TYPE_STRING and (rule[1] as Array).has(value):
				return value
	return null


## The player's text: control characters become spaces, invisible and direction-changing
## characters go, runs of spaces collapse, and the result is cut to `max_chars`.
static func clean_text(typed: String, max_chars: int) -> String:
	# Cut long input first (removed characters can only shorten it), and collect the kept
	# characters in an array: adding to a String copies it, which grows quadratically.
	var source := typed.left(maxi(max_chars, 0) * INPUT_SLACK)
	var kept := PackedStringArray()
	var last_space := true
	for i in source.length():
		var code := source.unicode_at(i)
		if code <= C0_LAST or code == DELETE or (code >= C1_FIRST and code <= C1_LAST) or code == SPACE:
			if not last_space:
				kept.append(" ")
				last_space = true
			continue
		if INVISIBLE.has(code):
			continue
		kept.append(source[i])
		last_space = false
	return "".join(kept).strip_edges().left(maxi(max_chars, 0)).strip_edges()


## The stats as one line, "name=value, ...", in STATS order.
func stats_line() -> String:
	var parts := PackedStringArray()
	for name in STATS:
		if stats.has(name):
			var value = stats[name]
			parts.append("%s=%s" % [name, ("%.1f" % value) if typeof(value) == TYPE_FLOAT else str(value)])
	return ", ".join(parts) if not parts.is_empty() else "none"


## The user part of a prompt: the stats line and the player's message.
func user_message() -> String:
	return "Game stats: %s\nPlayer: %s" % [stats_line(), text if text != "" else "(no message)"]


## The whole prompt, preamble first, for agents that take no separate system prompt.
func full_prompt() -> String:
	return PREAMBLE + "\n\n" + user_message()
