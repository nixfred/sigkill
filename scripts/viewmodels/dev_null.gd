extends Viewmodel
## /dev/null's model (weapon 12, plum, C31): a containment cradle for a singularity, a sink you hold, not a
## grenade. Three curved prongs reach forward from a ring collar and cup a sphere of black glass, the
## device, between them; round it two gyroscope rings of plum light turn on crossed axes, and a white-hot
## photon ring hugs it, breathing. Along both flanks chevrons point in toward it, everything flows in.
## On top of the collar the charge cells, one per charge, lit as charges come back (the player sets them:
## two lit full, one while the spent one recharges). Behind the collar a short receiver in dark hex metal,
## vents down its sides; a grip and its guard under it. With no charge left the sphere's ring goes dark.

## Turns a second of the two gyro rings at rest.
const GYRO_TURNS := 0.35
const GYRO_CROSS_TURNS := 0.55
## How hard the photon ring breathes.
const RING_HZ := 1.8
const RING_DEPTH := 0.45
## The device sits this far forward of the grip; its radius.
const DEVICE_Z := -0.15
const DEVICE_R := 0.042
## The model's charge cells: one per charge of the loadout's magazine (2).
const CELLS := 2

var _gyros: Array[int] = []
var _photon := -1


func _build() -> void:
	body_hex = true
	# The receiver: dark hex metal, vents down both flanks, a back cap.
	prism(Part.BODY, Vector3(0.0, 0.0, 0.04), 0.036, 0.13, 6, Vector3.ZERO, 0.032, 30.0)
	prism(Part.DARK, Vector3(0.0, 0.0, 0.112), 0.028, 0.012, 6, Vector3.ZERO, -1.0, 30.0)
	tube(Part.TRIM, Vector3(0.0, 0.0, 0.104), 0.028, 0.031, 0.004, 6, Vector3.ZERO, 30.0)
	for x in [-1.0, 1.0]:
		for i in 3:
			box(Part.PLATE, Vector3(0.034 * x, -0.004, 0.07 - 0.028 * i), Vector3(0.006, 0.02, 0.008), Vector3(0.0, 0.0, 22.0 * x))
	# The collar: a ring round the receiver's front, the cradle's root.
	tube(Part.PLATE, Vector3(0.0, 0.0, -0.035), 0.034, 0.05, 0.022, 12)
	tube(Part.TRIM, Vector3(0.0, 0.0, -0.047), 0.046, 0.05, 0.003, 12)
	# The charge cells on top of the collar, lit one per charge.
	for i in CELLS:
		var cell := charge_piece(Part.HOT, i)
		box(cell, Vector3(-0.011 + 0.022 * i, 0.054, -0.03), Vector3(0.014, 0.008, 0.016))
		box(Part.PLATE, Vector3(-0.011 + 0.022 * i, 0.049, -0.03), Vector3(0.018, 0.004, 0.02))
	# The prongs: three arms curving forward round the device, each in three bent segments.
	for k in 3:
		var a := deg_to_rad(90.0 + 120.0 * k)
		var out := Vector3(cos(a), sin(a), 0.0)
		var turn := Vector3(0.0, 0.0, rad_to_deg(a) - 90.0)
		box(Part.BODY, out * 0.054 + Vector3(0.0, 0.0, -0.062), Vector3(0.01, 0.012, 0.04), turn)
		box(Part.BODY, out * 0.066 + Vector3(0.0, 0.0, -0.1), Vector3(0.009, 0.011, 0.04), turn)
		box(Part.BODY, out * 0.06 + Vector3(0.0, 0.0, -0.14), Vector3(0.008, 0.01, 0.036), turn)
		box(Part.BODY, out * 0.046 + Vector3(0.0, 0.0, -0.172), Vector3(0.007, 0.009, 0.03), turn)
		box(Part.TRIM, out * 0.0715 + Vector3(0.0, 0.0, -0.1), Vector3(0.0025, 0.002, 0.034), turn)
		# A small glowing pad at each prong's tip, where it holds the field.
		box(Part.HOT, out * 0.04 + Vector3(0.0, 0.0, -0.186), Vector3(0.008, 0.004, 0.008), turn)
	# The device: a sphere of black glass, in stacked slices.
	var slices := 7
	for i in slices:
		var u0 := -1.0 + 2.0 * float(i) / slices
		var u1 := -1.0 + 2.0 * float(i + 1) / slices
		var r0 := sqrt(maxf(1.0 - u0 * u0, 0.0)) * DEVICE_R
		var r1 := sqrt(maxf(1.0 - u1 * u1, 0.0)) * DEVICE_R
		var mid := (u0 + u1) * 0.5 * DEVICE_R
		prism(Part.DARK, Vector3(0.0, 0.0, DEVICE_Z + mid), maxf(r0, 0.002), (u1 - u0) * DEVICE_R, 14, Vector3.ZERO, maxf(r1, 0.002))
	# The photon ring hugging it, breathing.
	_photon = piece(Part.HOT, Vector3(0.0, 0.0, DEVICE_Z))
	tube(_photon, Vector3(0.0, 0.0, DEVICE_Z), DEVICE_R * 1.04, DEVICE_R * 1.14, 0.003, 20)
	pulse(_photon, RING_HZ, RING_DEPTH)
	# The gyroscope rings, crossed, each its own piece turning on its own axis.
	var gyro := piece(Part.TRIM, Vector3(0.0, 0.0, DEVICE_Z))
	tube(gyro, Vector3(0.0, 0.0, DEVICE_Z), DEVICE_R * 1.42, DEVICE_R * 1.56, 0.004, 22, Vector3(90.0, 0.0, 0.0))
	spin(gyro, Vector3.FORWARD, GYRO_TURNS)
	_gyros.append(gyro)
	var cross := piece(Part.TRIM, Vector3(0.0, 0.0, DEVICE_Z))
	tube(cross, Vector3(0.0, 0.0, DEVICE_Z), DEVICE_R * 1.7, DEVICE_R * 1.82, 0.004, 22, Vector3(0.0, 90.0, 0.0))
	spin(cross, Vector3.UP, -GYRO_CROSS_TURNS)
	_gyros.append(cross)
	# Chevrons down both flanks, pointing in toward the device: the sink's flow.
	for x in [-1.0, 1.0]:
		for i in 3:
			chevron(Part.TRIM, Vector3(0.0375 * x, 0.012, 0.075 - 0.03 * i), 0.012, -1.0)
	# The rail under the receiver, the grip and its guard.
	box(Part.PLATE, Vector3(0.0, -0.038, 0.03), Vector3(0.026, 0.01, 0.1))
	box(Part.DARK, Vector3(0.0, -0.08, 0.08), Vector3(0.036, 0.09, 0.042), Vector3(-14.0, 0.0, 0.0))
	box(Part.DARK, Vector3(0.0, -0.046, 0.03), Vector3(0.012, 0.01, 0.05))
	muzzle.position = Vector3(0.0, 0.0, DEVICE_Z - DEVICE_R * 1.3)


## The gyro rings' turns so far, for the checks: the first ring's angle about its axis.
func gyro_angle() -> float:
	return (_pieces[_gyros[0] - PARTS]["node"] as Node3D).rotation.z
