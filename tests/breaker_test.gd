extends SceneTree
## Headless test of I2's ICEbreakers for SIGKILL. scripts/check.sh runs it as step 41, and any FAIL
## exits 1.
##
##   godot --headless --path . --fixed-fps 60 --script res://tests/breaker_test.gd
##
## The sources: protocol 13 with two new messages (a joiner's ask, the host's breaker word), the host
## judging; the tuning; U and Y free and bound (the brief's H is the multiplayer panel's own). The colour: the breakers' ultraviolet reads apart (OKLab)
## from every bright colour of the palette. The art: the same seed builds the same pickup and decoy, other
## seeds build others, inside their budgets. Alone, in the real arena with ICE on: a round's counts, the
## cap, Y loading the next kind it holds, U spending the loaded one (none left: nothing), a pickup taken
## by walking over it (not at the cap) and laid on its schedule; the brute breaking a wall up close and
## nearly breaking one from further, a hard hit on a node and on the hunter (never a one-shot, never
## adapted to), a daemon in its cone; exploit's bonus only on weak seams, only for direct hits and only
## for its time, its seams marked; cloak hiding the player from a node, the hunter and a daemon, firing
## ending it and its time ending it; the decoy pulling the hunter (its lance on the decoy, the player
## untouched) and a node's field (the decoy takes it, the player is not jammed) until its call ends. The
## readout and the effect lines, and their layout at 960x540 and 1280x720. The pick: the round numbers
## alone go to the AI (a stub adapter, never a real call), on T and at the round's end, and the scripted
## guide picks when the AI is off. Practice turns breakers off; the ICE switch does not. Then a host and a
## joiner over ENet on 127.0.0.1: the joiner's breakers are the host's word, its asks are judged by the
## host (refused with none left), its cloak ends on its own shot, its decoy and its brute land in the
## host's world and show on its screen. Deterministic: frames counted, only counts and outcomes printed.

const Session = preload("res://scripts/net/net_session.gd")
const NetTuningScript = preload("res://scripts/net/net_tuning.gd")
const Link = preload("res://scripts/guide/guide_link.gd")
const MainScene = preload("res://scenes/main.tscn")
const Dummy = preload("res://scripts/target_dummy.gd")
const Controls = preload("res://scripts/controls.gd")
const Palette = preload("res://scripts/palette.gd")
const Kinds = preload("res://scripts/ice/breakers.gd")
const Pick = preload("res://scripts/ice/breaker_pick.gd")
const Request = preload("res://scripts/ai/guide_request.gd")
const Fakes = preload("res://tests/support/guide_fakes.gd")
const Found = preload("res://scripts/ai/ai_source_result.gd")
const Detector = preload("res://scripts/ai/ai_source_detector.gd")
const Settings = preload("res://scripts/boot/guide_settings.gd")
const BreakerArt = preload("res://scripts/ice/breaker_art.gd")
const WATCHDOG_MS := 12000
const CLIENT_OFFSET := Vector3(1000.0, 0.0, 0.0)
const PARKED := Vector3(0.0, -50.0, 0.0)
## The least OKLab distance the breakers' colour keeps from every bright colour of the palette.
const APART := 0.12
## Builds sampled for the seeds' variety.
const BUILDS := 10
const B := Kinds.Kind.BRUTE
const E := Kinds.Kind.EXPLOIT
const C := Kinds.Kind.CLOAK
const D := Kinds.Kind.DECOY

var _fails := 0
var _checks := 0
var _tmp := ""
var _arenas: Array = []
var _branches: Array = []
var _bt: BreakerTuning
var _t: IceTuning
var _fake_now := 1000000


func _initialize() -> void:
	_run()


func _run() -> void:
	await process_frame
	root.size = Vector2i(1280, 720)
	_tmp = OS.get_temp_dir().path_join("sigkill-breaker-test-%d" % OS.get_process_id())
	if DirAccess.dir_exists_absolute(_tmp):
		print("FAIL the test's temporary folder already exists; not touching it")
		quit(1)
		return
	DirAccess.make_dir_recursive_absolute(_tmp)
	Controls.ensure()
	GameSettings.current().reset()
	_bt = load("res://resources/breakers.tres") as BreakerTuning
	_t = load("res://resources/ice.tres") as IceTuning
	_source_checks()
	_palette_checks()
	await _art_checks()
	await _carry_checks()
	await _brute_checks()
	await _exploit_checks()
	await _cloak_checks()
	await _decoy_checks()
	await _hud_checks()
	await _pick_checks()
	await _off_checks()
	await _match_checks()
	await _cleanup()
	for name in DirAccess.get_files_at(_tmp):
		DirAccess.remove_absolute(_tmp.path_join(name))
	DirAccess.remove_absolute(_tmp)
	print("ICEBREAKERS: %d checks" % _checks)
	print("ICEBREAKERS RESULT: ", "ALL PASS" if _fails == 0 else "%d FAILED" % _fails)
	quit(0 if _fails == 0 else 1)


func _check(label: String, ok: bool, detail: String = "") -> void:
	_checks += 1
	print("PASS " if ok else "FAIL ", label, ("   " + detail) if detail != "" else "")
	if not ok:
		_fails += 1


# --- The sources, the tuning and the keys. ---

func _source_checks() -> void:
	var session := _code("res://scripts/net/net_session.gd")
	var ask := _body(session, "_breaker")
	var judge := _body(session, "_handle_breaker")
	var word := _body(session, "_breakers")
	_check("acceptance: in a match the host judges every breaker: a joiner's run key is only an ask (its kind and aim) that the host checks and runs from where it last heard the joiner's eye, and the host's word (each joiner's own counts, exploit and cloak, the decoys, the pickups, the last brute charge) is all a joiner shows; an accepted shot or throw ends the shooter's cloak there; protocol 13", Session.PROTOCOL == 13 and ask.contains("_handle_breaker(") and judge.contains("breakers.handle_intent(id, kind, _arena.to_global(eye)") and word.contains("breakers.take_word(") and _body(session, "_handle_fire").contains("breakers.fired(shooter)") and _body(session, "_handle_throw").contains("breakers.fired(id)") and _body(session, "breaker_intent").contains("_breaker.rpc_id(1,"))
	var problems := _bt.problems() if _bt != null else PackedStringArray(["no tuning"])
	var bad := _bt.duplicate() as BreakerTuning
	bad.start_count = 3
	bad.cloak_warn_s = bad.cloak_s
	_check("the tuning (resources/breakers.tres) is sound (start %d of each, cap %d), and refuses a start past the cap or a cloak warning as long as the cloak" % [_bt.start_count, _bt.carry_cap], problems.is_empty() and bad.problems().size() == 2 and _bt.start_count == 1 and _bt.carry_cap == 2, str(problems))
	var ice := _code("res://scripts/ice/ice_director.gd")
	_check("the I1 hooks carry it: the brute's source is ICE's brute hook (past the hit cap, a wall taking brute_wall_scale times it), exploit's bonus lands after the cap, a breaker's hit is never noted for the hunter's adaptation, and every hit still carries its source", _body(ice, "take").contains("source == BRUTE") and _body(ice, "take").contains("brute_wall_scale") and _body(ice, "take").contains("minf(damage, tuning.hit_cap) * clampf(bonus") and _body(ice, "note_damage").contains("Breakers.is_source(source)") and _code("res://scripts/ice/ice_piece.gd").contains("director.exploit_scale(shooter, self, point, source)") and _body(_code("res://scripts/target_dummy.gd"), "hit").contains("breakers.exploit_scale("))
	Controls.ensure()
	var run := Controls.default_bind("run_breaker")
	var cycle := Controls.default_bind("cycle_breaker")
	var clashes := Controls.conflicts({})
	_check("acceptance: U runs the loaded breaker (the brief's H is the multiplayer panel's own key, kept from every action since C13) and Y loads the next: both free in the input map (no other action or fixed key on them), rebindable, neither a Ctrl, Alt or Super key", run == "key:%d" % KEY_U and cycle == "key:%d" % KEY_Y and not clashes.has("run_breaker") and not clashes.has("cycle_breaker") and Controls.rebindable("run_breaker") and Controls.rebindable("cycle_breaker"), "%s %s %s" % [run, cycle, clashes])


func _palette_checks() -> void:
	var src := FileAccess.get_file_as_string("res://scripts/palette.gd")
	var rx := RegEx.create_from_string("const ([A-Z_]+) := Color\\(")
	var consts: Dictionary = (Palette as Script).get_script_constant_map()
	var least := INF
	var near := ""
	for m in rx.search_all(src):
		var key := m.get_string(1)
		if key.begins_with("BREAKER"):
			continue
		var c: Color = consts[key]
		if maxf(c.r, maxf(c.g, c.b)) <= 0.5:
			continue  # the dark bases, armour and glass: nothing bright to confuse it with
		var dist := _oklab(Palette.BREAKER).distance_to(_oklab(c))
		if dist < least:
			least = dist
			near = key
	var text_l := _oklab(Palette.BREAKER_TEXT).x
	_check("acceptance: the breakers' own colour, ultraviolet #%s, reads apart: at least %.2f (OKLab) from every bright colour of the palette (the player's teal, every weapon's, the daemons', ICE's glacier and cobalt, the crosshair's); its HUD text #%s legible on black" % [Palette.BREAKER.to_html(false), APART, Palette.BREAKER_TEXT.to_html(false)], least >= APART and Palette.BREAKER.to_html(false) == "7400cc" and text_l >= 0.7, "nearest %s %.3f; text lightness %.2f" % [near, least, text_l])


static func _oklab(c: Color) -> Vector3:
	var lin := func(x: float) -> float: return x / 12.92 if x <= 0.04045 else pow((x + 0.055) / 1.055, 2.4)
	var r: float = lin.call(c.r)
	var g: float = lin.call(c.g)
	var b: float = lin.call(c.b)
	var l := pow(0.4122214708 * r + 0.5363325363 * g + 0.0514459929 * b, 1.0 / 3.0)
	var m := pow(0.2119034982 * r + 0.6806995451 * g + 0.1073969566 * b, 1.0 / 3.0)
	var s := pow(0.0883024619 * r + 0.2817188376 * g + 0.6299787005 * b, 1.0 / 3.0)
	return Vector3(0.2104542553 * l + 0.7936177850 * m - 0.0040720468 * s, 1.9779984951 * l - 2.4285922050 * m + 0.4505937099 * s, 0.0259040371 * l + 0.7827717662 * m - 0.8086757660 * s)


# --- The art. ---

func _art_checks() -> void:
	var world := Node3D.new()
	root.add_child(world)
	var same := PackedStringArray()
	var kinds := {}
	var over := PackedStringArray()
	var looks_ok := true
	for type in [["pickup", B], ["pickup", E], ["pickup", C], ["pickup", D], ["decoy", 0]]:
		var a := _art(world, type, 7001, Vector3(-20.0, 0.0, 0.0))
		var b := _art(world, type, 7001, Vector3(20.0, 0.0, 0.0))
		if type[0] == "pickup":
			for node in a.sets():
				node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF  # as BreakerPickup lays it
		await _frames(20)
		var alike := a.part_count() == b.part_count() and is_equal_approx(a.size_scale, b.size_scale)
		if alike:
			for id in a.part_count():
				alike = alike and a.part_transform(id).is_equal_approx(b.part_transform(id)) and a.part_custom(id).is_equal_approx(b.part_custom(id))
		var label := "%s:%s" % [type[0], Kinds.name_of(type[1]) if type[0] == "pickup" else ""]
		if not alike:
			same.append(label)
		if a.triangles() > a.budget_triangles or a.draw_calls() > a.budget_draw_calls:
			over.append("%s %d/%d tris %d/%d calls" % [label, a.triangles(), a.budget_triangles, a.draw_calls(), a.budget_draw_calls])
		# Solid armour and light only: no obsidian shell's wire, no box voxels.
		var armour := false
		var light := false
		for i in a.sets().size():
			var look := a.set_look(i)
			armour = armour or look == DaemonArt.Look.ARMOR
			light = light or look == DaemonArt.Look.CORE
			looks_ok = looks_ok and look != DaemonArt.Look.SHELL and a.set_shape(i) != DaemonArt.Shape.CUBE
		looks_ok = looks_ok and armour and light
		a.queue_free()
		b.queue_free()
		var builds := {}
		for k in BUILDS:
			var art := _art(world, type, 300 + k * 7919, Vector3(0.0, 0.0, 40.0))
			await _frames(1)
			builds[_signature(art)] = true
			art.queue_free()
		kinds[label] = builds.size()
	world.queue_free()
	await _frames(2)
	var varied := true
	for k in kinds:
		varied = varied and kinds[k] >= BUILDS - 2
	print("ICEBREAKERS seeds: distinct builds of %d seeds each: %s" % [BUILDS, kinds])
	_check("acceptance: the pickups (each kind's emblem) and the decoy are solid forms in the A5/I1 rig: armour with light in its seams and cores (no wire, no boxes), inside their budgets; the same seed builds the same one, part for part, and %d other seeds at least %d different ones" % [BUILDS, BUILDS - 2], same.is_empty() and varied and over.is_empty() and looks_ok, "differs: %s; over: %s; %s" % [same, over, kinds])


func _art(world: Node3D, type: Array, seed: int, at: Vector3) -> DaemonArt:
	var art: DaemonArt = BreakerArt.new()
	art.form = type[0]
	art.kind = type[1]
	art.setup(null, seed)
	world.add_child(art)
	art.position = at
	return art


func _signature(art: DaemonArt) -> String:
	var bits := PackedStringArray([str(art.part_count()), "%.3f" % art.size_scale])
	for id in art.part_count():
		var basis := art.part_transform(id).basis
		bits.append("%.2f,%.2f,%.2f" % [basis.x.length(), basis.y.length(), basis.z.length()])
	return ";".join(bits)


# --- Carried: counts, Y, H, pickups. ---

func _carry_checks() -> void:
	var main := await _lab(Vector3(0.0, 0.95, 15.0))
	var br := _breakers(main)
	var mine := br.mine
	var start_ok := br.mode == BreakerDirector.Mode.RUN and Array(mine.counts) == [1, 1, 1, 1] and mine.loaded == B
	# Y loads the next kind; with one kind at none, Y skips it.
	var order := []
	for i in 4:
		br.press_cycle()
		await _frames(1)
		order.append(mine.loaded)
	mine.counts[E] = 0
	br.press_cycle()
	await _frames(1)
	var skipped := mine.loaded == C
	_check("acceptance: a round starts with %d of each kind (brute loaded); Y loads the next in turn (brute, exploit, cloak, decoy and round), skipping a kind with none left" % _bt.start_count, start_ok and order == [E, C, D, B] and skipped, "order %s, skipped %s" % [order, skipped])
	# U runs the loaded one and spends it; none left: nothing runs.
	mine.counts[E] = 1
	mine.loaded = E
	var runs_before := br.runs[E]
	br.press_run()
	await _frames(2)
	var ran := br.runs[E] == runs_before + 1 and mine.count(E) == 0 and br.my_exploit > 0.0
	var empties := [0]
	br.empty.connect(func(_k): empties[0] += 1)
	br.press_run()
	await _frames(int(ceil(_bt.use_gap_s * 60.0)) + 2)
	br.press_run()
	await _frames(2)
	_check("acceptance: U runs the loaded breaker (exploit here) and spends it; pressed with none of the loaded kind left, nothing runs and the readout says so", ran and br.runs[E] == runs_before + 1 and empties[0] >= 1 and mine.count(E) == 0, "runs %d, empties %d" % [br.runs[E], empties[0]])
	# Pickups: walking over one takes it, never past the cap; on its schedule more are laid.
	var player = main.get_node("Player")
	mine.counts[D] = _bt.carry_cap
	var p := br.lay_pickup_at(2, D)
	player.global_position = p.global_position + Vector3.UP * 0.95
	await _frames(5)
	var kept: bool = is_instance_valid(p) and br.pickups_out().get(2, -1) == D and mine.count(D) == _bt.carry_cap
	mine.counts[D] = 0
	await _frames(5)
	var taken: bool = br.pickups_out().get(2, -1) == -1 and mine.count(D) == 1 and br.pickups_taken == 1
	player.global_position = main.to_global(Vector3(0.0, 0.95, 15.0))
	var made := br.pickups_made
	var laid := await _wait(func(): return br.pickups_made > made, int((_bt.pickup_first_s + 1.0) * 60.0))
	var first: Dictionary = br.pickups_out()
	print("ICEBREAKERS pickup: laid after %d frames at %s" % [laid, first])
	_check("acceptance: pickups: walking over one takes it (+1 of its kind) unless that kind is at its cap (%d), when it stays; a seeded pickup is laid %.0f s into a round, then one every %.0f s while fewer than %d are out" % [_bt.carry_cap, _bt.pickup_first_s, _bt.pickup_every_s, _bt.pickups_live], kept and taken and laid >= int(_bt.pickup_first_s * 60.0) - 60 and first.size() == 1, "kept %s taken %s laid %d" % [kept, taken, laid])
	# A new round: counts back to the start, the pickups cleared; with the seeds fixed the same round lays
	# the same first pickup in another arena.
	br.start_round(2)
	await _frames(2)
	var reset_ok := Array(mine.counts) == [1, 1, 1, 1] and br.pickups_out().is_empty()
	var again := await _wait(func(): return br.pickups_made > made + 1, int((_bt.pickup_first_s + 1.0) * 60.0))
	var round_two: Dictionary = br.pickups_out()
	await _drop(main)
	var main2 := await _lab(Vector3(0.0, 0.95, 15.0))
	var other := _breakers(main2)
	other.start_round(2)
	await _wait(func(): return other.pickups_made > 0, int((_bt.pickup_first_s + 1.0) * 60.0))
	_check("a new round gives back %d of each and clears the pickups; with the seeds fixed (demo, test and capture runs) the same round lays the same first pickup" % _bt.start_count, reset_ok and again >= 0 and not round_two.is_empty() and round_two == other.pickups_out(), "%s vs %s" % [round_two, other.pickups_out()])
	await _drop(main2)


# --- brute. ---

func _brute_checks() -> void:
	var main := await _lab(Vector3(-17.6, 0.95, 9.4))
	var ice := _ice(main)
	var br := _breakers(main)
	var player = main.get_node("Player")
	player.rotation.y = 0.0
	await _frames(2)
	var wall := ice.wall("wall")
	var gap: float = player.eye_position().distance_to(wall.blast_point(player.eye_position()))
	br.mine.loaded = B
	br.press_run()
	await _frames(2)
	var broke_close: bool = wall.broken and br.mine.count(B) == 0
	# From further: a fresh build of the wall, the player farther back.
	ice.start_round(1)
	br.start_round(1)
	await _frames(2)
	wall = ice.wall("wall")
	player.global_position = main.to_global(Vector3(-17.6, 0.95, 11.6))
	await _frames(2)
	var far: float = player.eye_position().distance_to(wall.blast_point(player.eye_position()))
	await _gap()
	br.press_run()
	await _frames(2)
	var nearly: bool = not wall.broken and wall.health() <= _t.barrier_health * 0.5 and wall.health() > 0.0
	print("ICEBREAKERS brute: the wall up close (%.2f m) %s; from %.2f m left at %.0f of %.0f" % [gap, "broken" if broke_close else "standing", far, wall.health(), _t.barrier_health])
	_check("acceptance: brute cracks white ICE: run up close (within %.2f m) it breaks a whole wall in one charge (%.0f x %.0f = %.0f, past ICE's hit cap); from farther (to %.2f m, down to %.0f%%) it nearly breaks one" % [_bt.brute_full_m, _bt.brute_damage, _bt.brute_wall_scale, _bt.brute_damage * _bt.brute_wall_scale, _bt.brute_reach_m, _bt.brute_far_share * 100.0], broke_close and gap <= _bt.brute_full_m and nearly and far > _bt.brute_full_m, "close %s (%.2f m), far %.2f m -> %.0f" % [broke_close, gap, far, wall.health()])
	# A node: a hard hit, not a break.
	var node := ice.node_of("hud")
	var at: Vector3 = node.global_position + Vector3(0.0, 0.95, 1.8)
	player.global_position = at
	_face(player, node.blast_point(player.eye_position()))
	await _frames(1)
	var node_before: float = node.health()
	br.start_round(1)
	await _gap()
	br.press_run()
	await _frames(2)
	var node_hit: float = node_before - node.health()
	var node_broken: bool = node.broken
	# The hunter: a hard hit, never a one-shot, never adapted to.
	ice.start_round(2)
	br.start_round(2)
	await _frames(2)
	var hunter := ice.hunter
	player.global_position = hunter.global_position + Vector3(0.0, 0.95 - 0.0, 2.0)
	_face(player, hunter.blast_point(player.eye_position()))
	await _frames(1)
	var hunter_before: float = hunter.health()
	await _gap()
	br.press_run()
	await _frames(2)
	var hunter_hit: float = hunter_before - hunter.health()
	_check("acceptance: brute on a node hits hard (%.0f of its %.0f) without breaking it; on the hunter hard (%.0f of %.0f) and never a one-shot; the hunter never adapts to a breaker (no ledger entry)" % [node_hit, _t.node_health, hunter_hit, _t.hunter_health], is_equal_approx(node_hit, _bt.brute_damage) and not node_broken and is_equal_approx(hunter_hit, _bt.brute_damage) and not hunter.broken and not ice.ledger.has(IceDirector.BRUTE) and ice.adapt == 0.0, "node %.0f hunter %.0f ledger %s" % [node_hit, hunter_hit, ice.ledger])
	# A daemon in its cone, close: down. One behind the player: untouched. A cloak: ended by the charge.
	var dummies: Array = main.get_node("Arena/Targets").get_children()
	var front: Node3D = dummies[1]
	var back: Node3D = dummies[2]
	player.global_position = main.to_global(Vector3(14.0, 0.95, 14.0))
	player.rotation.y = 0.0
	_place(front, main.to_global(Vector3(14.0, 0.0, 12.0)))
	_place(back, main.to_global(Vector3(14.0, 0.0, 16.0)))
	await _frames(2)
	br.start_round(2)
	br.use(1, C, player.eye_position(), player.aim_direction())
	await _frames(int(ceil(_bt.use_gap_s * 60.0)) + 2)
	var cloaked_then: bool = br.cloaked(1)
	br.mine.loaded = B
	br.press_run()
	await _frames(2)
	_check("brute floors a daemon in its cone up close, leaves one behind the player alone, and (an attack) ends a cloak", not front.is_alive() and back.is_alive() and cloaked_then and not br.cloaked(1) and br.last_brute_hits >= 1, "front %s back %s hits %d" % [front.is_alive(), back.is_alive(), br.last_brute_hits])
	await _drop(main)


# --- exploit. ---

func _exploit_checks() -> void:
	var main := await _lab(Vector3(0.0, 0.95, 15.0))
	var ice := _ice(main)
	var br := _breakers(main)
	var player = main.get_node("Player")
	var node := ice.node_of("jam")
	var art: DaemonArt = node.art
	var seams := art.weak_points()
	var seam: Vector3 = art.global_transform * seams[0]
	var plain: Vector3 = node.global_position + Vector3(0.45, 0.15, 0.0)
	var lands := func(point: Vector3, source: String) -> float:
		var before: float = node.health()
		node.hit(20.0, point, Vector3.FORWARD, source)
		return before - node.health()
	var before_run: float = lands.call(seam, "terminal_cannon")
	br.use(1, E, player.eye_position(), player.aim_direction())
	await _frames(2)
	var on_seam: float = lands.call(seam, "terminal_cannon")
	var off_seam: float = lands.call(plain, "terminal_cannon")
	var blast: float = lands.call(seam, "fork_bomb")
	var marks: int = br.get_node("ExploitMarks").shown()
	# A daemon's seam too (its scale, the same rule).
	var dummy: Node3D = main.get_node("Arena/Targets").get_child(0)
	var d_art: DaemonArt = dummy.art_node()
	var d_seam: Vector3 = d_art.global_transform * d_art.weak_points()[0]
	var d_on: float = br.exploit_scale(1, dummy, d_seam, "terminal_cannon")
	var d_off: float = br.exploit_scale(1, dummy, dummy.global_position + Vector3(0.0, 3.0, 0.0), "terminal_cannon")
	await _frames(int(ceil(_bt.exploit_s * 60.0)) + 2)
	var after: float = lands.call(seam, "terminal_cannon")
	var marks_after: int = br.get_node("ExploitMarks").shown()
	print("ICEBREAKERS exploit: a 20 hit landed %.0f before, %.0f on a seam, %.0f off it, %.0f from a blast, %.0f after; %d seams marked" % [before_run, on_seam, off_seam, blast, after, marks])
	_check("acceptance: exploit: for its %.0f s a hit on a weak seam (ICE's or a daemon's) lands %.1f times harder, never off a seam, never a blast's, and after its time no more; the seams it counts are marked on this screen while it runs" % [_bt.exploit_s, _bt.exploit_scale], is_equal_approx(before_run, 20.0) and is_equal_approx(on_seam, 20.0 * _bt.exploit_scale) and is_equal_approx(off_seam, 20.0) and is_equal_approx(blast, 20.0) and is_equal_approx(after, 20.0) and is_equal_approx(d_on, _bt.exploit_scale) and is_equal_approx(d_off, 1.0) and marks >= seams.size() and marks_after == 0, "daemon %.1f/%.1f marks %d/%d" % [d_on, d_off, marks, marks_after])
	# After ICE's cap: the rail's 1000 on a seam is the cap's 100 times the bonus.
	br.start_round(1)
	br.use(1, E, player.eye_position(), player.aim_direction())
	await _frames(2)
	var hunter_less := ice.wall("gate")
	var g_art: DaemonArt = hunter_less.art
	var g_seam: Vector3 = g_art.global_transform * g_art.weak_points()[0]
	var g_before: float = hunter_less.health()
	hunter_less.hit(1000.0, g_seam, Vector3.FORWARD, "sigkill_rail")
	_check("exploit's bonus comes after ICE's hit cap: the rail's 1000 on a wall's seam lands the cap's %.0f times %.1f" % [_t.hit_cap, _bt.exploit_scale], is_equal_approx(g_before - hunter_less.health(), _t.hit_cap * _bt.exploit_scale), "%.0f" % (g_before - hunter_less.health()))
	await _drop(main)


# --- cloak. ---

func _cloak_checks() -> void:
	var main := await _lab(Vector3(0.0, 0.95, 15.0))
	var ice := _ice(main)
	var br := _breakers(main)
	var player = main.get_node("Player")
	await _unprotect(main)
	var node := ice.node_of("jam")
	var tells := func() -> int:
		var n := 0
		for e in node.events:
			n += 1 if e[1] == "tell" else 0
		return n
	# A node: cloaked inside its trigger range, it never starts; a shot ends the cloak, then it does.
	br.use(1, C, player.eye_position(), player.aim_direction())
	player.global_position = node.heart() + Vector3(0.0, -0.5, 4.0)
	await _frames(2)
	var before: int = tells.call()
	await _frames(90)
	var quiet: bool = tells.call() == before and br.cloaked(1)
	player.select_slot(0)
	await _frames(int(ceil(0.35 * 60.0)))
	player.drive_input(Vector2.ZERO, false, false, true)
	await _frames(2)
	var ended := not br.cloaked(1)
	var told := await _wait(func(): return tells.call() > before, 60)
	_check("acceptance: cloak: a node never triggers on a cloaked intruder in its range; firing ends the cloak at once, and then it does", quiet and ended and told >= 0, "quiet %s ended %s told after %d" % [quiet, ended, told])
	player.global_position = main.to_global(Vector3(0.0, 0.95, 15.0))
	# The hunter: in its tell on the player, a cloak calls the lance off; it goes to where it last saw the
	# player and tells on no one while the cloak holds; then its time runs out and it sees again.
	ice.start_round(2)
	br.start_round(2)
	await _frames(2)
	var hunter := ice.hunter
	player.global_position = main.to_global(Vector3(10.0, 0.95, 8.0))
	var hunted := await _wait(func(): return hunter.brain.state == DaemonBrain.State.TELL, 600)
	var lances: int = hunter.brain.lances
	br.use(1, C, player.eye_position(), player.aim_direction())
	await _frames(int(ceil(_t.hunter_tell_s * 60.0)) + 5)
	var called_off: bool = hunter.brain.lances == lances
	var tells_then: int = hunter.brain.tells
	var lost := await _wait(func(): return hunter.brain.unseen_t > 0.5, 120)
	await _wait(func(): return br.my_cloak <= _bt.cloak_warn_s * 0.5, int(ceil(_bt.cloak_s * 60.0)))
	var quiet_hunter: bool = hunter.brain.tells == tells_then and br.cloaked(1)
	var warned: bool = br.cloak_warning()
	var out := await _wait(func(): return not br.cloaked(1), 120)
	var seen_again := await _wait(func(): return hunter.brain.tells > tells_then, 600)
	print("ICEBREAKERS cloak: the hunter told after %d frames, lost the player after %d more, told again %d frames after the cloak ran out" % [hunted, lost, seen_again])
	_check("acceptance: cloak: the hunter in its tell on the player calls its lance off, loses sight, goes to where it last saw the player and tells on no one for the cloak's %.0f s (the HUD warning in its last %.0f s); when its time runs out it sees the player again" % [_bt.cloak_s, _bt.cloak_warn_s], hunted >= 0 and called_off and lost >= 0 and quiet_hunter and warned and out >= 0 and seen_again >= 0, "called off %s quiet %s warned %s" % [called_off, quiet_hunter, warned])
	# A daemon at home: never spots a cloaked player in its sight; does once the cloak is over.
	ice.start_round(1)
	br.start_round(1)
	var dummy: Node3D = main.get_node("Arena/Targets").get_child(1)
	_place(dummy, main.to_global(Vector3(0.0, 0.0, 14.0)))
	player.global_position = main.to_global(Vector3(0.0, 0.95, 9.0))
	br.use(1, C, player.eye_position(), player.aim_direction())
	await _frames(60)
	var home: bool = dummy.brain.state == DaemonBrain.State.HOME and dummy.brain.prey == 0
	var director := main.get_node(DaemonDirector.NODE_NAME)
	var spot_cloaked: int = dummy.brain._spot(director)
	br.fired(1)
	var spot_seen: int = dummy.brain._spot(director)
	var hunts := await _wait(func(): return dummy.brain.state != DaemonBrain.State.HOME, 60)
	_check("acceptance: cloak: a daemon in sight never spots a cloaked player (it stays home); uncloaked, it does at once", home and spot_cloaked == 0 and spot_seen == 1 and hunts >= 0, "home %s spotted %d/%d hunts %d" % [home, spot_cloaked, spot_seen, hunts])
	await _drop(main)


# --- decoy. ---

func _decoy_checks() -> void:
	var main := await _lab(Vector3(0.0, 0.95, 15.0))
	var ice := _ice(main)
	var br := _breakers(main)
	var player = main.get_node("Player")
	var life := _life(main)
	await _unprotect(main)
	# The hunter: telling on the player; a decoy thrown off to the side pulls it, mid-tell, onto the decoy,
	# whose call it hunts and lances while the player, in plain sight, is untouched.
	ice.start_round(2)
	br.start_round(2)
	await _frames(2)
	var hunter := ice.hunter
	player.global_position = main.to_global(Vector3(10.0, 0.95, 8.0))
	player.rotation.y = PI * 0.5
	var hunted := await _wait(func(): return hunter.brain.state == DaemonBrain.State.TELL, 600)
	var early: bool = hunter.brain.state_t < 0.3
	var hp: float = life.health()
	br.use(1, D, player.eye_position(), Vector3(-1.0, -2.0, 0.0).normalized())
	var landed := await _wait(func(): return not br.calling().is_empty(), 120)
	var decoy: Decoy = br.calling()[0] if landed >= 0 else null
	var landed_m: float = decoy.global_position.distance_to(player.global_position - Vector3.UP * 0.95) if decoy != null else -1.0
	var pulled := await _wait(func(): return hunter.brain.prey < 0, 30)
	var struck := await _wait(func(): return decoy != null and is_instance_valid(decoy) and decoy.struck >= 1, int(ceil(_bt.decoy_s * 60.0)))
	# It stays on the decoy for the whole call.
	var stayed := true
	var gone := -1
	for i in int(ceil(_bt.decoy_s * 60.0)) + 30:
		if br.calling().is_empty():
			gone = i
			break
		stayed = stayed and hunter.brain.prey < 0
		await physics_frame
	var spared: bool = life.health() == hp and stayed
	var back := await _wait(func(): return hunter.brain.prey == 1, 900)
	print("ICEBREAKERS decoy: landed after %d frames %.1f m from the player; the hunter pulled %d frames later, its lance on the decoy after %d more; back on the player %d frames after the call ended" % [landed, landed_m, pulled, struck, back])
	_check("acceptance: decoy: dropped, it lands and calls for %.0f s; the hunter, mid-tell on the player, swings onto it instead, lances it, and stays on it for its whole call while the player stands in its sight and is never hit; when the call ends the decoy bursts and the hunter hunts the player again: a real escape" % _bt.decoy_s, hunted >= 0 and early and landed >= 0 and pulled >= 0 and struck >= 0 and spared and gone >= 0 and back >= 0 and br.decoys_thrown == 1, "early %s spared %s" % [early, spared])
	# A node: the player inside its dome; without a decoy its field jams the player; with a decoy calling
	# within its range, the decoy takes the field and the player is not jammed.
	ice.start_round(1)
	br.start_round(1)
	await _frames(2)
	var node := ice.node_of("jam")
	player.global_position = node.heart() + Vector3(0.0, -0.5, 4.0)
	var jams := ice.jams_on_me
	var jammed := await _wait(func(): return ice.jams_on_me > jams, int(ceil((_t.jam_tell_s + 1.0) * 60.0)))
	var director := main.get_node(DaemonDirector.NODE_NAME)
	await _wait(func(): return node.state == IceNode.State.COOLDOWN and node.state_t >= _t.jam_cooldown_s / director.aggression() - 1.0, int(ceil((_t.jam_cooldown_s + 2.0) * 60.0)))
	br.use(1, D, player.eye_position(), Vector3(0.0, -1.0, 0.1).normalized())
	await _wait(func(): return not br.calling().is_empty(), 120)
	var jams_then := ice.jams_on_me
	var lured := await _wait(func(): return node.lured >= 1, int(ceil((_t.jam_cooldown_s + _t.jam_tell_s + 1.0) * 60.0)))
	await _frames(3)
	_check("acceptance: decoy: a node's field goes into a decoy calling within its trigger range and reaches no one: the player inside its dome, jammed by its field before, is not jammed now", jammed >= 0 and lured >= 0 and ice.jams_on_me == jams_then and node.fires >= 2, "jammed after %d, lured after %d, jams %d" % [jammed, lured, ice.jams_on_me])
	await _drop(main)


# --- The readout. ---

func _hud_checks() -> void:
	var main := await _lab(Vector3(0.0, 0.95, 15.0))
	var br := _breakers(main)
	var hud = main.get_node("Hud").breaker_hud()
	var player = main.get_node("Player")
	await _frames(3)
	var idle_lines: bool = hud.loaded_text() == "U BRUTE 1" and hud.counts_text() == "Y [b1] e1 c1 d1" and hud.effect_text().is_empty()
	br.use(1, E, player.eye_position(), player.aim_direction())
	await _frames(int(ceil(_bt.use_gap_s * 60.0)) + 2)
	br.use(1, C, player.eye_position(), player.aim_direction())
	await _frames(3)
	var lines: PackedStringArray = hud.effect_text()
	var both: bool = lines.size() == 2 and lines[0].begins_with("EXPLOIT ") and lines[1].begins_with("CLOAKED ") and lines[1].contains("firing ends it") and hud.wash() > 0.0
	var after_use: bool = hud.counts_text() == "Y [b1] e0 c0 d1" and hud.notice_text() == "cloak run"
	await _frames(int(ceil(_bt.exploit_s * 60.0)) + 3)
	_check("acceptance: the readout (bottom left, over the sudo badge): the loaded breaker with its key and count (\"U BRUTE 1\"), Y and every count (\"Y [b1] e1 c1 d1\"), a notice of what ran; under the crosshair the effect lines while they run (\"EXPLOIT 5.9s\", \"CLOAKED 4.9s  firing ends it\", the screen's edge washed ultraviolet), gone when they end", idle_lines and both and after_use and hud.effect_text().is_empty() and hud.wash() == 0.0, "%s | %s | %s" % [hud.loaded_text(), hud.counts_text(), lines])
	await _drop(main)
	# The layout: at 960x540 and 1280x720 the readout sits inside the screen, bottom left right over the
	# sudo badge, clear of the guide panel, the kill feed, the weapon strip and the hint line.
	var before := root.size
	for size in [Vector2i(1280, 720), Vector2i(960, 540)]:
		root.size = size
		GameSettings.current().set_value("gameplay", "practice", false)
		var host := _branch("Layout", Vector3.ZERO)
		await _frames(2)
		host["session"].host(0)
		await _frames(10)
		var combat_hud = host["main"].get_node("Hud").combat_hud()
		host["session"].players[7] = {"slot": 2, "name": "Daemon-2"}
		for i in 4:
			combat_hud.entries.push_front({"killer": "Daemon-2", "victim": "Daemon-1", "word": "SIGTERM", "left": 2.0})
		host["main"].get_node("Hud").guide()._notice("word ".repeat(60), Color.WHITE, 5000)
		var bh = host["main"].get_node("Hud").breaker_hud()
		bh._say("decoy run")
		await _frames(3)
		var screen := Rect2(Vector2.ZERO, Vector2(root.size))
		var box: Rect2 = bh.box().get_global_rect()
		var layout_hud = host["main"].get_node("Hud")
		var strip: Rect2 = layout_hud.weapon_hud().get("_stack").get_global_rect()
		var feed: Rect2 = combat_hud.get("_feed").get_global_rect()
		var panel: Rect2 = layout_hud.guide().get("_panel").get_global_rect()
		var badge: Rect2 = layout_hud.sudo_badge().badge().get_global_rect()
		var others := {"the weapon strip": strip, "the kill feed": feed, "the guide panel": panel, "the sudo badge": badge}
		var wrong := PackedStringArray()
		if not screen.encloses(box):
			wrong.append("outside %s" % box)
		if box.end.y > badge.position.y + 0.5 or box.position.x > badge.position.x + 0.5:
			wrong.append("not over the badge %s %s" % [box, badge])
		for name in others:
			if box.intersects(others[name]):
				wrong.append("on %s %s" % [name, others[name]])
		for label in layout_hud.find_children("*", "Label", true, false):
			if label.is_visible_in_tree() and label.text.begins_with("WASD") and label.get_global_rect().intersects(box):
				wrong.append("on the hint line")
		_check("acceptance: at %dx%d the breakers' readout sits inside the screen bottom left right over the sudo badge, clear of the weapon strip (its whole column left for C29), a full kill feed, a long guide notice and the hint line" % [size.x, size.y], wrong.is_empty(), ", ".join(wrong) + " box %s" % box)
		await _drop_side(host)
	root.size = before


# --- The pick. ---

func _pick_checks() -> void:
	# The numbers: only the round's, under the request's own whitelist.
	var main := await _lab(Vector3(0.0, 0.95, 15.0))
	var ice := _ice(main)
	var br := _breakers(main)
	ice.start_round(2)
	ice.note_damage("terminal_cannon", 100.0)
	ice.note_damage("terminal_cannon", 100.0)
	ice.wall("gate").hit(60.0, Vector3.INF, Vector3.ZERO, "sigterm")
	await _frames(2)
	var n := Pick.numbers(br)
	var kinds_ok := true
	for key in n:
		kinds_ok = kinds_ok and Request.STATS.has(key) and (typeof(n[key]) == TYPE_INT or (key == "hunter_adapted_weapon" and typeof(n[key]) == TYPE_STRING))
	var request = Request.build(n, "", 0)
	var prompt: String = request.full_prompt()
	var kept: bool = request.stats.size() == n.size()
	for key in n:
		kept = kept and request.stats.has(key) and request.stats[key] == n[key]
	var only_numbers: bool = kept and Array(n.keys()) == Pick.KEYS and kinds_ok and request.preamble().ends_with(Request.BREAKER_LINE)
	var clean := not prompt.contains("/") and not prompt.contains("\\") and not prompt.contains("res:") and not prompt.contains("user:") and prompt.contains("Player: (no message)")
	print("ICEBREAKERS pick: %s" % request.stats_line())
	_check("acceptance: the AI pick is built only from the round's numbers: ICE's walls and nodes standing and their health, whether the hunter is out with its health, the weapon it adapted to and how far, this player's counts and the round, all whitelisted (no path, name, process or file can get in), and its one fixed line asks for the breaker to load", only_numbers and clean and n["ice_walls"] == 2 and n["hunter_out"] == 1 and n["hunter_adapted_weapon"] == "terminal_cannon" and n["hunter_adapted_pct"] > 0 and n["ice_wall_health_pct"] < 100, request.stats_line())
	await _drop(main)
	# The scripted guide's own pick from those numbers.
	var picks := [Pick.scripted({"hunter_out": 1, "hunter_adapted_pct": 40, "hunter_adapted_weapon": "terminal_cannon", "breakers_decoy": 1, "breakers_exploit": 1, "ice_walls": 2, "breakers_brute": 1})[0],
		Pick.scripted({"hunter_out": 1, "hunter_adapted_pct": 10, "breakers_decoy": 1, "breakers_exploit": 1})[0],
		Pick.scripted({"ice_walls": 2, "breakers_brute": 1, "breakers_cloak": 1, "ice_nodes": 2})[0],
		Pick.scripted({"ice_nodes": 1, "breakers_cloak": 1})[0],
		Pick.scripted({"breakers_decoy": 1})[0],
		Pick.scripted({})[0]]
	_check("the scripted guide picks from the same numbers: decoy for a hunter adapted %d%% or more, exploit for a hunter out, brute for walls standing, cloak for nodes, else whatever is carried, none with nothing left" % Pick.DECOY_AT_PCT, picks == ["decoy", "exploit", "brute", "cloak", "decoy", ""], str(picks))
	# On T with the AI off (no AI linked under the headless guard): the scripted guide's pick.
	var off_main := await _lab(Vector3(0.0, 0.95, 15.0), false)
	var guide = off_main.get_node("Hud").guide()
	await _frames(2)
	guide.open_ask()
	var said: String = guide.panel_text()
	_check("acceptance: with the AI off, T shows the scripted guide's breaker pick (\"Scripted guide: Load ...\")", said.contains("Scripted guide: Load brute:") and not guide.is_typing(), said.c_escape())
	# At the round's end with the AI off: the summary's pick line is the scripted guide's.
	var round = off_main.get_node("Hud").round_hud()
	round._end_round()
	await _frames(2)
	_check("between rounds with the AI off, the summary panel's ICEbreaker pick is the scripted guide's", round.pick_text().begins_with("ICEbreaker pick: Load ") and round.summary_text().contains("ICEbreaker pick: Load "), round.pick_text())
	await _drop(off_main)
	# With a stub AI (never a real call): Enter alone on T asks for the pick with the numbers only; the
	# round's end carries the numbers in its one call, and the summary shows the AI's pick.
	var holder := {}
	var link := _stub_link({"answer": "Decoy: the hunter has adapted, slip away.", "delay_steps": 2}, "stub.cfg", holder)
	var stub_main := await _lab(Vector3(0.0, 0.95, 15.0), true, link)
	guide = stub_main.get_node("Hud").guide()
	await _wait(func(): return guide.session_link().is_ready(), 600)
	guide.open_ask()
	guide._send("")
	await _wait(func(): return holder.has("stub") and holder["stub"].ask_calls >= 1, 120)
	var stub = holder.get("stub")
	var sent_ok: bool = stub != null and stub.ask_calls == 1 and stub.last_preamble.ends_with(Request.BREAKER_LINE) and stub.last_message.ends_with("\nPlayer: (no message)")
	var keys_ok := true
	if stub != null:
		for key in stub.last_stats:
			keys_ok = keys_ok and Request.STATS.has(key)
		for key in Pick.KEYS:
			keys_ok = keys_ok and stub.last_stats.has(key)
	var shown := await _wait(func(): return guide.panel_text().contains("Decoy: the hunter"), 300)
	_check("acceptance: on T (a stub AI, no real call), Enter with nothing typed asks the AI which breaker to load: one call, its stats the whitelisted round numbers only, its instructions the fixed breaker line, no message; its answer shows", sent_ok and keys_ok and shown >= 0, "%s | %s" % [stub.last_stats if stub != null else {}, stub.last_preamble.right(60) if stub != null else ""])
	_fake_now += 60000
	round = stub_main.get_node("Hud").round_hud()
	round._end_round()
	var answered := await _wait(func(): return round.announcer.state == "ai", 300)
	_check("between rounds (a stub AI), the round's one call carries the breaker numbers and the breaker line beside the coach task, and the summary panel shows the AI's pick", answered >= 0 and stub.ask_calls == 2 and stub.last_preamble.contains(Request.TASKS["coach"]) and stub.last_preamble.ends_with(Request.BREAKER_LINE) and stub.last_stats.has("breakers_decoy") and round.pick_text() == "next round, load decoy (your AI's pick)", round.pick_text())
	await _drop(stub_main)


func _found() -> Found:
	var f := Found.new()
	f.agent_state = Found.AgentState.KNOWN
	f.agent = "claude"
	f.agent_cli_present = true
	Detector.resolve(f)
	return f


func _now() -> int:
	return _fake_now


## A started link with a fake detector and a stub adapter, its settings (consent given) in the test
## folder. holder["stub"] is the stub. Nothing real is run or reached.
func _stub_link(spec: Dictionary, settings: String, holder: Dictionary) -> Link:
	var path := _tmp.path_join(settings)
	Settings.save("claude", true, path)
	var link := Link.new()
	var detector := Fakes.FakeDetector.new()
	detector.result = _found()
	link.detector = detector
	link.settings_path = path
	link.adapter_factory = func(_f, _d, guide_tuning: Resource):
		var stub := Fakes.StubAdapter.new(guide_tuning)
		for key in spec:
			stub.set(key, spec[key])
		stub.rate_clock = _now
		holder["stub"] = stub
		return stub
	link.start()
	return link


# --- Practice and the ICE switch. ---

func _off_checks() -> void:
	GameSettings.current().set_value("gameplay", "practice", true)
	var main := await _lab(Vector3(0.0, 0.95, 15.0), true, null, true)
	var br := _breakers(main)
	var hud = main.get_node("Hud").breaker_hud()
	await _frames(3)
	br.press_run()
	await _frames(int(_bt.pickup_first_s * 60.0) + 30)
	_check("acceptance: practice turns breakers off: no readout, U runs nothing, no pickups", br.mode == BreakerDirector.Mode.OFF and hud.loaded_text() == "" and br.runs == PackedInt32Array([0, 0, 0, 0]) and br.pickups_made == 0)
	GameSettings.current().set_value("gameplay", "practice", false)
	GameSettings.current().set_value("gameplay", "ice", false)
	await _frames(3)
	var ice := _ice(main)
	var player = main.get_node("Player")
	var dummy: Node3D = main.get_node("Arena/Targets").get_child(1)
	player.global_position = main.to_global(Vector3(14.0, 0.95, 14.0))
	player.rotation.y = 0.0
	_place(dummy, main.to_global(Vector3(14.0, 0.0, 12.0)))
	await _frames(2)
	br.mine.loaded = B
	br.press_run()
	await _frames(2)
	_check("acceptance: the ICE switch off leaves breakers on, working on the daemons: no ICE standing, and the brute's charge floors a daemon", br.mode == BreakerDirector.Mode.RUN and ice.pieces().is_empty() and not dummy.is_alive() and hud.loaded_text() != "", "mode %d pieces %d alive %s loaded %s runs %s hits %d" % [br.mode, ice.pieces().size(), dummy.is_alive(), hud.loaded_text(), br.runs, br.last_brute_hits])
	GameSettings.current().set_value("gameplay", "ice", true)
	await _drop(main)


# --- A host and a joiner. ---

func _match_checks() -> void:
	GameSettings.current().set_value("gameplay", "practice", false)
	GameSettings.current().set_value("gameplay", "ice", true)
	var host := _branch("Host", Vector3.ZERO)
	var client := _branch("Client", CLIENT_OFFSET)
	await _frames(2)
	var joined := await _join(host, client)
	_check("the host and the joiner connect over ENet on 127.0.0.1", joined)
	if not joined:
		await _drop_side(client)
		await _drop_side(host)
		return
	var hb: BreakerDirector = host["main"].get_node(BreakerDirector.NODE_NAME)
	var cb: BreakerDirector = client["main"].get_node(BreakerDirector.NODE_NAME)
	var cid: int = client["session"].my_id
	for main in [host["main"], client["main"]]:
		for dummy in main.get_node("Arena/Targets").get_children():
			_park(dummy)
	host["player"].global_position = host["main"].to_global(Vector3(15.0, 0.95, 15.0))
	client["player"].global_position = client["main"].to_global(Vector3(14.0, 0.95, 16.0))
	var heard := await _wait(func(): return client["session"].breaker_words > 2 and hb.loadouts.has(cid), 300)
	_check("acceptance: in a match the host keeps every intruder's breakers and each joiner's are the host's word (%d of each)" % _bt.start_count, heard >= 0 and cb.mode == BreakerDirector.Mode.FOLLOW and hb.mode == BreakerDirector.Mode.RUN and Array(cb.mine.counts) == [1, 1, 1, 1] and Array((hb.loadouts[cid] as Breakers).counts) == [1, 1, 1, 1])
	# exploit: the joiner asks, the host runs it, and its word shows it on the joiner.
	cb.mine.loaded = E
	cb.press_run()
	var ran := await _wait(func(): return float(hb.exploit_left.get(cid, 0.0)) > 0.0 and cb.my_exploit > 0.0 and cb.mine.count(E) == 0, 120)
	# A forged ask for a kind it holds none of: the host refuses it.
	var refused: int = host["session"].breaker_refused
	client["session"]._breaker.rpc_id(1, client["session"].lives.get(cid, 0), E, Vector3.FORWARD)
	var no := await _wait(func(): return host["session"].breaker_refused > refused, 60)
	var said: String = client["main"].get_node("Hud").breaker_hud().notice_text()
	_check("acceptance: a joiner's run (U) is an ask the host judges: its exploit runs in the host's world and shows on the joiner from the host's word (its readout says so); an ask for a kind it holds none of is refused", ran >= 0 and no >= 0 and (hb.loadouts[cid] as Breakers).count(E) == 0 and said == "exploit run", "ran %d refused %d said %s" % [ran, no, said])
	# cloak: the host hides the joiner; the joiner's own shot ends it, by the host's judging of the shot.
	await _frames(int(ceil(_bt.use_gap_s * 60.0)) + 2)
	cb.mine.loaded = C
	cb.press_run()
	var hidden := await _wait(func(): return hb.cloaked(cid) and cb.my_cloak > 0.0, 120)
	client["player"].select_slot(0)
	await _frames(25)
	client["player"].drive_input(Vector2.ZERO, false, false, true)
	var unhidden := await _wait(func(): return not hb.cloaked(cid) and cb.my_cloak == 0.0, 120)
	_check("acceptance: a joiner's cloak hides it on the host (the host's daemons and ICE judge it) and its own shot, judged by the host, ends it on both", hidden >= 0 and unhidden >= 0, "hidden %d unhidden %d" % [hidden, unhidden])
	# decoy: the joiner's lands in the host's world, and the joiner draws it where the host's is.
	await _frames(int(ceil(_bt.use_gap_s * 60.0)) + 2)
	client["player"].rotation.y = 0.0
	cb.mine.loaded = D
	cb.press_run()
	var thrown := await _wait(func(): return not hb.calling().is_empty() and not cb.calling().is_empty(), 180)
	var apart := INF
	if thrown >= 0:
		await _frames(6)
		apart = host["main"].to_local(hb.calling()[0].global_position).distance_to(client["main"].to_local(cb.calling()[0].global_position))
	var same_build: bool = thrown >= 0 and (hb.calling()[0] as Decoy).spawn_seed == (cb.calling()[0] as Decoy).spawn_seed
	_check("acceptance: a joiner's decoy is thrown in the host's world (the host's word: its thrower the joiner) and the joiner draws it where the host's stands, built from the host's seed", thrown >= 0 and apart < 0.5 and (hb.calling()[0] as Decoy).thrower == cid and same_build, "apart %.2f m, same build %s" % [apart, same_build])
	# brute: the joiner at the gate; the host judges the charge, and the gate breaks on both screens.
	await _frames(int(ceil(_bt.use_gap_s * 60.0)) + 2)
	client["player"].global_position = client["main"].to_global(Vector3(0.0, 0.95, -6.6))
	client["player"].rotation.y = 0.0
	await _frames(20)
	cb.mine.loaded = B
	cb.press_run()
	var hi: IceDirector = host["main"].get_node(IceDirector.NODE_NAME)
	var ci: IceDirector = client["main"].get_node(IceDirector.NODE_NAME)
	var broke := await _wait(func(): return hi.wall("gate").broken and ci.wall("gate").broken, 180)
	_check("acceptance: a joiner's brute at the gate is judged by the host (its charge from where the host last heard the joiner's eye): the gate breaks in the host's world and on the joiner's screen", broke >= 0 and cb.mine.count(B) == 0, "broke after %d" % broke)
	# The host's own decoy: the joiner draws it too.
	host["player"].rotation.y = 0.0
	hb.mine.loaded = D
	hb.press_run()
	var seen := await _wait(func(): return cb.calling().size() == 2, 180)
	_check("the host's own breakers run where it decides and show on the joiner: its decoy stands on both", seen >= 0 and hb.calling().size() == 2)
	await _drop_side(client)
	await _drop_side(host)


# --- Harness. ---

## A fresh arena, practice off and ICE on, every daemon parked under the floor and the player at
## `player_at`. A demo link (`demo`), or a guarded one (no AI linked), or `with_link`.
func _lab(player_at: Vector3, demo: bool = true, with_link: Link = null, keep_settings: bool = false) -> Node:
	if not keep_settings:
		GameSettings.current().set_value("gameplay", "practice", false)
		GameSettings.current().set_value("gameplay", "ice", true)
	var link := with_link
	if link == null:
		link = Link.new()
		link.settings_path = _tmp.path_join("arena-privacy.cfg")
		link.demo = demo
		if not demo:
			link.start()
	Link.park(link)
	var main = MainScene.instantiate()
	root.add_child(main)
	_arenas.append(main)
	main.get_node("Hud").guide().focus_check = func(): return false
	var player = main.get_node("Player")
	player.assume_captured = true
	player.global_position = main.to_global(player_at)
	for dummy in main.get_node("Arena/Targets").get_children():
		_park(dummy)
	await _frames(2)
	return main


func _breakers(main: Node) -> BreakerDirector:
	return main.get_node(BreakerDirector.NODE_NAME)


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


## A daemon at `at` (world space), at home there.
func _place(dummy: Node3D, at: Vector3) -> void:
	dummy.global_position = at
	dummy.global_rotation = Vector3.ZERO
	dummy.brain.take_home()
	dummy.brain.moved = false
	dummy.brain.state = DaemonBrain.State.HOME
	dummy.brain.prey = 0


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
	await process_frame


func _park(dummy: Node3D) -> void:
	dummy.global_position = dummy.get_parent().get_parent().get_parent().to_global(PARKED + Vector3(dummy.get_index() * 3.0, 0.0, 0.0))
	dummy.global_rotation = Vector3.ZERO
	dummy.brain.take_home()
	dummy.brain.moved = false
	dummy.brain.state = DaemonBrain.State.HOME
	dummy.brain.prey = 0


## Waits out the breakers' use gap: a second press any sooner spends nothing.
func _gap() -> void:
	await _frames(int(ceil(_bt.use_gap_s * 60.0)) + 2)


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


## A side of the game in its own branch: {branch, session, main, player}.
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
	var out := {"branch": branch, "session": session, "main": main, "player": main.get_node("Player")}
	out["player"].assume_captured = true
	main.get_node("Hud").guide().focus_check = func(): return false
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
	Dummy.fixed_seeds = true
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


## A script's code without its comments.
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
