extends Node3D
class_name GornFighter
## REV 494: the Gorn captain for Episode 5's Arena memory (episodes/episode5/ARENA_MEMORY_SCRIPT.md).
##
## The model is the Mixamo-rigged Gorn (assets/models/characters/gorn/, README there). Mixamo dropped
## its materials, so they're put back by mesh name from gorn_parts.json. Its clips (gorn_*.fbx, Mixamo
## "Without Skin") were made on its own skeleton, so they play NATIVELY on an AnimationPlayer of our
## own - no retargeting - with the hips held in place (the Gorn is moved by this script, not the clip).
##
## The hunter (all numbers at the top):
##   STALK   walks at the target while it can see it; in reach -> ATTACK (punch or claw swipe)
##   THROW   at range, now and then, heaves a boulder (telegraphed: signal throw_started)
##   SEARCH  lost sight -> walks to where it last saw it, stops, sniffs, hisses, comes on again
##   BLOCKED can't climb (the big slabs) -> stands, roars, waits for the target to come down
##   STUN    the boulder in the gully - has to go round (stunned for a while)
##   DOWN    the cannon - falls (gorn_dying, Glen: "the defeated moment") and stays down
##   HOLD    the room is running a scene: stands still (idle), no attacks
## The room listens to the signals and does the damage, sounds and lines.

signal attack_landed(kind: String, damage: float)     # the target was hit ("punch", "swipe", "boulder")
signal attack_missed(kind: String)
signal throw_started(land_point: Vector3, seconds: float)   # a boulder is coming - DODGE prompt
signal lost_sight()
signal blocked()
signal taunt_wanted()

const MODEL_PATH := "res://assets/models/characters/gorn/gorn_mixamo.fbx"
const PARTS_PATH := "res://assets/models/characters/gorn/gorn_parts.json"
const PARTS_DIR := "res://assets/models/characters/gorn/"
const CLIP_DIR := "res://assets/animations/mixamo/"
## our name -> [clip file, loops]
const CLIPS := {
	"idle": ["gorn_idle", true],
	"idle2": ["gorn_idle_2", true],
	"walk": ["gorn_walk", true],
	"punch": ["gorn_punch", false],
	"swipe": ["gorn_swipe", false],
	"roar": ["gorn_roar", false],
	"throw": ["gorn_throw_overhead", false],
	"dying": ["gorn_dying", false],
}

## Height of the Gorn in metres before the room's character scale (TOS Gorn: towers over Kirk).
const HEIGHT := 2.35                  # REV 507: a foot taller (Glen) - Kirk comes up to his shoulder
const WALK_SPEED := 1.25             # metres a second (Kirk walks 1.13, runs 3.8 - he can outrun it)
const WALK_ANIM_RATE := 1.0          # walk clip speed at WALK_SPEED (tune if its feet slide)
const TURN_SPEED := 3.2              # radians a second
const STOP_DISTANCE := 1.35          # doesn't walk closer than this
const ATTACK_RANGE := 1.9            # starts a swing inside this
const HIT_RANGE := 2.35              # the swing connects if the target is still inside this...
const HIT_CONE_DEG := 70.0           # ...and in front of it
const ATTACKS := {
	# kind: [clip, the moment it lands (share of the clip), damage, recovery seconds after the clip]
	"punch": ["punch", 0.42, 22.0, 0.35],
	"swipe": ["swipe", 0.45, 16.0, 0.25],
}
const THROW_MIN := 9.0               # throws only at least this far away...
const THROW_MAX := 22.0              # ...and no further
const THROW_COOLDOWN := 14.0
const THROW_RELEASE := 0.55          # share of the throw clip when the boulder leaves its hands
const THROW_FLIGHT := 1.15           # seconds in the air
const BOULDER_DAMAGE := 30.0
const BOULDER_HIT_RADIUS := 1.5
const SIGHT_RANGE := 32.0
const LOSE_SIGHT_AFTER := 1.2        # seconds unseen before it starts searching
const SNIFF_SECONDS := 2.6
const MAX_RISE := 0.55               # can't step up more than this over STEP_PROBE metres...
const STEP_PROBE := 0.6
const MIN_FLOOR_NORMAL_Y := 0.62     # ...or onto ground steeper than this
const TERRAIN_MASK := 32             # physics layer 6: the room puts the scan's collision on it

enum State { HOLD, STALK, ATTACK, THROW, SEARCH, BLOCKED, STUN, DOWN }

var state: State = State.HOLD
var target: Node3D = null                 # Kirk's body
var target_dodging: Callable = Callable() # () -> bool: true while the target can't be hit
var can_throw := true
var scale_k := 1.0                         # the room's character scale

var hp := 100.0
var hp_floor := 85.0                       # fists can't take it below this

var _model: Node3D
var _skel: Skeleton3D
var _anim: AnimationPlayer
var _have_anims := false
var _current_anim := ""
var _blocker: AnimatableBody3D
var _state_t := 0.0
var _unseen_t := 0.0
var _last_seen := Vector3.INF
var _throw_cd := 6.0
var _attack_kind := ""
var _attack_done := false
var _attack_len := 1.0
var _stun_left := 0.0
var _taunt_t := 9.0
var _search_phase := 0
var _blocked_t := 0.0
var _boulder_root: Node3D


func _ready() -> void:
	_build_model()
	_build_blocker()
	_play("idle", 0.0)


# ------------------------------------------------------------------------------------- building --

func _build_model() -> void:
	var packed: PackedScene = load(MODEL_PATH) if ResourceLoader.exists(MODEL_PATH) else null
	if packed == null:
		push_warning("GornFighter: no model at " + MODEL_PATH + " - using a stand-in shape")
		_model = _stand_in()
		add_child(_model)
		return
	_model = packed.instantiate() as Node3D
	_model.name = "Model"
	add_child(_model)
	var skels := _model.find_children("*", "Skeleton3D", true, false)
	_skel = skels[0] as Skeleton3D if not skels.is_empty() else null
	# the import's own AnimationPlayer (if any) is not ours - stop it fighting ours
	for p in _model.find_children("*", "AnimationPlayer", true, false):
		(p as AnimationPlayer).stop()
	_apply_materials()
	_fit_height()
	_build_animations()
	_build_head_up()


## Mixamo dropped the Gorn's materials; gorn_parts.json maps each mesh name to one.
func _apply_materials() -> void:
	if not FileAccess.file_exists(PARTS_PATH):
		return
	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(PARTS_PATH))
	if typeof(data) != TYPE_DICTIONARY:
		return
	var parts: Dictionary = data.get("parts", {})
	var mats: Dictionary = data.get("materials", {})
	var made := {}
	for mi in _model.find_children("*", "MeshInstance3D", true, false):
		var mesh_inst := mi as MeshInstance3D
		var key := _part_key(mesh_inst.name, parts)
		if key == "":
			continue
		var mat_name := String(parts[key])
		if not made.has(mat_name):
			made[mat_name] = _make_material(mats.get(mat_name, {}))
		for s in mesh_inst.get_surface_override_material_count():
			mesh_inst.set_surface_override_material(s, made[mat_name])


## Mesh names may come through the importer slightly changed ("gorn_body_001", "part_4 2"...).
static func _part_key(node_name: String, parts: Dictionary) -> String:
	var n := node_name.to_lower()
	if parts.has(n):
		return n
	var best := ""
	for k in parts.keys():
		var ks := String(k)
		if n.begins_with(ks) and ks.length() > best.length():
			var rest := n.substr(ks.length())
			if rest == "" or not rest[0].is_valid_int():     # part_2 must not match part_207
				best = ks
	return best


func _make_material(m: Dictionary) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	var c: Array = m.get("colour", [0.5, 0.5, 0.5])
	mat.albedo_color = Color(float(c[0]), float(c[1]), float(c[2]))
	mat.roughness = 0.78
	mat.metallic = 0.0
	if m.has("albedo") and ResourceLoader.exists(PARTS_DIR + String(m["albedo"])):
		mat.albedo_texture = load(PARTS_DIR + String(m["albedo"]))
	if m.has("normal") and ResourceLoader.exists(PARTS_DIR + String(m["normal"])):
		mat.normal_enabled = true
		mat.normal_texture = load(PARTS_DIR + String(m["normal"]))
	return mat


## Scales the model so it stands HEIGHT tall, with its feet on this node's origin.
func _fit_height() -> void:
	var box := AABB()
	var first := true
	for mi in _model.find_children("*", "MeshInstance3D", true, false):
		var m := mi as MeshInstance3D
		if m.mesh == null:
			continue
		var b := (_model.global_transform.affine_inverse() * m.global_transform) * m.get_aabb()
		box = b if first else box.merge(b)
		first = false
	if first or box.size.y < 0.01:
		return
	var k := HEIGHT / box.size.y
	_model.scale = Vector3.ONE * k
	_model.position.y = -box.position.y * k


func _build_animations() -> void:
	if _skel == null:
		return
	_anim = AnimationPlayer.new()
	_anim.name = "GornAnimations"
	_model.add_child(_anim)
	_anim.root_node = _anim.get_path_to(_model)
	var lib := AnimationLibrary.new()
	var skel_path := String(_model.get_path_to(_skel))
	var hips := -1
	for i in _skel.get_bone_count():
		if _skel.get_bone_name(i).to_lower().ends_with("hips"):
			hips = i
			break
	for key in CLIPS.keys():
		var a := _load_clip(String(CLIPS[key][0]), skel_path, hips)
		if a == null:
			continue
		a.loop_mode = Animation.LOOP_LINEAR if bool(CLIPS[key][1]) else Animation.LOOP_NONE
		lib.add_animation(String(key), a)
	if lib.get_animation_list().is_empty():
		push_warning("GornFighter: none of its clips loaded - it will glide")
		return
	_anim.add_animation_library("", lib)
	_have_anims = true


## One clip, its tracks pointed at our skeleton by bone name, the hips held in place.
func _load_clip(file: String, skel_path: String, hips: int) -> Animation:
	var path := CLIP_DIR + file + ".fbx"
	if not ResourceLoader.exists(path):
		push_warning("GornFighter: missing clip " + path)
		return null
	var packed := load(path) as PackedScene
	if packed == null:
		return null
	var inst := packed.instantiate()
	var players := inst.find_children("*", "AnimationPlayer", true, false)
	var src: Animation = null
	if not players.is_empty():
		var ap := players[0] as AnimationPlayer
		var names := ap.get_animation_list()
		if not names.is_empty():
			src = ap.get_animation(names[0])
	inst.free()
	if src == null:
		return null
	var a := src.duplicate(true) as Animation
	var hips_name := _skel.get_bone_name(hips) if hips >= 0 else ""
	for t in range(a.get_track_count() - 1, -1, -1):
		var np := a.track_get_path(t)
		var bone := String(np.get_concatenated_subnames())
		if bone == "":
			a.remove_track(t)
			continue
		var b := _find_bone(bone)
		if b < 0:
			a.remove_track(t)
			continue
		var bname := _skel.get_bone_name(b)
		a.track_set_path(t, NodePath(skel_path + ":" + bname))
		var ty := a.track_get_type(t)
		if ty == Animation.TYPE_SCALE_3D:
			a.remove_track(t)        # Mixamo scale keys only fight the import's own scale
		elif ty == Animation.TYPE_POSITION_3D:
			if bname != hips_name:
				a.remove_track(t)    # only the hips move; everything else keeps its rest offset
			else:
				_hold_in_place(a, t)
	return a


func _find_bone(name: String) -> int:
	var b := _skel.find_bone(name)
	if b >= 0:
		return b
	var plain := name.replace("mixamorig:", "").replace("mixamorig_", "").to_lower()
	for i in _skel.get_bone_count():
		var n := _skel.get_bone_name(i).replace("mixamorig:", "").replace("mixamorig_", "").to_lower()
		if n == plain:
			return i
	return -1


## Keeps the hips' height and sway but takes out the walk forward (this script moves the Gorn).
static func _hold_in_place(a: Animation, t: int) -> void:
	var n := a.track_get_key_count(t)
	if n == 0:
		return
	var first: Vector3 = a.track_get_key_value(t, 0)
	var last: Vector3 = a.track_get_key_value(t, n - 1)
	var length := maxf(a.track_get_key_time(t, n - 1), 0.001)
	for k in n:
		var v: Vector3 = a.track_get_key_value(t, k)
		var f := a.track_get_key_time(t, k) / length
		var drift := first.lerp(last, f)      # the steady travel through the clip
		a.track_set_key_value(t, k, Vector3(v.x - drift.x + first.x, v.y, v.z - drift.z + first.z))


# ---- REV 522: head up ------------------------------------------------------------------------------
## Glen: the Gorn always looks down at the ground - the Mixamo mutant clips hunch the neck forward. A
## skeleton modifier (runs after the animation every frame) turns the neck so the head points up toward
## standing straight, on the idle/walk clips only (attacks, the roar and the fall keep their own heads).
## Axis-free: it measures the neck->head-top line and bends it toward the model's up.
const HEAD_UP := 0.55            # how far the neck line turns toward straight up (0 = as the clip has it)
var _head_up: GornHeadUp

class GornHeadUp extends SkeletonModifier3D:
	var neck := -1
	var tip := -1
	var amount := 0.55

	func _process_modification() -> void:
		var sk := get_skeleton()
		if sk == null or neck < 0 or tip < 0:
			return
		var g_neck := sk.get_bone_global_pose(neck)
		var v := sk.get_bone_global_pose(tip).origin - g_neck.origin
		if v.length() < 0.0001:
			return
		v = v.normalized()
		var up := (sk.global_transform.basis.inverse() * Vector3.UP).normalized()
		var want := v.slerp(up, amount).normalized()
		if v.is_equal_approx(want):
			return
		g_neck.basis = Basis(Quaternion(v, want)) * g_neck.basis
		sk.set_bone_global_pose(neck, g_neck)


func _build_head_up() -> void:
	if _skel == null:
		return
	var neck := _find_bone("Neck")
	var tip := _find_bone("HeadTop_End")
	if tip < 0:
		tip = _find_bone("Head")
	if neck < 0 or tip < 0:
		return
	_head_up = GornHeadUp.new()
	_head_up.name = "HeadUp"
	_head_up.neck = neck
	_head_up.tip = tip
	_head_up.amount = HEAD_UP
	_head_up.influence = 1.0
	_skel.add_child(_head_up)


func _process(delta: float) -> void:
	if _head_up == null:
		return
	var calm := _current_anim in ["idle", "idle2", "walk"] and state != State.DOWN
	_head_up.influence = move_toward(_head_up.influence, 1.0 if calm else 0.0, delta * 3.0)


func _build_blocker() -> void:
	# Kirk can't walk through it (layer 1, like the walls); it doesn't block its own ground rays
	_blocker = AnimatableBody3D.new()
	_blocker.name = "Blocker"
	_blocker.sync_to_physics = false
	_blocker.collision_layer = 1
	_blocker.collision_mask = 0
	var shape := CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = 0.45
	cap.height = HEIGHT * 0.9
	shape.shape = cap
	shape.position.y = HEIGHT * 0.45
	_blocker.add_child(shape)
	add_child(_blocker)


func _stand_in() -> Node3D:
	var root := Node3D.new()
	root.name = "Model"
	var body := MeshInstance3D.new()
	var cap := CapsuleMesh.new()
	cap.radius = 0.45
	cap.height = HEIGHT
	body.mesh = cap
	body.position.y = HEIGHT * 0.5
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.3, 0.45, 0.25)
	body.material_override = mat
	root.add_child(body)
	return root


# ------------------------------------------------------------------------------------- animation --

## REV 516: the TOS Gorn telegraphed everything - his swings were half the joke (Glen: he hits fast, he should
## be so so slow). Each clip's own tempo; timings that read clip lengths use _anim_length, which allows for it.
const CLIP_RATE := {"punch": 0.5, "swipe": 0.5, "throw": 0.55, "roar": 0.75, "dying": 0.8}

func _play(name: String, blend := 0.25, rate := -1.0) -> void:
	if rate < 0.0:
		rate = float(CLIP_RATE.get(name, 1.0))
	if not _have_anims or not _anim.has_animation(name):
		return
	if _current_anim == name and _anim.is_playing():
		_anim.speed_scale = rate
		return
	_current_anim = name
	_anim.play(name, blend)
	_anim.speed_scale = rate


func _anim_length(name: String) -> float:
	if _have_anims and _anim.has_animation(name):
		return _anim.get_animation(name).length / float(CLIP_RATE.get(name, 1.0))
	return 1.2 / float(CLIP_RATE.get(name, 1.0))


## Plays a one-off and returns its length in seconds (for scripted beats - the roar, the fall).
func play_once(name: String, blend := 0.2) -> float:
	_current_anim = ""
	_play(name, blend)
	return _anim_length(name)


# ------------------------------------------------------------------------------------- control --

## The room's commands.
func hunt() -> void:
	if state == State.DOWN:
		return
	if _stun_left > 0.0:
		_set_state(State.STUN)     # a stun (the gully boulder) outlasts the scenes in the middle of it
		return
	_set_state(State.STALK)


func hold() -> void:
	if state == State.DOWN:
		return
	_set_state(State.HOLD)


func stun(seconds: float) -> void:
	if state == State.DOWN:
		return
	_stun_left = seconds
	_set_state(State.STUN)
	play_once("roar")


## A punch from Kirk: a sliver, never below hp_floor. Returns the new hp.
## Turns to face a point at once (scripted beats).
func face_now(point: Vector3) -> void:
	var d := point - global_position
	if Vector2(d.x, d.z).length() > 0.01:
		rotation.y = atan2(d.x, d.z)


func take_punch(amount := 1.5) -> float:
	hp = maxf(hp_floor, hp - amount)
	return hp


## The cannon.
func knock_down(to_hp := 4.0) -> float:
	hp = to_hp
	_set_state(State.DOWN)
	_blocker.collision_layer = 0
	return play_once("dying", 0.1)


func is_down() -> bool:
	return state == State.DOWN


func is_attacking() -> bool:
	return state == State.ATTACK or state == State.THROW


func _set_state(s: State) -> void:
	state = s
	_state_t = 0.0
	match s:
		State.HOLD, State.BLOCKED:
			_play("idle")
		State.SEARCH:
			_search_phase = 0


func teleport(pos: Vector3, face: Vector3 = Vector3.INF) -> void:
	global_position = pos
	_snap_to_ground()
	if face != Vector3.INF:
		var d := face - global_position
		rotation.y = atan2(d.x, d.z)
	_last_seen = Vector3.INF
	_unseen_t = 0.0


func _physics_process(delta: float) -> void:
	_state_t += delta
	_throw_cd = maxf(0.0, _throw_cd - delta)
	_blocker.global_transform = Transform3D(Basis.IDENTITY, global_position)
	if target == null or not is_instance_valid(target):
		return
	match state:
		State.HOLD, State.DOWN:
			return
		State.STUN:
			_stun_left -= delta
			if _stun_left <= 0.0:
				_stun_left = 0.0
				_set_state(State.STALK)
			elif _state_t > _anim_length("roar"):
				_play("idle2")
			return
		State.ATTACK:
			_do_attack(delta)
			return
		State.THROW:
			_do_throw()
			return
	var sees := _can_see_target()
	if sees:
		_last_seen = target.global_position
		_unseen_t = 0.0
		if state == State.SEARCH or state == State.BLOCKED:
			_set_state(State.STALK)
	else:
		_unseen_t += delta
		if state == State.STALK and _unseen_t > LOSE_SIGHT_AFTER and _last_seen != Vector3.INF:
			_set_state(State.SEARCH)
			lost_sight.emit()
	_taunt_t -= delta
	if _taunt_t <= 0.0:
		_taunt_t = randf_range(11.0, 18.0)
		taunt_wanted.emit()
	match state:
		State.STALK:
			_stalk(delta, sees)
		State.SEARCH:
			_search(delta)
		State.BLOCKED:
			_blocked_t += delta
			_face(target.global_position, delta)
			if _blocked_t > 2.5:
				_blocked_t = 0.0
				_set_state(State.STALK)      # try again (the target may have come down)


func _stalk(delta: float, sees: bool) -> void:
	var to := target.global_position - global_position
	to.y = 0.0
	var dist := to.length() / scale_k
	if sees and dist <= ATTACK_RANGE:
		_start_attack()
		return
	if sees and can_throw and _throw_cd <= 0.0 and dist >= THROW_MIN and dist <= THROW_MAX:
		_start_throw()
		return
	if dist <= STOP_DISTANCE:
		_face(target.global_position, delta)
		_play("idle")
		return
	if not _walk_toward(target.global_position, delta):
		_set_state(State.BLOCKED)
		blocked.emit()


func _search(delta: float) -> void:
	match _search_phase:
		0:     # to where it last saw the target
			var to := _last_seen - global_position
			to.y = 0.0
			if to.length() < 1.0 * scale_k or not _walk_toward(_last_seen, delta):
				_search_phase = 1
				_state_t = 0.0
				play_once("idle2")
		1:     # sniffing the air
			if _state_t > SNIFF_SECONDS:
				_search_phase = 2
				_state_t = 0.0
		2:     # it hears where the target is - comes on, slower to decide
			if not _walk_toward(target.global_position, delta):
				_set_state(State.BLOCKED)


## One step toward a point, steering round what it can't climb. False if every way is blocked.
func _walk_toward(point: Vector3, delta: float) -> bool:
	var to := point - global_position
	to.y = 0.0
	if to.length() < 0.05:
		return true
	var want := atan2(to.x, to.z)
	for off in [0.0, 0.6, -0.6, 1.2, -1.2, 1.75, -1.75]:
		var dir := Vector3(sin(want + off), 0.0, cos(want + off))
		if _can_step(dir):
			_face(global_position + dir, delta)
			var step := dir * WALK_SPEED * scale_k * delta
			global_position += step
			_snap_to_ground()
			_play("walk", 0.25, WALK_ANIM_RATE)
			return true
	_play("idle")
	return false


func _can_step(dir: Vector3) -> bool:
	var probe := global_position + dir * STEP_PROBE * scale_k
	var hit := _ground_at(probe)
	if hit.is_empty():
		_why_blocked = "no ground"
		return false
	var rise := float(hit["position"].y) - global_position.y
	if rise > MAX_RISE * scale_k:
		_why_blocked = "too steep up (%.2f m)" % rise
		return false
	if rise < -2.5 * scale_k:
		_why_blocked = "drop"
		return false            # a drop - doesn't walk off cliffs
	# REV 505: abs - the scan's faces aren't all wound the same way, so a ray can report a flat face's
	# normal pointing DOWN; the old test then called every uphill step a wall (Glen: the Gorn just stood).
	if absf((hit["normal"] as Vector3).y) >= MIN_FLOOR_NORMAL_Y or rise < 0.05:
		return true
	_why_blocked = "slope (normal %.2f)" % (hit["normal"] as Vector3).y
	return false


var _why_blocked := ""

## REV 505: one line for the F3 read-out (ArenaMemory.debug_where).
func debug_text() -> String:
	var anim := _current_anim
	if not _have_anims:
		anim = "NO CLIPS LOADED"
	elif _anim != null and not _anim.is_playing():
		anim += " (stopped)"
	var dist := -1.0
	if target != null and is_instance_valid(target):
		dist = Vector2(target.global_position.x - global_position.x, target.global_position.z - global_position.z).length()
	var t := "%s  anim %s  dist %.1f m  hp %d" % [State.keys()[state], anim, dist, int(hp)]
	if target == null:
		t += "  NO TARGET"
	if _why_blocked != "":
		t += "  last blocked: " + _why_blocked
	return t


func _snap_to_ground() -> void:
	var hit := _ground_at(global_position)
	if not hit.is_empty():
		global_position.y = float(hit["position"].y)


func _ground_at(p: Vector3) -> Dictionary:
	if not is_inside_tree():
		return {}
	var space := get_world_3d().direct_space_state
	var q := PhysicsRayQueryParameters3D.create(p + Vector3.UP * 3.0 * scale_k, p + Vector3.DOWN * 6.0 * scale_k, TERRAIN_MASK)
	return space.intersect_ray(q)


func _can_see_target() -> bool:
	var eye := global_position + Vector3.UP * HEIGHT * 0.88 * scale_k
	var aim := target.global_position + Vector3.UP * 1.2 * scale_k
	if eye.distance_to(aim) > SIGHT_RANGE * scale_k:
		return false
	var space := get_world_3d().direct_space_state
	var q := PhysicsRayQueryParameters3D.create(eye, aim, TERRAIN_MASK)
	return space.intersect_ray(q).is_empty()


func _face(point: Vector3, delta: float) -> void:
	var d := point - global_position
	if Vector2(d.x, d.z).length() < 0.01:
		return
	rotation.y = rotate_toward(rotation.y, atan2(d.x, d.z), TURN_SPEED * delta)


func _start_attack() -> void:
	_attack_kind = "punch" if randf() < 0.55 else "swipe"
	var def: Array = ATTACKS[_attack_kind]
	_attack_len = play_once(String(def[0]), 0.12)
	_attack_done = false
	_set_state(State.ATTACK)


func _do_attack(delta: float) -> void:
	var def: Array = ATTACKS[_attack_kind]
	if _state_t < _attack_len * float(def[1]) * 0.6:
		_face(target.global_position, delta)       # tracks during the wind-up only
	if not _attack_done and _state_t >= _attack_len * float(def[1]):
		_attack_done = true
		if _in_reach() and not _dodging():
			attack_landed.emit(_attack_kind, float(def[2]))
		else:
			attack_missed.emit(_attack_kind)
	if _state_t >= _attack_len + float(def[3]):
		_set_state(State.STALK)


func _in_reach() -> bool:
	var to := target.global_position - global_position
	to.y = 0.0
	if to.length() > HIT_RANGE * scale_k:
		return false
	var fwd := Vector3(sin(rotation.y), 0.0, cos(rotation.y))
	return rad_to_deg(fwd.angle_to(to.normalized())) <= HIT_CONE_DEG


func _dodging() -> bool:
	return target_dodging.is_valid() and bool(target_dodging.call())


# ---- the boulder throw ------------------------------------------------------------------------

var _throw_len := 1.5
var _thrown := false

func _start_throw() -> void:
	_throw_len = play_once("throw", 0.15)
	_thrown = false
	_throw_cd = THROW_COOLDOWN
	_set_state(State.THROW)
	# where it'll land: where the target is heading
	throw_started.emit(_predict_landing(), _throw_len * THROW_RELEASE + THROW_FLIGHT)


func _predict_landing() -> Vector3:
	var v := Vector3.ZERO
	if target is CharacterBody3D:
		v = (target as CharacterBody3D).velocity
		v.y = 0.0
	return target.global_position + v * (_throw_len * THROW_RELEASE + THROW_FLIGHT) * 0.5


func _do_throw() -> void:
	var land := _predict_landing()
	if _state_t < _throw_len * THROW_RELEASE:
		_face(target.global_position, get_physics_process_delta_time())
	elif not _thrown:
		_thrown = true
		_launch_boulder(land)
	if _state_t >= _throw_len:
		_set_state(State.STALK)


func _launch_boulder(land: Vector3) -> void:
	var rock := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = 0.45 * scale_k
	sm.height = 0.7 * scale_k
	rock.mesh = sm
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.55, 0.47, 0.38)
	mat.roughness = 1.0
	rock.material_override = mat
	get_parent().add_child(rock)
	var start := global_position + Vector3.UP * HEIGHT * 1.05 * scale_k
	rock.global_position = start
	var g := _ground_at(land)
	if not g.is_empty():
		land = g["position"]
	var fly := func(f: float) -> void:
		if is_instance_valid(rock):
			var p := start.lerp(land, f)
			p.y += sin(f * PI) * 3.0 * scale_k
			rock.global_position = p
			rock.rotation += Vector3(0.11, 0.07, 0.0)
	var landed := func() -> void:
		_boulder_landed(land)
		if is_instance_valid(rock):
			foam_bounce(rock, land, land - start, scale_k, sm.radius)
			var fade := rock.create_tween()
			fade.tween_interval(5.0)
			fade.tween_callback(rock.queue_free)
	var tw := create_tween()
	tw.tween_method(fly, 0.0, 1.0, THROW_FLIGHT)
	tw.tween_callback(landed)


## REV 504: a 1967 boulder - it lands and bounces like the prop it was (Glen: the rocks didn't look like
## big pieces of styrofoam). Three shrinking hops along `dir`, a hollow bonk on each, then a little wobble.
## Static so the Arena room uses it too (Kirk's heave).
const FOAM_HOPS := [[1.3, 0.55, 0.34], [0.55, 0.2, 0.22], [0.2, 0.07, 0.14]]   # metres along, metres up, seconds
const FOAM_SOUND := "res://assets/audio/sfx/arena/foam_bonk.wav"

static func foam_bounce(rock: Node3D, land: Vector3, dir: Vector3, k: float, radius: float, done := Callable()) -> void:
	if rock == null or not rock.is_inside_tree():
		return
	dir.y = 0.0
	dir = dir.normalized() if dir.length() > 0.01 else Vector3.FORWARD
	var axis := dir.cross(Vector3.UP).normalized()
	var space := rock.get_world_3d().direct_space_state
	var bonk: AudioStreamPlayer3D = null
	if ResourceLoader.exists(FOAM_SOUND):
		bonk = AudioStreamPlayer3D.new()
		bonk.stream = load(FOAM_SOUND)
		bonk.bus = "SFX" if AudioServer.get_bus_index("SFX") >= 0 else "Master"
		rock.add_child(bonk)
		bonk.play()
	var tw := rock.create_tween()
	var from := land
	var loud := 0.0
	for hop in FOAM_HOPS:
		var to: Vector3 = from + dir * float(hop[0]) * k
		var q := PhysicsRayQueryParameters3D.create(to + Vector3.UP * 4.0 * k, to + Vector3.DOWN * 8.0 * k, TERRAIN_MASK)
		var hit := space.intersect_ray(q)
		to.y = (float(hit["position"].y) if not hit.is_empty() else from.y) + radius * 0.55
		var a := from
		var b := to
		var h := float(hop[1]) * k
		var spin := -float(hop[0]) * k / maxf(radius, 0.05) / 12.0
		tw.tween_method(func(f: float) -> void:
			if is_instance_valid(rock):
				var p := a.lerp(b, f)
				p.y += sin(f * PI) * h
				rock.global_position = p
				rock.rotate(axis, spin), 0.0, 1.0, float(hop[2]))
		loud -= 5.0
		var db := loud
		tw.tween_callback(func() -> void:
			if is_instance_valid(bonk):
				bonk.volume_db = db
				bonk.play())
		from = b
	for w in [0.14, -0.1, 0.05, -0.09]:
		tw.tween_property(rock, "rotation:x", w, 0.09).as_relative()
	if done.is_valid():
		tw.tween_callback(done)


func _boulder_landed(land: Vector3) -> void:
	if target == null or not is_instance_valid(target):
		return
	var d := Vector2(target.global_position.x - land.x, target.global_position.z - land.z).length()
	if d <= BOULDER_HIT_RADIUS * scale_k and not _dodging():
		attack_landed.emit("boulder", BOULDER_DAMAGE)
	else:
		attack_missed.emit("boulder")
