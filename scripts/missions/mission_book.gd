class_name MissionBook
extends RefCounted
## The campaign's missions (C35, docs/STORY.md section 6): the seven after the opener, in order, and the test range,
## each a MissionDef in resources/missions/ (scripts/missions/mission_def.gd), read once a run from this fixed list
## (never a folder scan). Its rules, beyond each mission's own (problems()): the orders run 1 to 7 and each `next`
## names the one after it; every weapon is handed out once, by the mission that teaches it, all thirteen by mission
## 6 and none sooner than STORY.md says (a mission only ever carries what it and the missions before it hand out);
## the finale hands out nothing. The test range is not in the campaign: never listed, never recorded.

const CAMPAIGN := ["res://resources/missions/login.tres", "res://resources/missions/defunct.tres", "res://resources/missions/while_true.tres", "res://resources/missions/permission_denied.tres", "res://resources/missions/sudo_bang.tres", "res://resources/missions/nohup.tres", "res://resources/missions/kill_9.tres"]
const TEST_RANGE := "res://resources/missions/test_range.tres"
## By the end of this mission every weapon is held (STORY.md, pick 4).
const ALL_HELD_BY := 6

static var _campaign: Array = []
static var _test: MissionDef = null


## The seven, in order. A file that is not a MissionDef is left out (problems() says so).
static func campaign() -> Array:
	if _campaign.is_empty():
		for path in CAMPAIGN:
			var def = load(path)
			if def is MissionDef:
				_campaign.append(def)
	return _campaign


static func test_range() -> MissionDef:
	if _test == null:
		var def = load(TEST_RANGE)
		_test = def if def is MissionDef else null
	return _test


## The mission with id `id`, the test range included, or null.
static func of(id: String) -> MissionDef:
	for def in campaign():
		if def.id == id:
			return def
	var t := test_range()
	return t if t != null and t.id == id else null


## The campaign mission numbered `order`, or null.
static func at(order: int) -> MissionDef:
	for def in campaign():
		if def.order == order:
			return def
	return null


## The shipped weapons' ids, slot order.
static func weapon_ids() -> PackedStringArray:
	var out := PackedStringArray()
	for def in WeaponKit.shipped_defs():
		out.append(def.id)
	return out


## Every weapon handed out for keeps by the missions up to and including number `order`.
static func granted_by(order: int) -> PackedStringArray:
	var out := PackedStringArray()
	for def in campaign():
		if def.order <= order:
			for w in def.grants:
				if not out.has(w):
					out.append(w)
	return out


## The campaign mission that hands out weapon `weapon`, or null.
static func granting(weapon: String) -> MissionDef:
	for def in campaign():
		if def.grants.has(weapon):
			return def
	return null


## Everything wrong with the book; empty when it is good.
static func problems() -> PackedStringArray:
	var out := PackedStringArray()
	var ids := weapon_ids()
	var defs := campaign()
	if defs.size() != CAMPAIGN.size():
		out.append("%d of %d campaign files are missions" % [defs.size(), CAMPAIGN.size()])
	var test := test_range()
	if test == null:
		out.append("the test range is not a mission")
	else:
		out.append_array(test.problems(ids))
		if not test.hidden or test.order != 0 or not test.grants.is_empty():
			out.append("the test range: hidden, order 0, handing out nothing")
	var seen := {}
	for i in defs.size():
		var def: MissionDef = defs[i]
		out.append_array(def.problems(ids))
		if def.order != i + 1 or def.hidden:
			out.append("%s: order %d at place %d" % [def.id, def.order, i + 1])
		if seen.has(def.id):
			out.append("%s twice" % def.id)
		seen[def.id] = true
		var after: String = defs[i + 1].id if i + 1 < defs.size() else ""
		if def.next != after:
			out.append("%s: next \"%s\", the campaign's \"%s\"" % [def.id, def.next, after])
		var allowed := granted_by(def.order)
		for w in def.carried_ever():
			if not allowed.has(w):
				out.append("%s carries %s before the mission that hands it out" % [def.id, w])
	for w in ids:
		var count := 0
		for def in defs:
			count += def.grants.count(w)
		if count != 1:
			out.append("%s handed out %d times" % [w, count])
	if granted_by(ALL_HELD_BY).size() != ids.size():
		out.append("not every weapon held by mission %d" % ALL_HELD_BY)
	if not defs.is_empty() and not defs[defs.size() - 1].grants.is_empty():
		out.append("the finale hands out weapons")
	return out
