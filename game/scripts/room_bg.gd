extends Node2D

## RoomBG: draws the floor, back wall and set dressing for each biome,
## and decides obstacle layout + lighting for a room.

const Art = preload("res://scripts/art.gd")
const WorldData = preload("res://scripts/world_data.gd")
const DrawLayer = preload("res://scripts/draw_layer.gd")

var biome: Dictionary = {}
var biome_id: String = "bar"
var room_type: String = "combat"
var boss_kind: String = ""
var arena: Rect2 = Rect2(70, 140, 1140, 540)
var rng: RandomNumberGenerator = RandomNumberGenerator.new()
var t: float = 0.0
var anim_layer: Node2D

# cached random decor
var planks: Array = []
var bottles: Array = []
var specks: Array = []
var puddles: Array = []
var cracks: Array = []
var stars: Array = []
var craters: Array = []
var windows: Array = []

const SLOTS = [Vector2(260, 270), Vector2(1020, 270), Vector2(250, 560), Vector2(1030, 560), Vector2(450, 340), Vector2(830, 340), Vector2(440, 560), Vector2(840, 560), Vector2(640, 250), Vector2(180, 420), Vector2(1100, 420)]

func _ready():
	anim_layer = DrawLayer.new()
	anim_layer.draw_func = _draw_anim
	var m = CanvasItemMaterial.new()
	m.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED
	anim_layer.material = m
	add_child(anim_layer)

func _process(delta):
	t += delta

func build(biome_idx: int, rtype: String, arena_rect: Rect2, boss: String = "") -> Dictionary:
	biome = WorldData.biome(biome_idx)
	biome_id = String(biome["id"])
	room_type = rtype
	boss_kind = boss
	arena = arena_rect
	rng.randomize()
	_gen_decor()
	queue_redraw()
	var obstacles = []
	if rtype == "combat" or rtype == "elite":
		var kinds = []
		match biome_id:
			"bar": kinds = ["table", "table", "table", "stool", "stool"]
			"alley": kinds = ["trash", "crate", "crate", "dumpster", "trash"]
			"casino": kinds = ["roulette", "cardtable", "slot", "cardtable"]
			"moon": kinds = ["boulder", "boulder", "boulder", "lander", "flag"]
		var slots = SLOTS.duplicate()
		slots.shuffle()
		var n = rng.randi_range(3, 5)
		for i in range(n):
			var k = String(kinds[rng.randi_range(0, kinds.size() - 1)])
			var p: Vector2 = slots[i] + Vector2(rng.randf_range(-30, 30), rng.randf_range(-20, 20))
			obstacles.append({"pos": p, "kind": k, "r": obstacle_radius(k)})
	var lights = []
	var lc: Color = biome["light"]
	match biome_id:
		"bar":
			lights = [{"pos": Vector2(330, 330), "color": lc, "energy": 1.1, "scale": 2.3}, {"pos": Vector2(640, 300), "color": lc, "energy": 1.2, "scale": 2.4}, {"pos": Vector2(950, 330), "color": lc, "energy": 1.1, "scale": 2.3}, {"pos": Vector2(640, 90), "color": Color(0.4, 0.6, 1.0), "energy": 0.9, "scale": 1.6}]
		"alley":
			lights = [{"pos": Vector2(230, 150), "color": Color(1.0, 0.25, 0.8), "energy": 1.4, "scale": 2.2}, {"pos": Vector2(1040, 150), "color": Color(0.2, 0.9, 1.0), "energy": 1.4, "scale": 2.2}, {"pos": Vector2(640, 420), "color": Color(1.0, 0.8, 0.55), "energy": 0.8, "scale": 2.8}]
		"casino":
			lights = [{"pos": Vector2(330, 320), "color": lc, "energy": 1.1, "scale": 2.5}, {"pos": Vector2(950, 320), "color": lc, "energy": 1.1, "scale": 2.5}, {"pos": Vector2(640, 470), "color": Color(1.0, 0.5, 0.4), "energy": 0.7, "scale": 2.8}]
		"moon":
			lights = [{"pos": Vector2(640, 380), "color": lc, "energy": 0.9, "scale": 4.2}, {"pos": Vector2(1030, 120), "color": Color(0.4, 0.7, 1.0), "energy": 0.8, "scale": 2.6}]
	match rtype:
		"shop":
			lights.append({"pos": Vector2(640, 330), "color": Color(1.0, 0.75, 0.4), "energy": 1.2, "scale": 2.4})
		"rest":
			lights.append({"pos": Vector2(640, 380), "color": Color(1.0, 0.5, 0.75), "energy": 1.2, "scale": 2.6})
		"jackpot":
			lights.append({"pos": Vector2(640, 360), "color": Color(1.0, 0.9, 0.4), "energy": 1.3, "scale": 2.4})
		"boss":
			lights.append({"pos": Vector2(640, 400), "color": Color(1.0, 0.95, 0.9), "energy": 0.8, "scale": 3.4})
	for o in obstacles:
		if o["kind"] == "table":
			lights.append({"pos": o["pos"] + Vector2(0, -34), "color": Color(1.0, 0.6, 0.25), "energy": 0.55, "scale": 0.55})
		elif o["kind"] == "slot":
			lights.append({"pos": o["pos"] + Vector2(0, -40), "color": Color(1.0, 0.3, 0.3), "energy": 0.5, "scale": 0.5})
	var amb = ""
	match biome_id:
		"bar": amb = "smoke"
		"alley": amb = "rain"
		"casino": amb = "gold"
		"moon": amb = "stars"
	return {"obstacles": obstacles, "lights": lights, "ambient": amb}

static func obstacle_radius(k: String) -> float:
	match k:
		"table": return 26.0
		"stool": return 11.0
		"trash": return 15.0
		"crate": return 20.0
		"dumpster": return 30.0
		"roulette": return 34.0
		"cardtable": return 30.0
		"slot": return 17.0
		"boulder": return 24.0
		"lander": return 30.0
		"flag": return 6.0
	return 20.0

func _gen_decor():
	planks.clear()
	bottles.clear()
	specks.clear()
	puddles.clear()
	cracks.clear()
	stars.clear()
	craters.clear()
	windows.clear()
	var A = arena
	match biome_id:
		"bar":
			var y = A.position.y
			while y < A.end.y:
				var x = A.position.x - rng.randf_range(0, 120)
				while x < A.end.x:
					var w = rng.randf_range(90, 210)
					planks.append({"r": Rect2(x, y, w, 22), "k": rng.randf()})
					x += w
				y += 22
			for i in range(46):
				bottles.append({"x": 318 + i * 14 + rng.randf_range(-2, 2), "shelf": i % 2, "h": rng.randf_range(12, 22), "c": Color.from_hsv(rng.randf_range(0.0, 0.4) if rng.randf() < 0.7 else rng.randf(), rng.randf_range(0.4, 0.9), rng.randf_range(0.35, 0.8), 0.9)})
		"alley":
			for i in range(260):
				specks.append({"p": Vector2(rng.randf_range(A.position.x, A.end.x), rng.randf_range(A.position.y, A.end.y)), "s": rng.randf_range(0.8, 2.2), "a": rng.randf_range(0.05, 0.18)})
			for i in range(rng.randi_range(4, 6)):
				puddles.append({"p": Vector2(rng.randf_range(A.position.x + 80, A.end.x - 80), rng.randf_range(A.position.y + 60, A.end.y - 40)), "rx": rng.randf_range(40, 90), "ry": rng.randf_range(12, 24), "hue": 0.85 if rng.randf() < 0.5 else 0.5})
			for i in range(6):
				var c = []
				var p = Vector2(rng.randf_range(A.position.x, A.end.x), rng.randf_range(A.position.y, A.end.y))
				for j in range(6):
					c.append(p)
					p += Vector2(rng.randf_range(-30, 30), rng.randf_range(-15, 25))
				cracks.append(c)
			for i in range(5):
				windows.append({"x": 120 + i * 250 + rng.randf_range(-20, 20), "lit": rng.randf() < 0.7})
		"casino":
			pass
		"moon":
			for i in range(160):
				stars.append({"p": Vector2(rng.randf_range(0, 1280), rng.randf_range(0, A.position.y - 20)), "s": rng.randf_range(0.6, 1.8), "a": rng.randf_range(0.3, 1.0)})
			for i in range(rng.randi_range(8, 12)):
				craters.append({"p": Vector2(rng.randf_range(A.position.x + 30, A.end.x - 30), rng.randf_range(A.position.y + 30, A.end.y - 20)), "r": rng.randf_range(14, 46)})
			for i in range(220):
				specks.append({"p": Vector2(rng.randf_range(A.position.x, A.end.x), rng.randf_range(A.position.y, A.end.y)), "s": rng.randf_range(0.8, 2.0), "a": rng.randf_range(0.05, 0.2)})

# ---------------------------------------------------------------------------
# STATIC BACKGROUND
# ---------------------------------------------------------------------------
func _draw():
	if biome.is_empty():
		return
	var A = arena
	var wall: Color = biome["wall"]
	draw_rect(Rect2(0, 0, 1280, 720), wall.darkened(0.45))
	match biome_id:
		"bar": _bg_bar()
		"alley": _bg_alley()
		"casino": _bg_casino()
		"moon": _bg_moon()
	match room_type:
		"shop":
			Art.rrect(self, Rect2(440, A.position.y + 30, 400, 40), 6, Color(0.3, 0.15, 0.08))
			draw_rect(Rect2(440, A.position.y + 30, 400, 5), Style.GOLD_DIM)
		"rest":
			Art.ellipse(self, Vector2(640, 410), 330, 170, Color(0.55, 0.15, 0.3, 0.55))
			Art.ellipse_line(self, Vector2(640, 410), 320, 162, Color(1.0, 0.7, 0.8, 0.5), 3.0)
		"jackpot":
			for i in range(16):
				var a = TAU * float(i) / 16.0
				draw_line(Vector2(640, 400), Vector2(640, 400) + Vector2(cos(a) * 300, sin(a) * 170), Color(1.0, 0.8, 0.3, 0.12), 14.0)
		"boss":
			Art.ellipse(self, Vector2(640, 420), 420, 210, Color(0, 0, 0, 0.18))
			Art.ellipse_line(self, Vector2(640, 420), 420, 210, Color(biome["accent"].r, biome["accent"].g, biome["accent"].b, 0.35), 3.0)
			if boss_kind == "big_band":
				Art.rrect(self, Rect2(400, A.position.y - 6, 480, 150), 12, Color(0.2, 0.08, 0.06))
				draw_rect(Rect2(400, A.position.y + 136, 480, 8), Style.GOLD)
	# side walls
	var side: Color = wall.darkened(0.3)
	draw_rect(Rect2(0, A.position.y - 10, A.position.x, 720), side)
	draw_rect(Rect2(A.end.x, A.position.y - 10, 1280 - A.end.x, 720), side)
	draw_line(Vector2(A.position.x, A.position.y - 10), Vector2(A.position.x, A.end.y), side.lightened(0.15), 3.0)
	draw_line(Vector2(A.end.x, A.position.y - 10), Vector2(A.end.x, A.end.y), side.lightened(0.15), 3.0)
	draw_rect(Rect2(0, A.end.y, 1280, 720 - A.end.y), wall.darkened(0.55))
	draw_line(Vector2(A.position.x, A.end.y), Vector2(A.end.x, A.end.y), side.lightened(0.1), 2.0)
	# contact shadow under the back wall + vignette
	for i in range(6):
		draw_rect(Rect2(A.position.x, A.position.y + i * 4, A.size.x, 4), Color(0, 0, 0, 0.28 - i * 0.045))
	for i in range(8):
		var a = 0.05 * (8 - i) / 8.0
		draw_rect(Rect2(A.position.x + i * 10, A.position.y, 10, A.size.y), Color(0, 0, 0, a))
		draw_rect(Rect2(A.end.x - (i + 1) * 10, A.position.y, 10, A.size.y), Color(0, 0, 0, a))

func _bg_bar():
	var A = arena
	var fa: Color = biome["floor_a"]
	var fb: Color = biome["floor_b"]
	for p in planks:
		var r: Rect2 = p["r"]
		var cr = r.intersection(A)
		if cr.size.x <= 0.0:
			continue
		var c = fa.lerp(fb, float(p["k"]))
		draw_rect(cr, c)
		draw_line(Vector2(cr.position.x, cr.position.y), Vector2(cr.end.x, cr.position.y), c.darkened(0.35), 1.0)
		draw_line(Vector2(cr.position.x, cr.position.y), Vector2(cr.position.x, cr.end.y), c.darkened(0.45), 1.0)
		draw_line(Vector2(cr.position.x, cr.position.y + 2), Vector2(cr.end.x, cr.position.y + 2), c.lightened(0.08), 1.0)
	# rug
	var rug = Rect2(380, 260, 520, 300)
	Art.rrect(self, rug, 10, Color(0.42, 0.05, 0.08))
	Art.rrect(self, rug.grow(-10), 8, Color(0.5, 0.07, 0.1))
	draw_rect(rug.grow(-14), Color(0.9, 0.7, 0.3, 0.55), false, 2.0)
	for i in range(7):
		var cx = rug.position.x + 60 + i * 67
		var cy = rug.get_center().y
		Art.poly(self, [Vector2(cx, cy - 26), Vector2(cx + 16, cy), Vector2(cx, cy + 26), Vector2(cx - 16, cy)], Color(0.85, 0.65, 0.25, 0.35))
	# back wall: wood paneling
	var wall: Color = biome["wall"]
	draw_rect(Rect2(0, 0, 1280, A.position.y), wall)
	for i in range(17):
		var x = i * 80.0
		Art.rrect(self, Rect2(x + 8, 16, 64, A.position.y - 60), 3, wall.lightened(0.07))
	draw_line(Vector2(0, 8), Vector2(1280, 8), Style.GOLD_DIM, 3.0)
	# mirror + shelves + bottles
	Art.rrect(self, Rect2(300, 14, 680, 84), 4, Color(0.08, 0.1, 0.16))
	draw_rect(Rect2(300, 14, 680, 84), Style.GOLD_DIM, false, 3.0)
	draw_line(Vector2(300, 56), Vector2(980, 56), Color(0.35, 0.2, 0.1), 3.0)
	draw_line(Vector2(300, 94), Vector2(980, 94), Color(0.35, 0.2, 0.1), 3.0)
	for b in bottles:
		var base_y = 55.0 if int(b["shelf"]) == 0 else 93.0
		var h = float(b["h"])
		var bx = float(b["x"])
		var c: Color = b["c"]
		Art.rrect(self, Rect2(bx - 4, base_y - h, 8, h), 2, c)
		draw_rect(Rect2(bx - 1.5, base_y - h - 6, 3, 7), c)
		draw_line(Vector2(bx - 2, base_y - h + 2), Vector2(bx - 2, base_y - 3), Color(1, 1, 1, 0.25), 1.0)
	# posters
	for px in [150.0, 1130.0]:
		Art.rrect(self, Rect2(px - 40, 20, 80, 76), 2, Style.GOLD_DIM)
		Art.rrect(self, Rect2(px - 35, 25, 70, 66), 2, Color(0.7, 0.55, 0.35))
		draw_circle(Vector2(px, 50), 14, Color(0.2, 0.1, 0.08))
		draw_line(Vector2(px - 6, 60), Vector2(px + 10, 84), Color(0.2, 0.1, 0.08), 5.0)
	# the bar counter
	Art.rrect(self, Rect2(0, A.position.y - 36, 1280, 36), 2, Color(0.25, 0.1, 0.05))
	draw_rect(Rect2(0, A.position.y - 36, 1280, 6), Color(0.4, 0.2, 0.1))
	draw_line(Vector2(0, A.position.y - 12), Vector2(1280, A.position.y - 12), Style.GOLD, 2.0)

func _bg_alley():
	var A = arena
	var fa: Color = biome["floor_a"]
	draw_rect(A, fa)
	for s in specks:
		draw_circle(s["p"], float(s["s"]), Color(0.5, 0.55, 0.7, float(s["a"])))
	for c in cracks:
		var pts = PackedVector2Array()
		for v in c:
			pts.append(v)
		draw_polyline(pts, Color(0, 0, 0, 0.35), 1.5)
	# manhole
	Art.ellipse(self, Vector2(900, 520), 30, 16, Color(0.15, 0.15, 0.18))
	Art.ellipse_line(self, Vector2(900, 520), 30, 16, Color(0.3, 0.3, 0.35), 2.0)
	for i in range(4):
		draw_line(Vector2(878 + i * 14, 510), Vector2(878 + i * 14, 530), Color(0.25, 0.25, 0.3), 1.5)
	for p in puddles:
		Art.ellipse(self, p["p"], float(p["rx"]), float(p["ry"]), Color(0.1, 0.13, 0.22, 0.9))
	# curb
	draw_rect(Rect2(A.position.x, A.position.y, A.size.x, 10), Color(0.25, 0.25, 0.28))
	# back wall: brick
	var wall: Color = biome["wall"]
	draw_rect(Rect2(0, 0, 1280, A.position.y), wall)
	var row = 0
	var y = 0.0
	while y < A.position.y:
		draw_line(Vector2(0, y), Vector2(1280, y), wall.darkened(0.4), 1.0)
		var off = 18.0 if row % 2 == 0 else 0.0
		var x = off
		while x < 1280:
			draw_line(Vector2(x, y), Vector2(x, y + 14), wall.darkened(0.4), 1.0)
			x += 36.0
		y += 14.0
		row += 1
	for w in windows:
		var wx = float(w["x"])
		var lit = w["lit"]
		Art.rrect(self, Rect2(wx - 26, 18, 52, 58), 2, Color(0.08, 0.06, 0.07))
		var wc = Color(1.0, 0.75, 0.4, 0.9) if lit else Color(0.1, 0.12, 0.2)
		draw_rect(Rect2(wx - 22, 22, 44, 50), wc)
		if lit:
			for i in range(5):
				draw_line(Vector2(wx - 22, 26 + i * 10), Vector2(wx + 22, 26 + i * 10), Color(0.6, 0.4, 0.2, 0.7), 2.0)
		draw_line(Vector2(wx, 22), Vector2(wx, 72), Color(0.08, 0.06, 0.07), 3.0)
	# fire escape
	for i in range(8):
		draw_line(Vector2(780 + i * 20, 84), Vector2(780 + i * 20, 104), Color(0.1, 0.1, 0.12), 2.0)
	draw_line(Vector2(770, 84), Vector2(940, 84), Color(0.1, 0.1, 0.12), 3.0)
	draw_line(Vector2(770, 104), Vector2(940, 104), Color(0.1, 0.1, 0.12), 3.0)
	draw_line(Vector2(60, 0), Vector2(60, A.position.y), Color(0.3, 0.3, 0.33), 6.0)

func _bg_casino():
	var A = arena
	var fa: Color = biome["floor_a"]
	draw_rect(A, fa)
	var gold = Color(0.9, 0.7, 0.3, 0.12)
	var step = 60.0
	var k = -A.size.y
	while k < A.size.x + A.size.y:
		draw_line(Vector2(A.position.x + k, A.position.y), Vector2(A.position.x + k + A.size.y, A.end.y), gold, 2.0)
		draw_line(Vector2(A.position.x + k + A.size.y, A.position.y), Vector2(A.position.x + k, A.end.y), gold, 2.0)
		k += step
	# medallion
	Art.star(self, Vector2(640, 410), 150, 60, 8, Color(0.9, 0.7, 0.3, 0.12), 0.0)
	Art.ellipse_line(self, Vector2(640, 410), 160, 90, Color(0.9, 0.7, 0.3, 0.25), 3.0)
	# back wall: gold art deco
	var wall: Color = biome["wall"]
	draw_rect(Rect2(0, 0, 1280, A.position.y), wall)
	for i in range(64):
		draw_line(Vector2(i * 20 + 10, 0), Vector2(i * 20 + 10, A.position.y), Color(0.9, 0.7, 0.3, 0.1), 3.0)
	for fx_ in [200.0, 640.0, 1080.0]:
		var c = Vector2(fx_, A.position.y - 20)
		for j in range(13):
			var a = PI + PI * float(j) / 12.0
			draw_line(c, c + Vector2(cos(a), sin(a)) * 100.0, Color(0.95, 0.75, 0.35, 0.35), 3.0)
		draw_arc(c, 100.0, PI, TAU, 24, Color(0.95, 0.75, 0.35, 0.5), 3.0)
		draw_arc(c, 60.0, PI, TAU, 24, Color(0.95, 0.75, 0.35, 0.4), 2.0)
	# drapes
	for dx in [0.0, 1200.0]:
		draw_rect(Rect2(dx, 0, 80, A.position.y + 10), Color(0.45, 0.04, 0.08))
		for j in range(5):
			draw_line(Vector2(dx + 8 + j * 16, 0), Vector2(dx + 8 + j * 16, A.position.y + 10), Color(0.25, 0.02, 0.05), 3.0)
	draw_line(Vector2(0, A.position.y - 4), Vector2(1280, A.position.y - 4), Style.GOLD, 3.0)

func _bg_moon():
	var A = arena
	draw_rect(Rect2(0, 0, 1280, A.position.y), Color(0.01, 0.01, 0.04))
	for s in stars:
		draw_circle(s["p"], float(s["s"]), Color(1, 1, 1, float(s["a"])))
	# Earth rising
	var e = Vector2(1030, 64)
	Art.glow(self, e, 70, Color(0.4, 0.7, 1.4, 0.35), 5)
	draw_circle(e, 44, Color(0.15, 0.35, 0.8))
	draw_circle(e + Vector2(-12, -10), 14, Color(0.2, 0.6, 0.3))
	draw_circle(e + Vector2(10, 12), 11, Color(0.25, 0.55, 0.3))
	draw_circle(e + Vector2(18, -16), 7, Color(0.9, 0.95, 1.0, 0.8))
	draw_circle(e + Vector2(20, 8), 40, Color(0, 0, 0.03, 0.55))
	# horizon hills
	var fa: Color = biome["floor_a"]
	var fb: Color = biome["floor_b"]
	var hills = PackedVector2Array()
	hills.append(Vector2(0, A.position.y + 2))
	for i in range(33):
		var x = i * 40.0
		hills.append(Vector2(x, A.position.y - 14 - 12 * sin(i * 0.9) - 6 * sin(i * 2.3)))
	hills.append(Vector2(1280, A.position.y + 2))
	draw_colored_polygon(hills, fa.darkened(0.25))
	draw_rect(A, fa)
	for s in specks:
		draw_circle(s["p"], float(s["s"]), Color(0.1, 0.1, 0.15, float(s["a"])))
	for c in craters:
		var r = float(c["r"])
		var cp: Vector2 = c["p"]
		Art.ellipse(self, cp, r, r * 0.45, fb.darkened(0.2))
		Art.ellipse(self, cp + Vector2(0, -r * 0.08), r * 0.85, r * 0.36, fa.darkened(0.12))
		draw_arc(cp, r, 0.2, PI - 0.2, 16, fb.lightened(0.15), 2.0)

# ---------------------------------------------------------------------------
# ANIMATED BITS (neon, bulbs, reflections)
# ---------------------------------------------------------------------------
func _draw_anim(ci: CanvasItem):
	if biome.is_empty():
		return
	var A = arena
	match biome_id:
		"bar":
			var flick = 1.0 if fmod(t, 5.3) > 0.12 else 0.3
			Art.text(ci, Vector2(640, 44), "THE BLUE NOTE", 26, Color(0.4 * flick, 0.8 * flick, 2.2 * flick), Style.font_title, 600.0, false)
			Art.text(ci, Vector2(640, 44), "THE BLUE NOTE", 26, Color(0.4, 0.8, 2.0, 0.25 * flick), Style.font_title, 600.0, false)
		"alley":
			var f1 = 1.0 if fmod(t * 1.3, 4.0) > 0.2 else 0.25
			var mag = Color(2.2 * f1, 0.35 * f1, 1.6 * f1)
			var letters = "HOTEL"
			for i in range(letters.length()):
				Art.text(ci, Vector2(232, 24 + i * 20), letters.substr(i, 1), 20, mag, Style.font_mono, 40.0, false)
			Art.text(ci, Vector2(1040, 58), "JAZZ", 34, Color(0.3, 1.8, 2.2), Style.font_title, 200.0, false)
			Art.text(ci, Vector2(640, 110), "OPEN ALL NIGHT", 14, Color(2.0, 0.4, 0.3, 0.9 if fmod(t, 1.0) > 0.5 else 0.5), Style.font_mono, 300.0, false)
			for p in puddles:
				var pc: Vector2 = p["p"]
				var hue = float(p["hue"])
				var col = Color.from_hsv(hue, 0.8, 1.4, 0.2 + 0.08 * sin(t * 2.0 + pc.x))
				ci.draw_line(pc + Vector2(-float(p["rx"]) * 0.6, 0), pc + Vector2(float(p["rx"]) * 0.6, 0), col, 3.0)
				ci.draw_line(pc + Vector2(-float(p["rx"]) * 0.3, 4), pc + Vector2(float(p["rx"]) * 0.4, 4), col, 2.0)
		"casino":
			for i in range(64):
				var on = int(t * 10.0 + i) % 4 == 0
				var bc = Color(2.2, 1.8, 0.8) if on else Color(0.8, 0.6, 0.3)
				ci.draw_circle(Vector2(10 + i * 20, A.position.y - 14), 3.0, bc)
			Art.text(ci, Vector2(640, 42), "THE SILVER DOLLAR", 26, Color(2.0, 1.6, 0.7), Style.font_title, 700.0, false)
		"moon":
			if fmod(t, 7.0) < 0.9:
				var k = fmod(t, 7.0) / 0.9
				var sp = Vector2(lerpf(200, 700, k), lerpf(20, 90, k))
				ci.draw_line(sp, sp - Vector2(60, 12), Color(1.5, 1.5, 2.0, 1.0 - k), 2.0)
	match room_type:
		"shop":
			Art.text(ci, Vector2(640, A.position.y + 58), "SPEAKEASY", 22, Color(2.0, 1.5, 0.6), Style.font_title, 400.0, false)
		"rest":
			Art.text(ci, Vector2(640, A.position.y + 40), "THE POWDER ROOM", 20, Color(2.0, 0.8, 1.4), Style.font_title, 500.0, false)
		"jackpot":
			Art.text(ci, Vector2(640, A.position.y + 40), "JACKPOT  -  FEELING LUCKY?", 20, Color.from_hsv(fmod(t * 0.5, 1.0), 0.7, 2.0), Style.font_title, 700.0, false)

# ---------------------------------------------------------------------------
# OBSTACLES (drawn by y-sorted nodes in the world)
# ---------------------------------------------------------------------------
static func draw_obstacle(ci: CanvasItem, k: String, t: float):
	match k:
		"table":
			Art.shadow(ci, Vector2(0, 2), 30)
			ci.draw_line(Vector2(0, 0), Vector2(0, -20), Color(0.15, 0.08, 0.05), 5.0)
			Art.ellipse(ci, Vector2(0, -22), 30, 15, Color(0.92, 0.9, 0.85))
			Art.ellipse(ci, Vector2(0, -24), 28, 13, Color(0.98, 0.96, 0.92))
			Art.ellipse_line(ci, Vector2(0, -24), 22, 10, Color(0.75, 0.1, 0.12, 0.7), 2.0)
			ci.draw_rect(Rect2(-2, -38, 4, 12), Color(0.95, 0.9, 0.75))
			var fl = 1.0 + 0.2 * sin(t * 17.0) + 0.1 * sin(t * 31.0)
			Art.glow(ci, Vector2(0, -42), 10.0 * fl, Color(2.0, 1.2, 0.4, 0.6), 3)
			Art.ellipse(ci, Vector2(0, -42), 2.2, 4.0 * fl, Color(2.5, 1.8, 0.6))
			ci.draw_circle(Vector2(12, -26), 3, Color(0.8, 0.9, 1.0, 0.6))
		"stool":
			Art.shadow(ci, Vector2(0, 1), 12)
			ci.draw_line(Vector2(0, 0), Vector2(0, -16), Color(0.6, 0.6, 0.65), 3.0)
			Art.ellipse(ci, Vector2(0, -18), 12, 6, Color(0.6, 0.08, 0.1))
			Art.ellipse(ci, Vector2(0, -19), 10, 4.5, Color(0.75, 0.12, 0.15))
		"trash":
			Art.shadow(ci, Vector2(0, 1), 16)
			Art.rrect(ci, Rect2(-14, -32, 28, 32), 4, Color(0.4, 0.42, 0.45))
			for i in range(3):
				ci.draw_line(Vector2(-14, -26 + i * 9), Vector2(14, -26 + i * 9), Color(0.3, 0.32, 0.35), 2.0)
			Art.ellipse(ci, Vector2(0, -33), 16, 6, Color(0.5, 0.52, 0.55))
			ci.draw_rect(Rect2(-4, -44, 8, 10), Color(0.8, 0.75, 0.6))
		"crate":
			Art.shadow(ci, Vector2(0, 1), 22)
			Art.poly(ci, [Vector2(-20, -30), Vector2(-12, -38), Vector2(26, -38), Vector2(20, -30)], Color(0.62, 0.45, 0.25))
			Art.poly(ci, [Vector2(20, -30), Vector2(26, -38), Vector2(26, -6), Vector2(20, 0)], Color(0.4, 0.28, 0.14))
			ci.draw_rect(Rect2(-20, -30, 40, 30), Color(0.52, 0.36, 0.18))
			ci.draw_rect(Rect2(-20, -30, 40, 30), Color(0.3, 0.2, 0.1), false, 2.0)
			ci.draw_line(Vector2(-20, -30), Vector2(20, 0), Color(0.3, 0.2, 0.1), 2.0)
		"dumpster":
			Art.shadow(ci, Vector2(0, 2), 36)
			Art.rrect(ci, Rect2(-32, -38, 64, 38), 3, Color(0.12, 0.3, 0.18))
			Art.poly(ci, [Vector2(-32, -38), Vector2(-26, -48), Vector2(38, -48), Vector2(32, -38)], Color(0.08, 0.22, 0.12))
			for i in range(4):
				ci.draw_line(Vector2(-24 + i * 16, -34), Vector2(-24 + i * 16, -4), Color(0.08, 0.2, 0.1), 2.0)
		"roulette":
			Art.shadow(ci, Vector2(0, 3), 40)
			Art.ellipse(ci, Vector2(0, -20), 40, 20, Color(0.3, 0.15, 0.06))
			Art.ellipse(ci, Vector2(0, -22), 36, 17, Color(0.08, 0.38, 0.18))
			Art.ellipse(ci, Vector2(0, -24), 15, 7.5, Color(0.25, 0.12, 0.05))
			for i in range(12):
				var a = TAU * float(i) / 12.0 + t * 1.5
				var p1 = Vector2(0, -24) + Vector2(cos(a) * 13, sin(a) * 6.5)
				ci.draw_circle(p1, 2.2, Color(0.8, 0.1, 0.1) if i % 2 == 0 else Color(0.05, 0.05, 0.05))
			ci.draw_circle(Vector2(0, -24), 3, Style.GOLD)
			var ba = -t * 4.0
			ci.draw_circle(Vector2(0, -24) + Vector2(cos(ba) * 10, sin(ba) * 5), 1.6, Color(2, 2, 2))
		"cardtable":
			Art.shadow(ci, Vector2(0, 3), 36)
			Art.ellipse(ci, Vector2(0, -18), 34, 17, Color(0.3, 0.15, 0.06))
			Art.ellipse(ci, Vector2(0, -20), 30, 14, Color(0.08, 0.4, 0.2))
			for i in range(4):
				ci.draw_rect(Rect2(-16 + i * 8, -24, 6, 8), Color(0.97, 0.97, 0.94))
			for i in range(3):
				ci.draw_circle(Vector2(14, -18 - i * 2), 4, Color(0.8, 0.1, 0.15))
		"slot":
			Art.shadow(ci, Vector2(0, 2), 18)
			Art.rrect(ci, Rect2(-16, -56, 32, 56), 5, Color(0.55, 0.08, 0.1))
			Art.rrect(ci, Rect2(-12, -44, 24, 14), 2, Color(0.95, 0.93, 0.88))
			Art.text(ci, Vector2(0, -33), "777", 11, Color(0.8, 0.1, 0.1), null, 30.0, false)
			ci.draw_circle(Vector2(0, -52), 3, Color(2.2, 0.5, 0.4) if int(t * 3.0) % 2 == 0 else Color(0.6, 0.2, 0.2))
			ci.draw_line(Vector2(16, -40), Vector2(22, -54), Color(0.8, 0.8, 0.85), 2.0)
			ci.draw_circle(Vector2(22, -55), 3.5, Color(0.9, 0.1, 0.1))
		"boulder":
			Art.shadow(ci, Vector2(0, 2), 28)
			Art.ellipse(ci, Vector2(0, -16), 26, 18, Color(0.38, 0.38, 0.43))
			Art.ellipse(ci, Vector2(-6, -22), 16, 10, Color(0.5, 0.5, 0.55))
			ci.draw_circle(Vector2(8, -12), 4, Color(0.3, 0.3, 0.35))
		"lander":
			Art.shadow(ci, Vector2(0, 2), 36)
			for sx in [-28.0, 28.0]:
				ci.draw_line(Vector2(sx * 0.5, -22), Vector2(sx, 0), Color(0.7, 0.7, 0.75), 3.0)
				ci.draw_line(Vector2(sx - 6, 0), Vector2(sx + 6, 0), Color(0.7, 0.7, 0.75), 3.0)
			Art.rrect(ci, Rect2(-20, -40, 40, 22), 3, Color(0.9, 0.72, 0.25))
			Art.rrect(ci, Rect2(-13, -60, 26, 22), 5, Color(0.8, 0.8, 0.84))
			ci.draw_circle(Vector2(0, -50), 5, Color(0.2, 0.3, 0.5))
		"flag":
			Art.shadow(ci, Vector2(0, 1), 8)
			ci.draw_line(Vector2(0, 0), Vector2(0, -64), Color(0.85, 0.85, 0.9), 2.0)
			var w = sin(t * 3.0) * 3.0
			Art.poly(ci, [Vector2(0, -64), Vector2(34, -62 + w), Vector2(34, -42 + w), Vector2(0, -44)], Color(0.1, 0.12, 0.35))
			Art.star(ci, Vector2(17, -53 + w * 0.5), 6, 2.5, 5, Color(1.8, 1.6, 0.6), 0.0)
