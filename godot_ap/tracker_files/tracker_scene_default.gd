class_name TrackerScene_Default extends TrackerScene_Base

@onready var console: BaseConsole = $Console/Cont/ConsoleMargin/Row/Console

var headings: Array[BaseConsole.TextPart]
var loc_container: BaseConsole.ContainerPart

var sort_ascending := [true,false]
var sort_cols := [1,0]

var width_arr := []

var datapack: TrackerPack_Data

var show_hint_status := true

var hint_status_filters: Dictionary = {
	NetworkHint.Status.FOUND: false,
}
var status_filters: Dictionary = {}

signal item_register(name: String)
class LocationPart extends BaseConsole.ArrangedColumnsPart: ## A part representing a hint info
	var loc: APLocation
	var datapack: TrackerPack_Data
	var parent: TrackerScene_Default
	
	func _init(tracker_loc: APLocation, pack: TrackerPack_Data, parent_scene: TrackerScene_Default):
		loc = tracker_loc
		datapack = pack
		parent = parent_scene
	func draw(c: BaseConsole, data: ConsoleDrawData) -> void:
		if dont_draw(): return
		if parts.is_empty():
			refresh(c)
		var vspc = c.get_line_height()/4
		data.ensure_spacing(c, Vector2(0, vspc))
		super(c, data)
		for part in parts:
			if part is TextPart and not part.hitboxes.is_empty():
				var top_hb = part.hitboxes.front()
				top_hb.position.y -= vspc/2
				top_hb.size.y += vspc/2
				part.hitboxes[0] = top_hb
				var bot_hb = part.hitboxes.back()
				bot_hb.size.y += vspc/2
				part.hitboxes[-1] = bot_hb
	func refresh(c: BaseConsole) -> void:
		loc.refresh()
		clear()
		var data := Archipelago.conn.get_gamedata_for_player()
		
		var locpart: BaseConsole.TextPart = add(Archipelago.out_location(c, loc.id, data, false).centered(),parent.width_arr[0])
		var dispname := loc.get_display_name()
		if dispname:
			locpart.tooltip = ("%s\n%s" % [locpart.text, locpart.tooltip]).strip_edges()
			locpart.text = dispname
		if parent.show_hint_status:
			add(NetworkHint.make_hint_status(c, loc.hint_status).centered(), parent.width_arr[1])
		if datapack:
			var stat: String = TrackerManager.get_location(loc.id).get_status()
			var stats: Array = TrackerManager.statuses.filter(func(s): return s.text == stat)
			if stats:
				add(stats[0].make_c_text(c), parent.width_arr[2])
		

func sort_click(event: InputEventMouseButton, index: int) -> bool:
	if not event.pressed: return false
	if event.button_index == MOUSE_BUTTON_LEFT:
		if sort_cols[0] == index:
			sort_ascending[index] = not sort_ascending[index]
			headings[index].text = headings[index].text.rstrip("↓↑") + ("↑" if sort_ascending[index] else "↓")
		else:
			headings[sort_cols[0]].text = headings[sort_cols[0]].text.rstrip(" ↓↑")
			sort_cols.erase(index)
			sort_cols.push_front(index)
			sort_ascending[index] = index != 1
			headings[index].text += (" ↑" if sort_ascending[index] else " ↓")
		queue_refresh()
		return true
	elif event.button_index == MOUSE_BUTTON_RIGHT:
		if index == 0:
			return false # Nothing to show
		var vbox := headings[index].pop_dropdown(console)
		# Create action buttons
		var btnrow := HBoxContainer.new()
		var btn_checkall := Button.new()
		btn_checkall.text = "Check All"
		btn_checkall.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		btn_checkall.pressed.connect(func():
			Util.for_all_nodes(vbox, func(node: Node):
				if node is CheckBox:
					node.button_pressed = true))
		var btn_uncheckall := Button.new()
		btn_uncheckall.text = "Uncheck All"
		btn_uncheckall.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		btn_uncheckall.pressed.connect(func():
			Util.for_all_nodes(vbox, func(node: Node):
				if node is CheckBox:
					node.button_pressed = false))
		btnrow.add_child(btn_checkall)
		btnrow.add_child(btn_uncheckall)
		vbox.add_child(btnrow)
		# Add filter options
		match index:
			1: # Status
				var arr: Array = []
				arr.append_array(Util.reversed(NetworkHint.status_names.keys()))
				for s in arr:
					var hbox := GUI.make_cbox_row(s if s is String else NetworkHint.status_names[s],
						hint_status_filters.get(s, true),
						func(state: bool):
							hint_status_filters[s] = state
							queue_refresh())
					vbox.add_child(hbox)
			2: # Location Status
				var arr: Array = []
				arr.append_array(Util.reversed(TrackerManager.statuses))
				for s in arr:
					var hbox := GUI.make_cbox_row(s.text,
						status_filters.get(s.text, true),
						func(state: bool):
							status_filters[s.text] = state
							queue_refresh())
					vbox.add_child(hbox)
		return true
	return false

func _ready() -> void:
	width_arr.assign([1000, 500])
	var titles := ["Location Name", "Hint Status"]
	
	if datapack:
		width_arr.assign([-1, 120, 120])
		for q in NetworkHint.Status.values():
			var statname: String = NetworkHint.status_names[q]
			var font := console.get_font()
			var sz := font.get_string_size(statname)
			width_arr[1] = max(width_arr[1], sz.x)
		for stat in TrackerManager.statuses:
			var font := console.get_font()
			var sz := font.get_string_size(stat.text)
			width_arr[2] = max(width_arr[2], sz.x)
		width_arr[1] += 10
		width_arr[2] += 10
		
		titles.append("Status")
		sort_ascending.append(false)
		sort_cols.push_front(2)
	
	titles[sort_cols[0]] += " ↓"
	var to_hide := [false, not show_hint_status, false]
	var header := BaseConsole.ArrangedColumnsPart.new()
	for q in width_arr.size():
		if to_hide[q]: continue
		var heading = header.add(console.make_c_text(titles[q]), width_arr[q])
		heading.on_click = func(evt): return sort_click(evt,q)
		headings.append(heading)
	console.add(header)
	loc_container = console.add(BaseConsole.ContainerPart.new())
	super()
	Archipelago.conn.set_hint_notify(func(_hints): queue_refresh())
	
	for itm in Archipelago.conn.received_items:
		item_register.emit(itm.get_name())
	Archipelago.conn.obtained_item.connect(func(itm: NetworkItem):
		item_register.emit(itm.get_name()))

## Refresh due to general status update (refresh everything)
## if `fresh_connection` is true, the tracker is just initializing
func refresh_tracker(fresh_connection: bool = false) -> void:
	if fresh_connection: # Generate the list
		loc_container.clear()
		if Archipelago.datapack_pending:
			await Archipelago.all_datapacks_loaded
		for locid in Archipelago.location_list():
			var new_part := LocationPart.new(TrackerManager.get_location(locid), datapack, self)
			loc_container._add(new_part)
		await get_tree().process_frame
		console.scroll_by_abs(-console.scroll)
	console.is_max_scroll = false # Prevent force scroll-down
	for part in loc_container.parts:
		part.hidden = not filter_allow(part)
		part.refresh(console)
	
	_sort_index_data.clear()
	for q in loc_container.parts.size():
		_sort_index_data[loc_container.parts[q]] = q
	loc_container.parts.sort_custom(do_sort)
	
	console.queue_redraw()

## Handle this node being resized; fit child nodes into place
func on_resize() -> void:
	pass

## Refresh due to item collection
func on_items_get(_items: Array[NetworkItem]) -> void:
	if datapack:
		refresh_tracker() # Accessibility can change

## Refresh due to location being checked
func on_loc_checked(_locid: int) -> void:
	queue_refresh()

func filter_allow(part: LocationPart) -> bool:
	if datapack:
		if not status_filters.get(part.loc.get_status(), true):
			return false
	return hint_status_filters.get(part.loc.hint_status, true)
#region Sorting
var _sort_index_data: Dictionary = {}
func sort_by_name(a: LocationPart, b: LocationPart) -> int:
	return a.loc.name.naturalnocasecmp_to(b.loc.name)
func sort_by_hint_status(a: LocationPart, b: LocationPart) -> int:
	return (a.loc.hint_status - b.loc.hint_status)
func sort_by_loc_status(a: LocationPart, b: LocationPart) -> int:
	var ai := -1
	var bi := -1
	var astat: String = a.loc.get_status()
	var bstat: String = b.loc.get_status()
	for q in datapack.statuses.size():
		if datapack.statuses[q].text == astat:
			ai = q
		if datapack.statuses[q].text == bstat:
			bi = q
	return (ai - bi)
func sort_by_prev_index(a: LocationPart, b: LocationPart) -> int:
	return _sort_index_data.get(b, 99999) - _sort_index_data.get(a, 99999)

func do_sort(a: LocationPart, b: LocationPart) -> bool:
	var sorters = [sort_by_name,sort_by_hint_status,sort_by_loc_status]
	for q in sort_cols.size():
		var c: int = sorters[sort_cols[q]].call(a,b)
		if c < 0: return sort_ascending[sort_cols[q]]
		elif c > 0: return not sort_ascending[sort_cols[q]]
	return sort_by_prev_index(a,b) >= 0
#endregion
