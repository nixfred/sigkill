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
## refusal() is the one gate every caller checks first: the T ask box (C11) and the round's
## end (C12) share its pace, its one call in flight and the session's cap on calls. The
## roast announcer switch (C12) sits next to the answer in the same settings file.
##
## Model loading (C11b), for an Ollama server only, through scripts/guide/ollama_loader.gd
## on a worker: begin_offer() finds one candidate (or a model loaded by now), and only
## accept_load(), the player's Y, loads it. The answer to that question is for this session
## only and never saved. The link unloads the model the game loaded itself when the AI is
## turned off (set_consent(false)) and when it is shut down at the end of the session, and
## watches a load it stopped waiting for so it can unload it if it turns up. Under the
## headless guard the only server it may load on is a port a test handed in (load_port).

const Settings = preload("res://scripts/boot/guide_settings.gd")
const Loader = preload("res://scripts/guide/ollama_loader.gd")
const Detector = preload("res://scripts/ai/ai_source_detector.gd")
const Found = preload("res://scripts/ai/ai_source_result.gd")
const GuideTuningScript = preload("res://scripts/guide_tuning.gd")

const GUIDE_TUNING_PATH := "res://resources/guide.tres"
const GPU_INTERVAL_FIRST_MS := 1000
## The longest wait between two retries of an unload that keeps failing.
const TIDY_BACKOFF_LAST_MS := 30000.0
## The least time the exit unload gets even if stopping a job used the whole budget.
const EXIT_UNLOAD_FLOOR_MS := 250
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
## A test's fake Ollama port to load models on. Under the headless guard this is the only
## server a link may ever load on; -1 means none there, and the detector's port otherwise.
var load_port := -1

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
## Moves on when a call starts and when one is stopped. A caller that kept the number its
## own call started with owns the call in flight only while the two still match, so it
## never polls or stops a call someone else started after its own was stopped.
var call_serial := 0
## True once a local server said it has nothing loaded, until a later call is answered or
## a model is loaded: "available, not loaded".
var not_loaded := false
## Where the model-load question stands: "" (nothing asked), "checking", "offer" (waiting
## for the player's Y or N), "loading", "loaded", "loaded_now" (a model was loaded by
## something else), "none_fits", "declined", "cancelled", "timeout" or "error".
var load_state := ""
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
## The roast announcer switch, read from the settings file once, like the answer. Demo data
## keeps its own in memory and never reads or writes the file.
var _roast_known := false
var _roast := false
var _demo_roast := false
var _loader: Loader
var _loader_thread: Thread
## A loader job waiting for the running one to be joined: jobs never overlap, and a thread
## that has not been joined is never replaced.
var _queued_job := Callable()
## What the running and the queued job are ("offer", "load", "unload", "watch") and which
## offer or load request each belongs to: a job's outcome only ever answers the request
## that started it, never a newer one.
var _running_kind := ""
var _queued_kind := ""
var _running_id := 0
var _queued_id := 0
var _request_id := 0
## The loader's current model, copied only once its job is joined: the main thread never
## reads what a worker may be writing.
var _game_loaded := ""
## Unloads asked for while a job ran, handed to the loader once it is idle: every owned
## model (O, the end of a session), or the named ones (a load nobody waits for any more).
var _release_all := false
var _release_names := PackedStringArray()
## Time until the next tidy run (release retries and watched loads), backing off while a
## release keeps failing.
var _tidy_wait_ms := 0.0
var _tidy_backoff_ms := 0.0
## How many releases were waiting when the running tidy job started.
var _tidy_release_before := 0


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
	_tick_loader(delta_ms)


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
		_request_unload()
	# The answer counts for this session even if it cannot be saved; then it is asked again
	# next time.
	_consent = Settings.Answer.ALLOWED if allowed else Settings.Answer.DECLINED
	_consent_known = true
	return Settings.save(adapter.source_name(), allowed, settings_path)


## True when the player turned the roast announcer on (B); off by default.
func roast_on() -> bool:
	if demo:
		return _demo_roast
	if not _roast_known:
		_roast = Settings.roast_on(settings_path)
		_roast_known = true
	return _roast


## Turns the roast announcer on or off and saves it next to the opt-in answer. It counts for
## this session even if it cannot be saved; false then (demo saves nothing, and is true).
func set_roast(on: bool) -> bool:
	if demo:
		_demo_roast = on
		return true
	_roast = on
	_roast_known = true
	return Settings.save_roast(on, settings_path)


## Why a call would be refused right now, as one word, or "" when one may start: "linking",
## "guarded" (the headless guard, with nothing handed in to call), "no_ai", "off", "busy"
## (a call in flight), "cap" (`cap` calls made this session) or "cooldown". Demo data never
## calls: "demo".
func refusal(cap: int) -> String:
	if demo:
		return "demo"
	if not is_ready():
		return "linking"
	if adapter == null:
		return "guarded" if _guarded else "no_ai"
	if not ai_on():
		return "off"
	if is_busy():
		return "busy"
	if calls >= cap:
		return "cap"
	if cooldown_ms() > 0:
		return "cooldown"
	return ""


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
		call_serial += 1
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
	call_serial += 1
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


## True when the game may offer to load a model: the adapter is a local Ollama server, a
## port to load on is known (under the headless guard only a test's), and not demo data.
func can_offer_load() -> bool:
	return not demo and adapter != null and adapter.source_name() == "ollama" and _load_port() > 0


## How the screens hint at loading a model: "loadable", "own_app" (another local server:
## the player loads one in its own app) or "".
func load_hint() -> String:
	if adapter == null or not is_local():
		return ""
	if can_offer_load():
		return "loadable"
	return "own_app" if adapter.source_name() != "ollama" else ""


func _load_port() -> int:
	if load_port > 0:
		return load_port
	if _guarded or detector == null:
		return -1
	var port = detector.get("ollama_port")
	return port if port is int else -1


## Starts finding a model to offer (re-reading /api/ps first), after any loader job still
## running. False if loading is not possible here or an offer or load is under way.
func begin_offer() -> bool:
	if not can_offer_load() or is_loading():
		return false
	_ensure_loader()
	load_state = "checking"
	var reading := gpu_reading()
	var free_mib := -1
	var used = reading.get("vram_used_mib", -1)
	var total = reading.get("vram_total_mib", -1)
	if reading.get("available", false) and used is int and total is int and used >= 0 and total > 0:
		free_mib = maxi(total - used, 0)
	_request_id += 1
	return _start_loader_job(_loader.job_offer.bind(free_mib), "offer", _request_id)


## The model on offer and its size, while load_state is "offer" (or after).
func offer_name() -> String:
	return _loader.offer_name if _loader != null else ""


func offer_size_text() -> String:
	return Loader.size_text(_loader.offer_bytes) if _loader != null else ""


## The player's Y: loads the model on offer. False if nothing is on offer.
func accept_load() -> bool:
	if load_state != "offer" or _loader == null or _loader.offer_name == "":
		return false
	load_state = "loading"
	_request_id += 1
	return _start_loader_job(_loader.job_load.bind(_loader.offer_name), "load", _request_id)


## The player's N (or Esc) to the question: nothing is loaded.
func decline_load() -> void:
	if load_state == "offer":
		load_state = "declined"


## Esc while loading: stop waiting. The load is watched and unloaded if it turns up (a
## load still waiting for its turn is simply dropped).
func cancel_load() -> void:
	if load_state == "loading" and _loader != null:
		if _queued_kind == "load":
			_queued_job = Callable()
			_queued_kind = ""
		elif _running_kind == "load" and _running_id == _request_id:
			_loader.cancel()
		load_state = "cancelled"


func is_loading() -> bool:
	return load_state == "checking" or load_state == "loading"


## The model the game loaded itself, as of the last joined job, or "".
func game_loaded_model() -> String:
	return _game_loaded


## True when no loader job is running.
func loader_idle() -> bool:
	return _loader_thread == null


## True while the loader, idle, still has a model to unload or a sent load to watch for.
func load_pending() -> bool:
	return _loader != null and _loader_thread == null and _loader.has_pending()


func _ensure_loader() -> void:
	if _loader == null:
		_loader = Loader.new()
		_loader.port = _load_port()
		_loader.tuning = guide_tuning


## Starts `job` on the loader's worker, or queues it behind the job still running. The
## cancel flag is armed here, on the main thread, before the thread starts.
func _start_loader_job(job: Callable, kind: String, id: int = 0) -> bool:
	if _loader_thread != null:
		_queued_job = job
		_queued_kind = kind
		_queued_id = id
		return true
	_loader.arm()
	if kind == "tidy":
		_tidy_release_before = _loader.release.size()
	_loader_thread = Thread.new()
	_running_kind = kind
	_running_id = id
	if _loader_thread.start(job) != OK:
		_loader_thread = null
		_running_kind = ""
		if kind == "offer" or kind == "load":
			load_state = "error"
		return false
	return true


func _request_unload() -> void:
	if _loader == null:
		return
	_queued_job = Callable()
	_queued_kind = ""
	if load_state == "loading" or load_state == "checking":
		if _running_kind == "load" or _running_kind == "offer":
			_loader.cancel()
		load_state = "cancelled"
	_release_all = true


## Joins a finished loader job and reads its outcome; then hands any asked-for unloads to
## the loader and tidies at once, or starts a queued job, or, while something is left to
## unload or watch for, tidies again after a wait that backs off while unloads keep failing.
func _tick_loader(ms: float) -> void:
	if _loader == null:
		return
	if _loader_thread != null:
		if _loader_thread.is_alive():
			return
		_loader_thread.wait_to_finish()
		_loader_thread = null
		var kind := _running_kind
		_read_outcome(kind, _running_id)
		_running_kind = ""
		_game_loaded = _loader.current
		if kind == "tidy":
			# Back off while releases keep failing; start over once one goes through.
			var stuck := _tidy_release_before > 0 and _loader.release.size() >= _tidy_release_before
			_tidy_backoff_ms = minf(maxf(_tidy_backoff_ms * 2.0, guide_tuning.load_watch_interval_ms), TIDY_BACKOFF_LAST_MS) if stuck else float(guide_tuning.load_watch_interval_ms)
			_tidy_wait_ms = _tidy_backoff_ms
	# Asked-for unloads go first, so a queued request runs against what is loaded after them.
	if _release_all or not _release_names.is_empty():
		_loader.mark_release(PackedStringArray() if _release_all else _release_names)
		_release_all = false
		_release_names = PackedStringArray()
		_game_loaded = _loader.current
		if _loader.has_pending():
			_start_loader_job(_loader.job_tidy, "tidy")
			return
	if not _queued_job.is_null():
		var next := _queued_job
		var kind := _queued_kind
		_queued_job = Callable()
		_queued_kind = ""
		_start_loader_job(next, kind, _queued_id)
		return
	if _loader.has_pending():
		_tidy_wait_ms -= ms
		if _tidy_wait_ms <= 0.0:
			_tidy_wait_ms = maxf(_tidy_backoff_ms, float(guide_tuning.load_watch_interval_ms))
			_start_loader_job(_loader.job_tidy, "tidy")


## Applies a joined job's outcome, but only to the request that started it (`id`), and only
## while that request still waits: an offer's to "checking", a load's to "loading". A newer
## request is never overwritten by an older job. A load that succeeded after the player
## stopped waiting for it, or after a newer request, is unloaded.
func _read_outcome(kind: String, id: int) -> void:
	var outcome := _loader.outcome
	_loader.outcome = Loader.Outcome.NONE
	var current := id == _request_id
	if kind == "load" and outcome == Loader.Outcome.LOADED and not (current and load_state == "loading"):
		_release_names.append(_loader.last_load)  # nobody waits for it any more: unload it
		return
	if not current:
		return
	if kind == "offer" and load_state == "checking":
		match outcome:
			Loader.Outcome.LOADED_NOW:
				load_state = "loaded_now"
				not_loaded = false
			Loader.Outcome.OFFER:
				load_state = "offer"
			Loader.Outcome.NONE_FITS:
				load_state = "none_fits"
			Loader.Outcome.CANCELLED:
				load_state = "cancelled"
			_:
				load_state = "error"
	elif kind == "load" and load_state == "loading":
		match outcome:
			Loader.Outcome.LOADED:
				load_state = "loaded"
				not_loaded = false
			Loader.Outcome.LOADED_NOW:
				load_state = "loaded_now"
				not_loaded = false
			Loader.Outcome.TIMEOUT:
				load_state = "timeout"
			Loader.Outcome.CANCELLED:
				load_state = "cancelled"
			_:
				load_state = "error"


## At the end of the session: stops a loader job (every job stops at a cancel within a
## poll step), then unloads the game's own models (and watched loads that have turned up)
## right here. The join and the unloads share one deadline of unload_timeout_ms.
func _unload_for_exit() -> void:
	if _loader == null:
		return
	var deadline := Time.get_ticks_msec() + int(guide_tuning.unload_timeout_ms)
	_queued_job = Callable()
	_queued_kind = ""
	if _loader_thread != null:
		_loader.cancel()
		_loader_thread.wait_to_finish()
		_loader_thread = null
		_read_outcome(_running_kind, _running_id)
		_running_kind = ""
	_loader.unload_now(maxi(deadline, Time.get_ticks_msec() + EXIT_UNLOAD_FLOOR_MS))
	_game_loaded = _loader.current


## When the link is dropped for good: also cancels the detector, and a detector whose own
## worker is still busy goes to the Leftovers node too. With no root (the game is quitting,
## or the owner was freed without a tree) every worker is joined right here; the C9 reader
## gives up at a cancel, so that is about a millisecond unless the filesystem hangs.
func shut_down(root: Node) -> void:
	cancel_call()
	_unload_for_exit()
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
