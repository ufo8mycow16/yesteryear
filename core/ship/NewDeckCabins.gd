class_name NewDeckCabins
extends RefCounted
## REV 812 - the new Deck 7's crew cabins brought to life (Glen, 3 Nov: "Start making crew cabins now please"; shared
## bathrooms - yes; nameplates - yes; docs/systems/cabins.md).
##
## Everything is worked out offline (tools/new_deck7/cabins.py + cabin_furniture.py -> deck7_fj/cabins_fit.json) and
## only put in place here:
##  - SLIDING DOORS in every cabin's doorways (corridor = Kirk's pale blue door picture, bathroom = the grey one),
##    worked by MapDoors like every other door on the ship (walk up, they swish open, they shut behind you);
##  - a NAMEPLATE beside each corridor door: TOS style, two black plaques on a grey plate - the occupants
##    ("CREWMAN ROBERTS") on top, the cabin number below - names from ShipCabins (per playthrough);
##  - FURNITURE from Kirk's quarters (assets/models/props/cabin_kirk/: his bed, his divider with the red grate, his
##    desk at crew size) - beds where Joseph drew them, pushed apart round the divider; a desk with its chair and Glen's
##    desk viewer for each occupant; a red wall intercom on each side of the divider; bunks in 7F-325;
##  - the REV 810 BATHROOM FIXTURES in the shared bathroom between each pair of cabins.
## Furniture and fixtures only draw within DRAW_RANGE of the camera (the bathrooms are detailed - an older PC can't
## draw all 32 at once, and the walls hide them anyway).

const FIT := "res://assets/models/maps/deck7_fj/cabins_fit.json"
const BED := "res://assets/models/props/cabin_kirk/bed.glb"
const DIVIDER := "res://assets/models/props/cabin_kirk/divider.glb"
const DESK := "res://assets/models/props/cabin_kirk/desk.glb"
const CHAIR := "res://assets/models/props/tos_chair/tos_chair.glb"
const VIEWER := "res://assets/models/props/tos_desk_viewer/tos_desk_viewer.glb"
const BATH_DIR := "res://assets/models/props/bathroom/"
## REV 816 (Glen, 3 Nov: "I'd just make all the doors red"): every door on the new deck is the old engineering red
## door (aedeck7 textures/tos/engred_door); the pale blue and grey pictures stay in the folder.
const DOOR_PICS := {"corridor": "res://assets/models/props/cabin_door/door_red.jpg",
	"bath": "res://assets/models/props/cabin_door/door_red.jpg"}

const S := 0.8                  # Kirk's room furniture comes out of the map at 0.03 m a unit; the ship is drawn at 80%
const DESK_K := 0.75            # crew desks: Kirk's at 75% across (cabin_furniture.py DESK_K), his height kept
const DOOR_H := 2.15            # doorway height (build_deck7.DOOR_H)
const LEAF_T := 0.05
const LEAF_OVERLAP := 0.04      # each leaf left showing in the frame when open
const PLATE_Y := 1.55           # middle of a nameplate beside a door
const PLATE_OVER_Y := 2.45      # on the lintel, over a door
const DRAW_RANGE := 16.0        # furniture and fixtures draw within this many metres
const PLATE_RANGE := 22.0
const CHAIR_H := 1.0            # Kirk's chairs stand about a metre tall
const VIEWER_SIZE := 0.30       # the desk viewer's longest side
## Kirk's desk, measured off his room (desk.glb's own metres): the chair's middle and the viewer's spot and facing.
const DESK_CHAIR := Vector3(-1.92, 0.0, 0.0)
const DESK_VIEWER := Vector3(-0.279, 0.0, 1.26)
const DESK_VIEWER_FACE := Vector2(-0.79, -0.61)
const DESK_TOP := 0.96          # desk.glb's height
const BUNK_POST := 0.035

static var _scenes := {}
static var _mats := {}


## Builds it all under `room`. Returns the doors (MapDoors.Door), not yet working: the room switches them on with
## MapDoors.activate once the physics world has the deck's floor (a physics frame or two later) and ticks them.
static func build(room: Node3D) -> Array:
	if not FileAccess.file_exists(FIT):
		push_warning("NewDeckCabins: no cabins_fit.json - run tools/new_deck7/build.sh")
		return []
	var fit: Variant = JSON.parse_string(FileAccess.get_file_as_string(FIT))
	if not (fit is Dictionary):
		return []
	var f := fit as Dictionary
	var root := Node3D.new()
	root.name = "CrewCabins"
	room.add_child(root)
	var doors := _doors(root, f)
	_plates(root, f)
	_furniture(root, f)
	_bathrooms(root, f)
	return doors


# --- doors -----------------------------------------------------------------------------------------------------------

static func _doors(root: Node3D, f: Dictionary) -> Array:
	var holder := Node3D.new()
	holder.name = "CabinDoors"
	root.add_child(holder)
	var out: Array = []
	for dd in f.get("doors", []):
		var d := dd as Dictionary
		var a := _v2(d["a"])
		var b := _v2(d["b"])
		var w := a.distance_to(b)
		if w < 0.5:
			continue
		var along := (b - a) / w
		var m := (a + b) * 0.5
		var pic: String = DOOR_PICS["bath" if String(d.get("kind", "")) == "bath" else "corridor"]
		var door := MapDoors.Door.new()
		door.centre = Vector3(m.x, 0.0, m.y)
		door.normal = Vector3(-along.y, 0.0, along.x)
		door.width = w
		door.height = DOOR_H
		# the leaves slide into the wall that carries straight on past each end (cabin_furniture.py "slide"); an L
		# doorway (wall past one end only) gets one full-width leaf sliding that way
		var sl: Array = d.get("slide", [1.0, 1.0])
		var leaves: Array = []          # [side, width, u0, u1, shut centre (along the doorway), slide distance]
		if minf(float(sl[0]), float(sl[1])) > 0.6:
			var lw := w * 0.5 + LEAF_OVERLAP
			leaves.append([-1.0, lw, 0.0, 0.5, -(w * 0.25 + LEAF_OVERLAP * 0.5), w * 0.5 - LEAF_OVERLAP])
			leaves.append([1.0, lw, 0.5, 1.0, w * 0.25 + LEAF_OVERLAP * 0.5, w * 0.5 - LEAF_OVERLAP])
		else:
			var side := -1.0 if float(sl[0]) >= float(sl[1]) else 1.0
			leaves.append([side, w + LEAF_OVERLAP * 2.0, 0.0, 1.0, 0.0, w - LEAF_OVERLAP])
		for lv in leaves:
			var side: float = lv[0]
			var leaf_w: float = lv[1]
			var leaf := MeshInstance3D.new()
			leaf.name = "CabinDoorLeaf"
			leaf.mesh = _leaf_mesh(leaf_w, DOOR_H, LEAF_T, float(lv[2]), float(lv[3]))
			leaf.material_override = _picture_mat(pic)
			leaf.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			holder.add_child(leaf)
			var shut := m + along * float(lv[4])
			var open := shut + along * side * float(lv[5])
			leaf.position = Vector3(shut.x, 0.0, shut.y)
			leaf.rotation.y = atan2(-along.y, along.x)          # the leaf's +X along the doorway
			var body := StaticBody3D.new()
			var cs := CollisionShape3D.new()
			var box := BoxShape3D.new()
			box.size = Vector3(leaf_w, DOOR_H, LEAF_T + 0.02)
			cs.shape = box
			cs.position = Vector3(0.0, DOOR_H * 0.5, 0.0)
			body.add_child(cs)
			leaf.add_child(body)
			door.leaves.append([leaf, leaf.position, Vector3(open.x, 0.0, open.y)])
		out.append(door)
	return out


## A door leaf: w wide (along +X, centred), h tall from the floor, t thick; its front and back show the picture from
## u0 to u1 (the door picture holds both leaves side by side).
static func _leaf_mesh(w: float, h: float, t: float, u0: float, u1: float) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var x0 := -w * 0.5
	var x1 := w * 0.5
	for side: float in [1.0, -1.0]:
		var z := t * 0.5 * side
		var n := Vector3(0.0, 0.0, side)
		var p := [Vector3(x0, 0.0, z), Vector3(x1, 0.0, z), Vector3(x1, h, z), Vector3(x0, h, z)]
		var uv := [Vector2(u0, 1.0), Vector2(u1, 1.0), Vector2(u1, 0.0), Vector2(u0, 0.0)]
		if side < 0.0:      # seen from behind: mirror so the picture reads the same way round
			uv = [Vector2(u1, 1.0), Vector2(u0, 1.0), Vector2(u0, 0.0), Vector2(u1, 0.0)]
		var order := [0, 1, 2, 0, 2, 3] if side > 0.0 else [0, 2, 1, 0, 3, 2]
		for k in order:
			st.set_normal(n)
			st.set_uv(uv[k])
			st.add_vertex(p[k])
	# the edges (seen when it slides into the wall's gap) - a sliver of the same picture
	var e := Vector2((u0 + u1) * 0.5, 0.5)
	for ex: float in [x0, x1]:
		var n := Vector3(signf(ex), 0.0, 0.0)
		var q := [Vector3(ex, 0.0, -t * 0.5), Vector3(ex, 0.0, t * 0.5), Vector3(ex, h, t * 0.5), Vector3(ex, h, -t * 0.5)]
		var order := [0, 2, 1, 0, 3, 2] if ex > 0.0 else [0, 1, 2, 0, 2, 3]
		for k in order:
			st.set_normal(n)
			st.set_uv(e)
			st.add_vertex(q[k])
	return st.commit()


# --- nameplates ------------------------------------------------------------------------------------------------------

static func _plates(root: Node3D, f: Dictionary) -> void:
	var holder := Node3D.new()
	holder.name = "CabinNameplates"
	root.add_child(holder)
	var doors: Array = f.get("doors", [])
	for pp in f.get("plates", []):
		var p: Array = pp
		var d: Dictionary = doors[int(p[0])]
		var number := String(d.get("room", ""))
		var text := ShipCabins.plate_text(number)
		var plate := _plate(String(text[0]), String(text[1]))
		holder.add_child(plate)
		var over := p.size() > 4 and int(p[4]) == 1
		plate.position = Vector3(float(p[1]), PLATE_OVER_Y if over else PLATE_Y, float(p[2]))
		plate.rotation.y = deg_to_rad(float(p[3]))


## A TOS cabin nameplate (the ones on Deck 5's doors): a brushed grey plate with two black plaques, the names on the
## upper one and the number on the lower one, in silver capitals. Front = +Z.
static func _plate(names: String, number: String) -> Node3D:
	var n := Node3D.new()
	n.name = "Nameplate_" + number
	var lines := maxi(1, names.count("\n") + 1) if names != "" else 0
	var longest := number.length()
	for l in names.split("\n"):
		longest = maxi(longest, l.length())
	var top_w := clampf(0.024 * float(longest) + 0.06, 0.26, 0.48)
	var top_h := 0.045 * float(lines) + 0.035
	var num_w := 0.16
	var num_h := 0.06
	var gap := 0.018
	var plate_w := top_w + 0.04
	var plate_h := (top_h + gap if lines > 0 else 0.0) + num_h + 0.04
	var body := _box(Vector3(plate_w, plate_h, 0.008), _mat(Color(0.62, 0.63, 0.65), 0.45, 0.5))
	body.position = Vector3(0.0, 0.0, 0.004)
	n.add_child(body)
	var y_top := plate_h * 0.5 - 0.02
	var mat_black := _mat(Color(0.015, 0.015, 0.02), 0.12, 0.2)
	if lines > 0:
		var top := _box(Vector3(top_w, top_h, 0.01), mat_black)
		top.position = Vector3(0.0, y_top - top_h * 0.5, 0.012)
		n.add_child(top)
		n.add_child(_plate_label(names, Vector3(0.0, y_top - top_h * 0.5, 0.0185), 0.0011))
		y_top -= top_h + gap
	var low := _box(Vector3(num_w, num_h, 0.01), mat_black)
	low.position = Vector3(0.0, y_top - num_h * 0.5, 0.012)
	n.add_child(low)
	n.add_child(_plate_label(number, Vector3(0.0, y_top - num_h * 0.5, 0.0185), 0.0013))
	for c in n.find_children("*", "GeometryInstance3D", true, false):
		(c as GeometryInstance3D).visibility_range_end = PLATE_RANGE
	return n


static func _plate_label(text: String, pos: Vector3, px: float) -> Label3D:
	var l := Label3D.new()
	l.text = text
	l.position = pos
	l.pixel_size = px
	l.font_size = 32
	l.modulate = Color(0.86, 0.88, 0.9)
	l.outline_size = 0
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.line_spacing = -4.0
	l.shaded = false
	l.double_sided = false
	return l


# --- furniture -------------------------------------------------------------------------------------------------------

static func _furniture(root: Node3D, f: Dictionary) -> void:
	var furn: Dictionary = f.get("furniture", {})
	var faces := PackedVector3Array()
	for num in furn:
		var cabin := Node3D.new()
		cabin.name = "Cabin_" + String(num)
		root.add_child(cabin)
		for it in furn[num]:
			var p: Array = it
			var kind := String(p[0])
			var at := Vector3(float(p[1]), 0.0, float(p[2]))
			var yaw := deg_to_rad(float(p[3]))
			match kind:
				"bed":
					_solid(cabin, _prop(cabin, BED, at, yaw, Vector3.ONE * S), faces)
				"bunk":
					var raise := float(p[4])
					var top := _prop(cabin, BED, at + Vector3.UP * raise, yaw, Vector3.ONE * S)
					_bunk_posts(cabin, at, yaw, raise)
					_solid(cabin, top, faces)
				"divider":
					var k := float(p[4])
					var dv := _prop(cabin, DIVIDER, at, yaw, Vector3(S * k, S, S))
					_solid(cabin, dv, faces)
					_divider_intercoms(cabin, at, yaw, 0.555 * S * k)
				"desk":
					_desk(cabin, at, yaw, faces)
	if not faces.is_empty():
		var shape := ConcavePolygonShape3D.new()
		shape.set_faces(faces)
		shape.backface_collision = true
		var body := StaticBody3D.new()
		body.name = "PROP_cabin_furniture"
		var cs := CollisionShape3D.new()
		cs.shape = shape
		body.add_child(cs)
		root.add_child(body)


## A model at `at` turned `yaw`, scaled; draws only near the camera.
static func _prop(parent: Node3D, path: String, at: Vector3, yaw: float, scale: Vector3) -> Node3D:
	var ps := _scene(path)
	if ps == null:
		return null
	var m := ps.instantiate() as Node3D
	parent.add_child(m)
	m.position = at
	m.rotation.y = yaw
	m.scale = scale
	_near_only(m)
	return m


## The piece's box as solid faces (you walk round beds, desks and dividers, not through them).
static func _solid(parent: Node3D, m: Node3D, faces: PackedVector3Array) -> void:
	if m == null:
		return
	var box := _aabb(m)
	if box.size == Vector3.ZERO:
		return
	var bm := BoxMesh.new()
	bm.size = box.size
	var xf := m.transform * Transform3D(Basis(), box.get_center())
	for v in bm.get_faces():
		faces.append(xf * v)


static func _desk(cabin: Node3D, at: Vector3, yaw: float, faces: PackedVector3Array) -> void:
	var k := Vector3(S * DESK_K, S, S * DESK_K)
	var desk := _prop(cabin, DESK, at, yaw, k)
	_solid(cabin, desk, faces)
	var basis := Basis(Vector3.UP, yaw)
	# Kirk's chair spot, at the crew desk's size, facing the desk (+X)
	var chair_at := at + basis * (DESK_CHAIR * k)
	var chair := _fitted(cabin, CHAIR, CHAIR_H, true)
	if chair != null:
		chair.position = chair_at
		chair.rotation.y = yaw + PI * 0.5
	var vw := _fitted(cabin, VIEWER, VIEWER_SIZE, false)
	if vw != null:
		vw.position = at + basis * (DESK_VIEWER * k) + Vector3.UP * (DESK_TOP * S)
		var fdir := basis * Vector3(DESK_VIEWER_FACE.x, 0.0, DESK_VIEWER_FACE.y)
		vw.rotation.y = atan2(fdir.x, fdir.z)


## A model scaled so its height (by_height) or longest side is `size`, standing on its lowest point, centred.
static func _fitted(parent: Node3D, path: String, size: float, by_height: bool) -> Node3D:
	var ps := _scene(path)
	if ps == null:
		return null
	var holder := Node3D.new()
	parent.add_child(holder)
	var m := ps.instantiate() as Node3D
	holder.add_child(m)
	var box := _aabb(m)
	if box.size == Vector3.ZERO:
		return holder
	var s := size / (box.size.y if by_height else maxf(box.size.x, maxf(box.size.y, box.size.z)))
	m.scale = Vector3.ONE * s
	m.position = -Vector3(box.get_center().x, box.position.y, box.get_center().z) * s
	_near_only(holder)
	return holder


static func _bunk_posts(cabin: Node3D, at: Vector3, yaw: float, raise: float) -> void:
	var basis := Basis(Vector3.UP, yaw)
	var mat := _mat(Color(0.75, 0.76, 0.78), 0.25, 0.85)
	var hw := 0.84 * S - 0.04
	var hl := 1.26 * S - 0.04
	for c: Vector2 in [Vector2(-hw, -hl), Vector2(hw, -hl), Vector2(-hw, hl), Vector2(hw, hl)]:
		var post := MeshInstance3D.new()
		var cm := CylinderMesh.new()
		cm.top_radius = BUNK_POST
		cm.bottom_radius = BUNK_POST
		cm.height = raise + 0.1
		cm.radial_segments = 10
		post.mesh = cm
		post.material_override = mat
		cabin.add_child(post)
		post.position = at + basis * Vector3(c.x, 0.0, c.y) + Vector3.UP * (raise + 0.1) * 0.5
		post.visibility_range_end = DRAW_RANGE


## Kirk's divider has an intercom on each side (Glen, 3 Nov): the red TOS wall intercom on both faces of its shelf.
static func _divider_intercoms(cabin: Node3D, at: Vector3, yaw: float, half_w: float) -> void:
	var basis := Basis(Vector3.UP, yaw)
	for side: float in [-1.0, 1.0]:
		var ic := WallIntercom.make(0.20)
		if ic == null:
			return
		cabin.add_child(ic)
		# on the shelf's side face, toward the head end (the divider's -Z), at sitting-up-in-bed height
		ic.position = at + basis * Vector3(side * (half_w + 0.002), 0.62, -0.55)
		var out := basis * Vector3(side, 0.0, 0.0)
		ic.rotation.y = atan2(out.x, out.z)
		_near_only(ic)


# --- bathrooms -------------------------------------------------------------------------------------------------------

static func _bathrooms(root: Node3D, f: Dictionary) -> void:
	var fit: Dictionary = f.get("bath_fittings", {})
	for b in fit:
		var bath := Node3D.new()
		bath.name = "Bathroom_" + String(b)
		root.add_child(bath)
		for it in fit[b]:
			var p: Array = it
			var path := BATH_DIR + String(p[0]) + ".glb"
			_prop(bath, path, Vector3(float(p[1]), float(p[4]), float(p[2])), deg_to_rad(float(p[3])), Vector3.ONE)


# --- helpers ---------------------------------------------------------------------------------------------------------

static func _v2(a) -> Vector2:
	return Vector2(float(a[0]), float(a[1]))


static func _scene(path: String) -> PackedScene:
	if not _scenes.has(path):
		_scenes[path] = load(path) if ResourceLoader.exists(path) else null
	return _scenes[path]


static func _near_only(n: Node) -> void:
	for c in n.find_children("*", "GeometryInstance3D", true, false):
		var g := c as GeometryInstance3D
		g.visibility_range_end = DRAW_RANGE
		g.visibility_range_end_margin = 1.0
		g.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_SELF
		g.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


static func _aabb(m: Node3D) -> AABB:
	var box := AABB()
	var first := true
	for c in m.find_children("*", "MeshInstance3D", true, false):
		var mi := c as MeshInstance3D
		if mi.mesh == null:
			continue
		var t := Transform3D.IDENTITY
		var w: Node = mi
		while w != null and w != m:
			if w is Node3D:
				t = (w as Node3D).transform * t
			w = w.get_parent()
		var a := t * mi.get_aabb()
		box = a if first else box.merge(a)
		first = false
	return box


static func _box(size: Vector3, mat: Material) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	mi.material_override = mat
	return mi


static func _mat(col: Color, rough: float, metal: float) -> StandardMaterial3D:
	var k := "%s|%.2f|%.2f" % [col.to_html(), rough, metal]
	if not _mats.has(k):
		var m := StandardMaterial3D.new()
		m.albedo_color = col
		m.roughness = rough
		m.metallic = metal
		_mats[k] = m
	return _mats[k]


static func _picture_mat(path: String) -> StandardMaterial3D:
	if not _mats.has(path):
		var m := StandardMaterial3D.new()
		m.roughness = 0.35
		m.metallic = 0.3
		if ResourceLoader.exists(path):
			m.albedo_texture = load(path)
		else:
			m.albedo_color = Color(0.55, 0.62, 0.78)
		_mats[path] = m
	return _mats[path]
