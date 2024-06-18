class_name APCredentials extends Node

var ip: String = "archipelago.gg"
var port: String = ""
var slot: String = ""
var pwd: String = ""

func read(file: FileAccess) -> bool:
	ip = file.get_line()
	port = file.get_line()
	slot = file.get_line()
	pwd = file.get_line()
	if file.get_error():
		return false
	return true
func write(file: FileAccess) -> bool:
	file.store_line(ip)
	file.store_line(port)
	file.store_line(slot)
	file.store_line(pwd)
	return true

func _to_string():
	return "APCREDS(%s:%s,%s,%s)" % [ip,port,slot,pwd]

