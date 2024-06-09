class_name ConsoleCommand

const HELPTEXT_INDENT = 20

class CmdHelpText:
	var args: String = ""
	var text: String = ""

var text: String = ""
var help_text: Array[CmdHelpText] = []
var call_proc: Variant = null # Callable(ConsoleCommand,String)->void | null
var autofill_proc: Variant = null # Callable(String)->Array[String] | null
var disabled: bool = false
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
func debug(state := true) -> ConsoleCommand:
	_debug = state
	return self
#endregion

func is_debug() -> bool:
	return _debug

func get_helptext() -> String:
	var s := ""
	for ht in help_text:
		s += "%s %s\n    %s\n" % [text,ht.args,ht.text.replace("\n","\n    ")]
	return s
func output_helptext(console: CustomConsole) -> void:
	for ht in help_text:
		console.add_line("%s %s" % [text,ht.args], "", console.COLOR_UI_MSG)
		console.add_indent(HELPTEXT_INDENT)
		console.add_line(ht.text, "", console.COLOR_UI_MSG)
		console.add_indent(-HELPTEXT_INDENT)
func output_usage(console: CustomConsole) -> void:
	console.add_text("Usage:\n%s" % get_helptext(), "", console.COLOR_UI_MSG)

static func cmd_is_enabled(cmd: ConsoleCommand):
	return not cmd.disabled

func _to_string():
	var s = "COMMAND(" + text
	if disabled: s += ",dis"
	if is_debug(): s += ",db"
	return s+")"
