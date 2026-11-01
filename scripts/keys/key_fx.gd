class_name KeyFx
extends RefCounted
## Keybind gunplay's shortcuts made physical (W4): each one a desktop window doing to a daemon what the shortcut does to a
## window (scripts/keys/key_window.gd, shaders/key_window.gdshader).
##   Terminal (SUPER + RETURN)        a terminal window blasts out of you, opening as it flies, printing as it goes, and
##                                    bursts where it meets something: the window flashing out, a frame blown wide, a
##                                    blast that hits every daemon near it.
##   Close window (SUPER + W)         a window drawn round the daemon under the crosshair, then folded shut: flat to a line
##                                    across its middle, then to nothing; closed, it is gone.
##   Toggle window split (SUPER + J)  a seam down the daemon's middle, then the window splits in two panes sliding apart.
##   Toggle floating/tiling (SUPER + T)  the daemon lifted in a floating window, turning, helpless; then tiled: slammed
##                                    into the floor, a tile of light flashing out under it.
## Full screen and the workspaces are the HUD's (they are the screen's): scripts/keys/keybind_hud.gd. Every hit is the
## game's own (target_dummy.gd hit(), its source `keys_<id>`): nothing real is closed, moved or touched. Visual only but
## for those hits.

const Palette = preload("res://scripts/palette.gd")
const SettingsApply = preload("res://scripts/settings/settings_apply.gd")

## Each shortcut's colour: the player's side of the palette, never a hostile's.
const COLORS := {
	"terminal": Color(0.49, 1.0, 0.81), "close": Color(0.64, 0.93, 1.0), "split": Color(1.0, 0.96, 0.76),
	"float": Color(0.85, 0.75, 1.0), "fullscreen": Color(0.78, 0.84, 1.0), "workspace": Color(0.72, 1.0, 0.18),
	"goto": Color(0.72, 1.0, 0.18), "keys": Color(0.49, 1.0, 0.81),
}
const SOURCE_PREFIX := "keys_"


static func color_of(id: String) -> Color:
	return COLORS.get(id, Palette.MINT)


## The frame a window round daemon `dummy` takes: its size (metres) and its middle.
static func frame_of(dummy: Node3D) -> Array:
	var art = dummy.art_node()
	var box: Vector3 = art.box_size() if art != null and art.box_size() != Vector3.ZERO else Vector3(1.2, 1.8, 1.2)
	var size := Vector2(maxf(box.x, box.z) * 1.05 + 0.55, box.y * 1.02 + 0.55)
	var body := dummy.get_node_or_null("Body") as Node3D
	var mid: Vector3 = body.global_position if body != null else dummy.global_position + Vector3(0.0, size.y * 0.5, 0.0)
	return [size, mid]


static func _eye(node: Node) -> Vector3:
	var cam := node.get_viewport().get_camera_3d() if node.is_inside_tree() else null
	return cam.global_position if cam != null else Vector3(0.0, 1.7, 10.0)


static func ease_out(u: float) -> float:
	u = clampf(u, 0.0, 1.0)
	return 1.0 - pow(1.0 - u, 3.0)


static func ease_back(u: float) -> float:
	u = clampf(u, 0.0, 1.0)
	var c := 1.9
	return 1.0 + (c + 1.0) * pow(u - 1.0, 3.0) + c * pow(u - 1.0, 2.0)


# --- Terminal: the cannon of this mode. ---

class TerminalBlast extends Node3D:
	const SPEED := 46.0
	const RANGE := 70.0
	const OPEN_S := 0.24
	const RADIUS := 3.4
	const NEAR := 1.15
	const BURST_S := 0.36
	const GHOST_EVERY := 0.035
	const GHOSTS_MOST := 7
	var dir := Vector3.FORWARD
	var shooter: Node3D = null
	var window: KeyWindow
	var ring: KeyWindow
	var ghosts: Array = []
	var travelled := 0.0
	var t := 0.0
	var burst_t := -1.0
	var hits := 0
	var kills := 0
	var _ghost_wait := 0.0
	signal landed(blast: Node3D)

	func start(from: Vector3, way: Vector3, who: Node3D) -> void:
		dir = way.normalized()
		shooter = who
		window = KeyWindow.make(Vector2(2.7, 1.75), KeyWindow.Style.TERMINAL, KeyFx.color_of("terminal"), "terminal", 3.0)
		window.set_param("typed", 0.0)
		add_child(window)
		global_position = from + dir * 1.3
		window.scale = Vector3.ONE * 0.12
		window.face(KeyFx._eye(self))

	func _physics_process(delta: float) -> void:
		t += delta
		if burst_t >= 0.0:
			return
		var step := SPEED * delta
		var from := global_position
		var to := from + dir * step
		var space := get_world_3d().direct_space_state
		var q := PhysicsRayQueryParameters3D.create(from, to)
		if shooter != null and is_instance_valid(shooter) and shooter is CollisionObject3D:
			q.exclude = [(shooter as CollisionObject3D).get_rid()]
		var got := space.intersect_ray(q)
		var near := _near_target(from, to)
		if near != null:
			_burst(near.threat_point())
			return
		if not got.is_empty():
			_burst(got["position"])
			return
		global_position = to
		travelled += step
		if travelled >= RANGE:
			_burst(global_position)

	func _near_target(from: Vector3, to: Vector3) -> Node3D:
		var best: Node3D = null
		var best_d := NEAR
		for body in get_tree().get_nodes_in_group("targets"):
			if not (body is Node3D) or not body.has_method("is_alive") or not body.is_alive():
				continue
			var p: Vector3 = body.threat_point()
			var d := Geometry3D.get_closest_point_to_segment(p, from, to).distance_to(p)
			if d < best_d:
				best_d = d
				best = body
		return best

	func _process(delta: float) -> void:
		var eye := KeyFx._eye(self)
		if burst_t < 0.0:
			var u := t / OPEN_S
			window.scale = Vector3.ONE * lerpf(0.12, 1.0, KeyFx.ease_back(u))
			window.set_param("typed", clampf(t / 0.32, 0.0, 1.0))
			window.set_param("clock", t)
			window.face(eye)
			_ghost_wait -= delta
			if _ghost_wait <= 0.0 and t > 0.05:
				_ghost_wait = GHOST_EVERY
				_ghost(eye)
		else:
			burst_t += delta
			var u := burst_t / BURST_S
			window.scale = Vector3.ONE * lerpf(1.0, 1.8, KeyFx.ease_out(u))
			window.set_param("flash", clampf(1.0 - u * 2.5, 0.0, 1.0))
			window.set_param("fade", clampf(1.0 - u, 0.0, 1.0))
			if ring != null:
				ring.resize(Vector2(1.0, 0.65) * lerpf(1.0, 9.0, KeyFx.ease_out(u)))
				ring.set_param("fade", clampf(1.0 - u, 0.0, 1.0))
				ring.face(eye)
			if u >= 1.0:
				queue_free()
		for g in ghosts.duplicate():
			var w: KeyWindow = g[0]
			g[1] = float(g[1]) + delta
			var k := float(g[1]) / 0.22
			w.set_param("fade", clampf(0.55 * (1.0 - k), 0.0, 1.0))
			if k >= 1.0:
				w.queue_free()
				ghosts.erase(g)

	func _ghost(eye: Vector3) -> void:
		if ghosts.size() >= GHOSTS_MOST:
			return
		var g := KeyWindow.make(window.size, KeyWindow.Style.FRAME, KeyFx.color_of("terminal"), "", 1.0)
		g.top_level = true
		add_child(g)
		g.global_position = global_position
		g.scale = window.scale
		g.face(eye)
		g.set_param("body_alpha", 0.0)
		g.set_param("glow", 1.4)
		ghosts.append([g, 0.0])

	func _burst(point: Vector3) -> void:
		global_position = point - dir * 0.3
		burst_t = 0.0
		ring = KeyWindow.make(Vector2(1.0, 0.65), KeyWindow.Style.FRAME, KeyFx.color_of("terminal"), "", 2.0)
		ring.set_param("body_alpha", 0.0)
		ring.set_param("glow", 3.0)
		ring.set_param("border", 0.09)
		add_child(ring)
		var fx := ParticleFx.of(self)
		if fx != null:
			fx.blast(point, KeyFx.color_of("terminal"), RADIUS)
		for body in get_tree().get_nodes_in_group("targets"):
			if not (body is Node3D) or not body.has_method("is_alive") or not body.is_alive():
				continue
			var p: Vector3 = body.threat_point()
			var d := p.distance_to(point)
			if d > RADIUS:
				continue
			if body.hit(lerpf(2.0, 1.0, d / RADIUS), p, dir, KeyFx.SOURCE_PREFIX + "terminal"):
				hits += 1
				if not body.is_alive():
					kills += 1
		landed.emit(self)


# --- Close window: the daemon folded shut. ---

class CloseFold extends Node3D:
	const DRAW_S := 0.16
	const FOLD_Y_S := 0.26
	const FOLD_X_S := 0.14
	const OUT_S := 0.2
	var target: Node3D = null
	var frame: KeyWindow
	var body: Node3D
	var rest := Vector3.ONE
	var t := 0.0
	var closed := false
	var kills := 0
	signal landed(effect: Node3D)

	func start(dummy: Node3D) -> void:
		target = dummy
		body = dummy.get_node_or_null("Body") as Node3D
		rest = body.scale if body != null else Vector3.ONE
		var f := KeyFx.frame_of(dummy)
		frame = KeyWindow.make(f[0], KeyWindow.Style.FRAME, KeyFx.color_of("close"), "%s   [x] close" % str(dummy.get("tag_text")), 5.0)
		frame.set_param("body_alpha", 0.18)
		frame.top_level = true
		add_child(frame)
		frame.global_position = f[1]

	func _physics_process(_delta: float) -> void:
		if not closed and _alive():
			target.hold_in_hole(0.2)

	func _alive() -> bool:
		return target != null and is_instance_valid(target) and target.is_alive()

	func _process(delta: float) -> void:
		t += delta
		var eye := KeyFx._eye(self)
		if _alive() and not closed:
			frame.global_position = KeyFx.frame_of(target)[1]
		frame.face(eye)
		var y := 1.0
		var x := 1.0
		if t < DRAW_S:
			frame.scale = Vector3.ONE * lerpf(1.35, 1.0, KeyFx.ease_out(t / DRAW_S))
			frame.set_param("fade", clampf(t / DRAW_S, 0.0, 1.0))
		elif t < DRAW_S + FOLD_Y_S:
			y = lerpf(1.0, 0.035, KeyFx.ease_out((t - DRAW_S) / FOLD_Y_S))
		elif t < DRAW_S + FOLD_Y_S + FOLD_X_S:
			y = 0.035
			x = lerpf(1.0, 0.02, KeyFx.ease_out((t - DRAW_S - FOLD_Y_S) / FOLD_X_S))
		else:
			y = 0.035
			x = 0.02
			if not closed:
				_close()
			var u := (t - DRAW_S - FOLD_Y_S - FOLD_X_S) / OUT_S
			frame.set_param("fade", clampf(1.0 - u, 0.0, 1.0))
			if u >= 1.0:
				queue_free()
				return
		if not closed:
			if t >= DRAW_S:
				frame.scale = Vector3(x, y, 1.0)
			frame.set_param("glow", 2.4 + (1.0 - y) * 3.0)
			if body != null and is_instance_valid(body) and _alive():
				body.scale = Vector3(rest.x * x, rest.y * y, rest.z * x)

	func _close() -> void:
		closed = true
		frame.set_param("flash", 1.0)
		if _alive():
			var at: Vector3 = target.threat_point()
			if target.hit(999.0, at, Vector3.ZERO, KeyFx.SOURCE_PREFIX + "close") and not target.is_alive():
				kills += 1
			if body != null and is_instance_valid(body):
				body.scale = rest
			var fx := ParticleFx.of(self)
			if fx != null:
				fx.impact(at, Vector3.UP, false, KeyFx.color_of("close"))
		landed.emit(self)


# --- Toggle window split: the daemon split down its middle. ---

class SplitPane extends Node3D:
	const DRAW_S := 0.12
	const SEAM_S := 0.16
	const PART_S := 0.34
	var target: Node3D = null
	var frame: KeyWindow
	var halves: Array = []
	var body: Node3D
	var rest := Vector3.ONE
	var size := Vector2.ONE
	var mid := Vector3.ZERO
	var right := Vector3.RIGHT
	var t := 0.0
	var cut := false
	var kills := 0
	signal landed(effect: Node3D)

	func start(dummy: Node3D) -> void:
		target = dummy
		body = dummy.get_node_or_null("Body") as Node3D
		rest = body.scale if body != null else Vector3.ONE
		var f := KeyFx.frame_of(dummy)
		size = f[0]
		mid = f[1]
		frame = KeyWindow.make(size, KeyWindow.Style.FRAME, KeyFx.color_of("split"), "%s   split" % str(dummy.get("tag_text")), 7.0)
		frame.set_param("body_alpha", 0.15)
		frame.top_level = true
		add_child(frame)
		frame.global_position = mid

	func _alive() -> bool:
		return target != null and is_instance_valid(target) and target.is_alive()

	func _physics_process(_delta: float) -> void:
		if not cut and _alive():
			target.hold_in_hole(0.2)

	func _process(delta: float) -> void:
		t += delta
		var eye := KeyFx._eye(self)
		if not cut:
			if _alive():
				mid = KeyFx.frame_of(target)[1]
			frame.global_position = mid
			frame.face(eye)
			right = frame.global_basis.x.normalized()
			frame.set_param("fade", clampf(t / DRAW_S, 0.0, 1.0))
			frame.set_param("seam", clampf((t - DRAW_S) / SEAM_S, 0.0, 1.0))
			if body != null and is_instance_valid(body) and _alive():
				var squeeze := lerpf(1.0, 0.55, clampf((t - DRAW_S) / SEAM_S, 0.0, 1.0))
				body.scale = Vector3(rest.x * squeeze, rest.y, rest.z * squeeze)
			if t >= DRAW_S + SEAM_S:
				_cut(eye)
			return
		var u := (t - DRAW_S - SEAM_S) / PART_S
		for i in halves.size():
			var h: KeyWindow = halves[i]
			var side := -1.0 if i == 0 else 1.0
			h.global_position = mid + right * side * (size.x * 0.25 + KeyFx.ease_out(u) * 1.1) + Vector3.UP * KeyFx.ease_out(u) * 0.15 * side
			h.face(eye)
			h.rotate_object_local(Vector3.FORWARD, side * KeyFx.ease_out(u) * 0.12)
			h.set_param("fade", clampf(1.0 - u, 0.0, 1.0))
		if u >= 1.0:
			queue_free()

	func _cut(eye: Vector3) -> void:
		cut = true
		frame.visible = false
		for side in [-1.0, 1.0]:
			var h := KeyWindow.make(Vector2(size.x * 0.5, size.y), KeyWindow.Style.FRAME, KeyFx.color_of("split"), "", 7.0 + side)
			h.set_param("body_alpha", 0.2)
			h.set_param("glow", 3.2)
			h.top_level = true
			add_child(h)
			h.global_position = mid + right * side * size.x * 0.25
			h.face(eye)
			halves.append(h)
		if body != null and is_instance_valid(body) and _alive():
			body.scale = rest
		if _alive():
			var at: Vector3 = target.threat_point()
			if target.hit(2.0, at, right, KeyFx.SOURCE_PREFIX + "split") and not target.is_alive():
				kills += 1
			var fx := ParticleFx.of(self)
			if fx != null:
				fx.impact(at, right, false, KeyFx.color_of("split"))
				fx.impact(at, -right, false, KeyFx.color_of("split"))
		landed.emit(self)


# --- Toggle floating/tiling: lifted in a floating window, then tiled into the floor. ---

class FloatTile extends Node3D:
	const LIFT_M := 2.6
	const LIFT_S := 0.55
	const HOLD_S := 1.05
	const SLAM_S := 0.14
	const OUT_S := 0.45
	var target: Node3D = null
	var frame: KeyWindow
	var tile: KeyWindow
	var body: Node3D
	var ground := Vector3.ZERO
	var t := 0.0
	var slammed := false
	var kills := 0
	var spin := 0.0
	signal landed(effect: Node3D)

	func start(dummy: Node3D) -> void:
		target = dummy
		body = dummy.get_node_or_null("Body") as Node3D
		ground = dummy.global_position
		var f := KeyFx.frame_of(dummy)
		frame = KeyWindow.make(f[0], KeyWindow.Style.FRAME, KeyFx.color_of("float"), "%s   floating" % str(dummy.get("tag_text")), 9.0)
		frame.set_param("body_alpha", 0.22)
		frame.top_level = true
		add_child(frame)
		frame.global_position = f[1]

	func _alive() -> bool:
		return target != null and is_instance_valid(target) and target.is_alive()

	func _physics_process(_delta: float) -> void:
		if slammed or not _alive():
			return
		target.hold_in_hole(0.2)
		var up := 0.0
		if t < LIFT_S:
			up = KeyFx.ease_out(t / LIFT_S) * LIFT_M
		elif t < LIFT_S + HOLD_S:
			up = LIFT_M + sin((t - LIFT_S) * 5.0) * 0.12
		else:
			up = lerpf(LIFT_M, 0.0, clampf((t - LIFT_S - HOLD_S) / SLAM_S, 0.0, 1.0))
		target.global_position = ground + Vector3.UP * up

	func _process(delta: float) -> void:
		t += delta
		var eye := KeyFx._eye(self)
		if not slammed:
			if _alive():
				frame.global_position = KeyFx.frame_of(target)[1]
				spin += delta * (2.4 if t < LIFT_S + HOLD_S else 0.0)
				if body != null and is_instance_valid(body):
					body.rotation.y = spin
			frame.face(eye)
			frame.set_param("fade", clampf(t / 0.15, 0.0, 1.0))
			frame.set_param("glow", 2.4 + sin(t * 9.0) * 0.6)
			if t >= LIFT_S + HOLD_S + SLAM_S or not _alive():
				_slam()
			return
		var u := (t - LIFT_S - HOLD_S - SLAM_S) / OUT_S
		frame.set_param("fade", clampf(1.0 - u * 3.0, 0.0, 1.0))
		if tile != null:
			tile.resize(Vector2(3.0, 3.0) * lerpf(1.0, 2.6, KeyFx.ease_out(u)))
			tile.set_param("fade", clampf(1.0 - u, 0.0, 1.0))
		if u >= 1.0:
			queue_free()

	func _slam() -> void:
		slammed = true
		tile = KeyWindow.make(Vector2(3.0, 3.0), KeyWindow.Style.FRAME, KeyFx.color_of("float"), "", 10.0)
		tile.set_param("body_alpha", 0.25)
		tile.set_param("glow", 3.5)
		tile.set_param("border", 0.07)
		tile.top_level = true
		add_child(tile)
		tile.global_position = ground + Vector3.UP * 0.06
		tile.global_basis = Basis(Vector3.RIGHT, -PI * 0.5)
		if _alive():
			target.global_position = ground
			if body != null and is_instance_valid(body):
				body.rotation.y = 0.0
			var at: Vector3 = target.threat_point()
			if target.hit(3.0, at, Vector3.DOWN, KeyFx.SOURCE_PREFIX + "float") and not target.is_alive():
				kills += 1
		var fx := ParticleFx.of(self)
		if fx != null:
			fx.blast(ground + Vector3.UP * 0.2, KeyFx.color_of("float"), 2.4)
		landed.emit(self)


# --- The shortcuts' sounds, made once, in code. ---

static var _sounds := {}


## The sound of shortcut `id`: a terminal's keys rattling into a thump; a close's click and zip; a split's ring; a float's
## rising whoosh; full screen's swell; a workspace's swish; a key that is not a weapon, a soft tick.
static func sound(id: String) -> AudioStreamWAV:
	if _sounds.has(id):
		return _sounds[id]
	var rate := 22050
	var seconds := {"terminal": 0.42, "close": 0.5, "split": 0.45, "float": 1.7, "fullscreen": 0.7, "workspace": 0.32, "goto": 0.32}.get(id, 0.08) as float
	var count := int(seconds * rate)
	var data := PackedByteArray()
	data.resize(count * 2)
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(id)
	var ph := 0.0
	for i in count:
		var s := float(i) / rate
		var u := s / seconds
		var v := 0.0
		match id:
			"terminal":
				var clack := 0.0
				var at := fmod(s, 0.028)
				if s < 0.16:
					clack = rng.randf_range(-1.0, 1.0) * exp(-at * 260.0) * 0.7
				var f := lerpf(160.0, 46.0, clampf((s - 0.14) / 0.2, 0.0, 1.0))
				ph += TAU * f / rate
				var thump := sin(ph) * exp(-maxf(s - 0.14, 0.0) * 9.0) * (1.0 if s >= 0.14 else 0.0)
				v = clack + thump * 0.9 + rng.randf_range(-1.0, 1.0) * 0.25 * exp(-maxf(s - 0.14, 0.0) * 14.0) * (1.0 if s >= 0.14 else 0.0)
			"close":
				var click := rng.randf_range(-1.0, 1.0) * exp(-s * 300.0)
				var f := lerpf(1800.0, 220.0, clampf((s - 0.16) / 0.3, 0.0, 1.0))
				ph += TAU * f / rate
				var zip := signf(sin(ph)) * 0.22 * (1.0 if s >= 0.16 else 0.0) * exp(-maxf(s - 0.4, 0.0) * 30.0)
				v = click * 0.8 + zip
			"split":
				var f := 2400.0 + 600.0 * sin(s * 40.0)
				ph += TAU * f / rate
				v = sin(ph) * exp(-s * 7.0) * 0.4 + rng.randf_range(-1.0, 1.0) * exp(-s * 40.0) * 0.5
			"float":
				var f := lerpf(110.0, 520.0, clampf(u / 0.4, 0.0, 1.0))
				ph += TAU * f / rate
				var rise := (sin(ph) * 0.25 + rng.randf_range(-1.0, 1.0) * 0.12) * sin(PI * clampf(u / 0.95, 0.0, 1.0))
				var slam := 0.0
				if s > 1.56:
					slam = (rng.randf_range(-1.0, 1.0) * 0.6 + sin((s - 1.56) * TAU * 55.0)) * exp(-(s - 1.56) * 18.0)
				v = rise + slam
			"fullscreen":
				var f := lerpf(80.0, 640.0, pow(clampf(u, 0.0, 1.0), 0.5))
				ph += TAU * f / rate
				v = (sin(ph) * 0.4 + sin(ph * 1.5) * 0.2 + rng.randf_range(-1.0, 1.0) * 0.15) * sin(PI * clampf(u, 0.0, 1.0))
			"workspace", "goto":
				v = rng.randf_range(-1.0, 1.0) * sin(PI * u) * 0.5 * (0.6 + 0.4 * sin(s * 90.0))
			_:
				ph += TAU * 1320.0 / rate
				v = sin(ph) * exp(-s * 60.0) * 0.35
		data.encode_s16(i * 2, int(clampf(v * 0.85, -1.0, 1.0) * 32767.0))
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = rate
	stream.stereo = false
	stream.data = data
	_sounds[id] = stream
	return stream
