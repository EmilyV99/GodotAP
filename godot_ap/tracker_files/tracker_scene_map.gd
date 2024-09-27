class_name TrackerScene_Map extends TrackerScene_Base

@onready var map: TextureRect = $MapImage

var image_path: String = ""
var map_id: String = ""
var some_reachable_color: String = "gold"

var offset: Vector2
var diff_scale: Vector2

var pins: Array[MapPin] = []
class MapPin extends Control:
	var base_pos: Vector2i
	var locs: Array[TrackerLocation] = []
	var parent: TrackerScene_Map

	var skipped := false
	var showing_ttip := false :
		set = show_tooltip

	var ttip: ColorRect = null

	func _ready():
		focus_mode = Control.FOCUS_CLICK
		mouse_filter = Control.MOUSE_FILTER_STOP
		mouse_entered.connect(func(): if not skipped: showing_ttip = true)
		mouse_exited.connect(func(): if not has_focus(): showing_ttip = false)
		focus_entered.connect(func(): showing_ttip = true)
		focus_exited.connect(func(): showing_ttip = false)
	func _process(_delta):
		position = parent.offset + (Vector2(base_pos) * parent.diff_scale) - size/2
		if locs.is_empty():
			queue_free()
			return
	func _draw():
		var statuses = {}
		for loc in locs:
			var stat = loc.get_status()
			if stat == "Found":
				continue
			statuses[stat] = statuses.get(stat, 0) + 1

		if Archipelago.config.hide_finished_map_squares and statuses.is_empty():
			skipped = true
			showing_ttip = false
			return
		skipped = false

		var c_status = "Found"
		for stat in locs[0]._iter_statuses(false):
			if stat.text in statuses:
				c_status = stat.text
				break
		var cname = TrackerManager.get_status(c_status).map_colorname
		if c_status == "Reachable":
			if statuses.keys().filter(func(s): return s != "Reachable" and s != "Found").size() > 0:
				cname = parent.some_reachable_color
		var color = AP.color_from_name(cname)
		var rect := Rect2(Vector2.ZERO, size)
		draw_rect(rect, color)
		draw_rect(rect, Color.BLACK, false, 2)

	func show_tooltip(val: bool) -> void:
		if showing_ttip == val: return
		showing_ttip = val
		if not val:
			if ttip:
				ttip.queue_free()
				ttip = null
			return
		ttip = ColorRect.new()
		ttip.top_level = true
		ttip.color = AP.color_from_name("black")

		var console: BaseConsole = load("res://godot_ap/ui/plain_console.tscn").instantiate()
		console.mouse_filter = Control.MOUSE_FILTER_IGNORE
		console.custom_minimum_size = Vector2(9999,9999)
		console.size = Vector2(9999,9999)
		var columns := BaseConsole.ColumnsPart.new()
		columns.add(1, console.make_spacing(Vector2(4,0)))
		for loc in locs:
			var stat := TrackerManager.get_status(loc.get_status())
			if Archipelago.config.hide_finished_map_squares and stat.text == "Found":
				continue
			columns.add(0, console.make_text(loc.get_loc_name() + ": ",
				"" if loc.descriptive_name.is_empty() else loc.get_loc().name,
				stat.map_colorname))
			columns.add(2, console.make_text(stat.text, stat.tooltip, stat.colorname))
		console.add(columns)
		console._calculate_hitboxes()
		console.custom_minimum_size = Vector2(console._draw_data.max_shown_x+8,console._draw_data.max_shown_y)
		ttip.custom_minimum_size = Vector2(console.custom_minimum_size.x + 8, console.custom_minimum_size.y + 8)



		ttip.add_child(console)
		parent.add_child(ttip)
		position_ttip()
		console.size = console.custom_minimum_size
		ttip.size = ttip.custom_minimum_size
		console.top_level = true
		console.position = ttip.position + Vector2(4,4)
	func position_ttip():
		if not ttip: return
		ttip.position.x = global_position.x + size.x/2 - ttip.size.x/2
		ttip.position.y = global_position.y + size.y
		while ttip.position.y + ttip.size.y > get_window().size.y:
			ttip.position.y -= 1
			if ttip.position.y < 0:
				ttip.position.y = 0
				break

## Refresh due to general status update (refresh everything)
## if `fresh_connection` is true, the tracker is just initializing
func refresh_tracker(fresh_connection: bool = false) -> void:
	if map_id.is_empty(): return
	if fresh_connection:
		var image = trackerpack.load_image(image_path)
		focus_mode = Control.FOCUS_CLICK
		mouse_filter = Control.MOUSE_FILTER_STOP
		if image:
			map.texture = ImageTexture.create_from_image(image)
		else:
			map_id = ""
			for pin in pins:
				pin.queue_free()
			pins.clear()

		var spot_dict := {}
		await TrackerManager.on_tracker_load()
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
	queue_redraw()
	for pin in pins:
		pin.queue_redraw()
	size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	size_flags_vertical = Control.SIZE_SHRINK_BEGIN

func _handle_sizing() -> Vector2:
	var tex_size = map.texture.get_size()
	var targ_size := Vector2.ZERO
	if abs(tex_size.x - map.size.x) < abs(tex_size.y - map.size.y):
		targ_size.x = map.size.x
		targ_size.y = tex_size.y * (map.size.x / tex_size.x)
	else:
		targ_size.y = map.size.y
		targ_size.x = tex_size.x * (map.size.y / tex_size.y)
	offset = Vector2.ZERO
	diff_scale = Vector2(targ_size.x / tex_size.x, targ_size.y / tex_size.y)
	return targ_size

func handle_sizing() -> void:
	map.custom_minimum_size = Vector2.ZERO
	map.size = get_parent().size
	var new_size = _handle_sizing()
	map.custom_minimum_size = new_size
	map.size = new_size
	size = new_size
func handle_sizing_2() -> void:
	map.custom_minimum_size = Vector2.ZERO

## Handle this node being resized; fit child nodes into place
func on_resize() -> void:
	queue_redraw()

## Refresh due to item collection
func on_items_get(_items: Array[NetworkItem]) -> void:
	queue_refresh()

## Refresh due to location being checked
func on_loc_checked(_locid: int) -> void:
	queue_refresh()
