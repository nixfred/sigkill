extends Node3D
## Root of the prototype level. Wires targets and the player to the HUD,
## and handles "respawn all targets" (reloads the scene).

const Controls = preload("res://scripts/controls.gd")

var _remaining := 0
var _total := 0

# Untyped on purpose: these call methods defined in their own scripts.
@onready var _hud = $Hud
@onready var _player = $Player


func _enter_tree() -> void:
	Controls.ensure()


func _ready() -> void:
	var dummies := get_tree().get_nodes_in_group("targets")
	_total = dummies.size()
	_remaining = _total
	for dummy in dummies:
		dummy.connect("downed", _on_target_downed)
	_player.shot_fired.connect(_on_shot_fired)
	_hud.set_targets(_remaining, _total)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("reset_arena"):
		get_tree().reload_current_scene()


func _on_target_downed(_dummy: Node3D) -> void:
	_remaining -= 1
	_hud.set_targets(_remaining, _total)


func _on_shot_fired(hit_target: bool) -> void:
	if hit_target:
		_hud.ping()
