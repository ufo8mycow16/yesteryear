// REV 201 - the Enterprise's glowing nacelle caps (bussard collectors), TOS style:
// orange-red light swirling round inside the dome, with flickering points of
// light, the two nacelles turning in opposite directions. Used by the opening
// titles and the main-menu backdrop (TitleSequence.gd _make_bussard_material).
// Everything is worked out from the mesh's own points, so it needs no UVs.
shader_type spatial;

uniform vec3 center = vec3(0.0);          // middle of the cap, mesh space
uniform vec3 axis = vec3(0.0, 0.0, 1.0);  // the nacelle's length direction, mesh space
uniform float radius = 1.0;               // cap radius, mesh space
uniform float spin_dir = 1.0;             // +1 / -1: port and starboard turn opposite ways
uniform float energy = 2.2;               // overall brightness (the titles' glow setting)
uniform float speed = 0.3;                // turns per second
uniform float vanes = 6.0;                // number of swirling arms
uniform vec3 deep_color : source_color = vec3(0.85, 0.1, 0.02);
uniform vec3 hot_color : source_color = vec3(1.0, 0.6, 0.18);
// REV 216 (Glen): the 1960s prop was fairy lights behind a spinning shutter, seen through a metal
// pie-tin diffuser. Fixed, softly blurred bulbs twinkling at their own pace behind the swirl, and an
// uneven, slightly blotchy diffuser so the glass doesn't look too clean.
uniform float fairy_grid = 6.0;           // bulbs across the cap (roughly fairy_grid squared in all)
uniform float fairy_strength = 0.9;       // how bright the bulbs are
uniform float fairy_blur = 0.11;          // bulb size through the diffuser (share of the cap radius)
uniform float diffuser_grain = 0.35;      // 0 = perfectly even glass, 1 = very blotchy

varying vec3 local_pos;

void vertex() {
	local_pos = VERTEX;
}

// REV 293: sin-free hashes (Dave Hoskins' "hash without sine", as WarpTunnel's NOISE_LIB since REV 239).
// The old fract(sin(x) * 43758) is worked out roughly on real graphics cards, which turned the warp
// nebula into blocky shards (REV 239); these give the same even scatter on any card.
float hash(float n) {
	float x = fract(n * 0.1031);
	x *= x + 33.33;
	x *= x + x;
	return fract(x);
}

float hash2(vec2 c) {
	vec3 p3 = fract(vec3(c.xyx) * 0.1031);
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.x + p3.y) * p3.z);
}

// Smooth value noise, for the diffuser's blotches.
float vnoise(vec2 x) {
	vec2 i = floor(x);
	vec2 f = fract(x);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash2(i), hash2(i + vec2(1.0, 0.0)), f.x),
		mix(hash2(i + vec2(0.0, 1.0)), hash2(i + vec2(1.0, 1.0)), f.x), f.y);
}

// The fairy lights: one bulb per grid cell, at a random spot in it, each with its own colour
// and its own twinkle (some steady, some blinking, some flickering). Returns brightness and tint.
vec4 fairy_lights(vec2 q, float t) {
	vec2 g = q * fairy_grid * 0.5;
	vec2 cell = floor(g);
	float light = 0.0;
	vec3 tint = vec3(0.0);
	for (int y = -1; y <= 1; y++) {
		for (int x = -1; x <= 1; x++) {
			vec2 c = cell + vec2(float(x), float(y));
			float h = hash2(c);
			vec2 pos = c + vec2(0.2 + 0.6 * hash2(c + 17.3), 0.2 + 0.6 * hash2(c + 41.9));
			float d = length(g - pos) / (fairy_grid * 0.5);
			float blob = exp(-(d * d) / (fairy_blur * fairy_blur));
			// twinkle: a slow breathe for most, a few blink, a few flicker fast
			float ph = h * 6.2831853;
			float tw = 0.55 + 0.45 * sin(t * (0.8 + 2.2 * hash2(c + 3.1)) + ph);
			if (h > 0.78) {
				tw = step(0.5, fract(t * (0.6 + hash2(c + 9.7)) + h));          // blinker
			} else if (h < 0.12) {
				tw = 0.4 + 0.6 * hash(floor(t * 14.0) + h * 97.0);              // flickerer
			}
			float b = blob * tw * (0.5 + 0.5 * hash2(c + 5.5));
			// warm bulbs: amber, yellow-white, a few redder ones
			vec3 bulb_col = mix(vec3(1.0, 0.55, 0.15), vec3(1.0, 0.85, 0.55), hash2(c + 23.0));
			if (hash2(c + 61.0) > 0.8) {
				bulb_col = vec3(1.0, 0.3, 0.08);
			}
			light += b;
			tint += bulb_col * b;
		}
	}
	return vec4(tint / max(light, 0.0001), light);
}

void fragment() {
	vec3 a = normalize(axis);
	vec3 p = local_pos - center;
	vec3 radial = p - a * dot(p, a);
	float r = clamp(length(radial) / max(radius, 0.0001), 0.0, 1.0);
	vec3 b1 = normalize(abs(a.y) < 0.9 ? cross(a, vec3(0.0, 1.0, 0.0)) : cross(a, vec3(1.0, 0.0, 0.0)));
	vec3 b2 = cross(a, b1);
	float ang = atan(dot(radial, b2), dot(radial, b1));
	float turn = TIME * speed * 6.2831853 * spin_dir;

	// Main swirl: curved arms sweeping round the cap.
	float arms = 0.5 + 0.5 * sin(vanes * (ang - turn) + r * 4.5);
	arms = smoothstep(0.3, 0.95, arms);
	// A slower layer turning the other way gives the glass some depth.
	float under = 0.5 + 0.5 * sin(3.0 * (ang + turn * 0.4) - r * 3.0);
	// Flickering lights riding round a ring, each switching on and off.
	float slots = 14.0;
	float a01 = fract((ang - turn * 0.8) / 6.2831853);
	float cell = floor(a01 * slots);
	float within = fract(a01 * slots);
	float on = step(0.55, hash(cell + floor(TIME * 7.0 + cell * 0.37) * 13.1));
	float bulb = on * smoothstep(0.5, 0.15, abs(within - 0.5)) * smoothstep(0.22, 0.0, abs(r - 0.62));
	// Hotter in the middle, like a light inside the dome.
	float core = 1.0 - smoothstep(0.0, 0.9, r);

	// REV 216: the fairy lights sit still behind the spinning shutter, so the swirl's arms sweep
	// across them - bright where an arm passes, dimmer between (never fully hidden).
	vec2 q = vec2(dot(radial, b1), dot(radial, b2)) / max(radius, 0.0001);
	vec4 fl = fairy_lights(q, TIME);
	float fairy = fl.a * mix(0.4, 1.0, arms) * fairy_strength * (1.0 - smoothstep(0.85, 1.0, r));
	// the pie-tin diffuser: blotchy, a little uneven - some patches let more light through
	float grain = vnoise(q * 3.2 + 7.0) * 0.65 + vnoise(q * 9.0 - 3.0) * 0.35;
	float diffuser = mix(1.0, 0.55 + 0.9 * grain, diffuser_grain);

	float k = (0.3 + 0.5 * arms + 0.15 * under + 0.5 * bulb + 0.45 * core) * diffuser + fairy;
	vec3 col = mix(deep_color, hot_color, clamp(arms * 0.55 + core * 0.6 + bulb * 0.5, 0.0, 1.0));
	col = mix(col, fl.rgb, clamp(fairy / max(k, 0.0001), 0.0, 0.6));
	ALBEDO = col * 0.2;
	ROUGHNESS = 0.25;
	EMISSION = col * k * energy;
}
