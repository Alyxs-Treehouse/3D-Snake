class_name SnakeModel
extends RefCounted
## Deterministic grid rules. No scene, hardware, rendering, wall clock or file access.
enum Phase { READY, RUNNING, PAUSED, GAME_OVER, WON }
var phase := Phase.READY
var body: Array[Vector3i] = []
var direction := Vector3i.RIGHT
var food := Vector3i(-1, -1, -1)
var score := 0
var food_eaten := 0
var end_reason := ""
var level: SnakeLevel
var _rng := RandomNumberGenerator.new()
var _occupied: Dictionary = {}
var _blocked: Dictionary = {}
var _free: Array[Vector3i] = []
var _free_index: Dictionary = {}
var _rules: Array[SnakeRule] = []


func configure(config: SnakeLevel, random_seed := -1) -> PackedStringArray:
	var errors := config.validate()
	if not errors.is_empty():
		return errors
	level = config.duplicate(true) as SnakeLevel
	if random_seed < 0:
		_rng.randomize()
	else:
		_rng.seed = random_seed
	reset()
	return errors


func reset() -> void:
	body.assign(level.initial_body)
	direction = level.initial_direction
	food = level.first_food
	score = 0
	food_eaten = 0
	end_reason = ""
	phase = Phase.READY
	_occupied.clear()
	_blocked.clear()
	_free.clear()
	_free_index.clear()
	for cell in body:
		_occupied[cell] = true
	for cell in level.obstacles:
		_blocked[cell] = true
	for x in level.grid_size.x:
		for y in level.grid_size.y:
			for z in level.grid_size.z:
				var cell := Vector3i(x, y, z)
				if not _occupied.has(cell) and not _blocked.has(cell):
					_add_free(cell)
	_rules.clear()
	for definition in level.rules:
		var rule := definition.duplicate(true) as SnakeRule
		rule.reset(self)
		_rules.append(rule)


func accepts(value: Vector3i) -> bool:
	return absi(value.x) + absi(value.y) + absi(value.z) == 1 and value != -direction


func step(intent: Vector3i) -> bool:
	if phase != Phase.RUNNING or not accepts(intent):
		return false
	direction = intent
	var next := body[0] + direction
	if not level.contains(next):
		return _finish("WALL")
	if _blocked.has(next):
		return _finish("OBSTACLE")
	var growing := next == food
	if _occupied.has(next) and (growing or next != body.back()):
		return _finish("SELF COLLISION")
	for rule in _rules:
		var reason := rule.collision_reason(next, self)
		if not reason.is_empty():
			return _finish(reason)
	if not growing:
		var tail: Vector3i = body.pop_back()
		_occupied.erase(tail)
		_add_free(tail)
	body.push_front(next)
	_occupied[next] = true
	_remove_free(next)
	if growing:
		var points := level.points_per_food
		for rule in _rules:
			points = rule.food_points(self, points)
		score += maxi(0, points)
		food_eaten += 1
		food = (
			_free[_rng.randi_range(0, _free.size() - 1)]
			if not _free.is_empty()
			else Vector3i(-1, -1, -1)
		)
	for rule in _rules:
		rule.after_step(self, growing)
	var won := _free.is_empty()
	for rule in _rules:
		won = won or rule.has_won(self)
	if won:
		phase = Phase.WON
		end_reason = "SPACE FILLED" if _free.is_empty() else "OBJECTIVE COMPLETE"
	return true


func _finish(reason: String) -> bool:
	phase = Phase.GAME_OVER
	end_reason = reason
	return false


func _add_free(cell: Vector3i) -> void:
	if _free_index.has(cell):
		return
	_free_index[cell] = _free.size()
	_free.append(cell)


func _remove_free(cell: Vector3i) -> void:
	if not _free_index.has(cell):
		return
	var index: int = _free_index[cell]
	var last: Vector3i = _free.back()
	_free[index] = last
	_free_index[last] = index
	_free.pop_back()
	_free_index.erase(cell)
