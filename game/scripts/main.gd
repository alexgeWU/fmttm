extends Node

## Master State Controller: Menu -> Hub (Jazz Lounge) -> Run -> Gacha -> Hub ...
## Handles fade transitions and the global 2D glow (bloom) environment.

const MenuScript = preload("res://scripts/menu.gd")
const HubScript = preload("res://scripts/hub.gd")
const CombatScript = preload("res://scripts/combat_room.gd")
const GachaScript = preload("res://scripts/gacha.gd")
const IntroScript = preload("res://scripts/intro.gd")
const EndingScript = preload("res://scripts/ending.gd")

var current: Node = null
var fade_layer: CanvasLayer
var fade_rect: ColorRect
var busy: bool = false
var _queued: Array = []

func _ready():
	process_mode = Node.PROCESS_MODE_ALWAYS
	_setup_env()
	fade_layer = CanvasLayer.new()
	fade_layer.layer = 200
	add_child(fade_layer)
	fade_rect = ColorRect.new()
	fade_rect.color = Color(0, 0, 0, 1)
	fade_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fade_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	fade_layer.add_child(fade_rect)
	_install(_make_menu())
	var tw = create_tween()
	tw.tween_property(fade_rect, "color:a", 0.0, 0.8)

func _setup_env():
	var we = WorldEnvironment.new()
	var env = Environment.new()
	env.background_mode = Environment.BG_CANVAS
	env.glow_enabled = true
	env.glow_intensity = 0.85
	env.glow_strength = 1.0
	env.glow_bloom = 0.02
	env.glow_hdr_threshold = 1.0
	env.glow_blend_mode = Environment.GLOW_BLEND_MODE_ADDITIVE
	we.environment = env
	add_child(we)

func go(builder: Callable, fade_time: float = 0.4):
	if busy:
		_queued = [builder, fade_time]
		return
	busy = true
	var tw = create_tween()
	tw.tween_property(fade_rect, "color:a", 1.0, fade_time)
	tw.tween_callback(func():
		get_tree().paused = false
		GameData.reset_time()
		_install(builder.call())
	)
	tw.tween_property(fade_rect, "color:a", 0.0, fade_time)
	tw.tween_callback(func():
		busy = false
		if not _queued.is_empty():
			var q = _queued
			_queued = []
			go(q[0], q[1])
	)

func _install(scene: Node):
	if current and is_instance_valid(current):
		current.queue_free()
	current = scene
	current.process_mode = Node.PROCESS_MODE_PAUSABLE
	add_child(current)

func _make_menu() -> Node:
	var m = MenuScript.new()
	m.start_game.connect(func():
		if GameData.tut.get("intro", false):
			go(_make_hub)
		else:
			go(_make_intro)
	)
	m.play_intro.connect(func(): go(_make_intro))
	m.play_ending.connect(func(): go(_make_ending_replay))
	return m

func _make_intro() -> Node:
	var i = IntroScript.new()
	i.finished.connect(func(): go(_make_hub, 0.6))
	return i

func _make_hub() -> Node:
	var h = HubScript.new()
	h.go_combat.connect(func(): go(_make_combat, 0.6))
	h.go_gacha.connect(func(): go(_make_gacha))
	h.go_menu.connect(func(): go(_make_menu))
	return h

func _make_combat() -> Node:
	var c = CombatScript.new()
	c.run_over.connect(func(won):
		if won:
			go(_make_ending, 1.0)
		else:
			go(_make_gacha, 0.8)
	)
	return c

func _make_ending() -> Node:
	var e = EndingScript.new()
	e.finished.connect(func(): go(_make_gacha, 0.8))
	return e

func _make_ending_replay() -> Node:
	var e = EndingScript.new()
	e.replay = true
	e.finished.connect(func(): go(_make_menu, 0.8))
	return e

func _make_gacha() -> Node:
	var g = GachaScript.new()
	g.return_to_hub.connect(func(): go(_make_hub))
	return g
