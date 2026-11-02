class_name VoiceCommands
extends Node
## Voice commands (W7, PRD 5.5; the seventh of M5's world features): the player calls out "reload" or "Larry, cover me"
## in the room, a transcript program they already run turns it into a line of text, and the game acts on that line.
## The game never opens a microphone, never captures audio and links no speech library: it only reads lines another
## program already wrote, through VoiceFeed (scripts/voice/voice_feed.gd), and only ever as a client.
##
## Two sources, one reading:
## - the demo feed (scripts/voice/voice_demo.gd), when the voice demo runs (Esc, "Voice commands", or --voice on a demo
##   or test run): made-up lines scripted in-process, no program, file or socket;
## - the player's own feed, only with all three of their yeses: an address in Settings (Privacy and AI, "voice feed",
##   empty by default), http on the loopback only (VoiceFeed.check), and the real-data opt-in on (the same answer the
##   opener, the visor and W1 to W4 use: AuditVisor.real_gate_for; never on a demo run). Without all three no request is
##   ever made: no HTTPRequest exists.
## It listens alone (the free arena, its world modes, a mission), never in a match or in co-op (one voice, two players).
##
## The feed's address is asked about every POLL_S (non-blocking: HTTPRequest's sockets never wait; a request given up
## after TIMEOUT_S of wall-clock time, whatever SIGSTOP does to the game's clock; no redirects; a capped body), and each
## answer is read off the main thread (WorkerThreadPool): only numbers and command ids come back. HTTPRequest's own
## thread is not used: cancelling a request it holds joins that thread, and a feed that hangs mid-answer could hold the
## frame on it. A feed that is down, slow or answers junk leaves voice off, quietly: the chip says so and when it tries
## again (backing off from BACKOFF_FIRST to BACKOFF_LAST), and nothing waits on it. Only the newest id seen is kept.
## No line's text is ever kept, printed, logged, shown, written, or sent to the player's AI or the announcer: the HUD
## shows a command's name and what came of it, nothing else.
##
## The commands (VoiceMatch.COMMANDS), each with a key that does the same with no voice: cover me (P, your AI's cover
## drone, scripts/voice/cover_drone.gd), drop a breaker (U), reload (E), visor (I), pause (F: SIGSTOP, the game's own
## pause, since the menu pauses nothing) and resume (F again: SIGCONT). A command spoken while the menu is up, while the
## player is derezzed, or in a place its key would be refused (a mission's gated abilities) does nothing, and says so.

const Palette = preload("res://scripts/palette.gd")
const VoiceFeed = preload("res://scripts/voice/voice_feed.gd")
const VoiceMatch = preload("res://scripts/voice/voice_match.gd")
const VoiceSound = preload("res://scripts/voice/voice_sound.gd")
const Kinds = preload("res://scripts/ice/breakers.gd")

const NODE_NAME := "VoiceCommands"
const GROUP := &"voice_commands"
## Seconds: between asks while the feed answers, a request's timeout, the backoff's first and last wait.
const POLL_S := 0.75
const TIMEOUT_S := 1.0
const BACKOFF_FIRST := 2.0
const BACKOFF_LAST := 30.0
## Seconds between looks at the settings and the opt-in.
const GATE_S := 0.5
## The cover drone's recharge, seconds from when it leaves.
const COVER_COOL_S := 40.0

## The settings' section and key of the address.
const SECTION := "voice"
const KEY := "feed_url"

signal fired(id: StringName, outcome: String)

## The cover drone's recharge left (the run's, so an arena reload keeps it).
static var cover_wait := 0.0

var player: Node3D = null
var visor: Node = null
var breakers: Node = null
var guide: Node = null
var session: Node = null
var coop: Node = null
var hud: Node = null
## Test seams: the real-data opt-in's answer and the address (unset: the game's own).
var real_gate := Callable()
var feed_url := Callable()

## The demo feed running here (the voice demo).
var demo := false
## "" (no feed), "demo" or "real": where lines come from now.
var source := ""
## How many requests have been made (the checks: none without an address and the opt-in).
var asks := 0
## Lines read since listening began: talk, the TV's skipped, refused ("Larry, tell"); commands fired.
var heard := 0
var media_skipped := 0
var refused := 0
var commands := 0
var drone: CoverDrone = null
var last_outcome := ""

var _state := "off"
var _why := ""
var _listening := false
var _learned := false
var _last_id := -1
var _fails := 0
var _wait := 0.0
var _gate_t := 0.0
var _busy := false
var _http: HTTPRequest = null
var _http_url := ""
var _asked_at := 0
var _task := -1
var _task_result := {}
## Bumped every time the feed is begun again: a read begun for an earlier feed (another address, the demo) is dropped.
var _gen := 0
var _task_gen := 0
var _demo_t := 0.0
var _sfx: AudioStreamPlayer = null


static func of(node: Node) -> VoiceCommands:
	if node == null or not node.is_inside_tree():
		return null
	for v in node.get_tree().get_nodes_in_group(GROUP):
		if not v.is_queued_for_deletion():
			return v as VoiceCommands
	return null


func _ready() -> void:
	name = NODE_NAME
	add_to_group(GROUP)
	_sfx = AudioStreamPlayer.new()
	_sfx.name = "VoiceSound"
	_sfx.bus = &"Effects" if AudioServer.get_bus_index(&"Effects") >= 0 else &"Master"
	_sfx.max_polyphony = 2
	add_child(_sfx)
	if player != null and is_instance_valid(player) and player.has_signal("cover_pressed"):
		player.cover_pressed.connect(func(): cover_me(false))
	_configure()


func _exit_tree() -> void:
	_drop_http()
	if _task >= 0:
		WorkerThreadPool.wait_for_task_completion(_task)
		_task = -1
	_task_result = {}


## The voice demo begins here: the demo feed in place of the player's own.
func begin_demo() -> void:
	demo = true
	VoiceDemo.queue()
	_reset_feed()
	_demo_t = 0.0
	_configure()


func end_demo() -> void:
	demo = false
	_reset_feed()
	_configure()


# --- What the HUD shows. ---

func hud_state() -> Dictionary:
	var out := {
		"shown": false, "listening": _listening, "warn": false, "word": "", "source": "", "line": "", "counts": "",
		"cover_left": drone.left_s() if drone != null and is_instance_valid(drone) else 0.0,
		"cover_wait": cover_wait if drone == null or not is_instance_valid(drone) else 0.0,
		"cover_s": CoverDrone.COVER_S, "cover_cool": COVER_COOL_S,
	}
	if _state == "off":
		return out
	out["shown"] = true
	out["source"] = "demo feed" if source == "demo" else ("your feed" if source == "real" else "")
	match _state:
		"listening":
			out["word"] = "listening"
			out["line"] = VoiceHud.LATE
			if heard + media_skipped + refused > 0:
				out["counts"] = "heard %d   tv skipped %d   refused %d" % [heard, media_skipped, refused]
		"connecting":
			out["word"] = "connecting"
			out["line"] = "asking the feed"
		"down":
			out["word"] = "off"
			out["warn"] = true
			out["line"] = "feed not answering, trying again in %ds" % ceili(maxf(_wait, 0.0))
		"junk":
			out["word"] = "off"
			out["warn"] = true
			out["line"] = "feed answer unreadable (%s), trying again in %ds" % [_why, ceili(maxf(_wait, 0.0))]
		"refused":
			out["word"] = "off"
			out["warn"] = true
			out["line"] = _why
		"gate":
			out["word"] = "off"
			out["warn"] = true
			out["line"] = "real-machine data is off (Esc > Settings > Privacy and AI)"
	return out


## The chip's word now (the checks): "off", "listening", "connecting", "down", "junk", "refused" or "gate".
func state() -> String:
	return _state


# --- The feed. ---

func _url() -> String:
	if feed_url.is_valid():
		return str(feed_url.call())
	var v = GameSettings.current().value(SECTION, KEY)
	return v if v is String else ""


func _gate() -> bool:
	if real_gate.is_valid():
		return bool(real_gate.call())
	var link = guide.session_link() if guide != null and is_instance_valid(guide) and guide.has_method("session_link") else null
	return AuditVisor.real_gate_for(link)


func _alone() -> bool:
	if session != null and is_instance_valid(session) and session.has_method("is_online") and session.is_online():
		return false
	if coop != null and is_instance_valid(coop) and coop.get("running") == true:
		return false
	return true


## Where lines come from now, from the settings, the opt-in and where the player is.
func _configure() -> void:
	if not _alone():
		_set_source("")
		_set_state("off")
		return
	if demo:
		_set_source("demo")
		if _state == "off" or _state == "gate" or _state == "refused":
			_set_state("connecting")
		return
	var url := _url()
	if url == "":
		_set_source("")
		_set_state("off")
		return
	var checked := VoiceFeed.check(url)
	if not checked["ok"]:
		_set_source("")
		_why = str(checked["why"])
		_set_state("refused")
		return
	if not _gate():
		_set_source("")
		_set_state("gate")
		return
	if _http_url != str(checked["url"]):
		_reset_feed()
		_http_url = str(checked["url"])
	_set_source("real")
	if _state == "off" or _state == "gate" or _state == "refused":
		_set_state("connecting")


func _set_source(next: String) -> void:
	if next == source:
		return
	source = next
	_reset_feed()
	if next != "real":
		_drop_http()
		_http_url = ""


func _set_state(next: String) -> void:
	if next == _state:
		return
	var was := _state
	_state = next
	_listening = next == "listening"
	if next == "listening" and was != "listening":
		_play("found")
	elif was == "listening" and (next == "down" or next == "junk"):
		_play("lost")


func _reset_feed() -> void:
	_gen += 1
	_learned = false
	_last_id = -1
	_fails = 0
	_wait = 0.0
	_busy = false
	heard = 0
	media_skipped = 0
	refused = 0
	if _http != null and is_instance_valid(_http):
		_http.cancel_request()


func _drop_http() -> void:
	if _http != null and is_instance_valid(_http):
		_http.cancel_request()
		_http.queue_free()
	_http = null
	_busy = false


func _make_http() -> void:
	_http = HTTPRequest.new()
	_http.name = "VoiceFeedRequest"
	_http.timeout = 0.0  # the wall-clock timeout below; HTTPRequest's own counts game frames
	_http.max_redirects = 0
	_http.body_size_limit = VoiceFeed.BODY_LAST
	_http.use_threads = false
	_http.accept_gzip = false
	_http.request_completed.connect(_on_answer.bind(_http))
	add_child(_http)


func _process(delta: float) -> void:
	var real := delta / maxf(Engine.time_scale, 0.001)  # SIGSTOP slows the clock, never the feed
	if drone == null or not is_instance_valid(drone):
		cover_wait = maxf(cover_wait - real, 0.0)
	_gate_t -= real
	if _gate_t <= 0.0:
		_gate_t = GATE_S
		_configure()
	if _task >= 0:
		if WorkerThreadPool.is_task_completed(_task):
			WorkerThreadPool.wait_for_task_completion(_task)
			_task = -1
			var r := _task_result
			_task_result = {}
			if _task_gen == _gen:
				_apply(r)
			else:
				_busy = false  # read for a feed no longer asked about
		return
	if source == "":
		return
	if source == "demo":
		_demo_t += real
	if _busy and source == "real" and Time.get_ticks_msec() - _asked_at > int(TIMEOUT_S * 1000.0):
		if _http != null and is_instance_valid(_http):
			_http.cancel_request()
		_fail("down", "")
		return
	_wait -= real
	if _busy or _wait > 0.0:
		return
	if source == "demo":
		_read(VoiceDemo.answer(_demo_t))
	else:
		_poll_feed()


func _poll_feed() -> void:
	if _http == null or not is_instance_valid(_http):
		_make_http()
	var err := _http.request(_http_url, PackedStringArray(["Accept: application/json"]), HTTPClient.METHOD_GET)
	asks += 1
	if err != OK:
		_fail("down", "")
		return
	_busy = true
	_asked_at = Time.get_ticks_msec()


func _on_answer(result: int, code: int, _headers: PackedStringArray, body: PackedByteArray, from: HTTPRequest) -> void:
	if from != _http or source != "real":
		return  # an answer to a feed no longer asked about
	_busy = false
	if result == HTTPRequest.RESULT_BODY_SIZE_LIMIT_EXCEEDED:
		_fail("junk", "too big")
	elif result != HTTPRequest.RESULT_SUCCESS:
		_fail("down", "")
	elif code != 200:
		_fail("down", "")
	else:
		_read(body)


## One answer handed to a worker thread to read; the main thread only ever sees what it returns.
func _read(body: PackedByteArray) -> void:
	_busy = true
	var last := _last_id
	var learn := not _learned
	_task_gen = _gen
	_task = WorkerThreadPool.add_task(func(): _task_result = VoiceFeed.digest(body, last, learn), false, "voice feed")


func _apply(r: Dictionary) -> void:
	_busy = false
	if source == "":
		return
	if not r.get("ok", false):
		_fail("junk", str(r.get("why", "")))
		return
	_fails = 0
	_wait = POLL_S
	_learned = true
	_last_id = int(r.get("last_id", _last_id))
	_set_state("listening")
	heard += int(r.get("talk", 0))
	media_skipped += int(r.get("media", 0))
	refused += int(r.get("blocked", 0))
	var ids: Array = r.get("commands", [])
	for id in ids:
		_heard_command(id)


func _fail(kind: String, why: String) -> void:
	_busy = false
	_fails += 1
	_wait = minf(BACKOFF_FIRST * pow(2.0, float(_fails - 1)), BACKOFF_LAST)
	_why = why
	_set_state(kind)


# --- The commands. ---

## A command heard on the feed: acted on where its key would be, toasted with what came of it.
func _heard_command(id: StringName) -> void:
	if not VoiceMatch.COMMANDS.has(id):
		return
	var outcome := run(id)
	commands += 1
	last_outcome = outcome
	_play("heard")
	if hud != null and is_instance_valid(hud) and hud.has_method("toast"):
		hud.toast(id, outcome)
	fired.emit(id, outcome)


## Runs command `id` as its key would; returns the game's own words for what came of it.
func run(id: StringName) -> String:
	if player == null or not is_instance_valid(player):
		return "not now"
	if player.get("input_blocked") == true:
		return "not while the menu is up"
	if player.get("alive") == false:
		return "not while derezzed"
	if player.has_method("frozen_now") and player.frozen_now():
		return "read-only: chmod 000 holds you"
	match id:
		&"cover":
			return cover_me(true)
		&"breaker":
			if not _ability("breakers") or breakers == null or not is_instance_valid(breakers):
				return "locked here"
			var mine = breakers.get("mine")
			if mine == null or mine.count(mine.loaded) <= 0:
				return "no breaker loaded (pick one up)"
			breakers.press_run()
			return "running %s" % Kinds.name_of(mine.loaded)
		&"reload":
			return "reloading" if player.reload_weapon() else "nothing to reload"
		&"visor":
			if visor == null or not is_instance_valid(visor):
				return "no visor here"
			visor.toggle()
			return "visor on" if visor.get("on") == true else "visor off"
		&"pause":
			if not _ability("sigstop"):
				return "locked here"
			var stop = player.get("sigstop")
			if stop == null:
				return "not now"
			if stop.is_on():
				return "already stopped"
			if not stop.can_start():
				return "SIGSTOP meter too low"
			stop.press()
			return "SIGSTOP: the world slows"
		&"resume":
			var stop = player.get("sigstop")
			if stop == null or not stop.is_on():
				return "nothing stopped"
			stop.press()
			return "SIGCONT: back to speed"
	return "not now"


func _ability(id: String) -> bool:
	return not player.has_method("ability_ok") or player.ability_ok(id)


## Your AI's cover drone, out over the player's shoulder: by voice, or the cover key (P). The game's words for what came
## of it.
func cover_me(by_voice: bool) -> String:
	if player == null or not is_instance_valid(player) or not _alone():
		return "not now"
	if by_voice and not _ability("cover"):
		return "locked here"  # the key's own gate (the player's _ability_pressed) says no for the key
	if drone != null and is_instance_valid(drone):
		return "already covering, %ds left" % ceili(drone.left_s())
	if cover_wait > 0.0:
		return "recharging, %ds" % ceili(cover_wait)
	var host := get_parent() if get_parent() != null else self
	drone = CoverDrone.new()
	drone.player = player
	drone.left.connect(_on_drone_left.bind(drone))
	host.add_child(drone)
	return "drone out, %ds" % int(CoverDrone.COVER_S)


func _on_drone_left(which: CoverDrone) -> void:
	if which == drone:
		drone = null
		cover_wait = COVER_COOL_S


func _play(id: String) -> void:
	if _sfx == null or DisplayServer.get_name() == "headless":
		return
	_sfx.stream = VoiceSound.of(id)
	_sfx.play()
