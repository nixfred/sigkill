extends Control
## The weapon strip (C16), bottom right, above the hint line and below the kill feed: every
## slot with its key, the drawn one in brackets; the drawn weapon's ammo, magazine and
## reserve ("inf" when there is no limit); and a third line that is the reload bar while
## it reloads, the weapon's fiction line for a moment after it is drawn, "empty" or "out of
## ammo" when it is, and the swap keys otherwise. It reads the player's inventory every
## frame and changes nothing.

const Palette = preload("res://scripts/palette.gd")
const WeaponDefScript = preload("res://scripts/weapons/weapon_def.gd")

const SLOT := "%d %s"
const SLOT_DRAWN := "[%d %s]"
const AMMO_LINE := "%s  %s / %s"
const AMMO_ENDLESS := "%s  inf"
const ENDLESS := "inf"
const RELOAD_LINE := "reload [%s%s]"
const BAR_FULL := "#"
const BAR_EMPTY := "."
const BAR_CELLS := 10
const EMPTY_LINE := "empty   E reloads"
const DRY_LINE := "out of ammo"
const KEYS_LINE := "Q last   E reload"
const FONT := 14
const SMALL_FONT := 12
const MARGIN := 18
## Room kept below the strip for the hint line.
const BOTTOM_GAP := 22

## The player whose inventory to show.
var player: Node = null

var _stack: VBoxContainer
var _slots: Label
var _ammo: Label
var _state: Label


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_stack = VBoxContainer.new()
	_stack.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_stack.alignment = BoxContainer.ALIGNMENT_END
	_stack.add_theme_constant_override("separation", 0)
	add_child(_stack)
	_stack.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT, Control.PRESET_MODE_MINSIZE, MARGIN)
	_stack.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	_stack.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_stack.position.y -= BOTTOM_GAP
	_slots = _label(FONT, Palette.MINT)
	_ammo = _label(FONT, Palette.MINT)
	_state = _label(SMALL_FONT, Palette.TEAL)
	_refresh()


func _process(_delta: float) -> void:
	_refresh()


func slots_text() -> String:
	return _slots.text


func ammo_text() -> String:
	return _ammo.text


func state_text() -> String:
	return _state.text


func _refresh() -> void:
	var inv = player.get("inventory") if player != null and is_instance_valid(player) else null
	_stack.visible = inv != null and (player.get("alive") != false)
	if not _stack.visible:
		return
	var slots := PackedStringArray()
	for i in inv.slot_count():
		slots.append((SLOT_DRAWN if i == inv.current else SLOT) % [i + 1, inv.defs[i].short_name])
	_slots.text = "  ".join(slots)
	var def: WeaponDefScript = inv.def()
	var mag: int = inv.mags[inv.current]
	var reserve: int = inv.reserves[inv.current]
	if not def.has_magazine():
		_ammo.text = AMMO_ENDLESS % def.short_name
	else:
		_ammo.text = AMMO_LINE % [def.short_name, str(mag), ENDLESS if reserve == WeaponDefScript.INFINITE else str(reserve)]
	var color := Palette.MINT
	if inv.is_reloading():
		var cells := roundi(inv.reload_progress() * BAR_CELLS)
		_state.text = RELOAD_LINE % [BAR_FULL.repeat(cells), BAR_EMPTY.repeat(BAR_CELLS - cells)]
	elif inv.fiction_left > 0.0:
		_state.text = def.fiction
	elif def.has_magazine() and mag <= 0:
		_state.text = DRY_LINE if reserve == 0 else EMPTY_LINE
		color = Palette.HOSTILE_AMBER
	else:
		_state.text = KEYS_LINE
	_ammo.add_theme_color_override("font_color", color)


func _label(size: int, color: Color) -> Label:
	var label := Label.new()
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	label.add_theme_font_override("font", Palette.mono_font())
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_outline_color", Palette.VOID)
	label.add_theme_constant_override("outline_size", 4)
	_stack.add_child(label)
	return label
