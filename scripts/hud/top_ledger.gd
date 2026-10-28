extends RefCounted
## The record a top table (C23, spectate as top) is built from, for one match or, alone, one
## arena: every process's join order, kills, deaths, damage dealt and time alive this life,
## the seconds of play since it started, and when each credited kill fell, for the load
## average. Pure bookkeeping on game time: no node, no clock of its own, nothing real. The
## host keeps one in its combat authority (scripts/net/combat.gd) for every player, fed where
## it applies damage and respawns; alone, the table (scripts/hud/spectate_top.gd) keeps one for
## the player and the dummies. A process's game PID is the table's base plus its join order.

## Seconds of play since the match (or the arena) started.
var uptime := 0.0
## Every process, key -> {order, kills, deaths, dealt, alive_s, dead}.
var rows := {}

var _joins := 0
## The uptime of every credited kill, oldest first; only the longest load window's are kept.
var _kills_at: Array[float] = []


## A process joins: the next join order, nothing counted yet, alive. Once per key.
func join(key: Variant) -> void:
	if rows.has(key):
		return
	rows[key] = {"order": _joins, "kills": 0, "deaths": 0, "dealt": 0.0, "alive_s": 0.0, "dead": false}
	_joins += 1


func leave(key: Variant) -> void:
	rows.erase(key)


## `dealer` took `amount` of health off `victim`: damage it dealt, unless it hurt itself.
func hit(dealer: Variant, victim: Variant, amount: float) -> void:
	if dealer == victim or not rows.has(dealer) or not is_finite(amount) or amount <= 0.0:
		return
	rows[dealer]["dealt"] += amount


## `victim` went down to `killer`: a death, and a kill credited unless it killed itself.
func kill(killer: Variant, victim: Variant) -> void:
	if rows.has(victim):
		rows[victim]["deaths"] += 1
		rows[victim]["dead"] = true
	if killer != victim and rows.has(killer):
		rows[killer]["kills"] += 1
		_kills_at.append(uptime)


## A new life: alive, its time alive from 0.
func respawn(key: Variant) -> void:
	if rows.has(key):
		rows[key]["dead"] = false
		rows[key]["alive_s"] = 0.0


## `delta` seconds of play: the uptime and every living process's time alive move on.
func tick(delta: float) -> void:
	if not is_finite(delta) or delta <= 0.0:
		return
	uptime += delta
	for key in rows:
		if not rows[key]["dead"]:
			rows[key]["alive_s"] += delta


## The credited kills within each of `windows` (seconds of play, shortest first) up to now:
## top's three load numbers. Kills older than the longest window are forgotten.
func load_counts(windows: Array) -> PackedInt32Array:
	var longest := 0.0
	for w in windows:
		longest = maxf(longest, w)
	while not _kills_at.is_empty() and _kills_at[0] <= uptime - longest:
		_kills_at.pop_front()
	var out := PackedInt32Array()
	for w in windows:
		var n := 0
		for at in _kills_at:
			if at > uptime - w:
				n += 1
		out.append(n)
	return out
