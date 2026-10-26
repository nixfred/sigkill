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

const Palette = preload("res://scripts/palette.gd")

enum FireMode { HITSCAN_SINGLE, HITSCAN_PELLETS, PROJECTILE, BEAM }

## Magazine and reserve value for "no limit": the terminal cannon never runs dry.
const INFINITE := -1
## The fire modes built so far. Projectile and beam weapons come with later chunks.
const BUILT_MODES := [FireMode.HITSCAN_SINGLE, FireMode.HITSCAN_PELLETS]
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

@export_group("Mode")
## How a shot travels. Hitscan single and hitscan pellets are built; projectile and beam
## are reserved for later weapons and refused until then.
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
		out.append("fire_mode %d is not built yet: only hitscan single and hitscan pellets" % fire_mode)
	elif fire_mode == FireMode.HITSCAN_SINGLE and pellet_count != 1:
		out.append("a single shot has exactly 1 pellet")
	elif fire_mode == FireMode.HITSCAN_PELLETS and (pellet_count < 2 or pellet_count > PELLETS_LAST):
		out.append("pellets must number 2 to %d" % PELLETS_LAST)
	if not is_finite(spread_degrees) or spread_degrees < 0.0 or spread_degrees > SPREAD_LAST:
		out.append("spread_degrees must be between 0 and %s" % SPREAD_LAST)
	elif fire_mode == FireMode.HITSCAN_PELLETS and spread_degrees <= 0.0:
		out.append("pellets need a spread above 0")
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
	for pair in [["mod_slots", mod_slots], ["skin_slots", skin_slots]]:
		for entry in pair[1]:
			if not _is_line(entry, SLOT_ENTRY_LAST):
				out.append("%s entries must be 1 to %d printable characters" % [pair[0], SLOT_ENTRY_LAST])
				break
	return out


## True when the weapon has a magazine to empty and reload.
func has_magazine() -> bool:
	return magazine_size != INFINITE


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


## Every pellet's direction for a shot along unit vector `aim`: the first straight along
## it, the rest spread evenly over the cone, drawn from `rng`. A single shot draws nothing.
func pellet_directions(aim: Vector3, rng: RandomNumberGenerator) -> PackedVector3Array:
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
