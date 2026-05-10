class_name APLocation
## A multiworld location.

## The location's id.
var id: int

## The location's name.
var name: String

## Priority of the location as given by a hint.
var hint_status: NetworkHint.Status


## Static factory method.
static func make(locid: int) -> APLocation:
	var ret := APLocation.new()
	ret.id = locid
	ret.name = Archipelago.conn.get_gamedata_for_player().get_loc_name(locid)
	return ret


## Create empty and invalid location.
static func nil() -> APLocation:
	var ret := APLocation.new()
	ret.id = -9999
	ret.name = "INVALID"
	ret.hint_status = NetworkHint.Status.UNSPECIFIED
	return ret


func _to_string() -> String:
	return "LOCATION(%d '%s',Hint '%s')" % [id, name, NetworkHint.status_names[hint_status]]
