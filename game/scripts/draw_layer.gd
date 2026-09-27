extends Node2D

## A tiny helper: a Node2D that redraws every frame by calling `draw_func(self)`.
var draw_func: Callable

func _process(_delta):
	queue_redraw()

func _draw():
	if draw_func.is_valid():
		draw_func.call(self)
