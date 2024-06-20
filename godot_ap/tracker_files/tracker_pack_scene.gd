class_name TrackerPack_Scene extends TrackerPack_Base

@export var scene: PackedScene
func instantiate() -> TrackerScene_Base:
	if scene and scene.can_instantiate():
		return scene.instantiate()
	return super()
