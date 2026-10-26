@tool
extends RefCounted
## SIGKILL palette and material factory. The single source for every colour and look tunable.
##
## Tron look: void-black sky, near-black faces, glowing neon edges and grid lines.
## Teal and mint belong to the player side, red and amber to hostiles.
## The .gdshader files carry matching defaults only so a material previews sensibly in the
## editor. Every value set here wins at runtime. Change colours here, nowhere else.

enum Surface { WALL, FLOOR, ACCENT, CRATE }

# Floats are hex / 255. The hex value is in each comment.
const VOID := Color(0.0, 0.0, 0.0)  # #000000 sky, clear colour, text outlines
const BASE := Color(0.019607843, 0.031372549, 0.039215686)  # #05080a floor, wall and face base
const TEAL := Color(0.098039216, 0.827450980, 0.772549020)  # #19d3c5 player side neon
const MINT := Color(0.490196078, 1.0, 0.811764706)  # #7dffcf player side highlight
const HOSTILE_RED := Color(1.0, 0.2, 0.333333333)  # #ff3355 hostile neon
const HOSTILE_AMBER := Color(1.0, 0.690196078, 0.0)  # #ffb000 hostile highlight
const FLASH := Color(1.0, 1.0, 1.0)  # #ffffff kill flash and hit-marker pop
# Matrix register: green code rain where reality is thin. Nothing else is green.
const MATRIX_GREEN := Color(0.0, 1.0, 0.254901961)  # #00ff41 code rain tails
const MATRIX_HEAD := Color(0.784313725, 1.0, 0.815686275)  # #c8ffd0 the leading glyph of each stream

# Look tunables. Lengths are in metres, energies multiply the emission colour.
const EDGE_WIDTH := 0.04
const GRID_CELL := 1.0
const GRID_MAJOR_EVERY := 8.0
const GRID_MINOR_WIDTH := 0.02
const GRID_MAJOR_WIDTH := 0.05
const GRID_MINOR_ENERGY := 1.0
const GRID_MAJOR_ENERGY := 2.2
const WALL_EDGE_ENERGY := 2.0
const ACCENT_EDGE_ENERGY := 2.6
const CRATE_EDGE_ENERGY := 1.6
const HOSTILE_ENERGY := 3.0

# Shader names under res://shaders/.
const NEON_EDGE_SHADER := "neon_edge"
const CODE_RAIN_SHADER := "code_rain"

static var _shaders: Dictionary = {}
static var _floor_material_cache: ShaderMaterial
static var _mono: SystemFont


## Greybox surface for a block of the given size. Floors share one world-space grid material.
## Every other kind gets its own material so the edge shader knows the block's size. Those
## use the code rain shader: the neon edge look, plus Matrix rain near enemies, which
## scripts/code_rain_driver.gd switches on. Until it does, the rain is off.
static func surface(kind: int, size: Vector3 = Vector3.ONE) -> ShaderMaterial:
	var mat: ShaderMaterial
	match kind:
		Surface.FLOOR:
			mat = _floor_material()
		Surface.ACCENT:
			mat = _neon_material(CODE_RAIN_SHADER, size, MINT, ACCENT_EDGE_ENERGY)
		Surface.CRATE:
			mat = _neon_material(CODE_RAIN_SHADER, size, TEAL, CRATE_EDGE_ENERGY)
		_:
			mat = _neon_material(CODE_RAIN_SHADER, size, TEAL, WALL_EDGE_ENERGY)
	return mat


## Hostile target body: neon edges in hostile red on a hexagonal prism.
## radius is the circumradius of the CylinderMesh, height its full height.
static func hostile_material(radius: float, height: float) -> ShaderMaterial:
	var apothem := radius * 0.8660254  # regular hexagon: radius * cos(30 degrees)
	var mat := _neon_material(NEON_EDGE_SHADER, Vector3(apothem * 2.0, height, 0.0), HOSTILE_RED, HOSTILE_ENERGY)
	mat.set_shader_parameter("hex_prism", true)
	return mat


## Dark body with a glowing emission colour. Used for the cannon viewmodel.
static func glow(color: Color, energy: float = 1.5) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color.darkened(0.65)
	mat.roughness = 0.6
	mat.emission_enabled = true
	mat.emission = color
	mat.emission_energy_multiplier = energy
	return mat


## Unlit translucent material for beams and impact flashes.
static func unlit_alpha(color: Color) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color = color
	return mat


## Unlit, translucent and over-bright, for effects that should bloom: beams, flashes,
## sparks. energy scales the colour above 1 so the glow pass picks it up.
static func unlit_glow(color: Color, energy: float) -> StandardMaterial3D:
	return unlit_alpha(Color(color.r * energy, color.g * energy, color.b * energy, color.a))


## Opacity ramp for particles: fully visible at birth, gone by the end of their life.
static func fade_out_ramp() -> Gradient:
	var ramp := Gradient.new()
	ramp.set_color(0, FLASH)
	ramp.set_color(1, Color(FLASH, 0.0))
	return ramp


static func mono_font() -> Font:
	if _mono == null:
		_mono = SystemFont.new()
		_mono.font_names = PackedStringArray(["JetBrains Mono", "DejaVu Sans Mono", "monospace"])
	return _mono


static func _shader(shader_name: String) -> Shader:
	if not _shaders.has(shader_name):
		_shaders[shader_name] = load("res://shaders/%s.gdshader" % shader_name)
	return _shaders[shader_name]


static func _floor_material() -> ShaderMaterial:
	if _floor_material_cache == null:
		var mat := ShaderMaterial.new()
		mat.shader = _shader("floor_grid")
		mat.set_shader_parameter("base_color", BASE)
		mat.set_shader_parameter("minor_color", TEAL)
		mat.set_shader_parameter("major_color", MINT)
		mat.set_shader_parameter("cell_size", GRID_CELL)
		mat.set_shader_parameter("major_every", GRID_MAJOR_EVERY)
		mat.set_shader_parameter("minor_width", GRID_MINOR_WIDTH)
		mat.set_shader_parameter("major_width", GRID_MAJOR_WIDTH)
		mat.set_shader_parameter("minor_energy", GRID_MINOR_ENERGY)
		mat.set_shader_parameter("major_energy", GRID_MAJOR_ENERGY)
		_floor_material_cache = mat
	return _floor_material_cache


static func _neon_material(shader_name: String, size: Vector3, edge: Color, energy: float) -> ShaderMaterial:
	var mat := ShaderMaterial.new()
	mat.shader = _shader(shader_name)
	mat.set_shader_parameter("face_color", BASE)
	mat.set_shader_parameter("edge_color", edge)
	mat.set_shader_parameter("edge_width", EDGE_WIDTH)
	mat.set_shader_parameter("edge_energy", energy)
	mat.set_shader_parameter("hex_prism", false)
	mat.set_shader_parameter("half_extents", size * 0.5)
	return mat
