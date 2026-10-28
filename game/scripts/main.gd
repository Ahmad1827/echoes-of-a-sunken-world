extends Node2D
## Game flow, input, camera, screen effects and the automated test mode.

const ANCHOR := Vector2(960.0, 700.0)
const ROMAN := ["", "I", "II", "III", "IV", "V"]
const DIFFICULTY := ["NOVICE", "ADEPT", "MASTER"]
const SKILL := [0.3, 0.6, 0.88]

const KB := [
	{"left": [KEY_A], "right": [KEY_D], "up": [KEY_W], "down": [KEY_S], "light": [KEY_J, KEY_F], "heavy": [KEY_K, KEY_G],
	 "block": [KEY_L, KEY_H], "thrust": [KEY_I, KEY_T], "kick": [KEY_U, KEY_R], "dash": [KEY_SPACE]},
	{"left": [KEY_LEFT], "right": [KEY_RIGHT], "up": [KEY_UP], "down": [KEY_DOWN], "light": [KEY_KP_1], "heavy": [KEY_KP_2],
	 "block": [KEY_KP_3], "thrust": [KEY_KP_5], "kick": [KEY_KP_4], "dash": [KEY_KP_0]},
]
const ACTIONS := ["left", "right", "up", "down", "light", "heavy", "block", "thrust", "kick", "dash", "start"]

var stages: Array = []
var stage: Stage
var stage_idx := 0
var scene_root: Node2D
var layer_nodes: Array = []
var fighter_view: Views.FighterView
var shadow_group: CanvasGroup
var shadow_view: Views.ShadowView
var contact_view: Views.ContactView
var fx: FX
var hud: Hud
var post: ShaderMaterial
var sfx: Sfx

var fighters: Array = []
var brains: Array = []
var mode := "title"
var vs_ai := true
var difficulty := 1
var round_no := 0
var round_time := 99.0
var timer := 0.0
var paused := false
var show_controls := false
var menu_idx := 0
var banner := {}

var ts_slow := 1.0
var slow_timer := 0.0
var hitstop := 0.0
var shake := 0.0
var flash := 0.0
var ca := 0.0
var desat := 0.0
var desat_target := 0.0
var cam_x := 1200.0
var cam_zoom := 1.0
var zoom_punch := 0.0
var ko_focus := -1.0
var cur_zoom := 1.0
var view_rect := Rect2()

var raw := [{}, {}]
var prev_raw := [{}, {}]
var menu_prev := {}

var autotest := false
var auto_frames := 900
var shot_dir := ""
var shot_every := 0
var frame := 0
var stats := {}
var title_test := false


func _ready() -> void:
	randomize()
	var args := OS.get_cmdline_user_args()
	for a: String in args:
		if a == "--autotest":
			autotest = true
		elif a.begins_with("--stage="):
			stage_idx = int(a.get_slice("=", 1))
		elif a.begins_with("--frames="):
			auto_frames = int(a.get_slice("=", 1))
		elif a.begins_with("--shots="):
			shot_dir = a.get_slice("=", 1)
		elif a.begins_with("--every="):
			shot_every = int(a.get_slice("=", 1))
		elif a == "--title":
			title_test = true
	sfx = Sfx.new()
	add_child(sfx)
	stages = [StageHollow.new(), StageDune.new()]
	for i in 2:
		var f := Fighter.new()
		f.id = i
		fighters.append(f)
		var b := AIBrain.new()
		b.me = f
		brains.append(b)
	brains[0].op = fighters[1]
	brains[1].op = fighters[0]
	_setup_env()
	_build_stage(stage_idx)

	var post_layer := CanvasLayer.new()
	post_layer.layer = 5
	add_child(post_layer)
	var rect := ColorRect.new()
	rect.size = Vector2(1920, 1080)
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	post = ShaderMaterial.new()
	post.shader = load("res://shaders/post.gdshader")
	post.set_shader_parameter("water", 1.0 if stage.water else 0.0)
	rect.material = post
	post_layer.add_child(rect)

	var hud_layer := CanvasLayer.new()
	hud_layer.layer = 10
	add_child(hud_layer)
	hud = Hud.new()
	hud.main = self
	hud_layer.add_child(hud)

	if autotest and not title_test:
		vs_ai = true
		_start_match()
	else:
		_to_title()


func _setup_env() -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_CANVAS
	env.glow_enabled = true
	env.glow_intensity = 0.85
	env.glow_strength = 1.0
	env.glow_bloom = 0.0
	env.glow_hdr_threshold = 1.0
	env.glow_blend_mode = Environment.GLOW_BLEND_MODE_SOFTLIGHT
	for i in 7:
		env.set_glow_level(i, 1.0 if i >= 1 and i <= 4 else 0.0)
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)


func _build_stage(i: int) -> void:
	if scene_root:
		remove_child(scene_root)
		scene_root.queue_free()
	stage_idx = i
	stage = stages[i]
	scene_root = Node2D.new()
	add_child(scene_root)
	move_child(scene_root, 0)
	layer_nodes.clear()
	var front: Array = []
	for entry: Array in stage.build():
		if float(entry[1]) > 1.0:
			front.append(entry)
			continue
		scene_root.add_child(entry[0])
		layer_nodes.append(entry)
	var world := Node2D.new()
	scene_root.add_child(world)
	layer_nodes.append([world, 1.0])
	contact_view = Views.ContactView.new()
	shadow_group = CanvasGroup.new()
	shadow_group.fit_margin = 30.0
	shadow_group.clear_margin = 30.0
	var sm := ShaderMaterial.new()
	sm.shader = load("res://shaders/shadow.gdshader")
	sm.set_shader_parameter("strength", stage.shadow_alpha)
	sm.set_shader_parameter("blur", stage.shadow_blur)
	shadow_group.material = sm
	shadow_view = Views.ShadowView.new()
	shadow_group.add_child(shadow_view)
	fighter_view = Views.FighterView.new()
	fx = FX.new()
	for n: Node2D in [shadow_group, contact_view, fighter_view, fx]:
		world.add_child(n)
	for v in [fighter_view, shadow_view, contact_view, fx]:
		v.fighters = fighters
		v.stage = stage
	for entry: Array in front:
		scene_root.add_child(entry[0])
		layer_nodes.append(entry)
	if post:
		post.set_shader_parameter("water", 1.0 if stage.water else 0.0)
	sfx.ambience(stage.ambience)


func _place() -> void:
	var c: float = stage.center_x
	fighters[0].setup(0, c - 270.0, stage.ground, 1.0)
	fighters[1].setup(1, c + 270.0, stage.ground, -1.0)
	for f: Fighter in fighters:
		f.rig.wind = stage.wind
		f.rig.water = stage.water
		f.lethal = mode != "title"
	for i in 2:
		brains[i].skill = 0.55 if mode == "title" else SKILL[difficulty]
	if autotest:
		brains[0].skill = 0.7
		brains[1].skill = 0.7
	cam_x = c
	fx.clear()
	ts_slow = 1.0
	slow_timer = 0.0
	hitstop = 0.0
	desat_target = 0.0
	ko_focus = -1.0


func names() -> Array:
	return ["THE WANDERER", "THE SHADOW" if vs_ai else "THE RONIN"]


func menu_items() -> Array:
	if mode == "title":
		return ["Duel the Shadow", "Duel a Friend", "Stage: " + stage.title.capitalize(),
			"Difficulty: " + DIFFICULTY[difficulty].capitalize(), "The Way of the Blade", "Leave"]
	if paused:
		return ["Resume", "The Way of the Blade", "Abandon the duel"]
	return ["Duel again", "Return"]


func _to_title() -> void:
	mode = "title"
	paused = false
	menu_idx = 0
	banner = {}
	_place()


func _start_match() -> void:
	for f: Fighter in fighters:
		f.wins = 0
	round_no = 0
	_next_round()


func _next_round() -> void:
	round_no += 1
	mode = "intro"
	_place()
	timer = 170.0
	round_time = 99.0
	cam_zoom = 0.86
	banner = {"text": "ROUND " + ROMAN[clampi(round_no, 0, 5)], "life": 150.0, "max": 150.0, "size": 46}
	sfx.play("gong", -4.0)


func world_to_screen(p: Vector2) -> Vector2:
	return ANCHOR + (p - Vector2(cam_x, stage.ground)) * cur_zoom


# ---------------------------------------------------------------- input

func _poll() -> void:
	var pads: Array = Input.get_connected_joypads()
	for i in 2:
		prev_raw[i] = raw[i]
		var r := {}
		for a: String in ACTIONS:
			r[a] = false
		var maps: Array = [KB[i]]
		if vs_ai and i == 0:
			maps.append(KB[1])
		for map: Dictionary in maps:
			for a: String in map:
				for key: int in map[a]:
					if Input.is_physical_key_pressed(key):
						r[a] = true
		var pad_ids: Array = []
		if vs_ai:
			if i == 0:
				pad_ids = pads
		elif i < pads.size():
			pad_ids = [pads[i]]
		for jid: int in pad_ids:
			var ax: float = Input.get_joy_axis(jid, JOY_AXIS_LEFT_X)
			var ay: float = Input.get_joy_axis(jid, JOY_AXIS_LEFT_Y)
			r["left"] = r["left"] or ax < -0.4 or Input.is_joy_button_pressed(jid, JOY_BUTTON_DPAD_LEFT)
			r["right"] = r["right"] or ax > 0.4 or Input.is_joy_button_pressed(jid, JOY_BUTTON_DPAD_RIGHT)
			r["up"] = r["up"] or ay < -0.55 or Input.is_joy_button_pressed(jid, JOY_BUTTON_DPAD_UP)
			r["down"] = r["down"] or ay > 0.55 or Input.is_joy_button_pressed(jid, JOY_BUTTON_DPAD_DOWN)
			r["light"] = r["light"] or Input.is_joy_button_pressed(jid, JOY_BUTTON_X)
			r["heavy"] = r["heavy"] or Input.is_joy_button_pressed(jid, JOY_BUTTON_Y)
			r["block"] = r["block"] or Input.is_joy_button_pressed(jid, JOY_BUTTON_RIGHT_SHOULDER) or Input.get_joy_axis(jid, JOY_AXIS_TRIGGER_RIGHT) > 0.4
			r["thrust"] = r["thrust"] or Input.is_joy_button_pressed(jid, JOY_BUTTON_B)
			r["kick"] = r["kick"] or Input.is_joy_button_pressed(jid, JOY_BUTTON_LEFT_SHOULDER)
			r["dash"] = r["dash"] or Input.is_joy_button_pressed(jid, JOY_BUTTON_A)
			r["start"] = r["start"] or Input.is_joy_button_pressed(jid, JOY_BUTTON_START)
		raw[i] = r


func _pressed(i: int, a: String) -> bool:
	return raw[i].get(a, false) and not prev_raw[i].get(a, false)


func _menu_poll() -> Dictionary:
	var m := {"up": false, "down": false, "left": false, "right": false, "ok": false, "back": false, "pause": false, "any": false}
	var keys := {"up": [KEY_UP, KEY_W], "down": [KEY_DOWN, KEY_S], "left": [KEY_LEFT, KEY_A], "right": [KEY_RIGHT, KEY_D],
		"ok": [KEY_ENTER, KEY_KP_ENTER, KEY_SPACE, KEY_J, KEY_F], "back": [KEY_ESCAPE, KEY_BACKSPACE], "pause": [KEY_ESCAPE]}
	var now := {}
	for a: String in keys:
		now[a] = false
		for k: int in keys[a]:
			if Input.is_physical_key_pressed(k):
				now[a] = true
	for i in 2:
		now["up"] = now["up"] or raw[i]["up"]
		now["down"] = now["down"] or raw[i]["down"]
		now["left"] = now["left"] or raw[i]["left"]
		now["right"] = now["right"] or raw[i]["right"]
		now["ok"] = now["ok"] or raw[i]["dash"] or raw[i]["light"]
		now["back"] = now["back"] or raw[i]["start"] or raw[i]["thrust"]
		now["pause"] = now["pause"] or raw[i]["start"]
	for a: String in now:
		m[a] = now[a] and not menu_prev.get(a, false)
		if m[a]:
			m["any"] = true
	menu_prev = now
	return m


func _menu(m: Dictionary) -> void:
	if show_controls:
		if m["any"]:
			show_controls = false
		return
	var in_fight: bool = mode in ["intro", "fight", "ko"]
	if in_fight and not paused:
		if m["pause"]:
			paused = true
			menu_idx = 0
		return
	if not (mode == "title" or mode == "end" or paused):
		return
	var items: Array = menu_items()
	var prev_key: String = "up" if paused else "left"
	var next_key: String = "down" if paused else "right"
	if m[prev_key]:
		menu_idx = (menu_idx - 1 + items.size()) % items.size()
	if m[next_key]:
		menu_idx = (menu_idx + 1) % items.size()
	if paused and m["back"]:
		paused = false
		return
	if mode == "title" and (m["up"] or m["down"]):
		_title_adjust(1 if m["down"] else -1)
	if m["ok"]:
		_menu_ok()


func _title_adjust(d: int) -> void:
	if menu_idx == 2:
		_build_stage((stage_idx + d + stages.size()) % stages.size())
		_place()
	elif menu_idx == 3:
		difficulty = clampi(difficulty + d, 0, 2)


func _menu_ok() -> void:
	if mode == "title":
		match menu_idx:
			0:
				vs_ai = true
				_start_match()
			1:
				vs_ai = false
				_start_match()
			2:
				_title_adjust(1)
			3:
				difficulty = (difficulty + 1) % 3
			4:
				show_controls = true
			5:
				get_tree().quit()
	elif paused:
		match menu_idx:
			0:
				paused = false
			1:
				show_controls = true
			2:
				_to_title()
	elif mode == "end":
		if menu_idx == 0:
			_start_match()
		else:
			_to_title()


# ---------------------------------------------------------------- loop

func _physics_process(_delta: float) -> void:
	frame += 1
	_poll()
	_menu(_menu_poll())
	if paused or show_controls:
		hud.queue_redraw()
		return

	if slow_timer > 0.0:
		slow_timer -= 1.0
		if slow_timer <= 0.0:
			ts_slow = 1.0
	elif ts_slow < 1.0:
		ts_slow = minf(1.0, ts_slow + 0.02)
	var ts: float = ts_slow
	var fts: float = ts
	if hitstop > 0.0:
		hitstop -= 1.0
		fts = 0.0

	var live: bool = mode == "fight" or mode == "title"
	for i in 2:
		var f: Fighter = fighters[i]
		if not live:
			for k: String in f.input:
				f.input[k] = false
			continue
		if mode == "title" or autotest or (vs_ai and i == 1):
			brains[i].think(fts)
		else:
			_player_input(i, f)
	for i in 2:
		fighters[i].update(fts, fighters[1 - i], stage.arena)
	_separate()
	var ev: Array = []
	if fts > 0.0 and live:
		Combat.step(fighters[0], fighters[1], ev)
	for f: Fighter in fighters:
		ev.append_array(f.events)
		f.events.clear()
	for e: Dictionary in ev:
		_on_event(e)

	fx.update(ts)
	stage.ambient(ts, fx, view_rect)
	_flow(ts)
	_camera()
	_post_fx()
	for n: CanvasItem in [fighter_view, shadow_view, contact_view, hud]:
		n.queue_redraw()
	fx.redraw()
	(shadow_group.material as ShaderMaterial).set_shader_parameter("blur", stage.shadow_blur * cur_zoom)
	if autotest:
		_autotest_tick()


func _player_input(i: int, f: Fighter) -> void:
	var r: Dictionary = raw[i]
	for k: String in ["left", "right", "up", "down", "block", "heavy"]:
		f.input[k] = r[k]
	for a: String in ["light", "heavy", "thrust", "kick", "dash"]:
		if _pressed(i, a):
			f.press(a)


func _separate() -> void:
	var a: Fighter = fighters[0]
	var b: Fighter = fighters[1]
	if a.rig.ragdoll or b.rig.ragdoll:
		return
	var dx: float = b.x - a.x
	var minimum := 54.0
	if absf(dx) < minimum:
		var push: float = (minimum - absf(dx)) * 0.5 * (1.0 if dx >= 0.0 else -1.0)
		a.x = clampf(a.x - push, stage.arena.x, stage.arena.y)
		b.x = clampf(b.x + push, stage.arena.x, stage.arena.y)


func _on_event(e: Dictionary) -> void:
	var pos: Vector2 = e.get("pos", Vector2.ZERO)
	stats[e["t"]] = int(stats.get(e["t"], 0)) + 1
	match e["t"]:
		"step":
			sfx.play(stage.step_sound, -16.0, randf_range(0.85, 1.15))
			fx.dust(pos, 2, stage.dust_color, 0.6)
		"dash":
			sfx.play("dash", -6.0, randf_range(0.9, 1.1))
			fx.dust(pos, 6, stage.dust_color, 1.4)
		"swing":
			var nm: String = "thrust" if e["kind"] == "thrust" else ("whoosh_heavy" if e["heavy"] else "whoosh")
			if e["kind"] != "kick":
				sfx.play(nm, -3.0, randf_range(0.92, 1.08))
			else:
				sfx.play("dash", -4.0, 0.8)
		"feint":
			sfx.play("dash", -10.0, 1.3)
		"clash":
			sfx.play("clash", 0.0, randf_range(0.95, 1.05))
			fx.spark(pos, 50, stage.spark_color, 10.0)
			fx.bubbles(pos, 10, 1.4)
			hitstop = 8.0
			shake = 9.0
			flash = 0.16
			ca = 1.0
		"parry":
			sfx.play("parry", 0.0, randf_range(0.97, 1.03))
			fx.spark(pos, 36, stage.spark_color, 8.0)
			hitstop = 7.0
			ts_slow = 0.35
			slow_timer = 12.0
			shake = 5.0
			flash = 0.12
			ca = 0.6
			_banner_small("DEFLECTED")
		"block":
			sfx.play("block", -2.0, randf_range(0.9, 1.1))
			fx.spark(pos, 14 if e["heavy"] else 8, stage.spark_color, 5.0)
			hitstop = 5.0 if e["heavy"] else 3.0
			shake = 4.0 if e["heavy"] else 2.0
		"break":
			sfx.play("break", 0.0)
			hitstop = 9.0
			zoom_punch = 0.05
			shake = 6.0
			_banner_small("GUARD BROKEN")
		"hit":
			var heavy: bool = e["heavy"] or float(e["dmg"]) > 24.0
			sfx.play("hit_heavy" if heavy else "hit", 0.0, randf_range(0.9, 1.1))
			fx.ink(pos, 14 if heavy else 8, e["dir"])
			fx.spark(pos, 10, stage.spark_color, 5.0)
			fx.bubbles(pos, 14 if heavy else 8, 1.6)
			fx.cut(pos, Vector2(e["dir"], 0.55 if e["part"] != "head" else 0.2), 220.0 if heavy else 160.0)
			hitstop = 9.0 if heavy else 6.0
			shake = 10.0 if heavy else 6.0
			flash = 0.14
			ca = 0.8
			if e["counter"]:
				_banner_small("COUNTER")
		"kick":
			sfx.play("kick", 0.0)
			fx.dust(pos, 6, stage.dust_color, 1.0)
			hitstop = 5.0
			shake = 6.0
		"fall":
			sfx.play("fall", -2.0)
			fx.dust(Vector2(pos.x, stage.ground), 16, stage.dust_color, 2.4)
			fx.bubbles(pos, 18, 1.2)
			shake = 4.0
		"ko":
			sfx.play("ko", 0.0)
			fx.ink(pos, 24, e["dir"])
			fx.bubbles(pos, 30, 2.2)
			fx.cut(pos, Vector2(e["dir"], 0.35), 420.0)
			hitstop = 16.0
			ts_slow = 0.22
			slow_timer = 100.0
			flash = 0.85
			ca = 1.4
			shake = 14.0
			zoom_punch = 0.16
			desat_target = 0.55
			var victim: Fighter = fighters[e["victim"]]
			var winner: Fighter = fighters[1 - int(e["victim"])]
			ko_focus = victim.x
			winner.wins += 1
			mode = "ko"
			timer = 300.0
			banner = {"text": "FALLEN", "life": 220.0, "max": 220.0, "size": 50}


func _banner_small(text: String) -> void:
	if mode == "ko":
		return
	banner = {"text": text, "life": 50.0, "max": 50.0, "size": 30}


func _flow(ts: float) -> void:
	if not banner.is_empty():
		banner["life"] = float(banner["life"]) - 1.0
		if float(banner["life"]) <= 0.0:
			banner = {}
	match mode:
		"intro":
			timer -= 1.0
			if timer == 60.0:
				sfx.play("draw", -4.0)
			if timer <= 0.0:
				mode = "fight"
				banner = {"text": "DRAW", "life": 50.0, "max": 50.0, "size": 54}
		"fight":
			round_time -= ts / 60.0
			if round_time <= 0.0:
				_timeout()
		"ko":
			timer -= 1.0
			if timer == 170.0:
				for f: Fighter in fighters:
					if f.state != "dead" and f.state != "dying":
						f.enter("victory")
			if timer <= 0.0:
				_after_round()


func _timeout() -> void:
	var a: Fighter = fighters[0]
	var b: Fighter = fighters[1]
	mode = "ko"
	timer = 200.0
	if absf(a.hp - b.hp) < 0.5:
		banner = {"text": "TIME — NEITHER YIELDS", "life": 170.0, "max": 170.0, "size": 40}
		return
	var w: Fighter = a if a.hp > b.hp else b
	w.wins += 1
	banner = {"text": "TIME", "sub": names()[w.id] + " HOLDS", "life": 170.0, "max": 170.0, "size": 46}


func _after_round() -> void:
	desat_target = 0.0
	for f: Fighter in fighters:
		if f.wins >= 2:
			mode = "end"
			menu_idx = 0
			banner = {"text": names()[f.id] + " PREVAILS", "life": 1e9, "max": 1e9, "size": 50, "y": 880.0}
			return
	_next_round()


func _camera() -> void:
	var a: float = fighters[0].x
	var b: float = fighters[1].x
	var focus: float = (a + b) * 0.5
	var dist: float = absf(a - b)
	var tz: float = clampf(1300.0 / (dist + 700.0), 0.84, 1.28)
	if mode == "title":
		tz *= 0.93
	if mode == "ko" and ko_focus >= 0.0:
		focus = lerpf(focus, ko_focus, 0.4)
		tz += 0.14
	cam_zoom = lerpf(cam_zoom, tz, 0.04)
	zoom_punch *= 0.9
	var z: float = cam_zoom * (1.0 + zoom_punch)
	cur_zoom = z
	cam_x = lerpf(cam_x, focus, 0.08)
	var half: float = 960.0 / z
	if stage.right - stage.left > half * 2.0:
		cam_x = clampf(cam_x, stage.left + half, stage.right - half)
	else:
		cam_x = stage.center_x
	shake *= 0.86
	var sh := Vector2(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0) * 0.6) * shake
	for entry: Array in layer_nodes:
		var n: Node2D = entry[0]
		var fac: float = entry[1]
		var zl: float = 1.0 + (z - 1.0) * fac
		var fl: float = lerpf(stage.center_x, cam_x, fac)
		n.scale = Vector2(zl, zl)
		n.position = ANCHOR - Vector2(fl, stage.ground) * zl + sh * fac
	view_rect = Rect2(cam_x - half, stage.ground - ANCHOR.y / z, half * 2.0, 1080.0 / z)


func _post_fx() -> void:
	flash *= 0.86
	ca *= 0.88
	desat = lerpf(desat, desat_target, 0.05)
	post.set_shader_parameter("flash", flash)
	post.set_shader_parameter("ca", ca)
	post.set_shader_parameter("desat", desat)


# ---------------------------------------------------------------- automated test

func _autotest_tick() -> void:
	var limit: int = auto_frames
	if shot_dir != "" and shot_every > 0 and frame % shot_every == 0:
		_shot("f%05d" % frame)
	if frame % 120 == 0:
		var a: Fighter = fighters[0]
		var b: Fighter = fighters[1]
		print("[%d] mode=%s round=%d  A hp=%.0f post=%.0f st=%.0f %s  B hp=%.0f post=%.0f st=%.0f %s  dist=%.0f" % [
			frame, mode, round_no, a.hp, a.posture, a.stamina, a.state, b.hp, b.posture, b.stamina, b.state, absf(a.x - b.x)])
	if frame >= limit:
		print("EVENTS ", stats)
		if shot_dir != "":
			_shot("final")
		get_tree().quit()


func _shot(name: String) -> void:
	var img: Image = get_viewport().get_texture().get_image()
	img.save_png(shot_dir.path_join(name + ".png"))
