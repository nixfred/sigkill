extends RefCounted
## One agent CLI the game started itself, and the only code that starts or stops a process
## for the guide (PRD section 6 execute exception, and the producer's clarification that
## the game may stop ONLY its own child, by the PID its own launch returned).
##
## It starts the command from an absolute path with an argument array, never through a
## shell, and reads its output without ever blocking: poll() takes what is there. stdout is
## kept up to a cap and the rest dropped; stderr is drained and dropped. stop() kills the
## child only while it is still ours: running, and not yet reaped, so its PID cannot have
## been reused. Godot's kill reaps it, so no zombie is left, and the PID is never asked
## about again afterwards (Godot would print an error).

## Bytes read from a pipe per call.
const READ_CHUNK := 65536

var pid := 0
## The exit code once the child has exited on its own, else -1.
var exit_code := -1

var _stdio: FileAccess
var _stderr: FileAccess
var _out := PackedByteArray()
var _cap := 0
var _overflow := false
var _alive := false


## Starts `path` (absolute, executable) with `args`. With `close_stdin` the child sees end of
## input at once; its stdout then goes nowhere, so use it only for a child that writes its
## answer elsewhere. False if it could not start.
func start(path: String, args: PackedStringArray, close_stdin: bool, cap: int) -> bool:
	if _alive or not path.is_absolute_path():
		return false
	var run := OS.execute_with_pipe(path, args, false)
	if run.is_empty():
		return false
	pid = run["pid"]
	_stdio = run["stdio"]
	_stderr = run["stderr"]
	_cap = cap
	_alive = true
	if close_stdin:
		_stdio.close()
		_stdio = null
	return true


## Reads what is there without waiting. True once the child has exited and its output has
## been drained; then exit_code holds its status.
func poll() -> bool:
	if not _alive:
		return true
	_read_some()
	if OS.is_process_running(pid):
		return false
	_read_some()  # anything written just before it exited
	exit_code = OS.get_process_exit_code(pid)
	_close()
	return true


## True while the child is running and ours.
func is_alive() -> bool:
	return _alive


## Stops the child if it is still running: our own PID only, checked just before. Godot's
## kill reaps it. Safe to call at any time, any number of times.
func stop() -> void:
	if not _alive:
		return
	if OS.is_process_running(pid):
		OS.kill(pid)
	else:
		exit_code = OS.get_process_exit_code(pid)
	_close()


## What the child wrote to stdout, up to the cap.
func output() -> PackedByteArray:
	return _out


## True if the child wrote more to stdout than the cap kept.
func overflowed() -> bool:
	return _overflow


func _read_some() -> void:
	if _stdio != null:
		var chunk := _stdio.get_buffer(READ_CHUNK)
		if not chunk.is_empty() and not _overflow:
			var room := _cap - _out.size()
			if chunk.size() > room:
				_out.append_array(chunk.slice(0, room))
				_overflow = true
			else:
				_out.append_array(chunk)
	if _stderr != null:
		_stderr.get_buffer(READ_CHUNK)  # drained and dropped, so it never fills


func _close() -> void:
	_alive = false
	if _stdio != null:
		_stdio.close()
		_stdio = null
	if _stderr != null:
		_stderr.close()
		_stderr = null


func _notification(what: int) -> void:
	# Freed while the child still runs, for example at game exit: stop it. Only engine and
	# other objects' calls here; a GDScript object cannot call its own methods while freed.
	if what == NOTIFICATION_PREDELETE and _alive:
		if OS.is_process_running(pid):
			OS.kill(pid)
		if _stdio != null:
			_stdio.close()
		if _stderr != null:
			_stderr.close()
