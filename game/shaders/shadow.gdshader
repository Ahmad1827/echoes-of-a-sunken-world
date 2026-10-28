// Flattens the projected silhouettes of both fighters, blurs them and fades them with height.
// The red channel carries how strong the shadow is at each point (1 at the feet, lower up the body).
shader_type canvas_item;
render_mode unshaded;

uniform sampler2D screen_tex : hint_screen_texture, repeat_disable, filter_linear;
uniform float blur = 2.5;
uniform float strength = 0.6;
uniform vec3 tint = vec3(0.0);

void fragment() {
	vec2 px = SCREEN_PIXEL_SIZE * blur;
	float a = 0.0;
	float wsum = 0.0;
	for (int x = -3; x <= 3; x++) {
		for (int y = -2; y <= 2; y++) {
			float w = exp(-float(x * x + y * y) / 5.0);
			a += textureLod(screen_tex, SCREEN_UV + vec2(float(x), float(y)) * px, 0.0).r * w;
			wsum += w;
		}
	}
	COLOR = vec4(tint, clamp(a / wsum, 0.0, 1.0) * strength);
}
