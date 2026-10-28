extends RefCounted
## The host's combat authority (C14, PRD 5.3): who has how much health, who is dead and for
## how long, who is freshly spawned and safe, and whether a shot a player claims to have
## fired is one the host will believe. Pure bookkeeping and rules: no node, no socket, no
## raycast. scripts/net/net_session.gd owns one of these while hosting, runs every shot,
## its own included, through validate(), raycasts in its own world and applies the
## outcome here. A joiner never has one: it only displays what the host sends.
##
## A shot is dropped, counted and never answered when: the shooter is not a player, is
## dead, repeats or skips too far in its own shot numbering, names a weapon other than the
## one it holds, sends a direction that is not a unit vector or an origin that is not
## finite, fires before the weapon it drew is ready, while it reloads, sooner than the
## weapon's fire interval allows, from an empty magazine, or claims an origin farther from
## the host's view of its eye than the tolerance.
##
## Weapons (C16): every player carries the arsenal's loadout and starts each life holding
## what it held, slot 1 at first. The host runs the same rules as the player's inventory
## from what the player tells it, so nothing about ammo is guessed: a draw (the weapon in
## hand from now on, ready after the swap time, any reload stopped) and a reload (refused
## with no magazine, a full one, nothing in reserve or mid-reload; one that comes mid-draw
## starts when the draw is done; its rounds move only when its time is up). Every believed shot spends a round. All timing is less
## the tolerance for jitter, so the host is never stricter than an honest player's game.
## Where the wire can still put the two apart (a reload's message so late that it arrives
## with the draw after it, a reload refused), the session's ammo replies put the player's
## counts back to the host's.
## A new life refills everything. Damage is worked out per pellet by the session from the
## weapon's falloff and applied here once per victim and shot.
##
## The ult (C17): the host owns every player's ult meter. What a player's other weapons do
## to other players here fills it (add_meter, from the share of health taken and the kills,
## by the ult's own numbers); a shot of the ult is believed only with the meter full and
## empties it; a death and a new life empty it. A forged or early ult shot is dropped and
## counted as "meter". Spawn protection stays full invulnerability: the rail, like every
## other weapon, does nothing to a protected player.
##
## SIGSTOP (C18): the host owns every player's SIGSTOP meter too, by the rules of
## scripts/abilities/sigstop_meter.gd on the host's clock, which never slows. A start is
## believed only with the meter at its start share; an empty-meter or otherwise forged start
## is dropped and counted as "sigstop". While a player's SIGSTOP is on, its pellets fly
## straight (the session asks sigstop_on()). A death empties the meter and ends SIGSTOP.
##
## The fork bomb (C19): a throw is its own request, not a shot (throw()), drawn or not, so a
## quick throw (G) counts too. The host believes one only from a living player in its life,
## with a unit aim within AIM_TOLERANCE_DEG of the view the host last had of it, an origin
## near the host's view of its eye, a bomb left in the host's count, the fork bomb's interval
## kept and the player under its cap of live bomblets; then it spends the bomb and runs the
## chain itself. A forged or empty throw is dropped and counted as for a shot ("empty",
## "origin", "aim", "rate", "live_cap"). A fork bomb named in a shot intent is a "weapon"
## drop: it is thrown, never fired. A new life refills its bombs as every magazine.
##
## Root vs user and sudo overcharge (C22): the host owns every player's sudo state too, by
## the rules of scripts/abilities/sudo_state.gd: every kill this host credits (a shot, a
## blast, a light-trail wall) counts toward the killer's next charge; a death ends the
## streak, drops any unused charge and ends root; a new life starts as user. A start of root
## (sudo()) is believed only from a living player in its life holding a charge; a forged or
## chargeless one is dropped and counted as "sudo". While a player is root its hits are
## damage_scale() times harder where the session judges them, and its shots and throws spend
## nothing: an empty magazine does not stop them. Every change of a player's sudo state is
## noted (take_sudo_changed()) for the session to tell everyone.
##
## Spectate as top (C23): the host also keeps the match's record for the top table
## (scripts/hud/top_ledger.gd): each player's join order, kills, deaths, the damage it dealt
## (health actually taken off another player, here where every hit lands) and its time alive
## this life, the match's seconds of play and when each kill fell. The session sends it to
## every player once a second.

const Tuning = preload("res://scripts/net/combat_tuning.gd")
const WeaponDefScript = preload("res://scripts/weapons/weapon_def.gd")
const SigstopMeter = preload("res://scripts/abilities/sigstop_meter.gd")
const SigstopTuning = preload("res://scripts/abilities/sigstop_tuning.gd")
const SIGSTOP_TUNING_PATH := "res://resources/sigstop.tres"
const SudoState = preload("res://scripts/abilities/sudo_state.gd")
const SudoTuning = preload("res://scripts/abilities/sudo_overcharge_tuning.gd")
const SUDO_TUNING_PATH := "res://resources/sudo_overcharge.tres"
const TopLedger = preload("res://scripts/hud/top_ledger.gd")

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
const DROP_RELOAD := "reload"
const DROP_EMPTY := "empty"
const DROP_METER := "meter"
const DROP_SIGSTOP := "sigstop"
const DROP_AIM := "aim"
const DROP_LIVE := "live_cap"
const DROP_SUDO := "sudo"
## How far a throw's aim may stray from the view the host last had of the thrower, in degrees:
## the view lags by a send interval and the network's delay.
const AIM_TOLERANCE_DEG := 45.0
## Below a full meter by less than this still counts as full: float sums of shares.
const METER_EPS := 0.0001

var tuning: Tuning
## The weapons every player carries, id -> WeaponDef, the one each starts with (slot 1),
## and the arsenal's swap time.
var weapons := {}
var first_weapon := ""
var swap_s := 0.3
## SIGSTOP's numbers (C18): every player's meter keeps them.
var sigstop_tuning: SigstopTuning
## Root vs user's numbers (C22).
var sudo_tuning: SudoTuning
## Players whose sudo state changed since the session last took them (C22).
var _sudo_changed := {}
## Every player the host knows, id -> {health, dead, respawn_left, protect_left,
## last_fire, last_seq, kills, deaths, drawn, ready_at, reloading, reload_done_at, ammo};
## drawn is the weapon in hand, ready_at when its draw is done, reloading the weapon being
## reloaded ("" for none) and reload_done_at when its rounds go in; ammo is weapon id ->
## {mag, reserve, last_fire}. Times are the host's clock.
var states := {}
## Shots dropped, in all and by reason.
var dropped := 0
var drops := {}
## The match's record for the top table (C23), on the host's clock.
var record := TopLedger.new()


## `weapon_defs`: the arsenal's usable WeaponDefs in slot order; `swap_seconds`: its swap time;
## `stop_tuning`: SIGSTOP's numbers, null for resources/sigstop.tres.
func _init(combat_tuning: Tuning, weapon_defs: Array, swap_seconds: float = 0.3, stop_tuning: Resource = null, root_tuning: Resource = null) -> void:
	tuning = combat_tuning
	swap_s = swap_seconds
	sigstop_tuning = stop_tuning if stop_tuning is SigstopTuning and stop_tuning.problems().is_empty() else load(SIGSTOP_TUNING_PATH)
	sudo_tuning = root_tuning if root_tuning is SudoTuning and root_tuning.problems().is_empty() else load(SUDO_TUNING_PATH)
	for def in weapon_defs:
		weapons[def.id] = def
	first_weapon = weapon_defs[0].id if not weapon_defs.is_empty() else ""


func add_player(id: int) -> void:
	states[id] = {"health": tuning.max_health, "dead": false, "respawn_left": 0.0, "protect_left": 0.0, "last_fire": -INF, "last_seq": 0, "kills": 0, "deaths": 0, "drawn": first_weapon, "ready_at": -INF, "reloading": "", "reload_done_at": 0.0, "ammo": _full_ammo(), "meter": 0.0, "stop": SigstopMeter.new(sigstop_tuning), "sudo": SudoState.new(sudo_tuning)}
	record.join(id)


## The ult of the loadout (C17), or null when it has none.
func ult_def() -> WeaponDefScript:
	for id in weapons:
		if weapons[id].is_ult():
			return weapons[id]
	return null


## `id`'s ult meter as the host counts it.
func meter_of(id: int) -> float:
	return states[id]["meter"] if states.has(id) else 0.0


## Adds to `id`'s ult meter what a hit with another weapon earned: `share` of a target's
## health taken, a kill or not. Capped at full; nothing for a dead player or with no ult.
func add_meter(id: int, share: float, killed: bool) -> void:
	var ult := ult_def()
	if ult == null or not states.has(id) or states[id]["dead"]:
		return
	var meter: float = minf(states[id]["meter"] + ult.meter_gain(share, killed), ult.ult_meter)
	states[id]["meter"] = ult.ult_meter if meter >= ult.ult_meter - METER_EPS else meter  # as the player's own


## `id` asks, in its life `life`, to start (`on`) or end its SIGSTOP: "" when the host
## believes it, otherwise why not, counted. A start needs the meter at its start share
## (DROP_SIGSTOP when it is not); an end is always believed; asking for what already is
## changes nothing.
func sigstop(id: int, life: int, on: bool, known_life: int) -> String:
	var why := _alive_in(id, life, known_life)
	if why != "":
		return why
	var stop: SigstopMeter = states[id]["stop"]
	if not on:
		stop.stop()
		return ""
	if stop.on or stop.start():
		return ""
	return _drop(DROP_SIGSTOP)


## True while `id`'s SIGSTOP is on, as the host counts it: its pellets then fly straight.
func sigstop_on(id: int) -> bool:
	return states.has(id) and states[id]["stop"].on


## Seconds of SIGSTOP left on `id`'s meter, as the host counts it.
func sigstop_meter(id: int) -> float:
	return states[id]["stop"].meter if states.has(id) else 0.0


## Moves every SIGSTOP meter on by `delta` seconds of the host's clock: drained while on,
## refilled while off (not while dead). Returns the ids whose SIGSTOP ran out just now.
func tick_sigstop(delta: float) -> Array:
	var out := []
	for id in states:
		if states[id]["stop"].tick(delta, not states[id]["dead"]):
			out.append(id)
	return out


## `id` asks, in its life `life`, to spend a sudo charge on root (C22): "" when the host
## believes it (root started), otherwise why not, counted: DROP_SUDO with no charge or
## already root.
func sudo(id: int, life: int, known_life: int) -> String:
	var why := _alive_in(id, life, known_life)
	if why != "":
		return why
	if not states[id]["sudo"].activate():
		return _drop(DROP_SUDO)
	_sudo_changed[id] = true
	return ""


## True while `id` is root, as the host counts it.
func root(id: int) -> bool:
	return states.has(id) and states[id]["sudo"].is_root()


## How hard `id`'s hits land now: root's damage_scale, or 1.
func damage_scale(id: int) -> float:
	return states[id]["sudo"].damage_scale() if states.has(id) else 1.0


## `id`'s sudo charges held, and its root seconds left, as the host counts them.
func sudo_charges(id: int) -> int:
	return states[id]["sudo"].charges if states.has(id) else 0


func root_left(id: int) -> float:
	return states[id]["sudo"].root_left if states.has(id) else 0.0


## Moves every player's root on by `delta` seconds of the host's clock. Returns the ids whose
## root ran out just now.
func tick_sudo(delta: float) -> Array:
	var out := []
	for id in states:
		if states[id]["sudo"].tick(delta):
			out.append(id)
			_sudo_changed[id] = true
	return out


## The players whose sudo state changed since the last call, each once.
func take_sudo_changed() -> Array:
	var out := _sudo_changed.keys()
	_sudo_changed = {}
	return out


## The weapon `id` holds, as the host knows it.
func drawn_by(id: int) -> String:
	return states[id]["drawn"] if states.has(id) else ""


## `shooter` started drawing `weapon` in its life `life`: "" when the host believes it,
## otherwise why not, counted. The weapon is in hand from now on and ready after the swap
## time; a reload stops. Drawing the weapon already in hand changes nothing.
func draw(id: int, life: int, weapon: String, known_life: int, now: float) -> String:
	var why := _alive_in(id, life, known_life)
	if why != "":
		return why
	if not weapons.has(weapon):
		return _drop(DROP_WEAPON)
	var s: Dictionary = states[id]
	if weapon == s["drawn"]:
		return ""
	_finish_reload(s, now)  # a reload whose time is up has put its rounds in; only one still running stops
	s["drawn"] = weapon
	s["ready_at"] = now + swap_s * (1.0 - tuning.fire_rate_tolerance)
	s["reloading"] = ""
	return ""


## `id` started reloading `weapon`, the one in hand: "" when the host believes it, otherwise
## why not, counted. Refused, as the player's own inventory refuses it, for a weapon not in
## hand, with no magazine, mid-reload, or with nothing to move. One that arrives while the
## host still counts the draw (the draw was late on the wire, the player had waited it out)
## is taken and starts when the draw is done: never sooner than the player's own could.
func reload(id: int, life: int, weapon: String, known_life: int, now: float) -> String:
	var why := _alive_in(id, life, known_life)
	if why != "":
		return why
	var s: Dictionary = states[id]
	if not weapons.has(weapon) or weapon != s["drawn"]:
		return _drop(DROP_WEAPON)
	_finish_reload(s, now)
	var def: WeaponDefScript = weapons[weapon]
	var a: Dictionary = s["ammo"][weapon]
	if not def.has_magazine() or s["reloading"] != "" or def.reload_take(a["mag"], a["reserve"]) <= 0:
		return _drop(DROP_RELOAD)
	s["reloading"] = weapon
	s["reload_done_at"] = maxf(now, s["ready_at"]) + def.reload_s * (1.0 - tuning.fire_rate_tolerance)
	return ""


## Rounds in the magazine and in reserve `id` has for `weapon` right now, as the host counts
## them: [mag, reserve]; [-1, -1] for no limit or no such thing.
func ammo_of(id: int, weapon: String) -> Array:
	if not states.has(id) or not states[id]["ammo"].has(weapon):
		return [-1, -1]
	var a: Dictionary = states[id]["ammo"][weapon]
	return [a["mag"], a["reserve"]]


func remove_player(id: int) -> void:
	states.erase(id)
	record.leave(id)


func has_player(id: int) -> bool:
	return states.has(id)


func alive(id: int) -> bool:
	return states.has(id) and not states[id]["dead"]


func health_of(id: int) -> float:
	return states[id]["health"] if states.has(id) else 0.0


func protected(id: int) -> bool:
	return states.has(id) and states[id]["protect_left"] > 0.0


## Moves death and protection timers, and the top table's record, on. Returns the ids
## whose respawn is due now.
func tick(delta: float) -> Array:
	record.tick(delta)
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
	if not weapons.has(weapon) or weapon != s["drawn"] or weapons[weapon].is_thrown():
		return _drop(DROP_WEAPON)
	if not dir_ok(dir) or not origin.is_finite() or absf(origin.x) > WORLD_LAST or absf(origin.y) > WORLD_LAST or absf(origin.z) > WORLD_LAST:
		return _drop(DROP_SHAPE)
	if now < s["ready_at"]:
		return _drop(DROP_SWAP)
	var def: WeaponDefScript = weapons[weapon]
	if s["reloading"] == weapon and now < s["reload_done_at"]:
		return _drop(DROP_RELOAD)
	var a: Dictionary = s["ammo"][weapon]
	if not rate_ok(now, a["last_fire"], def.fire_cooldown, tuning.fire_rate_tolerance):
		return _drop(DROP_RATE)
	if def.has_magazine() and not s["sudo"].is_root() and a["mag"] + (def.reload_take(a["mag"], a["reserve"]) if s["reloading"] == weapon else 0) <= 0:
		return _drop(DROP_EMPTY)  # root fires from an empty magazine too (C22)
	if def.is_ult() and s["meter"] < def.ult_meter - METER_EPS:
		return _drop(DROP_METER)
	if not origin_ok(origin, eye, tuning.origin_tolerance_m):
		return _drop(DROP_ORIGIN)
	return ""


## `id` throws `weapon` (the fork bomb, C19) in its life `life` from `origin` along `dir`,
## given the host's view of its eye and of its aim (`view`, a unit vector, or ZERO for none
## known yet: then the aim is not judged), the life the host knows it is in, the clock and the
## bomblets it has live now: "" when the host believes it, the bomb spent; otherwise why not,
## counted.
func throw(id: int, life: int, weapon: String, origin: Vector3, dir: Vector3, eye: Vector3, view: Vector3, known_life: int, now: float, live: int) -> String:
	var why := _alive_in(id, life, known_life)
	if why != "":
		return why
	if not weapons.has(weapon) or not weapons[weapon].is_thrown():
		return _drop(DROP_WEAPON)
	if not dir_ok(dir) or not origin.is_finite() or absf(origin.x) > WORLD_LAST or absf(origin.y) > WORLD_LAST or absf(origin.z) > WORLD_LAST:
		return _drop(DROP_SHAPE)
	var def: WeaponDefScript = weapons[weapon]
	var a: Dictionary = states[id]["ammo"][weapon]
	if not rate_ok(now, a["last_fire"], def.fire_cooldown, tuning.fire_rate_tolerance):
		return _drop(DROP_RATE)
	var root_now: bool = states[id]["sudo"].is_root()
	if a["mag"] <= 0 and not root_now:
		return _drop(DROP_EMPTY)
	if live >= def.projectile.live_cap:
		return _drop(DROP_LIVE)
	if not origin_ok(origin, eye, tuning.origin_tolerance_m):
		return _drop(DROP_ORIGIN)
	if not view.is_zero_approx() and rad_to_deg(view.angle_to(dir)) > AIM_TOLERANCE_DEG:
		return _drop(DROP_AIM)
	if not root_now:
		a["mag"] -= 1  # root throws for free (C22)
	a["last_fire"] = now
	return ""


## Records a believed shot's time and number and spends its round (after a reload whose
## time is up): the next shot is measured from here.
func accept(shooter: int, seq: int, weapon: String, now: float) -> void:
	if not states.has(shooter) or not weapons.has(weapon):
		return
	var s: Dictionary = states[shooter]
	_finish_reload(s, now)
	s["last_fire"] = now
	s["last_seq"] = seq
	var a: Dictionary = s["ammo"][weapon]
	if weapons[weapon].has_magazine() and not s["sudo"].is_root():
		a["mag"] = maxi(a["mag"] - 1, 0)  # root spends nothing (C22)
	if weapons[weapon].is_ult():
		s["meter"] = 0.0  # one full meter, one shot
	a["last_fire"] = now


## Seconds until `id`'s running reload is done, and until its draw is done; 0 for none.
func reload_left(id: int, now: float) -> float:
	if not states.has(id) or states[id]["reloading"] == "":
		return 0.0
	return maxf(states[id]["reload_done_at"] - now, 0.0)


func draw_left(id: int, now: float) -> float:
	return maxf(states[id]["ready_at"] - now, 0.0) if states.has(id) else 0.0


## Puts in the rounds of `id`'s reload if its time is up: before the host reports a count.
func settle(id: int, now: float) -> void:
	if states.has(id):
		_finish_reload(states[id], now)


## Moves a reload's rounds once its time is up.
func _finish_reload(s: Dictionary, now: float) -> void:
	if s["reloading"] == "" or now < s["reload_done_at"]:
		return
	var def: WeaponDefScript = weapons[s["reloading"]]
	var a: Dictionary = s["ammo"][s["reloading"]]
	var take := def.reload_take(a["mag"], a["reserve"])
	a["mag"] += take
	if a["reserve"] != WeaponDefScript.INFINITE:
		a["reserve"] -= take
	s["reloading"] = ""


## "" for a living player in the life the host knows it is in; otherwise why not, counted.
func _alive_in(id: int, life: int, known_life: int) -> String:
	if not states.has(id):
		return _drop(DROP_NO_PLAYER)
	if states[id]["dead"]:
		return _drop(DROP_DEAD)
	if life != known_life:
		return _drop(DROP_LIFE)
	return ""


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
	var before: float = s["health"]
	s["health"] = maxf(s["health"] - amount, 0.0)
	record.hit(killer, victim, before - s["health"])  # dealt: what it actually took (C23)
	var killed: bool = s["health"] <= 0.0
	if killed:
		s["dead"] = true
		s["respawn_left"] = tuning.respawn_delay_s
		s["deaths"] += 1
		s["meter"] = 0.0  # a death empties the ult meter
		s["stop"].empty()  # and the SIGSTOP meter, ending it (C18)
		s["sudo"].die()  # and root, the streak and any unused sudo charge (C22)
		_sudo_changed[victim] = true
		if killer != victim:
			states[killer]["kills"] += 1
			if states[killer]["sudo"].kill():
				_sudo_changed[killer] = true  # a sudo charge earned
		record.kill(killer, victim)
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
	s["reloading"] = ""
	s["ready_at"] = -INF
	s["meter"] = 0.0
	s["sudo"].die()  # every life starts as user (C22)
	_sudo_changed[id] = true
	record.respawn(id)  # its time alive starts again (C23)


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
