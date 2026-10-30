class_name ThemeColors
extends RefCounted
## A player's Omarchy theme read into the opener's palette shape (C39; PRD 5.7: "a FAKE terminal rendered by the
## game in the player's active Omarchy theme colors"). Text in, a palette out: this reads no file itself (the
## reader, scripts/opener/real_opener_data.gd, hands it the text of the active theme's colors.toml), keeps only
## colours, and makes them the shape OpenerPalette holds, key for key.
##
## Omarchy's own rules, as its colour resolver (omarchy-theme-color) applies them: a theme's canonical names
## (OpenerPalette.KEYS) first; then the older short names (bg, fg, dark_bg...), the ANSI names color0 to color15,
## purple for magenta; then the derived shades (dark_background 25% and darker_background 50% toward black from
## the background, each bright colour 20% toward white from its colour, orange from yellow). Its mode: the
## theme's "mode" (or older "theme_type"), else a light.mode file beside it, else light when its background is
## bright. Only "#rrggbb" values are colours; anything else in the file is ignored.
##
## Unreadable is unused: a theme whose foreground is under OpenerPalette.TEXT_CONTRAST (4.5:1) on its background,
## or that has no background or foreground at all, gives null, and the opener falls back to the default demo
## palette. Its coloured text is made readable as every palette's is (OpenerPalette.readable()).

## The id and the credit line a palette read from the player's theme carries.
const ID := "theme"
const INSPIRED_BY := "your Omarchy theme"
## The older short names (Omarchy's legacy palette names), by the canonical name each stands for.
const SHORT := {
	"background": "bg", "dark_background": "dark_bg", "darker_background": "darker_bg", "lighter_background": "lighter_bg",
	"foreground": "fg", "dark_foreground": "dark_fg", "light_foreground": "light_fg", "bright_foreground": "bright_fg",
}
## The ANSI names, by the canonical name each stands for.
const ANSI := {
	"red": "color1", "green": "color2", "yellow": "color3", "blue": "color4", "magenta": "color5", "cyan": "color6",
	"bright_red": "color9", "bright_green": "color10", "bright_yellow": "color11", "bright_blue": "color12",
	"bright_magenta": "color13", "bright_cyan": "color14",
}
## Each bright colour, from its colour, when the theme leaves it out.
const BRIGHT := ["red", "yellow", "green", "cyan", "blue", "magenta"]
const KEY_RULE := "^[A-Za-z0-9_-]+$"
const HEX_RULE := "^#?[0-9A-Fa-f]{6}$"
## The most lines read: a colors.toml is a few dozen.
const MOST_LINES := 400


## The palette in `text` (a colors.toml's), or null when it is not a usable one. `light_file`: whether a light.mode
## file stands beside it.
static func palette_from(text: String, light_file: bool) -> OpenerPalette:
	var raw := parse(text)
	var colours := resolve(raw)
	if not colours.has("background") or not colours.has("foreground"):
		return null
	var p := OpenerPalette.new()
	p.id = ID
	p.inspired_by = INSPIRED_BY
	p.mode = mode_of(raw, colours, light_file)
	var typed: Dictionary[String, String] = {}
	for key in colours:
		typed[key] = colours[key]
	p.colors = typed
	if OpenerPalette.contrast(p.color("foreground"), p.color("background")) < OpenerPalette.TEXT_CONTRAST:
		return null
	return p


## `text`'s key = value lines, as Omarchy's parser reads them: the key without quotes or spaces, the value between
## its quotes (an inline comment after them ignored) or trimmed; comments, sections and odd keys skipped. Colours
## (#rrggbb, lower case) and the mode words only; the rest is dropped.
static func parse(text: String) -> Dictionary:
	var out := {}
	var key_rule := RegEx.create_from_string(KEY_RULE)
	var hex_rule := RegEx.create_from_string(HEX_RULE)
	var lines := text.split("\n")
	for n in mini(lines.size(), MOST_LINES):
		var line := lines[n]
		var eq := line.find("=")
		if eq < 0:
			continue
		var key := line.left(eq).replace("\"", "").replace("'", "").strip_edges()
		if key == "" or key.begins_with("#") or key_rule.search(key) == null:
			continue
		var value := line.substr(eq + 1)
		var open := _first_quote(value)
		if open >= 0:
			var quote := value[open]
			var close := value.find(quote, open + 1)
			value = value.substr(open + 1, (close - open - 1) if close > open else -1)
		value = value.strip_edges()
		if key == "mode" or key == "theme_type":
			if value == "light" or value == "dark":
				out[key] = value
		elif hex_rule.search(value) != null:
			out[key] = ("#" + value.trim_prefix("#")).to_lower()
	return out


## The canonical colours (OpenerPalette.KEYS) from what a theme gives, by Omarchy's cascade; a key it cannot reach
## is left out (OpenerPalette.color() falls back for it).
static func resolve(raw: Dictionary) -> Dictionary:
	var c := {}
	for key in OpenerPalette.KEYS:
		if raw.has(key):
			c[key] = raw[key]
	for key in SHORT:
		_alias(c, key, raw, SHORT[key])
	_alias(c, "background", raw, "color0")
	_alias(c, "foreground", raw, "color7")
	for key in ANSI:
		_alias(c, key, raw, ANSI[key])
	_alias(c, "magenta", raw, "purple")
	_alias(c, "bright_magenta", raw, "bright_purple")
	_alias(c, "light_foreground", raw, "color7")
	_alias(c, "bright_foreground", raw, "color15")
	_alias(c, "lighter_background", raw, "color0")
	_alias(c, "dark_foreground", raw, "color8")
	_alias(c, "muted", raw, "color8")
	_alias(c, "selection", raw, "selection_background")
	_alias(c, "selection", raw, "color8")
	if c.has("background"):
		var bg := Color.html(c["background"])
		if not c.has("dark_background"):
			c["dark_background"] = _hex(bg.lerp(Color.BLACK, 0.25))
		if not c.has("darker_background"):
			c["darker_background"] = _hex(bg.lerp(Color.BLACK, 0.5))
	if not c.has("orange") and c.has("yellow"):
		c["orange"] = c["yellow"]
	for key in BRIGHT:
		if not c.has("bright_" + key) and c.has(key):
			c["bright_" + key] = _hex(Color.html(c[key]).lerp(Color.WHITE, 0.2))
	return c


## "light" or "dark": the theme's own word, else a light.mode file, else by its background's brightness (the sum of
## its channels over 382 of 765, Omarchy's test).
static func mode_of(raw: Dictionary, colours: Dictionary, light_file: bool) -> String:
	for key in ["mode", "theme_type"]:
		if raw.has(key):
			return raw[key]
	if light_file:
		return "light"
	if colours.has("background"):
		var bg := Color.html(colours["background"])
		if bg.r8 + bg.g8 + bg.b8 > 382:
			return "light"
	return "dark"


static func _alias(c: Dictionary, key: String, raw: Dictionary, from: String) -> void:
	if not c.has(key) and raw.has(from):
		c[key] = raw[from]


static func _hex(c: Color) -> String:
	return "#" + c.to_html(false)


static func _first_quote(value: String) -> int:
	var a := value.find("\"")
	var b := value.find("'")
	if a < 0:
		return b
	if b < 0:
		return a
	return mini(a, b)
