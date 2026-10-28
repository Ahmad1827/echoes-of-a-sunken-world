class_name Sfx
extends Node
## Every sound is synthesized at startup: steel rings built from inharmonic partials,
## filtered-noise whooshes, body impacts, footsteps and two looping ambiences.

const RATE := 24000

var bank := {}
var players: Array[AudioStreamPlayer] = []
var amb: AudioStreamPlayer
var muted_scale := 1.0


func _ready() -> void:
	_generate()
	for i in 16:
		var pl := AudioStreamPlayer.new()
		add_child(pl)
		players.append(pl)
	amb = AudioStreamPlayer.new()
	amb.volume_db = -9.0
	add_child(amb)


func play(name: String, db: float = 0.0, pitch: float = 1.0) -> void:
	if not bank.has(name):
		return
	var pick: AudioStreamPlayer = players[0]
	for pl in players:
		if not pl.playing:
			pick = pl
			break
	pick.stream = bank[name]
	pick.volume_db = db + linear_to_db(muted_scale)
	pick.pitch_scale = pitch
	pick.play()


func ambience(name: String) -> void:
	if bank.has(name) and amb.stream != bank[name]:
		amb.stream = bank[name]
		amb.play()


func _generate() -> void:
	bank["whoosh"] = _wav(_whoosh(0.24, 500.0, 2600.0, 0.9))
	bank["whoosh_heavy"] = _wav(_whoosh(0.36, 300.0, 1700.0, 1.1))
	bank["thrust"] = _wav(_whoosh(0.18, 900.0, 3200.0, 0.7))
	bank["dash"] = _wav(_whoosh(0.2, 350.0, 1100.0, 0.6))
	bank["clash"] = _wav(_ring(1.0, [[1870.0, 0.22, 5.0], [2633.0, 0.18, 6.5], [3410.0, 0.12, 8.0], [4980.0, 0.08, 10.0], [1882.0, 0.12, 4.0]], 0.9, 0.035))
	bank["parry"] = _wav(_ring(1.5, [[1320.0, 0.2, 2.6], [1985.0, 0.16, 3.0], [2972.0, 0.1, 3.6], [3961.0, 0.06, 4.5], [1327.0, 0.12, 2.2]], 0.7, 0.025))
	bank["block"] = _wav(_ring(0.45, [[620.0, 0.2, 12.0], [1340.0, 0.16, 14.0], [2210.0, 0.09, 18.0]], 0.8, 0.05, 0.35))
	bank["hit"] = _wav(_impact(0.32, 120.0, 42.0, 0.9, 0.7, 2600.0))
	bank["hit_heavy"] = _wav(_impact(0.5, 95.0, 34.0, 1.0, 0.9, 1800.0))
	bank["kick"] = _wav(_impact(0.28, 85.0, 40.0, 0.8, 0.5, 900.0))
	bank["break"] = _wav(_impact(0.7, 70.0, 30.0, 0.9, 0.8, 600.0))
	bank["fall"] = _wav(_impact(0.6, 60.0, 30.0, 0.7, 0.8, 500.0))
	bank["step_stone"] = _wav(_step(0.07, 1400.0, 0.35))
	bank["step_sand"] = _wav(_step(0.11, 2400.0, 0.3))
	bank["ko"] = _wav(_mix(_impact(2.2, 52.0, 26.0, 1.0, 0.6, 400.0),
		_ring(2.6, [[392.0, 0.08, 1.0], [587.0, 0.06, 1.2], [881.0, 0.04, 1.5]], 0.0, 0.0)))
	bank["gong"] = _wav(_ring(4.0, [[98.0, 0.32, 0.7], [196.6, 0.14, 0.9], [270.0, 0.09, 1.1], [529.0, 0.05, 1.6], [99.3, 0.2, 0.6]], 0.15, 0.04, 0.0))
	bank["draw"] = _wav(_mix(_whoosh(0.5, 3000.0, 6000.0, 0.35), _ring(0.9, [[2960.0, 0.05, 4.0], [4410.0, 0.04, 5.0]], 0.0, 0.0)))
	bank["amb_hollow"] = _wav(_ambience(10.0, true), true)
	bank["amb_dune"] = _wav(_ambience(10.0, false), true)


func _wav(buf: PackedFloat32Array, loop: bool = false) -> AudioStreamWAV:
	var data := PackedByteArray()
	data.resize(buf.size() * 2)
	for i in buf.size():
		data.encode_s16(i * 2, int(clampf(buf[i], -1.0, 1.0) * 32000.0))
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = RATE
	w.stereo = false
	w.data = data
	if loop:
		w.loop_mode = AudioStreamWAV.LOOP_FORWARD
		w.loop_begin = 0
		w.loop_end = buf.size()
	return w


func _mix(a: PackedFloat32Array, b: PackedFloat32Array) -> PackedFloat32Array:
	var out := a.duplicate() if a.size() >= b.size() else b.duplicate()
	var other := b if a.size() >= b.size() else a
	for i in other.size():
		out[i] += other[i]
	return out


## Band-passed noise whose centre sweeps up and back down, like a blade cutting air.
func _whoosh(dur: float, f0: float, f1: float, amp: float) -> PackedFloat32Array:
	var n := int(dur * RATE)
	var out := PackedFloat32Array()
	out.resize(n)
	var low := 0.0
	var band := 0.0
	for i in n:
		var t: float = float(i) / n
		var fc: float = lerpf(f0, f1, sin(t * PI))
		var f: float = 2.0 * sin(PI * fc / RATE)
		var x: float = randf() * 2.0 - 1.0
		low += f * band
		var high: float = x - low - 0.55 * band
		band += f * high
		out[i] = band * pow(sin(t * PI), 1.6) * (1.0 - t * 0.3) * amp
	return out


## Decaying inharmonic partials plus a short bright noise transient: struck steel.
func _ring(dur: float, partials: Array, noise_amp: float, noise_dur: float, hp_mix: float = 1.0) -> PackedFloat32Array:
	var n := int(dur * RATE)
	var out := PackedFloat32Array()
	out.resize(n)
	var prev := 0.0
	var hp := 0.0
	for i in n:
		var t: float = float(i) / RATE
		var s := 0.0
		for pr: Array in partials:
			s += float(pr[1]) * sin(TAU * float(pr[0]) * t) * exp(-t * float(pr[2]))
		if t < noise_dur:
			var x: float = randf() * 2.0 - 1.0
			hp = 0.6 * (hp + x - prev)
			prev = x
			s += lerpf(x, hp, hp_mix) * noise_amp * pow(1.0 - t / noise_dur, 2.0)
		out[i] = s * minf(1.0, t * 3000.0)
	return out


## Falling-pitch thump with a noise body and a high "cut" transient.
func _impact(dur: float, f0: float, f1: float, amp: float, noise_amp: float, cut_f: float) -> PackedFloat32Array:
	var n := int(dur * RATE)
	var out := PackedFloat32Array()
	out.resize(n)
	var phase := 0.0
	var lp := 0.0
	var k: float = 2.0 * sin(PI * cut_f / RATE)
	for i in n:
		var t: float = float(i) / RATE
		var f: float = f1 + (f0 - f1) * exp(-t * 18.0)
		phase += TAU * f / RATE
		var x: float = randf() * 2.0 - 1.0
		lp += k * (x - lp)
		var body: float = sin(phase) * exp(-t * 7.0) * amp
		var nz: float = lp * exp(-t * 22.0) * noise_amp
		out[i] = (body + nz) * minf(1.0, t * 2000.0)
	return out


func _step(dur: float, fc: float, amp: float) -> PackedFloat32Array:
	var n := int(dur * RATE)
	var out := PackedFloat32Array()
	out.resize(n)
	var low := 0.0
	var band := 0.0
	var f: float = 2.0 * sin(PI * fc / RATE)
	for i in n:
		var t: float = float(i) / n
		var x: float = randf() * 2.0 - 1.0
		low += f * band
		band += f * (x - low - 0.9 * band)
		out[i] = (band * 0.6 + low * 0.5) * pow(1.0 - t, 3.0) * amp
	return out


## Seamless underwater loops: a drone in the cavern, a slow current rumble on the seabed,
## both with distant bubbles.
func _ambience(dur: float, cavern: bool) -> PackedFloat32Array:
	var n := int(dur * RATE)
	var fade := int(1.0 * RATE)
	var raw := PackedFloat32Array()
	raw.resize(n + fade)
	var low := 0.0
	var band := 0.0
	var bub_t := -1.0
	var bub_next := 0.4
	var bub_f := 400.0
	var bub_a := 0.1
	for i in n + fade:
		var t: float = float(i) / RATE
		var x: float = randf() * 2.0 - 1.0
		var s := 0.0
		if cavern:
			var fc: float = 260.0 + 140.0 * sin(TAU * t / 5.0)
			var f: float = 2.0 * sin(PI * fc / RATE)
			low += f * band
			band += f * (x - low - 0.8 * band)
			var lfo: float = 0.75 + 0.25 * sin(TAU * t / dur)
			s = (sin(TAU * 55.0 * t) * 0.16 + sin(TAU * 82.5 * t) * 0.1 + sin(TAU * 110.3 * t) * 0.05) * lfo
			s += band * 0.35
		else:
			var swell: float = 0.6 + 0.4 * sin(TAU * t / 5.0) * sin(TAU * t / 3.3 + 1.0)
			var fc: float = 110.0 + 150.0 * swell
			var f: float = 2.0 * sin(PI * fc / RATE)
			low += f * band
			band += f * (x - low - 0.7 * band)
			s = band * 0.7 * swell + low * 0.3 + sin(TAU * 41.0 * t) * 0.06 * swell
		if t >= bub_next:
			bub_t = t
			bub_f = randf_range(260.0, 760.0)
			bub_a = randf_range(0.04, 0.12)
			bub_next = t + randf_range(0.12, 1.3)
		var bt: float = t - bub_t
		if bub_t >= 0.0 and bt < 0.07:
			s += sin(TAU * bub_f * (1.0 + bt * 10.0) * bt) * exp(-bt * 55.0) * bub_a
		raw[i] = s
	var out := PackedFloat32Array()
	out.resize(n)
	for i in n:
		out[i] = raw[i]
	for i in fade:
		var a: float = float(i) / fade
		out[i] = raw[i] * a + raw[n + i] * (1.0 - a)
	return out
