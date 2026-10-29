extends Control
## The weapon strip (C16), bottom right, above the hint line and below the kill feed: every
## slot's key, the drawn one in brackets with its name ("1 [2 SIGTERM] 3"); the drawn
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
##
## Code-rain vision (C21): a fifth line, right under SIGSTOP's, is vision's own meter in the
## code rain's green with the key that works it: "V vision [##########]", dimmed while below
## the start's share, "V VISION [####......]" in the rain's bright head colour while it is on.
## A line under SIGSTOP's, not beside it: beside it the strip would grow wider than the room
## the round summary leaves it at 960x540, and the line still clears the kill feed above.
##
## fork() (C24) is slot 5: one space between slots, not two ("[1 cannon] 2 3 4(2) 5"), so
## five slots take no more room than four did and the strip stays clear of the panels centred
## at 960x540. grep (C25) is slot 6 ("[1 cannon] 2 3 4(2) 5 6"); its marks and their count,
## "grep -c: N", are under the crosshair (scripts/hud/grep_marks.gd), not on the strip, so the
## strip keeps its five lines. The slot line is smaller than the ammo line (SLOT_FONT): at the
## full size six slots with SIGTERM drawn reached 3 px under the guide panel at 960x540.
##
## The rm -rf cannon (C26) is slot 7; the slot line is the small lines' size (12) since, so seven
## slots stay clear of the guide panel at 960x540. While it winds up, the third line types its
## charge prompt out as the wind-up fills ("rm: remove? [y]" whole when the shot goes); the rail's
## charging bar is the rail's alone.
##
## cron mines (C27) are slot 8; the slot line is a point smaller again (11), so eight slots stay
## clear of the guide panel at 960x540 (a two-row strip was to wait for a ninth weapon; C28 shrank the
## line a point more instead). While cron is in hand, the third line is the crontab: "crontab 2/3"
## (this player's jobs running and the limit), or "crontab full: oldest out" for a moment after a
## placement removed the oldest.
##
## ping (C28) is slot 9, the last free one, still on the one slot line (the strip's redesign comes
## with C29): the slot line a point smaller again (10), so nine slots stay clear of the guide panel
## at 960x540. A cooldown, not ammo: drawn, its ammo line reads "ping  ready" or the seconds left
## ("ping  4.2s"), and the third line is the sonar coming back, "sonar [######....]" in its lime,
## "sonar ready: 18m" (its reach) once it is.
##
## The second bank (C29): keys 1 to 9 were all taken, so weapons 10 to 18 are bank 2, drawn with the
## bank key held (Shift; rebindable). The strip has two slot rows in its own column: bank 1 on the
## bottom row as before (slots_text(), "1 2 3 4(2) 5 6 7 8 9"), bank 2 over it, its keys led by the bank
## key's name ("Shift+ [1 chmod]"), one label (bank2_text()). The active bank's row is lit and the other
## dimmed: the drawn weapon's bank, or bank 2 while the bank key is held (1 to 9 then draw its weapons).
## Both rows stay the slot line's 10 px, and the strip keeps the column it always had (the ICEbreakers'
## readout is bottom left, over the sudo badge): at 960x540 it still clears the kill feed above it and
## the guide panel beside it. chmod 000 (weapon 10) drawn: its ammo line is its coolant ("chmod  coolant
## 72%", "chmod  VENTING"), its third line the tank ("coolant [#######...]" in its frost text colour, or
## "venting [###.......]" in amber until it is back to its share).

const Palette = preload("res://scripts/palette.gd")
const WeaponDefScript = preload("res://scripts/weapons/weapon_def.gd")
const Controls = preload("res://scripts/controls.gd")
const Arsenal = preload("res://scripts/weapons/arsenal_tuning.gd")

const SLOT := "%d"
## Between one slot and the next on the slot line.
const SLOT_GAP := " "
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
const VISION_LINE := "%s vision [%s%s]"
const VISION_ON_LINE := "%s VISION [%s%s]"
const CRONTAB_LINE := "crontab %d/%d"
const CRONTAB_FULL := "crontab full: oldest out"
const PING_READY := "%s  ready"
const PING_WAIT := "%s  %.1fs"
const SONAR_LINE := "sonar [%s%s]"
const SONAR_READY := "sonar ready: %dm"
## The second bank's row (C29): the bank key's name, then its slots.
const BANK2_LEAD := "%s+ "
## chmod 000's lines (C29): its coolant.
const COOLANT_AMMO := "%s  coolant %d%%"
const COOLANT_VENT_AMMO := "%s  VENTING"
const COOLANT_LINE := "coolant [%s%s]"
const VENT_LINE := "venting [%s%s]"
## A bank's row while the other is active.
const BANK_DIM := 0.5
## How dim an ult slot is while its meter fills.
const DIM := 0.4
const FONT := 14
## The slot line's size: a point under the small lines' (C27), and another for the ninth slot (C28),
## so nine slots stay clear of the guide panel.
const SLOT_FONT := 10
const SMALL_FONT := 12
const MARGIN := 18
## Room kept below the strip for the hint line.
const BOTTOM_GAP := 22

## The player whose inventory to show.
var player: Node = null

var _stack: VBoxContainer
var _slot_row: HBoxContainer
var _slot_labels: Array[Label] = []
var _bank2: Label
var _ammo: Label
var _meter_text := ""
var _meter_ready := false
var _state: Label
var _stop: Label
var _vision: Label


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
	_bank2 = _label(SLOT_FONT, Palette.MINT)  # bank 2's row over bank 1's (C29)
	_bank2.visible = false
	_slot_row = HBoxContainer.new()
	_slot_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_slot_row.alignment = BoxContainer.ALIGNMENT_END
	_slot_row.add_theme_constant_override("separation", 0)
	_stack.add_child(_slot_row)
	_ammo = _label(FONT, Palette.MINT)
	_state = _label(SMALL_FONT, Palette.TEAL)
	_stop = _label(SMALL_FONT, Palette.TEAL)
	_vision = _label(SMALL_FONT, Palette.MATRIX_GREEN)
	_refresh()


func _process(_delta: float) -> void:
	_refresh()


## The strip itself (I1: an ICE field's HUD corruption scrambles it, and the jam's notice sits over it).
func strip() -> Control:
	return _stack


## Bank 2's row as shown ("Shift+ [1 chmod]"), or "" when the loadout has no second bank (C29).
func bank2_text() -> String:
	return _bank2.text if _bank2.visible else ""


## The bank whose row is lit now (0 for bank 1), and how dim each row is (1 lit), for the checks.
func active_bank() -> int:
	return 1 if _bank2.visible and _bank2.modulate.a >= 1.0 else 0


func bank_alpha(bank: int) -> float:
	return _bank2.modulate.a if bank == 1 else _slot_row.modulate.a


## The two slot rows (C29): bank 2's label and bank 1's row, for the layout checks.
func bank_rows() -> Array[Control]:
	return [_bank2, _slot_row]


func slots_text() -> String:
	var parts := PackedStringArray()
	for label in _slot_labels:
		parts.append(label.text.strip_edges())
	return SLOT_GAP.join(parts)


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


## Code-rain vision's meter ("V vision [##########]"), or "" when the player has none.
func vision_text() -> String:
	return _vision.text if _vision.visible else ""


## True while vision's meter is dimmed: below the start's share.
func vision_dimmed() -> bool:
	return _vision.modulate.a < 1.0


func state_text() -> String:
	return _state.text


func _refresh() -> void:
	var inv = player.get("inventory") if player != null and is_instance_valid(player) else null
	_stack.visible = inv != null and (player.get("alive") != false)
	if not _stack.visible:
		return
	var bank1: int = mini(inv.slot_count(), Arsenal.BANK_SLOTS)
	while _slot_labels.size() < bank1:
		_slot_labels.append(_slot_label())
	for i in _slot_labels.size():
		var label: Label = _slot_labels[i]
		label.visible = i < bank1
		if not label.visible:
			continue
		var plain: String = (SLOT_THROWN % [i + 1, inv.mags[i]]) if inv.defs[i].is_thrown() else SLOT % (i + 1)
		label.text = (SLOT_GAP if i > 0 else "") + (SLOT_DRAWN % [i + 1, inv.defs[i].short_name] if i == inv.current else plain)
		var ult: bool = inv.defs[i].is_ult()
		label.add_theme_color_override("font_color", inv.defs[i].skin_beam() if ult and inv.meter_ready() else Palette.MINT)
		label.modulate = Color(1, 1, 1, DIM if ult and not inv.meter_ready() else 1.0)
	_refresh_banks(inv)
	var ult_slot: int = inv.ult_slot()
	_meter_text = ""
	_meter_ready = ult_slot >= 0 and inv.meter_ready()
	if ult_slot >= 0:
		var cells := roundi(inv.meter_share() * BAR_CELLS)
		if player.has_method("is_charging") and player.is_charging() and inv.def().is_ult():
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
	elif def.is_ping():
		var wait: float = inv.cooldowns[inv.current]
		_ammo.text = (PING_WAIT % [def.short_name, wait]) if wait > 0.0 else (PING_READY % def.short_name)
	elif def.is_freeze() and inv.coolant(inv.current) != null:
		var tank = inv.coolant(inv.current)
		_ammo.text = (COOLANT_VENT_AMMO % def.short_name) if tank.venting else (COOLANT_AMMO % [def.short_name, roundi(tank.share() * 100.0)])
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
	elif charging and def.charge_prompt != "":
		# The wind-up's prompt, typed out as it fills (C26): at least its first letter at once.
		var shown := clampi(ceili(player.charge_progress() * def.charge_prompt.length()), 1, def.charge_prompt.length())
		_state.text = def.charge_prompt.left(shown)
		state_color = def.skin_beam()
	elif charging:
		_state.text = _meter_text
		state_color = def.skin_beam()
	elif inv.fiction_left > 0.0:
		_state.text = def.fiction
	elif def.has_magazine() and mag <= 0:
		_state.text = DRY_LINE if reserve == 0 else EMPTY_LINE
		color = Palette.HOSTILE_AMBER
	elif def.is_freeze() and inv.coolant(inv.current) != null:
		# chmod 000 (C29): the tank, or its venting back to its share.
		var tank = inv.coolant(inv.current)
		var lit := clampi(roundi(tank.share() * BAR_CELLS), 0, BAR_CELLS)
		_state.text = (VENT_LINE if tank.venting else COOLANT_LINE) % [BAR_FULL.repeat(lit), BAR_EMPTY.repeat(BAR_CELLS - lit)]
		state_color = Palette.HOSTILE_AMBER if tank.venting else Palette.FROST_TEXT
		if tank.venting:
			color = Palette.HOSTILE_AMBER
	elif def.is_ping() and player.has_method("ping_ready"):
		# ping (C28): the sonar coming back, or ready with its reach.
		var back: float = player.ping_ready()
		var lit := clampi(floori(back * BAR_CELLS), 0, BAR_CELLS)
		_state.text = (SONAR_READY % roundi(def.ping_radius_m)) if back >= 1.0 else SONAR_LINE % [BAR_FULL.repeat(lit), BAR_EMPTY.repeat(BAR_CELLS - lit)]
		state_color = def.skin_beam() if back >= 1.0 else def.skin_body()
	elif def.is_mine() and player.has_method("crontab_count"):
		# cron (C27): the crontab, or the note that its oldest job went.
		_state.text = CRONTAB_FULL if player.crontab_noted() else CRONTAB_LINE % [player.crontab_count(), def.crontab_limit]
		state_color = def.skin_body()
	elif ult_slot >= 0:
		_state.text = _meter_text
		if _meter_ready:
			state_color = inv.defs[ult_slot].skin_beam()
	else:
		_state.text = KEYS_LINE
	_ammo.add_theme_color_override("font_color", color)
	_state.add_theme_color_override("font_color", state_color)
	_refresh_stop()
	_refresh_vision()


## The two slot rows (C29): bank 2's, its keys led by the bank key's name, the drawn one bracketed and
## named; the active bank's row lit, the other dimmed.
func _refresh_banks(inv) -> void:
	_bank2.visible = inv.slot_count() > Arsenal.BANK_SLOTS
	if not _bank2.visible:
		_slot_row.modulate = Color(1, 1, 1, 1)
		return
	var parts := PackedStringArray()
	for i in range(Arsenal.BANK_SLOTS, inv.slot_count()):
		var key := Arsenal.key_of(i)
		parts.append(SLOT_DRAWN % [key, inv.defs[i].short_name] if i == inv.current else SLOT % key)
	var lead := Controls.bind_label(GameSettings.current().bind("weapon_bank"))
	_bank2.text = (BANK2_LEAD % lead) + SLOT_GAP.join(parts)
	var held: bool = player.has_method("bank_held") and player.bank_held()
	var active := 1 if held else Arsenal.bank_of(inv.current)
	_bank2.modulate = Color(1, 1, 1, 1.0 if active == 1 else BANK_DIM)
	_slot_row.modulate = Color(1, 1, 1, 1.0 if active == 0 else BANK_DIM)


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


func _refresh_vision() -> void:
	var vision = player.get("vision")
	_vision.visible = vision != null and is_instance_valid(vision) and vision.meter != null
	if not _vision.visible:
		return
	var cells := roundi(vision.meter.share() * BAR_CELLS)
	var key := Controls.bind_label(GameSettings.current().bind("code_rain_vision"))
	var on: bool = vision.is_on()
	_vision.text = (VISION_ON_LINE if on else VISION_LINE) % [key, BAR_FULL.repeat(cells), BAR_EMPTY.repeat(BAR_CELLS - cells)]
	_vision.add_theme_color_override("font_color", Palette.MATRIX_HEAD if on else Palette.MATRIX_GREEN)
	_vision.modulate = Color(1, 1, 1, 1.0 if on or vision.can_start() else DIM)


func _slot_label() -> Label:
	var label := Label.new()
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_override("font", Palette.mono_font())
	label.add_theme_font_size_override("font_size", SLOT_FONT)
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
