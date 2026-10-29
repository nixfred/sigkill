extends SceneTree
## Headless test of ping, weapon 9, for SIGKILL (C28, PRD 5.2: "ping: sonar pulse that reveals
## hidden daemons"). scripts/check.sh runs it as step 38, and any FAIL exits 1.
##
##   godot --headless --path . --fixed-fps 60 --script res://tests/ping_test.gd
##
## The weapon: slot 9 on key 9, its resource's numbers and its checks, a cooldown with no ammo and no
## damage, its own lime. In the real arena, with the real player firing it: the ring grows to its
## radius over its time, fires its streaks and goes; a daemon behind a wall (out of every sight line)
## is outlined through the level with its tag, drawn with no depth test, and not roused; nothing
## outside the radius is revealed; the reveal holds, fades over its last part and expires, and a
## derezz ends it; a ping during a tell calls the attack off (rogue.d rearing, the zombie's claw
## raised with the ember in it, the swarm pulling in before a dive) and staggers it, no strike, no
## bolt, no dive and no damage, and it fights again after; a ping outside a tell changes nothing; the
## cooldown holds (the strip and the dish's rings show it); practice never breaks (the reveal still
## works, nothing leaves home, tells or attacks). Then a host and a joiner over ENet on 127.0.0.1
## (the joiner's arena 1000 m off): the joiner's ping is judged by the host (its rogue caught mid-tell
## staggers, a second ping too soon is refused), the ring drawn on both screens, the outline only on
## the joiner's; protocol 10, no new message. And the fiction rule for the ping code, and nothing
## made while a ring flies or an outline holds. Deterministic: frames counted, only counts and
## outcomes printed.

const Session = preload("res://scripts/net/net_session.gd")
const NetTuningScript = preload("res://scripts/net/net_tuning.gd")
const Link = preload("res://scripts/guide/guide_link.gd")
const MainScene = preload("res://scenes/main.tscn")
const Controls = preload("res://scripts/controls.gd")
const Palette = preload("res://scripts/palette.gd")
const WeaponDefScript = preload("res://scripts/weapons/weapon_def.gd")
const PING_PATH := "res://resources/ping_sonar.tres"
const ARSENAL_PATH := "res://resources/arsenal.tres"
const PING_CODE := ["res://scripts/weapons/ping_pulse.gd", "res://scripts/weapons/ping_reveal.gd", "res://scripts/viewmodels/ping_sonar.gd"]
const WATCHDOG_MS := 12000
const CLIENT_OFFSET := Vector3(1000.0, 0.0, 0.0)
## Open floor south of the low wall, clear of the crates and the platform.
const OPEN := Vector3(0.0, 0.95, 15.0)
## Where a daemon a check does not use waits: under the floor, out of every sight line.
const PARKED := Vector3(0.0, -50.0, 0.0)
## The west cover wall, CoverL1: x from -15 to -9, z from 1.8 to 2.2, 3 m high.
const WALL_X := -12.0
const SLOT := 8
const NEVER := ["OS.", "execute", "create_process", "kill(", "Thread", "HTTP", "PacketPeer", "StreamPeer", "TCPServer", "UDPServer", "DirAccess", "FileAccess", "shell_open", "move_to_trash", "Expression", "Time.", "ctrl_pressed", "alt_pressed", "rpc"]
const EPS := 0.001

var _fails := 0
var _checks := 0
var _tmp := ""
var _arenas: Array = []
var _branches: Array = []
var _def: Resource
var _t: DaemonAiTuning


func _initialize() -> void:
	_run()


func _run() -> void:
	await process_frame
	root.size = Vector2i(1280, 720)
	_tmp = OS.get_temp_dir().path_join("sigkill-ping-test-%d" % OS.get_process_id())
	if DirAccess.dir_exists_absolute(_tmp):
		print("FAIL the test's temporary folder already exists; not touching it")
		quit(1)
		return
	DirAccess.make_dir_recursive_absolute(_tmp)
	Controls.ensure()
	GameSettings.current().reset()
	_def = load(PING_PATH)
	_t = load("res://resources/daemon_ai.tres")
	_source_checks()
	_weapon_checks()
	await _ring_checks()
	await _wall_checks()
	await _radius_checks()
	await _expiry_checks()
	await _tell_checks()
	await _cooldown_checks()
	await _practice_checks()
	await _match_checks()
	await _cleanup()
	for name in DirAccess.get_files_at(_tmp):
		DirAccess.remove_absolute(_tmp.path_join(name))
	DirAccess.remove_absolute(_tmp)
	print("PING: %d checks" % _checks)
	print("PING RESULT: ", "ALL PASS" if _fails == 0 else "%d FAILED" % _fails)
	quit(0 if _fails == 0 else 1)


func _check(label: String, ok: bool, detail: String = "") -> void:
	_checks += 1
	print("PASS " if ok else "FAIL ", label, ("   " + detail) if detail != "" else "")
	if not ok:
		_fails += 1


# --- The code, the weapon and its numbers. ---

func _source_checks() -> void:
	var code := ""
	for path in PING_CODE:
		code += _code(path)
	var found := PackedStringArray()
	for word in NEVER:
		if code.contains(word):
			found.append(word)
	_check("acceptance: fiction only: the ping code (the ring, the reveal, the model) makes no OS, process, file, folder, thread or network call, no RPC, reads no wall clock and handles no Ctrl or Alt key", found.is_empty() and code.length() > 5000, ", ".join(found))
	var reveal := FileAccess.get_file_as_string("res://shaders/ping_reveal.gdshader")
	var wave := FileAccess.get_file_as_string("res://shaders/ping_wave.gdshader")
	_check("acceptance: the outline shows through walls: its shader draws with no depth test, unlit and additive, from the daemon's own posed parts (their presence honoured)", reveal.contains("depth_test_disabled") and reveal.contains("blend_add") and reveal.contains("unshaded") and reveal.contains("INSTANCE_CUSTOM") and reveal.contains("instance uniform float reveal"))
	_check("the ring never reads or warps the picture: no screen texture, no UV moved", not wave.contains("SCREEN") and not wave.contains("hint_screen_texture") and not wave.contains("UV =") and not reveal.contains("SCREEN"))
	var pulse := _code(PING_CODE[0])
	var lit := _code(PING_CODE[1])
	var each := _body(pulse, "_physics_process") + _body(pulse, "_step") + _body(pulse, "_meet") + _body(lit, "_process") + _body(lit, "_step") + _body(lit, "light")
	var made := PackedStringArray()
	for word in [".new(", "instantiate(", "duplicate(", "Mesh(", "Material("]:
		if each.contains(word):
			made.append(word)
	_check("acceptance: nothing is made while a ring flies or an outline holds: what runs each frame (the ring's step and meeting, the reveal's step and lighting) makes no node, mesh or material; the ring's meshes and materials are made once for every ping, and a daemon's outline once, the first time a ping meets it (PingReveal.of), then kept", made.is_empty() and each.length() > 1500 and pulse.contains("if _floor_mesh == null") and pulse.contains("if _floor_material == null") and lit.contains("if _material == null"), ", ".join(made))


func _weapon_checks() -> void:
	var d: WeaponDefScript = _def
	_check("acceptance: ping is its own weapon on the framework: fire mode ping, no magazine, no ammo, no damage, a 7 s cooldown, an 18 m ring in 0.5 s, a 4 s reveal fading over its last 0.8 s, in lime, with its own model", d is WeaponDefScript and d.problems().is_empty() and d.id == "ping_sonar" and d.is_ping() and not d.has_magazine() and d.damage == 0.0 and d.fire_cooldown == 7.0 and d.ping_radius_m == 18.0 and d.ping_ring_s == 0.5 and d.reveal_s == 4.0 and d.reveal_fade_s == 0.8 and d.light_skin == "lime" and d.viewmodel_model.resource_path == "res://scripts/viewmodels/ping_sonar.gd", str(d.problems()))
	var arsenal = load(ARSENAL_PATH)
	var others := {}
	for other in arsenal.loadout:
		if other.id != d.id:
			others[other.skin_body()] = true
			others[other.skin_beam()] = true
	_check("acceptance: slot 9 (key 9), the last slot: the arsenal holds nine, ping the ninth", arsenal.problems().is_empty() and arsenal.loadout.size() == 9 and arsenal.loadout[SLOT].id == "ping_sonar" and Controls.SLOT_KEYS[SLOT] == KEY_9)
	_check("acceptance: its light colour is its own: neither of lime's colours is any of the eight other weapons', nor hostile red or amber, nor the code rain's green", not others.has(Palette.LIME) and not others.has(Palette.LIME_HI) and not [Palette.HOSTILE_RED, Palette.HOSTILE_AMBER, Palette.MATRIX_GREEN].has(Palette.LIME) and Palette.SKINS["lime"] == [Palette.LIME, Palette.LIME_HI])
	var cases := [
		["magazine_size", 6, "cooldown, not ammo"], ["damage", 5.0, "no damage"], ["fire_cooldown", 0.5, "cooldown"],
		["ping_radius_m", 0.0, "ping_radius_m"], ["ping_radius_m", 61.0, "ping_radius_m"], ["ping_ring_s", 0.0, "ping_ring_s"],
		["reveal_s", 0.0, "reveal_s"], ["reveal_fade_s", 5.0, "reveal_fade_s"], ["pellet_count", 3, "one ring"],
	]
	var missed := PackedStringArray()
	for case in cases:
		var bad: Resource = d.duplicate()
		bad.set(case[0], case[1])
		var text := ", ".join(bad.problems())
		if not text.contains(case[2]):
			missed.append("%s=%s gave [%s]" % [case[0], case[1], text])
	var cannon: Resource = load("res://resources/terminal_cannon.tres").duplicate()
	cannon.ping_radius_m = 5.0
	if not ", ".join(cannon.problems()).contains("only ping"):
		missed.append("a cannon with a ping radius was not refused")
	_check("bad ping numbers are each refused with the reason: a magazine, damage, a short cooldown, no or too wide a ring, no ring time, no reveal, a fade longer than the reveal, more than one ring, a ping group on another weapon (%d cases)" % (cases.size() + 1), missed.is_empty(), "; ".join(missed))


# --- The ring. ---

func _ring_checks() -> void:
	var main := await _lab({}, OPEN)
	var p = main.get_node("Player")
	var ready := await _draw_ping(p)
	var fx := ParticleFx.of(main)
	var streaks: int = fx.fired(ParticleFx.Kind.PING) if fx != null else -1
	var shots: int = p.shots_fired
	await _ping(p)
	var pulse = p.last_ping
	var made: bool = pulse != null and is_instance_valid(pulse)
	await _frames(15)
	var half: float = pulse.radius() if made and is_instance_valid(pulse) else -1.0
	await _frames(15)
	var full: float = pulse.radius() if is_instance_valid(pulse) else -1.0
	# Read now: once the pulse frees itself, its nodes compare equal to null.
	var drawn: bool = is_instance_valid(pulse) and pulse.get_node_or_null("Floor") is MeshInstance3D and pulse.get_node_or_null("Wall") is MeshInstance3D
	var held := [pulse]  # never the freed node itself in the lambda
	var gone := await _wait(func(): return not is_instance_valid(held[0]), 60)
	_check("acceptance: fire sends one sonar ring out from the player: it grows to %.1f m at a quarter second and %.1f m (its radius) at its 0.5 s, with its floor ring, its wall of light and its streaks (%d fired), then fades and goes (%d frames after)" % [half, full, (fx.fired(ParticleFx.Kind.PING) - streaks) if fx != null else -1, gone], ready and made and absf(half - 9.0) < 0.7 and absf(full - 18.0) < EPS and drawn and fx != null and fx.fired(ParticleFx.Kind.PING) == streaks + 1 and gone >= 0)
	_check("a ping is no shot: no round's shot counted, nothing of the arena hit (every daemon whole)", p.shots_fired == shots and p.pings_sent == 1 and main.get_node("Arena/Targets").get_children().all(func(t): return t.health() == t.max_health))
	await _drop(main)


# --- What it shows. ---

func _wall_checks() -> void:
	var main := await _lab({"DummyA": Vector3(WALL_X, 0.0, 3.2), "DummyC": Vector3(WALL_X + 1.0, 0.0, 6.0)}, Vector3(WALL_X, 0.95, 0.9))
	var p = main.get_node("Player")
	var director: DaemonDirector = main.get_node("DaemonDirector")
	var rogue: Node3D = _dummy(main, "DummyA")
	var zombie: Node3D = _dummy(main, "DummyC")
	await _draw_ping(p)
	var eye: Vector3 = p.eye_position()
	var hidden: bool = not director.clear(eye, rogue.threat_point()) and not director.clear(eye, zombie.threat_point())
	await _ping(p)
	await _frames(20)
	var a := PingReveal.find(rogue.art_node())
	var c := PingReveal.find(zombie.art_node())
	var outlined: bool = a != null and a.lit() and a.visible and a.strength() == 1.0 and a.outlines().size() >= 2 and c != null and c.lit()
	var drawn_through := true
	for ghost in (a.outlines() if a != null else []):
		drawn_through = drawn_through and ghost.is_visible_in_tree() and ghost.multimesh != null and rogue.art_node().sets().any(func(s): return s.multimesh == ghost.multimesh) and (ghost.material_override as ShaderMaterial).shader.code.contains("depth_test_disabled") and ghost.get_instance_shader_parameter(&"reveal") == 1.0
	var tag: Label3D = a.get_node("Tag") if a != null else null
	var tagged: bool = tag != null and tag.is_visible_in_tree() and tag.no_depth_test and tag.fixed_size and tag.text.begins_with(rogue.tag_text) and tag.text.ends_with("m")
	_check("acceptance: a ping reveals a daemon behind a wall: rogue.d and a zombie behind the west cover wall (no sight line to either) are outlined through it, their own posed parts drawn with no depth test", hidden and outlined and drawn_through, "hidden %s outlined %s through %s" % [hidden, outlined, drawn_through])
	_check("acceptance: and tagged through the wall: its name and how far (\"%s\"), with no depth test, the same size near or far" % (tag.text if tag != null else ""), tagged)
	await _frames(60)
	_check("a ping is no hit: the daemons it found behind the wall are not roused (still at home, no hunt, no tell), and take nothing", rogue.brain.state == DaemonBrain.State.HOME and zombie.brain.state == DaemonBrain.State.HOME and rogue.brain.tells == 0 and rogue.health() == rogue.max_health and zombie.health() == zombie.max_health)
	await _drop(main)


func _radius_checks() -> void:
	# The player on open floor; rogue.d 17 m off (inside the 18 m ring), a zombie 19.3 m off (outside
	# it), both beyond the daemons' 16 m sight, so neither moves.
	var main := await _lab({"DummyA": Vector3(0.0, 0.0, -2.0), "DummyC": Vector3(-10.0, 0.0, -1.5)}, OPEN)
	var p = main.get_node("Player")
	var inside: Node3D = _dummy(main, "DummyA")
	var outside: Node3D = _dummy(main, "DummyC")
	await _draw_ping(p)
	var near: float = p.global_position.distance_to(inside.threat_point())
	var far: float = p.global_position.distance_to(outside.threat_point())
	await _ping(p)
	var pulse = p.last_ping
	var held := [pulse]
	var met_at := await _wait(func(): return is_instance_valid(held[0]) and held[0].met_daemons().has(inside), 40)
	var met_far := false
	var lit_far := false
	for i in 90:
		await physics_frame
		met_far = met_far or (is_instance_valid(pulse) and pulse.met_daemons().has(outside))
		var r := PingReveal.find(outside.art_node())
		lit_far = lit_far or (r != null and r.lit())
	var r_in := PingReveal.find(inside.art_node())
	_check("acceptance: nothing outside the radius is revealed: rogue.d %.1f m off is met when the ring reaches it (frame %d of 30) and outlined; a zombie %.1f m off, past the 18 m ring, is never met nor outlined" % [near, met_at, far], near < 18.0 and far > 18.5 and met_at >= 26 and met_at <= 31 and r_in != null and r_in.lit() and not met_far and not lit_far)
	await _drop(main)
	# A ping is no hit: rogue.d at home 17 m off along open floor, in plain sight but past its 16 m
	# aggro range, is met and outlined, and not roused.
	main = await _lab({}, Vector3(-17.0, 0.95, 15.0))
	p = main.get_node("Player")
	var director: DaemonDirector = main.get_node("DaemonDirector")
	var watcher: Node3D = _dummy(main, "DummyA")
	await _draw_ping(p)
	_place(watcher, Vector3(0.0, 0.0, 15.0))
	await _frames(20)  # it looks every 0.2 s, and does not spot a player 17 m off
	var sees: bool = director.clear(watcher.global_position + Vector3.UP * _t.eye_height_m, director.prey_point(1))
	var quiet: bool = watcher.brain.state == DaemonBrain.State.HOME and watcher.brain.prey == 0
	await _ping(p)
	await _frames(60)
	var seen := PingReveal.find(watcher.art_node())
	_check("a ping is no hit and rouses no one: rogue.d at home 17 m off, in plain sight but past its 16 m aggro range, is outlined and stays home, hunting no one (%s)" % DaemonBrain.STATE_NAMES[watcher.brain.state], sees and quiet and seen != null and seen.lit() and watcher.brain.state == DaemonBrain.State.HOME and watcher.brain.prey == 0)
	await _drop(main)


func _expiry_checks() -> void:
	var main := await _lab({"DummyA": Vector3(WALL_X, 0.0, 3.2)}, Vector3(WALL_X, 0.95, 0.9))
	var p = main.get_node("Player")
	var rogue: Node3D = _dummy(main, "DummyA")
	await _draw_ping(p)
	await _ping(p)
	var lit_at := await _wait(func(): return PingReveal.find(rogue.art_node()) != null and PingReveal.find(rogue.art_node()).lit(), 30)
	var r := PingReveal.find(rogue.art_node())
	var held := true
	var fading := false
	var monotone := true
	var last := 1.0
	var frames := 0
	var hold_frames := roundi((_def.reveal_s - _def.reveal_fade_s) * 60.0)
	while r != null and r.lit() and frames < 600:
		await physics_frame
		frames += 1
		var s := r.strength()
		if frames < hold_frames - 3:
			held = held and s == 1.0
		if s > 0.0 and s < 1.0:
			fading = true
		monotone = monotone and s <= last + EPS
		last = s
	await _frames(2)
	var reveal_frames := roundi(_def.reveal_s * 60.0)
	_check("acceptance: the reveal expires: lit when the ring reaches the daemon (frame %d), it holds full for its first %.1f s, fades over its last %.1f s and is out after %d frames (its %.0f s), outline and tag hidden" % [lit_at, _def.reveal_s - _def.reveal_fade_s, _def.reveal_fade_s, frames, _def.reveal_s], lit_at >= 0 and r != null and held and fading and monotone and not r.lit() and not r.visible and r.strength() == 0.0 and absi(frames - reveal_frames) <= 2, "%d frames" % frames)
	# Lit again by the next ping (once the cooldown allows), then a derezz ends it at once.
	await _ping(p)
	var relit := await _wait(func(): return r.lit(), 20)
	rogue.hit(1000.0)
	await _frames(2)
	_check("a later ping lights it again, and a derezz ends it at once (the body gone, no outline left behind)", relit >= 0 and not r.lit() and not r.visible and not rogue.is_alive())
	await _drop(main)


# --- What it does to an attack. ---

func _tell_checks() -> void:
	# rogue.d rearing: caught mid-tell, the attack is called off and it staggers. Each daemon is put
	# in place only once ping is in hand, so the tell caught is its first.
	var main := await _lab({}, OPEN)
	var p = main.get_node("Player")
	var life = main.get_node("SoloLife")
	var rogue: DaemonBrain = _dummy(main, "DummyA").brain
	await _draw_ping(p)
	_place(rogue.dummy, Vector3(0.0, 0.0, 12.5))
	var telling := await _wait(func(): return rogue.state == DaemonBrain.State.TELL and rogue.state_t > 0.15, 600)
	var rear_before: float = rogue.art.rear()
	var attacks := rogue.attacks
	var health: float = life.health()
	var from: Vector3 = rogue.dummy.global_position
	await _ping(p)
	var staggered := await _wait(func(): return rogue.staggers == 1, 10)
	var state_then := rogue.state
	var slot_kept := rogue.holds_slot
	await _frames(4)
	var reel: float = rogue.art.staggered()
	var no_strike := true
	var knocked := 0.0
	for i in roundi(_t.ping_stagger_s * 60.0) + 10:
		await physics_frame
		no_strike = no_strike and rogue.attacks == attacks and life.health() == health
		if rogue.state == DaemonBrain.State.SCATTER:
			knocked = maxf(knocked, Vector2(rogue.dummy.global_position.x - from.x, rogue.dummy.global_position.z - from.z).length())
	var after := rogue.state
	var again := await _wait(func(): return rogue.tells >= 2, 600)
	_check("acceptance: a ping during a tell interrupts that attack: rogue.d caught rearing (%.2f up) in its first tell staggers at once (%s), its slot given back, no strike and no damage through the stagger, knocked %.2f m back, then hunts again and tells anew (%d frames on)" % [rear_before, DaemonBrain.STATE_NAMES[state_then], knocked, again], telling >= 0 and rogue.tells == 2 and attacks == 0 and health == 100.0 and rear_before > 0.1 and staggered >= 0 and state_then == DaemonBrain.State.SCATTER and rogue.events.any(func(e): return e[1] == "stagger") and not slot_kept and no_strike and knocked <= _t.ping_knock_m + 0.05 and knocked > 0.2 and after == DaemonBrain.State.HUNT and again >= 0, "%s | tells %d attacks %d health %.0f staggered %d state %s events %s slot %s no_strike %s after %s" % [_events(rogue), rogue.tells, attacks, health, staggered, state_then, rogue.events.any(func(e): return e[1] == "stagger"), slot_kept, no_strike, DaemonBrain.STATE_NAMES[after]])
	_check("the stagger is drawn: rogue.d reels (%.2f) and glitches, and never rears in it" % reel, reel > 0.5 and rogue.art.rear() < rear_before)
	await _drop(main)
	# The zombie with its claw raised and the ember out: no bolt thrown.
	main = await _lab({}, OPEN)
	p = main.get_node("Player")
	life = main.get_node("SoloLife")
	var director: DaemonDirector = main.get_node("DaemonDirector")
	var zombie: DaemonBrain = _dummy(main, "DummyC").brain
	await _draw_ping(p)
	_place(zombie.dummy, Vector3(0.0, 0.0, 8.0))
	telling = await _wait(func(): return zombie.state == DaemonBrain.State.TELL and zombie.state_t > 0.2, 600)
	attacks = zombie.attacks
	await _ping(p)
	staggered = await _wait(func(): return zombie.staggers == 1, 30)
	var thrown := 0
	for i in 70:
		await physics_frame
		thrown = maxi(thrown, director.bolts_live())
	_check("acceptance: a zombie caught charging its bolt (claw raised, the ember out) throws nothing: it staggers, no bolt in the air, no damage", telling >= 0 and staggered >= 0 and attacks == 0 and zombie.attacks == attacks and thrown == 0 and life.health() == 100.0, "%s | telling %d staggered %d attacks %d/%d thrown %d health %.0f" % [_events(zombie), telling, staggered, attacks, zombie.attacks, thrown, life.health()])
	await _drop(main)
	# The swarm pulling in before a dive: it scatters, its burst over.
	main = await _lab({}, OPEN)
	p = main.get_node("Player")
	life = main.get_node("SoloLife")
	var swarm: DaemonBrain = _dummy(main, "DummyD").brain
	await _draw_ping(p)
	_place(swarm.dummy, Vector3(3.0, 1.0, 11.0))
	telling = await _wait(func(): return swarm.state == DaemonBrain.State.TELL and swarm.state_t > 0.1, 600)
	attacks = swarm.attacks
	await _ping(p)
	staggered = await _wait(func(): return swarm.staggers == 1, 30)
	var scattered := swarm.state == DaemonBrain.State.SCATTER and swarm.burst_left == 0
	var dived := false
	for i in roundi(_t.swarm_scatter_s * 60.0):
		await physics_frame
		dived = dived or swarm.attacks != attacks
	_check("acceptance: the swarm caught pulling in before a dive scatters: no dive, its burst over, no damage", telling >= 0 and staggered >= 0 and attacks == 0 and scattered and not dived and life.health() == 100.0, _events(swarm))
	await _drop(main)
	# Outside a tell a ping changes nothing: rogue.d hunting the player, not yet in reach, goes on.
	main = await _lab({}, OPEN)
	p = main.get_node("Player")
	rogue = _dummy(main, "DummyA").brain
	await _draw_ping(p)
	_place(rogue.dummy, Vector3(0.0, 0.0, 6.0))
	var hunting := await _wait(func(): return rogue.state == DaemonBrain.State.HUNT, 120)
	await _ping(p)
	await _frames(20)
	_check("a ping outside a tell changes nothing: rogue.d hunting, not yet in reach, goes on hunting, never staggered", hunting >= 0 and rogue.staggers == 0 and (rogue.state == DaemonBrain.State.HUNT or rogue.state == DaemonBrain.State.TELL), _events(rogue))
	await _drop(main)


# --- The cooldown. ---

func _cooldown_checks() -> void:
	var main := await _lab({}, OPEN)
	var p = main.get_node("Player")
	var wh = main.get_node("Hud").weapon_hud()
	await _draw_ping(p)
	await _frames(roundi(load(ARSENAL_PATH).fiction_s * 60.0))  # past the fiction line drawing shows
	var ready_line: String = wh.ammo_text()
	var ready_state: String = wh.state_text()
	var ready_rings: float = p.get("_viewmodel").charge()
	var wait_frames := roundi(_def.fire_cooldown * 60.0)
	var second := -1
	var line_mid := ""
	var state_mid := ""
	var rings_mid := -1.0
	var model_glow := true
	for i in wait_frames + 30:
		p.drive_input(Vector2.ZERO, false, false, true)  # fire held all the way
		await physics_frame
		if i == wait_frames / 2 + 3:
			line_mid = wh.ammo_text()
			state_mid = wh.state_text()
			rings_mid = p.get("_viewmodel").charge()
		model_glow = model_glow and absf(p.get("_viewmodel").charge() - p.ping_ready()) < EPS
		if second < 0 and p.pings_sent >= 2:
			second = i
	_check("acceptance: the cooldown holds: fire held for %.1f s sends a ping at once and the next only after its %.0f s cooldown (frame %d), never sooner" % [(wait_frames + 30) / 60.0, _def.fire_cooldown, second], p.pings_sent == 2 and second >= wait_frames - 2 and second <= wait_frames + 2)
	_check("the strip shows it: \"%s\" / \"%s\" ready, \"%s\" / \"%s\" halfway" % [ready_line, ready_state, line_mid, state_mid], ready_line == "ping  ready" and ready_state == "sonar ready: 18m" and line_mid.begins_with("ping  3.") and line_mid.ends_with("s") and state_mid == "sonar [#####.....]")
	_check("and so does the model: the dish's rings all lit when ready (%.2f), half lit halfway (%.2f), following the cooldown every frame" % [ready_rings, rings_mid], ready_rings == 1.0 and absf(rings_mid - 0.5) < 0.03 and model_glow)
	await _drop(main)


# --- Practice. ---

func _practice_checks() -> void:
	var main := await _lab({"DummyA": Vector3(0.0, 0.0, 12.5), "DummyC": Vector3(0.0, 0.0, 8.0), "DummyD": Vector3(3.0, 1.0, 11.0)}, OPEN, true)
	var p = main.get_node("Player")
	var life = main.get_node("SoloLife")
	var director: DaemonDirector = main.get_node("DaemonDirector")
	await _draw_ping(p)
	await _frames(30)
	var homes := {}
	for brain in director.brains():
		homes[brain] = brain.dummy.global_position
	var still := true
	var lit := 0
	await _ping(p)
	for i in 240:
		await physics_frame
		for brain in director.brains():
			still = still and brain.state == DaemonBrain.State.HOME and brain.dummy.global_position.distance_to(homes[brain]) < EPS and brain.tells == 0 and brain.staggers == 0
		if i == 30:
			for name in ["DummyA", "DummyC", "DummyD"]:
				var r := PingReveal.find(_dummy(main, name).art_node())
				lit += 1 if r != null and r.lit() else 0
	_check("acceptance: practice mode never breaks: a ping in practice still outlines all three daemons (%d), and nothing of practice changes: every daemon stays home and still, never tells, never staggers, the player whole, for 4 s" % lit, director.mode == DaemonDirector.Mode.REST and lit == 3 and still and life.health() == 100.0 and p.pings_sent == 1)
	await _drop(main)


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
	var cid: int = cs.my_id
	var rpcs := _code("res://scripts/net/net_session.gd").count("@rpc(")
	_check("acceptance: the wire: protocol 11 since A5's daemon seeds (10 at C28), no new message (24 RPCs, as C27b left them): a ping is the usual fire intent and the seed message every joiner already draws volleys from", joined and Session.PROTOCOL == 11 and rpcs == 24, "%d RPCs" % rpcs)
	# The host's own player far off behind the lair's walls; the joiner on open floor, ping drawn;
	# the host's rogue near the joiner, the others parked.
	host["player"].global_position = host["main"].to_global(Vector3(15.0, 0.95, -15.0))
	client["player"].global_position = client["main"].to_global(OPEN)
	for name in ["DummyB", "DummyC", "DummyD"]:
		_park(_dummy(host["main"], name))
	client["player"].select_slot(SLOT)
	var drawn := await _wait(func(): return hs.combat.drawn_by(cid) == "ping_sonar", 120)
	await _frames(30)
	var host_rogue: Node3D = _dummy(host["main"], "DummyA")
	var copy: Node3D = _dummy(client["main"], "DummyA")
	_place(host_rogue, host["main"].to_global(Vector3(0.0, 0.0, 12.5)))
	var telling := await _wait(func(): return host_rogue.brain.state == DaemonBrain.State.TELL and host_rogue.brain.prey == cid and host_rogue.brain.state_t > 0.1, 900)
	var attacks: int = host_rogue.brain.attacks
	var health: float = hs.combat.health_of(cid)
	client["player"].drive_input(Vector2.ZERO, false, false, true)
	var staggered := await _wait(func(): return host_rogue.brain.staggers == 1, 30)
	var copy_reel := false
	var no_strike := true
	var rings := [0, 0]
	for i in 40:
		await physics_frame
		copy_reel = copy_reel or (copy.brain.state == DaemonBrain.State.SCATTER and copy.art_node().staggered() > 0.0)
		no_strike = no_strike and host_rogue.brain.attacks == attacks
		rings = [maxi(rings[0], hs.get("_volleys").size()), maxi(rings[1], cs.get("_volleys").size())]
	var copy_reveal := PingReveal.find(copy.art_node())
	var host_reveal := PingReveal.find(host_rogue.art_node())
	_check("acceptance: in a match the host judges the ping: the joiner's ping staggers the host's rogue.d caught mid-tell on the joiner, no strike, no damage (%.0f), and the joiner's copy reels on the host's word" % hs.combat.health_of(cid), joined and drawn >= 0 and telling >= 0 and staggered >= 0 and no_strike and hs.combat.health_of(cid) == health and copy_reel, "telling %d staggered %d" % [telling, staggered])
	_check("acceptance: the reveal shows only on the pinger's screen: the joiner's copy outlined, the host's rogue not (%s on the host)" % ("lit" if host_reveal != null and host_reveal.lit() else "dark"), copy_reveal != null and copy_reveal.lit() and (host_reveal == null or not host_reveal.lit()))
	_check("the ring is drawn on both screens from the host's word (the host's own and the joiner's: %s)" % str(rings), rings[0] >= 1 and rings[1] >= 1)
	# A second ping before the cooldown is the host's to refuse too, whatever the joiner sends.
	var rate_before: int = hs.combat.drops.get("rate", 0)
	cs._on_fire_intent(client["player"].get_node("Head/Camera").global_position, Vector3.FORWARD, "ping_sonar")
	var refused := await _wait(func(): return hs.combat.drops.get("rate", 0) > rate_before, 60)
	_check("acceptance: and holds the cooldown: a joiner's second ping sent at once, past its own strip, is refused by the host (rate)", refused >= 0)
	await _drop_side(client)
	await _drop_side(host)


# --- Helpers. ---

## Draws ping on `p` and waits out the swap and its fiction line; true when it is in hand.
func _draw_ping(p: Node) -> bool:
	p.select_slot(SLOT)
	await _frames(40)
	return p.weapon_tuning().id == "ping_sonar" and p.inventory.fire_block() == ""


## Fires once (fire for one frame, as soon as nothing blocks it) and waits a frame.
func _ping(p: Node) -> void:
	await _wait(func(): return p.inventory.fire_block() == "", 600)
	p.drive_input(Vector2.ZERO, false, false, true)
	await physics_frame


func _lab(keep: Dictionary, player_at: Vector3, practice: bool = false) -> Node:
	GameSettings.current().set_value("gameplay", "practice", practice)
	GameSettings.current().set_value("gameplay", "difficulty", "normal")
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
	player.global_position = player_at
	player.velocity = Vector3.ZERO
	for dummy in main.get_node("Arena/Targets").get_children():
		if keep.has(String(dummy.name)):
			_place(dummy, keep[String(dummy.name)])
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
