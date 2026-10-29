extends SceneTree
## Headless test of pipe |, the chain beam, weapon 11, for SIGKILL (C30, PRD 5.2: "pipe |: chain beam that
## arcs between enemies"). scripts/check.sh runs it as step 44, and any FAIL exits 1.
##
##   godot --headless --path . --fixed-fps 60 --script res://tests/pipe_chain_test.gd
##
## The weapon: its resource's numbers and its checks (a chain beam with its PipeTuning, no magazine, the
## buffer; the tuning's refusals), its own brass measured in OKLab against every bright colour of the
## palette, kept clear of chmod's frost opal and of ICE's, Black ICE's and the breakers' colours. The chain's
## rules on their own (scripts/weapons/pipe_chain.gd): the first hit and each link nearest first, the jump
## range, five links (six as root), the damage falling down the chain, walls breaking it, a frozen link
## conducting, a wall or Black ICE never jumped to. The keys: Shift+2 draws it, 2 draws SIGTERM, Q and the
## wheel reach it; the strip and the readout at 960x540. In the real arena with the real player clicking
## fire: in practice a chain arcs across four dummies in order (each link's damage, the readout written out,
## the arcs drawn link to link with their packets, the particles at each link), plain dummies all derezz and
## come back; a target 12 m away and more is out of reach; a wall between two daemons breaks the chain
## ("a wall broke the chain"); a chmod-frozen daemon conducts and shatters; ICE: the hunter and a node are
## links (an exploit's seam bonus on each), a wall hit first ends it; Black ICE is only flashed ("pipe: broken
## pipe"), never hurt, never a link, its seals untouched; the buffer fills, blocks and drains, and root
## writes nothing. Then a host and a joiner over ENet on 127.0.0.1 (the joiner's arena 1000 m off): the host
## judges the joiner's chain on its daemons and on the host's own player, spawn protection holds, the host's
## own chain lands on the joiner, every screen draws the other's chain, a blocked buffer is refused;
## protocol 16, no new message. And the fiction rule for the pipe's code, and nothing made while a chain is
## drawn. Deterministic: frames counted, only counts and outcomes printed.

const Session = preload("res://scripts/net/net_session.gd")
const NetTuningScript = preload("res://scripts/net/net_tuning.gd")
const Link = preload("res://scripts/guide/guide_link.gd")
const MainScene = preload("res://scenes/main.tscn")
const Controls = preload("res://scripts/controls.gd")
const Palette = preload("res://scripts/palette.gd")
const WeaponDefScript = preload("res://scripts/weapons/weapon_def.gd")
const Arsenal = preload("res://scripts/weapons/arsenal_tuning.gd")
const CronMine = preload("res://scripts/weapons/cron_mine.gd")
const PIPE_PATH := "res://resources/pipe_chain.tres"
const ARSENAL_PATH := "res://resources/arsenal.tres"
const PIPE_CODE := ["res://scripts/weapons/pipe_chain.gd", "res://scripts/weapons/pipe_buffer.gd", "res://scripts/weapons/pipe_tuning.gd", "res://scripts/weapons/pipe_arc.gd", "res://scripts/hud/pipe_hud.gd", "res://scripts/viewmodels/pipe_chain.gd"]
const WATCHDOG_MS := 12000
const CLIENT_OFFSET := Vector3(1000.0, 0.0, 0.0)
## Open floor south of the low wall, clear of the crates and the platform.
const OPEN := Vector3(0.0, 0.95, 15.0)
## Where a daemon a check does not use waits: under the floor, out of every sight line.
const PARKED := Vector3(0.0, -50.0, 0.0)
## pipe |'s slot (slot 11: bank 2's second), chmod 000's before it, and cron's.
const SLOT := 10
const CHMOD := 9
const CRON := 7
## The four daemons of the practice chain (arena space): rogue.d aimed at, then the zombie, the runaway and
## the second zombie, each the nearest of the rest to the one before, every jump in reach and in sight.
const CHAIN := {"DummyA": Vector3(0.0, 0.0, 9.0), "DummyB": Vector3(4.0, 0.0, 7.5), "DummyD": Vector3(6.0, 1.0, 3.0), "DummyC": Vector3(2.0, 0.0, 0.0)}
const NAMES := ["rogue.d", "zombie", "runaway", "<defunct>"]
const NEVER := ["OS.", "execute", "create_process", "kill(", "Thread", "HTTP", "PacketPeer", "StreamPeer", "TCPServer", "UDPServer", "DirAccess", "FileAccess", "set_unix_permissions", "shell_open", "move_to_trash", "Expression", "Time.", "ctrl_pressed", "alt_pressed", "rpc"]
## How far apart (OKLab) the brass keeps from every bright colour, from chmod's frost and its texts, and from
## ICE's, Black ICE's and the breakers' colours and texts.
const APART := 0.15
const APART_FROST := 0.16
const APART_ICE := 0.2
const TOUGH := 400.0
const LONG_ROUND_S := 100000.0
const EPS := 0.001

var _fails := 0
var _checks := 0
var _tmp := ""
var _arenas: Array = []
var _branches: Array = []
var _scratch: Array = []
var _def: WeaponDefScript
var _pt: PipeTuning


func _initialize() -> void:
	_run()


func _run() -> void:
	await process_frame
	root.size = Vector2i(1280, 720)
	_tmp = OS.get_temp_dir().path_join("sigkill-pipe-test-%d" % OS.get_process_id())
	if DirAccess.dir_exists_absolute(_tmp):
		print("FAIL the test's temporary folder already exists; not touching it")
		quit(1)
		return
	DirAccess.make_dir_recursive_absolute(_tmp)
	Controls.ensure()
	GameSettings.current().reset()
	_def = load(PIPE_PATH)
	_pt = _def.pipe
	_source_checks()
	_weapon_checks()
	_palette_checks()
	_rule_checks()
	await _key_checks()
	await _strip_checks()
	await _practice_checks()
	await _reach_checks()
	await _wall_checks()
	await _frozen_checks()
	await _ice_checks()
	await _black_checks()
	await _buffer_checks()
	await _match_checks()
	await _cleanup()
	for name in DirAccess.get_files_at(_tmp):
		DirAccess.remove_absolute(_tmp.path_join(name))
	DirAccess.remove_absolute(_tmp)
	print("PIPE: %d checks" % _checks)
	print("PIPE RESULT: ", "ALL PASS" if _fails == 0 else "%d FAILED" % _fails)
	quit(0 if _fails == 0 else 1)


func _check(label: String, ok: bool, detail: String = "") -> void:
	_checks += 1
	print("PASS " if ok else "FAIL ", label, ("   " + detail) if detail != "" else "")
	if not ok:
		_fails += 1


# --- The code, the weapon, its numbers and its colour. ---

func _source_checks() -> void:
	var code := ""
	for path in PIPE_CODE:
		code += _code(path)
	var found := PackedStringArray()
	for word in NEVER:
		if code.contains(word):
			found.append(word)
	_check("acceptance: fiction only, never a real pipe: the pipe's code (the chain, the buffer, its tuning, the arcs, the readout, the model) makes no OS, process, file or permission call, no folder, thread or network call, no RPC, reads no wall clock and handles no Ctrl or Alt key", found.is_empty() and code.length() > 8000, ", ".join(found))
	var arc := _code(PIPE_CODE[3])
	var hud := _code(PIPE_CODE[4])
	var each := ""
	for fn in ["_process", "_draw", "_ribbon", "_quad", "_vertex", "fire", "_spill"]:
		each += _body(arc, fn)
	each += _body(hud, "_refresh") + _body(hud, "_lines")
	var made := PackedStringArray()
	for word in [".new(", "instantiate(", "duplicate(", "Mesh(", "Material(", "add_child"]:
		if each.contains(word):
			made.append(word)
	_check("acceptance: nothing is made while a chain is drawn: what runs each frame and each chain (the arcs rebuilt in place, the packets, the blooms, the spill, the readout) makes no node, mesh or material; the arc is made once per shooter", made.is_empty() and each.length() > 3000 and arc.contains("ImmediateMesh.new()") and _body(arc, "_ready").contains("ImmediateMesh.new()"), ", ".join(made))


func _weapon_checks() -> void:
	var t := _pt
	_check("acceptance: its numbers, all in one resource (resources/pipe_chain.tres, its PipeTuning inside): a chain a click every %.2f s, aimed to %.0f m, %.0f on the first link, each link %.0f%% of the one before, jumping %.0f m, %d links (%d as root), a frozen link passing on %.0f%% and reaching %.1fx as far; the buffer %.0fK, %.0fK a chain, draining %.0fK/s after %.1f s, unblocking at %.0f%%" % [_def.fire_cooldown, _def.fire_range, _def.damage, t.link_keep * 100.0, t.jump_m, t.max_links, t.root_max_links, t.frozen_keep * 100.0, t.frozen_jump_scale, t.buffer_kib, t.write_kib, t.drain_kib_s, t.drain_rest_s, t.unblock_share * 100.0], _def.problems().is_empty() and t.problems().is_empty() and _def.is_chain() and _def.fire_mode == WeaponDefScript.FireMode.BEAM and _def.pipe_tuning() == t and _def.fire_cooldown == 0.45 and _def.fire_range == 30.0 and _def.damage == 26.0 and t.jump_m == 12.0 and t.max_links == 5 and t.root_max_links == 6 and t.link_keep == 0.7 and t.frozen_keep == 1.0 and t.frozen_jump_scale == 1.5 and t.buffer_kib == 64.0 and t.write_kib == 8.0 and t.drain_rest_s == 0.5 and t.drain_kib_s == 24.0 and t.unblock_share == 0.5, str(_def.problems()))
	_check("it is weapon 11 as built: \"pipe |\", short \"pipe\", fiction \"%s\", the feed's SIGPIPE, the brass light skin, no magazine (its buffer instead), its own model" % _def.fiction, _def.id == "pipe_chain" and _def.display_name == "pipe |" and _def.short_name == "pipe" and _def.kill_word == "SIGPIPE" and _def.light_skin == "brass" and not _def.has_magazine() and _def.viewmodel_model != null and _def.viewmodel_model.resource_path == "res://scripts/viewmodels/pipe_chain.gd")
	var refusals := 0
	var keep: PipeTuning = t.duplicate()
	keep.frozen_keep = 0.5
	refusals += 0 if keep.problems().is_empty() else 1
	var one: PipeTuning = t.duplicate()
	one.max_links = 1
	refusals += 0 if one.problems().is_empty() else 1
	var under: PipeTuning = t.duplicate()
	under.root_max_links = 4
	refusals += 0 if under.problems().is_empty() else 1
	var wide: PipeTuning = t.duplicate()
	wide.write_kib = 80.0
	refusals += 0 if wide.problems().is_empty() else 1
	var far: PipeTuning = t.duplicate()
	far.jump_m = 40.0
	refusals += 0 if far.problems().is_empty() else 1
	var mag: WeaponDefScript = _def.duplicate()
	mag.magazine_size = 10
	mag.reserve_ammo = 50
	mag.reload_s = 1.0
	refusals += 0 if mag.problems().is_empty() else 1
	var none: WeaponDefScript = _def.duplicate()
	none.pipe = null
	refusals += 0 if none.problems().is_empty() else 1
	var harmless: WeaponDefScript = _def.duplicate()
	harmless.damage = 0.0
	refusals += 0 if harmless.problems().is_empty() else 1
	var cannon: WeaponDefScript = load("res://resources/terminal_cannon.tres").duplicate()
	cannon.pipe = t
	refusals += 0 if cannon.problems().is_empty() else 1
	_check("the checks refuse what would break it: a frozen link losing more than a plain one, a one-link chain, root with fewer links, a write bigger than the buffer, a 40 m jump, a magazine, no pipe tuning, no damage, and a pipe tuning on any other weapon (9 of 9)", refusals == 9, "%d of 9" % refusals)


func _palette_checks() -> void:
	var src := FileAccess.get_file_as_string("res://scripts/palette.gd")
	var rx := RegEx.create_from_string("const ([A-Z_]+) := Color\\(")
	var consts: Dictionary = (Palette as Script).get_script_constant_map()
	var least := INF
	var near := ""
	for m in rx.search_all(src):
		var key := m.get_string(1)
		if key.begins_with("PIPE"):
			continue
		var c: Color = consts[key]
		if maxf(c.r, maxf(c.g, c.b)) <= 0.5:
			continue  # the dark bases, armour and glass: nothing bright to confuse it with
		var dist := _oklab(Palette.PIPE).distance_to(_oklab(c))
		if dist < least:
			least = dist
			near = key
	var frost_least := INF
	for key in ["FROST", "FROST_TEXT", "FROST_HI"]:
		for mine in [Palette.PIPE, Palette.PIPE_TEXT]:
			frost_least = minf(frost_least, _oklab(mine).distance_to(_oklab(consts[key])))
	var ice_least := INF
	for key in ["GLACIER", "HUNTER_COBALT", "HUNTER_TEXT", "BLACK_ICE", "BLACK_ICE_TEXT", "BREAKER", "BREAKER_TEXT"]:
		ice_least = minf(ice_least, _oklab(Palette.PIPE).distance_to(_oklab(consts[key])))
	var text_l := _oklab(Palette.PIPE_TEXT).x
	_check("acceptance: the pipe's own colour, a brass #%s, reads apart: at least %.2f (OKLab) from every bright colour of the palette (nearest %s, %.3f), %.2f from chmod's frost opal and its texts (it and its text, %.3f) and %.2f from ICE's glacier, the hunter's cobalt, Black ICE's slate and the breakers' ultraviolet and their texts (%.3f); its HUD text #%s legible on black (lightness %.2f)" % [Palette.PIPE.to_html(false), APART, near, least, APART_FROST, frost_least, APART_ICE, ice_least, Palette.PIPE_TEXT.to_html(false), text_l], least >= APART and frost_least >= APART_FROST and ice_least >= APART_ICE and Palette.PIPE.to_html(false) == "a79300" and text_l >= 0.7 and Palette.SKINS.get("brass") == [Palette.PIPE, Palette.PIPE_TEXT])


# --- The chain's rules on their own. ---

func _rule_checks() -> void:
	var sight := func(_a: Vector3, _b: Vector3) -> bool: return true
	var row := _row(8, 5.0)
	var links := PipeChain.build(row[0], row[0]["middle"], row, sight, _pt, _def.damage, false)
	var root_links := PipeChain.build(row[0], row[0]["middle"], row, sight, _pt, _def.damage, true)
	var damages := PackedFloat32Array()
	for link in links:
		damages.append(link["damage"])
	var falling := links.size() == 5 and absf(damages[0] - 26.0) < EPS and absf(damages[1] - 18.2) < EPS and absf(damages[2] - 12.74) < EPS and absf(damages[3] - 8.918) < EPS and absf(damages[4] - 6.2426) < EPS
	_check("acceptance: the first hit is link 1 (%.0f) and each link after it %.0f%% of the one before (%s); %d links at most, %d as root, each the nearest of the rest (%s)" % [_def.damage, _pt.link_keep * 100.0, ", ".join(Array(damages).map(func(d): return "%.2f" % d)), _pt.max_links, _pt.root_max_links, PipeChain.line_of(links)], falling and root_links.size() == 6 and PipeChain.line_of(links) == "t0 | t1 | t2 | t3 | t4", PipeChain.line_of(root_links))
	var gap_in := _row(2, _pt.jump_m - 0.01)
	var gap_out := _row(2, _pt.jump_m + 0.01)
	var reached: int = PipeChain.build(gap_in[0], gap_in[0]["middle"], gap_in, sight, _pt, 26.0, false).size()
	var missed: int = PipeChain.build(gap_out[0], gap_out[0]["middle"], gap_out, sight, _pt, 26.0, false).size()
	_check("acceptance: the jump range: a target %.2f m from the link reached, one %.2f m away not" % [_pt.jump_m - 0.01, _pt.jump_m + 0.01], reached == 2 and missed == 1)
	var walled := {}
	var through := _at([0.0, 5.0, 10.0, 18.0])
	var blocked_at: Vector3 = through[2]["middle"]
	var wall_sight := func(_a: Vector3, b: Vector3) -> bool: return b.distance_to(blocked_at) > EPS
	var cut := PipeChain.build(through[0], through[0]["middle"], through, wall_sight, _pt, 26.0, false, walled)
	_check("acceptance: walls break a chain: the next target in reach behind a wall is never arced to (the chain stops at %d links, nothing else in reach, told a wall broke it)" % cut.size(), cut.size() == 2 and walled.get("walled") == true)
	var cold := _at([0.0, 11.0, 26.0])
	cold[1]["frozen"] = true
	var conducted := PipeChain.build(cold[0], cold[0]["middle"], cold, sight, _pt, 26.0, false)
	var warm := _at([0.0, 11.0, 26.0])
	var plain := PipeChain.build(warm[0], warm[0]["middle"], warm, sight, _pt, 26.0, false)
	var near_cold := _row(3, 11.0)
	near_cold[1]["frozen"] = true
	var kept := PipeChain.build(near_cold[0], near_cold[0]["middle"], near_cold, sight, _pt, 26.0, false)
	_check("acceptance: a frozen link conducts: the stream passes through it losing nothing (link 3 %.1f, as link 2) and jumps %.1fx as far from it (15 m on from it, where a plain link's chain stops)" % [kept[2]["damage"] if kept.size() == 3 else -1.0, _pt.frozen_jump_scale], kept.size() == 3 and absf(kept[2]["damage"] - kept[1]["damage"]) < EPS and absf(kept[1]["damage"] - 18.2) < EPS and conducted.size() == 3 and plain.size() == 2)
	var guards := _row(3, 4.0)
	guards[1]["kind"] = PipeChain.Kind.WALL
	var black_pool := _row(3, 4.0)
	black_pool[1]["kind"] = PipeChain.Kind.BLACK
	var around_wall := PipeChain.build(guards[0], guards[0]["middle"], guards, sight, _pt, 26.0, false)
	var around_black := PipeChain.build(black_pool[0], black_pool[0]["middle"], black_pool, sight, _pt, 26.0, false)
	var wall_first := PipeChain.build(guards[1], guards[1]["middle"], guards, sight, _pt, 26.0, false)
	var black_first := PipeChain.build(black_pool[1], black_pool[1]["middle"], black_pool, sight, _pt, 26.0, false)
	_check("acceptance: a wall of white ICE and Black ICE are never jumped to (the chain goes round them: %s, %s), and hit first either ends the chain at once" % [PipeChain.line_of(around_wall), PipeChain.line_of(around_black)], PipeChain.line_of(around_wall) == "t0 | t2" and PipeChain.line_of(around_black) == "t0 | t2" and wall_first.size() == 1 and black_first.size() == 1 and PipeChain.build({}, Vector3.ZERO, guards, sight, _pt, 26.0, false).is_empty())


## `count` synthetic daemons in a row along +X, `gap` metres apart, named t0, t1 and on.
func _row(count: int, gap: float) -> Array:
	var xs: Array = []
	for i in count:
		xs.append(gap * i)
	return _at(xs)


## Synthetic daemons along +X at `xs`, named t0, t1 and on.
func _at(xs: Array) -> Array:
	var out: Array = []
	for i in xs.size():
		var node := Node3D.new()
		_scratch.append(node)
		out.append({"node": node, "middle": Vector3(float(xs[i]), 1.0, 0.0), "kind": PipeChain.Kind.DAEMON, "frozen": false, "id": 0, "name": "t%d" % i})
	return out


# --- The keys: Shift+2, 2, Q and the wheel. ---

func _key_checks() -> void:
	var main := await _lab({}, OPEN, true)
	var p = main.get_node("Player")
	var wh = main.get_node("Hud").weapon_hud()
	await _frames(20)
	await _key(KEY_2, true)
	var shift_two: int = p.inventory.current
	var strip_two: String = wh.bank2_text()
	var lit_two: int = wh.active_bank()
	await _key(KEY_2)
	var two: int = p.inventory.current
	await _key(KEY_Q)
	var q_back: int = p.inventory.current
	await _key(KEY_1, true)
	await _wheel(MOUSE_BUTTON_WHEEL_DOWN)
	var wheel_on: int = p.inventory.current
	await _wheel(MOUSE_BUTTON_WHEEL_DOWN)
	var wheel_wrap: int = p.inventory.current
	await _wheel(MOUSE_BUTTON_WHEEL_UP)
	var wheel_back: int = p.inventory.current
	_check("acceptance: Shift+2 draws weapon 11, pipe | (\"%s\" on the strip, bank 2 lit), 2 draws SIGTERM, Q swaps back to the pipe, and the wheel reaches it from chmod 000, goes on (to the cannon, the wrap, until C31; to /dev/null, weapon 12, since: its charges on the strip, 3(2); SIGHUP's beside them, 4(2), since C32) and comes back" % strip_two, shift_two == SLOT and strip_two == "Shift+ 1 [2 pipe] 3(2) 4(2)" and lit_two == 1 and two == 1 and q_back == SLOT and wheel_on == SLOT and wheel_wrap == SLOT + 1 and wheel_back == SLOT and p.weapon_tuning().id == "pipe_chain", "%d %d %d %d %d %d" % [shift_two, two, q_back, wheel_on, wheel_wrap, wheel_back])
	await _drop(main)


# --- The strip and the readout at 960x540. ---

func _strip_checks() -> void:
	var before := root.size
	var wrong := PackedStringArray()
	var lines := PackedStringArray()
	var row := ""
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
			feed_hud.entries.push_front({"killer": "Daemon-2", "victim": "Daemon-1", "word": "SIGPIPE", "left": 2.0})
		hud.guide()._notice("word ".repeat(60), Color.WHITE, 5000)
		hud.net_hud().toggle()
		# A root's longest chain of long names, written out under the crosshair.
		var fake: Array = []
		for i in _pt.root_max_links:
			fake.append({"name": "player-%d-with-a-long-nam" % i, "frozen": i == 2})  # 24 characters, a name's most
		p.last_chain = fake
		p.chain_end = ""
		p.chain_age = 0.0
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
		var ph = hud.pipe_hud()
		for label in [ph.get("_line"), ph.get("_small")]:
			var rect: Rect2 = (label as Label).get_global_rect()
			if not (label as Label).visible or not screen.encloses(rect) or strip.get_global_rect().intersects(rect):
				wrong.append("%d: readout %s %s" % [size.x, (label as Label).text, rect])
		row = ph.line_text() + "  " + ph.small_text()
		lines = PackedStringArray([hud.weapon_hud().bank2_text(), hud.weapon_hud().slots_text(), hud.weapon_hud().ammo_text(), hud.weapon_hud().state_text()])
		await _drop_side(host)
	root.size = before
	_check("acceptance: at 960x540 (and 1280x720) the strip keeps its two rows in its own column, the pipe in bank 2's (\"%s\" over \"%s\"), with its buffer (\"%s\", \"%s\"): every line inside the screen, clear of a full kill feed, the net panel and a long guide notice; and a root's longest chain of the longest names (24 characters) fits as one row under the crosshair, drawn smaller and its names cut (\"%s\")" % [lines[0], lines[1], lines[2], lines[3], row], wrong.is_empty() and lines[0] == "Shift+ 1 [2 pipe] 3(2) 4(2)" and lines[1] == "1 2 3 4(2) 5 6 7 8 9" and lines[2] == "pipe  buffer 0K/64K" and lines[3] == "buffer [..........]" and row.contains("(000)") and row.contains("~") and row.ends_with("6 links"), ", ".join(wrong))


# --- In practice: a chain across the dummies. ---

func _practice_checks() -> void:
	var main := await _lab(CHAIN, OPEN, true)
	var p = main.get_node("Player")
	var ph = main.get_node("Hud").pipe_hud()
	var fx := main.get_tree().get_first_node_in_group(ParticleFx.GROUP) as ParticleFx
	var spills: int = fx.fired(ParticleFx.Kind.PIPE) if fx != null else -1
	for name in CHAIN:
		_toughen(_dummy(main, name), TOUGH)
	var drawn := await _draw(p)
	_aim(p, _dummy(main, "DummyA").global_position + Vector3(0.0, 1.1, 0.0))
	var model: Node3D = p.get("_viewmodels")[SLOT]
	var rest := await _turn(model)
	await _fire(p)
	var rush := await _turn(model)
	var links: Array = p.last_chain
	var took := PackedFloat32Array()
	for name in CHAIN:
		took.append(TOUGH - _dummy(main, name).health())
	var names := PackedStringArray()
	for link in links:
		names.append(link["name"])
	var line: String = ph.line_text()
	var small: String = ph.small_text()
	_check("acceptance: the first hit and each link: aimed at rogue.d, the chain arcs on to each nearest daemon in reach and sight in turn, \"%s\" (\"%s\")" % [line, small], drawn and names == PackedStringArray(NAMES) and line == "$ " + " | ".join(NAMES) and small == "4 links" and p.chain_end == "" and p.chains_run == 1, str(names))
	_check("acceptance: the damage falls down the chain: %s off the four (26, then 70%% of the one before each link)" % ", ".join(Array(took).map(func(d): return "%.2f" % d)), absf(took[0] - 26.0) < EPS and absf(took[1] - 18.2) < EPS and absf(took[2] - 12.74) < EPS and absf(took[3] - 8.918) < EPS)
	var arc = p.pipe_arc()
	var first_lit: int = arc.lit()
	await _frames(9)
	var lit_later: int = arc.lit()
	var packets: int = arc.packets()
	var spilled: int = (fx.fired(ParticleFx.Kind.PIPE) - spills) if fx != null else -1
	_check("acceptance: the look: the stream drawn from the muzzle link to link (%d lit at the shot, %d nine frames on), %d packets riding it, a spill of packets at each link (%d), the model's couplings spun by the rush (%.3f rad a frame against %.3f at rest)" % [first_lit, lit_later, packets, spilled, rush, rest], arc.on() and first_lit < lit_later and lit_later == 4 and arc.points().size() == 5 and packets >= 12 and spilled == 4 and rush > rest * 5.0 and rest > 0.0)
	await _frames(30)
	var stays: bool = ph.line_text() != "" and arc.strength() <= 1.0
	await _frames(int((PipeArc.HOLD_S + PipeArc.FADE_S) * 60.0) + 60)
	_check("the chain fades once its last link has held, and the readout after it", not arc.on() and ph.line_text() == "" and stays)
	# Plain dummies: one chain derezzes all four, and they come back as practice's dummies do.
	for name in CHAIN:
		var dummy := _dummy(main, name)
		_toughen(dummy, 1.0)
	await _frames(30)
	_aim(p, _dummy(main, "DummyA").global_position + Vector3(0.0, 1.1, 0.0))
	await _fire(p)
	var down := 0
	for name in CHAIN:
		down += 0 if _dummy(main, name).is_alive() else 1
	var back := await _wait(func(): return CHAIN.keys().all(func(n): return _dummy(main, n).is_alive()), 600)
	_check("acceptance: practice still chains across the dummies: one chain takes all four plain ones down at once (%d), and they come back" % down, down == 4 and back >= 0)
	# Alone: one link, and the readout says why.
	for name in ["DummyB", "DummyD", "DummyC"]:
		_park(_dummy(main, name))
	await _frames(40)
	_aim(p, _dummy(main, "DummyA").global_position + Vector3(0.0, 1.1, 0.0))
	await _fire(p)
	_check("a lone daemon is a one-link chain: \"%s\" / \"%s\"" % [ph.line_text(), ph.small_text()], p.last_chain.size() == 1 and ph.line_text() == "$ rogue.d" and ph.small_text() == "1 link: no one else in reach")
	await _drop(main)


## Range in the world: a second daemon 11.8 m from the first is linked, one 12.3 m away is not.
func _reach_checks() -> void:
	var main := await _lab({"DummyA": Vector3(0.0, 0.0, 9.0), "DummyB": Vector3(-11.8, 0.0, 9.0)}, OPEN, true)
	var p = main.get_node("Player")
	for name in ["DummyA", "DummyB"]:
		_toughen(_dummy(main, name), TOUGH)
	await _draw(p)
	_aim(p, _dummy(main, "DummyA").global_position + Vector3(0.0, 1.1, 0.0))
	await _fire(p)
	var near: int = p.last_chain.size()
	_place(_dummy(main, "DummyB"), main.to_global(Vector3(-12.3, 0.0, 9.0)))
	await _frames(30)
	_aim(p, _dummy(main, "DummyA").global_position + Vector3(0.0, 1.1, 0.0))
	await _fire(p)
	var far: int = p.last_chain.size()
	_check("acceptance: the jump range in the arena: a daemon 11.8 m on is linked, one 12.3 m on is not (%d, then %d links)" % [near, far], near == 2 and far == 1)
	await _drop(main)


## A wall between two daemons breaks the chain; with the wall out of the way the chain goes on.
func _wall_checks() -> void:
	var main := await _lab({"DummyA": Vector3(1.8, 0.0, 4.6), "DummyB": Vector3(-1.0, 0.0, -0.8)}, Vector3(3.2, 0.95, 9.6), true)
	var p = main.get_node("Player")
	var ph = main.get_node("Hud").pipe_hud()
	var behind := _dummy(main, "DummyB")
	for name in ["DummyA", "DummyB"]:
		_toughen(_dummy(main, name), TOUGH)
	await _draw(p)
	_aim(p, _dummy(main, "DummyA").global_position + Vector3(0.0, 1.1, 0.0))
	await _fire(p)
	var cut: int = p.last_chain.size()
	var said: String = ph.small_text()
	var untouched: bool = behind.health() == TOUGH
	_place(behind, main.to_global(Vector3(-1.0, 0.0, 6.0)))
	await _frames(30)
	_aim(p, _dummy(main, "DummyA").global_position + Vector3(0.0, 1.1, 0.0))
	await _fire(p)
	_check("acceptance: walls break a chain: the zombie in reach behind the low wall is never arced to (%d link, \"%s\", untouched), and in the open beside it is (%d links)" % [cut, said, p.last_chain.size()], cut == 1 and said == "1 link: a wall broke the chain" and p.chain_walled == false and untouched and p.last_chain.size() == 2 and behind.health() < TOUGH)
	await _drop(main)


## A daemon chmod 000 froze conducts the chain on, whole, and shatters.
func _frozen_checks() -> void:
	var main := await _lab({"DummyA": Vector3(0.0, 0.0, 9.0), "DummyB": Vector3(4.0, 0.0, 7.5), "DummyD": Vector3(4.0, 1.0, -7.0)}, OPEN, true)
	var p = main.get_node("Player")
	var ph = main.get_node("Hud").pipe_hud()
	var zombie := _dummy(main, "DummyB")
	var runaway := _dummy(main, "DummyD")
	_toughen(_dummy(main, "DummyA"), TOUGH)
	_toughen(runaway, TOUGH)
	_toughen(zombie, 1.0)
	await _draw(p)
	zombie.chill(10.0)
	var frozen: bool = zombie.chmod_frozen()
	_aim(p, _dummy(main, "DummyA").global_position + Vector3(0.0, 1.1, 0.0))
	await _fire(p)
	var reach: float = (zombie.global_position + Vector3.UP * 0.9).distance_to(runaway.global_position + Vector3.UP * 0.9)
	_check("acceptance: a chain through a chmod-frozen daemon: it conducts (the runaway %.1f m on from it, past a plain link's %.0f m, takes %.2f, the frozen link's own %.2f, nothing lost) and the frozen link shatters (\"%s\")" % [reach, _pt.jump_m, TOUGH - runaway.health(), p.last_chain[1]["damage"] if p.last_chain.size() > 1 else -1.0, ph.line_text()], frozen and p.last_chain.size() == 3 and reach > _pt.jump_m and absf((TOUGH - runaway.health()) - 18.2) < EPS and zombie.shatters == 1 and not zombie.is_alive() and ph.line_text() == "$ rogue.d | zombie(000) | runaway")
	await _drop(main)


# --- ICE: the hunter and the nodes are links; a wall ends a chain; exploit's seams count. ---

func _ice_checks() -> void:
	var main := await _lab({}, Vector3(7.0, 0.95, 3.0), false, true)
	var ice := _ice(main)
	var p = main.get_node("Player")
	var ph = main.get_node("Hud").pipe_hud()
	var life := _life(main)
	var breakers := BreakerDirector.of(main)
	await _draw(p)
	ice.start_round(2)
	await _frames(2)
	life.combat.states[1]["protect_left"] = 1000.0
	var rogue := _dummy(main, "DummyA")
	var node := ice.node_of("jam")
	var gate := ice.wall("gate")
	_toughen(rogue, TOUGH)
	var taken := []
	for exploit in [false, true]:
		breakers.exploit_left[breakers.my_id()] = 6.0 if exploit else 0.0
		_place(rogue, main.to_global(Vector3(1.0, 0.0, 0.0)))
		ice.hunter.global_position = main.to_global(Vector3(-2.0, 0.0, -1.5))
		await _frames(28)
		_place(rogue, main.to_global(Vector3(1.0, 0.0, 0.0)))
		ice.hunter.global_position = main.to_global(Vector3(-2.0, 0.0, -1.5))
		_aim(p, rogue.global_position + Vector3(0.0, 1.1, 0.0))
		var before: float = node.health()
		await _fire(p)
		taken.append(before - node.health())
	breakers.exploit_left[breakers.my_id()] = 0.0
	var names := PipeChain.line_of(p.last_chain)
	_check("acceptance: against ICE: the hunter and a node are links like daemons (\"%s\"), the gate never one; exploit-marked ICE takes its marked damage on a link (each link lands on a seam): the node's link %.2f plain, %.2f with exploit running (%.1fx)" % [names, taken[0], taken[1], taken[1] / maxf(taken[0], EPS)], names == "rogue.d | hunter ICE | white ICE: jam" and absf(taken[0] - 12.74) < EPS and absf(taken[1] - 12.74 * 2.5) < 0.01 and gate.health() == gate.max_health and ph.line_text().begins_with("$ rogue.d | hunter ICE"))
	# A wall hit first takes its hit and ends the chain, whatever stands in reach of it.
	_place(rogue, main.to_global(Vector3(0.0, 0.0, -5.5)))
	p.global_position = main.to_global(Vector3(0.0, 0.95, 4.0))
	await _frames(30)
	_place(rogue, main.to_global(Vector3(0.0, 0.0, -5.5)))
	_aim(p, gate.global_position + Vector3(1.0, 2.2, 0.0))
	var wall_before: float = gate.health()
	var rogue_before: float = rogue.health()
	await _fire(p)
	_check("acceptance: a wall of white ICE hit first takes its hit (%.0f) and passes nothing on (\"%s\" / \"%s\"), rogue.d in reach of it untouched" % [wall_before - gate.health(), ph.line_text(), ph.small_text()], p.chain_end == "wall" and p.last_chain.size() == 1 and absf(wall_before - gate.health() - 26.0) < EPS and rogue.health() == rogue_before and ph.line_text() == "$ white ICE" and ph.small_text() == "pipe: the wall reads nothing on")
	await _drop(main)


func _black_checks() -> void:
	var main := await _lab({}, OPEN, false, true)
	var ice := _ice(main)
	var p = main.get_node("Player")
	var ph = main.get_node("Hud").pipe_hud()
	var life := _life(main)
	await _draw(p)
	ice.start_round(4)
	var b := ice.summon_black(3)
	b.phase_t = b.tuning.tell_s
	b.step(0.0, ice.daemons)
	life.combat.states[1]["protect_left"] = 1000.0
	p.global_position = b.global_position + Vector3(0.0, 0.95, 9.0)
	await _frames(2)
	_aim(p, b.global_position + Vector3(0.0, 2.6, 0.0))
	var seals: int = b.seals_left
	var flashes: int = b.flashes
	var health: float = b.health()
	await _fire(p)
	var line: String = ph.line_text()
	var small: String = ph.small_text()
	_check("acceptance: Black ICE hit first is only flashed (%d flash) and refuses the chain (\"%s\" / \"%s\"): never hurt, its seals untouched, still out" % [b.flashes - flashes, line, small], p.chain_end == "black" and p.last_chain.size() == 1 and b.flashes == flashes + 1 and b.seals_left == seals and b.health() == health and not b.broken and line == "pipe: broken pipe" and small == "Black ICE takes nothing")
	# A daemon beside it: the chain never jumps to Black ICE, however near (the hunter and the nodes broken
	# first, so nothing else is in reach).
	for piece in ice.pieces():
		if piece is HunterIce or piece is IceNode:
			for i in 4:
				piece.hit(1000.0, Vector3.INF, Vector3.ZERO, "")
	var rogue := _dummy(main, "DummyA")
	_toughen(rogue, TOUGH)
	_place(rogue, b.global_position + Vector3(3.5, 0.0, 3.0))
	p.global_position = b.global_position + Vector3(3.5, 0.95, 11.0)
	await _frames(30)
	_place(rogue, b.global_position + Vector3(3.5, 0.0, 3.0))
	_aim(p, rogue.global_position + Vector3(0.0, 1.1, 0.0))
	var flashes_now: int = b.flashes
	await _fire(p)
	_check("acceptance: and it is never a link: a chain from a daemon %.1f m from it ends there (%d link), Black ICE neither hurt nor flashed by it" % [rogue.global_position.distance_to(b.global_position), p.last_chain.size()], p.last_chain.size() == 1 and p.last_chain[0]["name"] == "rogue.d" and b.flashes == flashes_now and b.seals_left == seals and b.health() == health)
	await _drop(main)


# --- The buffer: it fills, blocks, drains; root writes nothing. ---

func _buffer_checks() -> void:
	var main := await _lab({}, OPEN, true)
	var p = main.get_node("Player")
	var ph = main.get_node("Hud").pipe_hud()
	var wh = main.get_node("Hud").weapon_hud()
	await _draw(p)
	var pipe = p.inventory.buffer(SLOT)
	p.get_node("Head").rotation.x = 1.2  # at the open sky: nothing is struck
	var shots := 0
	for i in 12:
		if pipe.blocked:
			break
		await _fire(p)
		shots += 1
		await _frames(int(_def.fire_cooldown * 60.0) - 1)  # fired again on the interval: inside the buffer's rest
	var chains: int = p.chains_run
	await _fire(p)
	var refused: bool = p.chains_run == chains and pipe.blocked
	var note: String = ph.line_text()
	var ammo: String = wh.ammo_text()
	var state: String = wh.state_text()
	var gauge: float = p.get("_viewmodels")[SLOT].charge()
	var unblocked := await _wait(func(): return not pipe.blocked, int((_pt.drain_rest_s + _pt.buffer_kib * (1.0 - _pt.unblock_share) / _pt.drain_kib_s) * 60.0) + 30)
	var share: float = pipe.share()
	await _fire(p)
	_check("acceptance: its ammo is the buffer: %d chains of %.0fK fill its %.0fK and block it (\"%s\", \"%s\", \"%s\"); no chain then; it drains back to %.0f%% (%.2f) and runs again" % [shots, _pt.write_kib, _pt.buffer_kib, ammo, state, note, _pt.unblock_share * 100.0, share], shots == int(_pt.buffer_kib / _pt.write_kib) and refused and ammo == "pipe  BLOCKED" and state.begins_with("blocked [") and note == "pipe: write blocked, buffer full" and unblocked >= 0 and absf(share - _pt.unblock_share) < 0.05 and p.chains_run == chains + 1)
	await _wait(func(): return pipe.fill == 0.0, 300)
	p.sudo.state.charges = 1
	p.sudo.press()
	await _frames(3)
	var root_now: bool = p.sudo.is_root()
	await _fire(p)
	_check("root writes nothing: a chain as root leaves the buffer empty (C22's free ammo)", root_now and pipe.fill == 0.0 and p.chains_run == chains + 2)
	_check("the model's gauge is the buffer: its eight \"|\" bars all lit while it is full and blocked (%.2f)" % gauge, absf(gauge - 1.0) < EPS)
	await _drop(main)


# --- A match: the host judges. ---

func _match_checks() -> void:
	GameSettings.current().set_value("gameplay", "practice", false)
	GameSettings.current().set_value("gameplay", "difficulty", "normal")
	GameSettings.current().set_value("gameplay", "ice", false)
	var host := _branch("Host", Vector3.ZERO)
	var client := _branch("Client", CLIENT_OFFSET)
	await _frames(2)
	var joined := await _join(host, client)
	var hs = host["session"]
	var cs = client["session"]
	var cid: int = cs.my_id
	var session_code := _code("res://scripts/net/net_session.gd")
	var rpcs := session_code.count("@rpc(")
	_check("acceptance: the wire: protocol 19 (15 at C29, 16 at C30, 17 at C31, 18 at C32, 19 at C33), no new message (28 RPCs, as I2 left them) and no changed one: a chain is the usual fire intent, told as the usual shot message (its ends the chain's points)", joined and Session.PROTOCOL == 19 and rpcs == 28 and _body(session_code, "_handle_fire").contains("_pipe_judge(shooter, origin, dir, def)") and _body(session_code, "_shot").contains("pipe_tuning().root_max_links"), "%d RPCs" % rpcs)
	var hp = host["player"]
	var cp = client["player"]
	for name in ["DummyA", "DummyB", "DummyC", "DummyD"]:
		_park(_dummy(host["main"], name))
	# The joiner's chain on the host's rogue.d, on to the host's own player beside it: the host judges both.
	var rogue := _dummy(host["main"], "DummyA")
	var copy := _dummy(client["main"], "DummyA")
	_toughen(rogue, TOUGH)
	cp.global_position = client["main"].to_global(OPEN)
	cp.select_slot(SLOT)
	var drawn := await _wait(func(): return hs.combat.drawn_by(cid) == "pipe_chain", 120)
	await _frames(30)
	hs.combat.states[cid]["protect_left"] = 0.0
	hs.combat.states[1]["protect_left"] = 0.0
	_place(rogue, host["main"].to_global(Vector3(0.0, 0.0, 9.0)))
	hp.global_position = host["main"].to_global(Vector3(4.0, 0.95, 6.5))
	await _wait(func(): return copy.global_position.distance_to(client["main"].to_global(Vector3(0.0, 0.0, 9.0))) < 0.3, 60)
	await _frames(4)
	_place(rogue, host["main"].to_global(Vector3(0.0, 0.0, 9.0)))
	_aim(cp, client["main"].to_global(Vector3(0.0, 1.1, 9.0)))
	var judged: int = hs.chains_judged
	var host_health: float = hs.combat.health_of(1)
	var copy_health: float = copy.health()
	var avatar_fired: int = hs.avatars[cid].pipe_arc().fired() if hs.avatars.has(cid) else -1
	await _fire(cp)
	var heard := await _wait(func(): return hs.chains_judged > judged, 60)
	var links: Array = hs.last_judged
	var kinds := PackedStringArray()
	for link in links:
		kinds.append("player %d" % link["id"] if link["kind"] == PipeChain.Kind.PLAYER else String(link["name"]))
	var drawn_there := await _wait(func(): return hs.avatars.has(cid) and hs.avatars[cid].pipe_arc().fired() > avatar_fired, 30)
	_check("acceptance: in a match the host judges every chain: the joiner's chain, built again in the host's world (%s), lands on the host's rogue.d (%.0f) and on to the host's own player beside it, a player link (%.2f off its health), and the host's screen draws it from the joiner's avatar" % [", ".join(kinds), TOUGH - rogue.health(), host_health - hs.combat.health_of(1)], joined and drawn >= 0 and heard >= 0 and kinds.size() == 2 and kinds[0] == "rogue.d" and kinds[1] == "player 1" and absf(TOUGH - rogue.health() - 26.0) < EPS and absf(host_health - hs.combat.health_of(1) - 18.2) < 0.01 and drawn_there >= 0, str(kinds))
	_check("the joiner's own screen lands nothing itself: its copy of rogue.d (a plain one, %.0f health) still stands, untouched by the joiner's own chain" % copy_health, copy.is_alive() and copy.health() == copy_health and copy_health > 0.0)
	# Spawn protection holds: a protected player is never a link.
	await _frames(int(_def.fire_cooldown * 60.0) + 4)
	hs.combat.states[1]["protect_left"] = 10.0
	_place(rogue, host["main"].to_global(Vector3(0.0, 0.0, 9.0)))
	hp.global_position = host["main"].to_global(Vector3(4.0, 0.95, 6.5))
	_aim(cp, client["main"].to_global(Vector3(0.0, 1.1, 9.0)))
	judged = hs.chains_judged
	host_health = hs.combat.health_of(1)
	await _fire(cp)
	await _wait(func(): return hs.chains_judged > judged, 60)
	_check("acceptance: spawn protection holds: a protected player beside the daemon is no link (%d link), its health untouched" % hs.last_judged.size(), hs.last_judged.size() == 1 and hs.combat.health_of(1) == host_health)
	# The host's own chain on the joiner's player, drawn on the joiner's screen from the host's avatar.
	hs.combat.states[1]["protect_left"] = 0.0
	_park(rogue)
	cp.global_position = client["main"].to_global(Vector3(0.0, 0.95, 9.0))
	hp.global_position = host["main"].to_global(OPEN)
	hp.select_slot(SLOT)
	await _wait(func(): return hs.combat.drawn_by(1) == "pipe_chain" and hp.inventory.fire_block() == "", 120)
	await _wait(func(): return hs.avatars.has(cid) and hs.avatars[cid].global_position.distance_to(host["main"].to_global(Vector3(0.0, 0.95, 9.0))) < 0.3, 60)
	_aim(hp, host["main"].to_global(Vector3(0.0, 0.95, 9.0)))
	# Two plain daemons in reach beyond the joiner: the host's own hits take them down before its session
	# judges the chain, so a chain built again then would end at the joiner.
	var zombie := _dummy(host["main"], "DummyB")
	for pair in [[rogue, Vector3(3.5, 0.0, 9.0)], [zombie, Vector3(7.0, 0.0, 9.0)]]:
		_toughen(pair[0], 1.0)
		_place(pair[0], host["main"].to_global(pair[1]))
	var joiner_health: float = hs.combat.health_of(cid)
	var host_avatar_fired: int = cs.avatars[1].pipe_arc().fired() if cs.avatars.has(1) else -1
	await _fire(hp)
	var seen := await _wait(func(): return cs.avatars.has(1) and cs.avatars[1].pipe_arc().fired() > host_avatar_fired, 60)
	var own := PackedStringArray()
	for link in hs.last_judged:
		own.append("player %d" % link["id"] if link["kind"] == PipeChain.Kind.PLAYER else String(link["name"]))
	_check("acceptance: the host's own chain is the one its player built (pipe_last(), \"%s\"): it lands on the joiner (%.0f off its health) and on to the two daemons beyond, which its own hits took down before its session judged it; the joiner's screen draws it from the host's avatar" % [", ".join(own), joiner_health - hs.combat.health_of(cid)], absf(joiner_health - hs.combat.health_of(cid) - 26.0) < EPS and seen >= 0 and own == PackedStringArray(["player %d" % cid, "rogue.d", "zombie"]) and not rogue.is_alive() and not zombie.is_alive())
	# A miss: the stream into the open, drawn on the host's screen to its end alone, no link lit.
	await _frames(int(_def.fire_cooldown * 60.0) + 4)
	cp.get_node("Head").rotation.x = 1.2
	judged = hs.chains_judged
	var miss_fired: int = hs.avatars[cid].pipe_arc().fired() if hs.avatars.has(cid) else -1
	await _fire(cp)
	await _wait(func(): return hs.chains_judged > judged and hs.avatars[cid].pipe_arc().fired() > miss_fired, 60)
	var miss_arc = hs.avatars[cid].pipe_arc()
	await _frames(12)
	_check("a miss is told as its end twice and drawn as the stream into the open alone: no link judged, none lit on the other screen", hs.last_judged.is_empty() and miss_arc.fired() > miss_fired and miss_arc.points().size() == 2 and miss_arc.lit() == 0)
	# The aim's ray shoots off a cron mine on its way, as any shot does (C27): the host's mine on the floor.
	hp.select_slot(CRON)
	await _wait(func(): return hs.combat.drawn_by(1) == "cron_mines" and hp.inventory.fire_block() == "", 120)
	_aim(hp, host["main"].to_global(Vector3(2.0, 0.0, 13.0)))
	var mines: Dictionary = hs.get("_mines")
	var placed_before := mines.size()
	await _fire(hp)
	var placed := await _wait(func(): return mines.size() > placed_before, 60)
	var mine: Node3D = null
	for id in mines:
		mine = mines[id]
	var removed := -1
	if placed >= 0 and mine != null:
		await _frames(int(_def.fire_cooldown * 60.0) + 4)
		_aim(cp, client["main"].to_global(host["main"].to_local(mine.global_position)))
		await _fire(cp)
		removed = await _wait(func(): return not is_instance_valid(mine) or mine.get("why") == CronMine.SHOT, 90)
	_check("a chain's aim shoots off a cron mine on its way, as any shot does (the host's mine, removed by the joiner's chain)", placed >= 0 and removed >= 0)
	# A blocked buffer is refused, whatever the joiner's screen says.
	var pipe: PipeBuffer = hs.combat.buffer_of(cid)
	pipe.fill = pipe.full()
	pipe.blocked = true
	await _frames(int(_def.fire_cooldown * 60.0) + 4)
	var buffer_drops: int = hs.combat.drops.get("buffer", 0)
	cs._on_fire_intent(cp.eye_position(), Vector3.FORWARD, "pipe_chain")
	var dropped := await _wait(func(): return hs.combat.drops.get("buffer", 0) > buffer_drops, 60)
	_check("acceptance: the host owns the buffer: a joiner's chain from a blocked buffer is refused (buffer)", dropped >= 0)
	await _drop_side(client)
	await _drop_side(host)
	GameSettings.current().set_value("gameplay", "ice", true)


# --- Helpers. ---

## Draws pipe | on `p` and waits out the swap; true when it is in hand and ready.
func _draw(p: Node) -> bool:
	p.select_slot(SLOT)
	await _frames(30)
	return p.weapon_tuning().id == "pipe_chain" and p.inventory.fire_block() == ""


## How far `model`'s first coupling turns in one physics frame, in radians.
func _turn(model: Node3D) -> float:
	var before: float = model.coupling_angle()
	await physics_frame
	return absf(wrapf(model.coupling_angle() - before, -PI, PI))


## One click of fire, and the frame it fires in.
func _fire(p: Node) -> void:
	await physics_frame
	p.drive_input(Vector2.ZERO, false, false, true)
	await physics_frame
	await physics_frame


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
	for node in _scratch:
		if is_instance_valid(node):
			node.free()
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
