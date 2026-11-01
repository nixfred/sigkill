class_name ThemeGrade
extends CanvasLayer
## The whole frame in a terminal theme's colours (W3): one full-screen rectangle with shaders/theme_grade.gdshader, on a
## layer over the 3D view, the HUD and the Esc menu, and under the colourblind filter (so that still recolours all of it).
## Everything drawn under it takes the theme: the sky, the fog, the floor, the ruins and their registers' light, the
## daemons, the weapons and their effects, the HUD's panels and accents. Made by the theme shift
## (scripts/themes/theme_shift.gd) and only while it runs: the plain arena never has one, so nothing is drawn or costs a
## thing outside the mode.
##
## show_theme() puts a theme up at once; shift_to() tears the next one in over SHIFT_S (the palette tear, the shader's);
## step() runs it on the game's clock. Every theme it may show is set up front as uniforms of one material, so a shift
## changes numbers, never a shader: nothing compiles mid-game.

const GradeShader = preload("res://shaders/theme_grade.gdshader")

## Over the HUD (1) and its menu, the credits (90); under the colourblind filter (100).
const LAYER := 95
## How long the tear takes, and how long the grade takes to come in as the mode begins.
const SHIFT_S := 1.5
const EASE_IN_S := 0.6

var look: ThemeLook = null
var next: ThemeLook = null
## The tear's progress (0 none, 0 to 1 tearing), and the grade's strength.
var tear := 0.0
var strength := 0.0
## Tears finished (the checks).
var shifts := 0

var _cover: ColorRect
var _material: ShaderMaterial
var _tearing := false
var _clock := 0.0


func _init() -> void:
	name = "ThemeGrade"
	layer = LAYER
	_material = ShaderMaterial.new()
	_material.shader = GradeShader
	_cover = ColorRect.new()
	_cover.name = "Grade"
	_cover.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_cover.material = _material
	_cover.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_cover)
	_material.set_shader_parameter("strength", 0.0)


## Theme `l` at once (no tear).
func show_theme(l: ThemeLook) -> void:
	look = l
	next = null
	_tearing = false
	tear = 0.0
	_put("a", l)
	_put("b", l)
	_material.set_shader_parameter("tear", 0.0)


## Tears theme `l` in over the one showing, over SHIFT_S.
func shift_to(l: ThemeLook, seed: float = 0.0) -> void:
	if look == null:
		show_theme(l)
		return
	next = l
	_put("b", l)
	_material.set_shader_parameter("seam", Color(l.accent, 1.0))
	_material.set_shader_parameter("tear_seed", seed)
	_tearing = true
	tear = 0.0001  # the tear starts this frame (the shader reads 0 as no tear)
	_material.set_shader_parameter("tear", tear)


## At full strength at once (a level after the first: the run is already in the theme, so it never eases in from the
## plain colours behind a reload's tear).
func full() -> void:
	strength = 1.0
	_material.set_shader_parameter("strength", 1.0)


func tearing() -> bool:
	return _tearing


## The grade's material (the checks).
func grade_material() -> ShaderMaterial:
	return _material


func cover() -> ColorRect:
	return _cover


## On the game's clock (the theme shift's _process).
func step(delta: float) -> void:
	_clock = fmod(_clock + delta, 3600.0)
	_material.set_shader_parameter("clock", _clock)
	if strength < 1.0:
		strength = minf(strength + delta / EASE_IN_S, 1.0)
		_material.set_shader_parameter("strength", strength)
	if not _tearing:
		return
	tear = minf(tear + delta / SHIFT_S, 1.0)
	if tear >= 1.0:
		_tearing = false
		shifts += 1
		show_theme(next)
		return
	# Never exactly 0 while it runs (the shader reads 0 as a plain grade of a).
	_material.set_shader_parameter("tear", maxf(tear, 0.0001))


func _put(side: String, l: ThemeLook) -> void:
	_material.set_shader_parameter("ramp_" + side, l.ramp_vectors())
	_material.set_shader_parameter("hue_" + side, l.hue_vectors())
	_material.set_shader_parameter("light_" + side, 1.0 if l.light else 0.0)
	_material.set_shader_parameter("back_" + side, Color(l.background, 1.0))
