@tool class_name StringBar extends Control

@export var bg_color: Color = Color(.2,.2,.2)
@export var sel_color: Color = Color.SLATE_GRAY
@export var font: Font
@export var font_size: int = 20

signal clicked(index: int)

const HMARGIN = 6
const HPADDING = 2
const VMARGIN = 4
const VPADDING = 2

var strings: Array[String] = [] : get = get_strings, set = set_strings
var _hitboxes: Array[Rect2] = []
var hov_ind := -1

func set_strings(arr: Array[String]) -> void:
	strings = arr
	visible = not strings.is_empty()
	_hitboxes.clear()
	queue_redraw()
func get_strings() -> Array[String]:
	return strings

func _draw():
	var by := position.y+size.y
	var fh := font.get_height(font_size)
	var lh := fh + 2*(VMARGIN+VPADDING)
	var sz = Vector2(size.x,strings.size() * lh)
	position.y = by-sz.y
	var y = sz.y-(VMARGIN+VPADDING)-fh
	draw_rect(Rect2(Vector2.ZERO,size), bg_color)
	_hitboxes.clear()
	for q in strings.size():
		_hitboxes.append(Rect2(HMARGIN,VMARGIN+(lh*(strings.size()-q-1)),sz.x-2*HMARGIN,lh-2*VPADDING))
	for q in strings.size():
		var s = strings[q]
		if q == hov_ind:
			draw_rect(Rect2(HMARGIN,y-VPADDING,sz.x-(2*HMARGIN), lh-(2*VMARGIN)), sel_color)
		draw_string(font, Vector2(HMARGIN+HPADDING, y+font.get_ascent(font_size)), s, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size)
		y -= lh
	set_deferred("size",sz)

func _gui_input(event):
	if event is InputEventMouseButton:
		if hov_ind > -1 and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			clicked.emit(hov_ind)

var _has_mouse := false
func _process(_delta):
	if _has_mouse:
		var pos = get_viewport().get_mouse_position() + Util.MOUSE_OFFSET - global_position
		var found := false
		for q in _hitboxes.size():
			if _hitboxes[q].has_point(pos):
				if hov_ind != q:
					hov_ind = q
					queue_redraw()
				found = true
				break
		if not found:
			hov_ind = -1
func _notification(what):
	match what:
		NOTIFICATION_MOUSE_ENTER:
			_has_mouse = true
		NOTIFICATION_MOUSE_EXIT:
			_has_mouse = false
			hov_ind = -1
