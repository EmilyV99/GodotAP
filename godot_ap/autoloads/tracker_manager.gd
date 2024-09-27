extends Node
# Autoload 'TrackerManager'

signal tracking_reloaded

var do_update_tags := true
var tracking: bool = false :
	set(val):
		tracking = val
		if not do_update_tags: return
		if Archipelago.config:
			Archipelago.config.is_tracking = val
		Archipelago.set_tag("Tracker", val)

var trackers: Dictionary = {}
func get_tracker(game: String) -> TrackerPack_Base:
	var ret = trackers.get(game)
	if not ret: ret = trackers.get("")
	assert(ret)
	return ret

var named_rules: Dictionary = {}
var named_values: Dictionary = {}
var statuses: Array[LocationStatus] = [LocationStatus.ACCESS_FOUND,
	LocationStatus.ACCESS_UNKNOWN, LocationStatus.ACCESS_UNREACHABLE,
	LocationStatus.ACCESS_NOT_FOUND, LocationStatus.ACCESS_LOGIC_BREAK,
	LocationStatus.ACCESS_REACHABLE]
var locations: Dictionary = {}
var locs_by_name: Dictionary = {}
var variables: Dictionary = {}

signal locations_loaded
signal tracker_locations_loaded
var is_loaded := false
func on_tracker_load() -> bool:
	if not is_loaded:
		await tracker_locations_loaded
	return true

func get_location(locid: int) -> APLocation:
	return locations.get(locid, APLocation.nil())
func get_loc_by_name(loc_name: String) -> APLocation:
	return locs_by_name.get(loc_name, APLocation.nil())
func get_named_rule(rule_name: String) -> TrackerLogicNode:
	return named_rules.get(rule_name)
func get_named_value(val_name: String) -> TrackerValueNode:
	return named_values.get(val_name)
func get_variable(var_name: String) -> int:
	var val: int = variables.get(var_name, 0)
	return val
func get_status(status_name: String) -> LocationStatus:
	for s in statuses:
		if s.text == status_name:
			return s
	return null
func load_locations() -> void:
	locations.clear()
	locs_by_name.clear()
	is_loaded = false
	if Archipelago.datapack_pending:
		await Archipelago.all_datapacks_loaded
	for locid in Archipelago.location_list():
		var loc := APLocation.make(locid)
		locations[locid] = loc
		locs_by_name[loc.name] = loc
	locations_loaded.emit()
func load_tracker_locations(locs: Array[TrackerLocation]) -> void:
	if locations.is_empty():
		await locations_loaded
	for id in locations:
		var loc := get_location(id)
		if loc:
			loc.reset_tracker_loc()
	for loc in locs:
		loc.get_loc().loaded_tracker_loc = loc
	is_loaded = true
	tracker_locations_loaded.emit()
func load_named_rules(rules: Dictionary) -> void:
	named_rules = rules.duplicate(true)
func load_named_values(values: Dictionary) -> void:
	named_values = values.duplicate(true)
func load_statuses(status_array: Array[LocationStatus]):
	statuses = status_array.duplicate(true)

func clear_tracker() -> void:
	for id in locations:
		var loc := get_location(id)
		if loc:
			loc.reset_tracker_loc()
	named_rules.clear()
	named_values.clear()
	variables.clear()
	is_loaded = false

func _ready():
	tracking = "Tracker" in Archipelago.AP_GAME_TAGS or Archipelago.config.is_tracking
	# Set up default pack
	var def_pack: TrackerPack_Scene = TrackerPack_Scene.new()
	var scene: PackedScene = load("res://godot_ap/tracker_files/default_tracker.tscn")
	def_pack.scene = scene
	trackers[""] = def_pack
	# Set up hook
	Archipelago.preconnect.connect(func():
		tracking = "Tracker" in Archipelago.AP_GAME_TAGS or Archipelago.config.is_tracking)
	Archipelago.connected.connect(func(_conn,_json):
		load_locations())
	if Archipelago.AP_ALLOW_TRACKERPACKS:
		if Archipelago.output_console:
			load_tracker_packs()
		else:
			Archipelago.on_attach_console.connect(load_tracker_packs, CONNECT_ONE_SHOT)

func load_tracker_packs() -> void:
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
	do_update_tags = false
	var was_tracking := tracking
	tracking = false
	var default_tracker = trackers.get("")
	trackers.clear()
	trackers[""] = default_tracker
	AP.log("Loading Tracker Packs...")

	var file_names: Array[String] = []
	file_names.assign(dir.get_files())
	file_names.assign(file_names.map(func(s: String): return "tracker_packs/%s" % s))

	var console: BaseConsole = Archipelago.output_console

	var failcount := 0
	var successcount := 0
	var games: Dictionary = {}
	var errors: Dictionary = {}
	var timer := Timer.new()
	add_child(timer)
	const TIMER_DELAY = 1.0 ## Seconds to process before giving control back for the rest of the frame
	for fname in file_names:
		if Util.poll_timer(timer, TIMER_DELAY):
			await get_tree().process_frame
		var tpack_verbose_part
		var tpack_newline_part
		if Archipelago.config.verbose_trackerpack:
			var txt := "Loading TrackerPack from '%s'..." % fname
			if Archipelago.output_console:
				tpack_verbose_part = Archipelago.output_console.add_text(txt, "", Archipelago.output_console.COLOR_UI_MSG)
				tpack_newline_part = Archipelago.output_console.add_ensure_newline()
			AP.log(txt)
		var pack := TrackerPack_Base.load_from(fname)
		if Archipelago.config.verbose_trackerpack:
			if TrackerPack_Base.load_error == "Unrecognized Extension":
				if tpack_verbose_part: tpack_verbose_part.hidden = true
				if tpack_newline_part: tpack_newline_part.hidden = true
			else:
				var txt: String= "%s loading TrackerPack '%s'" % ["Success" if pack else "Failure", fname]
				if Archipelago.output_console and tpack_verbose_part:
					tpack_verbose_part.text = txt
					tpack_verbose_part.color = AP.color_from_name("green" if pack else "red")
					tpack_verbose_part.tooltip = ("TrackerPack for '%s'" % pack.game) if pack else TrackerPack_Base.load_error
				AP.log(txt)
		if Util.poll_timer(timer, TIMER_DELAY):
			await get_tree().process_frame
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
				console.add_line(loadstatus, success_ttip.strip_edges(), AP.color_from_name("green" if not failcount else "orange"))
			if failcount:
				var err_ttip := ""
				var err_files: Array[String] = []
				err_files.assign(errors.keys())
				err_files.sort_custom(func(a, b): return a.naturalnocasecmp_to(b))
				for f in err_files:
					err_ttip += "%s: %s\n" % [f, errors[f]]
				console.add_line("Failed loading %d/%d TrackerPacks" % [failcount, failcount+successcount], err_ttip.strip_edges(), AP.color_from_name("red"))
	else:
		AP.log("No TrackerPacks Found")
		console.add_line("No TrackerPacks Found", "Add packs to `./tracker_packs/` and relaunch to load!", console.COLOR_UI_MSG)
	tracking = was_tracking
	do_update_tags = true
	tracking_reloaded.emit()
	timer.queue_free()

func sort_by_location_status(a: String, b: String) -> int:
	var ai = -1
	var bi = -1
	for q in statuses.size():
		if statuses[q].text == a:
			ai = q
		if statuses[q].text == b:
			bi = q
	return (ai - bi)
