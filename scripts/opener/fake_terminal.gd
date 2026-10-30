class_name FakeTerminal
extends Control
## The opener's fake terminal (C38, PRD 5.7: "a FAKE terminal rendered by the game in the player's active Omarchy
## theme colors"): drawn by the game, inside its own window, to look like the terminal an Omarchy desktop opens. A
## tiled window on the desktop as Omarchy lays one out (10 px gaps, a 2 px border in the theme's accent, square
## corners, 14 px of padding, at 1080 lines; all of it scaled with the window's height), a real monospace grid of
## ROWS rows in the font Omarchy's terminal uses (or the nearest monospace one here), and a blinking block cursor in
## bright_foreground, solid while keys come in. Lines too long for a row wrap; more rows than fit scroll up.
##
## Wide characters (C39, where real names first appear): a row is laid out in cells, as a terminal does
## (scripts/opener/cell_width.gd): a CJK character or an emoji takes two, a combining mark, a variation selector,
## a skin tone or a joined emoji takes none and is drawn with the character before it, and a wide character that
## does not fit at a row's end starts the next row. A plain character is drawn alone in its cell; a cluster is
## drawn as one piece of shaped text, centred in its cells and scaled down if its glyph is wider than they are, so
## nothing spills into the next cell. Glyphs this font lacks come from the system's own fallback fonts.
##
## It is text and colour only: nothing typed into it reaches anything (the opener takes every key), and it runs
## nothing. Every colour comes from its palette (scripts/opener/opener_palette.gd), by Omarchy's names for them, so
## a new palette recolours everything at once. C40 shrinks it away; window_rect() and pop are its handles.

## Rows the grid holds at any window size: the text scales with the window's height, so a 960x540 window shows
## the same screen as a 1920x1080 one.
const ROWS := 30
## Omarchy's look at 1080 lines: the gap round a tiled window, its border, the terminal's padding.
const GAP_PX := 10.0
const BORDER_PX := 2.0
const PADDING_PX := 14.0
## The cursor: solid this long after a key, then on and off this long each.
const SOLID_S := 0.5
const BLINK_S := 0.53
## A row's height as a share of the font's size: a terminal's usual spacing (the Nerd Font's own, 1.32, would
## shrink the text in a small window).
const LINE_SPACING := 1.2
## Where the baseline sits below a row's middle, as a share of the font's size.
const BASELINE := 0.32
## The window popping in (Hyprland's pop-in): from this scale, with its alpha.
const POP_FROM := 0.92
## Fonts, nearest first: Omarchy's terminal font, then any monospace one.
const FONT_NAMES := ["JetBrainsMono Nerd Font", "JetBrains Mono", "DejaVu Sans Mono", "Liberation Mono", "monospace"]

static var _font: SystemFont
static var _bold: SystemFont
## The size each cluster is drawn at to fit its cells, by size and cluster, kept once worked out.
static var _fit_sizes := {}

## The colours.
var palette: OpenerPalette:
	set(value):
		palette = value
		queue_redraw()
## 0 to 1: the window's pop-in (0 hidden, 1 in place).
var pop := 1.0:
	set(value):
		pop = clampf(value, 0.0, 1.0)
		queue_redraw()
## Draw the cursor at all (a still terminal, or none, for C40's turns).
var cursor_on := true

## The lines, oldest first: each {"text": String, "attrs": PackedStringArray}, one attr a character: a palette
## colour's name, "*" after it for bold.
var _lines: Array = [{"text": "", "attrs": PackedStringArray()}]
var _since_key := 0.0
var _blink_shown := true


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	clip_contents = true


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	resized.connect(queue_redraw)


## The terminal's two fonts (regular and bold), made once.
static func fonts() -> Array[Font]:
	if _font == null:
		_font = _make_font(400)
		_bold = _make_font(700)
	return [_font, _bold]


static func _make_font(weight: int) -> SystemFont:
	var font := SystemFont.new()
	font.font_names = PackedStringArray(FONT_NAMES)
	font.font_weight = weight
	font.antialiasing = TextServer.FONT_ANTIALIASING_GRAY
	font.hinting = TextServer.HINTING_LIGHT
	font.subpixel_positioning = TextServer.SUBPIXEL_POSITIONING_DISABLED
	font.allow_system_fallback = true
	return font


# --- Writing. ---

## `ch` at the cursor, in colour `attr` (a palette colour's name, "*" after it for bold).
func put(ch: String, attr: String = "foreground") -> void:
	var line: Dictionary = _lines[-1]
	line["text"] += ch
	var attrs: PackedStringArray = line["attrs"]  # a copy: a packed array is a value, so it is stored back
	attrs.append(attr)
	line["attrs"] = attrs
	_keyed()


## The character before the cursor taken back: the whole of its cluster (a letter and its marks, an emoji and what
## is joined to it).
func back() -> void:
	var line: Dictionary = _lines[-1]
	var text: String = line["text"]
	if text.is_empty():
		return
	var widths := CellWidth.of_text(text)
	var keep := text.length() - 1
	while keep > 0 and widths[keep] == 0:
		keep -= 1
	line["text"] = text.left(keep)
	var attrs: PackedStringArray = line["attrs"]
	attrs.resize(keep)
	line["attrs"] = attrs
	_keyed()


## The cursor to the start of a new line.
func newline() -> void:
	_lines.append({"text": "", "attrs": PackedStringArray()})
	queue_redraw()


## A whole line printed at once, in one colour, on a line of its own (a new one if the cursor's has text), and the
## cursor on to the next. Its line's index (for set_line).
func print_line(text: String, attr: String = "foreground") -> int:
	if not (_lines[-1]["text"] as String).is_empty():
		_lines.append({"text": "", "attrs": PackedStringArray()})
	var attrs := PackedStringArray()
	attrs.resize(text.length())
	attrs.fill(attr)
	_lines[-1] = {"text": text, "attrs": attrs}
	newline()
	return _lines.size() - 2


## Line `index` (see line_count) rewritten in place, in one colour: the uptime ticking.
func set_line(index: int, text: String, attr: String = "foreground") -> void:
	if index < 0 or index >= _lines.size():
		return
	var attrs := PackedStringArray()
	attrs.resize(text.length())
	attrs.fill(attr)
	_lines[index] = {"text": text, "attrs": attrs}
	queue_redraw()


## Everything cleared, the cursor top left.
func clear() -> void:
	_lines = [{"text": "", "attrs": PackedStringArray()}]
	queue_redraw()


func line_count() -> int:
	return _lines.size()


## The text of line `index`.
func line_text(index: int) -> String:
	return _lines[index]["text"] if index >= 0 and index < _lines.size() else ""


## The colour name of character `at` on line `index` ("" past its end).
func attr_at(index: int, at: int) -> String:
	if index < 0 or index >= _lines.size():
		return ""
	var attrs: PackedStringArray = _lines[index]["attrs"]
	return attrs[at] if at >= 0 and at < attrs.size() else ""


## Every line ever written, joined by line breaks.
func all_text() -> String:
	var out := PackedStringArray()
	for line in _lines:
		out.append(line["text"])
	return "\n".join(out)


## What is on screen now: the last ROWS rows, wrapped as drawn, joined by line breaks.
func text() -> String:
	var out := PackedStringArray()
	for row in _visible_rows():
		out.append(row["text"])
	return "\n".join(out)


## Where the cursor is drawn: its column (in cells) and its row on screen.
func cursor_cell() -> Vector2i:
	var rows := _visible_rows()
	return Vector2i(rows[-1]["used"], rows.size() - 1) if not rows.is_empty() else Vector2i.ZERO


## The cells each row on screen takes now, top to bottom.
func row_cells() -> PackedInt32Array:
	var out := PackedInt32Array()
	for row in _visible_rows():
		out.append(row["used"])
	return out


## Whether the cursor is drawn this frame.
func cursor_showing() -> bool:
	return cursor_on and pop > 0.0 and (_since_key < SOLID_S or _blink_shown)


func _keyed() -> void:
	_since_key = 0.0
	_blink_shown = true
	queue_redraw()


func _process(delta: float) -> void:
	var was := cursor_showing()
	_since_key += delta
	if _since_key >= SOLID_S:
		_blink_shown = fmod(_since_key - SOLID_S, BLINK_S * 2.0) >= BLINK_S
	if cursor_showing() != was:
		queue_redraw()


# --- The layout. ---

## How much bigger than at 1080 lines.
func scale_k() -> float:
	return maxf(size.y, 1.0) / 1080.0


## The terminal window on the desktop, border included, before any pop.
func window_rect() -> Rect2:
	var gap := roundf(GAP_PX * scale_k())
	return Rect2(Vector2(gap, gap), size - Vector2(gap, gap) * 2.0)


func border_px() -> float:
	return maxf(1.0, roundf(BORDER_PX * scale_k()))


func padding_px() -> float:
	return roundf(PADDING_PX * scale_k())


## The text area inside the border and the padding.
func text_rect() -> Rect2:
	var inset := border_px() + padding_px()
	return window_rect().grow(-inset)


## A row's height, whole pixels.
func line_px() -> int:
	return maxi(int(floor(text_rect().size.y / ROWS)), 4)


## The font size that fills a row at LINE_SPACING.
func font_px() -> int:
	return maxi(int(floor(line_px() / LINE_SPACING)), 4)


## A cell's width, whole pixels, from the font's own advance.
func cell_px() -> int:
	return maxi(int(roundf(fonts()[0].get_char_size("M".unicode_at(0), font_px()).x)), 2)


## Columns that fit a row.
func columns() -> int:
	return maxi(int(floor(text_rect().size.x / cell_px())), 8)


## The colours as drawn, by role, for the checks.
func colors() -> Dictionary:
	return {"desktop": _c("darker_background"), "border": _c("accent"), "background": _c("background"), "foreground": _c("foreground"), "cursor": _cursor_color()}


func _c(key: String) -> Color:
	return palette.color(key) if palette != null else Color.BLACK


func _cursor_color() -> Color:
	return palette.cursor() if palette != null else Color.WHITE


## The rows as drawn: every line laid out in rows of columns() cells, the last ROWS of them. Each row is {"text",
## "attrs", "cells" (each character's width), "used" (the cells it fills)}.
func _visible_rows() -> Array:
	var cols := columns()
	var rows: Array = []
	for n in _lines.size():
		var text: String = _lines[n]["text"]
		var attrs: PackedStringArray = _lines[n]["attrs"]
		var widths := CellWidth.of_text(text)
		var start := 0
		var used := 0
		for i in text.length():
			if widths[i] > 0 and used > 0 and used + widths[i] > cols:
				rows.append(_row(text, attrs, widths, start, i, used))
				start = i
				used = 0
			used += widths[i]
		rows.append(_row(text, attrs, widths, start, text.length(), used))
		if used >= cols and n == _lines.size() - 1:
			rows.append(_row("", PackedStringArray(), PackedByteArray(), 0, 0, 0))  # a full last row: the cursor waits on the next
	return rows.slice(maxi(rows.size() - ROWS, 0))


static func _row(text: String, attrs: PackedStringArray, widths: PackedByteArray, from: int, to: int, used: int) -> Dictionary:
	return {"text": text.substr(from, to - from), "attrs": attrs.slice(from, to), "cells": widths.slice(from, to), "used": used}


func _draw() -> void:
	if palette == null:
		return
	if pop <= 0.0:
		return
	var fade := clampf(pop * 1.4, 0.0, 1.0)
	draw_rect(Rect2(Vector2.ZERO, size), Color(_c("darker_background"), fade))
	var window := window_rect()
	var mid := window.get_center()
	var s := lerpf(POP_FROM, 1.0, pop)
	draw_set_transform(mid * (1.0 - s), 0.0, Vector2(s, s))
	var border := border_px()
	draw_rect(window, Color(_c("accent"), fade))
	draw_rect(window.grow(-border), Color(_c("background"), fade))
	var area := text_rect()
	var cell := cell_px()
	var line := line_px()
	var size_px := font_px()
	var f := fonts()
	var base := roundf(line * 0.5 + size_px * BASELINE)
	var rows := _visible_rows()
	for r in rows.size():
		var row: Dictionary = rows[r]
		var text: String = row["text"]
		var attrs: PackedStringArray = row["attrs"]
		var cells: PackedByteArray = row["cells"]
		var y := area.position.y + r * line + base
		var col := 0
		var i := 0
		while i < text.length():
			var end := i + 1
			while end < text.length() and cells[end] == 0:
				end += 1
			var wide: int = maxi(cells[i], 1)
			var attr: String = attrs[i] if i < attrs.size() else "foreground"
			var font := f[1] if attr.ends_with("*") else f[0]
			var tint := Color(_c(attr.trim_suffix("*")), fade)
			var x := area.position.x + col * cell
			if end == i + 1 and wide == 1:
				if text[i] != " ":
					draw_char(font, Vector2(x, y), text[i], size_px, tint)
			else:
				var cluster := text.substr(i, end - i)
				var fit := _fit_size(font, cluster, size_px, wide * cell)
				var drawn := font.get_string_size(cluster, HORIZONTAL_ALIGNMENT_LEFT, -1, fit).x
				draw_string(font, Vector2(x + maxf((wide * cell - drawn) * 0.5, 0.0), y), cluster, HORIZONTAL_ALIGNMENT_LEFT, -1, fit, tint)
			col += wide
			i = end
	if cursor_showing() and not rows.is_empty():
		var col: int = rows[-1]["used"]
		var at := Vector2(area.position.x + col * cell, area.position.y + (rows.size() - 1) * line)
		draw_rect(Rect2(at, Vector2(cell, line)), Color(_cursor_color(), fade))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


## The font size `cluster` is drawn at so it is no wider than `room` pixels: `size_px`, or smaller.
static func _fit_size(font: Font, cluster: String, size_px: int, room: float) -> int:
	var key := "%d|%d|%s" % [font.get_instance_id(), size_px, cluster]
	if not _fit_sizes.has(key):
		if _fit_sizes.size() > 512:
			_fit_sizes.clear()
		var wide := font.get_string_size(cluster, HORIZONTAL_ALIGNMENT_LEFT, -1, size_px).x
		_fit_sizes[key] = size_px if wide <= room else maxi(int(floor(size_px * room / wide)), 4)
	return _fit_sizes[key]
