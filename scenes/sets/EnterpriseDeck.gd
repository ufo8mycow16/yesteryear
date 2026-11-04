extends Node3D
## An Enterprise deck from Vulcan Fury, as a backdrop for cutscenes: the converted map, Glen's HD textures
## (HdTextures.apply) and the map's own baked light (assets/shaders/baked_lightmap.gdshader), at Vulcan Fury's
## 80% deck scale. No doors, collision, player or HUD - Vulcan Fury's ModelRoom does all that for play; this
## is only the set. Positions given to this script are in the map's own metres (Quake units x 0.03);
## at() turns them into game positions.

const SHADER := "res://assets/shaders/baked_lightmap.gdshader"
const DECK_SCALE := 0.8

@export var model_path := ""
@export var lightmap_path := ""
@export var boost := 1.2
@export var chroma := 0.21

var deck: Node3D = null


func _ready() -> void:
	if model_path == "" or not ResourceLoader.exists(model_path):
		push_warning("EnterpriseDeck: missing " + model_path)
		return
	var packed := load(model_path) as PackedScene
	if packed == null:
		return
	deck = packed.instantiate() as Node3D
	deck.name = "Deck"
	deck.scale = Vector3.ONE * DECK_SCALE
	add_child(deck)
	var extra_path := model_path.get_basename() + "_extra.glb"
	if ResourceLoader.exists(extra_path):
		var extra := (load(extra_path) as PackedScene).instantiate() as Node3D
		if extra != null:
			deck.add_child(extra)
	if ClassDB.class_exists("HdTextures") or ResourceLoader.exists("res://core/ship/HdTextures.gd"):
		HdTextures.apply(deck)
	_bake(deck)
	_environment()


## Map metres -> game position. y is metres above the map's zero (Deck 7's floor is 0, Deck 5's is 8.16).
func at(x: float, y: float, z: float) -> Vector3:
	return Vector3(x, y, z) * DECK_SCALE


func _bake(root: Node) -> void:
	var shader: Shader = load(SHADER) if ResourceLoader.exists(SHADER) else null
	var lightmap: Texture2D = load(lightmap_path) if ResourceLoader.exists(lightmap_path) else null
	if shader == null or lightmap == null:
		push_warning("EnterpriseDeck: baked light missing - flat light instead")
		return
	var texel := Vector2(1.0 / maxf(float(lightmap.get_width()), 1.0), 1.0 / maxf(float(lightmap.get_height()), 1.0))
	for node in root.find_children("*", "MeshInstance3D", true, false):
		var mi := node as MeshInstance3D
		if mi.mesh == null:
			continue
		for s in mi.mesh.get_surface_count():
			var src: Material = mi.get_surface_override_material(s)
			if src == null:
				src = mi.mesh.surface_get_material(s)
			if not (src is StandardMaterial3D):
				continue
			var std := src as StandardMaterial3D
			if std.transparency != BaseMaterial3D.TRANSPARENCY_DISABLED:
				continue
			var sm := ShaderMaterial.new()
			sm.shader = shader
			sm.set_shader_parameter("lightmap_tex", lightmap)
			sm.set_shader_parameter("albedo_color", std.albedo_color)
			sm.set_shader_parameter("use_albedo_tex", 1.0 if std.albedo_texture != null else 0.0)
			if std.albedo_texture != null:
				sm.set_shader_parameter("albedo_tex", std.albedo_texture)
			sm.set_shader_parameter("light_boost", boost)
			sm.set_shader_parameter("soft_light", 0.0)
			sm.set_shader_parameter("lm_texel", texel)
			sm.set_shader_parameter("grade_strength", 0.15)
			sm.set_shader_parameter("ceiling_grey", 1.2)
			sm.set_shader_parameter("ambient_floor", 0.06)
			sm.set_shader_parameter("chroma_limit", chroma)
			sm.set_shader_parameter("mood_on", 0.0)
			mi.set_surface_override_material(s, sm)


func _environment() -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.0, 0.0, 0.0)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.55, 0.52, 0.6)
	env.ambient_light_energy = 0.55
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.glow_enabled = true
	env.glow_intensity = 0.4
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)
	# soft key light for the characters (the map's baked light only lights the map)
	var key := DirectionalLight3D.new()
	key.light_color = Color(1.0, 0.94, 0.86)
	key.light_energy = 0.55
	key.rotation_degrees = Vector3(-50.0, 30.0, 0.0)
	key.shadow_enabled = false
	add_child(key)
