class_name ArenaArt
extends Node3D
## The arena's dressing (A3): trims, bevels, ribs, rails and light strips on every greybox block,
## stepped edges round the raised platform, props (server racks, cable runs, vents, terminal screens,
## data conduits, floating ">_" glyph pylons), terminal-style signs, and the stepped plinth the arena
## stands on with its parapets, corner towers and masts. Original and procedural: shapes from the
## shared shape kit (scripts/art/shape_kit.gd), letters from scripts/arena/arena_font.gd, every look
## from the arena shaders; no model, texture or font file.
##
## Visual only: no node of it collides, so the greybox blocks stay the whole of the arena's collision,
## byte for byte. Nothing mounted on a wall stands out from it further than WALL_DEPTH_MAX, less than a
## player's radius, so a player's eyes never enter it; nothing above the floor that a player can walk
## under hangs lower than a jump can reach.
##
## Built once when it enters the tree, from the blocks beside it and the layout below, and merged: one
## mesh of solid parts (a surface per material, throwing shadows), one of light (strips, signs, flow,
## beacons, screens and racks; no shadows), and the holograms one MultiMesh. The result is kept for
## the next arena with the same blocks, so a reload builds nothing. Nothing is rebuilt while it is
## drawn: the strips breathe, the screens scroll, the conduits flow and the glyphs turn in their
## shaders.

const Palette = preload("res://scripts/palette.gd")
const SignFont = preload("res://scripts/arena/arena_font.gd")
const GreyBlock = preload("res://scripts/grey_block.gd")

## Budgets (A3), checked by tests/arena_art_test.gd. Draw calls: a surface each, one more for each
## surface of the shadow-throwing mesh, and one for the holograms.
const BUDGET_TRIANGLES := 32000
const BUDGET_DRAW_CALLS := 16
## Bumped whenever the layout below changes, so a kept build is never reused for a different one.
const LAYOUT_VERSION := 2

## Blocks lower than this can be stood on: their tops get a lip under the edge, never a crown that
## would rise above a player's feet.
const WALKABLE_BELOW := 2.5
## The deepest anything mounted on a wall stands out from it, in metres: under a player's radius.
const WALL_DEPTH_MAX := 0.3
## Trims, in metres.
const KICK_H := 0.16
const KICK_OUT := 0.03
const CROWN_H := 0.14
const CROWN_OUT := 0.06
const LIP_H := 0.08
const LIP_OUT := 0.035
const CORNER := 0.07
const RIB_SPACING := 2.6
const RIB_W := 0.16
const RIB_OUT := 0.06
const RAIL_Y := 1.15
const RAIL_H := 0.05
const RAIL_OUT := 0.025
const STRIP_H := 0.022
const STRIP_OUT := 0.035
const FRAME_W := 0.035
const FRAME_OUT := 0.012
## A face narrower than this gets a single upright strip instead of ribs and rails.
const NARROW := 1.2
## A face this wide or wider gets an inset frame in each panel above its rail.
const FRAMED := 6.0
## How far screens, signs and vents stand off a wall: clear of its ribs.
const MOUNT_OUT := 0.07
## A sign's lamp (A4): how far under the sign and out from the wall it hangs.
const LAMP_DOWN_M := 0.3
const LAMP_OUT_M := 0.8

## Where the hostile side lives: strips facing into it burn red instead of mint (the north room,
## the rogue daemon's lair).
@export var lair := AABB(Vector3(-8.0, 0.0, -20.0), Vector3(16.0, 4.0, 12.0))

## The shape kit's buckets, made in this order so each one's id is its name here.
enum { PANEL, DARK, TEAL, MINT, RED, FLOW, BEACON, SCREEN, RACK, WARM, BUCKETS }
## The buckets of each mesh, in surface order.
const SOLID := [PANEL, DARK]
const GLOW := [TEAL, MINT, RED, FLOW, BEACON, SCREEN, RACK, WARM]
## The arena's shared shader clock (A4): wrapped as the shaders' ticks always were.
const SHADER_CLOCK := &"arena_clock"
const CLOCK_WRAP := 1024.0
## The lair's two danger lights (A4): how far in from its sides and down from its top.
const DANGER_IN_M := 4.0
const DANGER_DOWN_M := 0.8

## Builds kept for the next arena with the same blocks: layout key -> {solid, glow, holo, dressed, signs}.
static var _kept: Dictionary = {}
static var _holo_mesh: ArrayMesh

var _kit: ShapeKit
var _holo: Array = []  # [Transform3D, phase] per hologram
var _dressed := PackedStringArray()
var _signs := PackedStringArray()
var _floor_half := Vector2.INF  # half the floor's size: a face beyond it looks out of the arena
var _solid: MeshInstance3D
var _glow: MeshInstance3D
var _holograms: MultiMeshInstance3D
var _fresh := false
## The lamps by the big signs (A4): [where, which way the sign faces] per lamp, in the dressing's space.
var _lamps: Array = []
var _lamp_nodes: Array[OmniLight3D] = []
var _danger_nodes: Array[OmniLight3D] = []
static var _clock := 0.0
static var _clock_frame := -1


func _ready() -> void:
	var key := _layout_key()
	var built: Dictionary = _kept.get(key, {})
	_fresh = built.is_empty()
	if _fresh:
		built = _build()
		_kept[key] = built
	_dressed = built["dressed"]
	_signs = built["signs"]
	_show(built)


## Steps the arena's shader clock (A4), once a frame at the game's pace, so SIGSTOP slows the
## strips' waves, the beacons, the screens and the holograms; and pulses the lair's danger lights on
## it. Makes nothing.
func _process(delta: float) -> void:
	step_clock(delta)
	var glow := 1.0 + Palette.DANGER_PULSE * sin(_clock * Palette.DANGER_PULSE_HZ * TAU)
	for light in _danger_nodes:
		light.light_energy = Palette.DANGER_LIGHT_ENERGY * glow


## The arena's shader clock: stepped once a frame by whichever dressing is drawn first.
static func step_clock(delta: float) -> void:
	var frame := Engine.get_process_frames()
	if frame == _clock_frame:
		return
	_clock_frame = frame
	_clock = fmod(_clock + delta, CLOCK_WRAP)
	RenderingServer.global_shader_parameter_set(SHADER_CLOCK, _clock)


static func clock() -> float:
	return _clock


## The warm lamps by the big signs and the lair's two danger lights (A4), for the checks.
func lamp_lights() -> Array[OmniLight3D]:
	return _lamp_nodes


func danger_lights() -> Array[OmniLight3D]:
	return _danger_nodes


## The solid parts' node, the light's and the holograms', for the checks.
func solid_node() -> MeshInstance3D:
	return _solid


func glow_node() -> MeshInstance3D:
	return _glow


func holo_node() -> MultiMeshInstance3D:
	return _holograms


## The blocks it dressed, by name.
func dressed() -> PackedStringArray:
	return _dressed


## Every sign's text.
func signs() -> PackedStringArray:
	return _signs


## True when this arena built its dressing, false when it took a kept one.
func built_fresh() -> bool:
	return _fresh


## Triangles in the whole dressing: its budget.
func triangles() -> int:
	var total := 0
	for node in [_solid, _glow]:
		var m := (node as MeshInstance3D).mesh as ArrayMesh
		for s in m.get_surface_count():
			total += m.surface_get_array_len(s) / 3
	var mm := _holograms.multimesh
	total += mm.instance_count * _holo_triangles()
	return total


## Draw calls for the whole dressing: a surface each, one more for each surface that throws a
## shadow, and the holograms one.
func draw_calls() -> int:
	var total := 0
	for node in [_solid, _glow]:
		var mi := node as MeshInstance3D
		var surfaces := mi.mesh.get_surface_count()
		total += surfaces
		if mi.cast_shadow != GeometryInstance3D.SHADOW_CASTING_SETTING_OFF:
			total += surfaces
	return total + 1


static func _holo_triangles() -> int:
	return _holo_mesh.surface_get_array_len(0) / 3 if _holo_mesh != null else 0


## A key for this arena's layout: its blocks' names, kinds, sizes and places, and the layout version.
func _layout_key() -> String:
	var parts := PackedStringArray([str(LAYOUT_VERSION), var_to_str(lair)])
	for b in _blocks():
		parts.append("%s|%d|%s|%s" % [b.name, b.kind, var_to_str(b.size), var_to_str(_to_art(b))])
	return "\n".join(parts)


## The greybox blocks beside it: its parent's children with a size and a kind.
func _blocks() -> Array:
	var out := []
	var parent := get_parent()
	if parent == null:
		return out
	for child in parent.get_children():
		if child is GreyBlock:
			out.append(child)
	return out


## A block's transform in the dressing's own space.
func _to_art(b: Node3D) -> Transform3D:
	return transform.affine_inverse() * b.transform


# --- The build. ---

func _build() -> Dictionary:
	_kit = ShapeKit.new()
	_holo.clear()
	_dressed = PackedStringArray()
	_signs = PackedStringArray()
	_lamps = []
	for id in BUCKETS:
		_kit.bucket(Vector3.ZERO, id in SOLID)
	var mounts := {}
	_floor_half = Vector2.INF
	for b in _blocks():
		if b.kind == Palette.Surface.FLOOR:
			_floor_half = Vector2(b.size.x, b.size.z) * 0.5
	for b in _blocks():
		mounts[String(b.name)] = b
		if b.kind != Palette.Surface.FLOOR:
			_dress_block(b)
			_dressed.append(b.name)
	_kit.pose = Transform3D.IDENTITY
	_props(mounts)
	_outside(mounts)
	_signage(mounts)
	return {"solid": _merge(SOLID), "glow": _merge(GLOW), "holo": _holo_multimesh(), "dressed": _dressed, "signs": _signs, "lamps": _lamps}


func _merge(ids: Array) -> ArrayMesh:
	var mesh := ArrayMesh.new()
	for id in ids:
		if _kit.count(id) > 0:
			_kit.commit(id, mesh)
			mesh.surface_set_material(mesh.get_surface_count() - 1, _material(id))
	return mesh


static func _material(id: int) -> Material:
	match id:
		PANEL:
			return Palette.arena_panel_material()
		DARK:
			return Palette.arena_panel_material(true)
		TEAL:
			return Palette.arena_light_material("teal")
		MINT:
			return Palette.arena_light_material("mint")
		RED:
			return Palette.arena_light_material("red")
		FLOW:
			return Palette.arena_light_material("flow")
		BEACON:
			return Palette.arena_light_material("beacon")
		WARM:
			return Palette.arena_light_material("warm")
		SCREEN:
			return Palette.arena_screen_material()
		_:
			return Palette.arena_screen_material(true)


func _holo_multimesh() -> MultiMesh:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_custom_data = true
	mm.mesh = _holo_glyph()
	mm.instance_count = _holo.size()
	for i in _holo.size():
		mm.set_instance_transform(i, _holo[i][0])
		mm.set_instance_custom_data(i, Color(_holo[i][1], 0.0, 0.0, 0.0))
	return mm


## The ">_" every hologram shows: the sign font's pixels as small blocks, centred on its pivot.
static func _holo_glyph() -> ArrayMesh:
	if _holo_mesh != null:
		return _holo_mesh
	var kit := ShapeKit.new()
	var id := kit.bucket()
	var px := 0.11
	var text := ">_"
	var w := SignFont.width(text) * px
	var h := SignFont.ROWS * px
	for run in SignFont.runs(text):
		var x0: float = -w * 0.5 + run[0] * px
		var y0: float = h * 0.5 - (run[1] + 1) * px
		kit.box(id, Vector3(x0 + run[2] * px * 0.5, y0 + px * 0.5, 0.0), Vector3(run[2] * px * 0.92, px * 0.92, px))
	_holo_mesh = kit.commit(id)
	return _holo_mesh


func _show(built: Dictionary) -> void:
	_solid = MeshInstance3D.new()
	_solid.name = "Solid"
	_solid.mesh = built["solid"]
	_solid.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	add_child(_solid)
	_glow = MeshInstance3D.new()
	_glow.name = "Glow"
	_glow.mesh = built["glow"]
	_glow.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_glow)
	_holograms = MultiMeshInstance3D.new()
	_holograms.name = "Holograms"
	_holograms.multimesh = built["holo"]
	_holograms.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_holograms.material_override = Palette.arena_holo_material()
	add_child(_holograms)
	# Light (A4): a warm lamp before each big sign, lighting it and the floor under it, and two red
	# danger lights in the lair, pulsing slowly. No shadows: a few clustered lights cost little.
	_lamp_nodes.clear()
	for lamp in built["lamps"]:
		_lamp_nodes.append(_light("SignLamp", lamp[0], Palette.SODIUM, Palette.SIGN_LAMP_ENERGY, Palette.SIGN_LAMP_RANGE_M))
	_danger_nodes.clear()
	var top := lair.position.y + lair.size.y - DANGER_DOWN_M
	var mid := lair.get_center()
	for side in [-1.0, 1.0]:
		var at := Vector3(mid.x + side * (lair.size.x * 0.5 - DANGER_IN_M), top, mid.z)
		_danger_nodes.append(_light("DangerLight", at, Palette.HOSTILE_RED, Palette.DANGER_LIGHT_ENERGY, Palette.DANGER_LIGHT_RANGE_M))


func _light(node_name: String, at: Vector3, color: Color, energy: float, reach: float) -> OmniLight3D:
	var light := OmniLight3D.new()
	light.name = node_name
	light.position = at
	light.light_color = color
	light.light_energy = energy
	light.omni_range = reach
	light.omni_attenuation = 1.6
	light.shadow_enabled = false
	light.light_specular = 0.6
	add_child(light)
	return light


# --- The blocks. ---

## One block's trims, in its own space through the kit's pose: a kick plate at its foot (two steps
## round a raised slab); a bevelled crown on top of a tall one, a lip under the edge of one that can be
## stood on; chamfered corner guards; and each side dressed by _dress_face.
func _dress_block(b: GreyBlock) -> void:
	var xf := _to_art(b)
	_kit.pose = xf
	var s: Vector3 = b.size
	var h := s * 0.5
	var tall := s.y >= WALKABLE_BELOW
	var slab: bool = b.kind == Palette.Surface.ACCENT and not tall and s.x >= 3.0 and s.z >= 3.0
	if slab:
		# Stepped edges: two steps round its foot, each shallower than a player's radius.
		for step in [[0.27, 0.0], [0.135, 0.25]]:
			var out: float = step[0]
			var y: float = -h.y + step[1]
			_kit.box(PANEL, Vector3(0.0, y + 0.125, 0.0), Vector3(s.x + 2.0 * out, 0.25, s.z + 2.0 * out))
			_ring_strip(TEAL, Vector3(0.0, y + 0.22, 0.0), Vector2(s.x + 2.0 * out + 0.03, s.z + 2.0 * out + 0.03))
	else:
		_kit.box(PANEL, Vector3(0.0, -h.y + KICK_H * 0.5, 0.0), Vector3(s.x + 2.0 * KICK_OUT, KICK_H, s.z + 2.0 * KICK_OUT))
	if tall:
		_kit.frustum(PANEL, Vector3(0.0, h.y, 0.0), Vector2(s.x + 2.0 * CROWN_OUT, s.z + 2.0 * CROWN_OUT), Vector2(s.x + 0.02, s.z + 0.02), CROWN_H)
	else:
		_kit.box(PANEL, Vector3(0.0, h.y - LIP_H * 0.5 - 0.004, 0.0), Vector3(s.x + 2.0 * LIP_OUT, LIP_H, s.z + 2.0 * LIP_OUT))
	var foot := -h.y + (0.5 if slab else KICK_H)
	var head := h.y - (0.0 if tall else LIP_H)
	for cx in [-1.0, 1.0]:
		for cz in [-1.0, 1.0]:
			_kit.box(PANEL, Vector3(cx * h.x, (foot + head) * 0.5, cz * h.z), Vector3(CORNER, head - foot, CORNER), Vector3(0.0, 45.0, 0.0))
	for side in [Vector3.FORWARD, Vector3.BACK, Vector3.LEFT, Vector3.RIGHT]:
		var n: Vector3 = side
		var u := Vector3.UP.cross(n)
		_dress_face(b, xf, n, u, absf(u.dot(s)), absf(n.dot(h)), h, tall, foot, head)


## One side of a block: ribs every RIB_SPACING or so with panels between, a rail at waist height on
## a tall one, an inset frame in each panel above it on a wide one, a teal strip low in each panel and
## a mint one high (red where it faces into the lair). A narrow side gets one upright strip instead; a
## crate's side a frame and a brace.
func _dress_face(b: GreyBlock, xf: Transform3D, n: Vector3, u: Vector3, w: float, d: float, h: Vector3, tall: bool, foot: float, head: float) -> void:
	var across := u.abs()
	var out := n.abs()
	var up := Vector3.UP
	if b.kind == Palette.Surface.CRATE:
		var inner_w := w - 0.14
		var inner_h := head - foot - 0.12
		var at := n * (d + FRAME_OUT * 0.5)
		_frame(at, u, 0.0, inner_w, foot + 0.06, head - 0.06, across, out)
		var length := sqrt(inner_w * inner_w + inner_h * inner_h)
		var deg := rad_to_deg(atan2(inner_h, inner_w))
		var c := at + up * ((foot + head) * 0.5)
		if absf(n.z) > 0.5:
			_kit.box(PANEL, c, Vector3(length, FRAME_W, FRAME_OUT), Vector3(0.0, 0.0, deg))
		else:
			_kit.box(PANEL, c, Vector3(FRAME_OUT, FRAME_W, length), Vector3(deg, 0.0, 0.0))
		return
	if w < NARROW:
		var strip := MINT if b.kind == Palette.Surface.ACCENT else TEAL
		_kit.box(strip, n * (d + STRIP_OUT * 0.5) + up * ((foot + head) * 0.5), across * 0.03 + out * STRIP_OUT + up * (head - foot - 0.2))
		return
	# A face out past the floor's edge looks out of the arena, seen only from afar: no inset frames.
	var face := xf * (n * d)
	var outward := absf(face.x) > _floor_half.x or absf(face.z) > _floor_half.y
	var count := maxi(1, roundi(w / RIB_SPACING))
	var seg := w / count
	var top := head - 0.02
	for k in range(1, count):
		var along := -w * 0.5 + k * seg
		_kit.box(PANEL, n * (d + RIB_OUT * 0.5) + u * along + up * ((foot + top) * 0.5), across * RIB_W + out * RIB_OUT + up * (top - foot))
	var rail_y := -h.y + RAIL_Y
	if tall:
		_kit.box(PANEL, n * (d + RAIL_OUT * 0.5) + up * rail_y, across * (w - 0.02) + out * RAIL_OUT + up * RAIL_H)
	for k in count:
		var mid := -w * 0.5 + (k + 0.5) * seg
		var span := seg - RIB_W - 0.12
		if span <= 0.1:
			continue
		_kit.box(TEAL, n * (d + STRIP_OUT * 0.5) + u * mid + up * (foot + 0.08), across * span + out * STRIP_OUT + up * STRIP_H)
		if not tall:
			continue
		var high := head - 0.26
		var faces_lair := lair.has_point(xf * (n * (d + 1.0) + u * mid + up * high))
		_kit.box(RED if faces_lair else MINT, n * (d + STRIP_OUT * 0.5) + u * mid + up * high, across * span + out * STRIP_OUT + up * STRIP_H)
		if w >= FRAMED and not outward:
			_frame(n * (d + FRAME_OUT * 0.5), u, mid, span - 0.2, rail_y + 0.25, high - 0.2, across, out)


## A rectangular frame of four thin bars standing FRAME_OUT off a face, round the middle of the bars
## at `y0` and `y1`: an inset panel's outline.
func _frame(at: Vector3, u: Vector3, mid: float, width: float, y0: float, y1: float, across: Vector3, out: Vector3) -> void:
	if width <= 0.2 or y1 - y0 <= 0.2:
		return
	var up := Vector3.UP
	var c := at + u * mid
	_kit.box(PANEL, c + up * y0, across * width + out * FRAME_OUT + up * FRAME_W)
	_kit.box(PANEL, c + up * y1, across * width + out * FRAME_OUT + up * FRAME_W)
	for side in [-1.0, 1.0]:
		_kit.box(PANEL, c + u * (side * width * 0.5) + up * ((y0 + y1) * 0.5), across * FRAME_W + out * FRAME_OUT + up * (y1 - y0))


## A thin light strip all the way round a rectangle `size` across, at `center`.
func _ring_strip(id: int, center: Vector3, size: Vector2) -> void:
	_kit.box(id, center + Vector3(0.0, 0.0, -size.y * 0.5), Vector3(size.x, STRIP_H, 0.03))
	_kit.box(id, center + Vector3(0.0, 0.0, size.y * 0.5), Vector3(size.x, STRIP_H, 0.03))
	_kit.box(id, center + Vector3(-size.x * 0.5, 0.0, 0.0), Vector3(0.03, STRIP_H, size.y))
	_kit.box(id, center + Vector3(size.x * 0.5, 0.0, 0.0), Vector3(0.03, STRIP_H, size.y))


# --- Mounts: a block's side as a place to hang things. ---

## Side `n` (an arena axis) of block `name`, as a mount: its centre on the face, its outward normal,
## its right (seen from in front of it), its width and its height, its foot's height. Empty when the
## block is not there.
func _mount(mounts: Dictionary, name: String, n: Vector3) -> Dictionary:
	var b: GreyBlock = mounts.get(name)
	if b == null:
		return {}
	var xf := _to_art(b)
	var s: Vector3 = b.size
	var right := Vector3.UP.cross(n)
	return {"center": xf.origin + n * absf(n.dot(s * 0.5)), "n": n, "right": right, "width": absf(right.dot(s)), "height": s.y, "foot": xf.origin.y - s.y * 0.5}


## A point on mount `m`: `along` its width from its centre (to its right), `y` above the arena floor,
## `out` off its face.
static func _on(m: Dictionary, along: float, y: float, out: float = 0.0) -> Vector3:
	var c: Vector3 = m["center"]
	return Vector3(c.x, y, c.z) + (m["right"] as Vector3) * along + (m["n"] as Vector3) * out


## How far along mount `m` the arena coordinate `coord` is (x on a north or south face, z on an east
## or west one).
static func _along(m: Dictionary, coord: float) -> float:
	var r: Vector3 = m["right"]
	var c: Vector3 = m["center"]
	return (coord - c.x) * r.x + (coord - c.z) * r.z


## A box on mount `m`, `width` along it, `height` up it and `depth` out of it, its back `out` off it.
func _wall_box(id: int, m: Dictionary, along: float, y: float, width: float, height: float, depth: float, out: float = 0.0) -> void:
	var r: Vector3 = m["right"]
	var n: Vector3 = m["n"]
	_kit.box(id, _on(m, along, y, out + depth * 0.5), r.abs() * width + n.abs() * depth + Vector3.UP * height)


## A flat face on mount `m`, `out` off it and facing out of it: a screen's, a rack's or a vent's.
func _wall_face(id: int, m: Dictionary, along: float, y: float, width: float, height: float, out: float) -> void:
	var corners := []
	for c in [[-0.5, -0.5], [0.5, -0.5], [0.5, 0.5], [-0.5, 0.5]]:
		corners.append(_on(m, along + c[0] * width, y + c[1] * height, out))
	_kit.polygon(id, corners, m["n"])


# --- Props. ---

func _props(mounts: Dictionary) -> void:
	# Server racks along the back of the lair, the rogue daemon's room, either side of its middle,
	# with a screen between them; and a short row on the east wall.
	var north := _mount(mounts, "WallN", Vector3.BACK)
	if not north.is_empty():
		for i in 8:
			for side in [-1.0, 1.0]:
				_rack(north, side * (1.95 + i * 0.68))
		_screen(north, 0.0, 2.95, 1.3, 0.55)
	var east := _mount(mounts, "WallE", Vector3.LEFT)
	if not east.is_empty():
		for i in 4:
			_rack(east, _along(east, -6.6 + i * 0.68))
		_screen(east, _along(east, 11.5), 2.2, 1.7, 0.95)
		_screen(east, _along(east, -14.0), 2.2, 1.7, 0.95)
	var west := _mount(mounts, "WallW", Vector3.RIGHT)
	if not west.is_empty():
		_screen(west, _along(west, -12.5), 2.2, 1.7, 0.95)
		_screen(west, _along(west, 13.0), 2.2, 1.7, 0.95)
	var south := _mount(mounts, "WallS", Vector3.FORWARD)
	if not south.is_empty():
		_screen(south, _along(south, -9.0), 2.2, 1.7, 0.95)
		_screen(south, _along(south, 9.0), 2.2, 1.7, 0.95)
		_vent(south, 0.0, 0.6, 1.6, 0.5)
	var lair_w := _mount(mounts, "RoomSideW", Vector3.RIGHT)
	if not lair_w.is_empty():
		_screen(lair_w, _along(lair_w, -14.0), 2.0, 1.4, 0.8)
	var lair_e := _mount(mounts, "RoomSideE", Vector3.RIGHT)
	if not lair_e.is_empty():
		_vent(lair_e, _along(lair_e, -14.0), 2.3, 1.4, 0.9)
	var cover := _mount(mounts, "CoverL2", Vector3.LEFT)
	if not cover.is_empty():
		_vent(cover, 0.0, 2.2, 1.2, 0.6)
	# Cable trays along the foot of the four outer walls, inside, and bundles of cable down the walls
	# into them.
	for spec in [["WallN", Vector3.BACK], ["WallS", Vector3.FORWARD], ["WallE", Vector3.LEFT], ["WallW", Vector3.RIGHT]]:
		var m := _mount(mounts, spec[0], spec[1])
		if not m.is_empty():
			_tray(m)
			# Clear of every rack, screen and sign on all four walls (self-review pass 1).
			for coord in [-11.0, 10.5]:
				_drop(m, _along(m, coord))
	# Cables slung between the pillars' tops, and from the lair's walls to the outer walls: all higher
	# than a player's head at the top of a jump.
	_cable(Vector3(11.7, 3.96, 2.75), Vector3(11.7, 3.96, 7.25), 0.45, 0.03)
	_cable(Vector3(12.3, 3.96, 2.75), Vector3(12.3, 3.96, 7.25), 0.55, 0.025)
	_cable(Vector3(8.2, 3.45, -11.5), Vector3(20.0, 3.95, -11.5), 0.5, 0.035)
	_cable(Vector3(8.2, 3.45, -16.0), Vector3(20.0, 3.95, -16.0), 0.4, 0.03)
	_cable(Vector3(-8.2, 3.45, -13.0), Vector3(-20.0, 3.95, -13.0), 0.5, 0.035)
	# Data conduits up the arena's four inside corners, tucked in where a player cannot stand.
	for cx in [-1.0, 1.0]:
		for cz in [-1.0, 1.0]:
			_conduit(Vector3(cx * 19.84, 0.0, cz * 19.84), 4.3, Vector3(-cx, 0.0, -cz).normalized())
	# Glyph pylons on the pillars' tops, and one large over the lair.
	for name in ["PillarA", "PillarB"]:
		var b: GreyBlock = mounts.get(name)
		if b != null:
			var top := _to_art(b).origin + Vector3.UP * (b.size.y * 0.5)
			_emitter(top, 0.45)
			_holo.append([Transform3D(Basis.IDENTITY.scaled(Vector3.ONE * 0.8), top + Vector3.UP * 0.95), _holo.size() * 0.37])
	_holo.append([Transform3D(Basis.IDENTITY.scaled(Vector3.ONE * 1.4), Vector3(0.0, 5.6, -14.0)), 0.5])


## A server rack against mount `m`: posts, a cap and a foot round a face of 1U units.
func _rack(m: Dictionary, along: float) -> void:
	var w := 0.6
	var depth := 0.16
	var tall := 2.1
	var foot: float = m["foot"]
	for side in [-1.0, 1.0]:
		_wall_box(PANEL, m, along + side * (w * 0.5 - 0.02), foot + tall * 0.5, 0.04, tall, depth)
	_wall_box(PANEL, m, along, foot + tall - 0.03, w, 0.06, depth + 0.02)
	_wall_box(PANEL, m, along, foot + 0.05, w, 0.1, depth + 0.02)
	_wall_face(RACK, m, along, foot + 0.1 + (tall - 0.16) * 0.5, w - 0.08, tall - 0.16, depth - 0.01)


## A terminal screen on mount `m`, clear of its ribs: a bezel round a face of scrolling text, a block
## behind holding it to the wall, a thin teal sill under it.
func _screen(m: Dictionary, along: float, y: float, w: float, h: float) -> void:
	var bezel := 0.06
	_wall_box(PANEL, m, along, y, w * 0.6, h * 0.6, MOUNT_OUT)
	_wall_box(PANEL, m, along, y, w, h, 0.03, MOUNT_OUT)
	_wall_box(PANEL, m, along, y + (h + bezel) * 0.5, w + 2.0 * bezel, bezel, 0.06, MOUNT_OUT)
	_wall_box(PANEL, m, along, y - (h + bezel) * 0.5, w + 2.0 * bezel, bezel, 0.06, MOUNT_OUT)
	for side in [-1.0, 1.0]:
		_wall_box(PANEL, m, along + side * (w + bezel) * 0.5, y, bezel, h, 0.06, MOUNT_OUT)
	_wall_face(SCREEN, m, along, y, w, h, MOUNT_OUT + 0.032)
	_wall_box(TEAL, m, along, y - h * 0.5 - bezel - 0.03, w * 0.8, 0.015, 0.03, MOUNT_OUT)


## A vent on mount `m`, clear of its ribs: a frame round slanted louvres, lit teal from behind.
func _vent(m: Dictionary, along: float, y: float, w: float, h: float) -> void:
	var frame := 0.05
	_wall_box(PANEL, m, along, y, w, h, MOUNT_OUT)
	_wall_box(PANEL, m, along, y + (h + frame) * 0.5, w + 2.0 * frame, frame, 0.08, MOUNT_OUT)
	_wall_box(PANEL, m, along, y - (h + frame) * 0.5, w + 2.0 * frame, frame, 0.08, MOUNT_OUT)
	for side in [-1.0, 1.0]:
		_wall_box(PANEL, m, along + side * (w + frame) * 0.5, y, frame, h, 0.08, MOUNT_OUT)
	_wall_face(TEAL, m, along, y, w, h, MOUNT_OUT + 0.005)
	var slats := maxi(2, int(h / 0.1))
	var r: Vector3 = m["right"]
	var n: Vector3 = m["n"]
	# A louvre leans down and out: turned about the face's own horizontal axis.
	var tilt := Vector3(35.0, 0.0, 0.0) if absf(r.x) > 0.5 else Vector3(0.0, 0.0, 35.0)
	if r.x * n.z - r.z * n.x < 0.0:
		tilt = -tilt
	for i in slats:
		var sy := y - h * 0.5 + (i + 0.5) * h / slats
		_kit.box(PANEL, _on(m, along, sy, MOUNT_OUT + 0.04), r.abs() * w + n.abs() * 0.07 + Vector3.UP * 0.012, tilt)


## A cable tray along the foot of mount `m`, a hand's width off it: a channel with three cables in it
## and one live line, its data flowing.
func _tray(m: Dictionary) -> void:
	var length: float = m["width"] - 2.0
	var foot: float = m["foot"]
	var off := 0.36
	_wall_box(PANEL, m, 0.0, foot + 0.01, length, 0.02, 0.22, off - 0.11)
	for side in [-1.0, 1.0]:
		_wall_box(PANEL, m, 0.0, foot + 0.035, length, 0.07, 0.02, off - 0.01 + side * 0.1)
	var r: Vector3 = m["right"]
	var turn := Vector3(0.0, 90.0, 0.0) if absf(r.x) > 0.5 else Vector3.ZERO
	for k in 3:
		_kit.prism(PANEL, _on(m, 0.0, foot + 0.045, off + (k - 1) * 0.055), 0.022, length, 6, turn)
	_kit.box(FLOW, _on(m, 0.0, foot + 0.07, off), r.abs() * length + (m["n"] as Vector3).abs() * 0.012 + Vector3.UP * 0.01)


## A bundle of cable down mount `m` from its top into the tray at its foot, with a clamp.
func _drop(m: Dictionary, along: float) -> void:
	var foot: float = m["foot"]
	var tall: float = m["height"]
	for k in 3:
		_kit.prism(PANEL, _on(m, along + (k - 1) * 0.06, foot + tall * 0.5, MOUNT_OUT + 0.03), 0.025, tall, 6, Vector3(90.0, 0.0, 0.0))
	_wall_box(PANEL, m, along, foot + tall * 0.66, 0.24, 0.06, MOUNT_OUT + 0.06)


## A cable slung from `a` to `b`, sagging `sag` at its middle.
func _cable(a: Vector3, b: Vector3, sag: float, radius: float) -> void:
	var steps := 12
	var last := a
	for i in range(1, steps + 1):
		var t := float(i) / steps
		var point := a.lerp(b, t) + Vector3.DOWN * (sag * 4.0 * t * (1.0 - t))
		_rod(PANEL, last, point, radius)
		last = point


## A thin six-sided rod from `a` to `b`, a little longer so a chain of them has no gaps.
func _rod(id: int, a: Vector3, b: Vector3, radius: float) -> void:
	var along := b - a
	if along.is_zero_approx():
		return
	var dir := along.normalized()
	var turn := Basis.looking_at(dir, Vector3.UP if absf(dir.y) < 0.98 else Vector3.RIGHT).get_euler()
	_kit.prism(id, (a + b) * 0.5, radius, along.length() * 1.04, 6, Vector3(rad_to_deg(turn.x), rad_to_deg(turn.y), rad_to_deg(turn.z)))


## A data conduit standing in a corner at `at`, `tall` high: a pipe with collars, its data flowing
## up a lit line on the side that faces `toward`.
func _conduit(at: Vector3, tall: float, toward: Vector3) -> void:
	_kit.prism(PANEL, at + Vector3.UP * tall * 0.5, 0.1, tall, 8, Vector3(90.0, 0.0, 0.0))
	var collars := 5
	for i in collars:
		_kit.tube(PANEL, at + Vector3.UP * (0.3 + i * (tall - 0.6) / (collars - 1)), 0.09, 0.13, 0.07, 8, Vector3(90.0, 0.0, 0.0))
	_kit.box(FLOW, at + toward * 0.095 + Vector3.UP * tall * 0.5, Vector3(0.03, tall - 0.2, 0.03), Vector3(0.0, 45.0, 0.0))


## A hologram's emitter on a pillar's or a mast's top: a low tapered disc with a mint ring.
func _emitter(top: Vector3, radius: float) -> void:
	_kit.prism(PANEL, top + Vector3.UP * 0.06, radius, 0.12, 8, Vector3(90.0, 0.0, 0.0), radius * 0.8, 22.5)
	_kit.tube(MINT, top + Vector3.UP * 0.125, radius * 0.55, radius * 0.65, 0.01, 8, Vector3(90.0, 0.0, 0.0), 22.5)


# --- Outside the walls. ---

## The stepped plinth the arena stands on, falling away in tiers into the fog, its column going on
## down; parapets of varied heights along the outer walls' tops with a conduit along their inside;
## a tower at each corner and a mast behind each wall's middle, a glyph over each; data streaming
## down into the abyss. The top tier sits just under the floor, never level with it.
func _outside(mounts: Dictionary) -> void:
	for tier in [[23.5, -0.02, 3.0], [27.0, -3.0, 4.0], [31.0, -7.0, 5.0]]:  # half width, top, depth
		var half: float = tier[0]
		var top: float = tier[1]
		var depth: float = tier[2]
		_kit.frustum(DARK, Vector3(0.0, top - depth, 0.0), Vector2(half * 2.0 - 1.0, half * 2.0 - 1.0), Vector2(half * 2.0, half * 2.0), depth)
		_ring_strip(TEAL, Vector3(0.0, top - 0.06, 0.0), Vector2(half * 2.0 + 0.04, half * 2.0 + 0.04))
	_kit.frustum(DARK, Vector3(0.0, -140.0, 0.0), Vector2(20.0, 20.0), Vector2(36.0, 36.0), 128.0)
	for cx in [-1.0, 1.0]:
		for cz in [-1.0, 1.0]:
			_tower(Vector3(cx * 22.0, -0.02, cz * 22.0))
			_kit.box(FLOW, Vector3(cx * 30.6, -80.0, cz * 30.6), Vector3(0.14, 140.0, 0.14))
	for at in [Vector3(0.0, -0.02, -22.2), Vector3(22.2, -0.02, 0.0), Vector3(0.0, -0.02, 22.2), Vector3(-22.2, -0.02, 0.0)]:
		_mast(at)
	for spec in [["WallN", Vector3.BACK], ["WallS", Vector3.FORWARD], ["WallE", Vector3.LEFT], ["WallW", Vector3.RIGHT]]:
		var b: GreyBlock = mounts.get(spec[0])
		if b != null:
			_parapet(b, spec[1])


## Merlons of varied heights along the outer half of an outer wall's top, each with a bevelled cap
## and the tall ones a mint strip on the arena side, and a conduit along the inner half (`inward` is
## the arena side), its data flowing. The heights come out the same every build: a hash of the wall
## and of each merlon's place along it.
func _parapet(b: GreyBlock, inward: Vector3) -> void:
	var xf := _to_art(b)
	var s: Vector3 = b.size
	var base := xf.origin.y + s.y * 0.5 + CROWN_H
	var axis := Vector3.UP.cross(inward).abs()
	var length := absf(axis.dot(s))
	var thick := absf(inward.dot(s))
	var depth := thick * 0.5
	var salt := int(xf.origin.x * 3.0 + xf.origin.z * 7.0)
	var outer := Vector3(xf.origin.x, base, xf.origin.z) - inward * (thick * 0.25)
	var x := -length * 0.5 + 1.6
	var i := 0
	while x < length * 0.5 - 1.6:
		var w := 1.2 + 2.2 * _hash(i, salt + 1)
		w = minf(w, length * 0.5 - 1.6 - x)
		if _hash(i, salt) > 0.3 and w > 0.6:
			var tall := 0.4 + 1.5 * _hash(i, salt + 2)
			var c := outer + axis * (x + w * 0.5)
			var size := axis * w + inward.abs() * depth + Vector3.UP * tall
			_kit.box(PANEL, c + Vector3.UP * tall * 0.5, size)
			var cap := axis * (w + 0.06) + inward.abs() * (depth + 0.06)
			var cap_top := axis * (w - 0.06) + inward.abs() * (depth - 0.06)
			_kit.frustum(PANEL, c + Vector3.UP * tall, Vector2(cap.x, cap.z), Vector2(cap_top.x, cap_top.z), 0.08)
			if tall > 1.2:
				_kit.box(MINT, c + inward * (depth * 0.5 + 0.006) + Vector3.UP * (tall - 0.2), axis * (w - 0.3) + inward.abs() * 0.012 + Vector3.UP * STRIP_H)
		x += w + 0.25
		i += 1
	var run := Vector3(xf.origin.x, base + 0.13, xf.origin.z) + inward * (thick * 0.25)
	var turn := Vector3(0.0, 90.0, 0.0) if axis.x > 0.5 else Vector3.ZERO
	_kit.prism(PANEL, run, 0.13, length - 0.6, 8, turn)
	_kit.box(FLOW, run + inward * 0.125, axis * (length - 0.8) + inward.abs() * 0.012 + Vector3.UP * 0.03)


## A corner tower on the plinth at `at`: a battered shaft, a setback, a bevelled crown, a mast with a
## blinking beacon, teal strips up its corners and a large glyph over it.
func _tower(at: Vector3) -> void:
	_kit.frustum(DARK, at, Vector2(3.0, 3.0), Vector2(2.6, 2.6), 6.6)
	_kit.frustum(DARK, at + Vector3.UP * 6.6, Vector2(2.8, 2.8), Vector2(2.8, 2.8), 0.25)
	_kit.frustum(DARK, at + Vector3.UP * 6.85, Vector2(2.0, 2.0), Vector2(1.8, 1.8), 1.9)
	_kit.frustum(DARK, at + Vector3.UP * 8.75, Vector2(2.3, 2.3), Vector2(1.3, 1.3), 0.45)
	_kit.prism(PANEL, at + Vector3.UP * 9.7, 0.1, 1.0, 6, Vector3(90.0, 0.0, 0.0))
	_kit.box(BEACON, at + Vector3.UP * 10.25, Vector3(0.18, 0.18, 0.18))
	for cx in [-1.0, 1.0]:
		for cz in [-1.0, 1.0]:
			_kit.box(TEAL, at + Vector3(cx * 1.38, 3.3, cz * 1.38), Vector3(0.05, 6.0, 0.05), Vector3(0.0, 45.0, 0.0))
	_holo.append([Transform3D(Basis.IDENTITY.scaled(Vector3.ONE * 1.8), at + Vector3.UP * 11.5), fposmod(at.x * 0.13 + at.z * 0.07, 1.0)])


## A mast behind a wall's middle at `at`: a pole with collars from the plinth up past the wall, a lit
## line up it, an emitter and a glyph over it.
func _mast(at: Vector3) -> void:
	_kit.prism(PANEL, at + Vector3.UP * 3.7, 0.22, 7.4, 6, Vector3(90.0, 0.0, 0.0))
	for y in [1.2, 3.0, 4.8, 6.6]:
		_kit.tube(PANEL, at + Vector3.UP * y, 0.2, 0.3, 0.1, 6, Vector3(90.0, 0.0, 0.0))
	_kit.box(TEAL, at + Vector3.UP * 3.7 - at.normalized() * 0.2, Vector3(0.03, 7.0, 0.03))
	_emitter(at + Vector3.UP * 7.4, 0.5)
	_holo.append([Transform3D(Basis.IDENTITY.scaled(Vector3.ONE * 1.1), at + Vector3.UP * 8.6), fposmod(at.x * 0.11 - at.z * 0.05, 1.0)])


# --- Signs. ---

## Terminal-style signs in the sign font: on the lair's front and over its door, the outer walls, the
## cover, the pillars and crates, and arrows on the floor before the lair's door; and the game's name
## and the arena's on the outer walls' outsides. Every one invented flavour, nothing of the player's.
func _signage(mounts: Dictionary) -> void:
	# A header beam across the top of the lair's door posts, its name in red on both faces.
	var post_l: GreyBlock = mounts.get("DoorPostL")
	var post_r: GreyBlock = mounts.get("DoorPostR")
	if post_l != null and post_r != null:
		var a := _to_art(post_l).origin
		var b := _to_art(post_r).origin
		var top: float = a.y + post_l.size.y * 0.5
		var mid := (a + b) * 0.5
		var span: float = absf(b.x - a.x) + post_l.size.x
		var deep: float = post_l.size.z
		_kit.box(PANEL, Vector3(mid.x, top + 0.2, mid.z), Vector3(span, 0.4, deep))
		_text("RING 0", Vector3(mid.x, top + 0.2, mid.z + deep * 0.5), Vector3.RIGHT, Vector3.BACK, 0.045, RED, false)
		_text("RING 0", Vector3(mid.x, top + 0.2, mid.z - deep * 0.5), Vector3.LEFT, Vector3.FORWARD, 0.045, RED, false)
	var front_l := _mount(mounts, "RoomFrontL", Vector3.BACK)
	if not front_l.is_empty():
		_wall_text(front_l, "KILL -9", 0.0, 2.65, 0.06, true, -1, true)
	var front_r := _mount(mounts, "RoomFrontR", Vector3.BACK)
	if not front_r.is_empty():
		_wall_text(front_r, "EXIT 137", 0.0, 2.65, 0.06, true, 5, true)
	var north := _mount(mounts, "WallN", Vector3.BACK)
	if not north.is_empty():
		_wall_text(north, "PID 1", -4.5, 2.75, 0.05, true, -1, true)
		_wall_text(north, "TTY0", 4.5, 2.75, 0.05, true, -1, true)
	var east := _mount(mounts, "WallE", Vector3.LEFT)
	if not east.is_empty():
		_wall_text(east, "SIGKILL", _along(east, 3.0), 2.95, 0.085, true, -1, true)
		_wall_text(east, "ARENA 01", _along(east, 3.0), 2.3, 0.04, false)
	var west := _mount(mounts, "WallW", Vector3.RIGHT)
	if not west.is_empty():
		_wall_text(west, "/DEV/NULL", _along(west, -3.0), 2.95, 0.075, true, -1, true)
	var south := _mount(mounts, "WallS", Vector3.FORWARD)
	if not south.is_empty():
		_wall_text(south, "CORE DUMPED", 0.0, 2.95, 0.07, true, -1, true)
	for spec in [["CoverL1", Vector3.FORWARD, "SIGTERM"], ["CoverL1", Vector3.BACK, "SIGSTOP"], ["LowWall", Vector3.BACK, "SUDO !!"]]:
		var m := _mount(mounts, spec[0], spec[1])
		if not m.is_empty():
			var tall: float = m["height"]
			_wall_text(m, spec[2], 0.0, m["foot"] + tall * (0.72 if tall > 2.0 else 0.6), 0.04)
	for spec in [["PillarA", "01"], ["PillarB", "02"]]:
		var m := _mount(mounts, spec[0], Vector3.LEFT)
		if not m.is_empty():
			_wall_text(m, spec[1], 0.0, 3.0, 0.07)
	for spec in [["CrateA", Vector3.FORWARD, "0x1F"], ["CrateB", Vector3.BACK, "TMP"]]:
		var m := _mount(mounts, spec[0], spec[1])
		if not m.is_empty():
			_text(spec[2], _on(m, 0.0, m["foot"] + m["height"] * 0.55, FRAME_OUT), m["right"], m["n"], 0.035, MINT, false)
	# Arrows on the floor before the lair's door, pointing in.
	_text(">>>", Vector3(0.0, 0.006, -6.2), Vector3.FORWARD, Vector3.UP, 0.09, RED, false)
	# Outside: the game's name and the arena's, big on the outer walls' outsides.
	var south_out := _mount(mounts, "WallS", Vector3.BACK)
	if not south_out.is_empty():
		_wall_text(south_out, "SIGKILL", 0.0, 2.6, 0.16)
	var west_out := _mount(mounts, "WallW", Vector3.LEFT)
	if not west_out.is_empty():
		_wall_text(west_out, "/PROC/ARENA", 0.0, 2.6, 0.12)


## A sign on mount `m`, standing off it clear of its ribs, in warm sodium (mint before A4), on a dark
## plate with a lit frame unless `plate` is off; the characters from `red_from` on in hostile red;
## with a warm lamp before it when `lamp` (A4).
func _wall_text(m: Dictionary, text: String, along: float, y: float, px: float, plate: bool = true, red_from: int = -1, lamp: bool = false) -> void:
	if plate:
		# What holds the plate off the wall.
		_wall_box(PANEL, m, along, y, SignFont.width(text) * px * 0.6, SignFont.ROWS * px, MOUNT_OUT)
	_text(text, _on(m, along, y, MOUNT_OUT), m["right"], m["n"], px, WARM, plate, red_from)
	if lamp:
		_lamps.append([_on(m, along, y - SignFont.ROWS * px * 0.5 - LAMP_DOWN_M, MOUNT_OUT + LAMP_OUT_M), m["n"]])


## `text` in the sign font, `px` metres a pixel, centred on `at` on a surface facing `normal`, reading
## along `right`, in bucket `id` (from character `alt_from` on in RED); on a dark plate with a frame of
## light when `plate`.
func _text(text: String, at: Vector3, right: Vector3, normal: Vector3, px: float, id: int, plate: bool = true, alt_from: int = -1) -> void:
	if not SignFont.covers(text):
		push_error("arena art: the sign font has no glyph for part of " + text)
		return
	_signs.append(text)
	var up := normal.cross(right)
	var w := SignFont.width(text) * px
	var h := SignFont.ROWS * px
	var lift := 0.003
	if plate:
		var margin := px * 2.5
		var depth := 0.03
		_kit.box(PANEL, at + normal * depth * 0.5, right.abs() * (w + 2.0 * margin) + up.abs() * (h + 2.0 * margin) + normal.abs() * depth)
		var face := at + normal * (depth + lift)
		var fw := w + 2.0 * margin - px
		var fh := h + 2.0 * margin - px
		var line := px * 0.35
		for side in [-1.0, 1.0]:
			_quad(id, face + up * (side * fh * 0.5), right, up, fw + line, line, normal)
			_quad(id, face + right * (side * fw * 0.5), right, up, line, fh + line, normal)
		at = face
	else:
		at = at + normal * lift
	for run in SignFont.runs(text):
		var x0: float = -w * 0.5 + run[0] * px
		var y0: float = h * 0.5 - (run[1] + 1) * px
		var ink := RED if alt_from >= 0 and int(run[0]) / SignFont.ADVANCE >= alt_from else id
		_quad(ink, at + right * (x0 + run[2] * px * 0.5) + up * (y0 + px * 0.5), right, up, run[2] * px, px, normal)


## A flat rectangle `w` along `right` and `h` along `up`, centred on `c`, facing `normal`.
func _quad(id: int, c: Vector3, right: Vector3, up: Vector3, w: float, h: float, normal: Vector3) -> void:
	var a := right * (w * 0.5)
	var b := up * (h * 0.5)
	_kit.polygon(id, [c - a - b, c + a - b, c + a + b, c - a + b], normal)


## A hash of two small integers, from 0 to 1, for choices that must come out the same every build.
static func _hash(a: int, b: int) -> float:
	var h := (a * 374761393 + b * 668265263) & 0x7fffffff
	h = ((h ^ (h >> 13)) * 1274126177) & 0x7fffffff
	return float(h & 0xffff) / 65535.0
