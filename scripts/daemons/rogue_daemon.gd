extends DaemonArt
## The rogue daemon (A2, the "rogue.d" dummy), the art bar's own: a red-hot crystal core, five tall
## obsidian blades standing round it in a twisted crown with gaps to see it through, turning one
## way, and seven shards leaning out round them, turning the other, over three spikes meeting in a
## point a hand above the ground: it hovers. Eight red glyphs go round it.

const BLADES := 5
const SHARDS := 7
const ROOTS := 3


func _build() -> void:
	core_color = Palette.HOSTILE_RED
	glyph_count = 8
	glyph_radius = 0.78
	glyph_low = -0.25
	glyph_high = 0.85
	glyph_turns = 0.04
	var still := layer(0.0)
	core_spike(still, Vector3(0.0, -0.22, 0.0), Vector3(0.0, 0.34, 0.0), 0.15, 6, 0.42)
	core_spike(still, Vector3(-0.17, 0.05, 0.0), Vector3(0.17, 0.05, 0.0), 0.07, 4, 0.5, 45.0)
	var blades := layer(0.11)
	for i in BLADES:
		var a := TAU * i / BLADES
		var foot := Vector3(cos(a) * 0.25, -0.6, sin(a) * 0.25)
		var tip := Vector3(cos(a + 0.35) * 0.16, 0.82 - 0.07 * (i % 2), sin(a + 0.35) * 0.16)
		shell_spike(blades, foot, tip, 0.075, 4, 0.36, 45.0)
	var shards := layer(-0.06)
	for i in SHARDS:
		var a := TAU * (i + 0.5) / SHARDS
		var inner := Vector3(cos(a) * 0.3, -0.32 + 0.05 * (i % 3), sin(a) * 0.3)
		var outer := Vector3(cos(a) * 0.64, 0.42 + 0.08 * ((i * 2) % 3), sin(a) * 0.64)
		shell_spike(shards, inner, outer, 0.055, 3, 0.3)
	for i in ROOTS:
		var a := TAU * i / ROOTS
		shell_spike(shards, Vector3(cos(a) * 0.2, -0.42, sin(a) * 0.2), Vector3(0.0, -0.84, 0.0), 0.06, 3, 0.25)
