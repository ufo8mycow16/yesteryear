class_name CabinDressing
extends RefCounted
## REV 688 (Glen, 30 Oct: "could you dress all the rooms now plz"): the twelve Deck 5 cabins (copies of Kirk's quarters,
## REV 682-687 - docs/systems/copying-rooms.md) each get their owner's things: their own bedspread and pillow, and the
## personal pieces agreed in chat (Spock's firepot and IDIC, Scotty's Flying Scotsman and Scotch, McCoy's bag and
## bourbon, Uhura's tribble basket, Sulu's plants and fencing foil, Giotto's phaser rifle rack, M'Benga's bag and Vulcan
## pottery; the crew cabins books, PADDs, pictures, plants, bottles). Spock's harp waits until it is assembled right
## (Glen: "that harp isn't together right").
##
## Everything is placed in KIRK'S ROOM'S OWN coordinates (map units: his desk, the counter along his back wall, the
## shelf by his partition, his bunk, his side wall) and carried into each cabin with the same turn / mirror / depth the
## cabin was copied with (tools/deck5_cabins.txt) - so one list of spots serves every cabin. ModelRoom.build_shared
## calls build() for the map file aedeck5_6.glb.

## name -> [door centre (map x, y), turn (degrees), mirrored, depth factor, clamp (axis, "<=" or ">=", limit) or []]
## (keep in step with tools/deck5_cabins.txt and tools/rebuild_deck5.sh's nudges)
const CABINS := {
	"uhura": [Vector2(8, 1185), 180.0, false, 1.0, []],
	"spock": [Vector2(739, 1185), 180.0, false, 1.0, []],
	"mccoy": [Vector2(-335, 1613), 90.0, false, 1.0, []],
	"sulu": [Vector2(-335, 2251), 90.0, false, 1.0, []],
	"scotty": [Vector2(1111, 1613), -90.0, false, 1.0, []],
	"giotto": [Vector2(1001, 1795), 90.0, true, 1.0, []],
	"mbenga": [Vector2(510, 1295), 0.0, false, 1.0, ["y", "<=", 1535.0]],
	"tork": [Vector2(768, 2686), 0.0, false, 1.0, []],
	"colt": [Vector2(1111, 2251), -90.0, true, 1.0, []],
	"millins": [Vector2(-217, 1795), -90.0, false, 1.0, ["y", "<=", 1896.0]],
	"horck": [Vector2(289, 1299), 0.0, true, 0.8, ["x", "<=", 384.0]],
	"fischer": [Vector2(565, 2044), 0.0, false, 1.0, ["x", ">=", 462.0]],
}
const KIRK_DOOR := Vector2(37, 2683)

## Spots in Kirk's room (map units): [x, y, top z, facing (x, y) - the way the thing faces / its length runs]
const SPOTS := {
	"desk_a": [25.0, 2846.0, 304.0, Vector2(1, 0)], "desk_b": [-6.0, 2852.0, 304.0, Vector2(1, 0)],
	"desk_c": [22.0, 2878.0, 304.0, Vector2(1, 0)],
	"counter_1": [-42.0, 2935.0, 304.0, Vector2(0, -1)], "counter_2": [58.0, 2935.0, 304.0, Vector2(0, -1)],
	"counter_3": [152.0, 2935.0, 304.0, Vector2(0, -1)], "counter_4": [210.0, 2935.0, 304.0, Vector2(0, -1)],
	"counter_5": [260.0, 2935.0, 304.0, Vector2(0, -1)],
	"shelf_1": [112.0, 2888.0, 310.0, Vector2(-1, 0)], "shelf_2": [112.0, 2918.0, 310.0, Vector2(-1, 0)],
	"wall": [287.0, 2730.0, 338.0, Vector2(-1, 0)],
	"floor": [262.0, 2764.0, 272.0, Vector2(-1, 0)],
	# REV 690: against the free side wall (x 288, between the front wall and Kirk's second door at y 2786), for furniture
	"side_floor": [268.0, 2738.0, 272.0, Vector2(-1, 0)],
	# REV 691: the same wall, right in the corner by the front wall (McCoy's desk; Glen: "put his desk in the corner")
	"corner_floor": [268.0, 2716.0, 272.0, Vector2(-1, 0)],
	# REV 776: the desk's open end, turned toward the desk chair (Kirk's chair at map (-53, 2875))
	"desk_viewer": [1.7, 2833.0, 304.0, Vector2(-0.79, 0.61)],
}
## Kirk's bunk: mattress top z 288, x 165-221, y 2839-2923 (pillow end at the back wall, y 2923)
const BUNK := [165.0, 221.0, 2839.0, 2923.0, 288.0]

const DRESSING := {
	"uhura": {"bed": Color(0.74, 0.12, 0.10), "items": [["tribble_basket", "counter_3"], ["vase", "counter_1", Color(0.80, 0.16, 0.12)], ["cards", "desk_a"], ["padd", "desk_b"], ["picture", "counter_4"]]},
	"spock": {"bed": Color(0.42, 0.06, 0.05), "items": [["firepot", "floor"], ["idic", "wall"], ["books", "shelf_1", "dark"], ["statue", "counter_4"], ["padd", "desk_a"]]},
	"mccoy": {"bed": Color(0.14, 0.24, 0.52), "items": [["medbag", "desk_a"], ["bottle", "counter_2", Color(0.55, 0.28, 0.06)], ["glass", "counter_2", 0.13], ["glass", "counter_2", -0.13], ["books", "shelf_1", "warm"], ["picture", "counter_4"]]},
	"sulu": {"bed": Color(0.12, 0.36, 0.18), "items": [["model", "counter_2", KATANA_RACK, 1.05, 0.0, false], ["plant", "counter_1"], ["plant", "counter_3"], ["plant", "counter_5"], ["plant", "shelf_2"], ["foil", "wall"], ["padd", "desk_a"]]},
	"scotty": {"bed": Color(0.10, 0.28, 0.16), "items": [["train", "counter_3"], ["decanter", "counter_5"], ["glass", "counter_5", 0.12], ["books", "desk_a", "manuals"], ["padd", "desk_b"]]},
	"giotto": {"bed": Color(0.30, 0.30, 0.32), "items": [["rifle_rack", "wall"], ["picture", "counter_4"], ["padd", "desk_a"], ["books", "shelf_1", "dark"]]},
	"mbenga": {"bed": Color(0.60, 0.40, 0.16), "items": [["medbag", "desk_a"], ["vase", "counter_3", Color(0.70, 0.42, 0.20)], ["statue", "counter_5"], ["books", "shelf_1", "warm"], ["padd", "desk_b"]]},
	"tork": {"bed": Color(0.10, 0.14, 0.32), "items": [["books", "desk_a", "warm"], ["picture", "counter_3"], ["plant", "shelf_2"]]},
	"colt": {"bed": Color(0.44, 0.10, 0.18), "items": [["padd", "desk_a"], ["plant", "counter_3"], ["bottle", "counter_5", Color(0.16, 0.42, 0.16)]]},
	"millins": {"bed": Color(0.08, 0.36, 0.36), "items": [["vase", "counter_2", Color(0.20, 0.50, 0.70)], ["books", "shelf_1", "warm"], ["cards", "desk_a"]]},
	"horck": {"bed": Color(0.68, 0.34, 0.08), "items": [["picture", "counter_2"], ["padd", "desk_a"], ["books", "shelf_2", "dark"]]},
	"fischer": {"bed": Color(0.34, 0.14, 0.44), "items": [["books", "desk_a", "manuals"], ["bottle", "counter_4", Color(0.30, 0.20, 0.50)], ["plant", "shelf_1"]]},
}
const TRAIN_MODEL := "res://assets/models/props/flying_scotsman/flying_scotsman_desk.glb"
const TRIBBLE_MODEL := "res://assets/models/props/tribble.glb"
## REV 690: Glen's models - McCoy's roll-top desk (front = the model's +Z), Sulu's katana in its case on a stand
## (long along its Z). ["model", spot, path, size of its longest side (m), turn (degrees), solid]
## REV 776 (Glen: "everywhere!"): his TOS desk viewer (props3dpro kit, tools/props/desk_viewer/) on every cabin desk,
## Kirk's own included; height in metres (the map's furniture is ~1.28x life size, so ~28 cm real).
const DESK_VIEWER := "res://assets/models/props/tos_desk_viewer/tos_desk_viewer.glb"
const DESK_VIEWER_HEIGHT := 0.36
const ROLL_TOP_DESK := "res://assets/models/props/roll_top_desk/roll_top_desk.glb"
const KATANA_RACK := "res://assets/models/props/katana_rack/katana_rack.glb"

var room: Node3D
var u := 0.024           # metres per map unit (set from the room)
var cab: Array = []
var _mats := {}


static func build(r: Node3D) -> void:
	var d := CabinDressing.new()
	d.room = r
	d.u = float(r.get("QS")) * float((r.get("cfg") as Dictionary)["scale"])
	for name in DRESSING:
		d.cab = CABINS[name]
		var root := Node3D.new()
		root.name = "CabinDressing_" + String(name)
		r.add_child(root)
		d._dress(root, DRESSING[name])
	# REV 776: a desk viewer in every cabin, Kirk's (the original room, no turn) too
	var viewers := Node3D.new()
	viewers.name = "CabinDeskViewers"
	r.add_child(viewers)
	var all := CABINS.duplicate()
	all["kirk"] = [KIRK_DOOR, 0.0, false, 1.0, []]
	for name in all:
		d.cab = all[name]
		d._model(d._spot(viewers, "desk_viewer"), DESK_VIEWER, DESK_VIEWER_HEIGHT, Vector3.ZERO, PI * 0.5)


# --- placing --------------------------------------------------------------------------------------------------------

## REV 741 (Glen: "scotty should be on deck 5, the officers quarters" - Episode 3's cabin bits moved here from Deck 6):
## where a cabin's spot is in the room (world), for a room's hotspots.
static func spot_world(r: Node3D, cabin: String, spot: String) -> Vector3:
	var d := CabinDressing.new()
	d.room = r
	d.u = float(r.get("QS")) * float((r.get("cfg") as Dictionary)["scale"])
	d.cab = CABINS[cabin]
	var s: Array = SPOTS[spot]
	var p := d._map(float(s[0]), float(s[1]))
	return r.call("q", p.x, p.y, float(s[2]))


## REV 741 (Glen's model: assets/models/props/decanter/ - decanter.obj + Textures/, no colour picture - it's glass): cut
## crystal (the bump picture as a normal map, decanter_normal.png), amber Scotch inside, a cork stopper. The obj's
## surfaces are out / in / cork / liquid. 0.27 m tall (x `scale`), standing on `pos` in `parent`.
const DECANTER := "res://assets/models/props/decanter/decanter.obj"
const DECANTER_NORMAL := "res://assets/models/props/decanter/decanter_normal.png"

static func make_decanter(parent: Node3D, pos: Vector3, scale: float = 1.0) -> Node3D:
	if not ResourceLoader.exists(DECANTER):
		return null
	var mesh := load(DECANTER) as Mesh
	if mesh == null:
		return null
	var glass := StandardMaterial3D.new()
	glass.albedo_color = Color(0.86, 0.92, 0.95, 0.22)
	glass.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_DEPTH_PRE_PASS
	glass.roughness = 0.04
	glass.metallic_specular = 0.9
	glass.rim_enabled = true
	glass.rim = 0.35
	glass.rim_tint = 0.2
	if ResourceLoader.exists(DECANTER_NORMAL):
		glass.normal_enabled = true
		glass.normal_texture = load(DECANTER_NORMAL)
		glass.normal_scale = 0.8
	var inner := glass.duplicate() as StandardMaterial3D
	inner.albedo_color = Color(0.86, 0.92, 0.95, 0.12)
	inner.cull_mode = BaseMaterial3D.CULL_FRONT
	var scotch := StandardMaterial3D.new()
	scotch.albedo_color = Color(0.62, 0.30, 0.05, 0.78)
	scotch.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	scotch.roughness = 0.08
	scotch.emission_enabled = true
	scotch.emission = Color(0.35, 0.14, 0.02)
	scotch.emission_energy_multiplier = 0.25
	var cork := StandardMaterial3D.new()
	cork.albedo_color = Color(0.55, 0.40, 0.24)
	cork.roughness = 0.85
	var mi := MeshInstance3D.new()
	mi.name = "Decanter"
	mi.mesh = mesh
	for i in mesh.get_surface_count():
		var nm := String(mesh.surface_get_name(i)).to_lower() if mesh is ArrayMesh else ""
		var m: Material = glass
		if nm.contains("liquid"):
			m = scotch
		elif nm.contains("cork"):
			m = cork
		elif nm == "in" or nm.begins_with("in"):
			m = inner
		mi.set_surface_override_material(i, m)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var ab := mesh.get_aabb()
	var k := 0.27 * scale / maxf(ab.size.y, 0.001)
	var holder := Node3D.new()
	holder.name = "DecanterHolder"
	parent.add_child(holder)
	holder.add_child(mi)
	mi.position = -Vector3(ab.get_center().x, ab.position.y, ab.get_center().z)
	holder.scale = Vector3.ONE * k
	holder.position = pos
	return holder


## A point in Kirk's room -> the same point in this cabin (map units).
func _map(x: float, y: float) -> Vector2:
	var c: Vector2 = cab[0]
	var dx := x - KIRK_DOOR.x
	var dy := (y - KIRK_DOOR.y) * float(cab[3])
	if bool(cab[2]):
		dx = -dx
	var a := deg_to_rad(float(cab[1]))
	var p := Vector2(c.x + dx * cos(a) - dy * sin(a), c.y + dx * sin(a) + dy * cos(a))
	var cl: Array = cab[4]
	if not cl.is_empty():
		var i := 0 if String(cl[0]) == "x" else 1
		# that side's wall was pulled in (rebuild_deck5.sh's nudge): keep things on its counter in front of it
		if String(cl[1]) == "<=" and p[i] > float(cl[2]) - 12.0:
			p[i] = float(cl[2]) - 12.0
		elif String(cl[1]) == ">=" and p[i] < float(cl[2]) + 12.0:
			p[i] = float(cl[2]) + 12.0
	return p


func _dir(v: Vector2) -> Vector2:
	var dx := v.x
	if bool(cab[2]):
		dx = -dx
	var a := deg_to_rad(float(cab[1]))
	return Vector2(dx * cos(a) - v.y * sin(a), dx * sin(a) + v.y * cos(a))


## A node at a Kirk-room point, its local +X along `facing` (a Kirk-room direction), +Y up.
func _at(parent: Node3D, x: float, y: float, z: float, facing: Vector2) -> Node3D:
	var n := Node3D.new()
	parent.add_child(n)
	var p := _map(x, y)
	var f := _dir(facing)
	var w0: Vector3 = room.call("q", p.x, p.y, z)
	var w1: Vector3 = room.call("q", p.x + f.x * 10.0, p.y + f.y * 10.0, z)
	var fx := (w1 - w0)
	fx.y = 0.0
	fx = fx.normalized()
	var fz := fx.cross(Vector3.UP).normalized()
	n.transform = Transform3D(Basis(fx, Vector3.UP, fz), w0)   # parent = the cabin root, which sits at the room's origin
	return n


func _spot(parent: Node3D, spot: String) -> Node3D:
	var s: Array = SPOTS[spot]
	return _at(parent, float(s[0]), float(s[1]), float(s[2]), s[3])


# --- materials and primitives ----------------------------------------------------------------------------------------

func _mat(col: Color, rough: float = 0.6, metal: float = 0.0, glow: float = 0.0, alpha: float = 1.0) -> StandardMaterial3D:
	var k := "%s|%.2f|%.2f|%.2f|%.2f" % [col.to_html(), rough, metal, glow, alpha]
	if _mats.has(k):
		return _mats[k]
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(col.r, col.g, col.b, alpha)
	m.roughness = rough
	m.metallic = metal
	if glow > 0.0:
		m.emission_enabled = true
		m.emission = col
		m.emission_energy_multiplier = glow
	if alpha < 1.0:
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_mats[k] = m
	return m


func _box(p: Node3D, pos: Vector3, size: Vector3, m: Material, rot := Vector3.ZERO) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	mi.material_override = m
	mi.position = pos
	mi.rotation = rot
	p.add_child(mi)
	return mi


func _cyl(p: Node3D, pos: Vector3, r_top: float, r_bot: float, h: float, m: Material, rot := Vector3.ZERO, segs: int = 24) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = r_top
	cm.bottom_radius = r_bot
	cm.height = h
	cm.radial_segments = segs
	cm.rings = 1
	mi.mesh = cm
	mi.material_override = m
	mi.position = pos
	mi.rotation = rot
	p.add_child(mi)
	return mi


func _ball(p: Node3D, pos: Vector3, r: float, m: Material) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = r
	sm.height = r * 2.0
	sm.radial_segments = 16
	sm.rings = 8
	mi.mesh = sm
	mi.material_override = m
	mi.position = pos
	p.add_child(mi)
	return mi


## REV 741: the same, for any room (Episode 3's Deck 6 puts Glen's Flying Scotsman on Scotty's desk).
static func place_model(p: Node3D, path: String, length: float, pos := Vector3.ZERO, yaw := 0.0) -> Node3D:
	return CabinDressing.new()._model(p, path, length, pos, yaw)


func _model(p: Node3D, path: String, length: float, pos := Vector3.ZERO, yaw := 0.0) -> Node3D:
	if not ResourceLoader.exists(path):
		return null
	var ps := load(path) as PackedScene
	if ps == null:
		return null
	var holder := Node3D.new()
	p.add_child(holder)
	var m: Node3D = ps.instantiate()
	holder.add_child(m)
	var box := AABB()
	var first := true
	for c in m.find_children("*", "MeshInstance3D", true, false):
		var mi := c as MeshInstance3D
		var t := Transform3D.IDENTITY
		var walk: Node = mi
		while walk != null and walk != holder:
			if walk is Node3D:
				t = (walk as Node3D).transform * t
			walk = walk.get_parent()
		var a := t * mi.get_aabb()
		box = a if first else box.merge(a)
		first = false
	if first:
		return holder
	var k := length / maxf(box.size.x, maxf(box.size.y, box.size.z))
	m.position = -Vector3(box.get_center().x, box.position.y, box.get_center().z)
	holder.scale = Vector3.ONE * k
	holder.position = pos
	holder.rotation.y = yaw
	return holder


## A whole model on a spot; solid ones get a box you can't walk through.
func _placed_model(n: Node3D, it: Array) -> void:
	var h := _model(n, String(it[2]), float(it[3]), Vector3.ZERO, deg_to_rad(float(it[4])))
	if h == null or it.size() < 6 or not bool(it[5]):
		return
	var box := AABB()
	var first := true
	for c in h.find_children("*", "MeshInstance3D", true, false):
		var mi := c as MeshInstance3D
		var t := Transform3D.IDENTITY
		var w: Node = mi
		while w != null and w != n:
			if w is Node3D:
				t = (w as Node3D).transform * t
			w = w.get_parent()
		var a := t * mi.get_aabb()
		box = a if first else box.merge(a)
		first = false
	if first:
		return
	var body := StaticBody3D.new()
	var shape := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = box.size
	shape.shape = bs
	shape.position = box.get_center()
	body.add_child(shape)
	n.add_child(body)


# --- the cabin ------------------------------------------------------------------------------------------------------

func _dress(root: Node3D, d: Dictionary) -> void:
	_bed(root, d["bed"])
	for it in d["items"]:
		var kind := String(it[0])
		var n := _spot(root, String(it[1]))
		match kind:
			"bottle": _bottle(n, it[2])
			"glass": _glass(n, float(it[2]))
			"books": _books(n, String(it[2]))
			"padd": _padd(n)
			"cards": _cards(n)
			"plant": _plant(n)
			"vase": _vase(n, it[2])
			"picture": _picture(n)
			"statue": _statue(n)
			"medbag": _medbag(n)
			"firepot": _firepot(n)
			"idic": _idic(n)
			"foil": _foil(n)
			"rifle_rack": _rifle_rack(n)
			"model": _placed_model(n, it)
			"train": _model(n, TRAIN_MODEL, 0.62)   # REV 741 (Glen: "should be bigger"): was 0.42   # the model runs along its Z = along the counter
			"tribble_basket": _tribble_basket(n)
			"decanter": make_decanter(n, Vector3(0.0, 0.0, -0.06), room.call("ms"))   # REV 741: Glen's crystal decanter


## The owner's own bedspread over the foot two-thirds of the bunk, folded back, and a white pillow at the head.
func _bed(root: Node3D, col: Color) -> void:
	var x0 := float(BUNK[0]) + 1.0
	var x1 := float(BUNK[1]) - 1.0
	var y0 := float(BUNK[2]) + 1.0
	var y1 := float(BUNK[3])
	var z := float(BUNK[4])
	var cx := (x0 + x1) * 0.5
	var spread := _mat(col, 0.85)
	var fold := _mat(col.lightened(0.15), 0.85)
	var pillow := _mat(Color(0.92, 0.92, 0.9), 0.9)
	var w := (x1 - x0) * u
	var ys := y0 + (y1 - y0) * 0.68
	var n := _at(root, cx, (y0 + ys) * 0.5, z, Vector2(1, 0))
	_box(n, Vector3(0.0, 0.012, 0.0), Vector3(w + 0.04, 0.024, (ys - y0) * u), spread)
	# the spread hangs a little over each side
	_box(n, Vector3(w * 0.5 + 0.02, -0.06, 0.0), Vector3(0.012, 0.13, (ys - y0) * u), spread)
	_box(n, Vector3(-w * 0.5 - 0.02, -0.06, 0.0), Vector3(0.012, 0.13, (ys - y0) * u), spread)
	var nf := _at(root, cx, ys + 3.0, z, Vector2(1, 0))
	_box(nf, Vector3(0.0, 0.03, 0.0), Vector3(w + 0.03, 0.03, 0.16), fold)
	var np := _at(root, cx, y1 - 9.0, z, Vector2(1, 0))
	_box(np, Vector3(0.0, 0.05, 0.0), Vector3(w * 0.72, 0.1, 0.3), pillow)


func _bottle(n: Node3D, col: Color) -> void:
	var glass := _mat(col, 0.08, 0.0, 0.0, 0.82)
	_cyl(n, Vector3(0, 0.1, 0), 0.036, 0.036, 0.2, glass)
	_cyl(n, Vector3(0, 0.225, 0), 0.014, 0.034, 0.05, glass)
	_cyl(n, Vector3(0, 0.268, 0), 0.014, 0.014, 0.04, glass)
	_cyl(n, Vector3(0, 0.295, 0), 0.017, 0.017, 0.018, _mat(Color(0.12, 0.08, 0.05), 0.5))
	_box(n, Vector3(0.037, 0.1, 0), Vector3(0.002, 0.07, 0.05), _mat(Color(0.9, 0.85, 0.7), 0.7))


func _glass(n: Node3D, off: float) -> void:
	_cyl(n, Vector3(off, 0.045, 0.06), 0.034, 0.03, 0.09, _mat(Color(0.85, 0.9, 0.95), 0.05, 0.0, 0.0, 0.35))


func _books(n: Node3D, style: String) -> void:
	var cols := {"dark": [Color(0.12, 0.12, 0.14), Color(0.35, 0.05, 0.05), Color(0.08, 0.1, 0.2)],
		"warm": [Color(0.5, 0.18, 0.08), Color(0.2, 0.3, 0.12), Color(0.55, 0.45, 0.2), Color(0.3, 0.1, 0.1)],
		"manuals": [Color(0.25, 0.3, 0.38), Color(0.4, 0.4, 0.42), Color(0.1, 0.2, 0.45)]}[style] as Array
	var x := -0.12
	for i in 6:
		var w := 0.025 + 0.012 * float(i % 3)
		var h := 0.17 + 0.03 * float((i * 7) % 3)
		_box(n, Vector3(x + w * 0.5, h * 0.5, 0.0), Vector3(w, h, 0.14), _mat(cols[i % cols.size()], 0.7))
		x += w + 0.004
	_box(n, Vector3(x + 0.08, 0.02, 0.0), Vector3(0.15, 0.04, 0.2), _mat(cols[0], 0.7), Vector3(0, 0.3, 0))


func _padd(n: Node3D) -> void:
	_box(n, Vector3(0, 0.006, 0), Vector3(0.11, 0.012, 0.16), _mat(Color(0.12, 0.12, 0.13), 0.4), Vector3(0, 0.4, 0))
	_box(n, Vector3(0, 0.013, 0), Vector3(0.08, 0.002, 0.1), _mat(Color(0.3, 0.75, 0.9), 0.3, 0.0, 0.9), Vector3(0, 0.4, 0))


func _cards(n: Node3D) -> void:
	var cols := [Color(0.9, 0.2, 0.15), Color(0.95, 0.75, 0.1), Color(0.2, 0.6, 0.95), Color(0.3, 0.85, 0.3)]
	for i in 6:
		_box(n, Vector3(0.012 * i, 0.002 + 0.003 * i, 0.0), Vector3(0.05, 0.003, 0.05), _mat(cols[i % 4], 0.4), Vector3(0, 0.25 * i, 0))


func _plant(n: Node3D) -> void:
	_cyl(n, Vector3(0, 0.06, 0), 0.07, 0.055, 0.12, _mat(Color(0.75, 0.72, 0.66), 0.7))
	_cyl(n, Vector3(0, 0.118, 0), 0.064, 0.064, 0.01, _mat(Color(0.2, 0.13, 0.07), 1.0))
	var leaf := _mat(Color(0.18, 0.48, 0.16), 0.6)
	var leaf2 := _mat(Color(0.26, 0.58, 0.2), 0.6)
	for i in 10:
		var a := TAU * float(i) / 10.0
		var tilt := 0.35 + 0.25 * float(i % 3)
		var l := 0.16 + 0.05 * float(i % 4)
		var mi := _box(n, Vector3(cos(a) * 0.03, 0.12 + l * 0.45, sin(a) * 0.03), Vector3(0.028, l, 0.004), leaf if i % 2 == 0 else leaf2)
		mi.rotation = Vector3(0.0, -a, 0.0)
		mi.rotate_object_local(Vector3(0, 0, 1), -tilt)


func _vase(n: Node3D, col: Color) -> void:
	var m := _mat(col, 0.35)
	_cyl(n, Vector3(0, 0.03, 0), 0.06, 0.045, 0.06, m, Vector3.ZERO, 32)
	_cyl(n, Vector3(0, 0.1, 0), 0.04, 0.06, 0.08, m, Vector3.ZERO, 32)
	_cyl(n, Vector3(0, 0.17, 0), 0.05, 0.04, 0.06, m, Vector3.ZERO, 32)
	var stem := _mat(Color(0.25, 0.5, 0.2), 0.7)
	var petals := [Color(0.95, 0.85, 0.3), Color(0.95, 0.4, 0.5), Color(0.95, 0.95, 0.9)]
	for i in 5:
		var a := TAU * float(i) / 5.0
		var tip := Vector3(cos(a) * 0.07, 0.34 + 0.03 * float(i % 2), sin(a) * 0.07)
		var mi := _cyl(n, (Vector3(0, 0.19, 0) + tip) * 0.5, 0.003, 0.003, tip.distance_to(Vector3(0, 0.19, 0)), stem)
		mi.rotation = Vector3(0.0, -a, -atan2(Vector2(tip.x, tip.z).length(), tip.y - 0.19))
		_ball(n, tip, 0.022, _mat(petals[i % 3], 0.6))


func _picture(n: Node3D) -> void:
	var frame := _mat(Color(0.75, 0.62, 0.3), 0.3, 0.8)
	var p := Node3D.new()
	n.add_child(p)
	p.rotation = Vector3(0.0, PI * 0.5, 0.0)   # its face towards the room (+X)
	p.rotate_object_local(Vector3.RIGHT, -0.2)
	_box(p, Vector3(0, 0.1, 0), Vector3(0.16, 0.2, 0.012), frame)
	_box(p, Vector3(0, 0.1, 0.007), Vector3(0.13, 0.17, 0.002), _mat(Color(0.35, 0.45, 0.6), 0.5, 0.0, 0.15))
	_box(p, Vector3(0, 0.07, 0.008), Vector3(0.05, 0.08, 0.002), _mat(Color(0.75, 0.55, 0.4), 0.6))
	_box(p, Vector3(0, 0.06, -0.05), Vector3(0.02, 0.12, 0.08), frame, Vector3(0.6, 0, 0))


func _statue(n: Node3D) -> void:
	var m := _mat(Color(0.18, 0.16, 0.14), 0.35, 0.3)
	_cyl(n, Vector3(0, 0.015, 0), 0.05, 0.055, 0.03, m)
	_cyl(n, Vector3(0, 0.1, 0), 0.025, 0.035, 0.14, m)
	_ball(n, Vector3(0, 0.2, 0), 0.03, m)
	_cyl(n, Vector3(0, 0.24, 0), 0.0, 0.035, 0.05, _mat(Color(0.7, 0.55, 0.25), 0.3, 0.8), Vector3.ZERO, 3)


func _medbag(n: Node3D) -> void:
	var leather := _mat(Color(0.08, 0.06, 0.05), 0.45)
	_box(n, Vector3(0, 0.08, 0), Vector3(0.34, 0.16, 0.16), leather, Vector3(0, 0.3, 0))
	_cyl(n, Vector3(0, 0.165, 0), 0.08, 0.08, 0.34, leather, Vector3(0, 0.3, PI * 0.5), 16)
	var metal := _mat(Color(0.8, 0.8, 0.82), 0.25, 0.9)
	var h := MeshInstance3D.new()
	var tm := TorusMesh.new()
	tm.inner_radius = 0.035
	tm.outer_radius = 0.045
	h.mesh = tm
	h.material_override = leather
	h.position = Vector3(0, 0.25, 0)
	h.rotation = Vector3(PI * 0.5, 0.3, 0)
	n.add_child(h)
	_box(n, Vector3(0, 0.15, 0.0), Vector3(0.04, 0.03, 0.17), metal, Vector3(0, 0.3, 0))


## Spock's Vulcan firepot: a bronze bowl on three legs with a low flame that flickers.
func _firepot(n: Node3D) -> void:
	var bronze := _mat(Color(0.55, 0.36, 0.16), 0.35, 0.8)
	for i in 3:
		var a := TAU * float(i) / 3.0
		var leg := _cyl(n, Vector3(cos(a) * 0.13, 0.22, sin(a) * 0.13), 0.012, 0.018, 0.46, bronze, Vector3.ZERO, 8)
		leg.rotation = Vector3(0.0, -a, 0.0)
		leg.rotate_object_local(Vector3(0, 0, 1), 0.18)   # splayed outwards
	_cyl(n, Vector3(0, 0.5, 0), 0.2, 0.1, 0.13, bronze, Vector3.ZERO, 32)
	_cyl(n, Vector3(0, 0.565, 0), 0.21, 0.21, 0.015, bronze, Vector3.ZERO, 32)
	_cyl(n, Vector3(0, 0.56, 0), 0.17, 0.17, 0.01, _mat(Color(0.25, 0.08, 0.02), 1.0, 0.0, 0.6))
	var flame := _mat(Color(1.0, 0.45, 0.1), 1.0, 0.0, 3.0, 0.85)
	var f1 := _cyl(n, Vector3(0, 0.63, 0), 0.0, 0.09, 0.14, flame, Vector3.ZERO, 12)
	var f2 := _cyl(n, Vector3(0.03, 0.61, 0.02), 0.0, 0.05, 0.1, _mat(Color(1.0, 0.8, 0.3), 1.0, 0.0, 4.0, 0.8), Vector3.ZERO, 10)
	var light := OmniLight3D.new()
	light.light_color = Color(1.0, 0.5, 0.2)
	light.light_energy = 0.9
	light.omni_range = 3.2
	light.shadow_enabled = false
	light.position = Vector3(0, 0.75, 0)
	n.add_child(light)
	if not room.is_inside_tree():
		return
	var tw := room.create_tween().set_loops()
	for k in 6:
		var e := 0.7 + 0.35 * float((k * 5) % 4) / 3.0
		var s := 0.85 + 0.3 * float((k * 3) % 4) / 3.0
		tw.tween_property(light, "light_energy", e, 0.11 + 0.04 * float(k % 3))
		tw.parallel().tween_property(f1, "scale", Vector3(1.0, s, 1.0), 0.11 + 0.04 * float(k % 3))
		tw.parallel().tween_property(f2, "scale", Vector3(1.0, 2.0 - s, 1.0), 0.11 + 0.04 * float(k % 3))


## REV 689: Glen's IDIC flag (assets/models/props/idic_flag/, his picture) hung on Spock's wall from a brass rod, the
## cloth in soft folds. (REV 688 had a code-built IDIC plate here - Glen: "BETTER IDIC FLAG for Spock".)
const IDIC_FLAG := "res://assets/models/props/idic_flag/idic_flag.png"

func _idic(n: Node3D) -> void:
	var p := Node3D.new()
	n.add_child(p)
	p.rotation = Vector3(0.0, PI * 0.5, 0.0)      # face out of the wall (the spot faces into the room along +X)
	p.position = Vector3(0.03, 0.08, 0.0)
	var w := 1.0
	var h := w * 611.0 / 1024.0
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var cols := 40
	var rows := 12
	var pts: Array = []
	for r in rows + 1:
		var row: Array = []
		var v := float(r) / float(rows)
		for c in cols + 1:
			var uu := float(c) / float(cols)
			# folds that deepen towards the bottom; the top edge stays straight along the rod
			var fold := 0.018 * sin(uu * TAU * 3.0) * (0.25 + 0.75 * v)
			row.append([Vector3((uu - 0.5) * w, -v * h, fold), Vector2(uu, v)])
		pts.append(row)
	for r in rows:
		for c in cols:
			var a: Array = pts[r][c]
			var b: Array = pts[r][c + 1]
			var cc: Array = pts[r + 1][c]
			var d: Array = pts[r + 1][c + 1]
			for t in [a, cc, b, b, cc, d]:
				st.set_uv(t[1])
				st.add_vertex(t[0])
	st.generate_normals()
	var cloth := MeshInstance3D.new()
	cloth.mesh = st.commit()
	var m := StandardMaterial3D.new()
	if ResourceLoader.exists(IDIC_FLAG):
		m.albedo_texture = load(IDIC_FLAG)
	else:
		m.albedo_color = Color(0.4, 0.12, 0.08)
	m.roughness = 0.75
	m.metallic_specular = 0.3
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	cloth.material_override = m
	cloth.position = Vector3(0.0, h * 0.5, 0.0)
	p.add_child(cloth)
	var brass := _mat(Color(0.78, 0.6, 0.3), 0.3, 0.9)
	_cyl(p, Vector3(0.0, h * 0.5 + 0.01, 0.0), 0.009, 0.009, w + 0.12, brass, Vector3(0, 0, PI * 0.5), 12)
	for sx in [-1.0, 1.0]:
		_ball(p, Vector3(sx * (w * 0.5 + 0.07), h * 0.5 + 0.01, 0.0), 0.018, brass)
		_box(p, Vector3(sx * (w * 0.5 + 0.02), h * 0.5 + 0.01, -0.02), Vector3(0.012, 0.03, 0.04), brass)


## Sulu's fencing foil, hung across the wall on two pegs.
func _foil(n: Node3D) -> void:
	var p := Node3D.new()
	n.add_child(p)
	p.rotation = Vector3(0.0, PI * 0.5, 0.35)
	p.position = Vector3(0.03, 0.0, 0.0)
	var steel := _mat(Color(0.82, 0.83, 0.86), 0.2, 0.95)
	_cyl(p, Vector3(0.2, 0, 0), 0.003, 0.0045, 0.86, steel, Vector3(0, 0, PI * 0.5), 8)
	_cyl(p, Vector3(-0.24, 0, 0), 0.045, 0.045, 0.012, steel, Vector3(0, 0, PI * 0.5), 24)
	_cyl(p, Vector3(-0.31, 0, 0), 0.012, 0.012, 0.13, _mat(Color(0.12, 0.1, 0.08), 0.6), Vector3(0, 0, PI * 0.5), 12)
	_ball(p, Vector3(-0.38, 0, 0), 0.016, steel)
	for x in [-0.1, 0.35]:
		_cyl(p, Vector3(x, -0.015, -0.015), 0.006, 0.006, 0.04, steel, Vector3(PI * 0.5, 0, 0), 8)


## Giotto's phaser rifle rack (the "Where No Man Has Gone Before" rifles): a wall plate with two rifles on brackets.
func _rifle_rack(n: Node3D) -> void:
	var p := Node3D.new()
	n.add_child(p)
	p.rotation = Vector3(0.0, PI * 0.5, 0.0)
	p.position = Vector3(0.01, 0.0, 0.0)
	_box(p, Vector3(0, 0, 0.006), Vector3(0.8, 0.42, 0.012), _mat(Color(0.18, 0.18, 0.2), 0.5, 0.3))
	var dark := _mat(Color(0.1, 0.1, 0.11), 0.4, 0.2)
	var grey := _mat(Color(0.55, 0.56, 0.58), 0.3, 0.8)
	for yy in [0.09, -0.09]:
		_box(p, Vector3(0.0, yy, 0.05), Vector3(0.62, 0.06, 0.05), dark)
		_box(p, Vector3(-0.22, yy - 0.04, 0.05), Vector3(0.12, 0.08, 0.04), dark)
		_cyl(p, Vector3(0.36, yy, 0.05), 0.012, 0.016, 0.16, grey, Vector3(0, 0, PI * 0.5), 12)
		_box(p, Vector3(0.05, yy + 0.04, 0.05), Vector3(0.14, 0.03, 0.03), grey)
		for x in [-0.25, 0.25]:
			_box(p, Vector3(x, yy, 0.025), Vector3(0.03, 0.05, 0.04), grey)


## Uhura's basket for Smokey the tribble.
func _tribble_basket(n: Node3D) -> void:
	var wicker := _mat(Color(0.62, 0.46, 0.24), 0.9)
	_cyl(n, Vector3(0, 0.035, 0), 0.13, 0.11, 0.07, wicker, Vector3.ZERO, 28)
	_cyl(n, Vector3(0, 0.071, 0), 0.12, 0.12, 0.004, _mat(Color(0.55, 0.12, 0.12), 0.95), Vector3.ZERO, 28)
	_model(n, TRIBBLE_MODEL, 0.15, Vector3(0, 0.07, 0), 0.6)
