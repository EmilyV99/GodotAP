class_name NetworkPlayer
## A player in the multiworld.
##
## @tutorial(Archipelago Documentation): https://github.com/ArchipelagoMW/Archipelago/blob/main/docs/network%20protocol.md#networkplayer

## The id of the team that the player is on.
var team: int
## The player's slot number.
var slot: int
## The player's alias.
var alias := ""
## The player's name.
var name : String


## Get the slot information for this player.
func get_slot() -> NetworkSlot:
	return Archipelago.conn.get_slot(slot)


## Get the player's name. If [param use_alias] is true the player's alias will be returned instead,
## if present.
func get_name(use_alias := true) -> String:
	var ret := ""
	if use_alias:
		ret = alias
	if not ret:
		ret = name
	return ret


## Create a player from a [Dictionary].
static func from(json: Dictionary) -> NetworkPlayer:
	if json["class"] != "NetworkPlayer":
		return null
	var v := NetworkPlayer.new()
	v.team = json["team"]
	v.slot = json["slot"]
	v.name = json["name"]
	if json.has("alias"):
		v.alias = json["alias"]
		if v.alias == v.name:
			v.alias = ""
	return v


func _to_string():
	return "PLAYER(%s[%s],team %d,slot %d)" % [name,alias,team,slot]


## Create a label to display on a console.
func output() -> ConsoleLabel:
	return BaseConsole.make_player(slot)
