class_name ThemeBox extends CheckBox

signal set_theme(path: String)
@export var target_theme_path: String

func _ready() -> void:
	toggled.connect(_on_toggle)

func _on_toggle(b: bool) -> void:
	if b:
		set_theme.emit(target_theme_path)
