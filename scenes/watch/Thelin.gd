class_name Thelin
extends RefCounted
## Thelin, the Andorian first officer: Glen's Andorian For G8M (bryanthefigureman's head morph, Ryselle's
## antennae, the blue skin) on Spock's body, in Spock's blue shirt.
##
## make() builds a normal Spock (CharacterKit.make_named), then:
##  - swaps the head for the plain Genesis 8 face with the Andorian morph, lined up on Spock's head and
##    faded out down the neck (points and shading from head.bin, made by tools/thelin/build_thelin.py).
##    Spock's ears, lashes, hair and collar follow. Every expression and joint shape is kept, in order.
##  - moves the face bones (eyes, jaw, lips, brows) with the new face, so blinking, talking and looking
##    around still pivot in the right places
##  - blue skin and brown eyes from the bundle's own pictures
##  - Spock's hair turned white (Andorian), and the two antennae fixed to the head bone
## If anything is missing it gives back plain Spock rather than nothing.

const DIR := "res://assets/models/characters/thelin/"
const HAIR_SHADER := preload("res://scenes/watch/thelin_hair.gdshader")
const HAIR_WHITE := Color(0.88, 0.89, 0.92)
const MATCH_CM := 0.035         # a mesh point this close (Daz cm) to one of Spock's points is that point
const CHAR_LAYER := 1 << 19     # the people-only light layer (CharacterLook.CHAR_LAYER)

## skin surface (lower-case start of the material name) -> [colour picture, normal picture or ""]
const SKIN := {
	"face": ["face.jpg", "face_normal.jpg"], "lips": ["face.jpg", "face_normal.jpg"],
	"ears": ["face.jpg", "face_normal.jpg"], "eyesocket": ["face.jpg", ""],
	"torso": ["torso.jpg", ""], "arms": ["arms.jpg", "arms_normal.jpg"], "fingernails": ["arms.jpg", ""],
	"legs": ["legs.jpg", ""], "toenails": ["legs.jpg", ""],
	"mouth": ["mouth.jpg", ""], "teeth": ["mouth.jpg", ""],
	"irises": ["eyes.jpg", ""], "pupils": ["eyes.jpg", ""], "sclera": ["eyes.jpg", ""],
}


static func make(extra: Dictionary = {}) -> Node3D:
	var fig: Node3D = CharacterKit.make_named("spock", extra)
	if fig == null:
		return null
	fig.name = "Thelin"
	fig.set_meta("speaker_id", "thelin")
	fig.set_meta("display_name", "Thelin")
	var data := _load()
	if data.is_empty():
		push_warning("Thelin: no head data in %s - he stays as Spock" % DIR)
		return fig
	var sks := fig.find_children("*", "Skeleton3D", true, false)
	if sks.is_empty():
		return fig
	var sk := sks[0] as Skeleton3D
	var meshes: Array[MeshInstance3D] = []
	for m in fig.find_children("*", "MeshInstance3D", true, false):
		if (m as MeshInstance3D).mesh is ArrayMesh:
			meshes.append(m)
	var body := _body(meshes)
	if body == null:
		return fig
	# Daz centimetres -> the imported meshes' units, measured off the top of the head
	var k := body.mesh.get_aabb().end.y / float(data["top"])
	var grid := _grid(data["pts"], k)
	var hair := []      # [MeshInstance3D, surface]
	for mi in meshes:
		var kinds := _reshape(mi, data, grid, k)
		for s in kinds.size():
			if kinds[s] == "hair":
				hair.append([mi, s])
	_move_bones(fig, sk, data["bones"], k)
	_skin(body)
	for h in hair:
		_white_hair(h[0], int(h[1]))
	_antennae(body, sk, data, k)
	return fig


# --- data ---------------------------------------------------------------------------------------------

static var _cache: Dictionary = {}


static func _load() -> Dictionary:
	if not _cache.is_empty():
		return _cache
	if not FileAccess.file_exists(DIR + "head.json") or not FileAccess.file_exists(DIR + "head.bin"):
		return {}
	var j = JSON.parse_string(FileAccess.get_file_as_string(DIR + "head.json"))
	if not (j is Dictionary):
		return {}
	var raw := FileAccess.get_file_as_bytes(DIR + "head.bin")
	var pts := PackedVector3Array()
	var off := PackedVector3Array()
	var dn := PackedVector3Array()
	var kind := PackedStringArray()
	for g in j["groups"]:
		var o := int(g["offset"])
		var has_n := bool(g["normals"])
		var stride := 36 if has_n else 24
		for i in int(g["count"]):
			var b := o + i * stride
			pts.append(Vector3(raw.decode_float(b), raw.decode_float(b + 4), raw.decode_float(b + 8)))
			off.append(Vector3(raw.decode_float(b + 12), raw.decode_float(b + 16), raw.decode_float(b + 20)))
			dn.append(Vector3(raw.decode_float(b + 24), raw.decode_float(b + 28), raw.decode_float(b + 32)) if has_n else Vector3.ZERO)
			kind.append(String(g["kind"]))
	var a: Dictionary = j["antennae"]
	var ao := int(a["offset"])
	var nv := int(a["verts"])
	var av := PackedVector3Array()
	var an := PackedVector3Array()
	var auv := PackedVector2Array()
	for i in nv:
		var b := ao + i * 32
		av.append(Vector3(raw.decode_float(b), raw.decode_float(b + 4), raw.decode_float(b + 8)))
		an.append(Vector3(raw.decode_float(b + 12), raw.decode_float(b + 16), raw.decode_float(b + 20)))
		auv.append(Vector2(raw.decode_float(b + 24), raw.decode_float(b + 28)))
	var ai := PackedInt32Array()
	var io := ao + nv * 32
	for i in int(a["tris"]) * 3:
		ai.append(raw.decode_s32(io + i * 4))
	_cache = {"pts": pts, "off": off, "dn": dn, "kind": kind, "bones": j["bones_cm"], "top": float(j["body_top_cm"]),
		"ant_v": av, "ant_n": an, "ant_uv": auv, "ant_i": ai}
	return _cache


static func _body(meshes: Array[MeshInstance3D]) -> MeshInstance3D:
	var best: MeshInstance3D = null
	for mi in meshes:
		var n := String(mi.name).to_lower()
		if n.begins_with("genesis8male") and not n.contains("eyelash"):
			return mi
		if best == null or mi.mesh.get_aabb().end.y > best.mesh.get_aabb().end.y:
			best = mi
	return best


## Spock's moving points in the meshes' own units, filed by little cubes so each mesh point finds its
## match quickly: {"pts": scaled points, "cell": cube size, "tol": match distance, "g": cube -> point numbers}
static func _grid(pts: PackedVector3Array, k: float) -> Dictionary:
	var cell := MATCH_CM * 1.5 * k
	var sp := PackedVector3Array()
	sp.resize(pts.size())
	var g := {}
	for j in pts.size():
		sp[j] = pts[j] * k
		var c := Vector3i((sp[j] / cell).floor())
		if not g.has(c):
			g[c] = PackedInt32Array()
		(g[c] as PackedInt32Array).append(j)
	return {"pts": sp, "cell": cell, "tol": MATCH_CM * k, "g": g}


static func _find(grid: Dictionary, v: Vector3) -> int:
	var g: Dictionary = grid["g"]
	var sp: PackedVector3Array = grid["pts"]
	var c := Vector3i((v / float(grid["cell"])).floor())
	var best := float(grid["tol"]) * float(grid["tol"])
	var out := -1
	for dx in [-1, 0, 1]:
		for dy in [-1, 0, 1]:
			for dz in [-1, 0, 1]:
				var cell := c + Vector3i(dx, dy, dz)
				if not g.has(cell):
					continue
				for j in g[cell]:
					var d := v.distance_squared_to(sp[j])
					if d < best:
						best = d
						out = j
	return out


# --- the new head -------------------------------------------------------------------------------------

## Moves every point of this mesh that is one of Spock's moving points. Returns, per surface, what it is
## ("body", "lash", "hair", "cloth") or "" where nothing moves.
static func _reshape(mi: MeshInstance3D, data: Dictionary, grid: Dictionary, k: float) -> PackedStringArray:
	var am := mi.mesh as ArrayMesh
	var off: PackedVector3Array = data["off"]
	var dnn: PackedVector3Array = data["dn"]
	var kinds: PackedStringArray = data["kind"]
	var kinds_out := PackedStringArray()
	var surfs := []
	var any := false
	for s in am.get_surface_count():
		var votes := {}
		var arr := am.surface_get_arrays(s)
		var v: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
		var n: PackedVector3Array = arr[Mesh.ARRAY_NORMAL] if arr[Mesh.ARRAY_NORMAL] != null else PackedVector3Array()
		var moved := PackedVector3Array()
		moved.resize(v.size())
		for i in v.size():
			var j := _find(grid, v[i])
			if j < 0:
				continue
			v[i] += off[j] * k
			moved[i] = off[j] * k
			if i < n.size() and dnn[j] != Vector3.ZERO:
				n[i] = (n[i] + dnn[j]).normalized()
			votes[kinds[j]] = int(votes.get(kinds[j], 0)) + 1
			any = true
		arr[Mesh.ARRAY_VERTEX] = v
		if not n.is_empty():
			arr[Mesh.ARRAY_NORMAL] = n
		surfs.append([arr, moved])
		var best := ""
		for kd in votes:
			if best == "" or int(votes[kd]) > int(votes[best]):
				best = kd
		kinds_out.append(best)
	if not any:
		return kinds_out
	var nm := ArrayMesh.new()
	nm.resource_name = am.resource_name
	nm.blend_shape_mode = am.blend_shape_mode
	for i in am.get_blend_shape_count():
		nm.add_blend_shape(am.get_blend_shape_name(i))   # every shape, in the same order (the face and joint code hold their numbers)
	for s in am.get_surface_count():
		var arr: Array = surfs[s][0]
		var moved: PackedVector3Array = surfs[s][1]
		var shapes := []
		for sh in am.surface_get_blend_shape_arrays(s):
			var c := (sh as Array).duplicate()
			if am.blend_shape_mode == Mesh.BLEND_SHAPE_MODE_NORMALIZED:
				# whole positions: they move with the face
				var sv: PackedVector3Array = c[Mesh.ARRAY_VERTEX]
				for i in mini(sv.size(), moved.size()):
					sv[i] += moved[i]
				c[Mesh.ARRAY_VERTEX] = sv
				c[Mesh.ARRAY_NORMAL] = arr[Mesh.ARRAY_NORMAL]
			shapes.append(c)
		var flags := am.surface_get_format(s) & Mesh.ARRAY_FLAG_USE_8_BONE_WEIGHTS
		nm.add_surface_from_arrays(am.surface_get_primitive_type(s), arr, shapes, {}, flags)
		nm.surface_set_name(s, am.surface_get_name(s))
		nm.surface_set_material(s, am.surface_get_material(s))
	mi.mesh = nm
	return kinds_out


## The face bones go with the face (as CrewLooks._move_bones): a moved bone gets its new rest, a bone
## under it keeps its place, and every skinned piece is re-fitted so nothing moves twice.
static func _move_bones(fig: Node3D, sk: Skeleton3D, bones: Dictionary, k: float) -> void:
	var delta := {}
	for bn in bones:
		var b := sk.find_bone(String(bn))
		var d: Array = bones[bn]
		if b >= 0:
			delta[b] = Vector3(float(d[0]), float(d[1]), float(d[2])) * k
	if delta.is_empty():
		return
	var old_global := {}
	for b in sk.get_bone_count():
		old_global[b] = sk.get_bone_global_rest(b)
	var new_global := {}
	for b in sk.get_bone_count():
		var g: Transform3D = old_global[b]
		if delta.has(b):
			g.origin += delta[b]
		var parent := sk.get_bone_parent(b)
		var pg: Transform3D = new_global[parent] if parent >= 0 else Transform3D()
		if delta.has(b) or (parent >= 0 and new_global[parent] != old_global[parent]):
			sk.set_bone_rest(b, pg.affine_inverse() * g)
			sk.reset_bone_pose(b)
		new_global[b] = g
	for m in fig.find_children("*", "MeshInstance3D", true, false):
		var mi := m as MeshInstance3D
		if mi.skin == null:
			continue
		var skin := mi.skin.duplicate() as Skin
		for i in skin.get_bind_count():
			var b := skin.get_bind_bone(i)
			if b < 0:
				b = sk.find_bone(String(skin.get_bind_name(i)))
			if b < 0 or not delta.has(b):
				continue
			var gn: Transform3D = new_global[b]
			var go: Transform3D = old_global[b]
			skin.set_bind_pose(i, gn.affine_inverse() * go * skin.get_bind_pose(i))
		mi.skin = skin


# --- skin, hair, antennae -----------------------------------------------------------------------------

static func _tex(file: String) -> Texture2D:
	if file == "" or not ResourceLoader.exists(DIR + file):
		return null
	return load(DIR + file) as Texture2D


static func _skin(body: MeshInstance3D) -> void:
	for s in body.mesh.get_surface_count():
		var mat := body.get_active_material(s)
		if mat == null:
			continue
		var low := String(mat.resource_name).to_lower()
		var pics: Array = []
		for key in SKIN:
			if low.begins_with(String(key)):
				pics = SKIN[key]
				break
		if pics.is_empty():
			continue
		var col := _tex(String(pics[0]))
		if col == null:
			continue
		var nrm := _tex(String(pics[1]))
		var eye := low.begins_with("irises") or low.begins_with("pupils") or low.begins_with("sclera")
		var mouth := low.begins_with("mouth") or low.begins_with("teeth")
		if mat is ShaderMaterial:
			var sm := (mat as ShaderMaterial).duplicate() as ShaderMaterial
			sm.set_shader_parameter("albedo_tex", col)
			sm.set_shader_parameter("albedo", Color.WHITE)
			if sm.get_shader_parameter("sss_tex") != null:
				sm.set_shader_parameter("sss_tex", col)
			if nrm != null:
				sm.set_shader_parameter("has_normal", true)
				sm.set_shader_parameter("normal_tex", nrm)
				sm.set_shader_parameter("normal_strength", 1.0)
			body.set_surface_override_material(s, sm)
		elif mat is StandardMaterial3D:
			var st := (mat as StandardMaterial3D).duplicate() as StandardMaterial3D
			st.albedo_texture = col
			if not eye and not mouth:
				st.albedo_color = Color.WHITE
			if st.subsurf_scatter_texture != null:
				st.subsurf_scatter_texture = col
			if nrm != null and not eye:
				st.normal_enabled = true
				st.normal_texture = nrm
				st.normal_scale = 1.0
			body.set_surface_override_material(s, st)


static func _white_hair(mi: MeshInstance3D, s: int) -> void:
	var mat := mi.get_active_material(s)
	var pic: Texture2D = null
	var cut := false
	if mat is StandardMaterial3D:
		var st := mat as StandardMaterial3D
		pic = st.albedo_texture
		cut = st.transparency != BaseMaterial3D.TRANSPARENCY_DISABLED
	elif mat is ShaderMaterial:
		var sm := mat as ShaderMaterial
		pic = sm.get_shader_parameter("strands") as Texture2D
		if pic == null:
			pic = sm.get_shader_parameter("albedo_tex") as Texture2D
		cut = true
	var h := ShaderMaterial.new()
	h.shader = HAIR_SHADER
	h.resource_name = mat.resource_name if mat != null else "Hair"
	h.set_shader_parameter("tex", pic)
	h.set_shader_parameter("has_tex", pic != null)
	h.set_shader_parameter("hair_color", HAIR_WHITE)
	h.set_shader_parameter("use_alpha", 1.0 if cut else 0.0)
	mi.set_surface_override_material(s, h)


## The two antennae: one mesh beside the body, every point held by the head bone.
static func _antennae(body: MeshInstance3D, sk: Skeleton3D, data: Dictionary, k: float) -> void:
	var head := sk.find_bone("head")
	if head < 0 or body.skin == null:
		return
	var bind := -1
	for i in body.skin.get_bind_count():
		var b := body.skin.get_bind_bone(i)
		if b == head or String(body.skin.get_bind_name(i)) == "head":
			bind = i
			break
	var skin := Skin.new()
	if bind >= 0:
		skin.add_named_bind("head", body.skin.get_bind_pose(bind))
	else:
		skin.add_named_bind("head", sk.get_bone_global_rest(head).affine_inverse())
	var src_v: PackedVector3Array = data["ant_v"]
	var v := PackedVector3Array()
	v.resize(src_v.size())
	for i in src_v.size():
		v[i] = src_v[i] * k
	var bones := PackedInt32Array()
	var weights := PackedFloat32Array()
	bones.resize(v.size() * 4)
	weights.resize(v.size() * 4)
	for i in v.size():
		weights[i * 4] = 1.0
	var arr := []
	arr.resize(Mesh.ARRAY_MAX)
	arr[Mesh.ARRAY_VERTEX] = v
	arr[Mesh.ARRAY_NORMAL] = data["ant_n"]
	arr[Mesh.ARRAY_TEX_UV] = data["ant_uv"]
	arr[Mesh.ARRAY_INDEX] = data["ant_i"]
	arr[Mesh.ARRAY_BONES] = bones
	arr[Mesh.ARRAY_WEIGHTS] = weights
	var am := ArrayMesh.new()
	am.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
	var mat := StandardMaterial3D.new()
	mat.resource_name = "Andorian_Antenna_Skin"
	mat.albedo_texture = _tex("antenna.jpg")
	mat.roughness = 0.55
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	am.surface_set_material(0, mat)
	var mi := MeshInstance3D.new()
	mi.name = "Antennae"
	mi.mesh = am
	mi.skin = skin
	mi.layers = body.layers | CHAR_LAYER
	body.get_parent().add_child(mi)
	mi.transform = body.transform
	mi.skeleton = body.skeleton      # a sibling of the body: the same path reaches the skeleton
