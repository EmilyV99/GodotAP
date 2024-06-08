class_name NetworkSlot

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
