extends Control
## The boot screen (PRD 5.4, chunk C10), SIGKILL's first scene: typed terminal lines that
## name the player's Omarchy default agent, or the fallback the C9 detector picked, a live
## GPU readout, and a "Linking..." handshake that shows the AI answering, then the arena.
## Esc or Enter skips straight to the arena at any point.
##
## Never blocks the main thread: the detector runs on its own worker (start/is_done/wait),
## each GPU reading runs on a short worker thread of its own (nvidia-smi can take a second),
## and the handshake adapter is polled once a frame. The arena loads in the background.
##
## The AI is called only with the player's yes. Before the first call to a source, the
## screen names it and says what it gets, and waits for Y (allow) or N (keep AI off); the
## answer is kept by scripts/boot/guide_settings.gd in user://settings.cfg. The guide
## tuning's ai_enabled switch is set only on this screen's own copy, and only after a yes.
## The handshake is one call through the C9b registry with the request builder, a fixed
## prompt and no player data at all; a timeout or an error falls back to the scripted line.
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
## On screen: fixed lines, an agent name from the detector's known list, numbers, fixed
## error words, and an answer that passes screen_line(). Never a path, host name, user
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
## The whole handshake prompt: fixed, with no player data at all.
const HANDSHAKE_TEXT := "Boot handshake. Greet the player in one short line of under twelve words to show the link works. Do not name any model, version, file, folder, user or machine."
const SPINNER := ["|", "/", "-", "\\"]
## Characters an answer may hold to be shown: ASCII letters, spaces and plain punctuation.
## No digits, slashes, colons, underscores or at signs, so no path, address, version or
## model tag gets on screen; an answer with anything else shows LINK_UP instead.
const SCREEN_PUNCTUATION := " .,!?'-()"
const ERROR_WORD_MAX := 24
const ELLIPSIS := "..."

const DEMO_AGENT := "claude"
const DEMO_ANSWER := "Link up. Daemons detected. Let's go hunting."
const DEMO_GPU := {"available": true, "source": "demo", "util_percent": 41, "vram_used_mib": 3072, "vram_total_mib": 8192, "temp_c": 58}
const DEMO_UTIL_SWING := 7

enum Phase { DETECTING, CONSENT, LINKING, CLOSING, LEAVING, DONE }

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


func _ready() -> void:
	_t = usable_tuning(tuning)
	_guide_tuning = _fresh_guide_tuning()
	var args := OS.get_cmdline_user_args()
	demo = demo or args.has("--demo")
	var headless := DisplayServer.get_name() == "headless"
	_guarded = headless or args.has("--no-ai")
	_skip_reason = "headless run" if headless else "--no-ai"
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
	if detector != null and detector.has_method("cancel"):
		detector.cancel()
	_release_gpu_thread()


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


## The adapter the handshake uses, or null.
func adapter() -> Variant:
	return _adapter


func is_guarded() -> bool:
	return _guarded


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


## The first line of `answer` if it is safe to show: letters, spaces and plain punctuation
## only, and a dot only at the end of a sentence (so no host.name or file.ext), cut at a
## word to at most `max_chars`, ellipsis included. "" when it holds anything else.
static func screen_line(answer: String, max_chars: int) -> String:
	var first := answer.strip_edges().get_slice("\n", 0).strip_edges()
	if first.is_empty():
		return ""
	for i in first.length():
		var c := first.unicode_at(i)
		var letter := (c >= 0x41 and c <= 0x5A) or (c >= 0x61 and c <= 0x7A)
		if not letter and not SCREEN_PUNCTUATION.contains(first[i]):
			return ""
		if first[i] == "." and i + 1 < first.length() and not (first[i + 1] == " " or first[i + 1] == "."):
			return ""
	if first.length() > max_chars:
		# The ellipsis counts against the cap; a word that would be cut is dropped whole.
		var room := max_chars - ELLIPSIS.length()
		var cut := first.substr(0, room)
		if first[room] != " ":
			var space := cut.rfind(" ")
			if space > 0:
				cut = cut.substr(0, space)
		first = cut.strip_edges() + ELLIPSIS
	return first


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
	_spinner.position.y -= 72.0
	_gpu_label = _make_label(_t.text_color, _t.line_font_size)
	_gpu_label.visible = false
	add_child(_gpu_label)
	_gpu_label.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT, Control.PRESET_MODE_MINSIZE, 48)
	_gpu_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	var hint := _make_label(_t.text_color, _t.hint_font_size)
	hint.text = HINT
	hint.modulate = Color(1.0, 1.0, 1.0, _t.hint_alpha)
	add_child(hint)
	hint.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT, Control.PRESET_MODE_MINSIZE, 48)


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
	_adapter = _make_adapter()
	_say(_agent_line())
	if _adapter == null:
		if _guarded and _found.source != Found.Source.SCRIPTED:
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


func _make_adapter() -> Variant:
	if not adapter_factory.is_null():
		return adapter_factory.call(_found, detector, _guide_tuning)
	if _guarded:
		return null  # headless guard: never the registry, so never a real agent or server
	return Registry.adapter_for(_found, detector, _guide_tuning)


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
		var line := screen_line(String(done.get("text", "")), _t.answer_max_chars)
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
	if not _gpu_on:
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


## A GPU reading still running when the screen goes is handed to a node that outlives it
## and joins the thread once it ends, so leaving never waits on nvidia-smi.
func _release_gpu_thread() -> void:
	if _gpu_thread == null:
		return
	var reaper := ThreadReaper.new()
	reaper.thread = _gpu_thread
	reaper.keep = detector
	_gpu_thread = null
	if is_inside_tree():
		get_tree().root.add_child.call_deferred(reaper)
	else:
		reaper.thread.wait_to_finish()
		reaper.free()


func _leave(skipped: bool) -> void:
	if _left:
		return
	_left = true
	_skipped = skipped
	_stop_link()
	_spinner.visible = false
	finished.emit(skipped)
	if not hand_off or next_scene == "":
		_phase = Phase.DONE
		return
	_phase = Phase.LEAVING
	_finish_leaving()


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


## Joins a worker thread once it has ended, then frees itself. Holds what the thread uses.
class ThreadReaper:
	extends Node
	var thread: Thread
	var keep: RefCounted

	func _process(_delta: float) -> void:
		if thread != null and not thread.is_alive():
			thread.wait_to_finish()
			thread = null
			keep = null
			queue_free()
