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
## What the current duel counts as: "casual", "friend", "story" or "train".
var game_type := "casual"
var vs_ai := true
var opp_idx := 0
var progress := {}
var save_path := "user://progress.cfg"
var chapter := 0
var card: Dictionary = {}
var drill := ""
var drill_count := 0
var drill_goal := 0
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
var auto_game := "casual"


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
		elif a.begins_with("--game="):
			auto_game = a.get_slice("=", 1)
		elif a.begins_with("--opp="):
			opp_idx = int(a.get_slice("=", 1))
		elif a.begins_with("--dump="):
			_dump_bodies(a.get_slice("=", 1))
			set_physics_process(false)
			get_tree().quit()
			return
	# test runs never touch the player's real save
	if autotest:
		save_path = "user://autotest_progress.cfg"
		DirAccess.remove_absolute(save_path)
	progress = Builds.load_progress(save_path)
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
		match auto_game:
			"story":
				_begin_story()
			"train":
				_start_drill("kick")
			_:
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


func opponent() -> Dictionary:
	return Builds.MEN[opp_idx]


## The hero's trained ranks count everywhere except a duel between two players.
func _apply_builds() -> void:
	var levels: Dictionary = progress["levels"] if game_type != "friend" and mode != "title" else {}
	var hero_stats: Dictionary = Builds.hero_stats(levels)
	hero_stats["kick_lunge"] = 3.4
	fighters[0].apply_build(Builds.HERO, hero_stats)
	var man: Dictionary = opponent()
	fighters[1].apply_build(man, (man["stats"] as Dictionary).duplicate())
	for i in 2:
		var ai: Dictionary = Builds.HERO["ai"] if i == 0 else man["ai"]
		var base: float = 0.55 if mode == "title" else SKILL[difficulty]
		if autotest:
			base = 0.7
		if game_type == "story" and i == 1:
			base += chapter * 0.025
		if game_type == "train" and i == 1:
			base = 0.35 + 0.08 * int(progress["levels"].get(drill, 0))
		brains[i].skill = clampf(base + float(ai["skill"]), 0.1, 0.97)
		brains[i].aggr = ai["aggr"]
		brains[i].kick_rate = ai["kick"]
		brains[i].parry_bias = ai["parry"]


func _place() -> void:
	_apply_builds()
	var c: float = stage.center_x
	fighters[0].setup(0, c - 270.0, stage.ground, 1.0)
	fighters[1].setup(1, c + 270.0, stage.ground, -1.0)
	for f: Fighter in fighters:
		f.rig.wind = stage.wind
		f.rig.water = stage.water
		f.lethal = mode != "title" and game_type != "train"
	cam_x = c
	fx.clear()
	ts_slow = 1.0
	slow_timer = 0.0
	hitstop = 0.0
	desat_target = 0.0
	ko_focus = -1.0


func names() -> Array:
	return [Builds.HERO["name"], opponent()["name"]]


## Stable ids for the title menu; the labels come from menu_items.
const TITLE_MENU := ["story", "casual", "friend", "train", "controls", "opponent", "stage", "difficulty", "leave"]


func menu_items() -> Array:
	if mode == "title":
		var out: Array = []
		for id: String in TITLE_MENU:
			match id:
				"story":
					out.append("Story")
				"casual":
					out.append("Casual Duel")
				"friend":
					out.append("Duel a Friend")
				"train":
					out.append("Train")
				"controls":
					out.append("The Way of the Blade")
				"opponent":
					out.append("Opponent: " + String(opponent()["name"]).capitalize())
				"stage":
					out.append("Stage: " + stage.title.capitalize())
				"difficulty":
					out.append("Difficulty: " + DIFFICULTY[difficulty].capitalize())
				"leave":
					out.append("Leave")
		return out
	if mode == "train_menu":
		var rows: Array = []
		for sk: String in Builds.SKILLS:
			rows.append(sk)
		rows.append("back")
		return rows
	if paused:
		return ["Resume", "The Way of the Blade", "Abandon the duel"]
	if game_type == "story":
		return ["Fight again", "Return"]
	return ["Duel again", "Return"]


func _to_title() -> void:
	mode = "title"
	game_type = "casual"
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
	if mode == "card":
		if m["ok"]:
			_card_ok()
		elif m["back"]:
			_to_title()
		return
	var in_fight: bool = mode in ["intro", "fight", "ko"]
	if in_fight and not paused:
		if m["pause"]:
			paused = true
			menu_idx = 0
		return
	if not (mode == "title" or mode == "end" or mode == "train_menu" or paused):
		return
	if mode == "train_menu" and m["back"]:
		_to_title()
		return
	var items: Array = menu_items()
	var vertical: bool = paused or mode == "train_menu"
	var prev_key: String = "up" if vertical else "left"
	var next_key: String = "down" if vertical else "right"
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
	match TITLE_MENU[menu_idx]:
		"opponent":
			opp_idx = (opp_idx + d + Builds.MEN.size()) % Builds.MEN.size()
			_place()
		"stage":
			_build_stage((stage_idx + d + stages.size()) % stages.size())
			_place()
		"difficulty":
			difficulty = clampi(difficulty + d, 0, 2)


func _menu_ok() -> void:
	if mode == "title":
		match TITLE_MENU[menu_idx]:
			"story":
				_begin_story()
			"casual":
				vs_ai = true
				game_type = "casual"
				_start_match()
			"friend":
				vs_ai = false
				game_type = "friend"
				_start_match()
			"train":
				mode = "train_menu"
				menu_idx = 0
			"opponent", "stage":
				_title_adjust(1)
			"difficulty":
				difficulty = (difficulty + 1) % 3
			"controls":
				show_controls = true
			"leave":
				get_tree().quit()
	elif mode == "train_menu":
		var id: String = menu_items()[menu_idx]
		if id == "back":
			_to_title()
		elif int(progress["levels"][id]) < Builds.MAX_LEVEL:
			_start_drill(id)
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


# ---------------------------------------------------------------- story and training

func _begin_story() -> void:
	vs_ai = true
	game_type = "story"
	chapter = int(progress["chapter"])
	if chapter >= Builds.STORY.size():
		chapter = 0
	_show_chapter()


func _show_chapter() -> void:
	var ch: Dictionary = Builds.STORY[chapter]
	for i in Builds.MEN.size():
		if Builds.MEN[i]["id"] == ch["opp"]:
			opp_idx = i
	_build_stage(ch["stage"])
	card = {"title": ch["title"], "lines": ch["text"], "next": "fight"}
	mode = "card"
	timer = 0.0
	banner = {}
	_place()


func _card_ok() -> void:
	if card["next"] == "fight":
		_start_match()
	else:
		_to_title()


func _story_won() -> void:
	chapter += 1
	progress["chapter"] = maxi(int(progress["chapter"]), chapter)
	Builds.save_progress(save_path, progress)
	if chapter >= Builds.STORY.size():
		card = {"title": "THE WATER STILLS", "lines": Builds.STORY_END, "next": "title"}
		mode = "card"
		timer = 0.0
		banner = {}
		print("STORY COMPLETE")
	else:
		_show_chapter()


## A drill is a non-lethal spar against a partner that gets better as the rank climbs.
func _start_drill(skill: String) -> void:
	vs_ai = true
	game_type = "train"
	drill = skill
	drill_count = 0
	drill_goal = Builds.drill_goal(skill, int(progress["levels"][skill]))
	opp_idx = 0
	_start_match()
	round_time = 75.0


func _drill_event(e: Dictionary) -> void:
	var counted := false
	match drill:
		"blade":
			counted = e["t"] == "hit" and e["victim"] == 1
		"kick":
			counted = e["t"] == "kick" and e["id"] == 0 and not e["blocked"]
		"footwork":
			counted = e["t"] == "dash" and e["id"] == 0 and fighters[1].state == "attack" and fighters[1].phase == "startup"
		"guard":
			counted = e["t"] == "parry" and e["by"] == 0
		"vigor":
			counted = (e["t"] == "sweep" or e["t"] == "break") and e["victim"] == 1
	if not counted:
		return
	drill_count += 1
	if drill_count >= drill_goal:
		_end_drill(true)


func _end_drill(passed: bool) -> void:
	mode = "drill_done"
	timer = 170.0
	var info: Dictionary = Builds.SKILL_INFO[drill]
	if passed:
		progress["levels"][drill] = int(progress["levels"][drill]) + 1
		Builds.save_progress(save_path, progress)
		sfx.play("gong", -4.0)
		banner = {"text": "%s RISES TO %s" % [info["title"], ROMAN[int(progress["levels"][drill])]], "life": 170.0, "max": 170.0, "size": 46}
	else:
		banner = {"text": "NOT YET", "sub": "TIME", "life": 170.0, "max": 170.0, "size": 46}
	print("DRILL %s passed=%s count=%d/%d" % [drill, passed, drill_count, drill_goal])


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

	var live: bool = mode == "fight" or mode == "title" or mode == "card" or mode == "train_menu"
	for i in 2:
		var f: Fighter = fighters[i]
		if not live:
			for k: String in f.input:
				f.input[k] = false
			continue
		if mode != "fight" or autotest or (vs_ai and i == 1):
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
	if game_type == "train" and mode == "fight":
		_drill_event(e)
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
				stats["kick_try"] = int(stats.get("kick_try", 0)) + 1
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
			sfx.play("block" if e["blocked"] else "kick", 0.0)
			fx.dust(pos, 6, stage.dust_color, 1.0)
			hitstop = 5.0
			shake = 6.0
		"sweep":
			sfx.play("fall", 0.0)
			fx.dust(Vector2(pos.x, stage.ground), 14, stage.dust_color, 2.0)
			hitstop = 10.0
			shake = 8.0
			zoom_punch = 0.06
			_banner_small("SWEPT")
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
		"drill_done":
			timer -= 1.0
			if timer <= 0.0:
				if autotest:
					print("EVENTS ", stats)
					get_tree().quit()
					return
				mode = "train_menu"
				menu_idx = 0
				_place()
		"card":
			timer += 1.0
			if autotest and timer > 30.0:
				_card_ok()
		"end":
			if autotest:
				if game_type == "story":
					print("STORY chapter %d lost, retrying" % chapter)
				_start_match()


func _timeout() -> void:
	if game_type == "train":
		_end_drill(false)
		return
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
			if game_type == "story" and f.id == 0:
				_story_won()
				return
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


## Writes every build's silhouette in several poses to a JSON file, for checking the art outside the game.
func _dump_bodies(path: String) -> void:
	var poses := {"guard": Fighter.GUARD[1], "heavy": Fighter.ATTACKS["heavy"][0][1],
		"low_kick": Fighter.ATTACKS["kick"][2][1], "high_kick": Fighter.ATTACKS["kick"][0][1]}
	var builds: Array = [Builds.HERO]
	builds.append_array(Builds.MEN)
	var out := {}
	for b: Dictionary in builds:
		var entry := {}
		for pose_name: String in poses:
			var r := Rig.new()
			r.apply_build(b)
			r.reset(0.0, 0.0, 1.0)
			r.set_pose(poses[pose_name], 12.0, 1.0)
			for i in 300:
				r.update(1.0, 0.0)
			var sh: Dictionary = r.build_shapes()
			entry[pose_name] = {"back": _polys_json(sh["back"]), "main": _polys_json(sh["main"]), "blade": _polys_json(r.blade_polys())}
		out[b["id"]] = entry
	var fa := FileAccess.open(path, FileAccess.WRITE)
	fa.store_string(JSON.stringify(out))
	fa.close()


func _polys_json(polys: Array) -> Array:
	var out: Array = []
	for poly: PackedVector2Array in polys:
		var pts: Array = []
		for q: Vector2 in poly:
			pts.append([q.x, q.y])
		out.append(pts)
	return out


func _shot(name: String) -> void:
	var img: Image = get_viewport().get_texture().get_image()
	img.save_png(shot_dir.path_join(name + ".png"))
