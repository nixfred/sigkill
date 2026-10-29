class_name BlackIceTuning
extends Resource
## Every number of Black ICE (I3): the machine's last line of defence. How rare it is (never in round 1,
## at most one a round, its chance from its first round on rising a step a round to its most, its arrival
## somewhere in a window of the round's play), its arrival (a long tell: the warning, the lights going down
## over its first seconds and how dark they go), its body (how big, how near a player's middle flatlines
## it), how it moves (slower than a running player, a slower drift toward an intruder it cannot see, how
## far it sees, how long it keeps a lost one's place, how fast it turns), what kills it (how many seals,
## each broken only by a brute while that intruder's exploit runs; how long a broken seal takes to mend;
## how far and how long a broken seal throws it back) and how long it takes to withdraw. The default
## instance is resources/black_ice.tres; scripts/ice/ice_director.gd and scripts/ice/black_ice.gd read
## it. Units are metres, seconds, metres a second and radians a second. Fiction only: nothing here reads
## or touches anything real.

@export_group("Rarity")
## Its first round (never round 1), its chance then, the chance added each round after, the most.
@export var from_round: int = 2
@export var chance_first: float = 0.2
@export var chance_step: float = 0.1
@export var chance_most: float = 0.4
## It arrives this far into the round's play, somewhere between the two (seeded).
@export var arrive_first_s: float = 20.0
@export var arrive_last_s: float = 40.0

@export_group("Arrival")
## The arrival's tell: the warning up, the arena's lights dying over dim_s to lights_low of themselves,
## the hum dropping out and the guide's link cut, the presence forming; nothing touches before its end.
@export var tell_s: float = 6.0
@export var dim_s: float = 2.0
@export var lights_low: float = 0.1
## Gone (broken or withdrawn): the lights and the hum come back over this long.
@export var restore_s: float = 1.5

@export_group("Body")
## Its body's radius and height (its hit volume, what blocks its steps), and how near its axis (flat) a
## player's middle must come to touch it: its radius and a player's.
@export var radius_m: float = 1.25
@export var height_m: float = 4.4
@export var touch_m: float = 1.65

@export_group("Movement")
## Its speed on an intruder it sees (well under a running player's 7), its drift toward the nearest one
## it cannot see, how far it sees, how long it keeps a lost one's last place, how fast it turns.
@export var speed: float = 4.0
@export var drift_speed: float = 2.4
@export var sight_m: float = 45.0
@export var lose_s: float = 6.0
@export var turn_rate: float = 1.8

@export_group("Seals")
## Its seals: each one broken only by a brute charge reaching it while that intruder's exploit runs;
## the last one broken kills it. A broken seal mends after seal_mend_s unless the last goes first; a
## broken seal throws it back reel_m along the charge over reel_s, in which it does not hunt.
@export var seals: int = 2
@export var seal_mend_s: float = 12.0
@export var reel_s: float = 1.2
@export var reel_m: float = 3.0

@export_group("Withdrawing")
## At the round's end it withdraws, sinking away over this long.
@export var withdraw_s: float = 1.6

## The arrival's tell is never shorter than this: several seconds.
const TELL_FIRST_S := 3.0
## A running player's top speed (resources/movement_tuning.tres walk_speed): Black ICE is always slower.
const RUN_M_S := 7.0
## The most seals it can have: the wire's word fits it.
const SEALS_LAST := 9
## [first, last] for every float above.
const RANGES := {
	"chance_first": [0.0, 1.0], "chance_step": [0.0, 1.0], "chance_most": [0.0, 1.0],
	"arrive_first_s": [0.0, 600.0], "arrive_last_s": [0.0, 600.0],
	"tell_s": [TELL_FIRST_S, 30.0], "dim_s": [0.0, 30.0], "lights_low": [0.0, 1.0], "restore_s": [0.0, 30.0],
	"radius_m": [0.3, 4.0], "height_m": [1.0, 12.0], "touch_m": [0.3, 6.0],
	"speed": [0.5, RUN_M_S * 0.8], "drift_speed": [0.0, RUN_M_S * 0.8], "sight_m": [1.0, 200.0], "lose_s": [0.0, 60.0], "turn_rate": [0.1, 20.0],
	"seal_mend_s": [0.5, 120.0], "reel_s": [0.0, 10.0], "reel_m": [0.0, 20.0],
	"withdraw_s": [0.1, 10.0],
}


## Its chance in round `number`: none before from_round (never round 1), then chance_first rising
## chance_step a round, never past chance_most.
func chance(number: int) -> float:
	if number < maxi(from_round, 2):
		return 0.0
	return minf(chance_first + chance_step * (number - from_round), chance_most)


## Everything wrong with these values, or empty when they are safe to use.
func problems() -> PackedStringArray:
	var out := PackedStringArray()
	for key in RANGES:
		var v = get(key)
		var bounds: Array = RANGES[key]
		if not (v is float) or not is_finite(v) or v < bounds[0] or v > bounds[1]:
			out.append("%s must be between %s and %s" % [key, bounds[0], bounds[1]])
	if from_round < 2 or from_round > IceTuning.ROUND_LAST:
		out.append("from_round must be 2 or later: never in round 1")
	if seals < 1 or seals > SEALS_LAST:
		out.append("seals must be between 1 and %d" % SEALS_LAST)
	if arrive_first_s > arrive_last_s:
		out.append("arrive_first_s must not be past arrive_last_s")
	if dim_s > tell_s:
		out.append("dim_s must not be past tell_s")
	if drift_speed > speed:
		out.append("drift_speed must not be past speed")
	if touch_m < radius_m:
		out.append("touch_m must reach its body: at least radius_m")
	return out


## The usable tuning: `candidate` when it is a BlackIceTuning with no problems, else the shipped one,
## else the built-in defaults (each problem warned).
static func usable(candidate: Resource) -> BlackIceTuning:
	var t := candidate as BlackIceTuning
	if t == null:
		t = load("res://resources/black_ice.tres") as BlackIceTuning
	if t != null and t.problems().is_empty():
		return t
	if t != null:
		for issue in t.problems():
			push_warning("Black ICE tuning: " + issue + "; using the built-in defaults instead")
	return BlackIceTuning.new()
