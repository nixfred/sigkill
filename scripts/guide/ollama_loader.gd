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
##   game's own models only (owned: seen loaded after its own load), and only if /api/ps
##   still lists it. A model marked for release stays marked, and is retried, until that
##   unload is answered or /api/ps shows it gone. A load request that reached the server
##   but that the game stopped waiting for (Esc, O, timeout) is watched, each on its own,
##   for load_timeout_ms, and unloaded if it turns up; once seen loaded it is kept until
##   unloaded or gone. A request that never reached the server is never watched.
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
## Models this game loaded itself (seen in /api/ps after its own load) and has not
## unloaded yet.
var owned := PackedStringArray()
## The owned model the guide uses now; "" if none.
var current := ""
## Owned models the game wants unloaded (O, a load nobody waits for any more). Each stays
## here until its unload is answered or /api/ps shows it gone.
var release := PackedStringArray()
## Loads the game sent to the server and stopped waiting for (Esc, O, a timeout):
## name -> {"until": ticks, "seen": bool}. Unloaded if they turn up. Dropped when their
## window passes without them turning up, or once seen loaded and then gone.
var watched := {}
## The model the last job_load was for.
var last_load := ""

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


## Marks owned models for unloading: those in `names`, or every one when it is empty.
## Main thread only, with no job running.
func mark_release(names: PackedStringArray = PackedStringArray()) -> void:
	for name in (owned if names.is_empty() else names):
		if owned.has(name) and not release.has(name):
			release.append(name)
	if release.has(current):
		current = ""


## True while something is left to unload or to watch for.
func has_pending() -> bool:
	return not release.is_empty() or not watched.is_empty()


func is_watching() -> bool:
	return not watched.is_empty()


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
	last_load = name
	var ps := _fetch(PS_PATH)
	if not ps[0] or not listing_ok(ps[1]):
		return  # what is loaded cannot be read, so ownership could not be proven: no load
	var listed := loaded_names(ps[1])
	if watched.has(name):
		# An earlier load of this model that the game stopped waiting for: the game's own.
		# Its watch stays until this attempt claims the model or sends a load of its own.
		if listed.has(name):
			_own(name)
			outcome = Outcome.LOADED
			return
	elif owned.has(name):
		if listed.has(name):
			release.erase(name)  # wanted again
			current = name
			outcome = Outcome.LOADED
			return
		owned.erase(name)  # gone since: loaded afresh below
		release.erase(name)
	elif listed.has(name):
		outcome = Outcome.LOADED_NOW  # loaded by someone else before the Y: never the game's
		return
	if _cancelled():
		outcome = Outcome.CANCELLED
		return
	var deadline := Time.get_ticks_msec() + int(tuning.load_timeout_ms)
	var sent := _post(GENERATE_PATH, {"model": name}, deadline)
	if not sent[3]:
		# The request never reached the server: nothing can load because of it.
		outcome = Outcome.CANCELLED if sent[2] == "cancelled" else Outcome.TIMEOUT if sent[2] == "timeout" else Outcome.ERROR
		return
	if sent[2] == "cancelled" or sent[2] == "timeout":
		_watch(name)  # sent: it may still load
		outcome = Outcome.CANCELLED if sent[2] == "cancelled" else Outcome.TIMEOUT
		return
	var after := _send("GET", PS_PATH, PackedByteArray(), Time.get_ticks_msec() + PROBE_TIMEOUT_MS, false)
	if after[0] and listing_ok(after[1]) and loaded_names(after[1]).has(name):
		_own(name)
		outcome = Outcome.LOADED
		return
	_watch(name)  # answered but not listed (yet): watched, in case it still loads
	outcome = Outcome.ERROR


func _own(name: String) -> void:
	if not owned.has(name):
		owned.append(name)
	watched.erase(name)
	current = name


func _watch(name: String) -> void:
	watched[name] = {"until": Time.get_ticks_msec() + int(tuning.load_timeout_ms), "seen": false}


## Worker job: unloads any watched load that has turned up, then the models marked for
## release. Every request has its own deadline, so one unload that hangs cannot use up the
## time for the others; whatever cannot be done now stays for the next run, and the
## release list is rotated so the next run starts with a different model.
func job_tidy() -> void:
	_begin_job()
	_watch_pass(-1)
	_release_pass(-1)
	if release.size() > 1:
		release.append(release[0])
		release.remove_at(0)
	outcome = Outcome.NONE


## At the end of the session: marks every owned model for release, unloads it and any
## watched load that has turned up, each only if /api/ps lists it, all before `deadline`,
## then forgets everything (nothing can follow). Runs on the main thread with no job
## running, and always runs, even after a cancel.
func unload_now(deadline: int) -> void:
	mark_release()
	_watch_pass(deadline)
	_release_pass(deadline)
	owned.clear()
	release.clear()
	watched.clear()
	current = ""


## `deadline` < 0: each request gets its own (PROBE_TIMEOUT_MS to read /api/ps,
## unload_timeout_ms per unload); otherwise everything shares it (the end of the session).
func _release_pass(deadline: int) -> void:
	if release.is_empty():
		return
	var ps := _send("GET", PS_PATH, PackedByteArray(), _by(deadline, PROBE_TIMEOUT_MS), false)
	if not (ps[0] and listing_ok(ps[1])):
		return  # cannot tell: kept for the next run
	var listed := loaded_names(ps[1])
	for name in release.duplicate():
		if not listed.has(name) or _send_unload(name, _by(deadline, int(tuning.unload_timeout_ms))):
			release.erase(name)
			owned.erase(name)


func _watch_pass(deadline: int) -> void:
	if watched.is_empty():
		return
	var ps := _send("GET", PS_PATH, PackedByteArray(), _by(deadline, PROBE_TIMEOUT_MS), false)
	if not (ps[0] and listing_ok(ps[1])):
		return  # cannot tell: nothing expires on a check that did not happen
	var listed := loaded_names(ps[1])
	var now := Time.get_ticks_msec()
	for name in watched.keys():
		var entry: Dictionary = watched[name]
		if listed.has(name):
			entry["seen"] = true
			if _send_unload(name, _by(deadline, int(tuning.unload_timeout_ms))):
				watched.erase(name)
		elif entry["seen"]:
			watched.erase(name)  # it turned up and is gone now
		elif now > int(entry["until"]):
			watched.erase(name)  # /api/ps shows it absent, past its window


## A shared deadline, or a fresh one `ms` from now when there is none.
static func _by(deadline: int, ms: int) -> int:
	return deadline if deadline >= 0 else Time.get_ticks_msec() + ms


## One unload request with exactly {"model": name, "keep_alive": 0}; true if answered.
func _send_unload(name: String, deadline: int) -> bool:
	var sent := _send("POST", GENERATE_PATH, JSON.stringify({"model": name, "keep_alive": 0}).to_utf8_buffer(), deadline, false)
	return sent[2] == "done" and sent[0]


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
## "timeout" | "cancelled", sent]. ok is false for a refusal, a non-200 answer or a body
## that is not JSON. sent is true once the whole request was written to the server. An
## unload passes `cancellable` false: it always runs to its deadline.
func _send(method: String, path: String, body: PackedByteArray, deadline: int, cancellable: bool = true) -> Array:
	if cancellable and _cancelled():
		return [false, null, "cancelled", false]
	var http := Http.new()
	if not http.start(port, method, path, body, deadline, RESPONSE_MAX_BYTES):
		return [false, null, "failed", false]
	var sent := false
	while true:
		var state := http.poll()
		sent = sent or state == Http.State.RECEIVING or state == Http.State.DONE
		if state == Http.State.DONE:
			break
		if state == Http.State.FAILED:
			return [false, null, "timeout" if Time.get_ticks_msec() > deadline else "failed", sent]
		if cancellable and _cancelled():
			http.close()
			return [false, null, "cancelled", sent]
		OS.delay_usec(POLL_USEC)
	var raw = http.body()
	if not (raw is PackedByteArray):
		return [false, null, "done", true]
	var parsed := Json.parse(raw)
	return [parsed[0], parsed[1], "done", true]
