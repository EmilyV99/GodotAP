class_name APLock 
extends Node
## Data unique to a room connection, locking a save to only connect to the same room.

## Whether or not the lock is valid.
var valid: bool = false
## The ID of the player.
var player_id: int = 0
## The ID of the team.
var team_id: int = 0
## The name of the slot the player connects to.
var slot_name: String = ""
## The name of the seed.
var seed_name: String = ""


## Check if [param conn] meets the requirements of this lock. Returns an array containing any
## invalid parameters on the connection. If everything matches the array will be empty.
## [br][br]
## If [member valid] is [code]false[/code] all members will be set to the values of [param conn].
func lock(conn: ConnectionInfo) -> Array[String]:
	if not valid:
		player_id = conn.player_id
		team_id = conn.team_id
		slot_name = conn.get_slot(player_id).name
		seed_name = conn.seed_name
		valid = true
		return []
	var ret: Array[String] = []
	if player_id != conn.player_id:
		ret.append("Wrong player_id: %d != %d" % [player_id, conn.player_id])
	if team_id != conn.team_id:
		ret.append("Wrong team_id: %d != %d" % [team_id, conn.team_id])
	if slot_name != conn.get_slot(player_id).name:
		ret.append("Wrong slot_name: %s != %s" % [slot_name, conn.get_slot(player_id).name])
	if seed_name != conn.seed_name:
		ret.append("Wrong seed_name: %s != %s" % [seed_name, conn.seed_name])
	return ret


## Release the lock, invalidating it.
func unlock() -> void:
	valid = false


## Read lock information from [param file]. Returns [code]false[/code] if errors occur reading
## from [param file], and [code]true[/code] otherwise, even if the lock isn't valid.
func read(file: FileAccess) -> bool:
	valid = file.get_8()
	if not valid:
		return true
	player_id = file.get_32()
	team_id = file.get_32()
	slot_name = file.get_line()
	seed_name = file.get_line()
	if file.get_error():
		return false
	return true


## Write lock information to [param file].
func write(file: FileAccess) -> bool:
	file.store_8(1 if valid else 0)
	if not valid:
		return true
	file.store_32(player_id)
	file.store_32(team_id)
	file.store_line(slot_name)
	file.store_line(seed_name)
	return true


func _to_string():
	if not valid:
		return "APLOCK()"
	return "APLOCK(%d,%d,%s,%s)" % [player_id, team_id, slot_name, seed_name]
