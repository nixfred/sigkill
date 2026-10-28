extends RefCounted
## The rules of root vs user and sudo overcharge (C22) for one player: the kill streak of its
## life, the sudo charges it holds and the root time it has left. Pure bookkeeping by the
## numbers in resources/sudo_overcharge.tres, no nodes: alone the player's own controller
## (scripts/abilities/sudo_overcharge.gd) keeps one; in a match the host keeps one per player
## (scripts/net/combat.gd), whose word decides, and a joiner's copy only shows it.
##
## Rules: every life starts as user, with no streak and no charge. Each kill adds to the
## streak; the kills_needed-th earns a charge and the streak starts again, up to max_charges
## held; kills while holding the most bank nothing. A charge buys root_s of root (the weapon in
## hand, whichever, hits damage_scale times harder and spends no ammo); root ends at its time,
## at a death and at a respawn. A death also ends the streak and drops every unused charge.
## Fiction only: nothing real is run or read.

const Tuning = preload("res://scripts/abilities/sudo_overcharge_tuning.gd")

## Root left under this counts as over: float sums of frames.
const EPS := 0.0001

var tuning: Tuning
## Kills since the life began or the last charge was earned.
var streak := 0
## Sudo charges held.
var charges := 0
## Seconds of root left; 0 is user.
var root_left := 0.0


func _init(sudo_tuning: Tuning) -> void:
	tuning = sudo_tuning


func is_root() -> bool:
	return root_left > 0.0


## How hard every weapon hits now, as a multiple of its own damage.
func damage_scale() -> float:
	return tuning.damage_scale if is_root() else 1.0


## True when a press of the sudo key may start root now.
func can_activate() -> bool:
	return charges > 0 and not is_root()


## A kill of this player's: counts toward the next charge. True when it earned one.
func kill() -> bool:
	if charges >= tuning.max_charges:
		return false  # holding the most: kills meanwhile bank nothing
	streak += 1
	if streak < tuning.kills_needed:
		return false
	streak = 0
	charges += 1
	return true


## Spends a charge on root_s of root; false with no charge or already root.
func activate() -> bool:
	if not can_activate():
		return false
	charges -= 1
	root_left = tuning.root_s
	return true


## Moves root on by `seconds`. True when it ran out just now.
func tick(seconds: float) -> bool:
	if root_left <= 0.0 or not is_finite(seconds) or seconds <= 0.0:
		return false
	root_left -= seconds
	if root_left <= EPS:
		root_left = 0.0
		return true
	return false


## Root over now (a respawn, leaving a match); the charges and the streak stay. True when it
## was root.
func end_root() -> bool:
	if root_left <= 0.0:
		return false
	root_left = 0.0
	return true


## A death: root over, the streak gone, every unused charge dropped. Back to plain user.
func die() -> void:
	streak = 0
	charges = 0
	root_left = 0.0
