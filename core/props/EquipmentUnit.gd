extends RefCounted
class_name EquipmentUnit
## REV 556 (Glen: "why is the rosin bag sitting on the seat? Shouldn't there be a rack of stuff like bowling
## shoes and spare balls and towels and the bag there as well?"): the bowling alley's equipment stand -
## Pell's stand by the seats in PROLOGUE_SCRIPT.md section 6. Built in code in the alley's own furniture
## style (the lane console's cream panels and copper trim):
##   - a tower of shoe cubbies (5 x 4), two-tone bowling shoes in pairs, a few out on loan, size plates;
##   - a cabinet with a copper-edged counter: a chrome ROSIN TRAY (where the rosin bag lives) and a
##     chrome rail with three spare house balls;
##   - a towel rail on the wall above the counter, three towels in the division colours;
##   - a RECREATION EQUIPMENT plate on top.
## Only the picture and a solid body; the rosin bag's hotspot belongs to the room (BowlingAlley).
## `pos` is the floor point at the wall, in the middle of the stand's length; `yaw_deg` turns it so its
## front (+Z) faces into the room. Length runs along local X: the counter at -X, the cubbies at +X.

const LENGTH := 2.6
const DEPTH := 0.42
const CUBBY_X := Vector2(-0.15, 1.3)      # local x range of the shoe tower
const COUNTER_X := Vector2(-1.3, -0.15)   # local x range of the cabinet
const TOWER_HEIGHT := 1.9
const COUNTER_HEIGHT := 0.92
const PLINTH := 0.08
const COLS := 5
const SHELF_LIP := 0.042          # REV 559: the cream lip on each shelf's front edge, carrying the size number
const ROWS := 4
## Cubbies with no shoes in them (column, row) - on loan to whoever is bowling.
const EMPTY_CUBBIES := [Vector2i(1, 0), Vector2i(3, 2), Vector2i(0, 3), Vector2i(4, 1)]
## Two-tone shoe colours: [main, toe and heel caps].
const SHOE_COLOURS := [
	[Color(0.62, 0.10, 0.09), Color(0.92, 0.90, 0.85)],    # red / white
	[Color(0.14, 0.24, 0.52), Color(0.92, 0.90, 0.85)],    # blue / white
	[Color(0.68, 0.50, 0.26), Color(0.30, 0.18, 0.10)],    # tan / brown
	[Color(0.08, 0.08, 0.09), Color(0.92, 0.90, 0.85)],    # black / white
	[Color(0.16, 0.36, 0.22), Color(0.92, 0.90, 0.85)],    # green / white
]
## Where the rosin bag's tray is (local), its top surface y.
const TRAY_CENTRE := Vector3(-1.02, 0.0, 0.24)
const TRAY_SIZE := Vector3(0.26, 0.012, 0.18)
## The spare balls on the counter rail: local x of each, and their colours.
const BALL_XS := [-0.74, -0.51, -0.28]
const BALL_FILES := ["bowling_ball_black", "bowling_ball_red", "bowling_ball"]
const BALL_DIAMETER := 0.218
const RAIL_SPACING := 0.12
const RAIL_RADIUS := 0.011
const TOWEL_RAIL_Y := 1.58
const TOWEL_XS := [-1.05, -0.73, -0.41]
## Towel colours: command gold, sciences blue, operations red (with a white band).
const TOWEL_COLOURS := [Color(0.80, 0.64, 0.22), Color(0.30, 0.48, 0.74), Color(0.70, 0.14, 0.12)]
## REV 558: Glen's towel models (his towel pack, simplified by tools/props/towel_convert.gd). The hanging
## towel's origin is on its bar; the rolled bundle's under its middle. Surfaces "cloth" and "band".
const TOWEL_HANGING := "res://assets/models/props/towel_hanging.glb"
## REV 560: Glen's leather shoe, two-toned by core/props/bowling_shoe.gdshader (falls back to the
## code-built shoe if missing). Toe +Z, sole on y = 0, 27 cm long. A pair = it and its mirror image.
const SHOE_MODEL := "res://assets/models/props/bowling_shoe.glb"
const SHOE_SHADER := "res://core/props/bowling_shoe.gdshader"
const SHOE_LEATHER := "res://assets/textures/props/shoe_leather.png"
const SHOE_LEATHER_N := "res://assets/textures/props/shoe_leather_n.png"
const TOWEL_BUNDLE := "res://assets/models/props/towel_roll_bundle.glb"
const TOWEL_WIDTH := 0.28          # the hanging towel scaled to this width (its own is 0.39 m)
const BUNDLE_X := 1.05             # the rolled bundle on top of the shoe tower (local x of its middle)
const BUNDLE_COLOUR := Color(0.96, 0.95, 0.92)
const BAND_COLOUR := Color(0.90, 0.86, 0.76)
const PROPS_DIR := "res://assets/models/rec_deck/props/"
## REV 569 (Glen: "let's have all that"): a shoe deodoriser can in the counter's back-left corner, and the
## TOS yeoman-style electronic clipboard (the sign-out sheet) hanging on the shoe tower's side over the balls.
const SPRAY_AT := Vector3(-1.25, 0.0, 0.08)        # x, -, z on the counter top
const SPRAY_RADIUS := 0.032
const SPRAY_HEIGHT := 0.15
const CLIPBOARD_AT := Vector3(-0.157, 1.355, 0.22) # its middle, against the tower's side (x -0.15)
const CLIPBOARD_SIZE := Vector2(0.16, 0.23)        # width (along z), height
## REV 570: a LOST + FOUND tote with a tribble peeking over its rim (the map tribble from sickbay.glb,
## extracted into tribble.glb; three furs in assets/textures/props/). REV 571 (Glen: in front of the counter
## it blocked the cabinet doors): on the floor against the wall beside the shoe tower's far end.
const LOST_FOUND_AT := Vector3(CUBBY_X.y + 0.22, 0.0, 0.2)   # the tote's middle on the floor
const LOST_FOUND_SIZE := Vector3(0.34, 0.16, 0.24)
const TRIBBLE_MODEL := "res://assets/models/props/tribble.glb"
const TRIBBLE_FUR := "res://assets/textures/props/tribble_fur_gold.jpg"
const SIGN_FONT := "res://assets/fonts/Microgramma_D_Extended_Bold.otf"
const SIZE_FONT := "res://assets/fonts/Microgramma_D_Extended_Medium.otf"
## Terry cloth for the towels (neutral grey, tinted per towel), from the texture in Glen's towel pack
## ("Полотенца" - its 3ds Max model can't be used, the cloth picture and its bump map can).
const TERRY := "res://assets/textures/props/towel_terry.png"
const TERRY_NORMAL := "res://assets/textures/props/towel_terry_n.png"

static var _mats := {}


static func build(parent: Node3D, pos: Vector3, yaw_deg: float) -> Node3D:
	_mats.clear()
	var root := Node3D.new()
	root.name = "EquipmentUnit"
	root.position = pos
	root.rotation_degrees = Vector3(0.0, yaw_deg, 0.0)
	parent.add_child(root)
	_build_tower(root)
	_build_counter(root)
	_build_towels(root)
	_build_sign(root)
	_build_spray_can(root)
	_build_clipboard(root)
	_build_lost_and_found(root)
	_build_body(root)
	return root


## The rosin tray's top, in world space (the room sits the bag on it).
static func tray_point(unit: Node3D) -> Vector3:
	var top := PLINTH + COUNTER_HEIGHT - PLINTH + 0.04 + TRAY_SIZE.y
	return unit.to_global(Vector3(TRAY_CENTRE.x, top, TRAY_CENTRE.z))


## REV 569: where the room puts the look-at spots for the can and the clipboard (world space).
static func spray_point(unit: Node3D) -> Vector3:
	return unit.to_global(Vector3(SPRAY_AT.x, COUNTER_HEIGHT + 0.04 + SPRAY_HEIGHT * 0.5, SPRAY_AT.z))


static func lost_found_point(unit: Node3D) -> Vector3:
	return unit.to_global(LOST_FOUND_AT + Vector3(0.0, LOST_FOUND_SIZE.y * 0.6, 0.0))


static func clipboard_point(unit: Node3D) -> Vector3:
	return unit.to_global(CLIPBOARD_AT)


# ---- materials ----------------------------------------------------------------------------------

static func _mat(key: String) -> StandardMaterial3D:
	if _mats.has(key):
		return _mats[key]
	var m := StandardMaterial3D.new()
	match key:
		"cream":
			m.albedo_color = Color(0.84, 0.82, 0.77)
			m.roughness = 0.7
			m.emission_enabled = true          # like the lane console: readable outside the baked light
			m.emission = Color(0.84, 0.82, 0.77)
			m.emission_energy_multiplier = 0.2
		"grey":
			m.albedo_color = Color(0.55, 0.55, 0.54)
			m.roughness = 0.7
		"inside":
			m.albedo_color = Color(0.16, 0.16, 0.18)
			m.roughness = 0.9
		"copper":
			m.albedo_color = Color(0.69, 0.42, 0.20)
			m.metallic = 0.6
			m.roughness = 0.4
		"chrome":
			m.albedo_color = Color(0.80, 0.81, 0.83)
			m.metallic = 0.9
			m.roughness = 0.22
		"gap":
			m.albedo_color = Color(0.25, 0.25, 0.26)
			m.roughness = 0.8
		"sole":
			m.albedo_color = Color(0.12, 0.09, 0.07)
			m.roughness = 0.85
		"plate":
			m.albedo_color = Color(0.10, 0.12, 0.18)
			m.metallic = 0.3
			m.roughness = 0.5
			m.cull_mode = BaseMaterial3D.CULL_DISABLED   # REV 568: never hollow when the camera clips it
		"band":
			m.albedo_color = Color(0.93, 0.92, 0.88)
			m.roughness = 0.95
	_mats[key] = m
	return m


static func _colour(c: Color, rough: float = 0.75) -> StandardMaterial3D:
	var key := "c%s_%.2f" % [c.to_html(false), rough]
	if _mats.has(key):
		return _mats[key]
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = rough
	_mats[key] = m
	return m


static func _box(parent: Node3D, nm: String, centre: Vector3, size: Vector3, mat: Material) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.name = nm
	var bm := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	mi.material_override = mat
	mi.position = centre
	parent.add_child(mi)
	return mi


# ---- the shoe tower -----------------------------------------------------------------------------

static func _build_tower(root: Node3D) -> void:
	var tower := Node3D.new()
	tower.name = "ShoeCubbies"
	root.add_child(tower)
	var x0 := CUBBY_X.x
	var x1 := CUBBY_X.y
	var w := x1 - x0
	var cx := (x0 + x1) * 0.5
	var side := 0.03
	var shelf := 0.02
	# plinth, back, sides, top
	_box(tower, "Plinth", Vector3(cx, PLINTH * 0.5, DEPTH * 0.5 - 0.02), Vector3(w - 0.04, PLINTH, DEPTH - 0.04), _mat("grey"))
	# REV 561 (Glen: a black strip at the back of the shoe rack that flickered as the camera moved): the back
	# panel was as wide and as tall as the tower, so its ends sat exactly in the side panels' outer faces and
	# its top in the top board's - two surfaces in one place flicker. It now fits between the sides and under
	# the top, and the sides stop under the top, like a real cabinet.
	var under_top := TOWER_HEIGHT - 0.04
	_box(tower, "Back", Vector3(cx, (PLINTH + under_top) * 0.5, 0.01), Vector3(w - side * 2.0, under_top - PLINTH, 0.02), _mat("inside"))
	_box(tower, "SideA", Vector3(x0 + side * 0.5, under_top * 0.5, DEPTH * 0.5), Vector3(side, under_top, DEPTH), _mat("cream"))
	_box(tower, "SideB", Vector3(x1 - side * 0.5, under_top * 0.5, DEPTH * 0.5), Vector3(side, under_top, DEPTH), _mat("cream"))
	_box(tower, "Top", Vector3(cx, TOWER_HEIGHT - 0.02, DEPTH * 0.5 + 0.01), Vector3(w + 0.02, 0.04, DEPTH + 0.02), _mat("cream"))
	_box(tower, "TopTrim", Vector3(cx, TOWER_HEIGHT - 0.02, DEPTH * 0.5 + 0.012), Vector3(w + 0.03, 0.022, DEPTH + 0.03), _mat("copper"))
	# shelves (the bottom one sits on the plinth) and dividers
	var inner_x0 := x0 + side
	var inner_w := w - side * 2.0
	var col_w := inner_w / float(COLS)
	var y_bottom := PLINTH
	var y_top := TOWER_HEIGHT - 0.04
	var row_h := (y_top - y_bottom) / float(ROWS)
	for r in ROWS:
		var y := y_bottom + row_h * r
		_box(tower, "Shelf%d" % r, Vector3(cx, y + shelf * 0.5, DEPTH * 0.5), Vector3(inner_w, shelf, DEPTH), _mat("cream"))
		# REV 559 (Glen: the size numbers spilled over the shelf edges): a front lip under each shelf, deep
		# enough to carry the numbers
		_box(tower, "Lip%d" % r, Vector3(cx, y + shelf - SHELF_LIP * 0.5, DEPTH - 0.004), Vector3(inner_w, SHELF_LIP, 0.012), _mat("cream"))     # REV 561: 2 mm proud of the shelf edge
	for c in range(1, COLS):
		var x := inner_x0 + col_w * c
		_box(tower, "Divider%d" % c, Vector3(x, (y_bottom + y_top) * 0.5, DEPTH * 0.5), Vector3(0.018, y_top - y_bottom, DEPTH), _mat("cream"))
	# shoes and the little size plates on each shelf edge
	var size_font: Font = load(SIZE_FONT) if ResourceLoader.exists(SIZE_FONT) else null
	var n := 0
	for r in ROWS:
		for c in COLS:
			var mid_x := inner_x0 + col_w * (c + 0.5)
			var floor_y := y_bottom + row_h * r + shelf
			var size_no := 6 + n % 10       # men's sizes 6-15, then round again
			n += 1
			var label := Label3D.new()
			label.name = "Size%d_%d" % [c, r]
			label.text = str(size_no)
			if size_font != null:
				label.font = size_font
			label.font_size = 40
			label.pixel_size = 0.00062     # REV 559: 2.5 cm tall, inside the lip (was 0.0009 - 3.6 cm)
			label.modulate = Color(0.12, 0.12, 0.14)
			label.outline_size = 0
			label.shaded = true
			label.position = Vector3(mid_x, floor_y - SHELF_LIP * 0.5, DEPTH + 0.004)
			tower.add_child(label)
			if EMPTY_CUBBIES.has(Vector2i(c, r)):
				continue
			var colours: Array = SHOE_COLOURS[(c * 3 + r * 2) % SHOE_COLOURS.size()]
			for s in 2:
				var shoe := _model_shoe(colours[0], colours[1], s == 0)
				if shoe == null:
					shoe = _make_shoe(colours[0], colours[1])
				shoe.position = Vector3(mid_x + (s - 0.5) * 0.11, floor_y, DEPTH * 0.55)
				# a pair is never set down perfectly straight
				shoe.rotation_degrees = Vector3(0.0, (s - 0.5) * 6.0 + float((c * 7 + r * 5) % 5 - 2), 0.0)
				tower.add_child(shoe)


## REV 560: one of Glen's leather shoes, two-toned; `left` mirrors it so a pair is a left and a right.
static func _model_shoe(main: Color, caps: Color, left: bool) -> Node3D:
	var scene := _scene(SHOE_MODEL)
	if scene == null:
		return null
	var holder := Node3D.new()
	holder.name = "Shoe"
	var model := scene.instantiate() as Node3D
	holder.add_child(model)
	var mat := _shoe_material(main, caps)
	for m in model.find_children("*", "MeshInstance3D", true, false):
		var mi := m as MeshInstance3D
		# REV 566 (Glen: "you've only done one out of the pair"): the left shoe was the right one at scale
		# x -1, which turned it inside out - lit from inside, dark, its two-tone lost. It now gets a truly
		# mirrored copy of the mesh (positions and normals flipped, triangles rewound), made once.
		if left and mi.mesh != null:
			mi.mesh = _mirrored(mi.mesh)
		mi.material_override = mat
	return holder


static var _mirror_cache := {}

## A left-right mirror image of `mesh` that still faces outwards.
static func _mirrored(mesh: Mesh) -> Mesh:
	var key := mesh.get_rid()
	if _mirror_cache.has(key):
		return _mirror_cache[key]
	var out := ArrayMesh.new()
	for si in mesh.get_surface_count():
		var arrays: Array = mesh.surface_get_arrays(si)
		var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		for i in verts.size():
			verts[i].x = -verts[i].x
		arrays[Mesh.ARRAY_VERTEX] = verts
		if arrays[Mesh.ARRAY_NORMAL] != null:
			var norms: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
			for i in norms.size():
				norms[i].x = -norms[i].x
			arrays[Mesh.ARRAY_NORMAL] = norms
		if arrays[Mesh.ARRAY_INDEX] != null:
			var idx: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
			for i in range(0, idx.size() - 2, 3):
				var t := idx[i + 1]
				idx[i + 1] = idx[i + 2]
				idx[i + 2] = t
			arrays[Mesh.ARRAY_INDEX] = idx
		arrays[Mesh.ARRAY_TANGENT] = null    # REV 567: rebuilt below rather than flipped by hand (Glen: one shoe less shiny)
		var st := SurfaceTool.new()
		st.create_from_arrays(arrays)
		if arrays[Mesh.ARRAY_TEX_UV] != null:
			st.generate_tangents()
		st.commit(out)
		out.surface_set_material(out.get_surface_count() - 1, mesh.surface_get_material(si))
	_mirror_cache[key] = out
	return out


static func _shoe_material(main: Color, caps: Color) -> Material:
	var key := "shoe%s%s" % [main.to_html(false), caps.to_html(false)]
	if _mats.has(key):
		return _mats[key]
	var m := ShaderMaterial.new()
	if ResourceLoader.exists(SHOE_SHADER):
		m.shader = load(SHOE_SHADER)
	if ResourceLoader.exists(SHOE_LEATHER):
		m.set_shader_parameter("leather", load(SHOE_LEATHER))
	if ResourceLoader.exists(SHOE_LEATHER_N):
		m.set_shader_parameter("leather_normal", load(SHOE_LEATHER_N))
	m.set_shader_parameter("main_col", main)
	m.set_shader_parameter("cap_col", caps)
	_mats[key] = m
	return m


## One bowling shoe, toe toward +Z, its sole on y = 0 (the code-built fallback).
static func _make_shoe(main: Color, caps: Color) -> Node3D:
	var shoe := Node3D.new()
	shoe.name = "Shoe"
	_box(shoe, "Sole", Vector3(0.0, 0.0125, 0.0), Vector3(0.088, 0.025, 0.26), _mat("sole"))
	var upper := MeshInstance3D.new()
	upper.name = "Upper"
	var sph := SphereMesh.new()
	sph.radius = 0.5
	sph.height = 1.0
	sph.radial_segments = 16
	sph.rings = 8
	upper.mesh = sph
	upper.material_override = _colour(main, 0.6)
	upper.scale = Vector3(0.086, 0.085, 0.25)
	upper.position = Vector3(0.0, 0.05, -0.005)
	shoe.add_child(upper)
	for cap in [[0.085, 0.10], [-0.095, 0.08]]:      # toe, heel: [z, length]
		var c := MeshInstance3D.new()
		c.name = "Cap"
		c.mesh = sph
		c.material_override = _colour(caps, 0.55)
		c.scale = Vector3(0.089, 0.062, float(cap[1]))
		c.position = Vector3(0.0, 0.04, float(cap[0]))
		shoe.add_child(c)
	_box(shoe, "Laces", Vector3(0.0, 0.088, 0.025), Vector3(0.036, 0.008, 0.075), _colour(caps, 0.8))
	return shoe


# ---- the counter --------------------------------------------------------------------------------

static func _build_counter(root: Node3D) -> void:
	var cab := Node3D.new()
	cab.name = "Counter"
	root.add_child(cab)
	var x0 := COUNTER_X.x
	var x1 := COUNTER_X.y
	var w := x1 - x0
	var cx := (x0 + x1) * 0.5
	var top_y := COUNTER_HEIGHT
	_box(cab, "Plinth", Vector3(cx, PLINTH * 0.5, DEPTH * 0.5 - 0.02), Vector3(w - 0.04, PLINTH, DEPTH - 0.04), _mat("grey"))
	_box(cab, "Body", Vector3(cx, (PLINTH + top_y) * 0.5, DEPTH * 0.5 - 0.005), Vector3(w, top_y - PLINTH, DEPTH - 0.01), _mat("cream"))
	# two sliding doors: a dark gap between them and round them, chrome pulls
	_box(cab, "DoorGap", Vector3(cx, (PLINTH + top_y) * 0.5, DEPTH - 0.004), Vector3(0.008, top_y - PLINTH - 0.06, 0.006), _mat("gap"))
	_box(cab, "DoorLineTop", Vector3(cx, top_y - 0.035, DEPTH - 0.004), Vector3(w - 0.06, 0.006, 0.006), _mat("gap"))
	_box(cab, "DoorLineBottom", Vector3(cx, PLINTH + 0.03, DEPTH - 0.004), Vector3(w - 0.06, 0.006, 0.006), _mat("gap"))
	for px in [cx - 0.09, cx + 0.09]:
		_box(cab, "Pull", Vector3(px, top_y * 0.55, DEPTH + 0.004), Vector3(0.012, 0.12, 0.014), _mat("chrome"))
	# the counter top, copper edged like the lane console
	_box(cab, "Top", Vector3(cx, top_y + 0.02, DEPTH * 0.5 + 0.015), Vector3(w + 0.02, 0.04, DEPTH + 0.03), _mat("cream"))
	_box(cab, "TopTrim", Vector3(cx, top_y + 0.02, DEPTH * 0.5 + 0.017), Vector3(w + 0.03, 0.022, DEPTH + 0.04), _mat("copper"))
	var surface := top_y + 0.04
	# the rosin tray: a shallow chrome dish with a lip
	var tray := Node3D.new()
	tray.name = "RosinTray"
	tray.position = Vector3(TRAY_CENTRE.x, surface, TRAY_CENTRE.z)
	cab.add_child(tray)
	_box(tray, "Base", Vector3(0.0, TRAY_SIZE.y * 0.5, 0.0), TRAY_SIZE, _mat("chrome"))
	var lip := 0.022
	for e in [[Vector3(0.0, lip * 0.5, TRAY_SIZE.z * 0.5), Vector3(TRAY_SIZE.x, lip, 0.006)],
			[Vector3(0.0, lip * 0.5, -TRAY_SIZE.z * 0.5), Vector3(TRAY_SIZE.x, lip, 0.006)],
			[Vector3(TRAY_SIZE.x * 0.5, lip * 0.5, 0.0), Vector3(0.006, lip, TRAY_SIZE.z)],
			[Vector3(-TRAY_SIZE.x * 0.5, lip * 0.5, 0.0), Vector3(0.006, lip, TRAY_SIZE.z)]]:
		_box(tray, "Lip", e[0], e[1], _mat("chrome"))
	# the spare-ball rail: two chrome bars on little posts, three house balls resting on them
	var rail_y := surface + 0.03
	var rail_x0 := float(BALL_XS[0]) - 0.14
	var rail_x1 := float(BALL_XS[BALL_XS.size() - 1]) + 0.12
	for zoff in [-RAIL_SPACING * 0.5, RAIL_SPACING * 0.5]:
		var bar := MeshInstance3D.new()
		bar.name = "Rail"
		var cyl := CylinderMesh.new()
		cyl.top_radius = RAIL_RADIUS
		cyl.bottom_radius = RAIL_RADIUS
		cyl.height = rail_x1 - rail_x0
		cyl.radial_segments = 12
		bar.mesh = cyl
		bar.material_override = _mat("chrome")
		bar.rotation_degrees = Vector3(0.0, 0.0, 90.0)
		bar.position = Vector3((rail_x0 + rail_x1) * 0.5, rail_y, 0.23 + zoff)
		cab.add_child(bar)
		for px in [rail_x0 + 0.02, rail_x1 - 0.02]:
			_box(cab, "RailPost", Vector3(px, surface + 0.015, 0.23 + zoff), Vector3(0.016, 0.03, 0.016), _mat("chrome"))
	var r := BALL_DIAMETER * 0.5
	var half := RAIL_SPACING * 0.5
	var lift := sqrt(maxf(pow(r + RAIL_RADIUS, 2.0) - half * half, 0.0))
	for i in BALL_XS.size():
		var ball := _ball(String(BALL_FILES[i]))
		if ball == null:
			continue
		ball.name = "SpareBall%d" % i
		cab.add_child(ball)
		ball.position += Vector3(float(BALL_XS[i]), rail_y + lift, 0.23)
		ball.rotation_degrees.y += 37.0 * i


## A house ball from the alley's own props, centred and sized to BALL_DIAMETER (the converted map
## props are not centred on their origin).
static func _ball(file: String) -> Node3D:
	var path := PROPS_DIR + file + ".glb"
	if not ResourceLoader.exists(path):
		return null
	var packed: Resource = load(path)
	if not (packed is PackedScene):
		return null
	var model: Node3D = (packed as PackedScene).instantiate()
	var box := AABB()
	var first := true
	for m in model.find_children("*", "MeshInstance3D", true, false):
		var mi := m as MeshInstance3D
		if mi.mesh == null:
			continue
		var b := _local_xf(mi, model) * mi.get_aabb()
		box = b if first else box.merge(b)
		first = false
	var holder := Node3D.new()
	holder.add_child(model)
	if first:
		return holder
	var s := BALL_DIAMETER / maxf(box.size.x, 0.001)
	model.scale = Vector3.ONE * s
	model.position = -box.get_center() * s
	return holder


static func _local_xf(node: Node3D, top: Node3D) -> Transform3D:
	var xf := Transform3D.IDENTITY
	var n: Node = node
	while n != null and n != top:
		if n is Node3D:
			xf = (n as Node3D).transform * xf
		n = n.get_parent()
	return xf


# ---- towels -------------------------------------------------------------------------------------

static func _build_towels(root: Node3D) -> void:
	var t := Node3D.new()
	t.name = "TowelRail"
	root.add_child(t)
	var rx0 := COUNTER_X.x + 0.07
	var rx1 := COUNTER_X.y - 0.12
	var bar_z := 0.07
	var bar := MeshInstance3D.new()
	bar.name = "Bar"
	var cyl := CylinderMesh.new()
	cyl.top_radius = 0.012
	cyl.bottom_radius = 0.012
	cyl.height = rx1 - rx0
	bar.mesh = cyl
	bar.material_override = _mat("chrome")
	bar.rotation_degrees = Vector3(0.0, 0.0, 90.0)
	bar.position = Vector3((rx0 + rx1) * 0.5, TOWEL_RAIL_Y, bar_z)
	t.add_child(bar)
	for bx in [rx0, rx1]:
		_box(t, "Bracket", Vector3(bx, TOWEL_RAIL_Y, bar_z * 0.5), Vector3(0.02, 0.03, bar_z), _mat("chrome"))
	var model: PackedScene = _scene(TOWEL_HANGING)
	for i in TOWEL_XS.size():
		if model != null:
			var tw := model.instantiate() as Node3D
			tw.name = "Towel%d" % i
			tw.scale = Vector3.ONE * (TOWEL_WIDTH / 0.387)
			tw.position = Vector3(float(TOWEL_XS[i]), TOWEL_RAIL_Y, bar_z)
			tw.rotation_degrees = Vector3(0.0, float(i - 1) * 2.0, 0.0)      # a hair off square
			_dress_towel(tw, TOWEL_COLOURS[i])
			t.add_child(tw)
		else:
			_hang_towel(t, float(TOWEL_XS[i]), bar_z, TOWEL_COLOURS[i], i)
	# REV 558: a bundle of rolled white towels on top of the shoe tower
	var bundle_scene: PackedScene = _scene(TOWEL_BUNDLE)
	if bundle_scene != null:
		var bundle := bundle_scene.instantiate() as Node3D
		bundle.name = "RolledTowels"
		bundle.position = Vector3(BUNDLE_X, TOWER_HEIGHT, DEPTH * 0.45)
		bundle.rotation_degrees = Vector3(0.0, 4.0, 0.0)
		_dress_towel(bundle, BUNDLE_COLOUR)
		root.add_child(bundle)


static func _scene(path: String) -> PackedScene:
	if not ResourceLoader.exists(path):
		return null
	var r: Resource = load(path)
	return r as PackedScene


## Terry cloth on a towel model's "cloth" surfaces in `colour`, the band in a pale linen.
static func _dress_towel(node: Node, colour: Color) -> void:
	for m in node.find_children("*", "MeshInstance3D", true, false):
		var mi := m as MeshInstance3D
		if mi.mesh == null:
			continue
		for s in mi.mesh.get_surface_count():
			var src := mi.mesh.surface_get_material(s)
			var nm: String = (src.resource_name if src != null else "") + " " + mi.mesh.surface_get_name(s)
			mi.set_surface_override_material(s, _terry(BAND_COLOUR if nm.to_lower().contains("band") else colour))


## A towel folded over the bar: a front and a back drop, a rounded fold on top, a white band.
static func _hang_towel(parent: Node3D, x: float, bar_z: float, colour: Color, i: int) -> void:
	var tw := Node3D.new()
	tw.name = "Towel%d" % i
	tw.position = Vector3(x, TOWEL_RAIL_Y, bar_z)
	parent.add_child(tw)
	var width := 0.27
	var thick := 0.012
	var front_drop := 0.46 - 0.03 * (i % 2)       # not all hung exactly level
	var back_drop := 0.40
	var mat := _terry(colour)
	var fold := MeshInstance3D.new()
	fold.name = "Fold"
	var cyl := CylinderMesh.new()
	cyl.top_radius = 0.022
	cyl.bottom_radius = 0.022
	cyl.height = width
	fold.mesh = cyl
	fold.material_override = mat
	fold.rotation_degrees = Vector3(0.0, 0.0, 90.0)
	fold.position = Vector3(0.0, 0.004, 0.0)
	tw.add_child(fold)
	_box(tw, "Front", Vector3(0.0, -front_drop * 0.5, 0.017), Vector3(width, front_drop, thick), mat)
	_box(tw, "Back", Vector3(0.0, -back_drop * 0.5, -0.017), Vector3(width, back_drop, thick), mat)
	_box(tw, "Band", Vector3(0.0, -front_drop + 0.07, 0.024), Vector3(width, 0.035, 0.002), _terry(Color(0.95, 0.94, 0.90)))
	tw.rotation_degrees = Vector3(0.0, 0.0, float(i - 1) * 0.8)     # a hair off square


## Terry-cloth material in `colour` (triplanar, so the loops are the same size on every face).
static func _terry(colour: Color) -> StandardMaterial3D:
	var key := "terry%s" % colour.to_html(false)
	if _mats.has(key):
		return _mats[key]
	var m := StandardMaterial3D.new()
	m.albedo_color = colour
	m.roughness = 1.0
	if ResourceLoader.exists(TERRY):
		m.albedo_texture = load(TERRY)
		m.uv1_triplanar = true
		m.uv1_scale = Vector3(5.0, 5.0, 5.0)      # a picture every 20 cm
	if ResourceLoader.exists(TERRY_NORMAL):
		m.normal_enabled = true
		m.normal_texture = load(TERRY_NORMAL)
		m.normal_scale = 0.8
	_mats[key] = m
	return m


# ---- counter extras (REV 569) --------------------------------------------------------------------

static func _cyl(parent: Node3D, nm: String, y: float, r_top: float, r_bottom: float, h: float, mat: Material) -> MeshInstance3D:
	var cm := CylinderMesh.new()
	cm.top_radius = r_top
	cm.bottom_radius = r_bottom
	cm.height = h
	cm.radial_segments = 24
	var mi := MeshInstance3D.new()
	mi.name = nm
	mi.mesh = cm
	mi.material_override = mat
	mi.position = Vector3(0.0, y, 0.0)
	parent.add_child(mi)
	return mi


static func _build_spray_can(root: Node3D) -> void:
	var can := Node3D.new()
	can.name = "ShoeSpray"
	can.position = Vector3(SPRAY_AT.x, COUNTER_HEIGHT + 0.04, SPRAY_AT.z)
	can.rotation_degrees.y = 12.0
	root.add_child(can)
	var r := SPRAY_RADIUS
	var h := SPRAY_HEIGHT
	var body := _colour(Color(0.42, 0.62, 0.74), 0.35)
	body.metallic = 0.5
	var label := _colour(Color(0.95, 0.94, 0.90), 0.5)
	var plastic := _colour(Color(0.93, 0.93, 0.92), 0.4)
	_cyl(can, "Rim", 0.004, r * 0.97, r * 0.97, 0.008, _mat("chrome"))
	_cyl(can, "Body", h * 0.42 + 0.006, r, r, h * 0.84, body)
	_cyl(can, "Label", h * 0.40, r + 0.0006, r + 0.0006, h * 0.42, label)
	_cyl(can, "Shoulder", h * 0.84 + 0.006 + 0.011, r * 0.55, r, 0.022, _mat("chrome"))
	_cyl(can, "Valve", h * 0.84 + 0.04, 0.007, 0.009, 0.01, _mat("chrome"))
	_cyl(can, "Button", h * 0.84 + 0.05, 0.011, 0.011, 0.014, plastic)
	_box(can, "Nozzle", Vector3(0.0, h * 0.84 + 0.052, 0.012), Vector3(0.006, 0.006, 0.006), _mat("gap"))
	var text := Label3D.new()
	text.name = "LabelText"
	text.text = "FRESH-STEP\nSHOE SPRAY"
	if ResourceLoader.exists(SIGN_FONT):
		text.font = load(SIGN_FONT)
	text.font_size = 48
	text.pixel_size = 0.00007
	text.line_spacing = -8.0
	text.modulate = Color(0.10, 0.18, 0.36)
	text.outline_size = 0
	text.shaded = true
	text.double_sided = false
	text.position = Vector3(0.0, h * 0.40, r + 0.0012)
	can.add_child(text)


static func _build_clipboard(root: Node3D) -> void:
	var board := Node3D.new()
	board.name = "SignOutClipboard"
	board.position = CLIPBOARD_AT
	root.add_child(board)
	var w := CLIPBOARD_SIZE.x
	var h := CLIPBOARD_SIZE.y
	var t := 0.012
	# the slab: dark blue-grey, faces -x (toward the counter)
	_box(board, "Slab", Vector3.ZERO, Vector3(t, h, w), _colour(Color(0.20, 0.23, 0.30), 0.45))
	var face := -t * 0.5 - 0.0008
	# the control strip along the top: four little coloured buttons, like the yeomen's boards
	var cols := [Color(0.85, 0.15, 0.12), Color(0.95, 0.68, 0.12), Color(0.25, 0.70, 0.30), Color(0.25, 0.45, 0.90)]
	for i in cols.size():
		var b := _colour(cols[i], 0.3)
		b.emission_enabled = true
		b.emission = cols[i]
		b.emission_energy_multiplier = 0.6
		_box(board, "Button%d" % i, Vector3(face, h * 0.5 - 0.022, -w * 0.3 + i * w * 0.2), Vector3(0.004, 0.012, 0.018), b)
	# the sheet: pale, with the log written on it
	var sheet_h := h * 0.74
	var sheet_y := -h * 0.5 + 0.012 + sheet_h * 0.5
	_box(board, "Sheet", Vector3(face + 0.0004, sheet_y, 0.0), Vector3(0.0015, sheet_h, w - 0.022), _colour(Color(0.90, 0.90, 0.84), 0.85))
	var sheet_text := Label3D.new()
	sheet_text.name = "SheetText"
	sheet_text.text = "SHOE SIGN-OUT\n\nLANE  NAME      SIZE\n 3    SPOCK      11\n 3    KIRK       10\n 3    McCOY      10\n 1    SULU        9\n 2    PELL        8"
	if ResourceLoader.exists(SIZE_FONT):
		sheet_text.font = load(SIZE_FONT)
	sheet_text.font_size = 40
	sheet_text.pixel_size = 0.00016
	sheet_text.modulate = Color(0.12, 0.14, 0.22)
	sheet_text.outline_size = 0
	sheet_text.shaded = true
	sheet_text.double_sided = false
	sheet_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	sheet_text.rotation_degrees.y = -90.0          # a Label3D faces +z; this turns it to -x
	sheet_text.position = Vector3(face - 0.0012, sheet_y, 0.0)
	board.add_child(sheet_text)
	# the hook it hangs from
	_box(board, "Hook", Vector3(-t * 0.5 + 0.002, h * 0.5 + 0.012, 0.0), Vector3(0.01, 0.03, 0.012), _mat("chrome"))


static func _build_lost_and_found(root: Node3D) -> void:
	var tote := Node3D.new()
	tote.name = "LostAndFound"
	tote.position = LOST_FOUND_AT
	tote.rotation_degrees.y = 3.0
	root.add_child(tote)
	var w := LOST_FOUND_SIZE.x
	var h := LOST_FOUND_SIZE.y
	var d := LOST_FOUND_SIZE.z
	var t := 0.01
	var shell := _colour(Color(0.62, 0.64, 0.66), 0.55)
	_box(tote, "Floor", Vector3(0.0, t * 0.5, 0.0), Vector3(w, t, d), shell)
	_box(tote, "Front", Vector3(0.0, h * 0.5, d * 0.5 - t * 0.5), Vector3(w, h, t), shell)
	_box(tote, "Back", Vector3(0.0, h * 0.5, -d * 0.5 + t * 0.5), Vector3(w, h, t), shell)
	_box(tote, "Left", Vector3(-w * 0.5 + t * 0.5, h * 0.5, 0.0), Vector3(t, h, d - t * 2.0), shell)
	_box(tote, "Right", Vector3(w * 0.5 - t * 0.5, h * 0.5, 0.0), Vector3(t, h, d - t * 2.0), shell)
	# a folded towel and an odd shoe in the bottom, the tribble on top of the towel
	var fill := 0.10
	_box(tote, "FoldedTowel", Vector3(-0.04, t + fill * 0.5, 0.0), Vector3(w - 0.09, fill, d - 0.05), _terry(Color(0.30, 0.48, 0.74)))
	var label := Label3D.new()
	label.name = "ToteLabel"
	label.text = "LOST + FOUND"
	if ResourceLoader.exists(SIGN_FONT):
		label.font = load(SIGN_FONT)
	label.font_size = 48
	label.pixel_size = 0.00042
	label.modulate = Color(0.12, 0.14, 0.22)
	label.outline_size = 0
	label.shaded = true
	label.double_sided = false
	label.position = Vector3(0.0, h * 0.55, d * 0.5 + 0.0012)
	tote.add_child(label)
	var trib := _tribble()
	if trib != null:
		trib.position = Vector3(-0.03, t + fill, 0.01)
		trib.rotation_degrees.y = 28.0
		tote.add_child(trib)


## REV 570: the tribble, with its fur picture and a soft rim so it reads as fluffy.
static func _tribble() -> Node3D:
	var scene := _scene(TRIBBLE_MODEL)
	if scene == null:
		return null
	var node := scene.instantiate() as Node3D
	var m := StandardMaterial3D.new()
	if ResourceLoader.exists(TRIBBLE_FUR):
		m.albedo_texture = load(TRIBBLE_FUR)
	m.roughness = 1.0
	m.specular_mode = BaseMaterial3D.SPECULAR_DISABLED
	m.rim_enabled = true
	m.rim = 0.8
	m.rim_tint = 0.7
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	for mi in node.find_children("*", "MeshInstance3D", true, false):
		(mi as MeshInstance3D).material_override = m
	return node


# ---- sign and body ------------------------------------------------------------------------------

static func _build_sign(root: Node3D) -> void:
	# REV 558: narrower, on the left of the tower top - the rolled towels sit on the right
	var cx := CUBBY_X.x + 0.47
	# REV 559 (Glen: the copper trim cut through the lettering from below): at the very front of the top,
	# raised on its stands, so the trim never hides it
	var y := TOWER_HEIGHT + 0.07
	var sz := DEPTH - 0.012
	_box(root, "SignPlate", Vector3(cx, y, sz), Vector3(0.82, 0.08, 0.012), _mat("plate"))
	_box(root, "SignStandA", Vector3(cx - 0.33, TOWER_HEIGHT + 0.015, sz - 0.01), Vector3(0.02, 0.03, 0.03), _mat("chrome"))
	_box(root, "SignStandB", Vector3(cx + 0.33, TOWER_HEIGHT + 0.015, sz - 0.01), Vector3(0.02, 0.03, 0.03), _mat("chrome"))
	var label := Label3D.new()
	label.name = "SignText"
	label.text = "RECREATION EQUIPMENT"
	if ResourceLoader.exists(SIGN_FONT):
		label.font = load(SIGN_FONT)
	label.font_size = 64
	label.pixel_size = 0.00055
	label.modulate = Color(0.95, 0.80, 0.42)
	label.outline_size = 0
	label.shaded = false
	label.position = Vector3(cx, y, sz + 0.0075)
	root.add_child(label)


static func _build_body(root: Node3D) -> void:
	var body := StaticBody3D.new()
	body.name = "EquipmentBody"
	root.add_child(body)
	for part in [[CUBBY_X, TOWER_HEIGHT], [COUNTER_X, COUNTER_HEIGHT + 0.06]]:
		var xr: Vector2 = part[0]
		var h: float = part[1]
		var shape := CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size = Vector3(xr.y - xr.x, h, DEPTH)
		shape.shape = box
		shape.position = Vector3((xr.x + xr.y) * 0.5, h * 0.5, DEPTH * 0.5)
		body.add_child(shape)
	# REV 570: the lost-and-found tote
	var tote_shape := CollisionShape3D.new()
	var tote_box := BoxShape3D.new()
	tote_box.size = LOST_FOUND_SIZE
	tote_shape.shape = tote_box
	tote_shape.position = LOST_FOUND_AT + Vector3(0.0, LOST_FOUND_SIZE.y * 0.5, 0.0)
	body.add_child(tote_shape)
	# REV 568 (Glen: the camera could get inside the sign and see the lettering float): the sign on top
	# is solid to the camera too
	var sign_shape := CollisionShape3D.new()
	var sign_box := BoxShape3D.new()
	sign_box.size = Vector3(0.9, 0.16, 0.08)
	sign_shape.shape = sign_box
	sign_shape.position = Vector3(CUBBY_X.x + 0.47, TOWER_HEIGHT + 0.08, DEPTH - 0.03)
	body.add_child(sign_shape)
