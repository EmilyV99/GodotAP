class_name CommandManager 
extends Node
## Manages available commands for an archipelago session

## Emits a signal when [member debug_hidden] is changed.
signal debug_toggled(disabled: bool)

# The commands currently available to use.
var _commands: Array[ConsoleCommand]

# Commands currently available to use, indexed by name.
var _commands_by_name: Dictionary[String, ConsoleCommand]

## Controls if debug commands should be hidden.
## Cannot be modified in non-debug builds.
var debug_hidden := true :
	set(val):
		if not OS.is_debug_build():
			return
		if debug_hidden == val:
			return
		debug_hidden = val
		debug_toggled.emit()

## Contains an array of [Callable]s to be called when no [ConsoleCommand] is registered for a
## submitted command message.
## [br][br]
## Elements should take a [CommandManager] for the first parameter and a [String] for the second.
## Returned values will be ignored.
var default_procs: Array[Callable] 

## The console to output to.
var console: BaseConsole = null


## Reset the command manager. Clears registered commands, [member default_procs], and sets
## [member debug_hidden] to [code]true[/code].
func reset() -> void:
	_commands.clear()
	_commands_by_name.clear()
	debug_hidden = true
	default_procs.clear()
	#does NOT clear console reference


## Returns [code]true[/code] if debug commands are being hidden, and false if they aren't.
func debug_disabled() -> bool:
	return debug_hidden


## Get the autofilled arguments for a command message, up to the number of arguments specified in
## [param capacity]. If [param capacity] is [code]0[/code], all available autofilled arguments will
## be returned.
func autofill(msg: String, capacity := 5) -> Array[String]:
	if msg.is_empty():
		return []
	var split_msg := msg.split(" ", true, 1)
	var cmd: ConsoleCommand = _commands_by_name.get(split_msg[0])
	var ret: Array[String] = []

	if cmd and not cmd.is_disabled() and cmd.autofill_proc:
		ret.assign(cmd.autofill_proc.call(msg))
	elif split_msg.size() < 2:
		for iter_cmd in _commands:
			if iter_cmd.is_disabled():
				continue
			elif debug_hidden and iter_cmd.is_debug():
				continue
			elif iter_cmd.text.begins_with(msg.to_lower()):
				ret.append(iter_cmd.text+" ")
				
	if capacity > 0 and ret.size() > capacity:
		ret.resize(capacity)

	return ret


## Register a [ConsoleCommand].
func register_command(cmd: ConsoleCommand) -> void:
	cmd.text = cmd.text.to_lower() # Enforce all-lower for insensitive comparisons
	_commands.append(cmd)
	_commands_by_name[cmd.text] = cmd
	if cmd.is_debug() and debug_hidden and not cmd.text == "/debug":
		cmd.disabled_procs.append(debug_disabled)


## Register a [Callable] to be used when no [ConsoleCommand] is found for a given command.
## See also [member default_procs].
## [br][br]
## [param proc] should take a [CommandManager] for the first parameter and a [String] for the second.
## The second parameter will contain the message to be handled.
func register_default(proc: Callable) -> void:
	default_procs.append(proc)


## Call the command for a given non-empty message. If none is found, the message is passed to all
## registered [Callable]s in [member default_procs].
func call_cmd(msg: String) -> void:
	if msg.is_empty():
		return
	var cmd := get_command(msg.split(" ", true, 1)[0])
	if cmd and cmd.call_proc:
		if cmd.is_disabled() or (cmd.is_debug() and cmd.debug_disabled()):
			console.add(BaseConsole.make_text("Command '%s' is disabled!" % cmd.text, "",
					AP.ComplexColor.as_special(AP.SpecialColor.UI_MESSAGE)))
		else:
			cmd.call_proc.call(self, cmd, msg)
	else:
		for proc in default_procs:
			proc.call(self, msg)


## Get the registered [ConsoleCommand]s.
## [br][br]
## [b]Do not mutate the returned array[/b]
func get_commands() -> Array[ConsoleCommand]: # don't mutate the return
	return _commands


## Get the [ConsoleCommand] registered to [param cmdname].
func get_command(cmdname: String) -> ConsoleCommand:
	return _commands_by_name.get(cmdname.to_lower())


# Check if [param cmd] is enabled.
static func _cmd_is_enabled(cmd: ConsoleCommand) -> bool:
	return not (cmd.is_disabled() or (cmd.is_debug() and cmd.debug_disabled()))


# Check if [param cmd] is debug-only.
static func _cmd_is_debug(cmd: ConsoleCommand) -> bool:
	return cmd.is_debug()


## Get an array of all the enabled commands.
func get_enabled_commands() -> Array[ConsoleCommand]:
	return _commands.filter(CommandManager._cmd_is_enabled)


## Get an array of all the debug-only commands.
func get_debug_commands() -> Array[ConsoleCommand]:
	return _commands.filter(CommandManager._cmd_is_debug)


## Set up the basic [ConsoleCommand]s that will always be available.
## [br][br]
## Currently this sets up [code]/help[/code] for displaying available commands, [code]/cls[/code] 
## for clearing the console, and [code]/clr_hist[/code] for clearing the command history.
func setup_basic_commands() -> void:
	register_command(ConsoleCommand.new("/help")
		.add_help("", "Displays all currently available commands")
		.set_call(func(mgr: CommandManager, _cmd: ConsoleCommand, _msg: String):
			mgr.console.add_header_spacing()
			var folder := BaseConsole.make_foldable("[ COMMAND HELP ]",
				"Commands shown may vary based on various conditions, such as if you are" +
				" connected to an Archipelago server or not.",
				AP.ComplexColor.as_special(AP.SpecialColor.UI_MESSAGE))
			mgr.console.add(folder)
			folder.add(mgr.console.make_header_spacing())
			for cmd in mgr.get_commands().filter(func(cmd):
					return not (cmd.is_disabled() or cmd.is_debug())):
				cmd.output_helptext(mgr.console, folder)
			
			mgr.console.add_header_spacing()
			folder.fold(false)))
	
	register_command(ConsoleCommand.new("/cls")
		.add_help("", "Clears the console")
		.set_call(func(mgr: CommandManager, _cmd: ConsoleCommand, _msg: String):
			mgr.console.clear()))
	
	register_command(ConsoleCommand.new("/clr_hist")
		.add_help("", "Clears the command history")
		.set_call(func(mgr: CommandManager, _cmd: ConsoleCommand, _msg: String):
			mgr.console.window.typing_bar.history_clear()))


## Set up the [ConsoleCommand]s that will only be available when debug mode is enabled.
## [br][br]
## If [method OS.is_debug_build] returns false, no commands will be set up.
func setup_debug_commands() -> void:
	if not OS.is_debug_build():
		return

	register_command(ConsoleCommand.new("/db_help").debug()
		.add_help("", "Displays this message")
		.set_call(func(mgr: CommandManager, _cmd: ConsoleCommand, _msg: String):
			mgr.console.add_header_spacing()
			mgr.console.add(BaseConsole.make_text("Debug Help:", "",
					AP.ComplexColor.as_special(AP.SpecialColor.UI_MESSAGE)))
			for cmd in mgr.get_commands().filter(func(cmd):
				return not cmd.is_disabled() and cmd.is_debug()):
				cmd.output_helptext(mgr.console)
			mgr.console.add_header_spacing()))
			
	register_command(ConsoleCommand.new("/debug").debug()
		.set_call(func(mgr: CommandManager, _cmd: ConsoleCommand, _msg: String):
			debug_hidden = not debug_hidden
			mgr.console.add_header_spacing()
			if debug_hidden:
				mgr.console.add(BaseConsole.make_text("Debug mode disabled", "",
						AP.ComplexColor.as_special(AP.SpecialColor.UI_MESSAGE)))
			else:
				mgr.console.add(BaseConsole.make_text(
						"Debug mode enabled. Use '/db_help' for debug commands.",
						"",
						AP.ComplexColor.as_special(AP.SpecialColor.UI_MESSAGE)))
			mgr.console.add_header_spacing()))
