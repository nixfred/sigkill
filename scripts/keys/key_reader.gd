class_name KeyReader
extends RefCounted
## Keybind gunplay's real layer (W4, PRD 5.5): the player's own key binds, so the drills teach their actual desktop. Read
## only when the player has said yes (the same answer as the opener's real data, the visor's, the hunt's, the map's and
## the theme shift's: Settings, Privacy and AI, "opener data", with real-machine data on, never on a demo run; scripts/keys/
## keybind_gunplay.gd asks AuditVisor.real_gate_for()). Off by default: when it is off this is never called and nothing is
## read.
##
## What it reads, all of it: the bind files Omarchy's binds live in (FILES: Omarchy's own defaults first, then the player's
## overrides, so a later bind wins as it does on the desktop), each at most LARGEST bytes (a longer one is refused whole),
## at most LINES_MOST lines and BINDS_MOST binds in all. From each bind line it keeps two things: the key combo and the
## description the line gives it (cut to NAME_LONGEST, printable characters only). Never the command or dispatcher a bind
## runs, never a comment, never any other line; a line longer than LINE_LONGEST is skipped. Lines it knows:
##   Omarchy 4 (Lua)        o.bind("SUPER + W", "Close window", ...)   o.bind_toggle(...)   hl.unbind("SUPER + W")
##   Omarchy 3 (hyprlang)   bindd = SUPER, W, Close window, ...        unbind = SUPER, W
## It never writes, changes, reloads or switches any bind or any config, never calls the compositor (no dispatch, no
## keyword, no reload), never runs a command, never sends a key to anything. What it keeps lives only in memory while
## the mode runs.

## Where binds live, in the order a desktop applies them: Omarchy 4's defaults (shipped with it, the same on every
## machine), then Omarchy 3's, then the player's own overrides (under the home folder). A folder entry is every file in it
## ending as the entry says, in name order. Absolute entries are Omarchy's own install folders; the rest are under home.
const FILES := [
	"/usr/share/omarchy/default/hypr/bindings/*.lua",
	".local/share/omarchy/default/hypr/bindings/*.conf",
	".config/hypr/bindings.lua",
	".config/hypr/bindings.conf",
]
const LARGEST := 65536
const FILES_MOST := 16
const LINES_MOST := 4000
const BINDS_MOST := 600
const LINE_LONGEST := 600
const NAME_LONGEST := 48
const COMBO_LONGEST := 48

## Reads made this run, and the files opened (the tests' proof that an off mode reads nothing).
static var reads := 0
static var opened := PackedStringArray()

static var _lua_bind: RegEx
static var _lua_unbind: RegEx
static var _conf_bind: RegEx
static var _conf_unbind: RegEx


static func _patterns() -> void:
	if _lua_bind != null:
		return
	_lua_bind = RegEx.create_from_string("^\\s*o\\.bind(?:_toggle)?\\(\\s*\"([^\"]{1,%d})\"\\s*,\\s*(?:\"([^\"]{0,200})\"|nil)" % COMBO_LONGEST)
	_lua_unbind = RegEx.create_from_string("^\\s*(?:hl|o)\\.unbind\\(\\s*\"([^\"]{1,%d})\"" % COMBO_LONGEST)
	_conf_bind = RegEx.create_from_string("^\\s*bind([a-z]*)\\s*=\\s*([^,#]*),([^,#]*)(?:,([^,#]*))?")
	_conf_unbind = RegEx.create_from_string("^\\s*unbind\\s*=\\s*([^,#]*),([^,#]*)")


## The binds in one file's text: [{"combo", "name"} or {"unbind"}], combos as written, descriptions cleaned; nothing else
## of a line is kept. `lua` picks the form.
static func parse(text: String, lua: bool) -> Array:
	_patterns()
	var out: Array = []
	var lines := text.split("\n")
	for i in mini(lines.size(), LINES_MOST):
		var line := lines[i]
		if line.length() > LINE_LONGEST or out.size() >= BINDS_MOST:
			continue
		var stripped := line.strip_edges()
		if stripped.begins_with("--") or stripped.begins_with("#"):
			continue  # a comment: never read
		if lua:
			var m := _lua_bind.search(line)
			if m != null:
				out.append({"combo": m.get_string(1).strip_edges(), "name": clean(m.get_string(2))})
				continue
			var u := _lua_unbind.search(line)
			if u != null:
				out.append({"unbind": u.get_string(1).strip_edges()})
		else:
			var u := _conf_unbind.search(line)
			if u != null:
				out.append({"unbind": u.get_string(1) + "," + u.get_string(2)})
				continue
			var m := _conf_bind.search(line)
			if m != null:
				var flags := m.get_string(1)
				var combo := m.get_string(2) + "," + m.get_string(3)
				# Only a described bind (the `d` flag) names its action; any other line is a combo with no name.
				out.append({"combo": combo, "name": clean(m.get_string(4)) if flags.contains("d") else ""})
	return out


## A description as the game keeps it: printable characters only, cut to NAME_LONGEST.
static func clean(text: String) -> String:
	var out := ""
	for ch in text.strip_edges():
		var c := ch.unicode_at(0)
		if c >= 32 and c < 127:
			out += ch
	return out.strip_edges().left(NAME_LONGEST)


## The player's binds under home folder `home`, in the order their desktop applies them, or [] (none read). `files`: where
## to look (the tests hand in their own fixture's).
static func read(home: String, files: PackedStringArray = PackedStringArray(FILES)) -> Array:
	reads += 1
	var out: Array = []
	var taken := 0
	for entry in files:
		var path := entry if entry.is_absolute_path() else (home.path_join(entry) if home != "" else "")
		if path == "":
			continue
		for file in _expand(path):
			if taken >= FILES_MOST or out.size() >= BINDS_MOST:
				return out
			taken += 1
			opened.append(file.get_file())
			var text := RealOpenerData._read_small(file, LARGEST)
			if text == "":
				continue
			for b in parse(text, file.ends_with(".lua")):
				if out.size() < BINDS_MOST:
					out.append(b)
	return out


## A file entry's files: itself when it is there, or (`<folder>/*.<ext>`) the folder's regular files ending so, in name
## order. Nothing is followed or opened here.
static func _expand(path: String) -> PackedStringArray:
	var out := PackedStringArray()
	if path.get_file().begins_with("*."):
		var dir := path.get_base_dir()
		var ext := path.get_file().substr(1)
		if not DirAccess.dir_exists_absolute(dir):
			return out
		var names := DirAccess.get_files_at(dir)
		names.sort()
		for n in names:
			if n.ends_with(ext):
				out.append(dir.path_join(n))
	elif FileAccess.file_exists(path):
		out.append(path)
	return out
