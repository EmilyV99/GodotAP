class_name SaveFile
## GodotAP connection & session save file.

## A room lock, preventing the save from connecting to the wrong room once locked.
var aplock: APLock = APLock.new()
## Room connection information.
var creds: APCredentials = APCredentials.new()


## Read save from file on disk. Returns [code]true[/code] if successful, [code]false[/code]
## otherwise.
func read(file: FileAccess) -> bool:
	if not aplock.read(file):
		return false
	if not creds.read(file):
		return false
	if file.get_error():
		return false
	return true


## Write save to file on disk. Returns [code]true[/code] if successful, [code]false[/code]
## otherwise.
func write(file: FileAccess) -> bool:
	if not aplock.write(file):
		return false
	if not creds.write(file):
		return false
	return true


## Clear currently loaded save information.
func clear() -> void:
	aplock = APLock.new()
	creds = APCredentials.new()
