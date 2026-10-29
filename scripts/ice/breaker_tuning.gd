class_name BreakerTuning
extends Resource
## Every number of the ICEbreakers (I2): the intruder's one-use programs, carried beside the weapons.
## How many of each kind a round starts with and the most carried, the gap between two uses; the brute
## (a short-range charge: its reach, the share of it at full strength, its cone, its damage and how much
## harder a wall takes it), exploit (how long it lasts, how much harder a hit on a weak seam lands, how
## near a seam counts), cloak (how long, and its last warning), the decoy (how long it calls, how it is
## thrown, how far its call pulls) and the pickups (when the first comes, how often more come, how many
## at once, how near takes one). The default instance is resources/breakers.tres; scripts/ice/
## breaker_director.gd reads it. Units are metres, seconds, metres a second, degrees and health points.
## Fiction only: nothing here reads or touches anything real.

@export_group("Carried")
## Each kind's count when a round starts, and the most of a kind carried.
@export var start_count: int = 1
@export var carry_cap: int = 2
## The least time between two uses: a held key spends one.
@export var use_gap_s: float = 0.35

@export_group("brute")
## The charge reaches what is this near the eye (a wall's nearest point) inside its cone, at full
## strength within full_m and down to far_share of it at reach_m.
@export var brute_reach_m: float = 4.5
@export var brute_full_m: float = 2.25
@export var brute_far_share: float = 0.5
@export var brute_cone_deg: float = 40.0
## Its damage at full strength on a node, the hunter or a daemon (past ICE's hit cap: its own), and how
## many times that a wall takes (I1's brute hook): 120 x 5 = 600, a whole wall up close.
@export var brute_damage: float = 120.0
@export var brute_wall_scale: float = 5.0

@export_group("exploit")
## How long it runs, how many times harder a hit on a weak seam lands (after ICE's hit cap), and how
## near a seam (at the target's own size) a hit must land to count.
@export var exploit_s: float = 6.0
@export var exploit_scale: float = 2.5
@export var exploit_radius_m: float = 0.4

@export_group("cloak")
## How long ICE and the daemons cannot see the intruder (firing ends it sooner), and how long before its
## end the HUD warns.
@export var cloak_s: float = 5.0
@export var cloak_warn_s: float = 1.0

@export_group("decoy")
## How long it calls once thrown; its throw (forward speed, the lift, the pull down, the longest flight
## before it settles where it is); and how far its call pulls the hunter and the daemons (a node is
## pulled while the decoy is within its own trigger range).
@export var decoy_s: float = 7.0
@export var decoy_speed: float = 9.0
@export var decoy_lift: float = 3.0
@export var decoy_gravity: float = 16.0
@export var decoy_flight_s: float = 2.0
@export var decoy_pull_m: float = 26.0

@export_group("Pickups")
## The first pickup comes this long into a round, then another every pickup_every_s while fewer than
## pickups_live are out; walking this near one takes it (unless that kind is at its cap).
@export var pickup_first_s: float = 15.0
@export var pickup_every_s: float = 20.0
@export var pickups_live: int = 2
@export var pickup_take_m: float = 1.4

## The most of a kind anyone can carry, whatever the tuning: the wire's counts fit it.
const CARRY_LAST := 9
## [first, last] for every float above.
const RANGES := {
	"use_gap_s": [0.0, 5.0],
	"brute_reach_m": [0.5, 20.0], "brute_full_m": [0.0, 20.0], "brute_far_share": [0.0, 1.0], "brute_cone_deg": [1.0, 90.0],
	"brute_damage": [0.0, 10000.0], "brute_wall_scale": [1.0, 100.0],
	"exploit_s": [0.1, 60.0], "exploit_scale": [1.0, 20.0], "exploit_radius_m": [0.05, 3.0],
	"cloak_s": [0.1, 60.0], "cloak_warn_s": [0.0, 10.0],
	"decoy_s": [0.1, 60.0], "decoy_speed": [0.0, 60.0], "decoy_lift": [0.0, 30.0], "decoy_gravity": [0.0, 100.0], "decoy_flight_s": [0.1, 10.0], "decoy_pull_m": [1.0, 100.0],
	"pickup_first_s": [0.0, 600.0], "pickup_every_s": [1.0, 600.0], "pickup_take_m": [0.2, 10.0],
}


## Everything wrong with these values, or empty when they are safe to use.
func problems() -> PackedStringArray:
	var out := PackedStringArray()
	for key in RANGES:
		var v = get(key)
		var bounds: Array = RANGES[key]
		if not (v is float) or not is_finite(v) or v < bounds[0] or v > bounds[1]:
			out.append("%s must be between %s and %s" % [key, bounds[0], bounds[1]])
	if carry_cap < 1 or carry_cap > CARRY_LAST:
		out.append("carry_cap must be between 1 and %d" % CARRY_LAST)
	if start_count < 0 or start_count > carry_cap:
		out.append("start_count must be between 0 and carry_cap")
	if pickups_live < 0 or pickups_live > BreakerDirector.SPOTS.size():
		out.append("pickups_live must be between 0 and %d" % BreakerDirector.SPOTS.size())
	if brute_full_m > brute_reach_m:
		out.append("brute_full_m must not be past brute_reach_m")
	if cloak_warn_s >= cloak_s:
		out.append("cloak_warn_s must be shorter than cloak_s")
	return out


## The usable tuning: `candidate` when it is a BreakerTuning with no problems, else the shipped one,
## else the built-in defaults (each problem warned).
static func usable(candidate: Resource) -> BreakerTuning:
	var t := candidate as BreakerTuning
	if t == null:
		t = load("res://resources/breakers.tres") as BreakerTuning
	if t != null and t.problems().is_empty():
		return t
	if t != null:
		for issue in t.problems():
			push_warning("ICEbreaker tuning: " + issue + "; using the built-in defaults instead")
	return BreakerTuning.new()
