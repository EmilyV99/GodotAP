class_name ConsoleContainer extends MarginContainer

@onready var tabs: TabContainer = $Tabs
@onready var console: BaseConsole = $Tabs/Console/ConsoleMargin/Console
@onready var console_tab: ConsoleTab = $Tabs/Console
@onready var typing_bar: TypingBar = console_tab.typing_bar


var console_window: Window :
	get = get_console_window

## Returns the window containing the console
func get_console_window() -> Window:
	if console_window: return console_window
	var p = get_parent()
	while not p is Window:
		p = p.get_parent()
	console_window = p
	return p

func _ready() -> void:
	tabs.tabs_visible = tabs.get_child_count() > 1
	typing_bar.grab_focus()
	console_window.size_changed.connect(update_cont_size)
	update_cont_size()

func update_cont_size() -> void:
	position = Vector2.ZERO
	custom_minimum_size = console_window.size
	reset_size()
	queue_sort()

func close() -> void:
	console_window.close_requested.emit()
	
