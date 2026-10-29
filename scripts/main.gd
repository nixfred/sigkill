extends Node3D
## Root of the prototype level. Wires targets and the player to the HUD (its round HUD
## counts each round from their signals), and handles "respawn all targets" (reloads the
## scene). Settings (C16b): puts the engine's into effect when it loads and on every change
## (scripts/settings/settings_apply.gd), and the graphics settings into the arena: bloom (the
## environment's glow), shadows (the sun's; the room light never casts any) and the code rain
## (C16b); SSAO, SSR, the full or plain skyline, the particle level, and the two screen post
## effects (A4). It makes the arena's particle pool and post layer once, when it loads, and
## (C27b) the daemons' director and this player's life alone: the daemons fight back; and (I1) ICE's
## director beside it, which builds the system's walls, nodes and hunter each round.

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
	add_child(ParticleFx.new())
	add_child(ScreenPost.new())
	# The daemons fight back (C27b): this player's health alone, and the director that steps
	# every daemon's brain.
	var life := SoloLife.new()
	life.player = _player
	add_child(life)
	var director := DaemonDirector.new()
	director.player = _player
	director.life = life
	add_child(director)
	# ICE (I1): the system's own defences, beside the daemons, built each round.
	var ice := IceDirector.new()
	ice.daemons = director
	ice.player = _player
	ice.life = life
	ice.rounds = _hud.round_hud()
	add_child(ice)
	_hud.set_ice(ice)
	_hud.set_solo_life(life)
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
		life.session = session
		director.session = session
		ice.session = session
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
	Palette.apply_arena_environment(world_env.environment)


## The graphics settings in the arena: bloom, shadows and the code rain on or off (C16b); SSAO,
## SSR, the full or plain skyline, the particle level and the post effects (A4).
func apply_quality() -> void:
	var g := GameSettings.current().graphics()
	var world_env := find_child("WorldEnvironment", true, false) as WorldEnvironment
	if world_env != null and world_env.environment != null:
		var env := world_env.environment
		env.glow_enabled = g["bloom"]
		env.ssao_enabled = g["ssao"]
		env.ssr_enabled = g["ssr"]
	var sun := get_node_or_null("Sun") as Light3D
	if sun != null:
		sun.shadow_enabled = g["shadows"]
	var rain := get_node_or_null("Arena/CodeRain")
	if rain != null and rain.has_method("set_enabled"):
		rain.set_enabled(g["code_rain"])
	var skyline := get_node_or_null("Arena/Skyline")
	if skyline != null and skyline.has_method("set_full"):
		skyline.set_full(g["skyline"])
	var fx := get_node_or_null("ParticleFx") as ParticleFx
	if fx != null:
		fx.set_level(g["particles"])
	else:
		ParticleFx.level = g["particles"]
	var post := get_node_or_null("ScreenPost") as ScreenPost
	if post != null:
		post.set_effects(g["chromatic_aberration"], g["crt"])


func _on_setting_changed(section: String, key: String) -> void:
	var s := GameSettings.current()
	if section == "" or section == "audio":
		SettingsApply.apply_audio(s)
	if section == "" or section == "video":
		SettingsApply.apply_display(s, get_tree())
		if section == "" or GameSettings.GRAPHICS_KEYS.has(key):
			apply_quality()
	if section == "" or section == GameSettings.BINDS:
		Controls.apply_binds(s.binds())


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("reset_arena") and not _hud.is_typing():
		get_tree().reload_current_scene()


func _on_target_downed(dummy: Node3D) -> void:
	# Every daemon down counts on the screen; only this player's kills count as its own (C27b: in
	# a match where they fight, another player's kill of the host's daemon is not).
	if dummy.get("credited") != false:
		_player.on_dummy_downed()  # alone, a kill toward a sudo charge (C22)
		_hud.note_kill()
	_remaining -= 1
	_hud.set_targets(_remaining, _total)


func _on_target_respawned(_dummy: Node3D) -> void:
	_remaining += 1
	_hud.set_targets(_remaining, _total)


func _on_shot_fired(hit_target: bool) -> void:
	_hud.on_shot(hit_target)
