class_name FontStorage

func _init(_base_font: Font):
	populate(_base_font)

func populate(_base_font: Font):
	base_font = _base_font
	bold_font = Util.font_mod(_get_font_for_mod(), true, false)
	italic_font = Util.font_mod(_get_font_for_mod(), false, true)
	bold_italic_font = Util.font_mod(_get_font_for_mod(), true, true)

func get_font(bold: bool, italic: bool) -> Font:
	if not italic:
		if not bold:
			return base_font
		else:
			return bold_font
	else:
		if not bold:
			return italic_font
		else:
			return bold_italic_font

func _get_font_for_mod():
	var _font: Font
	if base_font is FontVariation or base_font is SystemFont:
		_font = base_font.duplicate()
	else:
		_font = base_font
	return _font

var base_font: Font
var bold_font: Font
var italic_font: Font
var bold_italic_font: Font
