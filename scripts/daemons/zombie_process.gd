extends DaemonArt
## The zombie process (A2, the "zombie" and "<defunct>" dummies: a defunct process is a zombie):
## dead, never reaped. An obsidian obelisk broken into six chunks that grind slowly against each
## other, two ways, its tip floating tilted above it; an ember column inside guttering hostile amber
## through the cracks; four bits of debris drifting round; five glyphs creeping round the wrong
## way. It does not hover: it stands where it died.

## Each chunk: its bottom, its height, its half-width at the bottom and at the top, in metres, and
## how far it is knocked off true, in degrees: the cracks between them are wedges, no two alike.
const CHUNKS := [[-0.88, 0.34, 0.40, 0.37, -4.0], [-0.51, 0.24, 0.37, 0.33, 7.0], [-0.24, 0.30, 0.33, 0.29, -9.0], [0.09, 0.20, 0.29, 0.26, 5.0], [0.32, 0.22, 0.26, 0.22, -6.0], [0.57, 0.16, 0.22, 0.18, 11.0]]
const DEBRIS := 4


func _build() -> void:
	core_color = Palette.HOSTILE_AMBER
	gutter = 1.0
	hover_m = 0.0
	glyph_count = 5
	glyph_radius = 0.64
	glyph_low = -0.55
	glyph_high = 0.65
	glyph_turns = -0.02
	var still := layer(0.0)
	core_prism(still, Vector3(0.0, -0.1, 0.0), 0.11, 1.45, 4, Vector3(90.0, 0.0, 0.0), -1.0, 45.0)
	var grind_a := layer(0.022)
	var grind_b := layer(-0.017)
	for i in CHUNKS.size():
		var c: Array = CHUNKS[i]
		var side := 1.0 if i % 2 == 0 else -1.0
		var center := Vector3(0.03 * side, c[0] + c[1] * 0.5, 0.02 * (i - 2))
		var tilt := Vector3(90.0 + c[4], 13.0 * i, c[4] * 0.6 * side)
		shell_prism(grind_a if i % 2 == 0 else grind_b, center, c[2] * sqrt(2.0), c[1], 4, tilt, c[3] * sqrt(2.0), 45.0)
	# The tip, broken off: a pyramid floating tilted above the stump.
	shell_spike(grind_b if CHUNKS.size() % 2 == 0 else grind_a, Vector3(0.03, 0.82, 0.0), Vector3(0.1, 1.1, 0.03), 0.19, 4, 0.04, 45.0)
	var debris := layer(0.05)
	for i in DEBRIS:
		var a := TAU * (i + 0.3) / DEBRIS
		var at := Vector3(cos(a) * 0.52, -0.6 + 0.3 * i, sin(a) * 0.52)
		shell_spike(debris, at, at + Vector3(0.05 * (i % 2), 0.11, 0.06), 0.04, 3, 0.4)
