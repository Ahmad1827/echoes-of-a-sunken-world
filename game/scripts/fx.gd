class_name FX
extends Node2D
## Particles and light effects in world space: sparks, ink spray and stains, dust, motes and sand,
## plus everything additive about the blades (glow, motion trails, glints, cut flashes).

enum { SPARK, INK, STAIN, DUST, MOTE, SAND, SNOW, BUBBLE }

var parts: Array = []
var cuts: Array = []
var fighters: Array = []
var stage: Stage
var add_layer: Node2D

# Hundreds of specks live at once, so they share one triangle array rather than one draw call each.
static var RING_TINY: PackedVector2Array = _ring(6)
static var RING_SMALL: PackedVector2Array = _ring(14)
static var RING_BIG: PackedVector2Array = _ring(32)
var batch_pts := PackedVector2Array()
var batch_cols := PackedColorArray()
var batch_idx := PackedInt32Array()


static func _ring(n: int) -> PackedVector2Array:
	var out := PackedVector2Array()
	for i in n:
		out.append(Vector2.from_angle(TAU * i / n))
	return out


## Adds a filled disc to the batch, using no more points than its size can show.
func _disc(p: Vector2, r: float, c: Color, squash: float = 1.0) -> void:
	var ring: PackedVector2Array = RING_TINY if r < 2.0 else (RING_SMALL if r < 8.0 else RING_BIG)
	var base: int = batch_pts.size()
	var n: int = ring.size()
	for i in n:
		var q: Vector2 = ring[i]
		batch_pts.append(p + Vector2(q.x * r, q.y * r * squash))
		batch_cols.append(c)
		if i >= 2:
			batch_idx.append(base)
			batch_idx.append(base + i - 1)
			batch_idx.append(base + i)


## A thin horizontal streak, added to the batch.
func _streak(p: Vector2, length: float, c: Color) -> void:
	var base: int = batch_pts.size()
	batch_pts.append(p + Vector2(0.0, -0.5))
	batch_pts.append(p + Vector2(length, -0.5))
	batch_pts.append(p + Vector2(length, 0.5))
	batch_pts.append(p + Vector2(0.0, 0.5))
	for i in 4:
		batch_cols.append(c)
	batch_idx.append_array(PackedInt32Array([base, base + 1, base + 2, base, base + 2, base + 3]))


func _flush_batch(ci: CanvasItem) -> void:
	if not batch_idx.is_empty():
		RenderingServer.canvas_item_add_triangle_array(ci.get_canvas_item(), batch_idx, batch_pts, batch_cols)
	batch_pts.clear()
	batch_cols.clear()
	batch_idx.clear()


func _ready() -> void:
	add_layer = Node2D.new()
	var m := CanvasItemMaterial.new()
	m.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	add_layer.material = m
	add_child(add_layer)
	add_layer.draw.connect(_draw_add)


func clear() -> void:
	parts.clear()
	cuts.clear()


func redraw() -> void:
	queue_redraw()
	add_layer.queue_redraw()


func spark(pos: Vector2, n: int, col: Color, speed: float = 8.0) -> void:
	for i in n:
		var v: Vector2 = Vector2.from_angle(randf() * TAU) * randf_range(1.0, speed) + Vector2(0, -1.5)
		parts.append({"k": SPARK, "p": pos, "v": v, "life": randf_range(12.0, 36.0), "max": 36.0, "c": col})


func ink(pos: Vector2, n: int, dir: float) -> void:
	for i in n:
		var v := Vector2(dir * randf_range(1.0, 9.0) + randf_range(-1.0, 1.0), randf_range(-6.5, 1.5))
		parts.append({"k": INK, "p": pos, "v": v, "life": 90.0, "max": 90.0, "r": randf_range(1.2, 4.2)})


func dust(pos: Vector2, n: int, col: Color, spread: float = 1.0) -> void:
	for i in n:
		var v := Vector2(randf_range(-1.6, 1.6) * spread, randf_range(-0.9, -0.1))
		parts.append({"k": DUST, "p": pos + Vector2(randf_range(-10.0, 10.0), -2.0), "v": v,
			"life": randf_range(30.0, 60.0), "max": 60.0, "r": randf_range(6.0, 14.0), "c": col})


func mote(pos: Vector2) -> void:
	parts.append({"k": MOTE, "p": pos, "v": Vector2(randf_range(-0.2, 0.2), randf_range(-0.45, -0.1)),
		"life": randf_range(140.0, 300.0), "max": 300.0, "r": randf_range(0.7, 2.0), "ph": randf() * TAU})


## Marine snow: drifting silt. A few near-camera flecks are larger and fainter.
func snow(pos: Vector2) -> void:
	var near: bool = randf() < 0.08
	parts.append({"k": SNOW, "p": pos, "v": Vector2(randf_range(-0.15, 0.15), randf_range(0.04, 0.22)),
		"life": randf_range(260.0, 520.0), "max": 520.0, "r": randf_range(2.5, 4.5) if near else randf_range(0.6, 1.6),
		"a": 0.12 if near else randf_range(0.25, 0.55), "ph": randf() * TAU})


func bubbles(pos: Vector2, n: int, spread: float = 1.0) -> void:
	for i in n:
		parts.append({"k": BUBBLE, "p": pos + Vector2(randf_range(-6.0, 6.0), randf_range(-6.0, 6.0)) * spread,
			"v": Vector2(randf_range(-0.6, 0.6) * spread, randf_range(-1.6, -0.4)), "life": randf_range(120.0, 260.0),
			"max": 260.0, "r": randf_range(1.2, 3.6), "ph": randf() * TAU})


func sand(pos: Vector2) -> void:
	parts.append({"k": SAND, "p": pos, "v": Vector2(randf_range(-16.0, -7.0), randf_range(-0.3, 0.3)),
		"life": 200.0, "max": 200.0, "len": randf_range(12.0, 46.0)})


func cut(pos: Vector2, dir: Vector2, length: float = 190.0) -> void:
	cuts.append({"p": pos, "d": dir.normalized(), "len": length, "life": 12.0})


func update(ts: float) -> void:
	if ts <= 0.0:
		return
	var g: float = stage.ground
	for i in range(parts.size() - 1, -1, -1):
		var q: Dictionary = parts[i]
		q["life"] = float(q["life"]) - ts
		if float(q["life"]) <= 0.0:
			parts.remove_at(i)
			continue
		var p: Vector2 = q["p"]
		var v: Vector2 = q["v"]
		match q["k"]:
			SPARK:
				v.y += (0.06 if stage.water else 0.28) * ts
				v *= pow(0.88 if stage.water else 0.95, ts)
				if p.y > g and v.y > 0.0:
					v.y *= -0.35
					v.x *= 0.6
			INK:
				if stage.water:
					# blood in water: the spray slows, swells and drifts away as a cloud
					v *= pow(0.9, ts)
					v.y += 0.012 * ts
					q["r"] = float(q["r"]) + 0.09 * ts
				else:
					v.y += 0.36 * ts
				if not stage.water and p.y + v.y * ts >= g + 2.0:
					q["k"] = STAIN
					q["life"] = 600.0
					q["max"] = 600.0
					q["r"] = float(q["r"]) * randf_range(1.2, 2.0)
					p.y = g + randf_range(-1.0, 5.0)
					v = Vector2.ZERO
			DUST:
				v *= pow(0.95, ts)
				q["r"] = float(q["r"]) + 0.25 * ts
			MOTE:
				v.x += sin(float(q["ph"]) + float(q["life"]) * 0.02) * 0.004 * ts
			SNOW:
				v.x = sin(float(q["ph"]) + float(q["life"]) * 0.013) * 0.18
			BUBBLE:
				v.y = maxf(v.y - 0.03 * ts, -2.4)
				v.x = v.x * pow(0.96, ts) + sin(float(q["ph"]) + float(q["life"]) * 0.15) * 0.05
				q["r"] = minf(float(q["r"]) + 0.004 * ts, 5.0)
		p += v * ts
		q["p"] = p
		q["v"] = v
	for i in range(cuts.size() - 1, -1, -1):
		cuts[i]["life"] = float(cuts[i]["life"]) - ts
		if float(cuts[i]["life"]) <= 0.0:
			cuts.remove_at(i)


func _draw() -> void:
	for q: Dictionary in parts:
		var a: float = float(q["life"]) / float(q["max"])
		var p: Vector2 = q["p"]
		match q["k"]:
			INK:
				if stage.water:
					_disc(p, q["r"], Color(0.03, 0.02, 0.03, minf(1.0, a * 1.4) * 0.55))
				else:
					_disc(p, q["r"], Color(0.02, 0.02, 0.03, 1.0))
			SNOW:
				_disc(p, q["r"], Color(0.8, 0.93, 0.9, float(q["a"]) * sin(a * PI)))
			STAIN:
				_disc(p, q["r"], Color(0.02, 0.02, 0.03, minf(1.0, a * 3.0) * 0.85), 0.28)
			DUST:
				var c: Color = q["c"]
				c.a *= sin(a * PI) * 0.6
				_disc(p, q["r"], c)
			SAND:
				_streak(p, q["len"], Color(0.97, 0.86, 0.74, 0.2 * a))
	_flush_batch(self)


func _draw_add() -> void:
	var L: Node2D = add_layer
	for f: Fighter in fighters:
		_trail(f)
	for f: Fighter in fighters:
		var r: Rig = f.rig
		if stage.glow:
			var a: Vector2 = r.blade_base
			var b: Vector2 = r.blade_tip
			L.draw_line(a, b, Color(0.3, 0.45, 0.9, 0.09), 26.0, true)
			L.draw_line(a, b, Color(0.55, 0.7, 1.0, 0.18), 12.0, true)
			L.draw_line(a, b, Color(0.9, 0.95, 1.0, 0.7), 4.5, true)
			L.draw_line(a, b, Color(2.6, 2.6, 2.8, 1.0), 1.8, true)
		else:
			var perp := Vector2(-r.sword_dir.y, r.sword_dir.x)
			var g: float = pow(absf(perp.dot(stage.light_dir)), 12.0)
			if g > 0.02:
				var a2: Vector2 = r.blade_base.lerp(r.blade_tip, 0.15)
				var b2: Vector2 = r.blade_base.lerp(r.blade_tip, 0.85)
				L.draw_line(a2, b2, Color(1.6, 1.5, 1.35, g), 1.4, true)
				L.draw_circle(r.blade_base.lerp(r.blade_tip, 0.55), 6.0 * g, Color(1.4, 1.3, 1.2, g * 0.35))
	for q: Dictionary in parts:
		var a: float = float(q["life"]) / float(q["max"])
		var p: Vector2 = q["p"]
		match q["k"]:
			SPARK:
				var v: Vector2 = q["v"]
				var c: Color = q["c"]
				L.draw_line(p, p - v * 2.4, Color(c.r, c.g, c.b, a), 1.8, true)
			MOTE:
				_disc(p, q["r"], Color(0.8, 0.86, 0.86, sin(a * PI) * 0.35))
			BUBBLE:
				var r: float = q["r"]
				var ba: float = minf(1.0, a * 3.0) * 0.55
				L.draw_arc(p, r, 0.0, TAU, 12, Color(0.75, 0.95, 0.95, ba), 1.0, true)
				_disc(p + Vector2(-r * 0.35, -r * 0.35), r * 0.3, Color(1.2, 1.3, 1.3, ba))
	_flush_batch(L)
	for c: Dictionary in cuts:
		var a: float = float(c["life"]) / 12.0
		var p: Vector2 = c["p"]
		var d: Vector2 = c["d"]
		var l: float = float(c["len"]) * (1.2 - a * 0.4)
		L.draw_line(p - d * l * 0.5, p + d * l * 0.5, Color(1.4, 1.4, 1.4, a * 0.7), 2.0 * a + 0.4, true)


func _trail(f: Fighter) -> void:
	var tr: Array = f.trail
	if tr.size() < 2:
		return
	var pts := PackedVector2Array()
	var cols := PackedColorArray()
	var idx := PackedInt32Array()
	var base: Color = Color(0.7, 0.82, 1.2) if stage.glow else Color(1.0, 0.97, 0.9)
	var strength: float = 0.5 if stage.glow else 0.26
	for i in tr.size():
		var a: float = float(i + 1) / tr.size()
		var seg: Array = tr[i]
		pts.append(seg[0])
		pts.append(seg[1])
		var c := Color(base.r, base.g, base.b, 0.0)
		cols.append(c)
		c.a = a * a * strength
		cols.append(c)
		if i > 0:
			var k: int = i * 2
			idx.append_array(PackedInt32Array([k - 2, k - 1, k + 1, k - 2, k + 1, k]))
	RenderingServer.canvas_item_add_triangle_array(add_layer.get_canvas_item(), idx, pts, cols)
