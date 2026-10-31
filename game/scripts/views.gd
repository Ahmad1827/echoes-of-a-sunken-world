class_name Views
extends RefCounted
## Canvas nodes that draw the fighters, their cast shadows and their contact shadows.

const BODY := Color("050608")
const BODY_BACK := Color("15181c")
const STEEL := Color("0b0b0d")


class FighterView extends Node2D:
	var fighters: Array = []
	var stage: Stage

	func _draw() -> void:
		var order: Array = fighters.duplicate()
		# whoever is swinging is drawn in front
		if order.size() == 2 and (order[0] as Fighter).state == "attack":
			order.reverse()
		for f: Fighter in order:
			var sh: Dictionary = f.shapes
			if sh.is_empty():
				continue
			var blade: Array = [] if stage.glow else f.rig.blade_polys()
			var off: Vector2 = stage.rim_dir(f.rig.chest) * 2.2
			U.draw_polys(self, sh["back"], stage.rim_color, off)
			U.draw_polys(self, sh["main"], stage.rim_color, off)
			U.draw_polys(self, blade, stage.rim_color, off * 0.5)
			U.draw_polys(self, sh["back"], Views.BODY_BACK)
			U.draw_polys(self, sh["main"], Views.BODY)
			U.draw_polys(self, blade, Views.STEEL)


class ShadowView extends Node2D:
	var fighters: Array = []
	var stage: Stage

	func _draw() -> void:
		var proj := Callable(stage, "shadow_proj")
		var shade := Callable(stage, "shadow_shade")
		for f: Fighter in fighters:
			var sh: Dictionary = f.shapes
			if sh.is_empty():
				continue
			U.draw_polys(self, sh["shadow"], Color.WHITE, Vector2.ZERO, proj, shade)
			if not stage.glow:
				U.draw_polys(self, f.rig.blade_polys(), Color.WHITE, Vector2.ZERO, proj, shade)


## Soft occlusion where feet and bodies meet the floor; fades as a foot lifts.
class ContactView extends Node2D:
	var fighters: Array = []
	var stage: Stage
	var blob: Texture2D = U.radial_texture(64)

	func _draw() -> void:
		var g: float = stage.ground
		for f: Fighter in fighters:
			var r: Rig = f.rig
			var pts: Array = [r.ft_f, r.ft_b]
			if r.ragdoll:
				pts = [r.ft_f, r.ft_b, r.kn_f, r.kn_b, r.pelvis, r.chest, r.head, r.hand_f]
			for q: Vector2 in pts:
				var h: float = g - q.y - Rig.ANKLE * r.k
				var a: float = clampf(1.0 - h / 34.0, 0.0, 1.0) * 0.6
				if a > 0.01:
					draw_texture_rect(blob, Rect2(q.x - 28.0, g - 5.0, 56.0, 10.0), false, Color(0, 0, 0, a))
			var ph: float = g - r.pelvis.y
			var pa: float = clampf(1.0 - (ph - 60.0) / 80.0, 0.0, 1.0) * 0.35
			draw_texture_rect(blob, Rect2(r.pelvis.x - 70.0, g - 8.0, 140.0, 16.0), false, Color(0, 0, 0, pa))
			# a dropped sword rests on the floor too
			if r.ragdoll:
				for q: Vector2 in [r.pommel, r.blade_tip, r.pommel.lerp(r.blade_tip, 0.5)]:
					var a2: float = clampf(1.0 - (g - q.y) / 20.0, 0.0, 1.0) * 0.4
					draw_texture_rect(blob, Rect2(q.x - 22.0, g - 4.0, 44.0, 8.0), false, Color(0, 0, 0, a2))
