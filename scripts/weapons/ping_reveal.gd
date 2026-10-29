class_name PingReveal
extends Node3D
## A daemon outlined by ping (C28), on the pinger's screen alone: the daemon's own shell and core
## MultiMeshes drawn a second time through the level in lime (shaders/ping_reveal.gdshader), so the
## outline is the creature as it stands and moves, and a small tag over it, its name and how far it
## is, through the level too. Made the first time a ping meets the daemon, under its art (so it moves
## with it and hides with the body at a derezz), and kept: a later ping only lights it again. Nothing
## is made after that: while lit it holds, eases out over the reveal's last fade and goes dark, and
## a derezz ends it at once.
##
## Cosmetic: it reads the art's own MultiMeshes and the daemon's name; nothing is judged here.

const Palette = preload("res://scripts/palette.gd")
const RevealShader = preload("res://shaders/ping_reveal.gdshader")
const NODE_NAME := "PingReveal"
## The tag: how far over the daemon's own name tag, its font size, its size on screen (fixed: the
## same near or far, so a far daemon's still reads), and how often its distance is written again.
const TAG_ABOVE_M := 0.4
const TAG_FONT := 34
const TAG_PIXEL := 0.0009
const TAG_OUTLINE := 8
const TAG_EVERY_S := 0.2
const TAG_LINE := "%s  %dm"

static var _material: ShaderMaterial

var _ghosts: Array[MultiMeshInstance3D] = []
var _tag: Label3D
var _art: DaemonArt
var _name := ""
var _left := 0.0
var _fade := 0.0
var _strength := 0.0
var _sent := -1.0
var _tag_wait := 0.0


## The reveal of `art`'s daemon, made under it the first time (its name `daemon_name` on the tag).
static func of(art: DaemonArt, daemon_name: String) -> PingReveal:
	var found := find(art)
	if found != null:
		return found
	var reveal := PingReveal.new()
	reveal._setup(art, daemon_name)
	art.add_child(reveal)
	return reveal


## The reveal under `art`, or null when no ping has met its daemon yet.
static func find(art: Node) -> PingReveal:
	if art == null or not is_instance_valid(art):
		return null
	return art.get_node_or_null(NODE_NAME) as PingReveal


## The outline's one material, every daemon's: made once.
static func material() -> ShaderMaterial:
	if _material == null:
		_material = ShaderMaterial.new()
		_material.shader = RevealShader
		_material.set_shader_parameter("color", Palette.LIME)
		_material.set_shader_parameter("scan_color", Palette.LIME_HI)
		_material.render_priority = Material.RENDER_PRIORITY_MAX
	return _material


func _setup(art: DaemonArt, daemon_name: String) -> void:
	name = NODE_NAME
	_art = art
	_name = daemon_name
	visible = false
	var sets := art.sets()
	for i in sets.size():
		if art.set_look(i) == DaemonArt.Look.TRAIL:
			continue
		var ghost := MultiMeshInstance3D.new()
		ghost.name = "Outline%d" % i
		ghost.multimesh = sets[i].multimesh
		ghost.transform = sets[i].transform
		ghost.custom_aabb = sets[i].custom_aabb
		ghost.material_override = material()
		ghost.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(ghost)
		_ghosts.append(ghost)
	_tag = Label3D.new()
	_tag.name = "Tag"
	_tag.position.y = art.tag_height + TAG_ABOVE_M
	_tag.font = Palette.mono_font()
	_tag.font_size = TAG_FONT
	_tag.fixed_size = true
	_tag.pixel_size = TAG_PIXEL
	_tag.outline_size = TAG_OUTLINE
	_tag.modulate = Palette.LIME_HI
	_tag.outline_modulate = Palette.VOID
	_tag.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_tag.no_depth_test = true
	_tag.render_priority = Material.RENDER_PRIORITY_MAX
	_tag.shaded = false
	add_child(_tag)


## Lights it for `seconds`, easing out over the last `fade_s` of them; a ping meeting it again while
## lit starts it over.
func light(seconds: float, fade_s: float) -> void:
	_left = maxf(seconds, 0.0)
	_fade = clampf(fade_s, 0.0001, maxf(seconds, 0.0001))
	_tag_wait = 0.0
	visible = _left > 0.0
	_step(0.0)


## Puts it out now.
func end() -> void:
	_left = 0.0
	_step(0.0)


## True while it shows the daemon.
func lit() -> bool:
	return _left > 0.0


## How strong the outline is now: 1 while it holds, easing to 0 over its fade.
func strength() -> float:
	return _strength


func seconds_left() -> float:
	return _left


func tag_text() -> String:
	return _tag.text if _tag != null else ""


## The outline's nodes: one per shell and core set of the daemon's art.
func outlines() -> Array[MultiMeshInstance3D]:
	return _ghosts


func _process(delta: float) -> void:
	if _left > 0.0:
		_step(delta)


func _step(delta: float) -> void:
	# A derezz ends it: the body is gone.
	if _art != null and is_instance_valid(_art) and _art.is_inside_tree() and not _art.is_visible_in_tree():
		_left = 0.0
	_left = maxf(_left - delta, 0.0)
	_strength = clampf(_left / _fade, 0.0, 1.0) if _left > 0.0 else 0.0
	visible = _left > 0.0
	if _strength != _sent:
		for ghost in _ghosts:
			ghost.set_instance_shader_parameter(&"reveal", _strength)
		_tag.modulate.a = _strength
		_tag.outline_modulate.a = _strength
		_sent = _strength
	_tag_wait -= delta
	if visible and _tag_wait <= 0.0:
		_tag_wait = TAG_EVERY_S
		var camera := get_viewport().get_camera_3d() if is_inside_tree() else null
		var far := camera.global_position.distance_to(global_position) if camera != null else 0.0
		_tag.text = TAG_LINE % [_name, roundi(far)]
