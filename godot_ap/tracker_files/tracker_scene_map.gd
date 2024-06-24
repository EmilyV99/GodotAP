class_name TrackerScene_Map extends TrackerScene_Base

@onready var map: TextureRect = $MapImage

var image_path: String = ""
var map_id: String = ""
var datapack: TrackerPack_Data
var some_reachable_color: String = "gold"

signal item_register(name: String)

var offset: Vector2
var diff_scale: Vector2

var pins: Array[MapPin] = []
class MapPin extends Control:
	var base_pos: Vector2i
	var locs: Array[TrackerLocation] = []
	var parent: TrackerScene_Map
	func _process(_delta):
		position = parent.offset + (Vector2(base_pos) * parent.diff_scale) - size/2
		if locs.is_empty():
			queue_free()
			return
	func _draw():
		var statuses = {}
		for loc in locs:
			var stat = loc.get_status()
			statuses[stat] = statuses.get(stat, 0) + 1
		var cname = TrackerManager.get_status("Found").map_colorname
		for stat in locs[0]._iter_statuses(false):
			if stat.text in statuses:
				if stat.text == "Reachable":
					if statuses.keys().filter(func(s): return s != "Reachable" and s != "Found").size() > 0:
						cname = parent.some_reachable_color
						break
				cname = stat.map_colorname
				break
		var color = AP.color_from_name(cname)
		var rect := Rect2(Vector2.ZERO, size)
		draw_rect(rect, color)
		draw_rect(rect, Color.BLACK, false, 2)

func _ready() -> void:
	super()
	for itm in Archipelago.conn.received_items:
		item_register.emit(itm.get_name())
	Archipelago.conn.obtained_item.connect(func(itm: NetworkItem):
		item_register.emit(itm.get_name()))
	var image = datapack.load_image(image_path)
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	await get_tree().process_frame
	if image:
		map.texture = ImageTexture.create_from_image(image)
	else:
		map_id = ""
		for pin in pins:
			pin.queue_free()
		pins.clear()

## Refresh due to general status update (refresh everything)
## if `fresh_connection` is true, the tracker is just initializing
func refresh_tracker(fresh_connection: bool = false) -> void:
	if map_id.is_empty(): return
	if fresh_connection:
		var spot_dict := {}
		for loc in TrackerManager.locations.values():
			var track_loc: TrackerLocation = loc.loaded_tracker_loc
			if not track_loc: continue
			for spot in track_loc.map_spots:
				if spot.id == map_id:
					var arr = spot_dict.get(spot.pos)
					if arr:
						arr.append(track_loc)
					else: spot_dict[spot.pos] = [track_loc]
		for pos in spot_dict.keys():
			var pin := MapPin.new()
			pin.base_pos = pos
			pin.locs.assign(spot_dict[pos])
			pin.parent = self
			pin.custom_minimum_size = Vector2(10, 10)
			pins.append(pin)
			map.add_child(pin)
		on_resize()
	queue_redraw()

## Handle this node being resized; fit child nodes into place
func on_resize() -> void:
	var tex_size = map.texture.get_size()
	var targ_size := Vector2.ZERO
	if abs(tex_size.x - map.size.x) < abs(tex_size.y - map.size.y):
		targ_size.x = map.size.x
		targ_size.y = tex_size.y * (map.size.x / tex_size.x)
	else:
		targ_size.y = map.size.y
		targ_size.x = tex_size.x * (map.size.y / tex_size.y)
	var diff_sz = map.size - targ_size
	offset = diff_sz / 2
	diff_scale = Vector2(targ_size.x / tex_size.x, targ_size.y / tex_size.y)
	queue_redraw()

## Refresh due to item collection
func on_items_get(_items: Array[NetworkItem]) -> void:
	if datapack:
		refresh_tracker() # Accessibility can change

## Refresh due to location being checked
func on_loc_checked(_locid: int) -> void:
	queue_refresh()
