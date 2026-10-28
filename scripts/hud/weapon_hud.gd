extends Control
## The weapon strip (C16), bottom right, above the hint line and below the kill feed: every
## slot's key, the drawn one in brackets with its name ("1  [2 SIGTERM]  3"); the drawn
## weapon's ammo, magazine and reserve ("inf" when there is no limit); and a third line that
## is the reload bar while it reloads, the weapon's fiction line for a moment after it is
## drawn, "empty" or "out of ammo" when it is, and otherwise the ult meter (or the swap keys
## with no ult in the loadout). It reads the player's inventory every frame and changes
## nothing.
##
## The ult (C17): its slot (3, the SIGKILL rail) shows dimmed until the meter is full; the
## meter fills in the theme's teal and turns the rail's ice white when the one shot is ready,
## and says so while the rail charges. Only the drawn slot shows its name (C16 showed every
## name; with three slots, and up to nine to come, they would not fit beside the panels at
## 960x540), and the strip keeps its three lines, so nothing above it moves.
##
## SIGSTOP (C18): a fourth line, right under the ult meter, is SIGSTOP's own small meter in the
## theme's colours with the key that works it: "F SIGSTOP [####......]" in teal when a press
## would start it, dimmed while the meter is below the start's share, "F SIGCONT [...]" in
## mint while it runs.
##
## The fork bomb (C19): its slot shows its bombs left even when another weapon is drawn
## ("4(2)"), since G throws one from there, and drawn its ammo line reads "fork bomb  2 left".

const Palette = preload("res://scripts/palette.gd")
const WeaponDefScript = preload("res://scripts/weapons/weapon_def.gd")
const Controls = preload("res://scripts/controls.gd")

const SLOT := "%d"
const SLOT_DRAWN := "[%d %s]"
const SLOT_THROWN := "%d(%d)"
const THROWN_LINE := "%s  %d left"
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
const METER_LINE := "kill -9 [%s%s]"
const METER_READY := "kill -9 ready: %d, fire"
const METER_CHARGING := "charging [%s%s]"
const ULT_FILLING := "%s  meter %d%%"
const ULT_READY := "%s  ready"
const STOP_LINE := "%s SIGSTOP [%s%s]"
const STOP_ON_LINE := "%s SIGCONT [%s%s]"
## How dim an ult slot is while its meter fills.
const DIM := 0.4
const FONT := 14
const SMALL_FONT := 12
const MARGIN := 18
## Room kept below the strip for the hint line.
const BOTTOM_GAP := 22

## The player whose inventory to show.
var player: Node = null

var _stack: VBoxContainer
var _slot_row: HBoxContainer
var _slot_labels: Array[Label] = []
var _ammo: Label
var _meter_text := ""
var _meter_ready := false
var _state: Label
var _stop: Label


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
	_slot_row = HBoxContainer.new()
	_slot_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_slot_row.alignment = BoxContainer.ALIGNMENT_END
	_slot_row.add_theme_constant_override("separation", 0)
	_stack.add_child(_slot_row)
	_ammo = _label(FONT, Palette.MINT)
	_state = _label(SMALL_FONT, Palette.TEAL)
	_stop = _label(SMALL_FONT, Palette.TEAL)
	_refresh()


func _process(_delta: float) -> void:
	_refresh()


func slots_text() -> String:
	var parts := PackedStringArray()
	for label in _slot_labels:
		parts.append(label.text.strip_edges())
	return "  ".join(parts)


## The ult meter as the strip words it ("kill -9 [###.......]", ready or charging), or ""
## when the loadout has no ult. The third line shows it whenever nothing else is there.
func meter_text() -> String:
	return _meter_text


## True when slot `slot` (0 for slot 1) is shown dimmed: an ult whose meter is not full.
func slot_dimmed(slot: int) -> bool:
	return slot >= 0 and slot < _slot_labels.size() and _slot_labels[slot].modulate.a < 1.0


func ammo_text() -> String:
	return _ammo.text


## SIGSTOP's line ("F SIGSTOP [####......]"), or "" when the player has none.
func stop_text() -> String:
	return _stop.text if _stop.visible else ""


## True while SIGSTOP's line is dimmed: its meter below the start's share.
func stop_dimmed() -> bool:
	return _stop.modulate.a < 1.0


func state_text() -> String:
	return _state.text


func _refresh() -> void:
	var inv = player.get("inventory") if player != null and is_instance_valid(player) else null
	_stack.visible = inv != null and (player.get("alive") != false)
	if not _stack.visible:
		return
	while _slot_labels.size() < inv.slot_count():
		_slot_labels.append(_slot_label())
	for i in _slot_labels.size():
		var label: Label = _slot_labels[i]
		label.visible = i < inv.slot_count()
		if not label.visible:
			continue
		var plain: String = (SLOT_THROWN % [i + 1, inv.mags[i]]) if inv.defs[i].is_thrown() else SLOT % (i + 1)
		label.text = ("  " if i > 0 else "") + (SLOT_DRAWN % [i + 1, inv.defs[i].short_name] if i == inv.current else plain)
		var ult: bool = inv.defs[i].is_ult()
		label.add_theme_color_override("font_color", inv.defs[i].skin_beam() if ult and inv.meter_ready() else Palette.MINT)
		label.modulate = Color(1, 1, 1, DIM if ult and not inv.meter_ready() else 1.0)
	var ult_slot: int = inv.ult_slot()
	_meter_text = ""
	_meter_ready = ult_slot >= 0 and inv.meter_ready()
	if ult_slot >= 0:
		var cells := roundi(inv.meter_share() * BAR_CELLS)
		if player.has_method("is_charging") and player.is_charging():
			var charged := roundi(player.charge_progress() * BAR_CELLS)
			_meter_text = METER_CHARGING % [BAR_FULL.repeat(charged), BAR_EMPTY.repeat(BAR_CELLS - charged)]
		elif _meter_ready:
			_meter_text = METER_READY % (ult_slot + 1)
		else:
			_meter_text = METER_LINE % [BAR_FULL.repeat(cells), BAR_EMPTY.repeat(BAR_CELLS - cells)]
	var def: WeaponDefScript = inv.def()
	var mag: int = inv.mags[inv.current]
	var reserve: int = inv.reserves[inv.current]
	if def.is_ult():
		_ammo.text = (ULT_READY % def.short_name) if inv.meter_ready() else (ULT_FILLING % [def.short_name, floori(inv.meter_share() * 100.0)])
	elif def.is_thrown():
		_ammo.text = THROWN_LINE % [def.short_name, mag]
	elif not def.has_magazine():
		_ammo.text = AMMO_ENDLESS % def.short_name
	else:
		_ammo.text = AMMO_LINE % [def.short_name, str(mag), ENDLESS if reserve == WeaponDefScript.INFINITE else str(reserve)]
	var color := Palette.MINT
	var state_color := Palette.TEAL
	var charging: bool = player.has_method("is_charging") and player.is_charging()
	if inv.is_reloading():
		var cells := roundi(inv.reload_progress() * BAR_CELLS)
		_state.text = RELOAD_LINE % [BAR_FULL.repeat(cells), BAR_EMPTY.repeat(BAR_CELLS - cells)]
	elif charging:
		_state.text = _meter_text
		state_color = def.skin_beam()
	elif inv.fiction_left > 0.0:
		_state.text = def.fiction
	elif def.has_magazine() and mag <= 0:
		_state.text = DRY_LINE if reserve == 0 else EMPTY_LINE
		color = Palette.HOSTILE_AMBER
	elif ult_slot >= 0:
		_state.text = _meter_text
		if _meter_ready:
			state_color = inv.defs[ult_slot].skin_beam()
	else:
		_state.text = KEYS_LINE
	_ammo.add_theme_color_override("font_color", color)
	_state.add_theme_color_override("font_color", state_color)
	_refresh_stop()


func _refresh_stop() -> void:
	var stop = player.get("sigstop")
	_stop.visible = stop != null and is_instance_valid(stop) and stop.meter != null
	if not _stop.visible:
		return
	var cells := roundi(stop.meter.share() * BAR_CELLS)
	var key := Controls.bind_label(GameSettings.current().bind("sigstop"))
	var on: bool = stop.is_on()
	_stop.text = (STOP_ON_LINE if on else STOP_LINE) % [key, BAR_FULL.repeat(cells), BAR_EMPTY.repeat(BAR_CELLS - cells)]
	_stop.add_theme_color_override("font_color", Palette.MINT if on else Palette.TEAL)
	_stop.modulate = Color(1, 1, 1, 1.0 if on or stop.can_start() else DIM)


func _slot_label() -> Label:
	var label := Label.new()
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_override("font", Palette.mono_font())
	label.add_theme_font_size_override("font_size", FONT)
	label.add_theme_color_override("font_color", Palette.MINT)
	label.add_theme_color_override("font_outline_color", Palette.VOID)
	label.add_theme_constant_override("outline_size", 4)
	_slot_row.add_child(label)
	return label


func _label(size: int, color: Color, parent: Control = null) -> Label:
	var label := Label.new()
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	label.add_theme_font_override("font", Palette.mono_font())
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_outline_color", Palette.VOID)
	label.add_theme_constant_override("outline_size", 4)
	(parent if parent != null else _stack).add_child(label)
	return label
