extends Viewmodel
## The fork() shotgun's model (weapon 5, yellow, A1): a gun that forks. One trunk barrel leaves the
## receiver, meets a joint marked with a split line, and goes on as two prongs angled apart, each
## with a lit tip and a stripe along it; a shell tube under the trunk, a polymer grip.

## How far each prong turns out from the aim, in degrees.
const PRONG_DEGREES := 13.0
const PRONG_M := 0.2


func _build() -> void:
	# Receiver, top plate, grip and guard.
	box(Part.BODY, Vector3(0.0, 0.0, 0.03), Vector3(0.074, 0.085, 0.2))
	box(Part.PLATE, Vector3(0.0, 0.049, 0.03), Vector3(0.05, 0.014, 0.17))
	box(Part.DARK, Vector3(0.0, -0.086, 0.085), Vector3(0.042, 0.11, 0.046), Vector3(-17.0, 0.0, 0.0))
	box(Part.DARK, Vector3(0.0, -0.054, 0.035), Vector3(0.014, 0.01, 0.06))
	# The trunk, the shell tube under it, and the joint where it forks.
	prism(Part.BODY, Vector3(0.0, 0.01, -0.12), 0.024, 0.1, 8, Vector3.ZERO, -1.0, 22.5)
	prism(Part.PLATE, Vector3(0.0, -0.03, -0.09), 0.014, 0.14, 8)
	box(Part.PLATE, Vector3(0.0, 0.01, -0.185), Vector3(0.072, 0.042, 0.04))
	box(Part.TRIM, Vector3(0.0, 0.032, -0.185), Vector3(0.05, 0.002, 0.03))
	# The two prongs.
	for x in [-1.0, 1.0]:
		var turn := Vector3(0.0, -PRONG_DEGREES * x, 0.0)
		var along := _basis(turn) * Vector3.FORWARD
		var root := Vector3(0.016 * x, 0.01, -0.205)
		prism(Part.BODY, root + along * PRONG_M * 0.5, 0.015, PRONG_M, 8, turn, -1.0, 22.5)
		tube(Part.TRIM, root + along * (PRONG_M - 0.01), 0.015, 0.02, 0.006, 8, turn, 22.5)
		prism(Part.HOT, root + along * (PRONG_M + 0.0015), 0.009, 0.002, 8, turn, -1.0, 22.5)
		box(Part.TRIM, root + along * PRONG_M * 0.5 + Vector3(0.0, 0.0145, 0.0), Vector3(0.002, 0.002, PRONG_M * 0.85), turn)
	# Neon along the receiver.
	for x in [-1.0, 1.0]:
		box(Part.TRIM, Vector3(0.0375 * x, 0.022, 0.03), Vector3(0.002, 0.005, 0.17))
	muzzle.position = Vector3(0.0, 0.01, -0.4)
