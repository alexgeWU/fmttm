extends CanvasLayer

func _ready():
	if not DisplayServer.is_touchscreen_available():
		hide()
		queue_free() # Remove from memory if not on mobile
