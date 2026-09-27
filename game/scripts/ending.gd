extends Control

## THE ENDING: plays after beating the Man in the Moon. Six shots, each with its own genre.
## ENTER / SPACE / J = next shot, ESC = skip to the Hat-O-Matic.

const Art = preload("res://scripts/art.gd")
const BoonData = preload("res://scripts/boon_data.gd")

signal finished

var shots: Array = []
var idx: int = 0
var t: float = 0.0
var shot_t: float = 0.0
var done: bool = false
var star_name: String = ""
var hat: Dictionary = {}
var hat_node: Node2D
var stars: Array = []
var crowd: Array = []
var replay: bool = false
var win: Dictionary = {}
var win_skin: Dictionary = {}
var overlay: Control
var shake: float = 0.0
var star_d: Dictionary = {}   # tonight's star: where the dance has them this frame

func _ready():
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	focus_mode = Control.FOCUS_ALL
	grab_focus()
	win = GameData.last_win if not GameData.last_win.is_empty() else GameData.last_run
	star_name = String(win.get("name", GameData.performer(0)))
	win_skin = GameData.skin()
	for sk in GameData.SKINS:
		if sk["id"] == String(win.get("skin", GameData.skin_id)):
			win_skin = sk
	hat = win.get("hat", GameData.get_equipped_hat())
	if typeof(hat) != TYPE_DICTIONARY or hat.is_empty():
		hat = GameData.get_equipped_hat()
	shots = [
		["The tallest hat in the sky hits the dust.", "The last hat empire falls. Luna City's biggest stage belongs to nobody now.", 6.4, "t_ballad"],
		["Ladies and gentlemen... %s!" % star_name, "Built to sweep. Never to sing. Tonight a Rust Row robot headlines the Moon as OL' TIN EYES.", 7.7, "t_exotica"],
		["The Headliners take the bandstand.", "Five outsiders who made it on their own, backing the robot who did the same. One encore, all together.", 9.0, "victory"],
		["Back on Rust Row, the Back Room hears every note.", "Slim drops his bass. Ruby snaps a stick. Doc hits the chord of his life. Up in the rafters, Lady Loom smiles.", 8.0, "hub"],
		["Luna City's marquee has a new name on it.", "The empires' hats come down off the billboards. From tonight on, anybody can book the Moon.", 7.0, "t_mambo"],
		["", "", 12.0, "victory"],
	]
	for i in range(160):
		stars.append({"p": Vector2(randf() * 1280, randf() * 440), "s": randf_range(0.6, 1.8), "ph": randf() * TAU})
	for i in range(34):
		crowd.append({"x": randf_range(20, 1260), "k": randi() % 4, "ph": randf() * TAU, "c": Color.from_hsv(randf(), 0.35, 0.45)})
	hat_node = Art.make_hat_node(hat, 0.5)
	hat_node.visible = false
	add_child(hat_node)
	var ol = CanvasLayer.new()
	ol.layer = 5
	add_child(ol)
	overlay = Control.new()
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay.draw.connect(_draw_overlay)
	ol.add_child(overlay)
	_start_shot()

func _start_shot():
	shot_t = 0.0
	if idx < shots.size():
		Sfx.set_music(String(shots[idx][3]))
		Sfx.play("whoosh_up", 1.2, -8.0)
		if idx == 2:
			Sfx.play("jackpot")
			Sfx.riff("drums")
		elif idx == 3:
			Sfx.riff("piano")

func _unhandled_input(event):
	if done:
		return
	if event.is_action_pressed("pause") or event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		_finish()
	elif event.is_action_pressed("ui_accept") or event.is_action_pressed("interact") or event.is_action_pressed("attack"):
		get_viewport().set_input_as_handled()
		_next()

func _gui_input(event):
	_unhandled_input(event)

func _next():
	if shot_t < 1.0:
		return
	idx += 1
	if idx >= shots.size():
		_finish()
		return
	_start_shot()

func _finish():
	if done:
		return
	done = true
	finished.emit()

func _process(delta):
	t += delta
	if idx == 0 and shot_t < 1.3 and shot_t + delta >= 1.3:
		Sfx.play("slam", 0.7)
		shake = 18.0
	shot_t += delta
	if not done and idx < shots.size() and shot_t > float(shots[idx][2]):
		_next()
	star_d = {}
	if idx == 1:
		star_d = _dance(Vector2(640, 470), 2.0, "croon")
	elif idx == 2:
		star_d = _dance(Vector2(640, 495), 1.7, "dance")
	_place_hat()
	_camera(delta)
	queue_redraw()
	if overlay:
		overlay.queue_redraw()

## A slow push-in (or pull-back) per shot, plus impact shake. The overlay layer doesn't move.
func _camera(delta: float):
	shake = move_toward(shake, 0.0, delta * 30.0)
	if idx >= shots.size():
		return
	var k = clampf(shot_t / float(shots[idx][2]), 0.0, 1.0)
	var z = 1.0
	var piv = Vector2(640, 380)
	match idx:
		0: z = 1.0 + 0.08 * k
		1:
			z = 1.0 + 0.14 * k
			piv = Vector2(640, 400)
		2: z = 1.08 - 0.08 * k
		3: z = 1.0 + 0.06 * k
		4: z = 1.1 - 0.1 * k
		5: z = 1.0 + 0.05 * k
	pivot_offset = piv
	scale = Vector2(z, z)
	position = Vector2(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0)) * shake

func _alpha() -> float:
	if idx >= shots.size():
		return 0.0
	var dur = float(shots[idx][2])
	var fade = maxf(1.0 - shot_t / 0.3, (shot_t - dur + 0.3) / 0.3)
	return 1.0 - clampf(fade, 0.0, 1.0)

func _head(p: Vector2, sc: float) -> Vector2:
	return p + Vector2(0, (Art.HEAD_TOP + Art.robot_bob(t, false)) * sc)

func _place_hat():
	hat_node.visible = false
	if idx >= shots.size():
		return
	var pos = Vector2.ZERO
	var sc = 1.0
	var rot = 0.0
	var flip = false
	match idx:
		1, 2:
			if star_d.is_empty():
				return
			var dp: Vector2 = star_d["pos"]
			var pz: Dictionary = star_d["pose"]
			var fc: Vector2 = star_d["facing"]
			sc = float(star_d["sc"])
			rot = float(star_d["rot"])
			flip = fc.x < -0.2
			var hb = float(pz["bob"]) if pz.has("bob") else Art.robot_bob(t, bool(star_d["moving"]))
			var hl = float(pz.get("lift", 0.0))
			pos = dp + (Vector2(fc.x * 1.5, Art.HEAD_TOP + hb - hl) * sc).rotated(rot)
		5:
			pos = Vector2(640, 250 + sin(t * 1.3) * 8.0)
			sc = 2.4
			rot = sin(t * 0.8) * 0.1
		_:
			return
	hat_node.visible = true
	hat_node.position = pos
	hat_node.scale = Vector2(-sc if flip else sc, sc)
	hat_node.rotation = rot
	var a = _alpha()
	if idx == 5:
		a *= 1.0 - clampf((shot_t - 8.2) / 0.8, 0.0, 1.0)
	if hat.get("is_chroma", false):
		var c = Art.chroma_color(t)
		hat_node.modulate = Color(c.r * 1.3, c.g * 1.3, c.b * 1.3, a)
	else:
		hat_node.modulate = Color(1, 1, 1, a)

# ---------------------------------------------------------------------------
# DRAW
# ---------------------------------------------------------------------------
func _draw():
	draw_rect(Rect2(0, 0, 1280, 720), Color(0.02, 0.015, 0.04))
	if idx >= shots.size():
		return
	var k = clampf(shot_t / 0.6, 0.0, 1.0)
	match idx:
		0: _s_hat_falls(k)
		1: _s_moon_stage(k)
		2: _s_encore(k)
		3: _s_radio(k)
		4: _s_marquee(k)
		5: _s_curtain(k)

func _draw_overlay():
	var o = overlay
	if idx >= shots.size():
		o.draw_rect(Rect2(0, 0, 1280, 720), Color(0, 0, 0, 1))
		return
	var k = clampf(shot_t / 0.6, 0.0, 1.0)
	# soft vignette
	for i in range(8):
		var a = 0.05 * float(8 - i) / 8.0
		o.draw_rect(Rect2(i * 12, 56, 12, 518), Color(0, 0, 0, a * 2.0))
		o.draw_rect(Rect2(1280 - (i + 1) * 12, 56, 12, 518), Color(0, 0, 0, a * 2.0))
	o.draw_rect(Rect2(0, 0, 1280, 56), Color(0, 0, 0))
	o.draw_rect(Rect2(0, 574, 1280, 146), Color(0, 0, 0))
	o.draw_line(Vector2(0, 56), Vector2(1280, 56), Color(Style.GOLD.r, Style.GOLD.g, Style.GOLD.b, 0.35), 1.0)
	o.draw_line(Vector2(0, 574), Vector2(1280, 574), Color(Style.GOLD.r, Style.GOLD.g, Style.GOLD.b, 0.35), 1.0)
	var sh = shots[idx]
	if String(sh[0]) != "":
		var cw = Style.font_title.get_string_size(String(sh[0]), HORIZONTAL_ALIGNMENT_LEFT, -1, 30).x * k
		o.draw_line(Vector2(640 - cw * 0.5 - 30, 634), Vector2(640 + cw * 0.5 + 30, 634), Color(Style.GOLD.r, Style.GOLD.g, Style.GOLD.b, 0.4 * k), 1.0)
		Art.text(o, Vector2(640, 622), String(sh[0]), 30, Color(1.0, 0.9, 0.7, k), Style.font_title, 1240.0)
	if String(sh[1]) != "":
		var k2 = clampf((shot_t - 0.45) / 0.6, 0.0, 1.0)
		Art.text(o, Vector2(640, 662), String(sh[1]), 18, Color(0.85, 0.8, 0.72, k2), Style.font_body, 1240.0)
	for j in range(shots.size()):
		o.draw_circle(Vector2(640 - (shots.size() - 1) * 8 + j * 16, 694), 3.5, Style.GOLD if j <= idx else Color(0.3, 0.3, 0.3))
	Art.text(o, Vector2(1160, 704), "ENTER next   ESC skip", 11, Style.MUTED, Style.font_mono, 300.0)
	var fade = 1.0 - _alpha()
	if fade > 0.0:
		o.draw_rect(Rect2(0, 0, 1280, 720), Color(0, 0, 0, fade))

# ---------------------------------------------------------------------------
# SHOW EFFECTS
# ---------------------------------------------------------------------------
## Analytical firework: launches at t0 (seconds into the shot), bursts at `center`.
func _firework(center: Vector2, t0: float, col: Color, n: int = 28, spd: float = 150.0):
	var age = shot_t - t0
	if age < -0.7 or age > 2.0:
		return
	if age < 0.0:
		var rise = 1.0 + age / 0.7
		var rp = Vector2(center.x + sin(t0 * 7.0) * 20.0 * (1.0 - rise), lerpf(620.0, center.y, rise))
		draw_line(rp, rp + Vector2(0, 26), Color(2.0, 1.7, 1.0, 0.8), 2.0)
		draw_circle(rp, 2.5, Color(2.4, 2.2, 1.6))
		return
	if age < 0.18:
		Art.glow(self, center, 70.0 * (1.0 - age / 0.18) + 10.0, Color(col.r * 1.6, col.g * 1.6, col.b * 1.6, 0.6), 3)
	var fade = 1.0 - age / 2.0
	var spread = spd * (1.0 - exp(-age * 3.0))
	for i in range(n):
		var a = TAU * float(i) / float(n) + t0 * 3.0
		var dir = Vector2(cos(a), sin(a))
		var p = center + dir * spread + Vector2(0, 38.0 * age * age)
		var c = Color(col.r * 1.8, col.g * 1.8, col.b * 1.8, fade)
		draw_line(p, p - dir * 10.0 * fade - Vector2(0, 4.0 * age), Color(c.r, c.g, c.b, fade * 0.6), 1.5)
		draw_circle(p, 2.0 * fade + 0.6, c)
		if i % 3 == 0 and fmod(t * 20.0 + i, 2.0) < 1.0:
			draw_circle(p + dir * 4.0, 1.2, Color(2.4, 2.4, 2.2, fade))

func _fireworks_show(ystart: float, count: int, period: float):
	var cols = [Color(1.0, 0.4, 0.5), Color(0.5, 0.8, 1.0), Color(1.0, 0.85, 0.3), Color(0.5, 1.0, 0.6), Color(0.85, 0.5, 1.0)]
	for i in range(count):
		var cycle = floor(maxf(0.0, shot_t - float(i) * period * 0.37) / period)
		var t0 = cycle * period + float(i) * period * 0.37 + 0.6
		var seed_x = fmod(float(i) * 263.0 + cycle * 97.0, 1080.0) + 100.0
		var seed_y = ystart + fmod(float(i) * 53.0 + cycle * 31.0, 140.0)
		_firework(Vector2(seed_x, seed_y), t0, cols[(i + int(cycle)) % cols.size()], 26 + (i % 3) * 6, 120.0 + float(i % 4) * 25.0)

func _searchlight(base: Vector2, ang: float, length: float, col: Color, width: float = 70.0):
	var d = Vector2(cos(ang), sin(ang))
	var side = d.orthogonal()
	var far = base + d * length
	draw_colored_polygon(PackedVector2Array([base - side * 6.0, base + side * 6.0, far + side * width, far - side * width]), Color(col.r, col.g, col.b, 0.07))
	draw_colored_polygon(PackedVector2Array([base - side * 3.0, base + side * 3.0, far + side * width * 0.45, far - side * width * 0.45]), Color(col.r, col.g, col.b, 0.08))
	Art.glow(self, base, 18, Color(col.r * 1.5, col.g * 1.5, col.b * 1.5, 0.6), 3)

func _god_rays(c: Vector2, col: Color, n: int, length: float, spin: float = 0.1):
	for i in range(n):
		var a = t * spin + TAU * float(i) / float(n)
		var w = 0.06 + 0.03 * sin(t * 1.3 + i)
		var p1 = c + Vector2(cos(a - w), sin(a - w)) * length
		var p2 = c + Vector2(cos(a + w), sin(a + w)) * length
		draw_colored_polygon(PackedVector2Array([c, p1, p2]), Color(col.r, col.g, col.b, 0.06))

func _lens_flare(p: Vector2, col: Color, strength: float):
	if strength <= 0.0:
		return
	draw_line(p - Vector2(220, 0) * strength, p + Vector2(220, 0) * strength, Color(col.r * 2.0, col.g * 2.0, col.b * 2.0, 0.35 * strength), 2.0)
	draw_line(p - Vector2(0, 40) * strength, p + Vector2(0, 40) * strength, Color(col.r * 2.0, col.g * 2.0, col.b * 2.0, 0.25 * strength), 1.5)
	Art.glow(self, p, 30.0 * strength, Color(col.r * 1.8, col.g * 1.8, col.b * 1.8, 0.5 * strength), 3)
	var to_c = Vector2(640, 360) - p
	for i in range(3):
		var fp = p + to_c * (0.6 + i * 0.45)
		draw_circle(fp, 10.0 + i * 8.0, Color(col.r, col.g, col.b, 0.07 * strength))

func _dust_motes(area: Rect2, col: Color, n: int = 30):
	for i in range(n):
		var fx_ = area.position.x + fmod(float(i) * 97.3 + t * (6.0 + float(i % 5)), area.size.x)
		var fy = area.position.y + fmod(float(i) * 61.7 + sin(t * 0.7 + i) * 20.0 + t * 4.0, area.size.y)
		draw_circle(Vector2(fx_, fy), 1.2 + float(i % 3) * 0.5, Color(col.r, col.g, col.b, 0.35 + 0.3 * sin(t * 2.0 + i)))

func _confetti_rain(n: int, speed: float):
	for i in range(n):
		var cf = fmod(float(i) * 0.37 + shot_t * speed / 500.0, 1.0)
		var cx = fmod(float(i) * 71.0, 1280.0) + sin(t * 2.0 + i) * 24.0
		var cy = 60.0 + cf * 520.0
		var flip = absf(sin(t * 6.0 + i))
		draw_rect(Rect2(cx - 4.0 * flip, cy, 8.0 * flip + 1.0, 4.0), Color.from_hsv(fmod(float(i) * 0.13, 1.0), 0.65, 1.5))

## Beats elapsed in the current song (dancing and lights lock to the band).
func _beat() -> float:
	var bpm = 150.0
	if float(Sfx._bpm) > 1.0:
		bpm = float(Sfx._bpm)
	return shot_t * bpm / 60.0   # each shot's song starts fresh, so count from the shot

## A dance routine locked to the beat. Returns where the dancer is this frame, plus a
## leg/arm pose for Art.draw_robot. Feet only leave the floor when they're stepping.
func _dance(base: Vector2, sc: float, style: String, phase: float = 0.0) -> Dictionary:
	var b = _beat() + phase
	var ph = fmod(b, 1.0)
	var ez = ph * ph * (3.0 - 2.0 * ph)
	var d = {"pos": base, "sc": sc, "rot": 0.0, "flip": false, "moving": false, "facing": Vector2.DOWN, "pose": {}}
	var pose = {}
	match style:
		"croon":
			# feet planted, a soft knee on each beat, a toe tap, one hand reaching out to the crowd
			pose["bob"] = 1.2 * (0.5 + 0.5 * cos(ph * TAU))
			pose["l1"] = 0.0
			pose["l2"] = sin(ph * PI) * 1.5 if int(floor(b)) % 2 == 0 else 0.0
			var reach = 0.5 + 0.5 * sin(b * PI * 0.25)
			pose["hand_r"] = Vector2(6.0 + 4.0 * reach, 8.0 - 14.0 * reach)
			pose["hand_l"] = Vector2(-4.0, 13.0)
			d["rot"] = sin(b * PI * 0.5) * 0.04
		"dance":
			var span = 12.0
			var bar = fmod(b, 8.0)
			var x = 0.0
			if bar < 6.0:
				# step-touch: step right, tap, step left, tap. Knees dip on every beat.
				var q = fmod(b, 4.0)
				var lift_l = 0.0
				var lift_r = 0.0
				if q < 1.0:
					x = ez * span
					lift_r = sin(ph * PI) * 4.5
				elif q < 2.0:
					x = span
					lift_l = sin(ph * PI) * 2.5
				elif q < 3.0:
					x = span * (1.0 - ez)
					lift_l = sin(ph * PI) * 4.5
				else:
					lift_r = sin(ph * PI) * 2.5
				pose["bob"] = 3.0 * (0.5 + 0.5 * cos(ph * TAU))
				pose["l1"] = lift_l
				pose["l2"] = lift_r
				pose["lx1"] = -1.0 - lift_l * 0.35
				pose["lx2"] = 1.0 + lift_r * 0.35
				# finger snaps: the arm on the side you're stepping toward comes up
				var arm_k = 0.5 + 0.5 * sin(b * PI * 0.5)
				pose["hand_r"] = Vector2(6.0, 12.0 - 20.0 * arm_k)
				pose["hand_l"] = Vector2(-6.0, 12.0 - 20.0 * (1.0 - arm_k))
				d["rot"] = sin(b * PI * 0.5) * 0.06
			else:
				# every eight counts: a spin on the spot, then a leap back to centre
				var u = (bar - 6.0) / 2.0
				if u < 0.5:
					var views = [Vector2.DOWN, Vector2(1.0, 0.2), Vector2.UP, Vector2(-1.0, 0.2)]
					d["facing"] = views[int(u / 0.5 * 4.0) % 4]
					x = span
					pose["bob"] = 3.0
					pose["l1"] = 0.0
					pose["l2"] = 1.5 * sin(u / 0.5 * PI)   # pivot on the left foot
					pose["lx1"] = -1.0
					pose["lx2"] = 1.0
					pose["hand_l"] = Vector2(-6.0, 2.0)
					pose["hand_r"] = Vector2(6.0, 2.0)
				else:
					var lk = (u - 0.5) / 0.5
					var arc = sin(lk * PI)
					x = span * (1.0 - lk * lk * (3.0 - 2.0 * lk))
					var up = smoothstep(0.0, 0.2, lk) * (1.0 - smoothstep(0.8, 1.0, lk))
					pose["lift"] = arc * 14.0
					pose["bob"] = 3.0 * (1.0 - arc)   # crouch, spring up, land soft
					pose["l1"] = 2.5 * arc
					pose["l2"] = 2.5 * arc
					pose["lx1"] = -1.0 - 2.0 * arc
					pose["lx2"] = 1.0 + 2.0 * arc
					pose["hand_l"] = Vector2(-6.0, 2.0).lerp(Vector2(-12.0, -14.0), up)
					pose["hand_r"] = Vector2(6.0, 2.0).lerp(Vector2(12.0, -14.0), up)
			d["pos"] = base + Vector2((x - span * 0.5) * sc, 0.0)
	d["pose"] = pose
	return d

func _dancer(d: Dictionary, skin: Dictionary = {}):
	_robot(d["pos"], float(d["sc"]), d["facing"], skin, bool(d["moving"]), float(d["rot"]), bool(d["flip"]), d["pose"])

## A single eighth note, or a beamed pair.
func _note_at(p: Vector2, s: float, col: Color, kind: int):
	if kind % 3 == 2:
		var w = maxf(1.5, s * 0.16)
		Art.ellipse(self, p + Vector2(-s * 0.35, s * 0.55), s * 0.42, s * 0.3, col)
		Art.ellipse(self, p + Vector2(s * 0.85, s * 0.35), s * 0.42, s * 0.3, col)
		draw_line(p + Vector2(0, s * 0.5), p + Vector2(0, -s * 0.7), col, w)
		draw_line(p + Vector2(s * 1.2, s * 0.3), p + Vector2(s * 1.2, -s * 0.9), col, w)
		draw_line(p + Vector2(0, -s * 0.7), p + Vector2(s * 1.2, -s * 0.9), col, maxf(2.0, s * 0.28))
	else:
		Art.note_glyph(self, p, s, col)

## Notes floating up and out of a point, fading in and out.
func _note_fountain(origin: Vector2, n: int, height: float, col: Color, spread: float = 60.0, speed: float = 0.45):
	for i in range(n):
		var nt = fmod(t * speed + float(i) / float(n) + origin.x * 0.0013, 1.0)
		var nx = origin.x + sin(float(i) * 2.4) * spread * nt + sin(t * 2.0 + i) * 10.0 * nt
		var ny = origin.y - nt * height
		var na = sin(nt * PI)
		var ns = (9.0 + float(i % 3) * 3.0) * (0.7 + 0.5 * nt)
		_note_at(Vector2(nx, ny), ns, Color(col.r, col.g, col.b, na), i)

## A ring of rainbow notes circling a point.
func _note_swirl(c: Vector2, rx: float, ry: float, n: int):
	for i in range(n):
		var a = t * 1.3 + TAU * float(i) / float(n)
		var hue = fmod(float(i) / float(n) + t * 0.1, 1.0)
		var bob = sin(t * 3.0 + i) * 6.0
		_note_at(c + Vector2(cos(a) * rx, sin(a) * ry + bob), 11.0, Color.from_hsv(hue, 0.45, 1.9, 0.9), i)

## Five wavy staff lines across the sky with notes riding along them.
func _music_staff(y0: float, amp: float, alpha: float, col: Color):
	if alpha <= 0.0:
		return
	for li in range(5):
		var pts = PackedVector2Array()
		for xi in range(34):
			var x = float(xi) * 40.0
			pts.append(Vector2(x, y0 + li * 9.0 + sin(x * 0.006 + t * 1.4) * amp))
		draw_polyline(pts, Color(col.r, col.g, col.b, alpha * 0.45), 1.5)
	for ni in range(9):
		var x2 = fmod(float(ni) * 150.0 + t * 90.0, 1360.0) - 40.0
		var yb = y0 + sin(x2 * 0.006 + t * 1.4) * amp
		var off = float((ni * 3) % 9) * 4.5
		_note_at(Vector2(x2, yb + off - 4.0), 12.0, Color(col.r * 1.3, col.g * 1.3, col.b * 1.3, alpha), ni)

## Rings that pulse out across the stage floor on every beat.
func _beat_rings(c: Vector2, col: Color, rmax: float = 260.0):
	var b = _beat()
	for j in range(2):
		var u = fmod(b * 0.5 + float(j) * 0.5, 1.0)
		var rr = 40.0 + u * rmax
		Art.ellipse_line(self, c, rr, rr * 0.22, Color(col.r, col.g, col.b, 0.5 * (1.0 - u)), 3.0)

func _sky(tint: Color):
	for i in range(18):
		var kk = float(i) / 18.0
		draw_rect(Rect2(0, i * 32, 1280, 33), Color(0.02, 0.02, 0.06).lerp(tint, kk))
	for s in stars:
		var a = 0.4 + 0.5 * sin(t * 2.0 + float(s["ph"]))
		draw_circle(s["p"], float(s["s"]), Color(1, 1, 1, a * 0.7))

func _robot(p: Vector2, sc: float, facing: Vector2 = Vector2.DOWN, skin: Dictionary = {}, moving: bool = false, rot: float = 0.0, flip: bool = false, pose: Dictionary = {}):
	var sk = skin if not skin.is_empty() else win_skin
	draw_set_transform(p, rot, Vector2(-sc if flip else sc, sc))
	Art.draw_robot(self, t, facing, moving, 0.0, sk["body"], sk, "", pose)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

func _crowd(y: float, lit: float):
	# Luna City's audience: aliens, antennae and all
	var cb = _beat()
	for c in crowd:
		var cx = float(c["x"])
		var bob = pow(absf(sin(cb * PI + float(c["ph"]) * 0.3)), 2.0) * 10.0 * lit
		var col: Color = c["c"]
		var hp = Vector2(cx, y - 30 - bob)
		draw_rect(Rect2(cx - 18, y - 22 - bob, 36, 60), col.darkened(0.3))
		draw_circle(hp, 14, col)
		match int(c["k"]):
			0:
				draw_line(hp + Vector2(-6, -10), hp + Vector2(-12, -26), col, 2.0)
				draw_line(hp + Vector2(6, -10), hp + Vector2(12, -26), col, 2.0)
				draw_circle(hp + Vector2(-12, -27), 3, Color(1.6, 1.4, 0.6))
				draw_circle(hp + Vector2(12, -27), 3, Color(1.6, 1.4, 0.6))
			1:
				draw_circle(hp, 5, Color(0.1, 0.1, 0.1))
				draw_circle(hp, 2, Color(1.5, 1.5, 1.5))
			2:
				Art.poly(self, [hp + Vector2(-10, -8), hp + Vector2(-4, -22), hp + Vector2(0, -10)], col)
				Art.poly(self, [hp + Vector2(10, -8), hp + Vector2(4, -22), hp + Vector2(0, -10)], col)
		if lit > 0.5 and int(c["k"]) != 1:
			var wave = sin(cb * PI * 0.5 + float(c["ph"])) * 10.0
			draw_line(Vector2(cx - 14, y - 10 - bob), Vector2(cx - 22 + wave, y - 36 - bob * 2.0), col, 4.0)
			draw_line(Vector2(cx + 14, y - 10 - bob), Vector2(cx + 22 + wave, y - 36 - bob * 2.0), col, 4.0)
			draw_circle(Vector2(cx - 22 + wave, y - 37 - bob * 2.0), 3.0, col.lightened(0.2))
			draw_circle(Vector2(cx + 22 + wave, y - 37 - bob * 2.0), 3.0, col.lightened(0.2))

func _s_hat_falls(k: float):
	_sky(Color(0.12, 0.12, 0.25))
	draw_rect(Rect2(0, 420, 1280, 154), Color(0.42, 0.43, 0.48))
	for cr in [Vector2(200, 480), Vector2(420, 520), Vector2(900, 470), Vector2(1100, 530)]:
		Art.ellipse(self, cr, 50, 14, Color(0.34, 0.35, 0.4))
	# the defeated Chairman, dimmed, behind
	_god_rays(Vector2(640, 250), Color(1.0, 0.95, 0.7), 14, 700.0, 0.05)
	Art.boss_portrait(self, "moon_man", t, Vector2(640, 380), 1.2)
	draw_rect(Rect2(0, 56, 1280, 518), Color(0.02, 0.02, 0.06, 0.55))
	var fall = clampf(shot_t / 1.3, 0.0, 1.0)
	var hy = lerpf(60.0, 470.0, fall * fall)
	if fall < 1.0:
		for i in range(7):
			var lx = 610.0 + i * 10.0
			draw_line(Vector2(lx, hy - 60 - i * 9.0), Vector2(lx, hy - 160 - i * 16.0), Color(1.0, 1.0, 1.0, 0.18 * fall), 2.0)
	else:
		var imp = shot_t - 1.3
		if imp < 0.35:
			draw_rect(Rect2(0, 56, 1280, 518), Color(1.0, 0.95, 0.85, 0.35 * (1.0 - imp / 0.35)))
		Art.ellipse_line(self, Vector2(640, 478), 40.0 + imp * 520.0, (40.0 + imp * 520.0) * 0.25, Color(1.2, 1.2, 1.3, maxf(0.0, 0.8 - imp * 0.5)), 4.0)
	var spin = (1.0 - fall) * 7.0
	draw_set_transform(Vector2(640, hy), spin, Vector2.ONE)
	Art.top_hat(self, Vector2.ZERO, 2.4)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	if fall >= 1.0:
		var dt = shot_t - 1.3
		for i in range(12):
			var a = PI + PI * float(i) / 11.0
			var dp = Vector2(640, 475) + Vector2(cos(a), sin(a) * 0.4) * (40.0 + dt * 140.0)
			draw_circle(dp, maxf(1.0, 10.0 - dt * 6.0), Color(0.7, 0.7, 0.75, maxf(0.0, 0.6 - dt * 0.4)))

func _s_moon_stage(k: float):
	var b = _beat()
	_sky(Color(0.18, 0.08, 0.24))
	_fireworks_show(110.0, 3, 2.6)
	_searchlight(Vector2(260, 500), -PI * 0.5 + sin(t * 0.7) * 0.5, 620.0, Color(1.0, 0.95, 0.7))
	_searchlight(Vector2(1020, 500), -PI * 0.5 + sin(t * 0.7 + 2.0) * 0.5, 620.0, Color(0.7, 0.85, 1.0))
	Art.glow(self, Vector2(1080, 120), 90, Color(0.4, 0.7, 1.4, 0.3), 4)
	draw_circle(Vector2(1080, 120), 46, Color(0.15, 0.35, 0.8))
	draw_circle(Vector2(1068, 110), 14, Color(0.2, 0.6, 0.3))
	# the song, drifting across the sky on a music staff
	_music_staff(150.0, 22.0, 0.75 * k, Color(1.4, 1.15, 0.6))
	# Luna City's biggest stage
	Art.rrect(self, Rect2(240, 380, 800, 120), 10, Color(0.2, 0.18, 0.28))
	draw_line(Vector2(240, 380), Vector2(1040, 380), Style.GOLD, 3.0)
	for i in range(30):
		var on = (int(b * 2.0) + i) % 3 == 0 or fmod(b, 4.0) < 0.12
		draw_circle(Vector2(254 + i * 26.0, 392), 3.5, Color(2.2, 1.8, 0.7) if on else Color(0.7, 0.55, 0.3))
	draw_colored_polygon(PackedVector2Array([Vector2(620, 56), Vector2(660, 56), Vector2(780, 490), Vector2(500, 490)]), Color(1.3, 1.2, 0.9, 0.16))
	Art.ellipse(self, Vector2(640, 486), 140, 26, Color(1.3, 1.2, 0.9, 0.2))
	_beat_rings(Vector2(640, 486), Color(1.4, 1.2, 0.8), 200.0)
	_dust_motes(Rect2(540, 80, 200, 400), Color(1.4, 1.3, 1.0), 26)
	if not star_d.is_empty():
		_dancer(star_d)
	_lens_flare(_head(Vector2(640, 470), 2.0) + Vector2(18, -40), Color(1.0, 0.95, 0.8), clampf((shot_t - 1.0) / 0.8, 0.0, 1.0) * (0.75 + 0.25 * sin(t * 3.0)))
	# the first notes of the night, floating up out of the spotlight
	_note_fountain(Vector2(640, 330), 12, 260.0, Color(1.7, 1.4, 0.6), 150.0, 0.35)
	_crowd(560, k)

## The encore: all five Headliners at big-band stands on the riser (Lady Luna leading from the
## raised centre podium), tonight's star dancing front and centre below them.
func _s_encore(k: float):
	var b = _beat()
	_sky(Color(0.2, 0.08, 0.26))
	_fireworks_show(100.0, 6, 2.2)
	var sl_cols = [Color(1.0, 0.95, 0.7), Color(1.0, 0.6, 0.8), Color(0.6, 0.9, 1.0), Color(0.8, 1.0, 0.7)]
	var sl_x = [140.0, 420.0, 860.0, 1140.0]
	for si in range(4):
		_searchlight(Vector2(sl_x[si], 520), -PI * 0.5 + sin(t * 0.9 + si * 1.3) * 0.55, 640.0, sl_cols[si], 55.0)
	_god_rays(Vector2(640, 430), Color(1.2, 1.0, 0.6), 18, 560.0, 0.3)
	if fmod(b, 4.0) < 0.1:
		draw_rect(Rect2(0, 56, 1280, 518), Color(1.0, 0.95, 0.8, 0.05))
	# the riser (bandstand) and the main stage
	Art.rrect(self, Rect2(135, 340, 1010, 64), 8, Color(0.16, 0.13, 0.24))
	draw_line(Vector2(135, 340), Vector2(1145, 340), Style.GOLD, 2.0)
	Art.rrect(self, Rect2(200, 404, 880, 106), 10, Color(0.22, 0.18, 0.3))
	draw_line(Vector2(200, 404), Vector2(1080, 404), Style.GOLD, 3.0)
	for i in range(34):
		var on = (int(b * 2.0) + i) % 3 == 0 or fmod(b, 4.0) < 0.15
		draw_circle(Vector2(214 + i * 25.5, 416), 3.5, Color(2.2, 1.8, 0.7) if on else Color(0.7, 0.55, 0.3))
	# all five Headliners on the bandstand, Lady Luna leading from the raised centre podium
	Art.rrect(self, Rect2(556, 296, 168, 46), 6, Color(0.2, 0.16, 0.3))
	draw_line(Vector2(556, 296), Vector2(724, 296), Style.GOLD, 2.0)
	var band = [["baron", 200.0, 362.0], ["fortuna", 420.0, 362.0], ["luna", 640.0, 248.0], ["ivory", 860.0, 362.0], ["bruno", 1080.0, 362.0]]
	for i in range(band.size()):
		var pid = String(band[i][0])
		var bx = float(band[i][1])
		var sy = float(band[i][2])
		var lit = clampf((shot_t - 0.3 - absf(float(i) - 2.0) * 0.3) / 0.3, 0.0, 1.0)
		var pc: Color = BoonData.PATRONS[pid]["color"]
		var hc = Color(pc.r * 1.6, pc.g * 1.6, pc.b * 1.6)
		draw_colored_polygon(PackedVector2Array([Vector2(bx - 12, 56), Vector2(bx + 12, 56), Vector2(bx + 72, sy + 42), Vector2(bx - 72, sy + 42)]), Color(pc.r, pc.g, pc.b, 0.09 * lit))
		if lit > 0.0:
			var bob = pow(absf(sin((b + i * 0.5) * PI)), 2.0) * 8.0
			var sway = sin((b + float(i)) * PI * 0.5) * 0.1
			Art.patron_portrait(self, pid, t, Vector2(bx, sy + 32 - bob), 0.78 * (0.7 + 0.3 * lit), true, sway)
		# big-band music stand: stripe, emblem and name on the front
		Art.rrect(self, Rect2(bx - 54, sy, 108, 50), 4, Color(0.12, 0.08, 0.14))
		draw_rect(Rect2(bx - 54, sy, 108, 50), Style.GOLD, false, 2.0)
		draw_rect(Rect2(bx - 54, sy + 6, 108, 4), Color(pc.r * 1.3, pc.g * 1.3, pc.b * 1.3))
		Art.text(self, Vector2(bx, sy + 31), String(BoonData.PATRONS[pid]["glyph"]), 18, hc, null, 60.0, false)
		Art.text(self, Vector2(bx, sy + 45), String(BoonData.PATRONS[pid]["name"]).to_upper(), 10, Color(1.0, 0.9, 0.7), Style.font_mono, 104.0, false)
		if lit > 0.0:
			_note_fountain(Vector2(bx, sy - 62), 5, 200.0, hc, 45.0, 0.45)
	# tonight's star, dancing front and centre in the big spotlight
	draw_colored_polygon(PackedVector2Array([Vector2(615, 56), Vector2(665, 56), Vector2(760, 505), Vector2(520, 505)]), Color(1.3, 1.2, 0.9, 0.14))
	Art.ellipse(self, Vector2(640, 500), 120, 22, Color(1.3, 1.2, 0.9, 0.22))
	_beat_rings(Vector2(640, 500), Color(1.6, 1.3, 0.7), 300.0)
	if not star_d.is_empty():
		_dancer(star_d)
	_note_swirl(Vector2(640, 420), 130.0, 34.0, 8)
	_confetti_rain(50, 200.0)
	_crowd(560, k)

func _s_radio(k: float):
	# the Back Room on Earth, everyone crowded round the bar radio
	draw_rect(Rect2(0, 56, 1280, 518), Color(0.2, 0.05, 0.07))
	draw_rect(Rect2(0, 420, 1280, 154), Color(0.24, 0.13, 0.08))
	Art.text(self, Vector2(640, 110), "THE BLUE NOTE", 26, Color(0.5, 0.9, 2.2), Style.font_title, 600.0, false)
	Art.rrect(self, Rect2(470, 330, 340, 60), 6, Color(0.3, 0.13, 0.06))
	draw_line(Vector2(470, 336), Vector2(810, 336), Style.GOLD, 2.0)
	# moonlight through the high windows, dust hanging in it
	for wx in [180.0, 1040.0]:
		draw_rect(Rect2(wx, 70, 60, 40), Color(0.5, 0.65, 1.0, 0.5))
		draw_colored_polygon(PackedVector2Array([Vector2(wx, 110), Vector2(wx + 60, 110), Vector2(wx + 220 * (1.0 if wx < 640.0 else -1.0) + 60, 560), Vector2(wx + 220 * (1.0 if wx < 640.0 else -1.0) - 60, 560)]), Color(0.6, 0.75, 1.0, 0.07))
	_dust_motes(Rect2(100, 110, 1080, 440), Color(0.9, 0.9, 1.1), 36)
	Art.glow(self, Vector2(640, 297), 110 + 12 * sin(t * 6.0), Color(1.4, 1.1, 0.6, 0.35), 5)
	# the radio
	Art.rrect(self, Rect2(590, 262, 100, 70), 12, Color(0.55, 0.35, 0.18))
	Art.rrect(self, Rect2(600, 272, 50, 50), 8, Color(0.25, 0.15, 0.08))
	for i in range(4):
		draw_line(Vector2(604, 280 + i * 11), Vector2(646, 280 + i * 11), Color(0.4, 0.28, 0.15), 2.0)
	draw_circle(Vector2(672, 286), 8, Color(0.9, 0.85, 0.7))
	draw_circle(Vector2(672, 312), 6, Color(0.9, 0.85, 0.7))
	for i in range(3):
		var wt = fmod(t * 0.9 + i * 0.33, 1.0)
		draw_arc(Vector2(640, 262), 20 + wt * 60.0, PI * 1.15, PI * 1.85, 12, Color(1.4, 1.2, 0.6, 1.0 - wt), 2.0)
	# the band + the understudies, jumping
	var jump = absf(sin(_beat() * PI))
	var band = [[260.0, 4, "SLIM"], [400.0, 6, "RUBY"], [880.0, 7, "DOC"]]
	for b in band:
		var bx = float(b[0])
		_robot(Vector2(bx, 520 - jump * 26.0), 1.4, Vector2(0.3, 1.0).normalized(), GameData.SKINS[int(b[1])])
		Art.text(self, Vector2(bx, 548), String(b[2]), 13, Color(1.0, 0.85, 0.55), Style.font_mono, 120.0)
	for i in range(4):
		var qd = _dance(Vector2(1000.0 + i * 60.0, 520), 1.0, "dance", float(i) * 0.5)
		_dancer(qd, GameData.SKINS[(i * 3 + 1) % GameData.SKINS.size()])
	# the radio is pouring music into the room
	_note_fountain(Vector2(640, 262), 10, 200.0, Color(1.7, 1.4, 0.6), 160.0, 0.5)
	_beat_rings(Vector2(640, 520), Color(1.4, 1.1, 0.6), 260.0)
	# Doc's big chord: a burst of notes
	for i in range(8):
		var nt = fmod(t * 0.6 + i * 0.125, 1.0)
		var a = TAU * float(i) / 8.0
		Art.note_glyph(self, Vector2(880, 440) + Vector2(cos(a), sin(a) * 0.6) * (30.0 + nt * 150.0), 10, Color(1.6, 1.3, 0.6, 1.0 - nt))
	# Ruby's broken stick
	draw_line(Vector2(430, 430 - jump * 26.0), Vector2(452, 400 - jump * 40.0), Color(0.9, 0.85, 0.7), 3.0)
	# Lady Loom drops down from the rafters on her thread to listen in, swaying to the music
	var ld = clampf((shot_t - 1.0) / 1.2, 0.0, 1.0)
	if ld > 0.0:
		var lsw = sin(t * 1.6) * 0.08
		var lpos = Vector2(760, 90.0 + (1.0 - (1.0 - ld) * (1.0 - ld)) * 150.0 - absf(sin(_beat() * PI)) * 4.0)
		var ltop = lpos + Vector2(0, -105).rotated(lsw)
		draw_line(Vector2(760, 56), ltop, Color(0.9, 0.9, 1.0, 0.6), 1.0)
		Art.glow(self, lpos + Vector2(0, -50), 60.0, Color(1.0, 0.8, 0.5, 0.2), 3)
		Art.patron_portrait(self, "tailor", t, lpos, 0.6, true, lsw)
		Art.text(self, lpos + Vector2(0, 18), "LADY LOOM", 11, Color(1.0, 0.8, 0.5, ld), Style.font_mono, 160.0)

func _s_marquee(k: float):
	_sky(Color(0.25, 0.06, 0.14))
	_searchlight(Vector2(120, 574), -PI * 0.5 + 0.4 + sin(t * 0.9) * 0.35, 640.0, Color(1.0, 0.8, 0.6), 60.0)
	_searchlight(Vector2(1160, 574), -PI * 0.5 - 0.4 + sin(t * 0.9 + 1.5) * 0.35, 640.0, Color(0.8, 0.8, 1.0), 60.0)
	_fireworks_show(90.0, 4, 2.2)
	for i in range(22):
		var x = i * 60.0
		var h = 120.0 + fmod(float(i) * 53.0, 180.0)
		draw_rect(Rect2(x, 574 - h, 56, h), Color(0.08, 0.06, 0.12))
		for w in range(3):
			draw_rect(Rect2(x + 10 + w * 14, 574 - h + 16, 7, 9), Color(1.6, 1.3, 0.6, 0.6))
	# the marquee
	var m = Rect2(240, 120, 800, 200)
	Art.rrect(self, m, 14, Color(0.4, 0.06, 0.1))
	for i in range(40):
		var per = 2.0 * (m.size.x + m.size.y)
		var d = float(i) / 40.0 * per
		var p = Vector2.ZERO
		if d < m.size.x:
			p = m.position + Vector2(d, 0)
		elif d < m.size.x + m.size.y:
			p = m.position + Vector2(m.size.x, d - m.size.x)
		elif d < 2.0 * m.size.x + m.size.y:
			p = m.position + Vector2(m.size.x - (d - m.size.x - m.size.y), m.size.y)
		else:
			p = m.position + Vector2(0, m.size.y - (d - 2.0 * m.size.x - m.size.y))
		var on = int(t * 10.0 + i) % 2 == 0
		draw_circle(p, 5, Color(2.2, 1.8, 0.7) if on else Color(0.6, 0.45, 0.2))
	Art.text(self, Vector2(640, 172), "LUNA CITY PALLADIUM", 18, Color(1.0, 0.85, 0.55), Style.font_mono, 700.0, false)
	Art.text(self, Vector2(640, 238), "TONIGHT: OL' TIN EYES", 44, Color(2.0, 1.7, 0.7), Style.font_title, 780.0, false)
	Art.text(self, Vector2(640, 282), "starring " + star_name.to_upper() + "  -  SOLD OUT", 16, Color(1.0, 0.8, 0.6), Style.font_mono, 700.0, false)
	_note_fountain(Vector2(300, 320), 7, 240.0, Color(1.8, 1.3, 0.6), 90.0, 0.45)
	_note_fountain(Vector2(980, 320), 7, 240.0, Color(1.2, 1.3, 1.9), 90.0, 0.45)
	_crowd(572, 1.0)
	# the empires' hats, tumbling off their billboards
	var hats = [[260.0, "bowler"], [520.0, "trilby"], [780.0, "top"], [1040.0, "top_big"]]
	for i in range(hats.size()):
		var hx = float(hats[i][0])
		var fall = clampf((shot_t - 0.8 - i * 0.5) / 1.6, 0.0, 1.0)
		var hy = lerpf(380.0, 640.0, fall * fall)
		if fall > 0.0 and fall < 1.0:
			for sl in range(4):
				draw_line(Vector2(hx - 18 + sl * 12, hy - 50), Vector2(hx - 18 + sl * 12, hy - 110 - fall * 60.0), Color(1, 1, 1, 0.15), 2.0)
		draw_set_transform(Vector2(hx, hy), fall * (2.0 + i), Vector2.ONE)
		match String(hats[i][1]):
			"bowler": Art.bowler(self, Vector2.ZERO, 2.0)
			"trilby": Art.trilby(self, Vector2.ZERO, 2.2)
			"top": Art.top_hat(self, Vector2.ZERO, 1.6, Style.GOLD)
			_: Art.top_hat(self, Vector2.ZERO, 2.0)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

func _s_curtain(k: float):
	_sky(Color(0.18, 0.06, 0.2))
	var mc = Vector2(640, 250)
	_fireworks_show(100.0, 5, 2.4)
	_god_rays(mc, Color(1.2, 1.1, 0.8), 18, 600.0, 0.08)
	Art.glow(self, mc, 300, Color(1.2, 1.1, 0.8, 0.25), 6)
	draw_circle(mc, 176, Color(1.6, 1.5, 1.1, 0.5))
	draw_circle(mc, 170, Color(1.2, 1.15, 0.92))
	draw_circle(mc + Vector2(-60, -40), 28, Color(1.05, 1.0, 0.8))
	draw_circle(mc + Vector2(70, 50), 38, Color(1.05, 1.0, 0.8))
	_note_swirl(Vector2(640, 240), 240.0, 70.0, 12)
	_note_fountain(Vector2(160, 560), 8, 420.0, Color(1.8, 1.4, 0.6), 120.0, 0.3)
	_note_fountain(Vector2(1120, 560), 8, 420.0, Color(1.2, 1.3, 1.9), 120.0, 0.3)
	# curtains closing in from both sides
	var close = clampf((shot_t - 7.0) / 2.5, 0.0, 1.0)
	var a = clampf((shot_t - 0.5) / 0.8, 0.0, 1.0)
	Art.text(self, Vector2(640, 470), "FLY ME TO THE MOON", 64, Color(1.2, 0.95, 0.5, a), Style.font_title, 1240.0)
	Art.text(self, Vector2(640, 508), "Starring %s as Ol' Tin Eyes" % star_name, 20, Color(0.95, 0.9, 0.8, a), Style.font_body, 1240.0)
	var secs = int(float(win.get("time", 0.0)))
	var line = "Show #%d   -   %d rooms   -   %d KOs   -   %d:%02d on stage" % [int(win.get("n", GameData.stats.get("runs", 0))), int(win.get("depth", 0)), int(win.get("kills", 0)), int(secs / 60.0), secs % 60]
	Art.text(self, Vector2(640, 538), line, 14, Color(0.8, 0.75, 0.7, a), Style.font_mono, 1240.0)
	Art.text(self, Vector2(640, 562), "Rivet's dream, made real. And the show goes on." if replay else "Rivet's dream, made real. And the show goes on: new hats are waiting at the Hat-O-Matic.", 14, Color(1.0, 0.7, 0.6, clampf((shot_t - 2.0) / 0.8, 0.0, 1.0)), Style.font_body, 1240.0)
	var cw = 640.0 * close
	if cw > 0.0:
		draw_rect(Rect2(0, 56, cw, 518), Color(0.5, 0.04, 0.09))
		draw_rect(Rect2(1280 - cw, 56, cw, 518), Color(0.5, 0.04, 0.09))
		for i in range(8):
			var fx_ = cw - 20.0 - i * 60.0
			if fx_ > 0.0:
				draw_line(Vector2(fx_, 56), Vector2(fx_, 574), Color(0.3, 0.02, 0.05), 4.0)
				draw_line(Vector2(1280 - fx_, 56), Vector2(1280 - fx_, 574), Color(0.3, 0.02, 0.05), 4.0)
		# gold trim + tassels on the leading edges
		draw_line(Vector2(cw, 56), Vector2(cw, 574), Style.GOLD, 4.0)
		draw_line(Vector2(1280 - cw, 56), Vector2(1280 - cw, 574), Style.GOLD, 4.0)
		for side in [cw, 1280.0 - cw]:
			draw_circle(Vector2(side, 330), 9, Style.GOLD)
			draw_line(Vector2(side, 339), Vector2(side, 372), Style.GOLD, 3.0)
		draw_rect(Rect2(0, 56, 1280, 34), Color(0.45, 0.03, 0.08))
		draw_line(Vector2(0, 90), Vector2(1280, 90), Style.GOLD, 2.0)
		if close >= 1.0:
			Art.text(self, Vector2(640, 336), "THE END", 44, Color(1.6, 1.3, 0.6, clampf((shot_t - 9.5) / 0.6, 0.0, 1.0)), Style.font_title, 600.0)
