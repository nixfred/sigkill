extends SceneTree
## Headless lighting, post and particles test for SIGKILL (A4). scripts/check.sh runs it, and any
## FAIL exits 1.
##
##   godot --headless --path . --fixed-fps 60 --script res://tests/graphics_test.gd
##
## Every frame finished, all of it visual only. The sources: the A4 code (the particle pools, the
## post layer) makes no OS call, opens no file, thread or socket and loads nothing at run time;
## nothing that runs each frame or each shot makes a node, mesh or material; the arena's shaders
## take their time from the one shader global arena_clock, never TIME; no gameplay number moved
## (resources/ and scripts/net/ byte for byte as at dee2482, the protocol still 9). The settings:
## each preset sets its features, a toggle changed by hand makes it "custom", and every graphics
## setting round-trips through the settings file, a file from before A4 taking its preset's. In the
## real arena: the look (AgX, a glow over a threshold, the grade, the gloss floor); the presets
## reaching the environment, the sun, the rain, the skyline and the particles, and low truly
## dropping every costly feature; the post effects drawn only when on and under the HUD; the warm
## signs' lamps and the lair's red danger lights; the particle pools: their sizes the caps, one
## process material and mesh per kind, one draw material per colour, a muzzle burst on every model,
## a burst of shots or trails reusing them, the frames and the shots making no object; the
## viewmodels' fixed projection (the same size on screen at any field of view, inside the player's
## radius so no barrel pokes into a wall) and projectiles drawn from the muzzle, their true paths
## untouched; the arena's clock slowed by SIGSTOP.
## Deterministic: frames counted, only counts and outcomes printed.

const Link = preload("res://scripts/guide/guide_link.gd")
const MainScene = preload("res://scenes/main.tscn")
const Controls = preload("res://scripts/controls.gd")
const Palette = preload("res://scripts/palette.gd")
const CannonFx = preload("res://scripts/cannon_fx.gd")
const RmSlug = preload("res://scripts/weapons/rm_slug.gd")
const SettingsFile = preload("res://scripts/settings/settings_file.gd")
const Player = preload("res://scripts/player.gd")

## resources/ (every .tres) and scripts/net/ (every .gd) as they were at dee2482: SHA-256 over each
## file's name and a newline, then its bytes, in name order. Since C27b resources/ also holds
## daemon_ai.tres, the daemons' own numbers: the pin covers the files dee2482 had (DEE2482_TRES),
## and nothing else may join them. Since C28 the arsenal holds ping as its ninth weapon
## (arsenal.tres) and resources/ holds ping_sonar.tres: the pin covers dee2482's other 24 files
## (603599096ad5, the same bytes as at dee2482; bff9abb41595 with arsenal.tres), and arsenal.tres
## is dee2482's to the byte once ping's three lines are taken out (ARSENAL_SHA, its load steps, its
## ping and the ping in the loadout): the eight before it and every timing number as they were. Since
## C29 it holds chmod 000 as its tenth (C29_TRES: chmod_000.tres beside them), its lines taken out too.
const RESOURCES_SHA := "603599096ad58a96c8c127f49f93d77c2a9d8aa9b4791ead955ff0504eb32b0a"
const ARSENAL_SHA := "b98ef06f812877af00be320ad1350d3942b35f03fa78c00d355c03b0ab1b39a4"
## Since C27b the session carries the daemons (its brief changes scripts/net/, protocol 10): the
## pin over scripts/net/ (eeca5f69c759 at dee2482, every .gd) is now its files that hold numbers,
## as they were at dee2482 (NET_NUMBERS_SHA). Since A5 the daemon state message carries each
## daemon's build seed: protocol 11, its numbers unchanged. Since I1 the session carries ICE's word and
## a field's effect (protocol 12), its numbers unchanged too; ICE's own numbers are resources/ice.tres
## (I1_TRES), which joins the files beside dee2482's. Since I2 the session carries the ICEbreakers' ask
## and word (protocol 13), its numbers unchanged; the breakers' own are resources/breakers.tres
## (I2_TRES). Since I3 the session carries Black ICE's word and a flatline's cause (protocol 14), its
## numbers unchanged; Black ICE's own are resources/black_ice.tres (I3_TRES). Since C29 the session
## carries chmod 000's beam ticks and freeze meters (protocol 15), its numbers unchanged; the freeze
## ray's own are resources/chmod_000.tres (C29_TRES).
const NET_NUMBERS := ["combat_tuning.gd", "net_tuning.gd", "room_tuning.gd"]
const NET_NUMBERS_SHA := "6e8b0b58e20b69a326149b8f30eae07063c31b4c5fdbaa49ec8675cb6952d9fc"
const PROTOCOL := 19
const DEE2482_TRES := ["announcer.tres", "boot.tres", "code_rain.tres", "code_rain_vision.tres", "combat.tres", "cron_mines.tres", "derezz.tres", "fork_bomb.tres", "fork_bomb_weapon.tres", "fork_shotgun.tres", "grep_seeker.tres", "guide.tres", "hud.tres", "light_trail.tres", "movement_tuning.tres", "net.tres", "rm_rf_cannon.tres", "room.tres", "sigkill_rail.tres", "sigstop.tres", "sigterm.tres", "spectate_top.tres", "sudo_overcharge.tres", "terminal_cannon.tres"]
const C27B_TRES := ["daemon_ai.tres"]
## The opener's own timeline (C38): resources/opener.tres. Its six palettes sit in resources/opener/, a folder this
## list never reads; nothing of either is a gameplay number.
const C38_TRES := ["opener.tres"]
const I1_TRES := ["ice.tres"]
const I2_TRES := ["breakers.tres"]
const I3_TRES := ["black_ice.tres"]
const C28_TRES := ["arsenal.tres", "ping_sonar.tres"]
const C29_TRES := ["chmod_000.tres"]
## pipe |'s own numbers (C30): resources/pipe_chain.tres.
const C30_TRES := ["pipe_chain.tres"]
## /dev/null's own numbers (C31): resources/dev_null.tres.
const C31_TRES := ["dev_null.tres"]
## SIGHUP's own numbers (C32): resources/sighup.tres.
const C32_TRES := ["sighup.tres"]
## Each weapon's kit beside it (C33): its skins and its mod, resources/<id>_kit.tres. The weapons' own files
## name their kit's ids in the C16 slots, which held nothing before; the pin reads them back empty
## (_without_c33_slots()), so it still proves no gameplay number of a weapon moved.
const C33_KITS := ["chmod_000_kit.tres", "cron_mines_kit.tres", "dev_null_kit.tres", "fork_bomb_kit.tres", "fork_shotgun_kit.tres", "grep_seeker_kit.tres", "ping_sonar_kit.tres", "pipe_chain_kit.tres", "rm_rf_cannon_kit.tres", "sighup_kit.tres", "sigkill_rail_kit.tres", "sigterm_kit.tres", "terminal_cannon_kit.tres"]
## The most particles the arena's pools may ever show at once, and the most a muzzle burst may. 1600 at
## A4 (full to the last since C29's frost pool); 1700 since C30, for pipe |'s own pool of packets (4 x 24);
## 1800 since C31, for /dev/null's own pool of debris drawn in (2 x 48); 1900 since C32, for SIGHUP's own pool
## of static flung out (2 x 48).
const PARTICLE_BUDGET := 1900
const MUZZLE_BUDGET := 32
## The player's collision capsule: no viewmodel may reach past it.
const PLAYER_RADIUS_M := 0.4
## How far apart a model's size on screen may be at two fields of view, in pixels.
const SCREEN_EPS_PX := 1.5
## Run each frame or each shot: none of these may make a node, mesh or material.
const PER_FRAME := {
	"res://scripts/fx/particle_fx.gd": ["_process", "_fire", "_release", "impact", "beam_end", "blast", "follow", "fire_muzzle", "following", "share", "trails_on", "of"],
	"res://scripts/arena/arena_art.gd": ["_process", "step_clock"],
	"res://scripts/player.gd": ["_fit_viewmodels", "muzzle_point", "take_volley"],
	"res://scripts/weapons/rm_slug.gd": ["_place", "draw_from"],
	"res://scripts/weapons/seeker_volley.gd": ["_place", "draw_from"],
	"res://scripts/weapons/fork_volley.gd": ["_place", "draw_from"],
}

var _fails := 0
var _checks := 0
var _tmp := ""
var _arenas: Array = []


func _initialize() -> void:
	GameSettings.current().set_value("gameplay", "practice", true)  # these checks predate C27b: the daemons stay the old never-attack dummies
	_run()


func _run() -> void:
	await process_frame
	root.size = Vector2i(1280, 720)
	_tmp = OS.get_temp_dir().path_join("sigkill-graphics-test-%d" % OS.get_process_id())
	if DirAccess.dir_exists_absolute(_tmp):
		print("FAIL the test's temporary folder already exists; not touching it")
		quit(1)
		return
	DirAccess.make_dir_recursive_absolute(_tmp)
	Controls.ensure()
	GameSettings.current().reset()
	GameSettings.current().set_value("gameplay", "practice", true)  # these checks predate C27b: the daemons stay the old never-attack dummies
	_source_checks()
	_settings_checks()
	var main := await _arena()
	await _look_checks(main)
	await _preset_checks(main)
	await _post_checks(main)
	await _particle_checks(main)
	await _viewmodel_checks(main)
	await _projectile_checks(main)
	await _clock_checks(main)
	await _cleanup()
	for name in DirAccess.get_files_at(_tmp):
		DirAccess.remove_absolute(_tmp.path_join(name))
	DirAccess.remove_absolute(_tmp)
	print("GRAPHICS: %d checks" % _checks)
	print("GRAPHICS RESULT: ", "ALL PASS" if _fails == 0 else "%d FAILED" % _fails)
	quit(0 if _fails == 0 else 1)


func _check(label: String, ok: bool, detail: String = "") -> void:
	_checks += 1
	print("PASS " if ok else "FAIL ", label, ("   " + detail) if detail != "" else "")
	if not ok:
		_fails += 1


# --- The sources. ---

func _source_checks() -> void:
	var code := ""
	for name in DirAccess.get_files_at("res://scripts/fx/"):
		if name.ends_with(".gd"):
			code += _code("res://scripts/fx/" + name)
	var found := PackedStringArray()
	for word in ["OS.", "execute", "create_process", "DirAccess", "FileAccess", "move_to_trash", "shell_open", "Thread", "HTTP", "PacketPeer", "StreamPeer", "TCPServer", "UDPServer", "Expression", "rpc", "Time.get"]:
		if code.contains(word):
			found.append(word)
	if RegEx.create_from_string("(?<!pre)load\\(").search(code) != null:
		found.append("load(")
	_check("acceptance: the A4 code (the particle pools, the post layer) is cosmetic only: no OS call, no file, folder, thread, socket or network, no wall clock, nothing loaded at run time, no RPC", found.is_empty() and code.length() > 6000, ", ".join(found))

	var made := PackedStringArray()
	var missing := PackedStringArray()
	for path in PER_FRAME:
		var source := _code(path)
		for fn in PER_FRAME[path]:
			var body := _body(source, fn)
			if body == "":
				missing.append("%s %s" % [path.get_file(), fn])
				continue
			for word in [".new(", "add_child", "duplicate(", "instantiate(", "SurfaceTool", "ArrayMesh"]:
				if body.contains(word):
					made.append("%s %s: %s" % [path.get_file(), fn, word])
	_check("acceptance: no per-frame or per-shot allocation: what runs each frame or each shot (the trails following, an impact, a blast, a muzzle burst, the arena's clock, the viewmodels' projection, a projectile drawn from the muzzle) makes no node, mesh or material", made.is_empty() and missing.is_empty(), "%s %s" % [", ".join(made), ", ".join(missing)])

	var clocked := FileAccess.get_file_as_string("res://project.godot").contains("arena_clock={\n\"type\": \"float\"")
	var timed := PackedStringArray()
	for shader in ["arena_light", "arena_screen", "arena_holo"]:
		var text := _shader_code("res://shaders/%s.gdshader" % shader)
		if text.contains("TIME") or not text.contains("global uniform float arena_clock;"):
			timed.append(shader)
	_check("acceptance: SIGSTOP slows the arena's strips (and its beacons, screens and holograms): their time is the shader global arena_clock, stepped at the game's pace, never TIME", clocked and timed.is_empty(), ", ".join(timed))

	var post := _shader_code("res://shaders/screen_post.gdshader")
	_check("the post effects never warp the picture: no curve or zoom, the aberration's pull zero at the screen's middle (it grows with the distance from it), so the crosshair's point stays true", post.contains("hint_screen_texture") and post.contains("dot(d, d)") and not post.contains("barrel") and not post.contains("curv"))

	var resources := _dir_sha("res://resources/", ".tres", DEE2482_TRES)
	var tres := Array(DirAccess.get_files_at("res://resources/")).filter(func(n): return n.ends_with(".tres"))
	tres.sort()
	var expected_tres := DEE2482_TRES + C27B_TRES + C28_TRES + I1_TRES + I2_TRES + I3_TRES + C29_TRES + C30_TRES + C31_TRES + C32_TRES + C33_KITS + C38_TRES
	expected_tres.sort()
	resources = resources if tres == expected_tres else "files %s" % ", ".join(tres)
	var net := _dir_sha("res://scripts/net/", ".gd", NET_NUMBERS)
	var protocol := _code("res://scripts/net/net_session.gd").contains("const PROTOCOL := %d" % PROTOCOL)
	var arsenal_text := FileAccess.get_file_as_string("res://resources/arsenal.tres")
	var as_was := arsenal_text.replace("load_steps=15", "load_steps=10").replace("[ext_resource type=\"Resource\" path=\"res://resources/ping_sonar.tres\" id=\"10_ping\"]\n", "").replace("[ext_resource type=\"Resource\" path=\"res://resources/chmod_000.tres\" id=\"11_chmod\"]\n", "").replace("[ext_resource type=\"Resource\" path=\"res://resources/pipe_chain.tres\" id=\"12_pipe\"]\n", "").replace("[ext_resource type=\"Resource\" path=\"res://resources/dev_null.tres\" id=\"13_dev_null\"]\n", "").replace("[ext_resource type=\"Resource\" path=\"res://resources/sighup.tres\" id=\"14_sighup\"]\n", "").replace(", ExtResource(\"10_ping\"), ExtResource(\"11_chmod\"), ExtResource(\"12_pipe\"), ExtResource(\"13_dev_null\"), ExtResource(\"14_sighup\")])", "])")
	var arsenal := as_was.sha256_text()
	resources = resources if arsenal == ARSENAL_SHA and arsenal_text != as_was else "arsenal %s" % arsenal.left(12)
	_check("acceptance: no gameplay number changed: resources/ (dee2482's files; daemon_ai.tres beside them since C27b; since C28 ping_sonar.tres too, and the arsenal dee2482's with ping added and nothing else; since I1 ice.tres, ICE's own; since I2 breakers.tres, the ICEbreakers' own; since I3 black_ice.tres, Black ICE's own; since C29 chmod_000.tres, the freeze ray's own, and the arsenal with it added; since C30 pipe_chain.tres, the chain beam's own, and the arsenal with it added; since C31 dev_null.tres, the black hole's own, and the arsenal with it added; since C32 sighup.tres, the confusion grenade's own, and the arsenal with it added; since C33 each weapon's kit beside it, its skin and mod slots naming the kit's ids, read back empty here; since C38 opener.tres, the opener's own timeline, no gameplay number) and scripts/net/'s numbers (its tunings; the session itself since C27b's daemons) byte for byte as at dee2482, the protocol %d (9 at A4, 10 since C27b, 11 since A5, 12 since I1, 13 since I2, 14 since I3, 15 since C29, 16 since C30, 17 since C31, 18 since C32, 19 since C33)" % PROTOCOL, resources == RESOURCES_SHA and net == NET_NUMBERS_SHA and protocol, "resources %s, net %s" % [resources.left(12), net.left(12)])


# --- The settings. ---

func _settings_checks() -> void:
	var s := GameSettings.new()
	var low := {}
	for key in GameSettings.PRESET_KEYS:
		low[key] = GameSettings.PRESETS["low"][key]
	_check("the default is high, everything on; the two post effects off (taste, in no preset)", s.value("video", "quality") == "high" and s.graphics()["ssao"] and s.graphics()["ssr"] and s.graphics()["skyline"] and s.graphics()["particles"] == "high" and not s.value("video", "chromatic_aberration") and not s.value("video", "crt"))
	var cheaper := true
	for key in ["bloom", "shadows", "code_rain", "ssao", "ssr", "skyline"]:
		cheaper = cheaper and GameSettings.PRESETS["low"][key] == false and GameSettings.PRESETS["high"][key] == true
	_check("acceptance: low drops every costly feature (bloom, shadows, the code rain, SSAO, SSR, the full skyline) and shows a quarter of the particles; medium, the 4050-class target, keeps the glow, the rain and the skyline without shadows, SSAO or SSR", cheaper and GameSettings.PRESETS["low"]["particles"] == "low" and GameSettings.PRESETS["medium"]["bloom"] and not GameSettings.PRESETS["medium"]["ssao"] and not GameSettings.PRESETS["medium"]["ssr"] and not GameSettings.PRESETS["medium"]["shadows"] and GameSettings.PRESETS["medium"]["particles"] == "medium")
	s.set_value("video", "quality", "low")
	var got := {}
	for key in GameSettings.PRESET_KEYS:
		got[key] = s.value("video", key)
	s.set_value("video", "ssao", true)
	var custom: String = s.value("video", "quality")
	s.set_value("video", "ssao", false)
	var back: String = s.value("video", "quality")
	s.set_value("video", "quality", "custom")
	var kept: String = s.value("video", "quality")
	_check("acceptance: picking a preset sets each of its toggles; a toggle changed by hand makes it \"custom\", and back again \"low\"; \"custom\" itself sets nothing", got == low and custom == GameSettings.CUSTOM and back == "low" and kept == "low", "%s %s %s" % [custom, back, kept])

	var path := _tmp.path_join("graphics.cfg")
	var a := GameSettings.new()
	a.path = path
	a.set_value("video", "quality", "medium")
	a.set_value("video", "ssr", true)
	a.set_value("video", "particles", "low")
	a.set_value("video", "chromatic_aberration", true)
	a.set_value("video", "crt", true)
	var saved := a.save()
	var b := GameSettings.new()
	b.path = path
	var loaded := b.load_file()
	_check("acceptance: every graphics setting round-trips through the settings file (a custom mix, the particle level and both post effects)", saved and loaded == "loaded" and b.graphics() == a.graphics() and b.value("video", "quality") == GameSettings.CUSTOM and b.value("video", "crt") == true, "%s vs %s" % [b.graphics(), a.graphics()])

	var old := _tmp.path_join("before-a4.cfg")
	var f := FileAccess.open(old, FileAccess.WRITE)
	f.store_string("[meta]\nversion=1\n\n[video]\nquality=\"low\"\nfov=90\n")
	f.close()
	var c := GameSettings.new()
	c.path = old
	var old_load := c.load_file()
	var low_now := {}
	for key in GameSettings.PRESET_KEYS:
		low_now[key] = c.value("video", key)
	var edited := _tmp.path_join("hand-edited.cfg")
	f = FileAccess.open(edited, FileAccess.WRITE)
	f.store_string("[meta]\nversion=1\n\n[video]\nquality=\"high\"\nssao=false\n")
	f.close()
	var d := GameSettings.new()
	d.path = edited
	d.load_file()
	_check("a settings file from before A4 (the preset alone) gives each toggle its preset's value; one whose toggles match no preset reads \"custom\"", old_load == "loaded" and low_now == low and c.value("video", "quality") == "low" and c.value("video", "fov") == 90 and d.value("video", "quality") == GameSettings.CUSTOM and d.value("video", "ssao") == false and d.value("video", "ssr") == true)
	var size := FileAccess.get_file_as_bytes(path).size()
	_check("the whole settings file with every A4 key stays well under the file's size limit", size > 0 and size < SettingsFile.MAX_BYTES / 2, "%d bytes of %d" % [size, SettingsFile.MAX_BYTES])


# --- The look. ---

func _look_checks(main: Node) -> void:
	var env := _env(main)
	var floor_mat := Palette.surface(Palette.Surface.FLOOR)
	_check("acceptance: the tonemapper is AgX (bright neon rolls off to white without ACES's hue skew), its contrast raised; the glow takes only what is over the threshold (no blown-out mush) with a tight core over a softer halo; the grade is on (contrast, saturation and a cool-shadow, warm-highlight curve)", env.tonemap_mode == Environment.TONE_MAPPER_AGX and env.tonemap_agx_contrast > 1.0 and env.glow_hdr_threshold >= 0.8 and env.glow_blend_mode == Environment.GLOW_BLEND_MODE_SCREEN and env.get_glow_level(1) > env.get_glow_level(4) and env.get_glow_level(4) > 0.0 and env.adjustment_enabled and env.adjustment_color_correction is GradientTexture1D and env.adjustment_contrast > 1.0)
	var curve := (env.adjustment_color_correction as GradientTexture1D).gradient
	var dark := curve.sample(0.0)
	var light := curve.sample(1.0)
	_check("the grade cools the shadows and warms the highlights, by a touch", dark.b > dark.r and light.r > light.b and dark.b < 0.05 and light.b > 0.9, "%s %s" % [dark, light])
	_check("the floor's deck plates are gloss for SSR to show the neon in", floor_mat.get_shader_parameter("gloss") < 0.5 and floor_mat.get_shader_parameter("specular_amount") > 0.0)
	var art: ArenaArt = main.get_node("Arena/ArenaArt")
	var warm := 0
	for lamp in art.lamp_lights():
		if lamp.light_color == Palette.SODIUM and not lamp.shadow_enabled:
			warm += 1
	var danger := 0
	for red in art.danger_lights():
		if red.light_color == Palette.HOSTILE_RED and not red.shadow_enabled and art.lair.grow(0.5).has_point(red.position):
			danger += 1
	var warm_signs := false
	var glow_mesh := art.glow_node().mesh
	for i in glow_mesh.get_surface_count():
		warm_signs = warm_signs or glow_mesh.surface_get_material(i) == Palette.arena_light_material("warm")
	var split_hue := Palette.GLITCH_SPLIT.h
	_check("acceptance: colour contrast: the big signs in warm sodium, each with a warm lamp before it, two red danger lights pulsing in the lair, and a daemon's glitch split in hostile magenta", warm_signs and warm >= 5 and warm == art.lamp_lights().size() and danger == 2 and split_hue > 0.8 and split_hue < 0.95, "%d lamps, %d danger, split hue %.2f" % [warm, danger, split_hue])
	var e0 := art.danger_lights()[0].light_energy
	for _i in 40:
		await process_frame
	_check("the danger lights pulse (on the arena's clock)", not is_equal_approx(art.danger_lights()[0].light_energy, e0))


# --- The presets in the arena. ---

func _preset_checks(main: Node) -> void:
	var s := GameSettings.current()
	var env := _env(main)
	var sun: DirectionalLight3D = main.get_node("Sun")
	var rain: Node = main.get_node("Arena/CodeRain")
	var skyline: ArenaSkyline = main.get_node("Arena/Skyline")
	var states := {}
	for preset in ["low", "medium", "high"]:
		s.set_value("video", "quality", preset)
		await process_frame
		states[preset] = [env.glow_enabled, sun.shadow_enabled, rain.is_enabled(), env.ssao_enabled, env.ssr_enabled, skyline.is_full(), ParticleFx.share(), ParticleFx.trails_on()]
	print("GRAPHICS presets [glow, shadows, rain, ssao, ssr, skyline, particle share, trails]: %s" % [states])
	_check("acceptance: each preset reaches the arena: low none of glow, shadows, rain, SSAO, SSR or the full skyline, a quarter of the particles and no trails; medium glow, rain, the skyline and half the particles; high everything", states["low"] == [false, false, false, false, false, false, 0.25, false] and states["medium"] == [true, false, true, false, false, true, 0.5, true] and states["high"] == [true, true, true, true, true, true, 1.0, true], str(states))
	s.set_value("video", "ssr", false)
	await process_frame
	var one_off: bool = not env.ssr_enabled and env.ssao_enabled and s.value("video", "quality") == GameSettings.CUSTOM
	s.set_value("video", "quality", "high")
	await process_frame
	_check("a single toggle reaches the arena alone and makes the preset custom; the preset puts it back", one_off and env.ssr_enabled)


# --- The post effects. ---

func _post_checks(main: Node) -> void:
	var s := GameSettings.current()
	var post: ScreenPost = main.get_node("ScreenPost")
	var hud: CanvasLayer = main.get_node("Hud")
	var off := not post.drawing()
	s.set_value("video", "chromatic_aberration", true)
	await process_frame
	var aberration: bool = post.drawing() and post.post_material().get_shader_parameter("aberration_px") > 0.0 and post.post_material().get_shader_parameter("scanline_dark") == 0.0
	s.set_value("video", "chromatic_aberration", false)
	s.set_value("video", "crt", true)
	await process_frame
	var crt: bool = post.drawing() and post.post_material().get_shader_parameter("scanline_dark") > 0.0 and post.post_material().get_shader_parameter("aberration_px") == 0.0
	s.set_value("video", "crt", false)
	await process_frame
	_check("acceptance: chromatic aberration and the CRT scanlines are settings, off by default and then drawn not at all; each on draws only itself; on a layer over the 3D view and under the HUD", off and aberration and crt and not post.drawing() and post.layer < hud.layer)


# --- The particles. ---

func _particle_checks(main: Node) -> void:
	var fx: ParticleFx = main.get_node("ParticleFx")
	var p: Node = main.get_node("Player")
	var shared := true
	var sizes := PackedStringArray()
	for kind in ParticleFx.POOLS:
		var spec: Array = ParticleFx.POOLS[kind]
		var pool := fx.pool(kind)
		sizes.append("%s %dx%d" % [ParticleFx.Kind.keys()[kind], pool.size(), spec[1]])
		for e in pool:
			shared = shared and e.process_material == pool[0].process_material and e.draw_pass_1 == pool[0].draw_pass_1 and e.amount == spec[1] and e.get_parent() == fx and e.cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		shared = shared and pool.size() == spec[0]
	print("GRAPHICS particle pools: %s; at most %d particles at once" % [", ".join(sizes), fx.cap()])
	_check("acceptance: the particles are GPU particles in fixed pools, each kind's emitters sharing one process material and one mesh, and the pools are the caps: at most %d particles at once in all" % fx.cap(), shared and fx.cap() <= PARTICLE_BUDGET and fx.get_child_count() == _pool_total())

	var models: Array = p.get("_viewmodels")
	var bursts := PackedStringArray()
	var by_family := {}
	for model in models:
		var burst := (model as Viewmodel).muzzle.get_node_or_null(ParticleFx.MUZZLE_NAME) as GPUParticles3D
		if burst == null or burst.amount > MUZZLE_BUDGET or not burst.local_coords or not burst.one_shot:
			bursts.append(model.name)
			continue
		var family: int = burst.get_meta(&"family")
		if by_family.has(family) and by_family[family] != burst.process_material:
			bursts.append("%s does not share its family's" % model.name)
		by_family[family] = burst.process_material
	_check("acceptance: muzzle flash per weapon family: every model carries its family's GPU burst under its Muzzle (in its own space, at most %d particles), the same family sharing one process material; %d families among the 13 (8 at A4, ping's since C28 the rail's ring, chmod 000's since C29 a frost family of its own, pipe |'s since C30 a brass crackle of its own, /dev/null's since C31 and SIGHUP's since C32 the launchers' with the fork bomb)" % [MUZZLE_BUDGET, by_family.size()], bursts.is_empty() and models.size() == 13 and by_family.size() >= 5, ", ".join(bursts))

	# A muzzle burst fires with a shot's flash.
	p.respawn_at(main.to_global(Vector3(0.0, 0.95, 10.0)))
	p.select_slot(0)
	for _i in 30:
		await physics_frame
	var muzzle: Marker3D = models[0].muzzle
	var burst0 := muzzle.get_node(ParticleFx.MUZZLE_NAME) as GPUParticles3D
	var w: Resource = p.weapon_tuning()
	var root_red := ParticleFx.fire_muzzle(muzzle, Palette.HOSTILE_RED)
	var red_mat := burst0.material_override
	CannonFx.spawn_muzzle_flash(muzzle, w)
	_check("a shot's flash fires its model's burst, in its own colour, or root's red when tinted", root_red and red_mat != burst0.get_meta(&"base") and burst0.material_override == burst0.get_meta(&"base") and burst0.emitting)

	# A burst of impacts reuses the pool: nothing more is made, the colour's draw material is shared.
	var spark_pool := fx.pool(ParticleFx.Kind.SPARK)
	var before_children := fx.get_child_count()
	var fired_before := fx.fired(ParticleFx.Kind.SPARK)
	# Every colour's draw material is made with the pools: even the first impact, derezz and blast
	# of the run make nothing.
	var warm_objects := Performance.get_monitor(Performance.OBJECT_COUNT)
	for i in 40:
		fx.impact(Vector3(i * 0.1, 1.0, 0.0), Vector3.UP, i % 2 == 0, Palette.MINT)
		fx.blast(Vector3(0.0, 1.0, i * 0.1), Palette.EMBER, 3.0)
	var after_objects := Performance.get_monitor(Performance.OBJECT_COUNT)
	var mats := {}
	for e in spark_pool:
		mats[e.material_override] = true
	_check("acceptance: capped, no per-shot allocation: 40 impacts and 40 blasts in one frame, the first of the run among them, reuse the same %d spark emitters round the pool (the oldest cut short), make no object at all, and every mint spark draws with one shared material" % spark_pool.size(), fx.get_child_count() == before_children and fx.fired(ParticleFx.Kind.SPARK) == fired_before + 40 and after_objects == warm_objects and spark_pool.size() == ParticleFx.POOLS[ParticleFx.Kind.SPARK][0] and mats.size() <= 2, "%d objects before, %d after" % [warm_objects, after_objects])

	# Trails: as many as the pool holds, the rest none; each moves with its target, made of nothing.
	var targets: Array[Node3D] = []
	for i in 20:
		var t := Node3D.new()
		main.add_child(t)
		t.global_position = Vector3(i, 2.0, -3.0)
		targets.append(t)
	var took := 0
	for t in targets:
		took += 1 if fx.follow(t, Palette.COBALT) else 0
	var heavy := 0
	for t in targets.slice(0, 5):
		heavy += 1 if fx.follow(t, Palette.EMBER, true) else 0
	# The shot's C6 flash above frees itself in a blink: let it go before counting.
	for _i in 60:
		await process_frame
	var frame_objects := Performance.get_monitor(Performance.OBJECT_COUNT)
	var frame_nodes := Performance.get_monitor(Performance.OBJECT_NODE_COUNT)
	var grew := 0
	for f in 120:
		for t in targets:
			t.global_position += Vector3(0.0, 0.0, -0.2)
		await process_frame
		if Performance.get_monitor(Performance.OBJECT_COUNT) > frame_objects or Performance.get_monitor(Performance.OBJECT_NODE_COUNT) > frame_nodes:
			grew += 1
	var follower := fx.pool(ParticleFx.Kind.TRAIL)[0]
	var tracked := follower.global_position.distance_to(targets[0].global_position) < 0.001
	_check("acceptance: trails capped and made of nothing: 20 projectiles get the %d light followers there are, 5 heavy ones the 2 there are; 120 frames of them following make no object and no node" % ParticleFx.POOLS[ParticleFx.Kind.TRAIL][0], took == ParticleFx.POOLS[ParticleFx.Kind.TRAIL][0] and heavy == ParticleFx.POOLS[ParticleFx.Kind.HEAVY_TRAIL][0] and fx.following() == took + heavy and tracked and grew == 0, "%d light, %d heavy, %d frames grew" % [took, heavy, grew])
	for t in targets:
		t.queue_free()
	await process_frame
	await process_frame
	_check("a trail stops when its projectile is gone, and frees its follower once its sparks have burnt out", fx.following() == 0 and not follower.emitting)

	# A beam drawn alone (a remote player's shot) sparks where it ends; this player's own beam does
	# not spark twice; one into the open does not spark at all.
	var sparks_before := fx.fired(ParticleFx.Kind.SPARK)
	fx.beam_end(Vector3(0.0, 1.6, 10.0), Vector3(0.0, 1.2, -6.0), Palette.MINT, 120.0)
	var remote := fx.fired(ParticleFx.Kind.SPARK) - sparks_before
	fx.impact(Vector3(1.0, 1.2, -6.0), Vector3.BACK, false, Palette.MINT)
	fx.beam_end(Vector3(0.0, 1.6, 10.0), Vector3(1.0, 1.2, -6.0), Palette.MINT, 120.0)
	fx.beam_end(Vector3(0.0, 1.6, 10.0), Vector3(0.0, 1.6, -110.0), Palette.MINT, 120.0)
	_check("a remote player's hitscan shot, drawn as a beam alone, sparks where its beam ends; a beam with its own impact or into the open does not", remote == 1 and fx.fired(ParticleFx.Kind.SPARK) - sparks_before == 2)

	# Low: every emitter and every muzzle burst holds a quarter of high's particles, the trails flying
	# stop, and no new one starts.
	# The followers freed above are free again once their last sparks are out.
	for _i in 40:
		await process_frame
	var flying := Node3D.new()
	main.add_child(flying)
	var high_trail := fx.follow(flying, Palette.COBALT)
	GameSettings.current().set_value("video", "quality", "low")
	await process_frame
	var spare := Node3D.new()
	main.add_child(spare)
	var low_trail := fx.follow(spare, Palette.COBALT)
	var quarter := true
	for kind in ParticleFx.POOLS:
		for e in fx.pool(kind):
			quarter = quarter and e.amount == maxi(1, roundi(ParticleFx.POOLS[kind][1] * 0.25))
	for model in models:
		var b := (model as Viewmodel).muzzle.get_node(ParticleFx.MUZZLE_NAME) as GPUParticles3D
		quarter = quarter and b.amount == roundi(ParticleFx.MUZZLE_PARTICLES * 0.25)
	_check("acceptance: low really is cheaper: every emitter and every muzzle burst holds a quarter of high's particles (simulated and drawn, not just hidden), the trail flying when it was picked stops, and no trail starts", quarter and high_trail and not low_trail and fx.following() == 0, "spark emitter %d particles, all a quarter %s, trail on high %s, on low %s, %d flying" % [spark_pool[0].amount, quarter, high_trail, low_trail, fx.following()])
	spare.queue_free()
	flying.queue_free()
	GameSettings.current().set_value("video", "quality", "high")
	await process_frame
	_check("high again: every emitter back to its full amount", spark_pool[0].amount == ParticleFx.POOLS[ParticleFx.Kind.SPARK][1] and burst0.amount == ParticleFx.MUZZLE_PARTICLES)


# --- The viewmodels' fixed projection. ---

func _viewmodel_checks(main: Node) -> void:
	var s := GameSettings.current()
	var p: Node = main.get_node("Player")
	var cam: Camera3D = p.get_node("Head/Camera")
	p.select_slot(0)
	for _i in 40:
		await physics_frame
	var model: Viewmodel = p.get("_viewmodels")[0]
	var rects := {}
	var reach := 0.0
	var nearest := INF
	var on_screen := 0.0
	for fov in [60, 80, 120]:
		s.set_value("video", "fov", fov)
		for _i in 3:
			await physics_frame
		var rect := Rect2()
		var first := true
		for node in [model] + model.find_children("*", "MeshInstance3D", true, false):
			var mi := node as MeshInstance3D
			var box := mi.get_aabb()
			for k in 8:
				var corner := mi.global_transform * box.get_endpoint(k)
				var px := cam.unproject_position(corner)
				rect = Rect2(px, Vector2.ZERO) if first else rect.expand(px)
				first = false
				var local := cam.to_local(corner)
				reach = maxf(reach, local.length())
				nearest = minf(nearest, -local.z)
		rects[fov] = rect
		on_screen = maxf(on_screen, cam.unproject_position(p.muzzle_point()).distance_to(cam.unproject_position(model.muzzle.global_position)))
	# Every model at the widest view, where the stretch across it is greatest.
	s.set_value("video", "fov", 120)
	var models: Array = p.get("_viewmodels")
	for slot in models.size():
		p.select_slot(slot)
		for _i in 50:
			await physics_frame
		var vm: Viewmodel = models[slot]
		for node in [vm] + vm.find_children("*", "MeshInstance3D", true, false):
			var mi := node as MeshInstance3D
			var box := mi.get_aabb()
			for k in 8:
				var local := cam.to_local(mi.global_transform * box.get_endpoint(k))
				reach = maxf(reach, local.length())
				nearest = minf(nearest, -local.z)
	p.select_slot(0)
	s.set_value("video", "fov", 0)
	var same := true
	for fov in rects:
		same = same and (rects[fov] as Rect2).size.distance_to((rects[80] as Rect2).size) < SCREEN_EPS_PX and (rects[fov] as Rect2).position.distance_to((rects[80] as Rect2).position) < SCREEN_EPS_PX
	print("GRAPHICS viewmodel on screen at 60/80/120 degrees: %s; reaches %.3f m from the eye, nearest %.3f m" % [[rects[60], rects[80], rects[120]], reach, nearest])
	_check("acceptance: a fixed viewmodel projection: the drawn model covers the same rectangle of the screen at a 60, 80 and 120 degree field of view (within %.1f px)" % SCREEN_EPS_PX, same and (rects[80] as Rect2).size.x > 100.0, str(rects))
	_check("acceptance: no barrel pokes into a wall: every model part stays within %.2f m of the eye, inside the player's own %.1f m radius, and in front of the camera's near plane" % [reach, PLAYER_RADIUS_M], reach < PLAYER_RADIUS_M and nearest > cam.near and cam.near <= Player.VIEWMODEL_NEAR_M, "reach %.3f, nearest %.3f, near %.3f" % [reach, nearest, cam.near])
	_check("the muzzle point (where beams start and projectiles are drawn from) is the Muzzle marker on screen at every field of view", on_screen < 0.5, "%.3f px" % on_screen)
	# A shot's jolt moves the camera's lens: the rig follows it, so the models jolt as full-sized ones
	# would and the muzzle point stays on the marker.
	var shot_eye := cam.get_camera_transform().origin
	var tip_before: Vector3 = model.muzzle.global_position
	cam.h_offset = 0.03
	cam.v_offset = -0.02
	p.call("_fit_viewmodels")
	var jolted := cam.unproject_position(p.muzzle_point()).distance_to(cam.unproject_position(model.muzzle.global_position))
	# As full-sized: the marker's shift on screen is what the same point at full size would get.
	var full := shot_eye + (tip_before - shot_eye) / Player.VIEWMODEL_SHRINK
	var as_full := cam.unproject_position(model.muzzle.global_position).distance_to(cam.unproject_position(full))
	cam.h_offset = 0.0
	cam.v_offset = 0.0
	p.call("_fit_viewmodels")
	_check("acceptance: through a shot's jolt the shrunk model moves on screen as a full-sized one would, and the muzzle point stays on its marker (Codex review)", jolted < 0.5 and as_full < 0.5, "%.3f px, %.3f px" % [jolted, as_full])


# --- Projectiles drawn from the muzzle. ---

func _projectile_checks(main: Node) -> void:
	var p: Node = main.get_node("Player")
	var defs: Array = p.get("inventory").defs
	var rm: Resource = null
	for def in defs:
		if def.id == "rm_rf_cannon":
			rm = def
	var origin := Vector3(0.0, 1.6, 10.0)
	var aim := Vector3.FORWARD
	var muzzle_at := Vector3.ZERO
	var drawn = RmSlug.spawn(main, rm, origin, aim, false, false, 1)
	var plain = RmSlug.spawn(main, rm, origin, aim, false, false, 1)
	# As every volley of this player's reaches it, alone or from the host's word in a match.
	p.take_volley(drawn)
	muzzle_at = p.muzzle_point()
	var head: MeshInstance3D = drawn.get("_head")
	var start_ok: bool = head.visible and head.global_position.distance_to(muzzle_at) < 0.001
	var frames := 0
	while drawn.get("flown") < RmSlug.CONVERGE_M + 0.5 and frames < 120:
		await physics_frame
		frames += 1
	var joined: bool = head.global_position.distance_to(drawn.position_now()) < 0.001
	var same_path: bool = drawn.position_now().distance_to(plain.position_now()) < 0.0001
	_check("acceptance: projectiles drawn from the muzzle, alone or in a match (the player's take_volley draws it): a slug is seen leaving the barrel's tip and closes on its true path within %.0f m, while its path (the one that counts) is the very path of one not drawn so, still from the eyes" % RmSlug.CONVERGE_M, start_ok and joined and same_path, "start %s, joined %s, same path %s after %d frames" % [start_ok, joined, same_path, frames])
	for node in [drawn, plain]:
		if is_instance_valid(node):
			node.free()


# --- The arena's clock. ---

func _clock_checks(main: Node) -> void:
	# The player's own SIGSTOP, pressed as F does: the world slows to its scale.
	var stop: Node = main.get_node("Player").get("sigstop")
	stop.refill()
	stop.press()
	for _i in 10:
		await physics_frame
	var before := ArenaArt.clock()
	var expect := 0.0
	var slowest := 1.0
	for _i in 60:
		expect += Engine.time_scale / 60.0
		slowest = minf(slowest, Engine.time_scale)
		await process_frame
	var slowed := ArenaArt.clock() - before
	var held: bool = stop.slowing()
	stop.press()
	var frames := 0
	while Engine.time_scale != 1.0 and frames < 300:
		await physics_frame
		frames += 1
	before = ArenaArt.clock()
	for _i in 60:
		await process_frame
	var full := ArenaArt.clock() - before
	print("GRAPHICS arena clock: %.3f s in 60 frames of SIGSTOP (the engine's time at %.2f, %.3f s expected), %.3f s at full" % [slowed, slowest, expect, full])
	_check("acceptance: SIGSTOP slows the arena's strips: while it holds the world slowed, the arena's shader clock runs at the engine's slowed pace, and at full pace again after SIGCONT", held and slowest < 0.6 and absf(slowed - expect) < 0.04 and slowed < 0.7 and absf(full - 1.0) < 0.03, "%.3f vs %.3f" % [slowed, expect])


# --- Helpers. ---

func _pool_total() -> int:
	var n := 0
	for kind in ParticleFx.POOLS:
		n += ParticleFx.POOLS[kind][0]
	return n


func _env(main: Node) -> Environment:
	return (main.find_child("WorldEnvironment", true, false) as WorldEnvironment).environment


func _arena() -> Node:
	var link := Link.new()
	link.settings_path = _tmp.path_join("arena-privacy.cfg")
	link.demo = true
	Link.park(link)
	var main = MainScene.instantiate()
	root.add_child(main)
	_arenas.append(main)
	main.get_node("Hud").guide().focus_check = func(): return false
	main.get_node("Player").assume_captured = true
	for i in 3:
		await physics_frame
	return main


func _dir_sha(dir: String, ext: String, only: Array = []) -> String:
	var names := Array(DirAccess.get_files_at(dir)).filter(func(n): return n.ends_with(ext) and (only.is_empty() or only.has(n)))
	names.sort()
	var ctx := HashingContext.new()
	ctx.start(HashingContext.HASH_SHA256)
	for n in names:
		ctx.update((n + "\n").to_utf8_buffer())
		var bytes := FileAccess.get_file_as_bytes(dir + n)
		ctx.update(_without_c33_slots(bytes.get_string_from_utf8()).to_utf8_buffer() if ext == ".tres" else bytes)
	return ctx.finish().hex_encode()


## A weapon's .tres with its C16 slots read back empty, as they were before C33 named its kit's skins and mod
## in them: the slots name data, never a gameplay number.
static func _without_c33_slots(text: String) -> String:
	var slots := RegEx.create_from_string("(mod_slots|skin_slots) = Array\\[String\\]\\(\\[[^\\]]*\\]\\)")
	return slots.sub(text, "$1 = Array[String]([])", true)


func _shader_code(path: String) -> String:
	var out := PackedStringArray()
	for line in FileAccess.get_file_as_string(path).split("\n"):
		var cut := line.find("//")
		out.append(line.substr(0, cut) if cut >= 0 else line)
	return "\n".join(out)


## A script's code with its comments and string literals cut out.
func _code(path: String) -> String:
	var out := PackedStringArray()
	for line in FileAccess.get_file_as_string(path).split("\n"):
		var quote := ""
		var cut := line.length()
		var i := 0
		while i < line.length():
			var ch := line[i]
			if quote != "":
				if ch == "\\":
					i += 1
				elif ch == quote:
					quote = ""
			elif ch == "\"" or ch == "'":
				quote = ch
			elif ch == "#":
				cut = i
				break
			i += 1
		out.append(line.substr(0, cut))
	return "\n".join(out)


func _body(source: String, name: String) -> String:
	var at := source.find("\nfunc %s(" % name)
	if at < 0:
		at = source.find("\nstatic func %s(" % name)
	if at < 0:
		return ""
	var end := source.find("\nfunc ", at + 1)
	var end_static := source.find("\nstatic func ", at + 1)
	if end_static > 0 and (end < 0 or end_static < end):
		end = end_static
	return source.substr(at, (end if end > 0 else source.length()) - at)


func _cleanup() -> void:
	Engine.time_scale = 1.0
	GameSettings.current().reset()
	GameSettings.current().set_value("gameplay", "practice", true)  # these checks predate C27b: the daemons stay the old never-attack dummies
	for node in _arenas.duplicate():
		if is_instance_valid(node):
			for sfx in node.find_children("*", "AudioStreamPlayer", true, false):
				(sfx as AudioStreamPlayer).stop()
			node.free()
	var left = Link.take_parked()
	if left != null:
		left.shut_down(null)
	Controls.apply_binds({})
	await process_frame
	OS.delay_msec(300)
	await process_frame
