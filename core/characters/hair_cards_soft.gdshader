// REV 736 (Glen: Tuvall's hair looked grainy, like static). The second pass of card hair (hair_cards.gdshader).
// The first pass draws only the solid part of each strand picture (cut-out, so cards never flicker over each
// other) and relies on the screen's anti-aliasing to smooth the strand edges. With anti-aliasing off or FXAA,
// the many strands thinner than a pixel came out as hard on/off dots - the grain. This pass draws what the
// first one left out - the see-through fringe of every strand - softly blended on top, without writing depth,
// so the edges and fine wisps read as soft hair. Same lighting as the first pass.
shader_type spatial;
render_mode blend_mix, depth_draw_never, cull_disabled, diffuse_burley, specular_schlick_ggx;

uniform sampler2D strands : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform vec4 hair_color : source_color = vec4(0.72, 0.50, 0.34, 1.0);
uniform float cutoff : hint_range(0.0, 1.0) = 0.30;      // the first pass's cut-off: this pass draws below it
uniform float mip_boost : hint_range(0.0, 1.0) = 0.30;
uniform float soft_strength : hint_range(0.0, 1.0) = 0.85;
uniform float roughness_value : hint_range(0.0, 1.0) = 0.80;
uniform float specular_value : hint_range(0.0, 1.0) = 0.15;
uniform vec3 head_centre = vec3(0.0);
uniform float round_normals : hint_range(0.0, 1.0) = 0.55;
uniform bool use_round_normals = true;

void vertex() {
	if (use_round_normals) {
		vec3 out_dir = VERTEX - head_centre;
		float len = length(out_dir);
		if (len > 0.0001) {
			out_dir /= len;
			vec3 n = NORMAL;
			if (dot(n, out_dir) < 0.0) {
				n = -n;
			}
			NORMAL = normalize(mix(n, out_dir, round_normals));
		}
	}
}

void fragment() {
	if (!FRONT_FACING) {
		NORMAL = -NORMAL;
	}
	vec4 t = texture(strands, UV);
	vec2 tex_px = UV * vec2(textureSize(strands, 0));
	vec2 dx = dFdx(tex_px);
	vec2 dy = dFdy(tex_px);
	float lod = max(0.0, 0.5 * log2(max(dot(dx, dx), dot(dy, dy))));
	float a = clamp(t.a * (1.0 + lod * mip_boost), 0.0, 1.0);
	// only the fringe the solid pass didn't draw (a little overlap so there's no seam between them)
	float fringe = a * (1.0 - smoothstep(cutoff * 0.9, cutoff * 1.05, a));
	ALBEDO = t.rgb * hair_color.rgb;
	ALPHA = fringe * soft_strength;
	ROUGHNESS = roughness_value;
	SPECULAR = specular_value;
}
