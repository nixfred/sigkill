class_name IceTuning
extends Resource
## Every number of ICE (I1): the system defending itself against the player, the intruder. White
## ICE's walls (how much damage breaks one, and the most any one hit takes off any piece of ICE),
## its two nodes (each one's reach before it starts its tell, the tell, how far its field reaches,
## how long its effect holds and the wait before the next), hunter ICE (from which round, its health,
## how it moves and hunts, its lance's tell, lock, damage and reach, the wait between attacks, how
## long it is gone after a kill) and its adaptation (the most it resists the weapon used most, and
## how much damage with that weapon builds it all the way). The default instance is
## resources/ice.tres; scripts/ice/ice_director.gd and the pieces read it. Units are metres,
## seconds, metres a second and health points. A tell is never shorter than TELL_FIRST_S: every
## ICE attack is readable. The difficulty's aggression (the daemons' tuning) shortens every wait
## between ICE's attacks, its damage scale the hunter's lance; the tells never change. Fiction only:
## nothing here reads or touches anything real.

@export_group("White ICE")
## A wall's health, and the most any one hit takes off any piece of ICE (the rail's 1000 included).
@export var barrier_health: float = 600.0
@export var hit_cap: float = 100.0
## A node's health; how often an idle node looks for an intruder.
@export var node_health: float = 150.0
@export var node_look_s: float = 0.2
## The jam node: an intruder this close and in sight starts its tell; at the tell's end every one
## within its field and in sight has the weapon in hand jammed; then it waits.
@export var jam_trigger_m: float = 9.0
@export var jam_tell_s: float = 1.2
@export var jam_field_m: float = 7.0
@export var jam_s: float = 2.5
@export var jam_cooldown_s: float = 7.0
## The HUD node: the same, its field scrambling parts of the HUD (never the health line).
@export var hud_trigger_m: float = 10.0
@export var hud_tell_s: float = 1.4
@export var hud_field_m: float = 8.0
@export var hud_s: float = 4.0
@export var hud_cooldown_s: float = 9.0
## How long a field's dome stays lit after it fires.
@export var field_show_s: float = 0.6

@export_group("Hunter ICE")
## The first round with a hunter (one at a time), and its health.
@export var hunter_from_round: int = 2
@export var hunter_health: float = 300.0
## How fast it moves, how far it keeps from its prey, its middle over the floor (it hovers).
@export var hunter_speed: float = 3.6
@export var hunter_keep_m: float = 9.0
@export var hunter_hover_m: float = 1.35
## It sees an intruder this close (no leash: it hunts the whole arena) and keeps on the last place it
## saw one for this long.
@export var hunter_aggro_m: float = 26.0
@export var hunter_lose_s: float = 6.0
## Its lance: the tell starts within range; through the tell its trace follows the prey, then holds
## still for the lock's last seconds of it (the moment to step aside), and the lance fires along it,
## as far as reach, hitting a prey within its radius of the line.
@export var hunter_range_m: float = 16.0
@export var hunter_reach_m: float = 22.0
@export var hunter_tell_s: float = 1.3
@export var hunter_lock_s: float = 0.35
@export var hunter_lance_radius_m: float = 0.55
@export var hunter_damage: float = 24.0
@export var hunter_strike_s: float = 0.25
@export var hunter_recover_s: float = 0.7
@export var hunter_cooldown_s: float = 3.2
## A killed hunter is gone this long, then a new one comes from its post.
@export var hunter_respawn_s: float = 15.0

@export_group("Adaptation")
## The most the hunter resists the weapon the intruders have dealt the most damage with this round
## (never immunity), and the damage with that weapon that builds it all the way.
@export var adapt_max: float = 0.5
@export var adapt_full_damage: float = 500.0

## No ICE tell is shorter than this.
const TELL_FIRST_S := 1.0
## [first, last] for every number above.
const RANGES := {
	"barrier_health": [1.0, 100000.0], "hit_cap": [1.0, 10000.0], "node_health": [1.0, 100000.0], "node_look_s": [0.0, 5.0],
	"jam_trigger_m": [1.0, 60.0], "jam_tell_s": [TELL_FIRST_S, 10.0], "jam_field_m": [0.5, 60.0], "jam_s": [0.1, 30.0], "jam_cooldown_s": [0.1, 120.0],
	"hud_trigger_m": [1.0, 60.0], "hud_tell_s": [TELL_FIRST_S, 10.0], "hud_field_m": [0.5, 60.0], "hud_s": [0.1, 30.0], "hud_cooldown_s": [0.1, 120.0],
	"field_show_s": [0.05, 5.0],
	"hunter_health": [1.0, 100000.0], "hunter_speed": [0.1, 20.0], "hunter_keep_m": [0.0, 50.0], "hunter_hover_m": [0.3, 3.0],
	"hunter_aggro_m": [1.0, 100.0], "hunter_lose_s": [0.1, 60.0], "hunter_range_m": [1.0, 100.0], "hunter_reach_m": [1.0, 200.0],
	"hunter_tell_s": [TELL_FIRST_S, 10.0], "hunter_lock_s": [0.0, 5.0], "hunter_lance_radius_m": [0.05, 5.0], "hunter_damage": [0.0, 1000.0],
	"hunter_strike_s": [0.02, 5.0], "hunter_recover_s": [0.0, 10.0], "hunter_cooldown_s": [0.1, 60.0], "hunter_respawn_s": [0.0, 600.0],
	"adapt_max": [0.0, 0.9], "adapt_full_damage": [1.0, 100000.0],
}
const ROUND_LAST := 999


## Everything wrong with these values, or empty when they are safe to use.
func problems() -> PackedStringArray:
	var out := PackedStringArray()
	for key in RANGES:
		var v = get(key)
		var bounds: Array = RANGES[key]
		if not (v is float) or not is_finite(v) or v < bounds[0] or v > bounds[1]:
			out.append("%s must be between %s and %s" % [key, bounds[0], bounds[1]])
	if hunter_from_round < 1 or hunter_from_round > ROUND_LAST:
		out.append("hunter_from_round must be between 1 and %d" % ROUND_LAST)
	if hunter_lock_s >= hunter_tell_s:
		out.append("hunter_lock_s must be shorter than hunter_tell_s")
	if hunter_reach_m < hunter_range_m:
		out.append("hunter_reach_m must be at least hunter_range_m")
	return out


## The usable tuning: `candidate` when it is an IceTuning with no problems, else the shipped one,
## else the built-in defaults (each problem warned).
static func usable(candidate: Resource) -> IceTuning:
	var t := candidate as IceTuning
	if t == null:
		t = load("res://resources/ice.tres") as IceTuning
	if t != null and t.problems().is_empty():
		return t
	if t != null:
		for issue in t.problems():
			push_warning("ICE tuning: " + issue + "; using the built-in defaults instead")
	return IceTuning.new()
