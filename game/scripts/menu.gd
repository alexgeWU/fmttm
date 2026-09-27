extends Control

## Main Menu: night skyline, a big glowing moon, and your hat floating toward it.

const Art = preload("res://scripts/art.gd")

signal start_game
signal play_intro
signal play_ending

var t: float = 0.0
var stars: Array = []
var buildings: Array = []
var main_box: VBoxContainer
var how_panel: Control
var hat_ctrl: Control

var click_overlay: Button

func _ready():
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	theme = Style.theme
	if OS.get_name() == "Web" and not Sfx.audio_started:
		_build_click_overlay()
	else:
		Sfx.set_music("menu")
	for i in range(170):
		stars.append({"p": Vector2(randf() * 1280, randf() * 470), "s": randf_range(0.6, 2.0), "ph": randf() * TAU})
	var x = -20.0
	while x < 1300:
		var w = randf_range(50, 130)
		var h = randf_range(110, 300)
		var wins = []
		for j in range(int(w / 16.0)):
			for k in range(int(h / 22.0)):
				if randf() < 0.28:
					wins.append(Vector2(8 + j * 16, 14 + k * 22))
		buildings.append({"x": x, "w": w, "h": h, "wins": wins, "col": Color(0.04, 0.04, 0.09).lerp(Color(0.08, 0.06, 0.14), randf())})
		x += w + randf_range(-10, 6)
	hat_ctrl = Art.make_hat_control(GameData.get_equipped_hat(), 190)
	hat_ctrl.position = Vector2(860, 150)
	hat_ctrl.pivot_offset = Vector2(95, 95)
	add_child(hat_ctrl)
	var center = VBoxContainer.new()
	center.position = Vector2(110, 300)
	center.add_theme_constant_override("separation", 14)
	add_child(center)
	main_box = center
	var start = Style.button("START THE SHOW", Vector2(320, 62), 26)
	start.pressed.connect(func():
		Sfx.play("select")
		start_game.emit()
	)
	center.add_child(start)
	var how = Style.button("HOW TO PLAY", Vector2(320, 52), 20)
	how.pressed.connect(_show_how)
	center.add_child(how)
	var pro = Style.button("PROLOGUE", Vector2(320, 52), 20)
	pro.pressed.connect(func():
		Sfx.play("select")
		play_intro.emit()
	)
	center.add_child(pro)
	if int(GameData.stats.get("wins", 0)) > 0 and not GameData.last_win.is_empty():
		var fin = Style.button("THE ENDING", Vector2(320, 52), 20)
		fin.pressed.connect(func():
			Sfx.play("select")
			play_ending.emit()
		)
		center.add_child(fin)
	var quit = Style.button("QUIT", Vector2(320, 52), 20)
	quit.pressed.connect(func(): get_tree().quit())
	center.add_child(quit)
	var info = Style.label("Runs: %d   Wins: %d   RP: %d" % [int(GameData.stats.get("runs", 0)), int(GameData.stats.get("wins", 0)), GameData.rhythm_points], 14, Style.MUTED)
	center.add_child(info)
	start.grab_focus()
	_build_how()

func _build_click_overlay():
	click_overlay = Button.new()
	click_overlay.text = "CLICK ANYWHERE TO START"
	click_overlay.add_theme_font_size_override("font_size", 48)
	click_overlay.add_theme_color_override("font_color", Style.GOLD)
	click_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	click_overlay.z_index = 4096
	
	var sb = StyleBoxFlat.new()
	sb.bg_color = Color(0, 0, 0, 1)
	click_overlay.add_theme_stylebox_override("normal", sb)
	click_overlay.add_theme_stylebox_override("hover", sb)
	click_overlay.add_theme_stylebox_override("pressed", sb)
	
	click_overlay.pressed.connect(_on_click_start)
	add_child(click_overlay)

func _on_click_start():
	click_overlay.queue_free()
	click_overlay = null
	Sfx.audio_started = true
	Sfx.set_music("menu")
	if main_box and main_box.get_child_count() > 0:
		main_box.get_child(0).grab_focus()

func _build_how():
	how_panel = Control.new()
	how_panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	how_panel.visible = false
	add_child(how_panel)
	var dark = ColorRect.new()
	dark.color = Color(0, 0, 0, 0.85)
	dark.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	how_panel.add_child(dark)
	var cc = CenterContainer.new()
	cc.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	how_panel.add_child(cc)
	var p = PanelContainer.new()
	p.custom_minimum_size = Vector2(820, 560)
	cc.add_child(p)
	var v = VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)
	p.add_child(v)
	var tl = Style.label("HOW TO PLAY", 36, Style.GOLD, true)
	tl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(tl)
	var body = ""
	body += "THE HAT IS EVERYTHING\n"
	body += "  Your hat's Band is your Attack, its Add-on is your Special,\n  and its Material is your Showstopper, a hat-slam ultimate.\n\n"
	body += "CONTROLS\n"
	body += "  Move: WASD / Arrows     Dash: SPACE / SHIFT (dash through bullets!)\n"
	body += "  Attack: J / Z (hold)    Special: K / X    Showstopper: L / C\n"
	body += "  Interact: E / ENTER     Boons & pause: TAB / ESC    Reroll boons: R\n\n"
	body += "A RUN\n"
	body += "  Fight through The Smoky Bar, The Neon Alley, The Grand Casino\n  and finally The Moon. Each exit door shows its reward up front.\n"
	body += "  Five Headliners offer boons (Chill, Burn, Crits, Zaps, Shockwaves).\n  Mix two of them to unlock powerful Duo boons.\n\n"
	body += "DIE TO PROGRESS\n"
	body += "  You keep every Rhythm Point. Spend them on The Setlist (permanent upgrades)\n  and the Hat-O-Matic (new hats: 50 RP, then 250, 500...). Bosses give free pulls."
	var bl = Style.label(body, 16, Style.CREAM)
	v.add_child(bl)
	var close = Style.button("GOT IT", Vector2(200, 48), 18)
	close.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	close.pressed.connect(_hide_how)
	v.add_child(close)

func _show_how():
	Sfx.play("select")
	main_box.visible = false
	how_panel.visible = true
	how_panel.get_child(1).get_child(0).get_child(0).get_child(2).grab_focus()

func _hide_how():
	how_panel.visible = false
	main_box.visible = true
	main_box.get_child(1).grab_focus()

func _unhandled_input(event):
	if how_panel.visible and event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		_hide_how()

func _process(delta):
	t += delta
	hat_ctrl.position = Vector2(860, 150 + sin(t * 1.3) * 14.0)
	hat_ctrl.rotation = sin(t * 0.9) * 0.12
	queue_redraw()

func _draw():
	# sky gradient
	for i in range(24):
		var k = float(i) / 24.0
		draw_rect(Rect2(0, i * 30, 1280, 31), Color(0.02, 0.02, 0.07).lerp(Color(0.16, 0.06, 0.18), k))
	for s in stars:
		var a = 0.5 + 0.5 * sin(t * 2.0 + float(s["ph"]))
		draw_circle(s["p"], float(s["s"]), Color(1, 1, 1, 0.3 + 0.6 * a))
	# the moon
	var mc = Vector2(950, 230)
	Art.glow(self, mc, 260, Color(1.2, 1.1, 0.8, 0.22), 6)
	draw_circle(mc, 150, Color(1.25, 1.18, 0.95))
	draw_circle(mc + Vector2(-50, -30), 26, Color(1.08, 1.0, 0.8))
	draw_circle(mc + Vector2(40, 50), 34, Color(1.08, 1.0, 0.8))
	draw_circle(mc + Vector2(60, -60), 14, Color(1.08, 1.0, 0.8))
	draw_circle(mc + Vector2(-70, 60), 18, Color(1.08, 1.0, 0.8))
	# shooting star
	var sk = fmod(t, 6.0) / 1.2
	if sk < 1.0:
		var sp = Vector2(lerpf(100, 700, sk), lerpf(40, 200, sk))
		draw_line(sp, sp - Vector2(90, 30), Color(1.5, 1.5, 2.0, 1.0 - sk), 2.0)
	# skyline
	for b in buildings:
		var bx = float(b["x"])
		var bw = float(b["w"])
		var bh = float(b["h"])
		var top = 720.0 - bh
		draw_rect(Rect2(bx, top, bw, bh), b["col"])
		for w in b["wins"]:
			var wp: Vector2 = w
			var flick = 1.0 if fmod(t * 0.3 + wp.x * 0.37 + bx, 9.0) > 0.3 else 0.3
			draw_rect(Rect2(bx + wp.x, top + wp.y, 7, 10), Color(1.0 * flick, 0.75 * flick, 0.4 * flick, 0.85))
	# title
	Art.text_left(self, Vector2(104, 170), "Fly Me to", 58, Color(0.95, 0.85, 0.6), Style.font_title)
	Art.text_left(self, Vector2(104, 250), "the Moon", 84, Color(1.2, 0.95, 0.5), Style.font_title)
	Art.text_left(self, Vector2(108, 284), "a swingin' noir-jazz roguelite starring Ol' Tin Eyes and one very important hat", 16, Color(0.85, 0.8, 0.75), Style.font_body)
	Art.text(self, Vector2(640, 706), "ARROWS + ENTER to choose", 13, Style.MUTED, Style.font_mono, 600.0)
