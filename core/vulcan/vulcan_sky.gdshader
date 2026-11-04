// REV 821: the view out of a Vulcan window (ShiKahr's spires, red mountains, hazy orange sky, a big low sun).
// Stand-in until Glen paints assets/textures/vulcan/view_shikahr.png (VulcanSet.window_view uses that if it exists).
shader_type spatial;
render_mode unshaded, cull_disabled, shadows_disabled, fog_disabled;

uniform vec3 sky_top : source_color = vec3(0.62, 0.24, 0.14);
uniform vec3 sky_low : source_color = vec3(1.0, 0.64, 0.40);
uniform vec3 sun_col : source_color = vec3(1.0, 0.86, 0.62);
uniform vec3 far_mtn : source_color = vec3(0.70, 0.36, 0.26);
uniform vec3 near_mtn : source_color = vec3(0.50, 0.24, 0.17);
uniform vec3 stone_lit : source_color = vec3(0.92, 0.66, 0.44);
uniform vec3 stone_shade : source_color = vec3(0.58, 0.36, 0.25);
uniform vec2 sun_pos = vec2(0.58, 0.22);
uniform float aspect = 1.78;
uniform float brightness = 1.0;
uniform float seed = 3.0;

float hash(float n) { return fract(sin(n * 127.1 + seed * 31.7) * 43758.5453); }
float hash2(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7)) + seed) * 43758.5453); }
float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash2(i), hash2(i + vec2(1.0, 0.0)), f.x), mix(hash2(i + vec2(0.0, 1.0)), hash2(i + vec2(1.0, 1.0)), f.x), f.y);
}
float fbm(vec2 p) {
	float v = 0.0;
	float a = 0.5;
	for (int i = 0; i < 5; i++) { v += a * noise(p); p *= 2.03; a *= 0.5; }
	return v;
}
float ridge(float x, float s) {
	float v = 0.0;
	float a = 0.5;
	float f = 1.0;
	for (int i = 0; i < 5; i++) { v += a * (1.0 - abs(noise(vec2(x * f, s)) * 2.0 - 1.0)); f *= 2.1; a *= 0.5; }
	return v;
}

void fragment() {
	vec2 uv = UV;
	// heat shimmer low down
	uv.x += sin(uv.y * 90.0 + TIME * 2.6) * 0.0009 * smoothstep(0.45, 0.9, uv.y);
	float y = uv.y;
	vec3 col = mix(sky_top, sky_low, smoothstep(0.0, 0.62, y));
	col *= 0.94 + 0.08 * fbm(vec2(uv.x * 2.0 + TIME * 0.004, y * 9.0));
	// the sun and its glow
	vec2 sp = vec2(uv.x * aspect, y);
	vec2 sc = vec2(sun_pos.x * aspect, sun_pos.y);
	float d = distance(sp, sc);
	col += vec3(1.0, 0.55, 0.28) * 0.45 * exp(-d * 6.0);
	col = mix(col, sun_col, smoothstep(0.072, 0.066, d));
	// far mountains (hazy)
	float m1 = 0.50 - 0.16 * ridge(uv.x * 3.2, 1.7);
	if (y > m1) {
		vec3 c = mix(far_mtn, sky_low, 0.45);
		c *= 0.9 + 0.15 * fbm(uv * vec2(14.0, 30.0));
		col = c;
	}
	// nearer mountains
	float m2 = 0.60 - 0.13 * ridge(uv.x * 2.1 + 5.0, 4.2);
	if (y > m2) {
		vec3 c = mix(near_mtn, far_mtn, 0.25);
		c *= 0.85 + 0.25 * fbm(uv * vec2(20.0, 40.0));
		col = c;
	}
	// ShiKahr: terraced blocks and tall spires, three rows back to front
	for (int row = 0; row < 3; row++) {
		float base_y = 0.66 + float(row) * 0.06;
		float scale = 0.6 + float(row) * 0.35;
		for (int i = 0; i < 16; i++) {
			float k = float(i) + float(row) * 40.0;
			float cx = (float(i) + 0.15 + 0.7 * hash(k)) / 16.0;
			bool spire = hash(k + 7.0) > 0.62;
			float w = (spire ? 0.010 : 0.030 + 0.03 * hash(k + 2.0)) * scale;
			float h = (spire ? 0.20 + 0.18 * hash(k + 3.0) : 0.06 + 0.07 * hash(k + 4.0)) * scale;
			float top = base_y - h;
			float dx = (uv.x - cx) / w;
			if (y > top && y < 1.0 && abs(dx) < 1.0) {
				bool inside = true;
				if (spire) {
					// tapers to a point
					float t = (y - top) / h;
					inside = abs(dx) < clamp(t * 1.6, 0.0, 1.0);
				} else {
					// terraced: steps in toward the top
					float t = (y - top) / h;
					float step_in = floor(t * 3.0) / 3.0;
					inside = abs(dx) < 0.55 + 0.45 * step_in;
				}
				if (inside) {
					vec3 c = dx < 0.15 ? stone_lit : stone_shade;
					c *= 0.88 + 0.12 * noise(uv * vec2(300.0, 160.0));
					// windows and slits
					if (!spire && fract((y - top) * 90.0 / scale) < 0.22 && fract(dx * 3.0) < 0.3) c *= 0.55;
					float haze = 0.38 - float(row) * 0.14;
					col = mix(c, sky_low, haze);
				}
			}
		}
	}
	ALBEDO = col * brightness;
}
