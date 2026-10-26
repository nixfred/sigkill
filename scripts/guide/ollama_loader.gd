extends RefCounted
## Loads a chat model on the player's own Ollama server, and unloads it again (PRD 5.4
## model hygiene, chunk C11b). Ollama on 127.0.0.1 only, through the C9b polled HTTP client
## (scripts/ai/local_http.gd); never any other server, never /v1/models or anything else
## that could load a model on its own.
##
## Every job runs on a worker thread the GuideLink starts, one at a time, with a deadline
## and a cancel flag the link arms before the thread starts (a cancel sent before the
## worker runs still counts); the link reads the outcome once the thread is joined. The
## rules:
## - job_offer() re-reads /api/ps first: a model loaded by then is used as it is. Otherwise
##   it reads /api/tags and offers exactly one candidate: the smallest chat model under
##   max_load_bytes and, when the free VRAM is known, under it minus vram_margin_mib.
##   Embedding models are skipped by name and family, then every remaining candidate,
##   smallest first, must pass /api/show: an answer that cannot be read fails it, and
##   listed capabilities must include "completion" (an older Ollama that lists none is
##   judged by name and family alone).
## - job_load() runs only after the player's Y. It reads /api/ps again and keeps what was
##   loaded at that moment; if the candidate is among it, or the listing cannot be read,
##   nothing is sent and it is never the game's. Otherwise one POST /api/generate with exactly {"model": name}: no prompt,
##   no options, no num_ctx, no keep_alive. Only a model that then shows up in /api/ps is
##   the game's own.
## - Unload is one POST /api/generate with exactly {"model": name, "keep_alive": 0}, for the
##   game's own model only, and only if /api/ps still lists it. Ownership is kept until
##   that unload is answered or /api/ps shows the model gone. A load the game stopped
##   waiting for (Esc, O, timeout) is watched until load_timeout_ms has passed, and
##   unloaded if it turns up.
## Model names stay in memory. Nothing here prints, logs or saves one.

const Http = preload("res://scripts/ai/local_http.gd")
const Json = preload("res://scripts/ai/quiet_json.gd")
const Detector = preload("res://scripts/ai/ai_source_detector.gd")

const PS_PATH := "/api/ps"
const TAGS_PATH := "/api/tags"
const SHOW_PATH := "/api/show"
const GENERATE_PATH := "/api/generate"
const RESPONSE_MAX_BYTES := 1048576
const PROBE_TIMEOUT_MS := 3000
## The most time all the /api/show checks of one offer may take together.
const OFFER_CHECK_MS := 15000
const NAME_MAX := 128
const NAME_CHARS := "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789._:/-+@"
const EMBED_FAMILIES := ["bert", "nomic-bert"]
const BYTES_PER_MIB := 1048576
const BYTES_PER_GB := 1000000000.0
const POLL_USEC := 2000

enum Outcome { NONE, LOADED_NOW, OFFER, NONE_FITS, LOADED, TIMEOUT, CANCELLED, ERROR }

## The Ollama port on 127.0.0.1.
var port := 0
## The guide tuning (GuideTuning) with the load limits.
var tuning: Resource
## The last job's outcome, and for an offer its candidate.
var outcome: Outcome = Outcome.NONE
var offer_name := ""
var offer_bytes := 0
## The model this game loaded itself and has not unloaded; "" if none.
var game_loaded := ""
## A load the game stopped waiting for, unloaded if it turns up before watch_until.
var watched := ""
var watch_until := 0

var _cancel := false
var _mutex := Mutex.new()


func cancel() -> void:
	_mutex.lock()
	_cancel = true
	_mutex.unlock()


## Clears the cancel flag. The link calls it on the main thread right before it starts a
## job, never while one runs, so a cancel that comes before the worker starts is kept.
func arm() -> void:
	_mutex.lock()
	_cancel = false
	_mutex.unlock()


func _cancelled() -> bool:
	_mutex.lock()
	var stop := _cancel
	_mutex.unlock()
	return stop


func _begin_job() -> void:
	outcome = Outcome.ERROR


## Worker job: what to offer. `free_mib` is the GPU's free VRAM in MiB, or -1 if unknown.
func job_offer(free_mib: int) -> void:
	_begin_job()
	offer_name = ""
	offer_bytes = 0
	var ps := _fetch(PS_PATH)
	if not ps[0] or not listing_ok(ps[1]):
		return
	if not loaded_names(ps[1]).is_empty():
		outcome = Outcome.LOADED_NOW
		return
	var tags := _fetch(TAGS_PATH)
	if not tags[0]:
		return
	var list := candidates(tags[1], tuning.max_load_bytes, free_mib, tuning.vram_margin_mib)
	var until := Time.get_ticks_msec() + OFFER_CHECK_MS
	for candidate in list:
		if _cancelled():
			outcome = Outcome.CANCELLED
			return
		if Time.get_ticks_msec() > until:
			return  # could not check them all in time: an error, never a guess
		var show := _post(SHOW_PATH, {"model": candidate["name"]}, mini(until, Time.get_ticks_msec() + PROBE_TIMEOUT_MS))
		if not show[0] or not can_chat(show[1]):
			continue  # unreadable, or not a chat model: never offered
		offer_name = candidate["name"]
		offer_bytes = candidate["size"]
		outcome = Outcome.OFFER
		return
	outcome = Outcome.NONE_FITS


## Worker job, after the player's Y: loads `name` unless something already loaded it.
func job_load(name: String) -> void:
	_begin_job()
	var ps := _fetch(PS_PATH)
	if not ps[0] or not listing_ok(ps[1]):
		return  # what is loaded cannot be read, so ownership could not be proven: no load
	if loaded_names(ps[1]).has(name):
		outcome = Outcome.LOADED_NOW  # loaded by someone else before the Y: never the game's
		return
	if _cancelled():
		outcome = Outcome.CANCELLED
		return
	var deadline := Time.get_ticks_msec() + int(tuning.load_timeout_ms)
	var sent := _post(GENERATE_PATH, {"model": name}, deadline)
	# From here the model may be loading because of this request.
	watched = name
	watch_until = Time.get_ticks_msec() + int(tuning.load_timeout_ms)
	if sent[2] == "cancelled":
		outcome = Outcome.CANCELLED
		return
	if sent[2] == "timeout":
		outcome = Outcome.TIMEOUT
		return
	var after := _fetch(PS_PATH)
	if after[0] and loaded_names(after[1]).has(name):
		game_loaded = name
		watched = ""
		outcome = Outcome.LOADED
		return
	outcome = Outcome.ERROR


## Worker job: unloads the game's own model, and a watched load if it has turned up.
func job_unload() -> void:
	_begin_job()
	unload_now(Time.get_ticks_msec() + int(tuning.unload_timeout_ms), false)
	outcome = Outcome.NONE


## Worker job: checks once whether a load the game stopped waiting for has turned up, and
## unloads it if so; stops watching once watch_until has passed.
func job_watch() -> void:
	_begin_job()
	outcome = Outcome.NONE
	if watched == "":
		return
	var ps := _send("GET", PS_PATH, PackedByteArray(), Time.get_ticks_msec() + PROBE_TIMEOUT_MS, false)
	if ps[0] and listing_ok(ps[1]) and loaded_names(ps[1]).has(watched):
		if _send_unload(watched, Time.get_ticks_msec() + int(tuning.unload_timeout_ms)):
			watched = ""
	if watched != "" and Time.get_ticks_msec() > watch_until:
		watched = ""


## Unloads the game's own model and a watched load, each only if /api/ps lists it, before
## `deadline`. Runs on whichever thread calls it (a worker, or the main thread at exit),
## and always runs, even after a cancel. Ownership is dropped only once the unload was
## answered or /api/ps no longer lists the model; a watched load not there yet stays
## watched. `final` (the end of the session) drops everything after this one attempt,
## since nothing can follow it.
func unload_now(deadline: int, final: bool = true) -> void:
	for slot in ["game_loaded", "watched"]:
		var name: String = get(slot)
		if name == "":
			continue
		var ps := _send("GET", PS_PATH, PackedByteArray(), deadline, false)
		var known: bool = ps[0] and listing_ok(ps[1])
		if known and loaded_names(ps[1]).has(name):
			if _send_unload(name, deadline):
				set(slot, "")
		elif known and slot == "game_loaded":
			set(slot, "")  # gone already
		if final:
			set(slot, "")


## One unload request with exactly {"model": name, "keep_alive": 0}; true if answered.
func _send_unload(name: String, deadline: int) -> bool:
	var sent := _send("POST", GENERATE_PATH, JSON.stringify({"model": name, "keep_alive": 0}).to_utf8_buffer(), deadline, false)
	return sent[2] == "done" and sent[0]


func is_watching() -> bool:
	return watched != ""


## "4.7 GB": a size the way Ollama shows it.
static func size_text(bytes: int) -> String:
	return "%.1f GB" % (bytes / BYTES_PER_GB)


## The candidates in /api/tags, smallest first: chat models (not embedding ones) with a
## usable name, under `max_bytes`, and under `free_mib - margin_mib` when free_mib >= 0.
static func candidates(listing: Variant, max_bytes: int, free_mib: int, margin_mib: int) -> Array:
	var out := []
	var entries = Json.field(listing, "models")
	if not (entries is Array):
		return out
	var room := (free_mib - margin_mib) * BYTES_PER_MIB if free_mib >= 0 else -1
	for entry in entries:
		var name = Json.field(entry, "name")
		if not (name is String and valid_name(name)):
			name = Json.field(entry, "model")
		var size = Json.field(entry, "size")
		if not (name is String and valid_name(name)) or not (size is int) or size <= 0:
			continue
		if is_embedding(entry, name) or size > max_bytes or (free_mib >= 0 and size > room):
			continue
		out.append({"name": name, "size": size})
	out.sort_custom(func(a, b): return a["size"] < b["size"] or (a["size"] == b["size"] and a["name"] < b["name"]))
	return out


static func is_embedding(entry: Variant, name: String) -> bool:
	if name.to_lower().contains("embed"):
		return true
	var details = Json.field(entry, "details")
	var family = Json.field(details, "family")
	if family is String and EMBED_FAMILIES.has(family):
		return true
	var families = Json.field(details, "families")
	if families is Array:
		for item in families:
			if item is String and EMBED_FAMILIES.has(item):
				return true
	return false


## From a readable /api/show answer: false when it lists capabilities and "completion" is
## not one. An older Ollama that lists no capabilities passes (name and family were
## checked already); an answer that is not a JSON object fails.
static func can_chat(show: Variant) -> bool:
	if not (show is Dictionary):
		return false
	var capabilities = Json.field(show, "capabilities")
	if not (capabilities is Array):
		return true
	for item in capabilities:
		if item is String and item == "completion":
			return true
	return false


## True when /api/ps answered with a models list (empty or not) that can be trusted.
static func listing_ok(ps: Variant) -> bool:
	return Json.field(ps, "models") is Array


## The names /api/ps lists as loaded.
static func loaded_names(ps: Variant) -> PackedStringArray:
	var out := PackedStringArray()
	var entries = Json.field(ps, "models")
	if entries is Array:
		for entry in entries:
			for key in ["name", "model"]:
				var name = Json.field(entry, key)
				if name is String and valid_name(name) and not out.has(name):
					out.append(name)
	return out


static func valid_name(name: String) -> bool:
	if name.is_empty() or name.length() > NAME_MAX:
		return false
	for c in name:
		if not NAME_CHARS.contains(c):
			return false
	return true


func _fetch(path: String) -> Array:
	return _send("GET", path, PackedByteArray(), Time.get_ticks_msec() + PROBE_TIMEOUT_MS)


func _post(path: String, body: Dictionary, deadline: int) -> Array:
	return _send("POST", path, JSON.stringify(body).to_utf8_buffer(), deadline)


## One request, polled to its end on this thread: [ok, parsed JSON, "done" | "failed" |
## "timeout" | "cancelled"]. ok is false for a refusal, a non-200 answer or a body that is
## not JSON. An unload passes `cancellable` false: it always runs to its deadline.
func _send(method: String, path: String, body: PackedByteArray, deadline: int, cancellable: bool = true) -> Array:
	if cancellable and _cancelled():
		return [false, null, "cancelled"]
	var http := Http.new()
	if not http.start(port, method, path, body, deadline, RESPONSE_MAX_BYTES):
		return [false, null, "failed"]
	while true:
		var state := http.poll()
		if state == Http.State.DONE:
			break
		if state == Http.State.FAILED:
			return [false, null, "timeout" if Time.get_ticks_msec() > deadline else "failed"]
		if cancellable and _cancelled():
			http.close()
			return [false, null, "cancelled"]
		OS.delay_usec(POLL_USEC)
	var raw = http.body()
	if not (raw is PackedByteArray):
		return [false, null, "done"]
	var parsed := Json.parse(raw)
	return [parsed[0], parsed[1], "done"]
