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


static func paint_floor(kit: ShapeKit, damage: float, rims: int) -> void:
	kit.paint = Color(clampf(damage, 0.0, 1.0), float(rims) / 15.0, 0.0, 1.0)


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
	var mh := clampf(w * 0.92, 1.9, 3.6) * rng.randf_range(0.9, 1.12)
	var health_base := rng.randf_range(0.6, 1.0)
	var from := maxf(foot, -DETAIL_DEPTH)
	if from > foot + 0.5:
		kit.pose = base
		paint_body(kit, 0.95, 0.35)
		kit.box(b["body"], Vector3(0, (foot + from) * 0.5, 0), Vector3(w * 0.94, from - foot, d * 0.94))
		for k in int((from - foot) / 9.0):
			paint_light(kit, rng.randf(), _health(rng, health_base * 0.7), Slot.LED, 2.0)
			light_quad(kit, b["light"], Vector3(rng.randf_range(-w, w) * 0.35, from - 4.0 - k * 9.0, -d * 0.47 - 0.01), Vector2(0.12, 0.06), Vector3.FORWARD)
	var broken := top > 6.0 and rng.randf() < 0.45
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
		if rng.randf() < (0.07 if y < top * 0.6 else 0.2):
			slip += Vector3(rng.randf_range(-0.24, 0.24), 0, rng.randf_range(-0.14, 0.14))
		var turn := Basis.from_euler(Vector3(deg_to_rad(rng.randf_range(-1.2, 1.2)), deg_to_rad(rng.randf_range(-2.5, 2.5)), deg_to_rad(rng.randf_range(-1.2, 1.2))))
		kit.pose = base * Transform3D(turn, Vector3(slip.x, y, slip.z))
		var damage := rng.randf()
		_rack_module(kit, b, w, d, h, rng, health_base, both, last and broken, damage)
		if not neon.is_empty():
			var lo := maxf(y, neon[1])
			var hi := minf(y + h, neon[2])
			if hi > lo + 0.1:
				paint_light(kit, neon[4], 1.0, neon[3], 2.4)
				kit.box(b["light"], Vector3(neon[0] * (w * 0.5 + 0.03), (lo + hi) * 0.5 - y, -d * 0.5 - 0.03), Vector3(0.09, hi - lo, 0.06))
		if damage > 0.82 and spill_left > 0 and y > -4.0:
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
static func _rack_module(kit: ShapeKit, b: Dictionary, w: float, d: float, h: float, rng: RandomNumberGenerator, health_base: float, both: bool, jagged: bool, damage: float) -> void:
	var grime := rng.randf_range(0.1, 0.6)
	paint_body(kit, grime, 1.0)
	for sx in [-1.0, 1.0]:
		for sz in [-1.0, 1.0]:
			var ph := h if not jagged else h * rng.randf_range(0.2, 1.0)
			kit.box(b["body"], Vector3(sx * (w * 0.5 - 0.07), ph * 0.5, sz * (d * 0.5 - 0.07)), Vector3(0.14, ph, 0.14))
	kit.box(b["body"], Vector3(0, 0.05, 0), Vector3(w, 0.1, d))
	paint_body(kit, grime + 0.2, 0.35)
	for sx in [-1.0, 1.0]:
		if rng.randf() < 0.65 - damage * 0.3:
			kit.box(b["body"], Vector3(sx * (w * 0.5 - 0.03), h * 0.5, 0), Vector3(0.05, h - 0.14, d - 0.2))
	if jagged:
		return
	var blades := clampi(int(h / 0.42), 2, 7)
	var pitch := (h - 0.16) / float(blades)
	for i in blades:
		if rng.randf() < 0.1 + damage * 0.28:
			continue
		var out := rng.randf_range(0.12, 0.6) if rng.randf() < 0.1 else 0.0
		var by := 0.12 + pitch * (i + 0.5)
		paint_body(kit, grime, 0.55)
		kit.box(b["body"], Vector3(0, by, -out), Vector3(w - 0.3, pitch * 0.82, d - 0.24))
		var leds := clampi(int((w - 0.5) / 0.22), 2, 14)
		for faces in ([-1.0, 1.0] if both else [-1.0]):
			var fz: float = faces * ((d - 0.24) * 0.5 + (out if faces < 0.0 else 0.0)) + faces * 0.004
			for k in leds:
				if rng.randf() < 0.18:
					continue
				var lx := -(w - 0.6) * 0.5 + (w - 0.6) * (k + 0.5) / leds
				paint_light(kit, rng.randf(), _health(rng, health_base - damage * 0.25), Slot.LED, rng.randf_range(2.2, 4.6))
				light_quad(kit, b["light"], Vector3(lx, by + pitch * rng.randf_range(-0.18, 0.18), fz), Vector2(0.07, 0.035), Vector3(0, 0, faces))
	if rng.randf() < 0.45:
		var sx := -1.0 if rng.randf() < 0.5 else 1.0
		paint_light(kit, rng.randf(), _health(rng, health_base), Slot.STRIP, 1.8)
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
	var health_base := rng.randf_range(0.55, 0.95)
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
					if len > 0.4 and rng.randf() < 0.75:
						var mid := x + len * 0.5
						var at := Vector3(mid, ry, out.z * depth) if face < 2 else Vector3(out.x * depth, ry, mid)
						paint_light(kit, rng.randf(), _health(rng, health_base), Slot.STRIP, rng.randf_range(1.6, 3.4))
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
static func _name_on(kit: ShapeKit, b: Dictionary, text: String, at: Vector3, fit: float, px: float, slot: int, out: Vector3, rng: RandomNumberGenerator) -> void:
	var pw := minf(px, fit / maxf(float(SignFont.width(text)), 1.0))
	var tw := SignFont.width(text) * pw
	var letters := []
	for i in text.length():
		var roll := rng.randf()
		letters.append(0.0 if roll < 0.14 else (rng.randf_range(0.3, 0.7) if roll < 0.32 else 1.0))
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
	var along := Vector3(out.z, 0, -out.x)  # right-handed with up and out: never a mirror, so faces keep their winding
	var line := layout.center(e["cell"]) + out * RuinsLayout.CELL_M * 0.5
	var base := Transform3D(Basis(along, Vector3.UP, out), line)
	var half := RuinsLayout.CELL_M * 0.5 + 0.1
	var t := RuinsLayout.PARAPET_T
	kit.pose = base
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
	kit.pose = Transform3D.IDENTITY
	paint_floor(kit, damage, rims)
	kit.box(b["floor"], layout.center(c) - Vector3(0, RuinsLayout.SLAB_M * 0.5, 0), Vector3(RuinsLayout.CELL_M, RuinsLayout.SLAB_M, RuinsLayout.CELL_M))


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
	var health := 1.0 if rng.randf() < 0.75 else rng.randf_range(0.4, 0.8)
	kit.pose = base
	paint_body(kit, 0.5, 0.5)
	kit.box(b["body"], Vector3.ZERO, Vector3(size.x, size.y, 0.18))
	for sx in [-1.0, 1.0]:
		kit.box(b["body"], Vector3(sx * size.x * 0.35, 0, stand * 0.5), Vector3(0.12, 0.12, stand))
	paint_light(kit, rng.randf(), health, slot, 2.2)
	for edge in [[Vector3(0, size.y * 0.5, -0.1), Vector3(size.x, 0.05, 0.05)], [Vector3(0, -size.y * 0.5, -0.1), Vector3(size.x, 0.05, 0.05)], [Vector3(size.x * 0.5, 0, -0.1), Vector3(0.05, size.y, 0.05)], [Vector3(-size.x * 0.5, 0, -0.1), Vector3(0.05, size.y, 0.05)]]:
		kit.box(b["light"], edge[0], edge[1])
	var dead_letter := rng.randi_range(0, text.length() - 1) if rng.randf() < 0.4 else -1
	# The board looks down -z, read from -z, where +x is on the reader's left: its letters run toward -x.
	var flip := -1.0
	if upright:
		for i in text.length():
			var letter := text[i]
			var y0 := size.y * 0.5 - px - i * SignFont.LINE * px
			var lh := health if i != dead_letter else 0.35
			for run in SignFont.runs(letter):
				paint_light(kit, rng.randf() * 0.05 + i * 0.07, lh, slot, 3.4)
				var x: float = (-SignFont.COLS * 0.5 * px + (float(run[0]) + float(run[2]) * 0.5) * px) * flip
				kit.box(b["light"], Vector3(x, y0 - (float(run[1]) + 0.5) * px, -0.1), Vector3(float(run[2]) * px, px * 0.88, 0.03))
	else:
		var tw := SignFont.width(text) * px
		for run in SignFont.runs(text):
			var i: int = int(run[0]) / SignFont.ADVANCE
			paint_light(kit, rng.randf() * 0.05 + i * 0.07, health if i != dead_letter else 0.35, slot, 3.4)
			var x: float = (-tw * 0.5 + (float(run[0]) + float(run[2]) * 0.5) * px) * flip
			kit.box(b["light"], Vector3(x, (SignFont.ROWS * 0.5 - float(run[1]) - 0.5) * px, -0.1), Vector3(float(run[2]) * px, px * 0.88, 0.03))
	return base * Vector3(0, 0, -2.5)
