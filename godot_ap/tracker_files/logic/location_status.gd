class_name LocationStatus

var id: int
var text: String
var tooltip: String
var colorname: String
var map_colorname: String
func _init(txt: String, ttip := "", colname := "", map_colname := ""):
	text = txt
	tooltip = ttip
	colorname = colname
	map_colorname = map_colname
func save_dict() -> Dictionary:
	return {"name": text, "ttip": tooltip, "color": colorname}

func make_c_text(c: BaseConsole) -> BaseConsole.CenterTextPart:
	return c.make_c_text(text, tooltip, AP.color_from_name(colorname))
func add_c_text(c: BaseConsole) -> BaseConsole.CenterTextPart:
	return c.add(make_c_text(c))

static var ACCESS_NOT_FOUND := LocationStatus.new("Not Found", "", "red")
static var ACCESS_UNKNOWN := LocationStatus.new("Unknown", "", "white")
static var ACCESS_FOUND := LocationStatus.new("Found", "Already found", "green")
static var ACCESS_UNREACHABLE := LocationStatus.new("Unreachable", "Cannot be accessed", "red")
static var ACCESS_LOGIC_BREAK := LocationStatus.new("Out of Logic", "Reachable, but not currently expected of you, and might require glitches/tricks or be exceedingly difficult.", "orange")
static var ACCESS_REACHABLE := LocationStatus.new("Reachable", "Currently reachable within logic", "plum")
