class_name ChairSwap
extends RefCounted
## REV 778 (Glen: "Let's use it and replace every single chair in the game. And if it swivels in the game, let's keep it
## swiveling"): every old Quake TOS chair on every deck map (materials tos_chair and TrekTOS toschair01 - single props,
## copies, and the maps where dozens of chairs are merged into one mesh) is swapped for Glen's Burke chair
## (assets/models/props/tos_chair/tos_chair.glb, REV 777).
##
## For each old chair: its stem axis (the middle of its lowest part - the star base), the way it faces (away from the
## top of its back), its floor and its seat height (the highest point in front of the stem, below the back) are read
## from the map's own triangles. The new chair stands on the same axis, faces the same way and is scaled so its seat
## is at the SAME height - so everyone who sits in these chairs (bridge crew, lounge, teaser) sits exactly as before
## (the two chairs' proportions match: seat at 43% of the height on the old one, 42.5% on the new).
##
## The old chair's triangles are not deleted (the map's meshes are never rebuilt): its surface just draws nothing
## (HIDE shader). A chair that is a mesh of its own gets the new chair as a CHILD of that mesh - so when SwivelSeat turns
## the old mesh (the bridge crew turning to talk), the new chair turns with it. Chairs merged into a bigger mesh don't
## swivel (none of those are sat in by the swivel code).
## The new chair's node names never contain "tos_chair", so the code that finds chairs by name (SwivelSeat.chair_meshes,
## EnterpriseBridge, the teasers) still finds only the old meshes.

const MODEL := "res://assets/models/props/tos_chair/tos_chair.glb"
const MATERIALS := ["models/mapobjects/tos/tos_chair", "models/mapobjects/trektos/toschair01"]
const WELD := 0.002            # metres: points closer than this are one point
const SHELL_GLOW := 0.18       # the blue shell's own colour as a floor, so a chair in a dim corner never goes black

static var _hide_mat: ShaderMaterial = null
static var _model: PackedScene = null
static var _model_meas := {}   # the new chair, measured once: axis, seat
static var _cache := {}        # map file|node path|surface -> [[Transform3D relative to the mesh, own mesh?], ...]


static func run(room: Node3D) -> void:
	CaptainChairSwap.run(room)   # REV 783: Kirk's chair is its own model (Glen's kit)
	WallIntercom.swap_map(room)  # REV 792: the map's red wall intercoms -> UnimatrixRed's kit
	if not ResourceLoader.exists(MODEL):
		return
	if _model == null:
		_model = load(MODEL)
		if _model == null:
			return
		_model_meas = _measure_model()
		if _model_meas.is_empty():
			return
	var map_file := ""
	var cfg = room.get("cfg")
	if cfg is Dictionary:
		map_file = String((cfg as Dictionary).get("model", "")).get_file()
	var loose := Node3D.new()
	loose.name = "NewChairs"
	room.add_child(loose)
	var n := 0
	for m in room.find_children("*", "MeshInstance3D", true, false):
		var mi := m as MeshInstance3D
		if mi.mesh == null or mi.skin != null or not mi.is_visible_in_tree():
			continue
		if String(mi.name).to_lower().contains("captain"):
			continue   # REV 779 (Glen: "what have you done to Captain Kirk's chair?"): its seat is in the chair material too
		var chair_surfaces: Array = []
		for s in mi.mesh.get_surface_count():
			var mat := mi.mesh.surface_get_material(s)
			if mat != null and MATERIALS.has(String(mat.resource_name).to_lower()):
				chair_surfaces.append(s)
		if chair_surfaces.is_empty():
			continue
		var key := "%s|%s" % [map_file, String(room.get_path_to(mi))]
		var found: Array = _cache.get(key, [])
		if not _cache.has(key):
			found = _find_chairs(mi, chair_surfaces)
			_cache[key] = found
		for s in chair_surfaces:
			mi.set_surface_override_material(s, _hide())
		for f in found:
			var holder := _new_chair()
			if bool(f[1]):
				mi.add_child(holder)
			else:
				loose.add_child(holder)
			holder.global_transform = mi.global_transform * (f[0] as Transform3D)
			n += 1
	if n == 0:
		loose.queue_free()


## The chairs in `mi`'s chair surfaces: each [its transform relative to mi, whether it rides on mi (one chair alone)].
static func _find_chairs(mi: MeshInstance3D, surfaces: Array) -> Array:
	var gt := mi.global_transform
	var pts := PackedVector3Array()
	for s in surfaces:
		var arr := mi.mesh.surface_get_arrays(s)
		var v: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
		var idx = arr[Mesh.ARRAY_INDEX]
		if idx is PackedInt32Array and (idx as PackedInt32Array).size() > 0:
			for i in idx:
				pts.append(gt * v[i])
		else:
			for p in v:
				pts.append(gt * p)
	var groups := _cluster(pts)
	var alone := groups.size() == 1 and surfaces.size() == mi.mesh.get_surface_count()
	var inv := gt.affine_inverse()
	var out: Array = []
	for g in groups:
		var c := _analyse(g)
		if c.is_empty():
			continue
		var k := float(c["seat"]) / float(_model_meas["seat"])
		var f: Vector2 = c["facing"]
		var basis := Basis(Vector3.UP, atan2(f.x, f.y)).scaled(Vector3.ONE * k)
		var ax: Vector2 = c["axis"]
		var mx: Vector2 = _model_meas["axis"]
		var origin := Vector3(ax.x, float(c["floor"]), ax.y) - basis * Vector3(mx.x, 0.0, mx.y)
		out.append([inv * Transform3D(basis, origin), alone])
	return out


## Triangle points -> one array of points per chair: pieces joined where they share points, then pieces whose
## footprints (seen from above) overlap joined too (a chair's seat over its own base).
static func _cluster(pts: PackedVector3Array) -> Array:
	var n := pts.size()
	var id := {}
	var vid := PackedInt32Array()
	vid.resize(n)
	for i in n:
		var p := pts[i]
		var k := Vector3i(roundi(p.x / WELD), roundi(p.y / WELD), roundi(p.z / WELD))
		if not id.has(k):
			id[k] = id.size()
		vid[i] = id[k]
	var par := PackedInt32Array()
	par.resize(id.size())
	for i in par.size():
		par[i] = i
	var t := 0
	while t + 2 < n:
		var a := _root(par, vid[t])
		par[_root(par, vid[t + 1])] = a
		par[_root(par, vid[t + 2])] = a
		t += 3
	# footprints per piece
	var boxes := {}
	for i in n:
		var r := _root(par, vid[i])
		var p := pts[i]
		if not boxes.has(r):
			boxes[r] = [p.x, p.x, p.z, p.z]
		else:
			var b: Array = boxes[r]
			b[0] = minf(b[0], p.x); b[1] = maxf(b[1], p.x); b[2] = minf(b[2], p.z); b[3] = maxf(b[3], p.z)
	var keys := boxes.keys()
	var pp := {}
	for k in keys:
		pp[k] = k
	for i in keys.size():
		for j in range(i + 1, keys.size()):
			var A: Array = boxes[keys[i]]
			var B: Array = boxes[keys[j]]
			if A[0] <= B[1] and B[0] <= A[1] and A[2] <= B[3] and B[2] <= A[3]:
				pp[_root_d(pp, keys[j])] = _root_d(pp, keys[i])
	var groups := {}
	for i in n:
		var g = _root_d(pp, _root(par, vid[i]))
		if not groups.has(g):
			groups[g] = []        # an Array (shared), not a PackedVector3Array (copied on every read)
		(groups[g] as Array).append(pts[i])
	return groups.values()


static func _root(par: PackedInt32Array, a: int) -> int:
	while par[a] != a:
		par[a] = par[par[a]]
		a = par[a]
	return a


static func _root_d(pp: Dictionary, a):
	while pp[a] != a:
		pp[a] = pp[pp[a]]
		a = pp[a]
	return a


## One chair's points -> {floor, axis (x, z), facing (x, z), seat (height above the floor)}. Empty if it doesn't look
## like a chair.
static func _analyse(v) -> Dictionary:   # v: Array or PackedVector3Array of Vector3
	if v.size() < 12:
		return {}
	var y0 := INF
	var y1 := -INF
	for p: Vector3 in v:
		y0 = minf(y0, p.y)
		y1 = maxf(y1, p.y)
	var h := y1 - y0
	if h < 0.05:
		return {}
	var lo := Vector2(INF, INF)
	var hi := Vector2(-INF, -INF)
	var top := Vector2.ZERO
	var nt := 0
	for p in v:
		if p.y < y0 + 0.12 * h:
			lo = Vector2(minf(lo.x, p.x), minf(lo.y, p.z))
			hi = Vector2(maxf(hi.x, p.x), maxf(hi.y, p.z))
		if p.y > y0 + 0.85 * h:
			top += Vector2(p.x, p.z)
			nt += 1
	if nt == 0 or lo.x == INF:
		return {}
	var axis := (lo + hi) * 0.5
	var back := top / float(nt) - axis
	if back.length() < 0.02 * h:
		return {}
	var f := -back.normalized()
	var seat := -INF
	for p in v:
		if p.y < y0 + 0.75 * h and (Vector2(p.x, p.z) - axis).dot(f) > 0.15 * h:
			seat = maxf(seat, p.y - y0)
	if seat <= 0.0:
		return {}
	return {"floor": y0, "axis": axis, "facing": f, "seat": seat}


## The new chair measured the same way, at its own size (it faces +Z).
static func _measure_model() -> Dictionary:
	var inst := _model.instantiate() as Node3D
	var pts := PackedVector3Array()
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
		for s in mi.mesh.get_surface_count():
			for p in (mi.mesh.surface_get_arrays(s)[Mesh.ARRAY_VERTEX] as PackedVector3Array):
				pts.append(t * p)
	inst.free()
	return _analyse(pts)


static func _new_chair() -> Node3D:
	var holder := Node3D.new()
	holder.name = "BurkeChair"
	var c := _model.instantiate() as Node3D
	holder.add_child(c)
	for m in c.find_children("*", "MeshInstance3D", true, false):
		var mi := m as MeshInstance3D
		if mi.mesh == null:
			continue
		for s in mi.mesh.get_surface_count():
			var src := mi.mesh.surface_get_material(s) as StandardMaterial3D
			if src == null or not (String(src.resource_name) in ["Shell", "Triangles"]):
				continue
			var mat := _glow_cache.get(src.resource_name) as StandardMaterial3D
			if mat == null:
				mat = src.duplicate() as StandardMaterial3D
				mat.emission_enabled = true
				mat.emission = src.albedo_color
				mat.emission_energy_multiplier = SHELL_GLOW
				_glow_cache[src.resource_name] = mat
			mi.set_surface_override_material(s, mat)
	return holder

static var _glow_cache := {}


static func hide_material() -> ShaderMaterial:
	return _hide()


## Draws nothing (and casts no shadow): every point is put behind the camera's far end.
static func _hide() -> ShaderMaterial:
	if _hide_mat == null:
		var sh := Shader.new()
		sh.code = "shader_type spatial;\nrender_mode unshaded, cull_disabled;\nvoid vertex() { POSITION = vec4(0.0, 0.0, 2.0, 1.0); }\nvoid fragment() { discard; }\n"
		_hide_mat = ShaderMaterial.new()
		_hide_mat.shader = sh
	return _hide_mat
