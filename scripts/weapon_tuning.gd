class_name WeaponTuning
extends Resource
## Every number that shapes how the terminal cannon fires, kicks, looks and sounds.
## The default instance is resources/terminal_cannon.tres. scripts/player.gd,
## scripts/cannon_fx.gd and scripts/sfx_synth.gd read only from this resource.
## Colours come from scripts/palette.gd. Units are metres, seconds and degrees;
## "recovery" values are exponential easing rates per second.

@export_group("Firing")
## Seconds between shots.
@export var fire_cooldown: float = 0.16
## Hitscan reach, in metres.
@export var fire_range: float = 120.0
## Damage per hit. Target dummies have 1 health.
@export var damage: float = 25.0
## Physics layers the shot can hit: world and targets.
@export_flags_3d_physics var hit_mask: int = 5

@export_group("Viewmodel")
## Size of the placeholder cannon box, in metres.
@export var viewmodel_size: Vector3 = Vector3(0.09, 0.09, 0.5)
## Cannon position relative to the camera, at rest.
@export var viewmodel_offset: Vector3 = Vector3(0.22, -0.2, -0.45)
## Barrel tip relative to the camera: where the beam and the muzzle flash start.
@export var muzzle_offset: Vector3 = Vector3(0.22, -0.2, -0.7)
## Glow of the cannon body.
@export var viewmodel_glow_energy: float = 0.6
## How far the cannon jolts back on a shot, in metres.
@export var viewmodel_kick_back: float = 0.07
## How far the barrel tips up on a shot, in degrees.
@export var viewmodel_kick_pitch_degrees: float = 6.0
## Easing rate for the cannon settling back, per second.
@export var viewmodel_recovery: float = 18.0

@export_group("Recoil")
## Camera kick up per shot, in degrees.
@export var recoil_pitch_degrees: float = 1.6
## Largest random sideways kick per shot, in degrees.
@export var recoil_yaw_degrees: float = 0.6
## Cap on the stacked upward kick, in degrees.
@export var recoil_max_pitch_degrees: float = 8.0
## Cap on the stacked sideways kick, in degrees.
@export var recoil_max_yaw_degrees: float = 3.0
## Easing rate for the view settling back, per second. The shot jolt settles at it too.
@export var recoil_recovery: float = 10.0
## The screen shake of a shot (C16b): the picture jolts up to this far, in metres, and
## settles at recoil_recovery. Visual only: the camera, and so the aim, never moves. The
## settings' screen shake switch turns it off.
@export var shake_m: float = 0.004

@export_group("Beam")
## Beam thickness, in metres.
@export var beam_radius: float = 0.012
## Sides of the beam cylinder.
@export var beam_sides: int = 6
## Brightness above 1 makes the beam bloom.
@export var beam_energy: float = 3.0
## Seconds the beam takes to fade.
@export var beam_lifetime: float = 0.12
## Beams shorter than this are skipped, in metres.
@export var beam_min_length: float = 0.1

@export_group("Muzzle flash")
## Size of the flash at the barrel, in metres.
@export var muzzle_flash_radius: float = 0.07
## Brightness of the flash.
@export var muzzle_flash_energy: float = 6.0
## Seconds the flash and its light last.
@export var muzzle_flash_lifetime: float = 0.06
## Brightness of the light the flash throws.
@export var muzzle_light_energy: float = 4.0
## Reach of that light, in metres.
@export var muzzle_light_range: float = 4.0

@export_group("Impact")
## Size of the flash where the shot lands, in metres.
@export var impact_flash_radius: float = 0.09
## How much that flash swells while it fades.
@export var impact_flash_grow: float = 2.2
## Brightness of the impact flash.
@export var impact_flash_energy: float = 4.0
## Seconds the impact flash lasts.
@export var impact_flash_lifetime: float = 0.18
## Sparks per impact.
@export var spark_count: int = 24
## Seconds each spark lives.
@export var spark_lifetime: float = 0.35
## Slowest spark launch speed, in m/s.
@export var spark_speed_min: float = 3.0
## Fastest spark launch speed, in m/s.
@export var spark_speed_max: float = 7.0
## Cone around the surface normal the sparks fly in, in degrees.
@export var spark_spread_degrees: float = 55.0
## Pull on the sparks, in m/s per second.
@export var spark_gravity: float = 9.8
## Size of each spark, in metres.
@export var spark_size: float = 0.025
## Brightness of the sparks.
@export var spark_energy: float = 5.0

@export_group("Hit marker")
## Seconds the hit marker takes to fade.
@export var hit_marker_seconds: float = 0.25
## Length of each hit marker tick, in pixels.
@export var hit_marker_size: float = 9.0
## Space between the crosshair centre and each tick, in pixels.
@export var hit_marker_gap: float = 5.0
## Tick thickness, in pixels.
@export var hit_marker_thickness: float = 2.0

@export_group("Audio")
## Master volume for the cannon sounds, from 0 (silent) to 1.
@export_range(0.0, 1.0) var master_volume: float = 0.8
## Overlapping copies of each sound allowed during rapid fire.
@export var sfx_polyphony: int = 4
## Sample rate the sounds are synthesised at, in Hz.
@export var sfx_mix_rate: int = 44100
## Fade-in at the start of each sound, in seconds. Stops clicks.
@export var sfx_attack_seconds: float = 0.002
## Length of the fire zap, in seconds.
@export var fire_sfx_seconds: float = 0.14
## Fire zap starting pitch, in Hz.
@export var fire_start_hz: float = 1600.0
## Fire zap ending pitch, in Hz.
@export var fire_end_hz: float = 180.0
## How fast the fire zap dies away, per second.
@export var fire_decay: float = 22.0
## Share of noise mixed into the fire zap, from 0 to 1.
@export_range(0.0, 1.0) var fire_noise: float = 0.18
## Loudness of the fire zap before the master volume, from 0 to 1.
@export_range(0.0, 1.0) var fire_gain: float = 0.7
## Length of the hit blip, in seconds.
@export var hit_sfx_seconds: float = 0.09
## Hit blip pitch, in Hz.
@export var hit_hz: float = 2200.0
## Second hit tone as a multiple of the first.
@export var hit_second_ratio: float = 1.5
## How fast the hit blip dies away, per second.
@export var hit_decay: float = 35.0
## Loudness of the hit blip before the master volume, from 0 to 1.
@export_range(0.0, 1.0) var hit_gain: float = 0.6

## Float fields that must be finite and 0 or more.
const NON_NEGATIVE := [
	"fire_cooldown", "fire_range", "damage", "viewmodel_glow_energy", "viewmodel_kick_back",
	"viewmodel_kick_pitch_degrees", "viewmodel_recovery", "recoil_pitch_degrees",
	"recoil_yaw_degrees", "recoil_max_pitch_degrees", "recoil_max_yaw_degrees",
	"recoil_recovery", "shake_m", "beam_radius", "beam_energy", "beam_lifetime", "beam_min_length",
	"muzzle_flash_radius", "muzzle_flash_energy", "muzzle_flash_lifetime",
	"muzzle_light_energy", "muzzle_light_range", "impact_flash_radius", "impact_flash_grow",
	"impact_flash_energy", "impact_flash_lifetime", "spark_lifetime", "spark_speed_min",
	"spark_speed_max", "spark_spread_degrees", "spark_gravity", "spark_size", "spark_energy",
	"hit_marker_seconds", "hit_marker_size", "hit_marker_gap", "hit_marker_thickness",
	"master_volume", "sfx_attack_seconds", "fire_sfx_seconds", "fire_start_hz", "fire_end_hz",
	"fire_decay", "fire_noise", "fire_gain", "hit_sfx_seconds", "hit_hz", "hit_second_ratio",
	"hit_decay", "hit_gain",
]


## One line per value that would break the cannon. Empty means usable.
## scripts/player.gd checks this on load and falls back to the built-in defaults.
func problems() -> PackedStringArray:
	var out := PackedStringArray()
	for field in NON_NEGATIVE:
		var value: float = get(field)
		if not is_finite(value) or value < 0.0:
			out.append("%s must be a finite number of 0 or more, got %s" % [field, value])
	for field in ["viewmodel_size", "viewmodel_offset", "muzzle_offset"]:
		var vector: Vector3 = get(field)
		if not vector.is_finite():
			out.append("%s must be finite" % field)
	if not (viewmodel_size.x > 0.0 and viewmodel_size.y > 0.0 and viewmodel_size.z > 0.0):
		out.append("viewmodel_size must be above 0 on every axis")
	if fire_range <= 0.0:
		out.append("fire_range must be above 0")
	if hit_mask == 0:
		out.append("hit_mask must include at least one physics layer")
	if beam_sides < 3:
		out.append("beam_sides must be 3 or more")
	if spark_count < 1:
		out.append("spark_count must be 1 or more")
	if spark_lifetime <= 0.0:
		out.append("spark_lifetime must be above 0")
	if spark_speed_min > spark_speed_max:
		out.append("spark_speed_min must not exceed spark_speed_max")
	if sfx_polyphony < 1:
		out.append("sfx_polyphony must be 1 or more")
	if sfx_mix_rate < 8000 or sfx_mix_rate > 192000:
		out.append("sfx_mix_rate must be between 8000 and 192000 Hz")
	if master_volume > 1.0 or fire_gain > 1.0 or hit_gain > 1.0 or fire_noise > 1.0:
		out.append("master_volume, fire_gain, hit_gain and fire_noise must be between 0 and 1")
	if fire_start_hz <= 0.0 or fire_end_hz <= 0.0 or hit_hz <= 0.0:
		out.append("sound pitches must be above 0 Hz")
	if fire_sfx_seconds <= 0.0 or hit_sfx_seconds <= 0.0:
		out.append("sound lengths must be above 0 seconds")
	return out
