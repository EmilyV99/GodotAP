class_name HintsTab extends MarginContainer

@onready var hint_console: BaseConsole = $Console/Cont/ConsoleMargin/Console

var hint_container: BaseConsole.ContainerPart
var headings: Array[BaseConsole.TextPart]

var sort_ascending := [true,true,true,true,false]
var sort_cols := [4,0,2,1,3]

var status_filters: Dictionary = {
	"Force All": false,
	NetworkHint.Status.FOUND: false,
}

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
		refresh_hints()
		return true
	elif event.button_index == MOUSE_BUTTON_RIGHT:
		# TODO handle popping up filter list
		
		if not index in [4]: # TODO temp, remove
			return false
		
		var window := Window.new()
		window.transient = true
		window.exclusive = true
		window.unresizable = true
		window.borderless = true
		window.popup_window = true
		window.close_requested.connect(window.queue_free)
		window.position = get_window().position + Vector2i(event.global_position)
		window.ready.connect(func():
			window.size.x = roundi(get_window().size.x/5.0)
			window.position = get_window().position
			window.position.x += window.size.x*index
			window.position.y += roundi(hint_console.global_position.y + headings[0].get_hitboxes()[0].size.y)
			, CONNECT_ONE_SHOT)
		var vbox := VBoxContainer.new()
		window.add_child(vbox)
		vbox.set_anchors_preset(PRESET_FULL_RECT) 
		match index:
			4: # Status
				var arr: Array = ["Force All"]
				arr.append_array(Util.reversed(NetworkHint.status_names.keys()))
				for s in arr:
					var hbox := HBoxContainer.new()
					hbox.set_anchors_preset(PRESET_CENTER)
					var cbox := CheckBox.new()
					cbox.set_pressed_no_signal(status_filters.get(s, true))
					cbox.toggled.connect(func(state: bool):
						status_filters[s] = state
						refresh_hints())
					cbox.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
					hbox.add_child(cbox)
					var lbl := Label.new()
					lbl.text = s if s is String else NetworkHint.status_names[s]
					lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
					hbox.add_child(lbl)
					vbox.add_child(hbox)
		window.ready.connect(func():
			window.size.y = ceili(vbox.size.y))
		add_child(window)
		return true
	return false

func _ready():
	Archipelago.connected.connect(func(conn: ConnectionInfo, _j: Dictionary):
		var hint_key := "_read_hints_%d_%d" % [Archipelago.conn.team_id, Archipelago.conn.player_id]
		conn.set_notify(hint_key, self.load_hints_from_json)
		conn.retrieve(hint_key, self.load_hints_from_json))
	var header := BaseConsole.ColumnsPart.new()
	headings.append(header.add(hint_console.make_c_text("Receiving Player"), 500))
	headings.append(header.add(hint_console.make_c_text("Item"), 500))
	headings.append(header.add(hint_console.make_c_text("Finding Player"), 500))
	headings.append(header.add(hint_console.make_c_text("Location"), 500))
	headings.append(header.add(hint_console.make_c_text("Status ↓"), 500))
	for q in headings.size():
		headings[q].on_click = func(evt): return sort_click(evt,q)
	hint_console.add(header)
	hint_container = hint_console.add(BaseConsole.ContainerPart.new())

var _stored_hints: Array[NetworkHint] = []
func load_hints_from_json(hints: Array) -> void:
	_stored_hints.clear()
	for json in hints:
		_stored_hints.append(NetworkHint.from(json))
	refresh_hints()
func refresh_hints():
	_sort_index_data.clear()
	for q in _stored_hints.size():
		_sort_index_data[_stored_hints[q]] = q
	_stored_hints.sort_custom(do_sort)
	
	hint_container.clear()
	for hint in _stored_hints:
		if filter_allow(hint):
			hint_container._add(hint_console.make_hint(hint))
	hint_console.queue_redraw()

func filter_allow(hint: NetworkHint):
	if not status_filters.get(hint.status, true):
		return status_filters.get("Force All", false)
	return true
