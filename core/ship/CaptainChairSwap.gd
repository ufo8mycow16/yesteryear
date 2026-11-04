class_name CaptainChairSwap
extends RefCounted
## REV 783 (Glen: "keep replacing models in the game with actual 3D models so everything looks a lot newer"):
## the bridge's old Quake captain's chair (aedeck1's PROP_2_aehelm_captainchair, four meshes) is swapped for
## Captain Kirk's chair made from Glen's print kit (assets/models/props/captain_chair/captain_chair.glb, built by
## tools/props/captain_chair/build.sh - Jeff's Printables kit, CC BY 4.0, credited in docs/CREDITS.md).
##
## Same trick as ChairSwap: the old meshes are NOT deleted or renamed - they just draw nothing - so everything that
## finds the chair by name keeps working exactly as before (EnterpriseBridge/teasers' _props_centre("captainchair"),
## Kirk/Scotty seating, SwivelSeat.chair_meshes). The new chair is a CHILD of the old chair's biggest mesh, so when
## SwivelSeat turns the old meshes (Kirk turning to talk) the new chair turns with them.
##
## Placement, all measured from the old chair's own triangles: its post stands on the swivel axis (the average of
## the old meshes' centres - the same point _props_centre / SwivelSeat use), on the old chair's floor, facing away
## from the top of its back, scaled so the new SEAT is at the old seat's height (everyone who sits in it sits as
## before).

const MODEL := "res://assets/models/props/captain_chair/captain_chair.glb"
const TAG := "captainchair"
const SEAT_FRACTION := 0.59    # the old chair's cushion top as a share of its full height (measured from aedeck1)
const PLINTH_MODEL := "res://assets/models/props/captain_chair/captain_chair_plinth.glb"
const NEW_SEAT := 0.075148     # the new model's cushion top over the floor (m, parts.json "seat_top_mm" / 1000)
const PLINTH := 0.020          # REV 786: the show's plinth (m, "plinth_mm" / 1000) - Kirk's boots rest on top of it
const PLINTH_BOX := [-0.05214, 0.05214, -0.05694, 0.06385]   # its footprint, kit mm / 1000: x0 x1, y0 y1 (front -y)
const POST_Y := 0.017956       # the post's kit y (the model's origin), to put the box in model space
const RAISE_META := "captain_chair_raise"
const DONE_META := "captain_chair_done"
const GREY_GLOW := 0.06        # grey parts' own colour as a floor, so the chair never goes black in a dim corner
const GLOW_PARTS := ["Shell", "Console", "Plinth", "Post"]

static var _model: PackedScene = null
static var _plinth: PackedScene = null


## REV 786: how much higher than the floor anyone sitting in Kirk's chair sits (world metres) - their boots rest on
## the plinth. 0 when the room has no new chair. Seating code adds this to the sitter's height.
static func raise_of(room: Node) -> float:
	if room == null:
		return 0.0
	if not room.has_meta(DONE_META) and room is Node3D:
		run(room as Node3D)     # seating happens in build_room, before ModelRoom's build_shared swaps the chairs
	return float(room.get_meta(RAISE_META, 0.0))


static func run(room: Node3D) -> void:
	if room.has_meta(DONE_META):
		return               # once per room
	room.set_meta(DONE_META, true)
	if not ResourceLoader.exists(MODEL):
		return
	var meshes: Array[MeshInstance3D] = []
	for m in room.find_children("*", "MeshInstance3D", true, false):
		var mi := m as MeshInstance3D
		if mi.mesh != null and mi.skin == null and String(mi.name).to_lower().contains(TAG):
			meshes.append(mi)
	if meshes.is_empty():
		return
	if _model == null:
		_model = load(MODEL)
		if _model == null:
			return
	# the biggest old piece carries the new chair (all four turn together on the swivel)
	var host := meshes[0]
	for mi in meshes:
		if mi.get_aabb().get_volume() > host.get_aabb().get_volume():
			host = mi
	var inv := host.global_transform.affine_inverse()
	# every old point, in the host's own space
	var pts := PackedVector3Array()
	var centre := Vector3.ZERO
	for mi in meshes:
		var to_host := inv * mi.global_transform
		centre += to_host * mi.get_aabb().get_center()
		for s in mi.mesh.get_surface_count():
			for p in (mi.mesh.surface_get_arrays(s)[Mesh.ARRAY_VERTEX] as PackedVector3Array):
				pts.append(to_host * p)
	centre /= float(meshes.size())
	var y0 := INF
	var y1 := -INF
	for p in pts:
		y0 = minf(y0, p.y)
		y1 = maxf(y1, p.y)
	var h := y1 - y0
	if h < 0.05:
		return
	var top := Vector2.ZERO
	var nt := 0
	for p in pts:
		if p.y > y0 + 0.9 * h:
			top += Vector2(p.x, p.z)
			nt += 1
	var axis := Vector2(centre.x, centre.z)
	var back := top / float(maxi(nt, 1)) - axis
	if nt == 0 or back.length() < 0.01:
		return
	var f := -back.normalized()                     # the way the chair faces
	# REV 786: the seat stays as high above the sitter's boots (now on the plinth) as the old seat was above the floor
	var k := SEAT_FRACTION * h / (NEW_SEAT - PLINTH)
	var holder := Node3D.new()
	holder.name = "KirkChairNew"                     # never "captainchair" (the code finds the OLD chair by that)
	var c := _model.instantiate() as Node3D
	holder.add_child(c)
	host.add_child(holder)
	holder.transform = Transform3D(Basis(Vector3.UP, atan2(f.x, f.y)).scaled(Vector3.ONE * k), Vector3(axis.x, y0, axis.y))
	_glow(c)
	# the plinth: its own model, on the old chair's PARENT (it doesn't turn when the chair swivels)
	if _plinth == null and ResourceLoader.exists(PLINTH_MODEL):
		_plinth = load(PLINTH_MODEL)
	if _plinth != null:
		var ph := Node3D.new()
		ph.name = "KirkChairPlinth"
		var pc := _plinth.instantiate() as Node3D
		ph.add_child(pc)
		host.get_parent().add_child(ph)
		ph.global_transform = holder.global_transform
		_glow(pc)
		# (not solid yet: a box here would trap whoever sits in the chair - Scotty in Episode 3 sits from inside its
		# footprint. PLINTH_BOX is kept for when it gets one, with a collision exception for the sitter.)
	room.set_meta(RAISE_META, (holder.global_transform.basis * Vector3(0.0, PLINTH, 0.0)).length())
	var hide := ChairSwap.hide_material()
	for mi in meshes:
		for s in mi.mesh.get_surface_count():
			mi.set_surface_override_material(s, hide)


static func _glow(c: Node3D) -> void:
	for m in c.find_children("*", "MeshInstance3D", true, false):
		var mi := m as MeshInstance3D
		if mi.mesh == null:
			continue
		for s in mi.mesh.get_surface_count():
			var src := mi.mesh.surface_get_material(s) as StandardMaterial3D
			if src == null or not (String(src.resource_name) in GLOW_PARTS):
				continue
			var mat := src.duplicate() as StandardMaterial3D
			mat.emission_enabled = true
			mat.emission = src.albedo_color
			mat.emission_energy_multiplier = GREY_GLOW
			mi.set_surface_override_material(s, mat)
