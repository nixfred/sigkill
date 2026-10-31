class_name ParentThreads
extends Node3D
## The zombies' threads to their parent (M2, docs/STORY.md mission 2: "find where the zombies come from"): from every
## child of a mission's parent still standing, a thin arc of amber light climbs over the street to the parent's anchor,
## pulses running along it toward the parent, so wherever a zombie stands its thread points the way to what never
## reaped it. A zombie ping has lit (scripts/weapons/ping_reveal.gd) has its thread lit too, for as long. Made by the
## mission's stage (scripts/missions/mission_stage.gd), told its parent and asked each frame for the children; one
## MultiMesh of thin segments (shaders/parent_thread.gdshader), nothing made after it is built. Visual only.

const ThreadShader = preload("res://shaders/parent_thread.gdshader")

## The most threads drawn at once, and the segments of each.
const THREADS_MOST := 40
const SEGMENTS := 10
## A thread's thickness, metres; how high it arcs over the straight line, metres plus a share of its length.
const WIDTH_M := 0.045
const LIFT_M := 1.4
const LIFT_SHARE := 0.12
## Where a thread leaves its zombie, over its body's middle; its brightness, and a pinged zombie's on top.
const FROM_ABOVE_M := 0.75
const BRIGHT := 1.0
const PINGED := 2.4

## The parent (its dummy), and how the stage hands over the children standing now.
var parent: Node3D = null
var children: Callable
var _mesh: MultiMeshInstance3D
var _drawn := 0


func _ready() -> void:
	name = "ParentThreads"
	top_level = true  # its segments are placed in world space
	global_transform = Transform3D.IDENTITY
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_custom_data = true
	mm.mesh = BoxMesh.new()
	mm.instance_count = THREADS_MOST * SEGMENTS
	mm.visible_instance_count = 0
	var mat := ShaderMaterial.new()
	mat.shader = ThreadShader
	_mesh = MultiMeshInstance3D.new()
	_mesh.name = "Threads"
	_mesh.multimesh = mm
	_mesh.material_override = mat
	_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_mesh.extra_cull_margin = 200.0
	add_child(_mesh)


## How many threads it draws now (for the checks).
func drawn() -> int:
	return _drawn


func _process(_delta: float) -> void:
	_drawn = 0
	var mm := _mesh.multimesh
	var art = parent.art_node() if parent != null and is_instance_valid(parent) and parent.is_alive() else null
	if art == null or not art.has_method("anchor") or not children.is_valid():
		mm.visible_instance_count = 0
		return
	var to: Vector3 = art.anchor()
	var slot := 0
	for child in children.call():
		if _drawn >= THREADS_MOST:
			break
		if not is_instance_valid(child) or not child.is_alive():
			continue
		var from: Vector3 = child.threat_point() + Vector3.UP * FROM_ABOVE_M
		var line := to - from
		var lift := LIFT_M + line.length() * LIFT_SHARE
		var reveal := PingReveal.find(child.art_node()) if child.art_node() != null else null
		var bright := BRIGHT + (PINGED * reveal.strength() if reveal != null else 0.0)
		var phase := fposmod(float(child.get_instance_id() % 997) * 0.1373, 1.0)
		var last := from
		for k in SEGMENTS:
			var u := float(k + 1) / SEGMENTS
			var next := from.lerp(to, u) + Vector3.UP * sin(PI * u) * lift
			var seg := next - last
			var length := seg.length()
			var y := seg / maxf(length, 0.0001)
			var x := y.cross(Vector3.UP if absf(y.y) < 0.95 else Vector3.RIGHT).normalized()
			var z := x.cross(y)
			mm.set_instance_transform(slot, Transform3D(Basis(x * WIDTH_M, y * length, z * WIDTH_M), (last + next) * 0.5))
			mm.set_instance_custom_data(slot, Color(float(k) / SEGMENTS, 1.0 / SEGMENTS, bright, phase))
			slot += 1
			last = next
		_drawn += 1
	mm.visible_instance_count = slot
