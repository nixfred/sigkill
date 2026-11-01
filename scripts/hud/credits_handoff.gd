class_name CreditsHandoff
extends Control
## The hand-off from the finale to the credits (M7, docs/STORY.md section 7; the roll since C44): the mission HUD's own,
## what the finale's win flows into whichever way its card is left (scripts/missions/mission_runner.gd, roll_credits()).
## It puts up the credits roll (scripts/credits/credits_roll.gd: the cast as processes in a live `top`, Fred as PID 1,
## the player's own kill -9, SIGKILL on the hexagon, the bare `>_` after), keeps the player's input stopped while it
## plays, and as it ends hands the player on to where they asked (the runner's after_credits(): the Missions screen,
## the campaign finished and replayable, every unlock kept; or free play). Once per ending: the runner says so.
## Draws nothing itself; nothing here names the player or reads anything.

signal finished

var runner: MissionRunner = null

var _roll: CreditsRoll = null
var _blocked: Node = null


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_roll = CreditsRoll.new()
	_roll.name = "CreditsRoll"
	add_child(_roll)
	_roll.finished.connect(_on_roll_finished)


## The roll up from its first frame, for the ending.
func open() -> void:
	if is_up():
		return
	_block(true)
	_roll.open("ending")


func is_up() -> bool:
	return _roll != null and _roll.is_up()


## The roll itself (the checks and the capture tool).
func roll() -> CreditsRoll:
	return _roll


## True while the bare prompt (STORY.md's moment after the credits) is on.
func at_prompt() -> bool:
	return _roll != null and _roll.at_prompt()


## Esc's: on to the bare prompt now, or past it.
func skip() -> void:
	if _roll != null:
		_roll.skip()


## Every line the roll shows now, for the checks.
func shown_text() -> PackedStringArray:
	return _roll.shown_text() if _roll != null else PackedStringArray()


func _on_roll_finished(_skipped: bool) -> void:
	_block(false)
	finished.emit()


func _block(on: bool) -> void:
	var player = runner.player if runner != null and is_instance_valid(runner) else null
	if on and player != null and is_instance_valid(player) and "input_blocked" in player:
		player.input_blocked = true
		_blocked = player
	elif not on and _blocked != null and is_instance_valid(_blocked):
		_blocked.input_blocked = false
		_blocked = null
