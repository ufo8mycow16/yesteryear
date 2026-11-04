class_name VulcanDesert
extends RefCounted
## REV 869 - VULCAN'S DESERT, DRESSED (Episode 1, Part Five). One kit for every desert room: the Wadi Desert pack's
## red sandstone mesas, pebbles and sand grounds (assets/models/vulcan_desert/wadi/, Glen 4 Nov) and the Egyptian
## Ruins 2 pieces (assets/models/vulcan_desert/ruins/, Glen 4 Nov). Rooms keep their simple boxes for walking and
## hotspots - this only changes what you SEE:
##   ground(room)            the room's flat box ground hidden; rippled sand under the walkable area, dunes round it,
##                           a plain sand plane out to the fog
##   skyline(room, ...)      mesas on the horizon, all round
##   mesa(room, kind, ...)   one mesa/butte/cliff, any size (scaled to metres; stretched taller for cliffs)
##   rock_for(box, kind)     dress one of the room's stand-in rock boxes: its box is hidden (collision kept) and a mesa,
##                           squeezed to the box's size, stands in its place
##   ruin(room, kind, ...)   one ruin piece (tinted toward the desert's red; solid where you can walk into it)
##   pebbles(room, ...)      a scatter of small round stones
## Everything is optional - a missing file just leaves the room as it was.
## docs/systems/vulcan-desert.md has the pieces and where each room uses them.

const WADI := "res://assets/models/vulcan_desert/wadi/ap_modular_wadi_desert"
const RUINS := "res://assets/models/vulcan_desert/ruins/ruin_"
## The four mesas (each ~24 m across and 6-7 m tall in the kit; scaled here to whatever a room needs).
const MESAS := {
	"flat": "_rock1",       # the classic flat-topped mesa
	"rough": "_rock2",      # lumpier, eroded
	"table": "_rock3",      # a broad table-top
	"split": "_rock4",      # two halves with a gap through the middle (lower)
}
## REV 870: Wild Canyon's three Monument Valley buttes (Glen's Daz pack, 3dLab) - tall cliffs on long scree slopes,
## ~87 m across, 22-30 m tall, only 10-20k triangles with 4K pictures: the horizon and the big cliffs use these.
const CANYON := "res://assets/models/vulcan_desert/canyon/wc_canyon"
const BUTTES := {"block": "01", "bench": "02", "spire": "03"}     # a blocky butte, a long flat bench, a butte + its spire
const BUTTE_SIZE := 87.0
const BUTTE_HEIGHT := {"block": 22.2, "bench": 24.8, "spire": 30.4}
const MESA_SIZE := 24.0
const MESA_HEIGHT := {"flat": 7.26, "rough": 7.3, "table": 7.07, "split": 5.98}
const TILE := 52.0
## The ruins' pale stone, warmed toward the sand (the kit's own colour reads Egyptian; this reads Vulcan).
const RUIN_TINT := Color(1.0, 0.80, 0.66)
const ROCK_TINT := Color(1.0, 1.0, 1.0)
const SAND_PLANE := Color(0.70, 0.43, 0.29)

static var _tinted := {}


## Load one kit piece. Returns null (and the room carries on) when the file isn't there.
static func _load(path: String) -> Node3D:
	if not ResourceLoader.exists(path):
		push_warning("VulcanDesert: missing " + path)
		return null
	var ps := load(path) as PackedScene
	return ps.instantiate() as Node3D if ps != null else null


static func _dress(node: Node3D, tint: Color, solid: bool) -> void:
	for n in node.find_children("*", "MeshInstance3D", true, false):
		var mi := n as MeshInstance3D
		if mi.mesh == null:
			continue
		for i in mi.mesh.get_surface_count():
			var m := mi.get_active_material(i) as BaseMaterial3D
			if m == null:
				continue
			var key := str(m.get_instance_id()) + "|" + tint.to_html()
			if not _tinted.has(key):
				var t := m.duplicate() as BaseMaterial3D
				t.albedo_color = m.albedo_color * tint
				t.roughness = maxf(t.roughness, 0.85)
				_tinted[key] = t
			mi.set_surface_override_material(i, _tinted[key])
		if solid:
			var shape := mi.mesh.create_trimesh_shape()
			if shape != null:
				var body := StaticBody3D.new()
				body.name = "Collision"
				var cs := CollisionShape3D.new()
				cs.shape = shape
				body.add_child(cs)
				mi.add_child(body)
		else:
			mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON


## One mesa or butte ("block", "bench", "spire" = Wild Canyon's buttes; "flat", "rough", "table", "split" = the Wadi
## mesas). `width` = across in metres, `height` = how tall (default keeps the kit's shape). `lite` = the 16k-triangle
## copy (<piece>_lo, made in Blender) - the horizon and the small rocks use it; big cliffs close by use the full 80k.
static func mesa(room: Node3D, kind: String, pos: Vector3, yaw_deg: float, width: float, height: float = -1.0, solid := false, lite := false) -> Node3D:
	var butte := BUTTES.has(kind)
	var node := _load(CANYON + String(BUTTES[kind]) + ".gltf") if butte else _load(WADI + String(MESAS.get(kind, "_rock1")) + ("_lo" if lite else "") + ".gltf")
	if node == null:
		return null
	var s := width / (BUTTE_SIZE if butte else MESA_SIZE)
	var hs := s if height <= 0.0 else height / float((BUTTE_HEIGHT if butte else MESA_HEIGHT).get(kind, 7.0))
	node.name = "Mesa_" + kind
	node.scale = Vector3(s, hs, s)
	node.position = pos
	node.rotation_degrees.y = yaw_deg
	room.add_child(node)
	_dress(node, ROCK_TINT, solid)
	return node


## Dress a stand-in rock box (from EpisodeRoom.box): hide its block, keep its collision, put a mesa squeezed to its
## size in its place. `spread` widens the mesa past the box (its sand skirt runs out round the foot).
static func rock_for(box_body: Node3D, kind: String = "rough", spread := 1.35, yaw_deg := 0.0) -> Node3D:
	if box_body == null:
		return null
	var size := Vector3.ONE
	for c in box_body.get_children():
		if c is MeshInstance3D and (c as MeshInstance3D).mesh is BoxMesh:
			size = ((c as MeshInstance3D).mesh as BoxMesh).size
	var node := _load(WADI + String(MESAS.get(kind, "_rock2")) + "_lo.gltf")
	if node == null:
		return null
	for c in box_body.get_children():
		if c is MeshInstance3D:
			(c as MeshInstance3D).visible = false
	var turned := absf(sin(deg_to_rad(yaw_deg))) > 0.7
	var sx := (size.z if turned else size.x) * spread / MESA_SIZE
	var sz := (size.x if turned else size.z) * spread / MESA_SIZE
	var sy := size.y * 1.12 / float(MESA_HEIGHT.get(kind, 7.0))
	node.name = "Rock_" + String(box_body.name)
	node.scale = Vector3(sx, sy, sz)
	var base := box_body.position
	node.position = Vector3(base.x, base.y - size.y * 0.5 - 0.05, base.z)
	node.rotation_degrees.y = yaw_deg
	box_body.get_parent().add_child(node)
	_dress(node, ROCK_TINT, false)
	return node


## Hide a backdrop box altogether (a stand-in mountain range the skyline replaces).
static func hide_box(box_body: Node3D) -> void:
	if box_body == null:
		return
	box_body.visible = false
	for c in box_body.get_children():
		if c is CollisionShape3D:
			(c as CollisionShape3D).disabled = true


## The ground: rippled sand tiles under the walkable area, dune tiles round it, a sand plane out to the fog. The
## room's own flat ground keeps its collision (you walk on the box, the ripples sit a few centimetres either side of it).
## REV 883: `plane` false when the room has Glen's landscape round it (VulcanTerrain) - the terrain is the ground then.
static func ground(room: Node3D, half_x: float, half_z: float, rings := 1, centre := Vector3.ZERO, plane_out := true) -> void:
	var g := room.get_node_or_null("Ground")
	if g != null:
		for c in g.get_children():
			if c is MeshInstance3D:
				(c as MeshInstance3D).visible = false
	var root := Node3D.new()
	root.name = "DesertGround"
	room.add_child(root)
	var nx := int(ceil((half_x + 2.0) / TILE - 0.5))
	var nz := int(ceil((half_z + 2.0) / TILE - 0.5))
	for ix in range(-nx - rings, nx + rings + 1):
		for iz in range(-nz - rings, nz + rings + 1):
			var at := centre + Vector3(ix * TILE, 0.0, iz * TILE)
			var inside := absf(at.x - centre.x) - TILE * 0.5 < half_x + 2.0 and absf(at.z - centre.z) - TILE * 0.5 < half_z + 2.0
			var piece := "" if inside else ("_dunes" if (ix + iz) % 2 == 0 else "_dunes2")
			var node := _load(WADI + piece + ".gltf")
			if node == null:
				return
			node.position = at + Vector3(0.0, -0.10 if inside else -1.2, 0.0)
			node.rotation_degrees.y = 90.0 * float((ix * 3 + iz * 7) % 4)
			root.add_child(node)
			_dress(node, ROCK_TINT, false)
			for mi in node.find_children("*", "MeshInstance3D", true, false):
				(mi as MeshInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	# out to the fog
	if not plane_out:
		return
	var plane := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(1400.0, 1400.0)
	plane.mesh = pm
	var m := StandardMaterial3D.new()
	m.albedo_color = SAND_PLANE
	m.roughness = 1.0
	plane.material_override = m
	plane.position = centre + Vector3(0.0, -1.0, 0.0)
	plane.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(plane)


## Mesas round the horizon. `from`/`to` = the arc in degrees (0 = north, 90 = east), so a room can leave a gap
## (the city behind you, a canyon ahead).
static func skyline(room: Node3D, count: int, radius: float, seed_text: String, from_deg := 0.0, to_deg := 360.0, centre := Vector3.ZERO) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(seed_text)
	var kinds := ["block", "bench", "spire", "block", "bench"]
	for i in count:
		var t := (float(i) + rng.randf_range(0.2, 0.8)) / float(count)
		var a := deg_to_rad(lerpf(from_deg, to_deg, t))
		var r := radius * rng.randf_range(0.85, 1.25)
		var at := centre + Vector3(sin(a) * r, -0.6, -cos(a) * r)
		var w := rng.randf_range(80.0, 150.0)
		var k := String(kinds[(i + rng.randi_range(0, 4)) % kinds.size()])
		mesa(room, k, at, rng.randf_range(0.0, 360.0), w, w / BUTTE_SIZE * float(BUTTE_HEIGHT[k]) * rng.randf_range(0.9, 1.35))


## One ruin piece: "arch", "colonnade_curved", "colonnade_long", "temple_corner", "gatehouse".
static func ruin(room: Node3D, kind: String, pos: Vector3, yaw_deg: float, scale := 1.0, solid := true, tint := RUIN_TINT) -> Node3D:
	var node := _load(RUINS + kind + ".gltf")
	if node == null:
		return null
	node.name = "Ruin_" + kind
	node.position = pos
	node.rotation_degrees.y = yaw_deg
	node.scale = Vector3.ONE * scale
	room.add_child(node)
	_dress(node, tint, solid)
	return node


## REV 875: any converted kit piece (res:// path to a .gltf). `recentre` = the piece was exported in its pack's scene
## space (Forgotten Temple, Little Desert Valley): its footprint is moved onto `pos`, standing on y 0.
static func kit(room: Node3D, path: String, pos: Vector3, yaw_deg := 0.0, scale := 1.0, solid := false, tint := RUIN_TINT, recentre := false) -> Node3D:
	var piece := _load(path)
	if piece == null:
		return null
	var node := Node3D.new()
	node.name = "Kit_" + path.get_file().get_basename()
	node.add_child(piece)
	if recentre:
		var box := AABB()
		var first := true
		for n in piece.find_children("*", "MeshInstance3D", true, false):
			var mi := n as MeshInstance3D
			if mi.mesh == null:
				continue
			var a := mi.transform * mi.mesh.get_aabb()
			box = a if first else box.merge(a)
			first = false
		if not first:
			piece.position = -Vector3(box.get_center().x, box.position.y, box.get_center().z)
	node.position = pos
	node.rotation_degrees.y = yaw_deg
	node.scale = Vector3.ONE * scale
	room.add_child(node)
	_dress(node, tint, solid)
	return node


## A scatter of small round stones (the kit's piece is ~23 x 21 m; `scale` shrinks or grows the patch).
static func pebbles(room: Node3D, pos: Vector3, yaw_deg := 0.0, scale := 1.0) -> Node3D:
	var node := _load(WADI + "_rock_small.gltf")
	if node == null:
		return null
	node.name = "Pebbles"
	node.position = pos + Vector3(0.0, 0.02, 0.0)
	node.rotation_degrees.y = yaw_deg
	node.scale = Vector3(scale, 1.0, scale)
	room.add_child(node)
	_dress(node, ROCK_TINT, false)
	for mi in node.find_children("*", "MeshInstance3D", true, false):
		(mi as MeshInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return node
