class_name CharacterMotion
extends RefCounted
## REV 129: one character's animation, from the Mixamo clips. CharacterAnimator owns one of these
## when the character's skeleton can take the clips (MotionRig), and tells it each frame how fast the
## character is moving and turning; everything else is asked for by name:
##
##   posture       "stand" | "sit" | "kneel" - sit() / stand() / kneel() play the move between them
##   stance        how this character stands still: "kirk" (hands on hips), "spock" (hands behind his
##                 back, straightened), "" (the ordinary idle) - always with the idle's breathing on top
##   talk()        gestures while speaking (a loop on the upper body, at a modest strength)
##   play()        a one-off move: "shrug", "point", "think", "button", "pick_up", "look_behind", ...
##   gesture()     a nod or head shake on top of whatever else is going on
##
## Layers, bottom to top: standing/moving (or sitting/kneeling), the talk loop, the one-off move, the
## nod/shake. Each fades in and out; each can cover the whole body or part of it (MotionClips.mask).

signal action_event(id: String, what: String)     # e.g. ("throw", "release")
signal action_finished(id: String)

var rig: MotionRig
var src: MotionClips.SrcSkel
var stance := ""
var posture := "stand"
var who := ""                      # speaker id ("kirk", "spock", "mccoy", ...) for per-character choices
## REV 160 (items 7-8): a woman's figure (Daz Genesis 8 Female): clips marked "female" in MotionClips
## replace the men's (walk -> walk_female, sit_idle -> sit_female_crossed). Set by CharacterAnimator.
var female := false

# set by CharacterAnimator every frame
var speed := 0.0                   # character metres per second
var turn_rate := 0.0               # radians per second, + = turning left
var backwards := false

var _n := 0
var _q: Array[Quaternion] = []     # the pose being built (local, Mixamo skeleton)
var _tmp: Array[Quaternion] = []
var _tmp2: Array[Quaternion] = []
var _tmp3: Array[Quaternion] = []
var _stance_prev := ""
var _stance_x := 1.0
var _g: Array[Quaternion] = []
var _pos := PackedVector3Array()
var _hips := Vector3.ZERO

var _idle_t := 0.0
var _phase := 0.0                  # walking cycle, 0..1
var _w_move := 0.0
var _w_run := 0.0
var _w_back := 0.0
var _w_turn := 0.0                 # + left, - right
var _w_shuffle := 0.0
var _idle0: Array[Quaternion] = [] # the idle's first frame (the breathing is added relative to it)
var _idle0_p := Vector3.ZERO

var _base_clip := "idle"           # what the standing/sitting/kneeling layer holds
var _base_prev := ""               # crossfading from
var _base_x := 1.0                 # crossfade 0..1
var _base_fade := 0.45             # REV 576: seconds the current base crossfade takes
var _base_prev_t := 0.0

var talk_layer: Layer = null
var action: Layer = null
var gesture_layer: Layer = null
var root_offset := Vector3.ZERO    # where root-motion moves have taken the character (its own space, metres)
var _root_last := Vector3.ZERO
var _point_yaw := 0.0              # degrees the chest turns to point at something


class Layer:
	var id := ""
	var clip: MotionClips.Clip
	var t := 0.0                   # clip time
	var out_t := 0.0               # seconds since it started
	var rate := 1.0
	var strength := 1.0
	var mask := PackedFloat32Array()
	var mirror := false
	var fade := 0.0
	var fade_to := 1.0
	var fade_in := 0.25
	var fade_out := 0.35
	var hold := 0.0                # seconds left to keep repeating the hold part; < 0 = until released
	var reverse := false
	var time_map: Array = []       # [[output 0..1, clip 0..1], ...] for reversed moves
	var duration := 0.0            # output seconds (time-mapped moves)
	var events: Array = []         # [[clip time, name], ...]
	var fired := {}
	var additive := false
	var root_motion := false
	var then_posture := ""
	var then_base := ""
	var done := false

	func weight() -> float:
		return fade * strength


func setup(r: MotionRig, speaker := "") -> void:
	rig = r
	src = MotionClips.ref()
	who = speaker
	_n = src.names.size()
	for arr in [_q, _tmp, _tmp2, _tmp3, _g]:
		(arr as Array).resize(_n)
	_pos.resize(_n)
	_idle0.resize(_n)
	var idle := MotionClips.get_clip("idle")
	if idle != null:
		_idle0_p = MotionClips.sample(idle, idle.start, _idle0)
	else:
		for i in _n:
			_idle0[i] = src.rest_q[i]
	match speaker:
		"kirk":
			stance = "kirk"
		"spock":
			stance = "spock"
	_idle_t = randf() * 6.0       # so a room full of people don't breathe in step
	_pick_daz_idle()
	# load the everyday clips now (the rest load the first time they're used)
	# (REV 449: clip_for("walk") - the walk they really use; plain "walk" has been unused since REV 244)
	for id in [clip_for("walk"), "run", "walk_back", "walk_turn_left", "stance_kirk", "stance_spock"]:
		MotionClips.get_clip(id)


## REV 244: the standing idle for people without a stance of their own: Daz "Idle Weight Left/Right"
## (Idle 1 & 2 packs), and for background people sometimes "Checks Shoes" (they look down at a shoe now
## and then). false = Mixamo's idle again.
const USE_DAZ_IDLE := true
const DAZ_IDLES := ["daz_idle_right", "daz_idle_left"]
const DAZ_IDLES_BACKGROUND := ["daz_idle_right", "daz_idle_left", "daz_idle_right", "daz_check_shoe_l", "daz_check_shoe_r"]
var _daz_idle := ""

func _pick_daz_idle() -> void:
	# REV 293: background crew (speaker id "crew" / "crew_<n>", or none at all) get the pool with the
	# shoe checks; named people (McCoy, Pell, Kyle ...) the plain weight shifts only
	var background := who == "" or who == "crew" or who.begins_with("crew_")
	var pool: Array = DAZ_IDLES_BACKGROUND if background else DAZ_IDLES
	_daz_idle = String(pool[randi() % pool.size()])     # (the woman's version is picked when it's used)


## REV 293: who this is, once the figure's speaker id is known. CharacterKit.make_named() and
## CrewLooks set the speaker id only AFTER the animator was set up, so setup() saw "" and picked
## from the background pool (McCoy checking his shoes). The animator calls this on its first frame;
## the stance and the standing idle are chosen again for the real person.
func set_who(speaker: String) -> void:
	if speaker == who:
		return
	who = speaker
	if who == "kirk" or who == "spock":
		stance = who
	_pick_daz_idle()


## REV 160: the clip this character uses for `id` - a woman's version where there is one.
const FEMALE_CLIPS := {"walk": "walk_female", "sit_idle": "sit_female_crossed"}

## REV 244 (Glen): the men walk with the Daz "Relaxed" walk (Walks Collection, Michael 8), at its own
## pace (PlayerController.walk_factor 0.30). false = Mixamo's walk again (set walk_factor back to 0.45).
## REV 449 (Glen): the women walk with the same walk's female mocap (Walks Collection, Victoria 8):
## daz_walk_relaxed_f, picked below before FEMALE_CLIPS' Mixamo walk_female (kept as the fallback).
const USE_DAZ_WALK := true
const DAZ_WALK := "daz_walk_relaxed"

func clip_for(id: String) -> String:
	if id == "walk" and female and USE_DAZ_WALK and MotionClips.has_clip(DAZ_WALK + "_f"):
		return DAZ_WALK + "_f"
	if female and FEMALE_CLIPS.has(id) and MotionClips.has_clip(String(FEMALE_CLIPS[id])):
		return String(FEMALE_CLIPS[id])
	if id == "walk" and not female and USE_DAZ_WALK and MotionClips.has_clip(DAZ_WALK):
		return DAZ_WALK
	# REV 241: the Daz clips come as a man's and a woman's version (<id>_f)
	if female and id.begins_with("daz_") and not id.ends_with("_f") and MotionClips.has_clip(id + "_f"):
		return id + "_f"
	return id


## Change how the character stands, blending over half a second.
func set_stance(id: String) -> void:
	if id == stance:
		return
	_stance_prev = stance
	stance = id
	_stance_x = 0.0


## Character metres per body height of the Mixamo skeleton (how the clips' speeds become real speeds).
func _body_scale() -> float:
	return src.height * rig.src_to_model()


# ---- what the game asks for --------------------------------------------------------------

## A one-off move. opts: strength, mirror, hold (seconds; -1 = until stop_action), rate, mask,
## fade_in, fade_out. Returns how long it will take (seconds), or 0 if it can't be played.
func play(id: String, opts: Dictionary = {}) -> float:
	id = clip_for(id)
	var c := MotionClips.get_clip(id)
	if c == null:
		return 0.0
	var l := _layer(id, c, opts)
	if c.settings.has("hold") and not opts.has("hold"):
		l.hold = 0.0
	if id == "throw":
		l.events = [[MotionClips.BOWL_RELEASE, "release"]]
	elif id == "pick_up":
		l.events = [[MotionClips.PICK_UP_GRAB, "grab"]]
	action = l
	return _duration(l)


## REV 199 (CLAUDE.md item 9: characters touch what they use): Glen's Mixamo "button" press, with the
## hand steered onto the real thing being used. `offset` is where to touch, from the shoulder of that
## arm, in the character's own frame and metres: x forward, y to his left, z up. The clip's own reach
## (to about waist height, 0.95-1.9 s) sets the timing; two-bone arm IK puts the fingertips on the spot.
## Event "contact" when the fingers arrive. Returns the move's length.
const REACH_IN := Vector2(0.6, 0.98)       # clip seconds: the arm goes out
const REACH_OUT := Vector2(1.9, 2.45)      # and comes back
const REACH_CONTACT := 1.0
const REACH_FINGERS := 0.10        # wrist to fingertip in the press pose (model metres, measured on McCoy)
const REACH_MAX_LEAN := 22.0       # degrees the upper body may lean in to reach
const REACH_LEAN_GAIN := 2.5
var reach_offset := Vector3.INF
var reach_side := "Right"

## The animation skeleton's upper arm + forearm for `side`, in the model's metres.
func arm_length_m(side := "Right") -> float:
	var r := src
	var el := r.bone(side + "ForeArm")
	var wr := r.bone(side + "Hand")
	if el < 0 or wr < 0:
		return 0.0
	return (r.rest_p[el].length() + r.rest_p[wr].length()) * rig.src_to_model()


func reach(offset: Vector3, side := "Right") -> float:
	var c := MotionClips.get_clip("button")
	if c == null:
		return 0.0
	reach_offset = offset
	reach_side = side
	var l := _layer("button", c, {"mirror": side == "Left", "fade_in": 0.25, "fade_out": 0.35})
	l.events = [[REACH_CONTACT, "contact"]]
	action = l
	return _duration(l)


## REV 168 (item 11): the phaser. Draw = Pistol Holster backwards (the hand goes to the holster, takes
## the phaser at HOLSTER_AT - event "grab" - and comes up to aim), then the aim is held (phaser_aim on
## the upper body) until holster(). Holster = forwards from the aim (event "stow" when it goes in).
## Upper body only, so walking still works. Return how long the move takes.
func phaser_draw() -> float:
	var c := MotionClips.get_clip("phaser_holster")
	if c == null:
		return 0.0
	var l := _layer("phaser_draw", c, {"fade_in": 0.25, "fade_out": 0.3})
	l.reverse = true
	l.duration = 1.9
	l.time_map = [[0.0, 0.0], [0.45, 0.42], [1.0, 1.0]]
	l.events = [[MotionClips.HOLSTER_AT, "grab"]]
	action = l
	return l.duration


func phaser_aim(on: bool) -> void:
	if on:
		hold_loop("phaser_aim", 1.0)
	elif talk_layer != null and talk_layer.id == "phaser_aim":
		talk_layer.fade_to = 0.0


func phaser_holster() -> float:
	var c := MotionClips.get_clip("phaser_holster")
	if c == null:
		return 0.0
	phaser_aim(false)
	var l := _layer("phaser_holster", c, {"fade_in": 0.25, "fade_out": 0.45, "rate": 1.35})
	l.events = [[MotionClips.HOLSTER_AT, "stow"]]
	action = l
	return _duration(l)


## Stop the one-off move (or let a held one finish its last part).
func stop_action(fade := 0.4) -> void:
	if action == null:
		return
	if action.hold != 0.0:
		action.hold = 0.0
	else:
		action.fade_to = 0.0
		action.fade_out = fade


func is_busy() -> bool:
	return action != null and not action.done


## Gestures while speaking. style: "" picks for the character; "calm", "lively", "argue", "argue_big", "sad";
## "listen" = the listener's attentive loop (REV 242).
func talk(style := "", strength := -1.0) -> void:
	var id := "talk_calm"
	var s := 0.55
	var m := "upper"
	if style == "listen" and posture != "stand":
		return          # (the listening loop is a standing one)
	if posture == "sit":
		id = "talk_seated"
	elif style == "listen":
		id = "listen"
		s = 0.75
		if who == "spock":
			s = 0.45
			m = "arm_r_head"
	elif style == "sad":
		id = "sad"
		s = 0.85
	elif style == "argue" or style == "argue_big":
		id = style
		s = 0.85 if style == "argue" else 1.0
	elif style == "calm":
		id = "talk_calm"
	elif style == "lively":
		id = "talk_lively"
	else:
		match who:
			"spock":
				id = "talk_calm"
				s = 0.45
				m = "arm_r_head"   # his left hand stays behind his back
			"kirk":
				id = "talk_lively"
				s = 0.5
			_:
				id = "talk_calm" if randf() < 0.5 else "talk_lively"
	# REV 167 (Tiffany, item 5): the same person carrying on into their next line keeps the talking
	# they were already doing - no new random pick between calm and lively, no restart of the loop.
	var still_talking := talk_layer != null and talk_layer.fade > 0.0
	if still_talking and style == "" and posture != "sit" and String(talk_layer.get_meta("style", talk_layer.id)) in ["talk_calm", "talk_lively"]:
		id = String(talk_layer.get_meta("style", talk_layer.id))
		s = talk_layer.strength
		if talk_layer.fade_to > 0.0 or talk_layer.fade > 0.0:
			talk_layer.fade_to = 1.0
			return
	if who == "spock" and id.begins_with("argue"):
		s *= 0.5
	if strength >= 0.0:
		s = strength
	var styled := id
	# REV 242: the Daz Conversations pack's loops in place of Mixamo's, where they're there
	var clip_id := _talk_clip(id)
	if clip_id == "":
		return
	if clip_id.begins_with("daz_") and not styled == "listen" and strength < 0.0:
		s = clampf(s * DAZ_TALK_STRENGTH, 0.0, 1.0)
	var c := MotionClips.get_clip(clip_id)
	if c == null:
		return
	if talk_layer != null and String(talk_layer.get_meta("style", talk_layer.id)) == styled and (talk_layer.fade_to > 0.0 or talk_layer.fade > 0.0):
		talk_layer.strength = s
		talk_layer.fade_to = 1.0     # REV 167: still fading out from the last line - pick it back up
		return
	var l := _layer(clip_id, c, {"strength": s, "mask": m, "fade_in": 0.45, "fade_out": 0.7})
	l.t = c.start + randf() * c.length()      # start somewhere in the loop, so it doesn't look canned
	l.set_meta("style", styled)
	talk_layer = l


## REV 242: talking styles -> clips. Each style's Daz loops (Conversations Animation Collection), one
## picked at random, else the Mixamo clip. USE_DAZ_TALK = false brings back the Mixamo gestures.
const USE_DAZ_TALK := true
const DAZ_TALK := {
	"talk_calm": ["daz_talk_lowkey"],
	"talk_lively": ["daz_talk_upbeat", "daz_talk_animated", "daz_talk_side_r", "daz_talk_up_c"],
	"argue": ["daz_talk_argue"],
	"argue_big": ["daz_talk_argue_2", "daz_talk_very_animated"],
	"sad": ["daz_talk_sad"],
	"listen": ["daz_listen"],
}
## Mixamo's talking clips were played damped (strength ~0.5) because they're broad; the Daz ones are
## natural at full, so their strength is raised by this much (capped at 1).
const DAZ_TALK_STRENGTH := 1.6
const MIXAMO_TALK := {"sad": "talk_calm", "listen": ""}

func _talk_clip(id: String) -> String:
	if USE_DAZ_TALK and DAZ_TALK.has(id):
		var have := []
		for c in DAZ_TALK[id]:
			if MotionClips.has_clip(String(c)):
				have.append(String(c))
		if not have.is_empty():
			return String(have[randi() % have.size()])
	return String(MIXAMO_TALK.get(id, id))


func stop_talk() -> void:
	if talk_layer != null:
		talk_layer.fade_to = 0.0


## A nod or a head shake on top of everything ("nod", "head_shake").
func gesture(id: String, strength := 1.0) -> void:
	var c := MotionClips.get_clip(id)
	if c == null:
		return
	var l := _layer(id, c, {"strength": strength, "fade_in": 0.12, "fade_out": 0.25})
	l.additive = true
	gesture_layer = l


## Loops while doing something: the tricorder ("tablet"), typing, the communicator.
func hold_loop(id: String, strength := 1.0) -> void:
	var c := MotionClips.get_clip(id)
	if c == null:
		return
	var m := "tablet" if id == "tablet" else String(c.settings.get("mask", "upper"))
	talk_layer = _layer(id, c, {"strength": strength, "mask": m, "fade_in": 0.5, "fade_out": 0.5})
	# REV 786 (Glen: "Sulu and Chekov move their hands in unison when they're working at the consoles"): every held
	# loop (typing, working a console) starts at its own random point and runs a little faster or slower, so two people
	# doing the same job never move together
	if c.loop and c.length() > 0.1:
		talk_layer.t = c.start + randf() * c.length()
		talk_layer.rate = randf_range(0.85, 1.15)


func sit() -> float:
	if posture == "sit":
		return 0.0
	var c := MotionClips.get_clip("sit_to_stand")
	if c == null:
		posture = "sit"
		_set_base(clip_for("sit_idle"))
		return 0.0
	var l := _layer("stand_to_sit", c, {"fade_in": 0.3, "fade_out": 0.35})
	l.reverse = true
	l.duration = 2.6
	l.time_map = [[0.0, 0.0], [0.15, 0.16], [0.65, 0.5], [0.75, 0.56], [1.0, 1.0]]
	l.then_posture = "sit"
	l.then_base = "sit_drink" if drinking and MotionClips.has_clip("sit_drink") else clip_for("sit_idle")
	action = l
	return l.duration


func stand() -> float:
	on_heels = false
	if posture == "stand":
		return 0.0
	var id := "sit_to_stand" if posture == "sit" else "kneel_down"
	# REV 172: a real getting-up clip when there is one (Glen's One Knee To Standing)
	var own_up := posture == "kneel" and MotionClips.has_clip("kneel_to_stand")
	if own_up:
		id = "kneel_to_stand"
	var c := MotionClips.get_clip(id)
	if c == null:
		posture = "stand"
		_set_base("idle")
		return 0.0
	var l := _layer(id if posture == "sit" or own_up else "kneel_up", c, {"fade_in": 0.2, "fade_out": 0.4})
	if posture == "kneel" and not own_up:
		l.reverse = true
		l.duration = 2.4
		l.time_map = [[0.0, 0.0], [0.3, 0.22], [0.7, 0.62], [1.0, 1.0]]
	l.then_posture = "stand"
	l.then_base = "idle"
	# the base switches now (it's under a full-body move), so it's ready when the move fades out
	_set_base("idle")
	posture = "stand"
	action = l
	return _duration(l)


func kneel() -> float:
	if posture == "kneel":
		return 0.0
	var c := MotionClips.get_clip("kneel_down")
	if c == null:
		return 0.0
	var l := _layer("kneel_down", c, {"fade_in": 0.25, "fade_out": 0.3})
	l.then_posture = "kneel"
	l.then_base = "kneel_idle"
	action = l
	return _duration(l)


## REV 576 (Glen: X sits him on the floor - kneeling, sitting back on his heels): down on one knee
## (kneel_down), then the kneel slowly gives way to the heel sit (Zeddicuss "Kneel Sit Crouch" 13 / 10,
## converted to daz_kneel_sit / _f). Posture stays "kneel", so getting up is: rise_from_heels() back onto
## one knee, then stand(). Returns how long until he's settled.
const HEELS_SETTLE := 1.1
var on_heels := false

func kneel_sit() -> float:
	var sit_id := clip_for("daz_kneel_sit")
	if not MotionClips.has_clip(sit_id):
		return kneel()
	if posture == "kneel":
		_set_base(sit_id, HEELS_SETTLE)
		on_heels = true
		return HEELS_SETTLE
	if posture != "stand":
		return 0.0
	var c := MotionClips.get_clip("kneel_down")
	if c == null:
		posture = "kneel"
		_set_base(sit_id)
		on_heels = true
		return 0.0
	var l := _layer("kneel_down", c, {"fade_in": 0.25, "fade_out": HEELS_SETTLE})
	l.then_posture = "kneel"
	l.then_base = sit_id
	action = l
	on_heels = true
	return _duration(l) + HEELS_SETTLE * 0.8


## Back up onto one knee from the heel sit (stand() then gets him up). Returns how long it takes.
func rise_from_heels() -> float:
	if not on_heels:
		return 0.0
	on_heels = false
	_set_base("kneel_idle", 0.8)
	return 0.8


## REV 168 (item 10): seated and drinking - the base becomes the sipping loop (and back to the ordinary
## seated idle when `on` is false). Only while sitting; the caller sits the character first.
var drinking := false

func set_drinking(on: bool) -> void:
	drinking = on
	if posture == "sit":
		_set_base("sit_drink" if on and MotionClips.has_clip("sit_drink") else clip_for("sit_idle"))


## Seated straight away (a character who starts the scene in a seat).
func sit_now() -> void:
	posture = "sit"
	_base_clip = "sit_drink" if drinking and MotionClips.has_clip("sit_drink") else clip_for("sit_idle")
	_base_prev = ""
	_base_x = 1.0


## REV 160 (CLAUDE.md item 12): standing still, people aren't statues. Now and then they shift their
## weight to the other leg (the hips drift a centimetre or two, the feet stay put) or glance aside for
## a moment, each at their own pace: Spock barely and rarely, McCoy most, Kirk easy and relaxed.
## Only while standing idle (not walking, talking, gesturing or doing anything); it fades out the
## moment they do something. A face that's looking at someone still wins for the head.
## who -> [weight-shift size (0-1), glance (degrees), seconds between changes (min, max)]
const IDLE_PROFILES := {
	"spock": [0.3, 5.0, 12.0, 24.0],
	"mccoy": [1.0, 14.0, 5.0, 11.0],
	"kirk": [0.8, 9.0, 7.0, 14.0],
	"": [0.6, 8.0, 8.0, 16.0],
}
const IDLE_SHIFT := 0.012      # of the body's height, at size 1
var _iv_t := 0.0
var _iv_next := 4.0
var _iv_w := 0.0
var _iv_shift := 0.0
var _iv_shift_to := 0.0
var _iv_glance := 0.0
var _iv_glance_to := 0.0
var _iv_glance_until := 0.0

func _idle_variety() -> void:
	var idle := posture == "stand" and speed < 0.05 and action == null and talk_layer == null \
		and gesture_layer == null and _pump_t < 0.0
	_iv_w = move_toward(_iv_w, 1.0 if idle else 0.0, _last_delta * (0.6 if idle else 3.0))
	var prof: Array = IDLE_PROFILES.get(who, IDLE_PROFILES[""])
	if idle:
		_iv_t += _last_delta
		if _iv_t >= _iv_next:
			if randf() < 0.6:
				_iv_shift_to = -signf(_iv_shift_to if _iv_shift_to != 0.0 else randf() - 0.5) * randf_range(0.6, 1.0)
			else:
				_iv_glance_to = float(prof[1]) * randf_range(0.6, 1.0) * (1.0 if randf() < 0.5 else -1.0)
				_iv_glance_until = _iv_t + randf_range(1.0, 2.2)
			_iv_next = _iv_t + randf_range(float(prof[2]), float(prof[3]))
		if _iv_t > _iv_glance_until:
			_iv_glance_to = 0.0
	_iv_shift = lerpf(_iv_shift, _iv_shift_to, 1.0 - exp(-1.4 * _last_delta))
	_iv_glance = lerpf(_iv_glance, _iv_glance_to, 1.0 - exp(-3.0 * _last_delta))
	var w := _smooth(_iv_w)
	if w <= 0.001:
		return
	var h := src.height
	var lf := src.bone("LeftFoot")
	var rf := src.bone("RightFoot")
	src.positions(_g, _hips, _pos)
	var keep_l := _pos[lf]
	var keep_r := _pos[rf]
	var gl := _g[lf]
	var gr := _g[rf]
	var side := _iv_shift * float(prof[0]) * w
	_hips += Vector3(IDLE_SHIFT * h * side, -0.004 * h * absf(side), 0.0)
	MotionClips._turn_subtrees(_g, {
		"Spine": Quaternion(Vector3.FORWARD, deg_to_rad(2.2 * side)),          # the body leans back over the hips
		"Neck": Quaternion(Vector3.UP, deg_to_rad(_iv_glance * w * 0.45)),
		"Head": Quaternion(Vector3.UP, deg_to_rad(_iv_glance * w * 0.55)),
	})
	src.positions(_g, _hips, _pos)
	MotionClips.reach_leg(_g, _pos, "Left", keep_l, gl)
	MotionClips.reach_leg(_g, _pos, "Right", keep_r, gr)


## REV 160: a "Yes!" fist pump with the right arm (there's no clip for it): the arm comes up, elbow
## bent, fist at shoulder height, then yanks down twice and relaxes. Works over any pose (McCoy does it
## on one knee after his strike). Returns how long it takes.
const FIST_PUMP_SECONDS := 1.7
var _pump_t := -1.0
var _last_delta := 0.0

func fist_pump() -> float:
	# REV 171: Glen's Mixamo "Fist Pump" (recorded seated), right arm only, over whatever he is doing.
	# The arm is placed relative to the chest, so the seated recording reads the same standing.
	# The hand-made pump below is kept for a project without the clip.
	if MotionClips.has_clip("fist_pump"):
		return play("fist_pump", {"mask": "arm_r", "fade_in": 0.2, "fade_out": 0.35})
	_pump_t = 0.0
	return FIST_PUMP_SECONDS


func _fist_pump_pose() -> void:
	if _pump_t < 0.0:
		return
	_pump_t += _last_delta
	var t := _pump_t
	if t >= FIST_PUMP_SECONDS:
		_pump_t = -1.0
		return
	# [time, upper arm forward-raise (degrees), elbow bend (degrees)]
	# (REV 160 render check: 62/105 put the fist at his face - lower and more open reads as a pump)
	var keys := [[0.0, 0.0, 0.0], [0.32, 50.0, 82.0], [0.45, 50.0, 82.0], [0.6, 6.0, 96.0],
		[0.78, 34.0, 88.0], [0.93, 2.0, 98.0], [1.25, 2.0, 98.0], [FIST_PUMP_SECONDS, 0.0, 0.0]]
	var raise := 0.0
	var bend := 0.0
	for i in keys.size() - 1:
		var a: Array = keys[i]
		var b: Array = keys[i + 1]
		if t >= float(a[0]) and t <= float(b[0]):
			var w := _smooth((t - float(a[0])) / maxf(float(b[0]) - float(a[0]), 0.001))
			raise = lerpf(float(a[1]), float(b[1]), w)
			bend = lerpf(float(a[2]), float(b[2]), w)
			break
	# the Mixamo skeleton faces +Z; turning about +X by a negative angle swings a hanging arm forward
	MotionClips._turn_subtrees(_g, {
		"RightArm": Quaternion(Vector3.RIGHT, deg_to_rad(-raise)),
		"RightForeArm": Quaternion(Vector3.RIGHT, deg_to_rad(-bend)),
		"Spine2": Quaternion(Vector3.UP, deg_to_rad(-6.0 * raise / 62.0)),
	})


## Point (degrees: where the target is, + to the character's left); a target well over to the left is
## pointed at with the left hand.
func point(at_yaw_deg: float, hold := 1.2) -> float:
	var mirror := at_yaw_deg > 25.0
	_point_yaw = clampf(at_yaw_deg, -60.0, 60.0)
	return play("point", {"mirror": mirror, "hold": hold})


func _layer(id: String, c: MotionClips.Clip, opts: Dictionary) -> Layer:
	var l := Layer.new()
	l.id = id
	l.clip = c
	l.t = c.start
	l.rate = float(opts.get("rate", 1.0))
	l.strength = float(opts.get("strength", 1.0))
	l.mask = MotionClips.mask(String(opts.get("mask", c.settings.get("mask", "full"))))
	l.mirror = bool(opts.get("mirror", false))
	l.fade_in = float(opts.get("fade_in", 0.25))
	l.fade_out = float(opts.get("fade_out", 0.35))
	l.hold = float(opts.get("hold", 0.0))
	l.root_motion = bool(c.settings.get("root_motion", false))
	if l.root_motion:
		_root_last = Vector3.ZERO
	return l


func _duration(l: Layer) -> float:
	if l.duration > 0.0:
		return l.duration
	var d := l.clip.length() / maxf(l.rate, 0.01)
	if l.hold > 0.0:
		d += l.hold
	return d


func _set_base(id: String, fade := 0.45) -> void:
	if id == _base_clip:
		return
	_base_fade = maxf(fade, 0.05)
	_base_prev = _base_clip
	_base_prev_t = _idle_t
	_base_clip = id
	_base_x = 0.0


## True when something is turning the head itself (the eyes-and-head look should back off).
func owns_head() -> float:
	var w := 0.0
	if action != null and bool(action.clip.settings.get("own_head", false)):
		w = maxf(w, action.fade)
	if gesture_layer != null and not gesture_layer.done:
		w = maxf(w, gesture_layer.fade * 0.6)
	return w


# ---- every frame -------------------------------------------------------------------------

## Build this frame's pose and put it on the character. Returns how far root motion moved the
## character this frame (its own space, metres).
func update(delta: float) -> Vector3:
	if not is_finite(delta) or delta < 0.0:
		return Vector3.ZERO
	if not is_finite(speed):
		speed = 0.0
	if not is_finite(turn_rate):
		turn_rate = 0.0
	_idle_t += delta
	_last_delta = delta
	_base_pose(delta)
	if not _pose_ok("standing (" + _base_clip + ")"):
		return Vector3.ZERO
	_locomotion(delta)
	if not _pose_ok("walking"):
		return Vector3.ZERO
	var moved := Vector3.ZERO
	if talk_layer != null:
		_run_layer(talk_layer, delta)
		if talk_layer.done:
			talk_layer = null
		elif not _pose_ok("talk layer " + talk_layer.id):
			talk_layer = null
			return Vector3.ZERO
	if action != null:
		moved = _run_layer(action, delta)
		if action.done:
			var fin := action.id
			action = null
			action_finished.emit(fin)
		elif not _pose_ok("move " + action.id):
			var fin2 := action.id
			action = null
			action_finished.emit(fin2)
			return Vector3.ZERO
	if gesture_layer != null:
		_run_layer(gesture_layer, delta)
		if gesture_layer.done:
			gesture_layer = null
		elif not _pose_ok("gesture " + gesture_layer.id):
			gesture_layer = null
			return Vector3.ZERO
	src.globals(_q, _g)
	_procedural()
	for i in _n:
		if not _g[i].is_finite():
			_report("finishing touches (" + (action.id if action != null else "") + ")")
			return Vector3.ZERO
	rig.apply(_g, _hips)
	return moved if moved.is_finite() else Vector3.ZERO


## REV 130: a pose that has gone wrong (not-a-number) is never put on the character - one bad frame would
## make the whole figure (and any camera framing it) vanish into Godot's "cannot be normalized" errors.
## The first time it happens it says where, so it can be fixed.
var _reported := false

func _pose_ok(stage: String) -> bool:
	if not _hips.is_finite():
		_report(stage)
		return false
	for i in _n:
		if not _q[i].is_finite():
			_report(stage + " bone " + src.names[i])
			return false
	return true


func _report(stage: String) -> void:
	if _reported:
		return
	_reported = true
	push_warning("CharacterMotion: a bad pose for '%s' at %s (speed %.2f, turn %.2f) - skipped" % [who, stage, speed, turn_rate])


## Standing still (with the character's own stance), sitting or kneeling.
func _base_pose(delta: float) -> void:
	if _stance_x < 1.0:
		_stance_x = minf(1.0, _stance_x + delta / 0.5)
	_pose_of_base(_base_clip, _idle_t, _q)
	var hp := _hips
	if _base_x < 1.0:
		_base_x = minf(1.0, _base_x + delta / _base_fade)
		if _base_prev != "":
			var hp2 := _pose_into(_base_prev, _base_prev_t + _idle_t, _tmp)
			var w := _smooth(_base_x)
			for i in _n:
				_q[i] = _tmp[i].slerp(_q[i], w)
			_hips = hp2.lerp(hp, w)


## A base pose into out (returns the hips) - and leaves it in _hips when out is _q.
func _pose_of_base(id: String, t: float, out: Array[Quaternion]) -> void:
	_hips = _pose_into(id, t, out)


func _pose_into(id: String, t: float, out: Array[Quaternion]) -> Vector3:
	if id == "idle" and _stance_x < 1.0:
		# between two stances
		var now_p := _stance_pose(stance, t, out)
		var was_p := _stance_pose(_stance_prev, t, _tmp3)
		var w := _smooth(_stance_x)
		for i in _n:
			out[i] = _tmp3[i].slerp(out[i], w)
		return was_p.lerp(now_p, w)
	if id == "idle":
		return _stance_pose(stance, t, out)
	var c := MotionClips.get_clip(id)
	if c == null:
		return _stance_pose(stance, t, out)
	return MotionClips.sample(c, c.start + t, out)


func _stance_pose(st_id: String, t: float, out: Array[Quaternion]) -> Vector3:
	var idle := MotionClips.get_clip("idle")
	var st := MotionClips.get_clip("stance_" + st_id) if st_id != "" else null
	# REV 244: no stance of their own (McCoy, the crew) -> a Daz standing idle (weight on one leg,
	# breathing, settling; background people now and then look down at a shoe)
	if st == null and USE_DAZ_IDLE and _daz_idle != "":
		var di := MotionClips.get_clip(clip_for(_daz_idle))
		if di != null:
			return MotionClips.sample(di, t, out)
	if idle == null:
		for i in _n:
			out[i] = src.rest_q[i]
		return src.rest_p[src.hips]
	var p := MotionClips.sample(idle, t, out)
	if st == null:
		return p
	# the stance, with the idle's breathing and small sways on top (Spock's calmer)
	MotionClips.sample(st, 0.0, _tmp2)
	var calm := 0.7 if st_id == "spock" else 1.0
	for i in _n:
		var add: Quaternion = _idle0[i].inverse() * out[i]
		if calm < 1.0:
			add = Quaternion.IDENTITY.slerp(add, calm)
		out[i] = (_tmp2[i] * add).normalized()
	return st.still_p + (p - _idle0_p) * calm


## Walking, running, backing up, turning - blended in over the base by how the character moves.
func _locomotion(delta: float) -> void:
	if posture != "stand":
		_w_move = 0.0
		return
	var walk := MotionClips.get_clip(clip_for("walk"))
	var run := MotionClips.get_clip("run")
	if walk == null:
		return
	var body := _body_scale()
	var v_walk := float(walk.settings["speed"]) * body
	var v_run := float(run.settings["speed"]) * body if run != null else v_walk * 2.6
	var k := 1.0 - exp(-9.0 * delta)
	var turning := absf(turn_rate) > 0.7 and speed < 0.25 * v_walk
	_w_move = lerpf(_w_move, _smooth(clampf((speed - 0.04 * v_walk) / (0.3 * v_walk), 0.0, 1.0)), k)
	_w_shuffle = lerpf(_w_shuffle, 0.45 if turning else 0.0, 1.0 - exp(-6.0 * delta))
	_w_run = lerpf(_w_run, _smooth(clampf((speed - 1.45 * v_walk) / maxf(0.8 * v_run - 1.45 * v_walk, 0.1), 0.0, 1.0)), k)
	_w_back = lerpf(_w_back, 1.0 if backwards else 0.0, k)
	var want_turn := clampf(turn_rate / 1.6, -1.0, 1.0) if not turning else 0.0
	_w_turn = lerpf(_w_turn, want_turn, 1.0 - exp(-5.0 * delta))
	var w_total := maxf(_w_move, _w_shuffle)
	if w_total < 0.01:
		return
	# how fast the cycle goes: matched to the real speed so the planted foot doesn't slide
	var cycles := 0.0
	if _w_move >= _w_shuffle:
		var walk_cps := clampf(speed / v_walk, 0.55, 1.6) / walk.period()
		var run_cps := clampf(speed / v_run, 0.6, 1.4) / run.period() if run != null else walk_cps
		cycles = lerpf(walk_cps, run_cps, _w_run)
	else:
		cycles = 0.75 / walk.period()
	_phase = fposmod(_phase + cycles * delta, 1.0)
	# the moving pose
	var hp := _cycle(walk, _tmp)
	if run != null and _w_run > 0.01:
		var hr := _cycle(run, _tmp2)
		for i in _n:
			_tmp[i] = _tmp[i].slerp(_tmp2[i], _w_run)
		hp = hp.lerp(hr, _w_run)
	var back := MotionClips.get_clip("walk_back")
	if back != null and _w_back > 0.01:
		var hb := _cycle(back, _tmp2)
		for i in _n:
			_tmp[i] = _tmp[i].slerp(_tmp2[i], _w_back)
		hp = hp.lerp(hb, _w_back)
	var turn := MotionClips.get_clip("walk_turn_left")
	if turn != null and absf(_w_turn) > 0.02:
		var ht := _cycle(turn, _tmp2)
		if _w_turn < 0.0:
			ht = MotionClips.mirror(_tmp2, ht)
		var wt := absf(_w_turn) * (1.0 - _w_run) * (1.0 - _w_back)
		for i in _n:
			_tmp[i] = _tmp[i].slerp(_tmp2[i], wt)
		hp = hp.lerp(ht, wt)
	# the stance's arms and head stay a little while walking slowly (Spock keeps his hands behind him)
	var w := w_total
	for i in _n:
		_q[i] = _q[i].slerp(_tmp[i], w)
	_hips = _hips.lerp(hp, w)


func _cycle(c: MotionClips.Clip, out: Array[Quaternion]) -> Vector3:
	var u := fposmod(_phase + c.phase0, 1.0)
	return MotionClips.sample(c, c.start + u * c.period(), out)


## Advance one layer and mix it into the pose. Returns root-motion movement this frame.
func _run_layer(l: Layer, delta: float) -> Vector3:
	var c := l.clip
	l.out_t += delta
	# fading
	if l.fade_to > l.fade:
		l.fade = minf(l.fade_to, l.fade + delta / maxf(l.fade_in, 0.01))
	elif l.fade_to < l.fade:
		l.fade = maxf(l.fade_to, l.fade - delta / maxf(l.fade_out, 0.01))
	# time
	if l.duration > 0.0 and not l.time_map.is_empty():
		var u := _map(l.time_map, clampf(l.out_t / l.duration, 0.0, 1.0))
		l.t = (c.end - u * c.length()) if l.reverse else (c.start + u * c.length())
		if l.out_t >= l.duration - l.fade_out and l.fade_to > 0.0:
			_finish_into(l)
	else:
		var step := delta * l.rate
		var hold: Array = c.settings.get("hold", [])
		if not hold.is_empty() and l.hold != 0.0 and l.t >= float(hold[0]):
			# in the part that can be held: count the time down, and go round it while there's time left
			if l.hold > 0.0:
				l.hold = maxf(0.0, l.hold - delta)
			if l.t + step > float(hold[1]) and l.hold != 0.0:
				l.t = float(hold[0]) + fposmod(l.t + step - float(hold[0]), float(hold[1]) - float(hold[0]))
			else:
				l.t += step
		else:
			l.t += step
		if not c.loop and l.t >= c.end - l.fade_out * l.rate and l.fade_to > 0.0:
			_finish_into(l)
	for e in l.events:
		var name_s: String = e[1]
		# REV 168: a move played backwards (drawing the phaser) passes its moments in reverse
		var reached := l.t <= float(e[0]) if l.reverse else l.t >= float(e[0])
		if not l.fired.has(name_s) and reached:
			l.fired[name_s] = true
			action_event.emit(l.id, name_s)
	if l.fade <= 0.0 and l.fade_to <= 0.0:
		l.done = true
		return Vector3.ZERO
	# the layer's pose
	var hp := MotionClips.sample(c, l.t, _tmp)
	if l.mirror:
		hp = MotionClips.mirror(_tmp, hp)
	var moved := Vector3.ZERO
	if l.root_motion:
		var start_p := MotionClips.sample(c, c.end if l.reverse else c.start, _tmp2)
		if l.mirror:
			start_p.x = -start_p.x
		var off := Vector3(hp.x - start_p.x, 0.0, hp.z - start_p.z)
		hp -= off
		var off_m := off * rig.src_to_model()
		moved = off_m - _root_last
		_root_last = off_m
		root_offset += moved
	var w := l.weight()
	if l.additive:
		var first := MotionClips.sample(c, c.start, _tmp2)
		for i in _n:
			var m := l.mask[i] * w
			if m <= 0.0:
				continue
			var add: Quaternion = _tmp2[i].inverse() * _tmp[i]
			_q[i] = (_q[i] * Quaternion.IDENTITY.slerp(add, m)).normalized()
		return moved
	for i in _n:
		var m := l.mask[i] * w
		if m <= 0.0:
			continue
		_q[i] = _q[i].slerp(_tmp[i], m)
	var mh := l.mask[src.hips] * w
	if mh > 0.0:
		_hips = _hips.lerp(hp, mh)
	return moved


## A move that ends in a new posture: switch the base under it as it fades.
func _finish_into(l: Layer) -> void:
	l.fade_to = 0.0
	if l.then_posture != "":
		posture = l.then_posture
	if l.then_base != "":
		_set_base(l.then_base)
		_base_x = 1.0        # already covered by the move; no second crossfade
		_base_prev = ""


static func _map(keys: Array, x: float) -> float:
	for k in range(1, keys.size()):
		var a: Array = keys[k - 1]
		var b: Array = keys[k]
		if x <= float(b[0]):
			var f := (x - float(a[0])) / maxf(float(b[0]) - float(a[0]), 0.0001)
			return lerpf(float(a[1]), float(b[1]), f)
	return 1.0


static func _smooth(x: float) -> float:
	return x * x * (3.0 - 2.0 * x)


## Changes worked out on the whole body: Spock's bowl (low over the lane, feet kept on the floor),
## pointing toward something off to one side.
func _procedural() -> void:
	_seat_drop()
	_seated_hands()
	_fist_pump_pose()
	_idle_variety()
	_hold_device()
	_reach_pass()
	if action == null:
		return
	if action.id == "throw":
		_bowl_crouch(action)
		_keep_feet_on_floor(action)
	elif action.id == "point" and absf(_point_yaw) > 0.5:
		var w := action.weight() * _smooth(clampf((action.t - 0.2) / 0.5, 0.0, 1.0))
		var yaw := deg_to_rad(_point_yaw) * w
		MotionClips._turn_subtrees(_g, {"Spine1": Quaternion(Vector3.UP, yaw * 0.35), "Spine2": Quaternion(Vector3.UP, yaw * 0.25)})


## REV 258 (Glen, teaser: the bigger crew looked to hover above their chairs): sitting lower than the
## seated clip by this share of its seat height, with the feet kept where they were - the knees come up,
## as a big person's do in a chair a bit low for them. 0 = as the clip has it. Only while seated.
var seat_drop_frac := 0.0
## REV 263 (Glen: Scotty's hands go into his knees): with seat_drop_frac the knees come up; a seated
## person whose hands rest on their legs (not working a console) moves them up with the knees.
var seat_drop_hands := false
## REV 263 (Glen: Sulu's and Chekov's hands go through their consoles): a person drawn bigger than the set
## was made for reaches further and lower. For someone working a console, each hand is put where it would
## be on a person this many times their size - i.e. where the clip's hands met the console before the
## body grew (positions scaled about the character's own feet). 1 = leave the hands alone.
var seat_hands_scale := 1.0
## REV 264 (Glen: hands still going into the consoles): the top of the console in front of a seated worker,
## as a height in the character's own metres over its feet; the hands are kept on top of it
## (HAND_ON_DESK above it). INF = no console.
var hand_floor := INF
const HAND_ON_DESK := 0.035
## REV 264 (Glen: Scotty's hands still in his knees - the seated clip itself rests them inside the legs):
## hands that rest on the legs are put ON the thigh: this far along it from hip to knee, and this far above
## the line of the thigh bone (character's metres - half a thigh plus the hand).
const HAND_ON_THIGH_ALONG := 0.55     # REV 265 (Glen: still in his knees): 0.72 -> 0.55
const HAND_ON_THIGH_UP := 0.16        # REV 265: 0.11 -> 0.16

## REV 796 (Glen, new bridge: "you still haven't worked out the issue with the chairs" - the crew perched high above
## the chair, its back only reaching their waist): an EXACT seat instead of a guessed share. The hip joints' height
## over the feet that this person's chair needs (character's own metres - the chair's cushion top plus HIP_OVER_SEAT,
## divided by the figure's size); the hips are moved down (or up, a little) to it. INF = off (seat_drop_frac as before).
var seat_hip_height := INF
const HIP_OVER_SEAT := 0.09          # metres: the hip joints sit this far above the cushion they rest on


## Seated with a drop of some kind (a set share, or an exact seat).
func _seat_dropping() -> bool:
	return posture == "sit" and (seat_drop_frac > 0.0 or is_finite(seat_hip_height))


func _seat_drop() -> void:
	if not _seat_dropping():
		return
	var lf := src.bone("LeftFoot")
	var rf := src.bone("RightFoot")
	if lf < 0 or rf < 0:
		return
	src.positions(_g, _hips, _pos)
	var keep_l := _pos[lf]
	var keep_r := _pos[rf]
	var gl := _g[lf]
	var gr := _g[rf]
	# the seat: the hips' height over the feet
	var seat := _hips.y - minf(keep_l.y, keep_r.y)
	if seat <= 0.0:
		return
	var lh := src.bone("LeftHand")
	var rh := src.bone("RightHand")
	var hands_before := PackedVector3Array([_pos[lh] if lh >= 0 else Vector3.INF, _pos[rh] if rh >= 0 else Vector3.INF])
	var to_src := 1.0 / maxf(rig.src_to_model(), 0.000001)
	if is_finite(seat_hip_height):
		# the exact seat: hips at seat_hip_height over the feet (at most half the clip's seat down, a fifth up)
		_hips.y -= clampf(seat - seat_hip_height * to_src, -seat * 0.2, seat * 0.5)
	else:
		_hips.y -= seat * clampf(seat_drop_frac, 0.0, 0.5)
	src.positions(_g, _hips, _pos)
	MotionClips.reach_leg(_g, _pos, "Left", keep_l, gl)
	MotionClips.reach_leg(_g, _pos, "Right", keep_r, gr)
	if not seat_drop_hands:
		# working a console: the hands go back to where they met it before the body grew, and never
		# below the console's top
		src.positions(_g, _hips, _pos)
		var floor_y := hand_floor * to_src + HAND_ON_DESK * to_src if is_finite(hand_floor) else -INF
		for side in ["Left", "Right"]:
			var hb := hands_before[0] if side == "Left" else hands_before[1]
			if not hb.is_finite():
				continue
			var want := hb * seat_hands_scale
			want.y = maxf(want.y, floor_y)
			MotionClips.reach_arm(_g, _pos, side, want)
			src.positions(_g, _hips, _pos)
		return
	# hands resting on the legs: _seated_hands (next) puts them on the thighs


## REV 267 (Glen: seated men's hands went through their knees - Scotty in the teaser, the crew on the
## alley benches): the men's seated clip (sit_idle) rests the hands inside the legs. While a man sits in it
## with nothing else using his arms, each hand is put ON its thigh, a little behind the knee
## (HAND_ON_THIGH_ALONG / _UP); anything that moves the arms (typing, talking, applause, an action) takes
## over smoothly as it fades in. Switch off per person with hands_on_thighs = false. Women sit
## cross-legged (sit_female_crossed) with their own hand pose, left as it is.
var hands_on_thighs := true

func _seated_hands() -> void:
	if not hands_on_thighs or posture != "sit" or _base_clip != "sit_idle":
		return
	if _seat_dropping() and not seat_drop_hands:
		return      # (working a console - _seat_drop placed the hands)
	var busy := 0.0
	for l in [talk_layer, gesture_layer, action]:
		if l != null:
			busy = maxf(busy, clampf((l as Layer).fade, 0.0, 1.0))
	var w := 1.0 - busy
	if w <= 0.001:
		return
	var lk := src.bone("LeftLeg")
	var rk := src.bone("RightLeg")
	var lu := src.bone("LeftUpLeg")
	var ru := src.bone("RightUpLeg")
	if lk < 0 or rk < 0 or lu < 0 or ru < 0:
		return
	var to_src := 1.0 / maxf(rig.src_to_model(), 0.000001)
	var keep := _g.duplicate()
	src.positions(_g, _hips, _pos)
	for side in ["Left", "Right"]:
		var hip_p := _pos[lu if side == "Left" else ru]
		var knee_p := _pos[lk if side == "Left" else rk]
		var on := hip_p.lerp(knee_p, HAND_ON_THIGH_ALONG) + Vector3.UP * HAND_ON_THIGH_UP * to_src
		MotionClips.reach_arm(_g, _pos, side, on)
		src.positions(_g, _hips, _pos)
	if w < 0.999:
		for i in _n:
			_g[i] = keep[i].slerp(_g[i], w).normalized()


## REV 199: steer the hand of a "button" reach onto reach_offset (see reach()).
func _reach_pass() -> void:
	if action == null or action.id != "button" or not reach_offset.is_finite():
		return
	var t := action.t
	var k := _smooth(clampf((t - REACH_IN.x) / (REACH_IN.y - REACH_IN.x), 0.0, 1.0)) * (1.0 - _smooth(clampf((t - REACH_OUT.x) / (REACH_OUT.y - REACH_OUT.x), 0.0, 1.0)))
	var w := k * clampf(action.weight(), 0.0, 1.0)
	if w <= 0.001:
		return
	var r := src
	var side := reach_side
	var sh := r.bone(side + "Arm")
	var la := r.bone("LeftArm")
	var ra := r.bone("RightArm")
	var hand := r.bone(side + "Hand")
	if sh < 0 or la < 0 or ra < 0 or hand < 0:
		return
	src.positions(_g, _hips, _pos)
	var fwd: Vector3 = _g[r.bone("Hips")] * _rest_forward()
	fwd.y = 0.0
	fwd = fwd.normalized() if fwd.length() > 0.001 else Vector3.BACK
	var left := (_pos[la] - _pos[ra])
	left -= fwd * left.dot(fwd)
	left.y = 0.0
	left = left.normalized() if left.length() > 0.001 else Vector3.UP.cross(fwd).normalized()
	var to_src := 1.0 / maxf(rig.src_to_model(), 0.000001)
	var touch: Vector3 = _pos[sh] + (fwd * reach_offset.x + left * reach_offset.y + Vector3.UP * reach_offset.z) * to_src
	var keep := _g.duplicate()
	# out of easy reach: lean the upper body toward it (up to REACH_MAX_LEAN), as people do
	var arm := r.rest_p[r.bone(side + "ForeArm")].length() + r.rest_p[hand].length() + REACH_FINGERS * to_src
	var need := _pos[sh].distance_to(touch) - arm * 0.96
	var hips_b := r.bone("Hips")
	if need > 0.0 and hips_b >= 0:
		var torso := maxf(_pos[sh].distance_to(_pos[hips_b]), 0.001)
		# REACH_LEAN_GAIN: the model's spine follows only part of the animation skeleton's bend
		var lean := minf(asin(clampf(need / torso, 0.0, 1.0)) * REACH_LEAN_GAIN, deg_to_rad(REACH_MAX_LEAN))
		# toward the spot: about the axis across it
		var flat := touch - _pos[hips_b]
		flat.y = 0.0
		var axis := Vector3.UP.cross(flat.normalized() if flat.length() > 0.001 else fwd).normalized()
		var half := Quaternion(axis, lean * 0.5)
		MotionClips._turn_subtrees(_g, {"Spine1": half, "Spine2": half})
		src.positions(_g, _hips, _pos)
	var finger_t := (touch - _pos[sh]).normalized()
	var wrist := touch - finger_t * REACH_FINGERS * to_src      # fingertips (not the knuckles) on the spot
	var palm_t := (-Vector3.UP - finger_t * finger_t.dot(-Vector3.UP)).normalized()
	if palm_t.length() < 0.5:
		palm_t = (-left if side == "Left" else left)
	var tip_b := r.bone(side + "HandMiddle4")
	if tip_b < 0:
		tip_b = r.bone(side + "HandMiddle3")
	# twice: reach, turn the hand (fingers toward the spot, palm down - a press, not a slap), then see
	# where the fingertip really is (the clip's fingers are curled) and move the wrist by the miss
	for pass_i in 2:
		MotionClips.reach_arm(_g, _pos, side, wrist)
		var old := _g[hand]
		var want := _hand_rotation(side, finger_t, palm_t)
		_turn_hand_subtree(hand, (want * old.inverse()).normalized())
		if tip_b < 0:
			break
		src.positions(_g, _hips, _pos)
		wrist += touch - _pos[tip_b]
	for i in _n:
		_g[i] = keep[i].slerp(_g[i], w).normalized()


## REV 171 (Glen, 20 Oct: "the tricorder seems to be floating, the hands aren't holding it"): the
## Mixamo "tablet" clip only moves the arms roughly, and the tricorder was simply put at the left hand
## (REV 169 also lifted both arms while kneeling, to clear the knee). Now, while the tablet hold is on,
## the device's place is set in front of his chest - the same standing or kneeling, clear of the
## knees - and both hands are reached onto its sides (two-bone arm IK), palms in, fingers curled
## round it. SlungEquipment puts the tricorder between the hands, so it is gripped, not floating.
## Tuning, as fractions of the upper-arm length: how far in front of the chest, how far below it, and
## half the width between the palms.
const HOLD_FORWARD := 1.25
const HOLD_DOWN := 0.55
const HOLD_HALF_WIDTH := 0.31     # REV 591: palms on the TOS kit tricorder's sides (136 mm wide)
const HOLD_FINGER_CURL := 32.0      # degrees per finger joint
const HOLD_PITCH := 28.0            # fingers point this far down from straight ahead

func _hold_device() -> void:
	if talk_layer == null or talk_layer.id != "tablet":
		return
	var w := _smooth(clampf(talk_layer.weight(), 0.0, 1.0))
	if w <= 0.001:
		return
	var r := src
	var chest := r.bone("Spine2")
	var la := r.bone("LeftArm")
	var ra := r.bone("RightArm")
	if chest < 0 or la < 0 or ra < 0:
		return
	src.positions(_g, _hips, _pos)
	var arm_len := r.rest_p[r.bone("LeftForeArm")].length()
	# the body's own frame now: forward from the hips' facing, left across the shoulders
	var fwd: Vector3 = _g[r.bone("Hips")] * _rest_forward()
	fwd.y = 0.0
	fwd = fwd.normalized() if fwd.length() > 0.001 else Vector3.BACK
	var left := (_pos[la] - _pos[ra])
	left -= fwd * left.dot(fwd)
	left.y = 0.0
	left = left.normalized() if left.length() > 0.001 else Vector3.UP.cross(fwd).normalized()
	var centre: Vector3 = _pos[chest] + fwd * HOLD_FORWARD * arm_len - Vector3.UP * HOLD_DOWN * arm_len
	hold_centre = centre
	var keep := _g.duplicate()
	for side in ["Left", "Right"]:
		var sgn := 1.0 if side == "Left" else -1.0
		var hand := r.bone(side + "Hand")
		var mid := r.bone(side + "HandMiddle1")
		if hand < 0:
			continue
		var hand_len := (r.rest_gp[mid] - r.rest_gp[hand]).length() if mid >= 0 else arm_len * 0.35
		var a := deg_to_rad(HOLD_PITCH)
		var finger_t := (fwd * cos(a) - Vector3.UP * sin(a)).normalized()
		var palm_t := -left * sgn                       # palms toward the device
		var grip := centre + left * sgn * HOLD_HALF_WIDTH * arm_len
		var wrist := grip - finger_t * hand_len * 0.75
		MotionClips.reach_arm(_g, _pos, side, wrist)
		# the hand itself: fingers forward and down, palm in; the fingers follow it
		var old := _g[hand]
		var want := _hand_rotation(side, finger_t, palm_t)
		var turn := (want * old.inverse()).normalized()
		_turn_hand_subtree(hand, turn)
		_curl_fingers(side, finger_t, palm_t)
	for i in _n:
		_g[i] = keep[i].slerp(_g[i], w).normalized()


## Where the device is held this frame (skeleton space of the reference rig); INF when not holding.
var hold_centre := Vector3.INF


func _rest_forward() -> Vector3:
	var r := src
	var foot := r.bone("LeftFoot")
	var toe := r.bone("LeftToeBase")
	if foot >= 0 and toe >= 0:
		var d := r.rest_gp[toe] - r.rest_gp[foot]
		d.y = 0.0
		if d.length() > 0.001:
			return (r.rest_gq[r.bone("Hips")].inverse() * d.normalized()).normalized()
	return Vector3.BACK


## The global rotation for a hand whose fingers point along finger_t with the palm facing palm_t.
func _hand_rotation(side: String, finger_t: Vector3, palm_t: Vector3) -> Quaternion:
	var r := src
	var hand := r.bone(side + "Hand")
	var mid := r.bone(side + "HandMiddle1")
	var idx := r.bone(side + "HandIndex1")
	var pky := r.bone(side + "HandPinky1")
	var finger_r := Vector3.RIGHT if side == "Left" else Vector3.LEFT
	if mid >= 0:
		finger_r = (r.rest_gp[mid] - r.rest_gp[hand]).normalized()
	var across := Vector3.BACK
	if idx >= 0 and pky >= 0:
		across = (r.rest_gp[idx] - r.rest_gp[pky]).normalized()
	var palm_r := finger_r.cross(across).normalized() * (1.0 if side == "Left" else -1.0)
	var br := Basis(finger_r, palm_r, finger_r.cross(palm_r).normalized()).orthonormalized()
	var pt := (palm_t - finger_t * palm_t.dot(finger_t)).normalized()
	var bt := Basis(finger_t, pt, finger_t.cross(pt).normalized()).orthonormalized()
	var turn := (bt * br.inverse()).get_rotation_quaternion()
	return (turn * r.rest_gq[hand]).normalized()


func _turn_hand_subtree(hand: int, turn: Quaternion) -> void:
	var r := src
	for i in r.order:
		var b := i
		var under := false
		while b >= 0:
			if b == hand:
				under = true
				break
			b = r.parent[b]
		if under:
			_g[i] = (turn * _g[i]).normalized()


## Curl the four fingers round the device (each joint a little); the thumb stays along the side.
func _curl_fingers(side: String, finger_t: Vector3, palm_t: Vector3) -> void:
	var axis := finger_t.cross(palm_t).normalized()     # turning the fingers toward the palm
	var q := Quaternion(axis, deg_to_rad(HOLD_FINGER_CURL))
	var turns := {}
	for f in ["Index", "Middle", "Ring", "Pinky"]:
		for j in [1, 2, 3]:
			turns[side + "Hand" + f + str(j)] = q
	MotionClips._turn_subtrees(_g, turns)


## REV 146: the bowling crouch below lowers the hips 20% and then bends the legs to keep the feet
## where they were - but the legs can't bend that far, so the feet went up to 40 cm under the floor
## (Glen saw it on the real Spock). Afterwards, lift the hips just enough that neither ankle is below
## its standing height: he crouches as low as his legs allow, and no lower. Faded with the action.
func _keep_feet_on_floor(l: Layer) -> void:
	var w := l.weight()
	if w <= 0.001:
		return
	var lf := src.bone("LeftFoot")
	var rf := src.bone("RightFoot")
	var rest_y := minf(src.rest_gp[lf].y, src.rest_gp[rf].y)     # ankle height standing
	src.positions(_g, _hips, _pos)
	var deficit := minf(_pos[lf].y, _pos[rf].y) - rest_y          # moving the hips moves the feet the same
	if deficit < 0.0:
		_hips.y -= deficit * w


## Glen and I agreed the Mixamo throw is too upright for bowling: at the release Spock gets about
## 20 cm lower (front knee bent), leans forward, and his hand passes close to the lane.
func _bowl_crouch(l: Layer) -> void:
	var t := l.t
	var c := 0.0
	if t > 1.0 and t < 2.7:
		if t < 1.5:
			c = _smooth((t - 1.0) / 0.5)
		elif t < 1.85:
			c = 1.0
		else:
			c = 1.0 - _smooth((t - 1.85) / 0.85)
	c *= l.weight()
	if c <= 0.001:
		return
	var h := src.height
	# where the feet are now (to keep them there)
	src.positions(_g, _hips, _pos)
	var lf := src.bone("LeftFoot")
	var rf := src.bone("RightFoot")
	var keep_l := _pos[lf]
	var keep_r := _pos[rf]
	var gl := _g[lf]
	var gr := _g[rf]
	# lower and lean
	# REV 146: 0.2 -> 0.06 - with the knees now really bending, the throw's own dip plus 20% had him
	# nearly kneeling
	_hips += Vector3(0.0, -0.06 * h * c, 0.06 * h * c)
	MotionClips._turn_subtrees(_g, {
		"Spine": Quaternion(Vector3.RIGHT, deg_to_rad(12.0 * c)),
		"Spine1": Quaternion(Vector3.RIGHT, deg_to_rad(10.0 * c)),
		"Spine2": Quaternion(Vector3.RIGHT, deg_to_rad(8.0 * c)),
		"Neck": Quaternion(Vector3.RIGHT, deg_to_rad(-22.0 * c)),   # eyes stay on the pins
		"RightArm": Quaternion(Vector3.RIGHT, deg_to_rad(-8.0 * c)),
	})
	# the hips moved, so the legs must reach back to where the feet were
	# (REV 293: a do-nothing line that set the hips bone to itself was removed here)
	src.positions(_g, _hips, _pos)
	MotionClips.reach_leg(_g, _pos, "Left", keep_l, gl)
	MotionClips.reach_leg(_g, _pos, "Right", keep_r, gr)
