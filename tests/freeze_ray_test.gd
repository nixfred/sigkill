extends SceneTree
## Headless test of chmod 000, the freeze ray, weapon 10, and the weapon strip's second bank, for SIGKILL
## (C29, PRD 5.2: "chmod 000: freeze ray"). scripts/check.sh runs it as step 43, and any FAIL exits 1.
##
##   godot --headless --path . --fixed-fps 60 --script res://tests/freeze_ray_test.gd
##
## The weapon: its resource's numbers and its checks (no damage, no magazine, coolant; the freeze
## tuning's refusals, Black ICE's slow capped at 40%), its own frost opal measured in OKLab against every
## bright colour of the palette and kept clear of ICE's blues and the breakers' ultraviolet. The bank:
## slot 10, bank 2's first; the bank key Shift, rebindable, free of every other action and fixed key, no
## Ctrl or Alt; Shift+1 draws it, 1 draws the cannon, Q and the wheel reach it; the strip's two rows at
## 960x540 (the active bank lit) clear of the kill feed and the panels. In the real arena with the real
## player holding fire: the beam's meter fills by its ticks and freezes a daemon in its time (its frost
## creeping up, then whole, "PERMISSION DENIED"), frozen it neither moves, turns nor attacks, and thaws in
## its time behind a guard; a tell it was in is called off (no strike, no damage); the next hit on it
## frozen lands harder and thaws it, a strong one shatters it whatever its health, any kill of it is a
## shatter; the coolant drains, vents and refills; Black ICE is only slowed (never more than 40%), never
## frozen, hurt or flashed, its seals untouched, its touch still a flatline; a wall of white ICE ignores
## the beam; the hunter freezes (its lance's tell called off) and takes the frozen bonus after its cap; a
## node's field is paused (its tell called off); practice still freezes the dummies. Then a host and a
## joiner over ENet on 127.0.0.1 (the joiner's arena 1000 m off): the joiner's beam freezes the host's
## daemon (the host judging; the joiner's copy frosted from the host's word); a player beamed is slowed,
## then frozen briefly, and its shots refused while frozen; spawn protection holds; a venting tank's tick
## is refused; protocol 15, no new message. And the fiction rule for the freeze code (no real chmod,
## ever), and nothing made while the beam runs. Deterministic: frames counted, only counts and outcomes
## printed.

const Session = preload("res://scripts/net/net_session.gd")
const NetTuningScript = preload("res://scripts/net/net_tuning.gd")
const Link = preload("res://scripts/guide/guide_link.gd")
const MainScene = preload("res://scenes/main.tscn")
const Controls = preload("res://scripts/controls.gd")
const Palette = preload("res://scripts/palette.gd")
const WeaponDefScript = preload("res://scripts/weapons/weapon_def.gd")
const Arsenal = preload("res://scripts/weapons/arsenal_tuning.gd")
const GrepLock = preload("res://scripts/weapons/grep_lock.gd")
const CHMOD_PATH := "res://resources/chmod_000.tres"
const ARSENAL_PATH := "res://resources/arsenal.tres"
const FREEZE_CODE := ["res://scripts/weapons/frost.gd", "res://scripts/weapons/coolant.gd", "res://scripts/weapons/freeze_beam.gd", "res://scripts/weapons/freeze_tuning.gd", "res://scripts/fx/frost_look.gd", "res://scripts/hud/freeze_hud.gd", "res://scripts/viewmodels/chmod_000.gd"]
const WATCHDOG_MS := 12000
const CLIENT_OFFSET := Vector3(1000.0, 0.0, 0.0)
## Open floor south of the low wall, clear of the crates and the platform.
const OPEN := Vector3(0.0, 0.95, 15.0)
## Where a daemon a check does not use waits: under the floor, out of every sight line.
const PARKED := Vector3(0.0, -50.0, 0.0)
## chmod 000's slot (slot 10: bank 2's first).
const SLOT := 9
const NEVER := ["OS.", "execute", "create_process", "kill(", "Thread", "HTTP", "PacketPeer", "StreamPeer", "TCPServer", "UDPServer", "DirAccess", "FileAccess", "set_unix_permissions", "shell_open", "move_to_trash", "Expression", "Time.", "ctrl_pressed", "alt_pressed", "rpc"]
## How far apart (OKLab) the frost keeps from every bright colour, and from ICE's and the breakers'.
const APART := 0.15
const APART_ICE := 0.17
const LONG_ROUND_S := 100000.0
const EPS := 0.001

var _fails := 0
var _checks := 0
var _tmp := ""
var _arenas: Array = []
var _branches: Array = []
var _def: WeaponDefScript
var _ft: FreezeTuning


func _initialize() -> void:
	_run()


func _run() -> void:
	await process_frame
	root.size = Vector2i(1280, 720)
	_tmp = OS.get_temp_dir().path_join("sigkill-freeze-test-%d" % OS.get_process_id())
	if DirAccess.dir_exists_absolute(_tmp):
		print("FAIL the test's temporary folder already exists; not touching it")
		quit(1)
		return
	DirAccess.make_dir_recursive_absolute(_tmp)
	Controls.ensure()
	GameSettings.current().reset()
	_def = load(CHMOD_PATH)
	_ft = _def.freeze
	_source_checks()
	_weapon_checks()
	_palette_checks()
	_bank_checks()
	await _key_checks()
	await _strip_checks()
	await _meter_checks()
	await _tell_checks()
	await _shatter_checks()
	await _coolant_checks()
	await _black_checks()
	await _wall_checks()
	await _hunter_checks()
	await _node_checks()
	await _practice_checks()
	await _ice_marks_checks()
	await _match_checks()
	await _cleanup()
	for name in DirAccess.get_files_at(_tmp):
		DirAccess.remove_absolute(_tmp.path_join(name))
	DirAccess.remove_absolute(_tmp)
	print("FREEZE: %d checks" % _checks)
	print("FREEZE RESULT: ", "ALL PASS" if _fails == 0 else "%d FAILED" % _fails)
	quit(0 if _fails == 0 else 1)


func _check(label: String, ok: bool, detail: String = "") -> void:
	_checks += 1
	print("PASS " if ok else "FAIL ", label, ("   " + detail) if detail != "" else "")
	if not ok:
		_fails += 1


# --- The code, the weapon, its numbers and its colour. ---

func _source_checks() -> void:
	var code := ""
	for path in FREEZE_CODE:
		code += _code(path)
	var found := PackedStringArray()
	for word in NEVER:
		if code.contains(word):
			found.append(word)
	_check("acceptance: fiction only, no real chmod ever: the freeze code (the meter, the coolant, the beam, the frost, the readout, the model) makes no OS, process, file or permission call (no set_unix_permissions), no folder, thread or network call, no RPC, reads no wall clock and handles no Ctrl or Alt key", found.is_empty() and code.length() > 8000, ", ".join(found))
	var beam := _code(FREEZE_CODE[2])
	var look := _code(FREEZE_CODE[4])
	var each := _body(beam, "_process") + _body(beam, "_place") + _body(beam, "aim") + _body(look, "_process")
	var made := PackedStringArray()
	for word in [".new(", "instantiate(", "duplicate(", "Mesh(", "Material("]:
		if each.contains(word):
			made.append(word)
	_check("acceptance: nothing is made while the beam runs or a frost shows: what runs each frame (the beam's feed, step and placing, the frost's step) makes no node, mesh or material; the beam is made once per shooter and the frost once per target, then kept", made.is_empty() and each.length() > 1200 and look.contains("if _material == null"), ", ".join(made))
	var crust := FileAccess.get_file_as_string("res://shaders/frost_crust.gdshader")
	_check("the frost sits on the creature as it stands: its shader reads the target's own posed parts (their presence honoured) and pushes them out along their normals, creeping up from the feet with the meter", crust.contains("INSTANCE_CUSTOM") and crust.contains("VERTEX += NORMAL") and crust.contains("instance uniform float coverage") and crust.contains("instance uniform float frozen") and crust.contains("discard"))


func _weapon_checks() -> void:
	var d := _def
	_check("acceptance: chmod 000 is its own weapon on the framework: fire mode freeze, held, its beam ticking every %.2f s to %.0f m, no magazine and no ammo but coolant, no damage, in its own frost, with its own model and its freeze tuning inside its one resource" % [d.fire_cooldown, d.fire_range], d.problems().is_empty() and d.id == "chmod_000" and d.is_freeze() and not d.has_magazine() and d.damage == 0.0 and d.fire_cooldown == 0.1 and d.fire_range == 22.0 and d.light_skin == "frost" and d.viewmodel_model.resource_path == "res://scripts/viewmodels/chmod_000.gd" and _ft is FreezeTuning and _ft.problems().is_empty() and _ft.resource_path.begins_with(CHMOD_PATH) and d.short_name == "chmod", str(d.problems()))
	_check("its numbers: a %.0f s tank resting %.1f s then refilling in %.0f s, venting to %d%%; a daemon frozen by %.1f s of beam (an elite %.1f, ICE %.1f, a player %.1f) for %.1f s (ICE %.1f, a player %.1f), a guard of %.1f s after (a player %.1f); a player slowed up to %d%% first; the next hit on the frozen %.0fx, %.0f or more shatters; Black ICE slowed up to %d%%" % [_ft.coolant_s, _ft.coolant_rest_s, _ft.coolant_refill_s, roundi(_ft.vent_share * 100.0), _ft.chill_s, _ft.elite_chill_s, _ft.ice_chill_s, _ft.player_chill_s, _ft.freeze_s, _ft.ice_freeze_s, _ft.player_freeze_s, _ft.thaw_guard_s, _ft.player_guard_s, roundi(_ft.player_slow * 100.0), _ft.frozen_hit_scale, _ft.shatter_damage, roundi(_ft.black_slow * 100.0)], _ft.coolant_s == 4.0 and _ft.chill_s == 1.0 and _ft.freeze_s == 3.0 and _ft.player_freeze_s == 1.0 and _ft.frozen_hit_scale == 2.0 and _ft.shatter_damage == 40.0 and _ft.black_slow == 0.4)
	var bad := FreezeTuning.new()
	bad.black_slow = 0.5
	var slow_refused := not bad.problems().is_empty()
	bad = FreezeTuning.new()
	bad.player_freeze_s = 3.0
	var long_refused := not bad.problems().is_empty()
	var hurt: WeaponDefScript = d.duplicate()
	hurt.damage = 5.0
	var mag: WeaponDefScript = d.duplicate()
	mag.magazine_size = 10
	mag.reserve_ammo = 20
	mag.reload_s = 1.0
	var none: WeaponDefScript = d.duplicate()
	none.freeze = null
	var cannon: WeaponDefScript = load("res://resources/terminal_cannon.tres").duplicate()
	cannon.freeze = _ft
	_check("the checks refuse what would break it: Black ICE slowed past 40%, a player frozen past 2 s, a freeze ray that does damage, one with a magazine, one with no freeze tuning, and a freeze tuning on any other weapon", slow_refused and long_refused and not hurt.problems().is_empty() and not mag.problems().is_empty() and not none.problems().is_empty() and not cannon.problems().is_empty())


func _palette_checks() -> void:
	var src := FileAccess.get_file_as_string("res://scripts/palette.gd")
	var rx := RegEx.create_from_string("const ([A-Z_]+) := Color\\(")
	var consts: Dictionary = (Palette as Script).get_script_constant_map()
	var least := INF
	var near := ""
	for m in rx.search_all(src):
		var key := m.get_string(1)
		if key.begins_with("FROST"):
			continue
		var c: Color = consts[key]
		if maxf(c.r, maxf(c.g, c.b)) <= 0.5:
			continue  # the dark bases, armour and glass: nothing bright to confuse it with
		var dist := _oklab(Palette.FROST).distance_to(_oklab(c))
		if dist < least:
			least = dist
			near = key
	var ice_least := INF
	for key in ["GLACIER", "HUNTER_COBALT", "HUNTER_TEXT", "BLACK_ICE", "BLACK_ICE_TEXT", "BREAKER", "BREAKER_TEXT"]:
		ice_least = minf(ice_least, _oklab(Palette.FROST).distance_to(_oklab(consts[key])))
	var text_l := _oklab(Palette.FROST_TEXT).x
	_check("acceptance: the frost's own colour, a frost opal #%s, reads apart: at least %.2f (OKLab) from every bright colour of the palette (nearest %s, %.3f) and %.2f from ICE's glacier, the hunter's cobalt, Black ICE's slate and the breakers' ultraviolet and their texts (%.3f), so a frozen daemon never reads as ICE; its HUD text #%s legible on black" % [Palette.FROST.to_html(false), APART, near, least, APART_ICE, ice_least, Palette.FROST_TEXT.to_html(false)], least >= APART and ice_least >= APART_ICE and Palette.FROST.to_html(false) == "a87884" and text_l >= 0.7 and Palette.SKINS.has("frost"))


func _bank_checks() -> void:
	var shipped := load(ARSENAL_PATH) as Arsenal
	var loadout := Arsenal.usable_loadout(shipped)
	_check("acceptance: weapon 10, bank 2's first: the arsenal holds ten (nine in bank 1 as before; eleven since C30's pipe |, twelve since C31's /dev/null, thirteen since C32's SIGHUP), chmod 000 the tenth, bank 2 key 1", shipped.problems().is_empty() and loadout.size() == 13 and loadout[SLOT].id == "chmod_000" and Arsenal.bank_of(SLOT) == 1 and Arsenal.key_of(SLOT) == 1 and Arsenal.bank_of(8) == 0 and Arsenal.key_of(8) == 9 and Arsenal.SLOTS_LAST == 18, str(loadout.map(func(w): return w.id)))
	var shift := Controls.default_bind("weapon_bank")
	var clashes := Controls.conflicts({})
	var others := PackedStringArray()
	for pair in Controls.REBINDABLE:
		if pair[0] != "weapon_bank" and Controls.default_bind(pair[0]) == shift:
			others.append(pair[0])
	for action in InputMap.get_actions():
		if String(action) == "weapon_bank":
			continue
		for event in InputMap.action_get_events(action):
			if event is InputEventKey and ((event as InputEventKey).physical_keycode == KEY_SHIFT or (event as InputEventKey).keycode == KEY_SHIFT):
				others.append(String(action))
	_check("acceptance: the bank key is Shift, which nothing else uses (no action, no fixed key: no sprint), rebindable as \"weapon bank 2\" through the settings screen, never Ctrl or Alt", shift == "key:%d" % KEY_SHIFT and others.is_empty() and not clashes.has("weapon_bank") and Controls.rebindable("weapon_bank") and Controls.bind_problem(Controls.event_of(shift)) == "", "%s %s" % [shift, others])
	var many: Arsenal = shipped.duplicate()
	var list: Array[Resource] = []
	for i in 19:
		var w: WeaponDefScript = load("res://resources/terminal_cannon.tres").duplicate()
		w.id = "w%d" % i
		list.append(w)
	many.loadout = list
	_check("two banks of nine at most: a nineteenth weapon is refused", Arsenal.usable_loadout(many).size() == 18 and ", ".join(many.problems()).contains("1 to 18"))


# --- The keys: Shift+1, 1, Q and the wheel. ---

func _key_checks() -> void:
	var main := await _lab({}, OPEN, true)
	var p = main.get_node("Player")
	var wh = main.get_node("Hud").weapon_hud()
	await _frames(20)
	await _key(KEY_1, true)
	var shift_one: int = p.inventory.current
	var strip_two: String = wh.bank2_text()
	var lit_two: int = wh.active_bank()
	await _key(KEY_1)
	var one: int = p.inventory.current
	await _key(KEY_Q)
	var q_back: int = p.inventory.current
	await _key(KEY_9)
	await _wheel(MOUSE_BUTTON_WHEEL_DOWN)
	var wheel_on: int = p.inventory.current
	await _wheel(MOUSE_BUTTON_WHEEL_DOWN)
	var wheel_wrap: int = p.inventory.current
	await _wheel(MOUSE_BUTTON_WHEEL_UP)
	var wheel_back: int = p.inventory.current
	_check("acceptance: Shift+1 draws weapon 10, chmod 000 (\"%s\" on the strip, bank 2 lit), 1 the cannon, Q swaps back to chmod 000, and the wheel reaches it from ping and goes on to the next (the cannon, the wrap; pipe | since C30; the strip's bank 2 shows /dev/null's charges, 3(2), since C31, and SIGHUP's, 4(2), since C32) and back" % strip_two, shift_one == SLOT and strip_two == "Shift+ [1 chmod] 2 3(2) 4(2)" and lit_two == 1 and one == 0 and q_back == SLOT and wheel_on == SLOT and wheel_wrap == SLOT + 1 and wheel_back == SLOT, "%d %d %d %d %d %d" % [shift_one, one, q_back, wheel_on, wheel_wrap, wheel_back])
	# The bank key held alone lights bank 2 (1 to 9 then draw its weapons); let go, the drawn weapon's.
	await _key(KEY_1)
	var held_lit: int = await _hold_shift(func(): return wh.active_bank())
	var after_lit: int = wh.active_bank()
	_check("the strip shows the active bank: the cannon drawn, bank 1 lit and bank 2 dimmed; Shift held, bank 2 lit; let go, bank 1 again", held_lit == 1 and after_lit == 0 and wh.bank_alpha(1) < 1.0 and wh.bank_alpha(0) == 1.0 and wh.bank2_text() == "Shift+ 1 2 3(2) 4(2)", "%d %d %s" % [held_lit, after_lit, wh.bank2_text()])
	await _drop(main)


# --- The strip: two rows at 960x540. ---

func _strip_checks() -> void:
	var before := root.size
	var wrong := PackedStringArray()
	var lines := PackedStringArray()
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
			feed_hud.entries.push_front({"killer": "Daemon-2", "victim": "Daemon-1", "word": "SIGTERM", "left": 2.0})
		hud.guide()._notice("word ".repeat(60), Color.WHITE, 5000)
		hud.net_hud().toggle()
		await _frames(3)
		var screen := Rect2(Vector2.ZERO, Vector2(root.size))
		var panels := [hud.net_hud().get("_panel"), hud.guide().get("_panel")]
		var strip: Control = hud.weapon_hud().get("_stack")
		var feed: Control = feed_hud.get("_feed")
		var rows: Array = hud.weapon_hud().bank_rows()
		var top: Rect2 = rows[0].get_global_rect()
		var bottom: Rect2 = rows[1].get_global_rect()
		if not (top.end.y <= bottom.position.y + 0.5 and top.end.x >= bottom.end.x - 1.0):
			wrong.append("%d: bank 2 not over bank 1 (%s / %s)" % [size.x, top, bottom])
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
		lines = PackedStringArray([hud.weapon_hud().bank2_text(), hud.weapon_hud().slots_text(), hud.weapon_hud().ammo_text(), hud.weapon_hud().state_text()])
		await _drop_side(host)
	root.size = before
	_check("acceptance: at 960x540 (and 1280x720) the strip is two rows in its own column, bank 2 over bank 1 (\"%s\" over \"%s\"), the 10 px slot line kept, and with chmod 000 drawn its coolant (\"%s\", \"%s\"): every line inside the screen, clear of a full kill feed, the net panel and a long guide notice" % [lines[0], lines[1], lines[2], lines[3]], wrong.is_empty() and lines[0] == "Shift+ [1 chmod] 2 3(2) 4(2)" and lines[1] == "1 2 3 4(2) 5 6 7 8 9" and lines[2] == "chmod  coolant 100%" and lines[3] == "coolant [##########]", ", ".join(wrong))


# --- The meter and the freeze. ---

func _meter_checks() -> void:
	# Practice: the daemon stands, so the beam's own work is all that changes it.
	var main := await _lab({"DummyA": Vector3(0.0, 0.0, 11.0)}, OPEN, true)
	var p = main.get_node("Player")
	var rogue := _dummy(main, "DummyA")
	var fh = main.get_node("Hud").freeze_hud()
	var drawn := await _draw(p)
	_face(p, rogue.global_position)
	var start_ticks: int = p.beam_ticks
	p.hold_fire = true
	await _frames(30)
	var half: float = rogue.frost.chill
	var line_half: String = fh.line_text()
	var crust_half: float = rogue.frost_look().shown() if rogue.frost_look() != null else 0.0
	var beam_on: bool = p.beaming() and p.freeze_beam().on()
	var frozen_at := await _wait(func(): return rogue.chmod_frozen(), 60)
	var ticks: int = p.beam_ticks - start_ticks
	p.hold_fire = false
	await _frames(3)
	var look = rogue.frost_look()
	var tag: String = look.tag_text() if look != null else ""
	_check("acceptance: the beam builds the freeze meter: half way through its %.1f s it stands at %.0f%% (\"%s\"), the frost creeping up the body (%.2f), the beam drawn" % [_ft.chill_s, half * 100.0, line_half, crust_half], drawn and half > 0.35 and half < 0.7 and line_half.begins_with("chmod 000  rogue.d [") and crust_half > 0.3 and beam_on, "drawn %s" % drawn)
	_check("acceptance: a full meter freezes it: frozen after %d beam ticks, its art held still, its frost whole (\"%s\")" % [ticks, tag.replace("\n", " ")], frozen_at >= 0 and ticks >= 9 and ticks <= 12 and rogue.art_node().frozen and look != null and look.shown() == 1.0 and tag.begins_with("PERMISSION DENIED") and rogue.frost.freezes == 1 and p.freezes_made == 1)
	var held_at: Vector3 = rogue.global_position
	var held_yaw: float = rogue.global_rotation.y
	await _frames(60)
	var still: bool = rogue.chmod_frozen() and rogue.global_position.distance_to(held_at) < EPS and absf(rogue.global_rotation.y - held_yaw) < EPS
	var thawed := await _wait(func(): return not rogue.chmod_frozen(), int(_ft.freeze_s * 60.0) + 10)
	var guarded: bool = rogue.frost.guard_left > 0.0
	p.hold_fire = true
	await _frames(20)
	var guard_line: String = fh.line_text()
	var no_build: bool = rogue.frost.chill == 0.0 and not rogue.chmod_frozen()
	p.hold_fire = false
	_check("frozen it holds (no step, no turn) for its %.0f s, then thaws behind a %.1f s guard in which the beam builds nothing (\"%s\")" % [_ft.freeze_s, _ft.thaw_guard_s, guard_line], still and thawed >= 0 and guarded and no_build and guard_line.begins_with("chmod: thawing"))
	await _drop(main)


func _tell_checks() -> void:
	var main := await _lab({"DummyA": Vector3(0.0, 0.0, 9.0)}, OPEN, false)
	var p = main.get_node("Player")
	var rogue := _dummy(main, "DummyA")
	var life := _life(main)
	await _unprotect(main)
	var drawn := await _draw(p)
	_face(p, rogue.global_position)
	# Pre-chilled, so the beam's last ticks land in the middle of the tell.
	rogue.frost.chill = 0.75
	rogue.frost.hold_left = 10.0
	var telling := await _wait(func(): return rogue.brain.state == DaemonBrain.State.TELL and rogue.brain.state_t > 0.05, 900)
	var attacks: int = rogue.brain.attacks
	var health: float = life.health()
	_face(p, rogue.global_position)
	p.hold_fire = true
	var frozen := await _wait(func(): return rogue.chmod_frozen(), 40)
	p.hold_fire = false
	var no_strike := true
	var held_at: Vector3 = rogue.global_position
	var held_yaw: float = rogue.global_rotation.y
	var still := true
	for i in 90:
		await physics_frame
		no_strike = no_strike and rogue.brain.attacks == attacks and rogue.brain.state != DaemonBrain.State.STRIKE and rogue.brain.state != DaemonBrain.State.TELL
		if rogue.chmod_frozen():
			still = still and rogue.global_position.distance_to(held_at) < EPS and absf(rogue.global_rotation.y - held_yaw) < EPS
	_check("acceptance: a freeze calls off the tell it lands in: rogue.d rearing is frozen, nothing is thrown (no strike, the player's health %.0f untouched), its slot let go, \"frozen\" noted; frozen in play it neither moves nor turns" % life.health(), drawn and telling >= 0 and frozen >= 0 and no_strike and still and life.health() == health and rogue.brain.frozen_offs == 1 and not rogue.brain.holds_slot and _events(rogue.brain).contains("frozen"), "telling %d frozen %d still %s; %s" % [telling, frozen, still, _events(rogue.brain)])
	var back := await _wait(func(): return rogue.brain.state == DaemonBrain.State.TELL, int((_ft.freeze_s + 6.0) * 60.0))
	_check("it fights again once thawed (after its attack's own wait)", back >= int(_ft.freeze_s * 60.0) - 120)
	await _drop(main)


# --- Hits on the frozen: harder, a shatter. ---

func _shatter_checks() -> void:
	var main := await _lab({"DummyA": Vector3(0.0, 0.0, 9.0), "DummyB": Vector3(-6.0, 0.0, 9.0), "DummyC": Vector3(6.0, 0.0, 9.0)}, OPEN, true)
	var fx := ParticleFx.of(main)
	var rogue := _dummy(main, "DummyA")
	var tough := _dummy(main, "DummyB")
	var other := _dummy(main, "DummyC")
	# A plain daemon (1 health): any kill of it frozen is a shatter, in the frost.
	rogue.chill(5.0)
	var chips: int = fx.fired(ParticleFx.Kind.FROST)
	rogue.hit(25.0, rogue.threat_point(), Vector3.FORWARD, "terminal_cannon")
	_check("acceptance: every kill of a frozen daemon is a shatter: the cannon's hit derezzes it in the frost opal in a storm of frost", not rogue.is_alive() and rogue.shatters == 1 and fx.fired(ParticleFx.Kind.FROST) > chips)
	# A tough one (200 health, as an elite's 30 would hide the numbers): the next hit frozen lands 2x and
	# thaws it; a strong hit frozen shatters it whatever its health.
	_toughen(tough, 200.0)
	tough.chill(5.0)
	var was_frozen: bool = tough.chmod_frozen()
	tough.hit(25.0, tough.threat_point(), Vector3.FORWARD, "terminal_cannon")
	var after_bonus: float = tough.health()
	var thawed: bool = not tough.chmod_frozen()
	tough.hit(25.0, tough.threat_point(), Vector3.FORWARD, "terminal_cannon")
	var after_plain: float = tough.health()
	_check("acceptance: the next hit on a frozen daemon lands %.0fx and thaws it (25 took %.0f), the one after it plain (25)" % [_ft.frozen_hit_scale, 200.0 - after_bonus], was_frozen and absf(after_bonus - 150.0) < EPS and thawed and absf(after_plain - 125.0) < EPS)
	_toughen(other, 200.0)
	other.chill(5.0)
	other.hit(_ft.shatter_damage, other.threat_point(), Vector3.FORWARD, "rm_rf_cannon")
	var unfrozen_tough: float = tough.health()
	tough.hit(_ft.shatter_damage, tough.threat_point(), Vector3.FORWARD, "rm_rf_cannon")
	_check("acceptance: a strong hit (%.0f or more) on a frozen daemon shatters it outright whatever its health (200); the same hit on it unfrozen only takes its damage" % _ft.shatter_damage, not other.is_alive() and other.shatters == 1 and tough.is_alive() and absf(tough.health() - (unfrozen_tough - _ft.shatter_damage)) < EPS)
	await _drop(main)


# --- The coolant. ---

func _coolant_checks() -> void:
	var main := await _lab({}, OPEN, true)
	var p = main.get_node("Player")
	var wh = main.get_node("Hud").weapon_hud()
	await _draw(p)
	var tank: Coolant = p.inventory.coolant(SLOT)
	p.hold_fire = true
	var dry := await _wait(func(): return tank.venting, int(_ft.coolant_s * 60.0) + 60)
	var ticks_at_dry: int = p.beam_ticks
	await _frames(30)
	var stopped: bool = p.beam_ticks == ticks_at_dry and p.inventory.fire_block() == "coolant" and not p.beaming()
	var vent_ammo: String = wh.ammo_text()
	var vent_state: String = wh.state_text()
	p.hold_fire = false
	var back := await _wait(func(): return not tank.venting, int((_ft.coolant_rest_s + _ft.coolant_refill_s) * 60.0) + 30)
	var share_back := tank.share()
	_check("acceptance: its ammo is coolant: held, the beam drains the tank in %.0f s (%d ticks), runs dry and vents (\"%s\", \"%s\"): no beam until it has refilled to %d%% (%.2f), then it runs again" % [_ft.coolant_s, ticks_at_dry, vent_ammo, vent_state, roundi(_ft.vent_share * 100.0), share_back], dry >= int(_ft.coolant_s * 60.0) - 12 and stopped and vent_ammo == "chmod  VENTING" and vent_state.begins_with("venting [") and back >= 0 and absf(share_back - _ft.vent_share) < 0.05, "dry after %d frames" % dry)
	var full := await _wait(func(): return tank.share() >= 1.0, int(_ft.coolant_refill_s * 60.0) + 30)
	_check("left alone the tank refills to full", full >= 0)
	await _drop(main)


# --- Black ICE: only slowed. ---

func _black_checks() -> void:
	var main := await _lab({}, Vector3(0.0, 0.95, 15.0), false, true)
	var ice := _ice(main)
	var p = main.get_node("Player")
	var life := _life(main)
	await _draw(p)
	ice.start_round(4)
	var b := ice.summon_black(3)
	b.phase_t = b.tuning.tell_s
	b.step(0.0, ice.daemons)
	# Spawn protection held up while the beam works: its touch never fires through it.
	life.combat.states[1]["protect_left"] = 1000.0
	p.global_position = b.global_position + Vector3(0.0, 0.95, 9.0)
	_face(p, b.global_position + Vector3(0.0, 0.95, 0.0))
	var seals: int = b.seals_left
	var flashes: int = b.flashes
	var health: float = b.health()
	var fh = main.get_node("Hud").freeze_hud()
	p.hold_fire = true
	var most := 0.0
	var line := ""
	for i in 90:
		await physics_frame
		_face(p, b.global_position + Vector3(0.0, 0.95, 0.0))
		most = maxf(most, b.slow)
		if fh.line_text() != "":
			line = fh.line_text()
	var speed_now: float = b.brain._speed(ice.daemons)
	var never_frozen: bool = not b.chmod_frozen() and b.phase == BlackIce.Phase.OUT
	p.hold_fire = false
	_check("acceptance: Black ICE is only slowed: up to %d%% while the beam holds (%.2f; its pace %.2f of %.1f m/s), never frozen, never hurt or flashed, its seals untouched (\"%s\")" % [roundi(_ft.black_slow * 100.0), most, speed_now, b.tuning.speed, line], b.beamed_s > 1.0 and absf(most - _ft.black_slow) < EPS and most <= FreezeTuning.BLACK_SLOW_LAST and absf(speed_now - b.tuning.speed * (1.0 - _ft.black_slow)) < 0.01 and never_frozen and b.seals_left == seals and b.flashes == flashes and b.health() == health and line.begins_with("chmod: Operation not permitted"))
	var worn := await _wait(func(): return b.slow == 0.0, int((_ft.chill_hold_s + _ft.black_slow_out_s) * 60.0) + 20)
	_check("the slow wears off once the beam leaves it", worn >= 0)
	# Beamed at its full slow, its touch is still a flatline.
	p.hold_fire = true
	await _frames(40)
	life.combat.states[1]["protect_left"] = 0.0
	p.global_position = b.global_position + Vector3(0.9, 0.95, 0.0)
	var flat := await _wait(func(): return not life.alive(), 30)
	p.hold_fire = false
	_check("acceptance: and its touch is never stopped: slowed and beamed, touching it still flatlines (the I3 rules whole)", flat >= 0 and life.flatlined_now and b.slow > 0.0)
	await _drop(main)


# --- Walls ignore it; the hunter freezes; a node's field is paused. ---

func _wall_checks() -> void:
	var main := await _lab({}, Vector3(-17.6, 0.95, 14.0), false, true)
	var ice := _ice(main)
	var p = main.get_node("Player")
	var fh = main.get_node("Hud").freeze_hud()
	await _draw(p)
	var wall := ice.wall("wall")
	_face(p, wall.global_position + Vector3(0.0, 0.95, 0.0))
	var health: float = wall.health()
	p.hold_fire = true
	var line := ""
	for i in 60:
		await physics_frame
		if fh.line_text() != "":
			line = fh.line_text()
	p.hold_fire = false
	_check("acceptance: walls ignore it: a wall of white ICE beamed for a second has no meter, no frost, no damage (\"%s\")" % line, wall.frost == null and wall.frost_look() == null and wall.health() == health and not wall.chmod_frozen() and line == "chmod: read-only file system", str(p.beam_target))
	await _drop(main)


func _hunter_checks() -> void:
	var main := await _lab({}, Vector3(10.0, 0.95, 6.0), false, true)
	var ice := _ice(main)
	var p = main.get_node("Player")
	var life := _life(main)
	await _draw(p)
	ice.start_round(2)
	var hunter := ice.hunter
	life.combat.states[1]["protect_left"] = 1000.0
	p.hold_fire = true
	var frozen := -1
	for i in int(_ft.ice_chill_s * 60.0) + 60:
		_face(p, hunter.global_position)
		if hunter.chmod_frozen():
			frozen = i
			break
		await physics_frame
	p.hold_fire = false
	var held_at := hunter.global_position
	await _frames(40)
	var still: bool = hunter.chmod_frozen() and hunter.global_position.distance_to(held_at) < EPS and hunter.brain.state != DaemonBrain.State.TELL
	var before := hunter.health()
	hunter.hit(1000.0, Vector3.INF, Vector3.ZERO, "sigkill_rail")
	var took := before - hunter.health()
	_check("acceptance: it freezes the hunter like a daemon (ICE's %.1f s of beam), held still with its lance quiet, and the next hit lands %.0fx after its cap (the rail's 1000: %.0f) and thaws it" % [_ft.ice_chill_s, _ft.frozen_hit_scale, took], frozen >= 0 and still and absf(took - ice.tuning.hit_cap * _ft.frozen_hit_scale) < EPS and not hunter.chmod_frozen() and hunter.frost != null and hunter.frost.broken_by_hits == 1)
	# Its lance's tell, frozen in the middle, is called off (the player open to it again).
	if hunter.frost != null:
		hunter.frost.clear()
	hunter.art.frozen = false
	life.combat.states[1]["protect_left"] = 0.0
	var telling := await _wait(func(): return hunter.brain.state == DaemonBrain.State.TELL, 900)
	var lances: int = hunter.brain.lances
	hunter.chill(5.0)
	await _frames(int(hunter.tuning.hunter_tell_s * 60.0) + 20)
	_check("a freeze calls off the hunter's lance in its tell: no lance thrown", telling >= 0 and hunter.brain.lances == lances and hunter.brain.frozen_offs == 1)
	await _drop(main)


func _node_checks() -> void:
	var main := await _lab({}, Vector3(-4.5, 0.95, 2.5), false, true)
	var ice := _ice(main)
	var life := _life(main)
	await _unprotect(main)
	var node := ice.node_of("jam")
	var telling := await _wait(func(): return node.state == IceNode.State.TELL, 900)
	var fires: int = node.fires
	node.chill(5.0)
	var paused: bool = node.chmod_frozen() and node.state == IceNode.State.COOLDOWN
	var t_at: float = node.state_t
	await _frames(int(node.tell_s() * 60.0) + 20)
	var held: bool = node.fires == fires and node.state == IceNode.State.COOLDOWN and absf(node.state_t - t_at) < EPS
	_check("acceptance: it pauses a node's field like a daemon: the jam node's tell called off into its cooldown, no field fired, its clock held while frozen", telling >= 0 and paused and held and node.events.map(func(e): return e[1]).has("frozen") and life.alive())
	var thawed := await _wait(func(): return not node.chmod_frozen(), int(_ft.ice_freeze_s * 60.0) + 20)
	_check("it thaws in ICE's %.1f s and waits out its cooldown before it looks again" % _ft.ice_freeze_s, thawed >= 0 and node.state == IceNode.State.COOLDOWN)
	await _drop(main)


# --- Practice. ---

func _practice_checks() -> void:
	var main := await _lab({"DummyB": Vector3(0.0, 0.0, 10.0)}, OPEN, true)
	var p = main.get_node("Player")
	var zombie := _dummy(main, "DummyB")
	await _draw(p)
	_face(p, zombie.global_position)
	p.hold_fire = true
	var frozen := await _wait(func(): return zombie.chmod_frozen(), 120)
	p.hold_fire = false
	_check("acceptance: practice still freezes the dummies (the old zombie frozen in place), and nothing fights", frozen >= 0 and zombie.brain.attacks == 0 and zombie.brain.tells == 0)
	await _drop(main)


# --- I1's known issue, fixed on the way: ping reveals ICE, grep locks it. ---

func _ice_marks_checks() -> void:
	var main := await _lab({}, Vector3(4.0, 0.95, 4.0), false, true)
	var ice := _ice(main)
	var p = main.get_node("Player")
	ice.start_round(2)
	await _frames(2)
	var hunter := ice.hunter
	var node := ice.node_of("jam")
	var wall := ice.wall("gate")
	var marked: Array = p.grep.enemies()
	var ping: WeaponDefScript = load("res://resources/ping_sonar.tres")
	var pulse = load("res://scripts/weapons/ping_pulse.gd").spawn(main, ping, p.global_position, p.global_position.y - 0.9, true, true)
	await _frames(int(ping.ping_ring_s * 60.0) + 5)
	var hunter_lit: bool = PingReveal.find(hunter.art) != null and PingReveal.find(hunter.art).lit()
	var node_lit: bool = PingReveal.find(node.art) != null and PingReveal.find(node.art).lit()
	var wall_lit: bool = PingReveal.find(wall.art) != null
	_check("I1's known issue fixed on the way: ping outlines the hunter and the nodes through the level as it does a daemon (the walls stand in plain sight), and grep may lock the hunter and the nodes (never a wall or Black ICE), aiming at their middles", pulse != null and hunter_lit and node_lit and not wall_lit and marked.has(hunter) and marked.has(node) and not marked.has(wall) and GrepLock.point_of(hunter).distance_to(hunter.global_position + Vector3.UP * hunter.tuning.hunter_hover_m) < EPS, "hunter %s node %s wall %s; marks %d" % [hunter_lit, node_lit, wall_lit, marked.size()])
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
	var rpcs := _code("res://scripts/net/net_session.gd").count("@rpc(")
	_check("acceptance: the wire: protocol 15 (14 at I3; 16 since C30's pipe |, 17 since C31's /dev/null, 18 since C32's SIGHUP), no new message (28 RPCs as I2 left them): a beam tick is the usual fire intent, and the meters ride words already sent", joined and Session.PROTOCOL == 18 and rpcs == 28, "%d RPCs" % rpcs)
	var hp = host["player"]
	var cp = client["player"]
	for name in ["DummyA", "DummyB", "DummyC", "DummyD"]:
		_park(_dummy(host["main"], name))
	# The joiner beams the host's rogue.d: the host judges, the joiner's copy shows the host's word.
	hp.global_position = host["main"].to_global(Vector3(15.0, 0.95, -15.0))
	cp.global_position = client["main"].to_global(OPEN)
	cp.select_slot(SLOT)
	var drawn := await _wait(func(): return hs.combat.drawn_by(cid) == "chmod_000", 120)
	await _frames(30)
	hs.combat.states[cid]["protect_left"] = 0.0
	var rogue := _dummy(host["main"], "DummyA")
	var copy := _dummy(client["main"], "DummyA")
	_place(rogue, host["main"].to_global(Vector3(0.0, 0.0, 10.0)))
	_face(cp, client["main"].to_global(Vector3(0.0, 0.95, 10.0)))
	cp.hold_fire = true
	var frozen := await _wait(func(): return rogue.chmod_frozen(), 150)
	var copy_frozen := await _wait(func(): return copy.chmod_frozen() and copy.frost_look() != null and copy.frost_look().shown() == 1.0, 60)
	cp.hold_fire = false
	_check("acceptance: in a match the host judges every freeze: the joiner's beam freezes the host's rogue.d (%d ticks judged), and the joiner's copy is frozen and frosted on the host's word" % hs.beam_ticks_judged, joined and drawn >= 0 and frozen >= 0 and copy_frozen >= 0 and hs.beam_ticks_judged >= 9 and hs.freezes_judged >= 1)
	await _frames(int(_ft.freeze_s * 60.0) + 120)
	# The joiner beams the host's player: slowed, then frozen briefly; its shots refused while frozen.
	_park(rogue)
	hp.global_position = host["main"].to_global(Vector3(0.0, 0.95, 9.0))
	cp.global_position = client["main"].to_global(OPEN)
	hs.combat.states[1]["protect_left"] = 0.0
	await _frames(10)
	_face(cp, client["main"].to_global(Vector3(0.0, 1.0, 9.0)))
	var slowest := 1.0
	cp.hold_fire = true
	var host_frozen := -1
	for i in int(_ft.player_chill_s * 60.0) + 90:
		if hp.frozen_now():
			host_frozen = i
			break
		slowest = minf(slowest, hp.move_scale())
		await physics_frame
	cp.hold_fire = false
	var avatar = cs.avatars.get(1)
	var seen := await _wait(func(): return avatar != null and avatar.frost_look() != null and avatar.frost.frozen(), 30)
	var frozen_drops: int = hs.combat.drops.get("frozen", 0)
	var held_slot: int = hp.inventory.current
	var swapped: bool = hp.select_slot(1 if held_slot != 1 else 2) or hp.inventory.current != held_slot
	hs._on_fire_intent(hp.eye_position(), Vector3.FORWARD, hp.weapon_tuning().id)
	var refused: bool = hs.combat.drops.get("frozen", 0) > frozen_drops
	var thaw := await _wait(func(): return not hp.frozen_now(), int(_ft.player_freeze_s * 60.0) + 30)
	_check("acceptance: against players it slows (down to %.2f of the pace) and then freezes briefly (%.1f s, thawed after %d frames): the host frozen by the joiner's beam, drawn frosted on the joiner's screen; frozen it cannot draw, and its shot is refused (frozen)" % [slowest, _ft.player_freeze_s, thaw], slowest < 0.75 and slowest >= 1.0 - _ft.player_slow - EPS and host_frozen >= 0 and seen >= 0 and not swapped and refused and thaw >= 0 and thaw <= int(_ft.player_freeze_s * 60.0) + 30, "frozen %d seen %d swapped %s refused %s" % [host_frozen, seen, swapped, refused])
	var guarded: bool = hs.combat.frost_of(1).guard_left > 0.0
	_check("a thawed player is guarded %.1f s: no chain of freezes" % _ft.player_guard_s, guarded and not hs.combat.chill_player(1, 5.0))
	# The host beams the joiner: the joiner's own meter comes back to it from the host.
	hs.combat.frost_of(1).clear()
	hs.combat.states[cid]["protect_left"] = 0.0
	hp.global_position = host["main"].to_global(OPEN)
	cp.global_position = client["main"].to_global(Vector3(0.0, 0.95, 9.0))
	await _frames(10)
	hp.select_slot(SLOT)
	await _wait(func(): return hs.combat.drawn_by(1) == "chmod_000" and hp.inventory.fire_block() == "", 120)
	_face(hp, host["main"].to_global(Vector3(0.0, 1.0, 9.0)))
	hp.hold_fire = true
	var joiner_frozen := await _wait(func(): return cp.frozen_now(), 150)
	hp.hold_fire = false
	# The HUD redraws in its own frame: read it once it has (C30's final gate caught this read racing it).
	await _wait(func(): return client["hud"].freeze_hud().frozen_text().size() == 2, 10)
	var hud_lines: PackedStringArray = client["hud"].freeze_hud().frozen_text()
	var asks_refused: int = hs.breaker_refused
	cs._breaker.rpc_id(1, cs.lives.get(cid, 0), 0, Vector3.FORWARD)
	var no_breaker := await _wait(func(): return hs.breaker_refused > asks_refused, 30)
	_check("acceptance: the host's beam freezes the joiner, its own meter told back to it by the host: the joiner's screen frozen (\"%s\"), and its breaker ask refused while it is" % " / ".join(hud_lines), joiner_frozen >= 0 and hud_lines.size() == 2 and hud_lines[0] == "chmod 000: Permission denied" and client["hud"].freeze_hud().wash() > 0.5 and no_breaker >= 0, "frozen at %d, joiner frozen now %s, wash %.2f, breaker refused %d" % [joiner_frozen, cp.frozen_now(), client["hud"].freeze_hud().wash(), no_breaker])
	await _frames(int(_ft.player_freeze_s * 60.0) + int(_ft.player_guard_s * 60.0) + 30)
	# Spawn protection holds.
	hs.combat.states[cid]["protect_left"] = 10.0
	hp.hold_fire = true
	await _frames(60)
	hp.hold_fire = false
	_check("acceptance: spawn protection holds: a protected joiner beamed for a second gains no meter", hs.combat.frost_of(cid).chill == 0.0 and not hs.combat.frozen(cid))
	# A venting tank's tick is refused, whatever the joiner's screen says.
	var tank: Coolant = hs.combat.coolant_of(cid)
	cp.select_slot(SLOT)
	await _wait(func(): return hs.combat.drawn_by(cid) == "chmod_000", 120)
	await _frames(30)
	tank.meter = 0.0
	tank.venting = true
	var coolant_drops: int = hs.combat.drops.get("coolant", 0)
	cs._on_fire_intent(cp.eye_position(), Vector3.FORWARD, "chmod_000")
	var dropped := await _wait(func(): return hs.combat.drops.get("coolant", 0) > coolant_drops, 60)
	_check("acceptance: the host owns the coolant: a joiner's tick from a venting tank is refused (coolant)", dropped >= 0)
	await _drop_side(client)
	await _drop_side(host)
	GameSettings.current().set_value("gameplay", "ice", true)


# --- Helpers. ---

## Draws chmod 000 on `p` and waits out the swap; true when it is in hand and ready.
func _draw(p: Node) -> bool:
	p.select_slot(SLOT)
	await _frames(30)
	return p.weapon_tuning().id == "chmod_000" and p.inventory.fire_block() == ""


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


func _unprotect(main: Node) -> void:
	var life := _life(main)
	await _wait(func(): return life == null or not life.protected(), 300)


## Turns the player to face `point` (level).
func _face(player: Node3D, point: Vector3) -> void:
	var way: Vector3 = point - player.global_position
	player.rotation.y = atan2(-way.x, -way.z)


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


func _events(brain: DaemonBrain) -> String:
	return ", ".join(brain.events.slice(-8).map(func(e): return "%.2f %s" % [e[0], e[1]]))


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


## The bank key held while `read` is called a few frames in, then let go; what `read` gave.
func _hold_shift(read: Callable) -> Variant:
	_send_key(KEY_SHIFT, true, false)
	await process_frame
	await process_frame
	var out = read.call()
	_send_key(KEY_SHIFT, false, false)
	await process_frame
	await process_frame
	return out


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


## The text of function `name` in `source`, up to the next function.
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


## A script's code without its comments or the text of its strings.
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
		out.append(line.left(cut))
	return "\n".join(out)
