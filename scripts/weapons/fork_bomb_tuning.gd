class_name ForkBombTuning
extends Resource
## Every number of the fork bomb's chain (C19, PRD 5.2: "grenade that splits 1, 2, 4, 8"):
## the throw, the fuses, the fork's scatter, the blast's radius and damage with its falloff,
## the caps and the look of each blast. The default instance is resources/fork_bomb.tres; the
## weapon itself, its ammo (2 bombs) and its throw interval are the WeaponDef
## resources/fork_bomb_weapon.tres, which names this. scripts/weapons/fork_bomb.gd runs a
## chain by these numbers. Units are metres, seconds, metres a second and health points.
## Cosmetic fiction: nothing forks, runs or touches anything real.

@export_group("Throw")
## Speed along the aim when thrown, and the extra upward speed that gives the throw its arc.
@export var throw_speed: float = 13.0
@export var throw_lift: float = 3.0
## Downward pull on every bomblet, metres a second squared.
@export var gravity: float = 14.0
## Share of a bomblet's speed kept when it bounces off the level.
@export var bounce: float = 0.35

@export_group("Fork")
## Generations, the thrown bomb's included: 4 is 1, 2, 4, 8, fifteen blasts in all.
@export var generations: int = 4
## The thrown bomb's fuse; it also goes off at once on hitting a player or a daemon.
@export var fuse_s: float = 1.2
## Each child's fuse, shorter.
@export var child_fuse_s: float = 0.5
## How fast the two children of a blast fly outward from it, and up.
@export var scatter_speed: float = 3.5
@export var scatter_lift: float = 2.5
## How far each child's direction strays at random from straight out, in degrees.
@export var scatter_spread_degrees: float = 25.0

@export_group("Blast")
## How far one blast reaches, in metres.
@export var radius_m: float = 4.0
## Damage at the blast's centre; it eases down to falloff_floor of that at the radius.
@export var damage: float = 22.0
@export_range(0.0, 1.0) var falloff_floor: float = 0.3

@export_group("Caps")
## Bomblets one player may have live at once, every chain of theirs together: a child that
## would go past it is not made, and a throw is refused at it. One chain peaks at 8.
@export var live_cap: int = 16

@export_group("Look")
## A blast's ring: how long it shows, its size for the thrown bomb's blast, how much smaller
## and how much brighter each generation's is, and its glow.
@export var ring_s: float = 0.35
@export var ring_radius_m: float = 1.2
@export var ring_shrink: float = 0.85
@export var ring_brighten: float = 0.4
@export var ring_energy: float = 4.0
## A bomblet's size.
@export var bomb_radius_m: float = 0.12
## On a screen that only draws the host's chain: how long a bomblet waits past its fuse for
## the host's word of its blast before it is let go.
@export var wait_s: float = 1.5

## Fifteen blasts at most per throw, whatever the generations say: 1 + 2 + 4 + 8.
const BLASTS_LAST := 15
const GENERATIONS_LAST := 4
const SPEED_LAST := 60.0
const GRAVITY_LAST := 60.0
const FUSE_FIRST_S := 0.05
const FUSE_LAST_S := 10.0
const SPREAD_LAST := 90.0
const RADIUS_LAST_M := 20.0
const DAMAGE_LAST := 1000.0
const CAP_LAST := 64
const RING_LAST_S := 5.0


## Everything wrong with these values, or empty when they are safe to use.
func problems() -> PackedStringArray:
	var out := PackedStringArray()
	for pair in [["throw_speed", throw_speed], ["throw_lift", throw_lift], ["scatter_speed", scatter_speed], ["scatter_lift", scatter_lift]]:
		if not is_finite(pair[1]) or pair[1] < 0.0 or pair[1] > SPEED_LAST:
			out.append("%s must be between 0 and %s" % [pair[0], SPEED_LAST])
	if not is_finite(gravity) or gravity < 0.0 or gravity > GRAVITY_LAST:
		out.append("gravity must be between 0 and %s" % GRAVITY_LAST)
	if not is_finite(bounce) or bounce < 0.0 or bounce > 1.0:
		out.append("bounce must be between 0 and 1")
	if generations < 1 or generations > GENERATIONS_LAST:
		out.append("generations must be between 1 and %d (1, 2, 4, 8: fifteen blasts at most)" % GENERATIONS_LAST)
	for pair in [["fuse_s", fuse_s], ["child_fuse_s", child_fuse_s]]:
		if not is_finite(pair[1]) or pair[1] < FUSE_FIRST_S or pair[1] > FUSE_LAST_S:
			out.append("%s must be between %s and %s" % [pair[0], FUSE_FIRST_S, FUSE_LAST_S])
	if not is_finite(scatter_spread_degrees) or scatter_spread_degrees < 0.0 or scatter_spread_degrees > SPREAD_LAST:
		out.append("scatter_spread_degrees must be between 0 and %s" % SPREAD_LAST)
	if not is_finite(radius_m) or radius_m <= 0.0 or radius_m > RADIUS_LAST_M:
		out.append("radius_m must be above 0 and at most %s" % RADIUS_LAST_M)
	if not is_finite(damage) or damage <= 0.0 or damage > DAMAGE_LAST:
		out.append("damage must be above 0 and at most %s" % DAMAGE_LAST)
	if not is_finite(falloff_floor) or falloff_floor < 0.0 or falloff_floor > 1.0:
		out.append("falloff_floor must be between 0 and 1")
	if live_cap < 1 or live_cap > CAP_LAST:
		out.append("live_cap must be between 1 and %d" % CAP_LAST)
	if not is_finite(ring_s) or ring_s <= 0.0 or ring_s > RING_LAST_S:
		out.append("ring_s must be above 0 and at most %s" % RING_LAST_S)
	for pair in [["ring_radius_m", ring_radius_m], ["ring_energy", ring_energy], ["bomb_radius_m", bomb_radius_m]]:
		if not is_finite(pair[1]) or pair[1] <= 0.0 or pair[1] > RADIUS_LAST_M:
			out.append("%s must be above 0 and at most %s" % [pair[0], RADIUS_LAST_M])
	if not is_finite(ring_shrink) or ring_shrink <= 0.0 or ring_shrink > 1.0:
		out.append("ring_shrink must be above 0 and at most 1")
	if not is_finite(ring_brighten) or ring_brighten < 0.0 or ring_brighten > 2.0:
		out.append("ring_brighten must be between 0 and 2")
	if not is_finite(wait_s) or wait_s < 0.0 or wait_s > FUSE_LAST_S:
		out.append("wait_s must be between 0 and %s" % FUSE_LAST_S)
	return out


## Damage one blast does to a target `distance` metres from it: full at the centre, easing
## to falloff_floor of it at the radius, nothing beyond.
func damage_at(distance: float) -> float:
	if not is_finite(distance) or distance < 0.0 or distance > radius_m:
		return 0.0
	return damage * lerpf(1.0, falloff_floor, distance / radius_m)


## Blasts one throw makes in all: 1 + 2 + ... over the generations, fifteen at most.
func blasts() -> int:
	return mini((1 << generations) - 1, BLASTS_LAST)
