class_name ModernLighting
extends Node3D
## REV 170 (CLAUDE.md item 25): the modern look for a converted map room, so it stops reading as a
## 2005 Quake map. Written for any map (the bowling alley first); a room calls
##     ModernLighting.attach(room, map_root, world_environment, sun)
## after its map has its baked-lighting materials, and this takes it from there:
##   1. Surfaces: every map surface gets a lit material (modern_surface.gdshader) - shine and roughness
##      by kind (polished lanes, chrome, carpet, paint...), relief from the picture, the map's baked
##      light kept as soft occlusion - so it reacts to real lights, shadows and reflections.
##   2. Lights: the map's light panels are found by their textures, grouped into panels, and each gets
##      a real light of its own colour (the brightest few cast shadows). Works on whatever room version
##      Glen picks, without placing lights by hand.
##   3. The room: bounced light (SDFGI), reflections (SSR + a reflection probe), soft shadowing in
##      corners (SSAO/SSIL), a faint haze the lights shine through, glow, filmic colour.
## Needs the Forward+ renderer (Glen's laptop); on Compatibility, LOW quality or with LIGHTING set to
## CLASSIC the room is exactly as before (the baked lightmap). F7 flips CLASSIC / MODERN live (debug).
## Shift+F7 (debug) saves a before/after pair of the current view to user://screenshots/.

## ---- tuning (all in one place) ------------------------------------------------------------------
## Kinds of surface, matched against the material's name (first match wins).
## [keys, roughness, metallic, specular, clearcoat, relief, occlusion, emissive]
const KINDS := [
	[["lanes"], 0.32, 0.0, 0.55, 0.7, 0.25, 0.45, 0.0],                      # varnished wood
	# REV 693 (engineering + sickbay): engineering's coloured pipes are painted, not chrome; brushed metals; floors with a sheen
	[["redpipe", "bluepipe", "engpipe"], 0.35, 0.25, 0.5, 0.35, 0.3, 0.45, 0.0],
	[["med_silver", "copper_ball", "engine_grey", "protoplaser"], 0.3, 0.85, 0.5, 0.0, 0.3, 0.45, 0.0],
	# REV 701 (Glen: "I don't think lights are supposed to reflect off carpet"): ent_floor IS the ship's carpet (the
	# brown tweed in every corridor and engineering) - it moved to the carpet kind below; only the grey deck keeps a sheen
	[["floorgrey"], 0.4, 0.0, 0.5, 0.3, 0.6, 0.55, 0.0],
	[["chrome", "turboliftrail", "hallpipe", "pipe"], 0.18, 1.0, 0.5, 0.0, 0.2, 0.35, 0.0],
	[["carpet", "ent_floor", "fabric", "commandchair", "headboard"], 0.95, 0.0, 0.25, 0.0, 1.2, 0.6, 0.0],
	[["grate", "lift_floor", "tranplate", "ductplating"], 0.45, 0.65, 0.5, 0.0, 0.9, 0.55, 0.0],
	[["door"], 0.42, 0.0, 0.5, 0.15, 0.4, 0.5, 0.0],
	[["screen", "display_", "redalert", "energy"], 0.25, 0.0, 0.5, 0.0, 0.0, 0.0, 0.6],
	[["moodlite"], 0.5, 0.0, 0.4, 0.0, 0.0, 0.0, 1.0],
	[["light", "basiclt", "conflight", "elight"], 0.5, 0.0, 0.4, 0.0, 0.0, 0.0, 1.0],
	[["water"], 0.08, 0.0, 0.5, 0.0, 0.3, 0.3, 0.0],
	[["poster", "logo", "gal1", "sideview"], 0.55, 0.0, 0.4, 0.2, 0.3, 0.45, 0.0],
	[[""], 0.62, 0.0, 0.45, 0.0, 0.55, 0.55, 0.0],                             # painted walls etc.
]
## Which kinds count as light panels (they get real lights).
const LIGHT_PANEL_KEYS := ["light", "basiclt", "conflight", "elight", "moodlite"]
const MAX_LIGHTS := 40
const MAX_SHADOWED := 6
## REV 681 (performance pass): MEDIUM keeps the lamps but only this many throw shadows (each shadowed omni lamp
## draws the room six more times whenever someone moves near it), and screen reflections take fewer steps.
const MEDIUM_SHADOWED := 2
const MEDIUM_SSR_STEPS := 32
const PANEL_CELL := 1.6          # long strips of light are cut into pieces about this long (m)
const LIGHT_ENERGY := 1.45       # per square metre of panel, before limits (REV 552: was 1.15)
const LIGHT_MIN_ENERGY := 1.0      # REV 551: was 0.35 - small fixtures (the alley's dome lamps) lit almost nothing (REV 552: 0.8 -> 1.0)
const LIGHT_MAX_ENERGY := 3.0    # REV 552: was 2.4
const LIGHT_RANGE := 7.5
## REV 554: how far in front of its panel a light sits (m). 0.18 put a hot specular dot on the ceiling
## beside every lamp - the "little white spots on the roof" that flickered as the camera drifted.
const LIGHT_STANDOFF := 0.4
## REV 557 (Glen: the characters' lighting still a little off - faces orange and ruddy): how far each
## lamp's colour is pulled from its panel picture's hue toward a neutral warm white (was 0.35).
const LAMP_WHITE := Color(1.0, 0.98, 0.95)
const LAMP_NEUTRAL := 0.75
## REV 560 (Glen: "the lighting with the actors is still really off" - orange-brown faces, dark eye sockets):
## with the sun off, people were lit only by the steep ceiling lamps and the floor's bounce. A soft KEY light
## for people only (the room never sees it: render layer CHAR_LAYER), aimed from just above and beside the
## camera - the film "eye light" - so whoever faces the camera has a properly lit face.
const CHAR_LAYER := 1 << 19
const KEY_ENERGY := 1.0          # REV 565: was 0.7 (Glen: faces better, "maybe a little more light")
const KEY_COLOUR := Color(1.0, 0.97, 0.93)
const KEY_DOWN_DEG := 28.0        # how far above the camera's line the key comes from
const KEY_SIDE_DEG := 18.0        # and how far to the side
## REV 578 (Glen: a pale rim under every jaw - "a light source too far down"): lamps made from LOW or
## UPWARD-facing panels (the lane strips, the glowing panels by the seats) lit people from below. They
## still light the room (the lanes keep their gloss) but not people: their cull mask leaves out CHAR_LAYER,
## and _tag_people moves people off the room's layer 1 onto CHAR_LAYER (every other light still has it).
const LOW_LIGHT_Y := 1.3           # a lamp below this height (m, deck floor ~0) is "low"
const UP_FACING := 0.5             # or whose panel faces up this much (normal.y)
const NOT_PEOPLE := 0xFFFFF & ~CHAR_LAYER
const EMISSIVE_ENERGY := 1.7     # how hard the panels themselves glow (REV 171: was 2.6 - too hot)
## REV 551: how much of the map's baked light stays on as fill, so corners no real light reaches (the
## alley's seating area) read as the room, not as black. The lanes keep the old low fill - their gloss
## against the dark is the look Glen wants kept ("don't lose that ever").
const ROOM_FILL := 0.45           # REV 552: was 0.32 (Glen: still too dark)
const LANE_FILL := 0.08

## The room's own settings while MODERN is on (restored for CLASSIC).
const ENV := {
	"tonemap_mode": Environment.TONE_MAPPER_AGX,
	"tonemap_exposure": 1.55,         # REV 552: was 1.25 (Glen: still too dark) - times `brightness`
	"glow_enabled": true, "glow_intensity": 0.55, "glow_strength": 1.0, "glow_bloom": 0.04,
	"glow_hdr_threshold": 1.1, "glow_blend_mode": Environment.GLOW_BLEND_MODE_SOFTLIGHT,
	"ssao_enabled": true, "ssao_radius": 0.9, "ssao_intensity": 1.8, "ssao_power": 1.4,
	"ssao_detail": 0.6,
	"ssil_enabled": true, "ssil_radius": 3.0, "ssil_intensity": 0.45,     # REV 557: was 0.7 (the lanes' orange bounced onto faces)
	"ssr_enabled": true, "ssr_max_steps": 72, "ssr_fade_in": 0.15, "ssr_fade_out": 2.0,
	"ssr_depth_tolerance": 0.25,
	"sdfgi_enabled": true, "sdfgi_use_occlusion": true, "sdfgi_read_sky_light": false,
	"sdfgi_cascades": 4, "sdfgi_min_cell_size": 0.12, "sdfgi_energy": 0.7,     # REV 557: was 1.1 (orange bounce)
	"sdfgi_bounce_feedback": 0.35, "sdfgi_normal_bias": 1.1,
	"volumetric_fog_enabled": true, "volumetric_fog_density": 0.006,
	"volumetric_fog_albedo": Color(0.9, 0.92, 1.0), "volumetric_fog_gi_inject": 0.4,
	"volumetric_fog_length": 40.0, "volumetric_fog_anisotropy": 0.35,
	"ambient_light_energy": 0.5,      # REV 551: was 0.22, REV 552: 0.3 -> 0.5 (faces too dark)
	"adjustment_enabled": true, "adjustment_contrast": 1.04, "adjustment_saturation": 1.0,     # REV 557: was 1.06 / 1.08 (ruddy skin)
}
## What MEDIUM quality leaves out (the expensive ones).
const MEDIUM_OFF := ["sdfgi_enabled", "volumetric_fog_enabled", "ssil_enabled"]
const SUN_ENERGY := 0.0          # no sunlight indoors; the panels light the room

const MARK := "_vf_modern"       # env meta: LookEnhancer leaves an environment with this alone

var _env: Environment
var _sun: DirectionalLight3D
var _sun_energy := 0.0
var _env_orig := {}
var _surfaces: Array = []        # [MeshInstance3D, surface, classic material, modern material]
var _lights: Array[Light3D] = []
var _probe: ReflectionProbe
var _modern := false
var _shooting := false
var _key: DirectionalLight3D
var _tag_clock := 0.0
## REV 552: Glen's live brightness dial in MODERN (debug [ and ] in the alley), multiplies the exposure.
## Shown on F3's LIGHT line; tell Claude the number and it becomes the default.
static var brightness := 1.0
## REV 668: a ROOM's own dimmer on top of `brightness` (ModelRoom's [ ] keys and MODERN_LOOK "dim") - the deck rooms
## used to keep the alley's exposure whatever [ ] said (Glen: "it's the lowest it can be, and everything is still
## nuclear explosion bright"). 1.0 = the alley's look.
var room_dim := 1.0
## REV 554 (debug, MODERN only): effects switched off live with Ctrl+1..7 to find what flickers -
## 1 reflections (SSR), 2 bounced light (SDFGI), 3 SSIL, 4 SSAO, 5 haze (fog), 6 glow, 7 background blur.
const EFFECT_KEYS := ["ssr_enabled", "sdfgi_enabled", "ssil_enabled", "ssao_enabled", "volumetric_fog_enabled", "glow_enabled", "dof"]
const EFFECT_NAMES := ["SSR", "SDFGI", "SSIL", "SSAO", "FOG", "GLOW", "BLUR"]
static var effects_off := {}
var _bounds := AABB()            # REV 551: only light panels inside this box get real lights (empty = all)
## REV 663 (Glen: the alley's lights "all over deck 15"): a map room's own wishes -
##   exclude      surface names that only LOOK like lamps (Deck 15's symbol-light wall cladding, the consoles' little
##                coloured button lights): painted like walls, no real light, no glow
##   keep_custom  a surface the room has already given its own non-baked material (a warp-tunnel viewer, a picture) is
##                left exactly as it is
##   enabled      the room can switch the look off where it doesn't apply (the hangar map's other levels)
var exclude := PackedStringArray()
var keep_custom := false
var enabled := true
## REV 693 (Glen: engineering and sickbay "as Unreal as we can"): ZONES - one map file holding several rooms where only some
## get the modern look (Deck 7: engineering and sickbay). Each zone is a list of world boxes; lamps are found only inside
## the zones, each zone has its own lamp budget, reflection probe and coloured GEL lights (add_gel - the TOS theatrical
## washes as real lights), and only the zone you stand in (`set_zone`) has its lights on. Empty = the old single-room way.
var _zones: Array = []            # [[AABB, ...], ...] per zone
var _light_zone: Array[int] = []  # per _lights entry: its zone (-1 = no zone)
var _gels: Array[SpotLight3D] = []
var _gel_zone: Array[int] = []
var _probes: Array[ReflectionProbe] = []
var _probe_zone: Array[int] = []
var zone := -1                    # the zone the player stands in (set by the room)
## REV 732 (Glen: classic sickbay "looks better" - "you'd need to do that game wide"): the ship's map rooms (ModelRoom)
## build the enhanced look ON TOP of the classic one: every surface starts from exactly what CLASSIC draws (its baked
## light, ROOM_MOODS colours, contrast, dark ceilings - modern_surface.gdshader `classic_base`), the environment starts
## from the classic enhanced tone mapping (LookEnhancer), and the real lamps / reflections / haze are added to that.
## The bowling alley doesn't set it - its look (and the lanes' gloss) is exactly as before.
var classic_base := false
const CLASSIC_DIFFUSE := 0.15     # how much the real lamps still light a classic-based surface (the rest is classic)
## The classic shader's settings copied onto the modern material (the same names in both shaders).
const CLASSIC_KEYS := ["light_boost", "ambient_floor", "ceiling_floor", "ceiling_grey", "grade_strength", "contrast",
	"emissive_strength", "unlit_rect", "use_unlit_rect", "chroma_limit", "soft_light", "soft_k", "lm_texel",
	"wash_count", "wash_pos", "wash_col", "mood_on", "zone_count", "mood_data"]
var floor_y := 0.0                # the deck floor's world height (LOW_LIGHT_Y is measured from it)
const GEL_ENERGY := 1.25          # a gel's light = its mood strength x this (times the room's dim, through the exposure)
const GEL_RANGE_MIN := 6.0
const ZONE_MAX_LIGHTS := 24       # lamps per zone (the zones are never on together)


## Set up the modern look for `map` in `room`. Returns the node (it lives under the room).
## `bounds` (world space, optional): the part of the map the player can see. A map file often holds
## neighbouring rooms too (the alley's has engineering); without it their panels took most of the lights.
static func attach(room: Node, map: Node3D, world_env: WorldEnvironment, sun: DirectionalLight3D = null,
		lightmap_boost := 1.7, bounds := AABB(), not_lamps := PackedStringArray(), keep_room_materials := false,
		zone_boxes: Array = [], floor_height := 0.0, keep_classic := false) -> ModernLighting:
	var ml := ModernLighting.new()
	ml.name = "ModernLighting"
	ml.classic_base = keep_classic
	ml.add_to_group("modern_lighting")
	ml._bounds = bounds
	ml._zones = zone_boxes
	ml.floor_y = floor_height
	if not zone_boxes.is_empty():
		ml.enabled = false            # off until the room says which zone you are in
	ml.exclude = not_lamps
	ml.keep_custom = keep_room_materials
	room.add_child(ml)
	ml._setup(map, world_env.environment if world_env != null else null, sun, lightmap_boost)
	return ml


static func supported() -> bool:
	return RenderingServer.get_current_rendering_method() == "forward_plus"


func _setup(map: Node3D, env: Environment, sun: DirectionalLight3D, lm_boost: float) -> void:
	_env = env
	_sun = sun
	if sun != null:
		_sun_energy = sun.light_energy
	if not supported():
		return
	var shader: Shader = load("res://core/ship/modern_surface.gdshader")
	var panels: Array = []        # [world points of one light surface's triangles, colour]
	_convert(map, shader, lm_boost, panels)
	_place_lights(panels, map)
	_add_probe(map)
	_key = DirectionalLight3D.new()
	_key.name = "CharacterKey"
	_key.light_cull_mask = CHAR_LAYER
	_key.light_energy = KEY_ENERGY
	_key.light_color = KEY_COLOUR
	_key.shadow_enabled = false
	_key.light_specular = 0.35
	_key.visible = false
	add_child(_key)
	set_modern(_wanted())


## ---- surfaces -----------------------------------------------------------------------------------
func _convert(node: Node, shader: Shader, lm_boost: float, panels: Array) -> void:
	var mi := node as MeshInstance3D
	if mi != null and mi.mesh != null:
		for s in mi.mesh.get_surface_count():
			var base: Material = mi.mesh.surface_get_material(s)
			var classic: Material = mi.get_surface_override_material(s)
			var std := base as StandardMaterial3D
			if std == null:
				continue
			if std.transparency != BaseMaterial3D.TRANSPARENCY_DISABLED:
				continue          # glass and water keep their own see-through materials
			var nm := std.resource_name.to_lower()
			if keep_custom and classic != null and not (classic is ShaderMaterial and (classic as ShaderMaterial).get_shader_parameter("lightmap_tex") != null):
				continue          # REV 663: the room's own material (a screen, a picture) stays as it is
			if classic_base and classic is ShaderMaterial:
				var fx = (classic as ShaderMaterial).get_shader_parameter("screen_fx")
				if fx != null and float(fx) > 0.5:
					continue          # REV 732: a live display keeps its classic screen effects
			var k: Array = _kind(nm)
			var m := ShaderMaterial.new()
			m.shader = shader
			m.set_shader_parameter("albedo_color", std.albedo_color)
			m.set_shader_parameter("use_albedo_tex", 1.0 if std.albedo_texture != null else 0.0)
			if std.albedo_texture != null:
				m.set_shader_parameter("albedo_tex", std.albedo_texture)
			# the map's lightmap, if this surface was drawn with one
			var lm: Texture2D = null
			var sm := classic as ShaderMaterial
			if sm != null:
				lm = sm.get_shader_parameter("lightmap_tex") as Texture2D
				var tint = sm.get_shader_parameter("albedo_color")
				if tint is Color:
					m.set_shader_parameter("albedo_color", tint)     # e.g. the lifted near-black roof
				# REV 551: a picture the room swapped in on its classic material (the alley's wall with the
				# old UFP roundels painted out) - the modern material uses that too
				var at = sm.get_shader_parameter("albedo_tex")
				if at is Texture2D:
					m.set_shader_parameter("albedo_tex", at)
					m.set_shader_parameter("use_albedo_tex", 1.0)
				var ac = sm.get_shader_parameter("alpha_cut")
				if ac != null:
					m.set_shader_parameter("alpha_cut", float(ac))
			m.set_shader_parameter("use_lightmap", 1.0 if lm != null else 0.0)
			if lm != null:
				m.set_shader_parameter("lightmap_tex", lm)
			m.set_shader_parameter("lightmap_boost", lm_boost)
			m.set_shader_parameter("fill", LANE_FILL if k == KINDS[0] else ROOM_FILL)
			m.set_shader_parameter("roughness", k[1])
			m.set_shader_parameter("metallic", k[2])
			m.set_shader_parameter("specular", k[3])
			m.set_shader_parameter("clearcoat", k[4])
			m.set_shader_parameter("relief", k[5])
			m.set_shader_parameter("occlusion", k[6])
			var glow := float(k[7])
			if glow <= 0.0 and std.emission_enabled:
				glow = 0.5           # something the map (or HdTextures) already made glow
			m.set_shader_parameter("emissive", glow)
			m.set_shader_parameter("emissive_energy", EMISSIVE_ENERGY)
			if classic_base and sm != null and lm != null:
				m.set_shader_parameter("classic_base", 1.0)
				m.set_shader_parameter("classic_diffuse", CLASSIC_DIFFUSE)
				_copy_classic(sm, m)
			_surfaces.append([mi, s, classic, m])
			if _is_panel(nm):
				panels.append([_world_triangles(mi, s), _picture_colour(std)])
	for c in node.get_children():
		_convert(c, shader, lm_boost, panels)


## REV 732: the classic material's look settings onto its modern twin (boost, moods, grade, washes...).
func _copy_classic(sm: ShaderMaterial, m: ShaderMaterial) -> void:
	for key in CLASSIC_KEYS:
		var v = sm.get_shader_parameter(key)
		if v != null:
			m.set_shader_parameter(key, v)
	var em = sm.get_shader_parameter("emissive_strength")
	if em != null:
		m.set_shader_parameter("emissive_strength", em)


## REV 732: the room changed its classic look ([ ] brightness, mood on/off, a re-built mood texture) - the enhanced
## surfaces follow, so the two looks never drift apart.
func sync_classic() -> void:
	if not classic_base:
		return
	for e in _surfaces:
		var sm := e[2] as ShaderMaterial
		var m := e[3] as ShaderMaterial
		if sm == null or m == null:
			continue
		var cb = m.get_shader_parameter("classic_base")
		if cb != null and float(cb) > 0.5:
			_copy_classic(sm, m)


func _kind(nm: String) -> Array:
	if _excluded(nm):
		return KINDS[KINDS.size() - 1]
	for k in KINDS:
		for key in k[0]:
			if nm.contains(String(key)):
				return k
	return KINDS[KINDS.size() - 1]


func _excluded(nm: String) -> bool:
	for e in exclude:
		if nm.contains(e):
			return true
	return false


func _is_panel(nm: String) -> bool:
	if nm.contains("lightmap") or _excluded(nm):
		return false
	for key in LIGHT_PANEL_KEYS:
		if nm.contains(String(key)):
			return true
	return false


## The average colour of a surface's picture (what colour its light gives off), kept bright.
static var _colour_cache := {}

func _picture_colour(std: StandardMaterial3D) -> Color:
	var c := std.albedo_color
	var tex := std.albedo_texture
	if tex != null:
		var key := tex.get_rid()
		if _colour_cache.has(key):
			c = _colour_cache[key]
		else:
			var img := tex.get_image()
			if img != null:
				if img.is_compressed():
					img.decompress()
				img = img.duplicate()
				img.resize(4, 4, Image.INTERPOLATE_BILINEAR)
				var sum := Color(0, 0, 0)
				for y in 4:
					for x in 4:
						sum += img.get_pixel(x, y)
				c = Color(sum.r / 16.0, sum.g / 16.0, sum.b / 16.0)
			_colour_cache[key] = c
	# light colour: keep the hue, lift it to full brightness, and pull it a little toward white
	var m := maxf(c.r, maxf(c.g, c.b))
	if m < 0.01:
		return Color(1, 1, 1)
	c = Color(c.r / m, c.g / m, c.b / m)
	return c.lerp(LAMP_WHITE, LAMP_NEUTRAL)


func _world_triangles(mi: MeshInstance3D, s: int) -> PackedVector3Array:
	var out := PackedVector3Array()
	var arr := mi.mesh.surface_get_arrays(s)
	var v: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
	var idx = arr[Mesh.ARRAY_INDEX]
	var xf := mi.global_transform
	if idx is PackedInt32Array and (idx as PackedInt32Array).size() > 0:
		for i in idx:
			out.append(xf * v[i])
	else:
		for p in v:
			out.append(xf * p)
	return out


## ---- lights -------------------------------------------------------------------------------------
## Group each light surface's triangles into panels (triangles that touch), cut long ones into
## pieces, and put a light just in front of each piece.
func _place_lights(panels: Array, map: Node3D) -> void:
	var pieces: Array = []        # [centre, normal, area, colour, fixture]
	var fixture := 0
	for p in panels:
		var tris: PackedVector3Array = p[0]
		var col: Color = p[1]
		var n := tris.size() / 3
		if n == 0:
			continue
		# union-find over triangles sharing a corner (corners matched to the nearest centimetre)
		var parent := PackedInt32Array()
		parent.resize(n)
		for i in n:
			parent[i] = i
		var seen := {}
		for i in n:
			for j in 3:
				var q := tris[i * 3 + j]
				var key := Vector3i(roundi(q.x * 100.0), roundi(q.y * 100.0), roundi(q.z * 100.0))
				if seen.has(key):
					_union(parent, i, int(seen[key]))
				else:
					seen[key] = i
		var groups := {}
		for i in n:
			var r := _find(parent, i)
			if not groups.has(r):
				groups[r] = []
			(groups[r] as Array).append(i)
		for g in groups.values():
			fixture += 1
			# cut the panel into cells of PANEL_CELL so a long strip gets several lights
			var cells := {}
			for i in g:
				var a := tris[i * 3]
				var b := tris[i * 3 + 1]
				var c := tris[i * 3 + 2]
				var nrm := (b - a).cross(c - a)
				var area := nrm.length() * 0.5
				if area < 0.0001:
					continue
				var mid := (a + b + c) / 3.0
				if _bounds.size != Vector3.ZERO and not _bounds.has_point(mid):
					continue
				var zi := zone_of(mid)
				if not _zones.is_empty() and zi < 0:
					continue          # REV 693: outside every zone (the rest of the deck stays classic)
				var ck := Vector3i(floori(mid.x / PANEL_CELL), floori(mid.y / PANEL_CELL), floori(mid.z / PANEL_CELL))
				if not cells.has(ck):
					cells[ck] = [Vector3.ZERO, Vector3.ZERO, 0.0, zi]
				var e: Array = cells[ck]
				e[0] += mid * area
				e[1] += nrm.normalized() * area
				e[2] += area
			for e in cells.values():
				var area: float = e[2]
				if area < 0.02:
					continue
				pieces.append([e[0] / area, (e[1] as Vector3).normalized(), area, col, fixture, int(e[3])])
	# REV 551: every fixture gets one light (its biggest piece) before any gets a second - biggest-first
	# alone gave the long lane strips every light and the seating area's dome lamps none. The rest are
	# left to glow (and to the bounced light).
	pieces.sort_custom(func(x, y): return float(x[2]) > float(y[2]))
	var firsts: Array = []
	var seconds: Array = []
	var lit := {}
	for pc in pieces:
		if lit.has(pc[4]):
			seconds.append(pc)
		else:
			lit[pc[4]] = true
			firsts.append(pc)
	var order: Array = firsts + seconds
	# REV 693: with zones, each zone gets its own budget (they're never lit together)
	if not _zones.is_empty():
		var per := {}
		var kept: Array = []
		for pc in order:
			var zi: int = pc[5]
			if int(per.get(zi, 0)) < ZONE_MAX_LIGHTS:
				per[zi] = int(per.get(zi, 0)) + 1
				kept.append(pc)
		order = kept
	var count := mini(order.size(), MAX_LIGHTS if _zones.is_empty() else order.size())
	var low := 0
	var rank_in_zone := {}
	for i in count:
		var pc: Array = order[i]
		var zi: int = pc[5]
		var rank := int(rank_in_zone.get(zi, 0))
		rank_in_zone[zi] = rank + 1
		var nrm: Vector3 = pc[1]
		if nrm.length() < 0.5:
			nrm = Vector3.DOWN
		var l := OmniLight3D.new()
		l.name = "PanelLight%d" % i
		l.light_color = pc[3]
		l.light_energy = clampf(float(pc[2]) * LIGHT_ENERGY, LIGHT_MIN_ENERGY, LIGHT_MAX_ENERGY)
		l.omni_range = LIGHT_RANGE
		l.omni_attenuation = 1.2
		l.light_specular = 0.6
		l.light_volumetric_fog_energy = 0.6
		l.light_bake_mode = Light3D.BAKE_DYNAMIC
		l.shadow_enabled = rank < MAX_SHADOWED
		l.set_meta("_vf_rank", rank)
		l.shadow_bias = 0.06
		l.shadow_normal_bias = 1.2
		l.omni_shadow_mode = OmniLight3D.SHADOW_CUBE
		add_child(l)
		l.global_position = (pc[0] as Vector3) + nrm * LIGHT_STANDOFF
		if _low_light(l.global_position) or nrm.y > UP_FACING:
			l.light_cull_mask = NOT_PEOPLE      # REV 578: the room, not the faces
			low += 1
		_lights.append(l)
		_light_zone.append(zi)
	print("ModernLighting: %d light panels, %d lights (%d with shadows, %d low - room only)" % [pieces.size(), count, mini(count, MAX_SHADOWED), low])


func _find(parent: PackedInt32Array, i: int) -> int:
	while parent[i] != i:
		parent[i] = parent[parent[i]]
		i = parent[i]
	return i


func _union(parent: PackedInt32Array, a: int, b: int) -> void:
	var ra := _find(parent, a)
	var rb := _find(parent, b)
	if ra != rb:
		parent[ra] = rb


## ---- zones (REV 693) ----------------------------------------------------------------------------
## Which zone a world point is in (-1 = none, or no zones). `grow` widens every box (m) - the room uses it so the look
## doesn't flick on and off as you stand in a doorway.
func zone_of(p: Vector3, grow := 0.0) -> int:
	for i in _zones.size():
		for b: AABB in _zones[i]:
			if b.grow(grow).has_point(p):
				return i
	return -1


func _low_light(p: Vector3) -> bool:
	return p.y - floor_y < LOW_LIGHT_Y


## The room says where the player is; only that zone's lamps, gels and probe are on, and the look itself is on only
## inside a zone.
func set_zone(z: int) -> void:
	if z == zone and enabled == (z >= 0 or _zones.is_empty()):
		return
	zone = z
	if not _zones.is_empty():
		enabled = z >= 0
	_refresh_visibility()


func _in_zone(zi: int) -> bool:
	return _zones.is_empty() or zi < 0 or zi == zone


func _refresh_visibility() -> void:
	for i in _lights.size():
		if is_instance_valid(_lights[i]):
			_lights[i].visible = _modern and _in_zone(_light_zone[i] if i < _light_zone.size() else -1)
	for i in _gels.size():
		if is_instance_valid(_gels[i]):
			_gels[i].visible = _modern and _in_zone(_gel_zone[i])
	for i in _probes.size():
		if is_instance_valid(_probes[i]):
			_probes[i].visible = _modern and _in_zone(_probe_zone[i])
	if _probe != null:
		_probe.visible = _modern


## A coloured GEL light: the room's TOS theatrical wash (ModelRoom.ROOM_MOODS spots) as a real spot light, so the
## colour actually lands on the walls, shines on the metal and glows in the haze. Gels never cast shadows (cheap on
## older cards); only those marked `people` reach faces - the rest light the room alone (coloured faces looked ruddy).
func add_gel(zi: int, from: Vector3, at: Vector3, angle_deg: float, reach: float, colour: Color, strength: float,
		people: bool) -> void:
	var l := SpotLight3D.new()
	l.name = "Gel%d" % _gels.size()
	add_child(l)
	l.global_position = from
	var dir := (at - from).normalized()
	l.look_at(at, Vector3.UP if absf(dir.y) < 0.98 else Vector3.FORWARD)
	l.spot_angle = clampf(angle_deg, 5.0, 85.0)
	l.spot_angle_attenuation = 0.8         # soft edges - washes, never visible circles (Glen)
	l.spot_range = maxf(reach, GEL_RANGE_MIN)
	l.spot_attenuation = 1.1
	l.light_color = colour
	l.light_energy = strength * GEL_ENERGY
	l.light_specular = 0.5
	l.light_volumetric_fog_energy = 1.2    # the beams show in the haze (HIGH)
	l.light_bake_mode = Light3D.BAKE_DYNAMIC
	l.shadow_enabled = false
	if not people or _low_light(from) or dir.y > UP_FACING:
		l.light_cull_mask = NOT_PEOPLE
	l.visible = _modern and _in_zone(zi)
	_gels.append(l)
	_gel_zone.append(zi)


## One reflection probe over the whole room, for reflections the screen can't see (SSR fills the rest).
## REV 693: with zones, one probe per zone instead (a probe the size of a whole deck reflects nonsense).
func _add_probe(map: Node3D) -> void:
	if not _zones.is_empty():
		for i in _zones.size():
			var zb := AABB()
			var first_box := true
			for b: AABB in _zones[i]:
				zb = b if first_box else zb.merge(b)
				first_box = false
			if first_box:
				continue
			var pr := ReflectionProbe.new()
			pr.name = "ZoneReflections%d" % i
			pr.update_mode = ReflectionProbe.UPDATE_ONCE
			pr.interior = true
			pr.box_projection = true
			pr.size = zb.size
			pr.intensity = 0.8
			pr.ambient_mode = ReflectionProbe.AMBIENT_DISABLED
			pr.visible = false
			add_child(pr)
			pr.global_position = zb.get_center()
			_probes.append(pr)
			_probe_zone.append(i)
		return
	var box := AABB()
	var first := true
	for s in _surfaces:
		var mi: MeshInstance3D = s[0]
		var b := mi.global_transform * mi.get_aabb()
		box = b if first else box.merge(b)
		first = false
	if first:
		return
	_probe = ReflectionProbe.new()
	_probe.name = "RoomReflections"
	_probe.update_mode = ReflectionProbe.UPDATE_ONCE
	_probe.interior = true
	_probe.box_projection = true
	_probe.size = box.size
	_probe.intensity = 0.8
	_probe.ambient_mode = ReflectionProbe.AMBIENT_DISABLED
	add_child(_probe)
	_probe.global_position = box.get_center()
	_probe.origin_offset = Vector3.ZERO


## ---- switching ----------------------------------------------------------------------------------
func _tier() -> int:
	return clampi(GameSettings.quality_preset, 0, 2) if GameSettings.quality_preset < 3 else 2


func _wanted() -> bool:
	return enabled and supported() and GameSettings.enhanced_lighting and _tier() >= 1 and not _surfaces.is_empty()


func _process(_delta: float) -> void:
	if _shooting:
		return
	var want := _wanted()
	if want != _modern:
		set_modern(want)
	elif _modern:
		_apply_env()           # quality changes (MEDIUM / HIGH)
	if _modern and _key != null:
		_tag_clock -= _delta
		if _tag_clock <= 0.0:
			_tag_clock = 0.5
			_tag_new_people()
		_aim_key()


## REV 681 (performance pass): searching the whole room (thousands of map meshes) twice a second made a small
## hitch on big decks. Now the room is searched once, and after that only meshes added since are looked at.
var _new_meshes: Array = []
var _tag_hooked := false


func _tag_new_people() -> void:
	var room := get_parent()
	if room == null:
		return
	if not _tag_hooked:
		_tag_hooked = true
		get_tree().node_added.connect(_on_node_added)
		_tag_people(room)
		return
	# everyone with a blocker (the people) is checked each time too - cheap, and catches a body whose skin is
	# set some time after it was added
	for b in get_tree().get_nodes_in_group(CharacterBlocker.GROUP):
		var fig := (b as Node).get_parent()
		if fig != null and not fig.has_meta("_vf_key_done") and room.is_ancestor_of(fig):
			var any := false
			for m in fig.find_children("*", "MeshInstance3D", true, false):
				_tag_one(m as MeshInstance3D)
				any = any or (m as Node).has_meta("_vf_key")
			if any:
				fig.set_meta("_vf_key_done", true)
	if _new_meshes.is_empty():
		return
	var batch := _new_meshes
	_new_meshes = []
	for m in batch:
		if is_instance_valid(m) and (m as Node).is_inside_tree() and room.is_ancestor_of(m):
			_tag_one(m as MeshInstance3D)


func _on_node_added(n: Node) -> void:
	if n is MeshInstance3D:
		_new_meshes.append(n)


func _tag_one(mi: MeshInstance3D) -> void:
	if mi.has_meta("_vf_key") or mi.skin == null and String(mi.skeleton) in ["", ".."]:
		return
	mi.layers = (mi.layers & ~1) | CHAR_LAYER
	mi.set_meta("_vf_key", true)


## REV 560: every skinned mesh in the room (the people - characters come and go, so this runs twice a second)
## also draws on CHAR_LAYER, so the key light reaches them and nothing else.
func _tag_people(node: Node) -> void:
	if node == null:
		return
	for m in node.find_children("*", "MeshInstance3D", true, false):
		var mi := m as MeshInstance3D
		if mi.has_meta("_vf_key") or mi.skin == null and String(mi.skeleton) in ["", ".."]:
			continue
		mi.layers = (mi.layers & ~1) | CHAR_LAYER      # REV 578: off the room layer (see NOT_PEOPLE)
		mi.set_meta("_vf_key", true)


## REV 560: the key comes from just above and beside the camera, whichever camera is live.
func _aim_key() -> void:
	var cam := get_viewport().get_camera_3d()
	if cam == null:
		return
	var fwd := -cam.global_transform.basis.z
	var right := cam.global_transform.basis.x
	var dir := fwd.rotated(right, deg_to_rad(-KEY_DOWN_DEG)).rotated(Vector3.UP, deg_to_rad(KEY_SIDE_DEG))
	if dir.length() < 0.01:
		return
	_key.global_transform = Transform3D(Basis.looking_at(dir.normalized(), Vector3.UP if absf(dir.normalized().y) < 0.98 else Vector3.FORWARD), _key.global_position)


func is_modern() -> bool:
	return _modern


## REV 552: the brightness dial, or -1 when this room isn't in MODERN (for BuildInfo's LIGHT line).
func dial() -> float:
	return brightness if _modern else -1.0


## REV 552: nudge the brightness dial (0.5-2.5) and apply it straight away.
func nudge_brightness(step: float) -> void:
	brightness = clampf(snappedf(brightness + step, 0.05), 0.5, 2.5)
	_env_tier = -1
	if _modern:
		_apply_env()
	print("Modern lighting brightness: x%.2f  ([ darker, ] brighter)" % brightness)


## REV 668: set this room's dimmer and apply it straight away.
func set_room_dim(v: float) -> void:
	room_dim = maxf(v, 0.05)
	_env_tier = -1
	if _modern and _env != null:
		_apply_env()


func set_modern(on: bool) -> void:
	_modern = on
	if on:
		sync_classic()
	for s in _surfaces:
		var mi: MeshInstance3D = s[0]
		if is_instance_valid(mi):
			mi.set_surface_override_material(int(s[1]), s[3] if on else s[2])
	_refresh_visibility()       # REV 693: lamps, gels and probes - only the current zone's
	if _key != null:
		_key.visible = on
	if _sun != null:
		_sun.light_energy = SUN_ENERGY if on else _sun_energy
	if _env == null:
		return
	if on:
		# take the environment back from LookEnhancer, as authored, then add the modern look
		if _env.has_meta("_vf_look_original"):
			LookEnhancer._restore(_env, _env.get_meta("_vf_look_original"))
		if _env.has_meta("_vf_look_applied"):
			_env.remove_meta("_vf_look_applied")
		if _env_orig.is_empty():
			for key in ENV.keys():
				_env_orig[key] = _env.get(key)
		_env.set_meta(MARK, true)
		_apply_env()
	else:
		for key in _env_orig.keys():
			_env.set(key, _env_orig[key])
		if _env.has_meta(MARK):
			_env.remove_meta(MARK)
		LookEnhancer.refresh()            # the ordinary enhanced (or classic) look again


var _env_tier := -1

func _apply_env() -> void:
	var t := _tier()
	if t == _env_tier and _env.get_meta(MARK, false):
		return
	_env_tier = t
	if classic_base:
		_apply_classic_env(t)
		return
	for key in ENV.keys():
		_env.set(key, ENV[key])
	_env.tonemap_exposure = float(ENV["tonemap_exposure"]) * brightness * room_dim
	for key in effects_off.keys():
		if key != "dof":
			_env.set(key, false)
	if t < 2:
		for key in MEDIUM_OFF:
			_env.set(key, false)
		_env.ssr_max_steps = MEDIUM_SSR_STEPS
	var shadowed := MAX_SHADOWED if t >= 2 else MEDIUM_SHADOWED
	for i in _lights.size():
		if is_instance_valid(_lights[i]):
			_lights[i].shadow_enabled = int(_lights[i].get_meta("_vf_rank", i)) < shadowed     # REV 693: per zone


## REV 732: the environment for a classic-based room - exactly CLASSIC's enhanced environment (LookEnhancer: its tone
## mapping, exposure, contrast, glow, SSAO, ship ambient) plus the extras: screen-space reflections, the haze on HIGH.
## No bounced light (SDFGI / the modern SSIL) - the classic base already holds the room's light, bounce only washed it.
func _apply_classic_env(t: int) -> void:
	var orig: Dictionary = _env.get_meta(LookEnhancer.ORIGINAL) if _env.has_meta(LookEnhancer.ORIGINAL) else LookEnhancer._snapshot(_env)
	if not _env.has_meta(LookEnhancer.ORIGINAL):
		_env.set_meta(LookEnhancer.ORIGINAL, orig)
	LookEnhancer._restore(_env, orig)
	LookEnhancer._enhance(_env, t, orig)
	for key in ["ssr_enabled", "ssr_max_steps", "ssr_fade_in", "ssr_fade_out", "ssr_depth_tolerance"]:
		_env.set(key, ENV[key])
	_env.sdfgi_enabled = false
	var haze := t >= 2
	for key in ["volumetric_fog_density", "volumetric_fog_albedo", "volumetric_fog_length", "volumetric_fog_anisotropy"]:
		_env.set(key, ENV[key])
	_env.volumetric_fog_enabled = haze
	_env.volumetric_fog_gi_inject = 0.0
	_env.tonemap_exposure = _env.tonemap_exposure * brightness
	for key in effects_off.keys():
		if key != "dof":
			_env.set(key, false)
	if t < 2:
		_env.ssr_max_steps = MEDIUM_SSR_STEPS
	var shadowed := MAX_SHADOWED if t >= 2 else MEDIUM_SHADOWED
	for i in _lights.size():
		if is_instance_valid(_lights[i]):
			_lights[i].shadow_enabled = int(_lights[i].get_meta("_vf_rank", i)) < shadowed


## ---- before / after pictures (debug: Shift+F7) --------------------------------------------------
func _unhandled_key_input(event: InputEvent) -> void:
	var k := event as InputEventKey
	if k == null or not k.pressed or k.echo or not OS.is_debug_build():
		return
	if k.keycode == KEY_F7 and k.shift_pressed:
		get_viewport().set_input_as_handled()
		take_before_after()
	elif k.ctrl_pressed and _modern and k.keycode >= KEY_1 and k.keycode < KEY_1 + EFFECT_KEYS.size():
		get_viewport().set_input_as_handled()
		var i: int = k.keycode - KEY_1
		var key: String = EFFECT_KEYS[i]
		if effects_off.has(key):
			effects_off.erase(key)
		else:
			effects_off[key] = true
		ConversationPresenter.dof_allowed = not effects_off.has("dof")
		_env_tier = -1
		_apply_env()
		print("Modern lighting effects off: ", effects_text())


## REV 554: which effects are switched off (for the F3 LIGHT line), "" when none.
func effects_text() -> String:
	var off: Array = []
	for i in EFFECT_KEYS.size():
		if effects_off.has(EFFECT_KEYS[i]):
			off.append(EFFECT_NAMES[i])
	return "" if off.is_empty() else "OFF: " + " ".join(off)


func take_before_after() -> void:
	if _shooting or not supported():
		return
	_shooting = true
	var was := _modern
	var hidden: Array = []
	for c in get_tree().root.find_children("*", "CanvasLayer", true, false):
		if (c as CanvasLayer).visible:
			(c as CanvasLayer).visible = false
			hidden.append(c)
	var dir := "user://screenshots/"
	DirAccess.make_dir_recursive_absolute(dir)
	var stamp := Time.get_datetime_string_from_system().replace(":", "-").replace("T", "_")
	set_modern(false)
	for i in 20:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var before := get_viewport().get_texture().get_image()
	set_modern(true)
	for i in 90:          # the bounced light takes a moment to settle
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var after := get_viewport().get_texture().get_image()
	set_modern(was)
	for c in hidden:
		if is_instance_valid(c):
			(c as CanvasLayer).visible = true
	_shooting = false
	var w := before.get_width()
	var h := before.get_height()
	var both := Image.create(w * 2, h, false, before.get_format())
	both.blit_rect(before, Rect2i(0, 0, w, h), Vector2i(0, 0))
	both.blit_rect(after, Rect2i(0, 0, w, h), Vector2i(w, 0))
	before.save_png(dir + "lighting_%s_before.png" % stamp)
	after.save_png(dir + "lighting_%s_after.png" % stamp)
	both.save_png(dir + "lighting_%s_side_by_side.png" % stamp)
	var where := ProjectSettings.globalize_path(dir)
	print("Lighting before/after saved in ", where)
	MissionLog.notification_requested.emit("LIGHTING PICTURES SAVED: " + where)
