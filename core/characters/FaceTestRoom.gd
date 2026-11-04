extends Node3D
## FaceTestRoom (REV 97): a quick check of CharacterFace on McCoy. Not part of the game.
## Make a new scene with a Node3D, attach this script, press F6 (Run Current Scene).
## McCoy follows a floating ball with his eyes and head, blinks, and every two seconds
## changes expression. Keys: 1-8 = mouth shapes A-H, 0 = rest, B = blink, L = stop looking.

const MODEL := "res://assets/models/characters/McCoy_daz.fbx"   # REV 293: was the removed McCoy_rigged.glb
const EMOTIONS := ["neutral", "happy", "worried", "angry", "surprised", "sad", "curious", "stern"]

var face: CharacterFace
var ball: MeshInstance3D
var cam: Camera3D
var t := 0.0
var emo := 0
var label: Label


func _ready() -> void:
	var mccoy := CharacterFace.make_model(MODEL, null, "mccoy")   # REV 293: his id (skin detail, face fixes)
	if mccoy != null:
		add_child(mccoy)
		face = CharacterFace.face_of(mccoy)

	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-35, 30, 0)
	add_child(sun)
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color(0.12, 0.12, 0.14)
	env.environment.ambient_light_color = Color(0.5, 0.5, 0.55)
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	add_child(env)

	ball = MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = 0.04
	sphere.height = 0.08
	ball.mesh = sphere
	add_child(ball)

	cam = Camera3D.new()
	add_child(cam)
	cam.fov = 30.0
	label = Label.new()
	add_child(label)
	if face != null:
		face.look_at_node(ball)
	else:
		label.text = "No face: is %s in the project?" % MODEL


func _process(delta: float) -> void:
	t += delta
	ball.position = Vector3(sin(t * 0.7) * 0.9, 1.65 + sin(t * 1.3) * 0.35, 1.2)
	if face == null or not face.ready_to_use:
		return
	# a medium close-up, framed on the eyes (what the dialogue camera will do)
	var eyes := face.focus_point("eyes")
	cam.global_position = eyes + face.facing() * 1.1 + Vector3(0.15, 0.0, 0.0)
	cam.look_at(eyes - Vector3(0, 0.08, 0))
	if fmod(t, 2.0) < delta:
		emo = (emo + 1) % EMOTIONS.size()
		face.set_emotion(EMOTIONS[emo])
	label.text = "emotion: %s   shapes: %d   (1-8 mouth, 0 rest, B blink, L look on/off)" % [EMOTIONS[emo], face.shape_names().size()]


func _unhandled_key_input(event: InputEvent) -> void:
	var k := event as InputEventKey
	if k == null or not k.pressed or face == null:
		return
	var letters := "ABCDEFGH"
	if k.keycode >= KEY_1 and k.keycode <= KEY_8:
		var letter := letters[k.keycode - KEY_1]
		face.play_lipsync([{"start": 0.0, "end": 0.6, "value": letter}])
	elif k.keycode == KEY_0:
		face.stop_lipsync()
	elif k.keycode == KEY_B:
		face.blink()
	elif k.keycode == KEY_L:
		if face._looking:
			face.clear_look()
		else:
			face.look_at_node(ball)
