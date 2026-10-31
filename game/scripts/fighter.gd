class_name Fighter
extends RefCounted
## One duelist: footwork, guard lines, attacks, posture, stamina and the poses that sell them.

enum { HIGH, MID, LOW }

const PARRY_WINDOW := 6.0
const PARRY_SPAM := 24.0
const MAX_CHARGE := 34.0

const MOVES := {
	"light": {"startup": 15.0, "active": 5.0, "recovery": 15.0, "dmg": 16.0, "posture": 20.0, "stam": 12.0, "lunge": 3.5, "kind": "cut"},
	"heavy": {"startup": 26.0, "active": 6.0, "recovery": 26.0, "dmg": 30.0, "posture": 42.0, "stam": 22.0, "lunge": 6.5, "kind": "cut"},
	"thrust": {"startup": 17.0, "active": 5.0, "recovery": 20.0, "dmg": 20.0, "posture": 26.0, "stam": 15.0, "lunge": 9.0, "kind": "thrust"},
	"kick": {"startup": 15.0, "active": 5.0, "recovery": 18.0, "dmg": 3.0, "posture": 34.0, "stam": 14.0, "lunge": 4.0, "kind": "kick"},
}

const GUARD := [
	{"hx": 12.0, "hy": -50.0, "sa": -2.2, "lean": -0.02, "py": 4.0},
	{"hx": 36.0, "hy": 30.0, "sa": -0.62, "lean": 0.06, "py": 6.0},
	{"hx": 30.0, "hy": 56.0, "sa": 0.42, "lean": 0.12, "py": 9.0},
]
const BLOCK := [
	{"hx": 20.0, "hy": -52.0, "sa": -0.12, "lean": -0.05, "py": 9.0, "bf": -36.0},
	{"hx": 34.0, "hy": 12.0, "sa": -1.42, "lean": -0.03, "py": 11.0, "bf": -36.0},
	{"hx": 34.0, "hy": 44.0, "sa": 1.3, "lean": 0.12, "py": 14.0, "bf": -36.0},
]

## [startup, active, recovery] key poses per guard line.
const ATTACKS := {
	"light": [
		[{"hx": 6.0, "hy": -56.0, "sa": -2.6, "lean": -0.07, "py": 4.0, "bf": -36.0},
		 {"hx": 46.0, "hy": 32.0, "sa": 0.55, "lean": 0.3, "py": 16.0, "ff": 50.0, "bf": -34.0},
		 {"hx": 40.0, "hy": 38.0, "sa": 0.85, "lean": 0.22, "py": 14.0, "ff": 48.0}],
		[{"hx": -4.0, "hy": 26.0, "sa": 2.8, "fs": 1.0, "lean": -0.1, "py": 8.0, "bf": -38.0},
		 {"hx": 52.0, "hy": 22.0, "sa": -0.05, "fs": 1.0, "lean": 0.28, "py": 12.0, "ff": 50.0},
		 {"hx": 46.0, "hy": 26.0, "sa": -0.25, "lean": 0.2, "py": 10.0, "ff": 48.0}],
		[{"hx": -2.0, "hy": 48.0, "sa": 2.45, "lean": -0.02, "py": 12.0, "bf": -36.0},
		 {"hx": 46.0, "hy": 52.0, "sa": 0.3, "lean": 0.36, "py": 26.0, "ff": 52.0},
		 {"hx": 42.0, "hy": 54.0, "sa": 0.5, "lean": 0.28, "py": 22.0, "ff": 50.0}],
	],
	"heavy": [
		[{"hx": -2.0, "hy": -58.0, "sa": -2.9, "lean": -0.16, "py": 2.0, "ff": 22.0, "bf": -46.0},
		 {"hx": 50.0, "hy": 34.0, "sa": 0.8, "lean": 0.42, "py": 24.0, "ff": 64.0, "bf": -40.0},
		 {"hx": 46.0, "hy": 42.0, "sa": 1.0, "lean": 0.34, "py": 22.0, "ff": 62.0}],
		[{"hx": -16.0, "hy": 20.0, "sa": 3.0, "fs": 1.0, "lean": -0.18, "py": 8.0, "bf": -48.0},
		 {"hx": 56.0, "hy": 20.0, "sa": -0.1, "fs": 1.0, "lean": 0.36, "py": 18.0, "ff": 64.0},
		 {"hx": 48.0, "hy": 26.0, "sa": -0.35, "lean": 0.28, "py": 16.0, "ff": 62.0}],
		[{"hx": -10.0, "hy": 46.0, "sa": 2.6, "lean": -0.08, "py": 14.0, "bf": -48.0},
		 {"hx": 50.0, "hy": 54.0, "sa": 0.25, "lean": 0.46, "py": 32.0, "ff": 64.0},
		 {"hx": 46.0, "hy": 56.0, "sa": 0.45, "lean": 0.36, "py": 28.0, "ff": 62.0}],
	],
	"thrust": [
		[{"hx": 0.0, "hy": 24.0, "sa": 0.02, "lean": -0.12, "py": 10.0, "bf": -48.0, "ff": 22.0},
		 {"hx": 68.0, "hy": 16.0, "sa": -0.02, "lean": 0.34, "py": 18.0, "ff": 72.0},
		 {"hx": 56.0, "hy": 20.0, "sa": 0.06, "lean": 0.26, "py": 16.0, "ff": 68.0}],
	],
	# one kick per guard line: head kick, push kick, leg kick
	"kick": [
		[{"kw": 0.7, "kx": 20.0, "ky": 40.0, "hx": 24.0, "hy": 30.0, "sa": -0.9, "lean": -0.2, "py": 6.0},
		 {"kw": 1.0, "kx": 70.0, "ky": 58.0, "hx": 16.0, "hy": 34.0, "sa": -0.7, "lean": -0.42, "py": 6.0, "ht": 0.1},
		 {"kw": 0.3, "kx": 30.0, "ky": 20.0, "hx": 28.0, "hy": 30.0, "sa": -0.8, "lean": -0.1}],
		[{"kw": 0.7, "kx": 22.0, "ky": 46.0, "hx": 28.0, "hy": 26.0, "sa": -1.0, "lean": -0.14, "py": 4.0},
		 {"kw": 1.0, "kx": 74.0, "ky": 30.0, "hx": 22.0, "hy": 22.0, "sa": -1.2, "lean": -0.26, "py": 2.0},
		 {"kw": 0.3, "kx": 30.0, "ky": 16.0, "hx": 30.0, "hy": 28.0, "sa": -0.8, "lean": -0.05}],
		[{"kw": 0.6, "kx": 26.0, "ky": -24.0, "hx": 30.0, "hy": 24.0, "sa": -0.8, "lean": -0.04, "py": 8.0},
		 {"kw": 1.0, "kx": 72.0, "ky": -62.0, "hx": 24.0, "hy": 22.0, "sa": -1.0, "lean": -0.16, "py": 12.0},
		 {"kw": 0.3, "kx": 28.0, "ky": -34.0, "hx": 30.0, "hy": 28.0, "sa": -0.8, "lean": -0.04, "py": 8.0}],
	],
}

## Kick strength by guard line, before the kicker's `kick` stat.
const KICKS := [
	{"dmg": 9.0, "posture": 20.0, "stun": 30.0},
	{"dmg": 3.0, "posture": 34.0, "stun": 26.0},
	{"dmg": 6.0, "posture": 12.0, "stun": 20.0},
]
const SWEEP_AT := 2.0
const SWEPT := {"hx": 20.0, "hy": 58.0, "sa": 1.5, "lean": 0.55, "py": 56.0, "ht": 0.3, "ff": 42.0, "bf": -44.0}
const RECOIL := {"hx": 2.0, "hy": -44.0, "sa": -2.7, "lean": -0.28, "py": 6.0, "ht": -0.3, "bf": -46.0, "ff": 18.0}
const HURT := {"hx": 24.0, "hy": 44.0, "sa": 1.0, "lean": -0.12, "py": 16.0, "ht": -0.15}
const BROKEN := {"hx": 20.0, "hy": 60.0, "sa": 1.55, "lean": 0.5, "py": 30.0, "ht": 0.45, "ff": 30.0, "bf": -34.0}
const KICKED := {"hx": 22.0, "hy": 30.0, "sa": -1.3, "lean": -0.34, "py": 12.0, "ht": -0.25, "bf": -44.0}
const DYING := {"hx": 18.0, "hy": 62.0, "sa": 1.65, "lean": 0.6, "py": 46.0, "ht": 0.5}
const VICTORY := {"hx": 32.0, "hy": 52.0, "sa": 1.15, "lean": 0.04, "py": 4.0, "ht": 0.12}

var id := 0
var rig := Rig.new()
var x := 0.0
var vx := 0.0
var facing := 1.0
var ground := 0.0
var hp := 100.0
var hp_trail := 100.0
var posture := 0.0
var stamina := 100.0
var exhausted := false
var wins := 0
var lethal := true
var build: Dictionary = {}
var stats: Dictionary = {}
## Low kicks landed and not yet recovered from: slows the leg, and the second sweeps it.
var leg_wound := 0.0
var leg_delay := 0.0
## Frames left in which a cut on this fighter gets the kicker's follow-up bonus.
var opened := 0.0

var state := "idle"
var st := 0.0
var stun_len := 0.0
var move_name := ""
var move: Dictionary = {}
var phase := ""
var startup_eff := 0.0
var line := MID
var attack_line := MID
var attack_id := 0
var charge := 0.0
var charging := false
var hit_done := false
var block_t := 99.0
var last_block_press := -99.0
var parry_ok := false
var prev_block := false
var limp := 0.0
var stam_delay := 0.0
var posture_delay := 0.0
var dash_dir := 0.0
var age := 0.0

var input := {"left": false, "right": false, "up": false, "down": false, "block": false, "heavy": false}
var buf := {"light": 0.0, "heavy": 0.0, "thrust": 0.0, "kick": 0.0, "dash": 0.0}
var prev_base := Vector2.ZERO
var prev_dir := Vector2.RIGHT
var prev_len := 0.0
var trail: Array = []
var events: Array = []
var shapes: Dictionary = {}


func apply_build(b: Dictionary, st: Dictionary) -> void:
	build = b
	stats = st
	rig.apply_build(b)


func setup(i: int, px: float, gy: float, face: float) -> void:
	id = i
	leg_wound = 0.0
	leg_delay = 0.0
	opened = 0.0
	x = px
	ground = gy
	facing = face
	hp = 100.0
	hp_trail = 100.0
	posture = 0.0
	stamina = 100.0
	exhausted = false
	vx = 0.0
	limp = 0.0
	charge = 0.0
	line = MID
	enter("idle")
	trail.clear()
	events.clear()
	for k: String in buf:
		buf[k] = 0.0
	for k: String in input:
		input[k] = false
	rig.reset(x, gy, face)
	_sync_prev()
	shapes = rig.build_shapes()


func press(action: String) -> void:
	buf[action] = 8.0


func enter(s: String) -> void:
	state = s
	st = 0.0
	if s != "attack":
		phase = ""
		charging = false


func is_free() -> bool:
	return state == "idle" or state == "walk" or state == "block"


func update(ts: float, op: Fighter, arena: Vector2) -> void:
	if ts <= 0.0:
		return
	age += ts
	st += ts
	for k: String in buf:
		buf[k] = maxf(0.0, float(buf[k]) - ts)
	_sync_prev()
	var block_pressed: bool = input["block"] and not prev_block
	prev_block = input["block"]

	if is_free():
		facing = 1.0 if op.x > x else -1.0
		line = HIGH if input["up"] else (LOW if input["down"] else MID)
	var fwd: int = (int(input["right"]) - int(input["left"])) * int(facing)

	stam_delay -= ts
	if stam_delay <= 0.0 and state != "attack" and state != "dash":
		stamina = minf(100.0, stamina + (0.26 if state == "block" else 0.5) * float(stats["stam"]) * ts)
	if exhausted and stamina > 35.0:
		exhausted = false
	posture_delay -= ts
	if posture_delay <= 0.0 and state != "broken":
		posture = maxf(0.0, posture - (0.2 if state == "block" else 0.42) * ts)
	limp = maxf(0.0, limp - ts)
	# a kicked leg stays hurt for about four seconds, long enough to land the next one
	leg_delay -= ts
	if leg_delay <= 0.0:
		leg_wound = maxf(0.0, leg_wound - ts / 420.0)
	opened = maxf(0.0, opened - ts)
	if hp_trail > hp:
		hp_trail = maxf(hp, hp_trail - 0.45 * ts)
	block_t += ts

	match state:
		"idle", "walk", "block":
			_free_update(ts, fwd, block_pressed)
		"attack":
			_attack_update(ts, block_pressed)
		"dash":
			var k: float = st / 15.0
			vx = dash_dir * facing * (11.0 if dash_dir > 0.0 else 9.5) * pow(maxf(0.0, 1.0 - k), 1.4)
			if st >= 15.0:
				enter("idle")
		"recoil", "hurt", "broken", "kicked", "blockstun", "deflect", "swept":
			vx *= pow(0.84, ts)
			if st >= stun_len:
				if state == "broken":
					posture = 55.0
				enter("idle")
		"dying":
			vx *= pow(0.9, ts)
			if st >= 14.0 and not rig.ragdoll:
				rig.go_ragdoll(Vector2(vx * 0.6 - facing * 1.2, -1.0))
				events.append({"t": "fall", "pos": rig.pelvis})
				enter("dead")
		"dead":
			vx = 0.0
		"victory":
			vx *= pow(0.8, ts)
	x = clampf(x + vx * ts, arena.x, arena.y)

	_apply_pose()
	if not rig.ragdoll:
		rig.facing = facing
	rig.root_x = x
	rig.update(ts, vx)
	if rig.step_events > 0:
		rig.step_events = 0
		events.append({"t": "step", "pos": Vector2(x, ground)})
	_trail_update()
	shapes = rig.build_shapes()


func _free_update(ts: float, fwd: int, block_pressed: bool) -> void:
	for name: String in ["light", "heavy", "thrust", "kick"]:
		if float(buf[name]) > 0.0:
			buf[name] = 0.0
			_start(name)
			return
	if float(buf["dash"]) > 0.0 and stamina >= 12.0 and not exhausted:
		buf["dash"] = 0.0
		dash_dir = 1.0 if fwd > 0 else -1.0
		_spend(18.0 * float(stats.get("dash_cost", 1.0)))
		enter("dash")
		events.append({"t": "dash", "pos": Vector2(x, ground), "id": id})
		return
	var blocking: bool = input["block"]
	if block_pressed:
		# a fresh guard opens the parry window, unless the guard is being mashed
		parry_ok = (age - last_block_press) > PARRY_SPAM
		last_block_press = age
		block_t = 0.0
	var speed_mul: float = float(stats["speed"]) * (0.72 if exhausted else 1.0) * (0.62 if limp > 0.0 else 1.0)
	speed_mul *= 1.0 - 0.2 * minf(leg_wound, SWEEP_AT)
	var target := 0.0
	if fwd != 0:
		target = facing * fwd * (3.1 if fwd > 0 else 2.4) * speed_mul * (0.5 if blocking else 1.0)
	vx = lerpf(vx, target, 1.0 - pow(0.8, ts))
	if blocking:
		state = "block"
	else:
		state = "walk" if absf(vx) > 0.4 else "idle"


func _start(name: String) -> void:
	var mv: Dictionary = MOVES[name]
	_spend(mv["stam"])
	move_name = name
	move = mv
	attack_line = line
	if name == "thrust" or (name == "kick" and not stats["kick_lines"]):
		attack_line = MID
	startup_eff = float(mv["startup"]) * float(stats["startup"]) * (1.22 if exhausted else 1.0)
	if name == "kick":
		startup_eff *= float(stats.get("kick_startup", 1.0))
	charge = 0.0
	charging = false
	hit_done = false
	attack_id += 1
	enter("attack")
	phase = "startup"
	events.append({"t": "windup", "heavy": name == "heavy", "pos": rig.chest})


func _spend(amount: float) -> void:
	stamina -= amount
	stam_delay = 36.0
	if stamina <= 0.0:
		stamina = 0.0
		exhausted = true


func _attack_update(ts: float, block_pressed: bool) -> void:
	vx *= pow(0.82, ts)
	if phase == "startup":
		if move_name == "heavy" and block_pressed and st < startup_eff - 3.0:
			# feint: abandon the heavy and drop straight into guard
			_spend(8.0)
			parry_ok = (age - last_block_press) > PARRY_SPAM
			last_block_press = age
			block_t = 0.0
			enter("block")
			events.append({"t": "feint", "pos": rig.chest})
			return
		if move_name == "heavy" and input["heavy"] and charge < MAX_CHARGE and st >= startup_eff - 1.0:
			st = startup_eff - 1.0
			charge += ts
			charging = true
		else:
			charging = false
		if st >= startup_eff:
			phase = "active"
			st = 0.0
			var lunge: float = float(move["lunge"]) * (1.0 + charge / 60.0)
			if move_name == "kick":
				lunge *= float(stats.get("kick_lunge", 1.0))
			vx += facing * lunge
			hit_done = false
			events.append({"t": "swing", "heavy": move_name == "heavy", "kind": move["kind"], "pos": rig.chest})
	elif phase == "active":
		if st >= float(move["active"]):
			phase = "recovery"
			st = 0.0
	elif phase == "recovery":
		if st >= float(move["recovery"]) * (1.15 if exhausted else 1.0):
			enter("idle")


func remaining_startup() -> float:
	if state != "attack" or phase != "startup":
		return 0.0
	return startup_eff - st


func _apply_pose() -> void:
	if rig.ragdoll:
		return
	var pose: Dictionary
	var stiff := 11.0
	var damp := 0.9
	match state:
		"idle", "walk":
			pose = GUARD[line].duplicate()
			stiff = 10.0
			if state == "walk":
				pose["lean"] = float(pose["lean"]) + 0.05 * signf(vx * facing)
		"block", "blockstun":
			pose = BLOCK[line].duplicate()
			stiff = 30.0
			damp = 0.8
		"deflect":
			pose = BLOCK[line].duplicate()
			pose["hx"] = float(pose["hx"]) + 12.0
			stiff = 34.0
			damp = 0.6
		"attack":
			var frames: Array = ATTACKS[move_name]
			var keys: Array = frames[attack_line if frames.size() > 1 else 0]
			if move_name == "thrust":
				keys = frames[0]
			var idx: int = 0 if phase == "startup" else (1 if phase == "active" else 2)
			pose = keys[idx].duplicate()
			if phase == "startup":
				stiff = 13.0 if move_name == "heavy" else 19.0
				damp = 1.0
			elif phase == "active":
				stiff = 46.0
				damp = 0.72
			else:
				stiff = 10.0
				damp = 1.0
			if charging:
				pose["tw"] = 1.0
				pose["lean"] = float(pose.get("lean", 0.0)) - 0.06
				pose["py"] = float(pose.get("py", 6.0)) + 4.0
		"dash":
			pose = GUARD[line].duplicate()
			pose["lean"] = 0.24 if dash_dir > 0.0 else -0.16
			pose["py"] = 18.0 if dash_dir > 0.0 else 12.0
			stiff = 18.0
		"recoil":
			pose = RECOIL
			stiff = 18.0
			damp = 0.55
		"hurt":
			pose = HURT
			stiff = 16.0
			damp = 0.6
		"broken":
			pose = BROKEN
			stiff = 9.0
			damp = 0.7
		"kicked":
			pose = KICKED
			stiff = 16.0
			damp = 0.6
		"swept":
			pose = SWEPT
			stiff = 20.0
			damp = 0.75
		"dying":
			pose = DYING
			stiff = 7.0
			damp = 0.8
		"victory":
			pose = VICTORY
			stiff = 4.0
		_:
			pose = GUARD[MID]
	if exhausted or limp > 0.0:
		pose = pose.duplicate()
		if exhausted:
			pose["py"] = float(pose.get("py", 6.0)) + 7.0
			pose["lean"] = float(pose.get("lean", 0.06)) + 0.06
		if limp > 0.0:
			pose["py"] = float(pose.get("py", 6.0)) + 5.0
	rig.set_pose(pose, stiff, damp)


func _sync_prev() -> void:
	prev_base = rig.blade_base
	prev_dir = rig.sword_dir
	prev_len = rig.blade_base.distance_to(rig.blade_tip)


func _trail_update() -> void:
	var swinging: bool = state == "attack" and move_name != "kick" and (phase == "active" or (phase == "recovery" and st < 3.0))
	if swinging:
		trail.push_back([rig.blade_base.lerp(rig.blade_tip, 0.25), rig.blade_tip])
		if trail.size() > 9:
			trail.pop_front()
	elif trail.size() > 0:
		trail.pop_front()
