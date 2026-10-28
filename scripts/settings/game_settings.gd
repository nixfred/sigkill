class_name GameSettings
extends RefCounted
## The settings screen's own settings (C16b), one instance for the whole run (current()),
## kept in the game's one settings file (scripts/settings/settings_file.gd) beside the
## privacy answers, which stay with their owners (scripts/boot/guide_settings.gd, driven
## through the guide link and the round HUD) and are never copied here.
##
## SCHEMA is every setting: its section, its type, its default and the values it may take
## (a range, or a list of choices). A value from the file that is the wrong type or out of
## bounds is replaced by the default; a missing or damaged file gives every default. Every
## default is the game as it shipped before C16b, so nothing changes until the player
## changes it: fov 0 and port 0 mean the tuning's own (80 degrees, 9009), an empty display
## name the tuning's own ("player"), sensitivity multipliers of 1, and no relay URL: no
## online rooms and no network call (C16c). Light-trail mode (C20) is off: it is the host's
## match rule, and a joiner's own setting never counts. Graphics (A4): the quality preset
## (low, medium or high) sets every costly feature at once, each one its own toggle too (see
## PRESETS); a toggle changed by hand makes the preset read "custom", and picking a preset
## sets them all again. The default is high, everything on. Chromatic aberration and the CRT
## scanlines are taste, not cost: off by default and in no preset. A file from before A4
## holds the preset alone: each toggle it lacks takes that preset's value. Key binds live in their
## own section, one per action the player changed (scripts/controls.gd says which actions
## and what a bind may be); an action left out has its default.
##
## Headless runs (the tests, check.sh) never read or write the player's file: there
## current() holds the defaults and has no path, and a test that wants a file sets `path`
## itself. changed(section, key) fires on every change; the screen saves on its way out.

signal changed(section: String, key: String)

const SettingsFile = preload("res://scripts/settings/settings_file.gd")
const Controls = preload("res://scripts/controls.gd")
const RelayWire = preload("res://scripts/net/relay_wire.gd")

const BINDS := "binds"
const NAME_LAST := 24
const NAME_DEFAULT := "player"
const PORT_FIRST := 1024
const PORT_LAST := 65535
const FOV_FIRST := 60
const FOV_LAST := 120
const STEP := 0.01
## [type, default, then a [first, last] range or an Array of choices].
const SCHEMA := {
	"controls": {
		"invert_y": [TYPE_BOOL, false],
		"mouse_sensitivity": [TYPE_FLOAT, 1.0, [0.1, 5.0]],
		"ads_sensitivity": [TYPE_FLOAT, 0.7, [0.1, 5.0]],
		"crouch_mode": [TYPE_STRING, "hold", ["hold", "toggle"]],
		"aim_mode": [TYPE_STRING, "hold", ["hold", "toggle"]],
	},
	"video": {
		"window_mode": [TYPE_STRING, "windowed", ["windowed", "fullscreen", "borderless"]],
		"resolution_scale": [TYPE_FLOAT, 1.0, [0.5, 1.0]],
		"fps_cap": [TYPE_INT, 0, [0, 30, 60, 75, 90, 120, 144, 165, 240]],
		"vsync": [TYPE_BOOL, true],
		"fov": [TYPE_INT, 0, [0, FOV_LAST]],
		"quality": [TYPE_STRING, "high", ["low", "medium", "high", CUSTOM]],
		"bloom": [TYPE_BOOL, true],
		"shadows": [TYPE_BOOL, true],
		"code_rain": [TYPE_BOOL, true],
		"ssao": [TYPE_BOOL, true],
		"ssr": [TYPE_BOOL, true],
		"skyline": [TYPE_BOOL, true],
		"particles": [TYPE_STRING, "high", ["low", "medium", "high"]],
		"chromatic_aberration": [TYPE_BOOL, false],
		"crt": [TYPE_BOOL, false],
	},
	"audio": {
		"master": [TYPE_FLOAT, 1.0, [0.0, 1.0]],
		"effects": [TYPE_FLOAT, 1.0, [0.0, 1.0]],
		"music": [TYPE_FLOAT, 1.0, [0.0, 1.0]],
		"announcer": [TYPE_FLOAT, 1.0, [0.0, 1.0]],
	},
	"hud": {
		"crosshair_style": [TYPE_STRING, "cross", ["cross", "dot", "circle", "cross_dot"]],
		"crosshair_color": [TYPE_STRING, "mint", ["mint", "white", "yellow", "magenta", "cyan"]],
		"colorblind": [TYPE_BOOL, false],
		"screen_shake": [TYPE_BOOL, true],
		"motion_blur": [TYPE_BOOL, true],
		"subtitles": [TYPE_BOOL, true],
	},
	"multiplayer": {
		"display_name": [TYPE_STRING, "", []],
		"relay_url": [TYPE_STRING, "", []],
		"port": [TYPE_INT, 0, [0, PORT_LAST]],
		"net_stats": [TYPE_BOOL, false],
		"light_trails": [TYPE_BOOL, false],
	},
}
## The quality preset's name when the toggles match no preset.
const CUSTOM := "custom"
## What each quality preset sets (A4; bloom, shadows and code rain since C16b): bloom (the
## environment's glow), the sun's shadows, the code rain, screen-space ambient occlusion and
## reflections, the full skyline (off: its towers alone, without the orbital ring and the
## drifting slabs), and how many particles an effect may show. Low is the cheap one:
## none of the screen-space passes, no glow, the plain skyline, a quarter of the particles.
## Medium is the 4050-class target: glow, the rain and the full skyline, no shadows, SSAO or
## SSR, a half share of the particles. Every value here is a key in the video section.
const PRESETS := {
	"low": {"bloom": false, "shadows": false, "code_rain": false, "ssao": false, "ssr": false, "skyline": false, "particles": "low"},
	"medium": {"bloom": true, "shadows": false, "code_rain": true, "ssao": false, "ssr": false, "skyline": true, "particles": "medium"},
	"high": {"bloom": true, "shadows": true, "code_rain": true, "ssao": true, "ssr": true, "skyline": true, "particles": "high"},
}
## The settings a preset sets, in the order the screen shows them.
const PRESET_KEYS := ["bloom", "shadows", "code_rain", "ssao", "ssr", "skyline", "particles"]
## Every graphics setting (A4): the preset, its keys, and the two post effects.
const GRAPHICS_KEYS := ["quality", "bloom", "shadows", "code_rain", "ssao", "ssr", "skyline", "particles", "chromatic_aberration", "crt"]

static var _current: GameSettings

## Where load_file() reads and save() writes; "" (every headless run) means nowhere.
var path := ""
## How the last load went: "defaults" (no path), "missing", "unreadable", "old" (the
## file from before C16b: privacy answers only) or "loaded".
var last_load := "defaults"

var _values := {}
var _binds := {}


## The one instance for this run: read from user://settings.cfg on first use, except in a
## headless run, which gets the defaults and no path.
static func current() -> GameSettings:
	if _current == null:
		_current = GameSettings.new()
		if DisplayServer.get_name() != "headless":
			_current.path = SettingsFile.DEFAULT_PATH
			_current.load_file()
	return _current


func _init() -> void:
	reset()


## Every setting back to its default, and no binds: the shipped game. Fires changed("", "").
func reset() -> void:
	_values = {}
	for section in SCHEMA:
		_values[section] = {}
		for key in SCHEMA[section]:
			_values[section][key] = SCHEMA[section][key][1]
	_binds = {}
	changed.emit("", "")


## Reads `path`: each good value is taken, anything else stays at its default.
func load_file() -> String:
	reset()
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
	for section in SCHEMA:
		var saved = doc.get(section, {})
		for key in SCHEMA[section]:
			if saved.has(key):
				var good = checked(section, key, saved[key])
				if good != null:
					_values[section][key] = good
	# A file from before A4 holds the preset alone: each toggle it lacks takes the preset's.
	var preset: String = _values["video"]["quality"]
	var saved_video = doc.get("video", {})
	if PRESETS.has(preset):
		for key in PRESET_KEYS:
			if not (saved_video is Dictionary and saved_video.has(key) and checked("video", key, saved_video[key]) != null):
				_values["video"][key] = PRESETS[preset][key]
	_values["video"]["quality"] = _matching_preset()
	var saved_binds = doc.get(BINDS, {})
	for pair in Controls.REBINDABLE:
		var bind = saved_binds.get(pair[0])
		if bind is String and Controls.event_of(bind) != null and bind != Controls.default_bind(pair[0]):
			_binds[pair[0]] = bind
	last_load = "old" if doc.get(SettingsFile.META, {}).get("version", 0) == 0 else "loaded"
	changed.emit("", "")
	return last_load


## Writes every setting and bind to `path`, keeping the privacy answers. False with no path
## or when the write fails.
func save() -> bool:
	if path == "":
		return false
	var sections := {}
	for section in SCHEMA:
		sections[section] = _values[section].duplicate()
	sections[BINDS] = _binds.duplicate()
	return SettingsFile.write_sections(path, sections)


func value(section: String, key: String) -> Variant:
	return _values.get(section, {}).get(key)


## Sets one setting. The value is checked as a loaded one is: a float in range is snapped to
## STEP, a string out of its choices or a value of the wrong type is refused (false).
##
## Graphics (A4): a preset sets each of its keys first (each change fired), then itself; a
## preset key set by hand makes the preset whichever one its keys now match, or "custom".
## "custom" itself sets nothing, so it holds only while the keys match no preset.
func set_value(section: String, key: String, v: Variant) -> bool:
	var good = checked(section, key, v)
	if good == null:
		return false
	if section == "video" and key == "quality" and PRESETS.has(good):
		for preset_key in PRESET_KEYS:
			_put("video", preset_key, PRESETS[good][preset_key])
	_put(section, key, good)
	if section == "video" and (key == "quality" or PRESET_KEYS.has(key)):
		_put("video", "quality", _matching_preset())
	return true


func _put(section: String, key: String, good: Variant) -> void:
	if _values[section][key] != good:
		_values[section][key] = good
		changed.emit(section, key)


## The preset the video section's keys match now, or "custom".
func _matching_preset() -> String:
	for preset in PRESETS:
		var same := true
		for key in PRESET_KEYS:
			same = same and _values["video"][key] == PRESETS[preset][key]
		if same:
			return preset
	return CUSTOM


## `v` as the setting can hold it, or null when it can't.
static func checked(section: String, key: String, v: Variant) -> Variant:
	if not SCHEMA.has(section) or not SCHEMA[section].has(key):
		return null
	var spec: Array = SCHEMA[section][key]
	match spec[0]:
		TYPE_BOOL:
			return v if v is bool else null
		TYPE_FLOAT:
			if not (v is float or v is int) or not is_finite(float(v)):
				return null
			var bounds: Array = spec[2]
			return clampf(snappedf(float(v), STEP), bounds[0], bounds[1])
		TYPE_INT:
			if not (v is int):
				return null
			if key == "fov":
				return v if v == 0 or (v >= FOV_FIRST and v <= FOV_LAST) else null
			if key == "port":
				return v if v == 0 or (v >= PORT_FIRST and v <= PORT_LAST) else null
			return v if (spec[2] as Array).has(v) else null
		TYPE_STRING:
			if not (v is String):
				return null
			if key == "display_name":
				return clean_name(v)
			if key == "relay_url":
				return v if RelayWire.url_ok(v) else null
			return v if (spec[2] as Array).has(v) else null
	return null


## The player's display name as the game keeps it: letters, digits, spaces, - _ and . only,
## runs of spaces folded, trimmed, at most NAME_LAST characters. "" when nothing is left.
## A label only: in a match everyone is Daemon-<slot> (C14).
static func clean_name(text: String) -> String:
	var out := ""
	for i in text.length():
		var c := text.unicode_at(i)
		var ok := (c >= 0x30 and c <= 0x39) or (c >= 0x41 and c <= 0x5A) or (c >= 0x61 and c <= 0x7A) or c == 0x2D or c == 0x5F or c == 0x2E or c == 0x20
		if not ok:
			continue
		if c == 0x20 and (out.is_empty() or out.ends_with(" ")):
			continue
		out += char(c)
	return out.strip_edges().left(NAME_LAST).strip_edges()


## The bind of a rebindable action: the player's, or its default.
func bind(action: String) -> String:
	return _binds.get(action, Controls.default_bind(action))


## The player's binds only, {action: bind}, for Controls.apply_binds and conflicts.
func binds() -> Dictionary:
	return _binds.duplicate()


## Binds `action` to `event`. "" when it took; otherwise why not, in Controls' words (a
## Ctrl+Alt combo, any Ctrl, Alt or Super chord, Esc, not a key or button), and nothing
## changes. A bind another action already uses is taken and shown as a conflict.
func set_bind(action: String, event: InputEvent) -> String:
	if not Controls.rebindable(action):
		return Controls.UNKNOWN_REFUSED
	var why := Controls.bind_problem(event)
	if why != "":
		return why
	var text := Controls.bind_of(event)
	if text == Controls.default_bind(action):
		_binds.erase(action)
	else:
		_binds[action] = text
	changed.emit(BINDS, action)
	return ""


## Every action's bind back to its default.
func reset_binds() -> void:
	_binds = {}
	changed.emit(BINDS, "")


## {action: [what else uses its input]} for every action in conflict.
func conflicts() -> Dictionary:
	return Controls.conflicts(_binds)


## Bloom, shadows and the code rain as set now: {bloom, shadows, code_rain} (C16b).
func quality() -> Dictionary:
	return {"bloom": value("video", "bloom"), "shadows": value("video", "shadows"), "code_rain": value("video", "code_rain")}


## Every graphics setting as set now (A4): the preset's name, each of its keys, and the two
## post effects, {key: value} for each of GRAPHICS_KEYS.
func graphics() -> Dictionary:
	var out := {}
	for key in GRAPHICS_KEYS:
		out[key] = value("video", key)
	return out
