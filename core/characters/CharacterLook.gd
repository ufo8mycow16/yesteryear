class_name CharacterLook
extends RefCounted
## REV 736 (Glen, comparing Tuvall in the game with her Daz store picture: "I want these characters looking
## so much better"). The last step in building any Daz character (CharacterKit.make_named for the story
## people, CrewLooks.apply for the crew) - after every skin, hair and dress swap - that makes them read as
## people rather than dolls:
##  - EYES: the irises keep their real colour (the importer greyed them to 74% for McCoy in October - it
##    made every eye near-black in a dim room), and the clear outer layer of the eye now adds a wet shine
##    (catchlights). It was drawn fully see-through, which in this engine hides its shine too.
##  - SKIN: the general-purpose skin material becomes daz_skin.gdshader (oily sheen, light through thin
##    skin, close-up pore texture, soft edge) - everything already set up on it is carried over.
##  - HAIR: card hair (hair_cards.gdshader) gets a soft second pass for the strand fringes
##    (hair_cards_soft.gdshader) - the grain Glen saw on Tuvall's hair.
##  - LIGHT: every mesh of the character also draws on the people-only light layer, so FaceLight (and
##    ModernLighting's key) can light faces without lighting the room.
## The skin and hair passes are skipped at the LOW graphics preset (older computers keep the old look).

const SKIN_SHADER := preload("res://core/characters/daz_skin.gdshader")
const HAIR_SOFT_SHADER := preload("res://core/characters/hair_cards_soft.gdshader")
const HAIR_SHADER_PATH := "res://core/characters/hair_cards.gdshader"
const MICRO_NORMAL := "res://assets/models/characters/detail/_micro/skin_micro_normal.jpg"
## The people-only light layer (the same bit as ModernLighting.CHAR_LAYER - layer 20).
const CHAR_LAYER := 1 << 19
## REV 740: crease shading maps, one folder per figure (tools/crew/bake_skin_ao.py; map.json = surface ->
## picture). Story people by their key, background crew by "crew_male" / "crew_female".
const AO_DIR := "res://assets/models/characters/ao/"
## REV 845: roles played by the same model share its crease maps (Varel's Episode 2 cover had none).
const AO_SAME_AS := {"senior_specialist": "varel", "tech_specialist": "kovek", "archive_specialist": "tovan"}
static var _ao_maps := {}

## Skin surfaces that get the skin material (lower case; Genesis 8 and 8.1 names). The mouth and teeth stay
## as they are (CharacterFace._darken_mouth shades them).
const SKIN := ["face", "lips", "ears", "eyesocket", "head", "torso", "body", "arms", "legs", "fingernails",
	"toenails", "genitalia"]
## Per surface: [close-up texture strength, oily sheen, light-through (sss) strength]
const SKIN_TUNING := {
	# REV 737: the sheen cut to nothing except lips and nails (0.14-0.45 read as wet plastic, Glen)
	# REV 844: face/eyesocket/lips/head light-through cut 0.40-0.45 -> 0.10. Godot's skin glow is a screen blur that
	# smears the PICTURE too - brows, eyeliner, eye shadow and lip edges melted into the skin (Tuvall's black brows
	# came out pale red-brown, her makeup vanished). Ears keep theirs (they glow when backlit).
	"face": [0.30, 0.0, 0.10], "ears": [0.25, 0.0, 0.55], "eyesocket": [0.20, 0.0, 0.08],
	"lips": [0.10, 0.12, 0.10], "head": [0.20, 0.0, 0.12], "torso": [0.25, 0.0, 0.35],
	"body": [0.25, 0.0, 0.35], "arms": [0.25, 0.0, 0.40], "legs": [0.25, 0.0, 0.35],
	"fingernails": [0.0, 0.25, 0.20], "toenails": [0.0, 0.20, 0.20], "genitalia": [0.20, 0.0, 0.35],
}
## REV 844: these surfaces use their SKIN_TUNING light-through as it is (the Daz export's own, higher, value is ignored).
const SSS_CAPPED := ["face", "eyesocket", "lips", "head"]
## REV 736: iris colour as a share of the picture (the importer's 0.74 grey made them near-black).
const IRIS_TONE := Color(0.96, 0.95, 0.93)
## REV 841: a character whose iris picture is the wrong colour gets it tinted here (picture x colour; over 1 = brighter).
## Tuvall (Glen, with T'Nal's store picture): her export's irises came out grey-blue - the store picture is warm hazel.
const IRIS_TINTS := {
	# (REV 842: Tuvall now wears her kit's own hazel eye picture instead - CharacterKit.REAL_MODEL_SKIN)
}
static var _iris_tone := IRIS_TONE
const SCLERA_TONE := Color(0.78, 0.75, 0.72)   # REV 740: was 0.88 - the whites glared ("doll eyes")
const G9_EYE_TONE := Color(0.86, 0.84, 0.81)   # REV 751: Genesis 9's one-picture eyeball (whites + iris together)


static func _preset() -> int:
	var tree := Engine.get_main_loop() as SceneTree
	var gs: Node = tree.root.get_node_or_null("/root/GameSettings") if tree != null else null
	return int(gs.get("quality_preset")) if gs != null else 2


## Upgrade one built character (its whole node tree). Safe to call twice.
static func apply(root: Node, ao_key: String = "") -> void:
	if root == null:
		return
	_iris_tone = IRIS_TINTS.get(ao_key, IRIS_TONE)
	var rich := _preset() >= 1
	var ao := _ao_map(ao_key)
	var micro: Texture2D = load(MICRO_NORMAL) if _preset() >= 2 and ResourceLoader.exists(MICRO_NORMAL) else null   # HIGH and up
	for m in root.find_children("*", "MeshInstance3D", true, false):
		var mi := m as MeshInstance3D
		if mi.mesh == null:
			continue
		mi.layers = mi.layers | CHAR_LAYER
		for s in mi.mesh.get_surface_count():
			var mat := mi.get_active_material(s)
			if mat == null or mat.has_meta("vf_look"):
				continue
			var low := String(mat.resource_name).to_lower()
			var std := mat as StandardMaterial3D
			if std != null:
				var eye := _eye_material(std, low)
				if eye != null:
					mi.set_surface_override_material(s, eye)
					continue
				if rich and _is_skin(low) and std.transparency == BaseMaterial3D.TRANSPARENCY_DISABLED:
					mi.set_surface_override_material(s, _skin_material(std, low, micro, _ao_for(ao, low)))
				continue
			var sm := mat as ShaderMaterial
			if rich and sm != null and sm.shader != null and sm.shader.resource_path == HAIR_SHADER_PATH and sm.next_pass == null:
				var hm := sm.duplicate() as ShaderMaterial
				hm.next_pass = _hair_soft(sm)
				hm.set_meta("vf_look", true)
				mi.set_surface_override_material(s, hm)


static func _is_skin(low: String) -> bool:
	for k in SKIN:
		if low == k or low.begins_with(k + ".") or low.begins_with(k + "_"):
			return true
	return false


static func _tuning(low: String) -> Array:
	for k in SKIN_TUNING:
		if low == k or low.begins_with(String(k)):
			return SKIN_TUNING[k]
	return [0.25, 0.16, 0.35]


## The eye's surfaces (Genesis 8 / 8.1 names), or null for anything else.
static func _eye_material(std: StandardMaterial3D, low: String) -> StandardMaterial3D:
	if low.contains("cornea") or low.contains("eyemoisture") or low == "tear" or low.begins_with("tear."):
		# The wet layer over the eye: nothing but its shine. Added on top (black adds nothing), so the
		# highlight of every light - and the face light's catchlight - shows, where fully see-through hid it.
		var w := std.duplicate() as StandardMaterial3D
		w.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		w.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
		w.albedo_texture = null
		w.albedo_color = Color(0, 0, 0, 1)
		# REV 737: gentler - at 0.9 the room's reflection lay over the whole eye like a milky film (McCoy)
		w.roughness = 0.06 if not low.contains("tear") else 0.12
		w.metallic_specular = 0.45 if low.contains("cornea") else 0.3
		w.shading_mode = BaseMaterial3D.SHADING_MODE_PER_PIXEL
		w.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED
		w.set_meta("vf_look", true)
		return w
	if low == "irises" or low.begins_with("iris"):
		var i := std.duplicate() as StandardMaterial3D
		i.albedo_color = _iris_tone
		i.roughness = 0.35
		i.metallic_specular = 0.3
		i.set_meta("vf_look", true)
		return i
	if low == "sclera" or low.begins_with("sclera"):
		var c := std.duplicate() as StandardMaterial3D
		c.albedo_color = SCLERA_TONE
		c.roughness = 0.4
		c.set_meta("vf_look", true)
		return c
	if low.begins_with("eye left") or low.begins_with("eye right"):
		# REV 751: Genesis 9's eyeball is ONE picture (white, iris and pupil) - toned between Genesis 8's whites
		# and irises, so the whites don't glare and the iris keeps its colour
		var g := std.duplicate() as StandardMaterial3D
		g.albedo_color = G9_EYE_TONE
		g.roughness = 0.38
		g.metallic_specular = 0.28
		g.set_meta("vf_look", true)
		return g
	return null


## The figure's crease map {surface (lower case): Texture2D}, or {} if it has none.
static func _ao_map(key: String) -> Dictionary:
	if key == "":
		return {}
	key = String(AO_SAME_AS.get(key, key))
	if _ao_maps.has(key):
		return _ao_maps[key]
	var out := {}
	var path := AO_DIR + key + "/map.json"
	if FileAccess.file_exists(path):
		var data = JSON.parse_string(FileAccess.get_file_as_string(path))
		if data is Dictionary:
			for surf in data:
				var pic := AO_DIR + key + "/" + String(data[surf])
				if ResourceLoader.exists(pic):
					out[String(surf).to_lower()] = load(pic)
	_ao_maps[key] = out
	return out


static func _ao_for(ao: Dictionary, low: String) -> Texture2D:
	for k in ao:
		if low == k or low.begins_with(String(k) + ".") or low.begins_with(String(k) + "_"):
			return ao[k]
	return null


static func _skin_material(std: StandardMaterial3D, low: String, micro: Texture2D, ao: Texture2D = null) -> ShaderMaterial:
	var t := _tuning(low)
	var sm := ShaderMaterial.new()
	sm.shader = SKIN_SHADER
	sm.resource_name = std.resource_name          # other code finds surfaces by material name
	sm.set_shader_parameter("albedo", std.albedo_color)
	sm.set_shader_parameter("albedo_tex", std.albedo_texture)
	sm.set_shader_parameter("use_vertex_colour", std.vertex_color_use_as_albedo)
	sm.set_shader_parameter("uv1_scale", std.uv1_scale)
	sm.set_shader_parameter("uv1_offset", std.uv1_offset)
	var has_n := std.normal_enabled and std.normal_texture != null
	sm.set_shader_parameter("has_normal", has_n)
	if has_n:
		sm.set_shader_parameter("normal_tex", std.normal_texture)
		sm.set_shader_parameter("normal_strength", std.normal_scale)
	var has_r := std.roughness_texture != null
	sm.set_shader_parameter("has_rough", has_r)
	if has_r:
		sm.set_shader_parameter("rough_tex", std.roughness_texture)
	sm.set_shader_parameter("roughness_value", std.roughness)
	sm.set_shader_parameter("specular_value", minf(std.metallic_specular, 0.32))
	if std.subsurf_scatter_texture != null:
		sm.set_shader_parameter("sss_tex", std.subsurf_scatter_texture)
	sm.set_shader_parameter("sss_strength", float(t[2]) if SSS_CAPPED.has(low.get_slice(".", 0)) else maxf(float(t[2]), std.subsurf_scatter_strength if std.subsurf_scatter_enabled else 0.0))
	sm.set_shader_parameter("sheen", float(t[1]))
	sm.set_shader_parameter("has_micro", micro != null and float(t[0]) > 0.0)
	if micro != null:
		sm.set_shader_parameter("micro_normal", micro)
		sm.set_shader_parameter("micro_strength", float(t[0]))
	sm.set_shader_parameter("has_ao", ao != null)
	if ao != null:
		sm.set_shader_parameter("ao_tex", ao)
	sm.set_meta("vf_look", true)
	return sm


static func _hair_soft(base: ShaderMaterial) -> ShaderMaterial:
	var soft := ShaderMaterial.new()
	soft.shader = HAIR_SOFT_SHADER
	for p in ["strands", "hair_color", "cutoff", "mip_boost", "head_centre", "round_normals", "use_round_normals",
			"roughness_value", "specular_value"]:
		var v = base.get_shader_parameter(p)
		if v != null:
			soft.set_shader_parameter(p, v)
	soft.render_priority = 1
	return soft
