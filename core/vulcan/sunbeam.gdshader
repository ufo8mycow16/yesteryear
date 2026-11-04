// REV 821: a shaft of sunlight with dust in it - an open cone (VulcanSet.sunbeam), soft at the edges and ends.
shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, shadows_disabled, fog_disabled;

uniform vec3 tint : source_color = vec3(1.0, 0.70, 0.42);
uniform float strength = 0.10;

void fragment() {
	float along = UV.y;                // 0 at the window, 1 at the floor
	float ends = smoothstep(0.0, 0.18, along) * smoothstep(1.0, 0.7, along);
	float face = abs(dot(normalize(NORMAL), normalize(VIEW)));
	float edge = pow(face, 2.2);
	float flick = 0.94 + 0.06 * sin(TIME * 0.7 + along * 5.0);
	ALBEDO = tint * strength * ends * edge * flick;
}
