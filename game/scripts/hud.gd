extends Control

## HUD: health, currencies, room tracker, ability cooldowns, boons, boss bar, banners.

const Art = preload("res://scripts/art.gd")
const BoonData = preload("res://scripts/boon_data.gd")
const WorldData = preload("res://scripts/world_data.gd")

var room = null
var t: float = 0.0
var shown_rp: float = 0.0
var shown_chips: float = 0.0
var hurt_flash: float = 0.0
var banners: Array = []
var title_card: Dictionary = {}
var prompt_text: String = ""
var prompt_pos: Vector2 = Vector2.ZERO
var callout: Dictionary = {}
var boss_tip: String = ""
var boss_tip_t: float = 0.0
var boss_fight_t: float = 0.0
const BOSS_HINT_SECS = 5.0
var hint_text: String = ""
var hint_t: float = 0.0
var bintro: Dictionary = {}
var say_text: String = ""
var say_pos: Vector2 = Vector2.ZERO
var say_t: float = 0.0

func _ready():
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

func banner(text: String, col: Color, dur: float = 1.6, size: int = 40):
	banners.append({"text": text, "c": col, "t": 0.0, "dur": dur, "size": size})

func show_title(title: String, sub: String, dur: float = 3.0):
	title_card = {"title": title, "sub": sub, "t": 0.0, "dur": dur}

func say(text: String, pos: Vector2, dur: float = 4.0):
	say_text = text
	say_pos = pos
	say_t = dur

func boss_intro(kind: String):
	bintro = {"kind": kind, "t": 0.0, "dur": 3.6}

func hint(text: String, dur: float = 8.0):
	hint_text = text
	hint_t = dur

func flash_hurt():
	hurt_flash = 1.0

func _process(delta):
	t += delta
	hurt_flash = maxf(0.0, hurt_flash - delta * 2.5)
	var run = GameData.run
	shown_rp = move_toward(shown_rp, float(run.get("rp", 0)), maxf(1.0, absf(float(run.get("rp", 0)) - shown_rp) * delta * 6.0))
	shown_chips = move_toward(shown_chips, float(run.get("chips", 0)), maxf(1.0, absf(float(run.get("chips", 0)) - shown_chips) * delta * 6.0))
	var kb = []
	for b in banners:
		b["t"] = float(b["t"]) + delta
		if float(b["t"]) < float(b["dur"]):
			kb.append(b)
	banners = kb
	if not callout.is_empty():
		callout["t"] = float(callout["t"]) + delta
		if float(callout["t"]) > 2.4:
			callout = {}
	boss_tip_t -= delta
	hint_t -= delta
	say_t -= delta
	# how long the boss fight has actually been running (hints fade after BOSS_HINT_SECS)
	if room != null and room.boss != null and is_instance_valid(room.boss) and not room.boss.dead:
		if room.boss.state != "intro":
			boss_fight_t += delta
	else:
		boss_fight_t = 0.0
	if not bintro.is_empty():
		bintro["t"] = float(bintro["t"]) + delta
		if float(bintro["t"]) > float(bintro["dur"]):
			bintro = {}
	if not title_card.is_empty():
		title_card["t"] = float(title_card["t"]) + delta
		if float(title_card["t"]) > float(title_card["dur"]):
			title_card = {}
	queue_redraw()

func _draw():
	if room == null:
		return
	var p = room.player
	if p == null:
		return
	var run = GameData.run
	# --- vignette / hurt ---
	var low = p.hp / maxf(1.0, p.max_hp) < 0.3 and p.alive
	var va = hurt_flash * 0.45 + (0.12 + 0.08 * sin(t * 6.0) if low else 0.0)
	if va > 0.01:
		for i in range(10):
			var a = va * (1.0 - float(i) / 10.0)
			var w = 8.0 + i * 8.0
			draw_rect(Rect2(0, 0, 1280, w * 0.5), Color(0.8, 0.0, 0.05, a * 0.25))
			draw_rect(Rect2(0, 720 - w * 0.5, 1280, w * 0.5), Color(0.8, 0.0, 0.05, a * 0.25))
			draw_rect(Rect2(0, 0, w * 0.5, 720), Color(0.8, 0.0, 0.05, a * 0.25))
			draw_rect(Rect2(1280 - w * 0.5, 0, w * 0.5, 720), Color(0.8, 0.0, 0.05, a * 0.25))
	# --- health panel ---
	Art.rrect(self, Rect2(12, 10, 318, 74), 10, Color(0.04, 0.03, 0.05, 0.82))
	draw_rect(Rect2(12, 10, 318, 74), Color(Style.GOLD_DIM.r, Style.GOLD_DIM.g, Style.GOLD_DIM.b, 0.8), false, 2.0)
	var hr = clampf(p.hp / maxf(1.0, p.max_hp), 0.0, 1.0)
	Art.rrect(self, Rect2(24, 22, 240, 18), 5, Color(0.15, 0.02, 0.03))
	if hr > 0.0:
		Art.rrect(self, Rect2(24, 22, 240 * hr, 18), 5, Color(0.85, 0.12, 0.18))
		draw_rect(Rect2(28, 24, maxf(0.0, 240 * hr - 8), 4), Color(1, 0.5, 0.5, 0.35))
	Art.text_left(self, Vector2(30, 37), "%d / %d" % [int(ceil(p.hp)), int(p.max_hp)], 14, Style.CREAM, Style.font_mono)
	# shield + curtain calls
	var ix = 272.0
	if p.shield > 0:
		draw_circle(Vector2(ix + 8, 31), 8, Color(0.4, 0.8, 1.4, 0.8))
		ix += 20
	for i in range(int(run.get("defiance", 0))):
		Art.rrect(self, Rect2(ix, 24, 12, 11), 1, Color(0.1, 0.08, 0.1))
		draw_rect(Rect2(ix - 3, 34, 18, 3), Color(0.1, 0.08, 0.1))
		draw_rect(Rect2(ix, 31, 12, 2), Color(0.8, 0.1, 0.2))
		ix += 20
	# currencies
	Art.note_glyph(self, Vector2(34, 64), 10, Style.GOLD)
	Art.text_left(self, Vector2(50, 71), str(int(shown_rp)), 18, Style.GOLD, Style.font_mono)
	Art.chip_glyph(self, Vector2(140, 63), 8, Color(0.8, 0.12, 0.15))
	Art.text_left(self, Vector2(154, 71), str(int(shown_chips)), 18, Color(1.0, 0.75, 0.7), Style.font_mono)
	if int(run.get("records", 0)) > 0:
		Art.record_glyph(self, Vector2(236, 63), 9, t)
		Art.text_left(self, Vector2(250, 71), str(int(run.get("records", 0))), 18, Style.CREAM, Style.font_mono)
	# --- room tracker (top centre) ---
	var b = WorldData.biome(int(run.get("biome", 0)))
	if room.boss == null or not is_instance_valid(room.boss) or room.boss.dead:
		Art.text(self, Vector2(640, 28), String(b["name"]).to_upper(), 18, Style.GOLD, Style.font_title, 500.0)
		var rooms = int(b["rooms"])
		var cur = int(run.get("room", 0))
		var sx = 640.0 - (rooms + 1) * 11.0
		for i in range(rooms + 1):
			var pos = Vector2(sx + i * 22.0 + 11.0, 44)
			if i == rooms:
				Art.star(self, pos, 8, 3.5, 5, Color(1.0, 0.3, 0.3) if cur >= rooms else Color(0.6, 0.2, 0.2), 0.0)
			elif i < cur:
				draw_circle(pos, 5, Style.GOLD)
			elif i == cur:
				draw_circle(pos, 6, Style.CREAM)
				draw_arc(pos, 9, 0, TAU, 16, Color(1, 1, 1, 0.5 + 0.3 * sin(t * 4.0)), 1.5)
			else:
				draw_arc(pos, 5, 0, TAU, 12, Color(0.6, 0.55, 0.5), 1.5)
	else:
		_draw_boss_bar(room.boss)
	# --- boss attack callouts + tells ---
	if room.boss != null and is_instance_valid(room.boss) and not room.boss.dead:
		if not callout.is_empty():
			var ck = float(callout["t"]) / 2.4
			var ca = minf(1.0, minf(ck * 10.0, (1.0 - ck) * 4.0))
			var pop = 1.0 + maxf(0.0, 0.1 - ck) * 3.0
			Art.text(self, Vector2(640, 118), String(callout["name"]), int(30 * pop), Color(1.0, 0.45, 0.35, ca), Style.font_title, 900.0)
			if boss_fight_t < BOSS_HINT_SECS:
				var hint_a = ca * clampf(BOSS_HINT_SECS - boss_fight_t, 0.0, 1.0)
				Art.text(self, Vector2(640, 142), String(callout["hint"]), 16, Color(1.0, 0.92, 0.8, hint_a), Style.font_body, 900.0)
		if boss_tip_t > 0.0 and boss_tip != "" and boss_fight_t < BOSS_HINT_SECS:
			var ta = minf(minf(1.0, boss_tip_t), BOSS_HINT_SECS - boss_fight_t)
			var tw_ = Style.font_body.get_string_size(boss_tip, HORIZONTAL_ALIGNMENT_LEFT, -1, 15).x + 36.0
			var tip_r = Rect2(640 - tw_ * 0.5, 596, tw_, 34)
			Art.rrect(self, tip_r, 8, Color(0.05, 0.03, 0.05, 0.85 * ta))
			draw_rect(tip_r, Color(1.0, 0.5, 0.4, 0.6 * ta), false, 1.5)
			Art.text(self, Vector2(640, 618), boss_tip, 15, Color(1.0, 0.9, 0.8, ta), Style.font_body, tw_)
	# --- abilities (bottom left) ---
	var slots_info = [
		["J", "ATTACK", 0.0, 1.0, "attack"],
		["K", "SPECIAL", p.special_cd, p.special_cd_max, "special"],
		["L", "SHOW", p.cast_cd, p.cast_cd_max, "cast"],
		["SPC", "DASH", 0.0, 1.0, "dash"],
	]
	for i in range(4):
		var s = slots_info[i]
		var c = Vector2(46 + i * 70, 668)
		var col: Color = p.slot_color(String(s[4]))
		draw_circle(c, 26, Color(0.04, 0.03, 0.05, 0.85))
		draw_arc(c, 26, 0, TAU, 32, Color(col.r, col.g, col.b, 0.9), 2.5, true)
		var cd = float(s[2])
		var cdm = maxf(0.01, float(s[3]))
		if cd > 0.0:
			var k = clampf(cd / cdm, 0.0, 1.0)
			var pts = PackedVector2Array([c])
			for j in range(25):
				var a = -PI * 0.5 + TAU * k * float(j) / 24.0
				pts.append(c + Vector2(cos(a), sin(a)) * 24.0)
			if k > 0.02 and k < 0.995:
				draw_colored_polygon(pts, Color(0, 0, 0, 0.65))
			elif k >= 0.995:
				draw_circle(c, 24.0, Color(0, 0, 0, 0.65))
			Art.text(self, c + Vector2(0, 6), "%.1f" % cd, 14, Style.CREAM, Style.font_mono, 60.0)
		else:
			_ability_icon(i, c, col)
		Art.text(self, c + Vector2(0, 42), String(s[0]), 11, Style.MUTED, Style.font_mono, 60.0)
		if i == 3:
			for j in range(p.dash_max):
				var dp = c + Vector2(-float(p.dash_max - 1) * 6.0 + j * 12.0, -32)
				draw_circle(dp, 4, Color(0.5, 1.0, 1.4) if j < p.dash_charges else Color(0.2, 0.25, 0.3))
	# --- boons (bottom right) ---
	var bx = 1250.0
	var by = 680.0
	var n = 0
	for id in p.boons.keys():
		var bd = BoonData.BOONS[id]
		var pc: Color = BoonData.PATRONS[bd["patron"]]["color"]
		var pos2 = Vector2(bx - (n % 10) * 30.0, by - 6.0 - int(n / 10.0) * 38.0)
		draw_circle(pos2, 12, Color(0.04, 0.03, 0.05, 0.9))
		draw_arc(pos2, 12, 0, TAU, 20, pc, 2.0, true)
		var letter = String(bd["slot"]).substr(0, 1).to_upper()
		if bd["slot"] == "duo":
			letter = "*"
		Art.text(self, pos2 + Vector2(0, 5), letter, 13, pc, Style.font_mono, 30.0, false)
		var lv = int(p.boons[id]["level"])
		for li in range(BoonData.MAX_LEVEL):
			var pp2 = pos2 + Vector2(-6.0 + li * 6.0, 16)
			draw_circle(pp2, 2.2, Style.GOLD if li < lv else Color(0.25, 0.25, 0.28))
		n += 1
	if n > 0:
		Art.text(self, Vector2(1180, by - 24 - int((n - 1) / 10.0) * 30.0), "TAB  boons (this run)", 11, Style.MUTED, Style.font_mono, 200.0)
	# --- interact prompt ---
	if prompt_text != "":
		var w = Style.font_body.get_string_size(prompt_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 16).x + 28.0
		var pr = Rect2(prompt_pos.x - w * 0.5, prompt_pos.y - 22, w, 30)
		Art.rrect(self, pr, 8, Color(0.04, 0.03, 0.05, 0.9))
		draw_rect(pr, Style.GOLD_DIM, false, 1.5)
		Art.text(self, Vector2(prompt_pos.x, prompt_pos.y - 1), prompt_text, 16, Style.CREAM, null, w)
	# --- Headliner speech bubble ---
	if say_t > 0.0 and say_text != "":
		var sa = minf(1.0, say_t * 2.0)
		var sw = minf(520.0, Style.font_body.get_string_size(say_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 15).x + 28.0)
		var two = Style.font_body.get_string_size(say_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 15).x > 492.0
		var sh_ = 48.0 if two else 30.0
		var left_side = say_pos.x < 640.0
		var sx = say_pos.x + 64.0 if left_side else say_pos.x - 64.0 - sw
		sx = clampf(sx, 8.0, 1272.0 - sw)
		var sy = maxf(90.0, say_pos.y - sh_ * 0.5)
		var srect = Rect2(sx, sy, sw, sh_)
		Art.rrect(self, srect, 10, Color(0.95, 0.92, 0.85, 0.95 * sa))
		var tip_x = sx if left_side else sx + sw
		Art.poly(self, [Vector2(tip_x, sy + sh_ * 0.5 - 7), Vector2(tip_x, sy + sh_ * 0.5 + 7), Vector2(say_pos.x + (40.0 if left_side else -40.0), say_pos.y)], Color(0.95, 0.92, 0.85, 0.95 * sa))
		draw_multiline_string(Style.font_body, Vector2(sx + 14, sy + 20), say_text, HORIZONTAL_ALIGNMENT_LEFT, sw - 24, 15, 2, Color(0.1, 0.06, 0.05, sa))
	# --- tutorial hint ---
	if hint_t > 0.0 and hint_text != "":
		var ha = minf(1.0, hint_t * 1.5)
		var lines = hint_text.split("\n")
		var hw = 0.0
		for ln in lines:
			hw = maxf(hw, Style.font_body.get_string_size(ln, HORIZONTAL_ALIGNMENT_LEFT, -1, 17).x)
		hw += 60.0
		var hh = 22.0 * lines.size() + 20.0
		var hr2 = Rect2(640 - hw * 0.5, 548 - hh, hw, hh)
		Art.rrect(self, hr2, 10, Color(0.04, 0.03, 0.06, 0.9 * ha))
		draw_rect(hr2, Color(0.5, 0.9, 1.0, 0.7 * ha), false, 2.0)
		Art.text_left(self, hr2.position + Vector2(12, 22), "TIP", 12, Color(0.5, 0.9, 1.0, ha), Style.font_mono)
		for li in range(lines.size()):
			Art.text(self, Vector2(640 + 12, hr2.position.y + 30 + li * 22), lines[li], 17, Color(1, 0.95, 0.85, ha), Style.font_body, hw)
	# --- banners ---
	var yb = 250.0
	for bn in banners:
		var k2 = float(bn["t"]) / float(bn["dur"])
		var a2 = minf(1.0, minf(k2 * 8.0, (1.0 - k2) * 4.0))
		var sc = 1.0 + maxf(0.0, 0.15 - k2) * 2.0
		var c2: Color = bn["c"]
		c2.a = a2
		Art.text(self, Vector2(640, yb), String(bn["text"]), int(float(bn["size"]) * sc), c2, Style.font_title, 1200.0)
		yb += float(bn["size"]) + 10.0
	# --- boss introduction splash ---
	if not bintro.is_empty():
		var bk = float(bintro["t"]) / float(bintro["dur"])
		var ba = minf(1.0, minf(bk * 6.0, (1.0 - bk) * 5.0))
		var bars = 90.0 * minf(1.0, bk * 8.0) * minf(1.0, (1.0 - bk) * 8.0)
		draw_rect(Rect2(0, 0, 1280, bars), Color(0, 0, 0, 0.95))
		draw_rect(Rect2(0, 720 - bars, 1280, bars), Color(0, 0, 0, 0.95))
		draw_rect(Rect2(0, 250, 1280, 230), Color(0.02, 0.01, 0.03, 0.75 * ba))
		var bd = WorldData.BOSSES.get(String(bintro["kind"]), {})
		var slide = 1.0 - pow(1.0 - minf(1.0, bk * 3.0), 3.0)
		Art.boss_portrait(self, String(bintro["kind"]), t, Vector2(lerpf(-200.0, 260.0, slide), 470), 1.1)
		Art.text_left(self, Vector2(470, 300), "HAT EMPIRE:  " + String(bd.get("empire", "")).to_upper(), 16, Color(1.0, 0.6, 0.45, ba), Style.font_mono)
		Art.text_left(self, Vector2(466, 372), String(bd.get("name", "")), 64, Color(1.0, 0.92, 0.75, ba), Style.font_title)
		Art.text_left(self, Vector2(470, 408), String(bd.get("title", "")), 18, Color(0.9, 0.85, 0.75, ba), Style.font_body)
		Art.text_left(self, Vector2(470, 448), String(bd.get("quote", "")), 20, Color(1.0, 0.75, 0.55, ba * clampf((bk - 0.25) * 4.0, 0.0, 1.0)), Style.font_body)
	# --- title card ---
	if not title_card.is_empty():
		var k3 = float(title_card["t"]) / float(title_card["dur"])
		var a3 = minf(1.0, minf(k3 * 5.0, (1.0 - k3) * 3.0))
		var bw = 700.0 * minf(1.0, k3 * 6.0)
		draw_rect(Rect2(640 - bw * 0.5, 318, bw, 2), Color(Style.GOLD.r, Style.GOLD.g, Style.GOLD.b, a3))
		draw_rect(Rect2(640 - bw * 0.5, 392, bw, 2), Color(Style.GOLD.r, Style.GOLD.g, Style.GOLD.b, a3))
		Art.text(self, Vector2(640, 372), String(title_card["title"]), 52, Color(1, 0.92, 0.75, a3), Style.font_title, 1200.0)
		Art.text(self, Vector2(640, 422), String(title_card["sub"]), 18, Color(0.85, 0.8, 0.7, a3), Style.font_body, 1200.0)

func _ability_icon(i: int, c: Vector2, col: Color):
	var cc = Color(col.r, col.g, col.b, 0.95)
	match i:
		0:
			draw_arc(c, 13, -2.2, 0.2, 10, cc, 4.0, true)
			draw_line(c + Vector2(-8, 8), c + Vector2(8, -8), cc, 2.0)
		1:
			Art.star(self, c, 12, 5, 4, cc, 0.4)
		2:
			Art.ellipse(self, c + Vector2(0, 6), 14, 4, cc)
			Art.rrect(self, Rect2(c.x - 8, c.y - 10, 16, 15), 3, cc)
		3:
			for k in range(3):
				draw_line(c + Vector2(-12 + k * 6, -8), c + Vector2(-4 + k * 6, 0), cc, 2.5)
				draw_line(c + Vector2(-4 + k * 6, 0), c + Vector2(-12 + k * 6, 8), cc, 2.5)

func _draw_boss_bar(boss):
	var w = 620.0
	var x0 = 640.0 - w * 0.5
	Art.text(self, Vector2(640, 30), boss.display_name, 24, Color(1.0, 0.85, 0.7), Style.font_title, 800.0)
	Art.rrect(self, Rect2(x0 - 4, 40, w + 8, 20), 6, Color(0.04, 0.03, 0.05, 0.9))
	var k = clampf(boss.hp / boss.max_hp, 0.0, 1.0)
	Art.rrect(self, Rect2(x0, 44, w * k, 12), 4, Color(0.85, 0.12, 0.18))
	draw_rect(Rect2(x0, 44, w * k, 3), Color(1, 0.6, 0.6, 0.4))
	for m in [0.6, 0.3]:
		draw_line(Vector2(x0 + w * m, 42), Vector2(x0 + w * m, 58), Style.GOLD, 2.0)
	Art.text(self, Vector2(640, 76), boss.title, 13, Style.MUTED, Style.font_body, 800.0)
