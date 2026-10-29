extends SceneTree
## Headless bullet-time test for SIGKILL (C18). scripts/check.sh runs it, and any FAIL exits 1.
##
##   godot --headless --path . --fixed-fps 60 --script res://tests/bullet_time_test.gd
##
## SIGSTOP bullet time (F, SIGCONT on F again): its resource and its numbers, bad values
## refused, the meter's rules; F as a rebindable action, moved, saved to a settings file in a
## temporary folder and loaded back. Then solo in the real arena with the real player: no
## start below the start's share; during SIGSTOP the engine's time scale at exactly the
## resource's value, physics, a falling body and the round clock at that pace, while the
## player still walks, and its weapon cools, at the resource's compensated pace in real time
## (0.8x to 1.0x), with steady hands (no spread, no recoil); the callouts, the look and the
## sound pitched down; the meter draining and refilling by the resource's numbers; and the
## time scale back at exactly 1.0 after SIGCONT, after the meter runs out, after a death,
## after a round's end, after the Esc menu opens, after a stray change and after the arena
## goes away. Then a host and a joiner over ENet on 127.0.0.1 in this one process: the
## joiner's SIGSTOP, by the host's word, never moves the time scale off 1.0, never slows the
## host's clock or anyone's movement; the host draws the joiner's pellets straight only while
## its own count says SIGSTOP is on, ends it when its meter runs out, rejects and counts a
## forged start with the meter empty, and a death empties the meter on both sides.
## Nothing outside this process is touched: SIGSTOP and SIGCONT are fiction, and nothing
## real is stopped, continued or signalled.

const Session = preload("res://scripts/net/net_session.gd")
const Combat = preload("res://scripts/net/combat.gd")
const NetTuningScript = preload("res://scripts/net/net_tuning.gd")
const CombatTuningScript = preload("res://scripts/net/combat_tuning.gd")
const SigstopTuningScript = preload("res://scripts/abilities/sigstop_tuning.gd")
const Meter = preload("res://scripts/abilities/sigstop_meter.gd")
const Sigstop = preload("res://scripts/abilities/sigstop.gd")
const WeaponHud = preload("res://scripts/hud/weapon_hud.gd")
const RoundHud = preload("res://scripts/round/round_hud.gd")
const Controls = preload("res://scripts/controls.gd")
const Link = preload("res://scripts/guide/guide_link.gd")
const MainScene = preload("res://scenes/main.tscn")
const SIGSTOP_PATH := "res://resources/sigstop.tres"
const SIGTERM_PATH := "res://resources/sigterm.tres"
const FX_GROUP := &"cannon_fx"
const WATCHDOG_MS := 10000
const CLIENT_OFFSET := Vector3(1000.0, 0.0, 0.0)
const STAND_Y := 0.95
## Clear lines across the arena, from x -15 to the east wall at x 20.
const LINE_Z := 15.0
const SIDE_Z := 19.0
const START_X := -15.0
const FRAME := 1.0 / 60.0

## Sums the physics time it is handed: the world's own pace.
class Probe extends Node:
	var sum := 0.0

	func _physics_process(delta: float) -> void:
		sum += delta


var _fails := 0
var _checks := 0
var _tmp := ""
var _t: Resource
var _sigterm: Resource
var _arenas: Array = []
var _branches: Array = []


func _initialize() -> void:
	GameSettings.current().set_value("gameplay", "practice", true)  # these checks predate C27b: the daemons stay the old never-attack dummies
	_run()


func _run() -> void:
	await process_frame
	root.size = Vector2i(1280, 720)
	_tmp = OS.get_temp_dir().path_join("sigkill-bullet-time-test-%d" % OS.get_process_id())
	DirAccess.make_dir_recursive_absolute(_tmp)
	Controls.ensure()
	_t = load(SIGSTOP_PATH)
	_sigterm = load(SIGTERM_PATH)
	_tuning_checks()
	_meter_checks()
	_source_checks()
	_rebind_checks()
	await _solo_checks()
	await _match_checks()
	await _cleanup()
	for name in DirAccess.get_files_at(_tmp):
		DirAccess.remove_absolute(_tmp.path_join(name))
	DirAccess.remove_absolute(_tmp)
	print("BULLET TIME: %d checks" % _checks)
	print("BULLET TIME RESULT: ", "ALL PASS" if _fails == 0 else "%d FAILED" % _fails)
	quit(0 if _fails == 0 else 1)


func _check(label: String, ok: bool, detail: String = "") -> void:
	_checks += 1
	print("PASS " if ok else "FAIL ", label, ("   " + detail) if detail != "" else "")
	if not ok:
		_fails += 1


# --- The resource and the meter. ---

func _tuning_checks() -> void:
	var t = _t
	_check("SIGSTOP's numbers are one resource, resources/sigstop.tres: a SigstopTuning that passes its own checks", t is SigstopTuningScript and t.problems().is_empty(), str(t.problems()) if t is SigstopTuningScript else "")
	_check("its numbers: 4 s of slow-mo when full, 20 s to refill from empty, a quarter of the meter to start, the world at 0.3x solo, the player at 0.9x, SIGCONT easing back over 0.25 s", t.meter_s == 4.0 and t.refill_s == 20.0 and t.start_share == 0.25 and t.world_scale == 0.3 and t.player_rate == 0.9 and t.ease_s == 0.25)
	_check("the player's compensated pace sits in 0.8x to 1.0x, well above the world's", t.player_rate >= 0.8 and t.player_rate <= 1.0 and t.world_scale < t.player_rate)
	var cases := [
		["world_scale", 1.0, "world_scale"], ["world_scale", 0.0, "world_scale"], ["player_rate", 0.2, "player_rate"],
		["start_share", 0.0, "start_share"], ["meter_s", 0.0, "meter_s"], ["refill_s", -1.0, "refill_s"],
		["ease_s", 5.0, "ease_s"], ["audio_pitch", 2.0, "audio_pitch"], ["meter_s", NAN, "meter_s"],
	]
	var missed := PackedStringArray()
	for c in cases:
		var bad = _t.duplicate()
		bad.set(c[0], c[1])
		var issues: PackedStringArray = bad.problems()
		if not ", ".join(issues).contains(c[2]):
			missed.append("%s=%s: %s" % [c[0], c[1], issues])
	_check("bad values are refused with the reason: a world at full speed or stopped, a player slower than 0.5x, no start share, no meter, a negative refill, a long ease, a pitch up, NaN", missed.is_empty(), " | ".join(missed))
	var broken = _t.duplicate()
	broken.world_scale = 2.0
	_check("a bad tuning handed to SIGSTOP falls back to the shipped one", Sigstop.usable_tuning(broken).world_scale == 0.3 and Sigstop.usable_tuning(null).meter_s == 4.0)


func _meter_checks() -> void:
	var m := Meter.new(_t)
	_check("a fresh SIGSTOP meter is full, 4 s, and off", m.meter == 4.0 and not m.on and m.share() == 1.0 and m.start_needed() == 1.0)
	m.meter = 0.99
	var low := m.start()
	m.meter = 1.0
	var quarter := m.start()
	_check("a start needs a quarter of the meter: 0.99 s is refused, 1.0 s starts", not low and quarter and m.on)
	m.meter = 4.0
	for i in 60:
		m.tick(FRAME)
	_check("on, it drains one second a second: 3 s left after 60 frames", is_equal_approx(m.meter, 3.0) and m.on, "%.4f" % m.meter)
	var ended := m.tick(3.5)
	var at_end := [m.meter, m.on]
	var again := m.tick(FRAME)
	_check("it ends by itself when empty, once", ended and not again and at_end == [0.0, false])
	m.meter = 0.0
	for i in 300:
		m.tick(FRAME)
	var five_s := m.meter
	m.tick(5.0, false)
	var while_dead := m.meter
	m.meter = 3.9
	m.tick(1.0)
	_check("off, it refills 0.2 s a second, empty to full in 20 s, and caps at full; not while derezzed", is_equal_approx(five_s, 1.0) and while_dead == five_s and m.meter == 4.0, "%.4f %.4f" % [five_s, m.meter])
	m.start()
	m.empty()
	var emptied := [m.meter, m.on]
	m.fill()
	m.take(true, 9.0)
	_check("a death empties it and ends SIGSTOP; a new round fills it; the host's word is taken and kept in range", emptied == [0.0, false] and m.meter == 4.0 and m.on)


func _source_checks() -> void:
	var stop := _code("res://scripts/abilities/sigstop.gd")
	var writes := 0
	var where := PackedStringArray()
	for path in _scripts("res://scripts"):
		var n := _code(path).count("Engine.time_scale =")
		writes += n
		if n > 0:
			where.append(path)
	_check("the engine's time scale is written in two places only, both in scripts/abilities/sigstop.gd: _hold_time, which returns first in a match, and restore_time, which writes exactly 1.0", writes == 2 and where == PackedStringArray(["res://scripts/abilities/sigstop.gd"]) and _body(stop, "_hold_time").contains("if _online():\n\t\treturn\n\t_time_holder = self\n\tEngine.time_scale = scale") and _body(stop, "restore_time").contains("Engine.time_scale = 1.0"), "%d in %s" % [writes, where])
	var real := PackedStringArray()
	for path in _scripts("res://scripts/abilities"):
		var code := _code(path)
		for word in ["OS.execute", "OS.kill", "create_process", "get_process_id", "OS.shell", "FileAccess", "DirAccess"]:
			if code.contains(word):
				real.append("%s: %s" % [path, word])
	_check("SIGSTOP and SIGCONT are fiction: nothing in the ability runs, signals or reads a real process or file", real.is_empty(), ", ".join(real))
	var session := _code("res://scripts/net/net_session.gd")
	_check("the wire: protocol 4 then (5 since C19's fork bomb, 6 since C20's light trails, 7 since C22's sudo, 8 since C23's top table, 9 since C25's grep marks, 10 since C27b's daemons, 11 since A5's daemon seeds, 12 since I1's ICE, 13 since I2's ICEbreakers, 14 since I3's Black ICE, 15 since C29's chmod 000, 16 since C30's pipe |), twelve RPCs then (fifteen since C19, seventeen since C20, nineteen since C22, twenty since C23, twenty-four since C27b, twenty-six since I1, twenty-eight since I2 and I3); the ask is untyped and type-checked from any peer, the host's word an authority RPC to one player", Session.PROTOCOL == 16 and session.count("@rpc(") == 28 and session.contains('@rpc("any_peer", "call_remote", "reliable")\nfunc _sigstop(life: Variant, on: Variant) -> void:') and _body(session, "_sigstop").contains("typeof(life) != TYPE_INT or typeof(on) != TYPE_BOOL") and session.contains('@rpc("authority", "call_remote", "reliable")\nfunc _sigstop_state(life: int, on: bool, left: float) -> void:') and _body(session, "_send_sigstop").contains("_sigstop_state.rpc_id(id,"))
	var combat := _code("res://scripts/net/combat.gd")
	_check("the host owns the meter: a start is believed only when its own meter can pay for it, a refused one is counted, and its word is sent back either way", _body(combat, "sigstop").contains("if stop.on or stop.start():") and _body(combat, "sigstop").contains("return _drop(DROP_SIGSTOP)") and _body(session, "_handle_sigstop").contains("combat.sigstop(") and _body(session, "_handle_sigstop").contains("_send_sigstop(id)"))
	_check("zero spread only on the host's word: the host draws a player's pellets straight only while its own count says that SIGSTOP is on", _body(session, "_handle_fire").contains("var steady := combat.sigstop_on(shooter)") and _body(session, "_handle_fire").contains("def.steady_directions(dir) if steady else def.pellet_directions(dir, _pellets_rng)"))
	var round := _code("res://scripts/round/round_hud.gd")
	var sigstop_call := _body(round, "_on_sigstop") + _body(round, "_on_sigcont")
	_check("'SIGSTOP' and 'SIGCONT' are game-logic callouts: never the link or the announcer", sigstop_call.contains("_callout(\"sigstop\", true)") and sigstop_call.contains("_callout(\"sigcont\", true)") and not sigstop_call.contains("link") and not sigstop_call.contains("announcer"))


func _rebind_checks() -> void:
	var events := InputMap.action_get_events("sigstop")
	_check("F is SIGSTOP's key: a rebindable action shown as 'SIGSTOP' in the settings' list, F by default, clashing with nothing", Controls.rebindable("sigstop") and Controls.default_bind("sigstop") == "key:%d" % KEY_F and _shown("sigstop") == "SIGSTOP" and not Controls.conflicts({}).has("sigstop") and events.size() == 1 and (events[0] as InputEventKey).physical_keycode == KEY_F)
	var path := _tmp.path_join("rebind-settings.cfg")
	var s := GameSettings.new()
	s.path = path
	var g := InputEventKey.new()
	g.physical_keycode = KEY_G
	var took := s.set_bind("sigstop", g)
	var saved := s.save()
	var back := GameSettings.new()
	back.path = path
	var how := back.load_file()
	Controls.apply_binds(back.binds())
	var moved := InputMap.action_get_events("sigstop")
	_check("acceptance: the F rebind saves and loads: SIGSTOP moved to G is written to the settings file, read back from it, and the input map takes it", took == "" and saved and how == "loaded" and back.bind("sigstop") == "key:%d" % KEY_G and moved.size() == 1 and (moved[0] as InputEventKey).physical_keycode == KEY_G and FileAccess.get_file_as_string(path).contains("sigstop"), "%s %s %s %s" % [took, saved, how, back.bind("sigstop")])
	var chord := InputEventKey.new()
	chord.physical_keycode = KEY_F
	chord.ctrl_pressed = true
	chord.alt_pressed = true
	var refused := back.set_bind("sigstop", chord)
	back.reset_binds()
	back.save()
	var again := GameSettings.new()
	again.path = path
	again.load_file()
	Controls.apply_binds(again.binds())
	var reset := InputMap.action_get_events("sigstop")
	_check("Ctrl+Alt+F is refused, and resetting the keys puts SIGSTOP back on F, saved and loaded the same way", refused == Controls.CTRL_ALT_REFUSED and again.bind("sigstop") == "key:%d" % KEY_F and reset.size() == 1 and (reset[0] as InputEventKey).physical_keycode == KEY_F)


# --- Solo. ---

func _solo_checks() -> void:
	var arena := await _arena()
	var main: Node = arena["main"]
	var p: Node = arena["player"]
	var hud = arena["hud"]
	var round: RoundHud = hud.round_hud()
	var wh: WeaponHud = hud.weapon_hud()
	var st = p.sigstop
	var cover: ColorRect = st.get("_cover")
	var started := []
	var continued := []
	st.started.connect(func(): started.append(true))
	st.continued.connect(func(): continued.append(true))
	await _settle(p, 0.2)
	_check("solo: SIGSTOP lives under the player, its meter full and off, the world at full speed; the strip's fourth line shows it ready under F", st != null and st.meter.meter == 4.0 and not st.is_on() and Engine.time_scale == 1.0 and wh.stop_text() == "F SIGSTOP [##########]" and not wh.stop_dimmed() and not cover.visible, wh.stop_text())
	# Below the start's share.
	st.meter.meter = 0.9
	st.press()
	await _frames(2)
	_check("acceptance: below the start's share (0.9 s of 4) a press does nothing: no SIGSTOP, the world at exactly 1.0, no callout, the strip's line dimmed", not st.is_on() and Engine.time_scale == 1.0 and started.is_empty() and wh.stop_dimmed() and round.callout_text() == "", "%s %s" % [wh.stop_text(), round.callout_text()])
	# The pace at full speed, then under SIGSTOP.
	var normal := await _pace(p, main, round)
	var spread_normal: PackedVector3Array = await _pellets_of(p)
	st.meter.meter = 4.0
	st.press()
	await _frames(1)
	var at_start := [st.is_on(), Engine.time_scale, round.callout_text()]
	await _frames(int(_t.ease_s * 60.0) + 1)
	_check("SIGSTOP: called out 'SIGSTOP' by game logic, its look up to full on this screen and every sound slowed to the resource's pitch; the strip says 'F SIGCONT' in the meter's place", at_start == [true, _t.world_scale, RoundHud.SIGSTOP_LINE] and started.size() == 1 and st.look_strength() == 1.0 and cover.visible and is_equal_approx(AudioServer.playback_speed_scale, _t.audio_pitch) and wh.stop_text().begins_with("F SIGCONT [") and not wh.stop_dimmed(), "%s look %.2f audio %.2f %s" % [at_start, st.look_strength(), AudioServer.playback_speed_scale, wh.stop_text()])
	var slowed := await _pace(p, main, round)
	var steady: PackedVector3Array = await _pellets_of(p)
	var world := [slowed["fall"] / normal["fall"], slowed["clock"] / normal["clock"], slowed["world"] / normal["world"]]
	_check("acceptance: solo the world's time scale drops to exactly the resource's 0.3: physics at 0.3x (a falling body gathers 0.3x the speed in the same real time), the round clock and every timer too", Engine.time_scale == _t.world_scale and absf(world[0] - 0.3) < 0.03 and absf(world[1] - 0.3) < 0.005 and absf(world[2] - 0.3) < 0.005, "scale %s, fall/clock/world x%.3f x%.3f x%.3f" % [Engine.time_scale, world[0], world[1], world[2]])
	var walk: float = slowed["walk"] / normal["walk"]
	var cool: float = slowed["cool"] / normal["cool"]
	_check("acceptance: meanwhile the player keeps its compensated pace: it walks %.2f m/s against %.2f, x%.3f of its speed in real time (0.8x to 1.0x), and its weapon cools at x%.3f" % [slowed["walk"], normal["walk"], walk, cool], walk >= 0.8 and walk <= 1.0 and absf(walk - _t.player_rate) < 0.02 and absf(cool - _t.player_rate) < 0.02)
	_check("steady hands while it runs: zero recoil on the shot (the same shot at full speed kicked), and SIGTERM's nine pellets all straight down the aim (they spread at full speed)", normal["recoil"].x > 0.0 and slowed["recoil"] == Vector2.ZERO and _spread(steady) < 0.000001 and steady.size() == 9 and _spread(spread_normal) > 0.01, "recoil %s vs %s, spread %.5f vs %.5f" % [slowed["recoil"], normal["recoil"], _spread(steady), _spread(spread_normal)])
	var m0: float = st.meter.meter
	await _settle(p, 1.0)
	_check("acceptance: the meter drains by the resource's numbers: one second of it per real second, although the world runs at 0.3x", absf((m0 - st.meter.meter) - 1.0) < 0.02, "%.3f -> %.3f" % [m0, st.meter.meter])
	# SIGCONT, by F again.
	st.press()
	var scales := []
	for i in 24:
		await physics_frame
		scales.append(Engine.time_scale)
	var back_at := scales.find(1.0)
	var rising := true
	for i in range(1, scales.size()):
		rising = rising and scales[i] >= scales[i - 1] and scales[i] <= 1.0
	_check("acceptance: SIGCONT (F again) is called out and eases the world back over the resource's 0.25 s, never past full speed, then the time scale is exactly 1.0; the sound exactly 1.0, the look gone", continued.size() == 1 and round.callout_text() == RoundHud.SIGCONT_LINE and scales[0] < 0.5 and back_at >= 13 and back_at <= 16 and rising and Engine.time_scale == 1.0 and AudioServer.playback_speed_scale == 1.0 and st.look_strength() == 0.0 and not cover.visible, "back to 1.0 on frame %d: %s" % [back_at, scales.slice(0, 18)])
	# The meter running out.
	st.meter.meter = 4.0
	st.press()
	await _frames(1)
	var ran := 1
	while st.meter.on and ran < 400:
		await physics_frame
		ran += 1
	await _frames(20)
	_check("acceptance: from full, SIGSTOP lasts the resource's 4 s of real time (%d frames) and then sends SIGCONT by itself; the time scale is exactly 1.0 after the ease" % ran, ran >= 238 and ran <= 242 and continued.size() == 2 and Engine.time_scale == 1.0 and AudioServer.playback_speed_scale == 1.0)
	var low_at: float = st.meter.meter
	var dim_low := wh.stop_dimmed()
	await _frames(300)
	_check("acceptance: off, it refills by the resource's numbers: 0.2 s of slow-mo a second (full in 20 s), and the strip's line is no longer dimmed once it holds a quarter", absf((st.meter.meter - low_at) - 1.0) < 0.01 and dim_low and not wh.stop_dimmed(), "%.3f -> %.3f" % [low_at, st.meter.meter])
	# A death.
	await _start(st)
	var during_death := Engine.time_scale
	p.set_alive(false)
	var at_death := [Engine.time_scale, AudioServer.playback_speed_scale, st.meter.meter, st.is_on()]
	await _frames(30)
	st.press()
	await _frames(2)
	_check("acceptance: a death ends SIGSTOP at once: the time scale and the sound exactly 1.0 that moment, the meter empty; derezzed, it stays empty and a press does nothing", during_death == _t.world_scale and at_death == [1.0, 1.0, 0.0, false] and st.meter.meter == 0.0 and not st.is_on() and Engine.time_scale == 1.0, str(at_death))
	p.set_alive(true)
	# A round's end, and the next round.
	await _start(st)
	round.call("_end_round")
	var at_end := Engine.time_scale
	await _frames(1)
	_check("acceptance: a round's end ends SIGSTOP at once: the time scale exactly 1.0 for the break", at_end == 1.0 and Engine.time_scale == 1.0 and not st.is_on() and round.showing_summary())
	st.meter.meter = 0.5
	round.call("_next_round")
	_check("acceptance: a new round fills the SIGSTOP meter: 4 s again", st.meter.meter == 4.0 and round.stats.round_number == 2)
	# The Esc menu.
	var menu = hud.pause_menu()
	await _start(st)
	st.press()
	await _frames(3)
	var easing := Engine.time_scale
	hud.open_menu()
	await _frames(1)
	var snapped := Engine.time_scale
	menu.close()
	await _frames(2)
	_check("the menu stops SIGCONT's ease too: opened mid-ease (the world at x%.2f), the time scale is exactly 1.0 a frame later" % easing, easing > _t.world_scale and easing < 1.0 and snapped == 1.0 and not menu.is_open(), "%s -> %s" % [easing, snapped])
	await _start(st)
	hud.open_menu()
	await _frames(1)
	var menu_scale := Engine.time_scale
	st.press()
	await _frames(2)
	menu.open_settings()
	await _frames(2)
	var keys: Dictionary = menu.get("_keys")
	var listed: bool = keys.has("sigstop") and keys["sigstop"]["button"].text == "F"
	_check("acceptance: opening the Esc menu ends SIGSTOP: the time scale exactly 1.0 a frame later, and F does nothing while the menu is up; its settings list SIGSTOP on F among the keys", menu.is_open() and menu_scale == 1.0 and not st.is_on() and Engine.time_scale == 1.0 and listed, "scale %s listed %s" % [menu_scale, listed])
	menu.close()
	await _frames(2)
	menu.close()
	await _frames(2)
	# A stray change nothing holds.
	Engine.time_scale = 0.5
	AudioServer.playback_speed_scale = 0.5
	await _frames(1)
	_check("the safety check: a time scale or a sound speed that no SIGSTOP holds goes back to exactly 1.0 within a frame", Engine.time_scale == 1.0 and AudioServer.playback_speed_scale == 1.0)
	# The arena going away mid-SIGSTOP.
	await _start(st)
	var before_drop := Engine.time_scale
	_drop(arena)
	_check("acceptance: the arena going away mid-SIGSTOP (an R reload, a scene change) leaves nothing slowed: the time scale and the sound exactly 1.0 at once", before_drop == _t.world_scale and Engine.time_scale == 1.0 and AudioServer.playback_speed_scale == 1.0)
	await _frames(2)


## Fills the meter and starts SIGSTOP, then lets it run a few frames.
func _start(st: Node) -> void:
	st.meter.meter = 4.0
	st.press()
	await _frames(4)


## The player walks east along the clear line for 50 frames with a body falling beside it
## and the cannon fired on the first: what moved how much, in real time (each frame is
## 1/60 s of it), and the recoil of that shot.
func _pace(p: Node, main: Node, round: RoundHud) -> Dictionary:
	p.respawn_at(main.to_global(Vector3(START_X, STAND_Y, LINE_Z)))
	_aim(p, main.to_global(Vector3(20.0, STAND_Y + 0.7, LINE_Z)))
	await _settle(p, 0.1)
	await _until(func(): return p.inventory.fire_block() == "", 2000)
	var ball := RigidBody3D.new()
	var shape := CollisionShape3D.new()
	shape.shape = SphereShape3D.new()
	ball.add_child(shape)
	ball.collision_layer = 0
	ball.collision_mask = 0
	main.add_child(ball)
	ball.global_position = main.to_global(Vector3(0.0, 60.0, -40.0))
	var probe := Probe.new()
	main.add_child(probe)
	var clock := round.seconds_left()
	var xs := []
	var cools := []
	var recoil := Vector2.ZERO
	for k in 50:
		p.drive_input(Vector2(0.0, -1.0), false, false, k == 0)
		await physics_frame
		xs.append(p.global_position.x)
		cools.append(p.inventory.cooldowns[0])
		if k == 0:
			recoil = p.get("_recoil")
	var out := {
		"walk": (xs[49] - xs[19]) / 30.0 * 60.0,
		"fall": -ball.linear_velocity.y,
		"clock": clock - round.seconds_left(),
		"world": probe.sum,
		"cool": (cools[1] - cools[7]) / 6.0 * 60.0,
		"recoil": recoil,
	}
	ball.free()
	probe.free()
	return out


## SIGTERM's pellet directions as the player would fire them right now.
func _pellets_of(p: Node) -> PackedVector3Array:
	p.select_slot(1)
	await _settle(p, 0.05)
	var dirs: PackedVector3Array = p.call("_pellets", Vector3(1.0, 0.0, 0.0))
	p.select_slot(0)
	await _settle(p, 0.05)
	return dirs


## The widest gap between any two of `points` (directions or end points).
func _spread(points: PackedVector3Array) -> float:
	var widest := 0.0
	for a in points:
		for b in points:
			widest = maxf(widest, a.distance_to(b))
	return widest


# --- A match. ---

func _match_checks() -> void:
	var host := _branch("Host", Vector3.ZERO)
	var client := _branch("Client", CLIENT_OFFSET)
	var hs: Session = host["session"]
	var cs: Session = client["session"]
	var hp: Node = host["player"]
	var cp: Node = client["player"]
	var hst = hp.sigstop
	var cst = cp.sigstop
	# Hosting mid-SIGSTOP: it ends right there, before a frame of the match runs.
	await _frames(3)
	await _start(hst)
	var solo_scale := Engine.time_scale
	# Between frames, where a key press lands: the engine reads the time scale for a frame's
	# physics as the frame begins.
	await process_frame
	hs.host(0)
	var at_host := Engine.time_scale
	# physics_frame comes before the nodes' physics: the gap between two is one whole frame.
	await physics_frame
	var c1: float = hs.get("_clock")
	await physics_frame
	var first_frame: float = hs.get("_clock") - c1
	_check("hosting a match mid-SIGSTOP (from a key, between frames) ends it at once: the time scale exactly 1.0 the moment the host opens, and the match's first frame runs 1/60 s", solo_scale == _t.world_scale and at_host == 1.0 and is_equal_approx(first_frame, FRAME) and not hst.is_on() and Engine.time_scale == 1.0, "%s -> %s, first frame %.5f" % [solo_scale, at_host, first_frame])
	client["session"].join("127.0.0.1:%d" % hs.listen_port())
	var joined := await _until(func(): return cs.state == Session.State.JOINED and hs.players.size() == 2 and cs.players.size() == 2)
	var cid: int = cs.my_id
	await _until(func(): return hs.avatars.has(cid) and cs.avatars.has(1) and hs.combat.has_player(cid), 6000)
	await _frames(10)
	var started := []
	var continued := []
	cst.started.connect(func(): started.append(true))
	cst.continued.connect(func(): continued.append(true))
	_check("a host and a joiner over ENet on 127.0.0.1, protocol 4: the host counts the joiner's SIGSTOP meter, full and off, and the joiner's copy says the same", joined and hs.combat.sigstop_meter(cid) == 4.0 and not hs.combat.sigstop_on(cid) and cst.meter.meter > 3.99 and not cst.is_on() and Engine.time_scale == 1.0, "host %.2f joiner %.2f" % [hs.combat.sigstop_meter(cid), cst.meter.meter])
	# Speeds and the host's clock with nothing on.
	var host_walk := await _walk(hp, host, hs)
	var joiner_walk := await _walk(cp, client, hs)
	# The joiner, SIGTERM in hand, aims along the clear line; then SIGSTOP.
	cp.select_slot(1)
	cp.respawn_at(client["main"].to_global(Vector3(START_X, STAND_Y, LINE_Z)))
	_aim(cp, client["main"].to_global(Vector3(20.0, 1.4, LINE_Z)))
	await _settle(cp, 0.6)
	cst.press()
	var on := await _until(func(): return hs.combat.sigstop_on(cid) and cst.is_on(), 3000)
	var on_at: float = hs.get("_clock")
	_check("acceptance: the joiner's F asks the host, which starts its SIGSTOP by its own count; the host's word starts it on the joiner, called out 'SIGSTOP' there, its look on the joiner's screen only, and the time scale still exactly 1.0", on and started.size() == 1 and client["hud"].round_hud().callout_text() == RoundHud.SIGSTOP_LINE and Engine.time_scale == 1.0 and not hst.is_on() and hst.look_strength() == 0.0)
	# Zero spread, by the host's word.
	var shot := await _sigterm_shot(cp, client, host, hs)
	_check("acceptance: while the host says it is on, the joiner gets zero spread: the host believes the shot, draws nothing from its pellet generator, and all nine pellets fly down the aim to one point; and no recoil on the joiner's screen", shot["believed"] and shot["rng_same"] and shot["beams"] == 9 and shot["spread"] < 0.001 and shot["recoil"] == Vector2.ZERO, str(shot))
	# The host never slows.
	var host_during := await _walk(hp, host, hs)
	var joiner_during := await _walk(cp, client, hs)
	_check("acceptance: the joiner's SIGSTOP does not touch the host's time scale (exactly 1.0 every frame) or its clock (1/60 s a frame), and the host's player and the joiner move at their normal speeds", host_during["scale_ok"] and joiner_during["scale_ok"] and host_during["clock_ok"] and joiner_during["clock_ok"] and absf(host_during["walk"] - host_walk["walk"]) < 0.01 and absf(joiner_during["walk"] - joiner_walk["walk"]) < 0.01 and cst.is_on(), "host %.3f vs %.3f, joiner %.3f vs %.3f, scales %s %s, clocks %s %s" % [host_during["walk"], host_walk["walk"], joiner_during["walk"], joiner_walk["walk"], host_during["scale_ok"], joiner_during["scale_ok"], host_during["clock_ok"], joiner_during["clock_ok"]])
	# An R reload of the joiner's arena mid-SIGSTOP: the new arena's player takes the host's
	# word, and its first frame in the match does not wipe it.
	client["main"].free()
	await _frames(2)
	var main_r = MainScene.instantiate()
	client["branch"].add_child(main_r)
	client["main"] = main_r
	client["hud"] = main_r.get_node("Hud")
	client["hud"].guide().focus_check = func(): return false
	cp = main_r.get_node("Player")
	cp.assume_captured = true
	client["player"] = cp
	cst = cp.sigstop
	cst.continued.connect(func(): continued.append(true))
	await _frames(10)
	_check("an R reload of the joiner's arena mid-SIGSTOP keeps the host's word: the new arena's SIGSTOP is on, its look up, the time scale exactly 1.0", hs.combat.sigstop_on(cid) and cst.is_on() and cst.look_strength() > 0.0 and Engine.time_scale == 1.0, "host %s joiner %s look %.2f" % [hs.combat.sigstop_on(cid), cst.is_on(), cst.look_strength()])
	# The host's meter runs out on the host's clock.
	var scale_kept := true
	var ended := false
	var t0 := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < 8000:
		await physics_frame
		scale_kept = scale_kept and Engine.time_scale == 1.0
		if not hs.combat.sigstop_on(cid):
			ended = true
			break
	var lasted: float = hs.get("_clock") - on_at
	var told := await _until(func(): return not cst.is_on() and continued.size() == 1, 3000)
	await _frames(int(_t.ease_s * 60.0) + 2)
	_check("acceptance: the host drains the joiner's meter on its own clock and ends SIGSTOP when it is empty, %.2f s after the start; its word reaches the joiner: 'SIGCONT' called out, the look gone, the time scale exactly 1.0 throughout" % lasted, ended and told and absf(lasted - 4.0) < 0.1 and hs.combat.sigstop_meter(cid) < 0.1 and client["hud"].round_hud().callout_text() == RoundHud.SIGCONT_LINE and cst.look_strength() == 0.0 and scale_kept and Engine.time_scale == 1.0 and AudioServer.playback_speed_scale == 1.0)
	var spread_shot := await _sigterm_shot(cp, client, host, hs)
	_check("once the host says it is off the spread is back: the host believes the shot, draws the pellets from its generator again and they spread, and the shot kicks", spread_shot["believed"] and not spread_shot["rng_same"] and spread_shot["beams"] == 9 and spread_shot["spread"] > 0.05 and spread_shot["recoil"].x > 0.0, str(spread_shot))
	# An empty meter: an honest press is not even sent; a forged ask is rejected and counted.
	var dropped: int = hs.combat.drops.get(Combat.DROP_SIGSTOP, 0)
	var all_before: int = hs.combat.dropped
	var meters := [hs.combat.sigstop_meter(cid), cst.meter.meter]
	cst.press()
	await _frames(10)
	var honest := [hs.combat.drops.get(Combat.DROP_SIGSTOP, 0), hs.combat.dropped, hs.combat.sigstop_on(cid)]
	cs.rpc_id(1, "_sigstop", cs.lives.get(cid, 0), true)
	var refused := await _until(func(): return hs.combat.drops.get(Combat.DROP_SIGSTOP, 0) > dropped, 3000)
	await _frames(6)
	_check("acceptance: with the meter empty (%.2f s) an honest press sends nothing, and a forged SIGSTOP ask put straight on the wire is rejected by the host and counted as 'sigstop': off there and on the joiner, no look" % meters[0], meters[0] < 1.0 and meters[1] < 1.0 and honest == [dropped, all_before, false] and refused and hs.combat.drops.get(Combat.DROP_SIGSTOP, 0) == dropped + 1 and not hs.combat.sigstop_on(cid) and not cst.is_on() and cst.look_strength() == 0.0 and Engine.time_scale == 1.0, "meters %s honest %s refused %s drops %s on %s/%s" % [meters, honest, refused, hs.combat.drops, hs.combat.sigstop_on(cid), cst.is_on()])
	var counted: int = hs.combat.dropped
	cs.rpc_id(1, "_sigstop", "now", 1)
	var typed := await _until(func(): return hs.combat.dropped > counted, 3000)
	_check("an ask of the wrong types is dropped and counted too, never an engine error", typed and not hs.combat.sigstop_on(cid))
	# The host's own SIGSTOP slows nothing either.
	hst.press()
	var host_on := await _until(func(): return hs.combat.sigstop_on(1) and hst.is_on(), 2000)
	var joiner_meanwhile := await _walk(cp, client, hs)
	_check("the host's own SIGSTOP is the same: on by its own count, the look on its own screen, and nothing slows: the time scale exactly 1.0, its clock at 1/60 s a frame, the joiner at its normal speed", host_on and hst.look_strength() > 0.0 and joiner_meanwhile["scale_ok"] and joiner_meanwhile["clock_ok"] and absf(joiner_meanwhile["walk"] - joiner_walk["walk"]) < 0.01 and Engine.time_scale == 1.0)
	hst.press()
	await _until(func(): return not hs.combat.sigstop_on(1) and not hst.is_on(), 2000)
	# A death empties the meter on both sides.
	hs.combat.states[cid]["stop"].meter = 4.0
	hs.call("_send_sigstop", cid)
	await _until(func(): return cst.meter.meter > 3.9, 2000)
	cp.select_slot(0)
	cp.respawn_at(client["main"].to_global(Vector3(START_X, STAND_Y, LINE_Z)))
	await _settle(cp, 0.4)
	cst.press()
	var again := await _until(func(): return hs.combat.sigstop_on(cid) and cst.is_on(), 2000)
	# A hard stop in a match: the joiner's Esc menu.
	var cmenu = client["hud"].pause_menu()
	var strip: WeaponHud = client["hud"].weapon_hud()
	client["hud"].open_menu()
	await _frames(1)
	var at_menu := [cst.is_on(), strip.stop_dimmed(), Engine.time_scale]
	var host_off := await _until(func(): return not hs.combat.sigstop_on(cid), 2000)
	cmenu.close()
	await _frames(2)
	_check("in a match the Esc menu ends SIGSTOP too: off on the joiner's screen at once, its strip ready again rather than waiting on the host's word, and the host told to end it", again and at_menu == [false, false, 1.0] and host_off and hs.combat.sigstop_meter(cid) > 1.0 and not cmenu.is_open(), str(at_menu))
	cst.press()
	again = await _until(func(): return hs.combat.sigstop_on(cid) and cst.is_on(), 2000)
	hp.respawn_at(host["main"].to_global(Vector3(-8.0, STAND_Y, LINE_Z)))
	hp.select_slot(0)
	await _settle(hp, 0.5)
	_aim(hp, host["main"].to_global(Vector3(START_X, STAND_Y + 0.05, LINE_Z)))
	var shots := 0
	while not hs.dead.get(cid, false) and shots < 10:
		await _settle(hp, 0.2)
		await _fire(hp)
		shots += 1
		await _frames(4)
	var down := await _until(func(): return cs.dead.get(cid, false), 3000)
	await _frames(4)
	_check("acceptance: a death empties the SIGSTOP meter and ends it on both sides: the host's count and the joiner's own, with no look left and the time scale exactly 1.0", again and down and hs.combat.sigstop_meter(cid) == 0.0 and not hs.combat.sigstop_on(cid) and cst.meter.meter == 0.0 and not cst.is_on() and cst.look_strength() == 0.0 and Engine.time_scale == 1.0, "again %s down %s host %.2f joiner %.2f" % [again, down, hs.combat.sigstop_meter(cid), cst.meter.meter])
	_drop(host)
	_drop(client)


## Walks `p` east along the side line for 50 frames: its speed in real time, whether the time
## scale stayed exactly 1.0 every frame, and whether the host's clock ran 1/60 s a frame.
func _walk(p: Node, side: Dictionary, hs: Session) -> Dictionary:
	p.respawn_at(side["main"].to_global(Vector3(START_X, STAND_Y, SIDE_Z)))
	_aim(p, side["main"].to_global(Vector3(20.0, STAND_Y + 0.7, SIDE_Z)))
	await _settle(p, 0.1)
	var xs := []
	var scale_ok := true
	var clock_ok := true
	for k in 50:
		var before: float = hs.get("_clock")
		p.drive_input(Vector2(0.0, -1.0))
		await physics_frame
		xs.append(p.global_position.x)
		scale_ok = scale_ok and Engine.time_scale == 1.0
		clock_ok = clock_ok and is_equal_approx(hs.get("_clock") - before, FRAME)
	return {"walk": (xs[49] - xs[19]) / 30.0 * 60.0, "scale_ok": scale_ok, "clock_ok": clock_ok}


## The joiner's SIGTERM shot along the clear line, as the host drew it: whether its pellet
## generator was left alone, how many beams it drew for the shot in its own world, how far
## apart their middles are, whether it believed the shot, and the joiner's recoil.
func _sigterm_shot(cp: Node, client: Dictionary, host: Dictionary, hs: Session) -> Dictionary:
	cp.select_slot(1)
	cp.respawn_at(client["main"].to_global(Vector3(START_X, STAND_Y, LINE_Z)))
	_aim(cp, client["main"].to_global(Vector3(20.0, 1.4, LINE_Z)))
	await _settle(cp, 0.3)
	await _until(func(): return cp.inventory.fire_block() == "", 3000)
	var known := {}
	for node in _beams(host["main"]):
		known[node.get_instance_id()] = true
	var rng_before: int = hs.get("_pellets_rng").state
	var seq_before: int = hs.combat.states[cp.get_multiplayer().get_unique_id()]["last_seq"]
	await _fire(cp)
	var recoil: Vector2 = cp.get("_recoil")
	# Counted in frames, not milliseconds: a headless frame is far shorter than its 1/60 s.
	var fresh := []
	var frames := 0
	while frames < 120:
		fresh = _beams(host["main"]).filter(func(n): return not known.has(n.get_instance_id()))
		if fresh.size() >= 9:
			break
		frames += 1
		await physics_frame
	var middles := PackedVector3Array()
	for node in fresh:
		middles.append((node as Node3D).global_position)
	var believed: bool = hs.combat.states[cp.get_multiplayer().get_unique_id()]["last_seq"] > seq_before
	return {"rng_same": hs.get("_pellets_rng").state == rng_before, "beams": fresh.size(), "spread": _spread(middles), "recoil": recoil, "frames": frames, "believed": believed}


## SIGTERM's beams in `scope`: effects holding a cylinder as wide as its beam.
func _beams(scope: Node) -> Array:
	var out := []
	for node in get_nodes_in_group(FX_GROUP):
		if scope.is_ancestor_of(node) and node.get_child_count() > 0 and node.get_child(0) is MeshInstance3D:
			var mesh = (node.get_child(0) as MeshInstance3D).mesh
			if mesh is CylinderMesh and is_equal_approx(mesh.top_radius, _sigterm.beam_radius):
				out.append(node)
	return out


# --- Helpers. ---

func _shown(action: String) -> String:
	for pair in Controls.REBINDABLE:
		if pair[0] == action:
			return pair[1]
	return ""


func _scripts(dir: String) -> PackedStringArray:
	var out := PackedStringArray()
	for name in DirAccess.get_files_at(dir):
		if name.ends_with(".gd"):
			out.append(dir.path_join(name))
	for sub in DirAccess.get_directories_at(dir):
		out.append_array(_scripts(dir.path_join(sub)))
	return out


func _arena() -> Dictionary:
	var link := Link.new()
	link.settings_path = _tmp.path_join("arena-privacy.cfg")
	link.demo = true
	Link.park(link)
	var main = MainScene.instantiate()
	root.add_child(main)
	_arenas.append(main)
	var hud = main.get_node("Hud")
	hud.guide().focus_check = func(): return false
	var player = main.get_node("Player")
	player.assume_captured = true
	await _frames(3)
	return {"main": main, "player": player, "hud": hud}


func _drop(side: Dictionary) -> void:
	var node: Node = side.get("branch", side.get("main"))
	if is_instance_valid(node):
		for sfx in node.find_children("*", "AudioStreamPlayer", true, false):
			(sfx as AudioStreamPlayer).stop()
		var session = side.get("session")
		if session != null and is_instance_valid(session):
			session.leave()
		node.free()
	_arenas.erase(node)
	_branches.erase(node)
	var left = Link.take_parked()
	if left != null:
		left.shut_down(null)


func _net_tuning() -> Resource:
	var t := NetTuningScript.new()
	t.bind_address = "127.0.0.1"
	t.connect_timeout_ms = 1500
	t.peer_timeout_ms = 4000
	return t


func _combat_tuning() -> Resource:
	var t := CombatTuningScript.new()
	t.respawn_delay_s = 1.0
	t.spawn_protection_s = 0.3
	t.kill_feed_fade_s = 30.0
	return t


func _branch(name: String, offset: Vector3) -> Dictionary:
	var api := SceneMultiplayer.new()
	var branch := Node3D.new()
	branch.name = name
	branch.position = offset
	root.add_child(branch)
	set_multiplayer(api, branch.get_path())
	var session := Session.new()
	session.name = Session.NODE_NAME
	session.tuning = _net_tuning()
	session.combat_tuning = _combat_tuning()
	branch.add_child(session)
	_branches.append(branch)
	var link := Link.new()
	link.settings_path = _tmp.path_join("%s-privacy.cfg" % name)
	link.demo = true
	Link.park(link)
	var main = MainScene.instantiate()
	branch.add_child(main)
	var hud = main.get_node("Hud")
	hud.guide().focus_check = func(): return false
	var out := {"branch": branch, "session": session, "main": main, "player": main.get_node("Player"), "hud": hud}
	out["player"].assume_captured = true
	return out


func _join(host: Dictionary, client: Dictionary) -> bool:
	host["session"].host(0)
	await _frames(2)
	client["session"].join("127.0.0.1:%d" % host["session"].listen_port())
	return await _until(func(): return client["session"].state == Session.State.JOINED and host["session"].players.size() == 2 and client["session"].players.size() == 2)


func _settle(p: Node, seconds: float) -> void:
	for i in ceili(seconds * 60.0):
		p.drive_input(Vector2.ZERO)
		await physics_frame


func _fire(p: Node) -> void:
	p.drive_input(Vector2.ZERO, false, false, true)
	await physics_frame


func _aim(player: Node, target: Vector3) -> void:
	var cam: Node3D = player.get_node("Head/Camera")
	var to: Vector3 = target - cam.global_position
	player.rotation.y = atan2(-to.x, -to.z)
	player.get_node("Head").rotation.x = atan2(to.y, Vector2(to.x, to.z).length())


func _until(condition: Callable, ms: int = WATCHDOG_MS) -> bool:
	var t0 := Time.get_ticks_msec()
	while not condition.call():
		if Time.get_ticks_msec() - t0 > ms:
			return false
		await physics_frame
	return true


func _frames(n: int) -> void:
	for i in n:
		await physics_frame


func _code(path: String) -> String:
	var out := PackedStringArray()
	for line in FileAccess.get_file_as_string(path).split("\n"):
		var quote := ""
		var cut := line.length()
		var i := 0
		while i < line.length():
			var ch := line[i]
			if quote != "":
				if ch == "\\":
					i += 1
				elif ch == quote:
					quote = ""
			elif ch == "\"" or ch == "'":
				quote = ch
			elif ch == "#":
				cut = i
				break
			i += 1
		out.append(line.substr(0, cut).rstrip(" \t"))
	return "\n".join(out)


func _body(source: String, name: String) -> String:
	var at := source.find("\nfunc %s(" % name)
	if at < 0:
		at = source.find("\nstatic func %s(" % name)
	if at < 0:
		return ""
	var end := source.find("\nfunc ", at + 1)
	var end_static := source.find("\nstatic func ", at + 1)
	if end_static > 0 and (end < 0 or end_static < end):
		end = end_static
	return source.substr(at, (end if end > 0 else source.length()) - at)


func _cleanup() -> void:
	for node in _arenas.duplicate() + _branches.duplicate():
		if is_instance_valid(node):
			var session = node.get_node_or_null(Session.NODE_NAME)
			if session != null:
				session.leave()
			node.free()
	var left = Link.take_parked()
	if left != null:
		left.shut_down(null)
	Controls.apply_binds({})
	await process_frame
	OS.delay_msec(300)
	await process_frame
