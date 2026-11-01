class_name ThemeLook
extends RefCounted
## A theme's look for the whole frame (W3): what shaders/theme_grade.gdshader recolours the picture with, made from a
## terminal palette (OpenerPalette: the opener's demo palettes, or the player's own theme read by the real layer).
##
## The grade works the way a terminal theme does: by what a colour *means*, not by a hue slider.
##   - Its neutrals (the void, the floor, the armour, the HUD's panels, a white-hot glint): the picture's lightness read
##     down a ramp of the theme's own background and foreground shades (RAMP_KEYS at RAMP_AT), darkest to brightest; in
##     a light theme the ramp runs the other way, so the void is paper and a light is ink.
##   - Its colours: each hue taken to the theme's colour of that name (HUE_KEYS at HUE_AT, in degrees: a hostile's crimson
##     to the theme's red, the zombie's amber to its yellow, the player's teal to its cyan, the Matrix's green to its
##     green, the runaway's magenta to its bright magenta), lifted toward the source's brightness (at most LIFT_MOST),
##     mixed in by how coloured the source is (SAT_FROM to SAT_TO of its chroma).
## So a rogue.d stays red and the player teal in every theme, each in that theme's own red and cyan, and the frame reads
## as the theme. grade() is the shader's sum on the CPU, for the checks (the two are kept the same: HUE_AT and RAMP_AT
## are written into the shader as constants, and the tests read them back out of its source).

## The ramp's stops: the picture's lightness (Rec. 709 luma of its sRGB values, 0 to 1) and the theme's shade there.
const RAMP_AT := [0.0, 0.07, 0.2, 0.42, 0.75, 1.0]
const RAMP_DARK := ["darker_background", "background", "lighter_background", "muted", "foreground", "bright_foreground"]
const RAMP_LIGHT := ["background", "dark_background", "darker_background", "muted", "foreground", "bright_foreground"]
## The hue wheel, in degrees ascending (wrapping past 360 to the first): each stop's hue and the theme colour it takes.
## 20 rm -rf's ember and the signs' amber-orange; 42 the zombie's amber; 60 yellow; 85 ping's lime; 130 the Matrix's
## green; 160 the player's mint; 178 the player's teal; 200 white ICE's glacier; 228 grep's cobalt; 265 SIGTERM's
## violet; 300 the fork bomb's magenta; 325 the runaway's hot magenta; 350 rogue.d's crimson and hostile red.
const HUE_AT := [20.0, 42.0, 60.0, 85.0, 130.0, 160.0, 178.0, 200.0, 228.0, 265.0, 300.0, 325.0, 350.0]
const HUE_KEYS := ["orange", "yellow", "bright_yellow", "bright_green", "green", "bright_cyan", "cyan", "accent", "blue", "magenta", "bright_magenta", "bright_magenta", "red"]
## How coloured a source must be to take its hue's colour: none below SAT_FROM of chroma (the largest channel less the smallest), all past SAT_TO.
const SAT_FROM := 0.06
const SAT_TO := 0.4
## In a light theme, how much of the theme's colour a source of full brightness lays on the paper.
const INK := 1.15
## In a dark one, the most a theme's colour is lifted to meet a bright source (a neon edge stays neon, and a muted theme's
## red stays its own, never pushed to a bright pink).
const LIFT_MOST := 1.15

## The palette it is made from, and what it gives the shader.
var palette: OpenerPalette = null
var light := false
var ramp: Array[Color] = []
var hues: Array[Color] = []
var accent := Color.WHITE
var background := Color.BLACK
var foreground := Color.WHITE


static func of(p: OpenerPalette) -> ThemeLook:
	var look := ThemeLook.new()
	look.palette = p
	look.light = p.mode == "light"
	look.background = p.color("background")
	look.foreground = p.color("foreground")
	look.accent = p.color("accent")
	var keys: Array = RAMP_LIGHT if look.light else RAMP_DARK
	var shades: Array[Color] = []
	for key in keys:
		shades.append(p.color(key))
	# Kept in order of lightness whatever a theme says (a real theme's shades can be out of order): darkest first in a dark
	# theme, lightest first in a light one, so the ramp never turns back on itself.
	shades.sort_custom(func(a: Color, b: Color) -> bool: return (luma(a) > luma(b)) if look.light else (luma(a) < luma(b)))
	look.ramp = shades
	for key in HUE_KEYS:
		look.hues.append(p.color(key))
	return look


## Rec. 709 luma of `c`'s sRGB values: the grade's lightness.
static func luma(c: Color) -> float:
	return 0.2126 * c.r + 0.7152 * c.g + 0.0722 * c.b


## The hue of `c` in degrees (0 to 360), 0 for a grey.
static func hue_of(c: Color) -> float:
	var hi := maxf(c.r, maxf(c.g, c.b))
	var lo := minf(c.r, minf(c.g, c.b))
	var d := hi - lo
	if d <= 0.00001:
		return 0.0
	var h := 0.0
	if hi == c.r:
		h = fposmod((c.g - c.b) / d, 6.0)
	elif hi == c.g:
		h = (c.b - c.r) / d + 2.0
	else:
		h = (c.r - c.g) / d + 4.0
	return h * 60.0


## The ramp's shade at lightness `l`.
func ramp_at(l: float) -> Color:
	l = clampf(l, 0.0, 1.0)
	for i in range(1, RAMP_AT.size()):
		if l <= RAMP_AT[i]:
			var u: float = (l - RAMP_AT[i - 1]) / maxf(RAMP_AT[i] - RAMP_AT[i - 1], 0.00001)
			return ramp[i - 1].lerp(ramp[i], u)
	return ramp[ramp.size() - 1]


## The theme's colour for hue `h` (degrees): between the two stops either side, by where it falls between them.
func hue_target(h: float) -> Color:
	h = fposmod(h, 360.0)
	var n := HUE_AT.size()
	for i in n:
		var a: float = HUE_AT[i]
		var b: float = HUE_AT[(i + 1) % n] + (360.0 if i == n - 1 else 0.0)
		var hh := h + (360.0 if i == n - 1 and h < a else 0.0)
		if hh >= a and hh < b:
			return hues[i].lerp(hues[(i + 1) % n], (hh - a) / (b - a))
	return hues[0]


## The grade of colour `c` (sRGB, 0 to 1): what the shader makes of it in this theme.
func grade(c: Color) -> Color:
	var l := luma(c)
	var v := maxf(c.r, maxf(c.g, c.b))
	var chroma := v - minf(c.r, minf(c.g, c.b))
	var sat := smoothstep(SAT_FROM, SAT_TO, chroma)
	var base := ramp_at(l)
	var target := hue_target(hue_of(c))
	var tint: Color
	if light:
		tint = background.lerp(target, clampf(v * INK, 0.0, 1.0))
	else:
		var top := maxf(target.r, maxf(target.g, target.b))
		tint = target * minf(v / maxf(top, 0.01), LIFT_MOST)
	var out := base.lerp(tint, sat)
	out.a = 1.0
	return out


## The shader's ramp, as vec4s.
func ramp_vectors() -> PackedVector4Array:
	var out := PackedVector4Array()
	for c in ramp:
		out.append(Vector4(c.r, c.g, c.b, 1.0))
	return out


## The shader's hue wheel, as vec4s.
func hue_vectors() -> PackedVector4Array:
	var out := PackedVector4Array()
	for c in hues:
		out.append(Vector4(c.r, c.g, c.b, 1.0))
	return out


## The 16 colours a terminal's colour test shows (the eight and their brights): the HUD's swatch strip, and a
## palette-only daemon's cells.
func swatches() -> Array[Color]:
	var out: Array[Color] = []
	for key in ["background", "red", "green", "yellow", "blue", "magenta", "cyan", "foreground", "muted", "bright_red", "bright_green", "bright_yellow", "bright_blue", "bright_magenta", "bright_cyan", "bright_foreground"]:
		out.append(palette.color(key))
	return out
