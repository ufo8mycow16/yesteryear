shader_type spatial;
// REV 671 (Glen: "make all of those new displays blink, or sliders move"): a wall screen picture that looks switched
// on. ModelRoom._add_wall_pictures uses it for any picture listed in ModelRoom.SCREEN_LIFE. All rects are in the
// picture's own 0-1 coordinates (u across, v DOWN from the top), as SCREEN_LIFE gives them.
//   glow    - every screen: a slow faint breathing and the odd tiny flicker
//   blinks  - a box/lamp that goes dim and bright (period s, phase 0-1, duty = lit share)
//   bars    - a gauge whose level moves: mode 0 recolours fill/empty colours either side of the level (coolant bars),
//             mode 1 steps along and dims what's not reached yet (the Recording Log's progress bar)
//   wobble  - a trace that breathes (the warp field's red band and curve): only red pixels move
render_mode unshaded, cull_back, shadows_disabled;

uniform sampler2D tex : filter_linear_mipmap, repeat_disable;
uniform float seed = 0.0;
uniform int blink_count = 0;
uniform vec4 blink_rect[12];
uniform vec4 blink_par[12];      // period, phase, duty, dim level
uniform int bar_count = 0;
uniform vec4 bar_rect[4];
uniform vec4 bar_par[4];         // low level, high level, seconds per swing (or per sweep), mode
uniform vec4 bar_par2[4];        // steps (mode 1), phase, hold share (mode 1), -
uniform vec4 bar_fill[4];        // mode 0: the fill colour (sRGB)
uniform vec4 bar_empty[4];       // mode 0: the empty colour (sRGB)
uniform vec4 wob_rect = vec4(0.0);
uniform float wob_amp = 0.0;

float hash(float n) { return fract(sin(n) * 43758.5453); }

bool inside(vec2 uv, vec4 r) { return uv.x >= r.x && uv.x <= r.z && uv.y >= r.y && uv.y <= r.w; }

bool is_red(vec3 c) { return c.r > 0.75 && c.g < 0.5 && c.b < 0.5; }

vec3 to_linear(vec3 c) {
	return mix(c / 12.92, pow((c + 0.055) / 1.055, vec3(2.4)), step(vec3(0.04045), c));
}

void fragment() {
	vec2 uv = UV;
	vec3 col = texture(tex, uv).rgb;

	// the warp field's trace breathing
	if (wob_amp > 0.0 && inside(uv, wob_rect)) {
		float k = (uv.x - wob_rect.x) / max(wob_rect.z - wob_rect.x, 0.001);
		float dv = wob_amp * sin(k * 9.0 + TIME * 1.3 + seed) * sin(k * 3.14159) + wob_amp * 0.5 * sin(TIME * 0.7 + seed * 2.0) * k;
		vec3 moved = texture(tex, uv + vec2(0.0, dv)).rgb;
		if (is_red(col) || is_red(moved)) {
			col = moved;
		}
	}

	// moving gauges
	for (int i = 0; i < bar_count; i++) {
		vec4 r = bar_rect[i];
		if (!inside(uv, r)) continue;
		float k = (uv.x - r.x) / max(r.z - r.x, 0.001);
		vec4 p = bar_par[i];
		vec4 p2 = bar_par2[i];
		if (p.w < 0.5) {
			// a level that drifts smoothly between low and high
			float t = TIME / max(p.z, 0.1) + p2.y;
			float s = 0.5 + 0.35 * sin(t * 6.2832) + 0.15 * sin(t * 15.1 + 1.7);
			float level = mix(p.x, p.y, s);
			vec3 f = bar_fill[i].rgb;
			vec3 e = bar_empty[i].rgb;
			if (k > level && distance(col, f) < 0.22) col = e;
			else if (k <= level && distance(col, e) < 0.22) col = f;
		} else {
			// steps along to the top, holds, starts again
			float steps = max(p2.x, 1.0);
			float cyc = fract(TIME / max(p.z, 0.1) + p2.y);
			float run = clamp(cyc / max(1.0 - p2.z, 0.05), 0.0, 1.0);
			float level = mix(p.x, p.y, floor(run * steps + 0.001) / steps);
			if (k > level) col *= 0.18;
		}
	}

	// blinking boxes and lamps
	for (int i = 0; i < blink_count; i++) {
		if (!inside(uv, blink_rect[i])) continue;
		vec4 b = blink_par[i];
		float on = step(fract(TIME / max(b.x, 0.05) + b.y), b.z);
		col = mix(col * b.w, col, on);
	}

	// switched on: slow breathing and the odd flicker
	float glow = 1.0 + 0.035 * sin(TIME * 1.7 + seed * 6.0);
	glow -= 0.10 * step(0.996, hash(floor(TIME * 14.0) + seed * 17.0));
	ALBEDO = to_linear(clamp(col * glow, 0.0, 1.0));
}
