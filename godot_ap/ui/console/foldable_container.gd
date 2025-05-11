class_name ConsoleFoldableContainer extends VBoxContainer

var label: ConsoleLabel
var body: VBoxContainer
var folded: bool :
	set = fold, get = is_folded

func is_folded() -> bool:
	return not body.visible
func fold(val: bool) -> void:
	body.visible = not val
	queue_redraw()
	if label.text.ends_with(" (Show)") or label.text.ends_with(" (Hide)"):
		label.text = label.text.substr(0, label.text.length() - 7)
	label.text += " (Show)" if val else " (Hide)"

func toggle_fold() -> void:
	fold(not folded)

func _init() -> void:
	add_theme_constant_override(&"separation", 4)
	size_flags_horizontal = Control.SIZE_EXPAND_FILL

	label = ConsoleLabel.make("")
	add_child(label)

	body = VBoxContainer.new()
	body.theme_type_variation = "Console_VBox"
	add_child(body)
	folded = true

	label.clicked.connect(toggle_fold.unbind(1))

func add(node: Control) -> Control:
	body.add_child(node)
	return node

static func make(text: String, ttip := "", color := AP.ComplexColor.NIL) -> ConsoleFoldableContainer:
	var ret := ConsoleFoldableContainer.new()
	ret.label.set_content(text, ttip)
	ret.label.set_color(color)
	return ret
