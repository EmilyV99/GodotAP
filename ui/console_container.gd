@tool class_name ConsoleContainer extends MarginContainer

@onready var tabs: TabContainer = $Tabs
@onready var console_tab: ConsoleTab = $Tabs/Console
@onready var hints_tab: HintsTab = $Tabs/Hints
@onready var console: BaseConsole = console_tab.console
@onready var typing_bar: TypingBar = console_tab.typing_bar

@export var hide_console_tab := false :
	set(val):
		hide_console_tab = val
		refresh_hidden()
@export var hide_hints_tab := false :
	set(val):
		hide_hints_tab = val
		refresh_hidden()

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

func recount() -> int: ## Returns the number of visible tabs, and sets the tabbar's visibility.
	var count := 0
	for q in tabs.get_tab_count():
		if not tabs.is_tab_hidden(q):
			count += 1
	tabs.tabs_visible = count > 1
	return count

func refresh_hidden() -> void:
	if Engine.is_editor_hint(): return
	if not is_node_ready(): return
	tabs.set_tab_hidden(tabs.get_tab_idx_from_control(console_tab), hide_console_tab)
	tabs.set_tab_hidden(tabs.get_tab_idx_from_control(hints_tab), hide_hints_tab)
	while tabs.is_tab_hidden(tabs.get_tab_idx_from_control(tabs.get_current_tab_control())):
		tabs.select_next_available()
	recount()

func _ready() -> void:
	refresh_hidden()
	typing_bar.grab_focus()
	console_window.size_changed.connect(update_cont_size)
	update_cont_size()

func update_cont_size() -> void:
	position = Vector2.ZERO
	var sz := console_window.size
	custom_minimum_size = sz
	tabs.custom_minimum_size = sz
	reset_size()
	queue_sort()

func close() -> void:
	console_window.close_requested.emit()
	
