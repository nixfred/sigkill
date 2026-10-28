extends Viewmodel
## SIGTERM's model (weapon 2, violet, A1): the polite shotgun, an over-under pump. A wide receiver,
## two stacked barrels with flared, lit muzzles and a vent rib, a polymer pump ringed in violet,
## a stock stub, and a pair of "please exit" chevrons pointing out the muzzle on its near side.


func _build() -> void:
	# Receiver, top plate, stock stub.
	box(Part.BODY, Vector3(0.0, 0.0, 0.03), Vector3(0.08, 0.09, 0.2))
	box(Part.PLATE, Vector3(0.0, 0.051, 0.03), Vector3(0.06, 0.012, 0.18))
	box(Part.BODY, Vector3(0.0, -0.012, 0.16), Vector3(0.05, 0.075, 0.06))
	# Two barrels, over and under, each with a flared lip and a lit bore.
	for y in [0.026, -0.016]:
		prism(Part.BODY, Vector3(0.0, y, -0.225), 0.019, 0.31, 12)
		prism(Part.PLATE, Vector3(0.0, y, -0.39), 0.019, 0.02, 12, Vector3.ZERO, 0.024)
		tube(Part.TRIM, Vector3(0.0, y, -0.397), 0.016, 0.0245, 0.004, 12)
		prism(Part.HOT, Vector3(0.0, y, -0.4), 0.013, 0.002, 12)
	box(Part.PLATE, Vector3(0.0, 0.048, -0.225), Vector3(0.01, 0.008, 0.3))
	box(Part.BODY, Vector3(0.0, 0.005, -0.33), Vector3(0.02, 0.07, 0.014))
	# The pump, ringed in violet.
	box(Part.DARK, Vector3(0.0, -0.042, -0.17), Vector3(0.062, 0.042, 0.13))
	for z in [-0.125, -0.15, -0.175, -0.2, -0.225]:
		box(Part.TRIM, Vector3(0.0, -0.042, z), Vector3(0.0636, 0.0436, 0.004))
	# Grip and guard.
	box(Part.DARK, Vector3(0.0, -0.088, 0.088), Vector3(0.042, 0.11, 0.048), Vector3(-18.0, 0.0, 0.0))
	box(Part.DARK, Vector3(0.0, -0.055, 0.035), Vector3(0.014, 0.01, 0.06))
	# Neon: a line along each side, and the chevrons.
	for x in [-1.0, 1.0]:
		box(Part.TRIM, Vector3(0.0405 * x, 0.024, 0.03), Vector3(0.002, 0.005, 0.17))
	chevron(Part.TRIM, Vector3(-0.0406, -0.01, 0.085), 0.026)
	chevron(Part.TRIM, Vector3(-0.0406, -0.01, 0.06), 0.026)
	muzzle.position = Vector3(0.0, 0.005, -0.402)
