class_name Rig
extends RefCounted
## Procedural skeleton for one fighter.
##
## Gameplay sets pose *targets*; every parameter chases its target through a damped spring,
## which gives anticipation, follow-through and settle for free. Arms and legs are solved with
## two-bone IK, feet stay planted and roll from heel to toe, loose hair, sashes and skirts are
## verlet cloth, and on death the body becomes a ragdoll.
##
## One world unit is one centimetre: k = 1 is a 180 cm adult with real limb proportions, and
## the silhouette is built from side-view anatomy (see "shapes" at the bottom of this file), and
## `apply_build` sizes it for each fighter.

const THIGH := 46.0
const SHIN := 44.0
const ANKLE := 7.5
const FOOT_BALL := 13.0
const UPPER := 33.0
const FORE := 31.0
const SPINE := 52.0
const NECK := 11.0
const HEAD_R := 12.0
const HIP_H := 96.0
const GRIP := 22.0

## px/py: pelvis offset, lean: spine angle, hx/hy: lead hand relative to chest, sa: sword angle,
## bl: blade length scale, fs: foreshortening (blade turning toward the camera), ht: head tilt,
## ff/bf: front/back foot stance, kw/kx/ky: kick blend and foot target, tw: charge tremble,
## kp: ankle of the kicking foot relative to the shin (0 = square, 1.5 = pointed, negative = heel first),
## kt: toes of the kicking foot (negative pulls them back), sh: heel lift of the standing foot,
## sv: pivot of the standing foot on its ball, rh: free hand off the hilt and chambered at the ribs,
## air: the whole body off the floor, tk/tx/ty: blend and target for tucking the other leg up in the air.
const KEYS := ["px", "py", "lean", "hx", "hy", "sa", "bl", "fs", "ht", "ff", "bf", "kw", "kx", "ky", "tw",
	"kp", "kt", "sh", "sv", "rh", "air", "tk", "tx", "ty"]
const DEFAULT := {"px": 0.0, "py": 3.0, "lean": 0.03, "hx": 34.0, "hy": 40.0, "sa": -0.42, "bl": 1.0,
	"fs": 0.0, "ht": 0.0, "ff": 22.0, "bf": -28.0, "kw": 0.0, "kx": 0.0, "ky": 0.0, "tw": 0.0,
	"kp": 0.1, "kt": 0.0, "sh": 0.0, "sv": 0.0, "rh": 0.0, "air": 0.0, "tk": 0.0, "tx": 0.0, "ty": 0.0}

var p := {}
var v := {}
var tg := {}
var w := {}
var z := {}

var facing := 1.0
var root_x := 0.0
var ground := 0.0
var time := 0.0
var wind := 0.0
var water := false

## The build: `k` scales the whole skeleton (1 = 180 cm), so reach and pose follow the fighter's size.
var build: Dictionary = {}
var k := 1.0
var head_k := 1.0
var blade_len := 118.0
var blade_w := 1.0
var sori := 5.0
var hurt_r := 14.0
var lods: Dictionary = {}
## Leg bones at this build's proportions, before `k`.
var thigh := THIGH
var shin := SHIN
var hip_h := HIP_H
## Which leg the kick pose drives: 0 = front, 1 = rear.
var kick_leg := 0

var step_events := 0
## The foot that moved last: footwork takes turns, so one foot never skates past the other.
var last_step := 1

var pelvis := Vector2.ZERO
var chest := Vector2.ZERO
var neck := Vector2.ZERO
var head := Vector2.ZERO
var sh_f := Vector2.ZERO
var sh_b := Vector2.ZERO
var el_f := Vector2.ZERO
var el_b := Vector2.ZERO
var hand_f := Vector2.ZERO
var hand_b := Vector2.ZERO
var hip_f := Vector2.ZERO
var hip_b := Vector2.ZERO
var kn_f := Vector2.ZERO
var kn_b := Vector2.ZERO
var ft_f := Vector2.ZERO
var ft_b := Vector2.ZERO
var sword_dir := Vector2.RIGHT
var blade_base := Vector2.ZERO
var blade_tip := Vector2.ZERO
var pommel := Vector2.ZERO
var spine_ang := 0.0
var head_ang := 0.0
## Foot rotation: positive lifts the heel, negative lifts the toes.
var pitch_f := 0.0
var pitch_b := 0.0
var holding := true
## False while the rear hand cannot reach the hilt: it lets go and opens.
var rear_grip := true

var feet: Array = []

var chains := {}

var ragdoll := false
var rd_pos := PackedVector2Array()
var rd_vel := PackedVector2Array()
var rd_cons: Array = []
var sw_pos := PackedVector2Array()
var sw_vel := PackedVector2Array()


func _init() -> void:
	for k in KEYS:
		p[k] = DEFAULT[k]
		v[k] = 0.0
		tg[k] = DEFAULT[k]
		w[k] = 12.0
		z[k] = 1.0


func apply_build(b: Dictionary) -> void:
	build = b
	k = b["scale"]
	head_k = float(b["head"]) * k
	blade_len = b["blade"]
	blade_w = b["blade_w"]
	sori = b["sori"]
	hurt_r = b["hurt"]
	var leg: float = b.get("leg", 1.0)
	thigh = THIGH * leg
	shin = SHIN * leg
	hip_h = HIP_H * leg
	lods = _lods_for(b)


func reset(x: float, gy: float, face: float) -> void:
	root_x = x
	ground = gy
	facing = face
	ragdoll = false
	holding = true
	kick_leg = 0
	time = randf() * 100.0
	for k in KEYS:
		p[k] = DEFAULT[k]
		v[k] = 0.0
		tg[k] = DEFAULT[k]
	feet = [_foot_state(x + face * float(DEFAULT["ff"]) * k), _foot_state(x + face * float(DEFAULT["bf"]) * k)]
	_solve_pose()
	_init_cloth()
	for i in 120:
		_cloth_step(1.0)


func _foot_state(x: float) -> Dictionary:
	return {"x": x, "from": x, "to": x, "t": 0.0, "stepping": false, "dur": 8.0, "h": 6.0, "lift": 0.0}


## Sets every pose target (missing keys fall back to the neutral stance) and the spring feel.
func set_pose(target: Dictionary, stiff: float, damp: float = 1.0) -> void:
	for k in KEYS:
		tg[k] = target.get(k, DEFAULT[k])
		w[k] = stiff
		z[k] = damp


func kick(k: String, amount: float) -> void:
	v[k] = float(v[k]) + amount


func update(ts: float, vel_x: float) -> void:
	if ts <= 0.0:
		return
	time += ts
	if ragdoll:
		_ragdoll_step(ts)
	else:
		_springs(ts)
		_update_feet(ts, vel_x)
		_solve_pose()
	_cloth_step(ts)


func _springs(ts: float) -> void:
	var h: float = ts / 60.0 / 2.0
	for k in KEYS:
		var x: float = p[k]
		var vv: float = v[k]
		var ww: float = w[k]
		var zz: float = z[k]
		var t: float = tg[k]
		for i in 2:
			vv += (ww * ww * (t - x) - 2.0 * zz * ww * vv) * h
			x += vv * h
		p[k] = x
		v[k] = vv


## Sword footwork: the foot nearest the direction of travel steps first and the other closes up
## behind it, gliding low. Feet never cross, and they take turns unless the body is dashing.
func _update_feet(ts: float, vel_x: float) -> void:
	var fast: bool = absf(vel_x) > 6.0
	var moving: bool = absf(vel_x) > 0.6
	var lead: int = 0 if vel_x * facing >= 0.0 else 1
	for n in 2:
		var i: int = lead if n == 0 else 1 - lead
		var ft: Dictionary = feet[i]
		var off: float = p["ff"] if i == 0 else p["bf"]
		var desired: float = root_x + facing * off * k
		# in the air the feet travel with the body and land where it lands
		if float(p["air"]) > 2.0:
			ft["x"] = desired
			ft["stepping"] = false
			ft["lift"] = 0.0
			continue
		if ft["stepping"]:
			ft["t"] = minf(1.0, float(ft["t"]) + ts / float(ft["dur"]))
			var t: float = ft["t"]
			var e: float = t * t * (3.0 - 2.0 * t)
			ft["x"] = lerpf(ft["from"], ft["to"], e)
			ft["lift"] = sin(PI * t) * float(ft["h"])
			if t >= 1.0:
				ft["stepping"] = false
				ft["lift"] = 0.0
				step_events += 1
		else:
			var other: Dictionary = feet[1 - i]
			var lag: float = absf(float(ft["x"]) - desired)
			var ready: bool = fast or (not other["stepping"] and (not moving or last_step != i or lag > 30.0))
			if lag > (4.0 if moving else 9.0) and ready:
				var dur: float = 5.0 if fast else 8.0
				ft["stepping"] = true
				ft["t"] = 0.0
				ft["from"] = ft["x"]
				ft["to"] = desired + clampf(vel_x * dur * 1.4, -60.0, 60.0)
				ft["dur"] = dur
				ft["h"] = clampf(2.5 + absf(float(ft["to"]) - float(ft["from"])) * 0.09, 2.5, 9.0)
				last_step = i


func _solve_pose() -> void:
	var f := facing
	# nobody stands perfectly still: slow breathing, and the weight drifting between the feet
	var settle: float = clampf(1.0 - absf(float(p["kw"])) * 2.0 - float(p["air"]) * 0.2, 0.0, 1.0)
	var breath: float = sin(time * 0.045) * settle
	var drift: float = sin(time * 0.019) * settle
	var bob := 0.0
	for ft: Dictionary in feet:
		bob = maxf(bob, ft["lift"])
	pelvis = Vector2(root_x + f * (float(p["px"]) + drift * 1.4) * k, ground + (float(p["py"]) - hip_h - float(p["air"]) + breath * 0.3) * k - bob * 0.3)
	# on one leg the hips stack over the standing foot; only a jump is free of it
	var balance: float = clampf(p["kw"], 0.0, 1.0) * clampf(1.0 - float(p["air"]) / 30.0, 0.0, 1.0) * 0.85
	if balance > 0.001:
		pelvis.x = lerpf(pelvis.x, float(feet[1 - kick_leg]["x"]) + f * 3.0 * k, balance)
	# wide stances drop the hips so the legs can still reach the ground
	var tf: Vector2 = _plant(0)
	var tb: Vector2 = _plant(1)
	var kw: float = clampf(p["kw"], 0.0, 1.0)
	for i in 2:
		# a leg that is off the floor does not hold the hips down
		if i == kick_leg and kw > 0.35:
			continue
		var t_foot: Vector2 = tf if i == 0 else tb
		var hip_x: float = pelvis.x + (f * 4.0 if i == 0 else -f * 4.0) * k
		var dx: float = t_foot.x - hip_x
		var reach: float = (thigh + shin - 1.5) * k
		if absf(dx) < reach:
			pelvis.y = maxf(pelvis.y, t_foot.y - sqrt(reach * reach - dx * dx))
	var lean: float = p["lean"]
	spine_ang = lean * f
	chest = pelvis + Vector2(0, -SPINE * k).rotated(spine_ang) + Vector2(0, breath * 0.7)
	neck = chest + Vector2(0, -NECK * k).rotated(spine_ang * 0.6)
	head_ang = (lean * 0.4 + float(p["ht"])) * f
	head = neck + Vector2(0, -HEAD_R * head_k - 1.5).rotated(head_ang)
	sh_f = chest + Vector2(f * 3.0, 0.0).rotated(spine_ang) * k
	sh_b = chest + Vector2(-f * 4.0, 2.0).rotated(spine_ang) * k

	var reach_arm: float = (UPPER + FORE - 0.5) * k
	var target: Vector2 = chest + Vector2(f * float(p["hx"]), float(p["hy"])) * k
	# the shoulder girdle follows the arm instead of staying bolted to the ribs
	sh_f += (target - sh_f).normalized() * 3.0
	var dv: Vector2 = target - sh_f
	if dv.length() > reach_arm:
		target = sh_f + dv.normalized() * reach_arm
	var sa: float = float(p["sa"]) + sin(time * 0.031) * 0.012 * settle
	if float(p["tw"]) > 0.01:
		sa += sin(time * 2.3) * 0.025 * float(p["tw"])
	sword_dir = Vector2(cos(sa) * f, sin(sa))
	hand_f = target
	hand_b = hand_f - sword_dir * 11.0 * k
	sh_b += (hand_b - sh_b).normalized() * 2.0
	var dv2: Vector2 = hand_b - sh_b
	var gap: float = dv2.length() - reach_arm
	if gap > 0.0:
		hand_b = sh_b + dv2.normalized() * reach_arm
	# past arm's reach the rear hand releases the hilt and drops for balance instead of floating beside it
	var release: float = clampf(gap / 8.0, 0.0, 1.0)
	hand_b = hand_b.lerp(sh_b + Vector2(-f * 14.0, 50.0) * k, release)
	rear_grip = release < 0.5
	# in a kick the free hand pulls back to the ribs, karate's hikite
	var rh: float = clampf(p["rh"], 0.0, 1.0)
	if rh > 0.01:
		hand_b = hand_b.lerp(chest + Vector2(f * 6.0, 32.0).rotated(spine_ang) * k, rh)
		rear_grip = rear_grip and rh < 0.5
	# elbows fold down and back, the way a human arm holds a sword
	el_f = U.ik(sh_f, hand_f, UPPER * k, FORE * k, -f)
	el_b = U.ik(sh_b, hand_b, UPPER * k, FORE * k, -f)
	var fore_len: float = lerpf(1.0, 0.3 + 0.7 * absf(cos(sa)), clampf(p["fs"], 0.0, 1.0))
	blade_base = hand_f + sword_dir * 6.0
	blade_tip = blade_base + sword_dir * blade_len * float(p["bl"]) * fore_len
	pommel = hand_f - sword_dir * GRIP * k

	hip_f = pelvis + Vector2(f * 4.0 * k, 0)
	hip_b = pelvis + Vector2(-f * 4.0 * k, 0)
	if kw > 0.01:
		var aim: Vector2 = pelvis + Vector2(f * float(p["kx"]), -float(p["ky"])) * k
		if kick_leg == 0:
			tf = tf.lerp(aim, kw)
		else:
			tb = tb.lerp(aim, kw)
	var tk: float = clampf(p["tk"], 0.0, 1.0)
	if tk > 0.01:
		var tuck: Vector2 = pelvis + Vector2(f * float(p["tx"]), -float(p["ty"])) * k
		if kick_leg == 0:
			tb = tb.lerp(tuck, tk)
		else:
			tf = tf.lerp(tuck, tk)
	kn_f = U.ik(hip_f, tf, thigh * k, shin * k, f)
	ft_f = kn_f + (tf - kn_f).normalized() * shin * k
	kn_b = U.ik(hip_b, tb, thigh * k, shin * k, f)
	ft_b = kn_b + (tb - kn_b).normalized() * shin * k
	if kw > 0.01:
		if kick_leg == 0:
			pitch_f = lerpf(pitch_f, _ankle_pitch(kn_f, ft_f), kw)
		else:
			pitch_b = lerpf(pitch_b, _ankle_pitch(kn_b, ft_b), kw)
	if tk > 0.01:
		# a tucked foot hangs pointed from its shin
		if kick_leg == 0:
			pitch_b = lerpf(pitch_b, 0.9 - atan2((ft_b - kn_b).x * f, (ft_b - kn_b).y), tk)
		else:
			pitch_f = lerpf(pitch_f, 0.9 - atan2((ft_f - kn_f).x * f, (ft_f - kn_f).y), tk)


## Foot rotation of the kicking leg: the ankle angle is held relative to the shin, so a pointed
## instep or a pulled-back ball of the foot stays that way wherever the shin is aimed.
func _ankle_pitch(knee: Vector2, ankle: Vector2) -> float:
	var d: Vector2 = ankle - knee
	return float(p["kp"]) - atan2(d.x * facing, d.y)


## The striking part of the kicking leg, for hit detection.
func kick_seg() -> Array:
	return [kn_f, ft_f] if kick_leg == 0 else [kn_b, ft_b]


func _kicking(i: int) -> bool:
	return not ragdoll and i == kick_leg and float(p["kw"]) > 0.25


## Ankle target for a foot. The ball of the foot stays on the floor while the heel lifts, either
## because the foot trails behind the hips or because it is rolling through a step.
func _plant(i: int) -> Vector2:
	var ft: Dictionary = feet[i]
	var fx: float = ft["x"]
	var pitch: float = clampf(((pelvis.x - fx) * facing - 32.0) / 40.0, 0.0, 0.75)
	if ft["stepping"]:
		var t: float = ft["t"]
		pitch = pitch * (1.0 - sin(PI * t)) + sin(TAU * t) * 0.25
	# the standing foot rises onto its ball as the kick goes out
	if i != kick_leg and float(p["kw"]) > 0.01:
		pitch = maxf(pitch, float(p["sh"]))
	if i == 0:
		pitch_f = pitch
	else:
		pitch_b = pitch
	var ball := Vector2(fx + facing * FOOT_BALL * k, ground - float(ft["lift"]) - float(p["air"]) * k)
	return ball - Vector2(facing * FOOT_BALL, ANKLE).rotated(pitch * facing) * k


func hurtboxes() -> Array:
	return [["head", head, head, HEAD_R * head_k + 1.0], ["torso", pelvis, neck, hurt_r],
		["arm", sh_f, el_f, 6.0], ["arm", el_f, hand_f, 6.0],
		["leg", hip_f, kn_f, 10.0], ["leg", kn_f, ft_f, 8.0],
		["leg", hip_b, kn_b, 10.0], ["leg", kn_b, ft_b, 8.0]]


# ---------------------------------------------------------------- cloth

func _init_cloth() -> void:
	chains = {}
	for c: Array in build.get("cloth", []):
		var chain: Dictionary = _chain(_anchor(c[1]), c[2], float(c[3]) * k, c[4], c[5], c[6])
		chain["anchor"] = c[1]
		chain["r0"] = float(c[7]) * k
		chain["r1"] = float(c[8]) * k
		chain["layer"] = c[9]
		# optional: bends the tip of a lock forward (+) or back (-), so loose hair does not hang in a comb
		chain["curl"] = float(c[10]) * k if c.size() > 10 else 0.0
		chains[c[0]] = chain


## `bias` pushes the chain along the fighter's facing, strongest at the root, so hair and cloth arc
## away from the body and then hang.
func _chain(anchor: Vector2, n: int, seg: float, wf: float, grav: float, bias: float) -> Dictionary:
	var pos := PackedVector2Array()
	var vel := PackedVector2Array()
	for i in n:
		pos.append(anchor + Vector2(0, seg * (i + 1)))
		vel.append(Vector2.ZERO)
	return {"pos": pos, "vel": vel, "seg": seg, "wf": wf, "grav": grav, "bias": bias}


func _anchor(kind: String) -> Vector2:
	match kind:
		"crown":
			return head + Vector2(-facing * 8.0, -9.0).rotated(head_ang) * head_k
		"crown2":
			return head + Vector2(-facing * 10.0, -4.0).rotated(head_ang) * head_k
		"temple":
			return head + Vector2(facing * 5.0, -8.0).rotated(head_ang) * head_k
		"shoulder":
			return chest + Vector2(-facing * 9.0, 0.0).rotated(spine_ang) * k
		"h_back":
			return head + Vector2(-facing * 9.6, 3.5).rotated(head_ang) * head_k
		"h_mid":
			return head + Vector2(-facing * 7.0, 5.0).rotated(head_ang) * head_k
		"h_nape":
			return head + Vector2(-facing * 4.0, 5.5).rotated(head_ang) * head_k
		"hip_f":
			return pelvis + Vector2(facing * 8.0, -5.0).rotated(spine_ang) * k
		"hip_m":
			return pelvis + Vector2(0.0, -5.0).rotated(spine_ang) * k
		"waist":
			return pelvis.lerp(chest, 0.17) + Vector2(-facing * 9.0, 0.0).rotated(spine_ang) * k
	return pelvis + Vector2(-facing * 9.0, -6.0).rotated(spine_ang) * k


func _cloth_step(ts: float) -> void:
	var gust: float = wind * (0.6 + 0.4 * sin(time * 0.031) * sin(time * 0.017 + 1.3))
	for key: String in chains:
		var c: Dictionary = chains[key]
		_chain_step(c, _anchor(c["anchor"]), ts, gust)


func _chain_step(c: Dictionary, anchor: Vector2, ts: float, gust: float) -> void:
	var pos: PackedVector2Array = c["pos"]
	var vel: PackedVector2Array = c["vel"]
	var seg: float = c["seg"]
	var wf: float = c["wf"]
	var grav: float = float(c["grav"]) * (0.3 if water else 1.0)
	var bias: float = float(c["bias"]) * facing * (0.3 if water else 1.0)
	var prev: PackedVector2Array = pos.duplicate()
	var drag: float = pow(0.9 if water else 0.95, ts)
	for i in pos.size():
		vel[i] = vel[i] * drag + Vector2(gust * 0.06 * wf + bias * (1.0 - float(i) / pos.size()), grav) * ts
		pos[i] += vel[i] * ts
	for it in 2:
		var a: Vector2 = anchor
		for i in pos.size():
			var q: Vector2 = pos[i]
			var d: Vector2 = q - a
			var l: float = d.length()
			if l > 0.0001:
				q = a + d / l * seg
			if q.y > ground - 1.0:
				q.y = ground - 1.0
			pos[i] = q
			a = q
	var inv: float = 1.0 / ts
	for i in pos.size():
		vel[i] = (pos[i] - prev[i]) * inv * 0.98
	c["pos"] = pos
	c["vel"] = vel


# ---------------------------------------------------------------- ragdoll

func go_ragdoll(impulse: Vector2) -> void:
	ragdoll = true
	holding = false
	rd_pos = PackedVector2Array([pelvis, chest, head, el_f, hand_f, el_b, hand_b, kn_f, ft_f, kn_b, ft_b])
	rd_vel = PackedVector2Array()
	for i in rd_pos.size():
		var up: float = clampf((ground - rd_pos[i].y) / 200.0, 0.0, 1.0)
		rd_vel.append(impulse * (0.4 + 0.9 * up) + Vector2(randf_range(-0.4, 0.4), randf_range(-0.4, 0.1)))
	rd_cons = []
	for pair: Array in [[0, 1], [1, 2], [0, 2], [1, 3], [3, 4], [1, 5], [5, 6], [0, 7], [7, 8], [0, 9], [9, 10], [3, 5]]:
		rd_cons.append([pair[0], pair[1], rd_pos[pair[0]].distance_to(rd_pos[pair[1]]), false])
	for c: Array in [[0, 8, 46.0], [0, 10, 46.0], [1, 4, 22.0], [1, 6, 22.0], [7, 9, 8.0], [2, 7, 70.0], [2, 9, 70.0], [1, 8, 60.0]]:
		rd_cons.append([c[0], c[1], c[2], true])
	sw_pos = PackedVector2Array([pommel, blade_tip])
	var spin: float = randf_range(-8.0, 8.0)
	sw_vel = PackedVector2Array([impulse * 0.5 + Vector2(0, -3.0), impulse * 0.5 + Vector2(spin, -5.0)])


func _ragdoll_step(ts: float) -> void:
	var prev: PackedVector2Array = rd_pos.duplicate()
	var drag: float = pow(0.95 if water else 0.985, ts)
	var g: float = 0.11 if water else 0.42
	for i in rd_pos.size():
		rd_vel[i] = rd_vel[i] * drag + Vector2(0, g) * ts
		rd_pos[i] += rd_vel[i] * ts
	for it in 8:
		for c: Array in rd_cons:
			var a: int = c[0]
			var b: int = c[1]
			var rest: float = c[2]
			var d: Vector2 = rd_pos[b] - rd_pos[a]
			var l: float = d.length()
			if l < 0.0001 or (c[3] and l >= rest):
				continue
			var corr: Vector2 = d * (1.0 - rest / l) * 0.5
			rd_pos[a] += corr
			rd_pos[b] -= corr
		for i in rd_pos.size():
			var r: float = HEAD_R * head_k if i == 2 else (ANKLE * k if i == 8 or i == 10 else 5.0)
			var q: Vector2 = rd_pos[i]
			if q.y > ground - r:
				q.y = ground - r
				q.x = lerpf(q.x, prev[i].x, 0.35)
			rd_pos[i] = q
	for i in rd_pos.size():
		rd_vel[i] = (rd_pos[i] - prev[i]) / ts
	pelvis = rd_pos[0]
	chest = rd_pos[1]
	head = rd_pos[2]
	el_f = rd_pos[3]
	hand_f = rd_pos[4]
	el_b = rd_pos[5]
	hand_b = rd_pos[6]
	kn_f = rd_pos[7]
	ft_f = rd_pos[8]
	kn_b = rd_pos[9]
	ft_b = rd_pos[10]
	spine_ang = (chest - pelvis).angle() + PI * 0.5
	neck = chest.lerp(head, 0.3)
	sh_f = chest + Vector2(facing * 3.0, 3.0).rotated(spine_ang) * k
	sh_b = chest + Vector2(-facing * 5.0, 5.0).rotated(spine_ang) * k
	hip_f = pelvis
	hip_b = pelvis
	head_ang = (head - chest).angle() + PI * 0.5
	pitch_f = _limp_pitch(kn_f, ft_f)
	pitch_b = _limp_pitch(kn_b, ft_b)
	_sword_step(ts)


## A limp foot hangs off the shin, toes relaxed downward.
func _limp_pitch(knee: Vector2, ankle: Vector2) -> float:
	return wrapf(((ankle - knee).angle() - PI * 0.5) * facing + 0.5, -PI, PI)


func _sword_step(ts: float) -> void:
	var prev: PackedVector2Array = sw_pos.duplicate()
	var length: float = GRIP * k + 6.0 + blade_len
	for i in 2:
		sw_vel[i] = sw_vel[i] * pow(0.95 if water else 0.99, ts) + Vector2(0, 0.13 if water else 0.45) * ts
		sw_pos[i] += sw_vel[i] * ts
	for it in 4:
		var d: Vector2 = sw_pos[1] - sw_pos[0]
		var l: float = d.length()
		if l > 0.0001:
			var corr: Vector2 = d * (1.0 - length / l) * 0.5
			sw_pos[0] += corr
			sw_pos[1] -= corr
		for i in 2:
			var q: Vector2 = sw_pos[i]
			if q.y > ground - 2.0:
				q.y = ground - 2.0
				q.x = lerpf(q.x, prev[i].x, 0.5)
			sw_pos[i] = q
	for i in 2:
		sw_vel[i] = (sw_pos[i] - prev[i]) / ts
	pommel = sw_pos[0]
	blade_tip = sw_pos[1]
	sword_dir = (blade_tip - pommel).normalized()
	blade_base = pommel + sword_dir * (GRIP * k + 6.0)


# ---------------------------------------------------------------- shapes

## Side-view anatomy in centimetres at k = 1. Limb rows are Vector3(position along the bone 0..1,
## depth in front of the bone, depth behind it); torso rows use cm up the spine for the first value.
const ANATOMY := {
	# fit and strong, at the depths a real athlete measures from the side
	"woman": {
		"thigh": [Vector3(0, 9.5, 10.5), Vector3(0.2, 10, 10), Vector3(0.5, 8.6, 8), Vector3(0.8, 6.2, 5.6), Vector3(1, 5.3, 4.9)],
		"shin": [Vector3(0, 5.3, 4.9), Vector3(0.12, 4.8, 5.8), Vector3(0.3, 4.2, 6.8), Vector3(0.55, 3.4, 4.8), Vector3(0.82, 2.6, 2.9), Vector3(1, 2.7, 2.8)],
		"upper": [Vector3(0, 6.2, 6), Vector3(0.14, 6.8, 6.2), Vector3(0.35, 5.6, 5), Vector3(0.55, 5.6, 4.8), Vector3(0.8, 4.2, 3.9), Vector3(1, 3.6, 3.4)],
		"fore": [Vector3(0, 3.6, 3.4), Vector3(0.22, 4.6, 4.4), Vector3(0.6, 3.3, 3.2), Vector3(0.88, 2.4, 2.4), Vector3(1, 2.3, 2.3)],
		"neck": [Vector3(0, 4.8, 5.8), Vector3(0.5, 4.2, 5), Vector3(1, 4.2, 4.6)],
		"torso": [Vector3(-9, 6, 7.5), Vector3(0, 9, 12), Vector3(9, 9, 11.5), Vector3(20, 8.2, 8.2), Vector3(31, 9, 8.8),
			Vector3(39, 11.2, 10.5), Vector3(46, 11.2, 11.5), Vector3(53, 9.2, 11.5), Vector3(58, 6.8, 9), Vector3(61, 5.4, 6.8), Vector3(64, 4.8, 5.8)],
		"head": [Vector2(-1, -12.8), Vector2(4, -12), Vector2(7.2, -8.6), Vector2(7.9, -5.2), Vector2(7.5, -3), Vector2(7.7, -1.5), Vector2(8.7, 0.4),
			Vector2(9.2, 1), Vector2(8.7, 1.9), Vector2(7.7, 2.4), Vector2(8, 3.4), Vector2(7.6, 4.4), Vector2(8, 5.3), Vector2(7.3, 6.4), Vector2(7.4, 7.6),
			Vector2(6.6, 9), Vector2(4.6, 9.8), Vector2(1.5, 9), Vector2(-2, 8), Vector2(-5, 6.4), Vector2(-9.6, 3), Vector2(-11.6, -2.8), Vector2(-10, -9), Vector2(-5.6, -12.3)],
		"hip_r": 10.0, "knee_r": 5.0, "shoulder_r": 6.6, "elbow_r": 3.6,
	},
	"man": {
		"thigh": [Vector3(0, 9.6, 10.4), Vector3(0.22, 9.8, 9.6), Vector3(0.55, 8.6, 8.2), Vector3(0.85, 6.4, 6), Vector3(1, 6, 5.6)],
		"shin": [Vector3(0, 6, 5.6), Vector3(0.12, 5.4, 7), Vector3(0.32, 4.8, 7.8), Vector3(0.6, 3.8, 5.4), Vector3(0.85, 3.2, 3.6), Vector3(1, 3.3, 3.4)],
		"upper": [Vector3(0, 6.6, 6.4), Vector3(0.18, 6.4, 5.8), Vector3(0.5, 5.8, 5), Vector3(0.85, 4.4, 4.4), Vector3(1, 4.1, 4.1)],
		"fore": [Vector3(0, 4.1, 4.1), Vector3(0.25, 5, 4.8), Vector3(0.6, 3.9, 3.7), Vector3(0.88, 2.9, 2.9), Vector3(1, 2.8, 2.8)],
		"neck": [Vector3(0, 5.6, 6.6), Vector3(0.5, 5, 5.8), Vector3(1, 4.8, 5.2)],
		"torso": [Vector3(-9, 6, 7), Vector3(0, 9.5, 11), Vector3(12, 9.8, 9.8), Vector3(22, 10.4, 9.4), Vector3(36, 12.4, 11),
			Vector3(46, 12.8, 12.2), Vector3(53, 10.5, 12), Vector3(58, 7.8, 10), Vector3(61, 6, 7.6), Vector3(64, 5.4, 6.4)],
		"head": [Vector2(-1, -12.6), Vector2(4, -12), Vector2(7.4, -8.8), Vector2(8.8, -5), Vector2(8.4, -3), Vector2(11.2, 1.6), Vector2(9, 2.9),
			Vector2(9.2, 4.4), Vector2(8.6, 5.2), Vector2(8.8, 6.2), Vector2(8.2, 7.6), Vector2(9, 9.8), Vector2(7, 12), Vector2(2, 10.2),
			Vector2(-2, 8.4), Vector2(-5.4, 6.4), Vector2(-9.6, 3), Vector2(-11, -2.8), Vector2(-9.6, -8.8), Vector2(-5.4, -12)],
		"hip_r": 10.0, "knee_r": 6.0, "shoulder_r": 6.8, "elbow_r": 4.2,
	},
}
## Outlines facing +x, y down. FOOT is centred on the ankle: instep, toes, ball, arch, heel, Achilles.
const FOOT := [Vector2(3.4, -2.5), Vector2(7, 1.2), Vector2(13, 4.2), Vector2(18.5, 5.4), Vector2(20, 6.8), Vector2(19, 7.5), Vector2(13, 7.5),
	Vector2(7, 6.4), Vector2(2, 6.9), Vector2(-3.5, 7.5), Vector2(-6.2, 6.2), Vector2(-5.8, 3), Vector2(-3.6, -2.5)]
## FIST is centred on the grip, x along the sword.
const FIST := [Vector2(-4, -3.6), Vector2(-1.5, -4.2), Vector2(2, -4.2), Vector2(4, -3.2), Vector2(4.4, 0), Vector2(4, 3), Vector2(2, 4.2),
	Vector2(-1.5, 4.4), Vector2(-4, 3.4), Vector2(-4.4, 0)]
const THUMB := [Vector2(3.6, -3.4), Vector2(6.6, -2.4), Vector2(6.6, -0.6), Vector2(3.6, -0.4)]
const BEARD := [Vector2(9, 5.5), Vector2(10.2, 9), Vector2(8.5, 13.5), Vector2(4, 16), Vector2(0.5, 12), Vector2(1, 9)]
const CROWN := [Vector2(-8, -11), Vector2(-9.5, -18), Vector2(-5.5, -14), Vector2(-3, -20), Vector2(0, -14.5), Vector2(3, -20),
	Vector2(5, -14), Vector2(8.5, -17.5), Vector2(7, -9.5), Vector2(0, -12)]
const HAIR_CAP := [Vector2(-3, -13.8), Vector2(3, -13.4), Vector2(7.6, -10.2), Vector2(8.6, -6.6), Vector2(5, -8.4), Vector2(0.5, -8), Vector2(-5, -5),
	Vector2(-9.5, 2.5), Vector2(-12.6, -2.8), Vector2(-11, -9.6), Vector2(-7, -12.8)]
## The mass of her hair: volume at the crown, a side-swept fringe, down past the ear. Tapered cloth
## locks carry it on to the shoulders. Smoothed from a few control points.
const HAIR_SLEEK := [Vector2(-3.0, -14.8), Vector2(-1.67, -15.04), Vector2(-0.33, -15.25), Vector2(1.0, -15.3), Vector2(2.37, -15.17), Vector2(3.74, -14.88), Vector2(5.0, -14.4), Vector2(6.14, -13.67), Vector2(7.17, -12.76), Vector2(8.0, -11.8), Vector2(8.57, -10.82), Vector2(8.93, -9.8), Vector2(9.2, -8.8), Vector2(9.39, -7.83), Vector2(9.49, -6.88), Vector2(9.5, -6.0), Vector2(9.45, -5.11), Vector2(9.33, -4.29), Vector2(9.1, -3.8), Vector2(8.77, -3.84), Vector2(8.33, -4.22), Vector2(7.8, -4.6), Vector2(7.14, -4.87), Vector2(6.38, -5.15), Vector2(5.6, -5.4), Vector2(4.81, -5.67), Vector2(4.01, -5.93), Vector2(3.2, -6.0), Vector2(2.37, -5.88), Vector2(1.54, -5.58), Vector2(0.8, -5.0), Vector2(0.18, -4.06), Vector2(-0.36, -2.83), Vector2(-0.8, -1.5), Vector2(-1.1, -0.06), Vector2(-1.32, 1.5), Vector2(-1.6, 3.0), Vector2(-1.96, 4.46), Vector2(-2.39, 5.86), Vector2(-3.0, 7.0), Vector2(-3.86, 7.79), Vector2(-4.9, 8.32), Vector2(-6.0, 8.6), Vector2(-7.14, 8.65), Vector2(-8.34, 8.46), Vector2(-9.5, 8.0), Vector2(-10.63, 7.25), Vector2(-11.71, 6.24), Vector2(-12.6, 5.0), Vector2(-13.24, 3.46), Vector2(-13.7, 1.7), Vector2(-14.0, 0.0), Vector2(-14.14, -1.55), Vector2(-14.13, -3.05), Vector2(-14.0, -4.5), Vector2(-13.8, -5.92), Vector2(-13.49, -7.3), Vector2(-13.0, -8.6), Vector2(-12.28, -9.84), Vector2(-11.39, -11.0), Vector2(-10.4, -12.0), Vector2(-9.35, -12.81), Vector2(-8.21, -13.47), Vector2(-7.0, -14.0), Vector2(-5.71, -14.37), Vector2(-4.36, -14.6)]

## Curved outlines for the body; the blurred cast shadow only needs the key rows, which saves over
## half of the per-point script calls in the shadow pass. Built once per body and scale.
static var lod_cache: Dictionary = {}
static var foot_tris: PackedInt32Array = Geometry2D.triangulate_polygon(PackedVector2Array(FOOT))
static var beard_tris: PackedInt32Array = Geometry2D.triangulate_polygon(PackedVector2Array(BEARD))
static var crown_tris: PackedInt32Array = Geometry2D.triangulate_polygon(PackedVector2Array(CROWN))
static var cap_tris: PackedInt32Array = Geometry2D.triangulate_polygon(PackedVector2Array(HAIR_CAP))
static var sleek_tris: PackedInt32Array = Geometry2D.triangulate_polygon(PackedVector2Array(HAIR_SLEEK))
## The cast shadow is blurred, so it takes every third hair point: that is two thirds fewer script calls.
static var sleek_coarse: Array = _every_third(HAIR_SLEEK)
static var sleek_coarse_tris: PackedInt32Array = Geometry2D.triangulate_polygon(PackedVector2Array(sleek_coarse))


static func _every_third(outline: Array) -> Array:
	var out: Array = []
	for i in range(0, outline.size(), 3):
		out.append(outline[i])
	return out


static func _lods_for(b: Dictionary) -> Dictionary:
	var key: String = b["id"]
	if lod_cache.has(key):
		return lod_cache[key]
	var an: Dictionary = ANATOMY[b["body"]]
	var sc: float = b["scale"]
	var wd: float = float(b["width"]) * sc
	var fine := {"joints": true, "cap": 3}
	var coarse := {"joints": false, "cap": 1}
	for part: String in ["thigh", "shin", "upper", "fore", "neck", "torso"]:
		var raw := PackedVector3Array()
		for row: Vector3 in an[part]:
			raw.append(Vector3(row.x * (sc if part == "torso" else 1.0), row.y * wd, row.z * wd))
		coarse[part] = raw
		fine[part] = _smooth(Array(raw))
	var out := {"fine": fine, "coarse": coarse, "head_tris": Geometry2D.triangulate_polygon(PackedVector2Array(an["head"]))}
	lod_cache[key] = out
	return out


## Catmull-Rom through the depth columns, so outlines curve instead of showing their key rows.
static func _smooth(rows: Array, sub: int = 2) -> PackedVector3Array:
	var out := PackedVector3Array()
	var n: int = rows.size()
	for i in n - 1:
		var p0: Vector3 = rows[maxi(i - 1, 0)]
		var p1: Vector3 = rows[i]
		var p2: Vector3 = rows[i + 1]
		var p3: Vector3 = rows[mini(i + 2, n - 1)]
		for j in sub:
			var u: float = float(j) / sub
			var q: Vector3 = 0.5 * (2.0 * p1 + (p2 - p0) * u + (2.0 * p0 - 5.0 * p1 + 4.0 * p2 - p3) * u * u
				+ (3.0 * p1 - p0 - 3.0 * p2 + p3) * u * u * u)
			q.x = lerpf(p1.x, p2.x, u)
			out.append(q)
	out.append(rows[n - 1])
	return out


## Builds the silhouette as convex polygons: "back" (far limbs, drawn a shade lighter), "main", and
## "shadow" (the whole figure at low detail, for the cast shadow).
func build_shapes() -> Dictionary:
	var back: Array = []
	var main: Array = []
	_figure(back, main, lods["fine"])
	var hilt: Array = _hilt()
	main.append_array(hilt)
	var shadow: Array = []
	_figure(shadow, shadow, lods["coarse"])
	shadow.append_array(hilt)
	return {"back": back, "main": main, "shadow": shadow}


func _figure(back: Array, main: Array, lod: Dictionary) -> void:
	var cap: int = lod["cap"]
	var an: Dictionary = ANATOMY[build["body"]]
	var extras: Array = build["extras"]
	# a rear-leg kick turns the hips over, so that leg comes through in front of the body
	var rear_over: bool = _kicking(1)
	if not rear_over:
		_leg(back, hip_b, kn_b, ft_b, pitch_b, 1, lod, an)
	_arm(back, sh_b, el_b, hand_b, holding and rear_grip, lod, an)
	_cloth(back, "back", cap)
	_leg(main, hip_f, kn_f, ft_f, pitch_f, 0, lod, an)
	if rear_over:
		_leg(main, hip_b, kn_b, ft_b, pitch_b, 1, lod, an)
	_torso(main, lod["torso"])
	if "outfit" in extras:
		_outfit(main, lod)
	_limb(main, chest.lerp(neck, 0.55), head + Vector2(-2.0 * facing, 7.5).rotated(head_ang) * head_k, lod["neck"])
	_outline(main, an["head"], lods["head_tris"], head, head_ang, head_k)
	if "hair_cap" in extras:
		_outline(main, HAIR_CAP, cap_tris, head, head_ang, head_k)
	if "hair_sleek" in extras:
		if lod["joints"]:
			_outline(main, HAIR_SLEEK, sleek_tris, head, head_ang, head_k)
		else:
			_outline(main, sleek_coarse, sleek_coarse_tris, head, head_ang, head_k)
	if "beard" in extras:
		_outline(main, BEARD, beard_tris, head, head_ang, head_k)
	if "crown" in extras:
		_outline(main, CROWN, crown_tris, head, head_ang, head_k)
	if "topknot" in extras:
		main.append(U.circle(head + Vector2(-5.0 * facing, -14.0).rotated(head_ang) * head_k, 3.4 * head_k, 8))
	_cloth(main, "main", cap)
	_arm(main, sh_f, el_f, hand_f, holding, lod, an)


## Clothes that read in pure shadow, from the outline alone: a belt that breaks the waist line and a
## short flared skirt. Its hem hangs from three cloth chains, so it swings and lifts with the hips.
func _outfit(out: Array, lod: Dictionary) -> void:
	var rows: PackedVector3Array = lod["torso"]
	var d: Vector2 = (chest - pelvis).normalized()
	var n := Vector2(-d.y * facing, d.x * facing)
	var low: Vector2 = pelvis + d * 4.0 * k
	var w0: Vector2 = _depth_at(rows, 4.0 * k)
	var high: Vector2 = pelvis + d * 13.0 * k
	var w1: Vector2 = _depth_at(rows, 13.0 * k)
	out.append(PackedVector2Array([low + n * (w0.x + 0.7), high + n * (w1.x + 0.7), high - n * (w1.y + 0.7), low - n * (w0.y + 0.7)]))
	var wf: Vector2 = low + n * (w0.x + 0.4)
	var wb: Vector2 = low - n * (w0.y + 0.4)
	var hf: Vector2 = _hem("hem_f")
	var hm: Vector2 = _hem("hem_m")
	var hb: Vector2 = _hem("hem_b")
	out.append(PackedVector2Array([wf, hf, hm, low]))
	out.append(PackedVector2Array([low, hm, hb, wb]))


func _hem(key: String) -> Vector2:
	var pos: PackedVector2Array = chains[key]["pos"]
	return pos[pos.size() - 1]


## Limb outline depth at position `t` along the bone.
func _depth_at(rows: PackedVector3Array, t: float) -> Vector2:
	for i in range(1, rows.size()):
		if t <= rows[i].x:
			var u: float = (t - rows[i - 1].x) / maxf(rows[i].x - rows[i - 1].x, 0.0001)
			return Vector2(lerpf(rows[i - 1].y, rows[i].y, u), lerpf(rows[i - 1].z, rows[i].z, u))
	return Vector2(rows[rows.size() - 1].y, rows[rows.size() - 1].z)


## A strip around a limb between two positions along its bone, `pad` proud of the outline.
func _band(out: Array, a: Vector2, b: Vector2, rows: PackedVector3Array, t0: float, t1: float, pad: float) -> void:
	var d: Vector2 = (b - a).normalized()
	var n := Vector2(d.y * facing, -d.x * facing)
	var c0: Vector2 = a.lerp(b, t0)
	var c1: Vector2 = a.lerp(b, t1)
	var w0: Vector2 = _depth_at(rows, t0)
	var w1: Vector2 = _depth_at(rows, t1)
	out.append(PackedVector2Array([c0 + n * (w0.x + pad), c1 + n * (w1.x + pad), c1 - n * (w1.y + pad), c0 - n * (w0.y + pad)]))


## Hilt: wrapped grip with a butt cap, and a round guard seen from the side.
func _hilt() -> Array:
	var perp := Vector2(-sword_dir.y, sword_dir.x)
	var hw: float = 1.7 * clampf(blade_w, 0.9, 1.4)
	var guard_r: float = 4.6 * clampf(blade_w, 0.9, 1.5)
	var guard: Vector2 = blade_base - sword_dir * 1.0
	return [PackedVector2Array([pommel + perp * hw, guard + perp * hw, guard - perp * hw, pommel - perp * hw]),
		PackedVector2Array([pommel - sword_dir * 1.2 + perp * hw * 1.2, pommel + sword_dir * 1.2 + perp * hw * 1.2,
			pommel + sword_dir * 1.2 - perp * hw * 1.2, pommel - sword_dir * 1.2 - perp * hw * 1.2]),
		PackedVector2Array([guard - perp * guard_r + sword_dir * 1.1, guard + perp * guard_r + sword_dir * 1.1,
			guard + perp * guard_r - sword_dir * 1.1, guard - perp * guard_r - sword_dir * 1.1])]


## A real blade: full width most of its length, a thick spine, a curve that follows the build, and
## an angled point (kissaki) instead of a needle.
func blade_polys() -> Array:
	var out: Array = []
	var perp := Vector2(-sword_dir.y, sword_dir.x) * facing
	var l: float = blade_base.distance_to(blade_tip)
	var prev_c: Vector2 = blade_base
	var prev_spine: float = 1.6 * blade_w
	var prev_edge: float = 1.6 * blade_w
	for i in range(1, 9):
		# seven even lengths of full-width steel, then the short angled point
		var t: float = 0.95 * float(i) / 7.0 if i < 8 else 1.0
		var c: Vector2 = blade_base.lerp(blade_tip, t) - perp * (t * t * sori * l / maxf(blade_len, 1.0))
		var taper: float = lerpf(1.0, 0.85, t)
		var spine: float = 1.6 * blade_w * taper
		var edge: float = 1.6 * blade_w * taper
		if i == 8:
			# the edge sweeps up to meet the back of the blade
			c -= perp * spine * 0.8
			spine = 0.0
			edge = 0.0
		out.append(PackedVector2Array([prev_c - perp * prev_spine, prev_c + perp * prev_edge,
			c + perp * edge, c - perp * spine]))
		prev_c = c
		prev_spine = spine
		prev_edge = edge
	return out


## A strip of quads along a bone. "Front" is the anatomical front of the limb, so a calf stays on
## the back of the shin however the leg is turned.
func _limb(out: Array, a: Vector2, b: Vector2, rows: PackedVector3Array) -> void:
	var d: Vector2 = (b - a).normalized()
	var n := Vector2(d.y * facing, -d.x * facing)
	var pf := Vector2.ZERO
	var pb := Vector2.ZERO
	for i in rows.size():
		var row: Vector3 = rows[i]
		var c: Vector2 = a.lerp(b, row.x)
		var qf: Vector2 = c + n * row.y
		var qb: Vector2 = c - n * row.z
		if i > 0:
			out.append(PackedVector2Array([pf, qf, qb, pb]))
		pf = qf
		pb = qb


func _torso(out: Array, rows: PackedVector3Array) -> void:
	var d: Vector2 = (chest - pelvis).normalized()
	var n := Vector2(-d.y * facing, d.x * facing)
	var up: Vector2 = (neck - chest).normalized()
	var top: float = SPINE * k
	var pf := Vector2.ZERO
	var pb := Vector2.ZERO
	for i in rows.size():
		var row: Vector3 = rows[i]
		var c: Vector2
		if row.x <= top:
			c = pelvis + (chest - pelvis) * (row.x / top)
		else:
			c = chest + up * (row.x - top)
		var qf: Vector2 = c + n * row.y
		var qb: Vector2 = c - n * row.z
		if i > 0:
			out.append(PackedVector2Array([pf, qf, qb, pb]))
		pf = qf
		pb = qb


func _leg(out: Array, hip: Vector2, knee: Vector2, ankle: Vector2, pitch: float, i: int, lod: Dictionary, an: Dictionary) -> void:
	var wd: float = float(build["width"]) * k
	if lod["joints"]:
		out.append(U.circle(hip + Vector2(0, 1), float(an["hip_r"]) * wd, 10))
		out.append(U.circle(knee, float(an["knee_r"]) * wd, 10))
	_limb(out, hip, knee, lod["thigh"])
	_limb(out, knee, ankle, lod["shin"])
	# the top of a thigh-high boot, a small step in the outline
	if "outfit" in build["extras"]:
		_band(out, hip, knee, lod["thigh"], 0.72, 0.76, 0.35)
	_foot(out, ankle, pitch, i)


## The forearm ends at the wrist; the palm then widens into a fist wrapped around the grip with
## the thumb along the hilt. A hand that has let go is an open palm with tapering fingers.
func _arm(out: Array, shoulder: Vector2, elbow: Vector2, hand: Vector2, grips: bool, lod: Dictionary, an: Dictionary) -> void:
	var wd: float = float(build["width"]) * k
	if lod["joints"]:
		out.append(U.circle(shoulder, float(an["shoulder_r"]) * wd, 10))
		out.append(U.circle(elbow, float(an["elbow_r"]) * wd, 8))
	var d: Vector2 = (hand - elbow).normalized()
	var n := Vector2(d.y * facing, -d.x * facing)
	var wrist: Vector2 = hand - d * 7.0 * k
	_limb(out, shoulder, elbow, lod["upper"])
	_limb(out, elbow, wrist, lod["fore"])
	var palm: float = 3.4 * wd
	var wrist_w: float = 2.1 * wd
	if grips:
		var ang: float = (sword_dir * facing).angle()
		out.append(PackedVector2Array([wrist + n * wrist_w, hand + n * palm, hand - n * palm, wrist - n * wrist_w]))
		out.append(_placed(FIST, hand, ang, wd))
		out.append(_placed(THUMB, hand, ang, wd))
	else:
		var tip: Vector2 = hand + d * 9.0 * k
		out.append(PackedVector2Array([wrist + n * wrist_w, hand + n * palm, tip + n * palm * 0.5,
			tip - n * palm * 0.5, hand - n * palm, wrist - n * wrist_w]))


func _placed(outline: Array, org: Vector2, ang: float, sc: float) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for q: Vector2 in outline:
		pts.append(org + Vector2(q.x * facing, q.y).rotated(ang) * sc)
	return pts


## With the heel raised the toes bend and stay flat on the floor. A kicking foot is off the floor,
## so its toes follow the ankle plus the `kt` pose; a standing foot that pivots on its ball turns
## away from the camera and so reads shorter from the side.
func _foot(out: Array, ankle: Vector2, pitch: float, i: int) -> void:
	var rot: float = pitch * facing
	var kicking: bool = _kicking(i) or float(p["air"]) > 2.0
	var sx := 1.0
	if i != kick_leg and not ragdoll:
		sx = 1.0 - 0.42 * clampf(p["sv"], 0.0, 1.0) * clampf(p["kw"], 0.0, 1.0)
	var ball: Vector2 = ankle + Vector2(FOOT_BALL * sx * facing, ANKLE).rotated(rot) * k
	var toe_rot: float = rot + float(p["kt"]) * facing
	var pts := PackedVector2Array()
	for q: Vector2 in FOOT:
		var tip: Vector2 = Vector2((q.x - FOOT_BALL) * sx * facing, q.y - ANKLE)
		if q.x > FOOT_BALL and kicking:
			pts.append(ball + tip.rotated(toe_rot) * k)
		elif q.x > FOOT_BALL and pitch > 0.0 and not ragdoll:
			pts.append(ball + tip * k)
		else:
			pts.append(ankle + Vector2(q.x * sx * facing, q.y).rotated(rot) * k)
	_tris(out, pts, foot_tris)


func _outline(out: Array, outline: Array, tris: PackedInt32Array, org: Vector2, ang: float, sc: float) -> void:
	_tris(out, _placed(outline, org, ang, sc), tris)


## The concave outlines (head, foot, hair, beard, crown) are drawn as their triangles.
func _tris(out: Array, pts: PackedVector2Array, tris: PackedInt32Array) -> void:
	for i in range(0, tris.size(), 3):
		out.append(PackedVector2Array([pts[tris[i]], pts[tris[i + 1]], pts[tris[i + 2]]]))


func _cloth(out: Array, layer: String, cap: int) -> void:
	for key: String in chains:
		var c: Dictionary = chains[key]
		if c["layer"] != layer:
			continue
		var pos: PackedVector2Array = c["pos"]
		var a: Vector2 = _anchor(c["anchor"])
		var r0: float = c["r0"]
		var r1: float = c["r1"]
		var n: int = pos.size()
		var curl: float = c["curl"]
		for i in n:
			var u: float = float(i + 1) / n
			var q: Vector2 = pos[i] + Vector2(facing * curl * u * u, 0.0)
			out.append(U.capsule(a, q, lerpf(r0, r1, float(i) / n), lerpf(r0, r1, u), cap))
			a = q
