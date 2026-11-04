extends Node3D
## A transporter shimmer: a column of glittering light that swells, holds and fades. beam_in() shows the
## person at the brightest moment; beam_out() hides them. One per person, freed when done.

const SHADER := """
shader_type spatial;
render_mode unshaded, blend_add, cull_disabled, depth_draw_never;
uniform float strength = 0.0;
float hash(vec2 p) { return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453); }
void fragment() {
	vec2 g = floor(UV * vec2(40.0, 120.0) + vec2(0.0, TIME * 30.0));
	float sparkle = step(0.86, hash(g + floor(TIME * 12.0)));
	float column = smoothstep(0.0, 0.15, UV.y) * smoothstep(1.0, 0.85, UV.y);
	vec3 col = vec3(0.75, 0.85, 1.0) * (sparkle * 1.6 + 0.25) * column * strength;
	ALBEDO = col;
}
"""

var _mat: ShaderMaterial


static func play(parent: Node3D, who: Node3D, at: Vector3, appearing: bool, seconds := 3.0) -> void:
	var b := (load("res://scenes/watch/Beam.gd") as Script).new() as Node3D
	parent.add_child(b)
	b.global_position = at
	await b.call("_run", who, appearing, seconds)
	b.queue_free()


func _run(who: Node3D, appearing: bool, seconds: float) -> void:
	var mi := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = 0.45
	cyl.bottom_radius = 0.45
	cyl.height = 2.2
	cyl.cap_top = false
	cyl.cap_bottom = false
	mi.mesh = cyl
	mi.position.y = 1.1
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_mat = ShaderMaterial.new()
	var sh := Shader.new()
	sh.code = SHADER
	_mat.shader = sh
	mi.material_override = _mat
	add_child(mi)
	if appearing and who != null:
		who.visible = false
	var t := create_tween()
	t.tween_method(_set_strength, 0.0, 1.0, seconds * 0.4)
	await t.finished
	if who != null:
		who.visible = appearing
	var t2 := create_tween()
	t2.tween_method(_set_strength, 1.0, 0.0, seconds * 0.6)
	await t2.finished


func _set_strength(v: float) -> void:
	_mat.set_shader_parameter("strength", v)
