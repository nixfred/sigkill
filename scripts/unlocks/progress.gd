class_name Progress
extends RefCounted
## Unlocks earned by playing (C33, PRD 5.2), kept on this machine alone: no store, no money, no account, no
## network call, no telemetry, nothing ever bought. One instance for the whole run (current()), kept in one
## small versioned save beside the settings file, user://progress.cfg, through the settings file's own strict
## reader and atomic writer (scripts/settings/settings_file.gd: plain literals only, a temporary name renamed
## over the old file):
##   [meta]      version=1, the settings file's format
##   [progress]  format=1, this save's own
##   [feats]     a count per feat (FEATS): kills with each weapon, rail headshots, freezes, discards...
##   [unlocked]  each earned skin and mod, <weapon>__<id>=true
##   [loadout]   each weapon's chosen skin, skin_<weapon>="<skin>", and its mod, mod_<weapon>=true
## A missing, damaged or newer file is a fresh profile (nothing earned, every weapon in its own skin), never a
## crash; the next save writes a good one. Nothing in it is ever an object, a path or a name of the player's.
##
## Earned: count() moves a feat on and unlocks every skin and mod whose count it has reached (a kit's feat and
## need, resources/<weapon>_kit.tres), each once, telling unlocked (the HUD's toast). A feat counts alone only
## against the C27b daemons fighting back (judged_feat(): the daemons' director deciding, never in practice with
## the never-attack dummies), and in a match only from the host's judged results for this player (the host's own
## judging of its own player, or the session's match_feat() on the host's word: a kill it credits, a headshot).
##
## The launch flag --unlock-all (a dev and test flag, off unless given) makes everything count as held for the
## run, for captures; it is never written to the save. reset() wipes the profile (the settings screen asks
## twice). Headless runs (the tests, check.sh) never read or write the player's file: there current() has no
## path, and a test that wants a file sets `path` itself.

signal unlocked(weapon: String, item: String, title: String)

const SettingsFile = preload("res://scripts/settings/settings_file.gd")
const WeaponDefScript = preload("res://scripts/weapons/weapon_def.gd")

const DEFAULT_PATH := "user://progress.cfg"
const FORMAT := 1
const UNLOCK_ALL_FLAG := "--unlock-all"
const PROGRESS := "progress"
const FEATS_SECTION := "feats"
const UNLOCKED := "unlocked"
const LOADOUT := "loadout"
## A feat's count stops here: plenty, and well inside the file's numbers.
const COUNT_LAST := 1000000
## Seconds between saves of counts alone (an unlock, a choice or a reset saves at once).
const SAVE_EVERY_S := 30.0
## The feats that earn things: the kills with each weapon ("kills_<weapon id>", added by feats()) and these.
const SPECIAL_FEATS := ["rail_heads", "bomb_triples", "pings", "freezes", "shatters", "chains3", "discards", "hups", "lash_kills", "ice_walls", "black_ice", "grep_marks"]

## Where load_file() reads and save() writes; "" (every headless run) means nowhere.
var path := ""
## How the last load went: "defaults" (no path), "missing", "unreadable", "loaded".
var last_load := "defaults"
## Everything held for this run (--unlock-all); never saved.
var all_unlocked := false
## feat -> count; item key -> true; weapon id -> chosen skin; weapon id -> mod chosen.
var feats := {}
var held := {}
var skins := {}
var mods := {}
var _dirty := false
var _since_save := 0.0

static var _current: Progress


## The run's progress: the player's own file, loaded, unless headless (no path, a fresh profile). The launch
## flag --unlock-all holds everything for the run.
static func current() -> Progress:
	if _current == null:
		_current = Progress.new()
		_current.all_unlocked = OS.get_cmdline_user_args().has(UNLOCK_ALL_FLAG)
		if DisplayServer.get_name() != "headless":
			_current.path = DEFAULT_PATH
			_current.load_file()
	return _current


## Every feat that can earn something.
static func feat_names() -> PackedStringArray:
	var out := PackedStringArray()
	for def in WeaponKit.shipped_defs():
		out.append("kills_" + def.id)
	out.append_array(SPECIAL_FEATS)
	return out


## The save's key for weapon `weapon`'s skin or mod `item`.
static func key_of(weapon: String, item: String) -> String:
	return "%s__%s" % [weapon, item]


## A fresh profile: nothing counted, nothing earned, every weapon in its own skin with no mod.
func clear() -> void:
	feats = {}
	held = {}
	skins = {}
	mods = {}


## Reads `path`: each good value is taken, anything else left out. "missing" or "unreadable" leave a fresh
## profile.
func load_file() -> String:
	clear()
	if path == "":
		last_load = "defaults"
		return last_load
	if not FileAccess.file_exists(path):
		last_load = "missing"
		return last_load
	var doc := SettingsFile.read(path)
	if doc.is_empty() or not doc.has(PROGRESS) or doc[PROGRESS].get("format") != FORMAT:
		last_load = "unreadable"
		return last_load
	var names := feat_names()
	for feat in doc.get(FEATS_SECTION, {}):
		var n = doc[FEATS_SECTION][feat]
		if names.has(feat) and n is int and n >= 0:
			feats[feat] = mini(n, COUNT_LAST)
	for key in doc.get(UNLOCKED, {}):
		if doc[UNLOCKED][key] == true and _item_of(key) != null:
			held[key] = true
	for def in WeaponKit.shipped_defs():
		var kit := WeaponKit.of(def.id)
		var chosen = doc.get(LOADOUT, {}).get("skin_" + def.id)
		if kit != null and chosen is String and kit.skin_index(chosen) > 0:
			skins[def.id] = chosen
		if doc.get(LOADOUT, {}).get("mod_" + def.id) == true and kit != null and kit.mod != null:
			mods[def.id] = true
	last_load = "loaded"
	return last_load


## Writes the whole profile to `path`, keeping anything else the file holds. False with no path or a failed
## write (the run goes on with what it has).
func save() -> bool:
	_dirty = false
	_since_save = 0.0
	if path == "":
		return false
	var counts := {}
	for feat in feats:
		counts[feat] = feats[feat]
	var choices := {}
	for weapon in skins:
		choices["skin_" + weapon] = skins[weapon]
	for weapon in mods:
		choices["mod_" + weapon] = true
	return SettingsFile.write_sections(path, {PROGRESS: {"format": FORMAT}, FEATS_SECTION: counts, UNLOCKED: held.duplicate(), LOADOUT: choices})


## Saves counts that changed, at most every SAVE_EVERY_S of `delta` seconds (a round's end and quitting save
## at once through flush()).
func tick(delta: float) -> void:
	_since_save += delta
	if _dirty and _since_save >= SAVE_EVERY_S:
		save()


## Saves now if anything changed since the last save.
func flush() -> void:
	if _dirty:
		save()


## Moves `feat` on by `n` and unlocks whatever that earned: [[weapon, item, title], ...], each told once.
func count(feat: String, n: int = 1) -> Array:
	if n <= 0 or not feat_names().has(feat):
		return []
	feats[feat] = mini(int(feats.get(feat, 0)) + n, COUNT_LAST)
	_dirty = true
	var out := []
	for def in WeaponKit.shipped_defs():
		var kit := WeaponKit.of(def.id)
		if kit == null:
			continue
		var items: Array = kit.skins.slice(1)
		if kit.mod != null:
			items.append(kit.mod)
		for item in items:
			var id: String = item.skin if item is WeaponSkin else item.id
			var key := key_of(def.id, id)
			if item.feat == feat and not held.has(key) and feats[feat] >= item.need:
				held[key] = true
				var title := "%s  (%s %s)" % [item.display_name, def.short_name, "skin" if item is WeaponSkin else "mod"]
				out.append([def.id, id, title])
	if not out.is_empty():
		save()
		for got in out:
			unlocked.emit(got[0], got[1], got[2])
	return out


func count_of(feat: String) -> int:
	return int(feats.get(feat, 0))


## True when weapon `weapon`'s skin or mod `item` is held: its own skin always, anything with --unlock-all.
func has(weapon: String, item: String) -> bool:
	if all_unlocked or held.has(key_of(weapon, item)):
		return true
	var kit := WeaponKit.of(weapon)
	return kit != null and not kit.skins.is_empty() and kit.skins[0].skin == item


## The skin weapon `weapon` wears: the chosen one while it is held, else its own.
func skin_of(weapon: String) -> String:
	var kit := WeaponKit.of(weapon)
	var own: String = kit.skins[0].skin if kit != null and not kit.skins.is_empty() else ""
	var chosen: String = skins.get(weapon, own)
	return chosen if has(weapon, chosen) else own


## True when weapon `weapon`'s mod is chosen and held.
func mod_on(weapon: String) -> bool:
	var kit := WeaponKit.of(weapon)
	return mods.get(weapon, false) == true and kit != null and kit.mod != null and has(weapon, kit.mod.id)


## Chooses skin `skin` for `weapon`, saved at once. False (nothing changes) for one not held.
func choose_skin(weapon: String, skin: String) -> bool:
	var kit := WeaponKit.of(weapon)
	if kit == null or kit.skin_index(skin) < 0 or not has(weapon, skin):
		return false
	if kit.skin_index(skin) == 0:
		skins.erase(weapon)
	else:
		skins[weapon] = skin
	save()
	return true


## Turns `weapon`'s mod on or off, saved at once. False for a mod not held, or none.
func choose_mod(weapon: String, on: bool) -> bool:
	var kit := WeaponKit.of(weapon)
	if kit == null or kit.mod == null or (on and not has(weapon, kit.mod.id)):
		return false
	if on:
		mods[weapon] = true
	else:
		mods.erase(weapon)
	save()
	return true


## Wipes every count, unlock and choice, and saves the fresh profile. --unlock-all still holds everything for
## the run.
func reset() -> bool:
	clear()
	return save()


## How weapon `weapon`'s item `item` is earned, for the loadout screen: "12 / 25 kills with cannon".
func progress_line(weapon: String, item: Resource) -> String:
	var feat: String = item.feat
	return "%d / %d %s" % [mini(count_of(feat), item.need), item.need, feat_words(feat)]


## A feat in words, after its count.
static func feat_words(feat: String) -> String:
	if feat.begins_with("kills_"):
		var id := feat.trim_prefix("kills_")
		for def in WeaponKit.shipped_defs():
			if def.id == id:
				return "kills with " + def.short_name
	return {"rail_heads": "kill -9 headshots", "bomb_triples": "fork bombs that derezzed 3", "pings": "daemons found by ping", "freezes": "daemons frozen", "shatters": "frozen daemons shattered", "chains3": "chains of 3+ links", "discards": "daemons discarded", "hups": "daemons hung up", "lash_kills": "kills by a confused daemon's lash", "ice_walls": "ICE walls broken", "black_ice": "rounds survived with Black ICE out", "grep_marks": "targets marked by grep"}.get(feat, feat)


# --- The earned rule. ---

## A feat of this player's that this machine judged itself: alone against the C27b daemons fighting back, or as
## a match's host, whose own results are the host's judgement (the daemons' director deciding in both). Never in
## practice (the director resting: the old never-attack dummies), never on a joiner's screen (there only the
## host's word counts, match_feat()). `node` is anything in the arena.
static func judged_feat(node: Node, feat: String, n: int = 1) -> void:
	if judges_here(node):
		current().count(feat, n)


## True where this machine's own results earn feats: the daemons' director deciding (alone or hosting, the
## daemons fighting back).
static func judges_here(node: Node) -> bool:
	var director := DaemonDirector.of(node)
	return director != null and director.mode == DaemonDirector.Mode.RUN


## A feat in a match, from the host's judged results for this player: the session calls it on the host's word
## (a kill it credits, a headshot it confirms), on the host and on a joiner alike.
static func match_feat(feat: String, n: int = 1) -> void:
	current().count(feat, n)


func _item_of(key: String) -> Resource:
	var parts := key.split("__")
	if parts.size() != 2:
		return null
	var kit := WeaponKit.of(parts[0])
	if kit == null:
		return null
	if kit.mod != null and kit.mod.id == parts[1]:
		return kit.mod
	var i := kit.skin_index(parts[1])
	return kit.skins[i] if i > 0 else null
