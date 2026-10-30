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
## Omarchy ships (inspired_by; CREDITS.md names them). "night" is the default.

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


## The demo palette `palette_id` (one of IDS), or the default for anything else.
static func named(palette_id: String) -> OpenerPalette:
	if not IDS.has(palette_id):
		palette_id = DEFAULT_ID
	return load(DIR + palette_id + ".tres") as OpenerPalette
