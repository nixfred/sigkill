extends SceneTree
## Headless test of /dev/null, the black-hole grenade, weapon 12, for SIGKILL (C31, PRD 5.2: "/dev/null:
## black-hole grenade"). scripts/check.sh runs it as step 45, and any FAIL exits 1.
##
##   godot --headless --path . --fixed-fps 60 --script res://tests/dev_null_test.gd
##
## The weapon: its resource's numbers and its checks (a thrown weapon with its DevNullTuning, two charges
## that come back; the tuning's refusals), its own plum measured in OKLab against every bright colour of the
## palette and kept well clear of ICE's, Black ICE's and the pipe's. The hole's rules on their own (the pull
## over distance and over time, the damage inside the horizon, the pulse, the charges). The keys: Shift+3
## draws it, 3 the rail, Q and the wheel reach it; the strip and the readout at 960x540. In the real arena
## with the real player: the throw (the device flies, lands, opens over the floor; in the air on its fuse;
## one open at a time; root's free and wider), then in practice a hole over the dummies (each dragged at the
## pull for its distance and swirled, stretched toward the core, hurt inside the horizon only, discarded at
## the core, the implosion's pulse, the callout, the readout, the look's parts, the dummies coming back);
## fighting daemons: a tell called off and the crowd drawn into a knot; a chmod-frozen daemon pulled whole
## and shattered at the core; the level: nothing pulled out of the core's sight, a wall of white ICE never
## moved (it only flickers); ICE: the hunter pulled and hurt, a node anchored but hurt; Black ICE never pulled
## or hurt ("/dev/null: device busy"); cron mines drawn in and set off at the core. Then a host and a joiner
## over ENet on 127.0.0.1 (the joiner's arena 1000 m off): the host runs and judges the joiner's hole (its
## charges counted, its opening told, the host dragged and hurt and discarded with the joiner credited),
## spawn protection holds, the host's hole drags the joiner on its own screen, the thrower is never dragged,
## a joiner's hole drags the host's daemons; protocol 17 (18 since C32), no new message. And the fiction rule for the hole's
## code, and nothing made while a hole holds. Deterministic: frames counted, only counts and outcomes printed.

const Session = preload("res://scripts/net/net_session.gd")
const NetTuningScript = preload("res://scripts/net/net_tuning.gd")
const Link = preload("res://scripts/guide/guide_link.gd")
const MainScene = preload("res://scenes/main.tscn")
const Controls = preload("res://scripts/controls.gd")
const Palette = preload("res://scripts/palette.gd")
const WeaponDefScript = preload("res://scripts/weapons/weapon_def.gd")
const CronMine = preload("res://scripts/weapons/cron_mine.gd")
const HOLE_PATH := "res://resources/dev_null.tres"
const HOLE_CODE := ["res://scripts/weapons/dev_null_hole.gd", "res://scripts/weapons/dev_null_look.gd", "res://scripts/weapons/dev_null_tuning.gd", "res://scripts/hud/dev_null_hud.gd", "res://scripts/viewmodels/dev_null.gd"]
const WATCHDOG_MS := 12000
const CLIENT_OFFSET := Vector3(1000.0, 0.0, 0.0)
## Open floor south of the low wall, clear of the crates and the platform.
const OPEN := Vector3(0.0, 0.95, 15.0)
const PARKED := Vector3(0.0, -50.0, 0.0)
## /dev/null's slot (slot 12: bank 2's third), the pipe's before it, the rail's (key 3), and cron's.
const SLOT := 11
const PIPE := 10
const RAIL := 2
const CRON := 7
const NEVER := ["OS.", "execute", "create_process", "kill(", "Thread", "HTTP", "PacketPeer", "StreamPeer", "TCPServer", "UDPServer", "DirAccess", "FileAccess", "set_unix_permissions", "shell_open", "move_to_trash", "Expression", "Time.", "ctrl_pressed", "alt_pressed", "rpc", ".open("]
## How far apart (OKLab) the plum keeps from every bright colour, and from ICE's, Black ICE's and the pipe's.
const APART := 0.155
const APART_ICE := 0.22
const APART_TEXT := 0.1
const TOUGH := 400.0
const LONG_ROUND_S := 100000.0
const EPS := 0.001

var _fails := 0
var _checks := 0
var _tmp := ""
var _arenas: Array = []
var _branches: Array = []
var _def: WeaponDefScript
var _t: DevNullTuning


func _initialize() -> void:
	_run()


func _run() -> void:
	await process_frame
	root.size = Vector2i(1280, 720)
	_tmp = OS.get_temp_dir().path_join("sigkill-dev-null-test-%d" % OS.get_process_id())
	if DirAccess.dir_exists_absolute(_tmp):
		print("FAIL the test's temporary folder already exists; not touching it")
		quit(1)
		return
	DirAccess.make_dir_recursive_absolute(_tmp)
	Controls.ensure()
	GameSettings.current().reset()
	_def = load(HOLE_PATH)
	_t = _def.hole_tuning()
	_source_checks()
	_weapon_checks()
	_palette_checks()
	_rule_checks()
	await _key_checks()
	await _strip_checks()
	await _throw_checks()
	await _practice_checks()
	await _pulse_checks()
	await _tell_checks()
	await _frozen_checks()
	await _level_checks()
	await _ice_checks()
	await _black_checks()
	await _mine_checks()
	await _match_checks()
	await _cleanup()
	for name in DirAccess.get_files_at(_tmp):
		DirAccess.remove_absolute(_tmp.path_join(name))
	DirAccess.remove_absolute(_tmp)
	print("DEV NULL: %d checks" % _checks)
	print("DEV NULL RESULT: ", "ALL PASS" if _fails == 0 else "%d FAILED" % _fails)
	quit(0 if _fails == 0 else 1)


func _check(label: String, ok: bool, detail: String = "") -> void:
	_checks += 1
	print("PASS " if ok else "FAIL ", label, ("   " + detail) if detail != "" else "")
	if not ok:
		_fails += 1


# --- The code, the weapon, its numbers and its colour. ---

func _source_checks() -> void:
	var code := ""
	for path in HOLE_CODE:
		code += _code(path)
	var found := PackedStringArray()
	for word in NEVER:
		if code.contains(word):
			found.append(word)
	_check("acceptance: fiction only, never the real /dev/null: the hole's code (the hole, its look, its tuning, the readout, the model) opens, writes or reads no file, makes no OS, process, folder, thread or network call, no RPC, reads no wall clock and handles no Ctrl or Alt key", found.is_empty() and code.length() > 12000 and code.contains("\"/dev/null: device busy\""), ", ".join(found))
	var hole := _code(HOLE_CODE[0])
	var look := _code(HOLE_CODE[1])
	var hud := _code(HOLE_CODE[3])
	var each := ""
	for fn in ["_physics_process", "_process", "_hold_everything", "_hold", "_drag", "_stretch", "_let_go", "_pull_mines", "player_drag", "reaches", "_fly"]:
		each += _body(hole, fn)
	for fn in ["show_state", "_place_floor"]:
		each += _body(look, fn)
	each += _body(hud, "_refresh") + _body(hud, "_show")
	var made := PackedStringArray()
	for word in [".new(", "instantiate(", "duplicate(", "Mesh(", "Material(", "add_child"]:
		if each.contains(word):
			made.append(word)
	_check("acceptance: nothing is made while a hole holds: what runs each frame (the throw, the pull, the drag, the stretch, the mines, the look's state, the readout) makes no node, mesh or material; the look is made once per throw, its debris a MultiMesh drawn by its shader", made.is_empty() and each.length() > 6000 and _body(look, "_build_hole").contains("MultiMesh.new()"), ", ".join(made))


func _weapon_checks() -> void:
	var t := _t
	_check("acceptance: its numbers, all in one resource (resources/dev_null.tres, its DevNullTuning inside): %d charges, one back every %.0f s, a throw every %.1f s at %.0f m/s plus %.0f up, a %.1f s fuse, %d open at once; the hole %.1f s open, %.1f s pulling, %.2f s collapsing, its core %.1f m over the floor, reaching %.0f m (%.2f m as root), its horizon %.0f m, its core %.1f m; dragging %.1f to %.1f m/s (the square of the depth), swirling %.0f%%, ramping from %.0f%% over %.1f s, a player at most %.1f m/s; %.0f to %.0f a second inside the horizon every %.2f s, %.0f to discard, the implosion %.0f to %.0f within %.0f m" % [_def.magazine_size, t.recharge_s, _def.fire_cooldown, t.throw_speed, t.throw_lift, t.fuse_s, t.live_cap, t.open_s, t.hold_s, t.collapse_s, t.core_height_m, t.radius_m, t.reach_for(true), t.horizon_m, t.core_m, t.pull_edge, t.pull_core, t.swirl_share * 100.0, t.ramp_floor * 100.0, t.ramp_s, t.player_pull_cap, t.dps_horizon, t.dps_core, t.tick_s, t.discard_damage, t.pulse_damage, t.pulse_edge_damage, t.pulse_radius_m], _def.problems().is_empty() and t.problems().is_empty() and _def.is_thrown() and _def.is_hole() and _def.fire_mode == WeaponDefScript.FireMode.PROJECTILE and _def.magazine_size == 2 and _def.reserve_ammo == 0 and _def.fire_cooldown == 1.0 and t.recharge_s == 16.0 and t.throw_speed == 13.0 and t.throw_lift == 3.0 and t.fuse_s == 1.6 and t.live_cap == 1 and t.open_s == 0.4 and t.hold_s == 4.0 and t.collapse_s == 0.35 and t.core_height_m == 1.0 and t.radius_m == 9.0 and t.horizon_m == 3.0 and t.core_m == 0.8 and t.root_radius_scale == 1.25 and t.pull_edge == 1.0 and t.pull_core == 7.5 and t.pull_curve == 2.0 and t.swirl_share == 0.55 and t.ramp_s == 1.0 and t.ramp_floor == 0.35 and t.player_pull_cap == 4.2 and t.dps_horizon == 8.0 and t.dps_core == 40.0 and t.tick_s == 0.25 and t.discard_damage == 500.0 and t.pulse_radius_m == 5.0 and t.pulse_damage == 45.0 and t.pulse_edge_damage == 10.0, str(_def.problems()) + str(t.problems()))
	_check("it is weapon 12 as built: \"/dev/null\" (short \"/dev/null\"), fiction \"%s\", the feed's \"> /dev/null\", the plum light skin, thrown from its two charges, its own model" % _def.fiction, _def.id == "dev_null" and _def.display_name == "/dev/null" and _def.short_name == "/dev/null" and _def.kill_word == "> /dev/null" and _def.fiction == "> /dev/null: discarded" and _def.light_skin == "plum" and _def.viewmodel_model != null and _def.viewmodel_model.resource_path == "res://scripts/viewmodels/dev_null.gd")
	var refusals := 0
	for change in [["horizon_m", 9.0], ["core_m", 3.0], ["pull_core", 0.5], ["player_pull_cap", 7.0], ["live_cap", 0], ["ramp_s", 5.0], ["pulse_radius_m", 12.0], ["recharge_s", 0.0]]:
		var bad: DevNullTuning = t.duplicate()
		bad.set(change[0], change[1])
		refusals += 0 if bad.problems().is_empty() else 1
	var none: WeaponDefScript = _def.duplicate()
	none.projectile = null
	refusals += 1 if ", ".join(none.problems()).contains("needs a ForkBombTuning, a DevNullTuning") else 0
	var cannon: WeaponDefScript = load("res://resources/terminal_cannon.tres").duplicate()
	cannon.projectile = t
	refusals += 1 if ", ".join(cannon.problems()).contains("only a thrown weapon") else 0
	var endless: WeaponDefScript = _def.duplicate()
	endless.magazine_size = -1
	endless.reserve_ammo = -1
	endless.reload_s = 0.0
	refusals += 0 if endless.problems().is_empty() else 1
	_check("the checks refuse what would break it: a horizon at its reach, a core at its horizon, a pull weaker inside than out, a pull a run cannot beat (7 m/s), no hole at all (live cap 0), a ramp past its hold, a pulse past its reach, no recharge, no tuning, its tuning on a weapon that is not thrown, and no charges (11 of 11)", refusals == 11, "%d of 11" % refusals)


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
		if key.begins_with("DEV_NULL"):
			continue
		if key.begins_with("SKIN_"):
			continue  # the earned light skins (C33) are alternates, guarded against the hostile lights (tests/unlocks_test.gd)
		var c: Color = consts[key]
		if maxf(c.r, maxf(c.g, c.b)) <= 0.5:
			continue  # the dark bases, armour and glass: nothing bright to confuse it with
		var dist := _oklab(Palette.DEV_NULL).distance_to(_oklab(c))
		if dist < least:
			least = dist
			near = key
		var text_dist := _oklab(Palette.DEV_NULL_TEXT).distance_to(_oklab(c))
		if text_dist < text_least:
			text_least = text_dist
			text_near = key
	var named := {}
	for key in ["GLACIER", "HUNTER_COBALT", "HUNTER_TEXT", "BLACK_ICE", "BLACK_ICE_TEXT", "PIPE", "PIPE_TEXT"]:
		named[key] = _oklab(Palette.DEV_NULL).distance_to(_oklab(consts[key]))
	var ice_least: float = named.values().min()
	var text_l := _oklab(Palette.DEV_NULL_TEXT).x
	_check("acceptance: the hole's own colour, a plum #%s (the accretion ring's: the hole itself is black), reads apart: at least %.3f (OKLab) from every bright colour of the palette (nearest %s, %.3f: chmod's frost opal, then the breakers' ultraviolet and the runaway's hot magenta at %.3f and %.3f), %.2f from ICE's glacier (%.3f), the hunter's cobalt (%.3f), Black ICE's slate (%.3f) and the pipe's brass (%.3f), so its core never reads as Black ICE; its HUD text #%s legible on black (lightness %.2f; %.3f from the nearest, %s)" % [Palette.DEV_NULL.to_html(false), APART, near, least, _oklab(Palette.DEV_NULL).distance_to(_oklab(Palette.BREAKER)), _oklab(Palette.DEV_NULL).distance_to(_oklab(Palette.HOT_MAGENTA)), APART_ICE, named["GLACIER"], named["HUNTER_COBALT"], named["BLACK_ICE"], named["PIPE"], Palette.DEV_NULL_TEXT.to_html(false), text_l, text_least, text_near], least >= APART and ice_least >= APART_ICE and text_least >= APART_TEXT and text_l >= 0.75 and Palette.DEV_NULL.to_html(false) == "ab389b" and Palette.SKINS.get("plum").slice(0, 2) == [Palette.DEV_NULL, Palette.DEV_NULL_TEXT] and Palette.skin_hot("plum") == Palette.DEV_NULL_HI)


# --- The hole's rules on their own. ---

func _rule_checks() -> void:
	var t := _t
	var edge := t.pull_at(t.radius_m - 0.001, t.radius_m, 10.0)
	var mid := t.pull_at(t.radius_m * 0.5, t.radius_m, 10.0)
	var deep := t.pull_at(1.0, t.radius_m, 10.0)
	var axis := t.pull_at(0.0, t.radius_m, 10.0)
	var outside := t.pull_at(t.radius_m + 0.01, t.radius_m, 10.0)
	_check("acceptance: the pull grows inward: %.2f m/s at its reach, %.2f halfway, %.2f a metre from the core's axis, %.2f on it; nothing past its reach (%.2f)" % [edge, mid, deep, axis, outside], absf(edge - 1.0) < 0.01 and absf(mid - (1.0 + 6.5 * 0.25)) < EPS and absf(axis - 7.5) < EPS and edge < mid and mid < deep and deep < axis and outside == 0.0)
	var opened := t.pull_at(4.5, t.radius_m, 0.0)
	var later := t.pull_at(4.5, t.radius_m, 0.5)
	var full := t.pull_at(4.5, t.radius_m, 1.0)
	_check("and over time: just opened it pulls %.0f%% as hard (%.2f), %.2f half a second on, its full %.2f after %.1f s" % [t.ramp_floor * 100.0, opened, later, full, t.ramp_s], absf(opened - mid * t.ramp_floor) < EPS and opened < later and later < full and absf(full - mid) < EPS)
	_check("acceptance: damage over time inside the horizon only: nothing at %.1f m (%.1f), %.1f a second just inside it, %.1f on the axis; the implosion %.0f at the core easing to %.0f at %.0f m, nothing past it" % [t.horizon_m, t.dps_at(t.horizon_m), t.dps_at(t.horizon_m - 0.001), t.dps_at(0.0), t.pulse_at(0.0), t.pulse_at(t.pulse_radius_m), t.pulse_radius_m], t.dps_at(t.horizon_m) == 0.0 and absf(t.dps_at(t.horizon_m - 0.001) - 8.0) < 0.02 and t.dps_at(0.0) == 40.0 and t.dps_at(1.5) > t.dps_at(2.5) and t.pulse_at(0.0) == 45.0 and t.pulse_at(t.pulse_radius_m) == 10.0 and t.pulse_at(t.pulse_radius_m + 0.01) == 0.0)
	var charges := [1, 0.0]
	for i in 959:
		charges = t.step_charges(charges[0], 2, charges[1], 1.0 / 60.0)
	var before_back: int = charges[0]
	charges = t.step_charges(charges[0], 2, charges[1], 2.0 / 60.0)
	var host := [1, 0.0]
	for i in 12 * 60 + 1:
		host = t.step_charges(host[0], 2, host[1], 1.0 / 60.0, 0.25)
	var full_stays: Array = t.step_charges(2, 2, 0.0, 30.0)
	_check("acceptance: its charges come back: a spent one is back %.0f s later (still %d a frame before, %d after), the host's count a quarter quicker (back in 12 s: %d), and a full magazine waits for nothing" % [t.recharge_s, before_back, charges[0], host[0]], before_back == 1 and charges[0] == 2 and host[0] == 2 and full_stays == [2, 0.0] and absf(t.reach_for(true) - 11.25) < EPS and absf(t.life_s() - 4.75) < EPS)


# --- The keys. ---

func _key_checks() -> void:
	var main := await _lab({}, OPEN, true)
	var p = main.get_node("Player")
	var wh = main.get_node("Hud").weapon_hud()
	await _frames(20)
	await _key(KEY_3, true)
	var shift_three: int = p.inventory.current
	var strip_three: String = wh.bank2_text()
	var lit: int = wh.active_bank()
	await _key(KEY_3)
	var three: int = p.inventory.current
	await _key(KEY_Q)
	var q_back: int = p.inventory.current
	await _key(KEY_2, true)
	await _wheel(MOUSE_BUTTON_WHEEL_DOWN)
	var wheel_on: int = p.inventory.current
	await _wheel(MOUSE_BUTTON_WHEEL_DOWN)
	var wheel_wrap: int = p.inventory.current
	await _wheel(MOUSE_BUTTON_WHEEL_UP)
	var wheel_back: int = p.inventory.current
	_check("acceptance: Shift+3 draws weapon 12, /dev/null (\"%s\" on the strip, bank 2 lit), 3 draws the rail, Q swaps back to /dev/null, and the wheel reaches it from the pipe, goes on (to the cannon, the wrap, until C32; to SIGHUP, weapon 13, since: its charges on the strip, 4(2)) and comes back" % strip_three, shift_three == SLOT and strip_three == "Shift+ 1 2 [3 /dev/null] 4(2)" and lit == 1 and three == RAIL and q_back == SLOT and wheel_on == SLOT and wheel_wrap == SLOT + 1 and wheel_back == SLOT and p.weapon_tuning().id == "dev_null", "%d %d %d %d %d %d" % [shift_three, three, q_back, wheel_on, wheel_wrap, wheel_back])
	await _drop(main)


# --- The strip and the readout at 960x540. ---

func _strip_checks() -> void:
	var before := root.size
	var wrong := PackedStringArray()
	var lines := PackedStringArray()
	var readout := ""
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
			feed_hud.entries.push_front({"killer": "Daemon-2", "victim": "Daemon-1", "word": "> /dev/null", "left": 2.0})
		hud.guide()._notice("word ".repeat(60), Color.WHITE, 5000)
		hud.net_hud().toggle()
		p.inventory.mags[SLOT] = 1  # one spent: its recharge on the strip
		# An open hole of this player's (its readout over the crosshair), and a root's longest chain under it.
		var hole := DevNullHole.spawn(host["main"], _t, p.global_position + Vector3(0.0, 1.0, -12.0), Vector3.ZERO, 3, "p1", true, 1, false, "plum")
		p.take_hole(hole)
		var fake: Array = []
		for i in 6:
			fake.append({"name": "player-%d-with-a-long-nam" % i, "frozen": false})
		p.last_chain = fake
		p.chain_end = ""
		p.chain_age = 0.0
		await _wait(func(): return hole.is_open(), 90)
		await _frames(3)
		p.chain_age = 0.0
		await _frames(1)
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
		var dh = hud.dev_null_hud()
		var ph = hud.pipe_hud()
		p.hole_drag = Vector3(3.0, 0.0, 0.0)  # as if another player's hole dragged it: the warning
		dh._refresh()
		var line: Label = dh.get("_line")
		var rect: Rect2 = line.get_global_rect()
		if not line.visible or not screen.encloses(rect) or strip.get_global_rect().intersects(rect) or feed.get_global_rect().intersects(rect):
			wrong.append("%d: readout %s %s" % [size.x, line.text, rect])
		var pipe_line: Label = ph.get("_line")
		if pipe_line.visible and pipe_line.get_global_rect().intersects(rect):
			wrong.append("%d: the warning over the pipe's readout" % size.x)
		readout = dh.line_text() + " / tag: " + hole.get("_look").tag().replace("\n", " / ")
		lines = PackedStringArray([hud.weapon_hud().bank2_text(), hud.weapon_hud().slots_text(), hud.weapon_hud().ammo_text(), hud.weapon_hud().state_text()])
		await _drop_side(host)
	root.size = before
	_check("acceptance: at 960x540 (and 1280x720) the strip keeps its two rows in its own column, /dev/null in bank 2's (\"%s\" over \"%s\"), with its charges (\"%s\", \"%s\"): every line inside the screen, clear of a full kill feed, the net panel and a long guide notice; and a dragged player's warning over the crosshair, inside the screen, clear of the strip, the feed and a chain's readout under the crosshair; an open hole's own tag over its core (\"%s\")" % [lines[0], lines[1], lines[2], lines[3], readout], wrong.is_empty() and lines[0] == "Shift+ 1 2 [3 /dev/null] 4(2)" and lines[1] == "1 2 3 4(2) 5 6 7 8 9" and lines[2] == "/dev/null  1 left" and lines[3].begins_with("recharge [") and readout.begins_with("> /dev/null: pulling you in  RUN / tag: $ cat * > /dev/null / "), ", ".join(wrong))


# --- The throw. ---

func _throw_checks() -> void:
	var main := await _lab({}, OPEN, true)
	var p = main.get_node("Player")
	var drawn := await _draw(p)
	var target: Vector3 = main.to_global(Vector3(0.0, 0.0, 9.0))
	_aim(p, target)
	await _fire(p)
	var hole := _hole(main)
	var left: int = p.inventory.mags[SLOT]
	var flew := 0
	var high := -INF
	var start := hole.global_position if hole != null else Vector3.INF
	while hole != null and is_instance_valid(hole) and hole.phase == DevNullHole.Phase.FLYING and flew < 200:
		var look = hole.get("_look")
		high = maxf(high, look.device().global_position.y)
		flew += 1
		await physics_frame
	var opened := hole != null and is_instance_valid(hole) and hole.is_open()
	var core: Vector3 = main.to_local(hole.core) if opened else Vector3.INF
	var landed_off: float = Vector2(core.x, core.z).distance_to(Vector2(0.0, 9.0)) if opened else INF
	_check("acceptance: the throw: aimed at the floor 6 m off, the device leaves from just ahead of the eyes (%.2f m), arcs (up to %.2f m) for %d frames and opens where it lands, %.2f m from the aim, its core %.2f m over the floor; a charge spent (%d left)" % [p.eye_position().distance_to(start), main.to_local(Vector3(0.0, high, 0.0)).y, flew, landed_off, core.y, left], drawn and opened and flew > 5 and flew < 60 and landed_off < 1.0 and absf(core.y - _t.core_height_m) < 0.05 and left == 1 and p.eye_position().distance_to(start) < 0.7)
	# One open at a time: a second throw while it holds is refused, nothing spent.
	await _frames(int(_def.fire_cooldown * 60.0) + 2)
	await _fire(p)
	var holes := main.find_children("DevNull", "", true, false).size()
	_check("one hole open at a time (live cap %d): a second throw while it holds is refused, its charge kept (%d hole, %d left)" % [_t.live_cap, holes, p.inventory.mags[SLOT]], holes == 1 and p.inventory.mags[SLOT] == 1)
	await _wait(func(): return not is_instance_valid(hole) or hole.phase == DevNullHole.Phase.DONE, int(_t.life_s() * 60.0) + 30)
	# At the open sky: the fuse opens it in the air.
	p.get_node("Head").rotation.x = 0.9
	await _frames(int(_def.fire_cooldown * 60.0) + 2)
	await _fire(p)
	var sky := _hole(main)
	var open_at := await _wait(func(): return sky != null and is_instance_valid(sky) and sky.is_open(), 150)
	var air: float = main.to_local(sky.core).y if open_at >= 0 else -INF
	_check("acceptance: thrown at the sky it opens in the air when its %.1f s fuse runs out (%.2f s, its core %.1f m up)" % [_t.fuse_s, (open_at + 2) / 60.0, air], open_at >= 0 and absf((open_at + 2) / 60.0 - _t.fuse_s) < 0.1 and air > 3.0, str(open_at))
	await _wait(func(): return not is_instance_valid(sky) or sky.phase == DevNullHole.Phase.DONE, int(_t.life_s() * 60.0) + 30)
	# Both charges spent; one comes back after its recharge.
	var empty: int = p.inventory.mags[SLOT]
	var back := await _wait(func(): return p.inventory.mags[SLOT] == 1, int(_t.recharge_s * 60.0) + 30)
	_check("both charges spent (%d left), one comes back on its own %.1f s after the last went (%d frames)" % [empty, _t.recharge_s, back], empty == 0 and back >= 0)
	# Root: thrown for free, its hole wider.
	p.sudo.state.charges = 1
	p.sudo.press()
	await _frames(3)
	var root_now: bool = p.sudo.is_root()
	_aim(p, target)
	var had: int = p.inventory.mags[SLOT]
	await _fire(p)
	var rooted := _hole(main)
	_check("root throws for free (%d left, as before) and its hole reaches %.2f m (%.2fx)" % [p.inventory.mags[SLOT], rooted.reach if rooted != null else -1.0, _t.root_radius_scale], root_now and rooted != null and p.inventory.mags[SLOT] == had and absf(rooted.reach - _t.reach_for(true)) < EPS)
	await _drop(main)


# --- In practice: a hole over the dummies. ---

func _practice_checks() -> void:
	var spots := {"DummyA": Vector3(0.0, 0.0, 7.2), "DummyB": Vector3(5.8, 0.0, 3.0), "DummyC": Vector3(-7.4, 0.0, 3.0), "DummyD": Vector3(2.0, 1.0, 1.0)}
	var main := await _lab(spots, OPEN, true)
	var p = main.get_node("Player")
	var round_hud = main.get_node("Hud").round_hud()
	var fx := main.get_tree().get_first_node_in_group(ParticleFx.GROUP) as ParticleFx
	var bursts: int = fx.fired(ParticleFx.Kind.HOLE) if fx != null else -1
	for name in spots:
		_toughen(_dummy(main, name), TOUGH)
	var downs := {}
	for name in spots:
		_dummy(main, name).downed.connect(func(_d: Node3D): downs[name] = true)
	var hole := _spawn(main, p, Vector3(0.0, 0.2, 4.0))
	var discards := [0]
	hole.discarded.connect(func(_what: Node, _at: Vector3): discards[0] += 1)
	var seen := {"tag": "", "count": -1}
	hole.collapsed.connect(func(_core: Vector3):
		var made := main.find_children("DevNullImplosion", "", true, false)
		seen["count"] = made.size()
		for node in made:
			for child in node.get_children():
				if child is Label3D:
					seen["tag"] = child.text)
	await _wait(func(): return hole.is_open(), 60)
	var core: Vector3 = hole.core
	# The pull over distance: one frame's drag on the nearest and the farthest, toward the axis and round it.
	await _frames(12)
	var near := _dummy(main, "DummyA")
	var far := _dummy(main, "DummyC")
	var near_at: Vector3 = near.global_position
	var far_at: Vector3 = far.global_position
	await physics_frame
	var near_in := _inward(near_at, near.global_position, core)
	var far_in := _inward(far_at, far.global_position, core)
	var near_d := Vector2(near_at.x - core.x, near_at.z - core.z).length()
	var far_d := Vector2(far_at.x - core.x, far_at.z - core.z).length()
	var near_want := _t.pull_at(near_d, _t.radius_m, hole.open_age) / 60.0
	var far_want := _t.pull_at(far_d, _t.radius_m, hole.open_age) / 60.0
	var swirled := _round(near_at, near.global_position, core)
	_check("acceptance: pull strength over distance: in one frame the daemon %.1f m from the core's axis is dragged %.4f m in (the tuning's %.4f) and the one %.1f m off %.4f (%.4f): the nearer the harder; each swirled round it too (%.4f m)" % [near_d, near_in, near_want, far_d, far_in, far_want, swirled], near_in > far_in and absf(near_in - near_want) < near_want * 0.05 + 0.0005 and absf(far_in - far_want) < far_want * 0.05 + 0.0005 and swirled > 0.001)
	var stretch_near: float = near.art_node().stretched
	var stretch_far: float = far.art_node().stretched
	var parts: Dictionary = hole.get("_look").parts()
	var shown: bool = parts["lens"].is_visible_in_tree() and parts["disc"].is_visible_in_tree() and parts["debris"].is_visible_in_tree() and parts["floor"].visible and not hole.get("_look").device().visible
	_check("acceptance: the look: the event horizon and its lensing, the accretion ring, %d streaks of debris spiralling in, its mark on the floor (%.2f m under the core) and a negative light at the core (%.1f) all up while it holds, the device gone; daemons drawn out toward the core, the nearer the more (%.2f against %.2f)" % [parts["debris"].multimesh.instance_count, core.y - parts["floor"].global_position.y, parts["dark"].light_energy, stretch_near, stretch_far], shown and parts["dark"].light_negative and parts["dark"].light_energy > 0.0 and stretch_near > stretch_far and stretch_far > 0.0 and absf(core.y - parts["floor"].global_position.y - _t.core_height_m) < 0.08)
	var held_line: String = hole.get("_look").tag()
	# Damage over time: frame by frame until rogue.d goes, nothing taken outside the horizon, its rate inside.
	var hurt_outside := false
	var first_hurt := INF
	var worst_tick := 0.0
	var last_hp: float = near.health()
	var gone := -1
	for i in 300:
		await physics_frame
		if not near.is_alive():
			gone = i
			break
		var d := Vector2(near.global_position.x - core.x, near.global_position.z - core.z).length()
		var hp: float = near.health()
		if hp < last_hp:
			if d > _t.horizon_m + 0.2:
				hurt_outside = true
			first_hurt = minf(first_hurt, d)
			worst_tick = maxf(worst_tick, last_hp - hp)
		last_hp = hp
	var outside_hp: float = far.health()
	# Its full strength now: a player 0.4 m from its axis is still never dragged faster than the cap.
	var near_axis: Vector3 = hole.core + Vector3(0.4, -0.5, 0.0)
	var inward_way := Vector3(hole.core.x - near_axis.x, 0.0, hole.core.z - near_axis.z).normalized()
	var player_pull: float = hole.player_drag(near_axis, main.get_world_3d().direct_space_state).dot(inward_way)
	var daemon_pull: float = _t.pull_at(0.4, _t.radius_m, hole.open_age)
	_check("acceptance: damage over time inside the horizon only: rogue.d dragged in took nothing outside it and its first hurt %.2f m from the axis, at most %.2f a tick (%.0f to %.0f a second, every %.2f s); the far daemon still whole outside it (%.0f); at full strength a player 0.4 m from its axis is dragged in %.2f m/s, never past %.1f (a run is 7), where a daemon goes %.2f" % [first_hurt, worst_tick, _t.dps_horizon, _t.dps_core, _t.tick_s, outside_hp, player_pull, _t.player_pull_cap, daemon_pull], player_pull > 0.0 and player_pull <= _t.player_pull_cap + EPS and daemon_pull > _t.player_pull_cap and not hurt_outside and first_hurt < _t.horizon_m + 0.2 and worst_tick > 0.0 and worst_tick <= _t.dps_core * _t.tick_s + EPS and held_line == "$ cat * > /dev/null\n4 held  0 discarded", held_line)
	# The core discards: each daemon that reaches it dies, its 400 health or not.
	var said: String = round_hud.last_callout
	var line: String = hole.get("_look").tag()
	var burst: int = (fx.fired(ParticleFx.Kind.HOLE) - bursts) if fx != null else -1
	_check("acceptance: the core discards: rogue.d (%.0f health, %.0f left) gone the moment it reaches the core, the callout \"%s\", its tag \"%s\", a burst of debris drawn in (%d)" % [TOUGH, last_hp, said, line.replace("\n", " / "), burst], gone >= 0 and last_hp > 0.0 and said == "> /dev/null" and line.ends_with(" 1 discarded") and burst >= 1 and discards[0] >= 1)
	var all := await _wait(func(): return downs.size() == spots.size(), 300)
	_check("practice: it pulls the dummies, all four in its reach drawn in and discarded (%d discards)" % discards[0], all >= 0 and discards[0] >= 4, str(downs.keys()) + " " + str(all))
	var ended := await _wait(func(): return not is_instance_valid(hole) or hole.phase == DevNullHole.Phase.DONE, int(_t.life_s() * 60.0) + 30)
	await _frames(int(DevNullHole.LookScript.IMPLODE_S * 60.0) + 70)
	_check("acceptance: it ends in its implosion: a flash, a shock ring and \"%s\" over the core, gone after %.1f s, the hole and its tag gone with it" % [seen["tag"], DevNullHole.LookScript.IMPLODE_S], ended >= 0 and seen["count"] == 1 and seen["tag"] == "> /dev/null" and main.find_children("DevNullImplosion", "", true, false).is_empty() and main.find_children("DevNull", "", true, false).is_empty())
	var back := await _wait(func(): return spots.keys().all(func(n): return _dummy(main, n).is_alive()), 600)
	_check("practice's dummies come back after the hole, as they do after any kill", back >= 0)
	await _drop(main)


## The implosion's pulse: what it still holds within its radius takes the pulse for its distance.
func _pulse_checks() -> void:
	var main := await _lab({"DummyB": Vector3(4.2, 0.0, 4.0)}, OPEN, true)
	var p = main.get_node("Player")
	var zombie := _dummy(main, "DummyB")
	_toughen(zombie, TOUGH)
	var hole := _spawn(main, p, Vector3(0.0, 0.2, 4.0))
	var at_end := [INF, 0]
	hole.collapsed.connect(func(core: Vector3):
		at_end[0] = (zombie.global_position + Vector3.UP * DaemonBrain.MIDDLE_M).distance_to(core)
		at_end[1] = hole.pulses)
	await _wait(func(): return hole.is_open(), 60)
	await _frames(20)
	hole.open_age = _t.life_s() - 0.001  # straight to its end, the zombie held outside the horizon
	var hp: float = zombie.health()
	await _frames(2)
	var took: float = hp - zombie.health()
	var want: float = _t.pulse_at(at_end[0])
	_check("acceptance: the end pulse: at its implosion the zombie it held %.2f m from the core (outside the horizon, so nothing before) takes the pulse's %.2f for that distance (%.2f); the hole is done" % [at_end[0], want, took], absf(took - want) < 0.05 and want > _t.pulse_edge_damage and at_end[1] == 1 and (not is_instance_valid(hole) or hole.phase == DevNullHole.Phase.DONE))
	await _drop(main)


# --- Fighting daemons: a tell called off, a crowd drawn into a knot. ---

func _tell_checks() -> void:
	var main := await _lab({"DummyA": Vector3(0.0, 0.0, 9.5)}, Vector3(0.0, 0.95, 14.0), false)
	var p = main.get_node("Player")
	var life := _life(main)
	life.combat.states[1]["protect_left"] = 0.0
	var rogue := _dummy(main, "DummyA")
	_toughen(rogue, TOUGH)
	var telling := await _wait(func(): return rogue.brain.state == DaemonBrain.State.TELL, 900)
	var offs: int = rogue.brain.pulled_offs
	var hp_before: float = life.combat.health_of(1)
	var hole := _spawn(main, p, main.to_local(rogue.global_position) + Vector3(0.0, 0.05, -2.0))
	var opened := await _wait(func(): return hole.is_open(), 60)
	await _frames(2)
	life.combat.states[1]["protect_left"] = 1000.0
	var called_off: bool = rogue.brain.pulled_offs == offs + 1 and rogue.brain.state != DaemonBrain.State.TELL and rogue.brain.state != DaemonBrain.State.STRIKE
	var state_now: String = DaemonBrain.STATE_NAMES[rogue.brain.state]
	await _frames(60)
	var unhurt: bool = life.combat.health_of(1) == hp_before
	# The crowd: the zombie and the runaway either side of the hole, drawn together.
	var core: Vector3 = hole.core
	_place(_dummy(main, "DummyB"), Vector3(core.x + 4.6, main.to_global(Vector3.ZERO).y, core.z + 1.0))
	_place(_dummy(main, "DummyC"), Vector3(core.x - 4.6, main.to_global(Vector3.ZERO).y, core.z + 1.0))
	for name in ["DummyB", "DummyC"]:
		_toughen(_dummy(main, name), TOUGH)
	await _frames(2)
	var apart := _dummy(main, "DummyB").global_position.distance_to(_dummy(main, "DummyC").global_position)
	await _frames(70)
	var knot := _dummy(main, "DummyB").global_position.distance_to(_dummy(main, "DummyC").global_position)
	_check("acceptance: against the daemons that fight: rogue.d caught mid-tell has it called off (%d called off, %s now, nothing thrown at the player), and the crowd drawn in: the zombie and the swarm %.1f m apart pulled to %.1f m, a knot for a chain or a bomb" % [rogue.brain.pulled_offs - offs, state_now, apart, knot], telling >= 0 and opened >= 0 and called_off and unhurt and knot < apart - 3.0, "%d %d" % [telling, opened])
	await _drop(main)


# --- chmod 000's frozen daemon: pulled like any other, shattered at the core. ---

func _frozen_checks() -> void:
	var main := await _lab({"DummyB": Vector3(4.0, 0.0, 6.0)}, OPEN, true)
	var p = main.get_node("Player")
	var zombie := _dummy(main, "DummyB")
	_toughen(zombie, TOUGH)
	zombie.chill(10.0)
	var frozen: bool = zombie.chmod_frozen()
	var at: Vector3 = zombie.global_position
	var hole := _spawn(main, p, Vector3(0.0, 0.2, 4.5))
	await _wait(func(): return hole.is_open(), 60)
	await _frames(30)
	var moved: float = zombie.global_position.distance_to(at)
	var whole: bool = zombie.health() == TOUGH and zombie.chmod_frozen()
	var gone := await _wait(func(): return not zombie.is_alive(), 240)
	_check("acceptance: a chmod-frozen daemon is pulled like any other (%.2f m in half a second, still frozen, taking nothing on the way: %s) and shatters at the core (%d shatter)" % [moved, whole, zombie.shatters], frozen and moved > 0.5 and whole and gone >= 0 and zombie.shatters == 1)
	await _drop(main)


# --- The level: nothing pulled out of the core's sight; a wall of white ICE never moved. ---

func _level_checks() -> void:
	var main := await _lab({"DummyA": Vector3(1.8, 0.0, 4.6), "DummyB": Vector3(-1.0, 0.0, -0.8)}, Vector3(3.2, 0.95, 9.6), true)
	var p = main.get_node("Player")
	var behind := _dummy(main, "DummyB")
	var open_one := _dummy(main, "DummyA")
	for name in ["DummyA", "DummyB"]:
		_toughen(_dummy(main, name), TOUGH)
	var at: Vector3 = behind.global_position
	var hole := _spawn(main, p, Vector3(1.8, 0.2, 6.2))
	await _wait(func(): return hole.is_open(), 60)
	var reach_d := Vector2(at.x - hole.core.x, at.z - hole.core.z).length()
	await _frames(90)
	_check("acceptance: walls block it: the zombie %.1f m off behind the low wall (in reach, out of the core's sight) is never held or moved (%.3f m), while rogue.d in the open is (%s)" % [reach_d, behind.global_position.distance_to(at), "discarded" if not open_one.is_alive() else "held"], reach_d < _t.radius_m and behind.global_position.distance_to(at) < 0.001 and not hole.held.has(behind) and (not open_one.is_alive() or hole.held.has(open_one)) and behind.health() == TOUGH)
	await _drop(main)
	# A wall of white ICE inside the horizon: never moved, never hurt, it only flickers.
	main = await _lab({}, Vector3(0.0, 0.95, 4.0), false, true)
	p = main.get_node("Player")
	var ice := _ice(main)
	var life := _life(main)
	ice.start_round(1)
	await _frames(2)
	life.combat.states[1]["protect_left"] = 1000.0
	var gate := ice.wall("gate")
	var gate_at: Vector3 = gate.global_position
	hole = _spawn(main, p, Vector3(0.0, 0.2, -5.6))
	await _wait(func(): return hole.is_open(), 60)
	await _frames(120)
	_check("acceptance: a wall of white ICE is never moved: the gate %.1f m from the core stays put (%.3f m), whole (%.0f of %.0f), and only flickers (%d)" % [Vector2(gate.aim_point().x - hole.core.x, gate.aim_point().z - hole.core.z).length(), gate.global_position.distance_to(gate_at), gate.health(), gate.max_health, hole.walls_flickered], gate.global_position.distance_to(gate_at) < 0.0001 and gate.health() == gate.max_health and hole.walls_flickered >= 1 and not hole.held.has(gate))
	await _drop(main)


# --- ICE: the hunter pulled and hurt; a node anchored but hurt. ---

func _ice_checks() -> void:
	var main := await _lab({}, Vector3(7.0, 0.95, 3.0), false, true)
	var ice := _ice(main)
	var p = main.get_node("Player")
	var life := _life(main)
	ice.start_round(2)
	await _frames(2)
	life.combat.states[1]["protect_left"] = 1000.0
	var node := ice.node_of("jam")
	var node_at: Vector3 = node.global_position
	var hunter: HunterIce = ice.hunter
	hunter.global_position = main.to_global(Vector3(2.0, 0.0, 0.5))
	await _frames(2)
	var hunter_at: Vector3 = hunter.global_position
	var hunter_hp: float = hunter.health()
	var node_hp: float = node.health()
	var hole := _spawn(main, p, Vector3(-3.0, 0.2, -3.0))
	await _wait(func(): return hole.is_open(), 60)
	await _frames(45)
	var pulled: float = Vector2(hunter_at.x - hole.core.x, hunter_at.z - hole.core.z).length() - Vector2(hunter.global_position.x - hole.core.x, hunter.global_position.z - hole.core.z).length()
	var held: bool = hunter.held_by_hole()
	await _wait(func(): return not is_instance_valid(hole) or hole.phase == DevNullHole.Phase.DONE, int(_t.life_s() * 60.0) + 30)
	_check("acceptance: against ICE: the hunter is pulled like a daemon (%.2f m nearer in 3/4 s, held) and hurt (%.0f of its %.0f; its discard at the core held to ICE's hit cap), the jam node %.1f m off anchored (%.4f m) but hurt (%.1f of %.0f)" % [pulled, hunter_hp - hunter.health(), hunter_hp, Vector2(node_at.x - hole.core.x if hole != null and is_instance_valid(hole) else 0.0, 0.0).length(), node.global_position.distance_to(node_at), node_hp - node.health(), node_hp], pulled > 0.5 and held and hunter.health() < hunter_hp and hunter_hp - hunter.health() <= 100.0 + _t.dps_core * _t.life_s() + _t.pulse_damage and node.global_position.distance_to(node_at) < 0.0001 and node.health() < node_hp)
	await _drop(main)


# --- Black ICE: never pulled, never hurt. ---

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
	var at: Vector3 = b.global_position
	var seals: int = b.seals_left
	var health: float = b.health()
	var hole := _spawn(main, p, main.to_local(b.global_position) + Vector3(0.0, 0.2, 4.5))
	await _wait(func(): return hole.is_open(), 60)
	await _frames(40)
	var small: String = hole.get("_look").tag()
	await _wait(func(): return not is_instance_valid(hole) or hole.phase == DevNullHole.Phase.DONE, int(_t.life_s() * 60.0) + 30)
	_check("acceptance: Black ICE in its reach is never pulled or held (%.4f m; the drift of its own hunt aside), never hurt, its seals untouched; it flashes once and the hole's tag refuses it (\"%s\")" % [Vector2(b.global_position.x - at.x, 0.0).length(), small.replace("\n", " / ")], hole.black_refused and small.ends_with("\n/dev/null: device busy") and not b.held_by_hole() and not hole.held.has(b) and b.seals_left == seals and b.health() == health and not b.broken)
	await _drop(main)


# --- cron mines: drawn in and set off at the core. ---

func _mine_checks() -> void:
	var main := await _lab({}, Vector3(0.0, 0.95, 12.0), true)
	var p = main.get_node("Player")
	p.select_slot(CRON)
	await _frames(30)
	_aim(p, main.to_global(Vector3(0.0, 0.0, 9.5)))
	await _fire(p)
	var mine: Node3D = null
	for job in main.find_children("*", "", true, false):
		if job.get_script() == CronMine:
			mine = job
	var at: Vector3 = mine.global_position if mine != null else Vector3.INF
	var runs: Array = []
	var hole := _spawn(main, p, Vector3(0.0, 0.2, 5.0))
	await _wait(func(): return hole.is_open(), 60)
	if mine != null:
		mine.ran.connect(func(left: int, where: Vector3): runs.append([left, where]))
	var set_off := await _wait(func(): return hole.mines_set_off == 1, 240)
	var where: Vector3 = runs[-1][1] if not runs.is_empty() else Vector3.INF
	_check("acceptance: cron mines in its reach are torn loose, drawn to the core (from %.1f m) and set off there: one last run of the mine's own (%d runs while held, the last %.2f m from the core with none left), its job then over" % [at.distance_to(hole.core) if mine != null else -1.0, runs.size(), where.distance_to(hole.core)], mine != null and set_off >= 0 and not runs.is_empty() and runs[-1][0] == 0 and where.distance_to(hole.core) <= _t.core_m + 0.05 and not mine.running())
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
	_check("acceptance: the wire: protocol 19 (16 since C30's pipe |, 17 at C31, 18 since C32's SIGHUP, 19 since C33's loadouts), no new message (28 RPCs): a throw is the usual _throw, the hole's opening, collapse and discards ride _blast, its root the seed's sign", joined and Session.PROTOCOL == 19 and rpcs == 28, "%d RPCs" % rpcs)
	for name in ["DummyA", "DummyB", "DummyC", "DummyD"]:
		_park(_dummy(host["main"], name))
		_park(_dummy(client["main"], name))
	# The joiner throws at the floor under the host: the host runs it, the joiner's copy opens at its word.
	hp.global_position = host["main"].to_global(Vector3(0.0, 0.95, 5.0))
	cp.global_position = client["main"].to_global(OPEN)
	cp.select_slot(SLOT)
	var drawn := await _wait(func(): return hs.combat.drawn_by(cid) == "dev_null", 120)
	await _frames(30)
	hs.combat.states[1]["protect_left"] = 0.0
	hs.combat.states[cid]["protect_left"] = 0.0
	_aim(cp, client["main"].to_global(Vector3(0.0, 0.0, 9.0)))
	var hp_health: float = hs.combat.health_of(1)
	await _fire(cp)
	var hosted := await _wait(func(): return not hs.get("_holes").is_empty(), 60)
	var host_hole = hs.get("_holes").values()[0] if not hs.get("_holes").is_empty() else null
	var copy_made := await _wait(func(): return not cs.get("_holes").is_empty(), 60)
	var copy = cs.get("_holes").values()[0] if not cs.get("_holes").is_empty() else null
	var opened := await _wait(func(): return host_hole != null and host_hole.is_open() and copy != null and copy.is_open(), 120)
	var same: float = host["main"].to_local(host_hole.core).distance_to(client["main"].to_local(copy.core)) if opened >= 0 else INF
	var mag: int = hs.combat.states[cid]["ammo"]["dev_null"]["mag"]
	_check("acceptance: in a match the host runs the joiner's hole: its throw believed (a charge counted, %d left), the hole the host's to decide and the joiner's copy only drawn, opened at the host's word at the host's place (%.3f m apart)" % [mag, same], joined and drawn >= 0 and hosted >= 0 and copy_made >= 0 and opened >= 0 and host_hole.authoritative and not copy.authoritative and same < 0.01 and mag == 1)
	# The host is dragged on its own screen and judged by its own combat; the thrower never dragged.
	var host_at: Vector3 = hp.global_position
	await _frames(30)
	var dragged: bool = not hp.hole_drag.is_zero_approx()
	var warned: String = host["hud"].dev_null_hud().line_text()
	var washed: float = host["hud"].dev_null_hud().wash()
	var drawn_in: float = Vector2(host_at.x - host_hole.core.x, host_at.z - host_hole.core.z).length() - Vector2(hp.global_position.x - host_hole.core.x, hp.global_position.z - host_hole.core.z).length()
	var own_drag: bool = cp.hole_drag.is_zero_approx()
	var discarded := await _wait(func(): return not hs.combat.alive(1), 300)
	var word: String = hs.last_kill_word.get(1, "")
	var killer: int = hs.last_killer.get(1, 0)
	_check("acceptance: the host judges every pull and every hurt: the host's player dragged in on its own screen (%.2f m, at most %.1f m/s), hurt inside the horizon and discarded at the core, the kill the joiner's (%d) by \"%s\"; its screen says so (\"%s\", its edges washed %.2f); the thrower never dragged by its own hole" % [drawn_in, _t.player_pull_cap, killer, word, warned, washed], dragged and warned == "> /dev/null: pulling you in  RUN" and washed > 0.0 and drawn_in > 0.5 and discarded >= 0 and killer == cid and word == "> /dev/null" and own_drag and hp_health == 100.0)
	await _wait(func(): return host_hole == null or not is_instance_valid(host_hole) or host_hole.phase == DevNullHole.Phase.DONE, int(_t.life_s() * 60.0) + 60)
	await _wait(func(): return hs.combat.alive(1), 600)
	# Spawn protection: a protected host is neither dragged nor hurt.
	await _frames(int(_def.fire_cooldown * 60.0) + 2)
	hp.global_position = host["main"].to_global(Vector3(0.0, 0.95, 6.0))
	hs.combat.states[1]["protect_left"] = 30.0
	var before: float = hs.combat.health_of(1)
	_aim(cp, client["main"].to_global(Vector3(0.0, 0.0, 8.0)))
	await _fire(cp)
	await _wait(func(): return not hs.get("_holes").is_empty() and hs.get("_holes").values()[0].is_open(), 120)
	var protected_at: Vector3 = hp.global_position
	await _frames(90)
	_check("acceptance: spawn protection holds: a protected host in its reach is neither dragged (%.3f m) nor hurt (%.0f to %.0f)" % [hp.global_position.distance_to(protected_at), before, hs.combat.health_of(1)], hp.global_position.distance_to(protected_at) < 0.01 and hs.combat.health_of(1) == before and hp.hole_drag.is_zero_approx())
	await _wait(func(): return hs.get("_holes").is_empty(), int(_t.life_s() * 60.0) + 60)
	hs.combat.states[1]["protect_left"] = 0.0
	# The host throws at the joiner: the joiner is dragged on its own screen, the host judges its hurt.
	cp.global_position = client["main"].to_global(Vector3(0.0, 0.95, 6.0))
	hp.global_position = host["main"].to_global(OPEN)
	hs.combat.states[cid]["protect_left"] = 0.0
	await _frames(20)
	hp.select_slot(SLOT)
	await _wait(func(): return hs.combat.drawn_by(1) == "dev_null" and hp.inventory.fire_block() == "", 120)
	_aim(hp, host["main"].to_global(Vector3(0.0, 0.0, 8.5)))
	var joiner_hp: float = hs.combat.health_of(cid)
	var joiner_at: Vector3 = cp.global_position
	await _fire(hp)
	var pulled := await _wait(func(): return not cp.hole_drag.is_zero_approx(), 120)
	await _frames(60)
	var joiner_in: float = joiner_at.distance_to(cp.global_position)
	_check("acceptance: the host's hole drags the joiner on the joiner's own screen (%.2f m in a second) and the host judges its hurt (%.0f to %.0f)" % [joiner_in, joiner_hp, hs.combat.health_of(cid)], pulled >= 0 and joiner_in > 0.5 and hs.combat.health_of(cid) < joiner_hp)
	await _wait(func(): return hs.get("_holes").is_empty(), int(_t.life_s() * 60.0) + 60)
	# Refusals: none left, or one already open.
	var life_now: int = cs.lives.get(cid, 0)
	hs.combat.states[cid]["ammo"]["dev_null"]["mag"] = 0
	var empty_drops: int = hs.combat.drops.get("empty", 0)
	hs._handle_throw(cid, life_now, "dev_null", host["main"].to_local(hs.call("_eye_of", cid)), Vector3.FORWARD)
	var refused_empty: bool = hs.combat.drops.get("empty", 0) == empty_drops + 1 and hs.get("_holes").is_empty()
	_check("the host refuses a throw with no charge left (\"empty\")", refused_empty)
	# A joiner's hole drags the host's daemons while they fight.
	var rogue := _dummy(host["main"], "DummyA")
	_place(rogue, host["main"].to_global(Vector3(4.0, 0.0, 4.0)))
	_toughen(rogue, TOUGH)
	var rogue_at: Vector3 = rogue.global_position
	hs.combat.states[cid]["ammo"]["dev_null"]["mag"] = 2
	cp.inventory.mags[SLOT] = 2
	cp.global_position = client["main"].to_global(OPEN)
	await _frames(int(_def.fire_cooldown * 60.0) + 2)
	_aim(cp, client["main"].to_global(Vector3(0.0, 0.0, 6.0)))
	await _fire(cp)
	await _wait(func(): return not hs.get("_holes").is_empty() and hs.get("_holes").values()[0].is_open(), 120)
	await _frames(40)
	var copy_rogue := _dummy(client["main"], "DummyA")
	await _frames(20)
	_check("acceptance: while the daemons fight the host's daemons are the joiner's hole's too: rogue.d dragged %.2f m on the host, and the joiner's copy of it follows (%.2f m from the host's)" % [rogue.global_position.distance_to(rogue_at), host["main"].to_local(rogue.global_position).distance_to(client["main"].to_local(copy_rogue.global_position))], rogue.global_position.distance_to(rogue_at) > 0.5 or not rogue.is_alive())
	await _drop_side(client)
	await _drop_side(host)


# --- Helpers. ---

func _draw(p: Node) -> bool:
	p.select_slot(SLOT)
	await _frames(30)
	return p.weapon_tuning().id == "dev_null" and p.inventory.fire_block() == ""


## One click of fire, and the frame it fires in.
func _fire(p: Node) -> void:
	await physics_frame
	p.drive_input(Vector2.ZERO, false, false, true)
	await physics_frame
	await physics_frame


## The arena's newest hole, or null.
func _hole(main: Node) -> DevNullHole:
	var field := main.get_node_or_null(DevNullHole.FIELD)
	if field == null:
		return null
	for i in range(field.get_child_count() - 1, -1, -1):
		if field.get_child(i) is DevNullHole:
			return field.get_child(i)
	return null


## A hole of the player's own, dropped from `at` (arena space) as if thrown there, judged as the player's.
func _spawn(main: Node, p: Node, at: Vector3) -> DevNullHole:
	var hole := DevNullHole.spawn(main, _t, main.to_global(at), Vector3.ZERO, 5, "solo", true, 0, false, "plum", [p.get_rid()], p.hole_judge(_def))
	p.take_hole(hole)
	return hole


## How far a thing moved from `from` to `to` toward the axis of the core at `core`, metres.
static func _inward(from: Vector3, to: Vector3, core: Vector3) -> float:
	return Vector2(from.x - core.x, from.z - core.z).length() - Vector2(to.x - core.x, to.z - core.z).length()


## How far it moved round that axis, metres.
static func _round(from: Vector3, to: Vector3, core: Vector3) -> float:
	var a := Vector2(from.x - core.x, from.z - core.z)
	var b := Vector2(to.x - core.x, to.z - core.z)
	return absf(wrapf(b.angle() - a.angle(), -PI, PI)) * a.length()


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
	for i in n:
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
