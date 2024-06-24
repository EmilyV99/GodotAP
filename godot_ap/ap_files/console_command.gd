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
			console.add_line("%s %s" % [text,ht.args], "", console.COLOR_UI_MSG)
			console.add_indent(HELPTEXT_INDENT)
			console.add_line(ht.text, "", console.COLOR_UI_MSG)
			console.add_indent(-HELPTEXT_INDENT)
	elif target is BaseConsole.ArrangedColumnsPart or target is BaseConsole.ColumnsPart:
		assert(false)
	elif target is BaseConsole.FoldablePart:
		for ht in texts:
			target.add(console.make_text("%s %s" % [text,ht.args], "", console.COLOR_UI_MSG))
			target.add(console.make_header_spacing(0))
			target.add(console.make_indent(HELPTEXT_INDENT))
			target.add(console.make_text(ht.text, "", console.COLOR_UI_MSG))
			target.add(console.make_header_spacing(0))
			target.add(console.make_indent(-HELPTEXT_INDENT))
	elif target is BaseConsole.ContainerPart:
		for ht in texts:
			target._add(console.make_text("%s %s" % [text,ht.args], "", console.COLOR_UI_MSG))
			target._add(console.make_header_spacing(0))
			target._add(console.make_indent(HELPTEXT_INDENT))
			target._add(console.make_text(ht.text, "", console.COLOR_UI_MSG))
			target._add(console.make_header_spacing(0))
			target._add(console.make_indent(-HELPTEXT_INDENT))
func output_usage(console: BaseConsole) -> void:
	console.add_text("Usage:\n%s" % get_helptext(), "", console.COLOR_UI_MSG)

func is_disabled() -> bool:
	for proc in disabled_procs:
		if proc.call(): return true
	return false

func _to_string():
	var s = "COMMAND(" + text
	if is_disabled(): s += ",dis"
	if is_debug(): s += ",db"
	return s+")"
