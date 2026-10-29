class_name FreezeTuning
extends Resource
## Every number of chmod 000, the freeze ray (C29, PRD 5.2: "chmod 000: freeze ray"): its coolant,
## how fast its beam strips a target's permissions (the freeze meter, "chill"), how long a full meter
## holds each kind of target frozen and how long after a thaw it cannot be frozen again, what a hit on a
## frozen daemon does, how a player is slowed, and how far Black ICE is slowed (never frozen). The
## shipped instance lives inside the weapon's own resource, resources/chmod_000.tres, which names it in
## its freeze slot; its beam tick (fire_cooldown) and reach (fire_range) are the WeaponDef's. Units are
## seconds, metres and health points; a share is from 0 to 1.
##
## The rules these feed: scripts/weapons/frost.gd (a target's freeze meter and freeze),
## scripts/weapons/coolant.gd (the beam's coolant). Cosmetic fiction: nothing real is chmodded, ever.

@export_group("Coolant")
## Seconds of beam a full tank holds.
@export var coolant_s: float = 4.0
## Seconds after the last beam tick before the tank starts to refill.
@export var coolant_rest_s: float = 0.6
## Seconds an empty tank takes to refill to full.
@export var coolant_refill_s: float = 3.0
## An emptied tank vents: no beam until it has refilled to this share of full.
@export var vent_share: float = 0.4

@export_group("Freeze meter")
## Seconds of beam that fill the freeze meter of a daemon, an elite daemon, a piece of ICE that freezes
## (the hunter and the nodes; walls ignore the beam) and a player.
@export var chill_s: float = 1.0
@export var elite_chill_s: float = 1.5
@export var ice_chill_s: float = 1.6
@export var player_chill_s: float = 1.5
## Seconds a meter holds once the beam leaves it, then the seconds a full one takes to melt to empty.
@export var chill_hold_s: float = 0.35
@export var chill_melt_s: float = 1.2

@export_group("Frozen")
## Seconds a full meter holds a daemon, a piece of ICE and a player frozen.
@export var freeze_s: float = 3.0
@export var ice_freeze_s: float = 2.2
@export var player_freeze_s: float = 1.0
## Seconds after a thaw in which the beam builds no meter: no chain of freezes. Daemons and ICE, then
## players.
@export var thaw_guard_s: float = 1.5
@export var player_guard_s: float = 2.5
## The most a player is slowed while its meter fills, a share of its pace (frozen it does not move).
@export var player_slow: float = 0.45

@export_group("Hits on the frozen")
## The next hit on a frozen daemon or piece of ICE lands this many times harder and thaws it.
@export var frozen_hit_scale: float = 2.0
## A hit at least this strong (its damage before any scale) on a frozen daemon shatters it outright,
## whatever its health; every kill of a frozen daemon is a shatter.
@export var shatter_damage: float = 40.0

@export_group("Black ICE")
## The most Black ICE is slowed while the beam holds on it, a share of its pace: never frozen, never
## hurt, its touch never stopped.
@export var black_slow: float = 0.4
## Seconds of beam to reach that slow, and seconds it takes to wear off once the beam leaves.
@export var black_slow_in_s: float = 0.6
@export var black_slow_out_s: float = 0.8

## The bounds every number is held to.
const SECONDS_LAST := 30.0
const SCALE_LAST := 10.0
## The brief's "up to about 40%": the tuning refuses more.
const BLACK_SLOW_LAST := 0.4
## A player is never slowed to a standstill by the meter alone.
const PLAYER_SLOW_LAST := 0.8
## A player's freeze stays short and fair.
const PLAYER_FREEZE_LAST := 2.0


## One line per value that would break the freeze ray. Empty means usable.
func problems() -> PackedStringArray:
	var out := PackedStringArray()
	for name in ["coolant_s", "coolant_refill_s", "chill_s", "elite_chill_s", "ice_chill_s", "player_chill_s", "chill_melt_s", "freeze_s", "ice_freeze_s", "player_freeze_s", "black_slow_in_s", "black_slow_out_s"]:
		var v: float = get(name)
		if not is_finite(v) or v <= 0.0 or v > SECONDS_LAST:
			out.append("%s must be above 0 and at most %s" % [name, SECONDS_LAST])
	for name in ["coolant_rest_s", "chill_hold_s", "thaw_guard_s", "player_guard_s"]:
		var v: float = get(name)
		if not is_finite(v) or v < 0.0 or v > SECONDS_LAST:
			out.append("%s must be between 0 and %s" % [name, SECONDS_LAST])
	if not is_finite(vent_share) or vent_share <= 0.0 or vent_share > 1.0:
		out.append("vent_share must be above 0 and at most 1")
	if not is_finite(player_slow) or player_slow < 0.0 or player_slow > PLAYER_SLOW_LAST:
		out.append("player_slow must be between 0 and %s" % PLAYER_SLOW_LAST)
	if is_finite(player_freeze_s) and player_freeze_s > PLAYER_FREEZE_LAST:
		out.append("player_freeze_s must be at most %s: a player's freeze is short" % PLAYER_FREEZE_LAST)
	if not is_finite(frozen_hit_scale) or frozen_hit_scale < 1.0 or frozen_hit_scale > SCALE_LAST:
		out.append("frozen_hit_scale must be between 1 and %s" % SCALE_LAST)
	if not is_finite(shatter_damage) or shatter_damage <= 0.0:
		out.append("shatter_damage must be above 0")
	if not is_finite(black_slow) or black_slow < 0.0 or black_slow > BLACK_SLOW_LAST:
		out.append("black_slow must be between 0 and %s: Black ICE is only ever slowed" % BLACK_SLOW_LAST)
	return out
