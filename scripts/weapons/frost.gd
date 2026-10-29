class_name Frost
extends RefCounted
## One target's freeze meter and freeze (C29, chmod 000): pure bookkeeping by the freeze tuning
## (scripts/weapons/freeze_tuning.gd, inside resources/chmod_000.tres), no nodes. A daemon, a piece of
## ICE that freezes (the hunter and the nodes) and, on a match's host, every player keeps one.
##
## Rules: the beam builds the meter ("chill", 0 to 1) by the seconds it holds on the target over the
## target's own chill time (a daemon's, an elite's, ICE's, a player's). A full meter freezes the target
## for its freeze time and empties. Frozen, the beam builds nothing; when the freeze runs out, or a hit
## thaws it at once, a guard follows in which the beam builds nothing either, so no chain of freezes.
## Once the beam leaves, the meter holds for chill_hold_s, then melts away (a full one in chill_melt_s).
## A death, a respawn and a new round clear it.
##
## On a joiner a target's copy takes the host's word instead (take_bits()): its meter in eighths and
## whether it is frozen, packed in one byte's bits 3 to 6 (bits(): the level, 0 to 7, in bits 3 to 5,
## frozen in bit 6), beside a daemon's state in bits 0 to 2 and SIGSTOP's hold in bit 7.
##
## Fiction only: nothing real has its permissions touched.

enum Kind { DAEMON, ELITE, ICE, PLAYER }

## The word's bits: the level (0 to LEVELS) and the freeze.
const LEVEL_SHIFT := 3
const LEVEL_MASK := 0x38
const FROZEN_BIT := 0x40
const BITS := LEVEL_MASK | FROZEN_BIT
const LEVELS := 7
## Below full by less than this still freezes: float sums of beam ticks.
const EPS := 0.0001
const TUNING_PATH := "res://resources/chmod_000.tres"
## A copy's freeze, its countdown run out before the host's word of the thaw came, holds this long more.
const WORD_HOLD_S := 0.05

static var _shared: FreezeTuning

var tuning: FreezeTuning
var kind: Kind = Kind.DAEMON
## The meter, 0 to 1.
var chill := 0.0
## Seconds of freeze left, of the guard after a thaw, and of the meter's hold before it melts.
var frozen_left := 0.0
var guard_left := 0.0
var hold_left := 0.0
## Freezes since it was made, and thaws by a hit, for the checks.
var freezes := 0
var broken_by_hits := 0


func _init(target_kind: Kind = Kind.DAEMON, freeze_tuning: FreezeTuning = null) -> void:
	kind = target_kind
	tuning = freeze_tuning if freeze_tuning != null else shared()


## The shipped freeze numbers: chmod 000's own (resources/chmod_000.tres), or the built-in ones when it
## is missing or refused. Read once.
static func shared() -> FreezeTuning:
	if _shared == null:
		var def = load(TUNING_PATH) if ResourceLoader.exists(TUNING_PATH) else null
		var t = def.get("freeze") if def != null else null
		_shared = t if t is FreezeTuning and t.problems().is_empty() else FreezeTuning.new()
	return _shared


## Seconds of beam that fill this target's meter.
func chill_s() -> float:
	match kind:
		Kind.ELITE:
			return tuning.elite_chill_s
		Kind.ICE:
			return tuning.ice_chill_s
		Kind.PLAYER:
			return tuning.player_chill_s
	return tuning.chill_s


## Seconds a full meter holds this target frozen.
func freeze_s() -> float:
	match kind:
		Kind.ICE:
			return tuning.ice_freeze_s
		Kind.PLAYER:
			return tuning.player_freeze_s
	return tuning.freeze_s


func guard_s() -> float:
	return tuning.player_guard_s if kind == Kind.PLAYER else tuning.thaw_guard_s


func frozen() -> bool:
	return frozen_left > 0.0


## True while the beam would build this meter: not frozen and not guarded after a thaw.
func open() -> bool:
	return frozen_left <= 0.0 and guard_left <= 0.0


## `seconds` of beam on this target: the meter builds; true when that froze it just now.
func beam(seconds: float) -> bool:
	if not is_finite(seconds) or seconds <= 0.0 or not open():
		return false
	chill = minf(chill + seconds / chill_s(), 1.0)
	hold_left = tuning.chill_hold_s
	if chill < 1.0 - EPS:
		return false
	chill = 0.0
	hold_left = 0.0
	frozen_left = freeze_s()
	freezes += 1
	return true


## Moves it on by `seconds`: the freeze runs out (then the guard), the meter holds, then melts. True when
## the freeze ran out just now.
func tick(seconds: float) -> bool:
	if not is_finite(seconds) or seconds <= 0.0:
		return false
	if frozen_left > 0.0:
		frozen_left -= seconds
		if frozen_left > 0.0:
			return false
		frozen_left = 0.0
		guard_left = guard_s()
		return true
	guard_left = maxf(guard_left - seconds, 0.0)
	var left := seconds
	if hold_left > 0.0:
		var held := minf(hold_left, left)
		hold_left -= held
		left -= held
	if left > 0.0 and chill > 0.0:
		chill = maxf(chill - left / tuning.chill_melt_s, 0.0)
	return false


## A hit thawed it (the hit's own bonus is the target's to land): the freeze over, the guard begun. True
## when it was frozen.
func thaw() -> bool:
	if frozen_left <= 0.0:
		return false
	frozen_left = 0.0
	guard_left = guard_s()
	broken_by_hits += 1
	return true


## Everything back to nothing: a death, a respawn, a new round.
func clear() -> void:
	chill = 0.0
	frozen_left = 0.0
	guard_left = 0.0
	hold_left = 0.0


## The share of its pace a player keeps now: nothing while frozen, less as the meter fills.
func pace() -> float:
	if frozen_left > 0.0:
		return 0.0
	return 1.0 - tuning.player_slow * chill


## The meter for a screen to show: full while frozen.
func shown() -> float:
	return 1.0 if frozen_left > 0.0 else chill


## The word's bits: the meter in eighths and the freeze.
func bits() -> int:
	return (clampi(roundi(chill * LEVELS), 0, LEVELS) << LEVEL_SHIFT) | (FROZEN_BIT if frozen_left > 0.0 else 0)


## The host's word on a joiner's copy: its meter and whether it is frozen (a freeze holds until the word
## says otherwise). True when the word froze it just now.
func take_bits(word: int) -> bool:
	var was := frozen_left > 0.0
	chill = float((word & LEVEL_MASK) >> LEVEL_SHIFT) / LEVELS
	var now := (word & FROZEN_BIT) != 0
	if now and not was:
		freezes += 1
		frozen_left = freeze_s()
	elif now:
		frozen_left = maxf(frozen_left, WORD_HOLD_S)  # its own countdown runs on between the words
	else:
		frozen_left = 0.0
	hold_left = 0.0
	return now and not was


## Level `word`'s meter, 0 to 1 (a static read of the bits).
static func chill_of(word: int) -> float:
	return float((word & LEVEL_MASK) >> LEVEL_SHIFT) / LEVELS


static func frozen_of(word: int) -> bool:
	return (word & FROZEN_BIT) != 0
