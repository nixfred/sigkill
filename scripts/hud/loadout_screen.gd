class_name LoadoutScreen
extends Control
## The loadout screen (C33), from the Esc menu's Loadout (no key of its own): every weapon's skins and its mod,
## and how to earn the ones still locked. A piece of the game, not a form: the void, panels edged in the light
## of the weapon on show, and in the middle the weapon's own model large on a turntable (LoadoutStage), slowly
## turning, lit in its skin. Left, the arsenal in slot order, each with what it has earned of its kit; right,
## its skins as cards, each a swatch of its two lights, a name and a line of fiction, and its mod as a card of
## what it gains and what it costs. A card under the pointer lights the model in that skin at once, locked or
## not; a click wears a held skin or fits or takes off a held mod (saved at once, scripts/unlocks/progress.gd);
## a locked one says how it is earned and how far along this player is. Everything on one screen with no page
## scroll (Law 17), shrunk whole to fit a small window (960x540 and up), mouse and keyboard only.
##
## Alone, what the player wears changes as the screen closes (the Esc menu calls the player's wear()); in a
## match the look the host accepted holds until the match ends, and the screen says so.

signal closed

const Palette = preload("res://scripts/palette.gd")
const ArsenalScript = preload("res://scripts/weapons/arsenal_tuning.gd")

const TITLE := "SIGKILL // loadout"
const HINT := "click a weapon   a card under the pointer lights it   click to wear or fit   Esc back"
const MATCH_NOTE := "In a match your look holds until it ends: changes count from your next match."
const SOLO_NOTE := "Earned alone against daemons that fight back, or in a match on the host's word. Never bought."
const WEARING := "WEARING"
const WEAR := "click to wear"
const MOD_ON := "FITTED: click to take off"
const MOD_OFF := "click to fit"
const LOCKED := "LOCKED  %s"
const MODS_OFF := "the host's mods rule is off: shipped weapons this match"
const FONT := 13
const SMALL := 11
const HEAD := 15
const NAME_FONT := 22
const ROW_W := 196
const CARD_W := 300
## The turntable's size: its least (at 960x540 and under), and its share of a bigger window up to its most, so
## on a big screen the weapon is the hero of it.
const STAGE := Vector2(420, 300)
const STAGE_SHARE := Vector2(0.42, 0.54)
const STAGE_LAST := Vector2(860, 600)
const SWATCH := Vector2(14, 40)
const BAR_CELLS := 10
const MARGIN := 14
const GAP := 14
const EDGE := 8.0
## How much of the arena and its HUD the screen hides behind it: nearly all.
const SHADE_ALPHA := 0.96
## How bright a locked card is: there, but plainly not held.
const LOCKED_ALPHA := 0.55

## The player whose weapons these are (its shipped arsenal and its look), and the session (online or not).
var player: Node = null
var session: Node = null
## The progress shown and changed; null: Progress.current().
var progress: Progress = null
## The weapon on show (its slot), and the skin lighting the model now.
var slot := 0
var stage: LoadoutStage

var _defs: Array = []
var _center: CenterContainer
var _panel: PanelContainer
var _style: StyleBoxFlat
var _rows: Array[Button] = []
var _name: Label
var _fiction: Label
var _worn_line: Label
var _skin_cards: Array[PanelContainer] = []
var _mod_card: PanelContainer
var _note: Label
var _mods_note: Label
var _frame: SubViewportContainer
var _hover := -1


func _ready() -> void:
	if progress == null:
		progress = Progress.current()
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var theme_here := Theme.new()
	theme_here.default_font = Palette.mono_font()
	theme_here.default_font_size = FONT
	theme = theme_here
	_defs = WeaponKit.shipped_defs()
	_build()
	get_viewport().size_changed.connect(_fit)
	visible = false


## The screen up, the weapon in hand on show.
func open() -> void:
	visible = true
	var inv = player.get("inventory") if player != null and is_instance_valid(player) else null
	select(inv.current if inv != null else 0)
	_fit()


func close() -> void:
	if not visible:
		return
	visible = false
	closed.emit()


func is_open() -> bool:
	return visible


## Shows the weapon in slot `index`: the model as this player would wear it, its cards.
func select(index: int) -> void:
	slot = clampi(index, 0, _defs.size() - 1)
	_hover = -1
	stage.show_weapon(_worn(slot))
	_refresh()


## Wears skin `index` of the weapon on show: true when it is held (saved at once), false for a locked one.
func wear_skin(index: int) -> bool:
	var kit := WeaponKit.of(_defs[slot].id)
	if kit == null or index < 0 or index >= kit.skins.size() or not progress.choose_skin(_defs[slot].id, kit.skins[index].skin):
		return false
	stage.show_weapon(_worn(slot))
	_refresh()
	return true


## Fits the mod of the weapon on show, or takes it off: true when that changed it (a held mod), false else.
func toggle_mod() -> bool:
	var id: String = _defs[slot].id
	if not progress.choose_mod(id, not progress.mod_on(id)):
		return false
	stage.show_weapon(_worn(slot))
	_refresh()
	return true


## A card under the pointer: skin `index` lights the model (-1: back to the one worn).
func preview(index: int) -> void:
	_hover = index
	var kit := WeaponKit.of(_defs[slot].id)
	stage.light(kit.skin_at(index).skin if kit != null and index >= 0 else progress.skin_of(_defs[slot].id))
	_restyle()


## The texts on the screen now, for the checks: the rows, the name, every card's lines.
func texts() -> PackedStringArray:
	var out := PackedStringArray()
	for row in _rows:
		out.append(row.text)
	out.append(_name.text)
	out.append(_fiction.text)
	out.append(_worn_line.text)
	for card in _skin_cards + [_mod_card]:
		if card.visible:
			for label in card.find_children("*", "Label", true, false):
				out.append((label as Label).text)
	out.append(_note.text)
	return out


## How much the screen is shrunk to fit the window: 1 at 1280x720 and up.
func fit_scale() -> float:
	return _center.scale.x


## The panel's rectangle on screen, for the checks.
func panel_rect() -> Rect2:
	return Rect2(_panel.global_position, _panel.size * _center.scale)


func _input(event: InputEvent) -> void:
	if not visible:
		return
	var key := event as InputEventKey
	if key != null and key.pressed and not key.echo:
		if key.keycode == KEY_ESCAPE or key.physical_keycode == KEY_ESCAPE:
			get_viewport().set_input_as_handled()
			close()
		elif key.keycode == KEY_UP or key.keycode == KEY_DOWN:
			get_viewport().set_input_as_handled()
			select(posmod(slot + (1 if key.keycode == KEY_DOWN else -1), _defs.size()))


func _unhandled_input(event: InputEvent) -> void:
	if visible and (event is InputEventKey or event is InputEventMouseButton):
		get_viewport().set_input_as_handled()


## Weapon `index` as this player would wear it from its choices.
func _worn(index: int) -> Resource:
	var def: Resource = _defs[index]
	var kit := WeaponKit.of(def.id)
	var skin_index := kit.skin_index(progress.skin_of(def.id)) if kit != null else 0
	return Loadout.apply(def, maxi(skin_index, 0), progress.mod_on(def.id))


func _online() -> bool:
	return session != null and is_instance_valid(session) and session.has_method("is_online") and session.is_online()


# --- What it shows. ---

func _refresh() -> void:
	for i in _rows.size():
		var def: Resource = _defs[i]
		var kit := WeaponKit.of(def.id)
		var held := 0
		var total := 0
		if kit != null:
			for skin in kit.skins.slice(1):
				total += 1
				held += 1 if progress.has(def.id, skin.skin) else 0
			if kit.mod != null:
				total += 1
				held += 1 if progress.has(def.id, kit.mod.id) else 0
		var key := str(ArsenalScript.key_of(i)) if ArsenalScript.bank_of(i) == 0 else "S%d" % ArsenalScript.key_of(i)
		_rows[i].text = "%-3s%-12s %d/%d" % [key, def.short_name, held, total]
		_rows[i].button_pressed = i == slot
		var tint := Palette.skin_beam(progress.skin_of(def.id))
		_rows[i].add_theme_color_override("font_color", tint)
		_rows[i].add_theme_color_override("font_pressed_color", Palette.FLASH)
	var def: Resource = _defs[slot]
	var kit := WeaponKit.of(def.id)
	_name.text = def.display_name
	_fiction.text = def.fiction
	var skin := kit.skin_at(kit.skin_index(progress.skin_of(def.id))) if kit != null else null
	_worn_line.text = "skin  %s     mod  %s" % [skin.display_name if skin != null else "-", kit.mod.display_name if kit != null and kit.mod != null and progress.mod_on(def.id) else "none"]
	for i in _skin_cards.size():
		var card := _skin_cards[i]
		card.visible = kit != null and i < kit.skins.size()
		if card.visible:
			_fill_skin(card, def, kit.skins[i])
	_mod_card.visible = kit != null and kit.mod != null
	if _mod_card.visible:
		_fill_mod(def, kit.mod)
	_note.text = MATCH_NOTE if _online() else SOLO_NOTE
	_mods_note.visible = _online() and session.get("match_mods") == false
	_restyle()


func _fill_skin(card: PanelContainer, def: Resource, skin: WeaponSkin) -> void:
	var held := progress.has(def.id, skin.skin)
	var worn := progress.skin_of(def.id) == skin.skin
	var parts: Dictionary = card.get_meta(&"parts")
	(parts["body"] as ColorRect).color = skin.body()
	(parts["beam"] as ColorRect).color = skin.beam()
	parts["name"].text = skin.display_name
	parts["name"].add_theme_color_override("font_color", skin.beam())
	parts["fiction"].text = skin.fiction
	parts["state"].text = WEARING if worn else (WEAR if held else LOCKED % _earn_line(skin))
	parts["state"].add_theme_color_override("font_color", skin.beam() if worn else (Palette.MINT if held else Palette.TEAL))
	parts["bar"].text = "" if held else _bar(skin)
	parts["bar"].add_theme_color_override("font_color", skin.body())
	card.modulate = Color(1, 1, 1, 1.0 if held else LOCKED_ALPHA)
	card.set_meta(&"skin", skin.skin)


func _fill_mod(def: Resource, mod: WeaponMod) -> void:
	var held := progress.has(def.id, mod.id)
	var on := progress.mod_on(def.id)
	var parts: Dictionary = _mod_card.get_meta(&"parts")
	var shipped: Resource = _defs[slot]
	parts["name"].text = "mod  " + mod.display_name
	parts["fiction"].text = mod.fiction
	var lines := mod.lines(shipped)
	var gains := PackedStringArray()
	var costs := PackedStringArray()
	for line in lines:
		(gains if line.begins_with("+") else costs).append(line)
	parts["gains"].text = "\n".join(gains)
	parts["costs"].text = "\n".join(costs)
	parts["state"].text = (MOD_ON if on else MOD_OFF) if held else LOCKED % _earn_line(mod)
	parts["state"].add_theme_color_override("font_color", Palette.MINT if held else Palette.TEAL)
	parts["bar"].text = "" if held else _bar(mod)
	_mod_card.modulate = Color(1, 1, 1, 1.0 if held else LOCKED_ALPHA)


## How a locked item is earned: "12 / 25 kills with cannon".
func _earn_line(item: Resource) -> String:
	return progress.progress_line(_defs[slot].id, item)


func _bar(item: Resource) -> String:
	var lit := clampi(floori(float(progress.count_of(item.feat)) / maxf(item.need, 1) * BAR_CELLS), 0, BAR_CELLS)
	return "[%s%s]" % ["#".repeat(lit), ".".repeat(BAR_CELLS - lit)]


## The panel's edge, the cards' edges and the stage's light follow the skin on show (the one under the pointer
## while there is one).
func _restyle() -> void:
	var kit := WeaponKit.of(_defs[slot].id)
	var shown := stage.skin if stage.skin != "" else progress.skin_of(_defs[slot].id)
	_style.border_color = Palette.skin_body(shown)
	for i in _skin_cards.size():
		var card := _skin_cards[i]
		if not card.visible or kit == null:
			continue
		var style := card.get_theme_stylebox("panel") as StyleBoxFlat
		var skin: WeaponSkin = kit.skins[i]
		var worn := progress.skin_of(_defs[slot].id) == skin.skin
		style.border_color = skin.body() if worn or i == _hover else Color(skin.body(), 0.35)
		style.set_border_width_all(2 if worn or i == _hover else 1)
	var mod_style := _mod_card.get_theme_stylebox("panel") as StyleBoxFlat
	mod_style.border_color = Palette.skin_beam(shown) if progress.mod_on(_defs[slot].id) else Color(Palette.skin_body(shown), 0.35)


# --- Building. ---

func _build() -> void:
	var shade := ColorRect.new()
	shade.color = Color(Palette.VOID, SHADE_ALPHA)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(shade)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_center = CenterContainer.new()
	_center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_center)
	_panel = PanelContainer.new()
	_style = StyleBoxFlat.new()
	_style.bg_color = Color(Palette.VOID, 0.94)
	_style.border_color = Palette.TEAL
	_style.set_border_width_all(1)
	_style.set_content_margin_all(MARGIN)
	_panel.add_theme_stylebox_override("panel", _style)
	_center.add_child(_panel)
	var sheet := VBoxContainer.new()
	sheet.add_theme_constant_override("separation", 8)
	_panel.add_child(sheet)
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", GAP)
	sheet.add_child(head)
	_label(head, TITLE, HEAD, Palette.TEAL)
	_note = _label(head, SOLO_NOTE, SMALL, Palette.MINT)
	var columns := HBoxContainer.new()
	columns.add_theme_constant_override("separation", GAP)
	sheet.add_child(columns)
	_build_rows(columns)
	_build_stage(columns)
	_build_cards(columns)
	var foot := HBoxContainer.new()
	foot.add_theme_constant_override("separation", GAP)
	sheet.add_child(foot)
	var back := Button.new()
	back.text = "Back"
	back.pressed.connect(close)
	foot.add_child(back)
	_label(foot, HINT, SMALL, Palette.TEAL)
	_mods_note = _label(foot, MODS_OFF, SMALL, Palette.HOSTILE_AMBER)
	_mods_note.visible = false


func _build_rows(parent: Control) -> void:
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 2)
	col.custom_minimum_size.x = ROW_W
	parent.add_child(col)
	_label(col, "ARSENAL", HEAD, Palette.TEAL)
	var group := ButtonGroup.new()
	for i in _defs.size():
		var row := Button.new()
		row.toggle_mode = true
		row.button_group = group
		row.flat = true
		row.alignment = HORIZONTAL_ALIGNMENT_LEFT
		row.focus_mode = Control.FOCUS_NONE
		row.custom_minimum_size = Vector2(ROW_W, 22)
		row.pressed.connect(select.bind(i))
		col.add_child(row)
		_rows.append(row)


func _build_stage(parent: Control) -> void:
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 3)
	parent.add_child(col)
	_frame = SubViewportContainer.new()
	_frame.stretch = true
	_frame.custom_minimum_size = STAGE
	_frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stage = LoadoutStage.new()
	stage.name = "Stage"
	_frame.add_child(stage)
	col.add_child(_frame)
	_name = _label(col, "", NAME_FONT, Palette.FLASH)
	_fiction = _label(col, "", FONT, Palette.TEAL)
	_worn_line = _label(col, "", FONT, Palette.MINT)


func _build_cards(parent: Control) -> void:
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 5)
	col.custom_minimum_size.x = CARD_W
	parent.add_child(col)
	_label(col, "LIGHT SKINS", HEAD, Palette.TEAL)
	for i in WeaponKit.SKINS_LAST:
		var card := _card(col)
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		row.mouse_filter = Control.MOUSE_FILTER_IGNORE
		card.add_child(row)
		var swatch := VBoxContainer.new()
		swatch.add_theme_constant_override("separation", 0)
		swatch.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(swatch)
		var body := ColorRect.new()
		body.custom_minimum_size = Vector2(SWATCH.x, SWATCH.y * 0.6)
		body.mouse_filter = Control.MOUSE_FILTER_IGNORE
		swatch.add_child(body)
		var beam := ColorRect.new()
		beam.custom_minimum_size = Vector2(SWATCH.x, SWATCH.y * 0.4)
		beam.mouse_filter = Control.MOUSE_FILTER_IGNORE
		swatch.add_child(beam)
		var text := VBoxContainer.new()
		text.add_theme_constant_override("separation", 0)
		text.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(text)
		var parts := {"body": body, "beam": beam, "name": _label(text, "", HEAD, Palette.MINT), "fiction": _label(text, "", SMALL, Palette.TEAL), "state": _label(text, "", SMALL, Palette.MINT), "bar": _label(text, "", SMALL, Palette.MINT)}
		card.set_meta(&"parts", parts)
		card.gui_input.connect(_on_skin_card_input.bind(i))
		card.mouse_entered.connect(preview.bind(i))
		card.mouse_exited.connect(preview.bind(-1))
		_skin_cards.append(card)
	_label(col, "MOD", HEAD, Palette.TEAL)
	_mod_card = _card(col)
	var text := VBoxContainer.new()
	text.add_theme_constant_override("separation", 0)
	text.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_mod_card.add_child(text)
	var mod_parts := {"name": _label(text, "", HEAD, Palette.FLASH), "fiction": _label(text, "", SMALL, Palette.TEAL), "gains": _label(text, "", SMALL, Palette.MINT), "costs": _label(text, "", SMALL, Palette.HOSTILE_AMBER), "state": _label(text, "", SMALL, Palette.MINT), "bar": _label(text, "", SMALL, Palette.TEAL)}
	_mod_card.set_meta(&"parts", mod_parts)
	_mod_card.gui_input.connect(_on_mod_card_input)


func _card(parent: Control) -> PanelContainer:
	var card := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(Palette.BASE, 0.85)
	style.border_color = Color(Palette.TEAL, 0.35)
	style.set_border_width_all(1)
	style.set_content_margin_all(6)
	card.add_theme_stylebox_override("panel", style)
	card.mouse_filter = Control.MOUSE_FILTER_STOP
	card.custom_minimum_size.x = CARD_W
	parent.add_child(card)
	return card


func _label(parent: Control, text: String, size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", color)
	parent.add_child(label)
	return label


func _on_skin_card_input(event: InputEvent, index: int) -> void:
	var click := event as InputEventMouseButton
	if click != null and click.pressed and click.button_index == MOUSE_BUTTON_LEFT:
		wear_skin(index)


func _on_mod_card_input(event: InputEvent) -> void:
	var click := event as InputEventMouseButton
	if click != null and click.pressed and click.button_index == MOUSE_BUTTON_LEFT:
		toggle_mod()


## A window smaller than the screen (960x540, say) shrinks it whole and centred: never a page scroll, never a
## clipped row (the Esc menu's own way).
func _fit() -> void:
	if _center == null:
		return
	var screen := get_viewport_rect().size
	_frame.custom_minimum_size = (screen * STAGE_SHARE).clamp(STAGE, STAGE_LAST).floor()
	var need: Vector2 = _panel.get_combined_minimum_size()
	var k := 1.0
	if need.x > 0.0 and need.y > 0.0:
		k = clampf(minf((screen.x - 2.0 * EDGE) / need.x, (screen.y - 2.0 * EDGE) / need.y), 0.1, 1.0)
	_center.scale = Vector2(k, k)
	_center.position = Vector2.ZERO
	_center.size = screen / k
