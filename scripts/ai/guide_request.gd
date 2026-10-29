extends RefCounted
## What the game may tell the player's AI guide, built from a whitelist (PRD 5.4: "only game
## stats and what the player types"). Only the named stats below get in, each checked for
## its type and range or its fixed list of values; anything else handed in, such as a file
## name, a path, a host name or a process name, is dropped without a trace. The player's
## typed text is capped and has its control and direction-changing characters removed.
## Nothing here reads the system; it only filters what the game passes in.
##
## Round-stat coaching (C12) uses the same builder: the round's numbers go in as stats (the
## round keys below, numbers only), with no typed text, and the request names one of the
## game's own fixed round tasks, coach or roast, whose instruction is added to the
## preamble. A task name the game does not know is dropped, so nothing but SIGKILL's own
## words can reach the instructions.
##
## The ICEbreaker pick (I2): between rounds and on T, while breakers are carried, the round's ICE and
## breaker numbers go in as stats too (the ICE keys below, numbers and the game's own weapon ids only:
## scripts/ice/breaker_pick.gd builds them), and a request carrying them adds the game's fixed
## BREAKER_LINE to its instructions, so the guide also names the breaker to load.
##
## Black ICE (I3): the pick's numbers carry it too (whether it is out, its seals standing, how far it is
## from the player in whole metres, whether it flatlined the player this round: numbers only), and a
## request with it out adds the game's fixed BLACK_ICE_LINE, so the guide recommends the decoy or the
## exploit and brute combo.

## The fixed instructions every guide gets, as its system prompt where the agent allows one.
const PREAMBLE := "You are the in-game guide in SIGKILL, a first-person shooter. Answer the player in at most three short lines. Use only the game stats and the player's message below. Do not use tools, do not read or write files, and do not run commands."

## The only stats a request can carry: [kind, low, high] for numbers, ["enum", values].
## "float_or_unset" is a float in range, or exactly -1 for "never happened".
const STATS := {
	"shots_fired": ["int", 0, 1000000],
	"hits_landed": ["int", 0, 1000000],
	"kills": ["int", 0, 100000],
	"deaths": ["int", 0, 100000],
	"streak": ["int", 0, 100000],
	"targets_left": ["int", 0, 10000],
	"accuracy_percent": ["float", 0.0, 100.0],
	"round_seconds": ["float", 0.0, 86400.0],
	"weapon": ["enum", ["terminal_cannon", "sigterm"]],
	"mode": ["enum", ["practice", "deathmatch", "hunt"]],
	# One round's numbers, for the coaching or roast at its end (C12).
	"round_number": ["int", 1, 100000],
	"duration_s": ["float", 0.0, 86400.0],
	"shots": ["int", 0, 1000000],
	"hits": ["int", 0, 1000000],
	"accuracy_pct": ["float", 0.0, 100.0],
	"derezzes": ["int", 0, 100000],
	"longest_streak": ["int", 0, 1000000],
	"time_to_first_derezz_s": ["float_or_unset", 0.0, 86400.0],
	"distance_m": ["float", 0.0, 1000000.0],
	"slides": ["int", 0, 100000],
	"jumps": ["int", 0, 100000],
	# The ICEbreaker pick's numbers (I2): ICE standing now, the hunter, and this player's breakers.
	"ice_walls": ["int", 0, 16],
	"ice_wall_health_pct": ["int", 0, 100],
	"ice_nodes": ["int", 0, 16],
	"ice_node_health_pct": ["int", 0, 100],
	"hunter_out": ["int", 0, 1],
	"hunter_health_pct": ["int", 0, 100],
	"hunter_adapted_weapon": ["enum", ["none", "terminal_cannon", "sigterm", "sigkill_rail", "fork_bomb", "fork_shotgun", "grep_seeker", "rm_rf_cannon", "cron_mines", "ping_sonar"]],
	"hunter_adapted_pct": ["int", 0, 100],
	"breakers_brute": ["int", 0, 9],
	"breakers_exploit": ["int", 0, 9],
	"breakers_cloak": ["int", 0, 9],
	"breakers_decoy": ["int", 0, 9],
	# Black ICE (I3): out or not, its seals standing, how far from the player, a flatline this round.
	"black_ice_out": ["int", 0, 1],
	"black_ice_seals": ["int", 0, 9],
	"black_ice_distance_m": ["int", 0, 1000],
	"black_ice_flatlined": ["int", 0, 1],
}
## The game's own instructions for the end of a round, by task name. Only these words, and
## never anything the player or an AI wrote, are ever added to the preamble.
const TASKS := {
	"coach": "The round just ended. Give the player one concrete tip for the next round, drawn from these round numbers, in one or two short sentences.",
	"roast": "The round just ended. Roast the player's play in this round, PG-13, in one or two short sentences. Mock the play and the numbers only, never the player as a person. No slurs, nothing hateful, no profanity beyond mild words.",
}
## The game's own instruction added to a request carrying the ICEbreaker numbers (I2).
const BREAKER_LINE := "ICE is in the arena. Also name the one ICEbreaker the player should load next (brute, exploit, cloak or decoy), from the ICE and breaker numbers, in one short sentence that starts with the breaker's name."
## A stat only the ICEbreaker numbers carry: its presence adds BREAKER_LINE.
const BREAKER_KEY := "breakers_brute"
## The game's own instruction added while Black ICE is out (I3: black_ice_out is 1).
const BLACK_ICE_LINE := "Black ICE is out: weapons cannot hurt it and its touch flatlines the player. Only an exploit, then a brute charge while that exploit runs, breaks one of its seals (black_ice_seals of them stand), and a decoy pulls it away. Recommend the decoy, or that exploit and brute combo when the player carries enough brutes for its seals."
const BLACK_ICE_KEY := "black_ice_out"
const UNSET := -1.0
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
## The round task, "coach" or "roast", or "" for an ordinary ask.
var task := ""


## A request from whatever the game hands in: only whitelisted stats survive, and only a
## task named in TASKS.
static func build(raw_stats: Dictionary, typed: String, max_chars: int, task_name: String = "") -> RefCounted:
	var request = load("res://scripts/ai/guide_request.gd").new()
	for name in STATS:
		if raw_stats.has(name):
			var value = _accept(STATS[name], raw_stats[name])
			if value != null:
				request.stats[name] = value
	request.text = clean_text(typed, max_chars)
	request.task = task_name if TASKS.has(task_name) else ""
	return request


static func _accept(rule: Array, value: Variant) -> Variant:
	match rule[0]:
		"int":
			if typeof(value) == TYPE_INT and value >= rule[1] and value <= rule[2]:
				return value
		"float", "float_or_unset":
			if (typeof(value) == TYPE_FLOAT or typeof(value) == TYPE_INT) and is_finite(float(value)):
				if float(value) >= rule[1] and float(value) <= rule[2]:
					return float(value)
				if rule[0] == "float_or_unset" and float(value) == UNSET:
					return UNSET
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


## The fixed instructions for this request: the preamble, plus the round task's own line, plus the
## ICEbreaker pick's line when it carries the breaker numbers (I2).
func preamble() -> String:
	var out: String = PREAMBLE if task == "" else PREAMBLE + " " + TASKS[task]
	if stats.has(BREAKER_KEY):
		out += " " + BREAKER_LINE
	if int(stats.get(BLACK_ICE_KEY, 0)) == 1:
		out += " " + BLACK_ICE_LINE
	return out


## The whole prompt, preamble first, for agents that take no separate system prompt.
func full_prompt() -> String:
	return preamble() + "\n\n" + user_message()
