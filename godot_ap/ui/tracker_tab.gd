class_name TrackerTab extends MarginContainer

@onready var tracker_button: CheckButton = $Column/Margins/Row/TrackingButton
@onready var info_console: BaseConsole = $Column/Margins/Row/InfoLabel
@onready var column: VBoxContainer = $Column

var tracker: TrackerScene_Base = null
var info_part: BaseConsole.TextPart = null

static var tracking: bool = false :
	set(val):
		if Archipelago.config:
			Archipelago.config.is_tracking = val
		tracking = val
		Archipelago.set_tag("Tracker", val)

func refr_tags():
	TrackerTab.tracking = "Tracker" in Archipelago.AP_GAME_TAGS or Archipelago.config.is_tracking
	tracker_button.set_pressed_no_signal(TrackerTab.tracking)
	init_tracker()
		
func _ready():
	TrackerTab.initialize_stuff()
	info_part = info_console.add_c_text("")
	Archipelago.on_tag_change.connect(refr_tags)
	Archipelago.connected.connect(func(_conn, _json): refr_tags())
	Archipelago.disconnected.connect(refr_tags)
	tracker_button.toggled.connect(func(state):
		TrackerTab.tracking = state
		Archipelago.set_tag("Tracker", state))
	refr_tags()

func init_tracker():
	if tracker:
		tracker.queue_free()
		tracker = null
	TrackerTab.load_tracker_locations([])
	TrackerTab.load_named_rules({})
	
	if not TrackerTab.tracking:
		info_part.text = "Tracking Disabled"
		info_console.queue_redraw()
		return
	if Archipelago.is_not_connected():
		info_part.text = "Not Connected"
		info_console.queue_redraw()
		return
	info_part.text = "Loading"
	info_console.queue_redraw()
	var game := Archipelago.conn.get_game_for_player()
	var pack := TrackerTab.get_tracker(game)
	tracker = pack.instantiate()
	tracker.size_flags_vertical = Control.SIZE_EXPAND_FILL
	tracker.link_to_label(info_part)
	column.add_child(tracker)

static var trackers: Dictionary = {}
static func get_tracker(game: String) -> TrackerPack_Base:
	return trackers.get(game, trackers.get(""))

static var named_rules: Dictionary = {}
static var statuses: Array[LocationStatus] = [LocationStatus.ACCESS_FOUND,
	LocationStatus.ACCESS_UNKNOWN, LocationStatus.ACCESS_UNREACHABLE,
	LocationStatus.ACCESS_NOT_FOUND, LocationStatus.ACCESS_LOGIC_BREAK,
	LocationStatus.ACCESS_REACHABLE]
static var locations: Dictionary = {}
static var locs_by_name: Dictionary = {}
static var variables: Dictionary = {}

static func get_location(locid: int) -> APLocation:
	return locations.get(locid, APLocation.nil())
static func get_loc_by_name(loc_name: String) -> APLocation:
	return locs_by_name.get(loc_name, APLocation.nil())
static func get_named_rule(rule_name: String) -> TrackerLogicNode:
	return named_rules.get(rule_name)
static func get_status(status_name: String) -> LocationStatus:
	for s in statuses:
		if s.text == status_name:
			return s
	return null
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
static func load_statuses(status_array: Array[LocationStatus]):
	statuses = status_array
static var did_init := false
static func initialize_stuff():
	if did_init: return
	if not Archipelago: return
	did_init = true
	# Set up default pack
	var def_pack: TrackerPack_Scene = TrackerPack_Scene.new()
	var scene: PackedScene = load("res://godot_ap/tracker_files/default_tracker.tscn")
	def_pack.scene = scene
	trackers[""] = def_pack
	
	# Set up hook
	Archipelago.connected.connect(func(_conn,_json): load_locations())
	if Archipelago.AP_ALLOW_TRACKERPACKS:
		if Archipelago.output_console:
			load_tracker_packs()
		else:
			Archipelago.on_attach_console.connect(load_tracker_packs, CONNECT_ONE_SHOT)

static func load_tracker_packs() -> void:
	var dir := DirAccess.open("tracker_packs/")
	if not dir:
		dir = DirAccess.open("./")
		if dir:
			if dir.make_dir("tracker_packs/"):
				dir = null
			else:
				dir = DirAccess.open("tracker_packs/")
	
	if not dir: 
		AP.log("Failed to load or make `./tracker_packs/` directory!")
		return
	var was_tracking := tracking
	tracking = false
	trackers.clear()
	AP.log("Loading Tracker Packs...")
	
	var file_names: Array[String] = []
	file_names.assign(dir.get_files())
	file_names.assign(file_names.map(func(s: String): return "tracker_packs/%s" % s))
	
	var console: BaseConsole = Archipelago.output_console
	
	var failcount := 0
	var successcount := 0
	var games: Dictionary = {}
	var errors: Dictionary = {}
	for fname in file_names:
		var tpack_verbose_part
		if Archipelago.config.verbose_trackerpack:
			var txt := "Loading TrackerPack from '%s'..." % fname
			if Archipelago.output_console:
				tpack_verbose_part = Archipelago.output_console.add_text(txt, "", Archipelago.output_console.COLOR_UI_MSG)
				Archipelago.output_console.add_ensure_newline()
			AP.log(txt)
		var pack := TrackerPack_Base.load_from(fname)
		if Archipelago.config.verbose_trackerpack:
			var txt: String= "%s loading TrackerPack '%s'" % ["Success" if pack else "Failure", fname]
			if Archipelago.output_console and tpack_verbose_part:
				tpack_verbose_part.text = txt
				tpack_verbose_part.color = Archipelago.rich_colors["green" if pack else "red"]
				tpack_verbose_part.tooltip = ("TrackerPack for '%s'" % pack.game) if pack else TrackerPack_Base.load_error
			AP.log(txt)
		match TrackerPack_Base.load_error:
			"": # Valid
				pass
			"Unrecognized Extension": # Bad filetype, skip
				continue
			var err: # Print out any other error
				failcount += 1
				AP.log("TrackerPack error: %s" % err)
				errors[fname] = err
				continue
		if pack and not pack.game.is_empty():
			successcount += 1
			pack.saved_path = fname
			trackers[pack.game] = pack
			games[pack.game] = fname
		else:
			failcount += 1
	if failcount+successcount:
		var loadstatus := "Loaded %d/%d Tracker Packs successfully!" % [successcount, failcount+successcount]
		AP.log(loadstatus)
		if console:
			if successcount:
				var success_games: Array[String] = []
				success_games.assign(games.keys())
				success_games.sort_custom(func(a, b): return a.naturalnocasecmp_to(b))
				var success_ttip: String = ""
				for g in success_games:
					success_ttip += "%s: %s\n" % [g, games[g]]
				console.add_line(loadstatus, success_ttip.strip_edges(), Archipelago.rich_colors["green" if not failcount else "orange"])
			if failcount:
				var err_ttip := ""
				var err_files: Array[String] = []
				err_files.assign(errors.keys())
				err_files.sort_custom(func(a, b): return a.naturalnocasecmp_to(b))
				for f in err_files:
					err_ttip += "%s: %s\n" % [f, errors[f]]
				console.add_line("Failed loading %d/%d TrackerPacks" % [failcount, failcount+successcount], err_ttip.strip_edges(), Archipelago.rich_colors["red"])
	else:
		AP.log("No TrackerPacks Found")
		console.add_line("No TrackerPacks Found", "Add packs to `./tracker_packs/` and relaunch to load!", console.COLOR_UI_MSG)
	tracking = was_tracking

static func sort_by_location_status(a: String, b: String) -> int:
	var ai = -1
	var bi = -1
	for q in statuses.size():
		if statuses[q].text == a:
			ai = q
		if statuses[q].text == b:
			bi = q
	return (ai - bi)
