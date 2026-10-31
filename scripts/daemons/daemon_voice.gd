class_name DaemonVoice
extends Node3D
## A daemon's or a piece of ICE's own sounds in the arena (C42): its tell, its strike, a hit landing on it and its
## death, in its type's voice (scripts/sfx_synth.gd, daemon_voice(): rogue.d, the zombie, the runaway's swarm, a wall, a
## node, the hunter), from where it is, on the Effects bus (so the Effects and Master volumes rule it). It sits under
## the daemon or the piece and goes where it goes. Its owner tells it of hits and deaths (hit(), death()); the tell and
## the strike it hears for itself, from the owner's brain (scripts/fight/daemon_brain.gd, or the hunter's) entering
## those states, so a joiner's copy of the host's daemon says the same as the host's. A hit sounds at most once in
## HIT_GAP_S, so a stream of small hits (a beam) never machine-guns. Each type's sounds are made once a run.

const SfxSynth = preload("res://scripts/sfx_synth.gd")
const SettingsApply = preload("res://scripts/settings/settings_apply.gd")

## Linear volumes for each kind of sound; how far a voice carries (metres) and its size (unit_size).
const VOLUMES := {"tell": 0.5, "strike": 0.62, "hit": 0.45, "death": 0.72}
const REACH_M := 70.0
const UNIT_M := 7.0
const HIT_GAP_S := 0.07

## Its type: a DaemonArt.ai_kind ("rogue", "zombie", "swarm", "barrier", "node", "hunter").
var kind := "rogue"
## The owner's brain, or null (walls and nodes, and practice's dummies still have one that never attacks). Untyped on
## purpose, so the hunter's fits.
var brain = null

var _call: AudioStreamPlayer3D
var _hurt: AudioStreamPlayer3D
var _last_state := -1
var _last_hit := -1.0
var _clock := 0.0
## What it said, in order, for the checks: [[seconds, what], ...].
var said: Array = []

static var _made := {}


func _init() -> void:
	name = "Voice"


func _ready() -> void:
	_call = _player("Call")
	_hurt = _player("Hurt")
	for what in SfxSynth.DAEMON_WHATS:
		sound(kind, what)


## Every type's sounds made now (the arena does this as it loads, so no round's start waits on them).
static func prewarm() -> void:
	for of_kind in SfxSynth.DAEMON_KINDS:
		for what in SfxSynth.DAEMON_WHATS:
			sound(of_kind, what)


## Kind `kind`'s `what`, made once a run.
static func sound(of_kind: String, what: String) -> AudioStreamWAV:
	var key := of_kind + ":" + what
	if not _made.has(key):
		_made[key] = SfxSynth.daemon_voice(of_kind, what)
	return _made[key]


## A hit landed on it (not a quiet one).
func hit() -> void:
	if _last_hit >= 0.0 and _clock - _last_hit < HIT_GAP_S:
		return
	_last_hit = _clock
	_say(_hurt, "hit")


## It died: its death, over whatever it was saying.
func death() -> void:
	_call.stop()
	_say(_hurt, "death")


func _physics_process(delta: float) -> void:
	_clock += delta
	if brain == null:
		return
	var state: int = brain.state
	if state == _last_state:
		return
	_last_state = state
	if state == DaemonBrain.State.TELL:
		_say(_call, "tell")
	elif state == DaemonBrain.State.STRIKE:
		_say(_call, "strike")


func _say(player: AudioStreamPlayer3D, what: String) -> void:
	if not is_inside_tree():
		return
	player.stream = sound(kind, what)
	player.volume_db = SfxSynth.volume_db(VOLUMES[what])
	player.play()
	said.append([_clock, what])


func _player(node_name: String) -> AudioStreamPlayer3D:
	var player := AudioStreamPlayer3D.new()
	player.name = node_name
	player.bus = SettingsApply.EFFECTS if AudioServer.get_bus_index(SettingsApply.EFFECTS) >= 0 else &"Master"
	player.max_distance = REACH_M
	player.unit_size = UNIT_M
	player.attenuation_model = AudioStreamPlayer3D.ATTENUATION_INVERSE_DISTANCE
	add_child(player)
	return player
