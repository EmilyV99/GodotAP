class_name NetworkItem
## A multiworld item.
##
## @tutorial(Archipelago Documentation): https://github.com/ArchipelagoMW/Archipelago/blob/main/docs/network%20protocol.md#networkitem

## The item's ID.
var id: int
## The ID of this item's location.
var loc_id: int
## The ID of the player whose world this item is in.
var src_player_id: int
## The ID of the player who will receive this item.
var dest_player_id: int
## Combination of bit flags with information about the item. See [enum AP.ItemClassification] for
## more information.
var flags: int


## Get a text description of this item's [member flags].
func get_classification() -> String:
	return AP.get_item_classification(flags)


## Deserialize item information. If [param recv] is [code]true[/code], the 
## information is interpreted as an item found in another world. Otherwise the item is
## assumed to be found in the client's world.
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


## Deserialize item information from a [Dictionary] describing a hint.
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


## Returns [code]true[/code] if this item is found in it's player's own world. Returns
## [code]false[/code] if it's found in another player's world.
func is_local() -> bool:
	return src_player_id == dest_player_id


## Returns [code]true[/code] if the item is a progression item. Returns [code]false[/code] if it
## isn't.
func is_prog() -> bool:
	return flags & AP.ItemClassification.PROG


## Get the name of the item.
func get_name() -> String:
	return Archipelago.conn.get_gamedata_for_player(dest_player_id).get_item_name(id)


func _to_string():
	return "ITEM(%d at %d,player %d->%d,flags %d)" % [
		id,
		loc_id,
		src_player_id,
		dest_player_id,
		flags
	]


## Create a label describing this item for outputting to a console.
func output() -> ConsoleLabel:
	return BaseConsole.make_item(id, flags,
			Archipelago.conn.get_gamedata_for_player(dest_player_id))
