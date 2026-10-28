extends SceneTree
## Headless light-trail test for SIGKILL (C20). scripts/check.sh runs it, and any FAIL exits 1.
##
##   godot --headless --path . --fixed-fps 60 --script res://tests/light_trail_test.gd
##
## Light-trail mode (PRD 5.2: "your path leaves a solid neon wall, Tron deathmatch"): its
## resource and its numbers, bad values refused; the walls' own rules on one LightTrails node
## (a segment every 0.5 m of ground travel, none in the air and none across a jump, the cap
## per player, the lifetime, the grace on a player's own newest walls, a wall's height); the
## setting off by default, the Esc menu's row and --light-trails; a scan that only the host
## lays and judges walls and that the wall code runs nothing real. Then a host and a joiner
## over ENet on 127.0.0.1 in this one process: off by default nothing is laid; turned on by
## the host's setting the joiner gets the host's word; the host's walk lays a wall every
## 0.5 m and the joiner's screen holds the very same segments; standing on its own newest
## wall the host lives; the joiner walking into the host's wall is derezzed, the kill the
## host's on both screens and the joiner's own walls gone; the host walking back into its own
## older wall kills itself, no kill counted; a respawn starts with no walls; a running jump
## lays nothing in the air and nothing across it; the walls expire on their lifetime on both
## screens; turning the rule off takes every wall away; a joiner arriving while walls stand
## gets every one from the host, each with its age; leaving the match takes them all away; no
## orphan nodes.
## Deterministic: no random numbers are drawn, every walk is a fixed number of physics frames
## at most, and nothing waits a frame count for the network. Nothing outside this process is
## touched.

const Session = preload("res://scripts/net/net_session.gd")
const NetTuningScript = preload("res://scripts/net/net_tuning.gd")
const CombatTuningScript = preload("res://scripts/net/combat_tuning.gd")
const LightTrails = preload("res://scripts/modes/light_trails.gd")
const TrailTuningScript = preload("res://scripts/modes/light_trail_tuning.gd")
const RoomCode = preload("res://scripts/net/room_code.gd")
const RelayWire = preload("res://scripts/net/relay_wire.gd")
const Palette = preload("res://scripts/palette.gd")
const Link = preload("res://scripts/guide/guide_link.gd")
const MainScene = preload("res://scenes/main.tscn")
const TUNING_PATH := "res://resources/light_trail.tres"
const WATCHDOG_MS := 10000
const CLIENT_OFFSET := Vector3(1000.0, 0.0, 0.0)
const STAND_Y := 0.95
## The body's middle above its feet (RemotePlayer.FEET); the floor's top is at y 0.
const FEET := 0.9
## Clear ground along z 15 to 19.5 across the arena (the platform ends at z 14).
const LINE_Z := 15.0
const JOINER_Z := 18.5
const JUMP_Z := 17.5
const EAST := Vector3(1.0, 0.0, 0.0)
const WEST := Vector3(-1.0, 0.0, 0.0)
const NORTH := Vector3(0.0, 0.0, -1.0)
## One physics frame of walking at 7 m/s, and the most a segment can run at that speed: it is
## laid at the first look 0.5 m or more past the last, at most a frame's walk past it.
const STEP := 7.0 / 60.0
const SEGMENT_MOST := 0.5 + STEP + 0.01

var _fails := 0
var _checks := 0
var _tmp := ""
var _t: Resource
var _arenas: Array = []
var _branches: Array = []


func _initialize() -> void:
	_run()


func _run() -> void:
	await process_frame
	root.size = Vector2i(1280, 720)
	_tmp = OS.get_temp_dir().path_join("sigkill-light-trail-test-%d" % OS.get_process_id())
	DirAccess.make_dir_recursive_absolute(_tmp)
	_t = load(TUNING_PATH)
	_tuning_checks()
	_setting_checks()
	_source_checks()
	await _wall_rule_checks()
	await _match_checks()
	await _cleanup()
	for name in DirAccess.get_files_at(_tmp):
		DirAccess.remove_absolute(_tmp.path_join(name))
	DirAccess.remove_absolute(_tmp)
	print("LIGHT TRAIL: %d checks" % _checks)
	print("LIGHT TRAIL RESULT: ", "ALL PASS" if _fails == 0 else "%d FAILED" % _fails)
	quit(0 if _fails == 0 else 1)


func _check(label: String, ok: bool, detail: String = "") -> void:
	_checks += 1
	print("PASS " if ok else "FAIL ", label, ("   " + detail) if detail != "" else "")
	if not ok:
		_fails += 1


# --- The resource, the setting, the source. ---

func _tuning_checks() -> void:
	var t = _t
	_check("every number is one resource, resources/light_trail.tres, a LightTrailTuning that passes its own checks", t is TrailTuningScript and t.problems().is_empty(), str(t.problems()) if t is TrailTuningScript else "")
	_check("its numbers: a segment every 0.5 m, 1.2 m tall and 0.08 m thick, standing 6 s (the last 0.75 s fading), 64 a player, 0.4 s of grace on your own, on the ground within 0.15 m, a new wall past a 2.5 m gap", t.spacing_m == 0.5 and t.height_m == 1.2 and t.thickness_m == 0.08 and t.lifetime_s == 6.0 and t.fade_s == 0.75 and t.cap == 64 and t.grace_s == 0.4 and t.ground_slack_m == 0.15 and t.segment_last_m == 2.5)
	var cases := [
		["spacing_m", 0.0, "spacing_m"], ["spacing_m", NAN, "spacing_m"], ["segment_last_m", 0.2, "segment_last_m"], ["height_m", -1.0, "height_m"],
		["thickness_m", 0.0, "thickness_m"], ["lifetime_s", 0.1, "lifetime_s"], ["fade_s", 7.0, "fade_s"], ["cap", 0, "cap"],
		["cap", 1000, "cap"], ["grace_s", INF, "grace_s"], ["ground_slack_m", -0.1, "ground_slack_m"], ["energy", 0.0, "energy"],
	]
	var missed := PackedStringArray()
	for c in cases:
		var bad = _t.duplicate()
		bad.set(c[0], c[1])
		if not ", ".join(bad.problems()).contains(c[2]):
			missed.append("%s=%s: %s" % [c[0], c[1], bad.problems()])
	_check("bad values are refused with the reason: spacing, the gap, height, thickness, lifetime, a fade past it, the cap both ways, grace, the slack, the glow", missed.is_empty(), " | ".join(missed))
	var session = Session.new()
	var bad_tuning = _t.duplicate()
	bad_tuning.cap = 0
	session.light_trail_tuning = bad_tuning
	var used = session.trail_tuning_in_use()
	_check("a session given bad numbers plays by the shipped ones", used != bad_tuning and used.cap == 64)
	session.free()


func _setting_checks() -> void:
	var fresh := GameSettings.new()
	var schema: Array = GameSettings.SCHEMA["multiplayer"].get("light_trails", [])
	_check("off by default: the setting multiplayer/light_trails is a yes or no that starts at no", schema.size() >= 2 and schema[0] == TYPE_BOOL and schema[1] == false and fresh.value("multiplayer", "light_trails") == false)
	var menu := _code("res://scripts/hud/pause_menu.gd")
	_check("the Esc menu's Multiplayer column holds it: a \"light trails\" check, with the note that it is the host's rule", _body(menu, "_build_multiplayer").contains('_check(col, "light trails", "multiplayer", "light_trails")') and _body(menu, "_build_multiplayer").contains("TRAILS_NOTE"))
	var flagged = Session.new()
	flagged.take_launch_flags(PackedStringArray(["--light-trails"]))
	var plain = Session.new()
	plain.take_launch_flags(PackedStringArray(["--demo"]))
	_check("--light-trails on the command line turns it on for this run's hosting, and nothing else does; it is never taken for a join", flagged.light_trails_flag and not plain.light_trails_flag and RoomCode.parse_args(PackedStringArray(["--light-trails"])).is_empty() and _code("res://scripts/main.gd").contains("session.take_launch_flags(launch_args)"))
	_check("solo there is no light-trail mode, whatever the flag says: only a host or a joiner plays by it", not flagged.light_trails_on() and not plain.light_trails_on())
	flagged.free()
	plain.free()


func _source_checks() -> void:
	var walls := _code("res://scripts/modes/light_trails.gd") + _code("res://scripts/modes/light_trail_tuning.gd")
	var real := PackedStringArray()
	for word in ["OS.", "FileAccess", "DirAccess", "create_process", "execute", "Thread", "HTTP", "PacketPeer", "StreamPeer"]:
		if walls.contains(word):
			real.append(word)
	_check("the walls are game fiction: their code runs, reads, opens and signals nothing real", real.is_empty(), ", ".join(real))
	var session := _code("res://scripts/net/net_session.gd")
	var tick := _body(session, "_tick_trails")
	var host_only := tick.find("if state != State.HOSTING or combat == null:\n\t\treturn")
	_check("only the host lays and judges walls: in _tick_trails both come after its hosting check, nowhere else; a joiner's _trail only adds the host's segment", host_only > 0 and tick.find("trails.advance(") > host_only and tick.find("trails.touching(") > host_only and session.count("trails.advance(") == 1 and session.count("trails.touching(") == 1 and _body(session, "_trail").contains("trails.add(id, a, b, age)") and not _body(session, "_trail").contains("damage_player"))
	_check("the wire: protocol 6 (7 since C22's sudo, 8 since C23's top table, 9 since C25's grep marks), the rule and the segments authority RPCs from the host; a trail death is the usual death message with the cause \"light_trail\"; the relay's own protocol is untouched (wire 2)", Session.PROTOCOL == 9 and session.contains('@rpc("authority", "call_remote", "reliable")\nfunc _rules(light_trails: bool) -> void:') and session.contains('@rpc("authority", "call_remote", "reliable")\nfunc _trail(id: int, life: int, a: Vector3, b: Vector3, age: float) -> void:') and _body(session, "_death").contains("weapon == LIGHT_TRAIL") and tick.contains("_broadcast_death(id, wall_owner, push, LIGHT_TRAIL)") and RelayWire.WIRE == 2)


# --- The walls' own rules, on one node. ---

func _wall_rule_checks() -> void:
	var holder := Node3D.new()
	root.add_child(holder)
	var trails = LightTrails.of(holder, _t)
	_check("one LightTrails node an arena, made on first use and found again", LightTrails.of(holder, _t) == trails and LightTrails.find(holder) == trails and trails.is_in_group(LightTrails.GROUP))
	# Walking east on the ground at 7 m/s: a look every physics frame, 59 frames, 6.9 m.
	var step := STEP
	var laid := 0
	for i in 60:
		if not trails.advance(1, Vector3(step * i, 0.0, 0.0), true).is_empty():
			laid += 1
	var segs: Array = trails.segments_of(1)
	var lengths := segs.map(func(s): return Vector2(s[1].x - s[0].x, s[1].z - s[0].z).length())
	var joined := true
	for i in range(1, segs.size()):
		joined = joined and segs[i][0] == segs[i - 1][1]
	_check("on the ground a segment is laid every 0.5 m or so: 6.9 m walked at 0.117 m a frame lays 11, each from where the last ended, at the first look past 0.5 m (0.583 m)", laid == 11 and segs.size() == 11 and joined and lengths.all(func(l): return l >= 0.5 and l <= SEGMENT_MOST), "%d laid, lengths %s" % [laid, lengths])
	var before: int = trails.count_of(1)
	var in_air := 0
	for i in range(60, 90):
		if not trails.advance(1, Vector3(step * i, 0.0, 0.0), false).is_empty():
			in_air += 1
	var first_back: Array = trails.advance(1, Vector3(step * 90, 0.0, 0.0), true)
	var after_land: Array = []
	for i in range(91, 110):
		var one: Array = trails.advance(1, Vector3(step * i, 0.0, 0.0), true)
		if not one.is_empty() and after_land.is_empty():
			after_land = one
	_check("in the air nothing is laid, and no wall spans the jump: the first segment after landing starts where the player landed", in_air == 0 and first_back.is_empty() and trails.count_of(1) > before and not after_land.is_empty() and is_equal_approx(after_land[0].x, step * 90), "%d in the air, first after landing %s" % [in_air, after_land])
	var far: Array = trails.advance(1, Vector3(step * 109 + 3.0, 0.0, 0.0), true)
	_check("a move past the 2.5 m gap (a respawn, a teleport, a late sample) lays nothing across it; the next wall starts there", far.is_empty() and trails.anchor_of(1).is_equal_approx(Vector3(step * 109 + 3.0, 0.0, 0.0)))
	# The cap: player 2 lays 100 segments, player 3 lays 10.
	for i in 101:
		trails.advance(2, Vector3(0.5 * i, 0.0, 30.0), true)
	for i in 11:
		trails.advance(3, Vector3(0.5 * i, 0.0, 40.0), true)
	var capped: Array = trails.segments_of(2)
	_check("the cap holds per player: 100 laid leave the newest 64, the oldest gone first; another player's 10 are all kept", capped.size() == 64 and is_equal_approx(capped[0][0].x, 0.5 * 36) and is_equal_approx(capped[63][1].x, 50.0) and trails.count_of(3) == 10, "%d kept, first starts at %.1f" % [capped.size(), capped[0][0].x if not capped.is_empty() else -1.0])
	# Grace, and height: a fresh wall of player 3's, touched along its length.
	var on_second := Vector3(3.75, FEET, 40.0)  # the middle of player 3's 8th of 10 segments
	var mine_fresh: int = trails.touching(on_second, 3)
	var theirs_fresh: int = trails.touching(on_second, 4)
	trails.tick(_t.grace_s + 0.05)
	var mine_older: int = trails.touching(on_second, 3)
	var on_newest := Vector3(5.0, FEET, 40.0)  # where the newest ends, 0.5 m past the one before
	var newest_mine: int = trails.touching(on_newest, 3)
	var over_it: int = trails.touching(Vector3(3.75, _t.height_m + FEET + 0.01, 40.0), 4)
	var beside_it: int = trails.touching(Vector3(3.75, FEET, 40.0 + trails.reach() + 0.01), 4)
	var just_in: int = trails.touching(Vector3(3.75, FEET, 40.0 + trails.reach() - 0.01), 4)
	_check("your own grace segments don't touch you, another player's always do: a fresh wall leaves its owner standing and kills anyone else", mine_fresh == -1 and theirs_fresh == 3, "%d %d" % [mine_fresh, theirs_fresh])
	_check("your older trail does: past 0.4 s your own wall touches you, all but your newest segment, which never does (standing where you laid it)", mine_older == 3 and newest_mine == -1, "%d %d" % [mine_older, newest_mine])
	_check("a wall is 1.2 m tall and as thick as it looks: jumping clear over it, or standing a centimetre past its reach, is no touch; a centimetre inside is", over_it == -1 and beside_it == -1 and just_in == 3, "%d %d %d (reach %.2f m)" % [over_it, beside_it, just_in, trails.reach()])
	# The lifetime: player 3's segments were all laid at once and have aged 0.45 s.
	trails.tick(_t.lifetime_s - 0.45 - 0.02)
	var standing: int = trails.count_of(3)
	trails.tick(0.04)
	_check("segments expire after their lifetime: all 10 stand at 5.98 s and are gone at 6.02 s", standing == 10 and trails.count_of(3) == 0, "%d then %d" % [standing, trails.count_of(3)])
	trails.clear(1)
	trails.keep_only([1])
	_check("clearing a player takes all their walls and starts their next afresh; a player who left loses theirs", trails.count_of(1) == 0 and not trails.anchor_of(1).is_finite() and not trails.get("_owners").has(2) and not trails.get("_owners").has(3) and trails.total() == 0)
	LightTrails.drop(holder)
	await _frames(2)
	_check("dropping an arena's walls takes the node away at once and frees it", LightTrails.find(holder) == null and get_nodes_in_group(LightTrails.GROUP).is_empty())
	holder.free()


# --- A match. ---

func _match_checks() -> void:
	var orphans := int(Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT))
	var host := _branch("Host", Vector3.ZERO)
	var client := _branch("Client", CLIENT_OFFSET)
	var joined := await _join(host, client)
	var hs: Session = host["session"]
	var cs: Session = client["session"]
	var hp: Node = host["player"]
	var cp: Node = client["player"]
	var hm: Node = host["main"]
	var cm: Node = client["main"]
	var cid: int = cs.my_id
	await _until(func(): return hs.avatars.has(cid) and cs.avatars.has(1) and hs.combat.has_player(cid) and cs.get("_weapons_synced"), 6000)
	await _until(func(): return hs.protect_left.get(1, 0.0) <= 0.0 and hs.protect_left.get(cid, 0.0) <= 0.0, 6000)
	var deaths := []
	var host_hud = host["hud"].combat_hud()
	var client_hud = client["hud"].combat_hud()
	hs.player_died.connect(func(victim, killer): deaths.append(["host", victim, killer, host_hud.feed_text().duplicate()]))
	cs.player_died.connect(func(victim, killer): deaths.append(["joiner", victim, killer, client_hud.feed_text().duplicate()]))
	# Off by default: both walk, nothing is laid.
	_place(host, Vector3(-12.0, STAND_Y, LINE_Z), EAST)
	_place(client, Vector3(-16.0, STAND_Y, JOINER_Z), EAST)
	await _frames(10)
	await _walk_both(hp, cp, 90)
	await _frames(10)
	_check("a host and a joiner over ENet on 127.0.0.1, protocol 9, and light-trail mode off by default: both walk 3 m and more, and no wall is laid on either screen", joined and Session.PROTOCOL == 9 and not hs.light_trails_on() and not cs.light_trails_on() and LightTrails.find(hm) == null and LightTrails.find(cm) == null)
	# The host turns it on in its settings; the joiner plays by the host's word.
	GameSettings.current().set_value("multiplayer", "light_trails", true)
	var told := await _until(func(): return cs.light_trails_on(), 4000)
	_check("the host's setting is the match's: turned on there, the joiner gets the host's word (a joiner's own setting never counts)", hs.light_trails_on() and told)
	# The host walks east 5 m along z 15.
	_place(host, Vector3(-12.0, STAND_Y, LINE_Z), EAST)
	await _frames(20)
	var start: Vector3 = hm.to_local(hp.global_position)
	await _walk(hp, func(): return hm.to_local(hp.global_position).x >= start.x + 5.0, 120)
	await _stop(hp)
	var host_trails = LightTrails.find(hm)
	var host_segs: Array = host_trails.segments_of(1) if host_trails != null else []
	var lengths := host_segs.map(func(s): return Vector2(s[1].x - s[0].x, s[1].z - s[0].z).length())
	var on_line := host_segs.all(func(s): return absf(s[0].z - LINE_Z) < 0.05 and absf(s[1].z - LINE_Z) < 0.05 and absf(s[0].y) < 0.05 and absf(s[1].y) < 0.05)
	var walked: float = hm.to_local(hp.global_position).x - start.x
	var laid_m: float = 0.0
	for l in lengths:
		laid_m += l
	var chained := true
	for i in range(1, host_segs.size()):
		chained = chained and host_segs[i][0] == host_segs[i - 1][1]
	_check("acceptance: on, the host's 5 m walk lays a segment roughly every 0.5 m: 8 to 10 of them end to end, each from 0.5 m to a frame's walk more, covering all but the last part-segment of the walk, along the line walked and on the floor", host_segs.size() >= 8 and host_segs.size() <= 10 and lengths.all(func(l): return l >= 0.5 and l <= SEGMENT_MOST) and chained and laid_m >= walked - SEGMENT_MOST and on_line, "%d segments over %.2f of %.2f m, lengths %s" % [host_segs.size(), laid_m, walked, lengths])
	var agree := await _until(func(): return _same_walls(hm, cm, 1), 4000)
	var client_trails = LightTrails.find(cm)
	_check("acceptance: the host and the joiner agree on the walls: the joiner's screen holds the very same segments, end to end, in the host's player's colour on both", agree and host_trails.get("_owners")[1]["color"] == Palette.trail_color(1) and client_trails != null and client_trails.get("_owners")[1]["color"] == Palette.trail_color(1), "host %d, joiner %d" % [host_segs.size(), client_trails.count_of(1) if client_trails != null else -1])
	# Standing on its own newest wall: the host lives.
	await _settle([hp, cp], 1.0)
	_check("acceptance: your own grace segments don't kill you: the host stood a second where its wall ends, its newest segment under its feet, and lives", not hs.dead.get(1, false) and host_trails.count_of(1) == host_segs.size())
	# The joiner walks north into the host's wall.
	var kills_before: int = hs.combat.states[1]["kills"]
	var cdeaths_before: int = hs.combat.states[cid]["deaths"]
	_place(client, Vector3(-9.5, STAND_Y, LINE_Z + 3.0), NORTH)
	await _until(_heard.bind(hs, cid, client), 4000)
	var joiner_most := 0
	var down := false
	for i in 120:
		joiner_most = maxi(joiner_most, host_trails.count_of(cid))
		down = hs.dead.get(cid, false) and cs.dead.get(cid, false)
		if down:
			break
		cp.drive_input(Vector2(0.0, -1.0))
		await physics_frame
	cp.drive_input(Vector2.ZERO)
	await _frames(4)
	var cdeath: Array = deaths.filter(func(d): return d[1] == cid)
	var feed_ok: bool = cdeath.size() == 2 and cdeath.all(func(d): return d[2] == 1 and not d[3].is_empty() and d[3][0] == "light trail sent by Daemon-1 to Daemon-2")
	_check("acceptance: the joiner walking into the host's wall is derezzed, the kill credited to the wall's owner: the host's kills and the joiner's deaths each up by one, \"light trail sent by Daemon-1 to Daemon-2\" in the feed on both screens", down and feed_ok and hs.combat.states[1]["kills"] == kills_before + 1 and hs.combat.states[cid]["deaths"] == cdeaths_before + 1, "%s | %s" % [deaths.map(func(d): return d.slice(0, 3)), cdeath.map(func(d): return d[3])])
	var joiner_left_host: int = host_trails.count_of(cid)
	var joiner_left_client: int = client_trails.count_of(cid)
	_check("acceptance: a death clears that player's trail: the joiner's own walls (%d laid on its way in) are gone on both screens, and the host's wall still stands" % joiner_most, joiner_most >= 2 and joiner_left_host == 0 and joiner_left_client == 0 and host_trails.count_of(1) == host_segs.size() and client_trails.count_of(1) == host_segs.size(), "joiner's walls left: host %d, joiner %d" % [joiner_left_host, joiner_left_client])
	# The host walks back west into its own older wall.
	var host_kills: int = hs.combat.states[1]["kills"]
	var host_deaths: int = hs.combat.states[1]["deaths"]
	_face(hp, WEST)
	var self_down := await _walk(hp, func(): return hs.dead.get(1, false) and cs.dead.get(1, false), 120)
	await _frames(4)
	var hdeath: Array = deaths.filter(func(d): return d[1] == 1)
	_check("acceptance: your older trail does kill you: the host walking back into its own wall is derezzed, a self-kill (no kill counted, one death), \"light trail sent by Daemon-1 to Daemon-1\" on both screens", self_down and hdeath.size() == 2 and hdeath.all(func(d): return d[2] == 1 and not d[3].is_empty() and d[3][0] == "light trail sent by Daemon-1 to Daemon-1") and hs.combat.states[1]["kills"] == host_kills and hs.combat.states[1]["deaths"] == host_deaths + 1, "%s" % [hdeath.map(func(d): return d.slice(0, 3))])
	_check("and its walls go with it, on both screens", host_trails.count_of(1) == 0 and client_trails.count_of(1) == 0)
	# Both come back.
	var back := await _until(func(): return not hs.dead.get(1, false) and not hs.dead.get(cid, false) and not cs.dead.get(1, false) and not cs.dead.get(cid, false), 6000)
	await _frames(2)
	_check("acceptance: a respawn starts with no walls: both back, neither has a segment on either screen", back and host_trails.count_of(1) == 0 and host_trails.count_of(cid) == 0 and client_trails.count_of(1) == 0 and client_trails.count_of(cid) == 0)
	# A running jump: nothing in the air, nothing across it.
	_place(client, Vector3(-16.0, STAND_Y, JOINER_Z), EAST)
	_place(host, Vector3(2.0, STAND_Y, JUMP_Z), EAST)
	await _frames(20)
	await _until(_heard.bind(hs, cid, client), 4000)
	var runup: Vector3 = hm.to_local(hp.global_position)
	await _walk(hp, func(): return hm.to_local(hp.global_position).x >= runup.x + 1.5, 60)
	var marks := []  # [feet height, segments, x] after each frame of the jump
	for i in 90:
		var here: Vector3 = hm.to_local(hp.global_position)
		marks.append([here.y - FEET, host_trails.count_of(1), here.x])
		if i > 3 and hp.is_on_floor() and here.y - FEET < 0.01:
			break
		hp.drive_input(Vector2(0.0, -1.0), i == 0)
		await physics_frame
	var landed_x: float = hm.to_local(hp.global_position).x
	await _walk(hp, func(): return hm.to_local(hp.global_position).x >= landed_x + 1.5, 60)
	await _stop(hp)
	var laid_in_air := 0
	var air_from := INF
	var air_to := -INF
	for i in range(1, marks.size()):
		if marks[i - 1][0] > 0.25 and marks[i][0] > 0.25:
			laid_in_air += marks[i][1] - marks[i - 1][1]
			air_from = minf(air_from, marks[i - 1][2])
			air_to = maxf(air_to, marks[i][2])
	var jump_segs: Array = host_trails.segments_of(1)
	var spans := jump_segs.filter(func(s): return Vector2(s[1].x - s[0].x, s[1].z - s[0].z).length() > SEGMENT_MOST)
	var after := jump_segs.filter(func(s): return s[0].x >= air_to - 0.01)
	_check("acceptance: none while airborne: a running jump carries the host %.1f m with its feet over 0.25 m up and lays nothing there, no segment spans the jump, and laying starts again after it lands" % (air_to - air_from), laid_in_air == 0 and air_to - air_from >= 3.0 and spans.is_empty() and not after.is_empty() and jump_segs.size() >= 4, "laid in the air %d, airborne %.2f m, %d segments, %d after landing" % [laid_in_air, air_to - air_from, jump_segs.size(), after.size()])
	var agree_jump := await _until(func(): return _same_walls(hm, cm, 1), 4000)
	_check("and the joiner's screen holds the same jump-broken wall", agree_jump)
	# The lifetime, on both screens: stand still, and count frames until the oldest and the
	# newest segment go, against the ages they had when the standing began.
	var walls: Array = host_trails.get("_owners")[1]["segments"]
	var last := walls.size()
	var oldest_left: float = _t.lifetime_s - walls[0]["age"] if last > 0 else -1.0
	var newest_left: float = _t.lifetime_s - walls[last - 1]["age"] if last > 0 else -1.0
	var first_drop := -1
	var host_gone := -1
	var client_gone := -1
	for frame in int(_t.lifetime_s * 60.0) + 60:
		hp.drive_input(Vector2.ZERO)
		cp.drive_input(Vector2.ZERO)
		await physics_frame
		if first_drop < 0 and host_trails.count_of(1) < last:
			first_drop = frame + 1
		if host_gone < 0 and host_trails.count_of(1) == 0:
			host_gone = frame + 1
		if client_gone < 0 and client_trails.count_of(1) == 0:
			client_gone = frame + 1
		if host_gone >= 0 and client_gone >= 0:
			break
	var oldest_due := ceili(oldest_left * 60.0 - 0.001)
	var newest_due := ceili(newest_left * 60.0 - 0.001)
	_check("acceptance: segments expire after their lifetime, not before: of the host's %d, the oldest goes at frame %d of standing (due %d) and the newest at %d (due %d), 6 s after each was laid; the joiner's copy a few frames later on its own clock (%d)" % [last, first_drop, oldest_due, host_gone, newest_due, client_gone], last >= 4 and absi(first_drop - oldest_due) <= 1 and absi(host_gone - newest_due) <= 1 and client_gone >= host_gone and client_gone <= host_gone + 10, "first drop %d, gone %d, joiner %d" % [first_drop, host_gone, client_gone])
	# The rule off mid-match, then on again, then leaving.
	await _walk(hp, func(): return host_trails.count_of(1) >= 3, 60)
	await _until(func(): return client_trails.count_of(1) >= 3, 4000)
	GameSettings.current().set_value("multiplayer", "light_trails", false)
	var off := await _until(func(): return not cs.light_trails_on() and LightTrails.find(hm) == null and LightTrails.find(cm) == null, 4000)
	await _walk(hp, func(): return false, 30)
	_check("turned off mid-match, every wall goes at once on both screens and walking lays no more", off and LightTrails.find(hm) == null and LightTrails.find(cm) == null and not hs.light_trails_on())
	hs.light_trails_flag = true
	var again := await _until(func(): return cs.light_trails_on(), 4000)
	await _walk(hp, func(): return LightTrails.find(hm) != null and LightTrails.find(hm).count_of(1) >= 2, 60)
	await _until(func(): return LightTrails.find(cm) != null and LightTrails.find(cm).count_of(1) >= 2, 4000)
	# A joiner arriving while walls stand: the joiner leaves and comes back.
	await _stop(hp)
	cs.leave()
	await _frames(5)
	cs.join("127.0.0.1:%d" % hs.listen_port())
	var rejoined := await _until(func(): return cs.state == Session.State.JOINED and hs.players.size() == 2 and cs.players.size() == 2, 6000)
	var caught := await _until(func(): return _same_walls(hm, cm, 1), 4000)
	var host_walls: Array = LightTrails.find(hm).walls_of(1) if LightTrails.find(hm) != null else []
	var their_walls: Array = LightTrails.find(cm).walls_of(1) if LightTrails.find(cm) != null else []
	var ages_close := host_walls.size() == their_walls.size() and not host_walls.is_empty()
	for i in mini(host_walls.size(), their_walls.size()):
		ages_close = ages_close and absf(host_walls[i][2] - their_walls[i][2]) <= 0.1
	_check("a joiner arriving while walls stand gets every one of them from the host, each with its age, so they end on its screen when they end on the host's (%d walls, ages %s here, %s there)" % [host_walls.size(), host_walls.map(func(w): return snappedf(w[2], 0.01)), their_walls.map(func(w): return snappedf(w[2], 0.01))], rejoined and caught and ages_close and cs.light_trails_on())
	var had: int = LightTrails.find(cm).count_of(1) if LightTrails.find(cm) != null else 0
	hs.leave()
	var gone := await _until(func(): return cs.state != Session.State.JOINED, 6000)
	await _frames(3)
	_check("--light-trails turns it on mid-match too; then leaving the match frees every wall: the host's and the joiner's arenas (%d segments on the joiner's) hold none, no wall node is left" % had, again and gone and had >= 2 and LightTrails.find(hm) == null and LightTrails.find(cm) == null and get_nodes_in_group(LightTrails.GROUP).is_empty())
	GameSettings.current().set_value("multiplayer", "light_trails", false)
	_drop(host)
	_drop(client)
	await _frames(4)
	var orphans_after := int(Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT))
	_check("acceptance: no orphan nodes are left behind by any of it", orphans_after <= orphans, "%d before, %d after" % [orphans, orphans_after])


## True when `cm`'s walls of player `id` are `hm`'s, segment for segment, end for end.
func _same_walls(hm: Node, cm: Node, id: int) -> bool:
	var a = LightTrails.find(hm)
	var b = LightTrails.find(cm)
	if a == null or b == null:
		return false
	var mine: Array = a.segments_of(id)
	var theirs: Array = b.segments_of(id)
	if mine.size() != theirs.size() or mine.is_empty():
		return false
	for i in mine.size():
		if mine[i][0].distance_to(theirs[i][0]) > 0.0001 or mine[i][1].distance_to(theirs[i][1]) > 0.0001:
			return false
	return true


## True once the host has heard the joiner's newest place and look.
func _heard(hs: Session, cid: int, client: Dictionary) -> bool:
	var avatar = hs.avatars.get(cid)
	var cp: Node = client["player"]
	if avatar == null or not is_instance_valid(avatar) or not avatar.visible:
		return false
	var here: Vector3 = client["main"].to_local(cp.global_position)
	return avatar.latest_position().distance_to(here) < 0.05


## Puts `side`'s player at `at` (arena space), facing `facing` along the ground.
func _place(side: Dictionary, at: Vector3, facing: Vector3) -> void:
	var p: Node = side["player"]
	p.respawn_at(side["main"].to_global(at))
	_face(p, facing)


func _face(p: Node, facing: Vector3) -> void:
	p.rotation.y = atan2(-facing.x, -facing.z)
	p.get_node("Head").rotation.x = 0.0


## Walks `p` forward until `done` is true or `frames` pass, jumping on the first frame when
## `jump`; then stops it. True when done.
func _walk(p: Node, done: Callable, frames: int, jump: bool = false) -> bool:
	for i in frames:
		if done.call():
			p.drive_input(Vector2.ZERO)
			return true
		p.drive_input(Vector2(0.0, -1.0), jump and i == 0)
		await physics_frame
	p.drive_input(Vector2.ZERO)
	return done.call()


## Holds `p` still until it has stopped sliding (friction), so it lays nothing more; then a
## frame for the host to see it.
func _stop(p: Node) -> void:
	for i in 120:
		p.drive_input(Vector2.ZERO)
		if Vector2(p.velocity.x, p.velocity.z).length() < 0.001:
			break
		await physics_frame
	p.drive_input(Vector2.ZERO)
	await physics_frame


func _walk_both(a: Node, b: Node, frames: int) -> void:
	for i in frames:
		a.drive_input(Vector2(0.0, -1.0))
		b.drive_input(Vector2(0.0, -1.0))
		await physics_frame
	a.drive_input(Vector2.ZERO)
	b.drive_input(Vector2.ZERO)


func _settle(players: Array, seconds: float) -> void:
	for i in ceili(seconds * 60.0):
		for p in players:
			p.drive_input(Vector2.ZERO)
		await physics_frame


# --- Helpers. ---

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
	GameSettings.current().set_value("multiplayer", "light_trails", false)
	await process_frame
	OS.delay_msec(300)
	await process_frame
