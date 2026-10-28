// Soft light shafts falling out of the portal.
shader_type canvas_item;
render_mode blend_add, unshaded;

uniform vec2 size = vec2(2800.0, 1600.0);
uniform vec2 origin = vec2(1400.0, 630.0);
uniform float radius = 150.0;
uniform float strength = 0.22;
uniform vec3 tint = vec3(0.95, 0.84, 0.8);

float h1(float n) { return fract(sin(n) * 43758.5453); }
float n1(float x) {
	float i = floor(x);
	float f = fract(x);
	return mix(h1(i), h1(i + 1.0), f * f * (3.0 - 2.0 * f));
}

void fragment() {
	vec2 p = UV * size - origin;
	float r = length(p);
	float a = atan(p.y, p.x);
	float rays = n1(a * 17.0 + TIME * 0.06) * 0.6 + n1(a * 43.0 - TIME * 0.09) * 0.4;
	rays = pow(rays, 2.6);
	float fall = smoothstep(radius - 10.0, radius + 30.0, r) * exp(-(r - radius) / 560.0);
	float down = smoothstep(-0.1, 0.9, sin(a));
	COLOR = vec4(tint * rays * fall * down * strength, 1.0);
}
