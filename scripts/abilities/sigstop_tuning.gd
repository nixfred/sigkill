class_name SigstopTuning
extends Resource
## Every number of SIGSTOP bullet time (C18, PRD 5.3): how much slow-mo a full meter holds,
## how fast it comes back and how much of it a start needs; how slow the world runs solo,
## how fast the player still feels and how long SIGCONT eases back; and the look. The
## default instance is resources/sigstop.tres. scripts/abilities/sigstop_meter.gd keeps the
## meter by these numbers, on the player's side and on the host's alike, and
## scripts/abilities/sigstop.gd runs the slow-mo. Units are real seconds and shares: the
## meter never slows with the world. Cosmetic fiction: nothing real is stopped or continued.

@export_group("Meter")
## Seconds of slow-mo a full meter holds.
@export var meter_s: float = 4.0
## Seconds from empty to full while SIGSTOP is not in use.
@export var refill_s: float = 20.0
## The share of the meter a start needs: a quarter, 1 s of the full 4.
@export var start_share: float = 0.25

@export_group("Slow-mo, solo")
## How fast the world runs during SIGSTOP alone in the arena (the engine's time scale).
## Never in a match: there nothing global slows, for anyone.
@export var world_scale: float = 0.3
## How fast the player still moves, looks, aims and fires meanwhile, as a share of full
## speed in real time.
@export var player_rate: float = 0.9
## Seconds SIGCONT takes to ease the world back to full speed.
@export var ease_s: float = 0.25

@export_group("Look")
## How far the picture goes grey at full effect, 0 to 1.
@export var desaturate: float = 0.7
## How far it then shifts to the theme's teal, 0 to 1.
@export var tint: float = 0.3
## How far the motion trails smear the picture toward the middle, as a share of the screen.
@export var trail: float = 0.04
## Every sound's playback speed at full effect: below 1 pitches it down.
@export var audio_pitch: float = 0.7

const METER_FIRST_S := 0.5
const METER_LAST_S := 30.0
const REFILL_FIRST_S := 1.0
const REFILL_LAST_S := 600.0
const WORLD_FIRST := 0.05
const RATE_FIRST := 0.5
const EASE_LAST_S := 2.0
const TRAIL_LAST := 0.2
const PITCH_FIRST := 0.25


## Everything wrong with these values, or empty when they are safe to use.
func problems() -> PackedStringArray:
	var out := PackedStringArray()
	if not is_finite(meter_s) or meter_s < METER_FIRST_S or meter_s > METER_LAST_S:
		out.append("meter_s must be between %s and %s" % [METER_FIRST_S, METER_LAST_S])
	if not is_finite(refill_s) or refill_s < REFILL_FIRST_S or refill_s > REFILL_LAST_S:
		out.append("refill_s must be between %s and %s" % [REFILL_FIRST_S, REFILL_LAST_S])
	if not is_finite(start_share) or start_share <= 0.0 or start_share > 1.0:
		out.append("start_share must be above 0 and at most 1")
	if not is_finite(world_scale) or world_scale < WORLD_FIRST or world_scale >= 1.0:
		out.append("world_scale must be at least %s and below 1" % WORLD_FIRST)
	if not is_finite(player_rate) or player_rate < RATE_FIRST or player_rate > 1.0:
		out.append("player_rate must be between %s and 1" % RATE_FIRST)
	if not is_finite(ease_s) or ease_s < 0.0 or ease_s > EASE_LAST_S:
		out.append("ease_s must be between 0 and %s" % EASE_LAST_S)
	for pair in [["desaturate", desaturate], ["tint", tint]]:
		if not is_finite(pair[1]) or pair[1] < 0.0 or pair[1] > 1.0:
			out.append("%s must be between 0 and 1" % pair[0])
	if not is_finite(trail) or trail < 0.0 or trail > TRAIL_LAST:
		out.append("trail must be between 0 and %s" % TRAIL_LAST)
	if not is_finite(audio_pitch) or audio_pitch < PITCH_FIRST or audio_pitch > 1.0:
		out.append("audio_pitch must be between %s and 1" % PITCH_FIRST)
	return out
