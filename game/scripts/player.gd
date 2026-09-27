extends CharacterBody2D

## The Player: a dapper wind-up robot. The hat is the whole kit:
##   Band    -> Attack      (J / Z, hold to keep swinging)
##   Add-on  -> Special     (K / X)
##   Material-> Showstopper (L / C): the hat flies up and slams down
##   Dash    -> Space / Shift (charges)
## Boons from the Headliners modify each slot, Hades-style.

const Art = preload("res://scripts/art.gd")
const BoonData = preload("res://scripts/boon_data.gd")
const DrawLayer = preload("res://scripts/draw_layer.gd")

signal died

const BASE_ATK = 18.0
const BASE_SPECIAL = 16.0
const BASE_CAST = 22.0
const DASH_SPEED = 900.0
const DASH_TIME = 0.16
const CAST_WINDUP = 0.38

var room = null
var hub_mode: bool = false
var hp: float = 80.0
var max_hp: float = 80.0
var facing: Vector2 = Vector2.DOWN
var move_dir: Vector2 = Vector2.ZERO
var t: float = 0.0
var alive: bool = true
var input_locked: bool = false
var radius: float = 11.0

# --- derived stats ---
var speed: float = 190.0
var dmg_mult: float = 1.0
var atk_speed: float = 1.0
var crit_chance: float = 0.02
var crit_mult: float = 2.0
var special_mult: float = 1.0
var cast_mult: float = 1.0
var taken_mult: float = 1.0
var dodge: float = 0.0
var heal_mult: float = 1.0
var magnet_r: float = 90.0
var first_strike: float = 0.0
var elite_mult: float = 1.0
var dash_contact_dmg: float = 0.0
var atk_range_mult: float = 1.0

var hat: Dictionary = {}
var band_kit: Dictionary = {}
var addon_kit: Dictionary = {}
var mat_kit: Dictionary = {}

var boons: Dictionary = {}
var slots: Dictionary = {}
var mods: Array = []

# --- combat state ---
var atk_cd: float = 0.0
var atk_anim: float = 0.0
var atk_arc: float = 110.0
var atk_range: float = 64.0
var atk_melee: bool = true
var combo_i: int = -1
var combo_timer: float = 0.0
var special_cd: float = 0.0
var special_cd_max: float = 1.5
var burst_left: int = 0
var burst_timer: float = 0.0
var burst_dmg: float = 0.0
var cast_cd: float = 0.0
var cast_cd_max: float = 10.0
var casting: bool = false
var cast_t: float = 0.0
var dash_charges: int = 1
var dash_max: int = 1
var dash_recharge: float = 0.0
var dash_recharge_max: float = 0.9
var dash_t: float = 0.0
var dash_dir: Vector2 = Vector2.DOWN
var dash_hit: Array = []
var dash_trail_acc: float = 0.0
var invuln_t: float = 0.0
var hurt_flash: float = 0.0
var shield: int = 0
var hedge_ready: bool = false
var ghosts: Array = []
var last_hit_by: String = ""
var ninth_used: bool = false
var atk_counter: int = 0

var hat_root: Node2D
var hat_node: Node2D
var hat_lift: float = 0.0
var hat_tilt: float = 0.0
var light: PointLight2D
var hat_fx: Node2D

func setup(room_ref, hub: bool):
	room = room_ref
	hub_mode = hub

func _ready():
	motion_mode = CharacterBody2D.MOTION_MODE_FLOATING
	collision_layer = 2
	collision_mask = 1
	var col = CollisionShape2D.new()
	var sh = CircleShape2D.new()
	sh.radius = radius
	col.shape = sh
	col.position = Vector2(0, -6)
	add_child(col)
	light = PointLight2D.new()
	light.texture = Style.light_tex
	light.texture_scale = 1.5
	light.energy = 0.6
	light.color = Color(1.0, 0.88, 0.75)
	light.position = Vector2(0, -24)
	add_child(light)
	hat_root = Node2D.new()
	hat_root.position = Vector2(0, Art.HEAD_TOP)
	add_child(hat_root)
	hat_fx = DrawLayer.new()
	hat_fx.draw_func = _draw_hat_fx
	add_child(hat_fx)
	load_hat()
	if not hub_mode:
		for b in GameData.run.get("boons", []):
			boons[b["id"]] = {"rarity": int(b["rarity"]), "level": int(b["level"])}
		_rebuild_slots()
		mods = GameData.run.get("mods", []).duplicate()
	recompute()
	hp = max_hp
	dash_charges = dash_max

func load_hat():
	hat = GameData.get_equipped_hat()
	band_kit = BoonData.BAND_KITS.get(hat.get("band", "cotton"), BoonData.BAND_KITS["cotton"])
	addon_kit = BoonData.ADDON_KITS.get(hat.get("addon", "paperclip"), BoonData.ADDON_KITS["paperclip"])
	mat_kit = BoonData.MAT_KITS.get(hat.get("material", "cardboard"), BoonData.MAT_KITS["cardboard"])
	if hat_node and is_instance_valid(hat_node):
		hat_node.queue_free()
	hat_node = Art.make_hat_node(hat, 0.5)
	hat_root.add_child(hat_node)

# ---------------------------------------------------------------------------
# STATS & BOONS
# ---------------------------------------------------------------------------
func has(id: String) -> bool:
	return boons.has(id)

func bv(id: String) -> float:
	if not boons.has(id):
		return 0.0
	return BoonData.boon_value(id, int(boons[id]["rarity"]), int(boons[id]["level"]))

## Boons STACK: every slot holds a list of boon ids, and all of them fire.
func _rebuild_slots():
	slots = {"attack": [], "special": [], "cast": [], "dash": []}
	for id in boons.keys():
		var s = String(BoonData.BOONS[id]["slot"])
		if slots.has(s):
			slots[s].append(id)

func slot_ids(slot: String) -> Array:
	return slots.get(slot, [])

func slot_colors(slot: String) -> Array:
	var out = []
	for id in slot_ids(slot):
		out.append(BoonData.PATRONS[BoonData.BOONS[id]["patron"]]["color"])
	return out

func slot_color(slot: String) -> Color:
	var cs = slot_colors(slot)
	if cs.is_empty():
		return Style.CREAM
	return cs[int(t * 3.0) % cs.size()]

func boon_level(id: String) -> int:
	if not boons.has(id):
		return 0
	return int(boons[id]["level"])

func recompute():
	var hat_hp = GameData.hat_bonus_hp(hat) if not hat.is_empty() else 0
	speed = 190.0 * (1.0 + 0.05 * GameData.lvl("spd1")) * (1.0 + bv("bruno_walk") / 100.0)
	dmg_mult = (1.0 + 0.08 * GameData.lvl("dmg1")) * (1.0 + GameData.hat_power_pct(hat) / 100.0)
	atk_speed = (1.0 + 0.06 * GameData.lvl("atkspd")) * (1.0 + bv("baron_warm") / 100.0) * (1.2 if mods.has("quick_stitch") else 1.0)
	crit_chance = 0.02 + 0.03 * GameData.lvl("crit") + (0.1 if mods.has("lucky_label") else 0.0)
	crit_mult = 2.0 + 0.15 * GameData.lvl("critdmg") + bv("fortuna_double") / 100.0
	special_mult = (1.0 + 0.1 * GameData.lvl("special_dmg")) * (1.5 if mods.has("loaded_lining") else 1.0)
	cast_mult = 1.0 + 0.12 * GameData.lvl("cast_dmg")
	taken_mult = (1.0 - 0.04 * GameData.lvl("armor")) * (1.0 - bv("bruno_skin") / 100.0)
	dodge = 0.03 * GameData.lvl("dodge") + bv("fortuna_seven") / 100.0
	heal_mult = 1.0 + 0.2 * GameData.lvl("heal_bonus")
	magnet_r = 90.0 * (1.0 + 0.4 * GameData.lvl("magnet"))
	first_strike = 0.25 * GameData.lvl("first_strike")
	elite_mult = (1.0 + 0.1 * GameData.lvl("boss_dmg")) * (1.0 + bv("bruno_low") / 100.0)
	dash_contact_dmg = 15.0 * GameData.lvl("dash_dmg") + (25.0 if mods.has("steel_toe") else 0.0)
	dash_max = 1 + GameData.lvl("dash_charge") + (1 if mods.has("silk_lining") else 0)
	dash_recharge_max = 0.9 * (1.0 - 0.08 * GameData.lvl("dash_cd"))
	special_cd_max = float(addon_kit["cd"]) * (1.0 - 0.07 * GameData.lvl("special_cd")) * (0.7 if mods.has("deep_pockets") else 1.0) * (1.0 - bv("ivory_stacc") / 100.0)
	cast_cd_max = float(mat_kit["cd"]) * (1.0 - 0.08 * GameData.lvl("cast_cd")) * (0.65 if mods.has("encore_band") else 1.0)
	atk_range_mult = 1.3 if mods.has("wide_brim") else 1.0
	var new_max = 80.0 + 12.0 * GameData.lvl("hp1") + 25.0 * GameData.lvl("hp2") + float(hat_hp) + float(GameData.run.get("bonus_max_hp", 0)) + bv("luna_full")
	if hub_mode:
		new_max = 80.0 + 12.0 * GameData.lvl("hp1") + 25.0 * GameData.lvl("hp2") + float(hat_hp)
	if new_max > max_hp:
		hp += new_max - max_hp
	max_hp = new_max
	hp = minf(hp, max_hp)
	dash_charges = mini(dash_charges, dash_max)

func _sync_run():
	var arr = []
	for id in boons.keys():
		arr.append({"id": id, "rarity": int(boons[id]["rarity"]), "level": int(boons[id]["level"])})
	GameData.run["boons"] = arr
	GameData.run["mods"] = mods.duplicate()

## Adds a boon, or levels it up if you already own it. Returns the new level.
func add_boon(id: String, rarity: int) -> int:
	if boons.has(id):
		level_boon(id)
		return boon_level(id)
	boons[id] = {"rarity": rarity, "level": 1}
	_rebuild_slots()
	_sync_run()
	recompute()
	return 1

func level_boon(id: String):
	if boons.has(id):
		boons[id]["level"] = mini(BoonData.MAX_LEVEL, int(boons[id]["level"]) + 1)
		_sync_run()
		recompute()

func add_mod(id: String):
	if not mods.has(id):
		mods.append(id)
	_sync_run()
	recompute()
	if id == "silk_lining":
		dash_charges = dash_max

func start_room():
	ninth_used = false
	shield = 1 if GameData.lvl("start_shield") > 0 else 0
	dash_charges = dash_max
	burst_left = 0
	casting = false
	hat_lift = 0.0

func center() -> Vector2:
	return global_position + Vector2(0, -24)

# ---------------------------------------------------------------------------
# MAIN LOOP
# ---------------------------------------------------------------------------
func _physics_process(delta):
	t += delta
	_update_timers(delta)
	if not alive:
		velocity = velocity.lerp(Vector2.ZERO, minf(1.0, delta * 6.0))
		move_and_slide()
		queue_redraw()
		return
	var input = Vector2.ZERO
	if not input_locked:
		input = Input.get_vector("move_left", "move_right", "move_up", "move_down")
	move_dir = input
	if input.length() > 0.1 and atk_anim < 0.5 and not casting:
		facing = input.normalized()
	if dash_t > 0.0:
		_dash_update(delta)
	else:
		var sp = speed
		if atk_anim > 0.35 and atk_melee:
			sp *= 0.45
		if casting:
			sp *= 0.25
		velocity = velocity.lerp(input * sp, minf(1.0, delta * 14.0))
		if not input_locked:
			if Input.is_action_just_pressed("dash"):
				_try_dash()
			if not hub_mode and not casting:
				if Input.is_action_pressed("attack") and atk_cd <= 0.0:
					_attack()
				if Input.is_action_just_pressed("special") and special_cd <= 0.0:
					_special()
				if Input.is_action_just_pressed("cast") and cast_cd <= 0.0:
					_start_cast()
	move_and_slide()
	_update_hat(delta)
	queue_redraw()
	if hat_fx:
		hat_fx.queue_redraw()

func _update_timers(delta):
	atk_cd -= delta
	atk_anim = maxf(0.0, atk_anim - delta * 4.0)
	combo_timer -= delta
	special_cd = maxf(0.0, special_cd - delta)
	cast_cd = maxf(0.0, cast_cd - delta)
	invuln_t -= delta
	hurt_flash = maxf(0.0, hurt_flash - delta * 4.0)
	if dash_charges < dash_max:
		dash_recharge += delta
		if dash_recharge >= dash_recharge_max:
			dash_recharge = 0.0
			dash_charges += 1
	else:
		dash_recharge = 0.0
	var kg = []
	for g in ghosts:
		g["t"] = float(g["t"]) - delta
		if float(g["t"]) > 0.0:
			kg.append(g)
	ghosts = kg
	if burst_left > 0:
		burst_timer -= delta
		if burst_timer <= 0.0:
			burst_timer = 0.055
			burst_left -= 1
			var d = facing.rotated(randf_range(-0.08, 0.08))
			room.spawn_player_shot({"pos": center() + d * 16.0, "vel": d * float(addon_kit.get("speed", 900.0)), "r": 5.0, "dmg": burst_dmg, "life": 0.8, "kind": "bullet", "src": "special"})
			Sfx.play("shoot", 1.3, -4.0)
	if casting:
		cast_t += delta
		var k = clampf(cast_t / CAST_WINDUP, 0.0, 1.0)
		hat_lift = sin(k * PI * 0.5) * 120.0 if k < 0.8 else lerpf(120.0, 0.0, (k - 0.8) / 0.2)
		if cast_t >= CAST_WINDUP:
			casting = false
			hat_lift = 0.0
			_cast_impact()

func _update_hat(delta):
	var target_rot = clampf(-velocity.x * 0.0011, -0.35, 0.35) + sin(t * 2.0) * 0.03
	if dash_t > 0.0:
		target_rot = -dash_dir.x * 0.5
	if casting:
		target_rot = cast_t * 25.0
	hat_tilt = lerpf(hat_tilt, target_rot, minf(1.0, delta * 9.0)) if not casting else target_rot
	hat_root.rotation = hat_tilt
	var bob = Art.robot_bob(t, velocity.length() > 20.0)
	hat_root.position = Vector2(facing.x * 1.5, Art.HEAD_TOP + bob - hat_lift)
	var sgn = -1.0 if facing.x < -0.2 else 1.0
	var sc = 1.0 + hat_lift / 250.0
	hat_root.scale = Vector2(sgn * sc, sc)
	if hat.get("is_chroma", false):
		var c = Art.chroma_color(t)
		hat_root.modulate = Color(c.r * 1.35, c.g * 1.35, c.b * 1.35, 1.0)
	elif GameData.hat_grade_index(hat) >= 3:
		var p = 1.0 + 0.12 * (0.5 + 0.5 * sin(t * 3.0))
		hat_root.modulate = Color(p, p, p, 1.0)
	else:
		hat_root.modulate = Color.WHITE

# ---------------------------------------------------------------------------
# ATTACK / SPECIAL / CAST / DASH
# ---------------------------------------------------------------------------
func _targets() -> Array:
	if room == null:
		return []
	return room.get_targets()

func _aim_assist(max_range: float, cone_deg: float) -> Vector2:
	var best = null
	var best_score = 1e9
	for e in _targets():
		var d = e.global_position - global_position
		var dist = d.length()
		if dist > max_range or dist < 1.0:
			continue
		var ang = absf(facing.angle_to(d))
		if ang > deg_to_rad(cone_deg):
			continue
		var score = dist * (1.0 + ang * 2.0)
		if score < best_score:
			best = e
			best_score = score
	if best != null:
		return (best.global_position - global_position).normalized()
	return facing

func _attack():
	var kit = band_kit
	var rate = float(kit["rate"]) / atk_speed
	atk_cd = rate
	if kit["style"] == "shot":
		atk_melee = false
		facing = _aim_assist(520.0, 30.0)
		var look = "pearl"
		match String(hat.get("band", "")):
			"dynamo": look = "bolt"
			"neon_magenta": look = "neon"
		room.spawn_player_shot({"pos": center() + facing * 18.0, "vel": facing * float(kit["speed"]), "r": 7.0, "dmg": BASE_ATK * float(kit["dmg"]), "life": 1.1, "kind": look, "src": "attack", "pierce": int(kit["pierce"]), "color": slot_color("attack")})
		atk_anim = 0.4
		Sfx.play("shoot", 1.1, -3.0)
		_thunderstorm_tick()
		return
	atk_melee = true
	facing = _aim_assist(float(kit["range"]) * 2.4, 55.0)
	var combo = int(kit["combo"])
	if combo_timer > 0.0:
		combo_i += 1
	else:
		combo_i = 0
	if combo_i >= combo:
		combo_i = 0
	combo_timer = rate + 0.35
	var fin = combo > 1 and combo_i == combo - 1
	var rng = float(kit["range"]) * atk_range_mult * (1.15 if fin else 1.0)
	var arc = float(kit["arc"])
	if fin and kit["finisher"] == "spin":
		arc = 360.0
	var dmg = BASE_ATK * float(kit["dmg"]) * (1.5 if fin else 1.0)
	atk_range = rng
	atk_arc = arc
	atk_anim = 1.0
	velocity += facing * 130.0
	var hit_any = false
	for e in _targets():
		var to = e.global_position - global_position
		var dist = to.length() - float(e.radius)
		if dist > rng:
			continue
		if arc < 359.0 and to.length() > 4.0 and absf(facing.angle_to(to)) > deg_to_rad(arc * 0.5) + 0.2:
			continue
		var kn = 190.0
		if fin and kit["finisher"] == "knock":
			kn = 420.0
		hit_enemy(e, dmg, to.normalized(), "attack", {"knock": kn})
		if fin and kit["finisher"] == "stun":
			e.apply_status("stun", 0.8)
		hit_any = true
	Sfx.play("swing", 0.9 + combo_i * 0.09, -2.0)
	_thunderstorm_tick()
	if hit_any and fin:
		GameData.hitstop(0.045)
		room.fx.shake(4.0)

## LEGENDARY: Thunderstorm Sonata - every 3rd attack calls lightning on the nearest foe
func _thunderstorm_tick():
	if not has("ivory_legend"):
		return
	atk_counter += 1
	if atk_counter % 3 != 0:
		return
	var best = null
	var bd = 420.0
	for e in _targets():
		var d = e.global_position.distance_to(global_position)
		if d < bd:
			bd = d
			best = e
	if best == null:
		return
	var top: Vector2 = best.center() + Vector2(randf_range(-30, 30), -340)
	room.add_bolt(top, best.center(), Color(1.2, 0.9, 2.4))
	room.add_bolt(top + Vector2(8, 0), best.center(), Color(2.2, 2.2, 2.4))
	room.fx.ring(best.global_position, Color(1.2, 0.9, 2.4, 0.8), 6.0, 60.0, 0.25, 4.0)
	hit_enemy(best, bv("ivory_legend"), Vector2.DOWN, "zap", {"knock": 60.0})
	Sfx.play("zap", 0.6)

func _special():
	var k = addon_kit
	special_cd = special_cd_max
	var dir = _aim_assist(440.0, 40.0)
	facing = dir
	atk_anim = 0.6
	atk_melee = false
	var dmg = BASE_SPECIAL * float(k["dmg"])
	var origin = center() + dir * 14.0
	var col = slot_color("special")
	match String(k["kind"]):
		"proj":
			var n = int(k["count"])
			for i in range(n):
				var a = dir.angle() + (float(i) - float(n - 1) * 0.5) * float(k["spread"])
				var d = Vector2(cos(a), sin(a))
				room.spawn_player_shot({"pos": origin, "vel": d * float(k["speed"]), "r": 8.0, "dmg": dmg, "life": 1.0, "kind": String(k["look"]), "src": "special", "pierce": int(k["pierce"]), "color": col, "coin": String(k["look"]) == "coin"})
			Sfx.play("shoot", 0.8)
		"boomerang":
			room.spawn_player_shot({"pos": origin, "vel": dir * float(k["speed"]), "r": 12.0, "dmg": dmg, "life": 1.3, "kind": "horseshoe", "src": "special", "pierce": 999, "boomerang": true, "color": col})
			Sfx.play("swing", 0.7)
		"lob_fire":
			var target = global_position + dir * 230.0
			room.spawn_player_lob(center(), target, dmg)
			Sfx.play("swing", 0.6)
		"cone":
			_cone_blast(dir, dmg)
		"ricochet":
			room.spawn_player_shot({"pos": origin, "vel": dir * float(k["speed"]), "r": 9.0, "dmg": dmg, "life": 1.0, "kind": "chip", "src": "special", "ricochet": 4, "color": col})
			Sfx.play("chip")
		"dice":
			for i in range(2):
				var face = randi_range(1, 6)
				var d2 = dir.rotated(-0.12 + 0.24 * i)
				room.spawn_player_shot({"pos": origin, "vel": d2 * float(k["speed"]), "r": 9.0, "dmg": dmg * face, "life": 1.0, "kind": "dice", "face": face, "src": "special", "color": col})
			Sfx.play("chip", 0.7)
		"burst":
			burst_left = int(k["count"])
			burst_timer = 0.0
			burst_dmg = dmg

func _cone_blast(dir: Vector2, dmg: float):
	var rng = 180.0
	room.fx.spray(center(), dir, Color(0.6, 0.8, 1.4, 0.9), 16, 420.0, 0.6, 3.0, "spark", 0.35)
	for i in range(5):
		room.fx.burst(center() + dir * (40.0 + i * 28.0), Color(0.8, 0.9, 1.3, 0.7), 2, 60.0, 7.0, "note", 0.8)
	for e in _targets():
		var to = e.global_position - global_position
		if to.length() - float(e.radius) > rng:
			continue
		if absf(dir.angle_to(to)) > deg_to_rad(42.0):
			continue
		hit_enemy(e, dmg, to.normalized(), "special", {"knock": 460.0})
	Sfx.play("horn", 1.6, -4.0)

func _start_cast():
	casting = true
	cast_t = 0.0
	cast_cd = cast_cd_max
	invuln_t = maxf(invuln_t, CAST_WINDUP + 0.15)
	Sfx.play("whoosh_up")

func _cast_impact():
	var k = mat_kit
	var extra = String(k["extra"])
	var rad = float(k["radius"]) * (1.35 if mods.has("grand_finale") else 1.0)
	if has("bruno_cast"):
		rad *= 1.0 + bv("bruno_cast") / 100.0
	var dmg = BASE_CAST * float(k["dmg"])
	var pos = global_position
	var col = slot_color("cast")
	col = Color(col.r * 1.5, col.g * 1.5, col.b * 1.5, 0.95)
	room.fx.ring(pos, col, 20.0, rad, 0.45, 9.0)
	room.fx.ring(pos, Color(1, 1, 1, 0.7), 10.0, rad * 0.6, 0.3, 4.0)
	room.fx.burst(pos, Color(0.9, 0.85, 0.7, 0.6), 22, 300.0, 5.0, "smoke", 0.7)
	room.fx.burst(pos, col, 20, 420.0, 3.0, "spark", 0.4)
	room.fx.shake(12.0)
	room.ground_flash(pos, rad, col)
	Sfx.play("slam")
	GameData.hitstop(0.08, 0.05)
	for e in _targets():
		var to = e.global_position - pos
		if to.length() - float(e.radius) > rad:
			continue
		var d = to.normalized() if to.length() > 1.0 else Vector2.RIGHT
		var kn = 380.0
		if extra == "knock":
			kn = 850.0
		elif extra == "pull":
			d = -d
			kn = 320.0
		hit_enemy(e, dmg, d, "cast", {"knock": kn, "crit_bonus": 0.25 if extra == "crit" else 0.0})
		if e.dead:
			continue
		match extra:
			"stun": e.apply_status("stun", 1.0)
			"chill": e.apply_status("chill", 3)
			"burn": e.apply_status("burn", 12.0)
			"zap": zap(e, 10.0, 1)
	if has("bruno_legend"):
		# LEGENDARY: Aftershock
		var ad = bv("bruno_legend")
		for wi in range(2):
			var delay = 0.28 * float(wi + 1)
			var rr = rad * (1.15 + 0.25 * wi)
			get_tree().create_timer(delay, false).timeout.connect(func(): _aftershock(pos, rr, ad))
	if extra == "heal":
		heal(8.0)
	if extra == "invuln":
		invuln_t = 1.5
	if has("ivory_cast"):
		var v = bv("ivory_cast") * (1.0 + bv("ivory_high") / 100.0)
		for e in _targets():
			room.add_bolt(center() + Vector2(0, -60), e.center(), Color(0.9, 0.7, 1.8))
			hit_enemy(e, v, Vector2.ZERO, "zap", {"knock": 0.0})
		Sfx.play("zap", 0.8)

func _aftershock(pos: Vector2, rad: float, dmg: float):
	if room == null or not alive:
		return
	room.fx.ring(pos, Color(1.8, 0.5, 0.5, 0.9), 20.0, rad, 0.35, 7.0)
	room.fx.shake(6.0)
	Sfx.play("slam", 1.3, -6.0)
	for e in _targets():
		if e.global_position.distance_to(pos) < rad + float(e.radius):
			hit_enemy(e, dmg, (e.global_position - pos).normalized(), "shock", {"knock": 300.0})

func _try_dash():
	if dash_charges <= 0 or dash_t > 0.0 or casting:
		return
	dash_charges -= 1
	dash_t = DASH_TIME
	dash_dir = move_dir.normalized() if move_dir.length() > 0.1 else facing
	facing = dash_dir
	invuln_t = maxf(invuln_t, DASH_TIME + 0.08)
	dash_hit = []
	dash_trail_acc = 0.0
	Sfx.play("dash")
	if room != null and room.fx != null:
		room.fx.burst(global_position, Color(0.8, 0.75, 0.65, 0.5), 8, 90.0, 5.0, "smoke", 0.5)
	if hub_mode:
		return
	if has("ivory_dash"):
		var best = null
		var bd = 300.0
		for e in _targets():
			var d = e.global_position.distance_to(global_position)
			if d < bd:
				bd = d
				best = e
		if best != null:
			room.add_bolt(center(), best.center(), Color(0.9, 0.7, 1.8))
			hit_enemy(best, bv("ivory_dash") * (1.0 + bv("ivory_high") / 100.0), (best.global_position - global_position).normalized(), "zap", {"knock": 60.0})
			Sfx.play("zap")
	if has("fortuna_dash"):
		hedge_ready = true

func _dash_update(delta):
	dash_t -= delta
	velocity = dash_dir * DASH_SPEED
	ghosts.append({"p": global_position, "t": 0.22})
	if not hub_mode:
		dash_trail_acc += DASH_SPEED * delta
		if dash_trail_acc > 34.0:
			dash_trail_acc = 0.0
			if has("luna_dash"):
				room.add_zone({"pos": global_position, "r": 34.0, "life": 2.5, "kind": "frost", "power": bv("luna_dash")})
			if has("baron_dash"):
				room.add_zone({"pos": global_position, "r": 34.0, "life": 2.5, "kind": "fire", "power": bv("baron_dash")})
		if dash_contact_dmg > 0.0:
			for e in _targets():
				if e in dash_hit:
					continue
				if e.global_position.distance_to(global_position) < float(e.radius) + 22.0:
					dash_hit.append(e)
					hit_enemy(e, dash_contact_dmg, dash_dir, "dash", {"knock": 260.0})
	if dash_t <= 0.0:
		velocity = dash_dir * speed * 0.6
		if not hub_mode and has("bruno_dash"):
			shockwave(global_position, bv("bruno_dash"))

# ---------------------------------------------------------------------------
# DAMAGE PIPELINE
# ---------------------------------------------------------------------------
func hit_enemy(e, base: float, dir: Vector2, src: String, opts: Dictionary = {}):
	if e == null or not is_instance_valid(e) or e.dead:
		return
	var dmg = base * dmg_mult
	var crit_c = crit_chance
	var slot_src = src in ["attack", "special", "cast"]
	match src:
		"attack":
			dmg *= 1.0 + bv("luna_attack") / 100.0
			dmg *= 1.0 + bv("bruno_attack") / 100.0
			crit_c += bv("fortuna_attack") / 100.0
			if mods.has("heavy_crown"):
				dmg *= 1.3
		"special":
			dmg *= special_mult
			dmg *= 1.0 + bv("luna_special") / 100.0
			crit_c += bv("fortuna_special") / 100.0
		"cast":
			dmg *= cast_mult
			dmg *= 1.0 + bv("luna_cast") / 100.0
			dmg *= 1.0 + bv("bruno_cast") / 100.0
			crit_c += bv("fortuna_cast") / 100.0
			crit_c += float(opts.get("crit_bonus", 0.0))
		"zap":
			crit_c = bv("duo_circuit") / 100.0
		"burn", "explode":
			crit_c = 0.0
	if slot_src and first_strike > 0.0 and e.hp >= e.max_hp - 0.5:
		dmg *= 1.0 + first_strike
	if e.is_boss or e.elite:
		dmg *= elite_mult
	var chilled = e.chill > 0 or e.freeze_t > 0.0
	if chilled:
		if has("luna_cold"):
			dmg *= 1.0 + bv("luna_cold") / 100.0
		if has("duo_cabaret") and src != "burn":
			crit_c += bv("duo_cabaret") / 100.0
		if src == "zap" and has("duo_sonata"):
			dmg *= 1.0 + bv("duo_sonata") / 100.0
	if hedge_ready and slot_src:
		dmg *= 1.0 + bv("fortuna_dash") / 100.0
		hedge_ready = false
		crit_c += 0.33
	var crit = randf() < crit_c
	if crit:
		dmg *= crit_mult
	var kn = float(opts.get("knock", 120.0))
	if src == "attack" and has("bruno_attack"):
		kn *= 2.2
	e.take_hit(dmg, dir, kn, crit, src)
	if opts.get("coin", false) and e.dead:
		room.drop_rp(e.global_position, 4)
	if slot_src:
		_apply_slot_effects(e, src)
	if crit and has("duo_bouncer") and (slot_src or src == "dash"):
		shockwave(e.global_position, bv("duo_bouncer"))
	if src == "zap" and has("duo_sonata") and not e.dead:
		e.apply_status("chill", 1)

## Every boon in the slot fires: a Chill attack + a Burn attack + a Zap attack all apply together.
func _apply_slot_effects(e, src: String):
	var ids = slot_ids(src)
	if ids.is_empty():
		return
	for id in ids:
		var v = bv(id)
		var patron = String(BoonData.BOONS[id]["patron"])
		match patron:
			"luna":
				if not e.dead:
					e.apply_status("chill", 3 if src == "cast" else 1)
			"baron":
				if not e.dead:
					e.apply_status("burn", v)
			"ivory":
				if src != "cast":
					zap(e, v, 3 if src == "special" else 1)
			"bruno":
				if src == "special":
					shockwave(e.global_position, v)
		# a little pop of each Headliner's colour so you can SEE the stack working
		var pc: Color = BoonData.PATRONS[patron]["color"]
		room.fx.burst(e.center(), Color(pc.r * 1.6, pc.g * 1.6, pc.b * 1.6, 0.9), 2 + boon_level(id), 140.0, 2.5, "spark", 0.25)

func zap(from_e, dmg: float, count: int):
	var n = count + int(bv("ivory_sustain"))
	var mult = 1.0 + bv("ivory_high") / 100.0
	var hit = [from_e]
	var cur: Vector2 = from_e.center()
	for i in range(n):
		var best = null
		var bd = 240.0
		for e in _targets():
			if e in hit:
				continue
			var d = e.center().distance_to(cur)
			if d < bd:
				bd = d
				best = e
		if best == null:
			break
		room.add_bolt(cur, best.center(), Color(0.85, 0.7, 1.7))
		hit.append(best)
		var nxt: Vector2 = best.center()
		hit_enemy(best, dmg * mult, (nxt - cur).normalized(), "zap", {"knock": 40.0})
		cur = nxt
	Sfx.play("zap", randf_range(0.9, 1.2), -4.0)

func shockwave(pos: Vector2, dmg: float):
	room.fx.ring(pos, Color(1.5, 0.45, 0.5, 0.9), 10.0, 90.0, 0.3, 5.0)
	room.fx.burst(pos, Color(1.2, 0.4, 0.4, 0.8), 8, 200.0, 3.0, "spark", 0.3)
	for e in _targets():
		if e.global_position.distance_to(pos) < 90.0 + float(e.radius):
			hit_enemy(e, dmg, (e.global_position - pos).normalized(), "shock", {"knock": 260.0})
			if has("duo_boom") and not e.dead:
				e.apply_status("burn", bv("duo_boom"))
	Sfx.play("slam", 1.6, -8.0)

func burn_multiplier(e) -> float:
	var m = 1.0 + bv("baron_five") / 100.0
	if has("duo_steam") and (e.chill > 0 or e.freeze_t > 0.0):
		m *= 1.0 + bv("duo_steam") / 100.0
	return m * dmg_mult

func zone_tick(e, zone: Dictionary):
	match String(zone["kind"]):
		"frost":
			hit_enemy(e, float(zone["power"]) * 0.5, Vector2.ZERO, "zone", {"knock": 0.0})
			if not e.dead:
				e.apply_status("chill", 1)
		"fire":
			e.apply_status("burn", float(zone["power"]))

func on_enemy_killed(e):
	var pos0: Vector2 = e.global_position
	# LEGENDARY: Dark Side of the Moon (frost burst)
	if has("luna_legend") and (e.chill > 0 or e.freeze_t > 0.0):
		room.fx.burst(pos0 + Vector2(0, -16), Color(0.7, 1.2, 2.0), 22, 240.0, 3.5, "shard", 0.7)
		room.fx.ring(pos0, Color(0.7, 1.2, 2.0, 0.9), 10.0, 110.0, 0.35, 6.0)
		Sfx.play("freeze", 0.8, -4.0)
		for o in _targets():
			if o != e and o.global_position.distance_to(pos0) < 110.0 + float(o.radius):
				hit_enemy(o, bv("luna_legend"), (o.global_position - pos0).normalized(), "explode", {"knock": 120.0})
				if not o.dead:
					o.apply_status("chill", 2)
	# LEGENDARY: Wildfire (burn spreads)
	if has("baron_legend") and e.burn_t > 0.0:
		room.fx.ring(pos0, Color(2.0, 0.7, 0.2, 0.9), 10.0, 130.0, 0.4, 6.0)
		room.fx.burst(pos0 + Vector2(0, -16), Color(2.2, 0.8, 0.2), 20, 220.0, 3.5, "ember", 0.8)
		for o in _targets():
			if o != e and o.global_position.distance_to(pos0) < 130.0 + float(o.radius):
				o.apply_status("burn", maxf(6.0, float(e.burn_dps)))
				hit_enemy(o, bv("baron_legend"), (o.global_position - pos0).normalized(), "explode", {"knock": 80.0})
	if e.burn_t > 0.0 and has("baron_streak"):
		var pos = e.global_position
		room.fx.burst(pos, Color(2.0, 0.8, 0.2), 18, 260.0, 4.0, "ember", 0.6)
		room.fx.ring(pos, Color(2.0, 0.7, 0.2, 0.9), 10.0, 80.0, 0.3, 6.0)
		Sfx.play("explode", 1.3, -6.0)
		for o in _targets():
			if o != e and o.global_position.distance_to(pos) < 80.0 + float(o.radius):
				hit_enemy(o, bv("baron_streak"), (o.global_position - pos).normalized(), "explode", {"knock": 200.0})

# ---------------------------------------------------------------------------
# TAKING DAMAGE
# ---------------------------------------------------------------------------
func take_damage(amount: float, dir: Vector2 = Vector2.ZERO, src: String = "something"):
	if not alive or hub_mode:
		return
	if invuln_t > 0.0 or dash_t > 0.0:
		return
	last_hit_by = src
	if randf() < dodge:
		room.fx.text(center() + Vector2(0, -20), "DODGE", Color(0.5, 1.0, 1.0), 20)
		invuln_t = 0.3
		Sfx.play("dash", 1.6, -4.0)
		return
	if shield > 0:
		shield -= 1
		invuln_t = 0.6
		room.fx.ring(center(), Color(0.5, 1.2, 2.0, 0.9), 20.0, 50.0, 0.3, 4.0)
		room.fx.text(center() + Vector2(0, -20), "BLOCKED", Color(0.5, 0.9, 1.0), 18)
		Sfx.play("shield")
		return
	var d = amount * taken_mult
	hp -= d
	invuln_t = 0.75
	hurt_flash = 1.0
	velocity += dir * 260.0
	room.fx.burst(center(), Color(1.3, 0.2, 0.2), 14, 220.0, 3.0, "dot", 0.4)
	room.fx.shake(8.0)
	room.fx.damage_number(center(), d, false, Color(1.0, 0.35, 0.35))
	Sfx.play("hurt")
	GameData.hitstop(0.07, 0.1)
	room.on_player_hurt(d)
	if hp <= 0.0 and has("fortuna_legend") and not ninth_used:
		# LEGENDARY: Ninth Life
		ninth_used = true
		hp = max_hp * bv("fortuna_legend") / 100.0
		invuln_t = 1.5
		room.fx.text(center() + Vector2(0, -36), "NINTH LIFE!", Color(0.4, 2.0, 0.7), 26)
		room.fx.burst(center(), Color(0.4, 1.8, 0.7), 30, 260.0, 3.0, "confetti", 1.0)
		Sfx.play("sting_fortuna")
	if hp <= 0.0:
		if int(GameData.run.get("defiance", 0)) > 0:
			GameData.run["defiance"] = int(GameData.run["defiance"]) - 1
			hp = max_hp * 0.4
			invuln_t = 2.5
			room.on_curtain_call()
		else:
			hp = 0.0
			alive = false
			died.emit()

func heal(amount: float):
	if amount <= 0.0:
		return
	var h = amount * heal_mult
	var before = hp
	hp = minf(max_hp, hp + h)
	if room != null and room.fx != null:
		room.fx.text(center() + Vector2(0, -26), "+%d" % int(round(hp - before)), Color(0.4, 1.0, 0.5), 20)
		room.fx.burst(center(), Color(0.4, 1.3, 0.5, 0.8), 10, 90.0, 3.0, "ember", 0.7)
	Sfx.play("heal")

# ---------------------------------------------------------------------------
# DRAWING
# ---------------------------------------------------------------------------
func _draw():
	var dash_cols = slot_colors("dash")
	var gi = 0
	for g in ghosts:
		var off: Vector2 = g["p"] - global_position
		var a = float(g["t"]) / 0.22 * 0.35
		var gc = Color(0.4, 0.9, 1.4, a)
		if not dash_cols.is_empty():
			var dc: Color = dash_cols[gi % dash_cols.size()]
			gc = Color(dc.r * 1.4, dc.g * 1.4, dc.b * 1.4, a * 1.3)
		gi += 1
		var ghost_skin = {"head": Color(gc.r, gc.g, gc.b, a * 0.8), "eye": Color(2.0, 2.0, 2.2, a), "tie": Color(gc.r, gc.g, gc.b, a), "limb": Color(gc.r, gc.g, gc.b, a * 0.7)}
		draw_set_transform(off, 0.0, Vector2.ONE)
		Art.draw_robot(self, t, dash_dir, true, 0.0, Color(gc.r, gc.g, gc.b, a), ghost_skin)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	if shield > 0:
		draw_circle(Vector2(0, -30), 32, Color(0.4, 0.8, 1.4, 0.06))
		draw_arc(Vector2(0, -30), 32, 0, TAU, 36, Color(0.5, 1.0, 1.6, 0.35 + 0.15 * sin(t * 5.0)), 2.0, true)
		for hx in range(6):
			var ha = t * 0.8 + TAU * float(hx) / 6.0
			draw_arc(Vector2(0, -30), 32, ha, ha + 0.35, 4, Color(0.8, 1.4, 2.0, 0.6), 3.0, true)
	var blink = invuln_t > 0.0 and hurt_flash <= 0.0 and invuln_t < 2.6 and dash_t <= 0.0 and not casting and int(t * 20.0) % 2 == 0 and invuln_t > 0.15
	if hurt_flash > 0.0 or not blink:
		var sk = GameData.skin()
		var body = (sk["body"] as Color).lerp(Color(2.0, 2.0, 2.0), hurt_flash * 0.8)
		var atk_k = atk_anim if atk_melee else atk_anim * 0.6
		Art.draw_robot(self, t, facing, velocity.length() > 20.0, atk_k, body, sk)
	var hp_ = hat_root.position
	Art.ellipse(self, hp_ + Vector2(0, 2), 13, 3.2, Color(0, 0, 0, 0.3))
	if GameData.hat_grade_index(hat) >= 3 or hat.get("is_chroma", false):
		var gcol = Art.chroma_color(t) if hat.get("is_chroma", false) else Color(1.4, 1.1, 0.4)
		Art.glow(self, hp_ + Vector2(0, -10), 30 + 3 * sin(t * 3.0), Color(gcol.r, gcol.g, gcol.b, 0.35), 3)
	if atk_anim > 0.0 and atk_melee:
		_draw_swoosh()
	elif atk_anim > 0.25 and not atk_melee:
		# muzzle flash on shots and specials
		var mp = Vector2(0, -24) + facing * 22.0
		var mf = atk_anim
		Art.glow(self, mp, 14.0 * mf, Color(2.0, 1.8, 1.2, 0.6 * mf), 2)
		Art.star(self, mp, 9.0 * mf, 3.0 * mf, 4, Color(2.2, 2.0, 1.5, mf), facing.angle())
	if casting:
		var k = clampf(cast_t / CAST_WINDUP, 0.0, 1.0)
		var rad = float(mat_kit["radius"]) * (1.35 if mods.has("grand_finale") else 1.0)
		draw_arc(Vector2.ZERO, rad * k, 0, TAU, 48, Color(1.0, 0.85, 0.4, 0.5 * k), 3.0, true)
		draw_colored_polygon(PackedVector2Array([Vector2(-10, -260), Vector2(10, -260), Vector2(46, 4), Vector2(-46, 4)]), Color(1.3, 1.2, 0.9, 0.14 * k))
		for ci_ in range(12):
			var ca = TAU * float(ci_) / 12.0 + t * 2.0
			var cr = rad * (1.0 - k) * 0.8 + 20.0
			draw_circle(Vector2(cos(ca), sin(ca) * 0.5) * cr + Vector2(0, -10), 2.5, Color(1.8, 1.5, 0.7, k))

## Hat grade sparkle, drawn over the hat (a child node after hat_root).
func _draw_hat_fx(ci: CanvasItem):
	if hat.is_empty() or hat_root == null:
		return
	var g = GameData.hat_grade_index(hat)
	var hp_ = hat_root.position + Vector2(0, -12)
	if hat.get("is_chroma", false):
		for i in range(6):
			var a = t * 1.6 + TAU * float(i) / 6.0
			var c = Color.from_hsv(fmod(t * 0.3 + float(i) / 6.0, 1.0), 0.6, 1.8)
			Art.star(ci, hp_ + Vector2(cos(a) * 26.0, sin(a) * 10.0), 3.5, 1.2, 4, c, t * 3.0)
		return
	match g:
		1:
			var gl = fmod(t, 3.0)
			if gl < 0.35:
				Art.star(ci, hp_ + Vector2(lerpf(-16.0, 16.0, gl / 0.35), 8), 5.0, 1.5, 4, Color(1.6, 1.8, 2.2, 1.0 - gl / 0.35), 0.0)
		2:
			for i in range(3):
				var a2 = t * 1.2 + TAU * float(i) / 3.0
				Art.star(ci, hp_ + Vector2(cos(a2) * 24.0, sin(a2) * 9.0), 3.0, 1.0, 4, Color(1.6, 1.0, 2.2, 0.9), t * 2.0)
		3:
			for i in range(5):
				var a3 = t * 1.4 + TAU * float(i) / 5.0
				Art.star(ci, hp_ + Vector2(cos(a3) * 26.0, sin(a3) * 10.0), 3.6, 1.2, 4, Color(2.2, 1.7, 0.6, 1.0), t * 2.5)
			for i in range(3):
				var mt = fmod(t * 0.7 + float(i) * 0.33, 1.0)
				ci.draw_circle(hp_ + Vector2(-10.0 + i * 10.0, -mt * 26.0), 1.4, Color(2.0, 1.6, 0.5, 1.0 - mt))

func _draw_swoosh():
	var k = atk_anim
	var c = slot_color("attack")
	var col = Color(c.r * 1.5, c.g * 1.5, c.b * 1.5, 0.75 * k)
	var ctr = Vector2(0, -16)
	var r_out = atk_range
	var r_in = atk_range * 0.45
	if atk_arc >= 359.0:
		draw_arc(ctr, (r_out + r_in) * 0.5, 0, TAU, 48, col, r_out - r_in, true)
		return
	var half = deg_to_rad(atk_arc) * 0.5
	var base = facing.angle()
	var dirn = 1.0 if combo_i % 2 == 0 else -1.0
	var prog = 1.0 - k
	var a0 = base - half * dirn
	var a1 = base - half * dirn + (half * 2.0 * dirn) * minf(1.0, prog * 2.2 + 0.3)
	var seg = 14
	var pts = PackedVector2Array()
	for i in range(seg + 1):
		var a = lerpf(a0, a1, float(i) / float(seg))
		pts.append(ctr + Vector2(cos(a), sin(a)) * r_out)
	for i in range(seg, -1, -1):
		var a = lerpf(a0, a1, float(i) / float(seg))
		var taper = lerpf(0.85, 1.0, float(i) / float(seg))
		pts.append(ctr + Vector2(cos(a), sin(a)) * r_in * taper)
	var glow_pts = PackedVector2Array()
	for i in range(seg + 1):
		var ag = lerpf(a0, a1, float(i) / float(seg))
		glow_pts.append(ctr + Vector2(cos(ag), sin(ag)) * (r_out + 8.0))
	for i in range(seg, -1, -1):
		var ag2 = lerpf(a0, a1, float(i) / float(seg))
		glow_pts.append(ctr + Vector2(cos(ag2), sin(ag2)) * (r_out - 2.0))
	draw_colored_polygon(glow_pts, Color(col.r, col.g, col.b, 0.22 * k))
	draw_colored_polygon(pts, col)
	for sp_i in range(3):
		var sa = a1 - dirn * 0.12 * float(sp_i)
		var sr = lerpf(r_in, r_out, 0.4 + 0.3 * float(sp_i))
		Art.star(self, ctr + Vector2(cos(sa), sin(sa)) * sr, 4.0 * k, 1.5 * k, 4, Color(2.2, 2.1, 1.8, k), t * 6.0)
	# one bright stripe per stacked Attack boon
	var stripes = slot_colors("attack")
	for si in range(stripes.size()):
		var sc: Color = stripes[si]
		var rr = r_out - 3.0 - float(si) * 5.0
		var arc_pts = PackedVector2Array()
		for i in range(seg + 1):
			var a2 = lerpf(a0, a1, float(i) / float(seg))
			arc_pts.append(ctr + Vector2(cos(a2), sin(a2)) * rr)
		draw_polyline(arc_pts, Color(sc.r * 1.8, sc.g * 1.8, sc.b * 1.8, k), 3.0, true)
	draw_line(ctr + Vector2(cos(a1), sin(a1)) * r_in, ctr + Vector2(cos(a1), sin(a1)) * r_out, Color(2.0, 2.0, 1.8, k), 3.0)
