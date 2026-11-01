// The drowned cavern on screen: the still walls baked by hollow_bake.gdshader, with the
// rippling caustic light moved over them every frame.
shader_type canvas_item;

uniform vec2 size = vec2(2800.0, 1600.0);
uniform sampler2D baked : repeat_disable, filter_linear;

float caustic(vec2 p, float t) {
	vec2 i = p;
	float c = 1.0;
	float inten = 0.005;
	for (int n = 0; n < 4; n++) {
		float tt = t * (1.0 - (3.5 / float(n + 1)));
		i = p + vec2(cos(tt - i.x) + sin(tt + i.y), sin(tt - i.y) + cos(tt + i.x));
		c += 1.0 / length(vec2(p.x / (sin(i.x + tt) / inten), p.y / (cos(i.y + tt) / inten)));
	}
	c /= 4.0;
	c = 1.17 - pow(c, 1.4);
	return pow(abs(c), 8.0);
}

void fragment() {
	vec4 wall = texture(baked, UV);
	float cs = caustic(mod(UV * size / 1100.0 * 6.2831, 6.2831) - 250.0, TIME * 0.3 + 11.0);
	COLOR = vec4(wall.rgb + vec3(0.45, 0.75, 0.72) * clamp(cs, 0.0, 1.4) * wall.a * 0.32, 1.0);
}
