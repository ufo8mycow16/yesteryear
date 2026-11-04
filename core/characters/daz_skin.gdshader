// REV 736 (Glen: "I want these characters looking so much better" - his Daz store pictures have far more
// realistic skin). The skin of every Daz character, replacing the general-purpose material it imported with.
// It keeps everything that was set up before (the colour picture, the scalp shade, the pore/shine/glow
// detail maps from the Daz library) and adds what real skin has and the general material couldn't do:
//  - a thin oily sheen on top (a second, softer shine - Daz's "dual lobe" / top coat),
//  - light glowing THROUGH thin skin (ears, nostrils, fingers, the nose edge) when lit from behind,
//  - fine skin texture (T'Nal's micro detail map, repeated many times) that fades in only close up, so
//    conversation close-ups show skin, not plastic, and nothing shimmers further away,
//  - a soft velvety edge where the skin turns away from the camera.
// Made from the old material by CharacterLook.gd. Off at the LOW graphics settings (the old material stays).
shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_back, diffuse_burley, specular_schlick_ggx, sss_mode_skin;

uniform vec4 albedo : source_color = vec4(1.0);
uniform sampler2D albedo_tex : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform bool use_vertex_colour = false;          // REV 712: crew scalp shade (the colour per point)
uniform vec3 uv1_scale = vec3(1.0);
uniform vec3 uv1_offset = vec3(0.0);

uniform sampler2D normal_tex : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform bool has_normal = false;
uniform float normal_strength = 0.6;

uniform sampler2D rough_tex : hint_roughness_gray, filter_linear_mipmap, repeat_enable;
uniform bool has_rough = false;
uniform float roughness_value : hint_range(0.0, 1.0) = 0.62;
uniform float specular_value : hint_range(0.0, 1.0) = 0.35;
// REV 737 (Glen: "everybody's faces are made of plastic"): skin is never glossier than this, whatever a
// shine map says (some Daz maps were made for Daz's two-layer skin and read as wet in a one-layer shine)
uniform float rough_floor : hint_range(0.0, 1.0) = 0.55;

uniform sampler2D sss_tex : hint_default_white, filter_linear_mipmap, repeat_enable;
uniform float sss_strength : hint_range(0.0, 1.0) = 0.35;
uniform vec4 transmit_colour : source_color = vec4(0.86, 0.30, 0.20, 1.0);
uniform float transmit_depth = 0.10;
uniform float transmit_boost : hint_range(0.0, 1.0) = 0.25;

uniform float sheen : hint_range(0.0, 1.0) = 0.0;           // the oily layer's strength (REV 737: lips only)
uniform float sheen_roughness : hint_range(0.0, 1.0) = 0.6;
uniform float rim_amount : hint_range(0.0, 1.0) = 0.0;
uniform float rim_tint : hint_range(0.0, 1.0) = 0.6;

uniform sampler2D micro_normal : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform bool has_micro = false;
uniform float micro_tiles = 5.0;                 // repeats per picture width
uniform float micro_strength = 0.35;
uniform float micro_near = 0.5;                   // metres from the camera: full strength closer than this
uniform float micro_far = 2.4;                    // gone beyond this

// REV 740: crease shading baked from the figure's own shape (tools/crew/bake_skin_ao.py) - the eye
// sockets, beside the nose, the lip corners, under the jaw, inside the ears. It mostly darkens the
// even all-round light (where flat rooms left faces looking like dolls), a little of the direct light,
// and a touch of the colour itself so it still reads in rooms lit only by lamps.
// REV 749 (Glen's bug list 9 + 27/30: "he looks sick. like malnourished ... it's a thing across all of the crew kit";
// Sulu and Chekov pale too): Daz's skin pictures are painted for Daz's own renderer, whose deep light-through-skin
// adds the warmth and colour back - drawn here they came out grey-pink and washed. The colour picture is given that
// life back here, for every Daz figure (leads and the whole crew kit): a little more colour, a touch warmer, a
// touch deeper. Previewed on the crew kit's skins (all tones) before choosing these.
uniform float skin_saturation : hint_range(0.5, 2.0) = 1.15;
uniform vec3 skin_warmth = vec3(1.03, 0.99, 0.96);
uniform float skin_depth : hint_range(0.5, 1.2) = 0.95;

uniform sampler2D ao_tex : hint_default_white, filter_linear_mipmap, repeat_enable;
uniform bool has_ao = false;
uniform float ao_strength : hint_range(0.0, 1.0) = 1.0;
uniform float ao_colour : hint_range(0.0, 1.0) = 0.35;
uniform float ao_direct : hint_range(0.0, 1.0) = 0.2;

varying vec2 raw_uv;

void vertex() {
	raw_uv = UV;
	UV = UV * uv1_scale.xy + uv1_offset.xy;
}

void fragment() {
	vec4 c = texture(albedo_tex, UV) * albedo;
	if (use_vertex_colour) {
		c.rgb *= COLOR.rgb;
	}
	float luma = dot(c.rgb, vec3(0.2126, 0.7152, 0.0722));
	c.rgb = max(vec3(0.0), vec3(luma) + (c.rgb - vec3(luma)) * skin_saturation) * skin_warmth * skin_depth;
	if (has_ao) {
		float ao = mix(1.0, texture(ao_tex, raw_uv).r, ao_strength);
		c.rgb *= mix(1.0, ao, ao_colour);
		AO = ao;
		AO_LIGHT_AFFECT = ao_direct;
	}
	ALBEDO = c.rgb;

	vec2 n_xy = vec2(0.0);
	if (has_normal) {
		n_xy = (texture(normal_tex, UV).xy * 2.0 - 1.0) * normal_strength;
	}
	float micro_k = 0.0;
	if (has_micro) {
		float dist = length(VERTEX);
		micro_k = (1.0 - smoothstep(micro_near, micro_far, dist)) * micro_strength;
		if (micro_k > 0.001) {
			n_xy += (texture(micro_normal, UV * micro_tiles).xy * 2.0 - 1.0) * micro_k;
		}
	}
	if (has_normal || micro_k > 0.001) {
		NORMAL_MAP = vec3(n_xy * 0.5 + 0.5, 1.0);
		NORMAL_MAP_DEPTH = 1.0;
	}

	float r = roughness_value;
	if (has_rough) {
		r = texture(rough_tex, UV).r * roughness_value;   // as the standard material: picture x value
	}
	ROUGHNESS = max(r, rough_floor);
	SPECULAR = specular_value;

	CLEARCOAT = sheen;
	CLEARCOAT_ROUGHNESS = sheen_roughness;
	RIM = rim_amount;
	RIM_TINT = rim_tint;

	SSS_STRENGTH = sss_strength * texture(sss_tex, UV).r;
	SSS_TRANSMITTANCE_COLOR = transmit_colour;
	SSS_TRANSMITTANCE_DEPTH = transmit_depth;
	SSS_TRANSMITTANCE_BOOST = transmit_boost;
}
