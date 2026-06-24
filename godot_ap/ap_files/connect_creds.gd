class_name APCredentials
extends Node
## Credentials for connecting to an Archipelago room

## Emits updated credentials when credentials are changed.
signal updated(creds: APCredentials)

## The host to connect to.
var ip: String = "archipelago.gg"
## The port to connect to. If left empty will default to [code]"38281"[/code].
var port: String = "" :
	get:
		if port.is_empty():
			return "38281"
		return port
## The slot name to connect to.
var slot: String = ""
## The room password.
var pwd: String = ""


## Read saved credentials from [param file].
func read(file: FileAccess) -> bool:
	var new_strs = [file.get_line(), file.get_line(), file.get_line(), file.get_line()]
	if file.get_error():
		return false
	ip = new_strs[0]
	port = new_strs[1]
	slot = new_strs[2]
	pwd = new_strs[3]
	updated.emit(self)
	return true


## Write credentials to [param file].
func write(file: FileAccess) -> bool:
	file.store_line(ip)
	file.store_line(port)
	file.store_line(slot)
	file.store_line(pwd)
	return true


## Update credentials.
func update(nip: String, nport: String, nslot: String, npwd: String = ""):
	ip = nip
	port = nport
	slot = nslot
	pwd = npwd
	updated.emit(self)


func _to_string():
	return "APCREDS(%s:%s,%s,%s)" % [ip, port, slot, pwd]
