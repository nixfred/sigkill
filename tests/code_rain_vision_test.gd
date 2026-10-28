extends SceneTree
## Headless code-rain vision test for SIGKILL (C21). scripts/check.sh runs it, and any FAIL
## exits 1.
##
##   godot --headless --path . --fixed-fps 60 --script res://tests/code_rain_vision_test.gd
##
## Code-rain vision (PRD 5.3: "see enemies through walls as glyphs, drains fast"): its
## resource and numbers, bad values refused; the meter's rules on their own; V as a
## rebindable action, saved to a settings file in a temporary folder and loaded back, Ctrl+Alt
## refused; a scan that it sends nothing. Then solo in the real arena with the real player:
## held, it drains at the tuned rate and its line under SIGSTOP's says so; let go it is off at
## once and refills after its rest at the tuned rate; held through an empty meter it goes off
## and never starts again without a new press; under the start's share a press does nothing;
## a death, a respawn and a stopped input turn it off and leave the meter as it was; a dummy
## behind a wall within range gets a silhouette that draws through walls only while vision is
## on, one past range never, a derezzed one never; the look eases in and out, calmer with the
## comfort settings; the weapon still fires. Then a host and a joiner over ENet on 127.0.0.1:
## the joiner's vision shows the other player and no dummy, the host hears nothing new, and
## leaving the match turns it off. No orphan nodes. Deterministic: no random numbers, every
## rate counted in physics frames, nothing waits a frame count for the network.

const Session = preload("res://scripts/net/net_session.gd")
const NetTuningScript = preload("res://scripts/net/net_tuning.gd")
const CombatTuningScript = preload("res://scripts/net/combat_tuning.gd")
const Vision = preload("res://scripts/abilities/code_rain_vision.gd")
const VisionTuningScript = preload("res://scripts/abilities/code_rain_vision_tuning.gd")
const Meter = preload("res://scripts/abilities/code_rain_vision_meter.gd")
const WeaponHud = preload("res://scripts/hud/weapon_hud.gd")
const Controls = preload("res://scripts/controls.gd")
const Palette = preload("res://scripts/palette.gd")
const Link = preload("res://scripts/guide/guide_link.gd")
const MainScene = preload("res://scenes/main.tscn")
const TUNING_PATH := "res://resources/code_rain_vision.tres"
const WATCHDOG_MS := 10000
const CLIENT_OFFSET := Vector3(1000.0, 0.0, 0.0)
const STAND_Y := 0.95
const FRAME := 1.0 / 60.0
const EPS := 0.000001

var _fails := 0
var _checks := 0
var _tmp := ""
var _t: Resource
var _arenas: Array = []
var _branches: Array = []


func _initialize() -> void:
	_run()


func _run() -> void:
	await process_frame
	root.size = Vector2i(1280, 720)
	_tmp = OS.get_temp_dir().path_join("sigkill-vision-test-%d" % OS.get_process_id())
	DirAccess.make_dir_recursive_absolute(_tmp)
	Controls.ensure()
	_t = load(TUNING_PATH)
	_tuning_checks()
	_meter_checks()
	_rebind_checks()
	_source_checks()
	await _solo_checks()
	await _match_checks()
	await _cleanup()
	for name in DirAccess.get_files_at(_tmp):
		DirAccess.remove_absolute(_tmp.path_join(name))
	DirAccess.remove_absolute(_tmp)
	print("VISION: %d checks" % _checks)
	print("VISION RESULT: ", "ALL PASS" if _fails == 0 else "%d FAILED" % _fails)
	quit(0 if _fails == 0 else 1)


func _check(label: String, ok: bool, detail: String = "") -> void:
	_checks += 1
	print("PASS " if ok else "FAIL ", label, ("   " + detail) if detail != "" else "")
	if not ok:
		_fails += 1


# --- The resource, the meter, the action, the source. ---

func _tuning_checks() -> void:
	var t = _t
	_check("every number is one resource, resources/code_rain_vision.tres, a CodeRainVisionTuning that passes its own checks", t is VisionTuningScript and t.problems().is_empty(), str(t.problems()) if t is VisionTuningScript else "")
	_check("its numbers: a full meter lasts 3 s of use and refills in 12 s after 1 s of rest, a start needs 25%, it sees 40 m, the look eases over 0.2 s (calmer at half strength)", t.meter_s == 3.0 and t.refill_s == 12.0 and t.rest_s == 1.0 and t.start_share == 0.25 and t.range_m == 40.0 and t.fade_s == 0.2 and t.strength == 1.0 and t.calm_strength == 0.5)
	var cases := [
		["meter_s", 0.0, "meter_s"], ["refill_s", 0.5, "refill_s"], ["rest_s", -1.0, "rest_s"], ["start_share", 0.0, "start_share"],
		["range_m", 0.0, "range_m"], ["tint", Color(2.0, 0.5, 0.5), "tint"], ["strength", 2.0, "strength"], ["calm_strength", NAN, "calm_strength"],
		["fade_s", 3.0, "fade_s"], ["marker_radius_m", 0.0, "marker_radius_m"], ["marker_height_m", 0.5, "marker_height_m"], ["marker_energy", 0.0, "marker_energy"],
	]
	var missed := PackedStringArray()
	for c in cases:
		var bad = _t.duplicate()
		bad.set(c[0], c[1])
		if not ", ".join(bad.problems()).contains(c[2]):
			missed.append("%s=%s: %s" % [c[0], c[1], bad.problems()])
	var louder = _t.duplicate()
	louder.calm_strength = 0.9
	louder.strength = 0.6
	_check("bad values are refused with the reason: the meter, the refill, the rest, the start's share, the range, the tint, the strengths (a calm one stronger than the full one too), the fade, the silhouette's size and glow", missed.is_empty() and ", ".join(louder.problems()).contains("calm_strength must be at most strength"), " | ".join(missed))


func _meter_checks() -> void:
	var m := Meter.new(_t)
	var full_start := m.meter == 3.0 and not m.on
	m.start()
	var ran_out := false
	var ticks := 0
	while not ran_out and ticks < 1000:
		ran_out = m.tick(0.5)
		ticks += 1
	_check("the meter alone: full at 3 s, on it drains a second a second and ends by itself when empty (6 ticks of 0.5 s)", full_start and ran_out and ticks == 6 and not m.on and m.meter == 0.0, "%d ticks" % ticks)
	m.tick(0.9)
	var resting := m.meter
	m.tick(0.1)
	var rested := m.meter
	m.tick(4.0)
	var after_four := m.meter
	m.tick(100.0)
	_check("off, it rests 1 s and then refills a quarter of a second each second (full in 12 s), never past full", resting == 0.0 and absf(rested) < EPS and absf(after_four - 1.0) < EPS and m.meter == 3.0, "%.3f %.3f %.3f" % [resting, rested, after_four])
	var low := Meter.new(_t)
	low.meter = 0.74
	var refused := not low.start()
	low.meter = 0.75
	_check("a start needs 25%: 0.74 s of 3 is refused, 0.75 s starts", refused and low.start() and low.on)
	low.stop()
	var kept := low.meter
	low.tick(5.0, false)
	_check("turning it off leaves the meter as it was, and a derezzed player's meter does not refill", low.meter == kept and kept == 0.75)


func _rebind_checks() -> void:
	var events := InputMap.action_get_events("code_rain_vision")
	_check("V is code-rain vision: a rebindable action shown as \"code-rain vision\" in the settings' list, V by default, clashing with nothing", Controls.rebindable("code_rain_vision") and Controls.default_bind("code_rain_vision") == "key:%d" % KEY_V and _shown("code_rain_vision") == "code-rain vision" and not Controls.conflicts({}).has("code_rain_vision") and events.size() == 1 and (events[0] as InputEventKey).physical_keycode == KEY_V)
	var path := _tmp.path_join("rebind-settings.cfg")
	var s := GameSettings.new()
	s.path = path
	var z := InputEventKey.new()
	z.physical_keycode = KEY_Z
	var took := s.set_bind("code_rain_vision", z)
	var saved := s.save()
	var back := GameSettings.new()
	back.path = path
	var how := back.load_file()
	Controls.apply_binds(back.binds())
	var moved := InputMap.action_get_events("code_rain_vision")
	var chord := InputEventKey.new()
	chord.physical_keycode = KEY_V
	chord.ctrl_pressed = true
	chord.alt_pressed = true
	var refused := back.set_bind("code_rain_vision", chord)
	back.reset_binds()
	Controls.apply_binds(back.binds())
	var reset := InputMap.action_get_events("code_rain_vision")
	_check("acceptance: rebindable: moved to Z it is saved, read back and taken by the input map; Ctrl+Alt+V is refused; reset, it is V again", took == "" and saved and how == "loaded" and moved.size() == 1 and (moved[0] as InputEventKey).physical_keycode == KEY_Z and refused == Controls.CTRL_ALT_REFUSED and reset.size() == 1 and (reset[0] as InputEventKey).physical_keycode == KEY_V, "%s %s %s" % [took, how, refused])


func _source_checks() -> void:
	var mine := _code("res://scripts/abilities/code_rain_vision.gd") + _code("res://scripts/abilities/code_rain_vision_meter.gd") + _code("res://scripts/abilities/code_rain_vision_tuning.gd")
	var found := PackedStringArray()
	for word in ["rpc", "multiplayer", "PacketPeer", "StreamPeer", "HTTP", "OS.", "FileAccess", "DirAccess", "Thread", "Engine.time_scale"]:
		if mine.contains(word):
			found.append(word)
	_check("purely local: the vision code sends nothing, opens nothing, reads no file, runs nothing and slows no clock", found.is_empty(), ", ".join(found))
	var session := _code("res://scripts/net/net_session.gd")
	_check("acceptance: nothing goes over the wire for it: protocol 6 as C20 left it (7 since C22's sudo, 8 since C23's top table, none of it vision's), the session's 17 RPCs and 19 sends then (19 and 22 since C22's two sudo messages, 20 and 23 since C23's top table), and its one word about vision only hands the node the session", Session.PROTOCOL == 8 and session.count("@rpc(") == 20 and session.count(".rpc_id(") == 23 and not _code("res://scripts/abilities/code_rain_vision.gd").contains("sudo") and session.count("vision") == _body(session, "attach").count("vision") and _body(session, "attach").contains("vision.session = self"))
	var shader := FileAccess.get_file_as_string("res://shaders/vision_glyphs.gdshader")
	_check("the silhouettes draw over everything, walls included: no depth test, additive, unshaded; the walls' own glyphs (the same integer hash and glyph grid as shaders/code_rain.gdshader)", shader.contains("depth_test_disabled") and shader.contains("blend_add") and shader.contains("unshaded") and FileAccess.get_file_as_string("res://shaders/code_rain.gdshader").contains(_body_of_shader(shader, "uint pcg(uint v)")))


# --- Solo. ---

func _solo_checks() -> void:
	var arena := await _arena()
	var main: Node = arena["main"]
	var p: Node = arena["player"]
	var hud = arena["hud"]
	var wh: WeaponHud = hud.weapon_hud()
	var v = p.get("vision")
	var orphans := int(Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT))
	var starts := [0]
	var ends := [0]
	v.started.connect(func(): starts[0] += 1)
	v.ended.connect(func(): ends[0] += 1)
	p.respawn_at(main.to_global(Vector3(-10.0, STAND_Y, 15.0)))
	_face(p, Vector3(1.0, 0.0, 0.0))
	await _frames(5)
	var labels: Array = wh.get("_stack").get_children()
	var under := labels.find(wh.get("_vision")) == labels.find(wh.get("_stop")) + 1
	_check("solo: vision lives under the player beside SIGSTOP, its meter full and off; the strip shows its meter on the line right under SIGSTOP's, \"V vision [##########]\"", v is Vision and v.get_parent() == p and p.get_node_or_null("Sigstop") != null and v.meter.meter == 3.0 and not v.is_on() and under and wh.vision_text() == "V vision [##########]" and not wh.vision_dimmed(), wh.vision_text())
	# Held for a second: on, and draining a second.
	v.hold(true)
	await _frames(60)
	var after_second: float = v.meter.meter
	var on_line := wh.vision_text()
	_check("acceptance: held, it is on and drains at the tuned rate: 60 frames take 1 s of the 3 (2.0 left), and the line says so in capitals", v.is_on() and absf(after_second - 2.0) < EPS and on_line == "V VISION [#######...]" and starts[0] == 1, "%.6f %s" % [after_second, on_line])
	# Let go: off at once, then the rest, then the refill.
	v.hold(false)
	await physics_frame
	var off_at_once: bool = not v.is_on() and absf(v.meter.meter - 2.0) < EPS
	await _frames(59)
	var after_rest: float = v.meter.meter
	await _frames(240)
	var after_refill: float = v.meter.meter
	_check("acceptance: let go it is off at once, the meter as it was; it rests 1 s (60 frames, still 2.0) and then refills 0.25 s a second (240 more frames, 3.0)", off_at_once and absf(after_rest - 2.0) < EPS and absf(after_refill - 3.0) < EPS and ends[0] == 1, "%.6f %.6f" % [after_rest, after_refill])
	# Held through an empty meter.
	v.hold(true)
	var empty_frame := -1
	for i in 500:
		await physics_frame
		if empty_frame < 0 and not v.is_on():
			empty_frame = i + 1
	_check("acceptance: held through it, it turns off at empty (after 180 frames, 3 s) and, still held, never starts again by itself though the meter refills past its 25%", empty_frame == 180 and not v.is_on() and v.meter.meter > 0.75 and starts[0] == 2 and v.is_held(), "off at frame %d, meter %.3f, starts %d" % [empty_frame, v.meter.meter, starts[0]])
	v.hold(false)
	await physics_frame
	# Under the minimum.
	v.meter.meter = 0.6
	await physics_frame
	var dim := wh.vision_dimmed()
	v.hold(true)
	await _frames(3)
	_check("acceptance: under the minimum it will not start: at 0.6 s of 3 a press does nothing, and its line is dimmed", not v.is_on() and dim and starts[0] == 2, "%.3f" % v.meter.meter)
	v.hold(false)
	v.meter.meter = 3.0
	await physics_frame
	# A death, a respawn and a stopped input.
	v.hold(true)
	await _frames(30)
	p.set_alive(false)
	var at_death: float = v.meter.meter
	await _frames(60)
	var dead_off: bool = not v.is_on()
	var dead_meter: float = v.meter.meter
	p.set_alive(true)
	await physics_frame
	_check("acceptance: a death turns it off and leaves the meter as it was (%.2f s), and a derezzed player's meter does not refill" % at_death, dead_off and absf(dead_meter - at_death) < EPS and absf(at_death - 2.5) < EPS, "%.6f then %.6f" % [at_death, dead_meter])
	v.hold(true)
	await _frames(12)
	var before_respawn: float = v.meter.meter
	p.respawn_at(main.to_global(Vector3(-10.0, STAND_Y, 15.0)))
	var respawn_off: bool = not v.is_on() and v.meter.meter == before_respawn
	await physics_frame
	_check("acceptance: a respawn turns it off too, the meter as it was", respawn_off and not v.is_on(), "%.3f" % before_respawn)
	v.hold(false)
	v.meter.meter = 3.0
	v.hold(true)
	await _frames(5)
	var was_on: bool = v.is_on()
	p.input_blocked = true
	await physics_frame
	var blocked_off: bool = not v.is_on()
	p.input_blocked = false
	await _frames(3)
	_check("the Esc menu or the ask box (the player's input stopped) turns it off, and it stays off without a new press", was_on and blocked_off and not v.is_on())
	v.hold(false)
	await physics_frame
	# The silhouettes: dummies behind a wall, in range and out of it.
	var dummies: Array = []
	for name in ["DummyA", "DummyB", "DummyC", "DummyD"]:
		dummies.append(main.get_node("Arena/Targets/" + name))
	_place(main, dummies[0], -2.0, 15.0)  # 8 m off, behind the wall
	_place(main, dummies[1], 19.5, -19.5)  # 45 m off: out of range
	_place(main, dummies[2], 19.5, -10.0)  # 38.7 m off: in range
	_place(main, dummies[3], -10.0, 5.0)  # 10 m off, to be derezzed
	var wall := _wall(main, Vector3(-6.0, 1.5, 15.0), Vector3(0.4, 3.0, 6.0))
	v.meter.meter = 3.0
	await _frames(3)
	var eye: Vector3 = p.eye_position()
	var sight: Dictionary = p.get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(eye, dummies[0].global_position + Vector3.UP * 0.9, 1))
	var behind: bool = not sight.is_empty() and sight["collider"] == wall
	var off_marked: Array = v.marked()
	dummies[3].hit(10000.0, dummies[3].global_position + Vector3.UP, Vector3.FORWARD)
	v.hold(true)
	await _frames(15)
	var marked: Array = v.marked()
	var marker: MeshInstance3D = v.marker_of(dummies[0])
	var on_middle: bool = marker != null and marker.visible and marker.global_position.distance_to(dummies[0].global_position + Vector3.UP * 0.9) < 0.001
	_check("acceptance: a dummy behind a wall (a wall really between, by ray) gets a silhouette only while vision is on: none before, one standing on its middle now, drawn by the see-through glyph material", behind and off_marked.is_empty() and marked.has(dummies[0]) and on_middle and marker.material_override == v.marker_material() and v.marker_material().shader.resource_path == "res://shaders/vision_glyphs.gdshader")
	_check("acceptance: only within range: the dummy 38.7 m off is shown, the one 45 m off is not, nor a derezzed one; nearest first", marked.has(dummies[2]) and not marked.has(dummies[1]) and not marked.has(dummies[3]) and marked.find(dummies[0]) < marked.find(dummies[2]), "%d shown" % marked.size())
	# The look, and the weapon.
	var look_full: float = v.look_strength()
	var cover: ColorRect = v.get("_cover")
	var shots: int = p.shots_fired
	p.drive_input(Vector2.ZERO, false, false, true)
	await physics_frame
	var fired: bool = p.shots_fired == shots + 1 and v.is_on()
	_check("the look on this screen alone: up to full strength in 0.2 s (12 frames), the picture multiplied toward the green tint; and the weapon still fires with vision on", absf(look_full - 1.0) < EPS and cover.visible and cover.color.is_equal_approx(_t.tint) and fired, "look %.3f" % look_full)
	v.hold(false)
	var steps := []
	for i in 14:
		await physics_frame
		steps.append(v.look_strength())
	var gentle := true
	for i in range(1, steps.size()):
		gentle = gentle and steps[i - 1] - steps[i] <= 1.0 / 12.0 + EPS
	_check("let go, every silhouette goes at once and the look eases out over 0.2 s, never a flash or a jump", v.marked().is_empty() and not marker.visible and steps[-1] == 0.0 and gentle and not cover.visible, str(steps.map(func(x): return snappedf(x, 0.01))))
	GameSettings.current().set_value("hud", "screen_shake", false)
	v.meter.meter = 3.0
	v.hold(true)
	await _frames(15)
	var calm_look: float = v.look_strength()
	var calm_flicker: float = v.marker_material().get_shader_parameter("flicker_rate")
	_check("with the comfort settings (screen shake off) the look is calmer, half strength, and the glyphs hold still", v.calm() and absf(calm_look - 0.5) < EPS and calm_flicker == 0.0, "%.3f %.1f" % [calm_look, calm_flicker])
	v.hold(false)
	GameSettings.current().set_value("hud", "screen_shake", true)
	await _frames(15)
	_check("and back to the full look and moving glyphs when shake is on again", not v.calm() and v.marker_material().get_shader_parameter("flicker_rate") > 0.0)
	wall.free()
	_drop(arena)
	await _frames(3)
	var orphans_after := int(Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT))
	_check("solo: no orphan node left behind", orphans_after <= orphans, "%d before, %d after" % [orphans, orphans_after])


# --- A match. ---

func _match_checks() -> void:
	var orphans := int(Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT))
	var host := _branch("Host", Vector3.ZERO)
	var client := _branch("Client", CLIENT_OFFSET)
	var joined := await _join(host, client)
	var hs: Session = host["session"]
	var cs: Session = client["session"]
	var hp: Node = host["player"]
	var cp: Node = client["player"]
	var cid: int = cs.my_id
	await _until(func(): return hs.avatars.has(cid) and cs.avatars.has(1) and hs.combat.has_player(cid) and cs.get("_weapons_synced"), 6000)
	hp.respawn_at(host["main"].to_global(Vector3(-2.0, STAND_Y, 15.0)))
	cp.respawn_at(client["main"].to_global(Vector3(-12.0, STAND_Y, 15.0)))
	var seen := await _until(func(): return cs.avatars.has(1) and cs.avatars[1].latest_position().distance_to(Vector3(-2.0, 0.9, 15.0)) < 0.1, 4000)
	var cv = cp.get("vision")
	var intents_before: int = hs.get("_actions_from").get(cid, 0)
	var drops_before: int = hs.combat.dropped
	cv.hold(true)
	await _frames(15)
	var marked: Array = cv.marked()
	var host_avatar = cs.avatars.get(1)
	_check("in a match the joiner's vision shows the other player and no dummy: the host's avatar, 10 m off, is its one silhouette", joined and seen and cv.is_on() and marked.size() == 1 and marked[0] == host_avatar and cv.marker_of(host_avatar).global_position.distance_to(host_avatar.global_position) < 0.1, "%d shown" % marked.size())
	await _frames(30)
	_check("acceptance: nothing is sent for it: the host has no new intent from the joiner and drops nothing, and the host's own vision is untouched", hs.get("_actions_from").get(cid, 0) == intents_before and hs.combat.dropped == drops_before and not hp.get("vision").is_on())
	var kept: float = cv.meter.meter
	cs.leave()
	await physics_frame
	_check("acceptance: leaving the match turns it off, the meter as it was", not cv.is_on() and absf(cv.meter.meter - kept) < FRAME + EPS, "%.3f then %.3f" % [kept, cv.meter.meter])
	cv.hold(false)
	_drop(host)
	_drop(client)
	await _frames(4)
	var orphans_after := int(Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT))
	_check("acceptance: no orphan nodes are left behind by any of it", orphans_after <= orphans, "%d before, %d after" % [orphans, orphans_after])


# --- Helpers. ---

func _shown(action: String) -> String:
	for pair in Controls.REBINDABLE:
		if pair[0] == action:
			return pair[1]
	return ""


func _place(main: Node, dummy: Node, x: float, z: float) -> void:
	dummy.global_position = main.to_global(Vector3(x, 0.0, z))


func _face(p: Node, facing: Vector3) -> void:
	p.rotation.y = atan2(-facing.x, -facing.z)
	p.get_node("Head").rotation.x = 0.0


func _wall(main: Node, at: Vector3, size: Vector3) -> StaticBody3D:
	var wall := StaticBody3D.new()
	wall.collision_layer = 1
	var box := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	box.shape = shape
	wall.add_child(box)
	main.add_child(wall)
	wall.global_position = main.to_global(at)
	return wall


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


## A shader function from its head line to the line that closes it, or "".
func _body_of_shader(source: String, head: String) -> String:
	var at := source.find(head)
	if at < 0:
		return ""
	var end := source.find("\n}\n", at)
	return source.substr(at, end + 3 - at) if end > 0 else ""


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
	GameSettings.current().set_value("hud", "screen_shake", true)
	await process_frame
	OS.delay_msec(300)
	await process_frame
