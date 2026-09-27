extends CharacterBody2D

## Bosses. One per biome, three phases each (100% / 60% / 30% health).
##   big_sal      - The Doorman: stomps, bull charges into walls (then gets dizzy), bottle barrages
##   getaway_car  - A '52 sedan: lane-charges, tommy-gun volleys, horn shockwaves, molotovs
##   big_band     - Giant jukebox: note spirals, bouncing records, sound-wall beams
##   moon_man     - The Man in the Moon: meteor showers, moonbeams, starfalls, homing crescents

const Art = preload("res://scripts/art.gd")
const WorldData = preload("res://scripts/world_data.gd")

var kind: String = "big_sal"
var room = null
var display_name: String = "BOSS"
var title: String = ""
var hp: float = 900.0
var max_hp: float = 900.0
var radius: float = 34.0
var center_h: float = 40.0
var elite: bool = false
var is_boss: bool = true
var dead: bool = false
var dmg_k: float = 1.0

var t: float = 0.0
var state: String = "intro"
var st: float = 2.4
var step: int = 0
var sub_t: float = 0.0
var count: int = 0
var phase: int = 1
var facing: Vector2 = Vector2.DOWN
var heading: Vector2 = Vector2.DOWN
var charge_dir: Vector2 = Vector2.ZERO
var knock: Vector2 = Vector2.ZERO
var home: Vector2 = Vector2.ZERO
var last_atk: String = ""
var angle_acc: float = 0.0
var charge_hit: bool = false
var death_t: float = 0.0
var tempo_now: float = 1.0

var chill: int = 0
var chill_t: float = 0.0
var freeze_t: float = 0.0
var burn_dps: float = 0.0
var burn_t: float = 0.0
var burn_tick: float = 0.0
var stun_t: float = 0.0
var buff_t: float = 0.0
var flash: float = 0.0
var contact_cd: float = 0.0

func setup(k: String, room_ref, hp_mult: float):
	kind = k
	room = room_ref
	var d = WorldData.BOSSES.get(k, WorldData.BOSSES["big_sal"])
	display_name = String(d["name"])
	title = String(d["title"])
	max_hp = float(d["hp"]) * hp_mult
	hp = max_hp
	st = 3.6
	match kind:
		"big_sal":
			radius = 34.0
			center_h = 52.0
			dmg_k = 1.0
		"getaway_car":
			radius = 42.0
			center_h = 24.0
			dmg_k = 1.2
		"big_band":
			radius = 58.0
			center_h = 70.0
			dmg_k = 1.4
		"moon_man":
			radius = 60.0
			center_h = 70.0
			dmg_k = 1.6

func _ready():
	add_to_group("enemies")
	motion_mode = CharacterBody2D.MOTION_MODE_FLOATING
	collision_layer = 4
	collision_mask = 1
	if kind == "big_band" or kind == "moon_man":
		collision_mask = 0
	var col = CollisionShape2D.new()
	var sh = CircleShape2D.new()
	sh.radius = radius * 0.8
	col.shape = sh
	add_child(col)
	home = global_position

func center() -> Vector2:
	return global_position + Vector2(0, -center_h)

# ---------------------------------------------------------------------------
# DAMAGE
# ---------------------------------------------------------------------------
func take_hit(amount: float, dir: Vector2, knock_force: float, crit: bool, src: String):
	if dead or state == "intro":
		return
	hp -= amount
	flash = 1.0
	if kind == "big_sal" or kind == "getaway_car":
		knock += dir * knock_force * 0.06
	var col = Color(1, 0.95, 0.85)
	if src == "burn":
		col = Color(1.0, 0.55, 0.2)
	elif src == "zap":
		col = Color(0.85, 0.7, 1.0)
	room.fx.damage_number(center() + Vector2(randf_range(-20, 20), 0), amount, crit, col)
	if src != "burn":
		room.fx.spray(center(), dir if dir.length() > 0.1 else Vector2.UP, Color(1.6, 1.4, 1.0), 6, 260.0, 0.8, 2.0, "spark", 0.25)
		Sfx.play("crit" if crit else "hit", randf_range(0.8, 1.0), -3.0)
	if phase == 1 and hp < max_hp * 0.6:
		_enter_phase(2)
	elif phase == 2 and hp < max_hp * 0.3:
		_enter_phase(3)
	if hp <= 0.0:
		_die()

func _enter_phase(p: int):
	phase = p
	Sfx.play("roar", 1.0 + 0.1 * p)
	room.fx.shake(10.0)
	room.fx.ring(center(), Color(2.0, 0.5, 0.4, 0.9), 20.0, 220.0, 0.6, 8.0)
	room.banner("PHASE %d" % p, Color(1.0, 0.4, 0.35))

func apply_status(skind: String, power: float):
	if dead:
		return
	match skind:
		"burn":
			burn_dps = maxf(burn_dps, power) + power * 0.2
			burn_t = 3.0
		"chill":
			chill = mini(3, chill + int(power))
			chill_t = 3.0
		"stun":
			stun_t = maxf(stun_t, power * 0.3)

func _status_tick(delta):
	if burn_t > 0.0:
		burn_t -= delta
		burn_tick -= delta
		if burn_tick <= 0.0:
			burn_tick = 0.5
			var p = room.player
			var mult = p.burn_multiplier(self) if p != null else 1.0
			take_hit(burn_dps * 0.5 * mult, Vector2.ZERO, 0.0, false, "burn")
		if burn_t <= 0.0:
			burn_dps = 0.0
	if chill_t > 0.0:
		chill_t -= delta
		if chill_t <= 0.0:
			chill = 0
	stun_t -= delta

# ---------------------------------------------------------------------------
# MAIN LOOP
# ---------------------------------------------------------------------------
func _physics_process(delta):
	t += delta
	flash = maxf(0.0, flash - delta * 8.0)
	contact_cd -= delta
	if dead:
		_death_update(delta)
		queue_redraw()
		return
	_status_tick(delta)
	if dead:
		return
	knock = knock.move_toward(Vector2.ZERO, 900.0 * delta)
	var p = room.player
	if state == "intro":
		st -= delta
		velocity = Vector2.ZERO
		if st <= 0.0:
			state = "idle"
			st = 0.8
		queue_redraw()
		return
	if p == null or not p.alive:
		velocity = Vector2.ZERO
		move_and_slide()
		queue_redraw()
		return
	if stun_t > 0.0:
		velocity = knock
		move_and_slide()
		queue_redraw()
		return
	var tempo = [1.0, 1.0, 1.2, 1.4][phase] * (1.0 - 0.06 * chill)
	tempo_now = tempo
	var d = delta * tempo
	var to_p: Vector2 = p.global_position - global_position
	var dist = to_p.length()
	var dir = to_p.normalized() if dist > 0.1 else Vector2.DOWN
	var desired = Vector2.ZERO
	match kind:
		"big_sal":
			desired = _sal(d, p, dir, dist)
		"getaway_car":
			desired = _car(d, p, dir, dist)
		"big_band":
			desired = _band(d, p, dir, dist)
		"moon_man":
			desired = _moon(d, p, dir, dist)
	if kind != "big_band" and kind != "moon_man":
		if contact_cd <= 0.0 and dist < radius + p.radius + 8.0:
			contact_cd = 1.0
			p.take_damage(12.0 * dmg_k, dir, display_name)
	velocity = desired + knock
	move_and_slide()
	var a: Rect2 = room.arena
	global_position.x = clampf(global_position.x, a.position.x + radius, a.end.x - radius)
	global_position.y = clampf(global_position.y, a.position.y + radius * 0.5, a.end.y - 6.0)
	queue_redraw()

func _choose(options: Array) -> String:
	var pool = []
	for o in options:
		if o != last_atk:
			pool.append(o)
	if pool.is_empty():
		pool = options
	var c = String(pool.pick_random())
	last_atk = c
	return c

func _begin(atk: String):
	_callout(atk)
	state = atk
	step = 0
	st = 0.0
	sub_t = 0.0
	count = 0

func _callout(atk: String):
	var tbl = WorldData.BOSS_ATTACKS.get(kind, {})
	if tbl.has(atk):
		room.boss_callout(String(tbl[atk][0]), String(tbl[atk][1]))

func _to_idle(wait: float):
	state = "idle"
	st = wait
	step = 0

func _ring(n: int, spd: float, dmg: float, kind_s: String, off: float = 0.0, col: Color = Color(0, 0, 0, 0)):
	for i in range(n):
		var a = off + TAU * float(i) / float(n)
		var s = {"pos": center(), "vel": Vector2(cos(a), sin(a)) * spd, "r": 8.0, "dmg": dmg, "kind": kind_s, "src": display_name}
		if col.a > 0.0:
			s["color"] = col
		room.spawn_enemy_shot(s)

func _at_wall(dirv: Vector2) -> bool:
	var a: Rect2 = room.arena
	var p = global_position + dirv * (radius + 6.0)
	return p.x < a.position.x + 4.0 or p.x > a.end.x - 4.0 or p.y < a.position.y + 4.0 or p.y > a.end.y - 2.0 or get_slide_collision_count() > 0

# ---------------------------------------------------------------------------
# BIG SAL
# ---------------------------------------------------------------------------
func _sal(d: float, p, dir: Vector2, dist: float) -> Vector2:
	match state:
		"idle":
			facing = dir
			st -= d
			if st <= 0.0:
				var opts = ["stomp", "charge", "bottles"]
				if phase >= 2:
					opts.append("backup")
					opts.append("charge")
				_begin(_choose(opts))
			return dir * 75.0
		"stomp":
			if step == 0:
				room.add_telegraph({"shape": "circle", "pos": global_position, "r": 130.0, "dur": (0.85) / tempo_now, "dmg": 20.0 * dmg_k, "owner": self, "src": display_name, "fx": "slam"})
				st = 0.85
				step = 1
			elif step == 1:
				st -= d
				if st <= 0.0:
					_ring(12 if phase < 3 else 18, 190.0, 12.0 * dmg_k, "cap")
					if phase >= 2:
						_ring(12, 130.0, 12.0 * dmg_k, "cap", 0.26)
					step = 2
					st = 0.5
			else:
				st -= d
				if st <= 0.0:
					_to_idle(1.0)
			return Vector2.ZERO
		"charge":
			if step == 0:
				charge_dir = dir
				facing = dir
				room.add_telegraph({"shape": "line", "pos": global_position, "dir": dir, "len": 1100.0, "w": 84.0, "dur": (0.75) / tempo_now, "dmg": 0.0, "owner": self, "visual": true, "src": display_name})
				Sfx.play("roar", 1.4, -6.0)
				st = 0.75
				step = 1
				return Vector2.ZERO
			elif step == 1:
				st -= d
				if st <= 0.0:
					step = 2
					st = 1.8
					charge_hit = false
				return Vector2.ZERO
			elif step == 2:
				st -= d
				if not charge_hit and dist < radius + 24.0:
					charge_hit = true
					p.take_damage(24.0 * dmg_k, charge_dir, display_name)
				if randf() < 0.5:
					room.fx.burst(global_position, Color(0.7, 0.6, 0.5, 0.4), 1, 40.0, 10.0, "smoke", 0.5)
				if _at_wall(charge_dir) or st <= 0.0:
					room.fx.shake(14.0)
					Sfx.play("slam", 0.8)
					room.fx.burst(global_position + charge_dir * radius, Color(0.9, 0.8, 0.7), 20, 260.0, 4.0, "shard", 0.6)
					var back = -charge_dir
					for i in range(7):
						var a = back.angle() + (float(i) - 3.0) * 0.25
						room.spawn_enemy_shot({"pos": center(), "vel": Vector2(cos(a), sin(a)) * 230.0, "r": 8.0, "dmg": 10.0 * dmg_k, "kind": "cap", "src": display_name})
					step = 3
					st = 1.4 if phase < 3 else 0.8
					_callout("dizzy")
					return Vector2.ZERO
				return charge_dir * 720.0
			else:
				st -= d
				if st <= 0.0:
					if phase >= 3 and count < 1:
						count += 1
						step = 0
					else:
						_to_idle(0.8)
				return Vector2.ZERO
		"bottles":
			if step == 0:
				st = 0.5
				step = 1
			elif step == 1:
				st -= d
				if st <= 0.0:
					var n = 5 if phase == 1 else (7 if phase == 2 else 9)
					for i in range(n):
						var off = Vector2.ZERO if i == 0 else Vector2(randf_range(-160, 160), randf_range(-110, 110))
						room.add_telegraph({"shape": "circle", "pos": p.global_position + off, "r": 48.0, "dur": (0.95 + i * 0.1) / tempo_now, "dmg": 12.0 * dmg_k, "owner": null, "src": display_name, "fx": "glass", "lob_from": center() + Vector2(0, -40), "lob_kind": "bottle"})
					Sfx.play("swing", 0.6)
					step = 2
					st = 1.2
			else:
				st -= d
				if st <= 0.0:
					_to_idle(0.9)
			return Vector2.ZERO
		"backup":
			if step == 0:
				Sfx.play("roar", 1.6, -4.0)
				room.banner("\"BOYS! GET IN HERE!\"", Color(1, 0.8, 0.5))
				var n = 3
				for i in range(n):
					room.spawn_enemy("barfly" if (phase < 3 or i > 0) else "bouncer", room.random_spawn_pos(200.0), false)
				step = 1
				st = 1.4
			else:
				st -= d
				if st <= 0.0:
					_to_idle(1.2)
			return Vector2.ZERO
	return Vector2.ZERO

# ---------------------------------------------------------------------------
# THE GETAWAY CAR
# ---------------------------------------------------------------------------
func _car(d: float, p, dir: Vector2, dist: float) -> Vector2:
	match state:
		"idle":
			heading = heading.slerp(dir, minf(1.0, d * 2.5)).normalized()
			st -= d
			if st <= 0.0:
				var opts = ["drive", "tommy", "horn"]
				if phase >= 2:
					opts.append("goons")
					opts.append("drive")
				if phase >= 3:
					opts.append("molotov")
				_begin(_choose(opts))
			return heading * 45.0
		"drive":
			if step == 0:
				heading = dir
				room.add_telegraph({"shape": "line", "pos": global_position, "dir": dir, "len": 1400.0, "w": 96.0, "dur": (0.8) / tempo_now, "dmg": 0.0, "owner": self, "visual": true, "src": display_name})
				Sfx.play("horn")
				st = 0.8
				step = 1
				return Vector2.ZERO
			elif step == 1:
				st -= d
				if st <= 0.0:
					step = 2
					st = 2.0
					charge_hit = false
				return Vector2.ZERO
			elif step == 2:
				st -= d
				if not charge_hit and dist < radius + 26.0:
					charge_hit = true
					p.take_damage(26.0 * dmg_k, heading, display_name)
				room.fx.burst(global_position - heading * 50.0, Color(0.6, 0.6, 0.65, 0.35), 1, 30.0, 12.0, "smoke", 0.6)
				if _at_wall(heading) or st <= 0.0:
					room.fx.shake(10.0)
					Sfx.play("slam", 1.1, -2.0)
					room.fx.burst(global_position + heading * 50.0, Color(1.2, 1.0, 0.6), 16, 240.0, 3.0, "spark", 0.4)
					step = 3
					st = 0.5
					return Vector2.ZERO
				return heading * 820.0
			else:
				st -= d
				if st <= 0.0:
					count += 1
					if count < (1 if phase == 1 else 2):
						step = 0
					else:
						_to_idle(0.7)
				return Vector2.ZERO
		"tommy":
			heading = heading.slerp(dir, minf(1.0, d * 4.0)).normalized()
			if step == 0:
				st = 0.45
				step = 1
				Sfx.play("tick", 0.5)
			else:
				st -= d
				if st <= 0.0:
					var n = 7 if phase < 3 else 9
					for i in range(n):
						var a = dir.angle() + (float(i) - float(n - 1) * 0.5) * 0.13
						room.spawn_enemy_shot({"pos": center(), "vel": Vector2(cos(a), sin(a)) * 310.0, "r": 6.0, "dmg": 9.0 * dmg_k, "kind": "bullet", "src": display_name})
					room.fx.spray(center(), dir, Color(2.0, 1.6, 0.6), 8, 300.0, 0.4, 2.0, "spark", 0.2)
					Sfx.play("shoot", 0.6)
					count += 1
					st = 0.38
					if count >= 3 + phase:
						_to_idle(0.9)
			return Vector2.ZERO
		"horn":
			if step == 0:
				room.add_telegraph({"shape": "circle", "pos": global_position, "r": 150.0, "dur": (0.7) / tempo_now, "dmg": 18.0 * dmg_k, "owner": self, "src": display_name, "fx": "slam"})
				Sfx.play("horn", 0.8)
				st = 0.7
				step = 1
			elif step == 1:
				st -= d
				if st <= 0.0:
					Sfx.play("horn", 0.6)
					_ring(20, 180.0, 10.0 * dmg_k, "bullet")
					if phase >= 2:
						_ring(20, 130.0, 10.0 * dmg_k, "bullet", 0.16)
					step = 2
					st = 0.6
			else:
				st -= d
				if st <= 0.0:
					_to_idle(1.0)
			return Vector2.ZERO
		"goons":
			if step == 0:
				room.banner("\"Drop the boys off!\"", Color(1, 0.6, 0.9))
				for i in range(3):
					room.spawn_enemy("street_rat", global_position + Vector2(randf_range(-80, 80), randf_range(-60, 60)), false)
				if phase >= 3:
					room.spawn_enemy("alley_cat", room.random_spawn_pos(200.0), false)
				step = 1
				st = 1.0
			else:
				st -= d
				if st <= 0.0:
					_to_idle(1.2)
			return Vector2.ZERO
		"molotov":
			if step == 0:
				for i in range(4):
					var target = p.global_position + Vector2(randf_range(-150, 150), randf_range(-100, 100))
					room.add_telegraph({"shape": "circle", "pos": target, "r": 58.0, "dur": (1.0 + i * 0.12) / tempo_now, "dmg": 14.0 * dmg_k, "owner": null, "src": display_name, "fx": "explode", "lob_from": center(), "lob_kind": "molotov", "zone": {"kind": "enemy_fire", "r": 58.0, "life": 3.0, "power": 6.0}})
				step = 1
				st = 1.3
			else:
				st -= d
				if st <= 0.0:
					_to_idle(0.8)
			return Vector2.ZERO
	return Vector2.ZERO

# ---------------------------------------------------------------------------
# THE BIG BAND (jukebox)
# ---------------------------------------------------------------------------
func _band(d: float, p, dir: Vector2, dist: float) -> Vector2:
	var hover = home + Vector2(sin(t * 0.6) * 40.0, 0)
	var mv = (hover - global_position) * 2.0
	match state:
		"idle":
			st -= d
			if st <= 0.0:
				var opts = ["spiral", "records", "walls", "rings"]
				if phase >= 2:
					opts.append("encore")
				_begin(_choose(opts))
		"spiral":
			sub_t -= d
			st += d
			if sub_t <= 0.0:
				sub_t = 0.1
				var arms = phase + 1
				angle_acc += 0.23
				for i in range(arms):
					var a = angle_acc + TAU * float(i) / float(arms)
					var c = Color.from_hsv(fmod(t * 0.4 + float(i) * 0.2, 1.0), 0.6, 1.6)
					room.spawn_enemy_shot({"pos": center(), "vel": Vector2(cos(a), sin(a)) * 165.0, "r": 8.0, "dmg": 10.0 * dmg_k, "kind": "note", "src": display_name, "color": c})
				Sfx.play("tick", 1.5, -10.0)
			if st >= 3.2:
				_to_idle(1.0)
		"records":
			if step == 0:
				var n = 2 + phase
				for i in range(n):
					var a = dir.angle() + (float(i) - float(n - 1) * 0.5) * 0.35
					room.spawn_enemy_shot({"pos": center(), "vel": Vector2(cos(a), sin(a)) * 260.0, "r": 15.0, "dmg": 14.0 * dmg_k, "kind": "record", "src": display_name, "bounce": 3, "life": 7.0})
				Sfx.play("swing", 0.5)
				step = 1
				st = 1.6
			else:
				st -= d
				if st <= 0.0:
					_to_idle(0.6)
		"walls":
			if step == 0:
				var a: Rect2 = room.arena
				var rows = [0.25, 0.5, 0.75]
				rows.shuffle()
				var nrows = 2 if phase == 1 else 2
				for i in range(nrows):
					var y = a.position.y + a.size.y * float(rows[i])
					room.add_telegraph({"shape": "line", "pos": Vector2(a.position.x, y), "dir": Vector2.RIGHT, "len": a.size.x, "w": 60.0, "dur": (1.1) / tempo_now, "dmg": 20.0 * dmg_k, "owner": self, "src": display_name, "fx": "beam"})
				if phase >= 2:
					var cols = [0.2, 0.4, 0.6, 0.8]
					cols.shuffle()
					for i in range(phase - 1):
						var x = a.position.x + a.size.x * float(cols[i])
						room.add_telegraph({"shape": "line", "pos": Vector2(x, a.position.y), "dir": Vector2.DOWN, "len": a.size.y, "w": 60.0, "dur": (1.3) / tempo_now, "dmg": 20.0 * dmg_k, "owner": self, "src": display_name, "fx": "beam"})
				Sfx.play("roar", 2.0, -8.0)
				step = 1
				st = 1.5
			else:
				st -= d
				if st <= 0.0:
					_to_idle(0.7)
		"rings":
			sub_t -= d
			if sub_t <= 0.0:
				sub_t = 0.45
				count += 1
				_ring(16 + phase * 2, 150.0 + count * 15.0, 10.0 * dmg_k, "note", count * 0.2, Color.from_hsv(fmod(float(count) * 0.3, 1.0), 0.6, 1.6))
				room.fx.ring(center(), Color(1.5, 1.2, 0.6, 0.7), 20.0, 90.0, 0.3, 4.0)
				Sfx.play("horn", 1.2, -8.0)
				if count >= 3:
					_to_idle(1.1)
		"encore":
			if step == 0:
				room.banner("\"ENCORE!\"", Color(1.0, 0.85, 0.3))
				room.spawn_enemy("card_sharp", room.random_spawn_pos(250.0), false)
				room.spawn_enemy("card_sharp" if phase < 3 else "conductor", room.random_spawn_pos(250.0), false)
				step = 1
				st = 1.4
			else:
				st -= d
				if st <= 0.0:
					_to_idle(1.3)
	return mv

# ---------------------------------------------------------------------------
# THE MAN IN THE MOON
# ---------------------------------------------------------------------------
func _moon(d: float, p, dir: Vector2, dist: float) -> Vector2:
	var hover = home + Vector2(sin(t * 0.45) * 320.0, sin(t * 0.9) * 30.0)
	var mv = (hover - global_position) * 1.5
	facing = dir
	match state:
		"idle":
			st -= d
			if st <= 0.0:
				var opts = ["meteors", "beam", "starfall", "crescents"]
				if phase >= 2:
					opts.append("summon")
					opts.append("beam")
				_begin(_choose(opts))
		"meteors":
			if step == 0:
				var n = 9 if phase == 1 else (12 if phase == 2 else 16)
				for i in range(n):
					var off = Vector2.ZERO if i == 0 else Vector2(randf_range(-280, 280), randf_range(-170, 170))
					var target = p.global_position + off
					var a: Rect2 = room.arena
					target.x = clampf(target.x, a.position.x + 20, a.end.x - 20)
					target.y = clampf(target.y, a.position.y + 20, a.end.y - 20)
					room.add_telegraph({"shape": "circle", "pos": target, "r": 54.0, "dur": (1.1 + i * 0.09) / tempo_now, "dmg": 16.0 * dmg_k, "owner": null, "src": display_name, "fx": "explode", "lob_from": target + Vector2(-260, -700), "lob_kind": "meteor"})
				Sfx.play("whoosh_up", 0.6)
				step = 1
				st = 1.8
			else:
				st -= d
				if st <= 0.0:
					_to_idle(0.8)
			return mv * 0.4
		"beam":
			if step == 0:
				count = 0
				step = 1
				sub_t = 0.0
				angle_acc = dir.angle() - (0.9 if phase >= 3 else 0.0)
			sub_t -= d
			if sub_t <= 0.0:
				var n = 1 if phase == 1 else 3
				if phase >= 3:
					n = 1
				for i in range(n):
					var a2 = dir.angle() + (float(i) - float(n - 1) * 0.5) * 0.45
					if phase >= 3:
						a2 = angle_acc
						angle_acc += 0.3
					room.add_telegraph({"shape": "line", "pos": center() + Vector2(0, 40), "dir": Vector2(cos(a2), sin(a2)), "len": 1500.0, "w": 46.0, "dur": (0.9) / tempo_now, "dmg": 20.0 * dmg_k, "owner": self, "src": display_name, "fx": "beam"})
				Sfx.play("freeze", 0.5, -4.0)
				count += 1
				sub_t = 0.9 if phase < 3 else 0.22
				if count >= (2 if phase < 3 else 7):
					_to_idle(1.3)
			return mv * 0.2
		"starfall":
			if step == 0:
				_ring(22, 150.0, 11.0 * dmg_k, "star")
				step = 1
				st = 0.5
			elif step == 1:
				st -= d
				if st <= 0.0:
					_ring(22, 195.0, 11.0 * dmg_k, "star", TAU / 44.0)
					if phase >= 2:
						_ring(14, 120.0, 11.0 * dmg_k, "star", 0.1)
					step = 2
					st = 0.8
			else:
				st -= d
				if st <= 0.0:
					_to_idle(0.9)
			return mv
		"crescents":
			if step == 0:
				var n = 3 if phase < 3 else 5
				for i in range(n):
					var a = dir.angle() + (float(i) - float(n - 1) * 0.5) * 0.6
					room.spawn_enemy_shot({"pos": center(), "vel": Vector2(cos(a), sin(a)) * 200.0, "r": 12.0, "dmg": 14.0 * dmg_k, "kind": "crescent", "src": display_name, "homing": 1.6, "life": 5.0})
				Sfx.play("swing", 0.5)
				step = 1
				st = 1.4
			else:
				st -= d
				if st <= 0.0:
					_to_idle(0.8)
			return mv
		"summon":
			if step == 0:
				room.banner("\"Shine, my little stars!\"", Color(1.0, 0.95, 0.6))
				for i in range(3 + phase - 2):
					room.spawn_enemy("star_sprite", room.random_spawn_pos(220.0), false)
				if phase >= 3:
					room.spawn_enemy("comet", room.random_spawn_pos(250.0), false)
				step = 1
				st = 1.2
			else:
				st -= d
				if st <= 0.0:
					_to_idle(1.3)
			return mv
	return mv

# ---------------------------------------------------------------------------
# DEATH
# ---------------------------------------------------------------------------
func _die():
	if dead:
		return
	dead = true
	hp = 0.0
	remove_from_group("enemies")
	room.cancel_telegraphs(self)
	room.clear_enemy_shots()
	death_t = 0.0
	Sfx.play("roar", 0.8)
	GameData.hitstop(0.25, 0.1)
	room.on_boss_dying(self)

func _death_update(delta):
	death_t += delta
	velocity = Vector2.ZERO
	if int(death_t * 10.0) != int((death_t - delta) * 10.0) and death_t < 1.8:
		var p = center() + Vector2(randf_range(-radius, radius), randf_range(-radius, radius))
		room.fx.burst(p, Color(2.0, 1.2, 0.4), 12, 220.0, 4.0, "ember", 0.5)
		room.fx.ring(p, Color(2.0, 1.4, 0.6, 0.8), 6.0, 50.0, 0.25, 3.0)
		room.fx.shake(6.0)
		Sfx.play("explode", randf_range(0.8, 1.3), -6.0)
	if death_t >= 1.8 and death_t - delta < 1.8:
		room.fx.burst(center(), Color(2.2, 1.8, 0.8), 60, 500.0, 5.0, "shard", 1.0)
		room.fx.burst(center(), Color(1.8, 1.5, 0.6), 40, 300.0, 4.0, "confetti", 1.4)
		room.fx.ring(center(), Color(2.2, 1.8, 1.0, 0.9), 20.0, 400.0, 0.7, 10.0)
		room.fx.shake(18.0)
		Sfx.play("explode", 0.6)
		Sfx.play("jackpot")
		room.on_boss_killed(self)
		var tw = create_tween()
		tw.tween_property(self, "modulate:a", 0.0, 0.5)
		tw.tween_callback(queue_free)

# ---------------------------------------------------------------------------
# DRAW
# ---------------------------------------------------------------------------
func _draw():
	var shake_off = Vector2.ZERO
	if dead:
		shake_off = Vector2(randf_range(-4, 4), randf_range(-4, 4))
	# phase aura: the empire gets angrier (orange at phase 2, red at phase 3)
	if phase >= 2 and not dead:
		var pc = Color(2.0, 0.9, 0.2) if phase == 2 else Color(2.2, 0.3, 0.25)
		var pp = 0.5 + 0.5 * sin(t * (5.0 if phase == 2 else 8.0))
		Art.ellipse(self, Vector2.ZERO, radius * 1.9, radius * 0.7, Color(pc.r, pc.g, pc.b, 0.08 + 0.08 * pp))
		Art.ellipse_line(self, Vector2.ZERO, radius * (1.8 + 0.1 * pp), radius * (0.66 + 0.04 * pp), Color(pc.r, pc.g, pc.b, 0.45 + 0.3 * pp), 2.5)
		for ai in range(6 if phase == 2 else 10):
			var ak = fmod(t * 0.6 + float(ai) * 0.137, 1.0)
			var ax = sin(float(ai) * 1.9 + t * 0.8) * radius * 1.5
			draw_circle(Vector2(ax, -ak * radius * 3.5), 2.2 * (1.0 - ak) + 0.5, Color(pc.r, pc.g, pc.b, 0.85 * (1.0 - ak)))
	match kind:
		"big_sal":
			Art.shadow(self, Vector2.ZERO, 50)
			draw_set_transform(shake_off, 0.0, Vector2(2.3, 2.3))
			var an = "move"
			if state == "stomp" and step <= 1:
				an = "wind"
			elif state == "charge" and step == 2:
				an = "act"
			elif state != "idle":
				an = "idle"
			Art.draw_enemy(self, "bouncer", t, facing, an, 0.0)
			Art.bowler(self, Vector2(0, -61 + (sin(t * 12.0) * 1.2 if an == "move" else 0.0)), 1.0)
			draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
			# velvet-rope sash + VIP badge
			draw_line(Vector2(-36, -95), Vector2(36, -55), Color(0.75, 0.05, 0.12), 6.0)
			draw_circle(Vector2(20, -64), 7, Style.GOLD)
			if state == "charge" and step == 3:
				for i in range(4):
					var a = t * 5.0 + TAU * float(i) / 4.0
					Art.star(self, Vector2(cos(a) * 30, -130 + sin(a) * 8), 7, 3, 5, Color(1.8, 1.6, 0.4), 0.0)
		"getaway_car":
			_draw_car(shake_off)
		"big_band":
			_draw_jukebox(shake_off)
		"moon_man":
			_draw_moon(shake_off)
	if flash > 0.0:
		Art.ellipse(self, Vector2(0, -center_h), radius * 1.2, radius * 1.2, Color(2.5, 2.5, 2.5, flash * 0.35))
	if burn_t > 0.0:
		for i in range(4):
			var fx_ = (float(i) - 1.5) * radius * 0.5
			var h = 12.0 + sin(t * 18.0 + i * 2.0) * 4.0
			Art.poly(self, [Vector2(fx_ - 6, -center_h * 0.6), Vector2(fx_ + 6, -center_h * 0.6), Vector2(fx_, -center_h * 0.6 - h)], Color(2.0, 0.7, 0.15, 0.8))
	if chill > 0:
		Art.ellipse_line(self, Vector2.ZERO, radius * 1.3, radius * 0.5, Color(0.6, 1.0, 1.8, 0.7), 3.0)

func _draw_car(off: Vector2):
	var ang = heading.angle()
	Art.ellipse(self, Vector2(0, 4), 70, 30, Color(0, 0, 0, 0.4))
	draw_set_transform(off + Vector2(0, -18), ang, Vector2.ONE)
	# headlight cones when revving
	if state == "drive" and step <= 1:
		var cone = PackedVector2Array([Vector2(58, -18), Vector2(260, -70), Vector2(260, 70), Vector2(58, 18)])
		draw_colored_polygon(cone, Color(1.8, 1.6, 0.8, 0.18 + 0.1 * sin(t * 30.0)))
	# tires
	for tx in [-34.0, 34.0]:
		for ty in [-29.0, 29.0]:
			Art.rrect(self, Rect2(tx - 11, ty - 6, 22, 12), 4, Color(0.05, 0.05, 0.05))
			Art.rrect(self, Rect2(tx - 7, ty - 4, 14, 8), 3, Color(0.9, 0.9, 0.88))
	# body
	Art.rrect(self, Rect2(-62, -28, 124, 56), 22, Color(0.35, 0.05, 0.1))
	Art.rrect(self, Rect2(-58, -24, 116, 48), 18, Color(0.5, 0.08, 0.14))
	# chrome bumper + grille
	Art.rrect(self, Rect2(54, -24, 10, 48), 4, Color(0.85, 0.85, 0.9))
	Art.rrect(self, Rect2(-64, -22, 7, 44), 3, Color(0.8, 0.8, 0.85))
	# roof + windows
	Art.rrect(self, Rect2(-30, -21, 56, 42), 12, Color(0.28, 0.04, 0.08))
	Art.rrect(self, Rect2(14, -18, 14, 36), 5, Color(0.2, 0.3, 0.45, 0.9))
	Art.rrect(self, Rect2(-34, -18, 10, 36), 4, Color(0.2, 0.3, 0.45, 0.9))
	# goons in fedoras
	for gy in [-11.0, 11.0]:
		draw_circle(Vector2(-4, gy), 7, Color(0.1, 0.1, 0.12))
		Art.ellipse(self, Vector2(-4, gy), 9, 9, Color(0.15, 0.15, 0.17))
		draw_circle(Vector2(-4, gy), 5, Color(0.2, 0.2, 0.22))
	if state == "tommy":
		draw_circle(Vector2(0, -30), 5, Color(2.2, 1.8, 0.6, 0.6 + 0.4 * sin(t * 50.0)))
		draw_circle(Vector2(0, 30), 5, Color(2.2, 1.8, 0.6, 0.6 + 0.4 * sin(t * 50.0 + 1.0)))
	# headlights / taillights
	draw_circle(Vector2(58, -16), 5, Color(2.2, 2.0, 1.2))
	draw_circle(Vector2(58, 16), 5, Color(2.2, 2.0, 1.2))
	draw_circle(Vector2(-60, -16), 4, Color(2.0, 0.2, 0.2))
	draw_circle(Vector2(-60, 16), 4, Color(2.0, 0.2, 0.2))
	# whitewall stripe
	draw_line(Vector2(-50, 0), Vector2(50, 0), Color(0.7, 0.1, 0.15, 0.5), 2.0)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

func _draw_jukebox(off: Vector2):
	var c = Vector2(0, -80) + off + Vector2(0, sin(t * 1.5) * 3.0)
	Art.ellipse(self, Vector2(0, 0), 90, 26, Color(0, 0, 0, 0.45))
	# speakers on either side
	for sx in [-92.0, 92.0]:
		Art.rrect(self, Rect2(c.x + sx - 26, c.y - 20, 52, 90), 8, Color(0.2, 0.12, 0.08))
		var pump = 1.0 + 0.08 * absf(sin(t * 8.0))
		draw_circle(Vector2(c.x + sx, c.y + 5), 17 * pump, Color(0.08, 0.08, 0.08))
		draw_circle(Vector2(c.x + sx, c.y + 5), 7 * pump, Color(0.3, 0.3, 0.3))
		draw_circle(Vector2(c.x + sx, c.y + 48), 11 * pump, Color(0.08, 0.08, 0.08))
	# cabinet
	Art.rrect(self, Rect2(c.x - 62, c.y - 40, 124, 120), 10, Color(0.45, 0.22, 0.08))
	var arch = PackedVector2Array()
	for i in range(21):
		var a = PI + PI * float(i) / 20.0
		arch.append(c + Vector2(0, -40) + Vector2(cos(a) * 62, sin(a) * 58))
	draw_colored_polygon(arch, Color(0.45, 0.22, 0.08))
	# neon tubes (rainbow cycling)
	for k in range(3):
		var col = Color.from_hsv(fmod(t * 0.35 + k * 0.18, 1.0), 0.8, 1.8)
		var pts = PackedVector2Array()
		for i in range(21):
			var a = PI + PI * float(i) / 20.0
			pts.append(c + Vector2(0, -40) + Vector2(cos(a) * (54 - k * 9), sin(a) * (50 - k * 9)))
		draw_polyline(pts, col, 4.0, true)
		draw_line(c + Vector2(-54 + k * 9, -40), c + Vector2(-54 + k * 9, 70), col, 4.0)
		draw_line(c + Vector2(54 - k * 9, -40), c + Vector2(54 - k * 9, 70), col, 4.0)
	# record window
	Art.rrect(self, Rect2(c.x - 30, c.y - 36, 60, 44), 6, Color(0.08, 0.06, 0.1))
	Art.record_glyph(self, c + Vector2(0, -14), 18, t * 3.0)
	# grille with glowing face
	Art.rrect(self, Rect2(c.x - 30, c.y + 14, 60, 56), 6, Color(0.9, 0.75, 0.4))
	for i in range(6):
		draw_line(Vector2(c.x - 26 + i * 10.4, c.y + 18), Vector2(c.x - 26 + i * 10.4, c.y + 66), Color(0.5, 0.35, 0.15), 2.0)
	var eye_col = Color(2.2, 0.4, 0.3) if phase >= 2 else Color(1.8, 1.4, 0.5)
	draw_circle(c + Vector2(-13, 30), 6, eye_col)
	draw_circle(c + Vector2(13, 30), 6, eye_col)
	draw_arc(c + Vector2(0, 46), 14, 0.2, PI - 0.2, 10, eye_col, 3.0)
	# base
	Art.rrect(self, Rect2(c.x - 70, c.y + 70, 140, 14), 4, Color(0.25, 0.12, 0.05))
	# Top Hat Records' crown
	Art.top_hat(self, c + Vector2(0, -96), 1.4, Style.GOLD)

func _draw_moon(off: Vector2):
	var c = Vector2(0, -90) + off
	Art.shadow(self, Vector2.ZERO, 60, 0.25)
	Art.glow(self, c, 120, Color(1.2, 1.1, 0.6, 0.35), 5)
	# crescent: outer circle arc + inner circle arc
	# crescent: outer arc (tips at +-60 deg) + inner arc through the same tips
	var pts = PackedVector2Array()
	var R = 70.0
	var inner_c = c + Vector2(40, 0)
	var r2 = 60.8
	for i in range(33):
		var a = deg_to_rad(60.0 + 240.0 * float(i) / 32.0)
		pts.append(c + Vector2(cos(a), sin(a)) * R)
	for i in range(1, 32):
		var a = deg_to_rad(265.3 - 170.6 * float(i) / 32.0)
		pts.append(inner_c + Vector2(cos(a), sin(a)) * r2)
	var moon_col = Color(1.35, 1.25, 0.8) if phase < 3 else Color(1.5, 1.1, 0.8)
	draw_colored_polygon(pts, moon_col)
	# craters
	draw_circle(c + Vector2(-50, -22), 7, Color(1.0, 0.92, 0.6))
	draw_circle(c + Vector2(-46, 30), 8, Color(1.0, 0.92, 0.6))
	draw_circle(c + Vector2(-60, 6), 4, Color(1.0, 0.92, 0.6))
	# face on the inner edge
	var eye = c + Vector2(-30, -20)
	if phase >= 3:
		draw_circle(eye, 6, Color(2.2, 0.3, 0.2))
	else:
		draw_arc(eye, 6, 0.2, PI - 0.2, 8, Color(0.4, 0.3, 0.1), 3.0)
	Art.poly(self, [c + Vector2(-24, -6), c + Vector2(-8, 4), c + Vector2(-23, 8)], moon_col)
	draw_arc(c + Vector2(-32, 22), 11, 0.2, 1.4, 8, Color(0.5, 0.3, 0.15), 3.0)
	# THE HAT: a colossal top hat on the moon's crown
	var ht = c + Vector2(-26, -60)
	draw_set_transform(ht, -0.35, Vector2.ONE)
	Art.ellipse(self, Vector2.ZERO, 42, 9, Color(0.06, 0.05, 0.08))
	Art.rrect(self, Rect2(-26, -58, 52, 58), 4, Color(0.08, 0.07, 0.1))
	Art.rrect(self, Rect2(-26, -16, 52, 10), 2, Color(0.75, 0.1, 0.2))
	Art.star(self, Vector2(14, -11), 6, 2.5, 5, Color(2.0, 1.8, 0.8), t)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
