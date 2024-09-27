class_name TrackerScene_Icon extends TrackerScene_Base

@onready var image_rect: TextureRect = $Image
@onready var label: Label = $Label
@onready var tooltip_bg: ColorRect = $TooltipBG
@onready var tooltip_label: Label = $TooltipBG/Tooltip

var image_path: String
var width := -1
var height := -1
var show_max := false
var valnode: TrackerValueNode
var gray_under_node: TrackerValueNode = TrackerValueInt.new(1)
var maxnode: TrackerValueNode
var colorname := "white"
var max_colorname := "green"
var modulate_colorname := "white"

var tooltip: String = ""

var _base_image: Image
var image: Image
var gray_image: Image

var last_shown_image: Image
var last_shown_size: Vector2i

func show_image(img: Image) -> void:
	if last_shown_image == img: return
	image_rect.texture = ImageTexture.create_from_image(img)
	last_shown_image = img

func is_gray() -> bool:
	var v = valnode.calculate()
	if not TrackerPack_Base._check_int(v): v = 0
	var gray = gray_under_node.calculate()
	if not TrackerPack_Base._check_int(gray): gray = 1
	return v < gray

## Refresh due to general status update (refresh everything)
## if `fresh_connection` is true, the tracker is just initializing
func refresh_tracker(fresh_connection: bool = false) -> void:
	if fresh_connection:
		assert(valnode)
		assert(maxnode)
		assert(trackerpack as TrackerPack_Data)
		_base_image = trackerpack.load_image(image_path)
		image = Util.modulate(_base_image, AP.color_from_name(modulate_colorname))
		gray_image = Util.grayscale(image)
	await TrackerManager.on_tracker_load()

	var v = valnode.calculate()
	var maxval = maxnode.calculate()

	if TrackerPack_Base._check_int(v): v = roundi(v)
	else: v = 0

	if TrackerPack_Base._check_int(maxval): maxval = roundi(maxval)
	else: maxval = 999

	var gray := is_gray()
	label.visible = show_max or (maxval > 1 and v != 0)
	label.text = str(min(v,maxval))
	if show_max:
		label.text += " / %d" % maxval
	show_image(gray_image if gray else image)
	var mod_c = .3 if gray else 1.0
	image_rect.modulate = Color(mod_c,mod_c,mod_c)
	label.label_settings.font_color = AP.color_from_name(colorname if v < maxval else max_colorname)

	on_resize()

## Handle this node being resized; fit child nodes into place
func on_resize() -> void:
	if not is_node_ready(): return
	image_rect.custom_minimum_size = Vector2.ZERO
	var sz: Vector2
	if width > -1 and height > -1: # Exact Size
		sz = Vector2(width, height)
	elif width > -1:
		var w_ratio = (image.get_width() as float / image.get_height())
		sz = Vector2(width, w_ratio * width)
	elif height > -1:
		var h_ratio = (image.get_height() as float / image.get_width())
		sz = Vector2(h_ratio * height, height)
	else:
		sz = Vector2(image.get_width(), image.get_height())
	set_anchors_preset(Control.PRESET_CENTER)
	custom_minimum_size = sz
	size = sz
	image_rect.custom_minimum_size = sz
	image_rect.size = sz
	label.custom_minimum_size = sz
	label.size = sz
	var rect := Rect2((size - sz) / 2, sz)
	fit_child_in_rect(image_rect, rect)
	rect.size.x *= 2
	fit_child_in_rect(label, rect)

## Refresh due to item collection
func on_items_get(_items: Array[NetworkItem]) -> void:
	queue_refresh()

## Refresh due to location being checked
func on_loc_checked(_locid: int) -> void:
	queue_refresh()

func _ttip_calc_size(clip := false) -> void:
	if clip:
		tooltip_label.size = Vector2(get_window().size.x, tooltip_label.size.y)
		var h: int = 0 if tooltip_label.get_line_count() else tooltip_label.get_line_height()
		for q in tooltip_label.get_line_count():
			h += tooltip_label.get_line_height(q)
		tooltip_label.size = Vector2(tooltip_label.size.x,h)
	else:
		tooltip_label.reset_size()
	tooltip_bg.size = tooltip_label.size

	var cpos: Vector2 = size / 2
	tooltip_bg.position.x = cpos.x - tooltip_bg.size.x/2
	if cpos.y >= get_window().size.y / 2.0:
		tooltip_bg.position.y = -tooltip_bg.size.y
	else:
		tooltip_bg.position.y = size.y
	#region Add border
	const HMARGIN = 6
	const VMARGIN = 4
	tooltip_label.position.x = HMARGIN
	tooltip_label.position.y = VMARGIN
	tooltip_bg.size.x += 2*HMARGIN
	tooltip_bg.size.y += 2*VMARGIN
	#endregion Add border

func show_tooltip() -> void:
	if tooltip.is_empty(): return
	tooltip_bg.visible = true
	tooltip_bg.top_level = false
	tooltip_label.text = tooltip
	tooltip_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	tooltip_label.reset_size()
	_ttip_calc_size()

	#region Bound tooltip in-window
	var win := get_window()
	if tooltip_bg.size.x >= win.size.x: #don't let width overrun
		tooltip_label.autowrap_mode = TextServer.AUTOWRAP_WORD
		tooltip_label.get_minimum_size() # Removing this getter breaks everything for some reason. WTF.
		_ttip_calc_size(true)
	tooltip_bg.top_level = true
	tooltip_bg.position += global_position
	while tooltip_bg.global_position.x < win.position.x:
		tooltip_bg.position.x += 1
	while tooltip_bg.global_position.x + tooltip_bg.size.x >= win.position.x + win.size.x:
		tooltip_bg.position.x -= 1
	while tooltip_bg.global_position.y < 0:
		tooltip_bg.position.y += 1
	while tooltip_bg.global_position.y + tooltip_bg.size.y > win.size.y:
		tooltip_bg.position.y -= 1
	#endregion Bound tooltip in-window

func _on_mouse_entered():
	show_tooltip()

func _on_mouse_exited():
	tooltip_bg.visible = false

func _on_gui_input(event):
	if event is InputEventMouseMotion:
		show_tooltip()
