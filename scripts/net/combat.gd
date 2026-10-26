extends RefCounted
## The host's combat authority (C14, PRD 5.3): who has how much health, who is dead and for
## how long, who is freshly spawned and safe, and whether a shot a player claims to have
## fired is one the host will believe. Pure bookkeeping and rules: no node, no socket, no
## raycast. scripts/net/net_session.gd owns one of these while hosting, runs every shot,
## its own included, through validate(), raycasts in its own world and applies the
## outcome here. A joiner never has one: it only displays what the host sends.
##
## A shot is dropped, counted and never answered when: the shooter is not a player, is
## dead, repeats or skips too far in its own shot numbering, names a weapon it does not
## hold, sends a direction that is not a unit vector or an origin that is not finite, fires
## that weapon sooner than its fire interval allows, switches weapons between two shots
## sooner than the swap time allows (both less a tolerance for jitter), fires an empty
## magazine, or claims an origin farther from the host's view of its eye than the tolerance.
##
## Weapons (C16): every player holds the arsenal's loadout, so "holds" means the weapon is
## in it. The host keeps each player's magazine and reserve per weapon and counts a round
## off for every shot it believes. No reload message is trusted or needed: a weapon that
## has rested for its reload time (less the tolerance) since its last believed shot is
## credited a reload when it next fires, which is never less than a real reload gives, and
## a magazine emptied faster than that is empty. A new life refills everything. Damage is
## worked out per pellet by the session from the weapon's falloff and applied here once
## per victim and shot.

const Tuning = preload("res://scripts/net/combat_tuning.gd")
const WeaponDefScript = preload("res://scripts/weapons/weapon_def.gd")

const DIR_TOLERANCE := 0.01
const SEQ_JUMP_LAST := 10000
const SEQ_LAST := 2147483647
const WORLD_LAST := 10000.0
## Why a shot was dropped, as the words counted in `drops`.
const DROP_NO_PLAYER := "no_player"
const DROP_DEAD := "dead"
const DROP_SEQ := "seq"
const DROP_SHAPE := "shape"
const DROP_RATE := "rate"
const DROP_ORIGIN := "origin"
const DROP_LIFE := "life"
const DROP_WEAPON := "weapon"
const DROP_SWAP := "swap"
const DROP_EMPTY := "empty"

var tuning: Tuning
## The weapons every player holds, id -> WeaponDef, and the arsenal's swap time.
var weapons := {}
var swap_s := 0.3
## Every player the host knows, id -> {health, dead, respawn_left, protect_left,
## last_fire, last_weapon, last_seq, kills, deaths, ammo}; ammo is weapon id -> {mag,
## reserve, last_fire}.
var states := {}
## Shots dropped, in all and by reason.
var dropped := 0
var drops := {}


## `weapon_defs`: the arsenal's usable WeaponDefs; `swap_seconds`: its swap time.
func _init(combat_tuning: Tuning, weapon_defs: Array, swap_seconds: float = 0.3) -> void:
	tuning = combat_tuning
	swap_s = swap_seconds
	for def in weapon_defs:
		weapons[def.id] = def


func add_player(id: int) -> void:
	states[id] = {"health": tuning.max_health, "dead": false, "respawn_left": 0.0, "protect_left": 0.0, "last_fire": -INF, "last_weapon": "", "last_seq": 0, "kills": 0, "deaths": 0, "ammo": _full_ammo()}


## Rounds in the magazine and in reserve `id` has for `weapon` right now, as the host counts
## them: [mag, reserve]; [-1, -1] for no limit or no such thing.
func ammo_of(id: int, weapon: String) -> Array:
	if not states.has(id) or not states[id]["ammo"].has(weapon):
		return [-1, -1]
	var a: Dictionary = states[id]["ammo"][weapon]
	return [a["mag"], a["reserve"]]


func remove_player(id: int) -> void:
	states.erase(id)


func has_player(id: int) -> bool:
	return states.has(id)


func alive(id: int) -> bool:
	return states.has(id) and not states[id]["dead"]


func health_of(id: int) -> float:
	return states[id]["health"] if states.has(id) else 0.0


func protected(id: int) -> bool:
	return states.has(id) and states[id]["protect_left"] > 0.0


## Moves death and protection timers on. Returns the ids whose respawn is due now.
func tick(delta: float) -> Array:
	var due := []
	for id in states:
		var s: Dictionary = states[id]
		if s["protect_left"] > 0.0:
			s["protect_left"] = maxf(s["protect_left"] - delta, 0.0)
		if s["dead"] and s["respawn_left"] > 0.0:
			s["respawn_left"] -= delta
			if s["respawn_left"] <= 0.0:
				s["respawn_left"] = 0.0
				due.append(id)
	return due


## "" when the host believes shot `seq` from `shooter`, in its life `life`, of `weapon`, at
## `origin` along `dir`, given the host's view of the shooter's eye, the life it knows the
## shooter is in, and its clock; otherwise why not, counted. A shot from a past life is one
## that was in flight when the shooter died. Nothing is recorded here: accept() does, once
## the host has also looked at the shot itself.
func validate(shooter: int, seq: int, life: int, weapon: String, origin: Vector3, dir: Vector3, eye: Vector3, known_life: int, now: float) -> String:
	if not states.has(shooter):
		return _drop(DROP_NO_PLAYER)
	var s: Dictionary = states[shooter]
	if s["dead"]:
		return _drop(DROP_DEAD)
	if life != known_life:
		return _drop(DROP_LIFE)
	if not seq_ok(seq, s["last_seq"]):
		return _drop(DROP_SEQ)
	if not weapons.has(weapon):
		return _drop(DROP_WEAPON)
	if not dir_ok(dir) or not origin.is_finite() or absf(origin.x) > WORLD_LAST or absf(origin.y) > WORLD_LAST or absf(origin.z) > WORLD_LAST:
		return _drop(DROP_SHAPE)
	var def: WeaponDefScript = weapons[weapon]
	var a: Dictionary = s["ammo"][weapon]
	if not rate_ok(now, a["last_fire"], def.fire_cooldown, tuning.fire_rate_tolerance):
		return _drop(DROP_RATE)
	if s["last_weapon"] != "" and s["last_weapon"] != weapon and not rate_ok(now, s["last_fire"], swap_s, tuning.fire_rate_tolerance):
		return _drop(DROP_SWAP)
	if def.has_magazine() and _rested(def, a, now)[0] <= 0:
		return _drop(DROP_EMPTY)
	if not origin_ok(origin, eye, tuning.origin_tolerance_m):
		return _drop(DROP_ORIGIN)
	return ""


## Records a believed shot's time, number and weapon, and spends its round (after any
## reload its rest has earned): the next shot is measured from here.
func accept(shooter: int, seq: int, weapon: String, now: float) -> void:
	if not states.has(shooter) or not weapons.has(weapon):
		return
	var s: Dictionary = states[shooter]
	s["last_fire"] = now
	s["last_seq"] = seq
	s["last_weapon"] = weapon
	var def: WeaponDefScript = weapons[weapon]
	var a: Dictionary = s["ammo"][weapon]
	if def.has_magazine():
		var after := _rested(def, a, now)
		a["mag"] = after[0] - 1
		a["reserve"] = after[1]
	a["last_fire"] = now


## [mag, reserve] once a reload is credited to a weapon that has rested for its reload
## time, less the tolerance, since its last believed shot; unchanged otherwise.
func _rested(def: WeaponDefScript, a: Dictionary, now: float) -> Array:
	var mag: int = a["mag"]
	var reserve: int = a["reserve"]
	if now - a["last_fire"] >= def.reload_s * (1.0 - tuning.fire_rate_tolerance):
		var take := def.reload_take(mag, reserve)
		mag += take
		if reserve != WeaponDefScript.INFINITE:
			reserve -= take
	return [mag, reserve]


## Every weapon's magazine and reserve full, as at a new life.
func _full_ammo() -> Dictionary:
	var out := {}
	for id in weapons:
		out[id] = {"mag": weapons[id].magazine_size, "reserve": weapons[id].reserve_ammo, "last_fire": -INF}
	return out


## Counts a shot that passed validate() and was then refused on what the host saw, such as
## an origin behind cover. Nothing of it is recorded: a refused shot burns no number.
func drop_after(reason: String) -> void:
	_drop(reason)


## `amount` of damage on `victim` from `killer` (one shot's, every pellet that struck it
## added up): {health, killed}, or {} when the victim is dead or protected, or the amount
## is not a positive number, and nothing changes.
func damage_player(victim: int, killer: int, amount: float) -> Dictionary:
	if not states.has(victim) or not states.has(killer) or not is_finite(amount) or amount <= 0.0:
		return {}
	var s: Dictionary = states[victim]
	if s["dead"] or s["protect_left"] > 0.0:
		return {}
	s["health"] = maxf(s["health"] - amount, 0.0)
	var killed: bool = s["health"] <= 0.0
	if killed:
		s["dead"] = true
		s["respawn_left"] = tuning.respawn_delay_s
		s["deaths"] += 1
		if killer != victim:
			states[killer]["kills"] += 1
	return {"health": s["health"], "killed": killed}


## The host has no arena to put `id` down in right now (its own is reloading): the respawn
## comes due again a moment later.
func defer_respawn(id: int, by_s: float) -> void:
	if states.has(id) and states[id]["dead"]:
		states[id]["respawn_left"] = maxf(by_s, 0.001)


## Back to full health and full ammo, alive and protected for a while.
func respawn(id: int) -> void:
	if not states.has(id):
		return
	var s: Dictionary = states[id]
	s["health"] = tuning.max_health
	s["dead"] = false
	s["respawn_left"] = 0.0
	s["protect_left"] = tuning.spawn_protection_s
	s["ammo"] = _full_ammo()


func _drop(reason: String) -> String:
	dropped += 1
	drops[reason] = drops.get(reason, 0) + 1
	return reason


## True for a shot number after `last`: any first one, else newer and not absurdly so.
static func seq_ok(seq: int, last: int) -> bool:
	if seq < 1 or seq >= SEQ_LAST:
		return false
	if last <= 0:
		return true
	return seq > last and seq - last <= SEQ_JUMP_LAST


## True for a finite unit vector, within a small tolerance.
static func dir_ok(dir: Vector3) -> bool:
	return dir.is_finite() and absf(dir.length() - 1.0) <= DIR_TOLERANCE


## True when a shot's origin is within `tolerance` of where the host thinks the eye is.
static func origin_ok(origin: Vector3, eye: Vector3, tolerance: float) -> bool:
	return origin.is_finite() and eye.is_finite() and origin.distance_to(eye) <= tolerance


## True when `now` is at least the cooldown, less the tolerance's share of it, after the
## last accepted shot.
static func rate_ok(now: float, last: float, cooldown: float, tolerance: float) -> bool:
	return now - last >= cooldown * (1.0 - tolerance)


## The spawn point farthest from the nearest threat; the first one when there are no
## threats; Vector3.INF when there are no spawn points.
static func farthest_spawn(spawns: Array, threats: Array) -> Vector3:
	if spawns.is_empty():
		return Vector3.INF
	if threats.is_empty():
		return spawns[0]
	var best: Vector3 = spawns[0]
	var best_gap := -1.0
	for spawn in spawns:
		var gap := INF
		for threat in threats:
			gap = minf(gap, spawn.distance_to(threat))
		if gap > best_gap:
			best_gap = gap
			best = spawn
	return best
