extends MarginContainer

func _ready():
	var track_verbose: SettingsCBoxEntry = find_child("TrackVerbose")
	if track_verbose:
		track_verbose.cbox.toggled.connect(func(state: bool):
			Archipelago.config.verbose_trackerpack = state)
		track_verbose.cbox.button_pressed = Archipelago.config.verbose_trackerpack
	var track_hide_completed_map: SettingsCBoxEntry = find_child("TrackHideFinishedMap")
	if track_hide_completed_map:
		track_hide_completed_map.cbox.toggled.connect(func(state: bool):
			Archipelago.config.hide_finished_map_squares = state)
		track_hide_completed_map.cbox.button_pressed = Archipelago.config.hide_finished_map_squares
