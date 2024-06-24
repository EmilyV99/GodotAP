class_name TrackerScene_Root extends MarginContainer

var labeltext := "No game-specific tracker found. Showing default tracker."
var labelttip := ""

func _init() -> void:
	add_theme_constant_override("margin_up", 0)
	add_theme_constant_override("margin_down", 0)
	add_theme_constant_override("margin_left", 0)
	add_theme_constant_override("margin_right", 0)
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	

func set_heading_label(label: BaseConsole.TextPart) -> void:
	if not is_node_ready():
		await ready
	label.text = labeltext
	label.tooltip = labelttip
