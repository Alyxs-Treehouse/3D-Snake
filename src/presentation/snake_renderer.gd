class_name SnakeRenderer
extends Node3D
## Four render nodes regardless of snake length. No resource creation in animate().
const NOSE_RADIUS := 0.07
var level: SnakeLevel
var skin: SnakeSkin
var head: MeshInstance3D
var nose: MeshInstance3D
var bodies: MultiMeshInstance3D
var links: MultiMeshInstance3D
var head_direction := Vector3.RIGHT
var length := 0
var _from := PackedVector3Array()
var _to := PackedVector3Array()
var _positions := PackedVector3Array()
var _impact_offset := Vector3.ZERO
var _impact_duration := 0.0
var _impact_time := 0.0
var _default_link_mesh: Mesh
var _last_alpha := -1.0
var _last_impact := -1.0


func configure(config: SnakeLevel, appearance: SnakeSkin) -> void:
	level = config
	skin = appearance
	for child in get_children():
		child.free()
	var size := level.room_size()
	var bounds := AABB(Vector3(-size.x / 2, 0, -size.z / 2) - Vector3.ONE, size + Vector3.ONE * 2)
	head = MeshFactory.instance(MeshFactory.sphere(skin.radius, 16, 8), skin.head_color, false)
	nose = MeshFactory.instance(MeshFactory.sphere(NOSE_RADIUS), skin.nose_color, false)
	var tube := CylinderMesh.new()
	tube.top_radius = 0.115
	tube.bottom_radius = 0.115
	tube.height = 1.0
	tube.radial_segments = 10
	_default_link_mesh = tube
	bodies = MeshFactory.batch(
		MeshFactory.sphere(skin.radius), level.volume(), bounds, skin.body_color, false
	)
	links = MeshFactory.batch(tube, level.volume(), bounds, skin.body_color, false)
	for node in [head, nose, bodies, links]:
		add_child(node)
	_from.resize(level.volume())
	_to.resize(level.volume())
	_positions.resize(level.volume())
	length = 0
	apply_skin(skin)


func apply_skin(value: SnakeSkin) -> void:
	skin = value
	head.mesh = (
		value.head_mesh if value.head_mesh != null else MeshFactory.sphere(value.radius, 16, 8)
	)
	bodies.multimesh.mesh = (
		value.body_mesh if value.body_mesh != null else MeshFactory.sphere(value.radius)
	)
	links.multimesh.mesh = value.link_mesh if value.link_mesh != null else _default_link_mesh
	head.material_override.albedo_color = skin.head_color
	bodies.material_override.albedo_color = skin.body_color
	links.material_override.albedo_color = skin.body_color
	nose.material_override.albedo_color = skin.nose_color
	_last_alpha = -1


func sync(cells: Array[Vector3i], direction: Vector3i, snap := false) -> void:
	var previous_length := length
	var old_tail := _to[previous_length - 1] if previous_length > 0 else Vector3.ZERO
	for i in cells.size():
		var position := level.position_of(cells[i])
		_from[i] = (
			(_to[i] if i < previous_length else old_tail)
			if previous_length > 0 and not snap
			else position
		)
		_to[i] = position
	length = cells.size()
	bodies.multimesh.visible_instance_count = maxi(0, length - 1)
	links.multimesh.visible_instance_count = maxi(0, length - 1)
	head_direction = Vector3(direction)
	_impact_offset = Vector3.ZERO
	_impact_duration = 0
	_impact_time = 0
	_last_alpha = -1
	nose.material_override.albedo_color = skin.nose_color
	animate(1 if snap else 0)


func show_wall_collision(direction: Vector3i) -> void:
	head_direction = Vector3(direction)
	var cell_length := (level.cell_size * head_direction).length()
	var distance := maxf(0, cell_length * 0.5 - nose_offset() - NOSE_RADIUS)
	_impact_offset = head_direction * distance
	_impact_duration = level.step_seconds * distance / cell_length
	_impact_time = 0
	nose.material_override.albedo_color = skin.impact_color
	_last_alpha = -1
	animate(1)


func present(alpha: float, dt: float) -> void:
	var impact := 0.0
	if _impact_duration > 0:
		_impact_time = minf(_impact_duration, _impact_time + maxf(0, dt))
		impact = _impact_time / _impact_duration
	animate(alpha, impact)


func animate(alpha: float, impact := 0.0) -> void:
	if length == 0 or (alpha == _last_alpha and impact == _last_impact):
		return
	_last_alpha = alpha
	_last_impact = impact
	for i in length:
		_positions[i] = _from[i].lerp(_to[i], alpha)
	_positions[0] += _impact_offset * clampf(impact, 0, 1)
	head.position = _positions[0]
	nose.position = head.position + head_direction * nose_offset()
	for i in range(1, length):
		bodies.multimesh.set_instance_transform(i - 1, Transform3D(Basis.IDENTITY, _positions[i]))
		var a := _positions[i - 1]
		var b := _positions[i]
		var distance := a.distance_to(b)
		var transform := Transform3D(Basis.from_scale(Vector3.ZERO), a)
		if distance > 0.001:
			var axis := (b - a) / distance
			var helper := Vector3.RIGHT if absf(axis.y) > 0.95 else Vector3.UP
			var x := axis.cross(helper).normalized()
			transform = Transform3D(Basis(x, axis * distance, x.cross(axis)), (a + b) * 0.5)
		links.multimesh.set_instance_transform(i - 1, transform)


func nose_offset() -> float:
	return skin.radius - 0.02


func body_position(index: int) -> Vector3:
	return _positions[index]
