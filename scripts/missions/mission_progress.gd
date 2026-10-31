class_name MissionProgress
extends RefCounted
## The campaign's progress (C35): which missions are done and the best of each, kept in the [missions] section of
## the unlocks' save, user://progress.cfg, through the settings file's strict reader and atomic writer
## (scripts/settings/settings_file.gd), which keeps every other section as it was. The C33 sections ([progress],
## [feats], [unlocked], [loadout]) are never read or written here, and an old C33 save, with no [missions], loads
## unchanged: no mission done yet. One instance for the whole run (current()).
##   [missions]  format=1
##               done_<id>=true      a campaign mission finished
##               best_<id>=<s>       its fastest clear, in seconds of its clock
##               logs_<id>=<n>       the most of its terminal logs found in one clear
## A missing or damaged file, a section from another format, or a key that is not the right kind is no progress for
## it (nothing done), never a crash; the next save writes a good one. Only the campaign's own ids are kept.
##
## Finishing a mission (record()) hands out its weapons for keeps through the unlocks (Progress.grant_weapon(): the
## toast says so, and the loadout screen shows them). The test range is never recorded. Headless runs (the tests,
## check.sh) never read or write the player's file: there current() has no path, and a test sets `path` itself.

const SettingsFile = preload("res://scripts/settings/settings_file.gd")

const DEFAULT_PATH := "user://progress.cfg"
const SECTION := "missions"
const FORMAT := 1
## The longest clear kept, in seconds (a day): plenty, and inside the file's numbers.
const BEST_LAST := 86400.0

## Where load_file() reads and save() writes; "" (every headless run) means nowhere.
var path := ""
## How the last load went: "defaults" (no path), "missing", "unreadable", "loaded".
var last_load := "defaults"
## Mission id -> true; mission id -> best seconds; mission id -> most logs found.
var done := {}
var best_s := {}
var best_logs := {}

static var _current: MissionProgress


## The run's progress: the player's own file, loaded, unless headless (no path, nothing done).
static func current() -> MissionProgress:
	if _current == null:
		_current = MissionProgress.new()
		if DisplayServer.get_name() != "headless":
			_current.path = DEFAULT_PATH
			_current.load_file()
	return _current


func clear() -> void:
	done = {}
	best_s = {}
	best_logs = {}


## Reads `path`'s [missions]: each good value taken, anything else left out.
func load_file() -> String:
	clear()
	if path == "":
		last_load = "defaults"
		return last_load
	if not FileAccess.file_exists(path):
		last_load = "missing"
		return last_load
	var doc := SettingsFile.read(path)
	if doc.is_empty():
		last_load = "unreadable"
		return last_load
	var section = doc.get(SECTION)
	if section == null:
		last_load = "loaded"  # a good file with no [missions] yet (a C33 save): nothing done
		return last_load
	var format = section.get("format") if section is Dictionary else null
	if not (format is int) or format != FORMAT:
		last_load = "unreadable"
		return last_load
	for def in MissionBook.campaign():
		var finished = section.get("done_" + def.id)
		if finished is bool and finished:
			done[def.id] = true
		var s = section.get("best_" + def.id)
		if (s is float or s is int) and s > 0.0 and s <= BEST_LAST and done.has(def.id):
			best_s[def.id] = float(s)
		var n = section.get("logs_" + def.id)
		if n is int and n >= 0 and n <= def.logs.size() and done.has(def.id):
			best_logs[def.id] = n
	last_load = "loaded"
	return last_load


## Writes the [missions] section, keeping the rest of the file. False with no path or a failed write.
func save() -> bool:
	if path == "":
		return false
	var keys := {"format": FORMAT}
	for id in done:
		keys["done_" + id] = true
	for id in best_s:
		keys["best_" + id] = snappedf(best_s[id], 0.1)
	for id in best_logs:
		keys["logs_" + id] = best_logs[id]
	return SettingsFile.write_sections(path, {SECTION: keys})


func is_done(id: String) -> bool:
	return done.has(id)


## True when campaign mission `def` may be started: the first always, any other once the one before it is done.
func is_open(def: MissionDef) -> bool:
	if def == null or def.hidden:
		return false
	if def.order <= 1:
		return true
	var before := MissionBook.at(def.order - 1)
	return before != null and is_done(before.id)


## The first campaign mission open and not done (the one to play next), or null when every one is done.
func next_up() -> MissionDef:
	for def in MissionBook.campaign():
		if is_open(def) and not is_done(def.id):
			return def
	return null


## Mission `def` finished in `seconds` of its clock with `logs` of its logs found: kept (the test range never),
## saved, and its weapons handed out for keeps. {"first": its first clear, "best": a new best time, "granted":
## the weapons newly held}.
func record(def: MissionDef, seconds: float, logs: int) -> Dictionary:
	var out := {"first": false, "best": false, "granted": PackedStringArray()}
	if def == null or def.hidden or MissionBook.of(def.id) != def:
		return out
	out["first"] = not done.has(def.id)
	done[def.id] = true
	var s := clampf(seconds, 0.1, BEST_LAST)
	if not best_s.has(def.id) or s < best_s[def.id]:
		out["best"] = true
		best_s[def.id] = s
	best_logs[def.id] = maxi(int(best_logs.get(def.id, 0)), clampi(logs, 0, def.logs.size()))
	save()
	for w in def.grants:
		if Progress.current().grant_weapon(w):
			out["granted"].append(w)
	return out


## Wipes every mission (Reset progress, beside the unlocks' own wipe) and saves.
func reset() -> bool:
	clear()
	return save()
