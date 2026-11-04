class_name WallIntercom
extends RefCounted
## REV 792 (Glen: "If you want to replace all the red intercoms in the game with this, that would be cool"): the
## TOS red wall intercom from UnimatrixRed's kit (assets/models/props/wall_intercom_tos/wall_intercom.glb, built by
## tools/props/wall_intercom/build.sh; CC BY 4.0, credited in docs/CREDITS.md).
##
## Model: real size (PLATE = 239 x 197 mm), origin = the middle of the plate's BACK, front +Z, up +Y.
## Used three ways:
##  - make(width): an intercom that wide (the plate keeps its shape) - ModelRoom's WALL_PICTURES entries with
##    wall_intercom.png, the bowling alley's panel.
##  - swap_map(room): every flat panel in the map's own red intercom picture (MAP_MATERIAL - Deck 6's crew quarters,
##    the hangar deck, the old Act 1 map) draws nothing and a model stands on the wall in its place, as big as fits.
##  - talk_button(width): where the talk button is, from the plate's centre (x right, y up, z out) - for fingers.

const MODEL := "res://assets/models/props/wall_intercom_tos/wall_intercom.glb"
const MAP_MATERIAL := "textures/tos/intercom"
const PLATE := Vector2(0.23921, 0.19691)
const DEPTH := 0.02946
const TALK_BUTTON := Vector2(0.06284, -0.04166)
const GLOW := 0.10            # the red plate's own colour as a floor (dim corridors)
## REV 854 (Glen, 4 Nov: "too big ... should come down to about 75%"): every intercom is drawn this much smaller
## than the space it was given, still centred on the same spot. talk_button() follows, so fingers still land on it.
const SIZE := 0.75

static var _scene: PackedScene = null


static func make(width: float) -> Node3D:
	if _scene == null:
		if not ResourceLoader.exists(MODEL):
			return null
		_scene = load(MODEL)
		if _scene == null:
			return null
	var holder := Node3D.new()
	holder.name = "WallIntercom"
	var m := _scene.instantiate() as Node3D
	holder.add_child(m)
	m.scale = Vector3.ONE * (width * SIZE / PLATE.x)
	for mi_ in m.find_children("*", "MeshInstance3D", true, false):
		var mi := mi_ as MeshInstance3D
		for s in mi.mesh.get_surface_count():
			var src := mi.mesh.surface_get_material(s) as StandardMaterial3D
			if src != null and src.resource_name == "Body":
				var mat := src.duplicate() as StandardMaterial3D
				mat.emission_enabled = true
				mat.emission = src.albedo_color
				mat.emission_energy_multiplier = GLOW
				mi.set_surface_override_material(s, mat)
	return holder


## From the plate's centre, at this width: the talk button's face (x right, y up, z out of the wall).
static func talk_button(width: float) -> Vector3:
	var k := width * SIZE / PLATE.x
	return Vector3(TALK_BUTTON.x * k, TALK_BUTTON.y * k, DEPTH * k)


## The map's own red intercom panels -> the model.
static func swap_map(room: Node3D) -> void:
	if room.has_meta("wall_intercoms_done"):
		return
	room.set_meta("wall_intercoms_done", true)
	var n := 0
	for m in room.find_children("*", "MeshInstance3D", true, false):
		var mi := m as MeshInstance3D
		if mi.mesh == null or mi.skin != null:
			continue
		for s in mi.mesh.get_surface_count():
			var mat := mi.mesh.surface_get_material(s)
			if mat == null or String(mat.resource_name).to_lower() != MAP_MATERIAL:
				continue
			for panel in _panels(mi, s):
				var p: Dictionary = panel
				var w := minf(float(p["w"]), float(p["h"]) * PLATE.x / PLATE.y)
				var ic := make(w)
				if ic == null:
					return
				room.add_child(ic)
				var nrm: Vector3 = p["n"]
				var right := Vector3.UP.cross(nrm).normalized()
				ic.global_transform = Transform3D(Basis(right, Vector3.UP, nrm), (p["c"] as Vector3) + nrm * 0.002)
				n += 1
			mi.set_surface_override_material(s, ChairSwap.hide_material())
	if n > 0:
		print("WallIntercom: %d map intercoms replaced" % n)


## One surface's flat panels (world space): each {c: centre, n: outward normal (flat), w, h}. Triangles are joined
## into panels where they share corners; a panel that isn't a wall (its normal not level) is skipped.
static func _panels(mi: MeshInstance3D, s: int) -> Array:
	var arr := mi.mesh.surface_get_arrays(s)
	var v: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
	var nv = arr[Mesh.ARRAY_NORMAL]
	var idx = arr[Mesh.ARRAY_INDEX]
	var ids := PackedInt32Array()
	if idx is PackedInt32Array and (idx as PackedInt32Array).size() > 0:
		ids = idx
	else:
		for i in v.size():
			ids.append(i)
	var gt := mi.global_transform
	# join triangles that share a corner (by position)
	var key_of := {}
	var par := PackedInt32Array()
	var tri_count := ids.size() / 3
	par.resize(tri_count)
	for t in tri_count:
		par[t] = t
	for t in tri_count:
		for k in 3:
			var p := v[ids[t * 3 + k]]
			var key := Vector3i(roundi(p.x * 1000.0), roundi(p.y * 1000.0), roundi(p.z * 1000.0))
			if key_of.has(key):
				var a := _root(par, int(key_of[key]))
				var b := _root(par, t)
				par[b] = a
			else:
				key_of[key] = t
	var groups := {}
	for t in tri_count:
		var r := _root(par, t)
		if not groups.has(r):
			groups[r] = []
		(groups[r] as Array).append(t)
	var out: Array = []
	for g in groups.values():
		var pts := PackedVector3Array()
		var nsum := Vector3.ZERO
		for t in g:
			for k in 3:
				var i := ids[t * 3 + k]
				pts.append(gt * v[i])
				if nv is PackedVector3Array and i < (nv as PackedVector3Array).size():
					nsum += gt.basis * (nv as PackedVector3Array)[i]
		var nrm := Vector3(nsum.x, 0.0, nsum.z)
		if nrm.length() < 0.001 or absf(nsum.normalized().y) > 0.3:
			continue
		nrm = nrm.normalized()
		var right := Vector3.UP.cross(nrm).normalized()
		var lo := Vector2(INF, INF)
		var hi := Vector2(-INF, -INF)
		var c := Vector3.ZERO
		for p in pts:
			c += p
			var uv := Vector2(p.dot(right), p.y)
			lo = Vector2(minf(lo.x, uv.x), minf(lo.y, uv.y))
			hi = Vector2(maxf(hi.x, uv.x), maxf(hi.y, uv.y))
		c /= float(pts.size())
		var mid := Vector2((lo.x + hi.x) * 0.5, (lo.y + hi.y) * 0.5)
		# centre on the panel's own rectangle, on its plane
		var plane_d := c.dot(nrm)
		var centre := right * mid.x + Vector3.UP * mid.y
		centre += nrm * (plane_d - centre.dot(nrm))
		out.append({"c": centre, "n": nrm, "w": hi.x - lo.x, "h": hi.y - lo.y})
	return out


static func _root(par: PackedInt32Array, a: int) -> int:
	while par[a] != a:
		par[a] = par[par[a]]
		a = par[a]
	return a
