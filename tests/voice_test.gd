extends SceneTree
## Headless test of voice commands (W7, PRD 5.5). scripts/check.sh runs it as step 71, and any FAIL exits 1; the step
## also searches this run's whole output for the canary phrase.
##
##   godot --headless --path . --fixed-fps 60 --script res://tests/voice_test.gd
##
## Driven only by the game's own demo feed (in-process) and a fake feed this test serves itself on 127.0.0.1 (FakeFeed
## below): no real transcript program is ever asked. The fake feed's lines carry a canary phrase; it must never turn up
## in any print or log line, HUD text, node's property, file under user:// or call to the player's AI.
##
## The words: commands from talk lines, loosely (case, punctuation, small mishearings, a wake word, filler), everyday talk
## never a command, no command phrase opening "Larry, tell" and no such line ever acted on. The feed: only loopback http
## addresses (127.0.0.1, ::1, localhost) accepted, every other refused with a plain line; an answer's talk rows acted on,
## its TV rows skipped, its first answer only learned, its text field found by any of its names, unknown fields ignored,
## junk and an oversized answer refused. The adapter: an empty address means no request at all, and so does the real-data
## opt-in off; a set address and the opt-in on, commands fire from the fake feed's talk and never from its TV; a feed
## that is down, hangs, answers junk, an error or a redirect leaves voice off with the chip saying so, never stalls a
## frame, follows no redirect and backs off. The cover drone (by voice, and by its key, P): out over the player's
## shoulder, locking on and firing at a daemon, leaving, recharging; its kills no sudo streak. The demo: every scripted
## command fires in order, the TV's lines skipped, a "Larry, tell" line refused, the HUD's chip, toast and cover line.
## The menu and settings: the "Voice commands" entry (one world mode at a time), the voice feed box empty by default with
## its generic words. The code: nothing in the game opens a microphone or captures audio; no listening socket, program
## run, systemctl or compositor call in the voice code, and in the rest of the game only where the multiplayer and the AI
## always had them. The keys: P for cover me and every other key of the arena unchanged, no Ctrl+Alt combo.

const MainScene = preload("res://scenes/main.tscn")
const Link = preload("res://scripts/guide/guide_link.gd")
const Controls = preload("res://scripts/controls.gd")
const SettingsApply = preload("res://scripts/settings/settings_apply.gd")
const VoiceFeed = preload("res://scripts/voice/voice_feed.gd")
const VoiceMatch = preload("res://scripts/voice/voice_match.gd")
const VoiceSound = preload("res://scripts/voice/voice_sound.gd")

## The fake feed's canary: never to be seen anywhere but in what the fake feed sends.
const CANARY := "TANGERINE-OCELOT-4417"
const VOICE_CODE := ["res://scripts/voice/voice_commands.gd", "res://scripts/voice/voice_feed.gd", "res://scripts/voice/voice_match.gd", "res://scripts/voice/voice_demo.gd", "res://scripts/voice/voice_hud.gd", "res://scripts/voice/cover_drone.gd", "res://scripts/voice/voice_sound.gd"]
## Nothing the voice code may do: run a program, signal one, call systemctl or the compositor, listen or bind, touch a
## file, print or log, or talk to the AI or the announcer.
const NEVER := ["OS.execute", "create_process", "execute_with_pipe", "OS.kill", "shell_open", "systemctl", "hyprctl", "hyprland", "swaymsg", "wmctrl", "xdotool", "ydotool", "TCPServer", "UDPServer", "PacketPeer", "StreamPeer", "WebSocket", "ENet", "create_server", "listen(", "MultiplayerPeer", "IP.resolve", "FileAccess", "DirAccess", "store_", "ResourceSaver", "user://", "ConfigFile", "print(", "print_rich", "printerr", "printraw", "push_error", "push_warning", "OS.alert", ".ask(", "ask_ai", "announcer", "roast", "prompt", "AudioEffectCapture", "AudioEffectRecord", "AudioStreamMicrophone", "input_device", "record"]
## Only voice_commands.gd asks the feed (the one HTTP client); the others never touch the network at all.
const NET_WORDS := ["HTTPRequest", "HTTPClient"]
## A microphone or audio capture anywhere in the game: none.
const MIC := ["AudioEffectCapture", "AudioEffectRecord", "AudioStreamMicrophone", "input_device", "set_input_device", "enable_input", "record_bus", "get_input_mix_rate", "get_input_frames"]
## Where the game listens on a socket (the multiplayer's host, its relay rendezvous) and runs a program (the player's own
## AI agent and the GPU readout), as since C13 and C9; voice adds to neither.
const LISTENERS := ["res://scripts/net/net_session.gd", "res://scripts/net/ws_rendezvous.gd", "res://scripts/net/udp_rendezvous.gd"]
const RUNNERS := ["res://scripts/ai/guide_process.gd", "res://scripts/ai/ai_source_detector.gd"]
## Every key the arena had before W7, by action: [kind, code] (key or mouse), the default bind each stays.
const KEYS_BEFORE := {
	"move_forward": KEY_W, "move_back": KEY_S, "move_left": KEY_A, "move_right": KEY_D, "jump": KEY_SPACE, "slide": KEY_C,
	"crouch": KEY_X, "reload": KEY_E, "weapon_last": KEY_Q, "reset_arena": KEY_R, "ask_ai": KEY_T, "toggle_ai": KEY_O,
	"toggle_roast": KEY_B, "net_menu": KEY_M, "sigstop": KEY_F, "throw_bomb": KEY_G, "code_rain_vision": KEY_V,
	"sudo_overcharge": KEY_Z, "show_top": KEY_TAB, "run_breaker": KEY_U, "cycle_breaker": KEY_Y, "weapon_bank": KEY_SHIFT,
	"audit_visor": KEY_I, "release_mouse": KEY_ESCAPE,
}
const MOST_FRAMES := 3600
const LONG_ROUND_S := 100000.0


## A feed served by this test alone, on 127.0.0.1, a port the system picks: it answers each request by its mode.
class FakeFeed:
	var server := TCPServer.new()
	var port := 0
	var mode := "rows"
	var rows: Array = []
	var connections := 0
	var answered := 0
	var _peers: Array = []

	func start() -> bool:
		if server.listen(0, "127.0.0.1") != OK:
			return false
		port = server.get_local_port()
		return true

	func url() -> String:
		return "http://127.0.0.1:%d/lines" % port

	func step() -> void:
		while server.is_connection_available():
			var peer := server.take_connection()
			connections += 1
			_peers.append({"peer": peer, "buf": PackedByteArray(), "done": false, "age": 0})
		var keep: Array = []
		for e in _peers:
			var peer: StreamPeerTCP = e["peer"]
			peer.poll()
			e["age"] += 1
			if peer.get_status() != StreamPeerTCP.STATUS_CONNECTED:
				continue
			var n := peer.get_available_bytes()
			if n > 0:
				var buf: PackedByteArray = e["buf"]
				buf.append_array(peer.get_data(n)[1])
				e["buf"] = buf
			if not e["done"] and (e["buf"] as PackedByteArray).get_string_from_ascii().contains("\r\n\r\n"):
				e["done"] = true
				e["age"] = 0
				_answer(peer)
			if e["done"] and mode != "hang" and e["age"] > 20:
				peer.disconnect_from_host()
				continue
			keep.append(e)
		_peers = keep

	func _answer(peer: StreamPeerTCP) -> void:
		answered += 1
		match mode:
			"rows":
				_send(peer, "200 OK", JSON.stringify(rows))
			"junk":
				_send(peer, "200 OK", "<html>this is not a feed</html>")
			"error":
				_send(peer, "500 Internal Server Error", "{}")
			"big":
				var pad := "x".repeat(1024)
				var many: Array = []
				for i in 300:
					many.append({"id": i, "media": 0, "text": pad})
				_send(peer, "200 OK", JSON.stringify(many))
			"redirect":
				peer.put_data(("HTTP/1.1 302 Found\r\nLocation: http://example.invalid/lines\r\nContent-Length: 0\r\nConnection: close\r\n\r\n").to_ascii_buffer())
			"slam":
				peer.disconnect_from_host()
			"hang":
				pass

	func _send(peer: StreamPeerTCP, status: String, body: String) -> void:
		var bytes := body.to_utf8_buffer()
		var head := "HTTP/1.1 %s\r\nContent-Type: application/json\r\nContent-Length: %d\r\nConnection: close\r\n\r\n" % [status, bytes.size()]
		peer.put_data(head.to_ascii_buffer())
		peer.put_data(bytes)

	func stop() -> void:
		for e in _peers:
			(e["peer"] as StreamPeerTCP).disconnect_from_host()
		_peers.clear()
		server.stop()


## Every line Godot prints or logs while the test runs, searched for the canary.
class CanaryLog extends Logger:
	var hits := 0
	var lines := 0

	func _log_message(message: String, _error: bool) -> void:
		lines += 1
		if message.contains(CANARY):
			hits += 1

	func _log_error(function: String, file: String, _line: int, code: String, rationale: String, _editor_notify: bool, _error_type: int, _script_backtraces: Array[ScriptBacktrace]) -> void:
		lines += 1
		if (function + file + code + rationale).contains(CANARY):
			hits += 1


var _fails := 0
var _checks := 0
var _abs := ""
var _feed := FakeFeed.new()
var _log := CanaryLog.new()
var _gaps: Array = []
var _fired: Array = []


func _initialize() -> void:
	_run()


func _run() -> void:
	await process_frame
	OS.add_logger(_log)
	root.size = Vector2i(1280, 720)
	_abs = ProjectSettings.globalize_path("user://voice-test-%d" % OS.get_process_id())
	if DirAccess.dir_exists_absolute(_abs):
		print("FAIL the test's own folder already exists; not touching it")
		quit(1)
		return
	DirAccess.make_dir_recursive_absolute(_abs)
	Controls.ensure()
	GameSettings.current().reset()
	SettingsApply.apply_audio(GameSettings.current())
	MissionRunner.clear_pending()
	_clear_modes()
	MissionProgress.current().path = _abs.path_join("progress.cfg")
	MissionProgress.current().clear()
	Progress.current().path = _abs.path_join("progress.cfg")
	Progress.current().clear()
	AuditVisor.remembered = false
	_code_checks()
	_key_checks()
	_word_checks()
	_address_checks()
	_digest_checks()
	if not _feed.start():
		_check("the test's own fake feed listens on 127.0.0.1", false)
	await _adapter_checks()
	await _trouble_checks()
	await _cover_checks()
	await _demo_checks()
	await _menu_checks()
	await _canary_checks()
	await _cleanup()
	OS.remove_logger(_log)
	print("VOICE: %d checks" % _checks)
	print("VOICE RESULT: ", "ALL PASS" if _fails == 0 else "%d FAILED" % _fails)
	quit(0 if _fails == 0 else 1)


func _check(label: String, ok: bool, detail: String = "") -> void:
	_checks += 1
	print("PASS " if ok else "FAIL ", label, ("   " + detail) if detail != "" else "")
	if not ok:
		_fails += 1


func _clear_modes() -> void:
	ProcHunt.clear()
	FolderMap.clear()
	ThemeShift.clear()
	KeybindGunplay.clear()
	PacketTracer.clear()
	CoopHunt.clear()
	VoiceDemo.clear()


# --- The code. ---

func _code_checks() -> void:
	var found := PackedStringArray()
	for path in VOICE_CODE:
		var code := _code_of(path)
		if code == "":
			found.append(path + ": unreadable")
		for word in NEVER:
			if code.to_lower().contains(word.to_lower()):
				found.append("%s: %s" % [path.get_file(), word])
		if path != "res://scripts/voice/voice_commands.gd":
			for word in NET_WORDS:
				if code.contains(word):
					found.append("%s: %s" % [path.get_file(), word])
	_check("acceptance (safety): nothing in the voice code runs or signals a program, calls systemctl or the compositor, listens on or binds a port, opens a socket of its own, touches a file, prints or logs, or talks to the AI or the announcer; only the adapter asks the feed, as an HTTP client (%d files)" % VOICE_CODE.size(), found.is_empty(), ", ".join(found))
	var adapter := _code_of("res://scripts/voice/voice_commands.gd")
	_check("the adapter's one request is a client's: no redirects followed, a short wall-clock timeout, a capped answer, non-blocking sockets (no thread to join), and every answer read off the main thread", adapter.contains("max_redirects = 0") and adapter.contains("TIMEOUT_S * 1000.0") and adapter.contains("body_size_limit = VoiceFeed.BODY_LAST") and adapter.contains("use_threads = false") and adapter.contains("WorkerThreadPool.add_task") and VoiceCommands.TIMEOUT_S <= 1.0)
	var mic := PackedStringArray()
	var listen := PackedStringArray()
	var run := PackedStringArray()
	var ipc := PackedStringArray()
	for path in _game_code():
		var code := _code_of(path)
		for word in MIC:
			if code.contains(word):
				mic.append("%s: %s" % [path.get_file(), word])
		if (code.contains("create_server(") or code.contains("TCPServer") or code.contains("UDPServer") or code.contains("PacketPeerUDP")) and not LISTENERS.has(path):
			listen.append(path.get_file())
		if (code.contains("OS.execute") or code.contains("create_process") or code.contains("execute_with_pipe")) and not RUNNERS.has(path):
			run.append(path.get_file())
		for word in ["systemctl", "hyprctl", "swaymsg", "HYPRLAND_INSTANCE", ".socket.sock", "socket2.sock", "wmctrl", "xdotool"]:
			if code.contains(word):
				ipc.append("%s: %s" % [path.get_file(), word])
	var scenes := PackedStringArray()
	for path in _files_under("res://scenes", ".tscn"):
		var text := FileAccess.get_file_as_string(path)
		for word in ["AudioEffectCapture", "AudioEffectRecord", "AudioStreamMicrophone"]:
			if text.contains(word):
				scenes.append("%s: %s" % [path.get_file(), word])
	var ext := _files_under("res://", ".gdextension")
	_check("acceptance (no microphone): nothing in the game (%d scripts, the scenes, the project) opens a microphone or captures audio: no capture or record effect, no microphone stream, no input device, audio input off in the project, no native extension (no speech library)" % _game_code().size(), mic.is_empty() and scenes.is_empty() and ext.is_empty() and not bool(ProjectSettings.get_setting("audio/driver/enable_input", false)), ", ".join(mic + scenes + ext))
	_check("acceptance (no listening, no programs, no IPC): no script of the game listens on a socket but the multiplayer's three, runs a program but the AI's two (the player's own agent and the GPU readout), or calls systemctl or a compositor anywhere", listen.is_empty() and run.is_empty() and ipc.is_empty(), ", ".join(listen + run + ipc))


## The game's own scripts: scripts/ and tools/ (tests/ and the separately hosted relay/ are not the game).
func _game_code() -> PackedStringArray:
	var out := _files_under("res://scripts", ".gd")
	out.append_array(_files_under("res://tools", ".gd"))
	return out


func _files_under(dir_path: String, suffix: String) -> PackedStringArray:
	var out := PackedStringArray()
	var dir := DirAccess.open(dir_path)
	if dir == null:
		return out
	dir.list_dir_begin()
	var name := dir.get_next()
	while name != "":
		var full := dir_path.path_join(name)
		if dir.current_is_dir():
			if not name.begins_with(".") and name != "tests" and name != "relay" and name != "build":
				out.append_array(_files_under(full, suffix))
		elif name.ends_with(suffix):
			out.append(full)
		name = dir.get_next()
	dir.list_dir_end()
	return out


## A file's code with its comments taken out.
func _code_of(path: String) -> String:
	var out := PackedStringArray()
	for line in FileAccess.get_file_as_string(path).split("\n"):
		var at := line.find("#")
		out.append(line.substr(0, at) if at >= 0 else line)
	return "\n".join(out)


# --- The keys. ---

func _key_checks() -> void:
	var changed := PackedStringArray()
	for action in KEYS_BEFORE:
		var events := InputMap.action_get_events(action)
		var ok := false
		for ev in events:
			if ev is InputEventKey and (ev as InputEventKey).physical_keycode == KEYS_BEFORE[action]:
				ok = true
		if not ok:
			changed.append(action)
	for i in 9:
		var events := InputMap.action_get_events("weapon_%d" % (i + 1))
		if events.size() != 1 or (events[0] as InputEventKey).physical_keycode != Controls.SLOT_KEYS[i]:
			changed.append("weapon_%d" % (i + 1))
	# The keys and mouse buttons are what W7 promised unchanged: the gamepad's triggers (scripts/controls.gd) sit after them.
	var fire := InputMap.action_get_events("fire").filter(func(e): return not e is InputEventJoypadMotion and not e is InputEventJoypadButton)
	var aim := InputMap.action_get_events("aim").filter(func(e): return not e is InputEventJoypadMotion and not e is InputEventJoypadButton)
	if fire.size() != 1 or (fire[0] as InputEventMouseButton).button_index != MOUSE_BUTTON_LEFT or aim.size() != 1 or (aim[0] as InputEventMouseButton).button_index != MOUSE_BUTTON_RIGHT:
		changed.append("fire/aim")
	_check("acceptance: the regular arena's keys are unchanged: every action's key as before W7 (%d actions, the slots, fire and aim)" % KEYS_BEFORE.size(), changed.is_empty(), ", ".join(changed))
	var cover := InputMap.action_get_events("cover_me")
	var on_p := 0
	for action in InputMap.get_actions():
		for ev in InputMap.action_get_events(action):
			if ev is InputEventKey and (ev as InputEventKey).physical_keycode == KEY_P:
				on_p += 1
	_check("cover me has its own key, P, rebindable as \"cover me\", which nothing else in the game uses (no conflict on the settings screen)", cover.size() == 1 and (cover[0] as InputEventKey).physical_keycode == KEY_P and Controls.rebindable("cover_me") and on_p == 1 and Controls.conflicts({}).is_empty())
	var chorded := PackedStringArray()
	var game_actions := 0
	for action in InputMap.get_actions():
		if str(action).begins_with("ui_"):
			continue  # Godot's own text-box and list keys, not the game's
		game_actions += 1
		for ev in InputMap.action_get_events(action):
			if ev is InputEventWithModifiers and ((ev as InputEventWithModifiers).ctrl_pressed and (ev as InputEventWithModifiers).alt_pressed):
				chorded.append(str(action))
	_check("acceptance: no Ctrl+Alt combo anywhere in the game's keys (%d actions of its own)" % game_actions, chorded.is_empty(), ", ".join(chorded))
	var keyed := PackedStringArray()
	for id in VoiceMatch.ORDER:
		if str(VoiceMatch.COMMANDS[id].get("key", "")) == "":
			keyed.append(str(id))
	_check("every voice command has a key too, so nothing needs a voice: cover me P, drop a breaker U, reload E, visor I, pause F, resume F again", keyed.is_empty() and VoiceMatch.COMMANDS[&"cover"]["key"] == "P" and VoiceMatch.COMMANDS[&"breaker"]["key"] == "U" and VoiceMatch.COMMANDS[&"reload"]["key"] == "E" and VoiceMatch.COMMANDS[&"visor"]["key"] == "I" and VoiceMatch.COMMANDS[&"pause"]["key"] == "F", ", ".join(keyed))


# --- The words (pure). ---

func _word_checks() -> void:
	var said := {
		"Reload!": &"reload", "re-load, please": &"reload", "RELOAD RELOAD": &"reload", "reload now": &"reload",
		"Larry, cover me!": &"cover", "hey Larry, cover me": &"cover", "cover me, cover me": &"cover", "Larry cover me.": &"cover",
		"drop a breaker": &"breaker", "Drop a breaker please": &"breaker", "icebreaker": &"breaker",
		"visor": &"visor", "Visa": &"visor", "visor off": &"visor", "pause.": &"pause", "Pause!": &"pause", "sigstop": &"pause",
		"resume": &"resume", "continue": &"resume", "realod": &"reload",
	}
	var wrong := PackedStringArray()
	for text in said:
		if VoiceMatch.command_of(text) != said[text]:
			wrong.append("%s -> %s" % [text, VoiceMatch.command_of(text)])
	_check("acceptance: commands match loosely: case, punctuation, a wake word, filler, a word said twice and small mishearings (%d lines)" % said.size(), wrong.is_empty(), ", ".join(wrong))
	var talk := ["I need to reload the page", "the visor on that helmet is great", "pause the music for a second", "can you cover the dish", "we should drop the breaker panel idea", "continue with the next slide when ready", "Over.", "hover", "Cause!", "presume", "beaker", "vigor", "showtime", "", "   ", "!!!", "reload " + "x".repeat(200)]
	var fired := PackedStringArray()
	for text in talk:
		if VoiceMatch.command_of(text) != &"":
			fired.append(text.left(30))
	_check("everyday talk that only mentions a command's word is never a command (%d lines)" % talk.size(), fired.is_empty(), ", ".join(fired))
	var told := PackedStringArray()
	for id in VoiceMatch.ORDER:
		for phrase in VoiceMatch.COMMANDS[id]["phrases"]:
			if (phrase as String).begins_with("larry tell") or (phrase as String).begins_with("tell"):
				told.append(phrase)
			for line in ["Larry, tell " + phrase, "hey Larry tell " + phrase, "LARRY TELL ME TO " + phrase, "Larry, tell"]:
				if VoiceMatch.command_of(line) != &"":
					told.append(line)
	var names := PackedStringArray()
	for id in VoiceMatch.ORDER:
		names.append(VoiceMatch.name_of(id))
	_check("acceptance: no command phrase begins \"Larry, tell\", and no line that begins so is ever a command (each phrase tried after it, %d commands: %s)" % [names.size(), ", ".join(names)], told.is_empty() and not VoiceMatch.WAKE.has("tell"), ", ".join(told))


# --- The address (pure). ---

func _address_checks() -> void:
	var good := {
		"http://127.0.0.1:8123/lines": "http://127.0.0.1:8123/lines", "http://localhost:8123/lines?last=5": "http://127.0.0.1:8123/lines?last=5",
		"http://[::1]:8123/": "http://[::1]:8123/", "HTTP://LOCALHOST/feed": "http://127.0.0.1/feed", "http://127.0.0.1": "http://127.0.0.1/",
	}
	var wrong := PackedStringArray()
	for url in good:
		var c := VoiceFeed.check(url)
		if not c["ok"] or c["url"] != good[url]:
			wrong.append("%s -> %s" % [url, c["url"]])
	_check("loopback http addresses are accepted (127.0.0.1, [::1], localhost, any case, a port, a path), localhost asked for as 127.0.0.1 so no name is ever looked up", wrong.is_empty(), ", ".join(wrong))
	# Addresses that are not the loopback, built at run time (none of them anyone's real machine).
	var any_host := "%d.%d.%d.%d" % [0, 0, 0, 0]
	var other_loop := "%d.%d.%d.%d" % [127, 0, 0, 2]
	var lan := "%d.%d.%d.%d" % [10, 1, 2, 3]
	var bad := ["http://example.com/lines", "https://127.0.0.1/lines", "ws://127.0.0.1/", "http://127.0.0.1@example.com/", "http://127.0.0.1.example.com/", "http://localhost.example.com/", "http://%s:80/" % any_host, "http://%s/" % other_loop, "http://%s/" % lan, "http://[::2]/", "http://[::1]x/", "http://127.0.0.1:0/", "http://127.0.0.1:70000/", "http://127.0.0.1:/", "http://127.0.0.1:80a/", "http:///lines", "127.0.0.1:8123/lines", "http://127.0.0.1/a b", "http://127.0.0.1/\"x", "http://127.0.0.1/" + "x".repeat(80), "file:///lines"]
	var let_in := PackedStringArray()
	var said_why := true
	for url in bad:
		var c := VoiceFeed.check(url)
		if c["ok"]:
			let_in.append(url)
		said_why = said_why and str(c["why"]) != ""
	_check("acceptance: every other address is refused with a plain line (%d tried: another host, https, another scheme, a name hidden behind @, a name that starts like the loopback, the any-address, another loopback address, a LAN address, a bad port, too long)" % bad.size(), let_in.is_empty() and said_why and VoiceFeed.REFUSED.contains("loopback only"), ", ".join(let_in))
	var s := GameSettings.new()
	var refused: bool = not s.set_value("voice", "feed_url", "http://example.com/lines") and s.value("voice", "feed_url") == ""
	var kept: bool = s.set_value("voice", "feed_url", "http://localhost:8123/lines") and s.value("voice", "feed_url") == "http://localhost:8123/lines"
	var cleared: bool = s.set_value("voice", "feed_url", "") and s.value("voice", "feed_url") == ""
	_check("acceptance: the voice feed is a setting, EMPTY by default; the settings refuse a non-loopback address and keep a loopback one (at most %d characters, the settings file's longest string)" % VoiceFeed.URL_LAST, GameSettings.new().value("voice", "feed_url") == "" and refused and kept and cleared and VoiceFeed.URL_LAST <= 64)


# --- An answer read (pure). ---

func _digest_checks() -> void:
	var rows := [
		{"id": 10, "media": 0, "text": "Reload!", "speaker": "x", "confidence": 0.9},
		{"id": 11, "media": 1, "text": "reload"},
		{"id": 12, "media": 2, "text": "Larry, cover me"},
		{"id": 13, "media": 0, "transcript": "Larry, cover me"},
		{"id": 14, "media": -1, "content": "visor"},
		{"id": 15, "media": 0, "text": "Larry, tell me a joke about the visor " + CANARY},
		{"id": 16, "text": "pause"},
		{"id": "17", "media": 0, "text": "the rain is loud " + CANARY},
		{"media": 0, "text": "reload"},
		"reload",
	]
	var body := JSON.stringify(rows).to_utf8_buffer()
	var learned := VoiceFeed.digest(body, -1, true)
	_check("the first answer only learns where the feed stands: nothing fires, the newest id kept", learned["ok"] and learned["last_id"] == 17 and (learned["commands"] as Array).is_empty())
	var r := VoiceFeed.digest(body, 9, false)
	_check("acceptance: talk rows (media 0 or less) are acted on, TV rows (media 1 and 2) skipped even when they say a command, a row with no media or no id skipped, the text found by any of its names (text, transcript, content), unknown fields ignored, a \"Larry, tell\" row refused", r["ok"] and r["commands"] == [&"reload", &"cover", &"visor"] and r["media"] == 2 and r["talk"] == 5 and r["blocked"] == 1 and r["last_id"] == 17, str(r["commands"]))
	var _no_text := true
	for key in r:
		if str(r[key]).contains(CANARY) or str(r[key]).contains("rain"):
			_no_text = false
	_check("what comes back holds no text: numbers and command ids only", _no_text and r.keys().size() == 9)
	var again := VoiceFeed.digest(body, 17, false)
	_check("only rows newer than the last id seen count (the same answer again fires nothing)", again["ok"] and (again["commands"] as Array).is_empty() and again["talk"] == 0)
	var back := VoiceFeed.digest(JSON.stringify([{"id": 2, "media": 0, "text": "reload"}]).to_utf8_buffer(), 17, false)
	_check("a feed that began again (its ids went back) is learned anew, firing nothing", back["ok"] and back["restarted"] and back["last_id"] == 2 and (back["commands"] as Array).is_empty())
	var wrapped := VoiceFeed.digest(JSON.stringify({"lines": [{"id": 30, "media": 0, "text": "reload"}], "next": 31}).to_utf8_buffer(), 17, false)
	_check("an object answer holding its lines (under lines, rows, items...) is read the same", wrapped["ok"] and wrapped["commands"] == [&"reload"])
	var junk := ["<html>no</html>", "{\"a\": 1}", "42", "\"reload\"", "[1, 2, 3]", ""]
	var junk_ok := PackedStringArray()
	for j in junk:
		var d := VoiceFeed.digest(j.to_utf8_buffer(), -1, false)
		if d["ok"] and not (d["commands"] as Array).is_empty():
			junk_ok.append(j)
		if not d["ok"] and str(d["why"]) == "":
			junk_ok.append("no why: " + j)
	var big := PackedByteArray()
	big.resize(VoiceFeed.BODY_LAST + 1)
	big.fill(0x20)
	var too_big := VoiceFeed.digest(big, -1, false)
	_check("junk is refused, never a command (not JSON, an object with no lines, a number, a string, a list of numbers, nothing), and an answer over %d KB is refused unread" % (VoiceFeed.BODY_LAST / 1024), junk_ok.is_empty() and not too_big["ok"] and too_big["why"] == "too big", ", ".join(junk_ok))
	var storm: Array = []
	for i in 20:
		storm.append({"id": 100 + i, "media": 0, "text": "reload"})
	var capped := VoiceFeed.digest(JSON.stringify(storm).to_utf8_buffer(), 99, false)
	_check("a backlog never turns into a storm: at most %d commands from one answer" % VoiceFeed.COMMANDS_LAST, (capped["commands"] as Array).size() == VoiceFeed.COMMANDS_LAST and capped["last_id"] == 119)


# --- The adapter, on the test's own fake feed. ---

func _adapter_checks() -> void:
	var main := await _arena()
	var voice := VoiceCommands.of(main)
	var hud = main.get_node("Hud").voice_hud()
	_feed.mode = "rows"
	_feed.rows = []
	await _frames(40)
	_check("acceptance: an empty address (the default) means no network call at all: no request made, no HTTP client exists, the fake feed never reached, the chip hidden", voice != null and voice.state() == "off" and voice.asks == 0 and main.find_children("*", "HTTPRequest", true, false).is_empty() and _feed.connections == 0 and hud.chip_lines().is_empty())
	GameSettings.current().set_value("voice", "feed_url", _feed.url())
	await _frames(60)
	var gate_off: bool = voice.state() == "gate" and voice.asks == 0 and main.find_children("*", "HTTPRequest", true, false).is_empty() and _feed.connections == 0
	_check("acceptance: the adapter is off while the real-data opt-in is off (here a demo run's link): an address set, and still no request, no HTTP client, the fake feed never reached; the chip says why", gate_off and Array(hud.chip_lines()).has("real-machine data is off (Esc > Settings > Privacy and AI)") and hud.chip_lines()[0] == "VOICE  off", " | ".join(hud.chip_lines()))
	voice.feed_url = func(): return "http://example.com/lines"
	voice.real_gate = func(): return true
	await _frames(60)
	_check("acceptance: a non-loopback address (a hand-edited settings file) is refused with a plain line, even with the opt-in on: no request made", voice.state() == "refused" and voice.asks == 0 and _feed.connections == 0 and Array(hud.chip_lines()).has(VoiceFeed.REFUSED))
	# The opt-in on (the test's seam) and the address the fake feed's: the adapter asks it.
	voice.feed_url = Callable()
	_feed.rows = [{"id": 1, "media": 0, "text": "Reload!"}, {"id": 2, "media": 0, "text": "said before the game listened " + CANARY}]
	var player = main.get_node("Player")
	var reloads := [0]
	player.reload_started.connect(func(_w): reloads[0] += 1)
	_fired.clear()
	voice.fired.connect(func(id, _o): _fired.append(id))
	var heard_any := await _until(func(): return voice.state() == "listening", 900)
	if not heard_any:
		print("DEBUG state=%s asks=%d conn=%d answered=%d src=%s" % [voice.state(), voice.asks, _feed.connections, _feed.answered, voice.source])
	await _frames(60)
	_check("the opt-in on and a loopback address set: the adapter asks the fake feed (as an HTTP client), and its first answer only learns where the feed stands: what was said before it listened never fires", voice.state() == "listening" and _feed.connections >= 1 and voice.asks >= 1 and _fired.is_empty() and reloads[0] == 0 and hud.chip_lines()[0] == "VOICE  listening" and Array(hud.chip_lines()).has(VoiceHud.LATE), " | ".join(hud.chip_lines()))
	_feed.rows.append_array([
		{"id": 3, "media": 1, "text": "reload, says the TV " + CANARY},
		{"id": 4, "media": 0, "text": "Reload!", "words": 1},
		{"id": 5, "media": 2, "text": "visor"},
		{"id": 6, "media": 0, "text": "Larry, tell the room " + CANARY},
		{"id": 7, "media": 0, "text": "visor."},
		{"id": 8, "media": 0, "text": "pause"},
	])
	await _until(func(): return _fired.size() >= 3)
	await _frames(10)
	var stop = player.sigstop
	_check("acceptance: commands fire from the feed's talk rows only (reload, visor, pause: SIGSTOP on), its TV rows skipped (even one saying reload, and one saying visor), its \"Larry, tell\" row refused", _fired == [&"reload", &"visor", &"pause"] and voice.media_skipped == 2 and voice.refused == 1 and stop.is_on(), "%s, tv %d, refused %d" % [str(_fired), voice.media_skipped, voice.refused])
	var toast: Dictionary = hud.current_toast()
	_check("each command fired is toasted by its name and what came of it (the game's own words), never the line", not toast.is_empty() and VoiceMatch.COMMANDS.has(toast["id"]) and not str(toast["outcome"]).contains(CANARY), str(toast))
	_feed.rows.append({"id": 9, "media": 0, "text": "resume"})
	await _until(func(): return _fired.size() >= 4)
	await _frames(6)
	_check("resume sends SIGCONT: the world back to speed", _fired.back() == &"resume" and not stop.is_on())
	main.get_node("Hud").pause_menu().open()
	await _frames(2)
	var before := _fired.size()
	_feed.rows.append({"id": 10, "media": 0, "text": "visor"})
	await _until(func(): return _fired.size() > before)
	var visor_on_menu: bool = voice.last_outcome == "not while the menu is up"
	main.get_node("Hud").pause_menu().close()
	await _frames(2)
	_check("a command heard while the menu is up does nothing and says so", visor_on_menu, voice.last_outcome)
	var guide_link = main.get_node("Hud").guide().session_link()
	_check("acceptance: nothing goes to the player's AI: no call made while commands were heard (the guide's calls %d)" % (guide_link.calls if guide_link != null else -1), guide_link != null and guide_link.calls == 0)
	# A read begun for one feed, the feed begun again before it lands (an address changed, the demo began): dropped.
	await _until(func(): return voice._task < 0)
	var before_stale := _fired.size()
	voice._read(JSON.stringify([{"id": 500, "media": 0, "text": "visor"}]).to_utf8_buffer())
	voice._reset_feed()
	await _frames(20)
	_check("a read begun for a feed no longer asked about (another address, the demo begun) is dropped: nothing fires and the feed begun again learns afresh, never taking the old feed's place in its lines", _fired.size() == before_stale and voice._last_id < 500, "last id %d" % voice._last_id)
	voice.real_gate = func(): return false
	await _frames(40)
	var asks_then: int = voice.asks
	await _frames(60)
	_check("the opt-in turned off while listening: voice off at once, the HTTP client gone, no more requests", voice.state() == "gate" and voice.asks == asks_then and main.find_children("*", "HTTPRequest", true, false).is_empty())
	voice.real_gate = func(): return true
	await _frames(4)


# --- A feed in trouble: down, hanging, junk, an error, a redirect, too big. ---

func _trouble_checks() -> void:
	var main := current_scene
	var voice := VoiceCommands.of(main)
	var hud = main.get_node("Hud").voice_hud()
	if OS.has_environment("VOICE_TEST_TRACE"):
		print("TRACE trouble start state=%s" % voice.state())
	await _until(func(): return voice.state() == "listening")
	var results := {}
	for mode in ["junk", "error", "redirect", "slam", "big", "hang"]:
		if OS.has_environment("VOICE_TEST_TRACE"):
			print("TRACE mode %s state=%s" % [mode, voice.state()])
		_feed.mode = mode
		_gaps.clear()
		var asked: int = _feed.answered
		var want := "junk" if mode == "junk" or mode == "big" else "down"
		var reached := await _until(func(): return voice.state() == want, 900)
		await _frames(30)
		results[mode] = [reached, _longest_gap(), voice.state(), hud.chip_lines()[0] if not hud.chip_lines().is_empty() else ""]
		_feed.mode = "rows"
		await _until(func(): return voice.state() == "listening", 2400)
		if asked == _feed.answered and mode != "hang":
			results[mode].append("never asked")
	var bad := PackedStringArray()
	var worst := 0.0
	for mode in results:
		var r: Array = results[mode]
		worst = maxf(worst, r[1])
		if not r[0] or r[1] > 250.0 or str(r[3]) != "VOICE  off":
			bad.append("%s %s" % [mode, str(r)])
	_check("acceptance: a feed that answers junk, an error, a redirect, hangs up, sends more than the cap or hangs leaves voice off quietly with the chip saying so, and never stalls a frame (the longest frame %.0f ms)" % worst, bad.is_empty(), ", ".join(bad))
	_check("a redirect is never followed: the adapter asked only its own address (the fake feed's) and treated the redirect as no answer", results.has("redirect") and results["redirect"][2] == "down")
	# Down: nobody listening at all. It backs off, and the frames keep coming.
	_feed.stop()
	_gaps.clear()
	var asks0: int = voice.asks
	await _until(func(): return voice.state() == "down", 600)
	await _frames(600)
	var asks_down: int = voice.asks - asks0
	_check("acceptance: a feed that is down: voice off, the chip says when it tries again, it backs off (%d asks in 10 s of game time, not one every %.2f s), and no frame stalls (the longest %.0f ms)" % [asks_down, VoiceCommands.POLL_S, _longest_gap()], voice.state() == "down" and asks_down <= 4 and _longest_gap() < 250.0 and str(hud.chip_lines()[1]).begins_with("feed not answering, trying again in"), " | ".join(hud.chip_lines()))
	_feed = FakeFeed.new()
	if not _feed.start():
		_check("the test's fake feed listens again", false)


func _longest_gap() -> float:
	var worst := 0.0
	for g in _gaps:
		worst = maxf(worst, g)
	return worst


# --- Your AI's cover drone. ---

func _cover_checks() -> void:
	GameSettings.current().set_value("voice", "feed_url", "")
	GameSettings.current().set_value("gameplay", "practice", true)
	VoiceCommands.cover_wait = 0.0
	var main := await _arena()
	var voice := VoiceCommands.of(main)
	var hud = main.get_node("Hud").voice_hud()
	var player = main.get_node("Player")
	var dummy: Node3D = null
	for t in main.get_tree().get_nodes_in_group("targets"):
		if main.is_ancestor_of(t) and t.has_method("is_alive") and t.is_alive():
			dummy = t
			break
	# The player a few metres from a daemon, facing it, nothing between them.
	var at: Vector3 = dummy.global_position + Vector3(0, 0, 5.0)
	player.global_position = Vector3(at.x, player.global_position.y, at.z)
	player.velocity = Vector3.ZERO
	await _frames(4)
	var streak_before: int = player.sudo.state.streak
	await _key(KEY_P)
	await _frames(4)
	var drone: CoverDrone = voice.drone
	_check("acceptance: the cover key (P) sends your AI's cover drone out, high on the player's right, its tag counting down", drone != null and is_instance_valid(drone) and drone.global_position.distance_to(player.eye_position()) < 3.5)
	# Watched through the adapter, never a capture of the drone itself (it frees itself as it leaves).
	var locked := await _until(func(): return voice.drone != null and voice.drone.target() != null, 120)
	await _until(func(): return voice.drone == null or voice.drone.shots >= 1, 240)
	var shots: int = voice.drone.shots if voice.drone != null else -1
	_check("acceptance: it covers: locks on to a daemon it can see (a sight line from its lens), then fires on it (%d shot, the daemon hit)" % shots, locked and shots >= 1 and (not dummy.is_alive() or dummy.health() < dummy.max_health))
	_check("its kill is your AI's: on the screen, but no sudo streak and no feat toward an unlock", player.sudo.state.streak == streak_before and dummy.get("killed_with") in ["cover", ""])
	_check("the HUD shows it while it is out: \"P  cover me\" and its seconds", hud.cover_line().begins_with(VoiceHud.COVER))
	await _until(func(): return voice.drone == null, 1200)
	await _frames(4)
	var again: String = voice.cover_me(true)
	_check("after %d s it folds and leaves, and recharges (%d s): a call meanwhile is refused and says when" % [int(CoverDrone.COVER_S), int(VoiceCommands.COVER_COOL_S)], not is_instance_valid(drone) and voice.drone == null and VoiceCommands.cover_wait > 30.0 and again.begins_with("recharging") and hud.cover_line().contains("recharging"), again)
	# Where abilities are gated (a mission, co-op), the key does nothing.
	VoiceCommands.cover_wait = 0.0
	player.set_abilities(PackedStringArray(), true)
	await _key(KEY_P)
	await _frames(4)
	var gated := voice.drone == null and voice.cover_me(true) == "locked here"
	player.set_abilities(PackedStringArray(), false)
	_check("where the player's abilities are gated (a mission's, co-op's) the cover key and the voice both do nothing", gated)
	GameSettings.current().set_value("gameplay", "practice", false)


# --- The demo. ---

func _demo_checks() -> void:
	VoiceCommands.cover_wait = 0.0
	VoiceDemo.queue()
	var main := await _arena()
	var voice := VoiceCommands.of(main)
	var hud = main.get_node("Hud").voice_hud()
	await _until(func(): return voice.demo and voice.state() == "listening")
	_check("acceptance: the demo (Esc's \"Voice commands\", or --voice) runs the arena with the made-up feed: listening at once, its own words on the chip, and no HTTP client and no request", voice.source == "demo" and voice.asks == 0 and main.find_children("*", "HTTPRequest", true, false).is_empty() and hud.chip_lines()[0] == "VOICE  listening" and hud._state().get("source") == "demo feed")
	_fired.clear()
	voice.fired.connect(func(id, _o): _fired.append(id))
	var toasts := []
	var drones := [false]
	# Through the script's loop, a line at a time: the demo's clock moved on to each line as it arrives.
	var guard := 0
	while guard < 40:
		guard += 1
		var next := VoiceDemo.next_after(voice._demo_t)
		if next >= VoiceDemo.LOOP_S:
			break
		voice._demo_t = next + 0.01
		await _frames(int(VoiceCommands.POLL_S * 60.0) + 8)
		if not hud.current_toast().is_empty():
			toasts.append(hud.current_toast()["id"])
		if voice.drone != null:
			drones[0] = true
	_check("acceptance: every scripted command fires in order (reload, cover me, drop a breaker, visor, pause, resume, a misheard visor, reload), the TV's lines skipped (3), the \"Larry, tell\" line refused (1)", _fired == [&"reload", &"cover", &"breaker", &"visor", &"pause", &"resume", &"visor", &"reload"] and voice.media_skipped == 3 and voice.refused == 1 and voice.heard == 12, "%s tv %d refused %d heard %d" % [str(_fired), voice.media_skipped, voice.refused, voice.heard])
	_check("the HUD: a toast for each (%d seen), the drone out after cover me, the chip's counts (lines heard, the TV's skipped, refused) and never a word of a line" % toasts.size(), toasts.size() >= 6 and drones[0] and str(hud.chip_lines()[2]).begins_with("heard 12"))
	VoiceDemo.clear()


# --- The menu and the settings. ---

func _menu_checks() -> void:
	var main := await _arena()
	var menu = main.get_node("Hud").pause_menu()
	menu.open()
	await _frames(2)
	var b: Button = menu.voice_button()
	var plain_ok: bool = b != null and b.text == "Voice commands" and not b.disabled and b.is_visible_in_tree() and b.tooltip_text.contains("never opens a microphone")
	menu.open_settings()
	await _frames(2)
	var box: LineEdit = menu.voice_feed_box()
	var hint := box.placeholder_text if box != null else ""
	var digits := false
	for c in hint:
		if c >= "0" and c <= "9":
			digits = true
	var box_ok: bool = box != null and box.text == "" and box.is_visible_in_tree() and hint == "point it at your transcript feed" and not digits and not hint.contains("/") and not hint.contains(":")
	_check("acceptance: Settings (Privacy and AI) has the voice feed: empty by default, its hint generic (\"point it at your transcript feed\", no address, port or path of any program)", box_ok, hint)
	menu._set_voice_feed("http://example.com/lines")
	var refused_line: String = menu.status_text()
	menu._set_voice_feed("")
	_check("a non-loopback address typed there is refused with a plain line, and the setting stays empty", refused_line == VoiceFeed.REFUSED and GameSettings.current().value("voice", "feed_url") == "", refused_line)
	menu.close()
	await _frames(2)
	CoopHunt.queued = true
	PacketTracer.queued = true
	menu.toggle_voice()
	var one: bool = VoiceDemo.queued and not CoopHunt.queued and not PacketTracer.queued
	var old_id := main.get_instance_id()
	main = await _after_reload(old_id)
	var voice := VoiceCommands.of(main)
	await _until(func(): return voice.demo)
	menu = main.get_node("Hud").pause_menu()
	menu.open()
	await _frames(2)
	var leave_ok: bool = menu.voice_button().text == "Leave voice commands"
	menu.close()
	menu.toggle_coop()
	var cleared: bool = not VoiceDemo.queued and CoopHunt.queued
	CoopHunt.clear()
	old_id = main.get_instance_id()
	main = await _after_reload(old_id)
	await _frames(10)
	_check("acceptance: the Esc menu reaches the demo: \"Voice commands\" in the free arena, \"Leave voice commands\" while it runs; one world mode at a time (co-op and the packet tracer end as it begins, and co-op's entry ends it)", plain_ok and one and leave_ok and cleared)
	# Co-op: voice off (one voice, two players).
	var fake := GDScript.new()
	fake.source_code = "extends Node\nvar running := true\n"
	fake.reload()
	var coop_node := Node.new()
	coop_node.set_script(fake)
	VoiceDemo.queue()
	main = await _arena()
	voice = VoiceCommands.of(main)
	await _until(func(): return voice.state() == "listening")
	var was_coop = voice.coop
	voice.coop = coop_node
	await _frames(40)
	_check("voice listens alone only: in co-op it is off (one voice, two players), and the demo's feed stops", voice.state() == "off" and voice.source == "")
	voice.coop = was_coop
	coop_node.free()
	VoiceDemo.clear()


# --- The canary, everywhere. ---

func _canary_checks() -> void:
	var labels := PackedStringArray()
	var props := PackedStringArray()
	for node in root.find_children("*", "", true, false):
		for key in ["text", "placeholder_text", "tooltip_text"]:
			var v = node.get(key)
			if v is String and (v as String).contains(CANARY):
				labels.append(str(node.get_path()))
		for p in node.get_property_list():
			if not (int(p["usage"]) & PROPERTY_USAGE_SCRIPT_VARIABLE):
				continue
			var t := int(p["type"])
			if t in [TYPE_STRING, TYPE_STRING_NAME, TYPE_PACKED_STRING_ARRAY, TYPE_ARRAY, TYPE_DICTIONARY, TYPE_PACKED_BYTE_ARRAY]:
				var v = node.get(p["name"])
				var text := (v as PackedByteArray).get_string_from_utf8() if v is PackedByteArray else str(v)
				if text.contains(CANARY):
					props.append("%s.%s" % [node.name, p["name"]])
	var voice := VoiceCommands.of(current_scene)
	var hud = current_scene.get_node("Hud").voice_hud()
	var drawn: String = " ".join(hud.chip_lines()) + hud.cover_line() + str(hud.current_toast())
	_check("acceptance (privacy): the canary phrase the fake feed sent is on no label, box or tooltip, in no node's own property (%d nodes), nowhere the voice HUD draws, and not kept by the adapter" % root.find_children("*", "", true, false).size(), labels.is_empty() and props.is_empty() and not drawn.contains(CANARY) and (voice == null or str(voice._task_result).find(CANARY) < 0), ", ".join(labels + props))
	var files := _canary_in_user("user://")
	_check("acceptance (privacy): nothing under user:// holds the canary (every file read, the game's logs included)", files.is_empty(), ", ".join(files))
	_check("acceptance (privacy): no print or log line of this run holds it (%d lines seen by a logger of the test's own; check.sh searches the whole output too)" % _log.lines, _log.hits == 0 and _log.lines > 20)


func _canary_in_user(path: String) -> PackedStringArray:
	var out := PackedStringArray()
	var dir := DirAccess.open(path)
	if dir == null:
		return out
	dir.include_hidden = true
	dir.list_dir_begin()
	var name := dir.get_next()
	while name != "":
		var full := path.path_join(name)
		if dir.current_is_dir():
			if not dir.is_link(name):
				out.append_array(_canary_in_user(full))
		else:
			var f := FileAccess.open(full, FileAccess.READ)
			if f != null and f.get_length() < 32 * 1024 * 1024:
				if f.get_buffer(f.get_length()).get_string_from_ascii().contains(CANARY):
					out.append(full)
			if f != null:
				f.close()
		name = dir.get_next()
	dir.list_dir_end()
	return out


# --- The arena. ---

func _arena() -> Node:
	MissionRunner.clear_pending()
	for old in root.get_children():
		if old.scene_file_path == "res://scenes/main.tscn":
			await _drop(old)
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
	await _frames(2)
	return main


func _cleanup() -> void:
	_feed.stop()
	MissionRunner.clear_pending()
	_clear_modes()
	for node in root.get_children():
		if node.scene_file_path == "res://scenes/main.tscn":
			await _drop(node)
	current_scene = null
	AuditVisor.remembered = false
	VoiceCommands.cover_wait = 0.0
	GameSettings.current().reset()
	MissionProgress.current().path = ""
	MissionProgress.current().clear()
	Progress.current().path = ""
	Progress.current().clear()
	_wipe(_abs)
	_check("the test's own folder is gone, nothing of it left under user://", not DirAccess.dir_exists_absolute(_abs))


## The test's own folder only, file by file.
func _wipe(path: String) -> void:
	if not path.begins_with(ProjectSettings.globalize_path("user://voice-test-")):
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


## A frame at a time, the fake feed served and each frame's wall time kept (a stalled frame would show here).
func _frames(n: int) -> void:
	for i in n:
		_feed.step()
		var t0 := Time.get_ticks_usec()
		await process_frame
		_gaps.append(float(Time.get_ticks_usec() - t0) / 1000.0)
		if _gaps.size() > 4000:
			_gaps = _gaps.slice(2000)


func _until(condition: Callable, most: int = MOST_FRAMES) -> bool:
	var frames := 0
	while frames < most and not condition.call():
		await _frames(1)
		frames += 1
		if frames % 120 == 0 and OS.has_environment("VOICE_TEST_TRACE"):
			print("TRACE frame %d at %d ms" % [frames, Time.get_ticks_msec()])
	return condition.call()


func _key(code: Key) -> void:
	var down := InputEventKey.new()
	down.keycode = code
	down.physical_keycode = code
	down.pressed = true
	Input.parse_input_event(down)
	await process_frame
	var up := down.duplicate() as InputEventKey
	up.pressed = false
	Input.parse_input_event(up)
