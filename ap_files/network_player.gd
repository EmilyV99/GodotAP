class_name NetworkPlayer

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
