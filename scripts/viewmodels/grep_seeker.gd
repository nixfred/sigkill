extends Viewmodel
## The grep seeker's model (weapon 6, cobalt, A1): a smart gun. A fat scope sits high with lit
## lenses at both ends, the one toward the eye a cobalt glow breathing while held, over a tapered
## hex nose and a short barrel; a pod of three dart tubes rides its left side, their darts' tips
## lit, with a sensor fin up front.


func _build() -> void:
	# Receiver, nose, barrel and its lit bore.
	box(Part.BODY, Vector3(0.0, 0.0, 0.03), Vector3(0.068, 0.08, 0.2))
	prism(Part.PLATE, Vector3(0.0, -0.004, -0.11), 0.042, 0.08, 6, Vector3.ZERO, 0.03, 30.0)
	prism(Part.BODY, Vector3(0.0, -0.004, -0.2), 0.013, 0.1, 6, Vector3.ZERO, -1.0, 30.0)
	tube(Part.TRIM, Vector3(0.0, -0.004, -0.245), 0.013, 0.018, 0.006, 6, Vector3.ZERO, 30.0)
	prism(Part.HOT, Vector3(0.0, -0.004, -0.2505), 0.008, 0.002, 6, Vector3.ZERO, -1.0, 30.0)
	# The scope: a fat tube, its bell, a lens that breathes, rings and mounts.
	prism(Part.BODY, Vector3(0.0, 0.08, 0.0), 0.03, 0.15, 16)
	tube(Part.PLATE, Vector3(0.0, 0.08, -0.068), 0.03, 0.037, 0.022, 16)
	prism(Part.HOT, Vector3(0.0, 0.08, -0.077), 0.029, 0.004, 16)
	tube(Part.TRIM, Vector3(0.0, 0.08, -0.08), 0.029, 0.038, 0.003, 16)
	tube(Part.TRIM, Vector3(0.0, 0.08, 0.072), 0.022, 0.031, 0.004, 16)
	var lens := piece(Part.TRIM)
	prism(lens, Vector3(0.0, 0.08, 0.0755), 0.022, 0.002, 16)
	pulse(lens, 0.8, 0.35)
	for z in [0.05, -0.03]:
		box(Part.DARK, Vector3(0.0, 0.046, z), Vector3(0.014, 0.022, 0.016))
	# The dart pod on the left: three tubes, their darts' tips lit.
	box(Part.BODY, Vector3(-0.04, -0.002, -0.03), Vector3(0.012, 0.064, 0.1))
	for i in 3:
		var y := -0.022 + 0.02 * i
		prism(Part.PLATE, Vector3(-0.0505, y, -0.03), 0.0095, 0.13, 8)
		prism(Part.HOT, Vector3(-0.0505, y, -0.098), 0.005, 0.008, 6, Vector3.ZERO, 0.001)
	# Sensor fin, grip, guard, neon line.
	box(Part.PLATE, Vector3(0.0, 0.038, -0.125), Vector3(0.004, 0.03, 0.06), Vector3(-20.0, 0.0, 0.0))
	box(Part.DARK, Vector3(0.0, -0.084, 0.085), Vector3(0.04, 0.11, 0.046), Vector3(-15.0, 0.0, 0.0))
	box(Part.DARK, Vector3(0.0, -0.052, 0.035), Vector3(0.014, 0.01, 0.06))
	box(Part.TRIM, Vector3(0.0345, 0.016, 0.03), Vector3(0.002, 0.005, 0.18))
	box(Part.TRIM, Vector3(-0.0345, 0.03, 0.03), Vector3(0.002, 0.005, 0.18))
	muzzle.position = Vector3(0.0, -0.004, -0.253)
