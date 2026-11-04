// REV 821: a Vulcan display set into stone - amber/red map lines, script columns, a slow sweep.
// Stand-in until Glen's own screen pictures (VulcanSet.screen uses assets/textures/vulcan/screen_<name>.png if there).
shader_type spatial;
render_mode unshaded, shadows_disabled;

uniform vec3 ink : source_color = vec3(1.0, 0.62, 0.22);
uniform vec3 ink2 : source_color = vec3(0.95, 0.22, 0.10);
uniform vec3 back : source_color = vec3(0.05, 0.025, 0.015);
uniform float seed = 1.0;
uniform float energy = 1.6;
uniform float map_share = 0.62;    // left part = the map, right = script columns

float hash2(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7)) + seed * 17.0) * 43758.5453); }
float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash2(i), hash2(i + vec2(1.0, 0.0)), f.x), mix(hash2(i + vec2(0.0, 1.0)), hash2(i + vec2(1.0, 1.0)), f.x), f.y);
}
float fbm(vec2 p) {
	float v = 0.0; float a = 0.5;
	for (int i = 0; i < 4; i++) { v += a * noise(p); p *= 2.1; a *= 0.5; }
	return v;
}

void fragment() {
	vec2 uv = UV;
	vec3 col = back;
	float border = step(uv.x, 0.012) + step(0.988, uv.x) + step(uv.y, 0.02) + step(0.98, uv.y);
	col = mix(col, ink * 0.5, clamp(border, 0.0, 1.0));
	if (uv.x < map_share) {
		vec2 m = vec2(uv.x / map_share, uv.y);
		// contour lines of a terrain/city map
		float h = fbm(m * vec2(4.0, 3.0) + seed);
		float iso = abs(fract(h * 9.0) - 0.5);
		col += ink * smoothstep(0.06, 0.0, iso) * 0.55;
		// a ring and spokes (a site plan)
		vec2 c = m - vec2(0.5, 0.5);
		float r = length(c * vec2(1.4, 1.0));
		col += ink * smoothstep(0.012, 0.0, abs(r - 0.28)) * 0.9;
		col += ink * smoothstep(0.008, 0.0, abs(r - 0.16)) * 0.6;
		float ang = atan(c.y, c.x);
		col += ink * smoothstep(0.02, 0.0, abs(fract(ang * 6.0 / 6.2832) - 0.5) - 0.48) * step(r, 0.28) * 0.35;
		// red marks
		for (int i = 0; i < 4; i++) {
			vec2 p = vec2(hash2(vec2(float(i), 3.0)), hash2(vec2(float(i), 9.0))) * 0.7 + 0.15;
			float dd = length((m - p) * vec2(1.4, 1.0));
			col += ink2 * smoothstep(0.025, 0.012, dd) * (0.7 + 0.3 * sin(TIME * 2.0 + float(i)));
		}
		// slow sweep
		float sweep = fract(TIME * 0.08 + seed * 0.13);
		col += ink * 0.25 * smoothstep(0.03, 0.0, abs(m.x - sweep));
	} else {
		// columns of script: rows of short glyph bars, a few changing
		vec2 t = vec2((uv.x - map_share) / (1.0 - map_share), uv.y);
		float row = floor(t.y * 18.0);
		float fy = fract(t.y * 18.0);
		float glyph = floor(t.x * 9.0);
		float fx = fract(t.x * 9.0);
		float on = step(0.35, hash2(vec2(glyph, row + floor(TIME * 0.4 + hash2(vec2(row, 1.0)) * 6.0) * step(0.85, hash2(vec2(row, 2.0))))));
		float shape = step(0.15, fx) * step(fx, 0.8) * step(0.3, fy) * step(fy, 0.75);
		shape *= step(0.3, noise(vec2(t.x * 60.0, row * 3.0)));
		vec3 c = row > 12.0 ? ink2 : ink;
		col += c * on * shape * 0.8;
		// a small bar chart at the bottom
		if (t.y > 0.8) {
			float bar = hash2(vec2(floor(t.x * 20.0), floor(TIME * 0.5)));
			col += ink * step(1.0 - (t.y - 0.8) / 0.2, bar) * step(0.2, fract(t.x * 20.0)) * 0.6;
		}
	}
	col *= 0.92 + 0.08 * sin(uv.y * 400.0);
	ALBEDO = col * energy;
}
