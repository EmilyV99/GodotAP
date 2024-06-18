class_name APCredentials extends Node

signal updated(creds: APCredentials)

var ip: String = "archipelago.gg"
var port: String = "" :
	get:
		if port.is_empty():
			return "38281"
		return  port
var slot: String = ""
var pwd: String = ""

func read(file: FileAccess) -> bool:
	var new_strs = [file.get_line(),file.get_line(),file.get_line(),file.get_line()]
	if file.get_error():
		return false
	ip = new_strs[0]
	port = new_strs[1]
	slot = new_strs[2]
	pwd = new_strs[3]
	updated.emit(self)
	return true
func write(file: FileAccess) -> bool:
	file.store_line(ip)
	file.store_line(port)
	file.store_line(slot)
	file.store_line(pwd)
	return true

func update(nip: String, nport: String, nslot: String, npwd: String = ""):
	ip = nip
	port = nport
	slot = nslot
	pwd = npwd
	updated.emit(self)

func _to_string():
	return "APCREDS(%s:%s,%s,%s)" % [ip,port,slot,pwd]

