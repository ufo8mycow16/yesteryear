extends Node3D
class_name TransporterEffect
## REV 227: THE TRANSPORTER - the classic TOS beam, made once and used for every beam-down/up.
##
## Two parts:
##
##   1. ON A PERSON (or anything): glittering gold-white sparkles in the shape of the body while the
##      body fades away (dematerialise) or fades in (materialise).
##          var beam := TransporterEffect.on(kirk_figure)
##          await beam.dematerialise()          # gone; the figure is hidden afterwards
##          ...
##          await TransporterEffect.on(fig).materialise()   # there; back to normal afterwards
##      Several people at once: TransporterEffect.beam_out([a, b, c]) / beam_in([a, b, c]).
##
##   2. THE WHOLE SCREEN: the beam swells until it covers the picture, so a room can change behind it
##      (the transport IS the loading screen), then clears at the other end.
##          await TransporterEffect.screen_to(1.0, 1.6)     # fill
##          ... change room while covered ...
##          await TransporterEffect.screen_to(0.0, 2.0)     # clear
##      The screen layer lives on the window's root, not in a room, so it carries across a room change.
##
## Sound: assets/audio/sfx/transporter_beam.wav (a stand-in made by tools/make_transporter_sfx.py
## until Glen's real one replaces it: same file name). Played through SfxManager, which also
## survives the room change.
##
## Every number that changes the look is a constant below.

const SOUND := "transporter_beam"
const SOUND_DB := -4.0

const DEMAT_SECONDS := 3.4        # sparkle up, body fades, sparkle fades
const MAT_SECONDS := 3.4
const SPARKLE_COLOR := Color(1.0, 0.88, 0.58)   # TOS gold-white
const SPARKLE_DENSITY := 55.0     # sparkle cells per metre on the body (higher = finer glitter)
const PARTICLES := 260            # free sparkles in the column around each person
const COLUMN_SIZE := Vector3(0.62, 1.95, 0.42)   # metres (before the figure's own scale)

const SCREEN_LAYER := 120         # above every game screen and fade

const BODY_SHADER := """
shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_back, shadows_disabled, fog_disabled;
uniform float intensity = 0.0;
uniform vec3 tint = vec3(1.0, 0.88, 0.58);
uniform float density = 55.0;
varying vec3 wpos;
// REV 293: sin-free hash (Dave Hoskins' "hash without sine", as WarpTunnel's NOISE_LIB since REV 239).
// The old fract(sin(x) * 43758) is worked out roughly by real graphics cards and comes out in flat
// patches (the REV 239 blocky nebula); this gives the same kind of even sparkle on any card.
float hash(vec3 p) {
	vec3 p3 = fract(p * 0.1031);
	p3 += dot(p3, p3.zyx + 31.32);
	return fract((p3.x + p3.y) * p3.z);
}
void vertex() { wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz; }
void fragment() {
	vec3 cell = floor(wpos * density);
	float h = hash(cell);
	float twinkle = sin(TIME * (6.0 + h * 16.0) + h * 40.0) * 0.5 + 0.5;
	float spark = smoothstep(0.80, 1.0, h * 0.35 + twinkle * 0.72);
	float band = 0.5 + 0.5 * sin(wpos.y * 16.0 - TIME * 8.0 + h * 2.0);
	ALBEDO = tint * (spark * 2.8 + band * 0.22 + 0.12) * intensity;
}
"""

const SCREEN_SHADER := """
shader_type canvas_item;
uniform float level = 0.0;
uniform vec3 tint = vec3(1.0, 0.88, 0.58);
// REV 293: sin-free hash (Hoskins, as WarpTunnel's NOISE_LIB) - see the body shader above.
float hash(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * 0.1031);
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.x + p3.y) * p3.z);
}
void fragment() {
	vec2 px = FRAGCOORD.xy / 4.0;
	vec2 cell = floor(px);
	float h = hash(cell);
	float twinkle = sin(TIME * (5.0 + h * 13.0) + h * 50.0) * 0.5 + 0.5;
	float need = mix(1.02, 0.5, level);                     // more glitter as the beam builds
	float spark = step(need, h * 0.3 + twinkle * 0.72) * smoothstep(0.55, 0.0, length(fract(px) - 0.5));
	float columns = 0.5 + 0.5 * sin(UV.x * 38.0 + sin(UV.y * 3.0 + TIME * 1.3) * 0.7 + TIME * 2.2);
	float fill = smoothstep(0.4, 1.0, level);
	vec3 col = mix(tint, vec3(1.0), 0.45 + 0.3 * columns);
	float a = clamp(spark * min(level * 2.0, 1.0) + fill * (0.82 + 0.18 * columns), 0.0, 1.0);
	COLOR = vec4(col * (1.0 + spark * 0.6), a);
}
"""

## Set by a room that beams people out just before it changes room; the room they arrive in
## materialises them and clears it (TuvallOffice.arrival).
static var pending_arrival := false

static var _body_shader: Shader
static var _screen_shader: Shader
static var _screen_layer: CanvasLayer = null
static var _screen_rect: ColorRect = null

var figure: Node3D
var _overlay: ShaderMaterial
var _meshes: Array[GeometryInstance3D] = []
var _particles: CPUParticles3D
var _particle_mat: StandardMaterial3D
var _level_sparkle := 0.0
var _level_body := 1.0


## The effect on one figure (made the first time, reused after).
static func on(fig: Node3D) -> TransporterEffect:
	for c in fig.get_children():
		if c is TransporterEffect:
			return c
	var fx := TransporterEffect.new()
	fx.name = "Transporter"
	fx.figure = fig
	fig.add_child(fx)
	return fx


## Everyone in `figures` dematerialises together (returns when they are gone).
static func beam_out(figures: Array, seconds: float = DEMAT_SECONDS, with_sound: bool = true) -> void:
	if with_sound:
		play_sound()
	var last: TransporterEffect = null
	for f in figures:
		if f != null:
			last = on(f)
			last.dematerialise(seconds)
	if last != null:
		await last.get_tree().create_timer(seconds, false).timeout


## Everyone in `figures` materialises together (returns when they are solid).
static func beam_in(figures: Array, seconds: float = MAT_SECONDS, with_sound: bool = true) -> void:
	if with_sound:
		play_sound()
	var last: TransporterEffect = null
	for f in figures:
		if f != null:
			last = on(f)
			last.materialise(seconds)
	if last != null:
		await last.get_tree().create_timer(seconds, false).timeout


static func play_sound() -> void:
	if SfxManager.has_sound(SOUND):
		SfxManager.play(SOUND, SOUND_DB)


# ------------------------------------------------------------------- one figure --

func _ready() -> void:
	if _body_shader == null:
		_body_shader = Shader.new()
		_body_shader.code = BODY_SHADER
	_overlay = ShaderMaterial.new()
	_overlay.shader = _body_shader
	_overlay.set_shader_parameter("tint", Vector3(SPARKLE_COLOR.r, SPARKLE_COLOR.g, SPARKLE_COLOR.b))
	_overlay.set_shader_parameter("density", SPARKLE_DENSITY)
	_build_particles()
	_apply()


## Hidden, ready to materialise (call before the room is seen, so nobody flashes into view).
func hide_now() -> void:
	_level_body = 0.0
	_level_sparkle = 0.0
	_apply()


func dematerialise(seconds: float = DEMAT_SECONDS) -> void:
	_collect_meshes()
	_set_overlay(true)
	var t := create_tween()
	# sparkle builds over the first third, the body fades through the middle, the sparkle dies away last
	t.tween_method(_set_sparkle, 0.0, 1.0, seconds * 0.3).set_trans(Tween.TRANS_SINE)
	t.parallel().tween_method(_set_body, 1.0, 0.0, seconds * 0.55).set_delay(seconds * 0.2)
	t.chain().tween_method(_set_sparkle, 1.0, 0.0, seconds * 0.45).set_trans(Tween.TRANS_SINE)
	await t.finished
	_set_overlay(false)
	_apply()


func materialise(seconds: float = MAT_SECONDS) -> void:
	_collect_meshes()
	_level_body = 0.0
	_set_overlay(true)
	_apply()
	var t := create_tween()
	t.tween_method(_set_sparkle, 0.0, 1.0, seconds * 0.3).set_trans(Tween.TRANS_SINE)
	t.parallel().tween_method(_set_body, 0.0, 1.0, seconds * 0.55).set_delay(seconds * 0.25)
	t.chain().tween_method(_set_sparkle, 1.0, 0.0, seconds * 0.4).set_trans(Tween.TRANS_SINE)
	await t.finished
	_set_overlay(false)
	_apply()


func _set_sparkle(v: float) -> void:
	_level_sparkle = v
	_apply()


func _set_body(v: float) -> void:
	_level_body = v
	_apply()


func _apply() -> void:
	if figure == null:
		return
	_collect_meshes()
	# Fully gone = hidden outright (some renderers ignore the see-through setting).
	for m in _meshes:
		if is_instance_valid(m):
			m.transparency = 1.0 - _level_body
			m.visible = _level_body > 0.01
	_overlay.set_shader_parameter("intensity", _level_sparkle)
	if _particles != null:
		_particles.emitting = _level_sparkle > 0.02
		_particle_mat.albedo_color = Color(SPARKLE_COLOR.r, SPARKLE_COLOR.g, SPARKLE_COLOR.b, clampf(_level_sparkle, 0.0, 1.0))


func _collect_meshes() -> void:
	if not _meshes.is_empty():
		return
	for n in figure.find_children("*", "GeometryInstance3D", true, false):
		if n == _particles or (n as Node).is_ancestor_of(self) or self.is_ancestor_of(n):
			continue
		_meshes.append(n as GeometryInstance3D)


func _set_overlay(on_now: bool) -> void:
	for m in _meshes:
		if is_instance_valid(m) and m is MeshInstance3D:
			(m as MeshInstance3D).material_overlay = _overlay if on_now else null


func _build_particles() -> void:
	_particles = CPUParticles3D.new()
	_particles.name = "Sparkles"
	_particles.amount = PARTICLES
	_particles.lifetime = 0.55
	_particles.local_coords = true
	_particles.emitting = false
	_particles.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	_particles.emission_box_extents = COLUMN_SIZE * 0.5
	_particles.position = Vector3(0.0, COLUMN_SIZE.y * 0.5, 0.0)
	_particles.direction = Vector3.UP
	_particles.spread = 15.0
	_particles.gravity = Vector3.ZERO
	_particles.initial_velocity_min = 0.0
	_particles.initial_velocity_max = 0.12
	_particles.scale_amount_min = 0.5
	_particles.scale_amount_max = 1.4
	var curve := Curve.new()
	curve.add_point(Vector2(0.0, 0.0))
	curve.add_point(Vector2(0.25, 1.0))
	curve.add_point(Vector2(0.6, 0.3))
	curve.add_point(Vector2(1.0, 0.0))
	_particles.scale_amount_curve = curve
	var quad := QuadMesh.new()
	quad.size = Vector2(0.03, 0.03)
	_particle_mat = StandardMaterial3D.new()
	_particle_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_particle_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_particle_mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	_particle_mat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	_particle_mat.vertex_color_use_as_albedo = true
	_particle_mat.no_depth_test = false
	_particle_mat.albedo_color = SPARKLE_COLOR
	quad.material = _particle_mat
	_particles.mesh = quad
	var ramp := Gradient.new()
	ramp.set_color(0, Color(1.0, 1.0, 1.0))
	ramp.set_color(1, Color(1.0, 0.8, 0.45))
	_particles.color_ramp = ramp
	add_child(_particles)


# ------------------------------------------------------------------- whole screen --

## Fade the full-screen beam to `level` (0 = clear, 1 = the picture fully covered) over `seconds`.
static func screen_to(level: float, seconds: float) -> void:
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null:
		return
	_ensure_screen(tree)
	var from: float = float(_screen_rect.material.get_shader_parameter("level"))
	var t := _screen_layer.create_tween()
	t.tween_method(_set_screen_level, from, level, maxf(seconds, 0.01)).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	await t.finished
	if level <= 0.001:
		_screen_layer.visible = false


## How much of the screen the beam covers now (0..1).
static func screen_level() -> float:
	if _screen_rect == null or not is_instance_valid(_screen_rect):
		return 0.0
	return float(_screen_rect.material.get_shader_parameter("level"))


static func _set_screen_level(v: float) -> void:
	if _screen_rect != null and is_instance_valid(_screen_rect):
		_screen_layer.visible = v > 0.001
		(_screen_rect.material as ShaderMaterial).set_shader_parameter("level", v)


static func _ensure_screen(tree: SceneTree) -> void:
	if _screen_layer != null and is_instance_valid(_screen_layer):
		return
	if _screen_shader == null:
		_screen_shader = Shader.new()
		_screen_shader.code = SCREEN_SHADER
	_screen_layer = CanvasLayer.new()
	_screen_layer.name = "TransporterScreen"
	_screen_layer.layer = SCREEN_LAYER
	_screen_layer.process_mode = Node.PROCESS_MODE_ALWAYS
	_screen_rect = ColorRect.new()
	_screen_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	_screen_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var mat := ShaderMaterial.new()
	mat.shader = _screen_shader
	mat.set_shader_parameter("level", 0.0)
	mat.set_shader_parameter("tint", Vector3(SPARKLE_COLOR.r, SPARKLE_COLOR.g, SPARKLE_COLOR.b))
	_screen_rect.material = mat
	_screen_layer.add_child(_screen_rect)
	tree.root.add_child(_screen_layer)
