class_name MissionDef
extends Resource
## One mission of the campaign (C35, PRD 5.6, docs/STORY.md section 6), as data: a .tres file each in
## resources/missions/, read by MissionBook (scripts/missions/mission_book.gd) and played by the arena's
## MissionRunner (scripts/missions/mission_runner.gd). No mission is a branch in code: everything one does is here.
##
## Objectives run one after another, each a dictionary:
##   {"id": "vent", "kind": "kill", "text": "SIGTERM the rogue.d", "daemon": "rogue", "count": 3}
##   kinds:  kill     daemon "rogue", "zombie", "swarm" or "any"; count
##           reach    at (Vector3, the arena's space, or in ruins a point's name); radius (m, default REACH_RADIUS);
##                    label (the beacon's word)
##           log      log: the id of one of `logs`, picked up
##           survive  seconds alive, the mission's clock running
##   every one may add "gives": weapon ids handed over in the mission as it is done (the loadout grows).
## Where it is played (C36): `ruins` names a ruins district (scripts/ruins/ruins_book.gd) the arena is stood in for it,
## and there a reach's or a log's "at" may name one of the district's points ("exit", "log_0") instead of a place;
## "" plays it on the arena itself.
## Terminal logs, each {"id", "name" (the file it reads as), "text", "at" (Vector3, or a point's name)}: standing in the arena from the
## start, picked up by walking through, read on the screen. Lines, each {"on": trigger, "who": "ai", "auditor" or
## "tilde", "text"}: your AI's story lines go to the guide panel as "your AI" (never through the player's own AI, never
## sent anywhere: STORY.md section 4), the Auditor's to the audit log, and `~`'s to a terminal of its own. Transitions, each {"on": trigger, "to": register}:
## the place shifting register. Triggers: "start", "complete", "fail", "begin:<objective>", "done:<objective>",
## "log:<log>", "at:<seconds into the mission>".
##
## The weapons (STORY.md, pick 4): `loadout` is what is in hand as it starts, `grants` what it hands out for keeps
## when it is done (the C33 unlocks' campaign record, scripts/unlocks/progress.gd), so by mission 6 all thirteen
## are held. Arena play and matches keep the whole arsenal from the start, whatever is held.
##
## Its own daemons and set pieces (C37). Waves, each {"id", "kind" ("rogue", "zombie" or "swarm"), "count", "from"
## (the ids of the vents they climb out of, in turn), "on" (a trigger) or "after" (a wave's id: when no more than
## "left" of that wave still stand, default 0), "every" (seconds between two climbing out, default WAVE_EVERY_S),
## "elites" (how many of them are their type's elite, default 0), "health" (each one's, default the arena's: one hit;
## an elite at least the daemon tuning's elite_health)}. With any waves, the arena's own four are gone while
## it runs: every daemon in it is one of its waves', each hunts the player as it climbs out and never gives up, and
## none comes back once down, so its daemons are finite (no more than the waves' counts). Props, each {"id", "kind"}:
##   vent      "at": a spawn vent in the floor, leaking green code; waves climb out of them
##   ice_wall  "at", "yaw" (degrees), "span" (Vector2: width, height): a white ICE wall it cannot break
##   breach    its ruins' breach (the district must have one): "opens", the trigger that splits the grid open over it,
##             and "lights", the trigger that lights the remnant's sign in the pocket below
## Waves add two triggers: "wave:<id>" (its first daemon climbing out) and "cleared:<id>" (its last one down), and a
## kill objective may count only some waves' daemons: "of", their ids (the pack, not a straggler from before it).
## An objective may add "hint": a line under it on the panel (a key it teaches, a way to play it).
##
## Abilities (C37): `abilities` are what it hands over beside its weapons (ids, ABILITIES), and they are enforced in a
## mission: one that this mission and the ones before it in the campaign have not handed over cannot be used in it
## (allowed_abilities()). Arena play and matches keep everything.
##
## Mission 2's machinery (M2). An objective may add "arms": weapon ids handed over as it begins (the beat that teaches
## them), where "gives" hands them over as it is done. A wave may add:
##   "dormant"  true: its daemons stand where they are put and do not hunt (a queue waiting at a door, jobs left in the
##              rain) until "wakes" fires (a trigger), one of them is hurt, or the player comes within WAKE_M of one;
##              then the whole wave wakes at once and hunts as any (the trigger "woke:<id>")
##   "sealed"   a trigger: until it fires its daemons cannot be hurt (armoured shut)
##   "reaps"    on a "parent" wave only, a daemon type: its daemon is the parent of every daemon of that type in the
##              mission, a thread drawn from each to it, and when it goes down every one of them still standing drops
##              at once, reaped (no kill credited: init did it)
##   "tag"      its daemons' name tag, in place of their type's
##   "tagged"   false: its daemons carry no name tag at all (a crowd of ten reads as a crowd, not ten labels)
##   "hit_cap"  the most one hit takes off one of its daemons (a parent outlasting a single kill -9)
##   "epitaph"  on a parent wave, the line shown over it as it goes down (its owner field)
## The "parent" type (a kill objective's daemon too) is a process that never moves or strikes: it stands, sealed or
## not, and its waves do the fighting. Props add "spot" ({"at"}: a place a wave stands at, nothing drawn) and "queue"
## ({"at", "yaw" (degrees) or "to" (a place it runs toward), "gap" (metres)}: a line of places out from "at", each daemon
## facing its head) and "shop" (its ruins' dead storefront, the district must have one: "dark", the trigger that stops its
## timer and puts its lights out for good).
##
## Mission 3's machinery (M3). The "core" type is a loop's core (scripts/daemons/loop_core.gd): rooted as a parent is, its
## forks doing the fighting. Props add:
##   "loop"    its ruins' cache field must have one: "cores" (a wave of cores), "forks" (a wave of runaways the loop forks),
##             "runs" (the trigger it starts on), "pass_s" and "pass_least_s" (seconds between two passes with every core
##             running, and with one left), "fill_s" (seconds the cache takes to fill with every core running), "each" (the
##             most children a core forks) and "standing" (the most of one core's children standing at once). From "runs"
##             on, every pass rewrites the field and every core standing forks one runaway at its hub (within "each" and
##             "standing", and the forks wave's count); the cache fills while any core runs, faster the more of them; each
##             core down scatters its own children (reaped: init again, no kill credited) and runs the rest hotter (their
##             passes quicker), and the last one down breaks the loop: every fork left reaped, the field frozen, `^C` over
##             its walls. The cache full fails the mission (out of memory: "exit 137"). Its triggers: "cache:<n>", the
##             cache n per cent full (25, 50, 75)
##   "hush"    "on" (a trigger), "after" (seconds), "seconds": the rain stops (every drop and glyph of the district's
##             weather held where it hangs, the code in its walls with it), then runs on
##   "prompt"  "on", "after": a red `>_` blinking on a wall of the field in front of the player (its ruins must have a field)
## A wave may add "by": a loop's id, its daemons forked by that loop (no "on", "after" or "from": they come off a core's hub);
## a wave's "tag" may hold "{n}", its daemon's place in the wave ("cpu{n}": cpu0, cpu1...). An objective may add "unlocks":
## abilities (of this mission's `abilities`) handed over as it begins, refused until then; any of them no objective
## unlocks is allowed from the start, as before. A line may add "wait": seconds after its trigger before it is said (your
## AI going quiet a moment).
##
## Mission 7's machinery (M7, the finale). The "shell" type is the shell's true body (scripts/daemons/shell_core.gd): one
## wave of one, hanging over the point it stands at; its "only" names the weapons whose hits land on it (the rest are
## refused: SIGTERM trapped, SIGHUP ignored, nothing else reaches it), its "hit_cap" makes each landing hit a known share;
## "sheds" names a wave of runaways it forks off itself ("by" the shell's id on that wave), one every "shed_every" seconds
## from its "sheds_on" trigger (or from the start) while fewer than "shed_standing" of them stand; "reaps" "any" makes it
## the parent of every daemon in the mission: its death drops them all at once (init adopts the orphans) and stands the
## mission's ICE down. An objective of kind "hit" counts the shots of one "weapon" that met its waves ("of"), landed or
## refused ("count"; "word" the panel's verb). The trigger "hit:<wave>:<n>" fires as the nth landing hit meets that wave.
##
## Fiction only: nothing here reads, names or touches anything on the player's machine (STORY.md, pick 8).

## The registers (STORY.md section 1); "all" is the finale's three at once.
const REGISTERS := ["tron", "matrix", "cyberpunk", "all"]
const KINDS := ["kill", "reach", "log", "survive", "root", "hup", "hit"]
## A hit objective's count at most (M7); a shell sheds a child every so many seconds, within this; the panel's verb.
const HIT_COUNT_LAST := 99
const SHED_EVERY := Vector2(1.0, 60.0)
const WORD_LAST := 16
## A scheduled job's (M5) name on the crontab, at most this long; its countdown, seconds; a root door's span (wide, tall).
const JOB_NAME_LAST := 24
const JOB_EVERY := Vector2(3.0, 300.0)
const DOOR_SPAN := Vector2(3.4, 3.6)
const DAEMONS := ["rogue", "zombie", "swarm", "parent", "core", "shell", "wall", "node", "hunter", "any"]
## A mission's own ICE (M4): wave kinds that are pieces of ICE, placed through the ICE director (white ICE walls, white ICE
## nodes, hunter ICE); a node wave names each node's kind; a wall's span (wide, tall) when the data gives none.
const ICE_KINDS := ["wall", "node", "hunter", "black"]
## Mission 6's (M6): a wave may wait "delay" seconds past its trigger (at most this); a "hup" objective counts daemons
## hung up by SIGHUP (at most this many), or one SIGHUP reaching the shell ("prop"); a shell prop wakes the district's
## shell on a trigger; a breach may open "after" seconds past its trigger; a Black ICE wave "withdraws" on a trigger.
const DELAY_LAST := 60.0
const HUP_COUNT_LAST := 20
const NODE_KINDS := ["jam", "hud"]
const ICE_SPAN := Vector2(3.4, 3.6)
## Who says a line: your AI (the guide panel), the Auditor (the audit log), or `~` (its own terminal, from mission 3 on).
const WHO := ["ai", "auditor", "tilde"]
## A reach objective's radius when its data names none, in metres.
const REACH_RADIUS := 2.5
## The longest line or objective text the HUD shows whole.
const TEXT_LAST := 120
## The longest log the reader shows.
const LOG_LAST := 600
## The longest objective hint the panel shows whole (C37).
const HINT_LAST := 46
const ID_CHARS := "abcdefghijklmnopqrstuvwxyz0123456789_"
## The abilities a mission may hand over (C37), by id, with the words the menus show.
const ABILITIES := {"code_rain_vision": "code-rain vision", "breakers": "ICEbreakers", "sudo": "sudo and root#", "sigstop": "SIGSTOP bullet time"}
## The daemon types a wave may be, the props' kinds, and a wave's numbers.
const WAVE_KINDS := ["rogue", "zombie", "swarm", "parent", "core", "shell", "wall", "node", "hunter", "black"]
const PROP_KINDS := ["vent", "ice_wall", "breach", "spot", "queue", "shop", "loop", "hush", "prompt", "pickup", "vault", "stutter", "job", "door", "shell"]
const WAVE_EVERY_S := 0.6
const WAVE_LAST := 12
## A dormant wave wakes as the player comes this near one of its daemons, metres (M2).
const WAKE_M := 7.0
## The longest name tag a wave gives its daemons (M2).
const TAG_LAST := 24
## A queue's gap between two places, metres (M2).
const QUEUE_GAP := Vector2(0.9, 3.0)
## The longest a line may wait after its trigger, seconds (M3).
const WAIT_LAST := 10.0
## The cache marks a loop says, per cent (M3: the triggers "cache:25", "cache:50", "cache:75").
const CACHE_MARKS := [25, 50, 75]

## Its own name, a file's worth: "login".
@export var id := ""
## Its place in the campaign, 1 to 7; 0 for one that is not in it (the test range).
@export var order := 0
## The command it is called: "login", "while true", "sudo !!".
@export var title := ""
## Where it is (STORY.md section 1) and, after a transition, where it ends.
@export var register := "tron"
## The goal in one line, shown once it is open.
@export var goal := ""
## The weapons in hand as it starts (their WeaponDef ids).
@export var loadout := PackedStringArray()
## The weapons it hands out for keeps when it is done.
@export var grants := PackedStringArray()
## What else it hands over (ids, ABILITIES): shown on the menus, and enforced in a mission since C37.
@export var abilities := PackedStringArray()
@export var objectives: Array = []
@export var logs: Array = []
@export var lines: Array = []
@export var transitions: Array = []
## Its own daemons, in waves, and its set pieces (C37).
@export var waves: Array = []
@export var props: Array = []
## Seconds the place holds after its last objective before the end screen comes up (C37).
@export var end_hold_s := 1.5
## Each objective done is a checkpoint (C37): the player's health back to full (the scheduler grants a fresh timeslice).
@export var restores := false
## Whether ICE (I1 to I3) stands in it; off, the system's own defences stand down while it runs.
@export var ice := false
## The ruins district it is played in (a RuinsSet id, C36), or "" for the arena itself.
@export var ruins := ""
## Its own fail rule: seconds of its clock before the timeslice runs out (0: none). Death always fails it.
@export var fail_time_s := 0.0
## The mission after it, or "".
@export var next := ""
## Its content exists and it can be started. A skeleton (a later chunk builds it) is listed but not started.
@export var playable := false
## A stand-in, playable now (mission 1 in its ruins since C36), for what a later chunk builds (C37 builds mission 1 for real).
@export var draft := false
## Never listed (the test range): started by the tests, or with --demo and --mission=<id>.
@export var hidden := false


## What is wrong with it, against the shipped weapons' ids; empty when it is good.
func problems(weapon_ids: PackedStringArray) -> PackedStringArray:
	var out := PackedStringArray()
	if not _id_ok(id):
		out.append("id \"%s\": lower case letters, digits and _ only" % id)
	if order < 0 or order > 99 or (order == 0 and not hidden):
		out.append("%s: order %d (1 and up, or 0 for a hidden one)" % [id, order])
	if title.strip_edges() == "" or title.length() > 24:
		out.append("%s: a title of 1 to 24 characters" % id)
	if not REGISTERS.has(register):
		out.append("%s: register \"%s\"" % [id, register])
	if goal.strip_edges() == "" or goal.length() > TEXT_LAST:
		out.append("%s: a goal of 1 to %d characters" % [id, TEXT_LAST])
	if loadout.is_empty():
		out.append("%s: an empty loadout" % id)
	for w in loadout:
		if not weapon_ids.has(w):
			out.append("%s: loadout weapon \"%s\"" % [id, w])
	var held := loadout.duplicate()
	var objective_ids := PackedStringArray()
	for o in objectives:
		out.append_array(_objective_problems(o, weapon_ids, objective_ids))
		held.append_array(_handed_by(o))
	var log_ids := PackedStringArray()
	for entry in logs:
		if not (entry is Dictionary) or not _id_ok(str(entry.get("id", ""))) or log_ids.has(str(entry.get("id"))):
			out.append("%s: a log without a good, unique id" % id)
			continue
		log_ids.append(entry["id"])
		if not (entry.get("name") is String) or entry["name"].strip_edges() == "" or entry["name"].length() > 48:
			out.append("%s: log %s has no name" % [id, entry["id"]])
		if not (entry.get("text") is String) or entry["text"].strip_edges() == "" or entry["text"].length() > LOG_LAST:
			out.append("%s: log %s needs 1 to %d characters of text" % [id, entry["id"], LOG_LAST])
		if not _place_ok(entry.get("at")):
			out.append("%s: log %s needs \"at\", a Vector3 or a point of its ruins" % [id, entry["id"]])
	for o in objectives:
		if o is Dictionary and o.get("kind") == "log" and not log_ids.has(str(o.get("log", ""))):
			out.append("%s: objective %s picks up log \"%s\", which is not in its logs" % [id, o.get("id"), o.get("log")])
	var wave_ids := wave_ids()
	out.append_array(_prop_problems())
	out.append_array(_wave_problems(objective_ids, log_ids, weapon_ids))
	for entry in logs:
		# A log that stands only from a trigger (M4): the records, once they are decrypted.
		if entry is Dictionary and str(entry.get("on", "")) != "" and not trigger_ok(str(entry["on"]), objective_ids, log_ids, wave_ids):
			out.append("%s: log %s stands on trigger \"%s\"" % [id, entry.get("id"), entry["on"]])
	for a in abilities:
		if not ABILITIES.has(a):
			out.append("%s: ability \"%s\" (one of %s)" % [id, a, ", ".join(ABILITIES.keys())])
	for line in lines:
		if not (line is Dictionary):
			out.append("%s: a line that is not a dictionary" % id)
			continue
		if not trigger_ok(str(line.get("on", "")), objective_ids, log_ids, wave_ids):
			out.append("%s: line trigger \"%s\"" % [id, line.get("on")])
		if not WHO.has(line.get("who")):
			out.append("%s: line by \"%s\" (ai, auditor or tilde)" % [id, line.get("who")])
		# A pick line (M4): your AI's own pick of which ICEbreaker to load, from the moment's numbers, after its text.
		var pick = line.get("pick", false)
		if not (pick is bool) or (pick and (line.get("who") != "ai" or not abilities.has("breakers"))):
			out.append("%s: a line's pick: true only for your AI's, in a mission that hands the ICEbreakers over" % id)
		if not (line.get("text") is String) or (line["text"].strip_edges() == "" and pick != true) or line["text"].length() > TEXT_LAST:
			out.append("%s: a line needs 1 to %d characters" % [id, TEXT_LAST])
		var wait = line.get("wait", 0.0)
		if not (wait is float or wait is int) or wait < 0.0 or wait > WAIT_LAST:
			out.append("%s: a line's wait (0 to %.0f seconds)" % [id, WAIT_LAST])
	for shift in transitions:
		if shift is Dictionary and shift.has("seconds") and (not (shift["seconds"] is float or shift["seconds"] is int) or shift["seconds"] < 0.0 or shift["seconds"] > 180.0):
			out.append("%s: a shift over 0 to 180 seconds" % id)  # M5: a slow decay
		if not (shift is Dictionary) or not trigger_ok(str(shift.get("on", "")), objective_ids, log_ids, wave_ids) or not REGISTERS.has(shift.get("to")):
			out.append("%s: a transition needs a good trigger and a register" % id)
	for w in grants:
		if not weapon_ids.has(w):
			out.append("%s: grants weapon \"%s\"" % [id, w])
		elif not held.has(w):
			out.append("%s: grants %s, never in hand in it" % [id, w])
	if fail_time_s < 0.0 or fail_time_s > 3600.0:
		out.append("%s: fail_time_s %.1f" % [id, fail_time_s])
	if end_hold_s < 0.0 or end_hold_s > 15.0:
		out.append("%s: end_hold_s %.1f (0 to 15)" % [id, end_hold_s])
	if playable and objectives.is_empty():
		out.append("%s: playable with no objectives" % id)
	if draft and not playable:
		out.append("%s: a draft is a playable stand-in" % id)
	if next != "" and (next == id or not _id_ok(next)):
		out.append("%s: next \"%s\"" % [id, next])
	if ruins != "":
		if RuinsBook.of(ruins) == null:
			out.append("%s: ruins \"%s\" is not a set" % [id, ruins])
		if ice and ice_waves().is_empty():
			out.append("%s: ICE in ruins needs its own ICE waves (M4: the arena's pieces stand where the arena's level is)" % id)
	elif not ice_waves().is_empty():
		out.append("%s: ICE waves stand in ruins (their points)" % id)
	return out


## True for a good "at": a place, or in ruins the name of one of its points.
func _place_ok(at: Variant) -> bool:
	if at is Vector3:
		return true
	if not (at is String) or ruins == "":
		return false
	var s := RuinsBook.of(ruins)
	return s != null and RuinsLayout.of(s).points.has(at)


func _objective_problems(o: Variant, weapon_ids: PackedStringArray, seen: PackedStringArray) -> PackedStringArray:
	var out := PackedStringArray()
	if not (o is Dictionary):
		return PackedStringArray(["%s: an objective that is not a dictionary" % id])
	var oid := str(o.get("id", ""))
	if not _id_ok(oid) or seen.has(oid):
		out.append("%s: an objective without a good, unique id" % id)
	seen.append(oid)
	if not (o.get("text") is String) or o["text"].strip_edges() == "" or o["text"].length() > TEXT_LAST:
		out.append("%s: objective %s needs 1 to %d characters of text" % [id, oid, TEXT_LAST])
	var hint = o.get("hint", "")
	if not (hint is String) or hint.length() > HINT_LAST:
		out.append("%s: objective %s hint: text of up to %d characters" % [id, oid, HINT_LAST])
	match o.get("kind"):
		"kill":
			if not DAEMONS.has(o.get("daemon")):
				out.append("%s: objective %s kills daemon \"%s\"" % [id, oid, o.get("daemon")])
			if not (o.get("count") is int) or o["count"] < 1 or o["count"] > 99:
				out.append("%s: objective %s needs a count of 1 to 99" % [id, oid])
		"reach":
			if not _place_ok(o.get("at")):
				out.append("%s: objective %s needs \"at\", a Vector3 or a point of its ruins" % [id, oid])
			var r = o.get("radius", REACH_RADIUS)
			if not (r is float or r is int) or r < 0.5 or r > 20.0:
				out.append("%s: objective %s radius" % [id, oid])
		"log":
			pass  # checked against the logs once they are read
		"survive":
			var s = o.get("seconds")
			if not (s is float or s is int) or s < 1.0 or s > 900.0:
				out.append("%s: objective %s needs 1 to 900 seconds" % [id, oid])
		"root":
			# Become root (M5): done the moment the player is root#; only where the campaign has handed sudo over.
			if not allowed_abilities().has("sudo"):
				out.append("%s: objective %s needs root in a mission the campaign has not handed sudo to" % [id, oid])
		"hup":
			# Hang up (M6): so many daemons of its waves caught by SIGHUP, or ("prop") one SIGHUP reaching the shell.
			if o.has("prop"):
				if prop_of(str(o["prop"])).get("kind") != "shell":
					out.append("%s: objective %s hangs up \"%s\", which is not a shell prop" % [id, oid, o.get("prop")])
			elif not (o.get("count") is int) or o["count"] < 1 or o["count"] > HUP_COUNT_LAST:
				out.append("%s: objective %s needs a count of 1 to %d to hang up" % [id, oid, HUP_COUNT_LAST])
			if not (loadout.has("sighup") or _handed_before(oid, "sighup")):
				out.append("%s: objective %s hangs up without SIGHUP in hand by then" % [id, oid])
		"hit":
			# A shot that met (M7): so many of one weapon's shots on its waves, landed or refused.
			var weapon := str(o.get("weapon", ""))
			if not weapon_ids.has(weapon):
				out.append("%s: objective %s counts hits of \"%s\", which is no weapon" % [id, oid, weapon])
			elif not _handed_before(oid, weapon):
				out.append("%s: objective %s counts hits of %s, never in hand by then" % [id, oid, weapon])
			if not (o.get("count") is int) or o["count"] < 1 or o["count"] > HIT_COUNT_LAST:
				out.append("%s: objective %s needs a count of 1 to %d hits" % [id, oid, HIT_COUNT_LAST])
			if not (o.get("of", []) is Array) or (o.get("of", []) as Array).is_empty():
				out.append("%s: objective %s needs \"of\": the waves whose daemons its hits meet" % [id, oid])
			var word = o.get("word", "")
			if not (word is String) or word.length() > WORD_LAST:
				out.append("%s: objective %s word: text of up to %d characters" % [id, oid, WORD_LAST])
		_:
			out.append("%s: objective %s kind \"%s\"" % [id, oid, o.get("kind")])
	var unlocks = o.get("unlocks", [])
	if not (unlocks is Array):
		out.append("%s: objective %s unlocks: a list of ability ids" % [id, oid])
	else:
		for a in unlocks:
			if not abilities.has(str(a)):
				out.append("%s: objective %s unlocks \"%s\", which is not one of its abilities" % [id, oid, a])
	for key in ["gives", "arms"]:
		var list = o.get(key, [])
		if not (list is Array):
			out.append("%s: objective %s %s: a list of weapon ids" % [id, oid, key])
			continue
		for w in list:
			if not weapon_ids.has(w):
				out.append("%s: objective %s %s weapon \"%s\"" % [id, oid, key, w])
			elif loadout.has(w):
				out.append("%s: objective %s %s %s, already in its loadout" % [id, oid, key, w])
	return out


## True when weapon `w` is in hand by the time objective `oid` begins (M6): in the loadout, or handed by it or one before.
func _handed_before(oid: String, w: String) -> bool:
	if loadout.has(w):
		return true
	for o in objectives:
		if not (o is Dictionary):
			continue
		if o.get("arms", []).has(w):
			return true
		if str(o.get("id", "")) == oid:
			return false
		if o.get("gives", []).has(w):
			return true
	return false


## True for a trigger that names something it has: "start", "complete", "fail", "begin:<objective>",
## "done:<objective>", "log:<log>", "at:<seconds>", (C37) "wave:<wave>" and "cleared:<wave>", (M2) "woke:<wave>", and (M3)
## "cache:<per cent>", one of CACHE_MARKS.
static func trigger_ok(trigger: String, objective_ids: PackedStringArray, log_ids: PackedStringArray, wave_ids: PackedStringArray = PackedStringArray()) -> bool:
	if trigger in ["start", "complete", "fail"]:
		return true
	var parts := trigger.split(":", false, 1)
	if parts.size() != 2:
		return false
	match parts[0]:
		"begin", "done":
			return objective_ids.has(parts[1])
		"log":
			return log_ids.has(parts[1])
		"at":
			return parts[1].is_valid_float() and float(parts[1]) >= 0.0
		"wave", "cleared", "woke":
			return wave_ids.has(parts[1])
		"cache":
			return parts[1].is_valid_int() and CACHE_MARKS.has(int(parts[1]))
		"hit":
			# The nth landing hit on a wave (M7): "hit:<wave>:<n>".
			var rest := parts[1].split(":", false, 1)
			return rest.size() == 2 and wave_ids.has(rest[0]) and rest[1].is_valid_int() and int(rest[1]) >= 1 and int(rest[1]) <= HIT_COUNT_LAST
	return false


## Its waves' ids, in order (C37).
func wave_ids() -> PackedStringArray:
	var out := PackedStringArray()
	for w in waves:
		if w is Dictionary:
			out.append(str(w.get("id", "")))
	return out


## Its props' ids of kind `kind` ("" every kind), in order (C37).
func prop_ids(kind: String = "") -> PackedStringArray:
	var out := PackedStringArray()
	for p in props:
		if p is Dictionary and (kind == "" or p.get("kind") == kind):
			out.append(str(p.get("id", "")))
	return out


## Its loop (M3), or {}: the one prop of kind "loop".
func loop_prop() -> Dictionary:
	for p in props:
		if p is Dictionary and p.get("kind") == "loop":
			return p
	return {}


## The abilities it may use as it starts (M3): what allowed_abilities() allows, less its own that an objective unlocks
## later (refused until that objective begins).
func abilities_at_start() -> PackedStringArray:
	var later := PackedStringArray()
	for o in objectives:
		if o is Dictionary and o.get("unlocks") is Array:
			for a in o["unlocks"]:
				later.append(str(a))
	var out := PackedStringArray()
	for a in allowed_abilities():
		if not later.has(a):
			out.append(a)
	return out


## Its waves of ICE (M4): walls, nodes and hunters.
func ice_waves() -> Array:
	var out: Array = []
	for w in waves:
		if w is Dictionary and ICE_KINDS.has(w.get("kind")):
			out.append(w)
	return out


## True when its ruins have a records vault (M4).
func _has_vault() -> bool:
	var s := RuinsBook.of(ruins) if ruins != "" else null
	return s != null and s.vault != ""


## Its scheduled jobs (M5) and its doors only root may pass, in their props' order.
func job_props() -> Array:
	return props.filter(func(p): return p is Dictionary and p.get("kind") == "job")


func door_props() -> Array:
	return props.filter(func(p): return p is Dictionary and p.get("kind") == "door")


## Its parent wave (M2), or {}: the one whose daemon reaps the rest; (M7) the shell's wave, the parent of everything.
func parent_wave() -> Dictionary:
	for w in waves:
		if w is Dictionary and w.get("kind") == "parent":
			return w
	for w in waves:
		if w is Dictionary and w.get("kind") == "shell":
			return w
	return {}


## Its shell's wave (M7), or {}.
func shell_wave() -> Dictionary:
	for w in waves:
		if w is Dictionary and w.get("kind") == "shell":
			return w
	return {}


## Its prop with id `prop_id`, or {} (C37).
func prop_of(prop_id: String) -> Dictionary:
	for p in props:
		if p is Dictionary and p.get("id") == prop_id:
			return p
	return {}


## How many daemons its waves bring, of type `kind` ("" every type): the most it can ever have (C37).
func daemons_total(kind: String = "") -> int:
	var n := 0
	for w in waves:
		if w is Dictionary and (kind == "" or w.get("kind") == kind) and w.get("count") is int:
			n += int(w["count"])
	return n


## The abilities this mission may use (C37): what it and every campaign mission before it hand over. The test range
## (order 0) only its own.
func allowed_abilities() -> PackedStringArray:
	var out := abilities.duplicate()
	if order <= 0:
		return out
	for def in MissionBook.campaign():
		if def.order < order:
			for a in def.abilities:
				if not out.has(a):
					out.append(a)
	return out


func _prop_problems() -> PackedStringArray:
	var out := PackedStringArray()
	var seen := PackedStringArray()
	for p in props:
		if not (p is Dictionary) or not _id_ok(str(p.get("id", ""))) or seen.has(str(p.get("id"))):
			out.append("%s: a prop without a good, unique id" % id)
			continue
		seen.append(p["id"])
		match p.get("kind"):
			"vent":
				if not _place_ok(p.get("at")):
					out.append("%s: vent %s needs \"at\", a Vector3 or a point of its ruins" % [id, p["id"]])
			"ice_wall":
				if not _place_ok(p.get("at")):
					out.append("%s: ICE wall %s needs \"at\", a Vector3 or a point of its ruins" % [id, p["id"]])
				var span = p.get("span", Vector2(3.0, 3.5))
				if not (span is Vector2) or span.x < 1.0 or span.x > 12.0 or span.y < 1.5 or span.y > 8.0:
					out.append("%s: ICE wall %s span (1 to 12 wide, 1.5 to 8 tall)" % [id, p["id"]])
			"spot":
				if not _place_ok(p.get("at")):
					out.append("%s: spot %s needs \"at\", a Vector3 or a point of its ruins" % [id, p["id"]])
			"queue":
				if not _place_ok(p.get("at")):
					out.append("%s: queue %s needs \"at\", a Vector3 or a point of its ruins" % [id, p["id"]])
				var yaw = p.get("yaw", 0.0)
				var gap = p.get("gap", 1.3)
				if not (yaw is float or yaw is int) or not (gap is float or gap is int) or gap < QUEUE_GAP.x or gap > QUEUE_GAP.y:
					out.append("%s: queue %s needs a yaw (degrees) and a gap of %.1f to %.1f m" % [id, p["id"], QUEUE_GAP.x, QUEUE_GAP.y])
				if p.has("to") and not _place_ok(p.get("to")):
					out.append("%s: queue %s runs \"to\" a place that is neither a Vector3 nor a point of its ruins" % [id, p["id"]])
			"shop":
				var shop_set := RuinsBook.of(ruins) if ruins != "" else null
				if shop_set == null or shop_set.shop == "":
					out.append("%s: shop %s, but its ruins have none" % [id, p["id"]])
				var t := str(p.get("dark", ""))
				if t != "" and not trigger_ok(t, _objective_ids(), _log_ids(), wave_ids()):
					out.append("%s: shop %s dark trigger \"%s\"" % [id, p["id"], t])
			"loop":
				out.append_array(_loop_problems(p))
			"hush", "prompt":
				var t := str(p.get("on", ""))
				if not trigger_ok(t, _objective_ids(), _log_ids(), wave_ids()):
					out.append("%s: %s %s trigger \"%s\"" % [id, p["kind"], p["id"], t])
				var after = p.get("after", 0.0)
				if not (after is float or after is int) or after < 0.0 or after > WAIT_LAST:
					out.append("%s: %s %s after (0 to %.0f seconds)" % [id, p["kind"], p["id"], WAIT_LAST])
				if p["kind"] == "hush":
					var secs = p.get("seconds", 1.0)
					if not (secs is float or secs is int) or secs < 0.2 or secs > 5.0:
						out.append("%s: hush %s seconds (0.2 to 5)" % [id, p["id"]])
				elif not _has_field():
					out.append("%s: prompt %s, but its ruins have no field" % [id, p["id"]])
			"job":
				# A scheduled job of the mission's (M5): its name on the crontab, its countdown, the waves its runs start in
				# order (each the job's own: no trigger of its own), the trigger it is scheduled on, the one that removes it,
				# and the fail it runs when its last countdown ends with it still scheduled.
				var jname = p.get("name", "")
				if not (jname is String) or jname.strip_edges() == "" or jname.length() > JOB_NAME_LAST:
					out.append("%s: job %s needs a name of 1 to %d characters" % [id, p["id"], JOB_NAME_LAST])
				var every = p.get("every", 0.0)
				if not (every is float or every is int) or every < JOB_EVERY.x or every > JOB_EVERY.y:
					out.append("%s: job %s runs every %.0f to %.0f seconds" % [id, p["id"], JOB_EVERY.x, JOB_EVERY.y])
				if not trigger_ok(str(p.get("on", "")), _objective_ids(), _log_ids(), wave_ids()):
					out.append("%s: job %s trigger \"%s\"" % [id, p["id"], p.get("on")])
				var runs = p.get("waves", [])
				if not (runs is Array):
					out.append("%s: job %s waves: a list of wave ids" % [id, p["id"]])
					runs = []
				for wid in runs:
					var found := false
					for w in waves:
						if w is Dictionary and str(w.get("id", "")) == str(wid):
							found = true
							if w.has("on") or w.has("after") or w.has("by"):
								out.append("%s: job %s runs wave %s, which has a trigger of its own" % [id, p["id"], wid])
					if not found:
						out.append("%s: job %s runs wave \"%s\", which is not one of its waves" % [id, p["id"], wid])
				var fails = p.get("fails", "")
				if not (fails is String) or fails.length() > TEXT_LAST:
					out.append("%s: job %s fails: text of up to %d characters" % [id, p["id"], TEXT_LAST])
					fails = ""
				if runs.is_empty() and fails == "":
					out.append("%s: job %s runs nothing and fails nothing" % [id, p["id"]])
				var until = str(p.get("until", ""))
				if until != "" and not trigger_ok(until, _objective_ids(), _log_ids(), wave_ids()):
					out.append("%s: job %s until \"%s\"" % [id, p["id"], until])
			"door":
				# A door only root may pass (M5): where it stands, its turn, its span; its mission must have sudo.
				if not _place_ok(p.get("at")):
					out.append("%s: door %s needs \"at\", a Vector3 or a point of its ruins" % [id, p["id"]])
				var yaw = p.get("yaw", 0.0)
				var span = p.get("span", DOOR_SPAN)
				if not (yaw is float or yaw is int) or not (span is Vector2) or span.x < 1.0 or span.x > 12.0 or span.y < 1.5 or span.y > 8.0:
					out.append("%s: door %s span (1 to 12 wide, 1.5 to 8 tall) and yaw (degrees)" % [id, p["id"]])
				if str(p.get("opens", "root")) != "root":
					out.append("%s: door %s opens only to root" % [id, p["id"]])
				if not allowed_abilities().has("sudo"):
					out.append("%s: door %s only root may pass, in a mission the campaign has not handed sudo to" % [id, p["id"]])
			"pickup":
				# An ICEbreaker pickup of the mission's (M4): where, which, and the trigger it is laid on.
				if not _place_ok(p.get("at")):
					out.append("%s: pickup %s needs \"at\", a Vector3 or a point of its ruins" % [id, p["id"]])
				if not Breakers.NAMES.has(str(p.get("breaker", ""))):
					out.append("%s: pickup %s breaker \"%s\" (%s)" % [id, p["id"], p.get("breaker"), ", ".join(Breakers.NAMES)])
				if not trigger_ok(str(p.get("on", "")), _objective_ids(), _log_ids(), wave_ids()):
					out.append("%s: pickup %s trigger \"%s\"" % [id, p["id"], p.get("on")])
				if not abilities.has("breakers"):
					out.append("%s: pickup %s in a mission that hands no ICEbreakers over" % [id, p["id"]])
			"vault":
				# The records screen lit (M4) on a trigger.
				if not _has_vault():
					out.append("%s: vault %s, but its ruins have no records vault" % [id, p["id"]])
				if not trigger_ok(str(p.get("lights", "")), _objective_ids(), _log_ids(), wave_ids()):
					out.append("%s: vault %s lights trigger \"%s\"" % [id, p["id"], p.get("lights")])
			"stutter":
				# The sector's lights stuttering once (M4), `after` seconds past a trigger.
				if not trigger_ok(str(p.get("on", "")), _objective_ids(), _log_ids(), wave_ids()):
					out.append("%s: stutter %s trigger \"%s\"" % [id, p["id"], p.get("on")])
				var after = p.get("after", 0.0)
				if not (after is float or after is int) or after < 0.0 or after > WAIT_LAST:
					out.append("%s: stutter %s after (0 to %.0f seconds)" % [id, p["id"], WAIT_LAST])
			"breach":
				var s := RuinsBook.of(ruins) if ruins != "" else null
				if s == null or s.breach == "":
					out.append("%s: breach %s, but its ruins have none" % [id, p["id"]])
				for key in ["opens", "lights"]:
					var t := str(p.get(key, ""))
					if t != "" and not trigger_ok(t, _objective_ids(), _log_ids(), wave_ids()):
						out.append("%s: breach %s %s trigger \"%s\"" % [id, p["id"], key, t])
				var after = p.get("after", 0.0)
				if not (after is float or after is int) or after < 0.0 or after > WAIT_LAST:
					out.append("%s: breach %s after (0 to %.0f seconds)" % [id, p["id"], WAIT_LAST])
			"shell":
				# `~`'s terminal (M6): the district's shell, woken on a trigger; its lines type as `~` speaks.
				var s := RuinsBook.of(ruins) if ruins != "" else null
				if s == null or s.shell == "":
					out.append("%s: shell %s, but its ruins have none" % [id, p["id"]])
				var t := str(p.get("wakes", ""))
				if not trigger_ok(t, _objective_ids(), _log_ids(), wave_ids()):
					out.append("%s: shell %s wakes trigger \"%s\"" % [id, p["id"], t])
			_:
				out.append("%s: prop %s kind \"%s\" (%s)" % [id, p["id"], p.get("kind"), ", ".join(PROP_KINDS)])
	return out


## True when its ruins have a cache field (M3).
func _has_field() -> bool:
	var s := RuinsBook.of(ruins) if ruins != "" else null
	return s != null and s.field != ""


func _loop_problems(p: Dictionary) -> PackedStringArray:
	var out := PackedStringArray()
	var pid := str(p["id"])
	if not _has_field():
		out.append("%s: loop %s, but its ruins have no field" % [id, pid])
	var cores := _wave_of(str(p.get("cores", "")))
	var forks := _wave_of(str(p.get("forks", "")))
	if cores.get("kind") != "core":
		out.append("%s: loop %s cores: a wave of kind core" % [id, pid])
	if forks.get("kind") != "swarm" or str(forks.get("by", "")) != pid:
		out.append("%s: loop %s forks: a wave of runaways (swarm) forked by it (\"by\": \"%s\")" % [id, pid, pid])
	if not trigger_ok(str(p.get("runs", "")), _objective_ids(), _log_ids(), wave_ids()):
		out.append("%s: loop %s runs on trigger \"%s\"" % [id, pid, p.get("runs")])
	for pair in [["pass_s", 2.0, 60.0], ["pass_least_s", 1.0, 60.0], ["fill_s", 30.0, 3600.0]]:
		var v = p.get(pair[0])
		if not (v is float or v is int) or v < pair[1] or v > pair[2]:
			out.append("%s: loop %s %s (%.0f to %.0f seconds)" % [id, pid, pair[0], pair[1], pair[2]])
	var fast = p.get("pass_least_s")
	var slow = p.get("pass_s")
	if (fast is float or fast is int) and (slow is float or slow is int) and float(fast) > float(slow):
		out.append("%s: loop %s runs slower on one core than on all of them" % [id, pid])
	for key in ["each", "standing"]:
		var v = p.get(key)
		if not (v is int) or v < 1 or v > WAVE_LAST:
			out.append("%s: loop %s %s (1 to %d)" % [id, pid, key, WAVE_LAST])
	return out


func _wave_of(wave_id: String) -> Dictionary:
	for w in waves:
		if w is Dictionary and w.get("id") == wave_id:
			return w
	return {}


func _wave_problems(objective_ids: PackedStringArray, log_ids: PackedStringArray, weapon_ids: PackedStringArray = PackedStringArray()) -> PackedStringArray:
	# The waves a scheduled job runs (M5): started by the job, so they carry no trigger of their own.
	var job_waves := PackedStringArray()
	for jp in job_props():
		for jw in jp.get("waves", []):
			job_waves.append(str(jw))
	var out := PackedStringArray()
	var ids := wave_ids()
	var vents := prop_ids("vent") + prop_ids("spot") + prop_ids("queue")
	var seen := PackedStringArray()
	var parents := 0
	for w in waves:
		if not (w is Dictionary) or not _id_ok(str(w.get("id", ""))) or seen.has(str(w.get("id"))):
			out.append("%s: a wave without a good, unique id" % id)
			continue
		var wid: String = w["id"]
		seen.append(wid)
		if not WAVE_KINDS.has(w.get("kind")):
			out.append("%s: wave %s kind \"%s\" (rogue, zombie or swarm)" % [id, wid, w.get("kind")])
		var count = w.get("count")
		if not (count is int) or count < 1 or count > WAVE_LAST:
			out.append("%s: wave %s needs a count of 1 to %d" % [id, wid, WAVE_LAST])
		var elites = w.get("elites", 0)
		if not (elites is int) or elites < 0 or (count is int and elites > count):
			out.append("%s: wave %s elites (0 to its count)" % [id, wid])
		var by := str(w.get("by", ""))
		if by != "":
			# Forked by a loop (M3), or shed by the shell (M7): never triggered, never climbing out of anything.
			var loop := prop_of(by)
			var shell := _wave_of(by)
			var shed: bool = shell.get("kind") == "shell" and str(shell.get("sheds", "")) == wid
			if not shed and (loop.get("kind") != "loop" or str(loop.get("forks", "")) != wid):
				out.append("%s: wave %s forked by \"%s\", which is not a loop forking it or a shell shedding it" % [id, wid, by])
			if shed and w.get("kind") != "swarm":
				out.append("%s: wave %s is shed by the shell: a wave of runaways (swarm)" % [id, wid])
			for key in ["on", "after", "from", "dormant", "wakes", "sealed"]:
				if w.has(key):
					out.append("%s: wave %s is forked by a loop: no \"%s\"" % [id, wid, key])
		if w.get("kind") == "shell":
			# The shell's true body (M7): one, standing at a spot, the weapons that reach it named, what it sheds and reaps.
			if count != 1:
				out.append("%s: wave %s: a shell wave is one shell" % [id, wid])
			var only = w.get("only", [])
			if not (only is Array) or only.is_empty():
				out.append("%s: wave %s needs \"only\": the weapons whose hits land on it" % [id, wid])
			else:
				for weapon in only:
					if not weapon_ids.has(str(weapon)):
						out.append("%s: wave %s is reached only by \"%s\", which is no weapon" % [id, wid, weapon])
			if str(w.get("sheds", "")) != "":
				var child := _wave_of(str(w["sheds"]))
				if child.get("kind") != "swarm" or str(child.get("by", "")) != wid:
					out.append("%s: wave %s sheds \"%s\", which is not a wave of runaways shed by it (\"by\": \"%s\")" % [id, wid, w["sheds"], wid])
				var every = w.get("shed_every", SHED_EVERY.x)
				if not (every is float or every is int) or every < SHED_EVERY.x or every > SHED_EVERY.y:
					out.append("%s: wave %s shed_every (%.0f to %.0f seconds)" % [id, wid, SHED_EVERY.x, SHED_EVERY.y])
				var standing = w.get("shed_standing", 1)
				if not (standing is int) or standing < 1 or standing > WAVE_LAST:
					out.append("%s: wave %s shed_standing (1 to %d)" % [id, wid, WAVE_LAST])
				var on_shed := str(w.get("sheds_on", ""))
				if on_shed != "" and not trigger_ok(on_shed, objective_ids, log_ids, ids):
					out.append("%s: wave %s sheds on \"%s\"" % [id, wid, on_shed])
			else:
				for key in ["shed_every", "shed_standing", "sheds_on"]:
					if w.has(key):
						out.append("%s: wave %s has %s but sheds nothing" % [id, wid, key])
		else:
			for key in ["only", "sheds", "shed_every", "shed_standing", "sheds_on"]:
				if w.has(key):
					out.append("%s: wave %s has %s, but only a shell does" % [id, wid, key])
		var from = w.get("from", [])
		var ice_wave: bool = ICE_KINDS.has(w.get("kind"))
		if ice_wave:
			# A piece of the mission's own ICE (M4): at its points, never climbing out, never asleep, sealed or forked.
			if not ice:
				out.append("%s: wave %s is ICE, but the mission has none (ice)" % [id, wid])
			for key in ["dormant", "wakes", "sealed", "by", "elites", "reaps", "epitaph", "tagged", "tag"]:
				if w.has(key):
					out.append("%s: wave %s is ICE: no \"%s\"" % [id, wid, key])
			if not (from is Array) or from.is_empty():
				out.append("%s: wave %s needs \"from\": the points its pieces stand at" % [id, wid])
			else:
				for v in from:
					if not _place_ok(v):
						out.append("%s: wave %s stands at \"%s\", which is neither a Vector3 nor a point of its ruins" % [id, wid, v])
			if w.get("kind") == "hunter" and count != 1:
				out.append("%s: wave %s: a hunter wave is one hunter" % [id, wid])
			if w.get("kind") == "black":
				# Black ICE (M6): one, staged through the director, withdrawn on a trigger or broken by the breakers.
				if count != 1:
					out.append("%s: wave %s: a black wave is one Black ICE" % [id, wid])
				var back := str(w.get("withdraws", ""))
				if back != "" and not trigger_ok(back, objective_ids, log_ids, ids):
					out.append("%s: wave %s withdraws on \"%s\"" % [id, wid, back])
			elif w.has("withdraws"):
				out.append("%s: wave %s withdraws, but only Black ICE does" % [id, wid])
			if w.get("kind") == "node":
				var kinds = w.get("nodes", [])
				if not (kinds is Array) or (count is int and kinds.size() != count):
					out.append("%s: wave %s needs \"nodes\": a kind (jam or hud) for each of its %s" % [id, wid, str(count)])
				else:
					for k in kinds:
						if not NODE_KINDS.has(str(k)):
							out.append("%s: wave %s node kind \"%s\" (jam or hud)" % [id, wid, k])
			elif w.has("nodes"):
				out.append("%s: wave %s has node kinds, but is not a node wave" % [id, wid])
			if w.get("kind") == "wall":
				var span = w.get("span", ICE_SPAN)
				var yaw = w.get("yaw", 0.0)
				if not (span is Vector2) or span.x < 1.0 or span.x > 12.0 or span.y < 1.5 or span.y > 8.0 or not (yaw is float or yaw is int):
					out.append("%s: wave %s span (1 to 12 wide, 1.5 to 8 tall) and yaw (degrees)" % [id, wid])
			if w.has("face") and not _place_ok(w.get("face")):
				out.append("%s: wave %s faces \"%s\", which is neither a Vector3 nor a point of its ruins" % [id, wid, w.get("face")])
		elif by != "":
			pass  # forked by its loop at a core's hub: nothing to climb out of
		elif not (from is Array) or from.is_empty():
			out.append("%s: wave %s needs \"from\": the vents it climbs out of" % [id, wid])
		else:
			for v in from:
				if not vents.has(str(v)):
					out.append("%s: wave %s climbs out of \"%s\", which is not one of its vents, spots or queues" % [id, wid, v])
		var every = w.get("every", WAVE_EVERY_S)
		if not (every is float or every is int) or every < 0.1 or every > 30.0:
			out.append("%s: wave %s every (0.1 to 30 seconds)" % [id, wid])
		var delay = w.get("delay", 0.0)
		if not (delay is float or delay is int) or delay < 0.0 or delay > DELAY_LAST:
			out.append("%s: wave %s delay (0 to %.0f seconds past its trigger)" % [id, wid, DELAY_LAST])
		var on := str(w.get("on", ""))
		var after := str(w.get("after", ""))
		if by != "":
			pass
		elif job_waves.has(wid):
			pass  # a scheduled job's (M5): the job starts it, run by run
		elif (on == "") == (after == ""):
			out.append("%s: wave %s needs one of \"on\" (a trigger) or \"after\" (a wave)" % [id, wid])
		elif on != "" and not trigger_ok(on, objective_ids, log_ids, ids):
			out.append("%s: wave %s trigger \"%s\"" % [id, wid, on])
		elif after != "" and (after == wid or not seen.has(after)):
			out.append("%s: wave %s comes after \"%s\", which is not a wave before it" % [id, wid, after])
		var left = w.get("left", 0)
		if not (left is int) or left < 0:
			out.append("%s: wave %s left (0 or more)" % [id, wid])
		var health = w.get("health", 1.0)
		if not (health is float or health is int) or health <= 0.0 or health > 1000.0:
			out.append("%s: wave %s health (above 0, up to 1000)" % [id, wid])
		# Mission 2's (M2): asleep until woken, sealed until a trigger, a parent reaping its children, a tag of its own.
		for key in ["dormant", "tagged"]:
			if not (w.get(key, key == "tagged") is bool):
				out.append("%s: wave %s %s (true or false)" % [id, wid, key])
		for key in ["wakes", "sealed"]:
			var t := str(w.get(key, ""))
			if t != "" and not trigger_ok(t, objective_ids, log_ids, ids):
				out.append("%s: wave %s %s trigger \"%s\"" % [id, wid, key, t])
		if w.has("wakes") and w.get("dormant", false) != true:
			out.append("%s: wave %s wakes, but is not dormant" % [id, wid])
		if w.get("kind") == "parent":
			parents += 1
			if count is int and count != 1:
				out.append("%s: wave %s: a parent wave is one parent" % [id, wid])
			if not ["zombie", "rogue", "swarm"].has(w.get("reaps", "")):
				out.append("%s: parent wave %s reaps a daemon type (zombie, rogue or swarm)" % [id, wid])
		elif w.get("kind") == "shell":
			parents += 1
			if w.has("reaps") and not ["zombie", "rogue", "swarm", "any"].has(w.get("reaps", "")):
				out.append("%s: shell wave %s reaps a daemon type (zombie, rogue, swarm or any)" % [id, wid])
		elif w.has("reaps"):
			out.append("%s: wave %s reaps, but only a parent or the shell does" % [id, wid])
		for key in ["tag", "epitaph"]:
			var text = w.get(key, "")
			if not (text is String) or text.length() > TAG_LAST:
				out.append("%s: wave %s %s: text of up to %d characters" % [id, wid, key, TAG_LAST])
		if w.has("epitaph") and w.get("kind") != "parent" and w.get("kind") != "shell":
			out.append("%s: wave %s has an epitaph, but only a parent or the shell does" % [id, wid])
		var cap = w.get("hit_cap", 0.0)
		if not (cap is float or cap is int) or cap < 0.0 or cap > 1000.0:
			out.append("%s: wave %s hit_cap (0 to 1000)" % [id, wid])
	if parents > 1:
		out.append("%s: %d parent or shell waves (one at most)" % [id, parents])
	for o in objectives:
		if not (o is Dictionary) or not o.has("of"):
			continue
		var of = o.get("of")
		var bring := 0
		if not (of is Array) or of.is_empty():
			out.append("%s: objective %s \"of\": the waves whose daemons it counts" % [id, o.get("id")])
			continue
		for wid in of:
			if not ids.has(str(wid)):
				out.append("%s: objective %s counts wave \"%s\", which it has not" % [id, o.get("id"), wid])
			for w in waves:
				if w is Dictionary and w.get("id") == str(wid) and w.get("count") is int:
					bring += int(w["count"])
		if o.get("count") is int and int(o["count"]) > bring and o.get("kind") != "hit":
			out.append("%s: objective %s wants %d, its waves bring %d" % [id, o.get("id"), o["count"], bring])
	# Every kill objective can be done with the daemons its waves bring (a mission with waves has no others).
	if not waves.is_empty():
		var want := {}
		for o in objectives:
			if o is Dictionary and o.get("kind") == "kill" and o.get("count") is int:
				var k := str(o.get("daemon"))
				want[k] = int(want.get(k, 0)) + int(o["count"])
		for k in want:
			var have := daemons_total("" if k == "any" else k)
			if want[k] > have:
				out.append("%s: its kill objectives want %d %s, its waves bring %d" % [id, want[k], k, have])
	return out


func _objective_ids() -> PackedStringArray:
	var out := PackedStringArray()
	for o in objectives:
		if o is Dictionary:
			out.append(str(o.get("id", "")))
	return out


func _log_ids() -> PackedStringArray:
	var out := PackedStringArray()
	for entry in logs:
		if entry is Dictionary:
			out.append(str(entry.get("id", "")))
	return out


## Every weapon that is ever in hand in it: the loadout and what its objectives give.
func carried_ever() -> PackedStringArray:
	var out := loadout.duplicate()
	for o in objectives:
		for w in _handed_by(o):
			if not out.has(w):
				out.append(w)
	return out


## The weapons objective `o` hands over (M2): its "arms" as it begins, then its "gives" as it is done.
static func _handed_by(o: Variant) -> PackedStringArray:
	var out := PackedStringArray()
	if not (o is Dictionary):
		return out
	for key in ["arms", "gives"]:
		var list = o.get(key, [])
		if list is Array:
			for w in list:
				out.append(str(w))
	return out


## Its log with id `log_id`, or {}.
func log_of(log_id: String) -> Dictionary:
	for entry in logs:
		if entry is Dictionary and entry.get("id") == log_id:
			return entry
	return {}


## Its number as the menu shows it: "01"; "00" for the test range.
func number() -> String:
	return "%02d" % order


static func _id_ok(text: String) -> bool:
	if text == "" or text.length() > 32:
		return false
	for c in text:
		if not ID_CHARS.contains(c):
			return false
	return true
