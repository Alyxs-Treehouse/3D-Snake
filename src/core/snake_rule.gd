class_name SnakeRule
extends Resource
## A per-round rule instance. Never mutate the authored resource or access scene nodes.


func validate() -> PackedStringArray:
	return PackedStringArray()


func reset(_model: RefCounted) -> void:
	pass


func collision_reason(_cell: Vector3i, _model: RefCounted) -> String:
	return ""


func food_points(_model: RefCounted, base_points: int) -> int:
	return base_points


func after_step(_model: RefCounted, _ate_food: bool) -> void:
	pass


func has_won(_model: RefCounted) -> bool:
	return false
