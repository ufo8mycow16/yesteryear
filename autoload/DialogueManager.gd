extends Node
## DialogueManager — topic-list conversation engine + contextual hint firing.
##
## Progression is never driven by exhausting dialogue or by a conversation
## counter (DR-0001 / DR-0004 design rule, reconciled throughout the
## Prologue). Hints fire from GameState variable conditions; topics are
## flavour unless a topic is explicitly marked progression_topic.

signal conversation_started(dialogue: DialogueData)
signal topics_available(topics: Array[DialogueTopicData])
signal conversation_ended(dialogue_id: String)
## REV 97: the line about to play (ConversationPresenter reads its target_id / emotion / shot).
signal line_starting(line: DialogueLineData)

var _active_dialogue: DialogueData
var _active_speaker_name: String = ""

## True from the moment a conversation starts until its opener/hint lines
## have finished playing and topics are offered. Without this, pressing
## TALK again while lines are still playing starts a second concurrent
## start_conversation() coroutine that races the first one — both awaiting
## the same AudioSubtitleManager.line_finished signal, overwriting
## _active_dialogue out from under each other. That's exactly what the
## trace log showed (two overlapping "start_conversation" calls before the
## first had finished) and it's why both NPCs went unresponsive afterward.
var _in_progress: bool = false


## Coroutine: every line in a conversation entry plays fully (via
## AudioSubtitleManager.line_finished) before the next starts, and topics
## are only offered once the opener + any contextual hint have finished —
## otherwise the opener's subtitle is overwritten by the hint's in the same
## frame and only the hint is ever visible, which is not "routing through
## the dialogue system," it just looks like a bypass of it.
func start_conversation(dialogue: DialogueData) -> void:
	if _in_progress:
		return  # a conversation is already mid-line; ignore the re-trigger rather than race it
	_in_progress = true

	_active_dialogue = dialogue
	conversation_started.emit(dialogue)

	# Contextual hints: first matching condition in authoring order, selected
	# purely from current investigation state — never from how many times
	# TALK has been pressed. A hint can be more than one line (e.g. a short
	# two-line exchange). Chosen BEFORE anything plays, because the opener and
	# a hint are alternative greetings for different states: a matching hint
	# replaces the generic opener unless it is marked follows_opening (REV 144).
	var hint_to_play: HintLineData = null
	for hint in dialogue.hints:
		if GameState.evaluate_condition(hint.condition):
			hint_to_play = hint
			break  # one hint entry per conversation start

	if dialogue.opening_line != null and (hint_to_play == null or hint_to_play.follows_opening):
		await _play_line_and_wait(dialogue.opening_line)
	if hint_to_play != null:
		for line in hint_to_play.lines:
			await _play_line_and_wait(line)

	_refresh_topic_states()
	_in_progress = false
	topics_available.emit(_visible_topics())


func select_topic(topic_id: String) -> void:
	if _in_progress:
		return  # a line from a previous selection is still playing
	if _active_dialogue == null:
		push_error("DialogueManager: select_topic called with no active conversation")
		return
	for topic in _active_dialogue.topics:
		if topic.id == topic_id:
			print("DialogueManager: select_topic(%s) starting, %d lines" % [topic_id, topic.lines.size()])
			_in_progress = true
			# REV 97: the protagonist says the chosen response first, when the topic has one
			if topic.response_line != null:
				await _play_line_and_wait(topic.response_line)
			var play_lines: Array = topic.lines
			if topic.lines_provider.is_valid():     # REV 475
				play_lines = topic.lines_provider.call()
			for line in play_lines:
				await _play_line_and_wait(line)
			if topic.state == DialogueTopicData.State.NEW:
				topic.state = DialogueTopicData.State.CONTINUING
			for clue_id in topic.grants_clues:
				Case.add(String(clue_id))
			_refresh_topic_states()
			_in_progress = false
			print("DialogueManager: select_topic(%s) done, re-offering topics (active_dialogue=%s)" % [
				topic_id, _active_dialogue.id if _active_dialogue != null else "null"
			])
			topics_available.emit(_visible_topics())
			return
	push_error("DialogueManager: unknown topic id %s" % topic_id)


func end_conversation() -> void:
	if _active_dialogue == null:
		print("DialogueManager: end_conversation() called but _active_dialogue is already null — no-op")
		return
	var id := _active_dialogue.id
	print("DialogueManager: end_conversation() ending %s (_in_progress was %s)" % [id, _in_progress])
	_active_dialogue = null
	_in_progress = false
	conversation_ended.emit(id)
	print("DialogueManager: conversation_ended emitted for %s" % id)


## True while a conversation is open or one of its lines is still playing.
func is_busy() -> bool:
	return _in_progress or _active_dialogue != null


## Clears conversation state without emitting anything - used when a save is
## loaded and the scene (with its dialogue UI) is being replaced.
func reset() -> void:
	_active_dialogue = null
	_active_speaker_name = ""
	_in_progress = false


func _visible_topics() -> Array[DialogueTopicData]:
	var result: Array[DialogueTopicData] = []
	if _active_dialogue == null:
		return result
	for topic in _active_dialogue.topics:
		if topic.state == DialogueTopicData.State.HIDDEN:
			continue
		if topic.hide_condition != "" and GameState.evaluate_condition(topic.hide_condition):     # REV 475
			continue
		# REV 108: an answer already given is gone (until a story change makes it NEW/REACTIVATED again)
		if topic.one_time and (topic.state == DialogueTopicData.State.CONTINUING or topic.state == DialogueTopicData.State.EXHAUSTED):
			continue
		result.append(topic)
	return result


func _refresh_topic_states() -> void:
	# A topic with an unlock_condition stays HIDDEN until that condition is true,
	# then appears as NEW (the player found something that gives them a new question).
	if _active_dialogue == null:
		return
	for topic in _active_dialogue.topics:
		if topic.unlock_condition != "" and topic.state == DialogueTopicData.State.HIDDEN:
			if GameState.evaluate_condition(topic.unlock_condition):
				topic.state = DialogueTopicData.State.NEW


func _play_line(line: DialogueLineData) -> void:
	for var_name in line.variables_set.keys():
		GameState.set_var(var_name, line.variables_set[var_name])
	line_starting.emit(line)
	AudioSubtitleManager.play_line(line.character_folder, line.filename, line.speaker_display_name, line.subtitle, line.audio_bus)


func _play_line_and_wait(line: DialogueLineData) -> void:
	_play_line(line)
	await AudioSubtitleManager.line_finished
