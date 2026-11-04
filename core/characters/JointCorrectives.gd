extends Node
class_name JointCorrectives
## REV 240: Daz's joint corrections, driven in game.
## REV 842: Genesis 9 too - its own corrections (body_cbs_*) and flexions from jcm/genesis9_jcm.json, read from
## Glen's library by tools/crew/make_jcm_data.py genesis9. Some G9 helper values are named "<bone>:<id>" there
## (left and right share ids); to this script they're just names.
##
## The importer builds Daz's corrective shapes into every Genesis 8 character (the body and the
## clothes over it - tools/import/daz_character_import.gd). This turns them on, every frame, exactly as
## Daz Studio would: it reads each joint's angle the way Daz measures it (Daz's own axes and rotation
## order per bone, from assets/models/characters/jcm/genesis8<sex>_jcm.json) and runs Daz's own rules
## ("formulas") - e.g. the left elbow bent 75 degrees = pJCMForeArmFwd_75_L fully on. So elbows,
## knees, shoulders, hips, neck, wrists and fingers bulge and crease like flesh, and the biceps, triceps,
## quads, hamstrings and calves flex as the limbs bend.
##
## Added to every Daz character by CharacterFace.attach. REV 293: a model without the shapes
## (background crew, whose rebuilt meshes don't carry them) never gets one - attach_to() checks first,
## frees the unused node and returns null, so nothing is added to the figure. Cost: about 55 joints and 150
## small rules per character per frame; far-off characters update less often, hidden ones not at all.

const DATA_DIR := "res://assets/models/characters/jcm/"
## Corrections change smoothly, so they're worked out every other frame (about 0.2 ms a character on
## average); beyond FAR from the camera only every FAR_EVERY frames.
const EVERY := 2
const FAR := 12.0
const FAR_EVERY := 4
## Shape weights closer than this to what's already set aren't sent again.
const EPS := 0.004

## Daz rotation order "ABC" means A is turned first (innermost): basis = R_C * R_B * R_A, which is
## Godot's order "CBA" (Godot's first letter is outermost).
const ORDER := {
	"XYZ": EULER_ORDER_ZYX, "XZY": EULER_ORDER_YZX, "YXZ": EULER_ORDER_ZXY,
	"YZX": EULER_ORDER_XZY, "ZXY": EULER_ORDER_YXZ, "ZYX": EULER_ORDER_XYZ,
}

static var _data_cache := {}

var enabled := true
var _skel: Skeleton3D
var _root: Node3D
## per joint the rules read: [daz id, bone, parent bone, Daz axes (Basis), its inverse, Godot euler order,
## rest rotation inverse (Quaternion), parent's global rest (Basis), its inverse]
var _joints := []
var _angles := {}        # daz id -> Vector3 (degrees, Daz's x/y/z)
var _vals := {}          # value id -> float (rules' outputs and the master switches)
var _plan := []          # [out id, [sum op lists], [mult op lists], clamp min, clamp max] in evaluation order
var _targets := []       # [shape name, [[MeshInstance3D, shape index], ...]]
var _applied := {}       # shape name -> last weight sent
var _frame := 0


## Give a Daz character its joint corrections (does nothing if its meshes don't carry them).
static func attach_to(wrapper: Node, model_root: Node3D) -> JointCorrectives:
	var jc := JointCorrectives.new()
	jc.name = "JointCorrectives"
	if not jc._setup(model_root):
		jc.free()
		return null
	wrapper.add_child(jc)
	return jc


func _setup(model_root: Node3D) -> bool:
	_root = model_root
	var sks := model_root.find_children("*", "Skeleton3D", true, false)
	if sks.is_empty():
		return false
	_skel = sks[0] as Skeleton3D
	var fig := "genesis8male"
	for m in model_root.find_children("*", "MeshInstance3D", true, false):
		var mn := String(m.name).to_lower()
		if mn.begins_with("genesis8female"):
			fig = "genesis8female"
		elif mn.begins_with("genesis9"):
			fig = "genesis9"   # REV 842: Genesis 9's own rules (one figure for both sexes)
			break
	var data := _load(DATA_DIR + fig + "_jcm.json")
	if data.is_empty():
		return false
	# the shapes on this model
	var by_name := {}
	for sh in data["shapes"]:
		by_name[String(sh["name"])] = String(sh["id"])
	var found := {}
	for m in model_root.find_children("*", "MeshInstance3D", true, false):
		var mi := m as MeshInstance3D
		if mi.mesh == null:
			continue
		for k in mi.get_blend_shape_count():
			var nm := String(mi.mesh.get_blend_shape_name(k))
			if by_name.has(nm):
				if not found.has(nm):
					found[nm] = []
				(found[nm] as Array).append([mi, k])
	if found.is_empty():
		return false
	var id_to_name := {}
	for nm in found:
		id_to_name[by_name[nm]] = nm
	# the joints
	for id in data["bones"]:
		var b: Dictionary = data["bones"][id]
		var bi := _skel.find_bone(String(b["name"]))
		if bi < 0:
			continue
		var o: Array = b["orient"]
		var ob := Basis.from_euler(Vector3(deg_to_rad(o[0]), deg_to_rad(o[1]), deg_to_rad(o[2])), EULER_ORDER_ZYX)
		var parent := _skel.get_bone_parent(bi)
		var prest := _skel.get_bone_global_rest(parent).basis.orthonormalized() if parent >= 0 else Basis()
		_joints.append([String(id), bi, parent, ob, ob.inverse(), int(ORDER.get(String(b["order"]), EULER_ORDER_ZYX)),
			_skel.get_bone_rest(bi).basis.get_rotation_quaternion().inverse(), prest, prest.inverse()])
	for k in data["defaults"]:
		_vals[String(k)] = float(data["defaults"][k])
	# the rules, grouped per output, in an order where every input is worked out before it's used
	var sums := {}
	var mults := {}
	for f in data["formulas"]:
		var out := String(f["out"])
		if String(f.get("stage", "sum")) == "mult":
			if not mults.has(out):
				mults[out] = []
			(mults[out] as Array).append(f["ops"])
		else:
			if not sums.has(out):
				sums[out] = []
			(sums[out] as Array).append(f["ops"])
	var outs := {}
	for o in sums:
		outs[o] = true
	for o in mults:
		outs[o] = true
	var order := []
	var state := {}
	for o in outs:
		_visit(String(o), sums, mults, state, order)
	var clamps: Dictionary = data["clamps"]
	for o in order:
		if _vals.has(o) and not sums.has(o):
			continue   # a master switch (its "rules" only multiply by other switches)
		var c: Array = clamps.get(o, [-INF, INF])
		_plan.append([o, sums.get(o, []), mults.get(o, []), float(c[0]), float(c[1])])
	for id in id_to_name:
		_targets.append([id, id_to_name[id], found[id_to_name[id]]])
	return true


func _visit(o: String, sums: Dictionary, mults: Dictionary, state: Dictionary, order: Array) -> void:
	if state.get(o, 0) != 0:
		return
	state[o] = 1
	for list in [sums.get(o, []), mults.get(o, [])]:
		for ops in list:
			for op in ops:
				if String(op[0]) == "val" and (sums.has(op[1]) or mults.has(op[1])):
					_visit(String(op[1]), sums, mults, state, order)
	state[o] = 2
	order.append(o)


static func _load(path: String) -> Dictionary:
	if _data_cache.has(path):
		return _data_cache[path]
	var d := {}
	if FileAccess.file_exists(path):
		var parsed = JSON.parse_string(FileAccess.get_file_as_string(path))
		if parsed is Dictionary:
			d = parsed
	_data_cache[path] = d
	return d


func _ready() -> void:
	# after the skeleton has its final pose for the frame (animation, IK, look-at ...)
	if _skel != null and not _skel.skeleton_updated.is_connected(_on_skeleton_updated):
		_skel.skeleton_updated.connect(_on_skeleton_updated)


func _exit_tree() -> void:
	if _skel != null and is_instance_valid(_skel) and _skel.skeleton_updated.is_connected(_on_skeleton_updated):
		_skel.skeleton_updated.disconnect(_on_skeleton_updated)


func _on_skeleton_updated() -> void:
	if not enabled or _root == null or not _root.is_visible_in_tree():
		return
	_frame += 1
	var cam := get_viewport().get_camera_3d() if is_inside_tree() else null
	var every := EVERY
	if cam != null and cam.global_position.distance_to(_root.global_position) > FAR:
		every = FAR_EVERY
	if (_frame + get_instance_id()) % every != 0:   # (spread over frames when there are several people)
		return
	update_now()


## Read the joints and set every correction for the current pose.
func update_now() -> void:
	for j in _joints:
		var bi: int = j[1]
		# the joint's turn from its rest, in the parent's rest frame (= the world frame at rest, the
		# frame Daz's axes are given in), then in Daz's own axes for this bone
		var local := Basis(_skel.get_bone_pose_rotation(bi) * (j[6] as Quaternion))
		var w: Basis = (j[7] as Basis) * local * (j[8] as Basis)
		var daz: Basis = (j[4] as Basis) * w * (j[3] as Basis)
		var e := daz.get_euler(int(j[5]))
		_angles[j[0]] = Vector3(rad_to_deg(e.x), rad_to_deg(e.y), rad_to_deg(e.z))
	for p in _plan:
		var v := 0.0
		for ops in p[1]:
			v += _run(ops)
		for ops in p[2]:
			v *= _run(ops)
		_vals[p[0]] = clampf(v, p[3], p[4])
	for t in _targets:
		var v := float(_vals.get(t[0], 0.0))
		if absf(v - float(_applied.get(t[1], -9.0))) < EPS:
			continue
		_applied[t[1]] = v
		for pair in t[2]:
			(pair[0] as MeshInstance3D).set_blend_shape_value(int(pair[1]), v)


## One rule: a tiny stack machine (Daz's own operations).
func _run(ops: Array) -> float:
	var st: Array[float] = []
	for op in ops:
		match String(op[0]):
			"bone":
				var a: Vector3 = _angles.get(op[1], Vector3.ZERO)
				st.append(a.x if op[2] == "x" else (a.y if op[2] == "y" else a.z))
			"val":
				st.append(float(_vals.get(op[1], 0.0)))
			"num":
				st.append(float(op[1]))
			"mult":
				var b: float = st.pop_back()
				st.append(st.pop_back() * b)
			"add":
				var b: float = st.pop_back()
				st.append(st.pop_back() + b)
			"sub":
				var b: float = st.pop_back()
				st.append(st.pop_back() - b)
			"div":
				var b: float = st.pop_back()
				st.append(st.pop_back() / b if absf(b) > 1e-9 else 0.0)
			"spline":
				st.append(_spline(st.pop_back(), op[1]))
	return st.back() if not st.is_empty() else 0.0


## Daz's spline through its knots ([x, value], sorted by make_jcm_data.py); flat beyond the ends.
static func _spline(x: float, ks: Array) -> float:
	if x <= float(ks[0][0]):
		return float(ks[0][1])
	for i in range(1, ks.size()):
		var x1 := float(ks[i][0])
		if x <= x1:
			var x0 := float(ks[i - 1][0])
			var t := (x - x0) / maxf(x1 - x0, 1e-6)
			# smooth between knots (Daz's TCB spline with no tension/bias eases in and out)
			if ks.size() > 2:
				t = t * t * (3.0 - 2.0 * t)
			return lerpf(float(ks[i - 1][1]), float(ks[i][1]), t)
	return float(ks[ks.size() - 1][1])


## How strongly each correction is on right now (debug / checks): shape name -> weight.
func current() -> Dictionary:
	return _applied.duplicate()
