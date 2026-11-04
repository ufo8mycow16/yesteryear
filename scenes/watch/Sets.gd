extends RefCounted
## The watch-through's locations and their named spots.
##
## build(parent, key) makes a set and stores its spots (game positions) on it. spot(set, key) answers:
##   a name the set defines          -> that position
##   "<name>_head"                   -> that spot at head height (child 1.15, sehlat 1.0, adult 1.62)
##   "<name>_cam" not defined        -> a camera 2.8 m out from that spot towards the set's centre, eye height
##   a Vector3                       -> relative to the set's anchor

const GuardianPlanet := preload("res://scenes/sets/GuardianPlanet.gd")
const EnterpriseDeck := preload("res://scenes/sets/EnterpriseDeck.gd")

const CHILD_SPOTS := ["boy", "boy_push", "boy_home", "by_sehlat", "boy_start", "boy_mid", "boy_end", "boy_runs",
	"boy_door", "boy_dawn", "boy_by_ichaya", "boy_back", "bully1", "bully2", "bully3", "bully1_back"]
const LOW_SPOTS := ["sehlat", "sehlat_start", "lematya", "lematya_down"]


static func build(parent: Node3D, key: String) -> Node3D:
	var s: Node3D
	var spots := {}
	match key:
		"guardian", "guardian_night":
			s = GuardianPlanet.new()
			s.name = "GuardianPlanet"
			parent.add_child(s)
			if key == "guardian_night":
				_night(s)
			spots = _guardian_spots()
		"transporter", "briefing":
			s = _deck(parent, "res://assets/models/maps/aedeck7.glb", "res://assets/models/maps/aedeck7_lightmap.png", 1.2, 0.21)
			spots = _transporter_spots() if key == "transporter" else _briefing_spots()
		"quarters":
			s = _deck(parent, "res://assets/models/maps/aedeck5_6.glb", "res://assets/models/maps/aedeck5_6_lightmap.png", 1.1, 0.16)
			spots = _quarters_spots()
		"street", "courtyard", "courtyard_morning", "healer":
			s = Node3D.new()
			s.name = "ShiKahrSet"
			parent.add_child(s)
			var city := VulcanCity.make(s)
			var anchor_key: String = {"street": "elder", "courtyard": "sehlat", "courtyard_morning": "sehlat", "healer": "apothecary_sign"}[key]
			var a := city.spot(anchor_key)
			if a == Vector3.INF:
				a = Vector3.ZERO
			s.set_meta("anchor", a)
			_vulcan_sky(s, {"street": "sunset", "courtyard": "evening", "courtyard_morning": "morning", "healer": "predawn"}[key])
			spots = _relative(a, _city_spots(key))
		"desert", "desert_dawn":
			s = Node3D.new()
			s.name = "DesertSet"
			parent.add_child(s)
			VulcanDesert.ground(s, 70.0, 70.0)
			VulcanTerrain.place(s, "desert_search")
			for m in [["spire", Vector3(18, 0, 22), 30.0, 16.0], ["rough", Vector3(-20, 0, 26), 200.0, 22.0],
					["table", Vector3(30, 0, -12), 110.0, 26.0], ["split", Vector3(-28, 0, -6), 60.0, 18.0]]:
				VulcanDesert.mesa(s, String(m[0]), m[1], float(m[2]), float(m[3]))
			_vulcan_sky(s, "night" if key == "desert" else "dawn")
			spots = _desert_spots()
		_:
			s = Node3D.new()
			parent.add_child(s)
	s.set_meta("spots", spots)
	return s


static func spot(set_node: Node3D, key: Variant) -> Vector3:
	if set_node == null:
		return Vector3.ZERO
	if key is Vector3:
		var a: Vector3 = set_node.get_meta("anchor", Vector3.ZERO)
		return a + (key as Vector3)
	var k := String(key)
	var spots: Dictionary = set_node.get_meta("spots", {})
	if spots.has(k):
		return spots[k]
	if k.ends_with("_head"):
		var base_key := k.trim_suffix("_head")
		var h := 1.15 if base_key in CHILD_SPOTS else (1.0 if base_key in LOW_SPOTS else 1.62)
		return spot(set_node, base_key) + Vector3(0.0, h, 0.0)
	if k.ends_with("_cam"):
		var base_key := k.trim_suffix("_cam")
		if spots.has(base_key):
			var p: Vector3 = spots[base_key]
			var centre: Vector3 = spots.get("centre", p + Vector3(0, 0, 3))
			var d := centre - p
			d.y = 0.0
			if d.length() < 0.1:
				d = Vector3(0, 0, 1)
			d = d.normalized()
			var side := d.cross(Vector3.UP) * 0.7
			return p + d * 2.8 + side + Vector3(0.0, 1.55, 0.0)
	push_warning("Sets: no spot " + k)
	return spots.get("centre", Vector3.ZERO)


# ------------------------------------------------------------------------------------------------ sets --

static func _deck(parent: Node3D, model: String, lightmap: String, boost: float, chroma: float) -> Node3D:
	var d := EnterpriseDeck.new()
	d.name = "EnterpriseSet"
	d.model_path = model
	d.lightmap_path = lightmap
	d.boost = boost
	d.chroma = chroma
	parent.add_child(d)
	return d


static func _night(planet: Node3D) -> void:
	var env: Environment = planet.get("environment")
	if env != null:
		env.ambient_light_energy = 0.35
		env.tonemap_exposure = 0.8
		env.fog_light_color = Color(0.28, 0.26, 0.42)
	var sun := planet.get_node_or_null("Sun") as DirectionalLight3D
	if sun != null:
		sun.light_color = Color(0.62, 0.68, 1.0)
		sun.light_energy = 0.45
		sun.rotation_degrees = Vector3(-38.0, 60.0, 0.0)


## Vulcan light: a red-orange sky by day, deep blue at night, gold at dawn. No sky picture yet (Glen may make one).
static func _vulcan_sky(s: Node3D, mood: String) -> void:
	var top: Color
	var horizon: Color
	var sun_col: Color
	var sun_e := 1.3
	var sun_rot := Vector3(-20.0, -40.0, 0.0)
	var amb := 0.8
	match mood:
		"sunset":
			top = Color(0.42, 0.22, 0.2); horizon = Color(0.95, 0.5, 0.28); sun_col = Color(1.0, 0.6, 0.35); sun_rot = Vector3(-10.0, -60.0, 0.0)
		"evening":
			top = Color(0.25, 0.15, 0.2); horizon = Color(0.7, 0.36, 0.25); sun_col = Color(1.0, 0.55, 0.32); sun_e = 0.8; sun_rot = Vector3(-6.0, -70.0, 0.0); amb = 0.6
		"morning":
			top = Color(0.55, 0.36, 0.3); horizon = Color(1.0, 0.72, 0.45); sun_col = Color(1.0, 0.8, 0.55); sun_rot = Vector3(-18.0, 120.0, 0.0)
		"predawn":
			top = Color(0.08, 0.08, 0.16); horizon = Color(0.35, 0.22, 0.3); sun_col = Color(0.6, 0.6, 0.9); sun_e = 0.35; amb = 0.45
		"night":
			top = Color(0.03, 0.04, 0.1); horizon = Color(0.16, 0.13, 0.22); sun_col = Color(0.6, 0.68, 1.0); sun_e = 0.4; sun_rot = Vector3(-40.0, 30.0, 0.0); amb = 0.4
		_:
			top = Color(0.6, 0.35, 0.25); horizon = Color(1.0, 0.65, 0.4); sun_col = Color(1.0, 0.75, 0.5); sun_rot = Vector3(-6.0, 110.0, 0.0); sun_e = 1.1
	var sky_mat := ProceduralSkyMaterial.new()
	sky_mat.sky_top_color = top
	sky_mat.sky_horizon_color = horizon
	sky_mat.ground_horizon_color = horizon
	sky_mat.ground_bottom_color = horizon * 0.4
	var sky := Sky.new()
	sky.sky_material = sky_mat
	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_energy = amb
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.fog_enabled = true
	env.fog_light_color = horizon
	env.fog_density = 0.004
	env.glow_enabled = true
	var we := WorldEnvironment.new()
	we.environment = env
	s.add_child(we)
	var sun := DirectionalLight3D.new()
	sun.light_color = sun_col
	sun.light_energy = sun_e
	sun.rotation_degrees = sun_rot
	sun.shadow_enabled = true
	s.add_child(sun)


static func _relative(anchor: Vector3, rel: Dictionary) -> Dictionary:
	var out := {}
	for k in rel.keys():
		out[k] = anchor + (rel[k] as Vector3)
	return out


# ----------------------------------------------------------------------------------------------- spots --
# Guardian's planet: the Guardian at the origin, doorway along Z, the flat paved cliff top at y = 0.

static func _guardian_spots() -> Dictionary:
	return {
		"centre": Vector3(0, 0, 3.5),
		"door": Vector3(0, 0.28, 0), "kirk_out": Vector3(-1.2, 0, 2.8), "spock_out": Vector3(1.0, 0, 2.6),
		"block": Vector3(-3.4, 0, 5.0), "recorder": Vector3(3.6, 0, 4.6), "guardian": Vector3(0, 1.6, 0),
		"guardian_mid": Vector3(0, 1.7, 0), "door_look": Vector3(0, 1.3, 0),
		"wide_cam": Vector3(-20, 7, 18), "wide_cam2": Vector3(-8, 3.0, 12),
		"door_cam": Vector3(3.0, 1.6, 6.5), "two_cam": Vector3(0.2, 1.7, 7.5),
		"kirk_send": Vector3(-1.8, 0, 4.2), "spock_send": Vector3(0.7, 0, 3.2), "thelin_send": Vector3(2.9, 0, 5.4),
		"thelin_near": Vector3(1.9, 0, 4.0), "kirk_meet": Vector3(-0.6, 0, 3.8),
		"send_cam": Vector3(-5.0, 2.3, 9.5), "send_cam2": Vector3(-3.2, 1.75, 6.8),
		"thelin_send_cam": Vector3(-0.6, 1.65, 7.2), "spock_send_cam": Vector3(3.6, 1.65, 6.2),
	}


# Enterprise, Deck 7 transporter room (map metres x 0.8): pads at the west end raised 0.52, console east.
static func _d(x: float, z: float, y_world := 0.0, floor_raw := 0.0) -> Vector3:
	return Vector3(x * 0.8, floor_raw * 0.8 + y_world, z * 0.8)


static func _transporter_spots() -> Dictionary:
	return {
		"centre": _d(-23.0, -40.2),
		"pad1": _d(-27.3, -41.6, 0.0, 0.52), "pad2": _d(-27.3, -40.4, 0.0, 0.52), "pad3": _d(-27.3, -39.2, 0.0, 0.52),
		"pads": _d(-27.3, -40.4, 1.3, 0.52), "console": _d(-18.9, -40.4),
		"floor_spock": _d(-24.6, -40.2),
		"room_cam": _d(-16.8, -36.9, 1.75), "thelin_cam": _d(-22.6, -41.6, 1.6), "pads_cam": _d(-21.4, -39.4, 1.6),
		"spock": _d(-27.3, -40.4, 0.0, 0.52),
		# standing on the deck to meet a landing party: the first officer (pads' south side) and the doctor (north)
		"officer": _d(-24.3, -41.9), "doc": _d(-24.3, -38.9),
		"officer_cam": _d(-21.2, -40.9, 1.6), "doc_cam": _d(-21.2, -39.6, 1.6),
	}


# Deck 7 briefing room: the long table runs north-south (x -17.9..-14.9, z -9.6..-3.2), crew standing either side.
static func _briefing_spots() -> Dictionary:
	return {
		"centre": _d(-16.4, -7.4),
		"seat1": _d(-18.6, -8.4), "seat3": _d(-18.6, -6.4), "seat2": _d(-14.0, -8.4), "seat4": _d(-14.0, -6.4),
		"table": _d(-16.4, -7.4, 0.85), "table_cam": _d(-12.6, -11.8, 1.9),
		"kirk_cam": _d(-13.2, -9.6, 1.6), "spock_cam": _d(-19.3, -9.6, 1.6),
		"mccoy_cam": _d(-13.2, -5.2, 1.6), "thelin_cam": _d(-19.3, -5.2, 1.6),
	}


# Deck 5, the captain's-cabin layout dressed as Spock's quarters (floor 8.16): desk shelf on the south wall,
# door on the east.
static func _quarters_spots() -> Dictionary:
	return {
		"centre": _d(3.0, -83.5, 0.0, 8.16),
		"shelf": _d(3.0, -84.6, 0.0, 8.16), "shelf_look": _d(3.0, -87.5, 1.0, 8.16),
		"q_door": _d(7.3, -83.0, 0.0, 8.16),
		"q_cam": _d(-0.6, -81.6, 1.6, 8.16), "q_door_cam": _d(2.0, -84.0, 1.6, 8.16),
		"mccoy": _d(7.3, -83.0, 0.0, 8.16),
	}


# Shi'Kahr: offsets from Vulcan Fury's story spots (street = the Old Quarter's "elder" spot, courtyard = T'Vora's
# square where the sehlat lies, healer = the apothecary in the market canyon).
static func _city_spots(key: String) -> Dictionary:
	match key:
		"street":
			return {
				"centre": Vector3(0, 0, 0),
				"selek": Vector3(-7, 0, 5), "selek_stop": Vector3(-2.0, 0, 1.8),
				"boy": Vector3(2.5, 0, -1.5), "boy_push": Vector3(3.0, 0, -1.8), "boy_home": Vector3(9, 0, 5),
				"bully1": Vector3(3.6, 0, -2.6), "bully2": Vector3(1.8, 0, -2.9), "bully3": Vector3(3.2, 0, -0.4),
				"bully1_back": Vector3(4.4, 0, -3.3), "run1": Vector3(12, 0, -8), "run2": Vector3(11, 0, -10), "run3": Vector3(13, 0, -6),
				"sarek": Vector3(4.6, 0, 1.6),
				"street_cam": Vector3(-11, 2.2, 9), "street_cam2": Vector3(-5.5, 1.8, 5.5), "boys_cam": Vector3(-0.5, 1.4, 1.2),
				"sarek_cam": Vector3(1.0, 1.65, 2.6), "selek_cam": Vector3(1.8, 1.65, 0.6),
			}
		"courtyard":
			return {
				"centre": Vector3(0, 0, 0),
				"sehlat": Vector3(0, 0, 0), "by_sehlat": Vector3(1.7, 0, 0.9), "amanda": Vector3(-2.2, 0, 2.2),
				"selek_c": Vector3(-3.4, 0, -0.8),
				"court_cam": Vector3(3.0, 1.7, 5.5), "amanda_cam": Vector3(-4.6, 1.65, 1.0), "selek_c_cam": Vector3(-1.2, 1.65, 2.6),
			}
		"courtyard_morning":
			return {
				"centre": Vector3(0, 0, 0),
				"sarek_door": Vector3(-1.0, 0, -2.5), "amanda_door": Vector3(0.6, 0, -2.6), "amanda_to_boy": Vector3(0.4, 0, -0.2),
				"boy_back": Vector3(0.2, 0, 1.2), "selek_back": Vector3(-1.4, 0, 2.6), "inside": Vector3(0.0, 0, -7.0),
				"selek_leaves": Vector3(-10, 0, 12),
				"morning_cam": Vector3(3.2, 1.7, 4.4), "sarek_m_cam": Vector3(-0.9, 1.65, 0.6), "selek_m_cam": Vector3(-1.0, 1.65, -0.4),
			}
		"healer":
			return {
				"centre": Vector3(0, 0, 2),
				"boy_door": Vector3(0, 0, 1.3), "healer_door": Vector3(0, 0, -0.1),
				"door_cam_h": Vector3(1.6, 1.4, 3.4), "healer_cam": Vector3(-0.6, 1.3, 2.6),
			}
	return {}


# The desert below the hills: Vulcan Fury's desert ground at the origin, mesas round it.
static func _desert_spots() -> Dictionary:
	return {
		"centre": Vector3(1.5, 0, 5.0),
		"boy_start": Vector3(-6, 0, -10), "boy_mid": Vector3(0, 0, 0), "boy_end": Vector3(3.4, 0, 7.0),
		"boy_runs": Vector3(-25, 0, -22), "sehlat_start": Vector3(1.4, 0, 5.0),
		"selek_far": Vector3(-14, 0, -18), "selek_near": Vector3(0, 0, 3), "lematya": Vector3(6.2, 0, 10.5),
		"lematya_down": Vector3(5.8, 0, 9.8), "lematya_side": Vector3(5.0, 0, 8.8), "by_ichaya": Vector3(0, 0, 5.4),
		"boy_dawn": Vector3(2.6, 0, 3.8), "healer_dawn": Vector3(3.6, 0, 6.6), "boy_by_ichaya": Vector3(2.2, 0, 5.4),
		"desert_cam": Vector3(-12, 2.0, -4), "desert_cam2": Vector3(-5, 1.8, 4), "fight_cam": Vector3(0.5, 1.6, 2.0),
		"two_desert_cam": Vector3(-1.0, 1.6, 9.6), "sehlat_cam": Vector3(-2.2, 1.4, 7.8),
		"dawn_cam": Vector3(-4.5, 2.2, 9.5), "dawn_cam2": Vector3(-2.0, 1.4, 7.6), "healer_dawn_cam": Vector3(1.0, 1.6, 9.0),
		"boy_dawn_cam": Vector3(4.6, 1.3, 2.0), "selek_dawn_cam": Vector3(2.8, 1.6, 7.6),
	}
