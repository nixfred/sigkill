@tool
extends RefCounted
## SIGKILL palette and placeholder materials.
## Dark terminal look: near-black surfaces, teal and mint accents.
## Everything here is a placeholder for real art. Keep every colour in this file
## so a re-skin is a single edit.

enum Surface { WALL, FLOOR, ACCENT, CRATE }

const BG := Color(0.035, 0.050, 0.055)
const WALL_BASE := Color(0.070, 0.105, 0.110)
const FLOOR_BASE := Color(0.050, 0.075, 0.080)
const ACCENT_BASE := Color(0.060, 0.140, 0.135)
const CRATE_BASE := Color(0.085, 0.120, 0.115)
const TEAL_DIM := Color(0.060, 0.420, 0.400)
const TEAL := Color(0.090, 0.720, 0.670)
const MINT := Color(0.500, 1.000, 0.800)
const TEXT := Color(0.720, 1.000, 0.940)
const ALERT := Color(1.000, 0.370, 0.430)

static var _grid_texture: ImageTexture
static var _surface_cache: Dictionary = {}
static var _mono: SystemFont


## Greybox surface: flat dark base with a faint glowing grid, drawn in world space
## so every block gets the same scale reference.
static func surface(kind: int) -> StandardMaterial3D:
	if _surface_cache.has(kind):
		return _surface_cache[kind]
	var mat: StandardMaterial3D
	match kind:
		Surface.FLOOR:
			mat = _grid_material(FLOOR_BASE, TEAL_DIM, 0.9, 2.0)
		Surface.ACCENT:
			mat = _grid_material(ACCENT_BASE, MINT, 1.4, 1.0)
		Surface.CRATE:
			mat = _grid_material(CRATE_BASE, TEAL, 1.0, 0.5)
		_:
			mat = _grid_material(WALL_BASE, TEAL_DIM, 0.8, 2.0)
	_surface_cache[kind] = mat
	return mat


## Dark body with a glowing emission colour. Used for the cannon and targets.
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


static func mono_font() -> Font:
	if _mono == null:
		_mono = SystemFont.new()
		_mono.font_names = PackedStringArray(["JetBrains Mono", "DejaVu Sans Mono", "monospace"])
	return _mono


static func _grid_material(base: Color, line: Color, line_energy: float, cell_m: float) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = base
	mat.roughness = 0.95
	mat.emission_enabled = true
	mat.emission = line
	mat.emission_energy_multiplier = line_energy
	mat.emission_texture = _grid()
	mat.uv1_triplanar = true
	mat.uv1_world_triplanar = true
	mat.uv1_scale = Vector3.ONE / cell_m
	mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	return mat


## Black tile with a bright 2 px edge. Used as an emission mask, so only the lines glow.
static func _grid() -> ImageTexture:
	if _grid_texture != null:
		return _grid_texture
	var px := 128
	var img := Image.create_empty(px, px, true, Image.FORMAT_RGBA8)
	img.fill(Color(0.0, 0.0, 0.0, 1.0))
	for i in range(px):
		for t in range(2):
			img.set_pixel(i, t, Color.WHITE)
			img.set_pixel(t, i, Color.WHITE)
	img.generate_mipmaps()
	_grid_texture = ImageTexture.create_from_image(img)
	return _grid_texture
