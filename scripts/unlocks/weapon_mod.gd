class_name WeaponMod
extends Resource
## A weapon's one mod (C33, PRD 5.2): a small, readable tradeoff, never strictly better. It sets a few of the
## weapon's own numbers: what it gains and what it pays for it, each a number of the WeaponDef by name, or of
## the tuning inside it as "<slot>:<name>" (projectile, freeze or pipe: the fork bomb's tree, chmod 000's tank,
## the pipe's chain). Applied to a copy (apply_to()), never to the shipped weapon; the copy must pass the
## weapon's own checks. Every number lives here, in data, beside the weapon's .tres (resources/<id>_kit.tres).
## In a match the host judges a shot with the shooter's mod applied, and only while its "mods" rule is on.

const WeaponDefScript = preload("res://scripts/weapons/weapon_def.gd")

const ID_LAST := 16
const NAME_LAST := 18
const FICTION_LAST := 46
const NEED_LAST := 100000
## Which way is better for each number a mod may set: 1 more is better, -1 less is better. A gain must move
## its number the better way and a cost the worse way, so a mod is a sidegrade by construction.
const BETTER := {
	"fire_cooldown": -1, "damage": 1, "magazine_size": 1, "reserve_ammo": 1, "reload_s": -1,
	"spread_degrees": -1, "pellet_count": 1, "charge_s": -1, "ult_meter": -1, "fork_generations": 1,
	"max_marks": 1, "lock_s": -1, "self_damage_share": -1, "run_interval_s": -1, "runs": 1,
	"ping_radius_m": 1, "projectile:generations": 1, "projectile:radius_m": 1, "projectile:hold_s": 1,
	"projectile:wander_s": 1, "freeze:coolant_s": 1, "freeze:freeze_s": 1, "pipe:max_links": 1,
	"pipe:root_max_links": 1, "pipe:link_keep": 1,
}
## What the loadout screen calls each number, and its unit.
const LABELS := {
	"fire_cooldown": ["fire interval", "s"], "damage": ["damage", ""], "magazine_size": ["magazine", ""],
	"reserve_ammo": ["reserve", ""], "reload_s": ["reload", "s"], "spread_degrees": ["spread", " deg"],
	"pellet_count": ["pellets", ""], "charge_s": ["charge", "s"], "ult_meter": ["meter to fill", ""],
	"fork_generations": ["forks", ""], "max_marks": ["marks", ""], "lock_s": ["lock", "s"],
	"self_damage_share": ["blowback", "x"], "run_interval_s": ["run every", "s"], "runs": ["runs", ""],
	"ping_radius_m": ["ring reach", " m"], "projectile:generations": ["generations", ""],
	"projectile:radius_m": ["reach", " m"], "projectile:hold_s": ["hold", "s"], "projectile:wander_s": ["wander", "s"],
	"freeze:coolant_s": ["tank", "s"], "freeze:freeze_s": ["freeze", "s"], "pipe:max_links": ["links", ""],
	"pipe:root_max_links": ["links as root", ""], "pipe:link_keep": ["kept per link", "x"],
}

## Its id in the save, its name and fiction on the loadout screen.
@export var id: String = ""
@export var display_name: String = ""
@export var fiction: String = ""
## Number name -> its value with the mod on: what gets better, and what it costs.
@export var gains: Dictionary = {}
@export var costs: Dictionary = {}
## The feat that earns it (a Progress.FEATS key) and how many of it.
@export var feat: String = ""
@export var need: int = 1


## A copy of `def` with this mod's numbers set; the weapon's tunings it reaches into are copied too, so the
## shipped weapon is never touched.
func apply_to(def: WeaponDefScript) -> WeaponDefScript:
	var copy: WeaponDefScript = def.duplicate()
	var copied := {}
	for change in [gains, costs]:
		for key in change:
			var parts := String(key).split(":")
			if parts.size() == 2:
				if not copied.has(parts[0]):
					var inner: Resource = copy.get(parts[0])
					if inner == null:
						continue
					copy.set(parts[0], inner.duplicate())
					copied[parts[0]] = true
				(copy.get(parts[0]) as Resource).set(parts[1], change[key])
			else:
				copy.set(key, change[key])
	return copy


## The number `key` of `def` as shipped (a tuning's through its slot), or null when it has no such number.
static func number_of(def: Resource, key: String) -> Variant:
	var parts := key.split(":")
	if parts.size() == 2:
		var inner: Resource = def.get(parts[0])
		return inner.get(parts[1]) if inner != null else null
	return def.get(key)


## One line per thing that would break this mod on `def`. Empty means usable: at least one gain and one cost,
## every number one it may set, each gain better and each cost worse than `def`'s own, and the modded weapon
## passing the weapon's own checks.
func problems(def: WeaponDefScript) -> PackedStringArray:
	var out := PackedStringArray()
	if not _id_ok(id) or not WeaponSkin._line(display_name, NAME_LAST) or not WeaponSkin._line(fiction, FICTION_LAST):
		out.append("a mod needs an id (1 to %d lowercase letters, digits or _), a name and a fiction line" % ID_LAST)
	if feat == "" or need < 1 or need > NEED_LAST:
		out.append("a mod is earned by a feat and a count (1 to %d)" % NEED_LAST)
	if gains.is_empty() or costs.is_empty():
		out.append("a mod is a sidegrade: at least one gain and one cost")
	for pair in [[gains, 1], [costs, -1]]:
		for key in pair[0]:
			if not BETTER.has(key):
				out.append("a mod may not set %s" % key)
				continue
			var was = number_of(def, key)
			var now = pair[0][key]
			if not (was is int or was is float) or not (now is int or now is float) or typeof(was) != typeof(now):
				out.append("%s must be a number of the weapon's own type" % key)
				continue
			if signf(float(now) - float(was)) != float(BETTER[key] * pair[1]):
				out.append("%s %s must be %s than the weapon's own %s" % ["gain" if pair[1] > 0 else "cost", key, "better" if pair[1] > 0 else "worse", str(was)])
	if out.is_empty():
		var issues: PackedStringArray = apply_to(def).problems()
		if not issues.is_empty():
			out.append("the modded weapon is refused: %s" % issues[0])
	return out


## Its lines on the loadout screen: "+ fire interval 0.16 > 0.13s", then the costs with a "-".
func lines(def: WeaponDefScript) -> PackedStringArray:
	var out := PackedStringArray()
	for pair in [[gains, "+"], [costs, "-"]]:
		for key in pair[0]:
			var label: Array = LABELS.get(key, [key, ""])
			out.append("%s %s %s > %s%s" % [pair[1], label[0], _shown(number_of(def, key)), _shown(pair[0][key]), label[1]])
	return out


static func _shown(v: Variant) -> String:
	if v is float:
		return ("%.2f" % v).rstrip("0").rstrip(".")
	return str(v)


static func _id_ok(text: String) -> bool:
	if text.is_empty() or text.length() > ID_LAST:
		return false
	for ch in text:
		if not ((ch >= "a" and ch <= "z") or (ch >= "0" and ch <= "9") or ch == "_"):
			return false
	return true
