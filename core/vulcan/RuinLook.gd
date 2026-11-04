class_name RuinLook
extends RefCounted
## REV 882 - THE RUIN LOOK for the ruins' indoor rooms (the gallery first). Like AdobeLook: it changes only what you SEE.
## The room's boxes keep their collision; their plain colours become Glen's Egyptian Ruins sandstones (tileable, laid on
## in world space so nothing stretches); new dressing (pilasters, lintels, slits, door frame, rubble) is never solid.
##
## Carvings: the story's reliefs (armies, burning cities, covered faces...) are Glen's to make - a picture per panel in
## CARVINGS (portrait, about 2.2 x 3.6 m on the wall: 1024 x 1676 px is right). A panel with no picture yet stays plain
## carved stone with its stand-in figures; drop the picture in and the panel shows it, carved in by its own brightness
## (light = raised, dark = cut deep) and the stand-in figures go. docs/systems/vulcan-desert.md "The gallery".

const SAND := "res://assets/models/vulcan_desert/ruins/textures/DO_EgyptianRuins2_Sandstone0"
const CARVINGS := "res://assets/textures/vulcan_ruins/"

static var _mats := {}


static func _tex(path: String) -> Texture2D:
	return load(path) as Texture2D if ResourceLoader.exists(path) else null


## kinds: wall, floor, ceiling, relief, deep, tile (tile keeps each box's own shade)
static func stone(kind: String) -> StandardMaterial3D:
	if _mats.has(kind):
		return _mats[kind]
	var n: String = {"wall": "1", "floor": "3", "ceiling": "2", "relief": "2", "deep": "1", "tile": "3"}.get(kind, "1")
	var m := StandardMaterial3D.new()
	m.albedo_texture = _tex(SAND + n + ".jpg")
	m.normal_texture = _tex(SAND + n + "N.jpg")
	m.normal_enabled = m.normal_texture != null
	m.uv1_triplanar = true
	m.uv1_world_triplanar = true
	var sc: float = {"floor": 0.45, "tile": 0.9, "ceiling": 0.3}.get(kind, 0.35)
	m.uv1_scale = Vector3.ONE * sc
	m.roughness = 0.93
	m.albedo_color = {"wall": Color(0.92, 0.80, 0.68), "floor": Color(0.86, 0.74, 0.62), "ceiling": Color(0.48, 0.40, 0.34),
		"relief": Color(0.96, 0.84, 0.70), "deep": Color(0.58, 0.47, 0.38), "tile": Color(1.0, 1.0, 1.0)}.get(kind, Color.WHITE)
	if m.albedo_texture == null:
		m.albedo_color = Color(0.62, 0.50, 0.38) * (0.6 if kind in ["ceiling", "deep"] else 1.0)
	_mats[kind] = m
	return m


## The base name of a box (Godot renames clashing siblings to "@Name@123").
static func base_name(n: Node) -> String:
	var s := String(n.name)
	if s.begins_with("@"):
		s = s.substr(1).get_slice("@", 0)
	return s.rstrip("0123456789")


## Every box named `names` (base names) in the room gets the stone; "tile" keeps each box's own shade on top of it.
static func skin(room: Node, names: Array, kind: String) -> int:
	var count := 0
	for c in room.get_children():
		if not (c is StaticBody3D) or not names.has(base_name(c)):
			continue
		for mi in c.get_children():
			if not (mi is MeshInstance3D):
				continue
			var mat := stone(kind)
			if kind == "tile":
				var old := (mi as MeshInstance3D).material_override as StandardMaterial3D
				mat = mat.duplicate() as StandardMaterial3D
				if old != null:
					mat.albedo_color = Color(old.albedo_color.r * 1.35, old.albedo_color.g * 1.35, old.albedo_color.b * 1.35)
			(mi as MeshInstance3D).material_override = mat
			count += 1
	return count


## A carving picture on a panel's face, if Glen has made it. `normal` points out of the wall into the room.
static func carving(room: Node3D, slot: String, centre: Vector3, normal: Vector3, size: Vector2) -> bool:
	var pic := _tex(CARVINGS + "carving_" + slot + ".png")
	if pic == null:
		pic = _tex(CARVINGS + "carving_" + slot + ".jpg")
	if pic == null:
		return false
	var q := MeshInstance3D.new()
	q.name = "Carving_" + slot
	var qm := QuadMesh.new()
	qm.size = size
	q.mesh = qm
	var m := StandardMaterial3D.new()
	m.albedo_texture = pic
	m.albedo_color = Color(0.95, 0.85, 0.72)      # the stone's own warmth over Glen's picture
	m.roughness = 0.92
	m.heightmap_enabled = true                      # carved by its brightness: dark = cut deep
	m.heightmap_texture = pic
	m.heightmap_scale = 6.0
	m.heightmap_deep_parallax = true
	q.material_override = m
	room.add_child(q)
	q.basis = Basis.looking_at(-normal, Vector3.UP)   # a QuadMesh faces +Z; looking_at points -Z away from the room
	q.position = centre + normal * 0.012
	return true


## A plain stone block for dressing (never solid).
static func block(room: Node3D, node_name: String, pos: Vector3, size: Vector3, kind := "wall") -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.name = node_name
	var bm := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	mi.material_override = stone(kind)
	room.add_child(mi)
	mi.position = pos
	return mi


## A slit of starlight high in a wall: a pale glowing cut plus a faint shaft of light falling into the room.
static func slit(room: Node3D, pos: Vector3, into_room: Vector3) -> void:
	var cut := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(0.06, 0.9, 0.22) if absf(into_room.x) > 0.5 else Vector3(0.22, 0.9, 0.06)
	cut.mesh = bm
	var cm := StandardMaterial3D.new()
	cm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	cm.albedo_color = Color(0.72, 0.80, 1.0)
	cut.material_override = cm
	room.add_child(cut)
	cut.position = pos
	# the shaft: a long thin glowing slab leaning down into the room, very faint
	var beam := MeshInstance3D.new()
	var qm := QuadMesh.new()
	qm.size = Vector2(0.5, 5.0)
	beam.mesh = qm
	var bmat := StandardMaterial3D.new()
	bmat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	bmat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	bmat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	bmat.cull_mode = BaseMaterial3D.CULL_DISABLED
	bmat.albedo_color = Color(0.20, 0.24, 0.34, 0.35)
	bmat.no_depth_test = false
	beam.material_override = bmat
	beam.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	room.add_child(beam)
	var foot := pos + into_room * 2.2 + Vector3(0.0, -pos.y + 0.2, 0.0)
	beam.position = (pos + foot) * 0.5
	var up := (pos - foot).normalized()
	var side := up.cross(Vector3.UP if absf(up.y) < 0.99 else Vector3.RIGHT).normalized()
	beam.basis = Basis(side, up, side.cross(up)).orthonormalized()
	beam.scale = Vector3(1.0, (pos - foot).length() / 5.0, 1.0)


## Dust hanging in the air of a hall (box `size` centred on `centre`).
static func dust(room: Node3D, centre: Vector3, size: Vector3, amount := 140) -> void:
	var p := GPUParticles3D.new()
	p.name = "Dust"
	p.amount = amount
	p.lifetime = 14.0
	p.preprocess = 14.0
	p.visibility_aabb = AABB(-size * 0.5, size)
	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	pm.emission_box_extents = size * 0.5
	pm.gravity = Vector3(0.0, -0.004, 0.0)
	pm.direction = Vector3(0.2, 1.0, 0.1)
	pm.spread = 180.0
	pm.initial_velocity_min = 0.01
	pm.initial_velocity_max = 0.04
	pm.scale_min = 0.6
	pm.scale_max = 1.4
	p.process_material = pm
	var q := QuadMesh.new()
	q.size = Vector2(0.012, 0.012)
	var qm := StandardMaterial3D.new()
	qm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	qm.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	qm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	qm.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	qm.albedo_color = Color(0.80, 0.80, 0.90, 0.55)
	q.material = qm
	p.draw_pass_1 = q
	room.add_child(p)
	p.position = centre
