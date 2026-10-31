class_name IntroState
extends RefCounted
## The intro's first-launch state (C42), kept in the [intro] section of the game's one settings file, user://settings.cfg
## (scripts/settings/settings_file.gd), beside the privacy answers and the settings screen's own sections, which it never
## touches:
##   asked=true       the first-launch card was answered (its yes went to the privacy section's opener_real_data,
##                    through scripts/boot/guide_settings.gd; its no left that off)
##   played=true      the opener auto-played once and was watched to its end or skipped
##   skip_next=true   the player's "Skip the intro next time"
## A key that is missing or not a bool counts as false; a missing or damaged file is a first launch. The opener
## auto-plays only while it has been neither played nor marked to skip; the Esc menu's "Play the opener" always plays it.
## The unlocks' save (user://progress.cfg, C33) is a file of its own and is never read or written here.
##
## Headless runs (the tests, check.sh) never read or write the player's file: the arena hands no path ("") there, so
## nothing is asked and nothing auto-plays, and a test that wants the first launch hands in a file in its own folder.

const SettingsFile = preload("res://scripts/settings/settings_file.gd")

const SECTION := "intro"
const ASKED := "asked"
const PLAYED := "played"
const SKIP_NEXT := "skip_next"
const KEYS := [ASKED, PLAYED, SKIP_NEXT]


## {asked, played, skip_next} from the file at `path`; every one false when it is missing, damaged or not a bool, and
## for no path at all.
static func read(path: String) -> Dictionary:
	var out := {ASKED: false, PLAYED: false, SKIP_NEXT: false}
	if path == "":
		return out
	var section = SettingsFile.read(path).get(SECTION, {})
	if section is Dictionary:
		for key in KEYS:
			if section.get(key) is bool:
				out[key] = section[key]
	return out


## True when the first-launch card has not been answered yet (never for no path).
static func should_ask(path: String) -> bool:
	return path != "" and not read(path)[ASKED]


## True when the opener should play itself at this launch: not played yet, not marked to skip (never for no path).
static func should_autoplay(path: String) -> bool:
	if path == "":
		return false
	var state := read(path)
	return not state[PLAYED] and not state[SKIP_NEXT]


## The card answered. False, and nothing written, if the file cannot be written.
static func mark_asked(path: String) -> bool:
	return _save(path, ASKED, true)


## The first auto-play watched to its end or skipped.
static func mark_played(path: String) -> bool:
	return _save(path, PLAYED, true)


## "Skip the intro next time", on or off.
static func save_skip_next(on: bool, path: String) -> bool:
	return _save(path, SKIP_NEXT, on)


static func _save(path: String, key: String, value: bool) -> bool:
	if path == "" or not SettingsFile.usable_path(path):
		return false
	var state := read(path)
	state[key] = value
	return SettingsFile.write_sections(path, {SECTION: state})
