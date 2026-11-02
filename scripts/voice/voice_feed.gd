class_name VoiceFeed
extends RefCounted
## Voice commands' feed (W7, PRD 5.5): the one address the game may ask for transcript lines, and what it makes of an
## answer. The game never opens a microphone, captures audio or links a speech library: another program already turned
## talk into text, and this only reads its lines.
##
## The address (the player's own setting, empty unless they set it) must be http on the loopback: 127.0.0.1, [::1] or
## localhost (asked for as 127.0.0.1, so no name is ever looked up), with an optional port and path. Anything else is
## refused with a plain line. The game only ever asks: it never listens on a port, never binds one, and follows no
## redirect.
##
## An answer is a JSON array of line objects (or an object holding one, under one of LIST_KEYS): an increasing `id`, the
## line's text under one of TEXT_KEYS, and `media`, a number: 0 or less is talk, 1 or 2 is a TV or other media playing,
## never acted on. A row without a usable id or media is skipped; unknown fields are ignored. Only rows newer than the
## last id seen count; the first answer only learns where the feed stands (nothing said before the game listened fires).
## digest() reads one answer whole and returns only numbers and command ids: every line's text is matched inside it and
## dropped there, never kept, printed, logged, shown or passed on.

const VoiceMatch = preload("res://scripts/voice/voice_match.gd")

## The fields a line's text may come under, first found wins (feeds name it differently).
const TEXT_KEYS := ["text", "transcript", "line", "content", "utterance", "message"]
## An object answer's list of lines, under one of these.
const LIST_KEYS := ["lines", "rows", "items", "data", "results", "transcripts"]
## The hosts the address may name, and what is asked for instead of each.
const HOSTS := {"127.0.0.1": "127.0.0.1", "localhost": "127.0.0.1", "[::1]": "[::1]"}
const SCHEME := "http://"
## The longest address the setting keeps (the settings file's longest string), and the biggest answer read (bytes).
const URL_LAST := 64
const BODY_LAST := 262144
## At most this many commands fire from one answer (a backlog never turns into a storm).
const COMMANDS_LAST := 3
## The plain refusals.
const REFUSED := "voice feed: loopback only (http on 127.0.0.1, ::1 or localhost)"
const TOO_LONG := "voice feed: at most 64 characters"


## {ok, why, url} for the address `text`: `url` is what is asked for (localhost as 127.0.0.1). `ok` false and `why` a
## plain line for anything that is not http on the loopback; "" (no feed) is not ok and has no why.
static func check(text: String) -> Dictionary:
	var url := text.strip_edges()
	if url == "":
		return {"ok": false, "why": "", "url": ""}
	if url.length() > URL_LAST:
		return {"ok": false, "why": TOO_LONG, "url": ""}
	for i in url.length():
		var c := url.unicode_at(i)
		if c <= 0x20 or c >= 0x7F or c == 0x22 or c == 0x27 or c == 0x5C or c == 0x60:
			return {"ok": false, "why": REFUSED, "url": ""}
	if not url.to_lower().begins_with(SCHEME):
		return {"ok": false, "why": REFUSED, "url": ""}
	var rest := url.substr(SCHEME.length())
	var cut := rest.length()
	for mark in ["/", "?", "#"]:
		var at := rest.find(mark)
		if at >= 0:
			cut = mini(cut, at)
	var authority := rest.substr(0, cut).to_lower()
	var tail := rest.substr(cut)
	if authority.contains("@") or authority == "":
		return {"ok": false, "why": REFUSED, "url": ""}
	var host := authority
	var port := ""
	if authority.begins_with("["):
		var close := authority.find("]")
		if close < 0:
			return {"ok": false, "why": REFUSED, "url": ""}
		host = authority.substr(0, close + 1)
		var after := authority.substr(close + 1)
		if after != "":
			if not after.begins_with(":"):
				return {"ok": false, "why": REFUSED, "url": ""}
			port = after.substr(1)
	elif authority.contains(":"):
		var at := authority.find(":")
		host = authority.substr(0, at)
		port = authority.substr(at + 1)
	if not HOSTS.has(host):
		return {"ok": false, "why": REFUSED, "url": ""}
	if authority.contains(":") and not authority.ends_with("]"):
		if port == "" or not port.is_valid_int() or port.length() > 5 or port.to_int() < 1 or port.to_int() > 65535:
			return {"ok": false, "why": REFUSED, "url": ""}
	var asked := SCHEME + str(HOSTS[host]) + (":" + str(port.to_int()) if port != "" else "")
	if tail == "" or tail.begins_with("?") or tail.begins_with("#"):
		tail = "/" + tail
	var fragment := tail.find("#")
	if fragment >= 0:
		tail = tail.substr(0, fragment)
	return {"ok": true, "why": "", "url": asked + tail}


## True for an address the setting may keep: empty (no feed) or one check() accepts.
static func setting_ok(text: String) -> bool:
	return text == "" or bool(check(text)["ok"])


## One answer read: {ok, why, last_id, commands (ids, oldest first, at most COMMANDS_LAST), talk, media, blocked, rows,
## restarted}. `last_id` the newest id seen before it; `learn` true for the first answer (nothing fires, it only learns
## where the feed stands). Not ok, with why, for an answer that is too big or not a list of lines.
static func digest(body: PackedByteArray, last_id: int, learn: bool) -> Dictionary:
	var out := {"ok": false, "why": "", "last_id": last_id, "commands": [], "talk": 0, "media": 0, "blocked": 0, "rows": 0, "restarted": false}
	if body.size() > BODY_LAST:
		out["why"] = "too big"
		return out
	var json := JSON.new()
	if json.parse(body.get_string_from_utf8()) != OK:
		out["why"] = "not JSON"
		return out
	var data = json.data
	json = null
	var list = data
	if data is Dictionary:
		list = null
		for key in LIST_KEYS:
			if (data as Dictionary).get(key) is Array:
				list = data[key]
				break
	if not (list is Array):
		out["why"] = "not a list of lines"
		return out
	var rows: Array = []
	var newest := -1
	for row in list:
		if not (row is Dictionary):
			continue
		var id := _id_of(row.get("id"))
		if id < 0:
			continue
		newest = maxi(newest, id)
		if id > last_id:
			rows.append([id, row])
	out["ok"] = true
	out["rows"] = rows.size()
	if newest < 0:
		data = null
		return out
	if newest < last_id:
		# The feed began again (its ids went back): learn where it stands now, fire nothing.
		out["restarted"] = true
		out["last_id"] = newest
		data = null
		return out
	out["last_id"] = maxi(last_id, newest)
	if learn:
		data = null
		return out
	rows.sort_custom(func(a, b): return a[0] < b[0])
	for pair in rows:
		var row: Dictionary = pair[1]
		var media = row.get("media")
		if not ((media is int or media is float) and is_finite(float(media))):
			continue
		if float(media) > 0.0:
			out["media"] += 1
			continue
		out["talk"] += 1
		var said := _text_of(row)
		if said == "":
			continue
		var words := VoiceMatch.words_of(said)
		if VoiceMatch.blocked(words):
			out["blocked"] += 1
			said = ""
			continue
		var id := VoiceMatch.command_of(said)
		said = ""
		if id != &"" and (out["commands"] as Array).size() < COMMANDS_LAST:
			(out["commands"] as Array).append(id)
	rows.clear()
	data = null
	return out


## A row's id: a whole number (an int, a whole float, or digits), or -1.
static func _id_of(v) -> int:
	if v is int:
		return v if v >= 0 else -1
	if v is float and is_finite(v) and v >= 0.0 and v == floorf(v) and v < 9.0e15:
		return int(v)
	if v is String and (v as String).is_valid_int() and (v as String).length() < 16:
		return maxi((v as String).to_int(), -1)
	return -1


## A row's text under the first of TEXT_KEYS it has as a string, or "".
static func _text_of(row: Dictionary) -> String:
	for key in TEXT_KEYS:
		if row.get(key) is String:
			return row[key]
	return ""
