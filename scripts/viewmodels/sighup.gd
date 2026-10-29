extends Viewmodel
## SIGHUP's model (weapon 13, carrier green, C32): the line you hang up. An old telephone handset cut in
## hard geometry and held in the fist: an eight-sided handle along the aim, bending down at both ends into
## the cups (the earpiece forward, the mouthpiece back by the hand), each cup's face a grille of slots; the
## coiled cord springing down out of the mouthpiece. Off the earpiece the carrier, three rings of green
## light along the aim, each breathing at its own rate so they ripple; along the handle's spine a carrier
## light for each charge (the player sets them: both lit full, one while the spent one comes back) and a
## hook switch between them. With no charge left the carrier rings go dark: the line is dead.

## The rings' breath, and their depth.
const RING_HZ := 1.6
const RING_DEPTH := 0.6
## The handle's half-length (the cups' middles), its radius, and the cups' depth and radii.
const HALF_M := 0.105
const HANDLE_R := 0.019
const CUP_DEEP := 0.034
const CUP_TOP_R := 0.024
const CUP_FACE_R := 0.036
## The model's charge lights: one per charge of the loadout's magazine (2).
const CELLS := 2
## Turns of the coiled cord and how far it springs.
const COILS := 7

var _rings: Array[int] = []


func _build() -> void:
	plate_hex = true
	# Held tipped up a little, so the earpiece and its carrier lead the eye.
	pose = Transform3D(Basis(Vector3.RIGHT, deg_to_rad(6.0)), Vector3.ZERO)
	# The handle: an eight-sided bar along the aim, a dark spine plate on top, and the bends down to the cups.
	prism(Part.BODY, Vector3.ZERO, HANDLE_R, HALF_M * 1.3, 8, Vector3.ZERO, -1.0, 22.5)
	box(Part.PLATE, Vector3(0.0, HANDLE_R * 0.95, 0.0), Vector3(HANDLE_R * 1.1, 0.006, HALF_M * 1.1))
	for end in [-1.0, 1.0]:
		var z: float = end * HALF_M * 0.78
		prism(Part.BODY, Vector3(0.0, -0.012, z), HANDLE_R * 0.98, 0.046, 8, Vector3(28.0 * end, 0.0, 0.0), HANDLE_R * 1.1, 22.5)
		# The cup: an eight-sided frustum opening downward (its wide face down), a lip and its grille.
		var cup := Vector3(0.0, -0.034, end * HALF_M)
		prism(Part.PLATE, cup, CUP_FACE_R, CUP_DEEP, 8, Vector3(90.0, 0.0, 0.0), CUP_TOP_R, 22.5)
		tube(Part.TRIM, cup + Vector3(0.0, -CUP_DEEP * 0.5 - 0.001, 0.0), CUP_FACE_R * 0.86, CUP_FACE_R * 1.02, 0.003, 8, Vector3(90.0, 0.0, 0.0), 22.5)
		prism(Part.DARK, cup + Vector3(0.0, -CUP_DEEP * 0.5 - 0.002, 0.0), CUP_FACE_R * 0.82, 0.003, 8, Vector3(90.0, 0.0, 0.0), -1.0, 22.5)
		for i in 4:
			box(Part.HOT, cup + Vector3(-0.018 + 0.012 * i, -CUP_DEEP * 0.5 - 0.0035, 0.0), Vector3(0.004, 0.002, CUP_FACE_R * 1.1))
	# Ridges down both flanks of the handle, where the fingers close round it.
	for x in [-1.0, 1.0]:
		for i in 4:
			box(Part.DARK, Vector3(HANDLE_R * 0.92 * x, -0.004, 0.045 - 0.026 * i), Vector3(0.004, 0.016, 0.01))
		box(Part.TRIM, Vector3(HANDLE_R * 1.02 * x, 0.006, 0.0), Vector3(0.002, 0.003, HALF_M * 1.15))
	# The charge lights on the spine, a hook switch between them.
	for i in CELLS:
		var cell := charge_piece(Part.TRIM, i)
		prism(cell, Vector3(0.0, HANDLE_R * 0.95 + 0.0055, -0.03 + 0.06 * i), 0.0065, 0.004, 6, Vector3(90.0, 0.0, 0.0))
		tube(Part.PLATE, Vector3(0.0, HANDLE_R * 0.95 + 0.004, -0.03 + 0.06 * i), 0.0068, 0.0095, 0.004, 6, Vector3(90.0, 0.0, 0.0))
	box(Part.DARK, Vector3(0.0, HANDLE_R * 0.95 + 0.006, 0.0), Vector3(0.008, 0.006, 0.014))
	box(Part.HOT, Vector3(0.0, HANDLE_R * 0.95 + 0.0095, 0.0), Vector3(0.005, 0.0015, 0.01))
	# The coiled cord, springing down and back out of the mouthpiece.
	var from := Vector3(0.0, -0.034 - CUP_DEEP * 0.5, HALF_M + 0.004)
	for i in COILS:
		var u := float(i) / float(COILS - 1)
		var at := from + Vector3(0.006 * sin(u * 9.0), -0.012 - 0.018 * i, 0.012 * i + 0.01 * u * u)
		tube(Part.DARK, at, 0.006, 0.0095, 0.006, 6, Vector3(90.0 - 18.0 * u, 0.0, 0.0))
	# The carrier: three rings of light breathing out off the earpiece, along the aim.
	for k in 3:
		var ring := piece(Part.HOT, Vector3(0.0, -0.01, -HALF_M - 0.05))
		var r := 0.018 + 0.012 * k
		tube(ring, Vector3(0.0, -0.012, -HALF_M - 0.035 - 0.022 * k), r, r + 0.0032, 0.002, 18)
		pulse(ring, RING_HZ * (1.0 + 0.18 * k), RING_DEPTH)
		_rings.append(ring)
	muzzle.position = Vector3(0.0, -0.012, -HALF_M - 0.08)  # the outer carrier ring, the model's front


## The carrier rings' glow now (C32's checks): dark with no charge left.
func ring_glow() -> float:
	return piece_energy(_rings[0])


func _refresh() -> void:
	super()
	if _rings.is_empty():
		return
	# No charge left: the line is dead, the carrier rings dark.
	if charge() <= 0.0:
		for ring in _rings:
			var mat := _pieces[ring - PARTS]["material"] as StandardMaterial3D
			if mat != null:
				mat.emission_energy_multiplier = 0.0
