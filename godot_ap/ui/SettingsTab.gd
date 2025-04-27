extends MarginContainer

@export_group("Nodes")
@export_subgroup("Tracker")
@export var tracker_tab: Container
@export var track_verbose: CheckBox
@export var track_hide_completed_map: CheckBox


func _ready():
	if Archipelago.AP_ALLOW_TRACKERPACKS:
		if track_verbose:
			track_verbose.toggled.connect(func(state: bool):
				Archipelago.config.verbose_trackerpack = state)
			track_verbose.button_pressed = Archipelago.config.verbose_trackerpack
		if track_hide_completed_map:
			track_hide_completed_map.toggled.connect(func(state: bool):
				Archipelago.config.hide_finished_map_squares = state)
			track_hide_completed_map.button_pressed = Archipelago.config.hide_finished_map_squares
	else:
		tracker_tab.queue_free()
