@tool
extends EditorScenePostImport
## Daz character import fixes (REV 124). Set as the import script of a Daz Genesis 8 FBX
## (Import dock > Import Script, or "import_script/path" in its .import file). Runs once, when
## Godot imports the model - nothing extra happens while the game runs.
##
## 1. Face shapes (visemes, blinks, expressions) arrive from Daz's FBX without lighting normals, so
##    Godot lit every moving part of the face wrongly (dark blotches). Each shape is given the
##    face's own normals instead.
## 2. Shape names lose the mesh prefix Daz adds ("Genesis8Male__eCTRLvAA" -> "eCTRLvAA") so the
##    body, eyelashes, clothes and hair all answer to the same name.
## 3. Clothes, hair and eyelashes ("followers") come with their own copy of the skeleton
##    (bones named lShldrBend_2, head_3 ...), which nothing animates - so when McCoy moved, his
##    uniform stayed behind. Their skins are re-pointed at the body's own bones.
## 4. Skin under the clothes is removed (only where clothing lies just outside it), so the body
##    can't poke through the uniform when he moves - the usual game-character trick.
## 6. REV 240: Daz's joint corrections (flesh bulging and creasing at bent joints, muscles flexing)
##    are built into the body and the clothes over it; shapes that don't move a mesh are left off it.
## 5. Materials: the clear layers over the eyes (Cornea, EyeMoisture) become see-through with a wet
##    shine, eyelashes become soft dark strands, hair uses its picture's transparency, and skin gets
##    a softer, less plastic finish (plus subsurface scattering on the Forward+ renderer).
## 7. REV 751: Daz Genesis 9 as well (alongside Genesis 8). G9 is one unisex figure whose eyes, mouth (teeth
##    and tongue) and tear film are meshes of their own (Genesis9Eyes / Genesis9Mouth / Genesis9Tear) - they are
##    figure, not clothing; its lashes get their own map (g9_eyelashes.png - the G8 lash layouts don't fit), its
##    card brows (G9EyebrowCards) get their strand picture joined with its cut-out (g9_brows_*.png) and keep the
##    brow colour Daz exported. No Genesis 8 joint corrections on it (different figure). Made by
##    tools/crew/make_g9_maps.py; export rules in docs/DAZ_EXPORT_SETTINGS.md "Genesis 9".

## Genesis 8 Male lashes: Daz's G8MBaseEyelashesMapTR_1006.jpg turned into dark lashes whose
## transparency is the map (any Genesis 8 Male uses the same lash layout).
const EYELASH_TEXTURE := "res://assets/models/characters/g8m_eyelashes.png"
## REV 153: Genesis 8 Female lashes (Uhura's export) - same treatment, female lash layout.
const EYELASH_TEXTURE_FEMALE := "res://assets/models/characters/g8f_eyelashes.png"
## REV 579: Genesis 8.1 Female lashes (Tuvall / Lt T'Nal) - 8.1 lays its lash strips out differently
## (rows of strips, not the G8 arcs), so the G8 picture put lash strands where 8.1 has none: a brown smudge.
const EYELASH_TEXTURE_FEMALE_81 := "res://assets/models/characters/g81f_eyelashes.png"
## REV 751: Genesis 9 lashes (one layout for women and men) and card brows. The brow picture is chosen by
## the brow style's cut-out name when it can be read from the material's picture (g9_brows_<style>.png,
## e.g. "thin"); otherwise the thin style the blank figure wears.
const EYELASH_TEXTURE_G9 := "res://assets/models/characters/g9_eyelashes.png"
const BROW_TEXTURE_G9_DIR := "res://assets/models/characters/"
const BROW_TEXTURE_G9_DEFAULT := "res://assets/models/characters/g9_brows_thin.png"
## brows whose exported colour came through as plain white get this instead (a mid brown)
const BROW_FALLBACK_G9 := Color(0.25, 0.17, 0.11)
var _eyelash_tex := EYELASH_TEXTURE   # picked per figure in _post_import
var _g9 := false                      # REV 751: this figure is Genesis 9
var _body_mesh := false
var _cloth := {}             # spatial hash: Vector3i cell -> Array of clothing triangles
const CELL := 0.05
const COVER_DIST := 0.035    # clothing within this distance outside the skin covers it
## REV 154: keep the skin within this distance of visible skin, i.e. a band inside every clothing
## edge (collar, cuffs, hem). Clothing edges stand a little off the body, so with the skin right up
## to the edge removed you could see straight through the gap beside the neck (Glen: McCoy, Spock).
const EDGE_KEEP_DIST := 0.025
const INSIDE_DIST := 0.10     # REV 154: how far to look for clothing seen from the inside
const INSIDE_BELOW := 0.03    # REV 761: an inside hit further below the skin than this is a collar under the jaw, not a sleeve
## REV 154: real visible skin comes in big connected areas (head and neck, hands, bare legs). A small
## "visible" island surrounded by clothing - the armpits and crotch, where the check's ray slips out
## through the gap between sleeve and body - is really under the clothes (McCoy's armpit poked out).
const MIN_VISIBLE_AREA := 200   # skin points
var _visible_skin := {}   # spatial hash (cell EDGE_KEEP_DIST) of uncovered body skin, all surfaces
var _hidden_tris := 0
var _hair_mesh := false   # the mesh being fixed is hair (Daz hair products are named all sorts)
var _cloth_mesh := false  # REV 154: the mesh being fixed is clothing (not body, hair, lashes or brows)

## REV 131: stamped on the imported model, so the game can tell when Godot is still using an import made
## before the latest fixes (changing this script doesn't make Godot reimport by itself).
const FIX_VERSION := 849   # REV 849: bones that hang off a follower copy (G9 tongue) moved onto the real ones; REV 847: hair from the Daz library (library_hair/<Name>_daz.json); REV 842: Genesis 9 joint corrections; REV 761: skin above a collar is never "inside" it (Varel's jaw hole); REV 755: cut-out clothing pictures

const SKIN := ["face", "lips", "torso", "arms", "legs", "ears", "eyesocket", "mouth", "fingernails", "toenails"]


func _post_import(scene: Node) -> Object:
	var fixed := 0
	var rebound := 0
	_drop_daz_helpers(scene)
	var re := RegEx.create_from_string("_\\d+$")
	for m in scene.find_children("*", "MeshInstance3D", true, false):
		var mi0 := m as MeshInstance3D
		var sk := mi0.get_node_or_null(mi0.skeleton) as Skeleton3D
		if mi0.skin != null and sk != null:
			var skin := mi0.skin.duplicate() as Skin
			for b in skin.get_bind_count():
				var bn := String(skin.get_bind_name(b))
				var base := re.sub(bn, "")
				if base != bn and sk.find_bone(base) >= 0:
					skin.set_bind_name(b, base)
					rebound += 1
			mi0.skin = skin
	print("Daz import: %d follower bones joined to the body" % rebound)
	_join_follower_children(scene, re)
	_add_library_hair(scene)
	_g9 = _is_genesis9(scene)
	_eyelash_tex = EYELASH_TEXTURE_FEMALE if _is_female(scene) else EYELASH_TEXTURE
	if _is_female(scene) and _is_genesis81(scene):
		_eyelash_tex = EYELASH_TEXTURE_FEMALE_81
	if _g9:
		_eyelash_tex = EYELASH_TEXTURE_G9
		print("Daz import: Genesis 9 figure")
	print("Daz import: eyelashes %s" % _eyelash_tex.get_file())
	_collect_clothing(scene)
	_load_jcm(scene)
	for m in scene.find_children("*", "MeshInstance3D", true, false):
		var mi := m as MeshInstance3D
		if mi.mesh is ArrayMesh:
			var nn := String(mi.name).to_lower()
			_hair_mesh = nn.contains("hair") or nn.contains("cabelo") or nn.contains("cabello")
			_body_mesh = _is_body(nn)
			_cloth_mesh = not _hair_mesh and not _is_figure(nn) and not nn.contains("eyelash") and not nn.contains("brow") and not _is_tear(nn)
			mi.mesh = _fix_mesh(mi.mesh as ArrayMesh)
			fixed += 1
	print("Daz import: fixed %d meshes in %s, %d skin triangles under clothing hidden, %d joint-correction shapes added" % [fixed, scene.name, _hidden_tris, _jcm_added])
	scene.set_meta("daz_fixes", FIX_VERSION)
	return scene


## REV 849 (Glen: "the director still has a dark red thing hanging off his cheek" - his tongue): Genesis 9 exports
## the eyes, mouth, lashes and tear as figures of their own, each with a COPY of the body's bones (head_5, lowerjaw_4,
## lowerteeth_2 ...). The skins are moved onto the real bones above, but bones that exist ONLY in a follower - the
## tongue (tongue01-05) - stayed hanging off the copies, which nothing ever moves. So when the head turned or the
## jaw opened the tongue stayed where it was and came out through the cheek. Each such bone is re-hung from the
## real bone its copy stands for, keeping where it is.
func _join_follower_children(scene: Node, re: RegEx) -> void:
	var moved := 0
	for s in scene.find_children("*", "Skeleton3D", true, false):
		var sk := s as Skeleton3D
		for i in sk.get_bone_count():
			var nm := sk.get_bone_name(i)
			if re.sub(nm, "") != nm:
				continue        # a copy itself
			var p := sk.get_bone_parent(i)
			if p < 0:
				continue
			var pn := sk.get_bone_name(p)
			var base := re.sub(pn, "")
			if base == pn:
				continue        # already on a real bone
			var real := sk.find_bone(base)
			if real < 0 or real == i:
				continue
			var global_rest := sk.get_bone_global_rest(i)
			sk.set_bone_parent(i, real)
			var local := sk.get_bone_global_rest(real).affine_inverse() * global_rest
			sk.set_bone_rest(i, local)
			sk.set_bone_pose_position(i, local.origin)
			sk.set_bone_pose_rotation(i, local.basis.get_rotation_quaternion())
			sk.set_bone_pose_scale(i, local.basis.get_scale())
			moved += 1
	if moved > 0:
		print("Daz import: %d bones moved off follower copies onto the real ones (e.g. the tongue)" % moved)


## REV 847: a hair from the Daz library, fitted to this character by tools/crew/g9_library_hair.py (Glen: no need
## to export hair - it's added the way the crew kit adds it). library_hair/<this FBX's name>.json holds the fitted,
## thinned hair in the figure's own Daz centimetres with its skin weights by bone name; it's built here into a mesh
## beside the body, skinned with the body's own bind poses, so to everything after this it's exported hair.
const LIBRARY_HAIR_DIR := "res://assets/models/characters/library_hair/"

## REV 848: clothes too - every library_hair/<this FBX's name>.<part>.json (g9_library_clothes.py: Uhura's dress and
## boots fitted to this body) becomes its own mesh the same way, named by the part ("LibraryDress"), so the importer
## treats it as clothing (skin under it hidden, joint corrections followed).
func _add_library_hair(scene: Node) -> void:
	var stem := get_source_file().get_file().get_basename()
	if not DirAccess.dir_exists_absolute(LIBRARY_HAIR_DIR):
		return
	for f in DirAccess.get_files_at(LIBRARY_HAIR_DIR):
		if f == stem + ".json" or (f.begins_with(stem + ".") and f.ends_with(".json")):
			_add_library_part(scene, LIBRARY_HAIR_DIR + f)


func _add_library_part(scene: Node, jp: String) -> void:
	var meta = JSON.parse_string(FileAccess.get_file_as_string(jp))
	var blob := FileAccess.get_file_as_bytes(jp.get_basename() + ".bin")
	if not (meta is Dictionary) or blob.is_empty():
		print("Daz import: %s unreadable - left off" % jp.get_file())
		return
	var body: MeshInstance3D = null
	for m in scene.find_children("*", "MeshInstance3D", true, false):
		if _is_body(String(m.name).to_lower()) and (m as MeshInstance3D).skin != null:
			body = m
			break
	if body == null:
		print("Daz import: no skinned body found - %s left off" % jp.get_file())
		return
	var sk := body.get_node_or_null(body.skeleton) as Skeleton3D
	var py: Array = meta["points_y"]
	var k := body.mesh.get_aabb().size.y / maxf(float(py[1]) - float(py[0]), 0.001)
	# the body's bind poses by bone name; a hair bone the body isn't bound to uses its nearest bound parent
	var bind_of := {}
	for b in body.skin.get_bind_count():
		bind_of[String(body.skin.get_bind_name(b))] = body.skin.get_bind_pose(b)
	var skin := Skin.new()
	var slot := {}
	var remap := PackedInt32Array()
	for bn in meta["bones"]:
		var use := String(bn)
		var bi := sk.find_bone(use) if sk != null else -1
		while not bind_of.has(use) and bi >= 0:
			bi = sk.get_bone_parent(bi)
			use = sk.get_bone_name(bi) if bi >= 0 else ""
		if not bind_of.has(use):
			use = "head" if bind_of.has("head") else String(bind_of.keys()[0])
		if not slot.has(use):
			slot[use] = skin.get_bind_count()
			skin.add_named_bind(use, bind_of[use])
		remap.append(int(slot[use]))
	var mesh := ArrayMesh.new()
	mesh.resource_name = "LibraryHair"
	for s in meta["surfaces"]:
		var pos := _lh_floats(blob, s["pos"])
		var nrm := _lh_floats(blob, s["nrm"])
		var uvf := _lh_floats(blob, s["uv"])
		var jn := _lh_ints(blob, s["joints"])
		var n := pos.size() / 3
		var v := PackedVector3Array()
		var nn := PackedVector3Array()
		var uv := PackedVector2Array()
		v.resize(n)
		nn.resize(n)
		uv.resize(n)
		for i in n:
			v[i] = Vector3(pos[i * 3], pos[i * 3 + 1], pos[i * 3 + 2]) * k
			nn[i] = Vector3(nrm[i * 3], nrm[i * 3 + 1], nrm[i * 3 + 2])
			uv[i] = Vector2(uvf[i * 2], 1.0 - uvf[i * 2 + 1])   # Daz UVs start at the bottom
		for i in jn.size():
			jn[i] = remap[jn[i]]
		var arrays := []
		arrays.resize(Mesh.ARRAY_MAX)
		arrays[Mesh.ARRAY_VERTEX] = v
		arrays[Mesh.ARRAY_NORMAL] = nn
		arrays[Mesh.ARRAY_TEX_UV] = uv
		arrays[Mesh.ARRAY_BONES] = jn
		arrays[Mesh.ARRAY_WEIGHTS] = _lh_floats(blob, s["weights"])
		arrays[Mesh.ARRAY_INDEX] = _lh_ints(blob, s["index"])
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
		var mat := StandardMaterial3D.new()
		mat.resource_name = String(s["material"])
		var pic := String(s.get("picture", ""))
		if pic != "" and ResourceLoader.exists(pic):
			mat.albedo_texture = load(pic)
		if String(meta.get("node", "LibraryHair")).contains("Hair"):
			mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
		mat.cull_mode = BaseMaterial3D.CULL_DISABLED
		mesh.surface_set_name(mesh.get_surface_count() - 1, mat.resource_name)
		mesh.surface_set_material(mesh.get_surface_count() - 1, mat)
	var hair := MeshInstance3D.new()
	hair.name = String(meta.get("node", "LibraryHair"))
	mesh.resource_name = hair.name
	hair.mesh = mesh
	hair.skin = skin
	body.get_parent().add_child(hair)
	hair.transform = body.transform
	hair.skeleton = hair.get_path_to(sk)
	hair.owner = scene
	print("Daz import: library part %s added (%d surfaces, %d bones, scale %.4f)" % [String(meta.get("name", "")), mesh.get_surface_count(), skin.get_bind_count(), k])


static func _lh_floats(blob: PackedByteArray, x: Dictionary) -> PackedFloat32Array:
	var at := int(x["at"])
	return blob.slice(at, at + int(x["count"]) * 4).to_float32_array()


static func _lh_ints(blob: PackedByteArray, x: Dictionary) -> PackedInt32Array:
	var at := int(x["at"])
	return blob.slice(at, at + int(x["count"]) * 4).to_int32_array()


## REV 178: Daz "geometry shells" (a second copy of a garment, e.g. Ullus's "Jacket_8499_Shell 2") come
## through the FBX unskinned, pinned to one bone in the export pose, so they stood in an A-pose over the
## animated figure. dForce helper nodes carry no mesh the game wants either. Both are removed.
func _drop_daz_helpers(scene: Node) -> void:
	var gone: Array[Node] = []
	for n in scene.find_children("*", "", true, false):
		var nn := String(n.name).to_lower()
		if nn.contains("_shell") or nn.begins_with("dforce"):
			gone.append(n)
	# (Only by name: other unskinned pieces on a bone, like Uhura's earrings, are wanted.)
	var dropped := 0
	for n in gone:
		if is_instance_valid(n) and n.get_parent() != null and not gone.has(n.get_parent()):
			n.get_parent().remove_child(n)
			n.free()
			dropped += 1
	if dropped > 0:
		print("Daz import: removed %d unskinned Daz extras (geometry shells / dForce helpers)" % dropped)


func _fix_mesh(am: ArrayMesh) -> ArrayMesh:
	var nm := ArrayMesh.new()
	nm.resource_name = am.resource_name
	nm.blend_shape_mode = am.blend_shape_mode
	var normalized := am.blend_shape_mode == Mesh.BLEND_SHAPE_MODE_NORMALIZED
	if _body_mesh and not _cloth.is_empty():
		_collect_visible_skin(am)
	var surfs := []        # per surface: [arrays, its blend shape arrays]
	for s in am.get_surface_count():
		var arr := am.surface_get_arrays(s)
		if _body_mesh and not _cloth.is_empty():
			_cull_covered(arr)
		surfs.append([arr, am.surface_get_blend_shape_arrays(s)])
	# REV 240: only the Daz shapes that actually move this mesh (each one costs a copy of all its
	# points: Kirk's hair carried all 140 face shapes, 74 of which do nothing to it)
	var keep := []
	for i in am.get_blend_shape_count():
		var moves := false
		for sd in surfs:
			var base: PackedVector3Array = (sd[0] as Array)[Mesh.ARRAY_VERTEX]
			var sv: PackedVector3Array = ((sd[1] as Array)[i] as Array)[Mesh.ARRAY_VERTEX]
			if normalized:
				if sv != base:
					moves = true
					break
			else:
				for v in sv:
					if v != Vector3.ZERO:
						moves = true
						break
				if moves:
					break
		if moves:
			keep.append(i)
	var names := {}
	for i in keep:
		var n := String(am.get_blend_shape_name(i))
		var cut := n.rfind("__")
		n = n.substr(cut + 2) if cut >= 0 else n
		names[n] = true
		nm.add_blend_shape(n)
	# REV 240: Daz's joint corrections for the body, and carried onto the clothes lying over it
	var jcm: Array = _jcm_for_mesh(surfs) if (_body_mesh or _cloth_mesh) else []
	var jcm_kept := []
	for j in jcm:
		if not names.has(String(j[0])):
			nm.add_blend_shape(String(j[0]))
			jcm_kept.append(j)
	_jcm_added += jcm_kept.size()
	for s in surfs.size():
		var arr: Array = surfs[s][0]
		var shapes: Array = surfs[s][1]
		var out := []
		for i in keep:
			var a: Array = (shapes[i] as Array).duplicate()
			_shape_normals(a, arr, normalized)
			out.append(a)
		for j in jcm_kept:
			var a := []
			a.resize(Mesh.ARRAY_MAX)
			var moved: Dictionary = (j[1] as Array)[s]
			var base: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
			var v := base.duplicate() if normalized else PackedVector3Array()
			if not normalized:
				v.resize(base.size())
			for vi in moved:
				v[vi] += moved[vi]
			a[Mesh.ARRAY_VERTEX] = v
			_shape_normals(a, arr, normalized)
			out.append(a)
		nm.add_surface_from_arrays(am.surface_get_primitive_type(s), arr, out)
		nm.surface_set_name(s, am.surface_get_name(s))
		nm.surface_set_material(s, _fix_material(am.surface_get_material(s)))
	if am.get_blend_shape_count() > 0 or not jcm_kept.is_empty():
		print("Daz import: %s - %d of %d Daz shapes kept, %d joint corrections" % [am.resource_name, keep.size(), am.get_blend_shape_count(), jcm_kept.size()])
	return nm


## A shape's lighting normals: the surface's own (the FBX's shapes have none - REV 124).
func _shape_normals(a: Array, arr: Array, normalized: bool) -> void:
	if normalized:
		a[Mesh.ARRAY_NORMAL] = arr[Mesh.ARRAY_NORMAL]
		a[Mesh.ARRAY_TANGENT] = arr[Mesh.ARRAY_TANGENT]
	else:
		var z := PackedVector3Array()
		z.resize((arr[Mesh.ARRAY_NORMAL] as PackedVector3Array).size())
		a[Mesh.ARRAY_NORMAL] = z
		if arr[Mesh.ARRAY_TANGENT] != null:
			var zt := PackedFloat32Array()
			zt.resize((arr[Mesh.ARRAY_TANGENT] as PackedFloat32Array).size())
			a[Mesh.ARRAY_TANGENT] = zt


# ---- REV 240: Daz joint corrections ----------------------------------------------------------------
## When a Daz figure bends a joint, Daz switches on corrective shapes so it bulges and creases like
## flesh (and muscles flex). The FBX leaves them out; they come from Glen's Daz library instead
## (tools/crew/make_jcm_data.py -> assets/models/characters/jcm/), and are built into the body here.
## Clothing gets them too, carried over from the skin under it (as Daz's auto-fit does), so sleeves
## and trouser knees move with the arm and leg. core/characters/JointCorrectives.gd turns them on in
## game from the joint angles. Needs jcm/points/<model>.bin (the figure's own rest points in Daz's
## order: make_jcm_data.py points <model>.fbx) - without it the model is imported as before.
const JCM_DIR := "res://assets/models/characters/jcm/"
const JCM_MIN_MOVE := 0.0002       # m: a correction moving no point of a mesh further is left off it
const JCM_CLOTH_REACH := 0.07      # m: clothing this close to the skin follows its corrections
const JCM_CELL := 0.02
var _jcm_pts := PackedVector3Array()   # the figure's rest points (metres, Godot's units)
var _jcm_grid := {}                    # Vector3i -> Array of point numbers
var _jcm_list := []                    # [name, PackedInt32Array points, PackedVector3Array offsets (m)]
var _jcm_added := 0


func _load_jcm(scene: Node) -> void:
	_jcm_pts = PackedVector3Array()
	_jcm_grid.clear()
	_jcm_list.clear()
	_jcm_added = 0
	var stem := get_source_file().get_file().get_basename()
	var pts_path := JCM_DIR + "points/" + stem + ".bin"
	var fig := "genesis8female" if _is_female(scene) else "genesis8male"
	if _g9:
		fig = "genesis9"   # REV 842: Genesis 9's own corrections (one figure for both sexes)
	var json_path := JCM_DIR + fig + "_jcm.json"
	if not FileAccess.file_exists(pts_path) or not FileAccess.file_exists(json_path):
		print("Daz import: no joint corrections for %s (no %s)" % [stem, pts_path.get_file()])
		return
	var data = JSON.parse_string(FileAccess.get_file_as_string(json_path))
	var raw := FileAccess.get_file_as_bytes(pts_path)
	var n := raw.size() / 12
	if data == null or n != int(data.get("points", -1)):
		print("Daz import: %s doesn't match the %s figure - no joint corrections" % [pts_path.get_file(), fig])
		return
	# Daz centimetres -> the mesh's units: measured, from the body's height
	var cm := PackedVector3Array()
	cm.resize(n)
	var lo := INF
	var hi := -INF
	for i in n:
		cm[i] = Vector3(raw.decode_float(i * 12), raw.decode_float(i * 12 + 4), raw.decode_float(i * 12 + 8))
		lo = minf(lo, cm[i].y)
		hi = maxf(hi, cm[i].y)
	var body_h := 0.0
	for m in scene.find_children("*", "MeshInstance3D", true, false):
		if _is_body(String(m.name).to_lower()) and (m as MeshInstance3D).mesh != null:
			body_h = (m as MeshInstance3D).mesh.get_aabb().size.y
	var k := body_h / maxf(hi - lo, 0.001) if body_h > 0.0 else 0.01
	_jcm_pts.resize(n)
	for i in n:
		_jcm_pts[i] = cm[i] * k
		var c := Vector3i((_jcm_pts[i] / JCM_CELL).floor())
		if not _jcm_grid.has(c):
			_jcm_grid[c] = []
		(_jcm_grid[c] as Array).append(i)
	var blob := FileAccess.get_file_as_bytes(JCM_DIR + fig + "_jcm.bin")
	for sh in data["shapes"]:
		var off := int(sh["offset"])
		var cnt := int(sh["count"])
		var idx := PackedInt32Array()
		var d := PackedVector3Array()
		idx.resize(cnt)
		d.resize(cnt)
		for e in cnt:
			var o := off + e * 16
			idx[e] = blob.decode_s32(o)
			d[e] = Vector3(blob.decode_float(o + 4), blob.decode_float(o + 8), blob.decode_float(o + 12)) * k
		_jcm_list.append([String(sh["name"]), idx, d])
	print("Daz import: %d joint corrections from the Daz library (%s, scale %.4f)" % [_jcm_list.size(), fig, k])


## The joint corrections for one mesh: [[name, [per surface: {vertex: offset}]], ...] - only those
## that move it. The body's points are the Daz points themselves (matched by position); a clothing
## point follows the skin points nearest it, fading out with distance from the skin.
func _jcm_for_mesh(surfs: Array) -> Array:
	if _jcm_list.is_empty():
		return []
	# which Daz points each vertex follows, and how much: per Daz point a list of [surface, vertex, weight]
	var follow := {}
	var matched := 0
	var total := 0
	for s in surfs.size():
		var verts: PackedVector3Array = (surfs[s][0] as Array)[Mesh.ARRAY_VERTEX]
		for vi in verts.size():
			total += 1
			var near := _jcm_nearest(verts[vi], 0.001 if _body_mesh else JCM_CLOTH_REACH, 1 if _body_mesh else 4)
			if near.is_empty():
				continue
			matched += 1
			var wsum := 0.0
			for nb in near:
				wsum += 1.0 / (float(nb[1]) + 0.004)
			var fade := 1.0
			if not _body_mesh:
				fade = clampf((JCM_CLOTH_REACH - float(near[0][1])) / (JCM_CLOTH_REACH * 0.5), 0.0, 1.0)
			for nb in near:
				var w := fade * (1.0 / (float(nb[1]) + 0.004)) / wsum
				var p := int(nb[0])
				if not follow.has(p):
					follow[p] = []
				(follow[p] as Array).append([s, vi, w])
	if matched == 0:
		return []
	if _body_mesh and matched < total * 0.9:
		print("Daz import: only %d of %d body points matched the Daz figure - joint corrections left off" % [matched, total])
		return []
	var out := []
	for sh in _jcm_list:
		var idx: PackedInt32Array = sh[1]
		var d: PackedVector3Array = sh[2]
		var per := []
		for s in surfs.size():
			per.append({})
		var biggest := 0.0
		for e in idx.size():
			var f = follow.get(idx[e])
			if f == null:
				continue
			for t in (f as Array):
				var m: Dictionary = per[int(t[0])]
				var add: Vector3 = d[e] * float(t[2])
				var vi := int(t[1])
				m[vi] = (m[vi] as Vector3) + add if m.has(vi) else add
		for m in per:
			for vi in m:
				biggest = maxf(biggest, (m[vi] as Vector3).length())
		if biggest >= JCM_MIN_MOVE:
			out.append([sh[0], per])
	return out


## Up to <count> Daz points within <reach> of p, nearest first: [[point, distance], ...]. Searches
## outward ring by ring and stops once nothing nearer can turn up.
func _jcm_nearest(p: Vector3, reach: float, count: int) -> Array:
	var c := Vector3i((p / JCM_CELL).floor())
	var rmax := ceili(reach / JCM_CELL)
	var found := []
	for r in rmax + 1:
		for dx in range(-r, r + 1):
			for dy in range(-r, r + 1):
				for dz in range(-r, r + 1):
					if maxi(absi(dx), maxi(absi(dy), absi(dz))) != r:
						continue
					var cell = _jcm_grid.get(c + Vector3i(dx, dy, dz))
					if cell == null:
						continue
					for i in (cell as Array):
						var dist := p.distance_to(_jcm_pts[i])
						if dist <= reach:
							found.append([i, dist])
		if found.size() >= count:
			found.sort_custom(func(x, y): return x[1] < y[1])
			# anything in the next ring is at least r * cell away
			if float(found[count - 1][1]) <= float(r) * JCM_CELL:
				break
	found.sort_custom(func(x, y): return x[1] < y[1])
	return found.slice(0, count)


func _fix_material(mat: Material) -> Material:
	var sm := mat as StandardMaterial3D
	if sm == null:
		return mat
	var n := sm.resource_name.to_lower()
	# REV 579: Genesis 8.1's "Tear" (wet film along the lids) is clear like the cornea - drawn solid it was a white ring
	if n.contains("cornea") or n.contains("eyemoisture") or n.contains("moisture") or n == "tear" or n.begins_with("tear"):
		sm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		sm.albedo_texture = null
		sm.albedo_color = Color(1, 1, 1, 0.0)
		sm.roughness = 0.08
		sm.metallic_specular = 0.6      # a soft wet glint, not a glare
		sm.cull_mode = BaseMaterial3D.CULL_BACK
	elif n == "sclera" or n.begins_with("sclera"):
		# REV 127 (Tiffany): not the brightest thing on his face - warmer, duller whites, little shine
		sm.albedo_color = Color(0.80, 0.76, 0.72)
		sm.roughness = 0.55
		sm.metallic_specular = 0.25
	elif n == "irises" or n.begins_with("iris"):
		# blue, but not luminous game-character blue
		sm.albedo_color = Color(0.74, 0.76, 0.76)
		sm.roughness = 0.5
		sm.metallic_specular = 0.25
	elif n == "pupils" or n.begins_with("pupil"):
		sm.albedo_color = Color(0.02, 0.02, 0.02)     # a clearly defined pupil
		sm.roughness = 0.4
	elif _g9 and n.begins_with("eyebrows"):
		_g9_brows(sm)
	elif n.contains("eyelash"):
		sm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_DEPTH_PRE_PASS
		sm.cull_mode = BaseMaterial3D.CULL_DISABLED
		sm.roughness = 0.8
		if ResourceLoader.exists(_eyelash_tex):
			# REV 128: Daz's lash map (white = lash) made into dark lashes with see-through gaps
			sm.albedo_texture = load(_eyelash_tex)
			sm.albedo_color = Color(1, 1, 1, 0.9)
		elif sm.albedo_texture == null:
			# without the lash picture the lash cards draw as a dark band (eyeliner) - leave them out
			sm.albedo_color = Color(0.05, 0.04, 0.035, 0.0)
		sm.cull_mode = BaseMaterial3D.CULL_DISABLED
		sm.roughness = 0.8
	elif _is_hair(sm):
		sm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_DEPTH_PRE_PASS   # REV 126: smooth edges (hash dithered into speckles)
		sm.cull_mode = BaseMaterial3D.CULL_DISABLED
		sm.roughness = 0.6
	else:
		if _cloth_mesh:
			# REV 154: clothes draw both sides - looking down the open collar at the inside of the
			# back collar showed a see-through sliver beside the neck (Glen: Spock, McCoy)
			sm.cull_mode = BaseMaterial3D.CULL_DISABLED
			# REV 733 (Tuvall's robe): clothing with a cut-out map (ragged hems) is cut out, never blended -
			# blended cloth sorts against itself and the body and flickers as she moves
			# REV 755 (Varel's Romulan sash): a colour picture with see-through parts is a cut-out too, even when the
			# FBX didn't flag the material transparent (tools/crew/daz_cutouts.py bakes Poser cut-out maps into the
			# picture's alpha)
			if sm.transparency != BaseMaterial3D.TRANSPARENCY_DISABLED or _has_cutout(sm.albedo_texture):
				sm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
				sm.alpha_scissor_threshold = 0.5
		# REV 751: Genesis 9 names its skin Head / Body / Arms / Legs - "head" and "body" only on the figure itself
		var skin_names: Array = SKIN + (["head", "body"] if _g9 and _body_mesh else [])
		for k in skin_names:
			if n == k or n.begins_with(k):
				sm.roughness = 0.62
				sm.metallic_specular = 0.35
				sm.subsurf_scatter_enabled = true
				sm.subsurf_scatter_strength = 0.25
				sm.subsurf_scatter_skin_mode = true
				break
	return sm


## REV 755: a picture with real see-through parts (not just an alpha channel that's all solid).
func _has_cutout(tex: Texture2D) -> bool:
	if tex == null:
		return false
	var img := tex.get_image()
	if img == null:
		return false
	if img.is_compressed():
		img = img.duplicate() as Image
		if img.decompress() != OK:
			return false
	return img.detect_alpha() != Image.ALPHA_NONE


func _is_hair(sm: StandardMaterial3D) -> bool:
	return _hair_mesh or sm.resource_name.to_lower().contains("hair")


## REV 751: Genesis 9's card brows. Daz draws them as a near-white strand picture tinted by the brow colour,
## cut out by a separate opacity picture - an FBX material can't carry the second picture, so they arrive as
## solid grey cards. The joined picture (strands + cut-out, tools/crew/make_g9_maps.py) goes on instead, under
## the colour Daz exported (Eyebrows_Secondary is part see-through in Daz too - its opacity is kept).
func _g9_brows(sm: StandardMaterial3D) -> void:
	var path := BROW_TEXTURE_G9_DEFAULT
	var src := ""
	if sm.albedo_texture != null:
		src = (sm.albedo_texture.resource_path + " " + sm.albedo_texture.resource_name).to_lower()
	for style in ["thin", "medium", "thick", "full", "sparse"]:
		var p := BROW_TEXTURE_G9_DIR + "g9_brows_%s.png" % style
		if src.contains(style) and ResourceLoader.exists(p):
			path = p
			break
	var c := sm.albedo_color
	if c.r > 0.9 and c.g > 0.9 and c.b > 0.9:
		c = Color(BROW_FALLBACK_G9.r, BROW_FALLBACK_G9.g, BROW_FALLBACK_G9.b, c.a)
	if ResourceLoader.exists(path):
		sm.albedo_texture = load(path)
		sm.albedo_color = c
		sm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_DEPTH_PRE_PASS
	else:
		# without the joined picture the cards would be solid strips across the forehead - leave them out
		sm.albedo_color = Color(c.r, c.g, c.b, 0.0)
		sm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	sm.cull_mode = BaseMaterial3D.CULL_DISABLED
	sm.roughness = 0.75
	sm.metallic_specular = 0.2
	print("Daz import: Genesis 9 brows %s (colour %s)" % [path.get_file(), c])


## A Genesis 8 Female figure (its body/eyelash meshes are named Genesis8Female...).
static func _is_female(scene: Node) -> bool:
	for m in scene.find_children("*", "MeshInstance3D", true, false):
		if String(m.name).to_lower().begins_with("genesis8female"):
			return true
	return false


## REV 579: Genesis 8.1's tear film mesh ("Female 8_1 Tear").
static func _is_tear(mesh_name: String) -> bool:
	return mesh_name.contains("tear") and not mesh_name.contains("hair")


## REV 579: a Genesis 8.1 figure. tools/crew/fbx_trim.py renames its body to Genesis8Female, but 8.1
## brings its own tear-film figure, which plain Genesis 8 doesn't have.
static func _is_genesis81(scene: Node) -> bool:
	for m in scene.find_children("*", "MeshInstance3D", true, false):
		if _is_tear(String(m.name).to_lower()):
			return true
	return false


static func _is_body(mesh_name: String) -> bool:
	if mesh_name.begins_with("genesis9"):
		# REV 751: Genesis 9's body is "Genesis9" alone - its eyes, mouth and tear film are meshes of their own
		return not (mesh_name.contains("eye") or mesh_name.contains("mouth") or mesh_name.contains("tear") or mesh_name.contains("brow"))
	return mesh_name.begins_with("genesis8") and not mesh_name.contains("eyelash") and not mesh_name.contains("brow")


## REV 751: one of the figure's own meshes (never clothing): Genesis 8 body/lashes, and Genesis 9's body, eyes,
## mouth, tear film, lashes and card brows (G9EyebrowCards).
static func _is_figure(mesh_name: String) -> bool:
	return mesh_name.begins_with("genesis8") or mesh_name.begins_with("genesis9") or mesh_name.begins_with("g9eyebrow")


## REV 751: a Genesis 9 figure (its body mesh is "Genesis9").
static func _is_genesis9(scene: Node) -> bool:
	for m in scene.find_children("*", "MeshInstance3D", true, false):
		if String(m.name).to_lower().begins_with("genesis9"):
			return true
	return false


## Every triangle of the clothing meshes (not hair, not eyelashes, not the body), in a spatial hash.
## (Daz clothing is low-poly - its corners can be 10 cm apart - so we test against its surface.)
func _collect_clothing(scene: Node) -> void:
	_cloth.clear()
	for m in scene.find_children("*", "MeshInstance3D", true, false):
		var mi := m as MeshInstance3D
		var nn := String(mi.name).to_lower()
		# REV 293: brow meshes aren't clothing either (same rule as _cloth_mesh above), so skin under a
		# separate brow mesh is no longer hidden as if it were under a sleeve
		if mi.mesh == null or _is_figure(nn) or nn.contains("eyelash") or nn.contains("brow") or nn.contains("hair") or nn.contains("cabelo") or nn.contains("cabello"):
			continue
		# REV 579: Genesis 8.1's tear film ("Female 8_1 Tear") lies just over the eyeballs - counted as
		# clothing, it hid the eyes as "skin under a sleeve" (Tuvall: black eyes in a white ring)
		if _is_tear(nn):
			continue
		for s in mi.mesh.get_surface_count():
			var a := mi.mesh.surface_get_arrays(s)
			var verts: PackedVector3Array = a[Mesh.ARRAY_VERTEX]
			var cn: PackedVector3Array = a[Mesh.ARRAY_NORMAL] if a[Mesh.ARRAY_NORMAL] != null else PackedVector3Array()
			var idx: PackedInt32Array = a[Mesh.ARRAY_INDEX] if a[Mesh.ARRAY_INDEX] != null else PackedInt32Array()
			for t in range(0, idx.size(), 3):
				# corners + the cloth's outward direction (its vertex normals), for the inside test
				var out_n := Vector3.ZERO
				if cn.size() == verts.size():
					out_n = cn[idx[t]] + cn[idx[t + 1]] + cn[idx[t + 2]]
				var tri := [verts[idx[t]], verts[idx[t + 1]], verts[idx[t + 2]], out_n]
				var p0: Vector3 = tri[0]
				var lo: Vector3 = p0.min(tri[1]).min(tri[2])
				var hi: Vector3 = p0.max(tri[1]).max(tri[2])
				for x in range(floori(lo.x / CELL), floori(hi.x / CELL) + 1):
					for y in range(floori(lo.y / CELL), floori(hi.y / CELL) + 1):
						for z in range(floori(lo.z / CELL), floori(hi.z / CELL) + 1):
							var c := Vector3i(x, y, z)
							if not _cloth.has(c):
								_cloth[c] = []
							(_cloth[c] as Array).append(tri)


## Is this skin point covered: does a short ray straight out of the skin hit clothing?
## (At the V of the collar or the end of a sleeve the ray misses, so that skin stays.)
func _covered(v: Vector3, n: Vector3) -> bool:
	if n.length() < 0.5:
		return false
	var from := v - n * 0.006
	var c := Vector3i(floori(v.x / CELL), floori(v.y / CELL), floori(v.z / CELL))
	for dx in range(-1, 2):
		for dy in range(-1, 2):
			for dz in range(-1, 2):
				var tris = _cloth.get(c + Vector3i(dx, dy, dz))
				if tris == null:
					continue
				for tri in tris:
					var hit = Geometry3D.ray_intersects_triangle(from, n, tri[0], tri[1], tri[2])
					if hit != null and from.distance_to(hit) < COVER_DIST:
						return true
	return _inside_clothing(from, n)


## REV 154: skin INSIDE the clothes further from the cloth than COVER_DIST - the armpit fold, where
## the sleeve hangs a few cm off the body and the skin poked out of McCoy's shirt as his arm swung
## back while running. Its ray meets the cloth from the inside (along the cloth's outward
## direction); a hand by the thigh meets the trousers from the outside, so it stays.
func _inside_clothing(from: Vector3, n: Vector3) -> bool:
	var to := from + n * INSIDE_DIST
	var lo := from.min(to)
	var hi := from.max(to)
	for x in range(floori(lo.x / CELL), floori(hi.x / CELL) + 1):
		for y in range(floori(lo.y / CELL), floori(hi.y / CELL) + 1):
			for z in range(floori(lo.z / CELL), floori(hi.z / CELL) + 1):
				var tris = _cloth.get(Vector3i(x, y, z))
				if tris == null:
					continue
				for tri in tris:
					var hit = Geometry3D.segment_intersects_triangle(from, to, tri[0], tri[1], tri[2])
					# REV 761 (Glen: Varel's "dark bit on his cheek"): a jaw point whose ray ran DOWN into the
					# inside of a high collar counted as "inside the clothes" and was cut away - a hole by the
					# jaw showing the dark inside of the mouth. Skin is only inside clothing that reaches up
					# round it: a hit well below the skin point (the collar under a jaw) doesn't count.
					if hit != null and (tri[3] as Vector3).dot(n) > 0.0 and (hit as Vector3).y > from.y - INSIDE_BELOW:
						return true
	return false


## REV 154: every visible (uncovered) skin point of the body, across all its surfaces - Daz splits
## the body by material, and the collar edge falls on the join of the face/neck and torso parts.
func _collect_visible_skin(am: ArrayMesh) -> void:
	_visible_skin.clear()
	for s in am.get_surface_count():
		var arr := am.surface_get_arrays(s)
		var verts: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
		var norms: PackedVector3Array = arr[Mesh.ARRAY_NORMAL]
		if norms.size() != verts.size():
			continue
		for i in verts.size():
			if not _covered(verts[i], norms[i]):
				var c := Vector3i((verts[i] / EDGE_KEEP_DIST).floor())
				if not _visible_skin.has(c):
					_visible_skin[c] = []   # a plain Array: a Packed array here would be appended to as a copy
				(_visible_skin[c] as Array).append(verts[i])
	_drop_small_visible_islands()


## Group the visible skin into connected areas (cells touching cells) and forget the small ones.
func _drop_small_visible_islands() -> void:
	var done := {}
	var dropped := 0
	for start in _visible_skin.keys():
		if done.has(start):
			continue
		var cells := [start]
		done[start] = true
		var i := 0
		var count := 0
		while i < cells.size():
			var c: Vector3i = cells[i]
			i += 1
			count += (_visible_skin[c] as Array).size()
			for dx in range(-1, 2):
				for dy in range(-1, 2):
					for dz in range(-1, 2):
						var nc := c + Vector3i(dx, dy, dz)
						if _visible_skin.has(nc) and not done.has(nc):
							done[nc] = true
							cells.append(nc)
		if count < MIN_VISIBLE_AREA:
			for c in cells:
				_visible_skin.erase(c)
			dropped += count
	print("Daz import: %d stray visible skin points treated as covered" % dropped)


func _near_visible_skin(v: Vector3) -> bool:
	var c := Vector3i((v / EDGE_KEEP_DIST).floor())
	for dx in range(-1, 2):
		for dy in range(-1, 2):
			for dz in range(-1, 2):
				var pts = _visible_skin.get(c + Vector3i(dx, dy, dz))
				if pts == null:
					continue
				for p in (pts as Array):
					if p.distance_to(v) < EDGE_KEEP_DIST:
						return true
	return false


## Drop the triangles whose three corners are all covered by clothing.
func _cull_covered(arr: Array) -> void:
	var verts: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
	var norms: PackedVector3Array = arr[Mesh.ARRAY_NORMAL]
	var idx: PackedInt32Array = arr[Mesh.ARRAY_INDEX] if arr[Mesh.ARRAY_INDEX] != null else PackedInt32Array()
	if idx.is_empty() or norms.size() != verts.size():
		return
	var cov := PackedByteArray()
	cov.resize(verts.size())
	for i in verts.size():
		# hidden unless it is (or is next to) real visible skin; _visible_skin holds the uncovered
		# points in big areas only, so stray "visible" islands under the clothes go too
		cov[i] = 0 if _near_visible_skin(verts[i]) else 1
	var keep := PackedInt32Array()
	for t in range(0, idx.size(), 3):
		if cov[idx[t]] == 1 and cov[idx[t + 1]] == 1 and cov[idx[t + 2]] == 1:
			_hidden_tris += 1
			continue
		keep.append(idx[t]); keep.append(idx[t + 1]); keep.append(idx[t + 2])
	if keep.is_empty():
		keep.append_array(PackedInt32Array([0, 0, 0]))   # a surface can't be empty
	arr[Mesh.ARRAY_INDEX] = keep

