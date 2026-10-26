extends "res://scripts/ai/guide_adapter.gd"
## Shared part of the agent CLI adapters (Claude Code, Codex): the player's own agent, run
## in its own non-interactive mode with tools off, from the absolute path the C9 detector's
## PATH lookup found, with an argument array and never a shell (PRD section 6, the one
## execute exception). The command must be named exactly as the adapter, so nothing else,
## and never omarchy-agent, can be run through it.
##
## Each request runs in an empty scratch directory the game owns, under user://, where
## possible (Codex takes it as --cd; Godot's process API has no working-directory setting,
## so Claude Code inherits the game's directory and gets no tools and no file discovery
## instead). A request still running when the adapter is freed, for example at game exit,
## is stopped through its GuideProcess.

const Process = preload("res://scripts/ai/guide_process.gd")
## Where the game keeps its guide files. Tests point it at their own folder.
const SCRATCH_ROOT := "user://guide"
const WORKDIR_NAME := "workdir"
const EXECUTE_BITS := 0x49

## Absolute path of the agent's command.
var command_path := ""
## Root of the game's guide files; the empty working directory is inside it.
var scratch_root := SCRATCH_ROOT

var _process: Process


func _init(path: String = "", tuning_resource: Resource = null) -> void:
	super(tuning_resource)
	command_path = path


func is_available() -> bool:
	return command_ok(command_path, adapter_name())


## True if `path` is an absolute path to an executable file named exactly `command`.
static func command_ok(path: String, command: String) -> bool:
	if not path.is_absolute_path() or path.get_file() != command:
		return false
	if DirAccess.dir_exists_absolute(path) or not FileAccess.file_exists(path):
		return false
	return (FileAccess.get_unix_permissions(path) & EXECUTE_BITS) != 0


## The empty working directory, made if missing; "" if it cannot be made or is not empty.
func workdir() -> String:
	var dir := ProjectSettings.globalize_path(scratch_root.path_join(WORKDIR_NAME))
	if not DirAccess.dir_exists_absolute(dir):
		DirAccess.make_dir_recursive_absolute(dir)
	var listing := DirAccess.open(dir)
	if listing == null:
		return ""
	listing.include_hidden = true
	if not listing.get_files().is_empty() or not listing.get_directories().is_empty():
		return ""
	return dir


## The arguments for one request, after the command itself. Each adapter sets them.
func arguments(_request: RefCounted, _workdir: String) -> PackedStringArray:
	return PackedStringArray()


## Whether the child's stdin is closed at once (see GuideProcess.start).
func closes_stdin() -> bool:
	return false


func _begin(request: RefCounted) -> String:
	var dir := workdir()
	if dir == "":
		return "scratch_not_empty"
	var prepared := _prepare(dir)
	if prepared != "":
		return prepared
	_process = Process.new()
	if not _process.start(command_path, arguments(request, dir), closes_stdin(), _t.stdout_max_bytes):
		_process = null
		return "launch_failed"
	return ""


## Anything an adapter sets up before the launch; "" when ready, else the error_kind.
func _prepare(_dir: String) -> String:
	return ""


func _step() -> Dictionary:
	if _process == null or not _process.poll():
		return {}
	var done := _finish(_process)
	_process = null
	return done


## The result once the child has exited on its own.
func _finish(process: Process) -> Dictionary:
	if process.exit_code != 0:
		return result(false, "", "agent_error")
	var answer := clean_answer(process.output(), _t.answer_max_chars)
	return result(answer != "", answer, "" if answer != "" else "empty")


func _abort() -> void:
	if _process != null:
		_process.stop()
		_process = null


## The PID of the running child, or 0. For tests and logs of our own launch only.
func child_pid() -> int:
	return _process.pid if _process != null and _process.is_alive() else 0
