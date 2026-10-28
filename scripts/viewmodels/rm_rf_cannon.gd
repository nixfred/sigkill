extends Viewmodel
## The rm -rf cannon's model (weapon 7, ember, A1): heavy. A fat octagonal housing ends in a wide
## bore with a thick lip; deep in the bore a core, and along both flanks rows of vent fins, glow up
## through the "are you sure" wind-up. A heavy rear block wears hazard stripes; a carry handle on
## top, a polymer grip below.


func _build() -> void:
	# The housing and its bore.
	prism(Part.BODY, Vector3(0.0, 0.0, -0.07), 0.068, 0.3, 8, Vector3.ZERO, 0.062, 22.5)
	tube(Part.PLATE, Vector3(0.0, 0.0, -0.235), 0.042, 0.075, 0.04, 8, Vector3.ZERO, 22.5)
	tube(Part.TRIM, Vector3(0.0, 0.0, -0.256), 0.042, 0.048, 0.004, 8, Vector3.ZERO, 22.5)
	prism(Part.DARK, Vector3(0.0, 0.0, -0.2), 0.042, 0.03, 8, Vector3.ZERO, -1.0, 22.5)
	# The core and the vents: they glow up with the wind-up.
	prism(charge_piece(Part.HOT, 0), Vector3(0.0, 0.0, -0.217), 0.04, 0.004, 8, Vector3.ZERO, -1.0, 22.5)
	var vents := charge_piece(Part.TRIM, 0)
	for x in [-1.0, 1.0]:
		for i in 5:
			box(vents, Vector3(0.066 * x, 0.0, -0.17 + 0.035 * i), Vector3(0.012, 0.072, 0.012))
	# The rear block and its hazard stripes, the handle, the grip.
	box(Part.PLATE, Vector3(0.0, -0.005, 0.12), Vector3(0.13, 0.13, 0.09))
	for i in 3:
		box(Part.TRIM, Vector3(-0.0655, -0.005, 0.09 + 0.028 * i), Vector3(0.002, 0.11, 0.008), Vector3(-35.0, 0.0, 0.0))
	box(Part.TRIM, Vector3(0.0655, 0.03, 0.12), Vector3(0.002, 0.006, 0.08))
	box(Part.DARK, Vector3(0.0, 0.092, -0.06), Vector3(0.03, 0.018, 0.15))
	for z in [-0.12, 0.0]:
		box(Part.DARK, Vector3(0.0, 0.074, z), Vector3(0.022, 0.03, 0.016))
	box(Part.DARK, Vector3(0.0, -0.11, 0.11), Vector3(0.046, 0.11, 0.05), Vector3(-12.0, 0.0, 0.0))
	muzzle.position = Vector3(0.0, 0.0, -0.262)
