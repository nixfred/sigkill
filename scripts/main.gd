extends Node3D
## Root of the prototype level. Wires targets and the player to the HUD (its round HUD
## counts each round from their signals), and handles "respawn all targets" (reloads the
## scene). Settings (C16b): puts the engine's into effect when it loads and on every change
## (scripts/settings/settings_apply.gd), and the quality preset into the arena: bloom (the
## environment's glow), shadows (the sun's; the room light never casts any) and the code rain.

const Controls = preload("res://scripts/controls.gd")
const Palette = preload("res://scripts/palette.gd")
const NetSession = preload("res://scripts/net/net_session.gd")
const SettingsApply = preload("res://scripts/settings/settings_apply.gd")

var _remaining := 0
var _total := 0

## The game's own command-line arguments after --. A test sets its own before the arena
## enters the tree.
var launch_args: PackedStringArray = OS.get_cmdline_user_args()

# Untyped on purpose: these call methods defined in their own scripts.
@onready var _hud = $Hud
@onready var _player = $Player


func _enter_tree() -> void:
	Controls.ensure()
	SettingsApply.apply_all(GameSettings.current(), get_tree())


func _ready() -> void:
	_apply_palette_to_environment()
	GameSettings.current().changed.connect(_on_setting_changed)
	apply_quality()
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
		if session.take_launch_join(launch_args):
			_hud.net_hud().open()
		session.take_launch_flags(launch_args)  # --light-trails: this run's hosting plays by it (C20)
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


## The quality preset in the arena: bloom, shadows and the code rain on or off.
func apply_quality() -> void:
	var q := GameSettings.current().quality()
	var world_env := find_child("WorldEnvironment", true, false) as WorldEnvironment
	if world_env != null and world_env.environment != null:
		world_env.environment.glow_enabled = q["bloom"]
	var sun := get_node_or_null("Sun") as Light3D
	if sun != null:
		sun.shadow_enabled = q["shadows"]
	var rain := get_node_or_null("Arena/CodeRain")
	if rain != null and rain.has_method("set_enabled"):
		rain.set_enabled(q["code_rain"])


func _on_setting_changed(section: String, key: String) -> void:
	var s := GameSettings.current()
	if section == "" or section == "audio":
		SettingsApply.apply_audio(s)
	if section == "" or section == "video":
		SettingsApply.apply_display(s, get_tree())
		if section == "" or key == "quality":
			apply_quality()
	if section == "" or section == GameSettings.BINDS:
		Controls.apply_binds(s.binds())


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("reset_arena") and not _hud.is_typing():
		get_tree().reload_current_scene()


func _on_target_downed(_dummy: Node3D) -> void:
	_player.on_dummy_downed()  # alone, a kill toward a sudo charge (C22)
	_remaining -= 1
	_hud.note_kill()
	_hud.set_targets(_remaining, _total)


func _on_target_respawned(_dummy: Node3D) -> void:
	_remaining += 1
	_hud.set_targets(_remaining, _total)


func _on_shot_fired(hit_target: bool) -> void:
	_hud.on_shot(hit_target)
