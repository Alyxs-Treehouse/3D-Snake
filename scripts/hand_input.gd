extends XRNode3D
## A diagnostic skeleton driven by real XRHandTracker joints, plus pinch input.

signal pinch_started

const PinchDetector = preload("res://scripts/pinch_detector.gd")
const JOINTS := XRHandTracker.HAND_JOINT_MAX
const THUMB := XRHandTracker.HAND_JOINT_THUMB_TIP
const INDEX := XRHandTracker.HAND_JOINT_INDEX_FINGER_TIP
const POSITION_VALID := XRHandTracker.HAND_JOINT_FLAG_POSITION_VALID
const POSITION_TRACKED := XRHandTracker.HAND_JOINT_FLAG_POSITION_TRACKED
const GOLD := Color("ffce76")
# Palm/wrist and five finger chains, using Godot's 26-joint order.
const LINKS := [Vector2i(0, 1), Vector2i(1, 2), Vector2i(2, 3), Vector2i(3, 4), Vector2i(4, 5),
	Vector2i(1, 6), Vector2i(6, 7), Vector2i(7, 8), Vector2i(8, 9), Vector2i(9, 10),
	Vector2i(1, 11), Vector2i(11, 12), Vector2i(12, 13), Vector2i(13, 14), Vector2i(14, 15),
	Vector2i(1, 16), Vector2i(16, 17), Vector2i(17, 18), Vector2i(18, 19), Vector2i(19, 20),
	Vector2i(1, 21), Vector2i(21, 22), Vector2i(22, 23), Vector2i(23, 24), Vector2i(24, 25)]

var side := "L"
var hand_color := Color("51e4c2")
var detector := PinchDetector.new()
var pinch_count := 0
var joint_count := 0
var joint_positions := PackedVector3Array()
var distance := -1.0
var state := "NO TRACKER"
var source := "unknown"
var tips_tracked := false
var skeleton_root: Node3D
var joint_mesh: MultiMesh
var bone_mesh: MultiMesh
var _last_state := ""


func _ready() -> void:
	pose = "default"
	show_when_tracked = true
	skeleton_root = Node3D.new()
	add_child(skeleton_root)
	var sphere := SphereMesh.new()
	sphere.radius = 0.006
	sphere.height = 0.012
	sphere.radial_segments = 8
	sphere.rings = 4
	joint_mesh = _make_batch(sphere, JOINTS)
	var bone := CylinderMesh.new()
	bone.top_radius = 0.0025
	bone.bottom_radius = 0.0025
	bone.height = 1.0
	bone.radial_segments = 6
	bone_mesh = _make_batch(bone, LINKS.size())
	skeleton_root.hide()
	print("INPUT_LAB: hand diagnostics ready ", side, " tracker=", tracker)


func _make_batch(mesh: Mesh, count: int) -> MultiMesh:
	var batch := MultiMesh.new()
	batch.transform_format = MultiMesh.TRANSFORM_3D
	batch.use_colors = true
	batch.mesh = mesh
	batch.instance_count = count
	var instance := MultiMeshInstance3D.new()
	instance.multimesh = batch
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.vertex_color_use_as_albedo = true
	instance.material_override = material
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	skeleton_root.add_child(instance)
	return batch


func update_hand(delta: float, focused: bool) -> void:
	var hand := XRServer.get_tracker(tracker) as XRHandTracker
	if not focused:
		_hide_hand("PAUSED")
		return
	if hand == null:
		_hide_hand("NO TRACKER")
		return
	match hand.hand_tracking_source:
		XRHandTracker.HAND_TRACKING_SOURCE_UNOBSTRUCTED: source = "direct"
		XRHandTracker.HAND_TRACKING_SOURCE_CONTROLLER: source = "controller"
		_: source = "unknown"
	if not hand.has_tracking_data:
		_hide_hand("NOT TRACKED")
		return
	var palm_flags := hand.get_hand_joint_flags(XRHandTracker.HAND_JOINT_PALM)
	if (palm_flags & POSITION_VALID) == 0 or (palm_flags & XRHandTracker.HAND_JOINT_FLAG_ORIENTATION_VALID) == 0:
		_hide_hand("INVALID PALM")
		return
	var palm := hand.get_hand_joint_transform(XRHandTracker.HAND_JOINT_PALM)
	if not palm.is_finite() or absf(palm.basis.determinant()) < 0.0001:
		_hide_hand("INVALID PALM")
		return
	# XRNode3D places the palm using the adjusted pose (origin/recenter/scale).
	# Joint transforms are in tracking space; their visuals must be palm-relative.
	var inverse_palm := palm.affine_inverse()
	skeleton_root.scale = Vector3.ONE * XRServer.world_scale
	var points := PackedVector3Array()
	var valid: Array[bool] = []
	var tracked: Array[bool] = []
	joint_count = 0
	for joint in JOINTS:
		var flags := hand.get_hand_joint_flags(joint)
		var point := hand.get_hand_joint_transform(joint).origin
		var usable := (flags & POSITION_VALID) != 0 and point.is_finite()
		valid.append(usable)
		tracked.append(usable and (flags & POSITION_TRACKED) != 0)
		points.append(inverse_palm * point if usable else Vector3.ZERO)
		if usable:
			joint_count += 1
	joint_positions = points
	tips_tracked = tracked[THUMB] and tracked[INDEX] and source != "controller"
	distance = points[THUMB].distance_to(points[INDEX]) if tips_tracked else -1.0
	var was_pinching: bool = detector.pinching
	detector.update(distance, tips_tracked, delta)
	if detector.pinching and not was_pinching:
		pinch_count += 1
		print("INPUT_LAB: hand ", side, " pinch started #", pinch_count, " distance_mm=", snappedf(distance * 1000.0, 0.1))
		pinch_started.emit()
	elif was_pinching and not detector.pinching:
		print("INPUT_LAB: hand ", side, " pinch released" if tips_tracked else " pinch cancelled (tracking lost)")
	for joint in JOINTS:
		var basis := Basis.IDENTITY if valid[joint] else Basis.from_scale(Vector3.ZERO)
		joint_mesh.set_instance_transform(joint, Transform3D(basis, points[joint]))
		var color := hand_color if tracked[joint] else hand_color.darkened(0.55)
		joint_mesh.set_instance_color(joint, GOLD if detector.pinching and joint in [THUMB, INDEX] else color)
	for index in LINKS.size():
		var link: Vector2i = LINKS[index]
		var between := points[link.y] - points[link.x]
		var length := between.length()
		var transform := Transform3D(Basis.from_scale(Vector3.ZERO), Vector3.ZERO)
		if valid[link.x] and valid[link.y] and length > 0.0001:
			var axis := between / length
			var helper := Vector3.RIGHT if absf(axis.dot(Vector3.UP)) > 0.95 else Vector3.UP
			var x := axis.cross(helper).normalized()
			transform = Transform3D(Basis(x, axis * length, x.cross(axis)), (points[link.x] + points[link.y]) * 0.5)
		bone_mesh.set_instance_transform(index, transform)
		bone_mesh.set_instance_color(index, hand_color)
	skeleton_root.visible = joint_count > 0
	state = "TRACKED"
	_log_state()


func _hide_hand(reason: String) -> void:
	if detector.pinching:
		print("INPUT_LAB: hand ", side, " pinch cancelled (", reason, ")")
	detector.update(-1.0, false, 0.0)
	tips_tracked = false
	distance = -1.0
	joint_count = 0
	joint_positions.clear()
	skeleton_root.hide()
	state = reason
	_log_state()


func _log_state() -> void:
	var key := "%s/%s/%s" % [state, source, tips_tracked]
	if key != _last_state:
		_last_state = key
		print("INPUT_LAB: hand ", side, " ", state, " source=", source, " valid_joints=", joint_count, " tips_tracked=", tips_tracked)


func status_text() -> String:
	var gesture := "--"
	if tips_tracked:
		gesture = "PINCH" if detector.pinching else ("open" if detector.armed else "open to arm")
	var gap := "--" if distance < 0.0 else "%.0fmm" % (distance * 1000.0)
	return "%s: %s %d/26 (%s)\n%s | %s | count %d" % [side, state, joint_count, source, gesture, gap, pinch_count]
