class_name FolderTree
extends RefCounted
## The shape both layers of the filesystem map hand over (W2, PRD 5.5): a folder as a Dictionary, made by node(), filled
## by the demo tree (scripts/fsmap/demo_folders.gd) or the read-only reader (scripts/fsmap/folder_reader.gd), and the
## helpers every part of the map shares. Data only: nothing here reads, writes or runs anything.
##
## A folder:
##   name       its name, as listed (home's own name is never kept: the map calls it HOME_NAME)
##   own_files  how many files stand directly in it (counted, never named, never opened)
##   own_size   their bytes, from stat-level sizes
##   kinds      {kind: count} of those files, by their name's extension only (KINDS)
##   dirs       its subfolders, biggest first
##   more       subfolders past the reader's caps, not listed
##   size       bytes in it and everything under it that was read (total())
##   files      files in it and under it that were read
##   partial    something under it was past a cap (depth, entries or time): size and files are "at least"
##   scanned    its own entries were listed (a folder at the depth cap is known by name only)

## What the map calls the root, whatever the player's home folder is named (its real name is the user's name: never
## shown, never kept).
const HOME_NAME := "home"
const KINDS := ["video", "audio", "image", "code", "docs", "other"]
const EXTENSIONS := {
	"video": ["mp4", "mkv", "webm", "mov", "avi", "m4v", "wmv", "flv", "mpg", "mpeg"],
	"audio": ["mp3", "flac", "ogg", "opus", "wav", "m4a", "aac", "aiff", "mid", "midi"],
	"image": ["png", "jpg", "jpeg", "gif", "webp", "svg", "bmp", "tif", "tiff", "heic", "avif", "psd", "xcf", "kra"],
	"code": ["js", "mjs", "cjs", "ts", "tsx", "jsx", "py", "rs", "go", "c", "h", "cpp", "hpp", "cc", "java", "kt", "rb", "lua", "sh", "gd", "gdshader", "json", "toml", "yaml", "yml", "lock", "zig", "cs", "swift", "php", "wasm", "map", "css", "scss", "html", "vue", "svelte"],
	"docs": ["txt", "md", "pdf", "doc", "docx", "odt", "rtf", "csv", "xls", "xlsx", "ods", "ppt", "pptx", "odp", "epub", "tex", "org"],
}


static func node(name: String) -> Dictionary:
	var kinds := {}
	for k in KINDS:
		kinds[k] = 0
	return {"name": name, "own_files": 0, "own_size": 0, "kinds": kinds, "dirs": [], "more": 0, "size": 0, "files": 0, "partial": false, "scanned": false, "hint": ""}


## A file's kind from its name's extension alone ("other" for anything else); the name is never kept.
static func kind_of_name(file_name: String) -> String:
	var dot := file_name.rfind(".")
	if dot <= 0:
		return "other"
	var ext := file_name.substr(dot + 1).to_lower()
	for k in EXTENSIONS:
		if (EXTENSIONS[k] as Array).has(ext):
			return k
	return "other"


## Sizes, file counts and partial marks summed up from the leaves; every folder's subfolders sorted biggest first.
static func total(n: Dictionary) -> void:
	var size: int = int(n["own_size"])
	var files: int = int(n["own_files"])
	var partial: bool = bool(n["partial"]) or not bool(n["scanned"]) or int(n["more"]) > 0
	for d in n["dirs"]:
		total(d)
		size += int(d["size"])
		files += int(d["files"])
		partial = partial or bool(d["partial"])
	n["size"] = size
	n["files"] = files
	n["partial"] = partial
	(n["dirs"] as Array).sort_custom(func(a, b): return [int(b["size"]), str(a["name"])] < [int(a["size"]), str(b["name"])])


## The node under `root` at `path` (names, home first not included), or {}.
static func find(root: Dictionary, path: PackedStringArray) -> Dictionary:
	var at := root
	for name in path:
		var next := {}
		for d in at.get("dirs", []):
			if str(d["name"]) == name:
				next = d
				break
		if next.is_empty():
			return {}
		at = next
	return at


## How many nodes `n` is, itself and every folder under it that has a node.
static func count(n: Dictionary) -> int:
	var c := 1
	for d in n.get("dirs", []):
		c += count(d)
	return c


## What most of a folder holds: its own files' commonest kind, else its subfolders' (summed one level down), else
## "empty".
static func kind_of(n: Dictionary) -> String:
	var counts := {}
	var own: Dictionary = n.get("kinds", {})
	var any := false
	for k in KINDS:
		counts[k] = int(own.get(k, 0))
		any = any or counts[k] > 0
	if not any:
		for d in n.get("dirs", []):
			var dk: Dictionary = d.get("kinds", {})
			for k in KINDS:
				counts[k] = int(counts[k]) + int(dk.get(k, 0))
				any = any or int(dk.get(k, 0)) > 0
	if not any:
		return "empty" if (n.get("dirs", []) as Array).is_empty() else str(n.get("hint", "other")) if str(n.get("hint", "")) != "" else "other"
	var best := "other"
	var most := -1
	for k in KINDS:
		if int(counts[k]) > most:
			most = int(counts[k])
			best = k
	return best


## Bytes as a person reads them: "0 B", "380 KB", "4.8 GB".
static func human_size(bytes: int) -> String:
	var units := ["B", "KB", "MB", "GB", "TB", "PB"]
	var v := float(maxi(bytes, 0))
	var u := 0
	while v >= 1024.0 and u < units.size() - 1:
		v /= 1024.0
		u += 1
	if u == 0:
		return "%d B" % int(v)
	return ("%.1f %s" % [v, units[u]]) if v < 10.0 else ("%d %s" % [roundi(v), units[u]])


## A count with its thousands marked: 48211 -> "48,211".
static func thousands(n: int) -> String:
	var s := str(absi(n))
	var out := ""
	while s.length() > 3:
		out = "," + s.right(3) + out
		s = s.left(s.length() - 3)
	return ("-" if n < 0 else "") + s + out


## The path as the map writes it: "home/Code/starfall" (never `~`, never the real home's name).
static func path_text(path: PackedStringArray) -> String:
	return "/".join(PackedStringArray([HOME_NAME]) + path)
