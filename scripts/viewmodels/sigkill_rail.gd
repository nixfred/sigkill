extends Viewmodel
## The SIGKILL rail rifle's model (weapon 3, ice, A1): long and thin. Two rails reach forward past
## a lit core, wrapped in four coils that light one after another as the rail charges, under a
## long scope with a lit lens; a hex power cell sits at the back.


func _build() -> void:
	# Receiver, power cell, grip and guard.
	box(Part.BODY, Vector3(0.0, 0.0, 0.06), Vector3(0.062, 0.08, 0.24))
	prism(Part.PLATE, Vector3(0.0, -0.004, 0.2), 0.036, 0.07, 6, Vector3.ZERO, -1.0, 30.0)
	tube(Part.TRIM, Vector3(0.0, -0.004, 0.17), 0.036, 0.039, 0.006, 6, Vector3.ZERO, 30.0)
	box(Part.DARK, Vector3(0.0, -0.085, 0.11), Vector3(0.04, 0.11, 0.046), Vector3(-15.0, 0.0, 0.0))
	box(Part.DARK, Vector3(0.0, -0.052, 0.06), Vector3(0.014, 0.01, 0.06))
	# The rails, their lit inner edges, and the core between them.
	for x in [-1.0, 1.0]:
		box(Part.PLATE, Vector3(0.024 * x, 0.0, -0.25), Vector3(0.01, 0.036, 0.44))
		box(Part.TRIM, Vector3(0.0185 * x, 0.0, -0.25), Vector3(0.0012, 0.028, 0.42))
		box(Part.TRIM, Vector3(0.0315 * x, 0.016, 0.06), Vector3(0.002, 0.005, 0.2))
	prism(Part.HOT, Vector3(0.0, 0.0, -0.25), 0.0055, 0.42, 6)
	# The coils: they light in order with the charge.
	for i in 4:
		tube(charge_piece(Part.HOT, i), Vector3(0.0, 0.0, -0.13 - 0.085 * i), 0.037, 0.046, 0.018, 12)
	# The scope, its mounts and its lens.
	prism(Part.BODY, Vector3(0.0, 0.074, 0.02), 0.017, 0.2, 12)
	tube(Part.TRIM, Vector3(0.0, 0.074, -0.08), 0.013, 0.019, 0.006, 12)
	prism(Part.HOT, Vector3(0.0, 0.074, -0.082), 0.013, 0.002, 12)
	tube(Part.TRIM, Vector3(0.0, 0.074, 0.118), 0.012, 0.019, 0.004, 12)
	prism(Part.HOT, Vector3(0.0, 0.074, 0.121), 0.012, 0.002, 12)
	for z in [0.07, -0.04]:
		box(Part.DARK, Vector3(0.0, 0.05, z), Vector3(0.012, 0.03, 0.014))
	muzzle.position = Vector3(0.0, 0.0, -0.47)
