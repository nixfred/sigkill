class_name RuinsPieces
extends RefCounted
## The ruins kit's pieces (C36): server-farm and filesystem ruins, written in code from the shared shape kit's shapes
## (scripts/art/shape_kit.gd), no model, texture or font file. Every piece is built from its own seeded dice, so no
## two are alike: a rack tower's height, its modules' slips and missing blades, its lean, its lights' health and blink;
## a monolith's cracks, its fallen top, which letters of its folder name still light. A piece writes into a chunk's
## three buckets (`b`: "body", "light", "floor"), painting each part's data for the ruins' shaders:
##   body   (shaders/ruins_body.gdshader)   grime, edge brightness, material, sway
##   light  (shaders/ruins_light.gdshader)  phase, health, slot, energy
##   floor  (shaders/ruins_floor.gdshader)  damage, rims
## The pieces:
##   rack_tower   a tower of rack modules, toppling, half sunk into the abyss: corner posts, blades of status LEDs,
##                blades pulled out or gone, side panels off, modules knocked askew carrying the rest, cables spilling
##                from the worst, a neon strip up a corner, a mast and a beacon on top or a jagged break
##   giant        a megatower far out in the void: setback slabs of window bands, neon up its edges, antennas or a
##                broken top
##   monolith     a directory as a slab of black glass with a folder's tab, cracked into shifted pieces, its name and
##                its permissions in the sign font, half of them gone
##   fallen       a rack tower lying broken across a block
##   cover        a toppled rack, a dead terminal (its screen still typing), a pile of drive sleds, slab rubble with
##                rods sticking out, a shard of a monolith
##   edge         a parapet (broken wall chunks) or an overlook (a bent rail) on a floor side, and the broken slab
##                hanging off it into the void
##   hole         a tower rising out of a hole in the floor, the void glowing far below it
##   slab         a cell of the floor
##   cable        a bundle of cables between two towers, a cut one dangling from each, its ends hot
##   sign         a dead megacorp's neon sign on a tower, upright or wide, some letters gone
## and a breach's (C37): the gate (a portal of two pylons and a lintel on the exit's side onto the void, a low
## barrier across it) and the gangway past it out into the void, broken off at its end; the shaft under the breach's
## hatch (its rim, its walls going down, green code leaking up them); the pocket's deck and parapets (slab_at(),
## edge_at(): the floor's and the parapets' own pieces, at any place).
## And a shop's (M2): the storefront, a closed terminal as a dead shop built into a block on the floor's edge: a tall
## dark mass set back over a shopfront of two pillars and a fascia, its name lit along the fascia, a torn awning, its
## window a pane of dark glass with the terminal's last screen frozen on it and an OPEN sign in its corner, its door a
## roller shutter half down with light leaking out under it onto the street, a few dead windows up its front.
## And a vault's (M4, a pristine set with a vault): the record stack (a clean slab of black glass twice a ruin's height,
## rows of white record strips up both faces, every one alive, a frame of cyan up its edges, its name plate at eye level
## and a beacon on top), the guard post (a slim pillar with a cyan ring and a white beacon, its light on the floor), the
## records console (a clean pedestal terminal, its screen steady) and the records screen (a pane of dark glass in a frame
## past the exit row's parapet, the records in the sign font, a run of "#" a solid redaction bar in the "mark" bucket; the
## world gives it a material of its own, dark until a mission lights it). A pristine set's towers, giants, parapets and
## signs are built whole: nothing slipped, spilled, broken, bent or dying.
## Fiction only: the names are the set's demo text.

const SignFont = preload("res://scripts/arena/arena_font.gd")

enum Mat { METAL, STONE, CABLE, GLASS }
enum Slot { LED, STRIP, SIGN_A, SIGN_B, BEACON, SCREEN, HOT, VOID }
## A light's energy is painted in tenths of the light shader's ENERGY_MOST.
const ENERGY_MOST := 10.0
## Under this far below the floor, a tower is one plain shaft: too deep in the fog to see its parts.
const DETAIL_DEPTH := 26.0
## How a piece's lights are, mostly: alive, dying, nearly gone.
const ALIVE := 1.0


static func paint_body(kit: ShapeKit, grime: float, edge: float, mat: int = Mat.METAL, sway: float = 0.0) -> void:
	kit.paint = Color(clampf(grime, 0.0, 1.0), clampf(edge, 0.0, 1.0), float(mat) / 3.0, clampf(sway, 0.0, 1.0))


static func paint_light(kit: ShapeKit, phase: float, health: float, slot: int, energy: float) -> void:
	kit.paint = Color(fposmod(phase, 1.0), clampf(health, 0.0, 1.0), float(slot) / 8.0, clampf(energy / ENERGY_MOST, 0.0, 1.0))


## A slab's paint: its damage, its rims, and (M6) how far under FLOOR_Y its top lies, in sixteenths of a metre per
## eighth (the shader lights a broken side where it meets its own top, wherever that stands).
static func paint_floor(kit: ShapeKit, damage: float, rims: int, top_y: float = 0.0) -> void:
	kit.paint = Color(clampf(damage, 0.0, 1.0), float(rims) / 15.0, clampf(-top_y / 16.0, 0.0, 1.0), 1.0)


## A flat light quad `size` big, centred on `at` in the kit's pose, facing `out` (one of the axes).
static func light_quad(kit: ShapeKit, into: int, at: Vector3, size: Vector2, out: Vector3) -> void:
	var u := Vector3.RIGHT if absf(out.x) < 0.5 else Vector3.BACK
	var v := out.cross(u).normalized()
	u = v.cross(out).normalized()
	var a := u * size.x * 0.5
	var c := v * size.y * 0.5
	kit.polygon(into, [at - a - c, at + a - c, at + a + c, at - a + c], out)


## A light's health: mostly `base`, now and then far worse.
static func _health(rng: RandomNumberGenerator, base: float) -> float:
	var h := base + rng.randf_range(-0.35, 0.25)
	if rng.randf() < 0.08:
		h -= 0.5
	return clampf(h, 0.0, 1.0)


# --- Rack towers. ---

## Tower `t` (a RuinsLayout tower: at, tall, foot, width, depth, yaw, lean, inside) with its mast unless `crown` is false.
static func rack_tower(kit: ShapeKit, b: Dictionary, t: Dictionary, rng: RandomNumberGenerator, crown: bool = true) -> void:
	var base := RuinsLayout.tower_xform(t)
	var w: float = t["width"]
	var d: float = t["depth"]
	var top: float = t["tall"]
	var foot: float = -float(t["foot"])
	var both: bool = t.get("inside", false)
	var pristine: bool = t.get("pristine", false)
	var mh := clampf(w * 0.92, 1.9, 3.6) * rng.randf_range(0.9, 1.12)
	var health_base := 1.0 if pristine else rng.randf_range(0.6, 1.0)
	var from := maxf(foot, -DETAIL_DEPTH)
	if from > foot + 0.5:
		kit.pose = base
		paint_body(kit, 0.95, 0.35)
		kit.box(b["body"], Vector3(0, (foot + from) * 0.5, 0), Vector3(w * 0.94, from - foot, d * 0.94))
		for k in int((from - foot) / 9.0):
			paint_light(kit, rng.randf(), _health(rng, health_base * 0.7), Slot.LED, 2.0)
			light_quad(kit, b["light"], Vector3(rng.randf_range(-w, w) * 0.35, from - 4.0 - k * 9.0, -d * 0.47 - 0.01), Vector2(0.12, 0.06), Vector3.FORWARD)
	var broken := top > 6.0 and rng.randf() < 0.45 and not pristine
	# Neon up a front corner of some (a dead megacorp's trim, still lit): from where to where, which colour.
	var neon := []
	if top > 8.0 and rng.randf() < (0.4 if not both else 0.28):
		var n0 := rng.randf_range(maxf(from, -12.0), top * 0.35)
		neon = [-1.0 if rng.randf() < 0.5 else 1.0, n0, rng.randf_range(maxf(n0 + 6.0, top * 0.6), top - 0.5), Slot.SIGN_A if rng.randf() < 0.5 else Slot.SIGN_B, rng.randf()]
	var slip := Vector3.ZERO
	var y := from
	var spill_left := 2
	while y < top - 0.25:
		var h := minf(mh, top - y)
		var last := y + h >= top - 0.25
		if rng.randf() < (0.07 if y < top * 0.6 else 0.2) and not pristine:
			slip += Vector3(rng.randf_range(-0.24, 0.24), 0, rng.randf_range(-0.14, 0.14))
		var turn := Basis.from_euler(Vector3(deg_to_rad(rng.randf_range(-1.2, 1.2)), deg_to_rad(rng.randf_range(-2.5, 2.5)), deg_to_rad(rng.randf_range(-1.2, 1.2)))) if not pristine else Basis.IDENTITY
		kit.pose = base * Transform3D(turn, Vector3(slip.x, y, slip.z))
		var damage := rng.randf() if not pristine else 0.0
		_rack_module(kit, b, w, d, h, rng, health_base, both, last and broken, damage, pristine)
		if not neon.is_empty():
			var lo := maxf(y, neon[1])
			var hi := minf(y + h, neon[2])
			if hi > lo + 0.1:
				paint_light(kit, neon[4], 1.0, neon[3], 2.4)
				kit.box(b["light"], Vector3(neon[0] * (w * 0.5 + 0.03), (lo + hi) * 0.5 - y, -d * 0.5 - 0.03), Vector3(0.09, hi - lo, 0.06))
		if damage > 0.82 and spill_left > 0 and y > -4.0 and not pristine:
			spill_left -= 1
			_spill(kit, b, Vector3(rng.randf_range(-w, w) * 0.3, 0.05, -d * 0.5 - 0.05), rng.randf_range(1.5, minf(5.0, maxf(y + 0.5, 1.5))), rng)
		y += h
	if top <= 0.0:
		return
	kit.pose = base * Transform3D(Basis.IDENTITY, Vector3(slip.x, top, slip.z))
	if broken:
		for k in rng.randi_range(3, 6):
			paint_body(kit, 0.5, 0.8)
			var at := Vector3(rng.randf_range(-w, w) * 0.4, 0.0, rng.randf_range(-d, d) * 0.4)
			var to := at + Vector3(rng.randf_range(-0.8, 0.8), rng.randf_range(0.6, 2.4), rng.randf_range(-0.8, 0.8))
			kit.spike(b["body"], at, to, 0.06, 4, 0.2)
			paint_light(kit, rng.randf(), 0.6, Slot.HOT, 3.0)
			kit.box(b["light"], to, Vector3.ONE * 0.06)
	elif crown:
		paint_body(kit, 0.3, 0.9)
		kit.frustum(b["body"], Vector3.ZERO, Vector2(w, d), Vector2(w * 0.7, d * 0.7), 0.35)
		var mast := rng.randf_range(2.0, 6.0) * clampf(top / 20.0, 0.5, 1.6)
		kit.prism(b["body"], Vector3(w * 0.2, 0.35 + mast * 0.5, 0), 0.05, mast, 5, Vector3(90, 0, 0))
		if rng.randf() < 0.6:
			kit.prism(b["body"], Vector3(-w * 0.25, 0.35 + mast * 0.3, d * 0.1), 0.04, mast * 0.6, 5, Vector3(90, 0, 0))
		paint_light(kit, rng.randf(), 1.0, Slot.BEACON, 4.0)
		kit.box(b["light"], Vector3(w * 0.2, 0.35 + mast, 0), Vector3.ONE * 0.16)
		paint_light(kit, rng.randf(), _health(rng, health_base), Slot.STRIP, 2.0)
		kit.box(b["light"], Vector3(0, 0.36, -d * 0.36), Vector3(w * 0.66, 0.035, 0.03))


## One rack module, `h` tall from the pose's origin: posts, plates, panels, blades and their LEDs. `jagged`: the
## break at a tower's top, its posts snapped off and no plate over it.
static func _rack_module(kit: ShapeKit, b: Dictionary, w: float, d: float, h: float, rng: RandomNumberGenerator, health_base: float, both: bool, jagged: bool, damage: float, pristine: bool = false) -> void:
	var grime := rng.randf_range(0.1, 0.6) if not pristine else 0.0
	paint_body(kit, grime, 1.0)
	for sx in [-1.0, 1.0]:
		for sz in [-1.0, 1.0]:
			var ph := h if not jagged else h * rng.randf_range(0.2, 1.0)
			kit.box(b["body"], Vector3(sx * (w * 0.5 - 0.07), ph * 0.5, sz * (d * 0.5 - 0.07)), Vector3(0.14, ph, 0.14))
	kit.box(b["body"], Vector3(0, 0.05, 0), Vector3(w, 0.1, d))
	paint_body(kit, grime + 0.2, 0.35)
	for sx in [-1.0, 1.0]:
		if pristine or rng.randf() < 0.65 - damage * 0.3:
			kit.box(b["body"], Vector3(sx * (w * 0.5 - 0.03), h * 0.5, 0), Vector3(0.05, h - 0.14, d - 0.2))
	if jagged:
		return
	var blades := clampi(int(h / 0.42), 2, 7)
	var pitch := (h - 0.16) / float(blades)
	for i in blades:
		if not pristine and rng.randf() < 0.1 + damage * 0.28:
			continue
		var out := rng.randf_range(0.12, 0.6) if rng.randf() < 0.1 and not pristine else 0.0
		var by := 0.12 + pitch * (i + 0.5)
		paint_body(kit, grime, 0.55)
		kit.box(b["body"], Vector3(0, by, -out), Vector3(w - 0.3, pitch * 0.82, d - 0.24))
		var leds := clampi(int((w - 0.5) / 0.22), 2, 14)
		for faces in ([-1.0, 1.0] if both else [-1.0]):
			var fz: float = faces * ((d - 0.24) * 0.5 + (out if faces < 0.0 else 0.0)) + faces * 0.004
			for k in leds:
				if not pristine and rng.randf() < 0.18:
					continue
				var lx := -(w - 0.6) * 0.5 + (w - 0.6) * (k + 0.5) / leds
				paint_light(kit, rng.randf(), 1.0 if pristine else _health(rng, health_base - damage * 0.25), Slot.LED, rng.randf_range(2.2, 4.6))
				light_quad(kit, b["light"], Vector3(lx, by + pitch * rng.randf_range(-0.18, 0.18), fz), Vector2(0.07, 0.035), Vector3(0, 0, faces))
	if rng.randf() < 0.45 or pristine:
		var sx := -1.0 if rng.randf() < 0.5 else 1.0
		paint_light(kit, rng.randf(), 1.0 if pristine else _health(rng, health_base), Slot.STRIP, 1.8)
		kit.box(b["light"], Vector3(sx * (w * 0.5 - 0.15), h * 0.5, -d * 0.5 - 0.01), Vector3(0.035, h * 0.86, 0.012))


## A bundle of loose cables hanging `long` metres from `at` (in the kit's pose), swinging, their ends hot.
static func _spill(kit: ShapeKit, b: Dictionary, at: Vector3, long: float, rng: RandomNumberGenerator) -> void:
	var phase := rng.randf()
	for k in rng.randi_range(2, 4):
		var from := at + Vector3(rng.randf_range(-0.2, 0.2), 0, rng.randf_range(-0.08, 0.08))
		var steps := 4
		var length := long * rng.randf_range(0.6, 1.0)
		var tip := from
		for s in steps:
			var t0 := float(s) / steps
			var t1 := float(s + 1) / steps
			var p0 := from + Vector3(0, -length * t0, -0.15 * t0)
			var p1 := from + Vector3(0, -length * t1, -0.15 * t1)
			paint_body(kit, fposmod(phase + k * 0.13, 1.0), 0.0, Mat.CABLE, minf(t1, 0.9))
			_tube(kit, b["body"], p0, p1, 0.035, 4)
			tip = p1
		_hot_tip(kit, b, tip, fposmod(phase + k * 0.13, 1.0), 0.04)


## A cut cable's end: a short stub that swings with it and glows white-hot (the bodies' shader, its sway at 1).
static func _hot_tip(kit: ShapeKit, b: Dictionary, at: Vector3, phase: float, radius: float) -> void:
	paint_body(kit, phase, 0.0, Mat.CABLE, 1.0)
	_tube(kit, b["body"], at, at - Vector3(0, 0.07, 0), radius, 4)


## A tube between two points of the kit's pose.
static func _tube(kit: ShapeKit, into: int, a: Vector3, z: Vector3, radius: float, sides: int) -> void:
	var along := z - a
	if along.length() < 0.001:
		return
	var dir := along.normalized()
	var pitch := rad_to_deg(asin(clampf(-dir.y, -1.0, 1.0)))
	var yaw := rad_to_deg(atan2(dir.x, dir.z))
	kit.prism(into, (a + z) * 0.5, radius, along.length() + radius, sides, Vector3(pitch, yaw, 0))


# --- Giants. ---

## Giant `t`: setback slabs from the abyss to its top, bands of windows, neon up its edges.
static func giant(kit: ShapeKit, b: Dictionary, t: Dictionary, rng: RandomNumberGenerator) -> void:
	var base := RuinsLayout.tower_xform(t)
	var w: float = t["width"]
	var d: float = t["depth"]
	var top: float = t["tall"]
	var y := -90.0
	kit.pose = base
	paint_body(kit, 0.9, 0.4)
	kit.box(b["body"], Vector3(0, (-float(t["foot"]) + y) * 0.5, 0), Vector3(w, float(t["foot"]) + y, d))
	var health_base := 1.0 if t.get("pristine", false) else rng.randf_range(0.55, 0.95)
	# Neon up its edges: [side, from, to, slot], drawn module by module so it keeps to each setback.
	var neon := []
	for k in rng.randi_range(0, 2):
		var y0 := rng.randf_range(-20.0, top * 0.4)
		neon.append([-1.0 if k == 0 else 1.0, y0, rng.randf_range(maxf(y0 + 20.0, top * 0.5), top), Slot.SIGN_A if rng.randf() < 0.5 else Slot.SIGN_B, rng.randf()])
	while y < top:
		var h := minf(rng.randf_range(8.0, 14.0), top - y)
		if h < 1.0:
			break
		kit.pose = base
		paint_body(kit, rng.randf_range(0.2, 0.6), 0.8)
		kit.box(b["body"], Vector3(0, y + h * 0.5, 0), Vector3(w, h - 0.3, d))
		kit.box(b["body"], Vector3(0, y + h - 0.15, 0), Vector3(w * 1.04, 0.3, d * 1.04))
		var rows := clampi(int(h / 2.6), 1, 5)
		for r in rows:
			var ry := y + (r + 0.5) * h / rows
			for face in 4:
				var out: Vector3 = [Vector3.FORWARD, Vector3.BACK, Vector3.LEFT, Vector3.RIGHT][face]
				var span := w if face < 2 else d
				var depth := (d if face < 2 else w) * 0.5 + 0.02
				var x := -span * 0.5 + 0.6
				while x < span * 0.5 - 0.6:
					var seg := rng.randf_range(1.2, 5.0)
					var gap := rng.randf_range(0.3, 2.4)
					var len := minf(seg, span * 0.5 - 0.6 - x)
					if len > 0.4 and (rng.randf() < 0.75 or t.get("pristine", false)):
						var mid := x + len * 0.5
						var at := Vector3(mid, ry, out.z * depth) if face < 2 else Vector3(out.x * depth, ry, mid)
						paint_light(kit, rng.randf(), 1.0 if t.get("pristine", false) else _health(rng, health_base), Slot.STRIP, rng.randf_range(1.6, 3.4))
						light_quad(kit, b["light"], at, Vector2(len, 0.5), out)
					x += seg + gap
		for n in neon:
			var lo := maxf(y, n[1])
			var hi := minf(y + h, n[2])
			if hi > lo + 0.2:
				paint_light(kit, n[4], 1.0, n[3], 2.6)
				kit.box(b["light"], Vector3(n[0] * (w * 0.5 + 0.1), (lo + hi) * 0.5, -d * 0.5 - 0.1), Vector3(0.35, hi - lo, 0.2))
		y += h
		if rng.randf() < 0.3 and w > 10.0:
			w *= rng.randf_range(0.82, 0.94)
			d *= rng.randf_range(0.82, 0.94)
	kit.pose = base * Transform3D(Basis.IDENTITY, Vector3(0, y, 0))
	if t.get("broken", false):
		for k in rng.randi_range(4, 8):
			paint_body(kit, 0.6, 0.8)
			var at := Vector3(rng.randf_range(-w, w) * 0.4, 0, rng.randf_range(-d, d) * 0.4)
			kit.box(b["body"], at + Vector3(0, 1.5, 0), Vector3(rng.randf_range(1.0, w * 0.4), rng.randf_range(2.0, 9.0), rng.randf_range(1.0, d * 0.4)), Vector3(rng.randf_range(-25, 25), rng.randf_range(0, 90), rng.randf_range(-25, 25)))
	else:
		for k in rng.randi_range(1, 3):
			var at := Vector3(rng.randf_range(-w, w) * 0.3, 0, rng.randf_range(-d, d) * 0.3)
			var tall := rng.randf_range(6.0, 22.0)
			paint_body(kit, 0.3, 0.9)
			kit.prism(b["body"], at + Vector3(0, tall * 0.5, 0), 0.3, tall, 5, Vector3(90, 0, 0))
			paint_light(kit, rng.randf(), 1.0, Slot.BEACON, 4.5)
			kit.box(b["light"], at + Vector3(0, tall, 0), Vector3.ONE * 0.9)


# --- Monoliths and the fallen. ---

## A directory monolith standing between `lo` and `hi` (a block's floor corners): `name` on it.
static func monolith(kit: ShapeKit, b: Dictionary, lo: Vector3, hi: Vector3, name: String, rng: RandomNumberGenerator) -> void:
	var across_x := (hi.x - lo.x) >= (hi.z - lo.z)
	var span := maxf(hi.x - lo.x, hi.z - lo.z)
	var thick := clampf(minf(hi.x - lo.x, hi.z - lo.z) * 0.4, 0.8, 1.6)
	var width := clampf(span - rng.randf_range(0.2, 0.9), 2.4, 7.0)
	var tall := rng.randf_range(9.0, 19.0)
	var mid := (lo + hi) * 0.5
	var yaw := (0.0 if across_x else PI * 0.5) + deg_to_rad(rng.randf_range(-5.0, 5.0)) + (PI if rng.randf() < 0.5 else 0.0)
	var base := Transform3D(Basis(Vector3.UP, yaw), mid)
	var cuts: Array[float] = [0.0]
	for k in rng.randi_range(1, 3):
		cuts.append(rng.randf_range(0.2, 0.85) * tall)
	cuts.sort()
	cuts.append(tall)
	var fallen_top := rng.randf() < 0.3
	# Its name goes on its tallest piece still standing, a little over that piece's middle.
	var text_piece := 0
	for i in cuts.size() - 1:
		if (i == cuts.size() - 2 and fallen_top) or cuts[i + 1] - cuts[i] <= cuts[text_piece + 1] - cuts[text_piece]:
			continue
		text_piece = i
	var text_y: float = (cuts[text_piece] + cuts[text_piece + 1]) * 0.5 + 0.5
	var label := name.to_upper()
	var perms := "DRWXR-XR-X"
	for i in cuts.size() - 1:
		var y0: float = cuts[i]
		var y1: float = cuts[i + 1]
		var top := i == cuts.size() - 2
		var shift := Vector3(rng.randf_range(-0.14, 0.14), 0, rng.randf_range(-0.1, 0.1)) * float(i)
		var turn := Basis.from_euler(Vector3(deg_to_rad(rng.randf_range(-2.0, 2.0)) * i, deg_to_rad(rng.randf_range(-3.0, 3.0)) * i, deg_to_rad(rng.randf_range(-2.0, 2.0)) * i))
		var pose := base * Transform3D(turn, Vector3(shift.x, y0, shift.z))
		if top and fallen_top:
			# Broken off and sliding: turned on its crack, its foot still on the piece below.
			var slide := deg_to_rad(rng.randf_range(9.0, 15.0)) * (1.0 if rng.randf() < 0.5 else -1.0)
			pose = base * Transform3D(Basis(Vector3.FORWARD, slide), Vector3(shift.x, y0 + 0.1, shift.z))
		kit.pose = pose
		paint_body(kit, rng.randf_range(0.0, 0.4), 0.9, Mat.STONE)
		kit.box(b["body"], Vector3(0, (y1 - y0) * 0.5, 0), Vector3(width, (y1 - y0) - 0.06, thick))
		if top:
			# The folder's tab.
			kit.frustum(b["body"], Vector3(-width * 0.29, y1 - y0 - 0.03, 0), Vector2(width * 0.42, thick), Vector2(width * 0.3, thick), 0.8)
			paint_light(kit, rng.randf(), 1.0, Slot.STRIP, 3.0)
			kit.box(b["light"], Vector3(0, y1 - y0 - 0.04, -thick * 0.5 - 0.01), Vector3(width * 0.96, 0.04, 0.02))
		if i == text_piece:
			_name_on(kit, b, label, Vector3(0, text_y - y0, -thick * 0.5 - 0.012), width - 0.6, 0.22, Slot.SIGN_A, Vector3.FORWARD, rng)
			_name_on(kit, b, perms, Vector3(0, text_y - y0 - 1.0, -thick * 0.5 - 0.012), minf(width - 0.6, 2.6), 0.06, Slot.SIGN_B, Vector3.FORWARD, rng)
			_name_on(kit, b, label, Vector3(0, text_y - y0, thick * 0.5 + 0.012), width - 0.6, 0.22, Slot.SIGN_A, Vector3.BACK, rng)


## `text` in the sign font, its middle at `at` on a face looking along `out` (FORWARD or BACK), at most `fit` wide with
## pixels at most `px`: half legible, a share of its letters stuttering or gone.
static func _name_on(kit: ShapeKit, b: Dictionary, text: String, at: Vector3, fit: float, px: float, slot: int, out: Vector3, rng: RandomNumberGenerator, steady: bool = false) -> void:
	var pw := minf(px, fit / maxf(float(SignFont.width(text)), 1.0))
	var tw := SignFont.width(text) * pw
	var letters := []
	for i in text.length():
		var roll := rng.randf()
		letters.append(1.0 if steady else (0.0 if roll < 0.14 else (rng.randf_range(0.3, 0.7) if roll < 0.32 else 1.0)))
	# A face looking down -z is read from -z, where +x is on the reader's left: its text runs toward -x.
	var flip := 1.0 if out.z > 0.0 else -1.0
	for run in SignFont.runs(text):
		var health: float = letters[int(run[0]) / SignFont.ADVANCE]
		if health <= 0.0:
			continue
		paint_light(kit, rng.randf() * 0.1 + float(run[0]) * 0.01, health, slot, 2.6)
		var x: float = (-tw * 0.5 + (float(run[0]) + float(run[2]) * 0.5) * pw) * flip
		var y: float = (SignFont.ROWS * 0.5 - float(run[1]) - 0.5) * pw
		kit.box(b["light"], at + Vector3(x, y, 0), Vector3(float(run[2]) * pw, pw * 0.9, 0.02))


## A rack tower lying broken across the block between `lo` and `hi`.
static func fallen(kit: ShapeKit, b: Dictionary, lo: Vector3, hi: Vector3, rng: RandomNumberGenerator) -> void:
	var along_x := (hi.x - lo.x) >= (hi.z - lo.z)
	var length := maxf(hi.x - lo.x, hi.z - lo.z) - 0.4
	var w := rng.randf_range(2.2, 3.0)
	var d := clampf(minf(hi.x - lo.x, hi.z - lo.z) - 0.6, 1.2, 2.2)
	var mid := (lo + hi) * 0.5
	var yaw := (0.0 if along_x else PI * 0.5) + deg_to_rad(rng.randf_range(-4.0, 4.0))
	var mh := 2.2
	var pieces := rng.randi_range(2, 3)
	var per := length / pieces
	var health := rng.randf_range(0.25, 0.55)
	var x := -length * 0.5
	for p in pieces:
		var tilt := deg_to_rad(rng.randf_range(-6.0, 6.0))
		var sink := rng.randf_range(0.1, 0.45)
		var seg := Transform3D(Basis(Vector3.UP, yaw), mid) * Transform3D(Basis(Vector3.UP, tilt), Vector3(x + 0.15, w * 0.5 - sink, 0))
		var y := 0.0
		while y < per - 0.4:
			var h := minf(mh, per - 0.3 - y)
			kit.pose = seg * Transform3D(Basis(Vector3.BACK, -PI * 0.5), Vector3(y, 0, 0))
			_rack_module(kit, b, w, d, h, rng, health, true, false, rng.randf())
			y += h
		kit.pose = seg
		for k in rng.randi_range(2, 4):
			paint_light(kit, rng.randf(), 0.5, Slot.HOT, 2.5)
			kit.box(b["light"], Vector3(per - 0.3, rng.randf_range(-w, w) * 0.4, rng.randf_range(-d, d) * 0.4), Vector3.ONE * 0.05)
		x += per


# --- Cover. ---

## A piece of cover (a RuinsLayout cover: kind, at, yaw, size), within its collision box.
static func cover(kit: ShapeKit, b: Dictionary, p: Dictionary, rng: RandomNumberGenerator) -> void:
	var sz: Vector3 = p["size"]
	var base := Transform3D(Basis(Vector3.UP, p["yaw"]), p["at"])
	match p["kind"]:
		"toppled":
			var health := rng.randf_range(0.4, 0.9)
			kit.pose = base * Transform3D(Basis(Vector3.BACK, -PI * 0.5), Vector3(-sz.x * 0.5, sz.y * 0.5 - 0.06, 0))
			_rack_module(kit, b, sz.y, sz.z, sz.x, rng, health, true, false, rng.randf() * 0.8)
			kit.pose = base
			if rng.randf() < 0.6:
				_spill(kit, b, Vector3(sz.x * 0.45, sz.y, rng.randf_range(-0.3, 0.3)), sz.y - 0.1, rng)
		"terminal":
			kit.pose = base
			paint_body(kit, 0.4, 0.8)
			kit.box(b["body"], Vector3(0, 0.42, 0.05), Vector3(sz.x * 0.5, 0.84, sz.z * 0.55))
			kit.frustum(b["body"], Vector3(0, 0.0, 0.05), Vector2(sz.x * 0.75, sz.z * 0.8), Vector2(sz.x * 0.5, sz.z * 0.55), 0.12)
			kit.box(b["body"], Vector3(0, 0.88, -0.12), Vector3(sz.x * 0.86, 0.06, 0.34), Vector3(14, 0, 0))
			kit.pose = base * Transform3D(Basis(Vector3.RIGHT, deg_to_rad(-18.0)), Vector3(0, 1.08, 0.12))
			paint_body(kit, 0.2, 0.9)
			kit.box(b["body"], Vector3(0, 0, 0.05), Vector3(sz.x * 0.94, 0.58, 0.1))
			paint_body(kit, 0.0, 0.0, Mat.GLASS)
			kit.box(b["body"], Vector3(0, 0, -0.005), Vector3(sz.x * 0.84, 0.48, 0.01))
			var dead := rng.randf() < 0.3
			var lines := 7
			for l in lines:
				var len := rng.randf_range(0.15, 0.75) * sz.x * 0.8
				paint_light(kit, float(l) / lines * 0.5 + rng.randf() * 0.04, 0.3 if dead else 1.0, Slot.SCREEN, 2.6)
				light_quad(kit, b["light"], Vector3(-sz.x * 0.36 + len * 0.5, 0.19 - l * 0.058, -0.012), Vector2(len, 0.022), Vector3.FORWARD)
			paint_light(kit, 0.9, 1.0, Slot.LED, 4.0)
			light_quad(kit, b["light"], Vector3(-sz.x * 0.36 + 0.02, 0.19 - lines * 0.058, -0.012), Vector2(0.03, 0.04), Vector3.FORWARD)
		"drives":
			kit.pose = base
			var y := 0.0
			var layer := 0
			while y < sz.y - 0.1:
				for k in rng.randi_range(1, 3):
					var at := Vector3(rng.randf_range(-sz.x, sz.x) * 0.3, y + 0.05, rng.randf_range(-sz.z, sz.z) * 0.25)
					paint_body(kit, rng.randf_range(0.2, 0.8), 0.7)
					kit.box(b["body"], at, Vector3(0.44, 0.1, 0.62), Vector3(rng.randf_range(-4, 4), rng.randf_range(-30, 30), rng.randf_range(-4, 4)))
					if rng.randf() < 0.5:
						paint_light(kit, rng.randf(), rng.randf_range(0.2, 0.9), Slot.LED, 3.0)
						kit.box(b["light"], at + Vector3(0.15, 0.0, -0.32), Vector3(0.04, 0.02, 0.01))
				y += 0.1
				layer += 1
			paint_body(kit, 0.5, 0.6)
			kit.frustum(b["body"], Vector3.ZERO, Vector2(sz.x * 0.9, sz.z * 0.9), Vector2(sz.x * 0.7, sz.z * 0.7), 0.12)
		"rubble":
			kit.pose = base
			for k in rng.randi_range(3, 5):
				paint_body(kit, rng.randf_range(0.3, 0.9), 0.75)
				var csz := Vector3(rng.randf_range(0.6, sz.x * 0.6), rng.randf_range(0.25, 0.5), rng.randf_range(0.5, sz.z * 0.8))
				var at := Vector3(rng.randf_range(-sz.x, sz.x) * 0.22, csz.y * 0.4 + rng.randf_range(0.0, sz.y - 0.6), rng.randf_range(-sz.z, sz.z) * 0.15)
				kit.box(b["body"], at, csz, Vector3(rng.randf_range(-28, 28), rng.randf_range(-40, 40), rng.randf_range(-28, 28)))
			for k in rng.randi_range(2, 4):
				var from := Vector3(rng.randf_range(-sz.x, sz.x) * 0.3, 0.3, rng.randf_range(-sz.z, sz.z) * 0.25)
				var to := from + Vector3(rng.randf_range(-0.3, 0.3), rng.randf_range(0.4, 0.9), rng.randf_range(-0.2, 0.2))
				paint_body(kit, 0.9, 0.3)
				_tube(kit, b["body"], from, to, 0.02, 4)
				paint_light(kit, rng.randf(), 0.55, Slot.HOT, 2.0)
				kit.box(b["light"], to, Vector3.ONE * 0.035)
		"post":
			# A guard post (M4): a slim clean pillar on a plinth, a ring of cyan near its top, a white beacon on it, its
			# light on the floor round it.
			kit.pose = base
			paint_body(kit, 0.0, 1.0, Mat.METAL)
			kit.box(b["body"], Vector3(0, sz.y * 0.5, 0), Vector3(sz.x, sz.y, sz.z))
			kit.frustum(b["body"], Vector3.ZERO, Vector2(sz.x * 1.9, sz.z * 1.9), Vector2(sz.x * 1.15, sz.z * 1.15), 0.16)
			paint_light(kit, 0.0, 1.0, Slot.STRIP, 1.8)
			kit.box(b["light"], Vector3(0, sz.y * 0.78, 0), Vector3(sz.x + 0.05, 0.05, sz.z + 0.05))
			for face in 4:
				var out: Vector3 = [Vector3.FORWARD, Vector3.BACK, Vector3.LEFT, Vector3.RIGHT][face]
				paint_light(kit, 0.25, 1.0, Slot.STRIP, 1.2)
				light_quad(kit, b["light"], out * (sz.x * 0.5 + 0.006) + Vector3(0, sz.y * 0.42, 0), Vector2(0.04, sz.y * 0.6), out)
			paint_light(kit, 0.35, 1.0, Slot.BEACON, 4.5)
			kit.box(b["light"], Vector3(0, sz.y + 0.2, 0), Vector3(0.28, 0.28, 0.28))
			paint_light(kit, 0.35, 1.0, Slot.BEACON, 0.6)
			light_quad(kit, b["light"], Vector3(0, 0.012, 0), Vector2(sz.x * 3.2, sz.z * 3.2), Vector3.UP)
		"console":
			# The records console (M4): a clean pedestal terminal, its screen slanted toward the reader, steady lines on it.
			kit.pose = base
			paint_body(kit, 0.0, 1.0)
			kit.box(b["body"], Vector3(0, 0.55, 0.05), Vector3(sz.x * 0.6, 1.1, sz.z * 0.6))
			kit.frustum(b["body"], Vector3(0, 0.0, 0.05), Vector2(sz.x, sz.z), Vector2(sz.x * 0.62, sz.z * 0.62), 0.14)
			kit.box(b["body"], Vector3(0, 1.12, -0.1), Vector3(sz.x * 0.9, 0.06, 0.4), Vector3(12, 0, 0))
			kit.pose = base * Transform3D(Basis(Vector3.RIGHT, deg_to_rad(-22.0)), Vector3(0, 1.32, 0.1))
			paint_body(kit, 0.0, 1.0)
			kit.box(b["body"], Vector3(0, 0, 0.05), Vector3(sz.x, 0.66, 0.1))
			paint_body(kit, 0.0, 0.0, Mat.GLASS)
			kit.box(b["body"], Vector3(0, 0, -0.005), Vector3(sz.x * 0.9, 0.56, 0.01))
			var lines := 7
			for l in lines:
				var len := (0.35 + 0.55 * fposmod(float(l) * 0.618, 1.0)) * sz.x * 0.8
				paint_light(kit, float(l) * 0.07, 1.0, Slot.SCREEN, 2.4)
				light_quad(kit, b["light"], Vector3(-sz.x * 0.4 + len * 0.5, 0.22 - l * 0.068, -0.012), Vector2(len, 0.024), Vector3.FORWARD)
			paint_light(kit, 0.9, 1.0, Slot.BEACON, 4.0)
			light_quad(kit, b["light"], Vector3(-sz.x * 0.4 + 0.02, 0.22 - lines * 0.068, -0.012), Vector2(0.035, 0.045), Vector3.FORWARD)
			paint_light(kit, 0.0, 1.0, Slot.STRIP, 1.8)
			kit.box(b["light"], Vector3(0, -0.36, -0.03), Vector3(sz.x * 0.96, 0.03, 0.02))
		"shard":
			kit.pose = base
			paint_body(kit, 0.2, 0.9, Mat.STONE)
			var top := Vector3(rng.randf_range(-0.2, 0.2), sz.y + 0.2, rng.randf_range(-0.1, 0.1))
			kit.spike(b["body"], Vector3(0, -0.4, 0), top, minf(sz.x, sz.z) * 0.5, 5, 0.3)
			for k in rng.randi_range(2, 5):
				paint_light(kit, rng.randf(), rng.randf_range(0.4, 1.0), Slot.SIGN_A, 4.0)
				kit.box(b["light"], Vector3(rng.randf_range(-0.15, 0.15), rng.randf_range(0.5, sz.y * 0.8), -minf(sz.x, sz.z) * 0.3), Vector3(rng.randf_range(0.04, 0.16), 0.04, 0.02))


# --- The floor's edges, holes and slabs. ---

## Edge `e` of `layout` (a floor side meeting the void or a hole): its parapet or its overlook, standing in its
## collision box (the side's line, out PARAPET_T), and the broken slab hanging off it.
static func edge(kit: ShapeKit, b: Dictionary, layout: RuinsLayout, e: Dictionary, rng: RandomNumberGenerator) -> void:
	var side: Vector2i = RuinsLayout.SIDES[e["side"]]
	var out := Vector3(side.x, 0, side.y)
	if e.get("drop", false):
		lip_at(kit, b, layout.center(e["cell"]) + out * RuinsLayout.CELL_M * 0.5, out, rng)
		return
	edge_at(kit, b, layout.center(e["cell"]) + out * RuinsLayout.CELL_M * 0.5, out, e["hole"], e["overlook"], rng, layout.pristine_at(layout.center(e["cell"])))


## A lip along a step's upper edge (M6): a low rail of light a cell long (RuinsLayout.LIP_H: over a walker's step, under a
## jump), its middle on the floor's edge at `line`, facing `out` (the drop), a strip of light along its top so the edge
## reads from across the floor and from below.
static func lip_at(kit: ShapeKit, b: Dictionary, line: Vector3, out: Vector3, rng: RandomNumberGenerator) -> void:
	var along := Vector3(out.z, 0, -out.x)
	var base := Transform3D(Basis(along, Vector3.UP, out), line)
	var half := RuinsLayout.CELL_M * 0.5
	var t := RuinsLayout.LIP_T
	var h := RuinsLayout.LIP_H
	kit.pose = base
	paint_body(kit, 0.35, 0.9)
	kit.box(b["body"], Vector3(0, h * 0.5, -t * 0.5), Vector3(half * 2.0, h, t * 0.9))
	for x in [-half + 0.3, 0.0, half - 0.3]:
		kit.box(b["body"], Vector3(x, h * 0.5 + 0.06, -t * 0.5), Vector3(0.12, h + 0.12, t * 1.2))
	paint_light(kit, rng.randf(), _health(rng, 0.9), Slot.STRIP, 2.2)
	kit.box(b["light"], Vector3(0, h + 0.02, -t * 0.5), Vector3(half * 1.9, 0.03, t * 0.5))
	paint_light(kit, rng.randf(), _health(rng, 0.8), Slot.STRIP, 1.6)
	kit.box(b["light"], Vector3(0, 0.1, 0.01), Vector3(half * 1.9, 0.03, 0.012))


## A cliff under a step's upper edge (M6): the band above's floor standing on a wall of racks down to the band below,
## a cell wide, its modules' lights facing the lower floor; `e` the drop edge of `layout`.
static func cliff(kit: ShapeKit, b: Dictionary, layout: RuinsLayout, e: Dictionary, rng: RandomNumberGenerator) -> void:
	var side: Vector2i = RuinsLayout.SIDES[e["side"]]
	var out := Vector3(side.x, 0, side.y)
	var c: Vector2i = e["cell"]
	var drop := layout.floor_y(c) - layout.floor_y(c + side)
	var at := layout.center(c) + out * (RuinsLayout.CELL_M * 0.5 - 0.45)
	var t := {"at": at, "tall": -RuinsLayout.SLAB_M - 0.02, "foot": drop + 0.4, "width": RuinsLayout.CELL_M - 0.05, "depth": 0.9, "yaw": atan2(-out.x, -out.z), "lean": Vector2.ZERO, "seed": rng.randi(), "inside": false}
	rack_tower(kit, b, t, rng, false)


## A ramp down a step (M6): the slope from the step line to its foot as plates of floor, a rail of light along each side
## (the rails' boxes are the plan's), its sides racks down to the band below, so from the floor it reads as a stair of
## servers; `r` a ramp of `layout`.
static func ramp(kit: ShapeKit, b: Dictionary, layout: RuinsLayout, r: Dictionary, rng: RandomNumberGenerator) -> void:
	var xf := RuinsLayout.ramp_xform(r)
	var top: Vector3 = r["top"]
	var foot: Vector3 = r["foot"]
	var length := top.distance_to(foot)
	var w := RuinsLayout.CELL_M
	kit.pose = xf
	# The deck: plates along the slope, each a slab's face.
	var plates := maxi(int(length / 2.0), 2)
	var pitch := length / float(plates)
	for i in plates:
		var z := -length * 0.5 + pitch * (i + 0.5)
		paint_floor(kit, rng.randf_range(0.1, 0.5), 0, top.y)
		kit.box(b["floor"], Vector3(0, -RuinsLayout.SLAB_M * 0.5, z), Vector3(w, RuinsLayout.SLAB_M, pitch - 0.04))
	# The rails: posts and a lit top bar, stopping short of the foot.
	var rail_len := length - 1.0
	for sx in [-1.0, 1.0]:
		var rx := float(sx) * (w * 0.5 - RuinsLayout.RAIL_T * 0.5)
		paint_body(kit, 0.3, 0.9)
		var z := -rail_len * 0.5 + 0.5
		while z < rail_len * 0.5 + 0.5:
			kit.box(b["body"], Vector3(rx, RuinsLayout.RAIL_H * 0.5, z), Vector3(0.1, RuinsLayout.RAIL_H, 0.1))
			z += 1.6
		kit.box(b["body"], Vector3(rx, RuinsLayout.RAIL_H - 0.03, 0.5), Vector3(RuinsLayout.RAIL_T, 0.06, rail_len))
		paint_light(kit, rng.randf(), 1.0, Slot.STRIP, 1.1)
		kit.box(b["light"], Vector3(rx, RuinsLayout.RAIL_H + 0.02, 0.5), Vector3(0.06, 0.025, rail_len * 0.98))
	# The sides: racks under the deck, down to the band below, facing out.
	var drop := top.y - foot.y
	var modules := maxi(int(length / 3.0), 2)
	for sx in [-1.0, 1.0]:
		for i in modules:
			var k := (float(i) + 0.5) / float(modules)
			var at := top.lerp(foot, k) + Vector3(float(sx) * (w * 0.5 - 0.5), 0, 0)
			var deep := drop * (1.0 - k) + 0.3
			if deep < 0.8:
				continue
			var t := {"at": at, "tall": -0.5, "foot": deep, "width": length / float(modules) * 0.95, "depth": 0.9, "yaw": atan2(-float(sx), 0.0), "lean": Vector2.ZERO, "seed": rng.randi(), "inside": false}
			rack_tower(kit, b, t, rng, false)


## A parapet (or an overlook) a cell long, its middle on the floor's edge at `line`, facing `out` (C37: anywhere, the
## pocket's own; edge() puts one on a plan's edge). `pristine` (M4): one clean wall the cell long, a steady strip along its
## foot and a rail of light along its top, nothing hanging off it.
static func edge_at(kit: ShapeKit, b: Dictionary, line: Vector3, out: Vector3, over_hole: bool, overlook: bool, rng: RandomNumberGenerator, pristine: bool = false) -> void:
	var e := {"hole": over_hole, "overlook": overlook}
	var along := Vector3(out.z, 0, -out.x)  # right-handed with up and out: never a mirror, so faces keep their winding
	var base := Transform3D(Basis(along, Vector3.UP, out), line)
	var half := RuinsLayout.CELL_M * 0.5 + 0.1
	var t := RuinsLayout.PARAPET_T
	kit.pose = base
	if pristine:
		paint_body(kit, 0.0, 1.0)
		kit.box(b["body"], Vector3(0, RuinsLayout.PARAPET_H * 0.5, t * 0.5), Vector3(half * 2.0, RuinsLayout.PARAPET_H, t * 0.9))
		kit.box(b["body"], Vector3(0, RuinsLayout.PARAPET_H + 0.04, t * 0.5), Vector3(half * 2.0, 0.08, t * 1.1))
		paint_light(kit, 0.0, 1.0, Slot.STRIP, 1.6)
		kit.box(b["light"], Vector3(0, 0.12, -t * 0.45 - 0.01), Vector3(half * 2.0, 0.03, 0.012))
		paint_light(kit, 0.5, 1.0, Slot.BEACON, 1.2)
		kit.box(b["light"], Vector3(0, RuinsLayout.PARAPET_H - 0.05, -t * 0.45 - 0.01), Vector3(half * 2.0, 0.025, 0.012))
		return
	if e["overlook"]:
		paint_body(kit, 0.4, 0.9)
		kit.box(b["body"], Vector3(0, 0.09, t * 0.5), Vector3(half * 2.0, 0.18, t * 0.7))
		var x := -half + 0.1
		while x < half:
			var bend := rng.randf() < 0.14
			kit.pose = base * Transform3D(Basis(Vector3.RIGHT, deg_to_rad(rng.randf_range(10.0, 26.0)) if bend else 0.0), Vector3(x, 0.18, t * 0.4))
			kit.box(b["body"], Vector3(0, 0.5, 0), Vector3(0.07, 1.0, 0.07))
			x += rng.randf_range(0.9, 1.3)
		kit.pose = base
		var broken := rng.randf() < 0.22
		if broken:
			var cut := rng.randf_range(-0.8, 0.8)
			kit.pose = base * Transform3D(Basis(Vector3.BACK, -deg_to_rad(rng.randf_range(4.0, 12.0))), Vector3(-half, 1.15, t * 0.4))
			kit.box(b["body"], Vector3((cut + half) * 0.5, 0, 0), Vector3(cut + half, 0.06, 0.08))
			kit.pose = base * Transform3D(Basis(Vector3.BACK, deg_to_rad(rng.randf_range(4.0, 12.0))), Vector3(half, 1.15, t * 0.4))
			kit.box(b["body"], Vector3(-(half - cut) * 0.5, 0, 0), Vector3(half - cut, 0.06, 0.08))
			kit.pose = base
		else:
			kit.box(b["body"], Vector3(0, 1.15, t * 0.4), Vector3(half * 2.0, 0.06, 0.08))
			paint_light(kit, rng.randf(), _health(rng, 0.85), Slot.STRIP, 1.3)
			kit.box(b["light"], Vector3(0, 1.11, t * 0.4 - 0.045), Vector3(half * 1.9, 0.025, 0.012))
		paint_body(kit, 0.4, 0.6)
		kit.box(b["body"], Vector3(0, 0.62, t * 0.4), Vector3(half * 2.0, 0.04, 0.05))
	else:
		var x := -half
		while x < half - 0.2:
			var len := minf(rng.randf_range(0.9, 2.2), half - x)
			var h := rng.randf_range(1.3, 2.6) if not e["hole"] else rng.randf_range(1.3, 1.7)
			var lean := deg_to_rad(rng.randf_range(0.0, 5.0))
			kit.pose = base * Transform3D(Basis(Vector3.RIGHT, lean) * Basis(Vector3.UP, deg_to_rad(rng.randf_range(-3, 3))), Vector3(x + len * 0.5, 0, t * 0.5))
			paint_body(kit, rng.randf_range(0.3, 0.8), 0.85)
			kit.box(b["body"], Vector3(0, h * 0.5, 0), Vector3(len - rng.randf_range(0.02, 0.12), h, t * 0.9))
			if rng.randf() < 0.5:
				kit.frustum(b["body"], Vector3(rng.randf_range(-0.2, 0.2), h, 0), Vector2(len * 0.6, t * 0.8), Vector2(len * 0.2, t * 0.3), rng.randf_range(0.1, 0.4))
			paint_light(kit, rng.randf(), _health(rng, 0.8), Slot.STRIP, 1.4)
			kit.box(b["light"], Vector3(0, 0.12, -t * 0.45 - 0.01), Vector3(len * 0.9, 0.03, 0.012))
			x += len
	# The slab broken off past it, hanging into the void.
	if rng.randf() < (0.75 if not e["hole"] else 0.5):
		for k in rng.randi_range(1, 3):
			var pitch := deg_to_rad(rng.randf_range(12.0, 55.0))
			var csz := Vector3(rng.randf_range(0.9, 2.2), RuinsLayout.SLAB_M * rng.randf_range(0.7, 1.0), rng.randf_range(0.7, 1.6) if not e["hole"] else rng.randf_range(0.5, 0.9))
			kit.pose = base * Transform3D(Basis(Vector3.RIGHT, pitch), Vector3(rng.randf_range(-1.4, 1.4), -0.08, t + 0.05))
			paint_body(kit, 0.6, 0.7)
			kit.box(b["body"], Vector3(0, -csz.y * 0.5, csz.z * 0.5), csz)
			if rng.randf() < 0.6:
				_spill(kit, b, Vector3(rng.randf_range(-0.4, 0.4), -csz.y, csz.z), rng.randf_range(1.5, 4.5), rng)


## Hole `h` of `layout`: a tower rising out of the void through it, and the void's glow far below.
static func hole(kit: ShapeKit, b: Dictionary, layout: RuinsLayout, h: Dictionary, rng: RandomNumberGenerator) -> void:
	var r: Rect2i = h["rect"]
	var lo := layout.center(r.position) - Vector3(RuinsLayout.CELL_M, 0, RuinsLayout.CELL_M) * 0.5
	var hi := layout.center(r.end - Vector2i.ONE) + Vector3(RuinsLayout.CELL_M, 0, RuinsLayout.CELL_M) * 0.5
	var mid := (lo + hi) * 0.5
	var room := Vector2(hi.x - lo.x, hi.z - lo.z) - Vector2.ONE * (RuinsLayout.PARAPET_T * 2.0 + 0.7)
	var t := {"at": mid + Vector3(rng.randf_range(-0.3, 0.3), 0, rng.randf_range(-0.3, 0.3)), "tall": rng.randf_range(-3.0, 6.0), "foot": 80.0, "width": clampf(room.x * rng.randf_range(0.6, 0.85), 1.6, 3.2), "depth": clampf(room.y * rng.randf_range(0.5, 0.8), 1.2, 2.4), "yaw": rng.randf_range(-0.2, 0.2), "lean": Vector2(rng.randf_range(-3.0, 3.0), rng.randf_range(-3.0, 3.0)), "inside": true}
	rack_tower(kit, b, t, rng, rng.randf() < 0.5)
	kit.pose = Transform3D(Basis.IDENTITY, mid + Vector3(0, -38.0, 0))
	paint_light(kit, rng.randf(), 1.0, Slot.VOID, 1.4)
	light_quad(kit, b["light"], Vector3.ZERO, Vector2(hi.x - lo.x, hi.z - lo.z) * 1.4, Vector3.UP)


## Floor cell `c` of `layout` as its slab, `damage` its cracks, `rims` its sides meeting the void (a bit each).
static func slab(kit: ShapeKit, b: Dictionary, layout: RuinsLayout, c: Vector2i, damage: float, rims: int) -> void:
	slab_at(kit, b, layout.center(c), damage, rims)


## A cell's slab with its top's middle at `at` (C37: anywhere, the pocket's deck).
static func slab_at(kit: ShapeKit, b: Dictionary, at: Vector3, damage: float, rims: int) -> void:
	kit.pose = Transform3D.IDENTITY
	paint_floor(kit, damage, rims, at.y)
	kit.box(b["floor"], at - Vector3(0, RuinsLayout.SLAB_M * 0.5, 0), Vector3(RuinsLayout.CELL_M, RuinsLayout.SLAB_M, RuinsLayout.CELL_M))


# --- The breach (C37). ---

## The gate (layout.gate): the exit's side onto the void as a portal: a pylon each side with neon up its inner face, a
## lintel over them with a beacon, and a low barrier across (the parapet's box still stands there).
static func gate(kit: ShapeKit, b: Dictionary, g: Dictionary, rng: RandomNumberGenerator) -> void:
	var out: Vector3 = g["out"]
	var along := Vector3(out.z, 0, -out.x)
	var base := Transform3D(Basis(along, Vector3.UP, out), g["at"])
	var half := RuinsLayout.CELL_M * 0.5
	var tall := rng.randf_range(6.2, 7.4)
	for sx in [-1.0, 1.0]:
		kit.pose = base * Transform3D(Basis(Vector3.BACK, deg_to_rad(rng.randf_range(-1.5, 1.5))), Vector3(sx * (half - 0.2), 0, 0.2))
		paint_body(kit, 0.45, 0.95)
		kit.box(b["body"], Vector3(0, tall * 0.5, 0), Vector3(0.8, tall, 0.9))
		kit.frustum(b["body"], Vector3(0, tall, 0), Vector2(0.8, 0.9), Vector2(0.5, 0.6), 0.5)
		paint_light(kit, rng.randf(), 1.0, Slot.STRIP, 3.0)
		kit.box(b["light"], Vector3(-sx * 0.41, tall * 0.5, 0), Vector3(0.03, tall - 0.6, 0.12))
		for k in 5:
			paint_light(kit, rng.randf(), _health(rng, 0.8), Slot.LED, 2.4)
			light_quad(kit, b["light"], Vector3(rng.randf_range(-0.25, 0.25), 0.8 + k * 1.1, -0.46), Vector2(0.14, 0.06), Vector3.FORWARD)
	kit.pose = base
	paint_body(kit, 0.4, 0.95)
	kit.box(b["body"], Vector3(0, tall - 0.35, 0.2), Vector3(half * 2.0 + 0.4, 0.7, 0.8))
	paint_light(kit, rng.randf(), 1.0, Slot.STRIP, 3.0)
	kit.box(b["light"], Vector3(0, tall - 0.72, 0.2), Vector3(half * 2.0 - 0.8, 0.04, 0.5))
	paint_light(kit, rng.randf(), 1.0, Slot.BEACON, 5.0)
	kit.box(b["light"], Vector3(0, tall + 0.1, 0.2), Vector3(0.3, 0.2, 0.3))
	# The low barrier: posts and two bars, under a jump's reach.
	paint_body(kit, 0.5, 0.8)
	for k in 5:
		kit.box(b["body"], Vector3(-half + 0.5 + k * (half * 2.0 - 1.0) / 4.0, 0.55, 0.15), Vector3(0.08, 1.1, 0.08))
	kit.box(b["body"], Vector3(0, 1.08, 0.15), Vector3(half * 2.0 - 0.6, 0.06, 0.06))
	kit.box(b["body"], Vector3(0, 0.6, 0.15), Vector3(half * 2.0 - 0.6, 0.05, 0.05))


## The gangway (layout.gangway): plates out from the gate into the void, rails lit along both sides, struts under it,
## and its far end broken off: the last plates bent down, one gone, cables hanging from where it tore.
static func gangway(kit: ShapeKit, b: Dictionary, g: Dictionary, rng: RandomNumberGenerator) -> void:
	var out: Vector3 = g["out"]
	var along := Vector3(out.z, 0, -out.x)
	var base := Transform3D(Basis(along, Vector3.UP, out), g["at"])
	var length: float = g["length"]
	var width: float = g["width"]
	var plate := 1.5
	var n := int(length / plate)
	for i in n:
		var z := RuinsLayout.PARAPET_T + (i + 0.5) * plate
		var bend := 0.0
		var drop := 0.0
		if i >= n - 3:
			var k := float(i - (n - 3) + 1)
			bend = deg_to_rad(9.0 * k + rng.randf_range(0.0, 6.0))
			drop = 0.35 * k * k
		if i == n - 2 and rng.randf() < 0.7:
			continue
		kit.pose = base * Transform3D(Basis(Vector3.RIGHT, bend) * Basis(Vector3.BACK, deg_to_rad(rng.randf_range(-2.0, 2.0))), Vector3(0, -0.15 - drop, z))
		paint_body(kit, rng.randf_range(0.3, 0.7), 0.85)
		kit.box(b["body"], Vector3.ZERO, Vector3(width, 0.18, plate - 0.06))
		for sx in [-1.0, 1.0]:
			kit.box(b["body"], Vector3(sx * width * 0.5, 0.55, 0), Vector3(0.06, 1.1, 0.06))
			kit.box(b["body"], Vector3(sx * width * 0.5, 1.1, 0), Vector3(0.07, 0.07, plate))
			paint_light(kit, rng.randf(), _health(rng, 0.85), Slot.STRIP, 2.2)
			kit.box(b["light"], Vector3(sx * (width * 0.5 - 0.06), 0.12, 0), Vector3(0.03, 0.03, plate * 0.92))
			paint_body(kit, rng.randf_range(0.3, 0.7), 0.85)
		if i % 2 == 0:
			kit.box(b["body"], Vector3(0, -1.2, 0), Vector3(0.25, 2.2, 0.25), Vector3(rad_to_deg(0.35), 0, 0))
	# Torn ends: cables hanging from the break.
	kit.pose = base * Transform3D(Basis.IDENTITY, Vector3(0, -0.3, RuinsLayout.PARAPET_T + (n - 3) * plate))
	for k in rng.randi_range(2, 4):
		var from := Vector3(rng.randf_range(-width, width) * 0.4, 0, 0)
		_spill(kit, b, from, rng.randf_range(3.0, 7.0), rng)


## The shaft under a breach's hatch (layout.breach_cell): a rim round the opening, its walls going down `deep` metres,
## lit in seams, and the glow far down where it opens over the pocket.
static func shaft(kit: ShapeKit, b: Dictionary, top: Vector3, opening: float, deep: float, rng: RandomNumberGenerator) -> void:
	var half := RuinsLayout.CELL_M * 0.5
	var inner := opening * 0.5
	var rim := half - inner
	kit.pose = Transform3D(Basis.IDENTITY, top)
	paint_floor(kit, 0.4, 0, top.y)
	for side in 4:
		var o := Vector3(RuinsLayout.SIDES[side].x, 0, RuinsLayout.SIDES[side].y)
		var across := Vector3(absf(o.z), 0, absf(o.x))
		var size := across * (RuinsLayout.CELL_M if side % 2 == 0 else opening) + o.abs() * rim + Vector3(0, RuinsLayout.SLAB_M, 0)
		kit.box(b["floor"], o * (inner + rim * 0.5) - Vector3(0, RuinsLayout.SLAB_M * 0.5, 0), size)
	paint_body(kit, 0.35, 1.0)
	for side in 4:
		var o := Vector3(RuinsLayout.SIDES[side].x, 0, RuinsLayout.SIDES[side].y)
		var across := Vector3(absf(o.z), 0, absf(o.x))
		# A raised lip round the opening, and the walls going down.
		kit.box(b["body"], o * (inner + 0.09), across * (opening + 0.36) + o.abs() * 0.18 + Vector3(0, 0.1, 0))
		kit.box(b["body"], o * (inner + 0.1) + Vector3(0, -deep * 0.5, 0), across * (opening + 0.2) + o.abs() * 0.2 + Vector3(0, deep, 0))
		for k in 3:
			paint_light(kit, rng.randf(), 1.0, Slot.STRIP, 2.6)
			kit.box(b["light"], o * (inner - 0.01) + across * rng.randf_range(-inner, inner) * 0.8 + Vector3(0, -0.6 - k * deep * 0.3, 0), across * 0.04 + Vector3(0, deep * 0.22, 0) + o.abs() * 0.02)
			paint_body(kit, 0.35, 1.0)


# --- Cables and signs. ---

## Cable `c` (a RuinsLayout cable): a bundle of two or three, swinging where it hangs loose, its cut ends hot.
static func cable(kit: ShapeKit, b: Dictionary, c: Dictionary, rng: RandomNumberGenerator) -> void:
	kit.pose = Transform3D.IDENTITY
	var phase := rng.randf()
	var count := rng.randi_range(2, 3)
	var cut: bool = float(c["cut"]) > 0.0
	for k in count:
		var off := Vector3(rng.randf_range(-0.25, 0.25), rng.randf_range(-0.2, 0.2), rng.randf_range(-0.25, 0.25))
		var radius := rng.randf_range(0.05, 0.12)
		for line in RuinsLayout.cable_points(c, 16):
			var n: int = line.size()
			for i in n - 1:
				var swing := 0.0
				if cut:
					swing = minf(pow(float(i + 1) / float(n - 1), 1.5), 0.9)
				else:
					swing = 0.25 * sin(PI * float(i + 1) / float(n - 1))
				paint_body(kit, fposmod(phase + k * 0.21, 1.0), 0.0, Mat.CABLE, swing)
				_tube(kit, b["body"], (line[i] as Vector3) + off * (1.0 - swing * 0.5), (line[i + 1] as Vector3) + off * (1.0 - swing * 0.5), radius, 5)
			if cut:
				_hot_tip(kit, b, (line[n - 1] as Vector3) + off * 0.55, fposmod(phase + k * 0.21, 1.0), radius * 0.8)


## Where cable `c`'s cut ends hang, for the sparks: [] when it is whole.
static func cable_tips(c: Dictionary) -> Array[Vector3]:
	var out: Array[Vector3] = []
	if float(c["cut"]) <= 0.0:
		return out
	for line in RuinsLayout.cable_points(c, 16):
		out.append(line[line.size() - 1])
	return out


## Sign `s` (a RuinsLayout sign) on tower `t`: a dark board standing out from the tower's face toward the district,
## its letters in neon (upright, stacked, or wide), a tube round it, brackets back to the tower. Returns the place in
## front of its face, for its light.
static func sign(kit: ShapeKit, b: Dictionary, t: Dictionary, s: Dictionary, rng: RandomNumberGenerator) -> Vector3:
	var text: String = (s["text"] as String).to_upper()
	var upright: bool = s["upright"]
	var slot: int = Slot.SIGN_A if s["slot"] == 0 else Slot.SIGN_B
	var d: float = t["depth"]
	var stand := rng.randf_range(0.7, 1.6)
	var base := RuinsLayout.tower_xform(t) * Transform3D(Basis.IDENTITY, Vector3(rng.randf_range(-0.4, 0.4) * float(t["width"]), s["height"], -d * 0.5 - stand))
	var px := rng.randf_range(0.14, 0.2) if upright else rng.randf_range(0.2, 0.32)
	var size := Vector2.ZERO
	if upright:
		text = text.replace(" ", "")
		if text.length() > 8:
			text = text.substr(0, 8)
		size = Vector2((SignFont.COLS + 2) * px, text.length() * SignFont.LINE * px + px)
	else:
		px = minf(px, 14.0 / maxf(float(SignFont.width(text)), 1.0))
		size = Vector2(SignFont.width(text) * px + px * 3.0, (SignFont.ROWS + 3) * px)
	var pristine: bool = s.get("pristine", false)
	var health := 1.0 if pristine or rng.randf() < 0.75 else rng.randf_range(0.4, 0.8)
	kit.pose = base
	paint_body(kit, 0.0 if pristine else 0.5, 1.0 if pristine else 0.5)
	kit.box(b["body"], Vector3.ZERO, Vector3(size.x, size.y, 0.18))
	for sx in [-1.0, 1.0]:
		kit.box(b["body"], Vector3(sx * size.x * 0.35, 0, stand * 0.5), Vector3(0.12, 0.12, stand))
	paint_light(kit, rng.randf(), health, slot, 2.2)
	for edge in [[Vector3(0, size.y * 0.5, -0.1), Vector3(size.x, 0.05, 0.05)], [Vector3(0, -size.y * 0.5, -0.1), Vector3(size.x, 0.05, 0.05)], [Vector3(size.x * 0.5, 0, -0.1), Vector3(0.05, size.y, 0.05)], [Vector3(-size.x * 0.5, 0, -0.1), Vector3(0.05, size.y, 0.05)]]:
		kit.box(b["light"], edge[0], edge[1])
	var dead_letter := rng.randi_range(0, text.length() - 1) if rng.randf() < 0.4 and not pristine else -1
	# The board looks down -z, read from -z, where +x is on the reader's left: its letters run toward -x.
	var flip := -1.0
	if upright:
		for i in text.length():
			var letter := text[i]
			var y0 := size.y * 0.5 - px - i * SignFont.LINE * px
			var lh := health if i != dead_letter else 0.35
			for run in SignFont.runs(letter):
				paint_light(kit, rng.randf() * 0.05 + i * 0.07, lh, slot, 2.3)
				var x: float = (-SignFont.COLS * 0.5 * px + (float(run[0]) + float(run[2]) * 0.5) * px) * flip
				kit.box(b["light"], Vector3(x, y0 - (float(run[1]) + 0.5) * px, -0.1), Vector3(float(run[2]) * px, px * 0.88, 0.03))
	else:
		var tw := SignFont.width(text) * px
		for run in SignFont.runs(text):
			var i: int = int(run[0]) / SignFont.ADVANCE
			paint_light(kit, rng.randf() * 0.05 + i * 0.07, health if i != dead_letter else 0.35, slot, 2.3)
			var x: float = (-tw * 0.5 + (float(run[0]) + float(run[2]) * 0.5) * px) * flip
			kit.box(b["light"], Vector3(x, (SignFont.ROWS * 0.5 - float(run[1]) - 0.5) * px, -0.1), Vector3(float(run[2]) * px, px * 0.88, 0.03))
	return base * Vector3(0, 0, -2.5)


## A record stack (M4): a clean slab of black glass standing between `lo` and `hi` (a block's floor corners), `tall`
## metres, rows of white record strips up both long faces, every one alive and steady, a frame of cyan light up its
## edges and along its cap, its name plate at eye level on both faces, and a white beacon on top.
static func stack(kit: ShapeKit, b: Dictionary, lo: Vector3, hi: Vector3, name: String, tall: float, rng: RandomNumberGenerator) -> void:
	var across_x := (hi.x - lo.x) >= (hi.z - lo.z)
	var span := maxf(hi.x - lo.x, hi.z - lo.z) - 0.2
	var thick := minf(hi.x - lo.x, hi.z - lo.z) - 0.2
	var mid := (lo + hi) * 0.5
	kit.pose = Transform3D(Basis(Vector3.UP, 0.0 if across_x else PI * 0.5), mid)
	paint_body(kit, 0.0, 1.0, Mat.GLASS)
	kit.box(b["body"], Vector3(0, tall * 0.5, 0), Vector3(span, tall, thick))
	paint_body(kit, 0.0, 1.0, Mat.METAL)
	kit.box(b["body"], Vector3(0, 0.15, 0), Vector3(span + 0.3, 0.3, thick + 0.3))
	kit.box(b["body"], Vector3(0, tall + 0.12, 0), Vector3(span + 0.3, 0.24, thick + 0.3))
	for sx in [-1.0, 1.0]:
		for sz in [-1.0, 1.0]:
			kit.box(b["body"], Vector3(sx * (span * 0.5 + 0.04), tall * 0.5, sz * (thick * 0.5 + 0.04)), Vector3(0.1, tall, 0.1))
	# The record strips: a row every 0.55 m up each long face, split into drawers, a status LED at each drawer's end.
	var rows := int((tall - 1.4) / 0.55)
	var drawers := maxi(int(span / 1.4), 1)
	var w := (span - 0.5) / drawers - 0.14
	for face in [-1.0, 1.0]:
		var z: float = face * (thick * 0.5 + 0.012)
		for r in rows:
			var y := 0.95 + r * 0.55
			for k in drawers:
				var x := -span * 0.5 + 0.25 + (span - 0.5) * (k + 0.5) / drawers
				paint_light(kit, float(r) * 0.03 + float(k) * 0.17, 1.0, Slot.BEACON, 2.0)
				light_quad(kit, b["light"], Vector3(x, y, z), Vector2(w, 0.065), Vector3(0, 0, face))
				paint_light(kit, rng.randf(), 1.0, Slot.LED, 3.2)
				light_quad(kit, b["light"], Vector3(x + w * 0.5 + 0.04, y, z), Vector2(0.04, 0.04), Vector3(0, 0, face))
	# The frame of cyan up its edges and along its cap; the name plate on both faces; the beacon.
	paint_light(kit, 0.0, 1.0, Slot.STRIP, 1.6)
	for sx in [-1.0, 1.0]:
		for sz in [-1.0, 1.0]:
			kit.box(b["light"], Vector3(sx * (span * 0.5 + 0.04), tall * 0.5, sz * (thick * 0.5 + 0.04)), Vector3(0.05, tall - 0.3, 0.05))
	for face in [-1.0, 1.0]:
		kit.box(b["light"], Vector3(0, tall - 0.02, face * (thick * 0.5 + 0.03)), Vector3(span, 0.035, 0.03))
		_name_on(kit, b, name.to_upper(), Vector3(0, 2.55, face * (thick * 0.5 + 0.014)), minf(span - 0.8, 5.0), 0.16, Slot.SIGN_A, Vector3(0, 0, face), rng, true)
	paint_light(kit, 0.2, 1.0, Slot.HOT, 4.0)
	kit.box(b["light"], Vector3(0, tall + 0.42, 0), Vector3(0.32, 0.32, 0.32))


## The records screen (M4): `s` the plan's screen (RuinsLayout.vault["screen"]: at, out, size), a pane of dark glass in a
## clean frame, and on it `lines` (a "|" between two) in the sign font, left aligned from its top; a run of "#" in a line
## is drawn as a solid bar into `b["mark"]` (the redaction: the world paints that bucket red), never as letters. Built into
## its own kit (the world gives its light and its mark materials of their own, dark until a mission lights them). Returns
## where its light falls (in front of it, at a lamp's height).
static func records_screen(kit: ShapeKit, b: Dictionary, s: Dictionary, lines: String, rng: RandomNumberGenerator) -> Vector3:
	var size: Vector2 = s["size"]
	var foot := 1.1
	# Its own frame: -z toward the reader (the pose looks along `out`, so -z is `out`), +x on the reader's left.
	kit.pose = Transform3D(Basis.looking_at(s["out"], Vector3.UP), s["at"])
	paint_body(kit, 0.0, 1.0, Mat.METAL)
	for sx in [-1.0, 1.0]:
		kit.box(b["body"], Vector3(sx * (size.x * 0.5 + 0.35), (foot + size.y + 0.6) * 0.5, 0.1), Vector3(0.5, foot + size.y + 0.6, 0.5))
	kit.box(b["body"], Vector3(0, foot + size.y + 0.42, 0.1), Vector3(size.x + 1.2, 0.36, 0.5))
	kit.box(b["body"], Vector3(0, foot * 0.5, 0.1), Vector3(size.x + 1.2, foot, 0.5))
	paint_body(kit, 0.0, 0.2, Mat.GLASS)
	kit.box(b["body"], Vector3(0, foot + size.y * 0.5, -0.1), Vector3(size.x, size.y, 0.08))
	paint_light(kit, 0.0, 1.0, Slot.STRIP, 1.8)
	for edge in [[Vector3(0, foot + size.y + 0.03, -0.14), Vector3(size.x + 0.1, 0.04, 0.03)], [Vector3(0, foot - 0.03, -0.14), Vector3(size.x + 0.1, 0.04, 0.03)]]:
		kit.box(b["light"], edge[0], edge[1])
	for sx in [-1.0, 1.0]:
		kit.box(b["light"], Vector3(sx * (size.x * 0.5 + 0.03), foot + size.y * 0.5, -0.14), Vector3(0.04, size.y + 0.1, 0.03))
	paint_light(kit, 0.4, 1.0, Slot.BEACON, 3.0)
	kit.box(b["light"], Vector3(0, foot + size.y + 0.72, -0.2), Vector3(0.34, 0.2, 0.2))
	# The lines: a pixel sized so the longest fits with a margin, from the top down, each read as the storefront's are.
	var rows := lines.split("|", false)
	var longest := 1
	for line in rows:
		longest = maxi(longest, SignFont.width(line.strip_edges().to_upper()))
	var px := minf(0.19, (size.x - 1.4) / float(longest))
	var left := size.x * 0.5 - 0.7
	for i in rows.size():
		var line: String = rows[i].strip_edges().to_upper()
		var y := foot + size.y - 0.9 - float(i) * SignFont.LINE * px * 1.35
		var x := left
		var k := 0
		while k < line.length():
			if line[k] == "#":
				var run := 0
				while k + run < line.length() and line[k + run] == "#":
					run += 1
				var bw := float(run * SignFont.ADVANCE - 1) * px
				kit.paint = Color(1, 1, 1, 1)
				kit.box(b["mark"], Vector3(x - bw * 0.5, y, -0.16), Vector3(bw, SignFont.ROWS * px, 0.03))
				x -= float(run * SignFont.ADVANCE) * px
				k += run
				continue
			var ch: String = line[k]
			if ch != " ":
				_letters(kit, b, ch, Vector3(x - SignFont.COLS * 0.5 * px, y, -0.15), px, Slot.SCREEN, 2.6, -1)
			x -= float(SignFont.ADVANCE) * px
			k += 1
	return kit.pose * Vector3(0, foot + 1.8, -2.4)


## The storefront (M2): a closed terminal as a dead shop, `s` the plan's shop (scripts/ruins/ruins_layout.gd), built into
## `kit`'s buckets `b` (its body and its light: the world gives its light a material of its own, on a timer), its name
## `sign` over the door and its window's last screen `screen` (lines, "|" between two). Returns where its light falls
## (in front of its door, at a lamp's height), the district's space.
static func storefront(kit: ShapeKit, b: Dictionary, s: Dictionary, sign: String, screen: String, rng: RandomNumberGenerator) -> Vector3:
	var w: float = s["width"]
	var depth := RuinsLayout.CELL_M - RuinsLayout.BLOCK_INSET * 2.0
	var tall := rng.randf_range(6.6, 7.4)
	var back := 0.36
	# Its own frame: -z is the street, +z into the shop; read from the street, +x is on the reader's left.
	kit.pose = Transform3D(Basis.looking_at(s["out"], Vector3.UP), s["face"])
	var door_x := -w * RuinsLayout.SHOP_DOOR
	var window_x := w * 0.24
	var window_w := w * 0.4
	# The mass over it, set back from the shopfront; a cornice; a dead box and a bent mast on the roof.
	paint_body(kit, rng.randf_range(0.25, 0.5), 0.75, Mat.STONE)
	kit.box(b["body"], Vector3(0, tall * 0.5, back + (depth - back) * 0.5), Vector3(w, tall, depth - back))
	paint_body(kit, 0.3, 0.95, Mat.METAL)
	kit.box(b["body"], Vector3(0, tall + 0.16, depth * 0.5 - 0.12), Vector3(w + 0.36, 0.32, depth + 0.3))
	kit.box(b["body"], Vector3(w * 0.22, tall + 0.75, depth * 0.55), Vector3(1.6, 0.9, 1.2), Vector3(0, rng.randf_range(-0.2, 0.2), 0))
	kit.prism(b["body"], Vector3(-w * 0.3, tall + 1.6, depth * 0.4), 0.05, 2.6, 6, Vector3(0, 0, rng.randf_range(0.1, 0.25)))
	# The shopfront: two pillars, the fascia across the top, a riser under the window.
	paint_body(kit, rng.randf_range(0.2, 0.45), 1.0, Mat.METAL)
	for side in [-1.0, 1.0]:
		kit.box(b["body"], Vector3(side * (w * 0.5 - 0.26), 1.95, 0.17), Vector3(0.52, 3.9, 0.36))
	kit.box(b["body"], Vector3(0, 4.3, 0.12), Vector3(w, 0.96, 0.26))
	kit.box(b["body"], Vector3(window_x, 0.32, 0.2), Vector3(window_w + 0.3, 0.64, 0.32))
	# The window: a pane of dark glass in a frame.
	paint_body(kit, 0.1, 0.9, Mat.GLASS)
	kit.box(b["body"], Vector3(window_x, 1.75, 0.3), Vector3(window_w, 2.2, 0.05))
	paint_body(kit, 0.35, 1.0, Mat.METAL)
	for side in [-1.0, 1.0]:
		kit.box(b["body"], Vector3(window_x + side * (window_w * 0.5 + 0.05), 1.75, 0.27), Vector3(0.1, 2.3, 0.12))
	kit.box(b["body"], Vector3(window_x, 2.9, 0.27), Vector3(window_w + 0.2, 0.1, 0.12))
	# The door: a lintel, the dark inside, the roller shutter half down (a slat or two knocked askew).
	kit.box(b["body"], Vector3(door_x, 2.95, 0.18), Vector3(2.0, 0.3, 0.3))
	paint_body(kit, 0.6, 0.2, Mat.STONE)
	kit.box(b["body"], Vector3(door_x, 1.4, 0.75), Vector3(1.8, 2.8, 0.1))
	paint_body(kit, rng.randf_range(0.3, 0.6), 0.85, Mat.METAL)
	var slats := 13
	for k in slats:
		var y := 2.72 - k * 0.115
		var skew := Vector3(0, 0, rng.randf_range(-0.05, 0.05)) if rng.randf() < 0.2 else Vector3.ZERO
		kit.box(b["body"], Vector3(door_x, y, 0.26), Vector3(1.78, 0.1, 0.05), skew)
	kit.box(b["body"], Vector3(door_x, 2.72 - slats * 0.115, 0.24), Vector3(1.82, 0.08, 0.1))
	# The awning, torn: most of it on its brackets, sloping out over the street, a flap hanging lower.
	paint_body(kit, rng.randf_range(0.4, 0.7), 0.6, Mat.CABLE)
	kit.box(b["body"], Vector3(w * 0.12, 3.55, -0.62), Vector3(w * 0.7, 0.05, 1.45), Vector3(-0.32, 0, 0))
	kit.box(b["body"], Vector3(-w * 0.34, 3.35, -0.55), Vector3(w * 0.2, 0.05, 1.2), Vector3(-0.75, 0, 0.12))
	for x in [-w * 0.4, w * 0.45]:
		kit.box(b["body"], Vector3(x, 3.75, -0.5), Vector3(0.06, 0.06, 1.1), Vector3(-0.32, 0, 0))
	# Its light: its name along the fascia in a tube, the frozen screen, the OPEN sign, the leak under the shutter, a few
	# dead windows up its front.
	var name_px := minf(0.19, (w - 1.0) / maxf(float(SignFont.width(sign.to_upper())), 1.0))
	_letters(kit, b, sign.to_upper(), Vector3(0, 4.32, -0.03), name_px, Slot.SIGN_A, 2.8, rng.randi_range(0, sign.length() - 1))
	paint_light(kit, rng.randf(), 1.0, Slot.SIGN_A, 2.0)
	for y in [3.86, 4.78]:
		kit.box(b["light"], Vector3(0, y, -0.02), Vector3(w - 0.3, 0.04, 0.04))
	var lines := screen.split("|")
	var screen_px := minf(0.034, (window_w - 0.4) / float(SignFont.width("M".repeat(10))))
	for i in lines.size():
		var line: String = lines[i].strip_edges().to_upper()
		var lx := window_x + window_w * 0.5 - 0.2 - SignFont.width(line) * screen_px * 0.5
		_letters(kit, b, line, Vector3(lx, 2.6 - i * SignFont.LINE * screen_px, 0.26), screen_px, Slot.SCREEN, 1.6, -1)
	var open_px := 0.05
	var open_at := Vector3(window_x - window_w * 0.5 + 0.18 + SignFont.width("OPEN") * open_px * 0.5, 0.98, 0.22)
	_letters(kit, b, "OPEN", open_at, open_px, Slot.SIGN_B, 3.0, -1)
	paint_light(kit, 0.4, 1.0, Slot.SIGN_B, 2.4)
	var ow := SignFont.width("OPEN") * open_px + 0.16
	var oh := SignFont.ROWS * open_px + 0.16
	for edge in [[Vector3(0, oh * 0.5, 0), Vector3(ow, 0.03, 0.03)], [Vector3(0, -oh * 0.5, 0), Vector3(ow, 0.03, 0.03)], [Vector3(ow * 0.5, 0, 0), Vector3(0.03, oh, 0.03)], [Vector3(-ow * 0.5, 0, 0), Vector3(0.03, oh, 0.03)]]:
		kit.box(b["light"], open_at + edge[0], edge[1])
	paint_light(kit, 0.7, 1.0, Slot.SIGN_B, 2.6)
	light_quad(kit, b["light"], Vector3(door_x, 0.62, 0.68), Vector2(1.7, 1.2), Vector3.FORWARD)
	paint_light(kit, 0.7, 1.0, Slot.SIGN_B, 0.9)
	light_quad(kit, b["light"], Vector3(door_x, 0.03, -0.9), Vector2(1.9, 1.7), Vector3.UP)
	for k in rng.randi_range(4, 7):
		var at := Vector3(rng.randf_range(-w * 0.42, w * 0.42), rng.randf_range(5.2, tall - 0.6), back - 0.01)
		paint_light(kit, rng.randf(), rng.randf_range(0.15, 0.6), Slot.SCREEN if rng.randf() < 0.5 else Slot.STRIP, 0.8)
		light_quad(kit, b["light"], at, Vector2(rng.randf_range(0.5, 0.9), rng.randf_range(0.35, 0.6)), Vector3.FORWARD)
	return kit.pose * Vector3(door_x, 2.4, -1.6)


## `text` in the sign font, steady (M2's storefront: every letter lit but `dim`, which gutters), its middle at `at` on a
## face looking down -z in the kit's pose, `px` a pixel; the reader's left is +x, so the letters run toward -x.
static func _letters(kit: ShapeKit, b: Dictionary, text: String, at: Vector3, px: float, slot: int, energy: float, dim: int) -> void:
	var tw := SignFont.width(text) * px
	for run in SignFont.runs(text):
		var i: int = int(run[0]) / SignFont.ADVANCE
		paint_light(kit, 0.03 * i, 0.35 if i == dim else 1.0, slot, energy)
		var x: float = -(-tw * 0.5 + (float(run[0]) + float(run[2]) * 0.5) * px)
		var y: float = (SignFont.ROWS * 0.5 - float(run[1]) - 0.5) * px
		kit.box(b["light"], at + Vector3(x, y, 0), Vector3(float(run[2]) * px, px * 0.9, 0.025))
