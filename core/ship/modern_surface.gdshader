// REV 170 (CLAUDE.md item 25): the modern look for map surfaces. The old maps are drawn unshaded with
// their Quake lightmap painted on (baked_lightmap.gdshader), so nothing in them reacts to real lights,
// shadows, reflections or bounced light. This draws the same pictures as properly lit surfaces:
//   - shine and roughness per kind of surface (set by ModernLighting from the material's name),
//   - surface relief worked out from the picture itself (so it also follows Glen's HD textures),
//   - the map's own baked light kept as soft occlusion and a little fill, so the room keeps the
//     light-and-dark the map's author gave it while the real lights do the actual lighting,
//   - light panels glow (bright enough to bloom and to light the room through the bounced light).
// REV 551: cull_disabled like the classic baked shader - the converted maps have faces wound either way,
// and with cull_back those vanished in MODERN (a gap in the alley's ball return, the ceiling over the seats).
shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_disabled, diffuse_burley, specular_schlick_ggx;

uniform vec4 albedo_color : source_color = vec4(1.0);
uniform sampler2D albedo_tex : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform float use_albedo_tex = 1.0;
uniform sampler2D lightmap_tex : source_color, filter_linear, repeat_disable;
uniform float use_lightmap = 1.0;
uniform float lightmap_boost = 1.7;     // the scene's own brightening of its lightmap
uniform float occlusion = 0.55;         // how much the baked light darkens corners and shaded spots
uniform float fill = 0.08;              // how much of the baked light stays as glow-free fill (ModernLighting sets it per kind, REV 551)
uniform float roughness = 0.7;
uniform float metallic = 0.0;
uniform float specular = 0.5;
uniform float clearcoat = 0.0;          // a varnish layer (the lanes)
uniform float clearcoat_roughness = 0.1;
uniform float relief = 0.6;             // surface relief from the picture (0 = flat)
uniform float emissive = 0.0;           // light panels / screens: 0 = none
uniform float emissive_energy = 3.0;
uniform float emissive_white = 0.5;     // REV 171: lit panels glow toward white light, not their tint
uniform float alpha_cut = 0.0;

// ---- REV 732 (Glen, sickbay: classic "looks better" - "you'd need to do that game wide"): CLASSIC BASE. On the ship's
// map rooms the enhanced look used to throw the room away and relight it with real lamps, so every ROOM_MOODS colour,
// the rooms' contrast and their dark ceilings were lost (sickbay went to a white flood). With classic_base = 1 this
// shader first works out EXACTLY what the classic shader (assets/shaders/baked_lightmap.gdshader) draws - the same maths
// on the same data, copied across from the surface's classic material by ModernLighting - and that is the surface's own
// light. The real lamps then only add on top: a little diffuse (classic_diffuse), their shine on metal and varnish,
// reflections, haze - so enhanced can only look like classic plus extras. (The bowling alley never sets it: its lanes'
// gloss stays exactly as it was.) Keep the block below in step with baked_lightmap.gdshader's fragment().
uniform float classic_base = 0.0;
uniform float classic_diffuse = 0.15;   // how much the real lamps still light the surface itself (classic is the base)
uniform float classic_gain = 1.0;
uniform float light_boost = 1.7;
uniform float ambient_floor = 0.04;
uniform float ceiling_floor = 0.18;
uniform float ceiling_grey = 1.6;
uniform float grade_strength = 0.5;
uniform float contrast = 1.25;
uniform float emissive_strength = 0.0;
uniform vec4 unlit_rect = vec4(-1.0, -1.0, -1.0, -1.0);
uniform float use_unlit_rect = 0.0;
uniform float chroma_limit = 0.16;
uniform float soft_light = 0.0;
uniform float soft_k = 1.5;
uniform vec2 lm_texel = vec2(0.0013, 0.0013);
uniform int wash_count = 0;
uniform vec4 wash_pos[24];
uniform vec4 wash_col[24];
uniform float mood_on = 1.0;
uniform int zone_count = 0;
uniform sampler2D mood_data : filter_nearest, repeat_disable;
varying vec3 v_world;
varying vec3 v_nw;
varying float v_ny;

float lum(vec3 c) { return dot(c, vec3(0.299, 0.587, 0.114)); }

void vertex() {
	v_nw = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
	v_ny = v_nw.y;
	v_world = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

// The classic shader's lit colour for this point (baked light, soft light, unlit page + vertex colour, ceilings,
// ROOM_MOODS rooms and lamps, grade, chroma, washes, floor). `base` is the picture colour; returns the lit colour and
// writes the (possibly ceiling-greyed) picture colour back to `base_out`.
vec3 classic_lit(vec3 base, vec2 uv2, vec4 vcol, out vec3 base_out) {
	vec3 raw = texture(lightmap_tex, uv2).rgb;
	if (soft_light > 0.5) {
		vec2 o = lm_texel * 0.75;
		vec3 s = texture(lightmap_tex, uv2 + vec2(o.x, o.y)).rgb + texture(lightmap_tex, uv2 + vec2(-o.x, o.y)).rgb
			+ texture(lightmap_tex, uv2 + vec2(o.x, -o.y)).rgb + texture(lightmap_tex, uv2 + vec2(-o.x, -o.y)).rgb;
		raw = mix(raw, s * 0.25, 0.7);
	}
	vec3 lm = raw * pow(light_boost, 2.2);
	float peak = max(lm.r, max(lm.g, lm.b));
	if (soft_light > 0.5) {
		lm *= (1.0 - exp(-soft_k * peak)) / max(peak, 0.0001);
	} else if (peak > 1.0) {
		lm /= peak;
	}
	float unlit = step(0.995, min(raw.r, min(raw.g, raw.b)));
	if (use_unlit_rect > 0.5) {
		unlit = (uv2.x >= unlit_rect.x && uv2.x <= unlit_rect.z && uv2.y >= unlit_rect.y && uv2.y <= unlit_rect.w) ? 1.0 : 0.0;
	}
	vec3 vertex_light = mix(vec3(1.0), pow(vcol.rgb, vec3(2.2)), unlit);
	float floor_level = ambient_floor;
	if (v_ny < -0.7) {
		floor_level = max(floor_level, ceiling_floor);
		if (emissive_strength < 0.01) {
			float grey = dot(base, vec3(0.3, 0.59, 0.11));
			base = vec3(max(grey, 0.06)) * vec3(0.92, 0.97, 1.08) * ceiling_grey;
		}
	}
	float zw = 0.0;
	vec4 ztint = vec4(1.0);
	vec4 zceil = vec4(0.0);
	float zdark = 0.0;
	vec3 mood_add = vec3(0.0);
	if (mood_on > 0.5 && zone_count > 0) {
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
				cone *= 1.0 - step(sd.y, 0.0) * smoothstep(-0.15, 0.08, l.y);
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
	float l1 = dot(lm, vec3(0.3, 0.59, 0.11));
	vec3 shadow_tint = vec3(1.25, 0.8, 1.45);
	vec3 light_tint = vec3(0.8, 1.2, 1.05);
	vec3 tint = mix(shadow_tint, light_tint, smoothstep(0.05, 0.6, l1));
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
	lm *= 1.0 - zw * zdark * smoothstep(zceil.x, max(zceil.y, zceil.x + 0.01), v_world.y);
	lm += mood_add;
	lm = max(lm, vec3(floor_level) * mix(vec3(1.0), shadow_tint, grade_strength));
	vec3 lit = base * lm * vertex_light;
	lit = max(lit, base * emissive_strength);
	base_out = base;
	return clamp(lit, 0.0, 1.0);
}

void fragment() {
	vec4 a = albedo_color;
	if (use_albedo_tex > 0.5) {
		a *= texture(albedo_tex, UV);
	}
	if (alpha_cut > 0.5 && a.a < 0.5) {
		discard;
	}
	ALBEDO = a.rgb;

	// relief: the picture's brightness read as height, sampled either side.
	// REV 554 (Glen: specks and background details flickered while the camera drifted): read from a
	// softer mip, two texels apart - single-texel relief made pixel-sized bumps that sparkled in the light
	if (use_albedo_tex > 0.5 && relief > 0.001) {
		vec2 ts = 2.0 / vec2(textureSize(albedo_tex, 0));
		float hl = lum(texture(albedo_tex, UV - vec2(ts.x, 0.0), 1.5).rgb);
		float hr = lum(texture(albedo_tex, UV + vec2(ts.x, 0.0), 1.5).rgb);
		float hd = lum(texture(albedo_tex, UV - vec2(0.0, ts.y), 1.5).rgb);
		float hu = lum(texture(albedo_tex, UV + vec2(0.0, ts.y), 1.5).rgb);
		vec3 n = normalize(vec3((hl - hr) * relief * 4.0, (hd - hu) * relief * 4.0, 1.0));
		NORMAL_MAP = n * 0.5 + 0.5;
	}

	// a little variation from the picture: darker bits a touch rougher (worn, dusty), lighter smoother
	float l = lum(a.rgb);
	ROUGHNESS = clamp(roughness * mix(1.12, 0.9, l), 0.04, 1.0);
	METALLIC = metallic;
	SPECULAR = specular;
	CLEARCOAT = clearcoat;
	CLEARCOAT_ROUGHNESS = clearcoat_roughness;

	if (classic_base > 0.5 && use_lightmap > 0.5) {
		// REV 732: the classic look is the surface's own light; real lamps add a little diffuse, shine and reflections
		vec3 b2;
		vec3 lit = classic_lit(a.rgb, UV2, COLOR, b2);
		ALBEDO = b2 * classic_diffuse;
		EMISSION = lit * classic_gain;
	} else if (use_lightmap > 0.5) {
		vec3 lm = texture(lightmap_tex, UV2).rgb * lightmap_boost;
		float ll = clamp(lum(lm), 0.0, 1.0);
		AO = mix(1.0, smoothstep(0.02, 0.75, ll), occlusion);
		AO_LIGHT_AFFECT = 0.25;
		EMISSION = a.rgb * lm * fill;
	}
	if (emissive > 0.0) {
		vec3 glow_col = mix(a.rgb, vec3(lum(a.rgb)), emissive_white);
		EMISSION += glow_col * emissive * emissive_energy;
	}
}
