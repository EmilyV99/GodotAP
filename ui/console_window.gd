@tool class_name ConsoleWindow extends Window

@onready var cont: MarginContainer = $Cont
@onready var tabs: TabContainer = $Cont/Tabs
@onready var console: BaseConsole = $Cont/Tabs/Console/ConsoleMargin/Console
@onready var console_tab: VBoxContainer = $Cont/Tabs/Console
@onready var typing_bar: TypingBar = console_tab.typing_bar
# Called when the node enters the scene tree for the first time.
func _ready():
	if Engine.is_editor_hint():
		position = Vector2i.ZERO
	tabs.tabs_visible = tabs.get_child_count() > 1
	typing_bar.grab_focus()
	size_changed.connect(update_cont_size)
	update_cont_size()

func update_cont_size():
	cont.custom_minimum_size = size
	cont.reset_size()
	cont.queue_sort()

func _on_close_requested():
	queue_free()
