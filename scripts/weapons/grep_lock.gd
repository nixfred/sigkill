extends Node3D
## grep's marks (C25): which targets this player has marked, and the lock building on the next.
## The player makes it as a child and steps it every physics step while grep is in hand, on the
## player's own time; it reads the scene and changes nothing in it.
##
## A lock builds while the aim is held (or toggled, per the settings) on the one target nearest
## the crosshair that is inside the weapon's narrow lock cone, within its lock range and with
## nothing of the level between the eyes and the target's middle; the crosshair moving to
## another target, or this one leaving any of the three, starts it again from nothing. A full
## lock (lock_s; root builds it root_lock_speed times as fast) marks the target, up to
## max_marks at once (root_max_marks while root). A mark stays while its target is in sight
## (inside the sight cone of the crosshair, nothing of the level in between) and in range, or
## out of either for no longer than lock_grace_s; it drops at once when its target derezzes or
## goes away (an avatar freed when its player leaves the match), and every mark drops when the
## weapon is put away, at a death and at a respawn. A target is held untyped and checked
## valid before any typed use: Godot refuses a freed object to a typed variable or argument. Root ending
## with more marks than a user holds drops the newest. A shot spends every mark.
##
## Targets are this player's enemies, as code-rain vision has them: alone, the living dummies of
## its own arena; in a match, the other players' living avatars, each with its player id, which
## the shot claims to the host. Nothing is sent from here.
##
## Cosmetic fiction: nothing is searched, matched or run.

const WeaponDefScript = preload("res://scripts/weapons/weapon_def.gd")
## A daemon's middle, above its feet: where a lock looks at it and a dart flies to.
const DUMMY_MIDDLE_M := 0.9
const TARGET_GROUP := "targets"
## What blocks a lock and a mark's sight: the level.
const SIGHT_MASK := 1
## A lock counts as full within this many seconds: float sums of steps.
const LOCK_EPS := 0.000001
## Why a mark dropped.
const SIGHT := "sight"
const DEREZZ := "derezz"
const GONE := "gone"
const PUT_AWAY := "put_away"
const ROOT_OVER := "root_over"

## A target was marked.
signal marked(target: Node3D)
## A mark dropped, and why (one of the reasons above), not counting a shot spending it.
signal dropped(why: String)

## The session beside the arena (scripts/net/net_session.gd), set by it when it attaches: in a
## match the targets are the other players' avatars.
var session: Node = null
## The marks, oldest first: {target, id (a player id, 0 for a dummy), lost_s}.
var marks: Array = []
## The target a lock is building on, or null, and the seconds of it built so far (at user's
## pace: root's adds root_lock_speed for each second).
var locking: Node3D = null
var built_s := 0.0
## Marks dropped by reason, for the tests.
var drops := {}

var _def: WeaponDefScript


## One physics step of `delta` seconds with `weapon` (grep) in hand: the eyes at `eye`, the
## crosshair along `forward` (world space), `aiming` whether a lock may build, `root` whether
## C22's root is on.
func step(delta: float, weapon: WeaponDefScript, eye: Vector3, forward: Vector3, aiming: bool, root: bool) -> void:
	_def = weapon
	var ahead := forward.normalized()
	for m in marks.duplicate():
		var target = m["target"]
		if not is_instance_valid(target):
			_drop(m, GONE)
		elif not alive(target):
			_drop(m, DEREZZ)
		elif _seen(target, eye, ahead, _def.sight_cone_degrees):
			m["lost_s"] = 0.0
		else:
			m["lost_s"] += delta
			if m["lost_s"] > _def.lock_grace_s:
				_drop(m, SIGHT)
	var cap := _def.marks_for(root)
	while marks.size() > cap:
		_drop(marks[-1], ROOT_OVER)
	if not aiming or marks.size() >= cap:
		_restart(null)
		return
	var best := _nearest_to_crosshair(eye, ahead)
	if best != locking:
		_restart(best)
	if locking == null:
		return
	built_s += delta * _def.lock_speed(root)
	if built_s >= _def.lock_s - LOCK_EPS:
		var target := locking
		marks.append({"target": target, "id": int(target.get("player_id")) if target.get("player_id") != null else 0, "lost_s": 0.0})
		_restart(null)
		marked.emit(target)


## How far the lock building now has come, from 0 to 1; 0 when none is building.
func progress() -> float:
	if locking == null or _def == null:
		return 0.0
	return clampf(built_s / _def.lock_s, 0.0, 1.0)


func count() -> int:
	return marks.size()


## True when `target` is marked.
func has_mark(target: Node3D) -> bool:
	for m in marks:
		if m["target"] == target:
			return true
	return false


## The marked targets' player ids, oldest first: what a shot in a match claims.
func claims() -> PackedInt32Array:
	var out := PackedInt32Array()
	for m in marks:
		out.append(m["id"])
	return out


## Every mark, oldest first, emptied: a shot spends them.
func spend() -> Array:
	var out := marks.duplicate()
	marks.clear()
	_restart(null)
	return out


## Every mark dropped (`why`) and no lock building: the weapon put away, a death, a respawn.
func clear(why: String = PUT_AWAY) -> void:
	for m in marks.duplicate():
		_drop(m, why)
	_restart(null)


## Where `target`'s middle is now (world space): a dummy's above its feet, an avatar's where its
## body is. `target` must be valid.
static func point_of(target: Node3D) -> Vector3:
	return target.global_position + (Vector3.UP * DUMMY_MIDDLE_M if target.is_in_group(TARGET_GROUP) else Vector3.ZERO)


## A dart's mark: where `target`'s middle is while it lives, a non-finite vector once it is gone
## (derezzed, or freed: untyped, so a freed target is no error).
static func mark_point(target) -> Vector3:
	return point_of(target) if alive(target) else Vector3.INF


## True while `target` may be marked or stay marked: a living dummy, or a shown avatar not
## derezzed. Untyped: a freed target is simply not alive.
static func alive(target) -> bool:
	if not is_instance_valid(target) or not (target is Node3D) or not target.is_inside_tree():
		return false
	if target.is_in_group(TARGET_GROUP):
		return not target.has_method("is_alive") or target.call("is_alive")
	return target.visible and not target.get("dead")


## This player's enemies: alone, the living target dummies of its own arena; in a match, the
## other players' living avatars.
func enemies() -> Array[Node3D]:
	var out: Array[Node3D] = []
	if session != null and is_instance_valid(session) and session.has_method("is_online") and session.is_online():
		for avatar in session.avatars.values():
			if avatar is Node3D and alive(avatar):
				out.append(avatar)
		return out
	var player := get_parent()
	var arena: Node = player.get_parent() if player != null else null
	if arena == null:
		return out
	for body in get_tree().get_nodes_in_group(TARGET_GROUP):
		if body is Node3D and arena.is_ancestor_of(body) and alive(body):
			out.append(body)
	return out


## The unmarked enemy nearest the crosshair inside the lock cone, in range and in sight, or null.
func _nearest_to_crosshair(eye: Vector3, ahead: Vector3) -> Node3D:
	var best: Node3D = null
	var best_angle := INF
	for target in enemies():
		if has_mark(target):
			continue
		var to := point_of(target) - eye
		var angle := rad_to_deg(ahead.angle_to(to))
		if angle <= _def.lock_cone_degrees and angle < best_angle and _seen(target, eye, ahead, _def.lock_cone_degrees):
			best = target
			best_angle = angle
	return best


## True when `target` is within `cone` degrees of the crosshair, within lock range, and nothing
## of the level stands between the eyes and its middle.
func _seen(target: Node3D, eye: Vector3, ahead: Vector3, cone: float) -> bool:
	var at := point_of(target)
	var to := at - eye
	if to.length() > _def.lock_range_m or rad_to_deg(ahead.angle_to(to)) > cone:
		return false
	var query := PhysicsRayQueryParameters3D.create(eye, at, SIGHT_MASK)
	return get_world_3d().direct_space_state.intersect_ray(query).is_empty()


func _restart(target: Node3D) -> void:
	locking = target
	built_s = 0.0


func _drop(m: Dictionary, why: String) -> void:
	marks.erase(m)
	drops[why] = drops.get(why, 0) + 1
	dropped.emit(why)
