class_name DerezzTuning
extends Resource
## Every number that shapes a target dummy's derezz death and its respawn.
## The default instance is resources/derezz.tres. scripts/target_dummy.gd and
## scripts/derezz_fx.gd read only from this resource; colours come from palette.gd.
## Units are metres, seconds and degrees.

@export_group("Voxels")
## Most voxels one derezz may use. Caps the cost of every death.
@export var max_voxels: int = 160
## Edge length of each voxel cube, in metres.
@export var voxel_size: float = 0.11
## Share of voxels that glow red-hot, from 0 to 1. The rest are obsidian.
@export_range(0.0, 1.0) var glow_fraction: float = 0.55
## How much hostile red the obsidian voxels carry, from 0 (pure obsidian) to 1 (full red).
@export_range(0.0, 1.0) var obsidian_glow: float = 0.12
## Brightness of the voxels. Above 1 makes the red-hot ones bloom.
@export var glow_energy: float = 4.0

@export_group("Motion")
## Outward speed away from the body's centre, in m/s.
@export var burst_speed: float = 3.0
## Largest extra upward speed, in m/s.
@export var burst_up: float = 2.5
## Extra speed along the killing shot, in m/s.
@export var hit_push: float = 2.0
## Largest random speed added on each axis, in m/s.
@export var spread: float = 1.0
## Pull on the voxels, in m/s per second.
@export var gravity: float = 9.8
## Share of downward speed kept as a bounce when a voxel hits the ground, from 0 to 1.
@export_range(0.0, 1.0) var bounce: float = 0.3
## Share of sideways speed kept each time a voxel touches the ground, from 0 to 1.
@export_range(0.0, 1.0) var ground_friction: float = 0.6
## Physics layers the voxels land on: the world.
@export_flags_3d_physics var ground_mask: int = 1
## Slowest tumble, in degrees per second.
@export var spin_min_degrees: float = 180.0
## Fastest tumble, in degrees per second.
@export var spin_max_degrees: float = 720.0

@export_group("Fade")
## Shortest voxel life, in seconds.
@export var lifetime_min: float = 0.9
## Longest voxel life, in seconds. The effect frees itself when its last voxel is gone.
@export var lifetime_max: float = 1.4
## Shape of the shrink and fade: size and opacity follow 1 - t^power over each voxel's
## life. Above 1 holds a voxel near full size for longer, then collapses it.
@export var fade_power: float = 2.0

@export_group("Respawn")
## Seconds from the death until the dummy starts to rematerialise.
@export var respawn_delay: float = 2.5
## Seconds the dummy takes to grow back to full size. It cannot be hit until it is done.
@export var rematerialise_seconds: float = 0.4

## Highest voxel cap allowed, so a typo can never make a death stall a frame.
const MAX_VOXELS_LIMIT := 2048
## Every one of the 32 physics layers.
const PHYSICS_LAYERS_ALL := 0xFFFFFFFF
## Float fields that must be finite and 0 or more.
const NON_NEGATIVE := [
	"voxel_size", "glow_fraction", "obsidian_glow", "glow_energy", "burst_speed", "burst_up",
	"hit_push", "spread", "gravity", "bounce", "ground_friction", "spin_min_degrees",
	"spin_max_degrees", "lifetime_min", "lifetime_max", "fade_power", "respawn_delay",
	"rematerialise_seconds",
]


## One line per value that would break the derezz. Empty means usable.
## scripts/target_dummy.gd checks this on load and falls back to the built-in defaults.
func problems() -> PackedStringArray:
	var out := PackedStringArray()
	for field in NON_NEGATIVE:
		var value: float = get(field)
		if not is_finite(value) or value < 0.0:
			out.append("%s must be a finite number of 0 or more, got %s" % [field, value])
	if max_voxels < 1 or max_voxels > MAX_VOXELS_LIMIT:
		out.append("max_voxels must be between 1 and %d" % MAX_VOXELS_LIMIT)
	if voxel_size <= 0.0:
		out.append("voxel_size must be above 0")
	if glow_fraction > 1.0 or obsidian_glow > 1.0 or bounce > 1.0 or ground_friction > 1.0:
		out.append("glow_fraction, obsidian_glow, bounce and ground_friction must be between 0 and 1")
	if spin_min_degrees > spin_max_degrees:
		out.append("spin_min_degrees must not exceed spin_max_degrees")
	if lifetime_min <= 0.0 or lifetime_min > lifetime_max:
		out.append("lifetime_min must be above 0 and not exceed lifetime_max")
	if fade_power <= 0.0:
		out.append("fade_power must be above 0")
	if ground_mask < 1 or ground_mask > PHYSICS_LAYERS_ALL:
		out.append("ground_mask must name at least one of the 32 physics layers")
	return out
