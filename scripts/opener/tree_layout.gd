class_name TreeLayout
extends RefCounted
## The city the opener falls through (C40; PRD 5.7, 0:50 to 1:10: "fall through the player's directory tree as a
## city (real folder names on towers, node_modules pit)"), worked out from the folder names and entry counts the
## opener took (OpenerData.folders() and folder_counts(): C39's reader, or the demo's) and from nothing else. Plain
## numbers, no nodes; the same city every time for the same names, since every roll is seeded by a hash of them.
## TreeFall (scripts/opener/tree_fall.gd) builds it.
##
## The shape: a shaft under the home folder, a funnel of round terraces stepping down and in, one for each level of
## the tree. The home folder is the monolith on the top rim, the terminal's screen on its face. Each top-level
## folder is a tower on the top terrace, in a slice of the circle as wide as what it holds; the folders in it stand
## on the next terrace down, in that slice, hung from its rim by a cable of light; and so on (4 levels: the
## reader's depth). How many entries a folder holds sets its tower: wider, taller, more windows lit, the reader's
## 200 a folder as big as it gets. One not counted stands dim; a hidden one short and dim, in the back row. The
## first node_modules is the pit at the bottom, a maze lit from below and deeper than the fog; any other is a maze
## tower. Towers with no name fill the rows behind and megastructures the dark beyond, and streams of code light
## pour down the shaft onto the terraces, so the city is never a few boxes in a void.
##
## Caps, whatever it is handed: it looks at the first MOST_GIVEN folders only (C39's reader hands over at most 128),
## ROOMS of them become towers (the shallow ones first), LABELS are named, at most PIECES boxes in all, CABLES cables
## and STREAMS streams; a name is cleaned and cut as the terminal's are (OpenerData.clean()), so it can never be more
## than plain text.

## The terraces, top down: the radius of each one's front row of towers, its height, and its tallest tower.
const RING_R := [150.0, 112.0, 82.0, 58.0]
const RING_Y := [-70.0, -190.0, -300.0, -395.0]
const RING_TALLEST := [118.0, 104.0, 88.0, 66.0]
## The terrace reaches this far in front of the front row and this far behind it.
const TERRACE_IN := 6.0
const TERRACE_OUT := 96.0
## The second row stands this much further out; the filler rows start at, and spread over, these.
const ROW_M := 17.0
const FILL_FROM := 44.0
const FILL_SPREAD := 46.0
## The pit: its radius, the rim terrace's height (where the fall lands) and how far down it goes.
const PIT_R := 30.0
const PIT_Y := -470.0
const PIT_DEEP := 640.0
## The home folder's monolith: where on the circle (toward -Z, so the camera starts facing it), the slice it keeps
## clear, its width, depth and top; the terminal's screen on its face, centred this high.
const HOME_ANGLE := -PI / 2.0
const HOME_SPAN := 0.62
const HOME_WIDTH := 72.0
const HOME_DEPTH := 34.0
const HOME_TOP := 112.0
const PANEL_Y := 20.0
const PANEL_H := 4.5
## The machine's ceiling: you are inside it.
const CEILING_Y := 150.0
## The megastructures in the dark beyond the top terrace: how many, how far, how deep they go.
const SKYLINE := 40
const SKYLINE_FROM := 262.0
const SKYLINE_SPREAD := 150.0
## Towers with no name behind the named ones, on each terrace.
const FILLERS := [44, 36, 30, 24]

## The caps.
const MOST_GIVEN := 512
const ROOMS := 96
const LABELS := 40
const PIECES := 1024
const CABLES := 96
const STREAMS := 28
## A tower label's widest name, in cells (the terminal's FOLDER_LONGEST is for a whole path); its size on each
## terrace (metres a pixel of its font: about 25 pixels tall where the fall sees it), and the step up between
## neighbours' names (in its font's pixels).
const LABEL_LONGEST := 24
const LABEL_PX := [0.065, 0.055, 0.045, 0.035]
const LABEL_STEP := 150.0

## A tower's size from its entries: the reader's most counted (200 a folder), and the widths and heights between.
const MOST_COUNTED := 200
const WIDTH := Vector2(9.0, 22.0)
const NARROWEST := 4.5
const HEIGHT_SHARE := Vector2(0.24, 0.88)
const LIT := Vector2(0.1, 0.62)
## A tower whose entries were not counted, and a hidden one, as shares of an ordinary one.
const UNCOUNTED_WIDTH := 11.0
const UNCOUNTED_HEIGHT := 0.3
const UNCOUNTED_LIT := 0.03
const HIDDEN_SCALE := 0.7

## What a tower is, for its look (TreeFall paints each kind its own way).
enum Kind { FOLDER, HIDDEN, UNCOUNTED, MAZE, FILLER, SKYLINE, HOME }
## A piece's flags: its roof edge lit brighter, and a spire.
const FLAG_ROOF := 1
const FLAG_SPIRE := 2

## Seeded from the names, plus this.
const SEED := 4040

## One per tower made from a folder, in the order placed: {"path", "name", "depth", "count", "kind", "angle",
## "radius" (its front face), "width", "height", "base", "top", "parent" (an index here, or -1), "label" (an
## index into labels, or -1)}.
var rooms: Array[Dictionary] = []
## Every box: {"at" (its centre), "size", "yaw", "lit" (share of windows lit), "kind", "seed" (0 to 1), "flags"}.
var pieces: Array[Dictionary] = []
## {"text", "at", "px" (its size: metres a pixel at its font size), "kind", "room"}.
var labels: Array[Dictionary] = []
## {"from", "to"}: a folder's rim hung to each folder in it.
var cables: Array[Dictionary] = []
## {"x", "z", "top", "bottom", "width", "seed"}: code light pouring down the shaft.
var streams: Array[Dictionary] = []
## The pit's folder ("" when there is no node_modules), and the label over it.
var pit_path := ""
## Folders given, and how many of them are not in the city (past MOST_GIVEN or ROOMS, empty or repeated names).
var given := 0
var left_out := 0
var roll_seed := SEED


## The city for `folders` (paths under the home folder, "code/homelab") and `counts` (entries each, -1 not counted;
## missing ones count as not counted), as OpenerData hands them over.
static func build(folders: PackedStringArray, counts: PackedInt32Array) -> TreeLayout:
	var layout := TreeLayout.new()
	layout._build(folders, counts)
	return layout


## The world position on terrace ring `radius` at `angle` (radians round the shaft, 0 toward +X), at height `y`.
static func on_ring(angle: float, radius: float, y: float) -> Vector3:
	return Vector3(cos(angle) * radius, y, sin(angle) * radius)


## The yaw that turns a box's -Z toward the shaft's axis from `angle`.
static func facing_in(angle: float) -> float:
	return PI / 2.0 - angle


## FNV-1a of `text`'s UTF-8 bytes: stable on every machine and every run.
static func hash_of(text: String) -> int:
	var h := 2166136261
	for b in text.to_utf8_buffer():
		h = ((h ^ b) * 16777619) & 0xffffffff
	return h


## The terrace a stream at `radius` from the axis pours onto (its height), or into the pit.
static func floor_under(radius: float) -> float:
	for k in RING_R.size():
		if radius > RING_R[k] - TERRACE_IN:
			return RING_Y[k]
	if radius > PIT_R:
		return PIT_Y
	return PIT_Y - PIT_DEEP * 0.5


func _build(all_folders: PackedStringArray, counts: PackedInt32Array) -> void:
	given = all_folders.size()
	var folders := all_folders.slice(0, MOST_GIVEN)
	var names := ""
	for path in folders:
		names += path + "\n"
	roll_seed = (hash_of(names) ^ SEED) & 0x7fffffff
	var chosen := _choose(folders, counts)
	_place(chosen)
	_home()
	for room in rooms:
		_tower_pieces(room)
	_label_rooms()
	_hang_cables()
	_fill()
	_pour()


# --- Which folders, in what order. ---

## The folders kept (the shallow ones first, at most ROOMS), each with its cleaned path, depth, count and parent,
## in the order they go round the circle: each top-level folder with everything in it after it, the hidden ones in
## the middle of the visible ones (opposite the monolith).
func _choose(folders: PackedStringArray, counts: PackedInt32Array) -> Array[Dictionary]:
	var all: Array[Dictionary] = []
	var seen := {}
	for i in folders.size():
		var path := OpenerData.clean(folders[i], OpenerData.FOLDER_LONGEST)
		path = path.trim_prefix("/").trim_suffix("/")
		if path == "" or seen.has(path):
			continue
		seen[path] = true
		var depth := mini(path.count("/"), RING_R.size() - 1)
		var base := path.get_file()
		all.append({"path": path, "base": base, "depth": depth, "count": counts[i] if i < counts.size() else -1, "hidden": _hidden(path), "order": i})
	var by_depth := all.duplicate()
	by_depth.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a["depth"] < b["depth"] or (a["depth"] == b["depth"] and a["order"] < b["order"]))
	var kept := {}
	for entry in by_depth.slice(0, ROOMS):
		kept[entry["path"]] = entry
	left_out = given - kept.size()
	# Each kept folder under its nearest kept ancestor (an orphan, whose ancestors are all missing, is a top-level one).
	var children := {"": []}
	for entry in all:
		if not kept.has(entry["path"]):
			continue
		var up := _ancestor(entry["path"], kept)
		entry["up"] = up
		if not children.has(up):
			children[up] = []
		children[up].append(entry)
	var out: Array[Dictionary] = []
	# Round the circle from beside the monolith: half the visible ones, the hidden ones (opposite the monolith, out
	# of the reveal's view), then the rest of the visible ones, so the screen is flanked by the player's own folders.
	var shown: Array = children[""].filter(func(e): return not e["hidden"])
	var half := ceili(shown.size() / 2.0)
	var tops: Array = shown.slice(0, half) + children[""].filter(func(e): return e["hidden"]) + shown.slice(half)
	for top in tops:
		_walk(top, children, out)
	return out


func _walk(entry: Dictionary, children: Dictionary, out: Array[Dictionary]) -> void:
	out.append(entry)
	for child in children.get(entry["path"], []):
		_walk(child, children, out)


static func _ancestor(path: String, kept: Dictionary) -> String:
	var up := path.get_base_dir()
	while up != "" and not kept.has(up):
		up = up.get_base_dir()
	return up


static func _hidden(path: String) -> bool:
	for part in path.split("/"):
		if part.begins_with("."):
			return true
	return false


# --- Where each goes. ---

## Each top-level folder its slice of the circle (outside the home folder's), as wide as one plus what it holds; the
## folders in it share its slice, on their own terrace, and so on down.
func _place(chosen: Array[Dictionary]) -> void:
	var index := {}
	var weight := {}
	for i in range(chosen.size() - 1, -1, -1):
		var entry: Dictionary = chosen[i]
		weight[entry["path"]] = 1.0 + weight.get(entry["path"], 0.0)
		var up: String = entry["up"]
		if up != "":
			weight[up] = weight.get(up, 0.0) + minf(weight[entry["path"]], 12.0)
	var from := HOME_ANGLE + HOME_SPAN * 0.5
	var span := TAU - HOME_SPAN
	var tops := chosen.filter(func(e): return e["up"] == "")
	_slices(tops, from, span, weight, chosen, index)
	var by_ring := {}
	for entry in chosen:
		var depth: int = entry["depth"]
		if not by_ring.has(depth):
			by_ring[depth] = []
		by_ring[depth].append(entry)
	for entry in chosen:
		var room := _room(entry, weight)
		room["parent"] = index.get(entry["up"], -1) if entry["up"] != "" else -1
		index[entry["path"]] = rooms.size()
		rooms.append(room)
	# Two towers too close on one terrace: every other one steps back a row.
	for depth in by_ring:
		var ring: Array = by_ring[depth]
		ring.sort_custom(func(a, b): return a["angle"] < b["angle"])
		var row := 0
		for i in ring.size():
			var room: Dictionary = rooms[index[ring[i]["path"]]]
			var gap := TAU
			if ring.size() > 1:
				var prev: Dictionary = ring[(i - 1 + ring.size()) % ring.size()]
				gap = wrapf(ring[i]["angle"] - prev["angle"], 0.0, TAU)
			var arc: float = gap * RING_R[depth]
			if arc < room["width"] + 3.0:
				row = 1 - row
				room["width"] = maxf(minf(room["width"], arc * 1.7), NARROWEST)
			else:
				row = 0
			room["radius"] = RING_R[depth] + row * ROW_M + (ROW_M if room["kind"] == Kind.HIDDEN else 0.0)


func _slices(entries: Array, from: float, span: float, weight: Dictionary, chosen: Array[Dictionary], index: Dictionary) -> void:
	var total := 0.0
	for entry in entries:
		total += weight[entry["path"]]
	var at := from
	for entry in entries:
		var share: float = span * weight[entry["path"]] / maxf(total, 1.0)
		entry["angle"] = at + share * 0.5
		var kids := chosen.filter(func(e): return e["up"] == entry["path"])
		if not kids.is_empty():
			_slices(kids, at, share, weight, chosen, index)
		at += share


func _room(entry: Dictionary, _weight: Dictionary) -> Dictionary:
	var depth: int = entry["depth"]
	var count: int = entry["count"]
	var h := hash_of(entry["path"])
	var roll := float(h % 1000) / 1000.0
	var kind := Kind.FOLDER
	var width := UNCOUNTED_WIDTH
	var height: float = RING_TALLEST[depth] * UNCOUNTED_HEIGHT
	var lit := UNCOUNTED_LIT
	if count >= 0:
		var s := clampf(log(1.0 + count) / log(1.0 + MOST_COUNTED), 0.0, 1.0)
		width = lerpf(WIDTH.x, WIDTH.y, s)
		height = RING_TALLEST[depth] * lerpf(HEIGHT_SHARE.x, HEIGHT_SHARE.y, pow(s, 0.8)) * lerpf(0.88, 1.12, roll)
		lit = lerpf(LIT.x, LIT.y, s)
	else:
		kind = Kind.UNCOUNTED
	if entry["hidden"]:
		kind = Kind.HIDDEN
		width *= HIDDEN_SCALE
		height *= HIDDEN_SCALE * 0.85
		lit *= 0.5
	if entry["base"] == "node_modules":
		kind = Kind.MAZE
		if pit_path == "":
			pit_path = entry["path"]
	height = minf(height, minf(RING_TALLEST[depth], headroom(depth)))
	return {"path": entry["path"], "name": OpenerData.clean(entry["base"], LABEL_LONGEST) + "/", "depth": depth, "count": count, "kind": kind, "angle": entry["angle"], "radius": RING_R[depth], "width": width, "height": height, "base": RING_Y[depth], "top": RING_Y[depth] + height, "lit": lit, "seed": h, "parent": -1, "label": -1}


# --- The towers. ---

## A tower as boxes: one to three stacked, each set back from the one under it, now and then a spire. The pit's
## folder is no tower: it is the pit, its name over it.
func _tower_pieces(room: Dictionary) -> void:
	if room["path"] == pit_path:
		room["radius"] = PIT_R
		room["top"] = PIT_Y
		return
	var h: int = room["seed"]
	var tiers := 1 + (h >> 4) % 3
	var shares: Array = [[1.0], [0.62, 0.38], [0.5, 0.3, 0.2]][tiers - 1]
	var width: float = room["width"]
	var depth_m: float = width * lerpf(0.8, 1.15, float((h >> 8) % 100) / 100.0)
	var y: float = room["base"]
	var angle: float = room["angle"]
	for i in tiers:
		var tall: float = room["height"] * shares[i]
		var w := width * (1.0 - 0.2 * i)
		var d := depth_m * (1.0 - 0.2 * i)
		var centre := on_ring(angle, room["radius"] + depth_m * 0.5, y + tall * 0.5)
		_piece(centre, Vector3(w, tall, d), facing_in(angle), room["lit"], room["kind"], h + i, FLAG_ROOF if i == tiers - 1 else 0)
		y += tall
	# A spire now and then, never up through the terrace above (or the ceiling).
	var room_left := headroom(room["depth"]) - (y - float(room["base"]))
	if (h >> 12) % 3 == 0 and room["kind"] != Kind.HIDDEN and room_left > 4.0:
		var spire: float = minf(room["height"] * 0.22, room_left)
		_piece(on_ring(angle, room["radius"] + depth_m * 0.5, y + spire * 0.5), Vector3(0.7, spire, 0.7), facing_in(angle), 0.0, room["kind"], h + 7, FLAG_SPIRE)
		y += spire
	room["top"] = y


## How tall a tower on terrace `depth` may stand, spire and all: under the terrace above, or the ceiling.
static func headroom(depth: int) -> float:
	if depth == 0:
		return CEILING_Y - 30.0 - RING_Y[0]
	return RING_Y[depth - 1] - RING_Y[depth] - 8.0


func _piece(at: Vector3, size: Vector3, yaw: float, lit: float, kind: int, roll: int, flags: int) -> void:
	if pieces.size() >= PIECES:
		return
	pieces.append({"at": at, "size": size, "yaw": yaw, "lit": lit, "kind": kind, "seed": float(posmod(roll * 2654435761, 1000)) / 1000.0, "flags": flags})


## The home folder: the monolith on the top rim, its face toward the axis, the screen on it.
func _home() -> void:
	var bottom: float = RING_Y[0] - 12.0
	var centre := on_ring(HOME_ANGLE, RING_R[0] + HOME_DEPTH * 0.5, (bottom + HOME_TOP) * 0.5)
	_piece(centre, Vector3(HOME_WIDTH, HOME_TOP - bottom, HOME_DEPTH), facing_in(HOME_ANGLE), 0.0, Kind.HOME, SEED, FLAG_ROOF)


## Where the screen sits: its centre on the monolith's face, and the way the face looks (toward the axis).
static func panel_at() -> Vector3:
	return on_ring(HOME_ANGLE, RING_R[0] - 0.02, PANEL_Y)


static func panel_facing() -> Vector3:
	return -on_ring(HOME_ANGLE, 1.0, 0.0)


# --- Names, cables, fill and light. ---

## A name over the tower of each of the first LABELS folders, the top-level visible ones first, the hidden last.
func _label_rooms() -> void:
	var order := range(rooms.size())
	order.sort_custom(func(a: int, b: int) -> bool: return _label_rank(rooms[a]) < _label_rank(rooms[b]) or (_label_rank(rooms[a]) == _label_rank(rooms[b]) and a < b))
	for i in order:
		if labels.size() >= LABELS:
			break
		var room: Dictionary = rooms[i]
		if room["name"] == "/":
			continue
		room["label"] = labels.size()
		# Names a step or two higher in turn, so the names of neighbours seen edge-on never run together.
		var px: float = LABEL_PX[room["depth"]]
		var at := on_ring(room["angle"], room["radius"] - 1.5, room["top"] + px * (60.0 + LABEL_STEP * (i % 3)))
		if room["path"] == pit_path:
			px = PIT_LABEL_PX
			at = Vector3(0.0, PIT_Y + PIT_LABEL_UP, 0.0)
		labels.append({"text": room["name"], "at": at, "px": px, "kind": room["kind"], "room": i})


static func _label_rank(room: Dictionary) -> int:
	return room["depth"] + (10 if room["kind"] == Kind.HIDDEN else 0)


## A cable from the rim in front of each folder down to the top of each folder in it.
func _hang_cables() -> void:
	for room in rooms:
		if cables.size() >= CABLES:
			return
		var up: int = room["parent"]
		if up < 0:
			continue
		var parent: Dictionary = rooms[up]
		var from := on_ring(parent["angle"], RING_R[parent["depth"]] - TERRACE_IN, RING_Y[parent["depth"]])
		var to := on_ring(room["angle"], room["radius"] + 1.0, room["top"])
		if room["path"] == pit_path:
			to = on_ring(room["angle"], PIT_R, PIT_Y)
		if to.y < from.y:
			cables.append({"from": from, "to": to})


## Towers with no name in the rows behind, and the megastructures in the dark beyond.
func _fill() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = roll_seed
	for k in FILLERS.size():
		var n: int = FILLERS[k]
		for i in n:
			var angle := TAU * (i + rng.randf_range(0.15, 0.85)) / n
			if k == 0 and absf(wrapf(angle - HOME_ANGLE, -PI, PI)) < HOME_SPAN * 0.5 + 0.12:
				continue
			var width := rng.randf_range(8.0, 21.0)
			var tall: float = RING_TALLEST[k] * rng.randf_range(0.35, 1.0)
			var radius: float = RING_R[k] + FILL_FROM + rng.randf() * FILL_SPREAD
			_piece(on_ring(angle, radius + width * 0.5, RING_Y[k] + tall * 0.5), Vector3(width, tall, width * rng.randf_range(0.8, 1.2)), facing_in(angle), rng.randf_range(0.02, 0.2), Kind.FILLER, rng.randi(), FLAG_ROOF)
	for i in SKYLINE:
		var angle := TAU * (i + rng.randf_range(0.1, 0.9)) / SKYLINE
		var width := rng.randf_range(22.0, 52.0)
		var top := rng.randf_range(10.0, CEILING_Y - 8.0) if i % 4 != 0 else CEILING_Y
		var bottom := PIT_Y - PIT_DEEP * 0.4
		var radius := SKYLINE_FROM + rng.randf() * SKYLINE_SPREAD
		_piece(on_ring(angle, radius, (top + bottom) * 0.5), Vector3(width, top - bottom, width * rng.randf_range(0.7, 1.3)), facing_in(angle), rng.randf_range(0.03, 0.12), Kind.SKYLINE, rng.randi(), FLAG_ROOF)


## Streams of code light falling from the ceiling, each onto the terrace under it or into the pit, kept clear of
## the camera's way back from the screen and down the shaft (TreeFall's path) and of where it lands.
func _pour() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = roll_seed + 1
	var tries := 0
	while streams.size() < STREAMS and tries < STREAMS * 8:
		tries += 1
		var angle := rng.randf() * TAU
		var radius := 19.0 + 8.0 * rng.randf() if streams.size() % 5 == 0 else rng.randf_range(30.0, 138.0)
		var at := on_ring(angle, radius, 0.0)
		if absf(at.x) < 14.0 and at.z < 24.0:
			continue
		var inner := on_ring(LAND_ANGLE, 8.0, 0.0)
		var landing := on_ring(LAND_ANGLE, LAND_R + 6.0, 0.0)
		if Geometry2D.get_closest_point_to_segment(Vector2(at.x, at.z), Vector2(inner.x, inner.z), Vector2(landing.x, landing.z)).distance_to(Vector2(at.x, at.z)) < 12.0:
			continue
		streams.append({"x": at.x, "z": at.z, "top": CEILING_Y, "bottom": floor_under(radius), "width": rng.randf_range(1.2, 3.2), "seed": rng.randf()})


## Where the fall lands: on the pit's rim terrace, this far out, this far round (TreeFall faces it toward the axis):
## the fall starts on the far side of the axis from the screen (+Z) and turns 1.1 of a half turn on the way down.
const LAND_R := 40.0
const LAND_ANGLE := PI / 2.0 + 1.1 * PI
## The pit's name: its size, and how high over the rim.
const PIT_LABEL_PX := 0.05
const PIT_LABEL_UP := 16.0
