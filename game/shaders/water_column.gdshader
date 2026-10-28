// The open water: the rippled underside of the surface far above, fading into green-blue depth.
shader_type canvas_item;

uniform vec2 size = vec2(3000.0, 1500.0);
uniform float surface_y = 160.0;
uniform float horizon_y = 1050.0;
uniform vec3 surface_col = vec3(0.78, 0.93, 0.9);
uniform vec3 top_col = vec3(0.3, 0.55, 0.57);
uniform vec3 deep_col = vec3(0.07, 0.2, 0.23);

float hash(vec2 p) {
	p = fract(p * vec2(123.34, 456.21));
	p += dot(p, p + 45.32);
	return fract(p.x * p.y);
}
float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), u.x), mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), u.x), u.y);
}
float fbm(vec2 p) {
	float v = 0.0;
	float a = 0.5;
	for (int i = 0; i < 5; i++) {
		v += a * noise(p);
		p = p * 2.07 + vec2(3.1, 1.7);
		a *= 0.5;
	}
	return v;
}

void fragment() {
	vec2 px = UV * size;
	float d = clamp((px.y - surface_y) / (horizon_y - surface_y), 0.0, 1.0);
	vec3 col = mix(top_col, deep_col, pow(d, 0.75));
	// brighter column toward the middle where the light comes down
	col *= 0.85 + 0.25 * exp(-pow((px.x - size.x * 0.5) / (size.x * 0.35), 2.0));

	// the underside of the waves: cells of bright refracted sky
	float s = smoothstep(surface_y + 90.0, surface_y - 30.0, px.y);
	vec2 q = vec2(px.x / 120.0, px.y / 30.0) + vec2(TIME * 0.07, TIME * 0.03);
	float w1 = fbm(q);
	float w2 = fbm(q * 1.9 + vec2(4.0, -TIME * 0.05));
	float cells = pow(1.0 - abs(sin((w1 + w2 * 0.6) * 9.0)), 5.0);
	vec3 surf = surface_col * (0.62 + 0.6 * cells);
	col = mix(col, surf, s);
	COLOR = vec4(col, 1.0);
}
