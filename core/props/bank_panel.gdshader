// REV 706 (Glen, 30 Oct: his computer bank panel - "I thought it looked good with the oscilloscope, that was my
// request" / "if you can make it move, I'll love you forever"): the Deck 7 computer core's bank panels
// (ModelRoom.BANK_PANELS) - Glen's picture, with the round oscilloscope's trace redrawn live: a green sine sweeping
// across its screen, breathing in height, over a faint graticule. Each panel has its own phase so no two match.
shader_type spatial;
render_mode unshaded, cull_disabled;

uniform sampler2D panel : source_color, filter_linear_mipmap, repeat_disable;
uniform float phase = 0.0;
uniform float dim = 0.92;

// the picture's size and the scope screen in it (pixels, measured on assets/signs/core_bank_panel.png)
const vec2 SIZE = vec2(2172.0, 494.0);
const vec2 SC = vec2(1835.0, 128.0);
const float SR = 58.0;

void fragment() {
	vec2 p = UV * SIZE;
	vec3 col = texture(panel, UV).rgb;
	float d = length(p - SC);
	if (d < SR + 1.0) {
		vec3 scr = vec3(0.03, 0.17, 0.11) * (1.0 - 0.45 * d / SR);
		vec2 g = abs(fract((p - SC) / 20.0 + 0.5) - 0.5) * 20.0;
		scr += vec3(0.10, 0.35, 0.25) * (1.0 - smoothstep(0.0, 0.9, min(g.x, g.y))) * 0.16;
		float t = TIME * 2.4 + phase;
		float amp = 26.0 * (0.8 + 0.2 * sin(TIME * 0.9 + phase * 1.7));
		float x = p.x - SC.x;
		float yv = SC.y + amp * sin(x * 0.075 + t) * (1.0 - 0.15 * sin(x * 0.03 - t * 0.5));
		float dist = abs(p.y - yv);
		scr += vec3(0.35, 1.0, 0.75) * (exp(-dist * dist / 5.0) * 1.2 + exp(-dist * dist / 60.0) * 0.25);
		col = mix(col, scr, smoothstep(SR, SR - 2.5, d));
	}
	ALBEDO = col * dim;
}
