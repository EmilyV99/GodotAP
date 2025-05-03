class_name CustomLabel extends Panel

@export var text: String = "":
	set(val):
		if val != text:
			text = val
			queue_redraw()
@export var font: Font
@export var font_size: int = 16
@export var pos = Vector2(0.0, 0.0)

func _draw():
	draw_string(font, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, get_theme_color("font_color", "Label"))
