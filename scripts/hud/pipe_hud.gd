extends Control
## pipe | on the HUD (C30). For a moment after each chain, just under the crosshair (in grep's place, 26 px
## down: the weapons that use it are never in hand together), the chain written out as the command line it
## was, at a prompt: "$ rogue.d | zombie | runaway", and after it on the same row how far it went, "3 links" ("1 link: no one
## else in reach", "1 link: a wall broke the chain" when the next target in reach was behind one); a frozen link that conducted is marked with chmod's "000" ("zombie(000)"). What stopped a
## chain says so: "$ white ICE" over "pipe: the wall reads nothing on", "pipe: broken pipe" over "Black ICE
## takes nothing", "pipe: spawn protected, nothing lands" on a player still in spawn protection. Fire pressed
## on a full buffer: "pipe: write blocked, buffer full" for a moment. In the pipe's text colour; a chain's
## readout fades over its last FADE_S.
##
## Visual only: it reads the player (its last chain, its buffer) every frame and changes nothing.

const Palette = preload("res://scripts/palette.gd")

const PROMPT := "$ %s"
const LINKS_LINE := "%d links"
const ONE_LINK := "1 link: no one else in reach"
const WALLED_LINE := "%d %s: a wall broke the chain"
const FROZEN_MARK := "(000)"
const WALL_LINE := "pipe: the wall reads nothing on"
const BLACK_TITLE := "pipe: broken pipe"
const BLACK_LINE := "Black ICE takes nothing"
const PROTECTED_LINE := "pipe: spawn protected, nothing lands"
const BLOCKED_LINE := "pipe: write blocked, buffer full"
## How long a chain's readout stays, and the last part of that over which it fades.
const READOUT_S := 1.8
const FADE_S := 0.5
## How long a refused press says the buffer is full.
const BLOCKED_S := 1.0
## Under the crosshair, pixels: grep's count line's place; the count beside the chain on the same row.
const LINE_DROP := 26.0
const LINE_FONT := 17
const SMALL_FONT := 13
const LINE_FONT_SMALLER := 13
const SMALL_FONT_SMALLER := 11
## How short every name is cut, in turn, when a row will not fit even drawn smaller (0: whole), and the
## mark a cut name ends in.
const NAME_CUTS := [0, 12, 7]
const CUT_MARK := "~"
## The gap between the chain and its count, and the room kept at each side of the screen.
const ROW_GAP_PX := 14.0
const SIDE_ROOM_PX := 16.0

## The player whose chains to show.
var player: Node = null

var _line: Label
var _small: Label


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_line = _label(LINE_FONT)
	_small = _label(SMALL_FONT)


func _process(_delta: float) -> void:
	_refresh()


## The readout's two lines now ("" when none), for the checks.
func line_text() -> String:
	return _line.text if _line.visible else ""


func small_text() -> String:
	return _small.text if _small.visible else ""


func _refresh() -> void:
	_line.visible = false
	_small.visible = false
	var p := player
	if p == null or not is_instance_valid(p) or p.get("alive") != true:
		return
	if _lines(p, 0).is_empty():
		return
	# One row under the crosshair, the count after the chain (the breakers' effect lines stay under it); a
	# row too wide for the screen is drawn smaller, then with its names cut short.
	var lines := PackedStringArray()
	for cut in NAME_CUTS:
		lines = _lines(p, cut)
		_line.text = lines[0]
		_small.text = lines[1]
		_line.visible = _line.text != ""
		_small.visible = _small.text != ""
		var fits := false
		for sizes in [[LINE_FONT, SMALL_FONT], [LINE_FONT_SMALLER, SMALL_FONT_SMALLER]]:
			_line.add_theme_font_size_override("font_size", sizes[0])
			_small.add_theme_font_size_override("font_size", sizes[1])
			fits = _row_width() <= size.x - SIDE_ROOM_PX * 2.0
			if fits:
				break
		if fits:
			break
	# A label grows to its text but never shrinks back on its own: fit both to what they show now.
	_line.size = _line.get_minimum_size()
	_small.size = _small.get_minimum_size()
	var age: float = p.get("chain_age") if p.get("chain_age") is float else INF
	var alpha := 1.0 if lines[2] == "now" else clampf((READOUT_S - age) / FADE_S, 0.0, 1.0)
	_line.modulate.a = alpha
	_small.modulate.a = alpha
	var left := (size.x - _row_width()) * 0.5
	var top := size.y * 0.5 + LINE_DROP
	_line.position = Vector2(left, top)
	_small.position = Vector2(left + (_line.get_minimum_size().x + ROW_GAP_PX if _line.visible else 0.0), top + (_line.get_minimum_size().y - _small.get_minimum_size().y if _line.visible else 0.0))


## The row's width now: the chain, the gap and the count.
func _row_width() -> float:
	var w := _line.get_minimum_size().x if _line.visible else 0.0
	if _small.visible:
		w += _small.get_minimum_size().x + (ROW_GAP_PX if _line.visible else 0.0)
	return w


## [line, small line, "now" for a live note or "" for a chain's readout], or [] for nothing to show; with
## `cut` above 0 every name longer than it cut to it, its end marked.
func _lines(p: Node, cut: int = 0) -> PackedStringArray:
	var def = p.weapon_tuning() if p.has_method("weapon_tuning") else null
	if def == null or not def.is_chain():
		return PackedStringArray()
	var inv = p.get("inventory")
	var pipe = inv.buffer(inv.current) if inv != null else null
	var refused = p.get("blocked_age")
	if pipe != null and pipe.blocked and refused is float and refused < BLOCKED_S:
		return PackedStringArray([BLOCKED_LINE, "", "now"])
	var age = p.get("chain_age")
	if not (age is float) or age >= READOUT_S:
		return PackedStringArray()
	var links: Array = p.get("last_chain")
	match String(p.get("chain_end")):
		"wall":
			return PackedStringArray([PROMPT % _name(links[0], cut), WALL_LINE, ""])
		"black":
			return PackedStringArray([BLACK_TITLE, BLACK_LINE, ""])
		"protected":
			return PackedStringArray([PROTECTED_LINE, "", ""])
		"miss":
			return PackedStringArray()
	var names := PackedStringArray()
	for link in links:
		names.append(_name(link, cut) + (FROZEN_MARK if link.get("frozen") == true else ""))
	var count := ONE_LINK if links.size() == 1 else LINKS_LINE % links.size()
	if p.get("chain_walled") == true:
		count = WALLED_LINE % [links.size(), "link" if links.size() == 1 else "links"]
	return PackedStringArray([PROMPT % PipeChain.JOIN.join(names), count, ""])


static func _name(link: Dictionary, cut: int = 0) -> String:
	var who := String(link.get("name", "?"))
	return who.left(cut - 1) + CUT_MARK if cut > 0 and who.length() > cut else who


func _label(font_size: int) -> Label:
	var label := Label.new()
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_override("font", Palette.mono_font())
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", Palette.PIPE_TEXT)
	label.add_theme_color_override("font_outline_color", Palette.VOID)
	label.add_theme_constant_override("outline_size", 4)
	label.visible = false
	add_child(label)
	return label
