class_name OpenerPalette
extends Resource
## A terminal palette for the opener's fake terminal (C38, PRD 5.7: "a FAKE terminal rendered by the game in the
## player's active Omarchy theme colors"). The colours are kept under Omarchy's own names for them, the keys of a
## theme's colors.toml (KEYS), as "#rrggbb" text, so a real theme (C39) maps onto this shape key for key, and a
## theme missing a key still draws: color() falls back along FALLBACK to the background or the foreground.
## Colours only: no artwork, no font, nothing else of a theme.
##
## The terminal uses them as Omarchy's own terminal does: the background and the foreground, the cursor in
## bright_foreground over the background, the window's border in the accent, the desktop round the window in
## darker_background, and the eight named colours for what is typed in colour (the prompt's green and blue, a
## folder's blue, the uptime's yellow).
##
## The demo palettes are resources/opener/<id>.tres (IDS), each taking its colours from an open terminal theme
## Omarchy ships (inspired_by; CREDITS.md names them). "night" is the default. A player's own theme (C39) is read
## into this same shape by scripts/opener/theme_colors.gd.
##
## Readable on screen, whichever palette (C39): the opener draws every palette through readable(), which pulls a
## coloured text colour (the prompt's green and blue, the folders' blue, the uptime's yellow) or the cursor that
## is under SHAPE_CONTRAST against the background toward the foreground until it reaches it; the hue stays, and
## a palette that needs nothing comes back as itself.

## Omarchy's colour names (a theme's colors.toml), in its order.
const KEYS := ["accent", "selection", "muted", "background", "dark_background", "darker_background", "lighter_background", "foreground", "dark_foreground", "light_foreground", "bright_foreground", "red", "yellow", "orange", "green", "cyan", "blue", "magenta", "bright_red", "bright_yellow", "bright_green", "bright_cyan", "bright_blue", "bright_magenta"]
## A key a theme leaves out reads the one it names here, and so on down; every chain ends at "background" or
## "foreground".
const FALLBACK := {
	"accent": "blue", "selection": "lighter_background", "muted": "dark_foreground",
	"dark_background": "background", "darker_background": "dark_background", "lighter_background": "background",
	"dark_foreground": "foreground", "light_foreground": "foreground", "bright_foreground": "foreground",
	"red": "foreground", "yellow": "foreground", "orange": "yellow", "green": "foreground", "cyan": "foreground",
	"blue": "foreground", "magenta": "foreground",
	"bright_red": "red", "bright_yellow": "yellow", "bright_green": "green", "bright_cyan": "cyan",
	"bright_blue": "blue", "bright_magenta": "magenta",
}
## What the two ends of every chain are when a theme has neither.
const LAST_BACKGROUND := Color(0.07, 0.07, 0.09)
const LAST_FOREGROUND := Color(0.8, 0.8, 0.8)
## The demo palettes shipped, by id, and the one the opener uses unless told otherwise.
const IDS := ["night", "mocha", "ember", "frost", "forest", "latte"]
const DEFAULT_ID := "night"
const DIR := "res://resources/opener/"
## WCAG's least contrast for body text, and for large text and shapes (the bold prompt, the cursor block).
const TEXT_CONTRAST := 4.5
const SHAPE_CONTRAST := 3.0
## The colours the terminal draws text or the cursor in, besides the foreground.
const DRAWN := ["green", "blue", "yellow", "bright_foreground"]
## How far each step of readable() pulls a colour toward the foreground.
const PULL_STEP := 0.05

## Its short name ("night").
@export var id := ""
## The open theme its colours come from ("Tokyo Night").
@export var inspired_by := ""
## "dark" or "light", as the theme says.
@export var mode := "dark"
## Omarchy's colour names to "#rrggbb".
@export var colors: Dictionary[String, String] = {}


## The colour called `key` (one of KEYS), or what it falls back to.
func color(key: String) -> Color:
	var seen := 0
	while seen < KEYS.size():
		var text: String = colors.get(key, "")
		if text != "" and Color.html_is_valid(text):
			return Color.html(text)
		if not FALLBACK.has(key):
			break
		key = FALLBACK[key]
		seen += 1
	return LAST_BACKGROUND if key == "background" else LAST_FOREGROUND


## The terminal's cursor: bright_foreground, as Omarchy's own terminal draws it.
func cursor() -> Color:
	return color("bright_foreground")


## This palette with every colour of DRAWN at SHAPE_CONTRAST or more on the background (each one under it pulled
## toward the foreground, PULL_STEP at a time, until it reaches it); itself when none is under it.
func readable() -> OpenerPalette:
	var background := color("background")
	var foreground := color("foreground")
	var fixed := {}
	for key in DRAWN:
		var c := color(key)
		var k := 0.0
		while contrast(c, background) < SHAPE_CONTRAST and k < 1.0:
			k = minf(k + PULL_STEP, 1.0)
			c = color(key).lerp(foreground, k)
		if k > 0.0:
			fixed[key] = "#" + c.to_html(false)
	if fixed.is_empty():
		return self
	var copy := OpenerPalette.new()
	copy.id = id
	copy.inspired_by = inspired_by
	copy.mode = mode
	copy.colors = colors.duplicate()
	for key in fixed:
		copy.colors[key] = fixed[key]
	return copy


## WCAG's contrast ratio between two colours (1 to 21), from their relative luminance.
static func contrast(a: Color, b: Color) -> float:
	var la := luminance(a)
	var lb := luminance(b)
	return (maxf(la, lb) + 0.05) / (minf(la, lb) + 0.05)


## WCAG's relative luminance of a colour given in sRGB.
static func luminance(c: Color) -> float:
	var lin := c.srgb_to_linear()
	return 0.2126 * lin.r + 0.7152 * lin.g + 0.0722 * lin.b


## The demo palette `palette_id` (one of IDS), or the default for anything else.
static func named(palette_id: String) -> OpenerPalette:
	if not IDS.has(palette_id):
		palette_id = DEFAULT_ID
	return load(DIR + palette_id + ".tres") as OpenerPalette
