class_name Version extends Resource

@export var major := 0
@export var minor := 0
@export var build := 0

static func from(json: Dictionary) -> Version:
	if json["class"] != "Version":
		return null
	var v := Version.new()
	v.major = json["major"]
	v.minor = json["minor"]
	v.build = json["build"]
	return v
static func val(v1:int, v2:int, v3:int) -> Version:
	var v = Version.new()
	v.major = v1
	v.minor = v2
	v.build = v3
	return v

func _to_string():
	return "VER(%d.%d.%d)" % [major,minor,build]

func compare(other: Version) -> int:
	if major != other.major:
		return major - other.major
	if minor != other.minor:
		return minor - other.minor
	return build - other.build

func _as_ap_dict() -> Dictionary:
	return {"major":major,"minor":minor,"build":build,"class":"Version"}

func _as_semver_dict() -> Dictionary:
	return {"major":major,"minor":minor,"patch":build}
