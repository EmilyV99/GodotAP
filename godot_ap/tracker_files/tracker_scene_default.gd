class_name TrackerScene_Default extends TrackerScene_Base

@onready var console: BaseConsole = $Console/Cont/ConsoleMargin/Row/Console

const COL_LOCATION := "Location Name"
const COL_HINT_STAT := "Hint Status"
const COL_LOC_STAT := "Status"

var headings: Array[BaseConsole.TextPart]
var loc_container: BaseConsole.ContainerPart

class ColumnData:
	var index: int
	var name: String
	var def_sort_ascending := true
	var sort_ascending := true
	var col_width: int = 200
	var sorter: Callable
	var filter: Callable
	func _init(headname: String, wid: int, ind: int, sort_proc: Callable, ascending := true):
		name = headname
		col_width = wid
		def_sort_ascending = ascending
		sort_ascending = ascending
		index = ind
		sorter = sort_proc
	func set_filter(filt: Callable) -> ColumnData:
		filter = filt
		return self
var cols_in_order := [ColumnData.new(COL_LOCATION,1000,0,sort_by_name),
	ColumnData.new(COL_HINT_STAT,500,1,sort_by_hint_status,false).set_filter(_hint_status_filter)]
var sort_cols := [cols_in_order[1],cols_in_order[0]]
var cols_by_name := {}

var show_hint_status := true

var hint_status_filters: Dictionary = {
	NetworkHint.Status.FOUND: false,
}
var status_filters: Dictionary = {}

class LocationPart extends BaseConsole.ArrangedColumnsPart: ## A part representing a Location
	var loc: APLocation
	var trackerpack: TrackerPack_Data
	var parent: TrackerScene_Default

	func _init(tracker_loc: APLocation, pack: TrackerPack_Data, parent_scene: TrackerScene_Default):
		loc = tracker_loc
		trackerpack = pack
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
		var data: DataCache = Archipelago.conn.get_gamedata_for_player()

		var locpart: BaseConsole.TextPart
		if parent.cols_by_name.has(COL_LOCATION):
			locpart = add(Archipelago.out_location(c, loc.id, data, false).centered(),parent.cols_by_name[COL_LOCATION].col_width)
		var dispname := loc.get_display_name()
		if dispname and locpart:
			locpart.tooltip = ("%s\n%s" % [locpart.text, locpart.tooltip]).strip_edges()
			locpart.text = dispname
		if parent.cols_by_name.has(COL_HINT_STAT):
			add(NetworkHint.make_hint_status(c, loc.hint_status).centered(), parent.cols_by_name[COL_HINT_STAT].col_width)
		if trackerpack and parent.cols_by_name.has(COL_LOC_STAT):
			var stat: String = TrackerManager.get_location(loc.id).get_status()
			var stats: Array = TrackerManager.statuses.filter(func(s): return s.text == stat)
			if stats:
				add(stats[0].make_c_text(c), parent.cols_by_name[COL_LOC_STAT].col_width)


func sort_click(event: InputEventMouseButton, column_name: String) -> bool:
	if not event.pressed: return false
	var column: ColumnData = cols_by_name[column_name]
	if event.button_index == MOUSE_BUTTON_LEFT:
		if sort_cols[0] == column:
			column.sort_ascending = not column.sort_ascending
			headings[column.index].text = headings[column.index].text.rstrip("↓↑") + ("↑" if column.sort_ascending else "↓")
		else:
			headings[sort_cols[0].index].text = headings[sort_cols[0].index].text.rstrip(" ↓↑")
			sort_cols.erase(column)
			sort_cols.push_front(column)
			column.sort_ascending = column.def_sort_ascending
			headings[column.index].text += (" ↑" if column.sort_ascending else " ↓")
		queue_refresh()
		return true
	elif event.button_index == MOUSE_BUTTON_RIGHT:
		if not cols_by_name[column_name].filter:
			return false # Nothing to show
		var vbox := headings[column.index].pop_dropdown(console)
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
		match column_name:
			COL_HINT_STAT:
				var arr: Array = []
				arr.append_array(Util.reversed(NetworkHint.status_names.keys()))
				for s in arr:
					var hbox := GUI.make_cbox_row(s if s is String else NetworkHint.status_names[s],
						hint_status_filters.get(s, true),
						func(state: bool):
							hint_status_filters[s] = state
							queue_refresh())
					vbox.add_child(hbox)
			COL_LOC_STAT:
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

func _init():
	super()
	for col in cols_in_order:
		cols_by_name[col.name] = col

## Refresh due to general status update (refresh everything)
## if `fresh_connection` is true, the tracker is just initializing
func refresh_tracker(fresh_connection: bool = false) -> void:
	if fresh_connection: # Generate the list
		if trackerpack:
			cols_in_order[0].col_width = -1
			cols_in_order[1].col_width = 120
			cols_in_order.append(ColumnData.new(COL_LOC_STAT, 120, 2, sort_by_loc_status, false).set_filter(_status_filter))
			cols_by_name[COL_LOC_STAT] = cols_in_order.back()
			for q in NetworkHint.Status.values():
				var statname: String = NetworkHint.status_names[q]
				var font := console.get_font()
				var sz := font.get_string_size(statname)
				cols_in_order[1].col_width = max(cols_in_order[1].col_width, sz.x)
			for stat in TrackerManager.statuses:
				var font := console.get_font()
				var sz := font.get_string_size(stat.text)
				cols_in_order[2].col_width = max(cols_in_order[2].col_width, sz.x)
			cols_in_order[1].col_width += 10
			cols_in_order[2].col_width += 10

			sort_cols.push_front(cols_in_order[2])

		var to_hide := [false, not show_hint_status, false]
		var header := BaseConsole.ArrangedColumnsPart.new()
		var ind := 0
		while ind < cols_in_order.size():
			if to_hide.pop_front():
				var colmn = cols_in_order.pop_at(ind)
				sort_cols.erase(colmn)
				cols_by_name.erase(colmn.name)
				continue
			var col = cols_in_order[ind]
			col.index = ind
			var heading = header.add(console.make_c_text(col.name), col.col_width)
			heading.on_click = func(evt): return sort_click(evt, col.name)
			headings.append(heading)
			ind += 1
		console.add(header)
		headings[sort_cols[0].index].text += (" ↑" if sort_cols[0].sort_ascending else " ↓")
		loc_container = console.add(BaseConsole.ContainerPart.new())
		Archipelago.conn.set_hint_notify(func(_hints): queue_refresh())

		await TrackerManager.on_tracker_load()
		for locid in Archipelago.location_list():
			var new_part := LocationPart.new(TrackerManager.get_location(locid), trackerpack, self)
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
	if trackerpack:
		queue_refresh() # Accessibility can change

## Refresh due to location being checked
func on_loc_checked(_locid: int) -> void:
	queue_refresh()

func _status_filter(part: LocationPart) -> bool:
	return not trackerpack or status_filters.get(part.loc.get_status(), true)
func _hint_status_filter(part: LocationPart) -> bool:
	return hint_status_filters.get(part.loc.hint_status, true)
func filter_allow(part: LocationPart) -> bool:
	for col in cols_in_order:
		if not col.filter: continue
		if not col.filter.call(part):
			return false
	return true
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
	for q in trackerpack.statuses.size():
		if trackerpack.statuses[q].text == astat:
			ai = q
		if trackerpack.statuses[q].text == bstat:
			bi = q
	return (ai - bi)
func sort_by_prev_index(a: LocationPart, b: LocationPart) -> int:
	return _sort_index_data.get(b, 99999) - _sort_index_data.get(a, 99999)

func do_sort(a: LocationPart, b: LocationPart) -> bool:
	for q in sort_cols.size():
		var c: int = sort_cols[q].sorter.call(a,b)
		if c < 0: return sort_cols[q].sort_ascending
		elif c > 0: return not sort_cols[q].sort_ascending
	return sort_by_prev_index(a,b) >= 0
#endregion
