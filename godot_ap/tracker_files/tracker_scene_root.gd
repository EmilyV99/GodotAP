class_name TrackerScene_Root extends MarginContainer

var labeltext := "No game-specific tracker found. Showing default tracker."
var labelttip := ""

signal item_register(name: String)

func _init() -> void:
	add_theme_constant_override("margin_up", 0)
	add_theme_constant_override("margin_down", 0)
	add_theme_constant_override("margin_left", 0)
	add_theme_constant_override("margin_right", 0)
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	size_flags_vertical = Control.SIZE_EXPAND_FILL

func _ready():
	for itm in Archipelago.conn.received_items:
		var iname = itm.get_name()
		item_register.emit(iname)

func _enter_tree():
	Archipelago.conn.obtained_item.connect(__register_item)
func _exit_tree():
	if Archipelago.conn:
		Archipelago.conn.obtained_item.disconnect(__register_item)

func __register_item(itm: NetworkItem):
	item_register.emit(itm.get_name())

func set_heading_label(label: BaseConsole.TextPart) -> void:
	if not is_node_ready():
		await ready
	label.text = labeltext
	label.tooltip = labelttip
