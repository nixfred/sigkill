class_name CodeRainVisionTuning
extends Resource
## Every number of code-rain vision (C21, PRD 5.3: "see enemies through walls as glyphs,
## drains fast"): how long a full meter lasts in use, how fast and after what rest it comes
## back, how much of it a start needs; how far it sees; how the world dims toward green and
## how the glyph silhouettes look. The default instance is resources/code_rain_vision.tres;
## scripts/abilities/code_rain_vision_meter.gd keeps the meter by these numbers and
## scripts/abilities/code_rain_vision.gd runs the ability. The silhouettes' glyphs (size,
## speeds, tail, flicker, greens) are the walls' own, from resources/code_rain.tres. Units
## are real seconds, metres and shares. Purely local and visual: nothing is sent anywhere.

@export_group("Meter")
## Seconds of vision a full meter holds.
@export var meter_s: float = 3.0
## Seconds from empty to full once it is resting.
@export var refill_s: float = 12.0
## Seconds off before the meter starts to refill.
@export var rest_s: float = 1.0
## The share of the meter a start needs: a quarter.
@export var start_share: float = 0.25

@export_group("Sight")
## How far away an enemy body still shows, in metres.
@export var range_m: float = 40.0

@export_group("Look")
## The world on your screen while it is on: each colour is multiplied by this.
@export var tint: Color = Color(0.45, 0.8, 0.5)
## How far toward the tint the picture goes at full strength, normally and with the comfort
## settings (screen shake or motion blur turned off): calmer.
@export var strength: float = 1.0
@export var calm_strength: float = 0.5
## Seconds the look takes to come up or go away: never a flash.
@export var fade_s: float = 0.2
## Each silhouette's capsule, sized to hold a target dummy or a player.
@export var marker_radius_m: float = 0.6
@export var marker_height_m: float = 1.9
## How bright the silhouettes' glyphs glow.
@export var marker_energy: float = 3.0

## The most silhouettes shown at once: the nearest enemies win.
const MARKERS_LAST := 16
const METER_FIRST_S := 0.5
const METER_LAST_S := 30.0
const REFILL_FIRST_S := 1.0
const REFILL_LAST_S := 600.0
const REST_LAST_S := 10.0
const RANGE_LAST_M := 200.0
const FADE_LAST_S := 2.0
const MARKER_LAST_M := 5.0
const ENERGY_LAST := 10.0


## Everything wrong with these values, or empty when they are safe to use.
func problems() -> PackedStringArray:
	var out := PackedStringArray()
	if not is_finite(meter_s) or meter_s < METER_FIRST_S or meter_s > METER_LAST_S:
		out.append("meter_s must be between %s and %s" % [METER_FIRST_S, METER_LAST_S])
	if not is_finite(refill_s) or refill_s < REFILL_FIRST_S or refill_s > REFILL_LAST_S:
		out.append("refill_s must be between %s and %s" % [REFILL_FIRST_S, REFILL_LAST_S])
	if not is_finite(rest_s) or rest_s < 0.0 or rest_s > REST_LAST_S:
		out.append("rest_s must be between 0 and %s" % REST_LAST_S)
	if not is_finite(start_share) or start_share <= 0.0 or start_share > 1.0:
		out.append("start_share must be above 0 and at most 1")
	if not is_finite(range_m) or range_m <= 0.0 or range_m > RANGE_LAST_M:
		out.append("range_m must be above 0 and at most %s" % RANGE_LAST_M)
	for channel in [tint.r, tint.g, tint.b]:
		if not is_finite(channel) or channel < 0.0 or channel > 1.0:
			out.append("tint must have every channel between 0 and 1")
			break
	for pair in [["strength", strength], ["calm_strength", calm_strength]]:
		if not is_finite(pair[1]) or pair[1] < 0.0 or pair[1] > 1.0:
			out.append("%s must be between 0 and 1" % pair[0])
	if is_finite(calm_strength) and is_finite(strength) and calm_strength > strength:
		out.append("calm_strength must be at most strength")
	if not is_finite(fade_s) or fade_s < 0.0 or fade_s > FADE_LAST_S:
		out.append("fade_s must be between 0 and %s" % FADE_LAST_S)
	for pair in [["marker_radius_m", marker_radius_m], ["marker_height_m", marker_height_m]]:
		if not is_finite(pair[1]) or pair[1] <= 0.0 or pair[1] > MARKER_LAST_M:
			out.append("%s must be above 0 and at most %s" % [pair[0], MARKER_LAST_M])
	if is_finite(marker_radius_m) and is_finite(marker_height_m) and marker_height_m < marker_radius_m * 2.0:
		out.append("marker_height_m must be at least twice marker_radius_m")
	if not is_finite(marker_energy) or marker_energy <= 0.0 or marker_energy > ENERGY_LAST:
		out.append("marker_energy must be above 0 and at most %s" % ENERGY_LAST)
	return out
