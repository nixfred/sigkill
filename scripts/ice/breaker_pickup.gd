class_name BreakerPickup
extends Node3D
## An ICEbreaker pickup (I2): one breaker of its kind lying in the arena mid-round, at one of the
## director's spots (scripts/ice/breaker_director.gd), hovering over its plinth with its kind's emblem
## and a beam of ultraviolet light standing from it so it reads from across the arena
## (scripts/ice/breaker_art.gd), its kind's name on a tag over it. An intruder walking within the
## tuning's pickup_take_m takes it, unless it already carries that kind's cap; then it stays for someone
## else. The director decides who takes it (alone this player; hosting, every player; on a joiner it is
## the host's word). Fiction only.

const BreakerArt = preload("res://scripts/ice/breaker_art.gd")
const Kinds = preload("res://scripts/ice/breakers.gd")
const Palette = preload("res://scripts/palette.gd")

## Its kind (Breakers.Kind), its spot in the director's list, its seed; set before it enters the tree.
var kind := 0
var spot := 0
var spawn_seed := 0
var art: DaemonArt

var _tag: Label3D


func _ready() -> void:
	var holder := Node3D.new()
	holder.name = "Look"
	holder.position = Vector3.UP * 0.9
	add_child(holder)
	art = BreakerArt.new()
	art.form = "pickup"
	art.kind = kind
	art.setup(self, spawn_seed)
	holder.add_child(art)
	# Small and hovering: no shadow, half its draw calls.
	for node in art.sets():
		node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_tag = Label3D.new()
	_tag.name = "Tag"
	_tag.text = Kinds.name_of(kind)
	_tag.font = Palette.mono_font()
	_tag.font_size = 48
	_tag.pixel_size = 0.006
	_tag.outline_size = 10
	_tag.modulate = Palette.BREAKER_TEXT
	_tag.outline_modulate = Palette.VOID
	_tag.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_tag.position = Vector3.UP * (0.9 + art.tag_y())
	add_child(_tag)


func tag_text() -> String:
	return _tag.text if _tag != null else ""


## Taken: a burst of its own parts in its colour, and it goes.
func taken() -> void:
	var fx := ParticleFx.of(self)
	if fx != null:
		fx.blast(global_position + Vector3.UP * 1.2, Palette.BREAKER, 2.0)
	queue_free()
