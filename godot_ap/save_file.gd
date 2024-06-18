class_name SaveFile

var aplock: APLock = APLock.new()
var creds: APCredentials = APCredentials.new()

func read(file: FileAccess) -> bool:
	if not aplock.read(file):
		return false
	if not creds.read(file):
		return false
	if file.get_error():
		return false
	return true

func write(file: FileAccess) -> bool:
	if not aplock.write(file):
		return false
	if not creds.write(file):
		return false
	return true

func clear() -> void:
	aplock = APLock.new()
	creds = APCredentials.new()
