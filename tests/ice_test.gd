extends SceneTree
## Headless test of I1's ICE (white ICE and hunter ICE) for SIGKILL. scripts/check.sh runs it as step
## 40, and any FAIL exits 1.
##
##   godot --headless --path . --fixed-fps 60 --script res://tests/ice_test.gd
##
## The colours: glacier and the hunter's cobalt read apart (OKLab) from the player's teal, the rail's
## ice-white, ping's lime, every daemon's colour and grep's cobalt. Built alone: the same seed builds the
## same wall, node and hunter, part for part; other seeds build others. In the real arena, ICE on: the
## gate seals the room's doorway (sight, movement and the level's rays stop at it, shots land on it)
## until its damage threshold breaks it, never sooner, no hit taking more than the cap, its cracks
## deepening and panes falling as it goes; then the way is open. Each node's field fires only at its
## tell's end (at least a second, its dome and its swell showing through it): the jam locks the weapon
## in hand (another still swaps in and fires) and clears after its time, the HUD corruption scrambles
## the HUD but never the health line and clears after its time, and a player out of the dome at the
## tell's end escapes it. The hunter: none in round 1, one from round 2; it hunts by sight and tells
## before its lance (its trace locking still for the lock's last part), a player standing still is
## hit and one who steps aside in the lock is missed; its resistance tracks the weapon with the most
## damage this round (daemons and ICE alike), caps at the tuning's maximum (never immunity), shows on
## the HUD and in its shields' colour, and resets with the round. Practice and the ICE setting each
## turn every piece off and back on. The credit tag. Then a host and a joiner over ENet on 127.0.0.1:
## the joiner's pieces are the host's builds and follow its word (a wall's damage, its break, a node's
## tell and field, the hunter's place, state and adaptation), a joiner's shot lands nothing on its own
## copy while the host's judging of it lands, a field reaching the joiner jams it there and the host
## refuses that weapon; the host's ICE setting rules the joiner's. Protocol 12.
## Deterministic: frames counted, only counts and outcomes printed.

const Session = preload("res://scripts/net/net_session.gd")
const NetTuningScript = preload("res://scripts/net/net_tuning.gd")
const Link = preload("res://scripts/guide/guide_link.gd")
const MainScene = preload("res://scenes/main.tscn")
const Dummy = preload("res://scripts/target_dummy.gd")
const Controls = preload("res://scripts/controls.gd")
const Palette = preload("res://scripts/palette.gd")
const Inventory = preload("res://scripts/weapons/inventory.gd")
const ICE_DIR := "res://scripts/ice/"
const WATCHDOG_MS := 12000
const CLIENT_OFFSET := Vector3(1000.0, 0.0, 0.0)
const PARKED := Vector3(0.0, -50.0, 0.0)
## The least OKLab distance an ICE colour keeps from every colour it must read apart from.
const APART := 0.12
## Builds sampled for the seeds' variety.
const BUILDS := 12

var _fails := 0
var _checks := 0
var _tmp := ""
var _arenas: Array = []
var _branches: Array = []
var _scratch: Array = []
var _t: IceTuning


func _initialize() -> void:
	_run()


func _run() -> void:
	await process_frame
	root.size = Vector2i(1280, 720)
	_tmp = OS.get_temp_dir().path_join("sigkill-ice-test-%d" % OS.get_process_id())
	if DirAccess.dir_exists_absolute(_tmp):
		print("FAIL the test's temporary folder already exists; not touching it")
		quit(1)
		return
	DirAccess.make_dir_recursive_absolute(_tmp)
	Controls.ensure()
	GameSettings.current().reset()
	_t = load("res://resources/ice.tres") as IceTuning
	_source_checks()
	_palette_checks()
	await _seed_checks()
	await _barrier_checks()
	await _field_checks()
	await _hunter_checks()
	await _adapt_checks()
	await _off_checks()
	await _match_checks()
	await _cleanup()
	for name in DirAccess.get_files_at(_tmp):
		DirAccess.remove_absolute(_tmp.path_join(name))
	DirAccess.remove_absolute(_tmp)
	print("ICE: %d checks" % _checks)
	print("ICE RESULT: ", "ALL PASS" if _fails == 0 else "%d FAILED" % _fails)
	quit(0 if _fails == 0 else 1)


func _check(label: String, ok: bool, detail: String = "") -> void:
	_checks += 1
	print("PASS " if ok else "FAIL ", label, ("   " + detail) if detail != "" else "")
	if not ok:
		_fails += 1


# --- The sources and the tuning. ---

func _source_checks() -> void:
	var session := _code("res://scripts/net/net_session.gd")
	var told := _body(session, "_ice")
	var effect := _body(session, "_ice_effect")
	var fire := _body(session, "_handle_fire")
	_check("acceptance: in a match the host runs ICE and sends its word: a new state message (the round, each piece's seed, health, word and time, the hunter's place, aim and reach, the adaptation) and a field's effect to the player it reached; the rule message carries the host's ICE setting; joiners' shots and blasts at ICE are the host's to judge; a jammed weapon's shots are refused; protocol 12 (13 since I2's ICEbreakers, 14 since I3's Black ICE, 15 since C29's chmod 000, 16 since C30's pipe |, 17 since C31's /dev/null)", Session.PROTOCOL == 17 and told.contains("seeds: PackedInt32Array") and told.contains("ice.take_word(") and effect.contains("ice.take_effect(") and _body(session, "_rules").contains("ice: bool") and _body(session, "_is_daemon").contains("IceDirector.PIECES") and _body(session, "_blast_daemons").contains("ice.blast(") and fire.contains("ice.jammed(shooter, weapon)") and fire.contains("Combat.DROP_JAM"))
	var problems := _t.problems() if _t != null else PackedStringArray(["no tuning"])
	var bad := _t.duplicate() as IceTuning
	bad.jam_tell_s = 0.5
	bad.adapt_max = 1.0
	_check("the tuning (resources/ice.tres) is sound, and refuses a tell under a second or adaptation to immunity", problems.is_empty() and bad.problems().size() == 2 and IceTuning.TELL_FIRST_S >= 1.0 and _t.jam_tell_s >= 1.0 and _t.hud_tell_s >= 1.0 and _t.hunter_tell_s >= 1.0, str(problems))
	var dummy := _code("res://scripts/target_dummy.gd")
	var player := _code("res://scripts/player.gd")
	_check("hits carry their source (I2's hook): a daemon's hit and a piece of ICE's take the weapon's id, and every weapon's hit passes it; the brute breaker's hook is in the director", dummy.contains("source: String = \"\"") and _body(dummy, "hit").contains("ice.note_damage(source, damage)") and player.contains("end_point, dir, _w.id)") and player.contains("at, dir, def.id)") and _code(ICE_DIR + "ice_piece.gd").contains("source: String = \"\"") and _code(ICE_DIR + "ice_director.gd").contains("brute_wall_scale"))


func _palette_checks() -> void:
	var others := {"teal": Palette.TEAL, "mint": Palette.MINT, "rail ice": Palette.ICE, "rail ice-white": Palette.ICE_HI, "ping lime": Palette.LIME, "crimson": Palette.CRIMSON, "amber": Palette.HOSTILE_AMBER, "magenta": Palette.HOT_MAGENTA, "grep cobalt": Palette.COBALT, "SIGTERM violet": Palette.VIOLET}
	var nearest := {}
	var ok := true
	for ice in [["glacier", Palette.GLACIER], ["cobalt", Palette.HUNTER_COBALT]]:
		var least := INF
		var near := ""
		for k in others:
			var dist := _oklab(ice[1]).distance_to(_oklab(others[k]))
			if dist < least:
				least = dist
				near = k
		nearest[ice[0]] = "%s %.3f" % [near, least]
		ok = ok and least >= APART
	var apart := _oklab(Palette.GLACIER).distance_to(_oklab(Palette.HUNTER_COBALT))
	_check("acceptance: ICE's own colours read apart: glacier #%s and the hunter's cobalt #%s each at least %.2f (OKLab) from the player's teal, the rail's ice-white, ping's lime, the three daemons' colours, grep's cobalt and SIGTERM's violet, and from each other" % [Palette.GLACIER.to_html(false), Palette.HUNTER_COBALT.to_html(false), APART], ok and apart >= APART and Palette.GLACIER.to_html(false) == "18b2ff" and Palette.HUNTER_COBALT.to_html(false) == "1e30ff", "nearest: %s; apart %.3f" % [nearest, apart])


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


# --- Built alone. ---

## The same seed builds the same piece; other seeds build others.
func _seed_checks() -> void:
	var world := _world()
	var same := PackedStringArray()
	var kinds := {}
	for type in [["barrier_art", ""], ["node_art", "jam"], ["node_art", "hud"], ["hunter_art", ""]]:
		var a := _piece_art(world, type, 9001, Vector3(-20.0, 0.0, 0.0))
		var b := _piece_art(world, type, 9001, Vector3(20.0, 0.0, 0.0))
		await _frames(30)
		var alike := a.part_count() == b.part_count() and is_equal_approx(a.size_scale, b.size_scale)
		if alike:
			for id in a.part_count():
				alike = alike and a.part_transform(id).is_equal_approx(b.part_transform(id)) and a.part_custom(id).is_equal_approx(b.part_custom(id))
		if not alike:
			same.append(type[0] + type[1])
		a.queue_free()
		b.queue_free()
		var builds := {}
		for k in BUILDS:
			var art := _piece_art(world, type, 500 + k * 7919, Vector3(0.0, 0.0, 40.0))
			await _frames(1)
			builds[_signature(art)] = true
			art.queue_free()
		kinds[type[0] + type[1]] = builds.size()
	await _frames(2)
	var varied := true
	for k in kinds:
		varied = varied and kinds[k] >= BUILDS - 2
	print("ICE seeds: distinct builds of %d seeds each: %s" % [BUILDS, kinds])
	_check("acceptance: no clones: the same seed builds the same wall, jam node, HUD node and hunter, part for part and pose for pose; %d other seeds build at least %d different ones of each" % [BUILDS, BUILDS - 2], same.is_empty() and varied, "differs: %s; %s" % [same, kinds])


## A piece's art alone in `world` at `at`, built from `seed`.
func _piece_art(world: Node3D, type: Array, seed: int, at: Vector3) -> DaemonArt:
	var art: DaemonArt = load(ICE_DIR + type[0] + ".gd").new()
	if type[0] == "barrier_art":
		art.span = Vector2(2.7, 3.5)
	elif type[0] == "node_art":
		art.kind = type[1]
	art.setup(null, seed)
	world.add_child(art)
	art.position = at
	return art


## What a build is: its part count, its size and every part's own size (its shape's three axes,
## rounded): what its seed's dice choose, never where its clock has moved it or its tone.
func _signature(art: DaemonArt) -> String:
	var bits := PackedStringArray([str(art.part_count()), "%.3f" % art.size_scale])
	for id in art.part_count():
		var basis := art.part_transform(id).basis
		bits.append("%.2f,%.2f,%.2f" % [basis.x.length(), basis.y.length(), basis.z.length()])
	return ";".join(bits)


# --- White ICE's walls. ---

func _barrier_checks() -> void:
	var main := await _lab(Vector3(0.0, 0.95, -4.0))
	var ice := _ice(main)
	var gate := ice.wall("gate")
	var wall := ice.wall("wall")
	var space: PhysicsDirectSpaceState3D = main.get_world_3d().direct_space_state
	var from: Vector3 = main.to_global(Vector3(0.0, 1.2, -4.0))
	var to: Vector3 = main.to_global(Vector3(0.0, 1.2, -12.0))
	var sight := space.intersect_ray(PhysicsRayQueryParameters3D.create(from, to, 1))
	var shot := space.intersect_ray(PhysicsRayQueryParameters3D.create(from, to, 5))
	var sealed_sight: bool = not sight.is_empty() and sight["collider"] == gate.get_node("Core")
	var shot_lands: bool = not shot.is_empty() and shot["collider"] == gate
	var player = main.get_node("Player")
	player.rotation.y = 0.0
	for f in 120:
		player.drive_input(Vector2(0.0, -1.0))
		await physics_frame
	var stopped_at: float = main.to_local(player.global_position).z
	player.drive_input(Vector2.ZERO)
	_check("acceptance: white ICE seals the room's doorway: the level's rays (sight, steps, bolts) stop at the gate, a shot's ray lands on it, and a player walking into the doorway is held outside it; the west corridor's wall stands too", ice.mode == IceDirector.Mode.RUN and gate != null and wall != null and sealed_sight and shot_lands and stopped_at > -7.7 and not gate.broken and gate.sealed() and wall.sealed(), "the player stopped at z %.2f" % stopped_at)
	# Damage: no hit takes more than the cap; it breaks at its threshold and not a hit sooner.
	var cap_taken := _t.barrier_health - (gate.health() if gate.hit(1000.0, Vector3.INF, Vector3.ZERO, "sigkill_rail") else 0.0)
	var cracks := PackedFloat32Array([gate.art.deepest_crack()])
	var whole_until := true
	var total := cap_taken
	var hits := 1
	while total + _t.hit_cap < _t.barrier_health - 0.001:
		gate.hit(_t.hit_cap, Vector3.INF, Vector3.ZERO, "terminal_cannon")
		total += _t.hit_cap
		hits += 1
		await _frames(10)
		cracks.append(gate.art.deepest_crack())
		whole_until = whole_until and gate.sealed()
	var out_before: int = gate.art.panes_out()
	var short_by := _t.barrier_health - total
	gate.hit(short_by - 1.0, Vector3.INF, Vector3.ZERO, "terminal_cannon")
	var still := gate.sealed() and gate.health() > 0.0
	await _frames(20)
	var deeper := true
	for i in range(1, cracks.size()):
		deeper = deeper and cracks[i] >= cracks[i - 1]
	gate.hit(1.0, Vector3.INF, Vector3.ZERO, "terminal_cannon")
	await _frames(5)
	var broke := gate.broken and not gate.sealed()
	sight = space.intersect_ray(PhysicsRayQueryParameters3D.create(from, to, 1))
	shot = space.intersect_ray(PhysicsRayQueryParameters3D.create(from, to, 5))
	var open: bool = (sight.is_empty() or sight["collider"] != gate.get_node("Core")) and (shot.is_empty() or shot["collider"] != gate)
	print("ICE gate: a 1000 hit took %.0f; %d hits to %.0f, cracks %s, %d panes out of %d before the last, sealed %s with %.0f left, broken %s" % [cap_taken, hits, total, ", ".join(Array(cracks).map(func(c): return "%.2f" % c)), out_before, gate.art.pane_count(), still, gate.health(), broke])
	_check("acceptance: the wall breaks at its damage threshold (%.0f) and not before: no hit takes more than the cap (%.0f, the rail's 1000 too), every hit short of it leaves it sealed, its cracks deepening with each and panes falling out of the lattice; the last point breaks it and the way is open to sight, steps and shots" % [_t.barrier_health, _t.hit_cap], is_equal_approx(cap_taken, _t.hit_cap) and whole_until and still and deeper and cracks[cracks.size() - 1] > 0.5 and out_before > 0 and broke and open)
	player.rotation.y = 0.0
	player.global_position = main.to_global(Vector3(0.0, 0.95, -4.0))
	await _frames(5)
	for f in 120:
		player.drive_input(Vector2(0.0, -1.0))
		await physics_frame
	player.drive_input(Vector2.ZERO)
	var through: float = main.to_local(player.global_position).z
	_check("broken, the gate lets the player walk through the doorway into the room", through < -9.0, "the player reached z %.2f" % through)
	await _drop(main)


# --- White ICE's nodes. ---

func _field_checks() -> void:
	var main := await _lab(Vector3(0.0, 0.95, 15.0))
	var ice := _ice(main)
	var player = main.get_node("Player")
	var hud = main.get_node("Hud")
	var jam := ice.node_of("jam")
	var corrupt := ice.node_of("hud")
	await _unprotect(main)
	# The jam: the player 5 m from the node, in sight, the cannon drawn.
	player.select_slot(0)
	await _frames(30)
	player.global_position = jam.heart() + Vector3(0.0, -0.5, 5.0)
	var told := await _wait(func(): return jam.state == IceNode.State.TELL, 60)
	var tell_frames := 0
	var early := false
	var swelling := false
	var domed := 0.0
	while jam.state == IceNode.State.TELL and tell_frames < 400:
		early = early or player.inventory.jams[player.inventory.current] > 0.0
		swelling = swelling or (jam.get("_swell") as AudioStreamPlayer3D).playing
		domed = maxf(domed, jam.dome_shown())
		tell_frames += 1
		await physics_frame
	var jammed: float = player.inventory.jams[0]
	var blocked: String = player.inventory.fire_block()
	player.select_slot(1)
	await _frames(int(ceil(0.35 * 60.0)))
	var other_fires: bool = player.inventory.fire_block() == "" or player.inventory.fire_block() == Inventory.BLOCK_COOLDOWN
	player.select_slot(0)
	await _frames(int(ceil(_t.jam_s * 60.0)) + 5)
	var cleared: bool = player.inventory.jams[0] == 0.0 and player.inventory.fire_block() != Inventory.BLOCK_JAMMED
	print("ICE jam: told after %d frames, its tell %d frames (%.2f s), the dome up to %.2f, the swell playing %s, jammed %.2f s (%s), the other weapon free %s, cleared %s" % [told, tell_frames, tell_frames / 60.0, domed, swelling, jammed, blocked, other_fires, cleared])
	_check("acceptance: the jam field fires only after its tell (%.1f s, over a second, its dome warning at the field's reach and its swell playing): nothing jams through the tell; at its end the weapon in hand is jammed (%.1f s) and cannot fire, another still swaps in and fires, and the jam clears after its time" % [_t.jam_tell_s, _t.jam_s], told >= 0 and not early and tell_frames >= roundi(_t.jam_tell_s * 60.0) - 1 and tell_frames <= roundi(_t.jam_tell_s * 60.0) + 1 and domed > 0.5 and swelling and jammed > _t.jam_s - 0.05 and jammed <= _t.jam_s + 0.001 and blocked == Inventory.BLOCK_JAMMED and other_fires and cleared and ice.jams_on_me == 1)
	# The HUD corruption, from the other node; the jam node's field far off.
	player.global_position = main.to_global(Vector3(0.0, 0.95, 15.0))
	await _frames(int(ceil(_t.jam_cooldown_s * 60.0)))
	player.global_position = corrupt.heart() + Vector3(4.0, -0.5, 0.0)
	var t2 := await _wait(func(): return corrupt.state == IceNode.State.TELL, 60)
	var hud_early := false
	var hud_frames := 0
	while corrupt.state == IceNode.State.TELL and hud_frames < 400:
		hud_early = hud_early or ice.corrupting()
		hud_frames += 1
		await physics_frame
	await _frames(2)
	var ice_hud = hud.ice_hud()
	var covers: Array = ice_hud.drawn_rects().duplicate()
	var keep: Rect2 = ice_hud.health_rect()
	var spares_health := keep.size != Vector2.ZERO
	for r in covers:
		spares_health = spares_health and not (r as Rect2).intersects(keep)
	var health_shown: bool = hud.combat_hud().line_text().begins_with("health")
	var left: float = ice.corrupt_left
	await _frames(int(ceil(_t.hud_s * 60.0)) + 5)
	var gone: bool = not ice.corrupting() and ice_hud.drawn_rects().is_empty()
	print("ICE HUD: told after %d frames, its tell %d frames, %.2f s left as it fired, %d parts covered, the health line '%s' clear of them %s, gone after %s" % [t2, hud_frames, left, covers.size(), hud.combat_hud().line_text(), spares_health, gone])
	_check("acceptance: the HUD field fires only after its tell (%.1f s): nothing is corrupted through it; at its end parts of the HUD are scrambled (%.0f s) but never the health line, which stays shown, and it clears after its time" % [_t.hud_tell_s, _t.hud_s], t2 >= 0 and not hud_early and hud_frames >= roundi(_t.hud_tell_s * 60.0) - 1 and left > _t.hud_s - 0.1 and covers.size() >= 3 and spares_health and health_shown and gone and ice.corruptions_on_me == 1)
	# Fair: out of the dome (or behind cover) at the tell's end, nothing lands.
	player.global_position = main.to_global(Vector3(0.0, 0.95, 15.0))
	await _frames(int(ceil(_t.jam_cooldown_s * 60.0)))
	player.global_position = jam.heart() + Vector3(0.0, -0.5, 5.0)
	await _wait(func(): return jam.state == IceNode.State.TELL, 60)
	player.global_position = jam.heart() + Vector3(0.0, -0.5, _t.jam_field_m + 1.5)
	await _wait(func(): return jam.state == IceNode.State.FIELD, 200)
	await _frames(3)
	_check("acceptance: fair: a player who steps out of the dome during the tell is not jammed when it fires", jam.fires >= 2 and player.inventory.jams[player.inventory.current] == 0.0 and ice.jams_on_me == 1, "fired %d times" % jam.fires)
	# A node can be broken: its field gone with it.
	var broke: bool = jam.hit(1000.0, Vector3.INF, Vector3.ZERO, "rm_rf_cannon") and jam.hit(1000.0, Vector3.INF, Vector3.ZERO, "rm_rf_cannon")
	await _frames(int(ceil(_t.jam_cooldown_s * 60.0)))
	player.global_position = jam.heart() + Vector3(0.0, -0.5, 4.0)
	await _frames(120)
	_check("a node breaks under enough damage (%.0f, two capped hits) and its field never fires again" % _t.node_health, broke and jam.broken and jam.state == IceNode.State.IDLE and player.inventory.jams[player.inventory.current] == 0.0)
	await _drop(main)


# --- Hunter ICE. ---

func _hunter_checks() -> void:
	var main := await _lab(Vector3(0.0, 0.95, 15.0))
	var ice := _ice(main)
	var none_first := ice.hunter == null and ice.round_number == 1
	ice.start_round(2)
	var hunter := ice.hunter
	var posted: bool = hunter != null and main.to_local(hunter.global_position).distance_to(IceDirector.HUNTER_POST) < 0.01
	await _frames(2)
	_check("acceptance: spawning: white ICE from round 1, no hunter in it; one hunter from round 2, at its post", none_first and posted and is_instance_valid(hunter) and ice.walls.size() == 2 and ice.nodes.size() == 2, "first %s, posted %s" % [none_first, posted])
	var player = main.get_node("Player")
	var life = _life(main)
	await _unprotect(main)
	# Standing still in its sight: it hunts, tells (its trace following, then held), and its lance hits.
	player.global_position = main.to_global(Vector3(10.0, 0.95, 8.0))
	var hunted := await _wait(func(): return hunter.brain.state == DaemonBrain.State.TELL, 600)
	var aim_start: Vector3 = hunter.brain.aim
	var before: float = life.health()
	var struck := await _wait(func(): return hunter.brain.state == DaemonBrain.State.STRIKE, 200)
	await _frames(3)
	var hit_still: bool = life.health() < before and hunter.brain.lance_hits == 1
	print("ICE hunter: telling after %d frames, struck %d frames later; the lance took %.0f" % [hunted, struck, before - life.health()])
	_check("acceptance: the hunter tracks the player by sight and tells before its lance (%.1f s, its trace following, then held still for the lock's last %.2f s): a player standing still is struck (%.0f before the difficulty)" % [_t.hunter_tell_s, _t.hunter_lock_s, _t.hunter_damage], hunted >= 0 and struck >= roundi((_t.hunter_tell_s) * 60.0) - 2 and hit_still and is_equal_approx(before - life.health(), _t.hunter_damage))
	# Stepping aside in the lock: missed.
	await _wait(func(): return hunter.brain.state == DaemonBrain.State.TELL, 600)
	await _wait(func(): return hunter.brain.state_t >= _t.hunter_tell_s - _t.hunter_lock_s + 0.05, 200)
	var held: Vector3 = hunter.brain.aim
	var side: Vector3 = held.cross(Vector3.UP).normalized()
	player.global_position += side * 2.5
	var hp: float = life.health()
	await _wait(func(): return hunter.brain.state == DaemonBrain.State.STRIKE, 60)
	await _frames(3)
	_check("acceptance: fair: in the lock the trace holds still, and a player who steps aside then is missed", hunter.brain.aim.is_equal_approx(held) and life.health() == hp and hunter.brain.lances >= 2 and hunter.brain.lance_hits == 1, "lances %d, hits %d" % [hunter.brain.lances, hunter.brain.lance_hits])
	# A ping meeting it mid-tell staggers it, as it does a daemon (C28): its lance never comes.
	player.select_slot(player.inventory.slot_of("ping_sonar"))
	await _wait(func(): return hunter.brain.state == DaemonBrain.State.TELL, 600)
	player.drive_input(Vector2.ZERO, false, false, true)
	await physics_frame
	player.drive_input(Vector2.ZERO)
	var lances_before := hunter.brain.lances
	var staggered := await _wait(func(): return hunter.brain.staggers >= 1, 60)
	await _frames(int(ceil(_t.hunter_tell_s * 60.0)))
	_check("a ping meeting the hunter mid-tell staggers it, as it does a daemon (C28): the tell is called off and no lance comes", staggered >= 0 and hunter.brain.lances == lances_before, "staggered after %d frames" % staggered)
	# Killed, it is gone for its wait, then a new one comes.
	var first := hunter.build_seed
	hunter.hit(1000.0, Vector3.INF, Vector3.ZERO, "sigkill_rail")
	hunter.hit(1000.0, Vector3.INF, Vector3.ZERO, "rm_rf_cannon")
	hunter.hit(1000.0, Vector3.INF, Vector3.ZERO, "cron_mines")
	var down := hunter.broken
	var back := await _wait(func(): return ice.hunter != null and is_instance_valid(ice.hunter) and not ice.hunter.broken, int(_t.hunter_respawn_s * 60.0) + 30)
	_check("a killed hunter is gone for its wait (%.0f s), then a new one comes from its post" % _t.hunter_respawn_s, down and back >= int(_t.hunter_respawn_s * 60.0) - 2 and ice.hunters_killed == 1 and ice.hunters_made == 2 and is_instance_valid(ice.hunter) and ice.hunter != hunter, "back after %d frames (seed %d, fixed by name: the same build %s)" % [back, first, ice.hunter.build_seed == first if ice.hunter != null else false])
	await _drop(main)


func _adapt_checks() -> void:
	var main := await _lab(Vector3(0.0, 0.95, 15.0))
	var ice := _ice(main)
	var hud = main.get_node("Hud")
	ice.start_round(2)
	await _frames(2)
	var hunter := ice.hunter
	# The hunter far from the player: nothing hunts here.
	hunter.global_position = main.to_global(Vector3(15.0, 0.0, -15.0))
	hunter.brain.take_home()
	var cobalt := hunter.shield_color
	# Cannon kills of the four daemons: the system notes them.
	for name in ["DummyA", "DummyB", "DummyC", "DummyD"]:
		main.get_node("Arena/Targets/" + name).hit(25.0, Vector3.INF, Vector3.ZERO, "terminal_cannon")
	var early: int = ice.adapt_percent()
	for i in 16:
		ice.wall("wall").hit(25.0, Vector3.INF, Vector3.ZERO, "terminal_cannon")
	await _frames(2)
	var mid: int = ice.adapt_percent()
	var line: String = hud.ice_hud().adapt_line()
	var health := hunter.health()
	hunter.hit(25.0, Vector3.INF, Vector3.ZERO, "terminal_cannon")
	var resisted := health - hunter.health()
	for i in 40:
		ice.note_damage("terminal_cannon", 100.0)
	var capped: int = ice.adapt_percent()
	health = hunter.health()
	hunter.hit(25.0, Vector3.INF, Vector3.ZERO, "terminal_cannon")
	var at_cap := health - hunter.health()
	health = hunter.health()
	hunter.hit(25.0, Vector3.INF, Vector3.ZERO, "sigterm")
	var other := health - hunter.health()
	var tinted := hunter.shield_color
	await _frames(2)
	var cap_line: String = hud.ice_hud().adapt_line()
	print("ICE adaptation: %d%% after 100 on daemons, %d%% after 500 (line '%s', a cannon hit took %.2f), %d%% capped (a cannon hit %.2f, SIGTERM %.2f), shields %s from %s" % [early, mid, line, resisted, capped, at_cap, other, tinted.to_html(false), cobalt.to_html(false)])
	_check("acceptance: the hunter adapts to the weapon dealt the most damage this round (hits on daemons and on ICE alike) and builds resistance to it, shown on the HUD (\"HUNTER ADAPTED: cannon -NN%%\") and in its shields shifting from cobalt toward that weapon's colour", early == 10 and mid == 50 and line == "HUNTER ADAPTED: cannon -50%" and is_equal_approx(resisted, 12.5) and ice.adapt_weapon == "terminal_cannon" and tinted.is_equal_approx(ice.adapt_color()) and _closer(tinted, Palette.TEAL, Palette.HUNTER_COBALT) and not tinted.is_equal_approx(cobalt))
	_check("acceptance: it caps at the tuning's maximum (%d%%), never immunity: a cannon hit still takes half, another weapon's all of it" % roundi(_t.adapt_max * 100.0), capped == roundi(_t.adapt_max * 100.0) and is_equal_approx(at_cap, 25.0 * (1.0 - _t.adapt_max)) and is_equal_approx(other, 25.0) and cap_line == "HUNTER ADAPTED: cannon -50%")
	# Another weapon overtakes: it follows the one with the most.
	for i in 60:
		ice.note_damage("sigterm", 100.0)
	await _frames(2)
	var switched: bool = ice.adapt_weapon == "sigterm" and hud.ice_hud().adapt_line() == "HUNTER ADAPTED: SIGTERM -50%" and _closer(hunter.shield_color, Palette.VIOLET, Palette.TEAL)
	# A new round forgets it.
	ice.start_round(3)
	await _frames(2)
	var reset: bool = ice.ledger.is_empty() and ice.adapt_percent() == 0 and hud.ice_hud().adapt_line() == "" and ice.hunter != null and ice.hunter.shield_color.is_equal_approx(Palette.HUNTER_COBALT)
	_check("acceptance: it tracks the weapon with the most damage as that changes (SIGTERM overtaking the cannon), and resets each round: the next round's hunter starts cobalt with nothing learned", switched and reset)
	_check("the credit tag shows on ICE's HUD while ICE is on: \"ICE design: @TimProvencio\"", hud.ice_hud().credit_text() == "ICE design: @TimProvencio")
	await _drop(main)


## True when `c` is nearer `to` than `than` (RGB).
static func _closer(c: Color, to: Color, than: Color) -> bool:
	return Vector3(c.r - to.r, c.g - to.g, c.b - to.b).length() < Vector3(c.r - than.r, c.g - than.g, c.b - than.b).length()


# --- Off. ---

func _off_checks() -> void:
	var main := await _lab(Vector3(0.0, 0.95, 15.0))
	var ice := _ice(main)
	var on := ice.pieces().size() == 4 and get_nodes_in_group(IceDirector.PIECES).size() == 4
	GameSettings.current().set_value("gameplay", "practice", true)
	await _frames(3)
	var practice_off := ice.mode == IceDirector.Mode.OFF and ice.pieces().is_empty() and get_nodes_in_group(IceDirector.PIECES).is_empty()
	var space: PhysicsDirectSpaceState3D = main.get_world_3d().direct_space_state
	var open := space.intersect_ray(PhysicsRayQueryParameters3D.create(main.to_global(Vector3(0.0, 1.2, -4.0)), main.to_global(Vector3(0.0, 1.2, -12.0)), 1)).is_empty()
	GameSettings.current().set_value("gameplay", "practice", false)
	await _frames(3)
	var back := ice.mode == IceDirector.Mode.RUN and ice.pieces().size() == 4
	GameSettings.current().set_value("gameplay", "ice", false)
	await _frames(3)
	var setting_off: bool = ice.mode == IceDirector.Mode.OFF and ice.pieces().is_empty() and main.get_node("Hud").ice_hud().credit_text() == ""
	GameSettings.current().set_value("gameplay", "ice", true)
	await _frames(3)
	var again := ice.mode == IceDirector.Mode.RUN and ice.pieces().size() == 4
	var menu = main.get_node("Hud").pause_menu()
	var row: bool = menu.get("_rows").has("gameplay/ice")
	_check("acceptance: practice turns ICE off (no wall, node or hunter; the doorway open) and back on; the ICE setting (on by default, in Settings beside the difficulty) does the same; the daemons keep working as before", on and practice_off and open and back and setting_off and again and row and GameSettings.current().value("gameplay", "ice") == true)
	await _drop(main)


# --- A match. ---

func _match_checks() -> void:
	GameSettings.current().set_value("gameplay", "practice", false)
	GameSettings.current().set_value("gameplay", "ice", true)
	var host := _branch("Host", Vector3.ZERO)
	var client := _branch("Client", CLIENT_OFFSET)
	await _frames(2)
	var joined := await _join(host, client)
	var hs = host["session"]
	var cs = client["session"]
	await _wait(func(): return cs.host_practice == false and cs.host_ice == true, 120)
	var hi := _ice(host["main"])
	var ci := _ice(client["main"])
	host["player"].global_position = host["main"].to_global(Vector3(15.0, 0.95, 15.0))
	client["player"].global_position = client["main"].to_global(Vector3(14.0, 0.95, 16.0))
	for name in ["DummyA", "DummyB", "DummyC", "DummyD"]:
		_park(host["main"].get_node("Arena/Targets/" + name))
	Dummy.fixed_seeds = false
	hi.start_round(2)
	Dummy.fixed_seeds = true
	hi.black_plan = -1.0  # a random roll may plan Black ICE (I3) for this round: step 42 tests it, not this
	await _wait(func(): return ci.hunter != null and is_instance_valid(ci.hunter) and hi.hunter != null and ci.hunter.build_seed == hi.hunter.build_seed, 120)
	await _frames(10)
	var builds := ci.mode == IceDirector.Mode.FOLLOW and hi.mode == IceDirector.Mode.RUN
	for i in hi.pieces().size():
		builds = builds and hi.pieces()[i].build_seed == ci.pieces()[i].build_seed
	var refused: bool = not ci.wall("gate").hit(100.0, Vector3.INF, Vector3.ZERO, "terminal_cannon") and is_equal_approx(hi.wall("gate").health(), _t.barrier_health)
	# The host's judging of a joiner's hit lands, and the joiner's copy follows the cracks and the break.
	var cid: int = cs.my_id
	var judged: bool = hs._hit_daemon(hi.wall("gate"), cid, 100.0, Vector3.INF, Vector3.ZERO, "terminal_cannon")
	var cracked := await _wait(func(): return is_equal_approx(ci.wall("gate").health(), _t.barrier_health - 100.0), 60)
	hi.wall("gate").hit(1000.0, Vector3.INF, Vector3.ZERO, "sigkill_rail")
	for i in 5:
		hi.wall("gate").hit(100.0, Vector3.INF, Vector3.ZERO, "terminal_cannon")
	var broke := await _wait(func(): return ci.wall("gate").broken, 60)
	var learned := await _wait(func(): return ci.adapt_weapon == hi.adapt_weapon and ci.adapt_percent() == hi.adapt_percent() and hi.adapt_percent() > 0, 60)
	await _frames(4)
	var same_line: bool = client["main"].get_node("Hud").ice_hud().adapt_line() == host["main"].get_node("Hud").ice_hud().adapt_line() and client["main"].get_node("Hud").ice_hud().adapt_line() != ""
	# Read null-safe (C30): one of C30's gates found a hunter missing here once and the script error hid the
	# rest of the match's checks; a missing hunter still fails this check, and is named.
	var hunters := "host %s, joiner %s" % ["present" if hi.hunter != null and is_instance_valid(hi.hunter) else "missing", "present" if ci.hunter != null and is_instance_valid(ci.hunter) else "missing"]
	var tint: bool = hunters == "host present, joiner present" and ci.hunter.shield_color.is_equal_approx(hi.hunter.shield_color)
	print("ICE match: joined %s, builds the host's %s, the joiner's own shot refused %s, the host's judging landed %s, cracks followed in %d frames, the break in %d, adaptation (%s %d%%) in %d" % [joined, builds, refused, judged, cracked, broke, hi.adapt_weapon, hi.adapt_percent(), learned])
	_check("acceptance: host-authoritative in a match: the joiner's pieces are the host's builds (the hunter's too), a joiner's own shot lands nothing on its copy while the host's judging of a joiner's hit lands, and the joiner's copy follows the host's word: the wall's cracks and its break, the adaptation, its HUD line and the hunter's colour", joined and builds and refused and judged and cracked >= 0 and broke >= 0 and learned >= 0 and same_line and tint, "hunters: " + hunters)
	# The hunter's place and state, and a node's tell, on both screens.
	host["player"].global_position = host["main"].to_global(Vector3(-4.5, 0.95, 0.5))
	var telling := await _wait(func(): return hi.node_of("jam").state == IceNode.State.TELL, 200)
	await _frames(6)
	var node_follows: bool = ci.node_of("jam").state == IceNode.State.TELL and absf(ci.node_of("jam").state_t - hi.node_of("jam").state_t) < 0.2
	var hunter_at: float = (ci.hunter.global_position - client["main"].global_position).distance_to(hi.hunter.global_position - host["main"].global_position)
	_check("the joiner's copy plays the host's word: a node's tell as it tells, the hunter where the host's is", telling >= 0 and node_follows and hunter_at < 1.0, "the hunters %.2f m apart; words %d black %d" % [hunter_at, cs.ice_words, cs.black_words])
	# The hunter killed (it comes back after its wait), so no lance downs a player in what follows.
	for i in 3:
		hi.hunter.hit(1000.0, Vector3.INF, Vector3.ZERO, "rm_rf_cannon")
	var gone := await _wait(func(): return ci.hunter == null or not is_instance_valid(ci.hunter) or ci.hunter.broken, 60)
	# A field reaching the joiner jams it there; the host refuses that weapon until it clears.
	host["player"].global_position = host["main"].to_global(Vector3(15.0, 0.95, 15.0))
	await _wait(func(): return hi.node_of("jam").state == IceNode.State.IDLE, int(ceil((_t.jam_tell_s + _t.field_show_s + _t.jam_cooldown_s) * 60.0)) + 30)
	client["player"].select_slot(0)
	client["player"].global_position = client["main"].to_global(Vector3(-4.5, 0.95, 0.5))
	await _wait(func(): return hi.node_of("jam").state == IceNode.State.FIELD, int(ceil(_t.jam_tell_s * 60.0)) + 90)
	await _wait(func(): return client["player"].inventory.jams[0] > 0.0, 30)
	var jam_here: bool = client["player"].inventory.jams[0] > 0.0
	var host_refuses: bool = hi.jammed(cid, "terminal_cannon")
	print("ICE match jam: the hunter down on the joiner's screen %s; the joiner jammed %s (%d on it), the host refusing its cannon %s; the joiner alive %s, protected %s, its node %s fired %d" % [gone >= 0, jam_here, ci.jams_on_me, host_refuses, hs.combat.alive(cid), hs.combat.protected(cid), hi.node_of("jam").state_name(), hi.node_of("jam").fires])
	_check("acceptance: a field reaching a joiner is the host's word: the joiner's weapon in hand jams on its own screen, and the host refuses that weapon's shots until the jam clears", jam_here and ci.jams_on_me >= 1 and host_refuses)
	# The host's ICE setting rules the match.
	GameSettings.current().set_value("gameplay", "ice", false)
	var off := await _wait(func(): return cs.host_ice == false and ci.mode == IceDirector.Mode.OFF and ci.pieces().is_empty() and hi.pieces().is_empty(), 120)
	GameSettings.current().set_value("gameplay", "ice", true)
	var on := await _wait(func(): return cs.host_ice == true and ci.mode == IceDirector.Mode.FOLLOW and ci.walls.size() == 2, 120)
	_check("the host's ICE setting is the match's rule: off, every screen's ICE is gone; on, it is back", off >= 0 and on >= 0)
	await _drop_side(client)
	await _drop_side(host)
	GameSettings.current().set_value("gameplay", "practice", true)


# --- Helpers. ---

func _world() -> Node3D:
	var world := Node3D.new()
	root.add_child(world)
	_scratch.append(world)
	return world


## A fresh arena with ICE on, every daemon parked under the floor and the player at `player_at`.
func _lab(player_at: Vector3) -> Node:
	GameSettings.current().set_value("gameplay", "practice", false)
	GameSettings.current().set_value("gameplay", "ice", true)
	var link := Link.new()
	link.settings_path = _tmp.path_join("arena-privacy.cfg")
	link.demo = true
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


func _ice(main: Node) -> IceDirector:
	return main.get_node(IceDirector.NODE_NAME)


func _life(main: Node) -> Node:
	for child in main.get_children():
		if child is SoloLife:
			return child
	return null


## Waits out the player's spawn protection.
func _unprotect(main: Node) -> void:
	var life := _life(main)
	await _wait(func(): return life == null or not life.protected(), 300)


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
	for node in _scratch:
		if is_instance_valid(node):
			node.free()
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
