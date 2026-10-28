extends DaemonArt
## The runaway app (A2, the "runaway" dummy) as the art bar's swarm of angular drones: a small
## red-hot core with thirteen obsidian darts going round it in three tilted rings, each ring at its
## own pace and way, every dart pointing where it flies, with two blade fins and a glowing tail; the
## swarm bobs restlessly, and six glyphs whip round it.

## Each ring: its darts, its radius, its turns a second (the sign its way), its tilt in degrees.
const RINGS := [[5, 0.46, 0.42, Vector3.ZERO], [4, 0.36, -0.55, Vector3(62.0, 0.0, 0.0)], [4, 0.56, 0.66, Vector3(-48.0, 0.0, 38.0)]]


func _build() -> void:
	core_color = Palette.HOSTILE_RED
	glyph_count = 6
	glyph_radius = 0.72
	glyph_low = -0.4
	glyph_high = 0.55
	glyph_turns = 0.14
	hover_m = 0.06
	hover_hz = 1.1
	var still := layer(0.0)
	core_spike(still, Vector3(0.0, -0.13, 0.0), Vector3(0.0, 0.13, 0.0), 0.1, 4, 0.5)
	core_spike(still, Vector3(-0.1, 0.0, 0.0), Vector3(0.1, 0.0, 0.0), 0.06, 4, 0.5, 45.0)
	for r in RINGS:
		var darts: int = r[0]
		var radius: float = r[1]
		var turns: float = r[2]
		var ring := layer(turns, r[3])
		var way := 1.0 if turns > 0.0 else -1.0
		for d in darts:
			var a := TAU * d / darts
			var at := Vector3(cos(a), 0.0, sin(a)) * radius
			# A point turning about +Y moves along (sin a, 0, -cos a): the dart points that way.
			var ahead := Vector3(sin(a), 0.0, -cos(a)) * way
			var side := Vector3.UP.cross(ahead)
			shell_spike(ring, at - ahead * 0.16, at + ahead * 0.15, 0.07, 3, 0.3, 90.0)
			for wing in [-1.0, 1.0]:
				shell_spike(ring, at - ahead * 0.07, at - ahead * 0.15 + side * wing * 0.13, 0.022, 3, 0.25)
			core_spike(ring, at - ahead * 0.21, at - ahead * 0.15, 0.03, 3, 0.5)
