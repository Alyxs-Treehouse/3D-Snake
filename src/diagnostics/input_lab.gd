extends Node3D
## Hardware diagnostics only. Snake gameplay is a later milestone.

const CYAN := Color("51e4c2")
const BLUE := Color("6aaeff")
const GOLD := Color("ffce76")
const HandInput = preload("res://src/platform/xr/hand_tracking.gd")

var origin: XROrigin3D
var head: XRCamera3D
var left: XRController3D
var right: XRController3D
var left_hand: HandInput
var right_hand: HandInput
var status_label: Label3D
var input_label: Label3D
var demo_cube: MeshInstance3D
var desktop_camera: Camera3D
var xr: OpenXRInterface
var last_button := "No button pressed"
var mic_state := "OFF (M / left X)"
var mic_level := 0.0
var mic_player: AudioStreamPlayer
var mic_capture: AudioEffectCapture
var mic_requested := false
var mic_audio_received := false
var neutral_head := Quaternion.IDENTITY
var neutral_right := Quaternion.IDENTITY
var update_elapsed := 0.0
var session_active := false


func _ready() -> void:
	_build_room()
	_build_rig()
	_build_board()
	_build_panels()
	xr = XRServer.find_interface("OpenXR") as OpenXRInterface
	if xr != null and xr.is_initialized():
		get_viewport().use_xr = true
		DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
		session_active = true
		xr.session_focussed.connect(func(): session_active = true)
		xr.session_visible.connect(func(): session_active = false)
		xr.session_stopping.connect(func(): session_active = false)
		print("INPUT_LAB: OpenXR initialized")
	else:
		desktop_camera.make_current()
		print("INPUT_LAB: desktop preview; XR hardware is not being simulated")
	# Android delivers permission results outside Godot's scene thread.
	get_tree().on_request_permissions_result.connect(_permission_result, CONNECT_DEFERRED)
	_refresh_status()
	if "--capture-preview" in OS.get_cmdline_user_args():
		_capture_preview()


func _capture_preview() -> void:
	await get_tree().create_timer(1.0).timeout
	await RenderingServer.frame_post_draw
	DirAccess.make_dir_recursive_absolute("res://builds")
	var result := get_viewport().get_texture().get_image().save_png(
		"res://builds/input-lab-preview.png"
	)
	print("INPUT_LAB: preview saved, result=", result)
	get_tree().quit(result)


func _build_room() -> void:
	var env := WorldEnvironment.new()
	var settings := Environment.new()
	settings.background_mode = Environment.BG_COLOR
	settings.background_color = Color("090f1c")
	settings.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	settings.ambient_light_color = Color("bdcce3")
	settings.ambient_light_energy = 0.7
	env.environment = settings
	add_child(env)
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-45, -25, 0)
	light.light_energy = 1.2
	add_child(light)
	_box(Vector3(12, 0.04, 12), Vector3(0, -0.04, -2), Color("111d2d"))
	for i in range(-6, 7):
		_box(Vector3(0.008, 0.004, 12), Vector3(i, -0.015, -2), Color("203046"))
		_box(Vector3(12, 0.004, 0.008), Vector3(0, -0.015, i - 2), Color("203046"))


func _build_rig() -> void:
	origin = XROrigin3D.new()
	origin.name = "XROrigin3D"
	add_child(origin)
	head = XRCamera3D.new()
	head.name = "Head"
	origin.add_child(head)
	left = _controller("LeftController", "left_hand", CYAN)
	right = _controller("RightController", "right_hand", BLUE)
	left_hand = _hand("L", "/user/hand_tracker/left", CYAN)
	right_hand = _hand("R", "/user/hand_tracker/right", BLUE)
	desktop_camera = Camera3D.new()
	desktop_camera.position = Vector3(0, 1.65, 1.25)
	desktop_camera.fov = 60
	add_child(desktop_camera)
	desktop_camera.look_at(Vector3(0, 1.35, -2))


func _hand(side: String, tracker_path: String, color: Color) -> HandInput:
	var hand := HandInput.new()
	hand.name = "LeftHand" if side == "L" else "RightHand"
	hand.side = side
	hand.tracker = tracker_path
	hand.hand_color = color
	origin.add_child(hand)
	return hand


func _controller(node_name: String, tracker_name: String, color: Color) -> XRController3D:
	var controller := XRController3D.new()
	controller.name = node_name
	controller.tracker = tracker_name
	controller.pose = "grip"
	origin.add_child(controller)
	var marker := MeshInstance3D.new()
	var mesh := CapsuleMesh.new()
	mesh.radius = 0.025
	mesh.height = 0.14
	marker.mesh = mesh
	marker.material_override = _material(color)
	controller.add_child(marker)
	controller.button_pressed.connect(_on_button.bind(controller))
	return controller


func _build_board() -> void:
	var center := Vector3(0, 1.3, -2)
	_box(Vector3(1.4, 0.08, 1.4), center + Vector3(0, -0.69, 0), Color("20364a"))
	for a in [-0.6, 0.6]:
		for b in [-0.6, 0.6]:
			_box(Vector3(1.2, 0.008, 0.008), center + Vector3(0, a, b), CYAN)
			_box(Vector3(0.008, 1.2, 0.008), center + Vector3(a, 0, b), CYAN)
			_box(Vector3(0.008, 0.008, 1.2), center + Vector3(a, b, 0), CYAN)
	var cells: Array[Vector3] = [
		Vector3(-2, -2, 1),
		Vector3(-1, -2, 1),
		Vector3(0, -2, 1),
		Vector3(0, -1, 1),
		Vector3(0, 0, 1)
	]
	for i in cells.size():
		_box(Vector3.ONE * 0.13, center + cells[i] * 0.15, CYAN.lightened(i * 0.08))
	demo_cube = _box(Vector3.ONE * 0.16, center + Vector3(0.32, 0.27, -0.15), GOLD)
	_label("SPATIAL SNAKE", Vector3(0, 2.22, -2), 46, CYAN)
	_label("PICO 4  /  INPUT LAB", Vector3(0, 2.05, -2), 22, Color("9eb5cc"))
	_label("8 x 8 x 8  /  WORLD-LOCKED BOARD", Vector3(0, 0.47, -1.5), 18, Color("9eb5cc"))


func _build_panels() -> void:
	_box(Vector3(1.22, 1.1, 0.035), Vector3(-1.36, 1.4, -2.12), Color("162437"))
	_box(Vector3(1.22, 1.1, 0.035), Vector3(1.36, 1.4, -2.12), Color("162437"))
	_label("01 / TRACKING + HANDS", Vector3(-1.36, 1.83, -2.08), 23, CYAN)
	_label("02 / LIVE INPUT", Vector3(1.36, 1.83, -2.08), 23, BLUE)
	status_label = _label("", Vector3(-1.36, 1.39, -2.08), 17, Color("d5e2f1"))
	input_label = _label("", Vector3(1.36, 1.39, -2.08), 19, Color("d5e2f1"))
	_label(
		"C / right A: calibrate     M / left X: microphone",
		Vector3(0, 0.25, -1.5),
		18,
		Color("d5e2f1")
	)
	_label(
		"Hands: put controllers down / open fingers / pinch thumb + index",
		Vector3(0, 0.12, -1.5),
		16,
		Color("829ab4")
	)


func _material(color: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.75
	return material


func _box(size: Vector3, at: Vector3, color: Color) -> MeshInstance3D:
	var instance := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	instance.mesh = mesh
	instance.position = at
	instance.material_override = _material(color)
	add_child(instance)
	return instance


func _label(value: String, at: Vector3, font_size: int, color: Color) -> Label3D:
	var label := Label3D.new()
	label.text = value
	label.position = at
	label.font_size = font_size
	label.pixel_size = 0.0035
	label.modulate = color
	label.outline_size = 0
	label.no_depth_test = false
	add_child(label)
	return label


func _on_button(action: String, controller: XRController3D) -> void:
	last_button = "%s: %s" % ["L" if controller == left else "R", action]
	print("INPUT_LAB: ", last_button)
	if action == "ax_button":
		if controller == left:
			_toggle_microphone()
		else:
			_calibrate()


func _calibrate() -> void:
	neutral_head = head.quaternion
	neutral_right = right.quaternion
	last_button = "Neutral pose calibrated"
	print("INPUT_LAB: pose calibrated")


func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		match event.physical_keycode:
			KEY_C:
				_calibrate()
			KEY_M:
				_toggle_microphone()
			KEY_ESCAPE:
				Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	if get_viewport().use_xr:
		return
	if event is InputEventMouseMotion and Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		desktop_camera.rotation.y -= event.relative.x * 0.003
		desktop_camera.rotation.x = clampf(
			desktop_camera.rotation.x - event.relative.y * 0.003, -0.8, 0.8
		)
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			desktop_camera.position.z = maxf(0.0, desktop_camera.position.z - 0.15)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			desktop_camera.position.z = minf(3.0, desktop_camera.position.z + 0.15)


func _process(delta: float) -> void:
	var hand_input_enabled := get_viewport().use_xr and session_active
	left_hand.update_hand(delta, hand_input_enabled)
	right_hand.update_hand(delta, hand_input_enabled)
	var cube_material := demo_cube.material_override as StandardMaterial3D
	cube_material.albedo_color = (
		CYAN if left_hand.detector.pinching else (BLUE if right_hand.detector.pinching else GOLD)
	)
	if is_instance_valid(mic_capture):
		var frames := mic_capture.get_frames_available()
		if frames > 0:
			var samples := mic_capture.get_buffer(frames)
			var power := 0.0
			for sample in samples:
				power += sample.length_squared() * 0.5
			mic_level = sqrt(power / samples.size())
			if not mic_audio_received and mic_level > 0.00001:
				mic_audio_received = true
				print(
					(
						"INPUT_LAB: microphone received audio frames, level=%.1f dB"
						% linear_to_db(mic_level)
					)
				)
	if get_viewport().use_xr and right.get_is_active():
		demo_cube.quaternion = neutral_right.inverse() * right.quaternion
	else:
		demo_cube.rotate_y(delta * 0.35)
	update_elapsed += delta
	if update_elapsed >= 0.1:
		update_elapsed = 0
		_refresh_status()


func _refresh_status() -> void:
	var xr_enabled := get_viewport().use_xr
	var mode := (
		"OpenXR / " + ("ACTIVE" if session_active else "NOT FOCUSED")
		if xr_enabled
		else "DESKTOP PREVIEW"
	)
	status_label.text = (
		"%s / %d FPS\nControllers L: %s  R: %s\n\n%s\n\n%s"
		% [
			mode,
			Engine.get_frames_per_second(),
			"ON" if left.get_is_active() else "--",
			"ON" if right.get_is_active() else "--",
			left_hand.status_text(),
			right_hand.status_text()
		]
	)
	var angles := (neutral_head.inverse() * head.quaternion).get_euler() * 180.0 / PI
	var stick := right.get_vector2("primary")
	input_label.text = (
		(
			"Head: pitch %+.0f / yaw %+.0f\nRight trigger: %.2f\n"
			+ "Right stick: %+.2f / %+.2f\n\n%s\n\nMIC: %s\nLevel: %.1f dB"
		)
		% [
			angles.x,
			angles.y,
			right.get_float("trigger"),
			stick.x,
			stick.y,
			last_button,
			mic_state,
			linear_to_db(maxf(mic_level, 0.00001))
		]
	)


func _toggle_microphone() -> void:
	if mic_requested:
		return
	if is_instance_valid(mic_player):
		mic_player.stop()
		mic_player.queue_free()
		mic_player = null
		mic_capture = null
		mic_level = 0.0
		mic_state = "OFF"
		print("INPUT_LAB: microphone stopped")
		return
	if (
		OS.has_feature("android")
		and not "android.permission.RECORD_AUDIO" in OS.get_granted_permissions()
	):
		mic_requested = true
		mic_state = "waiting for permission"
		print("INPUT_LAB: requesting microphone permission")
		OS.request_permission("android.permission.RECORD_AUDIO")
		return
	_start_microphone()


func _permission_result(permission: String, granted: bool) -> void:
	if permission == "android.permission.RECORD_AUDIO" and mic_requested:
		mic_requested = false
		print("INPUT_LAB: microphone permission granted=", granted)
		if granted:
			_start_microphone()
		else:
			mic_state = "permission denied"


func _start_microphone() -> void:
	if is_instance_valid(mic_player):
		return
	var bus := AudioServer.get_bus_index("MicCapture")
	if bus < 0:
		AudioServer.add_bus()
		bus = AudioServer.bus_count - 1
		AudioServer.set_bus_name(bus, "MicCapture")
		mic_capture = AudioEffectCapture.new()
		AudioServer.add_bus_effect(bus, mic_capture)
	else:
		mic_capture = AudioServer.get_bus_effect(bus, 0) as AudioEffectCapture
	# Capture occurs before bus attenuation; never monitor the microphone in speakers.
	AudioServer.set_bus_volume_db(bus, -80.0)
	mic_capture.clear_buffer()
	mic_audio_received = false
	mic_player = AudioStreamPlayer.new()
	mic_player.bus = "MicCapture"
	mic_player.stream = AudioStreamMicrophone.new()
	add_child(mic_player)
	mic_player.play()
	mic_state = "ON / local level only"
	print("INPUT_LAB: microphone started")
