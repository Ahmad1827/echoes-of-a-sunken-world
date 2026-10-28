class_name Rig
extends RefCounted
## Procedural skeleton for one fighter.
##
## Gameplay sets pose *targets*; every parameter chases its target through a damped spring,
## which gives anticipation, follow-through and settle for free. Arms and legs are solved with
## two-bone IK, feet stay planted and take their own steps, the robe, hood, sash and sleeves
## are verlet cloth, and on death the body becomes a ragdoll.

const THIGH := 50.0
const SHIN := 49.0
const UPPER := 33.0
const FORE := 31.0
const SPINE := 52.0
const NECK := 11.0
const HEAD_R := 12.5
const HIP_H := 93.0
const GRIP := 22.0
const BLADE := 118.0

## px/py: pelvis offset, lean: spine angle, hx/hy: lead hand relative to chest, sa: sword angle,
## bl: blade length scale, fs: foreshortening (blade turning toward the camera), ht: head tilt,
## ff/bf: front/back foot stance, kw/kx/ky: kick blend and foot target, tw: charge tremble.
const KEYS := ["px", "py", "lean", "hx", "hy", "sa", "bl", "fs", "ht", "ff", "bf", "kw", "kx", "ky", "tw"]
const DEFAULT := {"px": 0.0, "py": 6.0, "lean": 0.06, "hx": 36.0, "hy": 30.0, "sa": -0.62, "bl": 1.0,
	"fs": 0.0, "ht": 0.0, "ff": 26.0, "bf": -30.0, "kw": 0.0, "kx": 0.0, "ky": 0.0, "tw": 0.0}

const ROBE_SEG := 15.5

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
var step_events := 0

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
var holding := true

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


func reset(x: float, gy: float, face: float) -> void:
	root_x = x
	ground = gy
	facing = face
	ragdoll = false
	holding = true
	time = randf() * 100.0
	for k in KEYS:
		p[k] = DEFAULT[k]
		v[k] = 0.0
		tg[k] = DEFAULT[k]
	feet = [_foot_state(x + face * float(DEFAULT["ff"])), _foot_state(x + face * float(DEFAULT["bf"]))]
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


func _update_feet(ts: float, vel_x: float) -> void:
	var fast: bool = absf(vel_x) > 6.0
	for i in 2:
		var ft: Dictionary = feet[i]
		var off: float = p["ff"] if i == 0 else p["bf"]
		var desired: float = root_x + facing * off
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
			if absf(float(ft["x"]) - desired) > 9.0 and (not other["stepping"] or fast):
				ft["stepping"] = true
				ft["t"] = 0.0
				ft["from"] = ft["x"]
				ft["to"] = desired + clampf(vel_x * 5.0, -42.0, 42.0)
				ft["dur"] = clampf(11.0 - absf(vel_x) * 0.9, 5.0, 11.0)
				ft["h"] = clampf(4.0 + absf(float(ft["to"]) - float(ft["from"])) * 0.12, 3.0, 14.0)


func _solve_pose() -> void:
	var f := facing
	var bob := 0.0
	for ft: Dictionary in feet:
		bob = maxf(bob, ft["lift"])
	pelvis = Vector2(root_x + f * float(p["px"]), ground - HIP_H + float(p["py"]) - bob * 0.3)
	# wide stances drop the hips so the legs can still reach the ground
	for i in 2:
		var ft: Dictionary = feet[i]
		var hip_x: float = pelvis.x + (f * 4.0 if i == 0 else -f * 4.0)
		var fy: float = ground - 4.0 - float(ft["lift"])
		var dx: float = float(ft["x"]) - hip_x
		var reach: float = THIGH + SHIN - 1.5
		if absf(dx) < reach:
			pelvis.y = maxf(pelvis.y, fy - sqrt(reach * reach - dx * dx))
	var lean: float = p["lean"]
	spine_ang = lean * f
	chest = pelvis + Vector2(0, -SPINE).rotated(spine_ang) + Vector2(0, sin(time * 0.045) * 0.9)
	neck = chest + Vector2(0, -NECK).rotated(spine_ang * 0.6)
	head = neck + Vector2(0, -HEAD_R - 1.5).rotated((lean * 0.4 + float(p["ht"])) * f)
	sh_f = chest + Vector2(f * 3.0, 3.0).rotated(spine_ang)
	sh_b = chest + Vector2(-f * 5.0, 5.0).rotated(spine_ang)

	var reach_arm := UPPER + FORE - 0.5
	var target: Vector2 = chest + Vector2(f * float(p["hx"]), float(p["hy"]))
	var dv: Vector2 = target - sh_f
	if dv.length() > reach_arm:
		target = sh_f + dv.normalized() * reach_arm
	var sa: float = p["sa"]
	if float(p["tw"]) > 0.01:
		sa += sin(time * 2.3) * 0.025 * float(p["tw"])
	sword_dir = Vector2(cos(sa) * f, sin(sa))
	hand_f = target
	hand_b = hand_f - sword_dir * 11.0
	var dv2: Vector2 = hand_b - sh_b
	if dv2.length() > reach_arm:
		hand_b = sh_b + dv2.normalized() * reach_arm
	el_f = U.ik(sh_f, hand_f, UPPER, FORE, f)
	el_b = U.ik(sh_b, hand_b, UPPER, FORE, f)
	var fore_len: float = lerpf(1.0, 0.3 + 0.7 * absf(cos(sa)), clampf(p["fs"], 0.0, 1.0))
	blade_base = hand_f + sword_dir * 6.0
	blade_tip = blade_base + sword_dir * BLADE * float(p["bl"]) * fore_len
	pommel = hand_f - sword_dir * GRIP

	hip_f = pelvis + Vector2(f * 4.0, 0)
	hip_b = pelvis + Vector2(-f * 4.0, 0)
	var tf := Vector2(feet[0]["x"], ground - 4.0 - float(feet[0]["lift"]))
	var tb := Vector2(feet[1]["x"], ground - 4.0 - float(feet[1]["lift"]))
	var kw: float = clampf(p["kw"], 0.0, 1.0)
	if kw > 0.01:
		tf = tf.lerp(pelvis + Vector2(f * float(p["kx"]), -float(p["ky"])), kw)
	kn_f = U.ik(hip_f, tf, THIGH, SHIN, f)
	ft_f = kn_f + (tf - kn_f).normalized() * SHIN
	kn_b = U.ik(hip_b, tb, THIGH, SHIN, f)
	ft_b = kn_b + (tb - kn_b).normalized() * SHIN


func hurtboxes() -> Array:
	return [["head", head, head, HEAD_R + 1.0], ["torso", pelvis, neck, 17.0],
		["arm", sh_f, el_f, 6.0], ["arm", el_f, hand_f, 6.0],
		["leg", hip_f, kn_f, 10.0], ["leg", kn_f, ft_f, 8.0],
		["leg", hip_b, kn_b, 10.0], ["leg", kn_b, ft_b, 8.0]]


# ---------------------------------------------------------------- cloth

func _init_cloth() -> void:
	chains = {
		"robe_f": _chain(_chain_anchor("robe_f"), 6, ROBE_SEG, 0.7, 0.62),
		"robe_b": _chain(_chain_anchor("robe_b"), 6, ROBE_SEG, 1.2, 0.55),
		"hood": _chain(_chain_anchor("hood"), 3, 6.5, 1.0, 0.25),
		"sash_a": _chain(_chain_anchor("sash_a"), 6, 9.0, 1.3, 0.3),
		"sash_b": _chain(_chain_anchor("sash_b"), 5, 9.0, 1.0, 0.3),
		"sleeve_f": _chain(_chain_anchor("sleeve_f"), 3, 8.0, 0.6, 0.32),
		"sleeve_b": _chain(_chain_anchor("sleeve_b"), 3, 8.0, 0.6, 0.32),
	}


func _chain(anchor: Vector2, n: int, seg: float, wf: float, grav: float) -> Dictionary:
	var pos := PackedVector2Array()
	var vel := PackedVector2Array()
	for i in n:
		pos.append(anchor + Vector2(0, seg * (i + 1)))
		vel.append(Vector2.ZERO)
	return {"pos": pos, "vel": vel, "seg": seg, "wf": wf, "grav": grav}


func _chain_anchor(key: String) -> Vector2:
	var waist_rot: float = spine_ang if ragdoll else spine_ang * 0.55
	match key:
		"robe_f":
			return pelvis + Vector2(facing * 13.0, 2.0).rotated(waist_rot)
		"robe_b":
			return pelvis + Vector2(-facing * 15.0, 2.0).rotated(waist_rot)
		"hood":
			return head + Vector2(-facing * 13.0, 8.0).rotated(spine_ang)
		"sash_a":
			return pelvis + Vector2(-facing * 13.0, -4.0).rotated(spine_ang)
		"sash_b":
			return pelvis + Vector2(-facing * 16.0, -1.0).rotated(spine_ang)
		"sleeve_f":
			return el_f.lerp(hand_f, 0.45)
	return el_b.lerp(hand_b, 0.45)


func _cloth_step(ts: float) -> void:
	var gust: float = wind * (0.6 + 0.4 * sin(time * 0.031) * sin(time * 0.017 + 1.3))
	for key: String in chains:
		var side := 0.0
		if key == "robe_f":
			side = 1.0
		elif key == "robe_b":
			side = -1.0
		_chain_step(chains[key], _chain_anchor(key), ts, gust, side)


## Horizontal extent of the legs at height y, in the fighter's facing-local x.
func _legs_extent(y: float) -> Vector2:
	var lo := 0.0
	var hi := 0.0
	for seg: Array in [[hip_f, kn_f, 11.0], [kn_f, ft_f, 9.0], [hip_b, kn_b, 11.0], [kn_b, ft_b, 9.0]]:
		var a: Vector2 = seg[0]
		var b: Vector2 = seg[1]
		var r: float = seg[2]
		if y < minf(a.y, b.y) - r or y > maxf(a.y, b.y) + r:
			continue
		var t: float = clampf((y - a.y) / (b.y - a.y), 0.0, 1.0) if absf(b.y - a.y) > 0.01 else 0.5
		var lx: float = (lerpf(a.x, b.x, t) - pelvis.x) * facing
		lo = minf(lo, lx - r)
		hi = maxf(hi, lx + r)
	return Vector2(lo, hi)


## `side` 1/-1 marks the robe's front/back edge: the legs may only push that edge outward,
## so the robe always wraps around them.
func _chain_step(c: Dictionary, anchor: Vector2, ts: float, gust: float, side: float = 0.0) -> void:
	if side != 0.0 and not ragdoll:
		_robe_edge_step(c, anchor, ts, gust, side)
		return
	var pos: PackedVector2Array = c["pos"]
	var vel: PackedVector2Array = c["vel"]
	var seg: float = c["seg"]
	var wf: float = c["wf"]
	var grav: float = float(c["grav"]) * (0.3 if water else 1.0)
	var prev: PackedVector2Array = pos.duplicate()
	var drag: float = pow(0.9 if water else 0.95, ts)
	for i in pos.size():
		vel[i] = vel[i] * drag + Vector2(gust * 0.06 * wf, grav) * ts
		pos[i] += vel[i] * ts
	for it in 2:
		var a: Vector2 = anchor
		for i in pos.size():
			var q: Vector2 = pos[i]
			var d: Vector2 = q - a
			var l: float = d.length()
			if l > 0.0001:
				q = a + d / l * seg
			if side != 0.0:
				q = _robe_bound(q, side)
			if q.y > ground - 1.0:
				q.y = ground - 1.0
			pos[i] = q
			a = q
	var inv: float = 1.0 / ts
	for i in pos.size():
		vel[i] = (pos[i] - prev[i]) * inv * 0.98
	c["pos"] = pos
	c["vel"] = vel


## Robe edges hang toward a draped outline (outside the legs, flaring toward the hem) through
## soft springs, so they lag, swing and flutter but always cover the legs.
func _robe_edge_step(c: Dictionary, anchor: Vector2, ts: float, gust: float, side: float) -> void:
	var pos: PackedVector2Array = c["pos"]
	var vel: PackedVector2Array = c["vel"]
	var n: int = pos.size()
	var wf: float = c["wf"]
	var step_y: float = (ground - 1.0 - anchor.y) / n
	var k: float = 1.0 - pow(1.0 - (0.08 if water else 0.2), ts)
	var drag: float = pow(0.88 if water else 0.8, ts)
	var flap_f: float = 0.07 if water else 0.21
	var flap_a: float = 2.6 if water else 1.0
	for i in n:
		var ty: float = anchor.y + step_y * (i + 1)
		var tgt: Vector2 = _robe_bound(Vector2(anchor.x, ty), side)
		var flap: float = sin(time * flap_f + i * 0.9 + side) * (0.4 + i * 0.25) * wind * 0.5 * flap_a
		var q: Vector2 = pos[i]
		var v2: Vector2 = vel[i] * drag + (tgt - q) * k + Vector2(gust * 0.05 * wf + flap * 0.1, 0.0) * ts
		q += v2 * ts
		q = _robe_bound(q, side)
		if q.y > ground - 1.0:
			q.y = ground - 1.0
		vel[i] = v2
		pos[i] = q
	c["pos"] = pos
	c["vel"] = vel


func _robe_bound(q: Vector2, side: float) -> Vector2:
	if ragdoll:
		for seg: Array in [[hip_f, kn_f], [kn_f, ft_f], [hip_b, kn_b], [kn_b, ft_b]]:
			q = U.push_out(q, seg[0], seg[1], 11.0)
		return q
	var ext: Vector2 = _legs_extent(q.y)
	var drop: float = maxf(0.0, q.y - pelvis.y)
	var lx: float = (q.x - pelvis.x) * facing
	if side > 0.0:
		lx = maxf(lx, maxf(ext.y + 4.0, 11.0 + drop * 0.44))
	else:
		lx = minf(lx, minf(ext.x - 4.0, -13.0 - drop * 0.5))
	q.x = pelvis.x + lx * facing
	return q


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
			var r: float = HEAD_R if i == 2 else 5.0
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
	sh_f = chest + Vector2(facing * 3.0, 3.0).rotated(spine_ang)
	sh_b = chest + Vector2(-facing * 5.0, 5.0).rotated(spine_ang)
	hip_f = pelvis
	hip_b = pelvis
	_sword_step(ts)


func _sword_step(ts: float) -> void:
	var prev: PackedVector2Array = sw_pos.duplicate()
	var length: float = GRIP + 6.0 + BLADE
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
	blade_base = pommel + sword_dir * (GRIP + 6.0)


# ---------------------------------------------------------------- shapes

## Builds the silhouette as convex polygons: "back" (far limbs, drawn a shade lighter) and "main".
func build_shapes() -> Dictionary:
	var back: Array = []
	var main: Array = []
	back.append(U.capsule(hip_b, kn_b, 10.0, 8.0))
	back.append(U.capsule(kn_b, ft_b, 7.5, 5.0))
	back.append(_foot(ft_b))
	back.append(U.capsule(sh_b, el_b, 7.0, 6.0))
	back.append(U.capsule(el_b, hand_b, 6.0, 5.0))
	back.append(U.circle(hand_b, 5.0, 8))
	_sleeve(back, "sleeve_b", el_b, hand_b)

	main.append(U.capsule(hip_f, kn_f, 10.0, 8.0))
	main.append(U.capsule(kn_f, ft_f, 7.5, 5.0))
	main.append(_foot(ft_f))
	main.append(_robe())
	main.append(U.capsule(pelvis + Vector2(0, 2), chest, 15.0, 15.5))
	main.append(U.capsule(chest, neck, 8.0, 7.0))
	main.append(U.circle(head, HEAD_R))
	main.append(_hood())
	_chain_shapes(main, "hood", _chain_anchor("hood"), 5.5, 2.5)
	_chain_shapes(main, "sash_a", _chain_anchor("sash_a"), 4.0, 1.5)
	_chain_shapes(main, "sash_b", _chain_anchor("sash_b"), 3.5, 1.2)
	main.append(U.capsule(sh_f, el_f, 7.5, 6.5))
	main.append(U.capsule(el_f, hand_f, 6.5, 5.0))
	_sleeve(main, "sleeve_f", el_f, hand_f)
	main.append(U.circle(hand_f, 5.5, 8))
	main.append(U.capsule(pommel, blade_base, 2.8, 2.8, 3))
	var perp := Vector2(-sword_dir.y, sword_dir.x)
	main.append(U.capsule(blade_base - perp * 6.0, blade_base + perp * 6.0, 2.2, 2.2, 3))
	return {"back": back, "main": main}


## A katana: slight curve (sori) toward the spine, tapering to the point.
func blade_polys() -> Array:
	var out: Array = []
	var perp := Vector2(-sword_dir.y, sword_dir.x) * facing
	var l: float = blade_base.distance_to(blade_tip)
	var prev_c: Vector2 = blade_base
	var prev_w := 2.6
	for i in range(1, 5):
		var t: float = float(i) / 4.0
		var c: Vector2 = blade_base.lerp(blade_tip, t) - perp * (t * t * 5.0 * l / BLADE)
		var ww: float = lerpf(2.6, 0.4, pow(t, 3.0))
		out.append(PackedVector2Array([prev_c - perp * prev_w, prev_c + perp * prev_w * 0.6,
			c + perp * ww * 0.6, c - perp * ww]))
		prev_c = c
		prev_w = ww
	return out


## The robe outline: waist, front edge down, a ragged hem, back edge up. Fanned from the waist.
func _robe() -> PackedVector2Array:
	var fr: PackedVector2Array = chains["robe_f"]["pos"]
	var bk: PackedVector2Array = chains["robe_b"]["pos"]
	var pts := PackedVector2Array([pelvis + Vector2(0, -6).rotated(spine_ang), _chain_anchor("robe_f")])
	pts.append_array(fr)
	var hf: Vector2 = fr[fr.size() - 1]
	var hb: Vector2 = bk[bk.size() - 1]
	for k in range(1, 4):
		var t: float = k / 4.0
		var q: Vector2 = hf.lerp(hb, t)
		q.y -= (2.0 + 2.0 * sin(time * 0.13 + k * 2.1)) * (1.0 if k % 2 == 0 else 0.4)
		pts.append(q)
	for i in range(bk.size() - 1, -1, -1):
		pts.append(bk[i])
	pts.append(_chain_anchor("robe_b"))
	return pts


func _foot(ankle: Vector2) -> PackedVector2Array:
	return U.capsule(ankle + Vector2(-facing * 4.0, 0.5), ankle + Vector2(facing * 12.0, 2.0), 4.5, 3.5, 3)


func _hood() -> PackedVector2Array:
	var ang: float = spine_ang * 0.5 + (0.0 if ragdoll else float(p["ht"]) * facing)
	var pts := PackedVector2Array()
	for q: Vector2 in [Vector2(7, -11), Vector2(-1, -16), Vector2(-10, -13), Vector2(-16, -3),
			Vector2(-16, 9), Vector2(-9, 16), Vector2(3, 13)]:
		pts.append(head + Vector2(q.x * facing, q.y).rotated(ang))
	return pts


func _chain_shapes(out: Array, key: String, anchor: Vector2, r0: float, r1: float) -> void:
	var pos: PackedVector2Array = chains[key]["pos"]
	var a: Vector2 = anchor
	var n: int = pos.size()
	for i in n:
		out.append(U.capsule(a, pos[i], lerpf(r0, r1, float(i) / n), lerpf(r0, r1, float(i + 1) / n), 3))
		a = pos[i]


func _sleeve(out: Array, key: String, e: Vector2, h: Vector2) -> void:
	var pos: PackedVector2Array = chains[key]["pos"]
	var poly := PackedVector2Array([e, e.lerp(h, 0.8)])
	for i in range(pos.size() - 1, -1, -1):
		poly.append(pos[i])
	out.append(poly)
