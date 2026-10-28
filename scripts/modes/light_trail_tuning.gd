class_name LightTrailTuning
extends Resource
## Every number of light-trail mode (C20, PRD 5.2: "your path leaves a solid neon wall,
## Tron deathmatch"): how often a wall is laid behind a player, its size, how long it stands
## and fades, the cap per player, the grace on a player's own newest wall, and what counts as
## on the ground. The default instance is resources/light_trail.tres; scripts/modes/
## light_trails.gd lays, ages, draws and judges the walls by these numbers. Units are metres
## and seconds. The touching body is the player's own capsule (radius 0.4 m, 1.8 m tall), the
## same one remote avatars carry (scripts/net/remote_player.gd).

@export_group("Laying")
## A new wall segment every this much ground travel.
@export var spacing_m: float = 0.5
## A move longer than this between two looks at a player (a respawn, a teleport, a late
## sample) starts a new wall there instead of laying one across the gap.
@export var segment_last_m: float = 2.5
## The level this far below a player's feet, or nearer, counts as the ground under them;
## further, the player is airborne and lays nothing.
@export var ground_slack_m: float = 0.15

@export_group("Wall")
## Each segment's height from the ground it was laid on, and its thickness.
@export var height_m: float = 1.2
@export var thickness_m: float = 0.08
## How long a segment stands, the fade at its end included, then it is gone.
@export var lifetime_s: float = 6.0
@export var fade_s: float = 0.75
## Segments one player's trail holds at most; laying past it drops that player's oldest.
@export var cap: int = 64

@export_group("Grace")
## A player's own segments younger than this never touch that player (its newest never
## does, whatever its age), so the wall being laid right now is never the one that kills.
@export var grace_s: float = 0.4

@export_group("Look")
## How far above full brightness the wall's colour is pushed, so bloom picks it up.
@export var energy: float = 2.4

const SPACING_FIRST_M := 0.1
const SPACING_LAST_M := 5.0
const SEGMENT_LAST_M := 20.0
const SLACK_LAST_M := 2.0
const HEIGHT_LAST_M := 10.0
const THICKNESS_LAST_M := 1.0
const LIFETIME_FIRST_S := 0.5
const LIFETIME_LAST_S := 60.0
const CAP_LAST := 256
const GRACE_LAST_S := 5.0
const ENERGY_LAST := 10.0


## Everything wrong with these values, or empty when they are safe to use.
func problems() -> PackedStringArray:
	var out := PackedStringArray()
	if not is_finite(spacing_m) or spacing_m < SPACING_FIRST_M or spacing_m > SPACING_LAST_M:
		out.append("spacing_m must be between %s and %s" % [SPACING_FIRST_M, SPACING_LAST_M])
	if not is_finite(segment_last_m) or segment_last_m < spacing_m or segment_last_m > SEGMENT_LAST_M:
		out.append("segment_last_m must be between spacing_m and %s" % SEGMENT_LAST_M)
	if not is_finite(ground_slack_m) or ground_slack_m < 0.0 or ground_slack_m > SLACK_LAST_M:
		out.append("ground_slack_m must be between 0 and %s" % SLACK_LAST_M)
	if not is_finite(height_m) or height_m <= 0.0 or height_m > HEIGHT_LAST_M:
		out.append("height_m must be above 0 and at most %s" % HEIGHT_LAST_M)
	if not is_finite(thickness_m) or thickness_m <= 0.0 or thickness_m > THICKNESS_LAST_M:
		out.append("thickness_m must be above 0 and at most %s" % THICKNESS_LAST_M)
	if not is_finite(lifetime_s) or lifetime_s < LIFETIME_FIRST_S or lifetime_s > LIFETIME_LAST_S:
		out.append("lifetime_s must be between %s and %s" % [LIFETIME_FIRST_S, LIFETIME_LAST_S])
	if not is_finite(fade_s) or fade_s < 0.0 or fade_s > lifetime_s:
		out.append("fade_s must be between 0 and lifetime_s")
	if cap < 1 or cap > CAP_LAST:
		out.append("cap must be between 1 and %d" % CAP_LAST)
	if not is_finite(grace_s) or grace_s < 0.0 or grace_s > GRACE_LAST_S:
		out.append("grace_s must be between 0 and %s" % GRACE_LAST_S)
	if not is_finite(energy) or energy <= 0.0 or energy > ENERGY_LAST:
		out.append("energy must be above 0 and at most %s" % ENERGY_LAST)
	return out
