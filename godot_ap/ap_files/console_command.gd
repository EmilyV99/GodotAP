class_name ConsoleCommand

const HELPTEXT_INDENT = 20

class CmdHelpText:
	var args: String = ""
	var text: String = ""
	var cond: Callable #Callable[]->bool

var text: String = ""
var help_text: Array[CmdHelpText] = []
var call_proc: Variant = null # Callable(ConsoleCommand,String)->void | null
var autofill_proc: Variant = null # Callable(String)->Array[String] | null
var disabled_procs: Array[Callable] = [] # [Callable()->bool]
var _debug: bool = false

#region Constructor and builder-pattern funcs
func _init(txt: String):
	text = txt

func set_call(caller: Callable) -> ConsoleCommand:
	call_proc = caller
	return self
func set_autofill(caller: Variant) -> ConsoleCommand:
	assert(caller is bool or caller is Callable)
	autofill_proc = caller
	return self
func add_help(args: String, helptxt: String) -> ConsoleCommand:
	var ht := CmdHelpText.new()
	ht.args = args
	ht.text = helptxt
	help_text.append(ht)
	return self
func add_help_cond(args: String, helptxt: String, cond: Callable) -> ConsoleCommand:
	add_help(args, helptxt)
	help_text.back().cond = cond
	return self
func add_disable(proc: Callable) -> ConsoleCommand:
	disabled_procs.append(proc)
	return self
func debug(state := true) -> ConsoleCommand:
	_debug = state
	return self
#endregion

func is_debug() -> bool:
	return _debug

func get_helptext() -> String:
	var s := ""
	for ht in help_text:
		if ht.cond and not ht.cond.call(): continue
		s += "%s %s\n    %s\n" % [text,ht.args,ht.text.replace("\n","\n    ")]
	return s
func output_helptext(console: BaseConsole, target = null) -> void:
	var texts: Array[CmdHelpText] = []
	for ht in help_text:
		if ht.cond and not ht.cond.call(): continue
		texts.append(ht)
	if not target:
		for ht in texts:
			console.add(BaseConsole.make_text("%s %s" % [text,ht.args], "", AP.ComplexColor.as_special(AP.SpecialColor.UI_MESSAGE)))
			var indent := BaseConsole.make_indent(HELPTEXT_INDENT)
			console.add(indent)
			indent.add_child(BaseConsole.make_text(ht.text, "", AP.ComplexColor.as_special(AP.SpecialColor.UI_MESSAGE)))
	elif target is ConsoleFoldableContainer:
		for ht in texts:
			target.add(BaseConsole.make_text("%s %s" % [text,ht.args], "", AP.ComplexColor.as_special(AP.SpecialColor.UI_MESSAGE)))
			target.add(console.make_header_spacing(0))
			var indent := BaseConsole.make_indent(HELPTEXT_INDENT)
			target.add(indent)
			var vbox := VBoxContainer.new()
			indent.add_child(vbox)
			vbox.add_child(BaseConsole.make_text(ht.text, "", AP.ComplexColor.as_special(AP.SpecialColor.UI_MESSAGE)))
			vbox.add_child(console.make_header_spacing(0))

	elif target is Container:
		for ht in texts:
			target.add_child(BaseConsole.make_text("%s %s" % [text,ht.args], "", AP.ComplexColor.as_special(AP.SpecialColor.UI_MESSAGE)))
			target.add_child(console.make_header_spacing(0))
			target.add_child(BaseConsole.make_indent(HELPTEXT_INDENT))
			target.add_child(BaseConsole.make_text(ht.text, "", AP.ComplexColor.as_special(AP.SpecialColor.UI_MESSAGE)))
			target.add_child(console.make_header_spacing(0))
			target.add_child(BaseConsole.make_indent(-HELPTEXT_INDENT))
func output_usage(console: BaseConsole) -> void:
	console.add(BaseConsole.make_text("Usage:\n%s" % get_helptext(), "", AP.ComplexColor.as_special(AP.SpecialColor.UI_MESSAGE)))

func is_disabled() -> bool:
	for proc in disabled_procs:
		if proc.call(): return true
	return false

func _to_string():
	var s = "COMMAND(" + text
	if is_disabled(): s += ",dis"
	if is_debug(): s += ",db"
	return s+")"
