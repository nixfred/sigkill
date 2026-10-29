class_name SighupTuning
extends Resource
## Every number of SIGHUP, the confusion grenade (C32, PRD 5.2: "SIGHUP: confusion grenade; enemies 'reload'
## and wander"): the throw, the charges and their recharge, the hangup's burst (how far it reaches and how
## fast its wave runs out), what it does to a daemon it catches (the reload stall, the confused wander, its
## lashes at the daemons round it, the guard after that keeps it from being held confused for ever), to ICE
## (the nodes' reload) and to a player in a match (a short confusion on that player's own screen). The
## shipped instance lives inside the weapon's own resource, resources/sighup.tres, which names it in its
## projectile slot (the fork bomb's slot: a thrown weapon); the throw's interval (fire_cooldown) and the
## charges (magazine_size) are the WeaponDef's. Units are metres, seconds and health points; a share is from
## 0 to 1. It does no damage of its own: its value is control.
##
## The rules these feed: scripts/weapons/sighup_burst.gd and the daemons' brain (scripts/fight/
## daemon_brain.gd). Cosmetic fiction only: SIGHUP is a name, no real signal is ever sent to anything.

## The bounds of its numbers.
const SPEED_LAST := 40.0
const FUSE_LAST_S := 5.0
const LIVE_LAST := 4
const RECHARGE_LAST_S := 120.0
const RADIUS_LAST_M := 20.0
const WAVE_FIRST := 2.0
const WAVE_LAST := 200.0
const CONFUSE_LAST_S := 20.0
const SHARE_LAST := 3.0
const SHIPPED_PATH := "res://resources/sighup.tres"

static var _shipped: SighupTuning

@export_group("Throw")
## The device leaves the hand at throw_speed along the aim plus throw_lift straight up, falls at gravity, and
## goes off where it first meets the level or a body, or in the air when fuse_s runs out.
@export var throw_speed: float = 14.0
@export var throw_lift: float = 3.0
@export var gravity: float = 15.0
@export var fuse_s: float = 1.2
## The device's size in flight, metres.
@export var device_radius_m: float = 0.12
## Devices one player has in the air at once (a third throw waits for one to go off).
@export var live_cap: int = 2
## Seconds for one spent charge to come back, while under the magazine's charges (a new life fills them).
@export var recharge_s: float = 12.0

@export_group("Burst")
## The hangup reaches radius_m from where it went off (as root, root_radius_scale times as far: C22's one
## more of the weapon's own thing), its wave running out at wave_speed metres a second: each thing in reach
## and in sight of the burst is caught as the wave's front passes it. The burst's middle sits burst_lift_m
## over where the device stopped, for its sight over a low floor's lip.
@export var radius_m: float = 7.0
@export var root_radius_scale: float = 1.25
@export var wave_speed: float = 14.0
@export var burst_lift_m: float = 0.5

@export_group("Confusion")
## A daemon caught calls off what it was doing, drops its target and stalls for reload_s ("reloading
## config"), then wanders confused for wander_s: no idea where anyone is, a random walk at wander_share of
## its own speed in legs of leg_s, stopping between them for look_s to look round (its facing swept by up to
## look_sweep radians either way, in snaps), its motion stuttering (still for stutter_share of each beat, at
## stutter_hz). When it ends the daemon is guarded for immune_s: a hangup then is refused, so no one daemon
## can be held confused for ever (the most it can be confused is reload_s + wander_s of every reload_s +
## wander_s + immune_s).
@export var reload_s: float = 1.2
@export var wander_s: float = 4.0
@export var immune_s: float = 6.0
@export var wander_share: float = 0.55
@export var leg_s: float = 1.1
@export var look_s: float = 0.6
@export var look_sweep: float = 1.1
@export var stutter_hz: float = 5.0
@export var stutter_share: float = 0.3

@export_group("Lashes")
## A crowd turns on itself a little: wandering confused, a daemon with another daemon within lash_range_m in
## sight of it lashes at that one (the nearest) with its own attack (its tell, then rogue.d's lunge and
## slash, the zombie's bolt, the swarm's dive), at lash_scale of the attack's own damage; at most lash_most
## lashes a confusion, the first lash_first_s into the wander, lash_gap_s between them. Only where the
## daemons fight: practice's dummies never attack.
@export var lash_range_m: float = 3.5
@export var lash_scale: float = 0.75
@export var lash_most: int = 2
@export var lash_first_s: float = 0.4
@export var lash_gap_s: float = 1.4

@export_group("Others")
## A /dev/null hole drags a confused daemon hole_pull_scale times as hard (it does not brace, C31).
@export var hole_pull_scale: float = 1.3
## An ICE node caught reloads for node_reload_s: its field dropped (a tell it was in called off), then it
## looks again. Walls are not touched; the hunter is confused as a daemon is and forgets what it learned.
@export var node_reload_s: float = 5.0
## A player caught in a match is confused on its own screen alone for player_s: its HUD glitching, its
## crosshair as drawn drifting by up to player_drift_px (the aim never moves), its AI link "hung up". It
## never inverts or takes away a control.
@export var player_s: float = 2.5
@export var player_drift_px: float = 22.0


## One line per value that would break the throw, the burst or the confusion. Empty means usable.
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
	if not is_finite(radius_m) or radius_m <= 0.0 or radius_m > RADIUS_LAST_M:
		out.append("radius_m must be above 0 and at most %s" % RADIUS_LAST_M)
	if not is_finite(root_radius_scale) or root_radius_scale < 1.0 or root_radius_scale > 2.0:
		out.append("root_radius_scale must be 1 to 2")
	if not is_finite(wave_speed) or wave_speed < WAVE_FIRST or wave_speed > WAVE_LAST:
		out.append("wave_speed must be %s to %s" % [WAVE_FIRST, WAVE_LAST])
	if not is_finite(burst_lift_m) or burst_lift_m < 0.0 or burst_lift_m > 2.0:
		out.append("burst_lift_m must be 0 to 2")
	for pair in [["reload_s", reload_s], ["wander_s", wander_s]]:
		if not is_finite(pair[1]) or pair[1] <= 0.0 or pair[1] > CONFUSE_LAST_S:
			out.append("%s must be above 0 and at most %s" % [pair[0], CONFUSE_LAST_S])
	if not is_finite(immune_s) or immune_s < 1.0 or immune_s > CONFUSE_LAST_S * 2.0:
		out.append("immune_s must be 1 to %s: a daemon is never held confused for ever" % (CONFUSE_LAST_S * 2.0))
	if not is_finite(wander_share) or wander_share <= 0.0 or wander_share > 1.0:
		out.append("wander_share must be above 0 and at most 1")
	for pair in [["leg_s", leg_s], ["look_s", look_s]]:
		if not is_finite(pair[1]) or pair[1] <= 0.0 or pair[1] > 5.0:
			out.append("%s must be above 0 and at most 5" % pair[0])
	if not is_finite(look_sweep) or look_sweep < 0.0 or look_sweep > PI:
		out.append("look_sweep must be 0 to pi")
	if not is_finite(stutter_hz) or stutter_hz < 0.5 or stutter_hz > 30.0:
		out.append("stutter_hz must be 0.5 to 30")
	if not is_finite(stutter_share) or stutter_share < 0.0 or stutter_share > 0.8:
		out.append("stutter_share must be 0 to 0.8: a confused daemon still gets somewhere")
	if not is_finite(lash_range_m) or lash_range_m < 0.0 or lash_range_m > RADIUS_LAST_M:
		out.append("lash_range_m must be 0 to %s" % RADIUS_LAST_M)
	if not is_finite(lash_scale) or lash_scale < 0.0 or lash_scale > SHARE_LAST:
		out.append("lash_scale must be 0 to %s" % SHARE_LAST)
	if lash_most < 0 or lash_most > 10:
		out.append("lash_most must be 0 to 10")
	if not is_finite(lash_first_s) or lash_first_s < 0.0 or lash_first_s > wander_s:
		out.append("lash_first_s must be 0 to wander_s")
	if not is_finite(lash_gap_s) or lash_gap_s < 0.1 or lash_gap_s > CONFUSE_LAST_S:
		out.append("lash_gap_s must be 0.1 to %s" % CONFUSE_LAST_S)
	if not is_finite(hole_pull_scale) or hole_pull_scale < 1.0 or hole_pull_scale > SHARE_LAST:
		out.append("hole_pull_scale must be 1 to %s" % SHARE_LAST)
	if not is_finite(node_reload_s) or node_reload_s <= 0.0 or node_reload_s > CONFUSE_LAST_S:
		out.append("node_reload_s must be above 0 and at most %s" % CONFUSE_LAST_S)
	if not is_finite(player_s) or player_s <= 0.0 or player_s > 6.0:
		out.append("player_s must be above 0 and at most 6: a player's confusion is short")
	if not is_finite(player_drift_px) or player_drift_px < 0.0 or player_drift_px > 80.0:
		out.append("player_drift_px must be 0 to 80")
	return out


## The shipped numbers (resources/sighup.tres's), for a screen that draws a confusion it did not decide (a
## joiner's node reloading on the host's word). Loaded once.
static func shipped() -> SighupTuning:
	if _shipped == null:
		var def = load(SHIPPED_PATH)
		_shipped = def.projectile as SighupTuning if def != null and def.get("projectile") is SighupTuning else SighupTuning.new()
	return _shipped


## How far a burst reaches, as root or not.
func reach_for(root: bool) -> float:
	return radius_m * (root_radius_scale if root else 1.0)


## Seconds from the burst until its wave reaches `distance` metres.
func wave_at(distance: float) -> float:
	return maxf(distance, 0.0) / wave_speed


## Seconds a daemon is confused for: the stall, then the wander.
func confused_s() -> float:
	return reload_s + wander_s


## The charges after `delta` seconds, as /dev/null's are counted (scripts/weapons/dev_null_tuning.gd): [mag,
## left], the host `slack` quicker.
func step_charges(mag: int, most: int, left: float, delta: float, slack: float = 0.0) -> Array:
	return DevNullTuning.charges_after(mag, most, left, delta, recharge_s, slack)
