class_name DevNullTuning
extends Resource
## Every number of /dev/null, the black-hole grenade (C31, PRD 5.2: "/dev/null: black-hole grenade"): the
## throw, the charges and their recharge, and the singularity it opens: how long it lasts, how far it pulls
## and how hard, what it does to what it holds, the core that discards, and the implosion that ends it. The
## shipped instance lives inside the weapon's own resource, resources/dev_null.tres, which names it in its
## projectile slot (the fork bomb's slot: a thrown weapon); the throw's interval (fire_cooldown) and the
## charges (magazine_size) are the WeaponDef's. Units are metres, seconds and health points; a share is
## from 0 to 1.
##
## The rules these feed: scripts/weapons/dev_null_hole.gd. Cosmetic fiction only: "/dev/null" is a name,
## nothing real is opened, written or discarded, ever.

## The bounds of its numbers.
const SPEED_LAST := 40.0
const FUSE_LAST_S := 5.0
const LIVE_LAST := 4
const RECHARGE_LAST_S := 120.0
const HOLD_LAST_S := 12.0
const RADIUS_LAST_M := 20.0
const PULL_LAST := 30.0
const DAMAGE_LAST := 1000.0
const TICK_FIRST_S := 0.05

@export_group("Throw")
## The device leaves the hand at throw_speed along the aim plus throw_lift straight up, falls at gravity,
## and opens where it first meets the level or a body, or in the air when fuse_s runs out.
@export var throw_speed: float = 13.0
@export var throw_lift: float = 3.0
@export var gravity: float = 15.0
@export var fuse_s: float = 1.6
## The device's size in flight, metres.
@export var device_radius_m: float = 0.13
## Holes one player has open at once (the second throw waits for the first to close).
@export var live_cap: int = 1
## Seconds for one spent charge to come back, while under the magazine's charges (a new life fills them).
@export var recharge_s: float = 16.0

@export_group("Singularity")
## It grows to its full size over open_s, pulls for hold_s, then collapses into its implosion over collapse_s.
@export var open_s: float = 0.4
@export var hold_s: float = 4.0
@export var collapse_s: float = 0.35
## The core floats this high over the point the device stopped.
@export var core_height_m: float = 1.0
## How far it pulls (radius_m), where its damage starts (horizon_m) and the core that discards (core_m),
## each from the core's vertical axis.
@export var radius_m: float = 9.0
@export var horizon_m: float = 3.0
@export var core_m: float = 0.8
## C22's root, one more of the weapon's own thing: a root's hole pulls this many times as far.
@export var root_radius_scale: float = 1.25

@export_group("Pull")
## Metres a second it drags a held thing at its edge and at the core, easing between them by pull_curve
## (2: the pull grows with the square of how far in it is), and the share of that it swirls it round.
@export var pull_edge: float = 1.0
@export var pull_core: float = 7.5
@export var pull_curve: float = 2.0
@export var swirl_share: float = 0.55
## Its strength grows from ramp_floor of full to full over ramp_s after it opens.
@export var ramp_s: float = 1.0
@export var ramp_floor: float = 0.35
## The most it drags a player, metres a second: under a run's 7, so a player who runs out gets out.
@export var player_pull_cap: float = 4.2

@export_group("Damage")
## Inside the horizon a held thing takes dps_horizon a second at the horizon rising to dps_core at the core,
## dealt every tick_s; outside it, nothing (the pull alone).
@export var dps_horizon: float = 8.0
@export var dps_core: float = 40.0
@export var tick_s: float = 0.25
## What reaching the core deals, once to each thing: a daemon is discarded (it dies; chmod 000's frozen one
## shatters, C29), ICE takes its own hit cap, a player is discarded (killed).
@export var discard_damage: float = 500.0
## The implosion: everything still held within pulse_radius_m takes pulse_damage at the core easing to
## pulse_edge_damage at that radius.
@export var pulse_radius_m: float = 5.0
@export var pulse_damage: float = 45.0
@export var pulse_edge_damage: float = 10.0


## One line per value that would break the throw or the hole. Empty means usable.
func problems() -> PackedStringArray:
	var out := PackedStringArray()
	if not is_finite(throw_speed) or throw_speed <= 0.0 or throw_speed > SPEED_LAST:
		out.append("throw_speed must be above 0 and at most %s" % SPEED_LAST)
	if not is_finite(throw_lift) or throw_lift < 0.0 or throw_lift > SPEED_LAST:
		out.append("throw_lift must be 0 to %s" % SPEED_LAST)
	if not is_finite(gravity) or gravity <= 0.0 or gravity > 100.0:
		out.append("gravity must be above 0 and at most 100")
	if not is_finite(fuse_s) or fuse_s <= 0.0 or fuse_s > FUSE_LAST_S:
		out.append("fuse_s must be above 0 and at most %s" % FUSE_LAST_S)
	if not is_finite(device_radius_m) or device_radius_m <= 0.0 or device_radius_m > 0.5:
		out.append("device_radius_m must be above 0 and at most 0.5")
	if live_cap < 1 or live_cap > LIVE_LAST:
		out.append("live_cap must be 1 to %d" % LIVE_LAST)
	if not is_finite(recharge_s) or recharge_s <= 0.0 or recharge_s > RECHARGE_LAST_S:
		out.append("recharge_s must be above 0 and at most %s" % RECHARGE_LAST_S)
	for pair in [["open_s", open_s], ["collapse_s", collapse_s]]:
		if not is_finite(pair[1]) or pair[1] <= 0.0 or pair[1] > 2.0:
			out.append("%s must be above 0 and at most 2" % pair[0])
	if not is_finite(hold_s) or hold_s <= 0.0 or hold_s > HOLD_LAST_S:
		out.append("hold_s must be above 0 and at most %s" % HOLD_LAST_S)
	if not is_finite(core_height_m) or core_height_m < 0.0 or core_height_m > 3.0:
		out.append("core_height_m must be 0 to 3")
	if not is_finite(radius_m) or radius_m <= 0.0 or radius_m > RADIUS_LAST_M:
		out.append("radius_m must be above 0 and at most %s" % RADIUS_LAST_M)
	elif not is_finite(horizon_m) or horizon_m <= 0.0 or horizon_m >= radius_m:
		out.append("horizon_m must be above 0 and under radius_m")
	elif not is_finite(core_m) or core_m <= 0.0 or core_m >= horizon_m:
		out.append("core_m must be above 0 and under horizon_m")
	if not is_finite(root_radius_scale) or root_radius_scale < 1.0 or root_radius_scale > 2.0:
		out.append("root_radius_scale must be 1 to 2")
	if not is_finite(pull_edge) or not is_finite(pull_core) or pull_edge < 0.0 or pull_core < pull_edge or pull_core > PULL_LAST:
		out.append("pulls must be 0 <= pull_edge <= pull_core <= %s: the pull grows inward" % PULL_LAST)
	if not is_finite(pull_curve) or pull_curve < 0.5 or pull_curve > 4.0:
		out.append("pull_curve must be 0.5 to 4")
	if not is_finite(swirl_share) or swirl_share < 0.0 or swirl_share > 2.0:
		out.append("swirl_share must be 0 to 2")
	if not is_finite(ramp_s) or ramp_s < 0.0 or ramp_s > hold_s:
		out.append("ramp_s must be 0 to hold_s")
	if not is_finite(ramp_floor) or ramp_floor <= 0.0 or ramp_floor > 1.0:
		out.append("ramp_floor must be above 0 and at most 1")
	if not is_finite(player_pull_cap) or player_pull_cap < 0.0 or player_pull_cap >= 7.0:
		out.append("player_pull_cap must be 0 or more and under a run's 7 m/s: a player can always run out")
	if not is_finite(dps_horizon) or not is_finite(dps_core) or dps_horizon < 0.0 or dps_core < dps_horizon or dps_core > DAMAGE_LAST:
		out.append("damage must be 0 <= dps_horizon <= dps_core <= %s" % DAMAGE_LAST)
	if not is_finite(tick_s) or tick_s < TICK_FIRST_S or tick_s > 1.0:
		out.append("tick_s must be %s to 1" % TICK_FIRST_S)
	if not is_finite(discard_damage) or discard_damage <= 0.0 or discard_damage > DAMAGE_LAST:
		out.append("discard_damage must be above 0 and at most %s" % DAMAGE_LAST)
	if not is_finite(pulse_radius_m) or pulse_radius_m <= 0.0 or pulse_radius_m > radius_m:
		out.append("pulse_radius_m must be above 0 and at most radius_m")
	if not is_finite(pulse_damage) or not is_finite(pulse_edge_damage) or pulse_edge_damage < 0.0 or pulse_damage < pulse_edge_damage or pulse_damage > DAMAGE_LAST:
		out.append("pulse damage must be 0 <= pulse_edge_damage <= pulse_damage <= %s" % DAMAGE_LAST)
	return out


## How far a hole pulls, as root or not.
func reach_for(root: bool) -> float:
	return radius_m * (root_radius_scale if root else 1.0)


## The drag at `distance` metres from the core's axis of a hole reaching `reach`, `age` seconds after it
## opened: metres a second toward the axis (0 beyond its reach), before the swirl.
func pull_at(distance: float, reach: float, age: float) -> float:
	if distance >= reach or reach <= 0.0:
		return 0.0
	var depth := clampf(1.0 - distance / reach, 0.0, 1.0)
	return (pull_edge + (pull_core - pull_edge) * pow(depth, pull_curve)) * ramp_at(age)


## The pull's strength `age` seconds after it opened: ramp_floor growing to full over ramp_s.
func ramp_at(age: float) -> float:
	if ramp_s <= 0.0:
		return 1.0
	return lerpf(ramp_floor, 1.0, smoothstep(0.0, ramp_s, maxf(age, 0.0)))


## Damage a second at `distance` from the core's axis: nothing outside the horizon, dps_horizon at it
## rising to dps_core at the axis.
func dps_at(distance: float) -> float:
	if distance >= horizon_m:
		return 0.0
	return lerpf(dps_core, dps_horizon, clampf(distance / horizon_m, 0.0, 1.0))


## The implosion's damage at `distance` from the core: pulse_damage easing to pulse_edge_damage at
## pulse_radius_m, nothing beyond it.
func pulse_at(distance: float) -> float:
	if distance > pulse_radius_m:
		return 0.0
	return lerpf(pulse_damage, pulse_edge_damage, clampf(distance / pulse_radius_m, 0.0, 1.0))


## The charges after `delta` seconds: `mag` of `most`, with `left` seconds to the next coming back (0 when
## none is coming). A spent charge starts its recharge; full stops it. [mag, left]: the player's inventory
## and the match's host count the same way, the host `slack` (a share) quicker, so it is never stricter than
## an honest player's game.
func step_charges(mag: int, most: int, left: float, delta: float, slack: float = 0.0) -> Array:
	if mag >= most:
		return [mag, 0.0]
	var wait := recharge_s * (1.0 - clampf(slack, 0.0, 0.5))
	if left <= 0.0:
		left = wait
	left -= delta
	if left <= 0.0:
		mag += 1
		left = wait + left if mag < most else 0.0
	return [mag, left]


## Seconds from opening to the end of the collapse.
func life_s() -> float:
	return open_s + hold_s + collapse_s
