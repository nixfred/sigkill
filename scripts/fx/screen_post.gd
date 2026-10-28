class_name ScreenPost
extends CanvasLayer
## The screen post effects (A4): chromatic aberration and CRT scanlines, each its own setting,
## both off by default (scripts/settings/game_settings.gd). One full-screen rectangle with
## shaders/screen_post.gdshader, on a layer under the HUD (so the HUD and the crosshair stay
## crisp) and over the 3D view; hidden, at no cost, while both are off. Neither effect warps
## the picture, so the crosshair's point is where a shot goes. Made once by the arena
## (scripts/main.gd); nothing is made after.

const Palette = preload("res://scripts/palette.gd")
const PostShader = preload("res://shaders/screen_post.gdshader")

## Under the HUD (layer 1) and the colour filter (100); over the 3D view.
const POST_LAYER := -1

var _cover: ColorRect
var _material: ShaderMaterial
var _aberration := false
var _crt := false


func _init() -> void:
	name = "ScreenPost"
	layer = POST_LAYER
	_material = ShaderMaterial.new()
	_material.shader = PostShader
	_cover = ColorRect.new()
	_cover.name = "Cover"
	_cover.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_cover.material = _material
	_cover.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_cover)
	set_effects(false, false)


## Chromatic aberration and the CRT scanlines on or off; the rectangle shows only while one is.
func set_effects(aberration: bool, crt: bool) -> void:
	_aberration = aberration
	_crt = crt
	_material.set_shader_parameter("aberration_px", Palette.POST_ABERRATION_PX if aberration else 0.0)
	_material.set_shader_parameter("scanline_dark", Palette.POST_SCANLINE_DARK if crt else 0.0)
	_material.set_shader_parameter("scanline_px", Palette.POST_SCANLINE_PX)
	_material.set_shader_parameter("grille", Palette.POST_GRILLE if crt else 0.0)
	_material.set_shader_parameter("vignette", Palette.POST_VIGNETTE if crt else 0.0)
	_cover.visible = aberration or crt


func aberration_on() -> bool:
	return _aberration


func crt_on() -> bool:
	return _crt


## True while the rectangle is drawn (one of the effects is on).
func drawing() -> bool:
	return _cover.visible


func post_material() -> ShaderMaterial:
	return _material
