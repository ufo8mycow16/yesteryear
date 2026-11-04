class_name DazOutfit
extends RefCounted
## REV 881: put a converted Daz outfit on a Genesis 8 Female figure at runtime (Glen, 4 Nov: Vulcan women in gowns).
##
## The outfit is old Genesis clothing carried onto Genesis 8 Female by tools/crew/genesis1_to_g8f.py (Glen's RSSY
## converter's go-between garments, read without Daz), fitted to Uhura's body - the body every crew woman is built on
## (CrewLooks.BASE) - and thinned in Blender. assets/models/characters/outfits/<name>.json + .bin hold it in the
## library_hair format: Daz centimetres, skin weights by bone NAME, one surface per piece and material; each surface's
## picture is "<piece>_{variant}.jpg" (tools/textures/recolour_royal_gown.py makes the colourways).
##
## wear() builds it beside the figure's body, skinned to the body's own skeleton with the body's own bind poses (the
## importer's _add_library_part, done at runtime), and hides the figure's other clothing (her Starfleet dress, boots).
## The mesh is built once per outfit and kept; each wearer gets her own Skin.
##
##   DazOutfit.wear(fig, "royal_gown", "rust", {"leave_off": ["cape"]})

const DIR := "res://assets/models/characters/outfits/"
## Pieces of each outfit and what they are (for leave_off). Royal gown (Glen's Royal Elf for Genesis):
##   gown, overtunic, sash, boots, cape (the cape has a train - leave it off anyone who walks)
const VARIANTS := {"royal_gown": ["rust", "sand", "plum"]}

static var _meshes := {}     # "<outfit>|<variant>|<left off>|<scale>" -> [ArrayMesh, bone names per bind slot]
static var _py := {}         # outfit -> its points_y (the fitted body's height range, cm)


## Dress the figure. Returns the outfit's MeshInstance3D (null if the figure has no Genesis 8 body or the outfit
## files are missing - the figure is left as it was).
static func wear(fig: Node3D, outfit: String, variant: String = "", opts: Dictionary = {}) -> MeshInstance3D:
	var body := _body_of(fig)
	if body == null:
		return null
	var sk := body.get_node_or_null(body.skeleton) as Skeleton3D
	if sk == null:
		return null
	if variant == "":
		variant = String((VARIANTS.get(outfit, ["rust"]) as Array)[0])
	var leave_off: Array = opts.get("leave_off", [])
	var py := _points_y(outfit)
	if py.is_empty():
		return null
	# the outfit's centimetres -> this body's mesh units (the importer's _add_library_part does the same)
	var k := body.mesh.get_aabb().size.y / maxf(float(py[1]) - float(py[0]), 0.001)
	var key := "%s|%s|%s|%.4f" % [outfit, variant, ",".join(PackedStringArray(leave_off)), k]
	if not _meshes.has(key):
		var built := _build(outfit, variant, leave_off, k)
		if built.is_empty():
			return null
		_meshes[key] = built
	var mesh: ArrayMesh = _meshes[key][0]
	var names: Array = _meshes[key][1]
	# the body's bind poses by bone name; a bone the body isn't bound to uses its nearest bound parent
	var bind_of := {}
	for b in body.skin.get_bind_count():
		bind_of[String(body.skin.get_bind_name(b))] = body.skin.get_bind_pose(b)
	var skin := Skin.new()
	for bn in names:
		var use := String(bn)
		var bi := sk.find_bone(use)
		while not bind_of.has(use) and bi >= 0:
			bi = sk.get_bone_parent(bi)
			use = sk.get_bone_name(bi) if bi >= 0 else ""
		if not bind_of.has(use):
			use = "hip" if bind_of.has("hip") else String(bind_of.keys()[0])
		skin.add_named_bind(use, bind_of[use])
	var mi := MeshInstance3D.new()
	mi.name = "Outfit_" + outfit
	mi.mesh = mesh
	mi.skin = skin
	mi.layers = body.layers
	body.get_parent().add_child(mi)
	mi.transform = body.transform
	mi.skeleton = mi.get_path_to(sk)
	_hide_other_clothes(fig, body, mi)
	fig.set_meta("outfit", outfit)
	return mi


static func _body_of(fig: Node) -> MeshInstance3D:
	for m in fig.find_children("*", "MeshInstance3D", true, false):
		var n := String(m.name).to_lower()
		if n.begins_with("genesis8") and not n.contains("eyelash") and not n.contains("brow") and (m as MeshInstance3D).skin != null:
			return m as MeshInstance3D
	return null


## Everything that isn't her body, lashes, hair or the new outfit goes (Uhura's dress and boots on the crew women).
static func _hide_other_clothes(fig: Node, body: MeshInstance3D, keep: MeshInstance3D) -> void:
	for m in fig.find_children("*", "MeshInstance3D", true, false):
		if m == body or m == keep:
			continue
		var n := String(m.name).to_lower()
		if n.begins_with("genesis8") or n.begins_with("crewhair") or n.contains("cabelo") or n.contains("hair") \
				or n.begins_with("outfit_"):
			continue
		(m as MeshInstance3D).visible = false


static func _points_y(outfit: String) -> Array:
	if not _py.has(outfit):
		var jp := DIR + outfit + ".json"
		if not FileAccess.file_exists(jp):
			return []
		var meta = JSON.parse_string(FileAccess.get_file_as_string(jp))
		if not (meta is Dictionary):
			return []
		_py[outfit] = meta["points_y"]
	return _py[outfit]


## The mesh in the body's mesh units (k = units per outfit centimetre), bones by name in bind-slot order.
static func _build(outfit: String, variant: String, leave_off: Array, k: float) -> Array:
	var jp := DIR + outfit + ".json"
	if not FileAccess.file_exists(jp):
		return []
	var meta = JSON.parse_string(FileAccess.get_file_as_string(jp))
	var blob := FileAccess.get_file_as_bytes(DIR + outfit + ".bin")
	if not (meta is Dictionary) or blob.is_empty():
		return []
	var mesh := ArrayMesh.new()
	mesh.resource_name = "Outfit_" + outfit
	var mats := {}
	for s in meta["surfaces"]:
		var piece := String(s.get("piece", ""))
		if leave_off.has(piece):
			continue
		var pos := _floats(blob, s["pos"])
		var nrm := _floats(blob, s["nrm"])
		var uvf := _floats(blob, s["uv"])
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
		var arrays := []
		arrays.resize(Mesh.ARRAY_MAX)
		arrays[Mesh.ARRAY_VERTEX] = v
		arrays[Mesh.ARRAY_NORMAL] = nn
		arrays[Mesh.ARRAY_TEX_UV] = uv
		arrays[Mesh.ARRAY_BONES] = _ints(blob, s["joints"])
		arrays[Mesh.ARRAY_WEIGHTS] = _floats(blob, s["weights"])
		arrays[Mesh.ARRAY_INDEX] = _ints(blob, s["index"])
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
		var pic := String(s.get("picture", "")).replace("{variant}", variant)
		if not mats.has(pic):
			var mat := StandardMaterial3D.new()
			mat.resource_name = piece
			if pic != "" and ResourceLoader.exists(pic):
				mat.albedo_texture = load(pic)
			mat.roughness = 0.88
			mat.cull_mode = BaseMaterial3D.CULL_DISABLED     # cloth: the inside of a sleeve or hem shows
			mats[pic] = mat
		mesh.surface_set_name(mesh.get_surface_count() - 1, piece + "/" + String(s["material"]))
		mesh.surface_set_material(mesh.get_surface_count() - 1, mats[pic])
	if mesh.get_surface_count() == 0:
		return []
	return [mesh, meta["bones"]]


static func _floats(blob: PackedByteArray, x: Dictionary) -> PackedFloat32Array:
	var at := int(x["at"])
	return blob.slice(at, at + int(x["count"]) * 4).to_float32_array()


static func _ints(blob: PackedByteArray, x: Dictionary) -> PackedInt32Array:
	var at := int(x["at"])
	return blob.slice(at, at + int(x["count"]) * 4).to_int32_array()
