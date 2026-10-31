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
## Loading a model (C11b): when the AI is on and the local Ollama server has nothing loaded,
## T offers to load one instead: the link re-reads what is loaded, picks one candidate, and
## the panel asks "Load <name> (<size>) on your local server?" with Y (load) and N or Esc
## (keep AI off). Y loads it on a worker with a spinner; Esc stops waiting, and the link
## unloads that model if it turns up. The answer is for this session only. Other local
## servers get a hint to load a model in their own app. In demo-data mode L shows the same
## question and a fake load, with no network.
##
## The AI side is the session's GuideLink (scripts/guide/guide_link.gd), taken over from
## the boot screen, or made here when there is none, with the same headless guard and demo
## data. When R reloads the arena this HUD parks it for the next one; when the window is
## closed it shuts it down.
##
## Black ICE (I3): from its arrival until it is gone the guide's link shows cut: the badge reads "LINK
## CUT" in Black ICE's colour, flickering, the latency and GPU lines go dark and the status line reads "NO
## CARRIER". Cosmetic only: no call is made or cancelled because of it, T still asks and an answer still
## shows; it comes back when Black ICE is gone.
##
## SIGHUP (C32): while another player's SIGHUP has this player confused (its hup_left), the link shows hung
## up the same way: the badge "HUNG UP" in the carrier's colour, flickering, the latency and GPU lines dark,
## the status line a redial. Black ICE's cut wins when both hold. Cosmetic only, as the cut is.

const HudTuningScript = preload("res://scripts/hud/hud_tuning.gd")
const Link = preload("res://scripts/guide/guide_link.gd")
const Settings = preload("res://scripts/boot/guide_settings.gd")
const Request = preload("res://scripts/ai/guide_request.gd")
const Adapter = preload("res://scripts/ai/guide_adapter.gd")
const Palette = preload("res://scripts/palette.gd")
const BreakerPick = preload("res://scripts/ice/breaker_pick.gd")

const DEFAULT_TUNING_PATH := "res://resources/hud.tres"
const BADGE_PREFIX := "your AI: "
const LINKING := "your AI: linking..."
const AI_OFF := "AI off"
const KEYS_LINE := "T ask your AI   O AI on/off"
const TYPING_LINE := "Enter sends   Esc cancels"
const ASK_TITLE := "ask your AI"
const NOTICE_TITLE := "SIGKILL"
## A story line's title (C35): the one voice, with no agent's name and no live mark, since no AI wrote it.
const STORY_TITLE := "your AI"
const CONSENT_KEYS := "[Y] allow   [N] keep AI off"
const OFF_LINE := "AI off. Press O to turn it on."
const NO_AI_LINE := "No AI linked. The scripted guide is here."
const LINKING_LINE := "Linking your AI..."
const BUSY_LINE := "Your AI is still thinking."
const NOT_LOADED_LINE := "Local model available, not loaded."
const LOADS_ONE := "   T loads one"
const OWN_APP := "   Load one in your local server's own app."
const LOAD_KEYS := "[Y] load   [N] keep AI off"
const CHECKING_LINE := "Checking which models your local server has..."
const NONE_FITS_LINE := "No chat model on your local server fits here (under %s and your free VRAM). The scripted guide is still here."
const LOAD_ERROR_LINE := "Could not read your local server's models. The scripted guide is still here."
const LOADED_LINE := "Model loaded. T asks your AI."
const LOADED_NOW_LINE := "A model is loaded on your local server now. T asks your AI."
const LOAD_TIMEOUT_LINE := "The model did not load in time. The scripted guide is still here."
const LOAD_FAILED_LINE := "The model did not load. The scripted guide is still here."
const NOT_LOADING_LINE := "Model not loaded. The scripted guide is still here."
const STOPPED_LINE := "Stopped waiting. If the model loads anyway, SIGKILL unloads it."
const LOADING_BUSY_LINE := "Your local server is loading a model."
const DEMO_LOAD_NAME := "demo-chat-small"
const DEMO_LOAD_BYTES := 4700000000
const DEMO_KEYS_LINE := "T ask your AI   O AI on/off   L demo model load"
const DEMO_ANSWER := "Demo mode: this is where your AI answers you, in its own words."
## The ICEbreaker pick (I2): the ask box's hint while breakers are carried, and the scripted guide's
## pick as it follows any line that is not the AI's own.
const BREAKER_HINT := "   (Enter alone: which breaker to load)"
const SCRIPTED_PICK := "Scripted guide: %s"
const DEMO_PICK := "Demo mode: %s"
## The link cut by Black ICE (I3): the badge, the status line, how fast the badge flickers.
const CUT_BADGE := "your AI: LINK CUT"
const CUT_STATUS := "NO CARRIER   Black ICE on the line"
const CUT_FLICKER_HZ := 9.0
## The link hung up by SIGHUP (C32): the badge and the status line.
const HUP_BADGE := "your AI: HUNG UP"
const HUP_STATUS := "SIGHUP   the line hung up, redialling..."
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
## Set by the multiplayer panel while its address box is open: T and O do nothing, since
## the player is typing an address and the input lock is that box's.
var other_box_open := false
## Set by the round HUD during the break between rounds, whose summary panel needs the room:
## the AI's answer to T is held back, hidden with its time on screen paused, and shows again
## when the break ends. Notices, the ask box and the questions still show.
var hold_answer := false
## The ICEbreakers' director (I2), set by the HUD: while breakers are carried a question carries the
## round's ICE and breaker numbers (scripts/ice/breaker_pick.gd) so the AI names a breaker to load, Enter
## with nothing typed asks for that pick alone, and every line that is not the AI's own (it is off,
## refused, silent) is followed by the scripted guide's pick.
var breakers: Node = null
## ICE's director (I3), set by the HUD: while its Black ICE is out the link shows cut.
var ice: Node = null

var _t: Resource
var _cut_clock := 0.0
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
## The model-load question: "", "checking", "prompt" or "loading". In demo mode it runs on
## its own timer, with no link and no network.
var _load_ui := ""
var _demo_load_ms := 0.0

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
	_cut_clock = fmod(_cut_clock + delta, 3600.0)
	_round_s = minf(_round_s + delta, ROUND_SECONDS_LAST)
	_link.poll(ms)
	_poll_call(ms)
	if _answer_ms_left > 0.0 and not hold_answer:
		_answer_ms_left -= ms
	if _notice_ms_left > 0.0:
		_notice_ms_left -= ms
	_poll_load_ui(ms)
	if _asking or _load_ui == "checking" or _load_ui == "loading":
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
	if _typing or other_box_open:
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
		elif key.keycode == KEY_ESCAPE:
			_esc_taken()  # the question's own: the mouse is freed, the Esc menu stays shut
			_consent_prompt = false
			_notice("AI stays off.", _t.off_color)
		return
	if _load_ui == "prompt":
		if key.keycode == KEY_Y:
			get_viewport().set_input_as_handled()
			_answer_load(true)
		elif key.keycode == KEY_N:
			get_viewport().set_input_as_handled()
			_answer_load(false)
		elif key.keycode == KEY_ESCAPE:
			_esc_taken()
			_answer_load(false)
		return
	if _load_ui == "loading" and key.keycode == KEY_ESCAPE:
		_esc_taken()
		_stop_waiting()
		return
	if demo and _load_ui == "" and key.keycode == KEY_L:
		get_viewport().set_input_as_handled()
		_start_demo_offer()
		return
	if event.is_action_pressed("ask_ai", false, true):
		get_viewport().set_input_as_handled()
		open_ask()
	elif event.is_action_pressed("toggle_ai", false, true):
		get_viewport().set_input_as_handled()
		toggle_ai()


## Esc that answered a question here is this HUD's (C16b): the mouse is freed as before,
## and the Esc menu does not open behind it.
func _esc_taken() -> void:
	get_viewport().set_input_as_handled()
	if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


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


## The drawn weapon's id (C16), or the cannon's when the player has none to tell.
func _weapon_id() -> String:
	if player != null and is_instance_valid(player) and player.has_method("weapon_tuning"):
		var id = player.weapon_tuning().get("id")
		if id is String and id != "":
			return id
	return WEAPON


## The game stats a question carries, all in the C9b whitelist.
func game_stats() -> Dictionary:
	var stats := {"weapon": _weapon_id(), "mode": MODE, "round_seconds": snappedf(_round_s, 0.1), "kills": _kills}
	if _targets_left >= 0:
		stats["targets_left"] = _targets_left
	if player != null:
		var shots: int = player.get("shots_fired") if player.get("shots_fired") is int else 0
		var hits: int = player.get("hits_landed") if player.get("hits_landed") is int else 0
		stats["shots_fired"] = shots
		stats["hits_landed"] = hits
		if shots > 0:
			stats["accuracy_percent"] = snappedf(100.0 * hits / shots, 0.1)
	stats.merge(BreakerPick.numbers(breakers))  # the ICEbreaker pick's numbers (I2), {} with none
	return stats


## True while breakers are carried (I2): the guide picks one to load.
func picks_breakers() -> bool:
	return not BreakerPick.numbers(breakers).is_empty()


## The scripted guide's pick now (I2): [the kind's name or "", its line].
func breaker_pick() -> Array:
	return BreakerPick.scripted(BreakerPick.numbers(breakers))


## `line`, followed by the scripted guide's breaker pick while breakers are carried (I2).
func _with_pick(line: String) -> String:
	return line + "\n" + SCRIPTED_PICK % breaker_pick()[1] if picks_breakers() else line


func note_kill() -> void:
	_kills += 1


## True while Black ICE has the guide's link cut (I3): from its arrival until it is gone.
func link_cut() -> bool:
	return ice != null and is_instance_valid(ice) and ice.has_method("black_out") and ice.black_out()


## True while another player's SIGHUP has this player confused (C32): the link shows hung up.
func link_hung_up() -> bool:
	if player == null or not is_instance_valid(player):
		return false
	var left = player.get("hup_left")
	return left is float and left > 0.0


func set_targets_left(remaining: int) -> void:
	_targets_left = maxi(remaining, 0)


func is_typing() -> bool:
	return _typing


func is_asking() -> bool:
	return _asking


func is_asking_consent() -> bool:
	return _consent_prompt


## True while the ask box, the opt-in question or the model-load question is up.
func is_prompting() -> bool:
	return _typing or _consent_prompt or _load_ui != ""


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


## Opens the ask box, or says why not; or, with nothing loaded on the local Ollama server,
## offers to load a model.
func open_ask() -> void:
	if _typing or other_box_open or _consent_prompt or _load_ui == "prompt":
		return
	if _load_ui == "checking" or _load_ui == "loading":
		_notice(LOADING_BUSY_LINE, _t.off_color)
		return
	if not demo and _link.is_ready() and _link.ai_on() and _link.not_loaded and _link.can_offer_load() and not _link.is_busy():
		_start_offer()
		return
	var reason := _refusal()
	if reason != "":
		_notice(_with_pick(reason), _t.off_color)
		return
	_typing = true
	_was_captured = _mouse_captured()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_block_player(true)
	_answer_ms_left = 0.0
	_notice_ms_left = 0.0
	_title.text = ASK_TITLE + (BREAKER_HINT if picks_breakers() else "")
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
	if _typing or other_box_open or _consent_prompt:
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
		_load_ui = ""
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


func _start_offer() -> void:
	if not _link.begin_offer():
		_notice(LOAD_ERROR_LINE, _t.warn_color)
		return
	_load_ui = "checking"
	_spin_at = 0
	_notice(CHECKING_LINE, _t.text_color, _t.answer_ms)


func _start_demo_offer() -> void:
	_load_ui = "prompt"
	_show_load_prompt(DEMO_LOAD_NAME, Link.Loader.size_text(DEMO_LOAD_BYTES))


func _show_load_prompt(name: String, size: String) -> void:
	_answer_ms_left = 0.0
	_notice_ms_left = 0.0
	_title.text = NOTICE_TITLE
	_title.add_theme_color_override("font_color", _t.off_color)
	_body.text = "Load %s (%s) on your local server?\n%s" % [name, size, LOAD_KEYS]
	_body.add_theme_color_override("font_color", _t.off_color)
	_body.visible = true
	_refresh()


func _answer_load(load_it: bool) -> void:
	if not load_it:
		_load_ui = ""
		if not demo:
			_link.decline_load()
		_notice(NOT_LOADING_LINE, _t.off_color)
		return
	_load_ui = "loading"
	_spin_at = 0
	if demo:
		_demo_load_ms = _t.demo_load_ms
		_notice("Loading %s on your local server..." % DEMO_LOAD_NAME, _t.text_color, _t.answer_ms)
		return
	if not _link.accept_load():
		_load_ui = ""
		_notice(LOAD_FAILED_LINE, _t.warn_color)
		return
	_notice("Loading %s on your local server..." % _link.offer_name(), _t.text_color, _t.answer_ms)


func _stop_waiting() -> void:
	_load_ui = ""
	if not demo:
		_link.cancel_load()
	_notice(STOPPED_LINE, _t.off_color)


## Follows the load question as the link's worker answers it.
func _poll_load_ui(ms: float) -> void:
	if _load_ui == "" or _load_ui == "prompt":
		return
	if demo:
		if _load_ui == "loading":
			_demo_load_ms -= ms
			if _demo_load_ms <= 0.0:
				_load_ui = ""
				_notice(LOADED_LINE, _t.badge_color)
		return
	match _link.load_state:
		"offer":
			if _load_ui == "checking":
				_load_ui = "prompt"
				_show_load_prompt(_link.offer_name(), _link.offer_size_text())
		"loaded_now":
			_load_ui = ""
			_notice(LOADED_NOW_LINE, _t.badge_color)
		"none_fits":
			_load_ui = ""
			_notice(NONE_FITS_LINE % Link.Loader.size_text(_link.guide_tuning.max_load_bytes), _t.off_color, _t.answer_ms)
		"loaded":
			_load_ui = ""
			_notice(LOADED_LINE, _t.badge_color)
		"timeout":
			_load_ui = ""
			_notice(LOAD_TIMEOUT_LINE, _t.warn_color, _t.answer_ms)
		"error":
			var was_loading := _load_ui == "loading"
			_load_ui = ""
			_notice(LOAD_FAILED_LINE if was_loading else LOAD_ERROR_LINE, _t.warn_color, _t.answer_ms)


func _answer_consent(allowed: bool) -> void:
	_consent_prompt = false
	var saved := _link.set_consent(allowed)
	if allowed:
		_notice("AI on. T asks your AI." if saved else "AI on for now. It could not be saved, so you will be asked again.", _t.badge_color)
	else:
		_notice("AI stays off.", _t.off_color)


func _send(text: String) -> void:
	_close_ask()
	# Nothing typed: nothing to ask, unless breakers are carried, when it asks for the pick alone (I2).
	if text.strip_edges().is_empty() and not picks_breakers():
		return
	var reason := _refusal()
	if reason != "":
		_notice(_with_pick(reason), _t.off_color)
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
			_show_answer(DEMO_PICK % breaker_pick()[1] if picks_breakers() else DEMO_ANSWER)
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


## Your AI's story line (C35: a mission's script, docs/STORY.md section 4), shown here as "your AI" for `ms` (the
## answer's time by default): the same for every player, never through the player's own AI and never sent anywhere.
## False, and nothing shown, while the panel is in use: the ask box, a question, a model load, a call in flight or a
## live answer still up; the mission tries it again.
func story_line(text: String, ms: float = -1.0) -> bool:
	if _typing or _consent_prompt or _load_ui != "" or _asking or (_answer_ms_left > 0.0 and _body.visible):
		return false
	_title.text = STORY_TITLE
	_title.add_theme_color_override("font_color", _t.badge_color)
	_body.text = text
	_body.add_theme_color_override("font_color", _t.text_color)
	_body.visible = true
	_answer_ms_left = 0.0
	_notice_ms_left = ms if ms > 0.0 else float(_t.answer_ms)
	_refresh()
	return true


func _show_failure(kind: String) -> void:
	var line := "No answer from your AI (%s). The scripted guide is still here." % kind
	if kind == "needs_consent":
		line = NOT_LOADED_LINE
	elif kind == "ai_off":
		line = OFF_LINE
	_notice(_with_pick(line), _t.warn_color, _t.answer_ms)


func _notice(text: String, color: Color, ms: float = -1.0) -> void:
	_title.text = NOTICE_TITLE
	_title.add_theme_color_override("font_color", color)
	_body.text = text
	_body.add_theme_color_override("font_color", color)
	_body.visible = true
	_answer_ms_left = 0.0
	_notice_ms_left = ms if ms > 0.0 else float(_t.notice_ms)
	_refresh()


## Why T would be refused right now, or "": the link's gate, shared with the round's end.
func _refusal() -> String:
	if demo:
		return "" if _link.ai_on() else OFF_LINE
	var word: String = _link.refusal(_t.session_call_cap)
	if _asking and (word == "" or word == "cap" or word == "cooldown"):
		word = "busy"
	match word:
		"linking":
			return LINKING_LINE
		"guarded", "no_ai":
			return NO_AI_LINE
		"off":
			return OFF_LINE
		"busy":
			return BUSY_LINE
		"cap":
			return "Limit reached: %d AI call%s this session." % [_t.session_call_cap, "" if _t.session_call_cap == 1 else "s"]
		"cooldown":
			return _cooldown_line()
	return ""


## The most AI calls in one game session, for the round's end to check against too.
func call_cap() -> int:
	return _t.session_call_cap


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
	elif _load_ui == "prompt":
		_status.text = LOAD_KEYS
	elif _load_ui == "checking":
		_status.text = "checking your local server  %s" % SPINNER[_spin_at]
	elif _load_ui == "loading":
		_status.text = "loading model  %s   Esc stops waiting" % SPINNER[_spin_at]
	else:
		var reason := _refusal()
		var line := (DEMO_KEYS_LINE if demo else KEYS_LINE) if reason == "" else reason
		if _link.not_loaded:
			# Stays up until a later call is answered or a model is loaded, with the way to
			# load one, next to any cooldown or limit.
			var hint := _link.load_hint()
			if hint == "loadable" and _link.ai_on():
				line = NOT_LOADED_LINE + LOADS_ONE
			else:
				line = NOT_LOADED_LINE + (OWN_APP if hint == "own_app" else "") + ("   " + reason if reason != "" else "")
		_status.text = line
	if link_cut():
		_badge.text = CUT_BADGE
		_badge.add_theme_color_override("font_color", Palette.BLACK_ICE_TEXT)
		_latency.visible = false
		_gpu.visible = false
		if not (_typing or _consent_prompt or _load_ui == "prompt"):
			_status.text = CUT_STATUS
	elif link_hung_up():
		_badge.text = HUP_BADGE
		_badge.add_theme_color_override("font_color", Palette.SIGHUP_TEXT)
		_latency.visible = false
		_gpu.visible = false
		if not (_typing or _consent_prompt or _load_ui == "prompt"):
			_status.text = HUP_STATUS
	_badge.modulate.a = (0.35 if fmod(_cut_clock * CUT_FLICKER_HZ, 1.0) < 0.3 else 1.0) if link_cut() or link_hung_up() else 1.0
	_panel.visible = _typing or _consent_prompt or _load_ui != "" or (_answer_ms_left > 0.0 and not hold_answer) or _notice_ms_left > 0.0


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
