class_name AP extends Node

const AP_GAME_NAME := "Super Metroid"
const AP_GAME_TAGS: Array[String] = []
const AP_ITEM_HANDLING := ItemHandling.ALL
const AP_LOG_COMMUNICATION := true
const COLOR_PLAYER: Color = Color8(238,0,238)
const COLOR_ITEM_PROG: Color = Color8(175,153,239)
const COLOR_ITEM: Color = Color8(1,234,234)
const COLOR_ITEM_TRAP: Color = Color.RED
const COLOR_LOCATION: Color = Color8(1,252,126)
const COLOR_SELF: Color = Color.GOLDENROD
const COLOR_UI_MSG: Color = Color(.7,.7,.3)

enum ItemHandling {
	NONE = 0,
	OTHER = 1,
	OWN_OTHER = 3,
	STARTING_OTHER = 5,
	ALL = 7,
}

var ip: String = "archipelago.gg"
var port: String = ""
var slot: String = ""
var pwd: String = ""
var death_alias: String = ""
var uid: int

var socket := WebSocketPeer.new()

#region CONNECTION
class ConnectionInfo:
	var serv_version: Version
	var gen_version: Version
	var seed_name: String
	
	var player_id: int
	var team_id: int
	var slot_data: Dictionary
	
	var players: Array[NetworkPlayer]
	var slots: Array[NetworkSlot]
	
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
	

var conn: ConnectionInfo

enum APStatus {
	DISCONNECTED,
	CONNECTING,
	CONNECTED,
	PLAYING, # 'Authenticated'
	DISCONNECTING,
}
signal status_updated
var status: APStatus = APStatus.DISCONNECTED :
	set(val):
		if status != val:
			status = val
			print(status)
			status_updated.emit()
		if status == APStatus.DISCONNECTED:
			conn = null

func ap_reconnect() -> void:
	var attempts := 1
	var wss := true
	var url: String
	while true:
		url = "%s://%s:%s" % ["wss" if wss else "ws",ip,port]
		socket.close()
		var err := socket.connect_to_url(url)
		if err:
			AP.log("Connection to '%s' failed! Retrying (%d)" % [url,attempts])
			wss = not wss
			if wss: attempts += 1
		else: break
	AP.log("Connected to '%s'!" % url)
	status = APStatus.CONNECTING

func ap_connect(room_ip: String, room_port: String, slot_name: String, room_pwd := "") -> void:
	AP.open_logger()
	ip = room_ip
	port = room_port
	slot = slot_name
	pwd = room_pwd
	death_alias = ""
	ap_reconnect()

func ap_disconnect() -> void:
	status = APStatus.DISCONNECTING
	socket.close()
	AP.close_logger()
#endregion CONNECTION

static var logging_file = null
static func open_logger() -> void:
	logging_file = FileAccess.open("user://ap/ap_log.log",FileAccess.WRITE)
static func close_logger() -> void:
	if logging_file:
		logging_file.close()
		logging_file = null
static func log(s: Variant) -> void:
	if logging_file:
		logging_file.store_line(str(s))
		if OS.is_debug_build(): logging_file.flush()
	print("[AP] %s" % str(s))
static func comm_log(pref: String, s: Variant) -> void:
	if not AP_LOG_COMMUNICATION: return
	AP.log("[%s] %s" % [pref,str(s)])
static func dblog(s: Variant) -> void:
	if not OS.is_debug_build(): return
	AP.log(s)

func poll():
	if status == APStatus.DISCONNECTED:
		return
	socket.poll()
	match socket.get_ready_state():
		WebSocketPeer.STATE_CLOSED: # Exited; handle reconnection, or concluding intentional disconnection
			if status == APStatus.DISCONNECTING:
				status = APStatus.DISCONNECTED
			else:
				AP.log("Accidental disconnection; reconnecting!")
				ap_reconnect()
		WebSocketPeer.STATE_OPEN: # Running; handle communication
			while socket.get_available_packet_count():
				var packet: PackedByteArray = socket.get_packet()
				var json = JSON.parse_string(packet.get_string_from_utf8())
				if not json is Array:
					json = [json]
				for dict in json:
					handle_command(dict)

var printout_recieved_items: bool = false
func send_command(cmdname: String, obj: Dictionary) -> void:
	obj["cmd"] = cmdname
	send_packet([obj])
func send_packet(obj: Array) -> void:
	var s := JSON.stringify(obj)
	AP.comm_log("SEND", s)
	socket.send_text(s)
func handle_command(json: Dictionary) -> void:
	var command = json["cmd"]
	match command:
		"RoomInfo":
			status = APStatus.CONNECTED
			conn = ConnectionInfo.new()
			conn.serv_version = Version.from(json["version"])
			conn.gen_version = Version.from(json["generator_version"])
			conn.seed_name = json["seed_name"]
			handle_datapackage_checksums(json["datapackage_checksums"])
			var args: Dictionary = {"name":slot,"password":pwd,"uuid":uid,
				"version":Version.val(0,4,6)._as_ap_dict(),"slot_data":true}
			args["game"] = AP_GAME_NAME
			args["tags"] = AP_GAME_TAGS
			args["items_handling"] = AP_ITEM_HANDLING
			send_command("Connect",args)
		"ConnectionRefused":
			AP.log("Connection errors: %s" % str(json["errors"]))
			ap_disconnect()
		"Connected":
			conn.player_id = json["slot"]
			conn.team_id = json["team"]
			#conn.slot_data = json["slot_data"]
			for plyr in json["players"]:
				conn.players.append(NetworkPlayer.from(plyr, conn))
			var slot_info = json["slot_info"]
			for key in slot_info:
				conn.slots.append(NetworkSlot.from(slot_info[key]))
			AP.log(conn)
			
			for loc in json["missing_locations"]:
				if not _removed_locs.has(loc):
					_removed_locs[loc] = false
					#Force this locations to be accessible?
			
			var server_checked = {}
			for loc in json["checked_locations"]:
				_remove_loc(loc)
				server_checked[loc] = true
			
			for loc in _removed_locs.keys():
				if _removed_locs[loc] and not loc in server_checked:
					collect_location(loc)
			
			# Deathlink stuff?
			# If deathlink stuff, possibly ConnectUpdate to add DeathLink tag?
			
			send_datapack_request()
			
			status = APStatus.PLAYING
			
			printout_recieved_items = true
			await get_tree().create_timer(3).timeout
			printout_recieved_items = false
		"PrintJSON":
			var s: String = ""
			for elem in json["data"]:
				var txt: String = elem["text"]
				s += txt
				if output_console:
					match elem.get("type", "text"):
						"player_name":
							output_console.add_text(txt, "Arbitrary Player Name", COLOR_PLAYER)
						"item_name":
							output_console.add_text(txt, "Arbitrary Item Name", COLOR_ITEM)
						"location_name":
							output_console.add_text(txt, "Arbitrary Location Name", COLOR_LOCATION)
						"entrance_name":
							output_console.add_text(txt, "Arbitrary Entrance Name", COLOR_LOCATION)
						"player_id":
							var plyr_id = int(txt)
							conn.get_player(plyr_id).output(output_console)
						"item_id":
							var item_id = int(txt)
							var plyr_id = int(elem["player"])
							var data := conn.get_gamedata_for_player(plyr_id)
							var flags := int(elem["flags"])
							AP.out_item(output_console, item_id, flags, data)
						"location_id":
							var loc_id = int(txt)
							var plyr_id = int(elem["player"])
							var data := conn.get_gamedata_for_player(plyr_id)
							AP.out_location(output_console, loc_id, data)
						"text":
							output_console.add_text(txt)
						"color":
							var part := output_console.add_text(txt)
							var col_str: String = elem["color"]
							if col_str.ends_with("_bg"): # no handling for bg colors, just convert to fg
								col_str = col_str.substr(0,col_str.length()-3)
							match col_str:
								"red":
									part.color = Color.RED
								"green":
									part.color = Color.GREEN
								"yellow":
									part.color = Color.YELLOW
								"blue":
									part.color = Color.BLUE
								"magenta":
									part.color = Color.MAGENTA
								"cyan":
									part.color = Color.CYAN
								"white":
									part.color = Color.WHITE
								"bold":
									part.bold = true
								"underline":
									part.underline = true
			if output_console:
				output_console.add_linebreak()
			AP.log("[PRINT] %s" % s)
		"DataPackage":
			var packs = json["data"]["games"]
			for game in packs.keys():
				handle_datapack(game, packs[game])
			send_datapack_request()
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
				items.append(NetworkItem.from(obj, conn, true))
			for item in items:
				recieve_item(idx, item)
				idx += 1
		_: #TODO "LocationInfo","RoomUpdate","Bounced","Retrieved","SetReply","InvalidPacket"
			AP.log("[UNHANDLED PACKET TYPE] %s" % str(json))

#region DATAPACKS
class DataCache:
	var item_name_to_id: Dictionary = {}
	var location_name_to_id: Dictionary = {}
	var item_id_to_name: Dictionary = {}
	var location_id_to_name: Dictionary = {}
	var checksum: String = ""
	
	static func from(data: Dictionary) -> DataCache:
		var c = DataCache.new()
		c.item_name_to_id = data.get("item_name_to_id",c.item_name_to_id)
		c.location_name_to_id = data.get("location_name_to_id",c.location_name_to_id)
		c.checksum = data.get("checksum",c.checksum)
		for k in c.item_name_to_id.keys():
			c.item_id_to_name[int(c.item_name_to_id[k])] = k
		for k in c.location_name_to_id.keys():
			c.location_id_to_name[int(c.location_name_to_id[k])] = k
		return c
	static func from_file(file: FileAccess) -> DataCache:
		if not file: return null
		var dict = JSON.parse_string(file.get_as_text())
		if dict is Dictionary:
			return from(dict)
		return null
	func get_item_id(name:String) -> int:
		var id = item_name_to_id.get(name,-1)
		assert(id > -1)
		return id
	func get_loc_id(name:String) -> int:
		var id = location_name_to_id.get(name,-1)
		assert(id > -1)
		return id
	func get_item_name(id:int) -> String:
		return item_id_to_name.get(id, str(id))
	func get_loc_name(id:int) -> String:
		return location_id_to_name.get(id, str(id))
const READABLE_DATAPACK_FILES = true
const datapack_cached_fields = ["item_name_to_id","location_name_to_id","checksum"]
var datapack_cache: Dictionary
var datapack_pending: Array = []
signal all_datapacks_loaded
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
		match game: # TODO Temporary while Stardew's datapack is broken- stops other games from being broken too
			"Stardew Valley":
				pass
			_:
				datapack_pending.append(game)

func handle_datapack(game: String, data: Dictionary) -> void:
	var data_file := FileAccess.open("user://ap/datapacks/%s.json" % game, FileAccess.WRITE)
	datapack_cache[game] = {"checksum":data["checksum"],"fields":datapack_cached_fields.duplicate()}
	for key in data.keys():
		if not key in datapack_cached_fields:
			data.erase(key)
	data_file.store_string(JSON.stringify(data, "\t" if READABLE_DATAPACK_FILES else ""))
func send_datapack_request() -> void:
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
var _recieved_item_index := -1
func recieve_item(index: int, item: NetworkItem) -> void:
	assert(item.dest_player_id == conn.player_id)
	if index <= _recieved_item_index:
		return # Already recieved, skip
	var data := AP.get_datacache(AP_GAME_NAME)
	var msg := ""
	if item.dest_player_id == item.src_player_id:
		if output_console and printout_recieved_items:
			AP.out_player(output_console, conn.player_id, conn)
			output_console.add_text(" found their ")
			item.output(output_console, data)
			output_console.add_text(" (")
			AP.out_location(output_console, item.loc_id, data)
			output_console.add_text(")\n")
		msg = "You found your %s at %s!" % [data.get_item_name(item.id),data.get_loc_name(item.loc_id)]
		_remove_loc(item.loc_id)
	else:
		var src_data := conn.get_gamedata_for_player(item.src_player_id)
		if output_console and printout_recieved_items:
			conn.get_player(item.src_player_id).output(output_console)
			output_console.add_text(" sent ")
			item.output(output_console, data)
			output_console.add_text(" to ")
			AP.out_player(output_console, conn.player_id, conn)
			output_console.add_text(" (")
			AP.out_location(output_console, item.loc_id, src_data)
			output_console.add_text(")\n")
		msg = "%s found your %s at their %s!" % [conn.get_player_name(item.src_player_id), data.get_item_name(item.id), src_data.get_loc_name(item.loc_id)]
	
	#TODO actually handle recieving?
	AP.log(msg)
	
	_recieved_item_index = index
#endregion ITEMS

#region LOCATIONS
## Emitted when a location should be cleared/deleted from the world, as it has been "already collected"
signal _remove_location(loc_id: int)
var _removed_locs: Dictionary = {}
func _remove_loc(loc_id: int) -> void:
	if not _removed_locs.get(loc_id, false):
		_removed_locs[loc_id] = true
		_remove_location.emit(loc_id)
func _on_removed_id(loc_id: int, proc: Callable) -> void:
	if _removed_locs.get(loc_id, false):
		proc.call()
	else:
		_remove_location.connect(func(id:int):
			if id == loc_id:
				proc.call())
func on_removed(loc_name: String, proc: Callable) -> void:
	_on_removed_id(AP.get_datacache(AP_GAME_NAME).get_loc_id(loc_name), proc)

## Call when a location is collected and needs to be sent to the server.
func collect_location(loc_id: int) -> void:
	send_command("LocationChecks", {"locations":[loc_id]})
	_remove_loc(loc_id)
#endregion LOCATIONS
func _process(_delta):
	poll()

func _ready():  #TODO REMOVE TESTING
	ap_connect("archipelago.gg","54785","EmilySM")

func _exit_tree():
	if status != APStatus.DISCONNECTED:
		ap_disconnect()

func _notification(what):
	if what == NOTIFICATION_PREDELETE:
		print(logging_file)
		AP.close_logger()

#region DATACLASSES
class Version:
	var major := 0
	var minor := 0
	var build := 0
	
	static func from(json: Dictionary) -> Version:
		if json["class"] != "Version":
			return null
		var v := Version.new()
		v.major = json["major"]
		v.minor = json["minor"]
		v.build = json["build"]
		return v
	static func val(v1:int, v2:int, v3:int):
		var v = Version.new()
		v.major = v1
		v.minor = v2
		v.build = v3
		return v
	
	func _to_string():
		return "VER(%d.%d.%d)" % [major,minor,build]
	
	func compare(other: Version) -> int:
		if major != other.major:
			return major - other.major
		if minor != other.minor:
			return minor - other.minor
		return build - other.build
	
	func _as_ap_dict() -> Dictionary:
		return {"major":major,"minor":minor,"build":build,"class":"Version"}
class NetworkItem:
	var id: int
	var loc_id: int
	var src_player_id: int
	var dest_player_id: int
	var flags: int
	
	func get_classification() -> String:
		return AP.get_item_classification(flags)
	static func from(json: Dictionary, conn_info: ConnectionInfo, recv: bool) -> NetworkItem:
		if json["class"] != "NetworkItem":
			return null
		var v := NetworkItem.new()
		v.id = json["item"]
		v.loc_id = json["location"]
		v.src_player_id = json["player"] if recv else conn_info.player_id
		v.dest_player_id = conn_info.player_id if recv else json["player"]
		v.flags = json["flags"]
		return v
	
	func _to_string():
		return "ITEM(%d at %d,player %d->%d,flags %d)" % [id,loc_id,src_player_id,dest_player_id,flags]
	func output(console: CustomConsole, data: DataCache) -> void:
		AP.out_item(console, id, flags, data)
class NetworkPlayer:
	var team: int
	var slot: int
	var alias := ""
	var name : String
	
	var conn: ConnectionInfo
	func get_slot() -> NetworkSlot:
		return conn.slots[slot]
	func get_name(use_alias := true) -> String:
		var ret := ""
		if use_alias: ret = alias
		if not ret: ret = name
		return ret
	
	static func from(json: Dictionary, conn_info: ConnectionInfo) -> NetworkPlayer:
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
		v.conn = conn_info
		return v
	
	func _to_string():
		return "PLAYER(%s[%s],team %d,slot %d)" % [name,alias,team,slot]
	func output(console: CustomConsole) -> void:
		AP.out_player(console, slot, conn)
class NetworkSlot:
	var name : String
	var game: String
	var type: int #spectator = 0x00, player = 0x01, group = 0x02
	var group_members: Array[int] = []
	
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
		return "SLOT(%s[%s],type %d,members %s)" % [name,game,type,group_members]

#endregion DATACLASSES

#region CONSOLE

static func out_item(console: CustomConsole, id: int, flags: int, data: DataCache):
	if not console: return
	var ttip = "Type: %s" % AP.get_item_classification(flags)
	var color := COLOR_ITEM
	if flags&ICLASS_PROG:
		color = COLOR_ITEM_PROG
	elif flags&ICLASS_TRAP:
		color = COLOR_ITEM_TRAP
	console.add_text(data.get_item_name(id), ttip, color)
static func out_player(console: CustomConsole, id: int, conn_info: ConnectionInfo):
	if not console: return
	var player := conn_info.get_player(id)
	var ttip = "Game: %s" % conn_info.get_slot(id).game
	if not player.alias.is_empty():
		ttip += "\nName: %s" % player.name
	console.add_text(conn_info.get_player_name(id), ttip, COLOR_PLAYER)
static func out_location(console: CustomConsole, id: int, data: DataCache):
	var ttip = ""
	console.add_text(data.get_loc_name(id), ttip, COLOR_LOCATION)

var output_console: CustomConsole = null
func _open_console() -> void:
	if output_console: return
	var console_scene: Node = load("res://ui/console.tscn").instantiate()
	console_scene.title = "Archipelago Console"
	add_child(console_scene)
	await console_scene.ready
	output_console = console_scene.console
	output_console.send_text.connect(console_message)
	output_console.tree_exiting.connect(_close_console)
func _close_console() -> void:
	if output_console:
		output_console.close()
		output_console = null

func console_message(msg: String) -> void:
	if msg.is_empty(): return
	if msg[0] != "/": #Plain message
		send_command("Say", {"text":msg})
	else:
		var command_args = msg.split(" ", true, 1)
		print(command_args)
		var raw_args = msg.split(" ")
		var args: Array[String] = []
		var open_quote := false
		for s in raw_args:
			if open_quote:
				args[-1] += " " + s
			else: args.append(s)
			if s.count("\"") % 2:
				open_quote = not open_quote
		match command_args[0].to_lower():
			"/help":
				output_console.add_text("/help\n    Displays this message\n"
					+ "!help\n    Displays server-based command help\n"
					+ "/cls\n    Clears the console\n", "", COLOR_UI_MSG)
			"/cls":
				output_console.clear()
			"/db_send":
				if command_args.size() > 1:
					var data = AP.get_datacache(AP_GAME_NAME)
					for loc in _removed_locs:
						var loc_name := data.get_loc_name(loc)
						if loc_name.strip_edges().to_lower() == command_args[1].strip_edges().to_lower():
							if _removed_locs[loc]:
								output_console.add_text("Location already sent!\n", "", COLOR_UI_MSG)
							else:
								output_console.add_text("Sending location '%s'!\n" % loc_name, "", COLOR_UI_MSG)
								collect_location(loc)
							return
					output_console.add_text("Location '%s' not found! Check spelling?\n" % command_args[1].strip_edges(), "", COLOR_UI_MSG)
				else: output_console.add_text("Usage: '/db_send Some Location Name'", "", COLOR_UI_MSG)
			_:
				output_console.add_text("Unknown command '%s'\n" % command_args[0], "", COLOR_UI_MSG)
#endregion CONSOLE

func _init():
	_open_console()

const ICLASS_PROG := 0b001
const ICLASS_USEFUL := 0b010
const ICLASS_TRAP := 0b100
static func get_item_classification(flags: int) -> String:
	match flags:
		0b001:
			return "Progression"
		0b010:
			return "Useful"
		0b100:
			return "Trap"
		0b000:
			return "Filler"
		_:
			var s := ""
			for q in 3:
				if flags & (1<<q):
					if s:
						s += ","
					s += get_item_classification(1<<q)
			return s
