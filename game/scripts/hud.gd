class_name Hud
extends Control
## Letterbox, health/stamina/posture, round text and menus.

const BAR := 70.0
const INK := Color(0.93, 0.91, 0.87)

var main: Node
var f_title: FontVariation
var f_wide: FontVariation
var f_ui: FontVariation


func _ready() -> void:
	size = Vector2(1920, 1080)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var base: Font = ThemeDB.fallback_font
	if ResourceLoader.exists("res://fonts/CormorantGaramond.ttf"):
		base = load("res://fonts/CormorantGaramond.ttf")
	f_title = _font(base, 300, 16)
	f_wide = _font(base, 500, 6)
	f_ui = _font(base, 500, 2)


func _font(base: Font, weight: int, spacing: int) -> FontVariation:
	var f := FontVariation.new()
	f.base_font = base
	f.variation_opentype = {"wght": weight}
	f.spacing_glyph = spacing
	return f


func _t(text: String, pos: Vector2, fsize: int, color: Color, font: Font, align: int = HORIZONTAL_ALIGNMENT_CENTER) -> void:
	var w := 1800.0
	var x: float = pos.x
	if align == HORIZONTAL_ALIGNMENT_CENTER:
		x -= w * 0.5
	elif align == HORIZONTAL_ALIGNMENT_RIGHT:
		x -= w
	draw_string(font, Vector2(x, pos.y + fsize * 0.32), text, align, w, fsize, color)


func _draw() -> void:
	var m = main
	if m.mode == "title":
		_title()
	else:
		_posture_bars()
		_top_bar()
		_banner()
		if m.mode == "end":
			_end()
	draw_rect(Rect2(0, 0, 1920, BAR), Color.BLACK)
	draw_rect(Rect2(0, 1080 - BAR, 1920, BAR), Color.BLACK)
	if m.mode == "title":
		_t("A / D  move     W / S  guard high · low     J  light     K  heavy (hold to charge)     L  guard · parry     I  thrust     U  kick     SPACE  dash",
			Vector2(960, 1080 - BAR * 0.5), 17, Color(INK, 0.45), f_ui)
	else:
		_hud_texts()
	if m.paused:
		_pause()
	if m.show_controls:
		_controls()


func _title() -> void:
	var m = main
	_t("ECHOES OF A SUNKEN WORLD", Vector2(960, 850), 66, Color(INK, 0.95), f_title)
	var items: Array = m.menu_items()
	var n: int = items.size()
	for i in n:
		var x: float = 960.0 + (i - (n - 1) * 0.5) * 300.0
		var sel: bool = i == m.menu_idx
		var c := Color(INK, 1.0 if sel else 0.42)
		_t(items[i], Vector2(x, 945), 25, c, f_ui)
		if sel:
			var w: float = f_ui.get_string_size(items[i], HORIZONTAL_ALIGNMENT_LEFT, -1, 25).x * 0.5 + 22.0
			_diamond(Vector2(x - w, 946), 4.0, c)
			_diamond(Vector2(x + w, 946), 4.0, c)


func _diamond(c: Vector2, r: float, col: Color) -> void:
	draw_colored_polygon(PackedVector2Array([c + Vector2(0, -r), c + Vector2(r, 0), c + Vector2(0, r), c + Vector2(-r, 0)]), col)


func _top_bar() -> void:
	pass


func _hud_texts() -> void:
	var m = main
	var names: Array = m.names()
	for i in 2:
		var f: Fighter = m.fighters[i]
		var right: bool = i == 1
		var x0: float = 1810.0 if right else 110.0
		var dir: float = -1.0 if right else 1.0
		var w := 620.0
		var align: int = HORIZONTAL_ALIGNMENT_RIGHT if right else HORIZONTAL_ALIGNMENT_LEFT
		_t(names[i], Vector2(x0, 21), 17, Color(INK, 0.9), f_wide, align)
		for k in f.wins:
			draw_circle(Vector2(x0 + dir * (w - k * 16.0), 21), 3.5, Color(0.82, 0.64, 0.45))
		var y := 42.0
		draw_line(Vector2(x0, y), Vector2(x0 + dir * w, y), Color(1, 1, 1, 0.1), 3.0)
		draw_line(Vector2(x0, y), Vector2(x0 + dir * w * f.hp_trail / 100.0, y), Color(0.72, 0.28, 0.24, 0.85), 3.0)
		draw_line(Vector2(x0, y), Vector2(x0 + dir * w * f.hp / 100.0, y), INK, 3.0)
		var sc := Color(0.6, 0.64, 0.66, 0.75)
		if f.exhausted:
			sc = Color(0.8, 0.35, 0.3, 0.5 + 0.4 * sin(Time.get_ticks_msec() * 0.012))
		draw_line(Vector2(x0, 52), Vector2(x0 + dir * w * 0.42 * f.stamina / 100.0, 52), sc, 1.5)
	_t(str(ceili(maxf(m.round_time, 0.0))), Vector2(960, 30), 34, Color(INK, 0.85), f_ui)
	_t(m.ROMAN[clampi(m.round_no, 0, 5)], Vector2(960, 58), 14, Color(INK, 0.45), f_wide)
	_t(m.stage.title, Vector2(960, 1080 - BAR * 0.5), 14, Color(INK, 0.35), f_wide)


## Posture floats above each fighter and only shows once it has started to fill.
func _posture_bars() -> void:
	var m = main
	for f: Fighter in m.fighters:
		if f.posture < 4.0 or f.state == "dead" or f.state == "dying":
			continue
		var p: Vector2 = m.world_to_screen(f.rig.head + Vector2(0, -40))
		var k: float = f.posture / 100.0
		var w := 96.0
		var col: Color = Color(0.95, 0.9, 0.82).lerp(Color(1.0, 0.45, 0.2), k)
		if f.state == "broken":
			col = Color(1.0, 0.4, 0.2, 0.6 + 0.4 * sin(Time.get_ticks_msec() * 0.02))
		draw_line(p - Vector2(w * 0.5, 0), p + Vector2(w * 0.5, 0), Color(0, 0, 0, 0.35), 4.0)
		draw_line(p - Vector2(w * 0.5 * k, 0), p + Vector2(w * 0.5 * k, 0), col, 2.5)


func _banner() -> void:
	var m = main
	var b: Dictionary = m.banner
	if b.is_empty():
		return
	var life: float = b["life"]
	var a: float = minf(1.0, life / 15.0) * minf(1.0, (float(b["max"]) - life) / 8.0 + 0.2)
	_t(b["text"], Vector2(960, b.get("y", 905.0)), b.get("size", 40), Color(INK, a), f_title)
	if b.has("sub"):
		_t(b["sub"], Vector2(960, float(b.get("y", 905.0)) + 50.0), 20, Color(INK, a * 0.6), f_wide)


func _end() -> void:
	var m = main
	var items: Array = m.menu_items()
	for i in items.size():
		var x: float = 960.0 + (i - (items.size() - 1) * 0.5) * 300.0
		var sel: bool = i == m.menu_idx
		_t(items[i], Vector2(x, 975), 24, Color(INK, 1.0 if sel else 0.42), f_ui)


func _pause() -> void:
	var m = main
	draw_rect(Rect2(0, 0, 1920, 1080), Color(0, 0, 0, 0.62))
	_t("STILLNESS", Vector2(960, 430), 54, Color(INK, 1.0), f_title)
	var items: Array = m.menu_items()
	for i in items.size():
		var sel: bool = i == m.menu_idx
		_t(items[i], Vector2(960, 520 + i * 52), 26, Color(INK, 1.0 if sel else 0.42), f_ui)


func _controls() -> void:
	draw_rect(Rect2(0, 0, 1920, 1080), Color(0, 0, 0, 0.82))
	_t("THE WAY OF THE BLADE", Vector2(960, 150), 44, INK, f_title)
	var rows := [
		["", "PLAYER ONE", "PLAYER TWO", "GAMEPAD"],
		["move", "A  /  D", "←  /  →", "left stick · d-pad"],
		["guard high · low", "hold W  /  S", "hold ↑  /  ↓", "stick up · down"],
		["light cut", "J   or   F", "numpad 1", "X  /  □"],
		["heavy cut — hold to charge", "K   or   G", "numpad 2", "Y  /  △"],
		["guard  ·  tap to parry", "L   or   H", "numpad 3", "RB  /  R1"],
		["thrust", "I   or   T", "numpad 5", "B  /  ○"],
		["kick — breaks a guard", "U   or   R", "numpad 4", "LB  /  L1"],
		["dash  (with or without a direction)", "SPACE", "numpad 0", "A  /  ✕"],
	]
	for r in rows.size():
		var row: Array = rows[r]
		var y: float = 250.0 + r * 46.0
		var c := Color(INK, 0.5 if r == 0 else 0.9)
		_t(row[0], Vector2(560, y), 22, c, f_ui, HORIZONTAL_ALIGNMENT_RIGHT)
		_t(row[1], Vector2(800, y), 22, c, f_ui)
		_t(row[2], Vector2(1100, y), 22, c, f_ui)
		_t(row[3], Vector2(1420, y), 22, c, f_ui)
	var notes := [
		"Your guard blocks only the line you hold. Read where the blade is raised and match it.",
		"Raise your guard just before the blow lands to parry: the attacker is thrown open.",
		"Blocking costs posture. When it breaks you are defenceless and blows land harder.",
		"Attacks and dashes cost stamina. Exhausted, you move and strike slower.",
		"Heads bleed more than arms. A cut leg leaves you limping. Press guard during a heavy wind-up to feint.",
	]
	for i in notes.size():
		_t(notes[i], Vector2(960, 720 + i * 38), 21, Color(INK, 0.62), f_ui)
	_t("press any key to return", Vector2(960, 950), 18, Color(INK, 0.4), f_wide)
