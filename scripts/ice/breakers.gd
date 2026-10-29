class_name Breakers
extends RefCounted
## One intruder's ICEbreakers (I2): the one-use programs it carries beside its weapons, never in a
## weapon slot. How many of each of the four kinds it holds this round (a round starts it with the
## tuning's start_count of each, a pickup adds one, never past carry_cap), and which kind is loaded:
## U runs the loaded one, Y loads the next. Y skips the kinds it holds none of while it holds any, so
## the loaded kind is one it can run whenever it can run anything. The rules only: who holds this and
## what a run does is scripts/ice/breaker_director.gd's.

enum Kind { BRUTE, EXPLOIT, CLOAK, DECOY }
## Each kind's name, on the HUD, in the guide's numbers and in a hit's source ("breaker:brute").
const NAMES := ["brute", "exploit", "cloak", "decoy"]
const SOURCE := "breaker:"

var counts := PackedInt32Array([0, 0, 0, 0])
var loaded: int = Kind.BRUTE
var cap := 2


func _init(start: int = 1, carry_cap: int = 2) -> void:
	cap = maxi(carry_cap, 1)
	reset(start)


## A new round: `start` of each kind; the loaded kind stays the player's choice.
func reset(start: int) -> void:
	for k in counts.size():
		counts[k] = clampi(start, 0, cap)


func count(kind: int) -> int:
	return counts[kind] if valid(kind) else 0


## Spends one of `kind`. False when none is held.
func take(kind: int) -> bool:
	if count(kind) <= 0:
		return false
	counts[kind] -= 1
	return true


## One more of `kind`, never past the cap. False when it is at the cap.
func add(kind: int) -> bool:
	if not valid(kind) or counts[kind] >= cap:
		return false
	counts[kind] += 1
	return true


## Y: the next kind after the loaded one that it holds any of (round the four in order), or simply
## the next when it holds none at all. The kind loaded now.
func cycle() -> int:
	var any := total() > 0
	for step in range(1, counts.size() + 1):
		var next := (loaded + step) % counts.size()
		if not any or counts[next] > 0:
			loaded = next
			break
	return loaded


func total() -> int:
	var n := 0
	for c in counts:
		n += c
	return n


## The counts as the wire carries them, in kind order.
func bytes() -> PackedByteArray:
	var out := PackedByteArray()
	for c in counts:
		out.append(clampi(c, 0, 255))
	return out


## The host's word for this intruder's counts (a joiner's own copy).
func take_bytes(word: PackedByteArray) -> void:
	for k in mini(word.size(), counts.size()):
		counts[k] = clampi(word[k], 0, cap)


static func valid(kind: int) -> bool:
	return kind >= 0 and kind < NAMES.size()


static func name_of(kind: int) -> String:
	return NAMES[kind] if valid(kind) else ""


## The kind named `word` ("brute" ...), or -1.
static func kind_of(word: String) -> int:
	return NAMES.find(word)


## A breaker's hit source: "breaker:brute".
static func source_of(kind: int) -> String:
	return SOURCE + name_of(kind)


## True for a hit whose source is a breaker's, never a weapon's: the hunter never adapts to one.
static func is_source(source: String) -> bool:
	return source.begins_with(SOURCE)
