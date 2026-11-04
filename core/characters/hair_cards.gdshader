// REV 358 (Glen: Chapel's hair "still flickering ... as soon as she moves her head, it catches the light").
// Daz card hair (flat ribbons with a strand cut-out picture) for real-time use. Fixes two causes of shimmer:
//  1. Distance: the game draws a shrunken copy of the strand picture further away (mipmaps). Thin
//     strands average out toward see-through and dropped under the cut-off, so they popped in and out as
//     she moved. Here solidity is raised a little for each shrink step, so strands keep their thickness.
//  2. Lighting: drawn both sides, each card's back face was lit as if facing the other way, and the cards
//     point every which way, so neighbouring cards flashed light/dark as the head turned. Here every card
//     is lit facing outward, and its lighting direction is bent toward "out from the head", so the hair
//     shades as one soft volume. Shine is low and broad (real hair isn't glittery at this scale).
// Edges are smoothed with the screen's anti-aliasing (alpha to coverage) where MSAA is on.
shader_type spatial;
render_mode cull_disabled, depth_draw_opaque, alpha_to_coverage, diffuse_burley, specular_schlick_ggx;

uniform sampler2D strands : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform vec4 hair_color : source_color = vec4(0.72, 0.50, 0.34, 1.0);
uniform float cutoff : hint_range(0.0, 1.0) = 0.30;      // how solid a pixel must be to be drawn
uniform float mip_boost : hint_range(0.0, 1.0) = 0.30;   // extra solidity per shrink step (distance)
uniform float edge_soft : hint_range(0.0, 1.0) = 0.25;   // width of the smoothed edge band
uniform float roughness_value : hint_range(0.0, 1.0) = 0.80;
uniform float specular_value : hint_range(0.0, 1.0) = 0.15;
uniform vec3 head_centre = vec3(0.0);                     // in the hair mesh's own space
uniform float round_normals : hint_range(0.0, 1.0) = 0.55; // 0 = card's own facing, 1 = straight out from the head
uniform bool use_round_normals = true;

void vertex() {
	if (use_round_normals) {
		vec3 out_dir = VERTEX - head_centre;
		float len = length(out_dir);
		if (len > 0.0001) {
			out_dir /= len;
			vec3 n = NORMAL;
			if (dot(n, out_dir) < 0.0) {
				n = -n;   // the side of the card that faces away from the head
			}
			NORMAL = normalize(mix(n, out_dir, round_normals));
		}
	}
}

void fragment() {
	// Both sides of a card share one (outward) lighting direction; Godot flips it for back faces.
	if (!FRONT_FACING) {
		NORMAL = -NORMAL;
	}
	vec4 t = texture(strands, UV);
	vec2 tex_px = UV * vec2(textureSize(strands, 0));
	vec2 dx = dFdx(tex_px);
	vec2 dy = dFdy(tex_px);
	float lod = max(0.0, 0.5 * log2(max(dot(dx, dx), dot(dy, dy))));
	ALBEDO = t.rgb * hair_color.rgb;
	ALPHA = clamp(t.a * (1.0 + lod * mip_boost), 0.0, 1.0);
	ALPHA_SCISSOR_THRESHOLD = cutoff;
	ALPHA_ANTIALIASING_EDGE = edge_soft;
	ALPHA_TEXTURE_COORDINATE = tex_px;
	ROUGHNESS = roughness_value;
	SPECULAR = specular_value;
}
