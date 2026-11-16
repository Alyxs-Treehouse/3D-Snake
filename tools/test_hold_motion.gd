extends SceneTree

const Game = preload("res://scripts/snake_game.gd")
const Sim = preload("res://scripts/snake_simulation.gd")
const Router = preload("res://scripts/snake_input_router.gd")
var checks := 0
var failures := 0

func _initialize() -> void:
	_run.call_deferred()

func expect(ok: bool, description: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error("HOLD TEST: " + description)

func tick(game: Node3D, seconds: float) -> void:
	var remaining := seconds
	while remaining > 0.0001:
		var dt := minf(0.05, remaining)
		game._update_motion(dt)
		remaining -= dt

func key(game: Node3D, code: Key, pressed: bool) -> void:
	var event := InputEventKey.new()
	event.physical_keycode = code
	event.pressed = pressed
	game._input(event)
	game._process(0.02)

func _run() -> void:
	var game := Game.new()
	root.add_child(game)
	game.set_process(false)
	game.toggle_play()
	var initial := game.simulation.snake.duplicate()
	tick(game, 5.0)
	expect(game.countdown == 0 and game.simulation.snake == initial, "Countdown ending never starts automatic movement")
	game.advance()
	expect(game.simulation.snake == initial, "No-input movement cannot be advanced directly")
	game._steer_sticks(Vector2.ZERO, Vector2.ZERO, Basis.IDENTITY)
	game._steer_sticks(Vector2.RIGHT, Vector2.ZERO, Basis.IDENTITY)
	tick(game, 0.2)
	expect(game.board.bodies[0].position.x > Game.BoardView.cell_position(initial[0]).x, "Holding right stick moves visibly")
	game._steer_sticks(Vector2.ZERO, Vector2.ZERO, Basis.IDENTITY)
	var stopped := game.board.bodies[0].position
	var cells := game.simulation.snake.duplicate()
	var elapsed: float = game.elapsed
	tick(game, 4.0)
	expect(game.move_intent == Vector3i.ZERO and game.simulation.turns.is_empty(), "Neutral cancels active and queued intent")
	expect(game.board.bodies[0].position == stopped and game.simulation.snake == cells and game.elapsed == elapsed, "Release freezes both animation and simulation mid-cell")
	game._steer_sticks(Vector2.ZERO, Vector2.ZERO, Basis(Vector3.UP, PI/2))
	tick(game, 1.0)
	expect(game.board.bodies[0].position == stopped, "Looking around while neutral never moves snake")
	game._steer_sticks(Vector2.RIGHT, Vector2.ZERO, Basis.IDENTITY)
	tick(game, 0.1)
	expect(game.board.bodies[0].position.x > stopped.x, "Re-engage continues from frozen visual position")
	game._steer_sticks(Vector2.LEFT, Vector2.ZERO, Basis.IDENTITY)
	stopped = game.board.bodies[0].position
	tick(game, 1.0)
	expect(game.move_intent == Vector3i.ZERO and game.board.bodies[0].position == stopped, "Forbidden reverse stops instead of continuing old course")
	game._steer_sticks(Vector2.RIGHT, Vector2(0,1), Basis.IDENTITY)
	expect(game.move_intent == Vector3i.UP, "Held left vertical takes priority")
	game._steer_sticks(Vector2.RIGHT, Vector2.ZERO, Basis.IDENTITY)
	expect(game.move_intent == Vector3i.RIGHT, "Release left restores right only when right is still held")
	game._steer_sticks(Vector2.ZERO, Vector2(0,-1), Basis.IDENTITY)
	expect(game.move_intent == Vector3i.DOWN, "Held left back drives downward")
	game._steer_sticks(Vector2.ZERO, Vector2.ZERO, Basis.IDENTITY)
	expect(game.move_intent == Vector3i.ZERO, "Release vertical input stops")
	game._steer_sticks(Vector2.ZERO, Vector2.ZERO, Basis.IDENTITY, true, false)
	expect(game.move_intent == Vector3i.UP, "Right A must be held for up")
	game._steer_sticks(Vector2.ZERO, Vector2.ZERO, Basis.IDENTITY)
	expect(game.move_intent == Vector3i.ZERO, "Right A release stops")
	game._steer_sticks(Vector2.ZERO, Vector2.ZERO, Basis.IDENTITY, false, true)
	expect(game.move_intent == Vector3i.DOWN, "Right B must be held for down")
	game._steer_sticks(Vector2.ZERO, Vector2.ZERO, Basis.IDENTITY, true, true)
	expect(game.move_intent == Vector3i.ZERO, "Opposite vertical buttons cancel")
	game._lost_focus()
	expect(game.move_intent == Vector3i.ZERO and game.held_keys.is_empty(), "Focus loss clears all held inputs")
	game.toggle_play()
	game._steer_sticks(Vector2.RIGHT, Vector2.ZERO, Basis.IDENTITY, true, false)
	expect(game.move_intent == Vector3i.ZERO, "Resume with held controls cannot auto-start")
	game._steer_sticks(Vector2.ZERO, Vector2.ZERO, Basis.IDENTITY)
	game._steer_sticks(Vector2.RIGHT, Vector2.ZERO, Basis.IDENTITY)
	expect(game.move_intent == Vector3i.RIGHT, "Neutral then re-engage resumes movement")
	# Keyboard uses press AND release events; the frame loop polls the held set.
	game.restart()
	game.countdown = 0
	key(game, KEY_D, true)
	expect(game.move_intent == Vector3i.RIGHT, "Keyboard press activates held movement")
	key(game, KEY_D, false)
	stopped = game.board.bodies[0].position
	game._process(0.1)
	expect(game.move_intent == Vector3i.ZERO and game.board.bodies[0].position == stopped, "Keyboard key-up immediately stops")
	key(game, KEY_Q, true)
	expect(game.move_intent == Vector3i.UP, "Held Q controls up")
	key(game, KEY_Q, false)
	expect(game.move_intent == Vector3i.ZERO, "Release Q stops")
	key(game, KEY_E, true)
	expect(game.move_intent == Vector3i.DOWN, "Held E controls down")
	key(game, KEY_E, false)
	expect(game.move_intent == Vector3i.ZERO, "Release E stops")
	expect(Router.keyboard({KEY_W:true, KEY_S:true}, Basis.IDENTITY, Basis.IDENTITY) == Vector3i.ZERO, "Opposite keyboard directions cancel")
	key(game, KEY_D, true)
	game._lost_focus()
	game.toggle_play()
	game._process(0.1)
	expect(game.move_intent == Vector3i.ZERO, "Lost key-up on focus loss cannot stick movement")
	game._refresh_hud()
	expect("HOLD TO MOVE" in game.board.status.text, "HUD makes idle-running distinct from paused")
	# Existing wall rule still applies, but waiting near a wall is safe indefinitely.
	game.restart()
	game.countdown = 0
	game.simulation.snake.assign([Vector3i(7,3,3), Vector3i(6,3,3), Vector3i(5,3,3)])
	game.board.sync(game.simulation.snake, game.simulation.food, game.simulation.direction, true)
	tick(game, 8.0)
	expect(game.simulation.phase == Sim.Phase.RUNNING, "Neutral at boundary never crashes autonomously")
	game._apply_move_intent(Vector3i.RIGHT)
	tick(game, 0.05)
	expect(game.simulation.end_reason == "WALL", "Deliberately holding toward wall still collides")
	game.restart()
	tick(game, 5.0)
	expect(game.move_intent == Vector3i.ZERO and game.simulation.snake == initial, "Restart clears held state and stays still after countdown")
	game.free()
	print("HOLD TESTS: ", checks, " checks, ", failures, " failures (synthetic input)")
	quit(0 if failures == 0 else 1)
