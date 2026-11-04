extends EpisodeRoom
## REV 802 - DECK 7 FROM FRANZ JOSEPH'S PLANS (debug location; main menu DEBUG: LOCATIONS "NEW DECK 7 (TEST)").
## Glen (3 Nov): "would we be able to do deck 7 and construct it entirely from the blueprints?" ... "create the whole
## thing". Claude builds the shell at true size; Glen does every detail and texture. The story's Deck 7 (aedeck7.glb,
## Episodes 2-3) is NOT touched - this one only replaces it when Glen says so.
##
## The model is made offline from the plan (docs/systems/new-deck7.md):
##   tools/new_deck7/extract_plan.py  PDF -> assets/models/maps/deck7_fj/plan.json (walls, hull, doors, lifts, furniture)
##   tools/new_deck7/build_deck7.py   plan.json -> deck7_fj.glb + layout.json
## Coordinates: metres, origin = the deck's centre (the emergency bridge), x = aft, z = port, floor at y 0.
##
## TEXTURES ARE GLEN'S: every surface is a plain colour until he drops a picture named after its slot into
## assets/textures/deck7_fj/ (floor, ceiling, wall, hull, lift - .png/.jpg/.webp) - wrapped round the shape.
##
## Debug keys: [ and ] = the lights darker / brighter.

const MODEL := "res://assets/models/maps/deck7_fj/deck7_fj.glb"
const LAYOUT := "res://assets/models/maps/deck7_fj/layout.json"
const TEXTURE_DIR := "res://assets/textures/deck7_fj/"

## slot -> [plain colour, roughness, metres one picture covers] (the plain colour shows only if a picture is missing)
const TEXTURE_SLOTS := {
	"floor": [Color(0.30, 0.30, 0.32), 0.95, 1.0],
	"ceiling": [Color(0.34, 0.35, 0.38), 0.9, 1.5],
	"wall": [Color(0.62, 0.63, 0.65), 0.6, 1.5],
	"hull": [Color(0.62, 0.63, 0.65), 0.6, 1.5],
	"lift": [Color(0.70, 0.22, 0.12), 0.5, 1.2],
	"wall_band": [Color(0.55, 0.13, 0.06), 0.8, 1.5],
	"beam": [Color(0.55, 0.13, 0.06), 0.6, 0.0],
	"pipe_grey": [Color(0.60, 0.60, 0.62), 0.45, 0.0],
	"pipe_copper": [Color(0.70, 0.45, 0.25), 0.4, 0.0],
}
## REV 808 (Glen: "texture the walls using the wall textures from our existing Deck 7 and put the correct red beams
## up the top of the ceiling with the wavy pattern"): every slot starts in the old Deck 7's own picture (aedeck7's
## corridor set, through HdTextures - the same HD files the old deck uses), repeating at the old deck's size scaled to
## our ceiling (K = 2.75 / 3.6). slot -> [map material name, metres across one picture, metres up one picture];
## 0 = the model's own 0..1 UVs (the beams and pipes: one picture across the corridor). A picture Glen puts in
## TEXTURE_DIR (<slot>.png/.jpg/.webp) still wins over these.
const DECK7_LOOK := {
	"floor": ["textures/tos/ent_floor", 0.733, 0.733],
	"ceiling": ["textures/scavenger/c_wall_nearblack", 0.733, 0.733],
	"wall": ["textures/tos/w1", 0.565, 1.128],
	"hull": ["textures/tos/w1", 0.565, 1.128],
	"wall_band": ["textures/tos/corrupper", 1.467, 1.467],
	"beam": ["textures/tos/crossbeam1", 0.0, 0.0],
	"pipe_grey": ["textures/tos/cross3a", 0.0, 0.0],
	"pipe_copper": ["textures/tos/cross2a", 0.0, 0.0],
}
## Nothing collides from these parts (the plain lift-shaft rings drawn on the floor).
const NO_COLLIDE := ["ShaftMarks", "Ceiling", "Beams", "BeamPipes", "BeamCopper"]

## Light: bright and even (Glen: not dark). The whole deck gets an even fill; a lamp rides over the player so the
## walls near you have some shape.
const AMBIENT := Color(0.88, 0.89, 0.92)
const AMBIENT_ENERGY := 0.75
const FOLLOW_LAMP_HEIGHT := 2.4
const FOLLOW_LAMP_ENERGY := 1.1
const FOLLOW_LAMP_RANGE := 9.0
const LAMP_COLOUR := Color(1.0, 0.97, 0.92)

static var light_mult := 1.0          # [ ] in debug builds

var _layout: Dictionary = {}
var _model: Node3D = null
var _lamp: OmniLight3D = null
var _slot_cache := {}

## REV 803 (Glen: "do up a map for me and a mini map ... I've really got no idea where I'm going"): one picture of the
## whole deck, drawn from the plan by tools/new_deck7/draw_map.py (rooms filled in, corridors lighter, turbolifts gold,
## main rooms named). The HUD minimap and the M full map both use it (group "minimap_source").
const MAP_PICTURE := "res://assets/models/maps/deck7_fj/deck7_map.png"
const MAP_INFO := "res://assets/models/maps/deck7_fj/deck7_map.json"
var _map_tex: Texture2D = null
var _map_origin := Vector2.ZERO
var _map_ppm := 12.0
var _map_labels: Array = []          # REV 804: [Vector2 world, text, size] - drawn as text by the minimap and M map

## REV 806 (Glen: "get those turbo lifts working ... Put a real car inside each of those areas ... If you need to resize
## it, shrink it, that's fine. Copy one of the other turbo lifts we have"): a REAL TOS car (Deck 7's, lifted out of
## aedeck7.glb by tools/new_deck7/make_car.sh) in each of Joseph's 15 stops, shrunk to his 2.5 m shafts, its doorway
## turned to the stop's open side (layout.json door_deg). Its six levers are Control Levers: they open the NEW SHIP's
## lift console (NewShipTurboliftUI - a copy of the old one) with every stop on this deck by name, plus the new bridge.
const CAR_MODEL := "res://assets/models/props/turbolift_car_tos/turbolift_car.glb"
const CAR_INFO := "res://assets/models/props/turbolift_car_tos/turbolift_car.json"
const CAR_SCALE := Vector3(0.70, 0.87, 0.70)     # across 3.7 m -> 2.6 m (Joseph's shafts are 2.5 m); 3.1 m tall -> 2.7 m
const CAR_LIFT := 0.006                           # its floor sits a hair over the deck's (no flicker)
## Each stop's name in the lift console: [x, z] of the stop (deck metres, the nearest stop is used), name. In the
## order they are listed (fore to aft, starboard before port).
const STOP_NAMES := [
	[[-34.3, -3.5], "Fore Corridor - Visicoms"],
	[[-34.1, 5.3], "Fore Corridor - Library Lounge"],
	[[-36.7, -35.9], "Crew Cabins - Starboard Fore"],
	[[-36.7, 35.9], "Crew Cabins - Port Fore"],
	[[-18.2, -48.0], "Starboard Lounge"],
	[[-18.2, 48.0], "Port Lounge"],
	[[-8.3, -25.7], "Transporter Rooms 2 and 4"],
	[[-8.3, 25.7], "Transporter Rooms 1 and 3"],
	[[4.5, 0.0], "Emergency Bridge"],
	[[17.3, 2.9], "Sickbay - Medical Lab"],
	[[22.2, -26.3], "Chapel"],
	[[22.2, 26.3], "Security Office and Brig"],
	[[48.6, -16.5], "Computer Core"],
	[[48.6, 16.5], "Engineering - Port"],
	[[46.5, 0.0], "Main Engineering"],
]
const NEW_BRIDGE_SCENE := "res://core/debug/NewBridge.tscn"
var _stops: Array = []               # {pos: Vector3 car floor middle, face: Vector3 out of its doorway, name}

## REV 812 (Glen: "Start making crew cabins now please" ... "fix up gaps in walls please"): the crew cabins - sealed with
## Joseph's doors only, sliding doors, nameplates, Kirk's furniture, the shared bathrooms. core/ship/NewDeckCabins.gd,
## docs/systems/cabins.md.
var _cabin_doors: Array = []
var _lift_doors: Array = []
## REV 817 (Glen: "Why haven't you put doors on the turbo lifts?"): a pair of red sliding doors just inside each car's
## doorway (the car model's metres: opening x -0.67..0.67, front wall at z 1.62, lintel 2.4 m up - measured off the
## model), worked like every other door on the deck (MapDoors: open as you walk up, shut behind you).
const CAR_DOOR_HALF := 0.67
const CAR_DOOR_Z := 1.56
var _new_lift_ui: NewShipTurboliftUI = null


func describe_room() -> void:
	room_key = "new_deck7"
	_layout = _read_layout()
	room_size = Vector3(124.0, float(_layout.get("height", 2.75)), 124.0)
	ambient_color = AMBIENT
	ambient_energy = AMBIENT_ENERGY
	allow_switching = true
	var sp: Array = _layout.get("spawn", [-42.0, 0.05, 0.0])
	kirk_start = Vector3(float(sp[0]), float(sp[1]), float(sp[2]))
	mccoy_start = kirk_start + Vector3(-1.2, 0.0, 0.5)


func _read_layout() -> Dictionary:
	if not FileAccess.file_exists(LAYOUT):
		push_warning("NewDeck7: no layout.json - run tools/new_deck7/build.sh")
		return {}
	var d: Variant = JSON.parse_string(FileAccess.get_file_as_string(LAYOUT))
	return d if d is Dictionary else {}


func location_name() -> String:
	return "Deck 7 (Franz Joseph plan)"


func room_display_name() -> String:
	return "Deck 7 - Main Deck (new, from the plans)"


func _show_banner() -> void:
	_banner.text = "DECK 7 - FROM THE FRANZ JOSEPH PLANS (TEST)"
	var tween := create_tween()
	tween.tween_interval(0.5)
	tween.tween_property(_banner, "modulate:a", 1.0, UITheme.dur(0.5))
	tween.tween_interval(2.2)
	tween.tween_property(_banner, "modulate:a", 0.0, UITheme.dur(0.8))


# =========================================================================
# The deck
# =========================================================================

func build_shell() -> void:
	if _layout.is_empty() or not ResourceLoader.exists(MODEL):
		super()          # no model: the plain box room, so the debug entry still opens
		return
	_model = (load(MODEL) as PackedScene).instantiate() as Node3D
	_model.name = "Deck7Model"
	add_child(_model)
	var parts: Array[MeshInstance3D] = []
	for m in _model.find_children("*", "MeshInstance3D", true, false):
		parts.append(m as MeshInstance3D)
	for mi in parts:
		if mi.mesh == null:
			continue
		for s in mi.mesh.get_surface_count():
			var src := mi.mesh.surface_get_material(s)
			var slot := String(src.resource_name) if src != null else "wall"
			mi.set_surface_override_material(s, _slot_material(slot))
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_build_collision(parts)
	# a catch under everything
	invisible_wall(Vector3(0.0, -0.2, 0.0), Vector3(140.0, 0.3, 140.0))


func build_room() -> void:
	_load_map()
	if _model == null:
		return
	_add_lifts()
	_cabin_doors = NewDeckCabins.build(self)
	_cabin_doors.append_array(_lift_doors)   # REV 817: the lift cars' own red doors
	_cabin_doors.append_array(NewDeckRooms.build(self))    # REV 813-816: the rooms, and (816) every room's red door
	_activate_cabin_doors.call_deferred()
	_lamp = OmniLight3D.new()
	_lamp.name = "FollowLamp"
	_lamp.light_color = LAMP_COLOUR
	_lamp.omni_range = FOLLOW_LAMP_RANGE
	_lamp.shadow_enabled = false
	add_child(_lamp)
	_apply_lights()


## A slot's material: Glen's picture if he has put one in TEXTURE_DIR (<slot>.png / .jpg / .webp), else the old
## Deck 7's picture (DECK7_LOOK, REV 808), else the plain colour.
func _slot_material(slot: String) -> StandardMaterial3D:
	if _slot_cache.has(slot):
		return _slot_cache[slot]
	var spec: Array = TEXTURE_SLOTS.get(slot, TEXTURE_SLOTS["wall"])
	var m := StandardMaterial3D.new()
	m.resource_name = "deck7_" + slot
	m.albedo_color = spec[0]
	m.roughness = float(spec[1])
	for ext in ["png", "jpg", "webp"]:
		var path: String = TEXTURE_DIR + slot + "." + String(ext)
		if ResourceLoader.exists(path):
			m.albedo_texture = load(path)
			m.albedo_color = Color.WHITE
			if float(spec[2]) > 0.0:          # beams and pipes keep their own 0..1 wrap
				m.uv1_triplanar = true
				m.uv1_world_triplanar = true
				var k := 1.0 / float(spec[2])
				m.uv1_scale = Vector3(k, k, k)
			break
	if m.albedo_texture == null and DECK7_LOOK.has(slot):
		var look: Array = DECK7_LOOK[slot]
		var tex := HdTextures._find(String(look[0]))
		if tex != null:
			m.albedo_texture = tex
			m.albedo_color = Color.WHITE
			if float(look[1]) > 0.0:
				m.uv1_scale = Vector3(1.0 / float(look[1]), 1.0 / float(look[2]), 1.0)
	_slot_cache[slot] = m
	return m


## ONE clean collision shell (the new bridge's lesson, REV 799): "Floor_deck7" (walkable) and "PROP_deck7" (walls,
## hull, lift cars - never stepped onto).
func _build_collision(parts: Array[MeshInstance3D]) -> void:
	var faces := {"Floor_deck7": PackedVector3Array(), "PROP_deck7": PackedVector3Array()}
	for mi in parts:
		if mi.mesh == null or NO_COLLIDE.has(String(mi.name)):
			continue
		var bucket := "Floor_deck7" if String(mi.name) == "Floor" else "PROP_deck7"
		var out: PackedVector3Array = faces[bucket]
		var xf := mi.transform
		for v in mi.mesh.get_faces():
			out.append(xf * v)
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


func _apply_lights() -> void:
	if _lamp != null:
		_lamp.light_energy = FOLLOW_LAMP_ENERGY * light_mult
	for we in find_children("*", "WorldEnvironment", true, false):
		var env := (we as WorldEnvironment).environment
		if env != null:
			env.ambient_light_energy = AMBIENT_ENERGY * light_mult


## The cabin doors need the deck's floor in the physics world (they only open where there is floor both sides).
func _activate_cabin_doors() -> void:
	await get_tree().physics_frame
	await get_tree().physics_frame
	if is_inside_tree():
		MapDoors.activate(self, _cabin_doors, [])


func _process(delta: float) -> void:
	super(delta)
	if not _cabin_doors.is_empty():
		MapDoors.tick(self, _cabin_doors, delta)
	if _lamp != null and active_body != null:
		_lamp.global_position = active_body.global_position + Vector3(0.0, FOLLOW_LAMP_HEIGHT, 0.0)


# =========================================================================
# Turbolifts (REV 806)
# =========================================================================

func _add_lifts() -> void:
	if not ResourceLoader.exists(CAR_MODEL):
		return
	var info: Dictionary = {}
	if FileAccess.file_exists(CAR_INFO):
		var d: Variant = JSON.parse_string(FileAccess.get_file_as_string(CAR_INFO))
		if d is Dictionary:
			info = d
	var car_scene := load(CAR_MODEL) as PackedScene
	var faces := PackedVector3Array()
	var car_doors: Array = []
	var holder := Node3D.new()
	holder.name = "LiftCars"
	add_child(holder)
	var i := 0
	for l in _layout.get("lifts", []):
		var c: Array = l["centre"]
		var a := deg_to_rad(float(l["door_deg"]))
		var out := Vector3(cos(a), 0.0, sin(a))          # out of the doorway, into the corridor
		var car := car_scene.instantiate() as Node3D
		car.name = "LiftCar_%d" % i
		holder.add_child(car)
		car.position = Vector3(float(c[0]), CAR_LIFT, float(c[2]))
		car.rotation.y = PI * 0.5 - a                     # the model's doorway faces +z
		car.scale = CAR_SCALE
		for m in car.find_children("*", "MeshInstance3D", true, false):
			var mi := m as MeshInstance3D
			mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			for s in mi.mesh.get_surface_count():
				var src := mi.mesh.surface_get_material(s) as StandardMaterial3D
				if src != null:
					var mat := src.duplicate() as StandardMaterial3D
					mat.vertex_color_use_as_albedo = false     # the map's own baked shading - wrong here
					mi.set_surface_override_material(s, mat)
			# solid walls: everything but the floor (the deck's floor is walked on)
			var xf := car.transform * mi.transform
			var tri := mi.mesh.get_faces()
			for k in range(0, tri.size(), 3):
				var p0 := xf * tri[k]
				var p1 := xf * tri[k + 1]
				var p2 := xf * tri[k + 2]
				if maxf(p0.y, maxf(p1.y, p2.y)) < 0.08:
					continue
				faces.append(p0)
				faces.append(p1)
				faces.append(p2)
		# the six Control Levers
		var j := 0
		for v in info.get("levers", []):
			var lp := car.transform * Vector3(float(v[0]), float(v[1]), float(v[2]))
			add_spot("NEWD7_LIFT_%d_LEVER_%d" % [i, j], "Control Lever", lp, Vector3(0.45, 0.6, 0.45), ["USE"],
				Callable(self, "_on_lift_lever").bind(i))
			j += 1
		_stops.append({"pos": Vector3(float(c[0]), 0.05, float(c[2])), "face": out, "name": _stop_name(float(c[0]), float(c[2]), i)})
		var da := car.transform * Vector3(-CAR_DOOR_HALF, 0.0, CAR_DOOR_Z)
		var db := car.transform * Vector3(CAR_DOOR_HALF, 0.0, CAR_DOOR_Z)
		car_doors.append({"a": [da.x, da.z], "b": [db.x, db.z], "kind": "lift", "slide": [1.0, 1.0]})
		i += 1
	_lift_doors = NewDeckCabins._doors(holder, {"doors": car_doors})
	if not faces.is_empty():
		var shape := ConcavePolygonShape3D.new()
		shape.set_faces(faces)
		shape.backface_collision = true
		var body := StaticBody3D.new()
		body.name = "PROP_lift_cars"
		var cs := CollisionShape3D.new()
		cs.shape = shape
		body.add_child(cs)
		add_child(body)


func _stop_name(x: float, z: float, i: int) -> String:
	for s in STOP_NAMES:
		var p: Array = s[0]
		if Vector2(float(p[0]), float(p[1])).distance_to(Vector2(x, z)) < 2.0:
			return String(s[1])
	return "Turbolift %d" % (i + 1)


## The stop nearest the player (where "YOU ARE HERE" goes).
func _stop_here() -> int:
	var best := -1
	var best_d := INF
	var p := active_body.global_position if active_body != null else Vector3.ZERO
	for i in _stops.size():
		var d := (_stops[i]["pos"] as Vector3).distance_to(Vector3(p.x, 0.05, p.z))
		if d < best_d:
			best_d = d
			best = i
	return best


func _on_lift_lever(_verb: String, _source: String, from_stop: int) -> void:
	if _new_lift_ui == null:
		_new_lift_ui = NewShipTurboliftUI.new()
		ui_canvas.add_child(_new_lift_ui)
	# listed in STOP_NAMES order
	var rooms: Array = []
	for s in STOP_NAMES:
		var p: Array = s[0]
		for i in _stops.size():
			var at: Vector3 = _stops[i]["pos"]
			if Vector2(at.x, at.z).distance_to(Vector2(float(p[0]), float(p[1]))) < 2.0:
				rooms.append(["fj7:%d" % i, String(_stops[i]["name"])])
	for i in _stops.size():          # any stop without a name still gets a button
		if not rooms.any(func(r: Array) -> bool: return String(r[0]) == "fj7:%d" % i):
			rooms.append(["fj7:%d" % i, String(_stops[i]["name"])])
	_new_lift_ui.set_places([
		{"deck": 1, "name": "Bridge (new model)", "rooms": [["fj_bridge", "Bridge (new model)"]]},
		{"deck": 7, "name": "Main Deck", "rooms": rooms},
	])
	var key: String = await _new_lift_ui.run(7, "fj7:%d" % from_stop)
	if key == "" or key == "fj7:%d" % from_stop:
		return
	SfxManager.play("door")
	SfxManager.play("turbolift", -2.0)
	active_body.input_enabled = false
	var tween := create_tween()
	tween.tween_property(_fade, "modulate:a", 1.0, 0.45)
	await tween.finished
	if key == "fj_bridge":
		get_tree().change_scene_to_file(NEW_BRIDGE_SCENE)
		return
	await pause(1.1)
	_arrive_at(int(key.substr(4)))
	_fade_in(0.7)
	active_body.input_enabled = true


## Puts the pair in stop i's car, facing out of its doorway.
func _arrive_at(i: int) -> void:
	var s: Dictionary = _stops[i]
	var face: Vector3 = s["face"]
	var side := Vector3(-face.z, 0.0, face.x)
	var spots := [(s["pos"] as Vector3) + side * 0.35, (s["pos"] as Vector3) - side * 0.35 - face * 0.25]
	var bodies := [active_body, kirk_body if active_body == mccoy_body else mccoy_body]
	for k in bodies.size():
		var b := bodies[k] as PlayerController
		if b == null:
			continue
		b.velocity = Vector3.ZERO
		b.global_position = spots[k]
		b.rotation.y = atan2(face.x, face.z)
		b.reset_physics_interpolation()
	camera_rig.set_orbit(atan2(-face.x, -face.z), 0.1)


# =========================================================================
# Map (minimap + M)
# =========================================================================

func _load_map() -> void:
	if not ResourceLoader.exists(MAP_PICTURE) or not FileAccess.file_exists(MAP_INFO):
		return
	var info: Variant = JSON.parse_string(FileAccess.get_file_as_string(MAP_INFO))
	if not (info is Dictionary):
		return
	_map_tex = load(MAP_PICTURE) as Texture2D
	var o: Array = (info as Dictionary).get("origin", [0.0, 0.0])
	_map_origin = Vector2(float(o[0]), float(o[1]))
	_map_ppm = float((info as Dictionary).get("px_per_metre", 12.0))
	_map_labels.clear()
	for l in (info as Dictionary).get("labels", []):
		_map_labels.append([Vector2(float(l[0]), float(l[1])), String(l[2]), int(l[3])])
	add_to_group("minimap_source")


func get_minimap_data() -> Dictionary:
	if _map_tex == null:
		return {}
	return {"texture": _map_tex, "origin": _map_origin, "px_per_metre": _map_ppm, "view_metres": 30.0,
		"labels": _map_labels, "map_id": "deck7_fj"}


func minimap_stale() -> bool:
	return false        # one picture covers the whole deck


func get_full_map_data() -> Dictionary:
	if _map_tex == null:
		return {}
	var size := Vector2(_map_tex.get_width(), _map_tex.get_height()) / _map_ppm
	return {"texture": _map_tex, "origin": _map_origin, "px_per_metre": _map_ppm,
		"bounds": Rect2(_map_origin, size), "room_name": "Main Deck (from the Franz Joseph plans)", "deck": 7,
		"labels": _map_labels, "map_id": "deck7_fj"}


# =========================================================================
# Player and debug
# =========================================================================

func _setup_characters(loaded: Dictionary) -> void:
	super(loaded)
	for b in [kirk_body, mccoy_body]:
		if b == null:
			continue
		b.step_onto_props = false
		b.rotation.y = PI * 0.5          # facing aft (+x), down the corridor toward the middle of the deck
	camera_rig.set_orbit(-PI * 0.5, 0.1)  # behind Kirk


func debug_keys() -> Array:
	return [["[  /  ]", "Deck lights darker / brighter"]]


func debug_where() -> String:
	var p := active_body.global_position if active_body != null else Vector3.ZERO
	return "NEW DECK 7  x %.2f  z %.2f  (aft +x, port +z)   LIGHT x%.2f\nSCRIPTS %.1f ms  PHYSICS %.1f ms  DRAWS %d  TRIS %dk" % [
		p.x, p.z, light_mult,
		Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0,
		Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0,
		int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)),
		int(Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME) / 1000.0)]


func _unhandled_input(event: InputEvent) -> void:
	if OS.is_debug_build() and event is InputEventKey and event.pressed and not event.echo:
		var k := (event as InputEventKey).keycode
		if k == KEY_BRACKETLEFT or k == KEY_BRACKETRIGHT:
			light_mult = clampf(light_mult * (1.1 if k == KEY_BRACKETRIGHT else 1.0 / 1.1), 0.2, 4.0)
			_apply_lights()
			get_viewport().set_input_as_handled()
			return
	super(event)
