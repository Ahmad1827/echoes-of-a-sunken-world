// Shafts of sunlight slanting down through the water, drifting and flickering with the waves.
shader_type canvas_item;
render_mode blend_add, unshaded;

uniform vec2 size = vec2(3000.0, 1500.0);
uniform float top = 0.0;
uniform float slant = 0.2;
uniform float length_px = 650.0;
uniform float strength = 0.3;
uniform vec3 tint = vec3(0.62, 0.88, 0.85);

float hash1(float n) { return fract(sin(n) * 43758.5453); }
float n1(float x) {
	float i = floor(x);
	float f = fract(x);
	return mix(hash1(i), hash1(i + 1.0), f * f * (3.0 - 2.0 * f));
}
float f1(float x) {
	return n1(x) * 0.55 + n1(x * 2.13 + 7.0) * 0.3 + n1(x * 4.7 + 3.0) * 0.15;
}

void fragment() {
	vec2 px = UV * size;
	float depth = max(px.y - top, 0.0);
	float x = px.x + depth * slant;
	float r = smoothstep(0.5, 0.95, f1(x / 90.0 + TIME * 0.05));
	float r2 = smoothstep(0.55, 1.0, f1(x / 31.0 - TIME * 0.09 + 11.0));
	float flicker = 0.75 + 0.25 * f1(x / 60.0 + TIME * 0.6);
	float fall = exp(-depth / length_px) * smoothstep(0.0, 60.0, depth);
	COLOR = vec4(tint * (r * 0.75 + r2 * 0.4) * flicker * fall * strength, 1.0);
}
