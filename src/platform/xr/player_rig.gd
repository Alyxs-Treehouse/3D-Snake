class_name PlayerRig
extends Node3D
## Owns device lifecycle and observer pose only; it knows no game rules.
signal play_requested
signal restart_requested
signal focus_lost
signal recentered
const HandTracking = preload("res://src/platform/xr/hand_tracking.gd")
var in_xr := false
var focused := false
var _hands: Array[Node3D] = []

@onready var origin: XROrigin3D = $Origin
@onready var head: XRCamera3D = $Origin/Head
@onready var left: XRController3D = $Origin/Left
@onready var right: XRController3D = $Origin/Right
@onready var desktop: Camera3D = $DesktopCamera


func _ready() -> void:
	left.button_pressed.connect(_left_button)
	for side in ["left", "right"]:
		var hand := HandTracking.new()
		hand.tracker = "/user/hand_tracker/" + side
		hand.side = "L" if side == "left" else "R"
		hand.hand_color = Color("64f5cb") if side == "left" else Color("6aaeff")
		origin.add_child(hand)
		_hands.append(hand)
	var xr := XRServer.find_interface("OpenXR") as OpenXRInterface
	in_xr = xr != null and xr.is_initialized()
	get_viewport().use_xr = in_xr
	if in_xr:
		DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
		xr.session_focussed.connect(func(): focused = true)
		xr.session_visible.connect(_lose_focus)
		xr.session_stopping.connect(_lose_focus)
		xr.pose_recentered.connect(func(): recentered.emit())
		print("SNAKE: OpenXR initialized; observer INSIDE arena")
	else:
		focused = true
		desktop.make_current()


func camera() -> Camera3D:
	return head if in_xr else desktop


func _left_button(action: String) -> void:
	if not focused:
		return
	if action == "ax_button":
		play_requested.emit()
	elif action == "by_button":
		restart_requested.emit()


func _lose_focus() -> void:
	focused = false
	focus_lost.emit()


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		_lose_focus()
	elif what == NOTIFICATION_APPLICATION_FOCUS_IN and not in_xr:
		focused = true


func _input(event: InputEvent) -> void:
	if (
		not in_xr
		and event is InputEventMouseMotion
		and Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT)
	):
		desktop.rotation.y -= event.relative.x * 0.003
		desktop.rotation.x = clampf(desktop.rotation.x - event.relative.y * 0.003, -1.35, 1.35)


func _process(dt: float) -> void:
	if not in_xr:
		return
	for hand in _hands:
		hand.update_hand(minf(dt, 0.1), focused)
