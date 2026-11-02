class_name KeybindGunplay
extends Node3D
## Keybind gunplay (W4, PRD 5.5; the fourth of M5's world features): the player learns Omarchy's shortcuts by fighting
## with them. Reached from the Esc menu ("Keybind gunplay"; "Leave keybind gunplay" ends it), or with --keys on a demo or
## test run. Made by the arena (scripts/main.gd) beside the other world modes; it begins when queued. The regular arena's
## keys never change: only this mode reads chords, and only while it runs.
##
## The chord: Super is the desktop's (the compositor takes a Super chord before any window sees it, and the game never
## asks anyone to unbind one), so a key the game holds stands in for it (KeyBook.STANDIN, the ` key). While it is held the
## next key is the chord: the player stands still (looking stays free; nothing fires) and every key it is held with goes
## to this mode, never to the game's own actions. Each chord shows its card (scripts/keys/keybind_hud.gd): the real
## shortcut ("SUPER + W"), Omarchy's own meaning ("Close window"), what it does here, how it was played ("` + W").
## Shortcuts that are weapons here (KeyBook.WEAPONS, scripts/keys/key_fx.gd) fire; the rest only teach.
##
## A run, ending on a results card (every shortcut, its uses and kills, its drill, learned or not; the cards read):
##   drill  one a weapon (KeyBook.DRILLS): its daemons stand asleep before the player (the last drill's come hunting),
##          its chord on a banner; it is done when the shortcut does what it asks (a kill with it; a workspace changed),
##          or skipped when its time (DRILL_S) is up.
##   wave   WAVES daemons of the arena's kinds, awake, every shortcut live with its cooldown; until they are down or
##          WAVE_S is up.
##
## Two layers, as the visor's, the hunt's, the map's and the theme shift's:
##   demo  the default, and the only layer the tests and captures use: the built-in table (KeyBook.DEFAULTS, Omarchy's
##         public defaults).
##   real  opt-in, behind the same answer as the opener's real data (opener data, real-machine data on, never a demo
##         run): the player's own binds (scripts/keys/key_reader.gd: combos and descriptions only, capped, read-only), laid
##         over the table so each weapon fires from the chord their desktop gives its meaning. Off, nothing is read.
## Nothing here calls the compositor, sends or makes a key press for anything but this game's own window, writes, changes
## or switches any bind or config, or runs anything. Close, split, float and the rest are the game's own hits on its own
## daemons.

const DummyScene = preload("res://scenes/target_dummy.tscn")
const RogueArt = preload("res://scripts/daemons/rogue_daemon.gd")
const ZombieArt = preload("res://scripts/daemons/zombie_process.gd")
const RunawayArt = preload("res://scripts/daemons/runaway_swarm.gd")
const Palette = preload("res://scripts/palette.gd")
const SettingsApply = preload("res://scripts/settings/settings_apply.gd")

const GROUP := &"keybind_gunplay"
const NODE_NAME := "KeybindGunplay"
const FLAG := "--keys"
const SET_ID := "fs_keys"
const GATE_EVERY_S := 2.0
## A drill's time before it is skipped, a wave's, the beat after a drill is done.
const DRILL_S := 45.0
const WAVE_S := 80.0
const DONE_S := 1.6
const WAVES := [5, 7]
const MOST_ENEMIES := 9
const WORKSPACES := 5
## How far the crosshair reaches for a window to close, split or float, and how far off it a daemon still counts.
const AIM_REACH := 60.0
const AIM_CONE_DEG := 7.0
## Full screen: how far a daemon on the screen may stand, and when its hit lands (as the border reaches the edges).
const FULL_REACH := 50.0
const FULL_HIT_S := 0.24
const SLIDE_S := 0.32
const TAGS := {"rogue": "rogue.d", "zombie": "zombie", "runaway": "runaway"}
const EVENTS_KEPT := 5
## Each drill's daemons: [kind, how many, awake].
const DRILL_ROSTER := {
	"terminal": [["rogue", 3, false]],
	"close": [["rogue", 1, false], ["zombie", 1, false]],
	"split": [["rogue", 2, false]],
	"float": [["zombie", 1, false], ["rogue", 1, false]],
	"fullscreen": [["rogue", 2, false], ["zombie", 1, false], ["runaway", 1, false]],
	"workspace": [["rogue", 2, true], ["runaway", 1, true]],
}
const DRILL_ASK := {
	"terminal": "open a terminal on them",
	"close": "close a daemon's window",
	"split": "split a daemon down the middle",
	"float": "float a daemon and let it tile",
	"fullscreen": "go full screen with them in view",
	"workspace": "they are awake: change workspace",
}
## The visor's mark round a window (its corners), and its label's lift.
const MARK_ARM := 0.4

## Queued for the next arena (the Esc menu, the flag); its layer and the table it plays (key -> entry); every weapon's
## numbers; the cards read. Kept across reloads, as the mode is.
static var queued := false
static var layer := "demo"
static var table := {}
static var stats := {}
static var seen := {}
## For the tests: the gate and a fake home; unset in the game. The clocks, shortened by a test.
static var gate: Callable
static var home_root := ""
static var drill_s := DRILL_S
static var wave_s := WAVE_S
## The stand-in held now (one chord at a time, whatever arena): Tab held with it is SUPER + TAB, not the top table.
static var holding := false
static var _flag_taken := false
static var _going := false
static var _misses := 0
const MISSES_MOST := 2

signal began
signal ended
signal spawned(dummy: Node3D)
signal event(kind: String, text: String)
## A shortcut was used: its weapon id ("" for one that only teaches) and its chord.
signal used(id: String, combo: String)

var running := false
var player: Node3D = null
var director: DaemonDirector = null
var runner: MissionRunner = null
var ice: Node = null
var rounds: Node = null
var guide: Node = null
var visor: Node = null
var world: RuinsWorld = null
## "drill", "done" (the beat after one), "wave", "results"; which drill and wave.
var phase := ""
var drill := 0
var wave := 0
## Its enemies: {body, kind, slot}.
var enemies: Array = []
var events: Array = []
## Seconds each weapon has to cool.
var cooling := {}
## The stand-in held: the next key is a chord.
var chord := false
## The card on screen ({}, none): KeyBook.card()'s, with its age and whether it was the first of its chord.
var card := {}
## Omarchy's keybindings list (SUPER + K) open.
var list_open := false
## The workspace the player is on, and where each is.
var workspace := 0
var workspace_at: Array[Vector3] = []
## How high the player's origin stands over the floor (its body's middle), so a workspace sets it down standing.
var _stand_y := 0.9
## Full screen's and the slide's clocks (-1 none), for the HUD; full screen's daemons on the screen.
var full_t := -1.0
var slide_t := -1.0
var _full_marks: Array = []
var _drill_done := false
var _hud: CanvasLayer = null
var _lines: VisorLines = null
var _marks := {}
var _desktop: Node3D = null
var _sfx: AudioStreamPlayer = null
var _pops: Array = []
var _clock := 0.0
var _phase_t := 0.0
var _gate_wait := 0.0


static func of(node: Node) -> KeybindGunplay:
	if node == null or not node.is_inside_tree():
		return null
	var mine := node.get_node_or_null(NODE_NAME) as KeybindGunplay
	if mine != null:
		return mine
	for m in node.get_tree().get_nodes_in_group(GROUP):
		if not m.is_queued_for_deletion():
			return m as KeybindGunplay
	return null


static func queue() -> void:
	queued = true
	stats = {}
	seen = {}


static func clear() -> void:
	queued = false
	holding = false
	stats = {}
	seen = {}
	table = {}
	layer = "demo"


static func take_flag(args: PackedStringArray) -> void:
	if _flag_taken:
		return
	_flag_taken = true
	if args.has(FLAG) and (args.has("--demo") or OS.get_cmdline_args().has("--script")):
		queue()


## As the arena loads, before it is staged (scripts/main.gd): its district queued for the stage, when the mode is queued,
## alone and with no mission. `real` is the visor's gate for this run.
static func prepare(args: PackedStringArray, online: bool, real: bool) -> void:
	take_flag(args)
	_going = false
	if not queued or online or MissionRunner.pending() != "":
		return
	ensure_table(bool(gate.call()) if gate.is_valid() else real)
	RuinsStage.queue_set(district())


## The table for this layer: the built-in one, or (real, when the player's binds read) theirs laid over it, every drill's
## weapon kept on its built-in chord where their desktop has none for it and the key is free.
static func ensure_table(real: bool) -> void:
	var want := "real" if real else "demo"
	if not table.is_empty() and layer == want:
		return
	layer = want
	table = KeyBook.resolve()
	if real:
		var binds := KeyReader.read(home_root if home_root != "" else OS.get_environment("HOME"))
		if not binds.is_empty():
			table = with_defaults(KeyBook.resolve(binds))
		else:
			layer = "demo"


## `mine` (a table from the player's binds) with every drill weapon it has no chord for put on its built-in chord, where
## that key is free in it.
static func with_defaults(mine: Dictionary) -> Dictionary:
	var out := mine.duplicate(true)
	var base := KeyBook.resolve()
	for id in KeyBook.DRILLS:
		if KeyBook.chord_for(out, id) != "":
			continue
		for key in base:
			if str(base[key]["weapon"]) == id and not out.has(key):
				out[key] = base[key]
				break
	return out


## The mode's district, made at play from C36's kit: a clean Tron hall, open in the middle for the drills.
static func district() -> RuinsSet:
	var s := RuinsSet.new()
	s.id = SET_ID
	s.title = "the desktop"
	s.seed = 8404
	s.register = "tron"
	s.cells = Vector2i(12, 14)
	s.blocks = 5
	s.holes = 0
	s.cover = 10
	s.towers = 10
	s.giants = 4
	s.cables = 0
	s.signs = 4
	s.tall = 0.75
	s.pristine = true
	s.clearing = 2
	s.words = PackedStringArray(["SUPER", "TILING", "FLOATING", "WORKSPACE", "FULL SCREEN", "RETURN"])
	s.folders = PackedStringArray(["terminal", "editor", "monitor", "files"])
	return s


func _ready() -> void:
	name = NODE_NAME
	add_to_group(GROUP)


func _exit_tree() -> void:
	if chord:
		holding = false  # freed mid-chord (a reload): the next arena's Tab is the top table's again


func real_allowed() -> bool:
	if gate.is_valid():
		return bool(gate.call())
	var link = guide.session_link() if guide != null and is_instance_valid(guide) and guide.has_method("session_link") else null
	return AuditVisor.real_gate_for(link)


## Begins a run where the arena stands in its district: the arena's own daemons parked, ICE stood down, the rounds held,
## the desktop up, the first drill in. False online, in a mission, or not yet in its district (it reloads there first).
func begin() -> bool:
	if running or _online() or (runner != null and is_instance_valid(runner) and runner.running()):
		return false
	ensure_table(real_allowed())
	running = true
	queued = true
	world = _world()
	if world == null or world.ruins == null or world.ruins.id != SET_ID:
		running = false
		_misses += 1
		if _misses > MISSES_MOST:
			_misses = 0
			clear()
			return false
		_go("$ keys --drill")
		return false
	_misses = 0
	_park_arena_daemons()
	if ice != null and is_instance_valid(ice) and "stand_down" in ice:
		ice.stand_down = true
	if rounds != null and is_instance_valid(rounds) and rounds.has_method("hold"):
		rounds.hold(true)
	for id in KeyBook.WEAPONS:
		if not stats.has(id):
			stats[id] = {"uses": 0, "hits": 0, "kills": 0, "drill": ""}
		cooling[id] = 0.0
	_find_workspaces()
	_build_desktop()
	_hud = KeybindHud.new()
	_hud.mode = self
	add_child(_hud)
	_lines = VisorLines.new()
	_lines.through_walls = true
	add_child(_lines)
	_sfx = AudioStreamPlayer.new()
	_sfx.name = "Shortcut"
	_sfx.bus = SettingsApply.EFFECTS if AudioServer.get_bus_index(SettingsApply.EFFECTS) >= 0 else &"Master"
	_sfx.max_polyphony = 4
	add_child(_sfx)
	drill = 0
	wave = 0
	_start_drill()
	_note("begin", "SUPER is your desktop's: here, hold %s" % KeyBook.STANDIN_NAME)
	began.emit()
	return true


## Ends the mode where it stands (a match starting, the Esc menu's way out): its enemies and effects gone, the arena's own
## back, ICE and the rounds as they were. Not queued any more.
func end() -> void:
	if not running:
		return
	running = false
	set_chord(false)
	for e in enemies:
		var body = e["body"]
		if is_instance_valid(body) and not body.is_queued_for_deletion():
			body.queue_free()
	enemies.clear()
	_release_parked()
	if ice != null and is_instance_valid(ice) and "stand_down" in ice:
		ice.stand_down = false
	if rounds != null and is_instance_valid(rounds) and rounds.has_method("hold"):
		rounds.hold(false)
	if director != null and is_instance_valid(director):
		director.forget_brains()
	for node in get_children():
		node.queue_free()
	_hud = null
	_lines = null
	_desktop = null
	clear()
	ended.emit()


func _world() -> RuinsWorld:
	var host := get_parent()
	return host.get_node_or_null("Arena/" + RuinsWorld.NODE_NAME) as RuinsWorld if host != null else null


func _online() -> bool:
	var session = director.session if director != null and is_instance_valid(director) else null
	return session != null and is_instance_valid(session) and session.has_method("is_online") and session.is_online()


# --- The chord. ---

## The stand-in held or let go. Held, the player stands (looking stays free) and nothing of theirs fires.
func set_chord(on: bool) -> void:
	if on and (not running or phase == "results" or not _can_act()):
		on = false
	chord = on
	holding = on
	if player != null and is_instance_valid(player) and "chord_open" in player:
		player.chord_open = on


func _input(ev: InputEvent) -> void:
	if not running or phase == "results":
		return
	if not (ev is InputEventKey):
		if chord and ev is InputEventMouseButton and (ev as InputEventMouseButton).pressed:
			get_viewport().set_input_as_handled()  # no shot while the chord is held
		return
	var k := ev as InputEventKey
	var code := int(k.physical_keycode) if k.physical_keycode != KEY_NONE else int(k.keycode)
	if code == KeyBook.STANDIN:
		if not chord and not _can_act():
			return  # the menu or the ask box has the keys: a ` typed there is theirs
		get_viewport().set_input_as_handled()
		if not k.echo:
			set_chord(k.pressed)
		return
	if not chord:
		return
	if code == KEY_ESCAPE:
		set_chord(false)
		return  # Esc is the menu's, as ever
	get_viewport().set_input_as_handled()
	if k.pressed and not k.echo:
		press(code)


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT or what == NOTIFICATION_WM_WINDOW_FOCUS_OUT:
		set_chord(false)


func _can_act() -> bool:
	return player != null and is_instance_valid(player) and player.get("alive") != false and player.get("input_blocked") != true


## The chord on `code` (the stand-in held): its card shown, and its shortcut fired when it is a weapon here and cool.
## Returns the weapon id it fired, or "".
func press(code: int) -> String:
	var entry: Dictionary = table.get(code, {})
	if entry.is_empty():
		var token := _token_of(code)
		show_card({"combo": "%s + %s" % [KeyBook.SUPER, token], "caps": PackedStringArray([KeyBook.SUPER, KeyBook.cap_of(token)]), "meaning": "nothing on this chord", "weapon": "", "here": "no shortcut in the table on this key", "played": "%s + %s" % [KeyBook.STANDIN_NAME, KeyBook.cap_of(token)], "cooling": 0.0})
		_play("tick")
		return ""
	var combo := str(entry["combo"])
	var id := str(entry["weapon"])
	var first := not seen.has(combo)
	seen[combo] = true
	var left := float(cooling.get(id, 0.0)) if id != "" else 0.0
	show_card(KeyBook.card(entry, left), first)
	if id == "":
		used.emit("", combo)
		_play("tick")
		return ""
	if left > 0.0:
		_note("cool", "%s cooling %.1fs" % [combo, left])
		return ""
	if not _can_act() or not _fire(id, entry):
		return ""
	var cool := float(KeyBook.WEAPONS[id]["cool"])
	cooling[id] = cool
	if id == "workspace" or id == "goto":
		cooling["workspace"] = cool
		cooling["goto"] = cool
	stats[id]["uses"] = int(stats[id]["uses"]) + 1
	used.emit(id, combo)
	_play(id)
	_note("use", "%s  %s" % [combo, str(entry["meaning"])])
	if phase == "drill" and not _drill_done and KeyBook.DRILLS[drill] == "workspace" and (id == "workspace" or id == "goto"):
		_complete_drill()
	return id


func _token_of(code: int) -> String:
	for t in KeyBook.KEY_TOKENS:
		if int(KeyBook.KEY_TOKENS[t]) == code:
			return t
	return OS.get_keycode_string(code as Key).to_upper()


func show_card(c: Dictionary, first: bool = false) -> void:
	card = c.duplicate()
	card["t"] = 0.0
	card["first"] = first


func _fire(id: String, entry: Dictionary) -> bool:
	match id:
		"terminal":
			var cam := get_viewport().get_camera_3d()
			if cam == null:
				return false
			var blast := KeyFx.TerminalBlast.new()
			add_child(blast)
			blast.start(cam.global_position + cam.global_basis.x * 0.25 - cam.global_basis.y * 0.15, -cam.global_basis.z, player)
			return true
		"close", "split", "float":
			var target := aim_target()
			if target == null:
				_note("miss", "no window under the crosshair")
				card["here"] = "no window under the crosshair: aim at a daemon"
				return false
			var fx: Node3D = KeyFx.CloseFold.new() if id == "close" else (KeyFx.SplitPane.new() if id == "split" else KeyFx.FloatTile.new())
			add_child(fx)
			fx.call("start", target)
			stats[id]["hits"] = int(stats[id]["hits"]) + 1
			return true
		"fullscreen":
			full_t = 0.0
			_full_marks = on_screen()
			return true
		"workspace":
			go_to_workspace((workspace + 1) % maxi(workspace_at.size(), 1))
			return true
		"goto":
			var n := int(entry.get("workspace", 1))
			go_to_workspace((maxi(n, 1) - 1) % maxi(workspace_at.size(), 1))
			return true
		"keys":
			list_open = not list_open
			return true
	return false


## The daemon under the crosshair: the one the view's ray meets, else the nearest within AIM_CONE_DEG of it in sight.
func aim_target() -> Node3D:
	var cam := get_viewport().get_camera_3d() if is_inside_tree() else null
	if cam == null:
		return null
	var from := cam.global_position
	var way := -cam.global_basis.z
	var got := _ray(from, from + way * AIM_REACH)
	if not got.is_empty() and _hittable(got["collider"]):
		return got["collider"] as Node3D
	var best: Node3D = null
	var best_a := deg_to_rad(AIM_CONE_DEG)
	for body in get_tree().get_nodes_in_group("targets"):
		if not _hittable(body):
			continue
		var p: Vector3 = body.threat_point()
		var v := p - from
		if v.length() > AIM_REACH:
			continue
		var a := way.angle_to(v)
		if a < best_a and _sees(from, p, body):
			best_a = a
			best = body
	return best


## Every daemon on the screen: in the view, within FULL_REACH, in sight.
func on_screen() -> Array:
	var out: Array = []
	var cam := get_viewport().get_camera_3d() if is_inside_tree() else null
	if cam == null:
		return out
	for body in get_tree().get_nodes_in_group("targets"):
		if not _hittable(body):
			continue
		var p: Vector3 = body.threat_point()
		if cam.global_position.distance_to(p) > FULL_REACH or not cam.is_position_in_frustum(p):
			continue
		if _sees(cam.global_position, p, body):
			out.append(body)
	return out


static func _hittable(body) -> bool:
	return body != null and is_instance_valid(body) and body is Node3D and body.has_method("is_alive") and body.is_alive() and body.is_in_group("targets")


func _ray(from: Vector3, to: Vector3) -> Dictionary:
	var q := PhysicsRayQueryParameters3D.create(from, to)
	if player != null and is_instance_valid(player) and player is CollisionObject3D:
		q.exclude = [(player as CollisionObject3D).get_rid()]
	return get_world_3d().direct_space_state.intersect_ray(q)


func _sees(from: Vector3, p: Vector3, body: Node3D) -> bool:
	var got := _ray(from, p)
	return got.is_empty() or got["collider"] == body


func _step_full(delta: float) -> void:
	if full_t < 0.0:
		return
	var before := full_t
	full_t += delta
	if before < FULL_HIT_S and full_t >= FULL_HIT_S:
		for body in _full_marks:
			if not _hittable(body):
				continue
			var p: Vector3 = body.threat_point()
			body.hit(1.0, p, Vector3.ZERO, KeyFx.SOURCE_PREFIX + "fullscreen")
			stats["fullscreen"]["hits"] = int(stats["fullscreen"]["hits"]) + 1
			_pop(body, KeyFx.color_of("fullscreen"))
		_full_marks.clear()
	if full_t > 1.0:
		full_t = -1.0


## A window flashing round `body` for a moment (full screen's mark).
func _pop(body: Node3D, color: Color) -> void:
	var f := KeyFx.frame_of(body)
	var w := KeyWindow.make(f[0], KeyWindow.Style.FRAME, color, "", 4.0)
	w.top_level = true
	w.set_param("body_alpha", 0.25)
	w.set_param("glow", 3.4)
	add_child(w)
	w.global_position = f[1]
	_pops.append([w, 0.0])


# --- The workspaces. ---

## Five places across the district, spread as far apart as they go from where the player starts.
func _find_workspaces() -> void:
	workspace_at.clear()
	var pool: Array[Vector3] = []
	if world != null:
		pool.append_array(world.points_of("daemon"))
		pool.append_array(world.points_of("breaker"))
	var start: Vector3 = player.global_position if player != null and is_instance_valid(player) else Vector3.ZERO
	var floor_y := world.floor_y_at(start) if world != null else 0.0
	_stand_y = maxf(start.y - floor_y, 0.0)
	workspace_at.append(Vector3(start.x, floor_y, start.z))
	while workspace_at.size() < WORKSPACES and not pool.is_empty():
		var best := 0
		var best_d := -1.0
		for i in pool.size():
			var d := INF
			for w in workspace_at:
				d = minf(d, pool[i].distance_to(w))
			if d > best_d:
				best_d = d
				best = i
		workspace_at.append(pool[best])
		pool.remove_at(best)
	workspace = 0


func go_to_workspace(n: int) -> void:
	if workspace_at.is_empty() or player == null or not is_instance_valid(player):
		return
	workspace = clampi(n, 0, workspace_at.size() - 1)
	var to := workspace_at[workspace]
	player.global_position = to + Vector3.UP * (_stand_y + 0.02)
	if "velocity" in player:
		player.velocity = Vector3.ZERO
	var mid := _middle()
	var look := mid - to
	if look.length_squared() > 1.0:
		player.rotation.y = atan2(-look.x, -look.z)
	slide_t = 0.0
	_note("workspace", "workspace %d" % (workspace + 1))


func _middle() -> Vector3:
	var sum := Vector3.ZERO
	for w in workspace_at:
		sum += w
	return sum / maxf(workspace_at.size(), 1.0)


# --- The desktop: the district's sky full of windows, and a mark at every workspace. ---

func _build_desktop() -> void:
	_desktop = Node3D.new()
	_desktop.name = "Desktop"
	add_child(_desktop)
	var mid := _middle()
	var reach := 0.0
	for w in workspace_at:
		reach = maxf(reach, Vector2(w.x - mid.x, w.z - mid.z).length())
	var r := reach + 34.0
	var styles := [KeyWindow.Style.TERMINAL, KeyWindow.Style.MONITOR, KeyWindow.Style.EDITOR]
	var titles := [["terminal", "top", "editor"], ["editor", "terminal", "files"], ["monitor", "terminal", "notes"], ["terminal", "editor", "top"]]
	var accents := [Palette.TEAL, Palette.MINT, Color(0.78, 0.84, 1.0), Palette.TEAL]
	for side in 4:
		var a := PI * 0.5 * side + 0.35
		var centre := mid + Vector3(sin(a), 0.0, cos(a)) * r + Vector3.UP * 30.0
		var face_in := (mid - centre)
		face_in.y = 0.0
		var basis := Basis.looking_at(-face_in.normalized(), Vector3.UP)
		# Tiled as a tiling desktop lays out three windows: one tall on the left, two stacked on the right.
		var gap := 1.6
		var tiles := [[Vector2(-13.0, 0.0), Vector2(25.0, 34.0)], [Vector2(13.0 + gap * 0.5, 8.9), Vector2(25.0, 16.2)], [Vector2(13.0 + gap * 0.5, -8.9), Vector2(25.0, 16.2)]]
		for i in tiles.size():
			var t: Array = tiles[i]
			var w := KeyWindow.make(t[1], styles[(side + i) % styles.size()], accents[side].lerp(Color.WHITE, 0.1 * i), titles[side][i], float(side * 7 + i))
			w.set_param("glow", 2.6)
			w.set_param("border", 0.3)
			w.set_param("body_alpha", 0.88)
			w.set_param("body_light", 0.05)
			w.top_level = true
			_desktop.add_child(w)
			w.global_basis = basis
			w.global_position = centre + basis.x * (t[0] as Vector2).x + Vector3.UP * (t[0] as Vector2).y
			if w.label != null:
				w.label.pixel_size = 0.07
				w.label.position = Vector3(-(t[1] as Vector2).x * 0.5, (t[1] as Vector2).y * 0.5 + 0.4, 0.0)
	for i in workspace_at.size():
		var pad := KeyWindow.make(Vector2(3.2, 3.2), KeyWindow.Style.FRAME, Palette.LIME, "", 30.0 + i)
		pad.set_param("body_alpha", 0.12)
		pad.set_param("glow", 2.2)
		pad.set_param("border", 0.06)
		pad.top_level = true
		_desktop.add_child(pad)
		pad.global_position = workspace_at[i] + Vector3.UP * 0.04
		pad.global_basis = Basis(Vector3.RIGHT, -PI * 0.5)
		var tag := Label3D.new()
		tag.name = "Workspace%d" % (i + 1)
		tag.font = Palette.mono_font()
		tag.text = "workspace %d" % (i + 1)
		tag.font_size = 48
		tag.pixel_size = 0.012
		tag.outline_size = 10
		tag.outline_modulate = Color(0, 0, 0, 0.8)
		tag.modulate = Palette.LIME * 1.25
		tag.shaded = false
		tag.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		tag.position = workspace_at[i] + Vector3.UP * 2.7
		tag.top_level = true
		_desktop.add_child(tag)
		tag.global_position = workspace_at[i] + Vector3.UP * 2.7


# --- The roster. ---

func _start_drill() -> void:
	_clear_enemies()
	_drill_done = false
	_enter("drill")
	var id: String = KeyBook.DRILLS[drill]
	_spawn_roster(DRILL_ROSTER[id], "drill_%s" % id)
	_note("drill", "drill %d of %d: %s" % [drill + 1, KeyBook.DRILLS.size(), KeyBook.chord_for(table, id)])


func _complete_drill() -> void:
	if _drill_done:
		return
	_drill_done = true
	var id: String = KeyBook.DRILLS[drill]
	stats[id]["drill"] = "done"
	_note("learned", "learned %s  %s" % [KeyBook.chord_for(table, id), str(KeyBook.WEAPONS[id]["meaning"])])
	_enter("done")


func _next() -> void:
	if phase == "drill" or phase == "done":
		if drill < KeyBook.DRILLS.size() - 1:
			drill += 1
			_start_drill()
			return
		wave = 0
		_start_wave()
		return
	if phase == "wave":
		if wave < WAVES.size() - 1:
			wave += 1
			_start_wave()
			return
		_clear_enemies()
		set_chord(false)
		_enter("results")
		_note("done", "keybind gunplay complete")


func _start_wave() -> void:
	_clear_enemies()
	_enter("wave")
	var kinds := ["rogue", "zombie", "runaway", "rogue", "runaway", "rogue", "zombie"]
	var roster: Array = []
	for i in mini(int(WAVES[wave]), MOST_ENEMIES):
		roster.append([kinds[(i + wave * 2) % kinds.size()], 1, true])
	_spawn_roster(roster, "wave_%d" % wave, 12.0)
	_note("wave", "wave %d of %d" % [wave + 1, WAVES.size()])


## `roster` ([kind, count, awake] each) out of the floor: in front of the player for a drill, round the district for a
## wave (`away` metres from the player at least).
func _spawn_roster(roster: Array, key: String, away: float = 0.0) -> void:
	var spots := _spots_for(away)
	var at := 0
	for r in roster:
		for n in int(r[1]):
			if at >= spots.size() or enemies.size() >= MOST_ENEMIES:
				return
			_spawn(str(r[0]), spots[at], "%s_%d" % [key, at], bool(r[2]))
			at += 1


func _spots_for(away: float) -> Array:
	var pool: Array = []
	if world != null:
		for p in world.points_of("daemon") + world.points_of("breaker"):
			pool.append(p)
	if player == null or not is_instance_valid(player):
		return pool
	var me: Vector3 = player.global_position
	if away <= 0.0:
		# A drill: in front of the player, nearest a point 13 m ahead, never closer than 6 m.
		# Only where the player can see them standing: a drill is learned by doing, never by hunting for its daemons.
		var ahead: Vector3 = me - player.global_basis.z * 13.0
		var eye: Vector3 = me + Vector3.UP * 1.6
		var near: Array = pool.filter(func(p): return (p as Vector3).distance_to(me) >= 6.0 and _ray(eye, (p as Vector3) + Vector3.UP * 0.6).is_empty() and _ray(eye, (p as Vector3) + Vector3.UP * 1.4).is_empty())
		near.sort_custom(func(a, b): return (a as Vector3).distance_to(ahead) < (b as Vector3).distance_to(ahead))
		return near
	var far: Array = pool.filter(func(p): return (p as Vector3).distance_to(me) >= away)
	far.sort_custom(func(a, b): return (a as Vector3).distance_to(me) < (b as Vector3).distance_to(me))
	return far


func _spawn(kind: String, at: Vector3, slot: String, awake: bool) -> Node3D:
	var targets := _targets()
	if targets == null:
		return null
	var dummy = DummyScene.instantiate()
	dummy.name = "Keys_%s" % slot
	dummy.tag_text = TAGS[kind]
	dummy.respawns = false
	dummy.art = ZombieArt if kind == "zombie" else (RunawayArt if kind == "runaway" else RogueArt)
	dummy.seed_wanted = _seed_for(slot)
	dummy.set_meta(&"keys", slot)
	dummy.set_meta(&"world", true)  # its kills share the world modes' credit cap (W2)
	targets.add_child(dummy)
	dummy.global_position = at
	dummy.spawn_in(1.0)
	if player != null and is_instance_valid(player):
		var to: Vector3 = player.global_position - dummy.global_position
		dummy.rotation.y = atan2(-to.x, -to.z)
	if dummy.brain != null:
		dummy.brain.dormant = not awake
	dummy.downed.connect(_on_downed)
	enemies.append({"body": dummy, "kind": kind, "slot": slot})
	spawned.emit(dummy)
	_forget()
	return dummy


func _seed_for(slot: String) -> int:
	if OS.get_cmdline_user_args().has("--demo") or OS.get_cmdline_args().has("--script"):
		return DaemonArt.seed_of("keys:%s" % slot) & DaemonArt.SEED_LAST
	return randi() & DaemonArt.SEED_LAST


func _clear_enemies() -> void:
	var fx := ParticleFx.of(self)
	for e in enemies:
		var body = e["body"]
		if is_instance_valid(body) and not body.is_queued_for_deletion():
			if fx != null and body.is_alive():
				fx.impact(body.threat_point(), Vector3.UP, false, Palette.MINT)
			body.queue_free()
	enemies.clear()
	_forget()


func _forget() -> void:
	if director != null and is_instance_valid(director):
		director.forget_brains()


func _on_downed(dummy: Node3D) -> void:
	var source := str(dummy.get("killed_with"))
	if not source.begins_with(KeyFx.SOURCE_PREFIX):
		return
	var id := source.substr(KeyFx.SOURCE_PREFIX.length())
	if not stats.has(id):
		return
	stats[id]["kills"] = int(stats[id]["kills"]) + 1
	if phase == "drill" and not _drill_done and KeyBook.DRILLS[drill] == id:
		_complete_drill()


## Its daemons still standing (or climbing in).
func standing() -> int:
	var n := 0
	for e in enemies:
		var body = e["body"]
		if is_instance_valid(body) and (body.is_alive() or body.climbing()):
			n += 1
	return n


func _enter(next: String) -> void:
	phase = next
	_phase_t = 0.0


func time_left() -> float:
	if phase == "drill":
		return maxf(drill_s - _phase_t, 0.0)
	if phase == "wave":
		return maxf(wave_s - _phase_t, 0.0)
	return 0.0


## Shortcuts learned this run: a drill done, or a kill with it.
func learned() -> PackedStringArray:
	var out := PackedStringArray()
	for id in KeyBook.DRILLS:
		var s: Dictionary = stats.get(id, {})
		if str(s.get("drill", "")) == "done" or int(s.get("kills", 0)) > 0:
			out.append(id)
	return out


## Plays the run again from its first drill (the results card's Enter).
func again() -> void:
	if phase != "results":
		return
	stats = {}
	seen = {}
	for id in KeyBook.WEAPONS:
		stats[id] = {"uses": 0, "hits": 0, "kills": 0, "drill": ""}
		cooling[id] = 0.0
	drill = 0
	wave = 0
	go_to_workspace(0)
	_start_drill()
	_note("again", "again")


func _go(label: String) -> void:
	if _going:
		return
	_going = true
	SceneTear.reload_scene(get_tree(), label)


func leave() -> void:
	if _going:
		return
	_going = true
	clear()
	SceneTear.reload_scene(get_tree(), "$ exit")


func _physics_process(delta: float) -> void:
	if not running:
		return
	if _online():
		end()  # a match started mid-run: the match's rules, the arena's own back
		SceneTear.reload_scene(get_tree(), "$ exit")  # P1: and its district goes with it, the plain arena back
		return
	_clock += delta
	_phase_t += delta
	_gate_wait -= delta
	if _gate_wait <= 0.0:
		_gate_wait = GATE_EVERY_S
		if (layer == "real") != real_allowed() and not _going:
			table = {}
			ensure_table(real_allowed())  # the answer changed: the table follows it
	for id in cooling:
		cooling[id] = maxf(float(cooling[id]) - delta, 0.0)
	_step_full(delta)
	match phase:
		"drill":
			if not _drill_done and standing() == 0 and _phase_t > 1.5:
				# Downed some other way before the shortcut did it: they come back for the drill.
				_spawn_roster(DRILL_ROSTER[KeyBook.DRILLS[drill]], "drill_%s_again%d" % [KeyBook.DRILLS[drill], int(_phase_t)])
			if _phase_t >= drill_s:
				stats[KeyBook.DRILLS[drill]]["drill"] = "skipped"
				_note("skip", "skipped %s" % KeyBook.chord_for(table, KeyBook.DRILLS[drill]))
				_next()
		"done":
			if _phase_t >= DONE_S:
				_next()
		"wave":
			if standing() == 0 or _phase_t >= wave_s:
				_next()


func _process(delta: float) -> void:
	if not running:
		return
	if chord and not _can_act():
		set_chord(false)
	if not card.is_empty():
		card["t"] = float(card["t"]) + delta
		if float(card["t"]) > (4.0 if bool(card.get("first", false)) else 2.2):
			card = {}
	if slide_t >= 0.0:
		slide_t += delta
		if slide_t > SLIDE_S:
			slide_t = -1.0
	for p in _pops.duplicate():
		p[1] = float(p[1]) + delta
		var w: KeyWindow = p[0]
		if is_instance_valid(w):
			w.face(KeyFx._eye(self))
			w.set_param("fade", clampf(1.0 - float(p[1]) / 0.4, 0.0, 1.0))
		if float(p[1]) >= 0.4:
			if is_instance_valid(w):
				w.queue_free()
			_pops.erase(p)
	if _desktop != null:
		for w in _desktop.get_children():
			if w is KeyWindow:
				(w as KeyWindow).set_param("clock", _clock)
	_draw_visor()


func _unhandled_input(ev: InputEvent) -> void:
	if running and phase == "results" and ev.is_action_pressed("ui_accept"):
		get_viewport().set_input_as_handled()
		again()


# --- The visor: every daemon a window, as the compositor lists its clients. ---

func visor_on() -> bool:
	return visor != null and is_instance_valid(visor) and bool(visor.get("on"))


func _draw_visor() -> void:
	if _lines == null:
		return
	var on := visor_on()
	var lines: Array = []
	var cam := get_viewport().get_camera_3d() if is_inside_tree() else null
	var live := {}
	for e in enemies:
		var body = e["body"]
		if not _hittable(body):
			continue
		var iid: int = body.get_instance_id()
		live[iid] = true
		var mark: Label3D = _marks.get(iid)
		if not on or cam == null:
			if mark != null and is_instance_valid(mark):
				mark.visible = false
			continue
		var f := KeyFx.frame_of(body)
		var half: Vector2 = (f[0] as Vector2) * 0.5
		var mid: Vector3 = f[1]
		var right: Vector3 = cam.global_transform.basis.x
		var up: Vector3 = cam.global_transform.basis.y
		for sx in [-1.0, 1.0]:
			for sy in [-1.0, 1.0]:
				var corner: Vector3 = mid + right * half.x * sx + up * half.y * sy
				lines.append(_line(corner, corner - right * MARK_ARM * sx))
				lines.append(_line(corner, corner - up * MARK_ARM * sy))
		if mark == null or not is_instance_valid(mark):
			mark = _mark_label()
			_marks[iid] = mark
		mark.visible = true
		mark.text = "window 0x%x  %s\nworkspace %d" % [(iid * 2654435761) & 0xffffff, str(body.tag_text), workspace + 1]
		mark.global_position = mid + up * (half.y + 0.4)
	for iid in _marks.keys():
		if not live.has(iid):
			var m = _marks[iid]
			if is_instance_valid(m):
				m.queue_free()
			_marks.erase(iid)
	_lines.draw(lines, [])


func _line(a: Vector3, b: Vector3) -> Dictionary:
	return {"a": a, "b": b, "heat": 0.7, "width": 0.06, "grown": 1.0, "phase": 0.0, "burn": 0.0, "bright": 1.3, "depth": 0.0, "lift": 0.0}


func _mark_label() -> Label3D:
	var l := Label3D.new()
	l.name = "WindowMark"
	l.font = Palette.mono_font()
	l.font_size = 40
	l.pixel_size = 0.0075
	l.outline_size = 10
	l.outline_modulate = Color(0, 0, 0, 0.85)
	l.modulate = Palette.LIME.lerp(Color.WHITE, 0.25) * 1.3
	l.shaded = false
	l.no_depth_test = true
	l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(l)
	return l


# --- The arena's own daemons. ---

func _targets() -> Node3D:
	var host := get_parent()
	var t = host.get_node_or_null("Arena/Targets") if host != null else null
	return t as Node3D if t != null else (host as Node3D)


var _parked: Array = []


func _park_arena_daemons() -> void:
	var host := get_parent()
	for dummy in get_tree().get_nodes_in_group("targets"):
		if host != null and host.is_ancestor_of(dummy) and not dummy.has_meta(&"keys"):
			dummy.remove_from_group("targets")
			_parked.append([dummy, dummy.get_parent(), dummy.collision_layer])
			dummy.process_mode = Node.PROCESS_MODE_DISABLED
			dummy.visible = false
			dummy.collision_layer = 0
			dummy.reparent(self)
	_forget()
	for driver in get_tree().get_nodes_in_group(&"code_rain_driver"):
		if driver.has_method("invalidate"):
			driver.invalidate()


func _release_parked() -> void:
	for entry in _parked:
		var dummy: Node3D = entry[0]
		if not is_instance_valid(dummy) or not is_instance_valid(entry[1]):
			continue
		dummy.reparent(entry[1])
		dummy.collision_layer = entry[2]
		dummy.visible = true
		dummy.process_mode = Node.PROCESS_MODE_INHERIT
		dummy.add_to_group("targets")
	_parked.clear()


# --- For the HUD and the checks. ---

func _play(id: String) -> void:
	if _sfx == null or not _sfx.is_inside_tree():
		return
	_sfx.stream = KeyFx.sound(id)
	_sfx.play()


func _note(kind: String, text: String) -> void:
	events.append({"t": _clock, "kind": kind, "text": text})
	while events.size() > EVENTS_KEPT:
		events.pop_front()
	event.emit(kind, text)


func clock() -> float:
	return _clock


func phase_time() -> float:
	return _phase_t


static func going() -> bool:
	return _going
