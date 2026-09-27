extends Control

var center: Vector2
var radius: float = 80.0
var stick_pos: Vector2 = Vector2.ZERO
var dragging: bool = false
var touch_idx: int = -1

func _ready():
	custom_minimum_size = Vector2(200, 200)
	center = custom_minimum_size / 2.0
	queue_redraw()

func _input(event):
	if event is InputEventScreenTouch:
		if event.pressed and not dragging:
			if get_global_rect().has_point(event.position):
				dragging = true
				touch_idx = event.index
				_update_stick(event.position)
		elif not event.pressed and event.index == touch_idx:
			dragging = false
			touch_idx = -1
			stick_pos = Vector2.ZERO
			_trigger_actions(Vector2.ZERO)
			queue_redraw()
			
	elif event is InputEventScreenDrag and dragging and event.index == touch_idx:
		_update_stick(event.position)

func _update_stick(pos: Vector2):
	var local = pos - global_position
	var diff = local - center
	if diff.length() > radius:
		diff = diff.normalized() * radius
	stick_pos = diff
	
	var n = diff / radius
	_trigger_actions(n)
	queue_redraw()

func _trigger_actions(v: Vector2):
	var threshold = 0.2
	_apply_action("move_right", v.x > threshold, v.x)
	_apply_action("move_left", v.x < -threshold, -v.x)
	_apply_action("move_down", v.y > threshold, v.y)
	_apply_action("move_up", v.y < -threshold, -v.y)

func _apply_action(action: String, pressed: bool, strength: float):
	if pressed:
		Input.action_press(action, strength)
	else:
		Input.action_release(action)

func _draw():
	draw_circle(center, radius, Color(1, 1, 1, 0.2))
	draw_circle(center + stick_pos, radius * 0.5, Color(1, 1, 1, 0.5))
