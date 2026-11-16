class_name DirectionMapper
extends RefCounted
## Held sticks express current intent. Quantize only after head-relative rotation.

const ENGAGE := 0.65
const RELEASE := 0.25
const AXIS_HYSTERESIS_COS := 0.6427876  # cos(50 degrees): five degrees beyond a diagonal.
const MOVE_KEYS := [KEY_W, KEY_A, KEY_S, KEY_D, KEY_UP, KEY_LEFT, KEY_DOWN, KEY_RIGHT, KEY_Q, KEY_E]
var right_active := false
var left_active := false
var right_needs_neutral := false
var left_needs_neutral := false
var last_forward := Vector3.FORWARD
var last_axis := Vector3i.ZERO
var buttons_need_release := false


func reset() -> void:
	right_active = false
	left_active = false
	right_needs_neutral = true
	left_needs_neutral = true
	last_axis = Vector3i.ZERO
	buttons_need_release = true


static func floor_forward(viewer: Basis, fallback := Vector3.FORWARD) -> Vector3:
	# Project the look direction, not the tilted head's right axis. Roll has no effect.
	var forward := -viewer.z
	forward.y = 0.0
	# Yaw is undefined looking straight up/down; retain the last usable heading.
	return forward.normalized() if forward.length_squared() > 0.01 else fallback


static func local_intent(vector: Vector2, forward: Vector3, arena: Basis) -> Vector3:
	var right := forward.cross(Vector3.UP)
	var local := arena.inverse() * (right * vector.x + forward * vector.y)
	local.y = 0.0
	return local.normalized()


static func quantize(local: Vector3) -> Vector3i:
	if local.length_squared() < 0.001:
		return Vector3i.ZERO
	if absf(local.x) > absf(local.z):
		return Vector3i(1 if local.x > 0 else -1, 0, 0)
	return Vector3i(0, 0, 1 if local.z > 0 else -1)


static func horizontal(vector: Vector2, viewer: Basis, arena: Basis) -> Vector3i:
	return quantize(local_intent(vector, floor_forward(viewer), arena))


func stick(value: Vector2, viewer: Basis, arena: Basis) -> Vector3i:
	last_forward = floor_forward(viewer, last_forward)
	if value.length() <= RELEASE:
		right_active = false
		right_needs_neutral = false
		last_axis = Vector3i.ZERO
		return Vector3i.ZERO
	if right_needs_neutral:
		return Vector3i.ZERO
	if value.length() >= ENGAGE:
		right_active = true
	if not right_active:
		return Vector3i.ZERO
	var local := local_intent(value, last_forward, arena)
	if last_axis != Vector3i.ZERO and local.dot(Vector3(last_axis)) >= AXIS_HYSTERESIS_COS:
		return last_axis
	last_axis = quantize(local)
	return last_axis


func vertical(value: Vector2) -> Vector3i:
	if absf(value.y) <= RELEASE:
		left_active = false
		left_needs_neutral = false
		return Vector3i.ZERO
	if left_needs_neutral:
		return Vector3i.ZERO
	if absf(value.y) >= ENGAGE:
		left_active = true
	if not left_active:
		return Vector3i.ZERO
	return Vector3i.UP if value.y > 0 else Vector3i.DOWN


func sticks(right: Vector2, left: Vector2, viewer: Basis, arena: Basis) -> Vector3i:
	var flat := stick(right, viewer, arena)
	var height := vertical(left)
	# One grid step cannot be horizontal and vertical: deliberate height input wins.
	return height if height != Vector3i.ZERO else flat


func buttons(up: bool, down: bool) -> Vector3i:
	if not up and not down:
		buttons_need_release = false
	if buttons_need_release or up == down:
		return Vector3i.ZERO
	return Vector3i.UP if up else Vector3i.DOWN


static func keyboard(keys: Dictionary, viewer: Basis, arena: Basis) -> Vector3i:
	var up := keys.has(KEY_Q)
	var down := keys.has(KEY_E)
	if up or down:
		return Vector3i.ZERO if up == down else (Vector3i.UP if up else Vector3i.DOWN)
	var x := (
		int(keys.has(KEY_D) or keys.has(KEY_RIGHT)) - int(keys.has(KEY_A) or keys.has(KEY_LEFT))
	)
	var y := int(keys.has(KEY_W) or keys.has(KEY_UP)) - int(keys.has(KEY_S) or keys.has(KEY_DOWN))
	return horizontal(Vector2(x, y), viewer, arena)


static func key_direction(key: int, viewer: Basis, arena: Basis) -> Vector3i:
	match key:
		KEY_W, KEY_UP:
			return horizontal(Vector2(0, 1), viewer, arena)
		KEY_S, KEY_DOWN:
			return horizontal(Vector2(0, -1), viewer, arena)
		KEY_A, KEY_LEFT:
			return horizontal(Vector2.LEFT, viewer, arena)
		KEY_D, KEY_RIGHT:
			return horizontal(Vector2.RIGHT, viewer, arena)
		KEY_Q:
			return Vector3i.UP
		KEY_E:
			return Vector3i.DOWN
	return Vector3i.ZERO
