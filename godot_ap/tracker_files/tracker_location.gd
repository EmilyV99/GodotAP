class_name TrackerLocation

var id: int
var name: String
var status: NetworkHint.Status

static func make(locid: int) -> TrackerLocation:
	var ret := TrackerLocation.new()
	ret.id = locid
	ret.name = Archipelago.conn.get_gamedata_for_player().get_loc_name(locid)
	ret.refresh()
	return ret
static func nil() -> TrackerLocation:
	var ret := TrackerLocation.new()
	ret.id = -9999
	ret.name = "INVALID"
	ret.status = NetworkHint.Status.UNSPECIFIED
	return ret

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
