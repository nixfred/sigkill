extends SceneTree
## Headless test of the credits roll (C44, PRD 5.8, docs/STORY.md section 7). scripts/check.sh runs it as step 64, and any
## FAIL exits 1.
##
##   godot --headless --path . --fixed-fps 60 --script res://tests/credits_test.gd
##
## The cast: its last row is exactly "6666 ~ thanks for running me", after every other; every contributor CREDITS.md
## names (its `top` block row for row, the community table's names and handles, every project it thanks) is in the roll
## and is shown as it plays; nothing in it names a model. The code: nothing the credits run reads, runs, signals or
## sends anything. The score: made in code, its three parts the lengths the roll keeps time by. In the arena: the roll
## never opens in free play or on any other mission's win (mission 1 completed: its card is Next, never Credits); the
## finale won, the save records the campaign finished, its card's Credits rolls it once (over the card, the player's
## input stopped, the 3D view not drawn under it): `$ top` typing, the summary and the heads, the title card, the cast
## arriving in order (Fred PID 1, init, first), the threads, the last row, the prompt waiting for the player's own
## kill -9 (fire), the command, the shot, SIGKILL on the hexagon, the bare `>_`, and the Missions screen, the roll never
## again for that ending. A second ending left by Free play: the roll again (once), Esc (a real key) skipping to the bare
## prompt and Esc past it, and free play after. The Esc menu: no Credits until the campaign is finished (and none in a
## mission); once it is, Credits replays the roll over the paused arena, typing its own kill -9 when the player waits,
## and gives the menu back as it was, the save unchanged. Its files live in its own folder under user://, removed at
## the end.

const MainScene = preload("res://scenes/main.tscn")
const Link = preload("res://scripts/guide/guide_link.gd")
const Controls = preload("res://scripts/controls.gd")
const SettingsApply = preload("res://scripts/settings/settings_apply.gd")

## Every community contributor, in the order they were credited (PRD 5.8; W2 adds the sixth, Tim Sonner; the seventh, TechLuddite, came by pull request).
const CONTRIBUTORS := ["@QuantaCortex", "@TimProvencio", "@cgranier", "@ocdjeremy", "@MindGamesLabs", "@timsonner", "@gh_TechLuddite"]
const LAST_ROW := "6666 ~ thanks for running me"
const CREDITS_CODE := ["res://scripts/credits/credits_roll.gd", "res://scripts/credits/credits_cast.gd", "res://scripts/credits/credits_score.gd", "res://scripts/hud/credits_handoff.gd"]
const NEVER := ["OS.execute", "create_process", "OS.kill", "shell_open", "HTTPRequest", "HTTPClient", "PacketPeer", "StreamPeer", "TCPServer", "UDPServer", "WebSocket", "FileAccess", "get_file_as_string", "DirAccess", "OS.get_environment", "get_user_data_dir", "get_system_dir", "get_executable_path", "OpenerData", "RealData", "OS.get_name", "get_unique_id"]
## A model named in a credit, caught by its shape rather than a list of names: the maker's family name anywhere but in
## "Claude Code" (the tool Larry codes in, CREDITS.md's own words), the words "model" or "LLM", or a size tag such as
## "name:7b".
const MODELS := "(?i)\\bclaude(?!\\s+code\\b)|\\bmodels?\\b|\\bllms?\\b|\\b[a-z][a-z0-9.\\-]*:[0-9.]+[bm]\\b"
const MOST_FRAMES := 3600
const LONG_ROUND_S := 100000.0

var _fails := 0
var _checks := 0
var _abs := ""
## Every line the roll showed across the finale's run.
var _seen := {}


func _initialize() -> void:
	_run()


func _run() -> void:
	await process_frame
	root.size = Vector2i(1280, 720)
	_abs = ProjectSettings.globalize_path("user://credits-test-%d" % OS.get_process_id())
	if DirAccess.dir_exists_absolute(_abs):
		print("FAIL the test's own folder already exists; not touching it")
		quit(1)
		return
	DirAccess.make_dir_recursive_absolute(_abs)
	Controls.ensure()
	GameSettings.current().reset()
	SettingsApply.apply_audio(GameSettings.current())
	MissionRunner.clear_pending()
	MissionProgress.current().path = _abs.path_join("progress.cfg")
	MissionProgress.current().clear()
	Progress.current().path = _abs.path_join("progress.cfg")
	Progress.current().clear()
	_code_checks()
	_cast_checks()
	_score_checks()
	await _elsewhere_checks()
	await _ending_checks()
	await _second_ending_checks()
	await _replay_checks()
	_seen_checks()
	await _cleanup()
	print("CREDITS: %d checks" % _checks)
	print("CREDITS RESULT: ", "ALL PASS" if _fails == 0 else "%d FAILED" % _fails)
	quit(0 if _fails == 0 else 1)


func _check(label: String, ok: bool, detail: String = "") -> void:
	_checks += 1
	print("PASS " if ok else "FAIL ", label, ("   " + detail) if detail != "" else "")
	if not ok:
		_fails += 1


# --- The code, the cast, the score. ---

func _code_checks() -> void:
	var found := PackedStringArray()
	for path in CREDITS_CODE:
		var code := _code_of(path)
		for word in NEVER:
			if code.contains(word):
				found.append("%s: %s" % [path.get_file(), word])
	_check("the credits touch nothing of the player's: nothing they run opens a file or a folder, runs or signals a program, opens a connection or reads the environment, a path or the opener's data (kill -9 is text on screen; the derezz is drawn)", found.is_empty(), ", ".join(found))


func _code_of(path: String) -> String:
	var out := PackedStringArray()
	for line in FileAccess.get_file_as_string(path).split("\n"):
		var at := line.find("#")
		out.append(line.substr(0, at) if at >= 0 else line)
	return "\n".join(out)


func _cast_checks() -> void:
	var rows := CreditsCast.rows()
	var last: Array = rows[rows.size() - 1]
	var others_before := true
	for i in rows.size() - 1:
		others_before = others_before and str(rows[i][0]) != "6666" and str(rows[i][1]) != "~"
	_check("the last row is exactly \"%s\" (STORY.md, pick 6), after every contributor and every thread, and nowhere else" % LAST_ROW, CreditsCast.row_words(last) == LAST_ROW and others_before and rows.size() == CreditsCast.CAST.size() + CreditsCast.THANKS.size() + 1, CreditsCast.row_words(last))
	var first: Array = CreditsCast.CAST[0]
	_check("Fred is PID 1, init (@NixFred), the first row; Larry and the producer next; every community contributor after them with their handle as USER", int(first[0]) == 1 and str(first[1]) == "@NixFred" and str(first[3]).begins_with("init") and str(CreditsCast.CAST[1][1]) == "Larry" and str(CreditsCast.CAST[2][1]) == "SIGKILL")
	# CREDITS.md mirrors the roll: its `top` block row for row, its community table's names and handles, every project it thanks.
	var md := FileAccess.get_file_as_string("res://CREDITS.md")
	var block := PackedStringArray()
	var inside := false
	for line in md.split("\n"):
		if line.begins_with("$ top -p sigkill --credits"):
			inside = true
			continue
		if inside and line.begins_with("```"):
			break
		if inside and not line.strip_edges().begins_with("PID") and line.strip_edges() != "":
			block.append(_words(line))
	var cast_words := PackedStringArray()
	for i in CreditsCast.CAST.size():
		cast_words.append(CreditsCast.row_words(rows[i]))
	_check("CREDITS.md's `top` block is the roll's cast, row for row (%d rows)" % block.size(), block == cast_words, "md [%s] roll [%s]" % [" | ".join(block), " | ".join(cast_words)])
	var people := _md_people(md)
	var missing := PackedStringArray()
	for p in people:
		var hit := false
		for c in CreditsCast.CAST:
			hit = hit or (str(c[4]) == p[0] and str(c[1]) == p[1])
		if not hit:
			missing.append("%s %s" % p)
	var handles := PackedStringArray()
	for p in people:
		handles.append(p[1])
	_check("every community contributor in CREDITS.md's table is a row of the roll, name and handle as CREDITS.md gives them (%d: %s)" % [people.size(), ", ".join(handles)], people.size() >= CONTRIBUTORS.size() and missing.is_empty(), ", ".join(missing))
	# The community contributors as rows, in the order they were credited (W2 adds the sixth, Tim Sonner; TechLuddite the seventh), all before 6666.
	var order := PackedStringArray()
	for i in range(3, CreditsCast.CAST.size()):
		order.append(str(CreditsCast.CAST[i][1]))
	var sixth := CreditsCast.CAST[CreditsCast.CAST.size() - 2] as Array
	var seventh := CreditsCast.CAST[CreditsCast.CAST.size() - 1] as Array
	_check("the community contributors are rows in the order they were credited (%s), the sixth \"Tim Sonner (@timsonner)\" after MindGameLabs, the seventh \"TechLuddite (@gh_TechLuddite)\" after him and before the last row" % ", ".join(order), order == PackedStringArray(CONTRIBUTORS) and str(sixth[4]) == "Tim Sonner" and str(sixth[1]) == "@timsonner" and str(seventh[4]) == "TechLuddite" and str(seventh[1]) == "@gh_TechLuddite", ", ".join(order))
	_check("the score keeps two bars a cast row before the threads (THANKS_BAR %d = CAST_BAR %d + CAST_EVERY %d x %d rows), a bell for every row" % [CreditsScore.THANKS_BAR, CreditsScore.CAST_BAR, CreditsScore.CAST_EVERY, CreditsCast.CAST.size()], CreditsScore.THANKS_BAR == CreditsScore.CAST_BAR + CreditsScore.CAST_EVERY * CreditsCast.CAST.size() and CreditsScore.ROW_BELLS.size() >= CreditsCast.CAST.size() and CreditsScore.LAST_BAR > CreditsScore.QUIET_BAR and CreditsScore.ROLL_BARS > CreditsScore.LAST_BAR)
	# Long commands (W2, C44's leftover): the table cuts one at its window, marked "+", and the hero card shows it whole.
	var fits := true
	var whole := true
	for c in CreditsCast.CAST + [[0, "@long", 1.0, "make --a-very-long-contributor-command --that --never --fits --in --one --line --of --any --card", "Long", "line", "tron"]]:
		var cut := CreditsCast.table_text([str(c[0]), c[1], "1.0", c[3]])
		fits = fits and cut.length() <= CreditsCast.row_text(["", "", "", ""]).length() + CreditsCast.COMMAND_ROOM
		for per in [12, 24, 40]:
			var lines := CreditsRoll.card_command_lines("$ " + str(c[3]), per)
			whole = whole and " ".join(lines) == "$ " + str(c[3]) and Array(lines).all(func(l): return l.length() <= per or not l.contains(" "))
	_check("a long COMMAND is cut at the table's window (\"+\", as top marks a cut field) and shown whole on its card, wrapped between words", fits and whole and CreditsCast.table_command("x".repeat(60)).ends_with("+") and CreditsCast.table_command("x".repeat(60)).length() == CreditsCast.COMMAND_ROOM)
	var thanked := _md_thanked(md)
	var names := CreditsCast.thanks_names()
	var unthanked := PackedStringArray()
	for t in thanked:
		if not names.has(t):
			unthanked.append(t)
	_check("every project CREDITS.md thanks is one of the roll's threads, and the engine too (%s)" % ", ".join(thanked), thanked.size() >= 8 and unthanked.is_empty() and names.has("Godot Engine") and names.has("10 PRINT"), ", ".join(unthanked))
	var bad := _models_in(CreditsRoll.every_line())
	_check("no model names anywhere in the roll (Larry credited as CREDITS.md does: \"writes every line of code (Claude Code)\")", bad.is_empty(), ", ".join(bad))


## [name, handle] of every row of CREDITS.md's community table.
func _md_people(md: String) -> Array:
	var out: Array = []
	var re := RegEx.create_from_string("^\\| ([^|/]+?) / \\[(@[A-Za-z0-9_]+)\\]")
	for line in md.split("\n"):
		var m := re.search(line)
		if m != null:
			out.append([m.get_string(1).strip_edges(), m.get_string(2)])
	return out


## The names of every project CREDITS.md thanks (its links outside the community table), and 10 PRINT.
func _md_thanked(md: String) -> PackedStringArray:
	var out := PackedStringArray()
	var from := md.find("## Names the skins borrow")
	var re := RegEx.create_from_string("\\[([^\\]]+)\\]\\((https?://[^)]+)\\)")
	for m in re.search_all(md.substr(from)):
		var name := m.get_string(1)
		if not m.get_string(2).contains("x.com") and not out.has(name):
			out.append(name)
	if md.contains("10 PRINT"):
		out.append("10 PRINT")
	return out


func _models_in(lines: PackedStringArray) -> PackedStringArray:
	var re := RegEx.create_from_string(MODELS)
	var out := PackedStringArray()
	for line in lines:
		var m := re.search(line)
		if m != null:
			out.append("%s (in \"%s\")" % [m.get_string(), line])
	return out


func _score_checks() -> void:
	var t0 := Time.get_ticks_msec()
	CreditsScore.drop()
	CreditsScore.make_now()
	var ms := Time.get_ticks_msec() - t0
	var ok := CreditsScore.ready_now()
	var lens := PackedStringArray()
	for part in CreditsScore.CREDIT_PARTS:
		var s := CreditsScore.part(part)
		ok = ok and s != null and absf(s.get_length() - CreditsScore.credit_seconds(part)) < 0.05
		lens.append("%s %.1f s" % [part, s.get_length() if s != null else -1.0])
		if part == "wait":
			ok = ok and s.loop_mode == AudioStreamWAV.LOOP_FORWARD
	_check("the score is made in code (%d ms): %s; the wait loops; the roll's beats on its bars (the prompt at %.1f s, the end of the roll part)" % [ms, ", ".join(lens), CreditsRoll.WAIT_AT], ok and absf(CreditsRoll.WAIT_AT - CreditsScore.credit_seconds("roll")) < 0.001)


# --- In the arena. ---

func _elsewhere_checks() -> void:
	var main := await _arena()
	var plays := CreditsRoll.plays
	await _frames(120)
	var mh: MissionHud = main.get_node("Hud").mission_hud()
	var menu = main.get_node("Hud").pause_menu()
	menu.open()
	await _frames(2)
	var hidden: bool = not menu.credits_button().visible and menu.open_credits() == null
	menu.close()
	_check("free play: no roll in 120 frames of the arena, and with the campaign not finished the Esc menu has no Credits at all (open_credits() refuses)", CreditsRoll.plays == plays and not mh.credits_screen().is_up() and hidden)
	# Mission 1 won: its card goes on to mission 2; nothing rolls.
	var runner := MissionRunner.of(main)
	var old_id := main.get_instance_id()
	runner.begin(MissionBook.at(1))
	main = await _after_reload(old_id)
	runner = MissionRunner.of(main)
	mh = main.get_node("Hud").mission_hud()
	await _until(func(): return runner.state == MissionRunner.State.RUNNING)
	runner._complete()
	var end: MissionEndScreen = mh.end_screen()
	var card := await _until(func(): return end.is_up())
	var first := end.buttons()[0].text
	var refused := not runner.roll_credits("missions")
	old_id = main.get_instance_id()
	end.choose("missions")
	var rolled: bool = mh.credits_screen().is_up()
	await _frames(3)
	var non_finale := true
	for i in range(1, MissionBook.campaign().size()):
		non_finale = non_finale and not MissionRunner.is_finale(MissionBook.at(i))
	_check("any other mission's win never rolls them: mission 1 complete, its card's first choice \"%s\", the runner refusing the roll, Missions taken with no roll; only mission 7 is the finale" % first, card and first.begins_with("Next") and refused and CreditsRoll.plays == plays and not rolled and non_finale and MissionRunner.is_finale(MissionBook.at(7)) and not MissionProgress.current().campaign_finished())
	main = await _after_reload(old_id)


func _ending_checks() -> void:
	var main := current_scene
	var runner := MissionRunner.of(main)
	var old_id := main.get_instance_id()
	runner.begin(MissionBook.at(7))
	main = await _after_reload(old_id)
	runner = MissionRunner.of(main)
	var mh: MissionHud = main.get_node("Hud").mission_hud()
	var player = main.get_node("Player")
	await _until(func(): return runner.state == MissionRunner.State.RUNNING)
	runner.life.shield(100000.0)
	var plays := CreditsRoll.plays
	runner._complete()
	var cfg := ConfigFile.new()
	var loaded := cfg.load(MissionProgress.current().path) == OK
	_check("the ending reached, the save records the campaign finished ([missions] finished=true in the progress file, mission 7 done)", MissionProgress.current().campaign_finished() and loaded and cfg.get_value("missions", "finished", false) == true and MissionProgress.current().is_done("kill_9"))
	var end: MissionEndScreen = mh.end_screen()
	await _until(func(): return end.is_up())
	_check("the finale's card: \"exit 0\" and Credits first, and no roll yet", end.buttons()[0].text == MissionEndScreen.CREDITS and CreditsRoll.plays == plays and not mh.credits_screen().is_up())
	var credits: CreditsHandoff = mh.credits_screen()
	var roll := credits.roll()
	old_id = main.get_instance_id()
	end.choose("next")
	await _frames(2)
	var rolled: bool = is_instance_valid(credits) and credits.is_up()
	_check("Credits rolls them, once, for the ending, over the card (the card down, the player's input stopped)", rolled and roll.reason == "ending" and CreditsRoll.plays == plays + 1 and not end.is_up() and player.input_blocked)
	if not rolled:
		await _skip_reload(old_id)
		return
	await _until(func(): return roll.elapsed() >= CreditsRoll.FADE_S + 0.1)
	await _frames(2)
	_check("once the screen is black, the arena's 3D view is not drawn under it", root.disable_3d)
	# The roll, swept on its own clock.
	var orders := []
	var t := 0.0
	var typing_seen := false
	var title_card := false
	while t < CreditsRoll.WAIT_AT + 0.6:
		t += 0.25
		roll.seek(t)
		await process_frame
		for line in roll.shown_text():
			_seen[line] = true
		typing_seen = typing_seen or (roll.phase_name() == "typing" and roll.shown_text()[0].begins_with("$ top"))
		title_card = title_card or roll.hero_text().has(CreditsRoll.CARD_TITLE)
		var shown := roll.shown_rows()
		if orders.is_empty() or (orders.back() as PackedStringArray).size() != shown.size():
			orders.append(shown)
	var full: PackedStringArray = orders.back()
	var in_order := full.size() == roll.rows().size()
	for i in full.size():
		in_order = in_order and full[i] == CreditsCast.table_text(roll.rows()[i])
	var grew := true
	for i in range(1, orders.size()):
		var a: PackedStringArray = orders[i - 1]
		var b: PackedStringArray = orders[i]
		grew = grew and b.size() >= a.size() and b.slice(0, a.size()) == a
	_check("the roll plays STORY.md's beats in order: `$ top -p sigkill --credits` typing itself, top's summary and column heads, the title card, then a row at a time, each kept as the next arrives (%d steps), Fred's PID 1 first" % orders.size(), typing_seen and title_card and _seen.has(CreditsCast.head_text()) and in_order and grew and full[0].strip_edges().begins_with("1  @NixFred"))
	_check("the last row in the table is exactly \"%s\", the last of all" % LAST_ROW, not full.is_empty() and _words(full[full.size() - 1]) == LAST_ROW, _words(full[full.size() - 1]) if not full.is_empty() else "none")
	_check("then the prompt waits for the player's own kill -9: `root# `, the reticle's hint, nothing typed yet", roll.phase_name() == "wait" and roll.shown_text().has(CreditsRoll.ROOT_PROMPT) and not roll.shot_fired())
	_action("fire")
	await _frames(2)
	roll.seek(roll.elapsed() + CreditsRoll.KILL_TYPE_S * 0.6)
	await process_frame
	var typing := Array(roll.shown_text()).filter(func(l): return l.begins_with(CreditsRoll.ROOT_PROMPT))
	var cmd: String = typing[0] if not typing.is_empty() else ""
	roll.seek(roll.elapsed() + CreditsRoll.KILL_TYPE_S)
	await process_frame
	var fired := roll.shot_fired() and roll.phase_name() == "kill"
	roll.seek(roll.elapsed() + CreditsRoll.SLAM_AFTER + 0.4)
	await process_frame
	var title := roll.title_showing() and roll.shown_text().has(CreditsRoll.TITLE)
	_check("fire is the kill: `%s` types (%s), the shot derezzes the table (nothing of it left: %d rows), then SIGKILL on the hexagon" % [CreditsRoll.ROOT_PROMPT + CreditsRoll.COMMAND, cmd.strip_edges(), roll.shown_rows().size()], cmd.begins_with(CreditsRoll.ROOT_PROMPT + "k") and fired and title and roll.shown_rows().is_empty())
	roll.seek(roll.elapsed() + CreditsRoll.BARE_AFTER - CreditsRoll.SLAM_AFTER)
	await process_frame
	var bare: bool = credits.at_prompt() and roll.shown_text() == PackedStringArray([CreditsRoll.BARE])
	old_id = main.get_instance_id()
	var ended := await _until(func(): return not credits.is_up())
	var given_back: bool = is_instance_valid(player) and not player.input_blocked and not root.disable_3d
	var asked := await _until(func(): return MissionRunner.mounting() != "" or current_scene == null or current_scene.get_instance_id() != old_id)
	_check("then STORY.md's bare `>_` alone, and on to the menu: the roll over (the player's input given back, the 3D view drawn again), the Missions screen asked for", bare and ended and given_back and asked)
	main = await _after_reload(old_id)
	var menu = main.get_node("Hud").pause_menu()
	await _frames(20)
	_check("after the roll: the Missions screen over a fresh arena, no roll up, played once for this ending (%d)" % (CreditsRoll.plays - plays), menu.showing_missions() and CreditsRoll.plays == plays + 1 and not main.get_node("Hud").mission_hud().credits_screen().is_up())


func _second_ending_checks() -> void:
	var main := current_scene
	var menu = main.get_node("Hud").pause_menu()
	menu.close()
	var runner := MissionRunner.of(main)
	var old_id := main.get_instance_id()
	runner.begin(MissionBook.at(7))
	main = await _after_reload(old_id)
	runner = MissionRunner.of(main)
	menu = main.get_node("Hud").pause_menu()
	var mh: MissionHud = main.get_node("Hud").mission_hud()
	await _until(func(): return runner.state == MissionRunner.State.RUNNING)
	runner.life.shield(100000.0)
	menu.open()
	await _frames(2)
	var in_mission: bool = menu.credits_button().visible and menu.credits_button().disabled and menu.open_credits() == null
	menu.close()
	await _frames(2)
	_check("the campaign finished, the Esc menu's Credits is there, but greyed out during a mission (open_credits() refuses)", in_mission)
	var plays := CreditsRoll.plays
	runner._complete()
	var end: MissionEndScreen = mh.end_screen()
	await _until(func(): return end.is_up())
	var credits: CreditsHandoff = mh.credits_screen()
	old_id = main.get_instance_id()
	end.choose("free_play")
	await _frames(2)
	if not (is_instance_valid(credits) and credits.is_up()):
		_check("a second ending, its card left by Free play: the roll again, once for it (0; it never came up)", false)
		await _skip_reload(old_id)
		return
	var once: bool = credits.is_up() and CreditsRoll.plays == plays + 1 and not runner.roll_credits("missions") and runner.credits_then() == "free_play"
	credits.roll().seek(CreditsRoll.CAST_AT + 1.0)
	await process_frame
	_key(KEY_ESCAPE)
	await _frames(2)
	var at_bare: bool = credits.at_prompt() and credits.shown_text() == PackedStringArray([CreditsRoll.BARE])
	old_id = main.get_instance_id()
	_key(KEY_ESCAPE)
	await _frames(2)
	var gone: bool = not credits.is_up()
	var asked := await _until(func(): return MissionRunner.mounting() != "" or current_scene == null or current_scene.get_instance_id() != old_id)
	_check("a second ending, its card left by Free play: the roll again, once for it (%d; the runner refuses another), Esc skipping to the bare prompt and Esc past it" % (CreditsRoll.plays - plays), once and at_bare and gone and asked)
	main = await _after_reload(old_id)
	await _frames(20)
	menu = main.get_node("Hud").pause_menu()
	var r := MissionRunner.of(main)
	_check("...and free play after it: a fresh arena, no mission running, no Missions screen, no roll", not menu.showing_missions() and (r == null or not r.running()) and CreditsRoll.plays == plays + 1)


func _replay_checks() -> void:
	var main := current_scene
	var menu = main.get_node("Hud").pause_menu()
	var p := MissionProgress.current()
	p.finished = false
	menu.open()
	await _frames(2)
	var locked: bool = not menu.credits_button().visible and menu.open_credits() == null
	menu.close()
	p.finished = true
	var plays := CreditsRoll.plays
	var done_before := p.done.duplicate()
	menu.open()
	await _frames(2)
	var shown: bool = menu.credits_button().visible and not menu.credits_button().disabled
	menu.credits_button().pressed.emit()
	await _frames(2)
	var roll: CreditsRoll = menu.get_node_or_null("CreditsRoll")
	var up := roll != null and roll.is_up() and roll.reason == "menu" and CreditsRoll.plays == plays + 1
	_check("replay is locked until the ending is reached (no Credits in the Esc menu while the campaign is not finished); once it is, Credits is there and replays the roll over the paused arena, the menu out of sight", locked and shown and up and paused and not menu.visible)
	if not up:
		return
	roll.seek(CreditsRoll.WAIT_AT + 1.0)
	await process_frame
	var waiting := roll.phase_name() == "wait" and not roll.shot_fired()
	roll.seek(CreditsRoll.WAIT_AT + CreditsRoll.WAIT_S + 0.05)
	await _frames(3)
	var self_typed := Array(roll.shown_text()).any(func(l): return l.begins_with(CreditsRoll.ROOT_PROMPT + "k"))
	roll.seek(roll.elapsed() + CreditsRoll.KILL_TYPE_S + CreditsRoll.BARE_AFTER + 0.2)
	await process_frame
	roll.seek(roll.elapsed() + CreditsRoll.BARE_S + 0.1)
	await _frames(3)
	_check("the prompt waits for the player, then types its own kill -9 (it never waits long); the roll ends into the Esc menu as it was: open, the arena running again, the 3D view drawn, the save unchanged", waiting and self_typed and not menu.showing_credits() and menu.visible and menu.is_open() and not paused and not root.disable_3d and p.campaign_finished() and p.done == done_before and CreditsRoll.plays == plays + 1)
	menu.close()


func _seen_checks() -> void:
	var lines := PackedStringArray(_seen.keys())
	var missing := PackedStringArray()
	for c in CreditsCast.CAST:
		for want in [str(c[1]), str(c[4])]:
			if not Array(lines).any(func(l): return l.contains(want)):
				missing.append(want)
	for n in CreditsCast.thanks_names():
		if not Array(lines).any(func(l): return l.contains(n)):
			missing.append(n)
	_check("every contributor and every project thanked was on screen as the roll played (%d lines seen)" % lines.size(), missing.is_empty(), ", ".join(missing))
	var bad := _models_in(lines)
	_check("no model names in anything the roll showed", bad.is_empty(), ", ".join(bad))


# --- Helpers. ---

## A part that failed to roll: on past the reload its card's choice asked for, so the checks after it run on a fresh arena.
func _skip_reload(old_id: int) -> void:
	await _until(func(): return current_scene != null and current_scene.get_instance_id() != old_id and current_scene.has_node("Hud") and current_scene.is_node_ready())
	if current_scene != null:
		await _ready_arena(current_scene)

func _arena() -> Node:
	MissionRunner.clear_pending()
	for old in root.get_children():
		if old.scene_file_path == "res://scenes/main.tscn":
			await _drop(old)
	GameSettings.current().set_value("gameplay", "practice", false)
	GameSettings.current().set_value("gameplay", "difficulty", "normal")
	GameSettings.current().set_value("gameplay", "ice", false)
	var link := Link.new()
	link.settings_path = _abs.path_join("privacy.cfg")
	link.demo = true
	Link.park(link)
	var main = MainScene.instantiate()
	root.add_child(main)
	current_scene = main
	await _ready_arena(main)
	return main


func _ready_arena(main: Node) -> void:
	main.get_node("Hud").guide().focus_check = func(): return false
	main.get_node("Hud").pause_menu().focus_check = func(): return false
	main.get_node("Hud").round_hud()._left_s = LONG_ROUND_S
	var player = main.get_node("Player")
	player.assume_captured = true
	var world := RuinsWorld.of(main)
	if world != null:
		player.global_position = world.point("start")
	player.velocity = Vector3.ZERO
	await _frames(2)


func _after_reload(old_id: int) -> Node:
	await _until(func(): return current_scene != null and current_scene.get_instance_id() != old_id and current_scene.has_node("Hud") and current_scene.is_node_ready())
	var main := current_scene
	await _ready_arena(main)
	return main


func _drop(main: Node) -> void:
	if is_instance_valid(main):
		for sfx in main.find_children("*", "AudioStreamPlayer", true, false):
			(sfx as AudioStreamPlayer).stop()
		for sfx in main.find_children("*", "AudioStreamPlayer3D", true, false):
			(sfx as AudioStreamPlayer3D).stop()
		if current_scene == main:
			current_scene = null
		main.free()
	await _frames(2)


func _cleanup() -> void:
	paused = false
	MissionRunner.clear_pending()
	for node in root.get_children():
		if node.scene_file_path == "res://scenes/main.tscn":
			await _drop(node)
	current_scene = null
	CreditsScore.drop()
	MissionProgress.current().path = ""
	MissionProgress.current().clear()
	Progress.current().path = ""
	Progress.current().clear()
	_wipe(_abs)
	_check("the test's own folder is gone, nothing of it left under user://", not DirAccess.dir_exists_absolute(_abs))
	await process_frame
	OS.delay_msec(300)
	await process_frame


func _wipe(path: String) -> void:
	if not path.begins_with(_abs):
		return
	var dir := DirAccess.open(path)
	if dir == null:
		return
	dir.include_hidden = true
	dir.list_dir_begin()
	var files := []
	var folders := []
	var name := dir.get_next()
	while name != "":
		if dir.is_link(name) or not dir.current_is_dir():
			files.append(name)
		else:
			folders.append(name)
		name = dir.get_next()
	dir.list_dir_end()
	for f in files:
		DirAccess.remove_absolute(path.path_join(f))
	for f in folders:
		_wipe(path.path_join(f))
	DirAccess.remove_absolute(path)


func _frames(n: int) -> void:
	for i in n:
		await process_frame


func _until(condition: Callable) -> bool:
	var frames := 0
	while frames < MOST_FRAMES and not condition.call():
		await process_frame
		frames += 1
	return condition.call()


func _action(action: String) -> void:
	for pressed in [true, false]:
		var e := InputEventAction.new()
		e.action = action
		e.pressed = pressed
		root.push_input(e)


func _key(code: Key) -> void:
	for pressed in [true, false]:
		var e := InputEventKey.new()
		e.keycode = code
		e.physical_keycode = code
		e.pressed = pressed
		root.push_input(e)


## `line` as words, one space between.
static func _words(line: String) -> String:
	var out := PackedStringArray()
	for w in line.strip_edges().split(" ", false):
		out.append(w)
	return " ".join(out)
