extends SceneTree
var checks := 0
var failures := 0


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	finish()


func expect(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error("TEST: " + message)


func finish() -> void:
	print(
		"TEST SUITE ", get_script().resource_path, ": ", checks, " checks, ", failures, " failures"
	)
	quit(0 if failures == 0 else 1)


func tick(session: GameSession, seconds: float) -> void:
	var remaining := seconds
	while remaining > 0.00001:
		var dt := minf(0.05, remaining)
		session.tick(dt)
		remaining -= dt
