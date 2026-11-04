extends Node3D
## CinematicDialoguePreview (REV 97): try the letterboxed conversation mode. Not part of the game.
## New scene -> Node3D -> attach this script -> F6. Press SPACE to start a conversation.
##
## Shows the whole flow in miniature: bars slide in; McCoy speaks (camera on McCoy, who looks at
## Kirk); six choices appear (four visible, wheel/arrows scroll, 1-4 pick the visible rows); the
## chosen line is spoken by Kirk with the camera cut to him; McCoy replies; McCoy and Spock then
## talk to each other with NO choice bar; bars slide out. Lines are timed text here; in the game they
## come from DialogueManager / AudioSubtitleManager (see docs/DIALOGUE_CAMERA_DESIGN.md).


var ui: CinematicDialogueUI
var cam: Camera3D
var people := {}       # id -> {"node": Node3D, "face": CharacterFace or null, "name": String}
var running := false


func _ready() -> void:
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color(0.1, 0.1, 0.12)
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color(0.5, 0.5, 0.55)
	add_child(env)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-40, 25, 0)
	add_child(sun)

	_add_person("mccoy", "McCoy", CharacterKit.make_named("mccoy"), Vector3(0, 0, 0.8), Vector3(0, 0, -1))
	_add_person("kirk", "Kirk", CharacterKit.make_named("kirk"), Vector3(0, 0, -0.8), Vector3(0, 0, 1))
	_add_person("spock", "Spock", CharacterKit.make_named("spock"), Vector3(1.3, 0, 0), Vector3(-1, 0, 0))

	cam = Camera3D.new()
	cam.fov = 35.0
	add_child(cam)
	_wide()
	ui = CinematicDialogueUI.new()
	add_child(ui)


func _add_person(id: String, display: String, node: Node3D, pos: Vector3, look_dir: Vector3) -> void:
	add_child(node)
	node.position = pos
	CharacterKit.face_toward(node, pos + look_dir)
	people[id] = {"node": node, "face": CharacterFace.face_of(node), "name": display}


func _unhandled_input(event: InputEvent) -> void:
	var k := event as InputEventKey
	if k != null and k.pressed and k.keycode == KEY_SPACE and not running:
		_conversation()


func _conversation() -> void:
	running = true
	ui.enter()
	_cut_to("mccoy", "kirk")
	await ui.entered
	await _say("mccoy", "kirk", "Jim, there's something about these readings I don't like.")
	ui.show_choices([
		{"id": "find", "text": "What did you find, Bones?"},
		{"id": "wait", "text": "Can it wait?"},
		{"id": "spock", "text": "Spock, what do you make of it?"},
		{"id": "keep", "text": "Keep looking. Report back when you're certain."},
		{"id": "chapel", "text": "Has Nurse Chapel seen these?"},
		{"id": "sickbay", "text": "Let's take this to sickbay."},
	])
	var picked: String = await ui.choice_made
	var said := {"find": "What did you find, Bones?", "wait": "Can it wait?", "spock": "Spock, what do you make of it?",
		"keep": "Keep looking. Report back when you're certain.", "chapel": "Has Nurse Chapel seen these?",
		"sickbay": "Let's take this to sickbay."}
	await _say("kirk", "mccoy", String(said.get(picked, "")))
	await _say("mccoy", "kirk", "His cell structure is changing, Jim. Not damaged - changing.")
	# NPC to NPC: no choices, the camera and the bars just carry on
	await _say("spock", "mccoy", "Fascinating. A metamorphic process, Doctor?")
	await _say("mccoy", "spock", "Don't you start, Spock.")
	ui.exit()
	await ui.exited
	_wide()
	for id in people:
		var f: CharacterFace = people[id]["face"]
		if f != null:
			f.clear_look()
	running = false


## One line: top bar text, speaker and listener look at each other, camera on the speaker.
func _say(speaker: String, target: String, text: String) -> void:
	ui.show_line(String(people[speaker]["name"]), text)
	_cut_to(speaker, target)
	# (no voice files here; in the game the speaker's face gets play_lipsync() with the line's Rhubarb cues)
	await get_tree().create_timer(maxf(1.8, text.length() / 15.0)).timeout


## A simple over-the-shoulder / medium close-up on the speaker (the real shot maker comes later).
func _cut_to(speaker: String, target: String) -> void:
	var s_eyes := _eyes(speaker)
	var t_eyes := _eyes(target)
	for pair in [[speaker, target], [target, speaker]]:
		var f: CharacterFace = people[pair[0]]["face"]
		if f != null:
			var other_face: CharacterFace = people[pair[1]]["face"]
			if other_face != null:
				f.look_at_node(other_face.focus_node())
			else:
				f.look_at_point(_eyes(pair[1]))
	var across := (s_eyes - t_eyes)
	across.y = 0.0
	var side := across.normalized().cross(Vector3.UP)
	cam.global_position = t_eyes - across.normalized() * 0.55 + side * 0.35 + Vector3(0, 0.02, 0)
	cam.look_at(s_eyes + side * 0.05 - Vector3(0, 0.05, 0))


func _eyes(id: String) -> Vector3:
	var f: CharacterFace = people[id]["face"]
	if f != null and f.ready_to_use:
		return f.focus_point("eyes")
	return (people[id]["node"] as Node3D).global_position + Vector3(0, 1.66, 0)


func _wide() -> void:
	cam.global_position = Vector3(3.2, 1.7, 3.2)
	cam.look_at(Vector3(0.3, 1.3, 0.0))
