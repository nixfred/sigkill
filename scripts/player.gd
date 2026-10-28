extends CharacterBody3D
## First-person player: WASD + mouse look, jump and slide, plus a small arsenal (C16):
## the hitscan terminal cannon in slot 1 and SIGTERM, the polite shotgun, in slot 2.
##
## Movement feel lives in one resource: scripts/movement_tuning.gd, with the default
## instance in resources/movement_tuning.tres. Every movement and camera number comes
## from it. All motion is scaled by delta, so it feels the same at any physics rate.
## Weapons work the same way: each is a WeaponDef (scripts/weapons/weapon_def.gd, one .tres
## per weapon: resources/terminal_cannon.tres, resources/sigterm.tres), the loadout and
## swap timing are resources/arsenal.tres, and what the player holds, its ammo, swap and
## reload live in scripts/weapons/inventory.gd. Effects are scripts/cannon_fx.gd and the
## synthesised sounds scripts/sfx_synth.gd. 1 to 9 pick a weapon, the wheel cycles, Q
## swaps back, E reloads; no shot goes off while a weapon is drawn or reloaded.
##
## Mouse rules: the mouse is captured only after the player clicks into the window.
## Esc, or the window losing focus, releases it. The game never grabs the mouse on
## its own and never steals focus. Esc also asks the HUD for the menu (C16b).
##
## Settings (C16b, scripts/settings/game_settings.gd) the player reads: invert Y for the
## mouse and the right stick alike, the mouse and aim-down-sights sensitivity multipliers,
## hold or toggle for crouch (X) and aim (right mouse), the field of view, screen shake (the
## camera jolt of a shot, which never moves the aim, and the head bob) and motion blur (the
## view stretching wider at speed). Every default is the movement tuning as it shipped.

const Palette = preload("res://scripts/palette.gd")
const Controls = preload("res://scripts/controls.gd")
const Tuning = preload("res://scripts/movement_tuning.gd")
const DEFAULT_TUNING_PATH := "res://resources/movement_tuning.tres"
const CannonFx = preload("res://scripts/cannon_fx.gd")
const Sfx = preload("res://scripts/sfx_synth.gd")
const WeaponDefScript = preload("res://scripts/weapons/weapon_def.gd")
const Arsenal = preload("res://scripts/weapons/arsenal_tuning.gd")
const Inventory = preload("res://scripts/weapons/inventory.gd")
const DEFAULT_ARSENAL_PATH := "res://resources/arsenal.tres"
const SettingsApply = preload("res://scripts/settings/settings_apply.gd")
## Added to the host's remaining reload or draw time when this side's has to wait for it:
## three physics frames at 60 Hz.
const TIMING_MARGIN_S := 0.05

## Emitted after each shot. `hit_target` is true when the ray struck a target.
signal shot_fired(hit_target: bool)
## Emitted with each shot's origin, aim direction in world space and weapon id: the intent
## the host of a LAN session validates (C14, C16). The host draws a pellet weapon's pellets
## itself. Local effects never wait for it.
signal fire_intent(origin: Vector3, direction: Vector3, weapon: String)
## Emitted when a weapon is drawn and when a reload starts, with the weapon's id: in a LAN
## session the host keeps the same rules from them (C16).
signal weapon_drawn(weapon: String)
signal reload_started(weapon: String)
## Emitted when a jump starts, from the ground or out of a slide. Round stats count it.
signal jumped
## Emitted when a slide starts. Round stats count it.
signal slid
## Emitted on Esc when nothing else took the key: the HUD opens the menu (C16b).
signal menu_requested

## Movement and camera tuning. Leave empty to use resources/movement_tuning.tres.
@export var tuning: Resource
## A WeaponDef to put in slot 1 instead of the arsenal's own (tests). Leave empty, as the
## shipped scene does, so the arsenal alone decides the loadout on every side. A bad one is
## replaced by the built-in cannon; a slot further on with the same id is left out.
@export var weapon: Resource
## The loadout and swap timing, an ArsenalTuning. Leave empty to use resources/arsenal.tres.
## A weapon in it that fails its own checks is refused and left out.
@export var arsenal: Resource

## Shots and hits since the arena loaded, for the guide's ask stats. Each round counts its
## own from shot_fired, jumped and slid (scripts/round/round_stats.gd).
var shots_fired := 0
var hits_landed := 0
## True while the guide HUD's ask box is open: no movement, jump, slide, look or fire, and a
## click does not grab the mouse. The HUD sets it and clears it.
var input_blocked := false
## Test hook: a headless run cannot capture the mouse, so tests set this to have the player
## read keyboard and mouse input as if it were captured. Never set by the game.
var assume_captured := false
## False while derezzed in a LAN match (C14): no movement, no fire, no weapon in view. The
## session sets it from the host's word and clears it at the respawn, which refills every
## weapon.
var alive := true
## The weapons held and their state (scripts/weapons/inventory.gd).
var inventory: Inventory

var _t: Tuning
var _w: WeaponDefScript  # the drawn weapon
var _a: Arsenal
var _spawn: Transform3D
var _fire_queued := false
var _viewmodel: MeshInstance3D  # the drawn weapon's
var _viewmodels: Array[MeshInstance3D] = []
var _rng := RandomNumberGenerator.new()
## Draws this player's own pellets: cosmetic tracers and its own dummies. In a match the
## host draws the pellets that count with its own generator.
var _pellet_rng := RandomNumberGenerator.new()
var _recoil := Vector2.ZERO  # pitch and yaw kick in radians, applied to the camera
var _viewmodel_kick := 0.0
var _shake := 0.0  # the camera's shot jolt in metres, visual only
var _shake_rng := RandomNumberGenerator.new()
var _fire_sfx: AudioStreamPlayer  # the drawn weapon's
var _hit_sfx: AudioStreamPlayer
var _reload_sfx: AudioStreamPlayer
var _sfx: Array = []  # per slot: [fire, hit, reload]

# Movement state.
var _sliding := false
var _slide_time := 0.0
var _slide_cooldown_left := 0.0
var _was_on_floor := false
var _air_speed_cap := 0.0
var _bob_phase_v := 0.0
var _bob_phase_h := 0.0
var _bob_weight := 0.0
var _fov_kick := 0.0
var _crouching := false
var _aiming := false
var _ads_blend := 0.0  # 0 at the hip, 1 fully aimed down the sights

# What the settings say (C16b), read when they change.
var _settings: GameSettings
var _invert_y := false
var _mouse_scale := 1.0
var _ads_scale := 0.7
var _crouch_toggles := false
var _aim_toggles := false
var _fov_setting := 0
var _shake_on := true
var _speed_fx_on := true

# Input for this physics frame: from the keyboard, or from a test through drive_input().
var _move_input := Vector2.ZERO
var _jump_pressed := false
var _slide_pressed := false
var _fire_pressed := false
var _scripted_input := false

@onready var _head: Node3D = $Head
@onready var _camera: Camera3D = $Head/Camera
@onready var _muzzle: Marker3D = $Head/Camera/Muzzle


func _ready() -> void:
	Controls.ensure()
	if not (tuning is Tuning):
		tuning = load(DEFAULT_TUNING_PATH)
	_t = tuning as Tuning
	if _t == null:
		push_error("player: no movement tuning resource at " + DEFAULT_TUNING_PATH)
		set_physics_process(false)
		set_process_unhandled_input(false)
		return
	var issues := _t.problems()
	if not issues.is_empty():
		for issue in issues:
			push_warning("movement tuning: " + issue + "; using the built-in defaults instead")
		_t = Tuning.new()
	_spawn = global_transform
	_head.position.y = _t.stand_head_height
	_settings = GameSettings.current()
	_settings.changed.connect(_on_setting_changed)
	_read_settings()
	_camera.fov = standard_fov()

	if not (arsenal is Arsenal):
		arsenal = load(DEFAULT_ARSENAL_PATH)
	_a = Arsenal.usable_timing(arsenal)
	var defs: Array = Arsenal.usable_loadout(arsenal)
	if weapon != null:
		var weapon_issues: PackedStringArray = weapon.problems() if weapon is WeaponDefScript else PackedStringArray(["not a WeaponDef"])
		for issue in weapon_issues:
			push_warning("weapon tuning: " + issue + "; using the built-in defaults instead")
		var first: Resource = weapon if weapon_issues.is_empty() else WeaponDefScript.new()
		defs = [first] + defs.slice(1).filter(func(def): return def.id != first.id)
	inventory = Inventory.new(defs, _a.swap_s, _a.fiction_s)
	_rng.randomize()
	_pellet_rng.randomize()
	_shake_rng.randomize()
	SettingsApply.ensure_buses()
	for def in inventory.defs:
		_viewmodels.append(_build_viewmodel(def))
		_sfx.append([_make_sfx_player(Sfx.fire_zap(def), def), _make_sfx_player(Sfx.hit_blip(def), def), _make_sfx_player(Sfx.reload_clack(def), def)])
	_show_weapon()


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT or what == NOTIFICATION_WM_WINDOW_FOCUS_OUT:
		_release_mouse()


func _unhandled_input(event: InputEvent) -> void:
	if input_blocked:
		return
	if event.is_action_pressed("release_mouse"):
		_release_mouse()
		get_viewport().set_input_as_handled()
		menu_requested.emit()
		return

	if not _captured():
		# Click to engage. That click is consumed so it never fires the cannon.
		if event.is_action_pressed("fire"):
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
			get_viewport().set_input_as_handled()
		return

	if event is InputEventMouseMotion:
		_look((event as InputEventMouseMotion).relative)
	elif event.is_action_pressed("fire"):
		_fire_queued = true
	elif event.is_action_pressed("reload"):
		reload_weapon()
	elif event.is_action_pressed("weapon_last"):
		swap_to_last()
	elif event.is_action_pressed("weapon_next"):
		cycle_weapon(1)
	elif event.is_action_pressed("weapon_prev"):
		cycle_weapon(-1)
	else:
		for i in Controls.SLOT_KEYS.size():
			if event.is_action_pressed("weapon_%d" % (i + 1)):
				select_slot(i)
				break


## Mouse look: the tuning's sensitivity times the settings' multiplier (the aim one while
## aiming down the sights).
func _look(relative: Vector2) -> void:
	var sensitivity := _t.mouse_sensitivity * _look_scale()
	_turn(relative.x * sensitivity, relative.y * sensitivity)


## Right-stick look for `delta` seconds: full tilt turns gamepad_look_degrees a second,
## times the same multiplier as the mouse. Test hook too.
func look_with_stick(stick: Vector2, delta: float) -> void:
	var rate := deg_to_rad(_t.gamepad_look_degrees) * delta * _look_scale()
	_turn(stick.x * rate, stick.y * rate)


## Turns the view `right` radians to the right and `down` radians down (up with invert Y):
## yaw on the body, pitch on the head, clamped to the pitch limit. The recoil on the camera
## is re-clamped straight away, so aim plus recoil never tips the view past the limit, not
## even between physics ticks.
func _turn(right: float, down: float) -> void:
	var pitch_limit := deg_to_rad(_t.pitch_limit_degrees)
	if _invert_y:
		down = -down
	rotate_y(-right)
	_head.rotation.x = clampf(_head.rotation.x - down, -pitch_limit, pitch_limit)
	_apply_recoil()


func _look_scale() -> float:
	return _ads_scale if _aiming else _mouse_scale


# --- Movement and camera. Every number below comes from the tuning resource. ---

func _physics_process(delta: float) -> void:
	if not _scripted_input:
		_read_player_input()
	if not input_blocked and alive:
		var stick := Input.get_vector("look_left", "look_right", "look_up", "look_down")
		if not stick.is_zero_approx():
			look_with_stick(stick, delta)
	if not alive:
		# Derezzed: neither the keyboard nor a test's scripted input moves the body.
		_move_input = Vector2.ZERO
		_jump_pressed = false
		_slide_pressed = false
		_fire_pressed = false
	_step_movement(delta)
	_step_camera(delta)
	_step_weapon(delta)
	# Presses are one-shot. Scripted input lasts exactly one physics frame, then the
	# keyboard takes over again.
	_jump_pressed = false
	_slide_pressed = false
	_fire_pressed = false
	if _scripted_input:
		_move_input = Vector2.ZERO
		_scripted_input = false

	if global_position.y < _t.fall_respawn_height:
		_respawn()


## Test hook: supplies the input for the next physics frame only, instead of the
## keyboard and mouse. jump, slide and fire are one-shot presses. Used by the tests in
## tests/.
func drive_input(move: Vector2, jump: bool = false, slide: bool = false, fire: bool = false) -> void:
	_scripted_input = true
	_move_input = move.limit_length(1.0)
	_jump_pressed = jump
	_slide_pressed = slide
	_fire_pressed = fire


## Where the player looks up or down, in radians: the head's pitch, without recoil. Sent to
## other players (C13).
func view_pitch() -> float:
	return _head.rotation.x


## True while a slide is running.
func is_sliding() -> bool:
	return _sliding


## True while crouched (X, held or toggled) and while aiming down the sights (right mouse).
func is_crouching() -> bool:
	return _crouching


func is_aiming() -> bool:
	return _aiming


## The field of view at rest at the hip: the settings' own, or the tuning's.
func standard_fov() -> float:
	return float(_fov_setting) if _fov_setting > 0 else _t.base_fov


## The camera's shot jolt right now, in metres: 0 with screen shake off.
func shake_offset() -> Vector2:
	return Vector2(_camera.h_offset, _camera.v_offset)


## Current speed along the ground plane, in m/s.
func horizontal_speed() -> float:
	return Vector2(velocity.x, velocity.z).length()


func _captured() -> bool:
	return assume_captured or Input.mouse_mode == Input.MOUSE_MODE_CAPTURED


func _read_player_input() -> void:
	if input_blocked or not alive or not _captured():
		_move_input = Vector2.ZERO
		_jump_pressed = false
		_slide_pressed = false
		_fire_pressed = false
		_fire_queued = false
		# A held crouch or aim lets go; a toggled one stays as it was until the player is back.
		_crouching = _crouching and _crouch_toggles and alive
		_aiming = _aiming and _aim_toggles and alive
		return
	_move_input = Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	_jump_pressed = Input.is_action_just_pressed("jump")
	_slide_pressed = Input.is_action_just_pressed("slide")
	_crouching = (not _crouching if Input.is_action_just_pressed("crouch") else _crouching) if _crouch_toggles else Input.is_action_pressed("crouch")
	_aiming = (not _aiming if Input.is_action_just_pressed("aim") else _aiming) if _aim_toggles else Input.is_action_pressed("aim")
	# Clicks arrive through _unhandled_input; the shot itself is resolved in the physics step.
	_fire_pressed = _fire_queued
	_fire_queued = false


func _step_movement(delta: float) -> void:
	var on_floor := is_on_floor()
	_slide_cooldown_left = maxf(_slide_cooldown_left - delta, 0.0)
	if not on_floor:
		velocity += get_gravity() * _t.gravity_scale * delta

	var horizontal := Vector3(velocity.x, 0.0, velocity.z)
	var speed := horizontal.length()
	var wish := global_transform.basis * Vector3(_move_input.x, 0.0, _move_input.y)
	wish.y = 0.0
	wish = wish.limit_length(1.0)

	# A running slide ends by jumping, leaving the ground, timing out or slowing down.
	var slide_jump := false
	if _sliding:
		_slide_time += delta
		if _jump_pressed and on_floor:
			slide_jump = true
			_end_slide()
		elif not on_floor or _slide_time >= _t.slide_max_duration or speed <= _t.slide_end_speed:
			_end_slide()

	# A jump pressed on the same frame wins: no slide starts and the normal jump runs.
	var start_slide := (
		_slide_pressed and not _jump_pressed and on_floor and not _sliding and not slide_jump
		and _slide_cooldown_left <= 0.0 and speed > 0.0 and speed >= _t.slide_min_speed
	)

	if slide_jump:
		# Jump out of the slide and keep its momentum, up to a cap.
		velocity.y = _t.jump_velocity
		horizontal = horizontal.limit_length(_t.slide_jump_max_speed)
		jumped.emit()
	elif start_slide:
		# Short burst along the current direction of travel. Never slows the player down.
		_sliding = true
		_slide_time = 0.0
		var burst := maxf(speed, minf(speed + _t.slide_boost, _t.slide_max_speed))
		horizontal = horizontal / speed * burst
		slid.emit()
	elif _sliding:
		horizontal = horizontal.move_toward(Vector3.ZERO, _t.slide_friction * delta)
	elif on_floor:
		if wish.is_zero_approx():
			horizontal = horizontal.move_toward(Vector3.ZERO, _t.ground_friction * delta)
		else:
			var pace := minf(_t.crouch_speed, _t.walk_speed) if _crouching else _t.walk_speed
			horizontal = horizontal.move_toward(wish * pace, _t.ground_accel * delta)
		if _jump_pressed:
			velocity.y = _t.jump_velocity
			jumped.emit()
	else:
		# Air: reduced steering. Speed is capped at walk speed or at the speed carried off
		# the ground, whichever is higher, so strafing never builds extra speed.
		var cap := maxf(_air_speed_cap, _t.walk_speed)
		if wish.is_zero_approx():
			horizontal = horizontal.move_toward(Vector3.ZERO, _t.air_drag * delta)
		else:
			horizontal = horizontal.move_toward(wish * cap, _t.ground_accel * _t.air_control * delta)
		horizontal = horizontal.limit_length(cap)

	velocity.x = horizontal.x
	velocity.z = horizontal.z
	move_and_slide()

	var grounded := is_on_floor()
	if _was_on_floor and not grounded:
		_air_speed_cap = clampf(horizontal_speed(), _t.walk_speed, _t.slide_jump_max_speed)
	_was_on_floor = grounded


func _end_slide() -> void:
	_sliding = false
	_slide_cooldown_left = _t.slide_cooldown


func _step_camera(delta: float) -> void:
	var speed := horizontal_speed()
	var grounded := is_on_floor()

	# Camera height: lowered while sliding and crouching, eased both ways.
	var head_target := _t.slide_head_height if _sliding else (_t.crouch_head_height if _crouching else _t.stand_head_height)
	_head.position.y = lerpf(_head.position.y, head_target, _smoothing(_t.head_height_smoothing, delta))

	# Head bob: scales with ground speed, fades out in the air and while sliding.
	var bob_target := 0.0
	if _t.head_bob_enabled and _shake_on and grounded and not _sliding and _t.walk_speed > 0.0:
		bob_target = clampf(speed / _t.walk_speed, 0.0, 1.0)
	_bob_weight = lerpf(_bob_weight, bob_target, _smoothing(_t.bob_smoothing, delta))
	var advance := TAU * _t.bob_frequency * bob_target * delta
	_bob_phase_v = wrapf(_bob_phase_v + advance, 0.0, TAU)
	_bob_phase_h = wrapf(_bob_phase_h + advance * _t.bob_lateral_ratio, 0.0, TAU)
	_camera.position = Vector3(
		sin(_bob_phase_h) * _t.bob_lateral, sin(_bob_phase_v) * _t.bob_vertical, 0.0
	) * _bob_weight

	# FOV kick: widens above walk speed and while sliding, capped, eased in and out.
	var kick := 0.0
	var span := _t.fov_full_speed - _t.walk_speed
	if span > 0.0:
		kick = _t.fov_speed_kick * clampf((speed - _t.walk_speed) / span, 0.0, 1.0)
	if _sliding:
		kick += _t.fov_slide_kick
	kick = minf(kick, _t.fov_max_kick) if _speed_fx_on else 0.0
	_fov_kick = lerpf(_fov_kick, kick, _smoothing(_t.fov_smoothing, delta))
	# Aiming down the sights narrows the view to ads_fov_scale of it, eased the same way.
	_ads_blend = lerpf(_ads_blend, 1.0 if _aiming else 0.0, _smoothing(_t.fov_smoothing, delta))
	_camera.fov = standard_fov() * lerpf(1.0, _t.ads_fov_scale, _ads_blend) + _fov_kick


## Share of the way to move toward a target this frame, for exponential easing at `rate`
## per second. The same total easing happens per second at any frame rate.
func _smoothing(rate: float, delta: float) -> float:
	return 1.0 - exp(-rate * delta)


func _respawn() -> void:
	respawn_at(_spawn.origin)
	global_transform = _spawn


## Put down at `pos` with everything at rest; the view keeps its direction.
func respawn_at(pos: Vector3) -> void:
	global_position = pos
	velocity = Vector3.ZERO
	_sliding = false
	_slide_cooldown_left = 0.0
	_air_speed_cap = 0.0
	_recoil = Vector2.ZERO
	_fire_queued = false
	_crouching = false
	_aiming = false


## Alive or derezzed (C14). Derezzed: no input counts, the body stops where it is (a slide
## ends, momentum goes; it still falls if in the air) and the weapon is out of view. Coming
## back to life (the host's respawn) refills every weapon (C16).
func set_alive(on: bool) -> void:
	if on and not alive and inventory != null:
		inventory.refill()
	alive = on
	if _viewmodel != null:
		_viewmodel.visible = on
	if not on:
		_move_input = Vector2.ZERO
		_jump_pressed = false
		_slide_pressed = false
		_fire_pressed = false
		_fire_queued = false
		velocity = Vector3(0.0, minf(velocity.y, 0.0), 0.0)
		_sliding = false
		_air_speed_cap = 0.0
		_crouching = false
		_aiming = false


## Where the eyes are, in world space, right now.
func eye_position() -> Vector3:
	return _camera.global_position


## How far above the body's origin the eyes sit when standing.
func eye_height() -> float:
	return _t.stand_head_height


func _release_mouse() -> void:
	if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


# --- Weapons. Every number below comes from the drawn weapon's WeaponDef. ---

## The drawn weapon's WeaponDef: the shipped one, or the built-in cannon if slot 1's was bad.
func weapon_tuning() -> Resource:
	return _w


## Draws the weapon in `slot` (0 for slot 1): ready to fire after the swap time. False when
## it is already drawn, there is no such slot, or the player is derezzed.
func select_slot(slot: int) -> bool:
	if not alive or not inventory.select(slot):
		return false
	_show_weapon()
	weapon_drawn.emit(_w.id)
	return true


## The next (`step` 1) or previous (-1) weapon, wrapping round: the mouse wheel.
func cycle_weapon(step: int) -> bool:
	return select_slot(posmod(inventory.current + step, inventory.slot_count())) if inventory.slot_count() > 1 else false


## Back to the weapon drawn before this one: Q.
func swap_to_last() -> bool:
	return select_slot(inventory.last)


## Reloads the drawn weapon: E. False when there is nothing to reload or it cannot now.
func reload_weapon() -> bool:
	if not alive or not inventory.reload():
		return false
	reload_started.emit(_w.id)
	return true


## A fresh loadout: slot 1 drawn, every weapon full, nothing running. The session calls it
## when a match starts, so the host's count and the player's begin the same. With `drawing`
## slot 1 is still being drawn for the swap time, as on the host after a draw.
func reset_inventory(drawing: bool = false) -> void:
	inventory = Inventory.new(inventory.defs, _a.swap_s, _a.fiction_s)
	if drawing:
		inventory.swap_left = _a.swap_s
	_show_weapon()


## Every weapon full again, the drawn one kept: a respawn that came while this arena was away.
func refill_weapons() -> void:
	inventory.refill()


## Takes the host's count for the weapon with `id` (C16): its magazine and reserve. A reload
## running here goes on and moves what the new count leaves room for. With `host_reloading`
## (the host is running a reload of it) and none running here any more (this side's
## finished first), the count is taken as that reload will leave it, so a late reply never
## undoes a reload this side has finished. False for a weapon not in the loadout.
func take_ammo(id: String, mag: int, reserve: int, host_reloading: bool = false) -> bool:
	var slot := inventory.slot_of(id)
	if slot < 0:
		return false
	if host_reloading and not (slot == inventory.current and inventory.is_reloading()):
		var take: int = inventory.defs[slot].reload_take(mag, reserve)
		mag += take
		if reserve != WeaponDefScript.INFINITE:
			reserve -= take
	inventory.mags[slot] = mag
	inventory.reserves[slot] = reserve
	return true


## The host's timing for the weapon in hand (C16): its reload or draw still has `reload_s`
## or `draw_s` to go there, so no shot goes off here until then and a little more
## (TIMING_MARGIN_S, so a shot never lands on the host's last frame of it). This side's own
## reload or draw, if still running, is stretched; if it has already ended, a fire block holds
## the shot instead (the reload is not run again, so no rounds move twice). Never shortens.
func take_timing(id: String, reloading: String, reload_s: float, draw_s: float) -> void:
	if inventory.def().id != id:
		return
	if reloading == id and reload_s > 0.0:
		if inventory.is_reloading():
			inventory.reload_left = maxf(inventory.reload_left, reload_s + TIMING_MARGIN_S)
		else:
			inventory.block_left = maxf(inventory.block_left, reload_s + TIMING_MARGIN_S)
	if draw_s > 0.0:
		if inventory.is_swapping():
			inventory.swap_left = maxf(inventory.swap_left, draw_s + TIMING_MARGIN_S)
		else:
			inventory.block_left = maxf(inventory.block_left, draw_s + TIMING_MARGIN_S)


## Holds the weapon with `id` at once, ready (a respawn with the weapon the host says is in
## hand). Nothing is sent: the host already knows. False for a weapon not in the loadout.
func hold_weapon(id: String) -> bool:
	if not inventory.hold(inventory.slot_of(id)):
		return false
	_show_weapon()
	return true


## Takes over `other`'s weapons and their state, when it holds the same loadout: the session
## hands a match's inventory to the new arena after an R reload, so R never refills ammo
## mid-match. False when the loadouts differ.
func adopt_inventory(other: Inventory) -> bool:
	if other == null or other.slot_count() != inventory.slot_count():
		return false
	for i in other.slot_count():
		if other.defs[i].id != inventory.defs[i].id:
			return false
	inventory = other
	_show_weapon()
	return true


func _step_weapon(delta: float) -> void:
	var reloading := inventory.is_reloading()
	inventory.tick(delta)
	if reloading and not inventory.is_reloading() and alive:
		_reload_sfx.play()  # the rounds are in
	# Recover first, then apply any new shot, so a shot's kick is the same size at any
	# physics rate. Mouse aim is never touched, so the view settles back on target.
	_recoil = _recoil.lerp(Vector2.ZERO, _smoothing(_w.recoil_recovery, delta))
	_viewmodel_kick = lerpf(_viewmodel_kick, 0.0, _smoothing(_w.viewmodel_recovery, delta))
	# The shot jolt moves the picture, never the camera, so the ray below is unchanged.
	_shake = lerpf(_shake, 0.0, _smoothing(_w.recoil_recovery, delta)) if _shake_on else 0.0
	_camera.h_offset = _shake_rng.randf_range(-1.0, 1.0) * _shake
	_camera.v_offset = _shake_rng.randf_range(-1.0, 1.0) * _shake
	# The ray is cast from the camera exactly as the player sees it, clamp included.
	_apply_recoil()
	if _fire_pressed and alive:
		var why := inventory.try_fire()
		if why == "":
			_fire()
			_apply_recoil()
		elif why == Inventory.BLOCK_EMPTY:
			reload_started.emit(_w.id)  # fire on an empty magazine started a reload
	# A weapon being drawn rises from below; one being reloaded tips over and back.
	var drop := _a.swap_drop_m * (1.0 - inventory.swap_progress())
	_viewmodel.position = _w.viewmodel_offset + Vector3(0.0, -drop, _w.viewmodel_kick_back * _viewmodel_kick)
	_viewmodel.rotation.x = deg_to_rad(_w.viewmodel_kick_pitch_degrees) * _viewmodel_kick
	_viewmodel.rotation.z = deg_to_rad(_a.reload_tilt_degrees) * sin(PI * inventory.reload_progress())


## One shot of the drawn weapon: one ray for a single shot, one per pellet for SIGTERM, each
## pellet's damage eased by its distance. Hits on this machine's own dummies land here; in
## a match the host judges every shot at another player from the intent alone.
func _fire() -> void:
	shots_fired += 1
	var origin := _camera.global_position
	var forward := -_camera.global_transform.basis.z
	var hit_target := false
	var fx_root := _fx_root()
	for dir in _w.pellet_directions(forward, _pellet_rng):
		var far_point := origin + dir * _w.fire_range
		var query := PhysicsRayQueryParameters3D.create(origin, far_point, _w.hit_mask)
		var result := get_world_3d().direct_space_state.intersect_ray(query)
		var end_point := far_point
		if not result.is_empty():
			end_point = result["position"]
			var normal: Vector3 = result["normal"]
			if normal.is_zero_approx():
				normal = -dir
			var landed := false
			var collider = result["collider"]
			if is_instance_valid(collider) and collider.has_method("hit"):
				landed = collider.call("hit", _w.damage_at(origin.distance_to(end_point)), end_point, dir) == true
			hit_target = hit_target or landed
			CannonFx.spawn_impact(fx_root, end_point, normal, landed, _w)
		CannonFx.spawn_beam(fx_root, _muzzle.global_position, end_point, _w)
	CannonFx.spawn_muzzle_flash(_muzzle, _w)
	_kick()
	if _shake_on:
		_shake = maxf(_shake, _w.shake_m)
	_fire_sfx.play()
	if hit_target:
		hits_landed += 1
		_hit_sfx.play()
	shot_fired.emit(hit_target)
	fire_intent.emit(origin, forward, _w.id)


## Puts the drawn weapon in view, with its muzzle and its sounds.
func _show_weapon() -> void:
	_w = inventory.def()
	_muzzle.position = _w.muzzle_offset
	for i in _viewmodels.size():
		_viewmodels[i].visible = i == inventory.current and alive
	_viewmodel = _viewmodels[inventory.current]
	_fire_sfx = _sfx[inventory.current][0]
	_hit_sfx = _sfx[inventory.current][1]
	_reload_sfx = _sfx[inventory.current][2]
	_viewmodel_kick = 0.0


## Puts the recoil on the camera, clamped so aim plus recoil stays within the pitch limit.
func _apply_recoil() -> void:
	var pitch_room := maxf(deg_to_rad(_t.pitch_limit_degrees) - _head.rotation.x, 0.0)
	_recoil.x = minf(_recoil.x, pitch_room)
	_camera.rotation = Vector3(_recoil.x, _recoil.y, 0.0)


## Camera kick up plus a small random yaw, both capped, and a cannon jolt.
func _kick() -> void:
	var max_pitch := deg_to_rad(_w.recoil_max_pitch_degrees)
	var max_yaw := deg_to_rad(_w.recoil_max_yaw_degrees)
	var yaw := deg_to_rad(_rng.randf_range(-_w.recoil_yaw_degrees, _w.recoil_yaw_degrees))
	_recoil.x = minf(_recoil.x + deg_to_rad(_w.recoil_pitch_degrees), max_pitch)
	_recoil.y = clampf(_recoil.y + yaw, -max_yaw, max_yaw)
	_viewmodel_kick = 1.0


## Where world-space effects live: the running scene, or the player's parent in tests.
func _fx_root() -> Node:
	var scene := get_tree().current_scene
	return scene if scene != null else get_parent()


## A placeholder viewmodel: a glowing box in the weapon's light skin, out of view until drawn.
func _build_viewmodel(def: WeaponDefScript) -> MeshInstance3D:
	var mesh := BoxMesh.new()
	mesh.size = def.viewmodel_size
	var model := MeshInstance3D.new()
	model.name = def.display_name.to_pascal_case()
	model.mesh = mesh
	model.material_override = Palette.glow(def.skin_body(), def.viewmodel_glow_energy)
	model.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	model.position = def.viewmodel_offset
	model.visible = false
	_camera.add_child(model)
	return model


func _make_sfx_player(stream: AudioStream, def: WeaponDefScript) -> AudioStreamPlayer:
	var sfx := AudioStreamPlayer.new()
	sfx.stream = stream
	sfx.bus = SettingsApply.EFFECTS
	sfx.volume_db = Sfx.volume_db(def.master_volume)
	sfx.max_polyphony = def.sfx_polyphony
	add_child(sfx)
	return sfx


func _on_setting_changed(_section: String, _key: String) -> void:
	_read_settings()


func _read_settings() -> void:
	_invert_y = _settings.value("controls", "invert_y")
	_mouse_scale = _settings.value("controls", "mouse_sensitivity")
	_ads_scale = _settings.value("controls", "ads_sensitivity")
	_crouch_toggles = _settings.value("controls", "crouch_mode") == "toggle"
	_aim_toggles = _settings.value("controls", "aim_mode") == "toggle"
	_fov_setting = _settings.value("video", "fov")
	_shake_on = _settings.value("hud", "screen_shake")
	_speed_fx_on = _settings.value("hud", "motion_blur")
