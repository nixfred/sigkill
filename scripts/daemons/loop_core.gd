extends DaemonArt
## A loop's core (M3, mission 3 `while true`): a runaway loop running on one core of the machine, given a body. Not a
## walker and not a swarm: a wheel standing on its edge in the air over the cache, turning, the loop going round. Its rim
## is a ring of armoured plates round a track of hot-magenta light, and on the track its iterations race round and round,
## small armoured drones each with its light and its trail, never stopping; four spokes of light hold its hub, the core
## drone (two armoured hex halves about a band of light, its heart in the gap: its weak point), and under it the loop's
## glyphs fall. Faceless: lights and armour, the runaway's own colour, nothing that moves like an animal.
##
## It turns about its axis (the loop) and slowly about the upright (so it shows its face all round); each time the loop
## forks (fork_flash()) one racer flings off the track as the new child and the wheel jolts on, and the hotter it runs
## (heat: its mission's other cores gone, so this one runs the loop alone) the faster and brighter it goes. Its lamp, a
## magenta light at its hub, spills over the walls round it, so where it stands shows over them.
##
## No two alike (A5's rule): its seed sets how many racers it runs and their spacing, its plates' lean, its spokes' turn,
## its tilt and a scorched plate or two. Never an elite. Visual only: its dummy keeps its hit volume (a box round the whole
## wheel), its health and its states; it never leaves its place, and its brain (scripts/fight/daemon_brain.gd) never moves
## it: its children (runaways it forks) do the fighting.

const PLATES := 14
const RACERS_LOW := 6
const RACERS_HIGH := 8
const SPOKES := 4
## The wheel: its hub's height over the art's origin, its rim's radius, a plate's size (along the rim, out, thick).
const HUB_Y := 1.05
const RIM_M := 1.3
const PLATE := Vector3(0.6, 0.2, 0.34)
## How fast it turns: the loop about its axis and the slow turn about the upright, radians a second; how much heat adds.
const SPIN := 1.1
const YAW := 0.21
const HEAT_SPIN := 2.4
## Its racers: how fast they go round the track (radians a second, on top of the wheel's), their size.
const RACE := 2.6
const RACER_W := 0.22
## Its hub, the core drone: its width and each half's thickness, metres.
const HUB_W := 0.62
const HUB_H := 0.17
## A fork's flash, seconds.
const FORK_S := 0.6
## Its hit volume (art space): a box round the whole wheel, however it turns.
const BOX_SIZE := Vector3(2.9, 2.9, 2.9)
## Its lamp: reach and energy (the beat's on top).
const LAMP_REACH := 7.5
const LAMP_ENERGY := 4.0

## How hot it runs, 0 to 1 (its mission sets it: its other cores gone).
var heat := 0.0

var _plates := PackedInt32Array()
var _track: int
var _rim: int
var _racers := PackedInt32Array()
var _glints := PackedInt32Array()
var _trails := PackedInt32Array()
var _spokes := PackedInt32Array()
var _top: int
var _bottom: int
var _hub_band: int
var _heart: int
var _count := 7
var _gap := PackedFloat32Array()
var _lean := 0.0
var _tilt := 0.0
var _spoke_turn := 0.0
var _turned := 0.0
var _yawed := 0.0
var _raced := 0.0
var _fork_at := -1.0
var _flung := -1
var _lamp: OmniLight3D = null


func _build() -> void:
	ai_kind = "core"
	core_color = Palette.HOT_MAGENTA
	edge_color = Palette.HOT_MAGENTA
	gutter = 0.6
	glyph_count = 10
	glyph_radius = 0.7
	glyph_low = -0.85
	glyph_high = 1.0
	glyph_size = 0.15
	glyph_turns = 0.09
	reach = AABB(Vector3(-1.8, -1.0, -1.8), Vector3(3.6, 4.1, 3.6))
	tag_height = HUB_Y + RIM_M + 0.55
	budget_triangles = 3600
	budget_draw_calls = 11
	size_low = 0.98
	size_high = 1.04
	elite_size = 1.0
	_count = pick(60, 0, RACERS_LOW, RACERS_HIGH)
	_lean = lerpf(-0.25, 0.25, dice(61, 0))
	_tilt = lerpf(-0.12, 0.12, dice(62, 0))
	_spoke_turn = TAU * dice(63, 0)
	_yawed = TAU * dice(64, 0)
	_lamp = OmniLight3D.new()
	_lamp.name = "CoreLamp"
	_lamp.light_color = Palette.HOT_MAGENTA
	_lamp.omni_range = LAMP_REACH
	_lamp.omni_attenuation = 1.2
	_lamp.shadow_enabled = false
	_lamp.position = Vector3(0.0, HUB_Y, 0.0)
	add_child(_lamp)
	for i in PLATES:
		_plates.append(part(Shape.PLATE, Look.ARMOR))
	_track = seam(part(Shape.RING, Look.CORE))
	_rim = seam(part(Shape.RING, Look.CORE))
	for i in _count:
		_racers.append(part(Shape.HEX, Look.ARMOR))
		_glints.append(part(Shape.GEM, Look.CORE))
		_trails.append(part(Shape.STREAK, Look.TRAIL))
		_gap.append((float(i) + 0.35 * dice(65, i)) / float(_count))
	for i in SPOKES:
		_spokes.append(seam(part(Shape.STREAK, Look.CORE)))
	_top = part(Shape.HEX, Look.ARMOR)
	_bottom = part(Shape.HEX, Look.ARMOR)
	_hub_band = weak(part(Shape.RING, Look.CORE))
	_heart = weak(part(Shape.GEM, Look.CORE))
	# Battle damage: a plate or two scorched, a racer's light flickering.
	for i in pick(66, 0, 1, 2):
		scorch(_plates[pick(67, i, 0, PLATES - 1)], lerpf(0.5, 1.0, dice(68, i)))
	flicker(_glints[pick(69, 0, 0, _count - 1)], lerpf(0.3, 0.6, dice(70, 0)))


func _pose(t: float, delta: float) -> void:
	var hot := clampf(heat, 0.0, 1.0)
	var fork := clampf(1.0 - since(_fork_at) / FORK_S, 0.0, 1.0) if _fork_at >= 0.0 else 0.0
	var pulse := pow(maxf(sin(TAU * (0.9 + 1.2 * hot) * t), 0.0), 4.0)
	var shake := recoil()
	_turned = fmod(_turned + (SPIN + HEAT_SPIN * hot + 3.0 * fork) * delta, TAU)
	_yawed = fmod(_yawed + YAW * delta, TAU)
	_raced = fmod(_raced + (RACE + 2.0 * hot) * delta, TAU)
	var hub := Vector3(0.0, HUB_Y + 0.06 * sin(1.3 * t), 0.0) + shake * 0.5
	# The wheel's frame: its axis level, turned about the upright, tilted a little; the loop turning about its axis.
	var face := Basis(Vector3.UP, _yawed) * Basis(Vector3.RIGHT, _tilt)
	var axis := face.z
	var loop := Basis(axis, _turned)
	var up := (loop * face.y).normalized()
	var across := (loop * face.x).normalized()
	# The rim: plates round the track, each laid along it, leaning a little out of the wheel's plane.
	for i in PLATES:
		var a := TAU * float(i) / PLATES
		var out := (up * cos(a) + across * sin(a)).normalized()
		var along := out.cross(axis).normalized()
		var lean := Basis(along, _lean)
		lay(_plates[i], hub + out * (RIM_M + 0.04), lean * Basis(along * PLATE.x, out * PLATE.y, axis * PLATE.z))
	orient(_track, hub, axis, 0.07, RIM_M * 1.86)
	brighten(_track, 2.2 + 0.8 * pulse + 1.4 * hot + 1.5 * fork)
	orient(_rim, hub, axis, 0.04, RIM_M * 2.22)
	brighten(_rim, 1.0 + 0.5 * pulse + 0.6 * hot)
	# The racers: round and round the track, faster than the wheel, each with its trail; one flung off by a fork.
	for i in _count:
		var a := TAU * _gap[i] + _raced + _turned
		var out := up * cos(a) + across * sin(a)
		var ahead := out.cross(axis).normalized()
		var at := hub + out * RIM_M * 0.93
		if i == _flung and fork > 0.0:
			at += out * (1.0 - fork) * 2.2  # flung off the track as the new child
		var s := RACER_W * (1.0 + 0.25 * hot)
		lay(_racers[i], at, Basis(ahead * s, out * s * 0.4, axis * s))
		orient(_glints[i], at, axis, s * 0.5, s * 0.35)
		brighten(_glints[i], 2.4 + 0.8 * hot)
		bone(_trails[i], at - ahead * (0.42 + 0.3 * hot), at, 0.06)
	# The spokes: light from the hub to the rim, turning with the loop.
	for i in SPOKES:
		var a := _spoke_turn + TAU * float(i) / SPOKES
		var out := up * cos(a) + across * sin(a)
		bone(_spokes[i], hub + out * HUB_W * 0.55, hub + out * RIM_M * 0.86, 0.035)
		brighten(_spokes[i], 1.5 + 0.6 * pulse + hot)
	# The hub: two armoured halves turning about its band, its heart in the gap.
	var spin := Basis(axis, -_turned * 1.7)
	var w := HUB_W
	var gap := 0.06 * (1.0 + 0.6 * hot + fork)
	lay(_top, hub + axis * (gap + HUB_H * 0.5), spin * Basis(across * w, axis * HUB_H, up * w))
	lay(_bottom, hub - axis * (gap + HUB_H * 0.5), spin * Basis(-across * w, -axis * HUB_H, up * w))
	orient(_hub_band, hub, axis, gap * 1.6, w * 0.95)
	brighten(_hub_band, 2.2 + 0.6 * pulse + 1.6 * hot + 2.0 * fork)
	orient(_heart, hub, axis, 0.36 * (1.0 + 0.2 * pulse), 0.28)
	brighten(_heart, 2.6 + 0.8 * pulse + 1.8 * hot + 2.0 * fork)
	if _lamp != null:
		_lamp.position = hub
		_lamp.light_energy = (LAMP_ENERGY + 1.6 * pulse + 2.0 * hot + 4.0 * fork) * ArenaArt.light_level


## The loop forks (its mission's pass): a racer flung off the track as the new child, the wheel jolting on, its light
## flaring.
func fork_flash() -> void:
	_fork_at = clock()
	_flung = (_flung + 1 + _count / 2) % _count


## Where its hub is (world space): where a forked child comes off.
func hub() -> Vector3:
	var local := Vector3(0.0, HUB_Y, 0.0)
	return global_transform * local if is_inside_tree() else transform * local


func body_box() -> Transform3D:
	return Transform3D(Basis.IDENTITY, Vector3(0.0, HUB_Y, 0.0))


func body_box_size() -> Vector3:
	return BOX_SIZE


func _on_hit() -> void:
	_turned += 0.4  # a hit throws the wheel round


func _muzzle() -> Vector3:
	return Vector3(0.0, HUB_Y, 0.0)
