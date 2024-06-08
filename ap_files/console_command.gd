class_name ConsoleCommand

class CmdHelpText:
	var args: String = ""
	var text: String = ""

var text: String = ""
var help_text: Array[CmdHelpText] = []
var call_proc: Variant = null # Callable[ConsoleCommand,String->void] | null
var autofill_proc: Variant = true # Callable[String->Array[String]] | bool

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

func get_helptext() -> String:
	var s := ""
	for ht in help_text:
		s += "%s %s\n    %s\n" % [text,ht.args,ht.text.replace("\n","\n    ")]
	return s
func output_usage(console: CustomConsole) -> void:
	console.add_text("Usage:\n%s" % get_helptext(), "", AP.COLOR_UI_MSG)
