class_name TrackerPack_Scene extends TrackerPack_Base

func get_type() -> String: return "SCENE"

@export var scene: PackedScene

func instantiate() -> TrackerScene_Base:
	if scene and scene.can_instantiate():
		return scene.instantiate()
	return super()
	
func _save_file(_data: Dictionary) -> Error:
	return ERR_UNAVAILABLE

func _load_file(_data: Dictionary) -> Error:
	return ERR_UNAVAILABLE
