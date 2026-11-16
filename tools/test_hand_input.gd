extends SceneTree
## Synthetic-data regression checks; these do not verify real PICO tracking.

const Pinch = preload("res://scripts/pinch_detector.gd")
const Hand = preload("res://scripts/hand_input.gd")
var failures := 0


func _initialize() -> void:
	_run.call_deferred()


func _expect(condition: bool, description: String) -> void:
	if not condition:
		failures += 1
		push_error("HAND TEST: " + description)


func _hold(detector: RefCounted, gap: float, frames := 6) -> void:
	for frame in frames:
		detector.update(gap, true, 0.02)


func _run() -> void:
	var pinch := Pinch.new()
	_hold(pinch, 0.01)
	_expect(not pinch.pinching, "Starting with closed fingers must not activate")
	pinch.update(0.06, true, 0.02)
	pinch.update(0.01, true, 0.02)
	_expect(not pinch.pinching, "One short close sample must not activate")
	pinch.update(0.03, true, 0.02)
	_hold(pinch, 0.01)
	_expect(pinch.pinching, "A deliberate pinch must activate")
	_hold(pinch, 0.035)
	_expect(pinch.pinching, "Small distance noise must not release a pinch")
	pinch.update(0.04, true, 0.02)
	_expect(not pinch.pinching, "Opening fingers must release")
	_hold(pinch, 0.01)
	pinch.update(0.01, false, 0.02)
	_expect(not pinch.pinching and not pinch.armed, "Tracking loss must cancel and disarm")
	_hold(pinch, 0.01)
	_expect(not pinch.pinching, "Reacquiring a closed hand must not reactivate")
	pinch.update(0.06, true, 0.02)
	pinch.update(0.01, true, 2.0)
	_expect(not pinch.pinching, "A stalled frame must not bypass debounce")
	pinch.update(NAN, true, 0.02)
	_expect(not pinch.armed, "Invalid positions must disarm")

	var tracker := XRHandTracker.new()
	tracker.name = "/user/hand_tracker/left"
	tracker.hand_tracking_source = XRHandTracker.HAND_TRACKING_SOURCE_UNOBSTRUCTED
	tracker.has_tracking_data = true
	var palm := Transform3D(Basis(Vector3.UP, 0.6), Vector3(0.2, 1.2, -0.5))
	var flags := XRHandTracker.HAND_JOINT_FLAG_POSITION_VALID | XRHandTracker.HAND_JOINT_FLAG_POSITION_TRACKED | XRHandTracker.HAND_JOINT_FLAG_ORIENTATION_VALID
	for joint in XRHandTracker.HAND_JOINT_MAX:
		tracker.set_hand_joint_transform(joint, Transform3D(palm.basis, palm * Vector3(joint * 0.01, 0.0, 0.0)))
		tracker.set_hand_joint_flags(joint, flags)
	tracker.set_pose("default", palm, Vector3.ZERO, Vector3.ZERO, XRPose.XR_TRACKING_CONFIDENCE_HIGH)
	XRServer.add_tracker(tracker)
	var origin := XROrigin3D.new()
	root.add_child(origin)
	var hand := Hand.new()
	hand.tracker = tracker.name
	origin.add_child(hand)
	hand.update_hand(0.02, true)
	_expect(hand.joint_count == 26 and hand.skeleton_root.visible, "Valid joints must show the skeleton")
	# The headless dummy renderer cannot read back MultiMesh GPU transforms.
	_expect(hand.joint_positions[10].is_equal_approx(Vector3(0.1, 0.0, 0.0)), "Rendered points must be palm-relative, with no double translation/rotation")
	XRServer.world_scale = 2.0
	hand.update_hand(0.02, true)
	_expect(hand.skeleton_root.scale.is_equal_approx(Vector3.ONE * 2.0), "Visual bones must follow XR world scale")
	_expect(is_equal_approx(hand.distance, 0.05), "Gesture distances must remain in real metres")
	XRServer.world_scale = 1.0
	tracker.set_hand_joint_transform(10, Transform3D(palm.basis, palm * Vector3(0.06, 0.0, 0.0)))
	for frame in 6:
		hand.update_hand(0.02, true)
	_expect(hand.pinch_count == 1 and hand.detector.pinching, "One held gesture must count only once")
	tracker.set_hand_joint_flags(10, XRHandTracker.HAND_JOINT_FLAG_POSITION_VALID)
	hand.update_hand(0.02, true)
	_expect(not hand.detector.pinching, "An inferred/stale fingertip must cancel input")
	tracker.set_hand_joint_flags(10, flags)
	tracker.hand_tracking_source = XRHandTracker.HAND_TRACKING_SOURCE_CONTROLLER
	hand.update_hand(0.02, true)
	_expect(not hand.tips_tracked, "Controller-inferred hands must not trigger bare-hand gestures")
	tracker.has_tracking_data = false
	hand.update_hand(0.02, true)
	_expect(not hand.skeleton_root.visible and hand.joint_count == 0, "Lost tracking must hide stale geometry")
	tracker.has_tracking_data = true
	hand.update_hand(0.02, false)
	_expect(not hand.skeleton_root.visible, "An unfocused app must hide hands and cancel input")
	XRServer.remove_tracker(tracker)
	origin.free()
	print("HAND TESTS: ", "passed" if failures == 0 else "FAILED (%d)" % failures, " (synthetic tracking data)")
	quit(0 if failures == 0 else 1)
