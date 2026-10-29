class_name HunterIce
extends IcePiece
## Hunter ICE (I1): mobile ICE that tracks the intruder by sight (scripts/ice/hunter_brain.gd, the
## daemons' C27b brain with the hunter's numbers and its lance) and adapts: its director keeps, for
## the round, how much damage each weapon has dealt to the system (daemons and ICE alike), and the
## hunter resists the weapon dealt the most, up to the tuning's adapt_max (never immunity); its
## shields' colour shifts toward that weapon's (tint_to()). Its art is scripts/ice/hunter_art.gd.
##
## One from the tuning's hunter_from_round on, at its post; killed, it is gone for hunter_respawn_s,
## then a new one (a new seed) comes from its post. Its body is a hit volume round its hovering
## hull, moved by its brain like a daemon's; nothing walks into it. A ping meeting it mid-tell
## staggers it, as it does a daemon; chmod 000 freezes it as it does a daemon (C29: its lance's tell called
## off, nothing moved till it thaws). On a joiner it plays the host's word.

const HunterArt = preload("res://scripts/ice/hunter_art.gd")

var spawn_seed := 0
var tuning: IceTuning
var brain: HunterBrain
## The colour its shields show now (cobalt, or tinted toward an adapted weapon's).
var shield_color := Palette.HUNTER_COBALT
## How far its trace or lance reaches now, metres (the host's, on a joiner).
var reach_now := 0.0


func _ready() -> void:
	collision_layer = TARGET_LAYER
	collision_mask = 0
	_health = max_health
	tag_text = "hunter ICE"
	_make_art(HunterArt, spawn_seed, _prepare)
	var hull := CylinderShape3D.new()
	hull.radius = 1.05
	hull.height = 1.6
	_shape(hull, Vector3(0.0, tuning.hunter_hover_m, 0.0))
	brain = HunterBrain.new(self, art, tuning)
	brain.take_home()
	frost = Frost.new(Frost.Kind.ICE)  # chmod 000 freezes it (C29)
	(art as HunterArt).lock_share = tuning.hunter_lock_s / tuning.hunter_tell_s


func _prepare(a) -> void:  # untyped: the hunter's own art script
	a.hover = tuning.hunter_hover_m


func _physics_process(_delta: float) -> void:
	if broken or brain == null:
		return
	var look := art as HunterArt
	look.aim_world = brain.aim
	match brain.state:
		DaemonBrain.State.TELL:
			if director != null and director.decides():
				var d = director.daemons
				reach_now = brain.muzzle().distance_to(d.prey_point(brain.prey)) if d != null and d.prey_valid(brain.prey) else tuning.hunter_reach_m * 0.5
			look.trace_len = reach_now
		DaemonBrain.State.STRIKE:
			if director != null and director.decides():
				reach_now = brain.lance_from.distance_to(brain.lance_to)
			look.trace_len = reach_now


## A hit that did not kill it: the flash and spray, and it is roused to hunt whoever is nearest.
func _hurt(point: Vector3, direction: Vector3) -> void:
	super(point, direction)
	if director != null and director.daemons != null:
		brain.on_hit(point, director.daemons)


## Its shields' colour (the director's word when it adapts): only when it changes.
func tint_to(color: Color) -> void:
	if color == shield_color:
		return
	shield_color = color
	art.tint(color, [DaemonArt.Shape.SHIELD], [DaemonArt.Shape.PRISM])


## Its heart, at its hover: where a ping meets it and grep aims (C29).
func aim_point() -> Vector3:
	return global_position + Vector3.UP * tuning.hunter_hover_m


func _derezz_radius() -> float:
	return 1.2


func _derezz_height() -> float:
	return tuning.hunter_hover_m + 0.9
