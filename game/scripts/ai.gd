class_name AIBrain
extends RefCounted
## An opponent that reads wind-ups with human-like reaction time, guesses lines, parries,
## punishes openings, kicks turtles, feints and manages its stamina.

var me: Fighter
var op: Fighter
var skill := 0.6
## Temperament from the build: how often it attacks, kicks and tries to parry.
var aggr := 0.6
var kick_rate := 0.2
var parry_bias := 1.0

var cd := 0.0
var line_hold := Fighter.MID
var line_timer := 0.0
var spacing := 240.0
var space_timer := 0.0
var turtle := 0.0
var charge_t := 0.0
var guard_t := 0.0

var react_id := -1
var react_at := 0.0
var decided := false
var plan := ""
var plan_line := Fighter.MID
var parry_lead := 4.0
var feint_armed := false
## Set after dashing in: kick as soon as the dash ends.
var dash_kick := false


## How far this fighter's blade reaches with a step, which sets all of its spacing.
func _reach() -> float:
	return 87.0 + me.rig.blade_len


func think(ts: float) -> void:
	var inp: Dictionary = me.input
	inp["left"] = false
	inp["right"] = false
	inp["up"] = false
	inp["down"] = false
	inp["block"] = false
	if ts <= 0.0 or me.state == "dead" or me.state == "dying":
		return
	var dist: float = absf(op.x - me.x)
	var reach: float = _reach()
	var fwd: String = "right" if op.x > me.x else "left"
	var back: String = "left" if fwd == "right" else "right"
	cd -= ts
	if op.state == "block":
		turtle += ts
	else:
		turtle = maxf(0.0, turtle - ts * 0.5)

	# keep a charged heavy wound for a moment
	if charge_t > 0.0:
		charge_t -= ts
		inp["heavy"] = true
	else:
		inp["heavy"] = false

	# feint a heavy when the opponent bites with an early guard
	if me.state == "attack" and me.move_name == "heavy" and me.phase == "startup" and feint_armed:
		if op.state == "block" and op.block_t < 5.0 and randf() < 0.55 * skill:
			inp["block"] = true
			feint_armed = false
			cd = 0.0
			return

	var threat: bool = op.state == "attack" and op.phase == "startup" and dist < 300.0
	if threat:
		if react_id != op.attack_id:
			react_id = op.attack_id
			decided = false
			plan = ""
			react_at = lerpf(17.0, 7.0, skill) + randf() * 5.0
		if not decided and op.st >= react_at:
			decided = true
			_decide(dist)
		if decided:
			_exec(dist, fwd, back)
		return
	if op.state == "attack" and op.phase == "active" and (plan == "block" or plan == "parry"):
		inp["block"] = true
		_set_line(plan_line)
		return
	plan = ""

	if not me.is_free():
		return

	if dash_kick:
		dash_kick = false
		if dist < 175.0:
			_kick_choice()
			cd = randf_range(14.0, 34.0)
			return

	var open: bool = op.state in ["recoil", "broken", "hurt", "kicked", "swept"] or (op.state == "attack" and op.phase == "recovery")
	if open:
		if dist < reach - 10.0 and cd <= 0.0:
			_set_line(randi() % 3)
			me.press("heavy" if op.state == "broken" or op.state == "swept" else "light")
			cd = 18.0
		elif dist < reach + 125.0:
			inp[fwd] = true
		return

	if me.stamina < 25.0:
		spacing = 300.0
	space_timer -= ts
	if space_timer <= 0.0:
		spacing = randf_range(reach - 5.0, reach + 85.0)
		# a kicker fights inside the sword, where the legs can reach
		if kick_rate >= 0.5:
			spacing = randf_range(120.0, 150.0)
		space_timer = randf_range(40.0, 120.0)
	if dist > spacing + 15.0:
		inp[fwd] = true
	elif dist < spacing - 15.0:
		inp[back] = true
	# sometimes hold a guard up in advance, more so when hurt
	if guard_t > 0.0:
		guard_t -= ts
		inp["block"] = true
	elif dist < reach + 45.0 and randf() < 0.008 * (1.0 + (1.0 - me.hp / 100.0) * 2.0):
		guard_t = randf_range(30.0, 100.0)

	line_timer -= ts
	if line_timer <= 0.0:
		var r := randf()
		line_hold = Fighter.MID if r < 0.5 else (Fighter.HIGH if r < 0.78 else Fighter.LOW)
		line_timer = randf_range(30.0, 120.0)
	_set_line(line_hold)

	if cd <= 0.0 and me.stamina > 25.0:
		if turtle > 40.0 and dist < 135.0:
			_set_line(Fighter.MID)
			me.press("kick")
			cd = 40.0
		elif dist < 160.0 and randf() < 0.14 * kick_rate:
			_kick_choice()
			cd = randf_range(14.0, 34.0)
		elif kick_rate >= 0.5 and dist >= 160.0 and dist < 270.0 and me.stamina > 45.0 and randf() < 0.05 * kick_rate:
			inp[fwd] = true
			dash_kick = true
			me.press("dash")
			cd = 30.0
		elif dist < reach and randf() < (0.06 + 0.05 * skill) * aggr / 0.6 * (1.0 - kick_rate * 0.7):
			var r := randf()
			if r < 0.5:
				me.press("light")
			elif r < 0.75:
				me.press("heavy")
				feint_armed = randf() < 0.6 * skill
				if randf() < 0.35:
					charge_t = randf_range(8.0, 30.0)
			elif r < 0.9:
				me.press("thrust")
			elif dist < 140.0:
				me.press("kick")
			cd = randf_range(25.0, 70.0) * (1.3 - skill) * (1.45 - 0.75 * aggr)
		elif dist > reach - 5.0 and dist < reach + 33.0 and randf() < 0.02:
			me.press("thrust")
			cd = randf_range(30.0, 60.0)
		elif turtle > 25.0 and dist > 135.0 and dist < reach + 55.0:
			inp[fwd] = true


## Mostly the leg, finishing a wounded one; the head when the guard is low.
func _kick_choice() -> void:
	var r := randf()
	if op.leg_wound >= 1.0 or r < 0.6:
		_set_line(Fighter.LOW if op.line != Fighter.LOW else Fighter.HIGH)
	elif r < 0.8:
		_set_line(Fighter.HIGH)
	else:
		_set_line(Fighter.MID)
	me.press("kick")


func _decide(dist: float) -> void:
	var correct: bool = randf() < 0.5 + 0.45 * skill
	plan_line = op.attack_line if correct else randi() % 3
	var r := randf()
	match op.move_name:
		"kick":
			plan = "interrupt" if r < 0.35 else ("evade" if r < 0.6 else "block")
		"heavy":
			if r < (0.35 * skill + 0.1) * parry_bias:
				plan = "parry"
			elif r < 0.6:
				plan = "block"
			elif r < 0.78:
				plan = "evade"
			else:
				plan = "interrupt"
		_:
			if r < 0.45 * skill * parry_bias:
				plan = "parry"
			elif r < 0.86:
				plan = "block"
			else:
				plan = "evade"
	if plan == "interrupt" and (me.stamina < 15.0 or op.remaining_startup() < 12.0):
		plan = "block"
	parry_lead = 4.0 + (randf() - 0.5) * (1.0 - skill) * 14.0


func _exec(dist: float, fwd: String, back: String) -> void:
	var inp: Dictionary = me.input
	match plan:
		"block":
			_set_line(plan_line)
			inp["block"] = true
		"parry":
			_set_line(plan_line)
			inp["block"] = op.remaining_startup() <= parry_lead
		"evade":
			if me.is_free() and me.stamina >= 12.0:
				inp[back] = true
				me.press("dash")
			plan = "block"
		"interrupt":
			if dist < _reach() - 5.0 and me.is_free():
				_set_line(randi() % 3)
				me.press("light")
			plan = "block"


func _set_line(l: int) -> void:
	me.input["up"] = l == Fighter.HIGH
	me.input["down"] = l == Fighter.LOW
