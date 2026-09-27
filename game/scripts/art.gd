extends RefCounted

## Art: static procedural drawing helpers. Every character is drawn in code
## (origin = feet), so the game has a consistent vector-noir look with zero sprite files.
## Usage: const Art = preload("res://scripts/art.gd") then Art.draw_robot(self, ...)

const HEAD_TOP = -61.0
const BoonDataRef = preload("res://scripts/boon_data.gd")

# ---------------------------------------------------------------------------
# PRIMITIVES
# ---------------------------------------------------------------------------
static func ellipse_pts(c: Vector2, rx: float, ry: float, seg: int = 22) -> PackedVector2Array:
	var pts = PackedVector2Array()
	for i in range(seg):
		var a = TAU * float(i) / float(seg)
		pts.append(c + Vector2(cos(a) * rx, sin(a) * ry))
	return pts

static func ellipse(ci: CanvasItem, c: Vector2, rx: float, ry: float, col: Color, seg: int = 22):
	if rx < 0.5 or ry < 0.5:
		return
	ci.draw_colored_polygon(ellipse_pts(c, rx, ry, seg), col)

static func ellipse_line(ci: CanvasItem, c: Vector2, rx: float, ry: float, col: Color, w: float = 2.0, seg: int = 28):
	var pts = ellipse_pts(c, rx, ry, seg)
	pts.append(pts[0])
	ci.draw_polyline(pts, col, w, true)

static func rrect_pts(r: Rect2, rad: float, seg: int = 4) -> PackedVector2Array:
	var pts = PackedVector2Array()
	var rr = minf(rad, minf(r.size.x, r.size.y) * 0.5 - 0.5)
	if rr < 1.0:
		pts.append(r.position)
		pts.append(Vector2(r.end.x, r.position.y))
		pts.append(r.end)
		pts.append(Vector2(r.position.x, r.end.y))
		return pts
	var cs = [
		[Vector2(r.end.x - rr, r.position.y + rr), -PI * 0.5],
		[Vector2(r.end.x - rr, r.end.y - rr), 0.0],
		[Vector2(r.position.x + rr, r.end.y - rr), PI * 0.5],
		[Vector2(r.position.x + rr, r.position.y + rr), PI],
	]
	for c in cs:
		for i in range(seg + 1):
			var a = float(c[1]) + (PI * 0.5) * float(i) / float(seg)
			pts.append(c[0] + Vector2(cos(a), sin(a)) * rr)
	return pts

static func rrect(ci: CanvasItem, r: Rect2, rad: float, col: Color):
	if r.size.x < 1.0 or r.size.y < 1.0:
		return
	ci.draw_colored_polygon(rrect_pts(r, rad), col)

static func poly(ci: CanvasItem, pts: Array, col: Color):
	var p = PackedVector2Array()
	for v in pts:
		p.append(v)
	ci.draw_colored_polygon(p, col)

static func shadow(ci: CanvasItem, pos: Vector2, rx: float, alpha: float = 0.38):
	ellipse(ci, pos, rx, rx * 0.36, Color(0, 0, 0, alpha))

static func glow(ci: CanvasItem, pos: Vector2, r: float, col: Color, steps: int = 4):
	for i in range(steps):
		var k = float(i + 1) / float(steps)
		var c = col
		c.a = col.a * (0.18 + 0.2 * k)
		ci.draw_circle(pos, r * (1.15 - k * 0.75), c)

static func star_pts(pos: Vector2, r_out: float, r_in: float, n: int, rot: float) -> PackedVector2Array:
	var pts = PackedVector2Array()
	for i in range(n * 2):
		var a = rot + PI * float(i) / float(n) - PI * 0.5
		var rad = r_out if i % 2 == 0 else r_in
		pts.append(pos + Vector2(cos(a), sin(a)) * rad)
	return pts

static func star(ci: CanvasItem, pos: Vector2, r_out: float, r_in: float, n: int, col: Color, rot: float = 0.0):
	ci.draw_colored_polygon(star_pts(pos, r_out, r_in, n, rot), col)

static func text(ci: CanvasItem, pos: Vector2, s: String, size: int, col: Color, font: Font = null, width: float = 800.0, shadow_on: bool = true):
	var f = font
	if f == null:
		f = Style.font_body
	var p = Vector2(pos.x - width * 0.5, pos.y)
	if shadow_on:
		ci.draw_string(f, p + Vector2(2, 2), s, HORIZONTAL_ALIGNMENT_CENTER, width, size, Color(0, 0, 0, col.a * 0.75))
	ci.draw_string(f, p, s, HORIZONTAL_ALIGNMENT_CENTER, width, size, col)

static func text_left(ci: CanvasItem, pos: Vector2, s: String, size: int, col: Color, font: Font = null):
	var f = font
	if f == null:
		f = Style.font_body
	ci.draw_string(f, pos + Vector2(2, 2), s, HORIZONTAL_ALIGNMENT_LEFT, -1, size, Color(0, 0, 0, col.a * 0.75))
	ci.draw_string(f, pos, s, HORIZONTAL_ALIGNMENT_LEFT, -1, size, col)

static func note_glyph(ci: CanvasItem, pos: Vector2, s: float, col: Color):
	# a musical eighth note: the Rhythm Point pickup
	ellipse(ci, pos + Vector2(-s * 0.35, s * 0.55), s * 0.42, s * 0.3, col)
	ci.draw_line(pos + Vector2(0.0, s * 0.5), pos + Vector2(0.0, -s * 0.7), col, maxf(1.5, s * 0.16))
	poly(ci, [pos + Vector2(0.0, -s * 0.7), pos + Vector2(s * 0.55, -s * 0.35), pos + Vector2(s * 0.5, -s * 0.15), pos + Vector2(0.0, -s * 0.42)], col)

static func chip_glyph(ci: CanvasItem, pos: Vector2, s: float, col: Color):
	ci.draw_circle(pos, s, col)
	ci.draw_circle(pos, s * 0.72, Color(0.95, 0.95, 0.9))
	ci.draw_circle(pos, s * 0.5, col)
	for i in range(6):
		var a = TAU * float(i) / 6.0
		ci.draw_line(pos + Vector2(cos(a), sin(a)) * s * 0.75, pos + Vector2(cos(a), sin(a)) * s * 0.98, Color(0.95, 0.95, 0.9), maxf(1.0, s * 0.18))

static func record_glyph(ci: CanvasItem, pos: Vector2, s: float, t: float = 0.0):
	ci.draw_circle(pos, s, Color(0.05, 0.05, 0.06))
	ellipse_line(ci, pos, s * 0.8, s * 0.8, Color(0.25, 0.25, 0.28), 1.0, 20)
	ellipse_line(ci, pos, s * 0.62, s * 0.62, Color(0.2, 0.2, 0.22), 1.0, 20)
	ci.draw_circle(pos, s * 0.35, Color(1.0, 0.75, 0.2))
	ci.draw_circle(pos, s * 0.08, Color(0.05, 0.05, 0.05))
	var a = t * 3.0
	ci.draw_line(pos + Vector2(cos(a), sin(a)) * s * 0.45, pos + Vector2(cos(a), sin(a)) * s * 0.9, Color(1, 1, 1, 0.35), 1.5)

static func heart_glyph(ci: CanvasItem, pos: Vector2, s: float, col: Color):
	# martini glass instead of a heart: this is a jazz club
	poly(ci, [pos + Vector2(-s, -s * 0.8), pos + Vector2(s, -s * 0.8), pos + Vector2(0, s * 0.2)], col)
	ci.draw_line(pos + Vector2(0, s * 0.2), pos + Vector2(0, s * 0.9), col, maxf(1.5, s * 0.15))
	ci.draw_line(pos + Vector2(-s * 0.5, s * 0.9), pos + Vector2(s * 0.5, s * 0.9), col, maxf(1.5, s * 0.15))
	ci.draw_circle(pos + Vector2(s * 0.2, -s * 0.5), s * 0.22, Color(0.5, 0.8, 0.2))

static func chroma_color(t: float) -> Color:
	return Color.from_hsv(fmod(t * 0.3, 1.0), 0.5, 1.0)

# ---------------------------------------------------------------------------
# HATS (layered PNG art from art/hats)
# ---------------------------------------------------------------------------
static func hat_layer_paths(hat: Dictionary) -> Array:
	var mat = String(hat.get("material", "cardboard"))
	var brim = String(hat.get("brim_material", mat))
	var band = String(hat.get("band", "cotton"))
	var addon = String(hat.get("addon", "paperclip"))
	return [
		"res://art/hats/brims/brim_%s.png" % brim,
		"res://art/hats/crowns/crown_%s.png" % mat,
		"res://art/hats/bands/band_%s.png" % band,
		"res://art/hats/addons/addon_%s.png" % addon,
	]

## Node2D whose origin is the underside-centre of the brim (sits on a head).
static func make_hat_node(hat: Dictionary, sc: float) -> Node2D:
	var root = Node2D.new()
	for path in hat_layer_paths(hat):
		if ResourceLoader.exists(path):
			var s = Sprite2D.new()
			s.texture = load(path)
			s.offset = Vector2(0, -18)
			s.scale = Vector2(sc, sc)
			s.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
			root.add_child(s)
	return root

static func make_hat_control(hat: Dictionary, size_px: float) -> Control:
	var c = Control.new()
	c.custom_minimum_size = Vector2(size_px, size_px)
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for path in hat_layer_paths(hat):
		if ResourceLoader.exists(path):
			var trect = TextureRect.new()
			trect.texture = load(path)
			trect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			trect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			trect.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
			trect.mouse_filter = Control.MOUSE_FILTER_IGNORE
			trect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
			c.add_child(trect)
	if hat.get("is_chroma", false):
		c.ready.connect(func():
			var tw = c.create_tween().set_loops()
			tw.tween_property(c, "modulate", Color(1.35, 0.8, 1.2), 0.45)
			tw.tween_property(c, "modulate", Color(0.8, 1.3, 1.35), 0.45)
			tw.tween_property(c, "modulate", Color(1.3, 1.3, 0.75), 0.45)
		)
	return c

static func hat_texture(hat: Dictionary, layer: int) -> Texture2D:
	var paths = hat_layer_paths(hat)
	var p = String(paths[clampi(layer, 0, 3)])
	if ResourceLoader.exists(p):
		return load(p)
	return null

# ---------------------------------------------------------------------------
# THE PLAYER: a dapper wind-up robot
# ---------------------------------------------------------------------------
static func robot_bob(t: float, moving: bool) -> float:
	return sin(t * 14.0) * 1.6 if moving else sin(t * 3.0) * 0.8

## skin: optional paint job {body, head, eye, tie, limb} from GameData.SKINS
## pose (cutscenes only): {bob, lift, l1, l2, lx1, lx2, hand_l, hand_r}. Feet lift (l1/l2) and
## spread (lx1/lx2), knee dip (bob), whole-body jump (lift, shadow stays on the floor),
## hands as offsets from the shoulders.
static func draw_robot(ci: CanvasItem, t: float, facing: Vector2, moving: bool, atk: float, body_col: Color = Color(0.16, 0.2, 0.38), skin: Dictionary = {}, number: String = "", pose: Dictionary = {}):
	var head_col: Color = skin.get("head", Color(0.74, 0.77, 0.84))
	var eye_c: Color = skin.get("eye", Color(0.5, 1.7, 2.2))
	var tie_c: Color = skin.get("tie", Color(0.85, 0.12, 0.2))
	var limb_c: Color = skin.get("limb", Color(0.55, 0.58, 0.65))
	var back = facing.y < -0.55
	var fx = clampf(facing.x, -1.0, 1.0)
	var bob = robot_bob(t, moving)
	var step = sin(t * 14.0) if moving else 0.0
	var lift = float(pose.get("lift", 0.0))
	if pose.has("bob"):
		bob = float(pose["bob"])
	var sh_k = clampf(1.0 - lift / 60.0, 0.45, 1.0)
	ellipse(ci, Vector2.ZERO, 22 * sh_k, 7.5 * sh_k, Color(0, 0, 0, 0.18))
	shadow(ci, Vector2.ZERO, 15 * sh_k, 0.32 * sh_k)
	var leg_col = limb_c.darkened(0.4)
	var l1 = maxf(0.0, step) * 3.0
	var l2 = maxf(0.0, -step) * 3.0
	if pose.has("l1"):
		l1 = float(pose["l1"])
		l2 = float(pose.get("l2", 0.0))
	l1 += lift
	l2 += lift
	var lx1 = float(pose.get("lx1", 0.0))
	var lx2 = float(pose.get("lx2", 0.0))
	rrect(ci, Rect2(-9 + lx1, -13 - l1, 7, 12), 3, leg_col)
	rrect(ci, Rect2(2 + lx2, -13 - l2, 7, 12), 3, leg_col)
	ellipse(ci, Vector2(-5.5 + lx1, -2 - l1), 5.5, 3.2, Color(0.08, 0.06, 0.06))
	ellipse(ci, Vector2(5.5 + lx2, -2 - l2), 5.5, 3.2, Color(0.08, 0.06, 0.06))
	ci.draw_line(Vector2(-8 + lx1, -3.5 - l1), Vector2(-4 + lx1, -3.5 - l1), Color(1, 1, 1, 0.25), 1.0)
	ci.draw_line(Vector2(3 + lx2, -3.5 - l2), Vector2(7 + lx2, -3.5 - l2), Color(1, 1, 1, 0.25), 1.0)
	var by = -12.0 + bob - lift
	var key_spin = cos(t * 5.0)
	if not back:
		_draw_key(ci, Vector2(0, by - 20), key_spin, true)
	# arms (behind body when not attacking)
	var sh_l = Vector2(-13, by - 22)
	var sh_r = Vector2(13, by - 22)
	var swing = sin(t * 14.0) * 4.0 if moving else 0.0
	var hand_l = Vector2(-17, by - 9 + swing)
	var hand_r = Vector2(17, by - 9 - swing)
	if pose.has("hand_l"):
		hand_l = sh_l + (pose["hand_l"] as Vector2)
	if pose.has("hand_r"):
		hand_r = sh_r + (pose["hand_r"] as Vector2)
	if atk > 0.0:
		var reach = facing.normalized() * (10.0 + 16.0 * atk)
		if fx >= 0.0:
			hand_r = Vector2(8, by - 18) + reach
		else:
			hand_l = Vector2(-8, by - 18) + reach
	var arm_col = limb_c
	ci.draw_line(sh_l, hand_l, arm_col, 4.0)
	ci.draw_line(sh_r, hand_r, arm_col, 4.0)
	# body
	rrect(ci, Rect2(-15, by - 30, 30, 30), 9, body_col.darkened(0.45))
	rrect(ci, Rect2(-14, by - 29, 28, 28), 8, body_col)
	rrect(ci, Rect2(-14, by - 16, 28, 10), 4, Color(body_col.r * 0.82, body_col.g * 0.82, body_col.b * 0.82, body_col.a))
	rrect(ci, Rect2(-11, by - 27, 22, 6), 3, body_col.lightened(0.18))
	rrect(ci, Rect2(-14, by - 8, 28, 7), 4, body_col.darkened(0.3))
	# rim light on the edge facing the key light
	var rim_x = -12.5 if fx <= 0.2 else 12.5
	ci.draw_line(Vector2(rim_x, by - 25), Vector2(rim_x, by - 7), Color(1, 1, 1, 0.22 * body_col.a), 1.5)
	for rv in [Vector2(-11, by - 24), Vector2(11, by - 24), Vector2(-11, by - 10), Vector2(11, by - 10)]:
		ci.draw_circle(rv, 1.1, body_col.lightened(0.35))
	# a chrome glint sweeps across the chassis every few seconds
	var gl = fmod(t * 0.9, 3.2)
	if gl < 0.5:
		var gx = lerpf(-16.0, 16.0, gl / 0.5)
		ci.draw_line(Vector2(gx - 4, by - 4), Vector2(gx + 4, by - 27), Color(1, 1, 1, 0.3 * sin(gl / 0.5 * PI)), 2.0)
	if not back:
		poly(ci, [Vector2(-6, by - 29), Vector2(6, by - 29), Vector2(0, by - 16)], Style.CREAM)
		var tie = tie_c
		poly(ci, [Vector2(0, by - 26), Vector2(-6, by - 29.5), Vector2(-6, by - 22.5)], tie)
		poly(ci, [Vector2(0, by - 26), Vector2(6, by - 29.5), Vector2(6, by - 22.5)], tie)
		ci.draw_circle(Vector2(0, by - 26), 1.8, tie.darkened(0.3))
		ci.draw_circle(Vector2(0, by - 12), 1.8, Style.GOLD)
		ci.draw_circle(Vector2(0, by - 6.5), 1.8, Style.GOLD)
	else:
		_draw_key(ci, Vector2(0, by - 18), key_spin, false)
	ci.draw_circle(hand_l, 4.2, limb_c.lightened(0.3))
	ci.draw_circle(hand_r, 4.2, limb_c.lightened(0.3))
	# head
	var hy = by - 40.0
	rrect(ci, Rect2(-4, by - 33, 8, 5), 2, Color(0.4, 0.42, 0.48))
	ci.draw_circle(Vector2(0, hy + 0.8), 13.6, head_col.darkened(0.35))
	ci.draw_circle(Vector2(0, hy), 13.0, head_col)
	ci.draw_circle(Vector2(-3, hy - 4), 6.0, head_col.lightened(0.15))
	ci.draw_circle(Vector2(-5, hy - 6), 2.0, Color(1, 1, 1, 0.35 * head_col.a))
	if not back:
		rrect(ci, Rect2(-10 + fx * 2.5, hy - 4, 20, 9), 4, Color(0.04, 0.06, 0.1))
		var blink = fmod(t, 3.7) < 0.12
		var eye_col = eye_c
		var ex = fx * 3.0
		if blink:
			ci.draw_line(Vector2(-7 + ex, hy + 0.5), Vector2(-2 + ex, hy + 0.5), eye_col, 1.5)
			ci.draw_line(Vector2(2 + ex, hy + 0.5), Vector2(7 + ex, hy + 0.5), eye_col, 1.5)
		else:
			for ec in [Vector2(-4.5 + ex, hy + 0.5), Vector2(4.5 + ex, hy + 0.5)]:
				ci.draw_circle(ec, 4.2, Color(eye_col.r, eye_col.g, eye_col.b, 0.18))
				ci.draw_circle(ec, 2.4, eye_col)
				ci.draw_circle(ec + Vector2(-0.8, -0.8), 0.8, Color(2.5, 2.5, 2.5, 0.9))
		ci.draw_line(Vector2(-8 + fx * 2.5, hy - 3), Vector2(-2 + fx * 2.5, hy - 3), Color(1, 1, 1, 0.12), 1.5)
	else:
		ci.draw_circle(Vector2(-6, hy + 3), 1.2, Color(0.4, 0.4, 0.45))
		ci.draw_circle(Vector2(6, hy + 3), 1.2, Color(0.4, 0.4, 0.45))
	# little ear bolts
	ci.draw_circle(Vector2(-13, hy + 1), 2.5, Color(0.5, 0.52, 0.58))
	ci.draw_circle(Vector2(13, hy + 1), 2.5, Color(0.5, 0.52, 0.58))
	if number != "" and not back:
		text(ci, Vector2(8, by - 5), number, 7, Color(1, 1, 1, 0.55), null, 30.0, false)

static func _draw_key(ci: CanvasItem, p: Vector2, spin: float, behind: bool):
	var col = Style.GOLD if not behind else Style.GOLD.darkened(0.25)
	ci.draw_line(p, p + Vector2(0, -3), col, 3.0)
	var w = 7.0 * absf(spin) + 1.0
	ellipse(ci, p + Vector2(-w, -3), maxf(1.0, w * 0.8), 4.5, col)
	ellipse(ci, p + Vector2(w, -3), maxf(1.0, w * 0.8), 4.5, col)

# ---------------------------------------------------------------------------
# ENEMIES
# anim: "idle", "move", "wind" (telegraphing), "act" (attacking), "hurt"
# ---------------------------------------------------------------------------
static func draw_enemy(ci: CanvasItem, kind: String, t: float, facing: Vector2, anim: String, extra: float = 0.0):
	match kind:
		"barfly": _barfly(ci, t, facing, anim)
		"bouncer": _bouncer(ci, t, facing, anim, false)
		"pit_boss": _bouncer(ci, t, facing, anim, true)
		"paparazzi": _paparazzi(ci, t, facing, anim)
		"bottler": _bottler(ci, t, facing, anim)
		"street_rat": _rat(ci, t, facing, anim)
		"alley_cat": _cat(ci, t, facing, anim)
		"sax_ghoul": _sax(ci, t, facing, anim)
		"firebug": _firebug(ci, t, facing, anim)
		"card_sharp": _card(ci, t, facing, anim)
		"loaded_die": _die(ci, t, facing, anim, int(extra))
		"slot_bot": _slotbot(ci, t, facing, anim)
		"conductor": _conductor(ci, t, facing, anim)
		"star_sprite": _starsprite(ci, t, facing, anim)
		"moon_rock": _moonrock(ci, t, facing, anim)
		"comet": _comet(ci, t, facing, anim)
		"satellite": _satellite(ci, t, facing, anim)
		_:
			shadow(ci, Vector2.ZERO, 14)
			ci.draw_circle(Vector2(0, -16), 14, Color(0.6, 0.2, 0.2))

static func _walk(t: float, anim: String) -> float:
	return sin(t * 12.0) if anim == "move" else 0.0

static func _legs(ci: CanvasItem, t: float, anim: String, spread: float, col: Color, h: float = 12.0, w: float = 7.0):
	var s = _walk(t, anim)
	rrect(ci, Rect2(-spread - w * 0.5, -h - maxf(0.0, s) * 3.0, w, h), 2, col)
	rrect(ci, Rect2(spread - w * 0.5, -h - maxf(0.0, -s) * 3.0, w, h), 2, col)

static func _barfly(ci: CanvasItem, t: float, facing: Vector2, anim: String):
	var hover = -24.0 + sin(t * 6.0) * 3.0
	shadow(ci, Vector2.ZERO, 8, 0.25)
	var flap = absf(sin(t * 45.0))
	ellipse(ci, Vector2(-8, hover - 7), 8, 3.0 + flap * 5.0, Color(0.85, 0.95, 1.0, 0.45))
	ellipse(ci, Vector2(8, hover - 7), 8, 3.0 + flap * 5.0, Color(0.85, 0.95, 1.0, 0.45))
	ellipse(ci, Vector2(0, hover), 8, 7, Color(0.12, 0.2, 0.1))
	ellipse(ci, Vector2(0, hover + 2), 6, 3, Color(0.35, 0.5, 0.2))
	var ex = facing.x * 2.5
	var ec = Color(1.6, 0.25, 0.2) if anim == "wind" else Color(0.9, 0.15, 0.12)
	ci.draw_circle(Vector2(-3 + ex, hover - 3), 3.0, ec)
	ci.draw_circle(Vector2(3 + ex, hover - 3), 3.0, ec)
	# tiny martini
	var g = Vector2(9 * signf(facing.x + 0.01), hover + 5)
	poly(ci, [g + Vector2(-4, -4), g + Vector2(4, -4), g + Vector2(0, 1)], Color(0.8, 0.95, 1.0, 0.8))
	ci.draw_line(g + Vector2(0, 1), g + Vector2(0, 5), Color(0.8, 0.95, 1.0, 0.8), 1.0)

static func _bouncer(ci: CanvasItem, t: float, facing: Vector2, anim: String, boss_suit: bool):
	var k = 1.2 if boss_suit else 1.0
	shadow(ci, Vector2.ZERO, 22 * k)
	var suit = Color(0.1, 0.09, 0.11) if not boss_suit else Color(0.32, 0.32, 0.36)
	_legs(ci, t, anim, 8 * k, suit.darkened(0.3), 13, 9 * k)
	var bob = sin(t * 12.0) * 1.2 if anim == "move" else 0.0
	var by = -12.0 + bob
	rrect(ci, Rect2(-20 * k, by - 34 * k, 40 * k, 34 * k), 10, suit)
	if boss_suit:
		for i in range(-3, 4):
			ci.draw_line(Vector2(i * 5 * k, by - 32 * k), Vector2(i * 5 * k, by - 2), Color(0.5, 0.5, 0.55, 0.5), 1.0)
		# gold chain
		ci.draw_arc(Vector2(0, by - 22 * k), 10 * k, 0.3, PI - 0.3, 10, Style.GOLD, 2.0)
	poly(ci, [Vector2(-7, by - 34 * k), Vector2(7, by - 34 * k), Vector2(0, by - 18 * k)], Color(0.92, 0.9, 0.86))
	poly(ci, [Vector2(-2, by - 32 * k), Vector2(2, by - 32 * k), Vector2(3, by - 20 * k), Vector2(0, by - 17 * k), Vector2(-3, by - 20 * k)], Color(0.7, 0.08, 0.1) if not boss_suit else Style.GOLD)
	# shoulders
	ci.draw_circle(Vector2(-18 * k, by - 29 * k), 8 * k, suit)
	ci.draw_circle(Vector2(18 * k, by - 29 * k), 8 * k, suit)
	# fists
	var fist = Color(0.85, 0.62, 0.48)
	if anim == "wind":
		var shake = sin(t * 60.0) * 1.5
		ci.draw_circle(Vector2(-12 * k + shake, by - 56 * k), 7 * k, fist)
		ci.draw_circle(Vector2(12 * k + shake, by - 56 * k), 7 * k, fist)
	elif anim == "act":
		ci.draw_circle(facing * 26 * k + Vector2(0, by - 16), 8 * k, fist)
	else:
		ci.draw_circle(Vector2(-22 * k, by - 12), 6.5 * k, fist)
		ci.draw_circle(Vector2(22 * k, by - 12), 6.5 * k, fist)
	# head
	var hy = by - 42 * k
	ci.draw_circle(Vector2(0, hy), 11 * k, Color(0.82, 0.6, 0.46))
	ci.draw_circle(Vector2(-3 * k, hy - 5 * k), 4 * k, Color(0.95, 0.78, 0.65))
	if facing.y > -0.5:
		var sx = facing.x * 3.0
		rrect(ci, Rect2(-9 * k + sx, hy - 3 * k, 18 * k, 5 * k), 2, Color(0.02, 0.02, 0.03))
		ci.draw_line(Vector2(-6 * k + sx, hy - 2 * k), Vector2(-2 * k + sx, hy - 2 * k), Color(1, 1, 1, 0.5), 1.0)
		ci.draw_line(Vector2(-4 * k + sx, hy + 6 * k), Vector2(4 * k + sx, hy + 6 * k), Color(0.4, 0.2, 0.15), 2.0)
	if boss_suit:
		# fedora + cigar
		ellipse(ci, Vector2(0, hy - 9 * k), 16 * k, 4 * k, Color(0.15, 0.15, 0.17))
		rrect(ci, Rect2(-9 * k, hy - 19 * k, 18 * k, 11 * k), 4, Color(0.15, 0.15, 0.17))
		rrect(ci, Rect2(-9 * k, hy - 12 * k, 18 * k, 3 * k), 1, Color(0.6, 0.1, 0.1))
		if facing.y > -0.5:
			var cg = Vector2(6 * k + facing.x * 4.0, hy + 6 * k)
			ci.draw_line(cg, cg + Vector2(9, 1), Color(0.45, 0.28, 0.15), 3.0)
			ci.draw_circle(cg + Vector2(10, 1), 2.0, Color(2.0, 0.7, 0.2))

static func _paparazzi(ci: CanvasItem, t: float, facing: Vector2, anim: String):
	shadow(ci, Vector2.ZERO, 14)
	var coat = Color(0.62, 0.5, 0.32)
	_legs(ci, t, anim, 5, Color(0.2, 0.18, 0.16), 11, 6)
	var by = -10.0
	rrect(ci, Rect2(-12, by - 28, 24, 30), 6, coat)
	ci.draw_line(Vector2(-12, by - 10), Vector2(12, by - 10), coat.darkened(0.35), 3.0)
	ci.draw_line(Vector2(0, by - 28), Vector2(0, by + 1), coat.darkened(0.25), 1.5)
	var hy = by - 35.0
	ci.draw_circle(Vector2(0, hy), 9, Color(0.86, 0.68, 0.55))
	# fedora with PRESS card
	ellipse(ci, Vector2(0, hy - 6), 14, 3.5, Color(0.28, 0.28, 0.3))
	rrect(ci, Rect2(-8, hy - 16, 16, 10), 3, Color(0.3, 0.3, 0.32))
	rrect(ci, Rect2(-8, hy - 9, 16, 3), 1, Color(0.1, 0.1, 0.1))
	rrect(ci, Rect2(2, hy - 15, 6, 6), 1, Color(0.95, 0.95, 0.9))
	if facing.y > -0.5:
		var cx = facing.x * 5.0
		rrect(ci, Rect2(-8 + cx, hy - 3, 16, 11), 2, Color(0.08, 0.08, 0.09))
		ci.draw_circle(Vector2(cx, hy + 3), 4, Color(0.3, 0.35, 0.45))
		ci.draw_circle(Vector2(cx, hy + 3), 2, Color(0.6, 0.7, 0.9))
		rrect(ci, Rect2(-3 + cx, hy - 9, 8, 6), 1, Color(0.7, 0.7, 0.72))
		if anim == "wind":
			glow(ci, Vector2(1 + cx, hy - 6), 14.0 + sin(t * 40.0) * 3.0, Color(2.0, 2.0, 1.6, 0.9))

static func _bottler(ci: CanvasItem, t: float, facing: Vector2, anim: String):
	shadow(ci, Vector2.ZERO, 15)
	_legs(ci, t, anim, 5, Color(0.08, 0.08, 0.1), 11, 7)
	var by = -10.0
	rrect(ci, Rect2(-13, by - 30, 26, 31), 6, Color(0.92, 0.9, 0.85))
	rrect(ci, Rect2(-13, by - 30, 7, 22), 3, Color(0.1, 0.1, 0.12))
	rrect(ci, Rect2(6, by - 30, 7, 22), 3, Color(0.1, 0.1, 0.12))
	rrect(ci, Rect2(-10, by - 12, 20, 14), 3, Color(1, 1, 1))
	poly(ci, [Vector2(-4, by - 30), Vector2(4, by - 30), Vector2(0, by - 26)], Color(0.1, 0.1, 0.12))
	var hy = by - 38.0
	ci.draw_circle(Vector2(0, hy), 10, Color(0.88, 0.7, 0.56))
	ellipse(ci, Vector2(0, hy - 6), 10, 5, Color(0.08, 0.06, 0.05))
	if facing.y > -0.5:
		var mx = facing.x * 3.0
		ci.draw_circle(Vector2(-3.5 + mx, hy), 1.5, Color(0.1, 0.1, 0.1))
		ci.draw_circle(Vector2(3.5 + mx, hy), 1.5, Color(0.1, 0.1, 0.1))
		poly(ci, [Vector2(-7 + mx, hy + 5), Vector2(0 + mx, hy + 3), Vector2(7 + mx, hy + 5), Vector2(0 + mx, hy + 6)], Color(0.35, 0.2, 0.1))
	var bottle_p = Vector2(15, by - 18) if anim != "wind" else Vector2(8, hy - 20 + sin(t * 30.0) * 2.0)
	rrect(ci, Rect2(bottle_p.x - 4, bottle_p.y - 6, 8, 13), 2, Color(0.15, 0.55, 0.25, 0.95))
	rrect(ci, Rect2(bottle_p.x - 1.5, bottle_p.y - 12, 3, 7), 1, Color(0.15, 0.55, 0.25, 0.95))
	rrect(ci, Rect2(bottle_p.x - 3, bottle_p.y - 2, 6, 4), 1, Color(0.95, 0.85, 0.6))

static func _rat(ci: CanvasItem, t: float, facing: Vector2, anim: String):
	shadow(ci, Vector2.ZERO, 11, 0.3)
	var f = facing.normalized() if facing.length() > 0.1 else Vector2.RIGHT
	var body_c = Vector2(0, -8)
	var tail_pts = PackedVector2Array()
	for i in range(8):
		var k = float(i) / 7.0
		tail_pts.append(body_c - f * (10.0 + k * 16.0) + f.orthogonal() * sin(t * 10.0 + k * 4.0) * 4.0 * k)
	ci.draw_polyline(tail_pts, Color(0.85, 0.55, 0.6), 2.0)
	ellipse(ci, body_c, 12, 7.5, Color(0.42, 0.4, 0.44))
	var head = body_c + f * 11.0
	ci.draw_circle(head, 6.5, Color(0.48, 0.46, 0.5))
	ci.draw_circle(head + f * 6.0, 2.0, Color(0.95, 0.55, 0.6))
	ci.draw_circle(head - f * 2.0 + f.orthogonal() * 5.0 + Vector2(0, -3), 3.5, Color(0.9, 0.6, 0.65))
	ci.draw_circle(head - f * 2.0 - f.orthogonal() * 5.0 + Vector2(0, -3), 3.5, Color(0.9, 0.6, 0.65))
	ci.draw_circle(head + f * 2.0 + Vector2(0, -2), 1.6, Color(1.5, 0.2, 0.2))
	# flat cap
	ellipse(ci, head + Vector2(0, -6), 7, 3, Color(0.25, 0.2, 0.15))
	ellipse(ci, head + Vector2(0, -6) + f * 5.0, 4, 2, Color(0.2, 0.16, 0.12))

static func _cat(ci: CanvasItem, t: float, facing: Vector2, anim: String):
	shadow(ci, Vector2.ZERO, 15, 0.35)
	var fx = 1.0 if facing.x >= 0.0 else -1.0
	var arch = 5.0 if anim == "wind" else 0.0
	var black = Color(0.07, 0.07, 0.09)
	var tail = PackedVector2Array()
	for i in range(8):
		var k = float(i) / 7.0
		tail.append(Vector2(-fx * (12.0 + k * 8.0), -12.0 - k * 18.0 + sin(t * 5.0 + k * 3.0) * 3.0))
	ci.draw_polyline(tail, black, 4.0)
	_legs(ci, t, anim, 8, black, 9, 4)
	ellipse(ci, Vector2(0, -14 - arch), 15, 8 + arch * 0.5, black)
	var head = Vector2(fx * 12.0, -24.0 - arch)
	ci.draw_circle(head, 8, black)
	poly(ci, [head + Vector2(-7, -3), head + Vector2(-5, -13), head + Vector2(-1, -6)], black)
	poly(ci, [head + Vector2(7, -3), head + Vector2(5, -13), head + Vector2(1, -6)], black)
	var eye = Color(2.0, 1.7, 0.3) if anim == "wind" else Color(1.2, 1.0, 0.2)
	ellipse(ci, head + Vector2(-3 + fx, -1), 2.2, 2.6, eye)
	ellipse(ci, head + Vector2(3 + fx, -1), 2.2, 2.6, eye)
	ci.draw_line(head + Vector2(-3 + fx, -3), head + Vector2(-3 + fx, 1), Color(0, 0, 0), 1.0)
	ci.draw_line(head + Vector2(3 + fx, -3), head + Vector2(3 + fx, 1), Color(0, 0, 0), 1.0)
	# red collar
	ci.draw_line(head + Vector2(-6, 6), head + Vector2(6, 6), Color(0.8, 0.1, 0.15), 2.5)

static func _sax(ci: CanvasItem, t: float, facing: Vector2, anim: String):
	var float_y = -10.0 + sin(t * 3.0) * 3.0
	shadow(ci, Vector2.ZERO, 13, 0.2)
	var gc = Color(0.45, 0.85, 1.0, 0.55)
	var pts = PackedVector2Array()
	pts.append(Vector2(-13, float_y - 30))
	pts.append(Vector2(13, float_y - 30))
	pts.append(Vector2(15, float_y - 5))
	for i in range(7):
		var k = float(i) / 6.0
		pts.append(Vector2(15.0 - k * 30.0, float_y + sin(t * 8.0 + k * 9.0) * 3.0))
	pts.append(Vector2(-15, float_y - 5))
	ci.draw_colored_polygon(pts, gc)
	ci.draw_circle(Vector2(0, float_y - 38), 10, gc)
	# wide-brim ghost hat
	ellipse(ci, Vector2(0, float_y - 45), 15, 3.5, Color(0.3, 0.6, 0.8, 0.7))
	rrect(ci, Rect2(-8, float_y - 55, 16, 10), 3, Color(0.3, 0.6, 0.8, 0.7))
	if facing.y > -0.5:
		ci.draw_circle(Vector2(-3.5, float_y - 39), 2.5, Color(0.02, 0.05, 0.1))
		ci.draw_circle(Vector2(3.5, float_y - 39), 2.5, Color(0.02, 0.05, 0.1))
	# golden sax
	var sx = 7.0 * (1.0 if facing.x >= 0.0 else -1.0)
	var gold = Color(1.4, 1.0, 0.35) if anim == "wind" else Color(1.0, 0.75, 0.25)
	var sax = PackedVector2Array([Vector2(sx * 0.2, float_y - 34), Vector2(sx, float_y - 26), Vector2(sx, float_y - 12), Vector2(sx + 4.0 * signf(sx), float_y - 8)])
	ci.draw_polyline(sax, gold, 4.0)
	ci.draw_circle(Vector2(sx + 5.0 * signf(sx), float_y - 10), 4.5, gold)

static func _firebug(ci: CanvasItem, t: float, facing: Vector2, anim: String):
	shadow(ci, Vector2.ZERO, 14)
	var f = facing.normalized() if facing.length() > 0.1 else Vector2.RIGHT
	for i in range(3):
		var side = f.orthogonal()
		var ph = sin(t * 18.0 + i * 2.0) * 3.0 if anim == "move" else 0.0
		var base = Vector2(0, -8) + f * (float(i) - 1.0) * 6.0
		ci.draw_line(base, base + side * 12.0 + Vector2(0, 6 + ph), Color(0.15, 0.08, 0.05), 2.0)
		ci.draw_line(base, base - side * 12.0 + Vector2(0, 6 - ph), Color(0.15, 0.08, 0.05), 2.0)
	var pulse = 0.5 + 0.5 * sin(t * (30.0 if anim == "wind" else 5.0))
	var abd = Vector2(0, -10) - f * 6.0
	var hot = Color(2.0, 0.8, 0.2).lerp(Color(2.5, 2.3, 2.0), pulse if anim == "wind" else 0.0)
	glow(ci, abd, 16.0 + pulse * 5.0, Color(1.5, 0.6, 0.1, 0.6))
	ellipse(ci, abd, 10, 8, hot)
	ellipse(ci, Vector2(0, -12) + f * 4.0, 8, 7, Color(0.25, 0.12, 0.06))
	var head = Vector2(0, -13) + f * 11.0
	ci.draw_circle(head, 5, Color(0.2, 0.1, 0.05))
	ci.draw_circle(head + f * 2.0 + f.orthogonal() * 2.0, 1.5, Color(1, 0.9, 0.3))
	ci.draw_circle(head + f * 2.0 - f.orthogonal() * 2.0, 1.5, Color(1, 0.9, 0.3))

static func _card(ci: CanvasItem, t: float, facing: Vector2, anim: String):
	shadow(ci, Vector2.ZERO, 14)
	_legs(ci, t, anim, 5, Color(0.05, 0.05, 0.05), 11, 3)
	var tilt = sin(t * 12.0) * 2.0 if anim == "move" else 0.0
	var r = Rect2(-13 + tilt * 0.5, -48, 26, 38)
	rrect(ci, r, 4, Color(0.97, 0.96, 0.92))
	ellipse_line(ci, r.get_center(), 11, 16, Color(0.8, 0.1, 0.12, 0.3), 1.0)
	var c = r.get_center()
	var red = facing.x < 0.0
	var suit_col = Color(0.8, 0.1, 0.12) if red else Color(0.08, 0.08, 0.1)
	if red:
		ci.draw_circle(c + Vector2(-4, -3), 5, suit_col)
		ci.draw_circle(c + Vector2(4, -3), 5, suit_col)
		poly(ci, [c + Vector2(-9, -1), c + Vector2(9, -1), c + Vector2(0, 10)], suit_col)
	else:
		poly(ci, [c + Vector2(0, -10), c + Vector2(-9, 2), c + Vector2(9, 2)], suit_col)
		ci.draw_circle(c + Vector2(-4.5, 2), 4.5, suit_col)
		ci.draw_circle(c + Vector2(4.5, 2), 4.5, suit_col)
		poly(ci, [c + Vector2(0, 2), c + Vector2(-3, 9), c + Vector2(3, 9)], suit_col)
	text_left(ci, r.position + Vector2(3, 10), "A", 10, suit_col, null)
	# eyes (angry)
	ci.draw_line(c + Vector2(-8, -13), c + Vector2(-3, -11), Color(0, 0, 0), 2.0)
	ci.draw_line(c + Vector2(8, -13), c + Vector2(3, -11), Color(0, 0, 0), 2.0)
	# arms holding cards
	var hand = Vector2(15, -30) if facing.x >= 0.0 else Vector2(-15, -30)
	ci.draw_line(Vector2(signf(hand.x) * 12, -30), hand, Color(0.05, 0.05, 0.05), 2.0)
	if anim == "wind":
		for i in range(3):
			var a = -0.4 + i * 0.4
			var d = Vector2(cos(a - PI * 0.5), sin(a - PI * 0.5))
			ci.draw_line(hand, hand + d * 10.0, Color(1, 1, 1), 4.0)
	# mini top hat
	ellipse(ci, Vector2(tilt * 0.5, -48), 10, 2.5, Color(0.05, 0.05, 0.06))
	rrect(ci, Rect2(-6 + tilt * 0.5, -60, 12, 12), 1, Color(0.05, 0.05, 0.06))
	rrect(ci, Rect2(-6 + tilt * 0.5, -52, 12, 2), 0, Color(0.8, 0.1, 0.12))

static func _die(ci: CanvasItem, t: float, facing: Vector2, anim: String, face: int):
	shadow(ci, Vector2.ZERO, 17)
	var wob = sin(t * 20.0) * 2.0 if anim == "move" else 0.0
	var top = PackedVector2Array([Vector2(-15, -32 + wob), Vector2(-7, -40 + wob), Vector2(21, -40 + wob), Vector2(15, -32 + wob)])
	ci.draw_colored_polygon(top, Color(1, 1, 1))
	var side = PackedVector2Array([Vector2(15, -32 + wob), Vector2(21, -40 + wob), Vector2(21, -10 + wob), Vector2(15, -2 + wob)])
	ci.draw_colored_polygon(side, Color(0.72, 0.72, 0.76))
	rrect(ci, Rect2(-15, -32 + wob, 30, 30), 4, Color(0.92, 0.92, 0.9))
	var c = Vector2(0, -17 + wob)
	var pc = Color(0.85, 0.1, 0.15) if anim == "wind" else Color(0.08, 0.08, 0.1)
	var n = clampi(face, 1, 6)
	var o = 8.0
	var spots = []
	match n:
		1: spots = [Vector2.ZERO]
		2: spots = [Vector2(-o, -o), Vector2(o, o)]
		3: spots = [Vector2(-o, -o), Vector2.ZERO, Vector2(o, o)]
		4: spots = [Vector2(-o, -o), Vector2(o, -o), Vector2(-o, o), Vector2(o, o)]
		5: spots = [Vector2(-o, -o), Vector2(o, -o), Vector2.ZERO, Vector2(-o, o), Vector2(o, o)]
		_: spots = [Vector2(-o, -o), Vector2(o, -o), Vector2(-o, 0), Vector2(o, 0), Vector2(-o, o), Vector2(o, o)]
	for s in spots:
		ci.draw_circle(c + s, 3.0, pc)

static func _slotbot(ci: CanvasItem, t: float, facing: Vector2, anim: String):
	shadow(ci, Vector2.ZERO, 22)
	rrect(ci, Rect2(-22, -10, 44, 10), 4, Color(0.15, 0.15, 0.17))
	for i in range(4):
		ci.draw_circle(Vector2(-16 + i * 10.7, -5), 3, Color(0.35, 0.35, 0.38))
	rrect(ci, Rect2(-20, -62, 40, 54), 6, Color(0.7, 0.1, 0.14))
	rrect(ci, Rect2(-20, -62, 40, 8), 4, Color(0.85, 0.75, 0.4))
	rrect(ci, Rect2(-16, -48, 32, 16), 3, Color(0.95, 0.93, 0.88))
	var spin = anim == "act" or anim == "wind"
	for i in range(3):
		var cx = -10.7 + i * 10.7
		var sym = int(t * 12.0 + i * 1.7) % 3 if spin else i
		match sym:
			0:
				ci.draw_circle(Vector2(cx - 2, -38), 2.5, Color(0.85, 0.1, 0.1))
				ci.draw_circle(Vector2(cx + 2, -38), 2.5, Color(0.85, 0.1, 0.1))
			1:
				text(ci, Vector2(cx, -34), "7", 13, Color(0.9, 0.1, 0.1), null, 20.0, false)
			_:
				rrect(ci, Rect2(cx - 4, -42, 8, 6), 1, Color(0.1, 0.1, 0.1))
	for i in range(5):
		var on = int(t * 8.0 + i) % 2 == 0
		ci.draw_circle(Vector2(-16 + i * 8, -58), 1.8, Color(2.0, 1.7, 0.6) if on else Color(0.5, 0.4, 0.2))
	# lever
	var la = -0.6 if anim != "wind" else 0.4
	var lp = Vector2(20, -40)
	ci.draw_line(lp, lp + Vector2(cos(la - PI * 0.5), sin(la - PI * 0.5)) * 20.0 + Vector2(6, 0), Color(0.8, 0.8, 0.85), 3.0)
	ci.draw_circle(lp + Vector2(cos(la - PI * 0.5), sin(la - PI * 0.5)) * 20.0 + Vector2(6, 0), 4.5, Color(0.9, 0.1, 0.1))
	# angry visor
	rrect(ci, Rect2(-14, -28, 28, 8), 2, Color(0.08, 0.02, 0.03))
	ci.draw_circle(Vector2(-6, -24), 2.5, Color(2.0, 0.3, 0.2))
	ci.draw_circle(Vector2(6, -24), 2.5, Color(2.0, 0.3, 0.2))

static func _conductor(ci: CanvasItem, t: float, facing: Vector2, anim: String):
	shadow(ci, Vector2.ZERO, 12)
	_legs(ci, t, anim, 4, Color(0.05, 0.05, 0.06), 12, 5)
	var by = -12.0
	poly(ci, [Vector2(-10, by - 32), Vector2(10, by - 32), Vector2(12, by + 4), Vector2(4, by - 2), Vector2(0, by + 6), Vector2(-4, by - 2), Vector2(-12, by + 4)], Color(0.05, 0.05, 0.07))
	poly(ci, [Vector2(-5, by - 32), Vector2(5, by - 32), Vector2(0, by - 16)], Color(0.95, 0.95, 0.95))
	poly(ci, [Vector2(0, by - 30), Vector2(-4, by - 32), Vector2(-4, by - 28)], Color(0.1, 0.1, 0.1))
	poly(ci, [Vector2(0, by - 30), Vector2(4, by - 32), Vector2(4, by - 28)], Color(0.1, 0.1, 0.1))
	var hy = by - 40.0
	ci.draw_circle(Vector2(0, hy), 8, Color(0.92, 0.82, 0.75))
	ci.draw_circle(Vector2(-8, hy - 5), 5, Color(0.97, 0.97, 1.0))
	ci.draw_circle(Vector2(8, hy - 5), 5, Color(0.97, 0.97, 1.0))
	ci.draw_circle(Vector2(0, hy - 9), 5, Color(0.97, 0.97, 1.0))
	if facing.y > -0.5:
		ci.draw_circle(Vector2(-3, hy), 1.2, Color(0, 0, 0))
		ci.draw_circle(Vector2(3, hy), 1.2, Color(0, 0, 0))
	var wave = sin(t * (14.0 if anim == "act" else 4.0))
	var hand = Vector2(14, by - 30 + wave * 6.0)
	ci.draw_line(Vector2(8, by - 28), hand, Color(0.05, 0.05, 0.07), 3.0)
	ci.draw_circle(hand, 3, Color(1, 1, 1))
	var tip = hand + Vector2(cos(-1.0 + wave * 0.5), sin(-1.0 + wave * 0.5)) * 16.0
	ci.draw_line(hand, tip, Color(0.95, 0.95, 0.9), 1.5)
	if anim == "act":
		glow(ci, tip, 10.0, Color(1.5, 1.3, 0.6, 0.8))

static func _starsprite(ci: CanvasItem, t: float, facing: Vector2, anim: String):
	var hover = -26.0 + sin(t * 5.0) * 4.0
	shadow(ci, Vector2.ZERO, 9, 0.2)
	var col = Color(2.0, 1.8, 0.6) if anim == "wind" else Color(1.3, 1.15, 0.45)
	glow(ci, Vector2(0, hover), 20, Color(1.2, 1.0, 0.4, 0.5))
	star(ci, Vector2(0, hover), 13, 6, 5, col, t * 2.0)
	ci.draw_circle(Vector2(-3, hover - 1), 1.5, Color(0.2, 0.1, 0.0))
	ci.draw_circle(Vector2(3, hover - 1), 1.5, Color(0.2, 0.1, 0.0))
	ci.draw_arc(Vector2(0, hover + 2), 3, 0.2, PI - 0.2, 6, Color(0.2, 0.1, 0.0), 1.2)

static func _moonrock(ci: CanvasItem, t: float, facing: Vector2, anim: String):
	shadow(ci, Vector2.ZERO, 24)
	var bob = sin(t * 10.0) * 1.5 if anim == "move" else 0.0
	var c = Vector2(0, -24 + bob)
	ci.draw_circle(c + Vector2(-22, 6), 8, Color(0.5, 0.5, 0.56))
	ci.draw_circle(c + Vector2(22, 6), 8, Color(0.5, 0.5, 0.56))
	if anim == "wind":
		ci.draw_circle(c + Vector2(-16, -26), 9, Color(0.55, 0.55, 0.6))
		ci.draw_circle(c + Vector2(16, -26), 9, Color(0.55, 0.55, 0.6))
	ellipse(ci, c, 22, 20, Color(0.58, 0.58, 0.64))
	ellipse(ci, c + Vector2(-5, -6), 14, 10, Color(0.66, 0.66, 0.72))
	ci.draw_circle(c + Vector2(8, 8), 5, Color(0.45, 0.45, 0.5))
	ci.draw_circle(c + Vector2(-10, 10), 3, Color(0.45, 0.45, 0.5))
	ci.draw_circle(c + Vector2(12, -8), 3.5, Color(0.45, 0.45, 0.5))
	var ec = Color(0.5, 1.6, 2.2) if anim != "wind" else Color(2.2, 1.0, 0.6)
	var ex = facing.x * 4.0
	ci.draw_line(c + Vector2(-9 + ex, -3), c + Vector2(-3 + ex, -1), ec, 3.0)
	ci.draw_line(c + Vector2(9 + ex, -3), c + Vector2(3 + ex, -1), ec, 3.0)
	ci.draw_line(c + Vector2(-2, 6), c + Vector2(4, 12), Color(0.4, 1.2, 1.8, 0.6), 1.5)

static func _comet(ci: CanvasItem, t: float, facing: Vector2, anim: String):
	shadow(ci, Vector2.ZERO, 12, 0.25)
	var f = facing.normalized() if facing.length() > 0.1 else Vector2.RIGHT
	var c = Vector2(0, -20)
	var side = f.orthogonal()
	var tail_len = 46.0 if anim == "act" else 26.0
	var tl = PackedVector2Array([c + side * 11.0, c - f * tail_len + side * 3.0 * sin(t * 20.0), c - side * 11.0])
	ci.draw_colored_polygon(tl, Color(0.4, 0.8, 1.4, 0.45))
	glow(ci, c, 18, Color(0.5, 0.9, 1.5, 0.5))
	ci.draw_circle(c, 11, Color(0.75, 0.95, 1.4) if anim != "wind" else Color(1.8, 1.8, 2.2))
	ci.draw_circle(c + f * 3.0 + side * 3.5, 2, Color(0.05, 0.1, 0.25))
	ci.draw_circle(c + f * 3.0 - side * 3.5, 2, Color(0.05, 0.1, 0.25))

static func _satellite(ci: CanvasItem, t: float, facing: Vector2, anim: String):
	var hover = -30.0 + sin(t * 2.0) * 3.0
	shadow(ci, Vector2.ZERO, 18, 0.2)
	var c = Vector2(0, hover)
	for sgn in [-1.0, 1.0]:
		var pr = Rect2(c.x + sgn * 14.0 - (18.0 if sgn < 0.0 else 0.0), c.y - 6, 18, 12)
		rrect(ci, pr, 1, Color(0.15, 0.25, 0.6))
		for i in range(3):
			ci.draw_line(Vector2(pr.position.x + 6 * (i + 1) - 1, pr.position.y), Vector2(pr.position.x + 6 * (i + 1) - 1, pr.end.y), Color(0.5, 0.7, 1.0, 0.6), 1.0)
		ci.draw_line(c, c + Vector2(sgn * 14.0, 0), Color(0.7, 0.7, 0.75), 2.0)
	rrect(ci, Rect2(c.x - 11, c.y - 11, 22, 22), 4, Color(0.82, 0.8, 0.72))
	rrect(ci, Rect2(c.x - 11, c.y - 11, 22, 6), 2, Style.GOLD)
	ci.draw_arc(c + Vector2(0, -16), 7, PI * 1.1, PI * 1.9, 8, Color(0.9, 0.9, 0.95), 2.0)
	ci.draw_line(c + Vector2(0, -11), c + Vector2(0, -17), Color(0.9, 0.9, 0.95), 1.5)
	var blink = int(t * 3.0) % 2 == 0
	ci.draw_circle(c + Vector2(0, 3), 3, Color(2.0, 0.2, 0.2) if (blink or anim == "wind") else Color(0.4, 0.05, 0.05))

# ---------------------------------------------------------------------------
# REWARD ICONS (doors, rewards, codex)
# ---------------------------------------------------------------------------
static func reward_icon(ci: CanvasItem, pos: Vector2, kind: String, patron: String, s: float, door_type: String = "", t: float = 0.0):
	var col = Style.CREAM
	match door_type:
		"shop":
			ci.draw_circle(pos, s, Color(0.1, 0.3, 0.15))
			text(ci, pos + Vector2(0, s * 0.45), "$", int(s * 1.3), Color(1.4, 1.2, 0.5), Style.font_title, s * 3.0, false)
			return
		"rest":
			heart_glyph(ci, pos, s * 0.8, Color(1.8, 0.8, 1.3))
			return
		"jackpot":
			ci.draw_circle(pos, s, Color(0.4, 0.05, 0.08))
			text(ci, pos + Vector2(0, s * 0.35), "777", int(s * 0.8), Color(2.0, 1.7, 0.5), Style.font_mono, s * 3.0, false)
			return
		"boss":
			star(ci, pos, s, s * 0.45, 5, Color(2.0, 0.4, 0.3), t)
			return
	match kind:
		"boon":
			var pc: Color = BoonDataRef.PATRONS[patron]["color"]
			glow(ci, pos, s * 1.6, Color(pc.r, pc.g, pc.b, 0.5), 4)
			ci.draw_circle(pos, s, Color(0.05, 0.04, 0.06))
			ci.draw_arc(pos, s, 0, TAU, 24, Color(pc.r * 1.5, pc.g * 1.5, pc.b * 1.5), 3.0, true)
			text(ci, pos + Vector2(0, s * 0.42), String(BoonDataRef.PATRONS[patron]["glyph"]), int(s * 1.2), Color(pc.r * 1.5, pc.g * 1.5, pc.b * 1.5), null, s * 3.0, false)
		"rp":
			glow(ci, pos, s * 1.5, Color(1.6, 1.2, 0.4, 0.5), 3)
			note_glyph(ci, pos, s, Color(2.0, 1.6, 0.6))
		"chips":
			chip_glyph(ci, pos, s * 0.8, Color(0.85, 0.12, 0.15))
		"martini":
			heart_glyph(ci, pos, s * 0.8, Color(0.8, 1.6, 1.8))
		"encore":
			ci.draw_circle(pos, s, Color(0.08, 0.06, 0.03))
			ci.draw_arc(pos, s, 0, TAU, 24, Color(2.0, 1.6, 0.5), 3.0, true)
			text(ci, pos + Vector2(0, s * 0.45), "+", int(s * 1.5), Color(2.0, 1.6, 0.5), Style.font_mono, s * 3.0, false)
		"hat_mod":
			ellipse(ci, pos + Vector2(0, s * 0.35), s * 1.1, s * 0.3, Color(1.6, 1.5, 1.3))
			rrect(ci, Rect2(pos.x - s * 0.55, pos.y - s * 0.7, s * 1.1, s * 1.0), 3, Color(1.6, 1.5, 1.3))
			ci.draw_rect(Rect2(pos.x - s * 0.55, pos.y + s * 0.05, s * 1.1, s * 0.18), Color(0.8, 0.1, 0.2))
		"records":
			glow(ci, pos, s * 1.6, Color(1.6, 1.2, 0.4, 0.5), 4)
			record_glyph(ci, pos, s, t)
		_:
			ci.draw_circle(pos, s, col)

# ---------------------------------------------------------------------------
# BOSS PORTRAITS (codex + trailer). Each boss runs a hat empire, so each wears one.
# ---------------------------------------------------------------------------
static func bowler(ci: CanvasItem, p: Vector2, s: float, col: Color = Color(0.1, 0.09, 0.1)):
	ellipse(ci, p, 17.0 * s, 4.5 * s, col)
	var dome = PackedVector2Array()
	for i in range(13):
		var a = PI + PI * float(i) / 12.0
		dome.append(p + Vector2(cos(a) * 11.0 * s, sin(a) * 12.0 * s - 1.0 * s))
	ci.draw_colored_polygon(dome, col)
	ci.draw_rect(Rect2(p.x - 11.0 * s, p.y - 4.0 * s, 22.0 * s, 3.0 * s), Color(0.55, 0.1, 0.12))
	ci.draw_circle(p + Vector2(-4.0 * s, -9.0 * s), 2.5 * s, Color(1, 1, 1, 0.12))

static func top_hat(ci: CanvasItem, p: Vector2, s: float, band: Color = Color(0.75, 0.1, 0.2)):
	ellipse(ci, p, 26.0 * s, 6.0 * s, Color(0.06, 0.05, 0.08))
	rrect(ci, Rect2(p.x - 16.0 * s, p.y - 36.0 * s, 32.0 * s, 36.0 * s), 3.0 * s, Color(0.08, 0.07, 0.1))
	ci.draw_rect(Rect2(p.x - 16.0 * s, p.y - 10.0 * s, 32.0 * s, 6.0 * s), band)
	ci.draw_line(p + Vector2(-10.0 * s, -32.0 * s), p + Vector2(-10.0 * s, -14.0 * s), Color(1, 1, 1, 0.1), 2.0 * s)

static func trilby(ci: CanvasItem, p: Vector2, s: float, col: Color = Color(0.2, 0.2, 0.24)):
	ellipse(ci, p, 16.0 * s, 4.0 * s, col.darkened(0.2))
	rrect(ci, Rect2(p.x - 10.0 * s, p.y - 11.0 * s, 20.0 * s, 11.0 * s), 4.0 * s, col)
	ci.draw_rect(Rect2(p.x - 10.0 * s, p.y - 4.0 * s, 20.0 * s, 3.0 * s), Color(0.9, 0.2, 0.7))

static func boss_portrait(ci: CanvasItem, kind: String, t: float, pos: Vector2, s: float):
	match kind:
		"big_sal":
			shadow(ci, pos, 40.0 * s)
			ci.draw_set_transform(pos, 0.0, Vector2(2.2 * s, 2.2 * s))
			draw_enemy(ci, "bouncer", t, Vector2.DOWN, "idle", 0.0)
			bowler(ci, Vector2(0, -61), 1.0)
			ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		"getaway_car":
			shadow(ci, pos, 70.0 * s)
			ci.draw_set_transform(pos + Vector2(0, -20.0 * s), -0.25, Vector2(s, s))
			rrect(ci, Rect2(-62, -28, 124, 56), 22, Color(0.35, 0.05, 0.1))
			rrect(ci, Rect2(-58, -24, 116, 48), 18, Color(0.5, 0.08, 0.14))
			rrect(ci, Rect2(-30, -21, 56, 42), 12, Color(0.28, 0.04, 0.08))
			rrect(ci, Rect2(14, -18, 14, 36), 5, Color(0.2, 0.3, 0.45, 0.9))
			rrect(ci, Rect2(54, -24, 10, 48), 4, Color(0.85, 0.85, 0.9))
			ci.draw_circle(Vector2(58, -16), 5, Color(2.2, 2.0, 1.2))
			ci.draw_circle(Vector2(58, 16), 5, Color(2.2, 2.0, 1.2))
			trilby(ci, Vector2(-4, -6), 0.8)
			trilby(ci, Vector2(-4, 16), 0.8)
			ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		"big_band":
			var c = pos + Vector2(0, -70.0 * s)
			shadow(ci, pos, 70.0 * s)
			ci.draw_set_transform(c, 0.0, Vector2(s, s))
			rrect(ci, Rect2(-50, -30, 100, 100), 10, Color(0.45, 0.22, 0.08))
			for k in range(3):
				var col = Color.from_hsv(fmod(t * 0.35 + k * 0.18, 1.0), 0.8, 1.8)
				ci.draw_line(Vector2(-44 + k * 8, -30), Vector2(-44 + k * 8, 66), col, 3.0)
				ci.draw_line(Vector2(44 - k * 8, -30), Vector2(44 - k * 8, 66), col, 3.0)
			record_glyph(ci, Vector2(0, -6), 18, t * 3.0)
			rrect(ci, Rect2(-24, 20, 48, 44), 6, Color(0.9, 0.75, 0.4))
			ci.draw_circle(Vector2(-10, 34), 5, Color(2.0, 0.4, 0.3))
			ci.draw_circle(Vector2(10, 34), 5, Color(2.0, 0.4, 0.3))
			top_hat(ci, Vector2(0, -30), 1.3, Style.GOLD)
			ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		"moon_man":
			var mc = pos + Vector2(0, -70.0 * s)
			glow(ci, mc, 100.0 * s, Color(1.2, 1.1, 0.6, 0.3), 4)
			ci.draw_set_transform(mc, 0.0, Vector2(s, s))
			var pts = PackedVector2Array()
			for i in range(33):
				var a = deg_to_rad(60.0 + 240.0 * float(i) / 32.0)
				pts.append(Vector2(cos(a), sin(a)) * 60.0)
			for i in range(1, 32):
				var a2 = deg_to_rad(265.3 - 170.6 * float(i) / 32.0)
				pts.append(Vector2(34.3, 0) + Vector2(cos(a2), sin(a2)) * 52.1)
			ci.draw_colored_polygon(pts, Color(1.35, 1.25, 0.8))
			ci.draw_arc(Vector2(-26, -16), 5, 0.2, PI - 0.2, 8, Color(0.4, 0.3, 0.1), 3.0)
			ci.draw_arc(Vector2(-28, 18), 10, 0.2, 1.4, 8, Color(0.5, 0.3, 0.15), 3.0)
			ci.draw_set_transform(mc + Vector2(-22, -52) * s, -0.35, Vector2(s, s))
			top_hat(ci, Vector2.ZERO, 1.2)
			star(ci, Vector2(12, -9), 5, 2.0, 5, Color(2.0, 1.8, 0.8), t)
			ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

# ---------------------------------------------------------------------------
# HAT GRADE BADGE (C / B / A / S)
# ---------------------------------------------------------------------------
static func grade_badge(ci: CanvasItem, pos: Vector2, grade: String, col: Color, r: float):
	if grade == "S":
		# sunburst behind the top grade
		for i in range(12):
			var a = TAU * float(i) / 12.0
			var tip = pos + Vector2(cos(a), sin(a)) * r * 1.3
			var s1 = pos + Vector2(cos(a - 0.16), sin(a - 0.16)) * r * 0.9
			var s2 = pos + Vector2(cos(a + 0.16), sin(a + 0.16)) * r * 0.9
			ci.draw_colored_polygon(PackedVector2Array([s1, tip, s2]), Color(col.r * 1.5, col.g * 1.5, col.b * 1.5, 0.55))
	elif grade == "A":
		for i in range(4):
			var a2 = TAU * float(i) / 4.0 + 0.785
			star(ci, pos + Vector2(cos(a2), sin(a2)) * r * 1.08, r * 0.2, r * 0.07, 4, Color(col.r * 1.6, col.g * 1.6, col.b * 1.6, 0.8), 0.0)
	ci.draw_circle(pos, r, Color(0.05, 0.04, 0.06))
	ci.draw_arc(pos, r, 0, TAU, 32, Color(col.r * 1.4, col.g * 1.4, col.b * 1.4), maxf(2.0, r * 0.12), true)
	text(ci, pos + Vector2(0, r * 0.42), grade, int(r * 1.3), Color(col.r * 1.4, col.g * 1.4, col.b * 1.4), Style.font_title, r * 3.0, false)

static func make_grade_badge(hat: Dictionary, size_px: float) -> Control:
	var c = Control.new()
	c.custom_minimum_size = Vector2(size_px, size_px)
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var g = GameData.hat_grade(hat)
	var col = GameData.hat_grade_color(hat)
	c.draw.connect(func(): grade_badge(c, Vector2(size_px, size_px) * 0.5, g, col, size_px * 0.38))
	return c

# ---------------------------------------------------------------------------
# THE HEADLINERS (patron portraits). Outsiders, not robots, each in homemade headwear.
# pos = bottom-centre of the bust. Roughly 150px tall at s = 1.
# ---------------------------------------------------------------------------
static func _rot_ellipse(ci: CanvasItem, c: Vector2, rx: float, ry: float, ang: float, col: Color):
	var pts = PackedVector2Array()
	for i in range(20):
		var a = TAU * float(i) / 20.0
		pts.append(c + Vector2(cos(a) * rx, sin(a) * ry).rotated(ang))
	ci.draw_colored_polygon(pts, col)

static func _rot_rect(ci: CanvasItem, c: Vector2, w: float, h: float, ang: float, col: Color):
	var hw = w * 0.5
	var hh = h * 0.5
	var pts = PackedVector2Array([c + Vector2(-hw, -hh).rotated(ang), c + Vector2(hw, -hh).rotated(ang), c + Vector2(hw, hh).rotated(ang), c + Vector2(-hw, hh).rotated(ang)])
	ci.draw_colored_polygon(pts, col)

static func patron_portrait(ci: CanvasItem, pid: String, t: float, pos: Vector2, s: float, aura: bool = true, rot: float = 0.0):
	ci.draw_set_transform(pos, rot, Vector2(s, s))
	if aura:
		patron_aura(ci, pid, t, false)
	match pid:
		"tailor": _p_loom(ci, t)
		"luna": _p_luna(ci, t)
		"baron": _p_baron(ci, t)
		"fortuna": _p_fortuna(ci, t)
		"ivory": _p_ivory(ci, t)
		"bruno": _p_bruno(ci, t)
	if aura:
		patron_aura(ci, pid, t, true)   # the near half of anything orbiting passes in FRONT
	ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

static func _p_luna(ci: CanvasItem, t: float):
	var flap = sin(t * 2.2) * 0.08
	var wing = Color(0.55, 0.75, 1.0, 0.85)
	_rot_ellipse(ci, Vector2(-46, -92), 42, 26, -0.5 - flap, wing)
	_rot_ellipse(ci, Vector2(46, -92), 42, 26, 0.5 + flap, wing)
	_rot_ellipse(ci, Vector2(-34, -54), 26, 18, 0.4 + flap, wing.darkened(0.15))
	_rot_ellipse(ci, Vector2(34, -54), 26, 18, -0.4 - flap, wing.darkened(0.15))
	for sx in [-1.0, 1.0]:
		ci.draw_circle(Vector2(52 * sx, -96), 9, Color(0.15, 0.25, 0.6))
		ci.draw_circle(Vector2(52 * sx, -96), 4, Color(1.6, 1.7, 2.0))
	ci.draw_line(Vector2(34, 0), Vector2(34, -70), Color(0.7, 0.7, 0.75), 2.0)
	ellipse(ci, Vector2(34, -75), 4, 6, Color(0.25, 0.25, 0.3))
	poly(ci, [Vector2(-26, 0), Vector2(26, 0), Vector2(15, -58), Vector2(-15, -58)], Color(0.1, 0.12, 0.3))
	for i in range(9):
		var sp = Vector2(-18 + fmod(float(i) * 13.0, 36.0), -8 - float(i) * 5.5)
		ci.draw_circle(sp, 1.3, Color(1.4, 1.5, 2.0, 0.5 + 0.5 * sin(t * 4.0 + i)))
	for i in range(7):
		ci.draw_circle(Vector2(-18 + i * 6, -60), 6, Color(0.93, 0.94, 1.0))
	ci.draw_circle(Vector2(0, -81), 16, Color(0.78, 0.8, 0.98))
	for sx2 in [-1.0, 1.0]:
		ellipse(ci, Vector2(6 * sx2, -83), 5.5, 7, Color(0.05, 0.05, 0.1))
		ci.draw_circle(Vector2(6 * sx2 + 1.5, -86), 1.8, Color(1, 1, 1, 0.8))
		var ant = PackedVector2Array([Vector2(4 * sx2, -95), Vector2(10 * sx2, -110), Vector2(20 * sx2, -122), Vector2(30 * sx2, -126)])
		ci.draw_polyline(ant, Color(0.85, 0.85, 0.95), 2.0)
		for k in range(4):
			var ap = ant[1].lerp(ant[3], float(k) / 3.0)
			ci.draw_line(ap, ap + Vector2(4 * sx2, 5), Color(0.85, 0.85, 0.95), 1.0)
	ci.draw_arc(Vector2(0, -74), 4, 0.3, PI - 0.3, 6, Color(0.4, 0.3, 0.5), 1.5)
	ci.draw_arc(Vector2(12, -100), 5, -0.8, 2.6, 10, Color(1.6, 1.3, 0.5), 2.5)

static func _p_baron(ci: CanvasItem, t: float):
	var orange = Color(0.95, 0.42, 0.12)
	var tail = PackedVector2Array([Vector2(18, -8), Vector2(44, -22), Vector2(56, -46), Vector2(52, -66 + sin(t * 3.0) * 4.0)])
	ci.draw_polyline(tail, orange, 8.0)
	rrect(ci, Rect2(-26, -56, 52, 56), 8, Color(0.9, 0.86, 0.78))
	ci.draw_line(Vector2(-12, -56), Vector2(-12, 0), Color(0.4, 0.22, 0.1), 3.0)
	ci.draw_line(Vector2(12, -56), Vector2(12, 0), Color(0.4, 0.22, 0.1), 3.0)
	ci.draw_circle(Vector2(-6, -30), 3, Color(0.3, 0.3, 0.3, 0.4))
	ellipse(ci, Vector2(0, -82), 24, 18, orange)
	for sp in [Vector2(-14, -74), Vector2(10, -70), Vector2(16, -80), Vector2(-4, -96)]:
		ci.draw_circle(sp, 3, Color(0.15, 0.05, 0.02))
	for sx in [-1.0, 1.0]:
		ci.draw_circle(Vector2(15 * sx, -90), 6.5, Color(1, 1, 0.9))
		ci.draw_circle(Vector2(15 * sx + 1, -90), 3.2, Color(0.05, 0.03, 0.02))
	ci.draw_arc(Vector2(0, -80), 13, 0.25, PI - 0.25, 12, Color(0.3, 0.08, 0.02), 2.5)
	ellipse(ci, Vector2(0, -99), 22, 7, Color(0.25, 0.23, 0.22))
	ellipse(ci, Vector2(10, -95), 16, 4, Color(0.2, 0.19, 0.18))
	ci.draw_circle(Vector2(-10, -101), 2, Color(0.1, 0.1, 0.1, 0.6))
	var brass = Color(1.3, 1.0, 0.35)
	ci.draw_line(Vector2(10, -76), Vector2(46, -70), brass, 5.0)
	poly(ci, [Vector2(44, -74), Vector2(64, -86), Vector2(64, -54), Vector2(44, -66)], brass)
	for i in range(3):
		var ft = fmod(t * 1.5 + i * 0.33, 1.0)
		var fp = Vector2(70 + ft * 24.0, -70 + sin(t * 8.0 + i) * 6.0 - ft * 10.0)
		ellipse(ci, fp, 5.0 * (1.0 - ft) + 1.0, 3.5 * (1.0 - ft) + 1.0, Color(2.2, 1.0 + ft, 0.2, 1.0 - ft))
	ci.draw_circle(Vector2(12, -74), 4, orange.lightened(0.15))

static func _p_fortuna(ci: CanvasItem, t: float):
	var black = Color(0.07, 0.07, 0.09)
	var tail = PackedVector2Array([Vector2(-22, -6), Vector2(-46, -26), Vector2(-52, -56), Vector2(-42 + sin(t * 2.0) * 4.0, -84)])
	ci.draw_polyline(tail, black, 7.0)
	ci.draw_circle(tail[2], 4.5, Color(1.3, 1.0, 0.35))
	rrect(ci, Rect2(-26, -56, 52, 56), 8, Color(0.6, 0.08, 0.12))
	poly(ci, [Vector2(-8, -56), Vector2(8, -56), Vector2(0, -34)], Color(0.95, 0.95, 0.92))
	for i in range(3):
		ci.draw_circle(Vector2(0, -28 + i * 9), 2, Color(1.3, 1.0, 0.35))
	ci.draw_circle(Vector2(0, -82), 18, black)
	poly(ci, [Vector2(-17, -90), Vector2(-9, -112), Vector2(-2, -97)], black)
	poly(ci, [Vector2(17, -90), Vector2(9, -112), Vector2(2, -97)], black)
	ci.draw_rect(Rect2(-15, -104, 7, 3), Color(0.95, 0.9, 0.85))
	for sx in [-1.0, 1.0]:
		ellipse(ci, Vector2(7 * sx, -84), 4.2, 5.2, Color(0.5, 2.0, 0.7))
		ci.draw_line(Vector2(7 * sx, -88), Vector2(7 * sx, -80), Color(0, 0, 0), 1.5)
		for k in range(2):
			ci.draw_line(Vector2(6 * sx, -76 + k * 3), Vector2(26 * sx, -79 + k * 5), Color(1, 1, 1, 0.5), 1.0)
	poly(ci, [Vector2(-2.5, -78), Vector2(2.5, -78), Vector2(0, -75)], Color(0.9, 0.5, 0.6))
	poly(ci, [Vector2(-21, -93), Vector2(21, -93), Vector2(25, -87), Vector2(-25, -87)], Color(0.2, 0.9, 0.4, 0.6))
	ci.draw_arc(Vector2(16, -76), 3, 0, TAU, 8, Color(1.3, 1.0, 0.35), 1.5)
	var fan = Vector2(28, -34)
	for i in range(3):
		var ang = -0.5 + i * 0.35
		_rot_rect(ci, fan + Vector2(0, -10).rotated(ang), 12, 18, ang, Color(0.97, 0.97, 0.94))
	ci.draw_circle(fan, 6, black)

static func _p_ivory(ci: CanvasItem, t: float):
	rrect(ci, Rect2(-26, -50, 52, 50), 8, Color(0.06, 0.06, 0.08))
	poly(ci, [Vector2(-9, -50), Vector2(9, -50), Vector2(0, -26)], Color(0.95, 0.95, 0.95))
	poly(ci, [Vector2(0, -46), Vector2(-7, -50), Vector2(-7, -42)], Color(0.6, 0.35, 1.0))
	poly(ci, [Vector2(0, -46), Vector2(7, -50), Vector2(7, -42)], Color(0.6, 0.35, 1.0))
	ci.draw_circle(Vector2(0, -84), 30, Color(0.5, 0.7, 1.0, 0.13))
	var sway = sin(t * 1.6) * 4.0
	var body = PackedVector2Array([Vector2(0, -54), Vector2(-7 + sway * 0.5, -66), Vector2(-4 + sway, -80), Vector2(4 + sway, -92)])
	ci.draw_polyline(body, Color(0.92, 0.9, 1.0), 13.0)
	var hp = Vector2(5 + sway, -96)
	ellipse(ci, hp, 12, 9, Color(0.94, 0.92, 1.0))
	poly(ci, [hp + Vector2(-10, -2), hp + Vector2(-17, -8), hp + Vector2(-12, 4)], Color(0.85, 0.8, 1.0))
	poly(ci, [hp + Vector2(10, -2), hp + Vector2(17, -8), hp + Vector2(12, 4)], Color(0.85, 0.8, 1.0))
	ci.draw_circle(hp + Vector2(-4, -1), 2.2, Color(1.8, 1.2, 2.4))
	ci.draw_circle(hp + Vector2(4, -1), 2.2, Color(1.8, 1.2, 2.4))
	ci.draw_arc(hp + Vector2(0, 3), 3, 0.3, PI - 0.3, 6, Color(0.5, 0.4, 0.7), 1.2)
	ci.draw_arc(Vector2(0, -84), 30, 0, TAU, 40, Color(0.75, 0.9, 1.0, 0.55), 2.0, true)
	ci.draw_arc(Vector2(0, -84), 24, -2.4, -1.4, 8, Color(1, 1, 1, 0.5), 2.0)
	ci.draw_line(Vector2(-26, -72), Vector2(26, -72), Color(0.6, 0.8, 1.0, 0.35), 1.5)
	for i in range(3):
		var a = t * 2.0 + TAU * float(i) / 3.0
		if fmod(t * 5.0 + i, 2.0) < 1.2:
			var sp0 = Vector2(0, -84) + Vector2(cos(a), sin(a)) * 34.0
			var sp1 = sp0 + Vector2(cos(a), sin(a)) * 8.0 + Vector2(4, -3)
			var sp2 = sp1 + Vector2(cos(a), sin(a)) * 8.0 + Vector2(-4, 3)
			ci.draw_polyline(PackedVector2Array([sp0, sp1, sp2]), Color(1.4, 1.1, 2.4), 2.0)

static func _p_bruno(ci: CanvasItem, t: float):
	ellipse(ci, Vector2(46, -22), 17, 26, Color(0.55, 0.28, 0.1))
	ci.draw_line(Vector2(46, -40), Vector2(46, -140), Color(0.2, 0.1, 0.05), 4.0)
	ci.draw_circle(Vector2(46, -142), 5, Color(0.2, 0.1, 0.05))
	rrect(ci, Rect2(-38, -58, 76, 58), 14, Color(0.45, 0.3, 0.2))
	poly(ci, [Vector2(-10, -58), Vector2(10, -58), Vector2(0, -30)], Color(0.85, 0.82, 0.75))
	for i in range(3):
		ci.draw_circle(Vector2(0, -24 + i * 8), 2.5, Color(0.8, 0.7, 0.5))
	var grey = Color(0.55, 0.55, 0.6)
	ellipse(ci, Vector2(-22, -100), 6, 9, grey)
	ellipse(ci, Vector2(22, -100), 6, 9, grey)
	ellipse(ci, Vector2(0, -86), 26, 22, grey)
	ellipse(ci, Vector2(0, -72), 18, 12, grey.lightened(0.12))
	poly(ci, [Vector2(-6, -76), Vector2(6, -76), Vector2(1, -95)], Color(0.92, 0.9, 0.82))
	poly(ci, [Vector2(-3, -86), Vector2(3, -86), Vector2(0, -92)], Color(0.92, 0.9, 0.82))
	for sx in [-1.0, 1.0]:
		ci.draw_circle(Vector2(13 * sx, -90), 2.5, Color(0.08, 0.08, 0.1))
		ci.draw_line(Vector2(8 * sx, -95), Vector2(18 * sx, -97), Color(0.3, 0.3, 0.35), 2.0)
		ci.draw_circle(Vector2(7 * sx, -70), 2, Color(0.3, 0.3, 0.35))
	ci.draw_arc(Vector2(0, -66), 6, 0.4, PI - 0.4, 8, Color(0.3, 0.3, 0.35), 1.5)
	var dome = PackedVector2Array()
	for i in range(13):
		var a = PI + PI * float(i) / 12.0
		dome.append(Vector2(cos(a) * 22.0, -103 + sin(a) * 13.0))
	ci.draw_colored_polygon(dome, Color(0.75, 0.12, 0.15))
	ci.draw_rect(Rect2(-22, -106, 44, 6), Color(0.6, 0.08, 0.1))
	for i in range(8):
		ci.draw_line(Vector2(-19 + i * 5.4, -106), Vector2(-19 + i * 5.4, -100), Color(0.45, 0.05, 0.08), 1.0)
	ci.draw_circle(Vector2(0, -118), 6, Color(0.95, 0.9, 0.85))

## Signature legendary aura, drawn behind each character (local coords, bust at origin).
## front = false: everything behind the character. front = true: only the orbiting bits that are
## on the near side of their loop (lower half of the ellipse), drawn over the character.
static func patron_aura(ci: CanvasItem, pid: String, t: float, front: bool = false):
	var c = Vector2(0, -82)
	match pid:
		"luna":
			if not front:
				ci.draw_arc(c, 46, 2.1, 5.5, 24, Color(0.8, 1.2, 2.0, 0.55 + 0.2 * sin(t * 2.0)), 5.0, true)
				ci.draw_arc(c, 52, 2.3, 5.3, 24, Color(0.6, 0.9, 1.6, 0.25), 2.0, true)
			for i in range(10):
				var a = t * 0.6 + TAU * float(i) / 10.0
				if (sin(a) > 0.0) != front:
					continue
				var mp = c + Vector2(cos(a) * 68.0, sin(a) * 40.0)
				star(ci, mp, 3.5 + (0.8 if front else 0.0), 1.4, 6, Color(1.0, 1.4, 2.2, 0.8), t)
		"baron":
			if front:
				return
			var pulse = 0.5 + 0.5 * sin(t * 5.0)
			ci.draw_arc(c, 50 + pulse * 5.0, 0, TAU, 32, Color(2.0, 0.7, 0.2, 0.3 + 0.2 * pulse), 4.0, true)
			for i in range(12):
				var ex = -54.0 + fmod(float(i) * 37.0, 108.0)
				var ey = -10.0 - fmod(t * 45.0 + float(i) * 23.0, 150.0)
				var ea = 1.0 - fmod(t * 45.0 + float(i) * 23.0, 150.0) / 150.0
				ci.draw_circle(Vector2(ex + sin(t * 3.0 + i) * 4.0, ey), 2.2, Color(2.2, 0.9, 0.2, ea))
		"fortuna":
			for i in range(5):
				var a2 = t * 0.9 + TAU * float(i) / 5.0
				if (sin(a2) > 0.0) != front:
					continue
				var cp = c + Vector2(cos(a2) * 66.0, sin(a2) * 34.0)
				var ck = 1.12 if front else 1.0
				_rot_rect(ci, cp, 11 * ck, 15 * ck, a2 * 0.5, Color(0.98, 0.97, 0.92, 0.9))
				ci.draw_circle(cp, 2.5, Color(0.1, 0.6, 0.3) if i % 2 == 0 else Color(0.8, 0.1, 0.15))
			if front:
				return
			for i in range(6):
				var sp = c + Vector2(cos(t * 2.0 + i * 1.7) * 55.0, sin(t * 1.3 + i) * 45.0)
				star(ci, sp, 3.0, 1.0, 4, Color(1.6, 1.3, 0.4, 0.5 + 0.5 * sin(t * 6.0 + i)), 0.0)
		"ivory":
			if front:
				return
			for i in range(4):
				var a3 = t * 1.5 + TAU * float(i) / 4.0
				if fmod(t * 4.0 + float(i) * 0.7, 2.0) < 1.3:
					var p0 = c + Vector2(cos(a3), sin(a3)) * 44.0
					var p1 = c + Vector2(cos(a3 + 0.25), sin(a3 + 0.25)) * 54.0
					var p2 = c + Vector2(cos(a3 + 0.5), sin(a3 + 0.5)) * 46.0
					ci.draw_polyline(PackedVector2Array([p0, p1, p2]), Color(1.5, 1.2, 2.4, 0.9), 2.0)
			for i in range(4):
				var nt = fmod(t * 0.5 + float(i) * 0.25, 1.0)
				note_glyph(ci, Vector2(-50.0 + i * 33.0, -30.0 - nt * 110.0), 6.0, Color(1.2, 1.0, 2.0, 1.0 - nt))
		"bruno":
			if front:
				return
			for i in range(3):
				var rr = 20.0 + fmod(t * 45.0 + float(i) * 33.0, 100.0)
				ellipse_line(ci, Vector2(0, -8), rr, rr * 0.3, Color(1.8, 0.5, 0.5, 0.6 * (1.0 - rr / 120.0)), 2.5)
		"tailor":
			if not front:
				for i in range(3):
					var tx = -40.0 + i * 40.0
					var sway = sin(t * 1.5 + i) * 8.0
					ci.draw_line(Vector2(tx, -170), Vector2(tx + sway, -40), Color(0.9, 0.9, 1.0, 0.25), 1.0)
			# her pins orbit: behind her on the far side, in front of her on the near side
			for i in range(5):
				var pa = t * 0.7 + TAU * float(i) / 5.0
				if (sin(pa) > 0.0) != front:
					continue
				var pp = c + Vector2(cos(pa) * 62.0, sin(pa) * 36.0)
				var pk = 1.25 if front else 1.0
				var head = pp + Vector2(6, -6).rotated(pa) * pk
				ci.draw_line(pp, head, Color(0.85, 0.85, 0.9), 1.5 * pk)
				ci.draw_circle(head, 2.2 * pk, Color.from_hsv(float(i) * 0.2, 0.6, 1.2))

## LADY LOOM: eight-armed spider hatmaker, spectacles, pincushion pillbox hat.
static func _p_loom(ci: CanvasItem, t: float):
	var bob = sin(t * 1.4) * 3.0
	ci.draw_line(Vector2(0, -175), Vector2(0, -122 + bob), Color(0.9, 0.9, 0.95, 0.8), 1.5)
	var leg_col = Color(0.22, 0.1, 0.2)
	var body = Vector2(0, -70 + bob)
	for sx in [-1.0, 1.0]:
		for i in range(4):
			var knee = body + Vector2(sx * (34.0 + i * 5.0), -30.0 + i * 16.0 + sin(t * 2.0 + i) * 2.0)
			var foot = body + Vector2(sx * (56.0 + i * 3.0), -14.0 + i * 22.0)
			ci.draw_polyline(PackedVector2Array([body + Vector2(sx * 8.0, -6.0 + i * 5.0), knee, foot]), leg_col, 3.0)
	# tools in four of the hands
	var nh = body + Vector2(-56, -14)
	ci.draw_line(nh + Vector2(-2, 10), nh + Vector2(4, -16), Color(0.9, 0.9, 0.95), 2.0)
	ci.draw_arc(nh + Vector2(4, -17), 2.0, 0, TAU, 8, Color(0.9, 0.9, 0.95), 1.0)
	var sh = body + Vector2(56, -14)
	ci.draw_circle(sh + Vector2(-3, 4), 3, Color(1.3, 1.0, 0.4))
	ci.draw_circle(sh + Vector2(3, 4), 3, Color(1.3, 1.0, 0.4))
	ci.draw_line(sh + Vector2(-2, 2), sh + Vector2(4, -14 + sin(t * 6.0) * 2.0), Color(0.85, 0.85, 0.9), 2.0)
	ci.draw_line(sh + Vector2(2, 2), sh + Vector2(-4, -14 - sin(t * 6.0) * 2.0), Color(0.85, 0.85, 0.9), 2.0)
	var sp = body + Vector2(61, 30)
	rrect(ci, Rect2(sp.x - 5, sp.y - 7, 10, 14), 2, Color(0.55, 0.35, 0.2))
	ci.draw_rect(Rect2(sp.x - 4, sp.y - 4, 8, 8), Color(0.8, 0.15, 0.3))
	var tp = body + Vector2(-61, 30)
	ci.draw_polyline(PackedVector2Array([tp, tp + Vector2(-6, 10), tp + Vector2(4, 18), tp + Vector2(-2, 28)]), Color(1.2, 1.0, 0.3), 3.0)
	# abdomen in a stitched plum dress, lace collar
	ellipse(ci, body + Vector2(0, 18), 26, 30, Color(0.36, 0.14, 0.3))
	for i in range(6):
		ci.draw_line(body + Vector2(-18 + i * 7, 18), body + Vector2(-14 + i * 7, 18), Style.GOLD, 1.5)
	for i in range(6):
		ci.draw_circle(body + Vector2(-15 + i * 6, -10), 4, Color(0.96, 0.94, 0.9))
	# head: four eyes, spectacles, tiny fangs
	var h = Vector2(0, -100 + bob)
	ci.draw_circle(h, 16, Color(0.62, 0.55, 0.66))
	for sx2 in [-1.0, 1.0]:
		ci.draw_circle(h + Vector2(6 * sx2, -2), 4.5, Color(0.05, 0.03, 0.06))
		ci.draw_circle(h + Vector2(6 * sx2 + 1.5, -3.5), 1.4, Color(1, 1, 1, 0.9))
		ci.draw_circle(h + Vector2(4 * sx2, -10), 2.0, Color(0.05, 0.03, 0.06))
		ci.draw_arc(h + Vector2(6 * sx2, -2), 6.5, 0, TAU, 14, Style.GOLD, 1.2)
		ci.draw_line(h + Vector2(3 * sx2, 7), h + Vector2(3 * sx2, 10), Color(1, 1, 1), 1.5)
	ci.draw_line(h + Vector2(-0.5, -2), h + Vector2(0.5, -2), Style.GOLD, 1.2)
	ci.draw_arc(h + Vector2(0, 4), 4, 0.3, PI - 0.3, 6, Color(0.3, 0.15, 0.25), 1.5)
	# pincushion pillbox hat
	rrect(ci, Rect2(h.x - 11, h.y - 25, 22, 10), 3, Color(0.8, 0.12, 0.2))
	for i in range(4):
		var pin = Vector2(h.x - 7 + i * 5, h.y - 25)
		ci.draw_line(pin, pin + Vector2(i - 1.5, -7), Color(0.85, 0.85, 0.9), 1.0)
		ci.draw_circle(pin + Vector2(i - 1.5, -7), 1.6, Color.from_hsv(float(i) * 0.25, 0.7, 1.3))
