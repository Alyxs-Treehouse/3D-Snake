extends "res://tests/test_suite.gd"
const GAME = preload("res://scenes/game/game.tscn")


func key(game: SnakeGame, code: Key, pressed: bool) -> void:
	var event := InputEventKey.new()
	event.physical_keycode = code
	event.pressed = pressed
	game._input(event)
	game._process(0.02)


func frames(game: SnakeGame, count: int) -> void:
	for i in count:
		game._process(0.05)


func _run() -> void:
	var game := GAME.instantiate() as SnakeGame
	game.save_enabled = false
	root.add_child(game)
	game.set_process(false)
	game.rig.set_process(false)
	expect(game.rig.camera().position == Vector3(0, 1.65, 0), "Observer stays inside room")
	expect(game.session.model.level.id == "classic", "Default scene loads classic content")
	game.session.toggle_play()
	var initial := game.session.model.body.duplicate()
	frames(game, 100)
	expect(game.session.model.body == initial, "Scene does not move automatically after countdown")
	key(game, KEY_D, true)
	frames(game, 4)
	var renderer := game.arena.snake
	var moving := renderer.body_position(0)
	expect(
		moving.x > game.session.model.level.position_of(initial[0]).x,
		"Held key drives actual renderer"
	)
	key(game, KEY_D, false)
	var stopped := renderer.body_position(0)
	var progress := game.session.elapsed
	frames(game, 60)
	expect(
		renderer.body_position(0) == stopped and game.session.elapsed == progress,
		"Release freezes rendered head mid-cell"
	)
	key(game, KEY_D, true)
	frames(game, 3)
	expect(renderer.body_position(0).x > stopped.x, "Re-engage resumes interpolation")
	key(game, KEY_A, true)
	key(game, KEY_D, false)
	stopped = renderer.body_position(0)
	frames(game, 10)
	expect(
		game.session.intent == Vector3i.ZERO and renderer.body_position(0) == stopped,
		"Reverse stops rather than running old direction"
	)
	game.rig.focus_lost.emit()
	expect(game.session.model.phase == SnakeModel.Phase.PAUSED, "Rig focus signal pauses session")
	game.session.toggle_play()
	frames(game, 10)
	expect(game.session.intent == Vector3i.ZERO, "Lost key-up cannot resume stale movement")
	expect(game.select_level("training") == OK, "Load another authored level through public API")
	expect(
		game.tutorial.instruction() != "" and game.session.model.level.step_seconds == 1.0,
		"Level config drives tutorial and speed"
	)
	expect(
		game.select_skin("sunset") == OK and game.arena.snake.skin.id == "sunset",
		"Swap skin independently of rules"
	)
	expect(game.select_skin("mint") == OK, "Restore original skin")
	expect(
		(
			game.select_level("unknown") == ERR_DOES_NOT_EXIST
			and game.session.model.level.id == "training"
		),
		"Bad level lookup preserves active level"
	)
	var custom := SnakeLevel.new()
	custom.id = "non_cubic"
	custom.grid_size = Vector3i(10, 6, 12)
	custom.cell_size = Vector3(0.6, 0.7, 0.9)
	expect(game.load_level(custom) == OK, "Non-cubic authored level loads")
	expect(
		game.arena.snake.bodies.multimesh.instance_count == 720,
		"Pool capacity follows level dimensions"
	)
	expect(
		game.arena.snake.body_position(0).is_equal_approx(Vector3(-1.5, 2.45, -4.05)),
		"Geometry follows authored cell dimensions"
	)
	# Failed turn updates rendered heading and contact plane for all six walls.
	for direction in [
		Vector3i.RIGHT, Vector3i.LEFT, Vector3i.UP, Vector3i.DOWN, Vector3i.BACK, Vector3i.FORWARD
	]:
		var level := SnakeLevel.new()
		var axis: int = 0 if direction.x else (1 if direction.y else 2)
		var at := Vector3i(3, 3, 3)
		at[axis] = 7 if direction[axis] > 0 else 0
		level.initial_body = [at]
		level.initial_direction = direction
		level.first_food = Vector3i(4, 4, 4)
		expect(game.load_level(level) == OK, "Boundary fixture loads")
		game.session.toggle_play()
		game.session.countdown = 0
		game.session.submit_intent(direction)
		game.session.advance()
		for i in 5:
			game.arena.snake.present(1, 0.05)
		var snake := game.arena.snake
		var contact := snake.nose.position + Vector3(direction) * SnakeRenderer.NOSE_RADIUS
		var plane: float = (4.0 if direction.y > 0 else 0.0) if axis == 1 else 3.2 * direction[axis]
		expect(
			snake.head_direction == Vector3(direction) and is_equal_approx(contact[axis], plane),
			"Actual collision direction and wall plane preserved"
		)
	game.select_level("classic")
	var cells: Array[Vector3i] = []
	for x in 8:
		for y in 8:
			for z in 8:
				cells.append(Vector3i(x, y, z))
	var nodes := game.arena.snake.get_child_count()
	game.arena.snake.sync(cells, Vector3i.RIGHT, true)
	expect(
		nodes == 4 and game.arena.snake.get_child_count() == 4,
		"512 segments do not create additional render nodes"
	)
	expect(
		game.arena.snake.bodies.multimesh.visible_instance_count == 511,
		"All long-snake segments submitted in one body batch"
	)
	game.session.restart()
	expect(
		(
			game.arena.snake.length == 3
			and game.arena.snake.bodies.multimesh.visible_instance_count == 2
		),
		"Restart shrinks visible instance count without freeing pool"
	)
	game.free()
	finish()
