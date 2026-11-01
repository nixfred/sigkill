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
## Its breach (C37), "exit" or "" for none: the point whose floor cell a mission can split open (built loose, a hatch over a
## shaft leaking green code, the exit side onto the void a gate), the depth of the pocket below it the player drops
## into, and the words on the remnant's sign beside that pocket (a dead megacorp's, dark until a mission lights it).
@export var breach := ""
@export var breach_depth := 14.0
@export var remnant := ""
## Its dead storefront (M2), "plaza" or "" for none: a closed terminal as a shop standing on the floor's edge nearest the
## plaza, its front to the street (a block of kind "shop": its window a terminal frozen on its last screen, a shutter half
## down with light leaking under it, its name over the door, an OPEN sign, all of its light on a timer nobody owns), the
## words over its door, and its window's last screen (lines in the sign font, a "|" between two).
@export var shop := ""
@export var shop_sign := ""
@export var shop_screen := ""
## Its cache field (M3), "plaza" or "" for none: a square of field_cells by field_cells floor cells round the plaza, kept
## clear of ruins, holes and cover, its cells' sides a lattice of walls of code that rewrite themselves (written, mid-
## rewrite, or gone; scripts/ruins/cache_field.gd), a post at every corner of the lattice; and the lines of code its walls
## show, a "|" between two (fiction, in the mono font).
@export var field := ""
@export var field_cells := 5
@export var field_code := ""
## A healthy sector (M4): nothing broken, slipped, spilled, cracked or dying. Every slab whole, every rack tower straight with
## every light alive, every parapet a clean rail, no cable, no cover of the broken kinds (cover, holes and cables must be 0):
## the kit's pieces built at their cleanest, so a guarded sector reads as a different place from the ruins.
@export var pristine := false
## Its records vault (M4), "exit" or "" for none: the sector planned as a guarded hall (scripts/ruins/ruins_layout.gd): the
## route a straight aisle down the middle through three gates (rows of record stacks either side of a one-cell way, where a
## mission seals the way with ICE), bays between them lined with stacks and guard posts, and at the exit end the vault: a
## clean deck lined with stacks, the records console at its far end and the records screen on the end wall, dark until a
## mission lights it. vault_lines are what the screen shows then (lines in the sign font, a "|" between two; a run of "#" in
## a line is drawn as a redaction bar, never letters). Needs cells at least 7 wide (an odd number: the aisle) and 20 long.
@export var vault := ""
@export var vault_lines := ""
## Its decay (M5), "exit" or "" for none: a sector healthy at its start and eaten as it goes toward the exit (STORY.md
## mission 5: the grid starts to rain as you go down). Every piece is built as clean as a pristine set's where
## RuinsLayout.decay_at() is under DECAY_CLEAN and as broken as the ruins' at the exit end; the dice's holes, cover and
## cables fall only past DECAY_CLEAN; the slabs' damage, the towers' lean and their dead lights grow with it. Not with
## pristine (that is the whole sector clean).
@export var decay := ""
## Its sealed room (M5), "exit" or "" for none: the exit cell walled in on three sides and both corners by record stacks
## named room_names (a "|" between two, cycled), its one doorway facing the start, where a mission stands a door only root
## may pass (a "door" prop at the point "room_door"); the point "room" inside it. Needs cells at least 9 wide (an odd
## number) and 8 long, and no vault.
@export var room := ""
@export var room_names := ""
## Its crontab board (M5), "plaza" or "" for none: a screen two cells wide on the floor's edge nearest the plaza (where
## the shop stands in a set with one; not both), lit from the start, showing board_lines in the sign font (a "|" between
## two); the point "board" in front of it.
@export var board := ""
@export var board_lines := ""
## Its terraces (M6): how many times the floor steps down between the start and the exit (0: flat), each step `drop_m`
## deep (RuinsLayout.floor_y()): the floor is cut into bands of rows, the start's the highest, the exit's the lowest; a
## ramp of racks carries the route down each step and a cliff of racks stands along the rest of it. STORY.md mission 6:
## a vertical descent through nested directories.
@export var terraces := 0
@export var drop_m := 4.5
## Its water (M6), metres under the lowest floor (0: none): the void is a drowned plain, its surface holding the signs'
## neon and the rain; what falls into it is gone (the fall puts the player back at the start).
@export var water := 0.0
## Its own colours (M6), a RuinsRegister.PALETTES name, or "" for the register's own: the signs, strips, screens, fog,
## sky and puddles of its cyberpunk read in another family (the deepest ruins are not mission 2's street).
@export var palette := ""
## Its shell (M6), "exit" or "" for none: a terminal screen on a block at the exit end facing the start, dark until a
## mission wakes it, where `~`'s lines type themselves (the point "shell" in front of it); shell_lines is what it shows
## before anything types (lines in the sign font, a "|" between two). Not with a room, a vault or a board.
@export var shell := ""
@export var shell_lines := ""
## Its breach's pocket is the core's (M6): no remnant tower or sign below, a red heat far under the deck instead, dark
## until a mission lights it (the drop into the core). Needs a breach; remnant may be "".
@export var breach_core := false
## Its clearing (M7), in cells round the plaza (0: none): the plaza and every cell within that many of it kept open floor,
## no ruin, hole or cover of the dice, so a fight round something hanging over the plaza has room and sight lines; the
## points "ring_0" to "ring_3" stand at its four edges. The finale's arena round the core.
@export var clearing := 0


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
	if breach != "" and breach != "exit":
		out.append("%s: breach \"%s\" (only the exit: its cell is never under cover, and its gate meets the void)" % [id, breach])
	if breach != "" and (breach_depth < 6.0 or breach_depth > 24.0):
		out.append("%s: breach_depth %.1f outside 6 to 24" % [id, breach_depth])
	if breach != "" and remnant.strip_edges() == "" and not breach_core:
		out.append("%s: a breach with no remnant sign" % id)
	if breach_core and breach == "":
		out.append("%s: the core under a breach it has not" % id)
	if shop != "" and shop != "plaza":
		out.append("%s: shop \"%s\" (only by the plaza)" % [id, shop])
	if shop != "" and (shop_sign.strip_edges() == "" or shop_screen.strip_edges() == ""):
		out.append("%s: a shop with no sign or no screen" % id)
	if field != "" and field != "plaza":
		out.append("%s: field \"%s\" (only round the plaza)" % [id, field])
	if field != "" and (field_cells != 5 or cells.x < field_cells + 2 or cells.y < field_cells + 5):
		out.append("%s: field_cells %d (5: a middle cell and a core a cell in from each corner; and room round it)" % [id, field_cells])
	if field != "" and field_code.strip_edges() == "":
		out.append("%s: a field with no code on its walls" % id)
	if field != "" and shop != "":
		out.append("%s: a field and a shop (one set piece a district)" % id)
	if vault != "" and vault != "exit":
		out.append("%s: vault \"%s\" (only at the exit end)" % [id, vault])
	if vault != "" and (shop != "" or field != "" or breach != ""):
		out.append("%s: a vault with a shop, a field or a breach (one set piece a district)" % id)
	if vault != "" and (cells.x < RuinsLayout.VAULT_WIDE_LEAST or cells.x % 2 == 0 or cells.y < RuinsLayout.vault_rows_least()):
		out.append("%s: a vault needs cells at least %d wide (an odd number) and %d long" % [id, RuinsLayout.VAULT_WIDE_LEAST, RuinsLayout.vault_rows_least()])
	if vault != "" and vault_lines.strip_edges() == "":
		out.append("%s: a vault with no lines on its screen" % id)
	if vault != "" and not pristine:
		out.append("%s: a vault in a sector that is not pristine (STORY.md: clean, healthy, guarded)" % id)
	if pristine and (holes != 0 or cover != 0 or cables != 0):
		out.append("%s: pristine, but with holes, cover or cables (%d, %d, %d: all must be 0)" % [id, holes, cover, cables])
	if decay != "" and decay != "exit":
		out.append("%s: decay \"%s\" (only toward the exit)" % [id, decay])
	if decay != "" and pristine:
		out.append("%s: decay in a pristine sector (one or the other)" % id)
	if room != "" and room != "exit":
		out.append("%s: room \"%s\" (only at the exit end)" % [id, room])
	if room != "" and vault != "":
		out.append("%s: a room and a vault (one set piece at the exit end)" % id)
	if room != "" and (cells.x < RuinsLayout.ROOM_WIDE_LEAST or cells.x % 2 == 0 or cells.y < RuinsLayout.ROOM_LONG_LEAST):
		out.append("%s: a room needs cells at least %d wide (an odd number) and %d long" % [id, RuinsLayout.ROOM_WIDE_LEAST, RuinsLayout.ROOM_LONG_LEAST])
	var room_list := room_names.split("|", false)
	if room != "" and room_list.size() < 3:
		out.append("%s: a room needs at least three names for its walls" % id)
	for name in room_list:
		if not RuinsLayout.legible(name.strip_edges()):
			out.append("%s: room name \"%s\" is longer than %d or has letters the sign font has not" % [id, name, RuinsLayout.NAME_LAST])
	if board != "" and board != "plaza":
		out.append("%s: board \"%s\" (only by the plaza)" % [id, board])
	if board != "" and shop != "":
		out.append("%s: a board and a shop (one block on the edge by the plaza)" % id)
	if board != "" and board_lines.strip_edges() == "":
		out.append("%s: a board with no lines on its screen" % id)
	for line in board_lines.split("|", false):
		if not RuinsLayout.legible_up_to(line.strip_edges(), RuinsLayout.VAULT_LINE_LAST):
			out.append("%s: board line \"%s\" is longer than %d or has letters the sign font has not" % [id, line, RuinsLayout.VAULT_LINE_LAST])
		for word in RuinsLayout.NEVER_SHOWN:
			if line.to_lower().contains(word):
				out.append("%s: \"%s\" gives the story away (\"%s\")" % [id, line, word])
	for line in vault_lines.split("|", false):
		var bare := line.replace("#", "")
		if line.length() > RuinsLayout.VAULT_LINE_LAST or (bare.strip_edges() != "" and not RuinsLayout.legible_up_to(bare.strip_edges(), RuinsLayout.VAULT_LINE_LAST)):
			out.append("%s: vault line \"%s\" is longer than %d or has letters the sign font has not" % [id, line, RuinsLayout.VAULT_LINE_LAST])
		for word in RuinsLayout.NEVER_SHOWN:
			if line.to_lower().contains(word):
				out.append("%s: \"%s\" gives the story away (\"%s\")" % [id, line, word])
	for line in field_code.split("|", false):
		if line.length() > RuinsLayout.NAME_LAST:
			out.append("%s: field code \"%s\" is longer than %d" % [id, line, RuinsLayout.NAME_LAST])
		for word in RuinsLayout.NEVER_SHOWN:
			if line.to_lower().contains(word):
				out.append("%s: \"%s\" gives the story away (\"%s\")" % [id, line, word])
	var texts := folders + words
	if remnant != "":
		texts.append(remnant)
	if shop != "":
		texts.append(shop_sign)
		for line in shop_screen.split("|"):
			texts.append(line.strip_edges() if line.strip_edges() != "" else "?")
	for text in texts:
		if not RuinsLayout.legible(text):
			out.append("%s: \"%s\" has letters the sign font has not, or is longer than %d" % [id, text, RuinsLayout.NAME_LAST])
		for word in RuinsLayout.NEVER_SHOWN:
			if text.to_lower().contains(word):
				out.append("%s: \"%s\" gives the story away (\"%s\")" % [id, text, word])
	if terraces < 0 or terraces > RuinsLayout.TERRACES_MOST:
		out.append("%s: terraces %d (0 to %d)" % [id, terraces, RuinsLayout.TERRACES_MOST])
	if terraces > 0 and (drop_m < RuinsLayout.DROP_LEAST or drop_m > RuinsLayout.DROP_MOST):
		out.append("%s: drop_m %.1f (%.1f to %.1f: a jump cannot clear it, a ramp can carry it)" % [id, drop_m, RuinsLayout.DROP_LEAST, RuinsLayout.DROP_MOST])
	if terraces > 0 and cells.y < (terraces + 1) * RuinsLayout.BAND_ROWS_LEAST:
		out.append("%s: %d terraces need cells at least %d long (%d rows a band)" % [id, terraces, (terraces + 1) * RuinsLayout.BAND_ROWS_LEAST, RuinsLayout.BAND_ROWS_LEAST])
	if terraces > 0 and (vault != "" or room != "" or field != "" or pristine):
		out.append("%s: terraces with a vault, a room, a field or pristine (the flat sets)" % id)
	if water < 0.0 or water > 30.0:
		out.append("%s: water %.1f (0 none, else up to 30 m under the lowest floor)" % [id, water])
	if palette != "" and not RuinsRegister.PALETTES.has(palette):
		out.append("%s: palette \"%s\" (%s)" % [id, palette, ", ".join(RuinsRegister.PALETTES.keys())])
	if shell != "" and shell != "exit":
		out.append("%s: shell \"%s\" (only at the exit end)" % [id, shell])
	if shell != "" and (room != "" or vault != "" or board != ""):
		out.append("%s: a shell with a room, a vault or a board (one screen a district)" % id)
	if shell != "" and shell_lines.strip_edges() == "":
		out.append("%s: a shell with no lines on its screen" % id)
	if clearing < 0 or clearing > RuinsLayout.CLEARING_MOST:
		out.append("%s: clearing %d (0 to %d cells round the plaza)" % [id, clearing, RuinsLayout.CLEARING_MOST])
	if clearing > 0 and (cells.x < clearing * 2 + 5 or cells.y < clearing * 2 + 7):
		out.append("%s: a clearing of %d needs cells at least %d wide and %d long" % [id, clearing, clearing * 2 + 5, clearing * 2 + 7])
	if clearing > 0 and (vault != "" or field != "" or room != ""):
		out.append("%s: a clearing with a vault, a field or a room (one plan round the plaza)" % id)
	if shell != "":
		for line in shell_lines.split("|", false):
			if not RuinsLayout.legible_up_to(line.strip_edges(), RuinsLayout.VAULT_LINE_LAST):
				out.append("%s: shell line \"%s\" is not legible in the sign font (up to %d letters)" % [id, line.strip_edges(), RuinsLayout.VAULT_LINE_LAST])
			for word in RuinsLayout.NEVER_SHOWN:
				if line.to_lower().contains(word):
					out.append("%s: shell line \"%s\" gives the story away" % [id, line.strip_edges()])
	return out
