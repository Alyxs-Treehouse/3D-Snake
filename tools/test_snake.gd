extends SceneTree

const Sim = preload("res://scripts/snake_simulation.gd")
const Router = preload("res://scripts/snake_input_router.gd")
const View = preload("res://scripts/board_view.gd")
const Game = preload("res://scripts/snake_game.gd")
var failures := 0
var checks := 0

func _initialize() -> void:
	_run.call_deferred()

func expect(value: bool, description: String) -> void:
	checks += 1
	if not value:
		failures += 1
		push_error("SNAKE TEST: " + description)

func _run() -> void:
	var sim := Sim.new()
	expect(not sim.step(), "Ready game must not move")
	sim.toggle_running()
	expect(not sim.queue_turn(Vector3i.LEFT), "Immediate reversal is rejected")
	expect(not sim.queue_turn(Vector3i(1, 1, 0)), "Diagonal directions are rejected")
	for i in 3:
		expect(sim.step(), "Opening path is traversable")
	expect(sim.score == 10 and sim.snake.size() == 4, "Food grows the snake and scores")
	expect(Sim.inside(sim.food) and not sim.snake.has(sim.food), "Food spawns in a free cell")
	var saved := sim.snake.duplicate()
	sim.toggle_running()
	expect(not sim.step() and sim.snake == saved, "Pause freezes simulation")
	sim.toggle_running()
	sim.food = Vector3i(0, 7, 7)
	while sim.phase == Sim.Phase.RUNNING:
		sim.step()
	expect(sim.end_reason == "WALL" and Sim.inside(sim.snake[0]), "Wall collision ends at last valid cell")
	sim.reset()
	expect(sim.phase == Sim.Phase.READY and sim.score == 0 and sim.snake.size() == 3, "Restart resets the round")
	sim.toggle_running()
	expect(sim.queue_turn(Vector3i.UP) and sim.queue_turn(Vector3i.LEFT), "Two rapid legal turns may queue")
	expect(not sim.queue_turn(Vector3i.BACK), "Queue is bounded")
	sim.step()
	expect(sim.direction == Vector3i.UP, "Only one turn consumed per tick")
	sim.step()
	expect(sim.direction == Vector3i.LEFT, "Second turn is relative to first queued turn")
	# Entering a vacating tail is legal; entering an occupied middle segment is not.
	sim.snake.assign([Vector3i(2,2,2), Vector3i(1,2,2), Vector3i(1,2,3), Vector3i(2,2,3)])
	sim.direction = Vector3i.BACK
	sim.food = Vector3i(7,7,7)
	expect(sim.step() and sim.phase == Sim.Phase.RUNNING, "Can move into the vacating tail")
	sim.snake.assign([Vector3i(2,2,2), Vector3i(1,2,2), Vector3i(1,2,3), Vector3i(2,2,3), Vector3i(3,2,3)])
	sim.direction = Vector3i.BACK
	expect(not sim.step() and sim.end_reason == "SELF COLLISION", "Body collision is detected")
	sim.reset()
	sim.snake.clear()
	for x in 8:
		for y in 8:
			for z in 8:
				sim.snake.append(Vector3i(x,y,z))
	sim._spawn_food()
	expect(sim.phase == Sim.Phase.WON and sim.food.x == -1, "Full grid wins without an infinite spawn loop")
	# Exercise spawn near capacity, not only on the sparse opening board.
	sim.snake.erase(Vector3i(7,7,7))
	sim._spawn_food()
	expect(sim.food == Vector3i(7,7,7), "Last available cell is selected")
	var router := Router.new()
	expect(router.stick(Vector2(0.1,0), Basis.IDENTITY, Basis.IDENTITY) == Vector3i.ZERO, "Stick deadzone")
	expect(router.stick(Vector2(0,1), Basis.IDENTITY, Basis.IDENTITY) == Vector3i.FORWARD, "Positive OpenXR stick Y means forward")
	expect(router.stick(Vector2(1,0), Basis.IDENTITY, Basis.IDENTITY) == Vector3i.RIGHT, "Held stick follows changes without requiring neutral")
	router.stick(Vector2.ZERO, Basis.IDENTITY, Basis.IDENTITY)
	expect(router.stick(Vector2(1,0), Basis.IDENTITY, Basis.IDENTITY) == Vector3i.RIGHT, "Neutral rearms the stick")
	var turned := Basis(Vector3.UP, PI / 2)
	expect(Router.horizontal(Vector2(0,1), turned, Basis.IDENTITY) == Vector3i.LEFT, "Turns are view-relative")
	expect(Router.horizontal(Vector2(0,1), turned, turned) == Vector3i.FORWARD, "Arena orientation accounted for")
	expect(Router.key_direction(KEY_Q, Basis.IDENTITY, Basis.IDENTITY) == Vector3i.UP, "Keyboard vertical input")
	var game := Game.new()
	root.add_child(game)
	game.set_process(false)
	expect(game.desktop_camera.position == Vector3(0,1.65,0), "Observer starts inside the room")
	expect(View.cell_position(Vector3i.ZERO).x < 0 and View.cell_position(Vector3i(7,7,7)).x > 0, "Arena encloses the observer on both sides")
	game.toggle_play()
	game.countdown = 0
	game._apply_move_intent(Vector3i.RIGHT)
	for i in 3:
		game.advance()
	game._refresh_hud()
	expect(game.simulation.score == 10 and game.board.bodies.size() == 4, "Game scene wires growth to rendered bodies")
	game._lost_focus()
	expect(game.simulation.phase == Sim.Phase.PAUSED, "Focus loss pauses game")
	var before := game.simulation.snake.duplicate()
	game._process(10.0)
	expect(game.simulation.snake == before, "Background time cannot advance game")
	game.xr_active = true
	game._on_controller_button("ax_button", true)
	expect(game.simulation.phase == Sim.Phase.RUNNING, "Left X resumes")
	game._steer_sticks(Vector2.ZERO, Vector2.ZERO, Basis.IDENTITY)
	game._steer_sticks(Vector2.ZERO, Vector2.ZERO, Basis.IDENTITY, true, false)
	expect(game.move_intent == Vector3i.UP, "Held right A maps to upward movement")
	game._on_controller_button("by_button", true)
	expect(game.simulation.score == 0 and game.countdown == 3, "Left Y restarts with countdown")
	var start := game.simulation.snake.duplicate()
	game.held_keys[KEY_D] = true
	for i in 20:
		game._process(0.1)
	expect(game.simulation.snake == start, "Countdown does not move the snake early")
	for i in 15:
		game._process(0.1)
	expect(game.simulation.snake != start, "Frame loop moves after countdown")
	game.toggle_play()
	var progress: float = game.elapsed
	game._process(1.0)
	expect(is_equal_approx(game.elapsed, progress), "Pause also freezes visual interpolation")
	game.restart()
	game.countdown = 0
	game.held_keys[KEY_D] = true
	for i in 70:
		game._process(0.1)
	expect(game.simulation.phase == Sim.Phase.GAME_OVER, "Complete frame-driven round ends on wall")
	game._refresh_hud()
	expect("RETRY" in game.board.status.text, "Ended round exposes retry action")
	game.free()
	print("SNAKE TESTS: ", checks, " checks, ", failures, " failures (synthetic input; no hardware claims)")
	quit(0 if failures == 0 else 1)
