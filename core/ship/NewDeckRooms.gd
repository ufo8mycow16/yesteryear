class_name NewDeckRooms
extends RefCounted
## REV 813 - the new Deck 7's rooms kitted out from our old Deck 7 (Glen, 3 Nov: "Do the chapel, the briefing room, the
## computer core, engineering, and the transporter rooms as one job ... use the original [pads] ... don't forget to label
## everything outside it ... and sick bay as well"; the workflow agreed with him: Joseph's walls stay where he drew them,
## each room gets the real pieces of our old room, as the crew cabins got Kirk's furniture).
##
## Worked out offline (tools/new_deck7/room_pieces.py cuts the pieces out of aedeck7.glb into
## assets/models/props/deck7_rooms/; tools/new_deck7/room_dressing.py places them -> deck7_fj/rooms_fit.json); here
## they are only put in place:
##  - PIECES: the transporter chambers (the original pads and lit panels), consoles and scanners in all four transporter
##    rooms; engineering's dilithium chamber, its panelled console walls and the big grille in the back wall; the five
##    computer banks in the computer core; diagnostic beds, Dr McCoy's desk and the lab benches in Joseph's medical wing;
##    the briefing room table (with Glen's Burke chairs round it); Giotto's desk, the monitor bank and the overview
##    screen in the security office, a bench in each of the brig's nine cells (a FORCE FIELD across every cell door),
##    the old armoury's phaser racks and rifle rack in the small arms vault (REV 815); and Joseph's 45 CARGO HOLDS filled from the old
##    Storage Bay 2 (crates, some stacked two high, the pipe rack, the barrel store - Cargo Bay 2 gets both). The old
##    deck's pictures, upgraded by HdTextures.
##  - the CHAPEL, built like the old one (ChapelDressing - "Balance of Terror"): platform, lectern, red runner, benches,
##    Glen's altar backdrop on the front wall;
##  - a SIGN beside every door of these rooms, on the corridor side.
## Pieces draw within DRAW_RANGE of the camera (an older PC can't draw every room at once; the walls hide them anyway).

const FIT := "res://assets/models/maps/deck7_fj/rooms_fit.json"
const PIECE_DIR := "res://assets/models/props/deck7_rooms/"
const CHAIR := "res://assets/models/props/tos_chair/tos_chair.glb"
const CHAPEL_BACKDROP := "res://assets/signs/chapel_backdrop.png"
## A sign's own picture where one was made for the old deck; the rest are lettered plates.
const SIGN_PICTURES := {"CHAPEL": "res://assets/signs/chapel_plate.png",
	"COMPUTER CORE": "res://assets/signs/computer_core.png"}

const S := 0.8                  # the old deck's pieces at the ship's size (room_dressing.py S)
const SY := 2.73 / 3.6          # heights: the old 3.6 m ceiling -> just under this deck's 2.75 m (room_dressing.py SY)
const LIFT := 0.004             # a piece's floor a hair over the deck's (no flicker)
const DRAW_RANGE := 28.0
const SIGN_RANGE := 26.0
const WALK_TOP := 0.62          # upward faces below this (the transporter platform) can be walked on
const CHAIR_H := 1.0
const FIELD_H := 2.1            # a cell's force field, floor to just under the door's lintel

## The chapel (metres, in its own frame: x = along the room away from the front wall, z = across)
const PLATFORM_DEPTH := 1.5
const PLATFORM_H := 0.14
const ROW_GAP := 1.0
const FIRST_ROW := 2.3
const AISLE := 1.1
const BENCH_LEN := 1.9
const SEAT_H := 0.42
const SEAT_DEPTH := 0.40
const BACKDROP_W := 2.5
const BACKDROP_Y := 1.55

static var _scenes := {}
static var NONE := PackedVector3Array()       # faces nobody collides with
static var _mats := {}


## Returns the room doors (MapDoors.Door), for the room to switch on with the cabins' (NewDeck7._activate_cabin_doors).
static func build(room: Node3D) -> Array:
	if not FileAccess.file_exists(FIT):
		push_warning("NewDeckRooms: no rooms_fit.json - run tools/new_deck7/build.sh")
		return []
	var fit: Variant = JSON.parse_string(FileAccess.get_file_as_string(FIT))
	if not (fit is Dictionary):
		return []
	var f := fit as Dictionary
	NONE = PackedVector3Array()
	var root := Node3D.new()
	root.name = "DeckRooms"
	room.add_child(root)
	var walk := PackedVector3Array()
	var solid := PackedVector3Array()
	_pieces(root, f, walk, solid)
	_chairs(root, f)
	_chapel(root, f, solid)
	_fields(root, f, solid)
	_signs(root, f)
	_body(room, "Floor_deck7_rooms", walk)
	_body(room, "PROP_deck7_rooms", solid)
	# REV 816 (Glen: "Every doorway should have red sliding doors"): a red sliding door in every room doorway, built
	# and worked exactly like the cabins' (room_dressing.py room_doors -> rooms_fit "doors")
	var doors := NewDeckCabins._doors(root, {"doors": f.get("doors", [])})
	for dd in doors:                       # ~250 doors on the deck: only draw the near ones (older PCs)
		for l in (dd as MapDoors.Door).leaves:
			var leaf := l[0] as MeshInstance3D
			if leaf != null:
				leaf.visibility_range_end = DRAW_RANGE
				leaf.visibility_range_end_margin = 1.0
	return doors


# --- the old deck's pieces ------------------------------------------------------------------------------------------

static func _pieces(root: Node3D, f: Dictionary, walk: PackedVector3Array, solid: PackedVector3Array) -> void:
	var rooms := {}
	for it in f.get("pieces", []):
		var p: Array = it
		var ps := _scene(PIECE_DIR + String(p[0]) + ".glb")
		if ps == null:
			continue
		var rname := String(p[7])
		if not rooms.has(rname):
			var h := Node3D.new()
			h.name = rname.replace(" ", "_").replace("-", "_")
			root.add_child(h)
			rooms[rname] = h
		var m := ps.instantiate() as Node3D
		m.name = String(p[0])
		(rooms[rname] as Node3D).add_child(m)
		var up := float(p[8]) if p.size() > 8 else 0.0     # stacked (a crate on a crate)
		m.position = Vector3(float(p[1]), LIFT + up, float(p[2]))
		m.rotation.y = deg_to_rad(float(p[3]))
		m.scale = Vector3(S * float(p[4]), SY * float(p[5]), S * float(p[6]))
		HdTextures.apply(m)
		for c in m.find_children("*", "MeshInstance3D", true, false):
			var mi := c as MeshInstance3D
			if mi.mesh == null:
				continue
			for s in mi.mesh.get_surface_count():
				var src := mi.mesh.surface_get_material(s) as StandardMaterial3D
				if src != null and src.vertex_color_use_as_albedo:
					var mat := src.duplicate() as StandardMaterial3D
					mat.vertex_color_use_as_albedo = false       # the old map's baked shading - wrong here
					mi.set_surface_override_material(s, mat)
			_collect(m, mi, walk, solid)
		_near_only(m, DRAW_RANGE)


## A piece's triangles into the deck's collision: low upward faces walkable, the rest solid.
static func _collect(top: Node3D, mi: MeshInstance3D, walk: PackedVector3Array, solid: PackedVector3Array) -> void:
	var xf := top.transform
	var w: Node = mi
	var local := Transform3D.IDENTITY
	while w != null and w != top:
		if w is Node3D:
			local = (w as Node3D).transform * local
		w = w.get_parent()
	xf = xf * local
	var tri := mi.mesh.get_faces()
	for k in range(0, tri.size(), 3):
		var a := xf * tri[k]
		var b := xf * tri[k + 1]
		var c := xf * tri[k + 2]
		var top_y := maxf(a.y, maxf(b.y, c.y))
		if top_y < 0.03:
			continue                                   # the old floor under a piece - the deck's own floor is walked on
		var n := (b - a).cross(c - a)
		var up := n.length() > 1e-8 and absf(n.normalized().y) > 0.7
		if up and top_y < WALK_TOP:
			walk.append(a)
			walk.append(b)
			walk.append(c)
		else:
			solid.append(a)
			solid.append(b)
			solid.append(c)


static func _body(room: Node3D, body_name: String, faces: PackedVector3Array) -> void:
	if faces.is_empty():
		return
	var shape := ConcavePolygonShape3D.new()
	shape.set_faces(faces)
	shape.backface_collision = true
	var body := StaticBody3D.new()
	body.name = body_name
	var cs := CollisionShape3D.new()
	cs.shape = shape
	body.add_child(cs)
	room.add_child(body)


## Glen's Burke chairs round the briefing room table (where the old room's chairs stood), facing it.
static func _chairs(root: Node3D, f: Dictionary) -> void:
	var ps := _scene(CHAIR)
	if ps == null:
		return
	for it in f.get("chairs", []):
		var p: Array = it
		var holder := Node3D.new()
		holder.name = "BriefingChair"
		root.add_child(holder)
		var m := ps.instantiate() as Node3D
		holder.add_child(m)
		var box := _aabb(m)
		if box.size.y > 0.0:
			var s := CHAIR_H / box.size.y
			m.scale = Vector3.ONE * s
			m.position = -Vector3(box.get_center().x, box.position.y, box.get_center().z) * s
		holder.position = Vector3(float(p[0]), 0.0, float(p[1]))
		holder.rotation.y = deg_to_rad(float(p[2]))
		_near_only(holder, DRAW_RANGE)


# --- the chapel -----------------------------------------------------------------------------------------------------

## As the old one (ChapelDressing, Glen's "Balance of Terror" still): a pale raised platform across the front with the
## tall angled lectern off to one side, a red runner up the aisle, low black padded benches on chrome legs in rows facing
## the front, and Glen's altar backdrop glowing on the front wall.
static func _chapel(root: Node3D, f: Dictionary, solid: PackedVector3Array) -> void:
	var ch: Dictionary = f.get("chapel", {})
	if ch.is_empty():
		return
	var front := Vector3(float(ch["front"][0]), 0.0, float(ch["front"][1]))
	var fwd := Vector3(float(ch["fwd"][0]), 0.0, float(ch["fwd"][1])).normalized()
	var width := float(ch["width"])
	var length := float(ch["length"])
	var c := Node3D.new()
	c.name = "Chapel"
	root.add_child(c)
	c.position = front
	c.rotation.y = atan2(fwd.x, fwd.z) - PI * 0.5     # the frame's +x runs into the room, away from the front wall
	var pale := _mat(Color(0.80, 0.81, 0.83), 0.45, 0.0)
	var edge := _mat(Color(0.90, 0.91, 0.93), 0.35, 0.0)
	var black := _mat(Color(0.05, 0.05, 0.06), 0.28, 0.0)
	var chrome := _mat(Color(0.82, 0.83, 0.86), 0.18, 1.0)
	var red := _mat(Color(0.55, 0.06, 0.05), 0.9, 0.0)
	var plat_w := minf(5.0, width - 1.4)
	_cbox(c, Vector3(PLATFORM_DEPTH * 0.5 + 0.08, PLATFORM_H * 0.5, 0.0), Vector3(PLATFORM_DEPTH, PLATFORM_H, plat_w), pale, solid)
	_cbox(c, Vector3(PLATFORM_DEPTH + 0.08, PLATFORM_H - 0.012, 0.0), Vector3(0.05, 0.024, plat_w), edge, NONE)
	var back := length - 1.4
	_cbox(c, Vector3((PLATFORM_DEPTH + 0.08 + back) * 0.5, 0.006, 0.0), Vector3(back - PLATFORM_DEPTH - 0.08, 0.012, AISLE * 0.8), red, NONE)
	# the lectern, off to one side as in the episode: a pale slab leaning back, a sloping reading board
	var base := Vector3(1.05, PLATFORM_H, -plat_w * 0.22)
	_cbox(c, base + Vector3(0.0, 0.02, 0.0), Vector3(0.40, 0.04, 0.46), edge, solid)
	var lean := deg_to_rad(12.0)
	var h := 1.05
	_cbox(c, base + Vector3(-sin(lean) * h * 0.5, 0.04 + cos(lean) * h * 0.5, 0.0), Vector3(0.10, h, 0.42), pale, solid,
		Vector3(0.0, 0.0, lean))
	_cbox(c, base + Vector3(-sin(lean) * h + 0.10, 0.04 + cos(lean) * h, 0.0), Vector3(0.34, 0.03, 0.52), edge, NONE,
		Vector3(0.0, 0.0, deg_to_rad(-22.0)))
	# benches, each side of the aisle, as many rows as the room takes (leaving the door end clear)
	var blen := minf(BENCH_LEN, (width - AISLE) * 0.5 - 0.5)
	var x := FIRST_ROW
	while x + SEAT_DEPTH < length - 1.8:
		for side in [-1.0, 1.0]:
			var mid := Vector3(x + SEAT_DEPTH * 0.5, 0.0, float(side) * (AISLE * 0.5 + blen * 0.5))
			_cbox(c, mid + Vector3(0.0, SEAT_H - 0.05, 0.0), Vector3(SEAT_DEPTH, 0.10, blen), black, solid)
			for e in [-1.0, 1.0]:
				var lz: float = float(e) * (blen * 0.5 - 0.22)
				_cbox(c, mid + Vector3(0.0, (SEAT_H - 0.10) * 0.5, lz), Vector3(0.30, SEAT_H - 0.10, 0.05), chrome, NONE)
				_cbox(c, mid + Vector3(0.0, 0.01, lz), Vector3(0.36, 0.02, 0.10), chrome, NONE)
		x += ROW_GAP
	# Glen's altar backdrop on the front wall, glowing like the old one (ModelRoom.WALL_PICTURES)
	if ResourceLoader.exists(CHAPEL_BACKDROP):
		var tex := load(CHAPEL_BACKDROP) as Texture2D
		var q := MeshInstance3D.new()
		var qm := QuadMesh.new()
		var hgt := BACKDROP_W * float(tex.get_height()) / maxf(1.0, float(tex.get_width()))
		qm.size = Vector2(BACKDROP_W, hgt)
		q.mesh = qm
		var m := StandardMaterial3D.new()
		m.albedo_texture = tex
		m.emission_enabled = true
		m.emission_texture = tex
		m.emission_energy_multiplier = 0.6
		m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
		q.material_override = m
		c.add_child(q)
		q.position = Vector3(0.085, maxf(BACKDROP_Y, hgt * 0.5 + 0.35), 0.0)
		q.rotation.y = PI * 0.5                      # facing +x, into the room
	_near_only(c, DRAW_RANGE)


## A box in the chapel's frame; its faces go into `solid` (pass NONE for a box people walk over or through).
static func _cbox(parent: Node3D, pos: Vector3, size: Vector3, mat: Material, solid: PackedVector3Array,
		rot := Vector3.ZERO) -> void:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	mi.material_override = mat
	mi.position = pos
	mi.rotation = rot
	parent.add_child(mi)
	var xf := parent.transform * mi.transform
	for v in bm.get_faces():
		solid.append(xf * v)


# --- the brig ---

## A detention force field across every cell's doorway (ForceField, as the old brig's), switched on. It is solid.
static func _fields(root: Node3D, f: Dictionary, solid: PackedVector3Array) -> void:
	var holder := Node3D.new()
	holder.name = "BrigFields"
	root.add_child(holder)
	for it in f.get("fields", []):
		var p: Array = it
		var w := float(p[4])
		var field := ForceField.make(w - 0.06, FIELD_H)
		holder.add_child(field)
		field.position = Vector3(float(p[0]), FIELD_H * 0.5, float(p[1]))
		field.rotation.y = atan2(-float(p[3]), float(p[2]))      # its width (local x) along the doorway
		# the sheet blocks the way: a thin slab of collision across the doorway
		var xf := root.transform * holder.transform * field.transform
		var bm := BoxMesh.new()
		bm.size = Vector3(w, FIELD_H, 0.06)
		for v in bm.get_faces():
			solid.append(xf * v)


# --- signs ----------------------------------------------------------------------------------------------------------

## TOS style: a brushed grey plate with a black plaque and the room's name in silver capitals (or the room's own
## picture where the old deck had one). Front = +Z, facing the corridor.
static func _signs(root: Node3D, f: Dictionary) -> void:
	var holder := Node3D.new()
	holder.name = "RoomSigns"
	root.add_child(holder)
	for it in f.get("signs", []):
		var p: Array = it
		var text := String(p[0])
		var sign := _picture_sign(String(SIGN_PICTURES[text])) if SIGN_PICTURES.has(text) else _plate(text)
		sign.name = "Sign_" + text.replace(" ", "_")
		holder.add_child(sign)
		sign.position = Vector3(float(p[1]), float(p[2]), float(p[3]))
		sign.rotation.y = deg_to_rad(float(p[4]))
		_near_only(sign, SIGN_RANGE)


static func _plate(text: String) -> Node3D:
	var n := Node3D.new()
	var w := clampf(0.034 * float(text.length()) + 0.08, 0.30, 0.78)
	var body := _box(Vector3(w + 0.04, 0.13, 0.008), _mat(Color(0.62, 0.63, 0.65), 0.45, 0.5))
	body.position = Vector3(0.0, 0.0, 0.004)
	n.add_child(body)
	var plaque := _box(Vector3(w, 0.09, 0.01), _mat(Color(0.015, 0.015, 0.02), 0.12, 0.2))
	plaque.position = Vector3(0.0, 0.0, 0.012)
	n.add_child(plaque)
	var l := Label3D.new()
	l.text = text
	l.position = Vector3(0.0, 0.0, 0.0185)
	l.pixel_size = 0.0016
	l.font_size = 32
	l.modulate = Color(0.86, 0.88, 0.9)
	l.outline_size = 0
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.shaded = false
	l.double_sided = false
	n.add_child(l)
	return n


static func _picture_sign(path: String) -> Node3D:
	var n := Node3D.new()
	if not ResourceLoader.exists(path):
		return _plate("")
	var tex := load(path) as Texture2D
	var q := MeshInstance3D.new()
	var qm := QuadMesh.new()
	var w := 0.62
	qm.size = Vector2(w, w * float(tex.get_height()) / maxf(1.0, float(tex.get_width())))
	q.mesh = qm
	var m := StandardMaterial3D.new()
	m.albedo_texture = tex
	m.roughness = 0.4
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	q.material_override = m
	q.position = Vector3(0.0, 0.0, 0.006)
	n.add_child(q)
	return n


# --- helpers --------------------------------------------------------------------------------------------------------

static func _scene(path: String) -> PackedScene:
	if not _scenes.has(path):
		_scenes[path] = load(path) if ResourceLoader.exists(path) else null
	return _scenes[path]


static func _near_only(n: Node, range_m: float) -> void:
	for c in n.find_children("*", "GeometryInstance3D", true, false):
		var g := c as GeometryInstance3D
		g.visibility_range_end = range_m
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
