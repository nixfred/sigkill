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
const ID_CHARS := "abcdefghijklmnopqrstuvwxyz0123456789_"

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
## What else it teaches, in words, for the menu: "code-rain vision". Shown, never enforced (C35).
@export var abilities := PackedStringArray()
@export var objectives: Array = []
@export var logs: Array = []
@export var lines: Array = []
@export var transitions: Array = []
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
## A stand-in, playable on today's arena, for what a later chunk builds (C37 builds mission 1 for real).
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
	for line in lines:
		if not (line is Dictionary):
			out.append("%s: a line that is not a dictionary" % id)
			continue
		if not trigger_ok(str(line.get("on", "")), objective_ids, log_ids):
			out.append("%s: line trigger \"%s\"" % [id, line.get("on")])
		if not WHO.has(line.get("who")):
			out.append("%s: line by \"%s\" (ai, auditor or tilde)" % [id, line.get("who")])
		if not (line.get("text") is String) or line["text"].strip_edges() == "" or line["text"].length() > TEXT_LAST:
			out.append("%s: a line needs 1 to %d characters" % [id, TEXT_LAST])
	for shift in transitions:
		if not (shift is Dictionary) or not trigger_ok(str(shift.get("on", "")), objective_ids, log_ids) or not REGISTERS.has(shift.get("to")):
			out.append("%s: a transition needs a good trigger and a register" % id)
	for w in grants:
		if not weapon_ids.has(w):
			out.append("%s: grants weapon \"%s\"" % [id, w])
		elif not held.has(w):
			out.append("%s: grants %s, never in hand in it" % [id, w])
	if fail_time_s < 0.0 or fail_time_s > 3600.0:
		out.append("%s: fail_time_s %.1f" % [id, fail_time_s])
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
## "done:<objective>", "log:<log>", "at:<seconds>".
static func trigger_ok(trigger: String, objective_ids: PackedStringArray, log_ids: PackedStringArray) -> bool:
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
	return false


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
