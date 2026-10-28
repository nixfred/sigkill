extends Viewmodel
## The terminal cannon's model (weapon 1, teal, A1): a compact blaster carbine. A boxy receiver
## under a top rail with its sights, a square shroud round an eight-sided barrel, a two-fin muzzle
## brake round a lit bore, an energy cell for a magazine, an angled polymer grip, and a ">_" prompt
## cut in teal on the side toward the eye.


func _build() -> void:
	# Receiver, top rail, sights.
	box(Part.BODY, Vector3(0.0, 0.0, 0.02), Vector3(0.07, 0.085, 0.22))
	box(Part.PLATE, Vector3(0.0, 0.051, 0.0), Vector3(0.05, 0.018, 0.26))
	box(Part.DARK, Vector3(0.0, 0.068, 0.09), Vector3(0.034, 0.018, 0.03))
	box(Part.DARK, Vector3(0.0, 0.07, -0.115), Vector3(0.008, 0.022, 0.012))
	# Shroud, barrel, brake and its lit bore.
	box(Part.PLATE, Vector3(0.0, 0.008, -0.15), Vector3(0.058, 0.056, 0.12))
	prism(Part.BODY, Vector3(0.0, 0.008, -0.255), 0.02, 0.1, 8, Vector3.ZERO, -1.0, 22.5)
	box(Part.BODY, Vector3(0.0, 0.008, -0.315), Vector3(0.066, 0.036, 0.028))
	box(Part.DARK, Vector3(0.0, 0.008, -0.315), Vector3(0.068, 0.008, 0.014))
	tube(Part.TRIM, Vector3(0.0, 0.008, -0.298), 0.02, 0.026, 0.006, 8, Vector3.ZERO, 22.5)
	prism(Part.HOT, Vector3(0.0, 0.008, -0.33), 0.011, 0.003, 8, Vector3.ZERO, -1.0, 22.5)
	# Energy cell, trigger guard, grip.
	box(Part.BODY, Vector3(0.0, -0.07, -0.04), Vector3(0.036, 0.07, 0.04), Vector3(-8.0, 0.0, 0.0))
	box(Part.TRIM, Vector3(0.0, -0.073, -0.0605), Vector3(0.024, 0.05, 0.003), Vector3(-8.0, 0.0, 0.0))
	box(Part.DARK, Vector3(0.0, -0.052, 0.02), Vector3(0.014, 0.01, 0.06))
	box(Part.DARK, Vector3(0.0, -0.085, 0.078), Vector3(0.04, 0.11, 0.045), Vector3(-16.0, 0.0, 0.0))
	# Neon: lines along the receiver and the shroud, and the prompt.
	for x in [-1.0, 1.0]:
		box(Part.TRIM, Vector3(0.0355 * x, 0.022, 0.02), Vector3(0.002, 0.005, 0.2))
		box(Part.TRIM, Vector3(0.0295 * x, 0.03, -0.15), Vector3(0.002, 0.004, 0.11))
	chevron(Part.TRIM, Vector3(-0.0356, -0.012, 0.02), 0.026, 1.0)
	box(Part.TRIM, Vector3(-0.0356, -0.023, 0.05), Vector3(0.002, 0.004, 0.018))
	muzzle.position = Vector3(0.0, 0.008, -0.334)
