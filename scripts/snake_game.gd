extends Node3D

const Simulation = preload("res://scripts/snake_simulation.gd")
const BoardView = preload("res://scripts/board_view.gd")
const InputRouter = preload("res://scripts/snake_input_router.gd")
const HandInput = preload("res://scripts/hand_input.gd")
const STEP_SECONDS := 0.75
var simulation := Simulation.new()
var router := InputRouter.new()
var board: BoardView
var origin: XROrigin3D
var head: XRCamera3D
var desktop_camera: Camera3D
var left: XRController3D
var right: XRController3D
var hands: Array[HandInput] = []
var xr: OpenXRInterface
var xr_active := false
var centred := false
var elapsed := STEP_SECONDS
var countdown := 3.0
var best := 0
var notice := ""
var notice_time := 0.0
var hud_elapsed := 0.0
var last_stick_intent := Vector3i.ZERO
var move_intent := Vector3i.ZERO
var held_keys: Dictionary = {}
var wall_impact_elapsed := 0.0
var wall_impact_seconds := 0.0


func _ready() -> void:
	var environment := WorldEnvironment.new()
	var settings := Environment.new()
	settings.background_mode = Environment.BG_COLOR
	settings.background_color = Color("050d19")
	settings.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	settings.ambient_light_color = Color("b9e4ea")
	settings.ambient_light_energy = 0.65
	environment.environment = settings
	add_child(environment)
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-35, -30, 0)
	add_child(light)
	board = BoardView.new()
	add_child(board)
	origin = XROrigin3D.new()
	add_child(origin)
	head = XRCamera3D.new()
	head.near = 0.05
	origin.add_child(head)
	left = _controller("left_hand", true)
	right = _controller("right_hand", false)
	for side in ["left", "right"]:
		var hand := HandInput.new()
		hand.tracker = "/user/hand_tracker/" + side
		hand.side = "L" if side == "left" else "R"
		hand.hand_color = Color("64f5cb") if side == "left" else Color("6aaeff")
		origin.add_child(hand)
		hands.append(hand)
	desktop_camera = Camera3D.new()
	desktop_camera.position = Vector3(0, 1.65, 0)
	desktop_camera.fov = 85
	desktop_camera.near = 0.05
	add_child(desktop_camera)
	xr = XRServer.find_interface("OpenXR") as OpenXRInterface
	if xr != null and xr.is_initialized():
		get_viewport().use_xr = true
		DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
		xr.session_focussed.connect(func(): xr_active = true)
		xr.session_visible.connect(_lost_focus)
		xr.session_stopping.connect(_lost_focus)
		xr.pose_recentered.connect(func():
			_pause("View reset; press X to resume")
			centred = false)
		print("SNAKE: OpenXR initialized; observer INSIDE arena")
	else:
		desktop_camera.make_current()
		print("SNAKE: desktop inside-arena view")
	board.sync(simulation.snake, simulation.food, simulation.direction, true)
	_refresh_hud()
	if "--capture-preview" in OS.get_cmdline_user_args():
		_capture_preview()


func _controller(path: String, is_left: bool) -> XRController3D:
	var controller := XRController3D.new()
	controller.tracker = path
	controller.pose = "grip"
	origin.add_child(controller)
	var marker := MeshInstance3D.new()
	var mesh := CapsuleMesh.new()
	mesh.radius = 0.02
	mesh.height = 0.12
	marker.mesh = mesh
	marker.material_override = board.material(Color("64f5cb") if is_left else Color("6aaeff"))
	controller.add_child(marker)
	controller.show_when_tracked = true
	controller.button_pressed.connect(_on_controller_button.bind(is_left))
	return controller


func viewer() -> Camera3D:
	return head if get_viewport().use_xr else desktop_camera


func _centre_arena() -> void:
	var camera := viewer()
	board.position = Vector3(camera.global_position.x, 0, camera.global_position.z)
	board.rotation.y = camera.global_rotation.y
	centred = true


func _on_controller_button(action: String, is_left: bool) -> void:
	if not xr_active:
		return
	if is_left:
		if action == "ax_button":
			toggle_play()
		elif action == "by_button":
			restart()
	# Right A/B movement is polled as held state, not latched on this event.


func _reset_move_input() -> void:
	router.reset()
	held_keys.clear()
	simulation.turns.clear()
	move_intent = Vector3i.ZERO
	last_stick_intent = Vector3i.ZERO


func toggle_play() -> void:
	if simulation.phase in [Simulation.Phase.GAME_OVER, Simulation.Phase.WON]:
		restart()
		return
	simulation.toggle_running()
	_reset_move_input()
	print("SNAKE: phase=", simulation.phase)
	_refresh_hud()


func restart() -> void:
	simulation.reset()
	simulation.toggle_running()
	elapsed = STEP_SECONDS
	countdown = 3.0
	notice_time = 0
	_reset_move_input()
	wall_impact_elapsed = 0.0
	wall_impact_seconds = 0.0
	board.sync(simulation.snake, simulation.food, simulation.direction, true)
	print("SNAKE: restart")
	_refresh_hud()


func _pause(reason: String) -> void:
	if simulation.phase == Simulation.Phase.RUNNING:
		simulation.phase = Simulation.Phase.PAUSED
		print("SNAKE: paused: ", reason)
		notice = reason
		notice_time = 4
	_reset_move_input()


func _lost_focus() -> void:
	xr_active = false
	_pause("App left foreground")


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT and is_instance_valid(board):
		_pause("Window left foreground")


func _apply_move_intent(direction: Vector3i) -> void:
	# Every control adapter supplies a current state: ZERO means stop immediately.
	move_intent = Vector3i.ZERO
	if simulation.phase == Simulation.Phase.RUNNING and direction != Vector3i.ZERO:
		if simulation.steer(direction):
			move_intent = direction
	else:
		simulation.turns.clear()
	if direction != last_stick_intent:
		if move_intent != Vector3i.ZERO:
			notice = "HELD: " + _direction_name(move_intent)
		else:
			notice = "STOPPED / REVERSE BLOCKED" if direction != Vector3i.ZERO else "STOPPED / HOLD TO MOVE"
		notice_time = 1.2
		print("SNAKE: move intent=", move_intent, " requested=", direction, " head_forward=", router.last_forward)
	last_stick_intent = direction


func _steer_sticks(right_stick: Vector2, left_stick: Vector2, heading: Basis, up := false, down := false) -> void:
	var intent := router.sticks(right_stick, left_stick, heading, board.global_basis)
	var button_intent := router.buttons(up, down)
	_apply_move_intent(intent if intent != Vector3i.ZERO else button_intent)


func _input(event: InputEvent) -> void:
	if event is InputEventKey and not event.echo:
		if event.physical_keycode in InputRouter.MOVE_KEYS:
			if event.pressed and simulation.phase == Simulation.Phase.RUNNING:
				held_keys[event.physical_keycode] = true
			else:
				held_keys.erase(event.physical_keycode)
			return
		if not event.pressed:
			return
		match event.physical_keycode:
			KEY_SPACE, KEY_P: toggle_play()
			KEY_R: restart()
			KEY_ESCAPE:
				_pause("Paused")
				Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
			KEY_C:
				_pause("Arena centred; resume when ready")
				_centre_arena()
	if not get_viewport().use_xr and event is InputEventMouseMotion and Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		desktop_camera.rotation.y -= event.relative.x * 0.003
		desktop_camera.rotation.x = clampf(desktop_camera.rotation.x - event.relative.y * 0.003, -1.35, 1.35)


func _process(delta: float) -> void:
	var dt := minf(delta, 0.1)
	var in_xr := get_viewport().use_xr
	if in_xr and xr_active and not centred:
		_centre_arena()
	for hand in hands:
		hand.update_hand(dt, in_xr and xr_active)
	if in_xr and xr_active:
		if right.get_is_active():
			var left_stick := left.get_vector2("primary") if left.get_is_active() else Vector2.ZERO
			_steer_sticks(right.get_vector2("primary"), left_stick, head.global_basis, right.is_button_pressed("ax_button"), right.is_button_pressed("by_button"))
		else:
			_pause("Pick up right controller to play")
	elif not in_xr:
		_apply_move_intent(InputRouter.keyboard(held_keys, viewer().global_basis, board.global_basis))
	_update_motion(dt)
	notice_time = maxf(0, notice_time - dt)
	hud_elapsed += dt
	if hud_elapsed >= 0.1:
		hud_elapsed = 0
		_refresh_hud()


func _update_motion(dt: float) -> void:
	if simulation.phase == Simulation.Phase.RUNNING:
		if countdown > 0:
			countdown = maxf(0, countdown - dt)
		elif move_intent != Vector3i.ZERO:
			elapsed += dt
			if elapsed >= STEP_SECONDS:
				elapsed -= STEP_SECONDS
				advance()
	var impact_progress := 0.0
	if simulation.phase == Simulation.Phase.GAME_OVER and wall_impact_seconds > 0.0:
		wall_impact_elapsed = minf(wall_impact_elapsed + dt, wall_impact_seconds)
		impact_progress = wall_impact_elapsed / wall_impact_seconds
	board.animate(clampf(elapsed / STEP_SECONDS, 0, 1), impact_progress)


func advance() -> void:
	if move_intent == Vector3i.ZERO or simulation.phase != Simulation.Phase.RUNNING:
		return
	var old_score := simulation.score
	if simulation.step():
		board.sync(simulation.snake, simulation.food, simulation.direction)
	elif simulation.phase == Simulation.Phase.GAME_OVER:
		# Even rejected steps have an attempted direction. Otherwise a wall hit
		# can look like death while travelling parallel to the wall.
		board.sync(simulation.snake, simulation.food, simulation.direction, true)
		if simulation.end_reason == "WALL":
			wall_impact_elapsed = 0.0
			wall_impact_seconds = STEP_SECONDS * board.show_wall_collision(simulation.direction)
			print("SNAKE: wall hit head=", simulation.snake[0], " direction=", simulation.direction, " attempted=", simulation.snake[0] + simulation.direction)
	if simulation.score != old_score:
		best = maxi(best, simulation.score)
		print("SNAKE: ate food, score=", simulation.score, " length=", simulation.snake.size())
	if simulation.phase in [Simulation.Phase.GAME_OVER, Simulation.Phase.WON]:
		move_intent = Vector3i.ZERO
		elapsed = STEP_SECONDS
		print("SNAKE: round ended: ", simulation.end_reason, " score=", simulation.score)


func _direction_name(direction: Vector3i) -> String:
	if direction.y != 0:
		return "UP" if direction.y > 0 else "DOWN"
	var forward := InputRouter.floor_forward(viewer().global_basis, router.last_forward)
	var world := board.global_basis * Vector3(direction)
	var right_amount := world.dot(forward.cross(Vector3.UP))
	var forward_amount := world.dot(forward)
	if absf(right_amount) > absf(forward_amount):
		return "VIEW RIGHT" if right_amount > 0 else "VIEW LEFT"
	return "VIEW FORWARD" if forward_amount > 0 else "VIEW BACK"


func _refresh_hud() -> void:
	var in_xr := get_viewport().use_xr
	board.score_label.text = "SCORE %03d    LENGTH %02d    BEST %03d" % [simulation.score, simulation.snake.size(), best]
	match simulation.phase:
		Simulation.Phase.READY: board.status.text = "PRESS LEFT X TO START" if in_xr else "PRESS SPACE TO START"
		Simulation.Phase.RUNNING: board.status.text = "READY  %d" % ceili(countdown) if countdown > 0 else ("HOLD TO MOVE / RELEASE TO STOP" if move_intent == Vector3i.ZERO else "FOLLOW THE GOLDEN FOOD")
		Simulation.Phase.PAUSED: board.status.text = "PAUSED / X TO RESUME" if in_xr else "PAUSED / SPACE TO RESUME"
		Simulation.Phase.GAME_OVER: board.status.text = simulation.end_reason + (" / Y TO RETRY" if in_xr else " / R TO RETRY")
		Simulation.Phase.WON: board.status.text = "SPACE FILLED / YOU WIN"
	board.controls.text = "HOLD RIGHT: steer   HOLD LEFT: up / down\nRELEASE: stop   X: pause / resume   Y: restart" if in_xr else "HOLD WASD: steer   HOLD Q / E: up / down\nRELEASE: stop   SPACE: pause   R: restart   C: centre"
	board.food_label.text = board.food_hint(viewer())
	board.turn_label.text = notice if notice_time > 0 else ("STOPPED / HOLD TO MOVE" if move_intent == Vector3i.ZERO else "MOVING: " + _direction_name(simulation.direction))


func _capture_preview() -> void:
	await get_tree().create_timer(0.8).timeout
	await RenderingServer.frame_post_draw
	DirAccess.make_dir_recursive_absolute("res://builds")
	var result := get_viewport().get_texture().get_image().save_png("res://builds/snake-game-preview.png")
	print("SNAKE: preview saved, result=", result)
	get_tree().quit(result)
