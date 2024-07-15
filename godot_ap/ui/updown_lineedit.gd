extends LineEdit

func _gui_input(event):
	if event is InputEventKey:
		var n: Control
		match event.keycode:
			KEY_UP:
				n = get_node(focus_neighbor_top) as Control
			KEY_DOWN:
				n = get_node(focus_neighbor_bottom) as Control
		if n:
			accept_event()
			if event.pressed and not event.is_echo():
				release_focus()
				n.grab_focus()
				if n is LineEdit:
					n.caret_column = len(n.text)
