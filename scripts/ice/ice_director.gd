class_name IceDirector
extends Node3D
## ICE (I1): William Gibson's intrusion countermeasure electronics, the system defending itself
## against the player, the intruder. A new enemy class beside the daemons: white ICE (walls that seal
## a doorway and a corridor of the arena until enough damage breaks them, and two nodes whose fields
## jam a weapon or corrupt the HUD) from round 1, and hunter ICE (scripts/ice/hunter_ice.gd: it hunts
## by sight and adapts to the weapon used most) from round 2. One of these lives beside the arena
## (main.gd makes it, next to the daemons' director): it builds every piece at its place each round
## from new seeds (fixed by name in demo, test and capture runs), steps them, judges what lands on
## them, keeps the round's adaptation, puts the fields' effects on the players, and in a match is the
## host's word on all of it.
##
## Its mode: RUN alone or hosting (it decides), FOLLOW on a joiner (its pieces play the host's word
## and judge nothing; the host judges every shot at them and sends its word, take_word()), OFF in
## practice or with the ICE setting off (no piece at all: nothing seals, jams or hunts). Alone the
## settings decide; in a match the host's (its practice and its ICE setting, as its difficulty).
##
## Adaptation: every hit that lands on the system (a daemon or a piece of ICE) notes its weapon's
## damage for the round, each hit counted up to the tuning's hit_cap (the most any one hit takes off
## ICE), so a rail's 1000 counts as 100. The hunter resists the weapon with the most, adapt_max times
## its share of adapt_full_damage (never more than adapt_max: never immunity), and its shields shift
## toward that weapon's colour; the HUD shows "HUNTER ADAPTED: <weapon> -NN%". In a match it learns
## from every intruder's hits together (the host judges them all). A new round forgets it.
##
## Fields: a node's field reaches the intruders inside its dome when its tell ends (scripts/ice/
## ice_node.gd). Alone, this player; hosting, each player in it: the host's own here, a joiner's by
## the session's word to that joiner (session.ice_effect()), the host remembering a joiner's jam so
## it refuses that weapon's shots until it clears. A jam (jam_s) locks the weapon in hand (the others
## still swap in and fire); a corruption (hud_s) scrambles parts of the HUD, never the health line.
##
## Everything is simulated: ICE reads nothing real and touches nothing real.

const Dummy = preload("res://scripts/target_dummy.gd")
const Palette = preload("res://scripts/palette.gd")
const ForkBomb = preload("res://scripts/weapons/fork_bomb.gd")

const GROUP := &"ice_director"
const NODE_NAME := "IceDirector"
## Every piece of ICE joins this group: the host judges joiners' shots at them, blasts reach them.
const PIECES := &"ice"
const TUNING_PATH := "res://resources/ice.tres"
const ARSENAL_PATH := "res://resources/arsenal.tres"
enum Mode { OFF, RUN, FOLLOW }
## A field's effect on a player: its weapon jammed, its HUD corrupted.
enum Effect { JAM, HUD }
## The layout, in arena space. Walls: name, the middle of its foot, its yaw, its opening (width,
## height). The gate seals the room's doorway (between its posts); the wall seals the west corridor's
## north end (between the west wall and the cover).
const WALLS := [["gate", Vector3(0.0, 0.0, -8.0), 0.0, Vector2(2.7, 3.5)], ["wall", Vector3(-17.6, 0.0, 8.0), 0.0, Vector2(4.8, 3.0)]]
## Nodes: name, place, kind. The jam node guards the gate; the HUD node stands south of the corridor.
const NODES := [["jam", Vector3(-4.5, 0.0, -4.5), "jam"], ["hud", Vector3(-17.5, 0.0, -2.0), "hud"]]
## The hunter's post, and the point it faces from there.
const HUNTER_POST := Vector3(10.0, 0.0, -4.0)
const HUNTER_FACES := Vector3(0.0, 0.0, 5.0)
## The pieces in the host's word, in order: the walls, the nodes, the hunter.
const PIECE_COUNT := 4 + 1
## A hunter's word when there is none.
const NO_HUNTER := 0xFF
## I2's brute ICEbreaker: a hit of this source cracks a wall this many times harder (the hook only).
const BRUTE := "breaker:brute"
const BRUTE_SCALE := 3.0
## How far toward an adapted weapon's colour the hunter's shields go at the most.
const TINT_SHARE := 0.85
## The hunter's adaptation as the HUD writes it.
const ADAPT_LINE := "HUNTER ADAPTED: %s -%d%%"

## This player's own field effects as they land: Effect, seconds.
signal effect_fired(kind: int, seconds: float)

## An IceTuning; null for resources/ice.tres. Set before the node enters the tree.
var tuning: IceTuning
## The daemons' director (who the intruders are, where, sight, the attacker cap, the combat path),
## the local player, its solo life, the session beside the arena (null alone) and the round HUD.
## Set by main.gd.
var daemons: Node = null
var player: Node3D = null
var life: Node = null
var session: Node = null
var rounds: Node = null
var mode: Mode = Mode.OFF
var round_number := 1

var walls: Array[IceBarrier] = []
var nodes: Array[IceNode] = []
## The hunter now (null before its round, or once its replacement is due), and the wait before a
## killed one's replacement comes.
var hunter: HunterIce = null
var hunter_wait := 0.0
## Hunters spawned and killed since this director was made, for the checks.
var hunters_made := 0
var hunters_killed := 0

## Damage each weapon has dealt to the system this round, weapon id -> health points.
var ledger := {}
var adapt_weapon := ""
var adapt := 0.0
## This player's HUD corruption: seconds left; and the effects that reached this player.
var corrupt_left := 0.0
var jams_on_me := 0
var corruptions_on_me := 0
## Host: each joiner's jam, id -> [weapon id, seconds left].
var _jams := {}

var _rng := RandomNumberGenerator.new()
var _weapons := {}
static var _field_mat: ShaderMaterial


static func of(node: Node) -> IceDirector:
	if node == null or not node.is_inside_tree():
		return null
	for d in node.get_tree().get_nodes_in_group(GROUP):
		var host := (d as Node).get_parent()
		if host != null and (host == node or host.is_ancestor_of(node)):
			return d
	return null


func _init() -> void:
	name = NODE_NAME


func _ready() -> void:
	add_to_group(GROUP)
	tuning = IceTuning.usable(tuning)
	_rng.randomize()
	var arsenal := load(ARSENAL_PATH) as ArsenalTuning
	if arsenal != null:
		for def in arsenal.loadout:
			_weapons[def.id] = def
	if rounds != null and rounds.get("stats") != null:
		round_number = rounds.stats.round_number
	if rounds != null and rounds.has_signal("round_started"):
		rounds.round_started.connect(start_round)
	_mode_now()


## The field domes' one material, every node's.
func field_material() -> ShaderMaterial:
	if _field_mat == null:
		_field_mat = Palette.ice_field_material()
	return _field_mat


# --- Its mode. ---

## True while ICE is on: not practice, and the ICE setting on (alone and hosting, the settings'; on a
## joiner, the host's word).
func ice_on() -> bool:
	if _online() and not session.is_hosting():
		return session.host_practice != true and session.host_ice == true
	var s := GameSettings.current()
	return s.value("gameplay", "practice") != true and s.value("gameplay", "ice") == true


## True while this machine decides: alone or hosting, ICE on.
func decides() -> bool:
	return mode == Mode.RUN


func follows() -> bool:
	return mode == Mode.FOLLOW


func _online() -> bool:
	return session != null and is_instance_valid(session) and session.is_online()


func _mode_now() -> void:
	var next := Mode.OFF
	if ice_on():
		next = Mode.FOLLOW if _online() and not session.is_hosting() else Mode.RUN
	if next == mode:
		return
	mode = next
	clear_effects()
	_jams.clear()
	_forget()
	_build_round()


# --- Rounds. ---

## Round `number` starts (the round HUD's word): the adaptation forgotten and, deciding, every piece
## built again from new seeds, a hunter at its post from its round on.
func start_round(number: int) -> void:
	round_number = maxi(number, 1)
	_forget()
	if mode == Mode.RUN:
		_build_round()


func _forget() -> void:
	ledger.clear()
	_set_adapt("", 0.0)


func _build_round() -> void:
	_clear_pieces()
	if mode == Mode.OFF:
		return
	for i in WALLS.size():
		walls.append(_make_wall(i, _seed_for(WALLS[i][0])))
	for i in NODES.size():
		nodes.append(_make_node(i, _seed_for(NODES[i][0])))
	hunter_wait = 0.0
	if mode == Mode.RUN and round_number >= tuning.hunter_from_round:
		_spawn_hunter(_seed_for("hunter"))


## A piece's seed: fixed by its name in demo, test and capture runs (and placeholders on a joiner until
## the host's word), else a new one each build.
func _seed_for(piece: String) -> int:
	if Dummy.fixed_seeds or mode == Mode.FOLLOW:
		return DaemonArt.seed_of("ice:" + piece)
	return _rng.randi() & DaemonArt.SEED_LAST


func _make_wall(i: int, seed: int) -> IceBarrier:
	var w := IceBarrier.new()
	w.name = "Ice" + String(WALLS[i][0]).capitalize()
	w.piece_name = WALLS[i][0]
	w.span = WALLS[i][3]
	w.spawn_seed = seed
	w.max_health = tuning.barrier_health
	w.director = self
	w.position = WALLS[i][1]
	w.rotation.y = WALLS[i][2]
	w.add_to_group(PIECES)
	add_child(w)
	return w


func _make_node(i: int, seed: int) -> IceNode:
	var n := IceNode.new()
	n.name = "IceNode" + String(NODES[i][0]).capitalize()
	n.piece_name = NODES[i][0]
	n.kind = NODES[i][2]
	n.spawn_seed = seed
	n.tuning = tuning
	n.max_health = tuning.node_health
	n.director = self
	n.position = NODES[i][1]
	n.add_to_group(PIECES)
	add_child(n)
	return n


func _spawn_hunter(seed: int) -> void:
	if hunter != null and is_instance_valid(hunter):
		_drop_hunter()
	var h := HunterIce.new()
	h.name = "HunterIce"
	h.piece_name = "hunter"
	h.spawn_seed = seed
	h.tuning = tuning
	h.max_health = tuning.hunter_health
	h.director = self
	h.position = HUNTER_POST
	var way := HUNTER_FACES - HUNTER_POST
	h.rotation.y = atan2(-way.x, -way.z)
	h.add_to_group(PIECES)
	add_child(h)
	h.broke.connect(_on_hunter_broke)
	h.tint_to(adapt_color())
	hunter = h
	hunters_made += 1


func _drop_hunter() -> void:
	if hunter != null and is_instance_valid(hunter):
		if hunter.brain != null and daemons != null:
			hunter.brain._release(daemons)
		hunter.remove_from_group(PIECES)
		hunter.queue_free()
	hunter = null


func _on_hunter_broke(_piece: Node3D) -> void:
	hunters_killed += 1
	hunter_wait = tuning.hunter_respawn_s
	if hunter != null and hunter.brain != null and daemons != null:
		hunter.brain._release(daemons)


func _clear_pieces() -> void:
	for piece in pieces():
		piece.remove_from_group(PIECES)
		piece.queue_free()
	walls.clear()
	nodes.clear()
	hunter = null
	hunter_wait = 0.0


## Every piece of ICE now, broken ones included: the walls, the nodes, the hunter.
func pieces() -> Array:
	var out: Array = []
	out.append_array(walls)
	out.append_array(nodes)
	if hunter != null and is_instance_valid(hunter):
		out.append(hunter)
	return out


func wall(piece: String) -> IceBarrier:
	for w in walls:
		if w.piece_name == piece:
			return w
	return null


func node_of(kind: String) -> IceNode:
	for n in nodes:
		if n.kind == kind:
			return n
	return null


# --- Each step. ---

func _physics_process(delta: float) -> void:
	_mode_now()
	corrupt_left = maxf(corrupt_left - delta, 0.0)
	if not _jams.is_empty():
		for id in _jams.keys():
			_jams[id][1] -= delta
			if _jams[id][1] <= 0.0:
				_jams.erase(id)
	if mode == Mode.OFF or daemons == null:
		return
	if mode == Mode.RUN:
		for n in nodes:
			n.step(delta, daemons, self)
		if hunter != null and is_instance_valid(hunter):
			hunter.brain.step(delta, daemons)
			if hunter.broken:
				hunter_wait -= delta
				if hunter_wait <= 0.0:
					_spawn_hunter(_seed_for("hunter"))
		elif round_number >= tuning.hunter_from_round:
			_spawn_hunter(_seed_for("hunter"))
		return
	for n in nodes:
		n.follow(delta)
	if hunter != null and is_instance_valid(hunter) and not hunter.broken:
		hunter.brain.follow(delta, daemons)


# --- Judging what lands. ---

## What a hit of `damage` from `source` takes off `piece`: never more than hit_cap (a brute
## ICEbreaker's hit on a wall harder, I2's hook), the hunter's resistance to its adapted weapon (as it
## stood before this hit) off it; then the weapon's damage is noted for the round. Deciding only.
func take(piece: Node, damage: float, source: String) -> float:
	if mode != Mode.RUN or not is_finite(damage) or damage <= 0.0:
		return 0.0
	var amount := minf(damage, tuning.hit_cap)
	if source == BRUTE and piece is IceBarrier:
		amount = minf(damage * BRUTE_SCALE, tuning.hit_cap * BRUTE_SCALE)
	if piece == hunter:
		amount *= 1.0 - resist_for(source)
	note_damage(source, minf(damage, tuning.hit_cap))
	return amount


## `amount` of damage from weapon `source` landed on the system (a daemon or a piece of ICE): noted for
## the round's adaptation, at most hit_cap of it. Deciding only; an unknown source counts for nothing.
func note_damage(source: String, amount: float) -> void:
	if mode != Mode.RUN or source == "" or not is_finite(amount) or amount <= 0.0:
		return
	ledger[source] = float(ledger.get(source, 0.0)) + minf(amount, tuning.hit_cap)
	var top := ""
	var most := 0.0
	for k in ledger:
		if ledger[k] > most or (ledger[k] == most and String(k) < top):
			top = k
			most = ledger[k]
	_set_adapt(top, tuning.adapt_max * clampf(most / tuning.adapt_full_damage, 0.0, 1.0))


func _set_adapt(weapon: String, amount: float) -> void:
	adapt_weapon = weapon
	adapt = clampf(amount, 0.0, tuning.adapt_max if tuning != null else 0.5)
	if hunter != null and is_instance_valid(hunter):
		hunter.tint_to(adapt_color())


## The hunter's resistance to a hit from `source` now: its adaptation when that is its weapon.
func resist_for(source: String) -> float:
	return adapt if source != "" and source == adapt_weapon else 0.0


func adapt_percent() -> int:
	return roundi(adapt * 100.0)


## The hunter's shields' colour now: cobalt, shifted toward its adapted weapon's own colour as far as
## its adaptation has come.
func adapt_color() -> Color:
	var def = _weapons.get(adapt_weapon)
	if def == null or tuning == null or tuning.adapt_max <= 0.0:
		return Palette.HUNTER_COBALT
	return Palette.HUNTER_COBALT.lerp(def.skin_body(), clampf(adapt / tuning.adapt_max, 0.0, 1.0) * TINT_SHARE)


## The HUD's line: "HUNTER ADAPTED: <weapon> -NN%" while a hunter has adapted this round, else "".
func adapt_text() -> String:
	if mode == Mode.OFF or adapt_percent() <= 0 or round_number < tuning.hunter_from_round:
		return ""
	var def = _weapons.get(adapt_weapon)
	return ADAPT_LINE % [def.short_name if def != null else adapt_weapon, adapt_percent()]


## A blast at `at` (world space) on every piece of ICE standing: each takes `base_at` of its distance
## to where the blast meets it (blast_point()), times `scale`, from `source`, with nothing of the
## level between, as a daemon in a blast does. `space` is the world's physics. How many it hurt.
func blast(at: Vector3, base_at: Callable, scale: float, source: String, space: PhysicsDirectSpaceState3D) -> int:
	if mode != Mode.RUN:
		return 0
	var hurt := 0
	for piece in pieces():
		if piece.broken:
			continue
		var point: Vector3 = piece.blast_point(at)
		var base: float = base_at.call(at.distance_to(point))
		if base <= 0.0:
			continue
		var from := at + Vector3.UP * ForkBomb.SIGHT_LIFT_M
		if not space.intersect_ray(PhysicsRayQueryParameters3D.create(from, point, IcePiece.LEVEL_LAYER)).is_empty():
			continue  # a wall between: the blast does not reach
		if piece.hit(base * scale, point, (point - at).normalized(), source):
			hurt += 1
	return hurt


# --- Fields. ---

## Node `node`'s field fired, reaching the players `ids`: each takes its effect. How many.
func strike(node: IceNode, ids: Array) -> int:
	var kind := Effect.JAM if node.kind == IceNode.JAM else Effect.HUD
	var seconds := node.effect_s()
	var n := 0
	for id in ids:
		if _online():
			if id == session.my_id:
				take_effect(kind, seconds, "")
			elif session.has_method("ice_effect"):
				var weapon := ""
				if kind == Effect.JAM and session.combat != null:
					weapon = session.combat.drawn_by(id)
					_jams[id] = [weapon, seconds]
				session.ice_effect(id, kind, seconds, weapon)
		elif id == 1:
			take_effect(kind, seconds, "")
		n += 1
	return n


## A field's effect on this player: `kind` for `seconds`; a jam on `weapon` (its id; "" the one in
## hand).
func take_effect(kind: int, seconds: float, weapon: String) -> void:
	if not is_finite(seconds) or seconds <= 0.0:
		return
	if kind == Effect.JAM:
		jams_on_me += 1
		if player != null and is_instance_valid(player) and player.has_method("ice_jam"):
			player.ice_jam(weapon, seconds)
	else:
		corruptions_on_me += 1
		corrupt_left = maxf(corrupt_left, seconds)
	effect_fired.emit(kind, seconds)


## True while the HUD is corrupted here.
func corrupting() -> bool:
	return corrupt_left > 0.0


## Host: true while joiner `id`'s `weapon` is jammed by a field (its shots with it are refused).
func jammed(id: int, weapon: String) -> bool:
	return _jams.has(id) and _jams[id][0] == weapon


## Every effect on this player cleared (ICE off, a mode's change).
func clear_effects() -> void:
	corrupt_left = 0.0
	if player != null and is_instance_valid(player) and player.has_method("clear_ice_jams"):
		player.clear_ice_jams()


# --- The host's word (a match). ---

## The host's word on every piece, for the session to send: the round, each piece's seed, health,
## word (a wall 1 broken; a node its state; the hunter its brain's state, SIGSTOP's hold in the top bit,
## NO_HUNTER for none) and seconds into it; the hunter's place and yaw, its aim (arena space) and how
## far its trace or lance reaches; the adaptation's weapon and percent.
func word() -> Dictionary:
	var seeds := PackedInt32Array()
	var healths := PackedFloat32Array()
	var words := PackedByteArray()
	var times := PackedFloat32Array()
	for w in walls:
		seeds.append(w.build_seed)
		healths.append(w.health())
		words.append(1 if w.broken else 0)
		times.append(0.0)
	for n in nodes:
		seeds.append(n.build_seed)
		healths.append(n.health())
		words.append(int(n.state))
		times.append(minf(n.state_t, 1000.0))
	var place := PackedFloat32Array([0.0, 0.0, 0.0, 0.0, 0.0, 0.0, -1.0, 0.0])
	if hunter != null and is_instance_valid(hunter):
		seeds.append(hunter.build_seed)
		healths.append(hunter.health())
		var frozen: bool = daemons != null and daemons.frozen(hunter.brain.prey)
		words.append(int(hunter.brain.state) | (0x80 if frozen else 0))
		times.append(minf(hunter.brain.state_t, 1000.0))
		var at := to_local(hunter.global_position)
		var aim := (global_transform.basis.inverse() * hunter.brain.aim).normalized()
		place = PackedFloat32Array([at.x, at.y, at.z, hunter.global_rotation.y, aim.x, aim.y, aim.z, hunter.reach_now])
	else:
		seeds.append(0)
		healths.append(0.0)
		words.append(NO_HUNTER)
		times.append(0.0)
	return {"round": round_number, "seeds": seeds, "healths": healths, "words": words, "times": times, "hunter": place, "weapon": adapt_weapon, "percent": adapt_percent()}


## The host's word, on a joiner (the session has checked its shape): every piece follows it, rebuilt
## first when its seed is new.
func take_word(round: int, seeds: PackedInt32Array, healths: PackedFloat32Array, words: PackedByteArray, times: PackedFloat32Array, place: PackedFloat32Array, weapon: String, percent: int) -> void:
	if mode != Mode.FOLLOW:
		return
	if round != round_number:
		round_number = round
	if walls.size() != WALLS.size() or nodes.size() != NODES.size():
		_build_round()
	for i in walls.size():
		if seeds[i] != walls[i].build_seed:
			walls[i].remove_from_group(PIECES)
			walls[i].queue_free()
			walls[i] = _make_wall(i, seeds[i])
		walls[i].take_health(healths[i], words[i] == 1)
	for j in nodes.size():
		var k := walls.size() + j
		if seeds[k] != nodes[j].build_seed:
			nodes[j].remove_from_group(PIECES)
			nodes[j].queue_free()
			nodes[j] = _make_node(j, seeds[k])
		nodes[j].take_health(healths[k], healths[k] <= 0.0)
		nodes[j].take_word(words[k], times[k])
	var h := PIECE_COUNT - 1
	if words[h] == NO_HUNTER:
		_drop_hunter()
	else:
		if hunter == null or not is_instance_valid(hunter) or hunter.build_seed != seeds[h]:
			_spawn_hunter(seeds[h])
		var state := words[h] & 0x7f
		hunter.brain.take_word(Vector3(place[0], place[1], place[2]), place[3], state, times[h], (words[h] & 0x80) != 0)
		hunter.brain.take_aim((global_transform.basis * Vector3(place[4], place[5], place[6])).normalized())
		hunter.reach_now = place[7]
		hunter.take_health(healths[h], state == DaemonBrain.State.DOWN)
	adapt_weapon = weapon
	adapt = clampf(percent / 100.0, 0.0, tuning.adapt_max)
	if hunter != null and is_instance_valid(hunter):
		hunter.tint_to(adapt_color())
