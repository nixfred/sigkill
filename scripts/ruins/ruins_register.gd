class_name RuinsRegister
extends RefCounted
## The ruins' three registers (C36, docs/STORY.md section 1), and the finale's "all": every colour, the sky, the fog,
## the sun and the weather of each, for scripts/ruins/ruins_world.gd to put the ruins in, and mix between as a
## mission's register shifts. The ruins' shaders blend their colours by the shader global ruins_mix
## (shaders/ruins_common.gdshaderinc); everything not in a shader (the environment, the sun, the lights' colours, how
## much rain) is mixed here by the same weights.
##   tron       the clean grid: teal and mint on black, the edges bright, the lights alive, motes of data rising
##   cyberpunk  the ruins in the rain: dead megacorps' neon in magenta and amber high on the towers, a violet haze,
##              the floor wet, most status lights dead
##   matrix     where memory is thin: dark, green code streaming down every wall and falling through the air
##   all        the three at once, mixed across the place, the finale's
## Readable against every one (Fred's A5 and I1 colours, measured in OKLab): no colour of the ruins comes nearer than
## READABLE_GAP to a daemon's or ICE's (rogue.d crimson, the zombie's amber, the runaway's magenta, the glitch split,
## ICE's glacier and cobalt, Black ICE), the signs' magenta and amber included (they hang high, behind the haze, and
## the floor's own light is cold). tests/ruins_test.gd measures it.

const Palette = preload("res://scripts/palette.gd")

const NAMES := ["tron", "cyberpunk", "matrix", "all"]
## The least OKLab distance any ruins colour keeps from a daemon's or ICE's colour.
const READABLE_GAP := 0.1
## The signs' neon (cyberpunk): a magenta toward violet and an amber toward orange, each READABLE_GAP or more from
## the runaway's magenta, the glitch split and the zombie's amber.
const NEON_MAGENTA := Color(0.823529412, 0.294117647, 1.0)  # #d24bff
const NEON_AMBER := Color(1.0, 0.478431373, 0.101960784)  # #ff7a1a
## The ruins' cold violet in the rain: strips, the floor's grid, the haze; and the deeper indigo of their edges.
const RAIN_VIOLET := Color(0.607843137, 0.360784314, 1.0)  # #9b5cff
const RAIN_INDIGO := Color(0.45, 0.32, 0.9)
const HOT_WHITE := Color(1.0, 0.94, 0.82)
const BEACON_WHITE := Color(0.82, 1.0, 0.95)

## Each register's light slots (shaders/ruins_light.gdshader): status LED, strip, sign A, sign B, beacon, screen text,
## a white-hot spark, the void's glow far below.
const SLOTS := {
	"tron": [Palette.MINT, Palette.TEAL, Palette.TEAL, Palette.MINT, BEACON_WHITE, Palette.TEAL, HOT_WHITE, Palette.TEAL],
	"cyberpunk": [Palette.TEAL, RAIN_VIOLET, NEON_MAGENTA, NEON_AMBER, NEON_AMBER, Palette.TEAL, HOT_WHITE, RAIN_VIOLET],
	"matrix": [Palette.MATRIX_GREEN, Palette.MATRIX_GREEN, Palette.MATRIX_GREEN, Palette.MATRIX_HEAD, Palette.MATRIX_HEAD, Palette.MATRIX_GREEN, Palette.MATRIX_HEAD, Palette.MATRIX_GREEN],
}
## A palette (M6): a set's own colours for its cyberpunk, in place of the register's (RuinsSet.palette). "abyss" is the
## deepest ruins', mission 6's drowned city: ice-cyan and acid neon, ultramarine strips, a deep blue haze and fog, black
## water holding the light. Every colour keeps READABLE_GAP from the daemons' and ICE's (the tests measure these too).
const ICE_CYAN := Color(0.55, 0.95, 1.0)
const ACID := Color(0.8, 1.0, 0.2)
const ULTRA := Color(0.45, 0.4, 1.0)
const WHITE_BLUE := Color(0.8, 0.9, 1.0)
## "core" (M7) is the finale's: the machine's heart round a red-hot core, everything the colour of heat: pale gold and
## straw on the strips and screens, amber signs, white-hot beacons, a dark ember glow from the void, and the water under
## the floor a sea of heat that glows of itself ("water_glow", the one key the drowned city's water has not).
const PALE_GOLD := Color(1.0, 0.9, 0.7)
const STRAW := Color(1.0, 0.95, 0.6)
const GOLD := Color(1.0, 0.85, 0.55)
const WHITE_HOT := Color(1.0, 0.97, 0.9)
const DARK_EMBER := Color(0.6, 0.12, 0.02)
const PALETTES := {
	"abyss": {
		"slots": [ICE_CYAN, ULTRA, ICE_CYAN, ACID, WHITE_BLUE, ICE_CYAN, HOT_WHITE, ULTRA],
		"env": {"fog": Color(0.015, 0.04, 0.12), "fog_density": 0.95, "fog_end": 300.0, "horizon": Color(0.02, 0.05, 0.16), "abyss": Color(0.0, 0.006, 0.02), "glow": ICE_CYAN, "points": ACID, "glow_energy": 0.35, "ambient": ULTRA, "ambient_energy": 0.07, "sun": Color(0.45, 0.6, 1.0), "sun_energy": 0.3, "rain": 1.0, "motes": 0.1, "glyphs": 0.0},
		"edge": ULTRA, "vein": ICE_CYAN, "sheen": ULTRA, "grid": ULTRA, "crack": ICE_CYAN, "puddle": ICE_CYAN, "puddle_b": ULTRA,
		"haze": Color(0.08, 0.18, 0.5), "water": Color(0.004, 0.012, 0.045), "water_rim": ULTRA, "water_glow": Color(0.0, 0.0, 0.0),
	},
	"core": {
		"slots": [PALE_GOLD, NEON_AMBER, STRAW, GOLD, WHITE_HOT, PALE_GOLD, HOT_WHITE, DARK_EMBER],
		"env": {"fog": Color(0.14, 0.035, 0.012), "fog_density": 0.9, "fog_end": 360.0, "horizon": Color(0.2, 0.05, 0.012), "abyss": Color(0.22, 0.03, 0.0), "glow": NEON_AMBER, "points": HOT_WHITE, "glow_energy": 0.5, "ambient": Color(1.0, 0.5, 0.2), "ambient_energy": 0.08, "sun": Color(1.0, 0.62, 0.3), "sun_energy": 0.35, "rain": 0.5, "motes": 0.4, "glyphs": 0.0},
		"edge": NEON_AMBER, "vein": PALE_GOLD, "sheen": NEON_AMBER, "grid": GOLD, "crack": STRAW, "puddle": NEON_AMBER, "puddle_b": PALE_GOLD,
		"haze": Color(0.5, 0.18, 0.06), "water": Color(0.5, 0.04, 0.01), "water_rim": NEON_AMBER, "water_glow": Color(0.42, 0.05, 0.01),
	},
}
## The colours the ruins must keep their distance from.
const FOES := [Palette.CRIMSON, Palette.HOSTILE_AMBER, Palette.HOT_MAGENTA, Palette.GLITCH_SPLIT, Palette.HOSTILE_RED, Palette.GLACIER, Palette.HUNTER_COBALT, Palette.BLACK_ICE]

## Each register's place: the fog, the sky, the ambient light, the sun, and its weather (how much of the rain, the
## motes and the falling glyphs, 0 to 1, and how the fog runs: its depth's end and its density).
const ENV := {
	"tron": {"fog": Color(0.012, 0.071, 0.078), "fog_density": 0.82, "fog_end": 520.0, "horizon": Color(0.012, 0.063, 0.071), "abyss": Color(0.004, 0.016, 0.02), "glow": Palette.TEAL, "points": Palette.MINT, "glow_energy": 0.35, "ambient": Palette.TEAL, "ambient_energy": 0.05, "sun": Color(0.72, 1.0, 0.94), "sun_energy": 0.55, "rain": 0.0, "motes": 1.0, "glyphs": 0.0},
	"cyberpunk": {"fog": Color(0.1, 0.038, 0.15), "fog_density": 0.92, "fog_end": 340.0, "horizon": Color(0.13, 0.035, 0.15), "abyss": Color(0.012, 0.004, 0.02), "glow": NEON_MAGENTA, "points": NEON_AMBER, "glow_energy": 0.55, "ambient": RAIN_VIOLET, "ambient_energy": 0.07, "sun": Color(0.55, 0.5, 1.0), "sun_energy": 0.32, "rain": 1.0, "motes": 0.15, "glyphs": 0.0},
	"matrix": {"fog": Color(0.0, 0.05, 0.016), "fog_density": 0.88, "fog_end": 420.0, "horizon": Color(0.0, 0.055, 0.02), "abyss": Color(0.0, 0.012, 0.004), "glow": Palette.MATRIX_GREEN, "points": Palette.MATRIX_HEAD, "glow_energy": 0.3, "ambient": Palette.MATRIX_GREEN, "ambient_energy": 0.04, "sun": Color(0.55, 1.0, 0.65), "sun_energy": 0.34, "rain": 0.0, "motes": 0.2, "glyphs": 1.0},
}


## A register's weights: x tron, y cyberpunk, z matrix, w all (an unknown name is tron's).
static func weights(register: String) -> Vector4:
	match register:
		"cyberpunk":
			return Vector4(0, 1, 0, 0)
		"matrix":
			return Vector4(0, 0, 1, 0)
		"all":
			return Vector4(0, 0, 0, 1)
	return Vector4(1, 0, 0, 0)


## The three registers' shares of a mix (the finale's "all" is a third each, on the whole), summing to 1.
static func shares(mix: Vector4) -> Vector3:
	var s := Vector3(mix.x, mix.y, mix.z) + Vector3.ONE * (mix.w / 3.0)
	var total := s.x + s.y + s.z
	return s / total if total > 0.0 else Vector3(1, 0, 0)


## The place's settings at `mix`: each of ENV's keys, mixed by its shares; with a `palette` (M6), its cyberpunk is the
## palette's.
static func env_at(mix: Vector4, palette: String = "") -> Dictionary:
	var s := shares(mix)
	var out := {}
	var cyber: Dictionary = ENV["cyberpunk"]
	if palette != "" and PALETTES.has(palette):
		cyber = cyber.duplicate()
		cyber.merge(PALETTES[palette]["env"], true)
	var parts := [ENV["tron"], cyber, ENV["matrix"]]
	for key in ENV["tron"]:
		var a = parts[0][key]
		var b = parts[1][key]
		var c = parts[2][key]
		if a is Color:
			out[key] = Color(a.r * s.x + b.r * s.y + c.r * s.z, a.g * s.x + b.g * s.y + c.g * s.z, a.b * s.x + b.b * s.y + c.b * s.z)
		else:
			out[key] = float(a) * s.x + float(b) * s.y + float(c) * s.z
	return out


## Register `register`'s colour for light slot `slot`, or (M6) the palette's where it has one for its cyberpunk.
static func slot_of(register: String, slot: int, palette: String = "") -> Color:
	if register == "cyberpunk" and palette != "" and PALETTES.has(palette):
		return PALETTES[palette]["slots"][slot]
	return SLOTS.get(register, SLOTS["tron"])[slot]


## Every colour of the ruins' own light (every register's slots but the white-hot spark, the signs' neon among them;
## M6: every palette's slots and tints too).
static func colours() -> Array[Color]:
	var out: Array[Color] = []
	for name in SLOTS:
		var slots: Array = SLOTS[name]
		for i in slots.size():
			if i != 6:
				out.append(slots[i])
	out.append(RAIN_VIOLET)
	out.append(RAIN_INDIGO)
	for name in PALETTES:
		var pal: Dictionary = PALETTES[name]
		for i in (pal["slots"] as Array).size():
			if i != 6:
				out.append(pal["slots"][i])
		for key in ["edge", "vein", "sheen", "grid", "crack", "puddle", "puddle_b", "water_rim"]:
			out.append(pal[key])
	return out


## Dresses a set's own materials (M6) in palette `name`: its cyberpunk colours over the register's.
static func dress_palette(name: String, body: ShaderMaterial, light: ShaderMaterial, floor: ShaderMaterial, haze: ShaderMaterial) -> void:
	var pal: Dictionary = PALETTES[name]
	body.set_shader_parameter("edge_cyber", pal["edge"])
	body.set_shader_parameter("vein_cyber", pal["vein"])
	body.set_shader_parameter("sheen_color", pal["sheen"])
	var arr := PackedVector4Array()
	for c in pal["slots"]:
		arr.append(Vector4(c.r, c.g, c.b, 1.0))
	light.set_shader_parameter("cyber_slots", arr)
	floor.set_shader_parameter("grid_cyber", pal["grid"])
	floor.set_shader_parameter("crack_cyber", pal["crack"])
	floor.set_shader_parameter("puddle_tint", pal["puddle"])
	floor.set_shader_parameter("puddle_tint_b", pal["puddle_b"])
	haze.set_shader_parameter("haze_cyber", pal["haze"])


## Sets the ruins' materials' register colours, once as they are built.
static func dress(body: ShaderMaterial, light: ShaderMaterial, floor: ShaderMaterial, haze: ShaderMaterial) -> void:
	body.set_shader_parameter("metal_color", Color(0.043, 0.055, 0.067))
	body.set_shader_parameter("stone_color", Color(0.012, 0.016, 0.022))
	body.set_shader_parameter("edge_tron", Palette.TEAL)
	body.set_shader_parameter("edge_cyber", RAIN_INDIGO)
	body.set_shader_parameter("edge_matrix", Palette.MATRIX_GREEN)
	body.set_shader_parameter("vein_tron", Palette.TEAL)
	body.set_shader_parameter("vein_cyber", NEON_MAGENTA)
	body.set_shader_parameter("vein_matrix", Palette.MATRIX_GREEN)
	body.set_shader_parameter("glyph_head", Palette.MATRIX_HEAD)
	body.set_shader_parameter("glyph_tail", Palette.MATRIX_GREEN)
	body.set_shader_parameter("sheen_color", RAIN_VIOLET)
	body.set_shader_parameter("hot_color", HOT_WHITE)
	for name in SLOTS:
		var key: String = {"tron": "tron_slots", "cyberpunk": "cyber_slots", "matrix": "matrix_slots"}[name]
		var arr := PackedVector4Array()
		for c in SLOTS[name]:
			arr.append(Vector4(c.r, c.g, c.b, 1.0))
		light.set_shader_parameter(key, arr)
	floor.set_shader_parameter("grid_tron", Palette.MINT)
	floor.set_shader_parameter("grid_cyber", RAIN_VIOLET)
	floor.set_shader_parameter("grid_matrix", Palette.MATRIX_GREEN)
	floor.set_shader_parameter("crack_tron", Palette.TEAL)
	floor.set_shader_parameter("crack_cyber", RAIN_VIOLET)
	floor.set_shader_parameter("crack_matrix", Palette.MATRIX_GREEN)
	floor.set_shader_parameter("glyph_head", Palette.MATRIX_HEAD)
	floor.set_shader_parameter("glyph_tail", Palette.MATRIX_GREEN)
	floor.set_shader_parameter("puddle_tint", NEON_MAGENTA)
	floor.set_shader_parameter("puddle_tint_b", NEON_AMBER)
	haze.set_shader_parameter("haze_tron", Color(0.06, 0.4, 0.4))
	haze.set_shader_parameter("haze_cyber", Color(0.42, 0.16, 0.6))
	haze.set_shader_parameter("haze_matrix", Color(0.0, 0.42, 0.1))


## Colour `c` in OKLab (Bjorn Ottosson's), for the distance between two colours as the eye sees it.
static func oklab(c: Color) -> Vector3:
	var lin := func(v: float) -> float: return v / 12.92 if v <= 0.04045 else pow((v + 0.055) / 1.055, 2.4)
	var r: float = lin.call(c.r)
	var g: float = lin.call(c.g)
	var b: float = lin.call(c.b)
	var l := pow(0.4122214708 * r + 0.5363325363 * g + 0.0514459929 * b, 1.0 / 3.0)
	var m := pow(0.2119034982 * r + 0.6806995451 * g + 0.1073969566 * b, 1.0 / 3.0)
	var s := pow(0.0883024619 * r + 0.2817188376 * g + 0.6299787005 * b, 1.0 / 3.0)
	return Vector3(0.2104542553 * l + 0.7936177850 * m - 0.0040720468 * s, 1.9779984951 * l - 2.4285922050 * m + 0.4505937099 * s, 0.0259040371 * l + 0.7827717662 * m - 0.8086757660 * s)


## The least OKLab distance colour `c` keeps from the daemons' and ICE's colours.
static func gap(c: Color) -> float:
	var least := INF
	for foe in FOES:
		least = minf(least, oklab(c).distance_to(oklab(foe)))
	return least
