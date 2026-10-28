extends RefCounted
## The code-rain vision meter (C21): seconds of vision left, from 0 to the tuning's meter_s,
## whether vision is on, and the rest left before it refills. Pure bookkeeping by the numbers
## in resources/code_rain_vision.tres, no nodes; scripts/abilities/code_rain_vision.gd keeps
## one for its player. Only this machine keeps it: nothing about it goes over the wire.
##
## Rules: a start needs at least start_share of the meter. While on, the meter drains one
## second per real second, and vision ends by itself when it is empty. Once off it rests
## rest_s, then refills from empty to full over refill_s; it does not refill while its player
## is derezzed. Turning vision off, a death and a respawn leave the meter as it was.

const Tuning = preload("res://scripts/abilities/code_rain_vision_tuning.gd")

## Below the start's share by less than this still starts: float sums of refills.
const EPS := 0.0001

var tuning: Tuning
## Seconds of vision left.
var meter := 0.0
## True while vision is on.
var on := false
## Seconds of rest left before the meter refills.
var rest_left := 0.0


func _init(vision_tuning: Tuning) -> void:
	tuning = vision_tuning
	meter = tuning.meter_s


func full() -> float:
	return tuning.meter_s


## How full the meter is, from 0 to 1.
func share() -> float:
	return clampf(meter / tuning.meter_s, 0.0, 1.0)


## Seconds of meter a start needs.
func start_needed() -> float:
	return tuning.meter_s * tuning.start_share


## True when vision may start now.
func can_start() -> bool:
	return not on and meter >= start_needed() - EPS


## Starts vision; false when it is already on or the meter is below the start's share.
func start() -> bool:
	if not can_start():
		return false
	on = true
	return true


## Ends vision, the meter as it is, and the rest before a refill begins; false when it was
## not on.
func stop() -> bool:
	if not on:
		return false
	on = false
	rest_left = tuning.rest_s
	return true


## Moves the meter on by `seconds` of real time: drained while on, refilled after its rest
## while off (unless `refilling` is false: its player is derezzed). True when it ran out just
## now and vision ended.
func tick(seconds: float, refilling: bool = true) -> bool:
	if not is_finite(seconds) or seconds <= 0.0:
		return false
	if on:
		meter = maxf(meter - seconds, 0.0)
		if meter <= EPS:
			meter = 0.0  # float dust from summing frames counts as empty
			stop()
			return true
		return false
	if not refilling:
		return false
	var resting := minf(rest_left, seconds)
	rest_left = 0.0 if rest_left - resting <= EPS else rest_left - resting
	var left := seconds - resting
	if left > 0.0:
		meter = minf(meter + left * tuning.meter_s / tuning.refill_s, tuning.meter_s)
	return false
