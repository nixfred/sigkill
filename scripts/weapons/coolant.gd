class_name Coolant
extends RefCounted
## chmod 000's coolant (C29): the freeze ray's ammo is not a magazine but a tank that empties while the
## beam runs and refills on its own. Pure bookkeeping by the freeze tuning, no nodes: the player's
## inventory keeps one for the freeze ray (scripts/weapons/inventory.gd) and a match's host keeps one per
## player by the same rules on its own clock (scripts/net/combat.gd), a little more lenient (slack), so
## the host is never stricter than an honest player's game.
##
## Rules: each beam tick spends its seconds of coolant. After the last tick the tank rests
## coolant_rest_s, then refills from empty to full over coolant_refill_s. A tank run dry vents: no beam
## until it has refilled to vent_share of full. A new life refills it at once.

## Below a share by less than this still counts: float sums of frames.
const EPS := 0.0001

var tuning: FreezeTuning
## Seconds of beam left in the tank.
var meter := 0.0
## True from running dry until it has refilled to vent_share.
var venting := false
## Seconds of rest left before the tank refills.
var rest_left := 0.0
## How much more lenient this keeper is: it refills (1 + slack) times as fast and vents out at (1 - slack)
## of the share. 0 for the player's own tank.
var slack := 0.0


func _init(freeze_tuning: FreezeTuning, leniency: float = 0.0) -> void:
	tuning = freeze_tuning
	slack = clampf(leniency, 0.0, 0.5)
	meter = tuning.coolant_s


func full() -> float:
	return tuning.coolant_s


## How full the tank is, from 0 to 1.
func share() -> float:
	return clampf(meter / tuning.coolant_s, 0.0, 1.0)


## True when a beam tick may go now: not venting and something left.
func ready() -> bool:
	return not venting and meter > EPS


## Spends a tick of `seconds` (what is left when less): the rest begins again; a tank run dry vents.
func spend(seconds: float) -> void:
	if not is_finite(seconds) or seconds <= 0.0:
		return
	meter = maxf(meter - seconds, 0.0)
	rest_left = tuning.coolant_rest_s * (1.0 - slack)
	if meter <= EPS:
		meter = 0.0
		venting = true


## Moves the tank on by `seconds`: its rest, then its refill; a venting tank stops venting at its share.
func tick(seconds: float) -> void:
	if not is_finite(seconds) or seconds <= 0.0:
		return
	var left := seconds
	if rest_left > 0.0:
		var resting := minf(rest_left, left)
		rest_left -= resting
		left -= resting
	if left > 0.0:
		meter = minf(meter + left * (1.0 + slack) * tuning.coolant_s / tuning.coolant_refill_s, tuning.coolant_s)
	if venting and meter >= tuning.coolant_s * tuning.vent_share * (1.0 - slack) - EPS:
		venting = false


## Full again, nothing running: a new life.
func refill() -> void:
	meter = tuning.coolant_s
	venting = false
	rest_left = 0.0
