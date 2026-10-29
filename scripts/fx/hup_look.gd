class_name HupLook
extends Node3D
## SIGHUP's confusion on what it caught (C32), over a daemon, the hunter or an ICE node: a tag over its own
## name tag, while it reloads "SIGHUP: reloading config" typed out with its dots and a bar of the reload's
## progress, and while it wanders confused a big "?" bobbing and flickering (now and then doubled); its art
## told the confusion (DaemonArt.hup_phase: its seams cycling in the carrier green, its glitch twitching, its
## pose stuttering, shaders/daemon_core.gdshader). Made the first time the target is hung up, under its art
## (so it moves with it and hides with the body at a derezz), and kept: nothing is made after that. The
## owner says each frame what it is in (show_phase()); a joiner's from the host's word.
##
## Cosmetic: it reads a phase and a share and draws; nothing is judged here.

const Palette = preload("res://scripts/palette.gd")
const NODE_NAME := "HupLook"
## The tag: how far over the target's own name tag, its fonts (fixed size on screen, so a far one reads),
## its outline, and how often the reload's line is written again.
const TAG_ABOVE_M := 0.45
## The "?" sits lower, right over the head.
const WANDER_ABOVE_M := 0.15
const RELOAD_FONT := 26
const WANDER_FONT := 84
const TAG_PIXEL := 0.0009
const TAG_OUTLINE := 10
const TAG_EVERY_S := 0.12
const RELOAD_LINE := "SIGHUP: reloading config%s\n[%s%s]"
const BAR_CELLS := 10
const WANDER_LINE := "?"
const WANDER_DOUBLE := "??"
## The "?"'s bob, metres and hertz, and how often it may flicker or double.
const BOB_M := 0.08
const BOB_HZ := 1.7
const FLICKER_HZ := 9.0
## A hangup's burst of carrier sparks off the target: a share of the pool's.
const HANGUP_BURST := 0.35

var _art: DaemonArt
var _tag: Label3D
var _base_y := 0.0
var _wander_y := 0.0
var _phase := 0
var _share := 0.0
var _clock := 0.0
var _tag_wait := 0.0
var _seed := 0


## The confusion look of `art`'s target, made under it the first time.
static func of(art: DaemonArt) -> HupLook:
	var found := find(art)
	if found != null:
		return found
	var look := HupLook.new()
	look._setup(art)
	art.add_child(look)
	return look


## The look under `art`, or null when it has never been hung up.
static func find(art: Node) -> HupLook:
	if art == null or not is_instance_valid(art):
		return null
	return art.get_node_or_null(NODE_NAME) as HupLook


func _setup(art: DaemonArt) -> void:
	name = NODE_NAME
	_art = art
	_seed = art.build_seed
	_tag = Label3D.new()
	_tag.name = "Tag"
	# Over the name tag: the art's origin is its body's middle, GROUND_Y over the feet the name tag is measured
	# from, and the art is scaled by its size about the ground (A5).
	var size := maxf(art.size_scale, 0.01)
	_base_y = art.tag_height + (DaemonArt.GROUND_Y + TAG_ABOVE_M) / size
	_wander_y = art.tag_height + (DaemonArt.GROUND_Y + WANDER_ABOVE_M) / size
	_tag.position.y = _base_y
	_tag.font = Palette.mono_font()
	_tag.font_size = RELOAD_FONT
	_tag.fixed_size = true
	_tag.pixel_size = TAG_PIXEL
	_tag.outline_size = TAG_OUTLINE
	_tag.modulate = Palette.SIGHUP_TEXT
	_tag.outline_modulate = Palette.VOID
	_tag.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_tag.shaded = false
	_tag.visible = false
	add_child(_tag)


## What the target is in now (DaemonBrain.Hup: 0 none, 1 reloading, 2 wandering) and how far through it,
## 0 to 1: the tag and the art follow it. Starting a reload throws the hangup's sparks.
func show_phase(phase: int, share: float) -> void:
	if phase == 1 and _phase != 1:
		var fx := ParticleFx.of(self) if is_inside_tree() else null
		if fx != null and fx.has_method("hup"):
			fx.hup(_art.global_transform * Vector3.ZERO, HANGUP_BURST)
		_tag_wait = 0.0
	if phase != _phase:
		_tag_wait = 0.0
	_phase = phase
	_share = clampf(share, 0.0, 1.0)
	if _art != null and is_instance_valid(_art):
		_art.hup_phase = phase
	_tag.visible = phase != 0
	_step(0.0)


## The tag's text now ("" when it is hidden), for the checks.
func tag_text() -> String:
	return _tag.text if _tag.visible else ""


func phase() -> int:
	return _phase


func _process(delta: float) -> void:
	if _phase != 0:
		_step(delta)


func _step(delta: float) -> void:
	_clock = fmod(_clock + delta, 3600.0)
	_tag_wait -= delta
	if _phase == 1:
		_tag.position.y = _base_y
		_tag.modulate.a = 1.0
		if _tag_wait <= 0.0:
			_tag_wait = TAG_EVERY_S
			_tag.font_size = RELOAD_FONT
			var lit := clampi(roundi(_share * BAR_CELLS), 0, BAR_CELLS)
			var dots := ".".repeat(int(_clock * 4.0) % 4)
			_tag.text = RELOAD_LINE % [dots, "#".repeat(lit), ".".repeat(BAR_CELLS - lit)]
	elif _phase == 2:
		_tag.font_size = WANDER_FONT
		_tag.position.y = _wander_y + BOB_M * sin(TAU * BOB_HZ * _clock + float(_seed % 97))
		# Now and then it flickers out or doubles, as a signal that keeps dropping does.
		var tick := int(_clock * FLICKER_HZ)
		var roll := DaemonArt.roll_of(_seed, tick, 3)
		_tag.text = WANDER_DOUBLE if roll > 0.86 else WANDER_LINE
		_tag.modulate.a = 0.35 if roll < 0.1 else 1.0
