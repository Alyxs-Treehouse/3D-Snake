class_name IntentSource
extends RefCounted


## Extension contract: sample every frame; neutral/lost tracking MUST return ZERO.
func sample(_viewer: Basis, _arena: Basis) -> Vector3i:
	return Vector3i.ZERO


func reset() -> void:
	pass


func handle_event(_event: InputEvent) -> void:
	pass


func available() -> bool:
	return true
