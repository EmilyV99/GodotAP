class_name SignalChooser

static var active_choosers: Array[SignalChooser]

signal chosen(idx: int)
var _choice: int = -1
var choices: Array[Callable] = []

func _choose(idx: int) -> void:
	assert(idx > -1)
	if _choice > -1: return
	_choice = idx
	choices[idx].call()
	chosen.emit(idx)
	SignalChooser.deregister(self)

func _reg_signal(sig: Signal, idx: int) -> void:
	await sig
	_choose(idx)
func _reg_call(proc: Callable, idx: int) -> void:
	await proc.call()
	_choose(idx)

func register_signal(sig: Signal, on_chosen: Callable) -> SignalChooser:
	SignalChooser.register(self)
	choices.append(on_chosen)
	_reg_signal(sig, choices.size()-1)
	return self

func register_call(proc: Callable, on_chosen: Callable) -> SignalChooser:
	SignalChooser.register(self)
	choices.append(on_chosen)
	_reg_call(proc, choices.size()-1)
	return self

func register_multiple(causes: Array, effects: Array[Callable]) -> SignalChooser:
	assert(causes.size() == effects.size())
	for q in causes.size():
		if causes[q] is Signal:
			register_signal(causes[q], effects[q])
		elif causes[q] is Callable:
			register_call(causes[q], effects[q])
		else: assert(false)
	return self

func finished() -> int:
	if _choice < 0:
		await chosen
	return _choice

func is_finished() -> bool:
	return _choice > -1

static func register(chooser: SignalChooser) -> void:
	if chooser not in active_choosers:
		active_choosers.append(chooser)

static func deregister(chooser: SignalChooser) -> void:
	if chooser in active_choosers:
		active_choosers.erase(chooser)
