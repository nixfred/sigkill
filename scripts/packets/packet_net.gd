class_name PacketNet
extends Node3D
## The packet tracer's world (W5, PRD 5.5): the network as floating islands in a dark void, joined by glowing links. Built
## in code from the invented table (scripts/packets/net_book.gd) when the mode stages the arena (stage(), as the ruins'
## stage does: the arena's own level goes, this goes in its place, the player at the first island).
##
## An island is a machine: a deck of black glass with a lit grid and circuit traces in its accent, its rim burning, over a
## stepped underside of dark crystal hanging into the void, veined and dripping light; on the deck the machine itself, each
## kind its own silhouette: the laptop (a keyboard deck under a giant open lid, its screen a terminal running the trace),
## the router (a squat box of blinking ports under a lantern on a mast and a crown of antennas), the rack (aisles of
## server racks, their faces alive with status lights, cable trays overhead), the board (an edge board: a big chip under a
## finned heatsink, smaller chips, capacitors, a row of header pins), the NAS (a wall of drive bays, platters spinning in
## two open stacks), the dish (a relay dish on its pylon, rings of signal pulsing off its feed), the core (the trace's last
## hop: a wide deck ringed with port pylons over a great red spike). Its name and address float over it. A port is a lit
## pad under a gate on its rim, one for each link, labelled with where it goes.
##
## A link (scripts/packets/net_link.gd) arches from port to port, its packets streaming down it (one MultiMesh for every
## packet in the network, each a slab of light in its protocol's colour); a link going bad stalls its packets, and a drop
## spills them tumbling into the void, a red flash and RST where it tore.
##
## Around it all, so the void is never plain: a sky of the globe's faint lines and far machines (shaders/net_void.gdshader),
## the bus far below (a vast grid, pulses racing down it, fading into the fog), dozens of far islands with their own links
## streaming, three backbone cables arcing across the sky and columns of data rising off the bus.
##
## Visual and collision only: the decks and the bigger machines are solid (cover), nothing else is. Nothing here reads
## anything or touches any network.

const IslandShader = preload("res://shaders/net_island.gdshader")
const LinkShader = preload("res://shaders/net_link.gdshader")
const VoidShader = preload("res://shaders/net_void.gdshader")
const PacketShader = preload("res://shaders/net_packet.gdshader")
const GreyBlock = preload("res://scripts/grey_block.gd")
const Palette = preload("res://scripts/palette.gd")

const NODE_NAME := "PacketNet"
const GROUP := &"packet_net"
## The arena's nodes that go, besides every greybox block (as the ruins' stage).
const GOES := ["ArenaArt", "Skyline", "RoomLight"]
const DECK_T := 1.2
const PORT_IN := 1.8
const PORT_R := 1.5
const SPOT_STEP := 2.2
const SPOT_MARGIN := 2.0
const SPOTS_MOST := 28
## The packets drawn: as many a link as fit its length at its protocol's gap, at most PACKETS_A_LINK; and the spill's.
const PACKETS_A_LINK := 22
const SPILL_MOST := 140
const SPILL_S := 2.4
const PACKET_SIZE := Vector3(0.55, 0.2, 0.95)
## Where the bus lies, under everything.
const BUS_Y := -70.0
const DECOR_ISLANDS := 34
const DECOR_LINKS := 18

var islands: Array = []
var links: Array = []
var environment: Environment = null
var sun: DirectionalLight3D = null
var _box: BoxMesh
var _cyl: CylinderMesh
var _cone: CylinderMesh
var _mat: ShaderMaterial
var _link_mat: ShaderMaterial
var _packets: MultiMeshInstance3D
var _slots := PackedInt32Array()
var _spill: Array = []
var _last_state := {}
var _labels := {}
var _flash: OmniLight3D
var _flash_t := -1.0
var _spinners: Array = []
var _pulses: Array = []
var _clock := 0.0


## Stands arena scene `main` in the network: the arena's own level goes, the network is built in its place, the player
## stands on the first island (where a fall puts it back, until the mode moves it on), the spawn markers and the arena's
## daemons on its deck. Returns the network, or null (no arena).
static func stage(main: Node3D) -> PacketNet:
	var arena := main.get_node_or_null("Arena") as Node3D
	if arena == null:
		return null
	for child in arena.get_children():
		if child.get_script() == GreyBlock or GOES.has(String(child.name)):
			arena.remove_child(child)
			child.free()
	var net := PacketNet.new()
	var we := arena.get_node_or_null("WorldEnvironment") as WorldEnvironment
	if we != null and we.environment != null:
		we.environment = we.environment.duplicate(true)
		net.environment = we.environment
	net.sun = main.get_node_or_null("Sun") as DirectionalLight3D
	arena.add_child(net)
	var start := net.start_point()
	var player := main.get_node_or_null("Player") as Node3D
	if player != null and player.has_method("set_spawn"):
		player.set_spawn(Transform3D(Basis(Vector3.UP, net.start_yaw()), start))
	var spawns := arena.get_node_or_null("Spawns")
	var spots: PackedVector3Array = net.islands[0]["spots"]
	if spawns != null:
		for i in spawns.get_child_count():
			var marker := spawns.get_child(i) as Node3D
			if marker != null and not spots.is_empty():
				marker.global_position = spots[i % spots.size()] + Vector3.UP * 0.95
	var targets := arena.get_node_or_null("Targets")
	if targets != null:
		for i in targets.get_child_count():
			var dummy := targets.get_child(i) as Node3D
			if dummy != null and not spots.is_empty():
				dummy.global_position = spots[(spots.size() - 1 - i) % spots.size()]
				var brain = dummy.get("brain")
				if brain != null:
					brain.take_home()
	return net


static func of(node: Node) -> PacketNet:
	if node == null or not node.is_inside_tree():
		return null
	for n in node.get_tree().get_nodes_in_group(GROUP):
		if not n.is_queued_for_deletion():
			return n as PacketNet
	return null


func _init() -> void:
	name = NODE_NAME
	top_level = true
	_box = BoxMesh.new()
	_box.size = Vector3.ONE
	_cyl = CylinderMesh.new()
	_cyl.top_radius = 0.5
	_cyl.bottom_radius = 0.5
	_cyl.height = 1.0
	_cyl.radial_segments = 16
	_cyl.rings = 1
	_cone = CylinderMesh.new()
	_cone.top_radius = 0.5
	_cone.bottom_radius = 0.02
	_cone.height = 1.0
	_cone.radial_segments = 6
	_cone.rings = 1
	_mat = ShaderMaterial.new()
	_mat.shader = IslandShader
	_link_mat = ShaderMaterial.new()
	_link_mat.shader = LinkShader
	for i in NetBook.MACHINES.size():
		_build_island(i)
	for i in NetBook.LINKS.size():
		_build_link(i)
	_build_packets()
	_build_background()
	_flash = OmniLight3D.new()
	_flash.name = "DropFlash"
	_flash.light_color = Color(1.0, 0.2, 0.25)
	_flash.omni_range = 26.0
	_flash.light_energy = 0.0
	_flash.shadow_enabled = false
	add_child(_flash)


func _ready() -> void:
	add_to_group(GROUP)
	_dress_environment()


# --- Where things are (for the mode). ---

func island_index(id: String) -> int:
	for i in islands.size():
		if islands[i]["id"] == id:
			return i
	return -1


## The middle of machine `i`'s deck (its top).
func top(i: int) -> Vector3:
	return islands[i]["at"]


func spots(i: int) -> PackedVector3Array:
	return islands[i]["spots"]


## Where the player stands to begin: the laptop's deck, in front of its lid, facing the way out.
func start_point() -> Vector3:
	return top(0) + Vector3(0.0, 0.95, 3.5)


func start_yaw() -> float:
	var out: NetLink = links[NetBook.forward_from(islands[0]["id"])]
	var to := out.p3 - start_point()
	return atan2(-to.x, -to.z)


## The port of link `li` on machine `id`'s island (its pad's middle, on the deck).
func port(li: int, id: String) -> Vector3:
	return islands[island_index(id)]["ports"].get(li, top(island_index(id)))


## The island under (or nearest over) `p`, by its deck's footprint and a few metres up; -1 when over the void.
func island_under(p: Vector3) -> int:
	for i in islands.size():
		var at: Vector3 = islands[i]["at"]
		var half: Vector2 = islands[i]["half"]
		if absf(p.x - at.x) <= half.x + 0.6 and absf(p.z - at.z) <= half.y + 0.6 and p.y > at.y - 3.0 and p.y < at.y + 12.0:
			return i
	return -1


## The lowest deck in the network: a fall far below it is lost.
func lowest() -> float:
	var y := INF
	for isl in islands:
		y = minf(y, (isl["at"] as Vector3).y)
	return y


# --- Building. ---

## A part of the world: a unit mesh (box, cylinder, cone) scaled to `size` at `at` (island-local, or world for `parent`
## of the net itself), drawn by the island shader as `part`, solid (a box shape on `body`) when asked.
func _piece(parent: Node3D, mesh: Mesh, at: Vector3, size: Vector3, part: int, accent: Color, body: StaticBody3D = null, basis: Basis = Basis.IDENTITY, energy: float = 1.0) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = _mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.gi_mode = GeometryInstance3D.GI_MODE_DISABLED
	mi.transform = Transform3D(basis * Basis.from_scale(size), at)
	mi.set_instance_shader_parameter("accent", accent)
	mi.set_instance_shader_parameter("box", size)
	mi.set_instance_shader_parameter("part", float(part))
	mi.set_instance_shader_parameter("seed", fmod(at.x * 0.37 + at.z * 0.71 + at.y, 97.0))
	mi.set_instance_shader_parameter("energy", energy)
	parent.add_child(mi)
	if body != null:
		var shape := CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size = size
		shape.shape = box
		shape.transform = Transform3D(basis, at)
		body.add_child(shape)
	return mi


func _build_island(i: int) -> void:
	var m: Dictionary = NetBook.MACHINES[i]
	var at: Vector3 = m["at"]
	var half: Vector2 = m["size"]
	var accent: Color = m["accent"]
	var root := Node3D.new()
	root.name = "Island_%s" % m["id"]
	root.position = at
	add_child(root)
	var body := StaticBody3D.new()
	body.name = "Deck"
	body.collision_layer = 1
	body.collision_mask = 0
	root.add_child(body)
	var isl := {"id": m["id"], "i": i, "at": at, "half": half, "node": root, "body": body, "ports": {}, "gates": {}, "foot": [], "spots": PackedVector3Array(), "accent": accent, "kind": m["kind"]}
	islands.append(isl)
	# The deck, its rim, and the stepped crystal under it.
	_piece(root, _box, Vector3(0.0, -DECK_T * 0.5, 0.0), Vector3(half.x * 2.0, DECK_T, half.y * 2.0), 0, accent, body)
	var tier := Vector2(half.x * 2.0, half.y * 2.0)
	var y := -DECK_T
	var r := _rng("under:%s" % m["id"])
	for k in 3:
		tier *= 0.72 - 0.06 * k
		var h := 2.2 + 1.2 * k + r.randf() * 1.0
		var off := Vector3(r.randf_range(-1.0, 1.0) * half.x * 0.12, 0.0, r.randf_range(-1.0, 1.0) * half.y * 0.12)
		_piece(root, _box, off + Vector3(0.0, y - h * 0.5, 0.0), Vector3(tier.x, h, tier.y), 1, accent)
		y -= h
	var spike := 7.0 + r.randf() * 5.0 + (10.0 if m["kind"] == "core" else 0.0)
	_piece(root, _cone, Vector3(0.0, y - spike * 0.5, 0.0), Vector3(minf(tier.x, tier.y) * 1.25, spike, minf(tier.x, tier.y) * 1.25), 1, accent.lerp(Color(1.0, 0.1, 0.2), 0.6 if m["kind"] == "core" else 0.0))
	for k in 4:
		var a := TAU * float(k) / 4.0 + r.randf() * 0.8
		var len := 3.0 + r.randf() * 5.0
		var p := Vector3(cos(a) * half.x * 0.55, -DECK_T - len * 0.5 - 0.4, sin(a) * half.y * 0.55)
		_piece(root, _cone, p, Vector3(1.6, len, 1.6), 1, accent)
	match str(m["kind"]):
		"laptop":
			_laptop(isl)
		"router":
			_router(isl)
		"rack":
			_rack(isl)
		"board":
			_board(isl)
		"nas":
			_nas(isl)
		"dish":
			_dish(isl)
		"core":
			_core(isl)
	# Its name and address over it, readable from the next island.
	var tag := Label3D.new()
	tag.name = "Name"
	tag.font = Palette.mono_font()
	tag.text = "%s\n%s" % [m["id"], NetBook.address(m)]
	tag.font_size = 96
	tag.pixel_size = 0.03
	tag.outline_size = 18
	tag.outline_modulate = Color(0, 0, 0, 0.85)
	tag.modulate = accent.lerp(Color.WHITE, 0.35) * 1.4
	tag.shaded = false
	tag.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y
	tag.position = Vector3(0.0, 9.5 if m["kind"] != "core" else 13.0, 0.0)
	# Read from the islands round it; out of the way on its own deck.
	tag.visibility_range_begin = maxf(half.x, half.y) + 14.0
	tag.visibility_range_begin_margin = 6.0
	tag.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_SELF
	root.add_child(tag)
	isl["label"] = tag
	# Its beacon: a shaft of its light straight up off a back corner of the deck, so every machine reads across the void.
	var beacon := _piece(root, _box, Vector3(-half.x + 0.8, 40.0, -half.y + 0.8), Vector3(0.35, 80.0, 0.35), 3, accent, null, Basis.IDENTITY, 0.55)
	beacon.name = "Beacon"
	beacon.visibility_range_begin = maxf(half.x, half.y) + 10.0
	var lamp := OmniLight3D.new()
	lamp.name = "Lamp"
	lamp.light_color = accent.lerp(Color.WHITE, 0.25)
	lamp.omni_range = maxf(half.x, half.y) * 2.2
	lamp.light_energy = 1.1
	lamp.shadow_enabled = false
	lamp.position = Vector3(0.0, 5.5, 0.0)
	root.add_child(lamp)


func _rng(key: String) -> RandomNumberGenerator:
	var r := RandomNumberGenerator.new()
	r.seed = hash(key)
	return r


## A footprint on the deck (island-local x, z, half sizes), kept clear of spawn spots.
func _foot(isl: Dictionary, at: Vector3, size: Vector3) -> void:
	(isl["foot"] as Array).append(Rect2(at.x - size.x * 0.5, at.z - size.z * 0.5, size.x, size.z))


## A solid machine part standing on the deck (`at` its footprint's middle on the deck, island-local).
func _solid(isl: Dictionary, at: Vector3, size: Vector3, accent: Color, part: int = 2, basis: Basis = Basis.IDENTITY) -> MeshInstance3D:
	_foot(isl, at, size)
	return _piece(isl["node"], _box, at + Vector3.UP * size.y * 0.5, size, part, accent, isl["body"], basis)


func _deco(isl: Dictionary, at: Vector3, size: Vector3, accent: Color, part: int = 2, basis: Basis = Basis.IDENTITY, energy: float = 1.0) -> MeshInstance3D:
	return _piece(isl["node"], _box, at, size, part, accent, null, basis, energy)


func _screen(isl: Dictionary, at: Vector3, size: Vector2, style: int, accent: Color, title: String, facing: Basis) -> KeyWindow:
	var w := KeyWindow.make(size, style, accent, title, float(isl["i"]) * 3.1)
	w.set_param("glow", 2.4)
	w.set_param("body_alpha", 0.92)
	w.set_param("body_light", 0.05)
	w.position = at
	w.basis = facing
	(isl["node"] as Node3D).add_child(w)
	if w.label != null:
		w.label.pixel_size = clampf(size.y * 0.004, 0.006, 0.03)
	return w


func _laptop(isl: Dictionary) -> void:
	var a: Color = isl["accent"]
	var half: Vector2 = isl["half"]
	# The keyboard: rows of keycaps (one MultiMesh) on the back half of the deck, the trackpad lit in front.
	var keys := MultiMesh.new()
	keys.transform_format = MultiMesh.TRANSFORM_3D
	keys.mesh = _box
	var cols := 13
	var rows := 4
	keys.instance_count = cols * rows
	var cap := Vector3(1.0, 0.14, 1.0)
	for rr in rows:
		for c in cols:
			var x := (float(c) - (cols - 1) * 0.5) * 1.18 + (0.3 if rr % 2 == 1 else 0.0)
			var z := -half.y + 1.4 + rr * 1.18
			keys.set_instance_transform(rr * cols + c, Transform3D(Basis.from_scale(cap), Vector3(x, 0.07, z)))
	var mmi := MultiMeshInstance3D.new()
	mmi.name = "Keys"
	mmi.multimesh = keys
	mmi.material_override = _mat
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mmi.set_instance_shader_parameter("accent", a)
	mmi.set_instance_shader_parameter("box", cap)
	mmi.set_instance_shader_parameter("part", 2.0)
	mmi.set_instance_shader_parameter("energy", 0.8)
	(isl["node"] as Node3D).add_child(mmi)
	_deco(isl, Vector3(0.0, 0.03, 2.6), Vector3(5.0, 0.04, 2.8), a, 3, Basis.IDENTITY, 0.25)
	# The lid, open past upright behind the keys, its screen running the trace.
	var hinge := Vector3(0.0, 0.0, -half.y + 0.2)
	var tilt := Basis(Vector3.RIGHT, deg_to_rad(-14.0))
	var lid := Vector3(half.x * 2.0 - 0.6, 11.0, 0.5)
	var mid := hinge + tilt * Vector3(0.0, lid.y * 0.5, -0.25)
	_foot(isl, Vector3(0.0, 0.0, hinge.z - 0.6), Vector3(lid.x, 0.0, 2.0))
	_piece(isl["node"], _box, mid, lid, 2, a, isl["body"], tilt)
	var face := mid + tilt * Vector3(0.0, 0.3, 0.3)
	var screen := _screen(isl, face, Vector2(lid.x - 1.2, lid.y - 1.4), KeyWindow.Style.TERMINAL, a, "localhost: traceroute %s" % NetBook.TARGET, tilt)
	screen.set_param("glyph", 0.42)
	# A little cover on the deck: two low blocks (a mouse, a mug of a drive).
	_solid(isl, Vector3(-5.6, 0.0, 3.6), Vector3(2.4, 1.2, 1.6), a)
	_solid(isl, Vector3(5.8, 0.0, 2.2), Vector3(1.6, 1.6, 1.6), a)


func _router(isl: Dictionary) -> void:
	var a: Color = isl["accent"]
	var box := _solid(isl, Vector3(0.0, 0.0, -1.0), Vector3(8.0, 2.4, 4.2), a)
	box.set_instance_shader_parameter("energy", 1.3)
	for k in 4:
		var x := -3.0 + k * 2.0
		var lean := Basis(Vector3.BACK, (float(k) - 1.5) * 0.12)
		_deco(isl, Vector3(x, 2.4 + 3.2, -2.6) , Vector3(0.28, 6.4, 0.28), a, 2, lean)
		_deco(isl, Vector3(x, 2.4, -2.6) + lean * Vector3(0.0, 6.6, 0.0), Vector3(0.5, 0.5, 0.5), a, 3)
	# The lantern: a mast and a cage of light at its head.
	_solid(isl, Vector3(6.4, 0.0, 4.6), Vector3(0.7, 12.0, 0.7), a)
	var cage := _deco(isl, Vector3(6.4, 12.6, 4.6), Vector3(1.6, 1.6, 1.6), a, 3)
	_spinners.append([cage, Vector3.UP, 0.8])
	var lamp := OmniLight3D.new()
	lamp.light_color = a
	lamp.omni_range = 16.0
	lamp.light_energy = 2.2
	lamp.position = Vector3(6.4, 12.6, 4.6)
	(isl["node"] as Node3D).add_child(lamp)
	_solid(isl, Vector3(-6.0, 0.0, 4.0), Vector3(2.2, 1.4, 2.2), a)
	_solid(isl, Vector3(-2.0, 0.0, 5.2), Vector3(3.0, 1.1, 1.4), a)
	_screen(isl, Vector3(0.0, 1.3, 1.15), Vector2(6.6, 1.6), KeyWindow.Style.MONITOR, a, "", Basis.IDENTITY)


func _rack(isl: Dictionary) -> void:
	var a: Color = isl["accent"]
	for row in 2:
		var z := -3.6 if row == 0 else 3.0
		for k in 5:
			var x := -6.2 + k * 1.34
			var rack := _solid(isl, Vector3(x, 0.0, z), Vector3(1.26, 3.6, 1.9), a)
			rack.set_instance_shader_parameter("energy", 1.25)
		_deco(isl, Vector3(-3.5, 4.3, z), Vector3(9.0, 0.2, 0.7), a, 2)
	_solid(isl, Vector3(7.5, 0.0, -0.4), Vector3(1.26, 3.6, 1.9), a)
	_solid(isl, Vector3(8.8, 0.0, -0.4), Vector3(1.26, 3.6, 1.9), a)
	_screen(isl, Vector3(4.6, 2.6, -6.6), Vector2(5.2, 3.0), KeyWindow.Style.MONITOR, a, "top", Basis.IDENTITY)
	_deco(isl, Vector3(4.6, 1.0, -6.7), Vector3(0.3, 2.0, 0.3), a, 2)


func _board(isl: Dictionary) -> void:
	var a: Color = isl["accent"]
	var soc := _solid(isl, Vector3(0.0, 0.0, -1.0), Vector3(4.6, 1.0, 4.6), a)
	soc.set_instance_shader_parameter("energy", 1.3)
	for k in 7:
		_solid(isl, Vector3(-1.8 + k * 0.6, 1.0, -1.0), Vector3(0.18, 1.8, 4.0), a)
	for c in [Vector3(-6.0, 0.0, -5.0), Vector3(5.5, 0.0, -5.5), Vector3(-5.5, 0.0, 4.5), Vector3(6.0, 0.0, 3.5)]:
		_solid(isl, c, Vector3(2.4, 1.3, 1.6), a)
	for c in [Vector3(3.6, 0.0, 2.4), Vector3(-3.4, 0.0, 2.8), Vector3(0.6, 0.0, 5.0)]:
		_foot(isl, c, Vector3(1.4, 0.0, 1.4))
		_piece(isl["node"], _cyl, c + Vector3.UP * 1.0, Vector3(1.3, 2.0, 1.3), 2, a, null)
		_deco(isl, c + Vector3.UP * 2.05, Vector3(0.8, 0.08, 0.8), a, 3)
	var half: Vector2 = isl["half"]
	for k in 16:
		var x := -half.x + 2.0 + k * ((half.x * 2.0 - 4.0) / 15.0)
		_deco(isl, Vector3(x, 0.8, half.y - 0.8), Vector3(0.22, 1.6, 0.22), a, 2)
		_deco(isl, Vector3(x, 1.65, half.y - 0.8), Vector3(0.28, 0.12, 0.28), a, 3)


func _nas(isl: Dictionary) -> void:
	var a: Color = isl["accent"]
	var bay := _solid(isl, Vector3(0.0, 0.0, -6.2), Vector3(12.0, 5.0, 2.2), a)
	bay.set_instance_shader_parameter("energy", 1.3)
	for side in [-1.0, 1.0]:
		var stack := Node3D.new()
		stack.position = Vector3(5.0 * side, 0.0, 1.6)
		(isl["node"] as Node3D).add_child(stack)
		_foot(isl, stack.position, Vector3(4.6, 0.0, 4.6))
		_piece(isl["node"], _cyl, stack.position + Vector3.UP * 2.4, Vector3(0.6, 4.8, 0.6), 2, a, isl["body"])
		for k in 6:
			var plat := _piece(stack, _cyl, Vector3(0.0, 0.6 + k * 0.78, 0.0), Vector3(4.4, 0.1, 4.4), 2, a)
			plat.set_instance_shader_parameter("energy", 0.9)
			# A lit sector on each platter, so its spin reads.
			_piece(stack, _box, Basis(Vector3.UP, k * 0.9) * Vector3(1.1, 0.0, 0.0) + Vector3(0.0, 0.66 + k * 0.78, 0.0), Vector3(2.0, 0.03, 0.16), 3, a, null, Basis(Vector3.UP, k * 0.9))
		_spinners.append([stack, Vector3.UP, 2.4 * side])
		var arm := _deco(isl, stack.position + Vector3(-2.6 * side, 2.9, -1.2), Vector3(0.18, 0.12, 3.0), a, 3, Basis(Vector3.UP, 0.6 * side))
		_pulses.append([arm, 0.6 * side])
	_solid(isl, Vector3(0.0, 0.0, 5.6), Vector3(3.0, 1.2, 1.4), a)


func _dish(isl: Dictionary) -> void:
	var a: Color = isl["accent"]
	_solid(isl, Vector3(-2.0, 0.0, -3.0), Vector3(1.4, 7.0, 1.4), a)
	var head := Node3D.new()
	head.position = Vector3(-2.0, 7.6, -3.0)
	head.basis = Basis(Vector3.RIGHT, deg_to_rad(-40.0))
	(isl["node"] as Node3D).add_child(head)
	var dish := CylinderMesh.new()
	dish.top_radius = 0.5
	dish.bottom_radius = 0.1
	dish.height = 1.0
	dish.radial_segments = 24
	dish.rings = 2
	_piece(head, dish, Vector3(0.0, 1.0, 0.0), Vector3(11.0, 2.4, 11.0), 2, a)
	_piece(head, _box, Vector3(0.0, 3.4, 0.0), Vector3(0.25, 4.8, 0.25), 2, a)
	_piece(head, _box, Vector3(0.0, 5.9, 0.0), Vector3(0.7, 0.7, 0.7), 3, a)
	for k in 3:
		var ring := _piece(head, _cyl, Vector3(0.0, 6.0, 0.0), Vector3(1.0, 0.05, 1.0), 3, a)
		_pulses.append([ring, float(k) / 3.0, "ring"])
	_solid(isl, Vector3(4.6, 0.0, 3.0), Vector3(3.2, 1.3, 1.6), a)
	_solid(isl, Vector3(-6.4, 0.0, 4.4), Vector3(1.8, 1.8, 1.8), a)
	_screen(isl, Vector3(4.6, 2.6, 2.2), Vector2(3.6, 2.2), KeyWindow.Style.EDITOR, a, "relay.conf", Basis.IDENTITY)


func _core(isl: Dictionary) -> void:
	var a: Color = isl["accent"]
	var half: Vector2 = isl["half"]
	for k in 8:
		var ang := TAU * float(k) / 8.0 + TAU / 16.0
		var p := Vector3(cos(ang) * (half.x - 1.6), 0.0, sin(ang) * (half.y - 1.6))
		_solid(isl, p, Vector3(1.2, 5.2, 1.2), a)
		_deco(isl, p + Vector3.UP * 5.5, Vector3(1.5, 0.4, 1.5), a, 3)
	var dais := _piece(isl["node"], _cyl, Vector3(0.0, 0.3, 0.0), Vector3(8.0, 0.6, 8.0), 0, a)
	dais.set_instance_shader_parameter("energy", 1.6)
	for k in 4:
		var ang := TAU * float(k) / 4.0
		var p := Vector3(cos(ang) * 9.0, 0.0, sin(ang) * 9.0)
		_solid(isl, p, Vector3(5.0, 1.6, 1.0), a, 2, Basis(Vector3.UP, -ang + PI * 0.5))


## A port on each island for link `li`: a lit pad under a gate on the rim facing the other machine. A wrong way (a link
## only a stale route sends packets down, `boardable` false) has no pad and no gate: only its end on the rim.
func _port_for(li: int, id: String, toward: Vector3, proto: String, to_id: String, boardable: bool = true) -> Vector3:
	var isl: Dictionary = islands[island_index(id)]
	var at: Vector3 = isl["at"]
	var half: Vector2 = isl["half"]
	var d := Vector3(toward.x - at.x, 0.0, toward.z - at.z).normalized()
	var t := minf(half.x / maxf(absf(d.x), 0.001), half.y / maxf(absf(d.z), 0.001))
	var local := d * (t - PORT_IN)
	var c := NetBook.color_of(proto)
	var face := Basis(Vector3.UP, atan2(-d.x, -d.z))
	if not boardable:
		local = d * (t - 0.3)
		var end := at + local
		(isl["ports"] as Dictionary)[li] = end
		return end
	(isl["gates"] as Dictionary)[li] = true
	_piece(isl["node"], _cyl, local + Vector3.UP * 0.04, Vector3(PORT_R * 2.0, 0.08, PORT_R * 2.0), 3, c, null, Basis.IDENTITY, 0.7)
	for s in [-1.0, 1.0]:
		_piece(isl["node"], _box, local + face * Vector3(s * 2.0, 1.7, 0.0), Vector3(0.32, 3.4, 0.32), 2, c, isl["body"], face)
	_piece(isl["node"], _box, local + Vector3.UP * 3.45, Vector3(4.3, 0.3, 0.32), 2, c, null, face)
	var tag := Label3D.new()
	tag.font = Palette.mono_font()
	tag.text = "-> %s  %s" % [to_id, NetBook.PROTOCOLS[proto]["label"]]
	tag.font_size = 40
	tag.pixel_size = 0.012
	tag.outline_size = 8
	tag.outline_modulate = Color(0, 0, 0, 0.85)
	tag.modulate = c.lerp(Color.WHITE, 0.3) * 1.3
	tag.shaded = false
	tag.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y
	tag.position = local + Vector3.UP * 4.2
	(isl["node"] as Node3D).add_child(tag)
	var world := at + local
	(isl["ports"] as Dictionary)[li] = world
	return world


func _build_link(li: int) -> void:
	var row: Array = NetBook.LINKS[li]
	var a: Dictionary = islands[island_index(row[0])]
	var b: Dictionary = islands[island_index(row[1])]
	var pa := _port_for(li, row[0], b["at"], row[2], row[1], bool(row[5]))
	var pb := _port_for(li, row[1], a["at"], row[2], row[0], bool(row[5]))
	var link := NetLink.new(li, pa + Vector3.UP * 0.5, pb + Vector3.UP * 0.5, row)
	add_child(link.build_mesh(_link_mat))
	links.append(link)
	_last_state[li] = link.state
	var tag := Label3D.new()
	tag.name = "LinkNote%d" % li
	tag.font = Palette.mono_font()
	tag.font_size = 64
	tag.pixel_size = 0.022
	tag.outline_size = 14
	tag.outline_modulate = Color(0, 0, 0, 0.9)
	tag.shaded = false
	tag.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	tag.no_depth_test = false
	tag.visible = false
	add_child(tag)
	_labels[li] = tag


## Spawn spots on each deck: a grid clear of the machine, the ports and the rim.
func _find_spots() -> void:
	for isl in islands:
		var half: Vector2 = isl["half"]
		var out := PackedVector3Array()
		var x := -half.x + SPOT_MARGIN
		while x <= half.x - SPOT_MARGIN:
			var z := -half.y + SPOT_MARGIN
			while z <= half.y - SPOT_MARGIN:
				var ok := true
				for f in isl["foot"]:
					if (f as Rect2).grow(1.0).has_point(Vector2(x, z)):
						ok = false
						break
				var world := (isl["at"] as Vector3) + Vector3(x, 0.0, z)
				for li in isl["gates"]:
					if Vector2(world.x, world.z).distance_to(Vector2(isl["ports"][li].x, isl["ports"][li].z)) < PORT_R + 2.4:
						ok = false
				if ok:
					out.append(world)
				z += SPOT_STEP
			x += SPOT_STEP
		# Spread them: a seeded shuffle, so a roster takes spots across the deck, not a row.
		var r := _rng("spots:%s" % isl["id"])
		var arr := Array(out)
		for k in range(arr.size() - 1, 0, -1):
			var j := r.randi_range(0, k)
			var tmp = arr[k]
			arr[k] = arr[j]
			arr[j] = tmp
		isl["spots"] = PackedVector3Array(arr.slice(0, SPOTS_MOST))


func _build_packets() -> void:
	_find_spots()
	var count := 0
	for link in links:
		var n := mini(int((link as NetLink).length_m / float(NetBook.PROTOCOLS[link.proto]["gap"])), PACKETS_A_LINK)
		_slots.append(n)
		count += n
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_custom_data = true
	mm.mesh = _box
	mm.instance_count = count + SPILL_MOST
	var hidden := Transform3D(Basis.from_scale(Vector3.ZERO), Vector3.ZERO)
	for k in mm.instance_count:
		mm.set_instance_transform(k, hidden)
		mm.set_instance_custom_data(k, Color(0, 0, 0, 1))
	_packets = MultiMeshInstance3D.new()
	_packets.name = "Packets"
	_packets.multimesh = mm
	var pm := ShaderMaterial.new()
	pm.shader = PacketShader
	_packets.material_override = pm
	_packets.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_packets.custom_aabb = AABB(Vector3(-400, -200, -700), Vector3(800, 500, 1100))
	add_child(_packets)


## The void, never plain: the bus below, far islands and their links, backbone cables arcing over, data rising.
func _build_background() -> void:
	var bg := Node3D.new()
	bg.name = "Void"
	add_child(bg)
	var bus := _piece(bg, _box, Vector3(0.0, BUS_Y, -210.0), Vector3(2400.0, 1.0, 2400.0), 4, Palette.TEAL, null, Basis.IDENTITY, 1.8)
	bus.name = "Bus"
	var r := _rng("void")
	var centre := Vector3(0.0, 0.0, -210.0)
	var far_at: Array[Vector3] = []
	var decks := MultiMesh.new()
	decks.transform_format = MultiMesh.TRANSFORM_3D
	decks.mesh = _box
	decks.instance_count = DECOR_ISLANDS
	var roots := MultiMesh.new()
	roots.transform_format = MultiMesh.TRANSFORM_3D
	roots.mesh = _cone
	roots.instance_count = DECOR_ISLANDS
	for k in DECOR_ISLANDS:
		var ang := r.randf() * TAU
		var dist := r.randf_range(240.0, 620.0)
		var p := centre + Vector3(cos(ang) * dist, r.randf_range(-35.0, 60.0), sin(ang) * dist)
		far_at.append(p)
		var s := r.randf_range(8.0, 22.0)
		var yaw := Basis(Vector3.UP, r.randf() * TAU)
		decks.set_instance_transform(k, Transform3D(yaw * Basis.from_scale(Vector3(s, s * 0.12, s * r.randf_range(0.6, 1.0))), p))
		roots.set_instance_transform(k, Transform3D(yaw * Basis.from_scale(Vector3(s * 0.8, s * 1.4, s * 0.8)), p - Vector3.UP * (s * 0.7 + s * 0.06)))
	for pair in [[decks, 0, Palette.TEAL], [roots, 1, Color(0.45, 0.4, 1.0)]]:
		var mmi := MultiMeshInstance3D.new()
		mmi.multimesh = pair[0]
		mmi.material_override = _mat
		mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mmi.set_instance_shader_parameter("accent", pair[2])
		mmi.set_instance_shader_parameter("box", Vector3(14.0, 1.6, 12.0))
		mmi.set_instance_shader_parameter("part", float(pair[1]))
		mmi.set_instance_shader_parameter("energy", 0.7)
		bg.add_child(mmi)
	# Far links, streaming between far islands.
	var protos := NetBook.PROTOCOLS.keys()
	for k in DECOR_LINKS:
		var a := far_at[r.randi_range(0, far_at.size() - 1)]
		var b := far_at[r.randi_range(0, far_at.size() - 1)]
		if a.distance_to(b) < 40.0 or a.distance_to(b) > 260.0:
			continue
		var fake := NetLink.new(100 + k, a, b, ["far", "far", protos[k % protos.size()], 0.0, false, false])
		var mi := fake.build_mesh(_link_mat)
		mi.name = "FarLink%d" % k
		fake.state = NetLink.State.UP
		fake.step(0.0, 0.0)
		bg.add_child(mi)
	# Backbone cables: three great arcs across the sky, and columns of data rising off the bus.
	for k in 3:
		var ang := TAU * float(k) / 3.0 + 0.4
		var a := centre + Vector3(cos(ang) * 600.0, -60.0, sin(ang) * 600.0)
		var b := centre + Vector3(cos(ang + PI * 0.85) * 600.0, -60.0, sin(ang + PI * 0.85) * 600.0)
		var cable := NetLink.new(200 + k, a, b, ["far", "far", protos[(k + 1) % protos.size()], 0.0, false, false])
		var mi := _arc_mesh(cable, a.lerp(b, 0.33) + Vector3.UP * 520.0, a.lerp(b, 0.67) + Vector3.UP * 520.0, 1.4)
		mi.set_instance_shader_parameter("bright", 0.45)
		mi.name = "Backbone%d" % k
		bg.add_child(mi)
	for k in 12:
		var ang := r.randf() * TAU
		var dist := r.randf_range(220.0, 480.0)
		var foot := centre + Vector3(cos(ang) * dist, BUS_Y, sin(ang) * dist)
		var head := foot + Vector3.UP * r.randf_range(160.0, 300.0)
		var column := NetLink.new(300 + k, foot, head, ["far", "far", protos[k % protos.size()], 0.0, false, false])
		var mi := _arc_mesh(column, foot.lerp(head, 0.33), foot.lerp(head, 0.67), 0.9)
		mi.name = "Column%d" % k
		bg.add_child(mi)


## A link's tube along a curve of our own (its middle points `c1`, `c2`), `radius` thick, streaming.
func _arc_mesh(link: NetLink, c1: Vector3, c2: Vector3, radius: float) -> MeshInstance3D:
	link.p1 = c1
	link.p2 = c2
	var pts := PackedVector3Array()
	var lens := PackedFloat32Array()
	var total := 0.0
	for s in NetLink.STEPS + 1:
		pts.append(link.at_raw(float(s) / NetLink.STEPS))
		if s > 0:
			total += pts[s].distance_to(pts[s - 1])
		lens.append(total)
	link.length_m = total
	var mi := link.build_mesh(_link_mat)
	mi.mesh = NetLink.tube(pts, lens, radius, NetLink.SIDES)
	mi.set_instance_shader_parameter("length_m", total)
	mi.set_instance_shader_parameter("gap", 18.0)
	mi.set_instance_shader_parameter("flow", 60.0)
	link.state = NetLink.State.UP
	link.step(0.0, 0.0)
	return mi


func _dress_environment() -> void:
	if environment == null:
		return
	var sky_mat := ShaderMaterial.new()
	sky_mat.shader = VoidShader
	var sky := Sky.new()
	sky.sky_material = sky_mat
	sky.radiance_size = Sky.RADIANCE_SIZE_32
	environment.background_mode = Environment.BG_SKY
	environment.sky = sky
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color(0.35, 0.4, 0.9)
	environment.ambient_light_energy = 0.07
	environment.fog_enabled = true
	environment.fog_light_color = Color(0.02, 0.025, 0.06)
	environment.fog_density = 0.0016
	environment.fog_height = -30.0
	environment.fog_height_density = 0.012
	environment.fog_sky_affect = 0.25
	if sun != null:
		sun.light_color = Color(0.7, 0.75, 1.0)
		sun.light_energy = 0.3


# --- Every frame: the packets streaming, the spill, the notes over the links, the machines' moving parts. ---

func _process(delta: float) -> void:
	_clock += delta
	var mm := _packets.multimesh
	var slot := 0
	var hidden := Transform3D(Basis.from_scale(Vector3.ZERO), Vector3.ZERO)
	for li in links.size():
		var link: NetLink = links[li]
		var n := _slots[li]
		var proto: Dictionary = NetBook.PROTOCOLS[link.proto]
		var shown := link.state == NetLink.State.UP or link.state == NetLink.State.FLAKY
		if _last_state.get(li, -1) != link.state:
			if link.state == NetLink.State.DROPPED:
				_spill_from(link, n, proto)
			_last_state[li] = link.state
		var col: Color = NetBook.color_of(link.proto)
		if link.state == NetLink.State.FLAKY:
			col = col.lerp(Color(1.0, 0.62, 0.12), 0.85)
		var speed: float = float(proto["speed"]) * (0.15 if link.state == NetLink.State.FLAKY else 1.0)
		for k in n:
			if not shown:
				mm.set_instance_transform(slot + k, hidden)
				continue
			var u := fposmod((k * float(proto["gap"]) + _clock * speed * (-1.0 if link.stale else 1.0)) / link.length_m, 1.0)
			var p := link.at(u)
			if link.state == NetLink.State.FLAKY:
				p += Vector3(sin(_clock * 31.0 + k), cos(_clock * 27.0 + k * 2.0), 0.0) * 0.12
			var c := col
			if link.tap_u >= 0.0 and absf(u - link.tap_u) * link.length_m < 5.0:
				c = Color(0.82, 0.0, 1.0)
			mm.set_instance_transform(slot + k, Transform3D(Basis.looking_at(link.way(u), Vector3.UP) * Basis.from_scale(PACKET_SIZE), p))
			mm.set_instance_custom_data(slot + k, c)
		slot += n
		_note_link(li, link)
	_step_spill(delta, slot)
	for s in _spinners:
		if is_instance_valid(s[0]):
			(s[0] as Node3D).rotate(s[1], float(s[2]) * delta)
	for p in _pulses:
		var node: Node3D = p[0]
		if not is_instance_valid(node):
			continue
		if p.size() > 2:
			var u := fposmod(_clock * 0.5 + float(p[1]), 1.0)
			node.scale = Vector3(1.0 + 9.0 * u, 0.05, 1.0 + 9.0 * u)
			node.position.y = 6.0 + 4.0 * u
			node.set_instance_shader_parameter("energy", 1.0 - u)
		else:
			node.rotation.y = float(p[1]) + 0.25 * sin(_clock * 3.0 + float(p[1]) * 5.0)
	if _flash_t >= 0.0:
		_flash_t += delta
		_flash.light_energy = 9.0 * maxf(1.0 - _flash_t / 0.45, 0.0)
		if _flash_t > 0.45:
			_flash_t = -1.0


## A drop: the packets on the link tumble off into the void, a red flash where it tore.
func _spill_from(link: NetLink, n: int, proto: Dictionary) -> void:
	var tear := link.at(link.tear_u)
	_flash.global_position = tear
	_flash_t = 0.0
	var fx := ParticleFx.of(self)
	if fx != null:
		for k in 3:
			fx.impact(tear + link.way(link.tear_u) * (float(k) - 1.0) * 0.8, Vector3.UP, true, Color(1.0, 0.25, 0.3))
	for k in n:
		if _spill.size() >= SPILL_MOST:
			break
		var u := fposmod((k * float(proto["gap"]) + _clock * float(proto["speed"])) / link.length_m, 1.0)
		var p := link.at(u)
		var away := link.way(u) * (6.0 if u > link.tear_u else -6.0)
		_spill.append({"p": p, "v": away + Vector3(sin(k * 1.7) * 2.0, 2.5 + 2.0 * fposmod(k * 0.37, 1.0), cos(k * 2.3) * 2.0), "spin": Vector3(sin(k * 3.1), 1.0, cos(k)).normalized(), "t": 0.0, "c": NetBook.color_of(link.proto).lerp(Color(1.0, 0.2, 0.25), 0.7)})


func _step_spill(delta: float, first: int) -> void:
	var mm := _packets.multimesh
	var hidden := Transform3D(Basis.from_scale(Vector3.ZERO), Vector3.ZERO)
	var keep: Array = []
	for s in _spill:
		s["t"] = float(s["t"]) + delta
		if float(s["t"]) < SPILL_S:
			s["v"] = (s["v"] as Vector3) + Vector3.DOWN * 14.0 * delta
			s["p"] = (s["p"] as Vector3) + (s["v"] as Vector3) * delta
			keep.append(s)
	_spill = keep
	for k in SPILL_MOST:
		if k < _spill.size():
			var s: Dictionary = _spill[k]
			var fade := 1.0 - float(s["t"]) / SPILL_S
			mm.set_instance_transform(first + k, Transform3D(Basis(s["spin"], float(s["t"]) * 7.0) * Basis.from_scale(PACKET_SIZE * (0.4 + 0.6 * fade)), s["p"]))
			mm.set_instance_custom_data(first + k, (s["c"] as Color) * fade)
		else:
			mm.set_instance_transform(first + k, hidden)


## The note over a link: TIMEOUT counting down where it will tear, RST as it tears, nothing else.
func _note_link(li: int, link: NetLink) -> void:
	var tag: Label3D = _labels[li]
	match link.state:
		NetLink.State.FLAKY:
			tag.visible = true
			tag.pixel_size = 0.022
			tag.text = "TIMEOUT %.1f" % maxf(NetLink.FLAKY_S - link.state_t, 0.0)
			tag.modulate = Color(1.0, 0.62, 0.12) * 1.5
			tag.global_position = link.at(link.tear_u) + Vector3.UP * 1.6
		NetLink.State.DROPPED:
			tag.visible = link.state_t < 1.2
			tag.text = "RST"
			tag.pixel_size = 0.04
			tag.modulate = Color(1.0, 0.16, 0.22) * (1.4 + 1.6 * maxf(1.0 - link.state_t / 0.4, 0.0))
			tag.global_position = link.at(link.tear_u) + Vector3.UP * 1.6
		_:
			tag.visible = false


func clock() -> float:
	return _clock
