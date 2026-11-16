class_name KeyboardIntentSource
extends IntentSource
var held_keys: Dictionary = {}


func sample(viewer: Basis, arena: Basis) -> Vector3i:
	return DirectionMapper.keyboard(held_keys, viewer, arena)


func reset() -> void:
	held_keys.clear()


func handle_event(event: InputEvent) -> void:
	if (
		event is InputEventKey
		and not event.echo
		and event.physical_keycode in DirectionMapper.MOVE_KEYS
	):
		if event.pressed:
			held_keys[event.physical_keycode] = true
		else:
			held_keys.erase(event.physical_keycode)
