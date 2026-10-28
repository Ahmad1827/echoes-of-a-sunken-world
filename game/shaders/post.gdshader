// Final grade: chromatic aberration on impacts, desaturation for the killing blow, vignette, film grain, flash.
shader_type canvas_item;
render_mode unshaded;

uniform sampler2D screen_tex : hint_screen_texture, repeat_disable, filter_linear;
uniform float ca = 0.0;
uniform float flash = 0.0;
uniform float desat = 0.0;
uniform float vignette = 0.7;
uniform float grain = 0.05;
uniform float water = 0.0;

float hash(vec2 p) {
	p = fract(p * vec2(443.897, 441.423));
	p += dot(p, p.yx + 19.19);
	return fract((p.x + p.y) * p.x);
}

void fragment() {
	vec2 uv = SCREEN_UV;
	// the faint refraction wobble of looking through water
	uv += vec2(sin(uv.y * 38.0 + TIME * 1.3) + sin(uv.y * 71.0 - TIME * 0.9) * 0.5,
		cos(uv.x * 29.0 + TIME * 1.1)) * 0.0009 * water;
	vec2 dir = uv - 0.5;
	float k = ca * 0.006 + 0.0007;
	vec3 c;
	c.r = textureLod(screen_tex, uv + dir * k, 0.0).r;
	c.g = textureLod(screen_tex, uv, 0.0).g;
	c.b = textureLod(screen_tex, uv - dir * k, 0.0).b;
	float lum = dot(c, vec3(0.299, 0.587, 0.114));
	c = mix(c, vec3(lum) * vec3(1.02, 1.0, 0.97), desat);
	float v = smoothstep(0.98, 0.2, length(dir * vec2(1.0, 0.85)));
	c *= mix(1.0 - vignette, 1.0, v);
	c += (hash(uv * vec2(1920.0, 1080.0) + fract(TIME * 7.13) * 91.7) - 0.5) * grain;
	c = mix(c, vec3(1.0), clamp(flash, 0.0, 1.0));
	COLOR = vec4(c, 1.0);
}
