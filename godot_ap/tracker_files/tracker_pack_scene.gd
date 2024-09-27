class_name TrackerPack_Scene extends TrackerPack_Base

func get_type() -> String: return "SCENE"

@export var scene: PackedScene

func instantiate() -> TrackerScene_Root:
	if scene and scene.can_instantiate():
		var root_scene := TrackerScene_Root.new()
		root_scene.add_child(scene.instantiate())
		_done_instantiating(root_scene)
		return root_scene
	return super()

func _save_file(_data: Dictionary) -> Error:
	return ERR_UNAVAILABLE

func _load_file(_data: Dictionary) -> Error:
	return ERR_UNAVAILABLE
