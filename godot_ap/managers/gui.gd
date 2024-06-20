class_name GUI

static func make_cbox_row(s: String, initial_state: bool, proc: Callable) -> HBoxContainer:
	var hbox := HBoxContainer.new()
	hbox.set_anchors_preset(Control.PRESET_CENTER)
	var cbox := CheckBox.new()
	cbox.set_pressed_no_signal(initial_state)
	cbox.toggled.connect(proc)
	cbox.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	hbox.add_child(cbox)
	var lbl := Label.new()
	lbl.text = s
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	hbox.add_child(lbl)
	return hbox
