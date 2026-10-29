extends Viewmodel
## chmod 000's model (weapon 10, frost opal, C29): a permission-stripping emitter, not a gun. A
## hexagonal receiver in hex-cell frost metal; on top a glass coolant tank whose four cells are its
## charge pieces, lit from the back forward with the coolant left (the player sets it: a full tank all
## four, a venting one dark). Round the barrel three lock tumblers, the r, w and x of a file's
## permissions, each ring notched, turning slowly at rest and spun hard while the beam runs, the rings
## counter-turning as the bits are stripped. At the front three cold prongs close round a crystal lens
## that breathes; on the left flank a plate with "000" in three lit rings. Cold fins along both flanks.

## Turns a second of the tumblers at rest, and the extra while the beam runs at full.
const TUMBLER_REST := 0.15
const TUMBLER_BEAM := 2.6
## How hard the lens breathes.
const LENS_HZ := 1.4
const LENS_DEPTH := 0.35

## How hard the beam runs now, 0 to 1: the player sets it each frame.
var beaming := 0.0

var _tumblers: Array[int] = []


func _build() -> void:
	body_hex = true
	# The receiver, hexagonal, its trims and the back cap.
	prism(Part.BODY, Vector3(0.0, 0.0, 0.0), 0.052, 0.22, 6, Vector3.ZERO, 0.048, 30.0)
	for x in [-1.0, 1.0]:
		box(Part.TRIM, Vector3(0.0455 * x, 0.026, -0.005), Vector3(0.002, 0.004, 0.19))
	tube(Part.PLATE, Vector3(0.0, 0.0, 0.112), 0.03, 0.054, 0.012, 6, Vector3.ZERO, 30.0)
	prism(Part.DARK, Vector3(0.0, 0.0, 0.12), 0.03, 0.008, 6, Vector3.ZERO, -1.0, 30.0)
	# The cold fins along both flanks.
	for x in [-1.0, 1.0]:
		for i in 4:
			box(Part.PLATE, Vector3(0.058 * x, -0.012, 0.06 - 0.032 * i), Vector3(0.012, 0.03, 0.006), Vector3(0.0, 0.0, 18.0 * x))
		box(Part.TRIM, Vector3(0.064 * x, -0.012, 0.012), Vector3(0.002, 0.026, 0.11))
	# The coolant tank on top: a glass cage round four cells that light with the coolant left.
	for z in [0.075, -0.06]:
		box(Part.PLATE, Vector3(0.0, 0.05, z), Vector3(0.026, 0.012, 0.012))
		tube(Part.PLATE, Vector3(0.0, 0.074, z), 0.019, 0.026, 0.01, 10)
	for a in [45.0, 135.0, 225.0, 315.0]:
		var rad := deg_to_rad(a)
		box(Part.DARK, Vector3(cos(rad) * 0.022, 0.074 + sin(rad) * 0.022, 0.0075), Vector3(0.004, 0.004, 0.125))
	for i in 4:
		var cell := charge_piece(Part.HOT, 3 - i)
		prism(cell, Vector3(0.0, 0.074, 0.05 - 0.032 * i), 0.015, 0.026, 8)
	box(Part.TRIM, Vector3(0.0, 0.098, 0.0075), Vector3(0.006, 0.002, 0.13))
	# The barrel and the lock tumblers round it: r, w and x, each notched, each its own piece.
	prism(Part.PLATE, Vector3(0.0, 0.0, -0.165), 0.034, 0.12, 6, Vector3.ZERO, 0.028, 30.0)
	for i in 3:
		var z := -0.135 - 0.03 * i
		var ring := piece(Part.TRIM, Vector3(0.0, 0.0, z))
		tube(ring, Vector3(0.0, 0.0, z), 0.037 - 0.002 * i, 0.047 - 0.002 * i, 0.012, 12)
		for k in 3:
			var at := deg_to_rad(120.0 * k + 40.0 * i)
			var r := 0.049 - 0.002 * i
			box(ring, Vector3(cos(at) * r, sin(at) * r, z), Vector3(0.008, 0.008, 0.014), Vector3(0.0, 0.0, rad_to_deg(at)))
		_tumblers.append(ring)
	# The emitter: three cold prongs closing round a crystal lens.
	tube(Part.PLATE, Vector3(0.0, 0.0, -0.232), 0.022, 0.036, 0.018, 6, Vector3.ZERO, 30.0)
	for k in 3:
		var at := deg_to_rad(90.0 + 120.0 * k)
		var base := Vector3(cos(at) * 0.03, sin(at) * 0.03, -0.25)
		var tip := Vector3(cos(at) * 0.014, sin(at) * 0.014, -0.29)
		var mid := (base + tip) * 0.5
		var tilt := rad_to_deg(atan2(0.016, 0.04))
		box(Part.BODY, mid, Vector3(0.01, 0.01, 0.046), Vector3(-sin(at) * tilt, cos(at) * tilt, 0.0))
		box(Part.TRIM, tip, Vector3(0.006, 0.006, 0.008))
	var lens := piece(Part.HOT)
	prism(lens, Vector3(0.0, 0.0, -0.252), 0.016, 0.022, 6, Vector3.ZERO, 0.004, 30.0)
	prism(lens, Vector3(0.0, 0.0, -0.238), 0.004, 0.006, 6, Vector3.ZERO, 0.016, 30.0)
	pulse(lens, LENS_HZ, LENS_DEPTH)
	# The "000" plate on the left flank, the eye's side: three lit rings.
	box(Part.PLATE, Vector3(-0.05, 0.006, -0.05), Vector3(0.006, 0.026, 0.07))
	for i in 3:
		tube(Part.HOT, Vector3(-0.0535, 0.006, -0.074 + 0.024 * i), 0.0055, 0.0085, 0.002, 10, Vector3(0.0, 90.0, 0.0))
	# The grip and its guard.
	box(Part.DARK, Vector3(0.0, -0.082, 0.07), Vector3(0.042, 0.1, 0.046), Vector3(-14.0, 0.0, 0.0))
	box(Part.DARK, Vector3(0.0, -0.05, 0.02), Vector3(0.014, 0.01, 0.06))
	muzzle.position = Vector3(0.0, 0.0, -0.3)


## The tumblers turn at rest and spin hard with the beam, every other one the other way.
func idle(delta: float) -> void:
	super(delta)
	var turns := TUMBLER_BEAM * clampf(beaming, 0.0, 1.0)
	for i in _tumblers.size():
		var node := _pieces[_tumblers[i] - PARTS]["node"] as Node3D
		node.rotate_object_local(Vector3.BACK, TAU * (TUMBLER_REST + turns) * (1.0 if i % 2 == 0 else -1.0) * delta)


## How far the tumblers have turned, for the checks: the first ring's angle about the barrel.
func tumbler_angle() -> float:
	return (_pieces[_tumblers[0] - PARTS]["node"] as Node3D).rotation.z
