extends Control

## THE JUKEBOX: pick the lounge's music genre, plus volume, records and controls.

const Art = preload("res://scripts/art.gd")

signal closed

var t: float = 0.0
var list: VBoxContainer
var disc: Control

func _ready():
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	theme = Style.theme
	_build()

func _unhandled_input(event):
	if visible and (event.is_action_pressed("ui_cancel") or event.is_action_pressed("pause")):
		get_viewport().set_input_as_handled()
		closed.emit()

func _process(delta):
	t += delta
	if is_instance_valid(disc):
		disc.queue_redraw()

func _build():
	for c in get_children():
		c.queue_free()
	var dark = ColorRect.new()
	dark.color = Color(0.03, 0.02, 0.04, 0.94)
	dark.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dark.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(dark)
	var hb = HBoxContainer.new()
	hb.position = Vector2(60, 30)
	hb.size = Vector2(1160, 660)
	hb.add_theme_constant_override("separation", 30)
	add_child(hb)
	# left: track list
	var left = VBoxContainer.new()
	left.custom_minimum_size = Vector2(560, 0)
	left.add_theme_constant_override("separation", 8)
	hb.add_child(left)
	left.add_child(Style.label("THE JUKEBOX", 38, Style.GOLD, true))
	left.add_child(Style.label("Pick what the house band plays in the lounge.", 15, Style.MUTED))
	list = VBoxContainer.new()
	list.add_theme_constant_override("separation", 6)
	left.add_child(list)
	var first: Button = null
	for tr_ in Sfx.TRACKS:
		var mode = String(tr_[0])
		var playing = GameData.hub_track == mode
		var b = Style.button("%s%s   -   %s" % ["> " if playing else "", tr_[1], tr_[2]], Vector2(540, 46), 16)
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		if playing:
			b.add_theme_color_override("font_color", Style.GOLD)
		b.pressed.connect(func():
			GameData.hub_track = mode
			GameData.save_game()
			Sfx.set_music(mode)
			Sfx.play("select")
			_build()
		)
		list.add_child(b)
		if first == null or playing:
			first = b
	if Sfx.has_file_for("hub"):
		left.add_child(Style.label("A drop-in track in audio/music/ is overriding the lounge music.", 13, Color(1.0, 0.7, 0.6)))
	var vol = HBoxContainer.new()
	vol.add_theme_constant_override("separation", 10)
	left.add_child(vol)
	var mb = Style.button("Music: %d%%" % int(round(GameData.music_volume * 100)), Vector2(170, 42), 15)
	mb.pressed.connect(func():
		GameData.music_volume = 0.0 if GameData.music_volume >= 0.99 else snappedf(GameData.music_volume + 0.25, 0.25)
		mb.text = "Music: %d%%" % int(round(GameData.music_volume * 100))
		GameData.save_game()
	)
	vol.add_child(mb)
	var sb = Style.button("SFX: %d%%" % int(round(GameData.sfx_volume * 100)), Vector2(170, 42), 15)
	sb.pressed.connect(func():
		GameData.sfx_volume = 0.0 if GameData.sfx_volume >= 0.99 else snappedf(GameData.sfx_volume + 0.25, 0.25)
		sb.text = "SFX: %d%%" % int(round(GameData.sfx_volume * 100))
		GameData.save_game()
		Sfx.play("coin")
	)
	vol.add_child(sb)
	var close = Style.button("CLOSE", Vector2(170, 42), 15)
	close.pressed.connect(func(): closed.emit())
	vol.add_child(close)
	# right: spinning record + records/stats
	var right = VBoxContainer.new()
	right.add_theme_constant_override("separation", 8)
	hb.add_child(right)
	disc = Control.new()
	disc.custom_minimum_size = Vector2(540, 220)
	disc.draw.connect(func():
		var c = Vector2(270, 110)
		Art.glow(disc, c, 120, Color(1.2, 0.9, 0.5, 0.25), 4)
		Art.record_glyph(disc, c, 95, t * 2.0)
		for i in range(4):
			var nt = fmod(t * 0.4 + i * 0.25, 1.0)
			Art.note_glyph(disc, c + Vector2(110 + sin(nt * 6.0 + i) * 20.0, 40 - nt * 150.0), 12, Color(1.6, 1.3, 0.6, 1.0 - nt))
	)
	right.add_child(disc)
	var s = GameData.stats
	var body = "RECORDS\n  Runs: %d    Wins: %d    Bosses beaten: %d\n  Best depth: %d rooms    Foes knocked out: %d\n  Robots who've worn the hat: %d\n\n" % [int(s.get("runs", 0)), int(s.get("wins", 0)), int(s.get("bosses", 0)), int(s.get("best_depth", 0)), int(s.get("kills", 0)), int(s.get("runs", 0))]
	body += "CONTROLS\n  Move  WASD / Arrows        Dash  SPACE / SHIFT\n  Attack  J / Z  (hold)         Special  K / X\n  Showstopper  L / C            Interact  E / ENTER\n  Boons & pause  TAB / ESC      Reroll boons  R"
	right.add_child(Style.label(body, 15, Style.CREAM))
	if first != null:
		first.call_deferred("grab_focus")
