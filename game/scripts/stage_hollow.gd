class_name StageHollow
extends Stage
## A drowned ribbed cavern. Its round window opens onto a sunken city under the sunlit surface.

const PC := Vector2(1200.0, 405.0)
const PR := 140.0
const BG_POS := Vector2(-200.0, -320.0)
const BG_SIZE := Vector2(2800.0, 1650.0)
const VENTS := [520.0, 900.0, 1540.0, 1930.0]


func _init() -> void:
	title = "THE HOLLOW GATE"
	ground = 770.0
	arena = Vector2(380.0, 2050.0)
	glow = false
	water = true
	light_type = "point"
	light_pos = Vector2(1200.0, 620.0)
	light_depth = 1300.0
	squash = 0.032
	shadow_alpha = 0.6
	shadow_blur = 2.8
	rim_color = Color(0.74, 0.95, 0.94, 0.55)
	spark_color = Color(2.0, 2.6, 2.8)
	dust_color = Color(0.62, 0.8, 0.8, 0.14)
	wind = 0.5
	step_sound = "step_stone"
	ambience = "amb_hollow"


func build() -> Array:
	var far := Node2D.new()
	# the walls are far too costly to work out every frame, and they don't move: draw them once
	var bake := SubViewport.new()
	bake.size = Vector2i(BG_SIZE)
	bake.transparent_bg = true
	bake.use_hdr_2d = true
	bake.render_target_update_mode = SubViewport.UPDATE_ONCE
	bake.add_child(Sunken.shader_rect("res://shaders/hollow_bake.gdshader", Rect2(Vector2.ZERO, BG_SIZE),
		{"portal": PC - BG_POS, "portal_r": PR}))
	far.add_child(bake)
	far.add_child(Sunken.shader_rect("res://shaders/hollow_bg.gdshader", Rect2(BG_POS, BG_SIZE),
		{"baked": bake.get_texture()}))
	var glow_s := Sprite2D.new()
	glow_s.texture = U.radial_texture(256)
	glow_s.position = PC
	glow_s.scale = Vector2(4.8, 4.8)
	glow_s.modulate = Color(0.55, 0.86, 0.84, 0.2)
	var add := CanvasItemMaterial.new()
	add.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	glow_s.material = add
	far.add_child(glow_s)
	far.add_child(Portal.new())
	far.add_child(Sunken.shader_rect("res://shaders/rays.gdshader", Rect2(BG_POS, BG_SIZE),
		{"origin": PC - BG_POS, "radius": PR, "tint": Vector3(0.6, 0.9, 0.88), "strength": 0.3}))

	# fogged kelp rooted behind the platform
	var mid := Sunken.Kelp.new()
	mid.setup(12, [60.0, 140.0, 260.0, 330.0, 2050.0, 2140.0, 2230.0, 2330.0], 760.0,
		Vector2(240.0, 520.0), Vector2(5.0, 9.0), Color(0.07, 0.17, 0.18))

	var near := Node2D.new()
	var top := PlatformTop.new()
	top.clip_children = CanvasItem.CLIP_CHILDREN_AND_DRAW
	top.add_child(Sunken.shader_rect("res://shaders/caustics.gdshader", Rect2(-300.0, 730.0, 3000.0, 90.0),
		{"scale": 700.0, "squash": 5.0, "strength": 0.42, "tint": Vector3(0.62, 0.95, 0.92), "fade_top": 0.25, "fade_bottom": 0.05}))
	near.add_child(top)
	near.add_child(PlatformFront.new())

	var fore := Sunken.Kelp.new()
	fore.setup(31, [-320.0, -240.0, -150.0, 2560.0, 2650.0, 2740.0], 1180.0,
		Vector2(620.0, 900.0), Vector2(11.0, 18.0), Color(0.01, 0.025, 0.03))
	return [[far, 0.22], [mid, 0.6], [near, 1.0], [fore, 1.35]]


func ambient(ts: float, fx: FX, view: Rect2) -> void:
	if randf() < 1.2 * ts:
		fx.snow(Vector2(randf_range(view.position.x, view.end.x), randf_range(view.position.y, view.end.y)))
	for vx: float in VENTS:
		if randf() < 0.02 * ts:
			fx.bubbles(Vector2(vx + randf_range(-8.0, 8.0), 744.0), randi_range(2, 6), 0.7)


class Portal extends Node2D:
	func _ready() -> void:
		var c: Vector2 = StageHollow.PC
		var r: float = StageHollow.PR
		var box := Rect2(c - Vector2(r, r), Vector2(r, r) * 2.0)
		var disc := PortalSky.new()
		disc.clip_children = CanvasItem.CLIP_CHILDREN_AND_DRAW
		add_child(disc)
		disc.add_child(Sunken.shader_rect("res://shaders/water_column.gdshader", box,
			{"surface_y": 18.0, "horizon_y": 2.0 * r, "top_col": Vector3(0.42, 0.66, 0.66), "deep_col": Vector3(0.16, 0.34, 0.37)}))
		var far := Sunken.Ruins.new()
		far.seed_ = 71
		far.x0 = box.position.x - 40.0
		far.x1 = box.end.x + 40.0
		far.base_y = c.y + 70.0
		far.h_min = 50.0
		far.h_max = 150.0
		far.size_k = 0.32
		far.gap = Vector2(2.0, 16.0)
		far.color = Color(0.3, 0.52, 0.53)
		disc.add_child(far)
		var school := Sunken.School.new()
		school.setup(5, 26, Rect2(box.position.x + 40.0, c.y - 80.0, 2.0 * r - 80.0, 70.0), Color(0.22, 0.4, 0.42), 3.2)
		school.speed = 0.08
		disc.add_child(school)
		var near := Sunken.Ruins.new()
		near.seed_ = 3
		near.x0 = box.position.x - 60.0
		near.x1 = box.end.x + 60.0
		near.base_y = c.y + 110.0
		near.h_min = 80.0
		near.h_max = 230.0
		near.size_k = 0.5
		near.gap = Vector2(4.0, 30.0)
		near.color = Color(0.13, 0.27, 0.29)
		near.window_color = Color(0.36, 0.58, 0.57, 0.55)
		disc.add_child(near)
		disc.add_child(Sunken.shader_rect("res://shaders/light_rays.gdshader", box,
			{"top": 0.0, "slant": 0.3, "length_px": 230.0, "strength": 0.5}))
		add_child(Rim.new())


class PortalSky extends Node2D:
	func _draw() -> void:
		draw_colored_polygon(U.circle(StageHollow.PC, StageHollow.PR, 72), Color(0.3, 0.52, 0.53))


class Rim extends Node2D:
	func _draw() -> void:
		var c: Vector2 = StageHollow.PC
		var r: float = StageHollow.PR
		var rng := RandomNumberGenerator.new()
		rng.seed = 9
		draw_arc(c, r + 3.0, 0.0, TAU, 128, Color(0.03, 0.06, 0.06), 9.0, true)
		var a: float = -PI
		while a < PI:
			var length: float = 16.0 + rng.randf() * 20.0
			for a0: float in [-2.2, -0.94]:
				length += 130.0 * exp(-pow(a - a0, 2.0) / 0.03)
			length += 30.0 * exp(-pow(a + PI * 0.5, 2.0) / 0.4)
			var v: float = 0.8 if rng.randf() < 0.5 else 0.38
			var col := Color(v * 0.9, v + 0.04, v + 0.03, 0.45 + rng.randf() * 0.45)
			var dir := Vector2.from_angle(a)
			var lift: float = length * 0.25 if length > 50.0 else 0.0
			draw_line(c + dir * (r - 4.0), c + dir * (r + length) + Vector2(0, -lift), col, 2.0 + rng.randf() * 1.6, true)
			a += 0.016


class PlatformTop extends Node2D:
	func _draw() -> void:
		var top := PackedVector2Array([Vector2(250, 742), Vector2(2700, 735), Vector2(2700, 800),
			Vector2(-300, 812), Vector2(-300, 776)])
		var cols := PackedColorArray([Color("4f6b6e"), Color("4f6b6e"), Color("8fabab"), Color("8fabab"), Color("6f8c8e")])
		draw_polygon(top, cols)


class PlatformFront extends Node2D:
	func _draw() -> void:
		draw_colored_polygon(PackedVector2Array([Vector2(-300, 812), Vector2(2700, 800), Vector2(2700, 1700),
			Vector2(-300, 1700)]), Color("020607"))
		var rng := RandomNumberGenerator.new()
		rng.seed = 3
		for i in 520:
			var x: float = rng.randf_range(-300.0, 2700.0)
			var y: float = rng.randf_range(818.0, 1500.0)
			draw_line(Vector2(x, y), Vector2(x, y + rng.randf_range(30.0, 220.0)),
				Color(0.4, 0.6, 0.62, rng.randf_range(0.02, 0.08)), 1.0)
		draw_line(Vector2(-300, 812), Vector2(2700, 800), Color(0.7, 0.95, 0.95, 0.45), 1.6, true)
		draw_line(Vector2(250, 742), Vector2(2700, 735), Color(0.15, 0.26, 0.27, 0.6), 1.2, true)
		draw_line(Vector2(250, 742), Vector2(-300, 776), Color(0.4, 0.55, 0.57, 0.6), 1.2, true)
