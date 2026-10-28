class_name Stage
extends RefCounted
## Base for an arena: its layers, its light (which drives cast shadows, rim light and glints) and its weather.

var title := ""
var ground := 770.0
var center_x := 1200.0
var left := 0.0
var right := 2400.0
var arena := Vector2(330.0, 2070.0)
var glow := false
## Underwater: cloth floats, bodies sink slowly, ink clouds instead of dripping.
var water := false
## "point": a light hanging in the scene at (x, height above ground), `depth` behind the fighters.
## "sun": parallel light; shadows skew by `sun` per unit of height.
var light_type := "point"
var light_pos := Vector2(1200.0, 560.0)
var light_depth := 1500.0
var squash := 0.034
var sun := Vector2(0.5, -0.15)
var light_dir := Vector2(0.0, -1.0)
var shadow_alpha := 0.6
var shadow_blur := 2.5
var rim_color := Color(1, 1, 1, 0.5)
var spark_color := Color(2.4, 2.4, 2.6)
var dust_color := Color(0.8, 0.8, 0.8, 0.3)
var wind := 1.0
var step_sound := "step_stone"
var ambience := ""


## Returns [[Node2D, parallax factor], ...] from farthest to nearest. Factors above 1 are
## foreground layers drawn in front of the fighters.
func build() -> Array:
	return []


func ambient(_ts: float, _fx: FX, _view: Rect2) -> void:
	pass


func shadow_proj(q: Vector2) -> Vector2:
	var h: float = maxf(0.0, ground - q.y)
	if light_type == "point":
		var hh: float = minf(h, light_pos.y * 0.8)
		var k: float = hh / (light_pos.y - hh)
		return Vector2(q.x + (q.x - light_pos.x) * k, ground + light_depth * k * squash)
	return Vector2(q.x + h * sun.x, ground + h * sun.y)


func shadow_shade(q: Vector2) -> Color:
	var h: float = maxf(0.0, ground - q.y)
	return Color(1.0 - clampf(h / 270.0, 0.0, 1.0) * 0.7, 0, 0, 1)


func rim_dir(pos: Vector2) -> Vector2:
	if light_type == "point":
		return (Vector2(light_pos.x, ground - light_pos.y) - pos).normalized()
	return light_dir
