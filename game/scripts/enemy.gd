extends CharacterBody2D

## Enemy: one data-driven script for every regular foe.
## Behaviours: swarm / brute / shooter / lobber / charger / bomber / turret / support / die

const Art = preload("res://scripts/art.gd")
const WorldData = preload("res://scripts/world_data.gd")

var kind: String = "bouncer"
var data: Dictionary = {}
var room = null
var display_name: String = "Enemy"
var hp: float = 50.0
var max_hp: float = 50.0
var dmg: float = 10.0
var speed: float = 80.0
var radius: float = 14.0
var center_h: float = 18.0
var elite: bool = false
var is_boss: bool = false
var beh: String = "brute"
var flying: bool = false
var size_k: float = 1.0

var state: String = "idle"
var st: float = 0.5
var t: float = 0.0
var anim: String = "idle"
var facing: Vector2 = Vector2.DOWN
var knock: Vector2 = Vector2.ZERO
var knock_res: float = 1.0
var atk_cd: float = 1.0
var contact_cd: float = 0.0
var strafe: float = 1.0
var strafe_t: float = 0.0
var charge_dir: Vector2 = Vector2.ZERO
var charge_hit: bool = false
var extra: float = 1.0
var turret_angle: float = 0.0
var roam_target: Vector2 = Vector2.ZERO

# statuses
var burn_dps: float = 0.0
var burn_t: float = 0.0
var burn_tick: float = 0.0
var chill: int = 0
var chill_t: float = 0.0
var freeze_t: float = 0.0
var stun_t: float = 0.0
var buff_t: float = 0.0

var dead: bool = false
var flash: float = 0.0
var spawn_t: float = 0.35

func setup(k: String, room_ref, hp_mult: float, dmg_mult: float, is_elite: bool):
	kind = k
	room = room_ref
	data = WorldData.ENEMIES.get(k, WorldData.ENEMIES["bouncer"])
	display_name = String(data["name"])
	elite = is_elite
	size_k = 1.25 if elite else 1.0
	max_hp = float(data["hp"]) * hp_mult * (2.4 if elite else 1.0)
	hp = max_hp
	dmg = float(data["dmg"]) * dmg_mult * (1.25 if elite else 1.0)
	speed = float(data["speed"]) * randf_range(0.9, 1.1)
	radius = float(data["radius"]) * size_k
	beh = String(data["beh"])
	flying = data.get("fly", false)
	center_h = 18.0 * size_k
	if flying:
		center_h = 26.0
	if elite:
		display_name = "Elite " + display_name
	match beh:
		"turret":
			knock_res = 0.15
		"brute":
			knock_res = 0.55
		"swarm":
			knock_res = 1.4
	if kind == "loaded_die":
		extra = float(randi_range(1, 6))
		var a = randf_range(0.3, 1.2) + float(randi_range(0, 3)) * PI * 0.5
		charge_dir = Vector2(cos(a), sin(a))
	atk_cd = randf_range(0.8, 2.0)

func _ready():
	add_to_group("enemies")
	motion_mode = CharacterBody2D.MOTION_MODE_FLOATING
	collision_layer = 4
	collision_mask = 0 if flying else 5
	var col = CollisionShape2D.new()
	var sh = CircleShape2D.new()
	sh.radius = radius * 0.8
	col.shape = sh
	col.position = Vector2(0, -4)
	add_child(col)
	scale = Vector2(0.2, 0.2)
	var tw = create_tween()
	tw.tween_property(self, "scale", Vector2.ONE, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

func center() -> Vector2:
	return global_position + Vector2(0, -center_h)

func _player():
	if room == null:
		return null
	return room.player

# ---------------------------------------------------------------------------
# DAMAGE & STATUS
# ---------------------------------------------------------------------------
func take_hit(amount: float, dir: Vector2, knock_force: float, crit: bool, src: String):
	if dead:
		return
	hp -= amount
	flash = 1.0
	knock += dir * knock_force * knock_res
	var col = Color(1, 0.95, 0.85)
	if src == "burn":
		col = Color(1.0, 0.55, 0.2)
	elif src == "zap":
		col = Color(0.85, 0.7, 1.0)
	room.fx.damage_number(center(), amount, crit, col)
	if src != "burn":
		room.fx.spray(center(), dir if dir.length() > 0.1 else Vector2.UP, Color(1.6, 1.4, 1.0), 5 if not crit else 10, 260.0, 0.7, 2.0, "spark", 0.25)
		Sfx.play("crit" if crit else "hit", randf_range(0.9, 1.15), -2.0 if crit else -5.0)
	if crit:
		room.fx.shake(3.0)
	# heavy hits interrupt charging foes
	if knock_force > 300.0 and state == "wind" and beh in ["charger", "shooter", "lobber"]:
		state = "recover"
		st = 0.6
		room.cancel_telegraphs(self)
	if hp <= 0.0:
		_die()

func apply_status(skind: String, power: float):
	if dead:
		return
	match skind:
		"burn":
			if burn_t <= 0.0:
				Sfx.play("burn", 1.0, -8.0)
			burn_dps = maxf(burn_dps, power) + power * 0.2
			burn_t = 3.0
		"chill":
			chill = mini(5, chill + int(power))
			chill_t = 4.0
			var p = _player()
			if chill >= 5 and p != null and p.has("luna_blue") and freeze_t <= 0.0:
				freeze_t = p.bv("luna_blue")
				chill = 0
				room.fx.burst(center(), Color(0.7, 1.2, 2.0), 14, 160.0, 3.0, "shard", 0.6)
				Sfx.play("freeze")
		"stun":
			stun_t = maxf(stun_t, power * (0.4 if beh == "turret" else 1.0))

func _status_tick(delta):
	if burn_t > 0.0:
		burn_t -= delta
		burn_tick -= delta
		if burn_tick <= 0.0:
			burn_tick = 0.5
			var p = _player()
			var mult = p.burn_multiplier(self) if p != null else 1.0
			take_hit(burn_dps * 0.5 * mult, Vector2.ZERO, 0.0, false, "burn")
			if dead:
				return
			if randf() < 0.6:
				room.fx.burst(center() + Vector2(randf_range(-8, 8), -6), Color(2.0, 0.7, 0.15, 0.9), 2, 40.0, 3.0, "ember", 0.6)
		if burn_t <= 0.0:
			burn_dps = 0.0
	if chill_t > 0.0:
		chill_t -= delta
		if chill_t <= 0.0:
			chill = 0
	freeze_t -= delta
	stun_t -= delta
	buff_t -= delta

# ---------------------------------------------------------------------------
# AI
# ---------------------------------------------------------------------------
func _physics_process(delta):
	if dead:
		return
	t += delta
	flash = maxf(0.0, flash - delta * 8.0)
	spawn_t -= delta
	contact_cd -= delta
	_status_tick(delta)
	if dead:
		return
	knock = knock.move_toward(Vector2.ZERO, 1400.0 * delta)
	var p = _player()
	if p == null or not p.alive or spawn_t > 0.0:
		velocity = knock
		move_and_slide()
		queue_redraw()
		return
	if freeze_t > 0.0 or stun_t > 0.0:
		velocity = knock
		anim = "idle"
		move_and_slide()
		_clamp_to_arena()
		queue_redraw()
		return
	var sm = (1.0 - 0.09 * chill) * (1.4 if buff_t > 0.0 else 1.0)
	var tempo = 1.4 if buff_t > 0.0 else 1.0
	var to_p: Vector2 = p.global_position - global_position
	var dist = to_p.length()
	var dir = to_p.normalized() if dist > 0.1 else Vector2.DOWN
	var desired = Vector2.ZERO
	atk_cd -= delta * tempo
	st -= delta * tempo
	match beh:
		"swarm":
			desired = _b_swarm(p, dir, dist, sm)
		"brute":
			desired = _b_brute(p, dir, dist, sm)
		"shooter":
			desired = _b_shooter(p, dir, dist, sm, delta)
		"lobber":
			desired = _b_lobber(p, dir, dist, sm, delta)
		"charger":
			desired = _b_charger(p, dir, dist, sm)
		"bomber":
			desired = _b_bomber(p, dir, dist, sm)
		"turret":
			desired = _b_turret(p, dir, dist, sm, delta)
		"support":
			desired = _b_support(p, dir, dist, sm)
		"die":
			desired = _b_die(p, dir, dist, sm)
	if dead:
		return
	velocity = desired + knock
	move_and_slide()
	if beh == "die" and state == "move" and get_slide_collision_count() > 0:
		var c = get_slide_collision(0)
		charge_dir = charge_dir.bounce(c.get_normal()).normalized()
	_clamp_to_arena()
	queue_redraw()

func _clamp_to_arena():
	var a: Rect2 = room.arena
	global_position.x = clampf(global_position.x, a.position.x + radius, a.end.x - radius)
	global_position.y = clampf(global_position.y, a.position.y + radius, a.end.y - 4.0)

func _contact(p, amount: float, dir: Vector2, cd: float = 0.9) -> bool:
	if contact_cd > 0.0:
		return false
	if p.global_position.distance_to(global_position) < radius + p.radius + 6.0:
		contact_cd = cd
		p.take_damage(amount, dir, display_name)
		return true
	return false

func _b_swarm(p, dir: Vector2, dist: float, sm: float) -> Vector2:
	anim = "move"
	facing = dir
	var wobble = dir.orthogonal() * sin(t * 5.0 + float(get_instance_id() % 7)) * 0.6
	_contact(p, dmg, dir, 1.0)
	return (dir + wobble).normalized() * speed * sm

func _b_brute(p, dir: Vector2, dist: float, sm: float) -> Vector2:
	match state:
		"wind":
			anim = "wind"
			if st <= 0.0:
				state = "act"
				st = 0.3
				room.fx.shake(4.0)
				Sfx.play("slam", 1.2, -6.0)
			return Vector2.ZERO
		"act":
			anim = "act"
			if st <= 0.0:
				state = "idle"
				atk_cd = 1.1
			return Vector2.ZERO
	anim = "move"
	facing = dir
	if dist < 80.0 * size_k and atk_cd <= 0.0:
		state = "wind"
		st = 0.7
		var hit_r = 60.0 * size_k
		room.add_telegraph({"shape": "circle", "pos": global_position + dir * 34.0 * size_k, "r": hit_r, "dur": 0.7 / (1.4 if buff_t > 0.0 else 1.0), "dmg": dmg, "owner": self, "src": display_name, "fx": "slam"})
		return Vector2.ZERO
	return dir * speed * sm

func _b_shooter(p, dir: Vector2, dist: float, sm: float, delta: float) -> Vector2:
	facing = dir
	match state:
		"wind":
			anim = "wind"
			if st <= 0.0:
				_fire(p, dir)
				state = "recover"
				st = 0.35
			return Vector2.ZERO
		"recover":
			anim = "idle"
			if st <= 0.0:
				state = "idle"
			return Vector2.ZERO
	anim = "move"
	strafe_t -= delta
	if strafe_t <= 0.0:
		strafe_t = randf_range(1.2, 2.4)
		strafe = -strafe
	var mv = Vector2.ZERO
	if dist < 200.0:
		mv = -dir
	elif dist > 330.0:
		mv = dir
	else:
		mv = dir.orthogonal() * strafe * 0.7
	if atk_cd <= 0.0 and dist < 560.0:
		state = "wind"
		st = 0.5
		atk_cd = randf_range(2.0, 2.8)
		if data.get("shot", "") == "flash":
			Sfx.play("tick", 2.0, -4.0)
	return mv * speed * sm

func _fire(p, dir: Vector2):
	var shot = String(data.get("shot", "flash"))
	var origin = center()
	match shot:
		"flash":
			room.spawn_enemy_shot({"pos": origin, "vel": dir * 340.0, "r": 8.0, "dmg": dmg, "kind": "flash", "src": display_name})
			if elite:
				room.spawn_enemy_shot({"pos": origin, "vel": dir.rotated(0.2) * 340.0, "r": 8.0, "dmg": dmg, "kind": "flash", "src": display_name})
				room.spawn_enemy_shot({"pos": origin, "vel": dir.rotated(-0.2) * 340.0, "r": 8.0, "dmg": dmg, "kind": "flash", "src": display_name})
			room.fx.burst(origin + Vector2(0, -8), Color(2.5, 2.5, 2.0), 10, 120.0, 3.0, "dot", 0.2)
			room.fx.ring(origin + Vector2(0, -8), Color(2.0, 2.0, 1.8, 0.8), 4.0, 34.0, 0.18, 3.0)
			Sfx.play("flash")
		"fan":
			var n = 5 if elite else 3
			for i in range(n):
				var a = (float(i) - float(n - 1) * 0.5) * 0.24
				room.spawn_enemy_shot({"pos": origin, "vel": dir.rotated(a) * 270.0, "r": 8.0, "dmg": dmg, "kind": "card", "src": display_name})
			Sfx.play("eshoot")
		"ring":
			var n2 = 12 if elite else 9
			var off = randf() * TAU
			for i in range(n2):
				var a2 = off + TAU * float(i) / float(n2)
				room.spawn_enemy_shot({"pos": origin, "vel": Vector2(cos(a2), sin(a2)) * 150.0, "r": 8.0, "dmg": dmg, "kind": "note", "src": display_name})
			room.spawn_enemy_shot({"pos": origin, "vel": dir * 230.0, "r": 9.0, "dmg": dmg, "kind": "note", "src": display_name})
			room.fx.ring(origin, Color(0.5, 1.2, 1.6, 0.7), 6.0, 50.0, 0.3, 3.0)
			Sfx.play("horn", 0.7, -6.0)

func _b_lobber(p, dir: Vector2, dist: float, sm: float, delta: float) -> Vector2:
	facing = dir
	match state:
		"wind":
			anim = "wind"
			if st <= 0.0:
				var n = 3 if elite else 1
				for i in range(n):
					var off = Vector2.ZERO if i == 0 else Vector2(randf_range(-70, 70), randf_range(-50, 50))
					var target = p.global_position + p.velocity * 0.35 + off
					room.add_telegraph({"shape": "circle", "pos": target, "r": 46.0, "dur": 1.0, "dmg": dmg, "owner": null, "src": display_name, "fx": "glass", "lob_from": center() + Vector2(0, -20), "lob_kind": "bottle"})
				Sfx.play("swing", 0.7, -4.0)
				state = "recover"
				st = 0.4
			return Vector2.ZERO
		"recover":
			anim = "idle"
			if st <= 0.0:
				state = "idle"
			return Vector2.ZERO
	anim = "move"
	strafe_t -= delta
	if strafe_t <= 0.0:
		strafe_t = randf_range(1.5, 3.0)
		strafe = -strafe
	var mv = dir.orthogonal() * strafe * 0.6
	if dist < 230.0:
		mv = -dir
	elif dist > 380.0:
		mv = dir
	if atk_cd <= 0.0 and dist < 600.0:
		state = "wind"
		st = 0.55
		atk_cd = randf_range(2.4, 3.2)
	return mv * speed * sm

func _b_charger(p, dir: Vector2, dist: float, sm: float) -> Vector2:
	match state:
		"wind":
			anim = "wind"
			facing = charge_dir
			if st <= 0.0:
				state = "charge"
				st = 0.42
				charge_hit = false
				Sfx.play("dash", 0.7, -3.0)
			return Vector2.ZERO
		"charge":
			anim = "act"
			if not charge_hit and _contact(p, dmg, charge_dir, 0.3):
				charge_hit = true
			if kind == "comet" and randf() < 0.6:
				room.fx.burst(center(), Color(0.6, 1.0, 1.8, 0.7), 1, 30.0, 3.0, "ember", 0.4)
			if st <= 0.0:
				state = "recover"
				st = 0.8
			return charge_dir * 640.0 * (1.0 - 0.06 * chill)
		"recover":
			anim = "idle"
			if st <= 0.0:
				state = "idle"
				atk_cd = randf_range(0.6, 1.4)
			return Vector2.ZERO
	anim = "move"
	facing = dir
	if dist < 280.0 and atk_cd <= 0.0:
		state = "wind"
		st = 0.6
		charge_dir = dir
		room.add_telegraph({"shape": "line", "pos": global_position, "dir": dir, "len": 290.0, "w": radius * 2.2, "dur": 0.6, "dmg": 0.0, "owner": self, "visual": true, "src": display_name})
		return Vector2.ZERO
	return dir * speed * sm

func _b_bomber(p, dir: Vector2, dist: float, sm: float) -> Vector2:
	facing = dir
	if state == "wind":
		anim = "wind"
		if st <= 0.0:
			_explode()
		return Vector2.ZERO
	anim = "move"
	if dist < 70.0:
		state = "wind"
		st = 0.85
		room.add_telegraph({"shape": "circle", "pos": global_position, "r": 82.0, "dur": 0.85, "dmg": dmg, "owner": self, "src": display_name, "fx": "explode"})
		Sfx.play("burn", 1.5)
		return Vector2.ZERO
	return dir * speed * sm

func _explode():
	room.add_zone({"pos": global_position, "r": 55.0, "life": 2.5, "kind": "enemy_fire", "power": dmg * 0.4, "src": display_name})
	hp = 0.0
	_die()

func _b_turret(p, dir: Vector2, dist: float, sm: float, delta: float) -> Vector2:
	facing = dir
	var mv = Vector2.ZERO
	if flying:
		if roam_target == Vector2.ZERO or global_position.distance_to(roam_target) < 20.0:
			var a: Rect2 = room.arena
			roam_target = Vector2(randf_range(a.position.x + 80, a.end.x - 80), randf_range(a.position.y + 60, a.end.y - 60))
		mv = (roam_target - global_position).normalized() * speed * sm
	match state:
		"wind":
			anim = "wind"
			if st <= 0.0:
				state = "act"
				st = 2.0 if not flying else 0.6
				extra = 0.0
			return mv * 0.3
		"act":
			anim = "act"
			extra -= delta
			if extra <= 0.0:
				if flying:
					extra = 0.18
					room.spawn_enemy_shot({"pos": center(), "vel": dir * 300.0, "r": 7.0, "dmg": dmg, "kind": "orb", "src": display_name, "color": Color(1.6, 0.4, 0.4)})
				else:
					extra = 0.17
					turret_angle += 0.33
					var arms = 6 if elite else 4
					for i in range(arms):
						var a2 = turret_angle + TAU * float(i) / float(arms)
						room.spawn_enemy_shot({"pos": center(), "vel": Vector2(cos(a2), sin(a2)) * 175.0, "r": 7.0, "dmg": dmg, "kind": "coin", "src": display_name})
				Sfx.play("chip", 0.8, -10.0)
			if st <= 0.0:
				state = "idle"
				atk_cd = randf_range(1.2, 1.8)
			return mv * 0.3
	anim = "idle"
	if atk_cd <= 0.0:
		state = "wind"
		st = 0.55
	return mv

func _b_support(p, dir: Vector2, dist: float, sm: float) -> Vector2:
	facing = dir
	if state == "act":
		anim = "act"
		if st <= 0.0:
			state = "idle"
		return Vector2.ZERO
	anim = "move"
	if atk_cd <= 0.0:
		state = "act"
		st = 0.6
		atk_cd = 3.4
		var buffed = 0
		for e in room.get_targets():
			if e != self and not e.is_boss and e.global_position.distance_to(global_position) < 280.0:
				e.buff_t = 4.5
				buffed += 1
				room.fx.burst(e.center() + Vector2(0, -20), Color(1.6, 1.3, 0.5, 0.9), 3, 50.0, 7.0, "note", 0.9)
		room.fx.ring(center(), Color(1.6, 1.3, 0.5, 0.8), 10.0, 280.0, 0.5, 3.0)
		room.spawn_enemy_shot({"pos": center(), "vel": dir * 200.0, "r": 9.0, "dmg": dmg, "kind": "note", "src": display_name})
		Sfx.play("levelup", 0.8, -8.0)
		return Vector2.ZERO
	if dist < 300.0:
		return -dir * speed * sm
	return dir.orthogonal() * strafe * speed * 0.4 * sm

func _b_die(p, dir: Vector2, dist: float, sm: float) -> Vector2:
	if state == "wind":
		anim = "wind"
		if st <= 0.0:
			var n = int(extra) * 2
			var off = randf() * TAU
			for i in range(n):
				var a = off + TAU * float(i) / float(n)
				room.spawn_enemy_shot({"pos": center(), "vel": Vector2(cos(a), sin(a)) * 200.0, "r": 7.0, "dmg": dmg * 0.8, "kind": "orb", "src": display_name, "color": Color(1.8, 0.3, 0.35)})
			Sfx.play("chip", 0.6)
			state = "move"
			st = randf_range(2.2, 3.0)
			var a3 = randf_range(0.3, 1.2) + float(randi_range(0, 3)) * PI * 0.5
			charge_dir = Vector2(cos(a3), sin(a3))
		return Vector2.ZERO
	state = "move"
	anim = "move"
	facing = charge_dir
	_contact(p, dmg, charge_dir, 0.8)
	if st <= 0.0:
		state = "wind"
		st = 0.7
		extra = float(randi_range(1, 6))
		room.fx.text(center() + Vector2(0, -30), str(int(extra)), Color(1.6, 0.3, 0.3), 26)
	return charge_dir * speed * sm

# ---------------------------------------------------------------------------
# DEATH
# ---------------------------------------------------------------------------
func _die():
	if dead:
		return
	dead = true
	remove_from_group("enemies")
	room.cancel_telegraphs(self)
	var col: Color = data.get("color", Color(0.6, 0.2, 0.2))
	room.fx.burst(center(), col.lightened(0.2), 16, 240.0, 4.0, "shard", 0.7)
	room.fx.burst(center(), Color(1.6, 1.4, 1.0), 8, 160.0, 2.0, "spark", 0.3)
	room.fx.ring(center(), Color(1.5, 1.3, 1.0, 0.6), 6.0, 40.0 * size_k, 0.25, 3.0)
	var p = _player()
	if p != null:
		p.on_enemy_killed(self)
	var rp = int(data.get("rp", 1)) * (3 if elite else 1)
	room.drop_rp(global_position, rp)
	if elite or randf() < 0.4:
		room.drop_chips(global_position, randi_range(1, 3) * (4 if elite else 1))
	room.on_enemy_killed(self)
	for c in get_children():
		if c is CollisionShape2D:
			c.set_deferred("disabled", true)
	var tw = create_tween()
	tw.tween_property(self, "scale", Vector2(1.3, 0.2), 0.12)
	tw.parallel().tween_property(self, "modulate:a", 0.0, 0.2)
	tw.tween_callback(queue_free)

# ---------------------------------------------------------------------------
# DRAW
# ---------------------------------------------------------------------------
func _draw():
	# soft ambient-occlusion pool under every foe
	Art.ellipse(self, Vector2.ZERO, radius * 1.7, radius * 0.6, Color(0, 0, 0, 0.14))
	if elite:
		var pulse = 0.5 + 0.5 * sin(t * 4.0)
		Art.ellipse(self, Vector2.ZERO, radius * 1.4, radius * 0.55, Color(1.6, 1.2, 0.3, 0.25 + 0.2 * pulse))
		Art.ellipse_line(self, Vector2.ZERO, radius * 1.5, radius * 0.6, Color(1.8, 1.4, 0.4, 0.7), 2.0)
		# rising gold motes
		for mi in range(4):
			var mk = fmod(t * 0.7 + float(mi) * 0.25, 1.0)
			var mx = sin(float(mi) * 2.3 + t) * radius * 1.1
			draw_circle(Vector2(mx, -mk * radius * 3.0), 1.6 * (1.0 - mk) + 0.4, Color(2.0, 1.6, 0.5, 0.8 * (1.0 - mk)))
	if buff_t > 0.0:
		Art.ellipse_line(self, Vector2.ZERO, radius * 1.3, radius * 0.5, Color(1.6, 1.3, 0.5, 0.6), 2.0)
	# wind-up tell: pulsing red ring at the feet
	if anim == "wind" and not dead:
		var wp = 0.5 + 0.5 * sin(t * 22.0)
		Art.ellipse_line(self, Vector2.ZERO, radius * (1.25 + 0.15 * wp), radius * (0.5 + 0.06 * wp), Color(2.0, 0.35, 0.3, 0.55 + 0.35 * wp), 2.0)
	# breathing + hit squash (feet stay planted)
	var breathe = sin(t * 3.2 + float(get_instance_id() % 7)) * 0.025
	var sq = flash * 0.12
	var body_scale = Vector2(size_k * (1.0 + sq - breathe * 0.5), size_k * (1.0 - sq + breathe))
	draw_set_transform(Vector2.ZERO, 0.0, body_scale)
	Art.draw_enemy(self, kind, t, facing, anim, extra)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	var c = center()
	var lc = c - global_position
	if elite and not dead:
		# little gold crown so elites read at a glance
		var cy = lc.y - radius - 30.0 - (6.0 if flying else 0.0)
		var crown = [Vector2(-8, cy + 4), Vector2(-8, cy - 3), Vector2(-4, cy + 0.5), Vector2(0, cy - 6), Vector2(4, cy + 0.5), Vector2(8, cy - 3), Vector2(8, cy + 4)]
		Art.poly(self, crown, Color(1.9, 1.45, 0.4))
		draw_polyline(PackedVector2Array(crown + [crown[0]]), Color(0.35, 0.2, 0.05, 0.9), 1.0)
		draw_circle(Vector2(0, cy - 6), 1.5, Color(2.2, 0.5, 0.5))
	if freeze_t > 0.0:
		Art.rrect(self, Rect2(lc.x - radius - 4, lc.y - radius - 14, radius * 2 + 8, radius * 2 + 28), 5, Color(0.6, 0.9, 1.4, 0.5))
	elif chill > 0:
		for i in range(chill):
			var a = t * 2.0 + TAU * float(i) / float(chill)
			Art.star(self, lc + Vector2(cos(a) * (radius + 6), sin(a) * 6 - radius - 8), 4, 1.5, 6, Color(0.7, 1.1, 1.8, 0.9), t)
	if burn_t > 0.0:
		for i in range(3):
			var fx_ = lc.x + (float(i) - 1.0) * radius * 0.6
			var h = 8.0 + sin(t * 18.0 + i * 2.0) * 3.0
			Art.poly(self, [Vector2(fx_ - 4, lc.y - radius * 0.2), Vector2(fx_ + 4, lc.y - radius * 0.2), Vector2(fx_, lc.y - radius * 0.2 - h)], Color(2.0, 0.7, 0.15, 0.8))
	if stun_t > 0.0:
		for i in range(3):
			var a2 = t * 6.0 + TAU * float(i) / 3.0
			Art.star(self, lc + Vector2(cos(a2) * 14, -radius - 14 + sin(a2) * 4), 4, 2, 5, Color(1.8, 1.6, 0.4), 0.0)
	if flash > 0.0:
		Art.ellipse(self, lc, radius * 1.1, radius * 1.3, Color(2.5, 2.5, 2.5, flash * 0.55))
	if hp < max_hp:
		var bw = 34.0 * size_k
		var by = lc.y - radius - 22.0 - (6.0 if flying else 0.0)
		draw_rect(Rect2(-bw * 0.5 - 1, by - 1, bw + 2, 6), Color(0, 0, 0, 0.7))
		draw_rect(Rect2(-bw * 0.5, by, bw * clampf(hp / max_hp, 0.0, 1.0), 4), Color(0.95, 0.2, 0.2) if not elite else Color(1.0, 0.75, 0.2))
		if burn_t > 0.0:
			draw_rect(Rect2(-bw * 0.5, by + 4, bw * clampf(burn_t / 3.0, 0.0, 1.0), 1.5), Color(2.0, 0.7, 0.15))
