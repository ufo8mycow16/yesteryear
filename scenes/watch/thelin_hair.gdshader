// Thelin's hair: Spock's hair cut, turned Andorian white. The original picture only gives the strand
// pattern (light and dark) and the cut-out; the colour comes from hair_color.
shader_type spatial;
render_mode cull_disabled, depth_draw_opaque, diffuse_burley, specular_schlick_ggx;

uniform sampler2D tex : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform bool has_tex = true;
uniform vec4 hair_color : source_color = vec4(0.88, 0.89, 0.92, 1.0);
uniform float lum_gain = 3.0;      // how much the picture's own light and dark shows through
uniform float use_alpha = 1.0;     // 1 = cut out where the picture is see-through
uniform float cutoff = 0.3;

void fragment() {
	vec4 t = has_tex ? texture(tex, UV) : vec4(0.2, 0.2, 0.2, 1.0);
	float l = dot(t.rgb, vec3(0.299, 0.587, 0.114));
	ALBEDO = hair_color.rgb * clamp(0.6 + l * lum_gain, 0.6, 1.08);
	ALPHA = mix(1.0, t.a, use_alpha);
	ALPHA_SCISSOR_THRESHOLD = cutoff;
	ROUGHNESS = 0.8;
	SPECULAR = 0.15;
}
