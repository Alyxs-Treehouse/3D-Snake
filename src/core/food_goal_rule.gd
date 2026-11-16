class_name FoodGoalRule
extends SnakeRule
## Example composable level objective, also used by the training room.
@export_range(1, 1000) var target_food := 3


func validate() -> PackedStringArray:
	return (
		PackedStringArray(["target_food must be positive"])
		if target_food < 1
		else PackedStringArray()
	)


func has_won(model: RefCounted) -> bool:
	return model.food_eaten >= target_food
