extends RefCounted
## The host's combat authority (C14, PRD 5.3): who has how much health, who is dead and for
## how long, who is freshly spawned and safe, and whether a shot a player claims to have
## fired is one the host will believe. Pure bookkeeping and rules: no node, no socket, no
## raycast. scripts/net/net_session.gd owns one of these while hosting, runs every shot,
## its own included, through validate(), raycasts in its own world and applies the
## outcome here. A joiner never has one: it only displays what the host sends.
##
## A shot is dropped, counted and never answered when: the shooter is not a player, is
## dead, repeats or skips too far in its own shot numbering, sends a direction that is not
## a unit vector or an origin that is not finite, fires sooner than the weapon's cooldown
## allows (less a tolerance for jitter), or claims an origin farther from the host's view
## of its eye than the tolerance. Damage comes from WeaponTuning.damage, the one weapon.

const Tuning = preload("res://scripts/net/combat_tuning.gd")

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

var tuning: Tuning
## The weapon's numbers, copied in from WeaponTuning by the session.
var cooldown_s := 0.16
var damage := 25.0
## Every player the host knows, id -> {health, dead, respawn_left, protect_left,
## last_fire, last_seq, kills, deaths}.
var states := {}
## Shots dropped, in all and by reason.
var dropped := 0
var drops := {}


func _init(combat_tuning: Tuning, weapon_cooldown_s: float, weapon_damage: float) -> void:
	tuning = combat_tuning
	cooldown_s = weapon_cooldown_s
	damage = weapon_damage


func add_player(id: int) -> void:
	states[id] = {"health": tuning.max_health, "dead": false, "respawn_left": 0.0, "protect_left": 0.0, "last_fire": -INF, "last_seq": 0, "kills": 0, "deaths": 0}


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


## "" when the host believes shot `seq` from `shooter` at `origin` along `dir`, given the
## host's view of the shooter's eye and its clock; otherwise why not, counted. Nothing is
## recorded here: accept() does, once the host has also looked at the shot itself.
func validate(shooter: int, seq: int, origin: Vector3, dir: Vector3, eye: Vector3, now: float) -> String:
	if not states.has(shooter):
		return _drop(DROP_NO_PLAYER)
	var s: Dictionary = states[shooter]
	if s["dead"]:
		return _drop(DROP_DEAD)
	if not seq_ok(seq, s["last_seq"]):
		return _drop(DROP_SEQ)
	if not dir_ok(dir) or not origin.is_finite() or absf(origin.x) > WORLD_LAST or absf(origin.y) > WORLD_LAST or absf(origin.z) > WORLD_LAST:
		return _drop(DROP_SHAPE)
	if not rate_ok(now, s["last_fire"], cooldown_s, tuning.fire_rate_tolerance):
		return _drop(DROP_RATE)
	if not origin_ok(origin, eye, tuning.origin_tolerance_m):
		return _drop(DROP_ORIGIN)
	return ""


## Records a believed shot's time and number: the next one is measured from here.
func accept(shooter: int, seq: int, now: float) -> void:
	if states.has(shooter):
		states[shooter]["last_fire"] = now
		states[shooter]["last_seq"] = seq


## Counts a shot that passed validate() and was then refused on what the host saw, such as
## an origin behind cover. Nothing of it is recorded: a refused shot burns no number.
func drop_after(reason: String) -> void:
	_drop(reason)


## The weapon's damage on `victim` from `killer`: {health, killed}, or {} when the victim
## is dead or protected and nothing changes.
func damage_player(victim: int, killer: int) -> Dictionary:
	if not states.has(victim) or not states.has(killer):
		return {}
	var s: Dictionary = states[victim]
	if s["dead"] or s["protect_left"] > 0.0:
		return {}
	s["health"] = maxf(s["health"] - damage, 0.0)
	var killed: bool = s["health"] <= 0.0
	if killed:
		s["dead"] = true
		s["respawn_left"] = tuning.respawn_delay_s
		s["deaths"] += 1
		if killer != victim:
			states[killer]["kills"] += 1
	return {"health": s["health"], "killed": killed}


## Back to full health, alive and protected for a while.
func respawn(id: int) -> void:
	if not states.has(id):
		return
	var s: Dictionary = states[id]
	s["health"] = tuning.max_health
	s["dead"] = false
	s["respawn_left"] = 0.0
	s["protect_left"] = tuning.spawn_protection_s


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
