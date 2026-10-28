extends RefCounted
## Short-lived visual effects for every hitscan weapon (the terminal cannon first, then
## SIGTERM's pellets): beam, muzzle flash and its light, impact flash and sparks. Every
## tunable comes from the weapon's resource and every colour from palette.gd, through the
## weapon's light skin (C16); plain WeaponTuning gets the cannon's teal and mint. Each
## effect frees itself when its lifetime ends.
## Effects are cosmetic only and never touch anything outside the game.

const Palette = preload("res://scripts/palette.gd")
const Weapon = preload("res://scripts/weapon_tuning.gd")

## Every effect node joins this group, so tests can count what is still alive.
const FX_GROUP := &"cannon_fx"

# Geometry, not tunables.
const HALF := 0.5
const QUARTER_TURN := PI / 2.0
const NEAR_PARALLEL := 0.98
const SPHERE_HEIGHT_PER_RADIUS := 2.0


## Thin glowing beam from the barrel to where the shot ended, fading out.
static func spawn_beam(root: Node, start: Vector3, finish: Vector3, w: Weapon) -> void:
	var length := start.distance_to(finish)
	if length < w.beam_min_length:
		return
	var pivot := _effect_root(root, "CannonBeam")
	pivot.global_position = start.lerp(finish, HALF)
	var dir := (finish - start) / length
	var up := Vector3.UP if absf(dir.dot(Vector3.UP)) < NEAR_PARALLEL else Vector3.RIGHT
	pivot.look_at(finish, up)
	var cyl := CylinderMesh.new()
	cyl.top_radius = w.beam_radius
	cyl.bottom_radius = w.beam_radius
	cyl.height = length
	cyl.radial_segments = w.beam_sides
	var mat := Palette.unlit_glow(_beam_color(w), w.beam_energy)
	var beam := _mesh(cyl, mat)
	beam.rotation.x = QUARTER_TURN  # cylinder axis Y onto the pivot's -Z
	pivot.add_child(beam)
	var tween := pivot.create_tween()
	tween.tween_property(mat, "albedo_color:a", 0.0, w.beam_lifetime)
	tween.tween_callback(pivot.queue_free)


## Bright neon burst at the barrel plus a light, both gone in a blink.
static func spawn_muzzle_flash(muzzle: Node3D, w: Weapon, tint: Color = Color.TRANSPARENT) -> void:
	var flash := _effect_root(muzzle, "MuzzleFlash")
	var sphere := SphereMesh.new()
	sphere.radius = w.muzzle_flash_radius
	sphere.height = w.muzzle_flash_radius * SPHERE_HEIGHT_PER_RADIUS
	# `tint`, when given (root's red while overcharged, C22), colours the flash and its light.
	var tinted := tint.a > 0.0
	var mat := Palette.unlit_glow(tint if tinted else _beam_color(w), w.muzzle_flash_energy)
	flash.add_child(_mesh(sphere, mat))
	var light := OmniLight3D.new()
	light.light_color = tint if tinted else _body_color(w)
	light.light_energy = w.muzzle_light_energy
	light.omni_range = w.muzzle_light_range
	light.shadow_enabled = false
	flash.add_child(light)
	var tween := flash.create_tween()
	tween.set_parallel(true)
	tween.tween_property(mat, "albedo_color:a", 0.0, w.muzzle_flash_lifetime)
	tween.tween_property(light, "light_energy", 0.0, w.muzzle_flash_lifetime)
	tween.chain().tween_callback(flash.queue_free)


## Flash and spark burst where the shot landed. The node's +Y points along the surface
## normal, so the sparks fly off the surface. Hostile hits spark amber, the world in the
## weapon's beam colour (mint for the cannon).
static func spawn_impact(root: Node, point: Vector3, normal: Vector3, hostile: bool, w: Weapon) -> void:
	var impact := _effect_root(root, "CannonImpact")
	impact.global_transform = Transform3D(_basis_with_up(normal), point)
	var color := Palette.HOSTILE_AMBER if hostile else _beam_color(w)

	var sphere := SphereMesh.new()
	sphere.radius = w.impact_flash_radius
	sphere.height = w.impact_flash_radius * SPHERE_HEIGHT_PER_RADIUS
	var flash_mat := Palette.unlit_glow(color, w.impact_flash_energy)
	var flash := _mesh(sphere, flash_mat)
	impact.add_child(flash)

	var sparks := CPUParticles3D.new()
	sparks.name = "Sparks"
	sparks.one_shot = true
	sparks.explosiveness = 1.0
	sparks.amount = w.spark_count
	sparks.lifetime = w.spark_lifetime
	sparks.direction = Vector3.UP
	sparks.spread = w.spark_spread_degrees
	sparks.initial_velocity_min = w.spark_speed_min
	sparks.initial_velocity_max = w.spark_speed_max
	sparks.gravity = Vector3.DOWN * w.spark_gravity
	var spark_mesh := BoxMesh.new()
	spark_mesh.size = Vector3.ONE * w.spark_size
	sparks.mesh = spark_mesh
	var spark_mat := Palette.unlit_glow(color, w.spark_energy)
	spark_mat.vertex_color_use_as_albedo = true
	sparks.material_override = spark_mat
	sparks.color_ramp = Palette.fade_out_ramp()
	sparks.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	impact.add_child(sparks)
	sparks.emitting = true

	var tween := impact.create_tween()
	tween.set_parallel(true)
	tween.tween_property(flash, "scale", Vector3.ONE * w.impact_flash_grow, w.impact_flash_lifetime)
	tween.tween_property(flash_mat, "albedo_color:a", 0.0, w.impact_flash_lifetime)
	tween.chain().tween_interval(maxf(w.spark_lifetime - w.impact_flash_lifetime, 0.0))
	tween.chain().tween_callback(impact.queue_free)


## The weapon's light skin colours; the cannon's for a plain WeaponTuning.
static func _beam_color(w: Weapon) -> Color:
	return w.call("skin_beam") if w.has_method("skin_beam") else Palette.MINT


static func _body_color(w: Weapon) -> Color:
	return w.call("skin_body") if w.has_method("skin_body") else Palette.TEAL


static func _effect_root(parent: Node, effect_name: String) -> Node3D:
	var node := Node3D.new()
	node.name = effect_name
	node.add_to_group(FX_GROUP)
	parent.add_child(node)
	return node


static func _mesh(mesh: Mesh, mat: Material) -> MeshInstance3D:
	var instance := MeshInstance3D.new()
	instance.mesh = mesh
	instance.material_override = mat
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return instance


## Right-handed basis whose +Y is `up`.
static func _basis_with_up(up: Vector3) -> Basis:
	var y := up.normalized()
	var ref := Vector3.FORWARD if absf(y.dot(Vector3.FORWARD)) < NEAR_PARALLEL else Vector3.RIGHT
	var x := ref.cross(y).normalized()
	var z := x.cross(y)
	return Basis(x, y, z)
