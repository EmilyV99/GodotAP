class_name AP extends Node

const AP_GAME_NAME := "Super Metroid"
const AP_GAME_TAGS: Array[String] = []
const AP_ITEM_HANDLING := ItemHandling.ALL
const AP_LOG_COMMUNICATION := false
const AP_LOG_RECIEVED := false
const COLOR_PLAYER: Color = Color8(238,0,238)
const COLOR_ITEM_PROG: Color = Color8(175,153,239)
const COLOR_ITEM: Color = Color8(1,234,234)
const COLOR_ITEM_TRAP: Color = Color.RED
const COLOR_LOCATION: Color = Color8(1,252,126)
const COLOR_SELF: Color = Color.GOLDENROD

enum ItemHandling {
	NONE = 0,
	OTHER = 1,
	OWN_OTHER = 3,
	STARTING_OTHER = 5,
	ALL = 7,
}

var creds: APCredentials :
	get:
		return Saves.open_save.creds
var aplock: APLock :
	get:
		return Saves.open_save.aplock

var socket := WebSocketPeer.new()

#region CONNECTION
var conn: ConnectionInfo

enum APStatus {
	DISCONNECTED,
	CONNECTING,
	CONNECTED,
	PLAYING, # 'Authenticated'
	DISCONNECTING,
}
signal status_updated
var queue_reconnect := false
var status: APStatus = APStatus.DISCONNECTED :
	set(val):
		if status != val:
			status = val
			status_updated.emit()
		if status == APStatus.DISCONNECTED:
			conn = null
			if queue_reconnect:
				queue_reconnect = false
				ap_reconnect()

var connecting_part: CustomConsole.TextPart

func ap_reconnect() -> void:
	if status != APStatus.DISCONNECTED:
		ap_disconnect()
		queue_reconnect = true
		return
	var attempts := 1
	var wss := true
	var url: String
	while true:
		url = "%s://%s:%s" % ["wss" if wss else "ws",creds.ip,creds.port]
		socket.close()
		var err := socket.connect_to_url(url)
		if err:
			AP.log("Connection to '%s' failed! Retrying (%d)" % [url,attempts])
			wss = not wss
			if wss: attempts += 1
		else: break
	AP.log("Connected to '%s'!" % url)
	if output_console:
		connecting_part = output_console.add_line("Connecting...","%s:%s %s" % [creds.ip,creds.port,creds.slot],output_console.COLOR_UI_MSG)
	status = APStatus.CONNECTING

func ap_connect(room_ip: String, room_port: String, slot_name: String, room_pwd := "") -> void:
	if status != APStatus.DISCONNECTED:
		ap_disconnect() # Do it here so the ip/port/slot are correct in the disconnect message
	AP.open_logger()
	creds.ip = room_ip
	creds.port = room_port
	creds.slot = slot_name
	creds.pwd = room_pwd
	ap_reconnect()

func ap_disconnect() -> void:
	if status == APStatus.DISCONNECTED or status == APStatus.DISCONNECTING:
		return
	status = APStatus.DISCONNECTING
	socket.close()
	AP.close_logger()
	if output_console:
		var part := output_console.add_line("Disconnecting...","%s:%s %s" % [creds.ip,creds.port,creds.slot],output_console.COLOR_UI_MSG)
		while status != APStatus.DISCONNECTED:
			await status_updated
		part.text = "Disconnected from AP.\n"
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
			if output_console and connecting_part:
				connecting_part.text = "Authenticating...\n"
			conn = ConnectionInfo.new()
			conn.serv_version = Version.from(json["version"])
			conn.gen_version = Version.from(json["generator_version"])
			conn.seed_name = json["seed_name"]
			handle_datapackage_checksums(json["datapackage_checksums"])
			var args: Dictionary = {"name":creds.slot,"password":creds.pwd,"uuid":conn.uid,
				"version":Version.val(0,4,6)._as_ap_dict(),"slot_data":true}
			args["game"] = AP_GAME_NAME
			args["tags"] = AP_GAME_TAGS
			args["items_handling"] = AP_ITEM_HANDLING
			send_command("Connect",args)
		"ConnectionRefused":
			var err_str := str(json["errors"])
			if output_console and connecting_part:
				connecting_part.text = "Connection Refused!\n"
				connecting_part.tooltip += "\nERROR(S): "+err_str
			AP.log("Connection errors: %s" % err_str)
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
			
			if aplock:
				var lock_err := aplock.lock(conn)
				if lock_err:
					connecting_part.text = "Connection Mismatch! Wrong slot for this save!\n"
					for s in lock_err:
						connecting_part.tooltip += "\n%s" % s
					ap_disconnect()
					return
			
			for loc in json["missing_locations"]:
				if not location_exists(loc):
					conn.checked_locations[loc as int] = false
					#Force this locations to be accessible?
			
			var server_checked = {}
			for loc in json["checked_locations"]:
				_remove_loc(loc)
				server_checked[loc] = true
			
			var to_collect: Array[int] = []
			for loc in conn.checked_locations.keys():
				if conn.checked_locations[loc] and not loc in server_checked:
					to_collect.append(loc)
			collect_locations(to_collect)
			
			# Deathlink stuff?
			# If deathlink stuff, possibly ConnectUpdate to add DeathLink tag?
			
			send_datapack_request()
			
			status = APStatus.PLAYING
			if output_console and connecting_part:
				connecting_part.text = "Connected Successfully!\n"
			
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
func recieve_item(index: int, item: NetworkItem) -> void:
	assert(item.dest_player_id == conn.player_id)
	if index <= conn.recieved_index:
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
			output_console.add_line(")")
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
			output_console.add_line(")")
		msg = "%s found your %s at their %s!" % [conn.get_player_name(item.src_player_id), data.get_item_name(item.id), src_data.get_loc_name(item.loc_id)]
	
	#TODO actually handle recieving?
	
	if AP_LOG_RECIEVED:
		AP.log(msg)
	
	conn.recieved_index = index
#endregion ITEMS

#region LOCATIONS
## Emitted when a location should be cleared/deleted from the world, as it has been "already collected"
signal _remove_location(loc_id: int)

func _remove_loc(loc_id: int) -> void:
	if conn and not conn.checked_locations.get(loc_id, false):
		conn.checked_locations[loc_id] = true
		_remove_location.emit(loc_id)
func _on_removed_id(loc_id: int, proc: Callable) -> void:
	if conn.checked_locations.get(loc_id, false):
		proc.call()
	else:
		_remove_location.connect(func(id:int):
			if id == loc_id:
				proc.call())
func on_removed(loc_name: String, proc: Callable) -> void:
	_on_removed_id(AP.get_datacache(AP_GAME_NAME).get_loc_id(loc_name), proc)

## Call when a location is collected and needs to be sent to the server.
func collect_location(loc_id: int) -> void:
	printout_recieved_items = false
	send_command("LocationChecks", {"locations":[loc_id]})
	_remove_loc(loc_id)
## Call when multiple locations are collected and need to be sent to the server at once.
func collect_locations(locs: Array[int]) -> void:
	printout_recieved_items = false
	send_command("LocationChecks", {"locations":locs})
	for loc_id in locs:
		_remove_loc(loc_id)

func location_exists(loc_id: int) -> bool:
	return conn.checked_locations.has(loc_id)
func location_checked(loc_id: int, def := false) -> bool:
	return conn.checked_locations.get(loc_id, def)
#endregion LOCATIONS
func _process(_delta):
	poll()

func ap_reconnect_to_save() -> void:
	if creds.slot.is_empty() or creds.port.length() != 5:
		if output_console:
			var s = "Connection details required! "
			if aplock.valid:
				s += "Please reconnect to the room previously used by this save file!"
			else:
				s += "Connect to a room when ready."
			output_console.add_line(s, "", output_console.COLOR_UI_MSG)
			var cmd = cmd_manager.get_command("/connect")
			if cmd:
				cmd.output_usage(output_console)
	else:
		ap_reconnect()

func _exit_tree():
	if status != APStatus.DISCONNECTED:
		ap_disconnect()

func _notification(what):
	if what == NOTIFICATION_PREDELETE:
		AP.close_logger()

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

var output_console_window: ConsoleWindow = null
var output_console: CustomConsole :
	get: return cmd_manager.console
	set(val): cmd_manager.console = val
func _open_console() -> void:
	if output_console: return
	output_console_window = load("res://ui/console.tscn").instantiate()
	output_console_window.title = "Archipelago Console"
	add_child(output_console_window)
	await output_console_window.ready
	output_console = output_console_window.console
	output_console.send_text.connect(cmd_manager.call_cmd)
	output_console.tree_exiting.connect(_close_console)
	output_console_window.typing_bar.cmd_manager = cmd_manager
func _close_console() -> void:
	if output_console:
		output_console.close()
		output_console = null

#endregion CONSOLE

var cmd_manager: CommandManager = CommandManager.new()
func _init():
	_open_console()
	cmd_manager.register_default(func(mgr: CommandManager, msg: String):
		if msg[0] == "/":
			mgr.console.add_line("Unknown command '%s' - use '/help' to see commands" % msg.split(" ", true, 1)[0], "", mgr.console.COLOR_UI_MSG)
		else:
			if status != APStatus.PLAYING:
				mgr.console.add_line("Not connected to Archipelago! Please '/connect' first!", "", mgr.console.COLOR_UI_MSG)
			else: send_command("Say", {"text":msg}))
	cmd_manager.register_command(ConsoleCommand.new("/connect")
		.add_help("port", "Connects to a new port, with the same ip/slot/password.")
		.add_help("ip:port", "Connects to a new ip+port, with the same slot/password.")
		.add_help("ip:port slot [pwd]", "Connects to a new ip+port, with a new slot and [optional] password.")
		.set_call(func(cmd: ConsoleCommand, msg: String):
			var command_args = msg.split(" ", true, 3)
			if command_args.size() == 2:
				command_args.append(creds.slot)
				command_args.append(creds.pwd)
			elif command_args.size() == 3:
				command_args.append("")
			if command_args.size() != 4:
				cmd.output_usage(output_console)
			else:
				var ipport = command_args[1].split(":",1)
				if ipport.size() == 1 and ipport[0].length() == 5:
					ipport = [creds.ip,ipport[0]]
				ap_connect(ipport[0],ipport[1],command_args[2],command_args[3])))
	cmd_manager.register_command(ConsoleCommand.new("/reconnect")
		.add_help("", "Refreshes the connection to the Archipelago server")
		.set_call(func(_cmd: ConsoleCommand, _msg: String): ap_reconnect()))
	cmd_manager.register_command(ConsoleCommand.new("/disconnect")
		.add_help("", "Kills the connection to the Archipelago server")
		.set_call(func(_cmd: ConsoleCommand, _msg: String): ap_disconnect()))
	#region Autofill for some AP commands
	cmd_manager.register_command(ConsoleCommand.new("!hint_location")
		.set_autofill(_autofill_locs))
	cmd_manager.register_command(ConsoleCommand.new("!hint")
		.set_autofill(_autofill_items))
	cmd_manager.register_command(ConsoleCommand.new("!help")
		.add_help("", "Displays server-based command help"))
	cmd_manager.register_command(ConsoleCommand.new("!remaining"))
	cmd_manager.register_command(ConsoleCommand.new("!missing"))
	cmd_manager.register_command(ConsoleCommand.new("!checked"))
	cmd_manager.register_command(ConsoleCommand.new("!collect"))
	cmd_manager.register_command(ConsoleCommand.new("!release"))
	cmd_manager.register_command(ConsoleCommand.new("!players"))
	#endregion Autofill for some AP commands
	cmd_manager.setup_basic_commands()
	if OS.is_debug_build():
		cmd_manager.register_command(ConsoleCommand.new("/send").debug()
			.add_help("", "Cheat-Collects the given location")
			.set_autofill(_autofill_locs)
			.set_call(func(cmd: ConsoleCommand, msg: String):
				var command_args = msg.split(" ", true, 1)
				if command_args.size() > 1 and command_args[1]:
					var data = AP.get_datacache(AP_GAME_NAME)
					for loc in conn.checked_locations.keys():
						var loc_name := data.get_loc_name(loc)
						if loc_name.strip_edges().to_lower() == command_args[1].strip_edges().to_lower():
							if conn.checked_locations[loc]:
								output_console.add_line("Location already sent!", "", output_console.COLOR_UI_MSG)
							else:
								output_console.add_line("Sending location '%s'!" % loc_name, "", output_console.COLOR_UI_MSG)
								collect_location(loc)
							return
					output_console.add_line("Location '%s' not found! Check spelling?" % command_args[1].strip_edges(), "", output_console.COLOR_UI_MSG)
				else: cmd.output_usage(output_console)))
		cmd_manager.register_command(ConsoleCommand.new("/lock_info").debug()
			.add_help("", "Prints the connection lock info")
			.set_call(func(_cmd: ConsoleCommand, _msg: String):
				if aplock:
					output_console.add_line("%s" % str(aplock), "", output_console.COLOR_UI_MSG)))
		cmd_manager.register_command(ConsoleCommand.new("/unlock_connection").debug()
			.add_help("", "Unlocks the connection lock, so that any valid slot can be connected to (instead of only the slot previously connected to)")
			.set_call(func(_cmd: ConsoleCommand, _msg: String):
				if aplock:
					aplock.unlock()))
		cmd_manager.register_command(ConsoleCommand.new("/save").debug()
			.add_help("[num]", "Saves the save file, optionally to a different-numbered slot. num >= 0.")
			.set_call(func(cmd: ConsoleCommand, msg: String):
				var command_args = msg.split(" ", true, 2)
				if command_args.size() == 1:
					Saves.save()
				elif command_args.size() != 2 or not command_args[1].is_valid_int() or int(command_args[1]) < 0:
					cmd.output_usage(output_console)
				else:
					Saves.write_save(int(command_args[1]))))
		cmd_manager.register_command(ConsoleCommand.new("/delsave").debug()
			.add_help("num", "Deletes the specified save file. num >= 0.")
			.set_call(func(cmd: ConsoleCommand, msg: String):
				var command_args = msg.split(" ", true, 2)
				if command_args.size() != 2 or not command_args[1].is_valid_int() or int(command_args[1]) < 0:
					cmd.output_usage(output_console)
				else:
					Saves.delete_save(int(command_args[1]))))
		cmd_manager.register_command(ConsoleCommand.new("/loadsave").debug()
			.add_help("num", "Loads the specified save file. num >= 0.")
			.set_call(func(_mgr: CommandManager, cmd: ConsoleCommand, msg: String):
				var command_args = msg.split(" ", true, 2)
				if command_args.size() != 2 or not command_args[1].is_valid_int() or int(command_args[1]) < 0:
					cmd.output_usage(output_console)
				else:
					var is_conn: bool = status != APStatus.DISCONNECTED
					if is_conn:
						ap_disconnect()
						while status != APStatus.DISCONNECTED:
							await status_updated
					Saves.read_save(int(command_args[1]))
					if is_conn:
						ap_reconnect_to_save()))
		cmd_manager.setup_debug_commands()
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

func _cmd_nil(_msg: String): pass
func _autofill_locs(msg: String) -> Array[String]:
	var args = msg.split(" ", true, 1)
	var data: DataCache = AP.get_datacache(AP_GAME_NAME)
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
	var args = msg.split(" ", true, 1)
	var data: DataCache = AP.get_datacache(AP_GAME_NAME)
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
