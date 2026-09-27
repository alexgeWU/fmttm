extends Node2D

## The Run (Hades-style).
## Biomes: Smoky Bar -> Neon Alley -> Grand Casino -> The Moon.
## Each room shows its exits up front with the reward you'll get for clearing the next room.
## Rewards: Boons, Encores (level-ups), Tailor mods, RP, Chips, Martinis, Gold Records.
## Special rooms: Speakeasy (shop), Powder Room (rest), Jackpot (gamble), Elite fights, Bosses.

const Art = preload("res://scripts/art.gd")
const BoonData = preload("res://scripts/boon_data.gd")
const WorldData = preload("res://scripts/world_data.gd")
const RoomBG = preload("res://scripts/room_bg.gd")
const PlayerScript = preload("res://scripts/player.gd")
const EnemyScript = preload("res://scripts/enemy.gd")
const BossScript = preload("res://scripts/boss.gd")
const FXScript = preload("res://scripts/fx.gd")
const DrawLayer = preload("res://scripts/draw_layer.gd")
const HudScript = preload("res://scripts/hud.gd")
const ChoiceScript = preload("res://scripts/choice_ui.gd")

signal run_over(won: bool)

const SHOP_ITEMS = {
	"boon": {"name": "Headliner's Favor", "desc": "Choose a boon", "price": 85},
	"martini": {"name": "Dirty Martini", "desc": "Heal 50% health", "price": 40},
	"encore": {"name": "Encore", "desc": "Level up a boon", "price": 70},
	"mod": {"name": "Lady Loom's Visit", "desc": "A hat mod for this run", "price": 100},
	"rp": {"name": "Sheet Music", "desc": "+60 Rhythm Points", "price": 30},
	"olive": {"name": "Olive Garnish", "desc": "+20 max health", "price": 60},
}

var arena: Rect2 = Rect2(70, 140, 1140, 540)

var player = null
var boss = null
var fx = null
var hud = null
var choice = null
var room_bg = null
var world: Node2D
var ground: Node2D
var shots_layer: Node2D
var cam: Camera2D
var canvas_mod: CanvasModulate
var lights_root: Node2D
var fade: ColorRect

var enemies: Array = []
var pshots: Array = []
var eshots: Array = []
var telegraphs: Array = []
var zones: Array = []
var pickups: Array = []
var bolts: Array = []
var beams: Array = []
var spawns: Array = []
var ground_flashes: Array = []
var doors: Array = []
var doors_open: bool = false
var interactables: Array = []
var room_nodes: Array = []
var obstacles: Array = []
var reward: Dictionary = {}
var waves: Array = []
var state: String = "intro"
var state_t: float = 0.0
var room_type: String = "combat"
var room_reward: Dictionary = {}
var t: float = 0.0
var pickup_combo: int = 0
var pickup_combo_t: float = 0.0
var boss_kind: String = ""
var jackpot_busy: bool = false
var room_id: int = 0
var _interact_queued: bool = false
var cameo: Dictionary = {}

func _ready():
	GameData.new_run()
	canvas_mod = CanvasModulate.new()
	add_child(canvas_mod)
	room_bg = RoomBG.new()
	room_bg.z_index = -10
	add_child(room_bg)
	var unshaded = CanvasItemMaterial.new()
	unshaded.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED
	ground = DrawLayer.new()
	ground.z_index = -5
	ground.material = unshaded
	ground.draw_func = _draw_ground
	add_child(ground)
	world = Node2D.new()
	world.y_sort_enabled = true
	add_child(world)
	shots_layer = DrawLayer.new()
	shots_layer.z_index = 10
	shots_layer.material = unshaded
	shots_layer.draw_func = _draw_shots
	add_child(shots_layer)
	fx = FXScript.new()
	fx.z_index = 20
	add_child(fx)
	lights_root = Node2D.new()
	add_child(lights_root)
	cam = Camera2D.new()
	cam.position = Vector2(640, 360)
	add_child(cam)
	cam.make_current()
	_build_walls()
	var hud_layer = CanvasLayer.new()
	hud_layer.layer = 50
	add_child(hud_layer)
	hud = HudScript.new()
	hud.room = self
	hud_layer.add_child(hud)
	var ui_layer = CanvasLayer.new()
	ui_layer.layer = 60
	ui_layer.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(ui_layer)
	choice = ChoiceScript.new()
	ui_layer.add_child(choice)
	var fade_layer = CanvasLayer.new()
	fade_layer.layer = 70
	add_child(fade_layer)
	fade = ColorRect.new()
	fade.color = Color(0, 0, 0, 0)
	fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	fade_layer.add_child(fade)
	player = PlayerScript.new()
	player.setup(self, false)
	player.died.connect(_on_player_died)
	world.add_child(player)
	_enter_room({"type": "combat", "reward": {"kind": "boon", "patron": _rand_patron([])}}, true)
	if GameData.lvl("start_boon") > 0:
		call_deferred("_offer_boon", _rand_patron([]), false, Callable())

func _build_walls():
	var walls = StaticBody2D.new()
	walls.collision_layer = 1
	walls.collision_mask = 0
	var A = arena
	var rects = [
		Rect2(A.position.x - 100, A.position.y - 100, A.size.x + 200, 100),
		Rect2(A.position.x - 100, A.end.y, A.size.x + 200, 100),
		Rect2(A.position.x - 100, A.position.y, 100, A.size.y),
		Rect2(A.end.x, A.position.y, 100, A.size.y),
	]
	for r in rects:
		var cs = CollisionShape2D.new()
		var sh = RectangleShape2D.new()
		sh.size = r.size
		cs.shape = sh
		cs.position = r.get_center()
		walls.add_child(cs)
	add_child(walls)

# ---------------------------------------------------------------------------
# ROOM FLOW
# ---------------------------------------------------------------------------
func _rand_patron(exclude: Array) -> String:
	var ps = []
	for k in BoonData.PATRONS.keys():
		if not (k in exclude):
			ps.append(k)
	if ps.is_empty():
		ps = BoonData.PATRONS.keys()
	return String(ps.pick_random())

func _enter_room(door: Dictionary, first: bool = false):
	var run = GameData.run
	if door.get("next_biome", false):
		run["biome"] = int(run["biome"]) + 1
		run["room"] = 0
		run["shop_seen_in_biome"] = false
	elif not first:
		run["room"] = int(run["room"]) + 1
	run["depth"] = int(run["depth"]) + 1
	room_type = String(door.get("type", "combat"))
	room_reward = door.get("reward", {})
	room_id += 1
	_clear_room()
	var b = WorldData.biome(int(run["biome"]))
	boss_kind = String(b["boss"]) if room_type == "boss" else ""
	var info = room_bg.build(int(run["biome"]), room_type, arena, boss_kind)
	var amb: Color = b["ambient"]
	if room_type == "boss":
		amb = amb.darkened(0.15)
	canvas_mod.color = amb
	fx.ambient = String(info["ambient"])
	fx.ambient_rect = arena
	for l in info["lights"]:
		var pl = PointLight2D.new()
		pl.texture = Style.light_tex
		pl.position = l["pos"]
		pl.color = l["color"]
		pl.energy = float(l["energy"])
		pl.texture_scale = float(l["scale"])
		lights_root.add_child(pl)
	for o in info["obstacles"]:
		_add_obstacle(o)
	if room_reward.get("kind", "") == "boon" and room_type != "boss":
		_setup_cameo(String(room_reward.get("patron", "luna")))
	elif room_reward.get("kind", "") == "hat_mod":
		_setup_cameo("tailor")
	player.global_position = Vector2(640, arena.end.y - 34)
	player.velocity = Vector2.ZERO
	player.facing = Vector2.UP
	player.start_room()
	state = "intro"
	state_t = 0.7
	# every room type has its own genre: swing bar, bebop alley, mambo casino, exotica moon,
	# bossa speakeasy, ballad powder room, mambo jackpot, big-band shout bosses
	var mus = String(b["music"])
	if room_type == "boss":
		mus = "boss"
	elif room_type in ["shop", "rest", "jackpot"]:
		mus = room_type
	Sfx.set_music(mus)
	match room_type:
		"combat", "elite":
			waves = _make_waves(room_type == "elite")
			doors = _make_doors()
		"boss":
			_spawn_boss(String(b["boss"]))
			doors = []
		"shop":
			_setup_shop()
			doors = _make_doors()
		"rest":
			_setup_rest()
			doors = _make_doors()
		"jackpot":
			_setup_jackpot()
			doors = _make_doors()
	if int(run["room"]) == 0 and room_type != "boss":
		hud.show_title(String(b["name"]), String(b["sub"]), 3.2)
	if first:
		hud.banner("TONIGHT: %s as OL' TIN EYES" % GameData.performer(0).to_upper(), Color(1.0, 0.85, 0.55), 3.0, 26)
	if first and int(GameData.stats.get("runs", 0)) <= 3:
		hud.hint("J / Z  attack (hold it)     K / X  special     L / C  Showstopper hat-slam\nSPACE  dash - you're invincible mid-dash, so dash THROUGH bullets", 11.0)
	elif room_type == "shop" and GameData.tut_once("shop"):
		hud.hint("Walk up to an item and press E to buy it with Chips.\nChips only last this run, so spend them!", 8.0)
	elif room_type == "jackpot" and GameData.tut_once("jackpot"):
		hud.hint("Pull the slot machine with E. It costs Chips, or health if you're broke.", 7.0)
	elif room_type == "elite" and GameData.tut_once("elite"):
		hud.hint("Gold-ringed ELITES hit harder but give better rewards.", 6.0)
	elif room_type == "elite":
		hud.banner("ELITE ENCOUNTER", Color(1.0, 0.75, 0.25), 1.8, 34)
	elif room_type == "shop":
		hud.banner("THE SPEAKEASY", Color(1.0, 0.8, 0.45), 1.8, 34)
	elif room_type == "rest":
		hud.banner("THE POWDER ROOM", Color(1.0, 0.6, 0.8), 1.8, 34)
	elif room_type == "jackpot":
		hud.banner("JACKPOT ROOM", Color(1.0, 0.9, 0.3), 1.8, 34)

func _clear_room():
	for e in enemies:
		if is_instance_valid(e):
			e.queue_free()
	enemies.clear()
	if boss != null and is_instance_valid(boss):
		boss.queue_free()
	boss = null
	for n in room_nodes:
		if is_instance_valid(n):
			n.queue_free()
	room_nodes.clear()
	for l in lights_root.get_children():
		l.queue_free()
	obstacles.clear()
	pshots.clear()
	eshots.clear()
	telegraphs.clear()
	zones.clear()
	pickups.clear()
	bolts.clear()
	beams.clear()
	spawns.clear()
	ground_flashes.clear()
	interactables.clear()
	doors.clear()
	doors_open = false
	reward = {}
	waves = []
	jackpot_busy = false
	cameo = {}
	fx.clear()

func _add_obstacle(o: Dictionary):
	var node = DrawLayer.new()
	node.position = o["pos"]
	node.draw_func = _draw_obstacle.bind(String(o["kind"]))
	world.add_child(node)
	var body = StaticBody2D.new()
	body.collision_layer = 1
	body.collision_mask = 0
	var cs = CollisionShape2D.new()
	var sh = CircleShape2D.new()
	sh.radius = float(o["r"])
	cs.shape = sh
	cs.position = Vector2(0, -4)
	body.add_child(cs)
	node.add_child(body)
	room_nodes.append(node)
	obstacles.append(o)

## The Headliner whose boon this room offers (or Lady Loom, for Tailor rooms) watches from
## a box seat. They show up for 5 seconds, duck out during the fight, and come back when
## the room is cleared (or when you go down).
const CAMEO_SHOW_SECS = 5.0

func _setup_cameo(pid: String):
	var left = randf() < 0.5
	var pos = Vector2(150.0 if left else 1130.0, arena.position.y + 72.0)
	var ch = BoonData.character(pid)
	cameo = {"patron": pid, "pos": pos, "cheer": 0.0, "show_t": CAMEO_SHOW_SECS, "vis": 0.0, "stay": false}
	var node = DrawLayer.new()
	node.position = pos
	node.draw_func = _draw_cameo
	node.modulate = Color(1, 1, 1, 0)
	world.add_child(node)
	var body = StaticBody2D.new()
	body.collision_layer = 1
	body.collision_mask = 0
	var cs = CollisionShape2D.new()
	var sh = CircleShape2D.new()
	sh.radius = 38.0
	cs.shape = sh
	cs.position = Vector2(0, -10)
	body.add_child(cs)
	node.add_child(body)
	room_nodes.append(node)
	var pl = PointLight2D.new()
	pl.texture = Style.light_tex
	pl.position = pos + Vector2(0, -70)
	pl.color = ch.get("color", Style.GOLD)
	pl.energy = 0.0
	pl.texture_scale = 1.0
	lights_root.add_child(pl)
	cameo["node"] = node
	cameo["shape"] = cs
	cameo["light"] = pl
	cameo["solid"] = true
	Sfx.play("sting_" + pid, 1.0, -6.0)
	hud.say("%s: %s" % [ch.get("name", "?"), String(ch.get("lines", ["..."]).pick_random())], pos + Vector2(0, -100), CAMEO_SHOW_SECS - 0.5)

func _cameo_return(line: String):
	if cameo.is_empty():
		return
	cameo["stay"] = true
	cameo["cheer"] = 2.0
	var ch = BoonData.character(String(cameo["patron"]))
	hud.say("%s: %s" % [ch.get("name", "?"), line], (cameo["pos"] as Vector2) + Vector2(0, -100), 3.5)

func _update_cameo(delta: float):
	if cameo.is_empty():
		return
	cameo["show_t"] = float(cameo["show_t"]) - delta
	var want = float(cameo["show_t"]) > 0.0 or cameo["stay"]
	var vis = move_toward(float(cameo["vis"]), 1.0 if want else 0.0, delta * 2.5)
	cameo["vis"] = vis
	cameo["cheer"] = maxf(0.0, float(cameo["cheer"]) - delta)
	var node = cameo.get("node")
	if node != null and is_instance_valid(node):
		node.modulate = Color(1, 1, 1, vis)
		node.position = (cameo["pos"] as Vector2) + Vector2(0, (1.0 - vis) * 40.0)
		node.visible = vis > 0.01
	var pl = cameo.get("light")
	if pl != null and is_instance_valid(pl):
		pl.energy = vis
	# only block movement while actually on stage
	var solid = vis > 0.5
	if solid != cameo["solid"]:
		cameo["solid"] = solid
		var cs = cameo.get("shape")
		if cs != null and is_instance_valid(cs):
			cs.set_deferred("disabled", not solid)

func _draw_cameo(ci: CanvasItem):
	if cameo.is_empty():
		return
	var pid = String(cameo["patron"])
	var pd = BoonData.character(pid)
	var pc: Color = pd.get("color", Style.GOLD)
	var cheer = float(cameo.get("cheer", 0.0))
	var bob = absf(sin(t * 9.0)) * 8.0 * minf(1.0, cheer) + sin(t * 1.5) * 1.5
	if pid == "tailor":
		# Lady Loom just drops down on her thread, web behind her
		for i in range(6):
			var a = PI + PI * float(i) / 5.0
			ci.draw_line(Vector2(0, -150), Vector2(0, -150) + Vector2(cos(a), sin(a) * 0.4) * 60.0, Color(0.9, 0.9, 1.0, 0.25), 1.0)
		for r in [20.0, 38.0, 56.0]:
			ci.draw_arc(Vector2(0, -150), r, PI, TAU, 10, Color(0.9, 0.9, 1.0, 0.2), 1.0)
		Art.patron_portrait(ci, pid, t, Vector2(0, -8 - bob), 0.7)
		Art.text(ci, Vector2(0, 14), "LADY LOOM", 11, Color(pc.r * 1.3, pc.g * 1.3, pc.b * 1.3), Style.font_mono, 120.0)
		return
	Art.shadow(ci, Vector2(0, 4), 56)
	Art.rrect(ci, Rect2(-54, -154, 108, 120), 8, Color(pc.r * 0.25, pc.g * 0.12, pc.b * 0.2 + 0.08))
	for i in range(5):
		ci.draw_line(Vector2(-46 + i * 23, -150), Vector2(-46 + i * 23, -40), Color(0, 0, 0, 0.25), 3.0)
	Art.patron_portrait(ci, pid, t, Vector2(0, -24 - bob), 0.62)
	if cheer > 0.0:
		for i in range(4):
			var a2 = t * 3.0 + TAU * float(i) / 4.0
			Art.star(ci, Vector2(cos(a2) * 44, -120 + sin(a2) * 10), 5, 2, 5, Color(pc.r * 1.6, pc.g * 1.6, pc.b * 1.6), t)
	Art.rrect(ci, Rect2(-56, -42, 112, 42), 6, Color(0.35, 0.16, 0.08))
	ci.draw_rect(Rect2(-56, -42, 112, 5), Style.GOLD)
	Art.text(ci, Vector2(0, -12), String(pd.get("name", "")).to_upper(), 11, Color(pc.r * 1.3, pc.g * 1.3, pc.b * 1.3), Style.font_mono, 120.0)

func _draw_obstacle(ci: CanvasItem, k: String):
	RoomBG.draw_obstacle(ci, k, t)

func _weighted(pool: Array) -> String:
	var total = 0
	for e in pool:
		total += int(e[1])
	var r = randi() % maxi(1, total)
	var acc = 0
	for e in pool:
		acc += int(e[1])
		if r < acc:
			return String(e[0])
	return String(pool[0][0])

func _make_waves(elite: bool) -> Array:
	var run = GameData.run
	var b = WorldData.biome(int(run["biome"]))
	var r = int(run["room"])
	var bi = int(run["biome"])
	var budget = 4.0 + r * 1.7 + bi * 2.5
	var n_waves = 2 if r < 2 else 3   # the last fight before the breather is the big one
	if bi == 0 and r == 0:
		n_waves = 1
		budget = 4.0
	if elite:
		n_waves = 2
	var pool = []
	for e in b["pool"]:
		if int(e[2]) <= r:
			pool.append(e)
	var result = []
	for w in range(n_waves):
		var wave = []
		var bud = budget * (0.8 + 0.25 * w)
		var guard = 0
		while bud > 0.0 and guard < 40:
			guard += 1
			var pick = _weighted(pool)
			wave.append({"type": pick, "elite": false})
			bud -= float(WorldData.ENEMIES[pick]["cost"])
		result.append(wave)
	var last: Array = result[result.size() - 1]
	if elite:
		last.append({"type": String(b["elite"]), "elite": true})
		if bi >= 2:
			last.append({"type": _weighted(pool), "elite": true})
	elif r >= 2 and randf() < 0.3:
		last.append({"type": _weighted(pool), "elite": true})
	return result

func _spawn_boss(k: String):
	boss = BossScript.new()
	boss.setup(k, self, 1.0)
	var y = arena.position.y + 170.0
	if k == "big_band":
		y = arena.position.y + 110.0
	elif k == "moon_man":
		y = arena.position.y + 150.0
	boss.position = Vector2(640, y)
	world.add_child(boss)
	hud.boss_intro(k)
	hud.boss_tip = String(WorldData.BOSSES.get(k, {}).get("tip", ""))
	hud.boss_tip_t = 20.0
	hud.boss_fight_t = 0.0
	Sfx.play("roar")
	fx.shake(8.0)

func random_spawn_pos(min_dist: float) -> Vector2:
	for i in range(40):
		var p = Vector2(randf_range(arena.position.x + 50, arena.end.x - 50), randf_range(arena.position.y + 50, arena.end.y - 40))
		if p.distance_to(player.global_position) < min_dist:
			continue
		var blocked = false
		for o in obstacles:
			if p.distance_to(o["pos"]) < float(o["r"]) + 26.0:
				blocked = true
				break
		if not blocked:
			return p
	return Vector2(640, arena.position.y + 120)

func _spawn_wave(list: Array):
	var i = 0
	for w in list:
		spawns.append({"pos": random_spawn_pos(230.0), "type": w["type"], "elite": w["elite"], "t": 0.0, "dur": 0.9 + i * 0.08})
		i += 1
	Sfx.play("spawn")

## Public: used by bosses to summon adds (with a spawn marker)
func spawn_enemy(k: String, pos: Vector2, elite: bool):
	var p = pos
	p.x = clampf(p.x, arena.position.x + 30, arena.end.x - 30)
	p.y = clampf(p.y, arena.position.y + 30, arena.end.y - 30)
	spawns.append({"pos": p, "type": k, "elite": elite, "t": 0.0, "dur": 0.8})

func _create_enemy(k: String, pos: Vector2, elite: bool):
	var e = EnemyScript.new()
	var run = GameData.run
	var hp_mult = 1.0 + 0.06 * float(run["depth"]) + 0.2 * float(run["biome"])
	var dmg_mult = 1.0 + 0.15 * float(run["biome"]) + 0.02 * float(run["room"])
	e.setup(k, self, hp_mult, dmg_mult, elite)
	e.position = pos
	world.add_child(e)
	enemies.append(e)
	fx.burst(pos + Vector2(0, -16), Color(1.4, 1.2, 0.9, 0.8), 12, 150.0, 3.0, "spark", 0.3)
	fx.ring(pos, Color(1.5, 1.3, 1.0, 0.7), 5.0, 40.0, 0.25, 3.0)

func get_targets() -> Array:
	var out = []
	for e in enemies:
		if is_instance_valid(e) and not e.dead:
			out.append(e)
	if boss != null and is_instance_valid(boss) and not boss.dead:
		out.append(boss)
	return out

func _alive_count() -> int:
	var n = 0
	for e in enemies:
		if is_instance_valid(e) and not e.dead:
			n += 1
	return n

func on_enemy_killed(e):
	GameData.run["kills"] = int(GameData.run["kills"]) + 1
	enemies.erase(e)

# ---------------------------------------------------------------------------
# DOORS & REWARDS
# ---------------------------------------------------------------------------
func _any_levelable() -> bool:
	for b in GameData.run["boons"]:
		if int(b["level"]) < BoonData.MAX_LEVEL:
			return true
	return false

func _rand_reward(used_kinds: Array, used_patrons: Array) -> Dictionary:
	var run = GameData.run
	var pool = [["boon", 42], ["rp", 14], ["chips", 12], ["martini", 10], ["hat_mod", 7]]
	if GameData.lvl("unlock_encore") > 0 and _any_levelable():
		pool.append(["encore", 14])
	var filtered = []
	for p in pool:
		if p[0] == "boon" or not (p[0] in used_kinds):
			filtered.append(p)
	var k = _weighted(filtered)
	var r = {"kind": k}
	if k == "boon":
		var pat = _rand_patron(used_patrons)
		r["patron"] = pat
		used_patrons.append(pat)
	used_kinds.append(k)
	return r

func _gen_door_options() -> Array:
	var run = GameData.run
	var b = WorldData.biome(int(run["biome"]))
	var rooms = int(b["rooms"])
	var nxt = int(run["room"]) + 1
	if room_type == "boss":
		if int(run["biome"]) >= WorldData.BIOMES.size() - 1:
			return []
		return [{"type": "combat", "reward": {"kind": "boon", "patron": _rand_patron([])}, "next_biome": true}]
	if nxt == rooms:
		return [{"type": "boss", "reward": {"kind": "records"}}]
	if nxt == rooms - 1:
		var o = [{"type": "rest", "reward": {}}]
		if GameData.lvl("unlock_shop") > 0:
			o.append({"type": "shop", "reward": {}})
		else:
			o.append({"type": "combat", "reward": _rand_reward([], [])})
		return o
	var count = 2
	var x = randf()
	if x < 0.22:
		count = 3
	elif x < 0.32:
		count = 1
	var used_kinds = []
	var used_patrons = []
	var used_types = []
	var opts = []
	for i in range(count):
		var rtype = "combat"
		var y = randf()
		if nxt >= 1 and y < 0.16 and not ("elite" in used_types):
			rtype = "elite"
		elif GameData.lvl("unlock_jackpot") > 0 and y < 0.26 and not ("jackpot" in used_types):
			rtype = "jackpot"
		elif GameData.lvl("unlock_shop") > 0 and y < 0.36 and not ("shop" in used_types) and not run.get("shop_seen_in_biome", false):
			rtype = "shop"
		used_types.append(rtype)
		var rew = {}
		if rtype == "combat" or rtype == "elite":
			rew = _rand_reward(used_kinds, used_patrons)
			if rtype == "elite" and rew["kind"] == "boon":
				rew["bonus"] = true
		opts.append({"type": rtype, "reward": rew})
	return opts

func _make_doors() -> Array:
	var opts = _gen_door_options()
	var xs = [[640.0], [440.0, 840.0], [300.0, 640.0, 980.0]]
	var out = []
	if opts.is_empty():
		return out
	var row: Array = xs[opts.size() - 1]
	for i in range(opts.size()):
		var o = opts[i]
		out.append({"x": float(row[i]), "type": o["type"], "reward": o["reward"], "next_biome": o.get("next_biome", false), "glow": 0.0})
	return out

func _open_doors():
	if state == "exit" or state == "dead" or state == "victory":
		return
	if doors_open:
		return
	doors_open = true
	if not doors.is_empty():
		Sfx.play("door")
		for d in doors:
			fx.burst(Vector2(float(d["x"]), arena.position.y - 40), Color(1.6, 1.3, 0.8), 14, 160.0, 3.0, "spark", 0.5)

func _room_cleared():
	state = "cleared"
	if not cameo.is_empty():
		_cameo_return("Hold still, dearie. Come get your fitting." if cameo["patron"] == "tailor" else "Bravo! Come get your reward, tin man.")
	if GameData.tut_once("reward"):
		hud.hint("Grab the glowing reward, then walk into a door.\nThe icon above each door shows what the NEXT room will give you.", 9.0)
	hud.banner("ROOM CLEARED", Color(1.0, 0.9, 0.6), 1.2, 30)
	Sfx.play("levelup", 1.0, -4.0)
	if GameData.lvl("regen") > 0:
		player.heal(3.0 * GameData.lvl("regen"))
	if room_type == "combat" or room_type == "elite":
		var tip = int((8 + 4 * int(GameData.run["biome"]) + (10 if room_type == "elite" else 0)) * (1.0 + player.bv("fortuna_tip") / 100.0))
		GameData.run["chips"] = int(GameData.run["chips"]) + tip
		fx.text(player.center() + Vector2(0, -44), "+%d chips (tips)" % tip, Color(1.0, 0.6, 0.6), 16)
	if room_reward.is_empty():
		_open_doors()
	else:
		reward = {"pos": Vector2(640, 410), "kind": room_reward["kind"], "patron": room_reward.get("patron", ""), "bonus": room_reward.get("bonus", false), "t": 0.0}
		fx.burst(reward["pos"], Color(1.8, 1.5, 0.8), 24, 220.0, 3.0, "spark", 0.6)
		fx.ring(reward["pos"], Color(1.8, 1.5, 0.8, 0.9), 10.0, 90.0, 0.5, 4.0)

func _collect_reward():
	var r = reward
	reward = {}
	var run = GameData.run
	fx.burst(r["pos"], Color(1.8, 1.5, 0.8), 30, 260.0, 3.0, "confetti", 1.0)
	Sfx.play("boon")
	match String(r["kind"]):
		"boon":
			_offer_boon(String(r["patron"]), r.get("bonus", false), _open_doors)
		"encore":
			_offer_encore(_open_doors)
		"hat_mod":
			_offer_mod(_open_doors)
		"rp":
			var amt = int((20 + int(run["depth"]) * 4) * (1.0 + player.bv("fortuna_tip") / 100.0))
			run["rp"] = int(run["rp"]) + amt
			hud.banner("+%d RHYTHM POINTS" % amt, Style.GOLD, 1.5, 30)
			Sfx.play("coin")
			_open_doors()
		"chips":
			var amt2 = int((90 + 25 * int(run["biome"])) * (1.0 + player.bv("fortuna_tip") / 100.0))
			run["chips"] = int(run["chips"]) + amt2
			hud.banner("+%d CHIPS" % amt2, Color(1.0, 0.5, 0.5), 1.5, 30)
			Sfx.play("chip")
			_open_doors()
		"martini":
			run["bonus_max_hp"] = int(run["bonus_max_hp"]) + 15
			player.recompute()
			player.heal(15.0)
			hud.banner("DIRTY MARTINI  +15 MAX HP", Color(0.6, 1.0, 0.5), 1.8, 30)
			_open_doors()
		"records":
			var n = int(WorldData.BOSSES.get(boss_kind, {"rec": 1})["rec"])
			run["records"] = int(run["records"]) + n
			player.heal(player.max_hp * 0.3)
			hud.banner("+%d GOLD RECORD%s" % [n, "S" if n > 1 else ""], Style.GOLD, 2.0, 34)
			Sfx.play("jackpot")
			_open_doors()
		_:
			_open_doors()

func _offer_boon(patron: String, bonus: bool = false, after: Callable = Callable()):
	var run = GameData.run
	var luck = GameData.lvl("boon_rarity") + (4 if bonus else 0)
	var offers = BoonData.offer_boons(patron, run["boons"], luck)
	if offers.is_empty():
		run["rp"] = int(run["rp"]) + 30
		hud.banner("+30 RHYTHM POINTS", Style.GOLD)
		if after.is_valid():
			after.call()
		return
	var pdata = BoonData.PATRONS[patron]
	var cards = []
	for o in offers:
		var bd = BoonData.BOONS[o["id"]]
		var r = int(o["rarity"])
		var tag = "%s  -  %s" % [String(pdata["name"]).to_upper(), BoonData.slot_label(String(bd["slot"]))]
		if bd["slot"] == "duo":
			tag = "DUO  -  %s & %s" % [BoonData.PATRONS[bd["patron"]]["name"], BoonData.PATRONS[bd["patron2"]]["name"]]
		var foot = ""
		var s = String(bd["slot"])
		var lvl_to = int(o.get("level", 1))
		var title = String(bd["name"])
		var desc = BoonData.boon_desc(o["id"], r, lvl_to)
		if o.get("upgrade", false):
			title += "  LV %d" % lvl_to
			tag = "LEVEL UP  -  LV %d -> %d of %d" % [lvl_to - 1, lvl_to, BoonData.MAX_LEVEL]
			foot = "Was: " + BoonData.boon_desc(o["id"], r, lvl_to - 1) + "\n"
		else:
			var mates = PackedStringArray()
			for other in player.slot_ids(s):
				mates.append(String(BoonData.BOONS[other]["name"]))
			if not mates.is_empty():
				foot = "STACKS with " + ", ".join(mates) + "\n"
		foot += "Lasts this run"
		cards.append({"title": title, "tag": tag, "desc": desc, "rarity_name": BoonData.RARITY_NAMES[r] + ("" if not o.get("upgrade", false) else "  (level up)"), "color": BoonData.RARITY_COLORS[r], "accent": pdata["color"], "footer": foot})
	var line = String(pdata["lines"].pick_random())
	var reroll_cb = Callable()
	if int(run["rerolls"]) > 0:
		reroll_cb = func():
			run["rerolls"] = int(run["rerolls"]) - 1
			_offer_boon(patron, bonus, after)
	var on_pick = func(i):
		_take_boon(offers[i])
		if after.is_valid():
			after.call()
	choice.open_cards(String(pdata["name"]), "\"" + line + "\"", cards, on_pick, patron, reroll_cb, int(run["rerolls"]))

func _take_boon(o: Dictionary):
	if not cameo.is_empty():
		cameo["cheer"] = 3.0
	if GameData.tut_once("boon"):
		hud.hint("Boons power you up for THIS RUN only.\nPermanent upgrades live on The Setlist back in the lounge. Press TAB to review boons.", 9.0)
	var bd = BoonData.BOONS[o["id"]]
	var new_lv = player.add_boon(o["id"], int(o["rarity"]))
	var label = String(bd["name"]).to_upper()
	if new_lv > 1:
		label += "  LV %d!" % new_lv
		Sfx.play("levelup")
	hud.banner(label, BoonData.RARITY_COLORS[int(o["rarity"])], 1.6, 32)
	fx.burst(player.center(), BoonData.patron_color(o["id"]), 24, 200.0, 3.0, "spark", 0.6)
	fx.ring(player.center(), BoonData.patron_color(o["id"]), 10.0, 80.0, 0.4, 4.0)

func _offer_encore(after: Callable = Callable()):
	var owned = []
	for b in GameData.run["boons"]:
		if int(b["level"]) < BoonData.MAX_LEVEL:
			owned.append(b)
	if owned.is_empty():
		_offer_boon(_rand_patron([]), false, after)
		return
	owned.shuffle()
	var picks = owned.slice(0, mini(3, owned.size()))
	var cards = []
	for b in picks:
		var bd = BoonData.BOONS[b["id"]]
		var r = int(b["rarity"])
		var lv = int(b["level"])
		cards.append({"title": String(bd["name"]) + "  LV %d" % (lv + 1), "tag": "ENCORE  -  LV %d -> %d of %d" % [lv, lv + 1, BoonData.MAX_LEVEL], "desc": BoonData.boon_desc(b["id"], r, lv + 1), "rarity_name": BoonData.RARITY_NAMES[r], "color": BoonData.RARITY_COLORS[r], "accent": BoonData.patron_color(b["id"]), "footer": "Was: " + BoonData.boon_desc(b["id"], r, lv)})
	var on_pick = func(i):
		player.level_boon(picks[i]["id"])
		hud.banner("LEVEL UP!", Style.GOLD, 1.4, 34)
		Sfx.play("levelup")
		if after.is_valid():
			after.call()
	choice.open_cards("ENCORE!", "The crowd wants more. Pick a boon to level up.", cards, on_pick)

func _offer_mod(after: Callable = Callable()):
	var cands = []
	for k in BoonData.HAT_MODS.keys():
		if not player.mods.has(k):
			cands.append(k)
	if cands.is_empty():
		GameData.run["rp"] = int(GameData.run["rp"]) + 40
		if after.is_valid():
			after.call()
		return
	cands.shuffle()
	var picks = cands.slice(0, mini(3, cands.size()))
	var cards = []
	for k in picks:
		var md = BoonData.HAT_MODS[k]
		cards.append({"title": md["name"], "tag": "LADY LOOM'S STITCHING", "desc": md["desc"], "rarity_name": "Hat Mod", "color": Style.GOLD, "accent": Color(0.9, 0.85, 0.7), "footer": "Lasts for this run."})
	var on_pick = func(i):
		player.add_mod(picks[i])
		hud.banner(String(BoonData.HAT_MODS[picks[i]]["name"]).to_upper(), Style.GOLD, 1.5, 32)
		if after.is_valid():
			after.call()
	choice.open_cards("LADY LOOM", "\"" + String(BoonData.TAILOR["lines"].pick_random()) + "\"", cards, on_pick, "tailor")

func _go_through(d: Dictionary):
	state = "exit"
	player.input_locked = true
	Sfx.play("door")
	if d["type"] == "shop":
		GameData.run["shop_seen_in_biome"] = true
	var tw = create_tween()
	tw.tween_property(fade, "color:a", 1.0, 0.35)
	tw.tween_callback(func():
		if state == "dead" or state == "over":
			return
		_enter_room(d)
		player.input_locked = false
	)
	tw.tween_property(fade, "color:a", 0.0, 0.35)

# ---------------------------------------------------------------------------
# SPECIAL ROOMS
# ---------------------------------------------------------------------------
func _add_interactable(it: Dictionary, collide_r: float = 0.0):
	var node = DrawLayer.new()
	node.position = it["pos"]
	node.draw_func = _draw_interactable.bind(it)
	world.add_child(node)
	if collide_r > 0.0:
		var body = StaticBody2D.new()
		body.collision_layer = 1
		body.collision_mask = 0
		var cs = CollisionShape2D.new()
		var sh = CircleShape2D.new()
		sh.radius = collide_r
		cs.shape = sh
		body.add_child(cs)
		node.add_child(body)
		obstacles.append({"pos": it["pos"], "r": collide_r, "kind": "prop"})
	room_nodes.append(node)
	interactables.append(it)

func _setup_shop():
	var keys = ["boon", "martini", "mod", "rp", "olive"]
	if GameData.lvl("unlock_encore") > 0 and _any_levelable():
		keys.append("encore")
		keys.append("encore")
	keys.shuffle()
	var chosen = []
	for k in keys:
		if not (k in chosen):
			chosen.append(k)
		if chosen.size() >= 3:
			break
	var disc = 1.0 - 0.1 * GameData.lvl("shop_discount")
	for i in range(chosen.size()):
		var k2 = String(chosen[i])
		var price = int(round(float(SHOP_ITEMS[k2]["price"]) * disc))
		_add_interactable({"pos": Vector2(440 + i * 200, 360), "kind": "shop", "item": k2, "price": price, "used": false, "label": "[E] %s  -  %d chips" % [SHOP_ITEMS[k2]["name"], price]}, 0.0)
	state = "cleared"
	_open_doors_later(0.6)

func _setup_rest():
	_add_interactable({"pos": Vector2(640, 400), "kind": "fountain", "used": false, "label": "[E] Champagne Fountain  -  heal 40%"}, 30.0)
	state = "cleared"
	_open_doors_later(0.6)

func _setup_jackpot():
	_add_interactable({"pos": Vector2(640, 400), "kind": "slot", "used": false, "label": "[E] Pull the lever  -  30 chips (or 20% health)"}, 30.0)
	state = "cleared"
	_open_doors_later(0.6)

func _open_doors_later(delay: float):
	var rid = room_id
	get_tree().create_timer(delay).timeout.connect(func():
		if rid == room_id:
			_open_doors()
	)

func _use_interactable(it: Dictionary):
	var run = GameData.run
	match String(it["kind"]):
		"shop":
			var price = int(it["price"])
			if int(run["chips"]) < price:
				Sfx.play("error")
				fx.text(it["pos"] + Vector2(0, -70), "Not enough chips", Color(1, 0.4, 0.4), 18)
				return
			run["chips"] = int(run["chips"]) - price
			it["used"] = true
			Sfx.play("buy")
			fx.burst(it["pos"] + Vector2(0, -30), Style.GOLD, 20, 180.0, 3.0, "confetti", 0.8)
			match String(it["item"]):
				"boon": _offer_boon(_rand_patron([]), false, Callable())
				"martini": player.heal(player.max_hp * 0.5)
				"encore": _offer_encore(Callable())
				"mod": _offer_mod(Callable())
				"rp":
					run["rp"] = int(run["rp"]) + 60
					hud.banner("+60 RHYTHM POINTS", Style.GOLD)
				"olive":
					run["bonus_max_hp"] = int(run["bonus_max_hp"]) + 20
					player.recompute()
					player.heal(20.0)
		"fountain":
			it["used"] = true
			player.heal(player.max_hp * 0.4)
			fx.burst(it["pos"] + Vector2(0, -40), Color(1.8, 1.6, 1.0), 30, 160.0, 3.0, "ember", 1.0)
			hud.banner("REFRESHED", Color(1.0, 0.7, 0.85), 1.4, 32)
		"slot":
			if jackpot_busy:
				return
			if int(run["chips"]) >= 30:
				run["chips"] = int(run["chips"]) - 30
			else:
				var cost = player.hp * 0.2
				player.hp = maxf(1.0, player.hp - cost)
				fx.damage_number(player.center(), cost, false, Color(1, 0.4, 0.4))
			it["used"] = true
			jackpot_busy = true
			it["spin"] = 1.4
			Sfx.play("lever")
			var rid = room_id
			get_tree().create_timer(1.4).timeout.connect(func():
				if rid == room_id:
					_jackpot_result()
			)

func _jackpot_result():
	jackpot_busy = false
	if state == "exit" or state == "dead":
		return
	var run = GameData.run
	var r = randf()
	if r < 0.3:
		Sfx.play("jackpot")
		fx.burst(Vector2(640, 340), Style.GOLD, 60, 360.0, 4.0, "confetti", 1.5)
		choice.open_message("JACKPOT!", "The Headliners are impressed. Take a Heroic-grade favor.", Style.GOLD, func(): _offer_boon(_rand_patron([]), true, Callable()))
	elif r < 0.5:
		run["chips"] = int(run["chips"]) + 120
		Sfx.play("jackpot")
		choice.open_message("CHIPS GALORE", "+120 chips rain from the machine.", Color(1.0, 0.5, 0.5))
	elif r < 0.68:
		run["rp"] = int(run["rp"]) + 80
		Sfx.play("coin")
		choice.open_message("SWEET MUSIC", "+80 Rhythm Points.", Style.GOLD)
	elif r < 0.83:
		player.heal(player.max_hp)
		choice.open_message("ON THE HOUSE", "Fully healed. Somebody likes you.", Color(0.6, 1.0, 0.6))
	else:
		Sfx.play("error")
		choice.open_message("BUST!", "The house wins. It always does.", Color(1.0, 0.4, 0.4))

# ---------------------------------------------------------------------------
# PUBLIC COMBAT API
# ---------------------------------------------------------------------------
func add_telegraph(d: Dictionary):
	d["t"] = 0.0
	if not d.has("color"):
		d["color"] = Color(1.0, 0.18, 0.12)
	telegraphs.append(d)

func cancel_telegraphs(owner_node):
	var keep = []
	for tg in telegraphs:
		if tg.get("owner") == owner_node:
			continue
		keep.append(tg)
	telegraphs = keep

func clear_enemy_shots():
	eshots.clear()
	telegraphs.clear()

func add_zone(z: Dictionary):
	z["tick"] = 0.0
	z["max"] = float(z["life"])
	zones.append(z)

func add_bolt(a: Vector2, b: Vector2, col: Color):
	var pts = PackedVector2Array()
	var n = 7
	for i in range(n + 1):
		var k = float(i) / float(n)
		var p = a.lerp(b, k)
		if i > 0 and i < n:
			p += (b - a).orthogonal().normalized() * randf_range(-10, 10)
		pts.append(p)
	bolts.append({"pts": pts, "t": 0.16, "c": col})

func ground_flash(pos: Vector2, r: float, col: Color):
	ground_flashes.append({"pos": pos, "r": r, "c": col, "t": 0.0})

func boss_callout(atk_name: String, hint: String):
	hud.callout = {"name": atk_name, "hint": hint, "t": 0.0}

func banner(text: String, col: Color):
	hud.banner(text, col, 1.6, 30)

func spawn_player_shot(d: Dictionary):
	if not d.has("life"):
		d["life"] = 1.0
	if not d.has("r"):
		d["r"] = 7.0
	if not d.has("pierce"):
		d["pierce"] = 0
	if not d.has("ricochet"):
		d["ricochet"] = 0
	if not d.has("boomerang"):
		d["boomerang"] = false
	d["hit"] = []
	d["t"] = 0.0
	if not d.has("color"):
		d["color"] = Style.CREAM
	pshots.append(d)

func spawn_player_lob(from: Vector2, to: Vector2, dmg: float):
	pshots.append({"lob": true, "from": from, "to": to, "t": 0.0, "dur": 0.45, "dmg": dmg, "kind": "match"})

func spawn_enemy_shot(d: Dictionary):
	if not d.has("life"):
		d["life"] = 4.5
	if not d.has("r"):
		d["r"] = 8.0
	if not d.has("bounce"):
		d["bounce"] = 0
	if not d.has("homing"):
		d["homing"] = 0.0
	d["t"] = 0.0
	if not d.has("color"):
		match String(d.get("kind", "orb")):
			"flash": d["color"] = Color(2.4, 2.3, 1.8)
			"card": d["color"] = Color(1.0, 1.0, 1.0)
			"note": d["color"] = Color(0.5, 1.4, 1.8)
			"cap": d["color"] = Color(1.8, 1.4, 0.5)
			"coin": d["color"] = Color(2.0, 1.6, 0.5)
			"bullet": d["color"] = Color(2.2, 1.4, 0.5)
			"star": d["color"] = Color(2.0, 1.9, 0.9)
			"crescent": d["color"] = Color(1.6, 1.6, 2.2)
			_: d["color"] = Color(1.8, 0.4, 0.4)
	eshots.append(d)

func drop_rp(pos: Vector2, base: int):
	var mult = (1.0 + 0.1 * GameData.lvl("rp_gain")) * (1.0 + player.bv("fortuna_tip") / 100.0)
	var total = maxi(1, int(round(float(base) * mult)))
	while total > 0:
		var v = mini(total, randi_range(1, 3))
		total -= v
		var a = randf() * TAU
		pickups.append({"pos": pos + Vector2(0, -14), "vel": Vector2(cos(a), sin(a)) * randf_range(80, 220), "kind": "rp", "amount": v, "t": 0.0})

func drop_chips(pos: Vector2, amount: int):
	var total = maxi(1, int(round(float(amount) * (1.0 + player.bv("fortuna_tip") / 100.0))))
	var a = randf() * TAU
	pickups.append({"pos": pos + Vector2(0, -14), "vel": Vector2(cos(a), sin(a)) * 140.0, "kind": "chip", "amount": total, "t": 0.0})

# ---------------------------------------------------------------------------
# CALLBACKS
# ---------------------------------------------------------------------------
func on_player_hurt(_d: float):
	hud.flash_hurt()

func on_curtain_call():
	hud.banner("CURTAIN CALL!", Style.GOLD, 2.2, 44)
	fx.burst(player.center(), Style.GOLD, 50, 300.0, 4.0, "confetti", 1.4)
	fx.ring(player.center(), Color(2.0, 1.6, 0.6, 0.9), 10.0, 200.0, 0.6, 6.0)
	Sfx.play("jackpot")
	eshots.clear()

func on_boss_dying(_b):
	spawns.clear()
	var kz = []
	for z in zones:
		if z["kind"] != "enemy_fire":
			kz.append(z)
	zones = kz
	for e in enemies.duplicate():
		if is_instance_valid(e) and not e.dead:
			e.hp = 0.0
			e._die()

func on_boss_killed(b):
	if state == "dead" or state == "over":
		return
	var run = GameData.run
	run["bosses"] = int(run["bosses"]) + 1
	var pos: Vector2 = b.global_position
	drop_rp(pos, 30 + 20 * int(run["biome"]))
	drop_chips(pos, 40 + 20 * int(run["biome"]))
	if int(run["biome"]) >= WorldData.BIOMES.size() - 1:
		_victory()
		return
	state = "cleared"
	var rp = Vector2(clampf(pos.x, arena.position.x + 60, arena.end.x - 60), clampf(pos.y + 40, arena.position.y + 80, arena.end.y - 60))
	room_reward = {"kind": "records"}
	reward = {"pos": rp, "kind": "records", "patron": "", "t": 0.0}
	doors = _make_doors()
	doors_open = false
	hud.banner("SHOWSTOPPER!", Style.GOLD, 2.4, 48)

func _victory():
	state = "victory"
	player.invuln_t = 999.0
	GameData.run["won"] = true
	Sfx.set_music("victory")
	hud.show_title("OL' TIN EYES PLAYS THE MOON", "%s headlines the night sky. Standing ovation from here to Saturn." % GameData.performer(0), 3.8)
	for i in range(6):
		fx.burst(Vector2(randf_range(200, 1080), randf_range(200, 500)), Color.from_hsv(randf(), 0.6, 1.8), 30, 300.0, 4.0, "confetti", 2.0)
	get_tree().create_timer(4.0).timeout.connect(func(): _end_run(true))

func _on_player_died():
	if state == "dead" or state == "victory" or state == "over":
		return
	state = "dead"
	if not cameo.is_empty():
		_cameo_return("Take a bow, kid. The show goes on.")
	Sfx.play("death")
	Sfx.set_music("quiet")
	GameData.hitstop(0.5, 0.2)
	fx.burst(player.center(), Color(1.6, 1.4, 1.0), 40, 300.0, 4.0, "shard", 1.0)
	fx.shake(14.0)
	var b = WorldData.biome(int(GameData.run["biome"]))
	var killer = player.last_hit_by if player.last_hit_by != "" else "the spotlight"
	hud.show_title("%s TAKES A BOW" % GameData.performer(0).to_upper(), "Knocked out by %s in %s. You keep every Rhythm Point. The show must go on: %s steps into the hat." % [killer, b["name"], GameData.performer(1)], 3.6)
	get_tree().create_timer(3.6).timeout.connect(func(): _end_run(false))

func _end_run(won: bool):
	if state == "over":
		return
	state = "over"
	GameData.end_run(won, player.last_hit_by)
	run_over.emit(won)

func _give_up():
	if state == "dead" or state == "victory" or state == "over":
		return
	player.alive = false
	player.hp = 0.0
	player.last_hit_by = "stage fright"
	_on_player_died()

func _unhandled_input(event):
	if event.is_action_pressed("interact"):
		_interact_queued = true
	if event.is_action_pressed("pause") or event.is_action_pressed("boon_list"):
		if state == "dead" or state == "victory" or state == "over" or choice.is_open():
			return
		get_viewport().set_input_as_handled()
		choice.open_pause(player, Callable(), _give_up)
	elif event.is_action_pressed("skip_round"):
		_give_up()

# ---------------------------------------------------------------------------
# MAIN LOOP
# ---------------------------------------------------------------------------
func _process(delta):
	t += delta
	cam.offset = Vector2(randf_range(-1, 1), randf_range(-1, 1)) * fx.shake_amount
	GameData.run["time"] = float(GameData.run.get("time", 0.0)) + delta

func _physics_process(delta):
	hud.prompt_text = ""
	pickup_combo_t -= delta
	if pickup_combo_t <= 0.0:
		pickup_combo = 0
	_update_spawns(delta)
	_update_pshots(delta)
	_update_eshots(delta)
	_update_telegraphs(delta)
	_update_zones(delta)
	_update_pickups(delta)
	_update_misc(delta)
	match state:
		"intro":
			state_t -= delta
			if state_t <= 0.0:
				if room_type == "combat" or room_type == "elite":
					state = "fight"
				elif room_type == "boss":
					state = "fight"
				else:
					state = "cleared"
		"fight":
			if room_type == "boss":
				pass
			elif spawns.is_empty():
				var alive = _alive_count()
				if not waves.is_empty() and alive <= 1:
					_spawn_wave(waves.pop_front())
				elif waves.is_empty() and alive == 0:
					_room_cleared()
		"cleared":
			_update_cleared()
	_interact_queued = false

func _update_cleared():
	if choice.is_open():
		return
	if not reward.is_empty() and float(reward.get("t", 0.0)) > 0.5:
		if player.global_position.distance_to(reward["pos"]) < 40.0:
			_collect_reward()
			return
	var best = null
	var bd = 70.0
	for it in interactables:
		if it["used"]:
			continue
		var d = player.global_position.distance_to(it["pos"])
		if d < bd:
			bd = d
			best = it
	if best != null:
		hud.prompt_text = String(best["label"])
		hud.prompt_pos = best["pos"] + Vector2(0, -92)
		if _interact_queued:
			_interact_queued = false
			_use_interactable(best)
	if doors_open:
		for d in doors:
			if absf(player.global_position.x - float(d["x"])) < 44.0 and player.global_position.y < arena.position.y + 36.0:
				_go_through(d)
				return

func _update_spawns(delta):
	var keep = []
	for s in spawns:
		s["t"] = float(s["t"]) + delta
		if float(s["t"]) >= float(s["dur"]):
			if state != "dead" and state != "over":
				_create_enemy(String(s["type"]), s["pos"], s["elite"])
		else:
			keep.append(s)
	spawns = keep

func _update_pshots(delta):
	var keep = []
	var targets = get_targets()
	for s in pshots:
		s["t"] = float(s["t"]) + delta
		if s.get("lob", false):
			if float(s["t"]) >= float(s["dur"]):
				_player_lob_land(s)
			else:
				keep.append(s)
			continue
		s["life"] = float(s["life"]) - delta
		if float(s["life"]) <= 0.0:
			continue
		var vel: Vector2 = s["vel"]
		if s["boomerang"] and float(s["t"]) > 0.42:
			var to: Vector2 = player.center() - s["pos"]
			vel = vel.lerp(to.normalized() * 720.0, minf(1.0, delta * 5.0))
			if to.length() < 26.0 and float(s["t"]) > 0.6:
				continue
		s["vel"] = vel
		s["pos"] = s["pos"] + vel * delta
		if not arena.grow(24.0).has_point(s["pos"]):
			if s["boomerang"]:
				s["vel"] = -vel
			else:
				fx.burst(s["pos"], s["color"], 4, 80.0, 2.0, "spark", 0.2)
				continue
		var consumed = false
		for e in targets:
			if e.dead:
				continue
			var eid = e.get_instance_id()
			if eid in s["hit"]:
				continue
			if s["pos"].distance_to(e.center()) < float(s["r"]) + float(e.radius):
				s["hit"].append(eid)
				player.hit_enemy(e, float(s["dmg"]), vel.normalized(), String(s["src"]), {"knock": 110.0, "coin": s.get("coin", false)})
				if int(s["ricochet"]) > 0:
					s["ricochet"] = int(s["ricochet"]) - 1
					var nxt = null
					var nd = 340.0
					for o in targets:
						if o.dead or (o.get_instance_id() in s["hit"]):
							continue
						var dd = o.center().distance_to(s["pos"])
						if dd < nd:
							nd = dd
							nxt = o
					if nxt != null:
						s["vel"] = (nxt.center() - s["pos"]).normalized() * vel.length()
						s["life"] = 1.0
						Sfx.play("chip", 1.3, -8.0)
					else:
						consumed = true
				elif int(s["pierce"]) > 0:
					s["pierce"] = int(s["pierce"]) - 1
				else:
					consumed = true
				break
		if not consumed:
			keep.append(s)
	pshots = keep

func _player_lob_land(s: Dictionary):
	var pos: Vector2 = s["to"]
	fx.burst(pos, Color(2.0, 0.8, 0.2), 20, 220.0, 3.0, "ember", 0.6)
	fx.ring(pos, Color(2.0, 0.8, 0.3, 0.9), 8.0, 70.0, 0.3, 5.0)
	Sfx.play("explode", 1.4, -6.0)
	for e in get_targets():
		if e.global_position.distance_to(pos) < 70.0 + float(e.radius):
			player.hit_enemy(e, float(s["dmg"]), (e.global_position - pos).normalized(), "special", {"knock": 200.0})
			if not e.dead:
				e.apply_status("burn", 8.0)
	add_zone({"pos": pos, "r": 60.0, "life": 3.0, "kind": "fire", "power": 8.0})

func _update_eshots(delta):
	var keep = []
	for s in eshots:
		s["t"] = float(s["t"]) + delta
		s["life"] = float(s["life"]) - delta
		if float(s["life"]) <= 0.0:
			continue
		var vel: Vector2 = s["vel"]
		if float(s["homing"]) > 0.0 and player.alive:
			s["homing"] = float(s["homing"]) - delta
			var want = (player.center() - s["pos"]).angle()
			var diff = wrapf(want - vel.angle(), -PI, PI)
			vel = vel.rotated(clampf(diff, -2.2 * delta, 2.2 * delta))
		var p: Vector2 = s["pos"] + vel * delta
		var A = arena.grow(12.0)
		if not A.has_point(p):
			if int(s["bounce"]) > 0:
				s["bounce"] = int(s["bounce"]) - 1
				if p.x < A.position.x or p.x > A.end.x:
					vel.x = -vel.x
				if p.y < A.position.y or p.y > A.end.y:
					vel.y = -vel.y
				p = s["pos"]
			else:
				continue
		s["vel"] = vel
		s["pos"] = p
		if player.alive and p.distance_to(player.center()) < float(s["r"]) + 9.0:
			if player.invuln_t <= 0.0 and player.dash_t <= 0.0:
				player.take_damage(float(s["dmg"]), vel.normalized(), String(s["src"]))
				fx.burst(p, s["color"], 6, 100.0, 2.0, "spark", 0.2)
				continue
		keep.append(s)
	eshots = keep

func _update_telegraphs(delta):
	var keep = []
	for tg in telegraphs:
		tg["t"] = float(tg["t"]) + delta
		var own = tg.get("owner")
		if own != null and (not is_instance_valid(own) or own.dead):
			continue
		if float(tg["t"]) >= float(tg["dur"]):
			_detonate(tg)
		else:
			keep.append(tg)
	telegraphs = keep

func _seg_dist(p: Vector2, a: Vector2, b: Vector2) -> float:
	var ab = b - a
	var l2 = ab.length_squared()
	if l2 < 0.001:
		return p.distance_to(a)
	var k = clampf((p - a).dot(ab) / l2, 0.0, 1.0)
	return p.distance_to(a + ab * k)

func _detonate(tg: Dictionary):
	var dmg = float(tg.get("dmg", 0.0))
	var pos: Vector2 = tg["pos"]
	if not tg.get("visual", false) and dmg > 0.0 and player.alive:
		var hit = false
		var pp: Vector2 = player.global_position
		if tg["shape"] == "circle":
			hit = pp.distance_to(pos) < float(tg["r"]) + 8.0
		else:
			var dirv: Vector2 = tg["dir"]
			hit = _seg_dist(pp, pos, pos + dirv * float(tg["len"])) < float(tg["w"]) * 0.5 + 8.0
		if hit:
			var kdir = (pp - pos).normalized() if pp.distance_to(pos) > 1.0 else Vector2.DOWN
			player.take_damage(dmg, kdir, String(tg.get("src", "a trap")))
	match String(tg.get("fx", "")):
		"slam":
			fx.ring(pos, Color(1.6, 0.6, 0.4, 0.9), 10.0, float(tg["r"]) + 10.0, 0.3, 6.0)
			fx.burst(pos, Color(0.8, 0.7, 0.6, 0.5), 10, 160.0, 8.0, "smoke", 0.6)
			fx.shake(5.0)
			Sfx.play("slam", 1.0, -5.0)
		"glass":
			fx.burst(pos, Color(0.4, 1.4, 0.6, 0.9), 16, 200.0, 3.0, "shard", 0.6)
			Sfx.play("glass", randf_range(0.9, 1.2), -4.0)
		"explode":
			fx.burst(pos, Color(2.0, 0.8, 0.2), 24, 260.0, 4.0, "ember", 0.7)
			fx.ring(pos, Color(2.0, 0.9, 0.4, 0.9), 10.0, float(tg.get("r", 60.0)) + 14.0, 0.3, 6.0)
			fx.shake(6.0)
			Sfx.play("explode", randf_range(0.9, 1.2), -4.0)
		"beam":
			var dirv2: Vector2 = tg["dir"]
			beams.append({"a": pos, "b": pos + dirv2 * float(tg["len"]), "w": float(tg["w"]), "t": 0.0})
			fx.shake(4.0)
			Sfx.play("zap", 0.6, -3.0)
	if tg.has("zone"):
		var z: Dictionary = tg["zone"].duplicate()
		z["pos"] = pos
		z["src"] = tg.get("src", "fire")
		add_zone(z)

func _update_zones(delta):
	var keep = []
	var targets = get_targets()
	for z in zones:
		z["life"] = float(z["life"]) - delta
		if float(z["life"]) <= 0.0:
			continue
		z["tick"] = float(z["tick"]) - delta
		if float(z["tick"]) <= 0.0:
			z["tick"] = 0.4
			var zp: Vector2 = z["pos"]
			if z["kind"] == "enemy_fire":
				if player.alive and player.global_position.distance_to(zp) < float(z["r"]):
					player.take_damage(float(z["power"]), Vector2.ZERO, String(z.get("src", "fire")))
			else:
				for e in targets:
					if not e.dead and e.global_position.distance_to(zp) < float(z["r"]) + float(e.radius):
						player.zone_tick(e, z)
		if z["kind"] != "frost" and randf() < 0.3:
			fx.burst(z["pos"] + Vector2(randf_range(-float(z["r"]), float(z["r"])) * 0.7, randf_range(-float(z["r"]), float(z["r"])) * 0.3), Color(2.0, 0.7, 0.15, 0.8), 1, 30.0, 3.0, "ember", 0.6)
		keep.append(z)
	zones = keep

func _update_pickups(delta):
	var keep = []
	var target: Vector2 = player.global_position + Vector2(0, -12)
	var vacuum = state == "cleared"
	for p in pickups:
		p["t"] = float(p["t"]) + delta
		var to: Vector2 = target - p["pos"]
		var d = to.length()
		var vel: Vector2 = p["vel"]
		if float(p["t"]) > 0.35 and (d < player.magnet_r or vacuum):
			vel = vel.lerp(to.normalized() * 640.0, minf(1.0, delta * 6.0))
		else:
			vel = vel * maxf(0.0, 1.0 - 4.0 * delta)
		p["vel"] = vel
		p["pos"] = p["pos"] + vel * delta
		if d < 22.0 and float(p["t"]) > 0.2:
			_collect_pickup(p)
			continue
		keep.append(p)
	pickups = keep

func _collect_pickup(p: Dictionary):
	var run = GameData.run
	pickup_combo += 1
	pickup_combo_t = 0.6
	match String(p["kind"]):
		"rp":
			run["rp"] = int(run["rp"]) + int(p["amount"])
			Sfx.play("coin", 1.0 + minf(0.6, pickup_combo * 0.04), -8.0)
		"chip":
			run["chips"] = int(run["chips"]) + int(p["amount"])
			fx.text(player.center() + Vector2(0, -30), "+%d chips" % int(p["amount"]), Color(1.0, 0.6, 0.6), 16)
			Sfx.play("chip")

func _update_misc(delta):
	var kb = []
	for b in bolts:
		b["t"] = float(b["t"]) - delta
		if float(b["t"]) > 0.0:
			kb.append(b)
	bolts = kb
	var kbm = []
	for b in beams:
		b["t"] = float(b["t"]) + delta
		if float(b["t"]) < 0.3:
			kbm.append(b)
	beams = kbm
	var kg = []
	for g in ground_flashes:
		g["t"] = float(g["t"]) + delta
		if float(g["t"]) < 0.4:
			kg.append(g)
	ground_flashes = kg
	if not reward.is_empty():
		reward["t"] = float(reward["t"]) + delta
	_update_cameo(delta)
	for it in interactables:
		if it.has("spin"):
			it["spin"] = maxf(0.0, float(it["spin"]) - delta)

# ---------------------------------------------------------------------------
# DRAWING: ground layer (under characters)
# ---------------------------------------------------------------------------
func _draw_ground(ci: CanvasItem):
	for g in ground_flashes:
		var k = float(g["t"]) / 0.4
		var c: Color = g["c"]
		var gp: Vector2 = g["pos"]
		Art.ellipse(ci, gp, float(g["r"]) * (0.6 + 0.4 * k), float(g["r"]) * 0.5 * (0.6 + 0.4 * k), Color(c.r, c.g, c.b, 0.3 * (1.0 - k)))
		# radial floor cracks
		for ci_ in range(9):
			var ca = TAU * float(ci_) / 9.0 + gp.x * 0.01
			var cl = float(g["r"]) * (0.45 + 0.2 * sin(float(ci_) * 3.7 + gp.y))
			var p0 = gp + Vector2(cos(ca), sin(ca) * 0.5) * 12.0
			var p1 = gp + Vector2(cos(ca + 0.15), sin(ca + 0.15) * 0.5) * cl * 0.55
			var p2 = gp + Vector2(cos(ca - 0.1), sin(ca - 0.1) * 0.5) * cl
			ci.draw_polyline(PackedVector2Array([p0, p1, p2]), Color(0.05, 0.03, 0.03, 0.55 * (1.0 - k)), 2.0)
			ci.draw_polyline(PackedVector2Array([p0, p1, p2]), Color(c.r, c.g, c.b, 0.5 * (1.0 - k)), 1.0)
	for z in zones:
		var k2 = clampf(float(z["life"]) / float(z["max"]), 0.0, 1.0)
		var zc = Color(1.6, 0.5, 0.1, 0.28 * minf(1.0, k2 * 3.0))
		if z["kind"] == "frost":
			zc = Color(0.6, 1.1, 1.8, 0.3 * minf(1.0, k2 * 3.0))
		elif z["kind"] == "enemy_fire":
			zc = Color(1.8, 0.3, 0.1, 0.35 * minf(1.0, k2 * 3.0))
		var r = float(z["r"])
		Art.ellipse(ci, z["pos"], r, r * 0.5, zc)
		Art.ellipse(ci, z["pos"], r * (0.6 + 0.1 * sin(t * 9.0)), r * 0.3, Color(zc.r, zc.g, zc.b, zc.a * 1.2))
	for tg in telegraphs:
		var k3 = clampf(float(tg["t"]) / float(tg["dur"]), 0.0, 1.0)
		var c3: Color = tg["color"]
		var visual = tg.get("visual", false)
		if tg["shape"] == "circle":
			var rr = float(tg["r"])
			Art.ellipse(ci, tg["pos"], rr, rr * 0.55, Color(c3.r, c3.g, c3.b, 0.14 + 0.1 * k3))
			Art.ellipse(ci, tg["pos"], rr * k3, rr * 0.55 * k3, Color(c3.r * 1.3, c3.g * 1.3, c3.b * 1.3, 0.28))
			Art.ellipse_line(ci, tg["pos"], rr, rr * 0.55, Color(c3.r * 1.5, c3.g * 1.5, c3.b * 1.5, 0.7 + 0.3 * sin(t * 30.0) * k3), 2.0)
			var tp: Vector2 = tg["pos"]
			for di in range(12):
				var da = t * 1.5 + TAU * float(di) / 12.0
				var dp0 = tp + Vector2(cos(da) * (rr + 5.0), sin(da) * (rr + 5.0) * 0.55)
				var dp1 = tp + Vector2(cos(da + 0.22) * (rr + 5.0), sin(da + 0.22) * (rr + 5.0) * 0.55)
				ci.draw_line(dp0, dp1, Color(c3.r * 1.6, c3.g * 1.6, c3.b * 1.6, 0.5 + 0.4 * k3), 2.0)
			if k3 > 0.8:
				Art.ellipse(ci, tp, rr, rr * 0.55, Color(c3.r * 1.8, c3.g * 1.8, c3.b * 1.8, (k3 - 0.8) * 1.2))
		else:
			var a: Vector2 = tg["pos"]
			var dirv: Vector2 = tg["dir"]
			var ln = float(tg["len"])
			var w = float(tg["w"]) * 0.5
			var side = dirv.orthogonal()
			var b = a + dirv * ln
			var quad = PackedVector2Array([a + side * w, b + side * w, b - side * w, a - side * w])
			var alpha = 0.12 + 0.12 * k3 if not visual else 0.08 + 0.1 * k3
			ci.draw_colored_polygon(quad, Color(c3.r, c3.g, c3.b, alpha))
			var bp = a + dirv * ln * k3
			if k3 > 0.02:
				var quad2 = PackedVector2Array([a + side * w, bp + side * w, bp - side * w, a - side * w])
				ci.draw_colored_polygon(quad2, Color(c3.r * 1.3, c3.g * 1.3, c3.b * 1.3, 0.18))
			ci.draw_line(a + side * w, b + side * w, Color(c3.r * 1.5, c3.g * 1.5, c3.b * 1.5, 0.6), 2.0)
			ci.draw_line(a - side * w, b - side * w, Color(c3.r * 1.5, c3.g * 1.5, c3.b * 1.5, 0.6), 2.0)
			# marching chevrons show which way it's coming
			var nch = int(ln / 70.0)
			for chi in range(nch):
				var f = fmod(float(chi) / float(maxi(1, nch)) + t * 0.8, 1.0)
				var cp = a + dirv * ln * f
				var cw_ = minf(w * 0.6, 18.0)
				ci.draw_polyline(PackedVector2Array([cp + side * cw_ - dirv * 8.0, cp, cp - side * cw_ - dirv * 8.0]), Color(c3.r * 1.6, c3.g * 1.6, c3.b * 1.6, 0.35 + 0.3 * k3), 2.0)
	for s in spawns:
		var k4 = clampf(float(s["t"]) / float(s["dur"]), 0.0, 1.0)
		var sp: Vector2 = s["pos"]
		var ec = Color(1.8, 1.4, 0.4) if s["elite"] else Color(1.5, 1.3, 1.1)
		Art.ellipse(ci, sp, 34.0 * (1.2 - k4 * 0.4), 14.0 * (1.2 - k4 * 0.4), Color(ec.r, ec.g, ec.b, 0.18 + 0.2 * k4))
		Art.ellipse_line(ci, sp, 30.0, 12.0, Color(ec.r, ec.g, ec.b, 0.6), 2.0)
		ci.draw_line(sp + Vector2(-14, -200.0 * (1.0 - k4)), sp + Vector2(-30, 0), Color(ec.r, ec.g, ec.b, 0.1 * k4), 2.0)
		ci.draw_line(sp + Vector2(14, -200.0 * (1.0 - k4)), sp + Vector2(30, 0), Color(ec.r, ec.g, ec.b, 0.1 * k4), 2.0)
	_draw_doors(ci)
	if not reward.is_empty():
		var base_p: Vector2 = reward["pos"]
		Art.ellipse(ci, base_p, 34, 13, Color(1.6, 1.3, 0.6, 0.25 + 0.1 * sin(t * 4.0)))
		# pedestal + light beam (floor layer, so it never paints over the robot)
		ci.draw_colored_polygon(PackedVector2Array([base_p + Vector2(-14, -200), base_p + Vector2(14, -200), base_p + Vector2(34, 0), base_p + Vector2(-34, 0)]), Color(1.4, 1.2, 0.8, 0.08))
		Art.ellipse(ci, base_p, 26, 8, Color(0.35, 0.25, 0.15, 0.9))
		Art.ellipse_line(ci, base_p, 26, 8, Style.GOLD, 2.0)

func _door_color(d: Dictionary) -> Color:
	var rw: Dictionary = d["reward"]
	match String(d["type"]):
		"shop": return Color(1.0, 0.75, 0.35)
		"rest": return Color(1.0, 0.55, 0.8)
		"jackpot": return Color(1.0, 0.9, 0.3)
		"boss": return Color(1.0, 0.25, 0.2)
	if rw.get("kind", "") == "boon":
		return BoonData.PATRONS[rw["patron"]]["color"]
	match String(rw.get("kind", "")):
		"rp": return Style.GOLD
		"chips": return Color(1.0, 0.4, 0.45)
		"martini": return Color(0.6, 1.0, 0.5)
		"encore": return Color(1.0, 0.85, 0.3)
		"hat_mod": return Color(0.95, 0.9, 0.8)
		"records": return Style.GOLD
	return Style.CREAM

func _draw_doors(ci: CanvasItem):
	var top = arena.position.y
	for d in doors:
		var x = float(d["x"])
		var col = _door_color(d)
		var fr = Rect2(x - 40, top - 104, 80, 104)
		Art.rrect(ci, fr.grow(6), 6, Color(0.05, 0.04, 0.05))
		if doors_open:
			var pulse = 0.7 + 0.3 * sin(t * 4.0)
			ci.draw_rect(fr, Color(col.r * 0.25, col.g * 0.25, col.b * 0.25))
			for i in range(5):
				var k = float(i) / 5.0
				ci.draw_rect(Rect2(fr.position.x + 6 + k * 18, fr.position.y + 8 + k * 30, fr.size.x - 12 - k * 36, fr.size.y - 8 - k * 30), Color(col.r * 1.4, col.g * 1.4, col.b * 1.4, 0.12 * pulse))
			Art.ellipse(ci, Vector2(x, top + 18), 70, 26, Color(col.r * 1.3, col.g * 1.3, col.b * 1.3, 0.22 * pulse))
			ci.draw_rect(fr, Color(col.r * 1.6, col.g * 1.6, col.b * 1.6, 0.9), false, 3.0)
		else:
			ci.draw_rect(fr, Color(0.25, 0.12, 0.07))
			ci.draw_line(Vector2(x, fr.position.y), Vector2(x, fr.end.y), Color(0.12, 0.06, 0.04), 3.0)
			for sx in [-1.0, 1.0]:
				ci.draw_rect(Rect2(x + sx * 20 - 12, fr.position.y + 12, 24, 36), Color(0.2, 0.1, 0.06))
				ci.draw_rect(Rect2(x + sx * 20 - 12, fr.position.y + 56, 24, 36), Color(0.2, 0.1, 0.06))
				ci.draw_circle(Vector2(x + sx * 6, fr.position.y + 60), 3, Style.GOLD)
			ci.draw_rect(fr, Color(0.5, 0.35, 0.2), false, 2.0)

# ---------------------------------------------------------------------------
# DRAWING: shots layer (over characters, unshaded)
# ---------------------------------------------------------------------------
func _reward_label(d: Dictionary) -> String:
	var rw: Dictionary = d["reward"]
	match String(d["type"]):
		"shop": return "SPEAKEASY"
		"rest": return "POWDER ROOM"
		"jackpot": return "JACKPOT"
		"boss": return "BOSS"
	var pre = "ELITE  " if d["type"] == "elite" else ""
	if d.get("next_biome", false):
		var nb = WorldData.biome(int(GameData.run["biome"]) + 1)
		return "ONWARD: " + String(nb["name"]).to_upper()
	match String(rw.get("kind", "")):
		"boon": return pre + String(BoonData.PATRONS[rw["patron"]]["name"]).to_upper()
		"rp": return pre + "RHYTHM POINTS"
		"chips": return pre + "CHIPS"
		"martini": return pre + "MARTINI"
		"encore": return pre + "ENCORE"
		"hat_mod": return pre + "LADY LOOM (TAILOR)"
		"records": return "GOLD RECORD"
	return pre + "???"

func _draw_reward_icon(ci: CanvasItem, pos: Vector2, kind: String, patron: String, s: float, door_type: String = ""):
	Art.reward_icon(ci, pos, kind, patron, s, door_type, t)

func _draw_shots(ci: CanvasItem):
	# door reward previews
	var top = arena.position.y
	for d in doors:
		var x = float(d["x"])
		var rw: Dictionary = d["reward"]
		var bob = sin(t * 2.5 + x) * 3.0
		var ip = Vector2(x, top - 128 + bob)
		if not doors_open:
			ip.y = top - 60
		_draw_reward_icon(ci, ip, String(rw.get("kind", "")), String(rw.get("patron", "")), 15.0 if not doors_open else 18.0, String(d["type"]) if not (d["type"] in ["combat", "elite"]) else "")
		var lc = _door_color(d)
		Art.text(ci, Vector2(x, top + 26), _reward_label(d), 12, Color(lc.r, lc.g, lc.b, 0.95 if doors_open else 0.55), Style.font_mono, 240.0)
		if d["type"] == "elite":
			Art.star(ci, ip + Vector2(20, -16), 6, 2.5, 5, Color(2.0, 1.5, 0.4), 0.0)
	# the reward item
	if not reward.is_empty():
		var rp: Vector2 = reward["pos"] + Vector2(0, -40 + sin(t * 3.0) * 6.0)
		var pat = String(reward.get("patron", ""))
		for ri in range(10):
			var ra = t * 0.8 + TAU * float(ri) / 10.0
			ci.draw_line(rp, rp + Vector2(cos(ra), sin(ra)) * 44.0, Color(1.6, 1.3, 0.7, 0.12), 6.0)
		_draw_reward_icon(ci, rp, String(reward["kind"]), pat, 22.0)
		var nm = ""
		match String(reward["kind"]):
			"boon": nm = String(BoonData.PATRONS[pat]["name"])
			"encore": nm = "Encore"
			"hat_mod": nm = "Lady Loom's fitting"
			"rp": nm = "Rhythm Points"
			"chips": nm = "Chips"
			"martini": nm = "Dirty Martini"
			"records": nm = "Gold Record"
		Art.text(ci, rp + Vector2(0, 46), nm, 14, Style.CREAM, Style.font_mono, 300.0)
	# pickups
	for p in pickups:
		var pp: Vector2 = p["pos"]
		var pt = float(p["t"])
		if p["kind"] == "rp":
			var pb = pp + Vector2(0, sin(pt * 6.0 + pp.x) * 2.0)
			Art.glow(ci, pb, 12.0, Color(1.6, 1.2, 0.3, 0.45), 2)
			Art.note_glyph(ci, pb, 7.0, Color(2.0, 1.6, 0.5))
			if fmod(pt * 3.0 + pp.x * 0.1, 1.0) < 0.15:
				Art.star(ci, pb + Vector2(5, -6), 3.0, 1.0, 4, Color(2.4, 2.2, 1.6), 0.0)
		else:
			ci.draw_set_transform(pp, 0.0, Vector2(absf(cos(pt * 8.0)) * 0.8 + 0.2, 1.0))
			Art.chip_glyph(ci, Vector2.ZERO, 6.0, Color(0.9, 0.15, 0.2))
			ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	# player shots
	for s in pshots:
		if s.get("lob", false):
			var k = clampf(float(s["t"]) / float(s["dur"]), 0.0, 1.0)
			var lp = (s["from"] as Vector2).lerp(s["to"], k) + Vector2(0, -sin(k * PI) * 90.0)
			Art.glow(ci, lp, 12, Color(2.0, 0.8, 0.2, 0.6), 3)
			ci.draw_line(lp, lp + Vector2(6, 6), Color(0.9, 0.8, 0.6), 3.0)
			Art.ellipse(ci, s["to"], 30, 12, Color(1.8, 0.6, 0.2, 0.2 * k))
			continue
		_draw_pshot(ci, s)
	# enemy shots
	for s in eshots:
		_draw_eshot(ci, s)
	# lobbed telegraph projectiles
	for tg in telegraphs:
		if tg.has("lob_from"):
			var k2 = clampf(float(tg["t"]) / float(tg["dur"]), 0.0, 1.0)
			var from: Vector2 = tg["lob_from"]
			var to: Vector2 = tg["pos"]
			var lk = String(tg.get("lob_kind", "bottle"))
			var h = 0.0 if lk == "meteor" else 120.0
			var lp2 = from.lerp(to, k2) + Vector2(0, -sin(k2 * PI) * h)
			match lk:
				"bottle":
					ci.draw_set_transform(lp2, t * 12.0, Vector2.ONE)
					Art.rrect(ci, Rect2(-4, -8, 8, 14), 2, Color(0.2, 0.8, 0.35))
					ci.draw_rect(Rect2(-1.5, -13, 3, 6), Color(0.2, 0.8, 0.35))
					ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
				"molotov":
					Art.glow(ci, lp2, 12, Color(2.0, 0.7, 0.2, 0.6), 3)
					ci.draw_circle(lp2, 5, Color(0.3, 0.6, 0.3))
				"meteor":
					var dirm = (to - from).normalized()
					Art.poly(ci, [lp2 - dirm * 80.0 + dirm.orthogonal() * 3.0, lp2 + dirm.orthogonal() * 12.0, lp2 - dirm.orthogonal() * 12.0, lp2 - dirm * 80.0 - dirm.orthogonal() * 3.0], Color(2.0, 1.0, 0.4, 0.5))
					ci.draw_circle(lp2, 11, Color(0.5, 0.45, 0.45))
					Art.glow(ci, lp2, 18, Color(2.2, 1.0, 0.4, 0.6), 3)
	# lightning & beams
	for b in bolts:
		var bc: Color = b["c"]
		var a = float(b["t"]) / 0.16
		ci.draw_polyline(b["pts"], Color(bc.r, bc.g, bc.b, a), 4.0)
		ci.draw_polyline(b["pts"], Color(2.5, 2.5, 2.5, a), 1.5)
	for bm in beams:
		var k3 = float(bm["t"]) / 0.3
		var w = float(bm["w"]) * (1.0 - k3 * 0.5)
		ci.draw_line(bm["a"], bm["b"], Color(1.6, 1.5, 2.2, 0.6 * (1.0 - k3)), w)
		ci.draw_line(bm["a"], bm["b"], Color(2.5, 2.5, 2.5, 0.9 * (1.0 - k3)), w * 0.35)

func _draw_pshot(ci: CanvasItem, s: Dictionary):
	var p: Vector2 = s["pos"]
	var v: Vector2 = s["vel"]
	var d = v.normalized()
	var c: Color = s["color"]
	var hc = Color(c.r * 1.6, c.g * 1.6, c.b * 1.6, 1.0)
	var st = float(s["t"])
	# motion trail behind every player shot
	var tr_len = minf(34.0, v.length() * 0.035)
	for ti in range(4):
		var tf = float(ti) / 4.0
		ci.draw_line(p - d * tr_len * tf, p - d * tr_len * (tf + 0.25), Color(hc.r, hc.g, hc.b, 0.28 * (1.0 - tf)), float(s.get("r", 6.0)) * (1.0 - tf) + 1.0)
	match String(s["kind"]):
		"pearl":
			Art.glow(ci, p, 10, Color(hc.r, hc.g, hc.b, 0.4), 2)
			ci.draw_circle(p, 5, Color(1.8, 1.8, 1.7))
		"bolt":
			ci.draw_line(p - d * 18.0, p, Color(0.5, 1.6, 2.2), 4.0)
			ci.draw_line(p - d * 18.0, p, Color(2.2, 2.2, 2.2), 1.5)
		"neon":
			ci.draw_line(p - d * 16.0, p, Color(2.2, 0.4, 1.8), 4.0)
		"bullet":
			ci.draw_line(p - d * 12.0, p, Color(2.2, 1.6, 0.6), 3.0)
		"clip":
			ci.draw_set_transform(p, st * 16.0, Vector2.ONE)
			Art.ellipse_line(ci, Vector2.ZERO, 8, 4, Color(1.6, 1.6, 1.7), 2.0, 12)
			ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		"feather":
			Art.poly(ci, [p + d * 10.0, p - d * 8.0 + d.orthogonal() * 4.0, p - d * 12.0, p - d * 8.0 - d.orthogonal() * 4.0], Color(1.8, 1.8, 1.8))
		"horseshoe":
			ci.draw_set_transform(p, st * 14.0, Vector2.ONE)
			ci.draw_arc(Vector2.ZERO, 10, 0.5, TAU - 0.5, 14, Color(1.4, 1.4, 1.5), 4.0)
			ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		"card":
			ci.draw_set_transform(p, st * 12.0, Vector2.ONE)
			ci.draw_rect(Rect2(-5, -7, 10, 14), Color(1.8, 1.8, 1.75))
			ci.draw_circle(Vector2.ZERO, 2.5, Color(0.9, 0.1, 0.15))
			ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		"chip":
			ci.draw_set_transform(p, 0.0, Vector2(absf(cos(st * 14.0)) * 0.8 + 0.2, 1.0))
			Art.chip_glyph(ci, Vector2.ZERO, 8.0, Color(1.4, 0.15, 0.2))
			ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		"dice":
			ci.draw_set_transform(p, st * 10.0, Vector2.ONE)
			Art.rrect(ci, Rect2(-7, -7, 14, 14), 3, Color(1.8, 1.8, 1.8))
			Art.text(ci, Vector2(0, 5), str(int(s.get("face", 1))), 12, Color(0.8, 0.1, 0.1), Style.font_mono, 20.0, false)
			ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		"coin":
			Art.glow(ci, p, 12, Color(2.0, 1.6, 0.4, 0.5), 2)
			Art.ellipse(ci, p, 7.0 * absf(cos(st * 16.0)) + 1.0, 7.0, Color(2.0, 1.6, 0.5))
		_:
			ci.draw_circle(p, float(s["r"]), hc)

func _draw_eshot(ci: CanvasItem, s: Dictionary):
	var p: Vector2 = s["pos"]
	var v: Vector2 = s["vel"]
	var c: Color = s["color"]
	var st = float(s["t"])
	var r = float(s["r"])
	var vd = v.normalized()
	ci.draw_line(p - vd * r * 0.8, p - vd * r * 3.0, Color(c.r, c.g, c.b, 0.18), r)
	ci.draw_circle(p, r + 3.0, Color(0.05, 0.0, 0.02, 0.55))
	ci.draw_arc(p, r + 3.0, 0, TAU, 16, Color(c.r * 1.3, c.g * 1.3, c.b * 1.3, 0.5), 1.2)
	match String(s["kind"]):
		"flash":
			Art.glow(ci, p, r * 2.4, Color(c.r, c.g, c.b, 0.5), 3)
			ci.draw_circle(p, r * 0.8, c)
		"card":
			ci.draw_set_transform(p, st * 10.0, Vector2.ONE)
			ci.draw_rect(Rect2(-6, -8, 12, 16), Color(1.5, 1.5, 1.45))
			ci.draw_rect(Rect2(-6, -8, 12, 16), Color(0.8, 0.1, 0.15), false, 1.5)
			ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		"note":
			Art.glow(ci, p, r * 1.8, Color(c.r, c.g, c.b, 0.35), 2)
			Art.note_glyph(ci, p, r * 1.1, c)
		"cap":
			ci.draw_circle(p, r, c)
			for i in range(8):
				var a = TAU * float(i) / 8.0 + st * 5.0
				ci.draw_circle(p + Vector2(cos(a), sin(a)) * r, 2.0, c.darkened(0.2))
		"coin":
			Art.ellipse(ci, p, r * absf(cos(st * 12.0)) + 1.5, r, c)
		"bullet":
			ci.draw_line(p - v.normalized() * 12.0, p, c, 4.0)
			ci.draw_circle(p, 3.0, Color(2.4, 2.2, 1.6))
		"record":
			Art.record_glyph(ci, p, r, st * 3.0)
			ci.draw_arc(p, r + 2, 0, TAU, 20, Color(2.0, 0.6, 0.6, 0.8), 2.0)
		"star":
			Art.glow(ci, p, r * 1.8, Color(c.r, c.g, c.b, 0.35), 2)
			Art.star(ci, p, r, r * 0.45, 5, c, st * 4.0)
		"crescent":
			Art.glow(ci, p, r * 1.8, Color(c.r, c.g, c.b, 0.35), 2)
			var ang = v.angle()
			var pts = PackedVector2Array()
			for i in range(13):
				var a2 = ang + deg_to_rad(-100.0 + 200.0 * float(i) / 12.0)
				pts.append(p + Vector2(cos(a2), sin(a2)) * r)
			for i in range(11, 0, -1):
				var a3 = ang + deg_to_rad(-80.0 + 160.0 * float(i) / 12.0)
				pts.append(p - Vector2(cos(ang), sin(ang)) * r * 0.45 + Vector2(cos(a3), sin(a3)) * r * 0.9)
			ci.draw_colored_polygon(pts, c)
		_:
			Art.glow(ci, p, r * 1.8, Color(c.r, c.g, c.b, 0.4), 2)
			ci.draw_circle(p, r * 0.75, c)
			ci.draw_circle(p, r * 0.35, Color(2.5, 2.5, 2.5))

func _draw_interactable(ci: CanvasItem, it: Dictionary):
	match String(it["kind"]):
		"shop":
			Art.shadow(ci, Vector2(0, 2), 34)
			Art.rrect(ci, Rect2(-32, -40, 64, 40), 5, Color(0.3, 0.15, 0.08))
			ci.draw_rect(Rect2(-32, -40, 64, 5), Style.GOLD_DIM)
			if not it["used"]:
				var bob = sin(t * 3.0 + float(it["pos"].x)) * 4.0
				var ip = Vector2(0, -70 + bob)
				match String(it["item"]):
					"boon": _draw_reward_icon(ci, ip, "boon", ["luna", "baron", "fortuna", "ivory", "bruno"][int(t) % 5], 16.0)
					"martini": Art.heart_glyph(ci, ip, 14.0, Color(0.8, 1.6, 1.8))
					"encore": _draw_reward_icon(ci, ip, "encore", "", 16.0)
					"mod": _draw_reward_icon(ci, ip, "hat_mod", "", 16.0)
					"rp": _draw_reward_icon(ci, ip, "rp", "", 16.0)
					"olive": Art.heart_glyph(ci, ip, 14.0, Color(0.6, 1.8, 0.6))
				Art.text(ci, Vector2(0, -16), "%d" % int(it["price"]), 14, Color(1.0, 0.7, 0.7), Style.font_mono, 80.0)
			else:
				Art.text(ci, Vector2(0, -16), "SOLD", 14, Style.MUTED, Style.font_mono, 80.0)
		"fountain":
			Art.shadow(ci, Vector2(0, 4), 44)
			Art.ellipse(ci, Vector2(0, -10), 40, 16, Color(0.8, 0.75, 0.7))
			Art.ellipse(ci, Vector2(0, -12), 34, 12, Color(1.2, 1.0, 0.6, 0.6) if not it["used"] else Color(0.3, 0.3, 0.35))
			for i in range(3):
				var y = -34.0 - i * 20.0
				var w = 26.0 - i * 7.0
				Art.poly(ci, [Vector2(-w, y), Vector2(w, y), Vector2(3, y + 16), Vector2(-3, y + 16)], Color(0.9, 0.95, 1.0, 0.7))
				ci.draw_line(Vector2(0, y + 16), Vector2(0, y + 22), Color(0.9, 0.95, 1.0, 0.7), 2.0)
			if not it["used"]:
				for i in range(6):
					var bt = fmod(t * 0.8 + i * 0.17, 1.0)
					ci.draw_circle(Vector2(sin(i * 2.0) * 16.0, -20.0 - bt * 70.0), 2.0, Color(2.0, 1.8, 1.0, 1.0 - bt))
		"slot":
			var spin = float(it.get("spin", 0.0))
			Art.shadow(ci, Vector2(0, 4), 40)
			Art.rrect(ci, Rect2(-36, -100, 72, 100), 10, Color(0.65, 0.08, 0.12))
			Art.rrect(ci, Rect2(-36, -100, 72, 14), 6, Style.GOLD)
			Art.rrect(ci, Rect2(-28, -76, 56, 26), 3, Color(0.95, 0.93, 0.88))
			for i in range(3):
				var cx = -18.0 + i * 18.0
				var sym = int(t * 14.0 + i * 3.0) % 3 if spin > float(i) * 0.4 else i
				match sym:
					0: ci.draw_circle(Vector2(cx, -63), 5, Color(0.9, 0.1, 0.1))
					1: Art.text(ci, Vector2(cx, -57), "7", 16, Color(0.9, 0.1, 0.1), Style.font_mono, 20.0, false)
					_: Art.star(ci, Vector2(cx, -63), 6, 2.5, 5, Style.GOLD, 0.0)
			for i in range(7):
				var on = int(t * 8.0 + i) % 2 == 0
				ci.draw_circle(Vector2(-27 + i * 9, -93), 2.5, Color(2.2, 1.8, 0.6) if on else Color(0.6, 0.4, 0.2))
			var la = 0.6 if spin > 1.0 else -0.5
			ci.draw_line(Vector2(36, -60), Vector2(36, -60) + Vector2(cos(la - PI * 0.5), sin(la - PI * 0.5)) * 30.0 + Vector2(8, 0), Color(0.85, 0.85, 0.9), 4.0)
			ci.draw_circle(Vector2(36, -60) + Vector2(cos(la - PI * 0.5), sin(la - PI * 0.5)) * 30.0 + Vector2(8, 0), 7, Color(0.9, 0.1, 0.1))
			if it["used"] and spin <= 0.0:
				Art.text(ci, Vector2(0, -20), "TAPPED OUT", 12, Style.MUTED, Style.font_mono, 120.0)
