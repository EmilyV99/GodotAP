class_name ThemeBox extends CheckBox

signal set_theme(path: String)
@export var target_theme_path: String:
	get():
		target_theme_path = target_theme_path.replace("res://godot_ap", AP.get_folder_base())
		return target_theme_path

func _ready() -> void:
	toggled.connect(_on_toggle)

func _on_toggle(b: bool) -> void:
	if b:
		set_theme.emit(target_theme_path)
