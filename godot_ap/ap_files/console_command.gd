class_name ConsoleCommand
## Information about a console command.

## How deep the indentation is for help text display on the console.
const HELPTEXT_INDENT = 20


## Contains the help text for the usage of a command.
class CmdHelpText:
	## The arguments the command takes, to be displayed to the user.
	var args: String = ""
	## A description of the command and the uses of the variables.
	var text: String = ""
	## A [Callable] that returns [code]true[/code] if the help text should be displayed. Returns
	## [code]false[/code] otherwise.
	## [br][br]
	## Should require no parameters and return a [bool].
	var cond: Callable # Callable() -> bool


## The command in question (including preceding [code]/[/code] or [code]![/code]).
var text: String = ""
## An array of descriptions to inform the user of how to use this command. Different elements may
## describe variations on commands with different argument types or counts. See
## [ConsoleCommand.CmdHelpText] for more information.
var help_text: Array[CmdHelpText] = []
## A [Callable] to be called when the command is input. May be [code]null[/code].
## [br][br]
## Must take a [ConsoleCommand] as its first parameter and a [String] as its second. The second
## parameter contains all arguments passed to the command. Any returned values will be ignored.
var call_proc: Variant = null # Callable(ConsoleCommand,String)->void | null
## A [Callable] that returns autofill information as an [Array] of [String]s. May be 
## [code]null[/code].
## [br][br]
## Should take a [String] as its first parameter and return an [Array] of [String]s. The parameter
## contains the current input by the user, and the returned value contains an array of possible
## completions
var autofill_proc: Variant = null # Callable(String)->Array[String] | null
## An [Array] of [Callable]s that determine whether or not this command is disabled. If any return
## [code]true[/code], this command is considered disabled.
## [br][br]
## Entries should require no parameters and return a [bool].
var disabled_procs: Array[Callable] = [] # Callable()->bool

var _debug: bool = false

#region Constructor and builder-pattern funcs
func _init(txt: String):
	text = txt


## Set [member call_proc].
func set_call(caller: Callable) -> ConsoleCommand:
	call_proc = caller
	return self


## Set [member autofill_proc].
func set_autofill(caller: Variant) -> ConsoleCommand:
	assert(caller is bool or caller is Callable)
	autofill_proc = caller
	return self


## Register a [ConsoleCommand.CmdHelpText] to [member help_text]. [param args] should be a text
## display of the arguments to the command and [param helptxt] should be a description of the
## command's effects.
func add_help(args: String, helptxt: String) -> ConsoleCommand:
	var ht := CmdHelpText.new()
	ht.args = args
	ht.text = helptxt
	help_text.append(ht)
	return self


## Register a [ConsoleCommand.CmdHelpText] to [member help_text]. Similar to [method add_help], but
## takes an additional [param cond] parameter to determine if the help text should be displayed.
## [br][br]
## See [member ConsoleCommand.CmdHelpText.cond] for more information on the requirements for
## [param cond].
func add_help_cond(args: String, helptxt: String, cond: Callable) -> ConsoleCommand:
	add_help(args, helptxt)
	help_text.back().cond = cond
	return self


## Add a [Callable] to determine if the command should be disabled. See [member disabled_procs] for
## information on the requirements for [param proc].
func add_disable(proc: Callable) -> ConsoleCommand:
	disabled_procs.append(proc)
	return self


## Enable or disable debug-only status for this command.
func debug(state := true) -> ConsoleCommand:
	_debug = state
	return self
#endregion


## Returns [code]true[/code] if the command is debug-only.
func is_debug() -> bool:
	return _debug


## Get all the help text for this command.
func get_helptext() -> String:
	var s := ""
	for ht in help_text:
		if ht.cond and not ht.cond.call():
			continue
		s += "%s %s\n    %s\n" % [text, ht.args, ht.text.replace("\n","\n    ")]
	return s


## Output help text to the given [param console]. [param target] may optionally also be supplied to
## specify where to output to.
## [br][br]
## [param target] may only be [code]null[/code] or of type [ConsoleFoldableContainer] or 
## [Container].
func output_helptext(console: BaseConsole, target = null) -> void:
	var texts: Array[CmdHelpText] = []
	for ht in help_text:
		if ht.cond and not ht.cond.call(): continue
		texts.append(ht)
		
	if not target:
		for ht in texts:
			console.add(BaseConsole.make_text("%s %s" % [text, ht.args],
					"",
					AP.ComplexColor.as_special(AP.SpecialColor.UI_MESSAGE)))
			var indent := BaseConsole.make_indent(HELPTEXT_INDENT)
			console.add(indent)
			indent.add_child(BaseConsole.make_text(ht.text,
					"",
					AP.ComplexColor.as_special(AP.SpecialColor.UI_MESSAGE)))
			
	elif target is ConsoleFoldableContainer:
		for ht in texts:
			target.add(BaseConsole.make_text("%s %s" % [text, ht.args],
					"",
					AP.ComplexColor.as_special(AP.SpecialColor.UI_MESSAGE)))
			target.add(console.make_header_spacing(0))
			var indent := BaseConsole.make_indent(HELPTEXT_INDENT)
			target.add(indent)
			var vbox := VBoxContainer.new()
			indent.add_child(vbox)
			vbox.add_child(BaseConsole.make_text(ht.text,
					"",
					AP.ComplexColor.as_special(AP.SpecialColor.UI_MESSAGE)))
			vbox.add_child(console.make_header_spacing(0))

	elif target is Container:
		for ht in texts:
			target.add_child(BaseConsole.make_text("%s %s" % [text, ht.args],
					"",
					AP.ComplexColor.as_special(AP.SpecialColor.UI_MESSAGE)))
			target.add_child(console.make_header_spacing(0))
			target.add_child(BaseConsole.make_indent(HELPTEXT_INDENT))
			target.add_child(BaseConsole.make_text(ht.text,
					"",
					AP.ComplexColor.as_special(AP.SpecialColor.UI_MESSAGE)))
			target.add_child(console.make_header_spacing(0))
			target.add_child(BaseConsole.make_indent(-HELPTEXT_INDENT))


## Output usage instructions to [param console].
func output_usage(console: BaseConsole) -> void:
	console.add(BaseConsole.make_text("Usage:\n%s" % get_helptext(),
			"",
			AP.ComplexColor.as_special(AP.SpecialColor.UI_MESSAGE)))


## Returns [code]true[/code] if this command is currently disabled. Returns [code]false[/code]
## otherwise.
func is_disabled() -> bool:
	for proc in disabled_procs:
		if proc.call():
			return true
	return false


func _to_string():
	var s = "COMMAND(" + text
	if is_disabled(): s += ",dis"
	if is_debug(): s += ",db"
	return s+")"
