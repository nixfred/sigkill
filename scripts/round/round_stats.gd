extends RefCounted
## One round's numbers (C12), and nothing else: the round HUD feeds it from the game's own
## signals (the cannon's shot_fired, a dummy's downed, the player's jumped and slid, and how
## far the player moved), and payload() hands the whitelisted keys to the C9b request
## builder. Numbers only: no names, paths, system details or text ever live here. Since C27b
## the daemons fight back, so a round counts this player's deaths too (derezzed by a daemon
## alone, or by anything in a match), under the whitelist's own "deaths", which comes first.
##
## Each event also says which in-round callout it earns, if any, as a word: "first_derezz"
## for the round's first process down, "streak" at every streak_at hits in a row,
## "misses" at every misses_at misses in a row. The round HUD pages those to the screen
## through its rate limit. Callouts are game logic only; the AI never sees them.

## The keys payload() gives, in this order: exactly the round keys of the request whitelist, in
## the whitelist's order ("deaths" is one of its first, kept for the guide since C9b).
const KEYS := ["deaths", "round_number", "duration_s", "shots", "hits", "accuracy_pct", "derezzes", "longest_streak", "time_to_first_derezz_s", "distance_m", "slides", "jumps"]
## time_to_first_derezz_s when no process went down this round.
const NEVER := -1.0

var round_number := 1
var elapsed_s := 0.0
var shots := 0
var hits := 0
var derezzes := 0
## Hits in a row right now, and the most this round.
var streak := 0
var longest_streak := 0
var misses_in_a_row := 0
var first_derezz_s := NEVER
var distance_m := 0.0
var slides := 0
var jumps := 0
## Times this player was derezzed this round (C27b).
var deaths := 0

var _streak_at := 3
var _misses_at := 10


func _init(streak_at: int = 3, misses_at: int = 10) -> void:
	_streak_at = maxi(streak_at, 1)
	_misses_at = maxi(misses_at, 1)


## Starts round `number` from zero.
func reset(number: int) -> void:
	round_number = maxi(number, 1)
	elapsed_s = 0.0
	shots = 0
	hits = 0
	derezzes = 0
	streak = 0
	longest_streak = 0
	misses_in_a_row = 0
	first_derezz_s = NEVER
	distance_m = 0.0
	slides = 0
	jumps = 0
	deaths = 0


func tick(seconds: float) -> void:
	if is_finite(seconds) and seconds > 0.0:
		elapsed_s += seconds


## A shot from the cannon; `hit` when it struck a target. Returns its callout or "".
func on_shot(hit: bool) -> String:
	shots += 1
	if hit:
		hits += 1
		streak += 1
		misses_in_a_row = 0
		longest_streak = maxi(longest_streak, streak)
		return "streak" if streak % _streak_at == 0 else ""
	streak = 0
	misses_in_a_row += 1
	return "misses" if misses_in_a_row % _misses_at == 0 else ""


## A process went down. Returns its callout or "".
func on_derezz() -> String:
	derezzes += 1
	if first_derezz_s < 0.0:
		first_derezz_s = elapsed_s
		return "first_derezz"
	return ""


func on_jump() -> void:
	jumps += 1


## This player was derezzed (C27b).
func on_death() -> void:
	deaths += 1


func on_slide() -> void:
	slides += 1


func add_distance(meters: float) -> void:
	if is_finite(meters) and meters > 0.0:
		distance_m += meters


func accuracy_pct() -> float:
	return snappedf(100.0 * hits / shots, 0.1) if shots > 0 else 0.0


## The round's numbers under the whitelisted round keys: ints, and floats to one decimal.
func payload() -> Dictionary:
	return {
		"deaths": deaths,
		"round_number": round_number,
		"duration_s": snappedf(elapsed_s, 0.1),
		"shots": shots,
		"hits": hits,
		"accuracy_pct": accuracy_pct(),
		"derezzes": derezzes,
		"longest_streak": longest_streak,
		"time_to_first_derezz_s": snappedf(first_derezz_s, 0.1) if first_derezz_s >= 0.0 else NEVER,
		"distance_m": snappedf(distance_m, 0.1),
		"slides": slides,
		"jumps": jumps,
	}
