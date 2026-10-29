extends Viewmodel
## ping's model (weapon 9, lime, C28): a sonar emitter. A short body flares into a dish facing
## forward, its transducer a lit spike at the dish's centre, three lit rings round it on the dish's
## face; on top a round scope with a sweep going round. The rings are its charge pieces, lit in
## order from the inside out as the cooldown comes back (the player sets it): all three lit, it is
## ready; a ping puts them out.

## Turns a second of the scope's sweep.
const SWEEP_TURNS := 0.75


func _build() -> void:
	# Body, its trims, grip and guard.
	box(Part.BODY, Vector3(0.0, 0.0, 0.04), Vector3(0.08, 0.07, 0.17))
	for x in [-1.0, 1.0]:
		box(Part.TRIM, Vector3(0.0405 * x, 0.014, 0.04), Vector3(0.002, 0.005, 0.15))
		box(Part.PLATE, Vector3(0.036 * x, -0.02, -0.03), Vector3(0.012, 0.024, 0.05))
	box(Part.DARK, Vector3(0.0, -0.08, 0.09), Vector3(0.042, 0.1, 0.046), Vector3(-15.0, 0.0, 0.0))
	box(Part.DARK, Vector3(0.0, -0.047, 0.04), Vector3(0.014, 0.01, 0.06))
	# The neck and the dish flaring forward, its rim lit.
	prism(Part.PLATE, Vector3(0.0, 0.0, -0.06), 0.03, 0.03, 12, Vector3.ZERO, 0.026)
	prism(Part.BODY, Vector3(0.0, 0.0, -0.1), 0.028, 0.05, 16, Vector3.ZERO, 0.075)
	tube(Part.TRIM, Vector3(0.0, 0.0, -0.126), 0.07, 0.079, 0.006, 16)
	# The transducer: a lit spike at the dish's centre, the muzzle at its tip.
	prism(Part.PLATE, Vector3(0.0, 0.0, -0.131), 0.014, 0.008, 12)
	prism(Part.HOT, Vector3(0.0, 0.0, -0.148), 0.009, 0.028, 8, Vector3.ZERO, 0.002)
	# The three rings on the dish's face, lit from the inside out as the cooldown comes back.
	var radii := [Vector2(0.018, 0.025), Vector2(0.036, 0.043), Vector2(0.054, 0.062)]
	for i in radii.size():
		var ring := charge_piece(Part.HOT, i)
		tube(ring, Vector3(0.0, 0.0, -0.1265), radii[i].x, radii[i].y, 0.004, 16)
	# The scope on top: a disc, its lit face and rim, and a sweep going round.
	box(Part.PLATE, Vector3(0.0, 0.04, 0.03), Vector3(0.03, 0.012, 0.04))
	prism(Part.PLATE, Vector3(0.0, 0.05, 0.03), 0.032, 0.008, 16, Vector3(90.0, 0.0, 0.0))
	tube(Part.TRIM, Vector3(0.0, 0.0545, 0.03), 0.027, 0.033, 0.003, 16, Vector3(90.0, 0.0, 0.0))
	var face := piece(Part.HOT)
	prism(face, Vector3(0.0, 0.0545, 0.03), 0.004, 0.002, 8, Vector3(90.0, 0.0, 0.0))
	pulse(face, 1.0, 0.4)
	var sweep := piece(Part.HOT, Vector3(0.0, 0.055, 0.03))
	box(sweep, Vector3(0.0, 0.0555, 0.018), Vector3(0.003, 0.002, 0.024))
	spin(sweep, Vector3.UP, -SWEEP_TURNS)
	muzzle.position = Vector3(0.0, 0.0, -0.162)
