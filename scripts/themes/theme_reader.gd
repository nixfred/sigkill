class_name ThemeReader
extends RefCounted
## The theme shift's real layer (W3, PRD 5.5): the player's active Omarchy theme as one more level, read only when the
## player has said yes (the same answer as the opener's real data, the visor's, the process hunt's and the folder map's:
## Settings, Privacy and AI, "opener data", with real-machine data on, never on a demo run; scripts/themes/theme_shift.gd
## asks AuditVisor.real_gate_for()). Off by default: when it is off this is never called and nothing is read.
##
## What it reads, all of it, and only what the opener already reads (C39, scripts/opener/real_opener_data.gd): the active
## theme's colors.toml (the first of RealOpenerData.THEME_FILES under the home folder that is there), at most
## RealOpenerData.THEME_LARGEST bytes (a longer file is refused whole), kept only for its colours (`#rrggbb` values and
## the mode, by ThemeColors.palette_from()), and whether a light.mode file stands beside it (asked, never opened). Not its
## name, not its folder, not its wallpaper or any other file of it. It never writes, switches or changes the theme or any
## desktop setting, never runs a command (no omarchy command, nothing at all), and keeps nothing after the run: the
## palette it makes lives only in memory while the mode runs.

## Reads made by any reader this run, and the files opened (the tests' proof that an off mode reads nothing, and that an
## on one opens one file).
static var reads := 0
static var opened := PackedStringArray()


## The player's own palette under home folder `home`, or null (none there, too big, unreadable, too low in contrast).
## `files`: where to look, under home (the tests hand in their own fixture's).
static func read(home: String, files: PackedStringArray = PackedStringArray(RealOpenerData.THEME_FILES)) -> OpenerPalette:
	reads += 1
	if home == "":
		return null
	for rel in files:
		var path := home.path_join(rel)
		if not FileAccess.file_exists(path):
			continue
		opened.append(rel)
		var text := RealOpenerData._read_small(path, RealOpenerData.THEME_LARGEST)
		if text == "":
			return null
		return ThemeColors.palette_from(text, FileAccess.file_exists(path.get_base_dir().path_join(RealOpenerData.LIGHT_FILE)))
	return null
