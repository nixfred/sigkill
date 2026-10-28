extends Viewmodel
## cron mines' model (weapon 8, rose, A1): a dispenser. A flat body carries the next mine loaded at
## its front, a hex stud like the ones it places, its lit centre beating once a run interval; on
## top a clock face with four lit ticks and a hand going round once a run interval.

## A run interval when the weapon names none, in seconds.
const INTERVAL_S := 2.0


func _build() -> void:
	plate_hex = true
	var interval: float = def.get("run_interval_s") if def.get("run_interval_s") is float else INTERVAL_S
	interval = interval if interval > 0.0 else INTERVAL_S
	# Body, front plate, cradle arms, grip and guard.
	box(Part.BODY, Vector3(0.0, 0.0, 0.03), Vector3(0.09, 0.06, 0.18))
	box(Part.PLATE, Vector3(0.0, 0.0, -0.075), Vector3(0.1, 0.05, 0.03))
	for x in [-1.0, 1.0]:
		box(Part.BODY, Vector3(0.044 * x, 0.0, -0.105), Vector3(0.012, 0.03, 0.04))
		box(Part.TRIM, Vector3(0.0455 * x, 0.012, 0.03), Vector3(0.002, 0.005, 0.16))
	box(Part.DARK, Vector3(0.0, -0.075, 0.085), Vector3(0.042, 0.1, 0.046), Vector3(-15.0, 0.0, 0.0))
	box(Part.DARK, Vector3(0.0, -0.045, 0.035), Vector3(0.014, 0.01, 0.06))
	# The loaded mine: a hex stud facing forward, its centre beating with the schedule.
	prism(Part.PLATE, Vector3(0.0, 0.0, -0.12), 0.046, 0.022, 6, Vector3.ZERO, 0.04, 30.0)
	tube(Part.TRIM, Vector3(0.0, 0.0, -0.1325), 0.028, 0.035, 0.004, 6, Vector3.ZERO, 30.0)
	var stud := piece(Part.HOT)
	prism(stud, Vector3(0.0, 0.0, -0.133), 0.014, 0.006, 6, Vector3.ZERO, -1.0, 30.0)
	pulse(stud, 1.0 / interval, 0.45)
	# The clock: a face, a lit ring, four ticks and a hand going round once a run interval.
	prism(Part.PLATE, Vector3(0.0, 0.032, 0.03), 0.033, 0.004, 16, Vector3(90.0, 0.0, 0.0))
	tube(Part.TRIM, Vector3(0.0, 0.035, 0.03), 0.027, 0.032, 0.004, 16, Vector3(90.0, 0.0, 0.0))
	for i in 4:
		var a := TAU * i / 4.0
		box(Part.HOT, Vector3(0.0, 0.035, 0.03) + Vector3(sin(a), 0.0, -cos(a)) * 0.021, Vector3(0.004, 0.003, 0.004))
	var hand := piece(Part.HOT, Vector3(0.0, 0.036, 0.03))
	box(hand, Vector3(0.0, 0.036, 0.019), Vector3(0.003, 0.003, 0.022))
	spin(hand, Vector3.UP, -1.0 / interval)
	muzzle.position = Vector3(0.0, 0.0, -0.137)
