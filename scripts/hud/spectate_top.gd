extends Control
## Spectate as top (C23, PRD 5.3 "dead players watch a live process-table style HUD of the
## match"): a full-width table in top's layout, monospace, in the theme's colours
## (scripts/palette.gd). In a match it comes up the moment this player is derezzed and goes
## the moment it respawns; holding Tab (the rebindable "show_top") shows it any time, alive
## or dead, alone or in a match. It refreshes once every refresh_s (a second, like top), not
## every frame. While the round's break summary is up it stays hidden, so the summary has the
## screen; so too while the menu, the multiplayer panel or a text box is open. While the death
## banner is up it sits just below the table.
##
## The header: "top - <round clock> up <time since the match started>, <N> users, load
## average: a, b, c", the load being the match's kills in the last 10, 30 and 60 seconds of
## play; then "Tasks: <total> total, <r> running, <s> stopped, <z> zombie". The columns: PID
## (a game number by join order from 100), USER (user, or root while C22's root is on), S (R
## alive, Z dead, T while that player's SIGSTOP is on as far as this game knows), %CPU (its
## share of the damage dealt this round), RES (health, rounded up), TIME+ (time alive this
## life, m:ss.hh), K, D and COMMAND (the in-game name). Sorted by K, then %CPU, highest first,
## then PID; this player's own row in reverse video, and always among the rows shown.
##
## Alone, the rows are the player and the arena's dummies, daemons "dummy-1" and on, Z while
## one derezzes or rematerialises; this table keeps their record itself (top_ledger.gd). In a
## match every number is the host's: the PIDs, kills, deaths, damage dealt, time alive, uptime
## and load from the host's table message (the session's top_numbers()); health, deaths, root
## and names from what the session already syncs. Nothing is made up for another player: a
## number this game has not been told shows as "-".
##
## Fiction only: nothing real is read, listed or named. No process, user, host name or path of
## this machine; every PID, user and command here is game data.

const TuningScript = preload("res://scripts/hud/spectate_top_tuning.gd")
const TopLedger = preload("res://scripts/hud/top_ledger.gd")
const Palette = preload("res://scripts/palette.gd")
const DEFAULT_TUNING_PATH := "res://resources/spectate_top.tres"

const HEADER := "top - %s up %s, %d %s, load average: %s, %s, %s"
const TASKS := "Tasks: %d total, %d running, %d stopped, %d zombie"
const COLUMNS := "%5s %-8s %1s %5s %5s %9s %3s %3s %s"
const TITLES := ["PID", "USER", "S", "%CPU", "RES", "TIME+", "K", "D", "COMMAND"]
const USER := "user"
const ROOT := "root"
const RUNNING := "R"
const ZOMBIE := "Z"
const STOPPED := "T"
const UNKNOWN := "-"
const DUMMY := "dummy-%d"
## The player's command alone when no display name is set: a fixed word.
const SOLO_NAME := "player"
## Alone, the player's key in the record (each dummy's is its command).
const YOU := "you"
## The player's health alone in practice, where nothing can hurt it: the combat tuning's full health
## (since C27b, with the daemons fighting back, its life's health).
const FULL_HEALTH := 100.0
const FONT := 13
const MARGIN := 18
## Below the status, round, net and combat lines and the net stats line.
const TOP := 140
const PAD := 8
const GAP := 6
## Room between the table and the death banner below it.
const BANNER_GAP := 8
const BG_ALPHA := 0.86
## A refresh comes due within this much of its time: float sums of frame steps.
const DUE_EPS := 0.0001

# Set these before the node enters the tree.
## SpectateTopTuning; null for resources/spectate_top.tres.
var tuning: Resource = null

## The player whose own row this is (alone: its root, SIGSTOP and name).
var player: Node = null
## This player's life alone (C27b); set through set_life.
var _life: Node = null
## The session beside the arena (scripts/net/net_session.gd): in a match, every number.
var session: Node = null
## The round HUD: the round clock, and the round whose damage %CPU shares out.
var round_hud: Control = null
## The HUD that owns this table (hud.gd): its top_held_back() hides the table while the
## round's summary, the menu, the multiplayer panel or a text box is up.
var hud: Node = null
## The combat HUD (scripts/net/combat_hud.gd), whose death banner moves below the table.
var combat_hud: Control = null

## Refreshes so far, and the rows as last refreshed, sorted: {pid, user, s, cpu, res, time,
## kills, deaths, command, me}, a number this game does not know being -1.
var refreshes := 0
var rows: Array = []

var _t: TuningScript
var _solo: TopLedger
var _dummies: Array = []
var _dummy_keys := {}
var _dummy_health := {}
var _left := 0.0
var _shown := false
## The damage each process had dealt when this round started (or when its numbers first
## came, in a match joined mid-round), to share out the round's.
var _base := {}
var _base_round := -1
var _base_source := ""
var _panel: PanelContainer
var _header: Label
var _tasks: Label
var _titles: Label
var _row_labels: Array[Label] = []
var _plain: StyleBoxEmpty
var _own: StyleBoxFlat


static func usable_tuning(candidate: Resource) -> TuningScript:
	if candidate is TuningScript:
		var issues: PackedStringArray = candidate.problems()
		if issues.is_empty():
			return candidate
		for issue in issues:
			push_warning("spectate top tuning: " + issue + "; using the shipped tuning instead")
	var shipped = load(DEFAULT_TUNING_PATH)
	if shipped is TuningScript and shipped.problems().is_empty():
		return shipped
	return TuningScript.new()


func _ready() -> void:
	_t = usable_tuning(tuning)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_solo = TopLedger.new()
	_solo.join(YOU)
	_build()


func tuning_in_use() -> TuningScript:
	return _t


## The arena's dummies, alone the table's daemons: "dummy-1" and on, joined in this order
## after the player.
func set_targets(targets: Array) -> void:
	for dummy in targets:
		if not is_instance_valid(dummy) or _dummy_keys.has(dummy.get_instance_id()):
			continue
		var key := DUMMY % (_dummies.size() + 1)
		_dummies.append(dummy)
		_dummy_keys[dummy.get_instance_id()] = key
		_dummy_health[key] = _health_of(dummy)
		_solo.join(key)
		if dummy.has_signal("downed"):
			dummy.connect("downed", _on_dummy_downed)
		if dummy.has_signal("respawned"):
			dummy.connect("respawned", _on_dummy_respawned)


## This player's life alone (C27b): its health is its RES, and the daemons' hits and kills on it
## are counted as theirs (damage dealt, a kill), its deaths as its own.
func set_life(l: Node) -> void:
	_life = l
	if l == null:
		return
	for pair in [["hurt", _on_life_hurt], ["died", _on_life_died], ["respawned", _on_life_respawned]]:
		if l.has_signal(pair[0]) and not l.is_connected(pair[0], pair[1]):
			l.connect(pair[0], pair[1])


func _on_life_hurt(amount: float, _health: float, by: Node) -> void:
	var key: String = _dummy_keys.get(by.get_instance_id(), "") if by != null and is_instance_valid(by) else ""
	if key != "":
		_solo.hit(key, YOU, amount)


func _on_life_died(_cause: String) -> void:
	var by: Node = _life.killer if _life != null else null
	var key: String = _dummy_keys.get(by.get_instance_id(), "") if by != null and is_instance_valid(by) else ""
	_solo.kill(key if key != "" else YOU, YOU)


func _on_life_respawned() -> void:
	_solo.respawn(YOU)


## True while the table is on the screen.
func is_showing() -> bool:
	return _panel.visible


## The table as shown: the header, the tasks line, the column titles and each row, or empty
## while it is hidden.
func lines() -> PackedStringArray:
	var out := PackedStringArray()
	if not _panel.visible:
		return out
	out.append_array([_header.text, _tasks.text, _titles.text])
	for label in _row_labels:
		if label.visible:
			out.append(label.text)
	return out


## Which shown row is this player's own (0 for the first), or -1.
func own_row() -> int:
	for i in _row_labels.size():
		if _row_labels[i].visible and _row_labels[i].get_theme_stylebox("normal") == _own:
			return i
	return -1


## The colour of the shown row `i`'s text.
func row_color(i: int) -> Color:
	return _row_labels[i].get_theme_color("font_color")


## The table's rectangle on the screen.
func panel_rect() -> Rect2:
	return _panel.get_global_rect()


## Where the table ends, from the screen's top, as laid out for its text now.
func bottom() -> float:
	return TOP + _panel.get_combined_minimum_size().y


func _physics_process(delta: float) -> void:
	# Alone, the arena's record runs on the game's own time: every bit of health the
	# dummies lose is the player's damage (nothing else hurts them).
	_solo.tick(delta)
	for dummy in _dummies:
		if is_instance_valid(dummy):
			_note_health(dummy)


func _process(delta: float) -> void:
	_take_round_base()
	var show := _wanted() and not _held_back()
	if show and not _shown:
		_left = _t.refresh_s
		_refresh()
	elif show:
		_left -= delta / maxf(Engine.time_scale, 0.01)  # real time, even under SIGSTOP alone
		if _left <= DUE_EPS:
			_refresh()
			_left += _t.refresh_s
			if _left <= DUE_EPS:
				_left = _t.refresh_s
	_shown = show
	_panel.visible = show
	if combat_hud != null and is_instance_valid(combat_hud) and combat_hud.has_method("place_banner"):
		combat_hud.place_banner(bottom() + BANNER_GAP if show else -1.0)


## Tab held, or this player derezzed in a match.
func _wanted() -> bool:
	if InputMap.has_action("show_top") and Input.is_action_pressed("show_top"):
		return true
	return _online() and session.dead.get(session.my_id, false)


func _held_back() -> bool:
	if hud != null and is_instance_valid(hud) and hud.has_method("top_held_back"):
		return hud.top_held_back()
	return round_hud != null and is_instance_valid(round_hud) and round_hud.showing_summary()


func _online() -> bool:
	return session != null and is_instance_valid(session) and session.has_method("is_online") and session.is_online()


func _refresh() -> void:
	refreshes += 1
	var numbers: Dictionary = session.top_numbers() if _online() else {}
	rows = _match_rows(numbers) if _online() else _solo_rows()
	rows.sort_custom(_before)
	var counts := {RUNNING: 0, STOPPED: 0, ZOMBIE: 0}
	for row in rows:
		counts[row["s"]] += 1
	var users: int = session.players.size() if _online() else 1
	var load := _load_text(numbers)
	var up := clock(numbers.get("uptime", -1.0)) if _online() else clock(_solo.uptime)
	_header.text = HEADER % [_round_clock(), up, users, "user" if users == 1 else "users", load[0], load[1], load[2]]
	_tasks.text = TASKS % [rows.size(), counts[RUNNING], counts[STOPPED], counts[ZOMBIE]]
	var shown := pick(rows, _t.max_rows)
	for i in _row_labels.size():
		var label := _row_labels[i]
		label.visible = i < shown.size()
		if not label.visible:
			continue
		var row: Dictionary = shown[i]
		label.text = row_text(row)
		label.add_theme_stylebox_override("normal", _own if row["me"] else _plain)
		label.add_theme_color_override("font_color", Palette.VOID if row["me"] else _state_color(row))


func _match_rows(numbers: Dictionary) -> Array:
	var known: Dictionary = numbers.get("rows", {})
	var shares := _shares(_dealt_of(known, session.players))  # a player gone since: not in the share
	var out := []
	for id in session.players:
		var n: Dictionary = known.get(id, {})
		out.append({
			"pid": n.get("pid", -1),
			"user": ROOT if session.root_left.get(id, 0.0) > 0.0 else USER,
			"s": ZOMBIE if session.dead.get(id, false) else (STOPPED if session.stopped_known(id) else RUNNING),
			"cpu": shares.get(id, -1.0),
			"res": ceili(maxf(session.health[id], 0.0)) if session.health.has(id) else -1,
			"time": n.get("alive_s", -1.0),
			"kills": n.get("kills", -1),
			"deaths": n.get("deaths", -1),
			"command": session.players[id].get("name", UNKNOWN),
			"me": id == session.my_id,
		})
	return out


func _solo_rows() -> Array:
	var shares := _shares(_solo_dealt())
	var out := []
	var you: Dictionary = _solo.rows[YOU]
	var sudo = player.get("sudo") if player != null and is_instance_valid(player) else null
	var stop = player.get("sigstop") if player != null and is_instance_valid(player) else null
	var alive: bool = player == null or not is_instance_valid(player) or player.get("alive") != false
	out.append({
		"pid": _t.pid_base + you["order"],
		"user": ROOT if sudo != null and sudo.state != null and sudo.is_root() else USER,
		"s": ZOMBIE if not alive else (STOPPED if stop != null and stop.is_on() else RUNNING),
		"cpu": shares.get(YOU, 0.0),
		"res": ceili(_life.health() if _life != null and is_instance_valid(_life) and _life.shown() else _full_health()),
		"time": you["alive_s"],
		"kills": you["kills"],
		"deaths": you["deaths"],
		"command": _solo_name(),
		"me": true,
	})
	for dummy in _dummies:
		if not is_instance_valid(dummy):
			continue
		var key: String = _dummy_keys[dummy.get_instance_id()]
		var d: Dictionary = _solo.rows[key]
		out.append({
			"pid": _t.pid_base + d["order"],
			"user": USER,
			"s": RUNNING if dummy.is_alive() else ZOMBIE,
			"cpu": shares.get(key, 0.0),
			"res": ceili(_health_of(dummy)),
			"time": d["alive_s"],
			"kills": d["kills"],
			"deaths": d["deaths"],
			"command": key,
			"me": false,
		})
	return out


## Each process's share of the damage dealt this round, in percent: the round's part of what
## it has dealt, over all of theirs; every share 0 while nobody has dealt any.
func _shares(dealt: Dictionary) -> Dictionary:
	var part := {}
	var total := 0.0
	for key in dealt:
		var d := maxf(float(dealt[key]) - float(_base.get(key, 0.0)), 0.0)
		part[key] = d
		total += d
	for key in part:
		part[key] = 100.0 * part[key] / total if total > 0.0 else 0.0
	return part


## At a new round, or when the source of the numbers changes (alone to a match and back),
## what each process had dealt is noted, so the round's share starts from there. In a match
## it waits for the host's first numbers.
func _take_round_base() -> void:
	var number := 0
	if round_hud != null and is_instance_valid(round_hud) and round_hud.get("stats") != null:
		number = round_hud.stats.round_number
	var source := "match" if _online() else "solo"
	if number == _base_round and source == _base_source:
		return
	var dealt := _dealt_of(session.top_numbers().get("rows", {})) if source == "match" else _solo_dealt()
	if source == "match" and dealt.is_empty():
		return
	_base = dealt
	_base_round = number
	_base_source = source


## Each process's damage dealt in `known`; with `only`, just the ones in it.
func _dealt_of(known: Dictionary, only: Dictionary = {}) -> Dictionary:
	var out := {}
	for id in known:
		if only.is_empty() or only.has(id):
			out[id] = known[id]["dealt"]
	return out


func _solo_dealt() -> Dictionary:
	var out := {}
	for key in _solo.rows:
		out[key] = _solo.rows[key]["dealt"]
	return out


## The three load numbers as top prints them, or "-" before the host's numbers come.
func _load_text(numbers: Dictionary) -> PackedStringArray:
	var counts = numbers.get("load") if _online() else _solo.load_counts(_t.windows())
	var out := PackedStringArray()
	for i in 3:
		out.append("%.2f" % counts[i] if counts is PackedInt32Array and counts.size() == 3 else UNKNOWN)
	return out


func _round_clock() -> String:
	if round_hud == null or not is_instance_valid(round_hud):
		return UNKNOWN
	var left := maxi(ceili(round_hud.seconds_left()), 0)
	return "%d:%02d" % [left / 60, left % 60]


func _full_health() -> float:
	if session != null and is_instance_valid(session) and session.has_method("combat_tuning_in_use"):
		return session.combat_tuning_in_use().max_health
	return FULL_HEALTH


func _solo_name() -> String:
	if session != null and is_instance_valid(session) and session.has_method("display_label") and session.display_label() != "":
		return session.display_label()
	return SOLO_NAME


func _state_color(row: Dictionary) -> Color:
	if row["s"] == ZOMBIE:
		return Palette.HOSTILE_AMBER
	if row["user"] == ROOT:
		return Palette.HOSTILE_RED
	if row["s"] == STOPPED:
		return Palette.ICE
	return Palette.MINT


func _on_dummy_downed(dummy: Node3D) -> void:
	var key := _note_health(dummy)  # the killing hit's damage first
	if key != "":
		_solo.kill(YOU, key)  # alone nothing but the player derezzes a daemon


func _on_dummy_respawned(dummy: Node3D) -> void:
	var key := _note_health(dummy)
	if key != "":
		_solo.respawn(key)


## Whatever health `dummy` lost since it was last looked at is the player's damage; a gain (a
## respawn, a new round) is only noted. Returns its key, or "".
func _note_health(dummy: Node) -> String:
	var key: String = _dummy_keys.get(dummy.get_instance_id(), "")
	if key == "":
		return ""
	var now := _health_of(dummy)
	if now < _dummy_health[key]:
		_solo.hit(YOU, key, _dummy_health[key] - now)
	_dummy_health[key] = now
	return key


static func _health_of(dummy: Node) -> float:
	return maxf(dummy.health(), 0.0) if dummy.has_method("health") else 0.0


## top's order: the most kills first, then the biggest share of the damage, then the lowest
## PID (a PID not yet known last, then by command).
static func _before(a: Dictionary, b: Dictionary) -> bool:
	if a["kills"] != b["kills"]:
		return a["kills"] > b["kills"]
	if a["cpu"] != b["cpu"]:
		return a["cpu"] > b["cpu"]
	var pa: int = a["pid"] if a["pid"] >= 0 else TuningScript.PID_LAST + 1
	var pb: int = b["pid"] if b["pid"] >= 0 else TuningScript.PID_LAST + 1
	if pa != pb:
		return pa < pb
	return a["command"] < b["command"]


## The first `count` of `sorted`, this player's own row always among them: past the last
## place, it takes that place.
static func pick(sorted: Array, count: int) -> Array:
	var out := sorted.slice(0, count)
	for row in sorted.slice(count):
		if row["me"] and not out.is_empty():
			out[out.size() - 1] = row
	return out


## One row in top's columns; "-" for a number this game does not know.
static func row_text(row: Dictionary) -> String:
	var cpu: float = row["cpu"]
	return COLUMNS % [_count(row["pid"]), row["user"], row["s"], "%.1f" % cpu if cpu >= 0.0 else UNKNOWN, _count(row["res"]), time_plus(row["time"]), _count(row["kills"]), _count(row["deaths"]), row["command"]]


static func titles_text() -> String:
	return COLUMNS % TITLES


## TIME+ as top prints it: minutes, seconds and hundredths, "1:05.25"; "-" when unknown.
static func time_plus(seconds: float) -> String:
	if seconds < 0.0 or not is_finite(seconds):
		return UNKNOWN
	var hundredths := floori(seconds * 100.0 + DUE_EPS)
	return "%d:%02d.%02d" % [hundredths / 6000, (hundredths / 100) % 60, hundredths % 100]


## A span of play as "m:ss", or "h:mm:ss" past an hour; "-" when unknown.
static func clock(seconds: float) -> String:
	if seconds < 0.0 or not is_finite(seconds):
		return UNKNOWN
	var whole := floori(seconds + DUE_EPS)
	if whole >= 3600:
		return "%d:%02d:%02d" % [whole / 3600, (whole / 60) % 60, whole % 60]
	return "%d:%02d" % [whole / 60, whole % 60]


static func _count(n: int) -> String:
	return str(n) if n >= 0 else UNKNOWN


func _build() -> void:
	_plain = StyleBoxEmpty.new()
	_own = StyleBoxFlat.new()
	_own.bg_color = Palette.MINT
	_panel = PanelContainer.new()
	_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style := StyleBoxFlat.new()
	style.bg_color = Color(Palette.VOID, BG_ALPHA)
	style.border_color = Palette.TEAL
	style.set_border_width_all(1)
	style.set_content_margin_all(PAD)
	_panel.add_theme_stylebox_override("panel", style)
	add_child(_panel)
	# Across the whole width, under the top lines, as tall as its rows.
	_panel.anchor_left = 0.0
	_panel.anchor_right = 1.0
	_panel.offset_left = MARGIN
	_panel.offset_right = -MARGIN
	_panel.offset_top = TOP
	_panel.offset_bottom = TOP
	var stack := VBoxContainer.new()
	stack.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stack.add_theme_constant_override("separation", 0)
	_panel.add_child(stack)
	_header = _label(stack, Palette.TEAL)
	_tasks = _label(stack, Palette.TEAL)
	var gap := Control.new()
	gap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	gap.custom_minimum_size = Vector2(0, GAP)
	stack.add_child(gap)
	_titles = _label(stack, Palette.TEAL)
	_titles.text = titles_text()
	for i in _t.max_rows:
		var label := _label(stack, Palette.MINT)
		label.visible = false
		_row_labels.append(label)
	_panel.visible = false


func _label(parent: Control, color: Color) -> Label:
	var label := Label.new()
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_override("font", Palette.mono_font())
	label.add_theme_font_size_override("font_size", FONT)
	label.add_theme_color_override("font_color", color)
	label.add_theme_stylebox_override("normal", StyleBoxEmpty.new())
	parent.add_child(label)
	return label
