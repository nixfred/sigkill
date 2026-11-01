class_name ThemeBook
extends RefCounted
## Theme-shift levels (W3, PRD 5.5: "theme-shift levels using Omarchy themes"): the themes a run plays through, in order,
## and the world each one is. Every theme is a palette (the opener's own demo palettes, scripts/opener/opener_palette.gd:
## colour values taken from open terminal themes Omarchy ships, credited in CREDITS.md) and a district of its own, made at
## play from C36's ruins kit (a RuinsSet built here, never a .tres): its register, its weather, its size, how tall its
## towers stand and the set piece it is built round. The palette recolours the whole frame (scripts/themes/theme_grade.gd);
## the district makes the theme its own place, not the same scene under a hue slider.
##
##   night   Tokyo Night         a rain-soaked megacity: the ruins' cyberpunk register, towers 2.3 times their height
##   ember   Gruvbox Material    a warm old grid going to rust toward its far end (M5's decay), stepped down twice
##   frost   Nord                a frozen hall: the Tron register pristine, nothing broken, an open plaza in the middle
##   forest  Everforest          a canopy: the Matrix register, its plaza a grove of code walls rewriting themselves
##   mocha   Catppuccin Mocha    a drowned dream: the rain over black water holding the neon (M6's drowned plain)
##   latte   Catppuccin Latte    daylight: the one light theme, the void turned to paper and every light to ink
##   yours   your Omarchy theme  (the opt-in real layer only) a plain grid in the player's own colours
##
## Fiction only: every word on a sign or a monolith is the game's own. The real layer's theme brings its colours and its
## mode and nothing else, so its level is called "your theme" (its name is never read).

## The run's built-in themes, in the order they are played. Each id is an OpenerPalette demo palette's.
const ORDER := ["night", "ember", "frost", "forest", "mocha", "latte"]
## The real layer's theme: added after the built-in ones when the player's own is read.
const YOURS := "yours"
const MADE_PREFIX := "fs_theme_"

## Each theme's world. name: what the HUD calls it; slug: what `export THEME=` types; register, cells, the dice and tall:
## its district (RuinsSet's fields); set: its set piece; words and folders: its signs and monoliths; seed: its layout's.
const WORLDS := {
	"night": {
		"name": "Tokyo Night", "slug": "tokyo-night", "register": "cyberpunk", "cells": Vector2i(11, 16), "seed": 7101,
		"blocks": 8, "holes": 2, "cover": 16, "towers": 52, "giants": 36, "cables": 30, "signs": 22, "tall": 2.3,
		"words": ["NIGHT SHIFT", "LAST TRAIN", "NO SIGNAL", "OPEN 24H", "STORM WARNING", "NEON"],
		"folders": ["rain", "alley", "arcade", "metro"], "set": "",
		"motto": "a city that never logs off",
	},
	"ember": {
		"name": "Gruvbox Material", "slug": "gruvbox-material", "register": "tron", "cells": Vector2i(11, 18), "seed": 7202,
		"blocks": 9, "holes": 2, "cover": 18, "towers": 36, "giants": 22, "cables": 16, "signs": 10, "tall": 1.15,
		"words": ["WARM BOOT", "OLD IRON", "RUST", "DUST", "RETRO"],
		"folders": ["furnace", "forge", "kiln", "anvil"], "set": "decay", "terraces": 2,
		"motto": "warm iron going to rust",
	},
	"frost": {
		"name": "Nord", "slug": "nord", "register": "tron", "cells": Vector2i(13, 15), "seed": 7303,
		"blocks": 10, "holes": 0, "cover": 0, "towers": 40, "giants": 30, "cables": 0, "signs": 8, "tall": 1.6,
		"words": ["POLAR NIGHT", "SNOW STORM", "ARCTIC", "FROST", "AURORA"],
		"folders": ["glacier", "fjord", "tundra", "floe"], "set": "pristine", "clearing": 2,
		"motto": "a clean hall under ice",
	},
	"forest": {
		"name": "Everforest", "slug": "everforest", "register": "matrix", "cells": Vector2i(11, 15), "seed": 7404,
		"blocks": 6, "holes": 1, "cover": 12, "towers": 44, "giants": 34, "cables": 20, "signs": 8, "tall": 2.6,
		"words": ["CANOPY", "DEEP ROOT", "MOSS", "LICHEN", "UNDERGROWTH"],
		"folders": ["grove", "thicket", "glade", "roots"], "set": "field",
		"code": "grow()|root --deep|branch++|while leaf|photosynth|fern.sh|moss -r",
		"motto": "code grows wild here",
	},
	"mocha": {
		"name": "Catppuccin Mocha", "slug": "catppuccin", "register": "cyberpunk", "cells": Vector2i(12, 16), "seed": 7505,
		"blocks": 7, "holes": 3, "cover": 14, "towers": 46, "giants": 30, "cables": 24, "signs": 16, "tall": 1.7,
		"words": ["LATE CAFE", "SOFT GLOW", "MOCHA", "PASTEL", "STAY A WHILE"],
		"folders": ["cafe", "lantern", "harbour", "quay"], "set": "water", "water": 3.0,
		"motto": "pastel neon over black water",
	},
	"latte": {
		"name": "Catppuccin Latte", "slug": "catppuccin-latte", "register": "tron", "cells": Vector2i(12, 14), "seed": 7606,
		"blocks": 8, "holes": 1, "cover": 16, "towers": 34, "giants": 22, "cables": 10, "signs": 10, "tall": 1.3,
		"words": ["DAYLIGHT", "MORNING", "FRESH START", "LATTE", "GOOD DAY"],
		"folders": ["sunroom", "porch", "garden", "studio"], "set": "",
		"motto": "the machine in daylight",
	},
	"yours": {
		"name": "your theme", "slug": "yours", "register": "tron", "cells": Vector2i(11, 15), "seed": 7707,
		"blocks": 8, "holes": 1, "cover": 14, "towers": 40, "giants": 26, "cables": 14, "signs": 10, "tall": 1.5,
		"words": ["YOUR THEME", "HOME", "YOUR COLOURS", "WELCOME"],
		"folders": ["home", "desk", "shelf", "lamp"], "set": "",
		"motto": "your own colours",
	},
}


## The run's themes for a layer: the built-in six, and (real) the player's own after them.
static func run_ids(with_yours: bool) -> PackedStringArray:
	var out := PackedStringArray(ORDER)
	if with_yours:
		out.append(YOURS)
	return out


## What theme `id` is called on screen ("Tokyo Night").
static func name_of(id: String) -> String:
	return str(WORLDS.get(id, WORLDS[YOURS])["name"])


## What `export THEME=` types for theme `id`.
static func slug_of(id: String) -> String:
	return str(WORLDS.get(id, WORLDS[YOURS])["slug"])


## The palette theme `id` plays in: a built-in one's demo palette; the player's own from the real layer (`yours`, null
## when there is none: the caller falls back to the default demo palette).
static func palette_of(id: String, yours: OpenerPalette = null) -> OpenerPalette:
	if id == YOURS:
		return yours if yours != null else OpenerPalette.named(OpenerPalette.DEFAULT_ID)
	return OpenerPalette.named(id)


## The district id theme `id` stands in.
static func set_id(id: String) -> String:
	return MADE_PREFIX + id


## Theme `id`'s district: a RuinsSet made at play from its world above (checked by RuinsSet.problems() in the tests).
static func set_for(id: String) -> RuinsSet:
	var w: Dictionary = WORLDS.get(id, WORLDS[YOURS])
	var s := RuinsSet.new()
	s.id = set_id(id if WORLDS.has(id) else YOURS)
	s.title = "the %s theme" % str(w["name"])
	s.seed = int(w["seed"])
	s.register = str(w["register"])
	s.cells = w["cells"]
	s.blocks = int(w["blocks"])
	s.holes = int(w["holes"])
	s.cover = int(w["cover"])
	s.towers = int(w["towers"])
	s.giants = int(w["giants"])
	s.cables = int(w["cables"])
	s.signs = int(w["signs"])
	s.tall = float(w["tall"])
	s.words = PackedStringArray(w["words"])
	s.folders = PackedStringArray(w["folders"])
	match str(w["set"]):
		"decay":
			s.decay = "exit"
		"pristine":
			s.pristine = true
		"field":
			s.field = "plaza"
			s.field_cells = 5
			s.field_code = str(w["code"])
		"water":
			s.water = float(w["water"])
			s.palette = "abyss"
	s.terraces = int(w.get("terraces", 0))
	s.clearing = int(w.get("clearing", 0))
	return s
