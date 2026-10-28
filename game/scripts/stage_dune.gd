class_name StageDune
extends Stage
## The drowned seabed: a colossal rust-framed screen sinking into silt, a sunken city fading
## into green-blue depth behind it, sunlight falling from the surface far above.

const SCREEN := Rect2(190.0, 175.0, 2020.0, 423.0)
## The monolith art is authored large and scaled down toward its base so open water shows around it.
const ART_PIVOT := Vector2(1200.0, 748.0)
const ART_SCALE := 0.62
## The water rect starts at y = -300, so the surface sits at world y 210.
const WATER := Rect2(-800.0, -300.0, 4000.0, 1150.0)
const SURFACE := 510.0


func _init() -> void:
	title = "THE DROWNED MONOLITH"
	ground = 790.0
	arena = Vector2(300.0, 2100.0)
	glow = false
	water = true
	light_type = "sun"
	sun = Vector2(0.18, -0.07)
	light_dir = Vector2(-0.2, -0.98)
	shadow_alpha = 0.38
	shadow_blur = 4.5
	rim_color = Color(0.7, 0.95, 0.95, 0.3)
	spark_color = Color(2.0, 2.5, 2.6)
	dust_color = Color(0.62, 0.7, 0.64, 0.16)
	wind = 0.9
	step_sound = "step_sand"
	ambience = "amb_dune"


func build() -> Array:
	var water_bg := Node2D.new()
	water_bg.add_child(Sunken.shader_rect("res://shaders/water_column.gdshader", WATER,
		{"surface_y": SURFACE, "horizon_y": SURFACE + 560.0}))

	var city_far := Sunken.Ruins.new()
	city_far.seed_ = 404
	city_far.base_y = 715.0
	city_far.h_min = 160.0
	city_far.h_max = 440.0
	city_far.size_k = 0.8
	city_far.gap = Vector2(0.0, 40.0)
	city_far.color = Color(0.2, 0.4, 0.42)
	var city_near := Sunken.Ruins.new()
	city_near.seed_ = 77
	city_near.base_y = 735.0
	city_near.h_min = 120.0
	city_near.h_max = 520.0
	city_near.size_k = 1.1
	city_near.gap = Vector2(40.0, 220.0)
	city_near.color = Color(0.12, 0.27, 0.29)
	city_near.window_color = Color(0.22, 0.42, 0.44, 0.7)
	var city := Node2D.new()
	city.add_child(city_near)
	city.add_child(Sunken.shader_rect("res://shaders/light_rays.gdshader", WATER,
		{"top": SURFACE, "slant": 0.22, "length_px": 700.0, "strength": 0.32}))

	var mono := Node2D.new()
	var sv := SubViewport.new()
	sv.size = Vector2i(2400, 760)
	sv.transparent_bg = true
	sv.render_target_update_mode = SubViewport.UPDATE_ONCE
	var art := MonolithArt.new()
	art.scale = Vector2(ART_SCALE, ART_SCALE)
	art.position = ART_PIVOT * (1.0 - ART_SCALE)
	sv.add_child(art)
	mono.add_child(sv)
	var spr := Sprite2D.new()
	spr.centered = false
	spr.texture = sv.get_texture()
	spr.modulate = Color(0.6, 0.8, 0.8)
	mono.add_child(spr)
	var glitch := Glitch.new()
	glitch.scale = art.scale
	glitch.position = art.position
	mono.add_child(glitch)
	# weed trailing from the frame's lower edge and growing from the plinths
	var hanging := Sunken.Kelp.new()
	hanging.hang = true
	var xs: Array = []
	for i in 26:
		xs.append(560.0 + i * 50.0)
	hanging.setup(8, xs, 748.0 - (748.0 - 612.0) * ART_SCALE, Vector2(20.0, 90.0), Vector2(2.0, 4.0), Color(0.07, 0.16, 0.17))
	mono.add_child(hanging)
	mono.add_child(Sunken.fog_rect(Rect2(-800, -300, 4000, 1150), Color(0.18, 0.38, 0.4, 0.28)))

	var school := Sunken.School.new()
	school.setup(19, 60, Rect2(300.0, 260.0, 1800.0, 260.0), Color(0.1, 0.24, 0.26), 6.0)
	var rays_near := Node2D.new()
	rays_near.add_child(Sunken.shader_rect("res://shaders/light_rays.gdshader", WATER,
		{"top": SURFACE, "slant": 0.18, "length_px": 640.0, "strength": 0.2}))

	var dunes := Dunes.new()
	dunes.add_child(Sunken.shader_rect("res://shaders/caustics.gdshader", Rect2(-700.0, 742.0, 3800.0, 130.0),
		{"scale": 620.0, "squash": 4.0, "strength": 0.3, "fade_top": 0.3, "fade_bottom": 0.1}))
	var mid_kelp := Sunken.Kelp.new()
	mid_kelp.setup(55, [-100.0, -20.0, 90.0, 460.0, 520.0, 1900.0, 1960.0, 2350.0, 2420.0, 2500.0], 760.0,
		Vector2(160.0, 420.0), Vector2(5.0, 9.0), Color(0.1, 0.21, 0.21))
	dunes.add_child(mid_kelp)

	var near := Near.new()
	near.add_child(Sunken.shader_rect("res://shaders/caustics.gdshader", Rect2(-500.0, 768.0, 3400.0, 40.0),
		{"scale": 520.0, "squash": 5.0, "strength": 0.45, "fade_top": 0.4, "fade_bottom": 0.05}))
	var fore := Sunken.Kelp.new()
	fore.setup(63, [-380.0, -300.0, -210.0, 2600.0, 2700.0, 2790.0], 1200.0,
		Vector2(640.0, 920.0), Vector2(12.0, 19.0), Color(0.01, 0.025, 0.03))
	return [[water_bg, 0.04], [city_far, 0.1], [city, 0.18], [mono, 0.3], [school, 0.38], [rays_near, 0.45],
		[dunes, 0.6], [near, 1.0], [fore, 1.35]]


func ambient(ts: float, fx: FX, view: Rect2) -> void:
	if randf() < 1.4 * ts:
		fx.snow(Vector2(randf_range(view.position.x, view.end.x), randf_range(view.position.y, view.end.y)))
	if randf() < 0.012 * ts:
		fx.bubbles(Vector2(randf_range(view.position.x, view.end.x), ground - 2.0), randi_range(3, 8), 0.8)


class MonolithArt extends Node2D:
	func _draw() -> void:
		var rng := RandomNumberGenerator.new()
		rng.seed = 23
		var sc: Rect2 = StageDune.SCREEN
		draw_polygon(PackedVector2Array([Vector2(150, 160), Vector2(2250, 160), Vector2(2250, 612), Vector2(150, 612)]),
			PackedColorArray([Color("5a2519"), Color("5a2519"), Color("7a3424"), Color("7a3424")]))
		draw_rect(Rect2(150, 160, 2100, 452), Color(0, 0, 0, 0.12), false, 6.0)
		draw_rect(sc, Color("0a0b0f"))
		var cx: float = sc.get_center().x
		var cy: float = sc.position.y + 205.0
		for i in 60:
			var t: float = pow(i / 60.0, 1.3)
			var x0: float = lerpf(sc.position.x, cx - 170.0, t)
			var x1: float = lerpf(sc.end.x, cx + 170.0, t)
			var y0: float = lerpf(sc.position.y, cy - 65.0, t)
			var y1: float = lerpf(sc.end.y, cy + 65.0, t)
			draw_rect(Rect2(x0, y0, x1 - x0, y1 - y0), Color(0.8, 0.82, 0.86, 0.03 + 0.12 * (1.0 - t) * rng.randf()), false, 1.0 + rng.randf() * 1.5)
		for i in 260:
			draw_rect(Rect2(cx + rng.randf_range(-210.0, 210.0), cy + rng.randf_range(-85.0, 85.0), 2.0, 2.0),
				Color(0.6, 0.72, 0.92, rng.randf() * 0.6))
		var bottom: float = sc.end.y
		var x: float = sc.position.x
		while x < sc.end.x:
			var u: float = (x - cx) / (sc.size.x * 0.5)
			var h: float = 36.0 + 245.0 * pow(absf(u), 2.6) * (0.85 + rng.randf() * 0.3)
			h += round(135.0 * exp(-pow(u / 0.075, 2.0)) / 14.0) * 14.0
			if u > 0.74:
				h = sc.size.y * (0.55 + rng.randf() * 0.45)
			if u < -0.84:
				h = 170.0 + rng.randf() * 150.0
			var bright: float = 1.0 if u > 0.74 else 0.8
			var yy: float = bottom
			while yy > bottom - h:
				if rng.randf() > 0.18:
					var k: float = pow((bottom - yy) / h, 1.6)
					draw_rect(Rect2(x, yy, 2.0, 3.0), Color(0.9, 0.9, 0.92, (0.1 + 0.75 * k) * bright))
				yy -= 4.0
			x += 3.0
		var y: float = sc.position.y
		while y < bottom:
			draw_rect(Rect2(sc.position.x, y, sc.size.x, 1.5), Color(0, 0, 0, 0.18))
			y += 4.0
		# pillars and plinths beneath the screen
		var px: float = 200.0
		while px < 2200.0:
			if rng.randf() > 0.3:
				draw_line(Vector2(px, 612), Vector2(px, 612 + rng.randf_range(80.0, 140.0)),
					Color(0.11, 0.1, 0.12, rng.randf_range(0.35, 0.85)), 2.0)
			px += 5.0
		for span: Vector2 in [Vector2(380, 760), Vector2(1640, 2020), Vector2(1030, 1370)]:
			draw_colored_polygon(PackedVector2Array([Vector2(span.x + 30, 680), Vector2(span.y - 30, 680),
				Vector2(span.y, 748), Vector2(span.x, 748)]), Color("2b282d"))
			var bx: float = span.x + 14.0
			while bx < span.y - 14.0:
				draw_rect(Rect2(bx, 690, 4, 56), Color("1f1d21"))
				bx += 13.0
		draw_polygon(PackedVector2Array([Vector2(0, 640), Vector2(2400, 640), Vector2(2400, 760), Vector2(0, 760)]),
			PackedColorArray([Color(0.3, 0.5, 0.52, 0.0), Color(0.3, 0.5, 0.52, 0.0), Color(0.3, 0.5, 0.52, 0.8), Color(0.3, 0.5, 0.52, 0.8)]))


class Glitch extends Node2D:
	var bars: Array = []
	var scan := 0.0

	func _process(delta: float) -> void:
		scan = fmod(scan + delta * 40.0, StageDune.SCREEN.size.y)
		if randf() < 0.03:
			bars.append([randf_range(StageDune.SCREEN.position.x, StageDune.SCREEN.end.x), randf_range(2.0, 40.0), randf_range(0.05, 0.2)])
		for b: Array in bars:
			b[2] = float(b[2]) - delta
		bars = bars.filter(func(b: Array) -> bool: return float(b[2]) > 0.0)
		queue_redraw()

	func _draw() -> void:
		var sc: Rect2 = StageDune.SCREEN
		for b: Array in bars:
			draw_rect(Rect2(b[0], sc.position.y, b[1], sc.size.y), Color(0.95, 0.95, 1.0, 0.14))
		draw_rect(Rect2(sc.position.x, sc.position.y + scan, sc.size.x, 26.0), Color(1, 1, 1, 0.025))


class Dunes extends Node2D:
	func _draw() -> void:
		draw_polygon(PackedVector2Array([Vector2(-700, 742), Vector2(3100, 742), Vector2(3100, 1100), Vector2(-700, 1100)]),
			PackedColorArray([Color("456159"), Color("456159"), Color("7f8c7b"), Color("7f8c7b")]))
		var rng := RandomNumberGenerator.new()
		rng.seed = 41
		for k in 9:
			var y: float = 748.0 + k * 9.0
			var x0: float = rng.randf_range(-400.0, 2800.0)
			var w: float = rng.randf_range(500.0, 1100.0)
			var pts := PackedVector2Array()
			for i in 25:
				var t: float = i / 24.0
				pts.append(Vector2(x0 - w + 2.0 * w * t, y + 12.0 - sin(t * PI) * rng.randf_range(8.0, 14.0)))
			pts.append(Vector2(x0 + w, y + 14.0))
			pts.append(Vector2(x0 - w, y + 14.0))
			draw_colored_polygon(pts, Color(0.66, 0.74, 0.66, rng.randf_range(0.16, 0.34)))


class Near extends Node2D:
	func _draw() -> void:
		draw_polygon(PackedVector2Array([Vector2(-500, 768), Vector2(2900, 768), Vector2(2900, 806), Vector2(-500, 806)]),
			PackedColorArray([Color(0.55, 0.62, 0.54, 0.0), Color(0.55, 0.62, 0.54, 0.0), Color("8b9684"), Color("8b9684")]))
		draw_colored_polygon(PackedVector2Array([Vector2(-500, 806), Vector2(2900, 806), Vector2(2900, 1700), Vector2(-500, 1700)]), Color("030708"))
		var rng := RandomNumberGenerator.new()
		rng.seed = 7
		for i in 260:
			draw_rect(Rect2(rng.randf_range(-500.0, 2900.0), rng.randf_range(812.0, 1400.0), rng.randf_range(80.0, 300.0), 1.0),
				Color(1, 1, 1, rng.randf() * 0.04))
		draw_line(Vector2(-500, 806), Vector2(2900, 806), Color(0.7, 0.95, 0.95, 0.16), 1.5)
