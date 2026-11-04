shader_type spatial;
// The Guardian's time vortex: a slowly turning, glowing mist inside the ring.
// The mesh carries how far each point is from the stone in its vertex colour (0 at the rock, 1 well inside),
// so the glow fades softly to nothing where it meets the stone. UV is 0..1 across the opening.
render_mode unshaded, blend_add, cull_disabled, depth_draw_never;

uniform vec4 core_colour : source_color = vec4(0.85, 0.92, 1.0, 1.0);
uniform vec4 mist_colour : source_color = vec4(0.55, 0.45, 1.0, 1.0);
uniform float brightness = 1.6;
uniform float swirl_speed = 0.12;
uniform float flare = 0.0;   // 0 = idle, 1 = someone passing through (the script raises it)

float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), u.x), mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), u.x), u.y);
}
float fbm(vec2 p) {
	float v = 0.0;
	float a = 0.5;
	for (int i = 0; i < 5; i++) { v += a * noise(p); p = p * 2.03 + vec2(1.7, 9.2); a *= 0.5; }
	return v;
}

void fragment() {
	vec2 c = UV - vec2(0.5, 0.48);
	float r = length(c);
	float ang = atan(c.y, c.x);
	float t = TIME * swirl_speed;
	// a slow spiral: turn faster near the middle
	float turn = t * (1.0 + 1.5 * (1.0 - clamp(r * 2.0, 0.0, 1.0)));
	vec2 sp = vec2(cos(ang + turn + r * 3.0), sin(ang + turn + r * 3.0)) * r;
	float m1 = fbm(sp * 4.0 + vec2(t * 0.7, -t * 0.4));
	float m2 = fbm(sp * 9.0 - vec2(t * 0.3, t * 0.9));
	float mist = smoothstep(0.35, 0.85, m1 * 0.7 + m2 * 0.5);
	float core = exp(-r * r * 9.0);
	float edge = smoothstep(0.0, 1.0, COLOR.r);
	float pulse = 0.85 + 0.15 * sin(TIME * 1.3);
	vec3 col = mist_colour.rgb * mist * 0.9 + core_colour.rgb * core * (0.35 + 0.65 * mist);
	col *= brightness * pulse * (1.0 + flare * 2.5);
	col += core_colour.rgb * flare * edge * 0.6;
	ALBEDO = col * edge;
}
