extends Control

## THE SETLIST: permanent upgrades (Johnny Upgrade style web).
## Everything is visible. Buying a node unlocks the nodes connected after it.
##   Mouse: click a node to select, click it again (or BUY) to purchase,
##          drag empty space to pan, wheel to zoom.
##   Keys:  arrows move, ENTER buy, +/- zoom, F fit, TAB next affordable, ESC close.

const Art = preload("res://scripts/art.gd")

signal closed

const SPACING = 104.0
const NODE_R = 28.0
const SIDE = Rect2(8, 72, 256, 640)
const GRAPH = Rect2(276, 112, 996, 458)
const INFO = Rect2(276, 578, 996, 134)
const CAT_COLORS = {
	"core": Color(1.0, 0.8, 0.4),
	"off": Color(1.0, 0.42, 0.38),
	"def": Color(0.45, 0.72, 1.0),
	"mob": Color(0.4, 1.0, 0.75),
	"luck": Color(1.0, 0.82, 0.3),
}
const CAT_NAMES = {"core": "CORE", "off": "OFFENSE", "def": "DEFENSE", "mob": "MOBILITY", "luck": "FORTUNE"}
const TABS = [["all", "ALL"], ["off", "OFFENSE"], ["def", "DEFENSE"], ["mob", "MOBILITY"], ["luck", "FORTUNE"]]

var sel: String = "chassis"
var hover: String = ""
var pan: Vector2 = Vector2.ZERO
var pan_target: Vector2 = Vector2.ZERO
var follow: bool = true
var zoom: float = 0.85
var t: float = 0.0
var pops: Dictionary = {}
var shakes: Dictionary = {}
var sparks: Array = []
var input_delay: float = 0.2
var dragging: bool = false
var drag_moved: float = 0.0
var tab: String = "all"
var list_box: VBoxContainer
var buy_btn: Button
var tab_btns: Array = []
var canvas: Control

func _ready():
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	focus_mode = Control.FOCUS_ALL
	theme = Style.theme
	_build_side()
	var best = ""
	var bc = 1 << 30
	for n in GameData.BOARD:
		if GameData.board_can_buy(n["id"]) and GameData.board_cost(n["id"]) < bc:
			bc = GameData.board_cost(n["id"])
			best = n["id"]
	if best != "":
		sel = best
	_fit()
	pan = pan_target
	grab_focus()

# ---------------------------------------------------------------------------
# SIDE PANEL (clickable list) + BUY BUTTON
# ---------------------------------------------------------------------------
func _build_side():
	# the graph lives in its own clipped box so nothing spills under the other panels
	canvas = Control.new()
	canvas.position = GRAPH.position
	canvas.size = GRAPH.size
	canvas.clip_contents = true
	canvas.mouse_filter = Control.MOUSE_FILTER_IGNORE
	canvas.draw.connect(func(): _draw_graph(canvas))
	add_child(canvas)
	var tb = HBoxContainer.new()
	tb.position = Vector2(GRAPH.position.x, 74)
	tb.add_theme_constant_override("separation", 6)
	add_child(tb)
	for tdef in TABS:
		var b = Button.new()
		b.text = String(tdef[1])
		b.focus_mode = Control.FOCUS_NONE
		b.custom_minimum_size = Vector2(0, 30)
		b.add_theme_font_size_override("font_size", 13)
		var tid = String(tdef[0])
		b.pressed.connect(func(): _set_tab(tid))
		tb.add_child(b)
		tab_btns.append([tid, b])
	var zb = HBoxContainer.new()
	zb.position = Vector2(GRAPH.end.x - 142, 74)
	zb.add_theme_constant_override("separation", 6)
	add_child(zb)
	for zdef in [["-", -1, 40], ["+", 1, 40], ["FIT", 0, 50]]:
		var b2 = Button.new()
		b2.text = String(zdef[0])
		b2.focus_mode = Control.FOCUS_NONE
		b2.custom_minimum_size = Vector2(float(zdef[2]), 30)
		b2.add_theme_font_size_override("font_size", 14)
		var dz = int(zdef[1])
		b2.pressed.connect(func():
			if dz == 0:
				_fit()
			else:
				_zoom_at(GRAPH.get_center(), 1.2 if dz > 0 else 1.0 / 1.2)
		)
		zb.add_child(b2)
	# fixed-size side panel (a plain Panel, so its contents can't stretch it)
	var side = Panel.new()
	side.position = SIDE.position
	side.size = SIDE.size
	add_child(side)
	var title = Style.label("ALL UPGRADES", 15, Style.GOLD)
	title.position = Vector2(14, 10)
	side.add_child(title)
	var sc = ScrollContainer.new()
	sc.position = Vector2(8, 38)
	sc.size = Vector2(SIDE.size.x - 16, SIDE.size.y - 48)
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	side.add_child(sc)
	list_box = VBoxContainer.new()
	list_box.add_theme_constant_override("separation", 2)
	list_box.custom_minimum_size = Vector2(SIDE.size.x - 32, 0)
	list_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sc.add_child(list_box)
	buy_btn = Button.new()
	buy_btn.focus_mode = Control.FOCUS_NONE
	buy_btn.position = Vector2(INFO.end.x - 196, INFO.position.y + 34)
	buy_btn.custom_minimum_size = Vector2(180, 64)
	buy_btn.add_theme_font_size_override("font_size", 20)
	buy_btn.pressed.connect(_buy)
	add_child(buy_btn)
	_refresh_list()
	_set_tab("all")

func _set_tab(tid: String):
	tab = tid
	for tb in tab_btns:
		var b: Button = tb[1]
		b.add_theme_color_override("font_color", Style.GOLD if tb[0] == tid else Style.CREAM)
	_refresh_list()
	if tid != "all":
		var ids = []
		for n in GameData.BOARD:
			if n["cat"] == tid:
				ids.append(n)
		if not ids.is_empty():
			var c = Vector2.ZERO
			for n in ids:
				c += n["pos"]
			c /= float(ids.size())
			follow = false
			pan_target = -c * SPACING * zoom

func _state_col(id: String) -> Color:
	var n = GameData.board_node(id)
	if GameData.lvl(id) >= int(n["max"]):
		return Color(1.0, 0.85, 0.45)
	if GameData.board_can_buy(id):
		return Color(0.55, 1.0, 0.55)
	if GameData.board_visibility(id) < 2:
		return Color(0.5, 0.48, 0.46)
	return Style.CREAM

func _refresh_list():
	if list_box == null:
		return
	for c in list_box.get_children():
		c.queue_free()
	for n in GameData.BOARD:
		if tab != "all" and n["cat"] != tab and n["cat"] != "core":
			continue
		var id = String(n["id"])
		var b = Button.new()
		b.focus_mode = Control.FOCUS_NONE
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.add_theme_font_size_override("font_size", 12)
		b.custom_minimum_size = Vector2(0, 26)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.clip_text = true
		var l = GameData.lvl(id)
		var mx = int(n["max"])
		var cost_txt = "MAX" if l >= mx else ("%d%s" % [GameData.board_cost(id), " rec" if n["cur"] == "rec" else ""])
		var lock = "" if GameData.board_visibility(id) >= 2 else "[locked] "
		b.text = "%s%s  %d/%d  %s" % [lock, n["name"], l, mx, cost_txt]
		b.add_theme_color_override("font_color", _state_col(id))
		b.pressed.connect(func(): _select(id, true))
		list_box.add_child(b)

func _select(id: String, center_view: bool):
	if sel == id:
		return
	sel = id
	Sfx.play("tick", 1.0, -4.0)
	if center_view:
		follow = true

# ---------------------------------------------------------------------------
# VIEW
# ---------------------------------------------------------------------------
func _node_pos(id: String) -> Vector2:
	var n = GameData.board_node(id)
	if n.is_empty():
		return Vector2.ZERO
	return n["pos"]

func _screen(p: Vector2) -> Vector2:
	return GRAPH.get_center() + pan + p * SPACING * zoom

func _fit():
	var mn = Vector2(1e9, 1e9)
	var mx = Vector2(-1e9, -1e9)
	for n in GameData.BOARD:
		var p: Vector2 = n["pos"]
		mn = Vector2(minf(mn.x, p.x), minf(mn.y, p.y))
		mx = Vector2(maxf(mx.x, p.x), maxf(mx.y, p.y))
	var span = (mx - mn) * SPACING + Vector2(120, 120)
	zoom = clampf(minf(GRAPH.size.x / span.x, GRAPH.size.y / span.y), 0.35, 1.6)
	follow = false
	pan_target = -((mn + mx) * 0.5) * SPACING * zoom

func _zoom_at(screen_pt: Vector2, factor: float):
	var old = zoom
	zoom = clampf(zoom * factor, 0.35, 1.8)
	var world = (screen_pt - GRAPH.get_center() - pan) / (SPACING * old)
	pan = screen_pt - GRAPH.get_center() - world * SPACING * zoom
	pan_target = pan
	follow = false

func _node_at(p: Vector2) -> String:
	if not GRAPH.has_point(p):
		return ""
	for n in GameData.BOARD:
		if _screen(n["pos"]).distance_to(p) < NODE_R * zoom + 6.0:
			return String(n["id"])
	return ""

func _process(delta):
	t += delta
	input_delay -= delta
	if follow:
		pan_target = -_node_pos(sel) * SPACING * zoom
	if not dragging:
		pan = pan.lerp(pan_target, minf(1.0, delta * 7.0))
	for k in pops.keys():
		pops[k] = float(pops[k]) - delta
		if float(pops[k]) <= 0.0:
			pops.erase(k)
	for k in shakes.keys():
		shakes[k] = float(shakes[k]) - delta
		if float(shakes[k]) <= 0.0:
			shakes.erase(k)
	var ks = []
	for s in sparks:
		s["life"] = float(s["life"]) - delta
		if float(s["life"]) > 0.0:
			s["v"] = s["v"] * (1.0 - 2.5 * delta)
			s["p"] = s["p"] + s["v"] * delta
			ks.append(s)
	sparks = ks
	_update_buy_btn()
	queue_redraw()
	if canvas:
		canvas.queue_redraw()

func _update_buy_btn():
	var n = GameData.board_node(sel)
	if n.is_empty():
		return
	var l = GameData.lvl(sel)
	if l >= int(n["max"]):
		buy_btn.text = "MAXED"
		buy_btn.disabled = true
	elif GameData.board_visibility(sel) < 2:
		buy_btn.text = "LOCKED"
		buy_btn.disabled = true
	else:
		buy_btn.text = "BUY  %d %s" % [GameData.board_cost(sel), "REC" if n["cur"] == "rec" else "RP"]
		buy_btn.disabled = not GameData.board_can_buy(sel)

# ---------------------------------------------------------------------------
# INPUT
# ---------------------------------------------------------------------------
func _gui_input(event):
	if input_delay > 0.0:
		return
	if event is InputEventMouseButton:
		var mb: InputEventMouseButton = event
		if mb.button_index == MOUSE_BUTTON_WHEEL_UP and mb.pressed:
			_zoom_at(mb.position, 1.12)
			accept_event()
		elif mb.button_index == MOUSE_BUTTON_WHEEL_DOWN and mb.pressed:
			_zoom_at(mb.position, 1.0 / 1.12)
			accept_event()
		elif mb.button_index == MOUSE_BUTTON_LEFT or mb.button_index == MOUSE_BUTTON_RIGHT or mb.button_index == MOUSE_BUTTON_MIDDLE:
			if mb.pressed:
				dragging = true
				drag_moved = 0.0
			else:
				dragging = false
				if drag_moved < 6.0 and mb.button_index == MOUSE_BUTTON_LEFT:
					var id = _node_at(mb.position)
					if id != "":
						if id == sel:
							_buy()
						else:
							_select(id, false)
				pan_target = pan
			accept_event()
	elif event is InputEventMouseMotion:
		var mm: InputEventMouseMotion = event
		hover = _node_at(mm.position)
		if dragging:
			pan += mm.relative
			pan_target = pan
			drag_moved += mm.relative.length()
			follow = false
		accept_event()
	elif event is InputEventKey:
		_handle_key(event)

func _unhandled_input(event):
	if event is InputEventKey:
		_handle_key(event)

func _handle_key(event):
	if not visible or input_delay > 0.0 or not event.pressed:
		return
	var vp = get_viewport()
	if event.is_action_pressed("ui_cancel") or event.is_action_pressed("pause"):
		vp.set_input_as_handled()
		Sfx.play("select", 0.7)
		closed.emit()
		return
	var dir = Vector2.ZERO
	if event.is_action_pressed("ui_left") or event.is_action_pressed("move_left"):
		dir = Vector2.LEFT
	elif event.is_action_pressed("ui_right") or event.is_action_pressed("move_right"):
		dir = Vector2.RIGHT
	elif event.is_action_pressed("ui_up") or event.is_action_pressed("move_up"):
		dir = Vector2.UP
	elif event.is_action_pressed("ui_down") or event.is_action_pressed("move_down"):
		dir = Vector2.DOWN
	if dir != Vector2.ZERO:
		vp.set_input_as_handled()
		_move_sel(dir)
		return
	if event.is_action_pressed("ui_accept") or event.is_action_pressed("interact"):
		vp.set_input_as_handled()
		_buy()
		return
	if event.is_action_pressed("boon_list") or event.is_action_pressed("ui_focus_next"):
		vp.set_input_as_handled()
		_next_affordable()
		return
	var k: InputEventKey = event
	match k.physical_keycode:
		KEY_EQUAL, KEY_KP_ADD:
			_zoom_at(GRAPH.get_center(), 1.2)
			vp.set_input_as_handled()
		KEY_MINUS, KEY_KP_SUBTRACT:
			_zoom_at(GRAPH.get_center(), 1.0 / 1.2)
			vp.set_input_as_handled()
		KEY_F:
			_fit()
			vp.set_input_as_handled()

func _next_affordable():
	var ids = []
	for n in GameData.BOARD:
		if GameData.board_can_buy(n["id"]):
			ids.append(String(n["id"]))
	if ids.is_empty():
		Sfx.play("error", 1.2, -6.0)
		return
	var i = ids.find(sel)
	_select(String(ids[(i + 1) % ids.size()]), true)

func _move_sel(dir: Vector2):
	var cur = _node_pos(sel)
	var best = ""
	var best_score = 1e9
	for n in GameData.BOARD:
		if n["id"] == sel:
			continue
		var d: Vector2 = n["pos"] - cur
		var dist = d.length()
		if dist < 0.01:
			continue
		var ang = absf(dir.angle_to(d))
		if ang > 1.05:
			continue
		var score = dist * (1.0 + ang * 1.6)
		if score < best_score:
			best_score = score
			best = n["id"]
	if best != "":
		_select(best, true)

func _buy():
	var n = GameData.board_node(sel)
	if n.is_empty():
		return
	if GameData.lvl(sel) >= int(n["max"]) or not GameData.board_buy(sel):
		Sfx.play("error")
		shakes[sel] = 0.3
		return
	pops[sel] = 0.35
	Sfx.play("buy")
	var sp = _screen(_node_pos(sel))
	var col: Color = CAT_COLORS.get(n["cat"], Style.GOLD)
	for i in range(26):
		var a = randf() * TAU
		sparks.append({"p": sp, "v": Vector2(cos(a), sin(a)) * randf_range(80, 320), "life": randf_range(0.4, 0.9), "c": col})
	if GameData.lvl(sel) >= int(n["max"]):
		Sfx.play("jackpot", 1.2, -6.0)
	for m in GameData.BOARD:
		if m["parent"] == sel and GameData.lvl(sel) == 1:
			Sfx.play("levelup", 1.0, -3.0)
			break
	_refresh_list()

# ---------------------------------------------------------------------------
# DRAW
# ---------------------------------------------------------------------------
func _draw():
	draw_rect(Rect2(0, 0, 1280, 720), Color(0.03, 0.025, 0.04, 0.98))
	draw_rect(GRAPH.grow(2), Color(0.9, 0.8, 0.6, 0.12), false, 1.0)
	_draw_header()
	_draw_info()

## Draws the web inside the clipped canvas (absolute screen coords via a transform).
func _draw_graph(ci: Control):
	ci.draw_set_transform(-GRAPH.position, 0.0, Vector2.ONE)
	for i in range(14):
		var y = GRAPH.position.y + i * 40.0 + fmod(pan.y * 0.3, 40.0)
		if y > GRAPH.position.y and y < GRAPH.end.y:
			ci.draw_line(Vector2(GRAPH.position.x, y), Vector2(GRAPH.end.x, y), Color(0.9, 0.8, 0.6, 0.03), 1.0)
	# links
	for n in GameData.BOARD:
		if n["parent"] == "":
			continue
		var a = _screen(_node_pos(n["parent"]))
		var b = _screen(n["pos"])
		var col: Color = CAT_COLORS.get(n["cat"], Style.GOLD)
		if GameData.lvl(n["id"]) > 0:
			ci.draw_line(a, b, Color(col.r, col.g, col.b, 0.85), 4.0 * zoom, true)
			var k = fmod(t * 0.6 + n["pos"].x * 0.13, 1.0)
			ci.draw_circle(a.lerp(b, k), 3.0 * zoom, Color(col.r * 1.5, col.g * 1.5, col.b * 1.5, 0.9))
		elif GameData.lvl(n["parent"]) > 0:
			ci.draw_line(a, b, Color(col.r, col.g, col.b, 0.45), 2.5 * zoom, true)
		else:
			var segs = 10
			for i in range(segs):
				if i % 2 == 0:
					ci.draw_line(a.lerp(b, float(i) / segs), a.lerp(b, float(i + 1) / segs), Color(0.55, 0.55, 0.55, 0.3), 2.0)
	for n in GameData.BOARD:
		_draw_node(ci, n)
	for s in sparks:
		var c: Color = s["c"]
		ci.draw_circle(s["p"], 2.5, Color(c.r * 1.5, c.g * 1.5, c.b * 1.5, float(s["life"])))
	if hover != "" and hover != sel:
		var hn = GameData.board_node(hover)
		var hp = _screen(hn["pos"]) + Vector2(0, -NODE_R * zoom - 16)
		Art.text(ci, hp, String(hn["name"]), 14, Style.CREAM, Style.font_mono, 260.0)
	ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

func _draw_node(ci: CanvasItem, n: Dictionary):
	var id = String(n["id"])
	var p = _screen(n["pos"])
	if shakes.has(id):
		p.x += sin(t * 80.0) * 5.0 * float(shakes[id]) / 0.3
	if not GRAPH.grow(60).has_point(p):
		return
	var col: Color = CAT_COLORS.get(n["cat"], Style.GOLD)
	var l = GameData.lvl(id)
	var mx = int(n["max"])
	var locked = GameData.board_visibility(id) < 2
	var r = NODE_R * zoom
	if pops.has(id):
		r *= 1.0 + float(pops[id]) * 0.8
	if id == hover:
		r *= 1.08
	if id == sel:
		for i in range(8):
			var a0 = t * 1.2 + TAU * float(i) / 8.0
			ci.draw_arc(p, r + 9, a0, a0 + 0.45, 6, Style.GOLD, 3.0, true)
	ci.draw_circle(p, r, Color(0.06, 0.05, 0.07) if not locked else Color(0.09, 0.085, 0.1))
	ci.draw_arc(p, r * 0.8, 0, TAU, 28, Color(0.2, 0.2, 0.22), 1.0, true)
	var lab = col if l > 0 else (col.darkened(0.45) if not locked else col.darkened(0.75))
	ci.draw_circle(p, r * 0.5, lab)
	_draw_icon(ci, id, String(n["cat"]), p, r * 0.34, Color(0.05, 0.04, 0.06) if l > 0 else Color(0.85, 0.85, 0.85, 0.75 if not locked else 0.35))
	if l >= mx:
		ci.draw_arc(p, r + 2, 0, TAU, 32, Color(2.0, 1.6, 0.6), 3.0, true)
	elif l > 0:
		ci.draw_arc(p, r + 2, 0, TAU * float(l) / float(mx), 32, Color(col.r * 1.5, col.g * 1.5, col.b * 1.5), 3.0, true)
	if GameData.board_can_buy(id):
		var pulse = 0.5 + 0.5 * sin(t * 5.0)
		ci.draw_arc(p, r + 5, 0, TAU, 32, Color(0.6, 1.6, 0.6, 0.35 + 0.45 * pulse), 2.0, true)
	if locked:
		var lp = p + Vector2(r * 0.7, -r * 0.7)
		Art.rrect(ci, Rect2(lp.x - 5, lp.y - 2, 10, 8), 2, Color(0.6, 0.55, 0.5))
		ci.draw_arc(lp + Vector2(0, -2), 3.5, PI, TAU, 8, Color(0.6, 0.55, 0.5), 1.5)
	if zoom > 0.6:
		Art.text(ci, p + Vector2(0, r + 16 * zoom + 8), String(n["name"]), int(clampf(11.0 * zoom + 2, 9, 15)), Color(0.85, 0.82, 0.78, 0.9 if not locked else 0.5), Style.font_mono, 160.0)
	if mx > 1:
		for i in range(mx):
			var px = p.x - float(mx - 1) * 4.0 * zoom + i * 8.0 * zoom
			ci.draw_circle(Vector2(px, p.y + r + 6), 2.5 * zoom, col if i < l else Color(0.25, 0.25, 0.28))

func _draw_icon(ci: CanvasItem, id: String, cat: String, c: Vector2, s: float, col: Color):
	if id.begins_with("unlock_") or id == "start_boon":
		ci.draw_circle(c + Vector2(-s * 0.35, 0), s * 0.45, col)
		ci.draw_line(c, c + Vector2(s, 0), col, 3.0)
		ci.draw_line(c + Vector2(s * 0.7, 0), c + Vector2(s * 0.7, s * 0.45), col, 3.0)
		return
	match cat:
		"core":
			Art.star(ci, c, s, s * 0.45, 5, col, 0.0)
		"off":
			Art.poly(ci, [c + Vector2(0, -s), c + Vector2(s * 0.35, -s * 0.2), c + Vector2(0, s), c + Vector2(-s * 0.35, -s * 0.2)], col)
			ci.draw_line(c + Vector2(-s * 0.6, s * 0.35), c + Vector2(s * 0.6, s * 0.35), col, 3.0)
		"def":
			Art.poly(ci, [c + Vector2(-s * 0.8, -s * 0.8), c + Vector2(s * 0.8, -s * 0.8), c + Vector2(s * 0.8, 0), c + Vector2(0, s), c + Vector2(-s * 0.8, 0)], col)
		"mob":
			for i in range(2):
				var ox = (float(i) - 0.5) * s * 0.8
				ci.draw_line(c + Vector2(ox - s * 0.35, -s * 0.6), c + Vector2(ox + s * 0.35, 0), col, 3.0)
				ci.draw_line(c + Vector2(ox + s * 0.35, 0), c + Vector2(ox - s * 0.35, s * 0.6), col, 3.0)
		"luck":
			for i in range(4):
				var a = TAU * float(i) / 4.0 + PI * 0.25
				ci.draw_circle(c + Vector2(cos(a), sin(a)) * s * 0.45, s * 0.42, col)

func _draw_header():
	draw_rect(Rect2(0, 0, 1280, 64), Color(0.02, 0.015, 0.03, 0.95))
	draw_line(Vector2(0, 64), Vector2(1280, 64), Style.GOLD_DIM, 2.0)
	Art.text_left(self, Vector2(22, 44), "THE SETLIST", 32, Style.GOLD, Style.font_title)
	Art.text_left(self, Vector2(GRAPH.position.x, 30), "PERMANENT upgrades - kept through every bow", 15, Style.CREAM, Style.font_body)
	Art.text_left(self, Vector2(GRAPH.position.x, 52), "click: select   click again / ENTER: buy   drag: pan   wheel: zoom   TAB: next   ESC: close", 12, Style.MUTED, Style.font_mono)
	Art.note_glyph(self, Vector2(1000, 26), 10, Style.GOLD)
	Art.text_left(self, Vector2(1016, 34), "%d RP" % GameData.rhythm_points, 20, Style.GOLD, Style.font_mono)
	Art.record_glyph(self, Vector2(1140, 26), 10, t)
	Art.text_left(self, Vector2(1156, 34), "%d" % GameData.gold_records, 20, Style.CREAM, Style.font_mono)
	Art.text_left(self, Vector2(1010, 56), "%d / %d levels bought" % [GameData.board_total_levels(), GameData.board_max_levels()], 12, Style.MUTED, Style.font_mono)

func _draw_info():
	var n = GameData.board_node(sel)
	if n.is_empty():
		return
	var r = INFO
	Art.rrect(self, r, 12, Color(0.05, 0.04, 0.06, 0.97))
	var col: Color = CAT_COLORS.get(n["cat"], Style.GOLD)
	draw_rect(r, Color(col.r, col.g, col.b, 0.7), false, 2.0)
	var l = GameData.lvl(sel)
	var mx = int(n["max"])
	Art.text_left(self, r.position + Vector2(22, 36), String(n["name"]), 26, col, Style.font_title)
	Art.text_left(self, r.position + Vector2(22, 66), String(n["desc"]), 18, Style.CREAM, Style.font_body)
	Art.text_left(self, r.position + Vector2(22, 94), "%s   Lv %d / %d" % [CAT_NAMES.get(n["cat"], ""), l, mx], 14, Style.MUTED, Style.font_mono)
	if GameData.board_visibility(sel) < 2:
		var pn = GameData.board_node(String(n["parent"]))
		Art.text_left(self, r.position + Vector2(22, 118), "LOCKED: buy \"%s\" first (it's the node this one connects from)" % pn.get("name", "?"), 14, Color(1.0, 0.55, 0.5), Style.font_mono)
	elif l < mx:
		var cost = GameData.board_cost(sel)
		var have = GameData.gold_records if n["cur"] == "rec" else GameData.rhythm_points
		var need = cost - have
		if need > 0:
			Art.text_left(self, r.position + Vector2(22, 118), "Need %d more %s" % [need, "Gold Records (beat bosses)" if n["cur"] == "rec" else "RP"], 14, Color(1.0, 0.55, 0.5), Style.font_mono)
		else:
			Art.text_left(self, r.position + Vector2(22, 118), "Affordable!", 14, Color(0.55, 1.0, 0.55), Style.font_mono)
