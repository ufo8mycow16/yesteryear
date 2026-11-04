extends Node3D
class_name WarpTunnel
## REV 237 (the teaser): a warp effect in the style of Strange New Worlds - flashy, bright, filmic.
##
##   * the tunnel: thousands of light streaks rushing past along the line of travel, teal and azure with
##     white-cyan highlights (COLOR_A/B/C below; REV 293: this line used to say blue-white with a violet
##     and warm edge, from before REV 237/239), brightest near the camera, fading into the distance;
##   * the core: the blazing point the ship is heading into, with a wide anamorphic lens streak and a
##     soft halo (bright enough to bloom);
##   * the nebula: a glowing cloud with the core at its heart (the moment before the jump);
##   * a cool light from the core that washes over the hull, and moving glints of the tunnel's light
##     that run along it from bow to stern (REV 246, in place of the warp bubble - Glen: no bubble).
## Everything is a number below. It is driven by its owner every frame (update()), never by its own
## clock, so a recording made with the movie maker is the same every time.
##
##   var warp := WarpTunnel.new()
##   world.add_child(warp)
##   warp.update(camera, t, {"tunnel": 1.0, "core": 1.0, "nebula": 0.0}, ship)
##
## WarpTunnel.screen_material() is the same tunnel drawn flat, for a viewscreen.

## The line of travel (the ship flies along -Z, nose first).
const DIRECTION := Vector3(0, 0, -1)
const TUNNEL_RADIUS := 16.0
const TUNNEL_LENGTH := 520.0
const TUNNEL_BEHIND := 40.0          # how far the tunnel reaches behind the camera
# (REV 293: STREAK_SPEED removed - nothing read it; the streaks' speed is the time and "speed" amount passed to update().)
const CORE_DISTANCE := 420.0         # how far ahead the core sits
const CORE_SIZE := 100.0
const NEBULA_DISTANCE := 460.0
const NEBULA_SIZE := 900.0
const COLOR_A := Color(0.12, 0.85, 0.88)     # teal (Strange New Worlds)
const COLOR_B := Color(0.30, 0.58, 1.0)      # azure
const COLOR_C := Color(0.85, 1.0, 1.0)       # white-cyan highlights
const CORE_COLOR := Color(0.75, 0.97, 1.0)
const LIGHT_COLOR := Color(0.60, 0.92, 1.0)
const LIGHT_ENERGY := 0.9
## REV 246: the glints - lights that ride along the hull with the streaks (no bubble any more, Glen).
## How many, how far out from the hull's middle line (x the ship's half-width), how long each one's run
## from bow to stern takes (seconds at speed 1), their reach and brightness.
const GLINT_COUNT := 5
const GLINT_OUT := 1.35
const GLINT_RUN := 1.7
const GLINT_RANGE := 3.2
const GLINT_ENERGY := 1.6
const GLINT_COLORS := [Color(0.35, 0.95, 1.0), Color(0.45, 0.7, 1.0), Color(0.8, 1.0, 1.0)]

var _tube: MeshInstance3D
var _tube_mat: ShaderMaterial
var _core: MeshInstance3D
var _core_mat: ShaderMaterial
var _nebs: Array[MeshInstance3D] = []
## The nebula's layers, back to front: [distance from the main nebula distance (+ = further), size,
## pattern seed, brightness, pattern scale, stars]. Different depths, so a push-in shows depth.
const NEBULA_LAYERS := [
	[140.0, 1.3, 0.0, 0.85, 2.4, 1.0],
	[0.0, 1.0, 1.7, 0.9, 3.0, 0.0],
	[-130.0, 0.78, 3.3, 0.5, 3.8, 0.0],
]
var _glints: Array[OmniLight3D] = []
var _light: DirectionalLight3D


func _ready() -> void:
	name = "WarpTunnel"
	_build()


func _build() -> void:
	# the tunnel: an open cylinder along the line of travel, seen from inside
	_tube = MeshInstance3D.new()
	_tube.name = "Tube"
	var cyl := CylinderMesh.new()
	cyl.top_radius = TUNNEL_RADIUS
	cyl.bottom_radius = TUNNEL_RADIUS
	cyl.height = TUNNEL_LENGTH
	cyl.radial_segments = 96
	cyl.rings = 24
	cyl.cap_top = false
	cyl.cap_bottom = false
	_tube.mesh = cyl
	_tube_mat = ShaderMaterial.new()
	_tube_mat.shader = _shader(TUBE_SHADER)
	_tube_mat.set_shader_parameter("col_a", COLOR_A)
	_tube_mat.set_shader_parameter("col_b", COLOR_B)
	_tube_mat.set_shader_parameter("col_c", COLOR_C)
	_tube_mat.set_shader_parameter("tube_length", TUNNEL_LENGTH)
	_tube.material_override = _tube_mat
	_tube.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_tube.extra_cull_margin = 1000.0
	add_child(_tube)

	for i in NEBULA_LAYERS.size():
		var l: Array = NEBULA_LAYERS[i]
		var nq := _quad("Nebula%d" % i, NEBULA_SIZE * float(l[1]), NEBULA_SHADER)
		var nm := nq.material_override as ShaderMaterial
		nm.set_shader_parameter("seed", float(l[2]))
		nm.set_shader_parameter("gain", float(l[3]))
		nm.set_shader_parameter("scale", float(l[4]))
		nm.set_shader_parameter("stars", float(l[5]))
		nq.set_meta("depth", float(l[0]))
		_nebs.append(nq)
	_core = _quad("Core", CORE_SIZE, CORE_SHADER)
	_core_mat = _core.material_override as ShaderMaterial
	_core_mat.set_shader_parameter("core_col", CORE_COLOR)

	for i in GLINT_COUNT:
		var g := OmniLight3D.new()
		g.name = "Glint%d" % i
		g.light_color = GLINT_COLORS[i % GLINT_COLORS.size()]
		g.omni_range = GLINT_RANGE
		g.omni_attenuation = 1.6
		g.shadow_enabled = false
		g.light_specular = 1.6       # mostly a moving highlight on the hull, little flat wash
		g.light_energy = 0.0
		g.visible = false
		add_child(g)
		_glints.append(g)

	_light = DirectionalLight3D.new()
	_light.name = "WarpLight"
	_light.light_color = LIGHT_COLOR
	_light.light_energy = 0.0
	_light.shadow_enabled = false
	add_child(_light)


func _quad(n: String, size: float, code: String) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.name = n
	var q := QuadMesh.new()
	q.size = Vector2(size, size)
	mi.mesh = q
	var m := ShaderMaterial.new()
	m.shader = _shader(code)
	mi.material_override = m
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.extra_cull_margin = 1000.0
	mi.visible = false
	add_child(mi)
	return mi


static var _shaders := {}
static func _shader(code: String) -> Shader:
	if not _shaders.has(code):
		var s := Shader.new()
		s.code = code
		_shaders[code] = s
	return _shaders[code]


## Place and drive everything for this frame.
## amounts: "tunnel" (0-1, the streaks), "core" (0-1+, the blazing point; above 1 = the flash),
## "nebula" (0-1), "speed" (1 = normal streak speed), "light" (0-1, the core's light on the hull),
## "glints" (0-1, the tunnel's light running along the hull; the tunnel amount if not given).
func update(cam: Camera3D, t: float, amounts: Dictionary, ship: Node3D = null) -> void:
	if cam == null:
		return
	var tunnel := float(amounts.get("tunnel", 0.0))
	var core := float(amounts.get("core", 0.0))
	var neb := float(amounts.get("nebula", 0.0))
	var speed := float(amounts.get("speed", 1.0))
	var cp := cam.global_position
	var dir := DIRECTION

	# tunnel: its axis runs along the line of travel through the camera (the camera is inside it)
	_tube.visible = tunnel > 0.001
	if _tube.visible:
		var centre := cp + dir * (TUNNEL_LENGTH * 0.5 - TUNNEL_BEHIND)
		# the cylinder's +Y end turned to +Z: the near end, behind the camera
		_tube.global_transform = Transform3D(Basis(Vector3.RIGHT, deg_to_rad(90.0)), centre)
		_tube_mat.set_shader_parameter("amount", tunnel)
		_tube_mat.set_shader_parameter("t", t * speed)
		# how far along the tube the camera is (0 = the near end): the streaks are brightest round it
		_tube_mat.set_shader_parameter("cam_v", TUNNEL_BEHIND / TUNNEL_LENGTH)

	# the core and the nebula sit far ahead on the line of travel, facing the camera
	# a fixed place in space ("anchor"), or always the same distance ahead of the camera
	var anchor: Vector3 = amounts.get("anchor", Vector3.INF)
	var ahead := cp + dir * CORE_DISTANCE if anchor == Vector3.INF else anchor
	_core.visible = core > 0.001
	if _core.visible:
		_core.global_transform = Transform3D(_facing_basis(cam), ahead)
		_core_mat.set_shader_parameter("amount", core)
		_core_mat.set_shader_parameter("t", t)
	for nq in _nebs:
		nq.visible = neb > 0.001
		if not nq.visible:
			continue
		var depth: float = float(nq.get_meta("depth", 0.0))
		var at := (cp + dir * (NEBULA_DISTANCE + depth)) if anchor == Vector3.INF else anchor + dir * (NEBULA_DISTANCE - CORE_DISTANCE + depth)
		nq.global_transform = Transform3D(_facing_basis(cam), at)
		var nm := nq.material_override as ShaderMaterial
		nm.set_shader_parameter("amount", neb)
		nm.set_shader_parameter("t", t)

	# the glints: each light runs along the hull from bow to stern at its own place round it, fading in
	# and out at the ends of its run, so highlights slide over the saucer and nacelles with the streaks
	var glints := float(amounts.get("glints", tunnel))
	var glints_on := glints > 0.001 and ship != null and is_instance_valid(ship) and ship.visible
	if glints_on:
		var box := _ship_box_local(ship)
		var c := box.get_center()
		var half := box.size * 0.5
		for i in _glints.size():
			var g := _glints[i]
			g.visible = true
			var seed := float(i) * 0.6180339 + 0.13
			var ph := fposmod(t * speed / GLINT_RUN + seed * 3.7, 1.0)
			var ang := TAU * fposmod(seed * 2.3, 1.0) + 0.35 * sin(t * 0.7 + float(i))
			var p := c + Vector3(cos(ang) * half.x * GLINT_OUT, sin(ang) * half.y * GLINT_OUT * 1.2 + half.y * 0.3, lerpf(-half.z * 1.25, half.z * 1.25, ph))
			g.global_position = ship.global_transform * p
			g.light_energy = GLINT_ENERGY * glints * sin(PI * ph) * (0.7 + 0.3 * sin(t * 9.0 + seed * 20.0))
	else:
		for g in _glints:
			g.visible = false

	# the core's light on the hull, from ahead
	var lit: float = float(amounts.get("light", core)) if amounts.has("light") else maxf(core, tunnel * 0.6)
	_light.light_energy = LIGHT_ENERGY * clampf(lit, 0.0, 1.5)
	_light.global_transform = Transform3D(Basis.looking_at(-dir, Vector3.UP), cp)


## A basis that faces the camera (for the flat cards).
static func _facing_basis(cam: Camera3D) -> Basis:
	var z := cam.global_basis.z
	var up := cam.global_basis.y
	return Basis.looking_at(-z, up)


var _box_cache := {}
## The ship's bounds in its own space (worked out once).
func _ship_box_local(ship: Node3D) -> AABB:
	var local: AABB
	if _box_cache.has(ship):
		local = _box_cache[ship]
	else:
		var inv := ship.global_transform.affine_inverse()
		var first := true
		for m in ship.find_children("*", "MeshInstance3D", true, false):
			var mi := m as MeshInstance3D
			if mi.mesh == null or String(mi.name).begins_with("NavLight"):
				continue
			var b: AABB = (inv * mi.global_transform) * mi.get_aabb()
			local = b if first else local.merge(b)
			first = false
		if first:
			local = AABB(Vector3(-2, -1, -5), Vector3(4, 2, 10))
		_box_cache[ship] = local
	return local


## The tunnel drawn flat, for a viewscreen: streaks radiating out from the middle, the core in the
## middle. Set its "t" every frame (or leave it: it falls back to TIME).
static func screen_material() -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = _shader(SCREEN_SHADER)
	m.set_shader_parameter("col_a", COLOR_A)
	m.set_shader_parameter("col_b", COLOR_B)
	m.set_shader_parameter("col_c", COLOR_C)
	return m


# ---------------------------------------------------------------------------------------- shaders

## REV 239 (Glen: the nebula looked blocky, the tunnel and bubble needed refining). The old shaders made
## their random patterns with fract(sin(x) * 43758) - on real graphics cards sin() of a big number is
## worked out with a fast, rough approximation, so the "random" values came out in flat patches and the
## nebula broke into straight-edged shards (the software renderer used for test renders is exact, which is
## why the renders looked smooth). Every pattern now uses a hash with no sin() in it (Dave Hoskins'
## "hash without sine") and smooth gradient noise, and keeps its numbers small.
const NOISE_LIB := """
float hash12(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * 0.1031);
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.x + p3.y) * p3.z);
}
vec2 hash22(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * vec3(0.1031, 0.1030, 0.0973));
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.xx + p3.yz) * p3.zy);
}
float hash11(float x) {
	x = fract(x * 0.1031);
	x *= x + 33.33;
	x *= x + x;
	return fract(x);
}
// gradient noise, 0..1, no grid seams; per = how many cells before it repeats across x (0 = never)
float gnoise(vec2 p, float per) {
	vec2 i = floor(p), f = fract(p);
	vec2 u = f * f * f * (f * (f * 6.0 - 15.0) + 10.0);
	vec2 i1 = i + vec2(1.0, 0.0), i2 = i + vec2(0.0, 1.0), i3 = i + vec2(1.0, 1.0);
	if (per > 0.0) { i.x = mod(i.x, per); i1.x = mod(i1.x, per); i2.x = mod(i2.x, per); i3.x = mod(i3.x, per); }
	// keep the numbers fed to the hash small (precision)
	i.y = mod(i.y, 2048.0); i1.y = mod(i1.y, 2048.0); i2.y = mod(i2.y, 2048.0); i3.y = mod(i3.y, 2048.0);
	float a = dot(hash22(i) * 2.0 - 1.0, f);
	float b = dot(hash22(i1) * 2.0 - 1.0, f - vec2(1.0, 0.0));
	float c = dot(hash22(i2) * 2.0 - 1.0, f - vec2(0.0, 1.0));
	float d = dot(hash22(i3) * 2.0 - 1.0, f - vec2(1.0, 1.0));
	return clamp(0.5 + 0.75 * mix(mix(a, b, u.x), mix(c, d, u.x), u.y), 0.0, 1.0);
}
"""

const TUBE_SHADER := """shader_type spatial;
render_mode unshaded, blend_add, cull_disabled, depth_draw_never, shadows_disabled, fog_disabled;
// REV 237/239 (Glen's Strange New Worlds reference): a tunnel FILLED with light - soft, wide,
// motion-blurred bands of teal and azure rushing past with a slow twist, sharper white-cyan streaks on
// top (bright heads, fading tails), and a glow that deepens into the core's light far ahead instead of
// going dark round it.
uniform float amount = 1.0;
uniform float t = 0.0;
uniform float cam_v = 0.08;
uniform float tube_length = 520.0;
uniform vec3 col_a : source_color;     // teal
uniform vec3 col_b : source_color;     // azure
uniform vec3 col_c : source_color;     // white-cyan
varying float along;      // 0 at the far end of the tube, 1 at the near end (behind the camera)
varying vec3 lp;
void vertex() {
	along = VERTEX.y / tube_length + 0.5;
	lp = VERTEX;
}
""" + NOISE_LIB + """
// sharp streaks: lanes round the tube, dashes rushing toward the camera. Lanes too thin for a pixel
// fade out instead of flickering (the far end, where hundreds of lanes squeeze into a few pixels).
vec3 streaks(float around, float y, float lanes, float seed, float spd, float dens, float tt) {
	float x = around * lanes;
	float lane = floor(x);
	float lx = fract(x);
	float px = fwidth(x);
	float r1 = hash11(lane + seed * 17.0), r2 = hash11(lane * 1.7 + seed + 9.1), r3 = hash11(lane * 2.3 + seed + 4.4);
	if (r1 > dens) return vec3(0.0);
	// REV 246 (Glen: softer): wide lanes with a soft, glowing cross-section rather than a hard-edged line
	float w = mix(0.16, 0.34, r2) + px * 0.75;
	float dx = (lx - 0.5) / w;
	float across = exp(-dx * dx * 2.2);
	across *= 1.0 - smoothstep(0.35, 0.9, px);
	float v = y * mix(1.4, 3.2, r3) - mod(tt * spd * mix(0.7, 1.4, r2), 4096.0) + r3 * 7.0;
	float seg = fract(v);
	float len = mix(0.6, 0.95, r1 / dens);
	// long, smeared dashes: brightest in the middle, fading out at both ends (no sharp head)
	float k = clamp((seg - (1.0 - len)) / len, 0.0, 1.0);
	float s = pow(sin(3.14159265 * k), 2.0);
	vec3 col = mix(col_c, col_a, smoothstep(0.4, 0.9, r2));
	col = mix(col, col_b, step(0.85, r3));
	return col * s * across * mix(0.6, 1.4, r3);
}
void fragment() {
	float around = atan(lp.z, lp.x) / 6.2831853 + 0.5;
	float y = along;
	// a slow twist: the pattern turns a little as it rushes past (wraps cleanly round the tube)
	float tw = fract(around + y * 0.06 + t * 0.004);
	float tt = t;
	// soft volumetric bands, stretched hugely along the tunnel, at three sizes
	float b1 = gnoise(vec2(tw * 40.0, y * 5.0 - mod(tt * 2.0, 2048.0)), 40.0);
	float b2 = gnoise(vec2(tw * 90.0 + 13.0, y * 9.0 - mod(tt * 3.2, 2048.0)), 90.0);
	float b3 = gnoise(vec2(tw * 22.0 + 5.0, y * 3.0 - mod(tt * 1.3, 2048.0)), 22.0);
	// (render check: at lower powers the bands merged into a wall of cyan - they need dark between them)
	vec3 soft = col_a * pow(b1, 4.0) * 1.3 + col_b * pow(b2, 5.0) * 1.1 + mix(col_a, col_b, 0.5) * pow(b3, 3.0) * 0.5;
	vec3 sharp = streaks(tw, y, 160.0, 1.0, 1.6, 0.40, tt) * 0.9 + streaks(tw, y, 320.0, 7.0, 2.3, 0.28, tt) * 0.5
		+ streaks(tw, y, 80.0, 13.0, 1.2, 0.30, tt) * 1.1;
	// strongest just ahead of the camera, fading out behind it and toward the far end ...
	float near_v = 1.0 - cam_v;
	float fade_along = smoothstep(0.0, 0.5, y) * smoothstep(1.0, near_v - 0.02, y);
	// ... where the walls melt into the core's light rather than going dark round it
	float far = smoothstep(0.62, 0.0, y);
	vec3 deep = vec3(0.0, 0.012, 0.03) + (col_a * 0.06 + col_b * 0.05) * smoothstep(1.0, 0.3, y);
	vec3 glow = deep + mix(col_a, col_c, 0.4) * far * far * 0.55 + (soft * 0.5) * far;
	ALBEDO = ((soft * 0.95 + sharp * 0.85) * fade_along + glow) * amount;
}
"""

const CORE_SHADER := """shader_type spatial;
render_mode unshaded, blend_add, cull_disabled, depth_draw_never, shadows_disabled, fog_disabled;
// REV 237/239: a starburst - a white-hot point, a cyan halo, rays, a prismatic (rainbow-edged) lens ring and a
// wide anamorphic streak, as a film lens would catch it. Every part fades to nothing well inside the card
// (it used to end in a soft SQUARE edge, which showed as a boxy halo round the core).
uniform float amount = 1.0;
uniform float t = 0.0;
uniform vec3 core_col : source_color;
""" + NOISE_LIB + """
void fragment() {
	vec2 p = UV * 2.0 - 1.0;
	float r = length(p);
	float ang = atan(p.y, p.x);
	float flick = 1.0 + 0.05 * sin(mod(t, 100.0) * 23.0) + 0.04 * sin(mod(t, 100.0) * 37.0 + 1.3);
	float point = exp(-r * r * 160.0) * 16.0;
	float halo = exp(-r * 5.0) * 2.0;
	vec3 haze = vec3(0.2, 0.75, 0.85) * exp(-r * 2.4) * 0.55;
	// rays: many thin spokes of different lengths, slowly turning
	float a = (ang / 6.2831853 + 0.5) * 48.0 + mod(t * 0.15, 48.0);
	float spoke = hash11(mod(floor(a), 48.0) + 3.0);
	float rays = pow(1.0 - abs(fract(a) - 0.5) * 2.0, 18.0) * spoke * exp(-r * mix(2.5, 6.0, hash11(mod(floor(a), 48.0) + 11.0))) * 2.4;
	// a prismatic ring and a fainter ghost ring further out
	vec3 rainbow = 0.5 + 0.5 * cos(6.2831853 * (r * 4.0 + vec3(0.0, 0.33, 0.67)));
	vec3 rings = rainbow * (exp(-pow((r - 0.30) / 0.035, 2.0)) * 0.35 + exp(-pow((r - 0.58) / 0.05, 2.0)) * 0.12);
	// the anamorphic streak, wide and cyan (it may run to the card's sides, so it fades along x)
	float streak = exp(-abs(p.y) * 80.0) * exp(-abs(p.x) * 1.6) * 3.0 + exp(-abs(p.y) * 260.0) * exp(-abs(p.x) * 0.7) * 1.6;
	streak *= smoothstep(1.0, 0.7, abs(p.x));
	vec3 round_part = vec3(1.0) * point + core_col * halo + vec3(0.75, 0.95, 1.0) * rays + haze + rings;
	round_part *= smoothstep(1.0, 0.62, r);
	ALBEDO = (round_part + vec3(0.45, 0.85, 1.0) * streak) * amount * flick;
}
"""

const NEBULA_SHADER := """shader_type spatial;
render_mode unshaded, blend_add, cull_disabled, depth_draw_never, shadows_disabled, fog_disabled;
// REV 237/239: a deep-space nebula in layers (three cards at different depths, so pushing in gives depth):
// glowing hydrogen magenta and pink, violet outer veils, a little blue reflection gas, a hot pearl heart
// round the core, dark dust lanes with lit edges, fine filaments, and stars behind (some bright, with
// diffraction spikes). Smooth gradient noise with a sin-free hash (see NOISE_LIB) - no blocky shards.
uniform float amount = 1.0;
uniform float t = 0.0;
uniform float seed = 0.0;
uniform float gain = 1.0;
uniform float scale = 3.0;
uniform float stars = 0.0;      // 1 on the back layer
""" + NOISE_LIB + """
float fbm(vec2 p) {
	float v = 0.0, a = 0.5;
	mat2 rot = mat2(vec2(0.8, 0.6), vec2(-0.6, 0.8));
	for (int i = 0; i < 6; i++) { v += a * gnoise(p, 0.0); p = rot * p * 2.03 + vec2(1.7, 9.2); a *= 0.5; }
	return v;
}
float ridged(vec2 p) {
	float v = 0.0, a = 0.5;
	mat2 rot = mat2(vec2(0.8, -0.6), vec2(0.6, 0.8));
	for (int i = 0; i < 5; i++) { v += a * (1.0 - abs(gnoise(p, 0.0) * 2.0 - 1.0)); p = rot * p * 2.07 + vec2(3.1, 1.3); a *= 0.5; }
	return v;
}
vec3 star_field(vec2 uv) {
	vec3 c = vec3(0.0);
	// fine stars: one candidate per cell, placed off-centre, soft round dots
	vec2 g = floor(uv * 420.0);
	vec2 f = fract(uv * 420.0);
	if (hash12(g) > 0.988) {
		vec2 o = hash22(g + 3.1) * 0.6 + 0.2;
		float d = length(f - o);
		float b = 0.25 + 0.75 * hash12(g + 7.0);
		vec3 tint = mix(vec3(1.0, 0.85, 0.75), vec3(0.75, 0.85, 1.0), hash12(g + 9.0));
		c += tint * b * exp(-d * d * 60.0) * 1.4;
	}
	// a few bright stars with diffraction spikes
	vec2 g2 = floor(uv * 22.0);
	vec2 f2 = fract(uv * 22.0) - 0.5;
	if (hash12(g2 + 31.0) > 0.84) {
		vec2 e = f2 - (hash22(g2 + 1.0) - 0.5) * 0.6;
		float b = 0.0016 / (dot(e, e) + 0.0016) + (exp(-abs(e.y) * 300.0) + exp(-abs(e.x) * 300.0)) * exp(-length(e) * 9.0) * 0.6;
		c += vec3(0.85, 0.92, 1.0) * b * (0.4 + 0.6 * hash12(g2 + 5.0)) * 1.2;
	}
	return c;
}
void fragment() {
	vec2 p = UV * 2.0 - 1.0;
	// drift, kept small (the clock can run long in the menu)
	vec2 drift = vec2(mod(t, 600.0) * 0.008, -mod(t, 600.0) * 0.005);
	vec2 q = p * scale + vec2(seed * 3.7, seed * 1.9) + drift;
	// domain warping: the cloud folds over itself like real gas
	vec2 w = vec2(fbm(q + vec2(4.0, 1.3)), fbm(q + vec2(8.3, 2.8)));
	vec2 w2 = vec2(fbm(q + w * 1.6 + vec2(1.7, 9.2)), fbm(q + w * 1.6 + vec2(8.3, 2.8)));
	float dens = fbm(q + w2 * 1.8);
	float fil = ridged(q * 1.3 + w * 1.4);
	float r = length(p * vec2(0.8, 1.1));
	float body = exp(-r * 1.9);
	// soft density, no hard thresholds (the old smoothstep cut gave hard rims)
	float d = pow(clamp(dens * 1.25 - 0.18, 0.0, 1.0), 2.2) * body;
	float heart = exp(-r * 4.5);
	// colour by density and by distance from the heart: violet veils -> magenta -> pink -> pearl
	vec3 violet = vec3(0.30, 0.07, 0.45), magenta = vec3(0.80, 0.12, 0.48), pink = vec3(1.0, 0.48, 0.70);
	vec3 pearl = vec3(1.0, 0.90, 0.96), teal = vec3(0.40, 0.85, 1.0), blue = vec3(0.22, 0.38, 0.95);
	vec3 gas = mix(violet, magenta, smoothstep(0.02, 0.25, d));
	gas = mix(gas, pink, smoothstep(0.2, 0.6, d));
	gas = mix(gas, pearl, smoothstep(0.5, 1.0, d) * heart);
	vec3 c = gas * d * 2.1;
	// a faint violet veil everywhere in the body, so the cloud never ends in a hard rim
	c += violet * pow(dens, 3.0) * body * 0.35;
	// blue reflection gas in patches
	float refl = smoothstep(0.55, 0.85, fbm(q * 0.7 + vec2(21.0, 5.0) + w));
	c += blue * refl * body * 0.22;
	// the heart, lit by the core
	c += mix(teal, pearl, 0.6) * heart * (0.25 + d * 1.2) * 0.9;
	// fine bright filaments
	c += pink * pow(fil, 5.0) * body * 0.55;
	// dust: dark lanes across the glow, their edges lit toward the heart
	float dustn = fbm(q * 1.7 + vec2(11.0, 3.0) + w2 * 0.8);
	float dust = smoothstep(0.48, 0.72, dustn);
	float dust_edge = smoothstep(0.40, 0.50, dustn) * (1.0 - smoothstep(0.50, 0.62, dustn));
	c *= 1.0 - dust * 0.8 * smoothstep(0.0, 0.3, body);
	c += pink * dust_edge * body * heart * 0.35;
	c *= gain;
	if (stars > 0.5) {
		c += star_field(UV) * (1.0 - clamp(d * 2.5 + dust * 0.5, 0.0, 0.9));
	}
	float edge = smoothstep(1.0, 0.5, length(p));
	ALBEDO = c * amount * edge;
}
"""

const SCREEN_SHADER := """shader_type spatial;
render_mode unshaded, cull_disabled, shadows_disabled;
// the tunnel drawn flat for a viewscreen: soft bands and sharp streaks rushing out from the core
uniform float t = -1.0;
uniform float amount = 1.0;
uniform vec3 col_a : source_color;
uniform vec3 col_b : source_color;
uniform vec3 col_c : source_color;
""" + NOISE_LIB + """
vec3 streaks(float a, float lr, float lanes, float seed, float spd, float tt) {
	float x = a * lanes;
	float lane = floor(x);
	float lx = fract(x);
	float px = fwidth(x);
	float r1 = hash11(lane + seed * 17.0), r2 = hash11(lane * 1.7 + seed + 9.1), r3 = hash11(lane * 2.3 + seed + 4.4);
	if (r1 > 0.4) return vec3(0.0);
	float w = mix(0.16, 0.34, r2) + px * 0.75;
	float dx = (lx - 0.5) / w;
	float across = exp(-dx * dx * 2.2) * (1.0 - smoothstep(0.35, 0.9, px));
	float v = lr * mix(0.9, 1.6, r3) - mod(tt * spd * mix(0.7, 1.4, r2), 4096.0) + r3 * 9.0;
	float seg = fract(v);
	float s = pow(sin(3.14159265 * clamp((seg - 0.25) / 0.75, 0.0, 1.0)), 2.0);
	vec3 col = mix(col_c, col_a, smoothstep(0.4, 0.9, r2));
	return col * s * across;
}
void fragment() {
	float tt = t >= 0.0 ? t : TIME;
	vec2 p = (UV - 0.5) * vec2(1.6, 1.0);
	float r = length(p);
	float a = atan(p.y, p.x) / 6.2831853 + 0.5;
	float lr = log(r + 0.02);
	float b1 = gnoise(vec2(a * 40.0, lr * 3.0 - mod(tt * 2.0, 2048.0)), 40.0);
	float b2 = gnoise(vec2(a * 90.0 + 13.0, lr * 5.0 - mod(tt * 3.2, 2048.0)), 90.0);
	vec3 c = col_a * pow(b1, 2.5) * 1.2 + col_b * pow(b2, 3.5) * 1.0;
	c += streaks(a, lr, 120.0, 1.0, 1.8, tt) * 1.0 + streaks(a, lr, 260.0, 5.0, 2.6, tt) * 0.6;
	c *= smoothstep(0.02, 0.3, r) * 1.5;
	c += vec3(0.0, 0.03, 0.06) + (col_a * 0.25 + col_b * 0.1) * exp(-r * 3.0);
	c += vec3(0.9, 1.0, 1.0) * (exp(-r * 22.0) * 3.0 + exp(-r * 6.0) * 0.6);
	c += vec3(0.45, 0.85, 1.0) * exp(-abs(p.y) * 60.0) * exp(-abs(p.x) * 2.5) * 1.2;
	ALBEDO = c * amount;
	EMISSION = c * amount * 0.6;
}
"""
