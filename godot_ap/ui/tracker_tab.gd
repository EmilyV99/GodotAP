class_name TrackerTab extends MarginContainer

@onready var tracker_button: CheckButton = $Column/Margins/Row/TrackingButton
@onready var refr_button: TextureButton = $Column/Margins/Row/Reload
@onready var info_console: BaseConsole = $Column/Margins/Row/InfoLabel
@onready var column: VBoxContainer = $Column

var tracker: TrackerScene_Root = null
var info_part: BaseConsole.TextPart = null

func refr_tags():
	tracker_button.set_pressed_no_signal(Archipelago.tracker_manager.tracking)
	init_tracker()

func _ready():
	if not Archipelago.AP_ALLOW_TRACKERPACKS:
		queue_free()
		return
	info_part = info_console.add_c_text("")
	Archipelago.on_tag_change.connect(refr_tags)
	Archipelago.tracker_manager.tracking_reloaded.connect(refr_tags)
	Archipelago.connected.connect(func(_conn, _json): refr_tags())
	Archipelago.disconnected.connect(refr_tags)
	tracker_button.toggled.connect(func(state):
		Archipelago.tracker_manager.tracking = state
		Archipelago.set_tag("Tracker", state))
	refr_button.pressed.connect(func():
		Archipelago.cmd_manager.call_cmd("/tracker refresh"))
	refr_tags()

func init_tracker():
	if tracker:
		tracker.visible = false
		tracker.queue_free()
		await tracker.tree_exited
		await get_tree().process_frame
		tracker = null
	Archipelago.tracker_manager.clear_tracker()

	if not Archipelago.tracker_manager.tracking:
		info_part.text = "Tracking Disabled"
		info_part.tooltip = ""
		info_console.queue_redraw()
		return
	if Archipelago.is_not_connected():
		info_part.text = "Not Connected"
		info_part.tooltip = ""
		info_console.queue_redraw()
		return
	info_part.text = "Loading"
	info_part.tooltip = ""
	info_console.queue_redraw()
	var game := Archipelago.conn.get_game_for_player()
	var pack: TrackerPack_Base = Archipelago.tracker_manager.get_tracker(game)
	tracker = pack.instantiate()
	tracker.size_flags_vertical = Control.SIZE_EXPAND_FILL
	tracker.set_heading_label(info_part)
	column.add_child(tracker)
