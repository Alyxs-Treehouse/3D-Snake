extends "res://tests/test_suite.gd"
const DIRECTIONS := [
	Vector3i.RIGHT, Vector3i.LEFT, Vector3i.UP, Vector3i.DOWN, Vector3i.BACK, Vector3i.FORWARD
]


func make_model(level := SnakeLevel.new()) -> SnakeModel:
	var model := SnakeModel.new()
	expect(model.configure(level, 42).is_empty(), "Valid authored level initializes model")
	model.phase = SnakeModel.Phase.RUNNING
	return model


func _run() -> void:
	var model := make_model()
	expect(
		not model.accepts(Vector3i.LEFT) and not model.accepts(Vector3i(1, 1, 0)),
		"Reverse and diagonal rejected"
	)
	for i in 3:
		expect(model.step(Vector3i.RIGHT), "Opening path traversable")
	expect(
		model.score == 10 and model.body.size() == 4 and model.food_eaten == 1,
		"Food grows and scores"
	)
	expect(
		model.level.contains(model.food) and not model.body.has(model.food),
		"Food generated in free cell"
	)
	var other := make_model()
	for i in 3:
		other.step(Vector3i.RIGHT)
	expect(other.food == model.food, "Same seed/input produces same food")
	var saved := model.body.duplicate()
	model.phase = SnakeModel.Phase.PAUSED
	expect(not model.step(Vector3i.RIGHT) and model.body == saved, "Pause freezes pure model")
	# All six faces and all eight corners, independently classified by face normal.
	for axis in 3:
		for side in [0, 7]:
			var at := Vector3i(3, 3, 3)
			at[axis] = side
			for direction in DIRECTIONS:
				boundary(at, direction, direction[axis] != (-1 if side == 0 else 1))
	for x in [0, 7]:
		for y in [0, 7]:
			for z in [0, 7]:
				for direction in DIRECTIONS:
					var at := Vector3i(x, y, z)
					var axis: int = 0 if direction.x else (1 if direction.y else 2)
					boundary(at, direction, direction[axis] == (1 if at[axis] == 0 else -1))
	var level := SnakeLevel.new()
	level.initial_body.assign(
		[Vector3i(2, 2, 2), Vector3i(1, 2, 2), Vector3i(1, 2, 3), Vector3i(2, 2, 3)]
	)
	level.initial_direction = Vector3i.BACK
	model = make_model(level)
	expect(model.step(Vector3i.BACK), "May enter vacating tail")
	level.initial_body.append(Vector3i(3, 2, 3))
	model = make_model(level)
	expect(
		not model.step(Vector3i.BACK) and model.end_reason == "SELF COLLISION",
		"Occupied middle segment collides"
	)
	level = SnakeLevel.new()
	level.obstacles = [Vector3i(3, 3, 1)]
	model = make_model(level)
	expect(
		not model.step(Vector3i.RIGHT) and model.end_reason == "OBSTACLE",
		"Level obstacles participate in rules"
	)
	level = SnakeLevel.new()
	var goal := FoodGoalRule.new()
	goal.target_food = 1
	level.rules = [goal]
	model = make_model(level)
	for i in 3:
		model.step(Vector3i.RIGHT)
	expect(
		model.phase == SnakeModel.Phase.WON and model.end_reason == "OBJECTIVE COMPLETE",
		"Composable objective wins without changing model code"
	)
	expect(
		goal.target_food == 1 and level.initial_body.size() == 3,
		"Authored resources remain unchanged"
	)
	# Fill a small board using a contiguous Hamiltonian path, leaving exactly one food cell.
	level = SnakeLevel.new()
	level.grid_size = Vector3i(2, 2, 2)
	level.initial_body.assign(
		[
			Vector3i(1, 1, 0),
			Vector3i(1, 1, 1),
			Vector3i(0, 1, 1),
			Vector3i(0, 1, 0),
			Vector3i(0, 0, 0),
			Vector3i(0, 0, 1),
			Vector3i(1, 0, 1)
		]
	)
	level.initial_direction = Vector3i.DOWN
	level.first_food = Vector3i(1, 0, 0)
	model = make_model(level)
	expect(
		model.step(Vector3i.DOWN) and model.phase == SnakeModel.Phase.WON and model.food.x == -1,
		"Full grid wins without spawn loop"
	)
	level.grid_size = Vector3i.ZERO
	expect(
		not model.configure(level).is_empty(),
		"Invalid level rejected before mutating running model"
	)
	expect(model.body.size() == 8, "Rejected level preserves previous state")
	finish()


func boundary(at: Vector3i, direction: Vector3i, valid: bool) -> void:
	var level := SnakeLevel.new()
	level.initial_body = [at]
	level.initial_direction = direction
	level.first_food = Vector3i(4, 4, 4)
	var model := make_model(level)
	var moved := model.step(direction)
	expect(
		(
			moved == valid
			and (model.phase == SnakeModel.Phase.RUNNING if valid else model.end_reason == "WALL")
		),
		"Boundary at %s toward %s" % [at, direction]
	)
