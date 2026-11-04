shader_type spatial;
// REV 878: one shell of the sehlat's fur. Sehlat.gd stacks SHELLS of these as next_pass materials on the bearSkin
// surface, each pushed a little further out along the normal (layer 0..1). A strand is a soft dot per UV cell that
// shrinks toward the tip and stops at its own random length, so the outline goes fuzzy instead of plastic.
// Opaque pipeline (alpha scissor), so it sorts and shadows like the body.
render_mode cull_back, depth_draw_opaque, diffuse_lambert, specular_schlick_ggx;

uniform sampler2D albedo_tex : source_color, filter_linear_mipmap, repeat_enable;
uniform float layer = 0.0;              // 0 = at the skin, 1 = the longest hairs
uniform float fur_length = 0.035;       // metres, before the creature's scale
uniform float density = 420.0;          // strands across one UV unit
uniform float droop = 0.35;             // hairs bend down a little at the tips (model space)
uniform float tip_light = 1.18;         // sun-bleached tips
uniform float root_dark = 0.62;         // shade down at the skin
uniform float fade_far = 28.0;          // metres from the camera where the shells give up (no shimmer far away)

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

void vertex() {
	VERTEX += NORMAL * fur_length * layer;
	VERTEX.y -= droop * fur_length * layer * layer;
}

void fragment() {
	if (length(VERTEX) > fade_far) {
		discard;
	}
	vec2 cell = UV * density;
	vec2 id = floor(cell);
	float h = hash(id);
	vec2 jitter = vec2(hash(id + 17.3), hash(id + 41.9)) - 0.5;
	vec2 f = fract(cell) - 0.5 - jitter * 0.35;
	float strand_len = 0.45 + 0.55 * h;               // each hair its own length
	float t = layer / strand_len;                      // how far up this hair we are
	float radius = 0.48 * (1.0 - t);
	ALPHA = (t < 1.0 && length(f) < radius) ? 1.0 : 0.0;
	ALPHA_SCISSOR_THRESHOLD = 0.5;
	vec3 base = texture(albedo_tex, UV).rgb;
	ALBEDO = base * mix(root_dark, tip_light, layer);
	ROUGHNESS = 0.95;
	SPECULAR = 0.2;
}
