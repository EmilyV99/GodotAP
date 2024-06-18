class_name ConnectionInfo

# Variables / data

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

# Init / Getters

func _init():
	uid = randi()

func _to_string():
	return "AP_CONN(SERV_%s, GEN_%s, SEED:%s, PLYR %d, TEAM %d, SLOT_DATA %s)" % [serv_version,gen_version,seed_name,player_id,team_id,slot_data]

func get_player(id: int = -1) -> NetworkPlayer: ## TODO handle Team
	if id < 0: return players[player_id-1]
	return players[id-1]
func get_slot(id: int = -1) -> NetworkSlot: ## TODO handle Team
	if id < 0: return slots[player_id-1]
	return slots[id-1]
func get_player_name(plyr_id: int, alias := true) -> String:
	var name = get_player(plyr_id).get_name(alias)
	if not name: name = "Player %d" % plyr_id
	return name
func get_game_for_player(plyr_id: int) -> String:
	return slots[plyr_id-1].game
func get_gamedata_for_player(plyr_id: int) -> DataCache:
	return AP.get_datacache(get_game_for_player(plyr_id))

# Incoming server packets
signal bounce(json: Dictionary)
signal deathlink(source: String, cause: String, json: Dictionary)
signal locationinfo(json: Dictionary)
signal setreply(json: Dictionary)
signal roomupdate(json: Dictionary)

# Outgoing server packets
func set_notify(key: String, proc: Callable) -> void: ## Callable[Variant]->void
	Archipelago.send_command("SetNotify", {"keys": [key]})
	setreply.connect(func(json):
		if json["key"] == key:
			proc.call(json.get("value")))

var _retrieve_queue: Dictionary
func retrieve(key: String, proc: Callable) -> void: ## Callable[Variant]->void
	Archipelago.send_command("Get", {"keys": [key]})
	if not _retrieve_queue.has(key):
		_retrieve_queue[key] = [proc]
	else: _retrieve_queue[key].append(proc)
func _on_retrieve(json: Dictionary) -> void:
	var vals: Dictionary = json.get("keys", {})
	for key in vals.keys():
		for proc in _retrieve_queue.get(key, []):
			proc.call(vals[key])
		_retrieve_queue[key] = []

func update_hint(loc: int, plyr: int, status: NetworkHint.Status) -> void:
	Archipelago.send_command("UpdateHint", {"location": loc, "player": plyr, "status": status})
