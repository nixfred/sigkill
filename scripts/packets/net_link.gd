class_name NetLink
extends RefCounted
## One link of the packet tracer's network (W5): a curve of light from a port on one machine's island to a port on
## another's, its packets streaming down it in its protocol's colour (shaders/net_link.gdshader). A player rides it on a
## packet (scripts/packets/packet_tracer.gd). Its life, a state machine on the mode's clock:
##   DOWN     no route yet: its first machine still has daemons standing (dim, dashed red); never boarded
##   SYN      reconnecting, SYN_S: a SYN in from each end, the ACK where they meet; never boarded
##   UP       streaming; a packet boards it
##   FLAKY    going bad, FLAKY_S: it stutters and burns amber, and where it will tear a red ring pulses (the warning)
##   DROPPED  DROPPED_S: torn at its tear point, the gap growing toward both ends at TEAR_SPEED; a rider the gap reaches
##            falls into the void; then SYN again
## A lossy link drops on a schedule of its own (its loss a minute, seeded, the same on every run); a link of loss 0 never
## does. Simulated, all of it: the game never sends, receives, resolves or opens anything.

enum State { DOWN, SYN, UP, FLAKY, DROPPED }

const FLAKY_S := 0.9
const DROPPED_S := 2.6
const SYN_S := 0.7
const TEAR_SPEED := 40.0
const RADIUS := 0.22
const SIDES := 6
const STEPS := 40
## How high over its ports a link arches, at least and a share of its length.
const ARCH_M := 3.0
const ARCH_SHARE := 0.06

var index := 0
var from_id := ""
var to_id := ""
var proto := "tcp"
var loss := 0.0
var mitm := false
var forward := true
## Its curve (a cubic Bézier, world space) and its length in metres.
var p0 := Vector3.ZERO
var p1 := Vector3.ZERO
var p2 := Vector3.ZERO
var p3 := Vector3.ZERO
var length_m := 1.0
var state: State = State.DOWN
var state_t := 0.0
## Where along it (0 to 1) it tears next, and the gap's half width now (metres).
var tear_u := 0.5
var tear_open := 0.0
## A man-in-the-middle's place along it (0 to 1), or -1; a stale route running its stream the wrong way.
var tap_u := -1.0
var stale := false
var drops := 0
var mesh: MeshInstance3D = null
var _next_drop := INF
var _samples := PackedVector3Array()
var _lengths := PackedFloat32Array()
var _sent := {}


func _init(i: int, from: Vector3, to: Vector3, row: Array) -> void:
	index = i
	from_id = str(row[0])
	to_id = str(row[1])
	proto = str(row[2])
	loss = float(row[3])
	mitm = bool(row[4])
	forward = bool(row[5])
	p0 = from
	p3 = to
	var flat := to - from
	var d := flat.length()
	var arch := Vector3.UP * (ARCH_M + ARCH_SHARE * d)
	p1 = from + flat * 0.33 + arch
	p2 = from + flat * 0.67 + arch
	_samples.resize(STEPS + 1)
	_lengths.resize(STEPS + 1)
	var total := 0.0
	for s in STEPS + 1:
		_samples[s] = at_raw(float(s) / STEPS)
		if s > 0:
			total += _samples[s].distance_to(_samples[s - 1])
		_lengths[s] = total
	length_m = maxf(total, 0.01)


## The point on the curve at parameter `t` (0 to 1), not by length.
func at_raw(t: float) -> Vector3:
	var u := 1.0 - t
	return p0 * u * u * u + p1 * 3.0 * u * u * t + p2 * 3.0 * u * t * t + p3 * t * t * t


## The point `u` of the way along it by length (0 at its first port, 1 at its last).
func at(u: float) -> Vector3:
	var want := clampf(u, 0.0, 1.0) * length_m
	var lo := 0
	var hi := STEPS
	while hi - lo > 1:
		var mid := (lo + hi) >> 1
		if _lengths[mid] < want:
			lo = mid
		else:
			hi = mid
	var span := maxf(_lengths[hi] - _lengths[lo], 0.0001)
	return _samples[lo].lerp(_samples[hi], clampf((want - _lengths[lo]) / span, 0.0, 1.0))


## Which way it runs at `u` (a unit vector toward its last port).
func way(u: float) -> Vector3:
	var a := at(clampf(u - 0.01, 0.0, 1.0))
	var b := at(clampf(u + 0.01, 0.0, 1.0))
	var w := b - a
	return w.normalized() if w.length_squared() > 0.0000001 else (p3 - p0).normalized()


func other(id: String) -> String:
	return to_id if id == from_id else from_id


## The tube it is drawn as: STEPS rings of SIDES round its curve, UV.x metres along it.
func build_mesh(material: Material) -> MeshInstance3D:
	mesh = MeshInstance3D.new()
	mesh.name = "Link_%s_%s" % [from_id, to_id]
	mesh.mesh = tube(_samples, _lengths, RADIUS, SIDES)
	mesh.material_override = material
	mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mesh.gi_mode = GeometryInstance3D.GI_MODE_DISABLED
	mesh.set_instance_shader_parameter("tint", NetBook.color_of(proto))
	mesh.set_instance_shader_parameter("length_m", length_m)
	mesh.set_instance_shader_parameter("flow", float(NetBook.PROTOCOLS[proto]["speed"]))
	mesh.set_instance_shader_parameter("gap", float(NetBook.PROTOCOLS[proto]["gap"]))
	mesh.set_instance_shader_parameter("seed", float(index) * 1.37)
	_paint()
	return mesh


## A tube of `radius` round the points `pts` (`lens` their distance along), `sides` round.
static func tube(pts: PackedVector3Array, lens: PackedFloat32Array, radius: float, sides: int) -> ArrayMesh:
	var verts := PackedVector3Array()
	var normals := PackedVector3Array()
	var uvs := PackedVector2Array()
	var idx := PackedInt32Array()
	var n := pts.size()
	var up := Vector3.UP
	for i in n:
		var along := (pts[mini(i + 1, n - 1)] - pts[maxi(i - 1, 0)]).normalized()
		if absf(along.dot(up)) > 0.95:
			up = Vector3.RIGHT
		var side := along.cross(up).normalized()
		var lift := side.cross(along).normalized()
		for s in sides + 1:
			var a := TAU * float(s) / sides
			var out := side * cos(a) + lift * sin(a)
			verts.append(pts[i] + out * radius)
			normals.append(out)
			uvs.append(Vector2(lens[i], float(s) / sides))
	for i in n - 1:
		for s in sides:
			var a := i * (sides + 1) + s
			var b := a + sides + 1
			idx.append_array([a, b, a + 1, a + 1, b, b + 1])
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_INDEX] = idx
	var out_mesh := ArrayMesh.new()
	out_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return out_mesh


# --- Its life. ---

## Its route comes up (its first machine clear, or the run's start): reconnecting, then up.
func open_route(clock: float) -> void:
	if state == State.DOWN:
		_enter(State.SYN)
		_schedule(clock)


func boardable() -> bool:
	return state == State.UP or state == State.FLAKY


## Starts it going bad now (its schedule's own drop, or a test's): the warning, then the tear at `u` (0 to 1).
func go_flaky(u: float) -> void:
	if state != State.UP:
		return
	tear_u = clampf(u, 0.08, 0.92)
	_enter(State.FLAKY)


## True when the point `u` of the way along it has fallen into the gap.
func gone_at(u: float) -> bool:
	return state == State.DROPPED and absf(u - tear_u) * length_m < tear_open


## True while it warns or is torn: its rider's danger.
func unstable() -> bool:
	return state == State.FLAKY or state == State.DROPPED


func step(delta: float, clock: float) -> void:
	state_t += delta
	match state:
		State.SYN:
			if state_t >= SYN_S:
				_enter(State.UP)
		State.UP:
			if loss > 0.0 and clock >= _next_drop:
				go_flaky(0.3 + 0.4 * _roll(drops, 2))
		State.FLAKY:
			if state_t >= FLAKY_S:
				tear_open = 0.0
				drops += 1
				_enter(State.DROPPED)
		State.DROPPED:
			tear_open = minf(tear_open + TEAR_SPEED * delta, length_m)
			if state_t >= DROPPED_S:
				tear_open = 0.0
				_enter(State.SYN)
				_schedule(clock)
	_paint()


func _enter(next: State) -> void:
	state = next
	state_t = 0.0


## Its next drop: a period of 60 / loss seconds, give or take 30% by its seed (the same on every run).
func _schedule(clock: float) -> void:
	if loss <= 0.0:
		_next_drop = INF
		return
	var period := 60.0 / loss
	_next_drop = clock + SYN_S + period * (0.7 + 0.6 * _roll(drops, 1))


func next_drop() -> float:
	return _next_drop


func _roll(n: int, salt: int) -> float:
	var h := hash("link:%d:%d:%d" % [index, n, salt])
	return float(h & 0xffff) / 65535.0


## Its look for its state, told to the shader only when a number changes.
func _paint() -> void:
	if mesh == null:
		return
	var flicker := 0.0
	var warn := -1.0
	var tear := -1.0
	var syn := 0.0
	match state:
		State.FLAKY:
			flicker = clampf(state_t / 0.25, 0.0, 1.0)
			warn = tear_u * length_m
		State.DROPPED:
			tear = tear_u * length_m
		State.SYN:
			syn = clampf(state_t / SYN_S, 0.0, 1.0)
	_send("flicker", flicker)
	_send("warn_at", warn)
	_send("tear_at", tear)
	_send("tear_open", tear_open)
	_send("down", 1.0 if state == State.DOWN else 0.0)
	_send("syn", syn)
	_send("tap_at", tap_u * length_m if tap_u >= 0.0 else -1.0)
	_send("stale", 1.0 if stale else 0.0)


func _send(param: String, value: float) -> void:
	if _sent.get(param, INF) == value:
		return
	_sent[param] = value
	mesh.set_instance_shader_parameter(param, value)
