extends RefCounted
## One HTTP/1.0 request to a local model server on 127.0.0.1, driven by poll(), which
## never blocks: each call does what the socket allows and returns. The host is the C9
## detector's constant LOCALHOST and cannot be changed; only the port is given. The whole
## response is capped, the deadline is checked on every poll, and a reset is a failure.
## HTTP/1.0 means no chunking and a close at the end, so a clean close ends the answer.

const Detector = preload("res://scripts/ai/ai_source_detector.gd")

enum State { IDLE, CONNECTING, SENDING, RECEIVING, DONE, FAILED }

## Bytes read per poll at most.
const READ_CHUNK := 65536

var state: State = State.IDLE
## Milliseconds from the start to the first byte of the answer, or -1.
var first_byte_ms := -1

var _peer: StreamPeerTCP
var _request := PackedByteArray()
var _sent := 0
var _raw := PackedByteArray()
var _cap := 0
var _deadline := 0
var _started := 0


## Starts a request to 127.0.0.1:port; `deadline` is in Time.get_ticks_msec() terms.
func start(port: int, method: String, path: String, body: PackedByteArray, deadline: int, cap: int) -> bool:
	if state != State.IDLE or port < 1 or port > Detector.PORT_LAST:
		return false
	var head := "%s %s HTTP/1.0\r\nHost: %s:%d\r\nAccept: application/json\r\nConnection: close\r\n" % [method, path, Detector.LOCALHOST, port]
	if not body.is_empty():
		head += "Content-Type: application/json\r\nContent-Length: %d\r\n" % body.size()
	_request = (head + "\r\n").to_ascii_buffer()
	_request.append_array(body)
	_cap = cap
	_deadline = deadline
	_started = Time.get_ticks_msec()
	_peer = StreamPeerTCP.new()
	if _peer.connect_to_host(Detector.LOCALHOST, port) != OK:
		state = State.FAILED
		return false
	state = State.CONNECTING
	return true


## One step, never blocking; returns the state after it.
func poll() -> State:
	if state == State.DONE or state == State.FAILED or state == State.IDLE:
		return state
	if Time.get_ticks_msec() > _deadline:
		close()
		state = State.FAILED
		return state
	_peer.poll()
	var status := _peer.get_status()
	if state == State.CONNECTING:
		if status == StreamPeerTCP.STATUS_CONNECTED:
			state = State.SENDING
		elif status != StreamPeerTCP.STATUS_CONNECTING:
			return _fail()
		else:
			return state
	if state == State.SENDING:
		if status != StreamPeerTCP.STATUS_CONNECTED:
			return _fail()
		var put: Array = _peer.put_partial_data(_request.slice(_sent))
		if put[0] != OK:
			return _fail()
		_sent += put[1]
		if _sent < _request.size():
			return state
		state = State.RECEIVING
	if state == State.RECEIVING:
		if status != StreamPeerTCP.STATUS_CONNECTED:
			if status == StreamPeerTCP.STATUS_NONE:
				state = State.DONE  # a clean close: the whole answer is in
				return state
			return _fail()
		var waiting := _peer.get_available_bytes()
		if waiting > 0:
			var got: Array = _peer.get_partial_data(mini(mini(waiting, READ_CHUNK), _cap + 1 - _raw.size()))
			if got[0] != OK:
				return _fail()
			if first_byte_ms < 0:
				first_byte_ms = Time.get_ticks_msec() - _started
			_raw.append_array(got[1])
			if _raw.size() > _cap:
				return _fail()
	return state


## The response body when DONE and well formed (see the detector's parse_http_body), else null.
func body() -> Variant:
	if state != State.DONE:
		return null
	return Detector.parse_http_body(_raw)


func close() -> void:
	if _peer != null:
		_peer.disconnect_from_host()


func _fail() -> State:
	close()
	state = State.FAILED
	return state
