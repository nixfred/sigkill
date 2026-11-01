class_name SceneTear
extends CanvasLayer
## A reload torn instead of cut (W3; and W2's `cd`, whose 1 to 2 s wait for a room's build it hides): the last frame of
## the old arena held on screen over the reload, glitching, the command typed over it, while the next arena builds
## behind it; then torn away in bands (shaders/scene_tear.gdshader) as soon as the new one is up. It lives on the tree's
## root, not in the arena, so it outlasts the reload, and frees itself when it is done (or after LIFE_S whatever happens).
## Over everything (the colourblind filter included: the frame it holds already went through it). With no frame to hold
## (headless, the tests) it holds nothing and the reload is the plain one.

const TearShader = preload("res://shaders/scene_tear.gdshader")
const Palette = preload("res://scripts/palette.gd")

const LAYER := 101
const NODE_NAME := "SceneTear"
## Frames the new arena runs before the tear starts (its first frames can hitch), the tear's length, the longest it lives.
const SETTLE_FRAMES := 3
const AWAY_S := 0.7
const LIFE_S := 8.0
const TYPE_S := 0.3

## Tears begun this run (the checks).
static var tears := 0

var label := ""
var _scene_id := 0
var _changed_frames := -1
var _away := -1.0
var _life := 0.0
var _rect: TextureRect
var _material: ShaderMaterial
var _text: Control
var _font: Font


## Reloads the arena behind a tear, `label` (the command) typed over the held frame. Falls back to the plain reload when
## there is no frame to hold.
static func reload_scene(tree: SceneTree, text: String) -> void:
	if tree == null or tree.current_scene == null:
		return
	if MissionRunner.mounting() == "":
		hold(tree, text)
	MissionRunner.reload_after_mount(tree, text)


## Holds the frame on screen now, over the next reload. False when there is none to hold (headless).
static func hold(tree: SceneTree, text: String) -> bool:
	if DisplayServer.get_name() == "headless" or tree.root.get_node_or_null(NODE_NAME) != null:
		return false
	var image := tree.root.get_texture().get_image() if tree.root.get_texture() != null else null
	if image == null or image.is_empty():
		return false
	var tear := SceneTear.new()
	tear.label = text
	tear._scene_id = tree.current_scene.get_instance_id()
	tear._make(ImageTexture.create_from_image(image))
	tree.root.add_child.call_deferred(tear)
	tears += 1
	return true


func _make(texture: Texture2D) -> void:
	name = NODE_NAME
	layer = LAYER
	process_mode = Node.PROCESS_MODE_ALWAYS
	_font = Palette.mono_font()
	_material = ShaderMaterial.new()
	_material.shader = TearShader
	_material.set_shader_parameter("seed", float(Time.get_ticks_msec() % 997) * 0.01)
	_material.set_shader_parameter("jitter", 1.0)
	_rect = TextureRect.new()
	_rect.texture = texture
	_rect.stretch_mode = TextureRect.STRETCH_SCALE
	_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_rect.material = _material
	_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_rect)
	_text = Control.new()
	_text.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_text.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_text.draw.connect(_draw_text)
	add_child(_text)


func _process(delta: float) -> void:
	_life += delta
	_material.set_shader_parameter("clock", _life)
	var tree := get_tree()
	if _life >= LIFE_S or tree == null:
		queue_free()
		return
	if _away < 0.0:
		var now := tree.current_scene.get_instance_id() if tree.current_scene != null else 0
		if now != _scene_id:
			_changed_frames += 1
			if _changed_frames >= SETTLE_FRAMES:
				_away = 0.0
	else:
		_away += delta / AWAY_S
		_material.set_shader_parameter("away", _away)
		_material.set_shader_parameter("jitter", maxf(1.0 - _away * 2.0, 0.0))
		if _away >= 1.0:
			queue_free()
			return
	_text.queue_redraw()


func _draw_text() -> void:
	if _away >= 0.0 or label == "":
		return
	var k := _text.size.y / 1080.0
	var size := int(22 * maxf(k, 0.6))
	var typed := clampi(int(label.length() * _life / TYPE_S), 0, label.length())
	var at := Vector2(28.0, _text.size.y - 40.0)
	var shown := label.left(typed)
	var w := _font.get_string_size(shown, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
	_text.draw_rect(Rect2(at.x - 10, at.y - size - 6, w + 40, size + 16), Color(Palette.VOID, 0.75))
	_text.draw_string(_font, at, shown, HORIZONTAL_ALIGNMENT_LEFT, -1, size, Palette.MINT)
	_text.draw_rect(Rect2(at.x + w + 6, at.y - size * 0.8, size * 0.5, size), Palette.MINT)


## Where the tear is (the checks): -1 holding, 0 to 1 tearing away.
func away() -> float:
	return _away
