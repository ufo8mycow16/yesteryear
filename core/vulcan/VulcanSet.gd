class_name VulcanSet
extends RefCounted
## REV 821 (Glen, 3 Nov: the Vulcan sets in the "remastered" look - TMP Director's Edition, Gol): the kit every
## Vulcan room is built from. Big clean planes of sandstone and dark volcanic rock, angled cuts, tall rooms, warm
## light through narrow openings. First used by Tuvall's office (episodes/episode1/scenes/TuvallOffice.gd); the
## other Vulcan rooms reuse it. Page: docs/systems/vulcan-sets.md.
##
## TEXTURES ARE GLEN'S. Every surface belongs to a SLOT; it is a plain stone colour (with a faint grain) until Glen
## drops a picture named after the slot into TEXTURE_DIR (<slot>.png / .jpg / .webp) - then that picture is used,
## tiled across the surface in world space (SLOTS' third value = metres one picture covers). Screens, the window
## view and the banner work the same way (their own names, listed in the page); until then they are drawn by shaders.
##
## Shapes: prism() extrudes any flat outline (angled panels, chamfered desk tops, chair sides), wall_with_opening()
## builds a wall with one pointed-arch window or door cut out of it. Everything solid gets collision.

const TEXTURE_DIR := "res://assets/textures/vulcan/"

## slot -> [plain colour, roughness, metres one picture covers, metallic]
const SLOTS := {
	"sandstone": [Color(0.74, 0.53, 0.36), 0.78, 2.5, 0.0],          # walls
	"carved": [Color(0.74, 0.53, 0.36), 0.75, 2.5, 0.0],             # REV 829: the wall stone in one piece (no block joints) - carved furniture
	"sandstone_dark": [Color(0.56, 0.38, 0.25), 0.80, 2.0, 0.0],     # buttresses, trim, shelves, chairs' bases
	"volcanic": [Color(0.15, 0.12, 0.11), 0.28, 1.5, 0.0],           # desk top, plinths, polished dark stone
	"floor": [Color(0.72, 0.52, 0.35), 0.22, 2.0, 0.0],              # polished sandstone tiles (picture = 2 x 2 m)
	"ceiling": [Color(0.40, 0.27, 0.19), 0.90, 3.0, 0.0],
	"cushion": [Color(0.20, 0.13, 0.11), 0.85, 0.6, 0.0],            # chair cushions
	"bronze": [Color(0.66, 0.45, 0.22), 0.35, 0.5, 0.85],            # bowls, brazier, chains, figures
	"door": [Color(0.62, 0.44, 0.29), 0.55, 2.5, 0.0],               # sliding stone doors
	"metal_dark": [Color(0.12, 0.10, 0.09), 0.45, 1.0, 0.6],         # screen frames, terminal casings
}

## REV 839 (Glen, twice: "too orange"): the stone pictures are multiplied by this cool tint - sandstone reads as
## pale honey-beige instead of orange. 1,1,1 = the pictures as made.
const STONE_TINT := Color(0.90, 0.94, 1.0)
const STONE_SLOTS := ["sandstone", "carved", "sandstone_dark", "floor", "ceiling", "door"]

const SKY_SHADER := "res://core/vulcan/vulcan_sky.gdshader"
const SCREEN_SHADER := "res://core/vulcan/vulcan_screen.gdshader"
const BANNER_SHADER := "res://core/vulcan/vulcan_banner.gdshader"
const BEAM_SHADER := "res://core/vulcan/sunbeam.gdshader"
const FLAME_SHADER := "res://core/vulcan/flame.gdshader"

static var _mats := {}


# =========================================================================
# Materials
# =========================================================================

## Glen's picture for `name` in TEXTURE_DIR, or null.
static func picture(name: String) -> Texture2D:
	for ext in ["png", "jpg", "webp"]:
		var path: String = TEXTURE_DIR + name + "." + String(ext)
		if ResourceLoader.exists(path):
			return load(path)
	return null


## A slot's material (shared): Glen's picture tiled in world space, else the plain colour with a faint grain.
static func mat(slot: String) -> StandardMaterial3D:
	if _mats.has(slot):
		return _mats[slot]
	var spec: Array = SLOTS.get(slot, SLOTS["sandstone"])
	var m := StandardMaterial3D.new()
	m.resource_name = "vulcan_" + slot
	m.albedo_color = spec[0]
	m.roughness = float(spec[1])
	m.metallic = float(spec[3])
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	var tex := picture(slot)
	if tex != null:
		m.albedo_texture = tex
		m.albedo_color = STONE_TINT if STONE_SLOTS.has(slot) else Color.WHITE
	elif slot == "floor":
		m.albedo_texture = _floor_tiles()
	elif slot != "cushion" and slot != "bronze" and slot != "metal_dark":
		m.albedo_texture = _grain(slot)
	var nrm := picture(slot + "_normal")       # REV 828: surface relief, so the stone catches the light
	if nrm != null:
		m.normal_enabled = true
		m.normal_texture = nrm
		m.normal_scale = 1.0
	if m.albedo_texture != null or nrm != null:
		m.uv1_triplanar = true
		m.uv1_world_triplanar = true
		var k := 1.0 / maxf(float(spec[2]), 0.01)
		m.uv1_scale = Vector3(k, k, k)
	_mats[slot] = m
	return m


## A faint stone grain (multiplies the plain colour by 0.86-1.0) - so plain walls don't read as grey boxes.
static func _grain(slot: String) -> NoiseTexture2D:
	var n := FastNoiseLite.new()
	n.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	n.frequency = 0.012
	n.fractal_octaves = 5
	n.seed = hash(slot) % 1000
	var t := NoiseTexture2D.new()
	t.width = 512
	t.height = 512
	t.seamless = true
	t.noise = n
	var g := Gradient.new()
	g.set_color(0, Color(0.86, 0.86, 0.86))
	g.set_color(1, Color(1.0, 1.0, 1.0))
	t.color_ramp = g
	return t


## Polished floor tiles: a 2 x 2 m picture of four 1 m tiles, each its own tone, thin dark joints.
static func _floor_tiles() -> ImageTexture:
	var size := 256
	var img := Image.create(size, size, false, Image.FORMAT_RGB8)
	var tones := [1.0, 0.93, 0.97, 0.90]
	var n := FastNoiseLite.new()
	n.frequency = 0.03
	for y in size:
		for x in size:
			var tile := (1 if x >= size / 2 else 0) + (2 if y >= size / 2 else 0)
			var v: float = tones[tile] * (0.94 + 0.06 * n.get_noise_2d(x, y))
			var jx := mini(x % (size / 2), size / 2 - 1 - x % (size / 2))
			var jy := mini(y % (size / 2), size / 2 - 1 - y % (size / 2))
			if jx < 1 or jy < 1:
				v *= 0.55
			img.set_pixel(x, y, Color(v, v, v))
	img.generate_mipmaps()
	return ImageTexture.create_from_image(img)


# =========================================================================
# Shapes
# =========================================================================

## A flat outline (`poly`, local x/y, metres) extruded `depth` metres along local z (centred on 0), placed by
## `xform`. Solid ones get trimesh collision. Returns the MeshInstance3D (its parent is the body when solid).
static func prism(parent: Node3D, node_name: String, poly: PackedVector2Array, depth: float, xform: Transform3D, slot: String, solid: bool = true) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.name = node_name
	mi.mesh = _prism_mesh(poly, depth)
	mi.material_override = mat(slot)
	_place(parent, mi, xform, solid)
	return mi


## The basis that lays a prism's outline flat (plan view: local x = world x, local y = world -z) and extrudes it
## upward - for desk tops, plinths, floor inlays.
static func flat(origin: Vector3, yaw_deg: float = 0.0) -> Transform3D:
	var b := Basis(Vector3(1, 0, 0), Vector3(0, 0, -1), Vector3(0, 1, 0))
	return Transform3D(Basis(Vector3.UP, deg_to_rad(yaw_deg)) * b, origin)


## The basis for a side profile (local x = the room's z, local y = up) extruded across x - chair sides, pedestals.
## The profile's +x is the way the piece faces (yaw 0 = facing +z).
static func side(origin: Vector3, yaw_deg: float = 0.0) -> Transform3D:
	var b := Basis(Vector3(0, 0, 1), Vector3(0, 1, 0), Vector3(-1, 0, 0))
	return Transform3D(Basis(Vector3.UP, deg_to_rad(yaw_deg)) * b, origin)


## An upright outline facing +z (local x = world x), turned by yaw - wall panels, buttresses, desk bases.
static func upright(origin: Vector3, yaw_deg: float = 0.0) -> Transform3D:
	return Transform3D(Basis(Vector3.UP, deg_to_rad(yaw_deg)), origin)


## A plain block in a slot (centre, size, optional turn in degrees).
static func slab(parent: Node3D, node_name: String, center: Vector3, size: Vector3, slot: String, solid: bool = true, rot_deg: Vector3 = Vector3.ZERO) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.name = node_name
	var bm := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	mi.material_override = mat(slot)
	var b := Basis.from_euler(rot_deg * (PI / 180.0))
	_place(parent, mi, Transform3D(b, center), solid)
	return mi


static func _place(parent: Node3D, mi: MeshInstance3D, xform: Transform3D, solid: bool) -> void:
	if solid:
		var body := StaticBody3D.new()
		body.name = String(mi.name) + "_Body"
		body.transform = xform
		parent.add_child(body)
		body.add_child(mi)
		var cs := CollisionShape3D.new()
		cs.shape = mi.mesh.create_trimesh_shape()
		body.add_child(cs)
	else:
		mi.transform = xform
		parent.add_child(mi)


static func _prism_mesh(poly_in: PackedVector2Array, depth: float) -> ArrayMesh:
	var poly := poly_in.duplicate()
	var area := 0.0
	for i in poly.size():
		var a := poly[i]
		var b := poly[(i + 1) % poly.size()]
		area += a.x * b.y - b.x * a.y
	if area < 0.0:
		poly.reverse()
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var hz := depth * 0.5
	var idx := Geometry2D.triangulate_polygon(poly)
	for t in range(0, idx.size(), 3):
		var p0 := poly[idx[t]]
		var p1 := poly[idx[t + 1]]
		var p2 := poly[idx[t + 2]]
		_tri(st, Vector3(p0.x, p0.y, hz), Vector3(p1.x, p1.y, hz), Vector3(p2.x, p2.y, hz), Vector3(0, 0, 1))
		_tri(st, Vector3(p0.x, p0.y, -hz), Vector3(p1.x, p1.y, -hz), Vector3(p2.x, p2.y, -hz), Vector3(0, 0, -1))
	for i in poly.size():
		var a := poly[i]
		var b := poly[(i + 1) % poly.size()]
		var e := b - a
		var n := Vector3(e.y, -e.x, 0.0).normalized()     # outward for a counter-clockwise outline
		var a0 := Vector3(a.x, a.y, hz)
		var b0 := Vector3(b.x, b.y, hz)
		var a1 := Vector3(a.x, a.y, -hz)
		var b1 := Vector3(b.x, b.y, -hz)
		_tri(st, a0, b0, b1, n)
		_tri(st, a0, b1, a1, n)
	return st.commit()


## One triangle facing `n` (Godot's front faces wind clockwise as seen from the front).
static func _tri(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, n: Vector3) -> void:
	if (b - a).cross(c - a).dot(n) > 0.0:
		var t := b
		b = c
		c = t
	st.set_normal(n)
	st.add_vertex(a)
	st.set_normal(n)
	st.add_vertex(b)
	st.set_normal(n)
	st.add_vertex(c)


## A wall `width` x `height`, `thick` deep, its inner face on the plane through `xform`'s origin (the wall goes
## back along local -z), with one pointed opening cut out of it: centre `cx` (local x), bottom `y0`, half width
## `hb` at the bottom, leaning in to half width `hs` at height `ys`, up to a point at `yp`. A door (y0 = 0) or a
## window (y0 = the sill). cx = INF = no opening.
static func wall_with_opening(parent: Node3D, node_name: String, xform: Transform3D, width: float, height: float, thick: float, slot: String,
		cx: float = INF, y0: float = 0.0, hb: float = 0.0, ys: float = 0.0, hs: float = 0.0, yp: float = 0.0) -> void:
	var back := xform * Transform3D(Basis.IDENTITY, Vector3(0.0, 0.0, -thick * 0.5))
	var l := -width * 0.5
	var r := width * 0.5
	if cx == INF:
		prism(parent, node_name, PackedVector2Array([Vector2(l, 0), Vector2(r, 0), Vector2(r, height), Vector2(l, height)]), thick, back, slot)
		return
	if y0 > 0.001:
		prism(parent, node_name + "_Below", PackedVector2Array([Vector2(l, 0), Vector2(r, 0), Vector2(r, y0), Vector2(l, y0)]), thick, back, slot)
	prism(parent, node_name + "_L", PackedVector2Array([Vector2(l, y0), Vector2(cx - hb, y0), Vector2(cx - hs, ys), Vector2(cx, yp), Vector2(cx, height), Vector2(l, height)]), thick, back, slot)
	prism(parent, node_name + "_R", PackedVector2Array([Vector2(cx + hb, y0), Vector2(r, y0), Vector2(r, height), Vector2(cx, height), Vector2(cx, yp), Vector2(cx + hs, ys)]), thick, back, slot)


## The same pointed outline as an opening, for the door leaf or a frame.
static func arch_outline(hb: float, ys: float, hs: float, yp: float, y0: float = 0.0) -> PackedVector2Array:
	return PackedVector2Array([Vector2(-hb, y0), Vector2(hb, y0), Vector2(hs, ys), Vector2(0, yp), Vector2(-hs, ys)])


# =========================================================================
# Set pieces
# =========================================================================

## The view through a window: Glen's view_<name> picture, else the painted-sky shader (ShiKahr). A big flat
## picture `size` metres, standing at `center`, facing `yaw_deg` (0 = facing +z, into a room to its south).
const VIEW_SPREAD := 4.0
const VIEW_SHADER := """
shader_type spatial;
render_mode unshaded, fog_disabled, cull_back;
uniform sampler2D view : source_color, filter_linear_mipmap, repeat_disable;
uniform float spread = 4.0;
void fragment() {
	vec2 uv = UV * spread - vec2((spread - 1.0) * 0.5);
	uv.x = 1.0 - abs(mod(uv.x, 2.0) - 1.0);
	uv.y = clamp(uv.y, 0.002, 0.998);
	ALBEDO = texture(view, uv).rgb;
}
"""


static func window_view(parent: Node3D, center: Vector3, size: Vector2, yaw_deg: float = 0.0, name: String = "shikahr") -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.name = "WindowView"
	var qm := QuadMesh.new()
	qm.size = size
	mi.mesh = qm
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var tex := picture("view_" + name)
	if tex != null:
		# REV 839 (Glen: "when i look at the correct angle, i can see the edges of the background image"): the
		# picture keeps its size and place, but the quad is VIEW_SPREAD times bigger and carries on past its edges -
		# mirrored left and right (more city and mountains), the top sky and bottom ground stretched - so no
		# angle through the window ever reaches an edge.
		qm.size = size * VIEW_SPREAD
		var sh := Shader.new()
		sh.code = VIEW_SHADER
		var m := ShaderMaterial.new()
		m.shader = sh
		m.set_shader_parameter("view", tex)
		m.set_shader_parameter("spread", VIEW_SPREAD)
		mi.material_override = m
	else:
		var sm := ShaderMaterial.new()
		sm.shader = load(SKY_SHADER)
		sm.set_shader_parameter("aspect", size.x / size.y)
		mi.material_override = sm
	mi.transform = upright(center, yaw_deg)
	parent.add_child(mi)
	return mi


## A display set into the stone: a dark metal frame standing `inset` proud of the surface and the screen in it.
## Glen's screen_<name> picture if he has made one, else the animated amber/red Vulcan display.
static func screen(parent: Node3D, node_name: String, center: Vector3, size: Vector2, yaw_deg: float, seed: float = 1.0, tilt_deg: float = 0.0) -> MeshInstance3D:
	var holder := Node3D.new()
	holder.name = node_name
	holder.transform = Transform3D(Basis(Vector3.UP, deg_to_rad(yaw_deg)) * Basis(Vector3.RIGHT, deg_to_rad(-tilt_deg)), center)
	parent.add_child(holder)
	var frame := MeshInstance3D.new()
	frame.mesh = rounded_box_mesh(Vector3(size.x + 0.10, size.y + 0.10, 0.05), 0.012, 3)
	frame.material_override = mat("metal_dark")
	frame.position = Vector3(0, 0, -0.02)
	holder.add_child(frame)
	var mi := MeshInstance3D.new()
	mi.name = "Screen"
	var qm := QuadMesh.new()
	qm.size = size
	mi.mesh = qm
	mi.position = Vector3(0, 0, 0.007)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var tex := picture("screen_" + node_name.to_lower())
	if tex != null:
		var m := StandardMaterial3D.new()
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		m.albedo_texture = tex
		mi.material_override = m
	else:
		var sm := ShaderMaterial.new()
		sm.shader = load(SCREEN_SHADER)
		sm.set_shader_parameter("seed", seed)
		sm.set_shader_parameter("map_share", 0.62 if size.x > size.y * 1.2 else 1.0)
		mi.material_override = sm
	holder.add_child(mi)
	return mi


## A long banner hanging from a bronze rod: `top` = the middle of the rod, facing yaw (0 = +z).
static func banner(parent: Node3D, top: Vector3, size: Vector2, yaw_deg: float) -> void:
	var holder := Node3D.new()
	holder.name = "Banner"
	holder.transform = upright(top, yaw_deg)
	parent.add_child(holder)
	var rod := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = 0.025
	cm.bottom_radius = 0.025
	cm.height = size.x + 0.3
	rod.mesh = cm
	rod.material_override = mat("bronze")
	rod.rotation_degrees = Vector3(0, 0, 90)
	rod.position = Vector3(0, 0, 0.06)
	holder.add_child(rod)
	var mi := MeshInstance3D.new()
	var qm := QuadMesh.new()
	qm.size = size
	qm.subdivide_width = 12
	qm.subdivide_depth = 12
	mi.mesh = qm
	mi.position = Vector3(0, -size.y * 0.5 - 0.03, 0.06)
	var tex := picture("banner")
	if tex != null:
		var m := StandardMaterial3D.new()
		m.albedo_texture = tex
		m.roughness = 0.9
		m.cull_mode = BaseMaterial3D.CULL_DISABLED
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
		mi.material_override = m
	else:
		var sm := ShaderMaterial.new()
		sm.shader = load(BANNER_SHADER)
		mi.material_override = sm
	holder.add_child(mi)


## A bronze brazier hanging on three chains from the ceiling at `ceiling_y`, its bowl at `bowl`, with a live
## flame and a flickering warm light.
static func brazier(parent: Node3D, bowl: Vector3, ceiling_y: float) -> OmniLight3D:
	var holder := Node3D.new()
	holder.name = "Brazier"
	holder.position = bowl
	parent.add_child(holder)
	var b := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = 0.30
	cm.bottom_radius = 0.10
	cm.height = 0.16
	b.mesh = cm
	b.material_override = mat("bronze")
	holder.add_child(b)
	var rim := MeshInstance3D.new()
	var tm := TorusMesh.new()
	tm.inner_radius = 0.28
	tm.outer_radius = 0.32
	rim.mesh = tm
	rim.position = Vector3(0, 0.08, 0)
	rim.material_override = mat("bronze")
	holder.add_child(rim)
	var drop := ceiling_y - bowl.y
	for i in 3:
		var a := TAU * float(i) / 3.0
		var foot := Vector3(cos(a) * 0.29, 0.08, sin(a) * 0.29)
		var topp := Vector3(0, drop, 0)
		var chain := MeshInstance3D.new()
		var ch := CylinderMesh.new()
		ch.top_radius = 0.008
		ch.bottom_radius = 0.008
		var chain_len := foot.distance_to(topp)
		ch.height = chain_len
		chain.mesh = ch
		chain.material_override = mat("bronze")
		var mid := (foot + topp) * 0.5
		var dir := (topp - foot).normalized()
		chain.transform = Transform3D(Basis(Quaternion(Vector3.UP, dir)), mid)
		holder.add_child(chain)
	var flame := MeshInstance3D.new()
	flame.name = "Flame"
	var qm := QuadMesh.new()
	qm.size = Vector2(0.42, 0.55)
	flame.mesh = qm
	flame.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var sm := ShaderMaterial.new()
	sm.shader = load(FLAME_SHADER)
	sm.set_shader_parameter("seed", bowl.x * 3.1)
	flame.material_override = sm
	flame.position = Vector3(0, 0.33, 0)
	holder.add_child(flame)
	var light := OmniLight3D.new()
	light.name = "FireLight"
	light.light_color = Color(1.0, 0.76, 0.52)     # REV 839: less orange
	light.light_energy = 1.1
	light.omni_range = 6.5
	light.position = Vector3(0, 0.35, 0)
	light.light_volumetric_fog_energy = 0.2
	holder.add_child(light)
	var t := holder.create_tween().set_loops()
	for e in [1.25, 0.95, 1.15, 0.85, 1.3, 1.0]:
		t.tween_property(light, "light_energy", e, 0.09 + 0.07 * randf())
	return light


## A stone chair facing yaw (0 = +z) - REV 833 rebuilt as proper furniture: a cut-stone frame with rounded edges,
## arms with polished dark stone tops, a padded leather seat and back (rounded, with stitched piping and buttons).
## `back_h` = how high the back reaches (a visitor's chair ~0.95, an official's ~1.5).
static func stone_chair(parent: Node3D, node_name: String, pos: Vector3, yaw_deg: float, back_h: float = 0.85, width: float = 0.78) -> void:
	var holder := Node3D.new()
	holder.name = node_name
	holder.transform = upright(pos, yaw_deg)
	parent.add_child(holder)
	var hw := width * 0.5
	var arm_w := 0.13
	# the frame: a low plinth, two arm blocks, a seat block
	soft(holder, "Plinth", Vector3(0, 0.03, 0.0), Vector3(width + 0.04, 0.06, 0.70), 0.02, "volcanic", Vector3.ZERO, false)
	for sx in [-1.0, 1.0]:
		soft(holder, "Arm", Vector3(sx * (hw - arm_w * 0.5), 0.33, 0.0), Vector3(arm_w, 0.54, 0.66), 0.025, "sandstone_dark")
		soft(holder, "ArmTop", Vector3(sx * (hw - arm_w * 0.5), 0.62, 0.02), Vector3(arm_w + 0.03, 0.04, 0.68), 0.015, "volcanic", Vector3.ZERO, false)
		soft(holder, "ArmTrim", Vector3(sx * (hw - arm_w * 0.5), 0.595, 0.355), Vector3(arm_w - 0.02, 0.012, 0.012), 0.004, "bronze", Vector3.ZERO, false)
	var inner := width - arm_w * 2.0
	soft(holder, "Seat", Vector3(0, 0.22, 0.02), Vector3(inner + 0.01, 0.36, 0.62), 0.02, "sandstone_dark")
	# padded leather seat: a plump rounded cushion with a thin piping round it
	soft(holder, "SeatCushion", Vector3(0, 0.46, 0.05), Vector3(inner - 0.01, 0.13, 0.58), 0.055, "cushion", Vector3.ZERO, false)
	soft(holder, "SeatPiping", Vector3(0, 0.455, 0.05), Vector3(inner + 0.0, 0.018, 0.59), 0.009, "cushion", Vector3.ZERO, false)
	# the back: a stone slab leaning back, a padded leather panel on it with buttons
	var lean := 12.0
	var bh := back_h - 0.4
	var back_c := Vector3(0, 0.4 + bh * 0.5, -0.27)
	soft(holder, "Back", back_c, Vector3(width, bh, 0.12), 0.025, "sandstone_dark", Vector3(-lean, 0, 0))
	var b := Basis.from_euler(Vector3(deg_to_rad(-lean), 0, 0))
	var pad_c := back_c + b * Vector3(0, 0.04, 0.085)
	var pad := Vector3(inner - 0.02, bh - 0.16, 0.08)
	soft(holder, "BackCushion", pad_c, pad, 0.04, "cushion", Vector3(-lean, 0, 0), false)
	var rows := maxi(1, int(round(pad.y / 0.22)))
	for i in rows:
		for j in 2:
			var bx := (float(j) - 0.5) * pad.x * 0.45 + (0.0 if i % 2 == 0 else (0.5 - float(j)) * pad.x * 0.45 * 0.0)
			var by := (float(i) + 0.5) / float(rows) * pad.y - pad.y * 0.5
			var btn := MeshInstance3D.new()
			var sm := SphereMesh.new()
			sm.radius = 0.011
			sm.height = 0.016
			btn.mesh = sm
			btn.material_override = mat("bronze")
			btn.position = pad_c + b * Vector3(bx, by, pad.z * 0.5 - 0.004)
			holder.add_child(btn)


## A smooth dark meditation stone resting on a sandstone plinth.
static func meditation_stone(parent: Node3D, pos: Vector3) -> void:
	soft(parent, "MeditationPlinth", pos + Vector3(0, 0.40, 0), Vector3(0.75, 0.80, 0.60), 0.025, "sandstone_dark")
	soft(parent, "MeditationPlinthTop", pos + Vector3(0, 0.825, 0), Vector3(0.85, 0.05, 0.70), 0.018, "volcanic", Vector3.ZERO, false)
	var mi := MeshInstance3D.new()
	mi.name = "MeditationStone"
	var sm := SphereMesh.new()
	sm.radius = 0.5
	sm.height = 1.0
	mi.mesh = sm
	mi.scale = Vector3(0.62, 0.36, 0.46)
	mi.position = pos + Vector3(0, 0.84 + 0.15, 0)
	mi.material_override = mat("volcanic")
	parent.add_child(mi)


## A small bronze figure of a robed Vulcan (shelf ornament), `h` metres tall.
static func figure(parent: Node3D, pos: Vector3, h: float = 0.42) -> void:
	var robe := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = h * 0.09
	cm.bottom_radius = h * 0.20
	cm.height = h * 0.78
	robe.mesh = cm
	robe.position = pos + Vector3(0, h * 0.39, 0)
	robe.material_override = mat("bronze")
	parent.add_child(robe)
	var head := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = h * 0.09
	sm.height = h * 0.20
	head.mesh = sm
	head.position = pos + Vector3(0, h * 0.86, 0)
	head.material_override = mat("bronze")
	parent.add_child(head)


## A shaft of sunlight from `from` (the window) to `to` (the floor), `r0`/`r1` metres wide at each end, and a few
## motes of dust drifting in it.
static func sunbeam(parent: Node3D, from: Vector3, to: Vector3, r0: float, r1: float, strength: float = 0.10) -> void:
	var mi := MeshInstance3D.new()
	mi.name = "Sunbeam"
	var cm := CylinderMesh.new()
	cm.top_radius = r0
	cm.bottom_radius = r1
	var beam_len := from.distance_to(to)
	cm.height = beam_len
	cm.cap_top = false
	cm.cap_bottom = false
	cm.radial_segments = 24
	mi.mesh = cm
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var sm := ShaderMaterial.new()
	sm.shader = load(BEAM_SHADER)
	sm.set_shader_parameter("strength", strength)
	mi.material_override = sm
	var dir := (from - to).normalized()
	mi.transform = Transform3D(Basis(Quaternion(Vector3.UP, dir)), (from + to) * 0.5)
	parent.add_child(mi)
	# dust
	var p := GPUParticles3D.new()
	p.name = "Dust"
	p.amount = 90
	p.lifetime = 9.0
	p.preprocess = 9.0
	p.transform = mi.transform
	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	pm.emission_box_extents = Vector3((r0 + r1) * 0.35, beam_len * 0.4, (r0 + r1) * 0.35)
	pm.gravity = Vector3(0, -0.004, 0)
	pm.direction = Vector3(1, 0.2, 0)
	pm.spread = 180.0
	pm.initial_velocity_min = 0.01
	pm.initial_velocity_max = 0.04
	pm.scale_min = 0.6
	pm.scale_max = 1.4
	var fade := Gradient.new()
	fade.set_color(0, Color(1, 1, 1, 0))
	fade.add_point(0.3, Color(1, 1, 1, 1))
	fade.add_point(0.7, Color(1, 1, 1, 1))
	fade.set_color(fade.get_point_count() - 1, Color(1, 1, 1, 0))
	var ft := GradientTexture1D.new()
	ft.gradient = fade
	pm.color_ramp = ft
	p.process_material = pm
	var q := QuadMesh.new()
	q.size = Vector2(0.012, 0.012)
	var qm := StandardMaterial3D.new()
	qm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	qm.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	qm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	qm.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	qm.vertex_color_use_as_albedo = true
	qm.albedo_color = Color(1.0, 0.8, 0.55, 0.7)
	q.material = qm
	p.draw_pass_1 = q
	p.visibility_aabb = AABB(Vector3(-3, -4, -3), Vector3(6, 8, 6))
	parent.add_child(p)


## The sun through a window: a warm spotlight from `from` outside aimed at `to`, casting the window's shape.
static func sun(parent: Node3D, from: Vector3, to: Vector3, energy: float = 7.0, angle_deg: float = 14.0) -> SpotLight3D:
	var s := SpotLight3D.new()
	s.name = "SunThroughWindow"
	s.light_color = Color(1.0, 0.95, 0.88)     # REV 839: near-white daylight (Glen: "still too orange")
	s.light_energy = energy
	s.spot_range = from.distance_to(to) * 1.4
	s.spot_angle = angle_deg
	s.spot_attenuation = 0.4
	s.shadow_enabled = true
	parent.add_child(s)
	s.look_at_from_position(from, to, Vector3.UP)
	return s


# =========================================================================
# REV 829: detail pieces (Glen: "pretend this is a commercial game")
# =========================================================================

## A block with its vertical edges chamfered `c` metres - stone pillars, plinths and furniture read as cut stone.
static func chamfer_box(parent: Node3D, node_name: String, center: Vector3, size: Vector3, slot: String, c: float = 0.03, solid: bool = true, yaw_deg: float = 0.0) -> MeshInstance3D:
	# REV 833: every cut-stone block is now a softly rounded box (bevelled edges catch the light - commercial-game look)
	return soft(parent, node_name, center, size, minf(c, 0.06), slot, Vector3(0.0, yaw_deg, 0.0), solid)


static var _round_cache := {}

## REV 833: a box with every edge and corner rounded to radius `r` (the classic "push the surface out from an inner
## box" trick): `seg` steps round each edge. Cached by size. Normals are exact, so bevels shade smoothly.
static func rounded_box_mesh(size: Vector3, r: float, seg: int = 4) -> ArrayMesh:
	var key := "%s|%.4f|%d" % [str(size), r, seg]
	if _round_cache.has(key):
		return _round_cache[key]
	var h := size * 0.5
	r = minf(r, minf(h.x, minf(h.y, h.z)) * 0.98)
	var inner := h - Vector3(r, r, r)
	var axis_pts := func(half: float) -> PackedFloat32Array:
		var out := PackedFloat32Array()
		for k in seg + 1:
			out.append(-half + r * (1.0 - cos(PI * 0.5 * float(k) / float(seg))))
		for k in range(seg, -1, -1):
			out.append(half - r * (1.0 - cos(PI * 0.5 * float(k) / float(seg))))
		return out
	var pts := [axis_pts.call(h.x), axis_pts.call(h.y), axis_pts.call(h.z)]
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for ax in 3:
		for sgn in [-1.0, 1.0]:
			var j := (ax + 1) % 3
			var k := (ax + 2) % 3
			var pj: PackedFloat32Array = pts[j]
			var pk: PackedFloat32Array = pts[k]
			var grid := []
			for a_ in pj.size():
				var row := []
				for b_ in pk.size():
					var p := Vector3.ZERO
					p[ax] = sgn * h[ax]
					p[j] = pj[a_]
					p[k] = pk[b_]
					var q := Vector3(clampf(p.x, -inner.x, inner.x), clampf(p.y, -inner.y, inner.y), clampf(p.z, -inner.z, inner.z))
					var n := (p - q)
					n = n.normalized() if n.length() > 1e-6 else Vector3.ZERO
					if n == Vector3.ZERO:
						n[ax] = sgn
					row.append([q + n * r, n])
				grid.append(row)
			for a_ in pj.size() - 1:
				for b_ in pk.size() - 1:
					var v00: Array = grid[a_][b_]
					var v10: Array = grid[a_ + 1][b_]
					var v01: Array = grid[a_][b_ + 1]
					var v11: Array = grid[a_ + 1][b_ + 1]
					for tri in [[v00, v10, v11], [v00, v11, v01]]:
						var pa: Vector3 = tri[0][0]
						var pb: Vector3 = tri[1][0]
						var pc: Vector3 = tri[2][0]
						var fn := (pb - pa).cross(pc - pa)
						if fn.length() < 1e-10:
							continue
						var avg: Vector3 = tri[0][1] + tri[1][1] + tri[2][1]
						var order := [0, 1, 2] if fn.dot(avg) < 0.0 else [0, 2, 1]     # clockwise from outside = front
						for o in order:
							st.set_normal(tri[o][1])
							st.add_vertex(tri[o][0])
	var mesh := st.commit()
	_round_cache[key] = mesh
	return mesh


## REV 833: a rounded box in a slot - stone, leather, metal. `rot_deg` turns it (degrees, x/y/z).
static func soft(parent: Node3D, node_name: String, center: Vector3, size: Vector3, r: float, slot: String, rot_deg: Vector3 = Vector3.ZERO, solid: bool = true) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.name = node_name
	mi.mesh = rounded_box_mesh(size, r, 4 if r > 0.03 else 3)
	mi.material_override = mat(slot)
	var xf := Transform3D(Basis.from_euler(rot_deg * (PI / 180.0)), center)
	if solid:
		var body := StaticBody3D.new()
		body.name = node_name + "_Body"
		body.transform = xf
		parent.add_child(body)
		body.add_child(mi)
		var cs := CollisionShape3D.new()
		var bs := BoxShape3D.new()
		bs.size = size
		cs.shape = bs
		body.add_child(cs)
	else:
		mi.transform = xf
		parent.add_child(mi)
	return mi


## A turned shape (urn, bowl, vase): `profile` = Vector2(radius, height) from the bottom up, spun round `pos`.
static func lathe(parent: Node3D, node_name: String, pos: Vector3, profile: Array, slot: String, segments: int = 28) -> MeshInstance3D:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in profile.size() - 1:
		var p0: Vector2 = profile[i]
		var p1: Vector2 = profile[i + 1]
		var t := p1 - p0
		var nrm := Vector2(t.y, -t.x).normalized()      # outward in the (radius, height) plane
		for k in segments:
			var a0 := TAU * float(k) / float(segments)
			var a1 := TAU * float(k + 1) / float(segments)
			var v00 := Vector3(cos(a0) * p0.x, p0.y, sin(a0) * p0.x)
			var v01 := Vector3(cos(a1) * p0.x, p0.y, sin(a1) * p0.x)
			var v10 := Vector3(cos(a0) * p1.x, p1.y, sin(a0) * p1.x)
			var v11 := Vector3(cos(a1) * p1.x, p1.y, sin(a1) * p1.x)
			var am := (a0 + a1) * 0.5
			var n := Vector3(cos(am) * nrm.x, nrm.y, sin(am) * nrm.x)
			_tri(st, v00, v01, v11, n)
			_tri(st, v00, v11, v10, n)
	var mi := MeshInstance3D.new()
	mi.name = node_name
	mi.mesh = st.commit()
	mi.material_override = mat(slot)
	mi.position = pos
	parent.add_child(mi)
	return mi


## A tall stone urn (on its own collision cylinder).
static func urn(parent: Node3D, pos: Vector3, h: float = 1.1) -> void:
	var r := h * 0.24
	lathe(parent, "Urn", pos, [Vector2(r * 0.55, 0.0), Vector2(r * 0.62, h * 0.06), Vector2(r * 0.5, h * 0.1), Vector2(r * 0.95, h * 0.38),
		Vector2(r, h * 0.52), Vector2(r * 0.8, h * 0.72), Vector2(r * 0.45, h * 0.86), Vector2(r * 0.42, h * 0.92), Vector2(r * 0.6, h * 0.97),
		Vector2(r * 0.6, h), Vector2(r * 0.4, h), Vector2(r * 0.4, h * 0.8)], "sandstone_dark")
	lathe(parent, "UrnBand", pos + Vector3(0, h * 0.5, 0), [Vector2(r * 1.01, 0.0), Vector2(r * 1.02, 0.03), Vector2(r * 1.01, 0.06)], "bronze")
	var body := StaticBody3D.new()
	body.position = pos + Vector3(0, h * 0.5, 0)
	var cs := CollisionShape3D.new()
	var cyl := CylinderShape3D.new()
	cyl.radius = r
	cyl.height = h
	cs.shape = cyl
	body.add_child(cs)
	parent.add_child(body)


## A Vulcan desert plant in a low stone bowl: stiff blade leaves, grey-green going rust at the tips.
static func plant(parent: Node3D, pos: Vector3, seed: int = 1) -> void:
	lathe(parent, "PlantBowl", pos, [Vector2(0.20, 0.0), Vector2(0.30, 0.05), Vector2(0.34, 0.30), Vector2(0.36, 0.34), Vector2(0.30, 0.34), Vector2(0.28, 0.30)], "sandstone_dark")
	var body := StaticBody3D.new()
	body.position = pos + Vector3(0, 0.2, 0)
	var cs := CollisionShape3D.new()
	var cyl := CylinderShape3D.new()
	cyl.radius = 0.34
	cyl.height = 0.4
	cs.shape = cyl
	body.add_child(cs)
	parent.add_child(body)
	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	var leaf_mat := StandardMaterial3D.new()
	leaf_mat.albedo_color = Color(0.36, 0.42, 0.30)
	leaf_mat.roughness = 0.7
	var tip_mat := StandardMaterial3D.new()
	tip_mat.albedo_color = Color(0.55, 0.26, 0.14)
	tip_mat.roughness = 0.7
	for i in 13:
		var a := rng.randf() * TAU
		var lean := deg_to_rad(rng.randf_range(8.0, 38.0))
		var length := rng.randf_range(0.45, 0.95)
		var leaf := MeshInstance3D.new()
		var cm := CylinderMesh.new()
		cm.top_radius = 0.0
		cm.bottom_radius = 0.035
		cm.height = length
		cm.radial_segments = 4
		cm.rings = 1
		leaf.mesh = cm
		leaf.material_override = tip_mat if i % 4 == 0 else leaf_mat
		leaf.scale = Vector3(1.0, 1.0, 0.35)
		var dir := Vector3(sin(lean) * cos(a), cos(lean), sin(lean) * sin(a))
		var base := pos + Vector3(cos(a) * 0.06, 0.3, sin(a) * 0.06)
		leaf.transform = Transform3D(Basis(Quaternion(Vector3.UP, dir)) * Basis.from_scale(Vector3(1.0, 1.0, 0.35)), base + dir * length * 0.5)
		parent.add_child(leaf)


## The IDIC as a bronze relief on a wall (REV 831: Glen's own symbol, exactly - docs/reference/vulcan/idic_symbol.png
## cut out of bronze: idic_relief.png = the symbol's black as bronze, its white lines and background cut away so the
## wall shows through; idic_relief_normal.png bevels the edges; a soft dark copy behind it lifts it off the wall).
## `center` on the wall face, facing yaw (0 = +z), `size` = how wide the whole emblem is.
const IDIC_TEX := "res://assets/textures/vulcan/idic_relief.png"
const IDIC_NORMAL := "res://assets/textures/vulcan/idic_relief_normal.png"

static func idic(parent: Node3D, center: Vector3, yaw_deg: float, size: float = 0.9) -> void:
	if not ResourceLoader.exists(IDIC_TEX):
		return
	var holder := Node3D.new()
	holder.name = "IDIC"
	holder.transform = upright(center, yaw_deg)
	parent.add_child(holder)
	var tex: Texture2D = load(IDIC_TEX)
	var shadow := MeshInstance3D.new()
	var qs := QuadMesh.new()
	qs.size = Vector2(size, size)
	shadow.mesh = qs
	var sm := StandardMaterial3D.new()
	sm.albedo_texture = tex
	sm.albedo_color = Color(0.0, 0.0, 0.0, 0.45)
	sm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	sm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	shadow.material_override = sm
	shadow.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	shadow.position = Vector3(0.012, -0.016, 0.004)
	holder.add_child(shadow)
	var face := MeshInstance3D.new()
	face.name = "IDICFace"
	var qm := QuadMesh.new()
	qm.size = Vector2(size, size)
	face.mesh = qm
	var m := StandardMaterial3D.new()
	m.albedo_texture = tex
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
	m.alpha_scissor_threshold = 0.5
	m.metallic = 0.75
	m.roughness = 0.38
	if ResourceLoader.exists(IDIC_NORMAL):
		m.normal_enabled = true
		m.normal_texture = load(IDIC_NORMAL)
		m.normal_scale = 1.0
	face.material_override = m
	face.position = Vector3(0, 0, 0.02)
	holder.add_child(face)


## A data slate lying on a surface: a thin dark tablet with a softly lit screen.
static func slate(parent: Node3D, pos: Vector3, yaw_deg: float, seed: float = 3.0) -> void:
	chamfer_box(parent, "Slate", pos + Vector3(0, 0.007, 0), Vector3(0.17, 0.014, 0.24), "metal_dark", 0.015, false, yaw_deg)
	var mi := MeshInstance3D.new()
	var qm := QuadMesh.new()
	qm.size = Vector2(0.13, 0.19)
	qm.orientation = PlaneMesh.FACE_Y
	mi.mesh = qm
	var sm := ShaderMaterial.new()
	sm.shader = load(SCREEN_SHADER)
	sm.set_shader_parameter("seed", seed)
	sm.set_shader_parameter("map_share", 1.0)
	sm.set_shader_parameter("energy", 1.0)
	mi.material_override = sm
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.transform = Transform3D(Basis(Vector3.UP, deg_to_rad(yaw_deg)), pos + Vector3(0, 0.0145, 0))
	parent.add_child(mi)


## Room reflections for polished stone (one box-projected probe, updated once).
static func reflections(parent: Node3D, center: Vector3, size: Vector3) -> void:
	var p := ReflectionProbe.new()
	p.name = "Reflections"
	p.position = center
	p.size = size
	p.box_projection = true
	p.interior = true
	p.update_mode = ReflectionProbe.UPDATE_ONCE
	p.ambient_mode = ReflectionProbe.AMBIENT_DISABLED
	parent.add_child(p)


# =========================================================================
# REV 832: second detail pass (Glen: "Still doesn't give commercial game vibes")
# =========================================================================

## A carved band of Vulcan script along a wall: from `a` to `b` (x/z on the wall face), `y` = its middle, `h` tall,
## facing yaw. The picture (frieze.jpg, 8:1) repeats along it.
static func frieze(parent: Node3D, a: Vector3, b: Vector3, y: float, h: float, yaw_deg: float) -> void:
	var length := Vector2(a.x, a.z).distance_to(Vector2(b.x, b.z))
	var mi := MeshInstance3D.new()
	mi.name = "Frieze"
	var qm := QuadMesh.new()
	qm.size = Vector2(length, h)
	mi.mesh = qm
	var m := StandardMaterial3D.new()
	var tex := picture("frieze")
	if tex != null:
		m.albedo_texture = tex
	else:
		m.albedo_color = (SLOTS["carved"][0] as Color)
	var nrm := picture("frieze_normal")
	if nrm != null:
		m.normal_enabled = true
		m.normal_texture = nrm
	m.roughness = 0.8
	m.uv1_scale = Vector3(length / (h * 8.0), 1.0, 1.0)
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	mi.material_override = m
	mi.transform = upright((a + b) * 0.5 + Vector3(0, y, 0), yaw_deg)
	parent.add_child(mi)


## A tall robed statue in the Gol manner: hooded, faceless, hands folded, on a cut-stone plinth. `h` = the figure.
static func statue(parent: Node3D, pos: Vector3, yaw_deg: float, h: float = 2.5) -> void:
	chamfer_box(parent, "StatuePlinth", pos + Vector3(0, 0.2, 0), Vector3(0.9, 0.4, 0.9), "sandstone_dark", 0.06, true, yaw_deg)
	chamfer_box(parent, "StatuePlinthTop", pos + Vector3(0, 0.42, 0), Vector3(0.98, 0.04, 0.98), "volcanic", 0.05, false, yaw_deg)
	var holder := Node3D.new()
	holder.name = "Statue"
	holder.transform = upright(pos + Vector3(0, 0.44, 0), yaw_deg)
	parent.add_child(holder)
	# the robe: wide at the hem, falling straight, narrowing to the shoulders; flattened front to back
	var robe := lathe(holder, "Robe", Vector3.ZERO, [Vector2(0.0, 0.0), Vector2(h * 0.17, 0.0), Vector2(h * 0.165, h * 0.04),
		Vector2(h * 0.14, h * 0.35), Vector2(h * 0.125, h * 0.62), Vector2(h * 0.13, h * 0.74), Vector2(h * 0.115, h * 0.79),
		Vector2(h * 0.06, h * 0.82), Vector2(0.0, h * 0.83)], "sandstone_dark", 32)
	robe.scale = Vector3(1.0, 1.0, 0.72)
	# the hood: an egg over the head, open at the front (a dark recess where the face would be)
	var hood := lathe(holder, "Hood", Vector3(0, h * 0.8, 0), [Vector2(0.0, 0.0), Vector2(h * 0.07, h * 0.01), Vector2(h * 0.075, h * 0.07),
		Vector2(h * 0.06, h * 0.14), Vector2(h * 0.03, h * 0.18), Vector2(0.0, h * 0.19)], "sandstone_dark", 24)
	hood.scale = Vector3(1.0, 1.0, 1.1)
	var face := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = h * 0.045
	sm.height = h * 0.11
	face.mesh = sm
	face.material_override = mat("volcanic")
	face.position = Vector3(0, h * 0.875, h * 0.052)
	face.scale = Vector3(1.0, 1.0, 0.5)
	holder.add_child(face)
	# folded hands at the waist and the fall of the sleeves
	chamfer_box(holder, "Hands", Vector3(0, h * 0.5, h * 0.105), Vector3(h * 0.16, h * 0.07, h * 0.06), "sandstone_dark", 0.02, false)
	for sx in [-1.0, 1.0]:
		var sleeve := MeshInstance3D.new()
		var cm := CylinderMesh.new()
		cm.top_radius = h * 0.035
		cm.bottom_radius = h * 0.05
		cm.height = h * 0.3
		sleeve.mesh = cm
		sleeve.material_override = mat("sandstone_dark")
		sleeve.position = Vector3(sx * h * 0.085, h * 0.63, h * 0.06)
		sleeve.rotation_degrees = Vector3(-18, 0, sx * -12)
		holder.add_child(sleeve)
	var body := StaticBody3D.new()
	body.position = pos + Vector3(0, 0.44 + h * 0.45, 0)
	var cs := CollisionShape3D.new()
	var cyl := CylinderShape3D.new()
	cyl.radius = h * 0.16
	cyl.height = h * 0.9
	cs.shape = cyl
	body.add_child(cs)
	parent.add_child(body)


## A bronze wall sconce with a small live flame: a bracket out from the wall, an open bowl, a warm light.
## `pos` = where the bowl hangs (in front of the wall), facing yaw (0 = +z, i.e. the wall is behind it at -z).
static func sconce(parent: Node3D, pos: Vector3, yaw_deg: float, energy: float = 0.55) -> OmniLight3D:
	var holder := Node3D.new()
	holder.name = "Sconce"
	holder.transform = upright(pos, yaw_deg)
	parent.add_child(holder)
	chamfer_box(holder, "SconcePlate", Vector3(0, 0.05, -0.2), Vector3(0.16, 0.42, 0.03), "bronze", 0.03, false)
	chamfer_box(holder, "SconceArm", Vector3(0, -0.04, -0.1), Vector3(0.04, 0.04, 0.2), "bronze", 0.01, false)
	lathe(holder, "SconceBowl", Vector3(0, -0.1, 0), [Vector2(0.0, 0.0), Vector2(0.05, 0.01), Vector2(0.11, 0.06), Vector2(0.13, 0.09),
		Vector2(0.12, 0.09), Vector2(0.1, 0.065)], "bronze", 24)
	var flame := MeshInstance3D.new()
	var qm := QuadMesh.new()
	qm.size = Vector2(0.14, 0.2)
	flame.mesh = qm
	var fm := ShaderMaterial.new()
	fm.shader = load(FLAME_SHADER)
	fm.set_shader_parameter("seed", pos.x * 1.7 + pos.z)
	flame.material_override = fm
	flame.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	flame.position = Vector3(0, 0.06, 0)
	holder.add_child(flame)
	var light := OmniLight3D.new()
	light.light_color = Color(1.0, 0.84, 0.66)     # REV 839: less orange
	light.light_energy = energy
	light.omni_range = 5.0
	light.light_volumetric_fog_energy = 0.15
	light.position = Vector3(0, 0.12, 0.05)
	holder.add_child(light)
	var t := holder.create_tween().set_loops()
	for e in [1.08, 0.94, 1.03, 0.9, 1.1, 1.0]:
		t.tween_property(light, "light_energy", energy * e, 0.1 + 0.08 * randf())
	return light


## The look that only the full renderer can do: haze in the air so the sun through the window shows as a real
## shaft, screen-space reflections on polished stone. Off in the compatibility renderer (the fake sunbeam mesh stays).
static func atmosphere(room: Node3D, density: float = 0.005) -> bool:     # REV 837: was 0.018 - an orange veil over everything
	if RenderingServer.get_current_rendering_method() != "forward_plus":
		return false
	for we in room.find_children("*", "WorldEnvironment", false, false):
		var env := (we as WorldEnvironment).environment
		if env == null:
			continue
		# REV 839 (Glen: "still too orange!"): no volumetric haze at all - even thin, the sunlit haze laid a warm veil
		# over every face. The sunbeam mesh is hidden too (the shaft is gone with the haze).
		env.volumetric_fog_enabled = false
		env.volumetric_fog_density = density
		env.volumetric_fog_albedo = Color(1.0, 0.97, 0.94)
		env.volumetric_fog_anisotropy = 0.55
		env.volumetric_fog_length = 24.0
		env.volumetric_fog_ambient_inject = 0.0      # haze shows only where the sun shines through it
		env.ssr_enabled = true
		env.ssr_max_steps = 48
		env.ssr_fade_in = 0.15
		env.ssr_fade_out = 2.0
	for l in room.find_children("*", "Light3D", true, false):
		if l.name != "SunThroughWindow":
			(l as Light3D).light_volumetric_fog_energy = 0.0
		else:
			(l as Light3D).light_volumetric_fog_energy = 8.0      # the shaft stays visible in the thinner haze
	for b in room.find_children("Sunbeam", "MeshInstance3D", true, false):
		(b as Node3D).visible = false
	return true


# =========================================================================
# REV 835: furniture modelled in Blender (tools/props/vulcan_furniture/build.py)
# =========================================================================

const FURNITURE_DIR := "res://assets/models/props/vulcan/"
static var _furniture := {}

## A piece of Blender-made furniture (FURNITURE_DIR/<name>.glb) at `pos`, facing yaw (0 = +z). Its materials are
## named vf_<slot> and are swapped for this kit's slot materials (so Glen's/the generated textures apply). Solid as a
## box round its shape. Returns the instance, or null if the model isn't in the project.
static func furniture(parent: Node3D, name: String, pos: Vector3, yaw_deg: float, solid: bool = true) -> Node3D:
	var path := FURNITURE_DIR + name + ".glb"
	if not _furniture.has(path):
		_furniture[path] = load(path) if ResourceLoader.exists(path) else null
	var scene: PackedScene = _furniture[path]
	if scene == null:
		return null
	var inst := scene.instantiate() as Node3D
	inst.name = name
	inst.transform = upright(pos, yaw_deg)
	parent.add_child(inst)
	var box := AABB()
	var first := true
	for m in inst.find_children("*", "MeshInstance3D", true, false):
		var mi := m as MeshInstance3D
		for s in mi.mesh.get_surface_count():
			var sm := mi.mesh.surface_get_material(s)
			var nm := String(sm.resource_name) if sm != null else ""
			if nm.begins_with("vf_"):
				mi.set_surface_override_material(s, mat(nm.substr(3).get_slice(".", 0)))
		var local_box: AABB = inst.global_transform.affine_inverse() * mi.global_transform * mi.mesh.get_aabb()
		box = local_box if first else box.merge(local_box)
		first = false
	if solid and not first:
		var body := StaticBody3D.new()
		body.name = name + "_Body"
		var cs := CollisionShape3D.new()
		var bs := BoxShape3D.new()
		bs.size = box.size
		cs.shape = bs
		cs.position = box.get_center()
		body.add_child(cs)
		inst.add_child(body)
	return inst
