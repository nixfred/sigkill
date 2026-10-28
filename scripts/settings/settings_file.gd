extends RefCounted
## SIGKILL's one settings file, user://settings.cfg (C16b): a Godot ConfigFile, versioned,
## holding everything the game keeps between launches, a section each:
##   [meta]         version=1
##   [privacy]      the AI opt-in, the roast announcer and real-machine data, read and
##                  written only by scripts/boot/guide_settings.gd
##   [controls] [binds] [video] [audio] [hud] [multiplayer]
##                  the settings screen's own, scripts/settings/game_settings.gd
## Reading is strict and quiet, as the C9 file's always was: at most MAX_BYTES of plain
## ASCII, and every line a comment, a [section] or key=value whose value is true, false, a
## number or a plain "string" with no quote or backslash inside. A key twice in a section,
## a section twice, anything else (Color(...), Object(...), Resource(...), a list or a
## dictionary) and the whole file counts as missing: nothing in it ever becomes an object,
## and a damaged file means the defaults and one more AI question, never a call without
## consent. Only text that passed that scan is handed to ConfigFile. A file from a newer
## version reads as missing and is overwritten only when the player saves. The C9 to C16
## file (plain key=value lines, no sections) is read by its old rules as version 0: its
## privacy answers carry over, and the next save writes version 1. A save goes to a
## temporary name in the same folder and is renamed over the old file; each writer replaces
## only its own sections and keeps every other one as it was read.

const DEFAULT_PATH := "user://settings.cfg"
const VERSION := 1
const MAX_BYTES := 4096
const META := "meta"
const PRIVACY := "privacy"
const LEGACY_KEYS := ["ai_consent_source", "ai_consent", "roast_announcer"]
const NAME_LAST := 40
const STRING_LAST := 64
const NEWLINE := 0x0A
const CARRIAGE_RETURN := 0x0D
const PRINTABLE_FIRST := 0x20
const PRINTABLE_LAST := 0x7E
const HEADER := "; SIGKILL settings. The game writes this file; a line it cannot read resets the whole file to the defaults.\n"
## true, false, an integer, a decimal (Godot writes 1e-05 as is) or a plain "string".
const LITERAL := "^(true|false|-?[0-9]{1,10}|-?[0-9]{1,10}\\.[0-9]{1,17}(e[-+]?[0-9]{1,3})?|-?[0-9]{1,10}e[-+]?[0-9]{1,3}|\"[ !#-\\[\\]-~]{0,64}\")$"
const NAME := "^[a-z][a-z0-9_]*$"


## {section: {key: value}} with meta.version, from the file; {} when it is missing, damaged,
## from a newer version or not somewhere the game keeps settings.
static func read(path: String = DEFAULT_PATH) -> Dictionary:
	if not usable_path(path) or not FileAccess.file_exists(path):
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
	var text := bytes.get_string_from_ascii()
	var lines := text.split("\n", false)
	for line in lines:
		if line.strip_edges().begins_with("["):
			return _read_sections(text, lines)
	return _read_legacy(lines)


## Replaces the given sections (each {key: value}, values bool, int, float or a plain
## string) and keeps every other section the file holds. False, and nothing written, for a
## path the game does not keep settings in, a value it could not read back, or a failed write.
static func write_sections(path: String, sections: Dictionary) -> bool:
	if not usable_path(path):
		return false
	var doc := read(path)
	doc.erase(META)
	for section in sections:
		doc[section] = sections[section]
	var config := ConfigFile.new()
	config.set_value(META, "version", VERSION)
	for section in doc:
		if not _name_ok(section):
			return false
		for key in doc[section]:
			var value = doc[section][key]
			if not _name_ok(key) or not value_ok(value):
				return false
			config.set_value(section, key, value)
	var dir := ProjectSettings.globalize_path(path.get_base_dir())
	if not DirAccess.dir_exists_absolute(dir) and DirAccess.make_dir_recursive_absolute(dir) != OK:
		return false
	var target := ProjectSettings.globalize_path(path)
	var temporary := target + ".tmp"
	var file := FileAccess.open(temporary, FileAccess.WRITE)
	if file == null:
		return false
	file.store_string(HEADER + config.encode_to_text())
	file.close()
	return DirAccess.rename_absolute(temporary, target) == OK


## True for a value the file can hold and read back: a bool, an int, a finite float, or a
## string of up to STRING_LAST printable ASCII characters with no quote or backslash.
static func value_ok(value: Variant) -> bool:
	match typeof(value):
		TYPE_BOOL, TYPE_INT:
			return true
		TYPE_FLOAT:
			return is_finite(value)
		TYPE_STRING:
			var s: String = value
			if s.length() > STRING_LAST:
				return false
			for i in s.length():
				var code := s.unicode_at(i)
				if code < PRINTABLE_FIRST or code > PRINTABLE_LAST or code == 0x22 or code == 0x5C:
					return false
			return true
	return false


## The game keeps its settings in user://; tests use an absolute path in a temporary
## folder. Never anywhere inside the project.
static func usable_path(path: String) -> bool:
	return path.begins_with("user://") or (path.begins_with("/") and not path.contains(".."))


static func _read_sections(text: String, lines: PackedStringArray) -> Dictionary:
	var literal := RegEx.create_from_string(LITERAL)
	var seen := {}
	var section := ""
	for line in lines:
		var s := line.strip_edges()
		if s.is_empty() or s.begins_with(";") or s.begins_with("#"):
			continue
		if s.begins_with("["):
			if not s.ends_with("]"):
				return {}
			section = s.substr(1, s.length() - 2)
			if not _name_ok(section) or seen.has(section):
				return {}
			seen[section] = {}
			continue
		var eq := s.find("=")
		if section == "" or eq <= 0:
			return {}
		var key := s.substr(0, eq).strip_edges()
		var value := s.substr(eq + 1).strip_edges()
		if not _name_ok(key) or seen[section].has(key) or literal.search(value) == null:
			return {}
		seen[section][key] = true
	var config := ConfigFile.new()
	if config.parse(text) != OK:
		return {}
	if not config.has_section_key(META, "version"):
		return {}
	var version = config.get_value(META, "version")
	if typeof(version) != TYPE_INT or version < 1 or version > VERSION:
		return {}
	var doc := {}
	for name in config.get_sections():
		doc[name] = {}
		for key in config.get_section_keys(name):
			doc[name][key] = config.get_value(name, key)
	return doc


## The C9 to C16 file: lines of key=value, # comments; each known key once, a line without
## "=" not at all. Only the privacy answers were ever in it.
static func _read_legacy(lines: PackedStringArray) -> Dictionary:
	var values := {}
	for line in lines:
		var s := line.strip_edges()
		if s.is_empty() or s.begins_with("#"):
			continue
		var eq := s.find("=")
		if eq <= 0:
			return {}
		var key := s.substr(0, eq).strip_edges()
		if not LEGACY_KEYS.has(key):
			continue
		if values.has(key):
			return {}
		values[key] = s.substr(eq + 1).strip_edges()
	return {META: {"version": 0}, PRIVACY: values}


static func _name_ok(name: String) -> bool:
	return name.length() <= NAME_LAST and RegEx.create_from_string(NAME).search(name) != null
