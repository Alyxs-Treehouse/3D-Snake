class_name TutorialDefinition
extends Resource
@export var id := ""
@export var steps: Array[TutorialStep] = []


func validate() -> PackedStringArray:
	var errors := PackedStringArray()
	if id.is_empty() or steps.is_empty():
		errors.append("Tutorial needs id and steps")
	var ids := {}
	for step in steps:
		if step == null:
			errors.append("Null tutorial step")
			continue
		if step.id.is_empty() or ids.has(step.id) or step.instruction.is_empty() or step.count < 1:
			errors.append("Invalid tutorial step")
		if step.event not in ["move", "stop", "food", "win"]:
			errors.append("Unknown tutorial event")
		ids[step.id] = true
	return errors
