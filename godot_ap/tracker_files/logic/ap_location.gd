class_name APLocation

var id: int
var name: String
var hint_status: NetworkHint.Status

var loaded_tracker_loc: TrackerLocation

static func make(locid: int) -> APLocation:
	var ret := APLocation.new()
	ret.id = locid
	ret.name = Archipelago.conn.get_gamedata_for_player().get_loc_name(locid)
	ret.loaded_tracker_loc = TrackerLocation.make_id(locid)
	ret.refresh()
	return ret
static func nil() -> APLocation:
	var ret := APLocation.new()
	ret.id = -9999
	ret.name = "INVALID"
	ret.hint_status = NetworkHint.Status.UNSPECIFIED
	ret.loaded_tracker_loc = TrackerLocation.new()
	return ret
func reset_tracker_loc() -> void:
	if id == -9999:
		loaded_tracker_loc = TrackerLocation.new()
	else: loaded_tracker_loc = TrackerLocation.make_id(id)

func refresh() -> void:
	var s := NetworkHint.Status.UNSPECIFIED
	if Archipelago.location_checked(id):
		s = NetworkHint.Status.FOUND
	else:
		for hint in Archipelago.conn.hints:
			if hint.item.src_player_id == Archipelago.conn.player_id and \
				hint.item.loc_id == id:
				if hint.status == NetworkHint.Status.NOT_FOUND and \
					hint.item.flags & Archipelago.ItemClassification.TRAP:
					s = NetworkHint.Status.AVOID
				else: s = hint.status
				break
	hint_status = s

## Returns the location's accessibility as a string
func get_status(default := "Unknown") -> String:
	if loaded_tracker_loc and TrackerManager.tracking:
		return loaded_tracker_loc.get_status()
	return default

## Returns a descriptive display name, or an empty string if none exists.
func get_display_name() -> String:
	if loaded_tracker_loc:
		return loaded_tracker_loc.descriptive_name
	return ""
