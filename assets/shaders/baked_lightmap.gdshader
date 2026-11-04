shader_type spatial;
// The recreation deck's own baked lighting. The map's author lit every surface
// with Quake 3's lightmap tool; this multiplies each texture by that lightmap
// (second UV set) and by the vertex light, the way the original engine drew it.
// Unshaded because the light is already "painted in".
render_mode unshaded, cull_disabled;

uniform sampler2D albedo_tex : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D lightmap_tex : source_color, filter_linear, repeat_disable;
uniform vec4 albedo_color : source_color = vec4(1.0);
uniform float use_albedo_tex = 1.0;
// Quake brightens lightmaps (its "overbright"); 4 is the engine default. Raise
// it for a brighter deck, lower it for moodier. Applied the way the original
// did, in gamma space (hence the 2.2 power).
uniform float light_boost = 1.7;
// Never let a surface go fully black (this is the minimum light every surface gets).
uniform float ambient_floor = 0.04;
// Ceilings (anything facing down) get a higher minimum, so the roof reads as a
// dark grey ceiling instead of a black void.
uniform float ceiling_floor = 0.18;
// Brightness of the ceiling's grey (1.0 = as the stock texture; raise to lighten the roof).
uniform float ceiling_grey = 1.6;
// Enterprise colour grade: shadows lean purple, lit areas lean green-teal.
// 0 = off (original colours), 1 = strong.
uniform float grade_strength = 0.5;
// Contrast: above 1 deepens the shadows (moodier), 1 = unchanged.
uniform float contrast = 1.25;
// Light panels and screens glow regardless of the lightmap.
uniform float emissive_strength = 0.0;
// The part of the lightmap atlas that is the plain white "unlit" page: x0, y0, x1, y1 in UV2.
// Surfaces the map did not light point at it, and only those are tinted by their vertex colour.
// (Used to be decided by whether the sampled texel was almost white, so every brightly lit texel of a
// lit surface was also treated as unlit and got the near-black vertex colour: that was the blotches.)
uniform vec4 unlit_rect = vec4(-1.0, -1.0, -1.0, -1.0);
uniform float use_unlit_rect = 0.0;
// How strongly coloured the baked light may be, as a fraction of its brightness (1 = no limit).
// Keeps the TOS coloured accent light but stops it flooding a whole corridor with green or magenta.
uniform float chroma_limit = 0.16;
// REV 41: 1 = see-through where the picture is transparent (the red grates: their gaps were drawn solid black).
uniform float alpha_cut = 0.0;
// REV 63: SOFT LIGHT. 1 = smooth the baked light (it is one pixel per ~0.5 m, so it shows as blobs) and compress
// bright light with a gentle curve instead of cutting it off at full white (the Enterprise map is lit very dark and
// boosted ~13x, which left big flat-white and dark patches). 0 = the old look. Debug build: backslash toggles it.
uniform float soft_light = 0.0;
// REV 74: how hard the soft curve lifts dark light (higher = shadows come up more; 1.5 was the old fixed value).
uniform float soft_k = 1.5;
uniform vec2 lm_texel = vec2(0.0013, 0.0013);
// REV 384 (Glen: Deck 7 "just dark"; "happy with greens and purples, but maybe not quite as intense" as
// Cawley's set): coloured room washes, like TOS's gelled set lighting. Up to 12 soft spheres of light in the
// world: wash_pos = centre (xyz) and radius (w), wash_col = colour (rgb) and strength (a). Added to the baked
// light, fading out to the radius. Set per map by ModelRoom.ROOM_WASHES.
// REV 414: up to 24 (the room's own washes plus the soft light the screens throw on the desks below them).
uniform int wash_count = 0;
uniform vec4 wash_pos[24];
uniform vec4 wash_col[24];
// REV 453 (Glen: CLASSIC "all just looks the same ... very generic"; TOS stills + a set-tour photo, "a cross
// between the episode and the set tour"): ROOM MOODS. The TOS sets were lit theatrically - aimed coloured gels
// pooling on the walls, deep shadow up in the ceilings, a bright working pool on the floor. Set per room by
// ModelRoom.ROOM_MOODS.
//  REV 456: any number of rooms and lamps, read from a data texture (mood_data, one row of RGBA floats, built by
//  ModelRoom._build_mood_texture). Per room 5 texels: box low xyz + edge blend (m) | box high xyz + ceiling
//  darkness 0..1 | tint rgb (the room's grade instead of the deck-wide purple/teal) + contrast (power on the light)
//  | ceiling from/to world height + colour allowance (under 0 = the deck's chroma_limit) | first lamp, lamp count.
//  Then per lamp 3 texels (after all the rooms): position xyz + reach | direction xyz + cos of the cone's half angle
//  | colour rgb + strength. A lamp lights only inside its own room (times the room's weight - fading over the box
//  edge), so no colour comes through a wall. Lamps are soft washes: brightest down the middle, fading right out to
//  the cone's edge, and with distance, strongest on what faces them.
//  - mood_on: 0 = off (compare with the old look; debug Y).
uniform float mood_on = 1.0;
uniform int zone_count = 0;
uniform sampler2D mood_data : filter_nearest, repeat_disable;
// REV 414 (Glen: "add the screen glow treatment ... do a really good job on it"): LIVE DISPLAYS. 0 = an
// ordinary surface. 1 = a CRT display (glows, scan lines, phosphor stripes up close, a slow rolling refresh
// band, faint flicker and grain, a dark glass face with a soft sheen, light bleeding round bright content).
// 2 = a backlit chart (an even lit glow, light bleed, no scan lines). 3 = a lamp panel (only its lit lamps
// glow and bleed; the board stays as the room lights it). In every mode the painted hardware - grey frames,
// bezels, bars - is picked out by colour (low saturation, mid grey) and keeps the room's baked light, so a
// picture with its frame painted in still reads as a lit screen set in a solid frame.
uniform float screen_fx = 0.0;
uniform float screen_gain = 1.0;      // display brightness against the room (1 = the picture as painted)
uniform float screen_hdr = 0.35;      // extra brightness on the brightest content (feeds the room's bloom)
uniform float screen_bleed = 0.55;    // how much light bleeds round bright content
uniform float screen_bleed_r = 0.006; // bleed radius, in picture coordinates
uniform float scan_lines = 300.0;     // scan lines down the picture's height
uniform float scan_depth = 0.22;      // how dark the gaps between lines are (fades out when too fine to see)
uniform float screen_seed = 0.0;      // per-screen offset so they don't flicker and roll in step
uniform vec3 glass_black = vec3(0.010, 0.017, 0.021);   // the "off" colour of the display's face
// REV 415 (Glen: "this is supposed to be 2269. I'm sure we have LCD's at this point"): 0 = a modern flat panel
// (no scan lines, phosphor, rolling band, flicker or grain - just its glow, light bleed and the glass), 1 = the
// old tube look (kept for anything that should look antique).
uniform float screen_retro = 0.0;
varying vec3 v_world;

// ---- REV 414: live displays -------------------------------------------------------------------------
float vf_hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float vf_luma(vec3 c) { return dot(c, vec3(0.2126, 0.7152, 0.0722)); }
// 1 where a picture's pixel is painted hardware (a grey frame, bezel or bar), 0 where it is display or lamp.
float vf_hardware(vec3 c) {
	float mx = max(c.r, max(c.g, c.b));
	float mn = min(c.r, min(c.g, c.b));
	float sat = (mx - mn) / max(mx, 0.001);
	float l = vf_luma(c);
	return (1.0 - smoothstep(0.10, 0.22, sat)) * smoothstep(0.15, 0.25, l) * (1.0 - smoothstep(0.84, 0.93, l));
}
// How much of a pixel is "light" in lamp-panel mode: lit lamps are bright, and either coloured or near white.
float vf_lamp(vec3 c) {
	float mx = max(c.r, max(c.g, c.b));
	float mn = min(c.r, min(c.g, c.b));
	float sat = (mx - mn) / max(mx, 0.001);
	return smoothstep(0.38, 0.72, mx) * max(smoothstep(0.30, 0.55, sat), smoothstep(0.80, 0.95, mn));
}
// The bright part of a picture's pixel (what glows past its edges), with painted hardware left out.
vec3 vf_bright(vec3 c) {
	return max(c - vec3(0.30), vec3(0.0)) * (1.0 - vf_hardware(c)) * 1.43;
}

// fw_rows / fw_cols: how many scan lines / phosphor stripes cross one screen pixel (fwidth, measured in
// fragment() - derivatives belong to the fragment stage).
vec3 live_display(vec3 base, vec3 lit, vec2 uv, vec3 nrm, vec3 view, float fw_rows, float fw_cols) {
	float mode = screen_fx;
	float hw = vf_hardware(base);
	float disp = 1.0 - hw;
	if (mode > 2.5) {
		disp *= vf_lamp(base);          // lamp panel: only the lit lamps
	}
	// light bleeding round bright content. REV 416 (Glen: "the glow looks too much"; REV 414's two fixed rings
	// of taps drew faint copies of thin lines beside them): 16 taps spread evenly over a disc (a sunflower
	// spiral, no two taps at the same distance or angle, so no single copy of a line stands out), weighted
	// toward the middle - a smooth haze. (A per-pixel random turn would be smoother still but speckles.)
	// Works whether or not the picture has mipmaps.
	vec3 bleed = vec3(0.0);
	float wsum = 0.0;
	float spin = 0.39;
	for (int i = 0; i < 16; i++) {
		float fi = float(i) + 0.5;
		float rr = sqrt(fi / 16.0);
		float a = fi * 2.3999632 + spin;
		float w = (1.0 - rr) * (1.0 - rr) + 0.05;
		bleed += vf_bright(texture(albedo_tex, uv + vec2(cos(a), sin(a)) * rr * screen_bleed_r).rgb) * w;
		wsum += w;
	}
	bleed *= albedo_color.rgb / wsum;
	float t = TIME + screen_seed * 17.0;
	// faint flicker: mains hum plus a slow wander, never more than a couple of percent
	float flick = 1.0 + screen_retro * (0.010 * sin(t * 59.0) + 0.016 * (vf_hash(vec2(floor(t * 6.0), screen_seed)) - 0.5));
	vec3 emit = base * screen_gain;
	emit *= 1.0 + screen_hdr * smoothstep(0.45, 1.0, vf_luma(base));
	if (mode < 1.5) {
		// --- a display (the tube effects below only with screen_retro)
		float rows = uv.y * scan_lines;
		float fade = (1.0 - smoothstep(0.30, 0.65, fw_rows)) * screen_retro;   // too fine to see: no lines, no moire
		float line = 0.5 + 0.5 * cos(rows * 6.2831853);
		emit *= mix(1.0, (1.0 - scan_depth) + scan_depth * 2.0 * line, fade);
		// phosphor stripes, only when close enough for them to be a few pixels wide
		float cols = uv.x * scan_lines * 3.0;
		float pfade = (1.0 - smoothstep(0.18, 0.40, fw_cols)) * screen_retro;
		int ph = int(mod(floor(cols), 3.0));
		vec3 mask = ph == 0 ? vec3(1.16, 0.92, 0.92) : (ph == 1 ? vec3(0.92, 1.16, 0.92) : vec3(0.92, 0.92, 1.16));
		emit *= mix(vec3(1.0), mask, 0.55 * pfade);
		// the slow rolling refresh band
		float yb = fract(uv.y - t * 0.055);
		float bd = (yb - 0.5) / 0.035;
		float band = exp(-bd * bd);
		emit *= 1.0 + 0.055 * band * screen_retro;
		// a dark glass face (never pure black), fine grain on it
		float grain = (vf_hash(uv * 1024.0 + vec2(floor(t * 24.0))) - 0.5) * 0.012 * screen_retro;
		emit = max(emit, glass_black) + vec3(grain) * (1.0 - smoothstep(0.0, 0.25, vf_luma(base)));
		// a soft sheen on the glass, strongest at grazing angles
		float graze = 1.0 - clamp(abs(dot(normalize(nrm), normalize(view))), 0.0, 1.0);
		emit += vec3(0.55, 0.62, 0.70) * 0.05 * pow(graze, 3.0);
	} else if (mode < 2.5) {
		// --- backlit chart: an even glow; its blacks are lit film, not quite black
		emit = max(emit, glass_black * 0.6);
	}
	emit = (emit + bleed * screen_bleed) * flick;
	// bleed also spills a little over the dark board of a lamp panel and the dark glass round content
	vec3 outc = mix(lit, emit, disp);
	if (mode > 2.5) {
		outc += bleed * screen_bleed * (1.0 - disp) * (1.0 - hw) * flick;
	}
	return clamp(outc, 0.0, 2.5);
}

// REV 29: the ceiling test used NORMAL in fragment(), which Godot flips for back faces when culling is off.
// Many props (chairs, bridge dome, trays) have triangles of mixed winding, so the same surface turned "ceiling"
// (dark grey) or not depending on which side the camera saw it from. Use the mesh's own normal instead.
varying float v_ny;
varying vec3 v_nw;
void vertex() {
	v_nw = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
	v_ny = v_nw.y;
	v_world = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec3 base = albedo_color.rgb;
	if (use_albedo_tex > 0.5) {
		vec4 albedo_sample = texture(albedo_tex, UV);
		base *= albedo_sample.rgb;
		if (alpha_cut > 0.5 && albedo_sample.a < 0.5) {
			discard;
		}
	}
	vec3 raw = texture(lightmap_tex, UV2).rgb;
	if (soft_light > 0.5) {
		// four extra taps half a pixel to each side: with the hardware filter this is a smooth 3x3 blur
		vec2 o = lm_texel * 0.75;
		vec3 s = texture(lightmap_tex, UV2 + vec2(o.x, o.y)).rgb + texture(lightmap_tex, UV2 + vec2(-o.x, o.y)).rgb
			+ texture(lightmap_tex, UV2 + vec2(o.x, -o.y)).rgb + texture(lightmap_tex, UV2 + vec2(-o.x, -o.y)).rgb;
		raw = mix(raw, s * 0.25, 0.7);
	}
	vec3 lm = raw * pow(light_boost, 2.2);
	float peak = max(lm.r, max(lm.g, lm.b));
	if (soft_light > 0.5) {
		// gentle curve: keeps the gradient in bright areas instead of flattening them to white
		lm *= (1.0 - exp(-soft_k * peak)) / max(peak, 0.0001);
	} else if (peak > 1.0) {
		lm /= peak; // keep the colour of very bright light instead of burning to white
	}
	// Surfaces the map left unlit use the plain white lightmap page; only those
	// are shaded by their vertex colour. (Lightmapped surfaces already carry
	// their light, and multiplying in the near-black vertex colours too was what
	// made the whole room so dark.)
	float unlit = step(0.995, min(raw.r, min(raw.g, raw.b)));
	if (use_unlit_rect > 0.5) {
		unlit = (UV2.x >= unlit_rect.x && UV2.x <= unlit_rect.z && UV2.y >= unlit_rect.y && UV2.y <= unlit_rect.w) ? 1.0 : 0.0;
	}
	vec3 vertex_light = mix(vec3(1.0), pow(COLOR.rgb, vec3(2.2)), unlit);
	float floor_level = ambient_floor;
	if (v_ny < -0.7) {
		floor_level = max(floor_level, ceiling_floor);
		if (emissive_strength < 0.01) {
			// Ceilings (not the light panels) are drawn as one cool dark grey, whatever
			// stock texture the map put up there (some were brown or near-black).
			float grey = dot(base, vec3(0.3, 0.59, 0.11));
			base = vec3(max(grey, 0.06)) * vec3(0.92, 0.97, 1.08) * ceiling_grey;
		}
	}
	// REV 453: how far inside a mood zone this point is (0 outside, 1 inside; blended over the zone's edge)
	float zw = 0.0;
	vec4 ztint = vec4(1.0);
	vec4 zceil = vec4(0.0);
	float zdark = 0.0;
	vec3 mood_add = vec3(0.0);
	if (mood_on > 0.5 && zone_count > 0) {
		// overlapping rooms blend their settings by weight (no hard swap at a doorway); each room's lamps are
		// summed here too (applied after the washes, below)
		float wsum = 0.0;
		vec4 tsum = vec4(0.0);
		vec4 csum = vec4(0.0);
		float dsum = 0.0;
		for (int i = 0; i < zone_count; i++) {
			int zb = i * 5;
			vec4 zlo = texelFetch(mood_data, ivec2(zb, 0), 0);
			vec4 zhi = texelFetch(mood_data, ivec2(zb + 1, 0), 0);
			float b = max(zlo.w, 0.01);
			if (any(lessThan(v_world, zlo.xyz - vec3(b))) || any(greaterThan(v_world, zhi.xyz + vec3(b)))) {
				continue;
			}
			vec3 a = smoothstep(zlo.xyz - vec3(b), zlo.xyz + vec3(b), v_world) * (vec3(1.0) - smoothstep(zhi.xyz - vec3(b), zhi.xyz + vec3(b), v_world));
			float w = a.x * a.y * a.z;
			if (w <= 0.0) {
				continue;
			}
			vec4 zc = texelFetch(mood_data, ivec2(zb + 3, 0), 0);
			if (zc.z < 0.0) {
				zc.z = chroma_limit;
			}
			wsum += w;
			tsum += texelFetch(mood_data, ivec2(zb + 2, 0), 0) * w;
			csum += zc * w;
			dsum += zhi.w * w;
			vec4 zs = texelFetch(mood_data, ivec2(zb + 4, 0), 0);
			int s0 = zone_count * 5 + int(zs.x) * 3;
			int sn = int(zs.y);
			for (int k = 0; k < sn; k++) {
				int sb = s0 + k * 3;
				vec4 sp = texelFetch(mood_data, ivec2(sb, 0), 0);
				vec3 to = v_world - sp.xyz;
				float d = length(to);
				float r = max(sp.w, 0.01);
				if (d > r) {
					continue;
				}
				vec4 sd = texelFetch(mood_data, ivec2(sb + 1, 0), 0);
				vec3 l = to / max(d, 0.0001);
				float cone = smoothstep(sd.w, 1.0, dot(l, normalize(sd.xyz)));
				if (cone <= 0.0) {
					continue;
				}
				// lamps hang under the ceiling: light that would travel UP from one (onto the ceiling
				// beside it) is cut - a raking lamp near the ceiling lit it blue/violet otherwise
				// (only lamps aimed level or down - engineering's low blue lamps point up at the housings)
				cone *= 1.0 - step(sd.y, 0.0) * smoothstep(-0.15, 0.08, l.y);     // nothing at or above the lamp
				vec4 sc = texelFetch(mood_data, ivec2(sb + 2, 0), 0);
				float fall = 1.0 - (d / r) * (d / r);
				fall *= fall;
				float face = mix(0.3, 1.0, abs(dot(normalize(v_nw), l)));
				mood_add += sc.rgb * sc.a * cone * fall * face * w;
			}
		}
		if (wsum > 0.0001) {
			zw = min(wsum, 1.0);
			ztint = tsum / wsum;
			zceil = csum / wsum;
			zdark = dsum / wsum;
		}
	}
	lm = pow(lm, vec3(contrast * mix(1.0, ztint.a, zw)));
	float lum = dot(lm, vec3(0.3, 0.59, 0.11));
	vec3 shadow_tint = vec3(1.25, 0.8, 1.45);  // purple
	vec3 light_tint = vec3(0.8, 1.2, 1.05);    // green-teal
	vec3 tint = mix(shadow_tint, light_tint, smoothstep(0.05, 0.6, lum));
	lm *= mix(mix(vec3(1.0), tint, grade_strength), ztint.rgb, zw);
	{
		float l2 = dot(lm, vec3(0.3, 0.59, 0.11));
		vec3 ch = lm - vec3(l2);
		float cm = max(abs(ch.r), max(abs(ch.g), abs(ch.b)));
		float allowed = l2 * mix(chroma_limit, zceil.z, zw) + 0.02;
		lm = vec3(l2) + ch * min(1.0, allowed / max(cm, 0.0001));
	}
	for (int i = 0; i < wash_count; i++) {
		float d = distance(v_world, wash_pos[i].xyz) / max(wash_pos[i].w, 0.01);
		float f = 1.0 - smoothstep(0.0, 1.0, d);
		lm += wash_col[i].rgb * wash_col[i].a * f * f;
	}
	// the ceiling falls into shadow (TOS lit from the floor up; the rafters were dark) - REV 456: after the
	// room washes too, which kept sickbay's ceiling glowing
	lm *= 1.0 - zw * zdark * smoothstep(zceil.x, max(zceil.y, zceil.x + 0.01), v_world.y);
	lm += mood_add;     // REV 453/456: the rooms' lamps (summed with the rooms above)
	lm = max(lm, vec3(floor_level) * mix(vec3(1.0), shadow_tint, grade_strength));
	vec3 lit = base * lm * vertex_light;
	lit = max(lit, base * emissive_strength);
	lit = clamp(lit, 0.0, 1.0);
	if (screen_fx > 0.5) {
		lit = live_display(base, lit, UV, NORMAL, VIEW, fwidth(UV.y * scan_lines), fwidth(UV.x * scan_lines * 3.0));
	}
	ALBEDO = lit;
}
