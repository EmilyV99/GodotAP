@tool class_name ConsoleWindowContainer extends PanelContainer

@onready var tabs: TabContainer = $Tabs
@onready var console_tab: Control = $Tabs/Console
@onready var hints_tab: Control = $Tabs/Hints
@onready var console_margin: MarginContainer = $Tabs/Console/Console/Cont/ConsoleMargin
@onready var console_container: ConsoleContainer = $Tabs/Console/Console
@onready var console: BaseConsole = console_container.console
@onready var typing_bar: TypingBar = console_container.typing_bar

@export var hide_console_tab := false :
	set(val):
		hide_console_tab = val
		refresh_hidden()
@export var hide_hints_tab := false :
	set(val):
		hide_hints_tab = val
		refresh_hidden()

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
	get_window().size_changed.connect(update_cont_size)
	get_viewport().gui_embed_subwindows = true
	update_cont_size()

	if Engine.is_editor_hint(): return

	var right_bar_ws: Array[float] = []
	var register_bar_w: Callable = func(n):
			if n is SliderBox:
				right_bar_ws.push_back(n.get_closed_width())
	for node in console_tab.get_children():
		if node == console_margin: continue
		register_bar_w.call(node)
		Util.for_all_nodes(node, register_bar_w)
	var right_bar_w := 0.0
	for w in right_bar_ws:
		if w > right_bar_w:
			right_bar_w = w
	console_margin.add_theme_constant_override("margin_right", 8+ceili(right_bar_w))

func update_cont_size() -> void:
	position = Vector2.ZERO
	var win := get_window()
	if win:
		custom_minimum_size = win.size
		tabs.custom_minimum_size = win.size
	reset_size()
	queue_sort()

func close() -> void:
	get_window().close_requested.emit()
