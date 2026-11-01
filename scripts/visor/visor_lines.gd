class_name VisorLines
extends Node3D
## What the Audit Trail visor draws in the world (C43, scripts/visor/audit_visor.gd): every lineage line in one
## MultiMesh of strips (shaders/visor_line.gdshader: the arc, the camera-facing ribbon, the packets running rootward,
## the fork's growth and the sever's fuse are all worked out on the GPU from each instance's two points), and every
## process's mark in another (shaders/visor_node.gdshader: init's rings, the hidden parent's redacted plate, a job's
## ring, a daemon's socket, a burst). Two draw calls whatever the arena holds; nothing is made after it is built.
## Visual only.

const LineShader = preload("res://shaders/visor_line.gdshader")
const NodeShader = preload("res://shaders/visor_node.gdshader")

## The most lines and marks drawn at once, and the strip's segments.
const LINES_MOST := 128
const MARKS_MOST := 192
const SEGMENTS := 28
## A box round everything, so the GPU-placed strips are never culled.
const EVERYWHERE := AABB(Vector3(-5000.0, -5000.0, -5000.0), Vector3(10000.0, 10000.0, 10000.0))

var _lines: MultiMeshInstance3D
var _marks: MultiMeshInstance3D
var _line_mat: ShaderMaterial
var _mark_mat: ShaderMaterial
var drawn_lines := 0
var drawn_marks := 0
## Drawn over everything (W4; W3's known issue: a concealed daemon's box lost its corners behind walls): set before it
## is added. Its own copy of the line shader with the depth test off, made once a run the first time one is asked for
## (a mode's begin, never a shift or a frame).
var through_walls := false
static var _through: Shader = null


## The line shader with its depth test off (made once).
static func through_shader() -> Shader:
	if _through == null:
		_through = Shader.new()
		_through.code = LineShader.code.replace("depth_draw_never,", "depth_draw_never, depth_test_disabled,")
	return _through


func _ready() -> void:
	name = "VisorLines"
	top_level = true
	global_transform = Transform3D.IDENTITY
	_line_mat = ShaderMaterial.new()
	_line_mat.shader = through_shader() if through_walls else LineShader
	_lines = _multi("Lines", _strip(), LINES_MOST, _line_mat, true)
	_mark_mat = ShaderMaterial.new()
	_mark_mat.shader = NodeShader
	var quad := QuadMesh.new()
	quad.size = Vector2.ONE
	_marks = _multi("Marks", quad, MARKS_MOST, _mark_mat, false)


func _multi(label: String, mesh: Mesh, most: int, mat: ShaderMaterial, custom: bool) -> MultiMeshInstance3D:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_custom_data = custom
	mm.mesh = mesh
	mm.instance_count = most
	mm.visible_instance_count = 0
	var inst := MultiMeshInstance3D.new()
	inst.name = label
	inst.multimesh = mm
	inst.material_override = mat
	inst.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	inst.custom_aabb = EVERYWHERE
	inst.gi_mode = GeometryInstance3D.GI_MODE_DISABLED
	add_child(inst)
	return inst


## The strip a line is drawn from: x its share of the way (0 at the child, 1 at the parent), y its side (-1 or 1).
func _strip() -> ArrayMesh:
	var verts := PackedVector3Array()
	var index := PackedInt32Array()
	for k in SEGMENTS + 1:
		var t := float(k) / SEGMENTS
		verts.append(Vector3(t, -1.0, 0.0))
		verts.append(Vector3(t, 1.0, 0.0))
	for k in SEGMENTS:
		var i := k * 2
		index.append_array([i, i + 1, i + 2, i + 1, i + 3, i + 2])
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_INDEX] = index
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	mesh.custom_aabb = EVERYWHERE
	return mesh


## The register's three hues, for both materials.
func set_hues(tron: Color, cyber: Color, matrix: Color) -> void:
	for mat in [_line_mat]:
		mat.set_shader_parameter("hue_tron", tron)
		mat.set_shader_parameter("hue_cyber", cyber)
		mat.set_shader_parameter("hue_matrix", matrix)


## This frame's lines, each {a, b, heat, width, grown, phase, burn, bright, depth, lift}, and marks, each {at, size,
## kind, flash, color, alpha}; past the caps the rest are dropped.
func draw(lines: Array, marks: Array) -> void:
	var mm := _lines.multimesh
	var n := mini(lines.size(), LINES_MOST)
	for i in n:
		var e: Dictionary = lines[i]
		mm.set_instance_transform(i, Transform3D(Basis(e["b"], Vector3(e["heat"], e["width"], e["grown"]), Vector3(e["phase"], e["burn"], e["bright"])), e["a"]))
		mm.set_instance_custom_data(i, Color(e["depth"], e["lift"], 0.0, 0.0))
	mm.visible_instance_count = n
	drawn_lines = n
	var km := _marks.multimesh
	var m := mini(marks.size(), MARKS_MOST)
	for i in m:
		var k: Dictionary = marks[i]
		var c: Color = k["color"]
		km.set_instance_transform(i, Transform3D(Basis(Vector3(k["size"], k["kind"], k["flash"]), Vector3(c.r, c.g, c.b), Vector3(k["alpha"], 0.0, 0.0)), k["at"]))
	km.visible_instance_count = m
	drawn_marks = m
