extends Control

## HALL OF FAME: every show that's been played, framed like a backstage photo wall.
## Sort by most recent or best. UP/DOWN / wheel scroll, ESC close.

const Art = preload("res://scripts/art.gd")
const BoonData = preload("res://scripts/boon_data.gd")
const WorldData = preload("res://scripts/world_data.gd")

signal closed

var t: float = 0.0
var mode: String = "recent"
var scroll: ScrollContainer
var grid: GridContainer
var photos: Array = []
var sort_btns: Array = []

func _ready():
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	theme = Style.theme
	var dark = ColorRect.new()
	dark.color = Color(0.05, 0.02, 0.03, 0.96)
	dark.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dark.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(dark)
	var title = Style.label("HALL OF FAME", 38, Style.GOLD, true)
	title.position = Vector2(40, 12)
	add_child(title)
	var s = GameData.stats
	var sub = Style.label("%d shows played   -   %d played the Moon   -   deepest run: %d rooms" % [int(s.get("runs", 0)), int(s.get("wins", 0)), int(s.get("best_depth", 0))], 14, Style.MUTED)
	sub.position = Vector2(44, 62)
	add_child(sub)
	var hb = HBoxContainer.new()
	hb.position = Vector2(820, 20)
	hb.add_theme_constant_override("separation", 8)
	add_child(hb)
	for m in [["recent", "MOST RECENT"], ["best", "BEST SHOWS"]]:
		var b = Style.button(String(m[1]), Vector2(150, 38), 14)
		var mid = String(m[0])
		b.pressed.connect(func(): _set_mode(mid))
		b.focus_entered.connect(func():
			if mode != mid:
				_set_mode(mid)
		)
		hb.add_child(b)
		sort_btns.append([mid, b])
	var close = Style.button("CLOSE", Vector2(100, 38), 14)
	close.focus_mode = Control.FOCUS_NONE
	close.pressed.connect(func(): closed.emit())
	hb.add_child(close)
	scroll = ScrollContainer.new()
	scroll.position = Vector2(40, 96)
	scroll.size = Vector2(1200, 610)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(scroll)
	grid = GridContainer.new()
	grid.columns = 4
	grid.add_theme_constant_override("h_separation", 14)
	grid.add_theme_constant_override("v_separation", 14)
	scroll.add_child(grid)
	_set_mode("recent")
	(sort_btns[0][1] as Button).call_deferred("grab_focus")

func _unhandled_input(event):
	if not visible:
		return
	if event.is_action_pressed("ui_cancel") or event.is_action_pressed("pause"):
		get_viewport().set_input_as_handled()
		closed.emit()
	elif event.is_action_pressed("ui_down") or event.is_action_pressed("move_down"):
		scroll.scroll_vertical += 120
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("ui_up") or event.is_action_pressed("move_up"):
		scroll.scroll_vertical -= 120
		get_viewport().set_input_as_handled()

func _process(delta):
	t += delta
	for p in photos:
		if is_instance_valid(p):
			p.queue_redraw()

static func show_score(e: Dictionary) -> int:
	return (10000 if e.get("won", false) else 0) + int(e.get("bosses", 0)) * 1000 + int(e.get("depth", 0)) * 10 + int(e.get("kills", 0))

func _set_mode(m: String):
	mode = m
	for sb in sort_btns:
		(sb[1] as Button).add_theme_color_override("font_color", Style.GOLD if sb[0] == m else Style.CREAM)
	for c in grid.get_children():
		c.queue_free()
	photos.clear()
	var list = GameData.history.duplicate()
	if m == "recent":
		list.reverse()
	else:
		list.sort_custom(func(a, b): return show_score(a) > show_score(b))
	if list.is_empty():
		var l = Style.label("No shows yet. Your first photo goes up after your first run.", 18, Style.MUTED)
		grid.add_child(l)
		return
	var rank = 0
	for e in list:
		rank += 1
		grid.add_child(_card(e, rank if m == "best" else 0))

func _card(e: Dictionary, rank: int) -> PanelContainer:
	var won = e.get("won", false)
	var border = Style.GOLD if won else Color(0.55, 0.42, 0.3)
	var p = PanelContainer.new()
	p.custom_minimum_size = Vector2(285, 380)
	p.add_theme_stylebox_override("panel", Style.panel_box(Color(0.1, 0.07, 0.06, 0.98), border, 4 if won else 3, 4))
	var v = VBoxContainer.new()
	v.add_theme_constant_override("separation", 4)
	p.add_child(v)
	# the "photo": sepia backdrop, spotlight, the performer in their paint job + hat
	var hat: Dictionary = e.get("hat", {})
	var sk = GameData.SKINS[0]
	for s in GameData.SKINS:
		if s["id"] == String(e.get("skin", "classic")):
			sk = s
	var ph = Control.new()
	ph.custom_minimum_size = Vector2(250, 150)
	ph.clip_contents = true
	ph.draw.connect(func():
		ph.draw_rect(Rect2(Vector2.ZERO, ph.size), Color(0.32, 0.24, 0.17))
		ph.draw_colored_polygon(PackedVector2Array([Vector2(115, 0), Vector2(135, 0), Vector2(190, 150), Vector2(60, 150)]), Color(1.0, 0.9, 0.7, 0.12))
		Art.ellipse(ph, Vector2(125, 140), 55, 10, Color(0, 0, 0, 0.3))
		ph.draw_set_transform(Vector2(125, 140), 0.0, Vector2(1.3, 1.3))
		Art.draw_robot(ph, t * 0.5, Vector2.DOWN, false, 0.0, sk["body"], sk)
		ph.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		if won:
			for i in range(8):
				var cx = fmod(float(i) * 41.0 + t * 20.0, 250.0)
				var cy = fmod(float(i) * 23.0 + t * 40.0, 150.0)
				ph.draw_rect(Rect2(cx, cy, 5, 3), Color.from_hsv(fmod(float(i) * 0.13, 1.0), 0.6, 1.4, 0.8))
		if rank > 0 and rank <= 3:
			Art.grade_badge(ph, Vector2(24, 24), "#%d" % rank, [Style.GOLD, Color(0.8, 0.8, 0.85), Color(0.8, 0.5, 0.3)][rank - 1], 18.0)
	)
	photos.append(ph)
	if not hat.is_empty():
		var hv = Art.make_hat_control(hat, 83.2)
		hv.position = Vector2(125 - 41.6, 140 + Art.HEAD_TOP * 1.3 - 53.3)
		ph.add_child(hv)
	v.add_child(ph)
	var nm = Style.label(String(e.get("name", "Unknown")), 20, Style.CREAM, true)
	nm.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(nm)
	var show_l = Style.label("Show #%d  as Ol' Tin Eyes" % int(e.get("n", 0)), 12, Style.MUTED)
	show_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(show_l)
	var b = WorldData.biome(int(e.get("biome", 0)))
	var result = ""
	var rc = Color(1.0, 0.55, 0.45)
	if won:
		result = "PLAYED THE MOON!"
		rc = Style.GOLD
	else:
		result = "Bowed out: %s" % b["name"]
	var rl = Style.label(result, 16, rc)
	rl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(rl)
	if not won:
		var kl = Style.label("Knocked out by %s" % String(e.get("killer", "?")), 12, Style.MUTED)
		kl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		v.add_child(kl)
	var secs = int(float(e.get("time", 0.0)))
	var st = Style.label("%d rooms   %d KOs   %d bosses   %d:%02d" % [int(e.get("depth", 0)), int(e.get("kills", 0)), int(e.get("bosses", 0)), int(secs / 60.0), secs % 60], 12, Style.CREAM)
	st.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(st)
	if not hat.is_empty():
		var hl = Style.label("%s  (%s)" % [GameData.hat_name(hat), GameData.hat_grade(hat)], 12, GameData.hat_grade_color(hat))
		hl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		hl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		hl.custom_minimum_size = Vector2(250, 0)
		v.add_child(hl)
	# boon dots in their Headliner colours
	var boons: Array = e.get("boons", [])
	if not boons.is_empty():
		var dots = Control.new()
		dots.custom_minimum_size = Vector2(250, 20)
		dots.draw.connect(func():
			var n = mini(boons.size(), 14)
			for i in range(n):
				var bd = BoonData.BOONS.get(boons[i].get("id", ""), {})
				var pc: Color = BoonData.PATRONS.get(bd.get("patron", ""), {}).get("color", Style.CREAM)
				var x = 125.0 - float(n - 1) * 8.0 + i * 16.0
				dots.draw_circle(Vector2(x, 10), 6, pc)
		)
		v.add_child(dots)
	return p
