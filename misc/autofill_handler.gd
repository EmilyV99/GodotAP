class_name AutofillHandler extends Node

var commands: Dictionary #[String,Callable(String)->Array[String]]

func autofill(msg: String, capacity := 5) -> Array[String]:
	if msg.is_empty(): return []
	var proc = commands.get(msg.split(" ",true,1)[0], false)
	var ret: Array[String] = []
	if proc:
		if proc is Callable:
			ret = proc.call(msg)
	else:
		for cmd in commands.keys():
			if cmd.begins_with(msg.to_lower()):
				ret.append(cmd+" ")
	if capacity > 0 and ret.size() > capacity:
		ret.resize(capacity)
	return ret
