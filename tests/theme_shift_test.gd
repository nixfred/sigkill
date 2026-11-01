extends SceneTree
## Headless test of theme-shift levels (W3, PRD 5.5: the theme shift). scripts/check.sh runs it as step 67, and any
## FAIL exits 1.
##
##   godot --headless --path . --fixed-fps 60 --script res://tests/theme_shift_test.gd
##
## Fixtures are fake only: the game's own six palettes, its own districts, and for the real layer's reader a made-up
## theme file the test writes under its own folder (fake colours, a planted word that must never come out, a file beside
## it that must never be opened). The real layer is never turned on in the mode, against anything.
##
## The code: nothing of the mode writes, switches, runs, signals or sends anything; only the reader touches a file, and
## only the opener's capped read of one. The palettes: every built-in one loads, whole, credited; its look's ramp runs one
## way; the grade takes the game's colours to the theme's own (crimson its red, teal its cyan, the void its darkest),
## hostiles readable on the ground in every theme; the shader and its CPU twin share their stops. The districts: one each,
## good sets, all reachable, each its own. The mode: off by default (no grade, nothing read); queued, the first theme's
## district, the grade over every themed surface, the roster (the arena's kinds, the theme's own conceal shown, the next
## theme's lurkers concealed: out of reach, asleep, with their tells: ripple, chirp, the visor's box); the shift (the
## line, the tear finishing, the register going with it, lurkers printing in and waking, the old theme's conceal hiding);
## the ambush; the next theme's own world after a reload; the run's end on a results card and Enter's again. Conceal no
## two alike. The tear over a reload, finishing and gone. The Esc menu's entry; one world mode at a time.

const MainScene = preload("res://scenes/main.tscn")
const Link = preload("res://scripts/guide/guide_link.gd")
const Controls = preload("res://scripts/controls.gd")
const SettingsApply = preload("res://scripts/settings/settings_apply.gd")
const Palette = preload("res://scripts/palette.gd")
const ConcealArt = preload("res://scripts/daemons/conceal_daemon.gd")

const MODE_CODE := ["res://scripts/themes/theme_shift.gd", "res://scripts/themes/theme_book.gd", "res://scripts/themes/theme_look.gd", "res://scripts/themes/theme_grade.gd", "res://scripts/themes/theme_shift_hud.gd", "res://scripts/themes/theme_reader.gd", "res://scripts/daemons/conceal_daemon.gd", "res://scripts/fx/scene_tear.gd"]
const NEVER := ["OS.execute", "create_process", "execute_with_pipe", "OS.kill", "shell_open", "move_to_trash", "HTTPRequest", "HTTPClient", "PacketPeer", "StreamPeer", "TCPServer", "UDPServer", "WebSocket", "store_", "ResourceSaver", ".remove(", "remove_absolute", "rename", ".copy(", "copy_absolute", "make_dir", "create_link", "set_unix_permissions", "FileAccess.WRITE", "FileAccess.READ_WRITE", "FileAccess.WRITE_READ", "user://", "OS.crash", "omarchy-", "set_environment", "print("]
const READER := "res://scripts/themes/theme_reader.gd"
const PLANT := "PLANTED-WORD-NEVER-READ"
const MOST_FRAMES := 3000
const LONG_ROUND_S := 100000.0
## Pinned here, so a changed constant cannot move its own check.
const THEMES := ["night", "ember", "frost", "forest", "mocha", "latte"]
const CREDITED := ["Tokyo Night", "Catppuccin", "Gruvbox Material", "Nord", "Everforest"]

var _fails := 0
var _checks := 0
var _abs := ""


func _initialize() -> void:
	_run()


func _run() -> void:
	await process_frame
	root.size = Vector2i(1280, 720)
	_abs = ProjectSettings.globalize_path("user://theme-shift-test-%d" % OS.get_process_id())
	if DirAccess.dir_exists_absolute(_abs):
		print("FAIL the test's own folder already exists; not touching it")
		quit(1)
		return
	DirAccess.make_dir_recursive_absolute(_abs)
	Controls.ensure()
	GameSettings.current().reset()
	SettingsApply.apply_audio(GameSettings.current())
	MissionRunner.clear_pending()
	ProcHunt.clear()
	FolderMap.clear()
	ThemeShift.clear()
	MissionProgress.current().path = _abs.path_join("progress.cfg")
	MissionProgress.current().clear()
	Progress.current().path = _abs.path_join("progress.cfg")
	Progress.current().clear()
	AuditVisor.remembered = false
	_code_checks()
	_palette_checks()
	_district_checks()
	_reader_checks()
	await _tear_checks()
	await _arena_checks()
	await _shift_checks()
	await _next_level_checks()
	await _results_checks()
	await _menu_checks()
	await _cleanup()
	print("THEME SHIFT: %d checks" % _checks)
	print("THEME SHIFT RESULT: ", "ALL PASS" if _fails == 0 else "%d FAILED" % _fails)
	quit(0 if _fails == 0 else 1)


func _check(label: String, ok: bool, detail: String = "") -> void:
	_checks += 1
	print("PASS " if ok else "FAIL ", label, ("   " + detail) if detail != "" else "")
	if not ok:
		_fails += 1


# --- The code. ---

func _code_checks() -> void:
	var found := PackedStringArray()
	for path in MODE_CODE:
		var code := _code_of(path)
		if code == "":
			found.append(path + ": unreadable")
		for word in NEVER:
			if code.contains(word):
				found.append("%s: %s" % [path.get_file(), word])
	_check("acceptance (safety): nothing in the mode can write, switch, run, signal or send anything (no such call, no omarchy command, no environment change) in any of its %d files" % MODE_CODE.size(), found.is_empty(), ", ".join(found))
	var touch := PackedStringArray()
	for path in MODE_CODE:
		if path != READER and (_code_of(path).contains("FileAccess") or _code_of(path).contains("DirAccess")):
			touch.append(path.get_file())
	var reader := _code_of(READER)
	var reads_only_colours: bool = reader.contains("RealOpenerData._read_small(path, RealOpenerData.THEME_LARGEST)") and reader.contains("ThemeColors.palette_from(") and not reader.contains("DirAccess") and not reader.contains("FileAccess.open") and not reader.contains("get_file_as")
	_check("acceptance (safety): only the reader touches a file, and only through the opener's capped read of the theme's colours (RealOpenerData._read_small at THEME_LARGEST, then ThemeColors.palette_from: `#rrggbb` and the mode); no listing, no other open", touch.is_empty() and reads_only_colours, ", ".join(touch))
	var shader := FileAccess.get_file_as_string("res://shaders/theme_grade.gdshader")
	var ramp_at := "const float RAMP_AT[6] = float[](%s);" % ", ".join(ThemeLook.RAMP_AT.map(func(v): return _num(v)))
	var hue_at := "const float HUE_AT[13] = float[](%s);" % ", ".join(ThemeLook.HUE_AT.map(func(v): return _num(v)))
	_check("the grade's shader and its CPU twin (ThemeLook.grade) share their ramp and hue stops", shader.contains(ramp_at) and shader.contains(hue_at) and shader.contains("const float SAT_FROM = %s;" % _num(ThemeLook.SAT_FROM)) and shader.contains("const float SAT_TO = %s;" % _num(ThemeLook.SAT_TO)) and shader.contains("const float LIFT_MOST = %s;" % _num(ThemeLook.LIFT_MOST)) and shader.contains("const float INK = %s;" % _num(ThemeLook.INK)), ramp_at + " " + hue_at)


static func _num(v: float) -> String:
	var t := "%.2f" % v
	while t.ends_with("0") and not t.ends_with(".0"):
		t = t.left(t.length() - 1)
	return t


func _code_of(path: String) -> String:
	var out := PackedStringArray()
	for line in FileAccess.get_file_as_string(path).split("\n"):
		var at := line.find("#")
		var keep := line.substr(0, at) if at >= 0 else line
		var slash := keep.find("//")
		out.append(keep.substr(0, slash) if slash >= 0 and path.ends_with(".gdshader") else keep)
	return "\n".join(out)


# --- The palettes and the grade (pure). ---

func _palette_checks() -> void:
	var credits := FileAccess.get_file_as_string("res://CREDITS.md")
	var whole := true
	var notes := PackedStringArray()
	for id in THEMES:
		var p := OpenerPalette.named(id)
		var ok: bool = p != null and p.id == id and p.inspired_by != "" and credits.contains(p.inspired_by.replace(" Mocha", "").replace(" Latte", ""))
		for key in OpenerPalette.KEYS:
			ok = ok and Color.html_is_valid(str(p.colors.get(key, "")))
		whole = whole and ok
		if not ok:
			notes.append(id)
	_check("acceptance: every built-in palette loads whole (all %d of Omarchy's colour names, valid), from an open theme credited in CREDITS.md: %s" % [OpenerPalette.KEYS.size(), ", ".join(THEMES)], whole and ThemeBook.ORDER == THEMES, ", ".join(notes))
	var credited := true
	for name in CREDITED:
		credited = credited and credits.contains(name)
	_check("every theme's source is credited in CREDITS.md (%s), and the theme shift's use of them said there" % ", ".join(CREDITED), credited and credits.contains("theme shift"))
	var ramps := true
	var mapped := true
	var readable := true
	var apart := true
	var lines := PackedStringArray()
	var map_notes := PackedStringArray()
	for id in THEMES:
		var look := ThemeLook.of(OpenerPalette.named(id).readable())
		for i in range(1, look.ramp.size()):
			var step := ThemeLook.luma(look.ramp[i]) - ThemeLook.luma(look.ramp[i - 1])
			ramps = ramps and (step <= 0.0001 if look.light else step >= -0.0001)
		var p := look.palette
		var red := look.grade(Palette.CRIMSON)
		var teal := look.grade(Palette.TEAL)
		var amber := look.grade(Palette.HOSTILE_AMBER)
		var green := look.grade(Palette.MATRIX_GREEN)
		var ground := look.grade(Palette.VOID)
		var miss := PackedStringArray()
		for pair in [["red", red], ["cyan", teal], ["yellow", amber], ["green", green]]:
			if not _near(pair[1], p.color(pair[0]), 0.12):
				miss.append("%s %s want %s (%.2f)" % [pair[0], (pair[1] as Color).to_html(false), p.color(pair[0]).to_html(false), RuinsRegister.oklab(pair[1]).distance_to(RuinsRegister.oklab(p.color(pair[0])))])
		if not _near(ground, look.ramp[0], 0.02):
			miss.append("ground " + ground.to_html(false))
		mapped = mapped and miss.is_empty()
		if not miss.is_empty():
			map_notes.append(id + ": " + ", ".join(miss))
		var contrast := OpenerPalette.contrast(red, ground)
		readable = readable and contrast >= 2.5
		var gap := RuinsRegister.oklab(red).distance_to(RuinsRegister.oklab(teal))
		apart = apart and gap >= 0.12
		lines.append("%s red %.1f:1 gap %.2f" % [id, contrast, gap])
	_check("each theme's ramp runs one way (darkest first; the light theme lightest first, so its void is paper)", ramps)
	_check("the grade takes the game's colours to the theme's own: crimson to its red, the player's teal to its cyan, amber to its yellow, the Matrix's green to its green, the void to its darkest shade", mapped, " | ".join(map_notes))
	_check("readable in every theme: a hostile's red stands off the ground at 2.5:1 or more, and stays apart from the player's teal (OKLab 0.12 or more)", readable and apart, " | ".join(lines))
	var latte := ThemeLook.of(OpenerPalette.named("latte").readable())
	_check("the light theme turns the frame over: the void is its paper (its lightest), a white-hot light its ink (its darkest)", latte.light and ThemeLook.luma(latte.grade(Palette.VOID)) > 0.85 and ThemeLook.luma(latte.grade(Color.WHITE)) < 0.35)


func _near(a: Color, b: Color, most: float) -> bool:
	return RuinsRegister.oklab(a).distance_to(RuinsRegister.oklab(b)) <= most


# --- The districts (pure). ---

func _district_checks() -> void:
	var good := true
	var notes := PackedStringArray()
	var ids := {}
	var looks := {}
	for id in ThemeBook.run_ids(true):
		var s := ThemeBook.set_for(id)
		var problems := s.problems()
		var layout := RuinsLayout.of(s)
		var stray := layout.unreachable()
		var daemon_points := 0
		while layout.points.has("daemon_%d" % daemon_points):
			daemon_points += 1
		good = good and problems.is_empty() and stray.is_empty() and daemon_points >= 4
		if not problems.is_empty() or not stray.is_empty():
			notes.append("%s: %s %s" % [id, ", ".join(problems), ", ".join(stray)])
		ids[s.id] = true
		looks["%s/%s/%s/%s/%d" % [s.register, s.decay, str(s.pristine), s.field, int(s.water)]] = true
	_check("acceptance: every theme has its own district, made at play: good sets (RuinsSet.problems() none), every floor reachable, daemon points for its roster", good and ids.size() == ThemeBook.run_ids(true).size(), " | ".join(notes))
	_check("each theme its own world, not one scene recoloured: %d different registers and set pieces among the six built-in themes (megacity rain, a decaying grid, a pristine hall, a code grove, a drowned plain, daylight)" % (looks.size() - 1), looks.size() >= 6)
	_check("the regular arena never shifts: no book district is a theme's, and the theme sets are made at play (\"fs_theme_\"), kept as W2's are (the last few)", RuinsBook.of(ThemeBook.set_id("night")) == null and ThemeBook.set_id("night").begins_with(RuinsWorld.MADE_PREFIX))


# --- The real layer's reader (a fake theme file). ---

func _reader_checks() -> void:
	var home := _abs.path_join("home")
	var dir := home.path_join("theme")
	DirAccess.make_dir_recursive_absolute(dir)
	var text := "# %s\naccent = \"#ff8800\"\nbackground = \"#101820\"\nforeground = \"#e0e8f0\"\nred = \"#ff4060\"\ngreen = \"#40ff80\"\nname = \"%s\"\n" % [PLANT, PLANT]
	_write(dir.path_join("colors.toml"), text)
	_write(dir.path_join("wallpaper.txt"), PLANT)
	var before := ThemeReader.reads
	ThemeReader.opened = PackedStringArray()
	var p := ThemeReader.read(home, PackedStringArray(["theme/colors.toml"]))
	var ok: bool = p != null and p.color("background").to_html(false) == "101820" and p.color("red").to_html(false) == "ff4060" and p.mode == "dark" and p.id == ThemeColors.ID
	var leaked := false
	if p != null:
		for key in p.colors:
			leaked = leaked or str(p.colors[key]).contains(PLANT)
		leaked = leaked or p.inspired_by.contains(PLANT)
	_check("the real layer's reader takes only colours (`#rrggbb` and the mode) from the theme file: the fixture's background and red, nothing of its other words, and opens that one file only", ok and not leaked and ThemeReader.opened == PackedStringArray(["theme/colors.toml"]) and ThemeReader.reads == before + 1)
	_write(dir.path_join("light.mode"), "")
	var light := ThemeReader.read(home, PackedStringArray(["theme/colors.toml"]))
	_check("a light.mode beside it makes it a light theme (asked for, never opened)", light != null and light.mode == "light" and ThemeReader.opened.count("theme/light.mode") == 0)
	_write(dir.path_join("colors.toml"), text + "#".repeat(RealOpenerData.THEME_LARGEST))
	_check("a theme file over the opener's cap (%d bytes) is refused whole" % RealOpenerData.THEME_LARGEST, ThemeReader.read(home, PackedStringArray(["theme/colors.toml"])) == null)
	_check("no theme file: nothing, and the run is the six built-in themes alone", ThemeReader.read(home, PackedStringArray(["none/colors.toml"])) == null and ThemeBook.run_ids(false).size() == 6 and ThemeBook.run_ids(true).size() == 7 and ThemeBook.run_ids(true)[6] == ThemeBook.YOURS)


func _write(path: String, text: String) -> void:
	var f := FileAccess.open(path, FileAccess.WRITE)
	f.store_string(text)
	f.close()


# --- The tear over a reload. ---

func _tear_checks() -> void:
	_check("headless there is no frame to hold: the tear holds nothing and the reload is the plain one", not SceneTear.hold(self, "$ cd x"))
	var tear := SceneTear.new()
	var image := Image.create(16, 9, false, Image.FORMAT_RGBA8)
	image.fill(Color(0.2, 0.4, 0.6))
	tear._make(ImageTexture.create_from_image(image))
	tear._scene_id = -1  # a scene that is never this one: as if the reload has happened
	root.add_child(tear)
	await _frames(SceneTear.SETTLE_FRAMES + 2)
	var tearing := is_instance_valid(tear) and tear.away() >= 0.0
	await _frames(int(SceneTear.AWAY_S * 60.0) + 10)
	_check("acceptance: the tear over a reload finishes: held while the next arena builds, torn away in %.1f s once it is up, and gone" % SceneTear.AWAY_S, tearing and not is_instance_valid(tear))


# --- The mode in the arena. ---

func _arena(queue_mode: bool) -> Node:
	MissionRunner.clear_pending()
	for old in root.get_children():
		if old.scene_file_path == "res://scenes/main.tscn":
			await _drop(old)
	ProcHunt.clear()
	FolderMap.clear()
	if queue_mode:
		ThemeShift.queued = true
	else:
		ThemeShift.clear()
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
	player.velocity = Vector3.ZERO
	await _frames(3)


func _after_reload(old_id: int) -> Node:
	await _until(func(): return current_scene != null and current_scene.get_instance_id() != old_id and current_scene.has_node("Hud") and current_scene.is_node_ready())
	var main := current_scene
	await _ready_arena(main)
	var mode := ThemeShift.of(main)
	await _until(func(): return mode != null and mode.running)
	await _frames(2)
	return main


func _arena_checks() -> void:
	var reads := ThemeReader.reads
	var plain := await _arena(false)
	var m0 := ThemeShift.of(plain)
	await _frames(10)
	_check("acceptance: off by default: the mode stands in the arena, not running, no grade anywhere, no theme district, nothing read", m0 != null and not m0.running and plain.find_children("ThemeGrade", "CanvasLayer", true, false).is_empty() and RuinsWorld.of(plain) == null and ThemeReader.reads == reads)
	ThemeShift.fight_s = 1000.0
	ThemeShift.ambush_s = 1000.0
	var main := await _arena(true)
	var mode := ThemeShift.of(main)
	await _until(func(): return mode.running)
	_check("acceptance (safety): the real layer is off by default: a demo run plays the six built-in themes and reads nothing", ThemeShift.layer == "demo" and ThemeShift.run == PackedStringArray(THEMES) and ThemeShift.yours == null and ThemeReader.reads == reads)
	_check("acceptance: queued (the Esc menu, or --themes), it begins at its first theme, Tokyo Night, in that theme's own district (a rain-soaked megacity in the cyberpunk register)", mode.running and mode.theme == "night" and mode.world != null and mode.world.ruins.id == ThemeBook.set_id("night") and mode.world.register == "cyberpunk" and mode.phase == "fight")
	var g := mode.grade
	var layers_ok := g != null and g.layer == ThemeGrade.LAYER
	var under := PackedStringArray()
	for cl in main.find_children("*", "CanvasLayer", true, false):
		if cl == g or cl.name == "ColorblindFilter":
			continue
		if (cl as CanvasLayer).layer >= g.layer:
			under.append("%s %d" % [cl.name, (cl as CanvasLayer).layer])
	var filter := main.find_children("ColorblindFilter", "CanvasLayer", true, false)
	layers_ok = layers_ok and under.is_empty() and not filter.is_empty() and (filter[0] as CanvasLayer).layer > g.layer
	var mat := g.grade_material()
	var night := mode.look_of("night")
	var uniforms_ok: bool = mat.shader.resource_path == "res://shaders/theme_grade.gdshader" and mat.get_shader_parameter("ramp_a") == night.ramp_vectors() and mat.get_shader_parameter("hue_a") == night.hue_vectors()
	var cover := g.cover()
	var full := cover.anchor_left == 0.0 and cover.anchor_top == 0.0 and cover.anchor_right == 1.0 and cover.anchor_bottom == 1.0
	_check("acceptance: the theme recolours every themed surface: one full-screen grade (in Tokyo Night's ramp and colours) over the 3D view (sky, floor, ruins, registers, daemons, weapons and their effects) and every HUD layer and the menu, under only the colourblind filter", layers_ok and uniforms_ok and full, ", ".join(under))
	await _frames(int(ThemeGrade.EASE_IN_S * 60.0) + 5)
	_check("the grade eases in as the mode begins (no snap): full strength after %.1f s" % ThemeGrade.EASE_IN_S, g.strength >= 1.0)
	var regular := 0
	var own: Array = []
	var lurkers: Array = []
	for e in mode.enemies:
		if str(e["kind"]) == "conceal":
			if str(e["key"]) == "night":
				own.append(e)
			else:
				lurkers.append(e)
		else:
			regular += 1
	_check("the first theme's roster: the arena's kinds (%d), its own palette-only daemons shown (%d), the next theme's lurking concealed (%d)" % [regular, own.size(), lurkers.size()], regular == ThemeShift.DAEMONS_FIRST and own.size() == ThemeShift.OWN_CONCEAL[0] and lurkers.size() == ThemeShift.LURKERS[0] and lurkers.all(func(e): return str(e["key"]) == "ember"))
	await _frames(90)
	var shown_ok := true
	for e in own:
		var body = e["body"]
		var art = body.art_node()
		shown_ok = shown_ok and art.reveal >= 1.0 and not bool(e["phased"]) and body.is_in_group("targets") and int(body.collision_layer) != 0 and not body.sealed
	_check("acceptance: a palette-only daemon shows in its own palette: printed in, a target, solid, hittable", shown_ok)
	var hidden_ok := true
	var harmless := true
	for e in lurkers:
		var body = e["body"]
		var art = body.art_node()
		hidden_ok = hidden_ok and art.reveal <= 0.0 and bool(e["phased"]) and not body.is_in_group("targets") and int(body.collision_layer) == 0
		var sets_hidden := true
		for s in art.sets():
			sets_hidden = sets_hidden and not s.visible
		hidden_ok = hidden_ok and sets_hidden and art.cells().visible
		harmless = harmless and body.sealed and body.brain.dormant and not body.brain.attacking()
		harmless = harmless and not body.hit(10000.0)
	_check("acceptance: and is concealed in the others: no lit part shown, only its cells as a ripple; out of the targets, no volume", hidden_ok)
	_check("acceptance (fair): a concealed one never hits and is never hit: asleep, sealed, its hits refused (no invisible enemy that kills)", harmless)
	var chirps := 0
	await _frames(300)
	for e in lurkers:
		chirps += int(e["body"].art_node().chirps)
	_check("its tells while concealed: its ripple moving (it drifts round its home) and a chirp from where it is every few seconds (%d in 5 s)" % chirps, chirps >= lurkers.size())
	mode.visor.set_on(true)
	await _frames(4)
	var marks := 0
	var mark_text := ""
	for e in lurkers:
		var m = e.get("mark")
		if m != null and is_instance_valid(m) and m.visible and (m as Label3D).no_depth_test:
			marks += 1
			mark_text = (m as Label3D).text
	_check("acceptance: and under the visor (I) each concealed one is marked through walls as selected hidden text is: a box round it (%d strokes) and \"%s\"" % [mode._lines.drawn_lines, mark_text.replace("\n", " / ")], marks == lurkers.size() and mode._lines.drawn_lines == 8 * lurkers.size() and mark_text.contains("Gruvbox Material"))
	mode.visor.set_on(false)
	await _frames(2)
	var none_shown := true
	for e in lurkers:
		var m = e.get("mark")
		none_shown = none_shown and (m == null or not m.visible)
	_check("visor off: no marks, no boxes", none_shown and mode._lines.drawn_lines == 0)
	var sigs := {}
	var seeds := {}
	for e in mode.enemies:
		var art = e["body"].art_node()
		if str(e["kind"]) == "conceal":
			sigs[str(art.signature())] = true
		seeds[e["body"].build_seed()] = true
	_check("no two alike (A5): every palette-only daemon built differently from its seed (%d of %d), every daemon its own seed" % [sigs.size(), own.size() + lurkers.size()], sigs.size() == own.size() + lurkers.size() and seeds.size() == mode.enemies.size())
	var meta_ok := true
	for e in mode.enemies:
		meta_ok = meta_ok and e["body"].has_meta(&"world")
	_check("its kills are the world modes' (the credit cap of W1 and W2 applies to them)", meta_ok)
	var lines := "\n".join(mode._hud.lines())
	_check("its panel: the theme, its level, where its colours come from, what fights and what lurks (\"%s\")" % lines.replace("\n", " / "), lines.contains("Tokyo Night") and lines.contains("level 1 of 6") and lines.contains("colours: Tokyo Night") and lines.contains("lurking concealed 2") and lines.contains("they show in: Gruvbox Material"))


func _shift_checks() -> void:
	var main := current_scene
	var mode := ThemeShift.of(main)
	var own: Array = []
	var lurkers: Array = []
	for e in mode.enemies:
		if str(e["kind"]) == "conceal":
			(own if str(e["key"]) == "night" else lurkers).append(e)
	# The theme's time runs out with its own conceal still standing: the shift hides it.
	ThemeShift.fight_s = mode.phase_time() + 0.05
	await _until(func(): return mode.phase == "shift")
	_check("acceptance: the theme's time up, it shifts: `$ export THEME=gruvbox-material` types itself", mode.phase == "shift" and mode.next_theme == "ember" and mode.events.any(func(e): return str(e["text"]) == "$ export THEME=gruvbox-material"))
	await _until(func(): return mode.grade.tearing())
	var mid_ok := mode.grade.tear > 0.0 and mode.grade.tear < 1.0 and mode.world.register == "tron" and mode.world.shifting()
	var tear_seen := float(mode.grade.grade_material().get_shader_parameter("tear"))
	_check("acceptance: the shift is an event: the palette tears across the frame (the shader's tear running, %.2f), the ruins' register going with it (cyberpunk to tron, tearing)" % tear_seen, mid_ok and tear_seen > 0.0)
	await _until(func(): return mode.phase == "ambush")
	var done_ok: bool = not mode.grade.tearing() and mode.grade.look == mode.look_of("ember") and mode.grade.shifts == 1 and mode.theme == "ember" and float(mode.grade.grade_material().get_shader_parameter("tear")) == 0.0
	_check("acceptance: the transition completes: the tear finished, the whole frame now in Gruvbox Material, the tear's uniform back at rest", done_ok)
	await _frames(70)
	var woke := true
	for e in lurkers:
		var body = e["body"]
		var art = body.art_node()
		woke = woke and art.reveal >= 1.0 and not bool(e["phased"]) and body.is_in_group("targets") and not body.sealed and not body.brain.dormant
	_check("acceptance: the shift reveals them: the lurkers keyed to Gruvbox Material printed in and woke, targets, hunting", woke)
	var hid := true
	for e in own:
		var body = e["body"]
		if not body.is_alive():
			continue
		hid = hid and bool(e["phased"]) and body.art_node().reveal <= 0.0 and body.sealed
	_check("acceptance: and hides the others: Tokyo Night's own conceal, still standing, concealed and asleep with its theme gone", hid and own.any(func(e): return e["body"].is_alive()))
	var ambush := mode.enemies.filter(func(e): return str(e["body"].name).begins_with("Theme_ambush")).size()
	_check("the ambush: the woken lurkers and %d more of the arena's kind" % ambush, mode.phase == "ambush" and ambush == ThemeShift.AMBUSH_DAEMONS)


func _next_level_checks() -> void:
	var main := current_scene
	var mode := ThemeShift.of(main)
	for e in mode.enemies:
		var body = e["body"]
		if is_instance_valid(body) and body.is_alive() and not bool(e["phased"]):
			body.hit(10000.0)
	var old_id := main.get_instance_id()
	await _until(func(): return ThemeShift.level == 1)
	var s0: Dictionary = ThemeShift.stats[0]
	_check("the level done: its numbers kept (%d kills, %d caught, %d slipped, %.0f s)" % [int(s0["kills"]), int(s0["caught"]), int(s0["slipped"]), float(s0["time"])], int(s0["kills"]) >= ThemeShift.AMBUSH_DAEMONS and int(s0["caught"]) >= ThemeShift.LURKERS[0] and int(s0["slipped"]) >= 1 and float(s0["time"]) > 0.0)
	main = await _after_reload(old_id)
	mode = ThemeShift.of(main)
	_check("acceptance: then the world follows its theme: the arena reloads into Gruvbox Material's own district (a warm grid decaying toward its far end), graded in it from its first frame", mode.theme == "ember" and mode.world.ruins.id == ThemeBook.set_id("ember") and mode.world.ruins.decay == "exit" and mode.grade.look == mode.look_of("ember") and mode.world.register == "tron")
	var keys := {}
	for e in mode.enemies:
		if str(e["kind"]) == "conceal":
			keys[str(e["key"])] = true
	_check("its roster: its own conceal and Nord's lurking", keys.has("ember") and keys.has("frost") and keys.size() == 2)


func _results_checks() -> void:
	var main := current_scene
	ThemeShift.level = ThemeShift.run.size() - 1
	while ThemeShift.stats.size() < ThemeShift.level:
		ThemeShift.stats.append({"theme": ThemeShift.run[ThemeShift.stats.size()], "kills": 1, "caught": 1, "slipped": 0, "time": 30.0})
	var old_id := main.get_instance_id()
	ThemeShift.queued = true
	MissionRunner.reload_after_mount(self, "$ reset")
	main = await _after_reload(old_id)
	var mode := ThemeShift.of(main)
	_check("the last theme, Catppuccin Latte: the light theme's district, its frame turned to paper", mode.theme == "latte" and mode.look_of("latte").light and mode.world.ruins.id == ThemeBook.set_id("latte"))
	var lurk_keys := {}
	for e in mode.enemies:
		if bool(e["phased"]):
			lurk_keys[str(e["key"])] = true
	_check("its lurkers are keyed to the first theme: the last shift goes round to Tokyo Night", lurk_keys.has("night") and lurk_keys.size() == 1)
	ThemeShift.fight_s = mode.phase_time() + 0.05
	await _until(func(): return mode.phase == "ambush")
	ThemeShift.ambush_s = mode.phase_time() + 0.05
	await _until(func(): return mode.phase == "results")
	var rows: PackedStringArray = mode._hud.result_lines()
	_check("acceptance: the run ends on a results card: a row each theme (%d) and the totals (\"%s\")" % [rows.size() - 2, rows[rows.size() - 1]], mode.phase == "results" and rows.size() == ThemeShift.run.size() + 2 and rows[1].begins_with("Tokyo Night") and rows[rows.size() - 1].begins_with("ALL 6 THEMES"))
	old_id = main.get_instance_id()
	var ev := InputEventAction.new()
	ev.action = "ui_accept"
	ev.pressed = true
	mode._unhandled_input(ev)
	main = await _after_reload(old_id)
	mode = ThemeShift.of(main)
	_check("Enter runs it again from its first theme", mode.theme == "night" and ThemeShift.level == 0 and ThemeShift.stats.size() == 1)
	ThemeShift.fight_s = ThemeShift.FIGHT_S
	ThemeShift.ambush_s = ThemeShift.AMBUSH_S


func _menu_checks() -> void:
	var main := await _arena(false)
	var menu = main.get_node("Hud").pause_menu()
	menu.open()
	await _frames(2)
	var b: Button = menu.theme_button()
	var plain_ok: bool = b != null and b.text == "Theme shift" and not b.disabled and b.is_visible_in_tree()
	menu.close()
	FolderMap.queued = true
	ProcHunt.queued = true
	menu.toggle_theme_shift()
	var one := ThemeShift.queued and not FolderMap.queued and not ProcHunt.queued
	var old_id := main.get_instance_id()
	main = await _after_reload(old_id)
	menu = main.get_node("Hud").pause_menu()
	menu.open()
	await _frames(2)
	var leave_ok: bool = menu.theme_button().text == "Leave theme shift"
	menu.close()
	_check("acceptance: the Esc menu reaches it: \"Theme shift\" in the free arena, \"Leave theme shift\" while it runs; one world mode at a time (the hunt and the map end as it begins)", plain_ok and leave_ok and one)
	ThemeShift.clear()


func _cleanup() -> void:
	MissionRunner.clear_pending()
	ProcHunt.clear()
	FolderMap.clear()
	ThemeShift.clear()
	for node in root.get_children():
		if node.scene_file_path == "res://scenes/main.tscn":
			await _drop(node)
	current_scene = null
	AuditVisor.remembered = false
	GameSettings.current().reset()
	MissionProgress.current().path = ""
	MissionProgress.current().clear()
	Progress.current().path = ""
	Progress.current().clear()
	_wipe(_abs)
	_check("the test's own folder is gone, nothing of it left under user://", not DirAccess.dir_exists_absolute(_abs))


## The test's own folder only, file by file.
func _wipe(path: String) -> void:
	if not path.begins_with(ProjectSettings.globalize_path("user://theme-shift-test-")):
		return
	var dir := DirAccess.open(path)
	if dir == null:
		return
	dir.include_hidden = true
	dir.list_dir_begin()
	var name := dir.get_next()
	while name != "":
		var full := path.path_join(name)
		if dir.current_is_dir() and not dir.is_link(name):
			_wipe(full)
		else:
			DirAccess.remove_absolute(full)
		name = dir.get_next()
	dir.list_dir_end()
	DirAccess.remove_absolute(path)


func _drop(main: Node) -> void:
	if is_instance_valid(main):
		for sfx in main.find_children("*", "AudioStreamPlayer", true, false):
			(sfx as AudioStreamPlayer).stop()
		for sfx in main.find_children("*", "AudioStreamPlayer3D", true, false):
			(sfx as AudioStreamPlayer3D).stop()
		if current_scene == main:
			current_scene = null
		main.queue_free()
		await _frames(3)


func _frames(n: int) -> void:
	for i in n:
		await process_frame


func _until(condition: Callable) -> bool:
	var frames := 0
	while frames < MOST_FRAMES and not condition.call():
		await process_frame
		frames += 1
	return condition.call()
