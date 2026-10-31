class_name CacheField
extends Node3D
## The cache lines' field (M3, docs/STORY.md mission 3: "a cache district where nothing is written to disk and the walls
## rewrite themselves between fights"): its plan's lattice of walls (RuinsLayout.field) made into walls of code, each
## standing written (solid: it stops a step, a shot and a look), mid-rewrite (a storm of glyphs as tall, nothing of it
## solid: walked and shot through, seen through only by code-rain vision) or gone, a post at every corner of the lattice
## and its seam on the floor under every wall. Made by the district (scripts/ruins/ruins_world.gd) when its plan has one.
##
## It rewrites itself (rewrite()): every wall to its state on the next pass (RuinsLayout.field_pattern(), the same on every
## machine), a wall writing in filling from the top down behind a bright write head over WRITE_S and solid only once it
## is whole and nothing stands in it (a wall never writes in over the player or a daemon: it waits mid-rewrite until
## they are out of it), one draining away over DRAIN_S, a storm rising over STORM_S. On its own it rewrites every IDLE_S
## (between fights); a mission's loop (scripts/missions/mission_stage.gd) drives it instead once it runs (driven), and
## stops it where it stands when the loop is broken (freeze(): every storm held still, `^C` over every wall still
## standing). Its written walls are solid in the district's walk grid as an A* grid too (RuinsLayout.walk_astar()), so a
## mission's daemons and the pace run find their way round them; mid-rewrite and gone are open floor.
##
## Every third wall carries a line of the set's code on both faces (field_code), lit while the wall is written. `^C` is
## the wall shader's own (shaders/cache_wall.gdshader), in the signs' pixel letters.
##
## The end of mission 3 (prompt()): a red `>_` on a standing wall in front of the player, blinking: `~`, watching. Visual,
## collision and its walk grid only: it reads nothing and runs nothing.

const WallShader = preload("res://shaders/cache_wall.gdshader")
const Palette = preload("res://scripts/palette.gd")

signal rewritten(turn: int)

## A wall writing in, draining away, and its storm rising or falling, seconds.
const WRITE_S := 1.1
const DRAIN_S := 0.6
const STORM_S := 0.45
## Seconds between two passes while nothing drives it.
const IDLE_S := 14.0
## Every LABEL_EVERY-th wall carries a line of the code.
const LABEL_EVERY := 3
## Its code's lines: how high on the wall, the font's size and its pixel size.
const LABEL_Y := 2.55
const LABEL_FONT := 52
const LABEL_PIXEL := 0.0048
## The red prompt at the end: how big (its chevron's height, metres), how bright, how long it blinks, its blink.
const PROMPT_M := 1.5
const PROMPT_GLOW := 5.0
const PROMPT_S := 4.2
const PROMPT_BLINK_S := 0.53
## How far off a wall the prompt picks may stand from the eye, metres, and how near the middle of the view.
const PROMPT_NEAR_M := 4.0
const PROMPT_FAR_M := 16.0
## A body in a wall's footprint (its half thickness plus this) keeps it from writing in, metres.
const CLEAR_M := 0.55

var layout: RuinsLayout = null
## The pass it stands on, and whether a loop drives it (no rewrites of its own).
var turn := 0
var driven := false
## Stopped where it stands (the loop broken).
var frozen := false

var _walls: Array = []
var _idle_t := 0.0
var _mat: ShaderMaterial = null
var _post_mat: ShaderMaterial = null
var _astar: AStarGrid2D = null
var _base := PackedByteArray()
var _grid_n := Vector2i.ZERO
var _cover := PackedInt32Array()
var _prompt: Node3D = null
var _prompt_t := -1.0


func _ready() -> void:
	name = "CacheField"
	if layout == null or layout.field.is_empty():
		return
	_mat = ShaderMaterial.new()
	_mat.shader = WallShader
	_post_mat = ShaderMaterial.new()
	_post_mat.shader = WallShader
	_post_mat.set_shader_parameter("post", true)
	var post_size := Vector3(RuinsLayout.FIELD_POST_M, RuinsLayout.FIELD_WALL_H + RuinsLayout.FIELD_POST_OVER, RuinsLayout.FIELD_POST_M)
	_post_mat.set_shader_parameter("size", post_size)
	var lines := layout.ruins.field_code.split("|", false)
	var walls: Array = layout.field["walls"]
	# Every wall the same length (a cell less a post): one material for them all.
	_mat.set_shader_parameter("size", Vector3(walls[0]["length"], RuinsLayout.FIELD_WALL_H, RuinsLayout.FIELD_WALL_T))
	var start := layout.field_pattern(0)
	for i in walls.size():
		var w: Dictionary = walls[i]
		var length: float = w["length"]
		var mesh := BoxMesh.new()
		mesh.size = Vector3(length, RuinsLayout.FIELD_WALL_H, RuinsLayout.FIELD_WALL_T)
		var node := MeshInstance3D.new()
		node.name = "Wall%02d" % i
		node.mesh = mesh
		node.material_override = _mat
		node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		node.position = (w["at"] as Vector3) + Vector3(0, RuinsLayout.FIELD_WALL_H * 0.5, 0)
		node.rotation.y = w["yaw"]
		node.set_instance_shader_parameter("wall_seed", fposmod(float(i) * 0.6180339 + float(layout.ruins.seed % 997) * 0.013, 1.0))
		add_child(node)
		var body := StaticBody3D.new()
		body.name = "Solid%02d" % i
		body.collision_layer = 1
		body.collision_mask = 0
		var shape := CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size = mesh.size
		shape.shape = box
		shape.disabled = true
		body.add_child(shape)
		node.add_child(body)
		var labels: Array[Label3D] = []
		if i % LABEL_EVERY == 0 and not lines.is_empty():
			for side in [1.0, -1.0]:
				labels.append(_label(node, lines[(i / LABEL_EVERY) % lines.size()], side))
		var state: int = start[i]
		var wall := {"node": node, "shape": shape, "state": state, "fill": 1.0 if state == RuinsLayout.Wall.WRITTEN else 0.0, "storm": 0.0 if state == RuinsLayout.Wall.GONE else 1.0, "solid": false, "labels": labels, "squares": PackedInt32Array()}
		_walls.append(wall)
	_seams(walls)
	_posts()
	_grid_in()
	for i in _walls.size():
		_show(i)
	_idle_t = IDLE_S


func _label(wall: Node3D, text: String, side: float) -> Label3D:
	var label := Label3D.new()
	label.text = text
	label.font = Palette.mono_font()
	label.font_size = LABEL_FONT
	label.pixel_size = LABEL_PIXEL
	label.outline_size = 0
	label.modulate = Color(0.55, 2.4, 0.85)
	label.double_sided = false
	label.shaded = false
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.position = Vector3(0, LABEL_Y - RuinsLayout.FIELD_WALL_H * 0.5, side * (RuinsLayout.FIELD_WALL_T * 0.5 + 0.012))
	label.rotation.y = 0.0 if side > 0.0 else PI
	wall.add_child(label)
	return label


## Its seam on the floor under every wall: one MultiMesh of thin glowing strips.
func _seams(walls: Array) -> void:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	var strip := BoxMesh.new()
	strip.size = Vector3(1.0, 0.02, 0.09)
	mm.mesh = strip
	mm.instance_count = walls.size()
	for i in walls.size():
		var w: Dictionary = walls[i]
		mm.set_instance_transform(i, Transform3D(Basis(Vector3.UP, w["yaw"]).scaled(Vector3(w["length"], 1.0, 1.0)), (w["at"] as Vector3) + Vector3(0, 0.012, 0)))
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = Color(0.0, 0.85, 0.24) * 1.4
	var node := MultiMeshInstance3D.new()
	node.name = "Seams"
	node.multimesh = mm
	node.material_override = mat
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(node)


## A post at every corner of the lattice (their collision is the district's, kind "post").
func _posts() -> void:
	var posts: Array = layout.field["posts"]
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	var box := BoxMesh.new()
	var tall := RuinsLayout.FIELD_WALL_H + RuinsLayout.FIELD_POST_OVER
	box.size = Vector3(RuinsLayout.FIELD_POST_M, tall, RuinsLayout.FIELD_POST_M)
	mm.mesh = box
	mm.instance_count = posts.size()
	for i in posts.size():
		mm.set_instance_transform(i, Transform3D(Basis.IDENTITY, (posts[i] as Vector3) + Vector3(0, tall * 0.5, 0)))
	var node := MultiMeshInstance3D.new()
	node.name = "Posts"
	node.multimesh = mm
	node.material_override = _post_mat
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	add_child(node)


# --- The rewrite. ---

## Every wall to its state on the next pass. Nothing once frozen.
func rewrite() -> void:
	if frozen:
		return
	turn += 1
	var states := layout.field_pattern(turn)
	for i in _walls.size():
		var wall: Dictionary = _walls[i]
		if wall["state"] != states[i]:
			wall["state"] = states[i]
			if states[i] != RuinsLayout.Wall.WRITTEN:
				_solid(i, false)  # nothing left standing of it to stop anyone, the moment it starts to go
	_idle_t = IDLE_S
	rewritten.emit(turn)


## Stopped where it stands (the loop broken): no more rewrites, every storm held still, a wall half written left as it
## is (and open), `^C` over every wall still standing.
func freeze() -> void:
	if frozen:
		return
	frozen = true
	for i in _walls.size():
		var wall: Dictionary = _walls[i]
		var node: MeshInstance3D = wall["node"]
		node.set_instance_shader_parameter("calm", 1.0)
		for label in wall["labels"]:
			label.visible = false  # its line of code gives way to `^C`
		if wall["fill"] > 0.02 or wall["storm"] > 0.02:
			node.set_instance_shader_parameter("caret", 1.0)
			wall["caret"] = true


## A red `>_` on the standing wall nearest the middle of the view from `eye` looking along `ahead`, between
## PROMPT_NEAR_M and PROMPT_FAR_M away, on its face toward the eye, blinking for PROMPT_S (its wall's `^C` put out, so it
## stands alone); false with none. Built as neon, a chevron and a cursor, as the hexagon's own prompt is drawn.
func prompt(eye: Vector3, ahead: Vector3) -> bool:
	var best := -1
	var best_score := -INF
	var face := 1.0
	for i in _walls.size():
		var wall: Dictionary = _walls[i]
		if wall["fill"] < 0.5 and wall["storm"] < 0.5:
			continue
		var node: MeshInstance3D = wall["node"]
		var mid := node.global_position
		var to := mid - eye
		var flat := Vector2(to.x, to.z).length()
		if flat < PROMPT_NEAR_M or flat > PROMPT_FAR_M:
			continue
		var normal := node.global_transform.basis.z.normalized()
		var side := 1.0 if normal.dot(-to) > 0.0 else -1.0
		if absf(normal.dot(to.normalized())) < 0.35:
			continue  # seen too edge-on to read
		var score := ahead.normalized().dot(to.normalized()) - 0.02 * flat + (0.3 if wall["fill"] >= 1.0 else 0.0)
		if score > best_score:
			best_score = score
			best = i
			face = side
	if best < 0:
		return false
	var node: MeshInstance3D = _walls[best]["node"]
	node.set_instance_shader_parameter("caret", 0.0)
	_walls[best]["caret"] = false
	_prompt = Node3D.new()
	_prompt.name = "Prompt"
	_prompt.position = Vector3(0, 0.1, face * (RuinsLayout.FIELD_WALL_T * 0.5 + 0.06))
	_prompt.rotation.y = 0.0 if face > 0.0 else PI
	node.add_child(_prompt)
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = Color(Palette.HOSTILE_RED.r * PROMPT_GLOW, Palette.HOSTILE_RED.g * PROMPT_GLOW, Palette.HOSTILE_RED.b * PROMPT_GLOW)
	mat.disable_fog = true
	# The chevron: two strokes meeting at its point; then the cursor beside it, low.
	var stroke := PROMPT_M * 0.62
	var thick := PROMPT_M * 0.13
	for k in [1.0, -1.0]:
		var bar := MeshInstance3D.new()
		var box := BoxMesh.new()
		box.size = Vector3(stroke, thick, 0.04)
		bar.mesh = box
		bar.material_override = mat
		bar.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		bar.rotation.z = -k * deg_to_rad(40.0)
		bar.position = Vector3(-PROMPT_M * 0.42, k * stroke * 0.5 * sin(deg_to_rad(40.0)), 0)
		_prompt.add_child(bar)
	var cursor := MeshInstance3D.new()
	cursor.name = "Cursor"
	var under := BoxMesh.new()
	under.size = Vector3(PROMPT_M * 0.5, thick, 0.04)
	cursor.mesh = under
	cursor.material_override = mat
	cursor.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	cursor.position = Vector3(PROMPT_M * 0.3, -stroke * sin(deg_to_rad(40.0)) + thick * 0.5, 0)
	_prompt.add_child(cursor)
	var lamp := OmniLight3D.new()
	lamp.light_color = Palette.HOSTILE_RED
	lamp.light_energy = 2.2
	lamp.omni_range = 4.5
	lamp.position = Vector3(0, 0, 0.5)
	_prompt.add_child(lamp)
	_prompt_t = 0.0
	return true


## The red prompt, or null: for the checks.
func prompt_node() -> Node3D:
	return _prompt if _prompt != null and is_instance_valid(_prompt) else null


func _process(delta: float) -> void:
	if _walls.is_empty():
		return
	if not driven and not frozen:
		_idle_t -= delta
		if _idle_t <= 0.0:
			rewrite()
	for i in _walls.size():
		_step(i, delta)
	if _prompt_t >= 0.0 and _prompt != null and is_instance_valid(_prompt):
		_prompt_t += delta
		(_prompt.get_node("Cursor") as Node3D).visible = fmod(_prompt_t, PROMPT_BLINK_S * 2.0) < PROMPT_BLINK_S
		if _prompt_t > PROMPT_S:
			_prompt.queue_free()
			_prompt = null
			_prompt_t = -1.0


## Wall `i` a step toward its state: written fills from the top behind the write head (solid once whole and clear),
## mid-rewrite drains its written part and raises the storm, gone drains both. Held where it is once frozen.
func _step(i: int, delta: float) -> void:
	if frozen:
		return
	var wall: Dictionary = _walls[i]
	var fill: float = wall["fill"]
	var storm: float = wall["storm"]
	match int(wall["state"]):
		RuinsLayout.Wall.WRITTEN:
			if storm < 1.0:
				storm = minf(storm + delta / STORM_S, 1.0)
			elif fill < 1.0:
				fill = minf(fill + delta / WRITE_S, 1.0)
			if fill >= 1.0 and not wall["solid"]:
				if _clear(i):
					_solid(i, true)
				else:
					fill = 0.97  # someone stands in it: it waits, mid-write, until they are out
		RuinsLayout.Wall.DIRTY:
			fill = maxf(fill - delta / DRAIN_S, 0.0)
			storm = minf(storm + delta / STORM_S, 1.0)
		_:
			fill = maxf(fill - delta / DRAIN_S, 0.0)
			storm = maxf(storm - delta / DRAIN_S, 0.0) if fill <= 0.0 else storm
	if fill == wall["fill"] and storm == wall["storm"]:
		return
	wall["fill"] = fill
	wall["storm"] = storm
	_show(i)


func _show(i: int) -> void:
	var wall: Dictionary = _walls[i]
	var node: MeshInstance3D = wall["node"]
	node.visible = wall["fill"] > 0.0 or wall["storm"] > 0.0
	node.set_instance_shader_parameter("fill", wall["fill"])
	node.set_instance_shader_parameter("storm", wall["storm"])
	for label in wall["labels"]:
		label.visible = wall["fill"] >= 1.0
		label.modulate.a = 1.0


## True when nothing (the player, a daemon) stands in wall `i`'s footprint.
func _clear(i: int) -> bool:
	var node: MeshInstance3D = _walls[i]["node"]
	var space := get_world_3d().direct_space_state if is_inside_tree() else null
	if space == null:
		return true
	var box := BoxShape3D.new()
	box.size = Vector3((node.mesh as BoxMesh).size.x, RuinsLayout.FIELD_WALL_H, RuinsLayout.FIELD_WALL_T + CLEAR_M * 2.0)
	var q := PhysicsShapeQueryParameters3D.new()
	q.shape = box
	q.transform = node.global_transform
	q.collision_mask = 0xFFFFFFFE  # anything but the level
	q.collide_with_areas = false
	return space.intersect_shape(q, 1).is_empty()


func _solid(i: int, on: bool) -> void:
	var wall: Dictionary = _walls[i]
	if wall["solid"] == on:
		return
	wall["solid"] = on
	(wall["shape"] as CollisionShape3D).set_deferred("disabled", not on)
	_grid_mark(i, 1 if on else -1)


# --- Its walk grid. ---

## The walk grid's squares under each wall (grown by a player's radius), and every field square back to the plan's own
## state (a retry finds the grid as the last run left it).
func _grid_in() -> void:
	_astar = layout.walk_astar()
	var grid := layout.walk_grid()
	_base = grid["open"]
	_grid_n = grid["n"]
	var ext: Vector2 = grid["ext"]
	_cover.resize(_base.size())
	_cover.fill(0)
	for i in _walls.size():
		var w: Dictionary = layout.field["walls"][i]
		var at: Vector3 = w["at"]
		var along := Vector3(cos(w["yaw"]), 0, -sin(w["yaw"]))
		var half_l: float = w["length"] * 0.5 + RuinsLayout.PLAYER_R
		var half_t := RuinsLayout.FIELD_WALL_T * 0.5 + RuinsLayout.PLAYER_R
		var squares := PackedInt32Array()
		var reach := maxf(half_l, half_t)
		for j in range(maxi(floori((at.z - reach + ext.y) / RuinsLayout.WALK_M), 0), mini(ceili((at.z + reach + ext.y) / RuinsLayout.WALK_M), _grid_n.y)):
			for k in range(maxi(floori((at.x - reach + ext.x) / RuinsLayout.WALK_M), 0), mini(ceili((at.x + reach + ext.x) / RuinsLayout.WALK_M), _grid_n.x)):
				var p := Vector3(-ext.x + (k + 0.5) * RuinsLayout.WALK_M, 0, -ext.y + (j + 0.5) * RuinsLayout.WALK_M) - at
				if absf(p.dot(along)) < half_l and absf(p.dot(Vector3(-along.z, 0, along.x))) < half_t:
					squares.append(j * _grid_n.x + k)
		_walls[i]["squares"] = squares
		for s in squares:
			_astar.set_point_solid(Vector2i(s % _grid_n.x, s / _grid_n.x), _base[s] == 0)
	for i in _walls.size():
		if _walls[i]["state"] == RuinsLayout.Wall.WRITTEN and _walls[i]["fill"] >= 1.0:
			_solid(i, true)


func _grid_mark(i: int, by: int) -> void:
	if _astar == null:
		return
	for s in _walls[i]["squares"]:
		_cover[s] = maxi(_cover[s] + by, 0)
		_astar.set_point_solid(Vector2i(s % _grid_n.x, s / _grid_n.x), _base[s] == 0 or _cover[s] > 0)


func _exit_tree() -> void:
	# The plan's grid is kept for the run: every square this field closed is opened again as it goes.
	if _astar == null:
		return
	for i in _walls.size():
		if _walls[i]["solid"]:
			for s in _walls[i]["squares"]:
				_astar.set_point_solid(Vector2i(s % _grid_n.x, s / _grid_n.x), _base[s] == 0)


# --- For the checks. ---

## Wall `i`'s state now: its target (RuinsLayout.Wall), how written (0 to 1), its storm, whether it is solid.
func wall_state(i: int) -> Dictionary:
	var wall: Dictionary = _walls[i]
	return {"state": wall["state"], "fill": wall["fill"], "storm": wall["storm"], "solid": wall["solid"], "caret": wall.get("caret", false)}


func wall_count() -> int:
	return _walls.size()


func wall_node(i: int) -> MeshInstance3D:
	return _walls[i]["node"]


## How many walls stand solid now.
func solid_count() -> int:
	var n := 0
	for wall in _walls:
		if wall["solid"]:
			n += 1
	return n
