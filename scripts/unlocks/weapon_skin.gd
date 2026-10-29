class_name WeaponSkin
extends Resource
## One Tron light skin of a weapon (C33, PRD 5.2): a palette skin by its name (scripts/palette.gd SKINS, the
## one source of colours: its body lights the model's seams, trim and rim, its beam the hot parts, the trails,
## the muzzle burst and the weapon's line on the HUD strip), its name and a little fiction on the loadout
## screen, and the feat that earns it. Cosmetic only: a skin changes no number of the weapon. The first skin
## of a kit is the weapon's own, held from the start (no feat).

const Palette = preload("res://scripts/palette.gd")

const ID_LAST := 16
const NAME_LAST := 18
const FICTION_LAST := 46
const NEED_LAST := 100000

## The palette's name for it: a key of Palette.SKINS, and its id in the save.
@export var skin: String = "teal"
## What the loadout screen calls it, and its line of fiction.
@export var display_name: String = "stock teal"
@export var fiction: String = "as shipped"
## The feat that earns it (a Progress.FEATS key) and how many of it; "" and 0 for the weapon's own.
@export var feat: String = ""
@export var need: int = 0


## One line per value that would break it. Empty means usable.
func problems() -> PackedStringArray:
	var out := PackedStringArray()
	if not Palette.SKINS.has(skin) or skin.length() > ID_LAST:
		out.append("skin must be a palette skin name of at most %d characters" % ID_LAST)
	if not _line(display_name, NAME_LAST) or not _line(fiction, FICTION_LAST):
		out.append("a skin's name and fiction are 1 to %d and %d printable characters" % [NAME_LAST, FICTION_LAST])
	if (feat == "") != (need == 0) or need < 0 or need > NEED_LAST:
		out.append("a skin is earned by a feat and a count (1 to %d), or held from the start with neither" % NEED_LAST)
	return out


func body() -> Color:
	return Palette.skin_body(skin)


func beam() -> Color:
	return Palette.skin_beam(skin)


static func _line(text: String, last: int) -> bool:
	if text.strip_edges().is_empty() or text.length() > last:
		return false
	for ch in text:
		if ch.unicode_at(0) < 32 or ch.unicode_at(0) > 126:
			return false
	return true
