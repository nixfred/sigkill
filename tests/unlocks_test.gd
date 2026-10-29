extends SceneTree
## Headless test of unlocks, mods and light skins for SIGKILL (C33, PRD 5.2: "every one gets its own Tron light
## skin, mods and unlocks earned by playing"). scripts/check.sh runs it as step 47, and any FAIL exits 1.
##
##   godot --headless --path . --fixed-fps 60 --script res://tests/unlocks_test.gd
##
## The code: nothing of the chunk opens a network connection, runs a program or writes a file except the one
## save through the settings file's writer, and only under user:// (a test's own folder aside); the nixfred
## logo untouched. The data: every weapon's kit beside it (its own skin, two earned, one mod), every skin's two
## lights at least FLOOR (OKLab) from every hostile light and its weapon's skins apart at a glance, every mod a
## sidegrade that changes exactly its own numbers and leaves the shipped weapon alone. The save: written and read
## back, a missing one and a corrupt one (garbage, an object, a newer format) a fresh profile, no path headless.
## The rule: a threshold's edges (one short: nothing; at it: the unlock, told once), the all-unlocked flag. In the
## real arena: a kill with the real cannon against the daemons fighting back earns, the same kill against practice
## dummies does not, and the toast says what was earned; wearing a mod and a skin changes the weapon in hand
## (its numbers, its model's light, the strip) and a real shot lands the mod's damage; reset progress asks
## first, then wipes. The loadout screen at 960x540 from the Esc menu: whole on screen, every weapon, every
## card, a locked one saying how it is earned, the turntable lit live by a card under the pointer. Then a host
## and a joiner over ENet on 127.0.0.1: the joiner's mod judged by the host (a real shot landing its damage),
## its skin seen on the host's screen, the host's mods rule off ignoring the mod while the skin stays, and a kill
## counted for the joiner from the host's word alone. Deterministic: frames counted, only outcomes printed.

const Session = preload("res://scripts/net/net_session.gd")
const NetTuningScript = preload("res://scripts/net/net_tuning.gd")
const Link = preload("res://scripts/guide/guide_link.gd")
const MainScene = preload("res://scenes/main.tscn")
const Controls = preload("res://scripts/controls.gd")
const Palette = preload("res://scripts/palette.gd")
const WeaponDefScript = preload("res://scripts/weapons/weapon_def.gd")
const SettingsFile = preload("res://scripts/settings/settings_file.gd")
const WeaponHudScript = preload("res://scripts/hud/weapon_hud.gd")
const PauseMenu = preload("res://scripts/hud/pause_menu.gd")
const C33_CODE := ["res://scripts/unlocks/progress.gd", "res://scripts/unlocks/loadout.gd", "res://scripts/unlocks/weapon_kit.gd", "res://scripts/unlocks/weapon_mod.gd", "res://scripts/unlocks/weapon_skin.gd", "res://scripts/hud/loadout_screen.gd", "res://scripts/hud/loadout_stage.gd", "res://scripts/hud/unlock_toast.gd"]
const NEVER := ["OS.execute", "create_process", "OS.kill", "shell_open", "HTTPRequest", "HTTPClient", "PacketPeer", "StreamPeer", "TCPServer", "UDPServer", "ENetMultiplayerPeer", "WebSocket", "WebRTC", "FileAccess.open", "DirAccess", "store_var", "get_var", "bytes_to_var", "str_to_var", "JavaScriptBridge", "http://", "https://", "nixfred-icon"]
const LOGO := "res://docs/media/nixfred-icon.svg"
const LOGO_SHA := "b94873100bfae0d9b7993a721f70c601be436a2a961d22e3310e871b77611a82"
## How far apart (OKLab) every earned skin's two lights keep from every hostile light; a weapon's skins from
## each other; and how light a skin's beam is, as text on black.
const FLOOR := 0.16
const APART := 0.15
const BEAM_LIGHT := 0.75
const WATCHDOG_MS := 12000
const CLIENT_OFFSET := Vector3(1000.0, 0.0, 0.0)
const OPEN := Vector3(0.0, 0.95, 15.0)
const PARKED := Vector3(0.0, -50.0, 0.0)
const LONG_ROUND_S := 100000.0
const EPS := 0.001

var _fails := 0
var _checks := 0
var _tmp := ""
var _arenas: Array = []
var _branches: Array = []
var _defs: Array = []
var _p: Progress


func _initialize() -> void:
	_run()


func _run() -> void:
	await process_frame
	root.size = Vector2i(1280, 720)
	_tmp = OS.get_temp_dir().path_join("sigkill-unlocks-test-%d" % OS.get_process_id())
	if DirAccess.dir_exists_absolute(_tmp):
		print("FAIL the test's temporary folder already exists; not touching it")
		quit(1)
		return
	DirAccess.make_dir_recursive_absolute(_tmp)
	Controls.ensure()
	GameSettings.current().reset()
	_defs = WeaponKit.shipped_defs()
	_p = Progress.current()
	_check("a headless run's progress has no path and a fresh profile: the player's own save is never read or written (no flag: nothing held but the weapons' own skins)", _p.path == "" and _p.last_load == "defaults" and _p.feats.is_empty() and not _p.save() and not _p.all_unlocked and not _p.has("terminal_cannon", "tty1") and _p.has("terminal_cannon", "teal"))
	_p.path = _tmp.path_join("progress.cfg")
	_source_checks()
	_kit_checks()
	_palette_checks()
	_mod_checks()
	_save_checks()
	_threshold_checks()
	await _solo_checks()
	await _reset_checks()
	await _screen_checks()
	await _match_checks()
	await _cleanup()
	for name in DirAccess.get_files_at(_tmp):
		DirAccess.remove_absolute(_tmp.path_join(name))
	DirAccess.remove_absolute(_tmp)
	print("UNLOCKS: %d checks" % _checks)
	print("UNLOCKS RESULT: ", "ALL PASS" if _fails == 0 else "%d FAILED" % _fails)
	quit(0 if _fails == 0 else 1)


func _check(label: String, ok: bool, detail: String = "") -> void:
	_checks += 1
	print("PASS " if ok else "FAIL ", label, ("   " + detail) if detail != "" else "")
	if not ok:
		_fails += 1


# --- The code. ---

func _source_checks() -> void:
	var found := PackedStringArray()
	var all := ""
	for path in C33_CODE:
		var code := _code(path)
		all += code
		for word in NEVER:
			if code.contains(word):
				found.append("%s: %s" % [path.get_file(), word])
	_check("acceptance: nothing in the chunk opens a network connection (no HTTP, socket, ENet, WebSocket or WebRTC), runs a program, opens a file or a folder of its own, or decodes an object; no URL anywhere in it, so no telemetry and no online unlock check", found.is_empty() and all.length() > 0, ", ".join(found))
	var progress := _code("res://scripts/unlocks/progress.gd")
	_check("acceptance: its one write is the progress save, through the settings file's strict writer (a temporary name renamed over the old file), to user://progress.cfg: never outside user:// (the writer refuses res:// and relative paths; tests use their own folder)", progress.count("SettingsFile.write_sections(") == 1 and progress.count("store_") == 0 and Progress.DEFAULT_PATH == "user://progress.cfg" and SettingsFile.usable_path(Progress.DEFAULT_PATH) and not SettingsFile.usable_path("res://progress.cfg") and not SettingsFile.usable_path("progress.cfg") and _code("res://scripts/settings/settings_file.gd").contains("DirAccess.rename_absolute(temporary, target)"))
	_check("acceptance: the locked nixfred hexagon logo is untouched (its file to the byte) and nothing of the chunk names it", FileAccess.get_sha256(LOGO) == LOGO_SHA and not all.contains("nixfred-icon") and not all.contains("logo"))
	var shop := PackedStringArray()
	for word in ["purchase", "price", "payment", "currency", "checkout", "login", "sign_in", "signin"]:
		if all.to_lower().contains(word):
			shop.append(word)
	_check("no store, no money, no account: nothing in it sells, buys or signs in", shop.is_empty(), ", ".join(shop))
	_check("the dev and test flag --unlock-all is read once, from the game's own arguments, and never saved", progress.contains("OS.get_cmdline_user_args().has(UNLOCK_ALL_FLAG)") and Progress.UNLOCK_ALL_FLAG == "--unlock-all" and not _body(progress, "save").contains("all_unlocked"))


# --- The kits: every weapon's skins and its mod. ---

func _kit_checks() -> void:
	var issues := PackedStringArray()
	var skins := 0
	var mods := 0
	var names := {}
	var earliest := 1000000
	for def in _defs:
		var kit := WeaponKit.of(def.id)
		if kit == null:
			issues.append("%s: no kit" % def.id)
			continue
		for issue in kit.problems(def):
			issues.append("%s: %s" % [def.id, issue])
		if kit.skins.size() != 3 or kit.mod == null:
			issues.append("%s: %d skins, mod %s" % [def.id, kit.skins.size(), kit.mod])
		for skin in kit.skins:
			if names.has(skin.skin):
				issues.append("skin %s twice" % skin.skin)
			names[skin.skin] = true
			if skin.feat != "":
				skins += 1
				if not Progress.feat_names().has(skin.feat):
					issues.append("%s: unknown feat %s" % [skin.skin, skin.feat])
				earliest = mini(earliest, skin.need)
		if kit.mod != null:
			mods += 1
			if not Progress.feat_names().has(kit.mod.feat):
				issues.append("%s: unknown feat %s" % [kit.mod.id, kit.mod.feat])
			earliest = mini(earliest, kit.mod.need)
	_check("acceptance: every one of the %d weapons has its kit beside it (resources/<id>_kit.tres): its own skin and two more earned (%d), and one mod (%d), each named, with its fiction and the feat that earns it; the weapon's C16 slots name the kit's ids in order" % [_defs.size(), skins, mods], issues.is_empty() and _defs.size() == 13 and skins == 26 and mods == 13, "; ".join(issues))
	var cannon := WeaponKit.of("terminal_cannon")
	_check("a first unlock comes inside a normal session: the cannon's overclock at 10 kills with the cannon (the lowest count any unlock needs is %d)" % earliest, cannon.mod.feat == "kills_terminal_cannon" and cannon.mod.need == 10 and earliest <= 10)
	var bad := WeaponKit.new()
	bad.weapon = "terminal_cannon"
	var own := WeaponSkin.new()
	own.skin = "violet"
	var only_own: Array[Resource] = [own]
	bad.skins = only_own
	var unknown := WeaponSkin.new()
	unknown.skin = "no_such_skin"
	unknown.feat = "kills_terminal_cannon"
	unknown.need = 5
	var bad2 := cannon.duplicate()
	var with_unknown: Array[Resource] = [cannon.skins[0], unknown]
	bad2.skins = with_unknown
	var free_skin := WeaponSkin.new()
	free_skin.skin = "tty1"
	var bad3 := cannon.duplicate()
	var with_free: Array[Resource] = [cannon.skins[0], free_skin, cannon.skins[2]]
	bad3.skins = with_free
	var def0: WeaponDefScript = _defs[0]
	_check("a broken kit is refused by name: the first skin not the weapon's own, a skin not in the palette, an earned skin with no feat", ", ".join(bad.problems(def0)).contains("weapon's own") and ", ".join(bad2.problems(def0)).contains("palette skin name") and ", ".join(bad3.problems(def0)).contains("earned"))


# --- The colours: never an enemy's, and apart at a glance. ---

func _palette_checks() -> void:
	var near := INF
	var near_name := ""
	var crowded := PackedStringArray()
	var dim := PackedStringArray()
	for def in _defs:
		var kit := WeaponKit.of(def.id)
		for skin in kit.skins.slice(1):
			for light in [skin.body(), skin.beam()]:
				for hostile in Palette.HOSTILE_LIGHTS:
					var d := _oklab(light).distance_to(_oklab(hostile))
					if d < near:
						near = d
						near_name = "%s #%s from #%s" % [skin.skin, light.to_html(false), hostile.to_html(false)]
			if _oklab(skin.beam()).x < BEAM_LIGHT:
				dim.append(skin.skin)
		for i in kit.skins.size():
			for j in range(i + 1, kit.skins.size()):
				var apart := _oklab(kit.skins[i].body()).distance_to(_oklab(kit.skins[j].body()))
				if apart < APART:
					crowded.append("%s/%s %.3f" % [kit.skins[i].skin, kit.skins[j].skin, apart])
	_check("acceptance: every earned skin's body and beam keep at least %.2f (OKLab) from every hostile light (the daemons' crimson, hostile red and amber, the runaway's hot magenta, the glitch's magenta, ICE's glacier, the hunter's cobalt, Black ICE's slate), so a weapon never reads as an enemy: nearest %.3f (%s)" % [FLOOR, near, near_name], near >= FLOOR and Palette.HOSTILE_LIGHTS.size() == 8 and Palette.HOSTILE_LIGHTS.has(Palette.CRIMSON) and Palette.HOSTILE_LIGHTS.has(Palette.HOSTILE_AMBER) and Palette.HOSTILE_LIGHTS.has(Palette.HOT_MAGENTA) and Palette.HOSTILE_LIGHTS.has(Palette.GLACIER) and Palette.HOSTILE_LIGHTS.has(Palette.HUNTER_COBALT) and Palette.HOSTILE_LIGHTS.has(Palette.BLACK_ICE))
	_check("acceptance: a weapon's skins look clearly different at a glance: their bodies at least %.2f apart (OKLab), its own among them; every beam light enough to read as the strip's text on black (lightness %.2f and up)" % [APART, BEAM_LIGHT], crowded.is_empty() and dim.is_empty(), "%s | %s" % [", ".join(crowded), ", ".join(dim)])
	_check("the weapons' own skins are as they were: the cannon teal and mint, SIGTERM violet, the rail ice, chmod's frost with its own highlight", Palette.SKINS["teal"] == [Palette.TEAL, Palette.MINT] and Palette.SKINS["violet"] == [Palette.VIOLET, Palette.VIOLET_HI] and Palette.SKINS["ice"] == [Palette.ICE, Palette.ICE_HI] and Palette.skin_hot("frost") == Palette.FROST_HI and Palette.skin_hot("carrier") == Palette.SIGHUP_HI)


# --- The mods: sidegrades, exactly their own numbers. ---

func _mod_checks() -> void:
	var wrong := PackedStringArray()
	for def in _defs:
		var mod: WeaponMod = WeaponKit.of(def.id).mod
		var before := _numbers(def)
		var copy: WeaponDefScript = mod.apply_to(def)
		var after := _numbers(copy)
		var expected := {}
		for change in [mod.gains, mod.costs]:
			for key in change:
				expected[key] = change[key]
		for key in after:
			var was = before.get(key)
			if expected.has(key):
				if after[key] != expected[key]:
					wrong.append("%s %s is %s, not %s" % [def.id, key, str(after[key]), str(expected[key])])
			elif after[key] != was:
				wrong.append("%s %s moved" % [def.id, key])
		if _numbers(def) != before:
			wrong.append("%s: the shipped weapon changed" % def.id)
		if not mod.problems(def).is_empty():
			wrong.append("%s: %s" % [def.id, mod.problems(def)[0]])
	_check("acceptance: a mod changes exactly its numbers and nothing else (every number of the weapon and its tuning compared), on a copy: the shipped weapon untouched; and every mod passes its checks (a gain moves its number the better way, a cost the worse, the modded weapon passes the weapon's own)", wrong.is_empty(), "; ".join(wrong))
	var cannon: WeaponDefScript = _defs[0]
	var over: WeaponDefScript = WeaponKit.of("terminal_cannon").mod.apply_to(cannon)
	_check("the cannon's overclock: a 0.13 s interval for 21 a hit (0.16 s and 25 as shipped): faster, thinner, never strictly better; it reads \"%s\"" % ", ".join(WeaponKit.of("terminal_cannon").mod.lines(cannon)), absf(over.fire_cooldown - 0.13) < EPS and absf(over.damage - 21.0) < EPS and absf(cannon.fire_cooldown - 0.16) < EPS and cannon.damage == 25.0 and WeaponKit.of("terminal_cannon").mod.lines(cannon) == PackedStringArray(["+ fire interval 0.16 > 0.13s", "- damage 25 > 21"]))
	var greedy := WeaponMod.new()
	greedy.id = "greedy"
	greedy.display_name = "greedy"
	greedy.fiction = "all gain"
	greedy.feat = "kills_terminal_cannon"
	greedy.need = 1
	greedy.gains = {"fire_cooldown": 0.1}
	greedy.costs = {"damage": 30.0}
	var sneaky := greedy.duplicate()
	sneaky.costs = {}
	var reach := greedy.duplicate()
	reach.costs = {"beam_energy": 1.0}
	_check("a mod that is strictly better is refused by name: a \"cost\" that helps, no cost at all, a number no mod may set", ", ".join(greedy.problems(cannon)).contains("must be worse") and ", ".join(sneaky.problems(cannon)).contains("sidegrade") and ", ".join(reach.problems(cannon)).contains("may not set"))


# --- The save. ---

func _save_checks() -> void:
	var path := _tmp.path_join("save-trip.cfg")
	var p := Progress.new()
	p.path = path
	var missing := p.load_file()
	_check("acceptance: a missing save is a fresh profile, never a crash", missing == "missing" and p.feats.is_empty() and p.held.is_empty())
	p.count("kills_terminal_cannon", 30)
	p.count("discards", 2)
	var chose := p.choose_skin("terminal_cannon", "tty1") and p.choose_mod("terminal_cannon", true) and p.choose_mod("dev_null", true)
	var written := p.save()
	var text := FileAccess.get_file_as_string(path)
	var q := Progress.new()
	q.path = path
	var loaded := q.load_file()
	_check("acceptance: the save is written and read back whole: its counts, what was earned and the choices (\"%s\")" % loaded, chose and written and loaded == "loaded" and q.count_of("kills_terminal_cannon") == 30 and q.count_of("discards") == 2 and q.has("terminal_cannon", "tty1") and q.has("terminal_cannon", "overclock") and not q.has("terminal_cannon", "dracula") and q.skin_of("terminal_cannon") == "tty1" and q.mod_on("terminal_cannon") and q.mod_on("dev_null"))
	_check("the save is small, plain and versioned: [progress] format=1, [feats], [unlocked], [loadout], plain literals only, no temporary file left behind (%d bytes)" % text.length(), text.contains("[progress]") and text.contains("format=1") and text.contains("[feats]") and text.contains("kills_terminal_cannon=30") and text.contains("terminal_cannon__tty1=true") and text.contains("skin_terminal_cannon=\"tty1\"") and text.length() < SettingsFile.MAX_BYTES and not FileAccess.file_exists(path + ".tmp"))
	var bad := PackedStringArray()
	for pair in [["garbage", "this is not a save at all\n" + char(1) + char(2)], ["object", "[meta]\nversion=1\n[progress]\nformat=1\n[feats]\nkills_sigterm=Object(Node)\n"], ["newer", "[meta]\nversion=1\n[progress]\nformat=2\n[feats]\nkills_sigterm=4\n"], ["no format", "[meta]\nversion=1\n[feats]\nkills_sigterm=4\n"], ["huge", "[meta]\nversion=1\n" + "x".repeat(5000)]]:
		var file := FileAccess.open(_tmp.path_join("corrupt.cfg"), FileAccess.WRITE)
		file.store_string(pair[1])
		file.close()
		var c := Progress.new()
		c.path = _tmp.path_join("corrupt.cfg")
		if c.load_file() != "unreadable" or not c.feats.is_empty() or not c.held.is_empty():
			bad.append(pair[0])
	_check("acceptance: a corrupt save (garbage, an object, a newer format, none, too big) is a fresh profile, never a crash, never an object", bad.is_empty(), ", ".join(bad))
	var junk := FileAccess.open(_tmp.path_join("odd.cfg"), FileAccess.WRITE)
	junk.store_string("[meta]\nversion=1\n[progress]\nformat=1\n[feats]\nkills_sigterm=7\nno_such_feat=9\nfreezes=-3\n[unlocked]\nsigterm__ctrl_c=true\nsigterm__nothing=true\n[loadout]\nskin_sigterm=\"catppuccin\"\nskin_sighup=\"teal\"\n")
	junk.close()
	var o := Progress.new()
	o.path = _tmp.path_join("odd.cfg")
	o.load_file()
	_check("a save's bad values are left out one by one: an unknown feat or item, a negative count, a skin of another weapon or not earned", o.count_of("kills_sigterm") == 7 and not o.feats.has("no_such_feat") and not o.feats.has("freezes") and o.has("sigterm", "ctrl_c") and o.held.size() == 1 and o.skin_of("sigterm") == "violet" and o.skin_of("sighup") == "carrier")
	var guard := Progress.new()
	guard.path = "res://progress.cfg"
	var refused_res := not guard.save()
	guard.path = "progress.cfg"
	_check("a save anywhere but user:// (or a test's absolute folder) is refused and nothing is written", refused_res and not guard.save() and not FileAccess.file_exists("res://progress.cfg"))


# --- The rule: thresholds, once each, the flag. ---

func _threshold_checks() -> void:
	var p := Progress.new()
	var told: Array = []
	p.unlocked.connect(func(weapon: String, item: String, title: String): told.append("%s/%s/%s" % [weapon, item, title]))
	p.count("kills_terminal_cannon", 9)
	var short := not p.has("terminal_cannon", "overclock")
	var got := p.count("kills_terminal_cannon")
	_check("acceptance: a threshold's edges: one short of the overclock's 10 kills nothing is earned; the 10th earns it, told once (\"%s\")" % ", ".join(told), short and p.has("terminal_cannon", "overclock") and got.size() == 1 and told == ["terminal_cannon/overclock/overclock  (cannon mod)"])
	p.count("kills_terminal_cannon", 14)
	var before_25 := not p.has("terminal_cannon", "tty1")
	p.count("kills_terminal_cannon")
	p.count("kills_terminal_cannon", 500)
	_check("the next ones in turn: tty1 at 25, not at 24; Dracula at 75; each told exactly once, never again however far the count goes (%d told)" % told.size(), before_25 and p.has("terminal_cannon", "tty1") and p.has("terminal_cannon", "dracula") and told.size() == 3 and told[1].begins_with("terminal_cannon/tty1/") and told[2].begins_with("terminal_cannon/dracula/"))
	var unknown := p.count("no_such_feat", 5)
	var zero := p.count("pings", 0)
	_check("a feat it does not know, or a count of nothing, earns nothing and counts nothing", unknown.is_empty() and zero.is_empty() and not p.feats.has("no_such_feat") and not p.feats.has("pings"))
	var flag := Progress.new()
	flag.path = _tmp.path_join("flag.cfg")
	flag.all_unlocked = true
	var all_held := true
	for def in _defs:
		var kit := WeaponKit.of(def.id)
		for skin in kit.skins:
			all_held = all_held and flag.has(def.id, skin.skin)
		all_held = all_held and flag.has(def.id, kit.mod.id)
	var worn := flag.choose_skin("rm_rf_cannon", "dd") and flag.choose_mod("rm_rf_cannon", true)
	var saved := flag.save()
	var reread := Progress.new()
	reread.path = flag.path
	reread.load_file()
	_check("acceptance: the dev and test flag (--unlock-all) holds every skin and mod for the run, to wear and fit, without earning or saving any of them (what it chose is saved, and is the weapon's own again without the flag)", all_held and worn and saved and flag.held.is_empty() and reread.held.is_empty() and reread.skin_of("rm_rf_cannon") == "ember" and not reread.mod_on("rm_rf_cannon"))


# --- The real arena alone: earning, wearing, resetting. ---

func _solo_checks() -> void:
	_p.clear()
	_p.count("kills_terminal_cannon", 9)
	var told: Array = []
	_p.unlocked.connect(func(_w: String, item: String, _t: String): told.append(item))
	var main := await _lab({"DummyA": Vector3(0.0, 0.0, 9.0)}, OPEN)
	var player = main.get_node("Player")
	var a := _dummy(main, "DummyA")
	_toughen(a, 20.0)
	_aim(player, a.global_position + Vector3.UP * 0.9)
	await _fire(player)
	var downed := await _wait(func(): return not a.is_alive(), 30)
	await _frames(2)
	var toast: UnlockToast = main.get_node("Hud").unlock_toast()
	_check("acceptance: a feat earns alone against the daemons fighting back: a real kill with the real cannon counts (9 to %d kills with the cannon) and earns the overclock at once, \"%s\" on screen" % [_p.count_of("kills_terminal_cannon"), toast.text()], downed >= 0 and _p.count_of("kills_terminal_cannon") == 10 and told == ["overclock"] and toast.showing() and toast.text() == "UNLOCKED: overclock")
	var saved := FileAccess.get_file_as_string(_p.path)
	_check("an unlock is saved at once (the round's end, a pause and quitting save the counts between)", saved.contains("terminal_cannon__overclock=true") and saved.contains("kills_terminal_cannon=10"))
	await _drop(main)
	var practice := await _lab({"DummyA": Vector3(0.0, 0.0, 9.0)}, OPEN, true)
	var pp = practice.get_node("Player")
	var pa := _dummy(practice, "DummyA")
	_toughen(pa, 20.0)
	_aim(pp, pa.global_position + Vector3.UP * 0.9)
	await _fire(pp)
	var practice_down := await _wait(func(): return not pa.is_alive(), 30)
	_check("acceptance: never from practice's never-attack dummies: the same kill with practice on counts nothing (%d kills, still)" % _p.count_of("kills_terminal_cannon"), practice_down >= 0 and _p.count_of("kills_terminal_cannon") == 10 and not _p.has("terminal_cannon", "tty1"))
	await _drop(practice)
	# Wearing: the overclock fitted and tty1 (held for the run) on the cannon, choke on SIGTERM, with a magazine part spent.
	_p.count("kills_terminal_cannon", 15)
	_p.count("kills_sigterm", 8)
	var lab := await _lab({"DummyA": Vector3(0.0, 0.0, 9.0)}, OPEN)
	var player2 = lab.get_node("Player")
	player2.inventory.mags[1] = 3
	_p.choose_skin("terminal_cannon", "tty1")
	_p.choose_mod("terminal_cannon", true)
	_p.choose_mod("sigterm", true)
	player2.wear(player2.chosen_look())
	await _frames(2)
	var worn: WeaponDefScript = player2.inventory.defs[0]
	var model: Viewmodel = player2.get("_viewmodels")[0]
	_check("acceptance: wearing changes the weapon in hand: the cannon overclocked (0.13 s, 21 a hit) in tty1, its model's seams in tty1's phosphor green, the strip's entry in its beam; SIGTERM choked (7 pellets in 4 degrees) keeping its 3 rounds; the shipped weapons untouched", absf(worn.fire_cooldown - 0.13) < EPS and absf(worn.damage - 21.0) < EPS and worn.light_skin == "tty1" and model.glow.emission == Palette.SKIN_PHOSPHOR and WeaponHudScript.skin_tint(worn) == Palette.MATRIX_HEAD and player2.inventory.defs[1].pellet_count == 7 and player2.inventory.mags[1] == 3 and _defs[0].damage == 25.0 and _defs[0].light_skin == "teal")
	var la := _dummy(lab, "DummyA")
	_toughen(la, 100.0)
	_aim(player2, la.global_position + Vector3.UP * 0.9)
	await _frames(12)
	await _fire(player2)
	await _frames(2)
	_check("a real shot lands the mod's damage: the overclocked cannon takes 21 off the daemon (%.1f left of 100)" % la.health(), absf(la.health() - 79.0) < 0.01)
	_arenas.erase(lab)
	_arenas.append(lab)


func _reset_checks() -> void:
	var lab: Node = _arenas.back()
	var player = lab.get_node("Player")
	var menu: PauseMenu = lab.get_node("Hud").pause_menu()
	menu.open()
	menu.open_settings()
	var reset: Button = menu.get("_reset")
	reset.pressed.emit()
	var asked := menu.status_text()
	var intact := _p.has("terminal_cannon", "overclock") and _p.count_of("kills_terminal_cannon") == 25
	await _frames(int(PauseMenu.RESET_WAIT_S * 60.0) + 10)
	var lapsed := reset.text == PauseMenu.RESET_PROGRESS and _p.has("terminal_cannon", "overclock")
	reset.pressed.emit()
	await _frames(2)
	var asked_again := reset.text == PauseMenu.RESET_CONFIRM and _p.has("terminal_cannon", "overclock")
	reset.pressed.emit()
	await _frames(2)
	var text := FileAccess.get_file_as_string(_p.path)
	_check("acceptance: reset progress asks first (\"%s\"), keeps everything if the second click does not come in %d s, and on the second wipes every count, unlock and choice, saved, the weapons back to their own: \"%s\"" % [asked, roundi(PauseMenu.RESET_WAIT_S), menu.status_text()], asked.begins_with("Wipe every unlock") and intact and lapsed and asked_again and _p.feats.is_empty() and _p.held.is_empty() and _p.skins.is_empty() and _p.mods.is_empty() and not text.contains("kills_") and player.inventory.defs[0].light_skin == "teal" and player.inventory.defs[0].damage == 25.0)
	menu.close()
	await _frames(2)


# --- The loadout screen and the toast, at 960x540. ---

func _screen_checks() -> void:
	var lab: Node = _arenas.back()
	root.size = Vector2i(960, 540)
	await _frames(3)
	_p.clear()
	_p.count("kills_terminal_cannon", 30)
	var player = lab.get_node("Player")
	player.select_slot(0)
	await _frames(20)
	var menu: PauseMenu = lab.get_node("Hud").pause_menu()
	menu.open()
	menu.open_loadout()
	await _frames(3)
	var screen: LoadoutScreen = menu.loadout_screen()
	var rect := screen.panel_rect()
	var texts := screen.texts()
	var joined := "\n".join(texts)
	var rows := 0
	for def in _defs:
		rows += 1 if joined.contains(def.short_name) else 0
	_check("acceptance: the loadout screen from the Esc menu (no key of its own), whole on a 960x540 screen with no page scroll (shrunk to %.2f, its panel %s inside 960x540), every weapon of the arsenal listed (%d)" % [screen.fit_scale(), rect, rows], menu.showing_loadout() and screen.fit_scale() <= 1.0 and rect.position.x >= 0.0 and rect.position.y >= 0.0 and rect.end.x <= 960.0 + EPS and rect.end.y <= 540.0 + EPS and rows == _defs.size() and screen.get("_rows").size() == 13)
	_check("acceptance: the weapon on show (the one in hand) has its cards: its own skin worn, tty1 held, Dracula locked with how it is earned (\"LOCKED  30 / 75 kills with cannon\"), its mod with what it gains and what it costs", joined.contains("Terminal cannon") and joined.contains("WEARING") and joined.contains("click to wear") and joined.contains("LOCKED  30 / 75 kills with cannon") and joined.contains("+ fire interval 0.16 > 0.13s") and joined.contains("- damage 25 > 21") and joined.contains("FITTED: click to take off") == false and joined.contains("click to fit"), joined.replace("\n", " | "))
	var stage := screen.stage
	var model := stage.model
	var start := stage.turned()
	await _frames(30)
	_check("the turntable: the weapon's own model large and alone in its own world, slowly turning, lit in the skin it wears (its seams teal)", model != null and is_instance_valid(model) and stage.own_world_3d and stage.turned() > start + 0.4 and model.glow.emission == Palette.TEAL and model.get_parent().name == "Turntable")
	screen.preview(2)
	var lit_locked := stage.model.glow.emission == Palette.SKIN_DRACULA and stage.skin == "dracula"
	screen.preview(-1)
	var back := stage.model.glow.emission == Palette.TEAL
	_check("acceptance: a card under the pointer lights the model in that skin at once, a locked one too (Dracula's purple), and leaving it puts back the one worn", lit_locked and back)
	var refused := not screen.wear_skin(2)
	var wore := screen.wear_skin(1)
	var fitted := screen.toggle_mod()
	_check("a click wears a held skin (tty1, the model rebuilt in it) and fits a held mod, saved at once; a locked one is refused", refused and wore and fitted and _p.skin_of("terminal_cannon") == "tty1" and _p.mod_on("terminal_cannon") and stage.model.glow.emission == Palette.SKIN_PHOSPHOR and FileAccess.get_file_as_string(_p.path).contains("skin_terminal_cannon=\"tty1\""))
	screen.select(12)
	await _frames(2)
	var hup_texts := "\n".join(screen.texts())
	_check("another weapon from the list: SIGHUP's cards, its skins locked behind their feats (\"0 / 1 kills by a confused daemon's lash\") and its mod behind its own (\"0 / 6 daemons hung up\")", hup_texts.contains("SIGHUP") and hup_texts.contains("0 / 1 kills by a confused daemon's lash") and hup_texts.contains("0 / 6 daemons hung up") and screen.stage.def.id == "sighup")
	_send_key(KEY_ESCAPE, true)
	await process_frame
	_send_key(KEY_ESCAPE, false)
	await _frames(3)
	var worn: WeaponDefScript = player.inventory.defs[0]
	_check("acceptance: Esc goes back to the menu, and alone the player wears what it chose as the screen closes (the cannon now tty1 and overclocked in hand)", not screen.is_open() and menu.is_open() and not menu.showing_loadout() and worn.light_skin == "tty1" and absf(worn.damage - 21.0) < EPS)
	menu.close()
	await _frames(3)
	var toast: UnlockToast = lab.get_node("Hud").unlock_toast()
	await _wait(func(): return not toast.showing(), 900)  # the cannon's two from before told first
	_p.count("kills_sigterm", 50)
	await _frames(2)
	var first := toast.text()
	var waiting := toast.waiting()
	var tr: Rect2 = Rect2(toast.position, UnlockToast.SIZE)
	_check("acceptance: the toast: \"%s\" near the top the moment it is earned, whole on the 960x540 screen, the next one waiting its turn (%d)" % [first, waiting], first == "UNLOCKED: choke" and waiting == 2 and tr.position.x >= 0.0 and tr.end.x <= 960.0 and tr.position.y >= 0.0 and tr.end.y <= 540.0)
	await _frames(int((UnlockToast.SHOW_S + 0.1) * 60.0))
	var second := toast.text()
	await _frames(int((UnlockToast.SHOW_S + 0.1) * 60.0) * 2)
	_check("each in turn, then gone: \"%s\" next, and none showing once all are told" % second, second == "UNLOCKED: ^C" and not toast.showing() and toast.waiting() == 0)
	root.size = Vector2i(1280, 720)
	await _drop(lab)


# --- A match: the host judges each player's mod; everyone sees each player's skin. ---

func _match_checks() -> void:
	GameSettings.current().set_value("gameplay", "practice", true)
	GameSettings.current().set_value("gameplay", "ice", false)
	GameSettings.current().set_value("multiplayer", "mods", true)
	_p.clear()
	var host := _branch("Host", Vector3.ZERO)
	var client := _branch("Client", CLIENT_OFFSET)
	await _frames(2)
	host["session"].host(0)
	await _frames(2)
	# The joiner's own choices, made before it joins (one process, one progress): tty1 and the overclock on the
	# cannon, chattr +i on chmod 000, held through the test flag.
	_p.all_unlocked = true
	_p.choose_skin("terminal_cannon", "tty1")
	_p.choose_mod("terminal_cannon", true)
	_p.choose_skin("chmod_000", "immutable")
	var joined := await _join_hosted(host, client)
	var hs: Session = host["session"]
	var cs: Session = client["session"]
	var hp = host["player"]
	var cp = client["player"]
	var cid: int = cs.my_id
	var judged: WeaponDefScript = hs.combat.def_of(cid, "terminal_cannon")
	_check("acceptance: a host and a joiner over ENet on 127.0.0.1, protocol 19: the joiner's look rides its hello, and the host accepts its mod and judges with it (the joiner's cannon 21 a hit every 0.13 s in the host's count; the host's own 25 as shipped)", joined and Session.PROTOCOL == 19 and absf(judged.damage - 21.0) < EPS and absf(judged.fire_cooldown - 0.13) < EPS and hs.combat.def_of(1, "terminal_cannon").damage == 25.0 and (hs.look_of(cid)[0] & Loadout.MOD_BIT) != 0)
	_check("the joiner wears what the host accepted (its cannon overclocked, in tty1); every roster carries each look: the joiner's screen knows its own and the host's stock one", cp.inventory.defs[0].light_skin == "tty1" and absf(cp.inventory.defs[0].damage - 21.0) < EPS and cs.look_of(cid) == hs.look_of(cid) and cs.look_of(1) == Loadout.stock(_defs))
	var avatar = hs.avatars.get(cid)
	_check("acceptance: a skin seen by the other player: on the host's screen the joiner's shots are drawn in its tty1 (its cannon as the host draws it) and its avatar's freeze beam is painted chattr +i's paper white", hs.def_of(cid, "terminal_cannon").skin_beam() == Palette.MATRIX_HEAD and avatar != null and avatar.freeze_beam().body == Palette.SKIN_PAPER and cs.def_of(1, "terminal_cannon").light_skin == "teal")
	for name in ["DummyA", "DummyB", "DummyC", "DummyD"]:
		_park(_dummy(host["main"], name))
		_park(_dummy(client["main"], name))
	hs.combat.states[1]["protect_left"] = 0.0
	hs.combat.states[cid]["protect_left"] = 0.0
	hp.global_position = host["main"].to_global(Vector3(0.0, 0.95, 8.0))
	cp.global_position = client["main"].to_global(OPEN)
	await _frames(20)
	_aim(cp, client["main"].to_global(Vector3(0.0, 1.4, 8.0)))
	var before: float = hs.combat.health_of(1)
	await _fire(cp)
	var landed := await _wait(func(): return hs.combat.health_of(1) < before, 60)
	# The tracer lives a few frames: read it the frame the host's judgement lands.
	var beams := 0
	for node in host["main"].find_children("CannonBeam*", "", true, false):
		for mesh in node.find_children("*", "MeshInstance3D", true, false):
			var mat := (mesh as MeshInstance3D).material_override as StandardMaterial3D
			if mat != null and _hue_close(mat.albedo_color, Palette.MATRIX_HEAD):
				beams += 1
	await _frames(10)
	_check("acceptance: the host judges the joiner's real shot with its mod: 21 off the host (%.0f to %.0f), and draws its tracer in the joiner's tty1 (%d)" % [before, hs.combat.health_of(1), beams], landed >= 0 and absf(before - hs.combat.health_of(1) - 21.0) < 0.01 and beams >= 1)
	# A kill counted for the joiner from the host's word alone: the host left at 10, one more shot.
	var kills_before := _p.count_of("kills_terminal_cannon")
	hs.combat.states[1]["health"] = 10.0
	await _frames(12)
	await _fire(cp)
	var died := await _wait(func(): return hs.dead.get(1, false) and cs.dead.get(1, false), 90)
	await _frames(5)
	_check("acceptance: in a match a kill counts from the host's judged result for this player alone: the joiner's kill of the host counted once (%d to %d), the host counting nothing for a death" % [kills_before, _p.count_of("kills_terminal_cannon")], died >= 0 and _p.count_of("kills_terminal_cannon") == kills_before + 1)
	cs.leave()
	await _frames(5)
	_check("leaving the match, the joiner wears its own choices again (still overclocked and in tty1: its own, fitted)", cp.inventory.defs[0].light_skin == "tty1" and absf(cp.inventory.defs[0].damage - 21.0) < EPS)
	hs.leave()
	await _frames(5)
	# The host's mods rule off: the joiner's mod ignored, its skin still seen.
	GameSettings.current().set_value("multiplayer", "mods", false)
	host["session"].host(0)
	await _frames(2)
	var rejoined := await _join_hosted(host, client)
	cid = cs.my_id
	var plain: WeaponDefScript = hs.combat.def_of(cid, "terminal_cannon")
	_check("acceptance: the host's mods rule off: the joiner's mod is ignored (the host judges its cannon as shipped, 25 a hit every 0.16 s; the joiner wears it so, told the rule) while its skin is still tty1 on both screens", rejoined and plain.damage == 25.0 and absf(plain.fire_cooldown - 0.16) < EPS and (hs.look_of(cid)[0] & Loadout.MOD_BIT) == 0 and hs.def_of(cid, "terminal_cannon").light_skin == "tty1" and cp.inventory.defs[0].damage == 25.0 and cp.inventory.defs[0].light_skin == "tty1" and cs.match_mods == false and hs.match_mods == false)
	hs.combat.states[1]["protect_left"] = 0.0
	hs.combat.states[cid]["protect_left"] = 0.0
	hp.global_position = host["main"].to_global(Vector3(0.0, 0.95, 8.0))
	cp.global_position = client["main"].to_global(OPEN)
	await _frames(20)
	_aim(cp, client["main"].to_global(Vector3(0.0, 1.4, 8.0)))
	before = hs.combat.health_of(1)
	await _fire(cp)
	await _wait(func(): return hs.combat.health_of(1) < before, 60)
	_check("and a real shot of the joiner's lands the shipped 25 (%.0f to %.0f)" % [before, hs.combat.health_of(1)], absf(before - hs.combat.health_of(1) - 25.0) < 0.01)
	_p.all_unlocked = false
	GameSettings.current().set_value("multiplayer", "mods", true)
	await _drop_side(client)
	await _drop_side(host)


# --- Helpers. ---

## Every number a weapon holds, its tunings' too ("<slot>:<name>"), for comparing.
func _numbers(def: Resource) -> Dictionary:
	var out := {}
	for prop in def.get_property_list():
		if not (prop["usage"] & PROPERTY_USAGE_STORAGE):
			continue
		var v = def.get(prop["name"])
		if v is int or v is float or v is bool or v is String:
			out[prop["name"]] = v
		elif v is Resource and ["projectile", "freeze", "pipe"].has(prop["name"]):
			for inner in (v as Resource).get_property_list():
				if inner["usage"] & PROPERTY_USAGE_STORAGE:
					var w = (v as Resource).get(inner["name"])
					if w is int or w is float or w is bool:
						out["%s:%s" % [prop["name"], inner["name"]]] = w
	return out


func _hue_close(a: Color, b: Color) -> bool:
	var n := Vector3(a.r, a.g, a.b).normalized()
	var m := Vector3(b.r, b.g, b.b).normalized()
	return n.distance_to(m) < 0.02


func _fire(p: Node) -> void:
	await physics_frame
	p.drive_input(Vector2.ZERO, false, false, true)
	await physics_frame
	await physics_frame
	p.drive_input(Vector2.ZERO, false, false, false)


func _toughen(dummy: Node3D, health: float) -> void:
	dummy.max_health = health
	dummy.set("_health", health)


func _lab(keep: Dictionary, player_at: Vector3, practice: bool = false) -> Node:
	GameSettings.current().set_value("gameplay", "practice", practice)
	GameSettings.current().set_value("gameplay", "difficulty", "normal")
	GameSettings.current().set_value("gameplay", "ice", false)
	var link := Link.new()
	link.settings_path = _tmp.path_join("arena-privacy.cfg")
	link.demo = true
	Link.park(link)
	var main = MainScene.instantiate()
	root.add_child(main)
	_arenas.append(main)
	main.get_node("Hud").guide().focus_check = func(): return false
	main.get_node("Hud").round_hud()._left_s = LONG_ROUND_S
	var player = main.get_node("Player")
	player.assume_captured = true
	player.global_position = main.to_global(player_at)
	player.velocity = Vector3.ZERO
	for dummy in main.get_node("Arena/Targets").get_children():
		if keep.has(String(dummy.name)):
			_place(dummy, main.to_global(keep[String(dummy.name)]))
		else:
			_park(dummy)
	await _frames(2)
	return main


func _drop(main: Node) -> void:
	if is_instance_valid(main):
		for sfx in main.find_children("*", "AudioStreamPlayer", true, false):
			(sfx as AudioStreamPlayer).stop()
		for sfx in main.find_children("*", "AudioStreamPlayer3D", true, false):
			(sfx as AudioStreamPlayer3D).stop()
		main.free()
	_arenas.erase(main)
	var left = Link.take_parked()
	if left != null:
		left.shut_down(null)
	await process_frame


## Turns the player to face `point` (world space), its view tipped up or down to it from its eyes.
func _aim(player: Node3D, point: Vector3) -> void:
	var way: Vector3 = point - player.global_position
	player.rotation.y = atan2(-way.x, -way.z)
	var eye: Vector3 = player.get_node("Head/Camera").global_position
	var to := point - eye
	player.get_node("Head").rotation.x = atan2(to.y, Vector2(to.x, to.z).length())


func _dummy(main: Node, name: String) -> Node3D:
	return main.get_node("Arena/Targets/" + name)


## A daemon put at `at` (world space), facing as the scene had it, at home there.
func _place(dummy: Node3D, at: Vector3) -> void:
	dummy.global_position = at
	dummy.global_rotation = Vector3.ZERO
	dummy.brain.take_home()
	dummy.brain.moved = false
	dummy.brain.state = DaemonBrain.State.HOME
	dummy.brain.prey = 0


func _park(dummy: Node3D) -> void:
	_place(dummy, PARKED + Vector3(dummy.get_index() * 3.0, 0.0, 0.0))


func _send_key(keycode: Key, down: bool) -> void:
	var event := InputEventKey.new()
	event.keycode = keycode
	event.physical_keycode = keycode
	event.pressed = down
	Input.parse_input_event(event)


func _frames(n: int) -> void:
	for i in maxi(n, 0):
		await physics_frame


## Frames until `condition` holds, or -1 after `most`.
func _wait(condition: Callable, most: int) -> int:
	for i in most:
		if condition.call():
			return i
		await physics_frame
	return most if condition.call() else -1


func _net_tuning() -> Resource:
	var t := NetTuningScript.new()
	t.bind_address = "127.0.0.1"
	t.connect_timeout_ms = 1500
	t.peer_timeout_ms = 2000
	return t


## A side of the game in its own branch: {branch, session, main, player, hud}.
func _branch(name: String, offset: Vector3) -> Dictionary:
	var api := SceneMultiplayer.new()
	var branch := Node3D.new()
	branch.name = name
	branch.position = offset
	root.add_child(branch)
	set_multiplayer(api, branch.get_path())
	var session := Session.new()
	session.name = Session.NODE_NAME
	session.tuning = _net_tuning()
	branch.add_child(session)
	_branches.append(branch)
	var main = MainScene.instantiate()
	branch.add_child(main)
	var out := {"branch": branch, "session": session, "main": main, "player": main.get_node("Player"), "hud": main.get_node("Hud")}
	out["player"].assume_captured = true
	main.get_node("Hud").guide().focus_check = func(): return false
	main.get_node("Hud").round_hud()._left_s = LONG_ROUND_S
	return out


func _drop_side(side: Dictionary) -> void:
	var branch: Node = side["branch"]
	if is_instance_valid(branch):
		for sfx in branch.find_children("*", "AudioStreamPlayer", true, false):
			(sfx as AudioStreamPlayer).stop()
		for sfx in branch.find_children("*", "AudioStreamPlayer3D", true, false):
			(sfx as AudioStreamPlayer3D).stop()
		side["session"].leave()
		branch.free()
	_branches.erase(branch)
	await process_frame


## The joiner joins the host already hosting: true once both sides agree and the joiner's weapons are synced.
func _join_hosted(host: Dictionary, client: Dictionary) -> bool:
	client["session"].join("127.0.0.1:%d" % host["session"].listen_port())
	var t0 := Time.get_ticks_msec()
	while not (client["session"].state == Session.State.JOINED and host["session"].players.size() == 2 and client["session"].players.size() == 2 and client["session"].get("_weapons_synced") == true):
		if Time.get_ticks_msec() - t0 > WATCHDOG_MS:
			return false
		await physics_frame
	await _frames(10)
	return true


func _cleanup() -> void:
	for node in _arenas.duplicate():
		await _drop(node)
	for branch in _branches.duplicate():
		if is_instance_valid(branch):
			branch.free()
	_p.clear()
	_p.all_unlocked = false
	_p.path = ""
	GameSettings.current().reset()
	Controls.apply_binds({})
	await process_frame
	OS.delay_msec(300)
	await process_frame


## OKLab of `c` (sRGB), as a point.
static func _oklab(c: Color) -> Vector3:
	var lin := func(x: float) -> float: return x / 12.92 if x <= 0.04045 else pow((x + 0.055) / 1.055, 2.4)
	var r: float = lin.call(c.r)
	var g: float = lin.call(c.g)
	var b: float = lin.call(c.b)
	var l := pow(0.4122214708 * r + 0.5363325363 * g + 0.0514459929 * b, 1.0 / 3.0)
	var m := pow(0.2119034982 * r + 0.6806995451 * g + 0.1073969566 * b, 1.0 / 3.0)
	var s := pow(0.0883024619 * r + 0.2817188376 * g + 0.6299787005 * b, 1.0 / 3.0)
	return Vector3(0.2104542553 * l + 0.7936177850 * m - 0.0040720468 * s, 1.9779984951 * l - 2.4285922050 * m + 0.4505937099 * s, 0.0259040371 * l + 0.7827717662 * m - 0.8086757660 * s)


func _code(path: String) -> String:
	return FileAccess.get_file_as_string(path)


## The text of function `name` in `source`, up to the next function.
func _body(source: String, name: String) -> String:
	var at := source.find("\nfunc %s(" % name)
	if at < 0:
		at = source.find("\nstatic func %s(" % name)
	if at < 0:
		return ""
	var end := source.find("\nfunc ", at + 1)
	var end_static := source.find("\nstatic func ", at + 1)
	if end < 0 or (end_static >= 0 and end_static < end):
		end = end_static
	return source.substr(at, end - at if end >= 0 else -1)
