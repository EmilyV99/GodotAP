class_name APLocation

var id: int
var name: String
var status: NetworkHint.Status

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
	ret.status = NetworkHint.Status.UNSPECIFIED
	ret.loaded_tracker_loc = TrackerLocation.new()
	return ret
func reset_tracker_loc() -> void:
	if id == -9999:
		loaded_tracker_loc = TrackerLocation.new()
	else: loaded_tracker_loc = TrackerLocation.make_id(id)

func refresh() -> void:
	var s := NetworkHint.Status.NOT_FOUND
	if Archipelago.location_checked(id):
		s = NetworkHint.Status.FOUND
	else:
		for hint in Archipelago.conn.hints:
			if hint.item.src_player_id == Archipelago.conn.player_id and \
				hint.item.loc_id == id:
				if hint.status == NetworkHint.Status.NOT_FOUND and \
					hint.item.flags & Archipelago.ICLASS_TRAP:
					s = NetworkHint.Status.AVOID
				else: s = hint.status
				break
	status = s

## Returns true if the location is accessible
func can_access() -> bool:
	if loaded_tracker_loc:
		return loaded_tracker_loc.can_access()
	return TrackerTab.default_access
