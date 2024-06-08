class_name SaveFile

var aplock: APLock = APLock.new()

func read(file: FileAccess) -> bool:
	if not aplock.read(file):
		return false
	return true

func write(file: FileAccess) -> bool:
	if not aplock.write(file):
		return false
	return true
