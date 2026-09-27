extends Control

## THE WARDROBE: view, equip and scrap hats. Keyboard: arrows + ENTER, ESC closes.

const Art = preload("res://scripts/art.gd")
const BoonData = preload("res://scripts/boon_data.gd")

signal closed
signal equipped

var hbox: HBoxContainer
var info: Label
var t: float = 0.0
var sparkles: Array = []

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
	for sp_c in sparkles:
		if is_instance_valid(sp_c):
			sp_c.queue_redraw()

func _build():
	sparkles.clear()
	for c in get_children():
		c.queue_free()
	var dark = ColorRect.new()
	dark.color = Color(0.02, 0.015, 0.03, 0.93)
	dark.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dark.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(dark)
	var center = CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var vb = VBoxContainer.new()
	vb.add_theme_constant_override("separation", 14)
	vb.alignment = BoxContainer.ALIGNMENT_CENTER
	center.add_child(vb)
	var title = Style.label("THE WARDROBE", 40, Style.GOLD, true)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vb.add_child(title)
	var sub = Style.label("%d / %d hat slots   -   the hat IS your moveset" % [GameData.roster.size(), GameData.max_roster()], 16, Style.MUTED)
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vb.add_child(sub)
	var scroll = ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(1220, 500)
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.follow_focus = true
	vb.add_child(scroll)
	var cc = CenterContainer.new()
	cc.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cc.custom_minimum_size = Vector2(1200, 490)
	scroll.add_child(cc)
	hbox = HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 16)
	cc.add_child(hbox)
	var first_btn: Button = null
	for i in range(GameData.roster.size()):
		var b = _hat_card(i)
		hbox.add_child(b)
		if first_btn == null or i == GameData.equipped_hat_index:
			first_btn = b.get_meta("equip_btn")
	var close = Style.button("BACK TO THE LOUNGE", Vector2(300, 48), 18)
	close.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	close.pressed.connect(func(): closed.emit())
	vb.add_child(close)
	if first_btn != null:
		first_btn.call_deferred("grab_focus")
	else:
		close.call_deferred("grab_focus")

func _hat_card(i: int) -> Control:
	var hat: Dictionary = GameData.roster[i]
	var rc = GameData.hat_grade_color(hat)
	var panel = PanelContainer.new()
	panel.custom_minimum_size = Vector2(280, 480)
	var eq = i == GameData.equipped_hat_index
	panel.add_theme_stylebox_override("panel", Style.panel_box(Color(0.07, 0.05, 0.08, 0.98), rc if eq else Color(rc.r, rc.g, rc.b, 0.45), 3 if eq else 2, 12))
	var v = VBoxContainer.new()
	v.add_theme_constant_override("separation", 6)
	panel.add_child(v)
	# mannequin + hat
	var stage = Control.new()
	stage.custom_minimum_size = Vector2(240, 150)
	stage.draw.connect(func():
		var c = Vector2(stage.size.x * 0.5, 138)
		if eq:
			# the hat you're wearing gets the spotlight
			stage.draw_colored_polygon(PackedVector2Array([Vector2(c.x - 18, 0), Vector2(c.x + 18, 0), Vector2(c.x + 80, c.y + 8), Vector2(c.x - 80, c.y + 8)]), Color(1.4, 1.2, 0.8, 0.12))
			Art.glow(stage, Vector2(c.x, 50), 90.0, Color(rc.r * 1.4, rc.g * 1.4, rc.b * 1.4, 0.22), 4)
			Art.ellipse(stage, c, 76, 15, Color(1.4, 1.2, 0.8, 0.2))
		Art.ellipse(stage, c, 60, 12, Color(0, 0, 0, 0.4))
		Art.rrect(stage, Rect2(c.x - 6, c.y - 60, 12, 60), 3, Color(0.35, 0.25, 0.18))
		stage.draw_circle(Vector2(c.x, c.y - 70), 26, Color(0.85, 0.8, 0.72))
	)
	var hv = Art.make_hat_control(hat, 150)
	hv.position = Vector2(45, -34)
	stage.add_child(hv)
	if hat.get("is_chroma", false):
		# the same rainbow sparkles a chroma hat has on your head
		var sp_c = Control.new()
		sp_c.mouse_filter = Control.MOUSE_FILTER_IGNORE
		sp_c.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		sp_c.draw.connect(func():
			var hc = Vector2(stage.size.x * 0.5, 44)
			for si in range(6):
				var sa = t * 1.6 + TAU * float(si) / 6.0
				var scol = Color.from_hsv(fmod(t * 0.3 + float(si) / 6.0, 1.0), 0.6, 1.8)
				Art.star(sp_c, hc + Vector2(cos(sa) * 62.0, sin(sa) * 18.0), 6.0, 2.0, 4, scol, t * 3.0)
		)
		stage.add_child(sp_c)
		sparkles.append(sp_c)
	var gb = Art.make_grade_badge(hat, 48)
	gb.position = Vector2(4, 4)
	stage.add_child(gb)
	v.add_child(stage)
	if not eq:
		stage.modulate = Color(0.45, 0.45, 0.5)   # dimmed: not the hat you're wearing
	var nm = Style.label(GameData.hat_name(hat), 20, rc if eq else rc.darkened(0.35), true)
	nm.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	nm.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(nm)
	var tag = GameData.hat_grade_label(hat)
	var tl = Style.label(tag, 13, rc)
	tl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(tl)
	var st = Style.label("+%d%% damage   +%d health" % [int(GameData.hat_power_pct(hat)), GameData.hat_bonus_hp(hat)], 15, Style.CREAM)
	st.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(st)
	if not eq:
		var eh = GameData.get_equipped_hat()
		var dd = int(GameData.hat_power_pct(hat)) - int(GameData.hat_power_pct(eh))
		var dh = GameData.hat_bonus_hp(hat) - GameData.hat_bonus_hp(eh)
		var cmp = Style.label("vs equipped:  %s%d%% dmg   %s%d hp" % ["+" if dd >= 0 else "", dd, "+" if dh >= 0 else "", dh], 13, Color(0.45, 1.0, 0.5) if dd + dh * 0.5 >= 0 else Color(1.0, 0.45, 0.45))
		cmp.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		v.add_child(cmp)
	var bk = BoonData.BAND_KITS.get(hat.get("band", "cotton"), {})
	var ak = BoonData.ADDON_KITS.get(hat.get("addon", "paperclip"), {})
	var mk = BoonData.MAT_KITS.get(hat.get("material", "cardboard"), {})
	for row in [["J", bk, int(hat.get("band_rarity", 0))], ["K", ak, int(hat.get("addon_rarity", 0))], ["L", mk, int(hat.get("material_rarity", 0))]]:
		var kit: Dictionary = row[1]
		var l = Style.label("%s  %s - %s" % [row[0], kit.get("name", "?"), kit.get("desc", "")], 13, GameData.get_rarity_color(int(row[2])))
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.custom_minimum_size = Vector2(240, 0)
		v.add_child(l)
	var sp = Control.new()
	sp.size_flags_vertical = Control.SIZE_EXPAND_FILL
	v.add_child(sp)
	var eb = Style.button("EQUIPPED" if eq else "EQUIP", Vector2(0, 40), 17)
	eb.pressed.connect(func():
		if GameData.equipped_hat_index != i:
			GameData.equipped_hat_index = i
			GameData.save_game()
			Sfx.play("select")
			equipped.emit()
			_build()
	)
	v.add_child(eb)
	var val = GameData.scrap_value(hat)
	var sb = Style.button("SCRAP  +%d RP" % val, Vector2(0, 36), 14)
	sb.disabled = eq or GameData.roster.size() <= 1
	sb.pressed.connect(func():
		if GameData.roster.size() <= 1 or i == GameData.equipped_hat_index:
			return
		var eq_hat = GameData.get_equipped_hat()
		GameData.rhythm_points += val
		GameData.roster.remove_at(i)
		GameData.equipped_hat_index = maxi(0, GameData.roster.find(eq_hat))
		GameData.save_game()
		Sfx.play("buy")
		_build()
	)
	v.add_child(sb)
	panel.set_meta("equip_btn", eb)
	return panel
