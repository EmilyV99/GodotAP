class_name TrackerTab extends MarginContainer

@onready var tracker_button: CheckButton = $Column/Margins/Row/TrackingButton
@onready var infolabel: Label = $Column/Margins/Row/InfoLabel
@onready var column: VBoxContainer = $Column

var tracker: TrackerScene_Base = null

var tracking: bool = false

func refr_tags():
	tracking = "Tracker" in Archipelago.AP_GAME_TAGS
	tracker_button.set_pressed_no_signal(tracking)
	init_tracker()
		
func _ready():
	Archipelago.on_tag_change.connect(refr_tags)
	Archipelago.connected.connect(func(_conn, _json): refr_tags())
	Archipelago.disconnected.connect(refr_tags)
	tracker_button.toggled.connect(func(state):
		tracking = state
		Archipelago.set_tag("Tracker", state))
	refr_tags()

func init_tracker():
	if tracker:
		tracker.queue_free()
		tracker = null
	if not tracking:
		infolabel.text = "Tracking Disabled"
		return
	if Archipelago.is_not_connected():
		infolabel.text = "Not Connected"
		return
	infolabel.text = "Loading"
	var pack := TrackerTab.get_tracker(Archipelago.conn.get_game_for_player())
	tracker = pack.instantiate()
	tracker.size_flags_vertical = Control.SIZE_EXPAND_FILL
	tracker.link_to_label(infolabel)
	column.add_child(tracker)

static var trackers: Dictionary = {}
static func get_tracker(game: String) -> TrackerPack_Base:
	return trackers.get(game, trackers.get(""))

static var locations: Dictionary = {}

static func get_location(locid: int) -> TrackerLocation:
	return locations.get(locid, TrackerLocation.nil())
static func load_locations() -> void:
	locations.clear()
	if Archipelago.datapack_pending:
		await Archipelago.all_datapacks_loaded
	for loc in Archipelago.location_list():
		locations[loc] = TrackerLocation.make(loc)
static func _static_init():
	# Set up default pack
	var def_pack: TrackerPack_Scene = TrackerPack_Scene.new()
	var scene: PackedScene = load("res://godot_ap/tracker_files/default_tracker.tscn")
	def_pack.scene = scene
	trackers[""] = def_pack
	
	# Set up location hook
	Archipelago.connected.connect(func(_conn,_json): load_locations())
