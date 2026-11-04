class_name MapDoors
extends RefCounted
## REV 377 (Glen: "can you make doors open as you enter them? We don't have that yet" - for the whole ship).
##
## The Elite Force maps keep every door leaf on the ship in one mesh per door picture (all the red doors
## together, all the yellow ones...), standing shut. split() cuts those meshes into separate doors, before the
## map's collision is made (so each leaf gets its own solid body that moves with it). activate() then, once
## the collision exists, gives every real door a sensor: anyone walking up (the player, the party, crew) and it
## swishes open, the two leaves sliding apart into the wall; it closes behind them.
##
## A door only opens if there is floor on both sides of it (a "fake" door painted on an outside wall, like
## Deck 5's, stays shut - nobody opens a door onto empty space), and never if the room locks it
## (ModelRoom.LOCKED_DOORS / lock_door) - that is how the story keeps you out of somewhere.

## The door-leaf pictures (Elite Force TOS pack). Frames, lights and buttons are left alone.
const LEAF_MATERIALS := ["edoorred", "edooryel", "grey_door", "paleblue_door", "yellow_door", "red_door", "engred_door", "shuttledoor"]

const OPEN_TIME := 0.45       # seconds to slide open / shut
const CLOSE_AFTER := 1.2      # seconds after the last person leaves the sensor
const SENSOR_DEPTH := 1.6     # metres in front of and behind the door that open it
const LEAF_OVERLAP := 0.04    # metres of each leaf left showing in the frame when open

## A door leaf pair is at least this tall and this wide (metres, before the map's own scale), and thin.
const MIN_HEIGHT := 1.5
const MIN_WIDTH := 0.6
const MAX_THICK := 0.35


class Door extends RefCounted:
	var leaves: Array = []          # [MeshInstance3D, closed local origin, open local origin]
	var centre := Vector3.ZERO      # world, at the floor
	var normal := Vector3.ZERO      # world, flat
	var width := 0.0                # world metres
	var height := 0.0
	var sensor: Area3D = null
	var open := false
	var inside := 0
	var tween: Tween = null
	var close_timer := 0.0
	var locked := false


## Splits the door meshes under `deck` into per-door leaves. Returns the doors (not yet active).
static func split(deck: Node3D) -> Array:
	var doors: Array = []
	for m in deck.find_children("*", "MeshInstance3D", true, false):
		var mi := m as MeshInstance3D
		if mi.mesh == null or mi.skin != null or not _is_leaf_mesh(mi):
			continue
		doors.append_array(_split_mesh(mi))
	return doors


static func _is_leaf_mesh(mi: MeshInstance3D) -> bool:
	var n := String(mi.name).to_lower()
	for s in mi.mesh.get_surface_count():
		var mat: Material = mi.get_surface_override_material(s)
		if mat == null:
			mat = mi.mesh.surface_get_material(s)
		if mat != null:
			n += " " + String(mat.resource_name).to_lower()
	for k in LEAF_MATERIALS:
		if n.contains(k):
			return true
	return false


static func _split_mesh(mi: MeshInstance3D) -> Array:
	var mesh := mi.mesh
	# 1. every triangle, with the surface it came from
	var tris: Array = []        # [surface, i0, i1, i2]
	var arrays: Array = []
	for s in mesh.get_surface_count():
		if mesh.surface_get_primitive_type(s) != Mesh.PRIMITIVE_TRIANGLES:
			return []
		var a: Array = mesh.surface_get_arrays(s)
		arrays.append(a)
		var idx: PackedInt32Array = a[Mesh.ARRAY_INDEX] if a[Mesh.ARRAY_INDEX] != null else PackedInt32Array()
		var nv: int = (a[Mesh.ARRAY_VERTEX] as PackedVector3Array).size()
		if idx.is_empty():
			idx.resize(nv)
			for i in nv:
				idx[i] = i
		for t in range(0, idx.size() - 2, 3):
			tris.append([s, idx[t], idx[t + 1], idx[t + 2]])
	if tris.is_empty():
		return []
	# 2. group triangles that touch (shared corners, to 5 cm)
	var parent := PackedInt32Array()
	parent.resize(tris.size())
	for i in tris.size():
		parent[i] = i
	var owner := {}
	for i in tris.size():
		var t: Array = tris[i]
		var vs: PackedVector3Array = arrays[t[0]][Mesh.ARRAY_VERTEX]
		for k in [1, 2, 3]:
			var p: Vector3 = vs[t[k]]
			var key := Vector3i(roundi(p.x * 20.0), roundi(p.y * 20.0), roundi(p.z * 20.0))
			if owner.has(key):
				_union(parent, i, int(owner[key]))
			else:
				owner[key] = i
	var groups := {}
	for i in tris.size():
		var r := _find(parent, i)
		if not groups.has(r):
			groups[r] = []
		(groups[r] as Array).append(i)
	# 3. each group's box; merge groups whose boxes touch (the two leaves of one door often share no corner)
	var boxes: Array = []
	for r in groups:
		var box := AABB()
		var first := true
		for i in groups[r]:
			var t: Array = tris[i]
			var vs: PackedVector3Array = arrays[t[0]][Mesh.ARRAY_VERTEX]
			for k in [1, 2, 3]:
				var p: Vector3 = vs[t[k]]
				if first:
					box = AABB(p, Vector3.ZERO)
					first = false
				else:
					box = box.expand(p)
		boxes.append([box, groups[r]])
	var merged := true
	while merged:
		merged = false
		for i in boxes.size():
			for j in range(i + 1, boxes.size()):
				var bi: AABB = boxes[i][0]
				var bj: AABB = boxes[j][0]
				if bi.grow(0.06).intersects(bj) and absf(bi.get_center().y - bj.get_center().y) < 0.3:
					boxes[i] = [bi.merge(bj), (boxes[i][1] as Array) + (boxes[j][1] as Array)]
					boxes.remove_at(j)
					merged = true
					break
			if merged:
				break
	# 4. groups shaped like a door become doors; the rest stay in the original mesh
	var keep: Array = []
	var doors: Array = []
	for entry in boxes:
		var box: AABB = entry[0]
		var w := maxf(box.size.x, box.size.z)
		var th := minf(box.size.x, box.size.z)
		if box.size.y < MIN_HEIGHT * 0.8 or w < MIN_WIDTH * 0.8 or th > MAX_THICK:
			keep.append_array(entry[1])
			continue
		doors.append(_make_door(mi, arrays, tris, entry[1], box))
	# rebuild the original from what's left (or hide it if nothing is)
	if doors.is_empty():
		return []
	var rest := _build_mesh(mesh, arrays, tris, keep)
	if rest == null:
		mi.visible = false
		mi.mesh = ArrayMesh.new()
	else:
		mi.mesh = rest
	return doors


static func _make_door(mi: MeshInstance3D, arrays: Array, tris: Array, ids: Array, box: AABB) -> Door:
	var d := Door.new()
	var c := box.get_center()
	var along_x := box.size.x >= box.size.z            # the door's width runs along mesh-local x (else z)
	var halves := [[], []]
	var w := box.size.x if along_x else box.size.z
	# REV 394 (Glen: "this door opens... diagonally"): a door that is ONE panel (its triangles run across the
	# middle - a plain quad is two triangles split corner to corner) can't be cut into two leaves by triangle;
	# it slides open whole, to one side, instead of coming apart along the diagonal.
	var single := false
	for i in ids:
		var t: Array = tris[i]
		var vs: PackedVector3Array = arrays[t[0]][Mesh.ARRAY_VERTEX]
		var lo := INF
		var hi := -INF
		for k in [1, 2, 3]:
			var u: float = vs[t[k]].x if along_x else vs[t[k]].z
			lo = minf(lo, u)
			hi = maxf(hi, u)
		var mid_u := c.x if along_x else c.z
		if lo < mid_u - w * 0.1 and hi > mid_u + w * 0.1:
			single = true
			break
	for i in ids:
		var t: Array = tris[i]
		var vs: PackedVector3Array = arrays[t[0]][Mesh.ARRAY_VERTEX]
		var mid: Vector3 = (vs[t[1]] + vs[t[2]] + vs[t[3]]) / 3.0
		var side := (mid.x if along_x else mid.z) - (c.x if along_x else c.z)
		halves[1 if single else (0 if side < 0.0 else 1)].append(i)
	var slide := (w - LEAF_OVERLAP * 2.0) if single else (w * 0.5 - LEAF_OVERLAP)
	for h in 2:
		if (halves[h] as Array).is_empty():
			continue
		var leaf_mesh := _build_mesh(mi.mesh, arrays, tris, halves[h])
		if leaf_mesh == null:
			continue
		var leaf := MeshInstance3D.new()
		leaf.name = "DoorLeaf"
		leaf.mesh = leaf_mesh
		for s in leaf_mesh.get_surface_count():
			var src_s := int(leaf_mesh.surface_get_name(s)) if leaf_mesh.surface_get_name(s).is_valid_int() else s
			var mat: Material = mi.get_surface_override_material(src_s) if src_s < mi.get_surface_override_material_count() else null
			if mat != null:
				leaf.set_surface_override_material(s, mat)
		leaf.cast_shadow = mi.cast_shadow
		leaf.gi_mode = mi.gi_mode
		mi.get_parent().add_child(leaf)
		leaf.transform = mi.transform
		var dir := Vector3(-1.0 if h == 0 else 1.0, 0.0, 0.0) if along_x else Vector3(0.0, 0.0, -1.0 if h == 0 else 1.0)
		var closed := leaf.transform.origin
		var opened := closed + mi.transform.basis * (dir * slide)
		d.leaves.append([leaf, closed, opened])
	var gt := mi.global_transform
	d.centre = gt * Vector3(c.x, box.position.y, c.z)
	var n_local := Vector3(0, 0, 1) if along_x else Vector3(1, 0, 0)
	d.normal = (gt.basis * n_local)
	d.normal.y = 0.0
	d.normal = d.normal.normalized()
	d.width = (gt.basis * (Vector3(w, 0, 0) if along_x else Vector3(0, 0, w))).length()
	d.height = (gt.basis * Vector3(0, box.size.y, 0)).length()
	return d


## An ArrayMesh of the given triangles of `src` (same surfaces and materials, only the points they use).
static func _build_mesh(src: Mesh, arrays: Array, tris: Array, ids: Array) -> ArrayMesh:
	if ids.is_empty():
		return null
	var by_surface := {}
	for i in ids:
		var s: int = tris[i][0]
		if not by_surface.has(s):
			by_surface[s] = []
		(by_surface[s] as Array).append(i)
	var out := ArrayMesh.new()
	for s in by_surface:
		var a: Array = arrays[s]
		var remap := {}
		var order: Array = []
		var idx := PackedInt32Array()
		for i in by_surface[s]:
			for k in [1, 2, 3]:
				var o: int = tris[i][k]
				if not remap.has(o):
					remap[o] = order.size()
					order.append(o)
				idx.append(int(remap[o]))
		var na: Array = []
		na.resize(Mesh.ARRAY_MAX)
		for slot in Mesh.ARRAY_MAX:
			if slot == Mesh.ARRAY_INDEX or a[slot] == null:
				continue
			na[slot] = _pick(a[slot], order, slot)
		na[Mesh.ARRAY_INDEX] = idx
		out.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, na)
		out.surface_set_material(out.get_surface_count() - 1, src.surface_get_material(s))
		out.surface_set_name(out.get_surface_count() - 1, str(s))
	return out


## The entries of one vertex array for the kept points (tangents/bones/weights have several numbers per point).
static func _pick(arr, order: Array, slot: int):
	var per := 1
	if slot == Mesh.ARRAY_TANGENT or slot == Mesh.ARRAY_BONES or slot == Mesh.ARRAY_WEIGHTS:
		per = 4
	if arr is PackedVector3Array:
		var o := PackedVector3Array()
		for i in order:
			o.append(arr[i])
		return o
	if arr is PackedVector2Array:
		var o2 := PackedVector2Array()
		for i in order:
			o2.append(arr[i])
		return o2
	if arr is PackedColorArray:
		var oc := PackedColorArray()
		for i in order:
			oc.append(arr[i])
		return oc
	if arr is PackedFloat32Array:
		var of := PackedFloat32Array()
		for i in order:
			for k in per:
				of.append(arr[i * per + k])
		return of
	if arr is PackedInt32Array:
		var oi := PackedInt32Array()
		for i in order:
			for k in per:
				oi.append(arr[i * per + k])
		return oi
	if arr is PackedByteArray:
		var ob := PackedByteArray()
		for i in order:
			for k in per:
				ob.append(arr[i * per + k])
		return ob
	return null


static func _find(p: PackedInt32Array, i: int) -> int:
	while p[i] != i:
		p[i] = p[p[i]]
		i = p[i]
	return i


static func _union(p: PackedInt32Array, a: int, b: int) -> void:
	var ra := _find(p, a)
	var rb := _find(p, b)
	if ra != rb:
		p[ra] = rb


## Gives each real door its sensor. Call once the map's collision exists. `locked` = world points: a door
## within 1.5 m of one stays shut. `room` drives the closing timers (it must call tick(delta)).
static func activate(room: Node3D, doors: Array, locked: Array) -> void:
	var space := room.get_world_3d().direct_space_state
	for dd in doors:
		var d: Door = dd
		if d.leaves.is_empty():
			continue
		for p in locked:
			if Vector2((p as Vector3).x - d.centre.x, (p as Vector3).z - d.centre.z).length() < 1.5:
				d.locked = true
		if d.locked or not (_floor_at(space, room, d, 1.0) and _floor_at(space, room, d, -1.0)):
			d.locked = true
			continue
		var area := Area3D.new()
		area.name = "DoorSensor"
		area.collision_layer = 0
		area.collision_mask = 1 | CharacterBlocker.LAYER
		area.monitorable = false
		var cs := CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size = Vector3(d.width + 0.4, maxf(d.height, 1.8), SENSOR_DEPTH * 2.0)
		cs.shape = box
		area.add_child(cs)
		room.add_child(area)
		area.global_position = d.centre + Vector3.UP * box.size.y * 0.5
		area.rotation.y = atan2(d.normal.x, d.normal.z)
		area.body_entered.connect(func(b: Node3D) -> void: _entered(room, d, b))
		area.body_exited.connect(func(b: Node3D) -> void: _exited(d, b))
		d.sensor = area


## A walker, or a crew member's blocker - not the map, not another door.
static func _counts(b: Node3D) -> bool:
	return b is CharacterBody3D or b is CharacterBlocker


static func _entered(room: Node3D, d: Door, b: Node3D) -> void:
	if not _counts(b) or d.locked:
		return
	d.inside += 1
	d.close_timer = 0.0
	if not d.open:
		_move(room, d, true)


static func _exited(d: Door, b: Node3D) -> void:
	if not _counts(b):
		return
	d.inside = maxi(d.inside - 1, 0)
	if d.inside == 0:
		d.close_timer = CLOSE_AFTER


## Closes doors whose sensors have been empty for CLOSE_AFTER seconds.
static func tick(room: Node3D, doors: Array, delta: float) -> void:
	for dd in doors:
		var d: Door = dd
		if d.open and d.inside == 0 and d.close_timer > 0.0:
			d.close_timer -= delta
			if d.close_timer <= 0.0:
				_move(room, d, false)


static func _move(room: Node3D, d: Door, to_open: bool) -> void:
	d.open = to_open
	if d.tween != null and d.tween.is_valid():
		d.tween.kill()
	d.tween = room.create_tween().set_parallel(true)
	d.tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT if to_open else Tween.EASE_IN_OUT)
	for l in d.leaves:
		var leaf: MeshInstance3D = l[0]
		if is_instance_valid(leaf):
			d.tween.tween_property(leaf, "position", (l[2] if to_open else l[1]) as Vector3, OPEN_TIME)
	var sfx := room.get_node_or_null("/root/SfxManager")
	if sfx != null:
		sfx.call("play", "door")


## REV 758: a story door driven by hand (Pell's cabin, Episode 3): 0 = shut, 1 = fully open, in between = a crack.
## The door should be locked (so its sensor leaves it alone).
static func set_open(room: Node3D, d: Door, frac: float, seconds: float = 0.2) -> void:
	d.open = frac > 0.0
	if d.tween != null and d.tween.is_valid():
		d.tween.kill()
	d.tween = room.create_tween().set_parallel(true)
	for l in d.leaves:
		var leaf: MeshInstance3D = l[0]
		if is_instance_valid(leaf):
			d.tween.tween_property(leaf, "position", (l[1] as Vector3).lerp(l[2] as Vector3, clampf(frac, 0.0, 1.0)), seconds)


## Floor on one side of the door (side = 1 / -1 along its normal), about at the door's own foot.
static func _floor_at(space: PhysicsDirectSpaceState3D, room: Node3D, d: Door, side: float) -> bool:
	var p := d.centre + d.normal * side * 0.9 + Vector3.UP * 0.8
	var q := PhysicsRayQueryParameters3D.create(p, p + Vector3.DOWN * 1.4, 1)
	var hit := space.intersect_ray(q)
	if hit.is_empty():
		return false
	var dy := absf((hit["position"] as Vector3).y - d.centre.y)
	return dy < 0.35
