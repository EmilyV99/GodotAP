class_name NetworkItem

var id: int
var loc_id: int
var src_player_id: int
var dest_player_id: int
var flags: int

func get_classification() -> String:
	return AP.get_item_classification(flags)
static func from(json: Dictionary, recv: bool) -> NetworkItem:
	if json["class"] != "NetworkItem":
		return null
	var v := NetworkItem.new()
	v.id = json["item"]
	v.loc_id = json["location"]
	v.src_player_id = json["player"] if recv else Archipelago.conn.player_id
	v.dest_player_id = Archipelago.conn.player_id if recv else json["player"]
	v.flags = json["flags"]
	return v
static func from_hint(json: Dictionary) -> NetworkItem:
	if json["class"] != "Hint":
		return null
	var v := NetworkItem.new()
	v.id = json["item"]
	v.loc_id = json["location"]
	v.src_player_id = json["finding_player"]
	v.dest_player_id = json["receiving_player"]
	v.flags = json["item_flags"]
	return v

func is_local() -> bool:
	return src_player_id == dest_player_id
func is_prog() -> bool:
	return flags & AP.ItemClassification.PROG

func get_name() -> String:
	return Archipelago.conn.get_gamedata_for_player(dest_player_id).get_item_name(id)
func _to_string():
	return "ITEM(%d at %d,player %d->%d,flags %d)" % [id,loc_id,src_player_id,dest_player_id,flags]
func output(console: BaseConsole, add := true) -> BaseConsole.TextPart:
	return Archipelago.out_item(console, id, flags, Archipelago.conn.get_gamedata_for_player(dest_player_id), add)
