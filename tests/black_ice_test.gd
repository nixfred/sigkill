extends SceneTree
## Headless test of I3's Black ICE for SIGKILL. scripts/check.sh runs it as step 42, and any FAIL exits 1.
##
##   godot --headless --path . --fixed-fps 60 --script res://tests/black_ice_test.gd
##
## The sources: protocol 14, the host's ICE word carrying Black ICE's (no new message: 28 RPCs, 31 sends; 15 and 32 since
## C29's chmod 000)
## and a new death cause (a flatline), the host judging the touch and holding a flatlined player down until its next round. The
## tuning: never round 1, a long tell, slower than a running player. The colour: Black ICE's cold slate
## reads apart (OKLab) from every bright colour of the palette. The art: the same seed builds the same one,
## other seeds others, huge, inside its budgets, no box and no wire. The rarity: never in round 1, at most
## one a round, its chance and its moment fixed by the round under fixed seeds and close to the tuning's
## odds over many new rolls. Alone, in the real arena: its arrival (the warning, the lights down to the
## tuning's level while its own glow stays, the hum out, the guide's link cut, nothing touching in the
## tell); its touch flatlining the player (the round ends as a loss, the run over, round 1 next and the
## player back); normal weapons, blasts and a brute without exploit only flashing it; the exploit and brute
## combo breaking its seals and killing it (a broken seal mending in its time); a decoy pulling it off the
## player; a cloak hiding the player from it; its speed under a running player's; spawn protection
## holding; its withdrawal at the round's end and everything coming back. The AI: its numbers ride in the
## request's whitelist (a stub adapter, never a real call), its line is added while it is out, and the
## scripted guide recommends the decoy or the combo. The HUD at 960x540. Practice and the ICE switch turn
## it off. Then a host and a joiner over ENet on 127.0.0.1: the joiner draws the host's Black ICE (its
## seed, its arrival, its lights and link), a touch flatlines the joiner on both screens and holds it out
## until the host's next round, and the joiner's own combo, judged by the host, kills it on both.
## Deterministic: frames counted, only counts and outcomes printed.

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
const BlackArt = preload("res://scripts/ice/black_ice_art.gd")
const WATCHDOG_MS := 12000
const CLIENT_OFFSET := Vector3(1000.0, 0.0, 0.0)
const PARKED := Vector3(0.0, -50.0, 0.0)
## The least OKLab distance Black ICE's colour keeps from every bright colour of the palette.
const APART := 0.15
const BUILDS := 10
## A round's seconds left in a check: long enough that its end never comes mid-check.
const LONG_ROUND_S := 100000.0
## Rolls sampled for the odds, and how far the share may stray from the tuning's chance.
const ROLLS := 3000
const ODDS_SLACK := 0.04
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
var _kt: BlackIceTuning
var _fake_now := 1000000


func _initialize() -> void:
	_run()


func _run() -> void:
	await process_frame
	root.size = Vector2i(1280, 720)
	_tmp = OS.get_temp_dir().path_join("sigkill-black-ice-test-%d" % OS.get_process_id())
	if DirAccess.dir_exists_absolute(_tmp):
		print("FAIL the test's temporary folder already exists; not touching it")
		quit(1)
		return
	DirAccess.make_dir_recursive_absolute(_tmp)
	Controls.ensure()
	GameSettings.current().reset()
	_bt = load("res://resources/breakers.tres") as BreakerTuning
	_kt = load("res://resources/black_ice.tres") as BlackIceTuning
	_source_checks()
	_palette_checks()
	await _art_checks()
	_rarity_checks()
	await _arrival_checks()
	await _flatline_checks()
	await _weapon_checks()
	await _combo_checks()
	await _decoy_checks()
	await _cloak_checks()
	await _pick_checks()
	await _hud_checks()
	await _off_checks()
	await _match_checks()
	await _cleanup()
	for name in DirAccess.get_files_at(_tmp):
		DirAccess.remove_absolute(_tmp.path_join(name))
	DirAccess.remove_absolute(_tmp)
	print("BLACK ICE: %d checks" % _checks)
	print("BLACK ICE RESULT: ", "ALL PASS" if _fails == 0 else "%d FAILED" % _fails)
	quit(0 if _fails == 0 else 1)


func _check(label: String, ok: bool, detail: String = "") -> void:
	_checks += 1
	print("PASS " if ok else "FAIL ", label, ("   " + detail) if detail != "" else "")
	if not ok:
		_fails += 1


# --- The sources and the tuning. ---

func _source_checks() -> void:
	var session := _code("res://scripts/net/net_session.gd")
	var tick := _body(session, "_tick_ice")
	var word := _body(session, "_ice")
	var flat := _body(session, "black_ice_flatline")
	_check("acceptance: in a match the host decides Black ICE and sends its word inside ICE's own at the sync rate (one packet, so it never runs out of step; a joiner plays it), judges every touch (a flatline in the match's combat, told as a death by Black ICE) and holds a flatlined player down until its ICE starts the next round; protocol 14 (15 since C29's chmod 000, 16 since C30's pipe |, its 13th number Black ICE's slow; 32 sends)", Session.PROTOCOL == 16 and tick.contains("w[\"percent\"], bw[\"seed\"], bw[\"word\"])") and word.contains("_black_ok(black_seed, black)") and word.contains("ice.take_black_word(black_seed, black)") and session.count("@rpc(") == 28 and session.count(".rpc_id(") == 32 and flat.contains("combat.damage_player(id, id") and flat.contains("_broadcast_death(id, id, local_way, BLACK_CAUSE)") and _body(session, "_death").contains("weapon == BLACK_CAUSE") and _body(session, "_physics_process").contains("if _flat_round.has(id):\n\t\t\t\t\tcombat.defer_respawn(id, RESPAWN_RETRY_S)") and _body(session, "_tick_flatlined").contains("ice.round_number != _flat_round[id]"))
	var problems := _kt.problems() if _kt != null else PackedStringArray(["no tuning"])
	var bad := _kt.duplicate() as BlackIceTuning
	bad.from_round = 1
	bad.tell_s = 2.0
	bad.speed = 7.0
	var movement := load("res://resources/movement_tuning.tres")
	var run: float = movement.walk_speed if movement != null else 0.0
	_check("the tuning (resources/black_ice.tres) is sound and fair: from round %d (never round 1), its arrival's tell %.0f s (never under %.0f), its speed %.1f m/s and its drift %.1f m/s both under a running player's %.1f; it refuses round 1, a short tell and a speed a player cannot outrun" % [_kt.from_round, _kt.tell_s, BlackIceTuning.TELL_FIRST_S, _kt.speed, _kt.drift_speed, run], problems.is_empty() and _kt.from_round >= 2 and _kt.tell_s >= BlackIceTuning.TELL_FIRST_S and _kt.speed < run and _kt.drift_speed < run and _kt.touch_m >= _kt.radius_m and bad.problems().size() == 3, "%s / bad %s" % [problems, bad.problems()])
	var piece := _code("res://scripts/ice/black_ice.gd")
	_check("acceptance: normal weapons cannot kill it: every hit goes to its own judge, where nothing is taken and nothing is noted for the hunter; only a brute while that intruder's exploit runs breaks a seal", _body(piece, "_land").contains("source == IceDirector.BRUTE and director.exploit_runs(shooter)") and not _body(piece, "_land").contains("director.take(") and not _body(piece, "_land").contains("note_damage"))


func _palette_checks() -> void:
	var src := FileAccess.get_file_as_string("res://scripts/palette.gd")
	var rx := RegEx.create_from_string("const ([A-Z_]+) := Color\\(")
	var consts: Dictionary = (Palette as Script).get_script_constant_map()
	var least := INF
	var near := ""
	for m in rx.search_all(src):
		var key := m.get_string(1)
		if key.begins_with("BLACK_ICE"):
			continue
		var c: Color = consts[key]
		if maxf(c.r, maxf(c.g, c.b)) <= 0.5:
			continue  # the dark bases, armour and glass: nothing bright to confuse it with
		var dist := _oklab(Palette.BLACK_ICE).distance_to(_oklab(c))
		if dist < least:
			least = dist
			near = key
	var lab := _oklab(Palette.BLACK_ICE)
	var chroma := Vector2(lab.y, lab.z).length()
	var hue := fposmod(rad_to_deg(atan2(lab.z, lab.y)), 360.0)
	var text_l := _oklab(Palette.BLACK_ICE_TEXT).x
	_check("acceptance: Black ICE's own colour, a cold dead slate #%s (OKLab hue %.0f, chroma %.3f), reads apart: at least %.2f from every bright colour of the palette (the player's teal, every weapon's, the daemons', white ICE's glacier, the hunter's cobalt, the breakers' ultraviolet, the crosshair's); its HUD text #%s legible on black; its body glass darker than the rest of ICE's" % [Palette.BLACK_ICE.to_html(false), hue, chroma, APART, Palette.BLACK_ICE_TEXT.to_html(false)], least >= APART and Palette.BLACK_ICE.to_html(false) == "2a6e81" and chroma < 0.08 and hue > 180.0 and hue < 260.0 and text_l >= 0.7 and Palette.BLACK_ICE_GLASS.get_luminance() < Palette.ICE_CRYSTAL.get_luminance(), "nearest %s %.3f; text lightness %.2f" % [near, least, text_l])


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
	var a := _build_art(world, 4242)
	var a2 := _build_art(world, 4242)
	await _frames(3)
	var same := a.part_count() == a2.part_count()
	for id in a.part_count():
		same = same and a.part_transform(id).is_equal_approx(a2.part_transform(id))
	var spikes := {}
	var legs := {}
	for i in BUILDS:
		var other := _build_art(world, 1000 + i * 7919)
		spikes[other.blade_count()] = true
		legs[other.halo_count()] = true
	await _frames(2)
	var box := a.pose_bounds()
	var shapes_ok := true
	var dark := true
	for i in a.sets().size():
		shapes_ok = shapes_ok and a.set_shape(i) != DaemonArt.Shape.CUBE
		if a.set_look(i) == DaemonArt.Look.ICE:
			dark = dark and a.sets()[i].material_override == Palette.black_ice_crystal_material()
	_check("acceptance: its look: one seed builds the same Black ICE every time, other seeds others (spikes %s, legs %s); huge (%.1f m tall, %.1f m across) and faceless, no box and no wire (crystal plates, spikes and legs only), its glass Black ICE's own darker crystal; within its budget (%d triangles of %d, %d draw calls of %d)" % [spikes.keys(), legs.keys(), box.size.y, maxf(box.size.x, box.size.z), a.triangles(), a.budget_triangles, a.draw_calls(), a.budget_draw_calls], same and spikes.size() >= 3 and legs.size() >= 2 and box.size.y >= 4.0 and maxf(box.size.x, box.size.z) >= 2.2 and shapes_ok and dark and a.triangles() <= a.budget_triangles and a.draw_calls() <= a.budget_draw_calls, "parts %d" % a.part_count())
	_check("its seals and its heart are its weak points (where exploit's marks show), lit only once it has formed", a.weak_parts().size() == 2 * BlackArt.SEAL_SEGMENTS + 1 and a.seal_glow(0) > 0.5 and a.seal_glow(1) > 0.5)
	world.free()
	await process_frame


func _build_art(parent: Node3D, seed: int) -> DaemonArt:
	var holder := Node3D.new()
	parent.add_child(holder)
	var art := BlackArt.new()
	art.setup(holder, seed)
	holder.add_child(art)
	art.drive(DaemonArt.Act.IDLE)
	return art


# --- The rarity. ---

func _rarity_checks() -> void:
	var ice := IceDirector.new()
	ice.black_tuning = _kt
	root.add_child(ice)
	var fixed := Dummy.fixed_seeds
	Dummy.fixed_seeds = false
	var firsts := 0
	var rates := {}
	var in_window := true
	for number in [2, 4]:
		var came := 0
		for i in ROLLS:
			var at := ice.black_arrival(number)
			if at >= 0.0:
				came += 1
				in_window = in_window and at >= _kt.arrive_first_s and at <= _kt.arrive_last_s
		rates[number] = float(came) / ROLLS
	for i in 500:
		if ice.black_arrival(1) >= 0.0:
			firsts += 1
	Dummy.fixed_seeds = true
	var steady := true
	var plan := PackedFloat32Array()
	for number in range(1, 13):
		var first := ice.black_arrival(number)
		steady = steady and first == ice.black_arrival(number)
		plan.append(first)
	Dummy.fixed_seeds = fixed
	ice.free()
	var comes := []
	for i in plan.size():
		if plan[i] >= 0.0:
			comes.append("%d at %.1f s" % [i + 1, plan[i]])
	print("BLACK ICE fixed plan: %s" % ", ".join(comes))
	_check("acceptance: rare and seeded: never in round 1 (none in 500 rolls), round 2 comes %.1f%% of rolls (the tuning's %.0f%%), round 4 and on %.1f%% (%.0f%%), always %.0f to %.0f s into the round's play; under fixed seeds (demo, test and capture runs) each round's roll and moment are the same every time (%s)" % [rates[2] * 100.0, _kt.chance(2) * 100.0, rates[4] * 100.0, _kt.chance(4) * 100.0, _kt.arrive_first_s, _kt.arrive_last_s, ", ".join(comes)], firsts == 0 and absf(rates[2] - _kt.chance(2)) <= ODDS_SLACK and absf(rates[4] - _kt.chance(4)) <= ODDS_SLACK and in_window and steady and plan[0] < 0.0 and comes.size() >= 2)


# --- Its arrival, alone. ---

func _arrival_checks() -> void:
	var main := await _lab(Vector3(0.0, 0.95, 15.0))
	var ice := _ice(main)
	var blackout: Blackout = main.get_node(Blackout.NODE_NAME)
	var guide = main.get_node("Hud").guide()
	var hud = main.get_node("Hud").black_ice_hud()
	var sun: Light3D = main.get_node("Sun")
	var sun_lit := sun.light_energy
	var lit_level := blackout.level
	var link_before: bool = guide.link_cut()
	var badge_before: String = guide.badge_text()
	# The round's plan: round 3 under fixed seeds brings it; its moment comes on the round's play clock.
	ice.start_round(3)
	var planned := ice.black_plan
	ice.round_t = maxf(planned - 0.05, 0.0)
	var came := await _wait(func(): return ice.black != null, 30)
	var b := ice.black
	var spot: Vector3 = ice.to_local(b.global_position) if b != null else Vector3.INF
	var far := INF
	for s in IceDirector.BLACK_SPOTS:
		far = minf(far, -Vector2(s.x, s.z).distance_to(Vector2(0.0, 15.0)))
	var farthest: bool = b != null and is_equal_approx(-Vector2(spot.x, spot.z).distance_to(Vector2(0.0, 15.0)), far)
	_check("acceptance: round 3 (fixed seed) plans its arrival %.1f s into the round's play; it comes then, arriving at the spot farthest from the player (%s)" % [planned, spot], planned >= 0.0 and came >= 0 and b != null and b.phase == BlackIce.Phase.ARRIVE and farthest and ice.blacks_made == 1)
	if b == null:
		await _drop(main)
		return
	await _frames(int(_kt.dim_s * 60.0) + 6)
	var warning: PackedStringArray = hud.warning_text()
	var low := _kt.lights_low
	var own_glow: float = Palette.black_ice_light_material().get_shader_parameter("energy")
	var ice_glow: float = Palette.ice_light_material().get_shader_parameter("energy")
	var shader_level: float = blackout.level  # the level it set on the arena_light shader global (a headless renderer keeps no globals to read back)
	_check("acceptance: its arrival is an event with a long tell (%.0f s): the warning up (\"%s\"), the arena's lights down to %.0f%% of themselves (the shader level %.2f, the sun %.2f of %.2f, the danger lights' level %.2f) while its own glow stays (%.1f) and ICE's (%.1f), the hum dropped out, the guide's link shown cut (\"%s\")" % [_kt.tell_s, " / ".join(warning), low * 100.0, shader_level, sun.light_energy, sun_lit, ArenaArt.light_level, own_glow, ice_glow, guide.badge_text()], lit_level == 1.0 and not link_before and warning.size() == 3 and warning[0] == hud.TITLE and absf(blackout.level - low) < 0.01 and absf(shader_level - low) < 0.01 and absf(sun.light_energy - sun_lit * low) < 0.01 and absf(ArenaArt.light_level - low) < 0.01 and own_glow == Palette.BLACK_ICE_LIGHT_ENERGY and ice_glow == Palette.ICE_LIGHT_ENERGY and blackout.hum_down > 0.99 and blackout.humming() and guide.link_cut() and guide.badge_text() == guide.CUT_BADGE and badge_before != guide.CUT_BADGE)
	# Nothing touches in the tell: the player stands inside its reach.
	var life := _life(main)
	await _unprotect(main)
	main.get_node("Player").global_position = b.global_position + Vector3(0.6, 0.95, 0.0)
	await _frames(20)
	_check("acceptance: fair: nothing touches before its tell ends, even standing in it", life.alive() and b.phase == BlackIce.Phase.ARRIVE and ice.flatlines == 0)
	main.get_node("Player").global_position = main.to_global(Vector3(0.0, 0.95, 15.0))
	var formed := await _wait(func(): return is_instance_valid(b) and b.phase == BlackIce.Phase.OUT, int(_kt.tell_s * 60.0) + 30)
	_check("its tell ends and it is out, hunting; still cut, still dark", formed >= 0 and guide.link_cut() and absf(blackout.level - low) < 0.01)
	# The round's end: it withdraws; the lights, the hum and the link come back.
	ice._on_round_ended(3)
	var back := await _wait(func(): return ice.black == null and blackout.level == 1.0 and not guide.link_cut(), int(maxf(_kt.withdraw_s, _kt.restore_s) * 60.0) + 60)
	await _frames(2)
	_check("acceptance: the round's end withdraws it, and when it is gone the lights come back exactly (the sun %.2f), the hum returns and the guide's link with it" % sun.light_energy, back >= 0 and ice.blacks_withdrawn == 1 and sun.light_energy == sun_lit and blackout.hum_down == 0.0 and ArenaArt.light_level == 1.0 and guide.badge_text() == badge_before)
	await _drop(main)


# --- Its touch, alone: the run is over. ---

func _flatline_checks() -> void:
	var main := await _lab(Vector3(0.0, 0.95, 15.0))
	var ice := _ice(main)
	var round = main.get_node("Hud").round_hud()
	var life := _life(main)
	var player = main.get_node("Player")
	await _unprotect(main)
	round._start_round(4)
	await _frames(2)
	var b := ice.summon_black(3)
	b.phase_t = _kt.tell_s - 0.02
	player.global_position = main.to_global(Vector3(3.0, 0.95, 4.0))
	await _frames(3)
	# Spawn protection holds: a protected player inside its reach is not touched.
	life.combat.states[1]["protect_left"] = 1.0
	player.global_position = b.global_position + Vector3(0.9, 0.95, 0.0)
	await _frames(3)
	var held: bool = life.alive() and ice.flatlines == 0
	life.combat.states[1]["protect_left"] = 0.0
	var touched := await _wait(func(): return not life.alive(), 60)
	await _frames(2)
	var banner: String = main.get_node("Hud").combat_hud().line_label().text
	var hidden_banner: bool = main.get_node("Hud").combat_hud().banner_text() == ""
	var summary: String = round.summary_text()
	_check("acceptance: fair: spawn protection holds against its touch", held)
	_check("acceptance: touching it is a flatline: alone the round ends at once as a loss with a clear screen (\"%s\", the screen darkened behind it and the death banner giving it the room), the player held down with no respawn countdown (\"%s\")" % [summary.get_slice("\n", 0), banner.replace("\n", " ")], touched >= 0 and life.flatlined_now and round.lost and round.showing_summary() and summary.begins_with("FLATLINED by Black ICE") and round._veil.visible and hidden_banner and ice.flatlines == 1 and b.flatlines == 1 and banner.contains("FLATLINED") and not banner.contains("respawn in"))
	await _frames(int(life.tuning.respawn_delay_s * 60.0) + 30)
	var still_down: bool = not life.alive()
	var next := await _wait(func(): return round.phase == round.Phase.ROUND, int(round._t.intermission_seconds * 60.0) + 120)
	await _frames(3)
	_check("acceptance: the run is over: no respawn through the break, then a new run at round 1 with the player back, Black ICE gone and the lights up", still_down and next >= 0 and round.stats.round_number == 1 and life.alive() and not life.flatlined_now and not round.lost and ice.black == null and main.get_node(Blackout.NODE_NAME).level == 1.0, "round %d alive %s" % [round.stats.round_number, life.alive()])
	await _drop(main)


# --- Weapons only flash it. ---

func _weapon_checks() -> void:
	var main := await _lab(Vector3(0.0, 0.95, 15.0))
	var ice := _ice(main)
	var br := _breakers(main)
	ice.start_round(4)
	var b := _out_now(ice, 1)
	var at := b.global_position + Vector3(0.0, 1.5, 1.25)
	var landed := 0
	for weapon in ["terminal_cannon", "sigterm", "sigkill_rail", "fork_shotgun", "grep_seeker"]:
		if b.hit(1000.0, at, Vector3.FORWARD, weapon):
			landed += 1
	var seals_before := b.seals_left
	ice.blast(b.global_position + Vector3(0.0, 1.0, 2.0), func(d: float) -> float: return 300.0 if d < 3.0 else 0.0, 1.0, "fork_bomb", main.get_world_3d().direct_space_state)
	var blasted := seals_before - b.seals_left
	await _frames(1)
	var glow := b.art.hit_glow()
	# With exploit running a weapon still does nothing, even on a seal.
	br.exploit_left[1] = 5.0
	var seal: Vector3 = b.art.global_transform * b.art.weak_points()[1]
	var on_seal := b.hit(1000.0, seal, Vector3.FORWARD, "sigkill_rail")
	# A brute without exploit: a flash, no seal.
	br.exploit_left[1] = 0.0
	var brute_alone := b.hit(120.0, at, Vector3.FORWARD, IceDirector.BRUTE)
	_check("acceptance: normal weapons cannot kill it: the cannon, SIGTERM, the rail's 1000, fork() and grep land nothing (%d), a fork bomb's blast nothing (%d), a rail shot on a seal with exploit running nothing, a brute without exploit nothing; every hit flashes it (%d flashes, glow %.2f) and its seals stand %d/%d; the hunter adapts to none of it" % [landed, blasted, b.flashes, glow, b.seals_left, _kt.seals], landed == 0 and blasted == 0 and not on_seal and not brute_alone and b.flashes >= 8 and glow > 0.1 and b.seals_left == _kt.seals and not b.broken and ice.ledger.is_empty())
	await _drop(main)


## True (and a failed check `label`, the arena dropped) when Black ICE `b` is gone before a check could
## read it: a flatline ended the round and withdrew it, or it broke. A check never just vanishes.
func _gone(b, main: Node, label: String, detail: String) -> bool:  # untyped: `b` may be freed
	if is_instance_valid(b) and not b.is_queued_for_deletion():
		return false
	_check(label, false, "Black ICE gone before the check (%s)" % detail)
	await _drop(main)
	return true


## Round's Black ICE out now at BLACK_SPOTS[`spot`], its tell skipped.
func _out_now(ice: IceDirector, spot: int) -> BlackIce:
	var b := ice.summon_black(spot)
	b.phase_t = _kt.tell_s
	b.step(0.0, ice.daemons)
	return b


# --- The combo: exploit, then brute while it runs. ---

func _combo_checks() -> void:
	var main := await _lab(Vector3(0.0, 0.95, 15.0))
	var ice := _ice(main)
	var br := _breakers(main)
	var player = main.get_node("Player")
	await _unprotect(main)
	ice.start_round(4)
	br.mine.counts = PackedInt32Array([2, 1, 0, 1])
	# The plan: a decoy to pin it, exploit, then two brutes inside the exploit's seconds.
	var b := _out_now(ice, 3)
	var spot := b.global_position
	player.global_position = spot + Vector3(-9.0, 0.95, 4.0)
	_face(player, spot + Vector3(0.0, 1.0, 0.0))
	br.mine.loaded = D
	br.press_run()
	var pinned := await _wait(func(): return is_instance_valid(b) and b.brain.prey < 0, 200)
	await _frames(90)
	if await _gone(b, main, "acceptance: the kill combo takes a plan: a decoy pins it, exploit runs, then the brutes", "pinned %d" % pinned):
		return
	var decoy: Decoy = br.calling()[0] if not br.calling().is_empty() else null
	var near_decoy: bool = decoy != null and Vector2(b.global_position.x - decoy.global_position.x, b.global_position.z - decoy.global_position.z).length() < 1.2
	player.global_position = b.global_position + (player.global_position - b.global_position).normalized() * 3.1
	player.global_position.y = main.to_global(Vector3(0.0, 0.95, 0.0)).y
	_face(player, b.global_position + Vector3(0.0, 1.5, 0.0))
	await _gap()
	br.mine.loaded = E
	br.press_run()
	await _gap()
	br.mine.loaded = B
	br.press_run()
	var one := await _wait(func(): return is_instance_valid(b) and b.seals_left == _kt.seals - 1, 20)
	var reeled: bool = b.brain.state == DaemonBrain.State.SCATTER
	var call_one: String = main.get_node("Hud").black_ice_hud().call_text()
	# It is thrown back along the charge; once back in reach, the second brute while exploit still runs.
	await _gap()
	var close := await _wait(func(): return is_instance_valid(b) and br.brute_strength(player.eye_position(), player.aim_direction(), b.blast_point(player.eye_position())) > 0.0 and b.brain.state != DaemonBrain.State.SCATTER, 240)
	_face(player, b.global_position + Vector3(0.0, 1.5, 0.0))
	var exploit_left: float = br.my_exploit
	br.mine.loaded = B
	br.press_run()
	var dead := await _wait(func(): return is_instance_valid(b) and b.broken, 20)
	await _frames(2)
	var call_two: String = main.get_node("Hud").black_ice_hud().call_text()
	_check("acceptance: the kill combo takes a plan: a decoy pins it, exploit runs, a brute while exploit runs breaks a seal (\"%s\", thrown back along the charge), and the second brute inside the same exploit (%.1f s left) breaks the last: it dies (\"%s\")" % [call_one, exploit_left, call_two], pinned >= 0 and near_decoy and one >= 0 and reeled and call_one.begins_with("SEAL BROKEN") and close >= 0 and exploit_left > 0.0 and dead >= 0 and b.phase == BlackIce.Phase.DOWN and ice.blacks_killed == 1 and call_two == "BLACK ICE DOWN", "pinned %d near %s one %d close %d dead %d seals %d" % [pinned, near_decoy, one, close, dead, b.seals_left])
	var gone := await _wait(func(): return ice.black == null and main.get_node(Blackout.NODE_NAME).level == 1.0 and not main.get_node("Hud").guide().link_cut(), 240)
	_check("acceptance: once it is broken the lights, the hum and the link come back, and no other comes that round (at most one a round)", gone >= 0 and ice.black_plan < 0.0 and ice.blacks_made == 1)
	# A broken seal mends: one combo, then nothing until seal_mend_s has run.
	var b2 := _out_now(ice, 1)
	b2.brain.state = DaemonBrain.State.HOME
	br.exploit_left[1] = 3.0
	b2.hit(120.0, b2.global_position + Vector3(0.0, 1.5, 1.25), Vector3.FORWARD, IceDirector.BRUTE)
	var broke := b2.seals_left
	br.exploit_left[1] = 0.0
	b2.mend_left = 0.2
	await _frames(20)
	_check("a broken seal mends in the tuning's %.0f s unless the next combo lands first (here run short): %d seal(s), then %d" % [_kt.seal_mend_s, broke, b2.seals_left], broke == _kt.seals - 1 and b2.seals_left == _kt.seals)
	await _drop(main)


# --- The decoy and the cloak. ---

func _decoy_checks() -> void:
	var main := await _lab(Vector3(0.0, 0.95, 15.0))
	var ice := _ice(main)
	var br := _breakers(main)
	var life := _life(main)
	var player = main.get_node("Player")
	await _unprotect(main)
	ice.start_round(4)
	var b := _out_now(ice, 3)
	player.global_position = b.global_position + Vector3(0.0, 0.95, 9.0)
	_face(player, b.global_position)
	var hunting := await _wait(func(): return is_instance_valid(b) and b.brain.prey == 1, 60)
	# Its pace while it hunts, under a running player's.
	var from := b.global_position
	await _frames(30)
	var pace := Vector2(b.global_position.x - from.x, b.global_position.z - from.z).length() / 0.5
	# A decoy thrown aside: it goes after it, and the player walks away untouched.
	player.rotation.y += deg_to_rad(80.0)
	br.mine.loaded = D
	br.press_run()
	var pulled := await _wait(func(): return is_instance_valid(b) and b.brain.prey < 0, 200)
	if await _gone(b, main, "acceptance: a decoy pulls it off the player", "pulled %d" % pulled):
		return
	player.global_position = b.global_position + Vector3(0.0, 0.95, 4.0)
	await _frames(int(_bt.decoy_s * 60.0 * 0.6))
	if await _gone(b, main, "acceptance: a decoy pulls it off the player and the player beside it is never touched", "pulled %d" % pulled):
		return
	var gap := Vector2(player.global_position.x - b.global_position.x, player.global_position.z - b.global_position.z).length()
	_check("acceptance: it hunts the player at %.1f m/s (slower than a running player's 7) and a decoy pulls it off: it goes after the decoy and the player beside it is never touched while the decoy calls (%.1f m apart)" % [pace, gap], hunting >= 0 and pace <= _kt.speed + 0.2 and pace < 7.0 and pulled >= 0 and life.alive() and ice.flatlines == 0, "hunting %d pulled %d prey %d" % [hunting, pulled, b.brain.prey])
	await _drop(main)


func _cloak_checks() -> void:
	var main := await _lab(Vector3(0.0, 0.95, 15.0))
	var ice := _ice(main)
	var br := _breakers(main)
	var player = main.get_node("Player")
	await _unprotect(main)
	ice.start_round(4)
	var b := _out_now(ice, 3)
	player.global_position = b.global_position + Vector3(0.0, 0.95, 11.0)
	var hunting := await _wait(func(): return is_instance_valid(b) and b.brain.prey == 1, 60)
	br.mine.loaded = C
	br.press_run()
	await _frames(3)
	player.global_position = b.global_position + Vector3(9.0, 0.95, 9.0)  # cloaked, the player slips aside
	await _wait(func(): return is_instance_valid(b) and b.brain.prey != 1, int(_bt.cloak_s * 60.0) - 60)
	await _frames(30)
	var lost: bool = b.brain.prey != 1 and b.brain.drifting_to == 0
	var unseen: bool = b.brain._spot(ice.daemons) == 0
	_check("acceptance: a cloak hides the player from it as from the hunter: unseen, it loses the player and never drifts to a cloaked one", hunting >= 0 and lost and unseen and br.cloaked(1), "prey %d drifting %d" % [b.brain.prey, b.brain.drifting_to])
	var found := await _wait(func(): return is_instance_valid(b) and (b.brain.prey == 1 or b.brain.drifting_to == 1), int(_bt.cloak_s * 60.0) + 120)
	_check("the cloak over, it finds the player again (by sight, or drifting toward the nearest)", found >= 0)
	await _drop(main)


# --- The AI guide. ---

func _pick_checks() -> void:
	var main := await _lab(Vector3(0.0, 0.95, 15.0))
	var ice := _ice(main)
	var br := _breakers(main)
	ice.start_round(4)
	var b := _out_now(ice, 3)
	await _frames(2)
	var n := Pick.numbers(br)
	var request = Request.build(n, "", 0)
	var kept: bool = request.stats.size() == n.size()
	for key in n:
		kept = kept and Request.STATS.has(key) and request.stats.has(key) and request.stats[key] == n[key]
	var prompt: String = request.full_prompt()
	var clean := not prompt.contains("/") and not prompt.contains("\\") and not prompt.contains("res:") and not prompt.contains("user:")
	print("BLACK ICE pick: %s" % request.stats_line())
	_check("acceptance: its numbers ride in the guide's whitelist (out, seals standing, how far, a flatline this round: numbers only) and, while it is out, the game's own fixed line asks for the decoy or the combo", kept and clean and n["black_ice_out"] == 1 and n["black_ice_seals"] == _kt.seals and n["black_ice_distance_m"] > 0 and n["black_ice_flatlined"] == 0 and request.preamble().ends_with(Request.BLACK_ICE_LINE) and Array(n.keys()) == Pick.KEYS, request.stats_line())
	var picks := [Pick.scripted({"black_ice_out": 1, "black_ice_seals": 2, "breakers_exploit": 1, "breakers_brute": 2, "breakers_decoy": 1})[0],
		Pick.scripted({"black_ice_out": 1, "black_ice_seals": 2, "breakers_exploit": 1, "breakers_brute": 1, "breakers_decoy": 1})[0],
		Pick.scripted({"black_ice_out": 1, "black_ice_seals": 1, "breakers_exploit": 1, "breakers_brute": 1})[0],
		Pick.scripted({"black_ice_out": 1, "breakers_cloak": 1})[0],
		Pick.scripted({"black_ice_out": 1})[0],
		Pick.scripted({"black_ice_out": 0, "hunter_out": 1, "breakers_exploit": 1})[0]]
	var line: String = main.get_node("Hud").black_ice_hud().out_text()[1] if main.get_node("Hud").black_ice_hud().out_text().size() > 1 else ""
	_check("acceptance: while it is out the scripted guide recommends the combo when the brutes cover its seals, else the decoy, else the cloak, else running (\"%s\")" % line, picks == ["exploit", "decoy", "exploit", "cloak", "", "exploit"] and line.begins_with("scripted guide: Black ICE:"), str(picks))
	await _drop(main)
	# On T with a stub AI (never a real call): Enter alone asks, and the numbers and the line go with it.
	var holder := {}
	var link := _stub_link({"answer": "Load decoy: it cannot be shot."}, holder)
	var ai_main := await _lab(Vector3(0.0, 0.95, 15.0), true, link)
	var ai_ice := _ice(ai_main)
	ai_ice.start_round(4)
	_out_now(ai_ice, 3)
	var guide = ai_main.get_node("Hud").guide()
	await _frames(3)
	var stub = holder.get("stub")
	guide.open_ask()
	guide._send("")
	var asked := await _wait(func(): return stub != null and stub.ask_calls >= 1, 120)
	var stats: Dictionary = stub.last_stats if stub != null else {}
	_check("acceptance: on T (a stub adapter, never a real AI call) the AI is asked with Black ICE's numbers and its line while the link only shows cut (cosmetic: the call still goes)", asked >= 0 and int(stats.get("black_ice_out", 0)) == 1 and stub.last_preamble.contains(Request.BLACK_ICE_LINE) and guide.link_cut(), str(stats.keys()))
	await _drop(ai_main)


func _now() -> int:
	return _fake_now


func _found() -> Found:
	var f := Found.new()
	f.agent_state = Found.AgentState.KNOWN
	f.agent = "claude"
	f.agent_cli_present = true
	Detector.resolve(f)
	return f


## A started link with a fake detector and a stub adapter, its settings (consent given) in the test
## folder. holder["stub"] is the stub. Nothing real is run or reached.
func _stub_link(spec: Dictionary, holder: Dictionary) -> Link:
	var path := _tmp.path_join("stub-%d.cfg" % _checks)
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


# --- The HUD. ---

func _hud_checks() -> void:
	var main := await _lab(Vector3(0.0, 0.95, 15.0))
	var ice := _ice(main)
	var hud = main.get_node("Hud").black_ice_hud()
	var guide = main.get_node("Hud").guide()
	ice.start_round(4)
	var b := ice.summon_black(3)
	var ok := true
	var notes := PackedStringArray()
	for size in [Vector2i(960, 540), Vector2i(1280, 720)]:
		root.size = size
		b.phase = BlackIce.Phase.ARRIVE
		b.phase_t = 1.5
		await _frames(3)
		var screen := Rect2(Vector2.ZERO, Vector2(size))
		var rects := [hud._title.get_global_rect(), hud._what.get_global_rect(), hud._forms.get_global_rect()]
		var column: Rect2 = guide._column.get_global_rect()
		for r in rects:
			ok = ok and screen.encloses(r) and not r.intersects(column)
		b.phase = BlackIce.Phase.OUT
		b.phase_t = 0.5
		await _frames(3)
		var out: Rect2 = hud._out.get_global_rect().merge(hud._guide.get_global_rect())
		ok = ok and screen.encloses(out) and not out.intersects(column) and hud.out_text().size() == 2
		# Its tag: over it from afar, never into the out line; hidden when it is near and in view.
		var player = main.get_node("Player")
		for far in [16.0, 4.0]:
			player.global_position = b.global_position + Vector3(0.0, 0.95, far)
			_face(player, b.global_position + Vector3.UP * 2.4)
			player.get_node("Head").rotation.x = 0.35 if far < 5.0 else 0.0
			await _frames(3)
			var tag: Rect2 = hud._tag.get_global_rect() if hud.tag_text() != "" else Rect2()
			ok = ok and (hud.tag_text() != "" if far > 10.0 else hud.tag_text() == "") and not tag.intersects(out)
			notes.append("%.0f m tag '%s'" % [far, hud.tag_text()])
		player.get_node("Head").rotation.x = 0.0
		notes.append("%dx%d warning %s out %s" % [size.x, size.y, rects[1].size, out.size])
	root.size = Vector2i(1280, 720)
	_check("acceptance: the warning and its line fit the screen at 960x540 and 1280x720, clear of the guide's corner; its tag stands over it from afar, never into its line, and hides when it is near and in view", ok, " | ".join(notes))
	await _drop(main)


# --- Practice and the ICE switch. ---

func _off_checks() -> void:
	GameSettings.current().set_value("gameplay", "practice", true)
	var main := await _lab(Vector3(0.0, 0.95, 15.0), true, null, true)
	var ice := _ice(main)
	ice.start_round(4)
	var none_practice: bool = ice.summon_black(3) == null and ice.black_plan < 0.0 and not ice.black_out()
	GameSettings.current().set_value("gameplay", "practice", false)
	GameSettings.current().set_value("gameplay", "ice", false)
	await _frames(3)
	ice.start_round(4)
	var none_off: bool = ice.summon_black(3) == null and ice.black_plan < 0.0
	GameSettings.current().set_value("gameplay", "ice", true)
	await _frames(3)
	ice.start_round(4)
	var on: bool = ice.black_plan >= 0.0
	var b := _out_now(ice, 3)
	GameSettings.current().set_value("gameplay", "ice", false)
	await _frames(3)
	var gone: bool = ice.black == null and not is_instance_valid(b) or (is_instance_valid(b) and b.is_queued_for_deletion())
	await _frames(2)
	_check("acceptance: practice turns Black ICE off and the ICE switch turns it off (none planned, none comes, one out goes with the switch and the lights come back)", none_practice and none_off and on and gone and main.get_node(Blackout.NODE_NAME).level == 1.0, "%s %s %s %s" % [none_practice, none_off, on, gone])
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
	var hi: IceDirector = host["main"].get_node(IceDirector.NODE_NAME)
	var ci: IceDirector = client["main"].get_node(IceDirector.NODE_NAME)
	var hb: BreakerDirector = host["main"].get_node(BreakerDirector.NODE_NAME)
	var cb: BreakerDirector = client["main"].get_node(BreakerDirector.NODE_NAME)
	var hs = host["session"]
	var cs = client["session"]
	var cid: int = cs.my_id
	for main in [host["main"], client["main"]]:
		for dummy in main.get_node("Arena/Targets").get_children():
			_park(dummy)
	host["player"].global_position = host["main"].to_global(Vector3(15.0, 0.95, 15.0))
	client["player"].global_position = client["main"].to_global(Vector3(-15.0, 0.95, 15.0))
	await _wait(func(): return not hs.combat.protected(cid) and not hs.combat.protected(1), 300)
	hi.start_round(4)
	var hb_black := hi.summon_black(3)
	var drawn := await _wait(func(): return ci.black != null and ci.black.phase == BlackIce.Phase.ARRIVE, 120)
	await _frames(int(_kt.dim_s * 60.0) + 10)
	var c_blackout: Blackout = client["main"].get_node(Blackout.NODE_NAME)
	_check("acceptance: in a match the host decides Black ICE and the joiner draws it from the host's word: the same build (the host's seed), its arrival, the joiner's lights down and its guide's link cut", drawn >= 0 and ci.black.build_seed == hb_black.build_seed and ci.follows() and hi.decides() and absf(c_blackout.level - _kt.lights_low) < 0.01 and client["main"].get_node("Hud").guide().link_cut() and cs.black_words > 0)
	# Out, it hunts; the joiner touched is flatlined on both screens, held out until the host's next round.
	hb_black.phase_t = _kt.tell_s
	await _frames(3)
	var near: Vector3 = host["main"].to_local(hb_black.global_position)
	client["player"].global_position = client["main"].to_global(near + Vector3(0.8, 0.95, 0.0))
	var flat := await _wait(func(): return hs.flatlined(cid) and cs.flatlined(cid) and cs.dead.get(cid, false), 120)
	var banner: String = client["main"].get_node("Hud").combat_hud().banner_text() if client["main"].get_node("Hud").combat_hud().has_method("banner_text") else ""
	await _frames(int(hs.combat_tuning_in_use().respawn_delay_s * 60.0) + 60)
	var held: bool = hs.dead.get(cid, false) and not hs.combat.alive(cid) and cs.flatlined(cid)
	var top_up: bool = client["main"].get_node("Hud").spectate_top().is_showing()
	_check("acceptance: in a match its touch flatlines the joiner on both screens (\"%s\") and holds it out for the rest of the round, spectating as top, with no respawn countdown" % banner.replace("\n", " "), flat >= 0 and held and banner.contains("FLATLINED") and banner.contains("out until the round ends") and top_up, "flat %d held %s top %s" % [flat, held, top_up])
	hi._on_round_ended(4)
	hi.start_round(5)
	var back := await _wait(func(): return hs.combat.alive(cid) and not cs.dead.get(cid, false) and not cs.flatlined(cid), 180)
	_check("acceptance: the host's next round brings the flatlined joiner back", back >= 0)
	# The joiner's own combo, its asks judged by the host: the host's Black ICE dies on both screens.
	await _wait(func(): return ci.black == null and hi.black == null, 240)
	await _wait(func(): return not hs.combat.protected(cid), 300)
	var kb := hi.summon_black(3)
	kb.phase_t = _kt.tell_s
	(hb.loadouts[cid] as Breakers).counts = PackedInt32Array([2, 1, 0, 1])
	await _wait(func(): return cb.mine.count(B) == 2 and ci.black != null, 120)
	# A decoy of the host's pins it, so the joiner can come close.
	host["player"].global_position = host["main"].to_global(Vector3(3.0, 0.95, 7.0))
	_face(host["player"], kb.global_position)
	hb.mine.loaded = D
	hb.press_run()
	await _wait(func(): return is_instance_valid(kb) and kb.brain.prey < 0, 200)
	await _frames(90)
	var at: Vector3 = host["main"].to_local(kb.global_position)
	client["player"].global_position = client["main"].to_global(at + Vector3(-3.1, 0.95, 0.0))
	_face(client["player"], client["main"].to_global(at + Vector3(0.0, 1.5, 0.0)))
	await _frames(20)
	cb.mine.loaded = E
	cb.press_run()
	var ran := await _wait(func(): return float(hb.exploit_left.get(cid, 0.0)) > 0.0, 120)
	await _gap()
	cb.mine.loaded = B
	cb.press_run()
	var one := await _wait(func(): return is_instance_valid(kb) and kb.seals_left == _kt.seals - 1, 120)
	await _gap()
	var close := await _wait(func():
		var c: Vector3 = client["main"].to_local(client["player"].global_position)
		if not is_instance_valid(kb):
			return false
		var k: Vector3 = host["main"].to_local(kb.global_position)
		return Vector2(c.x - k.x, c.z - k.z).length() < 4.2 and kb.brain.state != DaemonBrain.State.SCATTER, 240)
	var k2: Vector3 = host["main"].to_local(kb.global_position)
	_face(client["player"], client["main"].to_global(k2 + Vector3(0.0, 1.5, 0.0)))
	await _frames(12)
	cb.mine.loaded = B
	cb.press_run()
	var killed := await _wait(func(): return is_instance_valid(kb) and kb.broken and (ci.black == null or ci.black.broken), 180)
	_check("acceptance: a joiner's combo is judged by the host (its exploit, then its brutes from where the host last heard its eye): the seals break and Black ICE dies in the host's world and on the joiner's screen", ran >= 0 and one >= 0 and close >= 0 and killed >= 0 and hi.blacks_killed == 1, "ran %d one %d close %d killed %d seals %d" % [ran, one, close, killed, kb.seals_left])
	await _drop_side(client)
	await _drop_side(host)


# --- Harness. ---

## A fresh arena, practice off and ICE on, every daemon parked under the floor and the player at
## `player_at`, its round long enough that no round's end (which withdraws Black ICE) comes in a check. A
## demo link (`demo`), or a guarded one (no AI linked), or `with_link`.
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
	main.get_node("Hud").round_hud()._left_s = LONG_ROUND_S
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
	main.get_node("Hud").round_hud()._left_s = LONG_ROUND_S
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
