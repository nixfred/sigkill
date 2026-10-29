extends SceneTree
## Headless spectate-as-top test for SIGKILL (C23). scripts/check.sh runs it, and any FAIL
## exits 1.
##
##   godot --headless --path . --fixed-fps 60 --script res://tests/spectate_top_test.gd
##
## Spectate as top (PRD 5.3): the resource and its numbers, bad values refused; the record's
## rules on their own (join order, damage dealt, kills and deaths, time alive, the load
## windows); top's columns and order; Tab as a rebindable action, saved and loaded, Ctrl+Alt
## refused; scans that the new code reads, runs and names nothing real (no process id, no
## /proc, no command) and that the table message is the host's alone. Then alone in the real
## arena: hidden until Tab is held, then the player and the four dummies as daemons, a dummy
## Z while it derezzes, the player's kill, damage share and load, T under SIGSTOP, root after
## a sudo, one refresh a second, gone when Tab is let go and while the round's summary is up.
## Then a host and a joiner over ENet on 127.0.0.1: a protocol 7 joiner refused; a joiner
## with no word from the host yet shows "-" and never a guess; the host's word once a second;
## the table up the moment a player is derezzed and gone the moment it respawns, on the host's
## screen and the joiner's; every number the host's (PIDs by join order, kills, deaths, the
## damage share, health); root and T where this game knows them; sorted by K, then %CPU. Then
## the layout at 960x540 and 1280x720: inside the screen, under the top lines, the death
## banner below it, nothing covered, and never up with the round's summary. No orphan nodes.
## Deterministic: no random numbers drawn for what is checked, every time counted in physics
## frames, nothing waits a frame count for the network.

const Session = preload("res://scripts/net/net_session.gd")
const NetTuningScript = preload("res://scripts/net/net_tuning.gd")
const CombatTuningScript = preload("res://scripts/net/combat_tuning.gd")
const TopTuningScript = preload("res://scripts/hud/spectate_top_tuning.gd")
const TopLedger = preload("res://scripts/hud/top_ledger.gd")
const SpectateTop = preload("res://scripts/hud/spectate_top.gd")
const AnnouncerTuning = preload("res://scripts/round/announcer_tuning.gd")
const Controls = preload("res://scripts/controls.gd")
const Palette = preload("res://scripts/palette.gd")
const Link = preload("res://scripts/guide/guide_link.gd")
const MainScene = preload("res://scenes/main.tscn")
const TUNING_PATH := "res://resources/spectate_top.tres"
const WATCHDOG_MS := 10000
const CLIENT_OFFSET := Vector3(1000.0, 0.0, 0.0)
const OLD_OFFSET := Vector3(2000.0, 0.0, 0.0)
const STAND_Y := 0.95
const LINE_Z := 15.0
const EPS := 0.0001

var _fails := 0
var _checks := 0
var _tmp := ""
var _t: Resource
var _arenas: Array = []
var _branches: Array = []


func _initialize() -> void:
	GameSettings.current().set_value("gameplay", "practice", true)  # these checks predate C27b: the daemons stay the old never-attack dummies
	_run()


func _run() -> void:
	await process_frame
	root.size = Vector2i(1280, 720)
	_tmp = OS.get_temp_dir().path_join("sigkill-spectate-top-test-%d" % OS.get_process_id())
	DirAccess.make_dir_recursive_absolute(_tmp)
	Controls.ensure()
	_t = load(TUNING_PATH)
	_tuning_checks()
	_ledger_checks()
	_format_checks()
	_rebind_checks()
	_source_checks()
	await _solo_checks()
	await _match_checks()
	await _layout_checks()
	await _cleanup()
	for name in DirAccess.get_files_at(_tmp):
		DirAccess.remove_absolute(_tmp.path_join(name))
	DirAccess.remove_absolute(_tmp)
	print("SPECTATE TOP: %d checks" % _checks)
	print("SPECTATE TOP RESULT: ", "ALL PASS" if _fails == 0 else "%d FAILED" % _fails)
	quit(0 if _fails == 0 else 1)


func _check(label: String, ok: bool, detail: String = "") -> void:
	_checks += 1
	print("PASS " if ok else "FAIL ", label, ("   " + detail) if detail != "" else "")
	if not ok:
		_fails += 1


# --- The resource, the record, the columns, the action, the source. ---

func _tuning_checks() -> void:
	var t = _t
	_check("every number is one resource, resources/spectate_top.tres, a SpectateTopTuning that passes its own checks", t is TopTuningScript and t.problems().is_empty(), str(t.problems()) if t is TopTuningScript else "")
	_check("its numbers: a refresh every 1.0 s (the host's message too), load windows of 10, 30 and 60 s of play, 8 rows at most, game PIDs from 100", t.refresh_s == 1.0 and t.windows() == [10.0, 30.0, 60.0] and t.max_rows == 8 and t.pid_base == 100)
	var cases := [
		["refresh_s", 0.5, "refresh_s"], ["refresh_s", NAN, "refresh_s"], ["load_mid_s", 5.0, "load_mid_s"], ["load_long_s", 30.0, "load_long_s"],
		["load_short_s", 0.0, "load_short_s"], ["max_rows", 1, "max_rows"], ["max_rows", 40, "max_rows"], ["pid_base", 0, "pid_base"], ["pid_base", 99999, "pid_base"],
	]
	var missed := PackedStringArray()
	for c in cases:
		var bad = _t.duplicate()
		bad.set(c[0], c[1])
		if not ", ".join(bad.problems()).contains(c[2]):
			missed.append("%s=%s: %s" % [c[0], c[1], bad.problems()])
	_check("bad values are refused with the reason: a refresh faster than once a second or NaN, a load window not longer than the one before or too short, too few or too many rows, a PID base out of range", missed.is_empty(), " | ".join(missed))


func _ledger_checks() -> void:
	var l := TopLedger.new()
	l.join(1)
	l.join(2)
	l.join(1)
	l.join(3)
	var orders := [l.rows[1]["order"], l.rows[2]["order"], l.rows[3]["order"]]
	_check("the record alone: each process joins once, in join order (0, 1, 2; a second join changes nothing)", orders == [0, 1, 2] and l.rows.size() == 3, str(orders))
	l.tick(2.0)
	l.hit(2, 1, 25.0)
	l.hit(1, 1, 10.0)
	l.hit(9, 1, 5.0)
	l.hit(2, 1, NAN)
	l.hit(2, 1, -3.0)
	_check("damage dealt counts the health a known process took off another: 25 for process 2; nothing for hurting itself, an unknown dealer, NaN or a negative amount", l.rows[2]["dealt"] == 25.0 and l.rows[1]["dealt"] == 0.0)
	l.kill(2, 1)
	l.tick(3.0)
	var times := [l.rows[1]["alive_s"], l.rows[2]["alive_s"], l.uptime]
	l.kill(3, 3)
	_check("a kill is the victim's death and the killer's kill; killing yourself is a death and no kill", l.rows[2]["kills"] == 1 and l.rows[1]["deaths"] == 1 and l.rows[3]["deaths"] == 1 and l.rows[3]["kills"] == 0 and l.rows[1]["dead"])
	l.respawn(1)
	_check("time alive this life stops at a death (2.0 s) and starts from 0 at a respawn; the uptime is every second of play (5.0 s)", times == [2.0, 5.0, 5.0] and l.rows[1]["alive_s"] == 0.0 and not l.rows[1]["dead"], str(times))
	var windows := [10.0, 30.0, 60.0]
	var loads := [l.load_counts(windows)]
	l.tick(8.0)
	loads.append(l.load_counts(windows))
	l.tick(20.0)
	loads.append(l.load_counts(windows))
	l.tick(30.0)
	loads.append(l.load_counts(windows))
	_check("load average: the credited kill (at 2 s; the self-kill is none) counts in each window it is inside: 3 s on in all three, 11 s on in 30 and 60, 31 s on in 60 only, 61 s on in none and forgotten", loads == [PackedInt32Array([1, 1, 1]), PackedInt32Array([0, 1, 1]), PackedInt32Array([0, 0, 1]), PackedInt32Array([0, 0, 0])] and l.get("_kills_at").is_empty(), str(loads))
	l.leave(2)
	_check("a process that leaves is gone from the record", not l.rows.has(2) and l.rows.size() == 2)


func _format_checks() -> void:
	var times := [SpectateTop.time_plus(65.25), SpectateTop.time_plus(0.0), SpectateTop.time_plus(0.35), SpectateTop.time_plus(600.0), SpectateTop.time_plus(-1.0)]
	var clocks := [SpectateTop.clock(65.0), SpectateTop.clock(3725.0), SpectateTop.clock(0.4), SpectateTop.clock(-1.0)]
	_check("TIME+ as top prints it, m:ss.hh (1:05.25, 0:00.00, 0:00.35, 10:00.00, \"-\" unknown); uptime m:ss or h:mm:ss", times == ["1:05.25", "0:00.00", "0:00.35", "10:00.00", "-"] and clocks == ["1:05", "1:02:05", "0:00", "-"], "%s %s" % [times, clocks])
	var titles := SpectateTop.titles_text()
	var row := SpectateTop.row_text({"pid": 101, "user": "root", "s": "R", "cpu": 62.5, "res": 75, "time": 65.25, "kills": 3, "deaths": 1, "command": "Daemon-2", "me": false})
	var unknown := SpectateTop.row_text({"pid": -1, "user": "user", "s": "R", "cpu": -1.0, "res": 100, "time": -1.0, "kills": -1, "deaths": -1, "command": "Daemon-1", "me": false})
	_check("top's columns: PID USER S %CPU RES TIME+ K D COMMAND, a row lined up under them, \"-\" for every number not known", titles == "  PID USER     S  %CPU   RES     TIME+   K   D COMMAND" and row == "  101 root     R  62.5    75   1:05.25   3   1 Daemon-2" and unknown == "    - user     R     -   100         -   -   - Daemon-1", "\n%s\n%s\n%s" % [titles, row, unknown])
	var a := _r(102, 2, 10.0, "alpha")
	var b := _r(101, 5, 0.0, "zulu")
	var c := _r(103, 2, 40.0, "bravo")
	var d := _r(100, 2, 40.0, "yankee")
	var rows := [a, b, c, d]
	rows.sort_custom(SpectateTop._before)
	var order := rows.map(func(x): return x["command"])
	_check("sorted like top: the most kills first, then the biggest %CPU, then the lowest PID (zulu, yankee, bravo, alpha; by name it would be alpha first)", order == ["zulu", "yankee", "bravo", "alpha"], str(order))
	var many := []
	for i in 10:
		many.append(_r(100 + i, 10 - i, 0.0, "p%d" % i))
	many[9]["me"] = true
	var picked := SpectateTop.pick(many, 8)
	_check("at most max_rows rows, the viewer's own always among them: tenth by kills, it takes the eighth place", picked.size() == 8 and picked[7]["command"] == "p9" and picked[6]["command"] == "p6")


func _r(pid: int, kills: int, cpu: float, command: String) -> Dictionary:
	return {"pid": pid, "user": "user", "s": "R", "cpu": cpu, "res": 100, "time": 1.0, "kills": kills, "deaths": 0, "command": command, "me": false}


func _rebind_checks() -> void:
	var events := InputMap.action_get_events("show_top")
	_check("Tab is top: a rebindable action shown as \"top\" in the settings' key list, Tab by default, clashing with nothing", Controls.rebindable("show_top") and Controls.default_bind("show_top") == "key:%d" % KEY_TAB and _shown("show_top") == "top" and not Controls.conflicts({}).has("show_top") and events.size() == 1 and (events[0] as InputEventKey).physical_keycode == KEY_TAB)
	var path := _tmp.path_join("rebind-settings.cfg")
	var s := GameSettings.new()
	s.path = path
	var k := InputEventKey.new()
	k.physical_keycode = KEY_K
	var took := s.set_bind("show_top", k)
	var saved := s.save()
	var back := GameSettings.new()
	back.path = path
	var how := back.load_file()
	Controls.apply_binds(back.binds())
	var moved := InputMap.action_get_events("show_top")
	var chord := InputEventKey.new()
	chord.physical_keycode = KEY_TAB
	chord.ctrl_pressed = true
	chord.alt_pressed = true
	var refused := back.set_bind("show_top", chord)
	back.reset_binds()
	Controls.apply_binds(back.binds())
	var reset := InputMap.action_get_events("show_top")
	_check("acceptance: the show_top bind is rebindable and refuses Ctrl+Alt: moved to K it is saved, read back and taken by the input map; Ctrl+Alt+Tab is refused; reset, it is Tab again", took == "" and saved and how == "loaded" and moved.size() == 1 and (moved[0] as InputEventKey).physical_keycode == KEY_K and refused == Controls.CTRL_ALT_REFUSED and reset.size() == 1 and (reset[0] as InputEventKey).physical_keycode == KEY_TAB, "%s %s %s" % [took, how, refused])


func _source_checks() -> void:
	var mine := _code("res://scripts/hud/spectate_top.gd") + _code("res://scripts/hud/top_ledger.gd") + _code("res://scripts/hud/spectate_top_tuning.gd")
	var session := _code("res://scripts/net/net_session.gd")
	var wire := _body(session, "top_numbers") + _body(session, "stopped_known") + _body(session, "_tick_top") + _body(session, "_top")
	var found := PackedStringArray()
	for word in ["OS.", "get_process_id", "/proc", "execute", "create_process", "shell_open", "FileAccess", "DirAccess", "Thread", "HTTP", "PacketPeer", "StreamPeer", "rpc", "\"ps\"", "\"top\""]:
		if mine.contains(word):
			found.append(word)
	for word in ["OS.", "get_process_id", "/proc", "execute", "create_process"]:
		if wire.contains(word):
			found.append("session: " + word)
	_check("acceptance: fiction only: the new code calls no process or OS execution API (no OS call at all: no process id, no /proc, no command, no file) and sends nothing itself; its PIDs, users and commands are game data", found.is_empty() and wire != "", ", ".join(found))
	var hosting := _body(session, "_physics_process")
	var host_at := hosting.find("State.HOSTING:")
	var join_at := hosting.find("State.JOINED:")
	_check("the wire: protocol 8 (9 since C25's grep marks, 10 since C27b's daemons, 11 since A5's daemon seeds, 12 since I1's ICE, 13 since I2's ICEbreakers, 14 since I3's Black ICE, 15 since C29's chmod 000, 16 since C30's pipe |, 17 since C31's /dev/null); one more RPC (20 in all then, 24 since C27b, 26 since I1, 28 since I2 and I3), _top, an authority RPC from the host; sent only from _tick_top, which only the hosting branch runs, to each joiner", Session.PROTOCOL == 17 and session.count("@rpc(") == 28 and session.contains('@rpc("authority", "call_remote", "reliable")\nfunc _top(uptime: float, load: PackedInt32Array, ids: PackedInt32Array, pids: PackedInt32Array, kills: PackedInt32Array, deaths: PackedInt32Array, dealt: PackedFloat32Array, alive: PackedFloat32Array) -> void:') and session.count("_top.rpc_id(") == 1 and _body(session, "_tick_top").contains("_top.rpc_id(") and session.count("_tick_top(delta)") == 1 and hosting.find("_tick_top(delta)") > host_at and hosting.find("_tick_top(delta)") < join_at)
	var shown := _code("res://scripts/hud/spectate_top.gd")
	_check("a client never makes up another player's numbers: in a match every row's health is the session's synced health and every other number the session's top_numbers() (the host's), \"-\" where there is none", _body(shown, "_match_rows").contains("session.health[id]") and _body(shown, "_match_rows").contains("n.get(\"kills\", -1)") and _body(shown, "_refresh").contains("session.top_numbers()") and not _body(shown, "_match_rows").contains("_solo"))


# --- Alone. ---

func _solo_checks() -> void:
	var arena := await _arena()
	var main: Node = arena["main"]
	var p: Node = arena["player"]
	var hud = arena["hud"]
	var top: SpectateTop = hud.spectate_top()
	var orphans := int(Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT))
	var dummies: Array = []
	for name in ["DummyA", "DummyB", "DummyC", "DummyD"]:
		dummies.append(main.get_node("Arena/Targets/" + name))
	await _frames(5)
	_check("alone and alive, nothing shows it until Tab is held: hidden, never refreshed", not top.is_showing() and top.refreshes == 0)
	Input.action_press("show_top")
	await physics_frame
	var lines := top.lines()
	var rows := lines.slice(3)
	var me := _tokens(rows[0]) if rows.size() > 0 else PackedStringArray()
	var daemons := PackedStringArray()
	for i in range(1, rows.size()):
		var t := _tokens(rows[i])
		daemons.append("%s %s %s %s" % [t[0], t[1], t[2], t[8]])
	_check("acceptance: held Tab shows it alone at once: \"top - <round clock> up <uptime>, 1 user, load average: 0.00, 0.00, 0.00\", \"Tasks: 5 total, 5 running, 0 stopped, 0 zombie\", the titles, then the player (PID 100, own row in reverse video) and the dummies as daemons dummy-1 to dummy-4, PIDs 101 to 104", top.is_showing() and lines.size() == 8 and lines[0].begins_with("top - 1:") and lines[0].contains(" up 0:0") and lines[0].ends_with(", 1 user, load average: 0.00, 0.00, 0.00") and lines[1] == "Tasks: 5 total, 5 running, 0 stopped, 0 zombie" and me.size() == 9 and me[0] == "100" and me[1] == "user" and me[2] == "R" and me[4] == "100" and me[8] == "player" and top.own_row() == 0 and top.row_color(0) == Palette.VOID and daemons == PackedStringArray(["101 user R dummy-1", "102 user R dummy-2", "103 user R dummy-3", "104 user R dummy-4"]), "\n" + "\n".join(lines))
	# A daemon derezzed: Z, its death, the player's kill, damage share and load.
	_kill_dummy(dummies[1])
	await _next_refresh(top)
	lines = top.lines()
	var dead := _row(lines, "dummy-2")
	me = _row(lines, "player")
	var cpu_sum := 0.0
	for line in lines.slice(3):
		cpu_sum += float(_tokens(line)[3])
	_check("acceptance: alone a dummy derezzing is Z (RES 0, D 1, in the hostile amber) and \"1 zombie\"; the player's kill (K 1) sorts it first, its %CPU 100.0 of the damage, the dummies' 0.0, summing to 100; the load 1.00 in every window", dead.size() == 9 and dead[2] == "Z" and dead[4] == "0" and dead[7] == "1" and top.row_color(_index(lines, "dummy-2")) == Palette.HOSTILE_AMBER and lines[1] == "Tasks: 5 total, 4 running, 0 stopped, 1 zombie" and _index(lines, "player") == 0 and me[3] == "100.0" and me[6] == "1" and _tokens(lines[4])[3] == "0.0" and absf(cpu_sum - 100.0) < 0.05 and lines[0].ends_with("load average: 1.00, 1.00, 1.00"), "\n" + "\n".join(lines))
	# One refresh a second, the text still in between.
	var r0 := top.refreshes
	var held := top.lines()
	await _frames(30)
	var still := top.lines() == held and top.refreshes == r0
	await _frames(150)
	_check("acceptance: it refreshes once a second like top, not every frame: unchanged half a second on, then 3 refreshes in 180 frames (3 s)", still and top.refreshes - r0 == 3, "%d refreshes" % (top.refreshes - r0))
	# The daemon back: R, its time alive from 0.
	await _until(func(): return dummies[1].is_alive(), 8000)
	await _next_refresh(top)
	var back := _row(top.lines(), "dummy-2")
	var other := _row(top.lines(), "dummy-1")
	_check("a daemon back from derezzing is R again, at full RES, its TIME+ started again from 0 (under a dummy's that never went down by more than its time down)", back.size() == 9 and other.size() == 9 and back[2] == "R" and back[4] == "1" and _secs(back[5]) < 3.0 and _secs(other[5]) - _secs(back[5]) > 1.0, "%s %s" % [back, other])
	# SIGSTOP alone: T.
	var st = p.get("sigstop")
	st.meter.meter = st.meter.full()
	st.press()
	var stopped := await _until(func(): return st.is_on(), 4000)
	await _next_refresh(top)
	me = _row(top.lines(), "player")
	_check("acceptance: alone under SIGSTOP the player's S is T and \"1 stopped\"; it still refreshes in real time while the world is slowed", stopped and me.size() == 9 and me[2] == "T" and top.lines()[1] == "Tasks: 5 total, 4 running, 1 stopped, 0 zombie", str(me))
	st.press()
	await _until(func(): return not st.is_on() and Engine.time_scale == 1.0, 6000)
	# Root after a sudo.
	var sudo = p.get("sudo")
	sudo.state.charges = 1
	sudo.press()
	var rooted := await _until(func(): return sudo.is_root(), 4000)
	await _next_refresh(top)
	me = _row(top.lines(), "player")
	_check("acceptance: after a sudo the player's USER is root (C22's root state; a fixed word), and the S back to R", rooted and me.size() == 9 and me[1] == "root" and me[2] == "R", str(me))
	await _until(func(): return not sudo.is_root(), 12000)
	Input.action_release("show_top")
	await physics_frame
	_check("let go of Tab and it is gone at once", not top.is_showing())
	# The round's summary has the screen: the table stays hidden through the break.
	var short = load("res://resources/announcer.tres").duplicate()
	short.round_seconds = 1.0
	short.intermission_seconds = 2.0
	var round = hud.round_hud()
	round.restart(short)
	Input.action_press("show_top")
	var both := false
	var hidden_frames := 0
	var saw_break := false
	for i in 300:
		await physics_frame
		if round.showing_summary():
			saw_break = true
			if top.is_showing():
				both = true
			else:
				hidden_frames += 1
		elif saw_break:
			break
	await physics_frame
	_check("acceptance: through the round's break the summary has the screen: never on a frame with the table, which comes back when the next round starts", saw_break and not both and hidden_frames > 100 and top.is_showing(), "%d frames hidden" % hidden_frames)
	Input.action_release("show_top")
	round.restart(load("res://resources/announcer.tres"))
	_drop(arena)
	await _frames(3)
	var orphans_after := int(Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT))
	_check("alone: no orphan node left behind", orphans_after <= orphans, "%d before, %d after" % [orphans, orphans_after])


# --- A match. ---

func _match_checks() -> void:
	var orphans := int(Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT))
	var host := _branch("Host", Vector3.ZERO)
	var hs: Session = host["session"]
	hs.host(0)
	await _frames(2)
	var old := _branch("Old", OLD_OFFSET, 7)
	var os: Session = old["session"]
	os.join("127.0.0.1:%d" % hs.listen_port())
	var refused := await _until(func(): return os.state == Session.State.FAILED, 6000)
	_check("acceptance: protocol 8 (9 since C25, 10 since C27b, 11 since A5, 12 since I1, 13 since I2, 14 since I3, 15 since C29, 16 since C30, 17 since C31): a joiner still on protocol 7 is refused with the clear version line", Session.PROTOCOL == 17 and refused and os.error == "version mismatch: host 17, you 7", os.error)
	_drop(old)
	await _frames(2)
	hs.set("_top_left", 1000.0)  # the host's first table held back, to see a joiner without one
	var client := _branch("Client", CLIENT_OFFSET)
	var cs: Session = client["session"]
	cs.join("127.0.0.1:%d" % hs.listen_port())
	var joined := await _until(func(): return cs.state == Session.State.JOINED and hs.players.size() == 2 and cs.players.size() == 2)
	var cid: int = cs.my_id
	await _until(func(): return hs.avatars.has(cid) and cs.avatars.has(1) and hs.combat.has_player(cid) and cs.get("_weapons_synced"), 6000)
	await _until(func(): return hs.protect_left.get(1, 0.0) <= 0.0 and hs.protect_left.get(cid, 0.0) <= 0.0, 6000)
	var htop: SpectateTop = host["hud"].spectate_top()
	var ctop: SpectateTop = client["hud"].spectate_top()
	Input.action_press("show_top")
	await physics_frame
	var cl := ctop.lines()
	var hl := htop.lines()
	var c_host := _row(cl, "Daemon-1")
	var c_me := _row(cl, "Daemon-2")
	_check("acceptance: a joiner the host has sent no table yet never makes a number up: every PID, %CPU, TIME+, K and D shows \"-\", the uptime and load too; health, state and user are what it was synced (RES 100, R, user)", joined and cs.tops_received == 0 and cl.size() == 5 and cl[0].contains(" up -, 2 users, load average: -, -, -") and c_host.size() == 9 and c_me.size() == 9 and c_host[0] == "-" and c_host[3] == "-" and c_host[5] == "-" and c_host[6] == "-" and c_host[7] == "-" and c_host[4] == "100" and c_host[2] == "R" and c_host[1] == "user" and c_me[0] == "-", "\n" + "\n".join(cl))
	_check("the host's own table has every number of its record: PIDs by join order from 100 (the host 100, the joiner 101; the refused joiner never joined)", hl.size() == 5 and _row(hl, "Daemon-1")[0] == "100" and _row(hl, "Daemon-2")[0] == "101" and _row(hl, "Daemon-1")[4] == "100", "\n" + "\n".join(hl))
	Input.action_release("show_top")
	# The host's word, once a second.
	hs.set("_top_left", 0.0)
	await _until(func(): return cs.tops_received == 1, 4000)
	var sent0 := hs.tops_sent
	var got0 := cs.tops_received
	var gaps := []
	var last := 0
	for i in 180:
		await physics_frame
		if cs.tops_received > got0 + gaps.size():
			gaps.append(i - last)
			last = i
	_check("acceptance: the host's table message goes to the joiner once a second, no more: 3 sent and 3 taken in 180 frames (3 s), each at least 59 frames after the last", hs.tops_sent - sent0 == 3 and cs.tops_received - got0 == 3 and gaps.size() == 3 and gaps.slice(1).all(func(g): return g >= 59), "sent %d, taken %d, gaps %s" % [hs.tops_sent - sent0, cs.tops_received - got0, gaps])
	# The joiner kills the host: the host's table up the moment it is derezzed.
	var down := await _joiner_kills_host(host, client, cid)
	var h_up := htop.is_showing()
	var c_up := ctop.is_showing()
	await process_frame
	hl = htop.lines()
	var h_me := _row(hl, "Daemon-1")
	var h_them := _row(hl, "Daemon-2")
	var banner: String = host["combat_hud"].banner_text()
	var below: bool = host["combat_hud"].banner_rect().position.y >= htop.panel_rect().end.y
	_check("acceptance: derezzed in a match, the table is up at once without Tab (the joiner, alive, has none): the killer first by K (1), the host Z with D 1, \"1 zombie\", %CPU 100.0 and 0.0, load 1.00, the host's own row in reverse video; the death banner still shown, below the table", down and h_up and not c_up and h_me.size() == 9 and h_them.size() == 9 and _index(hl, "Daemon-2") == 0 and h_them[6] == "1" and h_me[2] == "Z" and h_me[7] == "1" and h_me[4] == "0" and hl[1] == "Tasks: 2 total, 1 running, 0 stopped, 1 zombie" and h_them[3] == "100.0" and h_me[3] == "0.0" and hl[0].ends_with("2 users, load average: 1.00, 1.00, 1.00") and htop.own_row() == 1 and banner.begins_with("[ DEREZZED by Daemon-2 ]") and below, "\n" + "\n".join(hl))
	await _until(func(): return not hs.dead.get(1, false), 8000)
	_check("acceptance: it goes away the moment the player respawns: hidden on the first frame alive, the banner back in its own place and shape", not htop.is_showing() and host["combat_hud"].banner_text() == "" and host["combat_hud"].get("_banner_top") == -1.0 and is_equal_approx(host["combat_hud"].get("_banner").anchor_top, 0.38) and host["combat_hud"].get("_banner").get_theme_font_size("font_size") == 26, "%s %s %s %s '%s'" % [htop.is_showing(), host["combat_hud"].get("_banner_top"), host["combat_hud"].get("_banner").anchor_top, host["combat_hud"].get("_banner").get_theme_font_size("font_size"), host["combat_hud"].banner_text()])
	# The joiner's view of it, from the host's word.
	Input.action_press("show_top")
	await _until(func(): return hs.protect_left.get(1, 0.0) <= 0.0, 6000)
	_place(host, Vector3(-8.0, STAND_Y, LINE_Z), Vector3(-1.0, 0.0, 0.0))
	_place(client, Vector3(-12.0, STAND_Y, LINE_Z), Vector3(1.0, 0.0, 0.0))
	await _frames(10)
	var cp: Node = client["player"]
	_aim(cp, client["main"].to_global(Vector3(-8.0, 0.9, LINE_Z)))
	await _settle(cp, 0.6)
	await _until(_heard.bind(hs, cid, client), 4000)
	await _fire(cp)
	await _until(func(): return hs.combat.health_of(1) < 100.0, 4000)
	await _fresh(cs, ctop)
	cl = ctop.lines()
	c_host = _row(cl, "Daemon-1")
	c_me = _row(cl, "Daemon-2")
	var rec: Dictionary = hs.combat.record.rows
	_check("acceptance: on the joiner's screen every number is the host's: PIDs 100 and 101, its own K 1, the host's D 1, RES the host's health (%d), the damage dealt shared out (%s and %s, from the host's 26 and 0)" % [ceili(hs.combat.health_of(1)), c_me[3] if c_me.size() == 9 else "?", c_host[3] if c_host.size() == 9 else "?"], c_host.size() == 9 and c_me.size() == 9 and c_host[0] == "100" and c_me[0] == "101" and c_me[6] == "1" and c_host[7] == "1" and int(c_host[4]) == ceili(hs.combat.health_of(1)) and int(c_host[4]) == 75 and absf(rec[cid]["dealt"] - 26.0) < EPS and c_me[3] == "100.0" and c_host[3] == "0.0" and cl[0].contains("load average: 1.00, 1.00, 1.00"), "\n" + "\n".join(cl))
	# The host hits back: the shares split, still sorted by K first.
	_aim(host["player"], host["main"].to_global(Vector3(-12.0, 0.9, LINE_Z)))
	await _settle(host["player"], 0.6)
	await _fire(host["player"])
	await _until(func(): return hs.combat.health_of(cid) < 100.0, 4000)
	await _fresh(cs, ctop)
	cl = ctop.lines()
	c_host = _row(cl, "Daemon-1")
	c_me = _row(cl, "Daemon-2")
	var split := float(c_host[3]) + float(c_me[3]) if c_host.size() == 9 and c_me.size() == 9 else 0.0
	_check("acceptance: %%CPU is each one's share of the damage dealt this round (the host's 25 against the joiner's 26: %s and %s), summing to 100; the joiner still first, by K before %%CPU" % [c_host[3] if c_host.size() == 9 else "?", c_me[3] if c_me.size() == 9 else "?"], absf(split - 100.0) < 0.15 and c_host[3] == "49.0" and c_me[3] == "51.0" and _index(cl, "Daemon-2") == 0 and int(c_me[4]) == ceili(hs.combat.health_of(cid)), "\n" + "\n".join(cl))
	var stale: Dictionary = cs.top_numbers().duplicate(true)
	stale["rows"][999] = {"pid": 102, "kills": 0, "deaths": 0, "dealt": 500.0, "alive_s": 1.0}
	var gone_rows: Array = ctop.call("_match_rows", stale)
	var gone_sum := 0.0
	for r in gone_rows:
		gone_sum += r["cpu"]
	_check("a host's word still naming a player who has left (between its leaving and the next word) neither adds a row nor takes a share: the shares still sum to 100", gone_rows.size() == 2 and absf(gone_sum - 100.0) < 0.01, "%d rows, %.2f" % [gone_rows.size(), gone_sum])
	# Root: USER root on both screens, root's red on the other's.
	hs.combat.states[cid]["sudo"].charges = 1
	hs.combat.set("_sudo_changed", {cid: true})
	var csudo = cp.get("sudo")
	await _until(func(): return csudo.charges() == 1, 4000)
	csudo.press()
	await _until(func(): return hs.combat.root(cid) and csudo.is_root() and hs.root_left.get(cid, 0.0) > 0.0, 4000)
	await _next_refresh(htop)
	await _next_refresh(ctop)
	hl = htop.lines()
	cl = ctop.lines()
	_check("acceptance: after the joiner's sudo its USER is root on both screens (the host's word), its row in root's red on the host's", _row(hl, "Daemon-2")[1] == "root" and _row(cl, "Daemon-2")[1] == "root" and _row(hl, "Daemon-1")[1] == "user" and htop.row_color(_index(hl, "Daemon-2")) == Palette.HOSTILE_RED, "\n" + "\n".join(hl))
	# SIGSTOP: T where this game knows it.
	hs.combat.states[cid]["stop"].meter = 4.0
	cp.get("sigstop").press()
	await _until(func(): return hs.combat.sigstop_on(cid) and cp.get("sigstop").is_on(), 4000)
	hs.combat.states[1]["stop"].meter = 4.0
	host["player"].get("sigstop").press()
	await _until(func(): return hs.combat.sigstop_on(1), 4000)
	await _next_refresh(htop)
	await _next_refresh(ctop)
	hl = htop.lines()
	cl = ctop.lines()
	_check("acceptance: S is T where this game knows that SIGSTOP is on: on the host's screen both (\"2 stopped\"); on the joiner's its own T and the host's R, which only the host knows", _row(hl, "Daemon-1")[2] == "T" and _row(hl, "Daemon-2")[2] == "T" and hl[1] == "Tasks: 2 total, 0 running, 2 stopped, 0 zombie" and _row(cl, "Daemon-2")[2] == "T" and _row(cl, "Daemon-1")[2] == "R", "\n" + "\n".join(hl) + "\n" + "\n".join(cl))
	cp.get("sigstop").press()
	host["player"].get("sigstop").press()
	await _until(func(): return not hs.combat.sigstop_on(cid) and not hs.combat.sigstop_on(1), 4000)
	await _until(func(): return not hs.combat.root(cid), 12000)
	Input.action_release("show_top")
	await physics_frame
	# The host kills the joiner twice: the joiner's table up while it is dead, and the order flips.
	var shown_dead := 0
	var hidden_on_respawn := 0
	for k in 2:
		await _until(func(): return not cs.dead.get(cid, false) and hs.protect_left.get(cid, 0.0) <= 0.0, 8000)
		if await _host_kills_joiner(host, client, cid):
			await process_frame
			if ctop.is_showing() and not htop.is_showing():
				shown_dead += 1
			await _until(func(): return not cs.dead.get(cid, false), 8000)
			if not ctop.is_showing():
				hidden_on_respawn += 1
	_check("acceptance: on the joiner's screen too, the table is up the moment it is derezzed (the host's, alive, has none) and gone the moment it respawns, both times", shown_dead == 2 and hidden_on_respawn == 2, "%d %d" % [shown_dead, hidden_on_respawn])
	Input.action_press("show_top")
	await _fresh(cs, ctop)
	await _next_refresh(htop)
	cl = ctop.lines()
	hl = htop.lines()
	_check("acceptance: sorted by K, highest first, on both screens: the host's 2 kills now put it above the joiner's 1; deaths 1 and 2; the 3 kills in the last 60 s of play in the load average", _index(cl, "Daemon-1") == 0 and _index(hl, "Daemon-1") == 0 and _row(cl, "Daemon-1")[6] == "2" and _row(cl, "Daemon-2")[6] == "1" and _row(cl, "Daemon-1")[7] == "1" and _row(cl, "Daemon-2")[7] == "2" and cl[0].ends_with(", 3.00") and hl[0].ends_with(", 3.00"), "\n" + "\n".join(cl))
	Input.action_release("show_top")
	_drop(host)
	_drop(client)
	await _frames(4)
	var orphans_after := int(Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT))
	_check("acceptance: no orphan nodes are left behind by any of it", orphans_after <= orphans, "%d before, %d after" % [orphans, orphans_after])


## The joiner's real cannon kills the host, its health set to 1 first. True when the host died.
func _joiner_kills_host(host: Dictionary, client: Dictionary, cid: int) -> bool:
	var hs: Session = host["session"]
	var cp: Node = client["player"]
	await _until(func(): return not hs.dead.get(1, false) and hs.protect_left.get(1, 0.0) <= 0.0 and not hs.dead.get(cid, false), 8000)
	_place(host, Vector3(-8.0, STAND_Y, LINE_Z), Vector3(-1.0, 0.0, 0.0))
	_place(client, Vector3(-12.0, STAND_Y, LINE_Z), Vector3(1.0, 0.0, 0.0))
	await _frames(10)
	_aim(cp, client["main"].to_global(Vector3(-8.0, 0.9, LINE_Z)))
	await _settle(cp, 0.6)
	await _until(_heard.bind(hs, cid, client), 4000)
	hs.combat.states[1]["health"] = 1.0
	hs.call("_mirror_from_combat")
	await _fire(cp)
	return await _until(func(): return hs.dead.get(1, false), 4000)


## The host's real cannon kills the joiner, its health set to 1 first. True when it died on
## both screens.
func _host_kills_joiner(host: Dictionary, client: Dictionary, cid: int) -> bool:
	var hs: Session = host["session"]
	var cs: Session = client["session"]
	var hp: Node = host["player"]
	_place(host, Vector3(-8.0, STAND_Y, LINE_Z), Vector3(-1.0, 0.0, 0.0))
	_place(client, Vector3(-12.0, STAND_Y, LINE_Z), Vector3(1.0, 0.0, 0.0))
	await _frames(10)
	_aim(hp, host["main"].to_global(Vector3(-12.0, 0.9, LINE_Z)))
	await _settle(hp, 0.6)
	await _until(_heard.bind(hs, cid, client), 4000)
	hs.combat.states[cid]["health"] = 1.0
	hs.call("_mirror_from_combat")
	await _fire(hp)
	return await _until(func(): return hs.dead.get(cid, false) and cs.dead.get(cid, false), 4000)


# --- The layout. ---

func _layout_checks() -> void:
	var before := root.size
	for size in [Vector2i(1280, 720), Vector2i(960, 540)]:
		root.size = size
		var host := _branch("Layout", Vector3.ZERO)
		var hs: Session = host["session"]
		hs.host(0)
		var client := _branch("LayoutClient", CLIENT_OFFSET)
		var cs: Session = client["session"]
		cs.join("127.0.0.1:%d" % hs.listen_port())
		await _until(func(): return cs.state == Session.State.JOINED and hs.players.size() == 2 and cs.players.size() == 2)
		var cid: int = cs.my_id
		await _until(func(): return hs.avatars.has(cid) and cs.avatars.has(1) and hs.combat.has_player(cid) and cs.get("_weapons_synced"), 6000)
		await _until(func(): return hs.protect_left.get(1, 0.0) <= 0.0 and hs.protect_left.get(cid, 0.0) <= 0.0, 6000)
		var top: SpectateTop = host["hud"].spectate_top()
		var hc = host["combat_hud"]
		host["hud"].guide()._notice("word ".repeat(60), Color.WHITE, 60000)  # a long guide notice, bottom centre
		for i in 3:
			hc.entries.push_front({"killer": "Daemon-2", "victim": "Daemon-1", "word": "SIGKILL", "left": 30.0})
		var dead := await _joiner_kills_host(host, client, cid)
		await process_frame
		await process_frame
		var screen := Rect2(Vector2.ZERO, Vector2(root.size))
		var table := top.panel_rect()
		var wrong := PackedStringArray()
		var panel: Control = top.get("_panel")
		for label in host["main"].find_children("*", "Label", true, false):
			if not label.is_visible_in_tree() or label.text.is_empty() or panel.is_ancestor_of(label):
				continue
			var rect: Rect2 = label.get_global_rect()
			if rect.size.x >= screen.size.x - 1.0:
				continue  # a full-width line, its text centred: the banner, the callout, the click line
			if rect.intersects(table):
				wrong.append("%s %s" % [label.text.left(24), rect])
		var banner: Rect2 = hc.banner_rect()
		var words: Rect2 = hc.banner_text_rect()
		var guide_panel: Rect2 = host["hud"].guide().get("_panel").get_global_rect()
		for label in hc.get("_feed_labels"):
			if label.visible and label.get_global_rect().intersects(words):
				wrong.append("feed under the banner: %s" % label.get_global_rect())
		if host["hud"].guide().get("_panel").visible and guide_panel.intersects(words):
			wrong.append("guide panel %s under the banner %s" % [guide_panel, words])
		var lines := top.lines()
		var widest := 0.0
		for label in panel.find_children("*", "Label", true, false):
			if label.is_visible_in_tree():
				widest = maxf(widest, label.get_minimum_size().x)
		_check("acceptance: at %dx%d the table fits: dead in a match it is inside the screen, full width, every line of it whole, under the status, round, net and combat lines; nothing else on the HUD under it (a full kill feed and a long guide notice up); the death banner below it, one line, clear of the feed and the guide's panel" % [size.x, size.y], dead and top.is_showing() and screen.encloses(table) and table.size.x >= screen.size.x - 40.0 and widest <= table.size.x and wrong.is_empty() and banner.position.y >= table.end.y and screen.encloses(words) and words.size.x > 0.0 and hc.banner_text().begins_with("[ DEREZZED by Daemon-2 ]   respawn in ") and not hc.banner_text().contains("\n") and hc.feed_text().size() == 4 and host["hud"].guide().get("_panel").visible, "%s in %s, banner %s, guide %s; %s" % [table, screen, words, guide_panel, ", ".join(wrong)])
		# The round's summary at this size: never with the table.
		var round = host["hud"].round_hud()
		var short = load("res://resources/announcer.tres").duplicate()
		short.round_seconds = 1.0
		short.intermission_seconds = 1.5
		round.restart(short)
		Input.action_press("show_top")
		var both := false
		var saw := false
		var summary_rect := Rect2()
		for i in 200:
			await physics_frame
			if round.showing_summary():
				saw = true
				summary_rect = round.get("_panel").get_global_rect()
				both = both or top.is_showing()
			elif saw:
				break
		await physics_frame
		var shown_rect := top.panel_rect()
		_check("acceptance: at %dx%d the round's summary and the table never overlap: through the break the table is hidden, and back after it" % [size.x, size.y], saw and not both and top.is_showing() and screen.encloses(summary_rect), "summary %s, table %s" % [summary_rect, shown_rect])
		Input.action_release("show_top")
		round.restart(load("res://resources/announcer.tres"))
		_drop(host)
		_drop(client)
		await _frames(3)
	root.size = before


# --- Helpers. ---

## Waits for the table's next refresh.
func _next_refresh(top: SpectateTop) -> void:
	var n := top.refreshes
	await _until(func(): return top.refreshes > n, 4000)


## Waits for the host's next table message to the joiner, then the joiner's next refresh.
func _fresh(cs: Session, top: SpectateTop) -> void:
	var n := cs.tops_received
	await _until(func(): return cs.tops_received > n, 4000)
	await _next_refresh(top)


## Seconds from a TIME+ "m:ss.hh".
func _secs(time: String) -> float:
	var parts := time.split(":")
	return float(parts[0]) * 60.0 + float(parts[1]) if parts.size() == 2 else -1.0


func _tokens(line: String) -> PackedStringArray:
	return line.split(" ", false)


## The row whose command is `command`, split into its columns, or empty.
func _row(lines: PackedStringArray, command: String) -> PackedStringArray:
	var i := _index(lines, command)
	return _tokens(lines[i + 3]) if i >= 0 else PackedStringArray()


## Which row (0 first) is `command`'s, or -1.
func _index(lines: PackedStringArray, command: String) -> int:
	for i in range(3, lines.size()):
		var t := _tokens(lines[i])
		if t.size() == 9 and t[8] == command:
			return i - 3
	return -1


func _kill_dummy(dummy: Node) -> void:
	dummy.hit(100000.0, dummy.global_position + Vector3.UP, Vector3.FORWARD)


func _shown(action: String) -> String:
	for pair in Controls.REBINDABLE:
		if pair[0] == action:
			return pair[1]
	return ""


func _place(side: Dictionary, at: Vector3, facing: Vector3) -> void:
	var p: Node = side["player"]
	p.respawn_at(side["main"].to_global(at))
	p.rotation.y = atan2(-facing.x, -facing.z)
	p.get_node("Head").rotation.x = 0.0


func _aim(player: Node, target: Vector3) -> void:
	var cam: Node3D = player.get_node("Head/Camera")
	var to: Vector3 = target - cam.global_position
	player.rotation.y = atan2(-to.x, -to.z)
	player.get_node("Head").rotation.x = atan2(to.y, Vector2(to.x, to.z).length())


func _fire(p: Node) -> void:
	p.drive_input(Vector2.ZERO, false, false, true)
	await physics_frame


func _settle(p: Node, seconds: float) -> void:
	for i in ceili(seconds * 60.0):
		p.drive_input(Vector2.ZERO)
		await physics_frame


func _heard(hs: Session, cid: int, client: Dictionary) -> bool:
	var avatar = hs.avatars.get(cid)
	var cp: Node = client["player"]
	if avatar == null or not is_instance_valid(avatar) or not avatar.visible:
		return false
	var here: Vector3 = client["main"].to_local(cp.global_position)
	var look := (Basis(Vector3.UP, cp.rotation.y) * Basis(Vector3.RIGHT, cp.view_pitch()) * Vector3.FORWARD).normalized()
	return avatar.latest_position().distance_to(here) < 0.05 and avatar.latest_view().angle_to(look) < deg_to_rad(1.0)


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


func _branch(name: String, offset: Vector3, protocol: int = -1) -> Dictionary:
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
	if protocol >= 0:
		session.protocol = protocol
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
	var out := {"branch": branch, "session": session, "main": main, "player": main.get_node("Player"), "hud": hud, "combat_hud": hud.combat_hud()}
	out["player"].assume_captured = true
	return out


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
	var rpc := source.find("\n@rpc(", at + 1)
	if rpc > 0 and (end < 0 or rpc < end):
		end = rpc
	return source.substr(at, (end if end > 0 else source.length()) - at)


func _cleanup() -> void:
	Input.action_release("show_top")
	for node in _arenas.duplicate() + _branches.duplicate():
		if is_instance_valid(node):
			var session = node.get_node_or_null(Session.NODE_NAME)
			if session != null:
				session.leave()
			node.free()
	var left = Link.take_parked()
	if left != null:
		left.shut_down(null)
	Controls.apply_binds({})
	await process_frame
	OS.delay_msec(300)
	await process_frame
