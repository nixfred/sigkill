extends SceneTree
## Headless rail test for SIGKILL (C17). scripts/check.sh runs it, and any FAIL exits 1.
##
##   godot --headless --path . --fixed-fps 60 --script res://tests/rail_test.gd
##
## The SIGKILL rail rifle (kill -9), the ult: its resource and its numbers, the cannon and
## SIGTERM unchanged, bad rail values refused; then solo in the real arena with the real
## player: no shot with an empty meter, the meter filled by damage and kills to exactly full
## by the resource's numbers and kept across swaps, the charge and its glow timed to the
## frame, one shot emptying it, one rail through a line of three dummies derezzing all three,
## a wall stopping it, a headshot kill called out as "kill -9" (a body kill is not), the beam
## lingering and fading, the strip's dimmed slot and meter, and the meter reset by a death and
## a new round; then a host and a joiner over ENet on 127.0.0.1: the joiner fills its meter by
## killing the host with the cannon (the host's count and the joiner's own the same at every
## kill), its full-meter rail kills the host through a dummy the host's own trace passes, the
## feed names the kill "SIGKILL <pid> sent by Daemon-2" with the fake id on both sides, its
## head hit is called out, and a forged rail shot with the meter empty is dropped by the host
## and counted; a death empties the meter on both sides. Nothing outside this process is
## touched, and no process id is ever read: the pid is the game's own fake.

const Session = preload("res://scripts/net/net_session.gd")
const Combat = preload("res://scripts/net/combat.gd")
const NetTuningScript = preload("res://scripts/net/net_tuning.gd")
const CombatTuningScript = preload("res://scripts/net/combat_tuning.gd")
const WeaponDefScript = preload("res://scripts/weapons/weapon_def.gd")
const Inventory = preload("res://scripts/weapons/inventory.gd")
const Arsenal = preload("res://scripts/weapons/arsenal_tuning.gd")
const WeaponHud = preload("res://scripts/hud/weapon_hud.gd")
const RoundHud = preload("res://scripts/round/round_hud.gd")
const Controls = preload("res://scripts/controls.gd")
const Link = preload("res://scripts/guide/guide_link.gd")
const MainScene = preload("res://scenes/main.tscn")
const RAIL_PATH := "res://resources/sigkill_rail.tres"
const CANNON_PATH := "res://resources/terminal_cannon.tres"
const SIGTERM_PATH := "res://resources/sigterm.tres"
const FX_GROUP := &"cannon_fx"
const WATCHDOG_MS := 10000
const CLIENT_OFFSET := Vector3(1000.0, 0.0, 0.0)
const STAND_Y := 0.95
## A clear line across the arena at z 15, from the S2 spawn eastwards: no cover on it.
const LINE_Z := 15.0
const SHOOTER_X := -15.0
const EPS := 0.0001

var _fails := 0
var _checks := 0
var _tmp := ""
var _rail: Resource
var _cannon: Resource
var _sigterm: Resource
var _arenas: Array = []
var _branches: Array = []


func _initialize() -> void:
	_run()


func _run() -> void:
	await process_frame
	root.size = Vector2i(1280, 720)
	_tmp = OS.get_temp_dir().path_join("sigkill-rail-test-%d" % OS.get_process_id())
	DirAccess.make_dir_recursive_absolute(_tmp)
	Controls.ensure()
	_rail = load(RAIL_PATH)
	_cannon = load(CANNON_PATH)
	_sigterm = load(SIGTERM_PATH)
	_def_checks()
	_inventory_checks()
	_source_checks()
	await _solo_checks()
	await _match_checks()
	await _cleanup()
	for name in DirAccess.get_files_at(_tmp):
		DirAccess.remove_absolute(_tmp.path_join(name))
	DirAccess.remove_absolute(_tmp)
	print("RAIL: %d checks" % _checks)
	print("RAIL RESULT: ", "ALL PASS" if _fails == 0 else "%d FAILED" % _fails)
	quit(0 if _fails == 0 else 1)


func _check(label: String, ok: bool, detail: String = "") -> void:
	_checks += 1
	print("PASS " if ok else "FAIL ", label, ("   " + detail) if detail != "" else "")
	if not ok:
		_fails += 1


# --- The resource. ---

func _def_checks() -> void:
	var r = _rail
	_check("the SIGKILL rail is one WeaponDef resource and passes its own checks", r is WeaponDefScript and r.problems().is_empty(), str(r.problems()) if r is WeaponDefScript else "")
	_check("its numbers: kill -9, an ult of 3.0 points (0.8 per target's health dealt, 0.2 per kill: three kills fill it), no magazine, reserve or reload, a 0.35 s charge, piercing, 1000 damage, 120 m, the ice light skin, the feed's fake pid", r.id == "sigkill_rail" and r.short_name == "kill -9" and r.kill_word == "SIGKILL" and r.is_ult() and r.ult_meter == 3.0 and r.ult_per_health == 0.8 and r.ult_per_kill == 0.2 and not r.has_magazine() and r.reserve_ammo == WeaponDefScript.INFINITE and r.reload_s == 0.0 and r.charge_s == 0.35 and r.pierce and r.damage == 1000.0 and r.fire_range == 120.0 and r.light_skin == "ice" and r.feed_pid and r.fire_mode == WeaponDefScript.FireMode.HITSCAN_SINGLE)
	_check("one kill's worth of play is exactly a third of the meter, from damage and the kill bonus", is_equal_approx(r.meter_gain(1.0, true), 1.0) and is_equal_approx(r.meter_gain(0.25, false), 0.2) and r.meter_gain(2.0, false) == r.meter_gain(1.0, false) and r.meter_gain(-1.0, true) == 0.0)
	_check("the beam lingers about 0.6 s and is brighter and wider than the cannon's; its kill outdoes any health", r.beam_lifetime == 0.6 and r.beam_radius > _cannon.beam_radius and r.beam_energy > _cannon.beam_energy and r.damage >= CombatTuningScript.new().max_health * 10.0)
	_check("the cannon and SIGTERM are as they were: no ult, no charge, no pierce, no pid in the feed", not _cannon.is_ult() and _cannon.charge_s == 0.0 and not _cannon.pierce and not _cannon.feed_pid and not _sigterm.is_ult() and _sigterm.charge_s == 0.0 and not _sigterm.pierce and _cannon.damage == 25.0 and _sigterm.pellet_count == 9)
	var shipped = load("res://resources/arsenal.tres")
	_check("the shipped arsenal carries it as weapon 3 (the fork bomb is weapon 4 since C19, the fork() shotgun weapon 5 since C24, the grep seeker weapon 6 since C25)", shipped.loadout.size() == 6 and shipped.loadout[2] == _rail and Arsenal.usable_loadout(shipped).size() == 6)
	var cases := [
		["pierce", true, "fire_mode", WeaponDefScript.FireMode.HITSCAN_PELLETS, "only a single shot pierces"],
		["ult_meter", 3.0, "magazine_size", 4, "an ult has no magazine"],
		["ult_meter", 3.0, "ult_per_health", 0.0, "must fill from something"],
		["charge_s", 3.0, "", null, "charge_s"],
		["ult_meter", 0.1, "", null, "ult_meter"],
		["ult_per_kill", -1.0, "", null, "ult_per_health and ult_per_kill"],
	]
	var missed := PackedStringArray()
	for c in cases:
		var bad = _rail.duplicate()
		bad.set(c[0], c[1])
		if c[2] != "":
			bad.set(c[2], c[3])
			if c[2] == "fire_mode":
				bad.pellet_count = 4
				bad.spread_degrees = 3.0
			if c[2] == "magazine_size":
				bad.reserve_ammo = 8
				bad.reload_s = 1.0
			if c[2] == "ult_per_health":
				bad.ult_per_kill = 0.0
		var issues: PackedStringArray = bad.problems()
		if not ", ".join(issues).contains(c[4]):
			missed.append("%s=%s: %s" % [c[0], c[1], issues])
	_check("bad rail values are refused with the reason: pellets that pierce, an ult with a magazine, a meter that never fills, a 3 s charge, a tiny meter, a negative kill bonus", missed.is_empty(), " | ".join(missed))


func _inventory_checks() -> void:
	var inv := Inventory.new([_cannon, _sigterm, _rail], 0.3, 1.6)
	inv.select(2)
	inv.tick(0.4)
	_check("the inventory: the rail is the loadout's ult, slot 3; an empty meter blocks it as 'meter'", inv.ult_slot() == 2 and inv.meter_full() == 3.0 and not inv.meter_ready() and inv.fire_block() == Inventory.BLOCK_METER and inv.try_fire() == Inventory.BLOCK_METER)
	inv.add_meter(2.5)
	inv.add_meter(2.5)
	_check("the meter caps at full, and one shot empties it", inv.meter == 3.0 and inv.meter_ready() and inv.try_fire() == "" and inv.meter == 0.0 and inv.try_fire() == Inventory.BLOCK_COOLDOWN)
	var near := Inventory.new([_cannon, _rail], 0.3, 1.6)
	near.add_meter(2.99999999)
	var sums := Inventory.new([_cannon, _rail], 0.3, 1.6)
	for i in 15:
		sums.add_meter(_rail.meter_gain(0.25, false))
		if i % 5 == 4:
			sums.add_meter(_rail.meter_gain(0.0, true))
	_check("a meter a hair short of full from float sums counts as full, so the player's own and the host's agree", near.meter == 3.0 and near.meter_ready() and sums.meter == 3.0 and sums.meter_ready(), "%.17f %.17f" % [near.meter, sums.meter])
	inv.add_meter(3.0)
	inv.select(0)
	inv.tick(0.4)
	var kept := inv.meter
	inv.refill()
	_check("the meter stays across a swap, and a fresh life empties it", kept == 3.0 and inv.meter == 0.0)
	_check("the cannon still fires forever, SIGTERM still pumps: their rules did not change", inv.try_fire() == "" and inv.select(1) and is_equal_approx(inv.swap_left, 0.3))


func _source_checks() -> void:
	var session := _code("res://scripts/net/net_session.gd")
	var pid := _body(session, "fake_pid")
	_check("the feed's pid is worked out from the slot and life alone: no process id is ever read", pid.contains("slot * 4099 + life * 977") and not pid.contains("OS.") and not session.contains("get_process_id") and not _code("res://scripts/player.gd").contains("get_process_id"))
	var combat := _code("res://scripts/net/combat.gd")
	_check("the host owns every meter: a rail shot is believed only with the shooter's meter full, and spent when believed", _body(combat, "validate").contains("def.is_ult() and s[\"meter\"] < def.ult_meter - METER_EPS") and _body(combat, "accept").contains("s[\"meter\"] = 0.0"))
	_check("the host traces the pierce itself and stops it at the level", _body(session, "_handle_fire").contains("_rail_trace(shooter, origin, dir, def)") and _body(session, "_rail_trace").contains("if not target:\n\t\t\tend = result[\"position\"]\n\t\t\tbreak"))
	_check("the shot request is the C16 intent: the rail adds no RPC of its own (the fifteen are C13 to C16's ten, C18's two for SIGSTOP and C19's three for the fork bomb; seventeen since C20's two for light trails, nineteen since C22's two for sudo, twenty since C23's top table, protocol 8, 9 since C25's grep marks)", session.count("@rpc(") == 20 and Session.PROTOCOL == 9 and not session.contains("func _rail(") and _body(session, "_fire").contains("_handle_fire("))
	var round := _code("res://scripts/round/round_hud.gd")
	_check("'kill -9' is a game-logic callout: the rail-kill path never touches the link or the announcer", _body(round, "_on_rail_kill").contains("_callout(\"kill_9\", true)") and not _body(round, "_on_rail_kill").contains("link") and not _body(round, "_on_rail_kill").contains("announcer"))


# --- Solo. ---

func _solo_checks() -> void:
	var arena := await _arena()
	var p: Node = arena["player"]
	var main: Node = arena["main"]
	var wh: WeaponHud = main.get_node("Hud").weapon_hud()
	var round: RoundHud = main.get_node("Hud").round_hud()
	var dummies: Array = []
	for name in ["DummyA", "DummyB", "DummyC"]:
		dummies.append(main.get_node("Arena/Targets/" + name))
	var inv = p.inventory
	p.respawn_at(main.to_global(Vector3(SHOOTER_X, STAND_Y, LINE_Z)))
	await _settle(p, 0.3)
	p.select_slot(2)
	await _settle(p, 0.4)
	var shots: int = p.shots_fired
	await _fire(p)
	await _settle(p, 0.6)
	_check("with the meter empty the rail cannot fire: no charge, no shot", inv.current == 2 and not p.is_charging() and p.shots_fired == shots and inv.meter == 0.0)
	_check("the strip: slot 3 dimmed, the meter empty, the rail's own line saying so", wh.slot_dimmed(2) and not wh.slot_dimmed(0) and wh.meter_text() == "kill -9 [..........]" and wh.ammo_text() == "kill -9  meter 0%", "%s | %s" % [wh.meter_text(), wh.ammo_text()])
	# The meter from play: a 100-health dummy hit once by the cannon, then three kills.
	p.select_slot(0)
	await _settle(p, 0.4)
	var big: Node = dummies[0]
	big.max_health = 100.0
	big.reset_for_round()
	_place(main, big, -9.0)
	await _frames(2)
	await _shoot_at(p, main, big)
	var partial: float = inv.meter
	big.max_health = 1.0
	big.reset_for_round()
	p.reset_meter()
	var after := []
	for i in 3:
		var d: Node = dummies[i]
		_place(main, d, -9.0)
		d.reset_for_round()
		await _frames(2)
		await _shoot_at(p, main, d)
		after.append(inv.meter)
		_place(main, d, 30.0 + i)  # out of the way
	_check("damage and kills fill it by the resource's numbers: a quarter of a dummy's health is 0.2, each kill 1.0, so three kills fill it", is_equal_approx(partial, 0.2) and is_equal_approx(after[0], 1.0) and is_equal_approx(after[1], 2.0) and is_equal_approx(after[2], 3.0) and inv.meter_ready(), "%.3f %s" % [partial, after])
	dummies[0].reset_for_round()
	_place(main, dummies[0], -9.0)
	await _frames(2)
	await _shoot_at(p, main, dummies[0])
	_place(main, dummies[0], 30.0)
	_check("a fourth kill keeps it at full", inv.meter == 3.0)
	p.select_slot(1)
	await _settle(p, 0.4)
	var through_sigterm: float = inv.meter
	p.select_slot(2)
	await _settle(p, 0.4)
	_check("the meter is kept across swaps, and the strip lights slot 3 in the rail's colour", through_sigterm == 3.0 and inv.meter == 3.0 and not wh.slot_dimmed(2) and wh.meter_text() == "kill -9 ready: 3, fire", wh.meter_text())
	# One rail through a line of three dummies.
	for i in 3:
		dummies[i].reset_for_round()
		_place(main, dummies[i], -11.0 + 3.0 * i)
	await _frames(2)
	_aim(p, main.to_global(Vector3(-5.0, 0.9, LINE_Z)))
	var kills := []
	var record := func(headshot: bool): kills.append(headshot)
	p.rail_kill.connect(record)
	var glow_base: float = _rail.viewmodel_glow_energy
	var frame := -1
	var charging_at := []
	var glows := []
	var beam: Node = null
	var beam_found := false
	var beam_frame := -1
	shots = p.shots_fired
	for k in range(1, 40):
		p.drive_input(Vector2.ZERO, false, false, k == 1)
		await physics_frame
		charging_at.append(p.is_charging())
		glows.append((p.get("_viewmodel").material_override as StandardMaterial3D).emission_energy_multiplier)
		if p.shots_fired > shots and frame < 0:
			frame = k
		if not beam_found and frame > 0:
			beam = _rail_beam(main)
			beam_found = beam != null
			beam_frame = k
	var beam_age := 39 - beam_frame
	var charge_frames := ceili(_rail.charge_s * 60.0)
	_check("fire with the meter full charges for 0.35 s with a growing glow, then the rail goes off", frame >= charge_frames and frame <= charge_frames + 2 and charging_at[1] and glows[charge_frames - 2] > glow_base * 3.0 and is_equal_approx(glows[frame + 1], glow_base), "frame %d of %d, glow %.2f peak %.2f" % [frame, charge_frames, glows[0], glows.max()])
	var down := 0
	for i in 3:
		if not dummies[i].is_alive():
			down += 1
	_check("acceptance: one rail shot through a line of three dummies derezzes all three", down == 3 and kills.size() == 3, "%d down, %s" % [down, kills])
	_check("one shot empties the meter, and slot 3 dims again", inv.meter == 0.0 and wh.slot_dimmed(2))
	_check("a body kill is no 'kill -9': the line hit them below the head zone", not kills.has(true) and round.callout_text() != RoundHud.KILL9_LINE, round.callout_text())
	_check("each kill leaves the derezz voxels", _count_derezz(main) >= 3)
	await _frames(maxi(18 - beam_age, 0))
	var lingering := is_instance_valid(beam)
	await _frames(30)
	_check("the rail's beam lingers and fades: there after 0.3 s, gone by 0.8 s", beam_found and lingering and not is_instance_valid(beam), "beam %s at frame %d (age %d), lingering %s" % [beam_found, beam_frame, beam_age, lingering])
	# A wall in the line stops it.
	for i in 3:
		dummies[i].reset_for_round()
		_place(main, dummies[i], -11.0 + 3.0 * i)
	var wall := StaticBody3D.new()
	wall.collision_layer = 1
	var box := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(0.4, 4.0, 4.0)
	box.shape = shape
	wall.add_child(box)
	main.add_child(wall)
	wall.global_position = main.to_global(Vector3(-6.5, 1.5, LINE_Z))
	p.add_meter(3.0)
	await _frames(3)
	_aim(p, main.to_global(Vector3(-5.0, 0.9, LINE_Z)))
	kills.clear()
	await _rail_shot(p)
	_check("acceptance: a wall in the line stops the pierce: the two dummies before it derezz, the one behind it stands", not dummies[0].is_alive() and not dummies[1].is_alive() and dummies[2].is_alive() and kills.size() == 2)
	wall.queue_free()
	# A headshot.
	for i in 3:
		dummies[i].reset_for_round()
		_place(main, dummies[i], 30.0 + i)
	_place(main, dummies[1], -8.0)
	p.add_meter(3.0)
	await _frames(3)
	_aim(p, main.to_global(Vector3(-8.0, 1.65, LINE_Z)))
	kills.clear()
	await _rail_shot(p)
	_check("acceptance: a rail kill with the hit in the head zone is called out 'kill -9', by the game's own logic", not dummies[1].is_alive() and kills == [true] and round.callout_text() == RoundHud.KILL9_LINE and round.last_callout == "kill -9", round.callout_text())
	p.rail_kill.disconnect(record)
	# Resets.
	p.add_meter(3.0)
	p.set_alive(false)
	var after_death: float = inv.meter
	p.set_alive(true)
	p.add_meter(3.0)
	round.call("_next_round")
	_check("acceptance: the meter resets on death and at a round's start", after_death == 0.0 and inv.meter == 0.0 and round.stats.round_number == 2)
	p.add_meter(3.0)
	p.select_slot(2)
	await _settle(p, 0.4)
	p.drive_input(Vector2.ZERO, false, false, true)
	for i in 12:
		await physics_frame
	var was_charging: bool = p.is_charging()
	shots = p.shots_fired
	p.select_slot(0)
	await _settle(p, 0.6)
	var rail_glow: float = (p.get("_viewmodels")[2].material_override as StandardMaterial3D).emission_energy_multiplier
	var cannon_glow: float = (p.get("_viewmodels")[0].material_override as StandardMaterial3D).emission_energy_multiplier
	_check("drawing another weapon mid-charge lets the charge go: no shot, the meter still full, and the rail's glow back to its own base (the cannon's untouched)", was_charging and not p.is_charging() and p.shots_fired == shots and inv.meter == 3.0 and is_equal_approx(rail_glow, _rail.viewmodel_glow_energy) and is_equal_approx(cannon_glow, _cannon.viewmodel_glow_energy), "rail %.3f cannon %.3f" % [rail_glow, cannon_glow])
	_drop(arena)


# --- A match. ---

func _match_checks() -> void:
	var host := _branch("Host", Vector3.ZERO)
	var client := _branch("Client", CLIENT_OFFSET)
	var joined := await _join(host, client)
	var hs: Session = host["session"]
	var cs: Session = client["session"]
	var hp: Node = host["player"]
	var cp: Node = client["player"]
	var cid: int = cs.my_id
	await _until(func(): return hs.avatars.has(cid) and cs.avatars.has(1) and hs.combat.has_player(cid), 6000)
	_check("a host and a joiner over ENet on 127.0.0.1, both carrying the rail; the meters start empty on both sides", joined and cp.inventory.ult_slot() == 2 and hs.combat.meter_of(cid) == 0.0 and cp.inventory.meter == 0.0 and cp.match_meter)
	var spot := Vector3(-8.0, STAND_Y, LINE_Z)
	var cspot := Vector3(SHOOTER_X, STAND_Y, LINE_Z)
	var counts := []
	for kill in 3:
		await _back_at(hs, hp, host, spot)
		cp.respawn_at(client["main"].to_global(cspot))
		await _frames(6)
		_aim(cp, client["main"].to_global(spot + Vector3(0.0, 0.05, 0.0)))
		var shots := 0
		while not hs.dead.get(1, false) and shots < 8:
			await _settle(cp, 0.2)
			await _fire(cp)
			shots += 1
			await _frames(4)
		await _until(func(): return cs.dead.get(1, false), 3000)
		await _frames(4)
		counts.append([hs.combat.meter_of(cid), cp.inventory.meter])
	var same := true
	for i in counts.size():
		same = same and is_equal_approx(counts[i][0], i + 1.0) and is_equal_approx(counts[i][1], i + 1.0)
	_check("acceptance: in the match the joiner's cannon kills fill its meter, a third per kill, the host's count (which decides) and the joiner's own the same at each", same and cp.inventory.meter_ready(), str(counts))
	# The rail, through a dummy the host's own trace passes.
	await _back_at(hs, hp, host, spot)
	var dummy: Node = host["main"].get_node("Arena/Targets/DummyA")
	dummy.reset_for_round()
	_place(host["main"], dummy, -11.5)
	cp.respawn_at(client["main"].to_global(cspot))
	cp.select_slot(2)
	await _settle(cp, 0.6)
	_aim(cp, client["main"].to_global(spot + Vector3(0.0, 0.75, 0.0)))
	var heads := []
	var record := func(headshot: bool): heads.append(headshot)
	cp.rail_kill.connect(record)
	var life: int = hs.lives.get(1, 0)
	var host_slot: int = hs.players[1]["slot"]
	await _rail_shot(cp)
	var killed := await _until(func(): return hs.dead.get(1, false) and cs.dead.get(1, false), 4000)
	await _frames(4)
	var feed_host: Array = host["hud"].combat_hud().feed_text()
	var feed_client: Array = client["hud"].combat_hud().feed_text()
	var line := "SIGKILL %d sent by Daemon-2 to Daemon-1" % Session.fake_pid(host_slot, life)
	# The host's dummy stands in the line in the host's world: a trace that stopped at it would
	# leave the host alive. It takes no damage there: the host's trace judges players only.
	_check("acceptance: the joiner's full-meter rail kills the host, the host's own trace passing through a dummy in the line", killed and dummy.is_alive(), "dead on host %s" % hs.dead.get(1, false))
	_check("acceptance: the kill feed reads 'SIGKILL <pid> sent by <player>' on both sides, the pid the game's own fake for the host's life", not feed_host.is_empty() and feed_host[0] == line and not feed_client.is_empty() and feed_client[0] == line, "%s | %s" % [feed_host, feed_client])
	_check("the joiner's head hit, from its own trace, is called out 'kill -9' once the host's word of the kill arrives", heads == [true] and client["hud"].round_hud().callout_text() == RoundHud.KILL9_LINE, "%s %s" % [heads, client["hud"].round_hud().callout_text()])
	_check("the shot spent the meter on both sides", hs.combat.meter_of(cid) == 0.0 and cp.inventory.meter == 0.0)
	cp.rail_kill.disconnect(record)
	_place(host["main"], dummy, 30.0)  # out of the line: in the host's world it would stop a cannon shot
	# A forged rail shot with the meter empty.
	await _settle(cp, 1.2)
	var dropped: int = hs.combat.drops.get(Combat.DROP_METER, 0)
	var seq: int = hs.combat.states[cid]["last_seq"] + 1
	cs.set("_sent_actions", cs.get("_sent_actions") + 1)
	var eye: Vector3 = client["main"].to_local(cp.eye_position())
	cs.rpc_id(1, "_fire", seq, cs.lives.get(cid, 0), "sigkill_rail", eye, Vector3(1.0, 0.0, 0.0))
	var refused := await _until(func(): return hs.combat.drops.get(Combat.DROP_METER, 0) > dropped, 3000)
	_check("acceptance: a forged rail shot with the meter empty is dropped by the host and counted as 'meter', nothing applied", refused and hs.combat.states[cid]["last_seq"] == seq - 1, "drops %s" % hs.combat.drops)
	# A death empties the meter, on both sides.
	await _back_at(hs, hp, host, spot)
	cp.select_slot(0)
	cp.respawn_at(client["main"].to_global(cspot))
	await _settle(cp, 0.5)
	_aim(cp, client["main"].to_global(spot + Vector3(0.0, 0.05, 0.0)))
	await _fire(cp)
	await _until(func(): return hs.combat.meter_of(cid) > 0.0 and cp.inventory.meter > 0.0, 3000)
	var before_death := [hs.combat.meter_of(cid), cp.inventory.meter]
	_aim(hp, host["main"].to_global(cspot + Vector3(0.0, 0.05, 0.0)))
	hp.select_slot(0)
	await _settle(hp, 0.5)
	var host_shots := 0
	while not hs.dead.get(cid, false) and host_shots < 8:
		await _settle(hp, 0.2)
		await _fire(hp)
		host_shots += 1
		await _frames(4)
	await _until(func(): return cs.dead.get(cid, false), 3000)
	await _frames(4)
	_check("acceptance: a death empties the meter: the host's count and the joiner's own", before_death[0] > 0.0 and before_death[1] > 0.0 and hs.dead.get(cid, false) and hs.combat.meter_of(cid) == 0.0 and cp.inventory.meter == 0.0, "%s -> %.2f %.2f" % [before_death, hs.combat.meter_of(cid), cp.inventory.meter])
	_drop(host)
	_drop(client)


# --- Helpers. ---

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


## The host back alive, out of its protection, and put at `spot` on the line.
func _back_at(hs: Session, hp: Node, host: Dictionary, spot: Vector3) -> void:
	await _until(func(): return not hs.dead.get(1, false) and hs.protect_left.get(1, 0.0) <= 0.0, 6000)
	hp.respawn_at(host["main"].to_global(spot))
	await _frames(6)


## Puts a dummy on the line at `x`, standing on the floor.
func _place(main: Node, dummy: Node, x: float) -> void:
	dummy.global_position = main.to_global(Vector3(x, 0.0, LINE_Z))


## The cannon at a dummy's body centre until it goes down (or eight shots).
func _shoot_at(p: Node, main: Node, dummy: Node) -> void:
	_aim(p, dummy.global_position + Vector3(0.0, 0.9, 0.0))
	var shots := 0
	var health_before: float = dummy.health()
	while dummy.is_alive() and shots < 8:
		await _settle(p, 0.2)
		await _fire(p)
		shots += 1
		await _frames(2)
		if dummy.max_health > 1.0 and dummy.health() < health_before:
			return  # a partial hit is all that was wanted


## Fires the drawn rail once it may (its 1 s interval since the last) and waits out its
## charge and a little more.
func _rail_shot(p: Node) -> void:
	await _until(func(): return p.inventory.fire_block() == "", 3000)
	await _fire(p)
	for i in ceili(_rail.charge_s * 60.0) + 6:
		p.drive_input(Vector2.ZERO)
		await physics_frame


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


func _count_derezz(scope: Node) -> int:
	var n := 0
	for node in scope.find_children("*", "MultiMeshInstance3D", true, false):
		n += 1
	for node in root.find_children("*", "MultiMeshInstance3D", true, false):
		if not scope.is_ancestor_of(node):
			n += 1
	return n


## The rail's beam: an effect holding a cylinder as wide as the rail's.
func _rail_beam(_scope: Node) -> Node:
	for node in get_nodes_in_group(FX_GROUP):
		if node.get_child_count() > 0 and node.get_child(0) is MeshInstance3D:
			var mesh = (node.get_child(0) as MeshInstance3D).mesh
			if mesh is CylinderMesh and is_equal_approx(mesh.top_radius, _rail.beam_radius):
				return node
	return null


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
	await process_frame
	OS.delay_msec(300)
	await process_frame
