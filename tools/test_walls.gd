extends SceneTree

const Sim = preload("res://scripts/snake_simulation.gd")
const Game = preload("res://scripts/snake_game.gd")
const View = preload("res://scripts/board_view.gd")
const DIRECTIONS = [Vector3i.RIGHT, Vector3i.LEFT, Vector3i.UP, Vector3i.DOWN, Vector3i.BACK, Vector3i.FORWARD]
var checks := 0
var failures := 0

func _initialize() -> void:
	_run.call_deferred()

func expect(ok: bool, description: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error("WALL TEST: " + description)

func check_step(at: Vector3i, direction: Vector3i, should_move: bool) -> void:
	var sim := Sim.new()
	sim.snake.assign([at])
	sim.food = Vector3i(3,3,3)
	sim.direction = direction
	sim.toggle_running()
	var moved := sim.step()
	expect(moved == should_move and (sim.phase == Sim.Phase.RUNNING if should_move else sim.end_reason == "WALL"), "Boundary step from %s toward %s" % [at, direction])

func _run() -> void:
	# At each face, tangential/inward moves survive; only its outward normal dies.
	for axis in 3:
		for side in [0,7]:
			var at := Vector3i(3,3,3)
			at[axis] = side
			for direction in DIRECTIONS:
				var outward: bool = direction[axis] == (-1 if side == 0 else 1)
				check_step(at, direction, not outward)
	# All eight corners: inward along any axis is legal; outward crosses a face.
	for x in [0,7]:
		for y in [0,7]:
			for z in [0,7]:
				var at := Vector3i(x,y,z)
				for direction in DIRECTIONS:
					var axis: int = 0 if direction.x else (1 if direction.y else 2)
					check_step(at, direction, direction[axis] == (1 if at[axis] == 0 else -1))
	# Body segments may occupy an edge while the head turns along either wall.
	var sim := Sim.new()
	sim.snake.assign([Vector3i(7,3,1),Vector3i(7,3,0),Vector3i(6,3,0)])
	sim.food = Vector3i(3,3,3)
	sim.direction = Vector3i.BACK
	sim.toggle_running()
	for i in 6:
		expect(sim.step(), "Travel along a wall with body on corner")
	expect(sim.steer(Vector3i.UP) and sim.step(), "Turn upward along a two-wall edge")
	var game := Game.new()
	root.add_child(game)
	game.set_process(false)
	# Reproduce: visually travelling parallel to x wall, then turn into x wall.
	game.simulation.snake.assign([Vector3i(7,3,1),Vector3i(7,3,2),Vector3i(7,3,3)])
	game.simulation.food = Vector3i(3,3,3)
	game.simulation.direction = Vector3i.FORWARD
	game.board.sync(game.simulation.snake, game.simulation.food, game.simulation.direction, true)
	game.toggle_play()
	game.countdown = 0
	game._apply_move_intent(Vector3i.RIGHT)
	game.advance()
	expect(game.simulation.end_reason == "WALL", "Turning into adjacent wall is a real collision")
	expect(game.board.head_direction == Vector3.RIGHT, "Failed turn must update rendered head direction, not retain parallel heading")
	var before_impact := game.board.bodies[0].position
	game._process(0.05)
	expect(game.board.bodies[0].position.x > before_impact.x and game.board.bodies[0].position.x < 3.2, "Impact visibly approaches the correct wall")
	for i in 5:
		game._process(0.05)
	expect(is_equal_approx(game.board.nose.position.x + View.NOSE_RADIUS, 3.2), "Nose surface stops at actual wall, not short of it")
	expect(Sim.inside(game.simulation.snake[0]), "Visual impact keeps logical head in last valid cell")
	# Each wall, including floor and ceiling, ends at its visible contact plane.
	for direction in DIRECTIONS:
		var at := Vector3i(3,3,3)
		var axis: int = 0 if direction.x else (1 if direction.y else 2)
		at[axis] = 7 if direction[axis] > 0 else 0
		game.board.sync([at], Vector3i(4,4,4), direction, true)
		game.board.show_wall_collision(direction)
		game.board.animate(1.0, 1.0)
		var contact := game.board.nose.position + Vector3(direction) * View.NOSE_RADIUS
		var plane: float = (4.0 if direction.y > 0 else 0.0) if axis == 1 else 3.2 * direction[axis]
		expect(is_equal_approx(contact[axis], plane), "Impact contacts wall plane %s" % direction)
	game.restart()
	expect(game.board.wall_hit_offset == Vector3.ZERO and game.wall_impact_seconds == 0, "Restart clears impact presentation")
	game.free()
	print("WALL TESTS: ", checks, " checks, ", failures, " failures (synthetic input)")
	quit(0 if failures == 0 else 1)
