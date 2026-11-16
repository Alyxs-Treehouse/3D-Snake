class_name GameSession
extends RefCounted
## Public gameplay API. Input is a current state, never a latched one-shot turn.
signal round_reset
signal step_committed
signal round_finished(reason: String, score: int)
signal food_eaten(score: int)
signal phase_changed
signal intent_changed(intent: Vector3i, requested: Vector3i)
signal input_reset_requested

var model := SnakeModel.new()
var elapsed := 0.0
var countdown := 0.0
var intent := Vector3i.ZERO
var last_requested := Vector3i.ZERO


func configure(level: SnakeLevel, random_seed := -1) -> PackedStringArray:
	var errors := model.configure(level, random_seed)
	if errors.is_empty():
		_reset_clock()
	return errors


func _reset_clock() -> void:
	elapsed = model.level.step_seconds
	countdown = model.level.countdown_seconds
	clear_input()
	round_reset.emit()
	phase_changed.emit()


func clear_input() -> void:
	intent = Vector3i.ZERO
	last_requested = Vector3i.ZERO
	input_reset_requested.emit()


func toggle_play() -> void:
	match model.phase:
		SnakeModel.Phase.GAME_OVER, SnakeModel.Phase.WON:
			restart()
			return
		SnakeModel.Phase.RUNNING:
			model.phase = SnakeModel.Phase.PAUSED
		_:
			model.phase = SnakeModel.Phase.RUNNING
	clear_input()
	phase_changed.emit()


func pause() -> void:
	if model.phase == SnakeModel.Phase.RUNNING:
		model.phase = SnakeModel.Phase.PAUSED
		phase_changed.emit()
	clear_input()


func restart() -> void:
	model.reset()
	model.phase = SnakeModel.Phase.RUNNING
	_reset_clock()


func submit_intent(value: Vector3i) -> void:
	intent = (
		value if model.phase == SnakeModel.Phase.RUNNING and model.accepts(value) else Vector3i.ZERO
	)
	if value != last_requested:
		intent_changed.emit(intent, value)
	last_requested = value


func tick(delta: float) -> void:
	var dt := clampf(delta, 0.0, 0.1)  # No burst of catch-up steps after a suspended frame.
	if model.phase != SnakeModel.Phase.RUNNING:
		return
	if countdown > 0:
		countdown = maxf(0, countdown - dt)
	elif intent != Vector3i.ZERO:
		elapsed += dt
		if elapsed >= model.level.step_seconds:
			elapsed -= model.level.step_seconds
			advance()


func advance() -> void:
	if intent == Vector3i.ZERO or model.phase != SnakeModel.Phase.RUNNING:
		return
	var old_score := model.score
	if model.step(intent):
		step_committed.emit()
	if model.score != old_score:
		food_eaten.emit(model.score)
	if model.phase in [SnakeModel.Phase.GAME_OVER, SnakeModel.Phase.WON]:
		intent = Vector3i.ZERO
		elapsed = model.level.step_seconds
		round_finished.emit(model.end_reason, model.score)
		phase_changed.emit()


func interpolation() -> float:
	return clampf(elapsed / model.level.step_seconds, 0, 1)
