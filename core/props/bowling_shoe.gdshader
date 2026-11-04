// REV 560: two-tone bowling shoes from Glen's leather shoe (assets/models/props/bowling_shoe.glb, made by
// tools/props/shoe_convert.gd). The leather picture gives the grain, stitching and creases; the colours come
// from where on the shoe a point is (the model's own metres: toe +Z, heel -Z, sole on y = 0):
//   toe cap and heel counter = cap_col, the rest of the upper = main_col, the sole and welt = sole_col.
// Like 1960s rental bowling shoes. Each colour scheme is its own material (EquipmentUnit._shoe_material).
shader_type spatial;
render_mode cull_disabled, diffuse_burley, specular_schlick_ggx;

uniform sampler2D leather : source_color, filter_linear_mipmap_anisotropic;
uniform sampler2D leather_normal : hint_normal, filter_linear_mipmap_anisotropic;
uniform vec4 main_col : source_color = vec4(0.62, 0.10, 0.09, 1.0);
uniform vec4 cap_col : source_color = vec4(0.92, 0.90, 0.85, 1.0);
uniform vec4 sole_col : source_color = vec4(0.13, 0.10, 0.08, 1.0);
uniform float leather_mean = 0.136;   // the picture's average brightness (measured) - detail is relative to it
uniform float toe_from = 0.06;        // metres: the toe cap starts here (toe at +0.135)
uniform float heel_to = -0.085;       // the heel counter ends here (heel at -0.135)
uniform float sole_top = 0.013;       // sole and welt height at the flat part
uniform float toe_spring = 0.25;      // the sole line rises with the toe (rise per metre past toe_from)
uniform float edge = 0.0015;          // half-width of the soft seam between colours

varying vec3 lp;

void vertex() {
	lp = VERTEX;
}

void fragment() {
	float g = dot(texture(leather, UV).rgb, vec3(0.299, 0.587, 0.114));
	float detail = clamp(g / leather_mean, 0.45, 1.6);
	float cap = max(smoothstep(toe_from - edge, toe_from + edge, lp.z),
			1.0 - smoothstep(heel_to - edge, heel_to + edge, lp.z));
	vec3 c = mix(main_col.rgb, cap_col.rgb, cap);
	float sole_line = sole_top + max(0.0, lp.z - toe_from) * toe_spring;
	float sole = 1.0 - smoothstep(sole_line - edge, sole_line + edge, lp.y);
	c = mix(c, sole_col.rgb, sole);
	ALBEDO = c * detail;
	NORMAL_MAP = texture(leather_normal, UV).rgb;
	ROUGHNESS = mix(0.5, 0.8, sole);
	SPECULAR = 0.45;
}
