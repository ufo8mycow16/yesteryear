class_name SlungEquipment
extends Node3D
## REV 155: a piece of equipment carried on a shoulder strap - the TOS tricorder (Glen and Tiffany,
## 19 Oct; reference: McCoy with the strap over his LEFT shoulder, across the chest, the tricorder at
## his RIGHT hip, the strap running back across his back; when scanning he lifts it in both hands
## and it stays on the strap).
##
## No cloth simulation. The strap is a flat black ribbon redrawn every frame along a path through a
## few points that follow the skeleton:
##   front lug -> (across the chest) -> top of the left shoulder -> back of the left shoulder
##   -> (across the back) -> right flank -> back lug
## The two loose runs (lug to shoulder, flank to lug) sag under gravity when they have slack and pull
## straight when they don't; every point is then pushed out of a simple model of the torso (an oval
## per height, measured once from the posed body) so the strap lies on the shirt, not inside him.
##
## hold (0..1) blends the device from hanging at the hip (0) into the left hand (1); CharacterAnimator
## drives it from the "tablet" hold, so the tricorder rises as the arms come up.
##
## REV 164 (Glen: twisted, ends on the wrong sides, through his chest when he bends): the strap
## over the shoulder and across the back is laid on the real body and carried by the spine bones;
## loose lengths are kept out of a torso model that bends with the spine, and out of the thighs;
## in his hands the tricorder turns so the shoulder end is on his left. Check: tools/qa/strap_check.gd.
##
## Owned by CharacterAnimator (see set_slung / scan_action). Works for any figure with the animator's
## hip/chest/shoulder/hand roles; a figure without them just shows the device in the hand.

const DEVICE_HEIGHT := 0.18     # figure metres (REV 591: the kit's real size, 180 mm with the hood shut)
const STRAP_WIDTH := 0.024
const STRAP_THICK := 0.009      # gap kept between strap and shirt
const SLACK := 0.03             # extra length on each loose run, so it hangs a little when slung
const MAX_SAG := 0.22
const SAMPLES := 10             # per run
const LEVELS := 7               # torso ovals from hip to upper chest
const HANG_TURN := 0.8          # how far the hanging front turns from sideways toward forward
const HOLD_TILT := 40.0         # how far the face tips up toward him when held (degrees)
## REV 591 (Glen: "definitely flip open"): the TOS tricorder's hood (HoodPivot, a hinge about its own X)
## flips open as it rises into his hands and shuts again as it goes back to the hip. 90 = shut (how
## the model loads), 0 = open, the screen square to the body face (below 0 tips it away from him).
const HOOD_CLOSED_DEG := 90.0
const HOOD_OPEN_DEG := 0.0       # (held face-up, the open screen then looks straight up at him)
const HOOD_OPEN_FROM := 0.55    # hold value where it starts to open ...
const HOOD_OPEN_BY := 0.95      # ... and is fully open

var hold := 0.0
var _hood: Node3D = null        # HoodPivot, if the device has one
var _an: CharacterAnimator
var _model: Node3D
var _skel: Skeleton3D
var _device: Node3D             # pivot = middle of the device
var _dev_size := Vector3.ONE    # device size in its own (unscaled) units
var _dev_scale := 1.0
var _lug_local: Array = []      # [front, back] in device space
var _strap: MeshInstance3D
var _imesh: ImmediateMesh
var _unit := 1.0                # model units per figure metre
var _measured := false
var _levels: Array = []         # {bone, c, f, r, df, db, dr, dl} (c, f, r in that bone's space)
var _anchor := {}               # name -> {bone, p} (p in that bone's space)
var _rest_len := [0.0, 0.0]     # loose runs: front, back
var _swapped := false           # which lug faces forward when hanging
var _hold_swap := false         # REV 606: held the right way up, the shoulder lug is on his RIGHT - the strap ends cross over in his hands
var _legs: Array = []           # thighs as capsules: {a, b (hip and knee bones), r}
var _fixed: Array = []          # strap points laid on the body: {bone, p, n} in that bone's space
var last_points: Array = []     # this frame's strap path, [point, outward normal] (for tests)


## REV 167: where the device is now (world), for the character's eyes during a scan. INF if unknown.
func device_position() -> Vector3:
	if _device == null or not is_instance_valid(_device) or not _device.is_inside_tree():
		return Vector3.INF
	return _device.global_position


func setup(animator: CharacterAnimator, device_scene: PackedScene, fallback: Node3D = null) -> void:
	_an = animator
	_model = animator._model
	_skel = animator._skel
	name = "SlungEquipment"
	_device = Node3D.new()
	_device.name = "Device"
	add_child(_device)
	var inner: Node3D = device_scene.instantiate() if device_scene != null else fallback
	if inner == null:
		inner = Node3D.new()
	_device.add_child(inner)
	_darken_body(inner)
	_hood = inner.find_child("HoodPivot", true, false) as Node3D
	if _hood != null:
		_hood.rotation_degrees.x = HOOD_CLOSED_DEG     # measured shut, so the size is the carried size
	var ab := _aabb_of(inner)
	if ab.size.length() < 0.0001:
		ab = AABB(Vector3(-0.5, -0.5, -0.5), Vector3.ONE)
	inner.position = -ab.get_center()
	_dev_size = ab.size
	# strap lugs: the two narrow ends of the top, a little below the top edge, middle of the depth
	var top := ab.size.y * 0.5 - ab.size.y * 0.1
	_lug_local = [Vector3(0, top, ab.size.z * 0.5), Vector3(0, top, -ab.size.z * 0.5)]
	_imesh = ImmediateMesh.new()
	_strap = MeshInstance3D.new()
	_strap.name = "Strap"
	_strap.mesh = _imesh
	_strap.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0.035, 0.032, 0.03)
	m.roughness = 0.55
	m.metallic_specular = 0.3
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	_strap.material_override = m
	add_child(_strap)
	visible = false


## REV 156 (Glen): the TOS tricorder's body is almost black with a rough texture. The model's
## crinkled body material ("Aluminium sand") renders mid-grey, so it is darkened here (its bumps,
## from the normal map, stay); the screen, buttons and trim are untouched.
const BODY_COLOR := Color(0.07, 0.066, 0.062)

static func _darken_body(root: Node) -> void:
	for c in root.find_children("*", "MeshInstance3D", true, false):
		var mi := c as MeshInstance3D
		if mi.mesh == null:
			continue
		for i in mi.mesh.get_surface_count():
			var m := mi.get_active_material(i) as StandardMaterial3D
			if m == null or not m.resource_name.to_lower().contains("aluminium sand"):
				continue
			var d := m.duplicate() as StandardMaterial3D
			d.albedo_color = BODY_COLOR
			d.roughness = 0.85
			d.metallic = 0.0
			mi.set_surface_override_material(i, d)


static func _aabb_of(n: Node) -> AABB:
	var ab := AABB()
	var first := true
	var base := (n as Node3D).global_transform.affine_inverse() if n is Node3D and n.is_inside_tree() else Transform3D.IDENTITY
	for c in n.find_children("*", "MeshInstance3D", true, false):
		var mi := c as MeshInstance3D
		if mi.mesh == null:
			continue
		var xf := Transform3D.IDENTITY
		var p: Node = mi
		while p != null and p != n:
			if p is Node3D:
				xf = (p as Node3D).transform * xf
			p = p.get_parent()
		var a := xf * mi.mesh.get_aabb()
		ab = a if first else ab.merge(a)
		first = false
	return ab


# ---- skeleton helpers (everything below is in the figure's model space) ----------------------

func _to_model() -> Transform3D:
	return _model.global_transform.affine_inverse() * _skel.global_transform


func _bone_xf(b: int) -> Transform3D:
	return _to_model() * _skel.get_bone_global_pose(b)


func _role(r: String) -> int:
	return int(_an._bone.get(r, -1))


func _role_pos(r: String) -> Vector3:
	var b := _role(r)
	return _bone_xf(b).origin if b >= 0 else Vector3.ZERO


func _has_body() -> bool:
	for r in ["torso", "chest", "ua_l", "ua_r", "ha_l"]:
		if _role(r) < 0:
			return false
	return true


# ---- one-off measurement of the torso, from the posed body ----------------------------------

func _measure() -> void:
	_measured = true
	if not _has_body():
		return
	var up := Vector3.UP
	var hip := _role_pos("torso")
	var chest := _role_pos("chest")
	var sh_l := _role_pos("ua_l")
	var sh_r := _role_pos("ua_r")
	var right := (sh_r - sh_l)
	right.y = 0.0
	right = right.normalized()
	var fwd := up.cross(right).normalized()       # (right x up would point backwards)
	if fwd.dot(Vector3(0, 0, 1)) < 0.0:            # the figure faces +Z in model space
		fwd = -fwd
	var sh_y := (sh_l.y + sh_r.y) * 0.5
	_unit = maxf(sh_y, 0.1) / 1.45                 # a Genesis 8 shoulder is ~1.45 m up
	var tm := _body_triangles()
	var u := _unit

	var neck := Vector3((sh_l.x + sh_r.x) * 0.5, sh_y, (sh_l.z + sh_r.z) * 0.5)
	# torso ovals, hip to just under the shoulders
	_levels.clear()
	for i in LEVELS:
		var t := float(i) / float(LEVELS - 1)
		# (REV 164: from just below the belt, so the strap clears the seat of his trousers too)
		var y := lerpf(hip.y - 0.06 * u, sh_y - 0.06 * u, t)
		var spine := hip.lerp(neck, clampf((y - hip.y) / maxf(neck.y - hip.y, 0.01), 0.0, 1.0))
		var c := Vector3(spine.x, y, spine.z)
		var df := _hit_dist(tm, c, fwd, 0.18 * u)
		var db := _hit_dist(tm, c, -fwd, 0.15 * u)
		var half_span := absf((sh_r - sh_l).dot(right)) * 0.5
		var dr := minf(_inside_dist(tm, c, right, 0.16 * u), half_span * 0.95)    # from inside: the torso, not the arm
		var dl := minf(_inside_dist(tm, c, -right, 0.16 * u), half_span * 0.95)
		var bone := _spine_bone_at(y)
		var inv := _bone_xf(bone).affine_inverse()
		_levels.append({"bone": bone, "c": inv * c, "f": (inv.basis * fwd).normalized(),
			"r": (inv.basis * right).normalized(), "df": df, "db": db, "dr": dr, "dl": dl})
	var top: Dictionary = _levels[LEVELS - 1]
	var mid: Dictionary = _levels[3]
	var low: Dictionary = _levels[0]
	var top_c := _level_world(top)["c"] as Vector3
	# top of the LEFT shoulder (on the shirt, between neck and shoulder joint)
	# (from a little above, trying a few spots: too high or too close to the neck hits the head)
	var t_pt := neck.lerp(sh_l, 0.55) + up * 0.04 * u
	var found := false
	for lat in [0.68, 0.6, 0.76, 0.52]:
		for h in [0.18, 0.26, 0.12]:
			var p0 := neck.lerp(sh_l, lat)
			var hit := _cast(tm, p0 + up * h * u, -up)
			if hit != Vector3.INF and hit.y > sh_y - 0.03 * u and hit.y < sh_y + 0.10 * u:
				t_pt = hit + up * STRAP_THICK * u
				found = true
				break
		if found:
			break
	_set_anchor("shoulder", _role("chest"), t_pt)
	# right flank, a little behind the middle, at the lower ribs
	var mid_c := _level_world(mid)["c"] as Vector3
	var r0 := mid_c - fwd * float(mid["db"]) * 0.35
	var r_pt := r0 + right * (minf(_inside_dist(tm, r0, right, float(mid["dr"])), float(mid["dr"]) * 1.05) + STRAP_THICK * u)
	_set_anchor("flank", _spine_bone_at(r_pt.y), r_pt)
	# back of the left shoulder blade: a fifth of the way from the shoulder top down toward the right
	# flank (REV 164: it used to sit straight below the shoulder, which put a corner in the strap)
	var b0 := t_pt.lerp(r_pt, 0.2)
	b0 -= fwd * (b0 - top_c).dot(fwd)
	var b_hit := _cast(tm, b0 - fwd * 0.4 * u, fwd)
	var b_pt := (b_hit - fwd * STRAP_THICK * u) if b_hit != Vector3.INF else b0 - fwd * float(top["db"])
	_set_anchor("back", _role("chest"), b_pt)
	# where the device hangs: outside the RIGHT hip, its lugs a little below the belt
	var low_c := _level_world(low)["c"] as Vector3
	var h0 := low_c + up * 0.06 * u     # (the lowest slice is 8 cm under the old one since REV 164)
	var thick := _dev_size.x * _dev_scale_for(u) * 0.5
	var h_pt := h0 + right * (float(low["dr"]) + thick + 0.012 * u)
	_set_anchor("hip", _role("torso"), h_pt)
	_build_fixed(tm, fwd, right)
	_legs.clear()
	for side in [["ul_l", "ll_l"], ["ul_r", "ll_r"]]:
		var a := _role(side[0])
		var b := _role(side[1])
		if a < 0 or b < 0:
			continue
		var pa := _role_pos(side[0])
		var pb := _role_pos(side[1])
		var axis := (pb - pa).normalized()
		var m := pa.lerp(pb, 0.35)
		var rad := 0.0
		for d in [fwd, -fwd, right, -right]:
			var dd: Vector3 = (d - axis * d.dot(axis)).normalized()
			rad = maxf(rad, _inside_dist(tm, m, dd, 0.08 * u))
		_legs.append({"a": a, "b": b, "r": clampf(rad, 0.05 * u, 0.12 * u)})
	# rest lengths of the loose runs, from the hanging pose
	_dev_scale = _dev_scale_for(u)
	var hang := _hang_xf()
	var lugs := _lugs_model(hang)
	_swapped = (lugs[1] as Vector3).dot(fwd) > (lugs[0] as Vector3).dot(fwd)
	if _swapped:
		lugs.reverse()
	_rest_len[0] = (lugs[0] as Vector3).distance_to(_anchor_pos("shoulder")) + SLACK * u
	_rest_len[1] = (lugs[1] as Vector3).distance_to(_anchor_pos("flank")) + SLACK * u


## REV 164: the part of the strap that lies on him - over the left shoulder and across the back -
## is laid onto the real body once, by casting onto his shirt from just outside, and each point is
## then carried by the nearest spine bone (like the shirt itself). Before, it was a curve between
## two points pushed out of rough ovals: over the shoulder and near the right flank it ran under the
## shirt, and the strap seemed to stop short on the chest and back (Glen).
func _build_fixed(tm: TriangleMesh, fwd: Vector3, right: Vector3) -> void:
	_fixed.clear()
	var u := _unit
	var up := Vector3.UP
	var gap := STRAP_THICK * u
	var sh := _anchor_pos("shoulder")
	var bk := _anchor_pos("back")
	var fl := _anchor_pos("flank")
	var raw: Array = []      # [base point, outward normal, reach, centre to cast from or null]
	var mid := sh.lerp(bk, 0.5) + up * 0.018 * u
	# over the shoulder: cast toward a point inside the shoulder (below the middle of the arc), so the
	# strap wraps the ridge like a hand would lay it - casting straight back or down zig-zagged
	var core := sh.lerp(bk, 0.5) - up * 0.07 * u
	for i in range(1, SAMPLES):
		var t := float(i) / SAMPLES
		var p := sh.lerp(mid, t).lerp(mid.lerp(bk, t), t)
		raw.append([p, (p - core).normalized(), 0.0, core])
	for i in range(0, SAMPLES * 2 + 1):
		var t := float(i) / (SAMPLES * 2)
		var n := (-fwd * (1.0 - 0.55 * t) + right * 0.55 * t).normalized()
		raw.append([bk.lerp(fl, t), n, 0.12, null])
	# onto the shirt: from a little way out along the normal, inward; the outermost surface wins
	var placed: Array = []
	for r in raw:
		var p: Vector3 = r[0]
		var n: Vector3 = r[1]
		var hit := Vector3.INF
		if r[3] != null:
			var cc: Vector3 = r[3]
			hit = _cast(tm, cc + n * 0.22 * u, -n)
		else:
			hit = _cast(tm, p + n * float(r[2]) * u, -n)
		var q := p
		# (a hit far above the shoulder top is the head or ear, not the shoulder)
		if hit != Vector3.INF and (hit - p).dot(n) > -0.04 * u and hit.y < sh.y + 0.08 * u:
			q = hit + n * gap
		placed.append([q, n])
	# smooth out the bumps of the shirt mesh a little (never pulling a point back inside)
	for i in range(1, placed.size() - 1):
		var a: Vector3 = placed[i - 1][0]
		var b: Vector3 = placed[i + 1][0]
		var c: Vector3 = placed[i][0]
		var n: Vector3 = placed[i][1]
		var s := (a + b + c) / 3.0
		if (s - c).dot(n) > 0.0:
			placed[i] = [s, n]
	for i in placed.size():
		var q: Vector3 = placed[i][0]
		var n: Vector3 = placed[i][1]
		var bone := _role("chest") if i < SAMPLES - 1 else _spine_bone_at(q.y)
		var inv := _bone_xf(bone).affine_inverse()
		_fixed.append({"bone": bone, "p": inv * q, "n": (inv.basis * n).normalized()})


## REV 164: the spine bone a torso slice at height y moves with - the nearest one at or below it,
## from the hip up to the upper chest (Daz: hip, abdomenLower, abdomenUpper, chestLower, chestUpper).
## Before, everything below mid-chest followed the hip, so when he bent forward the belly folded over
## the strap's idea of where his body was and the strap disappeared into his shirt (Glen).
func _spine_bone_at(y: float) -> int:
	var torso := _role("torso")
	var b := _role("chest")
	var best := torso
	var best_y := -INF
	var guard := 0
	while b >= 0 and guard < 12:
		var by := _bone_xf(b).origin.y
		if by <= y + 0.005 * _unit and by > best_y:
			best = b
			best_y = by
		if b == torso:
			break
		b = _skel.get_bone_parent(b)
		guard += 1
	return best


func _dev_scale_for(u: float) -> float:
	return DEVICE_HEIGHT * u / maxf(_dev_size.y, 0.0001)


## Every triangle of the figure as it stands now (skinned meshes baked into their pose), model space.
func _body_triangles() -> TriangleMesh:
	var faces := PackedVector3Array()
	var inv := _model.global_transform.affine_inverse()
	for c in _model.find_children("*", "MeshInstance3D", true, false):
		var mi := c as MeshInstance3D
		if mi.mesh == null or not mi.visible or is_ancestor_of(mi):
			continue
		var nn := String(mi.name).to_lower()
		if nn.contains("hair") or nn.contains("eyelash") or nn.contains("brow"):
			continue       # long hair would sit on top of the shoulder ray
		var m: Mesh = mi.mesh
		if mi.skin != null or mi.get_node_or_null(mi.skeleton) is Skeleton3D:
			var baked := mi.bake_mesh_from_current_skeleton_pose()
			if baked != null:
				m = baked
		var xf := inv * mi.global_transform
		var f := m.get_faces()
		for i in f.size():
			f[i] = xf * f[i]
		faces.append_array(f)
	var tm := TriangleMesh.new()
	if faces.size() >= 3:
		tm.create_from_faces(faces)
	return tm


func _cast(tm: TriangleMesh, from: Vector3, dir: Vector3) -> Vector3:
	var r: Dictionary = tm.intersect_ray(from, dir)
	if r.is_empty() or not r.has("position"):
		return Vector3.INF
	return r["position"]


## Distance from c to the outermost surface along dir (cast from outside inward); `fallback` if no hit.
func _hit_dist(tm: TriangleMesh, c: Vector3, dir: Vector3, fallback: float) -> float:
	var h := _cast(tm, c + dir * 0.6 * _unit, -dir)
	if h == Vector3.INF:
		return fallback
	return maxf((h - c).dot(dir), 0.02 * _unit)


## Distance from c to the first surface going outward along dir (the torso wall, not an arm beyond it).
## REV 164: skin under the shirt is a surface too; keep going outward through layers that lie close
## together (skin, shirt) and use the outermost, so the strap sits on the shirt, not the skin.
func _inside_dist(tm: TriangleMesh, c: Vector3, dir: Vector3, fallback: float) -> float:
	var h := _cast(tm, c, dir)
	if h == Vector3.INF or (h - c).dot(dir) > 0.3 * _unit:
		return fallback
	var out := h
	for i in 4:
		var nxt := _cast(tm, out + dir * 0.002 * _unit, dir)
		if nxt == Vector3.INF or (nxt - out).dot(dir) > 0.035 * _unit:
			break
		out = nxt
	return maxf((out - c).dot(dir), 0.05 * _unit)


func _set_anchor(id: String, bone: int, p: Vector3) -> void:
	_anchor[id] = {"bone": bone, "p": _bone_xf(bone).affine_inverse() * p}


func _anchor_pos(id: String) -> Vector3:
	var a: Dictionary = _anchor[id]
	return _bone_xf(int(a["bone"])) * (a["p"] as Vector3)


func _level_world(l: Dictionary) -> Dictionary:
	var xf := _bone_xf(int(l["bone"]))
	return {"c": xf * (l["c"] as Vector3), "f": (xf.basis * (l["f"] as Vector3)).normalized(),
		"r": (xf.basis * (l["r"] as Vector3)).normalized()}


# ---- where the device is --------------------------------------------------------------------

func _frame() -> Dictionary:
	var right := _role_pos("ua_r") - _role_pos("ua_l")
	right.y = 0.0
	right = right.normalized()
	var up := Vector3.UP
	var fwd := up.cross(right).normalized()
	if fwd.dot(Vector3(0, 0, 1)) < 0.0:      # the figure faces +Z in model space
		fwd = -fwd
	return {"up": up, "right": right, "fwd": fwd}


## Hanging at the right hip: upright, its face (the side with the screen, +X) facing outward.
func _hang_xf() -> Transform3D:
	var fr := _frame()
	var right: Vector3 = fr["right"]
	var up: Vector3 = fr["up"]
	var fwd: Vector3 = fr["fwd"]
	var out := (right + fwd * HANG_TURN).normalized()      # its front faces out and a bit forward
	var b := Basis(out, up, out.cross(up)).orthonormalized()
	var lug_y := (_lug_local[0] as Vector3).y * _dev_scale
	var pos := _anchor_pos("hip") - up * lug_y
	return Transform3D(b.scaled(Vector3.ONE * _dev_scale), pos)


## In the hands: in front of him at the left hand (between both hands when they're together), its
## face tipped up toward him and its top end pointing away.
func _hand_xf() -> Transform3D:
	var fr := _frame()
	var up: Vector3 = fr["up"]
	var fwd: Vector3 = fr["fwd"]
	var a := deg_to_rad(HOLD_TILT)
	var face := (up * cos(a) - fwd * sin(a)).normalized()
	var long := (fwd * cos(a) + up * sin(a)).normalized()
	var b := Basis(face, long, face.cross(long)).orthonormalized()
	# REV 606 (Glen: "everybody uses it upside down"): ALWAYS the right way up - top end away from him,
	# face (and the open hood's screen) toward him. REV 164 used to turn it end for end whenever that put
	# the shoulder lug on his left (to stop the strap crossing his stomach); with the TOS tricorder that
	# was every time. Now the device stays put and, if the shoulder lug ends up on his right, the strap's
	# two ends slide across to the other lugs as it comes up into his hands (_draw_strap).
	var sh_lug: Vector3 = _lug_local[1] if _swapped else _lug_local[0]
	var left := -(fr["right"] as Vector3)
	_hold_swap = (b * sh_lug).dot(left) < 0.0
	var hl := _role_pos("ha_l")
	var hr := _role_pos("ha_r")
	var pos := hl
	# REV 171: both hands now reach onto its sides (CharacterMotion._hold_device), so it sits between
	# them - between the palms, which are a little ahead of the wrists
	if hl.distance_to(hr) < 0.5 * _unit:
		pos = hl.lerp(hr, 0.5) + fwd * 0.07 * _unit
	pos += up * 0.02 * _unit + fwd * 0.02 * _unit
	return Transform3D(b.scaled(Vector3.ONE * _dev_scale), pos)


func _lugs_model(xf: Transform3D) -> Array:
	return [xf * (_lug_local[0] as Vector3), xf * (_lug_local[1] as Vector3)]


# ---- every frame ----------------------------------------------------------------------------

func update_now() -> void:
	if not visible or _model == null or _skel == null:
		return
	if not _measured:
		_measure()
	_dev_scale = _dev_scale_for(_unit)
	if _hood != null:
		var o := smoothstep(HOOD_OPEN_FROM, HOOD_OPEN_BY, hold)
		_hood.rotation_degrees.x = lerpf(HOOD_CLOSED_DEG, HOOD_OPEN_DEG, o)
	if _levels.is_empty():
		# no torso to hang from: just the device in the hand while held
		_device.transform = _hand_xf() if _role("ha_l") >= 0 else Transform3D.IDENTITY
		_device.visible = hold > 0.05
		_imesh.clear_surfaces()
		return
	_device.visible = true
	var h := smoothstep(0.0, 1.0, hold)
	var a := _hang_xf()
	var b := _hand_xf()
	var qa := a.basis.orthonormalized().get_rotation_quaternion()
	var qb := b.basis.orthonormalized().get_rotation_quaternion()
	_device.transform = Transform3D(Basis(qa.slerp(qb, h)).scaled(Vector3.ONE * _dev_scale), a.origin.lerp(b.origin, h))
	_draw_strap()


func _draw_strap() -> void:
	_cache_levels()
	var lugs := _lugs_model(_device.transform)
	if _swapped:
		lugs.reverse()
	var lug_f: Vector3 = lugs[0]
	var lug_b: Vector3 = lugs[1]
	if _hold_swap:     # REV 606: in his hands the strap ends cross to the other lugs (see _hand_xf)
		var k := smoothstep(0.35, 0.9, hold)
		var f0 := lug_f
		lug_f = f0.lerp(lug_b, k)
		lug_b = lug_b.lerp(f0, k)
	var sh := _anchor_pos("shoulder")
	var fl := _anchor_pos("flank")
	var top: Dictionary = _ws[_ws.size() - 1]
	# one strap: the loose length is shared, so lifting the device sends the spare length round the back
	var d0 := lug_f.distance_to(sh)
	var d1 := fl.distance_to(lug_b)
	var spare := maxf(0.0, float(_rest_len[0]) + float(_rest_len[1]) - d0 - d1)
	# REV 164: in his hands the strap is held fairly taut - the spare length used to drop as a deep
	# loop (up to 22 cm) that sank into his lap and thigh when he scanned kneeling
	spare *= 1.0 - 0.8 * smoothstep(0.0, 1.0, hold)
	var len0 := d0 + spare * 0.5
	var len1 := d1 + spare * 0.5
	var pts: Array = []        # [point, surface normal]
	_loose_run(pts, lug_f, sh, len0, "front")
	# over the left shoulder and across the back: the points laid on his body (_build_fixed), carried
	# by the spine; the strap's face turns smoothly from forward, over the top, to the back (it used
	# to snap round 90 degrees at the shoulder - a visible twist)
	var bxf := {}
	for f in _fixed:
		var bone := int(f["bone"])
		if not bxf.has(bone):
			bxf[bone] = _bone_xf(bone)
		var xf: Transform3D = bxf[bone]
		var q: Vector3 = xf * (f["p"] as Vector3)
		var n: Vector3 = (xf.basis * (f["n"] as Vector3)).normalized()
		var pushed: Array = _push(q, "back") if n.dot(top["f"] as Vector3) < -0.5 else [q, n]
		pts.append([pushed[0], n])
	var back_run: Array = []
	_loose_run(back_run, fl, lug_b, len1, "radial")
	back_run.remove_at(0)
	pts.append_array(back_run)
	last_points = pts
	_ribbon(pts)


## A loose run from a to b of strap length `rest`: a hanging curve when there's slack, then kept out
## of the body. Appends [point, normal] pairs from a to b.
func _loose_run(out: Array, a: Vector3, b: Vector3, rest: float, mode: String) -> void:
	var d := a.distance_to(b)
	var sag := 0.0
	if rest > d:
		sag = minf(0.5 * sqrt(rest * rest - d * d), MAX_SAG * _unit)
	for i in SAMPLES + 1:
		var t := float(i) / SAMPLES
		var p := a.lerp(b, t) + Vector3.DOWN * sag * 4.0 * t * (1.0 - t)
		out.append(_push_legs(_push(p, mode)))


## REV 164: keep a loose strap point out of his thighs too (kneeling and scanning in his lap, the
## strap from his right side to the tricorder used to cut through the top of his leg).
func _push_legs(pn: Array) -> Array:
	var p: Vector3 = pn[0]
	var n: Vector3 = pn[1]
	for l in _legs:
		var a := _bone_xf(int(l["a"])).origin
		var b := _bone_xf(int(l["b"])).origin
		var ab := b - a
		var t := clampf((p - a).dot(ab) / maxf(ab.length_squared(), 0.000001), 0.0, 1.0)
		var c := a + ab * t
		var d := p - c
		var want := float(l["r"]) + STRAP_THICK * _unit
		if d.length() < want and t > 0.02:
			var dir := d.normalized() if d.length() > 0.0001 else n
			p = c + dir * want
			n = dir
	return [p, n]


## Keep a point out of the torso. mode "front" / "back" lift it onto that side; "radial" pushes it
## straight out from the middle. Returns [point, outward normal].
func _push(p: Vector3, mode: String) -> Array:
	var lv := _levels_at(p)
	var c: Vector3 = lv["c"]
	var f: Vector3 = lv["f"]
	var r: Vector3 = lv["r"]
	var rel := p - c
	var u := rel.dot(r)
	var w := rel.dot(f)
	var v := rel - r * u - f * w
	var ax: float = lv["dr"] if u > 0.0 else lv["dl"]
	var gap := STRAP_THICK * _unit
	var n := f
	if mode == "front" or mode == "back":
		var sgn := 1.0 if mode == "front" else -1.0
		n = f * sgn
		if absf(u) < ax:
			var q := u / ax
			var depth: float = lv["df"] if sgn > 0.0 else lv["db"]
			# a chest or back is flatter than an oval: a squarer curve, so the strap stays on the shirt
			var surf := depth * pow(maxf(0.0, 1.0 - pow(absf(q), 3.0)), 1.0 / 3.0)
			if w * sgn < surf + gap:
				w = (surf + gap) * sgn
	else:
		var bz: float = lv["df"] if w > 0.0 else lv["db"]
		var e := (u / ax) * (u / ax) + (w / bz) * (w / bz)
		var rad := r * u + f * w
		n = rad.normalized() if rad.length() > 0.0001 else f
		if e < 1.0:
			var k := 1.0 / sqrt(maxf(e, 0.0001))
			u *= k
			w *= k
			return [c + v + r * u + f * w + n * gap, n]
	return [c + v + r * u + f * w, n]


var _ws: Array = []   # this frame's torso ovals in model space (see _cache_levels)


func _cache_levels() -> void:
	_ws.clear()
	for l in _levels:
		var w := _level_world(l)
		w.merge(l)
		_ws.append(w)


## The torso oval at point p (in between two measured ones, or the end one).
## REV 164: chosen by how far p is ALONG THE SPINE (the line through the ovals' centres this frame),
## not by its height. Bent forward or kneeling the ovals are tilted, and picking by height chose the
## wrong one - the strap then went through his chest (Glen).
func _levels_at(p: Vector3) -> Dictionary:
	var ws := _ws
	var c0: Vector3 = ws[0]["c"]
	var axis: Vector3 = (ws[ws.size() - 1]["c"] as Vector3) - c0
	var al := axis.length()
	if al < 0.0001:
		return ws[0]
	axis /= al
	var s := (p - c0).dot(axis)
	if s <= 0.0:
		return ws[0]
	for i in range(1, ws.size()):
		var lo: Dictionary = ws[i - 1]
		var hi: Dictionary = ws[i]
		var s0 := ((lo["c"] as Vector3) - c0).dot(axis)
		var s1 := ((hi["c"] as Vector3) - c0).dot(axis)
		if s <= s1:
			var t := clampf((s - s0) / maxf(s1 - s0, 0.0001), 0.0, 1.0)
			var out := {}
			out["c"] = (lo["c"] as Vector3).lerp(hi["c"], t)
			out["f"] = (lo["f"] as Vector3).lerp(hi["f"], t).normalized()
			out["r"] = (lo["r"] as Vector3).lerp(hi["r"], t).normalized()
			for k in ["df", "db", "dr", "dl"]:
				out[k] = lerpf(float(lo[k]), float(hi[k]), t)
			return out
	return ws[ws.size() - 1]


## A flat strip through the points, lying flat against the surface normal at each.
func _ribbon(pts: Array) -> void:
	_imesh.clear_surfaces()
	if pts.size() < 2:
		return
	var half := STRAP_WIDTH * 0.5 * _unit
	_imesh.surface_begin(Mesh.PRIMITIVE_TRIANGLE_STRIP)
	for i in pts.size():
		var p: Vector3 = pts[i][0]
		var n: Vector3 = pts[i][1]
		var a: Vector3 = pts[maxi(i - 1, 0)][0]
		var b: Vector3 = pts[mini(i + 1, pts.size() - 1)][0]
		var tan := (b - a).normalized()
		var side := tan.cross(n)
		if side.length() < 0.001:
			side = tan.cross(Vector3.FORWARD)
		side = side.normalized() * half
		var nn := side.cross(tan).normalized()
		_imesh.surface_set_normal(nn)
		_imesh.surface_add_vertex(p - side)
		_imesh.surface_set_normal(nn)
		_imesh.surface_add_vertex(p + side)
	_imesh.surface_end()
