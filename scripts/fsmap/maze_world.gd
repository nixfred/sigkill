class_name MazeWorld
extends Node3D
## The node_modules maze, built (W2, PRD 5.5): a level's plan (scripts/fsmap/node_maze.gd) made into a place, standing on
## its district's floor (a child of the RuinsWorld). Visual and collision only: it reads nothing and runs nothing.
##
##   the walls     every wall of the plan in one mesh and one draw (shaders/maze_wall.gdshader: black glass, code
##                 falling, an install's progress bar filling and starting over; lime, amber WARN, red ERR!), a post at
##                 every corner; NodeMaze.WALL_H tall, over a jump and over the eye, so the maze shuts the room out; one
##                 static body of boxes (the level's layer: it stops a step, a shot and a look)
##   the names     every LABEL_EVERY-th wall wears a package's name on both faces (the folder's own subfolders' names,
##                 or the demo's), a version after it; a few wear npm's own complaints
##   the way out   a column of white light over the far cell, seen over every wall from anywhere, "cd .." over it
##   the ways down a lit hatch in a dead end's floor, its package's node_modules named over it, chevrons sinking into it
##   the welcome   at the start, the depth, and how many packages were "added" to get here

const WallShader = preload("res://shaders/maze_wall.gdshader")
const Palette = preload("res://scripts/palette.gd")

const LABEL_EVERY := 3
const LABEL_FONT := 64
const LABEL_PIXEL := 0.0062
const LABEL_Y := 2.9
const LABEL_RANGE_M := 22.0
const POST_M := 0.46
const BEACON_H := 70.0
const BEACON_R := 0.42
const COMPLAINTS := ["npm WARN deprecated", "peer dep missing", "1 high severity", "postinstall: running", "EBUSY: retrying", "npm WARN ERESOLVE", "fund: 412 packages", "you are here"]

var maze: NodeMaze = null
var names := PackedStringArray()
var level := 1
var installed := 1
## Walls built and labels hung, for the checks.
var wall_count := 0
var label_count := 0
var _mat: ShaderMaterial = null
var _pits: Array = []
var _beacon: MeshInstance3D = null
var _beacon_label: Label3D = null
var _t := 0.0


func _ready() -> void:
	name = "Maze"
	if maze == null or maze.layout == null:
		return
	_mat = ShaderMaterial.new()
	_mat.shader = WallShader
	_build_walls()
	_build_labels()
	_build_beacon()
	_build_pits()
	_build_welcome()


func _build_walls() -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	st.set_custom_format(0, SurfaceTool.CUSTOM_RGBA_FLOAT)
	var body := StaticBody3D.new()
	body.name = "MazeSolid"
	body.collision_layer = 1
	body.collision_mask = 0
	add_child(body)
	var posts := {}
	var h := NodeMaze.WALL_H
	for i in maze.walls.size():
		var w: Dictionary = maze.walls[i]
		var length: float = float(w["length"]) - POST_M
		var basis := Basis(Vector3.UP, w["yaw"])
		var mid: Vector3 = (w["at"] as Vector3) + Vector3(0, h * 0.5, 0)
		var seed := fposmod(float(i) * 0.6180339 + float(maze.seed % 997) * 0.013, 1.0)
		_box(st, Transform3D(basis, mid), Vector3(length, h, NodeMaze.WALL_T), seed)
		var shape := CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size = Vector3(float(w["length"]), h, NodeMaze.WALL_T)
		shape.shape = box
		shape.transform = Transform3D(basis, mid)
		body.add_child(shape)
		var along := basis.x * float(w["length"]) * 0.5
		for end in [(w["at"] as Vector3) - along, (w["at"] as Vector3) + along]:
			posts["%d,%d" % [roundi(end.x * 10.0), roundi(end.z * 10.0)]] = end
	for key in posts:
		var at: Vector3 = posts[key]
		_box(st, Transform3D(Basis.IDENTITY, at + Vector3(0, (h + 0.3) * 0.5, 0)), Vector3(POST_M, h + 0.3, POST_M), 0.5)
	wall_count = maze.walls.size()
	var mesh := st.commit()
	var node := MeshInstance3D.new()
	node.name = "MazeWalls"
	node.mesh = mesh
	node.material_override = _mat
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(node)


## A box into the walls' mesh: its four sides and its top, each face's UV its place in metres (x across, y down from
## the top), its custom data the wall's seed, the face's size and whether it is a top.
func _box(st: SurfaceTool, xf: Transform3D, size: Vector3, seed: float) -> void:
	var hx := size.x * 0.5
	var hy := size.y * 0.5
	var hz := size.z * 0.5
	# [normal, u axis, v axis (down), face width, face height]
	var faces := [
		[Vector3(0, 0, 1), Vector3(1, 0, 0), Vector3(0, -1, 0), size.x, size.y, hz],
		[Vector3(0, 0, -1), Vector3(-1, 0, 0), Vector3(0, -1, 0), size.x, size.y, hz],
		[Vector3(1, 0, 0), Vector3(0, 0, -1), Vector3(0, -1, 0), size.z, size.y, hx],
		[Vector3(-1, 0, 0), Vector3(0, 0, 1), Vector3(0, -1, 0), size.z, size.y, hx],
		[Vector3(0, 1, 0), Vector3(1, 0, 0), Vector3(0, 0, 1), size.x, size.z, hy],
	]
	for f in faces:
		var n: Vector3 = f[0]
		var u: Vector3 = f[1]
		var v: Vector3 = f[2]
		var fw: float = f[3]
		var fh: float = f[4]
		var off: float = f[5]
		var origin := n * off - u * fw * 0.5 - v * fh * 0.5
		var corners := [origin, origin + u * fw, origin + u * fw + v * fh, origin + v * fh]
		var uvs := [Vector2(0, 0), Vector2(fw, 0), Vector2(fw, fh), Vector2(0, fh)]
		var top := 1.0 if n.y > 0.5 else 0.0
		for k in [0, 1, 2, 0, 2, 3]:
			st.set_normal(xf.basis * n)
			st.set_uv(uvs[k])
			st.set_custom(0, Color(seed, fw, fh, top))
			st.add_vertex(xf * (corners[k] as Vector3))


func _build_labels() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = maze.seed * 3 + 1
	for i in maze.walls.size():
		if i % LABEL_EVERY != 0:
			continue
		var w: Dictionary = maze.walls[i]
		var text := ""
		if (i / LABEL_EVERY) % 5 == 4:
			text = COMPLAINTS[(i / LABEL_EVERY / 5) % COMPLAINTS.size()]
		else:
			text = "%s@%d.%d.%d" % [names[(i / LABEL_EVERY) % names.size()], rng.randi_range(0, 4), rng.randi_range(0, 19), rng.randi_range(0, 9)]
		# An outer wall wears its name on the face toward the floor only (+1 for a north or west wall, -1 for the others).
		var inner := 1.0 if (int(w["side"]) == 0 or int(w["side"]) == 3) else -1.0
		for side in [1.0, -1.0]:
			if bool(w["outer"]) and side != inner:
				continue
			var label := Label3D.new()
			label.text = text
			label.font = Palette.mono_font()
			label.font_size = LABEL_FONT
			label.pixel_size = LABEL_PIXEL
			label.outline_size = 0
			label.modulate = Color(0.85, 1.6, 0.35)
			label.double_sided = false
			label.shaded = false
			label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			label.visibility_range_end = LABEL_RANGE_M
			var basis := Basis(Vector3.UP, float(w["yaw"]) + (0.0 if side > 0.0 else PI))
			label.transform = Transform3D(basis, (w["at"] as Vector3) + Vector3(0, LABEL_Y, 0) + basis.z * (NodeMaze.WALL_T * 0.5 + 0.015))
			add_child(label)
			label_count += 1


func _build_beacon() -> void:
	var at := maze.layout.center(maze.exit)
	var mesh := CylinderMesh.new()
	mesh.top_radius = BEACON_R * 0.6
	mesh.bottom_radius = BEACON_R
	mesh.height = BEACON_H
	mesh.radial_segments = 12
	mesh.rings = 1
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	mat.albedo_color = Color(0.75, 0.95, 1.0, 0.85) * 2.4
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	_beacon = MeshInstance3D.new()
	_beacon.name = "WayOut"
	_beacon.mesh = mesh
	_beacon.material_override = mat
	_beacon.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_beacon.position = at + Vector3(0, BEACON_H * 0.5, 0)
	add_child(_beacon)
	var pad := MeshInstance3D.new()
	var quad := BoxMesh.new()
	quad.size = Vector3(RuinsLayout.CELL_M - 0.9, 0.03, RuinsLayout.CELL_M - 0.9)
	pad.mesh = quad
	var pad_mat := mat.duplicate() as StandardMaterial3D
	pad_mat.albedo_color = Color(0.6, 0.9, 1.0, 0.5) * 1.6
	pad.material_override = pad_mat
	pad.position = at + Vector3(0, 0.03, 0)
	add_child(pad)
	var lamp := OmniLight3D.new()
	lamp.light_color = Color(0.7, 0.92, 1.0)
	lamp.light_energy = 3.0
	lamp.omni_range = 9.0
	lamp.position = at + Vector3(0, 2.5, 0)
	add_child(lamp)
	_beacon_label = Label3D.new()
	_beacon_label.name = "WayOutLabel"
	_beacon_label.text = "cd ..\nTHE WAY OUT"
	_beacon_label.font = Palette.mono_font()
	_beacon_label.font_size = 64
	_beacon_label.pixel_size = 0.0007
	_beacon_label.fixed_size = true  # the same size on screen from anywhere: a way out, not a wall of text
	_beacon_label.outline_size = 16
	_beacon_label.outline_modulate = Color(0, 0, 0, 0.9)
	_beacon_label.modulate = Color(0.85, 1.0, 1.0) * 1.8
	_beacon_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_beacon_label.no_depth_test = true
	_beacon_label.shaded = false
	_beacon_label.position = at + Vector3(0, NodeMaze.WALL_H + 5.5, 0)
	add_child(_beacon_label)


func _build_pits() -> void:
	for i in maze.pits.size():
		var at := maze.layout.center(maze.pits[i])
		var node := Node3D.new()
		node.name = "WayDown%d" % i
		node.position = at
		add_child(node)
		var mat := StandardMaterial3D.new()
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mat.albedo_color = Color(1.0, 0.55, 0.05) * 2.2
		var hatch := MeshInstance3D.new()
		var box := BoxMesh.new()
		box.size = Vector3(2.4, 0.02, 2.4)
		hatch.mesh = box
		var dark := StandardMaterial3D.new()
		dark.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		dark.albedo_color = Color(0.0, 0.0, 0.0)
		hatch.material_override = dark
		hatch.position = Vector3(0, 0.02, 0)
		node.add_child(hatch)
		for s in 4:
			var rim := MeshInstance3D.new()
			var bar := BoxMesh.new()
			bar.size = Vector3(2.6, 0.05, 0.08)
			rim.mesh = bar
			rim.material_override = mat
			rim.transform = Transform3D(Basis(Vector3.UP, s * PI * 0.5), Basis(Vector3.UP, s * PI * 0.5) * Vector3(0, 0.04, 1.26))
			node.add_child(rim)
		var chevrons: Array = []
		for k in 3:
			var ch := MeshInstance3D.new()
			var prism := PrismMesh.new()
			prism.size = Vector3(0.9, 0.5, 0.08)
			ch.mesh = prism
			ch.material_override = mat
			ch.rotation = Vector3(0, 0, PI)
			node.add_child(ch)
			chevrons.append(ch)
		var label := Label3D.new()
		label.text = "%s/node_modules\nv  deeper  v" % names[i % names.size()]
		label.font = Palette.mono_font()
		label.font_size = 64
		label.pixel_size = 0.009
		label.outline_size = 12
		label.outline_modulate = Color(0, 0, 0, 0.9)
		label.modulate = Color(1.0, 0.7, 0.2) * 1.6
		label.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y
		label.shaded = false
		label.position = Vector3(0, 2.6, 0)
		label.visibility_range_end = 26.0
		node.add_child(label)
		var lamp := OmniLight3D.new()
		lamp.light_color = Color(1.0, 0.6, 0.15)
		lamp.light_energy = 2.0
		lamp.omni_range = 5.0
		lamp.position = Vector3(0, 0.6, 0)
		node.add_child(lamp)
		_pits.append({"node": node, "chevrons": chevrons})


func _build_welcome() -> void:
	var at := maze.layout.center(maze.start)
	var label := Label3D.new()
	label.name = "Welcome"
	label.text = "node_modules   DEPTH %d\nadded %s packages, and %d left behind" % [level, FolderTree.thousands(installed), maze.pits.size()]
	label.font = Palette.mono_font()
	label.font_size = 72
	label.pixel_size = 0.012
	label.outline_size = 14
	label.outline_modulate = Color(0, 0, 0, 0.9)
	label.modulate = Color(0.8, 1.0, 0.3) * 1.6
	label.shaded = false
	label.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y
	label.position = at + Vector3(0, NodeMaze.WALL_H - 1.2, -RuinsLayout.CELL_M * 0.5)
	add_child(label)


func _process(delta: float) -> void:
	_t += delta
	if _beacon != null:
		_beacon.scale = Vector3(1.0 + 0.12 * sin(_t * 3.1), 1.0, 1.0 + 0.12 * sin(_t * 3.1))
	for p in _pits:
		var chevrons: Array = p["chevrons"]
		for k in chevrons.size():
			var f := fposmod(_t * 0.7 + float(k) / chevrons.size(), 1.0)
			(chevrons[k] as Node3D).position = Vector3(0, lerpf(2.0, 0.1, f), 0)
			(chevrons[k] as Node3D).scale = Vector3.ONE * lerpf(1.0, 0.35, f)


## For the checks: the way out's place, and the ways down's.
func way_out_at() -> Vector3:
	return _beacon.global_position if _beacon != null else Vector3.INF


func ways_down() -> int:
	return _pits.size()
