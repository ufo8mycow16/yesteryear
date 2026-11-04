class_name CharacterDetail
extends RefCounted
## REV 221: skin detail for the Daz characters - pores and fine wrinkles that catch the light (normal
## map), where skin shines and where it's matte (roughness), and how much light glows through it
## (subsurface strength: ears, nostrils, fingers). Daz's FBX export leaves these behind; they come from
## Glen's Daz library through tools/crew/make_detail_maps.py into
##   res://assets/models/characters/detail/<export name>/<Surface>_normal|_rough|_sss.jpg
## Applied when a character is built (CharacterFace.make_model, CrewLooks.apply). Off at the LOW
## texture setting (older computers): the characters then look exactly as before.

const DIR := "res://assets/models/characters/detail/"
## Body surfaces -> which detail pictures they use (the same sharing as the colour pictures).
const SURFACE_SOURCE := {
	"Face": "Face", "Lips": "Face", "Ears": "Face", "EyeSocket": "Face",
	"Head": "Head", "Body": "Torso",      # REV 736: Genesis 8.1's own surfaces (Tuvall)
	"Torso": "Torso", "Arms": "Arms", "Fingernails": "Arms", "Legs": "Legs", "Toenails": "Legs",
}
const NORMAL_STRENGTH := 0.6
const SSS_STRENGTH := 0.35

static var _cache := {}   # path -> Texture2D (or null when missing)


static func enabled() -> bool:
	var tree := Engine.get_main_loop() as SceneTree
	var gs: Node = tree.root.get_node_or_null("/root/GameSettings") if tree != null else null
	if gs == null:
		return true
	return int(gs.get("texture_quality")) < 2


## Adds detail to every Genesis 8 body mesh under root, using the pictures made for `source`
## (an export name like "Kirk_daz" or "female_kate"). Returns how many surfaces got detail.
static func apply(root: Node, source: String) -> int:
	if source == "" or not enabled() or not DirAccess.dir_exists_absolute(DIR + source):
		return 0
	var done := 0
	for m in root.find_children("*", "MeshInstance3D", true, false):
		var mi := m as MeshInstance3D
		var n := String(mi.name).to_lower()
		if not (n.begins_with("genesis8male_shape") or n.begins_with("genesis8female_shape")):
			continue
		if mi.mesh == null:
			continue
		for s in mi.mesh.get_surface_count():
			var mat := mi.get_active_material(s) as StandardMaterial3D
			if mat == null:
				continue
			var src := _source_for(mat.resource_name)
			if src == "":
				continue
			var nrm := _tex(DIR + source + "/" + src + "_normal.jpg")
			var rough := _tex(DIR + source + "/" + src + "_rough.jpg")
			var sss := _tex(DIR + source + "/" + src + "_sss.jpg")
			if nrm == null and rough == null and sss == null:
				continue
			var nm := mat.duplicate() as StandardMaterial3D
			if nrm != null:
				nm.normal_enabled = true
				nm.normal_texture = nrm
				nm.normal_scale = NORMAL_STRENGTH
			if rough != null:
				nm.roughness = 1.0
				nm.roughness_texture = rough
				nm.roughness_texture_channel = BaseMaterial3D.TEXTURE_CHANNEL_GRAYSCALE
			if sss != null:
				# REV 736: always - Genesis 8.1's Head/Body surfaces never had subsurface switched on by the importer
				nm.subsurf_scatter_enabled = true
				nm.subsurf_scatter_skin_mode = true
				nm.subsurf_scatter_texture = sss
				nm.subsurf_scatter_strength = SSS_STRENGTH
			mi.set_surface_override_material(s, nm)
			done += 1
	return done


static func _source_for(mat_name: String) -> String:
	for k in SURFACE_SOURCE:
		if mat_name == k or mat_name.begins_with(k):
			return SURFACE_SOURCE[k]
	return ""


static func _tex(path: String) -> Texture2D:
	if _cache.has(path):
		return _cache[path]
	var t: Texture2D = load(path) if ResourceLoader.exists(path) else null
	_cache[path] = t
	return t
