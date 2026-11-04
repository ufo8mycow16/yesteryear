extends Node
## Authored contextual exchanges that play without opening the topic UI.
## REV 293: NOT USED. It is registered as an autoload (project.godot) but no script calls define() or
## try_play(), so it never does anything. Rooms play their own background chat instead (the Prologue's
## BowlingAlley._background_chat, the episode rooms' say()). Kept in case authored banter is wanted later;
## nothing breaks if it is left alone.
signal banter_started(id: String)
signal banter_finished(id: String)
var _defs: Dictionary = {}
var _playing := false
func define(id: String, lines: Array, condition := "", once := true) -> void:
	_defs[id] = {"lines": lines, "condition": condition, "once": once}
func try_play(id: String) -> bool:
	# Do not interrupt story dialogue. AudioSubtitleManager owns one VO player, so a
	# banter exchange only starts in a genuinely quiet gap.
	if _playing or AudioSubtitleManager.is_line_active() or not _defs.has(id): return false
	var d: Dictionary = _defs[id]
	if bool(d.once) and bool(WorldState.get_value("banter/" + id, false)): return false
	if String(d.condition) != "" and not GameState.evaluate_condition(String(d.condition)): return false
	_play(id, d)
	return true
func _play(id: String, d: Dictionary) -> void:
	_playing = true
	banter_started.emit(id)
	for item in d.lines:
		var line := item as DialogueLineData
		if line == null: continue
		for var_name in line.variables_set.keys(): GameState.set_var(var_name, line.variables_set[var_name])
		var expected_id := line.filename.get_basename()
		AudioSubtitleManager.play_line(line.character_folder, line.filename, line.speaker_display_name, line.subtitle, line.audio_bus)
		# line_finished carries the stable line id. Ignore an unrelated completion
		# rather than accidentally advancing this exchange. In normal use the guard
		# above means there is only one line in flight.
		while true:
			var finished_id: String = await AudioSubtitleManager.line_finished
			if finished_id == expected_id:
				break
	if bool(d.once): WorldState.set_value("banter/" + id, true)
	_playing = false
	banter_finished.emit(id)
func is_busy() -> bool: return _playing
