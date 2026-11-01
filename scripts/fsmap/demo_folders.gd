class_name DemoFolders
extends RefCounted
## The filesystem map's default layer (W2, PRD 5.5): a home folder the game makes up, believable and entirely fake, so
## the map works with zero reads of the player's machine. Every test and every capture uses only this. Nothing here
## reads, writes or runs anything; every name, size and count is the game's own.
##
## The same tree as the folder reader's (scripts/fsmap/folder_reader.gd), node for node: FolderTree's shape
## (scripts/fsmap/folder_tree.gd). Its node_modules folders are made from a list of invented package names, seeded,
## each with a few nested node_modules of its own, so the maze has names to wear.

## [name, files in it, their bytes, their kind, [children...]]: the files directly in each folder (counted, never
## named), their total size, what most of them are. Sizes in bytes.
const KB := 1024
const MB := 1024 * 1024
const GB := 1024 * 1024 * 1024
const TREE := ["home", 4, 18 * KB, "docs", [
	["Videos", 212, 61 * GB, "video", [
		["recordings", 41, 96 * GB, "video", [
			["raw", 18, 22 * GB, "video", []],
		]],
		["edits", 18, 22 * GB, "video", [
			["renders", 9, 7 * GB, "video", []],
		]],
		["phone", 380, 14 * GB, "video", []],
		["subtitles", 22, 380 * KB, "docs", []],
	]],
	["Music", 12, 220 * MB, "audio", [
		["albums", 0, 0, "audio", [
			["neon_tide", 14, 512 * MB, "audio", []],
			["glass_city", 11, 430 * MB, "audio", []],
			["night_drive", 16, 610 * MB, "audio", []],
			["low_orbit", 9, 380 * MB, "audio", []],
			["static_bloom", 12, 470 * MB, "audio", []],
		]],
		["stems", 64, 4800 * MB, "audio", []],
		["playlists", 9, 12 * KB, "docs", []],
	]],
	["Pictures", 46, 1200 * MB, "image", [
		["screenshots", 1820, 3100 * MB, "image", []],
		["wallpapers", 88, 640 * MB, "image", []],
		["camera", 0, 0, "image", [
			["2025", 940, 4600 * MB, "image", []],
			["2026", 610, 3000 * MB, "image", []],
		]],
	]],
	["Code", 2, 8 * KB, "docs", [
		["starfall", 9, 64 * KB, "code", [
			["src", 214, 3200 * KB, "code", [
				["engine", 96, 1900 * KB, "code", []],
				["ui", 58, 640 * KB, "code", []],
			]],
			["assets", 0, 0, "image", [
				["sprites", 640, 280 * MB, "image", []],
				["audio", 112, 410 * MB, "audio", []],
			]],
			["build", 22, 340 * MB, "other", []],
			["node_modules", 3, 1 * MB, "code", "packages:44"],
		]],
		["dotsite", 6, 40 * KB, "code", [
			["pages", 38, 220 * KB, "docs", []],
			["node_modules", 2, 400 * KB, "code", "packages:18"],
		]],
		["notes-app", 12, 90 * KB, "code", [
			["src", 44, 410 * KB, "code", []],
		]],
		["scratch", 3, 4 * KB, "code", []],
	]],
	["Documents", 18, 24 * MB, "docs", [
		["taxes", 0, 0, "docs", [
			["2024", 22, 18 * MB, "docs", []],
			["2025", 19, 16 * MB, "docs", []],
		]],
		["manuals", 64, 820 * MB, "docs", []],
		["letters", 31, 2100 * KB, "docs", []],
		["recipes", 57, 9 * MB, "docs", []],
	]],
	["Downloads", 340, 6800 * MB, "other", [
		["unzipped", 0, 0, "other", [
			["font-pack", 120, 46 * MB, "other", []],
			["sample-pack", 380, 1900 * MB, "audio", []],
		]],
		["archive", 76, 2200 * MB, "other", []],
	]],
	["Games", 0, 0, "other", [
		["saves", 48, 120 * MB, "other", []],
		["mods", 210, 3400 * MB, "other", []],
	]],
	["Desktop", 14, 40 * MB, "other", []],
	["Templates", 0, 0, "other", []],
]]

## Invented package names for the demo's node_modules: none of them is a real package's name on purpose.
const PACKAGES := [
	"left-pad-pro", "is-odd-ish", "is-even-ish", "noop3", "tiny-uuid4", "glob-of-globs", "deep-merge-deeper",
	"promise-promise", "callback-hell", "colors-again", "semver-ish", "micro-everything", "util-utils",
	"helper-helpers", "polyfill-all", "array-flat-flat", "string-of-strings", "emitter-emitter", "trash-lite",
	"kleur-ish", "chalkish", "debug-debug", "ms-ms", "once-twice", "wrappy-wrap", "inherits-all", "lodash-lite-lite",
	"has-flag-flag", "colour-maybe", "ansi-ansi", "strip-strip", "safe-buffer-ish", "core-of-cores", "path-is-path",
	"argv-maximal", "yargs-ish", "commander-ish", "mkdirp-p", "graceful-ish", "tslib-lite", "is-number-yes",
	"to-regex-regex", "fill-range-range", "picomatch-ish",
]
## A package in this many has a node_modules of its own (and so, deeper, on and on).
const NESTED_EVERY := 4

var root: Dictionary = {}


func _init() -> void:
	root = _make(TREE, 0)
	FolderTree.total(root)


static func _make(row: Array, depth: int) -> Dictionary:
	var node := FolderTree.node(str(row[0]))
	node["own_files"] = int(row[1])
	node["own_size"] = int(row[2])
	if int(row[1]) > 0:
		node["kinds"][str(row[3])] = int(row[1])
	node["hint"] = str(row[3])
	var kids = row[4]
	if kids is String and str(kids).begins_with("packages:"):
		node["dirs"] = _packages(int(str(kids).get_slice(":", 1)), hash(str(row[0])) + depth, depth + 1)
	else:
		for k in kids:
			node["dirs"].append(_make(k, depth + 1))
	node["scanned"] = true
	return node


## `count` packages, each with its few files of code, a share with a node_modules of their own down to a few levels.
static func _packages(count: int, seed: int, depth: int) -> Array:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	var out: Array = []
	for i in count:
		var name: String = PACKAGES[(i * 7 + absi(seed)) % PACKAGES.size()]
		var p := FolderTree.node(name)
		var files := rng.randi_range(6, 220)
		p["own_files"] = files
		p["own_size"] = files * rng.randi_range(2 * KB, 26 * KB)
		p["kinds"]["code"] = files
		p["hint"] = "code"
		p["scanned"] = true
		for d in rng.randi_range(0, 2):
			var sub := FolderTree.node(["lib", "dist", "src"][d])
			var n := rng.randi_range(4, 90)
			sub["own_files"] = n
			sub["own_size"] = n * rng.randi_range(1 * KB, 18 * KB)
			sub["kinds"]["code"] = n
			sub["hint"] = "code"
			sub["scanned"] = true
			p["dirs"].append(sub)
		if i % NESTED_EVERY == 0 and depth < 6:
			var nm := FolderTree.node("node_modules")
			nm["own_files"] = 1
			nm["own_size"] = 2 * KB
			nm["kinds"]["code"] = 1
			nm["hint"] = "code"
			nm["dirs"] = _packages(rng.randi_range(3, 7), seed * 31 + i, depth + 2)
			nm["scanned"] = true
			p["dirs"].append(nm)
		out.append(p)
	return out


## The node at `path` (names from home; [] is home), or {} for none. Always known: the whole tree is made up front.
func node_at(path: PackedStringArray) -> Dictionary:
	return FolderTree.find(root, path)


## Everything is ready at once: nothing to read.
func ready_for(_path: PackedStringArray) -> bool:
	return true


func want(_path: PackedStringArray) -> void:
	pass


func step(_delta: float) -> bool:
	return false


func drop() -> void:
	pass
