extends Control

## THE HAT-O-MATIC (post-death gacha).
## Three reels = Crown material / Band / Add-on. They stop one by one, then the hat pops out.
## Keep it (or swap it into a full wardrobe), or scrap it for Rhythm Points.

const Art = preload("res://scripts/art.gd")
const BoonData = preload("res://scripts/boon_data.gd")
const FXScript = preload("res://scripts/fx.gd")
const WorldData = preload("res://scripts/world_data.gd")

signal return_to_hub

const MAT_ORDER = ["cardboard", "straw", "tweed", "pinstripe", "felt", "leather", "copper", "titanium", "velvet", "patent_leather"]
const BAND_ORDER = ["cotton", "houndstooth", "pearl_strand", "silk", "spiked", "velvet_ribbon", "brass_rivet", "dynamo", "chrono", "neon_magenta"]
const ADDON_ORDER = ["paperclip", "feather", "horseshoe", "playing_card", "matchstick", "harmonica", "poker_chip", "fuzzy_dice", "golden_coin", "bullet_casing"]
const REEL_SRC = [Rect2(14, 4, 100, 84), Rect2(16, 46, 96, 50), Rect2(74, 50, 40, 42)]
const CELL = 170.0
const MACHINE_POS = Vector2(70, 110)

var reels: Array = []
var t: float = 0.0
var spinning: bool = false
var spin_t: float = 0.0
var lever_t: float = 0.0
var jackpot_t: float = 0.0
var result_hat: Dictionary = {}
var deciding: bool = false
var machine: Control
var side: VBoxContainer
var pull_btn: Button
var done_btn: Button
var fx = null

func _ready():
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	theme = Style.theme
	Sfx.set_music("gacha")
	machine = Control.new()
	machine.position = MACHINE_POS
	machine.size = Vector2(620, 470)
	machine.mouse_filter = Control.MOUSE_FILTER_IGNORE
	machine.draw.connect(_draw_machine)
	add_child(machine)
	var lists = [MAT_ORDER, BAND_ORDER, ADDON_ORDER]
	var layer_prefix = ["res://art/hats/crowns/crown_%s.png", "res://art/hats/bands/band_%s.png", "res://art/hats/addons/addon_%s.png"]
	for i in range(3):
		var rc = Control.new()
		rc.position = Vector2(58 + i * 176, 128)
		rc.size = Vector2(152, CELL)
		rc.clip_contents = true
		rc.mouse_filter = Control.MOUSE_FILTER_IGNORE
		machine.add_child(rc)
		var texs = []
		for nm in lists[i]:
			var path = layer_prefix[i] % nm
			texs.append(load(path) if ResourceLoader.exists(path) else null)
		var reel = {"ctrl": rc, "tex": texs, "names": lists[i], "off": float(randi() % 10), "spin": false, "speed": 0.0, "stop_at": 0.0, "target": 0, "stopping": false, "from": 0.0, "to": 0.0, "k": 0.0, "last_cell": 0}
		reels.append(reel)
		var idx = i
		rc.draw.connect(func(): _draw_reel(idx))
	fx = FXScript.new()
	add_child(fx)
	var sp = PanelContainer.new()
	sp.position = Vector2(740, 96)
	sp.custom_minimum_size = Vector2(480, 520)
	sp.size = Vector2(480, 520)
	add_child(sp)
	side = VBoxContainer.new()
	side.add_theme_constant_override("separation", 8)
	sp.add_child(side)
	var bb = HBoxContainer.new()
	bb.position = Vector2(70, 620)
	bb.size = Vector2(620, 70)
	bb.alignment = BoxContainer.ALIGNMENT_CENTER
	bb.add_theme_constant_override("separation", 20)
	add_child(bb)
	pull_btn = Style.button("PULL THE LEVER", Vector2(280, 64), 24)
	pull_btn.pressed.connect(_pull)
	bb.add_child(pull_btn)
	done_btn = Style.button("BACK TO THE LOUNGE", Vector2(280, 64), 20)
	done_btn.pressed.connect(func():
		if not spinning and not deciding:
			return_to_hub.emit()
	)
	bb.add_child(done_btn)
	_show_summary()
	_refresh_buttons()

func _refresh_buttons():
	pull_btn.text = "PULL  -  %s" % GameData.roll_label()
	pull_btn.disabled = spinning or deciding or not GameData.can_roll()
	done_btn.disabled = spinning or deciding
	if not spinning and not deciding:
		if GameData.can_roll():
			pull_btn.grab_focus()
		else:
			done_btn.grab_focus()

func _unhandled_input(event):
	if event.is_action_pressed("pause") and not spinning and not deciding:
		get_viewport().set_input_as_handled()
		return_to_hub.emit()

func _clear_side():
	for c in side.get_children():
		c.queue_free()

func _show_summary():
	_clear_side()
	var lr = GameData.last_run
	var won = lr.get("won", false)
	var tl = Style.label("ENCORE PERFORMANCE!" if won else "THAT'S SHOWBIZ", 30, Style.GOLD, true)
	side.add_child(tl)
	if lr.is_empty():
		side.add_child(Style.label("Pull the lever to win a new hat.", 17, Style.CREAM))
	else:
		var b = WorldData.biome(int(lr.get("biome", 0)))
		var lines = []
		if won:
			lines.append("You flew all the way to the moon!")
		else:
			lines.append("Knocked out by %s" % String(lr.get("killer", "someone")))
			lines.append("in %s" % String(b["name"]))
		lines.append("")
		lines.append("Rooms cleared:  %d" % int(lr.get("depth", 0)))
		lines.append("Foes knocked out:  %d" % int(lr.get("kills", 0)))
		lines.append("Bosses beaten:  %d" % int(lr.get("bosses", 0)))
		var secs = int(float(lr.get("time", 0.0)))
		lines.append("Time on stage:  %d:%02d" % [int(secs / 60.0), secs % 60])
		for l in lines:
			side.add_child(Style.label(l, 18, Style.CREAM))
		side.add_child(Style.label("+%d Rhythm Points banked" % int(lr.get("rp", 0)), 22, Style.GOLD))
		if int(lr.get("records", 0)) > 0:
			side.add_child(Style.label("+%d Gold Records" % int(lr.get("records", 0)), 20, Color(1.0, 0.85, 0.5)))
	var sp = Control.new()
	sp.custom_minimum_size = Vector2(0, 16)
	side.add_child(sp)
	var rl = Style.label("Free rolls: %d     Next paid roll: %d RP" % [GameData.pending_rolls, GameData.roll_cost()], 18, Color(1.0, 0.6, 0.6))
	side.add_child(rl)
	side.add_child(Style.label("Paid rolls go 50 > 250 > 500 > 1000 RP and reset after every run.", 13, Style.MUTED))
	side.add_child(Style.label("Free rolls: 1 per boss beaten, +1 per Extra Quarter upgrade.", 13, Style.MUTED))
	if int(lr.get("tokens", 0)) > 0:
		side.add_child(Style.label("+%d Stage Tokens (Dressing Room)" % int(lr.get("tokens", 0)), 16, Color(1.0, 0.75, 0.6)))
	side.add_child(Style.label("Reels: Crown  /  Band  /  Add-on", 14, Style.MUTED))

# ---------------------------------------------------------------------------
# SPIN
# ---------------------------------------------------------------------------
func _pull():
	if spinning or deciding:
		return
	if not GameData.consume_roll():
		Sfx.play("error")
		return
	result_hat = GameData.generate_hat()
	var idxs = [MAT_ORDER.find(result_hat["material"]), BAND_ORDER.find(result_hat["band"]), ADDON_ORDER.find(result_hat["addon"])]
	for i in range(3):
		var r = reels[i]
		r["spin"] = true
		r["stopping"] = false
		r["speed"] = 15.0 + i * 2.5
		r["stop_at"] = 1.0 + i * 0.65
		r["target"] = maxi(0, int(idxs[i]))
	spinning = true
	spin_t = 0.0
	lever_t = 0.6
	Sfx.play("lever")
	_clear_side()
	var l = Style.label("Spinning...", 26, Style.GOLD, true)
	side.add_child(l)
	_refresh_buttons()

func _ease_out_back(x: float) -> float:
	var c1 = 1.70158
	var c3 = c1 + 1.0
	return 1.0 + c3 * pow(x - 1.0, 3.0) + c1 * pow(x - 1.0, 2.0)

func _process(delta):
	t += delta
	lever_t = maxf(0.0, lever_t - delta)
	jackpot_t = maxf(0.0, jackpot_t - delta)
	if spinning:
		spin_t += delta
		var all_done = true
		for i in range(3):
			var r = reels[i]
			if not r["spin"]:
				continue
			all_done = false
			if not r["stopping"]:
				r["off"] = float(r["off"]) + float(r["speed"]) * delta
				if spin_t >= float(r["stop_at"]):
					var base = floor(float(r["off"])) + 3.0
					var cur_idx = int(base) % 10
					var add = (int(r["target"]) - cur_idx + 10) % 10
					r["from"] = float(r["off"])
					r["to"] = base + float(add)
					r["k"] = 0.0
					r["stopping"] = true
			else:
				r["k"] = float(r["k"]) + delta / 0.6
				var k = minf(1.0, float(r["k"]))
				r["off"] = lerpf(float(r["from"]), float(r["to"]), _ease_out_back(k))
				if k >= 1.0:
					r["off"] = float(r["to"])
					r["spin"] = false
					Sfx.play("slot_stop", 1.0 + i * 0.1)
					var rc: Control = r["ctrl"]
					fx.burst(MACHINE_POS + rc.position + rc.size * 0.5, Color(1.8, 1.5, 0.7), 14, 200.0, 3.0, "spark", 0.4)
			var cell = int(floor(float(r["off"])))
			if cell != int(r["last_cell"]):
				r["last_cell"] = cell
				Sfx.play("tick", 1.0 + i * 0.15, -8.0)
		if all_done:
			spinning = false
			_reveal()
	for r in reels:
		(r["ctrl"] as Control).queue_redraw()
	machine.queue_redraw()
	queue_redraw()

func _reveal():
	var h = result_hat
	var rar = GameData.hat_grade_index(h)
	var chroma = h.get("is_chroma", false)
	if rar >= 2 or chroma:
		jackpot_t = 3.0
		Sfx.play("jackpot")
		for i in range(5):
			fx.burst(Vector2(randf_range(120, 640), randf_range(120, 420)), Color.from_hsv(randf(), 0.6, 1.8), 28, 320.0, 4.0, "confetti", 1.8)
	elif rar == 1:
		Sfx.play("boon")
		fx.burst(Vector2(380, 300), Color(0.5, 0.8, 1.8), 30, 260.0, 3.0, "confetti", 1.2)
	else:
		Sfx.play("select")
	deciding = true
	_show_result()
	_refresh_buttons()

func _show_result():
	_clear_side()
	var h = result_hat
	var rc = GameData.hat_grade_color(h)
	var top = HBoxContainer.new()
	top.add_theme_constant_override("separation", 10)
	side.add_child(top)
	var hv = Art.make_hat_control(h, 150)
	top.add_child(hv)
	var badge = Art.make_grade_badge(h, 56)
	badge.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	top.add_child(badge)
	var tv = VBoxContainer.new()
	tv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(tv)
	tv.add_child(Style.label(GameData.hat_grade_label(h), 16, rc))
	var nm = Style.label(GameData.hat_name(h), 24, rc, true)
	nm.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	nm.custom_minimum_size = Vector2(270, 0)
	tv.add_child(nm)
	tv.add_child(Style.label("+%d%% damage   +%d health" % [int(GameData.hat_power_pct(h)), GameData.hat_bonus_hp(h)], 16, Style.CREAM))
	var eqh = GameData.get_equipped_hat()
	if not eqh.is_empty():
		tv.add_child(Style.label("vs your equipped hat:", 12, Style.MUTED))
		tv.add_child(_stat_row("Dmg", "", int(GameData.hat_power_pct(h)) - int(GameData.hat_power_pct(eqh)), "%"))
		tv.add_child(_stat_row("HP", "", GameData.hat_bonus_hp(h) - GameData.hat_bonus_hp(eqh), ""))
	var parts = [["Crown", "material"], ["Brim", "brim_material"], ["Band", "band"], ["Add-on", "addon"]]
	var rkeys = ["material_rarity", "brim_rarity", "band_rarity", "addon_rarity"]
	for i in range(4):
		var pr = int(h.get(rkeys[i], 0))
		var l = Style.label("%s: %s (%s)" % [parts[i][0], String(h[parts[i][1]]).replace("_", " ").capitalize(), GameData.rarity_name(pr)], 14, GameData.get_rarity_color(pr))
		side.add_child(l)
	var bk = BoonData.BAND_KITS.get(h["band"], {})
	var ak = BoonData.ADDON_KITS.get(h["addon"], {})
	var mk = BoonData.MAT_KITS.get(h["material"], {})
	for row in [["ATTACK", bk], ["SPECIAL", ak], ["SHOWSTOPPER", mk]]:
		var kit: Dictionary = row[1]
		var l2 = Style.label("%s  %s - %s" % [row[0], kit.get("name", "?"), kit.get("desc", "")], 14, Style.CREAM)
		l2.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l2.custom_minimum_size = Vector2(430, 0)
		side.add_child(l2)
	var hb = HBoxContainer.new()
	hb.add_theme_constant_override("separation", 12)
	side.add_child(hb)
	var full = GameData.roster.size() >= GameData.max_roster()
	var keep = Style.button("SWAP INTO WARDROBE" if full else "KEEP IT", Vector2(220, 50), 18)
	keep.pressed.connect(func():
		if full:
			_show_replace()
		else:
			GameData.roster.append(result_hat)
			GameData.save_game()
			Sfx.play("buy")
			_finish("Saved to the Wardrobe!")
	)
	hb.add_child(keep)
	var val = GameData.scrap_value(h)
	var scrap = Style.button("SCRAP  +%d RP" % val, Vector2(200, 50), 16)
	scrap.pressed.connect(func():
		GameData.rhythm_points += val
		GameData.save_game()
		Sfx.play("coin")
		_finish("Scrapped for %d RP." % val)
	)
	hb.add_child(scrap)
	keep.call_deferred("grab_focus")

func _show_replace():
	# Full-screen comparison: the new hat vs every hat in the wardrobe.
	_clear_side()
	var ov = Control.new()
	ov.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	ov.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(ov)
	var dark = ColorRect.new()
	dark.color = Color(0.02, 0.01, 0.03, 0.95)
	dark.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	ov.add_child(dark)
	var root = VBoxContainer.new()
	root.position = Vector2(30, 24)
	root.size = Vector2(1220, 670)
	root.add_theme_constant_override("separation", 10)
	ov.add_child(root)
	var tl = Style.label("WARDROBE FULL  -  WHICH HAT GOES?", 30, Style.GOLD, true)
	tl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	root.add_child(tl)
	var sub = Style.label("Green = the NEW hat is better than that one.  Red = you'd lose stats.  Replaced hats are scrapped for RP.", 14, Style.MUTED)
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	root.add_child(sub)
	var row = HBoxContainer.new()
	row.add_theme_constant_override("separation", 16)
	row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(row)
	# the new hat
	var nc = _hat_card(result_hat, {}, "NEW HAT")
	row.add_child(nc)
	var vs = Style.label("VS", 30, Color(1.0, 0.5, 0.5), true)
	vs.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(vs)
	var scroll = ScrollContainer.new()
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.follow_focus = true
	row.add_child(scroll)
	var hb = HBoxContainer.new()
	hb.add_theme_constant_override("separation", 12)
	scroll.add_child(hb)
	var first: Button = null
	for i in range(GameData.roster.size()):
		var h = GameData.roster[i]
		var tag = "EQUIPPED" if i == GameData.equipped_hat_index else "SLOT %d" % (i + 1)
		var card = _hat_card(h, result_hat, tag)
		hb.add_child(card)
		var b = Style.button("REPLACE  (+%d RP)" % GameData.scrap_value(h), Vector2(0, 42), 15)
		var idx = i
		b.pressed.connect(func():
			GameData.rhythm_points += GameData.scrap_value(GameData.roster[idx])
			GameData.roster[idx] = result_hat
			GameData.save_game()
			Sfx.play("buy")
			ov.queue_free()
			_finish("Swapped into the Wardrobe!")
		)
		card.get_child(0).add_child(b)
		if first == null:
			first = b
	var cancel = Style.button("KEEP MY HATS (back)", Vector2(260, 44), 16)
	cancel.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	cancel.pressed.connect(func():
		ov.queue_free()
		_show_result()
	)
	root.add_child(cancel)
	if first != null:
		first.call_deferred("grab_focus")

## A compact hat card. If `compare_to` is given, each stat shows how the
## compared (new) hat differs from THIS hat.
func _hat_card(h: Dictionary, compare_to: Dictionary, tag: String) -> PanelContainer:
	var rc = GameData.hat_grade_color(h)
	var p = PanelContainer.new()
	p.custom_minimum_size = Vector2(250, 540)
	p.add_theme_stylebox_override("panel", Style.panel_box(Color(0.07, 0.05, 0.08, 0.98), rc, 3 if compare_to.is_empty() else 2, 12))
	var v = VBoxContainer.new()
	v.add_theme_constant_override("separation", 5)
	p.add_child(v)
	var tg = Style.label(tag, 13, Color(1.0, 0.6, 0.5) if compare_to.is_empty() else Style.MUTED)
	tg.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(tg)
	var hv = Art.make_hat_control(h, 120)
	hv.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	v.add_child(hv)
	var nm = Style.label(GameData.hat_name(h), 17, rc, true)
	nm.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	nm.custom_minimum_size = Vector2(220, 0)
	nm.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(nm)
	var rl = Style.label(GameData.hat_grade_label(h), 14, rc)
	rl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(rl)
	var dmg = int(GameData.hat_power_pct(h))
	var hp = GameData.hat_bonus_hp(h)
	v.add_child(_stat_row("Damage", "+%d%%" % dmg, 0 if compare_to.is_empty() else int(GameData.hat_power_pct(compare_to)) - dmg, "%"))
	v.add_child(_stat_row("Health", "+%d" % hp, 0 if compare_to.is_empty() else GameData.hat_bonus_hp(compare_to) - hp, ""))
	var kits = [["J", BoonData.BAND_KITS, "band"], ["K", BoonData.ADDON_KITS, "addon"], ["L", BoonData.MAT_KITS, "material"]]
	for k in kits:
		var table: Dictionary = k[1]
		var kit: Dictionary = table.get(h.get(k[2], ""), {})
		var txt = "%s  %s" % [k[0], kit.get("name", "?")]
		var col = Style.CREAM
		if not compare_to.is_empty():
			var other: Dictionary = table.get(compare_to.get(k[2], ""), {})
			if other.get("name", "") != kit.get("name", ""):
				txt += "\n     new: " + String(other.get("name", "?"))
				col = Color(1.0, 0.85, 0.5)
		var kl = Style.label(txt, 13, col)
		kl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		kl.custom_minimum_size = Vector2(220, 0)
		v.add_child(kl)
	var sp = Control.new()
	sp.size_flags_vertical = Control.SIZE_EXPAND_FILL
	v.add_child(sp)
	return p

func _stat_row(label: String, value: String, delta: int, unit: String) -> HBoxContainer:
	var hb = HBoxContainer.new()
	hb.add_theme_constant_override("separation", 8)
	hb.add_child(Style.label(label, 14, Style.MUTED))
	hb.add_child(Style.label(value, 16, Style.CREAM))
	if delta == 0 and value == "":
		hb.add_child(Style.label("same", 14, Style.MUTED))
	elif delta != 0:
		var good = delta > 0
		var dl = Style.label(("new %s%d%s" % ["+" if good else "", delta, unit]), 14, Color(0.45, 1.0, 0.5) if good else Color(1.0, 0.4, 0.4))
		hb.add_child(dl)
	return hb

func _finish(msg: String):
	deciding = false
	_clear_side()
	side.add_child(Style.label(msg, 24, Style.GOLD, true))
	var hv = Art.make_hat_control(result_hat, 180)
	hv.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	side.add_child(hv)
	side.add_child(Style.label("Next roll: %s   (you have %d RP)" % [GameData.roll_label(), GameData.rhythm_points], 17, Color(1.0, 0.6, 0.6)))
	if not GameData.can_roll():
		side.add_child(Style.label("Head back to the lounge and spend your RP on the Setlist.", 15, Style.MUTED))
	_refresh_buttons()

# ---------------------------------------------------------------------------
# DRAWING
# ---------------------------------------------------------------------------
func _draw():
	draw_rect(Rect2(0, 0, 1280, 720), Color(0.05, 0.02, 0.04))
	for i in range(14):
		var a = float(i) / 14.0
		draw_rect(Rect2(0, 720 - i * 52, 1280, 52), Color(0.25, 0.03, 0.06, 0.05 + a * 0.02))
	for sx in [380.0, 980.0]:
		draw_colored_polygon(PackedVector2Array([Vector2(sx - 20, 0), Vector2(sx + 20, 0), Vector2(sx + 220, 720), Vector2(sx - 220, 720)]), Color(1.0, 0.85, 0.6, 0.035))

func _draw_machine():
	var c = machine
	var W = c.size.x
	var H = c.size.y
	Art.rrect(c, Rect2(-10, -10, W + 20, H + 20), 26, Color(0.1, 0.1, 0.12))
	Art.rrect(c, Rect2(0, 0, W, H), 22, Color(0.62, 0.07, 0.12))
	Art.rrect(c, Rect2(14, 14, W - 28, 70), 14, Color(0.2, 0.02, 0.05))
	# marquee sign lives on the cabinet now
	var tc = Color.from_hsv(fmod(t * 0.3, 1.0), 0.6, 2.0) if jackpot_t > 0.0 else Color(2.0, 0.5, 0.7)
	Art.glow(c, Vector2(W * 0.5, 49), 60.0, Color(tc.r, tc.g, tc.b, 0.12), 2)
	Art.text(c, Vector2(W * 0.5, 64), "THE HAT-O-MATIC", 40, tc, Style.font_title, W - 40)
	# chasing bulbs around the cabinet
	var n = 40
	for i in range(n):
		var k = float(i) / float(n)
		var p = Vector2.ZERO
		var per = 2.0 * (W + H)
		var d = k * per
		if d < W:
			p = Vector2(d, 0)
		elif d < W + H:
			p = Vector2(W, d - W)
		elif d < 2.0 * W + H:
			p = Vector2(W - (d - W - H), H)
		else:
			p = Vector2(0, H - (d - 2.0 * W - H))
		var speed = 26.0 if jackpot_t > 0.0 else 7.0
		var on = int(t * speed + i) % 3 == 0
		if jackpot_t > 0.0:
			on = int(t * speed + i) % 2 == 0
		c.draw_circle(p, 5, Color(2.2, 1.8, 0.7) if on else Color(0.6, 0.45, 0.2))
	# reel windows
	for i in range(3):
		var rr = Rect2(50 + i * 176, 120, 168, CELL + 16)
		Art.rrect(c, rr, 8, Color(0.85, 0.8, 0.7))
		Art.rrect(c, rr.grow(-5), 6, Color(0.96, 0.94, 0.9))
	c.draw_line(Vector2(40, 120 + CELL * 0.5 + 8), Vector2(W - 40, 120 + CELL * 0.5 + 8), Color(1.6, 0.3, 0.3, 0.6), 2.0)
	# labels
	var labs = ["CROWN", "BAND", "ADD-ON"]
	for i in range(3):
		Art.text(c, Vector2(134 + i * 176, 336), labs[i], 14, Style.GOLD, Style.font_mono, 160.0)
	# coin slot + tray
	Art.rrect(c, Rect2(W * 0.5 - 30, 360, 60, 14), 4, Color(0.1, 0.1, 0.1))
	Art.rrect(c, Rect2(60, 400, W - 120, 46), 10, Color(0.25, 0.02, 0.05))
	# lever
	var lk = 0.0
	if lever_t > 0.0:
		lk = sin((1.0 - lever_t / 0.6) * PI)
	var base = Vector2(W + 14, 190)
	Art.rrect(c, Rect2(W, 170, 24, 50), 6, Color(0.7, 0.7, 0.75))
	var tip = base + Vector2(18, -120 + 150 * lk)
	c.draw_line(base, tip, Color(0.85, 0.85, 0.9), 7.0)
	c.draw_circle(tip, 16, Color(0.9, 0.1, 0.12))
	c.draw_circle(tip + Vector2(-5, -5), 5, Color(1.6, 0.6, 0.6))

func _draw_reel(i: int):
	var r = reels[i]
	var rc: Control = r["ctrl"]
	var off = float(r["off"])
	var texs: Array = r["tex"]
	var src: Rect2 = REEL_SRC[i]
	var blur = r["spin"] and not r["stopping"]
	var base = int(floor(off))
	for j in range(base - 1, base + 3):
		var idx = ((j % 10) + 10) % 10
		var y = (float(j) - off) * CELL
		var tex = texs[idx]
		if tex == null:
			continue
		var aspect = src.size.x / src.size.y
		var h = 118.0 if i == 0 else (74.0 if i == 1 else 110.0)
		var w = h * aspect
		if w > 140.0:
			w = 140.0
			h = w / aspect
		var dest = Rect2(rc.size.x * 0.5 - w * 0.5, y + CELL * 0.5 - h * 0.5, w, h)
		if blur:
			dest = Rect2(dest.position.x, dest.position.y - 14, dest.size.x, dest.size.y + 28)
		rc.draw_texture_rect_region(tex, dest, src, Color(1, 1, 1, 0.6 if blur else 1.0))
	# glass shading
	rc.draw_rect(Rect2(0, 0, rc.size.x, 26), Color(0, 0, 0, 0.18))
	rc.draw_rect(Rect2(0, rc.size.y - 26, rc.size.x, 26), Color(0, 0, 0, 0.18))
	if not r["spin"] and not result_hat.is_empty():
		var names: Array = r["names"]
		var nm = String(names[((base % 10) + 10) % 10]).replace("_", " ").to_upper()
		Art.text(rc, Vector2(rc.size.x * 0.5, rc.size.y - 8), nm, 12, Color(0.3, 0.1, 0.1), Style.font_mono, rc.size.x, false)
