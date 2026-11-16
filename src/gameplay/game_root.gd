class_name SnakeGame
extends Node3D
## Composition root: explicit dependencies, session signals, public content APIs.
@export var catalog: GameCatalog
@export var initial_level := "classic"
@export var save_enabled := true
var session := GameSession.new()
var tutorial := TutorialRunner.new()
var profile := ProfileStore.new()
var input_source: IntentSource
var _skin: SnakeSkin
var _centered := false
var _hud_elapsed := 0.0
var _ready_to_play := false

@onready var rig: PlayerRig = $PlayerRig
@onready var arena: ArenaView = $Arena


func _ready() -> void:
	var errors := catalog.validate()
	if not errors.is_empty():
		push_error("Invalid content catalog: " + str(errors))
		return
	profile.enabled = save_enabled
	profile.load_profile()
	_skin = catalog.skin_by_id(profile.selected_skin)
	if _skin == null:
		_skin = catalog.skins[0]
	if rig.in_xr:
		var source := ControllerIntentSource.new()
		source.configure(rig.left, rig.right)
		input_source = source
	else:
		input_source = KeyboardIntentSource.new()
	session.input_reset_requested.connect(func(): input_source.reset())
	session.round_reset.connect(_round_reset)
	session.step_committed.connect(func(): arena.sync(session.model))
	session.food_eaten.connect(func(_score): tutorial.notify("food"))
	session.intent_changed.connect(_intent_changed)
	session.round_finished.connect(_round_finished)
	tutorial.completed.connect(profile.complete_tutorial)
	rig.play_requested.connect(session.toggle_play)
	rig.restart_requested.connect(session.restart)
	rig.focus_lost.connect(session.pause)
	rig.recentered.connect(
		func():
			session.pause()
			_centered = false
	)
	var selected := initial_level
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--level="):
			selected = argument.trim_prefix("--level=")
	if select_level(selected) != OK:
		return
	_ready_to_play = true
	if "--capture-preview" in OS.get_cmdline_user_args():
		_capture_preview()


func select_level(id: String) -> Error:
	var level := catalog.level_by_id(id)
	return ERR_DOES_NOT_EXIST if level == null else load_level(level)


func load_level(level: SnakeLevel) -> Error:
	var errors := level.validate()
	if not errors.is_empty():
		push_warning("Rejected level: " + str(errors))
		return ERR_INVALID_DATA
	# Initialize presentation before configure() emits round_reset.
	arena.configure(level, _skin)
	session.configure(level)
	_centered = false
	return OK


func select_skin(id: String) -> Error:
	var skin := catalog.skin_by_id(id)
	if skin == null:
		return ERR_DOES_NOT_EXIST
	_skin = skin
	arena.apply_skin(skin)
	profile.selected_skin = id
	return profile.save_profile()


func set_input_source(source: IntentSource) -> void:
	session.pause()
	input_source = source
	input_source.reset()


func _round_reset() -> void:
	arena.sync(session.model, true)
	var definition := session.model.level.tutorial
	tutorial.start(
		(
			definition
			if definition != null and not profile.completed_tutorials.has(definition.id)
			else null
		)
	)
	refresh_hud()


func _intent_changed(intent: Vector3i, requested: Vector3i) -> void:
	if session.model.phase == SnakeModel.Phase.RUNNING:
		if intent != Vector3i.ZERO:
			tutorial.notify("move")
		elif requested == Vector3i.ZERO:
			tutorial.notify("stop")
	print("SNAKE: move intent=", intent, " requested=", requested)


func _round_finished(reason: String, score: int) -> void:
	if session.model.phase == SnakeModel.Phase.GAME_OVER:
		arena.sync(session.model, true)
		if reason == "WALL":
			arena.snake.show_wall_collision(session.model.direction)
	profile.record_score(session.model.level.id, score)
	if session.model.phase == SnakeModel.Phase.WON:
		tutorial.notify("win")
	print(
		"SNAKE: round ended: ",
		reason,
		" head=",
		session.model.body[0],
		" direction=",
		session.model.direction,
		" score=",
		score
	)


func center_arena() -> void:
	var camera := rig.camera()
	arena.position = Vector3(camera.global_position.x, 0, camera.global_position.z)
	var forward := DirectionMapper.floor_forward(camera.global_basis)
	arena.rotation.y = atan2(-forward.x, -forward.z)
	_centered = true


func _input(event: InputEvent) -> void:
	if not _ready_to_play:
		return
	if session.model.phase == SnakeModel.Phase.RUNNING:
		input_source.handle_event(event)
	if event is InputEventKey and event.pressed and not event.echo:
		match event.physical_keycode:
			KEY_SPACE, KEY_P:
				session.toggle_play()
			KEY_R:
				session.restart()
			KEY_ESCAPE:
				session.pause()
			KEY_C:
				session.pause()
				center_arena()


func _process(delta: float) -> void:
	if not _ready_to_play:
		return
	if not _centered and (not rig.in_xr or rig.focused):
		center_arena()
	if rig.focused and input_source.available():
		session.submit_intent(input_source.sample(rig.camera().global_basis, arena.global_basis))
	else:
		session.pause()
	session.tick(delta)
	arena.snake.present(session.interpolation(), minf(delta, 0.1))
	_hud_elapsed += delta
	if _hud_elapsed >= 0.1:
		_hud_elapsed = 0
		refresh_hud()


func refresh_hud() -> void:
	var best := maxi(session.model.score, int(profile.best_scores.get(session.model.level.id, 0)))
	var direction := session.model.direction
	var name := "UP" if direction.y > 0 else "DOWN"
	if direction.y == 0:
		var forward := DirectionMapper.floor_forward(rig.camera().global_basis)
		var world := arena.global_basis * Vector3(direction)
		var right := world.dot(forward.cross(Vector3.UP))
		var ahead := world.dot(forward)
		name = (
			("VIEW RIGHT" if right > 0 else "VIEW LEFT")
			if absf(right) > absf(ahead)
			else ("VIEW FORWARD" if ahead > 0 else "VIEW BACK")
		)
	arena.hud.present(
		session, best, rig.in_xr, arena.food_hint(rig.camera()), name, tutorial.instruction()
	)


func _capture_preview() -> void:
	await get_tree().create_timer(0.8).timeout
	await RenderingServer.frame_post_draw
	DirAccess.make_dir_recursive_absolute("res://builds")
	var result := get_viewport().get_texture().get_image().save_png(
		"res://builds/snake-game-preview.png"
	)
	get_tree().quit(result)
