extends MarginContainer

@onready var theme_dark: CheckBox = $Row/Col1/DarkTheme
@onready var theme_light: CheckBox = $Row/Col1/LightTheme

func _ready():
	theme_dark.toggled.connect(func(b): if b: set_program_theme("res://godot_ap/ui/themes/dark_theme.tres"))
	theme_light.toggled.connect(func(b): if b: set_program_theme("res://godot_ap/ui/themes/light_theme.tres"))

func set_program_theme(path: String) -> void:
	ProjectSettings.set_setting("gui/theme/custom", path)
	get_tree().root.theme = load(path)

