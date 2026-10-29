class_name BlackIce
extends IcePiece
## Black ICE (I3): the machine's last line of defence. Rare and frightening, never a bigger health bar:
## at most one a round, never in round 1 (its director rolls each round's chance and picks its moment,
## scripts/ice/ice_director.gd). Its arrival is an event with a long tell (its tuning's tell_s): the
## warning on every screen, the arena's lights dying down (scripts/ice/blackout.gd), the hum dropping out
## and the guide's link cut, while it forms out of the floor at the spot farthest from every intruder;
## nothing touches before the tell ends. Then it hunts (scripts/ice/black_ice_brain.gd), slower than a
## running intruder, and touching it is a flatline: alone, the run is over; in a match, out for the rest
## of the round.
##
## Normal weapons cannot kill it: a hit only flashes it (nothing is taken, no hit is counted, and the
## hunter's adaptation notes nothing). Only the ICEbreakers deal with it: an exploit, then a brute charge
## reaching it while that intruder's exploit still runs, breaks one of its seals (and throws it back); a
## broken seal mends after seal_mend_s, and breaking the last one kills it, so a kill takes a plan: two
## combos (exploit and two brutes inside the exploit's seconds, or exploit and brute twice inside the
## mend), and getting close enough to brute it. A decoy pulls it off any intruder while it calls; a cloak
## hides an intruder from it as from the hunter; and it is always slower than a running intruder.
##
## When the round ends it withdraws, sinking into the floor. A broken or withdrawn one stays a moment
## (its burst, its sinking, the lights coming back) and is freed by its director. Alone and hosting its
## director decides everything here; on a joiner it plays the host's word (take_word()). Its body is a
## tall hit volume on the targets' layer (shots meet it, nothing walks into it). Fiction only.

const BlackIceArt = preload("res://scripts/ice/black_ice_art.gd")
const Sfx = preload("res://scripts/sfx_synth.gd")
const SettingsApply = preload("res://scripts/settings/settings_apply.gd")

## Where it is in its life: not yet (none), arriving (its tell), out (hunting), broken (its last seal
## gone), withdrawn (the round's end).
enum Phase { NONE, ARRIVE, OUT, DOWN, GONE }
const PHASE_NAMES := ["none", "arrive", "out", "down", "gone"]
## A broken one's burst stays this long before it is freed.
const DOWN_S := 2.5
## Its drone heard this near (its approach is heard as well as seen).
const DRONE_UNIT_M := 6.0
const DRONE_DB := -6.0

var spawn_seed := 0
var tuning: BlackIceTuning
var brain: BlackIceBrain
var phase: Phase = Phase.ARRIVE
var phase_t := 0.0
## Its seals standing now, and the seconds before a broken one mends.
var seals_left := 2
var mend_left := 0.0
## Hits that only flashed it, and seals broken, this life: for the checks and the host's word.
var flashes := 0
var cracks := 0
## The intruders it has flatlined, for the checks.
var flatlines := 0

var _seen_flashes := 0
var _arrive: AudioStreamPlayer
var _drone: AudioStreamPlayer3D
var _sounds := {}


func _ready() -> void:
	collision_layer = TARGET_LAYER
	collision_mask = 0
	seals_left = tuning.seals
	max_health = float(tuning.seals)
	_health = max_health
	tag_text = "Black ICE"
	_make_art(BlackIceArt, spawn_seed, _prepare)
	var hull := CylinderShape3D.new()
	hull.radius = tuning.radius_m
	hull.height = tuning.height_m
	_shape(hull, Vector3(0.0, tuning.height_m * 0.5, 0.0))
	brain = BlackIceBrain.new(self, art, tuning)
	brain.take_home()
	_arrive = AudioStreamPlayer.new()
	_arrive.stream = sound("arrive", tuning.tell_s)
	_arrive.bus = SettingsApply.EFFECTS
	add_child(_arrive)
	_drone = AudioStreamPlayer3D.new()
	_drone.stream = sound("drone")
	_drone.bus = SettingsApply.EFFECTS
	_drone.unit_size = DRONE_UNIT_M
	_drone.volume_db = DRONE_DB
	_drone.position = Vector3(0.0, 1.6, 0.0)
	add_child(_drone)
	for word in ["crack", "break", "mend", "withdraw"]:
		var p := AudioStreamPlayer3D.new()
		p.stream = sound(word)
		p.bus = SettingsApply.EFFECTS
		p.unit_size = 10.0
		p.position = Vector3(0.0, 2.0, 0.0)
		add_child(p)
		_sounds[word] = p
	if phase == Phase.ARRIVE:
		_arrive.play()
	_show()


func _prepare(a) -> void:  # untyped: Black ICE's own art script
	a.touch_m = tuning.touch_m
	a.seals_all = tuning.seals
	a.seals_up = tuning.seals


## Its sound `word` (Sfx.black_ice): its director's, made before it came (a fall is long to make).
func sound(word: String, seconds: float = 6.0) -> AudioStreamWAV:
	if director != null and director.has_method("black_sound"):
		return director.black_sound(word, seconds)
	return Sfx.black_ice(word, seconds)


func phase_name() -> String:
	return PHASE_NAMES[phase]


## True from its arrival's first moment until it is gone: the guide's link shows cut, the warning up.
func present_now() -> bool:
	return phase == Phase.ARRIVE or phase == Phase.OUT


## True while its touch flatlines: out, never in its tell.
func touching() -> bool:
	return phase == Phase.OUT and not broken


## How dark it makes the arena now, 0 (not at all) to 1 (its lights_low): falling over its arrival's
## first dim_s, full while it is out, lifting over restore_s once it is broken or withdrawn.
func darkness() -> float:
	match phase:
		Phase.ARRIVE:
			return smoothstep(0.0, 1.0, phase_t / maxf(tuning.dim_s, 0.001)) if tuning.dim_s > 0.0 else 1.0
		Phase.OUT:
			return 1.0
		Phase.DOWN, Phase.GONE:
			return 1.0 - smoothstep(0.0, 1.0, phase_t / maxf(tuning.restore_s, 0.001)) if tuning.restore_s > 0.0 else 0.0
	return 0.0


## Seconds left of its arrival's tell (0 once out).
func tell_left() -> float:
	return maxf(tuning.tell_s - phase_t, 0.0) if phase == Phase.ARRIVE else 0.0


## True when `point` (world space, an intruder's middle) is within its touch: near its axis and not
## over its crown.
func touches(point: Vector3) -> bool:
	if not point.is_finite():
		return false
	var here := global_position
	var flat := Vector2(point.x - here.x, point.z - here.z).length()
	return flat <= tuning.touch_m and point.y >= here.y - 0.5 and point.y <= here.y + tuning.height_m + 0.3


## True once its burst or its sinking is over: its director frees it.
func finished() -> bool:
	if phase == Phase.DOWN:
		return phase_t >= maxf(DOWN_S, tuning.restore_s)
	if phase == Phase.GONE:
		return phase_t >= maxf(tuning.withdraw_s, tuning.restore_s)
	return false


# --- Its life (deciding: its director steps it). ---

## One step of `delta` seconds: its tell running out, a broken seal mending, its brain hunting.
func step(delta: float, d) -> void:
	phase_t += delta
	match phase:
		Phase.ARRIVE:
			art.drive(DaemonArt.Act.TELL, phase_t / tuning.tell_s)
			if phase_t >= tuning.tell_s:
				_enter(Phase.OUT)
		Phase.OUT:
			if seals_left < tuning.seals:
				mend_left -= delta
				if mend_left <= 0.0:
					seals_left += 1
					mend_left = tuning.seal_mend_s if seals_left < tuning.seals else 0.0
					_play("mend")
			if d != null:
				brain.step(delta, d)
	_show()


## The round is over: it withdraws, sinking into the floor (nothing touches from now on).
func withdraw_now() -> void:
	if phase != Phase.ARRIVE and phase != Phase.OUT:
		return
	if director != null and director.daemons != null:
		brain._release(director.daemons)
	for shape in _shapes:
		shape.set_deferred("disabled", true)
	_enter(Phase.GONE)
	_play("withdraw")


func _enter(next: Phase) -> void:
	phase = next
	phase_t = 0.0
	if next == Phase.OUT:
		if not _drone.playing:
			_drone.play()
	else:
		_drone.stop()
	if next != Phase.ARRIVE:
		_arrive.stop()


## A hit from intruder `shooter` (0 this machine's own): a flash and nothing taken, unless it is a brute
## charge while that intruder's exploit runs, which breaks a seal. True only when a seal broke.
func _land(_damage: float, point: Vector3, direction: Vector3, source: String, shooter: int) -> bool:
	if broken or not present_now() or director == null:
		return false
	if not director.decides():
		if shooter == 0:
			art.flash()  # this screen's own shot shows at once; the host's word counts every other
		return false
	if phase == Phase.OUT and source == IceDirector.BRUTE and director.exploit_runs(shooter):
		_crack(point, direction)
		return true
	flashes += 1
	art.react(point, direction)
	if director.daemons != null and phase == Phase.OUT:
		brain.on_hit(point, director.daemons)
	return false


## A seal broken by the combo: thrown back along the charge, or, the last one, its end.
func _crack(point: Vector3, direction: Vector3) -> void:
	seals_left -= 1
	cracks += 1
	mend_left = tuning.seal_mend_s
	_health = float(seals_left)
	(art as BlackIceArt).seals_up = seals_left
	_play("crack")
	if seals_left <= 0:
		_health = 0.0
		if director.daemons != null:
			brain._release(director.daemons)
		_break(point, direction)
		_enter(Phase.DOWN)
		_play("break")
		return
	art.flash()
	var from := point - direction * 3.0 if point.is_finite() and direction.is_finite() else global_position - global_transform.basis.z
	brain.reel(from, director.daemons)


func _play(word: String) -> void:
	var p: AudioStreamPlayer3D = _sounds.get(word)
	if p != null and is_inside_tree():
		p.play()


## The art's own state from its life: its seals, its sinking.
func _show() -> void:
	var look := art as BlackIceArt
	look.seals_up = seals_left
	look.withdraw = clampf(phase_t / tuning.withdraw_s, 0.0, 1.0) if phase == Phase.GONE else 0.0


## Where a blast or a brute charge from `at` meets it: the nearest point of its body's side, at the
## height of `at` within it.
func blast_point(at: Vector3) -> Vector3:
	var here := global_position
	var flat := Vector3(at.x - here.x, 0.0, at.z - here.z)
	var side := flat.normalized() * minf(tuning.radius_m, flat.length()) if flat.length_squared() > 0.0001 else Vector3.ZERO
	return here + side + Vector3.UP * clampf(at.y - here.y, 0.3, tuning.height_m - 0.3)


func _derezz_radius() -> float:
	return tuning.radius_m


func _derezz_height() -> float:
	return tuning.height_m


# --- A joiner's copy: the host's word. ---

## The host's word: its phase and seconds into it, its seals, its brain's place (arena space), yaw,
## state and seconds into it, whether SIGSTOP holds it, and how many hits have flashed it.
func take_word(next: int, seconds: float, seals_now: int, at: Vector3, yaw: float, state: int, state_seconds: float, frozen: bool, flashed: int) -> void:
	if next == Phase.DOWN and not broken:
		_health = 0.0
		_break(Vector3.INF, Vector3.ZERO)
		_enter(Phase.DOWN)
		_play("break")
	elif next == Phase.GONE and phase != Phase.GONE and phase != Phase.DOWN:
		withdraw_now()
	elif next != phase and (next == Phase.OUT or next == Phase.ARRIVE):
		_enter(next)
	if phase == next:
		phase_t = seconds
	if seals_now < seals_left and seals_now > 0:
		_play("crack")
		art.flash()
	seals_left = clampi(seals_now, 0, tuning.seals)
	_health = float(seals_left)
	if flashed > _seen_flashes:
		art.flash()
	_seen_flashes = flashed
	brain.take_word(at, yaw, state, state_seconds, frozen)


## One step on a joiner: its clock on between the host's words, its brain playing the host's place.
func follow(delta: float, d) -> void:
	phase_t += delta
	if phase == Phase.ARRIVE:
		art.drive(DaemonArt.Act.TELL, phase_t / tuning.tell_s)
	elif phase == Phase.OUT and d != null:
		brain.follow(delta, d)
	_show()
