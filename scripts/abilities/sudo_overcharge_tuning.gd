class_name SudoOverchargeTuning
extends Resource
## Every number of root vs user and sudo overcharge (C22, PRD 5.3 "Root vs user: spawn as
## user, earn sudo for a power spike"; PRD 5.2 "sudo: power-up that unlocks overcharge on the
## current weapon"): how many kills in one life earn a sudo charge, how many a player may
## hold, how long root lasts, how much harder every weapon hits meanwhile, and the look. The
## default instance is resources/sudo_overcharge.tres; scripts/abilities/sudo_state.gd keeps
## the rules by these numbers (the player's own alone, the host's for every player in a
## match) and scripts/abilities/sudo_overcharge.gd runs the ability. Fiction only: nothing
## real is run, called or read; "user" is a fixed word, never anyone's name.

@export_group("Earning")
## Kills in one life, with no death between, that earn one sudo charge.
@export var kills_needed: int = 3
## Sudo charges a player may hold at once; kills while holding them bank nothing.
@export var max_charges: int = 1

@export_group("Root")
## Seconds of root (overcharge) a charge buys.
@export var root_s: float = 8.0
## Every weapon's damage while root, as a multiple of its own; no ammo is spent meanwhile.
@export var damage_scale: float = 1.5
## Seconds the cosmetic "[sudo] password for user: ********" line shows when it starts.
@export var password_s: float = 1.2

@export_group("Look")
## How bright the weapon in hand glows in root's red, as a multiple of its own glow.
@export var glow_scale: float = 2.0

const KILLS_LAST := 20
const CHARGES_LAST := 5
const ROOT_FIRST_S := 1.0
const ROOT_LAST_S := 60.0
const SCALE_LAST := 4.0
const PASSWORD_LAST_S := 5.0
const GLOW_LAST := 10.0


## Everything wrong with these values, or empty when they are safe to use.
func problems() -> PackedStringArray:
	var out := PackedStringArray()
	if kills_needed < 1 or kills_needed > KILLS_LAST:
		out.append("kills_needed must be between 1 and %d" % KILLS_LAST)
	if max_charges < 1 or max_charges > CHARGES_LAST:
		out.append("max_charges must be between 1 and %d" % CHARGES_LAST)
	if not is_finite(root_s) or root_s < ROOT_FIRST_S or root_s > ROOT_LAST_S:
		out.append("root_s must be between %s and %s" % [ROOT_FIRST_S, ROOT_LAST_S])
	if not is_finite(damage_scale) or damage_scale < 1.0 or damage_scale > SCALE_LAST:
		out.append("damage_scale must be between 1 and %s" % SCALE_LAST)
	if not is_finite(password_s) or password_s < 0.0 or password_s > PASSWORD_LAST_S or (is_finite(root_s) and password_s > root_s):
		out.append("password_s must be between 0 and %s, and no longer than root_s" % PASSWORD_LAST_S)
	if not is_finite(glow_scale) or glow_scale < 1.0 or glow_scale > GLOW_LAST:
		out.append("glow_scale must be between 1 and %s" % GLOW_LAST)
	return out
