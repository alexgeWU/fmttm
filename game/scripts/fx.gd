extends Node2D

## FX: lightweight particle + floating text system drawn in a single node.
## Also runs ambient weather per biome (smoke, rain, dust, stardust).

const Art = preload("res://scripts/art.gd")

var parts: Array = []
var texts: Array = []
var rings: Array = []
var ambient: String = ""
var ambient_rect: Rect2 = Rect2(0, 0, 1280, 720)
var _amb_t: float = 0.0
var shake_amount: float = 0.0
var _time: float = 0.0

func _ready():
	var m = CanvasItemMaterial.new()
	m.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED
	material = m

func clear():
	parts.clear()
	texts.clear()
	rings.clear()

func shake(amount: float):
	shake_amount = maxf(shake_amount, amount)

## kind: "dot", "spark", "smoke", "ember", "shard", "note", "confetti", "rain", "star"
func burst(pos: Vector2, col: Color, n: int = 10, spd: float = 180.0, size: float = 3.0, kind: String = "dot", life: float = 0.5):
	for i in range(n):
		var a = randf() * TAU
		var v = Vector2(cos(a), sin(a)) * spd * randf_range(0.35, 1.0)
		_add(pos, v, col, size * randf_range(0.7, 1.3), kind, life * randf_range(0.7, 1.2))

func spray(pos: Vector2, dir: Vector2, col: Color, n: int = 8, spd: float = 250.0, spread: float = 0.6, size: float = 3.0, kind: String = "spark", life: float = 0.35):
	var base = dir.angle()
	for i in range(n):
		var a = base + randf_range(-spread, spread)
		_add(pos, Vector2(cos(a), sin(a)) * spd * randf_range(0.4, 1.0), col, size, kind, life * randf_range(0.6, 1.2))

func _add(pos: Vector2, vel: Vector2, col: Color, size: float, kind: String, life: float):
	if parts.size() > 900:
		return
	var grav = 0.0
	var drag = 3.0
	match kind:
		"smoke":
			drag = 1.2
			grav = -20.0
		"ember":
			grav = -60.0
			drag = 1.5
		"shard":
			grav = 380.0
			drag = 1.0
		"confetti":
			grav = 160.0
			drag = 1.6
		"rain":
			drag = 0.0
		"note":
			grav = -40.0
			drag = 1.0
	parts.append({"p": pos, "v": vel, "c": col, "s": size, "k": kind, "life": life, "max": life, "g": grav, "d": drag, "r": randf() * TAU})

func ring(pos: Vector2, col: Color, r0: float, r1: float, dur: float = 0.35, width: float = 4.0):
	rings.append({"p": pos, "c": col, "r0": r0, "r1": r1, "t": 0.0, "dur": dur, "w": width})

func text(pos: Vector2, s: String, col: Color, size: int = 20, life: float = 0.8, rise: float = 50.0):
	if texts.size() > 80:
		texts.pop_front()
	texts.append({"p": pos + Vector2(randf_range(-8, 8), 0), "s": s, "c": col, "size": size, "life": life, "max": life, "rise": rise})

func damage_number(pos: Vector2, amount: float, crit: bool, col: Color = Color(1, 0.95, 0.85)):
	var s = str(int(round(amount)))
	if crit:
		text(pos + Vector2(0, -20), s + "!", Color(1.0, 0.85, 0.2), 28, 0.9, 70.0)
	else:
		text(pos + Vector2(0, -16), s, col, 18, 0.6, 45.0)

func _process(delta):
	_time += delta
	shake_amount = move_toward(shake_amount, 0.0, delta * 40.0)
	var keep = []
	for p in parts:
		p["life"] = float(p["life"]) - delta
		if float(p["life"]) <= 0.0:
			continue
		var v: Vector2 = p["v"]
		v.y += float(p["g"]) * delta
		v = v * maxf(0.0, 1.0 - float(p["d"]) * delta)
		p["v"] = v
		p["p"] = p["p"] + v * delta
		p["r"] = float(p["r"]) + delta * 6.0
		keep.append(p)
	parts = keep
	var kt = []
	for t in texts:
		t["life"] = float(t["life"]) - delta
		if float(t["life"]) > 0.0:
			t["p"] = t["p"] + Vector2(0, -float(t["rise"]) * delta)
			kt.append(t)
	texts = kt
	var kr = []
	for r in rings:
		r["t"] = float(r["t"]) + delta
		if float(r["t"]) < float(r["dur"]):
			kr.append(r)
	rings = kr
	_ambient(delta)
	queue_redraw()

func _ambient(delta):
	if ambient == "":
		return
	_amb_t += delta
	var R = ambient_rect
	match ambient:
		"smoke":
			if _amb_t > 0.25:
				_amb_t = 0.0
				_add(Vector2(randf_range(R.position.x, R.end.x), R.end.y + 10), Vector2(randf_range(-10, 10), -randf_range(15, 35)), Color(0.8, 0.75, 0.7, 0.05), randf_range(40, 80), "smoke", 9.0)
		"rain":
			for i in range(3):
				_add(Vector2(randf_range(R.position.x - 100, R.end.x), R.position.y - 20), Vector2(140, 900), Color(0.6, 0.7, 1.0, 0.35), 1.0, "rain", 0.9)
		"gold":
			if _amb_t > 0.08:
				_amb_t = 0.0
				_add(Vector2(randf_range(R.position.x, R.end.x), randf_range(R.position.y, R.end.y)), Vector2(0, -10), Color(1.6, 1.3, 0.5, 0.8), randf_range(1.0, 2.2), "ember", 1.6)
		"stars":
			if _amb_t > 0.06:
				_amb_t = 0.0
				_add(Vector2(randf_range(R.position.x, R.end.x), randf_range(R.position.y, R.end.y)), Vector2(randf_range(-6, 6), randf_range(-6, 6)), Color(1.2, 1.2, 1.6, 0.9), randf_range(0.8, 2.0), "star", 2.0)

func _draw():
	for r in rings:
		var k = float(r["t"]) / float(r["dur"])
		var rad = lerpf(float(r["r0"]), float(r["r1"]), 1.0 - pow(1.0 - k, 2.0))
		var c: Color = r["c"]
		c.a *= (1.0 - k)
		draw_arc(r["p"], rad, 0, TAU, 48, c, float(r["w"]) * (1.0 - k * 0.5), true)
	for p in parts:
		var k = float(p["life"]) / float(p["max"])
		var c: Color = p["c"]
		var pos: Vector2 = p["p"]
		var s = float(p["s"])
		match String(p["k"]):
			"smoke":
				c.a *= minf(1.0, k * 2.0) * minf(1.0, (1.0 - k) * 4.0)
				draw_circle(pos, s * (1.4 - k * 0.4), c)
			"spark":
				c.a *= k
				var v: Vector2 = p["v"]
				draw_line(pos, pos - v * 0.04, c, s)
			"rain":
				draw_line(pos, pos - Vector2(0.14, 0.9) * 22.0, c, 1.0)
			"shard":
				c.a *= minf(1.0, k * 3.0)
				var rot = float(p["r"])
				var d = Vector2(cos(rot), sin(rot)) * s
				draw_colored_polygon(PackedVector2Array([pos + d, pos + d.orthogonal() * 0.5, pos - d, pos - d.orthogonal() * 0.5]), c)
			"confetti":
				c.a *= minf(1.0, k * 3.0)
				var rot2 = float(p["r"])
				var w = absf(cos(rot2)) * s * 1.5 + 0.5
				draw_rect(Rect2(pos - Vector2(w, s * 0.6), Vector2(w * 2.0, s * 1.2)), c)
			"note":
				c.a *= minf(1.0, k * 2.0)
				Art.note_glyph(self, pos, s, c)
			"star":
				c.a *= sin(k * PI)
				draw_line(pos - Vector2(s * 2.0, 0), pos + Vector2(s * 2.0, 0), c, 1.0)
				draw_line(pos - Vector2(0, s * 2.0), pos + Vector2(0, s * 2.0), c, 1.0)
				draw_circle(pos, s * 0.6, c)
			_:
				c.a *= minf(1.0, k * 2.0)
				draw_circle(pos, s * (0.4 + 0.6 * k), c)
	for t in texts:
		var k = float(t["life"]) / float(t["max"])
		var c: Color = t["c"]
		c.a = minf(1.0, k * 3.0)
		var pop = 1.0 + maxf(0.0, (k - 0.8) * 2.5)
		Art.text(self, t["p"], String(t["s"]), int(float(t["size"]) * pop), c, Style.font_mono, 300.0)
