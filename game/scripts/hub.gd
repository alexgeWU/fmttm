extends Node2D

## THE BACK ROOM (hub). The Blue Note after hours: once the hat empires' acts go home,
## the robots who sweep the floors lock the doors and take the stage. It's the only stage
## on Earth where a robot can play. No hats back here, except THE hat.
##   Performers  -> Slim (bass, lore), Ruby Rimshot (drums, combat tips), Doc (piano, boons)
##   Stage Door  -> start a run
##   The Setlist -> Upgrade Board (Johnny Upgrade style)
##   Wardrobe    -> hat roster
##   Hat-O-Matic -> spend leftover Hat Rolls
##   Rex         -> the bartender, gossip and hints
##   Jukebox     -> pick the lounge music genre, records, controls
##   Playbill    -> the maitre d's podium: index of the world, rooms, bosses, enemies, hats
##   Dressing Rm -> backstage vanity: robot paint jobs bought with Stage Tokens
##   Hall of Fame-> photo wall of every past show
##   Understudy  -> after every show, the old performer hands the hat to the next robot (cutscene)

const Art = preload("res://scripts/art.gd")
const WorldData = preload("res://scripts/world_data.gd")
const PlayerScript = preload("res://scripts/player.gd")
const FXScript = preload("res://scripts/fx.gd")
const DrawLayer = preload("res://scripts/draw_layer.gd")
const BoardScript = preload("res://scripts/upgrade_board.gd")
const RosterScript = preload("res://scripts/roster_ui.gd")
const RoomBG = preload("res://scripts/room_bg.gd")
const SkinScript = preload("res://scripts/skin_ui.gd")
const CodexScript = preload("res://scripts/codex_ui.gd")
const JukeboxScript = preload("res://scripts/jukebox_ui.gd")
const FameScript = preload("res://scripts/fame_ui.gd")
const BoonData = preload("res://scripts/boon_data.gd")
# The house band. stand = where you talk to them from (the stage lip).
const BAND = [
	{"id": "bass", "name": "Slim", "role": "upright bass", "pos": Vector2(480, 190), "stand": Vector2(480, 250), "skin": 4},
	{"id": "drums", "name": "Ruby Rimshot", "role": "drums", "pos": Vector2(640, 180), "stand": Vector2(640, 250), "skin": 6},
	{"id": "piano", "name": "Doc", "role": "piano", "pos": Vector2(800, 190), "stand": Vector2(800, 250), "skin": 7},
]
const SLIM_LINES = [
	"Welcome to the Back Room, kid. After closing, this joint is ours.",
	"Sal's acts get the spotlight till two a.m. Then the brooms come out and the robots take the stage.",
	"No hats back here. Hats are what the empires sell. Only the one wearing THE hat goes on the road.",
	"Every one of us learned the act. You fall, somebody else steps in. Nobody plays alone on Rust Row.",
	"The Stage Door opens onto the Blue Note floor. Sal's crew runs it during business hours. Good luck.",
	"The Hall of Fame wall? Every robot who wore the hat gets a picture. Every single one.",
]
const RUBY_LINES = [
	"Dash is your best friend! You can't get hit mid-dash, so dash THROUGH the bullets.",
	"Red circle on the floor? Something's about to slam there. Move your feet!",
	"Big Sal hits a wall, Sal gets dizzy. That's your solo, baby. Go off.",
	"Hold attack and keep the rhythm. Every combo ends on a big hit.",
	"The Getaway can't turn worth a nickel. Sidestep the headlights.",
	"Your Showstopper throws the hat up and slams it down. Save it for a crowd.",
	"Elites have gold rings. Hit 'em hard, they pay out better.",
]
const DOC_LINES = [
	"The Headliners made it to the Moon back when it was hard. They like a robot with nerve.",
	"Boons stack, kid. A Chill attack AND a Burn attack? Steam. Lovely steam.",
	"Two Headliners who both like you might team up. That's a Duo boon. Sweetest harmony there is.",
	"Pick the same boon again and it levels up. Three's the limit, like a good chord.",
	"Madame Fortuna's crits and the Ivory Ghost's zaps? Lucky Circuit. Trust an old piano man.",
	"The Chairman up there owns every hat in the sky. But he's never heard THIS band play.",
]
const FRAMES = [Vector2(62, 96), Vector2(132, 96), Vector2(202, 96), Vector2(272, 96)]

# Changing of the understudy (plays once when you come back from a show)
const SWAP_LEN = 6.4
const SWAP_DOOR = Vector2(1100, 262)
const SWAP_STOP = Vector2(835, 540)
const SWAP_NEW = Vector2(640, 600)

signal go_combat
signal go_gacha
signal go_menu

const FLOOR = Rect2(60, 230, 1160, 450)

var player = null
var fx = null
var world: Node2D
var ui_layer: CanvasLayer
var hud_draw: Control
var overlay: Control = null
var t: float = 0.0
var stations: Array = []
var speech: String = ""
var speech_t: float = 0.0
var leaving: bool = false
var line_i: int = 0
var visited_board: bool = false
var rack_node: Node2D
var rack_hats: Array = []
var rack_chroma: Array = []   # [node, is_equipped] for chroma hats on the rack
var rack_worn_slot: int = -1  # which rack peg holds the hat you're wearing (highlighted)
var fame_layer: Node2D
var fame_hats: Array = []
var speech_pos: Vector2 = Vector2(210, 470)
var band_focus: String = ""
var band_focus_t: float = 0.0
var band_line: Dictionary = {}
var swap_t: float = -1.0
var swap_won: bool = false
var swap_old: String = ""
var swap_new: String = ""
var swap_old_node: Node2D = null
var swap_new_node: Node2D = null
var swap_hat: Node2D = null
var swap_fx_acc: float = 0.0
var swap_beats: Dictionary = {}
var swap_lock_t: float = 0.0
var cam: Camera2D = null

func _ready():
	Sfx.set_music(GameData.hub_track)
	var cm = CanvasModulate.new()
	cm.color = Color(0.62, 0.55, 0.58)
	add_child(cm)
	var bg = DrawLayer.new()
	bg.z_index = -10
	bg.draw_func = _draw_bg
	add_child(bg)
	world = Node2D.new()
	world.y_sort_enabled = true
	add_child(world)
	fx = FXScript.new()
	fx.z_index = 20
	fx.ambient = "smoke"
	fx.ambient_rect = FLOOR
	add_child(fx)
	cam = Camera2D.new()
	cam.position = Vector2(640, 360)
	add_child(cam)
	cam.make_current()
	_walls()
	_lights()
	stations = [
		{"id": "door", "pos": Vector2(1100, 250), "label": "[E] Stage Door  -  start a run", "r": 0.0},
		{"id": "board", "pos": Vector2(140, 380), "label": "[E] The Setlist  -  upgrades", "r": 34.0},
		{"id": "fame", "pos": Vector2(167, 252), "label": "[E] Hall of Fame  -  every show you've played", "r": 0.0},
		{"id": "wardrobe", "pos": Vector2(1110, 470), "label": "[E] The Wardrobe  -  your hats", "r": 36.0},
		{"id": "slots", "pos": Vector2(470, 610), "label": "[E] Hat-O-Matic", "r": 30.0},
		{"id": "bar", "pos": Vector2(210, 560), "label": "[E] Talk to Rex", "r": 0.0},
		{"id": "jukebox", "pos": Vector2(930, 620), "label": "[E] Jukebox  -  pick the music", "r": 28.0},
		{"id": "playbill", "pos": Vector2(640, 372), "label": "[E] The Playbill  -  rooms, bosses, enemies, hats", "r": 22.0},
		{"id": "loom", "pos": Vector2(300, 470), "label": "[E] Talk to Lady Loom (hatmaker)", "r": 0.0},
		{"id": "bass", "pos": Vector2(480, 250), "label": "[E] Talk to Slim (bass)", "r": 0.0},
		{"id": "drums", "pos": Vector2(640, 250), "label": "[E] Talk to Ruby Rimshot (drums)", "r": 0.0},
		{"id": "piano", "pos": Vector2(800, 250), "label": "[E] Talk to Doc (piano)", "r": 0.0},
		{"id": "paint", "pos": Vector2(700, 625), "label": "[E] Dressing Room  -  stage looks", "r": 32.0},
	]
	for s in stations:
		var node = DrawLayer.new()
		node.position = s["pos"]
		node.draw_func = _draw_station.bind(String(s["id"]))
		world.add_child(node)
		if s["id"] == "wardrobe":
			rack_node = node
		if float(s["r"]) > 0.0:
			var body = StaticBody2D.new()
			var cs = CollisionShape2D.new()
			var sh = CircleShape2D.new()
			sh.radius = float(s["r"])
			cs.shape = sh
			body.add_child(cs)
			node.add_child(body)
	_refresh_rack()
	fame_layer = Node2D.new()
	fame_layer.z_index = -9
	add_child(fame_layer)
	_refresh_fame_wall()
	for tp in [Vector2(420, 390), Vector2(640, 470), Vector2(760, 380)]:
		var node2 = DrawLayer.new()
		node2.position = tp
		node2.draw_func = _draw_table
		world.add_child(node2)
		var body2 = StaticBody2D.new()
		var cs2 = CollisionShape2D.new()
		var sh2 = CircleShape2D.new()
		sh2.radius = 26.0
		cs2.shape = sh2
		cs2.position = Vector2(0, -4)
		body2.add_child(cs2)
		node2.add_child(body2)
	player = PlayerScript.new()
	player.setup(self, true)
	player.position = Vector2(640, 600)
	world.add_child(player)
	ui_layer = CanvasLayer.new()
	ui_layer.layer = 50
	add_child(ui_layer)
	hud_draw = Control.new()
	hud_draw.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	hud_draw.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud_draw.draw.connect(_draw_hud)
	ui_layer.add_child(hud_draw)
	if GameData.swap_pending != "" and not GameData.last_run.is_empty():
		_start_swap()
	else:
		GameData.swap_pending = ""
		_greet()

func _greet():
	if not GameData.last_run.is_empty():
		var lr = GameData.last_run
		if lr.get("won", false):
			speech = "You played the MOON? Ring-a-ding! Drinks are on me, Tin Eyes!"
		else:
			var b = WorldData.biome(int(lr.get("biome", 0)))
			speech = "%s got %s in %s. Doc'll patch 'em up. You're on, kid." % [String(lr.get("killer", "Somebody")), GameData.performer(0).split(" ")[0], b["name"]]
		speech_t = 5.0
	elif int(GameData.stats.get("runs", 0)) == 0:
		speech = "Welcome to the Back Room, Tin Eyes. After closing, the robots run this joint. Stage door's top right."
		speech_t = 6.0

func get_targets() -> Array:
	return []

func _walls():
	var walls = StaticBody2D.new()
	var A = FLOOR
	for r in [Rect2(A.position.x - 100, A.position.y - 100, A.size.x + 200, 100), Rect2(A.position.x - 100, A.end.y, A.size.x + 200, 100), Rect2(A.position.x - 100, A.position.y, 100, A.size.y), Rect2(A.end.x, A.position.y, 100, A.size.y)]:
		var cs = CollisionShape2D.new()
		var sh = RectangleShape2D.new()
		sh.size = r.size
		cs.shape = sh
		cs.position = r.get_center()
		walls.add_child(cs)
	add_child(walls)

func _lights():
	var ls = [
		[Vector2(640, 170), Color(1.0, 0.85, 0.6), 1.4, 2.6],
		[Vector2(140, 360), Color(1.0, 0.7, 0.4), 0.9, 1.4],
		[Vector2(1100, 260), Color(1.0, 0.3, 0.3), 1.0, 1.4],
		[Vector2(1110, 450), Color(0.8, 0.7, 1.0), 0.8, 1.4],
		[Vector2(470, 600), Color(1.0, 0.8, 0.3), 0.9, 1.2],
		[Vector2(930, 610), Color.from_hsv(0.8, 0.6, 1.0), 0.9, 1.3],
		[Vector2(220, 560), Color(1.0, 0.65, 0.35), 0.9, 1.6],
		[Vector2(640, 470), Color(1.0, 0.7, 0.45), 0.6, 3.0],
		[Vector2(640, 334), Color(0.8, 1.0, 0.7), 0.6, 1.0],
		[Vector2(167, 110), Color(1.0, 0.85, 0.6), 0.9, 1.4],
		[Vector2(700, 600), Color(0.9, 0.6, 1.0), 0.8, 1.2],
		[Vector2(960, 320), Color(0.6, 0.7, 1.0), 0.6, 1.6],
	]
	for l in ls:
		var pl = PointLight2D.new()
		pl.texture = Style.light_tex
		pl.position = l[0]
		pl.color = l[1]
		pl.energy = l[2]
		pl.texture_scale = l[3]
		add_child(pl)

## Real Sprite2D hats on the rack (same path as the worn hat, so they always render)
func _refresh_rack():
	for h in rack_hats:
		if is_instance_valid(h):
			h.queue_free()
	rack_hats.clear()
	rack_chroma.clear()
	rack_worn_slot = -1
	if rack_node == null:
		return
	var n = mini(4, GameData.roster.size())
	var idxs = []
	for i in range(n):
		idxs.append(i)
	# the hat you're wearing always gets a peg on the rack
	if GameData.equipped_hat_index >= n and n > 0:
		idxs[n - 1] = GameData.equipped_hat_index
	for si in range(idxs.size()):
		var ri = int(idxs[si])
		var worn = ri == GameData.equipped_hat_index
		var hn = Art.make_hat_node(GameData.roster[ri], 0.36)
		hn.position = Vector2(-45.0 + si * 30.0, -100.0 - float(si % 2) * 8.0)
		# worn hat: full colour + spotlight. Everything else waits in the dark.
		hn.modulate = Color.WHITE if worn else Color(0.42, 0.42, 0.48, 0.85)
		if worn:
			rack_worn_slot = si
		if GameData.roster[ri].get("is_chroma", false):
			rack_chroma.append([hn, worn])
		rack_node.add_child(hn)
		rack_hats.append(hn)

## Hat sprites inside the Hall of Fame photo frames (last four shows)
func _refresh_fame_wall():
	for h in fame_hats:
		if is_instance_valid(h):
			h.queue_free()
	fame_hats.clear()
	var recent = _recent_shows()
	for i in range(recent.size()):
		var hat: Dictionary = recent[i].get("hat", {})
		if hat.is_empty():
			continue
		var hn = Art.make_hat_node(hat, 0.5)
		hn.scale = Vector2(0.55, 0.55)
		hn.position = FRAMES[i] + Vector2(0, 26 + Art.HEAD_TOP * 0.55)
		fame_layer.add_child(hn)
		fame_hats.append(hn)

func _recent_shows() -> Array:
	var h = GameData.history
	var out = []
	for i in range(mini(4, h.size())):
		out.append(h[h.size() - 1 - i])
	return out

# ---------------------------------------------------------------------------
# CHANGING OF THE UNDERSTUDY: the last performer comes back through the stage door,
# the hat changes heads, and the new robot is the only Tin Eyes in the room.
# ---------------------------------------------------------------------------
func _start_swap():
	swap_won = GameData.swap_pending == "won"
	GameData.swap_pending = ""
	swap_old = GameData.performer(0)
	swap_new = GameData.performer(1)
	swap_t = 0.0
	swap_beats = {}
	player.visible = false
	player.position = SWAP_NEW
	player.facing = Vector2.DOWN
	swap_old_node = DrawLayer.new()
	swap_old_node.position = SWAP_DOOR
	swap_old_node.draw_func = _draw_swap_old
	world.add_child(swap_old_node)
	swap_new_node = DrawLayer.new()
	swap_new_node.position = SWAP_NEW
	swap_new_node.draw_func = _draw_swap_new
	world.add_child(swap_new_node)
	swap_hat = Art.make_hat_node(GameData.get_equipped_hat(), 0.5)
	swap_hat.z_index = 30
	add_child(swap_hat)

func _swap_beat(id: String, at: float) -> bool:
	if swap_t >= at and not swap_beats.has(id):
		swap_beats[id] = true
		return true
	return false

func _swap_update(delta: float):
	swap_t += delta
	var k = swap_t
	if _swap_beat("door", 0.3):
		Sfx.play("door")
	# the old performer walks in from the stage door
	var wk = clampf(k / 1.9, 0.0, 1.0)
	var we = 1.0 - pow(1.0 - wk, 2.0)
	var op = SWAP_DOOR.lerp(SWAP_STOP, we)
	if not swap_won and wk < 1.0:
		op.y -= absf(sin(k * 8.0)) * 5.0
		swap_old_node.rotation = sin(k * 8.0) * 0.1
	swap_old_node.position = op
	if not swap_won:
		# sparks and smoke while limping in, a flicker, then down they go
		swap_fx_acc += delta
		if k < 2.4 and swap_fx_acc > 0.28:
			swap_fx_acc = 0.0
			fx.burst(op + Vector2(randf_range(-10, 10), -40), Color(2.2, 1.6, 0.6), 5, 140.0, 2.0, "spark", 0.35)
			fx.burst(op + Vector2(0, -50), Color(0.5, 0.45, 0.45, 0.5), 2, 30.0, 8.0, "smoke", 1.0)
		if k > 1.9 and k < 2.4:
			var fl = 0.45 if int(k * 18.0) % 2 == 0 else 1.0
			swap_old_node.modulate = Color(fl, fl, fl, 1.0)
			swap_old_node.rotation = 0.0
		elif k >= 2.4:
			var fall = clampf((k - 2.4) / 0.3, 0.0, 1.0)
			swap_old_node.rotation = lerpf(0.0, 1.35, fall * fall)
			swap_old_node.modulate = Color(0.7, 0.7, 0.7, 1.0)
		if _swap_beat("fall", 2.7):
			Sfx.play("slam", 0.8, -4.0)
			fx.shake(5.0)
			fx.burst(op + Vector2(24, -8), Color(0.75, 0.7, 0.65), 10, 160.0, 3.0, "shard", 0.6)
	else:
		# a winner: tips the hat, then bows out in a shower of gold
		if k > 1.9 and k < 2.4:
			swap_old_node.rotation = sin((k - 1.9) / 0.5 * PI) * 0.18
		if _swap_beat("tip", 2.0):
			Sfx.play("select")
	# the heap (or the star) fades away
	if k > 4.0:
		var fa = clampf(1.0 - (k - 4.0) / 0.9, 0.0, 1.0)
		var mc = swap_old_node.modulate
		swap_old_node.modulate = Color(mc.r, mc.g, mc.b, fa)
	if _swap_beat("gone", 4.0):
		var gc = Color(2.0, 1.6, 0.5) if swap_won else Color(0.8, 0.75, 0.7)
		fx.burst(op + Vector2(0, -30), gc, 22, 120.0, 3.0, "star" if swap_won else "shard", 1.0)
	# the hat changes heads
	var old_head = op + Vector2(0, Art.HEAD_TOP)
	var new_head = SWAP_NEW + Vector2(0, Art.HEAD_TOP)
	if k < 2.4:
		var lift = 0.0
		if swap_won and k > 1.9:
			lift = sin((k - 1.9) / 0.5 * PI) * 14.0
		swap_hat.position = op + Vector2(0, Art.HEAD_TOP - lift + Art.robot_bob(t, wk < 1.0)).rotated(swap_old_node.rotation)
		swap_hat.rotation = swap_old_node.rotation
	elif k < 3.5:
		var u = (k - 2.4) / 1.1
		swap_hat.position = old_head.lerp(new_head, u) + Vector2(0, -sin(u * PI) * 180.0)
		swap_hat.rotation = u * TAU * 2.0
		if int(k * 30.0) % 3 == 0:
			fx.burst(swap_hat.position + Vector2(0, -14), Color(2.0, 1.7, 0.8, 0.8), 1, 30.0, 2.0, "star", 0.5)
	else:
		swap_hat.position = new_head
		swap_hat.rotation = 0.0
	if _swap_beat("toss", 2.4):
		Sfx.play("whoosh_up", 1.0, -6.0)
	if _swap_beat("land", 3.5):
		Sfx.play("levelup")
		fx.ring(new_head, Color(2.0, 1.7, 0.8, 0.9), 10.0, 90.0, 0.4, 5.0)
		fx.burst(new_head + Vector2(0, -10), Color(2.0, 1.7, 0.8), 24, 220.0, 3.0, "confetti", 1.0)
	if swap_t >= SWAP_LEN:
		_swap_finish()

func _swap_finish():
	if swap_t < 0.0:
		return
	swap_t = -1.0
	swap_lock_t = 0.2
	for n in [swap_old_node, swap_new_node, swap_hat]:
		if n != null and is_instance_valid(n):
			n.queue_free()
	swap_old_node = null
	swap_new_node = null
	swap_hat = null
	player.visible = true
	player.position = SWAP_NEW
	_greet()

func _draw_swap_old(ci: CanvasItem):
	var sk = GameData.skin()
	var col: Color = sk["body"]
	if not swap_won:
		col = col.darkened(0.35)
	var walking = swap_t < 1.9
	var dirv = (SWAP_STOP - SWAP_DOOR).normalized() if walking else Vector2(-0.85, 0.5).normalized()
	var sk2 = sk
	if not swap_won and swap_t >= 2.7:
		sk2 = sk.duplicate()
		sk2["eye"] = Color(0.08, 0.08, 0.1)
	Art.draw_robot(ci, t, dirv, walking, 0.0, col, sk2)
	if not swap_won and swap_t < 2.7:
		# dents and a loose wire
		ci.draw_line(Vector2(-8, -30), Vector2(-3, -24), Color(0.1, 0.08, 0.08, 0.8), 2.0)
		ci.draw_line(Vector2(6, -38), Vector2(11, -33), Color(0.1, 0.08, 0.08, 0.8), 2.0)
		var wy = sin(t * 14.0) * 3.0
		ci.draw_polyline(PackedVector2Array([Vector2(10, -26), Vector2(18, -20 + wy), Vector2(22, -12)]), Color(1.0, 0.3, 0.2), 1.5)

func _draw_swap_new(ci: CanvasItem):
	var sk = GameData.skin()
	var on = clampf((swap_t - 2.9) / 0.6, 0.0, 1.0)
	# spotlight finds the next understudy
	if on > 0.0:
		ci.draw_colored_polygon(PackedVector2Array([Vector2(-22, -420), Vector2(22, -420), Vector2(70, 8), Vector2(-70, 8)]), Color(1.4, 1.2, 0.8, 0.09 * on))
		Art.ellipse(ci, Vector2.ZERO, 64, 18, Color(1.4, 1.2, 0.8, 0.16 * on))
	var col: Color = (sk["body"] as Color).darkened(0.55 * (1.0 - on))
	# powered down: eyes stay dark until the spotlight hits
	var sk2 = sk.duplicate()
	var ec: Color = sk.get("eye", Color(0.5, 1.7, 2.2))
	sk2["eye"] = Color(0.08, 0.08, 0.1).lerp(ec, on)
	Art.draw_robot(ci, t * on, Vector2.DOWN, false, 0.0, col, sk2)
	if swap_t > 3.5 and swap_t < 4.1:
		var fk = (swap_t - 3.5) / 0.6
		Art.glow(ci, Vector2(0, -40), 60.0 + 40.0 * fk, Color(2.0, 1.8, 1.2, 0.35 * (1.0 - fk)), 3)

func _draw_swap_hud(c: Control):
	var bar = clampf(minf(swap_t / 0.4, (SWAP_LEN - swap_t) / 0.4), 0.0, 1.0) * 64.0
	c.draw_rect(Rect2(0, 0, 1280, bar), Color(0, 0, 0))
	c.draw_rect(Rect2(0, 720 - bar, 1280, bar), Color(0, 0, 0))
	var cap = ""
	var sub_t = ""
	if swap_t < 2.4:
		cap = ("%s COMES HOME A STAR" if swap_won else "%s MAKES IT BACK... BARELY") % swap_old.to_upper()
		sub_t = "The Moon is theirs tonight. Time to pass the hat." if swap_won else "Rust Row takes care of its own. Doc will patch them up."
	elif swap_t < 4.2:
		cap = "THE HAT FINDS A NEW HEAD"
		sub_t = "No robot owns the act. The hat does."
	else:
		cap = "ENTER %s" % swap_new.to_upper()
		sub_t = "Whoever wears the hat IS Ol' Tin Eyes."
	var seg_start = 0.0 if swap_t < 2.4 else (2.4 if swap_t < 4.2 else 4.2)
	var ca = clampf((swap_t - seg_start) / 0.35, 0.0, 1.0)
	Art.text(c, Vector2(640, 684), cap, 26, Color(1.8, 1.45, 0.7, ca), Style.font_title, 1200.0)
	Art.text(c, Vector2(640, 708), sub_t, 14, Color(0.9, 0.86, 0.8, ca), Style.font_body, 1200.0)
	Art.text(c, Vector2(1200, 40), "any key: skip", 12, Color(0.7, 0.66, 0.6, 0.8), Style.font_mono, 200.0)

func _nearest_station():
	var best = null
	var bd = 90.0
	for s in stations:
		var d = player.global_position.distance_to(s["pos"])
		if s["id"] == "door":
			d = player.global_position.distance_to(s["pos"] + Vector2(0, 10))
		if d < bd:
			bd = d
			best = s
	return best

func _physics_process(delta):
	t += delta
	speech_t -= delta
	band_focus_t -= delta
	if band_focus_t <= 0.0:
		band_focus = ""
	swap_lock_t -= delta
	player.input_locked = overlay != null or leaving or swap_t >= 0.0 or swap_lock_t > 0.0
	if swap_t >= 0.0:
		_swap_update(delta)
	var cc = Art.chroma_color(t)
	for rc in rack_chroma:
		var rn = rc[0]
		if is_instance_valid(rn):
			var dim = 1.35 if rc[1] else 0.5
			rn.modulate = Color(cc.r * dim, cc.g * dim, cc.b * dim, 1.0 if rc[1] else 0.85)
	if swap_hat != null and is_instance_valid(swap_hat) and GameData.get_equipped_hat().get("is_chroma", false):
		swap_hat.modulate = Color(cc.r * 1.35, cc.g * 1.35, cc.b * 1.35, 1.0)
	if cam != null and fx != null:
		cam.offset = Vector2(randf_range(-1, 1), randf_range(-1, 1)) * fx.shake_amount
	hud_draw.queue_redraw()

func _unhandled_input(event):
	if swap_t >= 0.0:
		if swap_t > 0.3 and event.is_pressed() and not event.is_echo() and (event is InputEventKey or event is InputEventMouseButton or event is InputEventJoypadButton):
			get_viewport().set_input_as_handled()
			_swap_finish()
		elif event.is_pressed():
			get_viewport().set_input_as_handled()
		return
	if overlay != null and not overlay.has_signal("closed") and (event.is_action_pressed("ui_cancel") or event.is_action_pressed("pause")):
		get_viewport().set_input_as_handled()
		_close_overlay()
		return
	if overlay != null or leaving:
		return
	if event.is_action_pressed("interact"):
		var s = _nearest_station()
		if s != null:
			get_viewport().set_input_as_handled()
			_use(String(s["id"]))
		return
	if event.is_action_pressed("pause"):
		get_viewport().set_input_as_handled()
		leaving = true
		go_menu.emit()

func _use(id: String):
	match id:
		"door":
			leaving = true
			Sfx.play("door")
			fx.burst(Vector2(1100, 200), Color(1.8, 0.5, 0.4), 30, 200.0, 3.0, "confetti", 1.0)
			go_combat.emit()
		"board":
			visited_board = true
			Sfx.play("select")
			var b = BoardScript.new()
			b.closed.connect(_close_overlay)
			_open_overlay(b)
		"wardrobe":
			GameData.tut["wardrobe"] = true
			Sfx.play("select")
			var r = RosterScript.new()
			r.closed.connect(func():
				_close_overlay()
				_refresh_rack()
			)
			r.equipped.connect(func():
				player.load_hat()
				player.recompute()
				_refresh_rack()
			)
			_open_overlay(r)
		"slots":
			if GameData.can_roll():
				leaving = true
				Sfx.play("lever")
				go_gacha.emit()
			else:
				Sfx.play("error")
				_say("Next pull costs %d RP, pal. Go earn some tips on stage." % GameData.roll_cost())
		"bass", "drums", "piano":
			_band_talk(id)
		"loom":
			var ll = BoonData.TAILOR["lines"].duplicate()
			ll.append("Every hat in that Hat-O-Matic came off my loom, dearie. Go pull one.")
			ll.append("I've seen %d robots wear my hat so far. I remember every one." % int(GameData.stats.get("runs", 0)))
			if GameData.roster.size() > 0 and GameData.hat_grade_index(GameData.get_equipped_hat()) >= 2:
				ll.append("Ooh, an A-grade or better. Some of my finest work. Don't scuff it.")
			var li = int(band_line.get("loom", -1)) + 1
			band_line["loom"] = li
			Sfx.play("sting_tailor", 1.0, -4.0)
			_say("Lady Loom: " + String(ll[li % ll.size()]), Vector2(300, 330))
		"bar":
			_say("Rex: " + _bartender_line())
			Sfx.play("glass", 1.4, -8.0)
		"jukebox":
			Sfx.play("select")
			var jb = JukeboxScript.new()
			jb.closed.connect(_close_overlay)
			_open_overlay(jb)
		"fame":
			Sfx.play("select")
			var fm = FameScript.new()
			fm.closed.connect(_close_overlay)
			_open_overlay(fm)
		"playbill":
			Sfx.play("select")
			GameData.tut["playbill"] = true
			var cx = CodexScript.new()
			cx.closed.connect(_close_overlay)
			_open_overlay(cx)
		"paint":
			Sfx.play("select")
			var sk = SkinScript.new()
			sk.closed.connect(_close_overlay)
			_open_overlay(sk)

func _objective() -> Array:
	if int(GameData.stats.get("runs", 0)) == 0:
		return ["Walk to the STAGE DOOR (top right) and play your first gig.", "door"]
	if GameData.pending_rolls > 0:
		return ["Spin the HAT-O-MATIC. You have %d FREE roll%s." % [GameData.pending_rolls, "" if GameData.pending_rolls == 1 else "s"], "slots"]
	if GameData.roster.size() < 2 and GameData.rhythm_points >= GameData.roll_cost():
		return ["Buy a Hat Roll at the HAT-O-MATIC (%d RP). New hat = new moveset." % GameData.roll_cost(), "slots"]
	if not GameData.tut.get("playbill", false):
		return ["Check THE PLAYBILL by the stage to learn every room, boss and reward.", "playbill"]
	var n = 0
	for bn in GameData.BOARD:
		if GameData.board_can_buy(bn["id"]):
			n += 1
	if n > 0 and not visited_board:
		return ["Spend Rhythm Points at THE SETLIST. Those upgrades are PERMANENT.", "board"]
	if GameData.roster.size() > 1 and not GameData.tut.get("wardrobe", false):
		return ["Try a new hat at THE WARDROBE. Every hat is a new moveset.", "wardrobe"]
	return ["Goal: sing on THE MOON. Hit the STAGE DOOR when you're ready.", "door"]

func _say(s: String, anchor: Vector2 = Vector2(210, 470)):
	speech = s
	speech_t = 5.5
	speech_pos = anchor

func _band_talk(id: String):
	var lines = []
	var m = {}
	for bm in BAND:
		if bm["id"] == id:
			m = bm
	var lr = GameData.last_run
	match id:
		"bass":
			lines = SLIM_LINES.duplicate()
			if not lr.is_empty() and not lr.get("won", false):
				lines.append("Heard %s knocked %s off the stage. We'll play the next one in." % [String(lr.get("killer", "somebody")), String(GameData.history.back().get("name", "the last one")) if not GameData.history.is_empty() else "the last one"])
			if int(GameData.stats.get("wins", 0)) > 0:
				lines.append("A robot played the MOON. Somebody write that down. Somebody write a SONG.")
		"drums":
			lines = RUBY_LINES.duplicate()
			if int(GameData.stats.get("bosses", 0)) == 0 and int(GameData.stats.get("runs", 0)) > 0:
				lines.append("Big Sal charges in a straight line. Let him kiss the wall, then get your licks in!")
		"piano":
			lines = DOC_LINES.duplicate()
			if GameData.lvl("unlock_encore") == 0:
				lines.append("Buy Encore! on the Setlist and you can level up boons between rooms.")
	var i = int(band_line.get(id, -1)) + 1
	band_line[id] = i
	var line = String(lines[i % lines.size()])
	band_focus = id
	band_focus_t = 3.0
	Sfx.riff(id)
	_say("%s: %s" % [m.get("name", "?"), line], (m.get("pos", Vector2(640, 190)) as Vector2) + Vector2(0, -60))

func _bartender_line() -> String:
	var lines = WorldData.BARTENDER_LINES.duplicate()
	if GameData.lvl("unlock_shop") == 0:
		lines.append("Buy the Speakeasy Password on the Setlist. Trust me.")
	if GameData.lvl("unlock_encore") == 0:
		lines.append("Encore! on the Setlist lets you level boons mid-run.")
	if GameData.roster.size() < GameData.max_roster():
		lines.append("Got room in the Wardrobe. Go win yourself a hat.")
	line_i = (line_i + 1 + randi() % 3) % lines.size()
	return String(lines[line_i])

func _open_overlay(c: Control):
	overlay = c
	ui_layer.add_child(c)

func _close_overlay():
	if overlay != null:
		overlay.queue_free()
	overlay = null

# ---------------------------------------------------------------------------
# DRAWING
# ---------------------------------------------------------------------------
func _draw_bg(ci: CanvasItem):
	var A = FLOOR
	ci.draw_rect(Rect2(0, 0, 1280, 720), Color(0.08, 0.03, 0.04))
	# back wall: burgundy wallpaper with gold diamonds
	ci.draw_rect(Rect2(0, 0, 1280, A.position.y), Color(0.26, 0.05, 0.08))
	for i in range(33):
		for j in range(6):
			var p = Vector2(i * 40 + (20 if j % 2 == 0 else 0), 20 + j * 36)
			Art.poly(ci, [p + Vector2(0, -8), p + Vector2(6, 0), p + Vector2(0, 8), p + Vector2(-6, 0)], Color(0.9, 0.65, 0.3, 0.12))
	ci.draw_line(Vector2(0, 10), Vector2(1280, 10), Style.GOLD_DIM, 3.0)
	# floor: checker parquet
	for i in range(30):
		for j in range(12):
			var r = Rect2(A.position.x + i * 40, A.position.y + j * 40, 40, 40).intersection(A)
			if r.size.x <= 0 or r.size.y <= 0:
				continue
			var dark = (i + j) % 2 == 0
			ci.draw_rect(r, Color(0.2, 0.11, 0.07) if dark else Color(0.26, 0.15, 0.09))
	Art.ellipse(ci, Vector2(640, 470), 360, 150, Color(0.45, 0.06, 0.1, 0.8))
	Art.ellipse_line(ci, Vector2(640, 470), 350, 144, Color(0.9, 0.7, 0.3, 0.5), 3.0)
	# Hall of Fame photo wall
	Art.rrect(ci, Rect2(28, 44, 278, 132), 6, Color(0.16, 0.05, 0.06, 0.9))
	var recent = _recent_shows()
	for i in range(FRAMES.size()):
		var fc: Vector2 = FRAMES[i]
		var won = i < recent.size() and recent[i].get("won", false)
		var fr = Rect2(fc.x - 28, fc.y - 40, 56, 72)
		ci.draw_rect(fr.grow(4), Style.GOLD if won else Color(0.55, 0.42, 0.22))
		ci.draw_rect(fr, Color(0.33, 0.25, 0.18))
		if i < recent.size():
			var sk = GameData.SKINS[0]
			for s2 in GameData.SKINS:
				if s2["id"] == String(recent[i].get("skin", "classic")):
					sk = s2
			ci.draw_set_transform(fc + Vector2(0, 26), 0.0, Vector2(0.55, 0.55))
			Art.draw_robot(ci, 0.0, Vector2.DOWN, false, 0.0, sk["body"], sk)
			ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		else:
			Art.text(ci, fc + Vector2(0, 4), "?", 22, Color(0.6, 0.5, 0.4), Style.font_title, 50.0, false)
	Art.rrect(ci, Rect2(92, 180, 150, 22), 4, Color(0.6, 0.45, 0.2))
	Art.text(ci, Vector2(167, 196), "HALL OF FAME", 13, Color(0.15, 0.08, 0.05), Style.font_mono, 150.0, false)
	# stage
	var st = Rect2(390, 70, 500, 150)
	Art.rrect(ci, st, 10, Color(0.18, 0.08, 0.05))
	ci.draw_rect(Rect2(390, 200, 500, 20), Color(0.3, 0.15, 0.08))
	ci.draw_line(Vector2(390, 200), Vector2(890, 200), Style.GOLD, 3.0)
	for i in range(26):
		var on = int(t * 6.0 + i) % 3 == 0
		ci.draw_circle(Vector2(396 + i * 19.2, 214), 3.0, Color(2.0, 1.7, 0.7) if on else Color(0.7, 0.55, 0.3))
	# curtains
	for sx in [0.0, 1.0]:
		var x0 = 330.0 if sx == 0.0 else 890.0
		ci.draw_rect(Rect2(x0, 20, 60, 200), Color(0.55, 0.04, 0.1))
		for k in range(4):
			ci.draw_line(Vector2(x0 + 8 + k * 14, 20), Vector2(x0 + 8 + k * 14, 220), Color(0.3, 0.02, 0.05), 3.0)
	ci.draw_rect(Rect2(330, 14, 620, 22), Color(0.5, 0.04, 0.09))
	Art.text(ci, Vector2(640, 32), "THE BLUE NOTE", 18, Color(0.5, 0.9, 2.2), Style.font_title, 400.0, false)
	var flick = 1.0 if fmod(t, 6.1) > 0.15 else 0.3
	Art.text(ci, Vector2(640, 60), "AFTER HOURS", 12, Color(2.0 * flick, 0.5 * flick, 1.2 * flick), Style.font_mono, 300.0, false)
	# the robot band (bobbing on the beat)
	var beat = absf(sin(t * PI * 96.0 / 60.0))
	_band_member(ci, Vector2(480, 190), beat, "bass")
	_band_member(ci, Vector2(640, 180), beat, "drums")
	_band_member(ci, Vector2(800, 190), beat, "piano")
	# spotlight cones
	for sx2 in [480.0, 640.0, 800.0]:
		ci.draw_colored_polygon(PackedVector2Array([Vector2(sx2 - 8, 36), Vector2(sx2 + 8, 36), Vector2(sx2 + 50, 200), Vector2(sx2 - 50, 200)]), Color(1.0, 0.9, 0.6, 0.05))
	# bar counter (bottom-left)
	Art.rrect(ci, Rect2(60, 590, 300, 40), 6, Color(0.3, 0.13, 0.06))
	ci.draw_line(Vector2(60, 596), Vector2(360, 596), Style.GOLD, 2.0)
	# stage door frame (top-right)
	var dr = Rect2(1060, 120, 80, 110)
	ci.draw_rect(dr.grow(6), Color(0.08, 0.04, 0.04))
	ci.draw_rect(dr, Color(0.6, 0.08, 0.1))
	ci.draw_rect(Rect2(1066, 128, 30, 94), Color(0.5, 0.06, 0.08))
	ci.draw_rect(Rect2(1104, 128, 30, 94), Color(0.5, 0.06, 0.08))
	ci.draw_circle(Vector2(1098, 180), 4, Style.GOLD)
	Art.star(ci, Vector2(1100, 150), 12, 5, 5, Style.GOLD, 0.0)
	for i in range(10):
		var on2 = int(t * 8.0 + i) % 2 == 0
		ci.draw_circle(Vector2(1054 + i * 10.2, 108), 3.0, Color(2.2, 1.6, 0.6) if on2 else Color(0.6, 0.4, 0.2))
	Art.text(ci, Vector2(1100, 100), "STAGE", 14, Color(2.0, 1.7, 0.8), Style.font_mono, 120.0, false)

func _band_member(ci: CanvasItem, p: Vector2, beat: float, role: String):
	var m = {}
	for bm in BAND:
		if bm["id"] == role:
			m = bm
	var focus = band_focus == role
	var b = beat * (6.0 if focus else 3.0)
	var sk = GameData.SKINS[int(m.get("skin", 0)) % GameData.SKINS.size()]
	if focus:
		ci.draw_colored_polygon(PackedVector2Array([Vector2(p.x - 10, 36), Vector2(p.x + 10, 36), Vector2(p.x + 60, p.y + 10), Vector2(p.x - 60, p.y + 10)]), Color(1.2, 1.1, 0.8, 0.18))
		Art.glow(ci, p + Vector2(0, -30), 60, Color(1.4, 1.2, 0.7, 0.3), 3)
	# instrument behind the player for bass/piano, in front for drums
	if role == "piano":
		Art.rrect(ci, Rect2(p.x - 36, p.y - 40, 72, 30), 4, Color(0.05, 0.05, 0.06))
		ci.draw_rect(Rect2(p.x - 32, p.y - 14, 64, 6), Color(0.95, 0.95, 0.9))
		for k in range(8):
			ci.draw_line(Vector2(p.x - 32 + k * 8, p.y - 14), Vector2(p.x - 32 + k * 8, p.y - 8), Color(0.2, 0.2, 0.2), 1.0)
	ci.draw_set_transform(p + Vector2(0, -b), 0.0, Vector2(0.95, 0.95))
	Art.draw_robot(ci, t, Vector2(0.25, 1.0).normalized(), false, 0.3 * absf(sin(t * 8.0)) if focus else 0.0, sk["body"], sk)
	ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	match role:
		"bass":
			Art.ellipse(ci, Vector2(p.x + 18, p.y - 18), 12, 18, Color(0.55, 0.28, 0.1))
			Art.ellipse(ci, Vector2(p.x + 18, p.y - 38), 8, 11, Color(0.55, 0.28, 0.1))
			ci.draw_line(Vector2(p.x + 18, p.y - 80), Vector2(p.x + 18, p.y - 2), Color(0.2, 0.1, 0.05), 2.0)
		"drums":
			Art.ellipse(ci, Vector2(p.x, p.y + 2), 22, 11, Color(0.85, 0.85, 0.9))
			Art.ellipse(ci, Vector2(p.x, p.y + 2), 16, 7, Color(0.7, 0.1, 0.15))
			Art.ellipse(ci, Vector2(p.x - 28, p.y - 22), 11, 3, Color(1.4, 1.1, 0.4))
			Art.ellipse(ci, Vector2(p.x + 28, p.y - 16), 10, 3, Color(1.4, 1.1, 0.4))
			ci.draw_line(Vector2(p.x - 12, p.y - 26 - b), Vector2(p.x - 26, p.y - 30 + b * 2.0), Color(0.9, 0.85, 0.7), 2.0)
			ci.draw_line(Vector2(p.x + 12, p.y - 26 - b), Vector2(p.x + 26, p.y - 22 + b), Color(0.9, 0.85, 0.7), 2.0)
	# name plates sit on one line across the bandstand (Ruby's kit sits a little higher)
	Art.text(ci, Vector2(p.x, 212.0), String(m.get("name", "")).to_upper(), 11, Color(0.95, 0.85, 0.6) if focus else Color(0.75, 0.68, 0.55), Style.font_mono, 160.0, false)

func _draw_table(ci: CanvasItem):
	RoomBG.draw_obstacle(ci, "table", t)

func _draw_station(ci: CanvasItem, id: String):
	match id:
		"board":
			Art.shadow(ci, Vector2(0, 4), 40)
			ci.draw_line(Vector2(-30, 0), Vector2(-20, -90), Color(0.35, 0.2, 0.1), 4.0)
			ci.draw_line(Vector2(30, 0), Vector2(20, -90), Color(0.35, 0.2, 0.1), 4.0)
			Art.rrect(ci, Rect2(-48, -130, 96, 80), 4, Color(0.35, 0.2, 0.1))
			Art.rrect(ci, Rect2(-43, -125, 86, 70), 3, Color(0.08, 0.12, 0.1))
			for i in range(4):
				ci.draw_line(Vector2(-36, -112 + i * 14), Vector2(36, -112 + i * 14), Color(0.9, 0.9, 0.85, 0.35), 1.0)
			Art.note_glyph(ci, Vector2(-18, -104), 7, Color(1.0, 1.0, 0.9, 0.8))
			Art.note_glyph(ci, Vector2(8, -92), 7, Color(1.0, 1.0, 0.9, 0.8))
			Art.text(ci, Vector2(0, -136), "THE SETLIST", 13, Style.GOLD, Style.font_mono, 160.0)
			var n = 0
			for bn in GameData.BOARD:
				if GameData.board_can_buy(bn["id"]):
					n += 1
			if n > 0:
				ci.draw_circle(Vector2(44, -128), 11, Color(0.9, 0.15, 0.2))
				Art.text(ci, Vector2(44, -123), str(n), 13, Color(1, 1, 1), Style.font_mono, 30.0, false)
		"wardrobe":
			Art.shadow(ci, Vector2(0, 4), 50)
			ci.draw_line(Vector2(0, 0), Vector2(0, -110), Color(0.35, 0.22, 0.12), 5.0)
			ci.draw_line(Vector2(-40, -100), Vector2(40, -100), Color(0.35, 0.22, 0.12), 4.0)
			ci.draw_line(Vector2(-30, 0), Vector2(30, 0), Color(0.35, 0.22, 0.12), 5.0)
			ci.draw_line(Vector2(-55, -100), Vector2(55, -100), Color(0.35, 0.22, 0.12), 4.0)
			for i in range(4):
				ci.draw_line(Vector2(-45.0 + i * 30.0, -100), Vector2(-45.0 + i * 30.0, -94), Color(0.6, 0.5, 0.3), 2.0)
			if rack_worn_slot >= 0:
				# spotlight on the hat you're wearing
				var wp = Vector2(-45.0 + rack_worn_slot * 30.0, -100.0 - float(rack_worn_slot % 2) * 8.0)
				Art.glow(ci, wp + Vector2(0, -14), 24.0 + 3.0 * sin(t * 3.0), Color(1.7, 1.4, 0.6, 0.4), 3)
				Art.poly(ci, [wp + Vector2(-5, -36), wp + Vector2(5, -36), wp + Vector2(0, -30)], Color(2.0, 1.6, 0.6))
			Art.text(ci, Vector2(0, -150), "WARDROBE  %d/%d" % [GameData.roster.size(), GameData.max_roster()], 13, Style.GOLD, Style.font_mono, 200.0)
		"slots":
			Art.shadow(ci, Vector2(0, 4), 30)
			Art.rrect(ci, Rect2(-28, -80, 56, 80), 8, Color(0.6, 0.08, 0.12))
			Art.rrect(ci, Rect2(-28, -80, 56, 10), 5, Style.GOLD)
			Art.rrect(ci, Rect2(-22, -62, 44, 20), 3, Color(0.95, 0.93, 0.88))
			Art.text(ci, Vector2(0, -46), "HAT", 12, Color(0.8, 0.1, 0.1), Style.font_mono, 60.0, false)
			ci.draw_line(Vector2(28, -50), Vector2(36, -74), Color(0.85, 0.85, 0.9), 3.0)
			ci.draw_circle(Vector2(36, -76), 5, Color(0.9, 0.1, 0.1))
			if GameData.pending_rolls > 0:
				var pulse = 0.5 + 0.5 * sin(t * 6.0)
				Art.glow(ci, Vector2(0, -60), 40, Color(2.0, 1.6, 0.5, 0.3 + 0.3 * pulse), 3)
				Art.text(ci, Vector2(0, -92), "%d FREE!" % GameData.pending_rolls, 13, Color(2.0, 1.7, 0.7), Style.font_mono, 120.0)
			else:
				var afford = GameData.rhythm_points >= GameData.roll_cost()
				Art.text(ci, Vector2(0, -92), "%d RP" % GameData.roll_cost(), 13, Color(1.0, 0.85, 0.5) if afford else Style.MUTED, Style.font_mono, 120.0)
		"bar":
			# Rex the robo-bartender
			var bob = sin(t * 2.0) * 1.5
			Art.shadow(ci, Vector2(0, 0), 16)
			Art.rrect(ci, Rect2(-14, -52 + bob, 28, 30), 8, Color(0.9, 0.9, 0.88))
			Art.rrect(ci, Rect2(-14, -52 + bob, 7, 22), 3, Color(0.1, 0.1, 0.12))
			Art.rrect(ci, Rect2(7, -52 + bob, 7, 22), 3, Color(0.1, 0.1, 0.12))
			ci.draw_circle(Vector2(0, -64 + bob), 12, Color(0.72, 0.62, 0.45))
			ci.draw_line(Vector2(-7, -58 + bob), Vector2(7, -58 + bob), Color(0.3, 0.15, 0.08), 3.0)
			ci.draw_circle(Vector2(-4, -66 + bob), 2, Color(1.8, 1.2, 0.4))
			ci.draw_circle(Vector2(4, -66 + bob), 2, Color(1.8, 1.2, 0.4))
			ci.draw_line(Vector2(0, -76 + bob), Vector2(0, -84 + bob), Color(0.5, 0.5, 0.55), 1.5)
			ci.draw_circle(Vector2(0, -86 + bob), 2.5, Color(2.0, 0.4, 0.3) if int(t * 2.0) % 2 == 0 else Color(0.6, 0.15, 0.1))
			var shake = sin(t * 14.0) * 5.0
			Art.rrect(ci, Rect2(18, -58 + shake, 10, 16), 3, Color(0.85, 0.85, 0.9))
			Art.text(ci, Vector2(0, -92), "REX", 12, Style.GOLD, Style.font_mono, 80.0)
		"jukebox":
			Art.shadow(ci, Vector2(0, 4), 34)
			Art.rrect(ci, Rect2(-30, -80, 60, 80), 8, Color(0.45, 0.22, 0.08))
			var arch = PackedVector2Array()
			for i in range(13):
				var a = PI + PI * float(i) / 12.0
				arch.append(Vector2(0, -80) + Vector2(cos(a) * 30, sin(a) * 24))
			ci.draw_colored_polygon(arch, Color(0.45, 0.22, 0.08))
			for kk in range(2):
				var col = Color.from_hsv(fmod(t * 0.3 + kk * 0.3, 1.0), 0.8, 1.8)
				var pts = PackedVector2Array()
				for i in range(13):
					var a2 = PI + PI * float(i) / 12.0
					pts.append(Vector2(0, -80) + Vector2(cos(a2) * (24 - kk * 7), sin(a2) * (19 - kk * 6)))
				ci.draw_polyline(pts, col, 3.0)
			Art.record_glyph(ci, Vector2(0, -50), 12, t * 2.0)
			for i in range(3):
				var nt = fmod(t * 0.5 + i * 0.33, 1.0)
				Art.note_glyph(ci, Vector2(20 + sin(nt * 6.0 + i) * 8.0, -90 - nt * 50.0), 6, Color(1.6, 1.3, 0.6, 1.0 - nt))
		"playbill":
			# the maitre d's podium with the house program
			Art.shadow(ci, Vector2(0, 3), 26)
			Art.poly(ci, [Vector2(-22, 0), Vector2(22, 0), Vector2(18, -62), Vector2(-18, -62)], Color(0.32, 0.16, 0.08))
			ci.draw_line(Vector2(-18, -40), Vector2(18, -40), Color(0.5, 0.3, 0.15), 2.0)
			Art.poly(ci, [Vector2(-26, -62), Vector2(26, -62), Vector2(30, -72), Vector2(-30, -72)], Color(0.42, 0.22, 0.1))
			Art.poly(ci, [Vector2(-22, -72), Vector2(0, -76), Vector2(0, -68), Vector2(-20, -66)], Color(0.95, 0.9, 0.8))
			Art.poly(ci, [Vector2(22, -72), Vector2(0, -76), Vector2(0, -68), Vector2(20, -66)], Color(0.9, 0.85, 0.75))
			ci.draw_line(Vector2(14, -72), Vector2(14, -96), Style.GOLD_DIM, 2.0)
			Art.poly(ci, [Vector2(4, -96), Vector2(24, -96), Vector2(20, -104), Vector2(8, -104)], Color(0.1, 0.45, 0.25))
			Art.glow(ci, Vector2(14, -92), 18, Color(1.6, 1.4, 0.8, 0.35), 3)
			Art.text(ci, Vector2(0, -114), "THE PLAYBILL", 13, Style.GOLD, Style.font_mono, 160.0)
			if not GameData.tut.get("playbill", false):
				Art.text(ci, Vector2(0, -130), "NEW!", 12, Color(2.0, 1.6, 0.6), Style.font_mono, 80.0)
		"paint":
			# backstage vanity: bulb-ringed mirror, table, stool, wardrobe screen
			Art.shadow(ci, Vector2(0, 4), 48)
			for i in range(3):
				var sx = -62.0 + i * 14.0
				Art.poly(ci, [Vector2(sx, -2), Vector2(sx + 13, -6), Vector2(sx + 13, -86), Vector2(sx, -82)], Color(0.55, 0.12, 0.2) if i % 2 == 0 else Color(0.62, 0.16, 0.24))
			Art.rrect(ci, Rect2(-20, -34, 70, 10), 2, Color(0.4, 0.22, 0.1))
			ci.draw_line(Vector2(-16, -24), Vector2(-16, 0), Color(0.3, 0.16, 0.08), 3.0)
			ci.draw_line(Vector2(46, -24), Vector2(46, 0), Color(0.3, 0.16, 0.08), 3.0)
			Art.rrect(ci, Rect2(-8, -92, 46, 56), 4, Color(0.3, 0.22, 0.12))
			ci.draw_rect(Rect2(-3, -87, 36, 46), Color(0.55, 0.62, 0.72))
			ci.draw_line(Vector2(4, -80), Vector2(14, -70), Color(1, 1, 1, 0.35), 2.0)
			var bulbs = [Vector2(-8, -92), Vector2(7, -92), Vector2(23, -92), Vector2(38, -92), Vector2(-8, -74), Vector2(38, -74), Vector2(-8, -56), Vector2(38, -56)]
			for bi in range(bulbs.size()):
				var on = int(t * 2.0 + bi) % 7 != 0
				ci.draw_circle(bulbs[bi], 3.0, Color(2.2, 1.9, 1.2) if on else Color(0.7, 0.6, 0.4))
			ci.draw_circle(Vector2(0, -38), 3, Color(0.8, 0.2, 0.3))
			ci.draw_rect(Rect2(28, -40, 5, 6), Color(0.9, 0.8, 0.5))
			Art.ellipse(ci, Vector2(15, -10), 10, 4, Color(0.6, 0.1, 0.15))
			ci.draw_line(Vector2(15, -8), Vector2(15, 0), Color(0.5, 0.5, 0.55), 2.0)
			Art.text(ci, Vector2(0, -112), "DRESSING ROOM", 13, Style.GOLD, Style.font_mono, 180.0)
		"loom":
			# dangling from the rafters on a single silver thread
			var bob = sin(t * 1.3) * 4.0
			ci.draw_line(Vector2(0, -470), Vector2(0, -150 + bob), Color(0.9, 0.9, 1.0, 0.45), 1.0)
			Art.patron_portrait(ci, "tailor", t, Vector2(0, -40 + bob), 0.62)
			Art.text(ci, Vector2(0, -20), "LADY LOOM", 11, Color(1.0, 0.8, 0.5), Style.font_mono, 120.0)
		"door", "bass", "drums", "piano":
			pass

func _draw_hud():
	var c = hud_draw
	if swap_t >= 0.0:
		_draw_swap_hud(c)
		return
	var hat0 = GameData.get_equipped_hat()
	var tonight = "Tonight: %s as Ol' Tin Eyes, wearing %s (%s)" % [GameData.performer(1), GameData.hat_name(hat0), GameData.hat_grade(hat0)]
	var pw = maxf(440.0, Style.font_body.get_string_size(tonight, HORIZONTAL_ALIGNMENT_LEFT, -1, 13).x + 40.0)
	Art.rrect(c, Rect2(14, 12, pw, 70), 10, Color(0.03, 0.02, 0.04, 0.85))
	Art.note_glyph(c, Vector2(36, 36), 10, Style.GOLD)
	Art.text_left(c, Vector2(52, 44), "%d RP" % GameData.rhythm_points, 22, Style.GOLD, Style.font_mono)
	Art.record_glyph(c, Vector2(186, 36), 10, t)
	Art.text_left(c, Vector2(204, 44), "%d Records" % GameData.gold_records, 18, Style.CREAM, Style.font_mono)
	Art.text_left(c, Vector2(310, 44), "%d Tokens" % GameData.tokens, 18, Color(1.0, 0.75, 0.6), Style.font_mono)
	Art.text_left(c, Vector2(28, 70), tonight, 13, GameData.hat_grade_color(hat0), Style.font_body)
	Art.text(c, Vector2(640, 706), "WASD move    SPACE dash    E interact    ESC main menu", 13, Style.MUTED, Style.font_mono, 900.0)
	if overlay == null:
		var obj = _objective()
		var otxt = String(obj[0])
		var ow = Style.font_body.get_string_size(otxt, HORIZONTAL_ALIGNMENT_LEFT, -1, 15).x + 90.0
		var orect = Rect2(1266 - ow, 12, ow, 40)
		Art.rrect(c, orect, 10, Color(0.03, 0.02, 0.04, 0.88))
		c.draw_rect(orect, Color(Style.GOLD.r, Style.GOLD.g, Style.GOLD.b, 0.5 + 0.3 * sin(t * 3.0)), false, 2.0)
		Art.text_left(c, orect.position + Vector2(14, 26), "NEXT", 14, Style.GOLD, Style.font_mono)
		Art.text_left(c, orect.position + Vector2(66, 26), otxt, 15, Style.CREAM, Style.font_body)
		for s2 in stations:
			if s2["id"] == obj[1]:
				var ap: Vector2 = s2["pos"] + Vector2(0, -165 + sin(t * 5.0) * 8.0)
				if s2["id"] == "door":
					ap = Vector2(1100, 70 + sin(t * 5.0) * 8.0)
				if s2["id"] in ["bar", "slots", "jukebox", "paint", "playbill"]:
					ap = s2["pos"] + Vector2(0, -135 + sin(t * 5.0) * 8.0)
				var ac = Color(2.0, 1.6, 0.6)
				Art.poly(c, [ap + Vector2(-14, -12), ap + Vector2(14, -12), ap + Vector2(0, 8)], ac)
				c.draw_line(ap + Vector2(0, -12), ap + Vector2(0, -30), ac, 5.0)
	if overlay == null and not leaving:
		var s = _nearest_station()
		if s != null:
			var txt = String(s["label"])
			if s["id"] == "slots":
				txt = "[E] Hat-O-Matic  -  next roll: %s" % GameData.roll_label()
			var pp: Vector2 = s["pos"] + Vector2(0, 60 if s["id"] in ["door", "fame", "bass", "drums", "piano"] else -170)
			if s["id"] in ["bar", "jukebox", "slots", "paint"]:
				pp = s["pos"] + Vector2(0, -120)
			elif s["id"] == "loom":
				pp = s["pos"] + Vector2(0, 46)
			elif s["id"] == "playbill":
				pp = s["pos"] + Vector2(0, 58)
			var w = Style.font_body.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 16).x + 28.0
			var r = Rect2(pp.x - w * 0.5, pp.y - 22, w, 30)
			r.position.x = clampf(r.position.x, 8, 1272 - w)
			Art.rrect(c, r, 8, Color(0.04, 0.03, 0.05, 0.92))
			c.draw_rect(r, Style.GOLD_DIM, false, 1.5)
			Art.text(c, Vector2(r.get_center().x, pp.y - 1), txt, 16, Style.CREAM, null, w)
	if speech_t > 0.0 and speech != "":
		var a = minf(1.0, speech_t * 2.0)
		var bp = speech_pos
		var tw_ = Style.font_body.get_string_size(speech, HORIZONTAL_ALIGNMENT_LEFT, -1, 16).x
		var w2 = minf(620.0, tw_ + 30.0)
		var lines_n = int(ceil(tw_ / maxf(1.0, w2 - 30.0))) if tw_ > 590.0 else 1
		var bh = 12.0 + 22.0 * float(lines_n)
		var bx = clampf(bp.x - w2 * 0.5, 8.0, 1272.0 - w2)
		var br = Rect2(bx, maxf(90.0, bp.y - bh), w2, bh)
		Art.rrect(c, br, 10, Color(0.95, 0.92, 0.85, 0.95 * a))
		Art.poly(c, [Vector2(bp.x - 10, bp.y), Vector2(bp.x + 10, bp.y), Vector2(bp.x, bp.y + 14)], Color(0.95, 0.92, 0.85, 0.95 * a))
		var lab_y = br.position.y + 23.0
		if lines_n <= 1:
			c.draw_string(Style.font_body, Vector2(br.position.x + 15, lab_y), speech, HORIZONTAL_ALIGNMENT_LEFT, w2 - 20, 16, Color(0.1, 0.06, 0.05, a))
		else:
			c.draw_multiline_string(Style.font_body, Vector2(br.position.x + 15, lab_y), speech, HORIZONTAL_ALIGNMENT_LEFT, w2 - 30, 16, -1, Color(0.1, 0.06, 0.05, a))
