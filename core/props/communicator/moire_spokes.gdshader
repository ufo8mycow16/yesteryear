// The TOS communicator's moire (REV 610) - drawn live, so it's sharp at any distance.
// How the original was made (Ron Logan's write-up, Glen's reference): two identical "spoke wheels" - SPOKES
// black spokes and SPOKES gaps round a centre - laid one over the other, the top one nudged off-centre by
// `offset` (as a fraction of the disc's width; 10 px on a 300 px disc) and turning slowly about the disc's
// centre. The two sets of spokes interfere into the pulsing, slowly orbiting lobes.
// The disc's UVs run 0..1 across it (communicator_tos_*.glb, material "Moire"). CommunicatorProp drives
// `turn` (radians), so the pattern can stop and start without jumping.
shader_type spatial;

uniform float spokes = 100.0;
uniform vec2 offset = vec2(0.0333, 0.0333);
uniform float turn = 0.0;
uniform vec3 light_colour : source_color = vec3(0.80, 0.81, 0.83);
uniform vec3 dark_colour : source_color = vec3(0.025, 0.025, 0.03);

// 1 on a black spoke, 0 between - softened by one screen pixel so it never shimmers
// (a sine across the spokes: its positive half is the black spoke; atan's seam is invisible because the
// spoke count is whole)
float wheel(vec2 q, float spin) {
	float v = sin((atan(q.y, q.x) - spin) * spokes);
	float aa = max(fwidth(v), 1e-4);
	return smoothstep(-aa, aa, v);
}

void fragment() {
	vec2 p = UV - vec2(0.5);
	float c = cos(turn), s = sin(turn);
	vec2 centre = vec2(offset.x * c - offset.y * s, offset.x * s + offset.y * c);
	float black = max(wheel(p, 0.0), wheel(p - centre, turn));
	ALBEDO = mix(light_colour, dark_colour, black);
	METALLIC = 0.55 * (1.0 - black);
	ROUGHNESS = mix(0.35, 0.6, black);
}
