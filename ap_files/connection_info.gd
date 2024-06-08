class_name ConnectionInfo

var serv_version: Version
var gen_version: Version
var seed_name: String
var recieved_index: int = -1
var uid: int
var death_alias: String = ""

var player_id: int
var team_id: int
var slot_data: Dictionary

var players: Array[NetworkPlayer]
var slots: Array[NetworkSlot]

var checked_locations: Dictionary = {}

func _init():
	uid = randi()

func _to_string():
	return "AP_CONN(SERV_%s, GEN_%s, SEED:%s, PLYR %d, TEAM %d, SLOT_DATA %s)" % [serv_version,gen_version,seed_name,player_id,team_id,slot_data]

func get_player(id: int) -> NetworkPlayer:
	return players[id-1]
func get_slot(id: int) -> NetworkSlot:
	return slots[id-1]
func get_player_name(plyr_id: int, alias := true) -> String:
	var name = get_player(plyr_id).get_name(alias)
	if not name: name = "Player %d" % plyr_id
	return name
func get_game_for_player(plyr_id: int) -> String:
	return slots[plyr_id-1].game
func get_gamedata_for_player(plyr_id: int) -> DataCache:
	return AP.get_datacache(get_game_for_player(plyr_id))
