class_name VulcanTerrain
extends RefCounted
## REV 883 - Glen's World Creator desert basin round the desert rooms (the far landscape and mountains).
##
## One mesh for every room (assets/models/vulcan_desert/terrain/terrain.glb - 4 km square, 16 m between heights, made
## by tools/terrain/build_vulcan_terrain.py from Glen's heightmap-2k.obj and its 8K maps), each room standing on its
## own spot (spots.json: city's edge on the basin's north side, the waystation on the western slope, the desert
## search out on the basin floor, the ruins under the south-eastern ridges). terrain.gdshader flattens the room's
## patch and fills lower valleys, so the room's own sand tiles always lie on top and the slopes rise beyond them.
## Seen only far off through the haze; never solid (the rooms keep their own floors and walls).
##
##   VulcanTerrain.place(self, "waystation")            # in build_room(), after VulcanDesert.ground()

const DIR := "res://assets/models/vulcan_desert/terrain/"
## the basin's rust is redder than the sand tiles in the rooms; pulled a little toward them
const TINT := Color(1.06, 0.92, 0.86)

static var _spots := {}
static var _mesh: Mesh = null


static func spots() -> Dictionary:
	if _spots.is_empty() and FileAccess.file_exists(DIR + "spots.json"):
		var d = JSON.parse_string(FileAccess.get_file_as_string(DIR + "spots.json"))
		if d is Dictionary:
			_spots = d
	return _spots


static func _terrain_mesh() -> Mesh:
	if _mesh == null and ResourceLoader.exists(DIR + "terrain.glb"):
		var inst := (load(DIR + "terrain.glb") as PackedScene).instantiate()
		for mi in inst.find_children("*", "MeshInstance3D", true, false):
			_mesh = (mi as MeshInstance3D).mesh
			break
		inst.free()
	return _mesh


## Put the landscape round the room, the room standing on spot `key`. `yaw_deg` turns the land under the room (so a
## room can face a different ridge); `centre` = where the room's ground centre is. Returns the node (or null).
static func place(room: Node3D, key: String, yaw_deg := 0.0, centre := Vector3.ZERO, flat_radius := 90.0) -> MeshInstance3D:
	var s: Dictionary = spots().get(key, {})
	var mesh := _terrain_mesh()
	if s.is_empty() or mesh == null:
		return null
	var spot := Vector2(float(s["x"]), float(s["z"]))
	var mi := MeshInstance3D.new()
	mi.name = "VulcanTerrain"
	mi.mesh = mesh
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.extra_cull_margin = 300.0          # the shader moves points up and down
	var m := ShaderMaterial.new()
	m.shader = load("res://core/vulcan/terrain.gdshader")
	if ResourceLoader.exists(DIR + "terrain_colour.jpg"):
		m.set_shader_parameter("colour_tex", load(DIR + "terrain_colour.jpg"))
	if ResourceLoader.exists(DIR + "terrain_normal.png"):
		m.set_shader_parameter("normal_tex", load(DIR + "terrain_normal.png"))
	m.set_shader_parameter("tint", TINT)
	m.set_shader_parameter("spot", spot)
	m.set_shader_parameter("spot_h", float(s["h"]))
	m.set_shader_parameter("flat_radius", flat_radius)
	mi.material_override = m
	room.add_child(mi)
	# the spot (at its ground height) lands on the room's ground centre, turned by yaw
	var yaw := deg_to_rad(yaw_deg + float(s.get("yaw", 0.0)))
	var b := Basis(Vector3.UP, yaw)
	mi.basis = b
	mi.position = centre - b * Vector3(spot.x, float(s["h"]), spot.y)
	return mi
