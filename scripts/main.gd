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
## Missions (C35): the arena's mission runner (scripts/missions/mission_runner.gd) beside the directors; a mission
## queued before this load (the Missions screen, a retry, the next one, or R mid-mission) begins as it loads, and the
## Missions screen opens after a mission's "Missions". The flag --mission=<id> (with --demo, or under --script: the
## tests and captures) begins that mission once a run, the hidden test range included. Ruins (C36): when the mission
## queued names a ruins district (or a set is queued with no mission: --ruins=<id> with --demo, the tests', the
## captures'), the arena stands in it, staged before anything else is made (scripts/ruins/ruins_stage.gd): its level
## gone, the ruins built in its place, the player, its spawns, the daemons and the ICEbreakers' pickups at their points.
## A mission's own daemons (C37) count as the arena's: each one its runner says climbed out (daemon_spawned) is watched
## like the scene's own (a kill toward sudo, the kill count, the feats), and the runner holds the ICEbreakers' director
## to lock it while the mission has not handed them over. The Audit Trail visor (C43, scripts/visor/audit_visor.gd) stands
## beside them all, on the player's I. The process hunt (W1, scripts/procs/proc_hunt.gd: live process enemies) stands
## beside them too, begun when the Esc menu queued it (or --procs on a demo or test run), never with a mission queued.
## Split-screen co-op (W6, scripts/coop/coop_hunt.gd) stands beside them as well: begun when queued (or --coop on a demo
## or test run), it makes a second player and splits the window's view in two tiles; the daemons' director hunts both.

const Controls = preload("res://scripts/controls.gd")
const Palette = preload("res://scripts/palette.gd")
const NetSession = preload("res://scripts/net/net_session.gd")
const SettingsApply = preload("res://scripts/settings/settings_apply.gd")
const SettingsFile = preload("res://scripts/settings/settings_file.gd")
## The game's own flag that starts the opener (C38) as the arena loads, from the Esc menu, as if picked there: for
## the tests and the captures. The first launch's own (C42: the card, then the opener once) is the Esc menu's.
const OPENER_FLAG := "--opener"
## The dev and capture flag that begins a mission as the arena loads (C35): --mission=<id>, with --demo or under --script.
const MISSION_FLAG := "--mission="

## The flag is taken once a run: an R reload of the arena never plays the opener again.
static var _opener_flag_taken := false
## The first launch (C42) is looked at once a run, as the arena first loads.
static var _first_launch_taken := false
## --mission=<id> is taken once a run (C35), and --ruins=<id> (C36).
static var _mission_flag_taken := false
static var _ruins_flag_taken := false

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
	_take_mission_flag()
	if not _ruins_flag_taken:
		_ruins_flag_taken = true
		RuinsStage.take_flag(launch_args)
	_apply_palette_to_environment()
	# Never in a match: a session already beside the arena and online is looked at, never made (NetSession.of() makes one).
	var session_now = get_parent().get_node_or_null(NetSession.NODE_NAME) if get_parent() != null else null
	var ruins: RuinsWorld = null
	var alone: bool = session_now == null or not session_now.has_method("is_online") or not session_now.is_online()
	# The folder map (W2): the room for the folder it stands in, queued for the stage when the map is (alone, no mission).
	var guide_now = _hud.guide()
	var link = guide_now.session_link() if guide_now != null and guide_now.has_method("session_link") else null
	FolderMap.prepare(launch_args, not alone, AuditVisor.real_gate_for(link))
	# The theme shift (W3): the district of the level it is on, queued for the stage when it is (alone, no mission).
	ThemeShift.prepare(launch_args, not alone, AuditVisor.real_gate_for(link))
	# Keybind gunplay (W4): its district queued for the stage when it is (alone, no mission).
	KeybindGunplay.prepare(launch_args, not alone, AuditVisor.real_gate_for(link))
	# The packet tracer (W5): the network of invented machines stands where the arena's level was (alone, no mission).
	var net: PacketNet = null
	var net_wanted := PacketTracer.prepare(launch_args, not alone)
	# Split-screen co-op (W6): the regular arena, split in two tiles, when queued (alone, no mission).
	CoopHunt.prepare(launch_args, not alone)
	if alone:
		ruins = RuinsStage.stage(self, RuinsStage.wanted())
		if ruins == null and net_wanted:
			net = PacketNet.stage(self)
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
	if ruins != null:
		var spots := []
		for at in ruins.points_of("breaker"):
			spots.append($Arena.to_local(at))
		breakers.spots = spots
	elif net != null:
		var spots := []
		for i in range(1, net.islands.size()):
			var deck := net.spots(i)
			if not deck.is_empty():
				spots.append($Arena.to_local(deck[deck.size() - 1]))
		breakers.spots = spots
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
	# Missions (C35): one runner, beside the directors; it begins what was queued once the arena is up.
	var runner := MissionRunner.new()
	runner.player = _player
	runner.life = life
	runner.daemons = director
	runner.ice = ice
	runner.rounds = _hud.round_hud()
	runner.world = ruins
	runner.breakers = breakers
	runner.daemon_spawned.connect(_on_mission_daemon)
	# A mission ended where it stood (M2): the arena's own daemons are back on the top table.
	runner.ended.connect(func(): _hud.set_round_targets(get_tree().get_nodes_in_group("targets")))
	add_child(runner)
	if (ruins != null or net != null) and MissionRunner.pending() == "":
		ice.stand_down = true  # ruins with no mission: ICE's walls and nodes stand where the arena's level was
	_hud.set_mission_runner(runner)
	# The Audit Trail visor (C43): every daemon's process and lineage, on I.
	var visor := AuditVisor.new()
	visor.player = _player
	visor.runner = runner
	visor.director = director
	visor.guide = _hud.guide()
	add_child(visor)
	_hud.set_visor(visor)
	_player.visor_pressed.connect(visor.toggle)
	# The process hunt (W1): live process enemies, when queued; its enemies are the arena's own to the HUD and the kills.
	var hunt := ProcHunt.new()
	hunt.player = _player
	hunt.director = director
	hunt.runner = runner
	hunt.ice = ice
	hunt.rounds = _hud.round_hud()
	hunt.guide = _hud.guide()
	hunt.spawned.connect(_on_mission_daemon)
	_hud.set_proc_hunt(hunt)
	add_child(hunt)
	ProcHunt.take_flag(launch_args)
	# The folder map (W2): the player's folder tree as the level, when queued; its daemons the arena's own to the HUD and
	# the kills.
	var fsmap := FolderMap.new()
	fsmap.player = _player
	fsmap.director = director
	fsmap.runner = runner
	fsmap.ice = ice
	fsmap.rounds = _hud.round_hud()
	fsmap.guide = _hud.guide()
	fsmap.visor = visor
	fsmap.spawned.connect(_on_mission_daemon)
	_hud.set_folder_map(fsmap)
	add_child(fsmap)
	# The theme shift (W3): a run of levels in terminal themes' colours, when queued; its daemons the arena's own to the HUD
	# and the kills.
	var themes := ThemeShift.new()
	themes.player = _player
	themes.director = director
	themes.runner = runner
	themes.ice = ice
	themes.rounds = _hud.round_hud()
	themes.guide = _hud.guide()
	themes.visor = visor
	themes.spawned.connect(_on_mission_daemon)
	_hud.set_theme_shift(themes)
	add_child(themes)
	# Keybind gunplay (W4): Omarchy's shortcuts as weapons, when queued; its daemons the arena's own to the HUD and the
	# kills.
	var keys := KeybindGunplay.new()
	keys.player = _player
	keys.director = director
	keys.runner = runner
	keys.ice = ice
	keys.rounds = _hud.round_hud()
	keys.guide = _hud.guide()
	keys.visor = visor
	keys.spawned.connect(_on_mission_daemon)
	_hud.set_keybind_gunplay(keys)
	add_child(keys)
	# The packet tracer (W5): a traceroute across a network of invented machines, when queued; its daemons the arena's own
	# to the HUD and the kills.
	var tracer := PacketTracer.new()
	tracer.player = _player
	tracer.director = director
	tracer.runner = runner
	tracer.ice = ice
	tracer.rounds = _hud.round_hud()
	tracer.guide = _hud.guide()
	tracer.visor = visor
	tracer.spawned.connect(_on_mission_daemon)
	_hud.set_packet_tracer(tracer)
	add_child(tracer)
	# Split-screen co-op (W6): a second player and the screen split in two tiles, when queued; its daemons the arena's own
	# to the HUD and the kills, each kill credited to the player who made it.
	var coop := CoopHunt.new()
	coop.player = _player
	coop.director = director
	coop.runner = runner
	coop.ice = ice
	coop.rounds = _hud.round_hud()
	coop.guide = _hud.guide()
	coop.visor = visor
	coop.hud = _hud
	coop.spawned.connect(_on_mission_daemon)
	director.coop = coop
	_hud.set_coop_hunt(coop)
	add_child(coop)
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
		runner.session = session
	var rain := get_node_or_null("Arena/CodeRain")
	if rain != null:
		rain.viewer = _player
	# The first launch's state (C42) in the game's own settings file, only in a real run: never headless, never under a
	# --script run (the tests and the capture tools), which hand in a file of their own if they want one.
	if DisplayServer.get_name() != "headless" and not OS.get_cmdline_args().has("--script"):
		_hud.pause_menu().first_launch_path = SettingsFile.DEFAULT_PATH
	var queued := MissionRunner.take_pending()
	var after := MissionRunner.take_after()
	if queued[0] != "":
		ProcHunt.clear()  # a mission ends the process hunt (W1)
		FolderMap.clear()  # and the folder map (W2)
		ThemeShift.clear()  # and the theme shift (W3)
		KeybindGunplay.clear()  # and keybind gunplay (W4)
		PacketTracer.clear()  # and the packet tracer (W5)
		CoopHunt.clear()  # and split-screen co-op (W6)
	elif CoopHunt.queued and (session == null or not session.is_online()):
		_first_launch_taken = true
		coop.begin.call_deferred()
	elif PacketTracer.queued and (session == null or not session.is_online()):
		_first_launch_taken = true
		tracer.begin.call_deferred()
	elif KeybindGunplay.queued and (session == null or not session.is_online()):
		_first_launch_taken = true
		keys.begin.call_deferred()
	elif ThemeShift.queued and (session == null or not session.is_online()):
		_first_launch_taken = true
		themes.begin.call_deferred()
	elif FolderMap.queued and (session == null or not session.is_online()):
		_first_launch_taken = true
		fsmap.begin.call_deferred()
	elif ProcHunt.queued and (session == null or not session.is_online()):
		_first_launch_taken = true
		hunt.begin.call_deferred()
	if queued[0] != "":
		_first_launch_taken = true
		_begin_mission.call_deferred(queued[0], queued[1])
	elif after == MissionRunner.AFTER_MISSIONS:
		_first_launch_taken = true
		_hud.pause_menu().open_missions.call_deferred()
	if launch_args.has(OPENER_FLAG) and not _opener_flag_taken:
		_opener_flag_taken = true
		_first_launch_taken = true
		_play_opener.call_deferred()
	elif not _first_launch_taken:
		_first_launch_taken = true
		_hud.pause_menu().begin_first_launch.call_deferred()


## --mission=<id> (C35): queued once a run, only with --demo or under --script (the tests and the captures).
func _take_mission_flag() -> void:
	if _mission_flag_taken:
		return
	for arg in launch_args:
		if arg.begins_with(MISSION_FLAG):
			_mission_flag_taken = true
			if launch_args.has("--demo") or OS.get_cmdline_args().has("--script"):
				MissionRunner.queue(arg.trim_prefix(MISSION_FLAG), 1)
			return


## The mission queued before this load, begun: the runner's own checks (alone, built) decide.
func _begin_mission(id: String, try: int) -> void:
	var runner := MissionRunner.of(self)
	var def := MissionBook.of(id)
	if runner != null and def != null:
		runner.begin(def, try)


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
	var ruins := get_node_or_null("Arena/" + RuinsWorld.NODE_NAME) as RuinsWorld
	if ruins != null:
		ruins.apply_quality(g)


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
		if MissionRunner.pending() != "":
			MissionRunner.mark_fade()  # R mid-mission: its next try comes in from black (C36)
		get_tree().reload_current_scene()


func _on_target_downed(dummy: Node3D) -> void:
	# Every daemon down counts on the screen; only this player's kills count as its own (C27b: in
	# a match where they fight, another player's kill of the host's daemon is not).
	_credit_kill(dummy)
	_remaining -= 1
	_hud.set_targets(_remaining, _total)


## A mission's own daemon down (C37): this player's kill, as any; the arena's counter is not its.
func _on_mission_downed(dummy: Node3D) -> void:
	_credit_kill(dummy)


func _credit_kill(dummy: Node3D) -> void:
	var coop := CoopHunt.of(self)
	if coop != null and coop.running and coop.killer_seat(dummy) == 2:
		# Player 2's kill in co-op (W6): its own sudo count; the unlocks are player 1's profile's, earned by player 1.
		if coop.player2 != null and is_instance_valid(coop.player2):
			coop.player2.on_dummy_downed()
		_hud.note_kill()
		return
	if dummy.has_meta(&"world") and not ProcHunt.world_credit_ok():
		_hud.note_kill()
		return  # a world mode's kill past its share (W2): on the screen, but no sudo charge or feat toward an unlock
	if dummy.get("credited") != false:
		_player.on_dummy_downed()  # alone, a kill toward a sudo charge (C22)
		_hud.note_kill()
		# This player's kill, judged here (alone, or hosting): a feat toward its unlocks (C33).
		var weapon = dummy.get("killed_with")
		if weapon is String and weapon != "":
			Progress.judged_feat(self, "kills_" + weapon)
		if dummy.get("shattered_last") == true:
			Progress.judged_feat(self, "shatters")


## A mission's own daemon climbed out (C37): watched as the scene's own, and on the top table. A piece of its own ICE
## (M4) is the ICE director's to judge (its feats land there): only the table.
func _on_mission_daemon(dummy: Node3D) -> void:
	if dummy.has_signal("downed") and not dummy.is_connected("downed", _on_mission_downed):
		dummy.connect("downed", _on_mission_downed)
	_hud.set_round_targets(get_tree().get_nodes_in_group("targets"))


func _process(delta: float) -> void:
	Progress.current().tick(delta)


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		OpenerScore.cancel()  # quitting while the opener's score is still being made: never wait it out (C35)
		CreditsScore.stop()  # and the credits' (C44)
	if what == NOTIFICATION_WM_CLOSE_REQUEST or what == NOTIFICATION_EXIT_TREE:
		Progress.current().flush()


func _on_target_respawned(_dummy: Node3D) -> void:
	_remaining += 1
	_hud.set_targets(_remaining, _total)


func _on_shot_fired(hit_target: bool) -> void:
	_hud.on_shot(hit_target)
