extends Control
## The guide HUD (PRD 5.4, chunk C11): proof in the arena that the guide is the player's
## own AI. Top right: a "your AI" badge (the agent's name from the player's Omarchy
## setting, "local", or "AI off"), the last call's latency, tokens per second only when
## the local server answered and reported its own token count, the live GPU readout, and
## a status line: the keys, a "thinking" spinner while a call is in flight, the cooldown
## or "limit reached" when the key would be refused. Bottom centre: a panel for the ask
## box, the AI's answer, short SIGKILL notices and the opt-in question.
##
## T opens the ask box (one capped line). While it is open the mouse is free and the
## player takes no game input at all; Enter sends, Esc cancels, and either way the mouse
## is captured again only if it was before and the window still has focus. What was typed
## goes out through the C9b request builder with whitelisted game stats only. The answer
## is the one place the AI's own words reach the screen, because the player asked: shown
## as plain text in a Label (never parsed as BBCode or rich text), with escape sequences,
## control and invisible characters stripped by the adapter's clean_answer(), and cut to
## answer_max_chars and answer_max_lines, under a title naming it as their AI. A timeout
## or an error shows a fixed SIGKILL line instead.
##
## O turns the AI on or off through the same opt-in setting the boot screen uses
## (user://settings.cfg). Off means no calls and "AI off"; on asks first, by name, Y or N.
## Plain keys only: Ctrl, Alt and Super chords are ignored.
##
## Rate limits: one call in flight, the guide tuning's minimum interval, and a cap on calls
## per game session (HudTuning.session_call_cap, the boot handshake included).
##
## The AI side is the session's GuideLink (scripts/guide/guide_link.gd), taken over from
## the boot screen, or made here when there is none, with the same headless guard and demo
## data. When R reloads the arena this HUD parks it for the next one; when the window is
## closed it shuts it down.

const HudTuningScript = preload("res://scripts/hud/hud_tuning.gd")
const Link = preload("res://scripts/guide/guide_link.gd")
const Settings = preload("res://scripts/boot/guide_settings.gd")
const Request = preload("res://scripts/ai/guide_request.gd")
const Adapter = preload("res://scripts/ai/guide_adapter.gd")
const Palette = preload("res://scripts/palette.gd")

const DEFAULT_TUNING_PATH := "res://resources/hud.tres"
const BADGE_PREFIX := "your AI: "
const LINKING := "your AI: linking..."
const AI_OFF := "AI off"
const KEYS_LINE := "T ask your AI   O AI on/off"
const TYPING_LINE := "Enter sends   Esc cancels"
const ASK_TITLE := "ask your AI"
const NOTICE_TITLE := "SIGKILL"
const CONSENT_KEYS := "[Y] allow   [N] keep AI off"
const OFF_LINE := "AI off. Press O to turn it on."
const NO_AI_LINE := "No AI linked. The scripted guide is here."
const LINKING_LINE := "Linking your AI..."
const BUSY_LINE := "Your AI is still thinking."
const NOT_LOADED_LINE := "Local model available, not loaded."
const DEMO_ANSWER := "Demo mode: this is where your AI answers you, in its own words."
const SPINNER := ["|", "/", "-", "\\"]
const WEAPON := "terminal_cannon"
const MODE := "practice"
const ROUND_SECONDS_LAST := 86400.0

# Set these before the node enters the tree; the defaults are the real ones.
## HudTuning; null for resources/hud.tres.
var tuning: Resource = null
## The GuideLink to use. Null: the one the boot screen parked, or a new one.
var link = null
## For a link this HUD makes itself (tests): the same injection points as the boot screen.
var detector = null
var adapter_factory := Callable()
var settings_path := Settings.DEFAULT_PATH
var demo := false
## The player, whose input is blocked while the ask box is open.
var player: Node = null
## () -> bool, whether the window has focus. Empty: the window's own answer.
var focus_check := Callable()

var _t: Resource
var _link: Link
var _typing := false
var _was_captured := false
var _asking := false
var _consent_prompt := false
var _demo_wait_ms := 0.0
var _answer_ms_left := 0.0
var _notice_ms_left := 0.0
var _spin_ms := 0.0
var _spin_at := 0
var _quitting := false
var _round_s := 0.0
var _kills := 0
var _targets_left := -1
var _recaptures := 0

var _column: VBoxContainer
var _badge: Label
var _latency: Label
var _gpu: Label
var _status: Label
var _panel: PanelContainer
var _title: Label
var _body: Label
var _edit: LineEdit


func _ready() -> void:
	_t = usable_tuning(tuning)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_link = link if link != null else Link.take_parked()
	if _link == null:
		_link = Link.new()
		_link.detector = detector
		_link.adapter_factory = adapter_factory
		_link.settings_path = settings_path
		_link.demo = demo
		_link.start()
	_link.gpu_interval_ms = _t.gpu_interval_ms
	demo = _link.demo
	_build()
	get_viewport().size_changed.connect(_fit_panel)
	_refresh()


func _process(delta: float) -> void:
	var ms := delta * 1000.0
	_round_s = minf(_round_s + delta, ROUND_SECONDS_LAST)
	_link.poll(ms)
	_poll_call(ms)
	if _answer_ms_left > 0.0:
		_answer_ms_left -= ms
	if _notice_ms_left > 0.0:
		_notice_ms_left -= ms
	if _asking:
		_spin_ms += ms
		if _spin_ms >= _t.spinner_frame_ms:
			_spin_ms = 0.0
			_spin_at = (_spin_at + 1) % SPINNER.size()
	_refresh()


func _input(event: InputEvent) -> void:
	# While the ask box is open, Esc closes it before anything else sees the key.
	if not _typing:
		return
	var key := event as InputEventKey
	if key != null and key.pressed and not key.echo and key.keycode == KEY_ESCAPE:
		get_viewport().set_input_as_handled()
		_close_ask()


func _unhandled_input(event: InputEvent) -> void:
	if _typing:
		return
	var key := event as InputEventKey
	if key == null or not key.pressed or key.echo:
		return
	if key.ctrl_pressed or key.alt_pressed or key.meta_pressed:
		return  # plain keys only
	if _consent_prompt:
		if key.keycode == KEY_Y or key.keycode == KEY_N:
			get_viewport().set_input_as_handled()
			_answer_consent(key.keycode == KEY_Y)
		return
	if event.is_action_pressed("ask_ai", false, true):
		get_viewport().set_input_as_handled()
		open_ask()
	elif event.is_action_pressed("toggle_ai", false, true):
		get_viewport().set_input_as_handled()
		toggle_ai()


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		_quitting = true


func _exit_tree() -> void:
	_block_player(false)
	if _link == null:
		return
	if _quitting or not is_inside_tree():
		_link.shut_down(null)
		return
	# R reloads the arena: the next HUD takes the link on.
	_asking = false
	_link.pause(get_tree().root, true)
	Link.park(_link)


static func usable_tuning(candidate: Resource) -> Resource:
	if candidate is HudTuningScript:
		var issues: PackedStringArray = candidate.problems()
		if issues.is_empty():
			return candidate
		for issue in issues:
			push_warning("hud tuning: " + issue + "; using the shipped tuning instead")
	var shipped = load(DEFAULT_TUNING_PATH)
	if shipped is HudTuningScript and shipped.problems().is_empty():
		return shipped
	return HudTuningScript.new()


## The game stats a question carries, all in the C9b whitelist.
func game_stats() -> Dictionary:
	var stats := {"weapon": WEAPON, "mode": MODE, "round_seconds": snappedf(_round_s, 0.1), "kills": _kills}
	if _targets_left >= 0:
		stats["targets_left"] = _targets_left
	if player != null:
		var shots: int = player.get("shots_fired") if player.get("shots_fired") is int else 0
		var hits: int = player.get("hits_landed") if player.get("hits_landed") is int else 0
		stats["shots_fired"] = shots
		stats["hits_landed"] = hits
		if shots > 0:
			stats["accuracy_percent"] = snappedf(100.0 * hits / shots, 0.1)
	return stats


func note_kill() -> void:
	_kills += 1


func set_targets_left(remaining: int) -> void:
	_targets_left = maxi(remaining, 0)


func is_typing() -> bool:
	return _typing


func is_asking() -> bool:
	return _asking


func is_asking_consent() -> bool:
	return _consent_prompt


func session_link() -> Link:
	return _link


## Everything shown, for tests: badge, latency, GPU, status, panel title and body.
func shown_text() -> PackedStringArray:
	var out := PackedStringArray()
	for label in [_badge, _latency, _gpu, _status, _title, _body]:
		if label != null and label.is_visible_in_tree():
			out.append(label.text)
	return out


func badge_text() -> String:
	return _badge.text


func latency_text() -> String:
	return _latency.text if _latency.visible else ""


func gpu_text() -> String:
	return _gpu.text if _gpu.visible else ""


func status_text() -> String:
	return _status.text


func panel_text() -> String:
	return (_title.text + "\n" + _body.text) if _panel.visible else ""


func answer_label() -> Label:
	return _body


func recaptures() -> int:
	return _recaptures


## Opens the ask box, or says why not.
func open_ask() -> void:
	if _typing or _consent_prompt:
		return
	var reason := _refusal()
	if reason != "":
		_notice(reason, _t.off_color)
		return
	_typing = true
	_was_captured = _mouse_captured()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_block_player(true)
	_answer_ms_left = 0.0
	_notice_ms_left = 0.0
	_title.text = ASK_TITLE
	_title.add_theme_color_override("font_color", _t.badge_color)
	_body.visible = false
	_edit.text = ""
	_edit.max_length = mini(_t.ask_max_chars, _link.guide_tuning.typed_text_max_chars)
	_edit.visible = true
	_edit.editable = true
	_edit.grab_focus()
	_refresh()


## O: off at once; on only after the player's yes, asked by name.
func toggle_ai() -> void:
	if _typing or _consent_prompt:
		return
	if demo:
		_link.set_consent(not _link.ai_on())
		_notice("AI on." if _link.ai_on() else "AI off.", _t.badge_color)
		return
	if not _link.is_ready():
		_notice(LINKING_LINE, _t.off_color)
		return
	if _link.adapter == null:
		_notice(NO_AI_LINE, _t.off_color)
		return
	if _link.ai_on():
		_asking = false
		var saved := _link.set_consent(false)
		_notice("AI off. Your AI will not be called." if saved else "AI off for now. It could not be saved, so the boot screen will ask again.", _t.off_color)
		return
	_consent_prompt = true
	_answer_ms_left = 0.0
	_notice_ms_left = 0.0
	_title.text = NOTICE_TITLE
	_title.add_theme_color_override("font_color", _t.off_color)
	_body.text = "Allow SIGKILL to call %s? It gets only game stats and what you type.\n%s" % [_who_long(), CONSENT_KEYS]
	_body.add_theme_color_override("font_color", _t.off_color)
	_body.visible = true
	_refresh()


func _answer_consent(allowed: bool) -> void:
	_consent_prompt = false
	var saved := _link.set_consent(allowed)
	if allowed:
		_notice("AI on. T asks your AI." if saved else "AI on for now. It could not be saved, so you will be asked again.", _t.badge_color)
	else:
		_notice("AI stays off.", _t.off_color)


func _send(text: String) -> void:
	_close_ask()
	if text.strip_edges().is_empty():
		return
	var reason := _refusal()
	if reason != "":
		_notice(reason, _t.off_color)
		return
	_spin_at = 0
	if demo:
		_asking = true
		_demo_wait_ms = _t.demo_answer_ms
		return
	var cap := mini(_t.ask_max_chars, _link.guide_tuning.typed_text_max_chars)
	var started := _link.ask(Request.build(game_stats(), text, cap))
	if started.is_empty():
		_asking = true
		return
	match Link.error_word(started.get("error_kind", "")):
		"busy":
			_notice(BUSY_LINE, _t.off_color)
		"rate_limited":
			_notice(_cooldown_line(), _t.off_color)
		"ai_off":
			_notice(OFF_LINE, _t.off_color)
		var kind:
			_show_failure(kind)


func _close_ask() -> void:
	if not _typing:
		return
	_typing = false
	_edit.release_focus()
	_edit.visible = false
	_edit.editable = false
	_block_player(false)
	if _was_captured and _focused():
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		_recaptures += 1
	_was_captured = false
	_refresh()


func _poll_call(ms: float) -> void:
	if not _asking:
		return
	if demo:
		_demo_wait_ms -= ms
		if _demo_wait_ms <= 0.0:
			_asking = false
			_link.last_call = {"ok": true, "error_kind": "", "latency_ms": _t.demo_latency_ms, "tokens_per_sec": -1.0}
			_show_answer(DEMO_ANSWER)
		return
	var done := _link.poll_call()
	if done.is_empty():
		if not _link.is_busy():
			_asking = false  # stopped from outside (the AI was turned off)
		return
	_asking = false
	var text = done.get("text", "")
	if done.get("ok", false) and text is String:
		_show_answer(text)
	else:
		_show_failure(Link.error_word(done.get("error_kind", "")))


## The AI's own words, as plain text: escape sequences, control and invisible characters
## stripped, cut to the tuning's characters and lines.
func _show_answer(text: String) -> void:
	var clean := Adapter.clean_answer(text.to_utf8_buffer(), _t.answer_max_chars)
	var lines := clean.split("\n")
	if lines.size() > _t.answer_max_lines:
		clean = "\n".join(lines.slice(0, _t.answer_max_lines)).strip_edges()
	if clean.is_empty():
		_show_failure("empty")
		return
	_title.text = "your AI (%s) says:" % _link.display_name()
	_title.add_theme_color_override("font_color", _t.badge_color)
	_body.text = clean
	_body.add_theme_color_override("font_color", _t.text_color)
	_body.visible = true
	_answer_ms_left = _t.answer_ms
	_notice_ms_left = 0.0


func _show_failure(kind: String) -> void:
	var line := "No answer from your AI (%s). The scripted guide is still here." % kind
	if kind == "needs_consent":
		line = NOT_LOADED_LINE
	elif kind == "ai_off":
		line = OFF_LINE
	_notice(line, _t.warn_color, _t.answer_ms)


func _notice(text: String, color: Color, ms: float = -1.0) -> void:
	_title.text = NOTICE_TITLE
	_title.add_theme_color_override("font_color", color)
	_body.text = text
	_body.add_theme_color_override("font_color", color)
	_body.visible = true
	_answer_ms_left = 0.0
	_notice_ms_left = ms if ms > 0.0 else float(_t.notice_ms)
	_refresh()


## Why T would be refused right now, or "".
func _refusal() -> String:
	if demo:
		return "" if _link.ai_on() else OFF_LINE
	if not _link.is_ready():
		return LINKING_LINE
	if _link.adapter == null:
		return NO_AI_LINE
	if not _link.ai_on():
		return OFF_LINE
	if _asking or _link.is_busy():
		return BUSY_LINE
	if _link.calls >= _t.session_call_cap:
		return "Limit reached: %d AI calls this session." % _t.session_call_cap
	if _link.cooldown_ms() > 0:
		return _cooldown_line()
	return ""


func _cooldown_line() -> String:
	return "Next ask in %d s." % maxi(1, ceili(_link.cooldown_ms() / 1000.0))


func _who_long() -> String:
	return "the local model server" if _link.is_local() else _link.display_name()


func _mouse_captured() -> bool:
	if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		return true
	return player != null and player.get("assume_captured") == true


func _focused() -> bool:
	if not focus_check.is_null():
		return focus_check.call()
	return get_window().has_focus()


func _block_player(on: bool) -> void:
	if player != null and is_instance_valid(player) and "input_blocked" in player:
		player.input_blocked = on


func _refresh() -> void:
	if _badge == null:
		return
	var on := _link.ai_on()
	if not _link.is_ready():
		_badge.text = LINKING
		_badge.add_theme_color_override("font_color", _t.text_color)
	elif on and _link.display_name() != "":
		_badge.text = BADGE_PREFIX + _link.display_name()
		_badge.add_theme_color_override("font_color", _t.badge_color)
	else:
		_badge.text = AI_OFF
		_badge.add_theme_color_override("font_color", _t.off_color)
	var call := _link.last_call
	if call.is_empty():
		_latency.visible = false
	else:
		var line := "last call %d ms" % int(call.get("latency_ms", -1))
		var rate := float(call.get("tokens_per_sec", -1.0))
		if call.get("ok", false) and _link.is_local() and is_finite(rate) and rate > 0.0:
			line += "   %.1f tok/s" % rate
		elif not call.get("ok", false):
			line += " (%s)" % Link.error_word(call.get("error_kind", ""))
		_latency.text = line
		_latency.visible = true
	var gpu := Link.gpu_text(_link.gpu_reading())
	_gpu.text = gpu
	_gpu.visible = gpu != ""
	if _typing:
		_status.text = TYPING_LINE
	elif _asking:
		_status.text = "thinking  %s   waiting for your AI" % SPINNER[_spin_at]
	elif _consent_prompt:
		_status.text = CONSENT_KEYS
	else:
		var reason := _refusal()
		_status.text = KEYS_LINE if reason == "" else reason
	_panel.visible = _typing or _consent_prompt or _answer_ms_left > 0.0 or _notice_ms_left > 0.0


func _build() -> void:
	_column = VBoxContainer.new()
	_column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_column)
	_column.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT, Control.PRESET_MODE_MINSIZE, _t.margin)
	_column.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	_badge = _label(_column, _t.badge_font_size, _t.badge_color)
	_latency = _label(_column, _t.line_font_size, _t.text_color)
	_gpu = _label(_column, _t.line_font_size, _t.text_color)
	_status = _label(_column, _t.line_font_size, _t.text_color)
	for label in [_badge, _latency, _gpu, _status]:
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_panel = PanelContainer.new()
	_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style := StyleBoxFlat.new()
	style.bg_color = Color(Palette.VOID, _t.panel_alpha)
	style.border_color = _t.badge_color
	style.set_border_width_all(1)
	style.set_content_margin_all(10)
	_panel.add_theme_stylebox_override("panel", style)
	add_child(_panel)
	var stack := VBoxContainer.new()
	stack.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel.add_child(stack)
	_title = _label(stack, _t.line_font_size, _t.badge_color)
	_body = _label(stack, _t.answer_font_size, _t.text_color)
	_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_edit = LineEdit.new()
	_edit.add_theme_font_override("font", Palette.mono_font())
	_edit.add_theme_font_size_override("font_size", _t.answer_font_size)
	_edit.context_menu_enabled = false
	_edit.visible = false
	_edit.editable = false
	_edit.text_submitted.connect(_send)
	stack.add_child(_edit)
	_panel.visible = false
	_fit_panel()


## The panel: centred at the bottom, above the arena's hint line, as wide as the tuning
## says but never wider than the screen, growing upwards as its text grows.
func _fit_panel() -> void:
	if _panel == null:
		return
	var screen := get_viewport_rect().size
	var width := mini(_t.panel_width, int(screen.x) - 2 * _t.margin)
	_panel.custom_minimum_size = Vector2(maxi(width, 0), 0)
	_panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM, Control.PRESET_MODE_MINSIZE, _t.margin)
	_panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_panel.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_panel.position.y -= _t.panel_bottom_gap


func _label(parent: Control, size: int, color: Color) -> Label:
	var label := Label.new()
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_override("font", Palette.mono_font())
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_outline_color", Palette.VOID)
	label.add_theme_constant_override("outline_size", 4)
	parent.add_child(label)
	return label
