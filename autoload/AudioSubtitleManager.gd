extends Node
## AudioSubtitleManager — stable-ID VO playback with voice-optional subtitles.
##
## Dialogue must keep working whether or not the final voice asset exists yet.
## Subtitle presentation never depends on successful audio playback: if the
## .mp3 for a line's stable ID is missing, this logs it cleanly and still
## emits the subtitle signal so the UI shows the authored text.
##
## RUNTIME-STABILISATION FIX (this pass): a file that EXISTS but fails to
## load as a valid AudioStream (not yet reimported by the editor, wrong
## encoding, corrupt export, etc.) used to fall through with no fallback
## timer at all — _player.play() was never called, so _player.finished
## never fires, so line_finished never emits for that line, so EVERY
## await AudioSubtitleManager.line_finished caller (every dialogue line,
## every cutscene, the Uhura hand-off, the opening cutscene) hangs forever
## on that one line. That is almost certainly what "a significant amount of
## generated dialogue currently isn't playing correctly" was actually
## describing — not lines being skipped, but a whole conversation freezing
## partway through on whichever line happened to be unloadable. The fallback
## timer now fires on ANY path that didn't actually start playback, not only
## the "file doesn't exist at all" case.
##
## CLIPPING FIX (this pass): VO was audibly glitching (half a second of
## audio, a cutout, silence, then an artifact) even though every line here
## reports loaded=true/playing/finished with a correct duration — because
## clipping is a signal-level problem, not a load/playback failure, so it
## never shows up in this trace. Confirmed by testing the same files past
## 100% volume in VLC, which produces the identical artifact: the source
## files are mastered right at 0dBFS with no headroom, and Godot's own
## resampling/mixing is enough extra signal processing to tip a hot file
## over into clipping on output. default_bus_layout.tres's "Dialogue" bus
## is trimmed -6dB as a mitigation so Godot's processing doesn't push
## borderline files over the edge — this does NOT fix the source files,
## which are still peaking at/near 0dBFS. The real fix is re-exporting the
## voice-generation output with headroom (target roughly -3 to -6 dBFS true
## peak instead of slamming to 0dBFS); once that's done upstream, the -6dB
## trim on the Dialogue bus can come back out.

signal subtitle_requested(speaker: String, text: String, duration: float)
signal line_finished(line_id: String)
## Fired when the player clicks to skip the current line (the HUD hides its
## subtitle box at once). line_finished follows straight after.
signal line_skipped()
## REV 97: a line is starting (before its subtitle). character_folder is the speaker id ("mccoy"),
## audio_path the voice file looked for (lip-sync cues sit beside it as <same name>.json).
## Used by ConversationPresenter for the camera, eyes and lip sync.
signal line_started(character_folder: String, speaker: String, text: String, audio_path: String, bus: String)

const SPEECH_ROOT := "res://episodes/prologue/audio/speech/"
## Where voice files are looked up. Episode scenes change this (Episode 1 uses
## res://episodes/episode1/audio/speech/); the Prologue just leaves the default.
var speech_root: String = SPEECH_ROOT
const MIN_SUBTITLE_SECONDS := 1.6
const CHARS_PER_SECOND := 16.0  # rough reading-speed fallback when no audio length is known

## A/B test for the "first half-second plays, cuts out, goes quiet, then an
## artifact" report — that symptom matches a known class of Godot MP3-decoder
## glitch on certain encodings, not a logic bug (the trace log already showed
## every opening-cutscene line loading and finishing cleanly). Flip this to
## true to play the .wav copies instead, same character/filename, with
## "speech" swapped for "wav" in the path — e.g.
## res://episodes/prologue/audio/wav/mccoy/MCCOY_PRO_0001.wav. That's a guess
## at where the wav folder actually is; the path is printed below every line,
## so if it's wrong just tell me the real layout and this constant is the
## only thing that needs to change.
const USE_WAV_FOR_TESTING := false
const WAV_ROOT := "res://episodes/prologue/audio/wav/"

## The last HISTORY_MAX lines spoken, oldest first: {"speaker": String, "text": String}.
## Shown by the dialogue history panel (key T). Not saved with the game.
const HISTORY_MAX := 100
var history: Array[Dictionary] = []

var _player: AudioStreamPlayer
var _current_line_id: String = ""
## Bumped every time a line starts (and on stop_all). A fallback timer from an
## earlier line only counts if its number is still current, so a stale timer
## can never cut a newer line short (matters after a load).
var _line_serial: int = 0


func _ready() -> void:
	_player = AudioStreamPlayer.new()
	_player.name = "VOPlayer"
	_player.bus = "Dialogue"
	add_child(_player)
	_player.finished.connect(_on_player_finished)


## character_folder e.g. "mccoy" | "kirk" | "spock" | "uhura"
## filename e.g. "MCCOY_PRO_0016.mp3" — the stable ID from the design docs.
## bus_name routes this line's playback — "Dialogue" (default) for an in-room
## voice, or "Intercom" for a comm-channel voice (see DialogueLineData.audio_bus
## and default_bus_layout.tres for what that bus actually does to the sound).
## REV 680 (Glen: the Omnipedia Majel reference is "very clean"): every ship's computer voice plays through the
## "ShipComputer" bus - a 1960s ship's-speaker sound (narrower, boxy, a touch of grit and hull), tuned in
## default_bus_layout.tres. The recordings stay clean; only the playback is roughed up. A computer line already sent to
## another bus (e.g. "Intercom") keeps it.
const COMPUTER_VOICES := ["computer", "computer_glorious", "computer_memory", "sickbay_computer", "vulcan_computer"]


func play_line(character_folder: String, filename: String, speaker: String, subtitle_text: String, bus_name: String = "Dialogue") -> void:
	if bus_name == "Dialogue" and character_folder in COMPUTER_VOICES and AudioServer.get_bus_index("ShipComputer") >= 0:
		bus_name = "ShipComputer"
	# REV 144: every on-screen speaker name comes from the one names table (rank + surname), whatever
	# the calling script wrote; speakers not in the table keep the name they were given.
	speaker = GameNames.character(character_folder, speaker)
	var line_id := filename.get_basename()
	_line_serial += 1
	var my_serial := _line_serial
	_current_line_id = line_id
	_player.bus = bus_name
	var path: String
	if filename.begins_with("res://"):
		# REV 160: a line that lives outside the episode's own speech folder (the shared refusal and
		# scan pools, LinePools.POOL_SPEECH_ROOT)
		path = filename
	elif USE_WAV_FOR_TESTING:
		path = WAV_ROOT.path_join(character_folder).path_join(filename.get_basename() + ".wav")
	else:
		path = speech_root.path_join(character_folder).path_join(filename)

	var duration := _estimate_duration(subtitle_text)
	var duration_is_real := false
	var playback_started := false
	var exists := ResourceLoader.exists(path)

	if exists:
		var stream: AudioStream = load(path)
		if stream != null and not GameSettings.wants_speech():
			# Subtitles-only: keep the line's real length for timing, but stay silent.
			_player.stop()
			if stream.has_method("get_length") and stream.get_length() > 0.0:
				duration = stream.get_length()
		elif stream != null:
			_player.stream = stream
			_player.play()
			playback_started = true
			if stream.has_method("get_length") and stream.get_length() > 0.0:
				duration = stream.get_length()
				duration_is_real = true
			print("AudioSubtitleManager [%s]: exists=true loaded=true bus=%s playing (duration=%.2fs, %s)" % [
				line_id, bus_name, duration, "from audio" if duration_is_real else "estimated — stream reported zero length"
			])
		else:
			push_warning("AudioSubtitleManager: UNLOADABLE VO ASSET — id=%s path=%s (file exists but failed to load as an AudioStream; check it's a valid, Godot-imported .mp3). Showing subtitle only." % [line_id, path])
	else:
		push_warning("AudioSubtitleManager: MISSING VO ASSET — id=%s path=%s. Showing subtitle only." % [line_id, path])

	line_started.emit(character_folder, speaker, subtitle_text, path, bus_name)
	history.append({"speaker": speaker, "text": subtitle_text})
	if history.size() > HISTORY_MAX:
		history.remove_at(0)

	subtitle_requested.emit(speaker, subtitle_text, duration)

	# Fires line_finished on a timer whenever real playback did NOT start —
	# covers both "file missing" and "file exists but failed to load" — so
	# every await'er still unblocks instead of hanging on a bad file.
	if not playback_started:
		var timer := get_tree().create_timer(duration, false)
		timer.timeout.connect(_on_fallback_timeout.bind(my_serial))


## Click anywhere on the game (left mouse button) to move on from the line that
## is playing: the voice stops, the subtitle goes, and whatever was waiting for
## the line carries on with the next one. Clicks on buttons and sliders, clicks
## while a menu is open, and left+right (walking) clicks are left alone.
func _input(event: InputEvent) -> void:
	if _current_line_id == "":
		return
	if not (event is InputEventMouseButton):
		return
	var click := event as InputEventMouseButton
	if not click.pressed or click.button_index != MOUSE_BUTTON_LEFT:
		return
	if Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT):
		return
	if InteractionManager.is_modal_suspended():
		return
	var hovered := get_viewport().gui_get_hovered_control()
	if hovered is BaseButton or hovered is Range or hovered is LineEdit:
		return
	skip_current_line()


## The player the voice lines play through (lip sync follows its playback position).
func voice_player() -> AudioStreamPlayer:
	return _player


func is_line_active() -> bool:
	return _current_line_id != ""


func skip_current_line() -> void:
	if _current_line_id == "":
		return
	_line_serial += 1      # cancels the fallback timer of this line
	_player.stop()
	line_skipped.emit()
	_on_player_finished()


func _on_fallback_timeout(serial: int) -> void:
	if serial == _line_serial:
		_on_player_finished()


func _estimate_duration(text: String) -> float:
	return max(MIN_SUBTITLE_SECONDS, text.length() / CHARS_PER_SECOND)


func _on_player_finished() -> void:
	var finished_id := _current_line_id
	print("AudioSubtitleManager [%s]: finished" % finished_id)
	_current_line_id = ""
	line_finished.emit(finished_id)


## Silences whatever is playing without announcing "finished" - used when a
## save is loaded and the scene that was waiting on the line is being replaced.
func stop_all() -> void:
	_line_serial += 1
	_current_line_id = ""
	_player.stop()
