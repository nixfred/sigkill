extends Node3D
## One cron mine (C27, PRD 5.2 "timed mines"): a scheduled job stuck where it was placed, a small
## glowing hex stud in cron's rose. After the weapon's arm_s it runs every run_interval_s, a set
## number of runs (one more for a mine placed as C22's root), each run an area blast; then the job
## ends and the mine fades out over fade_s. Before each run a ring closes over the wait, out at
## the blast's radius and in to nothing as the run comes, and for the last telegraph_s the stud
## brightens: a reader sees it coming and steps out. Over it, cron-style text names the schedule
## and the runs left ("*/2s x3", then x2, x1). Every number is the weapon's own
## (resources/cron_mines.tres, scripts/weapons/weapon_def.gd's mine and blast groups).
##
## Cheap on the frame: one node per mine and no physics but its hit volume: a small sphere on its
## own physics layer, MINE_LAYER, which only the host's judging of shots asks about (a shot within
## mine_hit_radius_m of it removes it); nothing walks into it and no other ray sees it.
##
## Who decides: a mine that decides (alone, or the host's in a match) keeps the schedule and hands
## each run to its judge (a Callable the owner's side gives it), which applies the damage. A mine
## on a joiner's screen only draws: its rings count down by the schedule, but it runs only on the
## host's word (apply_run(), with the runs left after it), and it ends on the word of its last run
## or of its removal; it never judges or schedules anything. Its own clock is only an estimate (a
## mine a joiner first hears of mid-job starts counting when it hears), so a late word is waited
## for: with one run left, it gives up only a whole run_interval_s and blast_wait_s past the time
## it guessed.
##
## Cosmetic fiction: "cron" is a name and HUD text. Nothing schedules, runs or touches anything
## real.

## A run went off at `at` (world space); `left`: runs still to come.
signal ran(left: int, at: Vector3)
## The mine is gone (its job done, or removed), `why` one of the reasons below.
signal finished(why: String)

const WeaponDefScript = preload("res://scripts/weapons/weapon_def.gd")
const Palette = preload("res://scripts/palette.gd")
## Every mine node is in this group, every run's ring in the next: the tests count them.
const GROUP := &"cron_mine"
const RING_GROUP := &"cron_ring"
## The node under a scene's root that holds every volley there (the fork() volleys' own).
const FIELD := "ForkVolleys"
## The mines' own physics layer (layer 4): only the host's shot judging asks about it.
const MINE_LAYER := 8
## A hit volume's metadata: the mine's id and its owner's player id (0 alone).
const MINE_ID_META := "mine_id"
const MINE_OWNER_META := "mine_owner"
## A run's time counts as reached within this many seconds: float sums of steps.
const TIME_EPS := 0.000001
## The schedule over the stud, cron-style: the interval and the runs left.
const SCHEDULE := "*/%ss x%d"
const LABEL_LIFT_M := 0.45
const LABEL_PIXEL := 0.004
const LABEL_FONT := 32
## How bright the stud glows, at rest and at its brightest before a run; the rings' glow.
const STUD_ENERGY := 2.5
const BRIGHT_ENERGY := 9.0
const RING_ENERGY := 5.0
## The stud is this share of its radius thick; the rings are this share of their radius wide.
const STUD_THICKNESS := 0.35
const RING_BAND := 0.1
## The run's ring starts at this share of the blast's radius; the countdown ring is never drawn
## smaller than this share (a scale of 0 would lose which way it lies).
const RING_START := 0.15
const COUNTDOWN_LEAST := 0.001
## Why a mine ended: its job done, the crontab full, a shot, its owner gone (or a round reset).
const DONE := "done"
const CRONTAB := "crontab"
const SHOT := "shot"
const GONE := "gone"

var def: WeaponDefScript
## This mine's id and its owner's player id (0 alone).
var mine_id := 0
var owner_id := 0
## The surface's normal where it stuck (world space, unit length).
var normal := Vector3.UP
## True: keeps the schedule and judges its runs. False: draws, runs on the word.
var authoritative := true
## judge(at) -> int for a run at `at`: what it hurt.
var judge := Callable()
## Runs in this job, and still to come.
var runs_total := 0
var runs_left := 0
## Seconds of this job so far, and when the next run is due.
var age := 0.0
var next_at := 0.0
## Each run's age, when it went off (the tests check the frames).
var run_ages: Array[float] = []
## Why it ended, "" while it runs.
var why := ""

var _stud: MeshInstance3D
## Lying flat on the surface it stuck to: the stud's and its rings' turn.
var _flat := Basis.IDENTITY
var _stud_glow: StandardMaterial3D
var _countdown: MeshInstance3D
var _label: Label3D
var _body: StaticBody3D
var _fading := 0.0
var _done := false


## A mine of `weapon` under `root_node` (the arena) at `at` stuck to a surface with `normal`
## (world space), id `id` of `owner`, with `left` runs to come (all of them, when just placed).
## `deciding`: keeps the schedule and judges its runs; `armed`: its arm delay is already behind it
## (a mine a joiner first hears of mid-job).
static func spawn(root_node: Node, weapon: WeaponDefScript, at: Vector3, surface: Vector3, id: int, owner: int, left: int, deciding: bool, armed: bool = false, judged: Callable = Callable()) -> Node3D:
	var mine = load("res://scripts/weapons/cron_mine.gd").new()
	mine.name = "CronMine%d" % id
	mine.def = weapon
	mine.mine_id = id
	mine.owner_id = owner
	mine.normal = surface.normalized() if surface.length() > 0.0 else Vector3.UP
	mine.authoritative = deciding
	mine.judge = judged
	mine.runs_total = left
	mine.runs_left = left
	mine.next_at = weapon.run_interval_s if armed else weapon.arm_s
	field_of(root_node).add_child(mine)
	mine.global_position = at
	mine.build()
	return mine


## The node under `root_node` that holds its volleys and mines, made on first use.
static func field_of(root_node: Node) -> Node3D:
	var field := root_node.get_node_or_null(FIELD) as Node3D
	if field == null:
		field = Node3D.new()
		field.name = FIELD
		root_node.add_child(field)
	return field


## Where a mine aimed from `eye` along `aim` sticks, in `space` (world space): on the first piece
## of the level within `range_m`, a hair off its face, or with none in reach on the floor under
## `body` (the placer's middle), or at its feet. {at, normal}.
static func place(space: PhysicsDirectSpaceState3D, eye: Vector3, aim: Vector3, range_m: float, body: Vector3, feet_m: float) -> Dictionary:
	var ahead := PhysicsRayQueryParameters3D.create(eye, eye + aim.normalized() * range_m, 1)
	var hit := space.intersect_ray(ahead)
	if not hit.is_empty():
		var face: Vector3 = hit["normal"] if not (hit["normal"] as Vector3).is_zero_approx() else -aim.normalized()
		return {"at": (hit["position"] as Vector3) + face * STUD_LIFT_M, "normal": face}
	var down := PhysicsRayQueryParameters3D.create(body, body + Vector3.DOWN * (feet_m + FEET_REACH_M), 1)
	var floor := space.intersect_ray(down)
	if not floor.is_empty():
		return {"at": (floor["position"] as Vector3) + Vector3.UP * STUD_LIFT_M, "normal": Vector3.UP}
	return {"at": body + Vector3.DOWN * feet_m, "normal": Vector3.UP}


## A mine sits this far off the face it stuck to, so it and its blasts are on this side of it.
const STUD_LIFT_M := 0.05
## Below the feet a floor is still looked for this far down.
const FEET_REACH_M := 0.5


func _ready() -> void:
	add_to_group(GROUP)


## The stud, its countdown ring, its schedule text and (deciding) its hit volume.
func build() -> void:
	var hex := CylinderMesh.new()
	hex.radial_segments = 6
	hex.rings = 1
	hex.top_radius = def.mine_radius_m
	hex.bottom_radius = def.mine_radius_m
	hex.height = def.mine_radius_m * STUD_THICKNESS
	_stud_glow = Palette.glow(def.skin_body(), STUD_ENERGY)
	_stud = MeshInstance3D.new()
	_stud.mesh = hex
	_stud.material_override = _stud_glow
	_stud.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_stud)
	var torus := TorusMesh.new()
	torus.inner_radius = def.blast_radius_m * (1.0 - RING_BAND)
	torus.outer_radius = def.blast_radius_m
	torus.rings = 48
	torus.ring_segments = 6
	_countdown = MeshInstance3D.new()
	_countdown.mesh = torus
	_countdown.material_override = Palette.unlit_glow(def.skin_body(), RING_ENERGY * 0.5)
	_countdown.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_countdown)
	# The stud and its ring lie flat on the surface it stuck to: their up turned onto its normal.
	_flat = Basis(Quaternion(Vector3.UP, normal)) if normal.dot(Vector3.UP) > -0.999 else Basis(Vector3.RIGHT, PI)
	_stud.basis = _flat
	_countdown.basis = _flat
	_label = Label3D.new()
	_label.font = Palette.mono_font()
	_label.font_size = LABEL_FONT
	_label.pixel_size = LABEL_PIXEL
	_label.outline_size = 8
	_label.modulate = def.skin_body()
	_label.outline_modulate = Palette.VOID
	_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_label.position = normal * LABEL_LIFT_M
	add_child(_label)
	if authoritative:
		_body = StaticBody3D.new()
		_body.collision_layer = MINE_LAYER
		_body.collision_mask = 0
		_body.set_meta(MINE_ID_META, mine_id)
		_body.set_meta(MINE_OWNER_META, owner_id)
		var shape := CollisionShape3D.new()
		var sphere := SphereShape3D.new()
		sphere.radius = def.mine_hit_radius_m
		shape.shape = sphere
		_body.add_child(shape)
		add_child(_body)
	_show()


## The schedule as the text over the stud shows it ("*/2s x3").
func schedule_text() -> String:
	return _label.text if _label != null else ""


## The countdown ring's share of the blast's radius now, from 1 just after a run to 0 at the next.
func countdown() -> float:
	return _countdown.basis.get_scale().x if _countdown != null and _countdown.visible else 0.0


## True while the stud is brightened for the run about to come.
func brightened() -> bool:
	return _stud_glow != null and _stud_glow.emission_energy_multiplier > STUD_ENERGY


## The hit volume's RID: what a shooter's own rays pass by. An empty RID on a mine that only draws.
func hit_rid() -> RID:
	return _body.get_rid() if _body != null else RID()


## True while the job is still on.
func running() -> bool:
	return not _done and why == ""


func _physics_process(delta: float) -> void:
	if _done:
		return
	if why != "":
		_fading -= delta
		var share := clampf(_fading / def.fade_s, 0.0, 1.0)
		_stud.scale = Vector3.ONE * share
		_label.modulate.a = share
		if _fading <= 0.0:
			_done = true
			finished.emit(why)
			queue_free()
		return
	age += delta
	if authoritative:
		if age >= next_at - TIME_EPS:
			_run(global_position)
	elif age >= next_at + def.run_interval_s + def.blast_wait_s and runs_left <= 1:
		_end(DONE)  # the word of its last run never came, a whole interval past the guess
	_show()


## The host's word of a run of this mine at `at` (world space), on a mine that only draws:
## `left` runs still to come after it.
func apply_run(left: int, at: Vector3) -> void:
	if authoritative or not running() or not at.is_finite():
		return
	_run(at, left)


## The job ends now (`reason`: CRONTAB, SHOT or GONE): no run more, the stud fades out.
func remove(reason: String) -> void:
	if not running():
		return
	_end(reason)


func _run(at: Vector3, left: int = -1) -> void:
	runs_left = (runs_left - 1) if left < 0 else clampi(left, 0, runs_left)
	run_ages.append(age)
	next_at = age + def.run_interval_s
	_ring(at)
	if authoritative and judge.is_valid():
		judge.call(at)
	ran.emit(runs_left, at)
	if runs_left <= 0:
		_end(DONE)
	else:
		_show()


func _end(reason: String) -> void:
	why = reason
	_fading = def.fade_s
	_countdown.visible = false
	if _body != null:
		_body.queue_free()
		_body = null
	_show()


## The ring closing toward the next run, the stud's brighten before it, and the schedule text.
func _show() -> void:
	_label.text = SCHEDULE % [_seconds(def.run_interval_s), runs_left]
	if why != "":
		return
	var wait := def.arm_s if run_ages.is_empty() else def.run_interval_s
	var to_go := maxf(next_at - age, 0.0)
	var share := clampf(to_go / wait, 0.0, 1.0) if wait > 0.0 else 0.0
	_countdown.basis = _flat.scaled(Vector3.ONE * maxf(share, COUNTDOWN_LEAST))
	_countdown.visible = share > 0.0
	_stud_glow.emission_energy_multiplier = BRIGHT_ENERGY if to_go <= def.telegraph_s else STUD_ENERGY


## The run's blast ring at `at`, growing out to the blast's radius and fading over blast_ring_s.
## Not a child of the mine, so it outlives it by blast_ring_s at most.
func _ring(at: Vector3) -> void:
	# Debris thrown out of the run's blast (A4), from the arena's particle pool.
	var fx := ParticleFx.of(self)
	if fx != null:
		fx.blast(at, def.skin_beam(), def.blast_radius_m)
	var torus := TorusMesh.new()
	torus.inner_radius = def.blast_radius_m * (1.0 - RING_BAND)
	torus.outer_radius = def.blast_radius_m
	torus.rings = 48
	torus.ring_segments = 6
	var mat := Palette.unlit_glow(def.skin_beam(), RING_ENERGY)
	var ring := MeshInstance3D.new()
	ring.name = "CronRing"
	ring.mesh = torus
	ring.material_override = mat
	ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	ring.add_to_group(RING_GROUP)
	get_parent().add_child(ring)
	ring.global_position = at
	ring.basis = _flat.scaled(Vector3.ONE * RING_START)
	var tween := ring.create_tween()
	tween.set_parallel(true)
	tween.tween_property(ring, "scale", Vector3.ONE, def.blast_ring_s)
	tween.tween_property(mat, "albedo_color:a", 0.0, def.blast_ring_s)
	tween.chain().tween_callback(ring.queue_free)


## Seconds as the schedule writes them: "2" for 2.0, "1.5" for 1.5.
static func _seconds(s: float) -> String:
	return str(int(s)) if is_equal_approx(s, roundf(s)) else str(snappedf(s, 0.1))
