extends SceneTree
## Headless test of A5's daemons, no two alike, for SIGKILL. scripts/check.sh runs it as step 39,
## and any FAIL exits 1.
##
##   godot --headless --path . --fixed-fps 60 --script res://tests/daemon_variety_test.gd
##
## Each daemon is built from a seed. Built alone: the same seed builds the same daemon, part for
## part and pose for pose; other seeds build others (their sizes, their part counts, their battle
## damage); one seed in twelve is an elite, the rate measured over many seeds, and an elite is its
## type's biggest with more armour than any other build of it; every build's size inside its type's
## hitbox-safe range (the zombie's head in the hit volume's head zone at its smallest, its largest
## and as an elite; rogue.d's body box at its size; nothing drawn outside its culling box; the tag
## over it). In the real arena: the seeds fixed by name in a run like this one, the four rolling no
## elite; in play each spawn a new seed and a new daemon (the art rebuilt while it is nothing, its
## brain, box and tag told); an elite taking a cannon shot and living, a normal one not; killing the
## runaway's core scatters its swarm, every drone flying off whole and away. Then a host and a
## joiner over ENet on 127.0.0.1: the joiner's daemons are the host's builds, a wrong one put right
## by the host's word, a host's new spawn followed; the joiner's shot lands nothing on the host's
## runaway, and the host's kill scatters it on the joiner's screen too. And the wire: the seed rides
## the daemons' state message, protocol 11.
## Deterministic: frames counted, only counts and outcomes printed.

const Session = preload("res://scripts/net/net_session.gd")
const NetTuningScript = preload("res://scripts/net/net_tuning.gd")
const Link = preload("res://scripts/guide/guide_link.gd")
const MainScene = preload("res://scenes/main.tscn")
const DummyScene = preload("res://scenes/target_dummy.tscn")
const Dummy = preload("res://scripts/target_dummy.gd")
const Controls = preload("res://scripts/controls.gd")
const Shatter = preload("res://scripts/daemons/daemon_shatter.gd")
const ART_DIR := "res://scripts/daemons/"
const TYPES := ["rogue_daemon", "zombie_process", "runaway_swarm"]
const NAMES := {"DummyA": "rogue.d", "DummyB": "zombie", "DummyC": "<defunct>", "DummyD": "runaway"}
## Seeds sampled for the elite rate, and the rate's bounds round one in twelve.
const RATE_SEEDS := 12000
const RATE_LOW := 0.07
const RATE_HIGH := 0.097
## Builds of each type sampled for their variety and their sizes.
const BUILDS := 24
## The hit volume's head zone (WeaponDef.HEAD_ZONE_M under the 1.8 m prism's top), how far the
## zombie's head may stray from its middle, and the frames each size is watched for.
const HEAD_LOW := 1.4
const HEAD_HIGH := 1.85
const HEAD_OFF := 0.6
const WATCH := 120
## A cannon shot's damage (resources/terminal_cannon.tres).
const CANNON := 25.0
## The swarm's scatter: how long after the kill its drones are measured, and how much farther on
## average they must be from the core by then, in metres.
const SCATTER_FRAMES := 24
const SCATTER_GAIN := 2.0
const WATCHDOG_MS := 12000
const CLIENT_OFFSET := Vector3(1000.0, 0.0, 0.0)
const OPEN := Vector3(0.0, 0.95, 15.0)
const PARKED := Vector3(0.0, -50.0, 0.0)

var _fails := 0
var _checks := 0
var _tmp := ""
var _arenas: Array = []
var _branches: Array = []
var _scratch: Array = []


func _initialize() -> void:
	_run()


func _run() -> void:
	await process_frame
	root.size = Vector2i(1280, 720)
	_tmp = OS.get_temp_dir().path_join("sigkill-daemon-variety-test-%d" % OS.get_process_id())
	if DirAccess.dir_exists_absolute(_tmp):
		print("FAIL the test's temporary folder already exists; not touching it")
		quit(1)
		return
	DirAccess.make_dir_recursive_absolute(_tmp)
	Controls.ensure()
	GameSettings.current().reset()
	_source_checks()
	await _same_and_other_checks()
	_rate_checks()
	await _size_checks()
	await _spawn_checks()
	await _scatter_checks()
	await _match_checks()
	await _cleanup()
	for name in DirAccess.get_files_at(_tmp):
		DirAccess.remove_absolute(_tmp.path_join(name))
	DirAccess.remove_absolute(_tmp)
	print("DAEMON VARIETY: %d checks" % _checks)
	print("DAEMON VARIETY RESULT: ", "ALL PASS" if _fails == 0 else "%d FAILED" % _fails)
	quit(0 if _fails == 0 else 1)


func _check(label: String, ok: bool, detail: String = "") -> void:
	_checks += 1
	print("PASS " if ok else "FAIL ", label, ("   " + detail) if detail != "" else "")
	if not ok:
		_fails += 1


# --- The sources. ---

func _source_checks() -> void:
	var session := _code("res://scripts/net/net_session.gd")
	var told := _body(session, "_daemons")
	var sent := _body(session, "_tick_daemons")
	var follow := told.find("follow_seed(seeds[i])")
	var word := told.find("take_word(")
	_check("acceptance: in a match the host sends the seed: each daemon's build seed rides the daemons' state message (a packed array of 32-bit numbers, as long as the rest), and a joiner's copy is rebuilt from it before the rest of the word is played; protocol 11 (12 since I1's ICE, 13 since I2's ICEbreakers, 14 since I3's Black ICE, 15 since C29's chmod 000, 16 since C30's pipe |, 17 since C31's /dev/null, 18 since C32's SIGHUP)", Session.PROTOCOL == 18 and told.contains("seeds: PackedInt32Array") and told.contains("seeds.size() != n") and told.contains("seeds[i] < 0") and follow > 0 and follow < word and sent.contains("seeds.append(dummy.build_seed())") and sent.contains("killers, seeds, bolt_ids"))
	var dummy := _code("res://scripts/target_dummy.gd")
	_check("the seeds are fixed in demo, test and capture runs (--demo, or a --script run) and fixed by the daemon's name there, a fresh roll each spawn in play, and a joiner's copy waits for the host's", dummy.contains("static var fixed_seeds: bool = OS.get_cmdline_user_args().has(\"--demo\") or OS.get_cmdline_args().has(\"--script\")") and _body(dummy, "_spawn_seed").contains("DaemonArt.seed_of(tag_text)") and _body(dummy, "_spawn_seed").contains("randi()") and _body(dummy, "_begin_rematerialise").contains("if not _follows():") and Dummy.fixed_seeds)


# --- Built alone. ---

## The same seed builds the same daemon; other seeds build others.
func _same_and_other_checks() -> void:
	var world := _world()
	var same := PackedStringArray()
	var other := PackedStringArray()
	var report := PackedStringArray()
	for type in TYPES:
		var script: Script = load(ART_DIR + type + ".gd")
		var a := DaemonArt.make(script, null, 7001)
		var b := DaemonArt.make(script, null, 7001)
		world.add_child(a)
		world.add_child(b)
		b.position = Vector3(10.0, 0.0, 0.0)
		a.position = Vector3(-10.0, 0.0, 0.0)
		for f in 90:
			await process_frame
		var alike := a.part_count() == b.part_count() and a.size_scale == b.size_scale and a.elite == b.elite
		if alike:
			for id in a.part_count():
				alike = alike and a.part_transform(id).is_equal_approx(b.part_transform(id)) and a.part_custom(id).is_equal_approx(b.part_custom(id))
		if not alike:
			same.append(type)
		a.queue_free()
		b.queue_free()
		# Other seeds: every size its own, the part counts and the battle damage varied.
		var sizes := {}
		var counts := {}
		var damage := {}
		for k in BUILDS:
			var art := DaemonArt.make(script, null, 9100 + k * 37)
			sizes["%.4f" % art.size_scale] = true
			counts[art.part_count()] = true
			var marks := PackedStringArray()
			for id in art.part_count():
				if art.part_custom(id).a > 0.0 and art.part_look(id) != DaemonArt.Look.SHELL:
					marks.append(str(id))
			damage[",".join(marks)] = true
			art.free()
		report.append("%s: %d sizes, %d part counts, %d patterns of battle damage in %d builds" % [type, sizes.size(), counts.size(), damage.size(), BUILDS])
		if sizes.size() < BUILDS or counts.size() < 4 or damage.size() < BUILDS / 3:
			other.append(type)
	print("DAEMON VARIETY builds: " + "; ".join(report))
	_check("acceptance: the same seed gives identical builds: two daemons of each type from one seed match part for part, transform for transform and in every part's data after 90 frames", same.is_empty(), ", ".join(same))
	_check("acceptance: two seeds give different builds: %d builds of each type from %d seeds, every one its own size, at least 4 part counts (plates, segments, horns, voxels, drones) and at least a third of them their own battle damage (scorched plates, flickering seams)" % [BUILDS, BUILDS], other.is_empty(), ", ".join(other))
	world.queue_free()


## One seed in twelve is an elite.
func _rate_checks() -> void:
	var elites := 0
	for i in RATE_SEEDS:
		if DaemonArt.elite_of(hash(Vector2i(i, 31)) & DaemonArt.SEED_LAST):
			elites += 1
	var rate := float(elites) / RATE_SEEDS
	print("DAEMON VARIETY elite rate: %d elites in %d seeds, %.4f (the rule %.4f)" % [elites, RATE_SEEDS, rate, DaemonArt.ELITE_RATE])
	_check("acceptance: the elite rate is in range: one in twelve (%.4f) by the rule, %.4f measured over %d seeds (%.3f to %.3f)" % [DaemonArt.ELITE_RATE, rate, RATE_SEEDS, RATE_LOW, RATE_HIGH], is_equal_approx(DaemonArt.ELITE_RATE, 1.0 / 12.0) and rate >= RATE_LOW and rate <= RATE_HIGH)


## Every build's size inside its type's hitbox-safe range; an elite its type's biggest, with more
## armour than any other build of it.
func _size_checks() -> void:
	var out := PackedStringArray()
	var elites := PackedStringArray()
	var report := PackedStringArray()
	for type in TYPES:
		var script: Script = load(ART_DIR + type + ".gd")
		var low := INF
		var high := 0.0
		var low_seed := 0
		var high_seed := 0
		var most_armour := 0
		var range_low := 0.0
		var range_high := 0.0
		for k in BUILDS * 4:
			var seed := 20000 + k * 101
			if DaemonArt.elite_of(seed):
				continue
			var art := DaemonArt.make(script, null, seed)
			range_low = art.size_low
			range_high = art.size_high
			if art.size_scale < art.size_low - 0.0001 or art.size_scale > art.size_high + 0.0001:
				out.append("%s seed %d size %.3f" % [type, seed, art.size_scale])
			if art.size_scale < low:
				low = art.size_scale
				low_seed = seed
			if art.size_scale > high:
				high = art.size_scale
				high_seed = seed
			most_armour = maxi(most_armour, _armour(art))
			art.free()
		var elite_seed := _elite_seed(5000)
		var elite := DaemonArt.make(script, null, elite_seed)
		var elite_ok := elite.elite and is_equal_approx(elite.size_scale, elite.elite_size) and elite.elite_size > range_high and elite.elite_size <= 1.2 and _armour(elite) > most_armour
		report.append("%s %.3f to %.3f (range %.2f to %.2f), elite %.2f with %d armour parts (the most of any other %d)" % [type, low, high, range_low, range_high, elite.elite_size, _armour(elite), most_armour])
		if not elite_ok:
			elites.append(type)
		elite.free()
		# Each extreme and the elite drawn for two seconds: nothing outside its culling box, the tag
		# over it; the zombie's head in the head zone, rogue.d's box at its size.
		for seed in [low_seed, high_seed, elite_seed]:
			var problem: String = await _drawn_size(script, seed)
			if problem != "":
				out.append("%s seed %d: %s" % [type, seed, problem])
	print("DAEMON VARIETY sizes: " + "; ".join(report))
	_check("acceptance: sizes stay within the hitbox range: every build of every type inside its type's own range (rogue.d 0.88 to 1.08, the zombie 0.95 to 1.05, the runaway 0.92 to 1.06); at its smallest, its largest and as an elite nothing drawn outside its box, its tag over it, the zombie's head over the hit volume's head zone, rogue.d's body box scaled with it", out.is_empty(), "; ".join(out))
	_check("acceptance: an elite is its type's biggest (its own size, at most 1.2) and has more armour than any other build of its type (extra parts)", elites.is_empty(), ", ".join(elites))


## What is wrong with a daemon of `script` from `seed` drawn for WATCH frames, or "".
func _drawn_size(script: Script, seed: int) -> String:
	var holder := Node3D.new()
	root.add_child(holder)
	var art := DaemonArt.make(script, null, seed)
	holder.add_child(art)
	var outside := 0
	var head_out := 0
	var top := -INF
	var box := AABB(art.reach.position - Vector3.ONE * 0.001, art.reach.size + Vector3.ONE * 0.002)
	for f in WATCH:
		await process_frame
		var drawn := art.pose_bounds()
		if not box.encloses(drawn):
			outside += 1
		top = maxf(top, (art.transform * drawn.end).y)
		if art.has_method("head_at"):
			var head: Vector3 = art.transform * art.head_at()
			if head.y - DaemonArt.GROUND_Y < HEAD_LOW or head.y - DaemonArt.GROUND_Y > HEAD_HIGH or Vector2(head.x, head.z).length() > HEAD_OFF:
				head_out += 1
	var problem := ""
	if outside > 0:
		problem += "drawn outside its box in %d frames " % outside
	if art.tag_y() <= top:
		problem += "tag %.2f under its top %.2f " % [art.tag_y(), top]
	if head_out > WATCH / 20:
		problem += "head out of the zone in %d frames " % head_out
	if art.body_box_size() != Vector3.ZERO and not art.box_size().is_equal_approx(art.body_box_size() * art.size_scale):
		problem += "box %s at size %.3f " % [art.box_size(), art.size_scale]
	holder.queue_free()
	return problem


# --- In the real arena. ---

func _spawn_checks() -> void:
	var main := await _lab({"DummyA": Vector3(0.0, 0.0, 6.0), "DummyB": Vector3(-4.0, 0.0, 6.0), "DummyC": Vector3(4.0, 0.0, 6.0), "DummyD": Vector3(0.0, 1.0, 2.0)}, OPEN, true)
	var fixed := true
	var normal := true
	for name in NAMES:
		var dummy := _dummy(main, name)
		fixed = fixed and dummy.build_seed() == DaemonArt.seed_of(NAMES[name])
		normal = normal and not dummy.art_node().elite and is_equal_approx(dummy.max_health, 1.0)
	_check("acceptance: seeds are fixed in test mode: each arena daemon's build is its name's own seed, and the four roll no elite (every check's one-hit kill holds)", fixed and normal)
	# In play each spawn rolls a new daemon.
	Dummy.fixed_seeds = false
	var rogue := _dummy(main, "DummyA")
	var old_art: DaemonArt = rogue.art_node()
	var old_seed: int = rogue.build_seed()
	var old_id := old_art.get_instance_id()
	rogue.hit(1000.0)
	var back := await _wait(func(): return rogue.is_alive(), 400)
	var art: DaemonArt = rogue.art_node()
	var box: BoxShape3D = rogue.get_node("BodyBox").shape
	var rebuilt: bool = back >= 0 and rogue.build_seed() != old_seed and art.get_instance_id() != old_id and not is_instance_valid(old_art) and rogue.brain.art == art and art.get_parent() == rogue.get_node("Body") and box.size.is_equal_approx(art.box_size()) and is_equal_approx(rogue.get_node("Tag").position.y, art.tag_y()) and art.unstable() == 0.0
	Dummy.fixed_seeds = true
	print("DAEMON VARIETY spawn: rogue.d seed %d then %d after its respawn (%d frames), size %.3f then %.3f" % [old_seed, rogue.build_seed(), back, old_art.size_scale if is_instance_valid(old_art) else -1.0, art.size_scale])
	_check("acceptance: in play every spawn is a new daemon: killed and back, rogue.d is rebuilt from a new seed while it is nothing, the old art freed, its brain, its body box and its tag on the new one, whole again", rebuilt)
	# An elite takes a cannon shot and lives; a normal one does not.
	var elite_seed := _elite_seed(77)
	var zombie := _dummy(main, "DummyB")
	zombie.follow_seed(elite_seed)
	zombie.reset_for_round()  # a fresh life at the elite's health, as its spawn would give it
	var lived: bool = zombie.hit(CANNON) and zombie.is_alive()
	var health: float = zombie.health()
	var second: bool = zombie.hit(CANNON) and not zombie.is_alive()
	var plain := _dummy(main, "DummyC")
	var one: bool = plain.hit(CANNON) and not plain.is_alive()
	var tuning: DaemonAiTuning = load("res://resources/daemon_ai.tres")
	print("DAEMON VARIETY elite: an elite zombie at %.0f health took a cannon shot to %.0f; the defunct one at %.0f" % [zombie.max_health, health, plain.max_health])
	_check("acceptance: an elite's modest health bump: an elite takes at least elite_health (%.0f, a cannon shot and it lives at %.0f, the second kills it), a normal daemon 1 (one hit)" % [tuning.elite_health, health], zombie.art_node().elite and is_equal_approx(zombie.max_health, tuning.elite_health) and lived and second and one)
	await _drop(main)


## Killing the runaway's core scatters its swarm: every drone flies off whole and away from it.
func _scatter_checks() -> void:
	var main := await _lab({"DummyD": Vector3(0.0, 1.0, 4.0)}, OPEN, true)
	var runaway := _dummy(main, "DummyD")
	for f in 30:
		await process_frame
	var art: DaemonArt = runaway.art_node()
	var drones: int = art.drone_count()
	var core: Vector3 = runaway.threat_point()
	runaway.hit(1000.0, core, Vector3.FORWARD)
	await physics_frame
	var burst := _burst(main)
	var groups: int = burst.group_count() if burst != null else 0
	var start := _mean_out(burst, core) if burst != null else 0.0
	var gaps := _gaps(burst) if burst != null else PackedFloat32Array()
	for f in SCATTER_FRAMES:
		await physics_frame
	var fled := 0
	var later := 0.0
	var whole := true
	if burst != null and is_instance_valid(burst):
		later = _mean_out(burst, core)
		var middles: PackedVector3Array = burst.group_middles()
		for g in middles.size():
			fled += 1 if middles[g].distance_to(core) > 1.5 else 0
		var now := _gaps(burst)
		for i in gaps.size():
			whole = whole and absf(now[i] - gaps[i]) < 0.001
	print("DAEMON VARIETY scatter: %d drones, %d groups in the burst, %.2f m from the core on average at the kill, %.2f m %d frames later, %d past 1.5 m" % [drones, groups, start, later, SCATTER_FRAMES, fled])
	_check("acceptance: killing the runaway core scatters the swarm: its death flies every one of its drones off whole (one group each), all of them away from the core, %.0f m farther on average within %.1f s" % [SCATTER_GAIN, SCATTER_FRAMES / 60.0], drones >= 12 and groups == drones and later > start + SCATTER_GAIN and fled == drones and whole and not gaps.is_empty())
	await _drop(main)


## The burst under `main`'s derezz, or null.
func _burst(main: Node) -> Node:
	for node in get_nodes_in_group(Shatter.GROUP):
		if main.is_ancestor_of(node):
			return node
	return null


## How far a burst's groups are from `from` on average.
func _mean_out(burst: Node, from: Vector3) -> float:
	var middles: PackedVector3Array = burst.group_middles()
	var total := 0.0
	for m in middles:
		total += m.distance_to(from)
	return total / maxf(middles.size(), 1.0)


## The distance from each grouped part to the next part of the same group: unchanged while the
## group flies whole.
func _gaps(burst: Node) -> PackedFloat32Array:
	var out := PackedFloat32Array()
	var groups: PackedInt32Array = burst.part_groups()
	var at: PackedVector3Array = burst.positions()
	for i in groups.size() - 1:
		if groups[i] >= 0 and groups[i + 1] == groups[i]:
			out.append(at[i].distance_to(at[i + 1]))
	return out


# --- A match. ---

func _match_checks() -> void:
	GameSettings.current().set_value("gameplay", "practice", false)
	GameSettings.current().set_value("gameplay", "difficulty", "normal")
	var host := _branch("Host", Vector3.ZERO)
	var client := _branch("Client", CLIENT_OFFSET)
	await _frames(2)
	var joined := await _join(host, client)
	var hs = host["session"]
	var cs = client["session"]
	await _wait(func(): return cs.host_practice == false, 120)
	# The players far off and every daemon of both screens parked: nothing hunts in this check.
	host["player"].global_position = host["main"].to_global(Vector3(15.0, 0.95, -15.0))
	client["player"].global_position = client["main"].to_global(Vector3(-15.0, 0.95, 15.0))
	for name in NAMES:
		_park(_dummy(host["main"], name))
	await _frames(30)
	var alike := true
	for name in NAMES:
		alike = alike and _dummy(client["main"], name).build_seed() == _dummy(host["main"], name).build_seed()
	# A joiner's copy built wrong is put right by the host's word.
	var copy := _dummy(client["main"], "DummyB")
	copy.follow_seed(123457)
	var wrong: int = copy.build_seed()
	var righted := await _wait(func(): return copy.build_seed() == _dummy(host["main"], "DummyB").build_seed(), 60)
	# The host's daemon respawned as a new one: the joiner's copy follows.
	Dummy.fixed_seeds = false
	var host_rogue := _dummy(host["main"], "DummyA")
	var copy_rogue := _dummy(client["main"], "DummyA")
	var before: int = host_rogue.build_seed()
	host_rogue.hit(1000.0)
	var respawned := await _wait(func(): return host_rogue.is_alive() and host_rogue.build_seed() != before, 400)
	Dummy.fixed_seeds = true
	var followed := await _wait(func(): return copy_rogue.build_seed() == host_rogue.build_seed() and copy_rogue.is_alive(), 120)
	var same_build: bool = copy_rogue.art_node().part_count() == host_rogue.art_node().part_count() and is_equal_approx(copy_rogue.art_node().size_scale, host_rogue.art_node().size_scale) and copy_rogue.art_node().elite == host_rogue.art_node().elite and is_equal_approx(copy_rogue.max_health, host_rogue.max_health)
	print("DAEMON VARIETY match: joined %s, the copies' seeds the host's %s, a wrong copy (%d) put right in %d frames, the host's respawn (%d frames) followed in %d frames" % [joined, alike, wrong, righted, respawned, followed])
	_check("acceptance: in a match the host's seeds build every client's daemons: the joiner's copies are the host's builds, a copy built wrong is put right by the host's word, and the host's daemon respawned as a new one is the same new one on the joiner's screen (its parts, its size, elite or not, its health)", joined and Session.PROTOCOL == 18 and alike and wrong == 123457 and righted >= 0 and respawned >= 0 and followed >= 0 and same_build)
	# The runaway: the joiner's shot lands nothing on it; the host's kill scatters it on both screens.
	var host_swarm := _dummy(host["main"], "DummyD")
	var copy_swarm := _dummy(client["main"], "DummyD")
	_place(host_swarm, host["main"].to_global(Vector3(0.0, 1.0, 4.0)))
	await _frames(20)
	var refused: bool = not copy_swarm.hit(1000.0) and copy_swarm.is_alive()
	await _frames(2)
	var none_early := _burst(client["main"]) == null
	host_swarm.hit(1000.0)
	var told := await _wait(func(): return _burst(client["main"]) != null, 60)
	var burst := _burst(client["main"])
	var groups: int = burst.group_count() if burst != null else 0
	_check("acceptance: the swarm's scatter is the host's: a joiner's shot lands nothing on the host's runaway and scatters nothing, and the host's kill scatters every drone on the joiner's screen too", refused and none_early and told >= 0 and groups == copy_swarm.art_node().drone_count() and groups >= 12, "%d groups" % groups)
	await _drop_side(client)
	await _drop_side(host)
	GameSettings.current().set_value("gameplay", "practice", true)


# --- Helpers. ---

## A seed past `from` that rolls an elite, or a plain one when none of the next thousands do (an
## elite rule that never fires fails the elite checks; it never hangs the test).
func _elite_seed(from: int) -> int:
	for seed in range(from, from + 5000):
		if DaemonArt.elite_of(seed):
			return seed
	return from


## The armour parts of `art`.
func _armour(art: DaemonArt) -> int:
	var count := 0
	for id in art.part_count():
		count += 1 if art.part_look(id) == DaemonArt.Look.ARMOR else 0
	return count


func _world() -> Node3D:
	var world := Node3D.new()
	root.add_child(world)
	_scratch.append(world)
	return world


## A fresh arena with the daemons in `keep` (name -> place, arena space) and every other parked
## under the floor, the player at `player_at`, practice `practice`.
func _lab(keep: Dictionary, player_at: Vector3, practice: bool) -> Node:
	GameSettings.current().set_value("gameplay", "practice", practice)
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
	await process_frame


func _dummy(main: Node, name: String) -> Node3D:
	return main.get_node("Arena/Targets/" + name)


## A daemon put at `at` (world space), at home there.
func _place(dummy: Node3D, at: Vector3) -> void:
	dummy.global_position = at
	dummy.global_rotation = Vector3.ZERO
	dummy.brain.take_home()
	dummy.brain.moved = false
	dummy.brain.state = DaemonBrain.State.HOME
	dummy.brain.prey = 0


func _park(dummy: Node3D) -> void:
	_place(dummy, dummy.get_parent().get_parent().get_parent().to_global(PARKED + Vector3(dummy.get_index() * 3.0, 0.0, 0.0)))


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
