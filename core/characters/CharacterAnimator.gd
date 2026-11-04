extends Node
class_name CharacterAnimator
## CharacterAnimator (REV 86): walking and bowling for the rigged stand-ins, done in code.
##
## The figures have skeletons but no animation clips. This node sits inside a character (the wrapper
## CharacterKit.make() returns), watches how fast that wrapper is moving, and swings the legs, arms and
## body to match. It also holds a kneel-and-bowl move (play_bowl) used by the Prologue's opening strike.
##
## Everything is described as "a limb turned this many degrees about the character's side-to-side axis",
## measured from how the figure stands when still. That keeps it working whatever way a rig's own bones
## happen to point. Angles: for a limb that hangs down, POSITIVE swings it BACKWARD; for the body leaning
## up, POSITIVE leans it FORWARD. (The figure faces +Z in its own space.)

signal released(hand_position: Vector3)   # the bowling ball leaves the hand
signal bowl_finished

## Walking tuning.
const CYCLE_METRES := 2.0         # one full left-right stride, in the figure's own metres
const WALK_FULL_SPEED := 3.6      # figure-metres per second at which the swing reaches full size
const THIGH_SWING := 30.0
const KNEE_BEND := 48.0
const ARM_SWING := 24.0
const ELBOW_BEND := 16.0
const WALK_LEAN := 3.0
const BOB := 0.014

## Bowling tuning (the move lasts BOWL_LENGTH seconds; the ball is let go at BOWL_RELEASE).
const BOWL_LENGTH := 3.3
const BOWL_RELEASE := 1.75
const BOWL_LEAN := 70.0
const BOWL_FRONT_THIGH := 88.0    # how far forward the front thigh swings when kneeling
const BOWL_KNEE_FLOOR := 0.10     # height of the kneeling knee above the floor (figure metres)

## Bones to drive, by role -> name prefixes (lower case, "." turned into "_"). First rig that has
## the "torso" prefix wins.
const RIGS: Array = [
	{ # the captains kit
		"torso": "torso_", "chest": "chest_", "head": "head_",
		"ul_l": "u_l_l_", "ll_l": "l_l_l_", "ft_l": "foot_l_", "ul_r": "u_l_r_", "ll_r": "l_l_r_", "ft_r": "foot_r_",
		"ua_l": "u_a_l_", "la_l": "l_a_l_", "ha_l": "middlefingerbase_l_",
		"ua_r": "u_a_r_", "la_r": "l_a_r_", "ha_r": "middlefingerbase_r_",
	},
	{ # Mixamo-style (the old Spock file, the clone trooper)
		"torso": "mixamorig:hips_", "chest": "mixamorig:spine2_", "head": "mixamorig:head_",
		"ul_l": "mixamorig:leftupleg_", "ll_l": "mixamorig:leftleg_", "ft_l": "mixamorig:leftfoot_",
		"ul_r": "mixamorig:rightupleg_", "ll_r": "mixamorig:rightleg_", "ft_r": "mixamorig:rightfoot_",
		"ua_l": "mixamorig:leftarm_", "la_l": "mixamorig:leftforearm_", "ha_l": "mixamorig:lefthand_",
		"ua_r": "mixamorig:rightarm_", "la_r": "mixamorig:rightforearm_", "ha_r": "mixamorig:righthand_",
	},
	{ # Character Creator rigs (the realistic female / McCoy files)
		"torso": "cc_base_hip_", "chest": "cc_base_spine02_", "head": "cc_base_head_",
		"ul_l": "cc_base_l_thigh_", "ll_l": "cc_base_l_calf_", "ft_l": "cc_base_l_foot_",
		"ul_r": "cc_base_r_thigh_", "ll_r": "cc_base_r_calf_", "ft_r": "cc_base_r_foot_",
		"ua_l": "cc_base_l_upperarm_", "la_l": "cc_base_l_forearm_", "ha_l": "cc_base_l_hand_",
		"ua_r": "cc_base_r_upperarm_", "la_r": "cc_base_r_forearm_", "ha_r": "cc_base_r_hand_",
	},
	{ # REV 751: Daz Genesis 9 - before Genesis 8, which also has a "hip" (a rig only counts when its legs are
	  # there too). No "head" role, as for Genesis 8. (_find skips the twist helpers.)
		"torso": "hip", "chest": "spine4",
		"ul_l": "l_thigh", "ll_l": "l_shin", "ft_l": "l_foot", "toe_l": "l_toes",
		"ul_r": "r_thigh", "ll_r": "r_shin", "ft_r": "r_foot", "toe_r": "r_toes",
		"ua_l": "l_upperarm", "la_l": "l_forearm", "ha_l": "l_hand",
		"ua_r": "r_upperarm", "la_r": "r_forearm", "ha_r": "r_hand",
	},
	{ # REV 97: Daz Genesis 8 (first the old McCoy_rigged.glb, now every *_daz.fbx - REV 293). No "head" role on
	  # purpose: CharacterFace owns the neck, head and eyes so characters can look at each other.
		"torso": "hip", "chest": "chestupper",
		"ul_l": "lthighbend", "ll_l": "lshin", "ft_l": "lfoot", "toe_l": "ltoe",
		"ul_r": "rthighbend", "ll_r": "rshin", "ft_r": "rfoot", "toe_r": "rtoe",
		"ua_l": "lshldrbend", "la_l": "lforearmbend", "ha_l": "lhand",
		"ua_r": "rshldrbend", "la_r": "rforearmbend", "ha_r": "rhand",
	},
]

## REV 129: characters whose skeleton takes the Mixamo clips (McCoy from Daz, and every stand-in) are
## animated by CharacterMotion instead of the code below; the code stays as the fallback for any rig it
## can't handle (and if the clips are missing from the project).
var motion: CharacterMotion = null
signal action_finished(id: String)
var _root_home := Vector3.ZERO
var _root_active := false
var _last_yaw := 0.0
var _have_yaw := false
var _turn := 0.0
var _vel := Vector3.ZERO
var _lod_acc := 0.0
var _lod_frame := 0

## Set this to a node and the ball follows the right hand until it is let go.
var held_ball: Node3D = null
var held_ball_drop: float = 0.08        # how far below the hand the ball's centre hangs

var ready_to_animate := false
var _model: Node3D
var _skel: Skeleton3D
var _bone := {}                # role -> bone index (-1 when the rig lacks it)
var _base := {}                # bone index -> global basis when standing still
var _idle_rot := {}            # bone index -> local rotation when standing still
var _driven: Array = []        # bone indices, parents first
var _to_model: Basis           # skeleton space -> the character's own space (includes scale)
var _axis: Vector3             # the character's side-to-side axis, in skeleton space
var _up_s := Vector3.UP        # the character's up and forward axes, in skeleton space (full gait)
var _fwd_s := Vector3.BACK
## REV 97: rigs with toe bones (Genesis 8) get the fuller walk: heel-to-toe feet, hip sway and turn,
## shoulders turning against the hips, relaxed arms. The stand-ins keep the simple walk.
var _full_gait := false
const FULL_WALK_SPEED := 2.4   # figure-metres per second at which the full walk reaches full size
const ARM_REST_OUT := 7.0      # degrees out from the sides the arms hang (Genesis stands in an A-pose)
const LEG_REST_OUT := 2.5      # and the legs (Genesis stands with its feet apart)
var _torso_rest_pos := Vector3.ZERO

# figure measurements, in the character's own metres
var _hip_y := 0.9
var _thigh := 0.44
var _shin := 0.34
var _ankle_y := 0.14
var _shoulder_up := 0.56       # shoulder above the hips
var _arm_len := 0.64

var _last_pos := Vector3.ZERO
var _have_last := false
var _acc_dist := 0.0
var _acc_time := 0.0
var _speed := 0.0
var _amp := 0.0
var _phase := 0.0
var _posed := false

var bowling := false
var _bowl_t := 0.0
var _bowl_released := false
## World-forward angle of the arm when the ball is let go (code-made bowl only). Measured on the kit
## figure: with the body this low the hand is a hand's width above the lane when the arm is about this
## far forward of straight down. REV 293: a fixed number (it was "worked out" by a function that only
## ever set 14).
const RELEASE_ARM := 14.0


func setup(model: Node3D, root: Node) -> void:
	_model = model
	var skels := root.find_children("*", "Skeleton3D", true, false)
	if skels.is_empty():
		return
	_skel = skels[0] as Skeleton3D
	var names := {}
	for i in _skel.get_bone_count():
		names[i] = _skel.get_bone_name(i).to_lower().replace(".", "_")
	var rig: Dictionary = {}
	for candidate in RIGS:
		# REV 751: the torso AND a thigh (Genesis 8 and 9 both have a "hip")
		if _find(names, String(candidate["torso"])) >= 0 and _find(names, String(candidate["ul_l"])) >= 0:
			rig = candidate
			break
	if rig.is_empty():
		return
	for role in rig.keys():
		_bone[role] = _find(names, String(rig[role]))
	if int(_bone["ul_l"]) < 0 or int(_bone["ll_l"]) < 0 or int(_bone["ul_r"]) < 0 or int(_bone["torso"]) < 0:
		return

	# skeleton space -> character space
	var xf := Transform3D.IDENTITY
	var n: Node = _skel
	while n != null and n != model:
		var n3 := n as Node3D
		if n3 != null:
			xf = n3.transform * xf
		n = n.get_parent()
	_to_model = xf.basis
	_axis = (_to_model.orthonormalized().inverse() * Vector3.RIGHT).normalized()
	_up_s = (_to_model.orthonormalized().inverse() * Vector3.UP).normalized()
	_fwd_s = (_to_model.orthonormalized().inverse() * Vector3.BACK).normalized()   # +Z: the way it faces
	_full_gait = int(_bone.get("toe_l", -1)) >= 0 and int(_bone.get("toe_r", -1)) >= 0
	if MotionClips.available():
		var r := MotionRig.new()
		if r.setup(_skel, _to_model):
			motion = CharacterMotion.new()
			motion.setup(r, String(model.get_meta("speaker_id", "")))
			motion.action_event.connect(_on_motion_event)
			motion.action_finished.connect(_on_motion_finished)

	for role in _bone.keys():
		var b: int = int(_bone[role])
		if b < 0:
			continue
		_base[b] = _skel.get_bone_global_pose(b).basis
		_idle_rot[b] = _skel.get_bone_pose_rotation(b)
		_driven.append(b)
	_driven.sort_custom(func(a, b2): return _depth(a) < _depth(b2))
	_torso_rest_pos = _skel.get_bone_pose_position(int(_bone["torso"]))
	if _full_gait and motion == null:
		_relax_stance()

	# measurements
	var hip := _model_pos(int(_bone["ul_l"]))
	var knee := _model_pos(int(_bone["ll_l"]))
	_hip_y = hip.y
	_thigh = hip.distance_to(knee)
	if int(_bone["ft_l"]) >= 0:
		var ankle := _model_pos(int(_bone["ft_l"]))
		_shin = knee.distance_to(ankle)
		_ankle_y = ankle.y
	if int(_bone["ua_r"]) >= 0 and int(_bone["la_r"]) >= 0 and int(_bone["ha_r"]) >= 0:
		var sh := _model_pos(int(_bone["ua_r"]))
		var el := _model_pos(int(_bone["la_r"]))
		var ha := _model_pos(int(_bone["ha_r"]))
		_arm_len = sh.distance_to(el) + el.distance_to(ha)
		_shoulder_up = maxf(sh.y - hip.y, 0.3)
	ready_to_animate = true
	set_process(true)


static func _find(names: Dictionary, prefix: String) -> int:
	for i in names.keys():
		var nm: String = names[i]
		if nm.begins_with(prefix) and not nm.contains("twist"):
			return int(i)
	return -1


func _depth(bone: int) -> int:
	var d := 0
	var p := _skel.get_bone_parent(bone)
	while p >= 0:
		d += 1
		p = _skel.get_bone_parent(p)
	return d


## Where a bone's joint is, in the character's own space (rest pose).
func _model_pos(bone: int) -> Vector3:
	return _to_model * _skel.get_bone_global_rest(bone).origin


## Where the right hand is in the world right now.
func hand_world() -> Vector3:
	var b: int = int(_bone.get("ha_r", -1))
	if _skel == null or b < 0:
		return _model.global_position + Vector3(0.0, 0.9, 0.0) if _model != null else Vector3.ZERO
	return _skel.global_transform * _skel.get_bone_global_pose(b).origin


## REV 199 (item 9): reach out and touch `world_point` with the nearer hand (Glen's "button" press,
## the hand steered onto the spot). Returns how long until the fingers arrive (0 = can't animate);
## `touched` fires then. The whole move takes about 3 s; the body stays where it is.
signal touched(world_point: Vector3)
func reach_to(world_point: Vector3) -> float:
	if motion == null or _model == null or _skel == null:
		return 0.0
	var aim := _reach_aim(world_point)
	if aim.is_empty() or motion.reach(aim["offset"], aim["side"]) <= 0.0:
		return 0.0
	_reach_point = world_point
	return CharacterMotion.REACH_CONTACT - 0.0


## REV 232: while a reach is in progress, move the spot the hand is on (sliding a control with it).
## Keeps the arm that started the reach. Call every frame the spot moves.
func move_reach(world_point: Vector3) -> void:
	if motion == null or _model == null or _skel == null:
		return
	var aim := _reach_aim(world_point, motion.reach_side)
	if aim.is_empty():
		return
	motion.reach_offset = aim["offset"]
	_reach_point = world_point


## Where `world_point` is from the reaching shoulder, in the character's own frame (x forward, y left,
## z up) and in the animation skeleton's measure, plus which arm. Empty if the skeleton lacks the bones.
func _reach_aim(world_point: Vector3, force_side := "") -> Dictionary:
	var fwd := _model.global_transform.basis.z
	fwd.y = 0.0
	fwd = fwd.normalized() if fwd.length() > 0.001 else Vector3.BACK
	var left := Vector3.UP.cross(fwd).normalized()
	var to := world_point - _model.global_position
	var side := force_side if force_side != "" else ("Left" if to.dot(left) > 0.12 else "Right")     # right-handed unless it's well to his left
	# REV 751: the arm bones by role (Genesis 8 lShldrBend/lForearmBend/lHand, Genesis 9 l_upperarm/l_forearm/l_hand)
	var s := "l" if side == "Left" else "r"
	var sh := int(_bone.get("ua_" + s, -1))
	var at := _skel.global_transform * _skel.get_bone_global_pose(sh).origin if sh >= 0 else _model.global_position + Vector3.UP * 1.45
	var d := world_point - at
	# the animation skeleton's arm isn't the model's length: aim for the same fraction of the arm's
	# reach, so the model's own fingertips arrive on the spot
	var b_sh := sh
	var b_el := int(_bone.get("la_" + s, -1))
	var b_wr := int(_bone.get("ha_" + s, -1))
	var scale := 1.0
	if b_sh >= 0 and b_el >= 0 and b_wr >= 0:
		var g := _skel.global_transform
		var model_arm := (g * _skel.get_bone_global_rest(b_sh).origin).distance_to(g * _skel.get_bone_global_rest(b_el).origin) \
			+ (g * _skel.get_bone_global_rest(b_el).origin).distance_to(g * _skel.get_bone_global_rest(b_wr).origin)
		var src_arm := motion.arm_length_m(side)
		if model_arm > 0.05 and src_arm > 0.05:
			scale = src_arm / model_arm
	return {"offset": Vector3(d.dot(fwd), d.dot(left), d.y) * scale, "side": side}


var _reach_point := Vector3.INF


# ---- driving bones -------------------------------------------------------------------

## Turn a bone to `deg` about the character's side axis, measured from its still-standing orientation.
func _set_abs(role: String, deg: float) -> void:
	var b: int = int(_bone.get(role, -1))
	if b < 0:
		return
	var parent := _skel.get_bone_parent(b)
	var pb := Basis.IDENTITY
	if parent >= 0:
		pb = _skel.get_bone_global_pose(parent).basis
	var target: Basis = Basis(_axis, deg_to_rad(deg)) * (_base[b] as Basis)
	var local: Basis = pb.inverse() * target
	_skel.set_bone_pose_rotation(b, local.orthonormalized().get_rotation_quaternion())


## Move the hips from where they stand still, by `offset` in the character's own metres.
func _set_torso_offset(offset: Vector3) -> void:
	var b: int = int(_bone["torso"])
	var parent := _skel.get_bone_parent(b)
	var pb := Basis.IDENTITY
	if parent >= 0:
		pb = _skel.get_bone_global_pose(parent).basis
	var in_skel: Vector3 = _to_model.inverse() * offset
	_skel.set_bone_pose_position(b, _torso_rest_pos + pb.inverse() * in_skel)


func _restore() -> void:
	for b in _driven:
		_skel.set_bone_pose_rotation(int(b), _idle_rot[b])
	_skel.set_bone_pose_position(int(_bone["torso"]), _torso_rest_pos)
	_posed = false


# ---- per frame -----------------------------------------------------------------------

func _process(delta: float) -> void:
	if not ready_to_animate or _skel == null or _model == null or not _model.is_inside_tree():
		return
	if delta <= 0.0:
		return
	_measure_speed(delta)
	if motion != null:
		_drive_motion(delta)
		return
	if bowling:
		_bowl_t += delta
		if _bowl_t >= BOWL_LENGTH:
			bowling = false
			_restore()
			bowl_finished.emit()
			return
		_pose_bowl(_bowl_t)
		_follow_ball()
		if not _bowl_released and _bowl_t >= BOWL_RELEASE:
			_bowl_released = true
			var at := hand_world()
			held_ball = null
			released.emit(at)
		return
	var target := clampf(_speed / (FULL_WALK_SPEED if _full_gait else WALK_FULL_SPEED), 0.0, 1.0)
	_amp = lerpf(_amp, target, 1.0 - exp(-10.0 * delta))
	if _amp < 0.015:
		if _posed:
			_restore()
		return
	if _full_gait:
		# longer strides when going faster, so the legs don't race
		var cycle := clampf(1.4 + 0.3 * _speed, 1.4, 2.6)
		_phase += _speed * delta * TAU / cycle
		_pose_full(_phase, _amp)
		return
	_phase += _speed * delta * TAU / CYCLE_METRES
	_pose_walk()


## Speed of the character in its own metres per second, from how far its position moves.
func _measure_speed(delta: float) -> void:
	var gs := maxf(_model.global_transform.basis.get_scale().x, 0.001)
	var p := _model.global_position
	if not _have_last:
		_last_pos = p
		_have_last = true
		return
	var step := Vector2(p.x - _last_pos.x, p.z - _last_pos.z).length() / gs
	_last_pos = p
	if step > 2.5:          # a jump (a teleport or a new room), not a walk
		_acc_dist = 0.0
		_acc_time = 0.0
		return
	_acc_dist += step
	_acc_time += delta
	if _acc_time >= 0.07:
		_speed = _acc_dist / _acc_time
		_acc_dist = 0.0
		_acc_time = 0.0


func _pose_walk() -> void:
	var s := sin(_phase)
	var c := cos(_phase)
	var a := _amp
	# legs: one swings back while the other swings forward; the knee bends while a leg swings through
	var thigh_l := -THIGH_SWING * a * s
	var thigh_r := THIGH_SWING * a * s
	var knee_l := KNEE_BEND * a * maxf(0.0, c)
	var knee_r := KNEE_BEND * a * maxf(0.0, -c)
	_set_torso_offset(Vector3(0.0, -BOB * a * absf(c) , 0.0))
	_set_abs("torso", WALK_LEAN * a)
	_set_abs("ul_l", thigh_l)
	_set_abs("ll_l", thigh_l + knee_l)
	_set_abs("ft_l", 0.5 * (thigh_l + knee_l))
	_set_abs("ul_r", thigh_r)
	_set_abs("ll_r", thigh_r + knee_r)
	_set_abs("ft_r", 0.5 * (thigh_r + knee_r))
	# arms swing against the legs
	var arm_l := ARM_SWING * a * s
	var arm_r := -ARM_SWING * a * s
	_set_abs("ua_l", arm_l)
	_set_abs("la_l", arm_l - ELBOW_BEND * a)
	_set_abs("ua_r", arm_r)
	_set_abs("la_r", arm_r - ELBOW_BEND * a)
	_set_abs("head", -WALK_LEAN * a * 0.6)
	_posed = true


# ---- the full walk (REV 97, rigs with toe bones) --------------------------------------
## Prototyped and checked frame by frame on the old McCoy_rigged.glb (removed since; tools: work/mccoy2/gait.py) before
## being written here; the numbers are the same.

## Arms down from the A-pose and feet closer together: changes the "standing still" pose itself.
func _relax_stance() -> void:
	for side in ["l", "r"]:
		var out_sign := 1.0 if side == "l" else -1.0
		if int(_bone.get("ua_" + side, -1)) >= 0 and int(_bone.get("la_" + side, -1)) >= 0:
			var arm := Basis(_fwd_s, _frontal_turn("ua_" + side, "la_" + side, ARM_REST_OUT * out_sign))
			for role in ["ua_" + side, "la_" + side]:
				var b: int = int(_bone[role])
				_base[b] = arm * (_base[b] as Basis)
		var leg := Basis(_fwd_s, _frontal_turn("ul_" + side, "ll_" + side, LEG_REST_OUT * out_sign))
		for role in ["ul_" + side, "ll_" + side]:
			var b: int = int(_bone[role])
			_base[b] = leg * (_base[b] as Basis)
	# the new still pose becomes the one _restore() goes back to
	_pose_full(0.0, 0.0)
	for b in _driven:
		_idle_rot[b] = _skel.get_bone_pose_rotation(int(b))


## The turn (radians, about the forward axis) that brings a limb to `want_deg` out from straight down.
func _frontal_turn(top_role: String, bottom_role: String, want_deg: float) -> float:
	var d := _model_pos(int(_bone[bottom_role])) - _model_pos(int(_bone[top_role]))
	var have := Vector2(d.x, d.y)
	var want := Vector2(sin(deg_to_rad(want_deg)), -cos(deg_to_rad(want_deg)))
	return atan2(have.x * want.y - have.y * want.x, have.dot(want))


## Like _set_abs, with a turn about the up axis (yaw: + turns +Z toward +X) and the forward axis
## (roll: + lifts the +X side). follow_chest: the arms ride along with the chest's own turn.
func _set_rot(role: String, pitch: float, yaw: float = 0.0, roll: float = 0.0, follow_chest: bool = false) -> void:
	var b: int = int(_bone.get(role, -1))
	if b < 0:
		return
	var target: Basis = Basis(_up_s, deg_to_rad(yaw)) * Basis(_fwd_s, deg_to_rad(roll)) * Basis(_axis, deg_to_rad(pitch)) * (_base[b] as Basis)
	var chest: int = int(_bone.get("chest", -1))
	if follow_chest and chest >= 0:
		var now := _skel.get_bone_global_pose(chest).basis.orthonormalized()
		target = now * (_base[chest] as Basis).orthonormalized().inverse() * target
	var parent := _skel.get_bone_parent(b)
	var pb := Basis.IDENTITY
	if parent >= 0:
		pb = _skel.get_bone_global_pose(parent).basis
	var local: Basis = pb.inverse() * target
	_skel.set_bone_pose_rotation(b, local.orthonormalized().get_rotation_quaternion())


## One moment of the full walk. a = 0 (standing) .. 1 (full stride).
func _pose_full(phase: float, a: float) -> void:
	var s := sin(phase)
	var c := cos(phase)
	var thigh_swing := a * (20.0 + 12.0 * a)
	var knee_swing := a * (30.0 + 30.0 * a)
	_set_torso_offset(Vector3(-0.022 * a * c, -0.03 * a * absf(s), 0.0))
	_set_rot("torso", 3.0 * a, -5.0 * a * s, -2.5 * a * c)      # lean, hips turn with the leading leg, hip drop
	_set_rot("chest", 2.0 * a, 7.0 * a * s, 1.5 * a * c)        # shoulders turn the other way
	for side in ["l", "r"]:
		var sg := 1.0 if side == "l" else -1.0                    # the right leg is half a cycle later
		var ss := s * sg
		var cc := c * sg
		var thigh := -thigh_swing * ss * (1.0 if ss > 0.0 else 0.8) - 3.0 * a
		var knee := knee_swing * pow(maxf(0.0, cc), 1.3) + 8.0 * a * maxf(0.0, -cc) * maxf(0.0, ss) \
			+ 18.0 * a * maxf(0.0, -cc) * pow(maxf(0.0, -ss), 2.0)
		var foot: float
		if ss >= 0.0:
			foot = -12.0 * a * ss                   # toe up, ready for the heel to land
		elif cc < 0.0:
			foot = 30.0 * a * ss * ss               # heel lifting: pushing off the toes
		else:
			foot = 30.0 * a * pow(-ss, 3.0)         # the foot leaving the floor
		var arm := 16.0 * a * ss + 3.0 * a          # arms swing against the legs
		var fore := arm - (6.0 + 12.0 * maxf(0.0, -ss)) * (0.5 + 0.5 * a)
		_set_rot("ul_" + side, thigh)
		_set_rot("ll_" + side, thigh + knee)
		_set_rot("ft_" + side, foot)
		_set_rot("toe_" + side, minf(foot, 0.0))    # toes stay on the floor while the heel lifts
		_set_rot("ua_" + side, arm, 0.0, 0.0, true)
		_set_rot("la_" + side, fore, 0.0, 0.0, true)
	_posed = true


# ---- kneel and bowl ------------------------------------------------------------------

## Start the kneel-and-bowl move. `released` fires when the ball leaves the hand and `bowl_finished`
## when the character is standing again. Give held_ball first and the ball rides in the hand.
func play_bowl() -> void:
	if not ready_to_animate:
		# no usable skeleton: still let the caller's timeline run
		await get_tree().create_timer(BOWL_RELEASE, false).timeout
		released.emit(_model.global_position + Vector3(0.0, 0.3, 0.0) if _model != null else Vector3.ZERO)
		await get_tree().create_timer(BOWL_LENGTH - BOWL_RELEASE, false).timeout
		bowl_finished.emit()
		return
	if motion != null and MotionClips.has_clip("throw"):
		_bowl_released = false
		bowling = true
		_begin_root_motion()
		motion.play("throw", {"fade_in": 0.3, "fade_out": 0.6})
		return
	_bowl_t = 0.0
	_bowl_released = false
	bowling = true
	_amp = 0.0


## The kneeling shape, worked out from this figure's own proportions.
func _kneel_numbers() -> Dictionary:
	var alpha := deg_to_rad(BOWL_FRONT_THIGH)
	var hip_h: float = _ankle_y + _shin + _thigh * cos(alpha)
	var drop: float = _hip_y - hip_h
	var back_cos: float = clampf((hip_h - BOWL_KNEE_FLOOR) / _thigh, 0.0, 1.0)
	var beta: float = rad_to_deg(acos(back_cos))
	return {"hip_h": hip_h, "drop": drop, "back": beta, "shift": _thigh * sin(alpha)}


## Smooth curve through keys [[time, value], ...] (Catmull-Rom, flat before the first and after the last key).
static func _curve(keys: Array, t: float) -> float:
	var n := keys.size()
	if t <= float(keys[0][0]):
		return float(keys[0][1])
	if t >= float(keys[n - 1][0]):
		return float(keys[n - 1][1])
	var i := 0
	while i < n - 2 and t >= float(keys[i + 1][0]):
		i += 1
	var t0 := float(keys[i][0])
	var t1 := float(keys[i + 1][0])
	var w := (t - t0) / maxf(t1 - t0, 0.0001)
	var v0 := float(keys[i][1])
	var v1 := float(keys[i + 1][1])
	var pre := float(keys[maxi(i - 1, 0)][1])
	var post := float(keys[mini(i + 2, n - 1)][1])
	return cubic_interpolate(v0, v1, pre, post, w)


func _pose_bowl(t: float) -> void:
	var k := _kneel_numbers()
	# how far down: 0 standing, 1 kneeling
	var kneel := _curve([[0.0, 0.0], [0.5, 0.0], [1.2, 1.0], [2.5, 1.0], [3.25, 0.0]], t)
	kneel = clampf(kneel, 0.0, 1.0)
	# the bowling arm (degrees forward of hanging straight down)
	var arm := _curve([[0.0, 0.0], [0.55, -14.0], [1.15, -52.0], [1.4, -58.0], [BOWL_RELEASE, RELEASE_ARM], [2.0, 78.0], [2.55, 84.0], [3.25, 0.0]], t)
	var elbow := _curve([[0.0, 0.0], [1.2, 24.0], [1.5, 14.0], [BOWL_RELEASE, 4.0], [2.2, 20.0], [3.25, 0.0]], t)
	var off_arm := 22.0 * kneel
	var lean := BOWL_LEAN * kneel
	_set_torso_offset(Vector3(0.0, -float(k["drop"]) * kneel, -float(k["shift"]) * kneel))
	_set_abs("torso", lean)
	# front leg (left): thigh forward, shin straight down, foot flat
	_set_abs("ul_l", -BOWL_FRONT_THIGH * kneel)
	_set_abs("ll_l", 0.0)
	_set_abs("ft_l", 0.0)
	# back leg (right): thigh nearly vertical, shin along the floor behind
	_set_abs("ul_r", float(k["back"]) * kneel)
	_set_abs("ll_r", 88.0 * kneel)
	_set_abs("ua_l", -off_arm)
	_set_abs("la_l", -off_arm - 20.0 * kneel)
	_set_abs("ua_r", -arm)
	_set_abs("la_r", -arm - elbow)
	_set_abs("head", 0.28 * lean)
	_posed = true


func _follow_ball() -> void:
	if held_ball == null or not is_instance_valid(held_ball):
		return
	held_ball.global_position = hand_world() + Vector3(0.0, -held_ball_drop, 0.0)


# ---- REV 129: the Mixamo clips ---------------------------------------------------------

## REV 160: a Daz Genesis 8 Female figure (its body mesh is named Genesis8Female...), as the importer
## decides it for the eyelashes.
func _is_female_figure() -> bool:
	if _model == null:
		return false
	# REV 182: a figure that says what it is (crew bodies, CrewLooks) is believed first
	var n: Node = _model
	while n != null:
		if n.has_meta("sex"):
			return String(n.get_meta("sex")) == "female"
		if n is CharacterBody3D or n == get_tree().current_scene:
			break
		n = n.get_parent()
	for m in _model.find_children("*", "MeshInstance3D", true, false):
		var low := String(m.name).to_lower()
		if low.begins_with("genesis8female") or low.begins_with("genesis_8_female") or low.contains("genesis8female"):
			return true
	# the Genesis 8 Female skeleton, whatever the meshes are called
	for sk in _model.find_children("*", "Skeleton3D", true, false):
		var s3 := sk as Skeleton3D
		for i in s3.get_bone_count():
			if String(s3.get_bone_name(i)).to_lower().begins_with("genesis8female"):
				return true
	return false


func has_motion() -> bool:
	return motion != null


var _female_checked := false

func _drive_motion(delta: float) -> void:
	if not _female_checked:
		_female_checked = true
		motion.female = _is_female_figure()
		if motion.female and motion.posture == "sit":
			motion.sit_now()      # seated before we knew: take the women's seated pose
	# REV 293: follow the figure's speaker id whenever it is set or changed (rooms often set it after
	# the animator was made, e.g. CrewLooks says "crew" and then a room renames the figure "pell");
	# set_who() also picks the right standing idle for that person
	var sid := String(_model.get_meta("speaker_id", ""))
	if sid != "" and sid != motion.who:
		motion.set_who(sid)
	# holding the bowling ball: an ordinary stance (Spock's hands-behind-the-back would hide it)
	if held_ball != null and motion.stance != "":
		_stance_saved = motion.stance
		motion.set_stance("")
	elif held_ball == null and _stance_saved != "" and not bowling:
		motion.set_stance(_stance_saved)
		_stance_saved = ""
	# how it's moving: speed (measured above), turning, and forwards or backwards
	var z := _model.global_transform.basis.z
	if z.is_finite() and Vector2(z.x, z.z).length() > 0.000001:
		var yaw := atan2(z.x, z.z)
		if _have_yaw and delta > 0.0005:
			var dyaw := wrapf(yaw - _last_yaw, -PI, PI)
			_turn = lerpf(_turn, clampf(dyaw / delta, -20.0, 20.0), 1.0 - exp(-8.0 * delta))
		_last_yaw = yaw
		_have_yaw = true
	if not is_finite(_turn):
		_turn = 0.0
	if not is_finite(_speed):
		_speed = 0.0
	motion.speed = _speed
	motion.turn_rate = _turn
	motion.backwards = _vel_backwards()
	# far away or out of sight: fewer updates
	_lod_acc += delta
	_lod_frame += 1
	var every := _lod_every()
	if every == 0:
		return
	if every > 1 and _lod_frame % every != 0:
		return
	var step := minf(_lod_acc, 0.25)      # coming back into view after a long time: no giant jump
	_lod_acc = 0.0
	var moved := motion.update(step)
	if moved != Vector3.ZERO:
		var before := _model.global_position
		_model.position += _model.transform.basis * moved
		# not walking: don't let the step count as speed
		_last_pos += _model.global_position - before
	_bowl_release_check()
	_place_tricorder()
	_place_cup()
	_place_phaser()
	_follow_ball()
	var face := CharacterFace.face_of(_model)
	if face != null:
		face.animated_base(motion.rig.skel)
		face.look_weight = 1.0 - motion.owns_head()


## 0 = don't animate this frame at all, 1 = every frame, n = every nth frame.
func _lod_every() -> int:
	if not _model.is_visible_in_tree():
		return 0
	var cam := get_viewport().get_camera_3d() if get_viewport() != null else null
	if cam == null:
		return 1
	var s := maxf(_model.global_transform.basis.get_scale().y, 0.01)
	var d := cam.global_position.distance_to(_model.global_position) / s
	if d > 40.0:
		return 4
	if d > 18.0:
		return 2
	return 1


func _vel_backwards() -> bool:
	if _speed < 0.2:
		return false
	var fwd := _model.global_transform.basis.z.normalized()
	var v := _model.global_position - _prev_for_dir
	_prev_for_dir = _model.global_position
	v.y = 0.0
	if v.length() < 0.0005:
		return _was_back
	_was_back = v.normalized().dot(fwd) < -0.3
	return _was_back

var _stance_saved := ""
var _prev_for_dir := Vector3.ZERO
var _was_back := false


func _begin_root_motion() -> void:
	if not _root_active:
		_root_home = _model.position
		_root_active = true


## A move that walked the character somewhere (standing up out of a seat, the bowl): hand the distance
## to whatever carries the character (the hotspot, the player's body), so it stays where it ended up.
func _end_root_motion() -> void:
	if not _root_active:
		return
	_root_active = false
	var par := _model.get_parent() as Node3D
	if par == null or par == get_tree().current_scene:
		return
	var world_off := _model.global_position - par.global_transform * _root_home
	_model.position = _root_home
	par.global_position += world_off
	_last_pos = _model.global_position
	_have_last = true


## The ball goes at the bottom of the swing: the first moment the hand starts rising again.
var _hand_y_last := INF

func _bowl_release_check() -> void:
	if not bowling or _bowl_released or motion.action == null or motion.action.id != "throw":
		_hand_y_last = INF
		return
	var t := motion.action.t
	if t < 1.42:
		_hand_y_last = INF
		return
	var y := hand_world().y
	var sc := maxf(_model.global_transform.basis.get_scale().y, 0.01)
	# the swing has passed its lowest point once the hand is 3 cm back up from it
	if y > _hand_y_last + 0.03 * sc or t > MotionClips.BOWL_RELEASE:
		_bowl_released = true
		held_ball = null
		released.emit(hand_world())
	_hand_y_last = minf(_hand_y_last, y)


func _on_motion_event(id: String, what: String) -> void:
	if id == "button" and what == "contact" and _reach_point.is_finite():
		touched.emit(_reach_point)
	if id == "phaser_draw" and what == "grab" and phaser != null:
		phaser_state = "hand"
	elif id == "phaser_holster" and what == "stow" and phaser != null:
		phaser_state = "belt"
	if id == "throw" and what == "release" and not _bowl_released:
		_bowl_released = true
		var at := hand_world()
		held_ball = null
		released.emit(at)


func _on_motion_finished(id: String) -> void:
	_end_root_motion()
	if id == "throw":
		bowling = false
		if not _bowl_released:
			_bowl_released = true
			held_ball = null
			released.emit(hand_world())
		bowl_finished.emit()
	action_finished.emit(id)


## A one-off move by name (see MotionClips.DEFS): "shrug", "point", "think", "button", "pick_up",
## "look_behind", "look_around", "communicator" ... Returns its length in seconds (0 = not available).
func play(id: String, opts: Dictionary = {}) -> float:
	if motion == null:
		return 0.0
	if MotionClips.get_clip(id) != null and bool(MotionClips.get_clip(id).settings.get("root_motion", false)):
		_begin_root_motion()
	return motion.play(id, opts)


func stop_action(fade := 0.4) -> void:
	if motion != null:
		motion.stop_action(fade)


func is_busy() -> bool:
	return motion != null and motion.is_busy()


func talk(style := "", strength := -1.0) -> void:
	if motion != null:
		motion.talk(style, strength)


## REV 242: listening to someone - small attentive movements (the Daz Conversations "Listening" loop).
## Stops with stop_talk(), or when this character starts talking.
func listen(strength := -1.0) -> void:
	if motion != null:
		motion.talk("listen", strength)


func stop_talk() -> void:
	if motion != null:
		motion.stop_talk()


func gesture(id: String, strength := 1.0) -> void:
	if motion != null:
		motion.gesture(id, strength)


func hold_loop(id: String, strength := 1.0) -> void:
	if motion != null:
		motion.hold_loop(id, strength)


func sit() -> float:
	if motion == null:
		return 0.0
	_begin_root_motion()
	return motion.sit()


func stand() -> float:
	if motion == null:
		return 0.0
	_begin_root_motion()
	return motion.stand()


func kneel() -> float:
	if motion == null:
		return 0.0
	_begin_root_motion()
	return motion.kneel()


## REV 576: kneel and sit back on the heels (X); stand_from_heels() gets him up again. Both return seconds.
func kneel_sit() -> float:
	if motion == null:
		return 0.0
	_begin_root_motion()
	return motion.kneel_sit()


func stand_from_heels() -> float:
	if motion == null:
		return 0.0
	var d := motion.rise_from_heels()
	if d > 0.0:
		await get_tree().create_timer(d, false).timeout
	if motion == null:
		return 0.0
	_begin_root_motion()
	var s := motion.stand()
	return s


func is_on_heels() -> bool:
	return motion != null and motion.on_heels


## REV 160: a "Yes!" fist pump over whatever pose he is in (see CharacterMotion.fist_pump).
func fist_pump() -> float:
	return motion.fist_pump() if motion != null else 0.0


func sit_now() -> void:
	if motion != null:
		motion.sit_now()


func posture() -> String:
	return motion.posture if motion != null else "stand"


func set_stance(id: String) -> void:
	if motion != null:
		motion.set_stance(id)


## Point at something in the world (the chest turns toward it; well to the left, the left hand).
func point_at(world_pos: Vector3, hold := 1.2) -> float:
	if motion == null or _model == null:
		return 0.0
	var d := _model.global_transform.affine_inverse() * world_pos
	var yaw := rad_to_deg(atan2(d.x, d.z))
	return motion.point(yaw, hold)



# ---- REV 168 (CLAUDE.md item 10): sitting with a drink ----------------------------------------
## A seated character drinks: the sipping loop (CharacterMotion.set_drinking) and a cup in the right
## hand. The cup rides in the palm (just past the wrist, toward the fingers), upright while it rests and
## tipped toward the mouth as the hand comes up to it. Its size follows the forearm, so it suits any
## figure and any drawn scale. set_drinking(false) puts it away. Sit the character first (sit/sit_now).
var cup: Node3D = null

func set_drinking(on: bool) -> void:
	if motion == null:
		return
	motion.set_drinking(on)
	if on and cup == null:
		cup = make_cup()
		cup.name = "Cup"
		_model.add_child(cup)
		cup.top_level = true
	elif not on and cup != null:
		cup.queue_free()
		cup = null


func is_drinking() -> bool:
	return motion != null and motion.drinking


func _place_cup() -> void:
	if cup == null or not is_instance_valid(cup) or _skel == null:
		return
	var bh: int = int(_bone.get("ha_r", -1))
	var bf: int = int(_bone.get("la_r", -1))
	var bhead: int = int(_bone.get("head", -1))
	if bhead < 0:
		bhead = _skel.find_bone("head")     # Daz: no "head" role (the face owns it), but the bone is there
	if bh < 0 or bf < 0:
		cup.visible = false
		return
	var hand := _skel.global_transform * _skel.get_bone_global_pose(bh).origin
	var elbow := _skel.global_transform * _skel.get_bone_global_pose(bf).origin
	var fore := hand - elbow
	var forearm_len := fore.length()
	if forearm_len < 0.0001:
		return
	var k := forearm_len / 0.26           # this figure's metres (a forearm is about 26 cm)
	var along := fore / forearm_len
	var palm := hand + along * 0.055 * k
	var up := Vector3.UP
	var near := 0.0
	var mouth := Vector3.ZERO
	if bhead >= 0:
		var hx := _skel.global_transform * _skel.get_bone_global_pose(bhead)
		# the mouth: below the head bone and a little in front of the face
		mouth = hx.origin + Vector3.DOWN * 0.035 * k + _model.global_transform.basis.z.normalized() * 0.09 * k
		var face_fwd := _model.global_transform.basis.z.normalized()
		var tip := (mouth - palm).normalized().lerp(-face_fwd, 0.35).normalized()
		near = clampf(1.0 - (palm.distance_to(mouth) / k - 0.08) / 0.16, 0.0, 1.0)
		near = near * near * (3.0 - 2.0 * near)
		if near > 0.0:
			up = up.lerp(tip, 0.7 * near).normalized()
	# a little toward the thumb side so the hand wraps it rather than sitting inside it
	var side := along.cross(up)
	if side.length() > 0.001:
		palm += side.normalized() * -0.012 * k
	var x := up.cross(Vector3.FORWARD)
	if x.length() < 0.01:
		x = up.cross(Vector3.RIGHT)
	x = x.normalized()
	var basis := Basis(x, up, x.cross(up).normalized()).scaled(Vector3.ONE * k)
	var origin := palm - up * 0.035 * k
	if near > 0.0:
		# sipping: the rim meets the lips (the hand is right there; the cup settles the last few cm)
		var rim_at_mouth := mouth - up * 0.09 * k
		origin = origin.lerp(rim_at_mouth, 0.75 * near)
	cup.global_transform = Transform3D(basis, origin)
	cup.visible = true


## A TOS-style plastic tumbler (about 9.5 cm tall, gently tapered, a darker band near the rim) with
## something to drink in it. Built in code: there is no cup model. Its origin is the bottom centre.
static func make_cup() -> Node3D:
	var root := Node3D.new()
	var body := MeshInstance3D.new()
	var m := CylinderMesh.new()
	m.top_radius = 0.037
	m.bottom_radius = 0.029
	m.height = 0.095
	m.radial_segments = 24
	m.rings = 1
	body.mesh = m
	body.position.y = 0.0475
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.86, 0.47, 0.16)       # the warm orange of 60s melamine
	mat.roughness = 0.35
	mat.metallic_specular = 0.6
	body.material_override = mat
	root.add_child(body)
	var band := MeshInstance3D.new()
	var bm := CylinderMesh.new()
	bm.top_radius = 0.0376
	bm.bottom_radius = 0.0368
	bm.height = 0.009
	bm.radial_segments = 24
	band.mesh = bm
	band.position.y = 0.083
	var bmat := StandardMaterial3D.new()
	bmat.albedo_color = Color(0.55, 0.26, 0.08)
	bmat.roughness = 0.4
	band.material_override = bmat
	root.add_child(band)
	var drink := MeshInstance3D.new()
	var dm := CylinderMesh.new()
	dm.top_radius = 0.034
	dm.bottom_radius = 0.034
	dm.height = 0.002
	dm.radial_segments = 24
	drink.mesh = dm
	drink.position.y = 0.086
	var dmat := StandardMaterial3D.new()
	dmat.albedo_color = Color(0.16, 0.08, 0.04)       # coffee
	dmat.roughness = 0.15
	drink.material_override = dmat
	root.add_child(drink)
	for mi in [body, band, drink]:
		(mi as MeshInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	return root


# ---- REV 168 (CLAUDE.md item 11): the phaser -----------------------------------------------------
## Glen's TOS phaser (REV 615: assets/models/props/phaser_tos/ - built from the Unimatrix Red kit Glen has
## printed and built ten of; docs/systems/phaser-prop.md. The old phaser.glb is no longer used). wear_phaser(true) clips it to the belt at the
## right hip; draw_phaser() takes it out (the hand goes to the holster, it changes hands there, then the
## aim) and holds the aim until holster_phaser() puts it back. The model's own parts say which way is
## which (its "tip" is the muzzle, its "handle" the grip), so it sits right whatever its export axes.
## Its size follows the forearm, like the cup.
const PHASER_MODEL := "res://assets/models/props/phaser_tos/phaser_tos_standard.glb"
const PHASER_MODEL_CLOSEUP := "res://assets/models/props/phaser_tos/phaser_tos_closeup.glb"   # for close-ups (126k tris)
const PHASER_LENGTH := 0.23          # metres, muzzle to back (REV 572: was 0.2 - Glen: "maybe it needs to be bigger"; TOS phaser II size)
var phaser: Node3D = null
var phaser_state := ""               # "", "belt", "hand"
var _phaser_aim_timer: SceneTreeTimer = null

func wear_phaser(on: bool) -> void:
	if on and phaser == null:
		phaser = make_phaser()
		phaser.name = "Phaser"
		_model.add_child(phaser)
		phaser.top_level = true
		phaser_state = "belt"
	elif not on and phaser != null:
		if motion != null:
			motion.phaser_aim(false)
		phaser.queue_free()
		phaser = null
		phaser_state = ""


## Draw: returns how long until the aim is up. Puts the phaser on first if he isn't wearing one.
func draw_phaser() -> float:
	if motion == null:
		return 0.0
	if phaser == null:
		wear_phaser(true)
	if phaser_state == "hand":
		return 0.0
	var d := motion.phaser_draw()
	if d <= 0.0:
		phaser_state = "hand"
		return 0.0
	# the aim takes over just before the draw ends, so one flows into the other
	var my := randi()
	set_meta("_phaser_draw", my)
	get_tree().create_timer(maxf(d - 0.3, 0.05), false).timeout.connect(func() -> void:
		if is_instance_valid(self) and motion != null and get_meta("_phaser_draw", 0) == my and phaser_state == "hand":
			motion.phaser_aim(true))
	return d


func holster_phaser() -> float:
	if motion == null or phaser == null or phaser_state != "hand":
		return 0.0
	set_meta("_phaser_draw", 0)
	var d := motion.phaser_holster()
	if d <= 0.0:
		motion.phaser_aim(false)
		phaser_state = "belt"
	return d


func is_phaser_drawn() -> bool:
	return phaser != null and phaser_state == "hand"


## The muzzle end of the phaser in the world (where a beam would start), or INF.
func phaser_muzzle() -> Vector3:
	if phaser == null or not is_instance_valid(phaser):
		return Vector3.INF
	if phaser.has_meta("muzzle"):
		return phaser.global_transform * (phaser.get_meta("muzzle") as Vector3)
	return phaser.global_transform * Vector3(0.0, 0.0, PHASER_LENGTH * 0.62)


## REV 572: the right hand's grip frame in world space: "fwd" (wrist -> middle knuckle, tipped a touch up
## like a pistol held at aim), "down" (index knuckle -> little-finger knuckle, square to fwd), "palm" (the
## way the palm faces) and "at" (where the top of a pistol grip sits in the palm). Empty if the hand has
## no finger bones (non-Daz rigs fall back to the forearm placement).
func _hand_grip_frame(wrist: Vector3, along: Vector3, k: float) -> Dictionary:
	var bm := _finger_bone("rmid1")
	var bi := _finger_bone("rindex1")
	var bp := _finger_bone("rpinky1")
	if bm < 0 or bi < 0 or bp < 0:
		return {}
	var g := _skel.global_transform
	var mid := g * _skel.get_bone_global_pose(bm).origin
	var idx := g * _skel.get_bone_global_pose(bi).origin
	var pky := g * _skel.get_bone_global_pose(bp).origin
	var fwd := (mid - wrist)
	if fwd.length() < 0.001:
		return {}
	fwd = fwd.normalized().lerp(along, 0.35).normalized()
	var down := pky - idx
	down = down - fwd * fwd.dot(down)
	if down.length() < 0.0005:
		return {}
	down = down.normalized()
	var palm := down.cross(fwd).normalized()       # right hand: the palm faces this way
	var at := wrist.lerp(idx, 0.6) + palm * PHASER_PALM_IN * k - down * PHASER_GRIP_RISE * k
	return {"fwd": fwd, "down": down, "palm": palm, "at": at}


const PHASER_PALM_IN := 0.018      # REV 572: the grip's middle this far in from the bones toward the palm
const PHASER_GRIP_RISE := 0.034    # and this far toward the thumb side (the barrel rests on the web of the hand; REV 573: was 0.004 - Glen: "needs to come up a bit")
## REV 572: finger curls around the grip, degrees per joint (knuckle, middle, end); the index finger is
## on the trigger, the thumb lies along the far side.
const GRIP_CURL := {
	"rindex": [38.0, 55.0, 30.0],
	"rmid": [72.0, 85.0, 55.0],
	"rring": [76.0, 85.0, 55.0],
	"rpinky": [80.0, 80.0, 50.0],
	"rthumb": [0.0, 25.0, 30.0],
}
var _finger_bones := {}


func _finger_bone(nm: String) -> int:
	if _finger_bones.has(nm):
		return int(_finger_bones[nm])
	var b := -1
	# REV 751: Genesis 9 spells them with an underscore ("rmid1" -> "r_mid1")
	var g9 := nm.left(1) + "_" + nm.substr(1)
	for i in _skel.get_bone_count():
		var low := _skel.get_bone_name(i).to_lower()
		if low == nm or low == g9:
			b = i
			break
	_finger_bones[nm] = b
	return b


## Bends each finger joint toward the palm until it is GRIP_CURL degrees from the one before it, whatever
## the clip had (the clip's frame is written first each frame, so this never builds up).
func _close_fingers_on_grip(hand_fwd: Vector3, down: Vector3) -> void:
	var inv := _skel.global_transform.basis.inverse()
	var fwd_s := (inv * hand_fwd).normalized()
	var palm_s := (inv * down.cross(hand_fwd)).normalized()
	for f in GRIP_CURL.keys():
		var angles: Array = GRIP_CURL[f]
		var chain: Array[int] = []
		for j in 3:
			chain.append(_finger_bone(String(f) + str(j + 1)))
		if chain[0] < 0:
			continue
		var parent_dir := fwd_s
		var palm_ref := (palm_s - parent_dir * parent_dir.dot(palm_s)).normalized()
		var last_dir := Vector3.ZERO
		for j in 3:
			var b: int = chain[j]
			if b < 0:
				break
			var gp := _skel.get_bone_global_pose(b)
			var dir: Vector3
			if j < 2 and chain[j + 1] >= 0:
				dir = _skel.get_bone_global_pose(chain[j + 1]).origin - gp.origin
			else:
				dir = last_dir
			if dir.length() < 0.00001:
				break
			dir = dir.normalized()
			var current := atan2(dir.dot(palm_ref), dir.dot(parent_dir))
			var target := deg_to_rad(float(angles[j]))
			var axis := parent_dir.cross(palm_ref).normalized()
			var delta := target - current
			if absf(delta) > 0.001 and float(angles[j]) > 0.0:
				var newb := Basis(axis, delta) * gp.basis.orthonormalized()
				var par := _skel.get_bone_parent(b)
				var pb := _skel.get_bone_global_pose(par).basis.orthonormalized() if par >= 0 else Basis.IDENTITY
				_skel.set_bone_pose_rotation(b, (pb.inverse() * newb).get_rotation_quaternion())
				dir = Basis(axis, delta) * dir
			last_dir = dir
			parent_dir = dir
			palm_ref = axis.cross(parent_dir).normalized()


func _place_phaser() -> void:
	if phaser == null or not is_instance_valid(phaser) or _skel == null:
		return
	var bh: int = int(_bone.get("ha_r", -1))
	var bf: int = int(_bone.get("la_r", -1))
	var bt: int = int(_bone.get("ul_r", -1))
	var bk: int = int(_bone.get("ll_r", -1))
	var bto: int = int(_bone.get("torso", -1))
	if bh < 0 or bf < 0 or bt < 0 or bk < 0:
		phaser.visible = false
		return
	var g := _skel.global_transform
	var hand := g * _skel.get_bone_global_pose(bh).origin
	var elbow := g * _skel.get_bone_global_pose(bf).origin
	var fore := hand - elbow
	var k := maxf(fore.length(), 0.0001) / 0.26
	var mb := _model.global_transform.basis.orthonormalized()
	var body_fwd := mb.z
	var body_right := -mb.x          # the figures face +Z, their right is -X
	if phaser_state == "hand":
		var grip := _hand_grip_frame(hand, fore.normalized(), k)
		if grip.is_empty():
			var along := fore.normalized()
			var fwd0 := along.lerp(body_fwd, 0.15).normalized()
			var up0 := (Vector3.UP - fwd0 * fwd0.dot(Vector3.UP))
			up0 = up0.normalized() if up0.length() > 0.01 else mb.y
			phaser.global_transform = Transform3D(Basis(up0.cross(fwd0).normalized(), up0, fwd0).scaled(Vector3.ONE * k), hand + along * 0.045 * k)
		else:
			# REV 572 (Glen: "the phaser doesn't sit correctly in mccoy's hands"): placed from the HAND, not the
			# forearm - barrel along the hand, the grip down the index-to-little-finger line (how a pistol
			# grip lies in a hand), its top in the palm just behind the knuckles - and the fingers close on it
			var fwd: Vector3 = grip["fwd"]
			var down: Vector3 = grip["down"]
			var up := -down
			var b := Basis(up.cross(fwd).normalized(), up, fwd).scaled(Vector3.ONE * k)
			phaser.global_transform = Transform3D(b, grip["at"])
			_close_fingers_on_grip(fwd, down)
	else:
		# on the belt at the right hip: just below the hip joint, out on the side, a touch forward;
		# muzzle pointing down and slightly forward, grip up and back
		var hip := g * _skel.get_bone_global_pose(bt).origin
		var knee := g * _skel.get_bone_global_pose(bk).origin
		var thigh := (knee - hip).normalized()
		var spot := hip + thigh * 0.06 * k + body_right * 0.1 * k + body_fwd * 0.04 * k
		if bto >= 0:
			var waist := g * _skel.get_bone_global_pose(bto).origin
			spot.y = maxf(spot.y, waist.y - 0.1 * k)
		var fwd2 := (thigh * 0.85 + body_fwd * 0.15).normalized()
		var up2 := (-body_fwd - fwd2 * fwd2.dot(-body_fwd)).normalized()
		var x2 := up2.cross(fwd2).normalized()
		phaser.global_transform = Transform3D(Basis(x2, up2, fwd2).scaled(Vector3.ONE * k), spot)
	phaser.visible = true


## The phaser, turned so that +Z is the muzzle, -Y is the grip, the grip is at the origin and it is
## PHASER_LENGTH long. A plain stand-in shape if the model is missing.
static func make_phaser() -> Node3D:
	var root := Node3D.new()
	var packed: PackedScene = load(PHASER_MODEL) if ResourceLoader.exists(PHASER_MODEL) else null
	if packed == null:
		var box := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = Vector3(0.035, 0.03, PHASER_LENGTH)
		box.mesh = bm
		box.position = Vector3(0, 0.03, 0.05)
		var grip := MeshInstance3D.new()
		var gm := BoxMesh.new()
		gm.size = Vector3(0.03, 0.08, 0.035)
		grip.mesh = gm
		grip.position = Vector3(0, -0.02, 0.0)
		for mi in [box, grip]:
			var mat := StandardMaterial3D.new()
			mat.albedo_color = Color(0.12, 0.12, 0.13)
			(mi as MeshInstance3D).material_override = mat
			root.add_child(mi)
		return root
	var model := packed.instantiate() as Node3D
	var holder := Node3D.new()
	holder.add_child(model)
	root.add_child(holder)
	# measure its parts (in the model's own space)
	var all := AABB()
	var tip := AABB()
	var handle := AABB()
	var first := true
	for mi in model.find_children("*", "MeshInstance3D", true, false):
		var m := mi as MeshInstance3D
		if m.mesh == null:
			continue
		var xf := _xf_to(m, model)
		var box := xf * m.mesh.get_aabb()
		all = box if first else all.merge(box)
		first = false
		var path := String(m.get_parent().name).to_lower() + "/" + String(m.name).to_lower()
		if "tip" in path:
			tip = box if tip.size == Vector3.ZERO else tip.merge(box)
		elif "handle" in path:
			handle = box if handle.size == Vector3.ZERO else handle.merge(box)
	if first:
		return root
	var c := all.get_center()
	var fwd: Vector3
	if tip.size != Vector3.ZERO:
		fwd = (tip.get_center() - c).normalized()
	else:
		var s := all.size
		fwd = Vector3.RIGHT if s.x >= s.y and s.x >= s.z else (Vector3.UP if s.y >= s.z else Vector3.BACK)
	var down := Vector3.DOWN
	var grip := c
	if handle.size != Vector3.ZERO:
		grip = handle.get_center()
		down = (grip - c)
	down = (down - fwd * fwd.dot(down))
	down = down.normalized() if down.length() > 0.0001 else Vector3.DOWN
	var up := -down
	var x := up.cross(fwd).normalized()
	# model space -> phaser space: rows are the new axes
	var to_ph := Basis(x, up, fwd).transposed()
	var length := absf((all.size * Vector3(absf(fwd.x), absf(fwd.y), absf(fwd.z))).x) \
		+ absf((all.size * Vector3(absf(fwd.x), absf(fwd.y), absf(fwd.z))).y) \
		+ absf((all.size * Vector3(absf(fwd.x), absf(fwd.y), absf(fwd.z))).z)
	var sc := PHASER_LENGTH / maxf(length, 0.0001)
	# the grip's top (where the hand closes) at the origin
	var grip_top := grip + up * (handle.size.length() * 0.25 if handle.size != Vector3.ZERO else 0.0)
	holder.transform = Transform3D(to_ph.scaled(Vector3.ONE * sc), Vector3.ZERO)
	holder.transform.origin = -(holder.transform.basis * grip_top)
	# REV 741 (Glen: the beam "starts in mid-air"): the muzzle is the FRONT of the emitter itself, measured, not a
	# guess along the axis from the grip (the barrel sits well above the grip's top)
	if tip.size != Vector3.ZERO:
		var front := tip.get_center()
		var half := absf(tip.size.x * fwd.x) + absf(tip.size.y * fwd.y) + absf(tip.size.z * fwd.z)
		root.set_meta("muzzle", holder.transform * (front + fwd * half * 0.5))
	return root


static func _xf_to(n: Node3D, ancestor: Node3D) -> Transform3D:
	var xf := Transform3D.IDENTITY
	var cur: Node = n
	while cur != null and cur != ancestor:
		if cur is Node3D:
			xf = (cur as Node3D).transform * xf
		cur = cur.get_parent()
	return xf


# ---- the tricorder ---------------------------------------------------------------------
## REV 155: Glen's tricorder model on a shoulder strap (SlungEquipment). Selecting the tricorder slings
## it on (hanging at the right hip, strap over the left shoulder); scanning lifts it into his hands as
## the arms come up and lowers it back onto the strap after. Without the model file, the old
## code-made box is used instead.

const TRICORDER_MODEL := "res://assets/models/props/tricorder.glb"
## REV 591: the TOS tricorder built from Glen's kit (docs/systems/tricorder-prop.md), STANDARD version.
## Its front is +Z; SlungEquipment wants the face along +X, so it's wrapped and turned a quarter turn.
## The hood (HoodPivot) flips open as it comes up to scan - see SlungEquipment.HOOD_*.
const TRICORDER_TOS := "res://assets/models/props/tricorder_tos/tricorder_tos_standard.glb"
signal scan_lowered()
var slung: SlungEquipment = null
var _sling_want := false
var _scan_id := 0
var _scanning := false


## REV 293: true while a tricorder scan is running (raised, scanning or still being lowered).
## InteractionManager waits on this instead of reading the private flag.
func is_scanning() -> bool:
	return _scanning


## Show or hide the slung tricorder (strap and all) while not scanning.
func set_slung(on: bool) -> void:
	_sling_want = on
	if on:
		_ensure_slung()


func is_slung() -> bool:
	return _sling_want


func _ensure_slung() -> void:
	if slung != null or _model == null or _skel == null:
		return
	var scene: PackedScene = null
	var fallback: Node3D = null
	if ResourceLoader.exists(TRICORDER_TOS):
		var tos: PackedScene = load(TRICORDER_TOS)
		if tos != null:
			fallback = Node3D.new()
			fallback.name = "TricorderTOS"
			var inst: Node3D = tos.instantiate()
			inst.rotation_degrees = Vector3(0, 90, 0)      # front (+Z) -> +X, the face SlungEquipment expects
			fallback.add_child(inst)
	if fallback == null:
		scene = load(TRICORDER_MODEL) if ResourceLoader.exists(TRICORDER_MODEL) else null
	if scene == null and fallback == null:
		fallback = Node3D.new()
		var box := _make_tricorder()
		# the box lies flat (long side along Z): stand it up - long side Y, screen side +X
		box.basis = Basis(Vector3(0, 0, 1), Vector3(1, 0, 0), Vector3(0, 1, 0))
		fallback.add_child(box)
	slung = SlungEquipment.new()
	_model.add_child(slung)
	slung.setup(self, scene, fallback)


## Scan with the tricorder for `seconds` (fire and forget; see scan_action to wait for it).
func scan(seconds := 2.8) -> void:
	scan_action(seconds)


## The whole scan: the arms come up (the tricorder rises from the strap into his hands), at least
## `min_seconds` of scanning - longer while `keep_going` returns true, up to `max_seconds` - then the
## arms come down and it settles back on the strap. Returns once it is back on the strap.
func scan_action(min_seconds := 2.8, keep_going: Callable = Callable(), max_seconds := 12.0) -> void:
	if motion == null:
		return
	_ensure_slung()
	_scanning = true
	motion.hold_loop("tablet", 1.0)
	_scan_id += 1
	var my := _scan_id
	var t := 0.0
	while t < max_seconds:
		await get_tree().process_frame
		if my != _scan_id:
			return
		t += get_process_delta_time()
		if t >= min_seconds and (not keep_going.is_valid() or not bool(keep_going.call())):
			break
	if motion != null and motion.talk_layer != null and motion.talk_layer.id == "tablet":
		motion.stop_talk()
	# wait for the arms to come down (the tricorder follows them back onto the strap)
	var w := 0.0
	while w < 1.5 and motion != null and motion.talk_layer != null and motion.talk_layer.id == "tablet" \
			and motion.talk_layer.fade > 0.02:
		await get_tree().process_frame
		w += get_process_delta_time()
	if my == _scan_id:
		_scanning = false
		scan_lowered.emit()


func _place_tricorder() -> void:
	var fade := 0.0
	if motion != null and motion.talk_layer != null and motion.talk_layer.id == "tablet":
		fade = motion.talk_layer.fade
	var show := _sling_want or _scanning or fade > 0.02
	if slung == null:
		if not show:
			return
		_ensure_slung()
		if slung == null:
			return
	slung.visible = show
	if not show:
		_scan_sound(false)
		return
	# the arms rise over the first part of the blend: the tricorder leaves the strap with them
	slung.hold = clampf((fade - 0.15) / 0.7, 0.0, 1.0)
	slung.update_now()
	# REV 169 (item 15): the tricorder sounds while it is up in his hands, until the arms lower it
	var lowering := motion == null or motion.talk_layer == null or motion.talk_layer.id != "tablet" \
			or motion.talk_layer.fade_to < 0.5
	_scan_sound(_scanning and slung.hold > 0.75 and not lowering)


## REV 169: the scan sound plays from the tricorder (see TricorderSound).
var _tricorder_sound: TricorderSound = null

func _scan_sound(on: bool) -> void:
	if _tricorder_sound == null:
		if not on or _model == null:
			return
		_tricorder_sound = TricorderSound.new()
		_tricorder_sound.name = "TricorderSound"
		_model.add_child(_tricorder_sound)
	if on and slung != null:
		var at := slung.device_position()
		if at != Vector3.INF:
			_tricorder_sound.global_position = at
	_tricorder_sound.set_active(on)


## A TOS-style tricorder: a black box with a silver top, a small dark screen and a row of lights.
static func _make_tricorder() -> Node3D:
	var root := Node3D.new()
	root.name = "Tricorder"
	var parts := [
		[Vector3(0.11, 0.05, 0.16), Vector3(0, 0, 0), Color(0.04, 0.04, 0.045), 0.55, 0.1],
		[Vector3(0.112, 0.008, 0.162), Vector3(0, 0.029, 0), Color(0.72, 0.73, 0.75), 0.3, 0.8],
		[Vector3(0.06, 0.004, 0.045), Vector3(0, 0.034, 0.035), Color(0.08, 0.12, 0.1), 0.2, 0.0],
		[Vector3(0.012, 0.006, 0.012), Vector3(-0.03, 0.035, -0.03), Color(0.9, 0.2, 0.15), 0.4, 0.0],
		[Vector3(0.012, 0.006, 0.012), Vector3(-0.01, 0.035, -0.03), Color(0.95, 0.75, 0.2), 0.4, 0.0],
		[Vector3(0.012, 0.006, 0.012), Vector3(0.01, 0.035, -0.03), Color(0.25, 0.75, 0.3), 0.4, 0.0],
	]
	for p in parts:
		var mi := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = p[0]
		mi.mesh = bm
		mi.position = p[1]
		var m := StandardMaterial3D.new()
		m.albedo_color = p[2]
		m.roughness = p[3]
		m.metallic = p[4]
		if p[2].r > 0.85 or p[2].g > 0.7:
			m.emission_enabled = true
			m.emission = p[2]
			m.emission_energy_multiplier = 0.6
		mi.material_override = m
		root.add_child(mi)
	return root
