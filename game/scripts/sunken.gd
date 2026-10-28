class_name Sunken
extends RefCounted
## Shared pieces of the drowned world: fogged ruins, swaying kelp, fish schools and shader planes.


static func shader_rect(path: String, rect: Rect2, params: Dictionary = {}) -> ColorRect:
	var r := ColorRect.new()
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	r.position = rect.position
	r.size = rect.size
	var m := ShaderMaterial.new()
	m.shader = load(path)
	m.set_shader_parameter("size", rect.size)
	for k: String in params:
		m.set_shader_parameter(k, params[k])
	r.material = m
	return r


static func fog_rect(rect: Rect2, color: Color) -> ColorRect:
	var r := ColorRect.new()
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	r.position = rect.position
	r.size = rect.size
	r.color = color
	return r


## A skyline of drowned architecture: leaning towers with dead windows, broken arches,
## colonnades, domes and spires, standing on a bank of rubble.
class Ruins extends Node2D:
	var seed_ := 1
	var x0 := -500.0
	var x1 := 2900.0
	var base_y := 700.0
	var h_min := 120.0
	var h_max := 420.0
	var size_k := 1.0
	var color := Color.BLACK
	var window_color := Color(0, 0, 0, 0)
	var gap := Vector2(10.0, 90.0)

	func _draw() -> void:
		var rng := RandomNumberGenerator.new()
		rng.seed = seed_
		var x: float = x0
		while x < x1:
			var w: float = rng.randf_range(50.0, 170.0) * size_k
			var h: float = rng.randf_range(h_min, h_max)
			var tilt: float = rng.randf_range(-0.14, 0.14) if rng.randf() < 0.6 else 0.0
			var base := Vector2(x + w * 0.5, base_y + rng.randf_range(0.0, 24.0))
			match rng.randi() % 7:
				0, 1, 2:
					_tower(rng, base, w, h, tilt)
				3:
					_arch(rng, base, w * 1.5, h * 0.6)
				4:
					_columns(rng, base, w * 1.6, h * 0.55)
				5:
					_dome(rng, base, w * 1.3, h * 0.5)
				_:
					_spire(base, w * 0.55, h * 1.3, tilt)
			x += w + rng.randf_range(gap.x, gap.y)
		_rubble(rng)

	func _poly(base: Vector2, tilt: float, pts: Array) -> PackedVector2Array:
		var out := PackedVector2Array()
		for q: Vector2 in pts:
			out.append(base + q.rotated(tilt))
		return out

	func _tower(rng: RandomNumberGenerator, base: Vector2, w: float, h: float, tilt: float) -> void:
		var hw: float = w * 0.5
		var pts: Array = [Vector2(-hw, 40), Vector2(-hw, -h)]
		var broken: bool = rng.randf() < 0.55
		var n := 5
		for i in range(1, n):
			var t: float = float(i) / n
			var dy: float = rng.randf_range(0.0, h * 0.18) if broken else 0.0
			pts.append(Vector2(-hw + w * t, -h + dy))
		pts.append(Vector2(hw, -h * (rng.randf_range(0.72, 0.95) if broken else 1.0)))
		pts.append(Vector2(hw, 40))
		draw_colored_polygon(_poly(base, tilt, pts), color)
		if window_color.a <= 0.0:
			return
		var sk: float = size_k
		var yy: float = -h + 22.0 * sk + (h * 0.18 if broken else 0.0)
		while yy < -16.0 * sk:
			var xx: float = -hw + 9.0 * sk
			while xx < hw - 12.0 * sk:
				if rng.randf() < 0.55:
					draw_colored_polygon(_poly(base, tilt, [Vector2(xx, yy), Vector2(xx + 6.0 * sk, yy),
						Vector2(xx + 6.0 * sk, yy + 9.0 * sk), Vector2(xx, yy + 9.0 * sk)]), window_color)
				xx += 14.0 * sk
			yy += 20.0 * sk

	func _arch(rng: RandomNumberGenerator, base: Vector2, w: float, h: float) -> void:
		var hw: float = w * 0.5
		var pw: float = w * 0.16
		var top: float = -h
		draw_colored_polygon(_poly(base, 0.0, [Vector2(-hw, 40), Vector2(-hw, top), Vector2(-hw + pw, top), Vector2(-hw + pw, 40)]), color)
		var right_h: float = top if rng.randf() < 0.6 else top * rng.randf_range(0.4, 0.8)
		draw_colored_polygon(_poly(base, 0.0, [Vector2(hw - pw, 40), Vector2(hw - pw, right_h), Vector2(hw, right_h), Vector2(hw, 40)]), color)
		if right_h != top:
			return
		var ring := PackedVector2Array()
		var ro: float = hw
		var ri: float = hw - pw
		for i in 17:
			ring.append(base + Vector2(0, top) + Vector2.from_angle(PI + PI * i / 16.0) * ro)
		for i in range(16, -1, -1):
			ring.append(base + Vector2(0, top) + Vector2.from_angle(PI + PI * i / 16.0) * ri)
		draw_colored_polygon(ring, color)

	func _columns(rng: RandomNumberGenerator, base: Vector2, w: float, h: float) -> void:
		var n: int = rng.randi_range(3, 6)
		var cw: float = w * 0.08
		for i in n:
			var cx: float = -w * 0.5 + w * (i + 0.5) / n
			var ch: float = h * (1.0 if rng.randf() < 0.55 else rng.randf_range(0.25, 0.8))
			var tilt: float = rng.randf_range(-0.05, 0.05)
			var b: Vector2 = base + Vector2(cx, 0)
			draw_colored_polygon(_poly(b, tilt, [Vector2(-cw * 0.5, 40), Vector2(-cw * 0.5, -ch), Vector2(cw * 0.5, -ch), Vector2(cw * 0.5, 40)]), color)
			if ch >= h:
				draw_colored_polygon(_poly(b, tilt, [Vector2(-cw, -ch), Vector2(-cw, -ch - cw * 0.7), Vector2(cw, -ch - cw * 0.7), Vector2(cw, -ch)]), color)
		if rng.randf() < 0.5:
			draw_colored_polygon(_poly(base, rng.randf_range(-0.06, 0.06), [Vector2(-w * 0.55, -h - 4.0), Vector2(-w * 0.55, -h - cw * 1.6),
				Vector2(w * 0.3, -h - cw * 1.6), Vector2(w * 0.3, -h - 4.0)]), color)

	func _dome(rng: RandomNumberGenerator, base: Vector2, w: float, h: float) -> void:
		var hw: float = w * 0.5
		draw_colored_polygon(_poly(base, 0.0, [Vector2(-hw, 40), Vector2(-hw, -h), Vector2(hw, -h), Vector2(hw, 40)]), color)
		var dome := PackedVector2Array()
		var r: float = hw * 0.82
		var cut: float = 1.0 if rng.randf() < 0.6 else rng.randf_range(0.55, 0.85)
		for i in 25:
			var a: float = PI + PI * cut * i / 24.0
			dome.append(base + Vector2(0, -h) + Vector2(cos(a) * r, sin(a) * r))
		dome.append(base + Vector2(r * cos(PI + PI * cut), -h))
		draw_colored_polygon(dome, color)
		if cut >= 1.0:
			draw_colored_polygon(_poly(base, 0.0, [Vector2(-3, -h - r), Vector2(0, -h - r - 40.0 * size_k), Vector2(3, -h - r)]), color)

	func _spire(base: Vector2, w: float, h: float, tilt: float) -> void:
		var hw: float = w * 0.5
		draw_colored_polygon(_poly(base, tilt, [Vector2(-hw, 40), Vector2(-hw, -h * 0.7), Vector2(-hw * 0.4, -h * 0.82),
			Vector2(0, -h), Vector2(hw * 0.4, -h * 0.82), Vector2(hw, -h * 0.7), Vector2(hw, 40)]), color)

	func _rubble(rng: RandomNumberGenerator) -> void:
		var pts := PackedVector2Array()
		var x: float = x0 - 200.0
		pts.append(Vector2(x, base_y + 600.0))
		while x < x1 + 200.0:
			pts.append(Vector2(x, base_y + rng.randf_range(-26.0, 12.0) * size_k))
			x += rng.randf_range(14.0, 50.0) * size_k
		pts.append(Vector2(x, base_y + 600.0))
		draw_colored_polygon(pts, color)


## Swaying strands of kelp. `hang` makes them hang down from an edge instead of growing up.
class Kelp extends Node2D:
	var strands: Array = []
	var color := Color.BLACK
	var hang := false
	var t := 0.0

	func setup(seed_: int, xs: Array, base_y: float, h: Vector2, w: Vector2, col: Color) -> void:
		var rng := RandomNumberGenerator.new()
		rng.seed = seed_
		color = col
		for x: float in xs:
			strands.append({"x": x + rng.randf_range(-20.0, 20.0), "y": base_y + rng.randf_range(-6.0, 6.0),
				"h": rng.randf_range(h.x, h.y), "w": rng.randf_range(w.x, w.y), "ph": rng.randf() * TAU,
				"lean": rng.randf_range(-0.25, 0.25), "sp": rng.randf_range(0.45, 0.8)})

	func _process(delta: float) -> void:
		t += delta
		queue_redraw()

	func _draw() -> void:
		var dir: float = 1.0 if hang else -1.0
		for s: Dictionary in strands:
			var h: float = s["h"]
			var w: float = s["w"]
			var left := PackedVector2Array()
			var right := PackedVector2Array()
			var n := 18
			var prev := Vector2(s["x"], s["y"])
			for i in n + 1:
				var k: float = float(i) / n
				var sway: float = sin(t * float(s["sp"]) + float(s["ph"]) - k * 2.6) * k * k * h * 0.16
				var c := Vector2(float(s["x"]) + sway + float(s["lean"]) * k * h, float(s["y"]) + dir * k * h)
				var tang: Vector2 = (c - prev).normalized() if i > 0 else Vector2(0, dir)
				var nrm := Vector2(-tang.y, tang.x)
				var ww: float = w * (1.0 - k * 0.75) * (0.8 + 0.2 * sin(k * 9.0 + float(s["ph"])))
				left.append(c + nrm * ww)
				right.append(c - nrm * ww)
				prev = c
				if i % 3 == 1 and i > 2:
					var leaf := PackedVector2Array([c, c + nrm * w * 2.6 + tang * w * 1.5, c + tang * w * 3.5])
					draw_colored_polygon(leaf, color)
			right.reverse()
			left.append_array(right)
			draw_colored_polygon(left, color)


## A school of small fish drifting along a slow loop, each with its own wobble.
class School extends Node2D:
	var area := Rect2(0, 0, 1000, 300)
	var color := Color.BLACK
	var fish: Array = []
	var fish_size := 6.0
	var t := 0.0
	var speed := 0.05

	func setup(seed_: int, count: int, a: Rect2, col: Color, size_px: float) -> void:
		var rng := RandomNumberGenerator.new()
		rng.seed = seed_
		area = a
		color = col
		fish_size = size_px
		t = rng.randf() * 100.0
		for i in count:
			fish.append({"o": Vector2(rng.randf_range(-1.0, 1.0), rng.randf_range(-1.0, 1.0)) * Vector2(90.0, 34.0),
				"ph": rng.randf() * TAU, "s": rng.randf_range(0.7, 1.2)})

	func _center(tt: float) -> Vector2:
		return area.get_center() + Vector2(sin(tt * speed) * area.size.x * 0.45, sin(tt * speed * 2.3) * area.size.y * 0.35)

	func _process(delta: float) -> void:
		t += delta
		queue_redraw()

	func _draw() -> void:
		var c: Vector2 = _center(t)
		var vel: Vector2 = _center(t + 0.1) - c
		var face: float = 1.0 if vel.x >= 0.0 else -1.0
		var ang: float = clampf(vel.y / maxf(absf(vel.x), 0.001), -0.4, 0.4) * face
		for f: Dictionary in fish:
			var ph: float = f["ph"]
			var p: Vector2 = c + (f["o"] as Vector2) + Vector2(sin(t * 0.7 + ph) * 12.0, cos(t * 0.9 + ph) * 6.0)
			var s: float = fish_size * float(f["s"])
			var wig: float = sin(t * 9.0 + ph) * 0.35
			var body := PackedVector2Array()
			for i in 8:
				var a: float = TAU * i / 8.0
				body.append(p + Vector2(cos(a) * s * face, sin(a) * s * 0.38).rotated(ang))
			draw_colored_polygon(body, color)
			var tail: Vector2 = p + Vector2(-s * face, 0).rotated(ang)
			draw_colored_polygon(PackedVector2Array([tail, tail + Vector2(-s * 0.7 * face, -s * 0.45).rotated(ang + wig),
				tail + Vector2(-s * 0.7 * face, s * 0.45).rotated(ang + wig)]), color)
