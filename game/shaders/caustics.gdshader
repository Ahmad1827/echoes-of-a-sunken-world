// Rippling light focused by the waves above, projected onto a surface seen at a grazing angle.
shader_type canvas_item;
render_mode blend_add, unshaded;

uniform vec2 size = vec2(1000.0, 100.0);
uniform float strength = 0.35;
uniform vec3 tint = vec3(0.7, 0.95, 0.9);
uniform float scale = 900.0;
uniform float squash = 4.0;
uniform float speed = 0.35;
uniform float fade_top = 0.15;
uniform float fade_bottom = 0.15;

float caustic(vec2 p, float t) {
	vec2 i = p;
	float c = 1.0;
	float inten = 0.005;
	for (int n = 0; n < 5; n++) {
		float tt = t * (1.0 - (3.5 / float(n + 1)));
		i = p + vec2(cos(tt - i.x) + sin(tt + i.y), sin(tt - i.y) + cos(tt + i.x));
		c += 1.0 / length(vec2(p.x / (sin(i.x + tt) / inten), p.y / (cos(i.y + tt) / inten)));
	}
	c /= 5.0;
	c = 1.17 - pow(c, 1.4);
	return pow(abs(c), 8.0);
}

void fragment() {
	vec2 px = UV * size;
	vec2 p = vec2(px.x, px.y * squash) / scale;
	p = mod(p * 6.2831, 6.2831) - 250.0;
	float c = caustic(p, TIME * speed + 23.0);
	float fade = smoothstep(0.0, fade_top, UV.y) * (1.0 - smoothstep(1.0 - fade_bottom, 1.0, UV.y));
	COLOR = vec4(tint * clamp(c, 0.0, 1.6) * strength * fade, 1.0);
}
