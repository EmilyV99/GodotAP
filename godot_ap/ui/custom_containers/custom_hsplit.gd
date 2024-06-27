class_name CustomHSplit extends HSplitContainer

func _notification(what):
	match what:
		NOTIFICATION_PRE_SORT_CHILDREN:
			for child in get_children():
				if child.has_method("handle_sizing"):
					child.handle_sizing()
		NOTIFICATION_SORT_CHILDREN:
			for child in get_children():
				if child.has_method("handle_sizing_2"):
					child.handle_sizing_2()
