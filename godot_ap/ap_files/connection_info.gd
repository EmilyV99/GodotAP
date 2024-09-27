class_name ConnectionInfo

# Variables / data

var serv_version: Version
var gen_version: Version
var seed_name: String
var uid: int

var player_id: int
var team_id: int
var slot_data: Dictionary

var players: Array[NetworkPlayer]
var slots: Array[NetworkSlot]

var slot_locations: Dictionary = {}
var received_items: Array[NetworkItem] = []
var hints: Array[NetworkHint] = []

# Init / Getters

func received_index(index: int) -> bool:
	return received_items.size() > index and received_items[index] != null

func _init():
	uid = randi()

func _to_string():
	return "AP_CONN(SERV_%s, GEN_%s, SEED:%s, PLYR %d, TEAM %d, SLOT_DATA %s)" % [serv_version,gen_version,seed_name,player_id,team_id,slot_data]

## Returns a NetworkPlayer for the given ID (or the current slot)
func get_player(id: int = -1) -> NetworkPlayer: ## TODO handle Team
	if id < 0: return players[player_id-1]
	return players[id-1]
## Returns a NetworkSlot for the given ID (or the current slot)
func get_slot(id: int = -1) -> NetworkSlot: ## TODO handle Team
	if id < 0: return slots[player_id-1]
	return slots[id-1]
## Returns a player's name for the given ID (or the current slot)
## If `alias` is false, will return the slot name regardless of alias
func get_player_name(plyr_id: int = -1, alias := true) -> String:
	var name = get_player(plyr_id).get_name(alias)
	if not name: name = "Player %d" % plyr_id
	return name
## Returns the game name for the given player ID (or the current slot)
func get_game_for_player(plyr_id: int = -1) -> String:
	return get_slot(plyr_id).game
## Returns the DataCache for the given player ID (or the current slot)
func get_gamedata_for_player(plyr_id: int = -1) -> DataCache:
	return AP.get_datacache(get_game_for_player(plyr_id))

# Incoming server packets
signal bounce(json: Dictionary) ## Emitted when a `Bounce` packet is received.
signal deathlink(source: String, cause: String, json: Dictionary) ## Emitted when a `Bounce` packet of type `DeathLink` is received, after the `bounce` signal.
signal setreply(json: Dictionary) ## Emitted when a `SetReply` packet is received
signal roomupdate(json: Dictionary) ## Emitted when a `RoomUpdate` packet is received
signal obtained_item(item: NetworkItem) ## Emitted for each item received
signal obtained_items(items: Array[NetworkItem]) ## Emitted for each item *packet* received
signal refresh_items(items: Array[NetworkItem]) ## Emitted when the server re-sends ALL obtained items
signal on_hint_update(hints: Array[NetworkHint]) ## Emitted when hints relevant to this client change

signal all_scout_cached ## Emitted when a scout packet containing ALL locations is received (see `force_scout_all`)
# Outgoing server packets
var _notified_keys: Dictionary = {}
var _hint_listening: bool = false
func install_hint_listener() -> void:
	if _hint_listening: return
	_hint_listening = true
	var hint_str := "_read_hints_%d_%d" % [team_id, player_id]
	set_notify(hint_str, _load_hints_from_json)
	retrieve(hint_str, _load_hints_from_json)
func _load_hints_from_json(new_hints: Array) -> void:
	hints = []
	for json in new_hints:
		hints.append(NetworkHint.from(json))
	hints.make_read_only()
	on_hint_update.emit(hints)


## Connects the specified `Callable[Array[NetworkHint]]->void` to be called every time
## hints are updated for this client. Will call immediately, if hints are already loaded;
## else will immediately call for hints to be loaded, which will trigger an update.
func set_hint_notify(proc: Callable) -> void:
	on_hint_update.connect(proc)
	if _hint_listening: proc.call(hints)
	else: install_hint_listener()
## Sends a `SetNotify` packet, and connects the specified `Callable[Variant]->void`
## to be called every time the specified `key` is updated on the server.
func set_notify(key: String, proc: Callable) -> void: ##
	if not _notified_keys.has(key):
		Archipelago.send_command("SetNotify", {"keys": [key]})
		_notified_keys[key] = true
	setreply.connect(func(json):
		if json["key"] == key:
			proc.call(json.get("value")))

var _retrieve_queue: Dictionary
## Sends a `Get` packet, and connects the specified `Callable[Variant]->void`
## to be called once when the result is retrieved
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

## Sends an `UpdateHint` packet, updating the status of an existing hint
## The hint is identified by `loc, plyr`, the location it is for and the player who is to find it
## Only valid if the server is running a branch with https://github.com/ArchipelagoMW/Archipelago/pull/3506
func update_hint(loc: int, plyr: int, status: NetworkHint.Status) -> void:
	Archipelago.send_command("UpdateHint", {"location": loc, "player": plyr, "status": status})

var _scout_cache: Dictionary
var _scout_queue: Dictionary
## Sends a `LocationScouts` packet, and connects the specified `Callable[NetworkItem]->void`
## to be called with the returned information.
## If the location has already been scouted this session, returns the cached info.
func scout(location: int, create_as_hint: int, proc: Callable) -> void:
	var item: NetworkItem = _scout_cache.get(location)
	if create_as_hint or not item: # Always send if `create_as_hint`!
		Archipelago.send_command("LocationScouts", {"locations": [location], "create_as_hint": create_as_hint})
	if not proc: return
	if item:
		proc.call(item)
	else:
		if not _scout_queue.has(location):
			_scout_queue[location] = [proc]
		else: _scout_queue[location].append(proc)
func _on_locinfo(json: Dictionary) -> void:
	var locs = json.get("locations", [])
	for loc in locs:
		var locid = loc["location"] as int
		_scout_cache[locid] = NetworkItem.from(loc, false)
		for proc in _scout_queue.get(locid, []):
			proc.call(_scout_cache[locid])
		_scout_queue.erase(locid)
	if locs.size() == slot_locations.size():
		all_scout_cached.emit()
func force_scout_all() -> void: ## Scouts every location into the local cache
	Archipelago.send_command("LocationScouts", {"locations": slot_locations.keys(), "create_as_hint": 0})

## Sends a `Bounce` packet with whatever information you like
func send_bounce(data: Dictionary, target_games: Array[String], target_slots: Array[String], target_tags: Array[String]) -> void:
	var cmd: Dictionary = {}
	if target_games:
		cmd["games"] = target_games
	if target_slots:
		cmd["slots"] = target_slots
	if target_tags:
		cmd["tags"] = target_tags
	if not cmd: return
	cmd.merge(data)
	Archipelago.send_command("Bounce", cmd)

## Sends a `Bounce` packet designed for the `DeathLink` feature
## Requires the client be connected with the `DeathLink` tag
func send_deathlink(cause: String = ""):
	if not Archipelago.is_deathlink():
		AP.log("Tried to send DeathLink while DeathLink is not enabled!")
		return
	var cmd: Dictionary = {"data": {}}
	if not cause.is_empty():
		cmd["data"]["cause"] = cause
	cmd["data"]["source"] = get_player_name(-1, false)
	cmd["data"]["time"] = Time.get_unix_time_from_system()
	assert(not Archipelago.ap_deathlink_sent_key.is_empty())  # Should always be fine while connected
	cmd["data"]["godotap_key"] = Archipelago.ap_deathlink_sent_key
	send_bounce(cmd, [], [], ["DeathLink"])
