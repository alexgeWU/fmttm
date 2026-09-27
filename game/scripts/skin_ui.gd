extends Control

## THE DRESSING ROOM: buy and equip robot stage looks (paint jobs) with Stage Tokens.
## Earn Tokens every run (more for going deeper and beating bosses).

const Art = preload("res://scripts/art.gd")

signal closed
signal changed

var t: float = 0.0
var previews: Array = []
var header: Label

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
	for p in previews:
		if is_instance_valid(p):
			p.queue_redraw()

func _build():
	for c in get_children():
		c.queue_free()
	previews.clear()
	var dark = ColorRect.new()
	dark.color = Color(0.03, 0.02, 0.04, 0.95)
	dark.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dark.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(dark)
	var root = VBoxContainer.new()
	root.position = Vector2(40, 20)
	root.size = Vector2(1200, 680)
	root.add_theme_constant_override("separation", 10)
	add_child(root)
	var title = Style.label("THE DRESSING ROOM", 38, Style.GOLD, true)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	root.add_child(title)
	header = Style.label("You have %d Stage Tokens.  Earn more every run: go deeper, beat bosses." % GameData.tokens, 16, Color(1.0, 0.8, 0.6))
	header.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	root.add_child(header)
	var grid = GridContainer.new()
	grid.columns = 5
	grid.add_theme_constant_override("h_separation", 12)
	grid.add_theme_constant_override("v_separation", 12)
	root.add_child(grid)
	var first: Button = null
	for sk in GameData.SKINS:
		var card = _card(sk)
		grid.add_child(card)
		var b: Button = card.get_meta("btn")
		if first == null or sk["id"] == GameData.skin_id:
			first = b
	var close = Style.button("BACK TO THE LOUNGE", Vector2(300, 46), 18)
	close.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	close.pressed.connect(func(): closed.emit())
	root.add_child(close)
	if first != null:
		first.call_deferred("grab_focus")

func _card(sk: Dictionary) -> PanelContainer:
	var id = String(sk["id"])
	var owned = GameData.skins_owned.has(id)
	var equipped = GameData.skin_id == id
	var p = PanelContainer.new()
	p.custom_minimum_size = Vector2(228, 272)
	var border = Style.GOLD if equipped else (Color(0.5, 0.9, 0.6) if owned else Style.GOLD_DIM)
	p.add_theme_stylebox_override("panel", Style.panel_box(Color(0.07, 0.05, 0.08, 0.98), border, 3 if equipped else 2, 12))
	var v = VBoxContainer.new()
	v.add_theme_constant_override("separation", 4)
	p.add_child(v)
	var pv = Control.new()
	pv.custom_minimum_size = Vector2(200, 140)
	pv.clip_contents = true
	pv.draw.connect(func():
		var c = Vector2(pv.size.x * 0.5, 136)
		Art.ellipse(pv, c, 50, 10, Color(1.0, 0.9, 0.6, 0.12))
		pv.draw_set_transform(c, 0.0, Vector2(1.3, 1.3))
		Art.draw_robot(pv, t + float(id.length()), Vector2(sin(t * 0.8) * 0.4, 1.0), false, 0.0, sk["body"], sk)
		pv.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	)
	v.add_child(pv)
	previews.append(pv)
	var hv = Art.make_hat_control(GameData.get_equipped_hat(), 83.2)
	hv.position = Vector2(100 - 41.6, 136 + Art.HEAD_TOP * 1.3 - 53.3)
	pv.add_child(hv)
	var nm = Style.label(String(sk["name"]), 18, border if owned else Style.CREAM, true)
	nm.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(nm)
	var d = Style.label(String(sk["desc"]), 12, Style.MUTED)
	d.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	d.custom_minimum_size = Vector2(200, 34)
	d.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(d)
	var cost = int(sk["cost"])
	var txt = "EQUIPPED" if equipped else ("EQUIP" if owned else "BUY  %d TOKENS" % cost)
	var b = Style.button(txt, Vector2(0, 38), 15)
	b.disabled = equipped or (not owned and GameData.tokens < cost)
	b.pressed.connect(func():
		if not GameData.skins_owned.has(id):
			if GameData.tokens < cost:
				Sfx.play("error")
				return
			GameData.tokens -= cost
			GameData.skins_owned.append(id)
			Sfx.play("buy")
		else:
			Sfx.play("select")
		GameData.skin_id = id
		GameData.save_game()
		changed.emit()
		_build()
	)
	v.add_child(b)
	p.set_meta("btn", b)
	return p
