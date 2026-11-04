extends Node
## SfxManager — footsteps, interface/console sounds and the quiet background
## sound of each room.
##
##   SfxManager.play("interact")     one-shot sound from assets/audio/sfx/<name>.wav
##   SfxManager.footstep("metal")    one of four random steps for that surface
##   (rooms)                         the ambience changes by itself when the scene
##                                   changes: see _tone_for_scene()
##
## Every sound is a .wav in assets/audio/sfx/, looked up by name and loaded the first time it is
## used (some are stand-ins made by tools/make_*_sfx.py, some are Glen's recordings).
## REV 293: a missing file is silent AND quiet - it is looked for once, remembered as missing, and
## never warned about (not once, and certainly not every frame), so the game runs the same with or
## without it. Dropping the file in later is all it takes. docs/systems/audio-and-sfx.md lists the
## names the code asks for that have no file yet.
## One-shots go out on the SFX bus; the room tone on the Ambient bus, so the
## System menu's sliders control them.

const DIR := "res://assets/audio/sfx/"
const POOL_SIZE := 8
const TONE_FADE := 1.5
const TONE_DB := -4.0

## What the walking surface sounds like for each room tone, unless the floor the
## player is standing on says otherwise (see surface_for_collider).
const TONE_SURFACE := {"ship": "metal", "interior": "stone", "wind": "sand", "rec": "carpet", "meld": "stone", "": "stone"}
## REV 297: room tones that start from silence instead of the usual 1.5 s crossfade: [seconds of silence
## first, seconds to fade in]. The meld (script 12.5): "The Sickbay sound disappears. Complete silence."
## then the mindscape's drone slowly arrives (amb_meld.wav, tools/make_meld_sfx.py).
const TONE_SILENT_START := {"meld": [2.6, 6.0]}

var _pool: Array[AudioStreamPlayer] = []
var _pool_next: int = 0
var _streams: Dictionary = {}          # name -> AudioStream or null (missing)

var _tone_a: AudioStreamPlayer
var _tone_b: AudioStreamPlayer
var _tone_use_a: bool = true
var _tone_name: String = ""
var _tone_tween: Tween
var _last_scene: Node = null
var _scene_check: float = 0.0

var current_tone: String = ""

## REV 103: every one-shot, by name (InteractionManager uses it to know something responded).
signal played(sfx_name: String)

## REV 101: the room tone dips under speech so voices sit clearly on top: a little under any
## spoken line, more during a letterboxed conversation. Done with a volume effect on the Ambient
## bus itself, so it never fights the room-to-room crossfade or the player's volume settings.
const DUCK_VOICE_DB := -3.0
const DUCK_CONVERSATION_DB := -6.0
const DUCK_DOWN := 0.35
const DUCK_UP := 1.2
var _duck_voice := false
var _duck_conversation := false
var _duck_fx: AudioEffectAmplify = null
var _duck_tween: Tween


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for i in POOL_SIZE:
		var p := AudioStreamPlayer.new()
		p.bus = _bus("SFX")
		add_child(p)
		_pool.append(p)
	_tone_a = _make_tone_player()
	_tone_b = _make_tone_player()
	randomize()
	AudioSubtitleManager.line_started.connect(func(_f, _s, _t, _p, _b): _set_voice_duck(true))
	AudioSubtitleManager.line_finished.connect(func(_id): _set_voice_duck(false))


func _make_tone_player() -> AudioStreamPlayer:
	var p := AudioStreamPlayer.new()
	p.bus = _bus("Ambient")
	p.volume_db = -80.0
	add_child(p)
	return p


## ConversationPresenter calls this when the letterbox comes in and goes out.
func set_conversation_duck(on: bool) -> void:
	_duck_conversation = on
	_apply_duck()


func _set_voice_duck(on: bool) -> void:
	_duck_voice = on
	_apply_duck()


func _apply_duck() -> void:
	var idx := AudioServer.get_bus_index("Ambient")
	if idx < 0:
		return
	if _duck_fx == null:
		_duck_fx = AudioEffectAmplify.new()
		_duck_fx.volume_db = 0.0
		AudioServer.add_bus_effect(idx, _duck_fx)
	var target := 0.0
	if _duck_conversation:
		target = DUCK_CONVERSATION_DB
	elif _duck_voice:
		target = DUCK_VOICE_DB
	if _duck_tween != null and _duck_tween.is_valid():
		_duck_tween.kill()
	_duck_tween = create_tween()
	_duck_tween.set_trans(Tween.TRANS_SINE)
	var secs := DUCK_DOWN if target < _duck_fx.volume_db else DUCK_UP
	_duck_tween.tween_property(_duck_fx, "volume_db", target, secs)


func _bus(wanted: String) -> String:
	return wanted if AudioServer.get_bus_index(wanted) >= 0 else "Master"


func _process(delta: float) -> void:
	_scene_check -= delta
	if _scene_check > 0.0:
		return
	_scene_check = 0.4
	var scene := get_tree().current_scene
	if scene != _last_scene:
		_last_scene = scene
		set_tone(_tone_for_scene(scene))


# =========================================================================
# One-shots
# =========================================================================

func _stream(sfx_name: String) -> AudioStream:
	if _streams.has(sfx_name):
		return _streams[sfx_name]
	var path := DIR + sfx_name + ".wav"
	if not ResourceLoader.exists(path) and ResourceLoader.exists(DIR + sfx_name + ".mp3"):
		path = DIR + sfx_name + ".mp3"      # REV 741: the red alert klaxon is Glen's mp3
	# REV 293: "as AudioStream" so a wrong kind of file there is treated as missing, not an error
	var stream: AudioStream = (load(path) as AudioStream) if ResourceLoader.exists(path) else null
	_streams[sfx_name] = stream      # null is remembered too: a missing file is only looked for once
	return stream


## REV 168 (CLAUDE.md item 22): the interface sound family. Every menu, panel, clue and objective sound
## goes through ui(kind), so the set stays matched and quiet and obeys the INTERFACE SOUNDS volume (the UI
## bus, which feeds into SFX). kind -> [file in assets/audio/sfx, level dB]. Made by tools/make_ui_sfx.py.
const UI_SOUNDS := {
	"confirm": ["ui_confirm", -11.0],
	"back": ["ui_back", -11.0],
	"move": ["ui_move", -15.0],
	"open": ["ui_open", -13.0],
	"close": ["ui_close", -14.0],
	"focus": ["focus", -21.0],
	"invalid": ["deny", -10.0],
	"clue": ["clue", -7.0],
	"objective": ["objective", -7.0],
}
var _ui_pool: Array[AudioStreamPlayer] = []
var _ui_next := 0
var _ui_last := {}     # kind -> msec, so a burst of the same sound plays once
var _ui_warned := {}   # REV 293: unknown kinds already warned about

## Play an interface sound: "confirm", "back", "move", "open", "close", "focus", "invalid", "clue",
## "objective". `db` is added to its level, `pitch` shifts it a little (e.g. a softer sub-menu tick).
func ui(kind: String, db: float = 0.0, pitch: float = 1.0) -> void:
	var e: Array = UI_SOUNDS.get(kind, [])
	if e.is_empty():
		# a mistake in the calling code (a kind that isn't in UI_SOUNDS) - said once per kind, not every call
		if not _ui_warned.has(kind):
			_ui_warned[kind] = true
			push_warning("SfxManager.ui: no interface sound '%s'" % kind)
		return
	var now := Time.get_ticks_msec()
	if now - int(_ui_last.get(kind, -1000)) < 45:
		return
	_ui_last[kind] = now
	played.emit(String(e[0]))
	var stream := _stream(String(e[0]))
	if stream == null:
		return
	if _ui_pool.is_empty():
		for i in 4:
			var p := AudioStreamPlayer.new()
			p.bus = _bus("UI") if AudioServer.get_bus_index("UI") >= 0 else _bus("SFX")
			p.process_mode = Node.PROCESS_MODE_ALWAYS
			add_child(p)
			_ui_pool.append(p)
	var pl := _ui_pool[_ui_next]
	_ui_next = (_ui_next + 1) % _ui_pool.size()
	pl.stream = stream
	pl.volume_db = float(e[1]) + db
	pl.pitch_scale = pitch
	pl.play()


## True if that sound's file is in the project.
func has_sound(sfx_name: String) -> bool:
	return _stream(sfx_name) != null


func play(sfx_name: String, volume_db: float = 0.0, pitch: float = 1.0) -> void:
	played.emit(sfx_name)
	_play_on_pool(_stream(sfx_name), volume_db, pitch)


func _play_on_pool(stream: AudioStream, volume_db: float, pitch: float) -> void:
	if stream == null:
		return
	var p := _pool[_pool_next]
	_pool_next = (_pool_next + 1) % _pool.size()
	p.stream = stream
	p.volume_db = volume_db
	p.pitch_scale = pitch
	p.play()


## REV 293: picks among the step files that really exist for that surface (step_<surface>_1 .. _4),
## so one, two or three recordings work as well as four. None at all: silent, no warning.
const STEP_VARIANTS := 4
var _steps_found := {}   # surface -> Array of the step names that have a file

func footstep(surface: String) -> void:
	if not _steps_found.has(surface):
		var found: Array = []
		for i in range(1, STEP_VARIANTS + 1):
			var n := "step_%s_%d" % [surface, i]
			if has_sound(n):
				found.append(n)
		_steps_found[surface] = found
	var names: Array = _steps_found[surface]
	if names.is_empty():
		return
	# straight onto a player, NOT through play(): a footstep isn't an answer to anything, so it must not
	# send `played` (InteractionManager reads that as "the action did something").
	_play_on_pool(_stream(String(names[randi() % names.size()])), randf_range(-5.0, -2.0), randf_range(0.92, 1.08))


## Which surface a floor sounds like, from the name of what the player is
## standing on. Anything unrecognised uses the room's usual surface.
func surface_for_collider(collider: Object) -> String:
	var fallback: String = String(TONE_SURFACE.get(current_tone, "stone"))
	if collider == null or not (collider is Node):
		return fallback
	var n := String((collider as Node).name).to_lower()
	var parent := (collider as Node).get_parent()
	if parent != null:
		n += " " + String(parent.name).to_lower()
	if "lane" in n:
		return "wood"
	if "carpet" in n or "seat" in n or "rug" in n:
		return "carpet"
	if "grate" in n or "metal" in n or ("deck" in n and current_tone == "ship"):
		return "metal"
	if "sand" in n or "dirt" in n or "desert" in n:
		return "sand"
	if "stone" in n or "tile" in n or "marble" in n:
		return "stone"
	if "wood" in n or "plank" in n:
		return "wood"
	return fallback


# =========================================================================
# Room tone
# =========================================================================

## Picks the room sound from the scene's file name. Scenes that run their own
## music and ambience (the cold open, title screens, the main menu) get none.
func _tone_for_scene(scene: Node) -> String:
	if scene == null:
		return ""
	var key := (String(scene.scene_file_path) + " " + String(scene.name)).to_lower()
	for skip in ["coldopen", "mainmenu", "title", "boot", "endofprologue", "credits"]:
		if skip in key:
			return ""
	if "meld" in key:      # REV 297: Episode 2's mind melds (MeldOne / MeldTwo) - before "sickbay" etc.
		return "meld"
	for ship in ["enterprise", "bridge", "sickbay", "birdofprey", "bird_of_prey", "defiant", "maproom_", "turbolift", "maintenance", "daedalus", "engineering", "shuttle"]:
		if ship in key:
			return "ship"
	for outdoors in ["desert", "ruins", "exterior", "shikahr"]:
		if outdoors in key and not ("interior" in key):
			return "wind"
	if "bowling" in key:
		return "rec"
	return "interior"


func set_tone(tone_name: String) -> void:
	current_tone = tone_name
	if tone_name == _tone_name:
		return
	_tone_name = tone_name
	if _tone_tween != null:
		_tone_tween.kill()
	_tone_tween = null

	var outgoing := _tone_a if _tone_use_a else _tone_b
	var incoming := _tone_b if _tone_use_a else _tone_a
	_tone_use_a = not _tone_use_a
	if outgoing.playing:
		_tone_tween = create_tween().set_parallel(true)
		_tone_tween.tween_property(outgoing, "volume_db", -80.0, TONE_FADE)
		_tone_tween.chain().tween_callback(outgoing.stop)

	if tone_name == "":
		return
	var stream := _stream("amb_" + tone_name)
	if stream == null:
		return
	if _tone_tween == null:
		_tone_tween = create_tween().set_parallel(true)   # REV 99: only made when there is something to fade
	if stream is AudioStreamWAV:
		var wav := (stream as AudioStreamWAV).duplicate() as AudioStreamWAV
		wav.loop_mode = AudioStreamWAV.LOOP_FORWARD
		wav.loop_begin = 0
		# REV 293: the loop end is counted in samples from the sound's length, so a room tone Glen drops in
		# loops properly whatever way Godot stores it (plain 8/16-bit, or compressed: QOA / IMA-ADPCM,
		# where counting bytes would give the wrong end).
		wav.loop_end = maxi(1, int(round(wav.get_length() * wav.mix_rate)))
		stream = wav
	incoming.stream = stream
	incoming.volume_db = -80.0
	incoming.play()
	if TONE_SILENT_START.has(tone_name):     # REV 297: silence first, then a slow fade in
		var timing: Array = TONE_SILENT_START[tone_name]
		_tone_tween.tween_property(incoming, "volume_db", TONE_DB, float(timing[1])).set_delay(float(timing[0])).set_trans(Tween.TRANS_SINE)
		return
	_tone_tween.tween_property(incoming, "volume_db", TONE_DB, TONE_FADE)
