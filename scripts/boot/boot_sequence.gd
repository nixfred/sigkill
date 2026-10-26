extends Control
## The boot screen (PRD 5.4, chunk C10), SIGKILL's first scene: typed terminal lines that
## name the player's Omarchy default agent, or the fallback the C9 detector picked, a live
## GPU readout, and a "Linking..." handshake that shows the AI answering, then the arena.
## Esc or Enter skips straight to the arena at any point.
##
## Never blocks the main thread: the detector runs on its own worker (start/is_done/wait),
## the adapter is chosen on a worker too (the registry looks the agent's command up along
## the PATH), each GPU reading runs on a short worker thread of its own (nvidia-smi can take
## a second), and the handshake adapter is polled once a frame. The arena loads in the
## background. Leaving never waits on a worker either: it cancels the detector and hands
## anything still running (the detector, the adapter worker, a GPU reading) to a small
## Leftovers node that outlives the screen and joins each one once it has finished. Only
## when the game itself quits are workers joined on the spot, since a running thread must
## not outlive the engine; the C9 reader gives up at a cancel, so that is about a
## millisecond unless the filesystem itself hangs.
##
## The AI is called only with the player's yes. Before the first call to a source, the
## screen names it and says what it gets, and waits for Y (allow) or N (keep AI off); the
## answer is kept by scripts/boot/guide_settings.gd in user://settings.cfg. The guide
## tuning's ai_enabled switch is set only on this screen's own copy, and only after a yes.
## The handshake is one call through the C9b registry with the request builder, a fixed
## prompt and no player data at all; a timeout or an error falls back to the scripted line.
## The prompt asks the AI to answer with one of SIGKILL's own HANDSHAKE_LINES; the screen
## shows SIGKILL's copy of the line it picked, or "Link up." for anything else, so the AI's
## own words, which could name a person, a machine or a model, never reach the screen.
## A local server with nothing loaded is never asked to load anything.
##
## Headless guard (hard rule): in any headless run, or with the user argument --no-ai, no
## real detector is ever made and the C9b registry is never asked, whatever was saved, so
## no agent is launched and no model server is contacted. Only a detector and an adapter
## factory a test hands in are used. A headless run with nothing handed in, such as the
## check.sh smoke run, goes straight to the arena.
##
## Demo-data mode (user argument --demo, e.g. `godot --path . -- --demo`): fake data
## everywhere, agent "claude", fake GPU numbers, a canned answer and latency. No detector,
## no settings file, no process, no network. The mode for screenshots and trailers.
##
## On screen: fixed lines, an agent name from the detector's known list, numbers, short
## lowercase error words, and a line from HANDSHAKE_LINES. Never a path, host name, user
## name or model name.

signal finished(skipped: bool)

const BootTuningScript = preload("res://scripts/boot/boot_tuning.gd")
const Settings = preload("res://scripts/boot/guide_settings.gd")
const Palette = preload("res://scripts/palette.gd")
const Detector = preload("res://scripts/ai/ai_source_detector.gd")
const Found = preload("res://scripts/ai/ai_source_result.gd")
const Registry = preload("res://scripts/ai/guide_registry.gd")
const Request = preload("res://scripts/ai/guide_request.gd")
const GuideTuningScript = preload("res://scripts/guide_tuning.gd")

const ARENA_SCENE := "res://scenes/main.tscn"
const DEFAULT_TUNING_PATH := "res://resources/boot.tres"
const GUIDE_TUNING_PATH := "res://resources/guide.tres"

const TITLE := "SIGKILL boot"
const HINT := "Esc or Enter: skip to the arena"
const SCRIPTED_LINE := "AI off. Scripted guide online."
const LOCAL_LINE := "Local model server found. Linking..."
const NOT_LOADED_LINE := "Local model available, not loaded. Load it later from settings."
const CONSENT_KEYS := "[Y] allow   [N] keep AI off"
const LEAVING_LINE := "Entering the arena..."
const LINK_UP := "Link up."
## The only answers the screen shows. The handshake asks the AI to reply with one of them.
const HANDSHAKE_LINES := [
	"Link up. Ready to hunt.",
	"Online. Daemons beware.",
	"Linked. Let's clear this arena.",
	"Guide online. Stay low and keep moving.",
	"Link up. Daemons detected. Let's go hunting.",
]
## The whole handshake prompt: fixed, with no player data at all, naming HANDSHAKE_LINES.
const HANDSHAKE_TEXT := "Boot handshake. Reply with exactly one of these lines, word for word, and nothing else: Link up. Ready to hunt. | Online. Daemons beware. | Linked. Let's clear this arena. | Guide online. Stay low and keep moving. | Link up. Daemons detected. Let's go hunting."
## Characters stripped from both ends of an answer before it is matched.
const ANSWER_WRAPPING := " \t\"'`*>"
const SPINNER := ["|", "/", "-", "\\"]
const ERROR_WORD_MAX := 24

const DEMO_AGENT := "claude"
const DEMO_ANSWER := "Link up. Daemons detected. Let's go hunting."  # one of HANDSHAKE_LINES
const DEMO_GPU := {"available": true, "source": "demo", "util_percent": 41, "vram_used_mib": 3072, "vram_total_mib": 8192, "temp_c": 58}
const DEMO_UTIL_SWING := 7

enum Phase { DETECTING, CHOOSING, CONSENT, LINKING, CLOSING, LEAVING, DONE }

# Set these before the node enters the tree; the defaults are the real ones.
## BootTuning; null for resources/boot.tres.
var tuning: Resource = null
## The detector to ask: an AiSourceDetector, or a test fake with its start, is_done, wait,
## cancel and poll_gpu. Null: a real one, except under the headless guard. Untyped on
## purpose, so a fake fits.
var detector = null
## (found, detector, guide tuning) -> adapter or null. Empty: the C9b registry, except
## under the headless guard, where an empty factory means no adapter at all.
var adapter_factory := Callable()
## Where the opt-in answer is kept.
var settings_path := Settings.DEFAULT_PATH
## Demo-data mode; --demo on the command line also turns it on.
var demo := false
## Change to next_scene when done. Tests that only watch `finished` turn it off.
var hand_off := true
var next_scene := ARENA_SCENE

var _t: Resource
var _guide_tuning: Resource
var _guarded := false
var _skip_reason := ""
var _phase: Phase = Phase.DETECTING
var _found: Found
var _adapter  # untyped on purpose: a C9b adapter, or a test stub with the same calls
var _who := ""
var _source_key := ""
var _link_ms := 0.0
var _spin_ms := 0.0
var _spin_at := 0
var _continue_ms := 0.0
var _left := false
var _skipped := false
var _loading := false

var _lines: VBoxContainer
var _spinner: Label
var _gpu_label: Label
var _queue: Array[Label] = []
var _typed := 0.0
var _pause_ms := 0.0

var _gpu_on := false
var _gpu_wait_ms := 0.0
var _gpu_thread: Thread
var _gpu_reads := 0
var _demo_ticks := 0
var _adapter_job: AdapterJob
var _adapter_thread: Thread


func _ready() -> void:
	_t = usable_tuning(tuning)
	_guide_tuning = _fresh_guide_tuning()
	var args := OS.get_cmdline_user_args()
	demo = demo or args.has("--demo")
	var headless := DisplayServer.get_name() == "headless"
	_guarded = headless or args.has("--no-ai")
	_skip_reason = ("headless run" if headless else "--no-ai") if _guarded else "the detector gave no answer"
	_build_screen()
	if headless and not demo and detector == null and adapter_factory.is_null():
		print("SIGKILL boot: headless run, AI link skipped, straight to the arena")
		_leave.call_deferred(false)
		return
	if hand_off and next_scene != "":
		_loading = ResourceLoader.load_threaded_request(next_scene) == OK
	_say(TITLE, _t.title_color, _t.title_font_size)
	if demo:
		return
	if detector == null and not _guarded:
		detector = Detector.new()
	if detector != null and detector.start() != OK:
		detector = null
		_skip_reason = "detection could not start"


func _process(delta: float) -> void:
	var ms := delta * 1000.0
	_type(delta)
	_tick_gpu(ms)
	_tick_spinner(ms)
	if _phase == Phase.LEAVING:
		_finish_leaving()
		return
	if _phase == Phase.LINKING:
		_poll_link(ms)
	if _typing():
		return
	match _phase:
		Phase.DETECTING:
			_poll_detection()
		Phase.CHOOSING:
			_poll_choosing()
		Phase.CLOSING:
			_continue_ms -= ms
			if _continue_ms <= 0.0:
				_leave(false)


func _unhandled_input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if key == null or not key.pressed or key.echo:
		return
	if key.ctrl_pressed or key.alt_pressed or key.meta_pressed:
		return  # plain keys only
	match key.keycode:
		KEY_ESCAPE, KEY_ENTER, KEY_KP_ENTER:
			get_viewport().set_input_as_handled()
			_leave(true)
		KEY_Y, KEY_N:
			if _phase == Phase.CONSENT and not _typing():
				get_viewport().set_input_as_handled()
				_answer_consent(key.keycode == KEY_Y)


func _exit_tree() -> void:
	_stop_link()
	# Cancel first: the C9 reader then gives up at once, so the joins below take about a
	# millisecond even with an nvidia-smi still running (it is left to exit on its own).
	# Workers left here were not handed to a Leftovers node (the game is quitting, or the
	# screen was freed without leaving), so they are joined now: a thread must not
	# outlive its owner.
	if detector != null and detector.has_method("cancel"):
		detector.cancel()
	for worker in [_gpu_thread, _adapter_thread]:
		if worker != null and worker.is_started():
			worker.wait_to_finish()
	_gpu_thread = null
	_adapter_thread = null


## What is on screen, line by line, for tests: every line's whole text, then the spinner,
## the GPU readout and the hint, whether shown or not.
func screen_text() -> PackedStringArray:
	var out := lines()
	for label in [_spinner, _gpu_label]:
		if label != null:
			out.append(label.text)
	out.append(HINT)
	return out


## The typed lines so far, in order.
func lines() -> PackedStringArray:
	var out := PackedStringArray()
	if _lines != null:
		for child in _lines.get_children():
			out.append((child as Label).text)
	return out


## The GPU readout as shown, or "" while it is hidden.
func gpu_line() -> String:
	return _gpu_label.text if _gpu_label != null and _gpu_label.visible else ""


## How many GPU readings this screen has started.
func gpu_reads() -> int:
	return _gpu_reads


## True while a GPU reading is running on its worker.
func gpu_busy() -> bool:
	return _gpu_thread != null and _gpu_thread.is_alive()


## The adapter the handshake uses, or null.
func adapter() -> Variant:
	return _adapter


func is_guarded() -> bool:
	return _guarded


func is_choosing() -> bool:
	return _phase == Phase.CHOOSING


func is_waiting_for_consent() -> bool:
	return _phase == Phase.CONSENT and not _typing()


static func usable_tuning(candidate: Resource) -> Resource:
	if candidate is BootTuningScript:
		var issues: PackedStringArray = candidate.problems()
		if issues.is_empty():
			return candidate
		for issue in issues:
			push_warning("boot tuning: " + issue + "; using the shipped tuning instead")
	var shipped = load(DEFAULT_TUNING_PATH)
	if shipped is BootTuningScript and shipped.problems().is_empty():
		return shipped
	return BootTuningScript.new()


## SIGKILL's own copy of the HANDSHAKE_LINES entry `answer` picked, or "" if it picked none.
## Only the first line counts; quotes, spaces and markdown marks around it, letter case and
## runs of spaces are ignored. The answer itself is never returned.
static func handshake_line(answer: String) -> String:
	var picked := _plain(answer.strip_edges().get_slice("\n", 0))
	if picked.is_empty():
		return ""
	for line in HANDSHAKE_LINES:
		if _plain(line) == picked:
			return line
	return ""


static func _plain(text: String) -> String:
	var words := PackedStringArray()
	for word in _unwrap(text).to_lower().split(" ", false):
		words.append(word.strip_edges())
	return " ".join(words)


static func _unwrap(text: String) -> String:
	var first := 0
	var last := text.length()
	while first < last and ANSWER_WRAPPING.contains(text[first]):
		first += 1
	while last > first and ANSWER_WRAPPING.contains(text[last - 1]):
		last -= 1
	return text.substr(first, last - first)


## A copy of the shipped guide tuning with the AI switch off; only a yes turns it on.
static func _fresh_guide_tuning() -> Resource:
	var shipped = load(GUIDE_TUNING_PATH)
	var copy: Resource = shipped.duplicate() if shipped is GuideTuningScript else GuideTuningScript.new()
	copy.ai_enabled = false
	return copy


func _build_screen() -> void:
	var back := ColorRect.new()
	back.color = Palette.VOID
	back.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(back)
	back.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_lines = VBoxContainer.new()
	_lines.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_lines)
	_lines.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT, Control.PRESET_MODE_MINSIZE, 48)
	_spinner = _make_label(_t.text_color, _t.line_font_size)
	_spinner.visible = false
	add_child(_spinner)
	_spinner.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT, Control.PRESET_MODE_MINSIZE, 48)
	_spinner.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_spinner.position.y -= 72.0
	_gpu_label = _make_label(_t.text_color, _t.line_font_size)
	_gpu_label.visible = false
	add_child(_gpu_label)
	_gpu_label.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT, Control.PRESET_MODE_MINSIZE, 48)
	_gpu_label.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	_gpu_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	var hint := _make_label(_t.text_color, _t.hint_font_size)
	hint.text = HINT
	hint.modulate = Color(1.0, 1.0, 1.0, _t.hint_alpha)
	add_child(hint)
	hint.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT, Control.PRESET_MODE_MINSIZE, 48)
	hint.grow_vertical = Control.GROW_DIRECTION_BEGIN


func _make_label(color: Color, size: int) -> Label:
	var label := Label.new()
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_override("font", Palette.mono_font())
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_outline_color", Palette.VOID)
	label.add_theme_constant_override("outline_size", 4)
	return label


## Queues a line to type out, in the text colour and line size unless told otherwise.
func _say(text: String, color: Variant = null, size: int = 0) -> void:
	var label := _make_label(color if color is Color else _t.text_color, size if size > 0 else _t.line_font_size)
	label.text = text
	label.visible_characters = 0
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_lines.add_child(label)
	_queue.append(label)


func _typing() -> bool:
	return not _queue.is_empty() or _pause_ms > 0.0


func _type(delta: float) -> void:
	if _pause_ms > 0.0:
		_pause_ms -= delta * 1000.0
		return
	if _queue.is_empty():
		return
	var label := _queue[0]
	_typed += _t.chars_per_second * delta
	if int(_typed) >= label.text.length():
		label.visible_characters = -1
		_queue.pop_front()
		_typed = 0.0
		_pause_ms = _t.line_pause_ms
	else:
		label.visible_characters = int(_typed)


func _poll_detection() -> void:
	if demo:
		_found = _demo_found()
	elif detector == null:
		_found = null
	elif not detector.is_done():
		return
	else:
		_found = detector.wait()
	_route()


## Decides the lines, the adapter and the next step once the detector has answered.
func _route() -> void:
	if _found == null:
		_say("AI link skipped: %s." % _skip_reason, _t.warn_color)
		_scripted()
		return
	_gpu_on = true
	_show_gpu(DEMO_GPU if demo else _reading_of(_found))
	if demo:
		_who = DEMO_AGENT
		_say("Omarchy default agent: %s. Linking..." % DEMO_AGENT)
		_begin_link()
		return
	_adapter_job = AdapterJob.new()
	_adapter_job.factory = adapter_factory
	_adapter_job.found = _found
	_adapter_job.detector = detector
	_adapter_job.tuning = _guide_tuning
	_adapter_job.guarded = _guarded
	_adapter_thread = Thread.new()
	if _adapter_thread.start(_adapter_job.run) != OK:
		# Never on the main thread: no worker means no adapter, and the scripted guide.
		_adapter_thread = null
		_adapter_job.adapter = null
		_skip_reason = "no worker thread"
		_adapter_job.failed = true
	_phase = Phase.CHOOSING


## Once the adapter is chosen: the agent line, then the link, the question or the fallback.
func _poll_choosing() -> void:
	if _adapter_thread != null:
		if _adapter_thread.is_alive():
			return
		_adapter_thread.wait_to_finish()
		_adapter_thread = null
	_adapter = _adapter_job.adapter
	var failed := _adapter_job.failed
	_adapter_job = null
	_say(_agent_line())
	if _adapter == null:
		if failed or (_guarded and _found.source != Found.Source.SCRIPTED):
			_say("AI link skipped: %s." % _skip_reason, _t.warn_color)
		_scripted()
		return
	var local: bool = _adapter.adapter_name() == "local"
	if local:
		_say(LOCAL_LINE)
	_who = "the local model server" if local else String(_adapter.adapter_name())
	_source_key = _adapter.source_name()
	match Settings.answer_for(_source_key, settings_path):
		Settings.Answer.ALLOWED:
			_begin_link()
		Settings.Answer.DECLINED:
			_say("You said no to the AI link.")
			_scripted()
		_:
			_say("Allow SIGKILL to call %s? It gets only game stats and what you type." % _who, _t.prompt_color)
			_say(CONSENT_KEYS, _t.prompt_color)
			_phase = Phase.CONSENT


func _agent_line() -> String:
	var name := _found.agent if Detector.KNOWN_AGENTS.has(_found.agent) else ""
	if _found.agent_state == Found.AgentState.KNOWN and name != "":
		if _adapter != null and _adapter.adapter_name() == name:
			return "Omarchy default agent: %s. Linking..." % name
		if not _found.agent_cli_present:
			return "Omarchy default agent: %s, but its command is not installed." % name
		if not Registry.AGENT_ADAPTERS.has(name):
			return "Omarchy default agent: %s. No SIGKILL adapter for it yet." % name
		return "Omarchy default agent: %s." % name
	if _found.agent_state == Found.AgentState.UNKNOWN or _found.agent_state == Found.AgentState.KNOWN:
		return "Omarchy default agent: not one SIGKILL knows."
	return "Omarchy default agent: not set."


func _answer_consent(allowed: bool) -> void:
	var saved := Settings.save(_source_key, allowed, settings_path)
	if not allowed:
		_say("AI kept off." if saved else "AI kept off. Your answer could not be saved, so you will be asked again.")
		_scripted()
		return
	_say("Allowed." if saved else "Allowed for now. Your answer could not be saved, so you will be asked again.")
	_begin_link()


func _begin_link() -> void:
	_phase = Phase.LINKING
	_link_ms = 0.0
	_spinner.visible = true
	_spin()
	if demo:
		return
	# The switch goes on only on this screen's own copy, and only if the adapter uses it.
	if _adapter.tuning() != _guide_tuning:
		_link_done(_result(false, "", "ai_off", -1))
		return
	_guide_tuning.ai_enabled = true
	var started: Dictionary = _adapter.ask(Request.build({}, HANDSHAKE_TEXT, _guide_tuning.typed_text_max_chars))
	if not started.is_empty():
		_link_done(started)


func _poll_link(ms: float) -> void:
	_link_ms += ms
	if demo:
		if _link_ms >= _t.demo_link_ms:
			_link_done(_result(true, DEMO_ANSWER, "", _t.demo_latency_ms))
		return
	var done: Dictionary = _adapter.poll()
	if not done.is_empty():
		_link_done(done)


func _link_done(done: Dictionary) -> void:
	_spinner.visible = false
	if done.get("ok", false):
		var text = done.get("text", "")
		var line := handshake_line(text) if text is String else ""
		_say("> " + (line if line != "" else LINK_UP))
		var info := "answered in %d ms" % int(done.get("latency_ms", -1))
		var rate := float(done.get("tokens_per_sec", -1.0))
		if is_finite(rate) and rate > 0.0:
			info += ", %.1f tok/s" % rate
		_say(info)
		_closing()
		return
	var kind := _error_word(done.get("error_kind", ""))
	if kind == "needs_consent":
		_say(NOT_LOADED_LINE, _t.warn_color)
	else:
		_say("No answer from %s (%s)." % [_who, kind], _t.warn_color)
	_scripted()


static func _result(ok: bool, text: String, kind: String, latency_ms: int) -> Dictionary:
	return {"ok": ok, "text": text, "error_kind": kind, "latency_ms": latency_ms, "tokens_per_sec": -1.0}


static func _error_word(kind: Variant) -> String:
	if not (kind is String) or (kind as String).is_empty() or (kind as String).length() > ERROR_WORD_MAX:
		return "error"
	for c in (kind as String):
		if not ((c >= "a" and c <= "z") or c == "_"):
			return "error"
	return kind


func _scripted() -> void:
	_say(SCRIPTED_LINE)
	_closing()


func _closing() -> void:
	_say(LEAVING_LINE)
	_phase = Phase.CLOSING
	_continue_ms = _t.auto_continue_ms


func _tick_spinner(ms: float) -> void:
	if not _spinner.visible:
		return
	_spin_ms += ms
	if _spin_ms >= _t.spinner_frame_ms:
		_spin_ms = 0.0
		_spin_at = (_spin_at + 1) % SPINNER.size()
		_spin()


func _spin() -> void:
	_spinner.text = "thinking  %s   waiting for %s" % [SPINNER[_spin_at], _who]


func _tick_gpu(ms: float) -> void:
	if not _gpu_on or _left:
		return
	if _gpu_thread != null:
		if _gpu_thread.is_alive():
			return
		_show_gpu(_gpu_thread.wait_to_finish())
		_gpu_thread = null
	_gpu_wait_ms -= ms
	if _gpu_wait_ms > 0.0:
		return
	_gpu_wait_ms = _t.gpu_interval_ms
	_gpu_reads += 1
	if demo:
		_demo_ticks += 1
		var fake := DEMO_GPU.duplicate()
		fake["util_percent"] = DEMO_GPU["util_percent"] + (_demo_ticks * 3) % DEMO_UTIL_SWING
		_show_gpu(fake)
		return
	if detector == null:
		return
	_gpu_thread = Thread.new()
	if _gpu_thread.start(detector.poll_gpu) != OK:
		_gpu_thread = null


func _show_gpu(reading: Variant) -> void:
	if not (reading is Dictionary) or not reading.get("available", false):
		_gpu_label.visible = false
		return
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
	_gpu_label.text = "   ".join(parts)
	_gpu_label.visible = not parts.is_empty()


static func _number(reading: Dictionary, key: String) -> int:
	var value = reading.get(key, -1)
	return value if value is int else -1


static func _reading_of(found: Found) -> Dictionary:
	return {
		"available": found.gpu_available,
		"util_percent": found.gpu_util_percent,
		"vram_used_mib": found.gpu_vram_used_mib,
		"vram_total_mib": found.gpu_vram_total_mib,
		"temp_c": found.gpu_temp_c,
	}


static func _demo_found() -> Found:
	var found := Found.new()
	found.agent_state = Found.AgentState.KNOWN
	found.agent = DEMO_AGENT
	found.agent_cli_present = true
	found.source = Found.Source.AGENT
	found.source_name = DEMO_AGENT
	return found


func _stop_link() -> void:
	if _adapter != null and _adapter.has_method("cancel"):
		_adapter.cancel()


func _leave(skipped: bool) -> void:
	if _left:
		return
	_left = true
	_skipped = skipped
	_stop_link()
	_spinner.visible = false
	_hand_over_workers()
	finished.emit(skipped)
	if not hand_off or next_scene == "":
		_phase = Phase.DONE
		return
	_phase = Phase.LEAVING
	_finish_leaving()


## Leaving never waits: the detector is cancelled, and whatever is still running goes to a
## Leftovers node under the root that joins it once it has ended.
func _hand_over_workers() -> void:
	if detector != null and detector.has_method("cancel"):
		detector.cancel()
	var leftovers := Leftovers.new()
	if _adapter_thread != null:
		leftovers.keep(_adapter_thread, _adapter_job)
		_adapter_thread = null
		_adapter_job = null
	if _gpu_thread != null:
		leftovers.keep(_gpu_thread, detector)
		_gpu_thread = null
	if detector != null and detector.has_method("is_done") and not detector.is_done():
		leftovers.keep(null, detector)  # its own worker; dropping it would join it here
	if leftovers.is_empty() or not is_inside_tree():
		leftovers.free()
		return
	get_tree().root.add_child(leftovers)


func _finish_leaving() -> void:
	if _loading:
		var status := ResourceLoader.load_threaded_get_status(next_scene)
		if status == ResourceLoader.THREAD_LOAD_IN_PROGRESS:
			return
		_loading = false
		_phase = Phase.DONE
		if status == ResourceLoader.THREAD_LOAD_LOADED:
			var packed := ResourceLoader.load_threaded_get(next_scene) as PackedScene
			if packed != null:
				get_tree().change_scene_to_packed(packed)
				return
	_phase = Phase.DONE
	get_tree().change_scene_to_file(next_scene)


## Holds workers the boot screen left running, and joins each one once it has ended (or
## drops a detector once its own worker is done), then frees itself. If the game quits
## first, it joins what is left right there.
class Leftovers:
	extends Node
	var _threads: Array = []
	var _held: Array = []

	func keep(thread: Thread, held) -> void:
		_threads.append(thread)
		_held.append(held)

	func is_empty() -> bool:
		return _threads.is_empty()

	func count() -> int:
		return _threads.size()

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
		for thread in _threads:
			if thread != null and thread.is_started():
				thread.wait_to_finish()
		_threads.clear()
		_held.clear()


## Chooses the handshake adapter off the main thread: a test's factory if one was handed
## in; otherwise, unless the headless guard is on, the C9b registry, which looks the agent's
## command up along the PATH. The screen holds the job until its thread is joined.
class AdapterJob:
	extends RefCounted
	const RegistryScript = preload("res://scripts/ai/guide_registry.gd")
	var factory := Callable()
	var found
	var detector
	var tuning: Resource
	var guarded := false
	var adapter = null
	var failed := false

	func run() -> void:
		if not factory.is_null():
			adapter = factory.call(found, detector, tuning)
			return
		if guarded:
			return  # headless guard: never the registry, so never a real agent or server
		adapter = RegistryScript.adapter_for(found, detector, tuning)
