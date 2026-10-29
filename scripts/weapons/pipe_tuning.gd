class_name PipeTuning
extends Resource
## Every number of pipe |, the chain beam (C30, PRD 5.2: "pipe |: chain beam that arcs between enemies"):
## how far the stream jumps from one target to the next and how many it reaches, how its damage falls
## down the chain, what a link frozen by chmod 000 does, and the pipe's buffer (its ammo). The shipped
## instance lives inside the weapon's own resource, resources/pipe_chain.tres, which names it in its pipe
## slot; the first link's damage (damage), the shot's interval (fire_cooldown) and the aim's reach
## (fire_range) are the WeaponDef's. Units are metres, seconds, KiB (the buffer's fiction) and health
## points; a share is from 0 to 1.
##
## The rules these feed: scripts/weapons/pipe_chain.gd (the chain), scripts/weapons/pipe_buffer.gd (the
## buffer). Cosmetic fiction: nothing real is piped, run or read, ever.

## The bounds of its numbers.
const JUMP_LAST_M := 30.0
const LINKS_FIRST := 2
const LINKS_LAST := 8
const FROZEN_JUMP_LAST := 3.0
const BUFFER_LAST_KIB := 1024.0
const REST_LAST_S := 5.0

@export_group("Chain")
## Metres the stream jumps from a link's middle to the next target's middle, with nothing of the level
## between them.
@export var jump_m: float = 12.0
## Targets one chain reaches at most, the first hit counted: as user, and while C22's root is on.
@export var max_links: int = 5
@export var root_max_links: int = 6
## Each link's damage as a share of the one before it.
@export var link_keep: float = 0.7

@export_group("Frozen link")
## A daemon or a piece of ICE that chmod 000 holds frozen conducts (C29): the stream passing through it
## keeps this share (all of it: it loses nothing there; the frozen link's own hit is C29's frozen-hit rule)
## and jumps on from it this many times as far.
@export var frozen_keep: float = 1.0
@export var frozen_jump_scale: float = 1.5

@export_group("Buffer")
## The pipe's buffer, KiB: its size, and what one chain writes into it.
@export var buffer_kib: float = 64.0
@export var write_kib: float = 8.0
## Seconds after the last write before the reader starts draining it, then the KiB it drains a second.
@export var drain_rest_s: float = 0.5
@export var drain_kib_s: float = 24.0
## A full buffer blocks every write until it has drained to this share of full.
@export var unblock_share: float = 0.5


## One line per value that would break the chain or the buffer. Empty means usable.
func problems() -> PackedStringArray:
	var out := PackedStringArray()
	if not is_finite(jump_m) or jump_m <= 0.0 or jump_m > JUMP_LAST_M:
		out.append("jump_m must be above 0 and at most %s" % JUMP_LAST_M)
	if max_links < LINKS_FIRST or max_links > LINKS_LAST:
		out.append("max_links must be %d to %d: a chain is at least two links" % [LINKS_FIRST, LINKS_LAST])
	if root_max_links < max_links or root_max_links > LINKS_LAST:
		out.append("root_max_links must be max_links to %d" % LINKS_LAST)
	if not is_finite(link_keep) or link_keep <= 0.0 or link_keep > 1.0:
		out.append("link_keep must be above 0 and at most 1")
	if not is_finite(frozen_keep) or frozen_keep < link_keep or frozen_keep > 1.0:
		out.append("frozen_keep must be link_keep to 1: a frozen link never loses more than a plain one")
	if not is_finite(frozen_jump_scale) or frozen_jump_scale < 1.0 or frozen_jump_scale > FROZEN_JUMP_LAST:
		out.append("frozen_jump_scale must be 1 to %s" % FROZEN_JUMP_LAST)
	if not is_finite(buffer_kib) or buffer_kib <= 0.0 or buffer_kib > BUFFER_LAST_KIB:
		out.append("buffer_kib must be above 0 and at most %s" % BUFFER_LAST_KIB)
	elif not is_finite(write_kib) or write_kib <= 0.0 or write_kib > buffer_kib:
		out.append("write_kib must be above 0 and at most buffer_kib")
	if not is_finite(drain_rest_s) or drain_rest_s < 0.0 or drain_rest_s > REST_LAST_S:
		out.append("drain_rest_s must be 0 to %s" % REST_LAST_S)
	if not is_finite(drain_kib_s) or drain_kib_s <= 0.0 or drain_kib_s > BUFFER_LAST_KIB:
		out.append("drain_kib_s must be above 0 and at most %s" % BUFFER_LAST_KIB)
	if not is_finite(unblock_share) or unblock_share < 0.0 or unblock_share >= 1.0:
		out.append("unblock_share must be 0 or more and under 1")
	return out


## Targets a chain reaches at most, as root or not.
func links_for(root: bool) -> int:
	return root_max_links if root else max_links
