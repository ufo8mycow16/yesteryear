class_name RomulanBelt
extends RefCounted
## REV 839 (Glen: "I just want my Romulans wearing a belt", with a TOS Romulan picture - the wide dark belt over the
## quilted tunic AND the sash). No Daz belt is needed: the belt is cut from the clothes' own surface at the waist
## (tunic, sash, anything worn there), lifted a few millimetres off it and skinned to the SAME bones with the same
## weights, so it bends, twists and walks with the body and never cuts through the clothes. The cut edges get a
## thin rim so the belt has thickness. Works on Genesis 8 and 9 alike (it only reads the meshes).
##
## Tuning (all as fractions of the figure's height, so they hold for any size): CENTRE = height of the belt's middle
## above the feet, WIDTH = how tall the belt is, LIFT = how far it stands off the clothes, REACH = how far from the
## body's middle a piece of cloth can be and still count (keeps the hanging sleeves and hands out of it).

const CENTRE := 0.585
const WIDTH := 0.036
const LIFT := 0.0042
const REACH := 0.18
const COLOUR := Color(0.045, 0.05, 0.085)   # TOS: very dark navy, nearly black, shiny like vinyl

## Who wears one (CharacterKit keys). Only Daz models are touched; stand-ins are left alone.
const WEARERS := ["varel", "senior_specialist", "kovek", "tech_specialist", "tovan", "turian", "romulan_rep", "romulan_official",
	"tech_specialist", "archive_specialist"]


static func add_to(model: Node3D, key: String) -> void:
	if not WEARERS.has(key) or model == null:
		return
	var body: MeshInstance3D = null
	for m in model.find_children("*", "MeshInstance3D", true, false):
		var n := String(m.name).to_lower()
		if (n.begins_with("genesis8") or n.begins_with("genesis9")) and (m as MeshInstance3D).mesh != null:
			body = m
			break
	if body == null:
		return
	# the figure's height and middle, in the model's own space
	var bxf := _xf_to(body, model)
	var ab := body.mesh.get_aabb()
	var lo_v := Vector3(INF, INF, INF)
	var hi_v := -lo_v
	for i in 8:
		var c := bxf * ab.get_endpoint(i)
		lo_v = lo_v.min(c)
		hi_v = hi_v.max(c)
	var h := hi_v.y - lo_v.y
	if h <= 0.0:
		return
	var mid := Vector2((lo_v.x + hi_v.x) * 0.5, (lo_v.z + hi_v.z) * 0.5)
	var y0 := lo_v.y + h * (CENTRE - WIDTH * 0.5)
	var y1 := lo_v.y + h * (CENTRE + WIDTH * 0.5)
	var mat := StandardMaterial3D.new()
	mat.resource_name = "romulan_belt"
	mat.albedo_color = COLOUR
	mat.roughness = 0.24
	mat.metallic_specular = 0.6
	mat.clearcoat_enabled = true
	mat.clearcoat = 0.8
	mat.clearcoat_roughness = 0.18
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	var made := 0
	for m in model.find_children("*", "MeshInstance3D", true, false):
		var mi := m as MeshInstance3D
		var n := String(mi.name).to_lower()
		if mi.mesh == null or not mi.visible or n.begins_with("genesis") or n.begins_with("g9") or n.contains("hair") \
				or n.contains("brow") or n.contains("lash") or n.contains("eye") or n.contains("mouth") or n.contains("tear"):
			continue
		var belt := _cut(mi, _xf_to(mi, model), y0, y1, mid, h * REACH, h * LIFT)
		if belt == null:
			continue
		var bm := MeshInstance3D.new()
		bm.name = String(mi.name) + "_Belt"
		bm.mesh = belt
		bm.skin = mi.skin
		bm.transform = mi.transform
		bm.layers = mi.layers
		bm.cast_shadow = mi.cast_shadow
		bm.material_override = mat
		mi.get_parent().add_child(bm)
		bm.owner = mi.owner
		bm.skeleton = mi.skeleton   # same parent, so the same path reaches the skeleton
		made += 1
	if made > 0:
		model.set_meta("romulan_belt", made)


## Transform from a node's space up to `root`'s space (works before the model is in the scene tree).
static func _xf_to(node: Node3D, root: Node3D) -> Transform3D:
	var xf := Transform3D.IDENTITY
	var n: Node = node
	while n != null and n != root:
		if n is Node3D:
			xf = (n as Node3D).transform * xf
		n = n.get_parent()
	return xf


static func _cut(mi: MeshInstance3D, xf: Transform3D, y0: float, y1: float, mid: Vector2, reach: float, lift: float) -> ArrayMesh:
	var inv := xf.affine_inverse()
	var nb := xf.basis.inverse().transposed()
	var out_v := PackedVector3Array()
	var out_n := PackedVector3Array()
	var out_b := PackedInt32Array()
	var out_w := PackedFloat32Array()
	var per := 4
	var flags := 0
	var skinned := false
	for s in mi.mesh.get_surface_count():
		var arr: Array = mi.mesh.surface_get_arrays(s)
		var verts: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
		if verts.is_empty():
			continue
		var norms: PackedVector3Array = arr[Mesh.ARRAY_NORMAL] if arr[Mesh.ARRAY_NORMAL] != null else PackedVector3Array()
		var bones = arr[Mesh.ARRAY_BONES]
		var weights = arr[Mesh.ARRAY_WEIGHTS]
		var has_skin: bool = bones != null and weights != null and (bones as PackedInt32Array).size() > 0
		if has_skin:
			skinned = true
			per = int((bones as PackedInt32Array).size() / verts.size())
			if per == 8:
				flags = Mesh.ARRAY_FLAG_USE_8_BONE_WEIGHTS
		var idx = arr[Mesh.ARRAY_INDEX]
		var tri_count: int = (idx as PackedInt32Array).size() / 3 if idx != null else verts.size() / 3
		# vertices in model space, worked out once
		var mv := PackedVector3Array()
		mv.resize(verts.size())
		var mn := PackedVector3Array()
		mn.resize(verts.size())
		for i in verts.size():
			mv[i] = xf * verts[i]
			mn[i] = (nb * norms[i]).normalized() if i < norms.size() else Vector3.ZERO
		for t in tri_count:
			var ia: int = (idx as PackedInt32Array)[t * 3] if idx != null else t * 3
			var ib: int = (idx as PackedInt32Array)[t * 3 + 1] if idx != null else t * 3 + 1
			var ic: int = (idx as PackedInt32Array)[t * 3 + 2] if idx != null else t * 3 + 2
			var pa := mv[ia]
			var pb := mv[ib]
			var pc := mv[ic]
			if maxf(pa.y, maxf(pb.y, pc.y)) < y0 or minf(pa.y, minf(pb.y, pc.y)) > y1:
				continue
			var cen := (pa + pb + pc) / 3.0
			if Vector2(cen.x, cen.z).distance_to(mid) > reach:
				continue
			# polygon of [position, normal, source vertex for the bone weights]
			var poly := [[pa, mn[ia], ia], [pb, mn[ib], ib], [pc, mn[ic], ic]]
			poly = _clip(poly, y0, true)
			poly = _clip(poly, y1, false)
			if poly.size() < 3:
				continue
			var outer := []
			for p in poly:
				var nrm: Vector3 = p[1]
				outer.append(p[0] + nrm * lift)
			for k in range(1, poly.size() - 1):
				for j in [0, k, k + 1]:
					_emit(out_v, out_n, out_b, out_w, inv * (outer[j] as Vector3), inv.basis * (poly[j][1] as Vector3),
						int(poly[j][2]), bones, weights, per, has_skin)
			# the rim along the cut edges (both ends on the same cutting plane)
			var eps := (y1 - y0) * 0.002
			for k in poly.size():
				var a = poly[k]
				var b = poly[(k + 1) % poly.size()]
				var ya: float = (a[0] as Vector3).y
				var yb: float = (b[0] as Vector3).y
				var on0 := absf(ya - y0) < eps and absf(yb - y0) < eps
				var on1 := absf(ya - y1) < eps and absf(yb - y1) < eps
				if not (on0 or on1):
					continue
				var rn := Vector3.DOWN if on0 else Vector3.UP
				var quad := [[a[0], a[2]], [b[0], b[2]], [outer[(k + 1) % poly.size()], b[2]], [outer[k], a[2]]]
				for j in [0, 1, 2, 0, 2, 3]:
					_emit(out_v, out_n, out_b, out_w, inv * (quad[j][0] as Vector3), inv.basis * rn,
						int(quad[j][1]), bones, weights, per, has_skin)
	if out_v.is_empty() or not skinned:
		return null
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = out_v
	arrays[Mesh.ARRAY_NORMAL] = out_n
	arrays[Mesh.ARRAY_BONES] = out_b
	arrays[Mesh.ARRAY_WEIGHTS] = out_w
	var am := ArrayMesh.new()
	am.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays, [], {}, flags)
	return am


## One side of a horizontal plane (keep_above: keep y >= plane). New corners take the bone weights of the
## nearer original corner - the belt's edges sit within a few millimetres of one of them.
static func _clip(poly: Array, plane: float, keep_above: bool) -> Array:
	var res := []
	for k in poly.size():
		var a = poly[k]
		var b = poly[(k + 1) % poly.size()]
		var ya: float = (a[0] as Vector3).y
		var yb: float = (b[0] as Vector3).y
		var a_in := ya >= plane if keep_above else ya <= plane
		var b_in := yb >= plane if keep_above else yb <= plane
		if a_in:
			res.append(a)
		if a_in != b_in:
			var t := (plane - ya) / (yb - ya)
			var p := (a[0] as Vector3).lerp(b[0], t)
			p.y = plane
			var nrm := (a[1] as Vector3).lerp(b[1], t).normalized()
			res.append([p, nrm, a[2] if t < 0.5 else b[2]])
	return res


static func _emit(ov: PackedVector3Array, on: PackedVector3Array, ob: PackedInt32Array, ow: PackedFloat32Array,
		p: Vector3, n: Vector3, src: int, bones, weights, per: int, has_skin: bool) -> void:
	ov.append(p)
	on.append(n.normalized())
	for j in per:
		if has_skin:
			ob.append((bones as PackedInt32Array)[src * per + j])
			ow.append((weights as PackedFloat32Array)[src * per + j])
		else:
			ob.append(0)
			ow.append(1.0 if j == 0 else 0.0)
