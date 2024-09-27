class_name TrackerScene_ItemDefault extends TrackerScene_Base

@onready var console: BaseConsole = $Console/Cont/ConsoleMargin/Row/Console

const COL_INDEX := "Index"
const COL_VALUE := "Item/Value Name"
const COL_COUNT := "Count"
const COL_TOTAL := "Total"
const COL_PERC := "Percent"

var headings: Array[BaseConsole.TextPart]
var itm_container: BaseConsole.ContainerPart

var base_values: Array = []

class ColumnData:
	var index: int
	var name: String
	var def_sort_ascending := true
	var sort_ascending := true
	var col_width: int = 200
	var sorter: Callable
	var filter: Callable
	func _init(headname: String, wid: int, sort_proc: Callable, ascending := true):
		name = headname
		col_width = wid
		def_sort_ascending = ascending
		sort_ascending = ascending
		sorter = sort_proc
	func set_filter(filt: Callable) -> ColumnData:
		filter = filt
		return self
var cols_in_order := [ColumnData.new(COL_VALUE,1000,sort_by_name).set_filter(_item_class_filter),
	ColumnData.new(COL_COUNT,500,sort_by_count,false)]
var sort_cols := [cols_in_order[0],cols_in_order[1]]
var cols_by_name := {}

var show_index := true
var show_totals := true
var show_percent := true

var item_class_filters: Dictionary = {}

class ValuePart extends BaseConsole.ArrangedColumnsPart: ## A part representing a value that needs showing
	var name: String
	var visname := ""
	var index
	var parent: TrackerScene_ItemDefault

	var count_part: BaseConsole.TextPart
	var total_part: BaseConsole.TextPart
	var perc_part: BaseConsole.TextPart

	# NOTES: Must call `count()` before calling `tooltip()` or `colorname()` to ensure flags are updated

	func get_name():
		return name if visname.is_empty() else visname
	func _init(valname: String, parent_scene: TrackerScene_ItemDefault):
		name = valname
		parent = parent_scene
	func draw(c: BaseConsole, data: ConsoleDrawData) -> void:
		if dont_draw(): return
		if parts.is_empty():
			refresh(c)
		else: refr_counts()
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
	func refr_counts() -> void:
		if not (count_part or total_part or perc_part): return
		var cur_count = count()
		var cur_total = total()
		var cur_perc = percent()
		var cname = "green" if cur_count >= cur_total else ("red" if cur_count == 0 else "gold")
		var color := AP.color_from_name(cname)
		if count_part:
			if str(cur_count) != count_part.text:
				count_part.text = str(cur_count)
			count_part.color = color
		if total_part:
			var total_str = "?" if cur_total < 0 else str(cur_total)
			if total_str != total_part.text:
				total_part.text = total_str
			total_part.color = color
		if perc_part:
			var perc_str = "?" if cur_perc < 0 else str(cur_perc)
			if perc_str != perc_part.text:
				perc_part.text = perc_str
			perc_part.color = color
	func refresh(c: BaseConsole) -> void:
		clear()
		var cur_count = count()
		var cur_total = total()
		var cur_perc = percent()
		if parent.cols_by_name.has(COL_INDEX):
			add(c.make_c_text(str(index), "", AP.color_from_name("white")), parent.cols_by_name[COL_INDEX].col_width)
		if parent.cols_by_name.has(COL_VALUE):
			add(c.make_c_text(get_name(), tooltip(), AP.color_from_name(colorname())),
				parent.cols_by_name[COL_VALUE].col_width)
		var cname = "green" if cur_count >= cur_total else ("red" if cur_count == 0 else "gold")
		var color := AP.color_from_name(cname)
		if parent.cols_by_name.has(COL_COUNT):
			count_part = add(c.make_c_text(str(cur_count), "", color), parent.cols_by_name[COL_COUNT].col_width)
		if parent.cols_by_name.has(COL_TOTAL):
			total_part = add(c.make_c_text("?" if cur_total < 0 else
				str(cur_total), "", color), parent.cols_by_name[COL_TOTAL].col_width)
		if parent.cols_by_name.has(COL_PERC):
			perc_part = add(c.make_c_text("?" if cur_perc < 0 else
				str(cur_perc), "", color), parent.cols_by_name[COL_PERC].col_width)
	func count() -> int:
		return 0
	func total() -> int:
		return 0
	func percent() -> float:
		var t = total()
		if t < 0: return t # Error value
		if not t: return 100.0 # any of 0 is 100%, avoid div by 0
		return count() * 100.0 / t
	func tooltip() -> String:
		return ""
	func colorname() -> String:
		return "white"
class ItemPart extends ValuePart: ## A part representing an item that needs showing
	var specified_total: TrackerValueNode
	var default_flags: AP.ItemClassification
	var found_flags = null

	func _init(valname: String, parent_scene: TrackerScene_ItemDefault, def_flags := AP.ItemClassification.FILLER, spec_total: TrackerValueNode = null):
		super(valname, parent_scene)
		specified_total = spec_total if spec_total else TrackerValueInt.new(-1)
		default_flags = def_flags
	func count() -> int:
		var ret := 0
		found_flags = null
		for itm in Archipelago.conn.received_items:
			if itm.get_name() == name:
				ret += 1
				if found_flags == null:
					found_flags = itm.flags
				else:
					found_flags |= itm.flags
		return ret
	func total() -> int:
		return specified_total.calculate()
	func tooltip() -> String:
		return AP.get_item_classification(flags())
	func colorname() -> String:
		return AP.get_item_class_color(flags())
	func flags() -> AP.ItemClassification:
		return default_flags if found_flags == null else found_flags
class VariablePart extends ValuePart: ## A part representing a variable
	var count_value: TrackerValueNode
	var specified_total: TrackerValueNode
	var ttip: String = ""
	var display_color: String = "white"

	func _init(valname: String, parent_scene: TrackerScene_ItemDefault, count_node: TrackerValueNode, spec_total: TrackerValueNode = null):
		super(valname, parent_scene)
		count_value = count_node
		specified_total = spec_total if spec_total else TrackerValueInt.new(-1)
	func set_ttip(s: String) -> VariablePart:
		ttip = s
		return self
	func set_color(s: String) -> VariablePart:
		display_color = s
		return self

	func count() -> int:
		var ret = count_value.calculate()
		return ret if ret is int else 0
	func total() -> int:
		var ret = specified_total.calculate()
		return ret if ret is int else 0
	func tooltip() -> String:
		return ttip
	func colorname() -> String:
		return display_color

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
			COL_VALUE:
				var arr: Array[String] = []
				arr.append_array(item_class_filters.keys())
				arr.sort()
				for s in arr:
					var hbox := GUI.make_cbox_row(s,
						item_class_filters.get(s, true),
						func(state: bool):
							item_class_filters[s] = state
							queue_refresh())
					vbox.add_child(hbox)
		return true
	return false

func _init():
	super()
	for col in cols_in_order:
		cols_by_name[col.name] = col
	for flag in AP.ItemClassification.values():
		item_class_filters[AP.get_item_classification(flag)] = true
	item_class_filters["Non-Item"] = true

func _construct_values() -> void:
	itm_container.clear()
	var ind := 0
	for dict in base_values:
		var ty = dict.get("type")
		match ty:
			"ITEM":
				var part: ItemPart = itm_container._add(ItemPart.new(dict.get("name", "__ERROR__"),
					self, dict.get("flags", 0), TrackerValueNode.from_json_val(dict.get("total"))))
				part.visname = dict.get("visname", "")
				part.index = ind
				ind += 1
			"DISPLAY_VAR":
				var part: VariablePart = itm_container._add(VariablePart.new(dict.get("name", "__ERROR__"), self,
					TrackerValueNode.from_json_val(dict.get("count")), TrackerValueNode.from_json_val(dict.get("total"))) \
					.set_ttip(dict.get("tooltip", "")) \
					.set_color(dict.get("color", "white")))
				part.index = ind
				ind += 1
			_:
				assert(false) # should've been validated on load

## Refresh due to general status update (refresh everything)
## if `fresh_connection` is true, the tracker is just initializing
func refresh_tracker(fresh_connection: bool = false) -> void:
	if fresh_connection: # Generate the list
		cols_by_name[COL_VALUE].col_width = -1
		cols_by_name[COL_COUNT].col_width = 100
		if show_index: # Add index column
			cols_in_order.push_front(ColumnData.new(COL_INDEX, 100, sort_by_index))
			sort_cols.push_front(cols_in_order.front())
			cols_by_name[COL_INDEX] = cols_in_order.front()
		if show_totals: # Add totals column
			cols_in_order.append(ColumnData.new(COL_TOTAL, 100, sort_by_total, false))
			cols_by_name[COL_TOTAL] = cols_in_order.back()
			sort_cols.push_back(cols_in_order.back())
		if show_percent: # Add percent column
			cols_in_order.append(ColumnData.new(COL_PERC, 100, sort_by_percent, false))
			cols_by_name[COL_PERC] = cols_in_order.back()
			var found := false
			for q in sort_cols.size():
				if sort_cols[q].name == COL_COUNT:
					sort_cols.insert(q, cols_in_order.back())
					found = true
					break
			if not found:
				sort_cols.append(cols_in_order.back())
		if show_index: # Change default sorting
			sort_cols.erase(cols_by_name[COL_VALUE])
			sort_cols.append(cols_by_name[COL_VALUE])

		var header := BaseConsole.ArrangedColumnsPart.new()
		var ind := 0
		while ind < cols_in_order.size():
			var col = cols_in_order[ind]
			col.index = ind
			var heading = header.add(console.make_c_text(col.name), col.col_width)
			heading.on_click = func(evt): return sort_click(evt, col.name)
			headings.append(heading)
			ind += 1
		console.add(header)
		headings[sort_cols[0].index].text += (" ↑" if sort_cols[0].sort_ascending else " ↓")
		itm_container = console.add(BaseConsole.ContainerPart.new())
		await TrackerManager.on_tracker_load()
		_construct_values()
		await get_tree().process_frame
		console.scroll_by_abs(-console.scroll)
	console.is_max_scroll = false # Prevent force scroll-down
	for part in itm_container.parts:
		part.hidden = not filter_allow(part)
		part.refresh(console)

	_sort_index_data.clear()
	for q in itm_container.parts.size():
		_sort_index_data[itm_container.parts[q]] = q
	itm_container.parts.sort_custom(do_sort)

	console.queue_redraw()

## Handle this node being resized; fit child nodes into place
func on_resize() -> void:
	pass

## Refresh due to item collection
func on_items_get(_items: Array[NetworkItem]) -> void:
	queue_refresh()

## Refresh due to location being checked
func on_loc_checked(_locid: int) -> void:
	queue_refresh()

func _item_class_filter(part: ValuePart) -> bool:
	if part is ItemPart:
		for flag in AP.ItemClassification.values():
			var partflags = part.flags()
			if (flag & partflags) if flag else partflags == flag:
				if not item_class_filters.get(AP.get_item_classification(flag), true):
					return false
		return true
	return item_class_filters.get("Non-Item")
func filter_allow(part: ValuePart) -> bool:
	for col in cols_in_order:
		if not col.filter: continue
		if not col.filter.call(part):
			return false
	return true
#region Sorting
var _sort_index_data: Dictionary = {}
func sort_by_name(a: ValuePart, b: ValuePart) -> int:
	return a.get_name().naturalnocasecmp_to(b.get_name())
func sort_by_index(a: ValuePart, b: ValuePart) -> int:
	return (a.index - b.index)
func sort_by_count(a: ValuePart, b: ValuePart) -> int:
	return (a.count() - b.count())
func sort_by_total(a: ValuePart, b: ValuePart) -> int:
	return (a.total() - b.total())
func sort_by_percent(a: ValuePart, b: ValuePart) -> int:
	return roundi(a.percent() - b.percent())
func sort_by_prev_index(a: ValuePart, b: ValuePart) -> int:
	return _sort_index_data.get(b, 99999) - _sort_index_data.get(a, 99999)

func do_sort(a: ValuePart, b: ValuePart) -> bool:
	for q in sort_cols.size():
		var c: int = sort_cols[q].sorter.call(a,b)
		if c < 0: return sort_cols[q].sort_ascending
		elif c > 0: return not sort_cols[q].sort_ascending
	return sort_by_prev_index(a,b) >= 0
#endregion
