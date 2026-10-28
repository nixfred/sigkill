extends RefCounted
## The player's privacy answers (C16b: the settings screen's Privacy section), kept in the
## [privacy] section of the game's one settings file, user://settings.cfg
## (scripts/settings/settings_file.gd), and nowhere else:
##   ai_consent_source="<an agent name, "ollama" or "openai-compatible">"
##   ai_consent="yes"   (or "no"): the answer to the AI opt-in (PRD 5.4)
##   roast_announcer="on"   (or "off"; off when missing): the roast announcer switch (C12)
##   real_machine_data="on"   (or "off"; on when missing): off is demo data at every launch,
##       as --demo is: no detector, fake GPU numbers, nothing read from the machine
## The answer counts only for that source: a different agent or server is asked again.
## Reading is strict and quiet: a damaged file, or a value that is not one of these, counts
## as never asked, roast off and real data as shipped, so a damaged file means one more
## question, never a call without consent. Saving one answer keeps the others and every
## other section of the file. The file from before C16b, plain key=value lines, is read by
## its old rules and rewritten in the new form by the next save. C11 adds the in-game
## switch that changes the opt-in later; C16b's settings screen drives all three switches
## through their owners (the guide link, the round HUD), never a copy of its own.

const Detector = preload("res://scripts/ai/ai_source_detector.gd")
const SettingsFile = preload("res://scripts/settings/settings_file.gd")

const DEFAULT_PATH := SettingsFile.DEFAULT_PATH
const KEY_SOURCE := "ai_consent_source"
const KEY_CONSENT := "ai_consent"
const KEY_ROAST := "roast_announcer"
const KEY_REAL_DATA := "real_machine_data"
const KEYS := [KEY_SOURCE, KEY_CONSENT, KEY_ROAST, KEY_REAL_DATA]
const YES := "yes"
const NO := "no"
const ON := "on"
const OFF := "off"
const LOCAL_SOURCES := ["ollama", "openai-compatible"]

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


## True only when the file says roast_announcer on: missing, damaged or anything else is off.
static func roast_on(path: String = DEFAULT_PATH) -> bool:
	return _values(path).get(KEY_ROAST, "") == ON


## False only when the file says real_machine_data off: missing, damaged or anything else
## is the shipped behaviour, real data.
static func real_data_on(path: String = DEFAULT_PATH) -> bool:
	return _values(path).get(KEY_REAL_DATA, "") != OFF


## The privacy section's string values, or {} when the file is missing or damaged.
static func _values(path: String) -> Dictionary:
	var section = SettingsFile.read(path).get(SettingsFile.PRIVACY, {})
	var values := {}
	if not (section is Dictionary):
		return values
	for key in KEYS:
		if section.has(key):
			if not (section[key] is String):
				return {}
			values[key] = section[key]
	return values


## Saves the answer for `source`, keeping the other switches. False, and nothing written, if
## the source is not one an answer can be about or the file cannot be written.
static func save(source: String, allowed: bool, path: String = DEFAULT_PATH) -> bool:
	if not known_source(source) or not SettingsFile.usable_path(path):
		return false
	var answer := {"source": source, "allowed": allowed}
	return _write(path, answer, roast_on(path), real_data_on(path))


## Saves the roast announcer switch, keeping the opt-in answer and real data. False if the
## file cannot be written.
static func save_roast(on: bool, path: String = DEFAULT_PATH) -> bool:
	if not SettingsFile.usable_path(path):
		return false
	return _write(path, read(path), on, real_data_on(path))


## Saves the real-machine data switch, keeping the opt-in answer and the roast switch. It
## counts from the next launch. False if the file cannot be written.
static func save_real_data(on: bool, path: String = DEFAULT_PATH) -> bool:
	if not SettingsFile.usable_path(path):
		return false
	return _write(path, read(path), roast_on(path), on)


static func _write(path: String, answer: Dictionary, roast: bool, real_data: bool) -> bool:
	var privacy := {}
	if not answer.is_empty():
		privacy[KEY_SOURCE] = answer["source"]
		privacy[KEY_CONSENT] = YES if answer["allowed"] else NO
	privacy[KEY_ROAST] = ON if roast else OFF
	privacy[KEY_REAL_DATA] = ON if real_data else OFF
	return SettingsFile.write_sections(path, {SettingsFile.PRIVACY: privacy})
