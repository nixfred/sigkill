class_name DaemonAiTuning
extends Resource
## Every number of the daemons fighting back (C27b): how far a daemon sees and how far it
## chases from its spot, how many may go for one player at once, and each type's attack: its
## tell, its strike and its damage, how fast it moves and how long it waits between attacks.
## The difficulty's two multipliers live here too: damage scales every hit a daemon lands,
## aggression shortens every wait between attacks (the tells never get shorter: an attack is
## always readable). The default instance is resources/daemon_ai.tres; the brains
## (scripts/daemons/daemon_brain.gd) and their director (scripts/daemons/daemon_director.gd)
## read it. Units are metres, seconds, metres a second and health points. Fiction only:
## nothing here touches a real process.

@export_group("Hunting")
## A daemon sees a player this close, with nothing of the level between its eye and the
## player's middle, and hunts it.
@export var aggro_range_m: float = 16.0
## It chases at most this far from its spot, then goes home.
@export var leash_m: float = 14.0
## Seconds without sight of its prey before it gives up on the last place it saw it.
@export var lose_s: float = 2.5
## At most this many daemons tell or attack one player at the same time.
@export var max_attackers: int = 2
## Where a walking daemon looks from, above its feet.
@export var eye_height_m: float = 1.2
## How fast it turns to face its prey, in radians a second.
@export var turn_rate: float = 6.0
## How far it keeps from other daemons, and how far ahead its feelers reach for walls.
@export var keep_apart_m: float = 1.8
@export var feeler_m: float = 1.6

@export_group("rogue.d")
## It walks this fast, and starts its tell once its prey is this close.
@export var rogue_speed: float = 4.5
@export var rogue_reach_m: float = 2.4
## The tell: rearing up, this long.
@export var rogue_tell_s: float = 0.6
## The lunge: how far it carries the body and how long it takes; the slash at its end lands
## on a player whose middle is within slash_m of where the scythes come down.
@export var rogue_lunge_m: float = 1.4
@export var rogue_strike_s: float = 0.25
@export var rogue_slash_m: float = 1.5
@export var rogue_damage: float = 20.0
## Seconds it settles after a strike, and the least time from one strike to its next tell.
@export var rogue_recover_s: float = 0.5
@export var rogue_cooldown_s: float = 1.8

@export_group("zombie")
## It shambles this fast, stops closing in this close, and fires within this range.
@export var zombie_speed: float = 1.4
@export var zombie_keep_m: float = 6.0
@export var zombie_range_m: float = 14.0
## The tell: its ember swelling in its raised claw, this long.
@export var zombie_tell_s: float = 0.7
## The bolt: how fast it flies (slow enough to sidestep), how big it is, how long it lives and
## what it takes off a player it meets.
@export var zombie_bolt_speed: float = 9.0
@export var zombie_bolt_radius_m: float = 0.3
@export var zombie_bolt_life_s: float = 2.5
@export var zombie_bolt_damage: float = 12.0
@export var zombie_recover_s: float = 0.4
@export var zombie_cooldown_s: float = 2.6

@export_group("runaway")
## It flies this fast round its prey, this far out, this high over its spot's floor.
@export var swarm_speed: float = 5.5
@export var swarm_orbit_m: float = 5.0
## The tell: the swarm pulling in tight and brightening, this long, before each dive.
@export var swarm_tell_s: float = 0.45
## The dive: how fast, at most how long, and how close it must pass a player to chip it.
@export var swarm_dive_speed: float = 12.0
@export var swarm_dive_s: float = 0.7
@export var swarm_hit_m: float = 1.0
@export var swarm_damage: float = 5.0
## Dives in one burst, the wait between them, and the wait after a burst.
@export var swarm_burst: int = 3
@export var swarm_burst_gap_s: float = 0.35
@export var swarm_cooldown_s: float = 3.0
## A hit scatters it: it flees the shot this fast for this long, and any dive is off.
@export var swarm_scatter_s: float = 1.0
@export var swarm_scatter_speed: float = 7.0

@export_group("Difficulty")
## Every daemon's damage times this, and every wait between its attacks divided by its
## aggression, on easy, normal and hard.
@export var easy_damage: float = 0.6
@export var easy_aggression: float = 0.75
@export var normal_damage: float = 1.0
@export var normal_aggression: float = 1.0
@export var hard_damage: float = 1.5
@export var hard_aggression: float = 1.35

## The difficulties, as the settings name them.
const DIFFICULTIES := ["easy", "normal", "hard"]
## [first, last] for every number above.
const RANGES := {
	"aggro_range_m": [1.0, 100.0], "leash_m": [1.0, 100.0], "lose_s": [0.1, 30.0],
	"eye_height_m": [0.1, 3.0], "turn_rate": [0.5, 50.0], "keep_apart_m": [0.0, 10.0], "feeler_m": [0.2, 10.0],
	"rogue_speed": [0.1, 20.0], "rogue_reach_m": [0.5, 10.0], "rogue_tell_s": [0.2, 5.0], "rogue_lunge_m": [0.0, 10.0],
	"rogue_strike_s": [0.05, 2.0], "rogue_slash_m": [0.3, 5.0], "rogue_damage": [0.0, 1000.0], "rogue_recover_s": [0.0, 10.0], "rogue_cooldown_s": [0.1, 60.0],
	"zombie_speed": [0.1, 20.0], "zombie_keep_m": [0.0, 50.0], "zombie_range_m": [1.0, 100.0], "zombie_tell_s": [0.2, 5.0],
	"zombie_bolt_speed": [1.0, 100.0], "zombie_bolt_radius_m": [0.05, 2.0], "zombie_bolt_life_s": [0.2, 30.0], "zombie_bolt_damage": [0.0, 1000.0],
	"zombie_recover_s": [0.0, 10.0], "zombie_cooldown_s": [0.1, 60.0],
	"swarm_speed": [0.1, 30.0], "swarm_orbit_m": [0.5, 30.0], "swarm_tell_s": [0.2, 5.0], "swarm_dive_speed": [1.0, 60.0], "swarm_dive_s": [0.1, 5.0],
	"swarm_hit_m": [0.1, 5.0], "swarm_damage": [0.0, 1000.0], "swarm_burst_gap_s": [0.0, 10.0], "swarm_cooldown_s": [0.1, 60.0],
	"swarm_scatter_s": [0.0, 10.0], "swarm_scatter_speed": [0.0, 50.0],
	"easy_damage": [0.0, 10.0], "easy_aggression": [0.1, 10.0], "normal_damage": [0.0, 10.0], "normal_aggression": [0.1, 10.0],
	"hard_damage": [0.0, 10.0], "hard_aggression": [0.1, 10.0],
}
const ATTACKERS_LAST := 16
const BURST_LAST := 10


## Everything wrong with these values, or empty when they are safe to use.
func problems() -> PackedStringArray:
	var out := PackedStringArray()
	for key in RANGES:
		var v = get(key)
		var bounds: Array = RANGES[key]
		if not (v is float) or not is_finite(v) or v < bounds[0] or v > bounds[1]:
			out.append("%s must be between %s and %s" % [key, bounds[0], bounds[1]])
	if max_attackers < 1 or max_attackers > ATTACKERS_LAST:
		out.append("max_attackers must be between 1 and %d" % ATTACKERS_LAST)
	if swarm_burst < 1 or swarm_burst > BURST_LAST:
		out.append("swarm_burst must be between 1 and %d" % BURST_LAST)
	if leash_m < rogue_reach_m:
		out.append("leash_m must be at least rogue_reach_m")
	return out


## Every daemon's damage times this at `difficulty` ("easy", "normal" or "hard"; anything else
## is normal).
func damage_scale(difficulty: String) -> float:
	match difficulty:
		"easy":
			return easy_damage
		"hard":
			return hard_damage
	return normal_damage


## Every wait between a daemon's attacks divided by this at `difficulty`.
func aggression(difficulty: String) -> float:
	match difficulty:
		"easy":
			return easy_aggression
		"hard":
			return hard_aggression
	return normal_aggression
