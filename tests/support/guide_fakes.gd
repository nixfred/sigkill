extends RefCounted
## Fakes for the guide tests: a detector that answers with a canned C9 result and counts
## every call, and a guide adapter stub on the real C9b base class (pacing, the AI switch
## and the timeout all come from GuideAdapter). Nothing here runs a program or opens a
## socket.

const Found = preload("res://scripts/ai/ai_source_result.gd")


class FakeDetector:
	extends RefCounted
	var result: Found
	var reading := {"available": false}
	var done := true
	var starts := 0
	var waits := 0
	var finds := 0
	var cancels := 0
	var gpu_calls := 0
	var mutex := Mutex.new()

	func start() -> Error:
		starts += 1
		return OK

	func is_done() -> bool:
		return done

	func wait() -> Found:
		waits += 1
		return result

	func cancel() -> void:
		cancels += 1

	func find_command(_command: String) -> String:
		finds += 1
		return ""

	func poll_gpu() -> Dictionary:  # runs on a GPU worker thread
		mutex.lock()
		gpu_calls += 1
		var out := reading.duplicate()
		mutex.unlock()
		return out

	func gpu_count() -> int:
		mutex.lock()
		var n := gpu_calls
		mutex.unlock()
		return n


class StubAdapter:
	extends "res://scripts/ai/guide_adapter.gd"
	var name := "claude"
	var kind := ""
	var mode := "ok"
	var answer := "Aim for the core, then strafe."
	var tps := -1.0
	var ask_calls := 0
	var begins := 0
	var cancels := 0
	var steps := 0
	var last_message := ""
	var last_stats := {}

	func _init(tuning_resource: Resource) -> void:
		super(tuning_resource)

	func adapter_name() -> String:
		return name

	func source_name() -> String:
		return kind if kind != "" else name

	func is_available() -> bool:
		return true

	func ask(request: RefCounted) -> Dictionary:
		ask_calls += 1
		return super(request)

	func _begin(request: RefCounted) -> String:
		begins += 1
		steps = 0
		last_message = request.user_message()
		last_stats = request.stats.duplicate()
		return ""

	func _step() -> Dictionary:
		steps += 1
		if steps < 3 or mode == "hang":
			return {}
		if mode == "ok":
			return result(true, answer, "", tps)
		return result(false, "", mode)

	func _abort() -> void:
		cancels += 1
