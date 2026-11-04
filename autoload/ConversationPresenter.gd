extends Node
## ConversationPresenter (REV 97): how a conversation LOOKS. DialogueManager (Prologue topics) and
## EpisodeRoom (Episode 1 scenes) still decide what is said; this turns a conversation into the
## letterboxed cinematic mode:
##   - bars slide in (CinematicDialogueUI), the player stops walking and turns to the person,
##   - a conversation camera blends in from the gameplay camera and cuts to whoever speaks
##     (over-the-shoulder / medium close-up / close-up / medium / wide), always from the same side of
##     the line between the two main people (the 180-degree rule), avoiding walls in the way,
##   - speaker and listener look at each other, others nearby look at the speaker (CharacterFace),
##     the speaker's mouth moves (Rhubarb cues beside the voice file, or voice loudness),
##   - the line is in the top bar; the player's choices in the bottom bar, only when there is a choice,
##   - at the end the bars slide out and the camera blends back to the gameplay camera.
## Lines spoken outside conversations still get lip sync on characters that have a face.
##
## Off switch: ConversationPresenter.enabled = false brings back the old topic list and subtitle box.
## Written without Godot to hand (untested in the engine when written).

signal mode_changed(letterboxed: bool)
signal _asked(index: int)

var enabled := true
var letterboxed := false
var ui: CinematicDialogueUI

const BLEND_IN := 0.7
const BLEND_OUT := 0.55
const CONVERSATION_FOV := 30.0
const DRIFT_SECONDS := 9.0
const END_ID := "__end"

var _depth := 0
var _scene: Node = null
var _cam: Camera3D
var _game_cam: Camera3D
var _cam_tween: Tween
var _first_shot := true
var _player_body: PlayerController
var _player_input_was := true
var _turned := false
var _protagonist := ""
var _partner := ""
var _partner_fig: Node3D = null
var _last_speaker := ""
var _side_sign := 0.0
var _new_speaker_shots := 0
var _hint: DialogueLineData = null
var _drift_tween: Tween
var _listener_fig: Node3D = null   # REV 116: who the current line is said to (they react now and then)
var _react_in := 2.5
var _turned_figs := {}          # REV 113: figure -> its rotation.y before it turned to talk
var _menu_prompt := ["", ""]  # REV 108: the line that opened this conversation's topic menu
## REV 167 (Tiffany, item 4): the conversation's own opening question. Its topics answer it, so the
## menu shows it - even when a situation-specific remark (a hint) was said in its place, which used
## to leave that remark ("Perhaps your assumptions have.") above choices like "Not yet."
var _opening_line := ["", ""]
var _ask_menus: Array = []       # REV 108: [{options, line}] - each ask() menu and the line that opened it
var _asked_texts := {}           # REV 108: options picked this conversation (shown greyed)
var _choice_mode := ""        # "topics" | "ask" | ""
var _ask_cancel := false      # Esc may back out of an ask() (returns -1)
var _last_line := ["", ""]
var _talking_face: CharacterFace = null
var _talking_anim: CharacterAnimator = null   # REV 129: whose talking gestures are playing
var _staging := false            # REV 147: the player is stepping to a comfortable talking distance
var _last_shot: Array = []       # REV 147: [kind, subject, other] - re-framed once staging finishes


func _ready() -> void:
	ui = CinematicDialogueUI.new()
	ui.name = "CinematicDialogueUI"
	add_child(ui)
	ui.choice_made.connect(_on_choice)
	DialogueManager.conversation_started.connect(func(d): _remember_opening(d); begin())
	DialogueManager.conversation_ended.connect(func(_id): end())
	DialogueManager.topics_available.connect(_on_topics)
	DialogueManager.line_starting.connect(func(line: DialogueLineData): _hint = line)
	AudioSubtitleManager.line_started.connect(_on_line_started)
	AudioSubtitleManager.line_finished.connect(_on_line_finished)
	AudioSubtitleManager.subtitle_requested.connect(_on_subtitle)


## True when the Prologue topic list should be shown here instead of by TopicListUI.
func handles_topics() -> bool:
	return enabled


# ---- entering and leaving -----------------------------------------------------------

## Start the cinematic mode (nested calls are counted; only the outermost one counts).
func begin() -> void:
	if not enabled:
		return
	_depth += 1
	if _depth > 1:
		return
	letterboxed = true
	_scene = get_tree().current_scene
	_partner = ""
	_partner_fig = null
	_last_speaker = ""
	_side_sign = 0.0
	_new_speaker_shots = 0
	_turned = false
	_last_line = ["", ""]
	_menu_prompt = ["", ""]
	_ask_menus.clear()
	_asked_texts.clear()
	_first_shot = true
	_player_body = get_tree().get_first_node_in_group("player") as PlayerController
	_protagonist = _speaker_id_of_body(_player_body)
	if _player_body != null:
		_player_input_was = _player_body.input_enabled
		_player_body.input_enabled = false
		_player_body.velocity = Vector3.ZERO
	# until someone speaks, the person nearest the player is who they're talking to
	_partner_fig = _nearest_figure(func(f: Node3D) -> bool: return _id_of(f) != _protagonist or _protagonist == "")
	_stage()
	ui.enter()
	SfxManager.set_conversation_duck(true)
	_take_camera()
	set_process(true)
	mode_changed.emit(true)


## REV 147 (CLAUDE.md item 22): before the first shot, make sure the two people talking aren't
## standing on top of each other (about 1.2-1.5 m apart) and the player isn't crowding anyone else
## in a group. Only the player's character moves - smoothly, a step or two, backwards if it's a step
## back - never the person they're talking to, who may be on a planned mark. Spots inside walls,
## props or other people are never used; if no good spot exists, nobody moves. Walking up to talk
## (InteractionManager) has usually placed them well already, and then this does nothing. Scenes
## that start while the player has no control (cutscenes) keep their authored blocking.
func _stage() -> void:
	_staging = false
	if not is_instance_valid(_player_body) or not is_instance_valid(_partner_fig):
		return
	if _player_body.is_ancestor_of(_partner_fig) or _player_body.is_auto_walking():
		return
	# an authored scene (the player didn't have control) keeps its own blocking
	if not _player_input_was or InteractionManager.is_locked():
		return
	var spot := Approach.talk_spot(_player_body, _partner_fig, "stage")
	if spot.is_empty():
		return
	_staging = true
	var body := _player_body
	var reached: bool = await body.walk_to(spot["pos"], spot["face"])
	_staging = false
	if not letterboxed or not is_instance_valid(body) or body != _player_body:
		return
	if not reached:
		return
	# the first shot was framed on where they WERE standing: frame it again, gently
	if _last_shot.size() == 3 and is_instance_valid(_last_shot[1]):
		_first_shot = true
		_shoot(String(_last_shot[0]), _last_shot[1], _last_shot[2] if is_instance_valid(_last_shot[2]) else null)


func end() -> void:
	if _depth == 0:
		return
	_depth -= 1
	if _depth > 0:
		return
	_finish()


func _finish() -> void:
	if _staging and is_instance_valid(_player_body):
		_player_body.cancel_auto_walk()
	_staging = false
	_last_shot = []
	_menu_prompt = ["", ""]
	_opening_line = ["", ""]
	_ask_menus.clear()
	_asked_texts.clear()
	_depth = 0
	letterboxed = false
	_choice_mode = ""
	ui.exit()
	SfxManager.set_conversation_duck(false)
	_release_camera()
	_turn_figures_back()
	_stop_talking()
	for f in get_tree().get_nodes_in_group("speakers"):
		var an := CharacterKit.animator_of(f)
		if an != null:
			an.stop_talk()
	for f in get_tree().get_nodes_in_group("speakers"):
		var face := CharacterFace.face_of(f)
		if face != null:
			face.clear_look()
			face.set_emotion("neutral")
	if is_instance_valid(_player_body):
		_player_body.input_enabled = _player_input_was
	_player_body = null
	mode_changed.emit(false)


## REV 116: the person being spoken to nods, tilts their head or blinks every few seconds.
func _tick_listener(delta: float) -> void:
	if not letterboxed or ui.choosing or _listener_fig == null or not is_instance_valid(_listener_fig):
		return
	_react_in -= delta
	if _react_in > 0.0:
		return
	_react_in = randf_range(2.2, 4.5)
	var face := CharacterFace.face_of(_listener_fig)
	var an := CharacterKit.animator_of(_listener_fig)
	var roll := randf()
	if roll < 0.45 and an != null and an.has_motion():
		an.gesture("nod", 0.5)          # REV 129: a real nod (the Mixamo one, gently)
		if face != null and face.ready_to_use:
			face.blink()
		return
	if face != null and face.ready_to_use:
		face.react("nod" if roll < 0.45 else ("tilt" if roll < 0.75 else "blink"))


func _process(delta: float) -> void:
	_tick_listener(delta)
	# the room was changed or a save loaded mid-conversation: never leave the bars stuck up
	if letterboxed and get_tree().current_scene != _scene:
		_finish()
	if not letterboxed and (_cam_tween == null or not _cam_tween.is_valid()):
		set_process(false)


func _unhandled_input(event: InputEvent) -> void:
	if letterboxed and ui.choosing and _choice_mode == "ask" and _ask_cancel and event.is_action_pressed("menu_cancel"):
		get_viewport().set_input_as_handled()
		ui.hide_choices()
		_asked.emit(-1)
		return
	if letterboxed and ui.choosing and _choice_mode == "topics" and event.is_action_pressed("menu_cancel"):
		get_viewport().set_input_as_handled()
		ui.hide_choices()
		DialogueManager.end_conversation()


## REV 167: a new conversation starts its own menu (also when one opens inside a held cinematic mode).
func _remember_opening(d: DialogueData) -> void:
	_menu_prompt = ["", ""]
	_opening_line = ["", ""]
	if d != null and d.opening_line != null and d.opening_line.subtitle != "":
		var ol := d.opening_line
		_opening_line = [GameNames.character(ol.character_folder, ol.speaker_display_name), ol.subtitle]
	# REV 554 (Glen: Kirk's menu still read "Any closer to solving the mystery?" when he had said "Lane 3's
	# waiting" in its place): a hint that REPLACES the opener (DialogueManager picks the first one whose
	# condition holds) is the question the menu answers - its last line, the one said just before it
	if d != null:
		for h in d.hints:
			var hint := h as HintLineData
			if hint == null or not GameState.evaluate_condition(hint.condition):
				continue
			if not hint.follows_opening and not hint.lines.is_empty():
				var hl := hint.lines[hint.lines.size() - 1] as DialogueLineData
				if hl != null and hl.subtitle != "":
					_opening_line = [GameNames.character(hl.character_folder, hl.speaker_display_name), hl.subtitle]
			break


# ---- choices ----------------------------------------------------------------------------

func _on_topics(topics: Array) -> void:
	if not letterboxed:
		return
	var choices: Array = []
	for t in topics:
		var topic := t as DialogueTopicData
		var text := topic.label
		if topic.response_line != null and topic.response_line.subtitle != "":
			text = topic.response_line.subtitle
		elif not topic.lines.is_empty() and topic.lines[0] != null and topic.lines[0].character_folder == _protagonist:
			# most topics already open with the protagonist's own sentence: offer that sentence
			text = topic.lines[0].subtitle
		# REV 108: questions already asked are greyed (still selectable, to hear the answer again)
		var asked := topic.state == DialogueTopicData.State.CONTINUING or topic.state == DialogueTopicData.State.EXHAUSTED
		choices.append({"id": topic.id, "text": text, "used": asked})
	choices.append({"id": END_ID, "text": "[End conversation]"})
	_choice_mode = "topics"
	# REV 108: the top bar shows the line these choices answer - the question that first opened
	# the menu - not whatever was said last after a side topic
	if _menu_prompt[1] == "" and _opening_line[1] != "":
		_menu_prompt = _opening_line.duplicate()
	if _menu_prompt[1] == "":
		_menu_prompt = _last_line.duplicate()
		_show_last_line_for_choice()
	elif _menu_prompt[1] != "":
		ui.show_line(String(_menu_prompt[0]), String(_menu_prompt[1]), _menu_prompt != _last_line)
	_frame_listener()
	ui.show_choices(choices)


## Episode 1 style: ask the player to pick one of `options`; returns its index.
func ask(options: Array, prompt: String = "", allow_cancel: bool = false) -> int:
	var choices: Array = []
	for i in options.size():
		var txt := str(options[i])
		# REV 108: an option already picked in this conversation is greyed (still selectable)
		choices.append({"id": str(i), "text": txt, "used": _asked_texts.has(txt)})
	if prompt != "" and _last_line[1] == "":
		_last_line = _prompt_line(prompt)
	_choice_mode = "ask"
	_ask_cancel = allow_cancel
	# REV 108: when a menu comes back (the same options, or some of them), show the question that
	# first opened it, not the last thing said after a side topic
	var anchor := _ask_anchor_for(options)
	if anchor.is_empty():
		_ask_menus.append({"options": options.map(func(o): return str(o)), "line": _last_line.duplicate()})
		_show_last_line_for_choice()
	else:
		ui.show_line(String(anchor[0]), String(anchor[1]), anchor != _last_line)
	_frame_listener()
	ui.show_choices(choices)
	var pick: int = await _asked
	_choice_mode = ""
	if pick >= 0 and pick < options.size():
		_asked_texts[str(options[pick])] = true
	return pick


## REV 490 (the redesign's {TIMED} choices): the time ran out on an open ask() - the choices go away and
## the ask returns -2 (EpisodeRoom.choose_timed turns that into "said nothing").
func time_out_ask() -> void:
	if letterboxed and ui != null and ui.choosing and _choice_mode == "ask":
		ui.hide_choices()
		_asked.emit(-2)


## REV 365: the letterbox bars' height on screen (0 when no conversation) - menus opened during a
## conversation keep inside the picture between them (ChoiceMenu).
func bar_height() -> float:
	return ui.bar_px() if letterboxed and ui != null else 0.0


## REV 359 (Glen: Episode 2's Sickbay menu showed a bare "SPOCK:" at the top, in plain lettering, with
## nothing after it). Scripted menus pass the player's name as their prompt ("SPOCK:", "KIRK:", "McCOY:",
## "SPOCK - PRESENT:") - it means "you are speaking as Spock". When nothing has been said yet, that tag
## was shown as if it were the line itself. Now a tag becomes a proper speaker line: the character's name
## in their own colour and bold conversation lettering (as every spoken line), then what the menu is for.
## Any other prompt (a question such as "WHICH TERM IS SUPPORTED...?") still shows as it is.
func _prompt_line(prompt: String) -> Array:
	var p := prompt.strip_edges()
	var name := p.trim_suffix(":").strip_edges()
	var extra := ""
	for sep in [" - ", " ("]:
		var at := name.find(sep)
		if at > 0:
			extra = name.substr(at + sep.length()).trim_suffix(")").trim_suffix(":").strip_edges()
			name = name.substr(0, at).strip_edges()
			break
	var id := name.to_lower()
	if not GameNames.has_character(id):
		return ["", prompt]
	var body := "(Choose what to say.)"
	match extra.to_lower():
		"present":
			body = "(Choose what to present.)"
		"deduce":
			body = "(Choose your conclusion.)"
		"walking":
			body = "(Choose what to say on the way.)"
	return [GameNames.character(id), body]


## The question line remembered for a menu whose options are all among an earlier menu's.
func _ask_anchor_for(options: Array) -> Array:
	# REV 852 (Glen: "when it returns to the dialogue choice, make sure it shows [the question] at the top of the
	# screen"): a question list that has GROWN since last time (answering one opens new ones - "Who?" after "Why do
	# you think he was killed?") is still the same menu, so it still gets its question back. It counts as the same
	# menu when most of its options were in it before (all of them when there are only one or two); the new
	# options join that menu for next time.
	for m in _ask_menus:
		var known: Array = m["options"]
		if options.is_empty() or String(m["line"][1]) == "":
			continue
		var shared := 0
		for o in options:
			if known.has(str(o)):
				shared += 1
		var needed := options.size() if options.size() <= 2 else maxi(2, ceili(options.size() * 0.5))
		if shared >= needed:
			for o in options:
				if not known.has(str(o)):
					known.append(str(o))
			return m["line"]
	return []


func _on_choice(id: String) -> void:
	match _choice_mode:
		"ask":
			_asked.emit(int(id))
		"topics":
			_choice_mode = ""
			if id == END_ID:
				DialogueManager.end_conversation()
			else:
				DialogueManager.select_topic(id)


func _show_last_line_for_choice() -> void:
	# the line being answered is always visible while choosing, even with subtitles off
	if _last_line[1] != "":
		ui.show_line(String(_last_line[0]), String(_last_line[1]))


## While the player chooses: look at the person they're answering.
func _frame_listener() -> void:
	var listener: Node3D = _partner_fig if is_instance_valid(_partner_fig) else null
	var me := _figure(_protagonist)
	if listener != null and me != null:
		_turn_figure_toward(listener, me.global_position)
		_shoot("CU", listener, me)     # REV 115: their face while you decide, as in KOTOR


# ---- lines --------------------------------------------------------------------------------

func _on_subtitle(speaker: String, text: String, _duration: float) -> void:
	if not letterboxed:
		return
	_last_line = [speaker, text]
	if GameSettings.wants_subtitles() or ui.choosing or speaker == "":     # REV 296: voiceless notes always show
		ui.show_line(speaker, text)


func _on_line_started(folder: String, _speaker: String, _text: String, audio_path: String, bus: String) -> void:
	var hint := _hint
	_hint = null
	var speaker_fig := _figure(folder)
	_lipsync(speaker_fig, audio_path, bus)
	if not letterboxed or speaker_fig == null:
		return
	var sid := _id_of(speaker_fig)
	if sid == "":
		sid = folder

	# who is this said to?
	var target_fig: Node3D = null
	if hint != null and hint.target_id != "":
		target_fig = _figure(hint.target_id)
	# REV 190 (Glen: Kirk's "All right, you two." then "If Spock's cheating..." - he reset between them):
	# the same person carrying on is still talking to the same person. Working the listener out afresh
	# swapped Kirk from Spock to McCoy, and turning to the new listener snapped his body round mid-shot.
	if target_fig == null and sid == _last_speaker and is_instance_valid(_listener_fig) and _listener_fig != speaker_fig:
		target_fig = _listener_fig
	if target_fig == null:
		if sid == _protagonist or folder == _protagonist:
			target_fig = _partner_fig if is_instance_valid(_partner_fig) else null
		elif _last_speaker != "" and _last_speaker != _protagonist and _last_speaker != sid:
			target_fig = _figure(_last_speaker)     # NPC answering NPC
		else:
			target_fig = _figure(_protagonist)
	if target_fig == speaker_fig:
		target_fig = null
	# the first other person to speak is who the player is talking to (replaces the nearest-person guess)
	if sid != _protagonist and folder != _protagonist and _partner == "":
		_partner = sid
		_partner_fig = speaker_fig

	_listener_fig = target_fig
	_react_in = randf_range(1.2, 2.4)
	# eyes
	_look(speaker_fig, target_fig)
	if target_fig != null:
		_look(target_fig, speaker_fig)
	for f in get_tree().get_nodes_in_group("speakers"):
		var fig := f as Node3D
		if fig == null or fig == speaker_fig or fig == target_fig or not fig.is_visible_in_tree():
			continue
		if fig.global_position.distance_to(speaker_fig.global_position) < 5.0 * _scale_of(speaker_fig):
			_look(fig, speaker_fig)
	var face := CharacterFace.face_of(speaker_fig)
	if face != null and hint != null and hint.emotion != "":
		face.set_emotion(hint.emotion)
	_act_line(speaker_fig, target_fig, sid, hint)

	if not _turned and _player_body != null and is_instance_valid(_partner_fig):
		_turned = true
		_turn_player_toward(_partner_fig.global_position)
	# REV 113: someone speaking to someone turns to face them (Kirk at the foul line no longer talks
	# to McCoy over his shoulder); they turn back when the conversation ends
	if target_fig != null and sid != _protagonist and folder != _protagonist:
		_turn_figure_toward(speaker_fig, target_fig.global_position)

	# camera
	var same := sid == _last_speaker
	_last_speaker = sid
	var shot := hint.shot.to_upper() if hint != null else ""
	if shot == "" and same and not _first_shot:
		return          # same person carrying on: hold the shot
	if shot == "":
		shot = _auto_shot(target_fig, hint)
	_shoot(shot, speaker_fig, target_fig)


func _auto_shot(target_fig: Node3D, hint: DialogueLineData) -> String:
	_new_speaker_shots += 1
	if target_fig == null:
		return "MCU"
	# REV 115: open on both of them (where are we, who's here), then cut in close - mostly tight
	# singles, an over-the-shoulder every third cut, close-ups for anything emotional
	if _new_speaker_shots == 1:
		return "TWO"
	if hint != null and hint.emotion != "" and hint.emotion != "neutral":
		return "CU"
	# REV 235 (Glen: in a single the speaker looked like they were talking to no one): every other cut is
	# over the listener's shoulder, so you see who they are talking to
	return "OTS" if _new_speaker_shots % 2 == 0 else "CU"


## REV 129: the speaker's body. Talking gestures through the line (heated lines get the arguing ones),
## and the line's own move if it has one (DialogueLineData.gesture).
var _listening_anim = null     # REV 242: the listener's animator during a line


func _act_line(fig: Node3D, target_fig: Node3D, sid: String, hint: DialogueLineData) -> void:
	var an := CharacterKit.animator_of(fig)
	if an == null or not an.has_motion():
		return
	_stop_talking()
	_talking_anim = an
	var emo := hint.emotion if hint != null else ""
	var style := ""
	if emo == "angry" or emo == "annoyed" or emo == "exasperated":
		style = "argue"
	elif emo == "furious":
		style = "argue_big"
	elif emo == "sad" or emo == "sorrowful" or emo == "grieving":
		style = "sad"
	an.talk(style)
	# REV 244: a reaction on the line's feeling (a laugh, a facepalm, Spock's eyebrow ...), upper body
	var g0 := hint.gesture if hint != null else ""
	var react := _reaction_for(sid, emo)
	if react != "" and g0 == "" and an.posture() == "stand":
		an.play(react, {"mask": "upper" if not react.begins_with("daz_eyebrow") else "head", "strength": 0.85, "fade_in": 0.3, "fade_out": 0.5})
	# REV 242: the one being spoken to listens (small attentive movements) instead of standing frozen
	if target_fig != null and is_instance_valid(target_fig) and target_fig != fig:
		var la := CharacterKit.animator_of(target_fig)
		if la != null and la.has_motion() and la != an:
			la.listen()
			_listening_anim = la
	var g := hint.gesture if hint != null else ""
	match g:
		"":
			pass
		"nod", "head_shake":
			an.gesture(g, 0.85)
		"point":
			if target_fig != null and is_instance_valid(target_fig):
				an.point_at(_eyes(target_fig) - Vector3.UP * 0.25 * _scale_of(target_fig), 0.8)
			else:
				an.play("point", {"hold": 0.8})
		"shrug":
			# a Vulcan doesn't shrug; the Captain's is a wry half of one
			if sid != "spock":
				an.play("shrug", {"strength": 0.55 if sid == "kirk" else 1.0})
		"think":
			match sid:
				"spock":
					an.play("think", {"mask": "arm_r_head", "strength": 0.9, "hold": 1.6})
				"kirk":
					an.play("think", {"mask": "arm_r_head", "rate": 1.3, "hold": 0.8})
				_:
					an.play("think", {"strength": 0.85, "hold": 1.4})
		_:
			# REV 244: the Daz reactions by name ("laugh", "facepalm", "eyebrow" ...), upper body
			if DAZ_GESTURES.has(g):
				an.play(String(DAZ_GESTURES[g]), {"mask": "upper", "strength": 0.9, "fade_in": 0.3, "fade_out": 0.5})
			else:
				an.play(g)


## REV 244: gesture names a line can ask for (DialogueLineData.gesture / staging "gesture") -> the Daz clips.
const DAZ_GESTURES := {
	"laugh": "daz_laugh_short", "laugh_long": "daz_laugh", "big_laugh": "daz_guffaw", "chuckle": "daz_laugh_2",
	"facepalm": "daz_facepalm", "finger_shake": "daz_finger_shake", "surprised": "daz_surprised",
	"shock": "daz_shock", "angry": "daz_angry", "yesss": "daz_yesss", "excited": "daz_excited",
	"yawn": "daz_yawn", "smile": "daz_smile", "eyebrow": "daz_eyebrow_r", "eyebrow_left": "daz_eyebrow_l",
	"eyebrow_serious": "daz_eyebrow_serious_r", "check_hand": "daz_check_hand", "big_idea": "daz_talk_big_idea",
	"directions_left": "daz_talk_directions_l", "directions_right": "daz_talk_directions_r",
}
## REV 244: a line's feeling -> who reacts how. Each entry: a list to pick from ("" = no reaction); a
## character's own list wins over "" (everyone else). Reactions play now and then, not every line.
const EMOTION_REACTIONS := {
	"amused": {"": ["daz_laugh_short", "daz_laugh_2", ""], "spock": [""], "kirk": ["daz_laugh_short", "daz_laugh_2", ""]},
	"annoyed": {"": ["daz_finger_shake", ""], "mccoy": ["daz_facepalm", "daz_finger_shake", ""], "spock": [""]},
	"exasperated": {"": ["daz_facepalm", ""], "spock": [""]},
	"surprised": {"": ["daz_surprised"], "spock": ["daz_eyebrow_r"]},
	"shocked": {"": ["daz_shock"], "spock": ["daz_eyebrow_serious_r"]},
	"angry": {"": ["daz_angry", ""], "spock": [""]},
	"furious": {"": ["daz_angry"], "spock": [""]},
	"triumphant": {"": ["daz_yesss"], "spock": [""]},
	"skeptical": {"": ["daz_eyebrow_serious_r", ""], "spock": ["daz_eyebrow_r", "daz_eyebrow_l"]},
	"curious": {"": [""], "spock": ["daz_eyebrow_r", "daz_eyebrow_l", ""]},
}

func _reaction_for(sid: String, emo: String) -> String:
	if not EMOTION_REACTIONS.has(emo):
		return ""
	var e: Dictionary = EMOTION_REACTIONS[emo]
	var pool: Array = e.get(sid, e.get("", [""]))
	var id := String(pool[randi() % pool.size()])
	return id if id != "" and MotionClips.has_clip(id) else ""


func _stop_talking() -> void:
	if _talking_anim != null and is_instance_valid(_talking_anim):
		_talking_anim.stop_talk()
	_talking_anim = null
	if _listening_anim != null and is_instance_valid(_listening_anim):
		_listening_anim.stop_talk()
	_listening_anim = null


func _on_line_finished(_id: String) -> void:
	_stop_talking()
	if _talking_face != null and is_instance_valid(_talking_face):
		_talking_face.stop_lipsync()
		_talking_face.talk_from_bus("")
	_talking_face = null


func _lipsync(fig: Node3D, audio_path: String, bus: String) -> void:
	_on_line_finished("")
	var face := CharacterFace.face_of(fig)
	if face == null or not face.ready_to_use:
		return
	var cues_path := audio_path.get_basename() + ".json"
	var cues: Array = []
	if audio_path != "" and FileAccess.file_exists(cues_path):
		cues = CharacterFace.load_rhubarb(cues_path)
	if not cues.is_empty():
		face.play_lipsync(cues, AudioSubtitleManager.voice_player())
	elif AudioSubtitleManager.voice_player().playing:
		face.talk_from_bus(bus)
	_talking_face = face


func _look(who: Node3D, at: Node3D) -> void:
	var face := CharacterFace.face_of(who)
	if face == null or at == null:
		return
	var other := CharacterFace.face_of(at)
	if other != null and other.ready_to_use:
		face.look_at_node(other.focus_node())
	else:
		face.look_at_point(_eyes(at))


## Turn a non-player figure to face `point` (only if they're more than ~30 degrees off), remembering
## how they stood so _finish() can turn them back.
func _turn_figure_toward(fig: Node3D, point: Vector3) -> void:
	if fig == null or not is_instance_valid(fig):
		return
	if is_instance_valid(_player_body) and _player_body.is_ancestor_of(fig):
		return
	var d := point - fig.global_position
	d.y = 0.0
	if d.length() < 0.01:
		return
	var face := _facing(fig)
	var delta := wrapf(atan2(d.x, d.z) - atan2(face.x, face.z), -PI, PI)
	if absf(delta) < deg_to_rad(30.0):
		return
	# REV 366: someone in a swivel chair turns WITH the chair, about the chair's own axis
	if SwivelSeat.active(fig):
		if not _turned_figs.has(fig):
			_turned_figs[fig] = "swivel"
		# REV 370 (Glen: the snap "looks weird... like 'WHAT CAPTAIN I'M BUSY'"): an unhurried swivel
		var to := SwivelSeat.angle(fig) + delta
		if _swivel_tweens.has(fig) and (_swivel_tweens[fig] as Tween).is_valid():
			(_swivel_tweens[fig] as Tween).kill()
		var t := create_tween()
		t.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		var f: Node3D = fig
		t.tween_method(func(a: float) -> void: SwivelSeat.set_angle(f, a), SwivelSeat.angle(fig), to, SWIVEL_TIME * clampf(absf(delta) / PI, 0.5, 1.0))
		_swivel_tweens[fig] = t
		return
	if not _turned_figs.has(fig):
		_turned_figs[fig] = fig.rotation.y
	# at once, not tweened: it happens on the camera cut to them, so it's never seen, and the shot
	# that follows is framed on the way they now face
	fig.rotation.y += delta


## REV 370: how long a half-turn (180 degrees) of a swivel chair takes; smaller turns are quicker (not under half).
const SWIVEL_TIME := 1.4
var _swivel_tweens := {}

func _turn_figures_back() -> void:
	for fig in _turned_figs.keys():
		if is_instance_valid(fig):
			var t := create_tween()
			t.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
			if typeof(_turned_figs[fig]) == TYPE_STRING:
				# REV 366: swivel back to the console, chair and all (typing picks up at rest)
				var f: Node3D = fig
				if _swivel_tweens.has(fig) and (_swivel_tweens[fig] as Tween).is_valid():
					(_swivel_tweens[fig] as Tween).kill()
				t.tween_method(func(a: float) -> void: SwivelSeat.set_angle(f, a), SwivelSeat.angle(f), 0.0, SWIVEL_TIME * clampf(absf(SwivelSeat.angle(f)) / PI, 0.5, 1.0))
				_swivel_tweens[fig] = t      # a new conversation's turn takes over from this one
			else:
				t.tween_property(fig, "rotation:y", float(_turned_figs[fig]), 0.6)
	_turned_figs.clear()


## REV 160 (Glen): a person turns to whoever they're talking to the way people do - nearly facing them
## already, only the head moves (the face looks); further round, the body turns most of the way and
## the head does the rest. In an authored scene (the player had no control, e.g. the Prologue's
## opening) the blocking is planned, so the body turns at most a shoulder's worth (30 degrees).
const PLAYER_TURN_HEAD_ONLY := 35.0   # degrees
const PLAYER_TURN_LEAVE := 15.0       # degrees left for the head to cover
const PLAYER_TURN_AUTHORED_MAX := 30.0

func _turn_player_toward(point: Vector3) -> void:
	var body := _player_body
	var d := point - body.global_position
	if Vector2(d.x, d.z).length() < 0.01:
		return
	var want := atan2(d.x, d.z)
	var delta := wrapf(want - body.rotation.y, -PI, PI)
	if absf(delta) < deg_to_rad(PLAYER_TURN_HEAD_ONLY):
		return
	var turn := delta - signf(delta) * deg_to_rad(PLAYER_TURN_LEAVE)
	var authored := not _player_input_was
	if authored:
		turn = clampf(turn, -deg_to_rad(PLAYER_TURN_AUTHORED_MAX), deg_to_rad(PLAYER_TURN_AUTHORED_MAX))
	var t := create_tween()
	t.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	t.tween_property(body, "rotation:y", body.rotation.y + turn, 0.8 if authored else 0.55)


# ---- the camera -------------------------------------------------------------------------

func _take_camera() -> void:
	_game_cam = get_viewport().get_camera_3d()
	var root := get_tree().current_scene
	if _game_cam == null or root == null:
		return
	if _cam == null or not is_instance_valid(_cam) or _cam.get_parent() != root:
		_cam = Camera3D.new()
		_cam.name = "ConversationCamera"
		root.add_child(_cam)
	_cam.near = 0.05
	_cam.far = _game_cam.far
	_cam.keep_aspect = _game_cam.keep_aspect
	_cam.fov = _game_cam.fov
	_cam.global_transform = _game_cam.global_transform
	_cam.current = true
	# REV 579: a first-person player camera hides the player's own body - bring it back for the conversation
	var n: Node = _game_cam
	while n != null:
		if n.has_method("release_first_person"):
			n.release_first_person()
			break
		n = n.get_parent()


func _release_camera() -> void:
	_kill(_cam_tween)
	_kill(_drift_tween)
	if _cam == null or not is_instance_valid(_cam):
		return
	if _game_cam == null or not is_instance_valid(_game_cam):
		_cam.current = false
		return
	_cam_tween = create_tween()
	_cam_tween.set_parallel(true).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_cam_tween.tween_property(_cam, "global_transform", _game_cam.global_transform, BLEND_OUT)
	_cam_tween.tween_property(_cam, "fov", _game_cam.fov, BLEND_OUT)
	_cam_tween.chain().tween_callback(func():
		if is_instance_valid(_game_cam):
			_game_cam.current = true
	)
	set_process(true)


## Put the conversation camera on `subject` (the speaker), framed against `other` (the listener).
## kind: OTS, MCU, CU, MS, WIDE/TWO. Blends on the first shot, cuts after that.
func _shoot(kind: String, subject: Node3D, other: Node3D) -> void:
	if _cam == null or not is_instance_valid(_cam) or subject == null:
		return
	_last_shot = [kind, subject, other]
	var xf := Transform3D()
	var ok := false
	var focus_dist := 2.0
	var push := Vector3.ZERO
	for k in _fallbacks(kind, other != null):
		var r := {}
		# REV 126: try the framing straight on, then swung round the speaker to either side, until
		# nobody else stands between the camera and their face (side-by-side people blocked it)
		# REV 173 (Glen: Kirk in pure profile, McCoy out of shot): swings of 35-60 degrees turned close-ups
		# into side-on profiles. Small swings only; a blocked close-up goes over the listener's shoulder.
		for swing in ([0.0] if k == "TWO" or k == "WIDE" else [0.0, 20.0, -20.0]):
			r = _shot(k, subject, other, swing)
			if r.has("xf") and _people_clear(r, subject, other, k) and _on_our_side(r):
				break
			r = {}
		if r.has("xf"):
			xf = r["xf"]
			focus_dist = float(r.get("focus", 2.0))
			push = r.get("push", Vector3.ZERO)
			ok = true
			break
	# REV 182 (Glen: in the bowling alley opening the camera stayed on Spock while McCoy and Kirk spoke):
	# when no framing passed every rule, the camera used to stay where it was - on the LAST speaker. The
	# speaker must always get the shot, so the rules are eased one at a time until one fits: first the
	# side of the line, then someone brushing the frame, then walls / an angled-away face (a plain
	# medium close-up, which always fits).
	if not ok:
		var relaxed := _relaxed_shot(kind, subject, other)
		if relaxed.has("xf"):
			xf = relaxed["xf"]
			focus_dist = float(relaxed.get("focus", 2.0))
			push = relaxed.get("push", Vector3.ZERO)
			ok = true
	if not ok:
		return
	_kill(_cam_tween)
	_kill(_drift_tween)
	_set_focus(focus_dist)
	if _first_shot:
		_first_shot = false
		_cam_tween = create_tween()
		_cam_tween.set_parallel(true).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		_cam_tween.tween_property(_cam, "global_transform", xf, BLEND_IN)
		_cam_tween.tween_property(_cam, "fov", CONVERSATION_FOV, BLEND_IN)
	else:
		_cam.global_transform = xf
		_cam.fov = CONVERSATION_FOV
		# REV 115: a slow push-in while the line plays, like a dolly - the frame is never dead still
		if not GameSettings.reduced_motion and push != Vector3.ZERO:
			_drift_tween = create_tween()
			_drift_tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
			_drift_tween.tween_property(_cam, "global_position", xf.origin + push, DRIFT_SECONDS)


## REV 182: the best framing of the speaker when none passes every rule (see _shoot). Tries, in order:
## everything but the 180-degree side; everything but the people check; then ignoring walls and which
## way they face. Returns {} only if the speaker has no position at all.
func _relaxed_shot(kind: String, subject: Node3D, other: Node3D) -> Dictionary:
	var kinds: Array = _fallbacks(kind, other != null)
	for k in ["MCU", "CU", "MS", "TWO", "WIDE"]:
		if not kinds.has(k):
			kinds.append(k)
	# 1. everything but the 180-degree side
	for k in kinds:
		for swing in ([0.0] if k == "TWO" or k == "WIDE" else [0.0, 20.0, -20.0]):
			var r := _shot(k, subject, other, swing)
			if r.has("xf") and _people_clear(r, subject, other, k):
				return r
	# 2. REV 243: never just ignore people (that put McCoy's shoulder over Kirk): wider swings round the
	# speaker too, and of everything that fits the room, the one hiding the least of the face
	var best := {}
	var best_b := INF
	for k in kinds:
		for swing in ([0.0] if k == "TWO" or k == "WIDE" else [0.0, 20.0, -20.0, 40.0, -40.0, 60.0, -60.0]):
			var r := _shot(k, subject, other, swing)
			if not r.has("xf"):
				continue
			var bl := _blocking(r, subject, other, k) + absf(swing) * 0.0008    # (straighter is better, a little)
			if bl < best_b:
				best_b = bl
				best = r
	if not best.is_empty():
		return best
	for k in ["MCU", "CU", "MS"]:
		var r2 := _shot(k, subject, other, 0.0, false)
		if r2.has("xf"):
			return r2
	return {}


## REV 115: soft background blur behind whoever is in focus (needs the Forward+ or Mobile renderer;
## the Compatibility renderer simply shows everything sharp).
## REV 554 (debug): the alley's Ctrl+7 switches the background blur off to see if it flickers.
var dof_allowed := true

func _set_focus(dist: float) -> void:
	if _cam == null:
		return
	var attrs := _cam.attributes as CameraAttributesPractical
	if GameSettings.quality_preset == 0 or not dof_allowed:      # REV 120: no blur on LOW (it costs frames on slow cards)
		if attrs != null:
			attrs.dof_blur_far_enabled = false
			attrs.dof_blur_near_enabled = false
		return
	if attrs == null:
		attrs = CameraAttributesPractical.new()
		_cam.attributes = attrs
	attrs.dof_blur_far_enabled = true
	attrs.dof_blur_far_distance = dist + 0.6
	attrs.dof_blur_far_transition = maxf(dist * 1.5, 1.5)
	attrs.dof_blur_amount = 0.05
	attrs.dof_blur_near_enabled = true            # the listener's shoulder in the foreground softens too
	attrs.dof_blur_near_distance = maxf(dist * 0.55, 0.3)
	attrs.dof_blur_near_transition = maxf(dist * 0.3, 0.2)


static func _fallbacks(kind: String, has_other: bool) -> Array:
	match kind:
		"OTS":
			return ["OTS", "MCU", "CU", "TWO"] if has_other else ["MCU", "CU"]
		"TWO":
			return ["TWO", "WIDE", "OTS", "CU"] if has_other else ["MS", "MCU", "CU"]
		"WIDE":
			return ["WIDE", "TWO", "OTS", "MCU", "CU"] if has_other else ["MS", "MCU", "CU"]
		"MS":
			return ["MS", "MCU", "CU"]
		"CU":
			return ["CU", "OTS", "MCU", "TWO"] if has_other else ["CU", "MCU"]
	# REV 171: if no close shot fits on our side of the line, the two-shot from the side always does
	return ["MCU", "OTS", "CU", "TWO"] if has_other else ["MCU", "CU"]


## One framing. Returns {"xf": Transform3D} or {} when a wall is in the way.
func _shot(kind: String, subject: Node3D, other: Node3D, swing_deg: float = 0.0, strict: bool = true) -> Dictionary:
	var k := _size_of(subject)
	var ko := _size_of(other) if other != null else k
	var s := _eyes(subject)
	var t := _eyes(other) if other != null else s + _facing(subject) * 1.2 * k
	var dir := t - s
	dir.y = 0.0
	if dir.length() < 0.05 * k:
		dir = _facing(subject)
	dir = dir.normalized()
	if swing_deg != 0.0:
		dir = dir.rotated(Vector3.UP, deg_to_rad(swing_deg))
	var side := _side_vector(subject, other, dir)
	var up := Vector3.UP
	var pos: Vector3
	var look: Vector3
	var sep := Vector2(t.x - s.x, t.z - s.z).length()
	match kind:
		"OTS":
			# REV 115 (KOTOR-style): tight on the speaker - head and shoulders - with the listener's
			# shoulder as a soft sliver at the edge. The camera never sits further from the speaker
			# than a close single would; if the listener is further away they simply drop out.
			var back := minf(sep + 0.45 * ko, 1.75 * k)
			look = s - side * 0.1 * k - up * 0.06 * k
			# REV 178 (Glen: the back of McCoy's head filled a quarter of Kirk's shot): with the two standing
			# close, the camera was half a metre behind the listener's head. Step further round until their
			# head covers at most OTS_MAX_COVER of the frame width; if no spot does, use a single instead.
			var found := false
			for off in OTS_SIDE_STEPS:
				pos = s + dir * back + side * off * k + up * 0.04 * k
				# REV 554 (Glen: McCoy's head hid Kirk): the listener's head as it really is from behind -
				# the skull's middle sits behind the eyes and the hair makes it bigger - checked from where the
				# camera starts and where its slow push-in ends
				if other == null or maxf(_ots_cover(pos, look, _head_ball(other, ko), ko),
						_ots_cover(pos + (look - pos) * DRIFT_PUSH, look, _head_ball(other, ko), ko)) <= OTS_MAX_COVER:
					found = true
					break
			if not found and strict:
				return {}
		"CU":
			# head and top of the shoulders, at eye level, speaker a little off-centre
			pos = s + dir * 1.15 * k + side * 0.3 * k + up * 0.01 * k
			look = s - side * 0.07 * k - up * 0.05 * k
		"MS":
			# REV 365 (Glen: heads cut off on the bridge): aimed at the chest (0.35 below the eyes) the head
			# sat under the letterbox's top bar - aim at the chin, so the head has room inside the bars
			pos = s + dir * 2.0 * k + side * 0.5 * k - up * 0.08 * k
			look = s - up * 0.16 * k
		"TWO":
			# REV 115: the opening shot - both of them in the room, from the side, at chest height:
			# who's talking to whom, and where
			var mid := (s + t) * 0.5
			# REV 365 (Glen: Kirk's and Spock's heads cut by the top bar): camera at mouth height, aimed just
			# below the eyes, and a little further back - both heads fully inside the bars
			pos = mid + side * (sep * 0.85 + 1.35 * k) - up * 0.06 * k + dir * 0.25 * sep
			look = mid - up * 0.12 * k
		"WIDE":
			var mid2 := (s + t) * 0.5
			pos = mid2 + side * (sep * 0.9 + 1.3 * k) - up * 0.06 * k
			look = mid2 - up * 0.15 * k     # REV 365: was 0.25 (heads under the top bar)
		_:  # MCU
			pos = s + dir * 1.3 * k + side * 0.34 * k - up * 0.02 * k   # a touch wider - head room
			# REV 184 (Glen: the letterbox bars cut the top of McCoy's head): aim nearer the eyes so the
			# head sits lower in the frame, with room above it inside the bars
			look = s - up * 0.05 * k
	if strict and not _clear(look, pos, [subject, other]):
		return {}
	# REV 113: never film the speaker from behind - if this camera position is behind their face,
	# try the next framing instead
	if strict and kind != "WIDE" and kind != "TWO":
		var to_cam := pos - s
		to_cam.y = 0.0
		if to_cam.length() > 0.01 and _facing(subject).dot(to_cam.normalized()) < 0.15:
			return {}
	var xf := Transform3D(Basis(), pos)
	# drift: ease 6% of the way in on the speaker over the line (wider shots drift sideways a little)
	var push := (look - pos) * DRIFT_PUSH
	if kind == "TWO" or kind == "WIDE":
		push = side * 0.12 * k
	return {"xf": xf.looking_at(look, Vector3.UP), "focus": pos.distance_to(s), "push": push, "eye": s}


## REV 178: how far round the speaker an over-the-shoulder may step (x figure size), nearest first; the
## widest is about 30 degrees off their sightline - still a three-quarter view, not a profile.
const OTS_SIDE_STEPS := [0.42, 0.55, 0.7, 0.85]
## REV 178: the most of the frame's width the listener's head may cover in an over-the-shoulder.
const OTS_MAX_COVER := 0.15     # REV 235: was 0.10 - with people closer, a little more shoulder and head is welcome


## REV 554: the listener's head for the over-the-shoulder check: radius with hair, and how far its middle
## sits behind the eyes (x figure size); the camera's push-in over a line (the drift in _shot).
const OTS_HEAD_RADIUS := 0.135
const OTS_HEAD_BEHIND_EYES := 0.085
const DRIFT_PUSH := 0.06

func _head_ball(fig: Node3D, k: float) -> Vector3:
	return _eyes(fig) - _facing(fig) * OTS_HEAD_BEHIND_EYES * k


## REV 178: the share of the frame's width the listener's head would cover, seen from cam looking at look
## (0 = out of shot). The head is taken as a 0.11 m ball; the frame from CONVERSATION_FOV and the window shape.
func _ots_cover(cam: Vector3, look: Vector3, head: Vector3, size_k: float) -> float:
	var fwd := look - cam
	fwd.y = 0.0
	var to_h := head - cam
	to_h.y = 0.0
	if fwd.length() < 0.01 or to_h.length() < 0.01:
		return 1.0
	var vp := get_viewport().get_visible_rect().size
	var aspect := vp.x / maxf(vp.y, 1.0) if vp.y > 0.0 else 16.0 / 9.0
	var half_w := atan(tan(deg_to_rad(CONVERSATION_FOV * 0.5)) * aspect)
	var a := absf(fwd.signed_angle_to(to_h, Vector3.UP))
	if a > PI * 0.5:
		return 0.0      # behind the camera
	var r := atan(OTS_HEAD_RADIUS * size_k / to_h.length())     # REV 554: was 0.11 (a bare skull at the eyes)
	var inner := a - r              # the head's edge nearest the middle of the frame
	if inner >= half_w:
		return 0.0
	return clampf((half_w - inner) / (2.0 * half_w), 0.0, 1.0)


## The 180-degree rule: one side of the line between the protagonist and their partner, chosen at the
## first shot (the side the gameplay camera was already on) and kept for the whole conversation.
func _side_vector(subject: Node3D, other: Node3D, dir: Vector3) -> Vector3:
	var a := _figure(_protagonist)
	var b := _partner_fig if is_instance_valid(_partner_fig) else other
	var axis := dir
	if a != null and b != null and a != b:
		axis = b.global_position - a.global_position
		axis.y = 0.0
		if axis.length() < 0.01:
			axis = dir
		axis = axis.normalized()
	var perp := Vector3.UP.cross(axis).normalized()
	if _side_sign == 0.0:
		_side_sign = 1.0
		if _game_cam != null and is_instance_valid(_game_cam) and a != null:
			_side_sign = 1.0 if perp.dot(_game_cam.global_position - a.global_position) >= 0.0 else -1.0
	return perp * _side_sign


## REV 171 (Glen, 20 Oct: Kirk and McCoy both faced the same way while talking): a swung framing
## (tried when someone blocks the shot) could cross the line between the two people, flipping who
## faces left and who faces right. Every camera must stay on the conversation's side of that line.
func _on_our_side(r: Dictionary) -> bool:
	var a := _figure(_protagonist)
	var b := _partner_fig if is_instance_valid(_partner_fig) else null
	if a == null or b == null or a == b or _side_sign == 0.0:
		return true
	var axis := b.global_position - a.global_position
	axis.y = 0.0
	if axis.length() < 0.01:
		return true
	var side := Vector3.UP.cross(axis.normalized()) * _side_sign
	var cam: Vector3 = (r["xf"] as Transform3D).origin
	return (cam - a.global_position).dot(side) > 0.05 * _size_of(a)


## REV 126: no one else's head or body between the camera and the speaker's face. In an
## over-the-shoulder the listener is allowed, but only as a shoulder at the edge of the frame.
func _people_clear(r: Dictionary, subject: Node3D, other: Node3D, kind: String) -> bool:
	return _blocking(r, subject, other, kind) <= 0.0


## REV 243 (Glen's screenshot: Kirk speaking, hidden behind McCoy's shoulder in an over-the-shoulder
## on Spock): how much of the speaker's face is hidden by other people (0 = none). Each person is a
## body - a column from the hips to the top of the head, as wide as their shoulders, narrower at the
## head - not two points, so a shoulder beside the line counts; and the whole face is checked (its
## middle and both sides), not just one point. A camera right behind someone's head is always blocked.
const BODY_RADIUS := 0.21      # shoulders (x the person's size)
const HEAD_RADIUS := 0.12
const FACE_HALF := 0.09        # how far either side of the face's middle is checked
func _blocking(r: Dictionary, subject: Node3D, other: Node3D, kind: String) -> float:
	var cam_xf: Transform3D = r["xf"]
	var cam_pos := cam_xf.origin
	var face: Vector3 = r.get("eye", _eyes(subject))
	var ks := _size_of(subject)
	var right := cam_xf.basis.x.normalized()
	var aims := [face, face + right * FACE_HALF * ks, face - right * FACE_HALF * ks, face - Vector3.UP * 0.12 * ks]
	var worst := 0.0
	for f in get_tree().get_nodes_in_group("speakers"):
		var fig := f as Node3D
		if fig == null or fig == subject or not fig.is_visible_in_tree():
			continue
		var k := _size_of(fig)
		var eyes := _eyes(fig)
		# REV 140: a camera right behind someone's head sees nothing but the back of it
		if cam_pos.distance_to(eyes) < 0.5 * k:
			return 10.0
		var top := eyes + Vector3.UP * 0.1 * k
		var neck := eyes - Vector3.UP * 0.2 * k
		var hips := Vector3(eyes.x, maxf(fig.global_position.y + 0.85 * k, eyes.y - 0.75 * k), eyes.z)
		var listener_edge := kind == "OTS" and fig == other
		for aim in aims:
			# the head
			var dh := _seg_seg(cam_pos, aim, neck, top)
			var allowed_h := HEAD_RADIUS * k
			worst = maxf(worst, allowed_h - dh)
			# the body (an over-the-shoulder's listener may show a shoulder at the frame's edge: only
			# a body that's well into the picture counts)
			var db := _seg_seg(cam_pos, aim, hips, neck)
			var allowed_b := BODY_RADIUS * k * (0.55 if listener_edge else 1.0)
			worst = maxf(worst, allowed_b - db)
	return worst


## Shortest distance between two line segments (p1-p2 and q1-q2).
static func _seg_seg(p1: Vector3, p2: Vector3, q1: Vector3, q2: Vector3) -> float:
	var d1 := p2 - p1
	var d2 := q2 - q1
	var r := p1 - q1
	var a := d1.dot(d1)
	var e := d2.dot(d2)
	var f := d2.dot(r)
	var s := 0.0
	var t := 0.0
	if a <= 1e-9 and e <= 1e-9:
		return p1.distance_to(q1)
	if a <= 1e-9:
		t = clampf(f / e, 0.0, 1.0)
	else:
		var c := d1.dot(r)
		if e <= 1e-9:
			s = clampf(-c / a, 0.0, 1.0)
		else:
			var b := d1.dot(d2)
			var den := a * e - b * b
			s = clampf((b * f - c * e) / den, 0.0, 1.0) if den > 1e-9 else 0.0
			t = (b * s + f) / e
			if t < 0.0:
				t = 0.0
				s = clampf(-c / a, 0.0, 1.0)
			elif t > 1.0:
				t = 1.0
				s = clampf((b - c) / a, 0.0, 1.0)
	# ignore the very ends of the camera's line (the camera itself and the face itself)
	s = clampf(s, 0.02, 0.97)
	return (p1 + d1 * s).distance_to(q1 + d2 * t)


func _clear(from: Vector3, to: Vector3, people: Array) -> bool:
	var world := get_viewport().find_world_3d()
	if world == null:
		return true
	var q := PhysicsRayQueryParameters3D.create(from, to)
	var skip: Array[RID] = []
	for f in get_tree().get_nodes_in_group("speakers"):
		_collect_rids(f, skip)
	for p in people:
		if p != null:
			_collect_rids(p, skip)
	for b in get_tree().get_nodes_in_group("see_through"):     # REV 605: a force field doesn't block a shot
		if b is CollisionObject3D:
			skip.append((b as CollisionObject3D).get_rid())
	q.exclude = skip
	return world.direct_space_state.intersect_ray(q).is_empty()


static func _collect_rids(fig: Node, out: Array[RID]) -> void:
	if fig == null:
		return
	var parent := fig.get_parent()
	if parent is CollisionObject3D:
		out.append((parent as CollisionObject3D).get_rid())
	for c in fig.find_children("*", "CollisionObject3D", true, false):
		out.append((c as CollisionObject3D).get_rid())


# ---- finding people -----------------------------------------------------------------

## The figure for a speaker id ("mccoy", "guard" ...): figures made by CharacterKit carry their
## make_named key; "custodian" also matches "vulcan_custodian". Unknown voices (e.g. Yeoman Pell, made
## without a name) go to the nearest unnamed figure, then the conversation partner.
func _figure(id: String) -> Node3D:
	if id == "":
		return null
	var key := id.to_lower()
	var named := _nearest_figure(func(f: Node3D) -> bool: return _matches(f, key))
	if named != null:
		return named
	if key == _protagonist:
		return null
	if not letterboxed:
		return null
	var unnamed := _nearest_figure(func(f: Node3D) -> bool: return _id_of(f) == "", 8.0)
	if unnamed != null:
		return unnamed
	return _partner_fig if is_instance_valid(_partner_fig) else null


static func _matches(fig: Node3D, key: String) -> bool:
	var fid := _id_of(fig)
	return fid != "" and (fid == key or fid.ends_with("_" + key) or key.ends_with("_" + fid))


func _nearest_figure(test: Callable, max_metres: float = 1.0e9) -> Node3D:
	var from := _player_body.global_position if is_instance_valid(_player_body) else Vector3.ZERO
	var best: Node3D = null
	var best_d := max_metres
	for f in get_tree().get_nodes_in_group("speakers"):
		var fig := f as Node3D
		if fig == null or not fig.is_visible_in_tree():
			continue
		if is_instance_valid(_player_body) and _player_body.is_ancestor_of(fig) and _id_of(fig) != _protagonist:
			continue
		if not bool(test.call(fig)):
			continue
		var d := fig.global_position.distance_to(from)
		if d < best_d:
			best_d = d
			best = fig
	return best


static func _id_of(fig: Node) -> String:
	return String(fig.get_meta("speaker_id", "")) if fig != null else ""


func _speaker_id_of_body(body: Node) -> String:
	if body == null:
		return ""
	for c in body.get_children():
		if c.is_in_group("speakers"):
			return _id_of(c)
	return ""


func _eyes(fig: Node3D) -> Vector3:
	# REV 132: the stand-ins too follow the head as it really is (sitting, standing up, bending)
	return CharacterKit.eyes_world(fig)


## REV 113: how big this person is in the room (1.0 = a normal-sized adult), measured from their eye
## height - right for imported models whose node scale means nothing (McCoy's Daz model is scaled
## to fit, the CharacterKit figures by the room's scale).
func _size_of(fig: Node3D) -> float:
	if fig == null:
		return 1.0
	# standing eye height (not this moment's - someone sitting isn't a smaller person)
	var face := CharacterFace.face_of(fig)
	var h := (CharacterKit.head_top_local(fig) * 0.935) * _scale_of(fig)
	if face != null and face.ready_to_use:
		h = face.focus_point("eyes").y - fig.global_position.y
		if CharacterKit.animator_of(fig) != null and CharacterKit.animator_of(fig).posture() != "stand":
			h = CharacterKit.head_top_local(fig) * 0.935 * _scale_of(fig)
	return clampf(h / 1.62, 0.2, 20.0) if h > 0.05 else _scale_of(fig)


static func _scale_of(fig: Node3D) -> float:
	return maxf(0.1, fig.global_transform.basis.get_scale().y) if fig != null else 1.0


static func _facing(fig: Node3D) -> Vector3:
	var f := fig.global_transform.basis.z
	f.y = 0.0
	return f.normalized() if f.length() > 0.001 else Vector3.BACK


static func _kill(t: Tween) -> void:
	if t != null and t.is_valid():
		t.kill()
