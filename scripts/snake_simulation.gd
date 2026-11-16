extends RefCounted
## Grid rules only: no rendering, headset, timing or controller dependency.

enum Phase { READY, RUNNING, PAUSED, GAME_OVER, WON }
const SIZE := 8
var phase := Phase.READY
var snake: Array[Vector3i] = []
var direction := Vector3i.RIGHT
var turns: Array[Vector3i] = []
var food := Vector3i(-1, -1, -1)
var score := 0
var end_reason := ""
var rng := RandomNumberGenerator.new()


func _init() -> void:
	rng.randomize()
	reset()


func reset() -> void:
	snake.assign([Vector3i(2, 3, 1), Vector3i(1, 3, 1), Vector3i(0, 3, 1)])
	direction = Vector3i.RIGHT
	turns.clear()
	food = Vector3i(5, 3, 1)
	score = 0
	end_reason = ""
	phase = Phase.READY


func toggle_running() -> void:
	if phase in [Phase.READY, Phase.PAUSED]:
		phase = Phase.RUNNING
	elif phase == Phase.RUNNING:
		phase = Phase.PAUSED


func queue_turn(value: Vector3i) -> bool:
	if phase != Phase.RUNNING or absi(value.x) + absi(value.y) + absi(value.z) != 1 or turns.size() >= 2:
		return false
	var previous: Vector3i = direction if turns.is_empty() else turns.back()
	if value == previous or value == -previous:
		return false
	turns.append(value)
	return true


func step() -> bool:
	if phase != Phase.RUNNING:
		return false
	if not turns.is_empty():
		direction = turns.pop_front()
	var next := snake[0] + direction
	if not inside(next):
		_finish("WALL")
		return false
	var growing := next == food
	# The tail leaves its cell on a non-growing move, so entering it is legal.
	var occupied := snake.size() if growing else snake.size() - 1
	for i in occupied:
		if snake[i] == next:
			_finish("SELF COLLISION")
			return false
	snake.push_front(next)
	if growing:
		score += 10
		_spawn_food()
	else:
		snake.pop_back()
	return true


func steer(value: Vector3i) -> bool:
	# Continuous control replaces stale queued intent; it never stacks future turns.
	if phase != Phase.RUNNING or absi(value.x) + absi(value.y) + absi(value.z) != 1:
		return false
	turns.clear()
	if value == -direction:
		return false
	if value != direction:
		turns.append(value)
	return true


func _spawn_food() -> void:
	var free: Array[Vector3i] = []
	var occupied := {}
	for cell in snake:
		occupied[cell] = true
	for x in SIZE:
		for y in SIZE:
			for z in SIZE:
				var cell := Vector3i(x, y, z)
				if not occupied.has(cell):
					free.append(cell)
	if free.is_empty():
		food = Vector3i(-1, -1, -1)
		phase = Phase.WON
		end_reason = "SPACE FILLED"
	else:
		food = free[rng.randi_range(0, free.size() - 1)]


func _finish(reason: String) -> void:
	phase = Phase.GAME_OVER
	end_reason = reason
	turns.clear()


static func inside(cell: Vector3i) -> bool:
	return cell.x >= 0 and cell.x < SIZE and cell.y >= 0 and cell.y < SIZE and cell.z >= 0 and cell.z < SIZE
