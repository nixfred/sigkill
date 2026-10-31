class_name RuinsStage
extends RefCounted
## Stands an arena in a ruins district (C36): scripts/main.gd asks, as the arena loads, which set the next arena
## stands in (wanted(): the queued mission's own, MissionDef.ruins, else a set queued with no mission: the
## --ruins=<id> flag with --demo, the tests' and the captures'), and stage() puts it there:
##   the arena's own level goes: every greybox block (its floor, walls and cover), its dressing, its skyline and its
##   room light; the ruins (scripts/ruins/ruins_world.gd) are built in their place, the arena's environment copied
##   for them to change (so the next plain arena is as it was) and its sun handed to them;
##   the player stands at the ruins' start (where a fall puts it back too), the spawn markers at its spawn points,
##   each daemon at a daemon point (its home from then on), and the ICEbreakers' pickups at its breaker points.
## Everything else of the arena stays as it is: the round HUD, the directors, the code rain's driver, the HUD.
## In ruins with no mission, ICE stands down: its walls and nodes stand where the arena's level was. Solo only: a
## match is never staged (the missions are solo, and the flag is refused with a session). Nothing here reads anything.

const GreyBlock = preload("res://scripts/grey_block.gd")

## The game's own flag that stands the arena in a set with no mission: --ruins=<id>, with --demo or under --script.
const FLAG := "--ruins="
## The arena's nodes that go: besides every greybox block.
const GOES := ["ArenaArt", "Skyline", "RoomLight"]

static var _pending := ""


## Set `id` to stand the next arena in, with no mission (the flag, a test, a capture); "" for none.
static func queue(id: String) -> void:
	_pending = id


static func pending() -> String:
	return _pending


## The set the arena loading now stands in, or null: the queued mission's, else the set queued.
static func wanted() -> RuinsSet:
	var mission := MissionBook.of(MissionRunner.pending())
	if mission != null:
		return RuinsBook.of(mission.ruins) if mission.ruins != "" else null
	return RuinsBook.of(_pending) if _pending != "" else null


## The flag in `args` (the game's own arguments), queued once, only with --demo or under --script.
static func take_flag(args: PackedStringArray) -> void:
	for arg in args:
		if arg.begins_with(FLAG) and (args.has("--demo") or OS.get_cmdline_args().has("--script")):
			queue(arg.trim_prefix(FLAG))
			return


## Stands arena scene `main` in set `s`: returns the ruins built, or null (no set, or no arena to stand in).
static func stage(main: Node3D, s: RuinsSet) -> RuinsWorld:
	var arena := main.get_node_or_null("Arena") as Node3D
	if s == null or arena == null:
		return null
	for child in arena.get_children():
		if child.get_script() == GreyBlock or GOES.has(String(child.name)):
			arena.remove_child(child)
			child.free()
	var world := RuinsWorld.new(s)
	var we := arena.get_node_or_null("WorldEnvironment") as WorldEnvironment
	if we != null and we.environment != null:
		we.environment = we.environment.duplicate(true)
		world.environment = we.environment
	world.sun = main.get_node_or_null("Sun") as DirectionalLight3D
	arena.add_child(world)
	var player := main.get_node_or_null("Player") as Node3D
	if player != null and player.has_method("set_spawn"):
		player.set_spawn(Transform3D(Basis.IDENTITY, world.point("start")))
	var spawns := arena.get_node_or_null("Spawns")
	if spawns != null:
		var at := world.points_of("spawn")
		for i in spawns.get_child_count():
			var marker := spawns.get_child(i) as Node3D
			if marker != null and not at.is_empty():
				marker.global_position = at[i % at.size()]
	var targets := arena.get_node_or_null("Targets")
	if targets != null:
		var at := world.points_of("daemon")
		for i in targets.get_child_count():
			var dummy := targets.get_child(i) as Node3D
			if dummy == null or at.is_empty():
				continue
			dummy.global_position = at[i % at.size()]
			var brain = dummy.get("brain")
			if brain != null:
				brain.take_home()
	return world
