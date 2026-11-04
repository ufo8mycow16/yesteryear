extends EpisodeRoom
## REV 795 - THE NEW BRIDGE (debug location; main menu DEBUG: LOCATIONS "NEW BRIDGE (TEST)").
## Glen (2 Nov): "let's make it a debug location ... We won't replace the bridge we've got at the moment, but we'll
## work on this one." The story bridge (aedeck1.glb, EnterpriseBridge.gd, both teasers) is NOT touched.
##
## The model: Neel A.'s SketchUp "Star Trek TOS Enterprise Bridge" (3D Warehouse), converted by Glen to
## assets/models/maps/tos_bridge_new/tos_bridge_sketchup.glb - real metres, flat SketchUp colours, every coloured piece
## its own node (empty_N). Everything this room needs from it was measured ONCE by tools/new_bridge/measure_layout.py
## into layout.json (chairs, Kirk's chair, the screen rows, viewer, plaque, lift door, floors) - re-run it if the
## model changes. The look is matched to James Cawley's Ticonderoga set (Glen's photos: docs/reference/new_bridge_*).
##
## TEXTURES ARE GLEN'S (Glen, 2 Nov: "I'd like to be in charge of every texture myself"). Every surface is a plain
## colour until Glen drops a picture into assets/textures/tos_bridge_new/ named after its slot (TEXTURE_SLOTS below,
## e.g. carpet.png) - then it goes on that surface, wrapped round it (the SketchUp model has no usable UVs). No code.
##
## Debug keys: [ and ] = all the bridge lights darker / brighter (F3 shows the number - tell Claude to keep it).

const MODEL := "res://assets/models/maps/tos_bridge_new/tos_bridge_sketchup.glb"
const LAYOUT := "res://assets/models/maps/tos_bridge_new/layout.json"
const TEXTURE_DIR := "res://assets/textures/tos_bridge_new/"
const MODEL_ROOM := "res://episodes/episode1/ModelRoom.gd"
## REV 796 (Glen: "the characters need to be about 20% larger, or the bridge needs to be around 80% like it was" -
## "all of the characters have got their arms up around their necks to touch the consoles"): the whole set is drawn at
## 80%, like every other deck (ModelRoom.DECK7_SCALE). layout.json stays in the model's own metres; _p / _ring / sizes
## scale it. Chairs, Kirk's chair and the characters keep their own size.
const BRIDGE_SCALE := 1.0      # REV 801 (Glen: back to 100% - "the navigational console just looks a bit cramped for Chekov and Sulu"); 0.8 and 0.95 tried

## ---- Glen's texture slots: slot -> [plain colour (Cawley set), roughness, metres one picture covers, metallic] ----
const TEXTURE_SLOTS := {
	"carpet": [Color(0.50, 0.50, 0.51), 0.97, 1.0, 0.0],        # the grey carpet (ring, well, command platform)
	"wall": [Color(0.63, 0.64, 0.66), 0.55, 1.5, 0.0],          # the light grey walls and wall panels
	"wall_dark": [Color(0.53, 0.54, 0.56), 0.6, 1.5, 0.0],      # the darker grey parts (console bodies, kick plates)
	"wall_light": [Color(0.76, 0.76, 0.78), 0.5, 1.5, 0.0],     # the near-white trims
	"console": [Color(0.035, 0.035, 0.04), 0.3, 1.0, 0.0],      # the black console tops and fronts, the rail's base
	"trim_dark": [Color(0.10, 0.10, 0.11), 0.45, 1.0, 0.0],     # dark grey trims
	"rail": [Color(0.93, 0.20, 0.06), 0.35, 1.0, 0.0],          # the orange-red rail top, console edges, top stripe
	"dark_red": [Color(0.32, 0.03, 0.02), 0.45, 1.0, 0.0],      # small dark red parts
	"surround": [Color(0.42, 0.45, 0.63), 0.6, 1.2, 0.0],       # the blue-grey surrounds round the big screens
	"grille": [Color(0.30, 0.30, 0.32), 0.6, 0.5, 0.2],         # grilles
	"lift_door": [Color(0.95, 0.30, 0.16), 0.4, 1.2, 0.0],      # the turbolift door
}
## SketchUp colour name (contains) -> slot. First match wins; anything not listed that is a strong colour is a
## lit button or lamp (it glows in its own colour).
const NAME_SLOTS := [
	[["Chris_"], ""],
	[["console_top"], "console"],      # REV 796: the console desks + button plates (tools/new_bridge/clean_model.py names them)
	[["0131_Silver"], "wall"],
	[["0132_LightGray", "0133_Gray"], "wall_dark"],
	[["0130_Gainsboro", "0128_White", "0129_WhiteSmoke"], "wall_light"],
	[["0136_Charcoal", "0137_Black", "0135_DarkGray", "Color M09", "Color M08"], "console"],
	[["0134_DimGray"], "trim_dark"],
	[["0020_Red", "0024_OrangeRed"], "rail"],
	[["0022_Maroon", "0021_DarkRed"], "dark_red"],
	[["0099_LightSteelBlue", "tos blue", "0111_SlateGray", "0100_SteelBlue"], "surround"],
	[["Carpet"], "carpet"],
	[["mesh-of-lines"], "grille"],
	[["0035_Tan", "Wood Veneer", "hubble", "Image-of-the-Day"], "wall"],    # under our own pictures / hidden anyway
]
const BUTTON_GLOW := 1.3          # how hard the console buttons and lamps glow (their own colour)
const LENS_GLOW := 1.6            # the see-through coloured lenses

## ---- Glen's pictures on the screens -------------------------------------------------------------------------------
## REV 796 (Glen: "way too many status displays around the sides" - "there should be 4 screens each section"): each
## station's small-screen row shows SMALL_PER_ROW separate screens, every one a single screen out of Glen's HD bridge
## panel strips (REV 762; slot rectangles in tools/textures/bridge_panels.json), or his full-size HD remake where he has
## made one ("hd"). They are square, like Cawley's (the strips squeeze each screen to about half its width).
const SMALL_PER_ROW := 4
const SMALL_HEIGHT := 0.72       # share of the row's height
const SMALL_FILL := 0.9          # share of the row's width the four spread across
const PANELS_JSON := "res://tools/textures/bridge_panels.json"
const STRIP_DIR := "res://assets/hd_textures/textures/tos/bridge/"
const HD_DIR := "res://assets/textures/tos/bridge_screens/"      # copies of Glen's HD remakes (_originals is not imported)
## REV 796 (Glen: "I have bridge status monitors up the top in the viewscreens"): the six big upper screens are space
## pictures on Cawley's set (warp matrix scan, sub-comm trans vectors, subspace relay...) - Glen's to make. Each is a
## slot in TEXTURE_DIR, upper_screen_1 .. upper_screen_5 in the order of UPPER_SCREENS; dark glass until he has made
## it (debug builds name the slot on the glass). The one at 71 degrees is the CONDITION ALERT panel.
const UPPER_SCREENS := [
	[8.0, "upper_screen_1"],
	[71.0, "condition_alert"],
	[289.0, "upper_screen_2"],
	[317.0, "upper_screen_3"],
	[332.0, "upper_screen_4"],
	[353.0, "upper_screen_5"],
]
const CONDITION_ALERT := "res://assets/textures/tos/newend_condition_alert.png"
const DARK_GLASS := Color(0.015, 0.02, 0.03)
## Parts of the model hidden besides the chairs and SketchUp's stand-in person: its own little CONDITION ALERT screen
## by the lift (Glen: one alert panel only).
const HIDE_EXTRA := ["empty_14"]
const VIEWER_PICTURE := "res://assets/textures/tos/transporter_window_starfield.jpg"
const VIEWER_EDGE := Color(0.12, 0.32, 0.95)      # the thin blue edge round the main viewer (Cawley's set)
const PLAQUE_PICTURE := "res://assets/hd_textures/textures/tos/bridge/dedication_plaque.png"

## ---- props -------------------------------------------------------------------------------------------------------
## Kirk's chair (Glen's kit): the cushion's height above the top of its plinth (m) - the Burke chairs' seat is 0.43.
const KIRK_SEAT := 0.44
## REV 796 (Glen: "those chairs are way too small. The top of the backs should be up to around the characters' necks"):
## every Burke crew chair is sized by the TOP of its back - this high over its floor (m), just under a seated person's
## neck - and its seat follows (the sitters' hips are put on that seat).
const CHAIR_BACK_TOP := 1.12
var _chair_seat := {}         # layout chair index -> the new chair's seat height over its floor (m)

## ---- the crew: who sits at which chair (degrees round from the back of the ring, as layout.json) ---------------------
## The lift is aft-port (36 degrees); Spock's science station is the chair just starboard of it, Uhura's further round,
## Scotty's engineering station to port. Sulu at the helm (the left seat looking at the viewer), Chekov at navigation.
const SEATED := [
	["spock", 325.0, "Mr. Spock, at the science station."],      # REV 796 (Glen: they had stolen each other's stations)
	["uhura", 360.0, "Lieutenant Uhura, at communications."],
	["scotty", 71.0, "Mr. Scott, at the engineering station."],
	["sulu", 107.0, "Mr. Sulu, at the helm."],
	["chekov", 255.0, "Mr. Chekov, at navigation."],
]
## And two standing by the rail, chatting (ring angle, distance from the middle in metres, facing ring angle).
const STANDING := [
	["chapel", 300.0, 3.3, 286.0, "Nurse Chapel."],
	["kyle", 286.0, 3.4, 300.0, "Lieutenant Kyle."],
]
const SEAT_BACK := 0.04          # sitter sits this far back from the chair's stem (toward the chair back)

## ---- light (bright and even, like the set) ---------------------------------------------------------------------
const RING_LAMPS := 12
const RING_LAMP_RADIUS := 3.3
const RING_LAMP_HEIGHT := 2.45    # over the ring floor (its ceiling is ~2.66 m up)
const RING_LAMP_ENERGY := 0.85
const RING_LAMP_RANGE := 4.4
const WELL_LAMP_HEIGHT := 3.2
const WELL_LAMP_ENERGY := 1.4
const WELL_LAMP_RANGE := 6.5
const LAMP_COLOUR := Color(1.0, 0.97, 0.92)

var _layout: Dictionary = {}
var _centre := Vector3.ZERO           # the glb point that is this room's origin (ring middle, on the ring floor)
var _model: Node3D = null
var _parts := {}                      # node name -> MeshInstance3D
var _props: Node3D = null
var _mat_cache := {}
var _lamps: Array[OmniLight3D] = []
var _lamp_base: Array[float] = []
static var light_mult := 1.0          # [ ] in debug builds


# =========================================================================
# Room description
# =========================================================================

func describe_room() -> void:
	room_key = "new_bridge"
	_layout = _read_layout()
	var c: Array = _layout.get("centre", [0.0, 0.0, 0.0])
	_centre = Vector3(c[0], c[1], c[2])
	room_size = Vector3(11.0, 2.6, 11.0) * BRIDGE_SCALE
	ambient_color = Color(0.86, 0.88, 0.92)
	ambient_energy = 0.55
	allow_switching = true
	# Kirk and McCoy come in by the turbolift, facing the main viewer
	kirk_start = _ring(33.0, 4.2)
	mccoy_start = _ring(47.0, 3.8)


func _read_layout() -> Dictionary:
	if not FileAccess.file_exists(LAYOUT):
		push_warning("NewBridge: no layout.json - run tools/new_bridge/measure_layout.py")
		return {}
	var d: Variant = JSON.parse_string(FileAccess.get_file_as_string(LAYOUT))
	return d if d is Dictionary else {}


## A point on the ring floor: degrees round from the back (0 = straight aft, 180 = the main viewer), metres out.
func _ring(deg: float, r: float, y := 0.05) -> Vector3:
	var a := deg_to_rad(deg)
	return Vector3(sin(a) * r, y, -cos(a) * r) * BRIDGE_SCALE


## A size from layout.json (a half-width or half-height vector), in this room's metres.
func _sz(v: Array) -> float:
	return _v(v).length() * BRIDGE_SCALE


## A layout.json point (glb coordinates) in this room.
func _p(v: Array) -> Vector3:
	return (Vector3(float(v[0]), float(v[1]), float(v[2])) - _centre) * BRIDGE_SCALE


func _v(v: Array) -> Vector3:
	return Vector3(float(v[0]), float(v[1]), float(v[2]))


func location_name() -> String:
	return "Bridge (new model)"


func room_display_name() -> String:
	return "Deck 1 - Bridge (new model)"


func _show_banner() -> void:
	_banner.text = "BRIDGE - NEW MODEL (TEST)"
	var tween := create_tween()
	tween.tween_interval(0.5)
	tween.tween_property(_banner, "modulate:a", 1.0, UITheme.dur(0.5))
	tween.tween_interval(2.2)
	tween.tween_property(_banner, "modulate:a", 0.0, UITheme.dur(0.8))


# =========================================================================
# The set
# =========================================================================

func build_shell() -> void:
	if _layout.is_empty() or not ResourceLoader.exists(MODEL):
		super()          # no model: the plain box room, so the debug entry still opens
		return
	var scene := load(MODEL) as PackedScene
	_model = scene.instantiate() as Node3D
	_model.name = "BridgeModel"
	add_child(_model)
	_model.scale = Vector3.ONE * BRIDGE_SCALE
	_model.position = -_centre * BRIDGE_SCALE
	_props = Node3D.new()
	_props.name = "BridgeProps"
	add_child(_props)
	for m in _model.find_children("*", "MeshInstance3D", true, false):
		_parts[String(m.name)] = m
	_hide_parts()
	_dress_surfaces()
	_build_carpet()
	_build_collision()
	# a catch under everything, in case a gap in the model's floor ever lets someone through
	var well := (float(_layout["floors"]["well"]) - _centre.y) * BRIDGE_SCALE
	invisible_wall(Vector3(0.0, well - 0.18, 0.0), Vector3(14.0, 0.3, 14.0))


func build_room() -> void:
	if _model == null:
		return
	_add_screens()
	_add_viewer()
	_add_plaque()
	_add_chairs()
	_add_kirk_chair()
	_add_crew()
	_add_lights()


func _hide_parts() -> void:
	var names: Array = []
	names.append_array(_layout.get("hide", []))
	names.append_array(HIDE_EXTRA)
	for c in _layout.get("chairs", []):
		names.append_array(c["hide"])
	names.append_array(_layout.get("captain", {}).get("hide", []))
	for n in names:
		var mi := _parts.get(String(n)) as MeshInstance3D
		if mi != null:
			mi.visible = false


## Every surface gets its Cawley-set finish (or Glen's picture, when he has dropped one in its slot).
func _dress_surfaces() -> void:
	for mi: MeshInstance3D in _parts.values():
		if mi.mesh == null:
			continue
		for s in mi.mesh.get_surface_count():
			var src := mi.mesh.surface_get_material(s)
			if src != null:
				mi.set_surface_override_material(s, _bridge_material(src))
	var door := _parts.get(String(_layout.get("lift_door", {}).get("node", ""))) as MeshInstance3D
	if door != null and door.mesh != null:
		var m := _slot_material("lift_door")
		m.emission_enabled = true          # the set lights its door from inside the alcove
		m.emission = (TEXTURE_SLOTS["lift_door"][0] as Color)
		m.emission_energy_multiplier = 0.12
		for s in door.mesh.get_surface_count():
			door.set_surface_override_material(s, m)


func _bridge_material(src: Material) -> Material:
	if _mat_cache.has(src):
		return _mat_cache[src]
	var out: Material = src
	var std := src as StandardMaterial3D
	var one_sided := false
	if std != null:
		var nm := String(std.resource_name)
		# REV 796: tools/new_bridge/clean_model.py puts back-to-back surfaces (a wall's two skins in one plane) in a
		# copy of their material named "... [1side]" - drawn from the front only, so the two sides never fight
		if nm.ends_with(" [1side]"):
			one_sided = true
			nm = nm.trim_suffix(" [1side]")
		var c := std.albedo_color
		var slot := _slot_of(nm)
		if c.a < 0.99 or nm.begins_with("*"):
			out = _glow_material(c, LENS_GLOW, true)        # a coloured lens
		elif slot != "":
			out = _slot_material(slot)
		elif c.s > 0.4 and c.v > 0.15:
			out = _glow_material(c, BUTTON_GLOW, false)      # a lit button or lamp
		else:
			out = _slot_material("wall_dark")
	if one_sided and out is BaseMaterial3D:
		var key := "1side|" + str(out.get_instance_id())
		if not _mat_cache.has(key):
			var m1 := (out as BaseMaterial3D).duplicate() as BaseMaterial3D
			m1.cull_mode = BaseMaterial3D.CULL_BACK
			_mat_cache[key] = m1
		out = _mat_cache[key]
	_mat_cache[src] = out
	return out


func _slot_of(nm: String) -> String:
	if nm == "":
		return "wall"
	for row in NAME_SLOTS:
		for key in row[0]:
			if nm.contains(String(key)):
				return String(row[1])
	return ""


var _slot_cache := {}

## A slot's material: Glen's picture if he has put one in TEXTURE_DIR (<slot>.png / .jpg), else the plain colour.
func _slot_material(slot: String) -> StandardMaterial3D:
	if _slot_cache.has(slot):
		return (_slot_cache[slot] as StandardMaterial3D).duplicate() if slot == "lift_door" else _slot_cache[slot]
	var spec: Array = TEXTURE_SLOTS.get(slot, TEXTURE_SLOTS["wall"])
	var m := StandardMaterial3D.new()
	m.resource_name = "bridge_" + slot
	m.albedo_color = spec[0]
	m.roughness = float(spec[1])
	m.metallic = float(spec[3])
	m.cull_mode = BaseMaterial3D.CULL_DISABLED      # SketchUp faces often point the wrong way
	for ext in ["png", "jpg", "webp"]:
		var path: String = TEXTURE_DIR + slot + "." + String(ext)
		if ResourceLoader.exists(path):
			m.albedo_texture = load(path)
			m.albedo_color = Color.WHITE
			m.uv1_triplanar = true
			m.uv1_world_triplanar = true
			var k := 1.0 / maxf(float(spec[2]), 0.01)
			m.uv1_scale = Vector3(k, k, k)
			break
	_slot_cache[slot] = m
	return m.duplicate() if slot == "lift_door" else m


func _glow_material(c: Color, energy: float, see_through: bool) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(c.r, c.g, c.b, 0.85 if see_through else 1.0)
	if see_through:
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.roughness = 0.25
	m.emission_enabled = true
	m.emission = Color(c.r, c.g, c.b)
	m.emission_energy_multiplier = energy
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	return m


## The carpet: its own surface laid a few millimetres over every floor (ring, step, well) - the model's floors are
## the same grey part as its walls, so they can't simply be recoloured.
func _build_carpet() -> void:
	var levels: Array[float] = [float(_layout["floors"]["ring"]), float(_layout["floors"]["well"])]
	for y in _layout["floors"].get("step", []):
		levels.append(float(y))
	for i in levels.size():
		levels[i] -= _centre.y
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var n := 0
	for nm in _layout.get("floor_nodes", []):
		var mi := _parts.get(String(nm)) as MeshInstance3D
		if mi == null or mi.mesh == null:
			continue
		var xf := global_transform.affine_inverse() * mi.global_transform
		for s in mi.mesh.get_surface_count():
			var arr := mi.mesh.surface_get_arrays(s)
			var verts: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
			var idx: PackedInt32Array = arr[Mesh.ARRAY_INDEX] if arr[Mesh.ARRAY_INDEX] != null else PackedInt32Array()
			var count := idx.size() if idx.size() > 0 else verts.size()
			for t in range(0, count - 2, 3):
				var a := xf * verts[idx[t] if idx.size() > 0 else t]
				var b := xf * verts[idx[t + 1] if idx.size() > 0 else t + 1]
				var c := xf * verts[idx[t + 2] if idx.size() > 0 else t + 2]
				var nrm := (b - a).cross(c - a)
				if nrm.length() < 1e-7 or absf(nrm.normalized().y) < 0.98:
					continue
				var on_floor := false
				for lv in levels:
					if absf((a.y + b.y + c.y) / 3.0 - lv) < 0.02:
						on_floor = true
				if not on_floor:
					continue
				for p in [a, b, c]:
					st.set_normal(Vector3.UP)
					st.set_uv(Vector2(p.x, p.z))
					st.add_vertex(p + Vector3.UP * 0.008)     # REV 796: 8 mm (4 fought the floor far off)
				n += 1
	if n == 0:
		return
	var mesh := st.commit()
	var carpet := MeshInstance3D.new()
	carpet.name = "Carpet"
	carpet.mesh = mesh
	var m := _slot_material("carpet").duplicate() as StandardMaterial3D
	if m.albedo_texture != null:
		m.uv1_triplanar = false        # flat on the floor: the picture is laid by plain floor metres
		var k := 1.0 / maxf(float(TEXTURE_SLOTS["carpet"][2]), 0.01)
		m.uv1_scale = Vector3(k, k, 1.0)
	carpet.material_override = m
	carpet.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_props.add_child(carpet)


## Collision: every visible part of any size gets its own solid shape. The floor parts can be stepped onto; everything
## else is a fitting ("PROP_" - PlayerController never steps up onto it: consoles, rail, chairs).
## REV 799 (Glen: "It started out fine at 60 frames per second. Then it went down to 1"): collision is ONE clean shell
## built once - every part's triangles in room space, each spot only once whichever way it faces (REV 797's clean-up
## keeps both skins of a wall for drawing; colliding against both, and against hundreds of separate bodies, made every
## movement check far dearer), nothing above head height. Two bodies: "Floor_bridge" (the floor parts - walkable) and
## "PROP_bridge" (everything else - PlayerController never steps up onto a PROP_). Small bits and see-through parts
## are left out as before.
const COLLIDE_TOP := 2.3          # metres over the ring floor (model metres): nothing above this collides
const COLLIDE_GRID := 0.002       # metres: corners closer than this are the same corner

func _build_collision() -> void:
	var floor_names := {}
	for nm in _layout.get("floor_nodes", []):
		floor_names[String(nm)] = true
	var seen := {}
	var faces := {"Floor_bridge": PackedVector3Array(), "PROP_bridge": PackedVector3Array()}
	var top := COLLIDE_TOP * BRIDGE_SCALE
	var inv := global_transform.affine_inverse()
	for mi: MeshInstance3D in _parts.values():
		if mi.mesh == null or not mi.visible:
			continue
		var sz := mi.get_aabb().size
		if maxf(sz.x, maxf(sz.y, sz.z)) < 0.15:
			continue            # buttons and small bits
		if _all_see_through(mi):
			continue
		var bucket := "Floor_bridge" if floor_names.has(String(mi.name)) else "PROP_bridge"
		var out: PackedVector3Array = faces[bucket]
		var xf := inv * mi.global_transform
		var tri := mi.mesh.get_faces()
		for i in range(0, tri.size(), 3):
			var a := xf * tri[i]
			var b := xf * tri[i + 1]
			var c := xf * tri[i + 2]
			if minf(a.y, minf(b.y, c.y)) > top:
				continue
			var qa := Vector3i((a / COLLIDE_GRID).round())
			var qb := Vector3i((b / COLLIDE_GRID).round())
			var qc := Vector3i((c / COLLIDE_GRID).round())
			var k := [qa, qb, qc]
			k.sort()
			var h := hash(k)
			if seen.has(h):
				continue
			seen[h] = true
			out.append(a)
			out.append(b)
			out.append(c)
		faces[bucket] = out
	for bucket in faces:
		var f: PackedVector3Array = faces[bucket]
		if f.is_empty():
			continue
		var shape := ConcavePolygonShape3D.new()
		shape.set_faces(f)
		shape.backface_collision = true
		var body := StaticBody3D.new()
		body.name = bucket
		var cs := CollisionShape3D.new()
		cs.shape = shape
		body.add_child(cs)
		add_child(body)


func _all_see_through(mi: MeshInstance3D) -> bool:
	for s in mi.mesh.get_surface_count():
		var m := mi.mesh.surface_get_material(s) as StandardMaterial3D
		if m == null or (m.albedo_color.a >= 0.99 and not String(m.resource_name).begins_with("*")):
			return false
	return true


# =========================================================================
# Glen's pictures
# =========================================================================

## A flat picture on one of the model's measured rectangles (centre / right / up / normal from layout.json).
func _picture(node_name: String, r: Dictionary, w: float, h: float, mat: Material, lift := 0.004) -> MeshInstance3D:
	var q := QuadMesh.new()
	q.size = Vector2(w, h)
	var mi := MeshInstance3D.new()
	mi.name = node_name
	mi.mesh = q
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var bx := _v(r["right"]).normalized()
	var by := _v(r["up"]).normalized()
	var bz := _v(r["normal"]).normalized()
	_props.add_child(mi)
	mi.transform = Transform3D(Basis(bx, by, bz), _p(r["centre"]) + bz * lift)
	return mi


func _screen_material(path: String) -> Material:
	if not ResourceLoader.exists(path):
		return null
	var tex := load(path) as Texture2D
	var mr: Variant = load(MODEL_ROOM)
	var live: Variant = mr.screen_life_material(path.get_file(), tex) if mr != null else null
	if live is Material:
		return live
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_texture = tex
	return m


func _add_screens() -> void:
	_add_small_screens()
	_add_upper_screens()


## Every single screen available, in order: [texture, uv offset, uv size] - Glen's HD remake (whole picture) where he
## made one, else the screen's rectangle in its HD strip (mirrored strips are shown back to front on the old bridge's
## consoles, so their screens are flipped back here).
func _small_screen_list() -> Array:
	var out: Array = []
	if not FileAccess.file_exists(PANELS_JSON):
		return out
	var cfg: Variant = JSON.parse_string(FileAccess.get_file_as_string(PANELS_JSON))
	if not (cfg is Dictionary):
		return out
	var hd: Dictionary = cfg.get("hd", {})
	var mirrored: Array = cfg.get("mirrored", [])
	for strip in cfg["strips"]:
		var path := STRIP_DIR + String(strip) + ".png"
		var tex: Texture2D = load(path) if ResourceLoader.exists(path) else null
		var slots: Array = cfg["strips"][strip]["slots"]
		for k in slots.size():
			var key := "%s-%d" % [strip, k + 1]
			if hd.has(key) and ResourceLoader.exists(HD_DIR + String(hd[key])):
				out.append([load(HD_DIR + String(hd[key])), Vector2.ZERO, Vector2.ONE])
				continue
			if tex == null:
				continue
			var r: Array = slots[k]
			var off := Vector2(float(r[0]) / 512.0, float(r[1]) / 128.0)
			var size := Vector2(float(r[2] - r[0]) / 512.0, float(r[3] - r[1]) / 128.0)
			if strip in mirrored:
				off.x += size.x
				size.x = -size.x
			out.append([tex, off, size])
	return out


func _add_small_screens() -> void:
	var screens := _small_screen_list()
	if screens.is_empty():
		return
	var n := 0
	var row_i := 0
	for r in _layout.get("screens_small", []):
		row_i += 1
		var bw := _sz(r["right"]) * 2.0
		var bh := _sz(r["up"]) * 2.0
		var side := bh * SMALL_HEIGHT
		var step := bw * SMALL_FILL / float(SMALL_PER_ROW)
		side = minf(side, step * 0.88)
		var right := _v(r["right"]).normalized()
		for k in SMALL_PER_ROW:
			var sc: Array = screens[n % screens.size()]
			n += 1
			var m := StandardMaterial3D.new()
			m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			m.albedo_texture = sc[0]
			m.uv1_offset = Vector3((sc[1] as Vector2).x, (sc[1] as Vector2).y, 0.0)
			m.uv1_scale = Vector3((sc[2] as Vector2).x, (sc[2] as Vector2).y, 1.0)
			var along := (float(k) + 0.5 - float(SMALL_PER_ROW) * 0.5) * step
			var spot: Dictionary = (r as Dictionary).duplicate()
			var c := _v(r["centre"]) + right * (along / BRIDGE_SCALE)     # (layout.json metres)
			spot["centre"] = [c.x, c.y, c.z]
			_picture("SmallScreen_%d_%d" % [row_i, k + 1], spot, side, side, m)


func _add_upper_screens() -> void:
	for r in _layout.get("screens_big", []):
		var ang := float(r["angle"])
		var slot := ""
		var best_d := INF
		for row in UPPER_SCREENS:
			var d := absf(wrapf(ang - float(row[0]), -180.0, 180.0))
			if d < best_d:
				best_d = d
				slot = String(row[1])
		var path := CONDITION_ALERT if slot == "condition_alert" else ""
		if path == "":
			for ext in ["png", "jpg", "webp"]:
				if ResourceLoader.exists(TEXTURE_DIR + slot + "." + String(ext)):
					path = TEXTURE_DIR + slot + "." + String(ext)
					break
		var bw := _sz(r["right"]) * 2.0
		var bh := _sz(r["up"]) * 2.0
		var aspect := 4.0 / 3.0
		var mat: Material = null
		if path != "":
			mat = _screen_material(path)
			var tex := load(path) as Texture2D
			aspect = float(tex.get_width()) / maxf(float(tex.get_height()), 1.0)
		else:
			var glass := StandardMaterial3D.new()
			glass.albedo_color = DARK_GLASS
			glass.roughness = 0.08
			glass.metallic_specular = 0.8
			mat = glass
		var h := bh * 0.92
		var w := h * aspect
		if w > bw * 0.92:
			w = bw * 0.92
			h = w / aspect
		var pic := _picture("UpperScreen_" + slot, r, w, h, mat)
		if path == "" and OS.is_debug_build():
			var lab := Label3D.new()
			lab.text = slot
			lab.pixel_size = 0.0015
			lab.modulate = Color(0.45, 0.6, 0.7, 0.8)
			lab.position = Vector3(0.0, 0.0, 0.003)
			pic.add_child(lab)


func _add_viewer() -> void:
	var r: Dictionary = _layout.get("viewer", {})
	if r.is_empty():
		return
	var bw := _sz(r["right"]) * 2.0
	var bh := _sz(r["up"]) * 2.0
	var edge := StandardMaterial3D.new()
	edge.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	edge.albedo_color = VIEWER_EDGE
	_picture("ViewerEdge", r, bw, bh, edge, 0.003)
	if ResourceLoader.exists(VIEWER_PICTURE):
		var m := StandardMaterial3D.new()
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		m.albedo_texture = load(VIEWER_PICTURE)
		m.albedo_color = Color(0.9, 0.9, 0.9)
		_picture("ViewerSpace", r, bw - 0.05, bh - 0.05, m, 0.005)


func _add_plaque() -> void:
	var r: Dictionary = _layout.get("plaque", {})
	if r.is_empty() or not ResourceLoader.exists(PLAQUE_PICTURE):
		return
	var tex := load(PLAQUE_PICTURE) as Texture2D
	var aspect := float(tex.get_width()) / maxf(float(tex.get_height()), 1.0)
	var bw := _sz(r["right"]) * 2.0
	var bh := _sz(r["up"]) * 2.0
	var h := bh * 0.98
	var w := h * aspect
	if w > bw * 0.98:
		w = bw * 0.98
		h = w / aspect
	var m := StandardMaterial3D.new()
	m.albedo_texture = tex
	m.roughness = 0.35
	m.metallic = 0.25
	_picture("DedicationPlaque", r, w, h, m)


# =========================================================================
# Props: Glen's Burke chairs and Kirk's chair
# =========================================================================

func _add_chairs() -> void:
	if not ResourceLoader.exists(ChairSwap.MODEL):
		return
	if ChairSwap._model == null:
		ChairSwap._model = load(ChairSwap.MODEL)
		if ChairSwap._model == null:
			return
		ChairSwap._model_meas = ChairSwap._measure_model()
	var meas: Dictionary = ChairSwap._model_meas
	if meas.is_empty():
		return
	var mf: Vector2 = meas["facing"]
	var model_pt := Vector3((meas["axis"] as Vector2).x, float(meas["floor"]), (meas["axis"] as Vector2).y)
	var tall := _burke_height(float(meas["floor"]))
	var i := 0
	for c in _layout.get("chairs", []):
		i += 1
		var tf := Vector2(float(c["facing"][0]), float(c["facing"][1]))
		var k := CHAIR_BACK_TOP / tall if tall > 0.01 else float(c["seat"]) / maxf(float(meas["seat"]), 0.0001)
		_chair_seat[i - 1] = float(meas["seat"]) * k
		var b := Basis(Vector3.UP, atan2(tf.x, tf.y) - atan2(mf.x, mf.y)).scaled(Vector3.ONE * k)
		var at := _p(c["axis"])
		var holder := ChairSwap._new_chair()
		holder.name = "BurkeChair_%d" % i
		_props.add_child(holder)
		holder.transform = Transform3D(b, at - b * model_pt)
		_solid_post("PROP_chair_%d" % i, at, 0.24, float(_chair_seat[i - 1]))


## The Burke chair model's height, floor to the top of its back (its own units), measured once.
static var _burke_tall := -1.0

func _burke_height(floor_y: float) -> float:
	if _burke_tall > 0.0:
		return _burke_tall
	var inst := ChairSwap._model.instantiate() as Node3D
	var top := -INF
	for m in inst.find_children("*", "MeshInstance3D", true, false):
		var mi := m as MeshInstance3D
		if mi.mesh == null:
			continue
		var t := Transform3D.IDENTITY
		var w: Node = mi
		while w != null and w != inst:
			if w is Node3D:
				t = (w as Node3D).transform * t
			w = w.get_parent()
		top = maxf(top, (t * mi.get_aabb()).end.y)
	inst.free()
	_burke_tall = top - floor_y if top > -INF else -1.0
	return _burke_tall


func _add_kirk_chair() -> void:
	var cap: Dictionary = _layout.get("captain", {})
	if cap.is_empty() or not ResourceLoader.exists(CaptainChairSwap.MODEL):
		return
	var f := Vector2(float(cap["facing"][0]), float(cap["facing"][1]))
	var k := KIRK_SEAT / (CaptainChairSwap.NEW_SEAT - CaptainChairSwap.PLINTH)
	var xf := Transform3D(Basis(Vector3.UP, atan2(f.x, f.y)).scaled(Vector3.ONE * k), _p(cap["axis"]))
	var holder := Node3D.new()
	holder.name = "KirkChairNew"
	var chair := (load(CaptainChairSwap.MODEL) as PackedScene).instantiate() as Node3D
	holder.add_child(chair)
	_props.add_child(holder)
	holder.transform = xf
	CaptainChairSwap._glow(chair)
	if ResourceLoader.exists(CaptainChairSwap.PLINTH_MODEL):
		var plinth := (load(CaptainChairSwap.PLINTH_MODEL) as PackedScene).instantiate() as Node3D
		var ph := Node3D.new()
		ph.name = "KirkChairPlinth"
		ph.add_child(plinth)
		_props.add_child(ph)
		ph.transform = xf
		CaptainChairSwap._glow(plinth)
	set_meta(CaptainChairSwap.RAISE_META, CaptainChairSwap.PLINTH * k)
	set_meta(CaptainChairSwap.DONE_META, true)
	_solid_post("PROP_kirk_chair", _p(cap["axis"]), 0.42, KIRK_SEAT + CaptainChairSwap.PLINTH * k)


## A plain solid round post (chairs) - nobody walks through or climbs onto it.
func _solid_post(node_name: String, foot: Vector3, radius: float, height: float) -> void:
	var body := StaticBody3D.new()
	body.name = node_name
	var cs := CollisionShape3D.new()
	var cyl := CylinderShape3D.new()
	cyl.radius = radius
	cyl.height = maxf(height, 0.2)
	cs.shape = cyl
	body.add_child(cs)
	_props.add_child(body)
	body.position = foot + Vector3.UP * cyl.height * 0.5


# =========================================================================
# The crew
# =========================================================================

## The seat height of a layout chair as built (the new chair's, REV 796), else the SketchUp chair's.
func _seat_of(c: Dictionary) -> float:
	var idx: int = (_layout.get("chairs", []) as Array).find(c)
	return float(_chair_seat.get(idx, c["seat"]))


func _chair_near(deg: float) -> Dictionary:
	var best: Dictionary = {}
	var best_d := INF
	for c in _layout.get("chairs", []):
		var d := absf(wrapf(float(c["angle"]) - deg, -180.0, 180.0))
		if d < best_d:
			best_d = d
			best = c
	return best if best_d < 12.0 else {}


func _add_crew() -> void:
	for row in SEATED:
		var who := String(row[0])
		var c := _chair_near(float(row[1]))
		if c.is_empty():
			continue
		var at := _p(c["axis"])
		var facing := Vector3(float(c["facing"][0]), 0.0, float(c["facing"][1])).normalized()
		var spot := add_npc("NB_" + who.to_upper(), "", who, at, at + facing, ["LOOK", "TALK"], Callable(self, "_on_crew").bind(String(row[2])))
		var model := spot.get_node_or_null("Model") as Node3D
		if model == null:
			continue
		model.global_position = at - facing * SEAT_BACK
		model.rotation.y = atan2(facing.x, facing.z)
		var an := CharacterKit.animator_of(model)
		if an != null and an.has_motion():
			an.sit_now()
			an.hold_loop("typing", 0.9)
			# REV 796: hips exactly on this chair's cushion, hands on top of the console in front
			if an.motion != null:
				var size := maxf(model.global_transform.basis.get_scale().y, 0.0001)
				an.motion.seat_hip_height = (_seat_of(c) + CharacterMotion.HIP_OVER_SEAT) / size
				an.motion.seat_drop_hands = false
				var desk := _desk_top(at, facing)
				if desk != INF:
					an.motion.hand_floor = (desk - model.global_position.y) / size
		if who == "uhura":
			EarpieceProp.attach(model)
	for row in STANDING:
		var who := String(row[0])
		var at := _ring(float(row[1]), float(row[2]), 0.0)
		var look := _ring(float(row[3]), float(row[2]), 0.0)
		add_npc("NB_" + who.to_upper(), "", who, at, look, ["LOOK", "TALK"], Callable(self, "_on_crew").bind(String(row[4])))


## The console top in front of a chair (world height), or INF: the highest part of the bridge over a point 0.55 m in
## front of the stem whose top is between 0.55 and 1.3 m above the chair's floor (the console, not the wall behind).
func _desk_top(seat: Vector3, facing: Vector3) -> float:
	var probe := global_transform * (seat + Vector3(facing.x, 0.0, facing.z).normalized() * 0.55 * BRIDGE_SCALE)
	var floor_y := (global_transform * seat).y
	var best := -INF
	for mi: MeshInstance3D in _parts.values():
		if mi.mesh == null or not mi.visible:
			continue
		var b: AABB = mi.global_transform * mi.get_aabb()
		if probe.x < b.position.x or probe.x > b.end.x or probe.z < b.position.z or probe.z > b.end.z:
			continue
		if b.size.x > 3.0 and b.size.z > 3.0:
			continue          # a whole-room part (walls, floor)
		if b.end.y >= floor_y + 0.55 * BRIDGE_SCALE and b.end.y <= floor_y + 1.3 * BRIDGE_SCALE:
			best = maxf(best, b.end.y)
	return best if best > -INF else INF


func _on_crew(verb: String, _source: String, line: String) -> void:
	if verb == "LOOK":
		await say(current, line)
	else:
		await say(current, "(Nothing to say here yet - this bridge is a test set.)")


# =========================================================================
# Light
# =========================================================================

func _add_lights() -> void:
	for i in RING_LAMPS:
		var deg := 360.0 * float(i) / float(RING_LAMPS) + 15.0
		var l := OmniLight3D.new()
		l.name = "RingLamp_%d" % i
		l.light_color = LAMP_COLOUR
		l.omni_range = RING_LAMP_RANGE
		l.shadow_enabled = false
		l.position = _ring(deg, RING_LAMP_RADIUS, RING_LAMP_HEIGHT)
		add_child(l)
		_lamps.append(l)
		_lamp_base.append(RING_LAMP_ENERGY)
	var w := OmniLight3D.new()
	w.name = "WellLamp"
	w.light_color = LAMP_COLOUR
	w.omni_range = WELL_LAMP_RANGE
	w.shadow_enabled = RenderingServer.get_current_rendering_method() == "forward_plus" and GameSettings.quality_preset >= 1
	w.position = Vector3(0.0, WELL_LAMP_HEIGHT * BRIDGE_SCALE, 0.0)
	add_child(w)
	_lamps.append(w)
	_lamp_base.append(WELL_LAMP_ENERGY)
	# reflections in the glossy console tops and the rail
	var probe := ReflectionProbe.new()
	probe.name = "BridgeReflections"
	probe.size = Vector3(11.5, 3.4, 11.5) * BRIDGE_SCALE
	probe.position = Vector3(0.0, 1.3, 0.0) * BRIDGE_SCALE
	probe.interior = true
	probe.update_mode = ReflectionProbe.UPDATE_ONCE
	add_child(probe)
	_apply_lights()


func _apply_lights() -> void:
	for i in _lamps.size():
		_lamps[i].light_energy = _lamp_base[i] * light_mult


# =========================================================================
# Player and debug
# =========================================================================

func _setup_characters(loaded: Dictionary) -> void:
	super(loaded)
	var viewer := Vector3(0.0, 0.0, 4.7)
	var r: Dictionary = _layout.get("viewer", {})
	if not r.is_empty():
		viewer = _p(r["centre"])
	viewer.y = 0.0
	for b in [kirk_body, mccoy_body]:
		if b == null:
			continue
		b.step_onto_props = false        # walk the floors and the step, never climb consoles, rail or chairs
		b.rotation.y = atan2(viewer.x - b.position.x, viewer.z - b.position.z)
	var d := viewer - kirk_start
	d.y = 0.0
	if d.length() > 0.01:
		d = d.normalized()
		camera_rig.set_orbit(atan2(-d.x, -d.z), 0.1)     # behind Kirk, looking at the viewer


func debug_keys() -> Array:
	return [["[  /  ]", "Bridge lights darker / brighter"]]


func debug_where() -> String:
	var p := active_body.global_position if active_body != null else Vector3.ZERO
	# REV 801 (Glen's frame rate sinking to 1-2): where each frame's time goes - scripts, physics (ms), what is drawn,
	# and how many physics things are awake / touching
	return "NEW BRIDGE  x %.2f  y %.2f  z %.2f   LIGHT x%.2f\nSCRIPTS %.1f ms  PHYSICS %.1f ms  DRAWS %d  TRIS %dk  PHYS AWAKE %d  PAIRS %d" % [
		p.x, p.y, p.z, light_mult,
		Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0,
		Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0,
		int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)),
		int(Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME) / 1000.0),
		int(Performance.get_monitor(Performance.PHYSICS_3D_ACTIVE_OBJECTS)),
		int(Performance.get_monitor(Performance.PHYSICS_3D_COLLISION_PAIRS))]


func _unhandled_input(event: InputEvent) -> void:
	if OS.is_debug_build() and event is InputEventKey and event.pressed and not event.echo:
		var k := (event as InputEventKey).keycode
		if k == KEY_BRACKETLEFT or k == KEY_BRACKETRIGHT:
			light_mult = clampf(light_mult * (1.1 if k == KEY_BRACKETRIGHT else 1.0 / 1.1), 0.2, 4.0)
			_apply_lights()
			get_viewport().set_input_as_handled()
			return
	super(event)
