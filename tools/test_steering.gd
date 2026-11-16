extends SceneTree

const Router = preload("res://scripts/snake_input_router.gd")
const Sim = preload("res://scripts/snake_simulation.gd")
const Game = preload("res://scripts/snake_game.gd")
var checks := 0
var failures := 0

func _initialize() -> void:
	_run.call_deferred()

func expect(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error("STEERING TEST: " + message)

func _run() -> void:
	var router := Router.new()
	# Rotate the player through a full turn while holding forward, no stick release.
	var expected := [Vector3i.FORWARD, Vector3i.LEFT, Vector3i.BACK, Vector3i.RIGHT]
	for i in 4:
		expect(router.stick(Vector2(0,1), Basis(Vector3.UP, i * PI / 2), Basis.IDENTITY) == expected[i], "Held forward follows heading %d" % i)
	# Real analog direction must be rotated BEFORE quantization.
	expect(Router.horizontal(Vector2(0.7,0.8), Basis(Vector3.UP, deg_to_rad(-30)), Basis.IDENTITY) == Vector3i.RIGHT, "Diagonal at oblique yaw is not quantized twice")
	# Across non-cardinal headings, compare to an independently computed ideal angle.
	for yaw in range(-170, 180, 20):
		for stick_angle in [-100, -30, 10, 70, 150]:
			var angle := deg_to_rad(stick_angle)
			var world_angle := angle - deg_to_rad(yaw)
			var expected_direction := Vector3i.RIGHT if sin(world_angle) > 0 else Vector3i.LEFT
			if absf(cos(world_angle)) >= absf(sin(world_angle)):
				expected_direction = Vector3i.FORWARD if cos(world_angle) > 0 else Vector3i.BACK
			expect(Router.horizontal(Vector2(sin(angle),cos(angle)), Basis(Vector3.UP,deg_to_rad(yaw)), Basis.IDENTITY) == expected_direction, "Analog angular mapping")
	var yaw_basis := Basis(Vector3.UP, deg_to_rad(75))
	for pitch in [-70, 0, 70]:
		for roll in [-60, 0, 60]:
			var tilted := yaw_basis * Basis(Vector3.RIGHT, deg_to_rad(pitch)) * Basis(Vector3.BACK, deg_to_rad(roll))
			expect(Router.horizontal(Vector2(0,1), tilted, Basis.IDENTITY) == Vector3i.LEFT, "Pitch/roll must not steer horizontally")
	router.stick(Vector2(0,1), yaw_basis, Basis.IDENTITY)
	expect(router.stick(Vector2(0,1), yaw_basis * Basis(Vector3.RIGHT, PI/2), Basis.IDENTITY) == Vector3i.LEFT, "Looking straight up retains last horizontal heading")
	var arena := Basis(Vector3.UP, deg_to_rad(35))
	expect(Router.horizontal(Vector2(0,1), arena * yaw_basis, arena) == Vector3i.LEFT, "Rotated tracking/arena origins preserve relative mapping")
	router = Router.new()
	router.stick(Vector2(0,1), Basis(Vector3.UP,deg_to_rad(40)), Basis.IDENTITY)
	expect(router.stick(Vector2(0,1), Basis(Vector3.UP,deg_to_rad(47)), Basis.IDENTITY) == Vector3i.FORWARD, "Diagonal boundary noise does not toggle")
	expect(router.stick(Vector2(0,1), Basis(Vector3.UP,deg_to_rad(52)), Basis.IDENTITY) == Vector3i.LEFT, "Deliberate crossing changes grid axis")
	expect(router.stick(Vector2.ZERO, Basis(Vector3.UP,PI), Basis.IDENTITY) == Vector3i.ZERO, "Head motion alone never steers")
	expect(router.vertical(Vector2(1,0.1)) == Vector3i.ZERO, "Left horizontal movement does not change height")
	expect(router.vertical(Vector2(0,1)) == Vector3i.UP, "Left forward is up")
	expect(router.vertical(Vector2(0,0.5)) == Vector3i.UP, "Left deadzone hysteresis")
	expect(router.vertical(Vector2(0,-1)) == Vector3i.DOWN, "Left back is down")
	expect(router.sticks(Vector2(0,1),Vector2(0,1),yaw_basis,Basis.IDENTITY) == Vector3i.UP, "Left vertical wins simultaneous input")
	expect(router.sticks(Vector2(0,1),Vector2.ZERO,yaw_basis,Basis.IDENTITY) == Vector3i.LEFT, "Releasing left restores held right intent")
	router.reset()
	expect(router.sticks(Vector2(0,1),Vector2(0,1),Basis.IDENTITY,Basis.IDENTITY) == Vector3i.ZERO, "Held controls after resume require neutral")
	router.sticks(Vector2.ZERO,Vector2.ZERO,Basis.IDENTITY,Basis.IDENTITY)
	expect(router.sticks(Vector2.ZERO,Vector2(0,-1),Basis.IDENTITY,Basis.IDENTITY) == Vector3i.DOWN, "Controls work after neutral")
	var sim := Sim.new()
	sim.toggle_running()
	sim.steer(Vector3i.UP)
	sim.steer(Vector3i.FORWARD)
	expect(sim.turns == [Vector3i.FORWARD], "New intent replaces stale queued turn")
	for i in 100:
		sim.steer(Vector3i.FORWARD)
	expect(sim.turns.size() == 1, "Held input never builds a backlog")
	sim.steer(Vector3i.RIGHT)
	expect(sim.turns.is_empty(), "Choosing current course cancels a queued turn")
	sim.steer(Vector3i.UP)
	expect(not sim.steer(Vector3i.LEFT) and sim.turns.is_empty(), "Illegal reverse clears old intent without turning")
	var game := Game.new()
	root.add_child(game)
	game.set_process(false)
	game.toggle_play()
	game._steer_sticks(Vector2.ZERO,Vector2.ZERO,Basis.IDENTITY)
	game._steer_sticks(Vector2(0,1),Vector2.ZERO,Basis.IDENTITY)
	expect(game.simulation.turns == [Vector3i.FORWARD], "Right stick is wired into game")
	game._steer_sticks(Vector2(0,1),Vector2(0,1),Basis.IDENTITY)
	expect(game.simulation.turns == [Vector3i.UP], "Left stick overrides right in game")
	game.advance()
	expect(game.simulation.direction == Vector3i.UP, "Left input moves snake upward")
	game._steer_sticks(Vector2(0,1),Vector2.ZERO,Basis(Vector3.UP,PI/2))
	expect(game.simulation.turns == [Vector3i.LEFT], "Held right takes new heading after vertical release")
	game._lost_focus()
	expect(game.simulation.turns.is_empty(), "Focus loss clears stale steering")
	game.free()
	print("STEERING TESTS: ", checks, " checks, ", failures, " failures (synthetic input)")
	quit(0 if failures == 0 else 1)
