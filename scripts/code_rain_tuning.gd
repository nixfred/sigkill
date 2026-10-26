class_name CodeRainTuning
extends Resource
## Every number that shapes the Matrix code rain on the arena walls: how far from an enemy
## it reaches, how it fades in and out, and how the glyph streams look.
## The default instance is resources/code_rain.tres. scripts/code_rain_driver.gd reads
## only from this resource and pushes it into shaders/code_rain.gdshader. The two colours
## default to the palette's Matrix register in scripts/palette.gd.
## Units are metres, seconds and glyphs.

const Palette = preload("res://scripts/palette.gd")

@export_group("Reach")
## Distance from an enemy, in metres, at which its rain has faded to nothing.
@export var falloff_radius: float = 8.0
## Rain brightness on a wall with no enemy near, from 0 to 1. 0 keeps the walls clean Tron.
@export_range(0.0, 1.0) var min_intensity: float = 0.0
## Rain brightness on a wall right at an enemy, from 0 to 1.
@export_range(0.0, 1.0) var max_intensity: float = 1.0
## Most enemies the walls react to at once, the nearest ones to the player. At most 8,
## the size of the shader's enemy array.
@export_range(1, 8) var max_enemies_sampled: int = 8

@export_group("Fade")
## How fast an enemy's rain appears once it is alive, in full intensities per second.
@export var fade_in_rate: float = 2.0
## How fast an enemy's rain goes once it derezzes, in full intensities per second.
@export var fade_out_rate: float = 1.0

@export_group("Glyphs")
## Share of glyph columns that carry a stream, from 0 to 1.
@export_range(0.0, 1.0) var column_density: float = 0.6
## Width and height of one glyph cell, in metres.
@export var glyph_size: float = 0.25
## Slowest stream, in glyphs per second.
@export var fall_speed_min: float = 3.0
## Fastest stream, in glyphs per second.
@export var fall_speed_max: float = 9.0
## Glyphs in the fading tail behind each stream's bright leading glyph.
@export var tail_length: float = 12.0
## How often a glyph changes shape, in changes per second.
@export var flicker_rate: float = 6.0
## Brightness of the rain. Above 1 makes the leading glyphs bloom.
@export var rain_energy: float = 3.0

@export_group("Colours")
## The bright leading glyph of each stream.
@export var head_color: Color = Palette.MATRIX_HEAD
## The fading tail behind it.
@export var tail_color: Color = Palette.MATRIX_GREEN

## Size of the enemy array in shaders/code_rain.gdshader. max_enemies_sampled never exceeds it.
const MAX_ENEMIES := 8
## Float fields that must be finite and 0 or more.
const NON_NEGATIVE := [
	"falloff_radius", "min_intensity", "max_intensity", "fade_in_rate", "fade_out_rate",
	"column_density", "glyph_size", "fall_speed_min", "fall_speed_max", "tail_length",
	"flicker_rate", "rain_energy",
]


## Everything wrong with these values, or empty when they are safe to use.
func problems() -> PackedStringArray:
	var out := PackedStringArray()
	for field in NON_NEGATIVE:
		var value: float = get(field)
		if not is_finite(value) or value < 0.0:
			out.append("%s must be a finite number of 0 or more, got %s" % [field, value])
	if falloff_radius <= 0.0:
		out.append("falloff_radius must be above 0")
	if min_intensity > 1.0 or max_intensity > 1.0 or min_intensity > max_intensity:
		out.append("min_intensity and max_intensity must be between 0 and 1, the minimum not above the maximum")
	if max_enemies_sampled < 1 or max_enemies_sampled > MAX_ENEMIES:
		out.append("max_enemies_sampled must be between 1 and %d" % MAX_ENEMIES)
	if fade_in_rate <= 0.0 or fade_out_rate <= 0.0:
		out.append("fade_in_rate and fade_out_rate must be above 0, or the rain never settles")
	if column_density > 1.0:
		out.append("column_density must be between 0 and 1")
	if glyph_size <= 0.0:
		out.append("glyph_size must be above 0")
	if fall_speed_min > fall_speed_max:
		out.append("fall_speed_min must not exceed fall_speed_max")
	if tail_length < 1.0:
		out.append("tail_length must be at least 1 glyph")
	return out
