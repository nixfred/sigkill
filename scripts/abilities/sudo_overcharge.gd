extends Node
## Root vs user and sudo overcharge (C22, PRD 5.3 and 5.2), the player's ability. Every
## life starts as user ("user$" on the HUD). Kills in one life earn a sudo charge (the rules:
## scripts/abilities/sudo_state.gd, the numbers: resources/sudo_overcharge.tres); Z (rebindable
## in the settings) spends it: the HUD shows the cosmetic "[sudo] password for user: ********"
## for a moment and then "root#" for the root time, while the weapon in hand, whichever it is,
## hits harder and spends no ammo, and glows root's red. One of these lives under the player
## (scripts/player.gd makes it), beside SIGSTOP and code-rain vision.
##
## Alone it is all here: this player's own dummy kills count (the arena tells it,
## local_kill()), a press with a charge starts root, and its timer ends it. In a match the
## host owns it, as every other rule: kills count only as the host credits them, a press is
## only a request (the intent signal, sent by scripts/net/net_session.gd) and root starts and
## ends only on the host's word (take_host()); the host alone applies the harder hits and the
## free ammo where it judges shots. This side shows the host's word and counts its root down
## between words. Root also ends at a death, at a respawn and on leaving a match.
##
## Fiction only: nothing real is run, called or read. No sudo command exists anywhere in the
## game; "user" is a fixed word, never the name of anyone on this machine.

## Root came on (the password line first), and went off.
signal activated
signal ended
## A sudo charge was earned.
signal granted
## In a match: this player asks the host to start root.
signal intent

const TuningScript = preload("res://scripts/abilities/sudo_overcharge_tuning.gd")
const SudoState = preload("res://scripts/abilities/sudo_state.gd")
const DEFAULT_TUNING_PATH := "res://resources/sudo_overcharge.tres"

## A SudoOverchargeTuning; null for resources/sudo_overcharge.tres. Set before the node
## enters the tree.
var tuning: Resource = null
## The session beside the arena (scripts/net/net_session.gd), set by it when it attaches.
var session: Node = null
## The rules: this player's own alone, in a match a copy of the host's word.
var state: SudoState

var _t: TuningScript
var _press := false
var _was_online := false
var _password_left := 0.0


static func usable_tuning(candidate: Resource) -> TuningScript:
	if candidate is TuningScript:
		var issues: PackedStringArray = candidate.problems()
		if issues.is_empty():
			return candidate
		for issue in issues:
			push_warning("sudo overcharge tuning: " + issue + "; using the shipped tuning instead")
	var shipped = load(DEFAULT_TUNING_PATH)
	if shipped is TuningScript and shipped.problems().is_empty():
		return shipped
	return TuningScript.new()


func _ready() -> void:
	_t = usable_tuning(tuning)
	state = SudoState.new(_t)


func tuning_in_use() -> TuningScript:
	return _t


## Z: spend a sudo charge on root. Taken on the next physics frame. Nothing with no charge,
## while root, derezzed or with the player's input stopped.
func press() -> void:
	_press = true


func is_root() -> bool:
	return state.is_root()


func charges() -> int:
	return state.charges


func root_left() -> float:
	return state.root_left


## How hard the weapon in hand hits now, as a multiple of its own damage.
func damage_scale() -> float:
	return state.damage_scale()


## True while the cosmetic password line shows, just after root starts.
func showing_password() -> bool:
	return _password_left > 0.0


## A daemon of this arena derezzed by this player, alone: a kill toward the next charge. In a
## match only the host's word counts.
func local_kill() -> void:
	if not _online() and state.kill():
		granted.emit()


## A death: root over, the streak and every unused charge gone (in a match the host does the
## same and says so).
func on_death() -> void:
	var was := state.is_root()
	state.die()
	_password_left = 0.0
	if was:
		ended.emit()


## A respawn: root over, the charges kept.
func end_root() -> void:
	_password_left = 0.0
	if state.end_root():
		ended.emit()


## The host's word in a match: this player's sudo charges and the root it has left (0: user).
## A word handed over by the session (an arena back from an R reload) counts as the match
## already seen, so the first frame's change to online never wipes it.
func take_host(charges_now: int, left: float) -> void:
	_was_online = _online()
	var was := state.is_root()
	var had := state.charges
	state.charges = charges_now
	state.root_left = left
	if charges_now > had:
		granted.emit()
	if left > 0.0 and not was:
		_password_left = _t.password_s
		activated.emit()
	elif was and left <= 0.0:
		_password_left = 0.0
		ended.emit()


func _physics_process(_delta: float) -> void:
	var real := 1.0 / maxf(float(Engine.physics_ticks_per_second), 1.0)
	var player := get_parent()
	var alive: bool = player == null or player.get("alive") != false
	var blocked: bool = player != null and player.get("input_blocked") == true
	var online := _online()
	if online != _was_online:
		# A match starting or ending: a fresh user either way (in a match the host's word
		# follows).
		_was_online = online
		on_death()
	var pressed := _press
	_press = false
	if pressed and alive and not blocked and state.can_activate():
		if online:
			intent.emit()  # only a request: the host decides
		elif state.activate():
			_password_left = _t.password_s
			activated.emit()
	_password_left = maxf(_password_left - real, 0.0)
	if state.tick(real):
		ended.emit()  # alone the timer ends it; in a match the host's word follows


func _online() -> bool:
	return session != null and is_instance_valid(session) and session.has_method("is_online") and session.is_online()
