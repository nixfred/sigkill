extends Node3D
## Root of the prototype level. Wires targets and the player to the HUD (its round HUD
## counts each round from their signals), and handles "respawn all targets" (reloads the
## scene). Settings (C16b): puts the engine's into effect when it loads and on every change
## (scripts/settings/settings_apply.gd), and the graphics settings into the arena: bloom (the
## environment's glow), shadows (the sun's; the room light never casts any) and the code rain
## (C16b); SSAO, SSR, the full or plain skyline, the particle level, and the two screen post
## effects (A4). It makes the arena's particle pool and post layer once, when it loads, and
## (C27b) the daemons' director and this player's life alone: the daemons fight back; (I1) ICE's
## director beside it, which builds the system's walls, nodes and hunter each round; (I2) the
## ICEbreakers' director, which keeps every intruder's breakers and runs them; and (I3) the arena's
## blackout, its hum and its lights, which Black ICE takes away while it is out. Unlocks (C33): this player's kills
## of the daemons it judged here count toward its unlocks (scripts/unlocks/progress.gd), saved as rounds end.

const Controls = preload("res://scripts/controls.gd")
const Palette = preload("res://scripts/palette.gd")
const NetSession = preload("res://scripts/net/net_session.gd")
const SettingsApply = preload("res://scripts/settings/settings_apply.gd")
const SettingsFile = preload("res://scripts/settings/settings_file.gd")
## The game's own flag that starts the opener (C38) as the arena loads, from the Esc menu, as if picked there: for
## the tests and the captures. The first launch's own (C42: the card, then the opener once) is the Esc menu's.
const OPENER_FLAG := "--opener"

## The flag is taken once a run: an R reload of the arena never plays the opener again.
static var _opener_flag_taken := false
## The first launch (C42) is looked at once a run, as the arena first loads.
static var _first_launch_taken := false

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
	DaemonVoice.prewarm()  # the daemons' and ICE's sounds (C42), made once a run, here as the arena loads
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
	# ICEbreakers (I2): the intruder's one-use programs against ICE and the daemons, beside them.
	var breakers := BreakerDirector.new()
	breakers.daemons = director
	breakers.ice = ice
	breakers.player = _player
	breakers.rounds = _hud.round_hud()
	add_child(breakers)
	director.breakers = breakers
	ice.breakers = breakers
	_player.breakers = breakers
	# Black ICE (I3): the arena's hum and lights, dimmed and silenced while it is out.
	var blackout := Blackout.new()
	blackout.ice = ice
	add_child(blackout)
	_hud.set_ice(ice)
	_hud.set_breakers(breakers)
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
	# Unlocks (C33): the counts this run earned are saved at each round's end, as the game quits, and at most
	# every half minute between.
	var rounds = _hud.round_hud()
	if rounds != null and rounds.has_signal("round_ended"):
		rounds.round_ended.connect(func(_number: int): Progress.current().flush())
	# LAN and tailnet play (C13): the session lives beside this scene and outlives an R
	# reload; this arena shows its players and sends this player's movement.
	var session = NetSession.of(self)
	if session != null:
		life.session = session
		director.session = session
		ice.session = session
		breakers.session = session
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
	# The first launch's state (C42) in the game's own settings file, only in a real run: never headless, never under a
	# --script run (the tests and the capture tools), which hand in a file of their own if they want one.
	if DisplayServer.get_name() != "headless" and not OS.get_cmdline_args().has("--script"):
		_hud.pause_menu().first_launch_path = SettingsFile.DEFAULT_PATH
	if launch_args.has(OPENER_FLAG) and not _opener_flag_taken:
		_opener_flag_taken = true
		_first_launch_taken = true
		_play_opener.call_deferred()
	elif not _first_launch_taken:
		_first_launch_taken = true
		_hud.pause_menu().begin_first_launch.call_deferred()


## The opener from the Esc menu (C38), as the flag asks.
func _play_opener() -> void:
	_hud.pause_menu().open_opener()


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
		# This player's kill, judged here (alone, or hosting): a feat toward its unlocks (C33).
		var weapon = dummy.get("killed_with")
		if weapon is String and weapon != "":
			Progress.judged_feat(self, "kills_" + weapon)
		if dummy.get("shattered_last") == true:
			Progress.judged_feat(self, "shatters")
	_remaining -= 1
	_hud.set_targets(_remaining, _total)


func _process(delta: float) -> void:
	Progress.current().tick(delta)


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST or what == NOTIFICATION_EXIT_TREE:
		Progress.current().flush()


func _on_target_respawned(_dummy: Node3D) -> void:
	_remaining += 1
	_hud.set_targets(_remaining, _total)


func _on_shot_fired(hit_target: bool) -> void:
	_hud.on_shot(hit_target)
