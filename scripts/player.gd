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
## The SIGKILL rail rifle (C17), slot 3: the ult. Its meter fills from what the other
## weapons do (solo: damage and kills on this machine's dummies; in a match only the host's
## confirmed results, which the session hands in), stays across swaps and empties when it
## fires, and a death or a new round resets it. Fire with the meter full charges for the
## rail's charge_s with a growing glow, then one ray pierces every target on the line up to
## the first wall. A rail kill with the hit in the target's head zone emits rail_kill(true),
## which the round HUD calls out as "kill -9".
##
## SIGSTOP bullet time (C18): F, its own meter, kept by the node scripts/abilities/sigstop.gd
## makes under the player. Solo it slows the world and hands the player its own time for
## each frame (player_step()), so the player keeps close to full speed: every step here runs
## on that time, and the body's velocity is scaled to it for the move. In a match nothing
## global slows; while the host says SIGSTOP is on, shots go steady: zero spread, zero
## recoil. A death empties its meter.
##
## The fork bomb (C19), slot 4: fire with it drawn throws one on an arc, and G throws one
## without drawing it (its own interval and its two bombs alone count). Solo the throw is its
## own chain here (scripts/weapons/fork_bomb.gd), and its blasts hurt this arena's daemons
## in their radius with nothing of the level in between; in a match only the intent goes to
## the session (throw_intent) and the host runs the chain. The first blast of each throw of
## this player is the ":(){ :|:& };:" callout (fork_bomb_burst). A new round gives the bombs
## back, as a new life does.
##
## Code-rain vision (C21): hold V, its own meter, kept by the node
## scripts/abilities/code_rain_vision.gd makes under the player beside SIGSTOP. Enemy bodies
## in range show as glyph silhouettes through walls, on this screen only; a death or a
## respawn turns it off and leaves its meter as it was. Shots are untouched.
##
## Root vs user and sudo overcharge (C22): Z, kept by the node scripts/abilities/sudo_overcharge.gd
## makes under the player. Every life starts as user; kills in one life earn a sudo charge
## (alone, this arena's daemons going down; in a match, the host's credit). While root the
## weapon in hand, whichever it is, hits damage_scale times harder and spends nothing from its
## magazine or bombs, and every viewmodel and the muzzle flash glow root's red. Its share of
## the ult meter is what the hit would have been at user's strength: root fills it no faster.
## In a match the host applies all of it to players; this side only shows it.
##
## grep (C25), slot 6: the seeker. While it is in hand and the aim is held (or toggled), the
## node scripts/weapons/grep_lock.gd makes under the player builds a lock on the target nearest
## the crosshair in its narrow cone and marks it (up to 3, 5 as root, whose locks build twice as
## fast); each completed mark is the round's "grep" callout. A shot spends every mark: one dart
## per mark homes on it (scripts/weapons/seeker_volley.gd), or one flies straight with none.
## Alone the darts run here against this arena's daemons; in a match only the intent goes,
## with the marks' player ids as its claims, and the host decides which it believes. Putting
## grep away, a death and a respawn drop every mark.
##
## The rm -rf cannon (C26), slot 7: fire winds it up first (the rail's charge, C17: charge_s,
## half that as root), with the weapon's charge prompt typed out on the strip; letting go does
## not stop it, but putting it away, dying or respawning does, with nothing spent. Through the
## wind-up and move_slow_s after the shot the player moves at move_scale of its pace and starts
## no slide. The shot is one slow slug (scripts/weapons/rm_slug.gd) that blasts where it stops;
## alone the blast hurts this arena's daemons in its radius with nothing of the level between
## (the player has no health alone, so its own share of the blast is a match's), in a match only
## the intent goes and the host judges everyone in the radius, the shooter too. Each blast of
## this player's is the round's "rm -rf" callout (rm_blast).
##
## cron mines (C27), slot 8: fire places a mine (scripts/weapons/cron_mine.gd) on the surface
## aimed at within the weapon's placement range, or at the feet. Alone the player runs it: its
## runs hurt this arena's daemons in reach (never the player), and it keeps running whatever the
## player does, until its job is done; a new round clears them. The crontab holds crontab_limit
## jobs: one more removes the oldest, and the strip notes it. In a match only the intent goes; the
## host places, schedules and judges every mine, and hands this player its own (take_mine) for the
## strip's count. The first run of each of this player's mines is the round's "cron" callout.
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
const Sigstop = preload("res://scripts/abilities/sigstop.gd")
const CodeRainVision = preload("res://scripts/abilities/code_rain_vision.gd")
## The viewmodels' fixed projection (A4): they are drawn as at this field of view whatever the
## camera's (the setting, the speed kick, aiming), and shrunk toward the eye by VIEWMODEL_SHRINK,
## which looks the same from the eye but keeps every model inside the player's own radius, so a
## barrel never pokes into a wall. The camera's near plane comes in to keep them in view.
const VIEWMODEL_FOV_DEGREES := 80.0
const VIEWMODEL_SHRINK := 0.25
const VIEWMODEL_NEAR_M := 0.01
const SudoOvercharge = preload("res://scripts/abilities/sudo_overcharge.gd")
const ForkBomb = preload("res://scripts/weapons/fork_bomb.gd")
const ForkVolley = preload("res://scripts/weapons/fork_volley.gd")
const GrepLock = preload("res://scripts/weapons/grep_lock.gd")
const SeekerVolley = preload("res://scripts/weapons/seeker_volley.gd")
const RmSlug = preload("res://scripts/weapons/rm_slug.gd")
const CronMine = preload("res://scripts/weapons/cron_mine.gd")
## A daemon's middle, above its feet: where a blast aims at it.
const DUMMY_MIDDLE_M := 0.9
## A throw leaves this far in front of the eyes, or this far short of a wall nearer than that.
const THROW_AHEAD_M := 0.4
const THROW_CLEAR_M := 0.1
## Added to the host's remaining reload or draw time when this side's has to wait for it:
## three physics frames at 60 Hz.
const TIMING_MARGIN_S := 0.05
## A charge or wind-up counts as done within this many seconds: a sum of physics steps can leave
## a hair over 0, which would hold the shot a frame past its time (C26).
const CHARGE_EPS := 0.000001

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
## Emitted for each target a rail shot of this player derezzes (C17): a dummy here at once,
## another player once the host confirms the kill. `headshot` when the rail struck it in the
## head zone.
signal rail_kill(headshot: bool)
## A throw of the fork bomb (C19): where from, which way, which weapon. In a match the host
## runs the chain from it; solo this player runs its own.
signal throw_intent(origin: Vector3, direction: Vector3, weapon: String)
## The first blast of a throw of this player's: the round HUD's ":(){ :|:& };:".
signal fork_bomb_burst
## A shot of this player's fork() forked for the first time (C24): the round HUD's callout.
signal fork_split
## grep marked a target (C25): the round HUD's "grep" callout.
signal grep_marked
## A slug of this player's rm -rf went off (C26): the round HUD's "rm -rf" callout.
signal rm_blast
## A mine of this player's ran for the first time (C27): the round HUD's "cron" callout.
signal cron_ran

## Movement and camera tuning. Leave empty to use resources/movement_tuning.tres.
@export var tuning: Resource
## A WeaponDef to put in slot 1 instead of the arsenal's own (tests). Leave empty, as the
## shipped scene does, so the arsenal alone decides the loadout on every side. A bad one is
## replaced by the built-in cannon; a slot further on with the same id is left out.
@export var weapon: Resource
## The loadout and swap timing, an ArsenalTuning. Leave empty to use resources/arsenal.tres.
## A weapon in it that fails its own checks is refused and left out.
@export var arsenal: Resource
## SIGSTOP's numbers, a SigstopTuning (C18). Leave empty to use resources/sigstop.tres.
@export var sigstop_tuning: Resource
## Code-rain vision's numbers, a CodeRainVisionTuning (C21). Leave empty to use
## resources/code_rain_vision.tres.
@export var code_rain_vision_tuning: Resource
## Root vs user and sudo overcharge's numbers, a SudoOverchargeTuning (C22). Leave empty to
## use resources/sudo_overcharge.tres.
@export var sudo_tuning: Resource

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
## Set by the session while a match is on (C17): the ult meter then fills only from the
## host's confirmed results, never from this machine's own dummies.
var match_meter := false
## SIGSTOP bullet time (C18): the node under this player that runs it.
var sigstop: Sigstop
## Code-rain vision (C21): the node under this player that runs it.
var vision: CodeRainVision
## Root vs user and sudo overcharge (C22): the node under this player that runs it.
var sudo: SudoOvercharge
## grep's marks (C25): the node under this player that keeps them.
var grep: GrepLock
## The marks' player ids a grep shot claims, set only while its intent is being emitted.
var _claims := PackedInt32Array()
## Whether the viewmodels show root's red right now.
var _root_look := false

var _t: Tuning
var _w: WeaponDefScript  # the drawn weapon
var _a: Arsenal
var _spawn: Transform3D
var _fire_queued := false
var _throw_queued := false
var _throw_pressed := false
var _bomb_rng := RandomNumberGenerator.new()
var _viewmodel: Viewmodel  # the drawn weapon's model (A1)
var _viewmodels: Array[Viewmodel] = []
## The drawn weapon's barrel tip, its model's Muzzle marker: the muzzle flash starts here, and beams
## and projectiles from where the eye sees it (muzzle_point()).
var _muzzle: Marker3D
## Holds every viewmodel under the camera, scaled to give them their fixed projection (A4).
var _viewmodel_rig: Node3D
var _rng := RandomNumberGenerator.new()
## Draws this player's own pellets: cosmetic tracers and its own dummies. In a match the
## host draws the pellets that count with its own generator.
var _pellet_rng := RandomNumberGenerator.new()
var _recoil := Vector2.ZERO  # pitch and yaw kick in radians, applied to the camera
var _viewmodel_kick := 0.0
# The drawn weapon's own motion (A1), visual only: its lag behind a turn, the turn since the last
# step (radians right and down) and its trail behind a jump or a fall.
var _sway := Vector2.ZERO
var _turned := Vector2.ZERO
var _fall_lag := 0.0
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
# The rail's charge (C17): seconds left before it fires, the slot charging, and the players
# its last shot struck in the head (id -> true), for the session's kill confirmations.
var _charge_left := 0.0
var _charge_slot := -1
## The charge's whole length as it started: the rail's charge_s, or the rm -rf cannon's wind-up,
## shorter as root (C26).
var _charge_total := 0.0
## Seconds the rm -rf cannon still slows its shooter after a shot, and the share of its pace it
## keeps meanwhile, taken at the shot (C26).
var _slow_left := 0.0
var _slow_scale := 1.0
## This player's own cron mines (C27), oldest first: alone the ones it runs, in a match the ones the
## host says are its; and seconds the strip still notes a full crontab.
var _jobs: Array = []
var _crontab_note_left := 0.0
## Mines this player placed alone: each one's id.
var _placed := 0
var _rail_heads := {}
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
	_bomb_rng.randomize()
	SettingsApply.ensure_buses()
	_viewmodel_rig = Node3D.new()
	_viewmodel_rig.name = "ViewmodelRig"
	_camera.add_child(_viewmodel_rig)
	_camera.near = VIEWMODEL_NEAR_M
	_fit_viewmodels()
	for def in inventory.defs:
		_viewmodels.append(_build_viewmodel(def))
		_sfx.append([_make_sfx_player(Sfx.fire_zap(def), def), _make_sfx_player(Sfx.hit_blip(def), def), _make_sfx_player(Sfx.reload_clack(def), def)])
	_show_weapon()
	sigstop = Sigstop.new()
	sigstop.name = "Sigstop"
	sigstop.tuning = sigstop_tuning
	add_child(sigstop)
	vision = CodeRainVision.new()
	vision.name = "CodeRainVision"
	vision.tuning = code_rain_vision_tuning
	add_child(vision)
	sudo = SudoOvercharge.new()
	sudo.name = "SudoOvercharge"
	sudo.tuning = sudo_tuning
	add_child(sudo)
	grep = GrepLock.new()
	grep.name = "GrepLock"
	add_child(grep)
	grep.marked.connect(func(_target: Node3D): grep_marked.emit())


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT or what == NOTIFICATION_WM_WINDOW_FOCUS_OUT:
		_release_mouse()


func _unhandled_input(event: InputEvent) -> void:
	if input_blocked:
		return
	if event.is_action_released("code_rain_vision") and vision != null:
		vision.hold(false)  # let go wherever the mouse is: vision never sticks on
	if event.is_action_pressed("release_mouse"):
		_release_mouse()
		get_viewport().set_input_as_handled()
		menu_requested.emit()
		return

	if not _captured():
		# Click to engage, or press fire wherever the settings put it (C16b). That press is
		# consumed so it never fires the cannon.
		var click := event is InputEventMouseButton and event.is_pressed() and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT
		if click or event.is_action_pressed("fire"):
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
	elif event.is_action_pressed("sigstop"):
		sigstop.press()
	elif event.is_action_pressed("code_rain_vision"):
		vision.hold(true)
	elif event.is_action_pressed("sudo_overcharge"):
		sudo.press()
	elif event.is_action_pressed("throw_bomb"):
		_throw_queued = true
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
	_turned += Vector2(right, down)  # the drawn weapon lags it (A1)
	_apply_recoil()


func _look_scale() -> float:
	return _ads_scale if _aiming else _mouse_scale


# --- Movement and camera. Every number below comes from the tuning resource. ---

func _physics_process(frame_delta: float) -> void:
	# The player's own time: the frame's own, or near full speed while SIGSTOP slows the world.
	var delta: float = sigstop.player_step(frame_delta) if sigstop != null else frame_delta
	if not _scripted_input:
		_read_player_input()
	# The right stick looks while the player is engaged, as the mouse does.
	if not input_blocked and alive and _captured():
		var stick := Input.get_vector("look_left", "look_right", "look_up", "look_down")
		if not stick.is_zero_approx():
			look_with_stick(stick, delta)
	if not alive:
		# Derezzed: neither the keyboard nor a test's scripted input moves the body.
		_move_input = Vector2.ZERO
		_jump_pressed = false
		_slide_pressed = false
		_fire_pressed = false
	_step_movement(delta, delta / frame_delta if frame_delta > 0.0 else 1.0)
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
		_throw_pressed = false
		_throw_queued = false
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
	_throw_pressed = _throw_queued
	_throw_queued = false


## `delta` is the player's own time; `own_rate` how much faster than the world's it runs
## this frame (1 but for SIGSTOP solo), so the move covers the player's own time too.
func _step_movement(delta: float, own_rate: float = 1.0) -> void:
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
	# The rm -rf cannon's weight (C26): a share of the pace while it winds up and just after the
	# shot, and no slide starts then.
	var weight := move_scale()
	_slow_left = maxf(_slow_left - delta, 0.0)
	var start_slide := (
		_slide_pressed and not _jump_pressed and on_floor and not _sliding and not slide_jump
		and _slide_cooldown_left <= 0.0 and speed > 0.0 and speed >= _t.slide_min_speed and weight >= 1.0
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
			var pace := (minf(_t.crouch_speed, _t.walk_speed) if _crouching else _t.walk_speed) * weight
			horizontal = horizontal.move_toward(wish * pace, _t.ground_accel * delta)
		if _jump_pressed:
			velocity.y = _t.jump_velocity
			jumped.emit()
	else:
		# Air: reduced steering. Speed is capped at walk speed or at the speed carried off
		# the ground, whichever is higher, so strafing never builds extra speed.
		# The rm -rf cannon's weight (C26) slows only where the steering leads, never the momentum
		# already carried: a wind-up started mid-air eases the speed down, it does not cut it.
		var cap := maxf(_air_speed_cap, _t.walk_speed)
		if wish.is_zero_approx():
			horizontal = horizontal.move_toward(Vector3.ZERO, _t.air_drag * delta)
		else:
			horizontal = horizontal.move_toward(wish * cap * weight, _t.ground_accel * _t.air_control * delta)
		horizontal = horizontal.limit_length(cap)

	velocity.x = horizontal.x
	velocity.z = horizontal.z
	velocity *= own_rate
	move_and_slide()
	velocity /= own_rate

	var grounded := is_on_floor()
	if _was_on_floor and not grounded:
		_air_speed_cap = clampf(horizontal_speed(), _t.walk_speed, _t.slide_jump_max_speed)
	_was_on_floor = grounded


## The share of its pace the player keeps right now: the rm -rf cannon's move_scale while it winds
## up and for move_slow_s after its shot (C26), else 1.
func move_scale() -> float:
	var slug: bool = _charge_left > 0.0 and _charge_slot >= 0 and _charge_slot < inventory.defs.size() and inventory.defs[_charge_slot].is_slug()
	if slug:
		return inventory.defs[_charge_slot].move_factor()
	return _slow_scale if _slow_left > 0.0 else 1.0


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
	_fit_viewmodels()


## The viewmodels' fixed projection (A4): across the view they are stretched by how much wider the
## camera sees than VIEWMODEL_FOV_DEGREES, so they fill the same share of the screen at any field of
## view, and the whole rig is shrunk toward the eye. Sets one transform; makes nothing.
func _fit_viewmodels() -> void:
	if _viewmodel_rig == null:
		return
	var wide := tan(deg_to_rad(_camera.fov) * 0.5) / tan(deg_to_rad(VIEWMODEL_FOV_DEGREES) * 0.5)
	_viewmodel_rig.basis = Basis.from_scale(Vector3(wide, wide, 1.0) * VIEWMODEL_SHRINK)
	# The shot jolt moves the picture by the camera's lens offset; the rig moves with it by all but
	# the shrink's share, so the shrunk models jolt on screen exactly as full-sized ones would
	# (Codex review).
	_viewmodel_rig.position = Vector3(_camera.h_offset, _camera.v_offset, 0.0) * (1.0 - VIEWMODEL_SHRINK)


## Where the eye sees the drawn weapon's barrel tip, in the world (A4): the Muzzle marker grown back
## out from the eye (the camera's, its shot jolt included) to the model's full size, so on screen it
## is exactly the marker, at the distance the model's offsets mean. Beams start here, and
## projectiles are drawn coming out of it.
func muzzle_point() -> Vector3:
	var eye := _camera.get_camera_transform().origin
	if _muzzle == null:
		return eye
	return eye + (_muzzle.global_position - eye) / VIEWMODEL_SHRINK

## Share of the way to move toward a target this frame, for exponential easing at `rate`
## per second. The same total easing happens per second at any frame rate.
func _smoothing(rate: float, delta: float) -> float:
	return 1.0 - exp(-rate * delta)


func _respawn() -> void:
	respawn_at(_spawn.origin)
	global_transform = _spawn


## Put down at `pos` with everything at rest; the view keeps its direction.
func respawn_at(pos: Vector3) -> void:
	if vision != null and vision.meter != null:
		vision.end_now()  # a respawn turns code-rain vision off, its meter as it was (C21)
	if sudo != null and sudo.state != null:
		sudo.end_root()  # and ends root (C22)
	if grep != null:
		grep.clear()  # and drops grep's marks (C25)
	if _charge_left > 0.0:
		_end_charge()  # and a wind-up or charge stops with nothing spent (C26)
	_slow_left = 0.0
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
	if not on and inventory != null:
		inventory.reset_meter()  # a death empties the ult meter (C17)
		_end_charge()
	if not on and sigstop != null and sigstop.meter != null:
		sigstop.on_death()  # and the SIGSTOP meter, ending it at once (C18)
	if not on and vision != null and vision.meter != null:
		vision.on_death()  # code-rain vision off, its meter as it was (C21)
	if not on and sudo != null and sudo.state != null:
		sudo.on_death()  # root over, the streak and any unused sudo charge gone (C22)
	if not on and grep != null:
		grep.clear()  # every grep mark gone (C25)
	if not on:
		_slow_left = 0.0  # the rm -rf cannon's weight goes with the life (C26)
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
	if vision != null:
		vision.hold(false)  # a key held into another window never comes back released
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
	_fit_viewmodels()  # the models ride the jolt's offset (A4)
	# The ray is cast from the camera exactly as the player sees it, clamp included.
	_apply_recoil()
	_step_root()
	_step_grep(delta)
	_crontab_note_left = maxf(_crontab_note_left - delta, 0.0)
	if _charge_left > 0.0:
		_step_charge(delta)
	elif _fire_pressed and alive and not (_w.is_thrown() and _bombs_full(inventory.current)):
		if _w.charge_s > 0.0:
			if inventory.fire_block() == "":
				# The shot goes off when the charge is done: the rail's charge, or the rm -rf
				# cannon's wind-up, shorter as root (C26).
				var root: bool = sudo != null and sudo.state != null and sudo.is_root()
				_charge_total = _w.charge_for(root)
				_charge_left = _charge_total
				_charge_slot = inventory.current
		else:
			var why := inventory.try_fire()
			if why == "":
				_fire()
				_apply_recoil()
			elif why == Inventory.BLOCK_EMPTY:
				reload_started.emit(_w.id)  # fire on an empty magazine started a reload
	if _throw_pressed and alive:
		quick_throw()
	_throw_pressed = false
	_place_viewmodel(delta)


## The drawn weapon's place in view (A1), visual only: at its offset, risen from below and tipped
## as it is drawn, kicked back and up by a shot and settling, tipped over and back by a reload,
## lagging the view's turn, swaying with the stride and trailing a jump or a fall, all calmer aimed
## down the sights. Its muzzle rides along; the shot itself still leaves from the eyes.
func _place_viewmodel(delta: float) -> void:
	var calm := lerpf(1.0, _a.aim_motion_share, _ads_blend)
	var cap := deg_to_rad(_a.sway_cap_degrees)
	var rate := _turned / maxf(delta, 0.0001)
	_turned = Vector2.ZERO
	var lag := Vector2(clampf(rate.x * _a.sway_lag_s, -cap, cap), clampf(rate.y * _a.sway_lag_s, -cap, cap)) * calm
	var settle := _smoothing(_a.sway_recovery, delta)
	_sway = _sway.lerp(lag, settle)
	_fall_lag = lerpf(_fall_lag, clampf(-velocity.y * _a.fall_lag_m, -_a.fall_lag_cap_m, _a.fall_lag_cap_m) * calm, settle)
	var stride := _bob_weight * calm
	var rising := 1.0 - inventory.swap_progress()
	var kick := _viewmodel_kick
	_viewmodel.position = _w.viewmodel_offset + Vector3(
		-sin(_bob_phase_h) * _a.bob_m.x * stride,
		-sin(_bob_phase_v) * _a.bob_m.y * stride - _a.swap_drop_m * rising + _w.viewmodel_kick_back * _a.kick_lift_share * kick + _fall_lag,
		_w.viewmodel_kick_back * kick)
	_viewmodel.rotation = Vector3(
		deg_to_rad(_w.viewmodel_kick_pitch_degrees) * kick - deg_to_rad(_a.swap_tilt_degrees) * rising + _sway.y,
		_sway.x,
		deg_to_rad(_a.reload_tilt_degrees) * sin(PI * inventory.reload_progress()) + deg_to_rad(_a.bob_roll_degrees) * sin(_bob_phase_h) * stride)
	_viewmodel.idle(delta)


## A charging rail: the glow grows, and when the charge is done the shot goes off along the
## aim as it is then. Drawing another weapon, dying or the input being stopped (the menu)
## lets the charge go with nothing spent.
func _step_charge(delta: float) -> void:
	if not alive or input_blocked or inventory.current != _charge_slot:
		_end_charge()
		return
	_charge_left -= delta
	_set_glow(_charge_slot, 1.0 + 3.0 * charge_progress())
	_viewmodels[_charge_slot].set_charge(charge_progress())  # the rail's coils, rm -rf's core (A1)
	if _charge_left > CHARGE_EPS:
		return
	_end_charge()
	if inventory.try_fire() == "":
		_fire()
		_apply_recoil()


func _end_charge() -> void:
	# The charging slot's own model gets its glow back, even when another weapon is now drawn.
	_set_glow(_charge_slot, 1.0)
	if _charge_slot >= 0 and _charge_slot < _viewmodels.size():
		_viewmodels[_charge_slot].set_charge(0.0)
	_charge_left = 0.0
	_charge_slot = -1


## The glow of slot `slot`'s viewmodel at `scale` times that weapon's own base.
func _set_glow(slot: int, scale: float) -> void:
	if slot < 0 or slot >= _viewmodels.size():
		return
	_viewmodels[slot].set_glow(inventory.defs[slot].viewmodel_glow_energy * scale)


## How far the rail's charge (or the rm -rf cannon's wind-up, C26) has come, from 0 to 1; 0 when
## it is not charging.
func charge_progress() -> float:
	if _charge_left <= 0.0 or _charge_total <= 0.0:
		return 0.0
	return clampf(1.0 - _charge_left / _charge_total, 0.0, 1.0)


func is_charging() -> bool:
	return _charge_left > 0.0


## SIGSTOP (C18): a round's end stops it at once; a new round fills its meter.
func end_sigstop() -> void:
	if sigstop != null and sigstop.meter != null:
		sigstop.end_now()


func refill_sigstop() -> void:
	if sigstop != null and sigstop.meter != null:
		sigstop.refill()


## The ult meter (C17): what a hit with another weapon earned, and back to empty.
func add_meter(amount: float) -> void:
	inventory.add_meter(amount)


func reset_meter() -> void:
	inventory.reset_meter()


## What the loadout's ult gains for a hit taking `share` of a target's health; 0 with no ult.
func meter_gain(share: float, killed: bool) -> float:
	var slot := inventory.ult_slot()
	return inventory.defs[slot].meter_gain(share, killed) if slot >= 0 else 0.0


## True when the player's last rail shot struck player `id` in the head zone (C17).
func took_head(id: int) -> bool:
	return _rail_heads.get(id, false)


## True when `point` is in this body's head zone: the top HEAD_ZONE_M of the capsule.
func is_head_hit(point: Vector3) -> bool:
	var shape := ($Shape as CollisionShape3D).shape as CapsuleShape3D
	var top := global_position.y + (shape.height * 0.5 if shape != null else 0.9)
	return point.y >= top - WeaponDefScript.HEAD_ZONE_M


## One shot of the drawn weapon: one ray for a single shot, one per pellet for SIGTERM, each
## pellet's damage eased by its distance; the rail's one piercing ray; a thrown weapon throws
## (C19). Hits on this machine's own dummies land here (and, solo, fill the ult meter); in a
## match the host judges every shot at another player from the intent alone.
func _fire() -> void:
	if _w.is_thrown():
		_throw_from(inventory.current)
		return
	if _w.is_fork():
		_fire_fork()
		return
	if _w.is_seeker():
		_fire_grep()
		return
	if _w.is_slug():
		_fire_slug()
		return
	if _w.is_mine():
		_fire_mine()
		return
	shots_fired += 1
	var origin := _camera.global_position
	var forward := -_camera.global_transform.basis.z
	var hit_target := false
	var fx_root := _fx_root()
	if _w.pierce:
		hit_target = _fire_rail(origin, forward, fx_root)
	for dir in (PackedVector3Array() if _w.pierce else _pellets(forward)):
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
				var before: float = collider.call("health") if collider.has_method("health") else 0.0
				var base: float = _w.damage_at(origin.distance_to(end_point))
				landed = collider.call("hit", base * _damage_scale(), end_point, dir) == true
				if landed:
					_meter_from(collider, before, base)
			hit_target = hit_target or landed
			CannonFx.spawn_impact(fx_root, end_point, normal, landed, _w)
		CannonFx.spawn_beam(fx_root, muzzle_point(), end_point, _w)
	CannonFx.spawn_muzzle_flash(_muzzle, _w, Palette.HOSTILE_RED if _root_look else Color.TRANSPARENT)
	_kick()
	if _shake_on:
		_shake = maxf(_shake, _w.shake_m)
	_fire_sfx.play()
	if hit_target:
		hits_landed += 1
		_hit_sfx.play()
	shot_fired.emit(hit_target)
	fire_intent.emit(origin, forward, _w.id)


## The rail's one ray, piercing: every target on the line up to fire_range takes the hit,
## dummies and other players alike, and the first piece of the level stops it. Dummies it
## derezzes count as rail kills here at once; for other players this machine only notes
## which were struck in the head, for when the host's word of the kill arrives. True when a
## dummy took a hit.
func _fire_rail(origin: Vector3, dir: Vector3, fx_root: Node) -> bool:
	var space := get_world_3d().direct_space_state
	var far_point := origin + dir * _w.fire_range
	var end_point := far_point
	var exclude: Array[RID] = [get_rid()]
	var landed_any := false
	_rail_heads = {}
	for i in WeaponDefScript.PIERCE_LAST + 1:
		var query := PhysicsRayQueryParameters3D.create(origin, far_point, _w.hit_mask)
		query.exclude = exclude
		var result := space.intersect_ray(query)
		if result.is_empty():
			break
		var collider = result["collider"]
		var point: Vector3 = result["position"]
		var normal: Vector3 = result["normal"] if not (result["normal"] as Vector3).is_zero_approx() else -dir
		var dummy: bool = is_instance_valid(collider) and collider.has_method("hit")
		var avatar: bool = is_instance_valid(collider) and collider.has_meta("player_id")
		if not dummy and not avatar:
			end_point = point  # the level: the rail stops here
			CannonFx.spawn_impact(fx_root, point, normal, false, _w)
			break
		exclude.append(collider.get_rid())
		var owner_node: Node = collider if dummy else collider.get_parent()
		var head: bool = owner_node != null and owner_node.has_method("is_head_hit") and owner_node.call("is_head_hit", point)
		if dummy:
			var landed: bool = collider.call("hit", _w.damage_at(origin.distance_to(point)) * _damage_scale(), point, dir) == true
			landed_any = landed_any or landed
			if landed and collider.has_method("is_alive") and not collider.call("is_alive"):
				rail_kill.emit(head)
		else:
			_rail_heads[int(collider.get_meta("player_id", 0))] = head
		CannonFx.spawn_impact(fx_root, point, normal, true, _w)
	CannonFx.spawn_beam(fx_root, muzzle_point(), end_point, _w)
	return landed_any


## A shot of fork() (C24): the muzzle flash, the kick and the sound here at once; the pellets
## fly as a volley (scripts/weapons/fork_volley.gd) from the eyes along the aim. Alone the
## volley runs here, its seed this player's own, and judges this arena's dummies (fork_hit);
## in a match only the intent goes, and the host runs the shot: every screen, this one too,
## draws its pellets from the host's seed. Root (C22) forks them once more.
func _fire_fork() -> void:
	shots_fired += 1
	var origin := _camera.global_position
	var forward := -_camera.global_transform.basis.z
	CannonFx.spawn_muzzle_flash(_muzzle, _w, Palette.HOSTILE_RED if _root_look else Color.TRANSPARENT)
	_kick()
	if _shake_on:
		_shake = maxf(_shake, _w.shake_m)
	_fire_sfx.play()
	fire_intent.emit(origin, forward, _w.id)
	if match_meter:
		return
	var root: bool = sudo != null and sudo.state != null and sudo.is_root()
	var volley := ForkVolley.spawn(_fx_root(), _w, origin, forward, _pellet_rng.randi(), _w.forks_for(root), true, _w.hit_mask, _not_me, fork_hit.bind(_w))
	take_volley(volley)


## A volley of this player's own fork() or grep shot, alone or drawn from the host's word in a
## match: a fork()'s first fork is the "fork()" callout, and when it is done the shot counts as
## fired, and as a hit, with the weapon's own hit sound, when a pellet or dart of it landed here.
func take_volley(volley: Node) -> void:
	# Drawn coming out of this player's barrel (A4), alone or in a match; it still flies from the
	# eyes (Codex review: a match's volleys reach the player only here).
	if volley.has_method("draw_from"):
		volley.draw_from(muzzle_point())
	if volley.has_signal("forked"):
		volley.forked.connect(_on_volley_forked)
	if volley.has_signal("blasted"):
		volley.blasted.connect(_on_volley_blasted)
	volley.finished.connect(_on_volley_finished.bind(inventory.slot_of(volley.def.id)))


func _on_volley_blasted(_at: Vector3) -> void:
	rm_blast.emit()


func _on_volley_forked(gen: int) -> void:
	if gen == 1:
		fork_split.emit()


func _on_volley_finished(landed: int, slot: int) -> void:
	if landed > 0:
		hits_landed += 1
		if slot >= 0 and slot < _sfx.size():
			_sfx[slot][1].play()
	shot_fired.emit(landed > 0)


## A fork() pellet of generation `gen` (C24), or a grep dart (C25, always generation 0), met
## `collider` at `at`: on a daemon of this arena it lands with the weapon's damage for its
## generation (root's harder hit alone, C22), and fills the ult meter as the other weapons do.
## True when it landed. Never a player: in a match the host judges those.
func fork_hit(collider: Object, gen: int, at: Vector3, dir: Vector3, def: WeaponDefScript) -> bool:
	if not is_instance_valid(collider) or not collider.has_method("hit"):
		return false
	var before: float = collider.call("health") if collider.has_method("health") else 0.0
	var base: float = def.fork_damage(gen)
	var landed: bool = collider.call("hit", base * _damage_scale(), at, dir) == true
	if landed:
		_meter_from(collider, before, base)
	return landed


## A shot of grep (C25): the muzzle flash, the kick and the sound here at once, and every mark
## spent. Alone a volley of darts runs here from the eyes along the aim, one homing on each mark
## (or one straight with none), its seed this player's own, judging this arena's dummies
## (fork_hit); in a match only the intent goes, its claims the marks' player ids
## (grep_claims()), and the host runs the shot: every screen, this one too, draws the darts the
## host believed.
func _fire_grep() -> void:
	shots_fired += 1
	var origin := _camera.global_position
	var forward := -_camera.global_transform.basis.z
	CannonFx.spawn_muzzle_flash(_muzzle, _w, Palette.HOSTILE_RED if _root_look else Color.TRANSPARENT)
	_kick()
	if _shake_on:
		_shake = maxf(_shake, _w.shake_m)
	_fire_sfx.play()
	var held: Array = grep.spend()
	_claims = PackedInt32Array()
	for m in held:
		_claims.append(m["id"])
	fire_intent.emit(origin, forward, _w.id)
	_claims = PackedInt32Array()
	if match_meter:
		return
	var points := []
	for m in held:
		points.append(GrepLock.mark_point.bind(m["target"]))
	var volley := SeekerVolley.spawn(_fx_root(), _w, origin, forward, _pellet_rng.randi(), points, true, _w.hit_mask, _not_me, fork_hit.bind(_w))
	take_volley(volley)


## A shot of the rm -rf cannon (C26), its wind-up done: the muzzle flash, the kick and the sound
## here at once, and the weight for move_slow_s. Alone the slug flies here from the eyes along
## the aim and blasts this arena's daemons (_judge_slug); in a match only the intent goes, and
## the host runs the slug: every screen, this one too, draws it and its blast from the host.
func _fire_slug() -> void:
	shots_fired += 1
	var origin := _camera.global_position
	var forward := -_camera.global_transform.basis.z
	CannonFx.spawn_muzzle_flash(_muzzle, _w, Palette.HOSTILE_RED if _root_look else Color.TRANSPARENT)
	_kick()
	if _shake_on:
		_shake = maxf(_shake, _w.shake_m)
	_fire_sfx.play()
	_slow_left = _w.move_slow_s
	_slow_scale = _w.move_factor()
	fire_intent.emit(origin, forward, _w.id)
	if match_meter:
		return
	var root: bool = sudo != null and sudo.state != null and sudo.is_root()
	var slug := RmSlug.spawn(_fx_root(), _w, origin, forward, root, true, _w.hit_mask, _not_me, _judge_slug.bind(_w, root))
	take_volley(slug)


## A placement of cron (C27): the small flash, kick and sound here at once. Alone the mine sticks
## where the aim meets the level within the placement range (at the feet with none), runs from
## here, judged by _judge_mine, and the crontab keeps its limit (the oldest removed, and noted);
## in a match only the intent goes, and the host places it. Root's mine gets its extra run.
func _fire_mine() -> void:
	var origin := _camera.global_position
	var forward := -_camera.global_transform.basis.z
	CannonFx.spawn_muzzle_flash(_muzzle, _w, Palette.HOSTILE_RED if _root_look else Color.TRANSPARENT)
	_kick()
	_fire_sfx.play()
	fire_intent.emit(origin, forward, _w.id)
	if match_meter:
		return
	var root: bool = sudo != null and sudo.state != null and sudo.is_root()
	var place := CronMine.place(get_world_3d().direct_space_state, origin, forward, _w.place_range_m, global_position, _half_height())
	_placed += 1
	var mine := CronMine.spawn(_fx_root(), _w, place["at"], place["normal"], _placed, 0, _w.runs_for(root), true, false, _judge_mine.bind(_w))
	take_mine(mine)
	var live := _live_jobs()
	if live.size() > _w.crontab_limit:
		live[0].remove(CronMine.CRONTAB)
		note_crontab_full(_w)


## A mine of this player's (C27): kept for the strip's count, its first run the callout.
func take_mine(mine: Node) -> void:
	_jobs = _live_jobs()
	_jobs.append(mine)
	mine.ran.connect(_on_mine_ran.bind(mine))


func _on_mine_ran(left: int, _at: Vector3, mine: Node) -> void:
	if is_instance_valid(mine) and left == mine.runs_total - 1:
		cron_ran.emit()


## This player's mines still running, oldest first.
func _live_jobs() -> Array:
	return _jobs.filter(func(m): return is_instance_valid(m) and m.running())


## How many of this player's jobs run now (C27): the strip's "crontab N/limit".
func crontab_count() -> int:
	return _live_jobs().size()


## The crontab was full and its oldest job went: the strip says so for crontab_note_s.
func note_crontab_full(def: WeaponDefScript) -> void:
	_crontab_note_left = def.crontab_note_s


func crontab_noted() -> bool:
	return _crontab_note_left > 0.0


## A new round, alone: every job of this player's ends (C27). In a match the host owns them.
func clear_jobs() -> void:
	if match_meter:
		return
	for mine in _live_jobs():
		mine.remove(CronMine.GONE)
	_jobs = []


## Half the body's height: from its middle down to its feet.
func _half_height() -> float:
	var shape := ($Shape as CollisionShape3D).shape as CapsuleShape3D
	return shape.height * 0.5 if shape != null else DUMMY_MIDDLE_M


## Alone, a run of this player's cron mine at `at` (C27): every daemon of this arena within the
## blast's radius with nothing of the level between takes the blast's damage for its distance at
## this player's strength (root's harder hit, C22). The player itself is never hurt by its own
## mines (nor has health alone). How many it hurt.
func _judge_mine(at: Vector3, def: WeaponDefScript) -> int:
	return _judge_slug(at, def, false)


## Alone, the blast of this player's rm -rf slug at `at` (C26): every daemon of this arena whose
## middle is within the blast's radius (root's larger one with `root`), with nothing of the level
## between, takes the blast's damage for its distance at this player's strength (root's harder
## hit alone, C22) and fills the ult meter as the other weapons do. The player itself has no
## health alone. How many it hurt.
func _judge_slug(at: Vector3, def: WeaponDefScript, root: bool) -> int:
	var arena := _fx_root()
	var space := get_world_3d().direct_space_state
	var hurt := 0
	for dummy in get_tree().get_nodes_in_group("targets"):
		if not arena.is_ancestor_of(dummy) or not dummy.has_method("hit") or (dummy.has_method("is_alive") and not dummy.call("is_alive")):
			continue
		var middle: Vector3 = (dummy as Node3D).global_position + Vector3.UP * DUMMY_MIDDLE_M
		var base: float = def.blast_damage_at(at.distance_to(middle), root)
		if base <= 0.0:
			continue
		var sight := PhysicsRayQueryParameters3D.create(at + Vector3.UP * ForkBomb.SIGHT_LIFT_M, middle, 1)
		if not space.intersect_ray(sight).is_empty():
			continue  # a wall between: the blast does not reach
		var before: float = dummy.call("health") if dummy.has_method("health") else 0.0
		if dummy.call("hit", base * _damage_scale(), middle, (middle - at).normalized()) == true:
			hurt += 1
			_meter_from(dummy, before, base)
	return hurt


## The marks' player ids the grep shot being sent claims (C25): the session reads them while
## the intent is emitted. Empty at any other moment.
func grep_claims() -> PackedInt32Array:
	return _claims


## grep's lock for this physics step (C25): with grep in hand and drawn, its marks are kept and
## a lock builds while the aim is held (or toggled) and nothing blocks the input.
func _step_grep(delta: float) -> void:
	if grep == null or not _w.is_seeker() or not alive:
		return
	var root: bool = sudo != null and sudo.state != null and sudo.is_root()
	var aiming := _aiming and not input_blocked and not inventory.is_swapping()
	grep.step(delta, _w, _camera.global_position, -_camera.global_transform.basis.z, aiming, root)


## What this player's own pellets pass through: its own body.
func _not_me() -> Array[RID]:
	return [get_rid()]


## Solo, a hit on a dummy with a weapon other than the ult fills the meter: the share of the
## dummy's health it took, and the kill bonus if it went down. In a match only the host's
## results fill it. `base` is the hit at user's strength: root's harder hit counts as that,
## so root fills the meter no faster (C22).
func _meter_from(dummy: Node, before: float, base: float) -> void:
	if match_meter or _w.is_ult() or not dummy.has_method("health"):
		return
	var max_health = dummy.get("max_health")
	if not (max_health is float) or max_health <= 0.0:
		return
	var killed: bool = dummy.has_method("is_alive") and not dummy.call("is_alive")
	var share: float = clampf(minf(base, before), 0.0, before) / float(max_health)
	inventory.add_meter(meter_gain(share, killed))


## G: one fork bomb thrown from its own slot without drawing it (C19). False when there is
## none to throw (no thrown weapon, none left, inside its interval, or derezzed).
func quick_throw() -> bool:
	var slot := inventory.thrown_slot()
	if slot < 0 or not alive or _bombs_full(slot) or inventory.try_throw(slot) != "":
		return false
	_throw_from(slot)
	return true


## True solo while this player's live bomblets are at the fork bomb's cap: no throw, and no
## bomb spent (in a match the host keeps the cap).
func _bombs_full(slot: int) -> bool:
	var tuning: Resource = inventory.defs[slot].projectile
	return not match_meter and tuning != null and ForkBomb.live_of(_fx_root(), "solo") >= tuning.live_cap


## A throw of the thrown weapon in `slot`, its bomb already spent: from just in front of the
## eyes along the aim. Solo its chain runs here, judged by _judge_blast(); in a match the
## intent goes to the session and the host runs it.
func _throw_from(slot: int) -> void:
	var def: WeaponDefScript = inventory.defs[slot]
	var forward := -_camera.global_transform.basis.z
	var eye := _camera.global_position
	var origin := eye + forward * THROW_AHEAD_M
	# Never past the level: against a wall the bomb leaves on this side of it (a ray that
	# starts inside a wall would not see it, and the bomb would fly on beyond).
	var probe := PhysicsRayQueryParameters3D.create(eye, origin, 1)
	var wall := get_world_3d().direct_space_state.intersect_ray(probe)
	if not wall.is_empty():
		origin = eye + forward * maxf(eye.distance_to(wall["position"]) - THROW_CLEAR_M, 0.0)
	_sfx[slot][0].play()
	if slot == inventory.current:
		_viewmodel_kick = 1.0
	throw_intent.emit(origin, forward, def.id)
	if match_meter:
		return
	var never: Array[RID] = [get_rid()]
	var chain := ForkBomb.spawn(_fx_root(), def.projectile, origin, ForkBomb.throw_velocity(def.projectile, forward), _bomb_rng.randi(), "solo", true, def.light_skin, never, _judge_blast.bind(def))
	chain.blasted.connect(_on_bomb_blasted)


## The first blast of a throw (generation 0): the callout.
func _on_bomb_blasted(gen: int, _index: int, _at: Vector3) -> void:
	if gen == 0:
		fork_bomb_burst.emit()


## Solo, a blast of this player's fork bomb: every daemon of this arena within its radius,
## with nothing of the level between the blast and the daemon's middle, takes the tuning's
## damage for its distance (the thrower is never hurt: no self-damage). A daemon it hurts
## fills the ult meter as the other weapons do.
func _judge_blast(_gen: int, _index: int, at: Vector3, def: WeaponDefScript) -> void:
	var tuning: Resource = def.projectile
	var root := _fx_root()
	var space := get_world_3d().direct_space_state
	for dummy in get_tree().get_nodes_in_group("targets"):
		if not root.is_ancestor_of(dummy) or not dummy.has_method("hit") or (dummy.has_method("is_alive") and not dummy.call("is_alive")):
			continue
		var middle: Vector3 = (dummy as Node3D).global_position + Vector3.UP * DUMMY_MIDDLE_M
		var base: float = tuning.damage_at(at.distance_to(middle))
		var amount: float = base * _damage_scale()
		if amount <= 0.0:
			continue
		var sight := PhysicsRayQueryParameters3D.create(at + Vector3.UP * ForkBomb.SIGHT_LIFT_M, middle, 1)
		if not space.intersect_ray(sight).is_empty():
			continue  # a wall between: the blast does not reach
		var before: float = dummy.call("health") if dummy.has_method("health") else 0.0
		if dummy.call("hit", amount, middle, (middle - at).normalized()) == true and not match_meter:
			var max_health = dummy.get("max_health")
			if max_health is float and max_health > 0.0:
				var killed: bool = dummy.has_method("is_alive") and not dummy.call("is_alive")
				inventory.add_meter(meter_gain(clampf(minf(base, before), 0.0, before) / max_health, killed))  # at user's strength (C22)


## How hard this player's weapons hit right now, alone: root's damage_scale, or 1 as user
## (C22). In a match always 1: only the host applies root's harder hits, where it judges them.
func _damage_scale() -> float:
	if match_meter or sudo == null or sudo.state == null:
		return 1.0
	return sudo.damage_scale()


## A daemon of this arena went down: alone, a kill toward a sudo charge (C22).
func on_dummy_downed() -> void:
	if sudo != null and sudo.state != null:
		sudo.local_kill()


## Root's free ammo for this physics step, and its look on every viewmodel when it changes.
func _step_root() -> void:
	var root: bool = sudo != null and sudo.state != null and sudo.is_root()
	inventory.free_ammo = root
	if root == _root_look:
		return
	_root_look = root
	var scale: float = sudo.tuning_in_use().glow_scale if root else 1.0
	for i in _viewmodels.size():
		var color: Color = Palette.HOSTILE_RED if root else inventory.defs[i].skin_body()
		var beam: Color = Palette.HOSTILE_RED if root else inventory.defs[i].skin_beam()
		_viewmodels[i].set_look(color, beam, inventory.defs[i].viewmodel_glow_energy * scale)


## True while the weapons wear root's red (C22).
func shows_root() -> bool:
	return _root_look


## The bombs back to full: a new round (C19). In a match the host's count decides.
func refill_bombs() -> void:
	if inventory != null and not match_meter:
		inventory.refill_thrown()


## Puts the drawn weapon in view, with its muzzle and its sounds.
func _show_weapon() -> void:
	if grep != null:
		grep.clear()  # putting grep away, or drawing it again, drops its marks (C25)
	_w = inventory.def()
	for i in _viewmodels.size():
		_viewmodels[i].visible = i == inventory.current and alive
	_viewmodel = _viewmodels[inventory.current]
	_muzzle = _viewmodel.muzzle
	_fire_sfx = _sfx[inventory.current][0]
	_hit_sfx = _sfx[inventory.current][1]
	_reload_sfx = _sfx[inventory.current][2]
	_viewmodel_kick = 0.0


## Puts the recoil on the camera, clamped so aim plus recoil stays within the pitch limit.
func _apply_recoil() -> void:
	var pitch_room := maxf(deg_to_rad(_t.pitch_limit_degrees) - _head.rotation.x, 0.0)
	_recoil.x = minf(_recoil.x, pitch_room)
	_camera.rotation = Vector3(_recoil.x, _recoil.y, 0.0)


## Every pellet's direction for a shot along `forward`: the weapon's spread, or all of them
## straight along it while SIGSTOP holds this player's hands steady (C18).
func _pellets(forward: Vector3) -> PackedVector3Array:
	if sigstop != null and sigstop.steady():
		return _w.steady_directions(forward)
	return _w.pellet_directions(forward, _pellet_rng)


## Camera kick up plus a small random yaw, both capped, and a cannon jolt. None while SIGSTOP
## holds the hands steady (C18): the viewmodel still kicks.
func _kick() -> void:
	_viewmodel_kick = 1.0
	if sigstop != null and sigstop.steady():
		return
	var max_pitch := deg_to_rad(_w.recoil_max_pitch_degrees)
	var max_yaw := deg_to_rad(_w.recoil_max_yaw_degrees)
	var yaw := deg_to_rad(_rng.randf_range(-_w.recoil_yaw_degrees, _w.recoil_yaw_degrees))
	_recoil.x = minf(_recoil.x + deg_to_rad(_w.recoil_pitch_degrees), max_pitch)
	_recoil.y = clampf(_recoil.y + yaw, -max_yaw, max_yaw)


## Where world-space effects live: the running scene, or the player's parent in tests.
func _fx_root() -> Node:
	var scene := get_tree().current_scene
	return scene if scene != null else get_parent()


## The weapon's model in first person (A1, scripts/viewmodels/), the one its viewmodel_model names,
## out of view until drawn.
func _build_viewmodel(def: WeaponDefScript) -> Viewmodel:
	var model := Viewmodel.make(def)
	_viewmodel_rig.add_child(model)
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
