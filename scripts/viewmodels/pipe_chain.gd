extends Viewmodel
## pipe |'s model (weapon 11, brass, C30): a length of pipe made into a weapon, plumbing and shell at once.
## A round main pipe in gunmetal between two bolted flanges, brass conduits running along its top; on the
## left flank (the eye's side) the buffer gauge, eight "|" bars in a glass rail that light from the inlet
## forward as chains fill the buffer (the player sets it: empty all at rest, full and blocked all lit), two
## arrows beside it pointing down the pipe, the way the data flows. At the front a tee: its two side outlets
## end in glowing brass rings (the stream fans out), a valve wheel on top, and its forward outlet carries the
## emitter: two prong plates and between them a lit "|" filament, the pipe itself, breathing. Three
## segmented couplings round the main pipe and the valve wheel turn slowly at rest and spin hard with each
## chain, the stream rushing through. The grip and its guard under it.

## Turns a second of the couplings and the valve at rest, and the extra just after a chain at full.
const COUPLING_REST := 0.12
const COUPLING_RUSH := 3.2
## How fast a chain's rush dies away, a second.
const RUSH_DECAY := 4.0
## How hard the filament breathes.
const FILAMENT_HZ := 2.6
const FILAMENT_DEPTH := 0.4
## The buffer gauge's bars.
const BARS := 8

## How hard the stream rushes through now, 0 to 1: the player sets it to 1 at each chain; it dies away.
var streaming := 0.0

var _couplings: Array[int] = []
var _valve := -1
var _filament := -1


func _build() -> void:
	# The main pipe, its flanges, their bolts and the back cap.
	prism(Part.BODY, Vector3(0.0, 0.0, 0.0), 0.04, 0.24, 10)
	for z in [0.125, -0.125]:
		tube(Part.PLATE, Vector3(0.0, 0.0, z), 0.03, 0.056, 0.014, 10)
		for k in 6:
			var at := deg_to_rad(30.0 + 60.0 * k)
			box(Part.PLATE, Vector3(cos(at) * 0.048, sin(at) * 0.048, z + 0.009 * signf(z)), Vector3(0.008, 0.008, 0.006))
	prism(Part.DARK, Vector3(0.0, 0.0, 0.135), 0.03, 0.006, 10)
	box(Part.TRIM, Vector3(0.0, 0.0, 0.139), Vector3(0.03, 0.003, 0.002))
	# Brass conduits along the top, the stream's own lines.
	for x in [-1.0, 1.0]:
		prism(Part.TRIM, Vector3(0.016 * x, 0.044, 0.0), 0.004, 0.23, 6)
		for z in [0.08, -0.08]:
			box(Part.PLATE, Vector3(0.016 * x, 0.041, z), Vector3(0.012, 0.006, 0.01))
	# The buffer gauge on the left flank: a glass rail of eight "|" bars, the inlet's first.
	box(Part.PLATE, Vector3(-0.044, 0.008, 0.0), Vector3(0.006, 0.032, 0.21))
	box(Part.TRIM, Vector3(-0.047, 0.026, 0.0), Vector3(0.002, 0.002, 0.2))
	box(Part.TRIM, Vector3(-0.047, -0.01, 0.0), Vector3(0.002, 0.002, 0.2))
	for i in BARS:
		var bar := charge_piece(Part.HOT, i)
		box(bar, Vector3(-0.048, 0.008, 0.084 - 0.024 * i), Vector3(0.004, 0.024, 0.006))
	# The arrows down the pipe beside it: the way the data flows.
	for z in [-0.11, -0.09]:
		chevron(Part.TRIM, Vector3(-0.0415, -0.024, z), 0.014, -1.0)
	# The couplings: segmented rings round the pipe, each its own piece.
	for i in 3:
		var z := 0.075 - 0.075 * i
		var ring := piece(Part.TRIM, Vector3(0.0, 0.0, z))
		tube(ring, Vector3(0.0, 0.0, z), 0.041, 0.048, 0.01, 12)
		for k in 4:
			var at := deg_to_rad(45.0 + 90.0 * k + 22.5 * i)
			box(ring, Vector3(cos(at) * 0.05, sin(at) * 0.05, z), Vector3(0.007, 0.007, 0.014), Vector3(0.0, 0.0, rad_to_deg(at)))
		_couplings.append(ring)
	# The tee: a crossbar of pipe, its side outlets ending in glowing brass rings, a valve wheel on top.
	prism(Part.BODY, Vector3(0.0, 0.0, -0.165), 0.036, 0.13, 10, Vector3(0.0, 90.0, 0.0))
	for x in [-1.0, 1.0]:
		tube(Part.PLATE, Vector3(0.06 * x, 0.0, -0.165), 0.028, 0.044, 0.01, 10, Vector3(0.0, 90.0, 0.0))
		tube(Part.HOT, Vector3(0.068 * x, 0.0, -0.165), 0.016, 0.026, 0.004, 10, Vector3(0.0, 90.0, 0.0))
	box(Part.PLATE, Vector3(0.0, 0.048, -0.165), Vector3(0.008, 0.024, 0.008))
	_valve = piece(Part.TRIM, Vector3(0.0, 0.062, -0.165))
	tube(_valve, Vector3(0.0, 0.062, -0.165), 0.016, 0.022, 0.004, 12, Vector3(90.0, 0.0, 0.0))
	for k in 3:
		box(_valve, Vector3(0.0, 0.062, -0.165), Vector3(0.034, 0.003, 0.003), Vector3(0.0, 60.0 * k, 0.0))
	# The forward outlet and the emitter: two prong plates, the "|" filament lit between them.
	prism(Part.PLATE, Vector3(0.0, 0.0, -0.215), 0.03, 0.05, 10)
	tube(Part.PLATE, Vector3(0.0, 0.0, -0.243), 0.02, 0.04, 0.012, 10)
	for y in [-1.0, 1.0]:
		box(Part.BODY, Vector3(0.0, 0.034 * y, -0.278), Vector3(0.034, 0.008, 0.062))
		box(Part.TRIM, Vector3(0.0, 0.0295 * y, -0.278), Vector3(0.026, 0.002, 0.056))
	_filament = piece(Part.HOT)
	box(_filament, Vector3(0.0, 0.0, -0.29), Vector3(0.009, 0.054, 0.009))
	box(_filament, Vector3(0.0, 0.0, -0.29), Vector3(0.016, 0.006, 0.006))
	pulse(_filament, FILAMENT_HZ, FILAMENT_DEPTH)
	# The rail under the pipe, the grip and its guard.
	box(Part.PLATE, Vector3(0.0, -0.046, -0.03), Vector3(0.03, 0.012, 0.14))
	box(Part.DARK, Vector3(0.0, -0.085, 0.07), Vector3(0.04, 0.1, 0.045), Vector3(-14.0, 0.0, 0.0))
	box(Part.DARK, Vector3(0.0, -0.05, 0.02), Vector3(0.014, 0.01, 0.06))
	muzzle.position = Vector3(0.0, 0.0, -0.31)


## The couplings and the valve turn at rest and spin hard just after a chain, every other coupling the
## other way; the rush dies away on its own.
func idle(delta: float) -> void:
	super(delta)
	streaming = maxf(streaming - delta * RUSH_DECAY, 0.0)
	var turns := COUPLING_REST + COUPLING_RUSH * streaming
	for i in _couplings.size():
		var node := _pieces[_couplings[i] - PARTS]["node"] as Node3D
		node.rotate_object_local(Vector3.BACK, TAU * turns * (1.0 if i % 2 == 0 else -1.0) * delta)
	if _valve >= 0:
		(_pieces[_valve - PARTS]["node"] as Node3D).rotate_object_local(Vector3.UP, TAU * turns * 0.5 * delta)


## How far the first coupling has turned, for the checks: its angle about the pipe.
func coupling_angle() -> float:
	return (_pieces[_couplings[0] - PARTS]["node"] as Node3D).rotation.z
