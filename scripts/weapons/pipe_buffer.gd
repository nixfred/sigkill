class_name PipeBuffer
extends RefCounted
## pipe |'s buffer (C30): the chain beam's ammo is not a magazine but the pipe's buffer, which every chain
## writes into and the reader at the far end drains on its own. Pure bookkeeping by the pipe tuning, no
## nodes: the player's inventory keeps one for the pipe (scripts/weapons/inventory.gd) and a match's host
## keeps one per player by the same rules on its own clock (scripts/net/combat.gd), a little more lenient
## (slack), so the host is never stricter than an honest player's game.
##
## Rules: each chain writes write_kib. After the last write the buffer rests drain_rest_s, then drains
## drain_kib_s a second. A write that fills it blocks it ("write blocked", as a real pipe's writer waits on
## a full one): no chain until it has drained to unblock_share of full. A new life empties it.
##
## Fiction only: nothing real is written or read.

## Above full by less than this still counts as full: float sums of writes.
const EPS := 0.0001

var tuning: PipeTuning
## KiB in the buffer now.
var fill := 0.0
## True from filling up until it has drained to unblock_share.
var blocked := false
## Seconds of rest left before it drains.
var rest_left := 0.0
## How much more lenient this keeper is: it drains (1 + slack) times as fast, rests (1 - slack) as long
## and unblocks at (1 + slack) of the share. 0 for the player's own buffer.
var slack := 0.0


func _init(pipe_tuning: PipeTuning, leniency: float = 0.0) -> void:
	tuning = pipe_tuning
	slack = clampf(leniency, 0.0, 0.5)


func full() -> float:
	return tuning.buffer_kib


## How full it is, from 0 (empty) to 1 (full).
func share() -> float:
	return clampf(fill / tuning.buffer_kib, 0.0, 1.0)


## True when a chain may write now: not blocked.
func ready() -> bool:
	return not blocked


## A chain's write: the buffer fills by write_kib and rests again; one that fills it blocks it.
func write() -> void:
	fill = minf(fill + tuning.write_kib, tuning.buffer_kib)
	rest_left = tuning.drain_rest_s * (1.0 - slack)
	if fill >= tuning.buffer_kib - EPS:
		fill = tuning.buffer_kib
		blocked = true


## Moves it on by `seconds`: its rest, then its drain; a blocked one unblocks at its share.
func tick(seconds: float) -> void:
	if not is_finite(seconds) or seconds <= 0.0:
		return
	var left := seconds
	if rest_left > 0.0:
		var resting := minf(rest_left, left)
		rest_left -= resting
		left -= resting
	if left > 0.0:
		fill = maxf(fill - left * tuning.drain_kib_s * (1.0 + slack), 0.0)
	if blocked and fill <= tuning.buffer_kib * tuning.unblock_share * (1.0 + slack) + EPS:
		blocked = false


## Empty again, nothing waiting: a new life.
func empty() -> void:
	fill = 0.0
	blocked = false
	rest_left = 0.0
