class_name AdobeLook
extends RefCounted
## REV 871 - THE ADOBE LOOK for Shi'Kahr's guest rooms (Glen sent the Polish Clothing Store, 4 Nov: "I just thought it
## might look like it was meant to be there"). Warm sandstone plaster, a pale flagstone floor, dark timber beams
## under a skylight strip, and the store's own furniture - clay pots with trees, rugs, poufs, low tables, wall
## hangings - dropped where the room has space.
##
## A room turns it on with `adobe_look = true` in describe_room(); EpisodeRoom calls apply() right after build_room().
## It changes only what you SEE: the shell's boxes keep their collision, nothing is added on a hotspot, a doorway or
## a piece of furniture (every prop checks for clear floor first), and pots/plants are not solid (nobody gets stuck).
##
## Pictures: the store's baked atlases cut into tileable squares (tools/textures/make_adobe_tiles.py ->
## assets/models/vulcan_rooms/adobe/tiles/); props: assets/models/vulcan_rooms/adobe/pcs_*.gltf (converted with
## tools/props/daz_city/daz_prop_to_gltf.py). docs/systems/vulcan-sets.md "Adobe look".

const ROOT := "res://assets/models/vulcan_rooms/adobe/"
const TILES := ROOT + "tiles/"
const BEAM := Color(0.36, 0.23, 0.15)
const SKYLIGHT := Color(1.0, 0.93, 0.80)

static var _mats := {}


static func _tex(path: String) -> Texture2D:
	return load(path) as Texture2D if ResourceLoader.exists(path) else null


static func _mat(kind: String) -> StandardMaterial3D:
	if _mats.has(kind):
		return _mats[kind]
	var m := StandardMaterial3D.new()
	m.uv1_triplanar = true
	m.uv1_world_triplanar = true
	m.roughness = 0.92
	match kind:
		"floor":
			m.albedo_texture = _tex(TILES + "adobe_floor_basecolor.jpg")
			m.normal_texture = _tex(TILES + "adobe_floor_normal.jpg")
			m.uv1_scale = Vector3(0.33, 0.33, 0.33)
			m.albedo_color = Color(1.0, 0.95, 0.92)
			m.roughness = 0.8
		"ceiling":
			m.albedo_texture = _tex(TILES + "adobe_plaster_basecolor.jpg")
			m.uv1_scale = Vector3(0.4, 0.4, 0.4)
			m.albedo_color = Color(0.82, 0.74, 0.68)
		_:
			m.albedo_texture = _tex(TILES + "adobe_plaster_basecolor.jpg")
			m.normal_texture = _tex(TILES + "adobe_plaster_normal.jpg")
			m.uv1_scale = Vector3(0.4, 0.4, 0.4)
			m.albedo_color = Color(0.98, 0.90, 0.84)
	m.normal_enabled = m.normal_texture != null
	if m.albedo_texture == null:     # pictures missing: the plain warm colours still read as adobe
		m.albedo_color = {"floor": Color(0.62, 0.52, 0.46), "ceiling": Color(0.70, 0.56, 0.44)}.get(kind, Color(0.86, 0.64, 0.48))
	_mats[kind] = m
	return m


static func _skin(room: Node3D, node_name: String, kind: String) -> void:
	var b := room.get_node_or_null(node_name)
	if b == null:
		return
	for c in b.get_children():
		if c is MeshInstance3D:
			(c as MeshInstance3D).material_override = _mat(kind)


## Everything in the room that isn't the shell - furniture, hotspots, people - as flat (x, z) points.
static func _occupied(room: Node3D) -> Array:
	var pts: Array = []
	for c in room.get_children():
		if not (c is Node3D):
			continue
		var n := String(c.name)
		if n in ["Floor", "Ceiling", "WallN", "WallS", "WallE", "WallW", "Adobe"] or c is Light3D or c is WorldEnvironment or c is Camera3D:
			continue
		var p := (c as Node3D).position
		pts.append(Vector2(p.x, p.z))
	return pts


static func _clear(pts: Array, at: Vector2, r: float) -> bool:
	for p in pts:
		if (p as Vector2).distance_to(at) < r:
			return false
	return true


static func prop(parent: Node3D, piece: String, pos: Vector3, yaw_deg := 0.0, scale := 1.0) -> Node3D:
	var path := ROOT + "pcs_" + piece + ".gltf"
	if not ResourceLoader.exists(path):
		return null
	var node := (load(path) as PackedScene).instantiate() as Node3D
	node.name = piece
	node.position = pos
	node.rotation_degrees.y = yaw_deg
	node.scale = Vector3.ONE * scale
	parent.add_child(node)
	return node


## The look, for a room built by EpisodeRoom.build_shell() (centred on 0,0, floor at 0).
static func apply(room: Node3D, size: Vector3) -> void:
	var occupied := _occupied(room)
	_skin(room, "Floor", "floor")
	_skin(room, "Ceiling", "ceiling")
	for w in ["WallN", "WallS", "WallE", "WallW"]:
		_skin(room, w, "wall")
	var root := Node3D.new()
	root.name = "Adobe"
	room.add_child(root)
	var w := size.x
	var d := size.z
	var h := size.y
	var along_x := w >= d
	var length := w if along_x else d
	var span := d if along_x else w
	# timber beams across the short way, and a skylight strip between them down the middle
	var beam_mat := StandardMaterial3D.new()
	beam_mat.albedo_color = BEAM
	beam_mat.roughness = 0.75
	var n := maxi(2, int(length / 2.2))
	for i in n:
		var t := -length * 0.5 + (float(i) + 0.5) * length / float(n)
		var bm := MeshInstance3D.new()
		var mesh := BoxMesh.new()
		mesh.size = Vector3(0.22, 0.24, span) if along_x else Vector3(span, 0.24, 0.22)
		bm.mesh = mesh
		bm.material_override = beam_mat
		bm.position = Vector3(t, h - 0.12, 0.0) if along_x else Vector3(0.0, h - 0.12, t)
		root.add_child(bm)
	var sky := MeshInstance3D.new()
	var sm := BoxMesh.new()
	sm.size = Vector3(length * 0.7, 0.02, minf(1.4, span * 0.25)) if along_x else Vector3(minf(1.4, span * 0.25), 0.02, length * 0.7)
	sky.mesh = sm
	var skym := StandardMaterial3D.new()
	skym.albedo_color = SKYLIGHT
	skym.emission_enabled = true
	skym.emission = SKYLIGHT
	skym.emission_energy_multiplier = 1.3
	sky.material_override = skym
	sky.position = Vector3(0.0, h - 0.005, 0.0)
	sky.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(sky)
	var light := OmniLight3D.new()
	light.light_color = Color(1.0, 0.88, 0.72)
	light.light_energy = 0.55
	light.omni_range = length * 0.8
	light.position = Vector3(0.0, h - 0.6, 0.0)
	root.add_child(light)
	# a rug in the middle, if the middle is clear
	if _clear(occupied, Vector2.ZERO, 1.2) and span >= 5.0:
		prop(root, "carpet_01" if hash(String(room.name)) % 2 == 0 else "carpet_02", Vector3(0.0, 0.012, 0.0), 0.0 if along_x else 90.0, minf(1.0, span * 0.14))
	# clay pots with trees, in whichever corners are clear (scaled to the ceiling)
	var tree_scale := clampf((h - 0.4) / 3.3, 0.5, 1.0)
	var pots := ["plant_decor_01", "plant_decor_04", "plant_decor_03", "plant_decor_02"]
	var k := 0
	for cx in [-1.0, 1.0]:
		for cz in [-1.0, 1.0]:
			var at := Vector2(cx * (w * 0.5 - 0.75), cz * (d * 0.5 - 0.75))
			if _clear(occupied, at, 1.5):
				prop(root, String(pots[k % pots.size()]), Vector3(at.x, 0.0, at.y), float(k) * 70.0, tree_scale)
				occupied.append(at)
				k += 1
	# a small potted plant and a pouf along the long walls, wall hangings on them, where there's room
	var hang := ["wall_art_01", "wall_art_02", "wall_art_03"]
	var placed := 0
	for side in [-1.0, 1.0]:
		for f in [-0.25, 0.25]:
			var along: float = float(f) * length
			var at := Vector2(along, side * (span * 0.5 - 0.06)) if along_x else Vector2(side * (span * 0.5 - 0.06), along)
			if placed < 2 and _clear(occupied, at, 1.6) and h >= 2.6:
				var yaw := (0.0 if side < 0.0 else 180.0) if along_x else (90.0 if side < 0.0 else -90.0)
				prop(root, String(hang[placed % hang.size()]), Vector3(at.x, 0.35, at.y), yaw, minf(1.0, (h - 0.7) / 2.9))
				occupied.append(at)
				placed += 1
	var small_at := Vector2(length * 0.38, -(span * 0.5 - 0.6)) if along_x else Vector2(-(span * 0.5 - 0.6), length * 0.38)
	if _clear(occupied, small_at, 1.2):
		prop(root, "plant_decor_05", Vector3(small_at.x, 0.0, small_at.y), 30.0)
		occupied.append(small_at)
	var pouf_at := Vector2(-length * 0.3, span * 0.5 - 0.9) if along_x else Vector2(span * 0.5 - 0.9, -length * 0.3)
	if _clear(occupied, pouf_at, 1.3) and span >= 4.5:
		prop(root, "stool_01", Vector3(pouf_at.x, 0.0, pouf_at.y))
