extends RefCounted
## The player's answer to the AI opt-in (PRD 5.4), and the roast announcer switch (C12),
## kept in one small text file in the game's own data folder, user://settings.cfg, and
## nowhere else. Up to three lines:
##   ai_consent_source=<an agent name, "ollama" or "openai-compatible">
##   ai_consent=yes   (or no)
##   roast_announcer=on   (or off; off when missing)
## The answer counts only for that source: a different agent or server is asked again.
## Reading is strict and quiet: at most MAX_BYTES of plain ASCII, each known key once,
## known values only; anything else counts as never asked and roast off, so a damaged file
## means one more question, never a call without consent. Saving one setting keeps the
## other as it was, and writes the whole file to a temporary name in the same folder and
## renames it over the old one. C11 adds the in-game switch that changes the answer later.

const Detector = preload("res://scripts/ai/ai_source_detector.gd")

const DEFAULT_PATH := "user://settings.cfg"
const MAX_BYTES := 4096
const KEY_SOURCE := "ai_consent_source"
const KEY_CONSENT := "ai_consent"
const KEY_ROAST := "roast_announcer"
const YES := "yes"
const NO := "no"
const ON := "on"
const OFF := "off"
const LOCAL_SOURCES := ["ollama", "openai-compatible"]
const NEWLINE := 0x0A
const CARRIAGE_RETURN := 0x0D
const PRINTABLE_FIRST := 0x20
const PRINTABLE_LAST := 0x7E

enum Answer { NOT_ASKED, ALLOWED, DECLINED }


## True for a name an answer can be about: an agent the C9 detector knows, or a local kind.
static func known_source(source: String) -> bool:
	return Detector.KNOWN_AGENTS.has(source) or LOCAL_SOURCES.has(source)


## The saved answer for `source`; NOT_ASKED if there is none, it is for another source, or
## the file is missing or damaged.
static func answer_for(source: String, path: String = DEFAULT_PATH) -> Answer:
	var saved := read(path)
	if saved.is_empty() or saved["source"] != source:
		return Answer.NOT_ASKED
	return Answer.ALLOWED if saved["allowed"] else Answer.DECLINED


## {source, allowed} from the file, or {} when there is no usable answer in it.
static func read(path: String = DEFAULT_PATH) -> Dictionary:
	var values := _values(path)
	if not values.has(KEY_SOURCE) or not values.has(KEY_CONSENT):
		return {}
	var source: String = values[KEY_SOURCE]
	var consent: String = values[KEY_CONSENT]
	if not known_source(source) or (consent != YES and consent != NO):
		return {}
	return {"source": source, "allowed": consent == YES}


## True only when the file says roast_announcer=on: missing, damaged or anything else is off.
static func roast_on(path: String = DEFAULT_PATH) -> bool:
	return _values(path).get(KEY_ROAST, "") == ON


## The known keys and their values from the file, or {} when it is missing, too big, not
## plain ASCII, or has a line without "=" or a known key twice.
static func _values(path: String) -> Dictionary:
	if not _usable_path(path) or not FileAccess.file_exists(path):
		return {}
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {}
	var bytes := file.get_buffer(MAX_BYTES + 1)
	file.close()
	if bytes.size() > MAX_BYTES:
		return {}
	for b in bytes:
		if b != NEWLINE and b != CARRIAGE_RETURN and (b < PRINTABLE_FIRST or b > PRINTABLE_LAST):
			return {}
	var values := {}
	for line in bytes.get_string_from_ascii().split("\n", false):
		var text := line.strip_edges()
		if text.is_empty() or text.begins_with("#"):
			continue
		var eq := text.find("=")
		if eq <= 0:
			return {}
		var key := text.substr(0, eq).strip_edges()
		if key != KEY_SOURCE and key != KEY_CONSENT and key != KEY_ROAST:
			continue
		if values.has(key):
			return {}
		values[key] = text.substr(eq + 1).strip_edges()
	return values


## Saves the answer for `source`, keeping the roast switch. False, and nothing written, if
## the source is not one an answer can be about or the file cannot be written.
static func save(source: String, allowed: bool, path: String = DEFAULT_PATH) -> bool:
	if not known_source(source) or not _usable_path(path):
		return false
	return _write(path, {"source": source, "allowed": allowed}, roast_on(path))


## Saves the roast announcer switch, keeping the opt-in answer. False if the file cannot be
## written.
static func save_roast(on: bool, path: String = DEFAULT_PATH) -> bool:
	if not _usable_path(path):
		return false
	return _write(path, read(path), on)


static func _write(path: String, answer: Dictionary, roast: bool) -> bool:
	var dir := ProjectSettings.globalize_path(path.get_base_dir())
	if not DirAccess.dir_exists_absolute(dir) and DirAccess.make_dir_recursive_absolute(dir) != OK:
		return false
	var target := ProjectSettings.globalize_path(path)
	var temporary := target + ".tmp"
	var file := FileAccess.open(temporary, FileAccess.WRITE)
	if file == null:
		return false
	var text := "# SIGKILL settings: the answer to the AI opt-in and the roast announcer switch.\n"
	if not answer.is_empty():
		text += "%s=%s\n%s=%s\n" % [KEY_SOURCE, answer["source"], KEY_CONSENT, YES if answer["allowed"] else NO]
	text += "%s=%s\n" % [KEY_ROAST, ON if roast else OFF]
	file.store_string(text)
	file.close()
	return DirAccess.rename_absolute(temporary, target) == OK


## The game keeps its settings in user://; tests use an absolute path in a temporary
## folder. Never anywhere inside the project.
static func _usable_path(path: String) -> bool:
	return path.begins_with("user://") or (path.begins_with("/") and not path.contains(".."))
