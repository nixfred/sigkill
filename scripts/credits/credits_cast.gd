class_name CreditsCast
extends RefCounted
## Who the credits roll names (C44, PRD 5.8, docs/STORY.md section 7), as rows of a `top`: every contributor a process,
## PID, USER (their public handle, as CREDITS.md gives it), %CPU (climbing as their row arrives) and COMMAND (their idea,
## CREDITS.md's own line for it). CREDITS.md mirrors these rows; tests/credits_test.gd holds the two to each other.
##   CAST    Fred as PID 1, init, the process that adopts everything that is left; Larry, who writes every line of the
##           code; the SIGKILL producer; then every community contributor in the order they were credited. Each has a
##           hero card too: the name as they present it publicly, their handle, what they made, the register it is drawn in.
##   THANKS  the open projects the game borrows a name, a colour or a pattern from, with thanks (CREDITS.md's sections on
##           them), as the kernel's own threads: root's, bracketed, idle; and the engine.
##   LAST    the one row that should not be there (STORY.md, pick 6). Nothing here says who it is.
## Data only: nothing here reads, runs or sends anything.

## [pid, user, cpu, command, name, line, register]: the row's four columns, then the hero card's name and its one line.
const CAST := [
	[1, "@NixFred", 99.9, "init: creator, director, kill -9 enthusiast", "Fred Nix", "creator and director: the process that adopts everything", "tron"],
	[2, "Larry", 88.4, "writes every line of code (Claude Code)", "Larry", "every line of the code", "matrix"],
	[3, "SIGKILL", 71.2, "producer, designer, daemon wrangler", "SIGKILL", "producer, designer, daemon wrangler", "cyberpunk"],
	[1337, "@QuantaCortex", 64.0, "audit_trail --visor --trace-parents", "Albert", "the Audit Trail visor: every enemy traced to its parent", "tron"],
	[1338, "@TimProvencio", 57.3, "ice --white --hunter --black --breakers", "Tim Provencio", "ICE and ICEbreakers: the machine defending itself", "matrix"],
	[1339, "@cgranier", 50.1, "man sigkill; oom-killer --boss; uptime --score", "Carlos Granier", "five ideas for after 1.0: the man page level, the OOM killer, uptime", "cyberpunk"],
	[1340, "@ocdjeremy", 44.6, "htop --visor; zoom --stepped; hitbox --real", "Jeremy", "for after 1.0: an htop visor, stepped zoom, real hitboxes", "tron"],
	[1341, "@MindGamesLabs", 38.2, "sudo grenade --tries=3", "MindGameLabs", "for after 1.0: the sudo grenade, three tries", "matrix"],
	[1342, "@timsonner", 31.9, "fsmode --rooms; filehunt --beacon", "Tim Sonner", "for after 1.0: folders as rooms, files to hunt", "cyberpunk"],
	[1343, "@gh_TechLuddite", 25.6, "gamepad --all-screens; shaders --prewarm", "TechLuddite", "pull requests: a gamepad for the whole game, and no stall on a weapon's first use", "tron"],
]
## [pid, command]: root's threads, every one idle.
const THANKS := [
	[10, "[Godot Engine] the engine itself, MIT"],
	[11, "[Dracula] the cannon's purple and green"],
	[12, "[Catppuccin] SIGTERM's pink, Mocha, Latte"],
	[13, "[Tokyo Night] the opener's terminal"],
	[14, "[Gruvbox Material] an opener palette"],
	[15, "[Nord] an opener palette"],
	[16, "[Everforest] an opener palette"],
	[17, "[10 PRINT] the pit's maze, after the C64"],
	[18, "[Omarchy] the shortcuts keybind gunplay teaches"],
]
const THANKS_USER := "root"
const THANKS_CPU := 0.0
## The hero card over the threads, and the names it lists.
const THANKS_NAME := "with thanks"
## The last row's four columns: no %CPU (it is not meant to be running).
const LAST := [6666, "~", "", "thanks for running me"]
## The roll's own process: what the final command names.
const TOP := "top"
## The columns' widths, in characters: PID, USER, %CPU (COMMAND takes the rest).
const PID_W := 5
const USER_W := 15  # one wider for "@gh_TechLuddite" (a GitHub-declared X handle is 15 characters)
const CPU_W := 5
## How many characters of COMMAND the table's window holds (W2, C44's leftover): a longer one is cut there and marked
## with a "+", as top marks a field cut to its column; the hero card shows it whole.
const COMMAND_ROOM := 44


## Every row in the order it arrives: the cast, the threads, the last. Each [pid, user, cpu text, command].
static func rows() -> Array:
	var out: Array = []
	for c in CAST:
		out.append([str(c[0]), c[1], cpu_text(c[2]), c[3]])
	for t in THANKS:
		out.append([str(t[0]), THANKS_USER, cpu_text(THANKS_CPU), t[1]])
	out.append([str(LAST[0]), LAST[1], LAST[2], LAST[3]])
	return out


## Row `fields` as the table draws it: its columns padded to their widths.
static func row_text(fields: Array) -> String:
	return "%s  %s  %s  %s" % [str(fields[0]).lpad(PID_W), str(fields[1]).rpad(USER_W), str(fields[2]).lpad(CPU_W), str(fields[3])]


## Row `fields` as the table's window draws it: row_text() with COMMAND cut to COMMAND_ROOM (W2).
static func table_text(fields: Array) -> String:
	var cut := fields.duplicate()
	cut[3] = table_command(str(fields[3]))
	return row_text(cut)


## A COMMAND as the table's window holds it: whole when it fits COMMAND_ROOM, else cut and marked "+" (W2).
static func table_command(cmd: String) -> String:
	return cmd if cmd.length() <= COMMAND_ROOM else cmd.left(COMMAND_ROOM - 1) + "+"


## Row `fields` as words: its columns that have anything in them, one space between ("6666 ~ thanks for running me").
static func row_words(fields: Array) -> String:
	var out := PackedStringArray()
	for f in fields:
		if str(f).strip_edges() != "":
			out.append(str(f).strip_edges())
	return " ".join(out)


## The table's column heads, as the table draws them.
static func head_text() -> String:
	return "%s  %s  %s  %s" % ["PID".lpad(PID_W), "USER".rpad(USER_W), "%CPU".lpad(CPU_W), "COMMAND"]


static func cpu_text(cpu: float) -> String:
	return "%.1f" % cpu


## The names the thanks card lists: each thread's bracketed name.
static func thanks_names() -> PackedStringArray:
	var out := PackedStringArray()
	for t in THANKS:
		var s: String = t[1]
		out.append(s.substr(1, s.find("]") - 1))
	return out
