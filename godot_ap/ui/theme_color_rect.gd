@tool class_name ColorRect_Theme extends Control

func _draw() -> void:
	draw_rect(get_rect(), get_theme_color(&"bg_color"))
