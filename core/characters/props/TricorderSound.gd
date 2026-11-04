class_name TricorderSound
extends Node3D
## REV 169 (CLAUDE.md item 15): the TOS tricorder warble, heard while a tricorder is up in someone's
## hands and scanning. CharacterAnimator turns it on once the arms have brought the tricorder up and
## off again as they lower it, so the sound follows the tricorder rather than a timer. It plays from
## the tricorder itself (3D), so a scan by Spock or anyone else sounds right too.
##
## The recording (assets/audio/sfx/tricorder_scan.wav, from Glen's file in sfx/source/) is about 7.5 s.
## A scan can last longer while a result is being spoken, so near the end it crossfades into a second
## copy picked up past the opening swell, and keeps going for as long as the scan does.

const STREAM := "res://assets/audio/sfx/tricorder_scan.wav"
const LEVEL_DB := -8.0        # loud enough to read as the tricorder, under the voices
const FADE_IN := 0.15
const FADE_OUT := 0.35
const LOOP_FROM := 0.7        # where the repeat picks up (past the opening swell)
const CROSSFADE := 0.6

var _players: Array[AudioStreamPlayer3D] = []
var _weights := [0.0, 0.0]
var _cur := 0
var _gain := 0.0              # the on/off fade, 0..1
var _on := false
var _length := 0.0


func _ready() -> void:
	var stream: AudioStream = load(STREAM) if ResourceLoader.exists(STREAM) else null
	if stream == null:
		set_process(false)
		return
	_length = stream.get_length()
	var bus := "SFX" if AudioServer.get_bus_index("SFX") >= 0 else "Master"
	for i in 2:
		var p := AudioStreamPlayer3D.new()
		p.stream = stream
		p.bus = bus
		p.unit_size = 3.0
		p.max_distance = 30.0
		p.volume_db = -80.0
		add_child(p)
		_players.append(p)


## Scanning (true) or not. Safe to call every frame.
func set_active(on: bool) -> void:
	if _players.is_empty() or on == _on:
		return
	_on = on
	if on and not _players[0].playing and not _players[1].playing:
		_cur = 0
		_weights = [1.0, 0.0]
		_players[0].play(0.0)


func is_playing() -> bool:
	return _gain > 0.001


func _process(delta: float) -> void:
	if _players.is_empty():
		return
	# the on/off fade
	var rate := 1.0 / (FADE_IN if _on else FADE_OUT)
	_gain = move_toward(_gain, 1.0 if _on else 0.0, rate * delta)
	if _gain <= 0.0 and not _on:
		for p in _players:
			p.stop()
		_weights = [0.0, 0.0]
		return
	# still scanning near the end of the recording: crossfade into a fresh copy
	var cur := _players[_cur]
	if _on and cur.playing and cur.get_playback_position() > _length - CROSSFADE - 0.05:
		_cur = 1 - _cur
		_players[_cur].play(LOOP_FROM)
	var step := delta / CROSSFADE
	for i in 2:
		_weights[i] = move_toward(_weights[i], 1.0 if i == _cur else 0.0, step)
		if _weights[i] <= 0.0 and i != _cur and _players[i].playing:
			_players[i].stop()
		# equal-power crossfade, then the on/off fade
		var g: float = sin(float(_weights[i]) * PI * 0.5) * _gain
		_players[i].volume_db = LEVEL_DB + (linear_to_db(g) if g > 0.0001 else -80.0)
