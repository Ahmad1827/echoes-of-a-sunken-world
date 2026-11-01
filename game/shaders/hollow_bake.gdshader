// The still part of the drowned cavern, drawn once when the stage loads: bundles of ribbed tubes that
// run as columns at the edges and curl into rings around the portal, with green-blue depth haze.
// Alpha carries how strongly the moving caustics light each point; hollow_bg.gdshader adds them per frame.
shader_type canvas_item;
render_mode blend_disabled, unshaded;

uniform vec2 size = vec2(2800.0, 1600.0);
uniform vec2 portal = vec2(1400.0, 630.0);
uniform float portal_r = 150.0;
uniform float tube = 64.0;
uniform vec3 water = vec3(0.12, 0.27, 0.29);

float hash(vec2 p) {
	p = fract(p * vec2(123.34, 456.21));
	p += dot(p, p + 45.32);
	return fract(p.x * p.y);
}

float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), u.x),
			mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), u.x), u.y);
}

float fbm(vec2 p) {
	float v = 0.0;
	float a = 0.5;
	for (int i = 0; i < 5; i++) {
		v += a * noise(p);
		p = p * 2.03 + vec2(1.7, 9.2);
		a *= 0.5;
	}
	return v;
}

void fragment() {
	vec2 px = UV * size;
	vec2 d = px - portal;
	float r = length(d);
	float ang = atan(d.y, d.x);
	float t = 0.0;

	// blend between rings around the portal and vertical columns further out
	float wp = exp(-pow(max(r - portal_r, 0.0) / 560.0, 2.0));
	vec2 warp = vec2(fbm(px / 330.0 + t), fbm(px / 330.0 + vec2(5.2, 1.3) - t));
	float wide = 0.7 + 0.6 * fbm(px / 900.0 + 11.0);
	float field = mix(px.x, r, wp) / (tube * wide) + (warp.x - 0.5) * 4.4 + (fbm(px / 160.0) - 0.5) * 0.8;
	float tid = floor(field);
	float tf = fract(field);
	float cyl = sqrt(max(0.0, 1.0 - pow(tf * 2.0 - 1.0, 2.0)));

	// ribs run across each tube; around the portal use an integer rib count per ring so it closes cleanly
	float rib_w = 5.0 + hash(vec2(tid, 3.0)) * 3.5;
	float ring_r = (tid + 0.5) * tube;
	float k_ring = floor(6.2831 * max(ring_r, 1.0) / rib_w);
	float ph_c = (px.y + warp.y * 80.0) / rib_w * 6.2831;
	float ph_p = ang * k_ring + warp.y * 6.0;
	float ph = mix(ph_c, ph_p, smoothstep(0.25, 0.75, wp)) + tid * 1.7;
	float rib = 0.5 + 0.5 * sin(ph);
	float aa = clamp(fwidth(ph) / 6.2831 * 1.4, 0.0, 1.0);
	rib = mix(rib, 0.5, aa);
	rib = pow(rib, 0.8);

	float bright = 0.35 + 0.65 * hash(vec2(tid, 7.0));
	float big = fbm(px / 700.0 + 3.0);
	float shade = cyl * (0.22 + 0.78 * rib) * bright * (0.25 + 1.1 * big * big);
	// dark crevices between tubes
	shade *= smoothstep(0.0, 0.12, tf) * smoothstep(1.0, 0.88, tf);

	vec3 col = vec3(0.27, 0.42, 0.42) * shade + vec3(0.02, 0.04, 0.045);
	// caustics ripple over the ridges, strongest near the portal where the light enters
	float lit = 0.25 + 0.75 * exp(-max(r - portal_r, 0.0) / 650.0);
	float caustic_amount = cyl * (0.4 + 0.6 * rib) * lit;

	// dark vault above the portal
	float cav = exp(-pow(length((px - portal - vec2(0.0, -250.0)) / vec2(400.0, 330.0)), 2.0));
	col *= 1.0 - 0.82 * cav;
	caustic_amount *= 1.0 - 0.82 * cav;
	// portal light spilling over the ribs
	float spill = exp(-max(r - portal_r, 0.0) / 240.0);
	col += vec3(0.42, 0.62, 0.6) * spill * cyl * rib * 0.38;
	// water swallows the far walls and pools toward the floor
	float edge = smoothstep(500.0, 1300.0, abs(px.x - portal.x));
	float fog = smoothstep(portal.y - 200.0, portal.y + 440.0, px.y);
	float haze = clamp(0.22 + fog * 0.4 + edge * 0.3, 0.0, 0.85);
	col = mix(col, water, haze);
	COLOR = vec4(col, caustic_amount * (1.0 - haze));
}
