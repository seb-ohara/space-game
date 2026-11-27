extends CanvasLayer

var fps_label: Label

func _ready() -> void:
	layer = 100
	process_mode = Node.PROCESS_MODE_ALWAYS
	fps_label = Label.new()
	fps_label.position = Vector2(30, 2)
	fps_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fps_label.add_theme_font_size_override("font_size", 14)
	fps_label.add_theme_color_override("font_color", Color("d9f0fb"))
	add_child(fps_label)
	_update_fps()

func _process(_delta: float) -> void:
	_update_fps()

func _update_fps() -> void:
	fps_label.text = "FPS  %d" % Engine.get_frames_per_second()
