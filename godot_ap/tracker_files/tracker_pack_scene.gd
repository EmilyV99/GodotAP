class_name TrackerPack_Scene extends TrackerPack_Base

func get_type() -> String: return "SCENE"

@export var scene: PackedScene

func instantiate() -> TrackerScene_Base:
	if scene and scene.can_instantiate():
		return scene.instantiate()
	return super()

func save_file(file: FileAccess) -> Error:
	var err := super(file)
	if err: return err
	file.store_var(scene, true)
	return file.get_error()

func _load_file(file: FileAccess) -> Error:
	var err := super(file)
	if err: return err
	scene = file.get_var(true)
	return file.get_error()
