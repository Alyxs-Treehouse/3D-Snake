class_name ArenaView
extends Node3D
## Arena geometry is built only on level load and batched by material.
var level: SnakeLevel
var food_mesh: MeshInstance3D
var food_beam: MeshInstance3D
var _room: Node3D
var _groups: Dictionary = {}

@onready var snake: SnakeRenderer = $Snake
@onready var hud: GameHud = $Hud


func configure(config: SnakeLevel, skin: SnakeSkin) -> void:
	level = config
	if is_instance_valid(_room):
		_room.free()
	_room = Node3D.new()
	add_child(_room)
	_groups.clear()
	var size := level.room_size()
	var hx := size.x / 2
	var hz := size.z / 2
	_box(Vector3(size.x + 1, 0.1, size.z + 1), Vector3(0, -0.07, 0), Color("0b1725"))
	for x in range(level.grid_size.x + 1):
		var p := -hx + x * level.cell_size.x
		_box(Vector3(0.008, 0.008, size.z), Vector3(p, 0, 0), Color("21404d"))
		for z in [-hz, hz]:
			_box(Vector3(0.008, size.y, 0.008), Vector3(p, size.y / 2, z), Color("142e3e"))
	for z in range(level.grid_size.z + 1):
		var p := -hz + z * level.cell_size.z
		_box(Vector3(size.x, 0.008, 0.008), Vector3(0, 0, p), Color("21404d"))
		for x in [-hx, hx]:
			_box(Vector3(0.008, size.y, 0.008), Vector3(x, size.y / 2, p), Color("142e3e"))
	for y in [0.01, size.y]:
		for z in [-hz, hz]:
			_box(Vector3(size.x, 0.025, 0.025), Vector3(0, y, z), Color("347578"))
		for x in [-hx, hx]:
			_box(Vector3(0.025, 0.025, size.z), Vector3(x, y, 0), Color("347578"))
	for x in [-hx, hx]:
		for z in [-hz, hz]:
			_box(Vector3(0.025, size.y, 0.025), Vector3(x, size.y / 2, z), Color("347578"))
	for cell in level.obstacles:
		_box(level.cell_size * 0.6, level.position_of(cell), Color("a95e7b"))
	var cube := BoxMesh.new()
	cube.size = Vector3.ONE
	var bounds := AABB(Vector3(-hx - 1, -0.2, -hz - 1), size + Vector3(2, 1, 2))
	for color in _groups:
		var transforms: Array = _groups[color]
		var batch := MeshFactory.batch(cube, transforms.size(), bounds, color)
		for i in transforms.size():
			batch.multimesh.set_instance_transform(i, transforms[i])
		batch.multimesh.visible_instance_count = transforms.size()
		_room.add_child(batch)
	_groups.clear()
	var ring := TorusMesh.new()
	ring.inner_radius = 0.48
	ring.outer_radius = 0.50
	var marker := MeshFactory.instance(ring, Color("4bbca9"))
	marker.position.y = 0.015
	_room.add_child(marker)
	for i in 4:
		var marker_label := Label3D.new()
		marker_label.text = ["01 / FRONT", "02 / LEFT", "03 / BACK", "04 / RIGHT"][i]
		marker_label.position = [
			Vector3(0, 0.2, -hz + 0.03),
			Vector3(-hx + 0.03, 0.2, 0),
			Vector3(0, 0.2, hz - 0.03),
			Vector3(hx - 0.03, 0.2, 0)
		][i]
		marker_label.rotation.y = i * PI / 2
		marker_label.font_size = 23
		marker_label.pixel_size = 0.0035
		marker_label.modulate = Color("69a3b7")
		marker_label.outline_size = 0
		_room.add_child(marker_label)
	food_mesh = MeshFactory.instance(MeshFactory.sphere(0.14), skin.food_color, false)
	food_beam = MeshFactory.instance(cube, Color("88632f"))
	_room.add_child(food_mesh)
	_room.add_child(food_beam)
	snake.configure(level, skin)
	hud.configure(size)


func _box(size: Vector3, at: Vector3, color: Color) -> void:
	if not _groups.has(color):
		_groups[color] = []
	_groups[color].append(Transform3D(Basis.from_scale(size), at))


func sync(model: SnakeModel, snap := false) -> void:
	snake.sync(model.body, model.direction, snap)
	food_mesh.visible = model.food.x >= 0
	food_beam.visible = food_mesh.visible
	if food_mesh.visible:
		food_mesh.position = level.position_of(model.food)
		food_beam.position = Vector3(
			food_mesh.position.x, food_mesh.position.y / 2, food_mesh.position.z
		)
		food_beam.scale = Vector3(0.008, food_mesh.position.y, 0.008)


func apply_skin(skin: SnakeSkin) -> void:
	snake.apply_skin(skin)
	food_mesh.material_override.albedo_color = skin.food_color


func food_hint(viewer: Camera3D) -> String:
	if not food_mesh.visible:
		return "ALL CELLS FILLED"
	var local := (
		viewer.global_basis.inverse() * (food_mesh.global_position - viewer.global_position)
	)
	var bearing := "AHEAD" if local.z < 0 else "BEHIND"
	if absf(local.x) > absf(local.z) * 0.6:
		bearing += " / " + ("RIGHT" if local.x > 0 else "LEFT")
	if local.y > 0.5:
		bearing += " / ABOVE"
	elif local.y < -0.5:
		bearing += " / BELOW"
	return "FOOD  %s   %.1f m" % [bearing, local.length()]
