class_name AP extends Node

@export var AP_GAME_NAME := "" ## The game name to connect to. Empty string for TextOnly or HintGame clients.
@export var AP_GAME_TAGS: Array[String] = [] ## The tags for your game.
@export var AP_CLIENT_VERSION := Version.val(0,0,0) ## The version of your client. Arbitrary number for you to manage.
@export var AP_VERSION := Version.val(0,5,0) ## The target AP version. Not arbitrary - used in `Connect` packet.
@export var AP_ITEM_HANDLING := ItemHandling.ALL ## The ItemHandling to use when connecting.
@export_group("Client Settings")
@export var AP_PRINT_ITEMS_ON_CONNECT := false ## Prints what items have been previously collected when reconnecting to a slot.
@export var AP_HIDE_NONLOCAL_ITEMSENDS := true ## Hide item send messages that don't involve the client.
@export var AP_AUTO_OPEN_CONSOLE := false ## Automatically opens a default AP text console.
@export var AP_ALLOW_TRACKERPACKS := true ## Allow loading custom tracker packs.

@export_subgroup("Logging")
@export var AP_LOG_COMMUNICATION := false ## Enables additional logging.
@export var AP_LOG_RECIEVED := false ## Enables additional logging.
@export_subgroup("Data Packs")
@export var READABLE_DATAPACK_FILES = true ## If true, datapackage local files will be stringified in a readable mode.
@export var datapack_cached_fields = ["item_name_to_id","location_name_to_id","checksum"] ## Which fields should be saved from received DataPacks.
@export_group("")

#region Connection packets
# See `ConnectionInfo` (Archipelago.conn) for more signals
signal preconnect ## Emitted before connection is attempted
signal roominfo(conn: ConnectionInfo, json: Dictionary) ## Emitted when `RoomInfo` is received
signal connectionrefused(conn: ConnectionInfo, json: Dictionary) ## Emitted when `ConnectionRefused` is received
signal connected(conn: ConnectionInfo, json: Dictionary) ## Emitted when `Connected` is received
signal printjson(json: Dictionary, plaintext: String) ## Emitted when `PrintJSON` is received
signal disconnected ## Emitted when the connection is lost
#endregion
#region Other signals
signal status_updated ## Signals when 'status' changes
signal all_datapacks_loaded ## Signals when all required datapacks have finished loading
## Emitted when a location should be cleared/deleted from the world, as it has been "already collected"
signal remove_location(loc_id: int)
signal on_tag_change
signal on_attach_console
#endregion


#region COLORS
const COLORNAME_PLAYER: StringName = "magenta"
const COLORNAME_ITEM_PROG: StringName = "plum"
const COLORNAME_ITEM: StringName = "cyan"
const COLORNAME_ITEM_USEFUL: StringName = "slateblue"
const COLORNAME_ITEM_TRAP: StringName = "salmon"
const COLORNAME_LOCATION: StringName = "green"

static func color_from_name(colname: String, def := Color.TRANSPARENT) -> Color:
	var c = rich_colors.get(colname)
	return c if c else Color.from_string(colname, def)

## The rich-text colors used for console output
## Chosen to match Archipelago CommonClient
static var rich_colors: Dictionary = {
	"red": Color8(0xEE,0x00,0x00),
	"green": Color8(0x00,0xFF,0x7F),
	"yellow": Color8(0xFA,0xFA,0xD2),
	"blue": Color8(0x64,0x95,0xED),
	"magenta": Color8(0xEE,0x00,0xEE),
	"cyan": Color8(0x00,0xEE,0xEE),
	"white": Color.WHITE,
	"black": Color.BLACK,
	"slateblue": Color8(0x6D,0x8B,0xE8),
	"plum": Color8(0xAF,0x99,0xEF),
	"salmon": Color8(0xFA,0x80,0x72),
	"orange": Color8(0xFF,0x77,0x00),
	"default": Color8(0x2C,0x2C,0x2C),
	"gold": Color.GOLD,
}


#endregion COLORS

enum ItemHandling {
	NONE = 0, ## Don't receive any items from the server.
	OTHER = 1, ## Receive your items in other worlds from the server.
	OWN_AND_OTHER = 3, ## Receive your items from your world and other worlds from the server.
	STARTING_AND_OTHER = 5, ## Receive your items from your starting inventory and other worlds from the server.
	ALL = 7, ## Receive your items from your starting inventory, your world, and other worlds from the server.
}

## The current connection credentials to be used
var creds: APCredentials = APCredentials.new()
## The current APLock object. A default lock object is "unlocked".
## If an "unlocked" object is set here, it will be "locked" when you connect to a slot.
## If a "locked" object is set here, it will disallow you from connecting to any slot different from the one it locked to.
## Saving an APLock object in a save file allows you to lock it to a particular room.
var aplock: APLock = null

var _socket := WebSocketPeer.new()

var config : APConfigManager

#region CONNECTION
var conn: ConnectionInfo ## The active Archipelago connection


enum APStatus {
	DISCONNECTED, ## Not connected to any Archipelago server
	SOCKET_CONNECTING, ## Socket attempting to connect
	CONNECTING, ## Socket connected, trying to connect with server
	CONNECTED, ## Connected with server, authenticating for selected slot
	PLAYING, ## Authenticated and acively playing
	DISCONNECTING, ## Attempting to disconnect from the server
}
var _queue_reconnect := false
## The current connection status
var status: APStatus = APStatus.DISCONNECTED :
	set(val):
		if status != val:
			status = val
			status_updated.emit()
		if status == APStatus.DISCONNECTED:
			conn = null
			if _queue_reconnect:
				_queue_reconnect = false
				ap_reconnect()

## Returns true if there is an active Archipelago connection
func is_ap_connected() -> bool:
	return status == APStatus.PLAYING
## Returns true if there is no active Archipelago connection
func is_not_connected() -> bool:
	return status != APStatus.PLAYING

var _connecting_part: BaseConsole.TextPart

var _connect_attempts := 1
var _wss := true

## Returns the URL currently being targetted for connection
func get_url() -> String:
	return "%s://%s:%s" % ["wss" if _wss else "ws",creds.ip,creds.port]

## Reconnect to Archipelago with the same information as before
func ap_reconnect() -> void:
	if status != APStatus.DISCONNECTED:
		ap_disconnect()
		_queue_reconnect = true
		return
	status = APStatus.SOCKET_CONNECTING
	_connect_attempts = 1
	_wss = true
	preconnect.emit()

## Connect to Archipelago with the specified connection information
func ap_connect(room_ip: String, room_port: String, slot_name: String, room_pwd := "") -> void:
	if status != APStatus.DISCONNECTED:
		ap_disconnect() # Do it here so the ip/port/slot are correct in the disconnect message
	AP.open_logger()
	creds.update(room_ip, room_port, slot_name, room_pwd)
	ap_reconnect()

## Disconnect from Archipelago
func ap_disconnect() -> void:
	if status == APStatus.DISCONNECTED or status == APStatus.DISCONNECTING:
		return
	status = APStatus.DISCONNECTING
	_socket.close()
	AP.close_logger()
	if output_console:
		var part := output_console.add_line("Disconnecting...","%s:%s %s" % [creds.ip,creds.port,creds.slot],output_console.COLOR_UI_MSG)
		while status != APStatus.DISCONNECTED:
			await status_updated
		part.text = "Disconnected from AP."
#endregion CONNECTION

#region LOGGING TO FILE
static var logging_file = null
## Opens the GodotAP logging file, if it isn't already open
static func open_logger() -> void:
	if not logging_file:
		logging_file = FileAccess.open("user://ap/ap_log.log",FileAccess.WRITE)
## Closes the GodotAP logging file, if its open
static func close_logger() -> void:
	if logging_file:
		logging_file.close()
		logging_file = null
## Logs a message to the GodotAP log
static func log(s: Variant) -> void:
	if logging_file:
		logging_file.store_line(str(s))
		if OS.is_debug_build(): logging_file.flush()
	print("[AP] %s" % str(s))
## Logs a message to the GodotAP log, but only if AP_LOG_COMMUNICATION is true
func comm_log(pref: String, s: Variant) -> void:
	if not AP_LOG_COMMUNICATION: return
	AP.log("[%s] %s" % [pref,str(s)])
## Logs a message to the GodotAP log, but only in a Debug build
static func dblog(s: Variant) -> void:
	if not OS.is_debug_build(): return
	AP.log(s)
#endregion

func _poll():
	if status == APStatus.DISCONNECTED:
		return
	if status == APStatus.SOCKET_CONNECTING:
		match _socket.get_ready_state():
			WebSocketPeer.STATE_OPEN: # Already connected, disconnect that connection
				ap_disconnect()
				return
			WebSocketPeer.STATE_CLOSED: # Start a new connection
				var err := _socket.connect_to_url(get_url())
				if err:
					AP.log("Connection to '%s' failed! Retrying (%d)" % [get_url(),_connect_attempts])
					_wss = not _wss
					if _wss: _connect_attempts += 1
				elif output_console and not _connecting_part:
					_connecting_part = output_console.add_line("Connecting...","%s:%s %s" % [creds.ip,creds.port,creds.slot],output_console.COLOR_UI_MSG)
			WebSocketPeer.STATE_CONNECTING: # Continue trying to make new connection
				_socket.poll()
				var state := _socket.get_ready_state()
				if state == WebSocketPeer.STATE_OPEN:
					AP.log("Connected to '%s'!" % get_url())
					status = APStatus.CONNECTING
				elif state != WebSocketPeer.STATE_CONNECTING:
					if _connect_attempts >= 50:
						_socket.close()
						status = APStatus.DISCONNECTING
						AP.log("Connection to '%s' failed too much! Giving up!" % get_url())
						if output_console and _connecting_part:
							_connecting_part.text = "Connection Failed!"
							_connecting_part.tooltip += "\nFailed connecting too many times. Check your connection details, or '/reconnect' to try again."
							_connecting_part = null
					else:
						AP.log("Connection to '%s' failed! Retrying (%d)" % [get_url(),_connect_attempts])
						_wss = not _wss
						if _wss: _connect_attempts += 1
			WebSocketPeer.STATE_CLOSING:
				return
		return
	if _connecting_part:
		_connecting_part = null
	_socket.poll()
	match _socket.get_ready_state():
		WebSocketPeer.STATE_CLOSED: # Exited; handle reconnection, or concluding intentional disconnection
			if status == APStatus.DISCONNECTING:
				status = APStatus.DISCONNECTED
				disconnected.emit()
			else:
				AP.log("Accidental disconnection; reconnecting!")
				ap_reconnect()
		WebSocketPeer.STATE_OPEN: # Running; handle communication
			while _socket.get_available_packet_count():
				var packet: PackedByteArray = _socket.get_packet()
				var json = JSON.parse_string(packet.get_string_from_utf8())
				if not json is Array:
					json = [json]
				for dict in json:
					_handle_command(dict)

var _printout_recieved_items: bool = false
## Sends a command of the specified name, with the given dictionary as the command arguments, to the Archipelago server
func send_command(cmdname: String, args: Dictionary) -> void:
	args["cmd"] = cmdname
	send_packet([args])
## Sends an array of dictionaries as a packet of commands to the server
func send_packet(obj: Array) -> void:
	var s := JSON.stringify(obj)
	Archipelago.comm_log("SEND", s)
	_socket.send_text(s)
func _handle_command(json: Dictionary) -> void:
	var command = json["cmd"]
	match command:
		"RoomInfo":
			status = APStatus.CONNECTED
			if output_console and _connecting_part:
				_connecting_part.text = "Authenticating..."
			conn = ConnectionInfo.new()
			conn.serv_version = Version.from(json["version"])
			conn.gen_version = Version.from(json["generator_version"])
			conn.seed_name = json["seed_name"]
			handle_datapackage_checksums(json["datapackage_checksums"])
			var args: Dictionary = {"name":creds.slot,"password":creds.pwd,"uuid":conn.uid,
				"version":AP_VERSION._as_ap_dict(),"slot_data":true}
			args["game"] = AP_GAME_NAME
			args["tags"] = AP_GAME_TAGS
			args["items_handling"] = AP_ITEM_HANDLING
			roominfo.emit(conn, json)
			send_command("Connect",args)
		"ConnectionRefused":
			var err_str := str(json["errors"])
			if output_console and _connecting_part:
				_connecting_part.text = "Connection Refused!"
				_connecting_part.tooltip += "\nERROR(S): "+err_str
				_connecting_part = null
			AP.log("Connection errors: %s" % err_str)
			connectionrefused.emit(conn, json)
			ap_disconnect()
		"Connected":
			conn.player_id = json["slot"]
			conn.team_id = json["team"]
			conn.slot_data = json["slot_data"]
			for plyr in json["players"]:
				conn.players.append(NetworkPlayer.from(plyr))
			var slot_info = json["slot_info"]
			for key in slot_info:
				conn.slots.append(NetworkSlot.from(slot_info[key]))
			
			if aplock:
				var lock_err := aplock.lock(conn)
				if lock_err:
					_connecting_part.text = "Connection Mismatch! Wrong slot for this save!"
					for s in lock_err:
						_connecting_part.tooltip += "\n%s" % s
						_connecting_part = null
					ap_disconnect()
					return
			
			for loc in json["missing_locations"]:
				if not location_exists(loc):
					conn.slot_locations[loc as int] = false
					#Force this locations to be accessible?
			
			var server_checked = {}
			for loc in json["checked_locations"]:
				_remove_loc(loc)
				server_checked[loc] = true
			
			var to_collect: Array[int] = []
			for loc in conn.slot_locations.keys():
				if conn.slot_locations[loc] and not loc in server_checked:
					to_collect.append(loc)
			collect_locations(to_collect)
			
			# Deathlink stuff?
			# If deathlink stuff, possibly ConnectUpdate to add DeathLink tag?
			
			_send_datapack_request()
			
			status = APStatus.PLAYING
			if output_console and _connecting_part:
				_connecting_part.text = "Connected Successfully!"
				_connecting_part = null
			
			if AP_PRINT_ITEMS_ON_CONNECT:
				_printout_recieved_items = true
				await get_tree().create_timer(3).timeout
				_printout_recieved_items = false
			connected.emit(conn, json)
		"PrintJSON":
			var s: String = (output_console.printjson_command(json) if output_console
				else BaseConsole.printjson_str(json["data"]))
			AP.log("[PRINT] %s" % s)
			printjson.emit(json, s)
		"DataPackage":
			var packs = json["data"]["games"]
			for game in packs.keys():
				_handle_datapack(game, packs[game])
			_send_datapack_request()
		"ReceivedItems":
			if datapack_pending:
				await all_datapacks_loaded
			while status != APStatus.PLAYING:
				if status == APStatus.CONNECTED:
					await status_updated
				else: return
			var idx: int = json["index"]
			var items: Array[NetworkItem] = []
			for obj in json["items"]:
				items.append(NetworkItem.from(obj, true))
			var refr_items: Array[NetworkItem] = []
			if idx == 0:
				refr_items.assign(items)
			if items:
				var q := 0
				while q < items.size():
					if _receive_item(idx, items[q]):
						q += 1
					else:
						items.remove_at(q)
					idx += 1
				items.make_read_only()
				conn.obtained_items.emit(items)
			
			if json["index"] == 0:
				refr_items.make_read_only()
				conn.received_items.assign(refr_items)
				conn.refresh_items.emit(refr_items)
		"RoomUpdate":
			for loc in json.get("checked_locations", []):
				_remove_loc(loc)
			if json.has("players"):
				conn.players.clear()
				for plyr in json["players"]:
					conn.players.append(NetworkPlayer.from(plyr))
			conn.roomupdate.emit(json)
		"Bounced":
			conn.bounce.emit(json)
			var tags: Array = json.get("tags", [])
			if tags.has("DeathLink"):
				var source: String = json["data"].get("source", "")
				if source == conn.get_player_name(false):
					return # Skip deaths from self
				var cause: String = json["data"].get("cause", "")
				conn.deathlink.emit(source, cause, json)
		"LocationInfo":
			conn._on_locinfo(json)
		"Retrieved":
			conn._on_retrieve(json)
		"SetReply":
			conn.setreply.emit(json)
		"InvalidPacket":
			AP.log("[INVALID PACKET] Error with %s of command '%s' (%s)" % [json["type"], json.get("original_cmd", "?"), json["text"]])
		_:
			AP.log("[UNHANDLED PACKET TYPE] %s" % str(json))

#region DATAPACKS
var datapack_cache: Dictionary
var datapack_pending: Array = []
## For each game (key) in the checksums dictionary, requests an update for its datapackage
## if the locally stored checksum does not match the given value
func handle_datapackage_checksums(checksums: Dictionary) -> void:
	DirAccess.make_dir_recursive_absolute("user://ap/datapacks/") # Ensure the directory exists, for later
	var cachefile: FileAccess = FileAccess.open("user://ap/datapacks/cache.dat", FileAccess.READ)
	if cachefile:
		datapack_cache = cachefile.get_var(true)
		cachefile.close()
	datapack_pending = []
	for game in checksums.keys():
		if datapack_cache.has(game):
			var cached = datapack_cache[game]
			if cached["checksum"] == checksums[game] and cached["fields"] == datapack_cached_fields:
				continue #already up-to-date, matching checksum
		datapack_pending.append(game)

## Caches and stores to disk `data` as the DataCache file for `game`
func _handle_datapack(game: String, data: Dictionary) -> void:
	var data_file := FileAccess.open("user://ap/datapacks/%s.json" % game, FileAccess.WRITE)
	datapack_cache[game] = {"checksum":data["checksum"],"fields":datapack_cached_fields.duplicate()}
	for key in data.keys():
		if not key in datapack_cached_fields:
			data.erase(key)
	data_file.store_string(JSON.stringify(data, "\t" if READABLE_DATAPACK_FILES else ""))
	_data_caches[game] = DataCache.from(data)
	data_file.close()
func _send_datapack_request() -> void:
	if datapack_pending:
		var game = datapack_pending.pop_front()
		var req = [{"cmd":"GetDataPackage","games":[game]}]
		#var req = [{"cmd":"GetDataPackage","games":datapack_pending}]
		#datapack_pending = []
		send_packet(req)
	else:
		var cachefile = FileAccess.open("user://ap/datapacks/cache.dat", FileAccess.WRITE)
		cachefile.store_var(datapack_cache, true)
		cachefile.close()
		all_datapacks_loaded.emit()

static var _data_caches: Dictionary = {}
## Returns a DataCache for the specified game. If it cannot be found, returns an empty (invalid) DataCache, which can still be used, albeit it will not have the desired data within.
static func get_datacache(game: String) -> DataCache:
	var ret: DataCache = _data_caches.get(game)
	if ret: return ret
	var data_file := FileAccess.open("user://ap/datapacks/%s.json" % game, FileAccess.READ)
	if not data_file:
		return DataCache.new()
	ret = DataCache.from_file(data_file)
	data_file.close()
	_data_caches[game] = ret
	return ret
#endregion DATAPACKS

#region ITEMS
func _receive_item(index: int, item: NetworkItem) -> bool:
	assert(item.dest_player_id == conn.player_id)
	if conn.received_index(index):
		return false # Already recieved, skip
	var data := conn.get_gamedata_for_player(conn.player_id)
	var msg := ""
	if item.dest_player_id == item.src_player_id:
		if output_console and _printout_recieved_items:
			conn.get_player().output(output_console)
			output_console.add_text(" found their ")
			item.output(output_console)
			output_console.add_text(" (")
			out_location(output_console, item.loc_id, data)
			output_console.add_line(")")
		msg = "You found your %s at %s!" % [data.get_item_name(item.id),data.get_loc_name(item.loc_id)]
		_remove_loc(item.loc_id)
	else:
		var src_data := conn.get_gamedata_for_player(item.src_player_id)
		if output_console and _printout_recieved_items:
			conn.get_player(item.src_player_id).output(output_console)
			output_console.add_text(" sent ")
			item.output(output_console)
			output_console.add_text(" to ")
			conn.get_player().output(output_console)
			output_console.add_text(" (")
			out_location(output_console, item.loc_id, src_data)
			output_console.add_line(")")
		msg = "%s found your %s at their %s!" % [conn.get_player_name(item.src_player_id), data.get_item_name(item.id), src_data.get_loc_name(item.loc_id)]
	
	conn.obtained_item.emit(item)
	
	if AP_LOG_RECIEVED:
		AP.log(msg)
	
	if conn.received_items.size() == index:
		conn.received_items.append(item)
	else:
		if conn.received_items.size() < index+1:
			conn.received_items.resize(index+1)
		conn.received_items[index] = item
	return true
#endregion ITEMS

#region LOCATIONS
func _remove_loc(loc_id: int) -> void:
	if conn and not conn.slot_locations.get(loc_id, false):
		conn.slot_locations[loc_id] = true
		remove_location.emit(loc_id)
## Will call `proc` when the specified location id is "removed" (i.e. collected, either by the player or the server)
## If the location is already removed when you call this, `proc` will be called immediately.
func on_removed_id(loc_id: int, proc: Callable) -> void:
	if conn.slot_locations.get(loc_id, false):
		proc.call()
	else:
		remove_location.connect(func(id:int):
			if id == loc_id:
				proc.call())
## Will call `proc` when the specified location name is "removed" (i.e. collected, either by the player or the server)
## If the location is already removed when you call this, `proc` will be called immediately.
func on_removed(loc_name: String, proc: Callable) -> void:
	on_removed_id(conn.get_gamedata_for_player(conn.player_id).get_loc_id(loc_name), proc)

## Call when a single location is collected and needs to be sent to the server.
func collect_location(loc_id: int) -> void:
	if is_tracker_textclient: return
	_printout_recieved_items = false
	send_command("LocationChecks", {"locations":[loc_id]})
	_remove_loc(loc_id)
## Call when multiple locations are collected and need to be sent to the server at once.
func collect_locations(locs: Array[int]) -> void:
	if is_tracker_textclient: return
	_printout_recieved_items = false
	send_command("LocationChecks", {"locations":locs})
	for loc_id in locs:
		_remove_loc(loc_id)

## Returns if the location exists in the slot or not.
func location_exists(loc_id: int) -> bool:
	return conn.slot_locations.has(loc_id)
## Returns if the location was checked or not. `def` is returned if the location does not exist in the slot.
func location_checked(loc_id: int, def := false) -> bool:
	return conn.slot_locations.get(loc_id, def)
## Returns a list of all location ids
func location_list() -> Array[int]:
	var arr: Array[int] = []
	arr.assign(conn.slot_locations.keys())
	return arr
#endregion LOCATIONS
func _process(_delta):
	_poll()

## Try to reconnect to the current connection details, BUT if it detects errors in the details,
## it will instead prompt the user to enter the details.
func ap_reconnect_to_save() -> void:
	if creds.slot.is_empty() or creds.port.length() != 5:
		if output_console:
			var s = "Connection details required! "
			if aplock and aplock.valid:
				s += "Please reconnect to the room previously used by this save file!"
			else:
				s += "Connect to a room when ready."
			output_console.add_line(s, "", output_console.COLOR_UI_MSG)
	else:
		ap_reconnect()

func _exit_tree():
	if status != APStatus.DISCONNECTED:
		ap_disconnect()

func _notification(what):
	if what == NOTIFICATION_PREDELETE:
		AP.close_logger()

#region CONSOLE

## Prints an Item in richtext (to the console, if `add` is true) and returns the TextPart
func out_item(console: BaseConsole, id: int, flags: int, data: DataCache, add := true) -> BaseConsole.TextPart:
	if not console: return
	var ttip = "Type: %s" % AP.get_item_classification(flags)
	var colorname := AP.get_item_class_color(flags)
	var ret := console.make_text(data.get_item_name(id), ttip, rich_colors[colorname])
	if add: console.add(ret)
	return ret
## Prints a Player in richtext (to the console, if `add` is true) and returns the TextPart
func out_player(console: BaseConsole, id: int, add := true) -> BaseConsole.TextPart:
	if not console: return
	var player := conn.get_player(id)
	var ttip = "Game: %s" % conn.get_slot(id).game
	if not player.alias.is_empty():
		ttip += "\nName: %s" % player.name
	var ret := console.make_text(conn.get_player_name(id), ttip, rich_colors[COLORNAME_PLAYER])
	if add: console.add(ret)
	return ret
## Prints a Location in richtext (to the console, if `add` is true) and returns the TextPart
func out_location(console: BaseConsole, id: int, data: DataCache, add := true) -> BaseConsole.TextPart:
	var ttip = ""
	var ret := console.make_text(data.get_loc_name(id), ttip, rich_colors[COLORNAME_LOCATION])
	if add: console.add(ret)
	return ret

var output_console_container: ConsoleContainer = null
var output_console: BaseConsole :
	get: return cmd_manager.console
	set(val): cmd_manager.console = val

## Loads a PackedScene as the active console. This becomes the active scene in the passed SceneTree.
func load_packed_console_as_scene(tree: SceneTree, console: PackedScene) -> bool:
	if output_console: return false
	if not Util.for_all_nodes(console.instantiate(), func(node): return node is ConsoleContainer):
		return false
	await tree.process_frame
	tree.change_scene_to_packed(console)
	await tree.node_added
	assert(tree.current_scene)
	load_console(tree.current_scene, false)
	return true
## Loads a Node as the active console. The window this node is in will be considered the console window.
func load_console(console_scene: Node, as_child := true) -> bool:
	if output_console: return false
	if console_scene is ConsoleContainer:
		output_console_container = console_scene
	elif console_scene is Node:
		output_console_container = Util.for_all_nodes(console_scene,
			func(node):
				return node is ConsoleContainer)
		if not output_console_container:
			return false
	if as_child: add_child(console_scene)
	console_scene.ready.connect(func():
		output_console = output_console_container.console
		output_console_container.typing_bar.send_text.connect(func(s: String):
			var data = output_console._draw_data
			var y = data.max_shown_y
			cmd_manager.call_cmd(s)
			output_console.is_max_scroll = false
			await get_tree().process_frame # IDK why this is needed, but it works
			output_console.scroll = y
			output_console.is_max_scroll = false
			)
		output_console.tree_exiting.connect(close_console)
		output_console_container.typing_bar.cmd_manager = cmd_manager
		on_attach_console.emit())
	return true
## Opens a default Archipelago text console popup
func open_console() -> void:
	if output_console: return
	load_console(load("res://godot_ap/ui/ap_console_window.tscn").instantiate())
## Closes the currently attached console
func close_console() -> void:
	if output_console:
		output_console.close()
		output_console = null

#endregion CONSOLE

## The CommandManager for console commands. New commands can be registered as you like.
var cmd_manager: CommandManager = CommandManager.new()
## Resets the CommandManager used by the archipelago console
func init_command_manager(can_connect: bool, server_autofills: bool = true):
	cmd_manager.reset()
	cmd_manager.register_default(func(mgr: CommandManager, msg: String):
		if msg[0] == "/":
			mgr.console.add_line("Unknown command '%s' - use '/help' to see commands" % msg.split(" ", true, 1)[0], "", mgr.console.COLOR_UI_MSG)
		else:
			if _ensure_connected(mgr.console):
				send_command("Say", {"text":msg}))
	if can_connect:
		cmd_manager.register_command(ConsoleCommand.new("/connect")
			.add_help("port", "Connects to a new port, with the same ip/slot/password.")
			.add_help("ip[:port]", "Connects to a new ip+[optional] port, with the same slot/password. (if port omitted, uses 38281)")
			.add_help("ip[:port] slot [pwd]", "Connects to a new ip+port, with a new slot and [optional] password. (if port omitted, uses 38281)")
			.set_call(func(mgr: CommandManager, cmd: ConsoleCommand, msg: String):
				var command_args = msg.split(" ", true, 3)
				if command_args.size() == 2:
					command_args.append(creds.slot)
					command_args.append(creds.pwd)
				elif command_args.size() == 3:
					command_args.append("")
				if command_args.size() != 4:
					cmd.output_usage(mgr.console)
				else:
					var ipport = command_args[1].split(":",1)
					if ipport.is_empty():
						cmd.output_usage(mgr.console)
					if ipport.size() == 1 and ipport[0].length() == 5:
						ipport = [creds.ip,ipport[0]]
					elif ipport.size() == 1:
						ipport.append("38281")
					ap_connect(ipport[0],ipport[1],command_args[2],command_args[3])))
		cmd_manager.register_command(ConsoleCommand.new("/reconnect")
			.add_help("", "Refreshes the connection to the Archipelago server")
			.set_call(func(_mgr: CommandManager, _cmd: ConsoleCommand, _msg: String): ap_reconnect()))
		cmd_manager.register_command(ConsoleCommand.new("/disconnect")
			.add_help_cond("", "Kills the connection to the Archipelago server", is_ap_connected)
			.set_call(func(_mgr: CommandManager, _cmd: ConsoleCommand, _msg: String): ap_disconnect()))
	cmd_manager.register_command(ConsoleCommand.new("/locations")
		.add_help_cond("[filter]", "Lists all locations (optionally matching a filter) for the current slot's game.", is_ap_connected)
		.set_call(func(mgr: CommandManager, _cmd: ConsoleCommand, msg: String):
			if not _ensure_connected(mgr.console): return
			var filt := msg.substr(11)
			var data := conn.get_gamedata_for_player()
			
			var columns := BaseConsole.ColumnsPart.new()
			var title := "LOCATIONS"
			if filt: title += " (%s)" % filt
			var folder: BaseConsole.FoldablePart = mgr.console.add_foldable("[ %s ]" % title, msg, mgr.console.COLOR_UI_MSG)
			folder.add(columns)
			folder.fold(false)
			
			var h1 = columns.add(0, mgr.console.make_text("Location Name:"))
			if filt:
				h1.tooltip = "Filter: " + filt
			columns.add(1, mgr.console.make_spacing(Vector2(80,0)))
			columns.add(2, mgr.console.make_text("Status:"))
			
			var ids: Array = data.location_name_to_id.values()
			var _index_dict := {}
			for q in ids.size(): _index_dict[ids[q]] = q
			var _status_getter = func(lid: int) -> String:
				if conn.slot_locations.get(lid): return "Found"
				var status_name = TrackerManager.get_location(lid).get_status("Not Found")
				return status_name
			ids.sort_custom(func(a,b):
				var astat: String = _status_getter.call(a)
				var bstat: String = _status_getter.call(b)
				var v = TrackerManager.sort_by_location_status(astat, bstat)
				if v:
					return v > 0
				return _index_dict[b] > _index_dict[a])
			
			for lid in ids:
				var loc_name = data.get_loc_name(lid)
				if not filt or (filt.to_lower() in loc_name.to_lower()):
					var loc_status = TrackerManager.get_status(_status_getter.call(lid))
					if not loc_status: loc_status = LocationStatus.new("Not Found","","red")
					
					columns.add(0, mgr.console.make_text(loc_name, "Location %d" % lid, rich_colors[loc_status.colorname]))
					columns.add(2, mgr.console.make_text(loc_status.text, loc_status.tooltip, rich_colors[loc_status.colorname]))
			mgr.console.add_header_spacing()
			))
	cmd_manager.register_command(ConsoleCommand.new("/items")
		.add_help_cond("[filter]", "Lists all items (optionally matching a filter) for the current slot's game.", is_ap_connected)
		.set_call(func(mgr: CommandManager, _cmd: ConsoleCommand, msg: String):
			if not _ensure_connected(mgr.console): return
			var filt := msg.substr(7)
			var data := conn.get_gamedata_for_player()
			
			var columns := BaseConsole.ColumnsPart.new()
			var title := "ITEMS"
			if filt: title += " (%s)" % filt
			var folder: BaseConsole.FoldablePart = mgr.console.add_foldable("[ %s ]" % title, msg, mgr.console.COLOR_UI_MSG)
			folder.add(columns)
			folder.fold(false)
			
			var h1 = columns.add(0, mgr.console.make_text("Item Name:"))
			if filt:
				h1.tooltip = "Filter: " + filt
			columns.add(1, mgr.console.make_spacing(Vector2(80,0)))
			columns.add(2, mgr.console.make_text("Num Collected:"))
			
			var item_dict := {}
			for item in conn.received_items:
				var dict = item_dict.get(item.id)
				if dict:
					dict[item.flags] = dict.get(item.flags, 0) + 1
				else:
					item_dict[item.id] = {item.flags: 1}
			
			var ids: Array = data.item_name_to_id.values()
			var _index_dict := {}
			for q in ids.size(): _index_dict[ids[q]] = q
			ids.sort_custom(func(a,b):
				var has_a = item_dict.has(a)
				var has_b = item_dict.has(b)
				if has_a and not has_b:
					return true
				if has_a == has_b:	
					return _index_dict[b] > _index_dict[a]
				return false)
			
			var num_counted := 0
			for iid in ids:
				var itm_name = data.get_item_name(iid)
				if not filt or (filt.to_lower() in itm_name.to_lower()):
					var flag_options = item_dict.get(iid)
					if flag_options:
						num_counted += 1
						for flags in flag_options.keys():
							var c1 = columns.add(0, out_item(mgr.console, iid, flags, data, false))
							columns.add(2, mgr.console.make_text("x%d" % flag_options[flags], "", c1.color))
					else:
						columns.add(0, mgr.console.make_text(itm_name, "Item %d" % iid, rich_colors["white"]))
						columns.add_nil(2)
			if columns.parts[0].parts.size() == 1:
				columns.parts = []
				if filt:
					columns.add(0, mgr.console.make_text(
						"No%s items found!" % (" matching" if filt else ""),
						h1.tooltip, rich_colors["salmon"]))
			elif not num_counted:
				columns.parts.pop_back()
				columns.parts.pop_back()
			mgr.console.add_header_spacing()
			))
	if server_autofills: # Autofill for some AP commands
		cmd_manager.register_command(ConsoleCommand.new("!hint_location")
			.set_autofill(_autofill_locs)
			.add_disable(is_not_connected))
		cmd_manager.register_command(ConsoleCommand.new("!hint")
			.set_autofill(_autofill_items)
			.add_disable(is_not_connected))
		cmd_manager.register_command(ConsoleCommand.new("!help")
			.add_help("", "Displays server-based command help")
			.add_disable(is_not_connected))
		cmd_manager.register_command(ConsoleCommand.new("!remaining")
			.add_disable(is_not_connected))
		cmd_manager.register_command(ConsoleCommand.new("!missing")
			.add_disable(is_not_connected))
		cmd_manager.register_command(ConsoleCommand.new("!checked")
			.add_disable(is_not_connected))
		cmd_manager.register_command(ConsoleCommand.new("!collect")
			.add_disable(is_not_connected))
		cmd_manager.register_command(ConsoleCommand.new("!release")
			.add_disable(is_not_connected))
		cmd_manager.register_command(ConsoleCommand.new("!players")
			.add_disable(is_not_connected))
	if AP_ALLOW_TRACKERPACKS:
		cmd_manager.register_command(ConsoleCommand.new("/tracker")
			.add_help_cond("vars", "Outputs trackerpack debug info", is_ap_connected)
			.add_help_cond("locations [filter]", "Outputs trackerpack location debug info, optionally filtered", is_ap_connected)
			.add_help("refresh", "Reloads tracker packs")
			.set_autofill(_autofill_track)
			.set_call(func(mgr: CommandManager, cmd: ConsoleCommand, msg: String):
				var args = msg.split(" ", true, 2)
				if args.size() < 2:
					cmd.output_usage(mgr.console)
					return
				match args[1].to_lower():
					"locations":
						if not _ensure_connected(mgr.console): return
						var filt: String = args[2].to_lower() if args.size() > 2 else ""
						var locs: Array[APLocation] = []
						
						locs.assign(conn.slot_locations.keys() \
							.map(func(locid: int): return TrackerManager.get_location(locid)) \
							.filter(func(v: APLocation): return v.loaded_tracker_loc != null and \
								(filt.is_empty() or v.name.to_lower().contains(filt))))
						locs.sort_custom(func(a: APLocation, b: APLocation): return a.name.naturalnocasecmp_to(b.name) < 0)
						if not locs.is_empty():
							mgr.console.add_header_spacing()
							var outer_folder := mgr.console.add_foldable("[ TRACKER LOCATIONS ]", msg, mgr.console.COLOR_UI_MSG)
							outer_folder.fold(false)
							for loc in locs:
								var tloc: TrackerLocation = loc.loaded_tracker_loc
								var status_name := tloc.get_status()
								var status_obj := TrackerManager.get_status(status_name)
								var folder: BaseConsole.FoldablePart = outer_folder.add(
									mgr.console.make_foldable("%s (%s)" % [loc.name, status_name], "", rich_colors[status_obj.colorname]))
								for stat in tloc._iter_statuses():
									if stat.text == "Found": continue
									folder.add(mgr.console.make_text("'%s':" % stat.text, stat.tooltip, rich_colors[stat.colorname]))
									mgr.console.ensure_newline(folder.get_inner_parts())
									var cont: BaseConsole.ContainerPart = folder.add(mgr.console.make_indented_block(
										tloc.status_rules[stat.text].get_repr(1), 25, mgr.console.COLOR_UI_MSG))
									cont.textpart_replace("true", "true", true, "", rich_colors["green"])
									cont.textpart_replace("false", "false", true, "", rich_colors["red"])
							mgr.console.add_header_spacing()
					"refresh":
						TrackerManager.load_tracker_packs()
					"vars":
						if not _ensure_connected(mgr.console): return
						mgr.console.add_header_spacing()
						var outer_folder := mgr.console.add_foldable("[ TRACKER INFO ]", msg, mgr.console.COLOR_UI_MSG)
						outer_folder.fold(false)
						outer_folder.add(mgr.console.make_header_spacing())
						outer_folder.add(mgr.console.make_indent(20))
						var needs_spacing := false
						var named_rules = TrackerManager.named_rules.keys()
						if not named_rules.is_empty():
							if needs_spacing:
								outer_folder.add(mgr.console.make_header_spacing())
							else: needs_spacing = true
							var rules_folder := outer_folder.add(mgr.console.make_foldable("[ NAMED RULES ]", "", mgr.console.COLOR_UI_MSG))
							for rulename in named_rules:
								var rule = TrackerManager.get_named_rule(rulename)
								var b = rule.can_access()
								var c = "white"
								if b != null:
									c = "green" if b else "red"
								var inner_folder: BaseConsole.FoldablePart = rules_folder.add(
									mgr.console.make_foldable(rulename, "", AP.color_from_name(c)))
								var cont: BaseConsole.ContainerPart = inner_folder.add(mgr.console.make_indented_block(
									rule.get_repr(0), 25, mgr.console.COLOR_UI_MSG))
								cont.textpart_replace("true", "true", true, "", rich_colors["green"])
								cont.textpart_replace("false", "false", true, "", rich_colors["red"])
						var named_vals = TrackerManager.named_values.keys()
						if not named_vals.is_empty():
							if needs_spacing:
								outer_folder.add(mgr.console.make_header_spacing())
							else: needs_spacing = true
							var vals_folder := outer_folder.add(mgr.console.make_foldable("[ NAMED VALUES ]", "", mgr.console.COLOR_UI_MSG))
							for valname in named_vals:
								var val_node := TrackerManager.get_named_value(valname)
								var value = val_node.calculate()
								var inner_folder: BaseConsole.FoldablePart = vals_folder.add(
									mgr.console.make_foldable("%s = %s" % [valname,value], "", mgr.console.COLOR_UI_MSG))
								var val_str: String = "%s" % JSON.stringify(val_node._to_dict(), "\t", false)
								var cont: BaseConsole.ContainerPart = inner_folder.add(mgr.console.make_indented_block(val_str, 25))
								cont.textpart_replace("true", "true", true, "", rich_colors["green"])
								cont.textpart_replace("false", "false", true, "", rich_colors["red"])
						var vars = TrackerManager.variables.keys()
						if not vars.is_empty():
							if needs_spacing:
								outer_folder.add(mgr.console.make_header_spacing())
							else: needs_spacing = true
							var vars_folder := outer_folder.add(mgr.console.make_foldable("[ VARIABLES ]", "", mgr.console.COLOR_UI_MSG))
							for varname in vars:
								vars_folder.add(mgr.console.make_text(varname+": ", "", mgr.console.COLOR_UI_MSG))
								var val = TrackerManager.get_variable(varname)
								vars_folder.add(mgr.console.make_text(str(val), "", AP.color_from_name("green")))
								vars_folder.add(mgr.console.make_header_spacing(0))
						outer_folder.add(mgr.console.make_indent(-20))
						mgr.console.add_header_spacing()
				))
	cmd_manager.setup_basic_commands()
	if OS.is_debug_build():
		cmd_manager.register_command(ConsoleCommand.new("/send").debug()
			.add_help("", "Cheat-Collects the given location")
			.add_disable(func(): return is_tracker_textclient)
			.set_autofill(_autofill_locs)
			.set_call(func(mgr: CommandManager, cmd: ConsoleCommand, msg: String):
				if not _ensure_connected(mgr.console): return
				var command_args = msg.split(" ", true, 1)
				if command_args.size() > 1 and command_args[1]:
					var data = conn.get_gamedata_for_player(conn.player_id)
					for loc in conn.slot_locations.keys():
						var loc_name := data.get_loc_name(loc)
						if loc_name.strip_edges().to_lower() == command_args[1].strip_edges().to_lower():
							if conn.slot_locations[loc]:
								mgr.console.add_line("Location already sent!", "", mgr.console.COLOR_UI_MSG)
							else:
								mgr.console.add_line("Sending location '%s'!" % loc_name, "", mgr.console.COLOR_UI_MSG)
								collect_location(loc)
							return
					mgr.console.add_line("Location '%s' not found! Check spelling?" % command_args[1].strip_edges(), "", mgr.console.COLOR_UI_MSG)
				else: cmd.output_usage(mgr.console)))
		cmd_manager.register_command(ConsoleCommand.new("/lock_info").debug()
			.add_help("", "Prints the connection lock info")
			.set_call(func(mgr: CommandManager, _cmd: ConsoleCommand, _msg: String):
				mgr.console.add_line("%s" % (str(aplock) if aplock else "No Lock Active"), "", mgr.console.COLOR_UI_MSG)))
		cmd_manager.register_command(ConsoleCommand.new("/unlock_connection").debug()
			.add_help("", "Unlocks the connection lock, so that any valid slot can be connected to (instead of only the slot previously connected to)")
			.set_call(func(_mgr: CommandManager, _cmd: ConsoleCommand, _msg: String):
				if aplock:
					aplock.unlock()))
		cmd_manager.register_command(ConsoleCommand.new("/set_tag").debug()
			.add_help("tag [bool]", "Sets a tag for the current connection")
			.set_autofill(func(msg: String):
				var args = msg.split(" ", 2)
				var arg_count := args.size()
				while args.size() < 3: args.append("")
				var ret: Array[String] = []
				var opts: Array[String] = []
				if arg_count < 3:
					opts.assign(["TextOnly","HintGame","Tracker","DeathLink"])
					var matched := false
					for opt in opts:
						if args[1] == opt:
							matched = true
							break
						if opt.to_lower().begins_with(args[1].to_lower()):
							ret.append("%s %s" % [args[0],opt])
					if not matched:
						return ret
					ret.clear()
				opts.assign(["true","false"])
				for opt in opts:
					if arg_count < 3 or opt.to_lower().begins_with(args[2].to_lower()):
						ret.append("%s %s %s" % [args[0],args[1],opt])
				return ret)
			.set_call(func(mgr: CommandManager, cmd: ConsoleCommand, msg: String):
				var args = msg.split(" ", true, 2)
				var state := true
				var tag: String = args[1].strip_edges() if args.size() > 1 else ""
				if tag.is_empty():
					cmd.output_usage(mgr.console)
					return
				if args.size() > 2:
					var s = args[2].to_lower()
					if s == "false": state = false
					elif s != "true":
						cmd.output_usage(mgr.console)
						return
				set_tag(tag, state)
				mgr.console.add_line("Set tag '%s' to %s" % [args[1],state], "", mgr.console.COLOR_UI_MSG)))
		cmd_manager.register_command(ConsoleCommand.new("/tags").debug()
			.add_help("", "Prints out your connection tags")
			.set_call(func(mgr: CommandManager, _cmd: ConsoleCommand, _msg: String):
				mgr.console.add_line(str(AP_GAME_TAGS), "", mgr.console.COLOR_UI_MSG)))
		cmd_manager.register_command(ConsoleCommand.new("/slot_data").debug()
			.add_help("", "Prints slot_data")
			.add_disable(is_not_connected)
			.set_call(func(mgr: CommandManager, _cmd: ConsoleCommand, _msg: String):
				var folder := mgr.console.add_foldable("[ SLOT_DATA ]", "/slot_data", mgr.console.COLOR_UI_MSG)
				folder.add(mgr.console.make_indented_block(JSON.stringify(Archipelago.conn.slot_data, "\t"), 25))
				folder.fold(false)
				))
		cmd_manager.setup_debug_commands()

func _autofill_track(msg: String) -> Array[String]:
	var args = msg.split(" ", true, 2)
	if args.size() <= 2:
		var fills: Array[String] = ["locations", "refresh", "vars"]
		if not conn:
			fills.erase("locations")
			fills.erase("vars")
		fills.assign(fills.map(func(s: String):
			return "%s %s" % [args[0],s]))
		if args.size() < 2:
			return fills
		var new_fills: Array[String] = []
		for s in fills:
			if s.to_lower().begins_with(msg.to_lower()):
				new_fills.append(s)
		return new_fills
	return []
func _init():
	init_command_manager(true)
	_socket.inbound_buffer_size = 65535*8
	_update_tags()
	if AP_AUTO_OPEN_CONSOLE:
		open_console()
func _ready():
	for node in get_children():
		if node is APConfigManager:
			config = node
			break
	if not config:
		config = APConfigManager.new()
		add_child(config)
enum ItemClassification {
	FILLER = 0b000,
	PROG = 0b001,
	USEFUL = 0b010,
	TRAP = 0b100
}

static func get_item_class_color(flags: int) -> String:
	var ret := COLORNAME_ITEM
	if flags & ItemClassification.PROG:
		ret = COLORNAME_ITEM_PROG
	elif flags & ItemClassification.TRAP:
		ret = COLORNAME_ITEM_TRAP
	return ret
## Returns the string name representing the combined item classifications flags
static func get_item_classification(flags: int) -> String:
	match flags:
		ItemClassification.PROG:
			return "Progression"
		ItemClassification.USEFUL:
			return "Useful"
		ItemClassification.TRAP:
			return "Trap"
		ItemClassification.FILLER:
			return "Filler"
		_:
			var s := ""
			for q in 3:
				if flags & (1<<q):
					if s:
						s += ","
					s += get_item_classification(1<<q)
			return s

func _cmd_nil(_msg: String): pass
func _autofill_locs(msg: String) -> Array[String]:
	if not conn: return []
	var args = msg.split(" ", true, 1)
	var data: DataCache = conn.get_gamedata_for_player(conn.player_id)
	var locs: Array[String] = []
	locs.assign(data.location_name_to_id.keys())
	var ind := 0
	while ind < locs.size():
		var id: int = data.location_name_to_id[locs[ind]]
		if location_checked(id, true):
			locs.pop_at(ind)
		else: ind += 1
	if args.size() > 1 and args[1]:
		var arg_str = args[1].strip_edges().to_lower()
		if arg_str.begins_with("\""):
			arg_str = arg_str.substr(1)
		if arg_str.ends_with("\""):
			arg_str = arg_str.substr(0,arg_str.length()-1)
		var q := 0
		while q < locs.size():
			if not locs[q].strip_edges().to_lower().begins_with(arg_str):
				locs.pop_at(q)
			else:
				q += 1
	for q in locs.size():
		locs[q] = "%s %s" % [args[0],locs[q]]
	return locs
func _autofill_items(msg: String) -> Array[String]:
	if not conn: return []
	var args = msg.split(" ", true, 1)
	var data: DataCache = conn.get_gamedata_for_player(conn.player_id)
	var itms: Array[String] = []
	itms.assign(data.item_name_to_id.keys())
	if args.size() > 1 and args[1]:
		var arg_str = args[1].strip_edges().to_lower()
		if arg_str.begins_with("\""):
			arg_str = arg_str.substr(1)
		if arg_str.ends_with("\""):
			arg_str = arg_str.substr(0,arg_str.length()-1)
		var q := 0
		while q < itms.size():
			if not itms[q].strip_edges().to_lower().begins_with(arg_str):
				itms.pop_at(q)
			else:
				q += 1
	for q in itms.size():
		itms[q] = "%s %s" % [args[0],itms[q]]
	return itms

var is_tracker_textclient := false
func _update_tags() -> void:
	if status == APStatus.PLAYING:
		send_command("ConnectUpdate", {"tags":AP_GAME_TAGS})
	is_tracker_textclient = false
	for tag in AP_GAME_TAGS:
		if tag == "TextOnly" or tag == "Tracker":
			is_tracker_textclient = true
			break
	on_tag_change.emit()
## Sets a given Archipelago tag (on or off)
func set_tag(tag: String, state := true) -> void:
	if tag.is_empty(): return
	for q in AP_GAME_TAGS.size():
		var t := AP_GAME_TAGS[q]
		if t == tag:
			if not state:
				AP_GAME_TAGS.pop_at(q)
				_update_tags()
			return
	if state:
		AP_GAME_TAGS.append(tag)
		_update_tags()
## Sets the Archipelago connection tags (overwriting all existing tags)
func set_tags(tags: Array[String]) -> void:
	if AP_GAME_TAGS != tags:
		AP_GAME_TAGS.assign(tags)
		_update_tags()

func _ensure_connected(console: BaseConsole) -> bool:
	if status == APStatus.PLAYING:
		return true
	console.add_line("Not connected to Archipelago! Please connect first!", "", console.COLOR_UI_MSG)
	return false

func set_deathlink(state: bool) -> void:
	set_tag("DeathLink", state)

func is_deathlink() -> bool:
	return "DeathLink" in Archipelago.AP_GAME_TAGS
