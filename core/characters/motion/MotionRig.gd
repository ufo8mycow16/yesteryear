class_name MotionRig
extends RefCounted
## REV 129: copies a pose from the Mixamo skeleton the clips were made on onto a character's own
## skeleton - Daz Genesis 8 (McCoy, and the crew as they come over from Daz) or the captain's-kit
## stand-ins (everyone else for now).
##
## How: each Mixamo bone's turn away from its rest pose (in the body's space) is given to the matching
## bone of the character. The two skeletons don't rest the same way - Mixamo stands in a T-pose, Daz
## and the kit in an A-pose with different hand and finger angles - so first each limb bone of the
## character is "lined up" with its Mixamo partner (same direction, and for the hands the same palm
## turn); the turns are applied on top of that lined-up pose. The spine, neck and head keep their own
## natural set (only their turns are copied).
##
## Genesis 8 has separate twist bones in the upper arms, forearms and thighs; the twisting part of a
## turn goes to those, the way Daz's own posing does, so wrists and shoulders don't pinch.
##
## REV 751: Daz Genesis 9 too (kind "daz9"), alongside Genesis 8. G9's limbs are built differently: the
## upper arm, forearm and thigh bones carry NO skin at all - each has two twist helpers hanging off its
## side (not in the chain), one near each end, and those carry the skin. So the main bones take their
## whole turn (the elbow, hand and knee land exactly where the clip puts them, children unchanged), and
## each helper is wound back so its skin keeps only its share of the twist (G9_TWIST) - a gradual twist
## along the limb instead of the whole sleeve of skin turning at the shoulder. The hand's own twist is
## shared down the forearm's helpers too, as a real forearm does it. Every clip (Mixamo and the
## converted Daz ones) plays on G9 through the same map, so nothing has to be converted again.

## Mixamo bone -> name of the character's bone (Daz Genesis 8). Fingers are added below.
const DAZ := {
	"Hips": "hip", "Spine": "abdomenLower", "Spine1": "chestLower", "Spine2": "chestUpper",
	"Neck": "neckLower", "Head": "head",
	"LeftShoulder": "lCollar", "LeftArm": "lShldrBend", "LeftForeArm": "lForearmBend", "LeftHand": "lHand",
	"RightShoulder": "rCollar", "RightArm": "rShldrBend", "RightForeArm": "rForearmBend", "RightHand": "rHand",
	"LeftUpLeg": "lThighBend", "LeftLeg": "lShin", "LeftFoot": "lFoot", "LeftToeBase": "lToe",
	"RightUpLeg": "rThighBend", "RightLeg": "rShin", "RightFoot": "rFoot", "RightToeBase": "rToe",
}
## Genesis 8 bones that sit between two copied ones and take half of each one's turn.
const DAZ_BETWEEN := {"abdomenUpper": ["Spine", "Spine1"], "neckUpper": ["Neck", "Head"]}
## bend bone -> its twist bone
const DAZ_TWIST := {"lShldrBend": "lShldrTwist", "rShldrBend": "rShldrTwist", "lForearmBend": "lForearmTwist",
	"rForearmBend": "rForearmTwist", "lThighBend": "lThighTwist", "rThighBend": "rThighTwist"}
## the hand's own twist moves up into the forearm's twist bone
const DAZ_WRIST := {"lHand": "lForearmTwist", "rHand": "rForearmTwist"}

## REV 751: Mixamo bone -> Daz Genesis 9 bone (one unisex figure; fingers added in setup: l_thumb1, l_index1,
## l_mid1, l_ring1, l_pinky1 ...). G9's spine has four bones and its neck two, like G8's under other names.
const G9 := {
	"Hips": "hip", "Spine": "spine1", "Spine1": "spine3", "Spine2": "spine4",
	"Neck": "neck1", "Head": "head",
	"LeftShoulder": "l_shoulder", "LeftArm": "l_upperarm", "LeftForeArm": "l_forearm", "LeftHand": "l_hand",
	"RightShoulder": "r_shoulder", "RightArm": "r_upperarm", "RightForeArm": "r_forearm", "RightHand": "r_hand",
	"LeftUpLeg": "l_thigh", "LeftLeg": "l_shin", "LeftFoot": "l_foot", "LeftToeBase": "l_toes",
	"RightUpLeg": "r_thigh", "RightLeg": "r_shin", "RightFoot": "r_foot", "RightToeBase": "r_toes",
}
## G9 bones between two copied ones, taking half of each one's turn (as DAZ_BETWEEN)
const G9_BETWEEN := {"spine2": ["Spine", "Spine1"], "neck2": ["Neck", "Head"]}
## REV 751: G9's twist helpers. main bone -> {"along": the child it points at (its twist axis), "twists":
## [[helper, share of the main bone's twist its skin keeps], ...]}. Shares measured from the blank G9
## export (assets/models/characters/_source/genesis_9_female.fbx): each helper's skin centre along the bone
## (twist1 a third of the way down the upper arm, twist2 four-fifths - near the elbow, where the skin must
## match the forearm's). Raise a share if a limb's skin looks too stiff when it turns, lower it if it
## wrings like a towel.
const G9_TWIST := {
	"l_upperarm": {"along": "l_forearm", "twists": [["l_upperarmtwist1", 0.35], ["l_upperarmtwist2", 0.8]]},
	"r_upperarm": {"along": "r_forearm", "twists": [["r_upperarmtwist1", 0.35], ["r_upperarmtwist2", 0.8]]},
	"l_forearm": {"along": "l_hand", "twists": [["l_forearmtwist1", 0.3], ["l_forearmtwist2", 0.9]], "hand": "l_hand"},
	"r_forearm": {"along": "r_hand", "twists": [["r_forearmtwist1", 0.3], ["r_forearmtwist2", 0.9]], "hand": "r_hand"},
	"l_thigh": {"along": "l_shin", "twists": [["l_thightwist1", 0.35], ["l_thightwist2", 0.85]]},
	"r_thigh": {"along": "r_shin", "twists": [["r_thightwist1", 0.35], ["r_thightwist2", 0.85]]},
}

## The captain's-kit stand-ins (bone names lower-cased, "." -> "_", matched by how they start).
const KIT := {
	"Hips": "torso_", "Spine2": "chest_", "Neck": "neck_", "Head": "head_",
	"LeftShoulder": "shoulder_l_", "LeftArm": "u_a_l_", "LeftForeArm": "l_a_l_", "LeftHand": "middlefingerbase_l_",
	"RightShoulder": "shoulder_r_", "RightArm": "u_a_r_", "RightForeArm": "l_a_r_", "RightHand": "middlefingerbase_r_",
	"LeftUpLeg": "u_l_l_", "LeftLeg": "l_l_l_", "LeftFoot": "foot_l_", "LeftToeBase": "toes_l_",
	"RightUpLeg": "u_l_r_", "RightLeg": "l_l_r_", "RightFoot": "foot_r_", "RightToeBase": "toes_r_",
}

## Which Mixamo joint each bone points at (for lining the limbs up).
const TIP := {
	"LeftShoulder": "LeftArm", "LeftArm": "LeftForeArm", "LeftForeArm": "LeftHand", "LeftHand": "LeftHandMiddle1",
	"RightShoulder": "RightArm", "RightArm": "RightForeArm", "RightForeArm": "RightHand", "RightHand": "RightHandMiddle1",
	"LeftUpLeg": "LeftLeg", "LeftLeg": "LeftFoot", "LeftFoot": "LeftToeBase",
	"RightUpLeg": "RightLeg", "RightLeg": "RightFoot", "RightFoot": "RightToeBase",
}
## Bones that are lined up (limbs). The spine, neck and head are not.
const LIMB_ROOTS := ["LeftShoulder", "RightShoulder", "LeftUpLeg", "RightUpLeg"]

var ok := false
var kind := ""                      # "daz" (Genesis 8) | "daz9" (Genesis 9, REV 751) | "kit"
## REV 751: G9 twist helpers, worked out after each pose: [main bone, axis (main bone's frame),
## [[helper, share, helper rest], ...], hand bone or -1, hand twist axis (hand's frame)]
var _g9_tw: Array = []
var skel: Skeleton3D
var src: MotionClips.SrcSkel
var _c := Quaternion.IDENTITY       # Mixamo body space -> this skeleton's space
var _ops: Array = []                # [bone, op, data...] parents first
var _rest_l: Array[Quaternion] = []
var _g: Array[Quaternion] = []      # this skeleton's rotations (skeleton space), per bone, this frame
var _m: Array[Quaternion] = []      # lined-up rest rotations
var _hips := -1
var _hips_rest := Vector3.ZERO
var _hips_parent_q := Quaternion.IDENTITY
var _ratio := 1.0
var _unit := 1.0                    # character metres -> this skeleton's units
var _feet: Array = []               # REV 146: [bone, standing height] for the ankles and toes
## REV 146: true (default) keeps the feet from going below the floor after each pose.
var keep_feet_on_floor := true
var _src_of := {}                   # target bone -> Mixamo bone
var written: PackedInt32Array = []  # bones this rig writes each frame
var target_of := {}                 # Mixamo name -> target bone (for others to ask)


## to_model: this skeleton's space -> the character's own space (the CharacterAnimator works it out).
func setup(sk: Skeleton3D, to_model: Basis) -> bool:
	skel = sk
	src = MotionClips.ref()
	if src == null or sk == null:
		return false
	var by := {}
	for i in sk.get_bone_count():
		by[sk.get_bone_name(i)] = i
	var map := {}
	if by.has("hip") and by.has("l_thigh") and by.has("l_upperarm") and by.has("l_forearm"):
		# REV 751: Daz Genesis 9
		kind = "daz9"
		map = G9.duplicate()
		for side in ["Left", "Right"]:
			var s := "l" if side == "Left" else "r"
			for f in [["Thumb", "thumb"], ["Index", "index"], ["Middle", "mid"], ["Ring", "ring"], ["Pinky", "pinky"]]:
				for k in [1, 2, 3]:
					map["%sHand%s%d" % [side, f[0], k]] = "%s_%s%d" % [s, f[1], k]
		for mx in map.keys():
			if not by.has(map[mx]):
				map.erase(mx)
		for mx in map.keys():
			map[mx] = by[map[mx]]
	elif by.has("hip") and by.has("lThighBend") and by.has("lShldrBend"):
		kind = "daz"
		map = DAZ.duplicate()
		for side in ["Left", "Right"]:
			var s := "l" if side == "Left" else "r"
			for f in [["Thumb", "Thumb"], ["Index", "Index"], ["Middle", "Mid"], ["Ring", "Ring"], ["Pinky", "Pinky"]]:
				for k in [1, 2, 3]:
					map["%sHand%s%d" % [side, f[0], k]] = "%s%s%d" % [s, f[1], k]
		for mx in map.keys():
			if not by.has(map[mx]):
				map.erase(mx)
		for mx in map.keys():
			map[mx] = by[map[mx]]
	else:
		var lower := {}
		for i in sk.get_bone_count():
			lower[i] = sk.get_bone_name(i).to_lower().replace(".", "_")
		for mx in KIT.keys():
			for i in lower.keys():
				if String(lower[i]).begins_with(String(KIT[mx])):
					map[mx] = int(i)
					break
		if not (map.has("Hips") and map.has("LeftUpLeg") and map.has("LeftArm")):
			return false
		kind = "kit"
	var n := sk.get_bone_count()
	_rest_l.resize(n)
	_g.resize(n)
	_m.resize(n)
	var rest_g: Array[Quaternion] = []
	rest_g.resize(n)
	var rest_gp := PackedVector3Array()
	rest_gp.resize(n)
	for i in n:
		_rest_l[i] = sk.get_bone_rest(i).basis.get_rotation_quaternion()
	for i in _order(sk):
		var p := sk.get_bone_parent(i)
		var r := sk.get_bone_rest(i)
		rest_g[i] = _rest_l[i] if p < 0 else (rest_g[p] * _rest_l[i]).normalized()
		rest_gp[i] = r.origin if p < 0 else rest_gp[p] + rest_g[p] * r.origin
	_c = to_model.orthonormalized().get_rotation_quaternion().inverse()   # Mixamo's body space is the character's space
	_unit = 1.0 / maxf(to_model.get_scale().y, 0.0001)

	# which bones to work on: the copied ones, the in-between ones, the twist bones and everything above them
	var role := {}          # bone -> ["map", mixamo] | ["between", a, b] | ["twist"]
	for mx in map.keys():
		role[int(map[mx])] = ["map", src.bone(mx)]
		_src_of[int(map[mx])] = src.bone(mx)
		target_of[mx] = int(map[mx])
	if kind == "daz":
		for nm in DAZ_BETWEEN.keys():
			if by.has(nm):
				var pair: Array = DAZ_BETWEEN[nm]
				role[int(by[nm])] = ["between", src.bone(pair[0]), src.bone(pair[1])]
		for bend in DAZ_TWIST.keys():
			if by.has(DAZ_TWIST[bend]) and by.has(bend):
				role[int(by[DAZ_TWIST[bend]])] = ["twist"]
	elif kind == "daz9":
		for nm in G9_BETWEEN.keys():
			if by.has(nm):
				var pair: Array = G9_BETWEEN[nm]
				role[int(by[nm])] = ["between", src.bone(pair[0]), src.bone(pair[1])]
	var need := {}
	for b in role.keys():
		var x: int = b
		while x >= 0 and not need.has(x):
			need[x] = true
			x = sk.get_bone_parent(x)

	# line the limbs up with Mixamo's (in the character's space)
	var align := {}          # target bone -> extra turn
	for i in _order(sk):
		if not need.has(i):
			continue
		var p := sk.get_bone_parent(i)
		var inherit := Quaternion.IDENTITY
		var x := p
		while x >= 0:
			if align.has(x):
				inherit = align[x]
				break
			x = sk.get_bone_parent(x)
		var a := inherit
		if role.has(i) and role[i][0] == "map":
			var mxb: int = role[i][1]
			var mx := src.names[mxb]
			var in_limb := LIMB_ROOTS.has(mx) or align.has(p) or _limb_parent(sk, i, align)
			if in_limb:
				a = inherit
				var tip_mx := String(TIP.get(mx, ""))
				if tip_mx == "" and mx.contains("Hand") and mx.right(1).is_valid_int():
					var k := int(mx.right(1))
					if k < 3:
						tip_mx = mx.left(mx.length() - 1) + str(k + 1)
				if tip_mx != "" and map.has(tip_mx):
					var tb: int = map[tip_mx]
					var dt: Vector3 = (a * (rest_gp[tb] - rest_gp[i])).normalized()
					var ds: Vector3 = (_c * (src.rest_gp[src.bone(tip_mx)] - src.rest_gp[mxb])).normalized()
					if dt.length() > 0.5 and ds.length() > 0.5:
						a = Quaternion(dt, ds) * a
						# hands: also match how the palm is turned (index knuckle -> little-finger knuckle)
						if mx.ends_with("Hand"):
							var sd := mx.replace("Hand", "")
							var i1 := String(sd + "HandIndex1")
							var p1 := String(sd + "HandPinky1")
							if map.has(i1) and map.has(p1):
								var st: Vector3 = a * (rest_gp[map[p1]] - rest_gp[map[i1]])
								var ss: Vector3 = _c * (src.rest_gp[src.bone(p1)] - src.rest_gp[src.bone(i1)])
								st = (st - ds * st.dot(ds)).normalized()
								ss = (ss - ds * ss.dot(ds)).normalized()
								if st.length() > 0.5 and ss.length() > 0.5:
									a = Quaternion(st, ss) * a
				elif mx.contains("Hand") and mx.right(1) == "3":
					a = inherit
				align[i] = a
		_m[i] = (a * rest_g[i]).normalized()

	# the work list, parents first
	for i in _order(sk):
		if not need.has(i):
			continue
		if role.has(i):
			_ops.append([i] + role[i])
		else:
			_ops.append([i, "rest"])
		written.append(i)
	for i in n:
		var p := sk.get_bone_parent(i)
		if p < 0:
			_g[i] = _rest_l[i]
	# twist axes
	for op in _ops:
		var b: int = op[0]
		var nm := sk.get_bone_name(b)
		if DAZ_TWIST.has(nm) and by.has(DAZ_TWIST[nm]):
			op.append(by[DAZ_TWIST[nm]])
			op.append(sk.get_bone_rest(int(by[DAZ_TWIST[nm]])).origin.normalized())
		elif DAZ_WRIST.has(nm) and by.has(DAZ_WRIST[nm]):
			op.append(-1)
			op.append(by[DAZ_WRIST[nm]])
	# REV 751: Genesis 9's twist helpers (leaves beside the chain - nothing hangs off them)
	_g9_tw.clear()
	if kind == "daz9":
		for main in G9_TWIST.keys():
			var e: Dictionary = G9_TWIST[main]
			if not by.has(main) or not by.has(String(e["along"])) or not need.has(int(by[main])):
				continue
			var axis := sk.get_bone_rest(int(by[String(e["along"])])).origin.normalized()
			if axis.length() < 0.5:
				continue
			var helpers := []
			for tw in e["twists"]:
				if by.has(String(tw[0])):
					var hb := int(by[String(tw[0])])
					helpers.append([hb, float(tw[1]), _rest_l[hb]])
					written.append(hb)
			if helpers.is_empty():
				continue
			var hand := int(by.get(String(e.get("hand", "")), -1))
			var hand_axis := Vector3.ZERO
			if hand >= 0:
				hand_axis = (_rest_l[hand].inverse() * sk.get_bone_rest(hand).origin.normalized()).normalized()
			_g9_tw.append([int(by[main]), axis, helpers, hand, hand_axis])
	# hips
	_hips = int(map["Hips"])
	_hips_rest = sk.get_bone_rest(_hips).origin
	var hp := sk.get_bone_parent(_hips)
	_hips_parent_q = rest_g[hp] if hp >= 0 else Quaternion.IDENTITY
	_ratio = rest_gp[_hips].y / maxf(src.rest_gp[src.hips].y, 0.0001)
	if rest_gp[_hips].y <= 0.0:
		_ratio = 1.0
	# REV 146: the ankle and toe bones and how high they are when standing (for keeping feet on the floor)
	_feet.clear()
	for foot_name in ["LeftFoot", "RightFoot", "LeftToeBase", "RightToeBase"]:
		if map.has(foot_name) and int(map[foot_name]) >= 0:
			_feet.append([int(map[foot_name]), rest_gp[int(map[foot_name])].y])
	ok = true
	return true


func _limb_parent(sk: Skeleton3D, i: int, align: Dictionary) -> bool:
	var x := sk.get_bone_parent(i)
	while x >= 0:
		if align.has(x):
			return true
		x = sk.get_bone_parent(x)
	return false


static func _order(sk: Skeleton3D) -> PackedInt32Array:
	var out := PackedInt32Array()
	var done := {}
	var n := sk.get_bone_count()
	while out.size() < n:
		var added := false
		for i in n:
			if done.has(i):
				continue
			var p := sk.get_bone_parent(i)
			if p < 0 or done.has(p):
				out.append(i)
				done[i] = true
				added = true
		if not added:
			break
	return out


## Put a pose on the skeleton. src_g: Mixamo rotations in its skeleton space; hips_p: Mixamo hips
## position (local). hips_offset: extra hips movement in the character's metres (e.g. root motion
## taken out), in the character's space.
func apply(src_g: Array[Quaternion], hips_p: Vector3, hips_offset := Vector3.ZERO) -> void:
	if not ok:
		return
	var d: Array[Quaternion] = []
	d.resize(src_g.size())
	var ci := _c.inverse()
	for i in src_g.size():
		d[i] = _c * (src_g[i] * src.rest_gq[i].inverse()) * ci
	var pending_twist := {}      # twist bone -> extra local turn (from the hand)
	for op in _ops:
		var b: int = op[0]
		var p := skel.get_bone_parent(b)
		var pg := _g[p] if p >= 0 else Quaternion.IDENTITY
		var kind_s: String = op[1]
		var l: Quaternion
		match kind_s:
			"map":
				var want: Quaternion = (d[int(op[2])] * _m[b]).normalized()
				l = (pg.inverse() * want).normalized()
				if op.size() > 4 and int(op[3]) >= 0:
					# a bend bone: its twist goes to the twist bone below it
					var tw_bone: int = op[3]
					var axis: Vector3 = op[4]
					var rel := _rest_l[b].inverse() * l
					var t := _twist(rel, axis)
					l = _rest_l[b] * (rel * t.inverse())
					pending_twist[tw_bone] = [t, false]
				elif op.size() > 4 and int(op[3]) < 0:
					# a hand: its twist about the forearm goes up into the forearm's twist bone
					var ftw: int = op[4]
					var rel := _rest_l[b].inverse() * l
					var axis_p := skel.get_bone_rest(b).origin.normalized()
					var axis_h := _rest_l[b].inverse() * axis_p
					var t := _twist(rel, axis_h)
					var big := _rest_l[b] * t * _rest_l[b].inverse()
					var fl := skel.get_bone_pose_rotation(ftw) * big
					skel.set_bone_pose_rotation(ftw, fl.normalized())
					_g[ftw] = (_g[skel.get_bone_parent(ftw)] * fl).normalized()
					pg = _g[ftw]
					l = _rest_l[b] * (t.inverse() * rel)
			"between":
				var want: Quaternion = (d[int(op[2])].slerp(d[int(op[3])], 0.5) * _m[b]).normalized()
				l = (pg.inverse() * want).normalized()
			"twist":
				var e: Array = pending_twist.get(b, [Quaternion.IDENTITY, false])
				l = ((e[0] as Quaternion) * _rest_l[b]).normalized()
			_:
				l = _rest_l[b]
		if b == _hips:
			var move := _c * hips_p - _c * src.rest_p[src.hips]
			var local_move := _hips_parent_q.inverse() * (move * _ratio)
			var hp := _hips_rest + local_move + _hips_parent_q.inverse() * (_c * hips_offset * _unit)
			skel.set_bone_pose_position(b, hp if hp.is_finite() else _hips_rest)
		if not l.is_finite():
			l = _rest_l[b]
		skel.set_bone_pose_rotation(b, l)
		_g[b] = (pg * l).normalized()
	if not _g9_tw.is_empty():
		_g9_twists()
	if keep_feet_on_floor:
		_feet_on_floor()


## REV 751: Genesis 9's twist helpers. The main bone has taken its whole turn; each helper hanging off it is
## turned back about the bone's length so its skin keeps only its share of the twist. On the forearm the
## hand's own twist (a wrist turn is really the forearm turning) is shared down the helpers as well - the
## hand keeps its full turn, so the skin twists evenly from elbow to wrist.
func _g9_twists() -> void:
	for e in _g9_tw:
		var main: int = e[0]
		var rel := _rest_l[main].inverse() * skel.get_bone_pose_rotation(main)
		var t := _pos_w(_twist(rel, e[1]))
		var hand_t := Quaternion.IDENTITY
		var hand: int = e[3]
		if hand >= 0:
			var hrel := _rest_l[hand].inverse() * skel.get_bone_pose_rotation(hand)
			var th := _twist(hrel, e[4])
			# the hand's twist, about the same axis but seen from the forearm
			hand_t = _pos_w((_rest_l[hand] * th * _rest_l[hand].inverse()).normalized())
		for h in (e[2] as Array):
			var share := float(h[1])
			var back := Quaternion.IDENTITY.slerp(t.inverse(), clampf(1.0 - share, 0.0, 1.0))
			var fwd := Quaternion.IDENTITY.slerp(hand_t, clampf(share, 0.0, 1.0))
			var q := (back * fwd * (h[2] as Quaternion)).normalized()
			if q.is_finite():
				skel.set_bone_pose_rotation(int(h[0]), q)
				_g[int(h[0])] = (_g[main] * q).normalized()


## The same turn with w >= 0, so part of it (slerp from no turn) goes the short way round.
static func _pos_w(q: Quaternion) -> Quaternion:
	return -q if q.w < 0.0 else q


## REV 146 (Glen: Spock's boots sank into the floor, standing and bowling). The animations come
## from Mixamo's body, whose hips sit a little differently and whose legs bend differently from a
## Daz figure's, so a pose could leave a foot a few centimetres under the floor. After every pose:
## if any ankle or toe is lower than it is when standing, lift the whole body by that much. A foot
## lifting off the floor (walking, the bowl's back foot) is left alone; only sinking is corrected.
func _feet_on_floor() -> void:
	if _feet.is_empty() or _hips < 0:
		return
	var sink := 0.0
	for f in _feet:
		var y := skel.get_bone_global_pose(int(f[0])).origin.y
		sink = minf(sink, y - float(f[1]))
	if sink < -0.0001:
		var hp := skel.get_bone_pose_position(_hips) + _hips_parent_q.inverse() * Vector3(0.0, -sink, 0.0)
		if hp.is_finite():
			skel.set_bone_pose_position(_hips, hp)


## The part of q that turns about `axis` (unit, in q's frame).
static func _twist(q: Quaternion, axis: Vector3) -> Quaternion:
	var v := Vector3(q.x, q.y, q.z)
	var pr := axis * v.dot(axis)
	var t := Quaternion(pr.x, pr.y, pr.z, q.w)
	if t.length_squared() < 0.0000001:
		return Quaternion.IDENTITY
	return t.normalized()


## Mixamo skeleton units -> the character's own metres.
func src_to_model() -> float:
	return _ratio / _unit


## The rotation a bone has this frame (skeleton space), as last written.
func bone_global(b: int) -> Quaternion:
	return _g[b]
