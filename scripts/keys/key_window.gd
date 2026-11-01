class_name KeyWindow
extends Node3D
## One desktop window in the world (W4, keybind gunplay): a quad drawn by shaders/key_window.gdshader (a thin border in the
## accent, no title bar, as an Omarchy window is; a terminal, a monitor, an editor or nothing inside), and a label over it.
## The shortcuts' effects (scripts/keys/key_fx.gd) and the district's desktop (scripts/keys/keybind_gunplay.gd) are made of
## these. Its own material, so each window has its own numbers; the shader is one, compiled once. Visual only.

const WindowShader = preload("res://shaders/key_window.gdshader")
const Palette = preload("res://scripts/palette.gd")

enum Style { TERMINAL, FRAME, MONITOR, EDITOR }

var mesh: MeshInstance3D
var material: ShaderMaterial
var label: Label3D
var size := Vector2(2.0, 1.4)


static func make(window_size: Vector2, style: Style, accent: Color, title: String = "", seed: float = 0.0) -> KeyWindow:
	var w := KeyWindow.new()
	w.size = window_size
	w.material = ShaderMaterial.new()
	w.material.shader = WindowShader
	w.material.set_shader_parameter("style", int(style))
	w.material.set_shader_parameter("accent", accent)
	w.material.set_shader_parameter("ink", accent.lerp(Color.WHITE, 0.55))
	w.material.set_shader_parameter("seed", seed)
	var quad := QuadMesh.new()
	quad.size = Vector2.ONE
	w.mesh = MeshInstance3D.new()
	w.mesh.name = "Pane"
	w.mesh.mesh = quad
	w.mesh.material_override = w.material
	w.mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	w.mesh.gi_mode = GeometryInstance3D.GI_MODE_DISABLED
	w.add_child(w.mesh)
	if title != "":
		w.label = Label3D.new()
		w.label.name = "Title"
		w.label.font = Palette.mono_font()
		w.label.text = title
		w.label.font_size = 40
		w.label.outline_size = 8
		w.label.outline_modulate = Color(0, 0, 0, 0.85)
		w.label.modulate = accent.lerp(Color.WHITE, 0.35) * 1.3
		w.label.shaded = false
		w.label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		w.label.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
		w.add_child(w.label)
	w.resize(window_size)
	return w


## Its size in metres: the quad, the shader's sizes and the label's place (over its top left corner) follow.
func resize(window_size: Vector2) -> void:
	size = window_size
	mesh.scale = Vector3(size.x, size.y, 1.0)
	material.set_shader_parameter("size", size)
	if label != null:
		label.pixel_size = clampf(size.y * 0.0042, 0.004, 0.02)
		label.position = Vector3(-size.x * 0.5, size.y * 0.5 + 0.06, 0.0)


func set_param(param: StringName, value: Variant) -> void:
	material.set_shader_parameter(param, value)


## Turned to face `eye` (a camera's position), upright.
func face(eye: Vector3) -> void:
	var to := eye - global_position
	to.y = 0.0
	if to.length_squared() < 0.0001:
		return
	global_basis = Basis.looking_at(-to.normalized(), Vector3.UP) * Basis.from_scale(scale)
