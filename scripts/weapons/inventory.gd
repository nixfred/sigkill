extends RefCounted
## What one player holds and the state of each weapon (C16): the loadout in slot order,
## which slot is drawn and which was drawn before it (Q swaps back), every magazine and
## reserve, each weapon's own fire interval, and the swap and reload in progress. Pure
## bookkeeping, no nodes: scripts/player.gd owns one, ticks it every physics frame and
## asks it before every shot. The host's own check of a shot lives in scripts/net/combat.gd.
##
## Rules: no shot while a weapon is being drawn or reloaded. Drawing another weapon stops a
## reload (its rounds are not moved). Pressing fire with an empty magazine starts a reload
## when there are rounds in reserve. A reload moves the rounds when it finishes. Each
## weapon's interval runs on while another is drawn.
##
## The ult meter (C17): one meter for the loadout's ult weapon (the SIGKILL rail), filled by
## what the player's other weapons do (scripts/player.gd solo, the host's results in a
## match), kept across swaps, emptied by the ult's one shot, and reset by a new life, a death
## and a new round. The ult fires only with the meter full.

const WeaponDefScript = preload("res://scripts/weapons/weapon_def.gd")

## Why try_fire() did not fire.
const BLOCK_SWAP := "swap"
const BLOCK_RELOAD := "reload"
const BLOCK_COOLDOWN := "cooldown"
const BLOCK_EMPTY := "empty"
const BLOCK_DRY := "dry"
const BLOCK_METER := "meter"

## The weapons, slot 1 first. Every one is a usable WeaponDef.
var defs: Array = []
## Per slot: rounds in the magazine, rounds in reserve (WeaponDef.INFINITE for no limit),
## seconds until the weapon may fire again.
var mags: Array[int] = []
var reserves: Array[int] = []
var cooldowns: Array[float] = []
## The drawn slot, and the slot drawn before it (the same slot when there was none).
var current := 0
var last := 0
var swap_s := 0.3
var swap_left := 0.0
var reload_left := 0.0
## Seconds no shot may go off although this side's own draw and reload are done: the host
## still counts one of them running (a LAN match, C16). A new draw, a hold or a refill ends it.
var block_left := 0.0
## Seconds the HUD keeps showing the drawn weapon's fiction line.
var fiction_left := 0.0
var fiction_s := 1.6
## The ult meter, from 0 to the ult's ult_meter.
var meter := 0.0


func _init(weapon_defs: Array, swap_seconds: float = 0.3, fiction_seconds: float = 1.6) -> void:
	defs = weapon_defs.duplicate()
	swap_s = swap_seconds
	fiction_s = fiction_seconds
	for def in defs:
		mags.append(def.magazine_size)
		reserves.append(def.reserve_ammo)
		cooldowns.append(0.0)


func slot_count() -> int:
	return defs.size()


## The slot of the loadout's ult weapon, or -1 when it has none.
func ult_slot() -> int:
	for i in defs.size():
		if defs[i].is_ult():
			return i
	return -1


## Points the meter needs; 0 when the loadout has no ult.
func meter_full() -> float:
	var slot := ult_slot()
	return defs[slot].ult_meter if slot >= 0 else 0.0


## True when the ult can take its one shot.
func meter_ready() -> bool:
	return meter_full() > 0.0 and meter >= meter_full()


## How full the meter is, from 0 to 1.
func meter_share() -> float:
	var full := meter_full()
	return clampf(meter / full, 0.0, 1.0) if full > 0.0 else 0.0


## Adds what another weapon's hit earned (see WeaponDef.meter_gain), capped at full.
func add_meter(amount: float) -> void:
	if is_finite(amount) and amount > 0.0:
		meter = minf(meter + amount, meter_full())


func reset_meter() -> void:
	meter = 0.0


## The drawn weapon.
func def() -> WeaponDefScript:
	return defs[current]


## The slot of the weapon with `id`, or -1.
func slot_of(id: String) -> int:
	for i in defs.size():
		if defs[i].id == id:
			return i
	return -1


## Draws the weapon in `slot` (0 for slot 1). False when it is already drawn or there is no
## such slot. A reload in progress stops; the new weapon is ready after the swap time.
func select(slot: int) -> bool:
	if slot < 0 or slot >= defs.size() or slot == current:
		return false
	last = current
	current = slot
	swap_left = swap_s
	reload_left = 0.0
	block_left = 0.0
	fiction_left = fiction_s
	return true


## Holds the weapon in `slot` at once, ready, nothing running: a new life taking the weapon
## the host says is in hand. False when there is no such slot.
func hold(slot: int) -> bool:
	if slot < 0 or slot >= defs.size():
		return false
	if slot != current:
		last = current
		current = slot
	swap_left = 0.0
	reload_left = 0.0
	block_left = 0.0
	return true


## The next (`step` 1) or previous (-1) slot, wrapping round.
func cycle(step: int) -> bool:
	if defs.size() < 2:
		return false
	return select(posmod(current + step, defs.size()))


## Back to the weapon drawn before this one.
func swap_last() -> bool:
	return select(last)


## Starts reloading the drawn weapon. False when it has no magazine, the magazine is full,
## the reserve is empty, or a swap or a reload is already running.
func reload() -> bool:
	var d := def()
	if not d.has_magazine() or swap_left > 0.0 or reload_left > 0.0:
		return false
	if d.reload_take(mags[current], reserves[current]) <= 0:
		return false
	reload_left = d.reload_s
	return true


func is_swapping() -> bool:
	return swap_left > 0.0


func is_reloading() -> bool:
	return reload_left > 0.0


## How far the reload has come, from 0 to 1; 0 when none is running.
func reload_progress() -> float:
	if reload_left <= 0.0:
		return 0.0
	return clampf(1.0 - reload_left / maxf(def().reload_s, 0.001), 0.0, 1.0)


## How far the swap has come, from 0 to 1; 1 when none is running.
func swap_progress() -> float:
	if swap_left <= 0.0:
		return 1.0
	return clampf(1.0 - swap_left / maxf(swap_s, 0.001), 0.0, 1.0)


## Fires the drawn weapon if it may: "" when it fired (a round spent, its interval set, the
## ult's meter emptied), otherwise why not. An empty magazine with rounds in reserve starts
## a reload.
func try_fire() -> String:
	var why := fire_block()
	if why == BLOCK_EMPTY:
		return BLOCK_EMPTY if reload() else BLOCK_DRY
	if why != "":
		return why
	var d := def()
	if d.has_magazine():
		mags[current] -= 1
	if d.is_ult():
		meter = 0.0
	cooldowns[current] = d.fire_cooldown
	return ""


## Why the drawn weapon could not fire right now, or "": the same rules as try_fire(),
## changing nothing (a charging shot asks before it starts).
func fire_block() -> String:
	if swap_left > 0.0:
		return BLOCK_SWAP
	if reload_left > 0.0 or block_left > 0.0:
		return BLOCK_RELOAD
	if cooldowns[current] > 0.0:
		return BLOCK_COOLDOWN
	var d := def()
	if d.has_magazine() and mags[current] <= 0:
		return BLOCK_EMPTY
	if d.is_ult() and not meter_ready():
		return BLOCK_METER
	return ""


## Moves every timer on by `delta` seconds; a reload that finishes moves its rounds.
func tick(delta: float) -> void:
	for i in cooldowns.size():
		cooldowns[i] = maxf(cooldowns[i] - delta, 0.0)
	swap_left = maxf(swap_left - delta, 0.0)
	block_left = maxf(block_left - delta, 0.0)
	fiction_left = maxf(fiction_left - delta, 0.0)
	if reload_left > 0.0:
		reload_left -= delta
		if reload_left <= 0.0:
			reload_left = 0.0
			var d := def()
			var take := d.reload_take(mags[current], reserves[current])
			mags[current] += take
			if reserves[current] != WeaponDefScript.INFINITE:
				reserves[current] -= take


## Every magazine and reserve full again, nothing in progress, the ult meter empty: a fresh
## life.
func refill() -> void:
	meter = 0.0
	for i in defs.size():
		mags[i] = defs[i].magazine_size
		reserves[i] = defs[i].reserve_ammo
		cooldowns[i] = 0.0
	swap_left = 0.0
	reload_left = 0.0
	block_left = 0.0
