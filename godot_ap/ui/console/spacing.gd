class_name Spacing extends Control

var parent: HFlowContainer
var hspace: float

func _init(_parent: HFlowContainer, _hspace: float):
	parent = _parent
	hspace = _hspace

func _ready():
	get_window().size_changed.connect(_on_window_size_changed)
	parent.resized.connect(_on_window_size_changed)

func _on_window_size_changed() -> void:
	if position.x == 0.0 or position.x + hspace >= get_parent().size.x:
		custom_minimum_size.x = 0.0
	else:
		custom_minimum_size.x = hspace
