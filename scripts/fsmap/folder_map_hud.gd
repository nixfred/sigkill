class_name FolderMapHud
extends CanvasLayer
## The folder map's HUD (W2): a panel where a mission's would stand. The folder it stands in (its path from home), its
## size, how many files stand in it and how many folders under it, what most of it is and the register that makes,
## the daemons still standing, its doors biggest first (and how many more past the cap), and the last few `cd`s; in the
## maze, its depth, the steps to the way out and the ways down. With the Audit Trail visor on, a breadcrumb across the
## top: every folder from home to here with its size (names only; home is "home"). Under the HUD's own layer, so the
## Esc menu covers it. Draws only what the map says; reads nothing.

const Palette = preload("res://scripts/palette.gd")
const PANEL_AT := Vector2(16, 98)
const PANEL_W := 392.0
const DOORS_SHOWN := 5
const DOORS_COMPACT := 2
const COMPACT_W := 1280.0
const COMPACT_CLEAR := 230.0
const LINE := 17.0
const ALPHA := 0.8
const TITLE := "FOLDER MAP"
const MAZE_TITLE := "NODE_MODULES"
const DEMO := "demo tree"
const REAL := "your home, read only"
const REGISTER_WORDS := {"tron": "Tron", "cyberpunk": "the ruins", "matrix": "the Matrix"}

var map: FolderMap = null
var _view: Control
var _font: Font


func _ready() -> void:
	layer = 0
	_font = Palette.mono_font()
	_view = Control.new()
	_view.name = "FolderMapView"
	_view.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_view.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_view.draw.connect(_draw_view)
	add_child(_view)


func _process(_delta: float) -> void:
	_view.queue_redraw()


## Every line the panel shows now, for the checks.
func lines() -> PackedStringArray:
	var out := PackedStringArray()
	if map == null or not map.running:
		return out
	var real := FolderMap.layer == "real"
	out.append((MAZE_TITLE if map.maze != null else TITLE) + "  " + (REAL if real else DEMO))
	out.append(FolderTree.path_text(FolderMap.path))
	if map.waiting:
		out.append("reading %s ..." % FolderTree.path_text(map._wait[0] if not map._wait.is_empty() else FolderMap.path))
		return out
	var n := map.room
	if n.is_empty():
		return out
	var more := ">=" if bool(n.get("partial", false)) else ""
	if map.maze != null:
		out.append("depth %d   %s%s in %s files" % [FolderMap.level, more, FolderTree.human_size(int(n.get("size", 0))), FolderTree.thousands(int(n.get("files", 0)))])
		var here := map.world.layout.cell_at(map.world.to_local(map.player.global_position)) if map.player != null and is_instance_valid(map.player) else map.maze.start
		var steps := int(map.maze_out.get(here, -1))
		out.append("the way out: %s   ways down: %d" % ["%d cells" % steps if steps >= 0 else "?", map.maze.pits.size()])
	else:
		out.append("%s%s   %s files here   %d folders" % [more, FolderTree.human_size(int(n.get("size", 0))), FolderTree.thousands(int(n.get("own_files", 0))), (n.get("dirs", []) as Array).size() + int(n.get("more", 0))])
		var kind := FolderTree.kind_of(n)
		out.append("%s: %s" % [kind.to_upper(), REGISTER_WORDS.get(FolderRooms.REGISTER_OF.get(kind, "tron"), "Tron")])
	out.append("daemons %d of %d" % [map.standing(), map.enemies.size()])
	return out


func door_lines(most: int) -> PackedStringArray:
	var out := PackedStringArray()
	if map == null or map.maze != null:
		return out
	for e in map.doors:
		if int(e["index"]) < 0 or out.size() >= most:
			continue
		var c: Dictionary = e["child"]
		out.append("%-16s %9s" % [str(e["name"]).left(16), FolderTree.human_size(int(c.get("size", 0)))])
	var extra := (map.room.get("dirs", []) as Array).size() - FolderRooms.DOORS_MOST + int(map.room.get("more", 0))
	if extra > 0:
		out.append("+%d more not shown" % extra)
	return out


## The visor's breadcrumb (W2): "home 312 GB > Code 9.1 GB > starfall 1.2 GB", "" while the visor is off.
func breadcrumb_text() -> String:
	if map == null or not map.running or map.visor == null or not is_instance_valid(map.visor) or not bool(map.visor.get("on")):
		return ""
	var parts := PackedStringArray()
	for b in map.breadcrumb():
		parts.append("%s %s" % [b[0], FolderTree.human_size(int(b[1]))])
	if map.maze != null:
		parts.append("depth %d" % FolderMap.level)
	return "  >  ".join(parts)


## The breadcrumb as it fits `room` pixels at `size`: whole; else the sizes dropped but the last; else the oldest folders
## dropped behind a "...". "" while the visor is off.
func fit_breadcrumb(room: float, size: int) -> String:
	var whole := breadcrumb_text()
	if whole == "" or _font.get_string_size(whole, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x <= room:
		return whole
	var parts := PackedStringArray()
	var crumbs := map.breadcrumb()
	for i in crumbs.size():
		parts.append(str(crumbs[i][0]) if i < crumbs.size() - 1 else "%s %s" % [crumbs[i][0], FolderTree.human_size(int(crumbs[i][1]))])
	if map.maze != null:
		parts.append("depth %d" % FolderMap.level)
	var text := "  >  ".join(parts)
	while parts.size() > 2 and _font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x > room:
		parts.remove_at(0)
		text = "...  >  " + "  >  ".join(parts)
	return text


func _draw_view() -> void:
	if map == null or not map.running:
		return
	var v := _view
	var real := FolderMap.layer == "real"
	var compact := v.size.x < COMPACT_W
	var main := lines()
	var door := door_lines(DOORS_COMPACT if compact else DOORS_SHOWN)
	var notes: Array = map.events.slice(maxi(map.events.size() - (1 if compact else 3), 0))
	var accent: Color = Palette.HOSTILE_AMBER if map.maze != null else Palette.TEAL
	var h := 30.0 + LINE * (main.size()) + (12.0 + LINE * door.size() if not door.is_empty() else 0.0) + 10.0 + LINE * notes.size() + 14.0
	var rect := Rect2(PANEL_AT, Vector2(PANEL_W, h))
	v.draw_rect(rect, Color(Palette.VOID, ALPHA))
	v.draw_rect(Rect2(rect.position, Vector2(3, h)), accent)
	var scan := fposmod(map.clock() * 0.35, 1.0)
	v.draw_rect(Rect2(rect.position + Vector2(3, h * scan), Vector2(PANEL_W - 3, 1)), Color(accent, 0.12))
	var x := PANEL_AT.x + 14.0
	var y := PANEL_AT.y + 24.0
	v.draw_string(_font, Vector2(x, y), MAZE_TITLE if map.maze != null else TITLE, HORIZONTAL_ALIGNMENT_LEFT, -1, 18, accent)
	var chip := REAL if real else DEMO
	var chip_c := Palette.HOSTILE_AMBER if real else Palette.MINT
	var cw := _font.get_string_size(chip, HORIZONTAL_ALIGNMENT_LEFT, -1, 12).x + 12.0
	var cx := PANEL_AT.x + PANEL_W - cw - 12.0
	v.draw_rect(Rect2(cx, y - 13, cw, 16), Color(chip_c, 0.16))
	v.draw_rect(Rect2(cx, y - 13, cw, 16), chip_c, false, 1.0)
	v.draw_string(_font, Vector2(cx + 6, y), chip, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, chip_c)
	for i in range(1, main.size()):
		y += LINE
		var colour := Palette.FLASH if i == 1 else Palette.MINT
		v.draw_string(_font, Vector2(x, y), main[i], HORIZONTAL_ALIGNMENT_LEFT, PANEL_W - 24, 14 if i == 1 else 13, colour)
	if not door.is_empty():
		y += 10.0
		v.draw_rect(Rect2(x, y, PANEL_W - 28, 1), Color(accent, 0.45))
		for line in door:
			y += LINE
			v.draw_string(_font, Vector2(x, y), line, HORIZONTAL_ALIGNMENT_LEFT, PANEL_W - 24, 13, Color(Palette.TEAL, 0.95))
	y += 10.0
	v.draw_rect(Rect2(x, y, PANEL_W - 28, 1), Color(accent, 0.3))
	for e in notes:
		y += LINE
		var age: float = map.clock() - float(e["t"])
		v.draw_string(_font, Vector2(x, y), str(e["text"]), HORIZONTAL_ALIGNMENT_LEFT, PANEL_W - 24, 12, Color(Palette.MINT, clampf(1.2 - age / 12.0, 0.4, 1.0)))
	# The visor's breadcrumb, across the top under the visor's own header (in a small window, at the bottom over the key
	# hints, clear of the panel; shortened to fit: the sizes dropped but the last, then the oldest folders).
	var size := 18 if not compact else 13
	# In a small window it keeps clear of the weapons' panel at the bottom right (COMPACT_CLEAR wide).
	var crumb := fit_breadcrumb(v.size.x - 48.0 if not compact else v.size.x - COMPACT_CLEAR * 2.0, size)
	if crumb != "":
		var w := _font.get_string_size(crumb, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
		var at := Vector2(maxf((v.size.x - w) * 0.5, 12.0), 92.0) if not compact else Vector2(maxf(v.size.x - COMPACT_CLEAR - w, 12.0), v.size.y - 64.0)
		v.draw_rect(Rect2(at.x - 12, at.y - size - 4, minf(w + 24, v.size.x - 2.0 * at.x + 24.0), size + 12), Color(Palette.VOID, 0.7))
		v.draw_rect(Rect2(at.x - 12, at.y + 7, minf(w + 24, v.size.x - 2.0 * at.x + 24.0), 2), Color(Palette.HOSTILE_AMBER, 0.85))
		v.draw_string(_font, at, crumb, HORIZONTAL_ALIGNMENT_LEFT, v.size.x - at.x - 12.0, size, Palette.HOSTILE_AMBER.lerp(Color.WHITE, 0.25))
