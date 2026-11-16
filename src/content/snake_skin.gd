class_name SnakeSkin
extends Resource
@export var id := "mint"
@export var head_color := Color("64f5cb")
@export var body_color := Color("2c9f9b")
@export var food_color := Color("ffd486")
@export var nose_color := Color("f2ffff")
@export var impact_color := Color("ff776b")
@export_range(0.05, 0.20) var radius := 0.18
@export var head_mesh: Mesh
@export var body_mesh: Mesh
@export var link_mesh: Mesh


func validate() -> PackedStringArray:
	if id.is_empty() or not is_finite(radius) or radius < 0.05 or radius > 0.20:
		return PackedStringArray(["Skin needs id and radius in [0.05, 0.20]"])
	return PackedStringArray()
