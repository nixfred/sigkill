extends Node3D
## Root of the prototype level. Wires targets and the player to the HUD (its round HUD
## counts each round from their signals), and handles "respawn all targets" (reloads the
## scene).

const Controls = preload("res://scripts/controls.gd")
const Palette = preload("res://scripts/palette.gd")
const NetSession = preload("res://scripts/net/net_session.gd")

var _remaining := 0
var _total := 0

# Untyped on purpose: these call methods defined in their own scripts.
@onready var _hud = $Hud
@onready var _player = $Player


func _enter_tree() -> void:
	Controls.ensure()


func _ready() -> void:
	_apply_palette_to_environment()
	var dummies := get_tree().get_nodes_in_group("targets")
	_total = dummies.size()
	_remaining = _total
	for dummy in dummies:
		dummy.connect("downed", _on_target_downed)
		dummy.connect("respawned", _on_target_respawned)
	_player.shot_fired.connect(_on_shot_fired)
	_hud.set_weapon_tuning(_player.weapon_tuning())
	_hud.set_player(_player)
	_hud.set_round_targets(dummies)
	_hud.set_targets(_remaining, _total)
	# LAN and tailnet play (C13): the session lives beside this scene and outlives an R
	# reload; this arena shows its players and sends this player's movement.
	var session = NetSession.of(self)
	if session != null:
		session.attach(self, _player)
		_hud.set_net_session(session)
		# A room code or invite link on the command line (C15), once per run: the panel opens
		# to show what came of it.
		if session.take_launch_join(OS.get_cmdline_user_args()):
			_hud.net_hud().open()
	var rain := get_node_or_null("Arena/CodeRain")
	if rain != null:
		rain.viewer = _player


## The arena scene stores approximate colours so the editor previews the look.
## palette.gd is the single source, so the exact values are applied here at runtime.
func _apply_palette_to_environment() -> void:
	var world_env := find_child("WorldEnvironment", true, false) as WorldEnvironment
	if world_env == null or world_env.environment == null:
		push_error("main: no WorldEnvironment with an Environment found")
		return
	var env := world_env.environment
	env.background_color = Palette.VOID
	env.ambient_light_color = Palette.TEAL
	env.fog_light_color = Palette.VOID


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("reset_arena") and not _hud.is_typing():
		get_tree().reload_current_scene()


func _on_target_downed(_dummy: Node3D) -> void:
	_remaining -= 1
	_hud.note_kill()
	_hud.set_targets(_remaining, _total)


func _on_target_respawned(_dummy: Node3D) -> void:
	_remaining += 1
	_hud.set_targets(_remaining, _total)


func _on_shot_fired(hit_target: bool) -> void:
	_hud.on_shot(hit_target)
