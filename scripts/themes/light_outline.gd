class_name LightOutline
extends RefCounted
## A light theme's outline on a zombie (P2, W3's Latte zombie): the theme shift (scripts/themes/theme_shift.gd) puts it
## on every zombie it fights while a light theme shows (Catppuccin Latte, or a player's own light palette) and takes it
## off for a dark one. Each set the zombie's art is drawn in gets shaders/light_outline.gdshader as its material_overlay: an
## inverted hull in a saturated red, which the theme's grade turns to the theme's own red. A dark theme is never touched,
## and nothing but a zombie is (the other daemons are lit and read on paper as they are).

const OutlineShader = preload("res://shaders/light_outline.gdshader")
## The rim's colour before the grade: a saturated red, which the grade takes to the theme's own red at full strength.
const INK := Color(1.0, 0.05, 0.1)

## The one material every outlined piece shares (made once, never changed after).
static var _material: ShaderMaterial


static func material() -> ShaderMaterial:
	if _material == null:
		_material = ShaderMaterial.new()
		_material.shader = OutlineShader
		_material.set_shader_parameter("ink", INK)
	return _material


## The outline on (`on`) or off for a daemon's art: every set it is drawn in (DaemonArt.sets(), MultiMeshes of its
## parts), never its glyphs (flat cards, which an inverted hull would show from behind as red cards). Only a set with no
## overlay of its own, or with this one, is changed, so nothing else's overlay is ever taken away.
static func apply(art: Node, on: bool) -> void:
	for node in _pieces(art):
		if node.material_overlay == null or node.material_overlay == material():
			node.material_overlay = material() if on else null


## Whether `art` wears the outline now (any of its sets; the checks).
static func worn(art: Node) -> bool:
	return worn_count(art) > 0


## How many of `art`'s sets wear it (the checks).
static func worn_count(art: Node) -> int:
	var n := 0
	for node in _pieces(art):
		n += 1 if node.material_overlay == material() else 0
	return n


static func _pieces(art: Node) -> Array:
	if art == null or not is_instance_valid(art) or not art.has_method("sets"):
		return []
	return art.sets()
