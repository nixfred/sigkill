extends SceneTree
## Headless viewmodel test for SIGKILL (A1). scripts/check.sh runs it, and any FAIL exits 1.
##
##   godot --headless --path . --fixed-fps 60 --script res://tests/viewmodel_test.gd
##
## The weapons held in first person (A1). The resources: every weapon of the arsenal names a model
## of its own (scripts/viewmodels/), a script that is not a model is refused, a weapon with none is
## allowed and gets the placeholder box; the arsenal's motion numbers, bad ones refused. A scan: the
## models and the capture tool touch nothing outside the game, nothing is rebuilt while a model is
## held, and the game never runs the tool. Each model built alone: its Muzzle marker at its front,
## in front of the camera and in view at the arena's field of view, never over the crosshair; its
## trim glowing in its own skin at its own energy; a low triangle budget; one mesh with a surface
## per material; eight different shapes; root's red on the trim, the hot parts and the rims, and
## back; the rail's coils lighting in order with its charge, rm -rf's core and vents with its
## wind-up; the placeholder box where none is named. In the real arena with the real player: only
## the drawn model shown, the player's muzzle its Muzzle; a shot's beam starting at it and its flash
## on it while the shot itself still leaves from the eyes; the kick back and up and the settle,
## SIGTERM's light and the rail's and rm -rf's heavy; the raise from below; the lag behind a turn
## and the settle; the sway with the stride and none standing; the charges lighting and going back;
## the fork bomb's drum and cron's clock hand turning while held; nothing rebuilt by any of it.
## Deterministic: frames counted, only counts and outcomes printed.

const Link = preload("res://scripts/guide/guide_link.gd")
const MainScene = preload("res://scenes/main.tscn")
const Palette = preload("res://scripts/palette.gd")
const Controls = preload("res://scripts/controls.gd")
const WeaponDefScript = preload("res://scripts/weapons/weapon_def.gd")
const ARSENAL_PATH := "res://resources/arsenal.tres"
const MOVEMENT_PATH := "res://resources/movement_tuning.tres"
const MODEL_DIR := "res://scripts/viewmodels/"
## A model's budget, in triangles, and the least a real one has (the placeholder box has 12).
const TRIANGLES_FIRST := 200
const TRIANGLES_LAST := 3000
## The muzzle is this far in front of the camera at least, and inside this share of the view.
const MUZZLE_NEAREST_M := 0.3
const VIEW_SHARE := 0.95
## No part of a model comes within this many degrees of the crosshair.
const CROSSHAIR_CLEAR_DEGREES := 4.0
const SPAWN := Vector3(0.0, 0.95, 10.0)
const EPS := 0.0005
const NEAR_M := 0.002

var _fails := 0
var _checks := 0
var _tmp := ""
var _arsenal: Resource
var _defs: Array = []
var _scratch: Array = []
var _arenas: Array = []


func _initialize() -> void:
	GameSettings.current().set_value("gameplay", "practice", true)  # these checks predate C27b: the daemons stay the old never-attack dummies
	_run()


func _run() -> void:
	await process_frame
	root.size = Vector2i(1280, 720)
	_tmp = OS.get_temp_dir().path_join("sigkill-viewmodel-test-%d" % OS.get_process_id())
	DirAccess.make_dir_recursive_absolute(_tmp)
	Controls.ensure()
	_arsenal = load(ARSENAL_PATH)
	_defs = _arsenal.loadout
	_resource_checks()
	_source_checks()
	await _model_checks()
	await _arena_checks()
	await _cleanup()
	for name in DirAccess.get_files_at(_tmp):
		DirAccess.remove_absolute(_tmp.path_join(name))
	DirAccess.remove_absolute(_tmp)
	print("VIEWMODEL: %d checks" % _checks)
	print("VIEWMODEL RESULT: ", "ALL PASS" if _fails == 0 else "%d FAILED" % _fails)
	quit(0 if _fails == 0 else 1)


func _check(label: String, ok: bool, detail: String = "") -> void:
	_checks += 1
	print("PASS " if ok else "FAIL ", label, ("   " + detail) if detail != "" else "")
	if not ok:
		_fails += 1


# --- The resources. ---

func _resource_checks() -> void:
	var paths := {}
	var wrong := PackedStringArray()
	for def in _defs:
		var script: Script = def.viewmodel_model
		if script == null or not Viewmodel.is_model(script) or not script.resource_path.begins_with(MODEL_DIR) or not def.problems().is_empty():
			wrong.append(def.id)
		else:
			paths[script.resource_path] = true
	_check("acceptance: every weapon of the arsenal (8) names a model of its own in its resource, a script under scripts/viewmodels/ extending the Viewmodel, and still passes its own checks", _defs.size() == 8 and paths.size() == 8 and wrong.is_empty(), ", ".join(wrong))
	var bad = _defs[0].duplicate()
	bad.viewmodel_model = load("res://scripts/palette.gd")
	var none = _defs[0].duplicate()
	none.viewmodel_model = null
	_check("a weapon naming a script that is not a model is refused with the reason; one naming none is allowed (the placeholder box)", ", ".join(bad.problems()).contains("viewmodel_model") and none.problems().is_empty(), str(bad.problems()))
	_check("the arsenal's motion numbers pass its checks: a 0.025 s lag capped at 5 degrees, a 0.008 by 0.006 m stride, a 22 degree tip on the raise, a third of it all aimed", _arsenal.problems().is_empty() and _arsenal.sway_lag_s == 0.025 and _arsenal.sway_cap_degrees == 5.0 and _arsenal.bob_m == Vector2(0.008, 0.006) and _arsenal.swap_tilt_degrees == 22.0 and _arsenal.aim_motion_share == 0.35, str(_arsenal.problems()))
	var cases := [["sway_lag_s", -0.1], ["sway_lag_s", 1.0], ["sway_cap_degrees", 45.0], ["sway_recovery", 0.0], ["bob_m", Vector2(0.5, 0.0)], ["bob_m", Vector2(0.0, -0.1)], ["bob_roll_degrees", 30.0], ["fall_lag_m", 0.2], ["fall_lag_cap_m", 1.0], ["kick_lift_share", 3.0], ["swap_tilt_degrees", 120.0], ["aim_motion_share", 1.5], ["sway_recovery", NAN]]
	var missed := PackedStringArray()
	for c in cases:
		var odd = _arsenal.duplicate()
		odd.set(c[0], c[1])
		if not ", ".join(odd.problems()).contains(c[0]):
			missed.append("%s=%s" % c)
	_check("bad motion numbers are refused with the reason: a negative or long lag, a wide cap, no recovery, a big or negative stride, a big roll, a long fall's trail or cap, a big lift, an over-tipped raise, more than all of it aimed, not a number", missed.is_empty(), ", ".join(missed))


func _source_checks() -> void:
	var models := ""
	for name in DirAccess.get_files_at(MODEL_DIR):
		if name.ends_with(".gd"):
			models += _code(MODEL_DIR + name)
	var tool := _code("res://tools/capture_shots.gd")
	var found := PackedStringArray()
	for word in ["OS.", "execute", "create_process", "DirAccess", "FileAccess", "move_to_trash", "shell_open", "Thread", "HTTP", "PacketPeer", "StreamPeer", "Expression", "rpc"]:
		if models.contains(word):
			found.append(word)
	if RegEx.create_from_string("(?<!pre)load\\(").search(models) != null:
		found.append("load(")
	for word in ["OS.execute", "create_process", "FileAccess", "HTTP", "shell_open", "move_to_trash"]:
		if tool.contains(word):
			found.append("the tool: " + word)
	_check("acceptance: the models are cosmetic code only: no OS call, no file or folder access, no thread, socket or network, nothing loaded at run time, no RPC; the capture tool runs and opens nothing either", found.is_empty() and models.length() > 8000 and tool.length() > 1000, ", ".join(found))
	var base := _code(MODEL_DIR + "viewmodel.gd")
	var player := _code("res://scripts/player.gd")
	var held := ""
	for name in ["idle", "set_glow", "set_look", "set_charge", "_refresh", "piece_energy"]:
		held += _body(base, name)
	held += _body(player, "_place_viewmodel") + _body(player, "_set_glow") + _body(player, "_step_root") + _body(player, "_step_charge") + _body(player, "_end_charge")
	var rebuilt := PackedStringArray()
	for word in ["SurfaceTool", "commit(", "ArrayMesh", "Mesh.new", ".new(", "add_child", "_build"]:
		if held.contains(word):
			rebuilt.append(word)
	_check("acceptance: nothing is rebuilt while a model is held: what runs each frame (its motion, glow, look, charge, pulses and turns) makes no mesh, no node and no material", rebuilt.is_empty() and held.length() > 1500, ", ".join(rebuilt))
	var game := ""
	for dir in ["res://scripts/", "res://scenes/"]:
		game += _tree_text(dir)
	_check("the game never runs the capture tool: nothing under scripts/ or scenes/ names it", not game.contains("capture_shots") and game.length() > 100000)
	var fire := _body(player, "_fire")
	_check("acceptance: the shot still leaves from the eyes (the muzzle is where its beam and flash start, nothing else): the fire intent's origin is the camera's", fire.contains("var origin := _camera.global_position") and fire.contains("fire_intent.emit(origin, forward, _w.id)") and fire.contains("CannonFx.spawn_beam(fx_root, muzzle_point(), end_point, _w)") and _body(player, "muzzle_point").contains("_muzzle.global_position"))


# --- Each model built alone. ---

func _model_checks() -> void:
	var world := Node3D.new()
	root.add_child(world)
	_scratch.append(world)
	var cam := Camera3D.new()
	cam.fov = load(MOVEMENT_PATH).base_fov
	world.add_child(cam)
	var models: Array = []
	for def in _defs:
		var model := Viewmodel.make(def)
		cam.add_child(model)
		models.append(model)
	await physics_frame
	var built := PackedStringArray()
	var glow := PackedStringArray()
	var budget := PackedStringArray()
	var front := PackedStringArray()
	var view := PackedStringArray()
	var clear := PackedStringArray()
	var shapes := {}
	var total := 0
	var half := deg_to_rad(cam.fov * 0.5)
	for i in models.size():
		var model: Viewmodel = models[i]
		var def = _defs[i]
		var body := model.get_node_or_null("Body") as MeshInstance3D
		var surfaces: int = body.mesh.get_surface_count() if body != null else 0
		var materials := 0
		for s in surfaces:
			materials += 1 if body.mesh.surface_get_material(s) != null else 0
		if model.muzzle == null or model.muzzle.get_parent() != model or model.muzzle.name != "Muzzle" or surfaces < 2 or surfaces > 4 or materials != surfaces or model.mesh == null or model.get_script() != def.viewmodel_model:
			built.append(def.id)
		var trim := model.material_override as StandardMaterial3D
		if trim == null or trim != model.glow or trim.emission != def.skin_body() or not is_equal_approx(trim.emission_energy_multiplier, def.viewmodel_glow_energy) or trim.albedo_color != def.skin_body().darkened(Viewmodel.TRIM_DARKEN):
			glow.append(def.id)
		var tris := model.triangles()
		total += tris
		if tris < TRIANGLES_FIRST or tris > TRIANGLES_LAST:
			budget.append("%s %d" % [def.id, tris])
		var box := _bounds(model)
		var tip := model.muzzle.position
		# Its front is along the way it is held: -Z through its pose (the fork bomb's canister is turned).
		var forward: Vector3 = model.pose.basis * Vector3.FORWARD
		var reach := -INF
		for corner in 8:
			reach = maxf(reach, box.get_endpoint(corner).dot(forward))
		var middle := box.get_center().dot(forward)
		if not box.grow(0.01).has_point(tip) or tip.dot(forward) < middle + (reach - middle) * 0.5:
			front.append("%s (tip %.3f, middle %.3f, reach %.3f)" % [def.id, tip.dot(forward), middle, reach])
		var at := model.transform * tip
		if at.z > -MUZZLE_NEAREST_M or absf(at.y) / -at.z > tan(half) * VIEW_SHARE or absf(at.x) / -at.z > tan(half) * (4.0 / 3.0) * VIEW_SHARE:
			view.append(def.id)
		# The box's nearest approach to the line of sight: its point closest to the axis, as far out
		# as the box goes (the model at rest only moves, never turns, so the box moves with it).
		var seen := AABB(model.transform * box.position, box.size)
		var aside := Vector2(clampf(0.0, seen.position.x, seen.end.x), clampf(0.0, seen.position.y, seen.end.y))
		if seen.position.z < 0.0 and rad_to_deg(atan2(aside.length(), -seen.position.z)) < CROSSHAIR_CLEAR_DEGREES:
			clear.append(def.id)
		shapes["%d %d %d %d" % [roundi(box.size.x * 100.0), roundi(box.size.y * 100.0), roundi(box.size.z * 100.0), tris]] = def.id
	_check("acceptance: every model is built: a Muzzle marker of its own, a Body mesh of 2 to 4 surfaces each with its material (body, plates, polymer, hot parts), the trim its own mesh, the script its weapon names", built.is_empty(), ", ".join(built))
	_check("acceptance: every model's trim glows in its weapon's own light skin at the weapon's own energy, its base darkened under it as the old box's was", glow.is_empty(), ", ".join(glow))
	_check("acceptance: low poly: every model between %d and %d triangles (all eight %d), built once" % [TRIANGLES_FIRST, TRIANGLES_LAST, total], budget.is_empty(), ", ".join(budget))
	_check("acceptance: every Muzzle marker is at its model's front, on the barrel's tip, so effects come out of the barrel", front.is_empty(), ", ".join(front))
	_check("acceptance: every muzzle sits in front of the camera, %.1f m at least, and in view at the arena's %d degree field of view, at 16:9 and at 4:3" % [MUZZLE_NEAREST_M, cam.fov], view.is_empty(), ", ".join(view))
	_check("no model reaches within %d degrees of the crosshair" % CROSSHAIR_CLEAR_DEGREES, clear.is_empty(), ", ".join(clear))
	_check("acceptance: eight different shapes: no two models share their size and triangle count", shapes.size() == 8, str(shapes.size()))
	await _look_checks(models)
	_placeholder_checks(cam)


func _look_checks(models: Array) -> void:
	var rail: Viewmodel = models[2]
	var energy: float = _defs[2].viewmodel_glow_energy
	rail.set_look(Palette.HOSTILE_RED, Palette.HOSTILE_RED, energy * 1.5)
	var red: bool = rail.glow.emission == Palette.HOSTILE_RED and (rail.get("_hot") as StandardMaterial3D).emission == Palette.HOSTILE_RED and (rail.get("_metal") as ShaderMaterial).get_shader_parameter("neon") == Palette.HOSTILE_RED and (rail.get("_plate") as ShaderMaterial).get_shader_parameter("neon") == Palette.HOSTILE_RED and is_equal_approx(rail.glow.emission_energy_multiplier, energy * 1.5)
	for piece in rail.get("_pieces"):
		red = red and (piece["material"] as StandardMaterial3D).emission == Palette.HOSTILE_RED
	rail.set_look(_defs[2].skin_body(), _defs[2].skin_beam(), energy)
	var back: bool = rail.glow.emission == _defs[2].skin_body() and (rail.get("_hot") as StandardMaterial3D).emission == _defs[2].skin_beam() and (rail.get("_metal") as ShaderMaterial).get_shader_parameter("neon") == _defs[2].skin_body()
	for piece in rail.get("_pieces"):
		back = back and (piece["material"] as StandardMaterial3D).emission == _defs[2].skin_beam()
	_check("root's look reaches the whole model: the trim, the hot parts, the coils and both metals' rims in root's red at root's glow, then back to the rail's own ice", red and back)
	var coils: Array = []
	for entry in rail.get("_charge_pieces"):
		coils.append(entry[0])
	var shares := []
	for progress in [0.0, 0.3, 1.0]:
		rail.set_charge(progress)
		var row := []
		for id in coils:
			row.append(rail.piece_energy(id) / Viewmodel.HOT_SHARE)
		shares.append(row)
	rail.set_charge(0.0)
	var rest := Viewmodel.CHARGE_REST
	var full := Viewmodel.CHARGE_REST + Viewmodel.CHARGE_GAIN
	var ordered: bool = coils.size() == 4 and rail.get("_charge_orders") == 4
	for k in 4:
		ordered = ordered and is_equal_approx(shares[0][k], rest) and is_equal_approx(shares[2][k], full)
	ordered = ordered and is_equal_approx(shares[1][0], full) and shares[1][1] > rest and shares[1][1] < full and is_equal_approx(shares[1][2], rest) and is_equal_approx(shares[1][3], rest)
	_check("acceptance: the rail's four coils light in order with its charge: all at rest uncharged, at 30% the first full, the second part lit and the last two at rest, all full charged", ordered, str(shares))
	var rm: Viewmodel = models[6]
	var lit := []
	for progress in [0.0, 0.5, 1.0]:
		rm.set_charge(progress)
		var sum := 0.0
		for entry in rm.get("_charge_pieces"):
			sum += rm.piece_energy(entry[0])
		lit.append(sum)
	rm.set_charge(0.0)
	_check("acceptance: rm -rf's core and vents glow up through its wind-up, together", rm.get("_charge_pieces").size() == 2 and rm.get("_charge_orders") == 1 and lit[0] < lit[1] and lit[1] < lit[2], str(lit))


func _placeholder_checks(cam: Camera3D) -> void:
	var none = _defs[0].duplicate()
	none.viewmodel_model = null
	var box := Viewmodel.make(none)
	cam.add_child(box)
	_check("a weapon with no model of its own gets the placeholder: one glowing box of viewmodel_size, its muzzle where muzzle_offset says", box.get_script() == Viewmodel and box.triangles() == 12 and box.mesh.get_aabb().size.is_equal_approx(none.viewmodel_size) and box.muzzle.position.is_equal_approx(none.muzzle_offset - none.viewmodel_offset) and box.glow.emission == none.skin_body())


## The model's box in its own space: every mesh in it, through its node's place.
func _bounds(model: Viewmodel) -> AABB:
	var box := model.mesh.get_aabb()
	for node in model.find_children("*", "MeshInstance3D", true, false):
		var m := (node as MeshInstance3D).mesh
		if m != null and m.get_surface_count() > 0:
			box = box.merge((node as MeshInstance3D).transform * m.get_aabb())
	return box


# --- In the real arena. ---

func _arena_checks() -> void:
	var side := await _arena()
	var main: Node = side["main"]
	var p: Node = side["player"]
	var cam: Camera3D = p.get_node("Head/Camera")
	var models: Array = p.get("_viewmodels")
	var meshes := _mesh_ids(models)
	var tris := 0
	for model in models:
		tris += model.triangles()
	var shown := PackedStringArray()
	for slot in models.size():
		if slot > 0:
			p.select_slot(slot)
		await _settle(p, 0.5)
		var visible := 0
		for model in models:
			visible += 1 if model.visible else 0
		# Where the eye sees the tip (A4: the models are drawn shrunk toward the eye).
		var tip: Vector3 = cam.to_local(p.muzzle_point())
		var resting: bool = models[slot].position.distance_to(_defs[slot].viewmodel_offset) < NEAR_M
		if visible != 1 or not models[slot].visible or p.get("_muzzle") != models[slot].muzzle or tip.z > -MUZZLE_NEAREST_M or not resting:
			shown.append(_defs[slot].id)
	_check("acceptance: drawn in turn, each weapon shows its own model alone, at rest at its offset, and the player's muzzle is that model's Muzzle, in front of the camera", shown.is_empty(), ", ".join(shown))
	await _shot_checks(main, p, cam, models)
	await _motion_checks(main, p, models)
	await _charge_checks(p, models)
	await _idle_checks(p, models)
	var same: bool = _mesh_ids(models) == meshes
	var tris_after := 0
	for model in models:
		tris_after += model.triangles()
	_check("acceptance: nothing rebuilt: after every draw, shot, charge, turn and stride above, every model holds the very meshes it was built with (%d triangles in all)" % tris, same and tris_after == tris)


func _shot_checks(main: Node, p: Node, cam: Camera3D, models: Array) -> void:
	p.respawn_at(main.to_global(SPAWN))
	p.rotation.y = 0.0
	p.get_node("Head").rotation.x = 0.0
	p.select_slot(0)
	await _settle(p, 0.6)
	var origins := []
	var heard := func(origin: Vector3, _dir: Vector3, _id: String): origins.append(origin)
	p.fire_intent.connect(heard)
	var muzzle: Marker3D = models[0].muzzle
	# Where the eye sees the barrel's tip (A4): the marker grown back out to the model's full size.
	var tip: Vector3 = p.muzzle_point()
	var on_screen := cam.unproject_position(tip).distance_to(cam.unproject_position(muzzle.global_position))
	var eye := cam.global_position
	var shots: int = p.shots_fired
	p.drive_input(Vector2.ZERO, false, false, true)
	await physics_frame
	var flash := _fx("MuzzleFlash")
	var beam := _fx("CannonBeam") as Node3D
	var start := Vector3.INF
	if beam != null and beam.get_child_count() > 0:
		var length: float = (beam.get_child(0) as MeshInstance3D).mesh.height
		start = beam.global_position + beam.global_basis.z * length * 0.5
	var model: Viewmodel = models[0]
	var offset: Vector3 = _defs[0].viewmodel_offset
	var kicked: bool = model.position.z - offset.z > _defs[0].viewmodel_kick_back * 0.9 and model.position.y > offset.y and model.rotation.x > 0.0
	_check("acceptance: a cannon shot's flash is on the drawn model's Muzzle and its beam starts at it, at the barrel's tip, while the shot itself leaves from the eyes, as before", p.shots_fired == shots + 1 and flash != null and flash.get_parent() == muzzle and start.distance_to(tip) < 0.01 and on_screen < 0.5 and origins.size() == 1 and origins[0].distance_to(eye) < EPS and tip.distance_to(eye) > MUZZLE_NEAREST_M, "beam from %.3f m off the muzzle, %.2f px off its marker on screen" % [start.distance_to(tip), on_screen])
	p.fire_intent.disconnect(heard)
	await _settle(p, 1.0)
	_check("acceptance: the shot kicks the model back and up, the barrel tipped up, and it settles back to rest", kicked and model.position.distance_to(offset) < NEAR_M and absf(model.rotation.x) < deg_to_rad(0.1))
	var kicks := {}
	for slot in [1, 2, 6]:
		p.select_slot(slot)
		await _settle(p, 0.6)
		p.inventory.add_meter(p.inventory.meter_full())
		var shots_before: int = p.shots_fired
		p.drive_input(Vector2.ZERO, false, false, true)
		var frames := 0
		while p.shots_fired == shots_before and frames < 120:
			await physics_frame
			p.drive_input(Vector2.ZERO)
			frames += 1
		var vm: Viewmodel = models[slot]
		kicks[slot] = [vm.position.z - _defs[slot].viewmodel_offset.z, vm.rotation.x]
		await _settle(p, 2.0)
	_check("acceptance: the kick is the weapon's own: SIGTERM's light, the rail's and rm -rf's heavy (over three times as far back, twice as far up)", kicks[2][0] > kicks[1][0] * 3.0 and kicks[6][0] > kicks[1][0] * 3.0 and kicks[2][1] > 0.0 and kicks[6][1] > kicks[1][1] * 2.0 and kicks[1][0] > 0.0, str(kicks))
	p.select_slot(1)
	await physics_frame
	var drawn: Viewmodel = models[1]
	var low: bool = drawn.position.y < _defs[1].viewmodel_offset.y - 0.1 and drawn.rotation.x < -deg_to_rad(10.0)
	await _settle(p, 0.6)
	_check("acceptance: a weapon being drawn rises from below, tipped down, to its rest", low and drawn.position.distance_to(_defs[1].viewmodel_offset) < NEAR_M and absf(drawn.rotation.x) < deg_to_rad(0.1))


func _motion_checks(main: Node, p: Node, models: Array) -> void:
	p.respawn_at(main.to_global(SPAWN))
	p.rotation.y = 0.0
	p.get_node("Head").rotation.x = 0.0
	p.select_slot(0)
	await _settle(p, 1.0)
	var model: Viewmodel = models[0]
	var cap := deg_to_rad(_arsenal.sway_cap_degrees)
	var right := 0.0
	for i in 20:
		p.look_with_stick(Vector2(1.0, 0.0), 1.0 / 60.0)
		p.drive_input(Vector2.ZERO)
		await physics_frame
		right = maxf(right, model.rotation.y)
	await _settle(p, 1.0)
	var settled_yaw := model.rotation.y
	var left := 0.0
	var down := 0.0
	for i in 20:
		p.look_with_stick(Vector2(-1.0, 1.0), 1.0 / 60.0)
		p.drive_input(Vector2.ZERO)
		await physics_frame
		left = minf(left, model.rotation.y)
		down = maxf(down, model.rotation.x)
	await _settle(p, 1.0)
	_check("acceptance: the model lags a turn: turning right it swings left, turning left right, looking down its barrel up, never past the cap, and it settles back when the turning stops", right > deg_to_rad(0.5) and right <= cap + EPS and left < -deg_to_rad(0.5) and left >= -cap - EPS and down > deg_to_rad(0.5) and absf(settled_yaw) < deg_to_rad(0.05) and absf(model.rotation.y) < deg_to_rad(0.05) and absf(model.rotation.x) < deg_to_rad(0.05), "right %.2f, left %.2f, down %.2f degrees" % [rad_to_deg(right), rad_to_deg(left), rad_to_deg(down)])
	p.respawn_at(main.to_global(SPAWN))
	p.rotation.y = 0.0
	p.get_node("Head").rotation.x = 0.0
	await _settle(p, 1.0)
	var offset: Vector3 = _defs[0].viewmodel_offset
	var still := 0.0
	for i in 30:
		p.drive_input(Vector2.ZERO)
		await physics_frame
		still = maxf(still, model.position.distance_to(offset))
	var across := 0.0
	var up := 0.0
	for i in 60:
		p.drive_input(Vector2(0.0, -1.0))
		await physics_frame
		across = maxf(across, absf(model.position.x - offset.x))
		up = maxf(up, absf(model.position.y - offset.y))
	await _settle(p, 1.5)
	var bob: Vector2 = _arsenal.bob_m
	_check("acceptance: the model sways with the stride, across and up within the arsenal's stride, not at all standing still, and settles when the walk stops", still < 0.0005 and across > bob.x * 0.3 and across <= bob.x + 0.002 and up > bob.y * 0.3 and model.position.distance_to(offset) < NEAR_M, "standing %.4f, across %.4f, up %.4f m" % [still, across, up])


func _charge_checks(p: Node, models: Array) -> void:
	p.select_slot(2)
	await _settle(p, 0.6)
	p.inventory.add_meter(p.inventory.meter_full())
	var rail: Viewmodel = models[2]
	var coils := []
	for entry in rail.get("_charge_pieces"):
		coils.append(entry[0])
	var shots: int = p.shots_fired
	var order_held := true
	var all_lit := false
	var peak := 0.0
	p.drive_input(Vector2.ZERO, false, false, true)
	for k in 90:
		await physics_frame
		p.drive_input(Vector2.ZERO)
		if p.shots_fired > shots:
			break
		var row := []
		for id in coils:
			row.append(rail.piece_energy(id))
			peak = maxf(peak, rail.piece_energy(id))
		for c in 3:
			order_held = order_held and row[c] >= row[c + 1] - EPS
		all_lit = row[3] > Viewmodel.HOT_SHARE * Viewmodel.CHARGE_REST * 2.0
	await _settle(p, 0.3)
	var rested := true
	for id in coils:
		rested = rested and is_equal_approx(rail.piece_energy(id), Viewmodel.HOT_SHARE * Viewmodel.CHARGE_REST)
	var cap := Viewmodel.HOT_SHARE * (Viewmodel.CHARGE_REST + Viewmodel.CHARGE_GAIN)
	_check("acceptance: through the rail's real charge its coils light in order, every one lit by the shot, never past a full charge's own glow (%.2f times the weapon's) however the trim's charge glow climbs, and all back to rest after it" % cap, p.shots_fired == shots + 1 and order_held and all_lit and peak <= cap + EPS and rested, "peak %.2f" % peak)
	p.select_slot(6)
	await _settle(p, 0.6)
	p.inventory.refill()  # its one round went in the kick check
	var rm: Viewmodel = models[6]
	shots = p.shots_fired
	var glow := []
	p.drive_input(Vector2.ZERO, false, false, true)
	for k in 90:
		await physics_frame
		p.drive_input(Vector2.ZERO)
		if p.shots_fired > shots:
			break
		var sum := 0.0
		for entry in rm.get("_charge_pieces"):
			sum += rm.piece_energy(entry[0])
		glow.append(sum)
	await _settle(p, 0.3)
	var climbed := glow.size() > 10
	for k in range(1, glow.size()):
		climbed = climbed and glow[k] >= glow[k - 1] - EPS
	_check("acceptance: through rm -rf's real wind-up its core and vents glow up, frame by frame, and are back to rest after the shot", p.shots_fired == shots + 1 and climbed and glow[glow.size() - 1] > glow[0] * 3.0 and rm.charge() == 0.0)


func _idle_checks(p: Node, models: Array) -> void:
	p.select_slot(3)
	await _settle(p, 0.5)
	var drum := (models[3] as Viewmodel).get("_pieces")[0]["node"] as Node3D
	var before := drum.basis
	await _settle(p, 0.5)
	var turned := before.get_rotation_quaternion().angle_to(drum.basis.get_rotation_quaternion())
	p.select_slot(7)
	await _settle(p, 0.5)
	var cron: Viewmodel = models[7]
	var hand := cron.get("_pieces")[1]["node"] as Node3D
	var start := hand.basis
	var interval: float = _defs[7].run_interval_s
	await _settle(p, interval * 0.5)
	var half := start.get_rotation_quaternion().angle_to(hand.basis.get_rotation_quaternion())
	_check("acceptance: held, the fork bomb's drum turns (a quarter turn a second) and cron's clock hand goes round once a run interval (half round in half of one)", absf(turned - 0.25 * TAU * 0.5) < 0.05 and absf(half - PI) < 0.08, "drum %.3f, hand %.3f rad" % [turned, half])


# --- Helpers. ---

func _arena() -> Dictionary:
	var link := Link.new()
	link.settings_path = _tmp.path_join("arena-privacy.cfg")
	link.demo = true
	Link.park(link)
	var main = MainScene.instantiate()
	root.add_child(main)
	_arenas.append(main)
	var hud = main.get_node("Hud")
	hud.guide().focus_check = func(): return false
	var player = main.get_node("Player")
	player.assume_captured = true
	await _frames(3)
	return {"main": main, "player": player, "hud": hud}


func _settle(p: Node, seconds: float) -> void:
	for i in ceili(seconds * 60.0):
		p.drive_input(Vector2.ZERO)
		await physics_frame


func _frames(n: int) -> void:
	for i in n:
		await physics_frame


func _fx(kind: String) -> Node:
	for node in get_nodes_in_group(&"cannon_fx"):
		if String(node.name).contains(kind):
			return node
	return null


func _mesh_ids(models: Array) -> Array:
	var ids := []
	for model in models:
		for node in [model] + model.find_children("*", "MeshInstance3D", true, false):
			ids.append((node as MeshInstance3D).mesh.get_instance_id() if (node as MeshInstance3D).mesh != null else 0)
	return ids


func _tree_text(dir: String) -> String:
	var out := ""
	for name in DirAccess.get_files_at(dir):
		if name.ends_with(".gd") or name.ends_with(".tscn"):
			out += FileAccess.get_file_as_string(dir.path_join(name))
	for sub in DirAccess.get_directories_at(dir):
		out += _tree_text(dir.path_join(sub))
	return out


func _code(path: String) -> String:
	var out := PackedStringArray()
	for line in FileAccess.get_file_as_string(path).split("\n"):
		var quote := ""
		var cut := line.length()
		var i := 0
		while i < line.length():
			var ch := line[i]
			if quote != "":
				if ch == "\\":
					i += 1
				elif ch == quote:
					quote = ""
			elif ch == "\"" or ch == "'":
				quote = ch
			elif ch == "#":
				cut = i
				break
			i += 1
		out.append(line.substr(0, cut).rstrip(" \t"))
	return "\n".join(out)


func _body(source: String, name: String) -> String:
	var at := source.find("\nfunc %s(" % name)
	if at < 0:
		at = source.find("\nstatic func %s(" % name)
	if at < 0:
		return ""
	var end := source.find("\nfunc ", at + 1)
	var end_static := source.find("\nstatic func ", at + 1)
	if end_static > 0 and (end < 0 or end_static < end):
		end = end_static
	return source.substr(at, (end if end > 0 else source.length()) - at)


func _cleanup() -> void:
	for node in _arenas.duplicate() + _scratch.duplicate():
		if is_instance_valid(node):
			for sfx in node.find_children("*", "AudioStreamPlayer", true, false):
				(sfx as AudioStreamPlayer).stop()
			node.free()
	var left = Link.take_parked()
	if left != null:
		left.shut_down(null)
	Controls.apply_binds({})
	await process_frame
	OS.delay_msec(300)
	await process_frame
