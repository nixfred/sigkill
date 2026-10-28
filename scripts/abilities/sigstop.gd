extends Node
## SIGSTOP bullet time (C18, PRD 5.3), the player's ability: F (rebindable in the settings)
## sends SIGSTOP, F again sends SIGCONT, and an empty meter sends SIGCONT by itself. One of
## these lives under the player (scripts/player.gd makes it). Its numbers are
## resources/sigstop.tres, its meter's rules scripts/abilities/sigstop_meter.gd.
##
## Solo the world slows to world_scale: the engine's time scale, so the daemons, the beams
## and every effect, physics and every timer (the round clock too). The player is made up
## for it: player_step() hands the player its own time for the frame, player_rate of real
## time, so it moves, looks, aims and fires at close to full speed. SIGCONT eases the world
## back over ease_s and then sets exactly 1.0. A death, a round's end, the Esc menu or the
## ask box (anything that stops the player's input), a match starting and this node leaving
## the tree (an R reload, a scene change) all end it at once, and every physics frame a
## safety check puts the time scale and the audio speed back to exactly 1.0 whenever no
## SIGSTOP of a player in the tree is holding them. Every write of 1.0 goes through
## restore_time() and restore_audio().
##
## In a match nothing global ever changes, for anyone: the host's simulation never slows,
## and neither does any player's. The effect is this player's own and local: the look (the
## picture greyed toward the theme's teal, with motion trails, and every sound on this
## machine pitched down) and, while the host says SIGSTOP is on, zero spread and zero recoil
## (steady()). A press asks the host (the intent signal, sent by scripts/net/net_session.gd);
## the host keeps every player's meter and validates the ask, and its word starts and ends
## SIGSTOP here (take_host()). Between its words the meter shown here runs on the same rules.
##
## Cosmetic fiction: nothing real is stopped, continued or signalled.

## SIGSTOP started (the round HUD calls it out), and SIGCONT: pressed again or the meter ran
## out. A hard stop (a death, the menu, a round's end) is no SIGCONT callout.
signal started
signal continued
## In a match: this player asks the host to start (true) or end (false) its SIGSTOP.
signal intent(on: bool)

const TuningScript = preload("res://scripts/abilities/sigstop_tuning.gd")
const Meter = preload("res://scripts/abilities/sigstop_meter.gd")
const Palette = preload("res://scripts/palette.gd")
const LookShader = preload("res://shaders/sigstop_look.gdshader")
const DEFAULT_TUNING_PATH := "res://resources/sigstop.tres"
## Over the 3D world, under the HUD (layer 1).
const LOOK_LAYER := 0

## A SigstopTuning; null for resources/sigstop.tres. Set before the node enters the tree.
var tuning: Resource = null
## The session beside the arena (scripts/net/net_session.gd), set by it when it attaches.
var session: Node = null
## The meter: this player's own solo; in a match a copy of the host's.
var meter: Meter

var _t: TuningScript
var _press := false
## Seconds left of SIGCONT's ease back to full speed, solo.
var _ease_left := 0.0
## How strong the look is now, from 0 to 1.
var _look := 0.0
## In a match: the host's word (on or off) and what this side last asked for.
var _host_on := false
var _asked := false
var _was_online := false
var _layer: CanvasLayer
var _cover: ColorRect
var _paint: ShaderMaterial

## The controllers that hold the engine's time scale and the audio speed, if any. Only one
## SIGSTOP slows anything at a time; the safety check frees what nothing holds any more.
static var _time_holder: Object = null
static var _audio_holder: Object = null


static func usable_tuning(candidate: Resource) -> TuningScript:
	if candidate is TuningScript:
		var issues: PackedStringArray = candidate.problems()
		if issues.is_empty():
			return candidate
		for issue in issues:
			push_warning("sigstop tuning: " + issue + "; using the shipped tuning instead")
	var shipped = load(DEFAULT_TUNING_PATH)
	if shipped is TuningScript and shipped.problems().is_empty():
		return shipped
	return TuningScript.new()


func _ready() -> void:
	_t = usable_tuning(tuning)
	meter = Meter.new(_t)
	_build_look()


func _exit_tree() -> void:
	# An R reload or a scene change: nothing this SIGSTOP slowed stays slowed.
	_ease_left = 0.0
	if meter != null:
		meter.on = false
	_host_on = false
	_look = 0.0
	if _time_holder == self:
		restore_time()
	if _audio_holder == self:
		restore_audio()


func tuning_in_use() -> TuningScript:
	return _t


## F: SIGSTOP, or SIGCONT while it runs. Taken on the next physics frame. Nothing while the
## player is derezzed or its input is stopped.
func press() -> void:
	_press = true


## True while SIGSTOP is on for this player: solo its own, in a match the host's word.
func is_on() -> bool:
	return _host_on if _online() else meter.on


## True while shots go steady: zero spread and zero recoil, for SIGSTOP's duration (in a
## match, only while the host says it is on).
func steady() -> bool:
	return is_on()


## True while this player's SIGSTOP holds the world slowed (solo only), the ease included.
func slowing() -> bool:
	return _time_holder == self and (meter.on or _ease_left > 0.0)


## True when a press now would start SIGSTOP.
func can_start() -> bool:
	return not is_on() and meter.can_start()


## How strong the look is, from 0 to 1.
func look_strength() -> float:
	return _look


## The player's own seconds for a physics frame of `delta`: `delta` itself, except while
## this SIGSTOP slows the world, when it is player_rate of the frame's real length (easing
## to all of it during SIGCONT), so the player keeps close to full speed in real time.
func player_step(delta: float) -> float:
	if not slowing():
		return delta
	var feel := _t.player_rate if meter.on else lerpf(_t.player_rate, 1.0, _ease_done())
	return feel * _real_frame()


## A new round: the meter full again, solo. In a match the host keeps the meter.
func refill() -> void:
	if not _online():
		meter.fill()


## Ends SIGSTOP at once, with no ease (a round's end, the menu): solo the time scale is
## exactly 1.0 straight away; in a match the host is asked to end it too.
func end_now() -> void:
	if _online():
		if _asked or _host_on:
			_asked = false
			intent.emit(false)
		_host_on = false
	meter.stop()  # in a match the copy too, so the strip is not left waiting for the host's word
	_ease_left = 0.0
	if _time_holder == self:
		restore_time()
	_set_look(0.0)


## A death: the meter empty and SIGSTOP over at once, here and (it knows of the death
## itself) on the host.
func on_death() -> void:
	_asked = false
	_host_on = false
	meter.empty()
	end_now()


## The host's word in a match: SIGSTOP on or off for this player, and the meter it counts.
## A word handed over by the session (an arena back from an R reload) counts as the match
## already seen, so the first frame's change to online never wipes it.
func take_host(on: bool, left: float) -> void:
	_was_online = _online()
	var was := _host_on
	_host_on = on
	_asked = on
	meter.take(on, left)
	if on and not was:
		started.emit()
	elif was and not on:
		continued.emit()


func _physics_process(_delta: float) -> void:
	var real := _real_frame()
	var player := get_parent()
	var alive: bool = player == null or player.get("alive") != false
	var blocked: bool = player != null and player.get("input_blocked") == true
	var online := _online()
	if online != _was_online:
		# A match starting ends solo slow-mo at once; leaving one, no word of the host's holds.
		_was_online = online
		_host_on = false
		_asked = false
		meter.on = false
		_ease_left = 0.0
		if _time_holder == self:
			restore_time()
	var pressed := _press
	_press = false
	if online:
		_step_match(real, pressed, alive, blocked)
	else:
		_step_solo(real, pressed, alive, blocked)
	_step_look(real)
	_guard()


func _step_solo(real: float, pressed: bool, alive: bool, blocked: bool) -> void:
	if pressed and alive and not blocked:
		if meter.on:
			_sigcont()
		elif meter.start():
			_ease_left = 0.0
			started.emit()
	if (meter.on or _ease_left > 0.0) and (not alive or blocked):
		end_now()  # SIGCONT's ease too: nothing eases on behind the menu or a death
	if meter.tick(real, alive):
		_sigcont()  # the meter ran out
	if _ease_left > 0.0:
		_ease_left = maxf(_ease_left - real, 0.0)
	if meter.on:
		_hold_time(_t.world_scale)
	elif _ease_left > 0.0:
		_hold_time(lerpf(_t.world_scale, 1.0, _ease_done()))
	elif _time_holder == self:
		restore_time()


func _step_match(real: float, pressed: bool, alive: bool, blocked: bool) -> void:
	if pressed and alive and not blocked:
		var want := not _asked
		if not want or meter.can_start():
			_asked = want
			intent.emit(want)
	if (_host_on or _asked) and (not alive or blocked):
		end_now()
	meter.tick(real, alive)  # the host's rules, shown between its words


## SIGCONT: the world eases back to full speed.
func _sigcont() -> void:
	meter.stop()
	_ease_left = _t.ease_s
	continued.emit()


## How far SIGCONT's ease has come, from 0 to 1.
func _ease_done() -> float:
	return 1.0 if _t.ease_s <= 0.0 else smoothstep(0.0, 1.0, 1.0 - _ease_left / _t.ease_s)


## The look follows the effect: up while SIGSTOP is on, down with SIGCONT's ease, and the
## sound on this machine with it.
func _step_look(real: float) -> void:
	var rate := real / maxf(_t.ease_s, 0.01)
	_set_look(move_toward(_look, 1.0 if is_on() else 0.0, rate))


func _set_look(strength: float) -> void:
	_look = clampf(strength, 0.0, 1.0)
	if _paint != null:
		_paint.set_shader_parameter("strength", _look)
		_cover.visible = _look > 0.0
	if _look > 0.0:
		_audio_holder = self
		AudioServer.playback_speed_scale = lerpf(1.0, _t.audio_pitch, _look)
	elif _audio_holder == self:
		restore_audio()


## The engine's time scale, held by this SIGSTOP: never in a match.
func _hold_time(scale: float) -> void:
	if _online():
		return
	_time_holder = self
	Engine.time_scale = scale


## The safety check: a time scale or an audio speed that no SIGSTOP in the tree holds any
## more goes back to exactly 1.0, and in a match this player's never holds either.
func _guard() -> void:
	if _online() and _time_holder == self:
		restore_time()
	if Engine.time_scale != 1.0 and not _holds(_time_holder, true):
		restore_time()
	if AudioServer.playback_speed_scale != 1.0 and not _holds(_audio_holder, false):
		restore_audio()


static func _holds(holder: Object, time: bool) -> bool:
	if holder == null or not is_instance_valid(holder) or not (holder as Node).is_inside_tree():
		return false
	return holder.slowing() if time else holder.look_strength() > 0.0


## Exactly 1.0 for the engine's time scale, and nothing holds it.
static func restore_time() -> void:
	Engine.time_scale = 1.0
	_time_holder = null


## Exactly 1.0 for the audio speed, and nothing holds it.
static func restore_audio() -> void:
	AudioServer.playback_speed_scale = 1.0
	_audio_holder = null


func _online() -> bool:
	return session != null and is_instance_valid(session) and session.has_method("is_online") and session.is_online()


## A physics frame's real length: physics runs this many frames a real second whatever the
## time scale, so the meter and the player's own time never slow with the world.
static func _real_frame() -> float:
	return 1.0 / maxf(float(Engine.physics_ticks_per_second), 1.0)


## The look: a full-screen cover reading the picture under it, hidden at strength 0.
func _build_look() -> void:
	_layer = CanvasLayer.new()
	_layer.name = "SigstopLook"
	_layer.layer = LOOK_LAYER
	add_child(_layer)
	_cover = ColorRect.new()
	_cover.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_paint = ShaderMaterial.new()
	_paint.shader = LookShader
	_paint.set_shader_parameter("desaturate", _t.desaturate)
	_paint.set_shader_parameter("tint", _t.tint)
	_paint.set_shader_parameter("trail", _t.trail)
	_paint.set_shader_parameter("theme_color", Palette.TEAL)
	_paint.set_shader_parameter("strength", 0.0)
	_cover.material = _paint
	_layer.add_child(_cover)
	_cover.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_cover.visible = false
