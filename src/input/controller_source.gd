class_name ControllerIntentSource
extends IntentSource
var mapper := DirectionMapper.new()
var left: XRController3D
var right: XRController3D


func configure(left_controller: XRController3D, right_controller: XRController3D) -> void:
	left = left_controller
	right = right_controller
	reset()


func reset() -> void:
	mapper.reset()


func available() -> bool:
	return is_instance_valid(right) and right.get_is_active()


func sample(viewer: Basis, arena: Basis) -> Vector3i:
	if not available():
		reset()
		return Vector3i.ZERO
	var left_stick := (
		left.get_vector2("primary")
		if is_instance_valid(left) and left.get_is_active()
		else Vector2.ZERO
	)
	return sample_values(
		right.get_vector2("primary"),
		left_stick,
		viewer,
		arena,
		right.is_button_pressed("ax_button"),
		right.is_button_pressed("by_button")
	)


func sample_values(
	right_stick: Vector2,
	left_stick: Vector2,
	viewer: Basis,
	arena: Basis,
	up := false,
	down := false
) -> Vector3i:
	var sticks := mapper.sticks(right_stick, left_stick, viewer, arena)
	var buttons := mapper.buttons(up, down)
	return sticks if sticks != Vector3i.ZERO else buttons
