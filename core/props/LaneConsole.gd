extends RefCounted
class_name LaneConsole
## The bowling alley's lane console: a cream pedestal with a copper edge strip, and the grey
## bridge-style computer on top. Only the picture (and a solid stand so nobody walks through it);
## the hotspot belongs to whichever room uses it (the Prologue's alley, or the ship's Deck 21 room).
## `pos` is the floor point under the stand, `yaw_deg` turns it (the controls face +Z at 0).

const MODEL := "res://assets/models/rec_deck/props/lane_console.glb"


static func build(parent: Node3D, pos: Vector3, yaw_deg: float, scale: float = 1.0) -> Node3D:
	var root := Node3D.new()
	root.name = "LaneConsole"
	root.position = pos
	root.rotation_degrees = Vector3(0.0, yaw_deg, 0.0)
	root.scale = Vector3.ONE * scale
	parent.add_child(root)
	var cream := StandardMaterial3D.new()
	cream.albedo_color = Color(0.84, 0.82, 0.77)
	cream.roughness = 0.7
	cream.emission_enabled = true
	cream.emission = Color(0.84, 0.82, 0.77)
	cream.emission_energy_multiplier = 0.25
	var grey_base := StandardMaterial3D.new()
	grey_base.albedo_color = Color(0.59, 0.58, 0.56)
	grey_base.roughness = 0.7
	var copper := StandardMaterial3D.new()
	copper.albedo_color = Color(0.69, 0.42, 0.20)
	copper.metallic = 0.6
	copper.roughness = 0.4
	# [name, centre y, height, width (x), depth (z), material]
	var parts := [
		["Base", 0.02, 0.04, 0.50, 0.70, grey_base],
		["Column", 0.39, 0.70, 0.30, 0.50, cream],
		["Top", 0.77, 0.06, 1.05, 0.62, cream],
		["TopTrim", 0.775, 0.03, 1.07, 0.64, copper],
	]
	for part in parts:
		var mi := MeshInstance3D.new()
		mi.name = String(part[0])
		var bm := BoxMesh.new()
		bm.size = Vector3(float(part[3]), float(part[2]), float(part[4]))
		mi.mesh = bm
		mi.material_override = part[5]
		mi.position = Vector3(0.0, float(part[1]), 0.0)
		root.add_child(mi)
	var body := StaticBody3D.new()
	body.name = "LaneConsoleBody"
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(1.05, 0.80, 0.62)
	shape.shape = box
	shape.position = Vector3(0.0, 0.40, 0.0)
	body.add_child(shape)
	root.add_child(body)
	var packed: Resource = load(MODEL)
	if packed is PackedScene:
		var computer: Node3D = (packed as PackedScene).instantiate()
		computer.name = "LaneComputer"
		computer.position = Vector3(0.0, 0.80, 0.0)
		root.add_child(computer)
		_glow_meshes(computer, 0.3)
	return root


## Makes every material under the node faintly self-lit (its own texture), so a
## prop sitting outside the deck's baked lighting is not dark.
static func _glow_meshes(node: Node, energy: float) -> void:
	if node is MeshInstance3D:
		var mi := node as MeshInstance3D
		for s in mi.mesh.get_surface_count():
			var src: Material = mi.mesh.surface_get_material(s)
			if src is StandardMaterial3D:
				var m := (src as StandardMaterial3D).duplicate() as StandardMaterial3D
				m.emission_enabled = true
				m.emission_texture = m.albedo_texture
				m.emission_energy_multiplier = energy
				mi.set_surface_override_material(s, m)
	for child in node.get_children():
		_glow_meshes(child, energy)
