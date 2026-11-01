class_name Blackout
extends Node
## The arena's lights and its hum, and Black ICE taking them (I3). One of these lives beside the arena
## (main.gd makes it). It plays the arena's hum (Sfx.arena_hum(): a low server-room drone, quietly, on the
## Music bus, whose slider it answers to) and, every frame, reads how dark Black ICE makes the arena now
## (the ICE director's black_darkness(), 0 to 1: falling over its arrival, full while it is out, lifting
## once it is broken or withdrawn) and puts it into the arena: A4's lighting dims toward Black ICE's
## lights_low (the arena_light shader global the arena's strips, panels, screens, holograms, floor,
## rain and skyline multiply by; the sun, the room's light, the signs' lamps and the lair's danger lights;
## the environment's ambient light, sky and fog light) and the hum drops out with it. Black ICE's own
## light is not the arena's and stays; so do the daemons', ICE's, the weapons' and the HUD.
##
## A stutter (M4, docs/STORY.md mission 4's end beat: "the sector's lights stutter, once"): stutter() drops the lights
## to Black ICE's low for a blink, lets them back, and drops them once more, shorter, the hum down with them; then
## everything as it was. Black ICE itself is not here: it is coming, not yet.
##
## Nothing here is made per frame, and nothing is touched while the level is unchanged: at level 1 every
## light is exactly as A4 set it. Visual and audio only; fiction only.

const Sfx = preload("res://scripts/sfx_synth.gd")
const SettingsApply = preload("res://scripts/settings/settings_apply.gd")
const NODE_NAME := "Blackout"
const SHADER_LEVEL := &"arena_light"
## The hum's level on the Music bus (its slider scales it), dB.
const HUM_DB := -20.0
## A light's own energy before any dimming, kept on it.
const BASE := &"blackout_base"

## The ICE director whose Black ICE dims the arena; set by main.gd.
var ice: Node = null
## The arena's light level now (1 normal) and how far the hum is down (0 full, 1 silent).
var level := 1.0
var hum_down := 0.0

## A stutter's beats (M4): dark, lit, dark, seconds each, and how far into them it is (-1 none).
const STUTTER := [0.13, 0.09, 0.07]
var _stutter_t := -1.0
var _stutters := 0

var _hum: AudioStreamPlayer
var _env: Environment
var _env_base := {}
var _lights: Array[Light3D] = []
var _applied := -1.0


func _init() -> void:
	name = NODE_NAME


func _ready() -> void:
	_hum = AudioStreamPlayer.new()
	_hum.name = "Hum"
	_hum.stream = Sfx.arena_hum()  # about 30 ms, once an arena
	_hum.bus = SettingsApply.MUSIC
	_hum.volume_db = HUM_DB
	add_child(_hum)
	_hum.play()
	var main := get_parent()
	var world_env := main.find_child("WorldEnvironment", true, false) as WorldEnvironment if main != null else null
	if world_env != null:
		_env = world_env.environment
	if _env != null:
		_env_base = {"ambient": _env.ambient_light_energy, "sky": _env.background_energy_multiplier, "fog": _env.fog_light_energy}
	_apply(1.0)


func _exit_tree() -> void:
	_apply(1.0)  # the next arena starts lit


## The lights the dimming reaches: the sun, the room's light, the signs' lamps (the lair's danger lights
## take ArenaArt.light_level themselves); found once, their own energies kept.
func _find_lights() -> void:
	_lights.clear()
	var main := get_parent()
	if main == null:
		return
	for path in ["Sun", "Arena/RoomLight"]:
		var light := main.get_node_or_null(path) as Light3D
		if light != null:
			_lights.append(light)
	var art := main.get_node_or_null("Arena/ArenaArt")
	if art != null and art.has_method("lamp_lights"):
		for lamp in art.lamp_lights():
			_lights.append(lamp)
	for light in _lights:
		if not light.has_meta(BASE):
			light.set_meta(BASE, light.light_energy)


func _process(delta: float) -> void:
	var dark: float = ice.black_darkness() if ice != null and is_instance_valid(ice) else 0.0
	var low: float = ice.black_tuning.lights_low if ice != null and is_instance_valid(ice) and ice.black_tuning != null else 0.1
	if _stutter_t >= 0.0:
		_stutter_t += delta
		var t := _stutter_t
		var out := false
		var done := true
		for i in STUTTER.size():
			if t < STUTTER[i]:
				out = i % 2 == 0
				done = false
				break
			t -= STUTTER[i]
		if done:
			_stutter_t = -1.0
		elif out:
			dark = 1.0
	_apply(lerpf(1.0, low, clampf(dark, 0.0, 1.0)))
	hum_down = clampf(dark, 0.0, 1.0)
	_hum.volume_db = HUM_DB + Sfx.volume_db(1.0 - hum_down) if hum_down < 0.999 else Sfx.SILENT_DB


## The arena's lights at `next` of themselves (1 as A4 set them).
func _apply(next: float) -> void:
	if next == _applied:
		return
	if _lights.is_empty():
		_find_lights()
	level = next
	_applied = next
	RenderingServer.global_shader_parameter_set(SHADER_LEVEL, next)
	ArenaArt.light_level = next
	for light in _lights:
		if is_instance_valid(light):
			light.light_energy = float(light.get_meta(BASE, light.light_energy)) * next
	if _env != null and not _env_base.is_empty():
		_env.ambient_light_energy = _env_base["ambient"] * next
		_env.background_energy_multiplier = _env_base["sky"] * next
		_env.fog_light_energy = _env_base["fog"] * next


## True while the hum plays (it stops for nothing: Black ICE only turns it down).
func humming() -> bool:
	return _hum != null and _hum.playing


## The lights stutter, once (M4): see the header. Nothing while one runs.
func stutter() -> void:
	if _stutter_t >= 0.0:
		return
	_stutter_t = 0.0
	_stutters += 1


## True while a stutter runs.
func stuttering() -> bool:
	return _stutter_t >= 0.0


## How many stutters it has run (the tests').
func stutters() -> int:
	return _stutters


## The arena's blackout beside `node`'s scene, or null.
static func of(node: Node) -> Blackout:
	var tree := node.get_tree() if node != null and node.is_inside_tree() else null
	if tree == null or tree.current_scene == null:
		return null
	return tree.current_scene.get_node_or_null(NODE_NAME) as Blackout
