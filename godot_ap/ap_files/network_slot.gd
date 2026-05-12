class_name NetworkSlot
## Information about a slot in the multiworld.
##
## @tutorial(Archipelago Documentation): https://github.com/ArchipelagoMW/Archipelago/blob/main/docs/network%20protocol.md#networkslot

## The name of the slot.
var name : String
## The game played on the slot.
var game: String
## The type of the slot. [code]0x00[/code] if the slot is for a spectator, [code]0x01[/code] if it's
## for a player, and [code]0x02[/code] if it's for a group.
var type: int
## If the slot is for a group, the IDs of the players in the group.
var group_members: Array[int] = []


## Create a slot from a [Dictionary].
static func from(json: Dictionary) -> NetworkSlot:
	if json["class"] != "NetworkSlot":
		return null
	var v := NetworkSlot.new()
	v.name = json["name"]
	v.game = json["game"]
	v.type = json["type"]
	v.group_members.assign(json["group_members"])
	return v


func _to_string():
	return "SLOT(%s[%s],type %d,members %s)" % [name, game, type, group_members]
