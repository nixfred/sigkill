extends "res://scripts/ai/guide_adapter.gd"
## A local OpenAI-compatible model server as the guide: Ollama or LM Studio on 127.0.0.1
## only, the port the C9 detector found. Model hygiene (PRD 5.4): it uses a model that is
## ALREADY loaded and never loads one: Ollama's /api/ps lists what is loaded; for another
## OpenAI-compatible server /v1/models is the list used. If nothing is loaded it answers
## "needs_consent" without asking the server for anything more (the consent UI comes
## later). It only ever sends GET /api/ps, GET /v1/models and POST /v1/chat/completions
## with {model, messages, stream: false, max_tokens}: never num_ctx, options or keep_alive,
## and it never pulls, deletes or unloads a model. Model names stay in memory for the one
## request and are never stored in a result, printed or logged.
##
## tokens_per_sec is usage.completion_tokens over the time the chat request took, when the
## answer reports it; otherwise -1.

const Detector = preload("res://scripts/ai/ai_source_detector.gd")
const Http = preload("res://scripts/ai/local_http.gd")
const Json = preload("res://scripts/ai/quiet_json.gd")
const Request = preload("res://scripts/ai/guide_request.gd")

const KIND_OLLAMA := "ollama"
const KIND_OPENAI := "openai-compatible"
const LOADED_PATH := "/api/ps"
const MODELS_PATH := "/v1/models"
const CHAT_PATH := "/v1/chat/completions"
const MODEL_NAME_MAX := 256
const MS_PER_SECOND := 1000.0

enum Phase { IDLE, LISTING, CHATTING }

var _kind := ""
var _port := 0
var _phase: Phase = Phase.IDLE
var _http: Http
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


func is_available() -> bool:
	return _kind != "" and _port > 0


func _timeout_ms() -> int:
	return _t.local_timeout_ms


func _begin(request: RefCounted) -> String:
	_message = request.user_message()
	_model = ""
	_deadline = Time.get_ticks_msec() + _t.local_timeout_ms
	_http = Http.new()
	if not _http.start(_port, "GET", LOADED_PATH if _kind == KIND_OLLAMA else MODELS_PATH, PackedByteArray(), _deadline, _t.local_response_max_bytes):
		_http = null
		return "unreachable"
	_phase = Phase.LISTING
	return ""


func _step() -> Dictionary:
	if _http == null:
		return result(false, "", "unreachable")
	var state := _http.poll()
	if state != Http.State.DONE and state != Http.State.FAILED:
		return {}
	if state == Http.State.FAILED:
		return _done(result(false, "", "timeout" if Time.get_ticks_msec() > _deadline else "unreachable"))
	var parsed := _parsed(_http.body())
	if not parsed[0]:
		return _done(result(false, "", "bad_response"))
	if _phase == Phase.LISTING:
		_model = loaded_model(parsed[1], _kind)
		if _model == "":
			return _done(result(false, "", "needs_consent"))
		var body := JSON.stringify(chat_body(_model, _message, _t.local_max_tokens)).to_utf8_buffer()
		_http = Http.new()
		_chat_started = Time.get_ticks_msec()
		if not _http.start(_port, "POST", CHAT_PATH, body, _deadline, _t.local_response_max_bytes):
			return _done(result(false, "", "unreachable"))
		_phase = Phase.CHATTING
		return {}
	var content = Json.field(Json.field(Json.item(Json.field(parsed[1], "choices"), 0), "message"), "content")
	if not (content is String):
		return _done(result(false, "", "bad_response"))
	var answer := clean_answer((content as String).to_utf8_buffer(), _t.answer_max_chars)
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


## The first loaded model's name from a listing, or "". Ollama's /api/ps gives
## {"models": [{"name" or "model": ...}]}; /v1/models gives {"data": [{"id": ...}]}.
static func loaded_model(listing: Variant, kind: String) -> String:
	var entries = Json.field(listing, "models" if kind == KIND_OLLAMA else "data")
	if not (entries is Array):
		return ""
	for entry in entries:
		for key in (["model", "name"] if kind == KIND_OLLAMA else ["id"]):
			var name = Json.field(entry, key)
			if name is String and not (name as String).is_empty() and (name as String).length() <= MODEL_NAME_MAX:
				return name
	return ""


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
