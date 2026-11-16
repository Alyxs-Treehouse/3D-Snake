class_name TutorialRunner
extends RefCounted
signal changed
signal completed(id: String)
var definition: TutorialDefinition
var index := 0
var progress := 0


func start(value: TutorialDefinition) -> void:
	definition = value
	index = 0
	progress = 0
	changed.emit()


func notify(event: String) -> void:
	if definition == null or index >= definition.steps.size():
		return
	var step := definition.steps[index]
	if step.event != event:
		return
	progress += 1
	if progress >= step.count:
		index += 1
		progress = 0
		changed.emit()
		if index == definition.steps.size():
			completed.emit(definition.id)


func instruction() -> String:
	if definition == null or index >= definition.steps.size():
		return ""
	return definition.steps[index].instruction
