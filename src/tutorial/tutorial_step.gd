class_name TutorialStep
extends Resource
@export var id := ""
@export_multiline var instruction := ""
@export_enum("move", "stop", "food", "win") var event := "move"
@export_range(1, 100) var count := 1
