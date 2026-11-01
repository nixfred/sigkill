class_name KeyBook
extends RefCounted
## Keybind gunplay (W4, PRD 5.5: "keybind gunplay mapped to real Omarchy shortcuts (opt-in, no conflicts)"): the
## shortcut table the mode teaches, the shortcuts that are weapons in it, the key that stands in for Super, and the cards
## a shortcut shows when it is used. Data only: nothing here reads, writes, sends or runs anything.
##
## The table (DEFAULTS) is the game's own copy of Omarchy's public default key bindings, Super with one key, as Omarchy's
## own files write them (SOURCE, credited in CREDITS.md): the combo and the description Omarchy gives it, nothing else.
## Left out, each for a reason: Super with Ctrl or Alt (no Ctrl or Alt chord anywhere in SIGKILL), Super+Escape (Esc is the
## game's menu), Super+grave (the stand-in key below is grave), Super+Print (the desktop takes Print before any window
## sees it), and the mouse's (the mouse aims and fires).
##
## Super itself is the desktop's: the compositor takes every Super chord it binds before a window sees it, and the game
## never asks a player to unbind one. So in the game a single key it holds stands in for Super (STANDIN, grave: the key
## left of 1, which nothing in the game uses and Omarchy binds only with Super). Hold it and the next key is the chord:
## every card shows the real one ("SUPER + W   Close window") and how it was played here ("` + W").
##
## The opt-in real layer (scripts/keys/key_reader.gd) hands in the player's own binds, combos and descriptions only:
## resolve() lays them over this table, so each weapon fires from the chord the player's own desktop gives its meaning.

## Where the table comes from: Omarchy's default bindings, at the commit the table was copied from.
const SOURCE := "Omarchy's default key bindings (basecamp/omarchy, default/hypr/bindings, MIT)"
const SOURCE_URL := "https://github.com/basecamp/omarchy/tree/63f60f4fcc4786d97e5c0384be640bcdef46f9a1/default/hypr/bindings"
## The key that stands in for Super (physical: the same place on every layout), and what it is called on screen.
const STANDIN := KEY_QUOTELEFT
const STANDIN_NAME := "`"
const STANDIN_SAID := "the ` key (left of 1)"
const SUPER := "SUPER"

## Omarchy's defaults, Super with one key: [combo, description], as Omarchy's files write them (its workspaces are made
## in a loop there, `code:10` to `code:19`, written here as the digits they are).
const DEFAULTS := [
	["SUPER + RETURN", "Terminal"],
	["SUPER + W", "Close window"],
	["SUPER + Q", "Close window"],
	["SUPER + J", "Toggle window split"],
	["SUPER + T", "Toggle window floating/tiling"],
	["SUPER + F", "Full screen"],
	["SUPER + TAB", "Next workspace"],
	["SUPER + K", "Keybindings"],
	["SUPER + SPACE", "Omarchy menu"],
	["SUPER + P", "Pseudo window"],
	["SUPER + O", "Pop window out (float & pin)"],
	["SUPER + L", "Cycle workspace layout"],
	["SUPER + S", "Toggle scratchpad"],
	["SUPER + M", "Minimize window to the dock"],
	["SUPER + G", "Toggle window grouping"],
	["SUPER + Home", "Restore window width"],
	["SUPER + BACKSPACE", "Toggle transparency on a window"],
	["SUPER + comma", "Dismiss, invoke, or focus last notification"],
	["SUPER + SLASH", "Monitor scaling up"],
	["SUPER + code:20", "Expand window left"],
	["SUPER + code:21", "Shrink window left"],
	["SUPER + LEFT", "Focus on left window"],
	["SUPER + RIGHT", "Focus on right window"],
	["SUPER + UP", "Focus on above window"],
	["SUPER + DOWN", "Focus on below window"],
	["SUPER + A", "Select all"],
	["SUPER + C", "Universal copy"],
	["SUPER + V", "Universal paste"],
	["SUPER + X", "Universal cut"],
	["SUPER + 1", "Switch to workspace 1"],
	["SUPER + 2", "Switch to workspace 2"],
	["SUPER + 3", "Switch to workspace 3"],
	["SUPER + 4", "Switch to workspace 4"],
	["SUPER + 5", "Switch to workspace 5"],
	["SUPER + 6", "Switch to workspace 6"],
	["SUPER + 7", "Switch to workspace 7"],
	["SUPER + 8", "Switch to workspace 8"],
	["SUPER + 9", "Switch to workspace 9"],
	["SUPER + 0", "Switch to workspace 10"],
]
## Shortcuts the game never takes as a chord, whatever a player's binds say: the menu's key, the stand-in itself, the
## desktop's screenshot key.
const NEVER := ["ESCAPE", "GRAVE", "PRINT"]

## The shortcuts that are weapons here, by id: the meaning they answer to (Omarchy's description), what they do in the game,
## their cooldown (seconds) and their colour. "goto" answers every "Switch to workspace <n>".
const WEAPONS := {
	"terminal": {"meaning": "Terminal", "here": "a terminal blasts open where you aim", "cool": 1.1},
	"close": {"meaning": "Close window", "here": "folds the daemon under your crosshair shut", "cool": 5.0},
	"split": {"meaning": "Toggle window split", "here": "splits the daemon down its middle", "cool": 3.0},
	"float": {"meaning": "Toggle window floating/tiling", "here": "floats the daemon up in a window, then tiles it into the floor", "cool": 6.0},
	"fullscreen": {"meaning": "Full screen", "here": "every daemon on your screen takes the hit", "cool": 14.0},
	"workspace": {"meaning": "Next workspace", "here": "slides you to the next workspace", "cool": 3.5},
	"goto": {"meaning": "Switch to workspace", "here": "slides you to that workspace", "cool": 3.5},
	"keys": {"meaning": "Keybindings", "here": "lists every shortcut (as Omarchy's own does)", "cool": 0.0},
}
## The drills, in order: one a weapon.
const DRILLS := ["terminal", "close", "split", "float", "fullscreen", "workspace"]
## What a key that is not a weapon here says it would do.
const NOT_HERE := "not a weapon here: on your desktop only"

## Key names as binds write them, upper case, and the key each is (Godot's physical keycode).
const KEY_TOKENS := {
	"RETURN": KEY_ENTER, "ENTER": KEY_ENTER, "TAB": KEY_TAB, "SPACE": KEY_SPACE, "BACKSPACE": KEY_BACKSPACE,
	"COMMA": KEY_COMMA, "PERIOD": KEY_PERIOD, "SLASH": KEY_SLASH, "MINUS": KEY_MINUS, "EQUAL": KEY_EQUAL,
	"SEMICOLON": KEY_SEMICOLON, "APOSTROPHE": KEY_APOSTROPHE, "BRACKETLEFT": KEY_BRACKETLEFT,
	"BRACKETRIGHT": KEY_BRACKETRIGHT, "BACKSLASH": KEY_BACKSLASH, "LEFT": KEY_LEFT, "RIGHT": KEY_RIGHT, "UP": KEY_UP,
	"DOWN": KEY_DOWN, "HOME": KEY_HOME, "END": KEY_END, "PAGE_UP": KEY_PAGEUP, "PAGE_DOWN": KEY_PAGEDOWN,
	"INSERT": KEY_INSERT, "DELETE": KEY_DELETE,
	"F1": KEY_F1, "F2": KEY_F2, "F3": KEY_F3, "F4": KEY_F4, "F5": KEY_F5, "F6": KEY_F6, "F7": KEY_F7, "F8": KEY_F8,
	"F9": KEY_F9, "F10": KEY_F10, "F11": KEY_F11, "F12": KEY_F12,
	"A": KEY_A, "B": KEY_B, "C": KEY_C, "D": KEY_D, "E": KEY_E, "F": KEY_F, "G": KEY_G, "H": KEY_H, "I": KEY_I, "J": KEY_J,
	"K": KEY_K, "L": KEY_L, "M": KEY_M, "N": KEY_N, "O": KEY_O, "P": KEY_P, "Q": KEY_Q, "R": KEY_R, "S": KEY_S, "T": KEY_T,
	"U": KEY_U, "V": KEY_V, "W": KEY_W, "X": KEY_X, "Y": KEY_Y, "Z": KEY_Z,
	"0": KEY_0, "1": KEY_1, "2": KEY_2, "3": KEY_3, "4": KEY_4, "5": KEY_5, "6": KEY_6, "7": KEY_7, "8": KEY_8, "9": KEY_9,
}
## X keycodes binds write as `code:<n>` (Omarchy's workspaces and its resize keys), as the key names above.
const CODES := {"code:10": "1", "code:11": "2", "code:12": "3", "code:13": "4", "code:14": "5", "code:15": "6", "code:16": "7", "code:17": "8", "code:18": "9", "code:19": "0", "code:20": "MINUS", "code:21": "EQUAL", "code:49": "GRAVE", "code:9": "ESCAPE"}
## How a key is written on its keycap.
const CAPS := {"RETURN": "RETURN", "COMMA": ",", "PERIOD": ".", "SLASH": "/", "MINUS": "-", "EQUAL": "=", "SEMICOLON": ";", "APOSTROPHE": "'", "BRACKETLEFT": "[", "BRACKETRIGHT": "]", "BACKSLASH": "\\", "BACKSPACE": "BKSP", "PAGE_UP": "PGUP", "PAGE_DOWN": "PGDN", "DELETE": "DEL", "INSERT": "INS"}
const MODS := ["SUPER", "SHIFT", "CTRL", "ALT"]


## A combo as binds write it ("SUPER + w", "super+code:10", "SUPER SHIFT, Return") in one form: the modifiers in MODS's
## order, then the key in upper case ("SUPER + W", "SUPER + 1", "SUPER + RETURN"); "" when it has no key.
static func normal(combo: String) -> String:
	var parts := combo.replace(",", "+").replace(" ", "+").split("+", false)
	var mods := {}
	var key := ""
	for p in parts:
		var t := p.strip_edges()
		if t == "":
			continue
		var up := t.to_upper()
		match up:
			"SUPER", "MOD4", "WIN", "META", "$MAINMOD":
				mods["SUPER"] = true
			"SHIFT":
				mods["SHIFT"] = true
			"CTRL", "CONTROL":
				mods["CTRL"] = true
			"ALT", "MOD1":
				mods["ALT"] = true
			_:
				key = CODES.get(t.to_lower(), up)
	if key == "":
		return ""
	if key == "ENTER":
		key = "RETURN"
	var out := PackedStringArray()
	for m in MODS:
		if mods.has(m):
			out.append(m)
	out.append(key)
	return " + ".join(out)


## The key of combo `normal_combo` (its last part).
static func key_token(normal_combo: String) -> String:
	var parts := normal_combo.split(" + ")
	return parts[parts.size() - 1] if not parts.is_empty() else ""


## True when the game can play combo `normal_combo` as a chord: Super and one key it can read (no Shift, Ctrl or Alt),
## never one of NEVER.
static func playable(normal_combo: String) -> bool:
	var parts := normal_combo.split(" + ")
	if parts.size() != 2 or parts[0] != SUPER:
		return false
	var key := parts[1]
	return not NEVER.has(key) and KEY_TOKENS.has(key) and KEY_TOKENS[key] != STANDIN


## The key a playable combo is played with here (Godot's keycode), or KEY_NONE.
static func keycode_of(normal_combo: String) -> int:
	if not playable(normal_combo):
		return KEY_NONE
	return int(KEY_TOKENS[key_token(normal_combo)])


## What a key is written as on its keycap.
static func cap_of(token: String) -> String:
	return str(CAPS.get(token, token))


## The weapon a meaning answers to ("Close window" -> "close"; "Switch to workspace 3" -> "goto"), or "".
static func weapon_of(meaning: String) -> String:
	var m := meaning.strip_edges().to_lower()
	for id in WEAPONS:
		var want := str(WEAPONS[id]["meaning"]).to_lower()
		if m == want or (id == "goto" and m.begins_with(want + " ")):
			return id
	return ""


## The workspace number a "Switch to workspace <n>" meaning names, or 0.
static func workspace_of(meaning: String) -> int:
	var tail := meaning.strip_edges().get_slice(" ", 3)
	return int(tail) if tail.is_valid_int() else 0


## The table the mode plays: every playable chord's key -> {combo, meaning, weapon, workspace}, laid out from `binds` (the
## player's, the real layer's; empty for the built-in table): each [combo, description] in order, a later one for the same
## key replacing the earlier (as a later bind does), `unbind` entries ({"unbind": combo}) taking one away. Only playable
## chords are kept; a key two meanings ask for keeps the later.
static func resolve(binds: Array = []) -> Dictionary:
	var source: Array = []
	if binds.is_empty():
		for d in DEFAULTS:
			source.append({"combo": d[0], "name": d[1]})
	else:
		source = binds
	var by_key := {}
	for b in source:
		var combo := normal(str(b.get("combo", b.get("unbind", ""))))
		if combo == "" or not playable(combo):
			continue
		var key := keycode_of(combo)
		if b.has("unbind"):
			by_key.erase(key)
			continue
		var name := str(b.get("name", "")).strip_edges()
		if name == "":
			by_key.erase(key)  # bound to something with no name: not a shortcut the game can teach
			continue
		by_key[key] = {"combo": combo, "meaning": name, "weapon": weapon_of(name), "workspace": workspace_of(name)}
	return by_key


## Every chord a weapon answers to in `table`, by weapon id: [combo, ...] in the table's key order.
static func chords_of(table: Dictionary) -> Dictionary:
	var out := {}
	for key in table:
		var w := str(table[key]["weapon"])
		if w == "":
			continue
		if not out.has(w):
			out[w] = []
		(out[w] as Array).append(str(table[key]["combo"]))
	return out


## The chord shown for weapon `id` in `table`: its first, the built-in one when the table has none, "" when neither.
static func chord_for(table: Dictionary, id: String) -> String:
	var chords := chords_of(table)
	if chords.has(id) and not (chords[id] as Array).is_empty():
		var defaults := default_chords(id)
		for c in chords[id]:
			if defaults.has(c):
				return str(c)  # the default chord first, while the player's desktop still has it
		return str(chords[id][0])
	return ""


## The built-in chords of weapon `id`.
static func default_chords(id: String) -> PackedStringArray:
	var out := PackedStringArray()
	for d in DEFAULTS:
		if weapon_of(d[1]) == id:
			out.append(normal(d[0]))
	return out


## The built-in description of combo `normal_combo`, or "".
static func default_meaning(normal_combo: String) -> String:
	for d in DEFAULTS:
		if normal(d[0]) == normal_combo:
			return d[1]
	return ""


## The card a chord shows when it is used: its combo, its keys (keycaps), Omarchy's meaning, what it does here, how it was
## played here. `entry` is a table entry; `cooling` the seconds it has left (0 ready).
static func card(entry: Dictionary, cooling: float = 0.0) -> Dictionary:
	var combo := str(entry["combo"])
	var token := key_token(combo)
	var weapon := str(entry.get("weapon", ""))
	var here := NOT_HERE
	if weapon != "":
		here = str(WEAPONS[weapon]["here"])
	return {
		"combo": combo,
		"caps": PackedStringArray([SUPER, cap_of(token)]),
		"meaning": str(entry["meaning"]),
		"weapon": weapon,
		"here": here,
		"played": "%s + %s" % [STANDIN_NAME, cap_of(token)],
		"cooling": cooling,
	}


## Every way the table and the game's keys could clash, in words ("" none): the stand-in on a key the game already uses
## (`game_keys`: keycode -> what uses it) or on a modifier or Esc; any table combo with Ctrl or Alt; any chord on the
## stand-in or Esc; a weapon with no chord. The checks (step 68) hand in the game's own keys.
static func problems(table: Dictionary, game_keys: Dictionary) -> PackedStringArray:
	var out := PackedStringArray()
	if game_keys.has(STANDIN):
		out.append("the stand-in for Super is the game's %s" % str(game_keys[STANDIN]))
	if [KEY_ESCAPE, KEY_CTRL, KEY_ALT, KEY_META, KEY_SHIFT, KEY_HYPER].has(STANDIN):
		out.append("the stand-in for Super is a modifier or Esc")
	for d in DEFAULTS:
		var c := normal(d[0])
		if c.contains("CTRL") or c.contains("ALT"):
			out.append("a Ctrl or Alt combo in the table: " + c)
		if not playable(c):
			out.append("a table combo the game cannot play: " + c)
	for key in table:
		var e: Dictionary = table[key]
		if int(key) == STANDIN or int(key) == KEY_ESCAPE:
			out.append("a chord on the stand-in or Esc: " + str(e["combo"]))
		if str(e["combo"]).contains("CTRL") or str(e["combo"]).contains("ALT"):
			out.append("a Ctrl or Alt chord: " + str(e["combo"]))
	for id in DRILLS:
		if chord_for(table, id) == "":
			out.append("weapon %s has no chord" % id)
	return out
