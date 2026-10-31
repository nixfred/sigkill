extends SceneTree
## Headless test of the opener's end and the first launch (C42: PRD 5.7, 1:35 to 2:00; STORY.md section 5). scripts/
## check.sh runs it as step 53, and any FAIL exits 1.
##
##   godot --headless --path . --fixed-fps 60 --script res://tests/opener_end_test.gd
##
## The forge, the first kill and the title: `kill -9` typed a letter an eighth, the rifle printing and forged on the drop,
## the copy's "you won't.", fire pressed and the shot on the next sixteenth (never before fire_from, once, or on its own
## at fire_by), the beam, the derezz, the kill feed "SIGKILL sent by <user>" / "to <user>" (the user name only, never the
## host), the whisper "one of 6666", the black, SIGKILL on the brand's own icon file slammed in on the score's beat, the
## end by 2:00, the brightness model's flashes capped. The score: its four parts made in code, their lengths and loop,
## not harsh (peaks and loudness), the same every run, on the Music bus at its volume, each part starting on its moment,
## the drop and the slam on its grid; the Music and Effects volumes ruling it and the daemons. The daemons' and ICE's
## voices: each type's four sounds, a daemon saying its tell, strike, hit and death on the Effects bus. Skipping: the
## intro's Esc menu and holding Space from every beat, C38's to C42's. The first launch: the card with No highlighted,
## no saved unless yes, the opener playing itself once and never again, an interrupted first play coming back, "Skip the
## intro next time" sticking across a restart, a C33 save and the settings still loading. The AI's answer kept for a
## session's replays. Stubs only: invented data, a guide link on a fake detector and stub adapters; every file in the
## test's own folder under user://, removed at the end; nothing of the player's machine read or written.

const OpenerScene = preload("res://scenes/opener.tscn")
const MainScene = preload("res://scenes/main.tscn")
const Link = preload("res://scripts/guide/guide_link.gd")
const Settings = preload("res://scripts/boot/guide_settings.gd")
const Found = preload("res://scripts/ai/ai_source_result.gd")
const Detector = preload("res://scripts/ai/ai_source_detector.gd")
const SettingsFile = preload("res://scripts/settings/settings_file.gd")
const SettingsApply = preload("res://scripts/settings/settings_apply.gd")
const SfxSynth = preload("res://scripts/sfx_synth.gd")
const Controls = preload("res://scripts/controls.gd")
const FPS := 60.0
const MOST_FRAMES := 7600
const LONG_ROUND_S := 100000.0
const USER := "qz-end-5"
const HOST := "qz-host-9"
const NEW_OPENER := ["res://scripts/opener/forge_beat.gd", "res://scripts/opener/title_beat.gd", "res://scripts/opener/opener_score.gd", "res://scripts/opener/intro_menu.gd", "res://shaders/opener_forge.gdshader", "res://shaders/opener_print.gdshader", "res://shaders/opener_post.gdshader"]
const NEVER := ["OS.execute", "create_process", "OS.kill", "shell_open", "get_environment", "get_unix_time", "_from_system", "get_ticks", "HTTPRequest", "HTTPClient", "StreamPeer", "PacketPeer", "WebSocket", "FileAccess", "DirAccess", "ResourceSaver", "save_png", "store_", "print(", "printerr(", "push_error(", ".wav", ".ogg", ".mp3", "AudioStreamOggVorbis", "AudioStreamMP3"]
## Beats to skip from: [the opener's second, its phase].
const BEATS := [[1.5, "frozen"], [16.0, "terminal"], [35.6, "hold"], [37.5, "ignore"], [45.0, "reveal"], [58.0, "fall"], [69.0, "landed"], [72.0, "link"], [88.0, "copy"], [97.0, "forge"], [105.0, "fire"], [109.0, "kill"], [113.0, "title"]]


class StubData extends OpenerData:
	func kind() -> String:
		return "stub"

	func user() -> String:
		return USER

	func host() -> String:
		return HOST


## Stands in for the C9 detector: a canned result.
class FakeDetector:
	extends RefCounted
	var result: Found

	func start() -> Error:
		return OK

	func is_done() -> bool:
		return true

	func wait() -> Found:
		return result

	func cancel() -> void:
		pass

	func find_command(_command: String) -> String:
		return ""

	func poll_gpu() -> Dictionary:
		return {"available": false}


## A guide adapter of the test's own on the real base class: answers after a few steps, counting what it was asked.
class StubAdapter:
	extends "res://scripts/ai/guide_adapter.gd"
	var asks := 0
	var steps := 0

	func _init(tuning_resource: Resource) -> void:
		super(tuning_resource)

	func adapter_name() -> String:
		return "claude"

	func is_available() -> bool:
		return true

	func ask(request: RefCounted) -> Dictionary:
		asks += 1
		return super(request)

	func _begin(_request: RefCounted) -> String:
		steps = 0
		return ""

	func _step() -> Dictionary:
		steps += 1
		if steps < 3:
			return {}
		return result(true, "Link up. It's dark down here.", "")

	func _abort() -> void:
		pass


## A brain of the test's own: only its state, as the voice reads it.
class FakeBrain extends RefCounted:
	var state := 0


## A session that says it is in a match.
class OnlineSession extends Node:
	func is_online() -> bool:
		return true


var _fails := 0
var _checks := 0
var _root := ""
var _abs := ""
var _finished: Array = []
var _arenas: Array = []


func _initialize() -> void:
	_run()


func _run() -> void:
	await process_frame
	root.size = Vector2i(1280, 720)
	_root = "user://opener-end-test-%d" % OS.get_process_id()
	_abs = ProjectSettings.globalize_path(_root)
	if DirAccess.dir_exists_absolute(_abs):
		print("FAIL the test's own folder already exists; not touching it")
		quit(1)
		return
	DirAccess.make_dir_recursive_absolute(_abs)
	Controls.ensure()
	GameSettings.current().reset()
	SettingsApply.apply_audio(GameSettings.current())
	_code_checks()
	_score_checks()
	await _voice_checks()
	await _forge_checks()
	await _auto_checks()
	await _skip_checks()
	await _first_launch_checks()
	await _reuse_checks()
	await _cleanup()
	print("OPENER END: %d checks" % _checks)
	print("OPENER END RESULT: ", "ALL PASS" if _fails == 0 else "%d FAILED" % _fails)
	quit(0 if _fails == 0 else 1)


func _check(label: String, ok: bool, detail: String = "") -> void:
	_checks += 1
	print("PASS " if ok else "FAIL ", label, ("   " + detail) if detail != "" else "")
	if not ok:
		_fails += 1


# --- The code. ---

func _code_checks() -> void:
	var listed := _code("res://tests/opener_test.gd")
	var missing := PackedStringArray()
	var found := PackedStringArray()
	for path in NEW_OPENER:
		if not listed.contains("\"%s\"" % path):
			missing.append(path.get_file())
		var code := _code(path)
		for word in NEVER:
			if code.contains(word):
				found.append("%s: %s" % [path.get_file(), word])
	_check("acceptance: the C38 to C41 static checks hold for every new opener file: each is in step 48's list (no environment, clock, program, network or file there) and none reads, writes, logs or prints anything, or loads a recording", missing.is_empty() and found.is_empty(), ", ".join(missing + found))
	var score := _code("res://scripts/opener/opener_score.gd")
	_check("acceptance: the score is made in code, from nothing: no load or preload in it at all, no audio file, nothing of anyone's", not score.contains("load(") and not score.contains("AudioStreamOggVorbis") and not score.contains("AudioStreamMP3") and score.contains("WorkerThreadPool.add_task"))
	var state := _code("res://scripts/settings/intro_state.gd")
	var card := _code("res://scripts/hud/first_launch_card.gd")
	_check("the first launch writes only its own [intro] section and the privacy answer, through the settings file's own writer (no file or folder opened, nothing run, nothing read of the machine)", state.contains("SettingsFile.write_sections(path, {SECTION: state})") and not state.contains("FileAccess") and not state.contains("DirAccess") and not card.contains("FileAccess") and not card.contains("OS.") and not card.contains("SettingsFile.") and not card.contains("IntroState.") and not card.contains("Privacy.") and not card.contains("Settings.save"))
	var main := _code("res://scripts/main.gd")
	_check("acceptance: only a real run uses the player's settings file for it: never headless, never a --script run (the tests and the capture tools)", main.contains("if DisplayServer.get_name() != \"headless\" and not OS.get_cmdline_args().has(\"--script\"):") and main.contains("first_launch_path = SettingsFile.DEFAULT_PATH"))
	var opener := _code("res://scripts/opener/opener.gd")
	_check("acceptance: the hold-to-skip is one key, Space, with no Ctrl or Alt; Esc pauses in the intro's own menu; the window's close is never touched", opener.contains("key.keycode == KEY_SPACE") and not opener.contains("ctrl_pressed") and not opener.contains("alt_pressed") and not opener.contains("WM_CLOSE") and IntroMenu.HOLD_S >= 0.5 and IntroMenu.HOLD_S <= 1.5)
	_check("the words, exactly (STORY.md section 5): `kill -9`, \"you won't.\", the kill feed \"SIGKILL sent by <user>\" / \"to <user>\", \"one of 6666\", SIGKILL", ForgeBeat.WORD == "kill -9" and ForgeBeat.DARE == "you won't." and TitleBeat.FEED_FIRST % ["SIGKILL", "u"] == "SIGKILL sent by u" and TitleBeat.FEED_SECOND % "u" == "to u" and TitleBeat.WHISPER == "one of 6666" and TitleBeat.TITLE == "SIGKILL")
	var logo := "res://packaging/linux/sigkill.svg"
	_check("acceptance: the title is the brand's own icon file, as it is (the hexagon with the white >_, byte for byte the brand's, never redrawn): %s" % logo.get_file(), TitleBeat.LOGO.resource_path == logo and FileAccess.get_sha256(logo) == FileAccess.get_sha256("res://docs/media/nixfred-icon.svg") and not _code("res://scripts/opener/title_beat.gd").contains("draw_polygon"))


# --- The score. ---

func _score_checks() -> void:
	OpenerScore.forget()
	OpenerScore.make_all()
	var lengths := {}
	var shapes := true
	var worst_peak := 0.0
	var loud := {}
	for part in OpenerScore.PARTS:
		var s := OpenerScore.stream(part)
		if s == null:
			shapes = false
			continue
		lengths[part] = snappedf(s.get_length(), 0.01)
		shapes = shapes and s.stereo and s.format == AudioStreamWAV.FORMAT_16_BITS and s.mix_rate == OpenerScore.RATE
		var stats := _levels(s)
		worst_peak = maxf(worst_peak, stats[0])
		loud[part] = snappedf(linear_to_db(stats[1]), 0.1)
	_check("acceptance: the score's four parts made: the bed %.2f s (from 0:40 to the forge, 34 bars), the forge %.2f s, the wait %.2f s (a loop), the stinger %.2f s; stereo, 16-bit" % [lengths.get("bed", 0.0), lengths.get("forge", 0.0), lengths.get("wait", 0.0), lengths.get("stinger", 0.0)], shapes and absf(lengths.get("bed", 0.0) - 54.4) < 0.02 and absf(lengths.get("forge", 0.0) - 9.6) < 0.02 and absf(lengths.get("wait", 0.0) - 3.2) < 0.02 and absf(lengths.get("stinger", 0.0) - 11.2) < 0.02 and OpenerScore.stream("wait").loop_mode == AudioStreamWAV.LOOP_FORWARD)
	_check("acceptance: not painful at full volume: every peak under full scale (worst %.3f), the loudest part at most -14 dBFS (bed %s, forge %s, wait %s, stinger %s dBFS), none silent" % [worst_peak, loud.get("bed"), loud.get("forge"), loud.get("wait"), loud.get("stinger")], worst_peak < 0.99 and loud.values().all(func(db): return db <= -14.0 and db >= -32.0))
	var first := OpenerScore.stream("forge").data
	OpenerScore.forget()
	OpenerScore.make_all()
	_check("the same score every run: made again, the forge's samples are the same, byte for byte", OpenerScore.stream("forge").data == first)
	var t := load("res://resources/opener.tres") as OpenerTuning
	_check("acceptance: on the score's grid: the bed ends on the forge (%.2f s), the forge's drop %d sixteenths in, the fire from %.2f s (six bars), the slam %d beats after the shot" % [OpenerScore.BED_AT + OpenerScore.BED_BARS * OpenerScore.BAR_S, OpenerScore.FORGE_DROP, t.fire_from, OpenerScore.SLAM_BEATS], absf(OpenerScore.BED_AT + OpenerScore.BED_BARS * OpenerScore.BAR_S - t.forge_at) < 0.01 and OpenerScore.FORGE_DROP % 16 == 0 and absf(t.fire_from - t.forge_at - OpenerScore.FORGE_BARS * OpenerScore.BAR_S) < 0.01 and absf(OpenerScore.BAR_S - 4.0 * OpenerScore.BEAT_S) < 0.0001)


## [peak, loudness (RMS of what sounds)] of a 16-bit stream, linear.
static func _levels(s: AudioStreamWAV) -> Array:
	var d := s.data
	var peak := 0
	var sum := 0.0
	var n := 0
	for i in range(0, d.size() / 2, 3):
		var v := d.decode_s16(i * 2)
		peak = maxi(peak, absi(v))
		if absi(v) > 8:
			sum += float(v) * v
			n += 1
	return [peak / 32767.0, sqrt(sum / maxf(n, 1)) / 32767.0]


# --- The daemons' and ICE's voices. ---

func _voice_checks() -> void:
	var sounds := 0
	var heard := 0
	var distinct := {}
	for kind in SfxSynth.DAEMON_KINDS:
		for what in SfxSynth.DAEMON_WHATS:
			var s := DaemonVoice.sound(kind, what)
			sounds += 1
			var stats := _levels(s)
			if stats[0] > 0.3 and stats[0] < 0.99:
				heard += 1
			distinct[Marshalls.raw_to_base64(s.data).sha256_text()] = true
	_check("acceptance: every daemon type and ICE has its own voice: %d sounds (rogue.d, the zombie, the runaway's swarm, a wall, a node, the hunter; tell, strike, hit, death), %d sounding and under full scale, %d different" % [sounds, heard, distinct.size()], sounds == 24 and heard == 24 and distinct.size() >= 20 and not SfxSynth.DAEMON_KINDS.has("black"))
	var main := await _lab("voices.cfg", true)
	var dummy: Node3D = null
	for d in main.get_tree().get_nodes_in_group("targets"):
		if d.get("voice") != null:
			dummy = d
			break
	var voice: DaemonVoice = dummy.voice if dummy != null else null
	var ok_bus: bool = voice != null and voice.get_node("Call").bus == &"Effects" and voice.get_node("Hurt").bus == &"Effects" and voice.kind == dummy.art_node().ai_kind and voice.brain == dummy.brain
	var said: Array = []
	if voice != null:
		# Its tell and strike as its brain enters them (a brain of the test's own, so the director cannot move it on).
		var brain := FakeBrain.new()
		voice.brain = brain
		brain.state = DaemonBrain.State.TELL
		await physics_frame
		await physics_frame
		brain.state = DaemonBrain.State.STRIKE
		await physics_frame
		await physics_frame
		brain.state = DaemonBrain.State.HUNT
		await physics_frame
		voice.brain = null
		dummy.hit(0.01, dummy.global_position, Vector3.FORWARD, "terminal_cannon")
		dummy.hit(0.01, dummy.global_position, Vector3.FORWARD, "terminal_cannon")
		dummy.hit(1000.0, dummy.global_position, Vector3.FORWARD, "terminal_cannon")
		for line in voice.said:
			said.append(line[1])
	_check("acceptance: a daemon in the arena says its tell and its strike as its brain enters them, a hit landing (two at once heard once) and its death, from where it stands, on the Effects bus (%s: %s)" % [voice.kind if voice != null else "none", " ".join(said)], ok_bus and said == ["tell", "strike", "hit", "death"])
	var ice := _code("res://scripts/ice/ice_piece.gd")
	_check("ICE's pieces (walls, nodes, the hunter) have their voices too, a hit and a break; the hunter's lock-on and lance from its brain; Black ICE keeps its own", ice.contains("voice = DaemonVoice.new()") and ice.contains("SfxSynth.DAEMON_KINDS.has(art.ai_kind)") and _body(ice, "_hurt").contains("voice.hit()") and _body(ice, "_break").contains("voice.death()") and _code("res://scripts/ice/hunter_ice.gd").contains("voice.brain = brain"))
	var s := GameSettings.current()
	s.set_value("audio", "effects", 0.5)
	s.set_value("audio", "music", 0.25)
	SettingsApply.apply_audio(s)
	var fx := AudioServer.get_bus_index("Effects")
	var music := AudioServer.get_bus_index("Music")
	var halves := absf(AudioServer.get_bus_volume_db(fx) - linear_to_db(0.5)) < 0.01 and absf(AudioServer.get_bus_volume_db(music) - linear_to_db(0.25)) < 0.01
	s.set_value("audio", "effects", 0.0)
	s.set_value("audio", "music", 0.0)
	SettingsApply.apply_audio(s)
	var muted := AudioServer.is_bus_mute(fx) and AudioServer.is_bus_mute(music)
	s.set_value("audio", "effects", 1.0)
	s.set_value("audio", "music", 1.0)
	SettingsApply.apply_audio(s)
	_check("acceptance: the volume settings rule them: the Effects and Music sliders set their buses (half and a quarter here), and at 0 mute them", halves and muted and not AudioServer.is_bus_mute(fx))
	await _drop(main)


# --- The forge, the kill and the title, played through on invented data with fire pressed. ---

func _forge_checks() -> void:
	var o := _opener(StubData.new(), null)
	var t := o.timing()
	var forge_seen := {}
	var early_press := -1.0
	var early_done := false
	var press_at := t.fire_from + 0.23
	var pressed := false
	var second := false
	var shot := -1.0
	var looked := {}
	var post_bad := 0
	var flash_bad := 0
	var bus_ok := true
	var frames := 0
	while frames < MOST_FRAMES and is_instance_valid(o) and o.playing():
		await process_frame
		frames += 1
		if not is_instance_valid(o) or not o.playing():
			break
		var e := o.elapsed()
		var forge := o.forge()
		var title := o.title()
		if forge == null:
			continue
		if e >= 100.0 and not early_done:
			_fire()
			early_done = true
			early_press = o.pressed_at()
		if not pressed and e >= press_at:
			_fire()
			pressed = true
		if pressed and not second and e >= press_at + 0.05:
			_fire()
			second = true
		shot = o.shot_time()
		for moment in [["rifle_before", forge.print_from() - 0.05], ["rifle_during", (forge.print_from() + forge.print_to()) * 0.5], ["rifle_after", forge.drop_at() + 0.05]]:
			if not looked.has(moment[0]) and e >= moment[1]:
				looked[moment[0]] = [forge.rifle().visible, forge.forged(), forge.rifle().charge()]
		if not looked.has("dare") and e >= forge.dare_key_at(ForgeBeat.DARE.length() - 1) + 0.05:
			looked["dare"] = forge.dare_text()
			looked["typing"] = o.pit().typing
		if shot >= 0.0:
			for key in [["beam", 0.05], ["copy", forge.shatter_at() - shot + 0.05], ["feed", 1.5], ["whisper", 3.0], ["black", 4.5], ["title", 5.3], ["title_late", 8.9]]:
				if not looked.has(key[0]) and e >= shot + key[1]:
					var shown := {"beam": forge.beam_showing(), "copy_visible": o.pit().copy().visible, "burst": forge.burst_showing(), "shatters": _shatters(o), "feed": title.feed_text(), "whisper": title.whisper_text(), "black": title.black(), "title": title.title_text(), "world": o.get_node("MachineView").visible if o.has_node("MachineView") else false}
					looked[key[0]] = shown
			# The shot's flash and the slam's, drawn from the brightness model.
			var level := o.luma_at(e)
			var after := e - shot
			if after >= 0.0 and after < OpenerScore.BLACK_BEATS * OpenerScore.BEAT_S:
				var want := clampf((level - Opener.MACHINE_LUMA) / (1.0 - Opener.MACHINE_LUMA), 0.0, 1.0)
				if absf(float(o.post().get_shader_parameter("flash")) - want) > 0.0001:
					post_bad += 1
		for part in ["bed", "forge", "wait", "stinger"]:
			var player := o.score_player(part)
			if player != null and (player.bus != &"Music" or absf(player.volume_db - linear_to_db(t.score_volume)) > 0.01):
				bus_ok = false
	await process_frame
	var ev := {}
	for event in o.events():
		if not ev.has(event[1]):
			ev[event[1]] = event[0]
	var keys := []
	for event in o.events():
		if event[1] == "forge_type" or event[1] == "forge_key":
			keys.append(event[0])
	var on_grid := keys.size() == ForgeBeat.WORD.length()
	for k in keys.size():
		on_grid = on_grid and absf(keys[k] - (t.forge_at + (OpenerScore.FORGE_KEYS_FROM + 2 * k) * OpenerScore.STEP_S)) < 1.5 / FPS
	_check("acceptance: `kill -9` types itself a letter on each eighth of the score from 1:35 (%s s)" % ", ".join(keys.map(func(x): return "%.2f" % x)), on_grid and absf(ev.get("forge_type", -1.0) - (t.forge_at + 0.2)) < 1.5 / FPS)
	var before: Array = looked.get("rifle_before", [true, true, 0.0])
	var during: Array = looked.get("rifle_during", [])
	var after_drop: Array = looked.get("rifle_after", [])
	_check("acceptance: the letters charge and break, and `kill -9` forges into the rifle: printing from its back as the cells arrive (shown, not yet in its own materials), whole and its four coils lit on the drop (%.2f s), in its own colours", not before[0] and not during.is_empty() and during[0] and not during[1] and not after_drop.is_empty() and after_drop[0] and after_drop[1] and after_drop[2] >= 0.99 and ev.has("charge") and ev.has("break") and ev.has("coils") and ev.get("break", 0.0) < ev.get("print", 0.0) and absf(ev.get("drop", -1.0) - (t.forge_at + OpenerScore.FORGE_DROP * 0.1)) < 1.5 / FPS, str([before, during, after_drop]))
	_check("acceptance: the copy types \"you won't.\" (STORY.md's words), its face's cursor racing as it types, before the player may fire (\"%s\")" % String(looked.get("dare", "")).strip_edges(), String(looked.get("dare", "")).begins_with("you won't.") and looked.get("typing", false) and ev.get("dare_done", 999.0) < t.fire_from)
	_check("acceptance: the player fires: a press before the rifle is theirs does nothing (%s), the press at %.2f s fires on the next sixteenth (%.2f s), a second press changes nothing" % [str(early_press), press_at, shot], early_press < 0.0 and absf(o.pressed_at() - press_at) < 1.5 / FPS and absf(shot - (t.fire_from + 0.3)) < 0.0001 and ev.has("fire") and not ev.has("auto") and absf(ev.get("shot", -1.0) - shot) < 1.5 / FPS)
	var beam: Dictionary = looked.get("beam", {})
	var gone: Dictionary = looked.get("copy", {})
	_check("acceptance: the first kill: the beam into the copy's heart, then on the beat it bursts (its own parts flung apart, the voxels' storm) and is gone", beam.get("beam", false) and not gone.get("copy_visible", true) and gone.get("burst", false) and gone.get("shatters", 0) >= 1 and absf(ev.get("derezz", -1.0) - (shot + OpenerScore.DEREZZ_BEATS * OpenerScore.BEAT_S)) < 1.5 / FPS)
	var feed: Dictionary = looked.get("feed", {})
	var whisper: Dictionary = looked.get("whisper", {})
	_check("acceptance: the kill feed in SIGKILL's words, the user name twice and nothing else of the machine (\"%s\"), then the whisper (\"%s\")" % [feed.get("feed", ""), whisper.get("whisper", "")], feed.get("feed", "") == "SIGKILL sent by %s to %s" % [USER, USER] and not String(feed.get("feed", "")).contains(HOST) and whisper.get("whisper", "") == "one of 6666")
	var black: Dictionary = looked.get("black", {})
	var title: Dictionary = looked.get("title", {})
	var late: Dictionary = looked.get("title_late", {})
	_check("acceptance: black (the machine gone, the feed with it), then the title, SIGKILL, slammed in on the score's beat at %.2f s and held" % ev.get("slam", -1.0), black.get("black", false) and not black.get("world", true) and black.get("feed", "x") == "" and title.get("title", "") == "SIGKILL" and late.get("title", "") == "SIGKILL" and absf(ev.get("slam", -1.0) - (shot + OpenerScore.SLAM_BEATS * OpenerScore.BEAT_S)) < 1.5 / FPS)
	var order := ["forge", "forge_type", "charge", "break", "print", "coils", "drop", "dare", "dare_start", "dare_done", "fire_ready", "fire", "shot", "derezz", "feed", "whisper", "black", "slam", "title_out", "done"]
	var in_order := true
	var missing := PackedStringArray()
	for i in order.size():
		if not ev.has(order[i]):
			missing.append(order[i])
		elif i > 0 and ev.has(order[i - 1]) and ev[order[i]] < ev[order[i - 1]]:
			in_order = false
	_check("acceptance: every beat of 1:35 to 2:00 in order, the end by 2:00 (%.2f s, the title's end after the shot)" % ev.get("done", -1.0), missing.is_empty() and in_order and ev.get("forge", 999.0) <= 95.5 and absf(ev.get("done", -1.0) - (shot + t.end_after)) < 1.5 / FPS and ev.get("done", 999.0) <= 120.0, ", ".join(missing))
	_check("acceptance: the score plays on the Music bus at its volume, each part on its moment: the bed at %.2f s, the forge at %.2f s, the wait at %.2f s, the stinger with the shot (%.2f s)" % [ev.get("score_bed", -1.0), ev.get("score_forge", -1.0), ev.get("score_wait", -1.0), ev.get("score_stinger", -1.0)], bus_ok and absf(ev.get("score_bed", -1.0) - OpenerScore.BED_AT) < 1.5 / FPS and absf(ev.get("score_forge", -1.0) - t.forge_at) < 1.5 / FPS and absf(ev.get("score_wait", -1.0) - t.fire_from) < 1.5 / FPS and absf(ev.get("score_stinger", -1.0) - shot) < 1.5 / FPS)
	var levels := PackedFloat32Array()
	for i in int((shot + t.end_after) * FPS) + 1:
		levels.append(o.luma_at(i / FPS))
	var worst := _worst_flashes(levels)
	_check("acceptance: flash-safe through the kill and the title: at most 2 flashes in any second (worst %d), the shot's flash drawn from the brightness model (%d frames off)" % [worst, post_bad], worst <= 2 and post_bad == 0)
	_check("... and it lets go of everything as it ends: the forge, the title, the machine, the copy's name and the user name dropped, every sound stopped", o.forge() == null and o.title() == null and o.fall() == null and o.get("_user") == "" and _all_quiet(o))
	o.free()


## The shatters still under the opener (DaemonShatter's group), counted.
func _shatters(o: Node) -> int:
	return o.find_children("*", "Node3D", true, false).filter(func(n): return n.is_in_group(&"daemon_shatter")).size()


## With no press: the rifle fires on its own at fire_by, and the end is end_at.
func _auto_checks() -> void:
	var o := _opener(null, null)
	var t := o.timing()
	await _until(o, func(): return o.elapsed() >= t.fire_by + 0.2)
	var auto := o.event_time("auto")
	var shot := o.shot_time()
	await _until(o, func(): return false)
	await process_frame
	_check("acceptance: the opener never waits on the player: with no press the rifle fires on its own at fire_by (%.2f s), and it ends at %.2f s, by 2:00" % [shot, o.event_time("done")], absf(auto - t.fire_by) < 1.5 / FPS and absf(shot - t.fire_by) < 0.0001 and absf(o.event_time("done") - t.end_at) < 1.5 / FPS and t.end_at <= 120.0)
	o.free()


# --- Skipping, from every beat. ---

func _skip_checks() -> void:
	var menu_ok := PackedStringArray()
	var held_ok := PackedStringArray()
	var bad := PackedStringArray()
	for beat in BEATS:
		for how in ["menu", "hold"]:
			var o := _opener(null, null)
			o.pause_world = true
			await _until(o, func(): return o.elapsed() >= beat[0])
			var phase := o.phase_name()
			if how == "menu":
				_key(KEY_ESCAPE)
				var stopped := o.is_paused() and o.menu().showing() and o.menu().buttons()[1].has_focus()
				_key(KEY_ENTER)
				_key(KEY_ENTER, false)
				await process_frame
				if stopped and not o.playing() and _finished == [true] and phase == beat[1]:
					menu_ok.append(phase)
				else:
					bad.append("%s by the menu (%s)" % [beat[1], phase])
			else:
				_key(KEY_SPACE)
				var at := o.elapsed()
				var frames := 0
				var hint := false
				while o.playing() and frames < 90:
					await process_frame
					frames += 1
					if o.playing():
						hint = hint or (o.menu().hint_showing() and o.hold_share() > 0.0)
				if not o.playing() and _finished == [true] and o.event_time("held") >= at + 0.95 and phase == beat[1] and hint:
					held_ok.append(phase)
				else:
					bad.append("%s by holding Space (%s, %d frames)" % [beat[1], phase, frames])
				_key(KEY_SPACE, false)
			if paused or root.disable_3d or not _all_quiet(o):
				bad.append("%s left something held" % beat[1])
			o.free()
	_check("acceptance: skip works from every beat, C38's to C42's: Esc pauses in the intro's Esc menu and Enter on its focused \"Skip intro\" leaves (%s)" % ", ".join(menu_ok), menu_ok.size() == BEATS.size(), ", ".join(bad))
	_check("acceptance: ... and holding Space a second leaves too, its hint showing (%s); each time the game behind let go, the 3D view drawn, every sound stopped" % ", ".join(held_ok), held_ok.size() == BEATS.size() and bad.is_empty(), ", ".join(bad))
	var o := _opener(null, null)
	await _until(o, func(): return o.elapsed() >= 20.0)
	_key(KEY_SPACE)
	for i in 30:
		await process_frame
	_key(KEY_SPACE, false)
	await process_frame
	var still := o.playing() and o.hold_share() == 0.0
	_key(KEY_ESCAPE)
	var at := o.elapsed()
	for i in 10:
		await process_frame
	var held := o.elapsed() == at
	_key(KEY_ESCAPE)
	for i in 3:
		await process_frame
	_check("a short press of Space skips nothing (the hold starts again); Esc pauses the clock and Esc again resumes it", still and held and not o.is_paused() and o.elapsed() > at)
	o.skip()
	o.free()


# --- The first launch. ---

func _first_launch_checks() -> void:
	var path := _root.path_join("first.cfg")
	var main := await _lab("first.cfg", true)
	var menu = main.get_node("Hud").pause_menu()
	_check("a run hands no path by default (the tests, check.sh: never the player's file): nothing asked, nothing auto-played", menu.first_launch_path == "" and not menu.begin_first_launch() and not menu.showing_card() and not menu.showing_opener())
	menu.first_launch_path = path
	var began: bool = menu.begin_first_launch()
	await process_frame
	var card: FirstLaunchCard = menu.card()
	var text := " ".join(card.shown_text())
	var no_default: bool = card.buttons()[0].has_focus() and not card.buttons()[1].has_focus() and card.buttons()[0].text.begins_with("No")
	_check("acceptance: the first launch asks first: the card over the paused arena, a one-line content note and the question (may the intro use the real user name and folder names), No highlighted and focused", began and menu.showing_card() and paused and no_default and text.contains(FirstLaunchCard.NOTE) and text.contains(FirstLaunchCard.QUESTION) and FirstLaunchCard.NOTE.find(".") >= FirstLaunchCard.NOTE.length() - 60)
	_check("the card names nothing of the machine and promises what the reader keeps to: read-only, live, never saved, logged or sent, never told to the AI", not text.contains(USER) and not text.contains(HOST) and FirstLaunchCard.DETAIL.contains("Never saved, logged or sent") and FirstLaunchCard.DETAIL.contains("your AI never sees them"))
	_key(KEY_ESCAPE)
	await process_frame
	var saved := FileAccess.get_file_as_string(ProjectSettings.globalize_path(path))
	var o = menu.opener()
	_check("acceptance: Esc on the card is its default, No: opener data stays off (opener_real_data=\"off\"), the card is answered, and the opener plays itself on invented data", not Settings.opener_real_on(path) and saved.contains("opener_real_data=\"off\"") and IntroState.read(path)[IntroState.ASKED] and menu.autoplaying() and o != null and o.data is DemoOpenerData and not paused)
	await _until(o, func(): return o.elapsed() >= 30.0)
	o.skip()
	await process_frame
	await process_frame
	_check("acceptance: skipped (or watched to its end), the first launch's opener is played: the menu closes into the arena, the arena runs", IntroState.read(path)[IntroState.PLAYED] and not menu.is_open() and not paused and not menu.showing_opener())
	_check("acceptance: it auto-plays only once: asked again this run, nothing happens", not menu.begin_first_launch() and not menu.showing_card() and not menu.showing_opener())
	await _drop(main)
	var again := await _lab("first.cfg", true)
	var again_menu = again.get_node("Hud").pause_menu()
	again_menu.first_launch_path = path
	_check("acceptance: ... and never again at a later launch (the arena loaded again on the same settings): no card, no opener", not again_menu.begin_first_launch() and not again_menu.showing_card() and not again_menu.showing_opener())
	var replay = again_menu.open_opener()
	_check("acceptance: \"Play the opener\" in the Esc menu always replays it, and comes back to the menu", replay != null and again_menu.showing_opener() and not again_menu.autoplaying())
	replay.skip()
	await process_frame
	_check("... back to the menu as it was", again_menu.is_open() and not again_menu.showing_opener())
	again_menu.close()
	await _drop(again)
	# Yes: opener data on, and the opener takes the player's own data (here a stub's: nothing real is read).
	var yes_path := _root.path_join("yes.cfg")
	var yes_main := await _lab("yes.cfg", false)
	var yes_menu = yes_main.get_node("Hud").pause_menu()
	var made := []
	yes_menu.real_opener_source = func() -> OpenerData:
		made.append(1)
		return StubData.new()
	yes_menu.first_launch_path = yes_path
	yes_menu.begin_first_launch()
	await process_frame
	_key(KEY_Y)
	await process_frame
	var yes_opener = yes_menu.opener()
	_check("acceptance: Y on the card turns opener data on (the only way the first launch does), and the opener takes the player's data (a stub's here)", Settings.opener_real_on(yes_path) and yes_opener != null and yes_opener.data is StubData and made.size() == 1)
	yes_opener.skip()
	await process_frame
	await _drop(yes_main)
	# Interrupted (the window closed mid-way): it plays itself again next launch, no card; "Skip the intro next time"
	# kept across a restart.
	var cut_path := _root.path_join("cut.cfg")
	var cut := await _lab("cut.cfg", true)
	var cut_menu = cut.get_node("Hud").pause_menu()
	cut_menu.first_launch_path = cut_path
	cut_menu.begin_first_launch()
	await process_frame
	cut_menu.card().answer(false)
	await process_frame
	var first_play = cut_menu.opener()
	await _until(first_play, func(): return first_play.elapsed() >= 3.0)
	await _drop(cut)
	var back := await _lab("cut.cfg", true)
	var back_menu = back.get_node("Hud").pause_menu()
	back_menu.first_launch_path = cut_path
	var replays: bool = back_menu.begin_first_launch()
	await process_frame
	_check("acceptance: a first play cut short (the window closed) is not played: the next launch plays it again, with no card", replays and not back_menu.showing_card() and back_menu.autoplaying() and not IntroState.read(cut_path)[IntroState.PLAYED])
	var playing = back_menu.opener()
	await _until(playing, func(): return playing.elapsed() >= 2.0)
	_key(KEY_ESCAPE)
	playing.menu().toggle().button_pressed = true
	var kept_now: bool = IntroState.read(cut_path)[IntroState.SKIP_NEXT]
	await _drop(back)
	var later := await _lab("cut.cfg", true)
	var later_menu = later.get_node("Hud").pause_menu()
	later_menu.first_launch_path = cut_path
	var none: bool = not later_menu.begin_first_launch()
	_check("acceptance: \"Skip the intro next time\" (the intro's Esc menu) sticks across a restart: saved at once, and the next launch does not play it", kept_now and none and not later_menu.showing_opener() and IntroState.read(cut_path)[IntroState.SKIP_NEXT])
	var shown_toggle: bool = later_menu.open_opener().menu() != null
	later_menu.opener().pause()
	_check("... and its Esc menu shows it as kept", shown_toggle and later_menu.opener().menu().skip_next())
	later_menu.opener().skip()
	await process_frame
	later_menu.close()
	await _drop(later)
	await _save_checks()
	var online := await _lab("online.cfg", true)
	var online_menu = online.get_node("Hud").pause_menu()
	var fake := OnlineSession.new()
	online.add_child(fake)
	online_menu.session = fake
	online_menu.first_launch_path = _root.path_join("online.cfg")
	_check("in a match the first launch waits (no card, no opener: a match cannot pause)", not online_menu.begin_first_launch() and not online_menu.showing_card())
	online_menu.session = null
	fake.free()
	await _drop(online)


## A C33 save and the settings screen's own sections still load beside the [intro] section.
func _save_checks() -> void:
	var settings := _root.path_join("old.cfg")
	var progress_path := _root.path_join("progress.cfg")
	var old := Progress.new()
	old.path = progress_path
	old.feats = {"kills_terminal_cannon": 12, "rail_heads": 3}
	old.held = {Progress.key_of("sigkill_rail", "glacier"): true}
	var progress_saved := old.save()
	var game := GameSettings.new()
	game.path = settings
	game.set_value("video", "fov", 95)
	game.set_value("audio", "music", 0.4)
	game.save()
	Settings.save_roast(true, settings)
	IntroState.mark_asked(settings)
	IntroState.mark_played(settings)
	IntroState.save_skip_next(true, settings)
	var loaded := Progress.new()
	loaded.path = progress_path
	var how := loaded.load_file()
	var again := GameSettings.new()
	again.path = settings
	again.load_file()
	_check("acceptance: old C33 saves still load: the unlocks' own file untouched by the first launch (\"%s\", the counts as kept), and the settings file's other sections and privacy answers as they were beside [intro]" % how, progress_saved and how == "loaded" and loaded.count_of("kills_terminal_cannon") == 12 and loaded.count_of("rail_heads") == 3 and again.value("video", "fov") == 95 and absf(again.value("audio", "music") - 0.4) < 0.001 and Settings.roast_on(settings) and IntroState.read(settings) == {"asked": true, "played": true, "skip_next": true})


# --- The AI's answer kept for replays. ---

func _reuse_checks() -> void:
	OpenerLink.forget_session()
	var stubs: Array = []
	var guide := Link.new()
	guide.settings_path = _root.path_join("reuse.cfg")
	Settings.save("claude", true, guide.settings_path)
	var found := Found.new()
	found.agent_state = Found.AgentState.KNOWN
	found.agent = "claude"
	found.agent_cli_present = true
	Detector.resolve(found)
	var detector := FakeDetector.new()
	detector.result = found
	guide.detector = detector
	guide.adapter_factory = func(_f, _d, tuning: Resource):
		var s := StubAdapter.new(tuning)
		stubs.append(s)
		return s
	guide.start()
	var first := await _link_run(guide)
	var second := await _link_run(guide)
	guide.set_consent(false)
	var third := await _link_run(guide)
	var asks: int = stubs[0].asks if not stubs.is_empty() else -1
	_check("acceptance: replays keep the session's calls: the first play asks the AI once (live, \"%s\"); a replay shows that answer again, marked live and earlier (\"%s\"), with no call" % [first["line"], second["status"]], first["live"] and first["asked"] and second["live"] and second["reused"] and not second["asked"] and second["line"] == first["line"] and second["status"].begins_with("live  earlier,") and asks == 1)
	_check("... unless the AI was turned off since: then the scripted line and why, and still no call", not third["live"] and third["why"] == "AI off" and asks == 1)
	guide.shut_down(null)
	OpenerLink.forget_session()


## One play of the opener on `guide` until its line is shown: what it showed.
func _link_run(guide) -> Dictionary:
	var o: Opener = OpenerScene.instantiate()
	o.guide = guide
	root.add_child(o)
	var t := o.timing()
	await _until(o, func(): return o.elapsed() >= t.answer_by + 0.4)
	var link := o.link()
	var out := {"line": link.line(), "live": link.live(), "asked": link.asked(), "reused": link.reused(), "why": link.why(), "status": o.link_beat().status_text() if o.link_beat() != null else ""}
	o.skip()
	o.free()
	await process_frame
	return out


# --- Helpers. ---

## An opener on `data` (null: its own demo data) in the tree, playing.
func _opener(data: OpenerData, guide) -> Opener:
	_finished.clear()
	var o: Opener = OpenerScene.instantiate()
	o.data = data
	o.guide = guide
	o.finished.connect(func(skipped: bool): _finished.append(skipped))
	root.add_child(o)
	return o


func _until(o: Opener, condition: Callable) -> void:
	var frames := 0
	while frames < MOST_FRAMES and is_instance_valid(o) and o.playing() and not condition.call():
		await process_frame
		frames += 1


func _key(code: Key, pressed: bool = true) -> void:
	var key := InputEventKey.new()
	key.keycode = code
	key.physical_keycode = code
	key.pressed = pressed
	root.push_input(key)


func _fire() -> void:
	var press := InputEventAction.new()
	press.action = "fire"
	press.pressed = true
	root.push_input(press)


func _all_quiet(o: Opener) -> bool:
	for p in o.find_children("*", "AudioStreamPlayer", true, false):
		if (p as AudioStreamPlayer).playing:
			return false
	return true


## The arena alone, practice on, a link parked for its guide HUD (demo or not), its privacy file in the test's folder.
func _lab(settings: String, demo: bool) -> Node:
	GameSettings.current().set_value("gameplay", "practice", true)
	GameSettings.current().set_value("gameplay", "ice", false)
	var link := Link.new()
	link.settings_path = _root.path_join(settings)
	link.demo = demo
	Link.park(link)
	var main = MainScene.instantiate()
	main.launch_args = PackedStringArray()
	root.add_child(main)
	_arenas.append(main)
	main.get_node("Hud").guide().focus_check = func(): return false
	main.get_node("Hud").round_hud()._left_s = LONG_ROUND_S
	main.get_node("Player").assume_captured = true
	await process_frame
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
	paused = false
	await process_frame


## Flashes in the worst one-second window of `levels` (one a frame at FPS), as step 48 counts them.
static func _worst_flashes(levels: PackedFloat32Array) -> int:
	var changes: Array = []
	var start := 0
	var last := 0
	var dir := 0.0
	for i in range(1, levels.size()):
		var d := signf(levels[i] - levels[i - 1])
		if d == 0.0:
			continue
		if d != dir:
			if dir != 0.0 and absf(levels[last] - levels[start]) >= 0.1:
				changes.append([float(last) / FPS, dir])
			start = i - 1
			dir = d
		last = i
	if dir != 0.0 and absf(levels[last] - levels[start]) >= 0.1:
		changes.append([float(last) / FPS, dir])
	var worst := 0
	for i in changes.size():
		var count := 0
		var j := i
		while j + 1 < changes.size() and changes[j + 1][0] - changes[i][0] < 1.0:
			if changes[j + 1][1] != changes[j][1]:
				count += 1
				j += 2
			else:
				j += 1
		worst = maxi(worst, count)
	return worst


func _cleanup() -> void:
	for main in _arenas.duplicate():
		await _drop(main)
	_wipe(_abs)
	_check("the test's own folder is gone, nothing of it left under user://", not DirAccess.dir_exists_absolute(_abs))
	await process_frame
	# A stopped sound is let go on the audio thread's next mix, in real time: give it that before quitting.
	OS.delay_msec(300)
	await process_frame


## The test's own folder removed: only under it, a link removed as itself and never followed.
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


func _code(path: String) -> String:
	return FileAccess.get_file_as_string(path)


func _body(source: String, name: String) -> String:
	var at := source.find("\nfunc %s(" % name)
	if at < 0:
		return ""
	var end := source.find("\nfunc ", at + 1)
	return source.substr(at, end - at) if end > 0 else source.substr(at)
