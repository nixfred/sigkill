extends StaticBody3D
## Target dummy: a daemon standing in for a rogue process. It takes hits, and when it dies it
## derezzes, then rematerialises at its spot with full health. Its hit volume is a hexagonal
## prism (the Shape, and the Body's hex mesh, which is its size and centre for everything that
## measures it); since A2 what is seen of it is its art (scripts/daemons/), built under the Body
## and drawn instead of the hex, so it hides and grows back with it; since A2b the art is a
## creature that recoils and sprays shards at a hit and bursts into its own parts at the death,
## over the derezz. The art is visual only.
## States: ALIVE, DEREZZING (collision off, hidden, not hittable), RESPAWNING (growing
## back, still not hittable), then ALIVE again. Only an ALIVE dummy can be hit, so it dies
## exactly once per life. The tag text is invented flavour only; it never reflects anything on
## the player's system.
##
## Since C27b the daemons fight back: each dummy carries a brain (scripts/fight/daemon_brain.gd)
## that the arena's director steps: it hunts, tells and strikes, and moves the dummy itself (its
## hit volume goes with it); a respawn puts it back at its spot. In practice it is the old dummy
## that never moves or attacks. On a joiner in a match where they fight, its daemons are the
## host's: they follow the host's word, and a shot here takes nothing off them (the host judges
## every shot at a daemon). rogue.d's hit volume is fair to what is seen of it: beyond the
## cylinder, a box round its body from head to tail turns and moves with its art.
##
## No two alike (A5): its art is built from a seed, a new one at each spawn in play, so each comes
## back a different creature of its type (its size, plates, seams, stance, gait, battle damage), now
## and then its type's elite, which takes at least the daemon tuning's elite_health. In demo, test and
## capture runs (--demo, or a --script run) the seed is fixed by its name, so stills and checks are
## the same every run. On a joiner in a match the host's seeds rebuild it (follow_seed()), so every
## screen draws the same daemon. Its death derezzes in its type's own colour.
##
## chmod 000 (C29): the freeze ray's beam builds its freeze meter (chill(); its Frost, an elite's slower
## to fill); a full one freezes it (its brain does nothing, its art holds still, a tell it was in is
## called off) under a frost crust (scripts/fx/frost_look.gd). The next hit on it frozen thaws it and
## lands the freeze tuning's frozen_hit_scale times harder, and one at least shatter_damage strong
## shatters it whatever its health; every kill of a frozen daemon is a shatter: it derezzes in the frost
## opal in a storm of frost. In practice the beam freezes the old dummy too. On a joiner in a match where
## they fight its meter is the host's word (follow_frost()).
##
## SIGHUP (C32): a hangup burst catching it confuses its brain (take_hup(): its reload, then its wander;
## scripts/fight/daemon_brain.gd) and its look shows it (scripts/fx/hup_look.gd: the "reloading config" tag,
## then the "?", its seams cycling in the carrier green, its pose stuttering). In practice the old dummy
## reloads and wanders too. On a joiner its confusion is the host's word, carried beside its life.

const Palette = preload("res://scripts/palette.gd")
const Derezz = preload("res://scripts/derezz_tuning.gd")
const DerezzFx = preload("res://scripts/derezz_fx.gd")
const DEFAULT_DEREZZ_PATH := "res://resources/derezz.tres"
const WeaponDefScript = preload("res://scripts/weapons/weapon_def.gd")
const DAEMON_AI_PATH := "res://resources/daemon_ai.tres"
## A shatter's storm of frost: the whole of the frost pool's chips (C29).
const SHATTER_BURST := 1.0

enum State { ALIVE, DEREZZING, RESPAWNING }

## Emitted once per death, on the hit that starts the derezz.
signal downed(dummy: Node3D)
## Emitted when the dummy is back: alive, hittable and at full health.
signal respawned(dummy: Node3D)

## Smallest body scale while rematerialising, so its transform never collapses to zero.
const MIN_BODY_SCALE := 0.001

## Whether every daemon's seed is fixed by its name (A5): in demo, test and capture runs, so the
## same tree gives the same daemons; in play each spawn rolls a new one.
static var fixed_seeds: bool = OS.get_cmdline_user_args().has("--demo") or OS.get_cmdline_args().has("--script")
static var _elite_health := -1.0

@export var tag_text: String = "<defunct>"
@export var max_health: float = 1.0
## Derezz and respawn tuning. Leave empty to use resources/derezz.tres.
@export var derezz: Resource
## How the daemon looks (A2): a script extending scripts/daemons/daemon_art.gd. Visual only.
@export var art: Script = preload("res://scripts/daemons/rogue_daemon.gd")

var state: State = State.ALIVE

var _health := 1.0
## Its own health as the scene gave it, before an elite's (A5).
var _base_health := 1.0
var _state_time := 0.0
var _hex: CylinderMesh
var _art: DaemonArt
var _d: Derezz
## Its brain (C27b), and the box round its body when its art gives one.
var brain: DaemonBrain
var _box: CollisionShape3D
## Whether this daemon's last death was this player's kill (C27b): alone always; in a match the
## host's own shots' kills on the host, a joiner's kills (the host's word, _daemon_struck) on that
## joiner. Every death is told (downed); what listens for this player's kills reads this.
var credited := true
## On the host, whose kill its last death was: another player's id, or 0 for this machine's own
## player (C27b; sent in the state word, so a joiner's copy credits it with the death itself).
var killer := 0
## The weapon its last death came from (its id, the killing hit's source; "" for none, a lash's), and whether that
## death was a frozen body shattered (C33: the feats a kill earns, scripts/unlocks/progress.gd).
var killed_with := ""
var shattered_last := false
## The next death's credit and killer: a hit another player's shot landed (the host judging a
## joiner's) credits none here and names that player.
var _credit := true
var _killer := 0
## Its freeze meter and freeze (C29), and its frost on screen once the beam has met it.
var frost: Frost
## /dev/null (C31): the last physics frame a hole holds it to.
var _held_until := -1
## /dev/null (C31): set round a hole's damage over time so it lands quietly: no flash, no recoil, no spray,
## nothing roused (the hole's own pull is its look); a kill still derezzes as any.
var quiet := false
var _frost_look: FrostLook
## Its deaths that were shatters (C29), for the checks.
var shatters := 0
## SIGHUP's look on it (C32), made the first time it is hung up.
var _hup_look: HupLook

@onready var _body: MeshInstance3D = $Body
@onready var _shape: CollisionShape3D = $Shape
@onready var _tag: Label3D = $Tag


func _ready() -> void:
	_base_health = max_health
	_hex = _body.mesh as CylinderMesh
	# The hex is the volume, drawn by no camera; the art under it is what is seen (A2).
	_body.layers = 0
	_body.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	frost = Frost.new()
	_build_art(_spawn_seed())
	_health = max_health
	brain = DaemonBrain.new(self, _art)
	brain.take_home()
	# The box round the body (C27b), on the dummy itself beside the cylinder: a shot that meets
	# what is seen of the creature hits it.
	if _art.body_box_size() != Vector3.ZERO:
		var box := BoxShape3D.new()
		box.size = _art.box_size()
		_box = CollisionShape3D.new()
		_box.name = "BodyBox"
		_box.shape = box
		add_child(_box)
		_fit_box()

	_tag.text = tag_text
	_tag.position.y = _art.tag_y()  # clear of the creature (A2b), at its size (A5)
	_tag.font = Palette.mono_font()
	_tag.font_size = 48
	_tag.pixel_size = 0.006
	_tag.outline_size = 10
	_tag.modulate = Palette.MINT
	_tag.outline_modulate = Palette.VOID
	_tag.billboard = BaseMaterial3D.BILLBOARD_ENABLED

	if not (derezz is Derezz):
		derezz = load(DEFAULT_DEREZZ_PATH)
	_d = derezz as Derezz
	if _d == null:
		push_error("target dummy: no derezz tuning resource at " + DEFAULT_DEREZZ_PATH)
		_d = Derezz.new()
	var issues := _d.problems()
	if not issues.is_empty():
		for issue in issues:
			push_warning("derezz tuning: " + issue + "; using the built-in defaults instead")
		_d = Derezz.new()


## True only while the dummy is alive. Derezzing and respawning dummies ignore hits.
func is_hittable() -> bool:
	return state == State.ALIVE


## True while the dummy counts as a live enemy, which the code rain on the walls reacts to.
func is_alive() -> bool:
	return state == State.ALIVE


## Where the dummy is, for anything that measures distance to it: the centre of its body.
func threat_point() -> Vector3:
	return _body.global_position


func health() -> float:
	return _health


## True when `point` is in the dummy's head zone (C17): the top of its prism, WeaponDef's
## HEAD_ZONE_M deep. A rail kill there is called out as "kill -9".
func is_head_hit(point: Vector3) -> bool:
	return point.y >= _body.global_position.y + _hex.height * 0.5 - WeaponDefScript.HEAD_ZONE_M


## /dev/null (C31): a hole holds it for `seconds` more (renewed each step it is held): while held its brain
## does nothing of its own and the hole moves it.
func hold_in_hole(seconds: float) -> void:
	_held_until = maxi(_held_until, Engine.get_physics_frames() + ceili(seconds * Engine.physics_ticks_per_second))


## True while a hole holds it.
func held_by_hole() -> bool:
	return Engine.get_physics_frames() <= _held_until and is_alive()


## How many times as hard a /dev/null hole drags it now: harder while SIGHUP has it confused (C32).
func hole_pull_scale() -> float:
	return brain.hole_pull_scale() if brain != null else 1.0


## SIGHUP's hangup (C32) from player `by` (0 alone) with numbers `t`: its brain is confused (see
## scripts/fight/daemon_brain.gd hangup()). True when it took it; never on a joiner's copy of the host's
## daemon (the host judges) or while it is down.
func take_hup(t: SighupTuning, by: int = 0) -> bool:
	if state != State.ALIVE or brain == null or _follows():
		return false
	var took := brain.hangup(t, by, DaemonDirector.of(self))
	_show_hup()
	return took


## SIGHUP's look on it now (C32), or null before it was ever hung up.
func hup_look() -> HupLook:
	return _hup_look


## Its look follows its brain's confusion: made the first time it is confused, then told each frame.
func _show_hup() -> void:
	if brain == null:
		return
	var phase: int = brain.hup if is_alive() else 0
	if _hup_look == null:
		if phase == 0:
			return
		_hup_look = HupLook.of(_art)
	_hup_look.show_phase(phase, brain.hup_share())


## Called by the player's cannon through the ray hit. Returns true if the hit landed,
## false if the dummy is derezzing or respawning. `point` is where the shot struck and
## `direction` the way it travelled; both are optional. `source` (I1) is the weapon's id, the hit's
## damage type: ICE's director notes it for the hunter's adaptation (an empty one counts for none).
## On a joiner in a match where the daemons fight (C27b), the host's daemons follow its word and
## this machine's shots land nothing on them: false.
func hit(damage: float, point: Vector3 = Vector3.INF, direction: Vector3 = Vector3.ZERO, source: String = "") -> bool:
	if state != State.ALIVE or _follows():
		return false
	# An exploit breaker's bonus on a weak seam (I2): this machine's own shot, or the joiner's the host
	# is judging.
	var breakers := BreakerDirector.of(self)
	var scale: float = breakers.exploit_scale(_killer if _killer != 0 else breakers.my_id(), self, point, source) if breakers != null else 1.0
	# Frozen by chmod 000 (C29): the hit thaws it and lands harder; a strong one shatters it outright.
	var frozen_now := frost != null and frost.frozen()
	if frozen_now:
		frost.thaw()
		_art.frozen = false
		scale *= frost.tuning.frozen_hit_scale
		if damage >= frost.tuning.shatter_damage:
			_health = 0.0
	_health -= damage * scale
	var ice := IceDirector.of(self)
	if ice != null:
		ice.note_damage(source, damage)  # the system learns which weapon hits it hardest (I1)
	if _health > 0.0:
		if quiet:
			return true
		_pulse(point, direction)
		var director := DaemonDirector.of(self)
		if brain != null and director != null:
			brain.on_hit(point, director)  # roused, or a swarm scattered (C27b)
		return true
	killed_with = source
	_start_derezz(point, direction, frozen_now)
	return true


## chmod 000's beam on it for `seconds` (C29): its freeze meter builds; true when that froze it just now.
## Nothing while it is down, and nothing on a joiner's copy of the host's daemon (the host judges).
func chill(seconds: float, _point: Vector3 = Vector3.INF, _direction: Vector3 = Vector3.ZERO, _source: String = "") -> bool:
	if state != State.ALIVE or _follows() or frost == null:
		return false
	var froze := frost.beam(seconds)
	if froze:
		_art.frozen = true
	_show_frost()
	return froze


## True while chmod 000 holds it frozen (C29): its brain does nothing.
func chmod_frozen() -> bool:
	return frost != null and frost.frozen() and state == State.ALIVE


## On a joiner in a match where the daemons fight (C29), the host's word on its freeze meter: the bits
## Frost packs beside its state.
func follow_frost(bits: int) -> void:
	if frost == null:
		return
	frost.take_bits(bits)
	_art.frozen = frost.frozen() and state == State.ALIVE
	_show_frost()


## Its frost on screen, made the first time there is any.
func _show_frost() -> void:
	if _frost_look == null and frost != null and (frost.chill > 0.0 or frost.frozen()):
		_frost_look = FrostLook.of(_art, frost)


## The frost on it now (C29), or null before the beam has met it.
func frost_look() -> FrostLook:
	return _frost_look


## A hit another player's shot landed (C27b: the host judging a joiner's shot at its daemon): as
## hit(), but a kill is not this player's.
func hit_by_other(damage: float, point: Vector3 = Vector3.INF, direction: Vector3 = Vector3.ZERO, shooter: int = 0, source: String = "") -> bool:
	_credit = false
	_killer = shooter
	var landed := hit(damage, point, direction, source)
	_credit = true
	_killer = 0
	return landed


## True while this daemon follows the host's word (C27b): a joiner's, in a match where they fight.
func _follows() -> bool:
	var director := DaemonDirector.of(self)
	return director != null and director.mode == DaemonDirector.Mode.FOLLOW


func _physics_process(delta: float) -> void:
	_fit_box()
	_show_hup()
	if state == State.ALIVE:
		if frost != null and frost.tick(delta):
			_art.frozen = false  # thawed (C29)
		return
	_state_time += delta
	# A joiner's copy of the host's daemon (C27b) changes state only on the host's word: it never
	# comes back on its own clock, and it waits grown for the host's "alive".
	var own := not _follows()
	if state == State.DEREZZING:
		if own and _state_time >= _d.respawn_delay:
			_begin_rematerialise()
	elif state == State.RESPAWNING:
		var grown := 1.0
		if _d.rematerialise_seconds > 0.0:
			grown = clampf(_state_time / _d.rematerialise_seconds, 0.0, 1.0)
		_body.scale = Vector3.ONE * maxf(grown, MIN_BODY_SCALE)
		_art.set_unstable(1.0 - grown)  # it glitches as it comes back (A2)
		if grown >= 1.0 and own:
			_finish_respawn()


func _start_derezz(point: Vector3, direction: Vector3, shattered: bool = false) -> void:
	credited = _credit
	killer = 0 if _credit else _killer
	shattered_last = shattered
	_go_down()
	# The voxels get a push along the killing shot: its real direction when the shooter
	# gives one, otherwise from where it struck toward the body's centre.
	var shot := Vector3(direction.x, 0.0, direction.z)
	if shot.is_zero_approx() and point.is_finite():
		shot = _body.global_position - point
		shot.y = 0.0
	shot = shot.normalized()
	var fx := DerezzFx.new()
	_fx_root().add_child(fx)
	# In its type's colour (A5); a frozen daemon's shatter in the frost opal, in a storm of frost (C29).
	fx.start(global_position, _hex.top_radius, _hex.height, shot, _d, 0, Palette.FROST if shattered else _art.core_color)
	_art.shatter(fx, shot)  # the creature's own parts burst apart with the voxels, and go with them (A2b)
	if shattered:
		shatters += 1
		var chips := ParticleFx.of(self)
		if chips != null:
			chips.frost(_body.global_position, _hex.height * 0.6, SHATTER_BURST)
	downed.emit(self)


## Down: derezzing, its collision off, hidden.
func _go_down() -> void:
	state = State.DEREZZING
	_state_time = 0.0
	if frost != null:
		frost.clear()
	_art.frozen = false
	_shape.set_deferred("disabled", true)
	if _box != null:
		_box.set_deferred("disabled", true)
	_body.visible = false
	_tag.visible = false


## Where world-space effects live: the running scene, or the dummy's parent in tests.
func _fx_root() -> Node:
	var scene := get_tree().current_scene
	return scene if scene != null else get_parent()


func _begin_rematerialise() -> void:
	state = State.RESPAWNING
	_state_time = 0.0
	_go_home()
	# A new spawn, a new daemon (A5): built from its next seed while it is still nothing. A joiner's
	# copy waits for the host's seed (follow_seed()).
	if not _follows():
		var seed := _spawn_seed()
		if seed != _art.build_seed:
			_build_art(seed)
	_body.scale = Vector3.ONE * MIN_BODY_SCALE
	_body.visible = true
	_art.set_unstable(1.0)


func _finish_respawn() -> void:
	state = State.ALIVE
	_health = max_health
	if frost != null:
		frost.clear()
	_body.scale = Vector3.ONE
	_art.set_unstable(0.0)
	_tag.visible = true
	_shape.set_deferred("disabled", false)
	if _box != null:
		_box.set_deferred("disabled", false)
	respawned.emit(self)


## On a joiner in a match where the daemons fight (C27b), the host's word on this daemon's life:
## down when the host's is (its derezz plays here, this player's kill when `mine`, the host's word
## of whose kill it was), back when the host's is, and its health, a drop flashing it as a hit does.
func follow_life(word: int, host_health: float, mine: bool = false) -> void:
	match word:
		State.DEREZZING:
			if state == State.ALIVE:
				_derezz_on_word(mine)
			elif state == State.RESPAWNING:
				_hide_down()  # down again before it was back: hidden, with no second burst
		State.RESPAWNING:
			if state == State.ALIVE:
				_derezz_on_word(mine)
			if state == State.DEREZZING:
				_begin_rematerialise()
		State.ALIVE:
			if state == State.DEREZZING:
				_begin_rematerialise()
			if state == State.RESPAWNING:
				_finish_respawn()
	if state == State.ALIVE:
		if host_health < _health - 0.001:
			_pulse()
		_health = clampf(host_health, 0.0, max_health)


## Down on the host's word (C27b): this player's kill only when the host's word says so.
func _derezz_on_word(mine: bool) -> void:
	_credit = mine
	_start_derezz(Vector3.INF, Vector3.ZERO)
	_credit = true


## Down, hidden and out of reach, with no effect: a joiner's copy the host's word put down again.
func _hide_down() -> void:
	_go_down()



## A new round: back at once, alive, hittable and at full health. A dummy that was down
## (derezzing or growing back) says so with `respawned`; its voxels finish on their own.
func reset_for_round() -> void:
	if _follows():
		return  # a joiner's copy of the host's daemon: the host's word owns its life (C27b)
	var director := DaemonDirector.of(self)
	if director != null and brain != null:
		director.stop_bolts_of(brain)  # a new round leaves none of its bolts flying (Codex review)
	if state == State.DEREZZING:
		_begin_rematerialise()
	if state == State.RESPAWNING:
		_finish_respawn()
	_health = max_health
	if frost != null:
		frost.clear()
	_art.frozen = false
	_go_home()


## Back at its spot at once, facing as it did, its hunt dropped (C27b): a respawn, a new round.
func _go_home() -> void:
	if brain == null or not brain.has_home:
		return
	var director := DaemonDirector.of(self)
	if director != null:
		director.release_slot(brain)
	brain.holds_slot = false
	brain.prey = 0
	brain.burst_left = 0
	brain.state = DaemonBrain.State.HOME if state == State.ALIVE else DaemonBrain.State.DOWN
	brain.state_t = 0.0
	if brain.moved:
		global_transform = brain.home
		brain.moved = false


## The box round the body where the art has it now (C27b): beside the cylinder, under the Body.
func _fit_box() -> void:
	if _box != null:
		var xf := _body.transform * _art.transform * _art.body_box()
		xf.basis = xf.basis.orthonormalized()  # never scaled: a body growing back from nothing
		_box.transform = xf


## A hit that did not kill: the art flares (A2), recoils and sprays shards from where it struck (A2b).
func _pulse(point: Vector3 = Vector3.INF, direction: Vector3 = Vector3.ZERO) -> void:
	_art.react(point, direction)


## The daemon's art (A2), for the checks.
func art_node() -> DaemonArt:
	return _art


## The seed its art was built from (A5): what a match's host sends its joiners.
func build_seed() -> int:
	return _art.build_seed


## On a joiner in a match (A5), the host's seed for this daemon: rebuilt from it when it differs, so
## this screen draws the host's daemon (its size, its build, an elite's health).
func follow_seed(seed: int) -> void:
	if seed >= 0 and seed <= DaemonArt.SEED_LAST and seed != _art.build_seed:
		_build_art(seed)


## The seed for its next spawn (A5): fixed by its name in demo, test and capture runs, else a new
## roll.
func _spawn_seed() -> int:
	if fixed_seeds:
		return DaemonArt.seed_of(tag_text)
	return randi() & DaemonArt.SEED_LAST


## Builds its art from `seed` (A5), in place of the one it had: under the Body, its brain told,
## what the old one was doing carried over (its glitch, its displays, its act), its body box, its
## tag and its health fitted to the new build. Only at a spawn, or a joiner's first word of the
## host's daemon.
func _build_art(seed: int) -> void:
	var old := _art
	_art = DaemonArt.make(art, self, seed)
	_frost_look = null  # it lived under the old art (C29)
	if frost != null:
		frost.kind = Frost.Kind.ELITE if _art.elite else Frost.Kind.DAEMON
	if old != null:
		_art.displays = old.displays
		_art.drive(old.act, old.act_u)
		_body.remove_child(old)
		old.queue_free()
	_body.add_child(_art)
	if old != null:
		_art.set_unstable(old.unstable())
	if brain != null:
		brain.art = _art
	if _box != null:
		(_box.shape as BoxShape3D).size = _art.box_size()
		_fit_box()
	_tag.position.y = _art.tag_y()
	max_health = maxf(_base_health, _elite_health_now()) if _art.elite else _base_health
	_health = minf(_health, max_health)


## An elite's health from the daemon tuning (A5), read once.
static func _elite_health_now() -> float:
	if _elite_health < 0.0:
		var tuning := load(DAEMON_AI_PATH) as DaemonAiTuning
		_elite_health = tuning.elite_health if tuning != null and tuning.problems().is_empty() else 30.0
	return _elite_health
