class_name APLocation

var id: int
var name: String
var hint_status: NetworkHint.Status

static func make(locid: int) -> APLocation:
	var ret := APLocation.new()
	ret.id = locid
	ret.name = Archipelago.conn.get_gamedata_for_player().get_loc_name(locid)
	ret.refresh()
	return ret
static func nil() -> APLocation:
	var ret := APLocation.new()
	ret.id = -9999
	ret.name = "INVALID"
	ret.hint_status = NetworkHint.Status.UNSPECIFIED
	return ret
