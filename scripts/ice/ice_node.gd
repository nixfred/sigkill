class_name IceNode
extends IcePiece
## A white ICE node (I1): a sentinel that throws a field over intruders near it. Two kinds: the jam
## node jams the weapon in an intruder's hand for a short time (they can still swap to another), the
## HUD node corrupts parts of their HUD for a few seconds (never the health line). Its art is
## scripts/ice/node_art.gd.
##
## Every field is telegraphed: an intruder within its trigger range and in sight of its heart (alive
## and not spawn-protected) starts its tell, at least IceTuning.TELL_FIRST_S long: its shields spread
## and spin up, its heart burns brighter, a rising crystalline swell plays from it, and a dome of
## lattice light flickers in at exactly the field's reach (shaders/ice_field.gdshader). At the tell's
## end the field fires: the dome flashes, a glassy crack sounds, and every intruder then inside the
## dome and in sight of the heart takes the effect, through the director (strike()). Then it waits
## its cooldown (shortened by the difficulty's aggression, as a daemon's waits are) and looks again.
## Stepping out of the dome or behind cover during the tell escapes it; so does breaking the node.
## ICEbreakers (I2): a cloaked intruder neither starts its tell nor is reached by its field; a decoy
## calling within its trigger range starts its tell as an intruder would, and at the tell's end takes
## the whole field, reaching no one (the decoy flashes).
##
## Alone and hosting it decides (step()); on a joiner it plays the host's word (take_word()): its
## state and how far into it, so its tell, its dome and its sound show on every screen.

const NodeArt = preload("res://scripts/ice/node_art.gd")
const Sfx = preload("res://scripts/sfx_synth.gd")
const SettingsApply = preload("res://scripts/settings/settings_apply.gd")

enum State { IDLE, TELL, FIELD, COOLDOWN }
const STATE_NAMES := ["idle", "tell", "field", "cooldown"]
## The two kinds.
const JAM := "jam"
const HUD := "hud"
## The tell's swell's pitch, each kind its own, and its loudness.
const SWELL_HZ := {"jam": [260.0, 780.0], "hud": [330.0, 1100.0]}
const SWELL_GAIN := 0.32
const BURST_HZ := {"jam": 900.0, "hud": 1300.0}
const BURST_GAIN := 0.4
## The heart over the floor, for its sight and the dome's middle.
const HEART_M := 1.45
## The most events kept for the checks.
const EVENTS_LAST := 64

## "jam" or "hud"; set before it enters the tree.
var kind := JAM
var spawn_seed := 0
## The tuning, set by the director before it enters the tree.
var tuning: IceTuning

var state: State = State.IDLE
var state_t := 0.0
## The fields it has fired, and the intruders they reached, since it was made.
var fires := 0
var struck := 0
## Fields a decoy took instead (I2).
var lured := 0
## [its clock, a word, ...]: "tell", "field", "abort", "lured" (a decoy took it, I2) for the checks.
var events: Array = []

var _clock := 0.0
var _look := 0.0
var _dome: MeshInstance3D
var _swell: AudioStreamPlayer3D
var _burst: AudioStreamPlayer3D


func _ready() -> void:
	collision_layer = TARGET_LAYER
	collision_mask = 0
	_health = max_health
	tag_text = "white ICE: " + kind
	_make_art(NodeArt, spawn_seed, _prepare)
	var body := CylinderShape3D.new()
	body.radius = 0.55
	body.height = 2.1
	_shape(body, Vector3(0.0, 1.05, 0.0))
	_dome = MeshInstance3D.new()
	_dome.name = "Field"
	var sphere := SphereMesh.new()
	sphere.radius = 1.0
	sphere.height = 2.0
	sphere.radial_segments = 48
	sphere.rings = 24
	_dome.mesh = sphere
	_dome.material_override = director.field_material() if director != null else Palette.ice_field_material()
	_dome.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_dome.position = Vector3(0.0, HEART_M, 0.0)
	_dome.scale = Vector3.ONE * field_m()
	_dome.visible = false
	_dome.set_instance_shader_parameter(&"color", Palette.GLACIER)
	_dome.set_instance_shader_parameter(&"scramble", 1.0 if kind == HUD else 0.0)
	add_child(_dome)
	_swell = _player(Sfx.ice_charge(tell_s(), SWELL_HZ[kind][0], SWELL_HZ[kind][1], SWELL_GAIN))
	_burst = _player(Sfx.ice_burst(BURST_HZ[kind], BURST_GAIN))


func _prepare(a) -> void:  # untyped: the node's own art script
	a.kind = kind


func _player(stream: AudioStream) -> AudioStreamPlayer3D:
	var p := AudioStreamPlayer3D.new()
	p.stream = stream
	p.bus = SettingsApply.EFFECTS
	p.position = Vector3(0.0, HEART_M, 0.0)
	p.unit_size = 8.0
	add_child(p)
	return p


func state_name() -> String:
	return STATE_NAMES[state]


## Its numbers by kind.
func trigger_m() -> float:
	return tuning.jam_trigger_m if kind == JAM else tuning.hud_trigger_m


func tell_s() -> float:
	return tuning.jam_tell_s if kind == JAM else tuning.hud_tell_s


func field_m() -> float:
	return tuning.jam_field_m if kind == JAM else tuning.hud_field_m


func effect_s() -> float:
	return tuning.jam_s if kind == JAM else tuning.hud_s


func cooldown_s() -> float:
	return tuning.jam_cooldown_s if kind == JAM else tuning.hud_cooldown_s


## Where its heart is (world space): its sight and its dome's middle.
func heart() -> Vector3:
	return global_position + Vector3.UP * HEART_M


# --- The host's (and alone, this machine's) decisions. ---

## One physics step of `delta` seconds, deciding: `d` the daemons' director (who the intruders are,
## where, whether attackable, sight against the level), `ice` its own director.
func step(delta: float, d, ice) -> void:
	if broken:
		return
	_clock += delta
	state_t += delta
	match state:
		State.IDLE:
			_look -= delta
			if _look <= 0.0:
				_look = tuning.node_look_s
				if _spots(d) or ice.decoy_near(heart(), trigger_m()) != 0:
					_enter(State.TELL)
					_note("tell")
		State.TELL:
			if state_t >= tell_s():
				# A decoy calling within its trigger range takes the whole field (I2): it reaches no one.
				var lure: int = ice.decoy_near(heart(), trigger_m())
				if lure != 0:
					ice.strike_decoy(lure, heart())
					lured += 1
					_note("lured")
				else:
					struck += ice.strike(self, _reached(d))
				fires += 1
				_note("field")
				_enter(State.FIELD)
		State.FIELD:
			if state_t >= tuning.field_show_s:
				_enter(State.COOLDOWN)
		State.COOLDOWN:
			if state_t >= cooldown_s() / maxf(d.aggression(), 0.01):
				_enter(State.IDLE)
	_show()


## True when an intruder is within its trigger range, in sight of its heart, alive, attackable and not
## cloaked (I2).
func _spots(d) -> bool:
	for id in d.prey_ids():
		if not d.prey_attackable(id) or d.prey_hidden(id):
			continue
		var at: Vector3 = d.prey_point(id)
		if at.distance_to(heart()) <= trigger_m() and d.clear(heart(), at):
			return true
	return false


## The intruders inside the dome now and in sight of the heart, alive, attackable and not cloaked (I2):
## their ids.
func _reached(d) -> Array:
	var out := []
	for id in d.prey_ids():
		if not d.prey_attackable(id) or d.prey_hidden(id):
			continue
		var at: Vector3 = d.prey_point(id)
		if at.distance_to(heart()) <= field_m() and d.clear(heart(), at):
			out.append(id)
	return out


# --- A joiner's copy: the host's word, played. ---

## The host's word: its state and how far into it.
func take_word(word: int, seconds: float) -> void:
	if broken:
		return
	var next: State = clampi(word, 0, State.COOLDOWN) as State
	if next != state:
		state = next
		if next == State.TELL:
			_note("tell")
		elif next == State.FIELD:
			fires += 1
			_note("field")
	state_t = seconds
	_show()


## Steps a joiner's copy's clock between the host's words.
func follow(delta: float) -> void:
	if broken:
		return
	_clock += delta
	state_t += delta
	_show()


# --- What it shows. ---

func _enter(next: State) -> void:
	state = next
	state_t = 0.0


## Its art's act, its dome and its sounds, from its state.
func _show() -> void:
	match state:
		State.TELL:
			var u := clampf(state_t / tell_s(), 0.0, 1.0)
			art.drive(DaemonArt.Act.TELL, u)
			_dome.visible = true
			_dome.set_instance_shader_parameter(&"warn", u)
			_dome.set_instance_shader_parameter(&"burst", 0.0)
			if not _swell.playing and u < 0.5:
				_swell.play(u * tell_s())
		State.FIELD:
			var u := clampf(state_t / tuning.field_show_s, 0.0, 1.0)
			art.drive(DaemonArt.Act.STRIKE, u)
			_dome.visible = true
			_dome.set_instance_shader_parameter(&"warn", 0.0)
			_dome.set_instance_shader_parameter(&"burst", 1.0 - u)
			if _swell.playing:
				_swell.stop()
			if not _burst.playing and u < 0.3:
				_burst.play()
		_:
			art.drive(DaemonArt.Act.IDLE)
			_dome.visible = false
			if _swell.playing:
				_swell.stop()


## How bright its field's dome is now: its warning through the tell, its flash as it fires.
func dome_shown() -> float:
	if _dome == null or not _dome.visible:
		return 0.0
	return float(_dome.get_instance_shader_parameter(&"warn")) + float(_dome.get_instance_shader_parameter(&"burst"))


func _break(point: Vector3, direction: Vector3) -> void:
	super(point, direction)
	_dome.visible = false
	_swell.stop()
	state = State.IDLE


func _note(word: String) -> void:
	events.append([_clock, word])
	if events.size() > EVENTS_LAST:
		events.pop_front()


func _derezz_radius() -> float:
	return 0.55


func _derezz_height() -> float:
	return 2.1
