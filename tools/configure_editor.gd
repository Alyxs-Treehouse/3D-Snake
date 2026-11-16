extends SceneTree
## Generate the initial action map with Godot --headless --xr-mode off --script.

func _initialize() -> void:
	call_deferred("_configure")


func _configure() -> void:
	var action_map := OpenXRActionMap.new()
	action_map.create_default_action_sets()
	var result := ResourceSaver.save(action_map, "res://openxr_action_map.tres")
	if result != OK:
		push_error("Could not save OpenXR action map")
		quit(1)
		return
	for action_set in action_map.get_action_sets():
		for action in action_set.get_actions():
			print("XR_ACTION: ", action.resource_name)
	print("INPUT_LAB: default action map configured")
	quit()
