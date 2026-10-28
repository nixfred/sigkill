class_name WeaponDef
extends "res://scripts/weapon_tuning.gd"
## One weapon of the arsenal (C16, PRD 5.2), one .tres per weapon: who it is, how it fires,
## its ammo, its falloff and its light skin, on top of every feel number WeaponTuning
## already holds (fire_cooldown is the fire interval, fire_range the range, damage the
## damage of one hit or one pellet, then recoil, beam, flash, sparks, hit marker, sounds).
## Each value lives in exactly one file: resources/terminal_cannon.tres is weapon #1,
## resources/sigterm.tres the polite shotgun. The built-in defaults are the terminal
## cannon's, so WeaponDef.new() is always a usable weapon.
##
## Weapons are cosmetic fiction only: a fiction line names the signal or command a weapon
## stands for, and nothing real is ever run, signalled or touched.
##
## The mod and skin slots are empty data for now: no unlocks, no progression (C33).
##
## The rail and the ult (C17, resources/sigkill_rail.tres): a weapon may charge before it
## fires (charge_s), pierce every target on its line up to the level's geometry (pierce),
## name its victim's fake in-game process id in the kill feed (feed_pid), and be an ult:
## no magazine, no reserve, no reload, but a meter (ult_meter points) that damage and kills
## with the other weapons fill, one full meter for one shot. Every default is off, so the
## terminal cannon and SIGTERM are exactly as they were.
##
## Thrown weapons (C19): fire_mode PROJECTILE throws instead of casting rays. The fork bomb
## (resources/fork_bomb_weapon.tres) is one: its magazine is its bombs (2, no reserve: a new
## life and a new round give them back), and every number of its chain is the
## ForkBombTuning it names in projectile (resources/fork_bomb.tres). damage is unused for a
## thrown weapon: the blasts' damage is the tuning's.
##
## fork() pellets (C24, resources/fork_shotgun.tres): fire_mode FORK_PELLETS fires a flat fan
## of pellets that fly as fast, short-lived projectiles (pellet_speed), not rays. Each one
## flies fork_distance_m and is replaced by two children angled fork_angle_degrees apart in the
## plane of the fan, at the same speed; a child forks again after another fork_distance_m while
## generations are left (fork_generations, root_fork_generations while C22's root is on). A
## pellet's damage is damage times child_damage_share for each fork behind it; it stops at the
## first wall or body it meets (a parent that hits before its fork never forks) and vanishes at
## fire_range. The fan and the forks come from the aim and a seed alone (fork_spread(),
## fork_pair()), so every screen draws the same pellets. The fork group is empty (0) for every
## other weapon.
##
## grep darts (C25, resources/grep_seeker.tres): fire_mode SEEKER marks before it fires. While
## it is drawn and the aim is held (or toggled), the target nearest the crosshair inside
## lock_cone_degrees, within lock_range_m and with nothing of the level in between, builds a
## lock over lock_s; a full lock marks it, up to max_marks at once (root_max_marks while C22's
## root is on, and the lock builds root_lock_speed times as fast). A mark stays while its target
## is in sight (inside sight_cone_degrees of the crosshair, nothing of the level in between) and
## within lock_range_m, or out of it for no longer than lock_grace_s. A shot fires one dart per
## mark, fanned over spread_degrees each side (seek_spread()), or one straight along the aim
## with no mark; each flies at dart_speed, turns toward its mark at most dart_turn_degrees a
## second, stops at the first wall or body and vanishes at fire_range. damage is one dart's.
## In a match the host believes a claimed mark within lock_range_m plus claim_tolerance_m and
## sight_cone_degrees plus claim_tolerance_degrees of the shot's aim, in sight. The Seek group
## is empty (0) for every other weapon.
##
## The rm -rf cannon (C26, resources/rm_rf_cannon.tres): fire_mode SLUG winds up first, charge_s
## the "are you sure" beat (root_charge_scale of it while C22's root is on), and moves the
## shooter at move_scale of its pace through the wind-up and move_slow_s after the shot. The
## shot is one slow, heavy slug flying straight at slug_speed that detonates on the first wall,
## floor or body it meets, or at fire_range. Its blast reaches blast_radius_m (root_blast_scale
## times that as root): damage at its centre, easing straight down to blast_edge_damage at the
## edge, nothing beyond, and nothing through the level. It hurts its own shooter too, at
## self_damage_share of the blast; a shooter it kills is "<kill_word>: <name> <self_kill_word>"
## in the feed. The HUD types charge_prompt out as the wind-up fills. The Blast group is empty
## (0) for every other weapon.

const Palette = preload("res://scripts/palette.gd")
const ForkBombTuning = preload("res://scripts/weapons/fork_bomb_tuning.gd")

enum FireMode { HITSCAN_SINGLE, HITSCAN_PELLETS, PROJECTILE, BEAM, FORK_PELLETS, SEEKER, SLUG }

## Magazine and reserve value for "no limit": the terminal cannon never runs dry.
const INFINITE := -1
## The fire modes built so far: projectile since C19 (the fork bomb), fork pellets since C24
## (fork()), seeker darts since C25 (grep), the slug since C26 (rm -rf). Beam comes later.
const BUILT_MODES := [FireMode.HITSCAN_SINGLE, FireMode.HITSCAN_PELLETS, FireMode.PROJECTILE, FireMode.FORK_PELLETS, FireMode.SEEKER, FireMode.SLUG]
const ID_LAST := 32
const NAME_LAST := 32
const SHORT_LAST := 12
const FICTION_LAST := 28
const WORD_LAST := 16
const PELLETS_LAST := 32
const SPREAD_LAST := 45.0
const MAGAZINE_LAST := 999
const RESERVE_LAST := 9999
const RELOAD_FIRST_S := 0.1
const RELOAD_LAST_S := 10.0
const SLOT_ENTRY_LAST := 32
const NEAR_PARALLEL := 0.98
const CHARGE_LAST_S := 2.0
const METER_FIRST := 0.5
const METER_LAST := 20.0
## A hit this close below a target's top counts as a headshot (C17), in metres: the top of
## a dummy's prism or a player's capsule.
const HEAD_ZONE_M := 0.35
## The most targets one piercing shot passes through.
const PIERCE_LAST := 16
## fork() pellets (C24): the bounds of their numbers. A shot never makes more than
## FORK_PELLETS_LAST pellets, whatever the generations.
const PELLET_SPEED_FIRST := 10.0
const PELLET_SPEED_LAST := 400.0
const FORK_ANGLE_LAST := 60.0
const FORK_GENERATIONS_LAST := 3
const FORK_PELLETS_LAST := 64
const PELLET_RADIUS_LAST_M := 0.2
const PELLET_TRAIL_LAST_M := 3.0
const FORK_FLASH_RADIUS_LAST_M := 0.5
const FORK_FLASH_LAST_S := 0.5
## grep darts (C25): the bounds of their numbers. A shot never fires more than MARKS_LAST darts.
const MARKS_LAST := 8
const LOCK_CONE_LAST := 30.0
const SIGHT_CONE_LAST := 90.0
const LOCK_RANGE_LAST_M := 200.0
const LOCK_FIRST_S := 0.05
const LOCK_LAST_S := 5.0
const GRACE_LAST_S := 5.0
const ROOT_LOCK_SPEED_LAST := 10.0
const CLAIM_TOLERANCE_LAST := 15.0
const CLAIM_TOLERANCE_LAST_M := 5.0
const DART_SPEED_FIRST := 5.0
const DART_SPEED_LAST := 400.0
const DART_TURN_LAST := 1440.0
const BRACKET_LAST_PX := 200.0
## The rm -rf slug (C26): the bounds of its numbers.
const SLUG_SPEED_FIRST := 1.0
const SLUG_SPEED_LAST := 60.0
const SLUG_RADIUS_LAST_M := 0.5
const SLUG_TRAIL_LAST_M := 5.0
const BLAST_RADIUS_LAST_M := 20.0
const ROOT_BLAST_SCALE_LAST := 4.0
const MOVE_SLOW_LAST_S := 5.0
const RING_LAST_S := 2.0
const WAIT_LAST_S := 5.0

@export_group("Identity")
## Stable id: lowercase letters, digits and underscores. Fire intents carry it (C16).
@export var id: String = "terminal_cannon"
## The weapon's full name.
@export var display_name: String = "Terminal cannon"
## The name in the HUD's slot strip.
@export var short_name: String = "cannon"
## The signal or command the weapon stands for, one short HUD line shown when it is drawn.
## Fiction only.
@export var fiction: String = "cannon: one line, one hit."
## The signal the kill feed names: "<kill_word> sent by <killer>".
@export var kill_word: String = "SIGKILL"
## A weapon that can kill its own shooter (C26): the feed's words for that, after the name
## ("rm -rf: Daemon-2 removed themself"). Empty for every other weapon.
@export var self_kill_word: String = ""
## A weapon that winds up (C26): the HUD line typed out as the wind-up fills. Empty for the
## rest (the rail's charge shows its own bar).
@export var charge_prompt: String = ""

@export_group("Mode")
## How a shot travels. Hitscan single, hitscan pellets and projectile (thrown, C19) are
## built; beam is reserved for a later weapon and refused until then.
@export var fire_mode: FireMode = FireMode.HITSCAN_SINGLE
## Pellets per shot: 1 for a single shot, 2 or more for pellets. The first pellet flies
## straight along the aim, the others scatter inside the cone.
@export var pellet_count: int = 1
## Half-angle of the pellet cone, in degrees. 0 for a single shot.
@export var spread_degrees: float = 0.0

@export_group("Ammo")
## Rounds in the magazine, or -1 for none: fires forever, never reloads.
@export var magazine_size: int = INFINITE
## Rounds carried beyond the magazine, or -1 for no limit. -1 when there is no magazine.
@export var reserve_ammo: int = INFINITE
## Seconds a reload takes. 0 when there is no magazine.
@export var reload_s: float = 0.0

@export_group("Falloff")
## Full damage up to this distance, in metres.
@export var falloff_start_m: float = 120.0
## From the start to here damage eases down to the floor, in metres.
@export var falloff_end_m: float = 120.0
## Share of the damage left at and beyond the falloff end, from 0 to 1.
@export_range(0.0, 1.0) var falloff_floor: float = 1.0

@export_group("Look")
## Tron light skin: a name from Palette.SKINS ("teal" for the cannon, "violet" for
## SIGTERM). The palette holds the colours themselves.
@export var light_skin: String = "teal"
## Pitch of the reload clack, in Hz.
@export var reload_click_hz: float = 900.0
## Loudness of the reload clack before the master volume, from 0 to 1.
@export_range(0.0, 1.0) var reload_gain: float = 0.5

@export_group("Rail")
## Seconds the shot charges after fire is pressed, with a wind-up glow, before it goes off;
## 0 fires at once.
@export var charge_s: float = 0.0
## True: the shot passes through every target on its line (dummies, players) and stops
## only at the level's geometry, up to fire_range. Single shots only.
@export var pierce: bool = false
## True: the kill feed names the victim's fake in-game process id after the kill word,
## "SIGKILL 4107 sent by Daemon-2" (PRD 5.3). Never a real process id.
@export var feed_pid: bool = false

@export_group("Ult")
## Meter points one shot needs; 0 for an ordinary weapon. An ult has no magazine, reserve or
## reload: one full meter is one shot, and the meter empties when it fires.
@export var ult_meter: float = 0.0
## Meter gained per target's worth of health dealt with the other weapons: a kill's damage
## is 1.0, a quarter of a player's health 0.25.
@export var ult_per_health: float = 0.0
## Meter gained for each kill with the other weapons.
@export var ult_per_kill: float = 0.0

@export_group("Projectile")
## A thrown weapon's chain, a ForkBombTuning (C19): resources/fork_bomb.tres for the fork bomb.
## Empty for every other weapon.
@export var projectile: Resource = null

@export_group("Fork")
## fork() pellets (C24): metres a second every pellet flies, parents and children alike.
@export var pellet_speed: float = 0.0
## Metres a pellet flies before it forks into two.
@export var fork_distance_m: float = 0.0
## Degrees between a fork's two children, in the plane of the fan.
@export var fork_angle_degrees: float = 0.0
## Each child's damage as a share of its parent's.
@export_range(0.0, 1.0) var child_damage_share: float = 1.0
## Forks each pellet line makes: as user, and while C22's root (sudo overcharge) is on.
@export var fork_generations: int = 0
@export var root_fork_generations: int = 0
## The look: a pellet's glowing head and thin trail, and the small flash of a fork.
@export var pellet_radius_m: float = 0.0
@export var pellet_trail_m: float = 0.0
@export var fork_flash_radius_m: float = 0.0
@export var fork_flash_s: float = 0.0

@export_group("Seek")
## grep darts (C25): the lock. Degrees off the crosshair a lock builds within, metres it
## reaches, and seconds a full lock takes.
@export var lock_cone_degrees: float = 0.0
@export var lock_range_m: float = 0.0
@export var lock_s: float = 0.0
## Seconds a mark lasts while its target is out of sight or out of range.
@export var lock_grace_s: float = 0.0
## Degrees off the crosshair a marked target counts as in sight (its line of sight takes the
## level into account too).
@export var sight_cone_degrees: float = 0.0
## Marks held at once: as user, and while C22's root is on; and how many times as fast a lock
## builds as root.
@export var max_marks: int = 0
@export var root_max_marks: int = 0
@export var root_lock_speed: float = 0.0
## In a match: how far past lock_range_m, and how many degrees past sight_cone_degrees, the host
## still believes a claimed mark (what one side's view and the other's may differ by).
@export var claim_tolerance_m: float = 0.0
@export var claim_tolerance_degrees: float = 0.0
## The darts: metres a second, the most degrees a second one turns toward its mark, and the
## look (a glowing head and a thin trail).
@export var dart_speed: float = 0.0
@export var dart_turn_degrees: float = 0.0
@export var dart_radius_m: float = 0.0
@export var dart_trail_m: float = 0.0
## The lock brackets on screen, half their side in pixels: as a lock starts, and once marked.
@export var bracket_open_px: float = 0.0
@export var bracket_marked_px: float = 0.0

@export_group("Blast")
## The rm -rf cannon (C26): the wind-up's share as root (0 for no change: the rail).
@export var root_charge_scale: float = 0.0
## The shooter's pace while winding up and for move_slow_s after the shot, a share of its own.
@export var move_scale: float = 0.0
@export var move_slow_s: float = 0.0
## The slug: metres a second, and the look (a heavy glowing head and a thick trail).
@export var slug_speed: float = 0.0
@export var slug_radius_m: float = 0.0
@export var slug_trail_m: float = 0.0
## The blast: its radius in metres (times root_blast_scale as root), the damage at its edge
## (damage is the centre's), the share the shooter takes of what it would deal there, and how
## long its ring takes to grow to the radius and fade.
@export var blast_radius_m: float = 0.0
@export var root_blast_scale: float = 0.0
@export var blast_edge_damage: float = 0.0
@export_range(0.0, 1.0) var self_damage_share: float = 0.0
@export var blast_ring_s: float = 0.0
## In a match: seconds a joiner's slug waits at a wall or at its range for the host's word of
## the blast before it gives up.
@export var blast_wait_s: float = 0.0

@export_group("Slots")
## Mod slots: empty data for now (unlocks and mods are C33).
@export var mod_slots: Array[String] = []
## Light skin slots: empty data for now (C33).
@export var skin_slots: Array[String] = []


## One line per value that would break this weapon, its feel included. Empty means usable.
func problems() -> PackedStringArray:
	var out := super()
	if not _is_id(id):
		out.append("id must be 1 to %d lowercase letters, digits or underscores" % ID_LAST)
	for pair in [["display_name", NAME_LAST], ["short_name", SHORT_LAST], ["fiction", FICTION_LAST], ["kill_word", WORD_LAST]]:
		var text: String = get(pair[0])
		if not _is_line(text, pair[1]):
			out.append("%s must be 1 to %d printable characters" % pair)
	if not BUILT_MODES.has(fire_mode):
		out.append("fire_mode %d is not built yet: only hitscan single, hitscan pellets, projectile, fork pellets, seeker and slug" % fire_mode)
	elif fire_mode == FireMode.PROJECTILE:
		if not (projectile is ForkBombTuning):
			out.append("a thrown weapon (fire_mode projectile) needs a ForkBombTuning in projectile")
		elif not projectile.problems().is_empty():
			out.append("a thrown weapon's projectile tuning is refused: %s" % projectile.problems()[0])
		if pellet_count != 1 or not has_magazine() or pierce or charge_s > 0.0 or ult_meter > 0.0:
			out.append("a thrown weapon throws one at a time from a magazine: 1 pellet, a magazine, no pierce, charge or ult")
	elif fire_mode == FireMode.FORK_PELLETS:
		out.append_array(_fork_problems())
	elif fire_mode == FireMode.SEEKER:
		out.append_array(_seek_problems())
	elif fire_mode == FireMode.SLUG:
		out.append_array(_slug_problems())
	elif projectile != null:
		out.append("only a thrown weapon (fire_mode projectile) names a projectile tuning")
	elif fire_mode == FireMode.HITSCAN_SINGLE and pellet_count != 1:
		out.append("a single shot has exactly 1 pellet")
	elif fire_mode == FireMode.HITSCAN_PELLETS and (pellet_count < 2 or pellet_count > PELLETS_LAST):
		out.append("pellets must number 2 to %d" % PELLETS_LAST)
	if not is_finite(spread_degrees) or spread_degrees < 0.0 or spread_degrees > SPREAD_LAST:
		out.append("spread_degrees must be between 0 and %s" % SPREAD_LAST)
	elif (fire_mode == FireMode.HITSCAN_PELLETS or fire_mode == FireMode.FORK_PELLETS or fire_mode == FireMode.SEEKER) and spread_degrees <= 0.0:
		out.append("pellets need a spread above 0")
	if fire_mode != FireMode.FORK_PELLETS and (pellet_speed != 0.0 or fork_distance_m != 0.0 or fork_generations != 0 or root_fork_generations != 0):
		out.append("only fork() pellets (fire_mode fork pellets) fill the fork group")
	if fire_mode != FireMode.SEEKER and (dart_speed != 0.0 or lock_s != 0.0 or max_marks != 0 or root_max_marks != 0 or lock_range_m != 0.0):
		out.append("only grep darts (fire_mode seeker) fill the seek group")
	if fire_mode != FireMode.SLUG and (slug_speed != 0.0 or blast_radius_m != 0.0 or self_damage_share != 0.0 or move_scale != 0.0 or root_charge_scale != 0.0 or self_kill_word != "" or charge_prompt != ""):
		out.append("only the rm -rf slug (fire_mode slug) fills the blast group, the self-kill words and the charge prompt")
	if fire_cooldown <= 0.0:
		out.append("fire_cooldown, the fire interval, must be above 0")
	if magazine_size == INFINITE:
		if reserve_ammo != INFINITE or reload_s != 0.0:
			out.append("a weapon with no magazine has reserve_ammo -1 and reload_s 0")
	else:
		if magazine_size < 1 or magazine_size > MAGAZINE_LAST:
			out.append("magazine_size must be -1 or 1 to %d" % MAGAZINE_LAST)
		if reserve_ammo != INFINITE and (reserve_ammo < 0 or reserve_ammo > RESERVE_LAST):
			out.append("reserve_ammo must be -1 or 0 to %d" % RESERVE_LAST)
		if not is_finite(reload_s) or reload_s < RELOAD_FIRST_S or reload_s > RELOAD_LAST_S:
			out.append("reload_s must be between %s and %s" % [RELOAD_FIRST_S, RELOAD_LAST_S])
	if not is_finite(falloff_start_m) or not is_finite(falloff_end_m) or falloff_start_m < 0.0 or falloff_end_m < falloff_start_m:
		out.append("falloff needs 0 <= falloff_start_m <= falloff_end_m")
	if not is_finite(falloff_floor) or falloff_floor < 0.0 or falloff_floor > 1.0:
		out.append("falloff_floor must be between 0 and 1")
	if not Palette.SKINS.has(light_skin):
		out.append("light_skin must be one of %s" % ", ".join(PackedStringArray(Palette.SKINS.keys())))
	if not is_finite(reload_click_hz) or reload_click_hz <= 0.0:
		out.append("reload_click_hz must be above 0 Hz")
	if not is_finite(reload_gain) or reload_gain < 0.0 or reload_gain > 1.0:
		out.append("reload_gain must be between 0 and 1")
	if not is_finite(charge_s) or charge_s < 0.0 or charge_s > CHARGE_LAST_S:
		out.append("charge_s must be between 0 and %s" % CHARGE_LAST_S)
	if pierce and fire_mode != FireMode.HITSCAN_SINGLE:
		out.append("only a single shot pierces")
	if not is_finite(ult_meter) or (ult_meter != 0.0 and (ult_meter < METER_FIRST or ult_meter > METER_LAST)):
		out.append("ult_meter must be 0 or between %s and %s" % [METER_FIRST, METER_LAST])
	if not is_finite(ult_per_health) or not is_finite(ult_per_kill) or ult_per_health < 0.0 or ult_per_kill < 0.0:
		out.append("ult_per_health and ult_per_kill must be 0 or more")
	if ult_meter > 0.0:
		if has_magazine():
			out.append("an ult has no magazine: magazine_size -1, reserve_ammo -1, reload_s 0")
		if ult_per_health <= 0.0 and ult_per_kill <= 0.0:
			out.append("an ult's meter must fill from something: ult_per_health or ult_per_kill above 0")
	for pair in [["mod_slots", mod_slots], ["skin_slots", skin_slots]]:
		for entry in pair[1]:
			if not _is_line(entry, SLOT_ENTRY_LAST):
				out.append("%s entries must be 1 to %d printable characters" % [pair[0], SLOT_ENTRY_LAST])
				break
	return out


## True when the weapon has a magazine to empty and reload.
func has_magazine() -> bool:
	return magazine_size != INFINITE


## True for the ult: a meter instead of ammo.
func is_ult() -> bool:
	return ult_meter > 0.0


## True for a thrown weapon (C19): the fork bomb.
func is_thrown() -> bool:
	return fire_mode == FireMode.PROJECTILE


## True for fork() pellets (C24): projectiles that fork mid-flight.
func is_fork() -> bool:
	return fire_mode == FireMode.FORK_PELLETS


## True for grep's seeker darts (C25): it marks targets, then its darts home on them.
func is_seeker() -> bool:
	return fire_mode == FireMode.SEEKER


## True for a weapon whose shot flies as a volley of projectiles the host runs and every
## screen draws from a seed: fork() (C24), grep (C25) and the rm -rf slug (C26).
func is_volley() -> bool:
	return is_fork() or is_seeker() or is_slug()


## True for the rm -rf cannon's slug (C26): one slow shot that blasts where it stops.
func is_slug() -> bool:
	return fire_mode == FireMode.SLUG


## Seconds the shot winds up (charges) for: charge_s, or root_charge_scale of it with `root`
## (C26's "--no-preserve-root"); the rail's is the same either way.
func charge_for(root: bool) -> float:
	return charge_s * (root_charge_scale if root and root_charge_scale > 0.0 else 1.0)


## The share of its pace the shooter keeps while this weapon winds up and just after: 1 for
## every weapon but the slug's.
func move_factor() -> float:
	return move_scale if move_scale > 0.0 else 1.0


## The blast's reach in metres: blast_radius_m, root_blast_scale times that with `root`.
func blast_radius_for(root: bool) -> float:
	return blast_radius_m * (root_blast_scale if root else 1.0)


## The blast's damage at `distance` metres from its centre, at user's strength: damage at the
## centre, easing straight down to blast_edge_damage at the radius (the larger root one with
## `root`), nothing beyond it.
func blast_damage_at(distance: float, root: bool) -> float:
	var radius := blast_radius_for(root)
	if not is_finite(distance) or distance < 0.0 or radius <= 0.0 or distance > radius:
		return 0.0
	return lerpf(damage, blast_edge_damage, distance / radius)


## Marks held at once: as user, or with `root` (C22's overcharge) the tuning's root number.
func marks_for(root: bool) -> int:
	return root_max_marks if root else max_marks


## How fast a lock builds: 1 as user, root_lock_speed with `root`.
func lock_speed(root: bool) -> float:
	return root_lock_speed if root else 1.0


## The first direction of each of a grep shot's `count` darts along `aim_in`, drawn from
## `shot_seed` alone: one dart flies straight along the aim; more are fanned in the plane of the
## aim and its level right-hand side, one in each equal slice of spread_degrees each side, at a
## place in its slice the seed picks.
func seek_spread(aim_in: Vector3, shot_seed: int, count: int) -> PackedVector3Array:
	var aim := aim_in.normalized()
	if count <= 1:
		return PackedVector3Array([aim])
	var axis := fork_axis(aim)
	var rng := RandomNumberGenerator.new()
	rng.seed = shot_seed
	var out := PackedVector3Array()
	var width := deg_to_rad(spread_degrees) * 2.0
	var slice := width / count
	for i in count:
		out.append(aim.rotated(axis, -width * 0.5 + slice * (i + rng.randf())).normalized())
	return out


## Forks each pellet line makes: as user, or with `root` (C22's overcharge) one generation more
## as the tuning says.
func forks_for(root: bool) -> int:
	return root_fork_generations if root else fork_generations


## Damage of one fork() pellet of generation `gen` (0 the parent): each fork behind it takes
## child_damage_share of the damage before it.
func fork_damage(gen: int) -> float:
	return damage * pow(child_damage_share, gen)


## Pellets alive after `forks` forks of a whole shot: pellet_count, doubled for each.
func pellets_after(forks: int) -> int:
	return pellet_count * (1 << forks)


## The fan of a fork() shot along `aim_in`, drawn from `shot_seed` alone: pellet_count
## directions in the plane of the aim and its level right-hand side, one in each equal slice of
## the spread (spread_degrees each side), at a place in its slice the seed picks.
func fork_spread(aim_in: Vector3, shot_seed: int) -> PackedVector3Array:
	var aim := aim_in.normalized()
	var axis := fork_axis(aim)
	var rng := RandomNumberGenerator.new()
	rng.seed = shot_seed
	var out := PackedVector3Array()
	var width := deg_to_rad(spread_degrees) * 2.0
	var slice := width / maxi(pellet_count, 1)
	for i in pellet_count:
		out.append(aim.rotated(axis, -width * 0.5 + slice * (i + rng.randf())).normalized())
	return out


## The two children of a fork() pellet flying along `dir` in a shot along `aim`: turned
## fork_angle_degrees apart about the fan's axis, so both stay in the plane of the fan.
func fork_pair(dir: Vector3, aim: Vector3) -> PackedVector3Array:
	var axis := fork_axis(aim.normalized())
	var half := deg_to_rad(fork_angle_degrees) * 0.5
	return PackedVector3Array([dir.rotated(axis, -half).normalized(), dir.rotated(axis, half).normalized()])


## The axis a fork() fan turns about: square to the aim and to its level right-hand side.
static func fork_axis(aim: Vector3) -> Vector3:
	var up := Vector3.UP if absf(aim.dot(Vector3.UP)) < NEAR_PARALLEL else Vector3.RIGHT
	var right := aim.cross(up).normalized()
	return right.cross(aim).normalized()


func _fork_problems() -> PackedStringArray:
	var out := PackedStringArray()
	if pellet_count < 2 or pellet_count > PELLETS_LAST:
		out.append("pellets must number 2 to %d" % PELLETS_LAST)
	if projectile != null or not has_magazine() or pierce or charge_s > 0.0 or ult_meter > 0.0:
		out.append("fork() pellets fire from a magazine: no projectile tuning, pierce, charge or ult")
	if not is_finite(falloff_floor) or falloff_floor != 1.0:
		out.append("fork() pellets' falloff is their forks: falloff_floor stays 1")
	if not is_finite(pellet_speed) or pellet_speed < PELLET_SPEED_FIRST or pellet_speed > PELLET_SPEED_LAST:
		out.append("pellet_speed must be between %s and %s" % [PELLET_SPEED_FIRST, PELLET_SPEED_LAST])
	if not is_finite(fork_angle_degrees) or fork_angle_degrees <= 0.0 or fork_angle_degrees > FORK_ANGLE_LAST:
		out.append("fork_angle_degrees must be above 0 and at most %s" % FORK_ANGLE_LAST)
	if not is_finite(child_damage_share) or child_damage_share <= 0.0 or child_damage_share > 1.0:
		out.append("child_damage_share must be above 0 and at most 1")
	if fork_generations < 1 or root_fork_generations < fork_generations or root_fork_generations > FORK_GENERATIONS_LAST:
		out.append("fork_generations must be at least 1 and root_fork_generations between it and %d" % FORK_GENERATIONS_LAST)
	elif pellet_count >= 2 and pellets_after(root_fork_generations) > FORK_PELLETS_LAST:
		out.append("a shot makes at most %d pellets: pellet_count doubled root_fork_generations times" % FORK_PELLETS_LAST)
	if not is_finite(fork_distance_m) or fork_distance_m <= 0.0 or not is_finite(fire_range) or fork_distance_m * maxi(root_fork_generations, 1) >= fire_range:
		out.append("fork_distance_m must be above 0, every fork within fire_range")
	for pair in [["pellet_radius_m", pellet_radius_m, PELLET_RADIUS_LAST_M], ["pellet_trail_m", pellet_trail_m, PELLET_TRAIL_LAST_M], ["fork_flash_radius_m", fork_flash_radius_m, FORK_FLASH_RADIUS_LAST_M], ["fork_flash_s", fork_flash_s, FORK_FLASH_LAST_S]]:
		var v: float = pair[1]
		if not is_finite(v) or v <= 0.0 or v > pair[2]:
			out.append("%s must be above 0 and at most %s" % [pair[0], pair[2]])
	return out


func _seek_problems() -> PackedStringArray:
	var out := PackedStringArray()
	if pellet_count != 1:
		out.append("grep fires darts, one a mark: pellet_count stays 1")
	if projectile != null or not has_magazine() or pierce or charge_s > 0.0 or ult_meter > 0.0:
		out.append("grep fires from a magazine: no projectile tuning, pierce, charge or ult")
	if not is_finite(falloff_floor) or falloff_floor != 1.0:
		out.append("grep's darts keep their damage: falloff_floor stays 1")
	if max_marks < 1 or root_max_marks < max_marks or root_max_marks > MARKS_LAST:
		out.append("max_marks must be at least 1 and root_max_marks between it and %d" % MARKS_LAST)
	var bounds := [
		["lock_cone_degrees", lock_cone_degrees, 0.0, LOCK_CONE_LAST], ["sight_cone_degrees", sight_cone_degrees, lock_cone_degrees, SIGHT_CONE_LAST],
		["lock_range_m", lock_range_m, 0.0, LOCK_RANGE_LAST_M], ["lock_grace_s", lock_grace_s, 0.0, GRACE_LAST_S],
		["claim_tolerance_m", claim_tolerance_m, 0.0, CLAIM_TOLERANCE_LAST_M], ["claim_tolerance_degrees", claim_tolerance_degrees, 0.0, CLAIM_TOLERANCE_LAST],
		["dart_turn_degrees", dart_turn_degrees, 0.0, DART_TURN_LAST], ["dart_radius_m", dart_radius_m, 0.0, PELLET_RADIUS_LAST_M],
		["dart_trail_m", dart_trail_m, 0.0, PELLET_TRAIL_LAST_M], ["bracket_marked_px", bracket_marked_px, 0.0, BRACKET_LAST_PX],
		["bracket_open_px", bracket_open_px, bracket_marked_px, BRACKET_LAST_PX],
	]
	for b in bounds:
		var v: float = b[1]
		if not is_finite(v) or v <= b[2] or v > b[3]:
			out.append("%s must be above %s and at most %s" % [b[0], b[2], b[3]])
	if not is_finite(lock_s) or lock_s < LOCK_FIRST_S or lock_s > LOCK_LAST_S:
		out.append("lock_s must be between %s and %s" % [LOCK_FIRST_S, LOCK_LAST_S])
	if not is_finite(root_lock_speed) or root_lock_speed < 1.0 or root_lock_speed > ROOT_LOCK_SPEED_LAST:
		out.append("root_lock_speed must be between 1 and %s" % ROOT_LOCK_SPEED_LAST)
	if not is_finite(dart_speed) or dart_speed < DART_SPEED_FIRST or dart_speed > DART_SPEED_LAST:
		out.append("dart_speed must be between %s and %s" % [DART_SPEED_FIRST, DART_SPEED_LAST])
	if is_finite(lock_range_m) and is_finite(fire_range) and fire_range < lock_range_m:
		out.append("fire_range, the darts' reach, must be at least lock_range_m")
	return out


func _slug_problems() -> PackedStringArray:
	var out := PackedStringArray()
	if pellet_count != 1:
		out.append("the rm -rf cannon fires one slug: pellet_count stays 1")
	if projectile != null or not has_magazine() or pierce or ult_meter > 0.0:
		out.append("the rm -rf cannon fires from a magazine: no projectile tuning, pierce or ult")
	if not is_finite(falloff_floor) or falloff_floor != 1.0:
		out.append("the slug's falloff is its blast's: falloff_floor stays 1")
	if not is_finite(charge_s) or charge_s <= 0.0:
		out.append("the rm -rf cannon winds up: charge_s above 0")
	var bounds := [
		["root_charge_scale", root_charge_scale, 0.0, 1.0], ["move_scale", move_scale, 0.0, 1.0],
		["slug_speed", slug_speed, SLUG_SPEED_FIRST, SLUG_SPEED_LAST], ["slug_radius_m", slug_radius_m, 0.0, SLUG_RADIUS_LAST_M],
		["slug_trail_m", slug_trail_m, 0.0, SLUG_TRAIL_LAST_M], ["blast_radius_m", blast_radius_m, 0.0, BLAST_RADIUS_LAST_M],
		["blast_ring_s", blast_ring_s, 0.0, RING_LAST_S], ["blast_wait_s", blast_wait_s, 0.0, WAIT_LAST_S],
	]
	for b in bounds:
		var v: float = b[1]
		if not is_finite(v) or v <= b[2] or v > b[3]:
			out.append("%s must be above %s and at most %s" % [b[0], b[2], b[3]])
	if not is_finite(root_blast_scale) or root_blast_scale < 1.0 or root_blast_scale > ROOT_BLAST_SCALE_LAST:
		out.append("root_blast_scale must be between 1 and %s" % ROOT_BLAST_SCALE_LAST)
	if not is_finite(move_slow_s) or move_slow_s < 0.0 or move_slow_s > MOVE_SLOW_LAST_S:
		out.append("move_slow_s must be between 0 and %s" % MOVE_SLOW_LAST_S)
	if not is_finite(blast_edge_damage) or blast_edge_damage < 0.0 or blast_edge_damage > damage:
		out.append("blast_edge_damage must be between 0 and the centre's damage")
	if not is_finite(self_damage_share) or self_damage_share <= 0.0 or self_damage_share > 1.0:
		out.append("self_damage_share must be above 0 and at most 1: the blast hurts its shooter")
	if not _is_line(self_kill_word, WORD_LAST):
		out.append("self_kill_word must be 1 to %d printable characters" % WORD_LAST)
	if not _is_line(charge_prompt, FICTION_LAST):
		out.append("charge_prompt must be 1 to %d printable characters" % FICTION_LAST)
	return out


## The meter this ult gains from a hit with another weapon that took `share` of a target's
## health (1.0 for all of it), plus the kill bonus when it was a kill.
func meter_gain(share: float, killed: bool) -> float:
	if not is_ult() or not is_finite(share) or share < 0.0:
		return 0.0
	return ult_per_health * minf(share, 1.0) + (ult_per_kill if killed else 0.0)


## Rounds a reload moves from `reserve` into a magazine holding `mag`.
func reload_take(mag: int, reserve: int) -> int:
	if not has_magazine():
		return 0
	var room := maxi(magazine_size - mag, 0)
	return room if reserve == INFINITE else mini(room, maxi(reserve, 0))


## Damage of one hit or one pellet that travelled `distance` metres.
func damage_at(distance: float) -> float:
	if distance <= falloff_start_m:
		return damage
	if distance >= falloff_end_m:
		return damage * falloff_floor
	return damage * lerpf(1.0, falloff_floor, (distance - falloff_start_m) / (falloff_end_m - falloff_start_m))


## Every pellet's direction for a shot along `aim` (made unit length first, so a slightly
## long aim cannot narrow the cone): the first straight along it, the rest spread evenly over
## the cone, drawn from `rng`. A single shot draws nothing.
func pellet_directions(aim_in: Vector3, rng: RandomNumberGenerator) -> PackedVector3Array:
	var aim := aim_in.normalized()
	var out := PackedVector3Array([aim])
	if pellet_count < 2:
		return out
	var up := Vector3.UP if absf(aim.dot(Vector3.UP)) < NEAR_PARALLEL else Vector3.RIGHT
	var right := aim.cross(up).normalized()
	var across := right.cross(aim).normalized()
	var cone := deg_to_rad(spread_degrees)
	for i in pellet_count - 1:
		var off := cone * sqrt(rng.randf())
		var turn := rng.randf() * TAU
		out.append((aim * cos(off) + (right * cos(turn) + across * sin(turn)) * sin(off)).normalized())
	return out


## Every pellet straight along `aim_in`: a shot with no spread at all, as SIGSTOP's steady
## hands fire (C18). One direction per pellet, so a pellet weapon still hits as many times.
func steady_directions(aim_in: Vector3) -> PackedVector3Array:
	var out := PackedVector3Array()
	for i in maxi(pellet_count, 1):
		out.append(aim_in.normalized())
	return out


## The body and beam colours of this weapon's light skin, from the palette.
func skin_body() -> Color:
	return Palette.skin_body(light_skin)


func skin_beam() -> Color:
	return Palette.skin_beam(light_skin)


static func _is_id(text: String) -> bool:
	if text.is_empty() or text.length() > ID_LAST:
		return false
	for ch in text:
		if not ((ch >= "a" and ch <= "z") or (ch >= "0" and ch <= "9") or ch == "_"):
			return false
	return true


static func _is_line(text: String, last: int) -> bool:
	if text.strip_edges().is_empty() or text.length() > last:
		return false
	for ch in text:
		if ch.unicode_at(0) < 32 or ch.unicode_at(0) == 127:
			return false
	return true
