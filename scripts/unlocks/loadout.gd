class_name Loadout
extends RefCounted
## A player's weapons as worn (C33): each of the arsenal's weapons in its chosen skin and with its mod or not.
## On the wire a loadout is its look, one byte a weapon in slot order: the skin's index in the weapon's kit
## (the low nibble; 0 its own) and MOD_BIT when its mod is on. A joiner's hello carries its own look; the host
## cleans it (clean(): an index past the kit is the weapon's own skin, a mod bit with no mod is dropped),
## clears every mod bit while its "mods" rule is off (accepted()), and every roster carries each player's
## accepted look, so every screen draws each player's shots in that player's skin and the host judges each
## player's shots with the mods it accepted. Skins are cosmetic; a mod is a sidegrade (scripts/unlocks/weapon_mod.gd).

const WeaponDefScript = preload("res://scripts/weapons/weapon_def.gd")

const SKIN_MASK := 0x0F
const MOD_BIT := 0x10


## This player's own look for `defs` (the arsenal, in slot order), from `progress`: each weapon's chosen skin
## while held, its mod while chosen and held.
static func look_of(defs: Array, progress: Progress) -> PackedByteArray:
	var out := PackedByteArray()
	for def in defs:
		var kit := WeaponKit.of(def.id)
		var index := kit.skin_index(progress.skin_of(def.id)) if kit != null else 0
		out.append(maxi(index, 0) | (MOD_BIT if progress.mod_on(def.id) else 0))
	return out


## Every weapon in its own skin with no mod.
static func stock(defs: Array) -> PackedByteArray:
	var out := PackedByteArray()
	out.resize(defs.size())
	out.fill(0)
	return out


## `look` as the host takes it for `defs`: the wrong length is every weapon stock; a skin index past the
## weapon's kit is its own skin; a mod bit for a weapon with no mod, or any other bit, is dropped.
static func clean(look: PackedByteArray, defs: Array) -> PackedByteArray:
	if look.size() != defs.size():
		return stock(defs)
	var out := PackedByteArray()
	for i in defs.size():
		var kit := WeaponKit.of(defs[i].id)
		var index := look[i] & SKIN_MASK
		var mod := (look[i] & MOD_BIT) != 0
		if kit == null or index >= kit.skins.size():
			index = 0
		out.append(index | (MOD_BIT if mod and kit != null and kit.mod != null else 0))
	return out


## `look` with every mod bit cleared unless `mods_on` (the host's rule).
static func accepted(look: PackedByteArray, mods_on: bool) -> PackedByteArray:
	if mods_on:
		return look.duplicate()
	var out := PackedByteArray()
	for b in look:
		out.append(b & SKIN_MASK)
	return out


## `def` in skin `index` of its kit, with its mod when `mod`: a copy whenever either differs from the
## weapon's own, else the weapon itself.
static func apply(def: WeaponDefScript, index: int, mod: bool) -> WeaponDefScript:
	var kit := WeaponKit.of(def.id)
	if kit == null or (index <= 0 and not mod):
		return def
	var out: WeaponDefScript = kit.mod.apply_to(def) if mod and kit.mod != null else def.duplicate()
	out.light_skin = kit.skin_at(index).skin
	return out


## `defs` worn as `look` says (a look of the wrong length: every weapon stock).
static func defs_for(defs: Array, look: PackedByteArray) -> Array:
	var clean_look := clean(look, defs)
	var out := []
	for i in defs.size():
		out.append(apply(defs[i], clean_look[i] & SKIN_MASK, (clean_look[i] & MOD_BIT) != 0))
	return out
