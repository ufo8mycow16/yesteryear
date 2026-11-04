extends Node3D
## The Guardian's planet: a ruined cliff top above a misty red canyon, at stormy dusk.
##
## The Guardian stands at the origin facing +Z. Everything here is built when the node enters the tree:
##   ground   a terrain mesh: a flat paved cliff top round the Guardian (y = 0), a winding gorge that drops
##            away in front and to the right, rolling broken land beyond (red canyon rock, wrapped from all sides)
##   rocks    Vasquez Rocks pieces as spires near the canyon and as hazy ridges on the skyline
##   ruins    the Egyptian ruin pieces and the colony column, standing, leaning and fallen round the cliff top
##   sky      Glen's stormy dusk panorama, low warm sun, fog that lies in the canyon
## No collision: this set is for the watch-through (no one walks; characters are placed at y = 0 on the top).

const RED_ROCK := "res://assets/textures/rock/red_canyon_rock.png"
const GREY_ROCK := "res://assets/textures/rock/sarRock01_Color.jpg"
const GREY_ROCK_N := "res://assets/textures/rock/sarRock01_Normal.jpg"
const SKY := "res://assets/textures/sky/storm_dusk_panorama.png"
const VASQUEZ := "res://assets/models/maps/vasquez_rocks.glb"
const COLUMN := "res://assets/models/column/nc_column.gltf"
const RUINS := {
	"arch": "res://assets/models/ruins/ruin_arch.gltf",
	"curved": "res://assets/models/ruins/ruin_colonnade_curved.gltf",
	"long": "res://assets/models/ruins/ruin_colonnade_long.gltf",
	"gatehouse": "res://assets/models/ruins/ruin_gatehouse.gltf",
	"corner": "res://assets/models/ruins/ruin_temple_corner.gltf",
}
const GUARDIAN := "res://scenes/guardian/Guardian.tscn"

const SIZE := 360.0        # terrain is SIZE x SIZE metres
const GRID := 200          # cells per side
const TOP_RADIUS := 13.0   # the flat cliff top round the Guardian

var guardian: Node3D = null
var environment: Environment = null
var _noise := FastNoiseLite.new()


func _ready() -> void:
	_noise.seed = 1973
	_noise.frequency = 0.012
	_noise.fractal_octaves = 4
	_build_sky_and_light()
	_build_terrain()
	_build_paving()
	_build_rocks()
	_build_ruins()
	_build_guardian()


## Height of the land at x, z. The cliff top is flat at 0; the gorge runs in a curve in front of the Guardian
## and out to the right; everything else rolls between about -4 and +10 m.
func height(x: float, z: float) -> float:
	var r := Vector2(x, z).length()
	var land := 2.0 + _noise.get_noise_2d(x, z) * 9.0 + _noise.get_noise_2d(x * 3.1, z * 3.1) * 2.0
	# the gorge: a curving channel whose centre line passes about 16 m in front of the Guardian
	var cx := 12.0 + 22.0 * sin(z * 0.018)            # wanders left and right as it goes
	var along := z - 16.0
	var dist := absf(x - cx) if along > -40.0 else absf(Vector2(x - cx, along + 40.0).length())
	var gorge_w := 14.0 + 6.0 * sin(z * 0.05 + 1.0)
	var depth := -30.0
	var g := smoothstep(gorge_w, gorge_w * 0.45, dist)      # 0 outside, 1 in the bottom
	var h := lerpf(land, depth + _noise.get_noise_2d(x * 2.0, z * 2.0) * 3.0, g)
	# the cliff top: flat and solid round the Guardian, falling off sharply at its edge towards the gorge
	var top := smoothstep(TOP_RADIUS + 6.0, TOP_RADIUS, r)
	h = lerpf(h, 0.0, top)
	return h


func _build_terrain() -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var step := SIZE / float(GRID)
	var half := SIZE * 0.5
	var pts := PackedVector3Array()
	pts.resize((GRID + 1) * (GRID + 1))
	for zi in GRID + 1:
		for xi in GRID + 1:
			var x := -half + xi * step
			var z := -half + zi * step
			pts[zi * (GRID + 1) + xi] = Vector3(x, height(x, z), z)
	for zi in GRID:
		for xi in GRID:
			var a := pts[zi * (GRID + 1) + xi]
			var b := pts[zi * (GRID + 1) + xi + 1]
			var c := pts[(zi + 1) * (GRID + 1) + xi + 1]
			var d := pts[(zi + 1) * (GRID + 1) + xi]
			for p in [a, b, c, a, c, d]:
				st.add_vertex(p)
	st.generate_normals()
	var mi := MeshInstance3D.new()
	mi.name = "Canyon"
	mi.mesh = st.commit()
	mi.material_override = _rock_material(RED_ROCK, "", Color(1.0, 0.93, 0.88), 0.12, true)
	add_child(mi)


## The worn paving round the Guardian: big flat grey slabs, slightly uneven, some missing.
func _build_paving() -> void:
	var mat := _rock_material(GREY_ROCK, GREY_ROCK_N, Color(0.72, 0.66, 0.62), 0.35, false)
	var rng := RandomNumberGenerator.new()
	rng.seed = 5373
	var slab := 2.2
	for zi in range(-6, 6):
		for xi in range(-6, 6):
			var p := Vector3((xi + 0.5) * slab, 0.0, (zi + 0.5) * slab)
			if p.length() > TOP_RADIUS - 1.0 or rng.randf() < 0.12:
				continue
			var box := MeshInstance3D.new()
			var bm := BoxMesh.new()
			bm.size = Vector3(slab - 0.06 - rng.randf() * 0.1, 0.25, slab - 0.06 - rng.randf() * 0.1)
			box.mesh = bm
			box.material_override = mat
			box.position = p + Vector3(0.0, -0.12 + rng.randf_range(-0.03, 0.03), 0.0)
			box.rotation = Vector3(rng.randf_range(-0.015, 0.015), rng.randf_range(-0.03, 0.03), rng.randf_range(-0.015, 0.015))
			add_child(box)


func _build_rocks() -> void:
	# [x, z, height, yaw, tilt] - spires along the canyon and the near rim, then a hazy ring of ridges far off
	var near := [
		[-22.0, -8.0, 26.0, 20.0, 8.0], [-30.0, 14.0, 18.0, 140.0, -6.0], [38.0, 4.0, 30.0, 75.0, 10.0],
		[30.0, 44.0, 22.0, 200.0, -12.0], [-8.0, 52.0, 16.0, 300.0, 5.0], [55.0, 70.0, 34.0, 15.0, 6.0],
		[-45.0, 40.0, 28.0, 250.0, -9.0], [18.0, -34.0, 20.0, 110.0, 7.0], [-28.0, -40.0, 24.0, 330.0, -5.0],
	]
	for r in near:
		_place_rock(Vector3(r[0], height(r[0], r[1]) - 2.0, r[1]), r[2], r[3], r[4])
	for i in 16:
		var ang := TAU * float(i) / 16.0 + 0.2
		var dist := 130.0 + 25.0 * sin(float(i) * 2.3)
		var p := Vector3(cos(ang) * dist, -8.0, sin(ang) * dist)
		_place_rock(p, 40.0 + 20.0 * absf(sin(float(i) * 1.7)), rad_to_deg(ang) + 90.0, 4.0 * sin(float(i)))


func _place_rock(at: Vector3, tall: float, yaw_deg: float, tilt_deg: float) -> void:
	var node := _load_scaled(VASQUEZ, tall)
	if node == null:
		return
	node.position = at
	node.rotation_degrees = Vector3(tilt_deg, yaw_deg, 0.0)
	add_child(node)


func _build_ruins() -> void:
	# behind and beside the Guardian: broken walls and colonnades on the cliff top's back edge
	_place_ruin("corner", Vector3(-10.0, -0.4, -9.0), 6.5, 35.0, Vector3(0, 0, 4))
	_place_ruin("long", Vector3(6.0, -0.6, -12.0), 5.5, -10.0, Vector3(3, 0, -2))
	_place_ruin("arch", Vector3(-13.0, -0.3, 3.0), 5.0, 80.0, Vector3(0, 0, -6))
	_place_ruin("curved", Vector3(14.0, -0.8, -5.0), 4.5, -60.0, Vector3(-4, 0, 3))
	# columns: four standing round the Guardian, two leaning, three fallen and broken across the paving
	var cols := [
		[-4.2, 3.4, 4.2, 0.0, 0.0], [4.0, 3.2, 4.0, 0.0, 0.0], [-5.5, -4.0, 4.6, 0.0, 0.0], [5.2, -4.5, 3.4, 0.0, 0.0],
		[-8.0, -1.0, 4.4, 0.0, 9.0], [8.5, 1.5, 3.8, 0.0, -12.0],
	]
	for c in cols:
		_place_column(Vector3(c[0], -0.05, c[1]), c[2], c[3], c[4], 0.0)
	_place_column(Vector3(-2.5, 0.35, 7.5), 4.0, 70.0, 90.0, 0.0)
	_place_column(Vector3(7.0, 0.35, 6.0), 3.0, -20.0, 90.0, 0.0)
	_place_column(Vector3(-7.5, 0.35, -6.8), 2.6, 130.0, 90.0, 0.0)


func _place_ruin(key: String, at: Vector3, tall: float, yaw_deg: float, tilt_deg: Vector3) -> void:
	var node := _load_scaled(String(RUINS[key]), tall)
	if node == null:
		return
	node.position = at
	node.rotation_degrees = Vector3(tilt_deg.x, yaw_deg, tilt_deg.z)
	add_child(node)


## A column standing (tilt 0) or lying (tilt 90). Lying ones are lifted by their radius at the call site.
func _place_column(at: Vector3, tall: float, yaw_deg: float, tilt_deg: float, _unused: float) -> void:
	var node := _load_scaled(COLUMN, tall)
	if node == null:
		return
	node.position = at
	node.rotation_degrees = Vector3(0.0, yaw_deg, tilt_deg)
	add_child(node)


func _build_guardian() -> void:
	if not ResourceLoader.exists(GUARDIAN):
		return
	guardian = (load(GUARDIAN) as PackedScene).instantiate() as Node3D
	guardian.name = "Guardian"
	add_child(guardian)


func _build_sky_and_light() -> void:
	var sky_mat := PanoramaSkyMaterial.new()
	if ResourceLoader.exists(SKY):
		sky_mat.panorama = load(SKY)
	var sky := Sky.new()
	sky.sky_material = sky_mat
	environment = Environment.new()
	environment.background_mode = Environment.BG_SKY
	environment.sky = sky
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	environment.ambient_light_energy = 0.75
	environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	environment.tonemap_exposure = 1.05
	environment.glow_enabled = true
	environment.glow_intensity = 0.6
	environment.glow_bloom = 0.08
	# haze across the land, and a thick bank lying in the canyon
	environment.fog_enabled = true
	environment.fog_light_color = Color(0.62, 0.5, 0.58)
	environment.fog_density = 0.0045
	environment.fog_sky_affect = 0.15
	environment.fog_height = -6.0
	environment.fog_height_density = 0.18
	var we := WorldEnvironment.new()
	we.name = "WorldEnvironment"
	we.environment = environment
	add_child(we)
	var sun := DirectionalLight3D.new()
	sun.name = "Sun"
	sun.light_color = Color(1.0, 0.72, 0.48)
	sun.light_energy = 1.35
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 120.0
	sun.rotation_degrees = Vector3(-14.0, -135.0, 0.0)    # low in the sky, over the gold side of the clouds
	add_child(sun)


## Loads a model and scales it so its height is `tall` metres, with its base on its own origin.
func _load_scaled(path: String, tall: float) -> Node3D:
	if not ResourceLoader.exists(path):
		push_warning("GuardianPlanet: missing %s" % path)
		return null
	var res: Resource = load(path)
	if not (res is PackedScene):
		return null
	var inst := (res as PackedScene).instantiate() as Node3D
	var box := _aabb_of(inst)
	var holder := Node3D.new()
	holder.name = path.get_file().get_basename()
	holder.add_child(inst)
	if box.size.y > 0.001:
		var s := tall / box.size.y
		inst.scale = Vector3.ONE * s
		inst.position = -Vector3(box.get_center().x, box.position.y, box.get_center().z) * s
	return holder


static func _aabb_of(root: Node3D) -> AABB:
	var out := AABB()
	var first := true
	for node in root.find_children("*", "MeshInstance3D", true, false):
		var mi := node as MeshInstance3D
		if mi.mesh == null:
			continue
		var xf := Transform3D.IDENTITY
		var n: Node = mi
		while n != null and n != root:
			if n is Node3D:
				xf = (n as Node3D).transform * xf
			n = n.get_parent()
		var b := xf * mi.mesh.get_aabb()
		if first:
			out = b
			first = false
		else:
			out = out.merge(b)
	return out


func _rock_material(albedo_path: String, normal_path: String, tint: Color, uv_scale: float, world: bool) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = tint
	if ResourceLoader.exists(albedo_path):
		m.albedo_texture = load(albedo_path)
	if normal_path != "" and ResourceLoader.exists(normal_path):
		m.normal_enabled = true
		m.normal_texture = load(normal_path)
	m.roughness = 0.95
	m.uv1_triplanar = true
	m.uv1_world_triplanar = world
	m.uv1_triplanar_sharpness = 4.0
	m.uv1_scale = Vector3.ONE * uv_scale
	return m
