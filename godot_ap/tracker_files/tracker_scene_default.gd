class_name TrackerScene_Default extends TrackerScene_Base

@onready var console: BaseConsole = $Console/Cont/ConsoleMargin/Row/Console

const LOC_NAME_WIDTH := 1000
const LOC_STATUS_WIDTH := 500

var headings: Array[BaseConsole.TextPart]
var loc_container: BaseConsole.ContainerPart

var sort_ascending := [true,false]
var sort_cols := [1,0]

var accessibility_proc: Callable ## Callable[int]->bool, takes locid returns true if accessible

const ACCESSIBLE_ONLY = "[Only Reachable]"

var accessible_filter: bool = true
var status_filters: Dictionary = {
	NetworkHint.Status.FOUND: false,
}

class LocationPart extends BaseConsole.ColumnsPart: ## A part representing a hint info
	var loc: TrackerLocation
	
	func _init(tracker_loc: TrackerLocation):
		loc = tracker_loc
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
		parts.clear()
		var data := Archipelago.conn.get_gamedata_for_player()
		
		add(Archipelago.out_location(c, loc.id, data, false).centered(), LOC_NAME_WIDTH)
		add(NetworkHint.make_hint_status(c, loc.status).centered(), LOC_STATUS_WIDTH)

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
		if index == 0 and accessibility_proc.is_null():
			return false # Nothing to show
		var vbox := headings[index].pop_dropdown(console)
		if index != 0: # Only 1 checkbox on 0
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
			0: # Location Name
				var arr: Array = [ACCESSIBLE_ONLY]
				for s in arr:
					var hbox := GUI.make_cbox_row(s, accessible_filter,
						func(state: bool):
							accessible_filter = state
							queue_refresh())
					vbox.add_child(hbox)
			1: # Status
				var arr: Array = []
				arr.append_array(Util.reversed(NetworkHint.status_names.keys()))
				for s in arr:
					var hbox := GUI.make_cbox_row(s if s is String else NetworkHint.status_names[s],
						status_filters.get(s, true),
						func(state: bool):
							status_filters[s] = state
							queue_refresh())
					vbox.add_child(hbox)
		return true
	return false

func _ready() -> void:
	var header := BaseConsole.ColumnsPart.new()
	headings.append(header.add(console.make_c_text("Location Name"), LOC_NAME_WIDTH))
	headings.append(header.add(console.make_c_text("Status ↓"), LOC_STATUS_WIDTH))
	for q in headings.size():
		headings[q].on_click = func(evt): return sort_click(evt,q)
	console.add(header)
	loc_container = console.add(BaseConsole.ContainerPart.new())
	super()
	Archipelago.remove_location.connect(func(_id): queue_refresh())
	Archipelago.conn.set_hint_notify(func(_hints): queue_refresh())

## Refresh due to general status update (refresh everything)
## if `fresh_connection` is true, the tracker is just initializing
func refresh_tracker(fresh_connection: bool = false) -> void:
	if fresh_connection: # Generate the list
		loc_container.clear()
		if Archipelago.datapack_pending:
			await Archipelago.all_datapacks_loaded
		for locid in Archipelago.location_list():
			var new_part := LocationPart.new(TrackerTab.get_location(locid))
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
	pass # Optionally override this function

## Refresh due to location being checked
func on_loc_checked(_locid: int) -> void:
	pass # Optionally override this function

func filter_allow(part: LocationPart) -> bool:
	if accessible_filter and accessibility_proc.is_valid():
		if not accessibility_proc.call(part.loc.id):
			return false
	return status_filters.get(part.loc.status, true)
#region Sorting
var _sort_index_data: Dictionary = {}
func sort_by_name(a: LocationPart, b: LocationPart) -> int:
	return a.loc.name.naturalnocasecmp_to(b.loc.name)
func sort_by_status(a: LocationPart, b: LocationPart) -> int:
	return (a.loc.status - b.loc.status)
func sort_by_prev_index(a: LocationPart, b: LocationPart) -> int:
	return _sort_index_data.get(b, 99999) - _sort_index_data.get(a, 99999)

func do_sort(a: LocationPart, b: LocationPart) -> bool:
	var sorters = [sort_by_name,sort_by_status]
	for q in sort_cols.size():
		var c: int = sorters[sort_cols[q]].call(a,b)
		if c < 0: return sort_ascending[sort_cols[q]]
		elif c > 0: return not sort_ascending[sort_cols[q]]
	return sort_by_prev_index(a,b) >= 0
#endregion

func _update_label() -> void:
	_linked_label.text = "No game-specific tracker found. Showing default tracker."
