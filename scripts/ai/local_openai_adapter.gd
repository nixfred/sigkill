extends "res://scripts/ai/guide_adapter.gd"
## A local OpenAI-compatible model server as the guide: Ollama or LM Studio on 127.0.0.1
## only, the port the C9 detector found. Model hygiene (PRD 5.4): it uses a model that is
## ALREADY loaded and never loads one. Ollama's /api/ps lists only loaded models. For the
## OpenAI-compatible kind it asks LM Studio's own API, which says per model whether it is
## loaded: /api/v1/models (loaded_instances, LM Studio 0.4 and later), then /api/v0/models
## (state, before 0.4). The OpenAI-compatible /v1/models is never used for this: with LM
## Studio's just-in-time loading on, it lists every downloaded model, and a chat request
## for one of them loads it. A server that cannot say what is loaded, or has nothing
## loaded, gets "needs_consent" and no further request (the consent UI comes later). It
## only ever sends those GETs and one POST /v1/chat/completions with {model, messages,
## stream: false, max_tokens}: never num_ctx, options or keep_alive, and it never loads,
## pulls, deletes or unloads a model. Model names stay in memory for the one request and
## are never stored in a result, printed or logged; an answer that names the model has the
## name replaced (redact()).
##
## tokens_per_sec is usage.completion_tokens over the time the chat request took, when the
## answer reports it; otherwise -1.

const Detector = preload("res://scripts/ai/ai_source_detector.gd")
const Http = preload("res://scripts/ai/local_http.gd")
const Json = preload("res://scripts/ai/quiet_json.gd")
const Request = preload("res://scripts/ai/guide_request.gd")

const KIND_OLLAMA := "ollama"
const KIND_OPENAI := "openai-compatible"
const OLLAMA_PS_PATH := "/api/ps"
const LMSTUDIO_V1_PATH := "/api/v1/models"
const LMSTUDIO_V0_PATH := "/api/v0/models"
const LOADED_STATE := "loaded"
## LM Studio model types that can chat; its listings also hold embedding models.
const CHAT_TYPES := ["llm", "vlm"]
const CHAT_PATH := "/v1/chat/completions"
const MODEL_NAME_MAX := 256
const MS_PER_SECOND := 1000.0
const REDACTED := "the local model"

enum Phase { IDLE, LISTING, CHATTING }

var _kind := ""
var _port := 0
var _phase: Phase = Phase.IDLE
var _http: Http
var _listing := 0
var _model := ""
var _message := ""
var _deadline := 0
var _chat_started := 0


func _init(tuning_resource: Resource = null) -> void:
	super(tuning_resource)


## Points the adapter at a server: `kind` is "ollama" or "openai-compatible", `host` must be
## exactly 127.0.0.1 (not even "localhost", which a hosts file could send elsewhere). False,
## and nothing set, for anything else.
func configure(kind: String, host: String, port: int) -> bool:
	if host != Detector.LOCALHOST or port < 1 or port > Detector.PORT_LAST:
		return false
	if kind != KIND_OLLAMA and kind != KIND_OPENAI:
		return false
	_kind = kind
	_port = port
	return true


func adapter_name() -> String:
	return "local"


func source_name() -> String:
	return _kind


func is_available() -> bool:
	return _kind != "" and _port > 0


func _timeout_ms() -> int:
	return _t.local_timeout_ms


func _begin(request: RefCounted) -> String:
	_message = request.user_message()
	_model = ""
	_deadline = Time.get_ticks_msec() + _t.local_timeout_ms
	_listing = 0
	if not _start_get(listing_paths(_kind)[0]):
		return "unreachable"
	_phase = Phase.LISTING
	return ""


## Where `kind` says which models are loaded, in the order asked.
static func listing_paths(kind: String) -> PackedStringArray:
	if kind == KIND_OPENAI:
		return PackedStringArray([LMSTUDIO_V1_PATH, LMSTUDIO_V0_PATH])
	return PackedStringArray([OLLAMA_PS_PATH])


func _start_get(path: String) -> bool:
	if _http != null:
		_http.close()
	_http = Http.new()
	if _http.start(_port, "GET", path, PackedByteArray(), _deadline, _t.local_response_max_bytes):
		return true
	_http = null
	return false


func _step() -> Dictionary:
	if _http == null:
		return result(false, "", "unreachable")
	var state := _http.poll()
	if state != Http.State.DONE and state != Http.State.FAILED:
		return {}
	if state == Http.State.FAILED:
		return _done(result(false, "", "timeout" if Time.get_ticks_msec() > _deadline else "unreachable"))
	var parsed := _parsed(_http.body())
	if _phase == Phase.LISTING:
		var paths := listing_paths(_kind)
		var found := loaded_model(parsed[1] if parsed[0] else null, paths[_listing])
		if not found[0]:
			# Not a listing this path should give: the next one, if any. Ollama's one
			# listing is a bad response; an OpenAI-compatible server that cannot say
			# what is loaded gets no chat request.
			_listing += 1
			if _kind != KIND_OPENAI:
				return _done(result(false, "", "bad_response"))
			if _listing >= paths.size():
				return _done(result(false, "", "needs_consent"))
			if not _start_get(paths[_listing]):
				return _done(result(false, "", "unreachable"))
			return {}
		_model = found[1]
		if _model == "":
			return _done(result(false, "", "needs_consent"))
		var body := JSON.stringify(chat_body(_model, _message, _t.local_max_tokens)).to_utf8_buffer()
		_http.close()
		_http = Http.new()
		_chat_started = Time.get_ticks_msec()
		if not _http.start(_port, "POST", CHAT_PATH, body, _deadline, _t.local_response_max_bytes):
			return _done(result(false, "", "unreachable"))
		_phase = Phase.CHATTING
		return {}
	if not parsed[0]:
		return _done(result(false, "", "bad_response"))
	var content = Json.field(Json.field(Json.item(Json.field(parsed[1], "choices"), 0), "message"), "content")
	if not (content is String):
		return _done(result(false, "", "bad_response"))
	var answer := redact(clean_answer((content as String).to_utf8_buffer(), _t.answer_max_chars), _model)
	if answer == "":
		return _done(result(false, "", "empty"))
	var tokens = Json.field(Json.field(parsed[1], "usage"), "completion_tokens")
	var seconds := (Time.get_ticks_msec() - _chat_started) / MS_PER_SECOND
	var rate := float(tokens) / maxf(seconds, 0.001) if tokens is int and tokens > 0 else -1.0
	return _done(result(true, answer, "", rate))


## The JSON of a finished response body, quietly, as [ok, value].
static func _parsed(body: Variant) -> Array:
	if not (body is PackedByteArray):
		return [false, null]
	return Json.parse(body)


## From the listing `path` gave: [true, the first loaded model's name] when it is that kind
## of listing ("" if nothing in it is loaded), or [false, ""] when it is not. Ollama's
## /api/ps gives {"models": [{"model" or "name": ...}]}, loaded models only. LM Studio's
## /api/v1/models gives {"models": [{"key": ..., "loaded_instances": [{"id": ...}]}]} and
## its /api/v0/models {"data": [{"id": ..., "state": "loaded" or "not-loaded"}]}; only a
## loaded instance or a "loaded" state counts, and only for a model whose "type" can chat
## ("llm" or "vlm"), so a loaded embedding model is never picked. Ollama's /api/ps does not
## say whether a model can chat; if the first loaded one cannot, the chat request fails
## and the answer is bad_response, never a load.
static func loaded_model(listing: Variant, path: String) -> Array:
	var entries = Json.field(listing, "data" if path == LMSTUDIO_V0_PATH else "models")
	if not (entries is Array):
		return [false, ""]
	for entry in entries:
		var names := []
		if path == OLLAMA_PS_PATH:
			names = [Json.field(entry, "model"), Json.field(entry, "name")]
		elif not _can_chat(entry):
			continue
		elif path == LMSTUDIO_V1_PATH:
			names = [Json.field(Json.item(Json.field(entry, "loaded_instances"), 0), "id")]
		elif path == LMSTUDIO_V0_PATH:
			var state = Json.field(entry, "state")
			if state is String and state == LOADED_STATE:
				names = [Json.field(entry, "id")]
		for name in names:
			if name is String and not (name as String).is_empty() and (name as String).length() <= MODEL_NAME_MAX:
				return [true, name]
	return [true, ""]


## `answer` with every mention of the loaded model's name, in any letter case, replaced by
## "the local model", so the name never reaches the screen.
static func redact(answer: String, model: String) -> String:
	if model.is_empty():
		return answer
	var out := answer
	var at := out.findn(model)
	while at >= 0:
		out = out.substr(0, at) + REDACTED + out.substr(at + model.length())
		at = out.findn(model, at + REDACTED.length())
	return out


static func _can_chat(entry: Variant) -> bool:
	var type = Json.field(entry, "type")
	return type is String and CHAT_TYPES.has(type)


## The chat request: the model, the fixed preamble as the system message, the stats and
## the player's text as the user message, no streaming, a token cap. Nothing else.
static func chat_body(model: String, message: String, max_tokens: int) -> Dictionary:
	return {
		"model": model,
		"messages": [
			{"role": "system", "content": Request.PREAMBLE},
			{"role": "user", "content": message},
		],
		"stream": false,
		"max_tokens": max_tokens,
	}


func _done(done: Dictionary) -> Dictionary:
	_model = ""  # model names live only for the one request
	_message = ""
	_phase = Phase.IDLE
	if _http != null:
		_http.close()
		_http = null
	return done


func _abort() -> void:
	_done({})
