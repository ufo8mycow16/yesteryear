// Animated moire disc for the TOS tricorder: plays Glen's 201-frame GIF from a flipbook sheet,
// stepping frames at the GIF's own rate (10 fps, 20.1 s loop) so it matches the original exactly.
// Sheet: tools/props/tricorder/make_moire.py (cells padded so mipmaps don't bleed between frames).
shader_type spatial;

uniform sampler2D atlas : source_color, filter_linear_mipmap, repeat_disable;
uniform int cols = 15;
uniform int rows = 14;
uniform int frames = 201;
uniform float fps = 10.0;
uniform float cell_frac = 0.96;          // cell / step (192 / 200): the frame inside its padding
uniform bool playing = true;
uniform int still_frame = 0;             // shown when not playing
uniform vec3 line_tint : source_color = vec3(1.0);
uniform float metal_on_light = 0.65;     // the light lines read as polished metal, the dark gaps as paint

void fragment() {
	int f = playing ? int(mod(floor(TIME * fps), float(frames))) : still_frame;
	vec2 cell = vec2(float(f % cols), float(f / cols));
	vec2 inner = (vec2(1.0) - vec2(cell_frac)) * 0.5 + clamp(UV, 0.0, 1.0) * cell_frac;
	vec2 uv = (cell + inner) / vec2(float(cols), float(rows));
	float v = texture(atlas, uv).r;
	ALBEDO = mix(vec3(0.02), vec3(0.85) * line_tint, v) * COLOR.rgb;
	METALLIC = metal_on_light * v;
	ROUGHNESS = mix(0.6, 0.3, v);
}
