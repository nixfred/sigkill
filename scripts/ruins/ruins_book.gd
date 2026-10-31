class_name RuinsBook
extends RefCounted
## The ruins districts (C36): each a RuinsSet in resources/ruins/ (scripts/ruins/ruins_set.gd), read once a run from
## this fixed list (never a folder scan). A mission names one by id (MissionDef.ruins); the tests build every one.

const SETS := ["res://resources/ruins/scheduler_breach.tres", "res://resources/ruins/deep_dirs.tres", "res://resources/ruins/cache_district.tres"]

static var _sets: Array = []


## Every set, in the list's order. A file that is not a RuinsSet is left out (problems() says so).
static func all() -> Array:
	if _sets.is_empty():
		for path in SETS:
			var s = load(path)
			if s is RuinsSet:
				_sets.append(s)
	return _sets


## The set with id `id`, or null.
static func of(id: String) -> RuinsSet:
	for s in all():
		if s.id == id:
			return s
	return null


## Everything wrong with the book; empty when it is good.
static func problems() -> PackedStringArray:
	var out := PackedStringArray()
	var sets := all()
	if sets.size() != SETS.size():
		out.append("%d of %d ruins files are sets" % [sets.size(), SETS.size()])
	var seen := {}
	for s in sets:
		out.append_array(s.problems())
		if seen.has(s.id):
			out.append("%s twice" % s.id)
		seen[s.id] = true
	return out
