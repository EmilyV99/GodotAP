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
	default_access = true
	TrackerTab.load_tracker_locations([])
	TrackerTab.load_named_rules({})
	
	if not tracking:
		infolabel.text = "Tracking Disabled"
		return
	if Archipelago.is_not_connected():
		infolabel.text = "Not Connected"
		return
	infolabel.text = "Loading"
	var game := Archipelago.conn.get_game_for_player()
	var pack := TrackerTab.get_tracker(game)
	tracker = pack.instantiate()
	tracker.size_flags_vertical = Control.SIZE_EXPAND_FILL
	tracker.link_to_label(infolabel)
	column.add_child(tracker)

static var default_access := true

static var trackers: Dictionary = {}
static func get_tracker(game: String) -> TrackerPack_Base:
	return trackers.get(game, trackers.get(""))

static var named_rules: Dictionary = {}
static var locations: Dictionary = {}
static var locs_by_name: Dictionary = {}

static func get_location(locid: int) -> APLocation:
	return locations.get(locid, APLocation.nil())
static func get_loc_by_name(loc_name: String) -> APLocation:
	return locs_by_name.get(loc_name, APLocation.nil())
static func get_named_rule(rule_name: String) -> TrackerLogicNode:
	return named_rules.get(rule_name)
static func load_locations() -> void:
	locations.clear()
	locs_by_name.clear()
	if Archipelago.datapack_pending:
		await Archipelago.all_datapacks_loaded
	for locid in Archipelago.location_list():
		var loc := APLocation.make(locid)
		locations[locid] = loc
		locs_by_name[loc.name] = loc
static func load_tracker_locations(locs: Array[TrackerLocation]) -> void:
	for id in locations:
		var loc := get_location(id)
		if loc:
			loc.reset_tracker_loc()
	for loc in locs:
		loc.get_loc().loaded_tracker_loc = loc
static func load_named_rules(rules: Dictionary) -> void:
	named_rules = rules
static func _static_init():
	# Set up default pack
	var def_pack: TrackerPack_Scene = TrackerPack_Scene.new()
	var scene: PackedScene = load("res://godot_ap/tracker_files/default_tracker.tscn")
	def_pack.scene = scene
	trackers[""] = def_pack
	var dir := DirAccess.open("tracker_packs/")
	if not dir:
		dir = DirAccess.open("./")
		if dir:
			if dir.make_dir("tracker_packs/"):
				dir = null
			else:
				dir = DirAccess.open("tracker_packs/")
	
	if dir:
		var file_names: Array[String] = []
		file_names.assign(dir.get_files())
		file_names.assign(file_names.map(func(s: String): return "tracker_packs/%s" % s))
		
		for fname in file_names:
			var pack := TrackerPack_Base.load_from(fname)
			if pack and not pack.game.is_empty():
				pack.saved_path = fname
				trackers[pack.game] = pack
	trackers.get("An Untitled Story").resave()
	
	# Set up location hook
	Archipelago.connected.connect(func(_conn,_json): load_locations())
