class_name MissionDef
extends Resource
## One mission of the campaign (C35, PRD 5.6, docs/STORY.md section 6), as data: a .tres file each in
## resources/missions/, read by MissionBook (scripts/missions/mission_book.gd) and played by the arena's
## MissionRunner (scripts/missions/mission_runner.gd). No mission is a branch in code: everything one does is here.
##
## Objectives run one after another, each a dictionary:
##   {"id": "vent", "kind": "kill", "text": "SIGTERM the rogue.d", "daemon": "rogue", "count": 3}
##   kinds:  kill     daemon "rogue", "zombie", "swarm" or "any"; count
##           reach    at (Vector3, the arena's space, or in ruins a point's name); radius (m, default REACH_RADIUS);
##                    label (the beacon's word)
##           log      log: the id of one of `logs`, picked up
##           survive  seconds alive, the mission's clock running
##   every one may add "gives": weapon ids handed over in the mission as it is done (the loadout grows).
## Where it is played (C36): `ruins` names a ruins district (scripts/ruins/ruins_book.gd) the arena is stood in for it,
## and there a reach's or a log's "at" may name one of the district's points ("exit", "log_0") instead of a place;
## "" plays it on the arena itself.
## Terminal logs, each {"id", "name" (the file it reads as), "text", "at" (Vector3, or a point's name)}: standing in the arena from the
## start, picked up by walking through, read on the screen. Lines, each {"on": trigger, "who": "ai", "auditor" or
## "tilde", "text"}: your AI's story lines go to the guide panel as "your AI" (never through the player's own AI, never
## sent anywhere: STORY.md section 4), the Auditor's to the audit log, and `~`'s to a terminal of its own. Transitions, each {"on": trigger, "to": register}:
## the place shifting register. Triggers: "start", "complete", "fail", "begin:<objective>", "done:<objective>",
## "log:<log>", "at:<seconds into the mission>".
##
## The weapons (STORY.md, pick 4): `loadout` is what is in hand as it starts, `grants` what it hands out for keeps
## when it is done (the C33 unlocks' campaign record, scripts/unlocks/progress.gd), so by mission 6 all thirteen
## are held. Arena play and matches keep the whole arsenal from the start, whatever is held.
##
## Its own daemons and set pieces (C37). Waves, each {"id", "kind" ("rogue", "zombie" or "swarm"), "count", "from"
## (the ids of the vents they climb out of, in turn), "on" (a trigger) or "after" (a wave's id: when no more than
## "left" of that wave still stand, default 0), "every" (seconds between two climbing out, default WAVE_EVERY_S),
## "elites" (how many of them are their type's elite, default 0), "health" (each one's, default the arena's: one hit;
## an elite at least the daemon tuning's elite_health)}. With any waves, the arena's own four are gone while
## it runs: every daemon in it is one of its waves', each hunts the player as it climbs out and never gives up, and
## none comes back once down, so its daemons are finite (no more than the waves' counts). Props, each {"id", "kind"}:
##   vent      "at": a spawn vent in the floor, leaking green code; waves climb out of them
##   ice_wall  "at", "yaw" (degrees), "span" (Vector2: width, height): a white ICE wall it cannot break
##   breach    its ruins' breach (the district must have one): "opens", the trigger that splits the grid open over it,
##             and "lights", the trigger that lights the remnant's sign in the pocket below
## Waves add two triggers: "wave:<id>" (its first daemon climbing out) and "cleared:<id>" (its last one down), and a
## kill objective may count only some waves' daemons: "of", their ids (the pack, not a straggler from before it).
## An objective may add "hint": a line under it on the panel (a key it teaches, a way to play it).
##
## Abilities (C37): `abilities` are what it hands over beside its weapons (ids, ABILITIES), and they are enforced in a
## mission: one that this mission and the ones before it in the campaign have not handed over cannot be used in it
## (allowed_abilities()). Arena play and matches keep everything.
##
## Fiction only: nothing here reads, names or touches anything on the player's machine (STORY.md, pick 8).

## The registers (STORY.md section 1); "all" is the finale's three at once.
const REGISTERS := ["tron", "matrix", "cyberpunk", "all"]
const KINDS := ["kill", "reach", "log", "survive"]
const DAEMONS := ["rogue", "zombie", "swarm", "any"]
## Who says a line: your AI (the guide panel), the Auditor (the audit log), or `~` (its own terminal, from mission 3 on).
const WHO := ["ai", "auditor", "tilde"]
## A reach objective's radius when its data names none, in metres.
const REACH_RADIUS := 2.5
## The longest line or objective text the HUD shows whole.
const TEXT_LAST := 120
## The longest log the reader shows.
const LOG_LAST := 600
## The longest objective hint the panel shows whole (C37).
const HINT_LAST := 46
const ID_CHARS := "abcdefghijklmnopqrstuvwxyz0123456789_"
## The abilities a mission may hand over (C37), by id, with the words the menus show.
const ABILITIES := {"code_rain_vision": "code-rain vision", "breakers": "ICEbreakers", "sudo": "sudo and root#", "sigstop": "SIGSTOP bullet time"}
## The daemon types a wave may be, the props' kinds, and a wave's numbers.
const WAVE_KINDS := ["rogue", "zombie", "swarm"]
const PROP_KINDS := ["vent", "ice_wall", "breach"]
const WAVE_EVERY_S := 0.6
const WAVE_LAST := 12

## Its own name, a file's worth: "login".
@export var id := ""
## Its place in the campaign, 1 to 7; 0 for one that is not in it (the test range).
@export var order := 0
## The command it is called: "login", "while true", "sudo !!".
@export var title := ""
## Where it is (STORY.md section 1) and, after a transition, where it ends.
@export var register := "tron"
## The goal in one line, shown once it is open.
@export var goal := ""
## The weapons in hand as it starts (their WeaponDef ids).
@export var loadout := PackedStringArray()
## The weapons it hands out for keeps when it is done.
@export var grants := PackedStringArray()
## What else it hands over (ids, ABILITIES): shown on the menus, and enforced in a mission since C37.
@export var abilities := PackedStringArray()
@export var objectives: Array = []
@export var logs: Array = []
@export var lines: Array = []
@export var transitions: Array = []
## Its own daemons, in waves, and its set pieces (C37).
@export var waves: Array = []
@export var props: Array = []
## Seconds the place holds after its last objective before the end screen comes up (C37).
@export var end_hold_s := 1.5
## Each objective done is a checkpoint (C37): the player's health back to full (the scheduler grants a fresh timeslice).
@export var restores := false
## Whether ICE (I1 to I3) stands in it; off, the system's own defences stand down while it runs.
@export var ice := false
## The ruins district it is played in (a RuinsSet id, C36), or "" for the arena itself.
@export var ruins := ""
## Its own fail rule: seconds of its clock before the timeslice runs out (0: none). Death always fails it.
@export var fail_time_s := 0.0
## The mission after it, or "".
@export var next := ""
## Its content exists and it can be started. A skeleton (a later chunk builds it) is listed but not started.
@export var playable := false
## A stand-in, playable now (mission 1 in its ruins since C36), for what a later chunk builds (C37 builds mission 1 for real).
@export var draft := false
## Never listed (the test range): started by the tests, or with --demo and --mission=<id>.
@export var hidden := false


## What is wrong with it, against the shipped weapons' ids; empty when it is good.
func problems(weapon_ids: PackedStringArray) -> PackedStringArray:
	var out := PackedStringArray()
	if not _id_ok(id):
		out.append("id \"%s\": lower case letters, digits and _ only" % id)
	if order < 0 or order > 99 or (order == 0 and not hidden):
		out.append("%s: order %d (1 and up, or 0 for a hidden one)" % [id, order])
	if title.strip_edges() == "" or title.length() > 24:
		out.append("%s: a title of 1 to 24 characters" % id)
	if not REGISTERS.has(register):
		out.append("%s: register \"%s\"" % [id, register])
	if goal.strip_edges() == "" or goal.length() > TEXT_LAST:
		out.append("%s: a goal of 1 to %d characters" % [id, TEXT_LAST])
	if loadout.is_empty():
		out.append("%s: an empty loadout" % id)
	for w in loadout:
		if not weapon_ids.has(w):
			out.append("%s: loadout weapon \"%s\"" % [id, w])
	var held := loadout.duplicate()
	var objective_ids := PackedStringArray()
	for o in objectives:
		out.append_array(_objective_problems(o, weapon_ids, objective_ids))
		if o is Dictionary:
			for w in o.get("gives", []):
				held.append(w)
	var log_ids := PackedStringArray()
	for entry in logs:
		if not (entry is Dictionary) or not _id_ok(str(entry.get("id", ""))) or log_ids.has(str(entry.get("id"))):
			out.append("%s: a log without a good, unique id" % id)
			continue
		log_ids.append(entry["id"])
		if not (entry.get("name") is String) or entry["name"].strip_edges() == "" or entry["name"].length() > 48:
			out.append("%s: log %s has no name" % [id, entry["id"]])
		if not (entry.get("text") is String) or entry["text"].strip_edges() == "" or entry["text"].length() > LOG_LAST:
			out.append("%s: log %s needs 1 to %d characters of text" % [id, entry["id"], LOG_LAST])
		if not _place_ok(entry.get("at")):
			out.append("%s: log %s needs \"at\", a Vector3 or a point of its ruins" % [id, entry["id"]])
	for o in objectives:
		if o is Dictionary and o.get("kind") == "log" and not log_ids.has(str(o.get("log", ""))):
			out.append("%s: objective %s picks up log \"%s\", which is not in its logs" % [id, o.get("id"), o.get("log")])
	var wave_ids := wave_ids()
	out.append_array(_prop_problems())
	out.append_array(_wave_problems(objective_ids, log_ids))
	for a in abilities:
		if not ABILITIES.has(a):
			out.append("%s: ability \"%s\" (one of %s)" % [id, a, ", ".join(ABILITIES.keys())])
	for line in lines:
		if not (line is Dictionary):
			out.append("%s: a line that is not a dictionary" % id)
			continue
		if not trigger_ok(str(line.get("on", "")), objective_ids, log_ids, wave_ids):
			out.append("%s: line trigger \"%s\"" % [id, line.get("on")])
		if not WHO.has(line.get("who")):
			out.append("%s: line by \"%s\" (ai, auditor or tilde)" % [id, line.get("who")])
		if not (line.get("text") is String) or line["text"].strip_edges() == "" or line["text"].length() > TEXT_LAST:
			out.append("%s: a line needs 1 to %d characters" % [id, TEXT_LAST])
	for shift in transitions:
		if not (shift is Dictionary) or not trigger_ok(str(shift.get("on", "")), objective_ids, log_ids, wave_ids) or not REGISTERS.has(shift.get("to")):
			out.append("%s: a transition needs a good trigger and a register" % id)
	for w in grants:
		if not weapon_ids.has(w):
			out.append("%s: grants weapon \"%s\"" % [id, w])
		elif not held.has(w):
			out.append("%s: grants %s, never in hand in it" % [id, w])
	if fail_time_s < 0.0 or fail_time_s > 3600.0:
		out.append("%s: fail_time_s %.1f" % [id, fail_time_s])
	if end_hold_s < 0.0 or end_hold_s > 15.0:
		out.append("%s: end_hold_s %.1f (0 to 15)" % [id, end_hold_s])
	if playable and objectives.is_empty():
		out.append("%s: playable with no objectives" % id)
	if draft and not playable:
		out.append("%s: a draft is a playable stand-in" % id)
	if next != "" and (next == id or not _id_ok(next)):
		out.append("%s: next \"%s\"" % [id, next])
	if ruins != "":
		if RuinsBook.of(ruins) == null:
			out.append("%s: ruins \"%s\" is not a set" % [id, ruins])
		if ice:
			out.append("%s: ICE in ruins (its walls and nodes stand where the arena's level is: not yet)" % id)
	return out


## True for a good "at": a place, or in ruins the name of one of its points.
func _place_ok(at: Variant) -> bool:
	if at is Vector3:
		return true
	if not (at is String) or ruins == "":
		return false
	var s := RuinsBook.of(ruins)
	return s != null and RuinsLayout.of(s).points.has(at)


func _objective_problems(o: Variant, weapon_ids: PackedStringArray, seen: PackedStringArray) -> PackedStringArray:
	var out := PackedStringArray()
	if not (o is Dictionary):
		return PackedStringArray(["%s: an objective that is not a dictionary" % id])
	var oid := str(o.get("id", ""))
	if not _id_ok(oid) or seen.has(oid):
		out.append("%s: an objective without a good, unique id" % id)
	seen.append(oid)
	if not (o.get("text") is String) or o["text"].strip_edges() == "" or o["text"].length() > TEXT_LAST:
		out.append("%s: objective %s needs 1 to %d characters of text" % [id, oid, TEXT_LAST])
	var hint = o.get("hint", "")
	if not (hint is String) or hint.length() > HINT_LAST:
		out.append("%s: objective %s hint: text of up to %d characters" % [id, oid, HINT_LAST])
	match o.get("kind"):
		"kill":
			if not DAEMONS.has(o.get("daemon")):
				out.append("%s: objective %s kills daemon \"%s\"" % [id, oid, o.get("daemon")])
			if not (o.get("count") is int) or o["count"] < 1 or o["count"] > 99:
				out.append("%s: objective %s needs a count of 1 to 99" % [id, oid])
		"reach":
			if not _place_ok(o.get("at")):
				out.append("%s: objective %s needs \"at\", a Vector3 or a point of its ruins" % [id, oid])
			var r = o.get("radius", REACH_RADIUS)
			if not (r is float or r is int) or r < 0.5 or r > 20.0:
				out.append("%s: objective %s radius" % [id, oid])
		"log":
			pass  # checked against the logs once they are read
		"survive":
			var s = o.get("seconds")
			if not (s is float or s is int) or s < 1.0 or s > 900.0:
				out.append("%s: objective %s needs 1 to 900 seconds" % [id, oid])
		_:
			out.append("%s: objective %s kind \"%s\"" % [id, oid, o.get("kind")])
	for w in o.get("gives", []):
		if not weapon_ids.has(w):
			out.append("%s: objective %s gives weapon \"%s\"" % [id, oid, w])
	return out


## True for a trigger that names something it has: "start", "complete", "fail", "begin:<objective>",
## "done:<objective>", "log:<log>", "at:<seconds>", and (C37) "wave:<wave>" and "cleared:<wave>".
static func trigger_ok(trigger: String, objective_ids: PackedStringArray, log_ids: PackedStringArray, wave_ids: PackedStringArray = PackedStringArray()) -> bool:
	if trigger in ["start", "complete", "fail"]:
		return true
	var parts := trigger.split(":", false, 1)
	if parts.size() != 2:
		return false
	match parts[0]:
		"begin", "done":
			return objective_ids.has(parts[1])
		"log":
			return log_ids.has(parts[1])
		"at":
			return parts[1].is_valid_float() and float(parts[1]) >= 0.0
		"wave", "cleared":
			return wave_ids.has(parts[1])
	return false


## Its waves' ids, in order (C37).
func wave_ids() -> PackedStringArray:
	var out := PackedStringArray()
	for w in waves:
		if w is Dictionary:
			out.append(str(w.get("id", "")))
	return out


## Its props' ids of kind `kind` ("" every kind), in order (C37).
func prop_ids(kind: String = "") -> PackedStringArray:
	var out := PackedStringArray()
	for p in props:
		if p is Dictionary and (kind == "" or p.get("kind") == kind):
			out.append(str(p.get("id", "")))
	return out


## Its prop with id `prop_id`, or {} (C37).
func prop_of(prop_id: String) -> Dictionary:
	for p in props:
		if p is Dictionary and p.get("id") == prop_id:
			return p
	return {}


## How many daemons its waves bring, of type `kind` ("" every type): the most it can ever have (C37).
func daemons_total(kind: String = "") -> int:
	var n := 0
	for w in waves:
		if w is Dictionary and (kind == "" or w.get("kind") == kind) and w.get("count") is int:
			n += int(w["count"])
	return n


## The abilities this mission may use (C37): what it and every campaign mission before it hand over. The test range
## (order 0) only its own.
func allowed_abilities() -> PackedStringArray:
	var out := abilities.duplicate()
	if order <= 0:
		return out
	for def in MissionBook.campaign():
		if def.order < order:
			for a in def.abilities:
				if not out.has(a):
					out.append(a)
	return out


func _prop_problems() -> PackedStringArray:
	var out := PackedStringArray()
	var seen := PackedStringArray()
	for p in props:
		if not (p is Dictionary) or not _id_ok(str(p.get("id", ""))) or seen.has(str(p.get("id"))):
			out.append("%s: a prop without a good, unique id" % id)
			continue
		seen.append(p["id"])
		match p.get("kind"):
			"vent":
				if not _place_ok(p.get("at")):
					out.append("%s: vent %s needs \"at\", a Vector3 or a point of its ruins" % [id, p["id"]])
			"ice_wall":
				if not _place_ok(p.get("at")):
					out.append("%s: ICE wall %s needs \"at\", a Vector3 or a point of its ruins" % [id, p["id"]])
				var span = p.get("span", Vector2(3.0, 3.5))
				if not (span is Vector2) or span.x < 1.0 or span.x > 12.0 or span.y < 1.5 or span.y > 8.0:
					out.append("%s: ICE wall %s span (1 to 12 wide, 1.5 to 8 tall)" % [id, p["id"]])
			"breach":
				var s := RuinsBook.of(ruins) if ruins != "" else null
				if s == null or s.breach == "":
					out.append("%s: breach %s, but its ruins have none" % [id, p["id"]])
				for key in ["opens", "lights"]:
					var t := str(p.get(key, ""))
					if t != "" and not trigger_ok(t, _objective_ids(), _log_ids(), wave_ids()):
						out.append("%s: breach %s %s trigger \"%s\"" % [id, p["id"], key, t])
			_:
				out.append("%s: prop %s kind \"%s\" (%s)" % [id, p["id"], p.get("kind"), ", ".join(PROP_KINDS)])
	return out


func _wave_problems(objective_ids: PackedStringArray, log_ids: PackedStringArray) -> PackedStringArray:
	var out := PackedStringArray()
	var ids := wave_ids()
	var vents := prop_ids("vent")
	var seen := PackedStringArray()
	for w in waves:
		if not (w is Dictionary) or not _id_ok(str(w.get("id", ""))) or seen.has(str(w.get("id"))):
			out.append("%s: a wave without a good, unique id" % id)
			continue
		var wid: String = w["id"]
		seen.append(wid)
		if not WAVE_KINDS.has(w.get("kind")):
			out.append("%s: wave %s kind \"%s\" (rogue, zombie or swarm)" % [id, wid, w.get("kind")])
		var count = w.get("count")
		if not (count is int) or count < 1 or count > WAVE_LAST:
			out.append("%s: wave %s needs a count of 1 to %d" % [id, wid, WAVE_LAST])
		var elites = w.get("elites", 0)
		if not (elites is int) or elites < 0 or (count is int and elites > count):
			out.append("%s: wave %s elites (0 to its count)" % [id, wid])
		var from = w.get("from", [])
		if not (from is Array) or from.is_empty():
			out.append("%s: wave %s needs \"from\": the vents it climbs out of" % [id, wid])
		else:
			for v in from:
				if not vents.has(str(v)):
					out.append("%s: wave %s climbs out of \"%s\", which is not one of its vents" % [id, wid, v])
		var every = w.get("every", WAVE_EVERY_S)
		if not (every is float or every is int) or every < 0.1 or every > 30.0:
			out.append("%s: wave %s every (0.1 to 30 seconds)" % [id, wid])
		var on := str(w.get("on", ""))
		var after := str(w.get("after", ""))
		if (on == "") == (after == ""):
			out.append("%s: wave %s needs one of \"on\" (a trigger) or \"after\" (a wave)" % [id, wid])
		elif on != "" and not trigger_ok(on, objective_ids, log_ids, ids):
			out.append("%s: wave %s trigger \"%s\"" % [id, wid, on])
		elif after != "" and (after == wid or not seen.has(after)):
			out.append("%s: wave %s comes after \"%s\", which is not a wave before it" % [id, wid, after])
		var left = w.get("left", 0)
		if not (left is int) or left < 0:
			out.append("%s: wave %s left (0 or more)" % [id, wid])
		var health = w.get("health", 1.0)
		if not (health is float or health is int) or health <= 0.0 or health > 1000.0:
			out.append("%s: wave %s health (above 0, up to 1000)" % [id, wid])
	for o in objectives:
		if not (o is Dictionary) or not o.has("of"):
			continue
		var of = o.get("of")
		var bring := 0
		if not (of is Array) or of.is_empty():
			out.append("%s: objective %s \"of\": the waves whose daemons it counts" % [id, o.get("id")])
			continue
		for wid in of:
			if not ids.has(str(wid)):
				out.append("%s: objective %s counts wave \"%s\", which it has not" % [id, o.get("id"), wid])
			for w in waves:
				if w is Dictionary and w.get("id") == str(wid) and w.get("count") is int:
					bring += int(w["count"])
		if o.get("count") is int and int(o["count"]) > bring:
			out.append("%s: objective %s wants %d, its waves bring %d" % [id, o.get("id"), o["count"], bring])
	# Every kill objective can be done with the daemons its waves bring (a mission with waves has no others).
	if not waves.is_empty():
		var want := {}
		for o in objectives:
			if o is Dictionary and o.get("kind") == "kill" and o.get("count") is int:
				var k := str(o.get("daemon"))
				want[k] = int(want.get(k, 0)) + int(o["count"])
		for k in want:
			var have := daemons_total("" if k == "any" else k)
			if want[k] > have:
				out.append("%s: its kill objectives want %d %s, its waves bring %d" % [id, want[k], k, have])
	return out


func _objective_ids() -> PackedStringArray:
	var out := PackedStringArray()
	for o in objectives:
		if o is Dictionary:
			out.append(str(o.get("id", "")))
	return out


func _log_ids() -> PackedStringArray:
	var out := PackedStringArray()
	for entry in logs:
		if entry is Dictionary:
			out.append(str(entry.get("id", "")))
	return out


## Every weapon that is ever in hand in it: the loadout and what its objectives give.
func carried_ever() -> PackedStringArray:
	var out := loadout.duplicate()
	for o in objectives:
		if o is Dictionary:
			for w in o.get("gives", []):
				if not out.has(w):
					out.append(w)
	return out


## Its log with id `log_id`, or {}.
func log_of(log_id: String) -> Dictionary:
	for entry in logs:
		if entry is Dictionary and entry.get("id") == log_id:
			return entry
	return {}


## Its number as the menu shows it: "01"; "00" for the test range.
func number() -> String:
	return "%02d" % order


static func _id_ok(text: String) -> bool:
	if text == "" or text.length() > 32:
		return false
	for c in text:
		if not ID_CHARS.contains(c):
			return false
	return true
