extends MarginContainer

func _ready():
	var track_verbose: SettingsCBoxEntry = find_child("TrackVerbose")
	if track_verbose:
		track_verbose.cbox.toggled.connect(func(state: bool):
			Archipelago.config.verbose_trackerpack = state)
		track_verbose.cbox.button_pressed = Archipelago.config.verbose_trackerpack
