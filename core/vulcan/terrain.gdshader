shader_type spatial;
// REV 883 - Glen's World Creator basin round a desert room (VulcanTerrain.gd). The room's own patch is flattened to
// its ground (sink metres below it, so the room's sand tiles always sit on top), rising smoothly into the real slopes
// beyond; anything lower than the room is filled flat - the basin floor never drops away under the dunes.

uniform sampler2D colour_tex : source_color, filter_linear_mipmap, repeat_disable;
uniform sampler2D normal_tex : hint_normal, filter_linear_mipmap, repeat_disable;
uniform vec4 tint : source_color = vec4(1.0);
uniform vec2 spot = vec2(0.0);          // the room's spot in the mesh's own metres (x, z)
uniform float spot_h = 0.0;             // its ground height
uniform float flat_radius = 90.0;       // fully flat out to here
uniform float blend = 280.0;            // ... then rises to the real ground over this far
uniform float sink = 1.5;               // the flat lies this far under the room's own ground (under the dune tiles too)
uniform vec4 near_colour : source_color = vec4(0.70, 0.43, 0.29, 1.0);   // the flat patch: the rooms' sand
uniform float roughness_value = 0.92;
uniform float normal_strength = 1.0;

varying float keep;     // 0 = flattened, 1 = the real ground

void vertex() {
	float d = distance(VERTEX.xz, spot);
	float t = smoothstep(flat_radius, flat_radius + blend, d);
	float real_y = max(VERTEX.y, spot_h);          // valleys below the room filled flat
	float filled = VERTEX.y < spot_h ? 0.0 : 1.0;
	VERTEX.y = mix(spot_h - sink, real_y, t);
	keep = t * filled;
	NORMAL = normalize(mix(vec3(0.0, 1.0, 0.0), NORMAL, keep));
}

void fragment() {
	ALBEDO = mix(near_colour.rgb, texture(colour_tex, UV).rgb * tint.rgb, smoothstep(0.0, 0.55, keep));
	ROUGHNESS = roughness_value;
	NORMAL_MAP = texture(normal_tex, UV).rgb;
	NORMAL_MAP_DEPTH = normal_strength * mix(0.25, 1.0, keep);
}
