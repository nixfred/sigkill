class_name FrostLook
extends Node3D
## chmod 000's frost on what it hits (C29): the target's own shell, core and armour MultiMeshes drawn a
## second time as a crystalline crust in the frost opal (shaders/frost_crust.gdshader), pushed out along
## their normals so the crust sits on the creature as it stands and moves; it creeps up from the feet as
## the freeze meter fills, and takes the body whole, thicker and bright once frozen. Over it a tag: the
## meter while it fills ("chmod 000  64%"), and frozen "PERMISSION DENIED" over the mode string
## "---------- 000" with the seconds left. At a freeze a burst of frost chips; when it thaws
## the crust cracks off in a smaller burst (the shooter's own screen hears the freeze: its weapon's hit
## sound, scripts/player.gd). Made the first time the beam meets the target, under its art
## (so it moves with it and hides with the body at a derezz), and kept: nothing is made after that.
##
## For an avatar (scripts/net/remote_player.gd) it wears the crust on a capsule round the body instead
## (of_body()). Cosmetic: it reads the target's meter (a Frost) and draws; nothing is judged here.

const Palette = preload("res://scripts/palette.gd")
const CrustShader = preload("res://shaders/frost_crust.gdshader")
const NODE_NAME := "FrostLook"
## The tag: how far over the target's own name tag, its font size and size on screen (fixed), and how
## often its numbers are written again.
const TAG_ABOVE_M := 0.55
const TAG_FONT := 24
const TAG_PIXEL := 0.0009
const TAG_OUTLINE := 8
const TAG_EVERY_S := 0.1
const CHILL_LINE := "chmod 000  %d%%"
const DENIED_LINE := "PERMISSION DENIED\n---------- 000  %.1fs"
## The bursts: how many of the pool's chips a freeze and a thaw throw (a share), and the most a burst
## spreads round the body's middle, metres.
const FREEZE_BURST := 1.0
const THAW_BURST := 0.45
const BURST_LAST_M := 1.0
## A body's height when its parts give none.
const HEIGHT_FIRST := 0.8
## The avatar's capsule crust, round its body.
const BODY_RADIUS := 0.46
const BODY_HEIGHT := 1.62

static var _material: ShaderMaterial

var _ghosts: Array[GeometryInstance3D] = []
## An avatar's capsule crust (null on a daemon's art).
var _shell: MeshInstance3D
var _tag: Label3D
var _frost: Frost
var _base_y := 0.0
var _height := 2.0
## The body's lowest point in its art's own space (its parts as posed when the look was made).
var _low := DaemonArt.GROUND_Y
var _shown := -1.0
var _was_frozen := false
var _tag_wait := 0.0
var _any := false
## A line of the owner's own for the tag instead of the meter's (Black ICE's "Operation not permitted").
var line := ""


## The frost of `art`'s target, made under it the first time, reading `frost`.
static func of(art: DaemonArt, frost: Frost) -> FrostLook:
	var found := find(art)
	if found != null:
		found._frost = frost
		return found
	var look := FrostLook.new()
	look._setup_art(art, frost)
	art.add_child(look)
	return look


## The frost on an avatar's body (`body` its root, its feet at its origin less `feet`).
static func of_body(body: Node3D, frost: Frost, feet: float) -> FrostLook:
	var found := find(body)
	if found != null:
		found._frost = frost
		return found
	var look := FrostLook.new()
	look._setup_body(frost, feet)
	body.add_child(look)
	return look


static func find(holder: Node) -> FrostLook:
	if holder == null or not is_instance_valid(holder):
		return null
	return holder.get_node_or_null(NODE_NAME) as FrostLook


## The crust's one material, every target's: made once.
static func material() -> ShaderMaterial:
	if _material == null:
		_material = ShaderMaterial.new()
		_material.shader = CrustShader
		_material.set_shader_parameter("frost", Palette.FROST)
		_material.set_shader_parameter("edge", Palette.FROST_TEXT)
		_material.set_shader_parameter("glint", Palette.FROST_HI)
	return _material


func _setup_art(art: DaemonArt, frost: Frost) -> void:
	name = NODE_NAME
	_frost = frost
	var sets := art.sets()
	for i in sets.size():
		if art.set_look(i) == DaemonArt.Look.TRAIL:
			continue
		var ghost := MultiMeshInstance3D.new()
		ghost.name = "Crust%d" % i
		ghost.multimesh = sets[i].multimesh
		ghost.transform = sets[i].transform
		ghost.custom_aabb = sets[i].custom_aabb
		ghost.material_override = material()
		ghost.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(ghost)
		_ghosts.append(ghost)
	# The body's height from its own parts as they stand (a tall name tag is no measure of it).
	var box := art.pose_bounds()
	var scale := art.global_transform.basis.get_scale().y if art.is_inside_tree() else 1.0
	_height = clampf(box.size.y * scale, HEIGHT_FIRST, 8.0) if box.size.y > 0.0 else maxf(art.tag_height * 0.85, HEIGHT_FIRST)
	_low = box.position.y if box.size.y > 0.0 else DaemonArt.GROUND_Y
	_make_tag(art.tag_height + TAG_ABOVE_M)
	visible = false


func _setup_body(frost: Frost, feet: float) -> void:
	name = NODE_NAME
	_frost = frost
	var shell := MeshInstance3D.new()
	shell.name = "Crust"
	var capsule := CapsuleMesh.new()
	capsule.radius = BODY_RADIUS
	capsule.height = BODY_HEIGHT
	capsule.radial_segments = 12
	capsule.rings = 4
	shell.mesh = capsule
	shell.material_override = material()
	shell.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	shell.position = Vector3(0.0, BODY_HEIGHT * 0.5 - feet, 0.0)
	add_child(shell)
	_ghosts.append(shell)
	_shell = shell
	_height = BODY_HEIGHT
	_make_tag(BODY_HEIGHT - feet + 0.55)
	visible = false


func _make_tag(at_y: float) -> void:
	_tag = Label3D.new()
	_tag.name = "Tag"
	_tag.position.y = at_y
	_tag.font = Palette.mono_font()
	_tag.font_size = TAG_FONT
	_tag.fixed_size = true
	_tag.pixel_size = TAG_PIXEL
	_tag.outline_size = TAG_OUTLINE
	_tag.modulate = Palette.FROST_TEXT
	_tag.outline_modulate = Palette.VOID
	_tag.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_tag.shaded = false
	_tag.no_depth_test = true  # read whole, never cut by a spike or a plate in front of it
	_tag.render_priority = Material.RENDER_PRIORITY_MAX
	_tag.visible = false
	add_child(_tag)


## The meter this look reads (a joiner's copy or the target's own).
func frost() -> Frost:
	return _frost


## How much of the body the frost shows now: the meter, full while frozen.
func shown() -> float:
	return _shown


func tag_text() -> String:
	return _tag.text if _tag != null and _tag.visible else ""


func crusts() -> Array[GeometryInstance3D]:
	return _ghosts


func _process(delta: float) -> void:
	if _frost == null:
		return
	var now := _frost.shown()
	var frozen := _frost.frozen()
	if frozen != _was_frozen:
		_burst(FREEZE_BURST if frozen else THAW_BURST)
		_was_frozen = frozen
		_tag_wait = 0.0
	_any = now > 0.001 or frozen
	visible = _any
	if not _any:
		_shown = 0.0
		return
	var base := _shell.global_position.y - _height * 0.5 if _shell != null else _feet_y()
	for ghost in _ghosts:
		ghost.set_instance_shader_parameter(&"coverage", now)
		ghost.set_instance_shader_parameter(&"frozen", 1.0 if frozen else 0.0)
		ghost.set_instance_shader_parameter(&"base_y", base)
		ghost.set_instance_shader_parameter(&"height_m", _height)
	_shown = now
	_tag_wait -= delta
	if _tag_wait <= 0.0:
		_tag_wait = TAG_EVERY_S
		_tag.visible = true
		if line != "":
			_tag.text = line
		else:
			_tag.text = DENIED_LINE % maxf(_frost.frozen_left, 0.0) if frozen else CHILL_LINE % roundi(now * 100.0)


## Where the target's feet are (world y): its body's lowest point.
func _feet_y() -> float:
	var art := get_parent() as Node3D
	return art.to_global(Vector3(0.0, _low, 0.0)).y if art != null else global_position.y


## A burst of frost chips off the body.
func _burst(share: float) -> void:
	if not is_inside_tree():
		return
	var holder := get_parent() as Node3D
	if share < FREEZE_BURST and holder != null and not holder.is_visible_in_tree():
		return  # a thaw on a body already gone (a shatter) throws nothing more
	var fx := ParticleFx.of(self)
	if fx != null:
		var feet := _shell.global_position.y - _height * 0.5 if _shell != null else _feet_y()
		var middle := Vector3(global_position.x, feet + _height * 0.5, global_position.z)
		fx.frost(middle, minf(_height * 0.35, BURST_LAST_M), share)
