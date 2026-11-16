extends "res://tests/test_suite.gd"


func _run() -> void:
	var session := GameSession.new()
	expect(session.configure(SnakeLevel.new(), 42).is_empty(), "Session configures")
	var initial := session.model.body.duplicate()
	session.toggle_play()
	tick(session, 5)
	expect(
		session.countdown == 0 and session.model.body == initial, "No auto movement after countdown"
	)
	session.advance()
	expect(session.model.body == initial, "No input cannot advance")
	session.submit_intent(Vector3i.UP)
	session.submit_intent(Vector3i.FORWARD)
	session.advance()
	expect(session.model.direction == Vector3i.FORWARD, "Latest current intent replaces stale turn")
	session.submit_intent(Vector3i.ZERO)
	var progress := session.elapsed
	var body := session.model.body.duplicate()
	tick(session, 10)
	expect(
		session.elapsed == progress and session.model.body == body,
		"Release freezes clock and grid indefinitely"
	)
	session.submit_intent(Vector3i.BACK)
	tick(session, 1)
	expect(
		session.intent == Vector3i.ZERO and session.model.body == body,
		"Invalid reverse stops old movement"
	)
	session.submit_intent(Vector3i.RIGHT)
	session.pause()
	expect(session.intent == Vector3i.ZERO, "Pause clears intent")
	session.toggle_play()
	tick(session, 1)
	expect(session.model.body == body, "Resume cannot replay old input")
	session.restart()
	expect(
		session.countdown == 3 and session.model.body == initial, "Restart resets all round state"
	)
	var source := ControllerIntentSource.new()
	session.input_reset_requested.connect(source.reset)
	session.restart()
	expect(
		(
			source.sample_values(Vector2.RIGHT, Vector2.ZERO, Basis.IDENTITY, Basis.IDENTITY)
			== Vector3i.ZERO
		),
		"Held stick requires neutral after restart"
	)
	source.sample_values(Vector2.ZERO, Vector2.ZERO, Basis.IDENTITY, Basis.IDENTITY)
	expect(
		(
			source.sample_values(Vector2.RIGHT, Vector2.ZERO, Basis.IDENTITY, Basis.IDENTITY)
			== Vector3i.RIGHT
		),
		"Re-engaging after neutral works"
	)
	expect(
		(
			source.sample_values(Vector2.RIGHT, Vector2(0, 1), Basis.IDENTITY, Basis.IDENTITY)
			== Vector3i.UP
		),
		"Left vertical wins simultaneous input"
	)
	expect(
		(
			source.sample_values(Vector2.RIGHT, Vector2.ZERO, Basis.IDENTITY, Basis.IDENTITY)
			== Vector3i.RIGHT
		),
		"Releasing left restores held right"
	)
	expect(
		(
			source.sample_values(Vector2.ZERO, Vector2.ZERO, Basis.IDENTITY, Basis.IDENTITY)
			== Vector3i.ZERO
		),
		"Both neutral stops"
	)
	expect(
		(
			source.sample_values(
				Vector2.ZERO, Vector2.ZERO, Basis.IDENTITY, Basis.IDENTITY, true, false
			)
			== Vector3i.UP
		),
		"A held moves up"
	)
	expect(
		(
			source.sample_values(Vector2.ZERO, Vector2.ZERO, Basis.IDENTITY, Basis.IDENTITY)
			== Vector3i.ZERO
		),
		"A release stops"
	)
	expect(
		(
			source.sample_values(
				Vector2.ZERO, Vector2.ZERO, Basis.IDENTITY, Basis.IDENTITY, false, true
			)
			== Vector3i.DOWN
		),
		"B held moves down"
	)
	expect(
		(
			source.sample_values(
				Vector2.ZERO, Vector2.ZERO, Basis.IDENTITY, Basis.IDENTITY, true, true
			)
			== Vector3i.ZERO
		),
		"A and B cancel"
	)
	source.reset()
	expect(
		(
			source.sample_values(
				Vector2.ZERO, Vector2.ZERO, Basis.IDENTITY, Basis.IDENTITY, true, false
			)
			== Vector3i.ZERO
		),
		"Buttons require release after resume too"
	)
	expect(
		not source.available() and source.sample(Basis.IDENTITY, Basis.IDENTITY) == Vector3i.ZERO,
		"Tracking unavailable returns neutral"
	)
	var keyboard := KeyboardIntentSource.new()
	var event := InputEventKey.new()
	event.physical_keycode = KEY_D
	event.pressed = true
	keyboard.handle_event(event)
	expect(keyboard.sample(Basis.IDENTITY, Basis.IDENTITY) == Vector3i.RIGHT, "Keyboard held state")
	event.pressed = false
	keyboard.handle_event(event)
	expect(
		keyboard.sample(Basis.IDENTITY, Basis.IDENTITY) == Vector3i.ZERO, "Keyboard release stops"
	)
	event.pressed = true
	keyboard.handle_event(event)
	keyboard.reset()
	expect(
		keyboard.sample(Basis.IDENTITY, Basis.IDENTITY) == Vector3i.ZERO,
		"Lost key-up cannot leave stale movement"
	)
	finish()
