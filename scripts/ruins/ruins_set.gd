class_name RuinsSet
extends Resource
## One ruins district (C36, PRD 5.6, docs/STORY.md section 1): the recipe a seeded layout is made from, as data, a
## .tres file each in resources/ruins/, read by RuinsBook (scripts/ruins/ruins_book.gd). RuinsLayout
## (scripts/ruins/ruins_layout.gd) turns it into a plan (floor, ruins, holes, cover, named points) and RuinsWorld
## (scripts/ruins/ruins_world.gd) builds the plan into a playable space. A mission names one by its id (MissionDef.ruins).
##
## The same set and seed always make the same district, on every machine. Fiction only: every name on its
## monoliths and signs is demo text from this file, never anything of the player's.

## Its own name, a file's worth: "scheduler_breach".
@export var id := ""
## What it is called in words, for the tests and the docs: "the scheduler's breach".
@export var title := ""
## The seed every choice of its layout and its pieces comes from.
@export var seed := 0
## The register it stands in when nothing else says (STORY.md section 1): "tron", "cyberpunk", "matrix" or "all".
@export var register := "cyberpunk"
## Its floor, in cells of RuinsLayout.CELL_M: across (x) and along (z, from the start at +z to the exit at -z).
@export var cells := Vector2i(9, 13)
## How many ruin blocks stand inside the floor (rack clusters, monoliths, a fallen tower), as tries.
@export var blocks := 6
## How many holes open into the void inside the floor, as tries.
@export var holes := 2
## How many pieces of cover stand on the floor (toppled racks, terminals, drive stacks, rubble), as tries.
@export var cover := 12
## How many towers ring the floor, standing in the void beside it, and how many giants rise far out in it.
@export var towers := 22
@export var giants := 16
## How many cables hang between the towers, and how many neon signs hang on them.
@export var cables := 14
@export var signs := 8
## Demo folder names for the directory monoliths, and demo company words for the signs: fiction.
@export var folders := PackedStringArray()
@export var words := PackedStringArray()


## What is wrong with it; empty when it is good.
func problems() -> PackedStringArray:
	var out := PackedStringArray()
	if not MissionDef._id_ok(id):
		out.append("id \"%s\": lower case letters, digits and _ only" % id)
	if title == "":
		out.append("%s: no title" % id)
	if not RuinsLayout.REGISTERS.has(register):
		out.append("%s: register \"%s\" is not one of %s" % [id, register, ", ".join(RuinsLayout.REGISTERS)])
	if cells.x < RuinsLayout.CELLS_LEAST.x or cells.y < RuinsLayout.CELLS_LEAST.y or cells.x > RuinsLayout.CELLS_MOST.x or cells.y > RuinsLayout.CELLS_MOST.y:
		out.append("%s: cells %s outside %s to %s" % [id, str(cells), str(RuinsLayout.CELLS_LEAST), str(RuinsLayout.CELLS_MOST)])
	for pair in [["blocks", blocks, 0, 24], ["holes", holes, 0, 8], ["cover", cover, 0, 40], ["towers", towers, 4, 60], ["giants", giants, 0, 40], ["cables", cables, 0, 40], ["signs", signs, 0, 24]]:
		if pair[1] < pair[2] or pair[1] > pair[3]:
			out.append("%s: %s %d outside %d to %d" % [id, pair[0], pair[1], pair[2], pair[3]])
	if folders.size() < 3:
		out.append("%s: fewer than 3 folder names for its monoliths" % id)
	if words.size() < 2:
		out.append("%s: fewer than 2 sign words" % id)
	for text in folders + words:
		if not RuinsLayout.legible(text):
			out.append("%s: \"%s\" has letters the sign font has not, or is longer than %d" % [id, text, RuinsLayout.NAME_LAST])
		for word in RuinsLayout.NEVER_SHOWN:
			if text.to_lower().contains(word):
				out.append("%s: \"%s\" gives the story away (\"%s\")" % [id, text, word])
	return out
