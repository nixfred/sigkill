extends RefCounted
## The SIGSTOP meter (C18): seconds of slow-mo left, from 0 to the tuning's meter_s, and
## whether SIGSTOP is on. Pure bookkeeping by the numbers in resources/sigstop.tres, no
## nodes: the player's own controller (scripts/abilities/sigstop.gd) keeps one, and in a
## match the host keeps one per player (scripts/net/combat.gd), whose word decides.
##
## Rules: a start needs at least start_share of the meter. While on, the meter drains one
## second per real second, and SIGSTOP ends by itself when it is empty. While off it refills
## from empty to full over refill_s, except while its player is derezzed. A death empties
## it and ends SIGSTOP; a new round fills it.

const Tuning = preload("res://scripts/abilities/sigstop_tuning.gd")

## Below the start's share by less than this still starts: float sums of refills.
const EPS := 0.0001

var tuning: Tuning
## Seconds of slow-mo left.
var meter := 0.0
## True while SIGSTOP runs.
var on := false


func _init(sigstop_tuning: Tuning) -> void:
	tuning = sigstop_tuning
	meter = tuning.meter_s


func full() -> float:
	return tuning.meter_s


## How full the meter is, from 0 to 1.
func share() -> float:
	return clampf(meter / tuning.meter_s, 0.0, 1.0)


## Seconds of meter a start needs.
func start_needed() -> float:
	return tuning.meter_s * tuning.start_share


## True when SIGSTOP may start now.
func can_start() -> bool:
	return not on and meter >= start_needed() - EPS


## Starts SIGSTOP; false when it is already on or the meter is below the start's share.
func start() -> bool:
	if not can_start():
		return false
	on = true
	return true


## Ends SIGSTOP (SIGCONT); false when it was not on.
func stop() -> bool:
	if not on:
		return false
	on = false
	return true


## Moves the meter on by `seconds` of real time: drained while on, refilled while off
## (unless `refilling` is false). True when it ran out just now and SIGSTOP ended.
func tick(seconds: float, refilling: bool = true) -> bool:
	if not is_finite(seconds) or seconds <= 0.0:
		return false
	if on:
		meter = maxf(meter - seconds, 0.0)
		if meter <= 0.0:
			on = false
			return true
		return false
	if refilling:
		meter = minf(meter + seconds * tuning.meter_s / tuning.refill_s, tuning.meter_s)
	return false


## A death: the meter empty and SIGSTOP off.
func empty() -> void:
	meter = 0.0
	on = false


## A new round: the meter full.
func fill() -> void:
	meter = tuning.meter_s


## Takes the host's word in a match: on or off, and the meter it counts, kept in range.
func take(host_on: bool, host_meter: float) -> void:
	on = host_on
	meter = clampf(host_meter, 0.0, tuning.meter_s) if is_finite(host_meter) else meter
