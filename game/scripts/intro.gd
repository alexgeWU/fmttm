extends Control

## PROLOGUE / TRAILER. Sixteen shots, each with its own music genre.
## ENTER / SPACE / J = next shot, ESC = skip.
## Hats are real Sprite2D nodes (Art.make_hat_node), positioned every frame.

const Art = preload("res://scripts/art.gd")
const BoonData = preload("res://scripts/boon_data.gd")
const WorldData = preload("res://scripts/world_data.gd")

signal finished

# [caption, sub-caption, seconds, music mode]
const SHOTS = [
	["EARTH.  RUST ROW.  1958.", "The part of town the brochures leave out.", 6.1, "menu"],
	["Wind-up robots. Built by the thousand.", "Built to sweep. Built to serve. Never to sing.", 6.7, "t_bebop"],
	["Up there, the Moon glitters.", "Luna City, where the legends play. Every stage belongs to the HAT EMPIRES, and robots need not apply.", 7.0, "t_exotica"],
	["One night at the Blue Note, a Rust Row jazz club...", "...a hat fell from the rafters. Somebody up there dropped it on purpose.", 6.4, "t_ballad"],
	["It landed on a stagehand named Rivet Fontaine.", "Under that brim he wasn't a stagehand anymore. He was OL' TIN EYES.", 6.7, "t_ballad"],
	["Now, every night after closing, the robots take the stage.", "The Back Room: Slim on bass, Ruby Rimshot on drums, Doc on keys, and Rivet out front in THE hat.", 8.6, "hub"],
	["RIVET'S DREAM:  HEADLINE THE MOON.", "Not a back room. Luna City's biggest stage, for one night. Four hat empires stand in the way.", 8.6, "t_exotica"],
	["STOP 1:  THE SMOKY BAR", "The Bowler Brotherhood keeps robots off the stage.", 6.1, "bar"],
	["STOP 2:  THE NEON ALLEY", "The Trilby Syndicate owns the only road to the rockets.", 6.1, "alley"],
	["STOP 3:  THE GRAND CASINO", "Top Hat Records runs the house. The house always wins.", 6.1, "casino"],
	["STOP 4:  THE MOON", "The Chairman of the Lunar Hat Empire. No robot has ever played his stage.", 6.7, "moon"],
	["His weapon? THE HAT IS THE ACT.", "Every hat is a new moveset: crowns, bands and add-ons. Thousands of combinations, Common to Chroma.", 8.0, "gacha"],
	["Some made it big without an empire hat.", "The HEADLINERS: a dark-side moth, a boiler-room salamander, a stray cat, a Saturn eel and a piano-moving rhino.", 9.0, "t_bossa"],
	["And they LOVE an underdog.", "Win their favor mid-show. Their boons STACK: Chill, Burn, Crits, Zaps and Shockwaves.", 7.0, "t_shout"],
	["If Rivet takes a bow, the show goes on.", "Most T-1Ns just sweep, but this crew all learned the act. The next one steps into the hat and becomes Ol' Tin Eyes.", 7.7, "t_ballad"],
	["", "", 8.0, "victory"],
]

const SHOWCASE = [
	{"material": "cardboard", "brim_material": "cardboard", "band": "cotton", "addon": "paperclip", "material_rarity": 0, "brim_rarity": 0, "band_rarity": 0, "addon_rarity": 0, "highest_rarity": 0, "is_chroma": false, "total_stats": 10.0, "name": "Two-Bit Hustler"},
	{"material": "felt", "brim_material": "cardboard", "band": "silk", "addon": "paperclip", "material_rarity": 1, "brim_rarity": 0, "band_rarity": 1, "addon_rarity": 0, "highest_rarity": 1, "is_chroma": false, "total_stats": 20.0, "name": "Backroom Serenade"},
	{"material": "velvet", "brim_material": "leather", "band": "chrono", "addon": "feather", "material_rarity": 2, "brim_rarity": 1, "band_rarity": 2, "addon_rarity": 0, "highest_rarity": 2, "is_chroma": false, "total_stats": 46.0, "name": "The Clockwork Headliner"},
	{"material": "titanium", "brim_material": "copper", "band": "dynamo", "addon": "golden_coin", "material_rarity": 2, "brim_rarity": 1, "band_rarity": 2, "addon_rarity": 2, "highest_rarity": 2, "is_chroma": false, "total_stats": 46.0, "name": "Iron Thunder of the Moon"},
	{"material": "patent_leather", "brim_material": "patent_leather", "band": "neon_magenta", "addon": "bullet_casing", "material_rarity": 2, "brim_rarity": 2, "band_rarity": 2, "addon_rarity": 2, "highest_rarity": 2, "is_chroma": true, "total_stats": 110.0, "name": "Prismatic After-Hours Neon"},
]

const DREAM_HERO = Vector2(250, 548)
const DREAM_MOON = Vector2(960, 230)

var idx: int = 0
var t: float = 0.0
var shot_t: float = 0.0
var stars: Array = []
var done: bool = false
var hero_hat: Dictionary = {}
var hats: Dictionary = {}

func _ready():
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	focus_mode = Control.FOCUS_ALL
	grab_focus()
	hero_hat = GameData.get_equipped_hat()
	for i in range(140):
		stars.append({"p": Vector2(randf() * 1280, randf() * 420), "s": randf_range(0.6, 1.8), "ph": randf() * TAU})
	_make_hat("hero", hero_hat)
	for i in range(SHOWCASE.size()):
		_make_hat("show%d" % i, SHOWCASE[i])
	_make_hat("line", hero_hat)
	_start_shot()

func _make_hat(key: String, h: Dictionary):
	var n = Art.make_hat_node(h, 0.5)
	n.visible = false
	n.set_meta("chroma", h.get("is_chroma", false))
	add_child(n)
	hats[key] = n

func _start_shot():
	shot_t = 0.0
	if idx < SHOTS.size():
		Sfx.set_music(String(SHOTS[idx][3]))
		Sfx.play("whoosh_up", 1.3, -8.0)

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
	if idx >= SHOTS.size():
		_finish()
		return
	_start_shot()

func _finish():
	if done:
		return
	done = true
	GameData.tut["intro"] = true
	GameData.save_game()
	finished.emit()

func _process(delta):
	t += delta
	shot_t += delta
	if not done and idx < SHOTS.size() and shot_t > float(SHOTS[idx][2]):
		_next()
	_place_hats()
	queue_redraw()

# ---------------------------------------------------------------------------
# HAT PLACEMENT (real sprites)
# ---------------------------------------------------------------------------
func _shot_alpha() -> float:
	if idx >= SHOTS.size():
		return 0.0
	var dur = float(SHOTS[idx][2])
	var fade = maxf(1.0 - shot_t / 0.25, (shot_t - dur + 0.25) / 0.25)
	return 1.0 - clampf(fade, 0.0, 1.0)

func _hat(key: String, pos: Vector2, sc: float, rot: float = 0.0):
	var n: Node2D = hats[key]
	n.visible = true
	n.position = pos
	n.scale = Vector2(sc, sc)
	n.rotation = rot
	var a = _shot_alpha()
	if n.get_meta("chroma", false):
		var c = Art.chroma_color(t)
		n.modulate = Color(c.r * 1.3, c.g * 1.3, c.b * 1.3, a)
	else:
		n.modulate = Color(1, 1, 1, a)

func _head(p: Vector2, sc: float, moving: bool) -> Vector2:
	return p + Vector2(0, (Art.HEAD_TOP + Art.robot_bob(t, moving)) * sc)

func _place_hats():
	for k in hats.keys():
		(hats[k] as Node2D).visible = false
	if done or idx >= SHOTS.size():
		return
	match idx:
		3:
			var fall = clampf(shot_t / 1.6, 0.0, 1.0)
			var head = _head(Vector2(640, 470), 2.2, false)
			var y = lerpf(20.0, head.y, fall * fall)
			var wob = sin(t * 8.0) * 40.0 * (1.0 - fall)
			_hat("hero", Vector2(640 + wob, y), 2.2, sin(t * 6.0) * 0.4 * (1.0 - fall))
		4:
			_hat("hero", _head(Vector2(640, 470), 2.2, false), 2.2, sin(t * 2.5) * 0.15)
		5:
			_hat("hero", _head(Vector2(640, 540), 1.5, false), 1.5, sin(t * 2.5) * 0.12)
		6:
			_hat("hero", _head(DREAM_HERO, 1.6, false), 1.6, 0.0)
		13:
			_hat("hero", _head(Vector2(640, 520), 1.4, false), 1.4, 0.0)
		11:
			for i in range(SHOWCASE.size()):
				var a = t * 0.5 + TAU * float(i) / float(SHOWCASE.size())
				var hp = Vector2(640 + cos(a) * 380.0, 330 + sin(a) * 70.0)
				var sc = 1.5 + 0.5 * (sin(a) * 0.5 + 0.5)
				_hat("show%d" % i, hp, sc, sin(t * 2.0 + i) * 0.1)
		14:
			# the hat hops down the line of robots
			var hop = fmod(shot_t * 0.9, 4.0)
			var i2 = int(hop)
			var k2 = hop - float(i2)
			var a0 = _head(Vector2(300 + i2 * 180.0, 480), 1.6, false)
			var a1 = _head(Vector2(300 + (i2 + 1) * 180.0, 480), 1.6, false)
			var hp2 = a0.lerp(a1, k2) + Vector2(0, -sin(k2 * PI) * 90.0)
			_hat("line", hp2, 1.6, sin(k2 * PI) * 0.8)
		15:
			_hat("hero", Vector2(640, 260 + sin(t * 1.4) * 8.0), 2.6, sin(t * 0.9) * 0.1)

# ---------------------------------------------------------------------------
# DRAW
# ---------------------------------------------------------------------------
func _draw():
	draw_rect(Rect2(0, 0, 1280, 720), Color(0.02, 0.015, 0.04))
	if idx >= SHOTS.size():
		return
	var k = clampf(shot_t / 0.6, 0.0, 1.0)
	match idx:
		0: _s_rust_row(k)
		1: _s_army(k)
		2: _s_moon_empires(k)
		3:
			_s_stage(1.0)
			_s_loom_peek()
		4: _s_stage(1.0)
		5: _s_backroom(k)
		6: _s_dream(k)
		7: _s_boss_card("big_sal", 0, k)
		8: _s_boss_card("getaway_car", 1, k)
		9: _s_boss_card("big_band", 2, k)
		10: _s_boss_card("moon_man", 3, k)
		11: _s_hats(k)
		12: _s_headliners(k)
		13: _s_underdog(k)
		14: _s_line(k)
		15: _s_title(k)
	# letterbox + captions
	draw_rect(Rect2(0, 0, 1280, 56), Color(0, 0, 0))
	draw_rect(Rect2(0, 574, 1280, 146), Color(0, 0, 0))
	var sh = SHOTS[idx]
	if String(sh[0]) != "":
		Art.text(self, Vector2(640, 622), String(sh[0]), 30, Color(1.0, 0.9, 0.7, k), Style.font_title, 1240.0)
	if String(sh[1]) != "":
		var k2 = clampf((shot_t - 0.45) / 0.6, 0.0, 1.0)
		Art.text(self, Vector2(640, 660), String(sh[1]), 18, Color(0.85, 0.8, 0.72, k2), Style.font_body, 1240.0)
	for j in range(SHOTS.size()):
		draw_circle(Vector2(640 - (SHOTS.size() - 1) * 8 + j * 16, 698), 3.5, Style.GOLD if j <= idx else Color(0.3, 0.3, 0.3))
	Art.text(self, Vector2(1160, 704), "ENTER next   ESC skip", 11, Style.MUTED, Style.font_mono, 300.0)
	# trailer cut: quick fade in/out at each shot edge
	var dur = float(sh[2])
	var fade = maxf(1.0 - shot_t / 0.25, (shot_t - dur + 0.25) / 0.25)
	if fade > 0.0:
		draw_rect(Rect2(0, 0, 1280, 720), Color(0, 0, 0, clampf(fade, 0.0, 1.0)))

func _robot(p: Vector2, sc: float, moving: bool, facing: Vector2 = Vector2.DOWN, skin_i: int = 0, number: String = ""):
	var sk = GameData.SKINS[skin_i % GameData.SKINS.size()]
	draw_set_transform(p, 0.0, Vector2(sc, sc))
	Art.draw_robot(self, t + float(skin_i), facing, moving, 0.0, sk["body"], sk, number)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

func _sky(tint: Color):
	for i in range(18):
		var kk = float(i) / 18.0
		draw_rect(Rect2(0, i * 32, 1280, 33), Color(0.02, 0.02, 0.06).lerp(tint, kk))
	for s in stars:
		var a = 0.4 + 0.5 * sin(t * 2.0 + float(s["ph"]))
		draw_circle(s["p"], float(s["s"]), Color(1, 1, 1, a * 0.7))

func _s_rust_row(k: float):
	_sky(Color(0.25, 0.12, 0.08))
	# the Moon, far away
	draw_circle(Vector2(1060, 120), 44, Color(1.1, 1.05, 0.85))
	Art.glow(self, Vector2(1060, 120), 90, Color(1.1, 1.0, 0.7, 0.25), 3)
	# smokestacks + factories
	for i in range(7):
		var x = 60.0 + i * 180.0
		draw_rect(Rect2(x, 300, 26, 280), Color(0.12, 0.08, 0.07))
		for j in range(4):
			var st = fmod(t * 0.2 + j * 0.25 + i * 0.1, 1.0)
			draw_circle(Vector2(x + 13 + st * 60.0, 290 - st * 200.0), 18 + st * 30.0, Color(0.35, 0.3, 0.3, 0.25 * (1.0 - st)))
		draw_rect(Rect2(x - 40, 420, 150, 160), Color(0.1, 0.07, 0.07))
		for w in range(4):
			draw_rect(Rect2(x - 26 + w * 34, 450, 18, 12), Color(1.0, 0.55, 0.2, 0.7 if (i + w) % 2 == 0 else 0.25))
	# conveyor of robots
	draw_rect(Rect2(0, 548, 1280, 26), Color(0.2, 0.18, 0.18))
	for i in range(9):
		var x2 = fmod(t * 60.0 + i * 160.0, 1440.0) - 80.0
		_robot(Vector2(x2, 548), 0.9, false, Vector2.DOWN, 1)
	# rain
	for i in range(60):
		var rx = fmod(i * 97.0 + t * 300.0, 1280.0)
		var ry = fmod(i * 53.0 + t * 700.0, 520.0) + 56.0
		draw_line(Vector2(rx, ry), Vector2(rx - 4, ry + 16), Color(0.6, 0.7, 1.0, 0.25), 1.0)

func _s_army(k: float):
	_sky(Color(0.12, 0.08, 0.14))
	for row in range(4):
		var y = 250.0 + row * 90.0
		var sc = 0.6 + row * 0.25
		var n = 12 - row * 2
		for i in range(n):
			var x = 640.0 + (float(i) - float(n - 1) * 0.5) * (1100.0 / float(n))
			var march = sin(t * 6.0 + i + row) * 3.0
			_robot(Vector2(x, y + march), sc, true, Vector2.DOWN, row)
	Art.text(self, Vector2(640, 120), "MODEL T-1N  -  WIND-UP SERVICE ROBOT", 20, Color(1.0, 0.7, 0.4, k), Style.font_mono, 800.0)

func _s_moon_empires(k: float):
	_sky(Color(0.1, 0.1, 0.25))
	var mc = Vector2(640, 330)
	Art.glow(self, mc, 330, Color(1.2, 1.1, 0.8, 0.22), 5)
	draw_circle(mc, 230, Color(1.2, 1.15, 0.92))
	draw_circle(mc + Vector2(-80, -60), 40, Color(1.05, 1.0, 0.8))
	draw_circle(mc + Vector2(90, 70), 55, Color(1.05, 1.0, 0.8))
	# Luna City skyline on the horizon
	for i in range(22):
		var x = 380.0 + i * 24.0
		var h = 40.0 + fmod(float(i) * 37.0, 70.0)
		draw_rect(Rect2(x, 560 - h, 20, h), Color(0.15, 0.12, 0.2))
		draw_rect(Rect2(x + 6, 560 - h + 8, 6, 6), Color(2.0, 1.6, 0.6))
	# the four hat empires rising over it
	var rise = clampf(shot_t / 1.5, 0.0, 1.0)
	var y0 = 560.0 - 60.0 * rise
	Art.bowler(self, Vector2(300, y0), 3.0)
	Art.trilby(self, Vector2(480, y0 - 20), 3.2)
	Art.top_hat(self, Vector2(800, y0 - 10), 2.4, Style.GOLD)
	Art.top_hat(self, Vector2(1010, y0 + 10), 3.2)
	var labels = [[300, "BOWLER BROTHERHOOD"], [480, "TRILBY SYNDICATE"], [800, "TOP HAT RECORDS"], [1010, "LUNAR HAT EMPIRE"]]
	for l in labels:
		Art.text(self, Vector2(float(l[0]), 110), String(l[1]), 14, Color(1.0, 0.85, 0.5, rise), Style.font_mono, 240.0)

func _s_stage(spot: float):
	draw_rect(Rect2(0, 440, 1280, 140), Color(0.22, 0.12, 0.07))
	draw_line(Vector2(0, 440), Vector2(1280, 440), Style.GOLD_DIM, 3.0)
	draw_rect(Rect2(140, 56, 100, 384), Color(0.45, 0.04, 0.08))
	draw_rect(Rect2(1040, 56, 100, 384), Color(0.45, 0.04, 0.08))
	draw_colored_polygon(PackedVector2Array([Vector2(610, 56), Vector2(670, 56), Vector2(760, 470), Vector2(520, 470)]), Color(1.2, 1.1, 0.8, 0.12 * spot))
	Art.ellipse(self, Vector2(640, 470), 130, 24, Color(1.2, 1.1, 0.8, 0.18 * spot))
	_robot(Vector2(640, 470), 2.2, false, Vector2.DOWN, 0)
	if shot_t > 1.6:
		Art.glow(self, _head(Vector2(640, 470), 2.2, false) + Vector2(0, -30), 120, Color(1.6, 1.3, 0.6, 0.3), 5)

## Lady Loom, peeking down from the rafters after letting the hat go
func _s_loom_peek():
	var drop = clampf((shot_t - 1.8) / 1.0, 0.0, 1.0)
	var lp = Vector2(900, 60 + drop * 110.0)
	draw_line(Vector2(900, 56), lp + Vector2(0, -65), Color(0.9, 0.9, 1.0, 0.5), 1.0)
	if drop > 0.0:
		Art.patron_portrait(self, "tailor", t, lp + Vector2(0, 40), 0.6)
		Art.text(self, lp + Vector2(0, 62), "LADY LOOM", 11, Color(1.0, 0.8, 0.5, drop), Style.font_mono, 160.0)

func _s_backroom(k: float):
	# the Blue Note after hours: chairs up on tables, the robot band on stage
	draw_rect(Rect2(0, 56, 1280, 518), Color(0.2, 0.05, 0.07))
	for i in range(33):
		for j in range(5):
			var dp = Vector2(i * 40 + (20 if j % 2 == 0 else 0), 80 + j * 34)
			Art.poly(self, [dp + Vector2(0, -7), dp + Vector2(5, 0), dp + Vector2(0, 7), dp + Vector2(-5, 0)], Color(0.9, 0.65, 0.3, 0.1))
	draw_rect(Rect2(0, 420, 1280, 154), Color(0.24, 0.13, 0.08))
	Art.rrect(self, Rect2(300, 230, 680, 200), 10, Color(0.18, 0.08, 0.05))
	draw_line(Vector2(300, 430), Vector2(980, 430), Style.GOLD, 3.0)
	Art.text(self, Vector2(640, 110), "THE BLUE NOTE", 30, Color(0.5, 0.9, 2.2), Style.font_title, 600.0, false)
	var flick = 1.0 if fmod(t, 4.3) > 0.15 else 0.3
	Art.text(self, Vector2(640, 142), "AFTER HOURS", 18, Color(2.0 * flick, 0.5 * flick, 1.2 * flick), Style.font_mono, 400.0, false)
	# a "CLOSED" sign on the door and chairs up on the tables
	Art.rrect(self, Rect2(60, 250, 110, 170), 4, Color(0.4, 0.1, 0.1))
	Art.rrect(self, Rect2(80, 300, 70, 26), 3, Color(0.95, 0.9, 0.8))
	Art.text(self, Vector2(115, 319), "CLOSED", 13, Color(0.7, 0.1, 0.1), Style.font_mono, 80.0, false)
	for tx in [1080.0, 1190.0]:
		Art.ellipse(self, Vector2(tx, 500), 40, 12, Color(0.9, 0.88, 0.82))
		draw_line(Vector2(tx, 500), Vector2(tx, 560), Color(0.2, 0.1, 0.05), 4.0)
		draw_line(Vector2(tx - 20, 494), Vector2(tx - 26, 460), Color(0.3, 0.15, 0.08), 3.0)
		draw_line(Vector2(tx + 20, 494), Vector2(tx + 26, 460), Color(0.3, 0.15, 0.08), 3.0)
		draw_line(Vector2(tx - 26, 460), Vector2(tx + 26, 460), Color(0.3, 0.15, 0.08), 3.0)
	# the band, hatless, each with a name plate that pops in
	var band = [["SLIM", "bass", 440.0, 4], ["RUBY RIMSHOT", "drums", 640.0, 6], ["DOC", "piano", 840.0, 7]]
	var beat = absf(sin(t * PI * 108.0 / 60.0))
	for i in range(3):
		var bm = band[i]
		var bx = float(bm[2])
		var bp = Vector2(bx, 400 - beat * 4.0)
		var lit = clampf((shot_t - 0.5 - i * 0.5) / 0.4, 0.0, 1.0)
		draw_colored_polygon(PackedVector2Array([Vector2(bx - 10, 56), Vector2(bx + 10, 56), Vector2(bx + 70, 430), Vector2(bx - 70, 430)]), Color(1.2, 1.1, 0.8, 0.1 * lit))
		if bm[1] == "piano":
			Art.rrect(self, Rect2(bx - 44, 350, 88, 36), 4, Color(0.05, 0.05, 0.06))
			draw_rect(Rect2(bx - 40, 380, 80, 7), Color(0.95, 0.95, 0.9))
		_robot(bp, 1.3, false, Vector2(0.2, 1.0).normalized(), int(bm[3]))
		match String(bm[1]):
			"bass":
				Art.ellipse(self, Vector2(bx + 24, 376), 16, 24, Color(0.55, 0.28, 0.1))
				draw_line(Vector2(bx + 24, 290), Vector2(bx + 24, 398), Color(0.2, 0.1, 0.05), 3.0)
			"drums":
				Art.ellipse(self, Vector2(bx, 404), 28, 13, Color(0.85, 0.85, 0.9))
				Art.ellipse(self, Vector2(bx, 404), 20, 8, Color(0.7, 0.1, 0.15))
				Art.ellipse(self, Vector2(bx - 36, 372), 13, 4, Color(1.4, 1.1, 0.4))
		Art.text(self, Vector2(bx, 268), String(bm[0]), 15, Color(1.0, 0.85, 0.55, lit), Style.font_mono, 220.0)
		Art.text(self, Vector2(bx, 286), String(bm[1]).to_upper(), 11, Color(0.8, 0.75, 0.65, lit * 0.8), Style.font_mono, 220.0)
	# tonight's Ol' Tin Eyes, front and centre (the only one with a hat)
	_robot(Vector2(640, 540), 1.5, false, Vector2.DOWN, 0)
	for i in range(5):
		var nt = fmod(t * 0.5 + i * 0.2, 1.0)
		Art.note_glyph(self, Vector2(360 + i * 140.0, 330 - nt * 220.0), 12, Color(1.6, 1.3, 0.6, 1.0 - nt))

## RIVET'S DREAM: the first Ol' Tin Eyes and the Back Room crew on the Blue Note's roof, looking up. The route to the Moon
## draws itself stop by stop, ending at Luna City's biggest stage.
func _s_dream(k: float):
	_sky(Color(0.14, 0.08, 0.22))
	# the Moon, with Luna City's marquee lit up on it
	var mc = DREAM_MOON
	Art.glow(self, mc, 260, Color(1.2, 1.1, 0.8, 0.22), 6)
	draw_circle(mc, 150, Color(1.2, 1.15, 0.92))
	draw_circle(mc + Vector2(-55, -45), 26, Color(1.05, 1.0, 0.8))
	draw_circle(mc + Vector2(60, 50), 34, Color(1.05, 1.0, 0.8))
	for si in range(3):
		var sa = -PI * 0.5 + sin(t * 0.8 + si * 2.1) * 0.6
		var sd = Vector2(cos(sa), sin(sa))
		draw_colored_polygon(PackedVector2Array([mc + Vector2(0, -40) - sd.orthogonal() * 4.0, mc + Vector2(0, -40) + sd.orthogonal() * 4.0, mc + Vector2(0, -40) + sd * 420.0 + sd.orthogonal() * 50.0, mc + Vector2(0, -40) + sd * 420.0 - sd.orthogonal() * 50.0]), Color(1.3, 1.2, 0.9, 0.06))
	var mq = Rect2(mc.x - 90, mc.y - 60, 180, 50)
	Art.rrect(self, mq, 8, Color(0.4, 0.06, 0.1))
	for bi in range(18):
		var on = int(t * 8.0 + bi) % 2 == 0
		draw_circle(Vector2(mq.position.x + 8 + bi * 9.6, mq.position.y + 5), 2.5, Color(2.2, 1.8, 0.7) if on else Color(0.6, 0.45, 0.2))
	Art.text(self, Vector2(mc.x, mc.y - 36), "LUNA CITY", 18, Color(2.0, 1.7, 0.7), Style.font_title, 180.0, false)
	Art.text(self, Vector2(mc.x, mc.y - 19), "NOW BOOKING: ???", 10, Color(1.0, 0.8, 0.6), Style.font_mono, 180.0, false)
	# Rust Row rooftops
	for i in range(18):
		var x = i * 74.0
		var h = 60.0 + fmod(float(i) * 41.0, 90.0)
		draw_rect(Rect2(x, 574 - h - 30, 70, h + 4), Color(0.07, 0.05, 0.08))
		if i % 3 == 0:
			draw_rect(Rect2(x + 20, 574 - h - 30 - 30, 12, 30), Color(0.07, 0.05, 0.08))
	draw_rect(Rect2(0, 548, 1280, 26), Color(0.12, 0.08, 0.08))
	Art.text(self, Vector2(250, 568), "THE BLUE NOTE  -  ROOF", 11, Color(0.5, 0.9, 2.2, 0.8), Style.font_mono, 300.0, false)
	Art.text(self, Vector2(222, 356), "RIVET FONTAINE", 13, Color(1.0, 0.85, 0.55, k), Style.font_mono, 200.0)
	Art.text(self, Vector2(222, 372), "Ol' Tin Eyes", 11, Color(0.85, 0.8, 0.72, k), Style.font_mono, 200.0)
	# the route: Earth to the Moon, one hat empire at a time
	var p0 = DREAM_HERO + Vector2(40, -120)
	var p2 = mc + Vector2(-60, 70)
	var p1 = Vector2(520, 110)
	var reveal = clampf((shot_t - 0.9) / 3.2, 0.0, 1.0)
	var steps = 60
	for si2 in range(steps):
		var u = float(si2) / float(steps)
		if u > reveal:
			break
		if si2 % 2 == 0:
			var q0 = p0.lerp(p1, u).lerp(p1.lerp(p2, u), u)
			var u2 = float(si2 + 1) / float(steps)
			var q1 = p0.lerp(p1, u2).lerp(p1.lerp(p2, u2), u2)
			draw_line(q0, q1, Color(1.8, 1.5, 0.7, 0.8), 3.0)
	var stop_u = [0.18, 0.44, 0.7, 1.0]
	for bi2 in range(4):
		var su = float(stop_u[bi2])
		if reveal < su:
			continue
		var pop = clampf(((shot_t - 0.9) / 3.2 - su) / 0.08, 0.0, 1.0)
		if pop <= 0.0:
			continue
		var sp = p0.lerp(p1, su).lerp(p1.lerp(p2, su), su)
		var bio = WorldData.BIOMES[bi2]
		var ac: Color = bio["accent"]
		Art.glow(self, sp, 26.0 * pop, Color(ac.r * 1.5, ac.g * 1.5, ac.b * 1.5, 0.5), 3)
		draw_circle(sp, 9.0 * pop, Color(ac.r * 1.6, ac.g * 1.6, ac.b * 1.6))
		draw_circle(sp, 4.0 * pop, Color(0.05, 0.03, 0.06))
		var lab = "%d  %s" % [bi2 + 1, String(bio["name"]).to_upper()]
		if bi2 == 3:
			# on the Moon itself: dark plate so it reads against the bright disc
			Art.rrect(self, Rect2(sp.x - 62, sp.y + 12, 124, 22), 6, Color(0.05, 0.04, 0.12, 0.85 * pop))
			Art.text(self, sp + Vector2(0, 28), lab, 13, Color(ac.r * 1.4, ac.g * 1.4, ac.b * 1.4, pop), Style.font_mono, 260.0)
		elif bi2 == 0:
			Art.text(self, sp + Vector2(78, 14), lab, 13, Color(ac.r * 1.4, ac.g * 1.4, ac.b * 1.4, pop), Style.font_mono, 260.0)
		else:
			Art.text(self, sp + Vector2(0, -18), lab, 13, Color(ac.r * 1.4, ac.g * 1.4, ac.b * 1.4, pop), Style.font_mono, 260.0)
	# a little rocket making the trip
	if reveal > 0.02:
		var ru = minf(reveal, clampf((shot_t - 1.2) / 5.0, 0.0, 1.0))   # one trip, then it's landed
		var rp = p0.lerp(p1, ru).lerp(p1.lerp(p2, ru), ru)
		var ru2 = minf(1.0, ru + 0.01)
		var rdir = (p0.lerp(p1, ru2).lerp(p1.lerp(p2, ru2), ru2) - rp).normalized()
		draw_set_transform(rp, rdir.angle() + PI * 0.5, Vector2.ONE)
		Art.poly(self, [Vector2(0, -12), Vector2(6, 4), Vector2(-6, 4)], Color(0.9, 0.9, 0.95))
		draw_circle(Vector2(0, -3), 2.5, Color(0.5, 0.9, 2.0))
		Art.poly(self, [Vector2(-4, 4), Vector2(4, 4), Vector2(0, 12 + sin(t * 40.0) * 3.0)], Color(2.2, 1.2, 0.3))
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	# the crew from behind, looking up. Tin Eyes points the way.
	var crew = [[DREAM_HERO + Vector2(110, 6), 4], [DREAM_HERO + Vector2(180, 2), 6], [DREAM_HERO + Vector2(250, 8), 7]]
	for c in crew:
		var cp: Vector2 = c[0]
		var csk = GameData.SKINS[int(c[1]) % GameData.SKINS.size()]
		draw_set_transform(cp, 0.0, Vector2(1.3, 1.3))
		Art.draw_robot(self, t, Vector2(0.4, -0.9).normalized(), false, 0.0, csk["body"], csk)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	var hsk = GameData.SKINS[0]
	draw_set_transform(DREAM_HERO, 0.0, Vector2(1.6, 1.6))
	Art.draw_robot(self, t, Vector2(0.4, -0.9).normalized(), false, 0.0, hsk["body"], hsk, "", {"hand_r": Vector2(18.0, -12.0)})
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

func _s_underdog(k: float):
	# the Headliners gather around the robot and lend their colours
	_sky(Color(0.16, 0.06, 0.14))
	_robot(Vector2(640, 520), 1.4, false, Vector2.DOWN, 0)
	var pids = BoonData.PATRONS.keys()
	for i in range(pids.size()):
		var pid = String(pids[i])
		var pc: Color = BoonData.PATRONS[pid]["color"]
		var a = PI + PI * (float(i) + 0.5) / float(pids.size())
		var pp = Vector2(640, 520) + Vector2(cos(a) * 470.0, sin(a) * 300.0)
		var src = pp + Vector2(0, -70)
		var dst = Vector2(640, 470)
		for j in range(6):
			var f = fmod(t * 0.8 + float(j) / 6.0 + i * 0.13, 1.0)
			draw_circle(src.lerp(dst, f), 4.0 * (1.0 - f) + 1.5, Color(pc.r * 1.6, pc.g * 1.6, pc.b * 1.6, 0.9 * (1.0 - f * 0.5)))
		Art.patron_portrait(self, pid, t, pp, 0.75)
		Art.text(self, pp + Vector2(0, 16), String(BoonData.PATRONS[pid]["status"]).to_upper(), 13, Color(pc.r * 1.4, pc.g * 1.4, pc.b * 1.4), Style.font_mono, 160.0)

func _s_boss_card(kind: String, bi: int, k: float):
	var b = WorldData.BIOMES[bi]
	var boss = WorldData.BOSSES[kind]
	var ac: Color = b["accent"]
	draw_rect(Rect2(0, 56, 1280, 518), (b["floor_a"] as Color).darkened(0.3))
	for i in range(12):
		var a = t * 0.3 + TAU * float(i) / 12.0
		draw_line(Vector2(900, 330), Vector2(900, 330) + Vector2(cos(a), sin(a)) * 700.0, Color(ac.r, ac.g, ac.b, 0.06), 30.0)
	var slide = 1.0 - pow(1.0 - clampf(shot_t / 0.7, 0.0, 1.0), 3.0)
	Art.boss_portrait(self, kind, t, Vector2(lerpf(1400.0, 900.0, slide), 520), 1.9)
	Art.text_left(self, Vector2(80, 180), String(boss["empire"]).to_upper(), 20, Color(ac.r, ac.g, ac.b, k), Style.font_mono)
	Art.text_left(self, Vector2(76, 260), String(boss["name"]), 64, Color(1.0, 0.92, 0.75, slide), Style.font_title)
	var q = clampf((shot_t - 0.9) / 0.5, 0.0, 1.0)
	Art.text_left(self, Vector2(80, 320), String(boss["quote"]), 22, Color(1.0, 0.8, 0.6, q), Style.font_body)
	# a couple of their goons
	var pool: Array = b["pool"]
	for i in range(mini(3, pool.size())):
		var ek = String(pool[i][0])
		draw_set_transform(Vector2(120 + i * 130.0, 520), 0.0, Vector2(1.4, 1.4))
		Art.draw_enemy(self, ek, t + i, Vector2(0.6, 0.6).normalized(), "move", 3.0)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

func _s_hats(k: float):
	_sky(Color(0.25, 0.05, 0.12))
	for i in range(SHOWCASE.size()):
		var h = SHOWCASE[i]
		var a = t * 0.5 + TAU * float(i) / float(SHOWCASE.size())
		var hp = Vector2(640 + cos(a) * 380.0, 330 + sin(a) * 70.0)
		var col = GameData.hat_grade_color(h)
		if h["is_chroma"]:
			col = Art.chroma_color(t)
		Art.ellipse(self, hp + Vector2(0, 30), 60, 12, Color(col.r, col.g, col.b, 0.25))
		Art.grade_badge(self, hp + Vector2(-70, 20), GameData.hat_grade(h), col, 16.0)
		Art.text(self, hp + Vector2(0, 62), String(h["name"]), 14, col, Style.font_title, 300.0)
		Art.text(self, hp + Vector2(0, 80), GameData.hat_grade_label(h), 11, col, Style.font_mono, 260.0)
		if sin(a) > 0.3:
			var bk = BoonData.BAND_KITS[h["band"]]
			var ak = BoonData.ADDON_KITS[h["addon"]]
			Art.text(self, hp + Vector2(0, 98), "%s  /  %s" % [bk["name"], ak["name"]], 12, Style.CREAM, Style.font_mono, 300.0)

func _s_headliners(k: float):
	_sky(Color(0.15, 0.08, 0.1))
	var i = 0
	for pid in BoonData.PATRONS.keys():
		var pd = BoonData.PATRONS[pid]
		var pc: Color = pd["color"]
		var lit = clampf((shot_t - 0.3 - i * 0.6) / 0.35, 0.0, 1.0)
		var p = Vector2(160 + i * 240.0, 430)
		draw_colored_polygon(PackedVector2Array([p + Vector2(-10, -374), p + Vector2(10, -374), p + Vector2(100, 40), p + Vector2(-100, 40)]), Color(pc.r, pc.g, pc.b, 0.12 * lit))
		if lit > 0.0:
			Art.glow(self, p + Vector2(0, -70), 80, Color(pc.r, pc.g, pc.b, 0.3 * lit), 4)
			Art.patron_portrait(self, String(pid), t, p + Vector2(0, (1.0 - lit) * 30.0), 1.05)
		Art.text(self, p + Vector2(0, 32), String(pd["name"]), 17, Color(pc.r, pc.g, pc.b, lit), Style.font_title, 230.0)
		Art.text(self, p + Vector2(0, 52), "FROM: " + String(pd["from"]), 11, Color(1, 1, 1, 0.75 * lit), Style.font_mono, 230.0)
		Art.text(self, p + Vector2(0, -170), String(pd["status"]).to_upper(), 13, Color(pc.r * 1.4, pc.g * 1.4, pc.b * 1.4, lit), Style.font_mono, 230.0)
		i += 1

func _s_line(k: float):
	_s_stage(0.6)
	Art.text(self, Vector2(640, 110), "THE BACK ROOM CREW", 20, Color(1.0, 0.8, 0.5, k), Style.font_mono, 800.0)
	for i in range(5):
		var p = Vector2(300 + i * 180.0, 480)
		_robot(p, 1.6, false, Vector2(0.4, 1.0).normalized(), i)
		Art.text(self, p + Vector2(0, 34), GameData.performer_at(i), 13, Style.MUTED, Style.font_mono, 170.0)
		if i == 0:
			Art.text(self, p + Vector2(0, 52), "(took a bow)", 11, Color(1.0, 0.5, 0.45), Style.font_mono, 170.0)

func _s_title(k: float):
	_sky(Color(0.18, 0.06, 0.2))
	var mc = Vector2(640, 250)
	Art.glow(self, mc, 300, Color(1.2, 1.1, 0.8, 0.25), 6)
	draw_circle(mc, 170, Color(1.2, 1.15, 0.92))
	draw_circle(mc + Vector2(-60, -40), 28, Color(1.05, 1.0, 0.8))
	draw_circle(mc + Vector2(70, 50), 38, Color(1.05, 1.0, 0.8))
	var a = clampf((shot_t - 0.6) / 0.8, 0.0, 1.0)
	Art.text(self, Vector2(640, 500), "FLY ME TO THE MOON", 72, Color(1.2, 0.95, 0.5, a), Style.font_title, 1240.0)
	Art.text(self, Vector2(640, 548), "Starring Ol' Tin Eyes", 18, Color(0.95, 0.9, 0.8, a), Style.font_body, 1240.0)
