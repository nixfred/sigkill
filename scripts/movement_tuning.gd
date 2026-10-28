class_name MovementTuning
extends Resource
## Every number that shapes how the player moves and how the camera follows.
## The default instance is resources/movement_tuning.tres. scripts/player.gd reads only
## from this resource, so tuning the feel never means editing code.
## Units are metres, seconds and degrees. "Smoothing" values are exponential easing rates
## per second: higher settles faster, and the result does not depend on frame rate.

@export_group("Ground")
## Top running speed on the ground, in m/s.
@export var walk_speed: float = 7.0
## Acceleration while a move key is held, in m/s per second. Higher means snappier starts.
@export var ground_accel: float = 60.0
## Deceleration once the move keys are released, in m/s per second. Higher means shorter stops.
@export var ground_friction: float = 36.0

@export_group("Air")
## Multiplier on the project gravity. Above 1 gives a tighter, less floaty jump arc.
@export var gravity_scale: float = 1.5
## Upward speed at takeoff, in m/s.
@export var jump_velocity: float = 6.0
## Share of ground_accel available for steering in the air, from 0 to 1.
@export_range(0.0, 1.0) var air_control: float = 0.3
## Deceleration in the air with no move key held, in m/s per second.
@export var air_drag: float = 0.5

@export_group("Slide")
## Minimum ground speed for C to start a slide, in m/s.
@export var slide_min_speed: float = 4.5
## Speed added along the current direction when a slide starts, in m/s.
@export var slide_boost: float = 4.5
## Highest speed a slide can reach, in m/s.
@export var slide_max_speed: float = 12.0
## Deceleration during a slide, in m/s per second.
@export var slide_friction: float = 10.0
## A slide ends once its speed drops to this, in m/s.
@export var slide_end_speed: float = 3.5
## Longest a slide can last, in seconds.
@export var slide_max_duration: float = 0.9
## Wait after a slide ends before the next one can start, in seconds.
@export var slide_cooldown: float = 0.5
## Jumping out of a slide keeps its momentum up to this speed, in m/s.
@export var slide_jump_max_speed: float = 10.0
## Camera height above the body centre while sliding, in metres.
@export var slide_head_height: float = 0.15

@export_group("Crouch and aim")
## Camera height above the body centre while crouched (C16b, X), in metres.
@export var crouch_head_height: float = 0.35
## Top ground speed while crouched, in m/s. Never above walk_speed.
@export var crouch_speed: float = 3.5
## Aiming down the sights (right mouse) narrows the field of view to this share of it.
@export var ads_fov_scale: float = 0.7
## Right-stick look speed at full tilt, in degrees a second, before the settings' multiplier.
@export var gamepad_look_degrees: float = 150.0

@export_group("Camera")
## Camera height above the body centre when standing, in metres.
@export var stand_head_height: float = 0.7
## Easing rate for camera height changes, per second.
@export var head_height_smoothing: float = 14.0
## Mouse look speed, in radians per pixel of mouse motion.
@export var mouse_sensitivity: float = 0.0022
## How far the view can pitch up or down, in degrees.
@export var pitch_limit_degrees: float = 89.0
## Field of view at rest, in degrees.
@export var base_fov: float = 80.0
## Extra FOV at fov_full_speed and above, in degrees. No kick at walk speed or below.
@export var fov_speed_kick: float = 6.0
## Speed at which the full speed kick applies, in m/s.
@export var fov_full_speed: float = 11.0
## Extra FOV while sliding, in degrees.
@export var fov_slide_kick: float = 4.0
## Cap on the total FOV kick, in degrees.
@export var fov_max_kick: float = 9.0
## Easing rate for FOV changes, per second.
@export var fov_smoothing: float = 8.0

@export_group("Head bob")
## Turn the head bob off for motion-sickness comfort.
@export var head_bob_enabled: bool = true
## Bob cycles per second at walk speed. Slower speeds bob slower and smaller.
@export var bob_frequency: float = 1.8
## Up and down bob amplitude at walk speed, in metres.
@export var bob_vertical: float = 0.03
## Side to side bob amplitude at walk speed, in metres.
@export var bob_lateral: float = 0.015
## Side to side cycles per up and down cycle.
@export var bob_lateral_ratio: float = 0.5
## Easing rate for the bob fading in and out, per second.
@export var bob_smoothing: float = 10.0

@export_group("World")
## Falling below this height respawns the player, in metres.
@export var fall_respawn_height: float = -30.0

## Fields that must be finite and 0 or more. Negative rates would make easing diverge and
## negative frictions would speed the player up instead of slowing them down.
const NON_NEGATIVE := [
	"walk_speed", "ground_accel", "ground_friction", "gravity_scale", "jump_velocity",
	"air_control", "air_drag", "slide_min_speed", "slide_boost", "slide_max_speed",
	"slide_friction", "slide_end_speed", "slide_max_duration", "slide_cooldown",
	"slide_jump_max_speed", "slide_head_height", "crouch_head_height", "crouch_speed",
	"ads_fov_scale", "gamepad_look_degrees", "stand_head_height", "head_height_smoothing",
	"mouse_sensitivity", "pitch_limit_degrees", "base_fov", "fov_speed_kick", "fov_full_speed",
	"fov_slide_kick", "fov_max_kick", "fov_smoothing", "bob_frequency", "bob_vertical",
	"bob_lateral", "bob_lateral_ratio", "bob_smoothing",
]


## One line per value that would break the movement or the camera. Empty means usable.
## scripts/player.gd checks this on load and falls back to the built-in defaults.
func problems() -> PackedStringArray:
	var out := PackedStringArray()
	for field in NON_NEGATIVE:
		var value: float = get(field)
		if not is_finite(value) or value < 0.0:
			out.append("%s must be a finite number of 0 or more, got %s" % [field, value])
	if walk_speed <= 0.0:
		out.append("walk_speed must be above 0")
	if air_control > 1.0:
		out.append("air_control must be between 0 and 1")
	if pitch_limit_degrees >= 90.0:
		out.append("pitch_limit_degrees must be below 90")
	if base_fov <= 1.0 or base_fov + fov_max_kick >= 179.0:
		out.append("base_fov plus fov_max_kick must stay between 1 and 179 degrees")
	if ads_fov_scale < 0.2 or ads_fov_scale > 1.0:
		out.append("ads_fov_scale must be between 0.2 and 1")
	if not is_finite(fall_respawn_height):
		out.append("fall_respawn_height must be a finite number")
	return out
