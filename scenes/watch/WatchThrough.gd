extends Node3D
## YESTERYEAR - the short watch-through (story/YESTERYEAR_SHORT.md), played like a visual novel.
##
## Each scene builds its set, puts the cast on their marks, then runs its beats in order: camera moves,
## lines (subtitles), walks, beams and pauses. Between scenes the screen fades to black and the old set is freed.
## Lines wait for Space / Enter / a click (the first press finishes the typing, the next carries on); A turns
## auto-play on and off. Esc leaves.
## Choices (["choice", ...]) stop and wait for the player; they set story flags, and scenes and beats can depend
## on those flags (a scene's "when", the "if" beat) or jump back to an earlier scene ("goto", by the scene's "id").
##
## While someone talks, their mouth and hands move, the person they're talking to listens, and everyone nearby
## looks at them. The camera can follow a person ("@kirk" as a look target) and drifts very slightly on held shots.
## Each place has its own background sound (assets/audio/amb, made by tools/yesteryear/make_ambience.py).
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
	"sarek": 1.88, "healer": 1.7, "thelin": 1.85, "historian": 1.75, "ichaya": 1.0}

## Background sound for each set
const AMBIENCE := {
	"guardian": "amb_guardian", "guardian_night": "amb_guardian_night", "transporter": "amb_ship", "briefing": "amb_ship",
	"quarters": "amb_ship", "street": "amb_city", "courtyard": "amb_city", "courtyard_morning": "amb_city",
	"healer": "amb_city", "desert": "amb_desert_night", "desert_dawn": "amb_desert_dawn",
}
## One-off sounds: name -> [file, volume dB, pitch]
const SFX := {
	"beam": ["res://assets/audio/sfx/transporter_beam.wav", -6.0, 1.0],
	"chirp": ["res://assets/audio/sfx/intercom_chirp.wav", -8.0, 1.0],
	"swell": ["res://assets/audio/amb/guardian_swell.wav", -6.0, 1.0],
	"roar": ["res://assets/audio/sfx/gorn_roar.wav", -4.0, 1.35],
	"snarl": ["res://assets/audio/sfx/gorn_roar.wav", -10.0, 1.7],
}
## Beats that take no time - a line stays up across them when another line follows
const INSTANT := ["cam", "face", "place", "show", "hide", "remove", "flare", "sehlat", "lematya", "set", "clear",
	"walk", "mood", "gesture", "sfx", "look", "shot"]
const WALK_SPEED := 1.5      # fastest a walk is played (m/s) - a quicker one is slowed to this
const RUN_SPEED := 4.2
const DRIFT := 0.16          # how far a held shot creeps in (m)

var overlay: Overlay           # the preloaded script, so its own functions (say, choose...) are known
var cam: Camera3D
var set_node: Node3D = null
var actors := {}
var auto := false              # lines carry on by themselves (A)
var flags := {}                # story flags set by choices: name -> true
var _goto := ""                # a scene id to jump to once the current beat is done
var _look := Vector3.ZERO      # what the camera looks at
var _look_actor: Node3D = null # ... or who it keeps in frame
var _cam_base := Vector3.ZERO  # where the camera is, before its drift
var _cam_fwd := Vector3.ZERO   # the drift direction (zero while it's moving)
var _drift_t := 0.0
var _skip := false
var _cam_tween: Tween = null
var _walks := {}               # actor -> its walk tween
var _turns := {}               # actor -> its turn tween
var _amb_key := ""
var _amb: AudioStreamPlayer = null
var _first_scene := true


func _ready() -> void:
	overlay = Overlay.new()
	add_child(overlay)
	cam = Camera3D.new()
	cam.name = "StoryCamera"
	cam.fov = 48.0
	cam.near = 0.05
	cam.far = 2000.0
	add_child(cam)
	cam.make_current()
	_run.call_deferred()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_accept"):
		_skip = true
	elif event is InputEventMouseButton and (event as InputEventMouseButton).pressed \
			and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
		_skip = true
	elif event is InputEventKey and event.is_pressed() and not event.is_echo() and (event as InputEventKey).keycode == KEY_A:
		auto = not auto
		overlay.set_auto(auto)
	elif event.is_action_pressed("ui_cancel"):
		get_tree().quit()


func _process(delta: float) -> void:
	if cam == null:
		return
	if _look_actor != null and is_instance_valid(_look_actor):
		_look = _look.lerp(_eyes_of(_look_actor), 1.0 - exp(-delta * 3.5))
	var pos := _cam_base
	if _cam_fwd != Vector3.ZERO:
		_drift_t += delta
		pos += _cam_fwd * DRIFT * (1.0 - exp(-_drift_t / 9.0))
	cam.global_position = pos
	if pos.distance_to(_look) > 0.05:
		cam.look_at(_look, Vector3.UP)


# --------------------------------------------------------------------------------------------- scenes --

func _run() -> void:
	var scenes: Array = Story.SCENES
	var i := 0
	while i < scenes.size():
		var scene: Dictionary = scenes[i]
		i += 1
		if not _ok(String(scene.get("when", ""))):
			continue
		await _play_scene(scene)
		if _goto != "":
			for j in scenes.size():
				if String((scenes[j] as Dictionary).get("id", "")) == _goto:
					i = j
					break
			_goto = ""
	overlay.clear_line(true)
	_ambience("", 2.0)
	await overlay.fade_to(1.0, 2.0)
	await get_tree().create_timer(0.8).timeout
	await overlay.title("STAR TREK\nYESTERYEAR\n\n\nThird Moon Interactive", 6.0)
	await get_tree().create_timer(1.0).timeout
	get_tree().quit()


func _play_scene(scene: Dictionary) -> void:
	overlay.clear_line()
	var amb := String(AMBIENCE.get(String(scene["set"]), ""))
	if amb != _amb_key:
		_ambience("", 0.9)
	await overlay.fade_to(1.0, 0.9)
	overlay.clear_line(true)
	_clear_set()
	set_node = Sets.build(self, String(scene["set"]))
	await get_tree().process_frame
	await get_tree().process_frame
	for who in scene.get("cast", {}).keys():
		var mark: Array = scene["cast"][who]
		_place(String(who), Sets.spot(set_node, mark[0]), float(mark[1]) if mark.size() > 1 else 0.0)
	var first: Array = scene.get("camera", [])
	if first.size() >= 2:
		_cut(first[0], first[1])
	if String(scene.get("title", "")) != "":
		await overlay.title(String(scene["title"]), 3.2)
	else:
		await get_tree().create_timer(0.5).timeout    # let the figures settle into their idles
	_ambience(amb, 1.6)
	await overlay.fade_to(0.0, 1.2)
	if _first_scene:
		_first_scene = false
		overlay.show_hint()
	await _beats(scene.get("beats", []))
	overlay.clear_line()
	await get_tree().create_timer(1.0).timeout


func _beats(list: Array) -> void:
	for n in list.size():
		if _goto != "":
			return
		await _beat(list[n], _line_follows(list, n + 1))


## Whether the next beat that takes time is another line (so the current one can stay up until it replaces it).
func _line_follows(list: Array, from: int) -> bool:
	for n in range(from, list.size()):
		var k := String((list[n] as Array)[0])
		if k == "say" or k == "note":
			return true
		if not k in INSTANT:
			return false
	return false


## A flag test: "" is always true, "name" needs the flag, "!name" needs it unset.
func _ok(cond: String) -> bool:
	if cond == "":
		return true
	if cond.begins_with("!"):
		return not flags.has(cond.substr(1))
	return flags.has(cond)


# ---------------------------------------------------------------------------------------------- beats --

func _beat(b: Array, keep := false) -> void:
	var kind := String(b[0])
	match kind:
		"say":         # ["say", who, line, {to, mood, style, gesture}?]
			await _say(String(b[1]), String(b[2]), b[3] if b.size() > 3 else {}, keep)
		"note":        # ["note", text] - stage direction / log entry, in italics
			await _say("", String(b[1]), {}, keep)
		"cam":         # ["cam", from, look, seconds]  (seconds 0 = cut; look may be "@who" to follow them)
			var s := float(b[3]) if b.size() > 3 else 0.0
			if s <= 0.0:
				_cut(b[1], b[2])
			else:
				_move_cam(b[1], b[2], s)
		"shot":        # ["shot", who, with, kind, seconds?] - a shot worked out from where the two of them are standing:
			#   "ots" over with's shoulder onto who (the default), "close" on who alone, "two" both side by side,
			#   "wide" further out. Every shot of a pair is taken from the same side of them, so cuts don't flip.
			#   A kind ending in "!" uses the other side. seconds > 0 moves the camera there instead of cutting.
			_shot(String(b[1]), String(b[2]) if b.size() > 2 else "", String(b[3]) if b.size() > 3 else "ots",
				float(b[4]) if b.size() > 4 else 0.0)
		"walk":        # ["walk", who, to, seconds, "run"?]
			var a: Node3D = actors.get(String(b[1]))
			if a != null:
				_walk(a, Sets.spot(set_node, b[2]), float(b[3]), b.size() > 4 and String(b[4]) == "run")
		"face":        # ["face", who, at (spot or actor id)]
			var a: Node3D = actors.get(String(b[1]))
			if a != null:
				_face(a, _where(b[2]))
		"look":        # ["look", who, at (actor id or spot)] - a glance with the head only ("" to look ahead)
			var f := _face_of(actors.get(String(b[1])))
			if f != null:
				if String(b[2]) == "":
					f.clear_look()
				else:
					_look_at(f, b[2])
		"mood":        # ["mood", who, emotion ("" = neutral), strength?]
			var f := _face_of(actors.get(String(b[1])))
			if f != null:
				f.set_emotion(String(b[2]), float(b[3]) if b.size() > 3 else 0.8)
		"gesture":     # ["gesture", who, "nod" / "head_shake" / "shrug"]
			_gesture(actors.get(String(b[1])), String(b[2]))
		"sfx":         # ["sfx", name]
			_sfx(String(b[1]))
		"beam_in", "beam_out":   # ["beam_in", [who...]]
			_sfx("beam")
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
			if float(b[1]) >= 0.9:
				_sfx("swell")
		"sehlat":      # ["sehlat", method, args...]  (settle, head_down, show_teeth, play_clip "walk"...)
			var s: Node3D = actors.get("ichaya")
			if s != null and s.has_method(String(b[1])):
				s.callv(String(b[1]), b.slice(2))
		"lematya":     # ["lematya", method, args...]  (play_clip "pounce"/"fight"/"wary", roar, snarl, sleep_now)
			var lm: Node3D = actors.get("lematya")
			if lm != null and lm.has_method(String(b[1])):
				lm.callv(String(b[1]), b.slice(2))
			if String(b[1]) in ["roar", "snarl"]:
				_sfx(String(b[1]))
		"wait":
			await get_tree().create_timer(float(b[1])).timeout
		"choice":      # ["choice", prompt, [{"text", "set"?, "when"?}, ...]] - waits for the player
			var opts: Array = []
			var texts := PackedStringArray()
			for o in b[2]:
				if _ok(String((o as Dictionary).get("when", ""))):
					opts.append(o)
					texts.append(String(o["text"]))
			if opts.is_empty():
				return
			var pick: int = await overlay.choose(String(b[1]), texts)
			var chosen: Dictionary = opts[pick]
			if chosen.has("set"):
				flags[String(chosen["set"])] = true
		"if":          # ["if", condition, [beats if true], [beats if false]?]
			if _ok(String(b[1])):
				await _beats(b[2])
			elif b.size() > 3:
				await _beats(b[3])
		"set":         # ["set", flag]
			flags[String(b[1])] = true
		"clear":       # ["clear", flag]
			flags.erase(String(b[1]))
		"goto":        # ["goto", scene id] - ends this scene and carries on from that one
			_goto = String(b[1])
		"title":       # ["title", text, seconds] - over black
			overlay.clear_line()
			_ambience("", 1.0)
			await overlay.fade_to(1.0, 1.0)
			await overlay.title(String(b[1]), float(b[2]) if b.size() > 2 else 3.0)


# ----------------------------------------------------------------------------------------------- lines --

func _say(who: String, line: String, opts: Dictionary, keep: bool) -> void:
	var a: Node3D = actors.get(who)
	overlay.say(String(NAMES.get(who, who.capitalize())) if who != "" else "", line)
	var face := _face_of(a)
	var anim := _anim_of(a)
	var to: Node3D = actors.get(String(opts["to"])) if opts.has("to") else _addressee(a)
	if a != null:
		# the speaker looks at whoever they're talking to; everyone else nearby looks at the speaker
		if face != null:
			if to != null:
				_look_at(face, to)
			face.talk_mime(true, false)
			if opts.has("mood"):
				face.set_emotion(String(opts["mood"]), 0.8)
		for other in actors.values():
			var o := other as Node3D
			if o == a or not is_instance_valid(o) or not o.visible:
				continue
			if o.global_position.distance_to(a.global_position) > 9.0:
				continue
			var of := _face_of(o)
			if of != null:
				_look_at(of, a)
		if anim != null:
			anim.talk(String(opts.get("style", "")))
			if opts.has("gesture"):
				anim.gesture(String(opts["gesture"]))
		var to_anim := _anim_of(to)
		if to_anim != null:
			to_anim.listen()
	# the line types out; Space finishes it, then waits for Space (or carries on by itself on auto)
	_skip = false
	while overlay.is_typing():
		if _skip:
			overlay.finish_typing()
			_skip = false
			break
		await get_tree().process_frame
	var hold := clampf(0.9 + line.length() * 0.04, 1.6, 6.0)
	var t := 0.0
	if not auto:
		overlay.show_more(true)
	while not _skip:
		if auto:
			overlay.show_more(false)
			t += get_process_delta_time()
			if t >= hold:
				break
		else:
			overlay.show_more(true)
		await get_tree().process_frame
	_skip = false
	overlay.show_more(false)
	if face != null:
		face.talk_mime(false)
	if anim != null:
		anim.stop_talk()
	var ta := _anim_of(to)
	if ta != null:
		ta.stop_talk()
	if not keep:
		overlay.clear_line()
		await get_tree().create_timer(0.3).timeout


## Who someone is most likely talking to: the nearest person roughly in front of them.
func _addressee(a: Node3D) -> Node3D:
	if a == null:
		return null
	var fwd := a.global_transform.basis.z
	fwd.y = 0.0
	fwd = fwd.normalized()
	var best: Node3D = null
	var best_score := INF
	for other in actors.values():
		var o := other as Node3D
		if o == a or not is_instance_valid(o) or not o.visible:
			continue
		var d := o.global_position - a.global_position
		d.y = 0.0
		var dist := d.length()
		if dist < 0.2 or dist > 9.0:
			continue
		var cosang := fwd.dot(d / dist)
		if cosang < 0.2:
			continue
		var score := dist * (2.0 - cosang)
		if score < best_score:
			best_score = score
			best = o
	return best


func _look_at(f: CharacterFace, at: Variant) -> void:
	var node: Node3D = null
	if at is Node3D:
		node = at
	elif at is String and actors.has(at):
		node = actors[at]
	if node != null:
		var of := _face_of(node)
		if of != null and of.ready_to_use:
			f.look_at_node(of.focus_node())
		else:
			f.look_at_point(_eyes_of(node))
	else:
		f.look_at_point(_where(at))


func _gesture(a: Node3D, id: String) -> void:
	var anim := _anim_of(a)
	if anim == null:
		return
	if id in ["nod", "head_shake"]:
		anim.gesture(id)
	else:
		anim.play(id)


# ------------------------------------------------------------------------------------------- people --

func _place(who: String, at: Vector3, facing_deg: float) -> void:
	var a: Node3D = actors.get(who)
	if a == null:
		a = _make_actor(who, at, facing_deg)
		if a == null:
			return
		actors[who] = a
	if _walks.has(a):
		(_walks[a] as Tween).kill()
		_walks.erase(a)
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
		"healer", "amanda":
			var w := _make_woman(who)
			if w != null:
				set_node.add_child(w)
				return w
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


## The healer and Amanda: Vulcan Fury's crew-kit women - a face mixed region by region from the kit's faces,
## a kit skin and hair - in Glen's Royal Elf gown (the city's Vulcan women, CrewLooks.make_vulcan_woman, but
## chosen by hand). The healer is Vulcan (T'Pol's ears and skin, older eyes, greying hair, a cape for the night
## walk); Amanda is human, with a sixties up-do.
const WOMEN := {
	"healer": {
		"look": {"mix": {
				"eyes": {"austine": 0.6, "tpol": 0.4}, "brow": {"tpol": 0.7, "austine": 0.3},
				"nose": {"tpol": 0.5, "celeste": 0.5}, "mouth": {"austine": 0.5, "tpol": 0.5},
				"jaw": {"tpol": 0.6, "austine": 0.4}, "cheeks": {"austine": 0.6, "tpol": 0.4},
				"ears": {"tpol": 1.0}, "rest": {"tpol": 0.5, "austine": 0.5}},
			"skin": "tpol", "hair": "smooth_bob_0", "hair_tint": [0.80, 0.80, 0.82], "skin_tint": [1, 1, 1], "height": 0.98},
		"gown": "sand", "cape": true},
	"amanda": {
		"look": {"mix": {
				"eyes": {"kate": 0.6, "celeste": 0.4}, "brow": {"kate": 0.5, "celeste": 0.5},
				"nose": {"celeste": 0.6, "kate": 0.4}, "mouth": {"celeste": 0.5, "cressida": 0.5},
				"jaw": {"kate": 0.5, "celeste": 0.5}, "cheeks": {"kate": 0.6, "celeste": 0.4},
				"ears": {"kate": 1.0}, "rest": {"kate": 0.5, "celeste": 0.5}},
			"skin": "kate", "hair": "mega_updo_0", "hair_tint": [0.62, 0.46, 0.33], "skin_tint": [1, 1, 1], "height": 0.96},
		"gown": "plum", "cape": false},
}


func _make_woman(who: String) -> Node3D:
	var spec: Dictionary = WOMEN[who]
	var look: Dictionary = (spec["look"] as Dictionary).duplicate(true)
	var fig := CrewLooks.make_with_look("female", look, "red")
	if fig == null:
		return null
	if fig.get_child_count() > 0 and fig.get_child(0) is Node3D:
		(fig.get_child(0) as Node3D).scale = Vector3.ONE * float(look.get("height", 1.0))
	DazOutfit.wear(fig, "royal_gown", String(spec["gown"]), {} if bool(spec["cape"]) else {"leave_off": ["cape"]})
	fig.name = who.capitalize()
	fig.add_to_group("speakers")
	fig.set_meta("speaker_id", who)
	fig.set_meta("display_name", String(NAMES.get(who, who.capitalize())))
	return fig


func _face_of(a: Variant) -> CharacterFace:
	if a == null or not (a is Node) or not is_instance_valid(a):
		return null
	var f := CharacterFace.face_of(a as Node)
	return f if f != null and f.ready_to_use else null


func _anim_of(a: Variant) -> CharacterAnimator:
	if a == null or not (a is Node) or not is_instance_valid(a):
		return null
	return CharacterKit.animator_of(a as Node)


## Where someone's eyes are (for the camera and for glances).
func _eyes_of(a: Node3D) -> Vector3:
	var f := _face_of(a)
	if f != null:
		return f.focus_point("eyes")
	for who in actors.keys():
		if actors[who] == a:
			return a.global_position + Vector3(0, float(HEIGHTS.get(who, 1.75)) - 0.12, 0)
	return a.global_position + Vector3(0, 1.62, 0)


## A spot name, an actor id, or a position.
func _where(at: Variant) -> Vector3:
	if at is String and actors.has(at):
		return (actors[at] as Node3D).global_position
	return Sets.spot(set_node, at)


## A smooth turn to face a point (a quick one for a small turn).
func _face(a: Node3D, at: Vector3, seconds := 0.45) -> void:
	var d := at - a.global_position
	d.y = 0.0
	if d.length() < 0.01:
		return
	var want := atan2(d.x, d.z)
	var diff := wrapf(want - a.rotation.y, -PI, PI)
	if _turns.has(a):
		(_turns[a] as Tween).kill()
	if absf(diff) < 0.02 or seconds <= 0.0:
		a.rotation.y += diff
		return
	var t := create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	t.tween_property(a, "rotation:y", a.rotation.y + diff, seconds * clampf(absf(diff) / PI * 1.6, 0.45, 1.0))
	_turns[a] = t


## A walk: turn towards where they're going, ease into the step, walk at a believable pace, ease out.
func _walk(a: Node3D, to: Vector3, seconds: float, run: bool) -> void:
	var from := a.global_position
	var dist := Vector2(to.x - from.x, to.z - from.z).length()
	if dist < 0.02:
		return
	seconds = maxf(seconds, dist / (RUN_SPEED if run else WALK_SPEED))
	_face(a, to, 0.3)
	if _walks.has(a):
		(_walks[a] as Tween).kill()
	var ramp := clampf(0.4 / seconds, 0.0, 0.3)      # share of the walk spent speeding up (and slowing down)
	var step := func(p: float) -> void:
		if is_instance_valid(a):
			a.global_position = from.lerp(to, _ease_walk(p, ramp))
	var t := create_tween()
	t.tween_method(step, 0.0, 1.0, seconds)
	_walks[a] = t
	# the sehlat and the le-matya have their own walk and run clips (people's legs follow their speed by themselves)
	if a.has_method("play_clip") and _anim_of(a) == null:
		a.call("play_clip", "run" if run else "walk")
		var stop := func() -> void:
			if is_instance_valid(a):
				a.call("play_clip", "idle")
		t.tween_callback(stop)


static func _ease_walk(p: float, r: float) -> float:
	if r <= 0.0:
		return p
	var v := 1.0 / (1.0 - r)
	if p < r:
		return v * p * p / (2.0 * r)
	if p > 1.0 - r:
		return 1.0 - v * (1.0 - p) * (1.0 - p) / (2.0 * r)
	return v * (p - r * 0.5)


# ----------------------------------------------------------------------------------------------- camera --

## A camera position or look target: "@who" follows that person's eyes; anything else is a spot.
func _cam_target(key: Variant) -> Array:
	if key is String and String(key).begins_with("@"):
		var a: Node3D = actors.get(String(key).substr(1))
		if a != null:
			return [_eyes_of(a), a]
	return [Sets.spot(set_node, key), null]


func _cut(from: Variant, look: Variant) -> void:
	var lt := _cam_target(look)
	_cut_to(_cam_target(from)[0] as Vector3, lt[0] as Vector3, lt[1])


func _move_cam(from: Variant, look: Variant, seconds: float) -> void:
	var lt := _cam_target(look)
	_move_to(_cam_target(from)[0] as Vector3, lt[0] as Vector3, lt[1], seconds)


func _cut_to(pos: Vector3, look: Vector3, follow: Variant) -> void:
	if _cam_tween != null and _cam_tween.is_valid():
		_cam_tween.kill()
	_look = look
	_look_actor = follow as Node3D if follow is Node3D else null
	_cam_base = pos
	_start_drift()
	cam.global_position = _cam_base
	if _cam_base.distance_to(_look) > 0.05:
		cam.look_at(_look, Vector3.UP)


func _move_to(pos: Vector3, look: Vector3, follow: Variant, seconds: float) -> void:
	if _cam_tween != null and _cam_tween.is_valid():
		_cam_tween.kill()
	_cam_base = cam.global_position          # carry on from wherever the drift had got to
	_cam_fwd = Vector3.ZERO
	_cam_tween = create_tween().set_parallel(true).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_cam_tween.tween_property(self, "_cam_base", pos, seconds)
	if follow is Node3D:
		_look_actor = follow                 # follow them (the follow eases the look across)
	else:
		_look_actor = null
		_cam_tween.tween_property(self, "_look", look, seconds)
	_cam_tween.chain().tween_callback(_start_drift)


## A shot worked out from the people in it (see the "shot" beat).
func _shot(who: String, with: String, kind: String, seconds: float) -> void:
	var s: Node3D = actors.get(who)
	if s == null:
		return
	var flip := kind.ends_with("!")
	kind = kind.trim_suffix("!")
	var se := _eyes_of(s)
	var w: Node3D = actors.get(with) if with != "" else null
	var pos: Vector3
	var look := se
	var follow: Node3D = s
	if w == null:
		# on their own: from in front of them, a little to one side
		var f := s.global_transform.basis.z
		f.y = 0.0
		f = f.normalized() if f.length() > 0.01 else Vector3.BACK
		var side := f.cross(Vector3.UP) * (-1.0 if flip else 1.0)
		pos = se + f * (2.6 if kind == "wide" else 1.6) + side * 0.4
	else:
		var we := _eyes_of(w)
		var u := we - se
		u.y = 0.0
		var dist := u.length()
		u = u / dist if dist > 0.01 else Vector3.BACK
		# the line between the two: always film from the same side of it, whoever the shot is on
		var line := u if who < with else -u
		var perp := line.cross(Vector3.UP) * (-1.0 if flip else 1.0)
		match kind:
			"close":
				pos = se + u * minf(1.5, dist * 0.6) + perp * 0.45
				pos.y = se.y + 0.02
			"two", "wide":
				var mid := (se + we) * 0.5
				var out := dist * 0.8 + 1.5 if kind == "two" else dist * 1.4 + 3.5
				pos = mid + perp * out
				pos.y = mid.y + (0.08 if kind == "two" else 0.7)
				look = mid
				follow = null
			_:      # "ots"
				pos = we + u * 0.75 + perp * 0.42
				pos.y = lerpf(we.y, se.y, 0.35) + 0.05
	if seconds > 0.0:
		_move_to(pos, look, follow, seconds)
	else:
		_cut_to(pos, look, follow)


## A held shot creeps in very slightly, unless it's already close.
func _start_drift() -> void:
	_drift_t = 0.0
	var d := _look - _cam_base
	_cam_fwd = d.normalized() if d.length() > 2.0 else Vector3.ZERO


# ------------------------------------------------------------------------------------------------ sound --

## Fade the background sound to a new loop ("" = silence) over `seconds`.
func _ambience(key: String, seconds: float) -> void:
	if key == _amb_key:
		if _amb != null and key != "":
			var up := create_tween()
			up.tween_property(_amb, "volume_db", -6.0, seconds)
		return
	_amb_key = key
	if _amb != null:
		var old := _amb
		var out := create_tween()
		out.tween_property(old, "volume_db", -60.0, seconds)
		out.tween_callback(old.queue_free)
		_amb = null
	if key == "":
		return
	var path := "res://assets/audio/amb/%s.wav" % key
	if not ResourceLoader.exists(path):
		return
	var s := load(path) as AudioStreamWAV
	if s == null:
		return
	s = s.duplicate() as AudioStreamWAV
	s.loop_mode = AudioStreamWAV.LOOP_FORWARD
	s.loop_begin = 0
	s.loop_end = int(s.get_length() * s.mix_rate)
	_amb = AudioStreamPlayer.new()
	_amb.stream = s
	_amb.volume_db = -60.0
	add_child(_amb)
	_amb.play()
	var t := create_tween()
	t.tween_property(_amb, "volume_db", -6.0, seconds)


func _sfx(id: String) -> void:
	var spec: Array = SFX.get(id, [])
	if spec.is_empty() or not ResourceLoader.exists(String(spec[0])):
		return
	var p := AudioStreamPlayer.new()
	p.stream = load(String(spec[0]))
	p.volume_db = float(spec[1])
	p.pitch_scale = float(spec[2])
	add_child(p)
	p.finished.connect(p.queue_free)
	p.play()


func _clear_set() -> void:
	actors.clear()
	_walks.clear()
	_turns.clear()
	_look_actor = null
	if set_node != null:
		set_node.queue_free()
		set_node = null
