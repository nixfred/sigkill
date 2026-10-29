class_name IceArt
extends DaemonArt
## What you see of a piece of ICE (I1): the system's own defences, a visual language of their own
## beside the daemons'. Cold crystalline lattice and shield geometry: faceted crystal panes, prisms
## and shields with mass (ICE's crystal look, shaders/ice_crystal.gdshader: near-black cold glass that
## takes the arena's light on its facets), whose light lives in its seams, joints and cores (ICE's
## light look: the core shader, steady, never glitching), in the ICE's own colour: white ICE glacier
## blue, hunter ICE a deeper cobalt. Faceless and geometric, never a box and never a wireframe.
##
## The same rig as the daemons' (scripts/daemons/daemon_art.gd): built once from a seed (no two pieces
## of ICE alike; fixed in demo, test and capture runs, sent by the host in a match), one MultiMesh per
## shape and look, posed by transforms alone, a hit's flash and spray, a burst of its own parts at its
## end, weak points marked with weak() (where I2's exploit breaker will aim). ICE has no elite: its
## frightening tier is Black ICE (I3). Its crack (crack()) is each crystal part's custom data w, drawn
## by the crystal shader as fracture lines spreading across the part.
##
## Each piece is a script extending this one (scripts/ice/barrier_art.gd, node_art.gd,
## hunter_art.gd). Visual only: the piece it dresses keeps its own body, health and states.

## The piece's colour, set by the type before it builds.
var ice_color := Palette.GLACIER


func _init() -> void:
	glyph_count = 0
	budget_triangles = 4000
	budget_draw_calls = 8


## Part `id`'s crack, 0 whole to 1 shattering (a crystal part's custom data w), telling the MultiMesh
## only when it changes.
func crack(id: int, amount: float) -> void:
	var c := _custom[id]
	if c.a == amount:
		return
	c.a = amount
	_custom[id] = c
	_set_mm[_part_set[id]].set_instance_custom_data(_part_slot[id], c)


## `color` on the crystal sets of `crystal` (its facets' inner light, its seams' line and its rim; a
## hunter's shields) and the light sets of `lights` (their spines): only when asked, never every frame.
func tint(color: Color, crystal: Array, lights: Array = []) -> void:
	for bin in _set_shape.size():
		if _set_look[bin] == Look.ICE and crystal.has(_set_shape[bin]):
			_set_node[bin].set_instance_shader_parameter(&"edge_color", color)
		elif _set_look[bin] == Look.ICE_LIGHT and lights.has(_set_shape[bin]):
			_set_node[bin].set_instance_shader_parameter(&"core_color", color)


## Before a type builds: no elite, the piece's colour on its core and its edges.
func _ice_start() -> void:
	elite = false
	core_color = ice_color
	edge_color = ice_color
