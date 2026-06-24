class_name DataCache
## Item and location names for a game.

## A [Dictionary] mapping item names to their numerical IDs.
var item_name_to_id: Dictionary[String, int] = {}
## A [Dictionary] mapping location names to their numerical IDs.
var location_name_to_id: Dictionary[String, int] = {}
## Checksum for the data.
var checksum: String = ""


## Load data cache from a [Dictionary].
static func from(data: Dictionary) -> DataCache:
	var c := DataCache.new()
	
	c.item_name_to_id.assign(data.get("item_name_to_id", c.item_name_to_id))
	for k in c.item_name_to_id.keys():
		c.item_name_to_id[k] = c.item_name_to_id[k] as int
	
	c.location_name_to_id.assign(data.get("location_name_to_id", c.location_name_to_id))
	for k in c.location_name_to_id.keys():
		c.location_name_to_id[k] = c.location_name_to_id[k] as int
		
	c.checksum = data.get("checksum",c.checksum)
	return c


## Load data cache from [param file].
static func from_file(file: FileAccess) -> DataCache:
	if not file:
		return null
	var dict = JSON.parse_string(file.get_as_text())
	if dict is Dictionary:
		return from(dict)
	return null


## Get the ID for the [param name] of an item.
func get_item_id(name: String) -> int:
	var id: int = item_name_to_id.get(name, -1)
	return id


## Get the ID for the [param name] of a location.
func get_loc_id(name: String) -> int:
	var id: int = location_name_to_id.get(name, -1)
	return id


## Get the name of the item with the given [param id].
func get_item_name(id: int) -> String:
	var v: Variant = item_name_to_id.find_key(id)
	return str(v) if v else str(id)


## Get the location of the item with the given [param id].
func get_loc_name(id: int) -> String:
	if id < 0:
		if id == -1:
			return "Server"
		if id == -2:
			return "Starting Inventory"
		return "??? #%d" % id
	var v: Variant = location_name_to_id.find_key(id)
	return str(v) if v else str(id)


## Check the validity of this cache.
func is_valid() -> bool:
	return not checksum.is_empty()
