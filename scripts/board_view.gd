extends Node3D
## Room-scale arena. The observer is at its floor centre, inside all six bounds.

const CELL := Vector3(0.8, 0.5, 0.8)
const ROOM := Vector3(6.4, 4.0, 6.4)
const MINT := Color("64f5cb")
const GOLD := Color("ffd486")
const NOSE_RADIUS := 0.07
const NOSE_OFFSET := 0.16
var bodies: Array[MeshInstance3D] = []
var links: Array[MeshInstance3D] = []
var from_cells: Array[Vector3i] = []
var to_cells: Array[Vector3i] = []
var food_mesh: MeshInstance3D
var food_beam: MeshInstance3D
var nose: MeshInstance3D
var title: Label3D
var status: Label3D
var score_label: Label3D
var controls: Label3D
var food_label: Label3D
var turn_label: Label3D
var head_direction := Vector3.RIGHT
var wall_hit_offset := Vector3.ZERO


static func cell_position(cell: Vector3i) -> Vector3:
	return Vector3((cell.x - 3.5) * CELL.x, (cell.y + 0.5) * CELL.y, (cell.z - 3.5) * CELL.z)


func _ready() -> void:
	_box(Vector3(7.4, 0.1, 7.4), Vector3(0, -0.07, 0), Color("0b1725"), false)
	for i in 9:
		var p := -3.2 + i * 0.8
		_box(Vector3(0.008, 0.008, 6.4), Vector3(p, 0, 0), Color("21404d"))
		_box(Vector3(6.4, 0.008, 0.008), Vector3(0, 0, p), Color("21404d"))
		for edge in [-3.2, 3.2]:
			_box(Vector3(0.008, 4.0, 0.008), Vector3(p, 2.0, edge), Color("142e3e"))
			_box(Vector3(0.008, 4.0, 0.008), Vector3(edge, 2.0, p), Color("142e3e"))
	for y in [0.01, 4.0]:
		for edge in [-3.2, 3.2]:
			_box(Vector3(6.4, 0.025, 0.025), Vector3(0, y, edge), Color("347578"))
			_box(Vector3(0.025, 0.025, 6.4), Vector3(edge, y, 0), Color("347578"))
	for x in [-3.2, 3.2]:
		for z in [-3.2, 3.2]:
			_box(Vector3(0.025, 4, 0.025), Vector3(x, 2, z), Color("347578"))
	# A ground marker anchors the user's standing position, without moving the rig.
	var ring := TorusMesh.new()
	ring.inner_radius = 0.48
	ring.outer_radius = 0.50
	_mesh(ring, Vector3(0, 0.015, 0), Color("4bbca9"))
	_box(Vector3(3.5, 1.13, 0.04), Vector3(0, 2.93, -3.19), Color("0b1c2c"))
	title = label("SPATIAL SNAKE", Vector3(0, 3.34, -3.15), 42, MINT)
	score_label = label("", Vector3(0, 3.10, -3.15), 26, Color("dce9f1"))
	status = label("", Vector3(0, 2.86, -3.15), 27, GOLD)
	controls = label("", Vector3(0, 2.60, -3.15), 22, Color("b1c8d7"))
	food_label = label("", Vector3(0, 2.25, -3.15), 24, GOLD)
	turn_label = label("", Vector3(0, 2.07, -3.15), 21, Color("96b3c8"))
	for i in 4:
		var angle := i * PI / 2.0
		var p := Vector3(0, 0.2, -3.17).rotated(Vector3.UP, angle)
		var marker := label(["01 / FRONT", "02 / LEFT", "03 / BACK", "04 / RIGHT"][i], p, 23, Color("69a3b7"))
		marker.rotation.y = angle
	food_mesh = _sphere(0.14, GOLD)
	food_beam = _box(Vector3(0.008, 1, 0.008), Vector3.ZERO, Color("88632f"))
	nose = _sphere(NOSE_RADIUS, Color("f2ffff"))


func material(color: Color, unshaded := true) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = 0.6
	if unshaded:
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	return m


func _mesh(mesh: Mesh, at: Vector3, color: Color, unshaded := true) -> MeshInstance3D:
	var instance := MeshInstance3D.new()
	instance.mesh = mesh
	instance.position = at
	instance.material_override = material(color, unshaded)
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(instance)
	return instance


func _box(size: Vector3, at: Vector3, color: Color, unshaded := true) -> MeshInstance3D:
	var box := BoxMesh.new()
	box.size = size
	return _mesh(box, at, color, unshaded)


func _sphere(radius: float, color: Color) -> MeshInstance3D:
	var sphere := SphereMesh.new()
	sphere.radius = radius
	sphere.height = radius * 2.0
	sphere.radial_segments = 16
	sphere.rings = 8
	return _mesh(sphere, Vector3.ZERO, color, false)


func label(value: String, at: Vector3, size: int, color: Color) -> Label3D:
	var text := Label3D.new()
	text.text = value
	text.position = at
	text.font_size = size
	text.pixel_size = 0.0035
	text.modulate = color
	text.outline_size = 0
	add_child(text)
	return text


func sync(cells: Array[Vector3i], food: Vector3i, direction: Vector3i, snap := false) -> void:
	wall_hit_offset = Vector3.ZERO
	nose.material_override.albedo_color = Color("f2ffff")
	from_cells.assign(to_cells if not to_cells.is_empty() and not snap else cells)
	to_cells.assign(cells)
	while from_cells.size() < cells.size():
		from_cells.append(from_cells.back())
	while bodies.size() < cells.size():
		bodies.append(_sphere(0.18, MINT if bodies.is_empty() else Color("2c9f9b")))
	while bodies.size() > cells.size():
		bodies.pop_back().queue_free()
	while links.size() < maxi(0, cells.size() - 1):
		var tube := CylinderMesh.new()
		tube.top_radius = 0.115
		tube.bottom_radius = 0.115
		tube.height = 1.0
		tube.radial_segments = 12
		links.append(_mesh(tube, Vector3.ZERO, Color("2c9f9b"), false))
	while links.size() > maxi(0, cells.size() - 1):
		links.pop_back().queue_free()
	head_direction = Vector3(direction)
	food_mesh.visible = food.x >= 0
	food_beam.visible = food.x >= 0
	if food.x >= 0:
		food_mesh.position = cell_position(food)
		food_beam.position = Vector3(food_mesh.position.x, food_mesh.position.y * 0.5, food_mesh.position.z)
		food_beam.scale.y = food_mesh.position.y
	animate(1.0 if snap else 0.0)


func show_wall_collision(direction: Vector3i) -> float:
	# A rejected grid step still changes the collision heading. Show the actual
	# impact face instead of leaving the nose pointing along the previous wall.
	head_direction = Vector3(direction)
	var cell_length := (CELL * head_direction).length()
	var travel := maxf(0.0, cell_length * 0.5 - NOSE_OFFSET - NOSE_RADIUS)
	wall_hit_offset = head_direction * travel
	nose.material_override.albedo_color = Color("ff776b")
	animate(1.0)
	return travel / cell_length


func animate(progress: float, impact_progress := 0.0) -> void:
	for i in bodies.size():
		bodies[i].position = cell_position(from_cells[i]).lerp(cell_position(to_cells[i]), progress)
	if not bodies.is_empty():
		bodies[0].position += wall_hit_offset * clampf(impact_progress, 0.0, 1.0)
	for i in links.size():
		var a := bodies[i].position
		var b := bodies[i + 1].position
		var length := a.distance_to(b)
		links[i].visible = length > 0.001
		if length > 0.001:
			var axis := (b - a) / length
			var helper := Vector3.RIGHT if absf(axis.y) > 0.95 else Vector3.UP
			var x := axis.cross(helper).normalized()
			links[i].transform = Transform3D(Basis(x, axis * length, x.cross(axis)), (a + b) * 0.5)
	if not bodies.is_empty():
		nose.position = bodies[0].position + head_direction * NOSE_OFFSET


func food_hint(viewer: Node3D) -> String:
	if not food_mesh.visible:
		return "ALL CELLS FILLED"
	var local := viewer.global_basis.inverse() * (food_mesh.global_position - viewer.global_position)
	var bearing := "AHEAD" if local.z < 0 else "BEHIND"
	if absf(local.x) > absf(local.z) * 0.6:
		bearing += " / " + ("RIGHT" if local.x > 0 else "LEFT")
	if local.y > 0.5:
		bearing += " / ABOVE"
	elif local.y < -0.5:
		bearing += " / BELOW"
	return "FOOD  %s   %.1f m" % [bearing, local.length()]
