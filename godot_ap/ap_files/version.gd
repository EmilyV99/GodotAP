class_name Version 
extends Resource
## Software version description.
##
## @tutorial(Semantic Versioning): https://semver.org/

## The major version.
@export var major := 0
## The minor version.
@export var minor := 0
## The build number.
@export var build := 0


## Create a version object from a [Dictionary].
static func from(json: Dictionary) -> Version:
	if json["class"] != "Version":
		return null
	var v := Version.new()
	v.major = json["major"]
	v.minor = json["minor"]
	v.build = json["build"]
	return v


## Create a version object from provided [int]s.
static func val(v1:int, v2:int, v3:int) -> Version:
	var v := Version.new()
	v.major = v1
	v.minor = v2
	v.build = v3
	return v


func _to_string():
	return "VER(%d.%d.%d)" % [major,minor,build]


## Compare two version numbers. Returns a value less than [code]0[/code] if [param other] is
## a newer version, and a value greater than [code]0[/code] if [param other] is older. Returns
## [code]0[/code] if both versions are identical.
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
