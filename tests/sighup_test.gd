extends SceneTree
## Headless test of SIGHUP, the confusion grenade, weapon 13, for SIGKILL (C32, PRD 5.2: "SIGHUP: confusion
## grenade; enemies 'reload' and wander"). scripts/check.sh runs it as step 46, and any FAIL exits 1.
##
##   godot --headless --path . --fixed-fps 60 --script res://tests/sighup_test.gd
##
## The weapon: its resource's numbers and its checks (a thrown weapon with its SighupTuning, two charges that
## come back; the tuning's refusals), its own carrier green measured in OKLab against every bright colour of
## the palette and kept well clear of ICE's, Black ICE's, the breakers', chmod's, the pipe's and /dev/null's.
## The keys: Shift+4 draws it, 4 the fork bomb, Q and the wheel reach it; the strip and a confused player's
## line at 960x540. In the real arena with the real player: the throw (the device flies, lands and goes off
## over the floor; in the air on its fuse; two in the air at most; its charges back; root's free and wider),
## then in practice a burst over the dummies (each caught as its wave's front passes, within its reach only:
## the reload's stall, its tag and its seams, then the confused wander and the walk home; the burst's look,
## its tag and the callout), the guard (a second burst while confused or just after is refused, taken again
## once the guard is over), the level (nothing behind a wall caught); fighting daemons: a tell called off and
## the prey dropped, no attack on the player while confused, and the crowd turning on itself (a lash from
## rogue.d's slash and a zombie's bolt, at the lash's share, a lash kill the thrower's); a chmod-frozen daemon
## taking it frozen and starting confused when it thaws; a /dev/null hole dragging a confused daemon harder;
## ping outlining the confused in the carrier green; ICE: the hunter confused and forgetting what it learned, a
## node reloading (its field dropped, then back), a wall untouched; Black ICE ignoring it ("SIGHUP: ignored
## (nohup)"). Then a host and a joiner over ENet on 127.0.0.1 (the joiner's arena 1000 m off): the host runs
## and judges the joiner's burst (its charges counted, where it went off told, the host's player confused on
## its own screen, no damage, every control still working), spawn protection holds, the thrower is never
## caught, the host's burst confuses the joiner on the joiner's screen alone, a joiner's burst confuses the
## host's daemons and the joiner's copies show it; protocol 18, no new message. And the fiction rule for its
## code (no real signal, ever), and nothing made while a burst runs. Deterministic: frames counted, only
## counts and outcomes printed.

const Session = preload("res://scripts/net/net_session.gd")
const NetTuningScript = preload("res://scripts/net/net_tuning.gd")
const Link = preload("res://scripts/guide/guide_link.gd")
const MainScene = preload("res://scenes/main.tscn")
const Controls = preload("res://scripts/controls.gd")
const Palette = preload("res://scripts/palette.gd")
const WeaponDefScript = preload("res://scripts/weapons/weapon_def.gd")
const PingPulseScript = preload("res://scripts/weapons/ping_pulse.gd")
const HUP_PATH := "res://resources/sighup.tres"
const HUP_CODE := ["res://scripts/weapons/sighup_burst.gd", "res://scripts/weapons/sighup_look.gd", "res://scripts/weapons/sighup_tuning.gd", "res://scripts/hud/sighup_hud.gd", "res://scripts/fx/hup_look.gd", "res://scripts/viewmodels/sighup.gd"]
const WATCHDOG_MS := 12000
const CLIENT_OFFSET := Vector3(1000.0, 0.0, 0.0)
## Open floor south of the low wall, clear of the crates and the platform.
const OPEN := Vector3(0.0, 0.95, 15.0)
const PARKED := Vector3(0.0, -50.0, 0.0)
## SIGHUP's slot (slot 13: bank 2's fourth), /dev/null's before it, the fork bomb's (key 4) and ping's.
const SLOT := 12
const HOLE := 11
const FORK := 3
const PING := 8
const NEVER := ["OS.", "execute", "create_process", "kill(", "Thread", "HTTP", "PacketPeer", "StreamPeer", "TCPServer", "UDPServer", "DirAccess", "FileAccess", "set_unix_permissions", "shell_open", "move_to_trash", "Expression", "Time.", "ctrl_pressed", "alt_pressed", "rpc", ".open("]
## How far apart (OKLab) the carrier green keeps from every bright colour, and from ICE's, Black ICE's, the
## breakers', chmod's, the pipe's and /dev/null's.
const APART := 0.16
const APART_NAMED := 0.165
const APART_TEXT := 0.13
const TOUGH := 400.0
const LONG_ROUND_S := 100000.0
const EPS := 0.001

var _fails := 0
var _checks := 0
var _tmp := ""
var _arenas: Array = []
var _branches: Array = []
var _def: WeaponDefScript
var _t: SighupTuning


func _initialize() -> void:
	_run()


func _run() -> void:
	await process_frame
	root.size = Vector2i(1280, 720)
	_tmp = OS.get_temp_dir().path_join("sigkill-sighup-test-%d" % OS.get_process_id())
	if DirAccess.dir_exists_absolute(_tmp):
		print("FAIL the test's temporary folder already exists; not touching it")
		quit(1)
		return
	DirAccess.make_dir_recursive_absolute(_tmp)
	Controls.ensure()
	GameSettings.current().reset()
	_def = load(HUP_PATH)
	_t = _def.hup_tuning()
	_source_checks()
	_weapon_checks()
	_palette_checks()
	_rule_checks()
	await _key_checks()
	await _strip_checks()
	await _throw_checks()
	await _practice_checks()
	await _guard_checks()
	await _level_checks()
	await _tell_checks()
	await _lash_checks()
	await _frozen_checks()
	await _hole_checks()
	await _ping_checks()
	await _ice_checks()
	await _black_checks()
	await _match_checks()
	await _cleanup()
	for name in DirAccess.get_files_at(_tmp):
		DirAccess.remove_absolute(_tmp.path_join(name))
	DirAccess.remove_absolute(_tmp)
	print("SIGHUP: %d checks" % _checks)
	print("SIGHUP RESULT: ", "ALL PASS" if _fails == 0 else "%d FAILED" % _fails)
	quit(0 if _fails == 0 else 1)


func _check(label: String, ok: bool, detail: String = "") -> void:
	_checks += 1
	print("PASS " if ok else "FAIL ", label, ("   " + detail) if detail != "" else "")
	if not ok:
		_fails += 1


# --- The code, the weapon, its numbers and its colour. ---

func _source_checks() -> void:
	var code := ""
	for path in HUP_CODE:
		code += _code(path)
	var found := PackedStringArray()
	for word in NEVER:
		if code.contains(word):
			found.append(word)
	var brain := _code("res://scripts/fight/daemon_brain.gd")
	var hup_part := brain.substr(brain.find("# --- SIGHUP (C32)"), brain.find("# --- A joiner's copy") - brain.find("# --- SIGHUP (C32)"))
	for word in NEVER:
		if hup_part.contains(word):
			found.append("brain: " + word)
	_check("acceptance: fiction only, never a real signal: SIGHUP's code (the burst, its look, its tuning, the HUD, a target's look, the model, and the brain's confusion) sends no signal to anything real: no OS, process, file, folder, thread or network call, no RPC, no wall clock, no Ctrl or Alt key", found.is_empty() and code.length() > 15000 and hup_part.length() > 6000 and code.contains("\"SIGHUP: ignored (nohup)\""), ", ".join(found))
	var burst := _code(HUP_CODE[0])
	var look := _code(HUP_CODE[1])
	var hud := _code(HUP_CODE[3])
	var tag := _code(HUP_CODE[4])
	var each := ""
	for fn in ["_physics_process", "_process", "_fly", "_sweep", "_refuse", "reaches", "front_m"]:
		each += _body(burst, fn)
	each += _body(look, "show_state") + _body(hud, "_refresh") + _body(hud, "_process") + _body(tag, "_step") + _body(tag, "show_phase")
	var made := PackedStringArray()
	for word in [".new(", "instantiate(", "duplicate(", "Mesh(", "Material(", "add_child"]:
		if each.contains(word):
			made.append(word)
	_check("acceptance: nothing is made while a burst runs: what runs each frame (the throw, the wave's sweep, the look's state, the confused tags, the HUD) makes no node, mesh or material; the look is made once per throw, a target's tag once per target", made.is_empty() and each.length() > 5000, ", ".join(made))


func _weapon_checks() -> void:
	var t := _t
	_check("acceptance: its numbers, all in one resource (resources/sighup.tres, its SighupTuning inside): %d charges, one back every %.0f s, a throw every %.1f s at %.0f m/s plus %.0f up, a %.1f s fuse, %d in the air at once; the burst reaching %.0f m (%.2f m as root), its wave %.0f m/s; a daemon's reload %.1f s, its wander %.1f s at %.0f%% of its speed (legs %.1f s, looks %.1f s, sweeping %.1f rad, stuttering %.0f%% at %.0f Hz), guarded %.0f s after; lashes within %.1f m at %.0f%% of its own damage, %d a confusion, the first %.1f s in, %.1f s apart; a hole drags it %.1fx; a node reloads %.0f s; a player confused %.1f s, its crosshair drifting %.0f px; no damage of its own" % [_def.magazine_size, t.recharge_s, _def.fire_cooldown, t.throw_speed, t.throw_lift, t.fuse_s, t.live_cap, t.radius_m, t.reach_for(true), t.wave_speed, t.reload_s, t.wander_s, t.wander_share * 100.0, t.leg_s, t.look_s, t.look_sweep, t.stutter_share * 100.0, t.stutter_hz, t.immune_s, t.lash_range_m, t.lash_scale * 100.0, t.lash_most, t.lash_first_s, t.lash_gap_s, t.hole_pull_scale, t.node_reload_s, t.player_s, t.player_drift_px], _def.problems().is_empty() and t.problems().is_empty() and _def.is_thrown() and _def.is_hup() and not _def.is_hole() and _def.fire_mode == WeaponDefScript.FireMode.PROJECTILE and _def.magazine_size == 2 and _def.reserve_ammo == 0 and _def.fire_cooldown == 0.8 and _def.damage == 0.0 and t.recharge_s == 12.0 and t.throw_speed == 14.0 and t.throw_lift == 3.0 and t.fuse_s == 1.2 and t.live_cap == 2 and t.radius_m == 7.0 and t.root_radius_scale == 1.25 and t.wave_speed == 14.0 and t.burst_lift_m == 0.5 and t.reload_s == 1.2 and t.wander_s == 4.0 and t.immune_s == 6.0 and t.wander_share == 0.55 and t.leg_s == 1.1 and t.look_s == 0.6 and t.look_sweep == 1.1 and t.stutter_hz == 5.0 and t.stutter_share == 0.3 and t.lash_range_m == 3.5 and t.lash_scale == 0.75 and t.lash_most == 2 and t.lash_first_s == 0.4 and t.lash_gap_s == 1.4 and t.hole_pull_scale == 1.3 and t.node_reload_s == 5.0 and t.player_s == 2.5 and t.player_drift_px == 22.0 and _def.charges_tuning() == t, str(_def.problems()) + str(t.problems()))
	_check("it is weapon 13 as built: \"SIGHUP\" (short \"SIGHUP\"), fiction \"%s\", the feed's \"kill -HUP\", the carrier light skin, thrown from its two charges, its own model (a telephone handset)" % _def.fiction, _def.id == "sighup" and _def.display_name == "SIGHUP" and _def.short_name == "SIGHUP" and _def.kill_word == "kill -HUP" and _def.fiction == "SIGHUP: NO CARRIER" and _def.light_skin == "carrier" and _def.viewmodel_model != null and _def.viewmodel_model.resource_path == "res://scripts/viewmodels/sighup.gd")
	var refusals := 0
	for change in [["immune_s", 0.0], ["wander_s", 0.0], ["reload_s", 25.0], ["wave_speed", 0.5], ["live_cap", 0], ["lash_first_s", 9.0], ["stutter_share", 0.95], ["player_s", 9.0], ["hole_pull_scale", 0.5], ["recharge_s", 0.0], ["radius_m", 0.0]]:
		var bad: SighupTuning = t.duplicate()
		bad.set(change[0], change[1])
		refusals += 0 if bad.problems().is_empty() else 1
	var none: WeaponDefScript = _def.duplicate()
	none.projectile = null
	refusals += 1 if ", ".join(none.problems()).contains("a DevNullTuning or a SighupTuning") else 0
	var endless: WeaponDefScript = _def.duplicate()
	endless.magazine_size = -1
	endless.reserve_ammo = -1
	endless.reload_s = 0.0
	refusals += 0 if endless.problems().is_empty() else 1
	_check("the checks refuse what would break it: no guard (a daemon held confused for ever), no wander, a reload past its bound, a wave too slow, none in the air (live cap 0), a first lash after the wander, a stutter that never moves, a player's confusion too long, a hole that drags it softer, no recharge, no reach, no tuning, and no charges (13 of 13)", refusals == 13, "%d of 13" % refusals)


func _palette_checks() -> void:
	var src := FileAccess.get_file_as_string("res://scripts/palette.gd")
	var rx := RegEx.create_from_string("const ([A-Z_]+) := Color\\(")
	var consts: Dictionary = (Palette as Script).get_script_constant_map()
	var least := INF
	var near := ""
	var text_least := INF
	var text_near := ""
	for m in rx.search_all(src):
		var key := m.get_string(1)
		if key.begins_with("SIGHUP"):
			continue
		if key.begins_with("SKIN_"):
			continue  # the earned light skins (C33) are alternates, guarded against the hostile lights (tests/unlocks_test.gd)
		var c: Color = consts[key]
		if maxf(c.r, maxf(c.g, c.b)) <= 0.5:
			continue  # the dark bases, armour and glass: nothing bright to confuse it with
		var dist := _oklab(Palette.SIGHUP).distance_to(_oklab(c))
		if dist < least:
			least = dist
			near = key
		var text_dist := _oklab(Palette.SIGHUP_TEXT).distance_to(_oklab(c))
		if text_dist < text_least:
			text_least = text_dist
			text_near = key
	var named := {}
	for key in ["GLACIER", "HUNTER_COBALT", "BLACK_ICE", "BREAKER", "FROST", "PIPE", "DEV_NULL", "CRIMSON", "HOSTILE_AMBER", "HOT_MAGENTA", "LIME"]:
		named[key] = _oklab(Palette.SIGHUP).distance_to(_oklab(consts[key]))
	var named_least: float = named.values().min()
	var text_l := _oklab(Palette.SIGHUP_TEXT).x
	_check("acceptance: its own colour, a carrier green #%s (an old modem's carrier light), reads apart: at least %.2f (OKLab) from every bright colour of the palette (nearest %s, %.3f: every hue band is held, so it is the farthest point of all of sRGB; then the pipe's brass %.3f, the code rain's green %.3f, the player's teal %.3f), %.3f and more from ICE's glacier (%.3f), the hunter's cobalt (%.3f), Black ICE's slate (%.3f), the breakers' ultraviolet (%.3f), chmod's frost opal (%.3f), the pipe's brass (%.3f), /dev/null's plum (%.3f), the daemons' crimson, amber and hot magenta (%.3f, %.3f, %.3f) and ping's lime (%.3f, so its wave never reads as ping's ring); its HUD text #%s legible on black (lightness %.2f; %.3f from the nearest, %s)" % [Palette.SIGHUP.to_html(false), APART, near, least, named["PIPE"], _oklab(Palette.SIGHUP).distance_to(_oklab(Palette.MATRIX_GREEN)), _oklab(Palette.SIGHUP).distance_to(_oklab(Palette.TEAL)), APART_NAMED, named["GLACIER"], named["HUNTER_COBALT"], named["BLACK_ICE"], named["BREAKER"], named["FROST"], named["PIPE"], named["DEV_NULL"], named["CRIMSON"], named["HOSTILE_AMBER"], named["HOT_MAGENTA"], named["LIME"], Palette.SIGHUP_TEXT.to_html(false), text_l, text_least, text_near], least >= APART and named_least >= APART_NAMED and text_least >= APART_TEXT and text_l >= 0.75 and Palette.SIGHUP.to_html(false) == "00bf00" and Palette.SKINS.get("carrier").slice(0, 2) == [Palette.SIGHUP, Palette.SIGHUP_TEXT] and Palette.skin_hot("carrier") == Palette.SIGHUP_HI)


# --- Its rules on their own. ---

func _rule_checks() -> void:
	var t := _t
	var charges := [1, 0.0]
	for i in 719:
		charges = t.step_charges(charges[0], 2, charges[1], 1.0 / 60.0)
	var before_back: int = charges[0]
	charges = t.step_charges(charges[0], 2, charges[1], 2.0 / 60.0)
	var host := [1, 0.0]
	for i in 9 * 60 + 1:
		host = t.step_charges(host[0], 2, host[1], 1.0 / 60.0, 0.25)
	_check("acceptance: its rules: its wave reaches %.0f m in %.2f s (%.2f m as root), a daemon is confused %.1f s in all (the most of any stretch it can be: %.0f%%, the guard between), and a spent charge is back %.0f s later (still %d a frame before, %d after; the host's count a quarter quicker: %d in 9 s)" % [t.radius_m, t.wave_at(t.radius_m), t.reach_for(true), t.confused_s(), 100.0 * t.confused_s() / (t.confused_s() + t.immune_s), t.recharge_s, before_back, charges[0], host[0]], absf(t.wave_at(7.0) - 0.5) < EPS and absf(t.reach_for(true) - 8.75) < EPS and absf(t.confused_s() - 5.2) < EPS and before_back == 1 and charges[0] == 2 and host[0] == 2 and t.step_charges(2, 2, 0.0, 30.0) == [2, 0.0])


# --- The keys. ---

func _key_checks() -> void:
	var main := await _lab({}, OPEN, true)
	var p = main.get_node("Player")
	var wh = main.get_node("Hud").weapon_hud()
	await _frames(20)
	await _key(KEY_4, true)
	var shift_four: int = p.inventory.current
	var strip_four: String = wh.bank2_text()
	var lit: int = wh.active_bank()
	await _key(KEY_4)
	var four: int = p.inventory.current
	await _key(KEY_Q)
	var q_back: int = p.inventory.current
	await _key(KEY_3, true)
	await _wheel(MOUSE_BUTTON_WHEEL_DOWN)
	var wheel_on: int = p.inventory.current
	await _wheel(MOUSE_BUTTON_WHEEL_DOWN)
	var wheel_wrap: int = p.inventory.current
	await _wheel(MOUSE_BUTTON_WHEEL_UP)
	var wheel_back: int = p.inventory.current
	_check("acceptance: Shift+4 draws weapon 13, SIGHUP (\"%s\" on the strip, bank 2 lit), 4 draws the fork bomb, Q swaps back to SIGHUP, and the wheel reaches it from /dev/null, wraps on to the cannon and comes back" % strip_four, shift_four == SLOT and strip_four == "Shift+ 1 2 3(2) [4 SIGHUP]" and lit == 1 and four == FORK and q_back == SLOT and wheel_on == SLOT and wheel_wrap == 0 and wheel_back == SLOT and p.weapon_tuning().id == "sighup", "%d %d %d %d %d %d %s" % [shift_four, four, q_back, wheel_on, wheel_wrap, wheel_back, strip_four])
	await _drop(main)


# --- The strip and a confused player's line at 960x540. ---

func _strip_checks() -> void:
	var before := root.size
	var wrong := PackedStringArray()
	var lines := PackedStringArray()
	var said := ""
	for size in [Vector2i(1280, 720), Vector2i(960, 540)]:
		root.size = size
		var host := _branch("Layout", Vector3.ZERO)
		await _frames(2)
		host["session"].host(0)
		var p = host["player"]
		p.select_slot(SLOT)
		await _frames(110)  # past the fiction line's moment
		var hud = host["hud"]
		var feed_hud = host["combat_hud"]
		host["session"].players[7] = {"slot": 2, "name": "Daemon-2"}
		for i in 4:
			feed_hud.entries.push_front({"killer": "Daemon-2", "victim": "Daemon-1", "word": "kill -HUP", "left": 2.0})
		hud.guide()._notice("word ".repeat(60), Color.WHITE, 5000)
		hud.net_hud().toggle()
		p.inventory.mags[SLOT] = 1  # one spent: its recharge on the strip
		p.take_hup(_t.player_s, _t.player_drift_px)  # as if another player's SIGHUP caught it
		p.hole_drag = Vector3(3.0, 0.0, 0.0)  # and another's hole dragged it: both warnings
		await _frames(3)
		var screen := Rect2(Vector2.ZERO, Vector2(root.size))
		var panels := [hud.net_hud().get("_panel"), hud.guide().get("_panel")]
		var strip: Control = hud.weapon_hud().get("_stack")
		var feed: Control = feed_hud.get("_feed")
		for label in host["main"].find_children("*", "Label", true, false):
			if not label.is_visible_in_tree() or label.text.is_empty() or not strip.is_ancestor_of(label):
				continue
			var rect: Rect2 = label.get_global_rect()
			if feed.get_global_rect().intersects(rect):
				wrong.append("%d: strip under the feed: %s" % [size.x, label.text])
			if not screen.encloses(rect):
				wrong.append("%d: outside: %s %s" % [size.x, label.text, rect])
			for panel in panels:
				if panel.get_global_rect().intersects(rect):
					wrong.append("%d: under a panel: %s" % [size.x, label.text])
		var sh = hud.sighup_hud()
		var dh = hud.dev_null_hud()
		p.hole_drag = Vector3(3.0, 0.0, 0.0)  # its physics step clears the drag each frame: both lines drawn now
		dh._refresh()
		sh._refresh()
		var line: Label = sh.get("_line")
		var rect: Rect2 = line.get_global_rect()
		if not line.visible or not screen.encloses(rect) or strip.get_global_rect().intersects(rect) or feed.get_global_rect().intersects(rect):
			wrong.append("%d: line %s %s" % [size.x, line.text, rect])
		var hole_line: Label = dh.get("_line")
		if not hole_line.visible or hole_line.get_global_rect().intersects(rect):
			wrong.append("%d: over /dev/null's warning (or it was not drawn)" % size.x)
		said = sh.line_text()
		lines = PackedStringArray([hud.weapon_hud().bank2_text(), hud.weapon_hud().slots_text(), hud.weapon_hud().ammo_text(), hud.weapon_hud().state_text()])
		await _drop_side(host)
	root.size = before
	_check("acceptance: at 960x540 (and 1280x720) the strip keeps its two rows in its own column, SIGHUP in bank 2's (\"%s\" over \"%s\"), with its charges (\"%s\", \"%s\"): every line inside the screen, clear of a full kill feed, the net panel and a long guide notice; and a confused player's line over the crosshair (\"%s\"), inside the screen, clear of the strip, the feed and /dev/null's warning" % [lines[0], lines[1], lines[2], lines[3], said], wrong.is_empty() and lines[0] == "Shift+ 1 2 3(2) [4 SIGHUP]" and lines[1] == "1 2 3 4(2) 5 6 7 8 9" and lines[2] == "SIGHUP  1 left" and lines[3].begins_with("recharge [") and said == "SIGHUP: hung up  NO CARRIER", ", ".join(wrong) + " / " + " | ".join(lines))


# --- The throw. ---

func _throw_checks() -> void:
	var main := await _lab({}, OPEN, true)
	var p = main.get_node("Player")
	var drawn := await _draw(p)
	var target: Vector3 = main.to_global(Vector3(0.0, 0.0, 9.0))
	_aim(p, target)
	await _fire(p)
	var burst := _burst(main)
	var left: int = p.inventory.mags[SLOT]
	var flew := 0
	var start := burst.global_position if burst != null else Vector3.INF
	var device_seen := false
	while burst != null and is_instance_valid(burst) and burst.phase == SighupBurst.Phase.FLYING and flew < 200:
		device_seen = device_seen or burst.get("_look").device().visible
		flew += 1
		await physics_frame
	var went := burst != null and is_instance_valid(burst) and burst.went()
	var middle: Vector3 = main.to_local(burst.center) if went else Vector3.INF
	var off: float = Vector2(middle.x, middle.z).distance_to(Vector2(0.0, 9.0)) if went else INF
	_check("acceptance: the throw: aimed at the floor 6 m off, the device (a handset, tumbling) leaves from just ahead of the eyes (%.2f m), arcs for %d frames and goes off where it lands, %.2f m from the aim, its middle %.2f m over the floor; a charge spent (%d left)" % [p.eye_position().distance_to(start), flew, off, middle.y, left], drawn and device_seen and went and flew > 5 and flew < 60 and off < 1.0 and absf(middle.y - _t.burst_lift_m) < 0.05 and left == 1 and p.eye_position().distance_to(start) < 0.7)
	await _wait(_done(burst), 200)
	# At the open sky: the fuse sets it off in the air. Two in the air at most: a third waits.
	p.get_node("Head").rotation.x = 0.9
	p.inventory.mags[SLOT] = 2
	await _frames(int(_def.fire_cooldown * 60.0) + 2)
	await _fire(p)
	var sky := _burst(main)
	await _frames(int(_def.fire_cooldown * 60.0) + 2)
	await _fire(p)
	p.inventory.mags[SLOT] = 2
	await _frames(int(_def.fire_cooldown * 60.0) - 46)
	var flying := SighupBurst.live_of(main, "solo")
	await _fire(p)
	var refused_third: bool = p.inventory.mags[SLOT] == 2
	var went_at := await _wait(func(): return sky != null and is_instance_valid(sky) and sky.went(), 150)
	var air: float = main.to_local(sky.center).y if went_at >= 0 else -INF
	var air_s: float = sky.age if went_at >= 0 else -1.0
	_check("acceptance: thrown at the sky it goes off in the air when its %.1f s fuse runs out (%.2f s, %.1f m up); two in the air at most: a third throw while two fly is refused, its charge kept (%d flying, %d left)" % [_t.fuse_s, air_s, air, flying, p.inventory.mags[SLOT]], went_at >= 0 and absf(air_s - _t.fuse_s) < 0.05 and air > 3.0 and flying == 2 and refused_third, str(went_at))
	await _wait(func(): return SighupBurst.live_of(main, "solo") == 0 and main.find_children("Sighup", "", true, false).is_empty(), 300)
	# Both charges spent; one comes back after its recharge.
	p.inventory.mags[SLOT] = 0
	p.inventory.recharges[SLOT] = 0.0
	await _frames(2)
	var back := await _wait(func(): return p.inventory.mags[SLOT] == 1, int(_t.recharge_s * 60.0) + 30)
	_check("both charges spent, one comes back on its own %.0f s later (%d frames), the model's carrier lights lit by it (%.2f)" % [_t.recharge_s, back, p.get("_viewmodel").charge()], back >= int(_t.recharge_s * 60.0) - 10 and back >= 0 and absf(p.get("_viewmodel").charge() - 0.5) < 0.01)
	# Root: thrown for free, its burst wider.
	p.sudo.state.charges = 1
	p.sudo.press()
	await _frames(3)
	var root_now: bool = p.sudo.is_root()
	_aim(p, target)
	var had: int = p.inventory.mags[SLOT]
	await _frames(int(_def.fire_cooldown * 60.0) + 2)
	await _fire(p)
	var rooted := _burst(main)
	_check("root throws for free (%d left, as before) and its burst reaches %.2f m (%.2fx)" % [p.inventory.mags[SLOT], rooted.reach if rooted != null else -1.0, _t.root_radius_scale], root_now and rooted != null and p.inventory.mags[SLOT] == had and absf(rooted.reach - _t.reach_for(true)) < EPS)
	await _drop(main)


# --- In practice: a burst over the dummies. ---

func _practice_checks() -> void:
	var spots := {"DummyA": Vector3(0.0, 0.0, 7.0), "DummyB": Vector3(5.5, 0.0, 3.0), "DummyC": Vector3(-7.8, 0.0, 3.0), "DummyD": Vector3(-3.0, 0.0, 6.0)}
	var main := await _lab(spots, OPEN, true)
	var p = main.get_node("Player")
	var round_hud = main.get_node("Hud").round_hud()
	var fx := main.get_tree().get_first_node_in_group(ParticleFx.GROUP) as ParticleFx
	var sparks: int = fx.fired(ParticleFx.Kind.HUP) if fx != null else -1
	var homes := {}
	for name in spots:
		homes[name] = _dummy(main, name).global_position
	var caught_at := {}
	var burst := _spawn(main, p, Vector3(0.0, 0.2, 4.0))
	burst.caught.connect(func(what: Node, _at: Vector3): caught_at[String(what.name)] = burst.wave_age)
	await _wait(func(): return burst.went(), 60)
	var middle: Vector3 = burst.center
	await _frames(int(burst.wave_s() * 60.0) + 4)
	var wrong := PackedStringArray()
	for name in caught_at:
		var d: float = (_dummy(main, name).global_position + Vector3.UP * DaemonBrain.MIDDLE_M).distance_to(middle)
		if absf(caught_at[name] - d / _t.wave_speed) > 2.0 / 60.0:
			wrong.append("%s at %.3f s, %.2f m" % [name, caught_at[name], d])
	var far := _dummy(main, "DummyC")
	var far_d: float = (far.global_position + Vector3.UP * DaemonBrain.MIDDLE_M).distance_to(middle)
	_check("acceptance: its radius: each daemon is caught as its wave's front passes it (%s: at its distance over %.0f m/s), and the one %.2f m off, past its %.0f m reach, is not (%s)" % [", ".join(caught_at.keys()), _t.wave_speed, far_d, _t.radius_m, far.brain.hup_name()], caught_at.size() == 3 and not caught_at.has("DummyC") and far_d > _t.radius_m and far.brain.hup == DaemonBrain.Hup.NONE and wrong.is_empty(), ", ".join(wrong))
	var rogue := _dummy(main, "DummyA")
	var look: HupLook = rogue.hup_look()
	var stall_tag := look.tag_text() if look != null else ""
	var stall_at: Vector3 = rogue.global_position
	var hup_param = rogue.art_node().core_set().get_instance_shader_parameter(&"hup")
	var parts: Dictionary = burst.get("_look").parts()
	var shown: bool = parts["floor"].visible and parts["curtain"].visible and parts["flash"].light_energy > 0.0 and not burst.get("_look").device().visible
	var burst_tag: String = burst.get("_look").tag()
	_check("acceptance: the look of the burst: the carrier wave on the floor and its curtain of static out to %.1f m, its flash lighting what it reaches (%.1f), the device gone, the HUP static flung out (%d), its tag \"%s\"; the callout \"%s\"" % [burst.front_m(), parts["flash"].light_energy, (fx.fired(ParticleFx.Kind.HUP) - sparks) if fx != null else -1, burst_tag.replace("\n", " / "), round_hud.last_callout], shown and absf(burst.front_m() - _t.radius_m) < EPS and absf(parts["curtain"].scale.x - _t.radius_m) < 0.05 and burst_tag == "$ kill -HUP\nNO CARRIER  3 reloading" and round_hud.last_callout == "kill -HUP  NO CARRIER" and fx != null and fx.fired(ParticleFx.Kind.HUP) > sparks)
	# The reload's stall: still, its tag typing "reloading config", its seams scanned in the carrier green.
	await _frames(int(_t.reload_s * 60.0) - int(burst.wave_s() * 60.0) - 20)
	var stalled: float = rogue.global_position.distance_to(stall_at)
	var still_reloading: bool = rogue.brain.hup == DaemonBrain.Hup.RELOAD
	_check("acceptance: the reload: each daemon caught stalls (rogue.d moved %.3f m over the %.1f s), its tag \"%s\", its seams in the carrier green (its art's hup %s, the core shader's slot %s)" % [stalled, _t.reload_s, stall_tag.replace("\n", " / "), rogue.art_node().hup_phase, str(hup_param)], still_reloading and stalled < 0.01 and stall_tag.begins_with("SIGHUP: reloading config") and stall_tag.contains("[") and float(hup_param) == 1.0)
	# Then it wanders, confused: moving, its "?" over it, its seams cycling, looking round.
	var wandering := await _wait(func(): return rogue.brain.hup == DaemonBrain.Hup.WANDER, 60)
	var yaws := PackedFloat32Array()
	var spread := 0.0
	var tags := {}
	for i in int(_t.wander_s * 60.0) - 30:
		await physics_frame
		spread = maxf(spread, rogue.global_position.distance_to(stall_at))
		yaws.append(rogue.global_rotation.y)
		if look != null:
			tags[look.tag_text()] = true
	var turned := 0.0
	for i in range(1, yaws.size()):
		turned += absf(wrapf(yaws[i] - yaws[i - 1], -PI, PI))
	var none_attacked: bool = rogue.brain.tells == 0 and rogue.brain.lashes == 0
	_check("acceptance: then it wanders confused for %.1f s: no idea where anyone is (no prey), drifting up to %.1f m on its random walk, looking round (its facing swept %.1f rad in all), its tag a \"?\" (%s), its seams cycling (%s); practice's dummies never attack or lash (%d tells, %d lashes)" % [_t.wander_s, spread, turned, ", ".join(tags.keys()), str(rogue.art_node().core_set().get_instance_shader_parameter(&"hup")), rogue.brain.tells, rogue.brain.lashes], wandering >= 0 and spread > 0.8 and turned > 1.0 and tags.has("?") and rogue.brain.prey == 0 and float(rogue.art_node().core_set().get_instance_shader_parameter(&"hup")) == 2.0 and none_attacked)
	var cleared := await _wait(func(): return rogue.brain.hup == DaemonBrain.Hup.NONE, 120)
	var home := await _wait(func(): return rogue.global_position.distance_to(homes["DummyA"]) < DaemonBrain.HOME_M + 0.05, 900)
	_check("practice: its never-attack dummies take the reload and wander, then walk home (%d frames) and stand, their tags and seams themselves again (\"%s\", hup %s)" % [home, look.tag_text() if look != null else "", str(rogue.art_node().core_set().get_instance_shader_parameter(&"hup"))], cleared >= 0 and home >= 0 and look != null and look.tag_text() == "" and float(rogue.art_node().core_set().get_instance_shader_parameter(&"hup")) == 0.0)
	await _drop(main)


## The guard: a hangup while confused never makes it longer; after one, a while before the next.
func _guard_checks() -> void:
	var main := await _lab({"DummyB": Vector3(3.0, 0.0, 6.0)}, OPEN, true)
	var p = main.get_node("Player")
	var zombie := _dummy(main, "DummyB")
	var first := _spawn(main, p, Vector3(0.0, 0.2, 6.0))
	await _wait(func(): return zombie.brain.hup != DaemonBrain.Hup.NONE, 90)
	await _frames(30)
	var t_before: float = zombie.brain.hup_t
	var again := _spawn(main, p, Vector3(0.0, 0.2, 6.0))
	await _wait(func(): return again.went() and again.wave_age > again.wave_s(), 90)
	var first_caught: int = first.caught_count
	var refused_confused: bool = again.refused == 1 and zombie.brain.hups == 1 and zombie.brain.hup_t > t_before
	await _wait(func(): return zombie.brain.hup == DaemonBrain.Hup.NONE, int(_t.confused_s() * 60.0) + 30)
	var guard: float = zombie.brain.hup_guard
	var during := _spawn(main, p, Vector3(0.0, 0.2, 6.0))
	await _wait(func(): return during.went() and during.wave_age > during.wave_s(), 90)
	var refused_guard: bool = during.refused == 1 and zombie.brain.hup == DaemonBrain.Hup.NONE
	await _wait(func(): return zombie.brain.hup_guard <= 0.0, int(_t.immune_s * 60.0) + 30)
	var after := _spawn(main, p, Vector3(0.0, 0.2, 6.0))
	await _wait(func(): return after.went() and after.wave_age > after.wave_s(), 90)
	_check("acceptance: no chain-lock: a second burst while it is confused is refused (it does not start over: %d hangups), and for %.0f s after it is itself again (guard %.1f s) another is refused too; once the guard is over it takes one again (%s)" % [zombie.brain.hups, _t.immune_s, guard, zombie.brain.hup_name()], refused_confused and absf(guard - _t.immune_s) < 0.05 and refused_guard and after.caught_count == 1 and zombie.brain.hup == DaemonBrain.Hup.RELOAD and first_caught == 1)
	await _drop(main)


## The level: a daemon behind a wall when the front passes is spared.
func _level_checks() -> void:
	var main := await _lab({"DummyA": Vector3(1.8, 0.0, 4.6), "DummyB": Vector3(-1.0, 0.0, -0.8)}, Vector3(3.2, 0.95, 9.6), true)
	var p = main.get_node("Player")
	var behind := _dummy(main, "DummyB")
	var open_one := _dummy(main, "DummyA")
	var burst := _spawn(main, p, Vector3(1.8, 0.2, 5.2))
	await _wait(func(): return burst.went() and burst.wave_age > burst.wave_s(), 90)
	var d: float = (behind.global_position + Vector3.UP * DaemonBrain.MIDDLE_M).distance_to(burst.center)
	_check("acceptance: walls block it: the zombie %.1f m off behind the low wall (in reach, out of the burst's sight) is spared (%s, %d spared), while rogue.d in the open is caught (%s)" % [d, behind.brain.hup_name(), burst.spared, open_one.brain.hup_name()], d < _t.radius_m and behind.brain.hup == DaemonBrain.Hup.NONE and burst.spared >= 1 and open_one.brain.hup != DaemonBrain.Hup.NONE)
	await _drop(main)


# --- Fighting daemons: a tell called off, the prey dropped, the crowd turning on itself. ---

func _tell_checks() -> void:
	var main := await _lab({"DummyA": Vector3(0.0, 0.0, 9.5)}, Vector3(0.0, 0.95, 14.0), false)
	var p = main.get_node("Player")
	var life := _life(main)
	life.combat.states[1]["protect_left"] = 0.0
	var rogue := _dummy(main, "DummyA")
	_toughen(rogue, TOUGH)
	var telling := await _wait(func(): return rogue.brain.state == DaemonBrain.State.TELL, 900)
	var offs: int = rogue.brain.hup_offs
	var tells: int = rogue.brain.tells
	var hp_before: float = life.combat.health_of(1)
	var burst := _spawn(main, p, main.to_local(rogue.global_position) + Vector3(0.0, 0.2, -1.5))
	var went := await _wait(func(): return burst.went() and rogue.brain.hup != DaemonBrain.Hup.NONE, 60)
	var called_off: bool = rogue.brain.hup_offs == offs + 1 and rogue.brain.state != DaemonBrain.State.TELL and rogue.brain.state != DaemonBrain.State.STRIKE and rogue.brain.prey == 0
	# The player stands in reach and in sight the whole confusion: no tell starts on it.
	await _frames(int(_t.confused_s() * 60.0) - 10)
	var unhurt: bool = life.combat.health_of(1) == hp_before and rogue.brain.tells == tells
	var hunts := await _wait(func(): return rogue.brain.hup == DaemonBrain.Hup.NONE, 60)
	var back := await _wait(func(): return rogue.brain.state == DaemonBrain.State.HUNT or rogue.brain.state == DaemonBrain.State.TELL, 600)
	_check("acceptance: against the daemons that fight: rogue.d caught mid-tell has it called off (%d called off) and drops its prey (no idea where the player is), and through its whole confusion starts no tell on the player standing in reach (%d tells, unhurt); then it is itself again and hunts once more" % [rogue.brain.hup_offs - offs, rogue.brain.tells - tells], telling >= 0 and went >= 0 and called_off and unhurt and hunts >= 0 and back >= 0, "%d %d %d %d" % [telling, went, hunts, back])
	await _drop(main)


## Confused daemons lash at each other: rogue.d's slash, a zombie's bolt; a lash kill the thrower's.
func _lash_checks() -> void:
	var main := await _lab({"DummyA": Vector3(1.0, 0.0, 6.0), "DummyB": Vector3(-1.0, 0.0, 6.0)}, Vector3(0.0, 0.95, -6.0), false)
	var p = main.get_node("Player")
	var life := _life(main)
	life.combat.states[1]["protect_left"] = 100000.0  # nothing on the player: what lands is the lashes
	var rogue := _dummy(main, "DummyA")
	var zombie := _dummy(main, "DummyB")
	for d in [rogue, zombie]:
		_toughen(d, TOUGH)
	var burst := _spawn(main, p, Vector3(0.0, 0.2, 5.0))
	await _wait(func(): return burst.went(), 60)
	var rogue_last := [rogue.health()]
	var zombie_last := [zombie.health()]
	var rogue_hits: Array = []
	var zombie_hits: Array = []
	for i in int(_t.confused_s() * 60.0) + 30:
		await physics_frame
		if rogue.health() < rogue_last[0]:
			rogue_hits.append(rogue_last[0] - rogue.health())
		if zombie.health() < zombie_last[0]:
			zombie_hits.append(zombie_last[0] - zombie.health())
		rogue_last[0] = rogue.health()
		zombie_last[0] = zombie.health()
	var ai: DaemonAiTuning = DaemonDirector.of(main).tuning
	var slash: float = ai.rogue_damage * _t.lash_scale
	var bolt: float = ai.zombie_bolt_damage * _t.lash_scale
	var right := true
	for hit in zombie_hits:
		right = right and absf(hit - slash) < EPS
	for hit in rogue_hits:
		right = right and absf(hit - bolt) < EPS
	_check("acceptance: a crowd turns on itself a little: rogue.d and the zombie confused 2 m apart lash at each other with their own attacks (rogue.d %d lashes, %d landed; the zombie %d, %d landed), rogue.d's slash taking %.2f off the zombie (%s) and the zombie's bolt %.2f off rogue.d (%s): %.0f%% of each attack's own; at most %d lashes a confusion each, none at the player" % [rogue.brain.lashes, rogue.brain.lash_hits, zombie.brain.lashes, zombie.brain.lash_hits, slash, str(zombie_hits), bolt, str(rogue_hits), _t.lash_scale * 100.0, _t.lash_most], rogue.brain.lash_hits >= 1 and zombie.brain.lash_hits >= 1 and not zombie_hits.is_empty() and not rogue_hits.is_empty() and right and rogue.brain.lashes <= _t.lash_most and zombie.brain.lashes <= _t.lash_most and rogue.brain.tells == 0 and zombie.brain.tells == 0)
	# A lash's kill is the thrower's: alone, this player's.
	await _wait(func(): return rogue.brain.hup == DaemonBrain.Hup.NONE and zombie.brain.hup == DaemonBrain.Hup.NONE, 300)
	await _wait(func(): return rogue.brain.hup_guard <= 0.0 and zombie.brain.hup_guard <= 0.0, int(_t.immune_s * 60.0) + 30)
	_place(rogue, main.to_global(Vector3(1.0, 0.0, 6.0)))
	_place(zombie, main.to_global(Vector3(-1.0, 0.0, 6.0)))
	_toughen(rogue, TOUGH)
	_toughen(zombie, 1.0)
	var downed := [false]
	zombie.downed.connect(func(_d: Node3D): downed[0] = true)
	var kill := _spawn(main, p, Vector3(0.0, 0.2, 5.0))
	await _wait(func(): return kill.went() and kill.wave_age > kill.wave_s(), 90)
	var kill_caught: int = kill.caught_count
	await _wait(func(): return downed[0], int(_t.confused_s() * 60.0) + 60)
	_check("a lash that kills is the thrower's kill: the zombie down to rogue.d's lash or its own bolt's return (%s), credited to this player (%s)" % [str(downed[0]), str(zombie.credited)], downed[0] and zombie.credited and zombie.killer == 0 and kill_caught == 2)
	await _drop(main)


# --- chmod 000's frozen daemon: it takes the hangup frozen and starts confused when it thaws. ---

func _frozen_checks() -> void:
	var main := await _lab({"DummyB": Vector3(3.0, 0.0, 6.0)}, OPEN, true)
	var p = main.get_node("Player")
	var zombie := _dummy(main, "DummyB")
	zombie.chill(10.0)
	var frozen: bool = zombie.chmod_frozen()
	var burst := _spawn(main, p, Vector3(0.0, 0.2, 6.0))
	await _wait(func(): return burst.went() and burst.wave_age > burst.wave_s(), 90)
	await _frames(30)
	var took: bool = burst.caught_count == 1 and zombie.brain.hup_pending and zombie.brain.hup == DaemonBrain.Hup.NONE and zombie.chmod_frozen()
	zombie.frost.thaw()
	zombie.art_node().frozen = false
	var started := await _wait(func(): return zombie.brain.hup == DaemonBrain.Hup.RELOAD, 10)
	_check("acceptance: a chmod-frozen daemon takes the hangup frozen (it stays frozen, nothing confused yet: %s) and starts confused when it thaws (%s, %d frames after)" % [str(took), zombie.brain.hup_name(), started], frozen and took and started >= 0 and not zombie.brain.hup_pending)
	await _drop(main)


## /dev/null drags a confused daemon harder than one that is itself.
func _hole_checks() -> void:
	var main := await _lab({"DummyB": Vector3(4.0, 0.0, 4.0), "DummyC": Vector3(-4.0, 0.0, 4.0)}, OPEN, true)
	var p = main.get_node("Player")
	var confused := _dummy(main, "DummyB")
	var itself := _dummy(main, "DummyC")
	for d in [confused, itself]:
		_toughen(d, TOUGH)
	confused.take_hup(_t, 0)
	var hole_def: WeaponDefScript = load("res://resources/dev_null.tres")
	var hole := DevNullHole.spawn(main, hole_def.hole_tuning(), main.to_global(Vector3(0.0, 0.2, 4.0)), Vector3.ZERO, 5, "solo", true, 0, false, "plum", [p.get_rid()], p.hole_judge(hole_def))
	await _wait(func(): return hole.is_open(), 60)
	await _frames(10)
	var core: Vector3 = hole.core
	var a: Vector3 = confused.global_position
	var b: Vector3 = itself.global_position
	await physics_frame
	var in_a := _inward(a, confused.global_position, core)
	var in_b := _inward(b, itself.global_position, core)
	_check("acceptance: /dev/null works well on the confused: a hole drags a confused daemon %.4f m in a frame against %.4f for one as far off that is itself (%.2fx; the rule's %.1fx: it does not brace)" % [in_a, in_b, in_a / maxf(in_b, 0.000001), _t.hole_pull_scale], in_b > 0.0 and absf(in_a / in_b - _t.hole_pull_scale) < 0.03)
	await _drop(main)


## ping outlines the confused in the carrier green.
func _ping_checks() -> void:
	var main := await _lab({"DummyA": Vector3(0.0, 0.0, 9.0), "DummyB": Vector3(-4.0, 0.0, 9.0)}, OPEN, true)
	var p = main.get_node("Player")
	var rogue := _dummy(main, "DummyA")
	var zombie := _dummy(main, "DummyB")
	rogue.take_hup(_t, 0)
	var ping_def: Resource = p.inventory.defs[PING]
	PingPulseScript.spawn(main, ping_def, p.global_position, p.global_position.y - 0.95, true, true)
	await _frames(40)
	var lit := PingReveal.find(rogue.art_node())
	var plain := PingReveal.find(zombie.art_node())
	var tag_c: String = lit.tag_text() if lit != null else ""
	var tag_p: String = plain.tag_text() if plain != null else ""
	var ghost_c: Material = lit.outlines()[0].material_override if lit != null else null
	var ghost_p: Material = plain.outlines()[0].material_override if plain != null else null
	_check("acceptance: ping shows the confused: rogue.d, confused, outlined in the carrier green (\"%s\"), the zombie beside it, itself, in ping's lime (\"%s\")" % [tag_c, tag_p], lit != null and plain != null and lit.confused() and not plain.confused() and ghost_c == PingReveal.hup_material() and ghost_p == PingReveal.material() and tag_c.ends_with("hung up") and not tag_p.ends_with("hung up"))
	await _drop(main)


# --- ICE: the hunter confused and forgetting; a node reloading; a wall untouched. ---

func _ice_checks() -> void:
	var main := await _lab({}, Vector3(7.0, 0.95, 3.0), false, true)
	var ice := _ice(main)
	var p = main.get_node("Player")
	var life := _life(main)
	ice.start_round(2)
	await _frames(2)
	life.combat.states[1]["protect_left"] = 1000.0
	var hunter: HunterIce = ice.hunter
	hunter.global_position = main.to_global(Vector3(2.0, 0.0, 0.5))
	ice.note_damage("sigkill_rail", 400.0)
	var learned: int = ice.adapt_percent()
	var weapon: String = ice.adapt_weapon
	var gate := ice.wall("gate")
	var gate_hp: float = gate.health()
	var gate_at: Vector3 = gate.global_position
	var burst := _spawn(main, p, Vector3(1.0, 0.2, -3.0))
	await _wait(func(): return burst.went() and burst.wave_age > burst.wave_s(), 90)
	var gate_reached: bool = burst.get("_passed").has(gate)
	var refused_any: int = burst.refused + burst.spared
	var forgot_count: int = burst.hunters_forgot
	var burst_at: Vector3 = burst.center
	var forgot: bool = ice.adapt_percent() == 0 and ice.adapt_weapon == "" and ice.ledger.is_empty() and ice.adapt_text() == "" and hunter.shield_color == Palette.HUNTER_COBALT and ice.forgets == 1
	var confused: String = hunter.brain.hup_name()
	var at: Vector3 = hunter.global_position
	await _wait(func(): return hunter.brain.hup == DaemonBrain.Hup.WANDER, 120)
	await _frames(int(_t.wander_s * 60.0) - 20)
	var wandered: float = hunter.global_position.distance_to(at)
	_check("acceptance: against ICE: the hunter is confused as a daemon is (%s, then wandering %.1f m) and forgets what it learned about your favourite weapon (%s at %d%% before, nothing now: its ledger wiped, its shields cobalt, the HUD's line gone); its look the same tag (\"%s\")" % [confused, wandered, weapon, learned, hunter.hup_look().tag_text() if hunter.hup_look() != null else ""], learned > 0 and weapon == "sigkill_rail" and forgot and confused == "reload" and wandered > 0.5 and forgot_count == 1 and hunter.hup_look() != null and hunter.hup_look().tag_text() == "?")
	_check("acceptance: ICE walls are not affected: the gate %.1f m off, inside its reach, untouched (%.0f of %.0f, %.4f m moved), never caught nor even asked (%d refused or spared)" % [gate.aim_point().distance_to(burst_at), gate.health(), gate_hp, gate.global_position.distance_to(gate_at), refused_any], gate.health() == gate_hp and gate.global_position.distance_to(gate_at) < 0.0001 and gate_reached and refused_any == 0 and gate.aim_point().distance_to(burst_at) < _t.radius_m and gate.hup_look() == null)
	await _drop(main)
	# A node: in its tell, a burst makes it reload: its field dropped (nothing reaches the player standing in
	# it) for node_reload_s, then it looks again.
	main = await _lab({}, Vector3(-4.5, 0.95, -1.8), false, true)
	ice = _ice(main)
	p = main.get_node("Player")
	life = _life(main)
	ice.start_round(1)
	await _frames(2)
	life.combat.states[1]["protect_left"] = 0.0
	var node := ice.node_of("jam")
	var telling := await _wait(func(): return node.state == IceNode.State.TELL, 600)
	var jams: int = ice.jams_on_me
	var reloads: int = node.reloads
	burst = _spawn(main, p, main.to_local(node.global_position) + Vector3(0.0, 0.2, 2.0))
	var reloading := await _wait(func(): return node.state == IceNode.State.RELOAD, 90)
	var nodes_reloaded: int = burst.nodes_reloaded
	var dome_off: bool = node.dome_shown() == 0.0
	var tag: String = node.hup_look().tag_text() if node.hup_look() != null else ""
	await _frames(int(_t.node_reload_s * 60.0) - 30)
	var dropped: bool = ice.jams_on_me == jams and node.state == IceNode.State.RELOAD
	var back := await _wait(func(): return node.state == IceNode.State.TELL or ice.jams_on_me > jams, 600)
	_check("acceptance: a node caught reloads its config: its tell called off, its field dropped (the dome down, \"%s\") for %.0f s while the player stands in it (%d jams), then it looks again and its field comes back (%d frames later)" % [tag.replace("\n", " / "), _t.node_reload_s, ice.jams_on_me - jams, back], telling >= 0 and reloading >= 0 and dome_off and tag.begins_with("SIGHUP: reloading config") and dropped and node.reloads == reloads + 1 and back >= 0 and nodes_reloaded == 1)
	await _drop(main)


# --- Black ICE: it runs under nohup. ---

func _black_checks() -> void:
	var main := await _lab({}, OPEN, false, true)
	var ice := _ice(main)
	var p = main.get_node("Player")
	var life := _life(main)
	ice.start_round(4)
	var b := ice.summon_black(3)
	b.phase_t = b.tuning.tell_s
	b.step(0.0, ice.daemons)
	life.combat.states[1]["protect_left"] = 1000.0
	p.global_position = b.global_position + Vector3(0.0, 0.95, 14.0)
	await _frames(2)
	var seals: int = b.seals_left
	var health: float = b.health()
	var hups: int = b.brain.hups
	var burst := _spawn(main, p, main.to_local(b.global_position) + Vector3(0.0, 0.2, 3.0))
	await _wait(func(): return burst.went() and burst.wave_age > burst.wave_s(), 90)
	await _frames(10)
	var tag: String = burst.get("_look").tag()
	_check("acceptance: Black ICE ignores it (it runs under nohup): never confused (%s), its seals and health untouched, never held or hurt; it flashes once and the burst's tag refuses it (\"%s\")" % [b.brain.hup_name(), tag.replace("\n", " / ")], burst.black_refused and tag.ends_with("\nSIGHUP: ignored (nohup)") and b.brain.hup == DaemonBrain.Hup.NONE and b.brain.hups == hups and b.seals_left == seals and b.health() == health and not b.broken)
	await _drop(main)


# --- A match: the host judges. ---

func _match_checks() -> void:
	GameSettings.current().set_value("gameplay", "practice", false)
	GameSettings.current().set_value("gameplay", "ice", false)
	var host := _branch("Host", Vector3.ZERO)
	var client := _branch("Client", CLIENT_OFFSET)
	await _frames(2)
	var joined := await _join(host, client)
	var hs: Session = host["session"]
	var cs: Session = client["session"]
	var hp = host["player"]
	var cp = client["player"]
	var cid: int = cs.my_id
	var src := FileAccess.get_file_as_string("res://scripts/net/net_session.gd")
	var rpcs := src.count("@rpc(")
	_check("acceptance: the wire: protocol 19 (17 since C31's /dev/null, 18 at C32, 19 since C33's loadouts), no new message (28 RPCs): a throw is the usual _throw, the burst, its count and a player it caught ride _blast, a daemon's confusion the state word, its root the seed's sign", joined and Session.PROTOCOL == 19 and rpcs == 28, "%d RPCs" % rpcs)
	for name in ["DummyA", "DummyB", "DummyC", "DummyD"]:
		_park(_dummy(host["main"], name))
		_park(_dummy(client["main"], name))
	# The joiner throws at the floor by the host: the host runs it, the joiner's copy goes off at its word.
	hp.global_position = host["main"].to_global(Vector3(0.0, 0.95, 6.0))
	cp.global_position = client["main"].to_global(OPEN)
	cp.select_slot(SLOT)
	var drawn := await _wait(func(): return hs.combat.drawn_by(cid) == "sighup", 120)
	await _frames(30)
	hs.combat.states[1]["protect_left"] = 0.0
	hs.combat.states[cid]["protect_left"] = 0.0
	_aim(cp, client["main"].to_global(Vector3(0.0, 0.0, 8.0)))
	var hp_health: float = hs.combat.health_of(1)
	await _fire(cp)
	var hosted := await _wait(func(): return not hs.get("_hups").is_empty(), 60)
	var host_burst = hs.get("_hups").values()[0] if not hs.get("_hups").is_empty() else null
	var copy_made := await _wait(func(): return not cs.get("_hups").is_empty(), 60)
	var copy = cs.get("_hups").values()[0] if not cs.get("_hups").is_empty() else null
	var went := await _wait(func(): return host_burst != null and host_burst.went() and copy != null and copy.went(), 120)
	var same: float = host["main"].to_local(host_burst.center).distance_to(client["main"].to_local(copy.center)) if went >= 0 else INF
	var mag: int = hs.combat.states[cid]["ammo"]["sighup"]["mag"]
	_check("acceptance: in a match the host runs the joiner's burst: its throw believed (a charge counted, %d left), the burst the host's to decide and the joiner's copy only drawn, gone off at the host's word at the host's place (%.3f m apart)" % [mag, same], joined and drawn >= 0 and hosted >= 0 and copy_made >= 0 and went >= 0 and host_burst.authoritative and not copy.authoritative and same < 0.01 and mag == 1)
	# The host's player caught: confused on its own screen, for a moment, with every control still its own.
	var caught := await _wait(func(): return hp.hup_left > 0.0, 60)
	await _frames(5)
	var line: String = host["hud"].sighup_hud().line_text()
	var glitch: float = host["hud"].sighup_hud().glitch()
	var drift: Vector2 = host["hud"].get("_crosshair").drift()
	var badge: bool = host["hud"].guide().link_hung_up()
	var walk_from: Vector3 = hp.global_position
	var yaw: float = hp.rotation.y
	var shots := [0]
	hp.shot_fired.connect(func(_hit: bool): shots[0] += 1)
	for i in 20:
		hp.drive_input(Vector2(0.0, -1.0), false, false, i % 2 == 0)
		await physics_frame
	hp.drive_input(Vector2.ZERO, false, false, false)
	var walked: float = Vector2(hp.global_position.x - walk_from.x, hp.global_position.z - walk_from.z).length()
	var still_aims: bool = absf(hp.rotation.y - yaw) < EPS
	var own: bool = cp.hup_left == 0.0
	_check("acceptance: a player caught is confused on its own screen alone, briefly (%.1f s): its HUD glitching (%.2f), \"%s\" over the crosshair, the crosshair as drawn drifting (%s px; the aim never moves), its AI link hung up (%s); and never a control taken: it still walks (%.2f m in a third of a second) and fires; no damage (%.0f to %.0f); the thrower never caught by its own" % [_t.player_s, glitch, line, str(drift), str(badge), walked, hp_health, hs.combat.health_of(1)], caught >= 0 and line == "SIGHUP: hung up  NO CARRIER" and glitch > 0.0 and drift.length() > 0.0 and badge and walked > 1.0 and still_aims and shots[0] >= 1 and own and hs.combat.health_of(1) == hp_health and hs.hups_judged == 1, "%d %d" % [caught, shots[0]])
	var cleared := await _wait(func(): return hp.hup_left <= 0.0, int(_t.player_s * 60.0) + 30)
	await _frames(3)
	_check("its confusion passes on its own (%d frames): the HUD clear, the crosshair back on the middle, the link back" % cleared, cleared >= 0 and host["hud"].sighup_hud().line_text() == "" and host["hud"].get("_crosshair").drift() == Vector2.ZERO and not host["hud"].guide().link_hung_up())
	await _wait(func(): return hs.get("_hups").is_empty(), 200)
	# Spawn protection: a protected host is never caught.
	hs.combat.states[1]["protect_left"] = 30.0
	await _frames(int(_def.fire_cooldown * 60.0) + 2)
	await _fire(cp)
	await _wait(func(): return not hs.get("_hups").is_empty() and hs.get("_hups").values()[0].went(), 120)
	await _frames(40)
	_check("acceptance: spawn protection holds: a protected host in its reach is never caught (%.2f s confused)" % hp.hup_left, hp.hup_left == 0.0 and hs.hups_judged == 1)
	await _wait(func(): return hs.get("_hups").is_empty(), 200)
	hs.combat.states[1]["protect_left"] = 0.0
	# The host throws at the joiner: the joiner is confused on its own screen alone, by the host's word.
	cp.global_position = client["main"].to_global(Vector3(0.0, 0.95, 6.0))
	hp.global_position = host["main"].to_global(OPEN)
	hs.combat.states[cid]["protect_left"] = 0.0
	await _frames(20)
	hp.select_slot(SLOT)
	await _wait(func(): return hs.combat.drawn_by(1) == "sighup" and hp.inventory.fire_block() == "", 120)
	_aim(hp, host["main"].to_global(Vector3(0.0, 0.0, 8.0)))
	var joiner_hp: float = hs.combat.health_of(cid)
	await _fire(hp)
	var told := await _wait(func(): return cp.hup_left > 0.0, 120)
	await _frames(3)
	_check("acceptance: the host's burst confuses the joiner on the joiner's own screen (\"%s\"), told to it alone; no damage (%.0f to %.0f); the host itself, its thrower, untouched" % [client["hud"].sighup_hud().line_text(), joiner_hp, hs.combat.health_of(cid)], told >= 0 and client["hud"].sighup_hud().line_text() == "SIGHUP: hung up  NO CARRIER" and hs.combat.health_of(cid) == joiner_hp and hp.hup_left == 0.0)
	await _wait(func(): return hs.get("_hups").is_empty(), 200)
	# Refused: none left.
	var life_now: int = cs.lives.get(cid, 0)
	hs.combat.states[cid]["ammo"]["sighup"]["mag"] = 0
	var empty_drops: int = hs.combat.drops.get("empty", 0)
	hs._handle_throw(cid, life_now, "sighup", host["main"].to_local(hs.call("_eye_of", cid)), Vector3.FORWARD)
	_check("the host refuses a throw with no charge left (\"empty\")", hs.combat.drops.get("empty", 0) == empty_drops + 1 and hs.get("_hups").is_empty())
	# A joiner's burst confuses the host's daemons while they fight, and the joiner's copies show it.
	var rogue := _dummy(host["main"], "DummyA")
	_place(rogue, host["main"].to_global(Vector3(3.0, 0.0, 6.0)))
	_toughen(rogue, TOUGH)
	hs.combat.states[cid]["ammo"]["sighup"]["mag"] = 2
	cp.inventory.mags[SLOT] = 2
	hs.combat.states[1]["protect_left"] = 1000.0
	cp.global_position = client["main"].to_global(OPEN)
	await _frames(int(_def.fire_cooldown * 60.0) + 2)
	_aim(cp, client["main"].to_global(Vector3(0.0, 0.0, 7.0)))
	await _fire(cp)
	var confused := await _wait(func(): return rogue.brain.hup != DaemonBrain.Hup.NONE, 120)
	var copy_rogue := _dummy(client["main"], "DummyA")
	var shown := await _wait(func(): return copy_rogue.brain.hup != DaemonBrain.Hup.NONE and copy_rogue.hup_look() != null and copy_rogue.hup_look().tag_text() != "", 60)
	_check("acceptance: while the daemons fight the host's daemons are the joiner's burst's too: rogue.d confused on the host (%s, by player %d), and the joiner's copy shows it from the host's word (%s, its tag \"%s\")" % [rogue.brain.hup_name(), rogue.brain.hup_by, copy_rogue.brain.hup_name(), copy_rogue.hup_look().tag_text().replace("\n", " / ") if copy_rogue.hup_look() != null else ""], confused >= 0 and shown >= 0 and rogue.brain.hup_by == cid)
	# The joiner leaves while its copy is confused on the host's word: its own daemons decide again, and the
	# borrowed confusion (no numbers of its own) ends quietly instead of running on.
	cs.leave()
	var ended := await _wait(func(): return copy_rogue.brain.hup == DaemonBrain.Hup.NONE, 120)
	await _frames(30)
	_check("a joiner that leaves while one of its copies is confused by the host's word: its daemons decide again and that confusion ends quietly (%d frames), nothing run on numbers it never had" % ended, ended >= 0 and copy_rogue.brain.hup == DaemonBrain.Hup.NONE)
	await _drop_side(client)
	await _drop_side(host)


# --- Helpers. ---

func _draw(p: Node) -> bool:
	p.select_slot(SLOT)
	await _frames(30)
	return p.weapon_tuning().id == "sighup" and p.inventory.fire_block() == ""


## One click of fire, and the frame it fires in.
func _fire(p: Node) -> void:
	await physics_frame
	p.drive_input(Vector2.ZERO, false, false, true)
	await physics_frame
	await physics_frame
	p.drive_input(Vector2.ZERO, false, false, false)


## A condition that holds once `node` is done or gone: it never reads a freed node (a weak reference).
func _done(node: Node) -> Callable:
	var ref: WeakRef = weakref(node)
	return func() -> bool:
		var n = ref.get_ref()
		return n == null or n.get("phase") == SighupBurst.Phase.DONE


## The arena's newest burst, or null.
func _burst(main: Node) -> SighupBurst:
	var field := main.get_node_or_null(SighupBurst.FIELD)
	if field == null:
		return null
	for i in range(field.get_child_count() - 1, -1, -1):
		if field.get_child(i) is SighupBurst:
			return field.get_child(i)
	return null


## A burst of the player's own, dropped from `at` (arena space) as if thrown there.
func _spawn(main: Node, p: Node, at: Vector3) -> SighupBurst:
	var burst := SighupBurst.spawn(main, _t, main.to_global(at), Vector3.ZERO, 5, "solo", true, 0, false, "carrier", [p.get_rid()])
	p.take_hup_burst(burst)
	return burst


## How far a thing moved from `from` to `to` toward the axis of the core at `core`, metres.
static func _inward(from: Vector3, to: Vector3, core: Vector3) -> float:
	return Vector2(from.x - core.x, from.z - core.z).length() - Vector2(to.x - core.x, to.z - core.z).length()


func _toughen(dummy: Node3D, health: float) -> void:
	dummy.max_health = health
	dummy.set("_health", health)


func _lab(keep: Dictionary, player_at: Vector3, practice: bool = false, ice: bool = false) -> Node:
	GameSettings.current().set_value("gameplay", "practice", practice)
	GameSettings.current().set_value("gameplay", "difficulty", "normal")
	GameSettings.current().set_value("gameplay", "ice", ice)
	var link := Link.new()
	link.settings_path = _tmp.path_join("arena-privacy.cfg")
	link.demo = true
	Link.park(link)
	var main = MainScene.instantiate()
	root.add_child(main)
	_arenas.append(main)
	main.get_node("Hud").guide().focus_check = func(): return false
	main.get_node("Hud").round_hud()._left_s = LONG_ROUND_S
	var player = main.get_node("Player")
	player.assume_captured = true
	player.global_position = main.to_global(player_at)
	player.velocity = Vector3.ZERO
	for dummy in main.get_node("Arena/Targets").get_children():
		if keep.has(String(dummy.name)):
			_place(dummy, main.to_global(keep[String(dummy.name)]))
		else:
			_park(dummy)
	await _frames(2)
	return main


func _drop(main: Node) -> void:
	if is_instance_valid(main):
		for sfx in main.find_children("*", "AudioStreamPlayer", true, false):
			(sfx as AudioStreamPlayer).stop()
		for sfx in main.find_children("*", "AudioStreamPlayer3D", true, false):
			(sfx as AudioStreamPlayer3D).stop()
		main.free()
	_arenas.erase(main)
	var left = Link.take_parked()
	if left != null:
		left.shut_down(null)
	Engine.time_scale = 1.0
	await process_frame


func _ice(main: Node) -> IceDirector:
	return main.get_node(IceDirector.NODE_NAME)


func _life(main: Node) -> Node:
	for child in main.get_children():
		if child is SoloLife:
			return child
	return null


## Turns the player to face `point` (world space), its view tipped up or down to it from its eyes.
func _aim(player: Node3D, point: Vector3) -> void:
	var way: Vector3 = point - player.global_position
	player.rotation.y = atan2(-way.x, -way.z)
	var eye: Vector3 = player.get_node("Head/Camera").global_position
	var to := point - eye
	player.get_node("Head").rotation.x = atan2(to.y, Vector2(to.x, to.z).length())


func _dummy(main: Node, name: String) -> Node3D:
	return main.get_node("Arena/Targets/" + name)


## A daemon put at `at` (world space), facing as the scene had it, at home there.
func _place(dummy: Node3D, at: Vector3) -> void:
	dummy.global_position = at
	dummy.global_rotation = Vector3.ZERO
	dummy.brain.take_home()
	dummy.brain.moved = false
	dummy.brain.state = DaemonBrain.State.HOME
	dummy.brain.prey = 0


func _park(dummy: Node3D) -> void:
	_place(dummy, PARKED + Vector3(dummy.get_index() * 3.0, 0.0, 0.0))


## A key pressed and let go; with `shift` the bank key held round it.
func _key(keycode: Key, shift: bool = false) -> void:
	if shift:
		_send_key(KEY_SHIFT, true, false)
		await process_frame
	_send_key(keycode, true, shift)
	await process_frame
	await process_frame
	_send_key(keycode, false, shift)
	if shift:
		await process_frame
		_send_key(KEY_SHIFT, false, false)
	await process_frame
	await process_frame


func _send_key(keycode: Key, down: bool, shift: bool) -> void:
	var event := InputEventKey.new()
	event.keycode = keycode
	event.physical_keycode = keycode
	event.pressed = down
	event.shift_pressed = shift or (keycode == KEY_SHIFT and down)
	Input.parse_input_event(event)


func _wheel(button: MouseButton) -> void:
	var down := InputEventMouseButton.new()
	down.button_index = button
	down.pressed = true
	Input.parse_input_event(down)
	await process_frame
	await process_frame
	var up := down.duplicate() as InputEventMouseButton
	up.pressed = false
	Input.parse_input_event(up)
	await process_frame
	await process_frame


func _frames(n: int) -> void:
	for i in maxi(n, 0):
		await physics_frame


## Frames until `condition` holds, or -1 after `most`.
func _wait(condition: Callable, most: int) -> int:
	for i in most:
		if condition.call():
			return i
		await physics_frame
	return most if condition.call() else -1


func _net_tuning() -> Resource:
	var t := NetTuningScript.new()
	t.bind_address = "127.0.0.1"
	t.connect_timeout_ms = 1500
	t.peer_timeout_ms = 2000
	return t


## A side of the game in its own branch: {branch, session, main, player, hud, combat_hud}.
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
	branch.add_child(session)
	_branches.append(branch)
	var main = MainScene.instantiate()
	branch.add_child(main)
	var out := {"branch": branch, "session": session, "main": main, "player": main.get_node("Player"), "hud": main.get_node("Hud"), "combat_hud": main.get_node("Hud").combat_hud()}
	out["player"].assume_captured = true
	main.get_node("Hud").guide().focus_check = func(): return false
	main.get_node("Hud").round_hud()._left_s = LONG_ROUND_S
	return out


func _drop_side(side: Dictionary) -> void:
	var branch: Node = side["branch"]
	if is_instance_valid(branch):
		for sfx in branch.find_children("*", "AudioStreamPlayer", true, false):
			(sfx as AudioStreamPlayer).stop()
		for sfx in branch.find_children("*", "AudioStreamPlayer3D", true, false):
			(sfx as AudioStreamPlayer3D).stop()
		side["session"].leave()
		branch.free()
	_branches.erase(branch)
	await process_frame


func _join(host: Dictionary, client: Dictionary) -> bool:
	host["session"].host(0)
	await _frames(2)
	client["session"].join("127.0.0.1:%d" % host["session"].listen_port())
	var t0 := Time.get_ticks_msec()
	while not (client["session"].state == Session.State.JOINED and host["session"].players.size() == 2 and client["session"].players.size() == 2 and client["session"].get("_weapons_synced") == true):
		if Time.get_ticks_msec() - t0 > WATCHDOG_MS:
			return false
		await physics_frame
	await _frames(10)
	return true


func _cleanup() -> void:
	Engine.time_scale = 1.0
	for node in _arenas.duplicate():
		await _drop(node)
	for branch in _branches.duplicate():
		if is_instance_valid(branch):
			branch.free()
	GameSettings.current().reset()
	Controls.apply_binds({})
	await process_frame
	OS.delay_msec(300)
	await process_frame


## OKLab of `c` (sRGB), as a point.
static func _oklab(c: Color) -> Vector3:
	var lin := func(x: float) -> float: return x / 12.92 if x <= 0.04045 else pow((x + 0.055) / 1.055, 2.4)
	var r: float = lin.call(c.r)
	var g: float = lin.call(c.g)
	var b: float = lin.call(c.b)
	var l := pow(0.4122214708 * r + 0.5363325363 * g + 0.0514459929 * b, 1.0 / 3.0)
	var m := pow(0.2119034982 * r + 0.6806995451 * g + 0.1073969566 * b, 1.0 / 3.0)
	var s := pow(0.0883024619 * r + 0.2817188376 * g + 0.6299787005 * b, 1.0 / 3.0)
	return Vector3(0.2104542553 * l + 0.7936177850 * m - 0.0040720468 * s, 1.9779984951 * l - 2.4285922050 * m + 0.4505937099 * s, 0.0259040371 * l + 0.7827717662 * m - 0.8086757660 * s)


func _code(path: String) -> String:
	return FileAccess.get_file_as_string(path)


## The text of function `name` in `source`, up to the next function.
func _body(source: String, name: String) -> String:
	var at := source.find("\nfunc %s(" % name)
	if at < 0:
		at = source.find("\nstatic func %s(" % name)
	if at < 0:
		return ""
	var end := source.find("\nfunc ", at + 1)
	var end_static := source.find("\nstatic func ", at + 1)
	if end < 0 or (end_static >= 0 and end_static < end):
		end = end_static
	return source.substr(at, end - at) if end >= 0 else source.substr(at)
