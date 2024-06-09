class_name CommandManager extends Node

signal debug_toggled(disabled: bool)

var _commands: Array[ConsoleCommand]
var _commands_by_name: Dictionary ##[String: ConsoleCommand]
var debug_hidden := true :
	set(val):
		if not OS.is_debug_build(): return
		if debug_hidden == val: return
		debug_hidden = val
		refresh_db_commands()
		debug_toggled.emit()
var default_procs: Array[Callable] ## [(CommandManager,String)->void]

var console: CustomConsole = null

func autofill(msg: String, capacity := 5) -> Array[String]:
	if msg.is_empty(): return []
	var split_msg := msg.split(" ",true,1)
	var cmd: ConsoleCommand = _commands_by_name.get(split_msg[0])
	var ret: Array[String] = []
	if cmd and not cmd.disabled and cmd.autofill_proc:
		ret = cmd.autofill_proc.call(msg)
	elif split_msg.size() < 2:
		for iter_cmd in _commands:
			if iter_cmd.disabled: continue
			if debug_hidden and iter_cmd.is_debug(): continue
			if iter_cmd.text.begins_with(msg.to_lower()):
				ret.append(iter_cmd.text+" ")
	if capacity > 0 and ret.size() > capacity:
		ret.resize(capacity)
	return ret

func register_command(cmd: ConsoleCommand) -> void:
	cmd.text = cmd.text.to_lower() # Enforce all-lower for insensitive comparisons
	_commands.append(cmd)
	_commands_by_name[cmd.text] = cmd
	if cmd.is_debug() and debug_hidden and not cmd.text == "/debug":
		cmd.disabled = true
func register_default(proc: Callable) -> void:
	default_procs.append(proc)

func call_cmd(msg: String) -> void:
	if msg.is_empty(): return
	var cmd := get_command(msg.split(" ", true, 1)[0])
	if cmd and cmd.call_proc:
		if cmd.disabled:
			console.add_line("Command '%s' is disabled!" % cmd.text, "", console.COLOR_UI_MSG)
		else:
			cmd.call_proc.call(self, cmd, msg)
	else:
		for proc in default_procs:
			proc.call(self, msg)
	

func get_commands() -> Array[ConsoleCommand]: # don't mutate the return
	return _commands
func get_command(cmdname: String) -> ConsoleCommand:
	return _commands_by_name.get(cmdname.to_lower())

static func _cmd_is_enabled(cmd: ConsoleCommand) -> bool:
	return not cmd.disabled
static func _cmd_is_debug(cmd: ConsoleCommand) -> bool:
	return cmd.is_debug()

func get_enabled_commands() -> Array[ConsoleCommand]:
	return _commands.filter(CommandManager._cmd_is_enabled)
func get_debug_commands() -> Array[ConsoleCommand]:
	return _commands.filter(CommandManager._cmd_is_debug)

func refresh_db_commands() -> void:
	if not OS.is_debug_build(): return
	for cmd in get_debug_commands():
		cmd.disabled = debug_hidden
	get_command("/debug").disabled = false

func setup_basic_commands() -> void:
	register_command(ConsoleCommand.new("/help")
		.add_help("", "Displays this message")
		.set_call(func(mgr: CommandManager, _cmd: ConsoleCommand, _msg: String):
			var s := "Command Help:\n"
			for cmd in mgr.get_commands().filter(func(cmd):
				return not (cmd.disabled or cmd.is_debug())):
				s += cmd.get_helptext()
			mgr.console.add_header_spacing()
			mgr.console.add_text(s, "", mgr.console.COLOR_UI_MSG)
			mgr.console.add_header_spacing()))
	register_command(ConsoleCommand.new("/cls")
		.add_help("", "Clears the console")
		.set_call(func(mgr: CommandManager, _cmd: ConsoleCommand, _msg: String):
			mgr.console.clear()))
	register_command(ConsoleCommand.new("/clr_hist")
		.add_help("", "Clears the command history")
		.set_call(func(mgr: CommandManager, _cmd: ConsoleCommand, _msg: String):
			mgr.console.window.typing_bar.history_clear()))
func setup_debug_commands() -> void:
	if not OS.is_debug_build(): return
	register_command(ConsoleCommand.new("/db_help").debug()
		.add_help("", "Displays this message")
		.set_call(func(mgr: CommandManager, _cmd: ConsoleCommand, _msg: String):
			var s := "Debug Help:\n"
			for cmd in mgr.get_commands().filter(func(cmd):
				return not cmd.disabled and cmd.is_debug()):
					s += cmd.get_helptext()
			mgr.console.add_header_spacing()
			mgr.console.add_text(s, "", mgr.console.COLOR_UI_MSG)
			mgr.console.add_header_spacing()))
	register_command(ConsoleCommand.new("/debug").debug()
		.set_call(func(mgr: CommandManager, _cmd: ConsoleCommand, _msg: String):
			debug_hidden = not debug_hidden
			mgr.console.add_header_spacing()
			if debug_hidden:
				mgr.console.add_line("Debug mode disabled","",mgr.console.COLOR_UI_MSG)
			else:
				mgr.console.add_line("Debug mode enabled. Use '/db_help' for debug commands.","",mgr.console.COLOR_UI_MSG)
			mgr.console.add_header_spacing()))
