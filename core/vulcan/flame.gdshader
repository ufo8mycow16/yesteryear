// REV 821: a small open flame (a brazier), always facing the camera.
shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, shadows_disabled;

uniform float seed = 0.0;

float hash2(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7)) + seed) * 43758.5453); }
float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash2(i), hash2(i + vec2(1.0, 0.0)), f.x), mix(hash2(i + vec2(0.0, 1.0)), hash2(i + vec2(1.0, 1.0)), f.x), f.y);
}

void vertex() {
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(INV_VIEW_MATRIX[0], INV_VIEW_MATRIX[1], INV_VIEW_MATRIX[2], MODEL_MATRIX[3]);
}

void fragment() {
	float x = (UV.x - 0.5) * 2.0;
	float y = 1.0 - UV.y;              // 0 at the bottom
	float n = noise(vec2(x * 3.0, y * 4.0 - TIME * 3.2));
	float sway = 0.12 * sin(TIME * 5.0 + y * 6.0) * y;
	float w = 0.62 * pow(max(1.0 - y, 0.0), 0.8) * (0.8 + 0.4 * n);
	float a = smoothstep(w, w * 0.3, abs(x + sway));
	a *= smoothstep(1.0, 0.45, y + 0.35 * n) * smoothstep(0.0, 0.06, y);
	vec3 col = mix(vec3(1.0, 0.30, 0.05), vec3(1.0, 0.88, 0.55), a * a);
	ALBEDO = col * a * 1.8;
}
