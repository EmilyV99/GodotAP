extends MarginContainer

@export var themes: Array[ThemeBox]
@export var default_theme: ThemeBox

func _ready():
	for themebox in themes:
		themebox.set_theme.connect(set_console_theme)
		themebox.set_pressed_no_signal(themebox.target_theme_path == Archipelago.config.window_theme_path)
	if Archipelago.config.window_theme_path.is_empty():
		default_theme.set_pressed(true)
	else:
		refresh_console_theme()

func set_console_theme(path: String) -> void:
	if path.is_empty(): return
	var theme_res := load(path) as Theme
	if not theme_res: return
	get_window().theme = theme_res
	Archipelago.config.window_theme_path = path

func refresh_console_theme() -> void:
	set_console_theme(Archipelago.config.window_theme_path)
