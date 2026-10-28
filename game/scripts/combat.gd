class_name Combat
extends RefCounted
## Resolves blades against bodies and against each other, using the real swept blade geometry.


static func is_active(f: Fighter) -> bool:
	return f.state == "attack" and f.phase == "active" and not f.hit_done


## The cutting part of the blade, interpolated through the swing between last frame and this one.
static func swept_blade(f: Fighter, k: float) -> Array:
	var base: Vector2 = f.prev_base.lerp(f.rig.blade_base, k)
	var dir: Vector2 = f.prev_dir.slerp(f.rig.sword_dir, k)
	var l: float = lerpf(f.prev_len, f.rig.blade_base.distance_to(f.rig.blade_tip), k)
	return [base + dir * l * 0.12, base + dir * l]


static func step(a: Fighter, b: Fighter, ev: Array) -> void:
	if is_active(a) and is_active(b) and a.move_name != "kick" and b.move_name != "kick":
		for s in range(1, 5):
			var sa: Array = swept_blade(a, s / 4.0)
			var sb: Array = swept_blade(b, s / 4.0)
			var r: Array = U.seg_seg(sa[0], sa[1], sb[0], sb[1])
			if r[0] < 7.0:
				_clash(a, b, (r[1] + r[2]) * 0.5, ev)
				return
	_strike(a, b, ev)
	_strike(b, a, ev)


static func _probe(def: Fighter, seg: Array, pad: float) -> Dictionary:
	var best := {}
	var best_pen := 0.0
	for hb: Array in def.rig.hurtboxes():
		var r: Array = U.seg_seg(seg[0], seg[1], hb[1], hb[2])
		var pen: float = float(hb[3]) + pad - float(r[0])
		if pen > best_pen:
			best_pen = pen
			best = {"part": hb[0], "point": r[2]}
	return best


static func _strike(att: Fighter, def: Fighter, ev: Array) -> void:
	if not is_active(att) or def.state == "dead" or def.state == "dying":
		return
	var hit := {}
	if att.move_name == "kick":
		hit = _probe(def, [att.rig.kn_f, att.rig.ft_f], 9.0)
	else:
		for s in range(1, 5):
			hit = _probe(def, swept_blade(att, s / 4.0), 1.5)
			if not hit.is_empty():
				break
	if hit.is_empty():
		return
	att.hit_done = true
	var mv: Dictionary = att.move
	var point: Vector2 = hit["point"]
	var heavy: bool = att.move_name == "heavy"

	if att.move_name == "kick":
		var guarded: bool = def.state == "block" or def.state == "blockstun"
		var broke: bool = _add_posture(def, float(mv["posture"]) * (1.4 if guarded else 1.0), ev)
		if not broke:
			def.enter("kicked")
			def.stun_len = 26.0
		def.vx = att.facing * 8.0
		if def.lethal:
			def.hp -= float(mv["dmg"])
		def.rig.kick("lean", -5.0)
		ev.append({"t": "kick", "pos": point, "dir": att.facing})
		return

	var guarding: bool = def.state == "block" or def.state == "blockstun"
	if guarding and def.facing == -att.facing and def.line == att.attack_line:
		var contact: Vector2 = _blade_point(att, def, point)
		if def.state == "block" and def.parry_ok and def.block_t <= Fighter.PARRY_WINDOW:
			att.enter("recoil")
			att.stun_len = 50.0 if heavy else 42.0
			att.vx = -att.facing * 4.0
			_add_posture(att, 24.0, ev)
			def.enter("deflect")
			def.stun_len = 8.0
			def.posture = maxf(0.0, def.posture - 10.0)
			att.rig.kick("sa", -14.0)
			att.rig.kick("lean", -4.0)
			ev.append({"t": "parry", "pos": contact, "by": def.id})
			return
		var pd: float = float(mv["posture"]) * (1.0 + att.charge / Fighter.MAX_CHARGE * 0.7) * (1.3 if def.exhausted else 1.0)
		def.vx = att.facing * (6.0 if heavy else 3.5)
		att.vx -= att.facing * 1.0
		ev.append({"t": "block", "pos": contact, "heavy": heavy})
		if not _add_posture(def, pd, ev):
			def.enter("blockstun")
			def.stun_len = 9.0 + pd * 0.15
			def.rig.kick("hx", -120.0)
			def.rig.kick("py", 60.0)
		return

	var part: String = hit["part"]
	var mult: float = {"head": 1.5, "torso": 1.0, "arm": 0.6, "leg": 0.75}[part]
	var dmg: float = float(mv["dmg"]) * mult * (1.0 + att.charge / Fighter.MAX_CHARGE * 0.45)
	if def.state == "broken":
		dmg *= 1.5
	var counter: bool = def.state == "attack" and def.phase == "startup"
	if counter:
		dmg *= 1.25
	if def.lethal:
		def.hp -= dmg
	def.vx = att.facing * (5.0 + dmg * 0.12)
	if part == "leg":
		def.limp = 150.0
	var dir: float = att.facing
	if def.hp <= 0.0:
		def.hp = 0.0
		def.enter("dying")
		def.rig.kick("lean", 3.0)
		def.rig.kick("py", 80.0)
		ev.append({"t": "ko", "pos": point, "dir": dir, "victim": def.id, "dmg": dmg})
		return
	def.enter("hurt")
	def.stun_len = 14.0 + dmg * 0.55
	_react(def, part, dir)
	ev.append({"t": "hit", "pos": point, "dir": dir, "part": part, "dmg": dmg, "heavy": heavy,
		"counter": counter, "victim": def.id})


## Part-specific flinch: impulses go straight into the pose springs.
static func _react(f: Fighter, part: String, dir: float) -> void:
	match part:
		"head":
			f.rig.kick("ht", -14.0)
			f.rig.kick("lean", -7.0)
		"torso":
			f.rig.kick("lean", 6.0)
			f.rig.kick("py", 130.0)
			f.rig.kick("hy", 160.0)
		"leg":
			f.rig.kick("py", 220.0)
			f.rig.kick("lean", 3.0)
		_:
			f.rig.kick("sa", 9.0)
			f.rig.kick("hy", 220.0)
	f.rig.kick("px", -dir * f.facing * 60.0)


static func _add_posture(f: Fighter, amount: float, ev: Array) -> bool:
	f.posture += amount
	f.posture_delay = 70.0
	if f.posture >= 100.0:
		f.posture = 100.0
		f.enter("broken")
		f.stun_len = 80.0
		f.vx *= 0.5
		ev.append({"t": "break", "pos": f.rig.chest, "victim": f.id})
		return true
	return false


static func _blade_point(att: Fighter, def: Fighter, fallback: Vector2) -> Vector2:
	var r: Array = U.seg_seg(att.rig.blade_base, att.rig.blade_tip, def.rig.blade_base, def.rig.blade_tip)
	return (r[1] + r[2]) * 0.5 if float(r[0]) < 60.0 else fallback


static func _clash(a: Fighter, b: Fighter, pt: Vector2, ev: Array) -> void:
	for f: Fighter in [a, b]:
		f.hit_done = true
		f.enter("recoil")
		f.stun_len = 22.0
		f.vx = -f.facing * 6.0
		f.rig.kick("sa", -10.0)
	ev.append({"t": "clash", "pos": pt})
