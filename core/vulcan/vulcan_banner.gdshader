// REV 821: a long woven banner - deep red, gold border and fringe, a tall gold Vulcan emblem.
// Stand-in until Glen's assets/textures/vulcan/banner.png.
shader_type spatial;
render_mode cull_disabled;

uniform vec3 cloth : source_color = vec3(0.42, 0.06, 0.05);
uniform vec3 gold : source_color = vec3(0.85, 0.62, 0.28);

float hash2(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }

void vertex() {
	VERTEX.z += sin(UV.x * 9.0 + TIME * 0.6) * 0.012 * UV.y;
}

void fragment() {
	vec2 uv = UV;
	vec3 col = cloth;
	// weave and folds
	col *= 0.9 + 0.1 * sin(uv.x * 26.0);
	col *= 0.94 + 0.06 * hash2(floor(uv * vec2(160.0, 420.0)));
	float g = 0.0;
	// border lines
	float bx = min(uv.x, 1.0 - uv.x);
	g += smoothstep(0.012, 0.0, abs(bx - 0.06));
	g += smoothstep(0.006, 0.0, abs(bx - 0.09));
	float by = uv.y;
	g += smoothstep(0.006, 0.0, abs(by - 0.03)) * step(0.06, bx);
	g += smoothstep(0.004, 0.0, abs(by - 0.86)) * step(0.06, bx);
	// emblem: a tall blade, a cross-spike and a ring
	vec2 c = vec2((uv.x - 0.5) * 2.4, uv.y);
	float blade = step(abs(c.x), 0.20 * (1.0 - smoothstep(0.08, 0.80, uv.y)) * smoothstep(0.06, 0.22, uv.y) + 0.02 * step(0.22, uv.y) * step(uv.y, 0.78));
	g += blade * step(0.08, uv.y) * step(uv.y, 0.80);
	float spike = step(abs(c.y - 0.52) * 4.0 + abs(c.x) * 0.55, 0.12);
	g += spike;
	float ring = smoothstep(0.02, 0.0, abs(length(vec2(c.x, (c.y - 0.52) * 2.4)) - 0.28));
	g += ring;
	// fringe
	if (uv.y > 0.93) {
		float strand = step(0.4, fract(uv.x * 60.0));
		col = mix(col, gold * 0.85, strand);
		if (uv.y > 0.93 + 0.07 * (0.6 + 0.4 * hash2(vec2(floor(uv.x * 60.0), 1.0)))) discard;
	}
	col = mix(col, gold, clamp(g, 0.0, 1.0));
	ALBEDO = col;
	ROUGHNESS = 0.9;
	METALLIC = clamp(g, 0.0, 1.0) * 0.4;
}
