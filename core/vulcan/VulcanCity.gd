class_name VulcanCity
extends Node3D
## SHI'KAHR (REV 856, Glen 4 Nov: "build me a beautiful Shi'Kahr ... it needs to feel grand").
##
## Builds the whole city from ONE data file, data/vulcan/shikahr_layout.json (the same file
## tools/props/daz_city/shikahr_map.py draws the plan from):
##   pieces       the converted Daz city kits (assets/models/vulcan_city/<kit>/<piece>.gltf), placed, turned, scaled;
##                stone tinted toward Vulcan red at load ("look".tint); solid pieces get mesh collision
##   ground       the plateau the city stands on: the UPPER CITY's slabs, the market canyon's floor, the two ramps
##                down into it; the desert floor all round below the cliff; the parapet at the Great Overlook
##   spots        story places [x, hint_y, z]; "spot_ground" = the real ground under each one, worked out from the
##                geometry by tools/props/daz_city/shikahr_heights.py (run it after moving anything)
## Plus what the kits don't have: the two statues, the tour stones, the water and sand gardens, transit pads, the
## far-viewer, distant mountains and the sky.
## Page: docs/systems/shikahr-city.md

const LAYOUT := "res://data/vulcan/shikahr_layout.json"
const CITY_ROOT := "res://assets/models/vulcan_city/"
const STONE_COL := "res://assets/models/vulcan_city/survival_palace/textures/sandstone_Col.jpg"
const STONE_NRM := "res://assets/models/vulcan_city/survival_palace/textures/sandstone_Norml.jpg"
const PAVING_COL := "res://assets/models/vulcan_city/survival_palace/textures/Floor_Col.jpg"
const PAVING_NRM := "res://assets/models/vulcan_city/survival_palace/textures/Floor_Norml.jpg"
const SAND_TEX := "res://assets/textures/arena/ground_sand.png"
## pieces with these words in their name never block anyone (cloth overhead, hanging lamps, rugs on the floor)
const NOT_SOLID := ["awning", "tube_light", "hanging_pot", "globe_light", "window_shade", "carpet", "_rug", "lamp", "plate", "bread", "fruit_veg"]

var layout: Dictionary = {}
var tint := Color(1.0, 0.80, 0.68)
var _tinted := {}            # original material -> tinted copy (shared between pieces that share a material)
var _mat_cache := {}


static func load_layout() -> Dictionary:
	var f := FileAccess.open(LAYOUT, FileAccess.READ)
	if f == null:
		push_warning("VulcanCity: no layout at " + LAYOUT)
		return {}
	var d: Variant = JSON.parse_string(f.get_as_text())
	return d if d is Dictionary else {}


## Builds the city under `parent` and returns it.
static func make(parent: Node3D) -> VulcanCity:
	var city := VulcanCity.new()
	city.name = "ShiKahr"
	parent.add_child(city)
	city.build()
	return city


func build() -> void:
	layout = load_layout()
	if layout.is_empty():
		return
	var look: Dictionary = layout.get("look", {})
	if look.has("tint"):
		tint = _col(look["tint"])
	_build_ground()
	for p in layout.get("pieces", []):
		_place_piece(p)
	_build_backdrop()
	_build_mountains()


# ---------------------------------------------------------------------------------------------- spots ----

## A story spot: (x, the real ground under it, z). Vector3.INF if the layout has no such spot.
func spot(key: String) -> Vector3:
	var s: Array = layout.get("spots", {}).get(key, [])
	if s.is_empty():
		push_warning("VulcanCity: no spot " + key)
		return Vector3.INF
	var g: Variant = layout.get("spot_ground", {}).get(key, null)
	return Vector3(float(s[0]), float(g) if g != null else float(s[1]), float(s[2]))


func has_spot(key: String) -> bool:
	return layout.get("spots", {}).has(key)


# ---------------------------------------------------------------------------------------------- pieces ---

func _place_piece(p: Dictionary) -> void:
	var path := CITY_ROOT + String(p["piece"]) + ".gltf"
	if not ResourceLoader.exists(path):
		push_warning("VulcanCity: missing " + path)
		return
	var ps: PackedScene = load(path)
	if ps == null:
		return
	var node: Node3D = ps.instantiate()
	var pos: Array = p["pos"]
	node.position = Vector3(float(pos[0]), float(pos[1]), float(pos[2]))
	node.rotation_degrees.y = float(p.get("yaw", 0.0))
	node.scale = Vector3.ONE * float(p.get("scale", 1.0))
	add_child(node)
	var piece_name := String(p["piece"]).get_file()
	var solid := bool(p.get("solid", true))
	for w in NOT_SOLID:
		if piece_name.contains(w):
			solid = false
	var boxed := p.has("box")     # REV 857: street buildings get one simple box (nobody walks inside them)
	for mi in node.find_children("*", "MeshInstance3D", true, false):
		_tint_mesh(mi as MeshInstance3D)
		if solid and not boxed:
			_collide(mi as MeshInstance3D)
	if solid and boxed:
		_collide_box(node)


func _tint_mesh(mi: MeshInstance3D) -> void:
	if mi.mesh == null:
		return
	for i in mi.mesh.get_surface_count():
		var m: Material = mi.get_active_material(i)
		if not (m is BaseMaterial3D):
			continue
		var src := m as BaseMaterial3D
		if String(src.resource_name).contains("Dune"):
			# the kit's sand had a Dune picture we don't have: the game's own desert sand instead
			mi.set_surface_override_material(i, _sand_material())
			continue
		if not _tinted.has(src):
			var t := src.duplicate() as BaseMaterial3D
			t.albedo_color = src.albedo_color * tint
			if t.emission_enabled:
				t.emission_energy_multiplier = minf(t.emission_energy_multiplier, 0.6)
			_tinted[src] = t
		mi.set_surface_override_material(i, _tinted[src])


## One box round the whole building (its meshes' bounds, in its own space).
func _collide_box(node: Node3D) -> void:
	var box_aabb := AABB()
	var first := true
	for mi in node.find_children("*", "MeshInstance3D", true, false):
		var m := mi as MeshInstance3D
		if m.mesh == null:
			continue
		var rel := node.global_transform.affine_inverse() * m.global_transform if node.is_inside_tree() else m.transform
		var a := rel * m.mesh.get_aabb()
		box_aabb = a if first else box_aabb.merge(a)
		first = false
	if first:
		return
	var body := StaticBody3D.new()
	body.name = "Collision"
	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = box_aabb.size * Vector3(0.96, 1.0, 0.96)
	cs.shape = bs
	cs.position = box_aabb.get_center()
	body.add_child(cs)
	node.add_child(body)


## REV 857: THE LOWER CITY - a thousand-odd light buildings round the foot of the terrace and out toward the mountains,
## drawn as MultiMeshes (one per building mesh per 160 m square, so what's behind you isn't drawn), no shadows, nothing
## to walk into. Generated by tools/props/daz_city/shikahr_blocks.py into the layout's "backdrop".
const SECTOR := 160.0

func _build_backdrop() -> void:
	var groups := {}      # piece -> sector key -> [Transform3D]
	for b in layout.get("backdrop", []):
		var pos: Array = b["pos"]
		var t := Transform3D(Basis(Vector3.UP, deg_to_rad(float(b.get("yaw", 0.0)))).scaled(Vector3.ONE * float(b.get("scale", 1.0))),
			Vector3(float(pos[0]), float(pos[1]), float(pos[2])))
		var key := Vector2i(floori(t.origin.x / SECTOR), floori(t.origin.z / SECTOR))
		var piece := String(b["piece"])
		if not groups.has(piece):
			groups[piece] = {}
		if not groups[piece].has(key):
			groups[piece][key] = []
		groups[piece][key].append(t)
	var root := Node3D.new()
	root.name = "LowerCity"
	add_child(root)
	for piece in groups:
		var path := CITY_ROOT + String(piece) + ".gltf"
		if not ResourceLoader.exists(path):
			push_warning("VulcanCity: missing " + path)
			continue
		var scene: Node3D = (load(path) as PackedScene).instantiate()
		add_child(scene)      # in the tree so mesh transforms are global
		var parts: Array = []   # [mesh with tinted materials, transform within the building]
		for mi in scene.find_children("*", "MeshInstance3D", true, false):
			var m := mi as MeshInstance3D
			if m.mesh == null:
				continue
			var mesh: Mesh = m.mesh.duplicate()
			for i in mesh.get_surface_count():
				var mat: Material = m.get_active_material(i)
				if mat is BaseMaterial3D:
					if not _tinted.has(mat):
						var tm := (mat as BaseMaterial3D).duplicate() as BaseMaterial3D
						tm.albedo_color = (mat as BaseMaterial3D).albedo_color * tint
						_tinted[mat] = tm
					mesh.surface_set_material(i, _tinted[mat])
			parts.append([mesh, scene.global_transform.affine_inverse() * m.global_transform])
		scene.queue_free()
		for key in groups[piece]:
			var list: Array = groups[piece][key]
			for part in parts:
				var mm := MultiMesh.new()
				mm.transform_format = MultiMesh.TRANSFORM_3D
				mm.mesh = part[0]
				mm.instance_count = list.size()
				for k in list.size():
					mm.set_instance_transform(k, (list[k] as Transform3D) * (part[1] as Transform3D))
				var mmi := MultiMeshInstance3D.new()
				mmi.multimesh = mm
				mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
				root.add_child(mmi)


func _collide(mi: MeshInstance3D) -> void:
	if mi.mesh == null:
		return
	var shape := mi.mesh.create_trimesh_shape()
	if shape == null:
		return
	var body := StaticBody3D.new()
	body.name = "Collision"
	var cs := CollisionShape3D.new()
	cs.shape = shape
	body.add_child(cs)
	mi.add_child(body)


# ---------------------------------------------------------------------------------------------- ground ---

func _build_ground() -> void:
	var g: Dictionary = layout.get("ground", {})
	var up := float(g.get("upper", 10.62))
	var low := float(g.get("market", 0.1))
	var stone := _stone_material(_col([0.86, 0.62, 0.48]), 0.05)
	var paving := _paving_material()
	for s in g.get("slabs", []):
		var x: Array = s["x"]
		var z: Array = s["z"]
		_slab(String(s["name"]), float(x[0]), float(x[1]), float(z[0]), float(z[1]), -2.0, up, paving, stone)
	var f: Dictionary = g.get("canyon_floor", {})
	if not f.is_empty():
		_slab("CanyonFloor", float(f["x"][0]), float(f["x"][1]), float(f["z"][0]), float(f["z"][1]), -2.0, low, _sand_material(), stone)
	for r in g.get("ramps", []):
		_ramp(String(r["name"]), float(r["x_low"]), float(r["x_high"]), float(r["z"][0]), float(r["z"][1]), low, up, paving)
	# the desert floor, all the way to the mountains
	var desert := MeshInstance3D.new()
	desert.name = "Desert"
	var pm := PlaneMesh.new()
	pm.size = Vector2(6000.0, 6000.0)
	desert.mesh = pm
	desert.position.y = -0.02
	var dm := _sand_material()
	dm = dm.duplicate()
	dm.albedo_color = _col(layout.get("look", {}).get("desert", [0.70, 0.40, 0.24]))
	desert.material_override = dm
	desert.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(desert)
	# the Great Overlook's parapet, and invisible walls round the plateau's edge
	var par: Dictionary = g.get("parapet", {})
	if not par.is_empty():
		var px: Array = par["x"]
		var pz := float(par["z"])
		_box("Parapet", Vector3((float(px[0]) + float(px[1])) * 0.5, up + 0.55, pz), Vector3(float(px[1]) - float(px[0]), 1.1, 0.6), stone, true)
		_box("ParapetCap", Vector3((float(px[0]) + float(px[1])) * 0.5, up + 1.13, pz), Vector3(float(px[1]) - float(px[0]) + 0.2, 0.08, 0.8), paving, false)
	var ex: Array = g.get("extent", [-192, 182, -82, 94])
	var x0 := float(ex[0])
	var x1 := float(ex[1])
	var z0 := float(ex[2])
	var z1 := float(ex[3])
	_wall(Vector3((x0 + x1) * 0.5, up + 2.0, z0 + 0.5), Vector3(x1 - x0, 6.0, 1.0))
	_wall(Vector3((x0 + x1) * 0.5, up + 2.0, z1 - 0.5), Vector3(x1 - x0, 6.0, 1.0))
	_wall(Vector3(x0 + 0.5, up + 2.0, (z0 + z1) * 0.5), Vector3(1.0, 6.0, z1 - z0))
	_wall(Vector3(x1 - 0.5, up + 2.0, (z0 + z1) * 0.5), Vector3(1.0, 6.0, z1 - z0))
	# the canyon's edges: nobody steps off the upper city into the market by accident (gaps where the bridges cross)
	for rail in g.get("rails", []):
		var rx: Array = rail["x"]
		_wall(Vector3((float(rx[0]) + float(rx[1])) * 0.5, up + 1.0, float(rail["z"])), Vector3(float(rx[1]) - float(rx[0]), 2.6, 0.4))


func _slab(nm: String, x0: float, x1: float, z0: float, z1: float, y0: float, y1: float, top: Material, side: Material) -> void:
	var body := StaticBody3D.new()
	body.name = nm
	body.position = Vector3((x0 + x1) * 0.5, (y0 + y1) * 0.5, (z0 + z1) * 0.5)
	var size := Vector3(x1 - x0, y1 - y0, z1 - z0)
	# the top as its own thin layer (paving), the body as cliff stone
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size - Vector3(0.0, 0.04, 0.0)
	mi.mesh = bm
	mi.position.y = -0.02
	mi.material_override = side
	body.add_child(mi)
	var cap := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(size.x, size.z)
	cap.mesh = pm
	cap.position.y = size.y * 0.5
	cap.material_override = top
	body.add_child(cap)
	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = size
	cs.shape = bs
	body.add_child(cs)
	add_child(body)


func _ramp(nm: String, x_low: float, x_high: float, z0: float, z1: float, low: float, up: float, mat: Material) -> void:
	var run := absf(x_high - x_low)
	var rise := up - low
	var length := sqrt(run * run + rise * rise)
	var body := StaticBody3D.new()
	body.name = nm
	var dir := signf(x_high - x_low)
	var ang := atan2(rise, run) * dir
	var thick := 0.6
	# the top surface runs from (x_low, low) to (x_high, up); the box hangs below that line
	var mid := Vector3((x_low + x_high) * 0.5, (low + up) * 0.5, (z0 + z1) * 0.5)
	var down := Vector3(sin(ang), -cos(ang), 0.0) * (thick * 0.5)
	body.position = mid + down
	body.rotation.z = ang
	var size := Vector3(length, thick, z1 - z0)
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	mi.material_override = mat
	body.add_child(mi)
	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = size
	cs.shape = bs
	body.add_child(cs)
	add_child(body)
	# steps drawn on it: shallow dark lines every 0.9 m so it reads as a stair-ramp
	var steps := int(length / 0.9)
	for i in range(1, steps):
		var t := float(i) / float(steps)
		var line := MeshInstance3D.new()
		var lm := BoxMesh.new()
		lm.size = Vector3(0.06, 0.02, z1 - z0)
		line.mesh = lm
		line.position = Vector3(lerpf(x_low, x_high, t), lerpf(low, up, t) + 0.012, (z0 + z1) * 0.5)
		line.rotation.z = ang
		line.material_override = _flat(Color(0.30, 0.18, 0.12))
		line.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(line)


func _wall(pos: Vector3, size: Vector3) -> void:
	var body := StaticBody3D.new()
	body.name = "Edge"
	body.position = pos
	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = size
	cs.shape = bs
	body.add_child(cs)
	add_child(body)


func _box(nm: String, pos: Vector3, size: Vector3, mat: Material, solid: bool) -> Node3D:
	var body := StaticBody3D.new() if solid else Node3D.new()
	body.name = nm
	body.position = pos
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	mi.material_override = mat
	body.add_child(mi)
	if solid:
		var cs := CollisionShape3D.new()
		var bs := BoxShape3D.new()
		bs.size = size
		cs.shape = bs
		body.add_child(cs)
	add_child(body)
	return body


## Low red mountains on the horizon all round (the Forge to the east, Seleya's peak to the south-east). A ring of
## noise-shaped ridges well past the fog's middle, so they read as distance, not as scenery you could walk to.
func _build_mountains() -> void:
	var noise := FastNoiseLite.new()
	noise.seed = 1701
	noise.frequency = 0.9
	noise.fractal_octaves = 4
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var segs := 256
	var r_in := 1500.0
	var r_out := 2600.0
	var rings := 6
	var pts: Array = []
	for j in rings + 1:
		var row: Array = []
		var rr := lerpf(r_in, r_out, float(j) / float(rings))
		for i in segs + 1:
			var a := TAU * float(i) / float(segs)
			var n := noise.get_noise_2d(cos(a) * 3.0 + float(j) * 0.35, sin(a) * 3.0)
			var h := (n * 0.5 + 0.5) * 260.0 + 40.0
			# Seleya: one tall peak to the south-east
			var d := absf(wrapf(a - 0.6, -PI, PI))
			h += maxf(0.0, 1.0 - d / 0.05) * 420.0 * (1.0 - absf(float(j) / float(rings) - 0.4))
			if j == 0 or j == rings:
				h = 0.0
			row.append(Vector3(cos(a) * rr, h, sin(a) * rr))
		pts.append(row)
	for j in rings:
		for i in segs:
			var a: Vector3 = pts[j][i]
			var b: Vector3 = pts[j][i + 1]
			var c: Vector3 = pts[j + 1][i]
			var d2: Vector3 = pts[j + 1][i + 1]
			st.add_vertex(a)
			st.add_vertex(c)
			st.add_vertex(b)
			st.add_vertex(b)
			st.add_vertex(c)
			st.add_vertex(d2)
	st.generate_normals()
	var mi := MeshInstance3D.new()
	mi.name = "Mountains"
	mi.mesh = st.commit()
	var m := StandardMaterial3D.new()
	m.albedo_color = _col(layout.get("look", {}).get("mountains", [0.46, 0.22, 0.14]))
	m.roughness = 1.0
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	mi.material_override = m
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)


# ------------------------------------------------------------------------------------- city furniture ---
## (The room calls these; each returns the node so it can hang a hotspot near it.)

## A stone statue stand-in: a hooded, robed figure on a plinth (Glen's Daz statues replace it later).
func statue(nm: String, at: Vector3, facing_deg: float, staff: bool, height: float = 2.3) -> Node3D:
	var root := Node3D.new()
	root.name = nm
	root.position = at
	root.rotation_degrees.y = facing_deg
	add_child(root)
	var stone := _stone_material(_col([0.80, 0.62, 0.52]), 0.0)
	var plinth := _part(root, BoxMesh.new(), Vector3(0, 0.6, 0), stone)
	(plinth.mesh as BoxMesh).size = Vector3(1.8, 1.2, 1.8)
	var k := height / 2.3
	var robe := CylinderMesh.new()
	robe.top_radius = 0.26 * k
	robe.bottom_radius = 0.52 * k
	robe.height = 1.55 * k
	_part(root, robe, Vector3(0, 1.2 + robe.height * 0.5, 0), stone)
	var chest := CylinderMesh.new()
	chest.top_radius = 0.24 * k
	chest.bottom_radius = 0.30 * k
	chest.height = 0.45 * k
	_part(root, chest, Vector3(0, 1.2 + (1.55 + 0.2) * k, 0), stone)
	var head := SphereMesh.new()
	head.radius = 0.15 * k
	head.height = 0.32 * k
	_part(root, head, Vector3(0, 1.2 + 2.1 * k, 0.02 * k), stone)
	var hood := SphereMesh.new()
	hood.radius = 0.21 * k
	hood.height = 0.42 * k
	hood.is_hemisphere = true
	var h := _part(root, hood, Vector3(0, 1.2 + 2.1 * k, -0.03 * k), stone)
	h.rotation_degrees.x = -12.0
	if staff:
		var cyl := CylinderMesh.new()
		cyl.top_radius = 0.03 * k
		cyl.bottom_radius = 0.035 * k
		cyl.height = 2.5 * k
		_part(root, cyl, Vector3(0.42 * k, 1.2 + 1.25 * k, 0.12 * k), stone)
		var arm := CylinderMesh.new()
		arm.top_radius = 0.06 * k
		arm.bottom_radius = 0.07 * k
		arm.height = 0.55 * k
		var a := _part(root, arm, Vector3(0.30 * k, 1.2 + 1.75 * k, 0.1 * k), stone)
		a.rotation_degrees.z = 55.0
	var body := StaticBody3D.new()
	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = Vector3(1.8, 1.2 + 2.3 * k, 1.8)
	cs.shape = bs
	cs.position.y = bs.size.y * 0.5
	body.add_child(cs)
	root.add_child(body)
	return root


## A tour stone: a lectern-high carved stone with a glowing glyph on its top.
func tour_stone(nm: String, at: Vector3, number: int) -> Node3D:
	var root := Node3D.new()
	root.name = nm
	root.position = at
	add_child(root)
	var stone := _stone_material(_col([0.62, 0.42, 0.34]), 0.0)
	var b := _part(root, BoxMesh.new(), Vector3(0, 0.5, 0), stone)
	(b.mesh as BoxMesh).size = Vector3(0.55, 1.0, 0.55)
	var top := _part(root, BoxMesh.new(), Vector3(0, 1.03, 0), stone)
	(top.mesh as BoxMesh).size = Vector3(0.7, 0.08, 0.7)
	var glow := StandardMaterial3D.new()
	glow.albedo_color = Color(1.0, 0.62, 0.30)
	glow.emission_enabled = true
	glow.emission = Color(1.0, 0.55, 0.22)
	glow.emission_energy_multiplier = 2.2
	var g := _part(root, CylinderMesh.new(), Vector3(0, 1.08, 0), glow)
	(g.mesh as CylinderMesh).top_radius = 0.18
	(g.mesh as CylinderMesh).bottom_radius = 0.18
	(g.mesh as CylinderMesh).height = 0.02
	var lbl := Label3D.new()
	lbl.text = str(number)
	lbl.font_size = 64
	lbl.pixel_size = 0.004
	lbl.modulate = Color(1.0, 0.85, 0.6)
	lbl.position = Vector3(0, 0.62, 0.28)
	lbl.outline_size = 0
	root.add_child(lbl)
	var lbl2 := lbl.duplicate() as Label3D
	lbl2.position = Vector3(0, 0.62, -0.28)
	lbl2.rotation_degrees.y = 180.0
	root.add_child(lbl2)
	var body := StaticBody3D.new()
	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = Vector3(0.6, 1.1, 0.6)
	cs.shape = bs
	cs.position.y = 0.55
	body.add_child(cs)
	root.add_child(body)
	return root


## A public transit pad: a stone disc with a glowing ring.
func transit_pad(nm: String, at: Vector3) -> Node3D:
	var root := Node3D.new()
	root.name = nm
	root.position = at
	add_child(root)
	var disc := CylinderMesh.new()
	disc.top_radius = 1.6
	disc.bottom_radius = 1.7
	disc.height = 0.12
	_part(root, disc, Vector3(0, 0.06, 0), _stone_material(_col([0.55, 0.50, 0.50]), 0.0))
	var ring := TorusMesh.new()
	ring.inner_radius = 1.25
	ring.outer_radius = 1.38
	var glow := StandardMaterial3D.new()
	glow.albedo_color = Color(0.5, 0.8, 1.0)
	glow.emission_enabled = true
	glow.emission = Color(0.45, 0.75, 1.0)
	glow.emission_energy_multiplier = 1.6
	var r := _part(root, ring, Vector3(0, 0.13, 0), glow)
	r.scale = Vector3(1.0, 0.25, 1.0)
	var post := _part(root, BoxMesh.new(), Vector3(1.9, 0.75, 0), _stone_material(_col([0.55, 0.42, 0.36]), 0.0))
	(post.mesh as BoxMesh).size = Vector3(0.3, 1.5, 0.5)
	return root


## The water garden: a stone basin of still water.
func pool(nm: String, at: Vector3, size: Vector2) -> Node3D:
	var root := Node3D.new()
	root.name = nm
	root.position = at
	add_child(root)
	var stone := _stone_material(_col([0.70, 0.52, 0.42]), 0.0)
	for side in [[Vector3(0, 0.25, -size.y * 0.5), Vector3(size.x + 0.6, 0.5, 0.3)], [Vector3(0, 0.25, size.y * 0.5), Vector3(size.x + 0.6, 0.5, 0.3)],
			[Vector3(-size.x * 0.5, 0.25, 0), Vector3(0.3, 0.5, size.y)], [Vector3(size.x * 0.5, 0.25, 0), Vector3(0.3, 0.5, size.y)]]:
		var b := _part(root, BoxMesh.new(), side[0], stone)
		(b.mesh as BoxMesh).size = side[1]
	var water := StandardMaterial3D.new()
	water.albedo_color = Color(0.20, 0.36, 0.40, 0.85)
	water.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	water.metallic = 0.3
	water.roughness = 0.04
	var w := _part(root, PlaneMesh.new(), Vector3(0, 0.36, 0), water)
	(w.mesh as PlaneMesh).size = size
	var body := StaticBody3D.new()
	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = Vector3(size.x + 0.6, 0.9, size.y + 0.3)
	cs.shape = bs
	cs.position.y = 0.45
	body.add_child(cs)
	root.add_child(body)
	return root


## The sand garden: raked lines in pale sand, with three dark meditation stones.
func sand_garden(nm: String, at: Vector3, size: Vector2) -> Node3D:
	var root := Node3D.new()
	root.name = nm
	root.position = at
	add_child(root)
	var sh := Shader.new()
	sh.code = """shader_type spatial;
uniform vec3 sand : source_color = vec3(0.93, 0.80, 0.66);
void fragment() {
	float r = sin(UV.y * 260.0) * 0.5 + 0.5;
	ALBEDO = sand * (0.86 + 0.14 * r);
	ROUGHNESS = 0.95;
	NORMAL_MAP = vec3(0.5, 0.5 + cos(UV.y * 260.0) * 0.18, 1.0);
}"""
	var m := ShaderMaterial.new()
	m.shader = sh
	var plane := _part(root, PlaneMesh.new(), Vector3(0, 0.03, 0), m)
	(plane.mesh as PlaneMesh).size = size
	var dark := _stone_material(Color(0.25, 0.16, 0.13), 0.0)
	for s in [[Vector3(-size.x * 0.25, 0.25, -size.y * 0.15), 0.55], [Vector3(size.x * 0.2, 0.18, size.y * 0.2), 0.4], [Vector3(size.x * 0.3, 0.3, -size.y * 0.25), 0.62]]:
		var sp := SphereMesh.new()
		sp.radius = float(s[1])
		sp.height = float(s[1]) * 1.2
		var st := _part(root, sp, s[0], dark)
		st.scale = Vector3(1.3, 0.7, 1.0)
	var rim := _stone_material(_col([0.70, 0.52, 0.42]), 0.0)
	for side in [[Vector3(0, 0.08, -size.y * 0.5), Vector3(size.x, 0.16, 0.2)], [Vector3(0, 0.08, size.y * 0.5), Vector3(size.x, 0.16, 0.2)],
			[Vector3(-size.x * 0.5, 0.08, 0), Vector3(0.2, 0.16, size.y)], [Vector3(size.x * 0.5, 0.08, 0), Vector3(0.2, 0.16, size.y)]]:
		var b := _part(root, BoxMesh.new(), side[0], rim)
		(b.mesh as BoxMesh).size = side[1]
	return root


## The far-viewer on the parapet: a post with a hooded eyepiece.
func far_viewer(nm: String, at: Vector3, facing_deg: float) -> Node3D:
	var root := Node3D.new()
	root.name = nm
	root.position = at
	root.rotation_degrees.y = facing_deg
	add_child(root)
	var metal := StandardMaterial3D.new()
	metal.albedo_color = Color(0.45, 0.30, 0.22)
	metal.metallic = 0.7
	metal.roughness = 0.35
	var post := CylinderMesh.new()
	post.top_radius = 0.06
	post.bottom_radius = 0.12
	post.height = 1.25
	_part(root, post, Vector3(0, 0.62, 0), metal)
	var head := _part(root, BoxMesh.new(), Vector3(0, 1.35, 0.05), metal)
	(head.mesh as BoxMesh).size = Vector3(0.42, 0.22, 0.5)
	var lens := CylinderMesh.new()
	lens.top_radius = 0.07
	lens.bottom_radius = 0.07
	lens.height = 0.2
	var l := _part(root, lens, Vector3(0, 1.35, 0.36), metal)
	l.rotation_degrees.x = 90.0
	return root


## A sehlat, lying in the shade: the real one (core/creatures/Sehlat.gd, REV 878) when its model is there, else the old
## stand-in of soft shapes. Six-inch fangs either way.
func sehlat(nm: String, at: Vector3, facing_deg: float) -> Node3D:
	var real: Node3D = (load("res://core/creatures/Sehlat.gd") as Script).call("make", self, nm, at, facing_deg)
	if real != null:
		return real
	var root := Node3D.new()
	root.name = nm
	root.position = at
	root.rotation_degrees.y = facing_deg
	add_child(root)
	var fur := StandardMaterial3D.new()
	fur.albedo_color = Color(0.42, 0.30, 0.20)
	fur.roughness = 1.0
	var body := CapsuleMesh.new()
	body.radius = 0.75
	body.height = 2.6
	var b := _part(root, body, Vector3(0, 0.72, 0), fur)
	b.rotation_degrees.x = 90.0
	b.scale = Vector3(1.15, 1.0, 0.85)
	var head := SphereMesh.new()
	head.radius = 0.5
	head.height = 0.9
	_part(root, head, Vector3(0, 0.62, 1.55), fur)
	var snout := SphereMesh.new()
	snout.radius = 0.25
	snout.height = 0.4
	_part(root, snout, Vector3(0, 0.5, 2.0), fur)
	for side in [-1.0, 1.0]:
		var ear := SphereMesh.new()
		ear.radius = 0.15
		ear.height = 0.25
		_part(root, ear, Vector3(0.3 * side, 1.05, 1.45), fur)
		var fang := CylinderMesh.new()
		fang.top_radius = 0.035
		fang.bottom_radius = 0.0
		fang.height = 0.18
		var ivory := _flat(Color(0.92, 0.88, 0.76))
		_part(root, fang, Vector3(0.1 * side, 0.3, 2.12), ivory)
		var paw := SphereMesh.new()
		paw.radius = 0.22
		paw.height = 0.3
		_part(root, paw, Vector3(0.45 * side, 0.15, 1.45 if side < 0.0 else 1.75), fur)
	var col := StaticBody3D.new()
	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = Vector3(1.8, 1.4, 4.4)
	cs.shape = bs
	cs.position = Vector3(0, 0.7, 0.4)
	col.add_child(cs)
	root.add_child(col)
	return root


func _part(parent: Node3D, mesh: Mesh, pos: Vector3, mat: Material) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.position = pos
	mi.material_override = mat
	parent.add_child(mi)
	return mi


# -------------------------------------------------------------------------------------------- materials ---

func _col(a: Variant) -> Color:
	var v: Array = a
	return Color(float(v[0]), float(v[1]), float(v[2]))


func _flat(c: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = 0.9
	return m


func _tex(path: String) -> Texture2D:
	return load(path) as Texture2D if ResourceLoader.exists(path) else null


## Cliff and plinth stone: the kit's sandstone, world-mapped so it never stretches, tinted like the pieces.
func _stone_material(c: Color, _unused: float) -> StandardMaterial3D:
	var key := "stone" + str(c)
	if _mat_cache.has(key):
		return _mat_cache[key]
	var m := StandardMaterial3D.new()
	m.albedo_color = c * tint * Color(1.15, 1.15, 1.15)
	m.albedo_texture = _tex(STONE_COL)
	m.normal_enabled = m.albedo_texture != null and _tex(STONE_NRM) != null
	if m.normal_enabled:
		m.normal_texture = _tex(STONE_NRM)
	m.uv1_triplanar = true
	m.uv1_world_triplanar = true
	m.uv1_scale = Vector3(0.25, 0.25, 0.25)
	m.roughness = 0.9
	_mat_cache[key] = m
	return m


func _paving_material() -> StandardMaterial3D:
	if _mat_cache.has("paving"):
		return _mat_cache["paving"]
	var m := StandardMaterial3D.new()
	m.albedo_color = tint * Color(1.05, 1.05, 1.05)
	m.albedo_texture = _tex(PAVING_COL)
	m.normal_enabled = m.albedo_texture != null and _tex(PAVING_NRM) != null
	if m.normal_enabled:
		m.normal_texture = _tex(PAVING_NRM)
	m.uv1_triplanar = true
	m.uv1_world_triplanar = true
	m.uv1_scale = Vector3(0.2, 0.2, 0.2)
	m.roughness = 0.85
	_mat_cache["paving"] = m
	return m


func _sand_material() -> StandardMaterial3D:
	if _mat_cache.has("sand"):
		return _mat_cache["sand"]
	var m := StandardMaterial3D.new()
	var t := _tex(SAND_TEX)
	m.albedo_color = Color(0.95, 0.70, 0.52) if t != null else Color(0.78, 0.52, 0.34)
	m.albedo_texture = t
	m.uv1_triplanar = true
	m.uv1_world_triplanar = true
	m.uv1_scale = Vector3(0.12, 0.12, 0.12)
	m.roughness = 1.0
	_mat_cache["sand"] = m
	return m
