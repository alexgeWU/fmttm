extends Control

## THE PLAYBILL: the in-lobby index. World lore, every room + reward, the Headliners,
## the four hat empires (bosses), a rogues' gallery of enemies, and every hat part.
## LEFT/RIGHT or click tabs, UP/DOWN or wheel to scroll, ESC to close.

const Art = preload("res://scripts/art.gd")
const BoonData = preload("res://scripts/boon_data.gd")
const WorldData = preload("res://scripts/world_data.gd")

signal closed

const TABS = [["world", "THE WORLD"], ["rooms", "ROOMS & REWARDS"], ["headliners", "HEADLINERS"], ["bosses", "HAT EMPIRES"], ["rogues", "ROGUES' GALLERY"], ["hats", "HATS"]]

var t: float = 0.0
var tab: String = "world"
var tab_btns: Array = []
var scroll: ScrollContainer
var content: VBoxContainer
var icons: Array = []

func _ready():
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	theme = Style.theme
	var dark = ColorRect.new()
	dark.color = Color(0.04, 0.03, 0.03, 0.96)
	dark.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dark.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(dark)
	var title = Style.label("THE PLAYBILL", 34, Style.GOLD, true)
	title.position = Vector2(40, 14)
	add_child(title)
	var sub = Style.label("Everything you'll meet on the way to the Moon", 14, Style.MUTED)
	sub.position = Vector2(310, 30)
	add_child(sub)
	var tb = HBoxContainer.new()
	tb.position = Vector2(40, 66)
	tb.add_theme_constant_override("separation", 8)
	add_child(tb)
	for td in TABS:
		var b = Style.button(String(td[1]), Vector2(0, 38), 15)
		var tid = String(td[0])
		b.pressed.connect(func(): _set_tab(tid))
		b.focus_entered.connect(func():
			if tab != tid:
				_set_tab(tid)
		)
		tb.add_child(b)
		tab_btns.append([tid, b])
	var close = Style.button("CLOSE", Vector2(120, 38), 15)
	close.position = Vector2(1120, 14)
	close.focus_mode = Control.FOCUS_NONE
	close.pressed.connect(func(): closed.emit())
	add_child(close)
	scroll = ScrollContainer.new()
	scroll.position = Vector2(40, 116)
	scroll.size = Vector2(1200, 590)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(scroll)
	content = VBoxContainer.new()
	content.add_theme_constant_override("separation", 10)
	content.custom_minimum_size = Vector2(1180, 0)
	scroll.add_child(content)
	_set_tab("world")
	(tab_btns[0][1] as Button).call_deferred("grab_focus")

func _process(delta):
	t += delta
	for ic in icons:
		if is_instance_valid(ic):
			ic.queue_redraw()

func _unhandled_input(event):
	if not visible:
		return
	if event.is_action_pressed("ui_cancel") or event.is_action_pressed("pause"):
		get_viewport().set_input_as_handled()
		closed.emit()
	elif event.is_action_pressed("ui_down") or event.is_action_pressed("move_down"):
		scroll.scroll_vertical += 80
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("ui_up") or event.is_action_pressed("move_up"):
		scroll.scroll_vertical -= 80
		get_viewport().set_input_as_handled()

func _set_tab(tid: String):
	tab = tid
	for tb in tab_btns:
		(tb[1] as Button).add_theme_color_override("font_color", Style.GOLD if tb[0] == tid else Style.CREAM)
	for c in content.get_children():
		c.queue_free()
	icons.clear()
	scroll.scroll_vertical = 0
	match tid:
		"world": _fill_world()
		"rooms": _fill_rooms()
		"headliners": _fill_headliners()
		"bosses": _fill_bosses()
		"rogues": _fill_rogues()
		"hats": _fill_hats()

# ---------------------------------------------------------------------------
func _row(icon: Control, title: String, title_col: Color, body: String, extra: String = "") -> PanelContainer:
	var p = PanelContainer.new()
	p.add_theme_stylebox_override("panel", Style.panel_box(Color(0.08, 0.06, 0.07, 0.95), Color(title_col.r, title_col.g, title_col.b, 0.45), 2, 10))
	var hb = HBoxContainer.new()
	hb.add_theme_constant_override("separation", 18)
	p.add_child(hb)
	if icon != null:
		hb.add_child(icon)
	var v = VBoxContainer.new()
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hb.add_child(v)
	var tl = Style.label(title, 22, title_col, true)
	tl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(tl)
	var text_w = minf(900.0, 1180.0 - 28.0 - 18.0 - (icon.custom_minimum_size.x if icon != null else 0.0) - 24.0)
	var bl = Style.label(body, 16, Style.CREAM)
	bl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	bl.custom_minimum_size = Vector2(text_w, 0)
	v.add_child(bl)
	if extra != "":
		var el = Style.label(extra, 14, Style.MUTED)
		el.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		el.custom_minimum_size = Vector2(text_w, 0)
		v.add_child(el)
	content.add_child(p)
	return p

func _icon(size_px: Vector2, fn: Callable) -> Control:
	var c = Control.new()
	c.custom_minimum_size = size_px
	c.clip_contents = true
	c.draw.connect(func(): fn.call(c))
	icons.append(c)
	return c

func _header(txt: String):
	var l = Style.label(txt, 18, Style.GOLD)
	content.add_child(l)

# ---------------------------------------------------------------------------
func _fill_world():
	var i = 0
	for e in WorldData.WORLD_LORE:
		var idx = i
		var ic = _icon(Vector2(110, 100), func(c): _world_icon(c, idx))
		_row(ic, String(e[0]), Style.GOLD, String(e[1]))
		i += 1
	_header("THE ROUTE UP")
	for bi in range(WorldData.BIOMES.size()):
		var b = WorldData.BIOMES[bi]
		var bk = String(b["boss"])
		var boss = WorldData.BOSSES[bk]
		var ac: Color = b["accent"]
		var ic2 = _icon(Vector2(110, 100), func(c):
			c.draw_rect(Rect2(0, 0, 110, 100), (b["floor_a"] as Color))
			c.draw_rect(Rect2(0, 0, 110, 30), (b["wall"] as Color))
			Art.text(c, Vector2(55, 70), str(bi + 1), 40, Color(ac.r * 1.4, ac.g * 1.4, ac.b * 1.4), Style.font_title, 110.0)
		)
		_row(ic2, "%d. %s" % [bi + 1, String(b["name"]).to_upper()], ac, String(b["sub"]), "Held by %s.  %d rooms, then the boss." % [boss["empire"], int(b["rooms"])])

func _world_icon(c: Control, i: int):
	var ctr = Vector2(55, 92)
	match i:
		0:
			c.draw_set_transform(ctr, 0.0, Vector2(1.1, 1.1))
			Art.draw_robot(c, t, Vector2.DOWN, false, 0.0, Color(0.45, 0.22, 0.1), GameData.SKINS[1])
			c.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		1:
			Art.glow(c, Vector2(55, 50), 50, Color(1.2, 1.1, 0.7, 0.3), 3)
			c.draw_circle(Vector2(55, 50), 34, Color(1.2, 1.15, 0.9))
			c.draw_circle(Vector2(45, 42), 7, Color(1.0, 0.95, 0.75))
		2:
			var y = 20.0 + fmod(t * 30.0, 50.0)
			Art.top_hat(c, Vector2(55, y + 30), 0.9)
		3:
			Art.patron_portrait(c, "tailor", t, Vector2(55, 100), 0.6)
		4, 5:
			for k in range(3):
				c.draw_set_transform(Vector2(22 + k * 33, 94), 0.0, Vector2(0.75, 0.75))
				Art.draw_robot(c, t + k, Vector2.DOWN, false, 0.0, GameData.SKINS[k]["body"], GameData.SKINS[k])
			c.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		6:
			var pts = [Vector2(15, 80), Vector2(40, 60), Vector2(70, 45), Vector2(95, 20)]
			for k in range(3):
				c.draw_line(pts[k], pts[k + 1], Style.GOLD, 2.0)
			for k in range(4):
				c.draw_circle(pts[k], 7, [Color(1.0, 0.7, 0.35), Color(1.0, 0.3, 0.8), Color(1.0, 0.85, 0.3), Color(0.8, 0.9, 1.2)][k])
		_:
			Art.star(c, Vector2(55, 50), 34, 14, 5, Color(1.8, 1.5, 0.6), t * 0.5)

func _fill_rooms():
	_header("ROOM TYPES")
	for r in WorldData.ROOM_INFO:
		var kind = String(r[0])
		var ic = _icon(Vector2(90, 80), func(c):
			var p = Vector2(45, 40)
			match kind:
				"combat":
					c.draw_line(p + Vector2(-18, -18), p + Vector2(18, 18), Style.CREAM, 5.0)
					c.draw_line(p + Vector2(18, -18), p + Vector2(-18, 18), Style.CREAM, 5.0)
				"elite":
					Art.star(c, p, 22, 9, 5, Color(2.0, 1.5, 0.4), 0.0)
				_:
					Art.reward_icon(c, p, "", "", 22.0, kind, t)
		)
		_row(ic, String(r[1]), Style.GOLD, String(r[2]))
	_header("REWARDS")
	for r in WorldData.REWARD_INFO:
		var kind2 = String(r[0])
		var ic2 = _icon(Vector2(90, 80), func(c): Art.reward_icon(c, Vector2(45, 40), kind2, "luna", 22.0, "", t))
		_row(ic2, String(r[1]), Style.CREAM, String(r[2]))

func _fill_headliners():
	_header("Outsiders who made it to the Moon WITHOUT an empire hat.")
	for pid in BoonData.PATRONS.keys():
		var pd = BoonData.PATRONS[pid]
		var pc: Color = pd["color"]
		var pkey = String(pid)
		var ic = _icon(Vector2(150, 150), func(c):
			Art.glow(c, Vector2(75, 84), 58, Color(pc.r, pc.g, pc.b, 0.3), 4)
			Art.patron_portrait(c, pkey, t, Vector2(75, 146), 0.78)
		)
		var lines = PackedStringArray()
		for id in BoonData.BOONS.keys():
			var bd = BoonData.BOONS[id]
			if bd["patron"] == pid and bd["slot"] != "duo":
				lines.append("%s  %s: %s" % [BoonData.slot_label(String(bd["slot"])), bd["name"], BoonData.boon_desc(id, 0, 1)])
		_row(ic, "%s  -  %s" % [pd["name"], pd["title"]], pc, "%s.  From: %s.\n%s\nSignature effect: %s." % [pd["species"], String(pd["from"]).capitalize(), pd["story"], pd["status"]], "\n".join(lines))
	var duos = PackedStringArray()
	for id in BoonData.BOONS.keys():
		var bd2 = BoonData.BOONS[id]
		if bd2["slot"] == "duo":
			duos.append("%s, %s + %s: %s" % [bd2["name"], BoonData.PATRONS[bd2["patron"]]["name"], BoonData.PATRONS[bd2["patron2"]]["name"], BoonData.boon_desc(id, 4, 1)])
	_row(null, "DUO BOONS", Color(0.75, 1.0, 0.35), "Own a boon from two Headliners and they may offer a Duo.", "\n".join(duos))
	var lp = BoonData.TAILOR
	var loom_ic = _icon(Vector2(150, 150), func(c):
		Art.glow(c, Vector2(75, 84), 58, Color(1.0, 0.8, 0.5, 0.25), 4)
		Art.patron_portrait(c, "tailor", t, Vector2(75, 154), 0.74)
	)
	var mods = PackedStringArray()
	for mk in BoonData.HAT_MODS.keys():
		mods.append("%s: %s" % [BoonData.HAT_MODS[mk]["name"], BoonData.HAT_MODS[mk]["desc"]])
	_row(loom_ic, "%s  -  %s" % [lp["name"], lp["title"]], lp["color"], "%s.  From: %s.\n%s" % [lp["species"], String(lp["from"]).capitalize(), lp["story"]], "HAT MODS\n" + "\n".join(mods))

func _fill_bosses():
	_header("Four hat empires stand between Rust Row and the Moon.")
	for bk in WorldData.BOSSES.keys():
		var b = WorldData.BOSSES[bk]
		var kind = String(bk)
		var ic = _icon(Vector2(170, 170), func(c): Art.boss_portrait(c, kind, t, Vector2(85, 160), 0.72))
		var atk = PackedStringArray()
		var tbl = WorldData.BOSS_ATTACKS.get(bk, {})
		for ak in tbl.keys():
			atk.append("%s: %s" % [tbl[ak][0], tbl[ak][1]])
		_row(ic, "%s  -  %s" % [b["name"], b["empire"]], Color(1.0, 0.5, 0.4), "%s.\n%s\n%s" % [b["title"], b["lore"], b["quote"]], "Home turf: %s.  %s\nATTACKS\n%s" % [b["home"], b["tip"], "\n".join(atk)])

func _fill_rogues():
	for bi in range(WorldData.BIOMES.size()):
		var bio = WorldData.BIOMES[bi]
		_header(String(bio["name"]).to_upper())
		for e in bio["pool"]:
			var ek = String(e[0])
			var ed = WorldData.ENEMIES[ek]
			var ic = _icon(Vector2(100, 100), func(c):
				c.draw_set_transform(Vector2(50, 88), 0.0, Vector2(1.3, 1.3))
				Art.draw_enemy(c, ek, t, Vector2(0.3, 1.0).normalized(), "move" if fmod(t, 3.0) < 2.0 else "wind", 3.0)
				c.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
			)
			_row(ic, String(ed["name"]), (ed["color"] as Color).lightened(0.3), String(ed.get("lore", "")), "Health %d   Damage %d   Style: %s" % [int(ed["hp"]), int(ed["dmg"]), String(ed["beh"]).capitalize()])

func _fill_hats():
	_header("Every hat = crown material + band + add-on, plus a brim.")
	var grade_ic = _icon(Vector2(200, 70), func(c):
		for gi in range(4):
			Art.grade_badge(c, Vector2(26 + gi * 50, 35), GameData.GRADES[gi], GameData.GRADE_COLORS[gi], 20.0)
	)
	_row(grade_ic, "HAT GRADES:  C  B  A  S", Style.GOLD, "A hat is graded on ALL four parts, not its single best one. Common parts score 0, Rare 1 and Legendary 2. Chroma adds 2.", "C = 0-1 points     B = 2-3     A = 4-5     S = 6+.  Loaded Dice on the Setlist makes rare parts more likely.")
	var groups = [
		["CROWN MATERIAL  ->  your SHOWSTOPPER", "crowns/crown_%s.png", BoonData.MAT_KITS, Rect2(14, 4, 100, 84)],
		["BAND  ->  your ATTACK", "bands/band_%s.png", BoonData.BAND_KITS, Rect2(16, 46, 96, 50)],
		["ADD-ON  ->  your SPECIAL", "addons/addon_%s.png", BoonData.ADDON_KITS, Rect2(74, 50, 40, 42)],
	]
	for g in groups:
		_header(String(g[0]))
		var kits: Dictionary = g[2]
		for part in kits.keys():
			var kit = kits[part]
			var path = "res://art/hats/" + (String(g[1]) % part)
			var ic: Control = Control.new()
			ic.custom_minimum_size = Vector2(90, 70)
			if ResourceLoader.exists(path):
				var at = AtlasTexture.new()
				at.atlas = load(path)
				at.region = g[3]
				var tr_ = TextureRect.new()
				tr_.texture = at
				tr_.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
				tr_.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
				tr_.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
				tr_.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
				ic.add_child(tr_)
			var rar = _part_rarity(String(part))
			_row(ic, "%s  -  %s" % [String(part).replace("_", " ").capitalize(), kit["name"]], GameData.get_rarity_color(rar), String(kit["desc"]), GameData.rarity_name(rar))

func _part_rarity(part: String) -> int:
	for r in [0, 1, 2]:
		for m in GameData.MATERIALS[r]:
			if m[0] == part:
				return r
		if part in GameData.BANDS[r] or part in GameData.ADDONS[r]:
			return r
	return 0
