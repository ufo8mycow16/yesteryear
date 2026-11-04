shader_type canvas_item;
// REV 103: behind menus - the game, softly blurred and dimmed. strength 0..1 fades it in.
uniform sampler2D screen_texture : hint_screen_texture, filter_linear_mipmap;
uniform float strength : hint_range(0.0, 1.0) = 1.0;
uniform float darken : hint_range(0.0, 1.0) = 0.45;
uniform float radius = 3.0;   // in screen pixels, at blur level 1.5

void fragment() {
	vec3 sharp = texture(screen_texture, SCREEN_UV).rgb;
	vec2 px = SCREEN_PIXEL_SIZE * radius;
	vec3 sum = vec3(0.0);
	float wsum = 0.0;
	for (int x = -2; x <= 2; x++) {
		for (int y = -2; y <= 2; y++) {
			float w = exp(-float(x * x + y * y) / 4.5);
			sum += textureLod(screen_texture, SCREEN_UV + vec2(float(x), float(y)) * px, 1.5).rgb * w;
			wsum += w;
		}
	}
	vec3 soft = sum / wsum;
	vec3 c = mix(sharp, soft, strength) * (1.0 - darken * strength);
	COLOR = vec4(c, 1.0);
}
