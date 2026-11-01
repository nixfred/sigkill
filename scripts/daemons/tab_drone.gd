extends DaemonArt
## A drone of a live process swarm (W1, PRD 5.5): one child process of a nest (a browser's tab) or one thread of a busy
## process, given a body of its own. The enemy art bar's "angular red drone swarms": a small armoured hex hull flying
## flat, swept blade wings that flutter, a vermilion light in its back (its weak point) and a trail of light behind. It
## is one of many: its swarm's flock (scripts/procs/swarm_flock.gd) flies it with the others round their nest and in
## dives at the player; the art banks it into its turns (bank), stretches its trail with its pace, folds its wings and
## burns its light white before a dive (the tell) and sweeps them right back as it dives (the strike).
##
## No two alike (A5's rule): its seed sets its size, two wings or four, their length, sweep and droop, a dorsal fin or
## none, its light's pulse and now and then a flickering light. Never an elite: a drone is small by design. Faceless:
## armour and light. Visual only: its dummy keeps its own small hit volume, sized by the hunt (scripts/procs/proc_hunt.gd).

const HULL_W := 0.42
const HULL_H := 0.11
const WING_L := 0.46
const LIGHT_M := 0.13
const FIN_L := 0.22
const TRAIL_L := 0.5
const FLUTTER_HZ := 9.0

## Set by its flock each frame: how hard it banks (radians, its roll into a turn), its pace (0 still to 1 at speed).
var bank := 0.0
var pace := 0.0

var _hull: int
var _light: int
var _fin := -1
var _wings := PackedInt32Array()
var _trails := PackedInt32Array()
var _sweep := 0.5
var _droop := 0.0
var _wing_l := 1.0
var _beat := 0.0
var _pulse_hz := 1.0


func _build() -> void:
	ai_kind = "drone"
	core_color = Palette.VERMILION
	edge_color = Palette.VERMILION
	glyph_count = 0
	reach = AABB(Vector3(-0.9, -0.6, -0.9), Vector3(1.8, 1.2, 2.2))
	tag_height = 0.55
	budget_triangles = 700
	budget_draw_calls = 5
	size_low = 0.88
	size_high = 1.18
	elite_size = 1.18
	_sweep = lerpf(0.35, 0.75, dice(60, 0))
	_droop = lerpf(-0.12, 0.18, dice(61, 0))
	_wing_l = lerpf(0.8, 1.2, dice(62, 0))
	_beat = TAU * dice(63, 0)
	_pulse_hz = lerpf(0.7, 1.6, dice(64, 0))
	_hull = part(Shape.HEX, Look.ARMOR)
	_light = weak(part(Shape.GEM, Look.CORE))
	var pairs := 2 if dice(65, 0) < 0.4 else 1
	for i in pairs * 2:
		_wings.append(part(Shape.BLADE, Look.ARMOR))
	if dice(66, 0) < 0.55:
		_fin = part(Shape.FACET, Look.ARMOR)
	for i in 2:
		_trails.append(part(Shape.STREAK, Look.TRAIL))
	if dice(67, 0) < 0.15:
		flicker(_light, lerpf(0.3, 0.6, dice(68, 0)))


func _pose(t: float, _delta: float) -> void:
	var tell := drive_amount() if act == Act.TELL else 0.0
	var dive := drive_amount() if act == Act.STRIKE else 0.0
	var roll := Basis(Vector3.BACK, clampf(bank, -0.9, 0.9))
	var middle := recoil() + Vector3(0.0, 0.03 * sin(t * 3.1 + _beat), 0.0)
	# The hull: a flat hex puck, nose ahead (-Z), rolled into its turn.
	lay(_hull, middle, roll * Basis.from_scale(Vector3(HULL_W, HULL_H, HULL_W * 1.25)))
	var light_at := middle + roll * Vector3(0.0, HULL_H * 0.7, 0.05)
	var pulse := 0.5 + 0.5 * sin(TAU * _pulse_hz * t + _beat)
	orient(_light, light_at, roll * Vector3.UP, LIGHT_M * (1.0 + 0.5 * tell), LIGHT_M * 0.9)
	brighten(_light, 1.6 + 0.8 * pulse + 3.5 * tell + 1.5 * dive)
	# The wings: swept back from the hull's flanks, fluttering; folded tight in the tell, right back in the dive.
	var flutter := sin(TAU * FLUTTER_HZ * t + _beat) * 0.12 * (1.0 - 0.7 * dive)
	var sweep := clampf(_sweep + 0.45 * tell + 0.7 * dive, 0.0, 1.35)
	for k in _wings.size():
		var side := -1.0 if k % 2 == 0 else 1.0
		var row := int(float(k) / 2.0)
		var root := middle + roll * Vector3(side * HULL_W * 0.45, 0.0, 0.04 + 0.12 * row)
		var out := Vector3(side * cos(sweep), -_droop + flutter * side + 0.06 * row, sin(sweep))
		var length := WING_L * _wing_l * (0.75 if row == 1 else 1.0) * (1.0 - 0.25 * tell)
		bone(_wings[k], root, root + roll * out.normalized() * length, 0.09, 0.025, roll * Vector3.UP)
	if _fin >= 0:
		bone(_fin, middle + roll * Vector3(0.0, HULL_H * 0.5, 0.08), middle + roll * Vector3(0.0, HULL_H * 0.5 + FIN_L * 0.6, 0.08 + FIN_L), 0.05, 0.02, roll * Vector3.RIGHT)
	# The trail: two slivers of light behind, longer with its pace and longest in the dive.
	var reach_back := TRAIL_L * (0.35 + 0.65 * pace + 1.2 * dive)
	for k in _trails.size():
		var side := -1.0 if k == 0 else 1.0
		var from := middle + roll * Vector3(side * 0.08, 0.0, HULL_W * 0.55)
		bone(_trails[k], from, from + roll * Vector3(side * 0.03, 0.02 * sin(t * 7.0 + k), reach_back), 0.035)
		brighten(_trails[k], 0.9 + 0.8 * pace + 1.5 * dive)


## Where its lineage line meets it (world space): its light.
func anchor() -> Vector3:
	return global_transform * Vector3(0.0, HULL_H, 0.0) if is_inside_tree() else transform.origin


func _muzzle() -> Vector3:
	return Vector3(0.0, 0.0, -HULL_W * 0.6)
