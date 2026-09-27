extends Control

## ChoiceUI: pauses the game and shows Hades-style card choices
## (boons, encores, tailor mods), the pause/boon list, and simple messages.

const Art = preload("res://scripts/art.gd")
const BoonData = preload("res://scripts/boon_data.gd")

var input_delay: float = 0.0
var _reroll_cb: Callable
var _rerolls: int = 0
var _pause_cb: Callable
var _kind: String = ""
var t: float = 0.0
var emblem_t: float = 0.0

func _ready():
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	theme = Style.theme
	mouse_filter = Control.MOUSE_FILTER_STOP
	hide()

func is_open() -> bool:
	return visible

func _process(delta):
	t += delta
	if visible:
		input_delay -= delta
		emblem_t += delta

func _clear():
	for c in get_children():
		c.queue_free()

func _begin(kind: String):
	_clear()
	_kind = kind
	visible = true
	get_tree().paused = true
	input_delay = 0.4
	var dark = ColorRect.new()
	dark.color = Color(0.02, 0.01, 0.03, 0.82)
	dark.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dark.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(dark)

func close():
	visible = false
	_kind = ""
	_clear()
	get_tree().paused = false

func _input(event):
	if not visible:
		return
	if _kind == "cards" and event.is_action_pressed("reroll") and _rerolls > 0 and _reroll_cb.is_valid() and input_delay <= 0.0:
		get_viewport().set_input_as_handled()
		Sfx.play("lever")
		_reroll_cb.call()
	elif _kind == "pause" and (event.is_action_pressed("pause") or event.is_action_pressed("boon_list")) and input_delay <= 0.1:
		get_viewport().set_input_as_handled()
		close()
		if _pause_cb.is_valid():
			_pause_cb.call()

# ---------------------------------------------------------------------------
# CARDS
# cards: [{title, tag, desc, rarity_name, color, accent, footer}]
# ---------------------------------------------------------------------------
func open_cards(title: String, subtitle: String, cards: Array, pick_cb: Callable, patron: String = "", reroll_cb: Callable = Callable(), rerolls: int = 0):
	_begin("cards")
	_reroll_cb = reroll_cb
	_rerolls = rerolls
	var center = CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var vb = VBoxContainer.new()
	vb.alignment = BoxContainer.ALIGNMENT_CENTER
	vb.add_theme_constant_override("separation", 14)
	center.add_child(vb)
	if patron != "":
		var portrait = Control.new()
		portrait.custom_minimum_size = Vector2(600, 160)
		portrait.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		portrait.draw.connect(func(): _draw_emblem(portrait, patron))
		vb.add_child(portrait)
		var tw = portrait.create_tween().set_loops()
		tw.tween_callback(portrait.queue_redraw).set_delay(0.033)
		emblem_t = 0.0
		Sfx.play("sting_" + patron)
	var tl = Style.label(title, 38, Style.GOLD, true)
	tl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vb.add_child(tl)
	if patron != "":
		var ch = BoonData.character(patron)
		var ep = Style.label(String(ch.get("title", "")).to_upper(), 14, ch.get("color", Style.GOLD))
		ep.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		vb.add_child(ep)
	var sl = Style.label(subtitle, 18, Style.CREAM)
	sl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vb.add_child(sl)
	if patron != "":
		# the Headliner's line types itself out
		sl.visible_ratio = 0.0
		var tws = sl.create_tween()
		tws.tween_property(sl, "visible_ratio", 1.0, 1.1)
	var hb = HBoxContainer.new()
	hb.alignment = BoxContainer.ALIGNMENT_CENTER
	hb.add_theme_constant_override("separation", 22)
	vb.add_child(hb)
	var first: Button = null
	for i in range(cards.size()):
		var c = cards[i]
		var b = _make_card(c)
		var idx = i
		b.pressed.connect(func():
			if input_delay > 0.0:
				return
			Sfx.play("boon")
			close()
			pick_cb.call(idx)
		)
		hb.add_child(b)
		if first == null:
			first = b
	var foot = "ARROWS to choose  -  ENTER to take"
	if rerolls > 0 and reroll_cb.is_valid():
		foot += "  -  R to reroll (%d left)" % rerolls
	var fl = Style.label(foot, 15, Style.MUTED)
	fl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vb.add_child(fl)
	if first != null:
		first.grab_focus()

func _make_card(c: Dictionary) -> Button:
	var b = Button.new()
	b.custom_minimum_size = Vector2(300, 330)
	b.focus_mode = Control.FOCUS_ALL
	var col: Color = c.get("color", Style.CREAM)
	var acc: Color = c.get("accent", Style.GOLD)
	var n = Style.panel_box(Color(0.07, 0.05, 0.08, 0.98), Color(col.r, col.g, col.b, 0.6), 2, 12)
	var h = Style.panel_box(Color(0.12, 0.08, 0.1, 1.0), col, 3, 12)
	b.add_theme_stylebox_override("normal", n)
	b.add_theme_stylebox_override("hover", h)
	b.add_theme_stylebox_override("pressed", h)
	b.add_theme_stylebox_override("focus", Style.panel_box(Color(0, 0, 0, 0), Color(1.0, 0.9, 0.6), 3, 12))
	b.focus_entered.connect(func():
		Sfx.play("tick", 1.2, -6.0)
		var tw = b.create_tween()
		tw.tween_property(b, "scale", Vector2(1.04, 1.04), 0.08)
	)
	b.focus_exited.connect(func():
		var tw = b.create_tween()
		tw.tween_property(b, "scale", Vector2.ONE, 0.08)
	)
	b.resized.connect(func(): b.pivot_offset = b.size * 0.5)
	var m = MarginContainer.new()
	m.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right", "top", "bottom"]:
		m.add_theme_constant_override("margin_" + side, 18)
	m.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(m)
	var v = VBoxContainer.new()
	v.add_theme_constant_override("separation", 8)
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	m.add_child(v)
	var tag = Style.label(String(c.get("tag", "")), 13, acc)
	tag.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(tag)
	var name_l = Style.label(String(c.get("title", "")), 26, col, true)
	name_l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	name_l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(name_l)
	var rl = Style.label(String(c.get("rarity_name", "")), 14, col)
	rl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(rl)
	var sep = ColorRect.new()
	sep.color = Color(acc.r, acc.g, acc.b, 0.4)
	sep.custom_minimum_size = Vector2(0, 2)
	sep.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(sep)
	var d = Style.label(String(c.get("desc", "")), 18, Style.CREAM)
	d.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	d.custom_minimum_size = Vector2(250, 0)
	d.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(d)
	var sp = Control.new()
	sp.size_flags_vertical = Control.SIZE_EXPAND_FILL
	sp.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(sp)
	if String(c.get("footer", "")) != "":
		var f = Style.label(String(c["footer"]), 14, Style.MUTED)
		f.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		f.mouse_filter = Control.MOUSE_FILTER_IGNORE
		v.add_child(f)
	return b

func _draw_emblem(ci: Control, patron: String):
	# the Headliner themselves, in a spotlight, with where they came from
	var p = BoonData.character(patron)
	var col: Color = p.get("color", Style.GOLD)
	var c = Vector2(ci.size.x * 0.5, ci.size.y)
	# legendary entrance: spotlight snaps on, the Headliner rises into it
	var ent = clampf(emblem_t / 0.45, 0.0, 1.0)
	var ez = 1.0 - pow(1.0 - ent, 3.0)
	var flash = maxf(0.0, 1.0 - emblem_t * 2.5)
	ci.draw_colored_polygon(PackedVector2Array([Vector2(c.x - 12, 0), Vector2(c.x + 12, 0), Vector2(c.x + 110, c.y), Vector2(c.x - 110, c.y)]), Color(col.r, col.g, col.b, 0.1 + 0.25 * flash))
	Art.glow(ci, c + Vector2(0, -60), 80 + 60 * flash, Color(col.r * 1.3, col.g * 1.3, col.b * 1.3, 0.28 + 0.4 * flash), 5)
	for i in range(10):
		var ra = t * 0.4 + TAU * float(i) / 10.0
		ci.draw_line(c + Vector2(0, -70), c + Vector2(0, -70) + Vector2(cos(ra), sin(ra)) * 170.0, Color(col.r, col.g, col.b, 0.06 * ez), 10.0)
	Art.patron_portrait(ci, patron, t, c + Vector2(0, -4 + (1.0 - ez) * 50.0), 0.85 + 0.15 * ez)
	ci.draw_multiline_string(Style.font_mono, Vector2(c.x - 270, c.y - 90), String(p.get("species", "")), HORIZONTAL_ALIGNMENT_RIGHT, 160, 12, 3, Color(col.r, col.g, col.b, 0.85))
	ci.draw_multiline_string(Style.font_mono, Vector2(c.x + 110, c.y - 90), "FROM: " + String(p.get("from", "")), HORIZONTAL_ALIGNMENT_LEFT, 160, 12, 3, Color(col.r, col.g, col.b, 0.85))

# ---------------------------------------------------------------------------
# PAUSE / BOON LIST
# ---------------------------------------------------------------------------
func open_pause(player, on_resume: Callable, on_quit: Callable):
	_begin("pause")
	_pause_cb = on_resume
	input_delay = 0.15
	var center = CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var panel = PanelContainer.new()
	panel.custom_minimum_size = Vector2(820, 540)
	center.add_child(panel)
	var vb = VBoxContainer.new()
	vb.add_theme_constant_override("separation", 10)
	panel.add_child(vb)
	var tl = Style.label("INTERMISSION  -  your boons this run", 32, Style.GOLD, true)
	tl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vb.add_child(tl)
	var hat = player.hat
	var kit = Style.label("%s   |   J: %s   K: %s   L: %s" % [GameData.hat_name(hat), player.band_kit["name"], player.addon_kit["name"], player.mat_kit["name"]], 15, Style.CREAM)
	kit.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vb.add_child(kit)
	var scroll = ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(780, 330)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	vb.add_child(scroll)
	var list = VBoxContainer.new()
	list.add_theme_constant_override("separation", 6)
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(list)
	if player.boons.is_empty() and player.mods.is_empty():
		list.add_child(Style.label("No boons yet. Clear rooms to earn favor from the Headliners.", 17, Style.MUTED))
	for id in player.boons.keys():
		var bd = BoonData.BOONS[id]
		var r = int(player.boons[id]["rarity"])
		var lv = int(player.boons[id]["level"])
		var pc: Color = BoonData.PATRONS[bd["patron"]]["color"]
		var row = Style.label("%s  %s  [%s, Lv %d/%d]  -  %s" % [BoonData.slot_label(String(bd["slot"])), bd["name"], BoonData.RARITY_NAMES[r], lv, BoonData.MAX_LEVEL, BoonData.boon_desc(id, r, lv)], 16, pc)
		row.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		row.custom_minimum_size = Vector2(760, 0)
		list.add_child(row)
	for mid in player.mods:
		var md = BoonData.HAT_MODS.get(mid, {})
		list.add_child(Style.label("TAILOR  %s  -  %s" % [md.get("name", mid), md.get("desc", "")], 16, Color(0.9, 0.85, 0.7)))
	var hb = HBoxContainer.new()
	hb.alignment = BoxContainer.ALIGNMENT_CENTER
	hb.add_theme_constant_override("separation", 20)
	vb.add_child(hb)
	var resume = Style.button("RESUME", Vector2(220, 50), 20)
	resume.pressed.connect(func():
		close()
		if on_resume.is_valid():
			on_resume.call()
	)
	hb.add_child(resume)
	var quit = Style.button("TAKE A BOW (end run)", Vector2(300, 50), 18)
	quit.pressed.connect(func():
		close()
		on_quit.call()
	)
	hb.add_child(quit)
	resume.grab_focus()

# ---------------------------------------------------------------------------
# MESSAGE
# ---------------------------------------------------------------------------
func open_message(title: String, body: String, col: Color, cb: Callable = Callable()):
	_begin("message")
	var center = CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var panel = PanelContainer.new()
	panel.custom_minimum_size = Vector2(560, 240)
	center.add_child(panel)
	var vb = VBoxContainer.new()
	vb.alignment = BoxContainer.ALIGNMENT_CENTER
	vb.add_theme_constant_override("separation", 16)
	panel.add_child(vb)
	var tl = Style.label(title, 34, col, true)
	tl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vb.add_child(tl)
	var bl = Style.label(body, 18, Style.CREAM)
	bl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	bl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	bl.custom_minimum_size = Vector2(500, 0)
	vb.add_child(bl)
	var ok = Style.button("CONTINUE", Vector2(220, 50), 20)
	ok.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	ok.pressed.connect(func():
		if input_delay > 0.0:
			return
		close()
		if cb.is_valid():
			cb.call()
	)
	vb.add_child(ok)
	ok.grab_focus()
