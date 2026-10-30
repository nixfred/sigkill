extends RefCounted
## Puts the settings that belong to the engine into effect (C16b): the audio buses and their
## volumes, the window mode, vsync, the frame cap and the 3D resolution scale, and the key
## binds (through scripts/controls.gd). The boot screen applies them at launch and the arena
## again when it loads and on every change. The rest is read where it is used: the player
## (look, aim, crouch, field of view, shake and the speed effect), the crosshair, the
## colour filter, the round HUD's subtitles, the arena's quality preset and the net HUD.
##
## Headless runs (tests, check.sh) never touch the window, vsync or the frame cap, so a
## test's fixed frame rate is never capped and no window is ever made or changed.
##
## The version (the pre-alpha drop): project.godot's application/config/version, shown small in the
## boot screen's and the menu's corner and in the window's title, which is set with the display.

const Controls = preload("res://scripts/controls.gd")

## The buses the game's sounds go to, under Master. Made at run time when missing.
const EFFECTS := "Effects"
const MUSIC := "Music"
const ANNOUNCER := "Announcer"
const MASTER := "Master"
## Bus name -> the audio setting that sets its volume.
const VOLUMES := {MASTER: "master", EFFECTS: "effects", MUSIC: "music", ANNOUNCER: "announcer"}
const SILENT_DB := -80.0
const WINDOW_MODES := {
	"windowed": DisplayServer.WINDOW_MODE_WINDOWED,
	"fullscreen": DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN,
	"borderless": DisplayServer.WINDOW_MODE_FULLSCREEN,
}


static func apply_all(s: GameSettings, tree: SceneTree) -> void:
	apply_audio(s)
	apply_display(s, tree)
	Controls.apply_binds(s.binds())


## The game's version from project.godot ("0.33.0-prealpha"), or "" if it has none.
static func version() -> String:
	return str(ProjectSettings.get_setting("application/config/version", ""))


## The version as the corners show it: "v0.33.0-prealpha", or "" if there is none.
static func version_tag() -> String:
	return "v" + version() if version() != "" else ""


## The window's title: the game's name and its version.
static func window_title() -> String:
	return ("%s %s" % [ProjectSettings.get_setting("application/config/name", "SIGKILL"), version_tag()]).strip_edges()


## Makes Effects, Music and Announcer under Master if they are missing; never removes one.
static func ensure_buses() -> void:
	for bus in [EFFECTS, MUSIC, ANNOUNCER]:
		if AudioServer.get_bus_index(bus) < 0:
			AudioServer.add_bus()
			var at := AudioServer.bus_count - 1
			AudioServer.set_bus_name(at, bus)
			AudioServer.set_bus_send(at, MASTER)


## Each bus's volume from its setting, linear 0 to 1; 0 mutes it.
static func apply_audio(s: GameSettings) -> void:
	ensure_buses()
	for bus in VOLUMES:
		var at := AudioServer.get_bus_index(bus)
		var linear: float = s.value("audio", VOLUMES[bus])
		AudioServer.set_bus_volume_db(at, linear_to_db(linear) if linear > 0.0 else SILENT_DB)
		AudioServer.set_bus_mute(at, linear <= 0.0)


## The 3D resolution scale always; the window's title, mode, vsync and frame cap outside headless runs.
static func apply_display(s: GameSettings, tree: SceneTree) -> void:
	if tree != null and tree.root != null:
		tree.root.scaling_3d_scale = s.value("video", "resolution_scale")
	if DisplayServer.get_name() == "headless":
		return
	if tree != null and tree.root != null:
		tree.root.title = window_title()
	Engine.max_fps = s.value("video", "fps_cap")
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED if s.value("video", "vsync") else DisplayServer.VSYNC_DISABLED)
	var mode: DisplayServer.WindowMode = WINDOW_MODES[s.value("video", "window_mode")]
	if DisplayServer.window_get_mode() != mode:
		DisplayServer.window_set_mode(mode)
