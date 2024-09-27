class_name HintsTab extends MarginContainer

@onready var hint_console: BaseConsole = $Console.console

var hint_container: BaseConsole.ContainerPart
var headings: Array[BaseConsole.TextPart]

var sort_ascending := [true,true,true,true,false]
var sort_cols := [4,0,2,1,3]

const FORCE_ALL := "[Force All]"
const LOCAL_ITEMS := "[Local Items]"
const ITEMS_PROG := "[Progression]"
const ITEMS_USEFUL := "[Useful]"
const ITEMS_TRAP := "[Trap]"
const ITEMS_FILLER := "[Filler]"
var status_filters: Dictionary = {
	FORCE_ALL: false,
	NetworkHint.Status.FOUND: false,
}
var recv_filters: Dictionary = {}
var finding_filters: Dictionary = {}
var item_filters: Dictionary = {}
var loc_filters: Dictionary = {}

var old_status_system := false

var _sort_index_data: Dictionary = {}
func sort_by_dest(a: NetworkHint, b: NetworkHint) -> int:
	return (Archipelago.conn.get_player_name(a.item.dest_player_id).nocasecmp_to(
		Archipelago.conn.get_player_name(b.item.dest_player_id)))
func sort_by_item(a: NetworkHint, b: NetworkHint) -> int:
	var a_data := Archipelago.conn.get_gamedata_for_player(a.item.src_player_id)
	var b_data := Archipelago.conn.get_gamedata_for_player(b.item.src_player_id)
	return (a_data.get_item_name(a.item.id).nocasecmp_to(
		b_data.get_item_name(b.item.id)))
func sort_by_src(a: NetworkHint, b: NetworkHint) -> int:
	return (Archipelago.conn.get_player_name(a.item.src_player_id).nocasecmp_to(
		Archipelago.conn.get_player_name(b.item.src_player_id)))
func sort_by_loc(a: NetworkHint, b: NetworkHint) -> int:
	var a_data := Archipelago.conn.get_gamedata_for_player(a.item.src_player_id)
	var b_data := Archipelago.conn.get_gamedata_for_player(b.item.src_player_id)
	return (a_data.get_loc_name(a.item.loc_id).nocasecmp_to(
		b_data.get_loc_name(b.item.loc_id)))
func sort_by_status(a: NetworkHint, b: NetworkHint) -> int:
	return (a.status - b.status)
func sort_by_prev_index(a: NetworkHint, b: NetworkHint) -> int:
	return _sort_index_data.get(b, 99999) - _sort_index_data.get(a, 99999)

func do_sort(a: NetworkHint, b: NetworkHint) -> bool:
	var sorters = [sort_by_dest,sort_by_item,sort_by_src,sort_by_loc,sort_by_status]
	for q in sort_cols.size():
		var c: int = sorters[sort_cols[q]].call(a,b)
		if c < 0: return sort_ascending[sort_cols[q]]
		elif c > 0: return not sort_ascending[sort_cols[q]]
	return sort_by_prev_index(a,b) >= 0

func _status_filter(s: NetworkHint.Status) -> bool:
	match s:
		NetworkHint.Status.FOUND: return true
		NetworkHint.Status.NOT_FOUND: return old_status_system
		_: return not old_status_system

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
			sort_ascending[index] = index != 4
			headings[index].text += (" ↑" if sort_ascending[index] else " ↓")
		queue_refresh()
		return true
	elif event.button_index == MOUSE_BUTTON_RIGHT:
		var vbox := headings[index].pop_dropdown(hint_console)
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
			0: # Receiving Player
				var arr: Array = [LOCAL_ITEMS]
				arr.append_array(recv_filters.keys().filter(func(s): return not s in arr))
				for s in arr:
					var proc: Callable
					if s == LOCAL_ITEMS:
						proc = func(state: bool):
							recv_filters[s] = state
							finding_filters[s] = state # Shared option
							queue_refresh()
					else:
						proc = func(state: bool):
							recv_filters[s] = state
							queue_refresh()
					var hbox := GUI.make_cbox_row(s, recv_filters.get(s, true), proc)
					vbox.add_child(hbox)
			1: # Item
				var arr: Array = [ITEMS_FILLER,ITEMS_TRAP,ITEMS_USEFUL,ITEMS_PROG]
				arr.append_array(item_filters.keys().filter(func(s): return not s in arr))
				for s in arr:
					var hbox := GUI.make_cbox_row(s, item_filters.get(s, true), func(state: bool):
						item_filters[s] = state
						queue_refresh())
					vbox.add_child(hbox)
			2: # Finding Player
				var arr: Array = [LOCAL_ITEMS]
				arr.append_array(finding_filters.keys().filter(func(s): return not s in arr))
				for s in arr:
					var proc: Callable
					if s == LOCAL_ITEMS:
						proc = func(state: bool):
							finding_filters[s] = state
							recv_filters[s] = state # Shared option
							queue_refresh()
					else:
						proc = func(state: bool):
							finding_filters[s] = state
							queue_refresh()
					var hbox := GUI.make_cbox_row(s, finding_filters.get(s, true), proc)
					vbox.add_child(hbox)
			3: # Location
				var arr: Array = loc_filters.keys()
				for s in arr:
					var hbox := GUI.make_cbox_row(s, loc_filters.get(s, true), func(state: bool):
						loc_filters[s] = state
						queue_refresh())
					vbox.add_child(hbox)
			4: # Status
				var arr: Array = [FORCE_ALL]
				arr.append_array(Util.reversed(NetworkHint.status_names.keys()).filter(_status_filter))
				for s in arr:
					var hbox := GUI.make_cbox_row(s if s is String else NetworkHint.status_names[s],
						status_filters.get(s, true),
						func(state: bool):
							status_filters[s] = state
							queue_refresh())
					vbox.add_child(hbox)
		return true
	return false

func reset_hints_to_empty() -> void:
	recv_filters = {
		LOCAL_ITEMS: recv_filters.get(LOCAL_ITEMS, true),
	}
	finding_filters = {
		LOCAL_ITEMS: finding_filters.get(LOCAL_ITEMS, true),
	}
	item_filters = {
		ITEMS_PROG: item_filters.get(ITEMS_PROG, true),
		ITEMS_USEFUL: item_filters.get(ITEMS_USEFUL, true),
		ITEMS_TRAP: item_filters.get(ITEMS_TRAP, true),
		ITEMS_FILLER: item_filters.get(ITEMS_FILLER, true),
	}
	loc_filters = {}
	load_hints([])
func _ready():
	Archipelago.connected.connect(func(conn: ConnectionInfo, _j: Dictionary):
		conn.set_hint_notify(self.load_hints))
	Archipelago.disconnected.connect(reset_hints_to_empty)
	var header := BaseConsole.ArrangedColumnsPart.new()
	headings.append(header.add(hint_console.make_c_text("Receiving Player"), 500))
	headings.append(header.add(hint_console.make_c_text("Item"), 500))
	headings.append(header.add(hint_console.make_c_text("Finding Player"), 500))
	headings.append(header.add(hint_console.make_c_text("Location"), 500))
	headings.append(header.add(hint_console.make_c_text("Status ↓"), 500))
	for q in headings.size():
		headings[q].on_click = func(evt): return sort_click(evt,q)
	hint_console.add(header)
	hint_container = hint_console.add(BaseConsole.ContainerPart.new())


var _queued_refresh_hints := false
func _process(_delta):
	if _queued_refresh_hints:
		_queued_refresh_hints = false
		refresh_hints()

func queue_refresh() -> void:
	_queued_refresh_hints = true

var _stored_hints: Array[NetworkHint] = []
func load_hints(hints: Array[NetworkHint]) -> void:
	_stored_hints.assign(hints)
	refresh_hints()
func refresh_hints():
	_sort_index_data.clear()
	for q in _stored_hints.size():
		_sort_index_data[_stored_hints[q]] = q
	_stored_hints.sort_custom(do_sort)

	hint_container.clear()
	old_status_system = true
	for hint in _stored_hints:
		if hint.status != NetworkHint.Status.NOT_FOUND and hint.status != NetworkHint.Status.FOUND:
			old_status_system = false
		if filter_allow(hint):
			hint_container._add(hint_console.make_hint(hint))
	hint_console.is_max_scroll = false # Prevent auto-scrolling
	hint_console.queue_redraw()

func filter_allow(hint: NetworkHint) -> bool:
	var recv_name := Archipelago.conn.get_player_name(hint.item.dest_player_id, false)
	var item_name := hint.item.get_name()
	var find_name := Archipelago.conn.get_player_name(hint.item.src_player_id, false)
	var loc_name := Archipelago.conn.get_gamedata_for_player(hint.item.src_player_id).get_loc_name(hint.item.loc_id)
	#region Add filters if missing
	if not recv_filters.has(recv_name):
		recv_filters[recv_name] = true
	if not item_filters.has(item_name):
		item_filters[item_name] = true
	if not finding_filters.has(find_name):
		finding_filters[find_name] = true
	if not loc_filters.has(loc_name):
		loc_filters[loc_name] = true
	#endregion
	if not recv_filters.get(recv_name, true):
		return false
	if not item_filters.get(item_name, true):
		return false
	if not finding_filters.get(find_name, true):
		return false
	if not loc_filters.get(loc_name, true):
		return false
	if hint.is_local() and not recv_filters.get(LOCAL_ITEMS, true):
		return false
	var flags := hint.item.flags
	if (flags & AP.ItemClassification.PROG) and not item_filters.get(ITEMS_PROG, true):
		return false
	if (flags & AP.ItemClassification.USEFUL) and not item_filters.get(ITEMS_USEFUL, true):
		return false
	if (flags & AP.ItemClassification.TRAP) and not item_filters.get(ITEMS_TRAP, true):
		return false
	if (not flags) and not item_filters.get(ITEMS_FILLER, true):
		return false
	if not status_filters.get(hint.status, true):
		if not status_filters.get(FORCE_ALL, false):
			return false
	return true
