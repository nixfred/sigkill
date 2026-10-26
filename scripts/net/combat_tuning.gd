class_name CombatTuning
extends Resource
## Every number of synced combat (C14, scripts/net/combat.gd): a player's health, how long
## death lasts and how long a fresh spawn is safe, how strictly the host checks a shot,
## and how the kill feed and the damage flash show. The default instance is
## resources/combat.tres. The cannon's damage, range and fire rate stay in WeaponTuning
## (resources/terminal_cannon.tres): there is one weapon, and this reuses it. Units are
## seconds, metres, health points and entries.

@export_group("Health")
## What every player spawns with. The cannon takes WeaponTuning.damage off it per hit.
@export var max_health: float = 100.0

@export_group("Respawn")
## Time from death to the host's respawn.
@export var respawn_delay_s: float = 3.0
## Time after a respawn during which the player takes no damage.
@export var spawn_protection_s: float = 2.0

@export_group("Validation")
## The host accepts a shot this share of the weapon's cooldown early, for network jitter.
## 0.25 with a 0.16 s cooldown means shots at least 0.12 s apart.
@export var fire_rate_tolerance: float = 0.25
## How far a shot's origin may be from the host's view of the shooter's eye: the newest
## position it received plus the eye height, which lags the shooter by up to one send
## interval and the network's delay.
@export var origin_tolerance_m: float = 1.5

@export_group("Feedback")
## Most kills shown at once.
@export var kill_feed_length: int = 4
## How long a kill stays in the feed.
@export var kill_feed_fade_s: float = 6.0
## How long the screen flashes when this player is hit.
@export var damage_flash_s: float = 0.25

const HEALTH_FIRST := 1.0
const HEALTH_LAST := 100000.0
const DELAY_FIRST_S := 0.1
const DELAY_LAST_S := 60.0
const PROTECT_LAST_S := 60.0
const TOLERANCE_LAST := 0.9
const ORIGIN_FIRST_M := 0.1
const ORIGIN_LAST_M := 20.0
const FEED_FIRST := 1
const FEED_LAST := 20
const FADE_FIRST_S := 0.5
const FADE_LAST_S := 120.0
const FLASH_LAST_S := 5.0


## Everything wrong with these values, or empty when they are safe to use.
func problems() -> PackedStringArray:
	var out := PackedStringArray()
	if not is_finite(max_health) or max_health < HEALTH_FIRST or max_health > HEALTH_LAST:
		out.append("max_health must be between %s and %s" % [HEALTH_FIRST, HEALTH_LAST])
	if not is_finite(respawn_delay_s) or respawn_delay_s < DELAY_FIRST_S or respawn_delay_s > DELAY_LAST_S:
		out.append("respawn_delay_s must be between %s and %s" % [DELAY_FIRST_S, DELAY_LAST_S])
	if not is_finite(spawn_protection_s) or spawn_protection_s < 0.0 or spawn_protection_s > PROTECT_LAST_S:
		out.append("spawn_protection_s must be between 0 and %s" % PROTECT_LAST_S)
	if not is_finite(fire_rate_tolerance) or fire_rate_tolerance < 0.0 or fire_rate_tolerance > TOLERANCE_LAST:
		out.append("fire_rate_tolerance must be between 0 and %s" % TOLERANCE_LAST)
	if not is_finite(origin_tolerance_m) or origin_tolerance_m < ORIGIN_FIRST_M or origin_tolerance_m > ORIGIN_LAST_M:
		out.append("origin_tolerance_m must be between %s and %s" % [ORIGIN_FIRST_M, ORIGIN_LAST_M])
	if kill_feed_length < FEED_FIRST or kill_feed_length > FEED_LAST:
		out.append("kill_feed_length must be between %d and %d" % [FEED_FIRST, FEED_LAST])
	if not is_finite(kill_feed_fade_s) or kill_feed_fade_s < FADE_FIRST_S or kill_feed_fade_s > FADE_LAST_S:
		out.append("kill_feed_fade_s must be between %s and %s" % [FADE_FIRST_S, FADE_LAST_S])
	if not is_finite(damage_flash_s) or damage_flash_s < 0.0 or damage_flash_s > FLASH_LAST_S:
		out.append("damage_flash_s must be between 0 and %s" % FLASH_LAST_S)
	return out
