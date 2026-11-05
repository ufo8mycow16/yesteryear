extends Node3D
## YESTERYEAR - the short watch-through (story/YESTERYEAR_SHORT.md), played start to finish with no input.
##
## Each scene builds its set, puts the cast on their marks, then runs its beats in order: camera moves,
## lines (subtitles), walks, beams and pauses. Between scenes the screen fades to black and the old set is freed.
## Space / Enter skips the current line. Esc leaves.
##
## Cast with a model (Vulcan Fury's Daz figures and the sehlat) are real; everyone else is a labelled marker
## (Marker.gd) until they have one. Swap a marker for a model in _make_actor().

const Overlay := preload("res://scenes/watch/Overlay.gd")
const Marker := preload("res://scenes/watch/Marker.gd")
const Beam := preload("res://scenes/watch/Beam.gd")
const Story := preload("res://scenes/watch/Story.gd")
const Sets := preload("res://scenes/watch/Sets.gd")
# the creature scripts have no global class name - reach them through their files
const Sehlat := preload("res://core/creatures/Sehlat.gd")
const LeMatya := preload("res://core/creatures/LeMatya.gd")

## Display names for subtitles and markers
const NAMES := {
	"kirk": "Kirk", "spock": "Spock", "mccoy": "McCoy", "scotty": "Scotty", "thelin": "Thelin", "historian": "Historian",
	"guardian": "Guardian", "young_spock": "Young Spock", "sarek": "Sarek", "amanda": "Amanda",
	"ichaya": "I-Chaya", "lematya": "Le-matya", "healer": "Healer",
	"boy1": "Vulcan boy", "boy2": "Vulcan boy", "boy3": "Vulcan boy", "selek": "Spock",
}
## Marker heights (metres) for people without a model
const HEIGHTS := {"young_spock": 1.3, "boy1": 1.35, "boy2": 1.4, "boy3": 1.3, "lematya": 1.0, "amanda": 1.68,
	"sarek": 1.88, "healer": 1.7, "thelin": 1.85, "historian": 1.75}

var overlay: CanvasLayer
var cam: Camera3D
var set_node: Node3D = null
var actors := {}
var _look := Vector3.ZERO
var _skip := false
var _cam_tween: Tween = null


func _ready() -> void:
	overlay = Overlay.new()
	add_child(overlay)
	cam = Camera3D.new()
	cam.name = "StoryCamera"
	cam.fov = 50.0
	cam.near = 0.05
	cam.far = 2000.0
	add_child(cam)
	cam.make_current()
	_run.call_deferred()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_accept"):
		_skip = true
	elif event.is_action_pressed("ui_cancel"):
		get_tree().quit()


func _process(_delta: float) -> void:
	if cam != null and cam.global_position.distance_to(_look) > 0.01:
		cam.look_at(_look, Vector3.UP)


func _run() -> void:
	for scene in Story.SCENES:
		await _play_scene(scene)
	overlay.clear_line()
	await overlay.fade_to(1.0, 1.5)
	await overlay.title("STAR TREK\nYESTERYEAR\n\nThird Moon Interactive", 5.0)
	await get_tree().create_timer(1.0).timeout
	get_tree().quit()


func _play_scene(scene: Dictionary) -> void:
	await overlay.fade_to(1.0, 0.8)
	overlay.clear_line()
	_clear_set()
	set_node = Sets.build(self, String(scene["set"]))
	await get_tree().process_frame
	await get_tree().process_frame
	for who in scene.get("cast", {}).keys():
		var mark: Array = scene["cast"][who]
		_place(String(who), Sets.spot(set_node, mark[0]), float(mark[1]) if mark.size() > 1 else 0.0)
	var first: Array = scene.get("camera", [])
	if first.size() >= 2:
		_cut(Sets.spot(set_node, first[0]), Sets.spot(set_node, first[1]))
	await get_tree().create_timer(0.6).timeout     # let the figures settle into their idles
	if scene.has("title"):
		await overlay.title(String(scene["title"]), 3.0)
	await overlay.fade_to(0.0, 1.0)
	for beat in scene.get("beats", []):
		await _beat(beat)
	await get_tree().create_timer(0.8).timeout


func _beat(b: Array) -> void:
	var kind := String(b[0])
	match kind:
		"say":         # ["say", who, line]
			await _say(String(b[1]), String(b[2]))
		"note":        # ["note", text] - stage direction / voice-over shown in italics
			await _say("", String(b[1]))
		"cam":         # ["cam", from, look, seconds]  (seconds 0 = cut)
			var s := float(b[3]) if b.size() > 3 else 0.0
			if s <= 0.0:
				_cut(Sets.spot(set_node, b[1]), Sets.spot(set_node, b[2]))
			else:
				_move_cam(Sets.spot(set_node, b[1]), Sets.spot(set_node, b[2]), s)
		"walk":        # ["walk", who, to, seconds]
			var a: Node3D = actors.get(String(b[1]))
			if a != null:
				var to := Sets.spot(set_node, b[2])
				_face(a, to)
				var t := create_tween()
				t.tween_property(a, "global_position", to, float(b[3]))
		"face":        # ["face", who, at (spot or actor id)]
			var a: Node3D = actors.get(String(b[1]))
			if a != null:
				var at = b[2]
				_face(a, (actors[at] as Node3D).global_position if (at is String and actors.has(at)) else Sets.spot(set_node, at))
		"beam_in", "beam_out":   # ["beam_in", [who...]]
			for w in b[1]:
				var a: Node3D = actors.get(String(w))
				if a != null:
					Beam.play(set_node, a, a.global_position, kind == "beam_in")
			await get_tree().create_timer(3.1).timeout
		"show", "hide":
			for w in b[1]:
				var a: Node3D = actors.get(String(w))
				if a != null:
					a.visible = kind == "show"
		"remove":
			for w in b[1]:
				var a: Node3D = actors.get(String(w))
				if a != null:
					a.queue_free()
					actors.erase(String(w))
		"place":       # ["place", who, spot, facing_deg]
			_place(String(b[1]), Sets.spot(set_node, b[2]), float(b[3]) if b.size() > 3 else 0.0)
		"flare":       # ["flare", amount]
			var g := set_node.get("guardian") as Node3D if set_node != null else null
			if g != null and g.has_method("flare_up"):
				g.call("flare_up", float(b[1]))
		"sehlat":      # ["sehlat", method]  (settle, head_down, show_teeth)
			var s: Node3D = actors.get("ichaya")
			if s != null and s.has_method(String(b[1])):
				s.call(String(b[1]))
		"lematya":     # ["lematya", method, args...]  (play_clip "pounce"/"fight"/"wary", roar, snarl, sleep_now)
			var lm: Node3D = actors.get("lematya")
			if lm != null and lm.has_method(String(b[1])):
				lm.callv(String(b[1]), b.slice(2))
		"wait":
			await get_tree().create_timer(float(b[1])).timeout


func _say(who: String, line: String) -> void:
	overlay.say(String(NAMES.get(who, who.capitalize())) if who != "" else "", line)
	var a: Node3D = actors.get(who)
	var anim: Object = null
	if a != null and ClassDB.class_exists("CharacterKit"):
		anim = CharacterKit.animator_of(a)
	if anim != null and anim.has_method("talk"):
		anim.call("talk")
	_skip = false
	var hold := clampf(1.4 + line.length() * 0.055, 2.2, 7.5)
	var t := 0.0
	while t < hold and not _skip:
		await get_tree().process_frame
		t += get_process_delta_time()
	if anim != null and anim.has_method("stop_talk"):
		anim.call("stop_talk")
	overlay.clear_line()
	await get_tree().create_timer(0.25).timeout


func _place(who: String, at: Vector3, facing_deg: float) -> void:
	var a: Node3D = actors.get(who)
	if a == null:
		a = _make_actor(who, at, facing_deg)
		if a == null:
			return
		actors[who] = a
	a.global_position = at
	a.rotation_degrees.y = facing_deg
	a.visible = true


func _make_actor(who: String, at: Vector3, facing_deg: float) -> Node3D:
	match who:
		"kirk", "mccoy", "spock", "selek", "scotty":
			var key := "spock" if who == "selek" else who
			if ClassDB.class_exists("CharacterKit") or ResourceLoader.exists("res://core/characters/CharacterKit.gd"):
				var fig: Node3D = CharacterKit.make_named(key, {"solid": false})
				if fig != null:
					set_node.add_child(fig)
					return fig
		"thelin":
			var t := Thelin.make({"solid": false})
			if t != null:
				set_node.add_child(t)
				return t
		"lematya":
			var lm := LeMatya.make(set_node, "LeMatya", at, facing_deg)
			if lm != null:
				return lm
		"ichaya":
			var s := Sehlat.make(set_node, "IChaya", at, facing_deg)
			if s != null:
				return s
	var m := Marker.make(String(NAMES.get(who, who)), float(HEIGHTS.get(who, 1.8)))
	set_node.add_child(m)
	return m


func _face(a: Node3D, at: Vector3) -> void:
	var d := at - a.global_position
	d.y = 0.0
	if d.length() > 0.01:
		a.rotation.y = atan2(d.x, d.z)


func _cut(from: Vector3, look: Vector3) -> void:
	if _cam_tween != null and _cam_tween.is_valid():
		_cam_tween.kill()
	cam.global_position = from
	_look = look
	cam.look_at(_look, Vector3.UP)


func _move_cam(from: Vector3, look: Vector3, seconds: float) -> void:
	if _cam_tween != null and _cam_tween.is_valid():
		_cam_tween.kill()
	_cam_tween = create_tween().set_parallel(true).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_cam_tween.tween_property(cam, "global_position", from, seconds)
	_cam_tween.tween_property(self, "_look", look, seconds)


func _clear_set() -> void:
	actors.clear()
	if set_node != null:
		set_node.queue_free()
		set_node = null
