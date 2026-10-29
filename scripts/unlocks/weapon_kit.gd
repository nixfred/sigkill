class_name WeaponKit
extends Resource
## A weapon's skins and its mod (C33, PRD 5.2: "every one gets its own Tron light skin, mods and unlocks earned
## by playing"), one file beside each weapon, resources/<weapon id>_kit.tres: its skins in order, the weapon's
## own (stock) first, then the ones a player earns, each with its feat and count; and its one mod. The
## WeaponDef's skin and mod slots (C16, empty until now) name the same ids in the same order, so a weapon
## says what it offers and its kit says what each one is.

const WeaponDefScript = preload("res://scripts/weapons/weapon_def.gd")
const ArsenalScript = preload("res://scripts/weapons/arsenal_tuning.gd")
const ARSENAL_PATH := "res://resources/arsenal.tres"
const PATH := "res://resources/%s_kit.tres"
## A weapon offers its own skin and up to this many more (the save keeps a skin's index in a nibble).
const SKINS_LAST := 4

## The weapon's id.
@export var weapon: String = ""
## WeaponSkins, the weapon's own first.
@export var skins: Array[Resource] = []
## Its one WeaponMod, or null for none.
@export var mod: Resource = null

static var _shipped: Array = []
static var _by_id := {}


## The kit of the weapon with `id`, loaded once, or null when it has none.
static func of(id: String) -> WeaponKit:
	if _by_id.has(id):
		return _by_id[id]
	var path := PATH % id
	var kit: WeaponKit = load(path) as WeaponKit if ResourceLoader.exists(path) else null
	_by_id[id] = kit
	return kit


## The shipped arsenal's weapons (resources/arsenal.tres), in slot order: what every player's loadout is.
static func shipped_defs() -> Array:
	if _shipped.is_empty():
		_shipped = ArsenalScript.usable_loadout(load(ARSENAL_PATH))
	return _shipped


## One line per thing that would break this kit for `def`. Empty means usable.
func problems(def: WeaponDefScript) -> PackedStringArray:
	var out := PackedStringArray()
	if weapon != def.id:
		out.append("the kit names %s, not %s" % [weapon, def.id])
	if skins.is_empty() or skins.size() > SKINS_LAST:
		out.append("a kit has the weapon's own skin and up to %d more" % (SKINS_LAST - 1))
		return out
	var names := PackedStringArray()
	for i in skins.size():
		var skin := skins[i] as WeaponSkin
		if skin == null:
			out.append("skin %d is not a WeaponSkin" % (i + 1))
			continue
		for issue in skin.problems():
			out.append("skin %s: %s" % [skin.skin, issue])
		if names.has(skin.skin):
			out.append("skin %s is offered twice" % skin.skin)
		names.append(skin.skin)
		if (i == 0) != (skin.feat == ""):
			out.append("the first skin is the weapon's own, held from the start; every other is earned")
	if skins[0] != null and skins[0].skin != def.light_skin:
		out.append("the first skin must be the weapon's own, %s" % def.light_skin)
	if PackedStringArray(def.skin_slots) != names:
		out.append("the weapon's skin slots must name its kit's skins in order")
	var mod_ids := PackedStringArray()
	if mod != null:
		if not (mod is WeaponMod):
			out.append("the mod is not a WeaponMod")
		else:
			for issue in mod.problems(def):
				out.append("mod %s: %s" % [mod.id, issue])
			mod_ids.append(mod.id)
	if PackedStringArray(def.mod_slots) != mod_ids:
		out.append("the weapon's mod slot must name its kit's mod")
	return out


## The index of skin `name` in this kit, or -1.
func skin_index(name: String) -> int:
	for i in skins.size():
		if skins[i].skin == name:
			return i
	return -1


func skin_at(index: int) -> WeaponSkin:
	return skins[index] if index >= 0 and index < skins.size() else skins[0]
