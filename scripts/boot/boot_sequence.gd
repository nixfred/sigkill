extends Control
## The boot screen (PRD 5.4, chunk C10), SIGKILL's first scene: typed terminal lines that
## name the player's Omarchy default agent, or the fallback the C9 detector picked, a live
## GPU readout, and a "Linking..." handshake that shows the AI answering, then the arena.
## Esc or Enter skips straight to the arena at any point.
##
## The AI side lives in scripts/guide/guide_link.gd, which this screen makes and, when it
## hands off, leaves to the arena's guide HUD: detection, the adapter choice and GPU
## readings on workers (never the main thread), the player's opt-in, the AI switch, the
## headless guard and demo data. The arena loads in the background.
##
## The AI is called only with the player's yes. Before the first call to a source, the
## screen names it and says what it gets, and waits for Y (allow) or N (keep AI off); the
## answer is kept by scripts/boot/guide_settings.gd in user://settings.cfg.
## The handshake is one call through the C9b registry with the request builder, a fixed
## prompt and no player data at all; a timeout or an error falls back to the scripted line.
## The prompt asks the AI to answer with one of SIGKILL's own HANDSHAKE_LINES; the screen
## shows SIGKILL's copy of the line it picked, or "Link up." for anything else, so the AI's
## own words, which could name a person, a machine or a model, never reach the screen.
## A local server with nothing loaded is never asked to load anything here; for Ollama the
## arena's HUD asks the player first (C11b).
##
## Headless guard (hard rule, kept by the link): in any headless run, or with the user
## argument --no-ai, no real detector is made and the registry is never asked, whatever was
## saved. A headless run with nothing handed in, such as the check.sh smoke run, goes
## straight to the arena.
##
## Demo-data mode (user argument --demo, e.g. `godot --path . -- --demo`, or real-machine
## data turned off in the settings' Privacy section, C16b): fake data everywhere, agent
## "claude", fake GPU numbers, a canned answer and latency. No detector, no process, no
## network. The mode for screenshots and trailers.
##
## Settings (C16b): the boot screen puts the saved window mode, vsync, frame cap, volumes
## and key binds into effect first (scripts/settings/settings_apply.gd; never the window
## in a headless run). Esc and Enter still skip it.
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
const Link = preload("res://scripts/guide/guide_link.gd")
const SettingsApply = preload("res://scripts/settings/settings_apply.gd")

const ARENA_SCENE := "res://scenes/main.tscn"
const DEFAULT_TUNING_PATH := "res://resources/boot.tres"

const TITLE := "SIGKILL boot"
const HINT := "Esc or Enter: skip to the arena"
const SCRIPTED_LINE := "AI off. Scripted guide online."
const LOCAL_LINE := "Local model server found. Linking..."
const NOT_LOADED_LINE := "Local model available, not loaded."
## What follows NOT_LOADED_LINE: for Ollama, the arena's HUD offers to load one (C11b);
## another local server loads models in its own app.
const LOAD_IN_ARENA := " Press T in the arena to load one."
const LOAD_IN_OWN_APP := " Load one in your local server's own app."
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

const DEMO_ANSWER := "Link up. Daemons detected. Let's go hunting."  # one of HANDSHAKE_LINES

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
## A test's fake Ollama port for the link's model loader (see GuideLink.load_port).
var load_port := -1
## Demo-data mode; --demo on the command line also turns it on.
var demo := false
## Change to next_scene when done, leaving the link to it. Tests that only watch
## `finished` turn it off.
var hand_off := true
var next_scene := ARENA_SCENE

var _t: Resource
var _link: Link
var _phase: Phase = Phase.DETECTING
var _routed := false
var _who := ""
var _link_ms := 0.0
var _spin_ms := 0.0
var _spin_at := 0
var _continue_ms := 0.0
var _left := false
var _skipped := false
var _loading := false
var _link_parked := false

var _lines: VBoxContainer
var _spinner: Label
var _gpu_label: Label
var _queue: Array[Label] = []
var _typed := 0.0
var _pause_ms := 0.0


func _ready() -> void:
	SettingsApply.apply_all(GameSettings.current(), get_tree())
	_t = usable_tuning(tuning)
	_link = Link.new()
	_link.detector = detector
	_link.adapter_factory = adapter_factory
	_link.settings_path = settings_path
	_link.load_port = load_port
	_link.demo = demo
	_link.gpu_interval_ms = _t.gpu_interval_ms
	_link.start()
	demo = _link.demo
	_build_screen()
	if DisplayServer.get_name() == "headless" and _link.is_inert():
		print("SIGKILL boot: headless run, AI link skipped, straight to the arena")
		_leave.call_deferred(false)
		return
	if hand_off and next_scene != "":
		_loading = ResourceLoader.load_threaded_request(next_scene) == OK
	_say(TITLE, _t.title_color, _t.title_font_size)


func _process(delta: float) -> void:
	var ms := delta * 1000.0
	_type(delta)
	if not _left:
		_link.poll(ms)
		_show_gpu()
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
			if _link.is_ready() and not _routed:
				_routed = true
				_route()
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
	# A link left for the arena keeps running there. Otherwise it is dropped for good, and
	# whatever it still runs is joined right here: the game is quitting, or the screen was
	# freed without leaving, and a root being torn down is no place to hand workers to.
	if _link != null and not _link_parked:
		_link.shut_down(null)


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


## How many GPU readings this screen's link has started.
func gpu_reads() -> int:
	return _link.gpu_reads if _link != null else 0


## True while a GPU reading is running on its worker.
func gpu_busy() -> bool:
	return _link != null and _link.gpu_busy()


## The adapter the handshake uses, or null.
func adapter() -> Variant:
	return _link.adapter if _link != null else null


## The link this screen made (the arena's HUD takes it over on handoff).
func link() -> Link:
	return _link


func is_guarded() -> bool:
	return _link != null and _link.is_guarded()


func is_choosing() -> bool:
	return _link != null and _link.is_choosing()


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


## Decides the lines and the next step once the link knows its adapter.
func _route() -> void:
	var found := _link.found
	if found == null:
		_say("AI link skipped: %s." % _link.skip_reason, _t.warn_color)
		_scripted()
		return
	if demo:
		_who = Link.DEMO_AGENT
		_say("Omarchy default agent: %s. Linking..." % Link.DEMO_AGENT)
		_begin_link()
		return
	var chosen = _link.adapter
	_say(_agent_line(found, chosen))
	if chosen == null:
		if _link.choose_failed or (_link.is_guarded() and found.source != Found.Source.SCRIPTED):
			_say("AI link skipped: %s." % _link.skip_reason, _t.warn_color)
		_scripted()
		return
	var local: bool = chosen.adapter_name() == "local"
	if local:
		_say(LOCAL_LINE)
	_who = "the local model server" if local else String(chosen.adapter_name())
	match _link.consent():
		Settings.Answer.ALLOWED:
			_begin_link()
		Settings.Answer.DECLINED:
			_say("You said no to the AI link.")
			_scripted()
		_:
			_say("Allow SIGKILL to call %s? It gets only game stats and what you type." % _who, _t.prompt_color)
			_say(CONSENT_KEYS, _t.prompt_color)
			_phase = Phase.CONSENT


static func _agent_line(found: Found, chosen) -> String:
	var name := found.agent if Detector.KNOWN_AGENTS.has(found.agent) else ""
	if found.agent_state == Found.AgentState.KNOWN and name != "":
		if chosen != null and chosen.adapter_name() == name:
			return "Omarchy default agent: %s. Linking..." % name
		if not found.agent_cli_present:
			return "Omarchy default agent: %s, but its command is not installed." % name
		if not Registry.AGENT_ADAPTERS.has(name):
			return "Omarchy default agent: %s. No SIGKILL adapter for it yet." % name
		return "Omarchy default agent: %s." % name
	if found.agent_state == Found.AgentState.UNKNOWN or found.agent_state == Found.AgentState.KNOWN:
		return "Omarchy default agent: not one SIGKILL knows."
	return "Omarchy default agent: not set."


func _answer_consent(allowed: bool) -> void:
	var saved := _link.set_consent(allowed)
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
	var started := _link.ask(Request.build({}, HANDSHAKE_TEXT, _link.guide_tuning.typed_text_max_chars))
	if not started.is_empty():
		_link_done(started)


func _poll_link(ms: float) -> void:
	_link_ms += ms
	if demo:
		if _link_ms >= _t.demo_link_ms:
			_link_done({"ok": true, "text": DEMO_ANSWER, "error_kind": "", "latency_ms": _t.demo_latency_ms, "tokens_per_sec": -1.0})
		return
	var done := _link.poll_call()
	if not done.is_empty():
		_link_done(done)


func _link_done(done: Dictionary) -> void:
	_spinner.visible = false
	if demo:
		_link.last_call = {"ok": true, "error_kind": "", "latency_ms": _t.demo_latency_ms, "tokens_per_sec": -1.0}
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
	var kind := Link.error_word(done.get("error_kind", ""))
	if kind == "needs_consent":
		_link.not_loaded = true
		var hint := _link.load_hint()
		_say(NOT_LOADED_LINE + (LOAD_IN_ARENA if hint == "loadable" else LOAD_IN_OWN_APP if hint == "own_app" else ""), _t.warn_color)
	else:
		_say("No answer from %s (%s)." % [_who, kind], _t.warn_color)
	_scripted()


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


func _show_gpu() -> void:
	var text := Link.gpu_text(_link.gpu_reading())
	_gpu_label.text = text
	_gpu_label.visible = text != ""


func _leave(skipped: bool) -> void:
	if _left:
		return
	_left = true
	_skipped = skipped
	_spinner.visible = false
	if hand_off and next_scene != "":
		# The link goes on to the arena's HUD; anything it had half done is handed off.
		_link.pause(get_tree().root)
		Link.park(_link)
		_link_parked = true
	else:
		_link.shut_down(get_tree().root)
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
