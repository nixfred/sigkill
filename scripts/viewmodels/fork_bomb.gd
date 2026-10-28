extends Viewmodel
## The fork bomb's model (weapon 4, magenta, A1): a held canister, not a gun. Two hex rings joined
## by struts cage a drum of six lit pods that turns slowly, the copies waiting to fork; a polymer
## cap at the back, a lit hub at the front, and a cradle and grip under it.

## How fast the drum turns while held, in turns a second.
const DRUM_TURNS := 0.25
## The canister is held turned toward the eye, its lit front showing: degrees up and to the left.
const HOLD_PITCH := 14.0
const HOLD_YAW := 38.0


func _build() -> void:
	body_hex = true
	pose = Transform3D(Basis.from_euler(Vector3(deg_to_rad(HOLD_PITCH), deg_to_rad(HOLD_YAW), 0.0)), Vector3.ZERO)
	# The cage: two hex rings and six struts.
	for z in [-0.045, 0.045]:
		tube(Part.PLATE, Vector3(0.0, 0.0, z), 0.05, 0.062, 0.014, 6, Vector3.ZERO, 30.0)
	for i in 6:
		var a := TAU * i / 6.0
		box(Part.BODY, Vector3(cos(a), sin(a), 0.0) * 0.058, Vector3(0.012, 0.012, 0.09), Vector3(0.0, 0.0, rad_to_deg(a)))
	# The drum: a hub and six pods, turning together.
	var hub := piece(Part.BODY)
	var pods := piece(Part.TRIM)
	prism(hub, Vector3.ZERO, 0.022, 0.1, 8)
	for i in 6:
		var a := TAU * i / 6.0 + PI / 6.0
		prism(pods, Vector3(cos(a), sin(a), 0.0) * 0.036, 0.011, 0.08, 6)
	spin(hub, Vector3.BACK, DRUM_TURNS)
	spin(pods, Vector3.BACK, DRUM_TURNS)
	prism(Part.HOT, Vector3(0.0, 0.0, -0.052), 0.012, 0.004, 8)
	# The cap and its pin, the cradle and the grip.
	prism(Part.DARK, Vector3(0.0, 0.0, 0.07), 0.026, 0.03, 8)
	tube(Part.TRIM, Vector3(0.0, 0.0, 0.058), 0.026, 0.03, 0.005, 8)
	box(Part.PLATE, Vector3(0.0, 0.03, 0.074), Vector3(0.006, 0.02, 0.012))
	box(Part.DARK, Vector3(0.0, -0.072, 0.01), Vector3(0.032, 0.026, 0.11))
	box(Part.DARK, Vector3(0.0, -0.115, 0.04), Vector3(0.036, 0.08, 0.042), Vector3(-12.0, 0.0, 0.0))
	muzzle.position = Vector3(0.0, 0.0, -0.06)
