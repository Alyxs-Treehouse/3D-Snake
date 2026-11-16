extends RefCounted
## Distances are in tracking-space metres, independent of XR world scale.

const PRESS_DISTANCE := 0.025
const RELEASE_DISTANCE := 0.040
const PRESS_SECONDS := 0.08

var pinching := false
var armed := false
var close_seconds := 0.0


func update(distance: float, tracked: bool, delta: float) -> void:
	if not tracked or not is_finite(distance) or distance < 0.0:
		pinching = false
		armed = false
		close_seconds = 0.0
		return
	if distance >= RELEASE_DISTANCE:
		pinching = false
		armed = true
		close_seconds = 0.0
	elif not pinching:
		if armed and distance <= PRESS_DISTANCE:
			# A stalled frame must not count as a sustained gesture.
			close_seconds += clampf(delta, 0.0, 0.04)
			if close_seconds >= PRESS_SECONDS:
				pinching = true
		else:
			close_seconds = 0.0
