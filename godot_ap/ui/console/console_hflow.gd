class_name ConsoleHFlow extends HFlowContainer

func _init() -> void:
	add_theme_constant_override("&h_separation", 0)
	add_theme_constant_override("&v_separation", 0)

func _notification(what):
	match what:
		NOTIFICATION_SORT_CHILDREN:
			for child in get_children():
				if child.has_method("handle_sizing"):
					child.handle_sizing(self)

func add_text_split(main_label: ConsoleLabel) -> void:
	if not main_label.text.contains(" "):
		add_child(main_label)
		return
	var words := main_label.text.split(" ")
	main_label.text = ""
	var labels: Array[Control]
	var hspace: int = roundi(main_label.get_theme_font("font").get_string_size(" ",HORIZONTAL_ALIGNMENT_LEFT, -1, main_label.get_theme_font_size("font_size")).x)
	for word in words:
		var d := main_label.make_dupe()
		d.text = word
		labels.append(d)
		var spacing := Spacing.new(self, hspace)
		labels.append(spacing)
	if labels.is_empty(): return
	labels.pop_back()
	for lbl in labels:
		add_child(lbl)
