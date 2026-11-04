extends Node3D
class_name ForceField
## REV 287: a Starfleet detention force field across a doorway (Glen's reference: the TNG doorway field -
## not a clear sheet and not blue: a faint milky haze full of small white flecks that sparkle, jump and
## fade, with the door frame's amber emitter light around it).
##
##   var f := ForceField.make(1.68, 2.4)      # width x height in metres; the sheet faces +Z / -Z
##   room.add_child(f); f.global_position = ...; f.rotation.y = ...
##   f.set_on(false, 0.4)                     # fade it out (and back on with true)
##   f.camera_hide(true)                      # just stop drawing it for a close shot (still "on")
##
## Everything is in this file: the sheet's shader, the emitter strips, a soft amber light and the hum
## (assets/audio/sfx/forcefield_hum.wav, from tools/make_forcefield_sfx.py; silent if it is missing).

const HUM := "res://assets/audio/sfx/forcefield_hum.wav"
const EMITTER_COLOR := Color(1.0, 0.62, 0.24)
const EMITTER_WIDTH := 0.03

const SHADER := """
shader_type spatial;
render_mode unshaded, blend_add, cull_disabled, depth_draw_never, shadows_disabled, fog_disabled;

uniform float power = 1.0;                    // 0 off .. 1 on
uniform vec2 size = vec2(1.7, 2.4);           // the sheet in metres (flecks stay the same real size)
uniform vec4 fleck_color : source_color = vec4(1.0, 0.97, 0.92, 1.0);
uniform vec4 haze_color : source_color = vec4(0.80, 0.76, 0.72, 1.0);
uniform float fleck_strength = 1.15;
uniform float haze_strength = 1.0;
// REV 333 (the preservation field): finer, rounder sparkles and a softer edge glow; the doorway keeps 1/1/1
uniform float fleck_scale = 1.0;              // < 1 = smaller sparkles, more of them
uniform float ragged = 1.0;                   // 0 = clean round points, 1 = the doorway's ragged flecks
uniform float edge_strength = 1.0;
uniform float density = 1.0;                  // REV 334: share of sparkle cells that light (1 = the doorway)
// REV 657 (Glen: "a forcefield that is the same shape as the device"): "shell" = the field drawn on any mesh,
// the sparkles laid out by the mesh's own points (metres = point * shell_scale), not its UVs
uniform float shell = 0.0;
uniform float shell_scale = 1.0;
varying vec3 opos;
varying vec3 onrm;
void vertex() {
	opos = VERTEX * shell_scale;
	onrm = NORMAL;
}

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

float vnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash12(i), hash12(i + vec2(1.0, 0.0)), f.x),
		mix(hash12(i + vec2(0.0, 1.0)), hash12(i + vec2(1.0, 1.0)), f.x), f.y);
}

// One layer of flecks: each grid cell (cell metres across) may hold one fleck that lives for a moment,
// then reappears somewhere else in its cell - the sparkle. Ragged little shapes, not round dots.
float flecks(vec2 m, float cell, float t, float seed, float share) {
	vec2 g = m / cell;
	vec2 id = floor(g);
	vec2 f = fract(g);
	float acc = 0.0;
	for (int y = -1; y <= 1; y++) {
		for (int x = -1; x <= 1; x++) {
			vec2 o = vec2(float(x), float(y));
			vec2 cid = id + o;
			float rate = 0.7 + 2.2 * hash12(cid * 1.7 + seed);
			float ph = hash12(cid * 3.1 + seed);
			float tt = t * rate + ph;
			float cyc = floor(tt);
			float life = fract(tt);
			if (hash12(cid + cyc * 5.31 + seed) > share * density) {
				continue;
			}
			vec2 p = o + 0.15 + 0.7 * hash22(cid + cyc * 7.13 + seed) - f;
			float ang = 6.2831 * hash12(cid * 2.3 + cyc * 3.3 + seed);
			vec2 q = vec2(cos(ang) * p.x + sin(ang) * p.y, -sin(ang) * p.x + cos(ang) * p.y);
			q.x *= 0.5 + 1.1 * hash12(cid + cyc * 1.9 + seed);
			float sz = 0.16 + 0.24 * hash12(cid * 5.7 + cyc + seed);
			float d = length(q) / sz;
			d += 0.35 * ragged * (vnoise(q * 9.0 + cid) - 0.5);          // ragged edge
			float tw = smoothstep(0.0, 0.12, life) * smoothstep(1.0, 0.5, life);
			tw *= 0.55 + 0.45 * sin(life * 40.0 + ph * 6.2831) * sin(life * 40.0 + ph * 6.2831);   // glitter
			acc += smoothstep(1.0, 0.15, d) * tw;
		}
	}
	return acc;
}

void fragment() {
	vec2 m = (UV - 0.5) * size;
	if (shell > 0.5) {
		vec3 an = abs(onrm) + vec3(0.0001, 0.0, 0.0);
		m = an.x > an.y && an.x > an.z ? opos.zy : (an.y > an.z ? opos.xz : opos.xy);
	}
	float t = TIME;
	float fs = fleck_scale;
	float a = flecks(m, 0.085 * fs, t * 1.25, 1.0, 0.62) * 0.95
		+ flecks(m, 0.05 * fs, t * 1.8, 7.0, 0.55) * 0.55
		+ flecks(m, 0.13 * fs, t * 0.75, 13.0, 0.45) * 0.75;
	// the haze: faint, slowly drifting, a little stronger in soft bands
	float haze = 0.035 + 0.035 * vnoise(m * 2.5 + vec2(0.0, t * 0.35)) + 0.025 * vnoise(m * 8.0 - vec2(t * 0.6, t * 0.2));
	haze += 0.02 * smoothstep(0.6, 1.0, vnoise(vec2(m.x * 0.8, m.y * 6.0 - t * 1.4)));
	// brighter where the sheet meets the emitters
	vec2 e = min(UV, 1.0 - UV) * size;
	// (REV 658: a shell skips this outright - a model's own UVs run far outside 0..1, exp() overflows to infinity,
	// and infinity x 0 is NaN, which drew the whole field black)
	float edge = shell > 0.5 ? 0.0 : exp(-min(e.x, e.y) / 0.05) * 0.5 * edge_strength;
	vec3 col = fleck_color.rgb * a * fleck_strength + haze_color.rgb * (haze * haze_strength + edge * 0.6);
	ALBEDO = col * power;
}
"""

var width := 1.7
var height := 2.4
## REV 332: "canopy" = an open-bottomed box of field over a biobed (Episode 2's preservation field):
## top + four sides, tinted, no amber emitters. "door" = the detention doorway (the original).
var shape := "door"
var length := 2.3
var tint := Color(0.82, 0.90, 1.0)     # REV 333: was 0.55 0.80 1.0 (Glen: less blue)
var shell_mesh: Mesh = null            # REV 657: "shell" - the field takes this mesh's shape
var shell_scale := Vector3.ONE         # ...drawn at this size (metres per mesh unit, per axis)
var shell_offset := Vector3.ZERO       # ...and moved by this much from the field's origin
var _mats: Array = []          # every sheet's material (the canopy has five)
var _sheet: MeshInstance3D
var _mat: ShaderMaterial
var _strips: Array = []
var _strip_mat: StandardMaterial3D
var _light: OmniLight3D
var _hum: AudioStreamPlayer3D
var _power := 1.0
var _on := true
var _cam_hidden := false
var _tween: Tween


## REV 332: a field over a bed: w across, l along, h tall; origin = the middle of the bed's top, faces +Z
## along its length. Pale blue by default, a soft hum.
static func canopy(w: float, l: float, h: float, col := Color(0.82, 0.90, 1.0)) -> ForceField:
	var f := ForceField.new()
	f.width = w
	f.length = l
	f.height = h
	f.tint = col
	f.shape = "canopy"
	f.name = "PreservationField"
	f._build()
	return f


## REV 657: a field that hugs an object - the same shape as `mesh`, drawn at `scl` (metres per mesh unit) and
## moved by `offset` from the field's origin. Make it a little bigger than the object itself (an inch all round).
## No emitter strips; a faint glow in `col` and a soft hum.
static func shell(mesh: Mesh, scl: Vector3, offset: Vector3, col := Color(0.82, 0.90, 1.0)) -> ForceField:
	var f := ForceField.new()
	f.shell_mesh = mesh
	f.shell_scale = scl
	f.shell_offset = offset
	f.tint = col
	f.shape = "shell"
	f.name = "ShellField"
	f._build()
	return f


static func make(w: float, h: float) -> ForceField:
	var f := ForceField.new()
	f.width = w
	f.height = h
	f.name = "ForceField"
	f._build()
	return f


func _build_canopy() -> void:
	var sh := Shader.new()
	sh.code = SHADER
	_sheet = MeshInstance3D.new()     # a holder: the field hangs under it, so hiding it hides everything
	_sheet.name = "Sheets"
	add_child(_sheet)
	var w := width
	var l := length
	var h := height
	# REV 334 (Glen: "a U shape ... like the thing Neelix is wearing" - Voyager's stasis cover): one arched
	# sheet over the bed, open at both ends - half an ellipse across (w wide, h high), l along the bed.
	const SEG := 28
	var verts := PackedVector3Array()
	var uvs := PackedVector2Array()
	var idx := PackedInt32Array()
	var arc := PackedFloat32Array()
	var run := 0.0
	var prev := Vector2(w * 0.5, 0.0)
	for i in SEG + 1:
		var a := PI * float(i) / SEG
		var p := Vector2(cos(a) * w * 0.5, sin(a) * h)
		run += p.distance_to(prev) if i > 0 else 0.0
		prev = p
		arc.append(run)
	for i in SEG + 1:
		var a := PI * float(i) / SEG
		for e in 2:
			var z := (-0.5 + float(e)) * l
			verts.append(Vector3(cos(a) * w * 0.5, sin(a) * h, z))
			uvs.append(Vector2(arc[i] / run, float(e)))
	for i in SEG:
		var k := i * 2
		idx.append_array([k, k + 1, k + 2, k + 1, k + 3, k + 2])
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_INDEX] = idx
	var am := ArrayMesh.new()
	am.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	var m := ShaderMaterial.new()
	m.shader = sh
	m.set_shader_parameter("size", Vector2(run, l))
	# REV 333/334 (Glen): clear, barely tinted, a few fine round sparkles, faint edges
	m.set_shader_parameter("fleck_color", Color(1.0, 1.0, 1.0))
	m.set_shader_parameter("haze_color", tint)
	m.set_shader_parameter("fleck_strength", 0.75)
	m.set_shader_parameter("haze_strength", 0.4)
	m.set_shader_parameter("fleck_scale", 0.4)
	m.set_shader_parameter("ragged", 0.0)
	m.set_shader_parameter("edge_strength", 0.5)
	m.set_shader_parameter("density", 0.3)
	_mats.append(m)
	var face := MeshInstance3D.new()
	face.name = "Arch"
	face.mesh = am
	face.material_override = m
	face.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_sheet.add_child(face)
	# thin pale emitter ribs along both ends of the arch, like the stasis cover's frame
	_strip_mat = StandardMaterial3D.new()
	_strip_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_strip_mat.albedo_color = Color(0.85, 0.92, 1.0)
	_strip_mat.emission_enabled = true
	_strip_mat.emission = Color(0.85, 0.92, 1.0)
	_strip_mat.emission_energy_multiplier = 1.2
	for e in [-0.5, 0.5]:
		for i in SEG:
			var a0 := PI * float(i) / SEG
			var a1 := PI * float(i + 1) / SEG
			var p0 := Vector3(cos(a0) * w * 0.5, sin(a0) * h, e * l)
			var p1 := Vector3(cos(a1) * w * 0.5, sin(a1) * h, e * l)
			var bm := BoxMesh.new()
			bm.size = Vector3(0.012, p0.distance_to(p1) + 0.004, 0.012)
			var s := MeshInstance3D.new()
			s.mesh = bm
			s.material_override = _strip_mat
			s.position = (p0 + p1) * 0.5
			s.rotation.z = atan2(p1.y - p0.y, p1.x - p0.x) - PI * 0.5
			s.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			_sheet.add_child(s)
	_mat = _mats[0]
	_light = OmniLight3D.new()
	_light.light_color = tint
	_light.light_energy = 0.2
	_light.omni_range = 2.5
	_light.shadow_enabled = false
	_light.position = Vector3(0.0, h * 0.6, 0.0)
	add_child(_light)
	if ResourceLoader.exists(HUM):
		_hum = AudioStreamPlayer3D.new()
		_hum.stream = load(HUM)
		_hum.volume_db = -20.0          # softer than a cell door: "the soft hum of the preservation field"
		_hum.pitch_scale = 0.8
		_hum.unit_size = 1.5
		_hum.max_distance = 10.0
		_hum.bus = "SFX" if AudioServer.get_bus_index("SFX") >= 0 else "Master"
		_hum.finished.connect(_hum_again)
		add_child(_hum)


func _build_shell() -> void:
	var sh := Shader.new()
	sh.code = SHADER
	_mat = ShaderMaterial.new()
	_mat.shader = sh
	_mat.set_shader_parameter("shell", 1.0)
	_mat.set_shader_parameter("shell_scale", (shell_scale.x + shell_scale.y + shell_scale.z) / 3.0)
	# the canopy's look (Glen liked it): clear, barely tinted, fine round sparkles
	_mat.set_shader_parameter("fleck_color", Color(1.0, 1.0, 1.0))
	_mat.set_shader_parameter("haze_color", tint)
	_mat.set_shader_parameter("fleck_strength", 0.8)
	_mat.set_shader_parameter("haze_strength", 0.35)       # REV 659: lighter haze, so what's inside shows
	_mat.set_shader_parameter("fleck_scale", 0.3)
	_mat.set_shader_parameter("ragged", 0.0)
	_mat.set_shader_parameter("density", 0.45)
	_sheet = MeshInstance3D.new()
	_sheet.name = "Shell"
	_sheet.mesh = shell_mesh
	_sheet.scale = shell_scale
	_sheet.position = shell_offset
	_sheet.material_override = _mat
	_sheet.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_sheet)
	_strip_mat = StandardMaterial3D.new()     # no strips - kept so power changes have something to set
	_light = OmniLight3D.new()
	_light.light_color = tint
	_light.light_energy = 0.08
	_light.omni_range = 1.2
	_light.shadow_enabled = false
	_light.position = shell_offset
	add_child(_light)
	if ResourceLoader.exists(HUM):
		_hum = AudioStreamPlayer3D.new()
		_hum.stream = load(HUM)
		_hum.volume_db = -22.0
		_hum.pitch_scale = 1.15
		_hum.unit_size = 1.2
		_hum.max_distance = 8.0
		_hum.bus = "SFX" if AudioServer.get_bus_index("SFX") >= 0 else "Master"
		_hum.finished.connect(_hum_again)
		add_child(_hum)


## REV 332: a brief surge (Chapel's "increase preservation field" test): brighter, then back.
func surge(seconds := 1.6) -> void:
	if _tween != null:
		_tween.kill()
	_tween = create_tween()
	_tween.tween_method(_set_power, _power, 2.2, seconds * 0.3)
	_tween.tween_method(_set_power, 2.2, 1.0, seconds * 0.7)


func _build() -> void:
	if shape == "canopy":
		_build_canopy()
		return
	if shape == "shell":
		_build_shell()
		return
	var sh := Shader.new()
	sh.code = SHADER
	_mat = ShaderMaterial.new()
	_mat.shader = sh
	_mat.set_shader_parameter("size", Vector2(width, height))
	var quad := QuadMesh.new()
	quad.size = Vector2(width, height)
	_sheet = MeshInstance3D.new()
	_sheet.name = "Sheet"
	_sheet.mesh = quad
	_sheet.material_override = _mat
	_sheet.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_sheet)
	# the emitters: thin amber strips down both sides and along the top, on both faces of the doorway
	_strip_mat = StandardMaterial3D.new()
	_strip_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_strip_mat.albedo_color = EMITTER_COLOR
	_strip_mat.emission_enabled = true
	_strip_mat.emission = EMITTER_COLOR
	_strip_mat.emission_energy_multiplier = 2.2
	for spec in [[Vector3(-width * 0.5, 0.0, 0.0), Vector3(EMITTER_WIDTH, height, EMITTER_WIDTH)],
			[Vector3(width * 0.5, 0.0, 0.0), Vector3(EMITTER_WIDTH, height, EMITTER_WIDTH)],
			[Vector3(0.0, height * 0.5, 0.0), Vector3(width + EMITTER_WIDTH, EMITTER_WIDTH, EMITTER_WIDTH)]]:
		var bm := BoxMesh.new()
		bm.size = spec[1]
		var s := MeshInstance3D.new()
		s.mesh = bm
		s.material_override = _strip_mat
		s.position = spec[0]
		s.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(s)
		_strips.append(s)
	_light = OmniLight3D.new()
	_light.light_color = Color(1.0, 0.82, 0.62)
	_light.light_energy = 0.35
	_light.omni_range = 3.0
	_light.shadow_enabled = false
	add_child(_light)
	if ResourceLoader.exists(HUM):
		_hum = AudioStreamPlayer3D.new()
		_hum.stream = load(HUM)
		_hum.volume_db = -14.0
		_hum.unit_size = 2.0
		_hum.max_distance = 14.0
		_hum.bus = "SFX" if AudioServer.get_bus_index("SFX") >= 0 else "Master"
		_hum.finished.connect(_hum_again)
		add_child(_hum)


func _ready() -> void:
	if _hum != null and _on:
		_hum.play()


func _hum_again() -> void:
	if _on and _hum != null and is_inside_tree():
		_hum.play()


## Switch the field on or off, fading over `seconds` (0 = at once). The hum follows.
## REV 574: dial the sparkle down (or up) for one field: fleck brightness and the share of sparkle cells
## that light (the doorway default is 1.15 / 1.0; the brig's game-over cell uses less - Glen: too intense).
func set_sparkle(strength: float, share: float) -> void:
	var all: Array = _mats.duplicate()
	if _mat != null and not all.has(_mat):
		all.append(_mat)
	for m in all:
		(m as ShaderMaterial).set_shader_parameter("fleck_strength", strength)
		(m as ShaderMaterial).set_shader_parameter("density", share)


func set_on(on: bool, seconds := 0.35) -> void:
	_on = on
	if _tween != null:
		_tween.kill()
	if on:
		_apply_visible()
		if _hum != null and not _hum.playing and is_inside_tree():
			_hum.play()
	if seconds <= 0.0:
		_set_power(1.0 if on else 0.0)
		_after_fade()
		return
	_tween = create_tween()
	_tween.tween_method(_set_power, _power, 1.0 if on else 0.0, seconds)
	_tween.tween_callback(_after_fade)


func is_on() -> bool:
	return _on


## A close shot: stop drawing the sheet, its strips and its light (the field is still "on" - the hum
## goes on, and camera_hide(false) brings it straight back).
func camera_hide(hidden: bool) -> void:
	_cam_hidden = hidden
	_apply_visible()


func _set_power(v: float) -> void:
	_power = v
	_mat.set_shader_parameter("power", v)
	for m in _mats:
		(m as ShaderMaterial).set_shader_parameter("power", v)
	_strip_mat.emission_energy_multiplier = 0.4 + 1.8 * v
	_light.light_energy = 0.35 * v


func _after_fade() -> void:
	if not _on and _hum != null:
		_hum.stop()
	_apply_visible()


func _apply_visible() -> void:
	var drawn := not _cam_hidden and (_on or _power > 0.001)
	_sheet.visible = drawn
	_light.visible = drawn
	for s in _strips:
		(s as Node3D).visible = not _cam_hidden
