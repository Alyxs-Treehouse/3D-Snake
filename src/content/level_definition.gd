class_name SnakeLevel
extends Resource
## Immutable authored data; GameSession clones it before starting a round.
const MAX_CELLS := 4096
@export var id := "classic"
@export var display_name := "Spatial Snake"
@export var grid_size := Vector3i(8, 8, 8)
@export var cell_size := Vector3(0.8, 0.5, 0.8)
@export_range(0.1, 5.0) var step_seconds := 0.75
@export_range(0.0, 10.0) var countdown_seconds := 3.0
@export var initial_body: Array[Vector3i] = _default_body()
@export var initial_direction := Vector3i.RIGHT
@export var first_food := Vector3i(5, 3, 1)
@export var points_per_food := 10
@export var obstacles: Array[Vector3i] = []
@export var rules: Array[SnakeRule] = []
@export var tutorial: TutorialDefinition


static func _default_body() -> Array[Vector3i]:
	return [Vector3i(2, 3, 1), Vector3i(1, 3, 1), Vector3i(0, 3, 1)]


func volume() -> int:
	return grid_size.x * grid_size.y * grid_size.z


func contains(cell: Vector3i) -> bool:
	return (
		cell.x >= 0
		and cell.x < grid_size.x
		and cell.y >= 0
		and cell.y < grid_size.y
		and cell.z >= 0
		and cell.z < grid_size.z
	)


func position_of(cell: Vector3i) -> Vector3:
	return (
		(Vector3(cell) + Vector3(0.5, 0.5, 0.5) - Vector3(grid_size.x * 0.5, 0, grid_size.z * 0.5))
		* cell_size
	)


func room_size() -> Vector3:
	return Vector3(grid_size) * cell_size


func validate() -> PackedStringArray:
	var errors := PackedStringArray()
	if id.is_empty():
		errors.append("Level id is required")
	if grid_size.x < 2 or grid_size.y < 2 or grid_size.z < 2 or volume() > MAX_CELLS:
		errors.append("Grid dimensions must be >= 2 and total cells <= %d" % MAX_CELLS)
	if not cell_size.is_finite() or cell_size.x < 0.5 or cell_size.y < 0.5 or cell_size.z < 0.5:
		errors.append("Cell dimensions must be finite and >= 0.5 metres")
	if (
		not is_finite(step_seconds)
		or step_seconds < 0.1
		or not is_finite(countdown_seconds)
		or countdown_seconds < 0
	):
		errors.append("Invalid movement/countdown timing")
	if points_per_food < 0:
		errors.append("Food points cannot be negative")
	if absi(initial_direction.x) + absi(initial_direction.y) + absi(initial_direction.z) != 1:
		errors.append("Initial direction must be cardinal")
	if initial_body.is_empty():
		errors.append("Initial body cannot be empty")
	var occupied := {}
	for i in initial_body.size():
		var cell := initial_body[i]
		if not contains(cell) or occupied.has(cell):
			errors.append("Invalid/duplicate initial body cell")
		if i > 0 and Vector3(cell - initial_body[i - 1]).length_squared() != 1:
			errors.append("Initial body must be contiguous")
		occupied[cell] = true
	if initial_body.size() > 1 and initial_body[0] + initial_direction == initial_body[1]:
		errors.append("Initial direction points into the neck")
	for cell in obstacles:
		if not contains(cell) or occupied.has(cell):
			errors.append("Invalid/overlapping obstacle")
		occupied[cell] = true
	if not contains(first_food) or occupied.has(first_food):
		errors.append("First food must occupy a free cell")
	for rule in rules:
		if rule == null:
			errors.append("Null rule")
		else:
			errors.append_array(rule.validate())
	if tutorial != null:
		errors.append_array(tutorial.validate())
	return errors
