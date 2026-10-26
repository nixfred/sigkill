extends RefCounted
## The game's one link to the player's AI for a whole session (PRD 5.4): the C9 detector,
## the C9b adapter the registry picks, the player's opt-in, the AI switch, the last call's
## numbers and a GPU readout. The boot screen (C10) makes it and hands it on to the arena,
## whose guide HUD (C11) keeps it; when R reloads the arena the HUD parks it and the new
## HUD takes it back, so one session has one adapter, one pace and one count of calls.
## A scene that finds none parked (the arena loaded on its own, as in tests) makes its own.
##
## Never blocks the main thread: the detector runs on its own worker, the adapter is chosen
## by an AdapterJob on a worker (the registry looks the agent's command up along the
## PATH), each GPU reading runs on a short worker thread, and a call is polled. poll() moves
## everything on once a frame.
##
## Headless guard (hard rule): in any headless run, or with the user argument --no-ai, no
## real detector is ever made and the C9b registry is never asked, whatever was saved, so
## no agent is launched and no model server is contacted. Only a detector and an adapter
## factory a test hands in are used.
##
## Demo-data mode (--demo): a fake agent "claude" and fake GPU numbers; no detector, no
## settings file, no adapter, no process, no network. Owners show their own canned answers.
##
## The AI is called only with the player's yes for that source (scripts/boot/
## guide_settings.gd keeps it in user://settings.cfg), and the guide tuning's ai_enabled
## switch is set only on this link's own copy, in ask(), right before the one call.

const Settings = preload("res://scripts/boot/guide_settings.gd")
const Detector = preload("res://scripts/ai/ai_source_detector.gd")
const Found = preload("res://scripts/ai/ai_source_result.gd")
const GuideTuningScript = preload("res://scripts/guide_tuning.gd")

const GUIDE_TUNING_PATH := "res://resources/guide.tres"
const GPU_INTERVAL_FIRST_MS := 1000
const ERROR_WORD_MAX := 24

const DEMO_AGENT := "claude"
const DEMO_GPU := {"available": true, "source": "demo", "util_percent": 41, "vram_used_mib": 3072, "vram_total_mib": 8192, "temp_c": 58}
const DEMO_UTIL_SWING := 7

enum State { STARTING, DETECTING, CHOOSING, READY }

## The link a scene left for the next one.
static var _parked = null

# Set these before start(); the defaults are the real ones.
## An AiSourceDetector, or a test fake with its start, is_done, wait, cancel and poll_gpu.
## Null: a real one, except under the headless guard. Untyped on purpose, so a fake fits.
var detector = null
## (found, detector, guide tuning) -> adapter or null. Empty: the C9b registry, except
## under the headless guard, where an empty factory means no adapter at all.
var adapter_factory := Callable()
## Where the opt-in answer is kept.
var settings_path := Settings.DEFAULT_PATH
## Demo-data mode; --demo on the command line also turns it on.
var demo := false
## Time between two GPU readings; never under GPU_INTERVAL_FIRST_MS.
var gpu_interval_ms := GPU_INTERVAL_FIRST_MS

## What the detector found, once it has: null when there was nothing to ask (the headless
## guard with no detector, or a detector that gave no answer).
var found: Found
## The adapter the registry (or a test's factory) chose, or null.
var adapter = null
## This link's own copy of the guide tuning. Its ai_enabled switch starts off.
var guide_tuning: Resource
## Why there is no AI link, in a few words, when there is none.
var skip_reason := ""
## True if the adapter worker could not start: no adapter, never a lookup on the main thread.
var choose_failed := false
## The last real call's numbers: {ok, error_kind, latency_ms, tokens_per_sec}. Never its text.
var last_call := {}
## Calls this session that reached the adapter.
var calls := 0
## True once a local server said it has nothing loaded, until a later call is answered:
## "available, not loaded". Nothing is ever loaded.
var not_loaded := false
## GPU readings started this session.
var gpu_reads := 0

var _guarded := false
var _state: State = State.STARTING
var _job: AdapterJob
var _adapter_thread: Thread
var _gpu_thread: Thread
var _gpu_reading := {}
var _gpu_wait_ms := 0.0
var _demo_ticks := 0
var _demo_on := true
## The opt-in answer for the adapter, read from the settings file once and kept in step
## with set_consent(), so a caller asking every frame never touches the disk.
var _consent_known := false
var _consent: Settings.Answer = Settings.Answer.NOT_ASKED


func _init() -> void:
	var shipped = load(GUIDE_TUNING_PATH)
	guide_tuning = shipped.duplicate() if shipped is GuideTuningScript else GuideTuningScript.new()
	guide_tuning.ai_enabled = false


## Leaves this link for the next scene to take.
static func park(link) -> void:
	_parked = link


## The link a scene left, or null; either way the slot is empty afterwards.
static func take_parked():
	var link = _parked
	_parked = null
	return link


## Starts detection (or demo data). Once only.
func start() -> void:
	if _state != State.STARTING:
		return
	var args := OS.get_cmdline_user_args()
	demo = demo or args.has("--demo")
	var headless := DisplayServer.get_name() == "headless"
	_guarded = headless or args.has("--no-ai")
	skip_reason = ("headless run" if headless else "--no-ai") if _guarded else "the detector gave no answer"
	if demo:
		found = demo_found()
		_gpu_reading = DEMO_GPU.duplicate()
		_state = State.READY
		return
	if detector == null and not _guarded:
		detector = Detector.new()
	if detector != null and detector.start() != OK:
		detector = null
		skip_reason = "detection could not start"
	_state = State.DETECTING


func is_guarded() -> bool:
	return _guarded


## True when the headless guard is on and nothing was handed in: nothing can ever link.
func is_inert() -> bool:
	return _guarded and not demo and detector == null and adapter_factory.is_null()


func is_detecting() -> bool:
	return _state == State.DETECTING


func is_choosing() -> bool:
	return _state == State.CHOOSING


func is_ready() -> bool:
	return _state == State.READY


## Moves detection, the adapter choice and the GPU readout on. Call once a frame.
func poll(delta_ms: float) -> void:
	match _state:
		State.DETECTING:
			if detector == null:
				found = null
				_state = State.READY
			elif detector.is_done():
				found = detector.wait()
				if found != null:
					_gpu_reading = reading_of(found)
				_choose()
		State.CHOOSING:
			_poll_choosing()
	_tick_gpu(delta_ms)


func _choose() -> void:
	if found == null:
		_state = State.READY
		return
	_job = AdapterJob.new()
	_job.factory = adapter_factory
	_job.found = found
	_job.detector = detector
	_job.tuning = guide_tuning
	_job.guarded = _guarded
	_adapter_thread = Thread.new()
	_state = State.CHOOSING
	if _adapter_thread.start(_job.run) != OK:
		# Never on the main thread: no worker means no adapter.
		_adapter_thread = null
		_job = null
		choose_failed = true
		skip_reason = "no worker thread"
		_state = State.READY


func _poll_choosing() -> void:
	if _adapter_thread == null:
		_choose()  # the last choice was handed off unfinished: choose again
		return
	if _adapter_thread.is_alive():
		return
	_adapter_thread.wait_to_finish()
	_adapter_thread = null
	adapter = _job.adapter
	_job = null
	_state = State.READY


## The opt-in answer for this link's adapter.
func consent() -> Settings.Answer:
	if demo:
		return Settings.Answer.ALLOWED if _demo_on else Settings.Answer.DECLINED
	if adapter == null:
		return Settings.Answer.NOT_ASKED
	if not _consent_known:
		_consent = Settings.answer_for(adapter.source_name(), settings_path)
		_consent_known = true
	return _consent


## True when a call may be made: an adapter and the player's yes for it (demo: its switch).
func ai_on() -> bool:
	return consent() == Settings.Answer.ALLOWED and (demo or adapter != null)


## Saves the player's answer for this link's adapter. Off also stops a call in flight and
## turns the switch off. False if it could not be saved (demo saves nothing, and is true).
func set_consent(allowed: bool) -> bool:
	if demo:
		_demo_on = allowed
		return true
	if adapter == null:
		return false
	if not allowed:
		cancel_call()
		guide_tuning.ai_enabled = false
	# The answer counts for this session even if it cannot be saved; then it is asked again
	# next time.
	_consent = Settings.Answer.ALLOWED if allowed else Settings.Answer.DECLINED
	_consent_known = true
	return Settings.save(adapter.source_name(), allowed, settings_path)


## The adapter's name for the screen: an agent name from the detector's known list,
## "local" for a local server, or "".
func display_name() -> String:
	if demo:
		return DEMO_AGENT
	if adapter == null:
		return ""
	var name: String = adapter.adapter_name()
	if name == "local" or Detector.KNOWN_AGENTS.has(name):
		return name
	return ""


func is_local() -> bool:
	return not demo and adapter != null and adapter.adapter_name() == "local"


## Starts one call with `request` (a GuideRequest). {} when it is under way; otherwise the
## adapter's refusal (busy, rate_limited, ...), or ai_off without the player's yes. Never
## called in demo mode: owners show canned answers there.
func ask(request: RefCounted) -> Dictionary:
	if demo or adapter == null:
		return {"ok": false, "text": "", "error_kind": "unavailable", "latency_ms": -1, "tokens_per_sec": -1.0}
	if not ai_on() or adapter.tuning() != guide_tuning:
		return {"ok": false, "text": "", "error_kind": "ai_off", "latency_ms": -1, "tokens_per_sec": -1.0}
	guide_tuning.ai_enabled = true
	var started: Dictionary = adapter.ask(request)
	if started.is_empty():
		calls += 1
	return started


## {} while a call runs; its result once, when done, and its numbers kept in last_call.
func poll_call() -> Dictionary:
	if adapter == null:
		return {}
	var done: Dictionary = adapter.poll()
	if not done.is_empty():
		last_call = {
			"ok": done.get("ok", false),
			"error_kind": error_word(done.get("error_kind", "")),
			"latency_ms": int(done.get("latency_ms", -1)),
			"tokens_per_sec": float(done.get("tokens_per_sec", -1.0)),
		}
		if last_call["ok"]:
			not_loaded = false
		elif last_call["error_kind"] == "needs_consent":
			not_loaded = true
	return done


func is_busy() -> bool:
	return adapter != null and adapter.is_busy()


## Milliseconds until the adapter's minimum interval allows the next call; 0 when it does.
func cooldown_ms() -> int:
	return adapter.cooldown_ms() if adapter != null and adapter.has_method("cooldown_ms") else 0


## Stops a call in flight; the agent child is stopped by its own PID.
func cancel_call() -> void:
	if adapter != null and adapter.has_method("cancel"):
		adapter.cancel()


## The latest GPU reading: {available, util_percent, vram_used_mib, vram_total_mib, temp_c}.
func gpu_reading() -> Dictionary:
	return _gpu_reading


func gpu_busy() -> bool:
	return _gpu_thread != null and _gpu_thread.is_alive()


func _tick_gpu(ms: float) -> void:
	if _state == State.STARTING or (found == null and not demo):
		return
	if _gpu_thread != null:
		if _gpu_thread.is_alive():
			return
		_gpu_reading = _gpu_thread.wait_to_finish()
		_gpu_thread = null
	_gpu_wait_ms -= ms
	if _gpu_wait_ms > 0.0:
		return
	_gpu_wait_ms = maxi(gpu_interval_ms, GPU_INTERVAL_FIRST_MS)
	gpu_reads += 1
	if demo:
		_demo_ticks += 1
		_gpu_reading = DEMO_GPU.duplicate()
		_gpu_reading["util_percent"] = DEMO_GPU["util_percent"] + (_demo_ticks * 3) % DEMO_UTIL_SWING
		return
	if detector == null:
		return
	_gpu_thread = Thread.new()
	if _gpu_thread.start(detector.poll_gpu) != OK:
		_gpu_thread = null


## Before the owner goes and leaves the link for the next one: stops a call in flight, and
## hands a GPU reading or an unfinished adapter choice that is still running to a
## Leftovers node under `root`, which joins it once it has ended (an unfinished choice is
## made again by the next owner). Detection still running carries on for the next owner.
## `deferred` adds that node at the end of the frame, for an owner leaving the tree.
func pause(root: Node, deferred: bool = false) -> void:
	cancel_call()
	var leftovers := Leftovers.new()
	if _adapter_thread != null:
		leftovers.keep(_adapter_thread, _job)
		_adapter_thread = null
		_job = null
	if _gpu_thread != null:
		leftovers.keep(_gpu_thread, detector)
		_gpu_thread = null
	_adopt(leftovers, root, deferred)


## When the link is dropped for good: also cancels the detector, and a detector whose own
## worker is still busy goes to the Leftovers node too. With no root (the game is quitting,
## or the owner was freed without a tree) every worker is joined right here; the C9 reader
## gives up at a cancel, so that is about a millisecond unless the filesystem hangs.
func shut_down(root: Node) -> void:
	cancel_call()
	if detector != null and detector.has_method("cancel"):
		detector.cancel()
	var leftovers := Leftovers.new()
	if _adapter_thread != null:
		leftovers.keep(_adapter_thread, _job)
		_adapter_thread = null
		_job = null
	if _gpu_thread != null:
		leftovers.keep(_gpu_thread, detector)
		_gpu_thread = null
	if detector != null and detector.has_method("is_done") and not detector.is_done():
		leftovers.keep(null, detector)  # its own worker; dropping it would join it here
	_adopt(leftovers, root)


static func _adopt(leftovers: Leftovers, root: Node, deferred: bool = false) -> void:
	if leftovers.is_empty():
		leftovers.free()
	elif root != null and root.is_inside_tree():
		if deferred:
			root.add_child.call_deferred(leftovers)
		else:
			root.add_child(leftovers)
	else:
		leftovers.join_all()
		leftovers.free()


## The screen's GPU readout from a reading: "GPU 41%   VRAM 3072/8192 MiB   58 C", without
## any field it lacks; "" when there is nothing to show.
static func gpu_text(reading: Variant) -> String:
	if not (reading is Dictionary) or not reading.get("available", false):
		return ""
	var parts := PackedStringArray()
	var util := _number(reading, "util_percent")
	if util >= 0:
		parts.append("GPU %d%%" % util)
	var used := _number(reading, "vram_used_mib")
	var total := _number(reading, "vram_total_mib")
	if used >= 0 and total > 0:
		parts.append("VRAM %d/%d MiB" % [used, total])
	var temp := _number(reading, "temp_c")
	if temp >= 0:
		parts.append("%d C" % temp)
	return "   ".join(parts)


static func _number(reading: Dictionary, key: String) -> int:
	var value = reading.get(key, -1)
	return value if value is int else -1


static func reading_of(result: Found) -> Dictionary:
	return {
		"available": result.gpu_available,
		"util_percent": result.gpu_util_percent,
		"vram_used_mib": result.gpu_vram_used_mib,
		"vram_total_mib": result.gpu_vram_total_mib,
		"temp_c": result.gpu_temp_c,
	}


static func demo_found() -> Found:
	var result := Found.new()
	result.agent_state = Found.AgentState.KNOWN
	result.agent = DEMO_AGENT
	result.agent_cli_present = true
	result.source = Found.Source.AGENT
	result.source_name = DEMO_AGENT
	return result


## An adapter's error kind if it is a short lowercase word, else "error".
static func error_word(kind: Variant) -> String:
	if not (kind is String) or (kind as String).is_empty() or (kind as String).length() > ERROR_WORD_MAX:
		return "error"
	for c in (kind as String):
		if not ((c >= "a" and c <= "z") or c == "_"):
			return "error"
	return kind


## Holds workers a link left running, and joins each one once it has ended (or drops a
## detector once its own worker is done), then frees itself. If the game quits first, it
## joins what is left right there.
class Leftovers:
	extends Node
	var _threads: Array = []
	var _held: Array = []

	func keep(thread: Thread, held) -> void:
		_threads.append(thread)
		_held.append(held)

	func is_empty() -> bool:
		return _threads.is_empty()

	func _process(_delta: float) -> void:
		for i in range(_threads.size() - 1, -1, -1):
			var thread: Thread = _threads[i]
			if thread != null:
				if thread.is_alive():
					continue
				thread.wait_to_finish()
			elif _held[i] != null and not _held[i].is_done():
				continue
			_threads.remove_at(i)
			_held.remove_at(i)
		if _threads.is_empty():
			queue_free()

	func _exit_tree() -> void:
		join_all()

	func join_all() -> void:
		for thread in _threads:
			if thread != null and thread.is_started():
				thread.wait_to_finish()
		_threads.clear()
		_held.clear()


## Chooses the adapter off the main thread: a test's factory if one was handed in;
## otherwise, unless the headless guard is on, the C9b registry, which looks the agent's
## command up along the PATH. The link holds the job until its thread is joined.
class AdapterJob:
	extends RefCounted
	const RegistryScript = preload("res://scripts/ai/guide_registry.gd")
	var factory := Callable()
	var found
	var detector
	var tuning: Resource
	var guarded := false
	var adapter = null

	func run() -> void:
		if not factory.is_null():
			adapter = factory.call(found, detector, tuning)
			return
		if guarded:
			return  # headless guard: never the registry, so never a real agent or server
		adapter = RegistryScript.adapter_for(found, detector, tuning)
