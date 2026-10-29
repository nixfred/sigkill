extends RefCounted
## The end of a round (C12, PRD 5.4): one line for the summary panel, in the player's own
## AI's words or in SIGKILL's.
##
## At most one AI call per round end, through the session's GuideLink and the C9b request
## builder: the round's numbers as whitelisted stats, no typed text, and the game's own
## fixed coach or roast task (roast only when the player turned the announcer on with B).
## The call is skipped, and SIGKILL's own line shown instead, when the link's gate refuses
## it: AI off, a call already in flight, the minimum interval since the last call, the
## session's cap on calls, still linking, or no AI (always so under the headless guard
## unless a test handed one in). A timeout, an error or an empty answer gets SIGKILL's
## line too. The next round never waits: when the break ends with the call still out, the
## call is stopped and whatever it would have said is dropped, never shown.
##
## What the AI says is shown as plain text only: escape sequences, control and invisible
## characters stripped (the adapter's clean_answer), markup tags such as [b] dropped, all
## on one line, cut to text_max_chars (never over 240).
##
## Demo data (--demo): fake stats with a fake roast and a fake tip; no call, no settings
## read, no process, no network.

const Request = preload("res://scripts/ai/guide_request.gd")
const Adapter = preload("res://scripts/ai/guide_adapter.gd")
const Link = preload("res://scripts/guide/guide_link.gd")
const TuningScript = preload("res://scripts/round/announcer_tuning.gd")

const DEMO_STATS := {"deaths": 2, "round_number": 3, "duration_s": 90.0, "shots": 41, "hits": 17, "accuracy_pct": 41.5, "derezzes": 9, "longest_streak": 4, "time_to_first_derezz_s": 6.2, "distance_m": 312.4, "slides": 7, "jumps": 12}
const DEMO_ROAST := "Demo mode: 41 shots, 17 hits. The walls are filing a complaint."
const DEMO_TIP := "Demo mode: fire in short bursts and let the crosshair settle; your streaks die on the third shot."
## Markup tags such as [b], [/i] or [color=red] in what the AI says. A Label never parses
## them; they are dropped so only plain words reach the screen.
const MARKUP := "\\[/?[A-Za-z][^\\[\\]\\n]{0,63}\\]"
const MARKUP_PASSES := 8
## The answer is cleaned at up to this many times the cap, before tags and spaces go.
const CLEAN_SLACK := 4
## Why SIGKILL speaks instead of the player's AI, by the gate's or the call's word.
const REASONS := {
	"off": "AI off",
	"busy": "your AI was busy",
	"cooldown": "too soon after the last call",
	"cap": "session limit reached",
	"linking": "still linking",
	"guarded": "no AI linked",
	"no_ai": "no AI linked",
	"timeout": "no answer in time",
	"empty": "empty answer",
	"stopped": "the call was stopped",
	"cancelled": "the call was stopped",
	"ai_off": "AI off",
	"rate_limited": "too soon after the last call",
	"unavailable": "your AI is not available",
	"needs_consent": "no model loaded",
}
## Less than this many metres in a round counts as standing still.
const STILL_M := 2.0
## This many deaths in a round and SIGKILL's own line is about them (C27b).
const DEATHS_NOTED := 3

## Where the round's line stands: "" (none), "thinking", "ai" (their AI's words), "game"
## (SIGKILL's own line) or "demo".
var state := ""
## "coach" or "roast", the task this round's line was for.
var task := ""
## The line shown: the AI's words, cleaned, or SIGKILL's.
var text := ""
## Why the line is SIGKILL's, as a word ("off", "cooldown", "timeout", ...), or "".
var reason := ""
## The numbers the panel shows: the round's own, or the demo's.
var payload := {}
## AI calls started at round ends, and late ones dropped, this link's whole session.
var asks := 0
var dropped := 0

var _link: Link
var _cap := 1
var _max_chars := TuningScript.TEXT_LAST
var _asked_round := 0
## The link's call_serial when this round's call started: the call is ours only while the
## link's still matches.
var _serial := -1


func _init(link: Link, cap: int, max_chars: int) -> void:
	_link = link
	_cap = maxi(cap, 1)
	_max_chars = clampi(max_chars, 0, TuningScript.TEXT_LAST)


## The round is over: starts its one call, or picks SIGKILL's line at once. `extra` rides along in the
## request only (I2: the ICEbreaker pick's numbers, which add the pick's line to the instructions); the
## panel's numbers stay the round's own.
func round_ended(stats: Dictionary, extra: Dictionary = {}) -> void:
	if state == "thinking":
		intermission_over()
	text = ""
	reason = ""
	if _link.demo:
		task = "roast" if _link.roast_on() else "coach"
		payload = DEMO_STATS.duplicate()
		state = "demo"
		return
	task = "roast" if _link.roast_on() else "coach"
	payload = stats.duplicate()
	var number := int(stats.get("round_number", 0))
	var word: String = _link.refusal(_cap)
	if word == "" and number == _asked_round:
		word = "busy"  # never a second call for the same round
	if word != "":
		_scripted(word)
		return
	_asked_round = number
	stats = stats.merged(extra)  # the ICEbreaker pick's numbers ride in the request only (I2)
	var started: Dictionary = _link.ask(Request.build(stats, "", 0, task))
	if not started.is_empty():
		_scripted(Link.error_word(started.get("error_kind", "")))
		return
	asks += 1
	_serial = _link.call_serial
	state = "thinking"


## Moves a call in flight on. Call once a frame during the break.
func poll() -> void:
	if state != "thinking":
		return
	if _link.call_serial != _serial:
		_scripted("stopped")  # stopped from outside, and maybe another call started since
		return
	var done: Dictionary = _link.poll_call()
	if done.is_empty():
		if not _link.is_busy():
			_scripted("stopped")
		return
	var answer = done.get("text", "")
	if done.get("ok", false) and answer is String:
		var clean := shown_text(answer, _max_chars)
		if clean != "":
			text = clean
			state = "ai"
			return
		_scripted("empty")
		return
	_scripted(Link.error_word(done.get("error_kind", "")))


## The break is over and the next round starts now: our call still out is stopped and its
## answer dropped. A call that is not ours is never touched.
func intermission_over() -> void:
	if state == "thinking" and _link.call_serial == _serial:
		_link.cancel_call()
		dropped += 1
	state = ""
	text = ""
	reason = ""


## Who says the line, for the panel: their AI by name, or SIGKILL with the reason.
func title() -> String:
	match state:
		"thinking":
			return "your AI (%s) is thinking" % _link.display_name()
		"ai", "demo":
			return "your AI (%s) %s:" % [_link.display_name(), "roasts" if task == "roast" else "coaches"]
		"game":
			return "SIGKILL says (%s):" % REASONS.get(reason, "no answer: " + reason)
	return ""


func _scripted(word: String) -> void:
	reason = word if word != "" else "error"
	text = scripted_line(payload, task == "roast")
	state = "game"


## What the AI said, as one plain line: escape sequences, control and invisible characters
## stripped, markup tags dropped, every run of spaces and line breaks one space, at most
## `max_chars` (never over 240) characters.
static func shown_text(raw: String, max_chars: int) -> String:
	var cap := clampi(max_chars, 0, TuningScript.TEXT_LAST)
	var clean := Adapter.clean_answer(raw.to_utf8_buffer(), cap * CLEAN_SLACK)
	var markup := RegEx.create_from_string(MARKUP)
	for i in MARKUP_PASSES:
		var fewer := markup.sub(clean, "", true)
		if fewer == clean:
			break
		clean = fewer
	if markup.search(clean) != null:
		clean = clean.replace("[", "").replace("]", "")  # nested past every pass: no brackets
	clean = " ".join(clean.replace("\n", " ").split(" ", false))
	return clean.left(cap).strip_edges()


## SIGKILL's own line for a round, from its numbers: a tip, or a roast of the play.
static func scripted_line(stats: Dictionary, roast: bool) -> String:
	var shots := int(stats.get("shots", 0))
	var accuracy := float(stats.get("accuracy_pct", 0.0))
	var down := int(stats.get("derezzes", 0))
	var best := int(stats.get("longest_streak", 0))
	var moves := int(stats.get("slides", 0)) + int(stats.get("jumps", 0))
	var still := float(stats.get("distance_m", 0.0)) < STILL_M
	var deaths := int(stats.get("deaths", 0))
	if roast:
		if shots == 0:
			return "Zero shots fired. The processes thank you for your mercy."
		if deaths >= DEATHS_NOTED:
			return "Derezzed %d times in one round. The daemons are starting a fan club." % deaths
		if down == 0:
			return "%d shots and not one process down. They are still running, and so is the clock." % shots
		if accuracy < 35.0:
			return "%d%% accuracy. The walls took more damage than the processes." % roundi(accuracy)
		if still:
			return "You barely moved all round. The dummies are bolted down and still covered more ground."
		if moves == 0:
			return "Not one jump or slide all round. Gravity sends its thanks."
		return "%d down, best streak %d. Respectable, for a screensaver." % [down, best]
	if shots == 0:
		return "No shots this round. Find a process and fire: the cannon is the left mouse button."
	if deaths >= DEATHS_NOTED:
		return "Derezzed %d times. Watch the tells and step aside: a rear-up, a raised claw, a swarm pulling tight." % deaths
	if down == 0:
		return "No process went down. Aim at the middle of a dummy and fire while the crosshair is still."
	if accuracy < 35.0:
		return "Accuracy %d%%. Fire after the crosshair settles, not while you turn." % roundi(accuracy)
	if still:
		return "You barely moved all round. Run between targets so the next one is always close."
	if moves == 0:
		return "No jumps or slides this round. Slide with C between targets to cross the arena faster."
	return "%d down, best streak %d. Next round, chain your hits: every miss resets the streak." % [down, best]
