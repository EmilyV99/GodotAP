class_name TrackerScene_Base extends Container

var trackerpack: TrackerPack_Base

func _init() -> void:
	# Initialize signal connections
	Archipelago.conn.obtained_items.connect(on_items_get)
	Archipelago.conn.refresh_items.connect(func(_itms): refresh_tracker())
	Archipelago.disconnected.connect(queue_free) # Tracker is linked per-connection
	Archipelago.remove_location.connect(on_loc_checked)
	sort_children.connect(on_resize)

func _ready() -> void:
	if trackerpack:
		await trackerpack.readied
	# Handle starting refresh
	refresh_tracker(true)

var _queued_refresh := false
func _process(_delta):
	if _queued_refresh:
		_queued_refresh = false
		if Archipelago.conn:
			refresh_tracker()
func queue_refresh() -> void:
	_queued_refresh = true

## Refresh due to general status update (refresh everything)
## if `fresh_connection` is true, the tracker is just initializing
func refresh_tracker(_fresh_connection: bool = false) -> void:
	assert(false) # Override this function

## Handle this node being resized; fit child nodes into place
func on_resize() -> void:
	assert(false) # Override this function

## Refresh due to item collection
func on_items_get(_items: Array[NetworkItem]) -> void:
	pass # Optionally override this function

## Refresh due to location being checked
func on_loc_checked(_locid: int) -> void:
	pass # Optionally override this function
