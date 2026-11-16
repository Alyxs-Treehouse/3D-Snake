class_name GameHud
extends Node3D
## Presentation-only, refreshed at 10 Hz; unchanged labels are not assigned again.
var labels: Dictionary = {}


func configure(room_size: Vector3) -> void:
	for child in get_children():
		child.free()
	labels.clear()
	position = Vector3(0, minf(2.93, room_size.y - 1.07), -room_size.z / 2 + 0.05)
	var box := BoxMesh.new()
	box.size = Vector3(3.5, 1.13, 0.04)
	var panel := MeshFactory.instance(box, Color("0b1c2c"))
	panel.position.z = -0.04
	add_child(panel)
	_label("title", "SPATIAL SNAKE", 0.41, 42, Color("64f5cb"))
	_label("score", "", 0.17, 26, Color("dce9f1"))
	_label("status", "", -0.07, 27, Color("ffd486"))
	_label("controls", "", -0.33, 22, Color("b1c8d7"))
	_label("food", "", -0.68, 24, Color("ffd486"))
	_label("movement", "", -0.86, 21, Color("96b3c8"))
	_label("tutorial", "", -1.12, 23, Color("64f5cb"))


func _label(id: String, text: String, y: float, size: int, color: Color) -> void:
	var label := Label3D.new()
	label.text = text
	label.position.y = y
	label.font_size = size
	label.pixel_size = 0.0035
	label.modulate = color
	label.outline_size = 0
	add_child(label)
	labels[id] = label


func _set_label(id: String, text: String) -> void:
	if labels[id].text != text:
		labels[id].text = text


func present(
	session: GameSession, best: int, in_xr: bool, food: String, direction: String, tutorial: String
) -> void:
	var model := session.model
	_set_label(
		"score", "SCORE %03d    LENGTH %02d    BEST %03d" % [model.score, model.body.size(), best]
	)
	var status := ""
	match model.phase:
		SnakeModel.Phase.READY:
			status = "PRESS LEFT X TO START" if in_xr else "PRESS SPACE TO START"
		SnakeModel.Phase.RUNNING:
			status = (
				"READY  %d" % ceili(session.countdown)
				if session.countdown > 0
				else (
					"HOLD TO MOVE / RELEASE TO STOP"
					if session.intent == Vector3i.ZERO
					else "FOLLOW THE GOLDEN FOOD"
				)
			)
		SnakeModel.Phase.PAUSED:
			status = "PAUSED / X TO RESUME" if in_xr else "PAUSED / SPACE TO RESUME"
		SnakeModel.Phase.GAME_OVER:
			status = model.end_reason + (" / Y TO RETRY" if in_xr else " / R TO RETRY")
		SnakeModel.Phase.WON:
			status = "LEVEL COMPLETE / YOU WIN"
	_set_label("status", status)
	_set_label(
		"controls",
		(
			"HOLD RIGHT: steer   HOLD LEFT: up / down\nRELEASE: stop   X: pause / resume   Y: restart"
			if in_xr
			else (
				"HOLD WASD: steer   HOLD Q / E: up / down\n"
				+ "RELEASE: stop   SPACE: pause   R: restart   C: centre"
			)
		)
	)
	_set_label("food", food)
	_set_label(
		"movement",
		(
			(
				"STOPPED / REVERSE BLOCKED"
				if session.last_requested != Vector3i.ZERO
				else "STOPPED / HOLD TO MOVE"
			)
			if session.intent == Vector3i.ZERO
			else "MOVING: " + direction
		)
	)
	_set_label("tutorial", tutorial)
