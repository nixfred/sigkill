class_name SoloLife
extends Node
## This player's health alone in the arena (C27b): since C14 only a match had player health;
## now that the daemons fight back, the solo player has it too, by the match's own rules and
## numbers. It runs the match's combat authority (scripts/net/combat.gd) for one player and its
## numbers (resources/combat.tres: 100 health, a 3 s respawn, 2 s of spawn protection, the damage
## flash), so a daemon's hit takes health through the same damage path as a match's shot
## (Combat.damage_player, no killer credited), and a death derezzes the player and brings it back
## through the match's flow: the player is set down (set_alive(false), its abilities ended as
## at any death) and its derezz plays where it stood, then after the respawn delay it is put at
## the spawn point farthest from the living daemons, alive, full and protected (respawn_at and
## set_alive(true), as the session's respawn does). Deaths are counted for the round's stats.
##
## Only alone and only while the daemons fight back: in practice nothing hurts the player and its
## health is not shown (the old game), and in a match the session's combat owns every player's
## health. A match starting with this player down brings it back at once. The player's own
## weapons never hurt it alone (the rm -rf cannon's self-damage stays a match's rule).
## Fiction only: a "death" is a game state.

signal hurt(amount: float, health: float, by: Node)
signal died(cause: String)
signal respawned

const Combat = preload("res://scripts/net/combat.gd")
const CombatTuningScript = preload("res://scripts/net/combat_tuning.gd")
const COMBAT_TUNING_PATH := "res://resources/combat.tres"
const DerezzFx = preload("res://scripts/derezz_fx.gd")
const DerezzTuning = preload("res://scripts/derezz_tuning.gd")
const DEREZZ_PATH := "res://resources/derezz.tres"
const NODE_NAME := "SoloLife"
const SPAWNS_NODE := "Arena/Spawns"
## The one player alone, as the combat authority counts it.
const ME := 1
## The player's body for its derezz: its radius and height, its middle above its feet.
const BODY_RADIUS := 0.4
const BODY_HEIGHT := 1.5
const FEET := 0.9

## The player, and the session beside the arena (null alone). Set by main.gd.
var player: Node3D = null
var session: Node = null
## The authority alone, and its numbers.
var combat: Combat
var tuning: CombatTuningScript
## Deaths alone since this arena loaded, and what took the last one ("rogue.d", ...) and which
## daemon it was.
var deaths := 0
var cause := ""
var killer: Node = null
## Seconds of the damage flash left.
var flash_left := 0.0


func _init() -> void:
	name = NODE_NAME


func _ready() -> void:
	tuning = load(COMBAT_TUNING_PATH)
	if not (tuning is CombatTuningScript) or not tuning.problems().is_empty():
		tuning = CombatTuningScript.new()
	combat = Combat.new(tuning, [])
	combat.add_player(ME)


## True while this life is the one that counts: alone, with the daemons fighting back.
func shown() -> bool:
	return not _online() and not _practice()


func alive() -> bool:
	return combat.alive(ME)


func health() -> float:
	return combat.health_of(ME)


func protected() -> bool:
	return combat.protected(ME)


func protect_left() -> float:
	return combat.states[ME]["protect_left"]


func respawn_left() -> float:
	return combat.states[ME]["respawn_left"] if not alive() else 0.0


func max_health() -> float:
	return tuning.max_health


## `amount` of a daemon's damage (`by` the daemon, along `way`): through the combat path; a death
## when it takes the last of the health. True when it took health.
func damage(amount: float, by: Node, way: Vector3) -> bool:
	if not shown() or player == null or not is_instance_valid(player) or not player.alive:
		return false
	var before := combat.health_of(ME)
	var outcome := combat.damage_player(ME, ME, amount)
	if outcome.is_empty():
		return false
	var taken: float = before - outcome["health"]  # what it actually took, never past 0 (Codex review)
	flash_left = tuning.damage_flash_s
	if player.has_method("take_hit"):
		player.take_hit(taken)
	hurt.emit(taken, outcome["health"], by)
	if outcome["killed"]:
		killer = by
		_die(String(by.get("tag_text")) if by != null else "", way)
	return true


func _physics_process(delta: float) -> void:
	flash_left = maxf(flash_left - delta, 0.0)
	if _online():
		if not alive():
			# A match began with the player down alone: that death is over, the match owns the
			# life now, and it counts this player alive unless its own word says down (Codex
			# review): hosting adds the host alive, a join adds the joiner alive.
			combat.respawn(ME)
			if player != null and is_instance_valid(player) and not player.alive and not session.dead.get(session.my_id, false):
				player.set_alive(true)
		return
	for id in combat.tick(delta):
		if id == ME:
			_respawn(true)


## A new round alone: full health at once (a player down comes back now). In a match the
## session owns the player's life and the round leaves it alone (Codex review).
func reset_for_round() -> void:
	if _online():
		return
	_respawn(not alive())


func _die(what: String, way: Vector3) -> void:
	deaths += 1
	cause = what
	if player.has_method("set_alive"):
		player.set_alive(false)
	var d = load(DEREZZ_PATH)
	if not (d is DerezzTuning) or not d.problems().is_empty():
		d = DerezzTuning.new()
	var fx := DerezzFx.new()
	var root := get_parent() if get_parent() != null else self
	root.add_child(fx)
	var along := Vector3(way.x, 0.0, way.z)
	fx.start(player.global_position + Vector3.DOWN * FEET, BODY_RADIUS, BODY_HEIGHT, along.normalized() if not along.is_zero_approx() else Vector3.FORWARD, d)
	died.emit(what)


## Back at full health and protected; `move` puts the player at the spawn farthest from the
## living daemons first (a death's respawn), else it stays where it is.
func _respawn(move: bool) -> void:
	combat.respawn(ME)
	if player == null or not is_instance_valid(player):
		return
	if move and player.has_method("respawn_at"):
		player.respawn_at(_spawn_point())
	if player.has_method("set_alive") and not player.alive:
		player.set_alive(true)
	respawned.emit()


## The arena's spawn point farthest from the nearest living daemon (world space); where the
## player stands when the arena has none.
func _spawn_point() -> Vector3:
	var main := get_parent()
	var spawns := []
	var node := main.get_node_or_null(SPAWNS_NODE) if main != null else null
	if node != null:
		for marker in node.get_children():
			if marker is Node3D:
				spawns.append((marker as Node3D).global_position)
	if spawns.is_empty():
		return player.global_position
	var threats := []
	for dummy in get_tree().get_nodes_in_group(DaemonDirector.TARGET_GROUP):
		if main.is_ancestor_of(dummy) and dummy.has_method("is_alive") and dummy.is_alive():
			threats.append((dummy as Node3D).global_position)
	return Combat.farthest_spawn(spawns, threats)


func _online() -> bool:
	return session != null and is_instance_valid(session) and session.is_online()


func _practice() -> bool:
	return GameSettings.current().value("gameplay", "practice") == true
