class_name SwarmFlock
extends RefCounted
## A live process swarm's flock (W1, PRD 5.5): how a nest's drones fly (scripts/procs/proc_hunt.gd makes one per nest and
## steps it each physics frame, after the daemons' director has stepped every brain). Each drone is its own enemy (one
## child process, or one thread), and they move as one swarm: each on its own tilted orbit round the nest, at its own
## radius and pace, pulled toward its place, pushed off its neighbours, turning smoothly, banking into its turns; when the
## nest moves on (its own process gone, its drones orphaned) they keep to where it was.
##
## Every attack is a tell, then the dives, then a wait (C27b's rule): with its prey near and in sight of the swarm and a
## slot under the director's attacker cap, the swarm gathers (TELL_S: its orbits pulled into a tight ball over the nest,
## every light burning white, the nest's cells drawn in), then DIVERS of its drones peel off one after another, each in a
## straight dive at where its prey was as it left (dodgeable), chipping DAMAGE off a player its path passes within HIT_M
## of with nothing of the level between, once a dive, until DIVE_S is up, it has flown DIVE_PAST_M past the mark or the
## level is ahead; then they climb back into the orbit and the swarm waits (WAIT_S, divided by the difficulty's
## aggression). In practice (the director resting) it only orbits. A drone its brain holds this frame (chmod 000, a
## /dev/null hole, SIGSTOP) stays where it is. Fiction only: nothing here touches a process.

const ORBIT_LOW := 1.5
const ORBIT_HIGH := 3.1
const TIGHT_M := 0.8
const SPEED := 6.0
const STEER := 7.0
const APART_M := 0.9
const PUSH := 5.0
const LOW_OVER_FLOOR_M := 0.5
const RANGE_M := 18.0
const TELL_S := 0.75
const DIVERS := 4
const DIVE_GAP_S := 0.16
const DIVE_SPEED := 13.0
const DIVE_S := 0.8
const DIVE_PAST_M := 1.6
const HIT_M := 0.9
const DAMAGE := 4.0
const WAIT_S := 3.6
const BODY_M := 0.4
const LEVEL_MASK := 1

enum Phase { ORBIT, TELL, DIVE }

var nest: Node3D = null
## Where the swarm keeps to when its nest is gone (world space); the floor's height under it.
var centre := Vector3.ZERO
var floor_y := 0.0
var drones: Array = []
var phase := Phase.ORBIT
var phase_t := 0.0
var wait := 1.5
## For the checks: tells, dives started, dives that landed.
var tells := 0
var dives := 0
var hits := 0

var _clock := 0.0
var _seed := 0
var _state := {}
var _prey := 0
var _slot_brain: DaemonBrain = null


func _init(at_seed: int = 0) -> void:
	_seed = at_seed


## A drone joins the flock where it is now.
func add(drone: Node3D) -> void:
	if drones.has(drone):
		return
	drones.append(drone)
	var k := hash(Vector2i(_seed, drone.get_instance_id() & 0xfffffff))
	var axis := Vector3(_roll(k, 1) - 0.5, 1.6, _roll(k, 2) - 0.5).normalized()
	_state[drone.get_instance_id()] = {
		"pos": drone.global_position + Vector3.UP * BODY_M,
		"vel": Vector3.ZERO,
		"axis": axis,
		"phase": TAU * _roll(k, 3),
		"radius": lerpf(ORBIT_LOW, ORBIT_HIGH, _roll(k, 4)),
		"turn": lerpf(0.7, 1.3, _roll(k, 5)) * (1.0 if _roll(k, 6) > 0.25 else -1.0),
		"dive": -1.0, "from": Vector3.ZERO, "mark": Vector3.ZERO, "way": Vector3.ZERO, "landed": false, "queued": -1.0,
	}


func remove(drone: Node3D) -> void:
	drones.erase(drone)
	if drone != null:
		_state.erase(drone.get_instance_id())


func _roll(k: int, i: int) -> float:
	return float(hash(Vector2i(k, i)) & 0xffff) / 65535.0


## One physics step of the flock.
func step(delta: float, d: DaemonDirector) -> void:
	_clock += delta
	phase_t += delta
	_forget_gone()
	var at := centre
	if nest != null and is_instance_valid(nest) and nest.is_alive():
		var art = nest.art_node()
		at = art.anchor() if art != null and art.is_inside_tree() else nest.global_position + Vector3.UP * 0.9
		centre = at
	var runs := d != null and d.runs() and not d.practice_on()
	_step_attack(delta, d, runs, at)
	var frame := Engine.get_physics_frames()
	var tight := phase == Phase.TELL
	for drone in drones:
		var s: Dictionary = _state[drone.get_instance_id()]
		var free: bool = drone.brain != null and drone.brain.flown_frame == frame
		if not free and not drone.climbing():
			if s["dive"] >= 0.0:
				s["dive"] = -1.0  # held mid-dive: the dive is off
			continue
		var pos: Vector3 = s["pos"]
		var vel: Vector3 = s["vel"]
		var want: Vector3
		var speed := SPEED
		if s["dive"] >= 0.0 and runs:
			s["dive"] += delta
			want = s["way"] * DIVE_SPEED
			speed = DIVE_SPEED
			var next: Vector3 = pos + want * delta
			if not s["landed"] and _passes(d, pos, next):
				s["landed"] = true
				hits += 1
				d.hurt(_prey, DAMAGE, drone.brain, s["way"])
			var past: float = (next - s["from"]).dot(s["way"]) - (s["mark"] - s["from"]).length()
			if s["dive"] >= DIVE_S or past > DIVE_PAST_M or next.y < floor_y + LOW_OVER_FLOOR_M * 0.5 or not d.clear(pos, next + s["way"] * 0.4):
				s["dive"] = -1.0
			vel = want
		else:
			s["dive"] = -1.0
			s["phase"] = fposmod(s["phase"] + s["turn"] * delta * (1.8 if tight else 1.0), TAU)
			var radius: float = TIGHT_M if tight else s["radius"]
			var axis: Vector3 = s["axis"]
			var side := axis.cross(Vector3.FORWARD if absf(axis.z) < 0.9 else Vector3.RIGHT).normalized()
			var ring: Vector3 = Basis(axis, s["phase"]) * side
			var goal: Vector3 = at + ring * radius
			goal.y = maxf(goal.y, floor_y + LOW_OVER_FLOOR_M + BODY_M)
			want = (goal - pos) * 2.5
			# Apart from its neighbours.
			for other in drones:
				if other == drone:
					continue
				var o: Vector3 = _state[other.get_instance_id()]["pos"]
				var gap := pos - o
				var dist := gap.length()
				if dist > 0.001 and dist < APART_M:
					want += gap / dist * PUSH * (1.0 - dist / APART_M)
			want = want.limit_length(speed * (1.6 if tight else 1.0))
			vel = vel.lerp(want, clampf(STEER * delta, 0.0, 1.0))
		var turn_v := vel - (s["vel"] as Vector3)
		pos += vel * delta
		pos.y = maxf(pos.y, floor_y + LOW_OVER_FLOOR_M * 0.5 + BODY_M * 0.5)
		s["pos"] = pos
		s["vel"] = vel
		drone.global_position = pos - Vector3.UP * BODY_M
		var flat := Vector3(vel.x, 0.0, vel.z)
		if flat.length() > 0.2:
			drone.rotation.y = lerp_angle(drone.rotation.y, atan2(-flat.x, -flat.z), clampf(10.0 * delta, 0.0, 1.0))
		var art = drone.art_node()
		if art != null:
			var lateral: float = drone.global_transform.basis.x.dot(turn_v) / maxf(delta, 0.001)
			art.set("bank", lerpf(float(art.get("bank")), clampf(-lateral * 0.05, -0.8, 0.8), clampf(6.0 * delta, 0.0, 1.0)))
			art.set("pace", clampf(vel.length() / SPEED, 0.0, 1.0))
			art.drive(DaemonArt.Act.STRIKE if s["dive"] >= 0.0 else (DaemonArt.Act.TELL if tight else DaemonArt.Act.MOVE), clampf(phase_t / TELL_S, 0.0, 1.0) if tight else 0.0)


## The swarm's attack: its wait, its tell, its dives one after another.
func _step_attack(delta: float, d: DaemonDirector, runs: bool, at: Vector3) -> void:
	var nest_art = nest.art_node() if nest != null and is_instance_valid(nest) and nest.is_alive() else null
	if not runs:
		_end_attack(d)
		if nest_art != null:
			nest_art.drive(DaemonArt.Act.IDLE)
		return
	match phase:
		Phase.ORBIT:
			wait -= delta
			if nest_art != null:
				nest_art.drive(DaemonArt.Act.IDLE)
			if wait > 0.0 or drones.is_empty():
				return
			var prey := _prey_for(d, at)
			var slot_brain := _brain_for_slot()
			if prey == 0 or slot_brain == null or not d.take_slot(slot_brain, prey):
				wait = 0.5
				return
			_prey = prey
			_slot_brain = slot_brain
			phase = Phase.TELL
			phase_t = 0.0
			tells += 1
		Phase.TELL:
			if nest_art != null:
				nest_art.drive(DaemonArt.Act.TELL, phase_t / TELL_S)
			if phase_t >= TELL_S:
				phase = Phase.DIVE
				phase_t = 0.0
				var n := 0
				for drone in drones:
					if n >= DIVERS:
						break
					if drone.is_alive() and drone.brain != null and drone.brain.flown_frame == Engine.get_physics_frames():
						_state[drone.get_instance_id()]["queued"] = float(n) * DIVE_GAP_S
						n += 1
		Phase.DIVE:
			if nest_art != null:
				nest_art.drive(DaemonArt.Act.STRIKE, clampf(phase_t / 0.6, 0.0, 1.0))
			var flying := false
			for drone in drones:
				var s: Dictionary = _state[drone.get_instance_id()]
				if s["queued"] >= 0.0 and phase_t >= s["queued"]:
					s["queued"] = -1.0
					if d.prey_valid(_prey) and d.prey_attackable(_prey) and drone.is_alive():
						var from: Vector3 = s["pos"]
						var mark: Vector3 = d.prey_point(_prey)
						if d.clear(from, mark):
							s["dive"] = 0.0
							s["from"] = from
							s["mark"] = mark
							s["way"] = (mark - from).normalized()
							s["landed"] = false
							dives += 1
				flying = flying or s["dive"] >= 0.0 or s["queued"] >= 0.0
			if not flying and phase_t > 0.2:
				_end_attack(d)
				wait = WAIT_S / maxf(d.aggression(), 0.1)


func _end_attack(d: DaemonDirector) -> void:
	if _slot_brain != null and d != null:
		d.release_slot(_slot_brain)
	_slot_brain = null
	_prey = 0
	if phase != Phase.ORBIT:
		phase = Phase.ORBIT
		phase_t = 0.0
	for drone in drones:
		var s: Dictionary = _state[drone.get_instance_id()]
		s["queued"] = -1.0


## The slot's holder: the nest's brain while it stands, else a drone's.
func _brain_for_slot() -> DaemonBrain:
	if nest != null and is_instance_valid(nest) and nest.is_alive() and nest.brain != null:
		return nest.brain
	for drone in drones:
		if drone.is_alive() and drone.brain != null:
			return drone.brain
	return null


## The nearest prey within RANGE_M of the swarm that some drone can see, attackable now; 0 for none.
func _prey_for(d: DaemonDirector, at: Vector3) -> int:
	var best := 0
	var best_d := RANGE_M
	for id in d.prey_ids():
		if not d.prey_valid(id) or d.prey_hidden(id) or not d.prey_attackable(id):
			continue
		var p: Vector3 = d.prey_point(id)
		var dist := p.distance_to(at)
		if dist >= best_d:
			continue
		for drone in drones:
			if drone.is_alive() and d.clear(_state[drone.get_instance_id()]["pos"], p):
				best = id
				best_d = dist
				break
	return best


## True when a dive from `a` to `b` passes its prey within HIT_M with nothing of the level between.
func _passes(d: DaemonDirector, a: Vector3, b: Vector3) -> bool:
	if not d.prey_valid(_prey) or not d.prey_attackable(_prey):
		return false
	var p: Vector3 = d.prey_point(_prey)
	var ab := b - a
	var u := clampf((p - a).dot(ab) / maxf(ab.length_squared(), 0.000001), 0.0, 1.0)
	var near := a + ab * u
	return near.distance_to(p) <= HIT_M and d.clear(near, p)


func _forget_gone() -> void:
	for drone in drones.duplicate():
		if not is_instance_valid(drone) or drone.is_queued_for_deletion():
			drones.erase(drone)
	for iid in _state.keys():
		var found := false
		for drone in drones:
			if drone.get_instance_id() == iid:
				found = true
				break
		if not found:
			_state.erase(iid)
