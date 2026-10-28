class_name ArsenalTuning
extends Resource
## The weapons every player holds and how swapping between them feels (C16): the loadout,
## slot 1 first, and the swap, reload and draw numbers shared by every weapon. The default
## instance is resources/arsenal.tres: the terminal cannon in slot 1, SIGTERM in slot 2, the
## SIGKILL rail rifle, the ult, in slot 3 (C17), the fork bomb, thrown, in slot 4 (C19).
## Each weapon's own numbers stay in its WeaponDef (scripts/weapons/weapon_def.gd).
## Units are seconds, metres and degrees.

const WeaponDefScript = preload("res://scripts/weapons/weapon_def.gd")

const SLOTS_LAST := 9
const SWAP_FIRST_S := 0.05
const SWAP_LAST_S := 2.0
const DROP_LAST_M := 1.0
const TILT_LAST := 90.0
const FICTION_LAST_S := 10.0
## The bounds of the drawn weapon's motion (A1).
const SWAY_LAG_LAST_S := 0.2
const SWAY_CAP_LAST := 30.0
const RECOVERY_FIRST := 0.5
const RECOVERY_LAST := 60.0
const BOB_LAST_M := 0.1
const ROLL_LAST := 15.0
const FALL_LAG_LAST_M := 0.05
const FALL_CAP_LAST_M := 0.2
const KICK_LIFT_LAST := 2.0

@export_group("Loadout")
## The weapons in slot order, slot 1 first: keys 1 to 9 pick them. Each is a WeaponDef.
@export var loadout: Array[Resource] = []

@export_group("Swap")
## Seconds from picking a weapon until it can fire. No shot goes off in between.
@export var swap_s: float = 0.3
## How far the new weapon rises from below while it is drawn, in metres.
@export var swap_drop_m: float = 0.25
## How far the weapon tips while it reloads, in degrees.
@export var reload_tilt_degrees: float = 25.0
## How long the HUD shows a weapon's fiction line after it is drawn.
@export var fiction_s: float = 1.6

@export_group("Viewmodel motion")
## The drawn weapon's own motion in view (A1). Visual only: none of it moves the aim or the shot.
## How far it lags a turn: its tilt is the turn's rate times this, in seconds.
@export var sway_lag_s: float = 0.025
## The most it tilts behind a turn, in degrees.
@export var sway_cap_degrees: float = 5.0
## Easing rate of the sway and of the fall's trail settling, per second.
@export var sway_recovery: float = 9.0
## How far it sways with the stride at a walk, across and up, in metres; none with the head bob
## off.
@export var bob_m: Vector2 = Vector2(0.008, 0.006)
## How far it rolls with the stride, in degrees.
@export var bob_roll_degrees: float = 1.5
## How far it trails a jump or a fall, in metres per metre a second of it, and the most it trails.
@export var fall_lag_m: float = 0.0025
@export var fall_lag_cap_m: float = 0.02
## The share of a shot's kick back that also lifts it.
@export var kick_lift_share: float = 0.35
## How far a weapon being drawn is tipped down as it rises, in degrees.
@export var swap_tilt_degrees: float = 22.0
## The share of the sway, the stride and the fall's trail kept while aiming down the sights.
@export var aim_motion_share: float = 0.35


## Everything wrong with these values, or empty when they are safe to use. A refused weapon
## is named with its slot.
func problems() -> PackedStringArray:
	var out := PackedStringArray()
	if loadout.is_empty() or loadout.size() > SLOTS_LAST:
		out.append("loadout must hold 1 to %d weapons" % SLOTS_LAST)
	var ids := {}
	for i in loadout.size():
		var def = loadout[i]
		if not (def is WeaponDefScript):
			out.append("slot %d is not a WeaponDef" % (i + 1))
			continue
		var issues: PackedStringArray = def.problems()
		if not issues.is_empty():
			out.append("slot %d (%s) refused: %s" % [i + 1, def.id, issues[0]])
		elif ids.has(def.id):
			out.append("slot %d repeats the id %s" % [i + 1, def.id])
		ids[def.id] = true
	if not is_finite(swap_s) or swap_s < SWAP_FIRST_S or swap_s > SWAP_LAST_S:
		out.append("swap_s must be between %s and %s" % [SWAP_FIRST_S, SWAP_LAST_S])
	if not is_finite(swap_drop_m) or swap_drop_m < 0.0 or swap_drop_m > DROP_LAST_M:
		out.append("swap_drop_m must be between 0 and %s" % DROP_LAST_M)
	if not is_finite(reload_tilt_degrees) or reload_tilt_degrees < 0.0 or reload_tilt_degrees > TILT_LAST:
		out.append("reload_tilt_degrees must be between 0 and %s" % TILT_LAST)
	if not is_finite(fiction_s) or fiction_s < 0.0 or fiction_s > FICTION_LAST_S:
		out.append("fiction_s must be between 0 and %s" % FICTION_LAST_S)
	for bound in [["sway_lag_s", 0.0, SWAY_LAG_LAST_S], ["sway_cap_degrees", 0.0, SWAY_CAP_LAST], ["sway_recovery", RECOVERY_FIRST, RECOVERY_LAST], ["bob_roll_degrees", 0.0, ROLL_LAST], ["fall_lag_m", 0.0, FALL_LAG_LAST_M], ["fall_lag_cap_m", 0.0, FALL_CAP_LAST_M], ["kick_lift_share", 0.0, KICK_LIFT_LAST], ["swap_tilt_degrees", 0.0, TILT_LAST], ["aim_motion_share", 0.0, 1.0]]:
		var value: float = get(bound[0])
		if not is_finite(value) or value < bound[1] or value > bound[2]:
			out.append("%s must be between %s and %s" % bound)
	if not bob_m.is_finite() or bob_m.x < 0.0 or bob_m.y < 0.0 or bob_m.x > BOB_LAST_M or bob_m.y > BOB_LAST_M:
		out.append("bob_m must be between 0 and %s on each axis" % BOB_LAST_M)
	return out


## The weapons of `candidate` that pass their own checks, in slot order, at most one per
## id and at most nine; refused ones are left out with a warning. Never empty: with nothing
## usable it is the built-in terminal cannon alone.
static func usable_loadout(candidate: Resource) -> Array:
	var out := []
	var ids := {}
	var list: Array = candidate.loadout if candidate is ArsenalTuning else []
	for i in list.size():
		var def = list[i]
		if not (def is WeaponDefScript):
			push_warning("arsenal: slot %d is not a WeaponDef; left out" % (i + 1))
			continue
		var issues: PackedStringArray = def.problems()
		if not issues.is_empty():
			push_warning("arsenal: slot %d (%s) refused: %s" % [i + 1, def.id, "; ".join(issues)])
			continue
		if ids.has(def.id) or out.size() >= SLOTS_LAST:
			push_warning("arsenal: slot %d (%s) left out: a repeated id or past slot %d" % [i + 1, def.id, SLOTS_LAST])
			continue
		ids[def.id] = true
		out.append(def)
	if out.is_empty():
		out.append(WeaponDefScript.new())
	return out


## The swap, draw and reload numbers to use: `candidate`'s when they are sound, otherwise
## the built-in ones. The loadout is judged weapon by weapon in usable_loadout().
static func usable_timing(candidate: Resource) -> ArsenalTuning:
	var fallback := ArsenalTuning.new()
	if not (candidate is ArsenalTuning):
		return fallback
	var probe: ArsenalTuning = candidate.duplicate()
	var one: Array[Resource] = [WeaponDefScript.new()]
	probe.loadout = one
	if probe.problems().is_empty():
		return candidate
	push_warning("arsenal: swap and reload timing refused (%s); using the built-in defaults" % "; ".join(probe.problems()))
	return fallback
