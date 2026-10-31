class_name U
extends RefCounted
## Geometry helpers shared by the rig, combat and the renderers.


## Two-bone IK: returns the middle joint (knee/elbow). `bend` picks which side it folds to.
static func ik(a: Vector2, b: Vector2, l1: float, l2: float, bend: float) -> Vector2:
	var d: Vector2 = b - a
	var dist: float = clampf(d.length(), 0.001, l1 + l2 - 0.01)
	var c: float = clampf((l1 * l1 + dist * dist - l2 * l2) / (2.0 * l1 * dist), -1.0, 1.0)
	return a + Vector2.from_angle(d.angle() - acos(c) * bend) * l1


## Closest points between two segments: [distance, point on first, point on second].
static func seg_seg(p1: Vector2, q1: Vector2, p2: Vector2, q2: Vector2) -> Array:
	var d1: Vector2 = q1 - p1
	var d2: Vector2 = q2 - p2
	var r: Vector2 = p1 - p2
	var a: float = d1.dot(d1)
	var e: float = d2.dot(d2)
	var f: float = d2.dot(r)
	var s := 0.0
	var t := 0.0
	if a <= 1e-6 and e <= 1e-6:
		return [r.length(), p1, p2]
	if a <= 1e-6:
		t = clampf(f / e, 0.0, 1.0)
	else:
		var c: float = d1.dot(r)
		if e <= 1e-6:
			s = clampf(-c / a, 0.0, 1.0)
		else:
			var b: float = d1.dot(d2)
			var denom: float = a * e - b * b
			if denom > 1e-6:
				s = clampf((b * f - c * e) / denom, 0.0, 1.0)
			t = (b * s + f) / e
			if t < 0.0:
				t = 0.0
				s = clampf(-c / a, 0.0, 1.0)
			elif t > 1.0:
				t = 1.0
				s = clampf((b - c) / a, 0.0, 1.0)
	var c1: Vector2 = p1 + d1 * s
	var c2: Vector2 = p2 + d2 * t
	return [c1.distance_to(c2), c1, c2]


static func capsule(a: Vector2, b: Vector2, ra: float, rb: float, n: int = 5) -> PackedVector2Array:
	var d: Vector2 = b - a
	var ang: float = d.angle() if d.length_squared() > 0.0001 else 0.0
	var pts := PackedVector2Array()
	for i in n + 1:
		pts.append(a + Vector2.from_angle(ang + PI * 0.5 + PI * float(i) / n) * ra)
	for i in n + 1:
		pts.append(b + Vector2.from_angle(ang - PI * 0.5 + PI * float(i) / n) * rb)
	return pts


static func circle(c: Vector2, r: float, n: int = 14) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in n:
		pts.append(c + Vector2.from_angle(TAU * float(i) / n) * r)
	return pts


## Draws convex polygons as a single triangle batch.
## `proj` remaps every point (used for cast shadows); `shade` gives a per-vertex color.
static func draw_polys(ci: CanvasItem, polys: Array, color: Color, offset: Vector2 = Vector2.ZERO,
		proj: Callable = Callable(), shade: Callable = Callable()) -> void:
	var pts := PackedVector2Array()
	var cols := PackedColorArray()
	var idx := PackedInt32Array()
	for poly: PackedVector2Array in polys:
		var n: int = poly.size()
		if n < 3:
			continue
		var base: int = pts.size()
		for q: Vector2 in poly:
			var w: Vector2 = q + offset
			if shade.is_valid():
				cols.append(shade.call(w))
			else:
				cols.append(color)
			if proj.is_valid():
				pts.append(proj.call(w))
			else:
				pts.append(w)
		for i in range(1, n - 1):
			idx.append(base)
			idx.append(base + i)
			idx.append(base + i + 1)
	if idx.is_empty():
		return
	RenderingServer.canvas_item_add_triangle_array(ci.get_canvas_item(), idx, pts, cols)


static func radial_texture(size: int = 128) -> GradientTexture2D:
	var g := Gradient.new()
	g.set_color(0, Color(1, 1, 1, 1))
	g.set_color(1, Color(1, 1, 1, 0))
	var tex := GradientTexture2D.new()
	tex.gradient = g
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.5)
	tex.fill_to = Vector2(1.0, 0.5)
	tex.width = size
	tex.height = size
	return tex
