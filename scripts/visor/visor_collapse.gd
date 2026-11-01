class_name VisorCollapse
extends Node3D
## A sever reshaping the arena (C43, PRD 5.5: "Severing a spawn chain collapses or reshapes that part of the arena"):
## where a severed process stood, a hexagon of the floor's columns thrusts up in a ripple from the middle out, its caps
## lit in the visor's colour going to embers, holds, and sinks back into the floor; a dead parent's is wider. One
## MultiMesh of hex columns (shaders/visor_pillar.gdshader) for every collapse at once; no collision, nothing moved
## for real: the floor under it is as it was. Visual only.

const PillarShader = preload("res://shaders/visor_pillar.gdshader")

## Collapses at once, at most, and columns in each (a hexagon of rings round the middle).
const MOST := 24
const RINGS := 2
const COLUMNS := 19
const SPACING_M := 0.72
const RADIUS_M := 0.4
## Its life: up over RISE_S (the ring further out later by STAGGER_S), held, down by LIFE_S.
const RISE_S := 0.22
const STAGGER_S := 0.07
const HOLD_S := 0.55
const LIFE_S := 2.4
## How tall a column stands at its height, metres: the middle tallest.
const TALL_M := Vector2(0.35, 1.5)

var _mesh: MultiMeshInstance3D
var _mat: ShaderMaterial
var _live: Array = []
var _cells: Array[Vector2] = []
var made := 0


func _ready() -> void:
	name = "VisorCollapse"
	top_level = true
	global_transform = Transform3D.IDENTITY
	_cells = _hexagon()
	var column := CylinderMesh.new()
	column.top_radius = RADIUS_M
	column.bottom_radius = RADIUS_M
	column.height = 1.0
	column.radial_segments = 6
	column.rings = 1
	_mat = ShaderMaterial.new()
	_mat.shader = PillarShader
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_custom_data = true
	mm.mesh = column
	mm.instance_count = MOST * COLUMNS
	mm.visible_instance_count = 0
	_mesh = MultiMeshInstance3D.new()
	_mesh.name = "Columns"
	_mesh.multimesh = mm
	_mesh.material_override = _mat
	_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_mesh.custom_aabb = VisorLines.EVERYWHERE
	add_child(_mesh)


func set_hues(tron: Color, cyber: Color, matrix: Color) -> void:
	_mat.set_shader_parameter("hue_tron", tron)
	_mat.set_shader_parameter("hue_cyber", cyber)
	_mat.set_shader_parameter("hue_matrix", matrix)


## A collapse at `floor_at` (the floor's point under what was severed), `scale` wider for a dead parent.
func burst(floor_at: Vector3, scale: float = 1.0, seed: int = 0) -> void:
	if not floor_at.is_finite():
		return
	if _live.size() >= MOST:
		_live.pop_front()
	_live.append({"at": floor_at, "age": 0.0, "scale": clampf(scale, 0.5, 2.0), "seed": seed})
	made += 1


## Collapses still going.
func live() -> int:
	return _live.size()


func _process(delta: float) -> void:
	var mm := _mesh.multimesh
	var slot := 0
	var keep: Array = []
	for c in _live:
		c["age"] = float(c["age"]) + delta
		var age: float = c["age"]
		if age >= LIFE_S:
			continue
		keep.append(c)
		var s: float = c["scale"]
		for k in _cells.size():
			var cell: Vector2 = _cells[k]
			var ring := cell.length() / SPACING_M
			var wobble := fposmod(sin(float(k * 7 + int(c["seed"])) * 12.9898) * 43758.5453, 1.0)
			var start := ring * STAGGER_S + wobble * 0.05
			var up := clampf((age - start) / RISE_S, 0.0, 1.0)
			var down := clampf((age - start - RISE_S - HOLD_S) / (LIFE_S - start - RISE_S - HOLD_S), 0.0, 1.0)
			var rise := (1.0 - pow(1.0 - up, 3.0)) * (1.0 - down * down)
			if rise <= 0.001:
				continue
			var tall := lerpf(TALL_M.y, TALL_M.x, clampf(ring / (RINGS + 0.5), 0.0, 1.0)) * (0.75 + 0.5 * wobble) * s
			var h := tall * rise
			var at: Vector3 = c["at"] + Vector3(cell.x * s, h * 0.5 - 0.02, cell.y * s)
			var tilt := Basis(Vector3(cell.y, 0.0, -cell.x).normalized() if cell.length() > 0.01 else Vector3.RIGHT, (wobble - 0.5) * 0.25 * down)
			mm.set_instance_transform(slot, Transform3D(tilt * Basis.from_scale(Vector3(s, maxf(h, 0.01), s)), at))
			mm.set_instance_custom_data(slot, Color(1.0 - down * 0.7, clampf(age / (RISE_S + HOLD_S + 0.3), 0.0, 1.0), 0.0, 0.0))
			slot += 1
	_live = keep
	mm.visible_instance_count = slot


## The hexagon's cells round the middle, RINGS rings out.
static func _hexagon() -> Array[Vector2]:
	var out: Array[Vector2] = []
	for q in range(-RINGS, RINGS + 1):
		for r in range(maxi(-RINGS, -q - RINGS), mini(RINGS, -q + RINGS) + 1):
			out.append(Vector2(SPACING_M * (q + r * 0.5), SPACING_M * r * 0.8660254))
	return out
