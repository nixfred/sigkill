extends SceneTree
## Runs the SIGKILL relay (relay/relay_server.gd, docs/RELAY.md) under a headless Godot:
##
##   godot --headless --path <project> --script res://relay/relay_main.gd -- [flags]
##
## or relay/run_relay.sh, which does the same. Settings come from SIGKILL_RELAY_* variables
## and --flags (a flag wins); with none set it listens on 127.0.0.1:9010 only. A bad setting
## prints why and exits 2. Every stats_s seconds (and when it stops) it prints one line of
## aggregate counters: never an address, a room code or a token.
##
## Stopping: a service manager's SIGTERM ends the process at once, which loses nothing (all
## state is in memory, by design). --stop-file <path> also stops it cleanly, exit 0, once
## that file exists: the tests use it, checked twice a second.

const RelayServer = preload("res://relay/relay_server.gd")

const STOP_CHECK_S := 0.5

var _server: RelayServer
var _stats_left := 0.0
var _stop_left := 0.0
var _stop_file := ""


func _initialize() -> void:
	var env := {}
	for key in ["SIGKILL_RELAY_BIND", "SIGKILL_RELAY_DATA_PORTS"]:
		if OS.has_environment(key):
			env[key] = OS.get_environment(key)
	for setting in RelayServer.SETTINGS.values():
		if OS.has_environment(setting[0]):
			env[setting[0]] = OS.get_environment(setting[0])
	var config := RelayServer.config_from(env, OS.get_cmdline_user_args())
	if config.has("error"):
		printerr("SIGKILL relay: ", config["error"])
		quit(2)
		return
	_server = RelayServer.new(config)
	var why := _server.start()
	if why != "":
		printerr("SIGKILL relay: ", why)
		quit(2)
		return
	_stop_file = config["stop_file"]
	_stats_left = config["stats_s"]
	Engine.max_fps = config["tick_hz"]
	print("SIGKILL relay: up, control port %d, data ports %s, up to %d rooms of %d players, codes live %d s" % [_server.control_port(), "system-picked" if config["data_first"] == 0 else "%d-%d" % [config["data_first"], config["data_last"]], config["max_rooms"], config["max_players"], config["room_ttl_s"]])


func _process(delta: float) -> bool:
	if _server == null:
		return false
	_server.poll(Time.get_ticks_msec() / 1000.0)
	if config_stats() > 0:
		_stats_left -= delta
		if _stats_left <= 0.0:
			_stats_left = config_stats()
			print("SIGKILL relay: ", _server.stats_line())
	if _stop_file != "":
		_stop_left -= delta
		if _stop_left <= 0.0:
			_stop_left = STOP_CHECK_S
			if FileAccess.file_exists(_stop_file):
				_server.stop()
				print("SIGKILL relay: stopped cleanly. ", _server.stats_line())
				_server = null
				quit(0)
	return false


func config_stats() -> int:
	return _server.config["stats_s"]
