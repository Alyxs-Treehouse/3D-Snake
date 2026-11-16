class_name MeshFactory
extends RefCounted


static func material(color: Color, unshaded := true) -> StandardMaterial3D:
	var result := StandardMaterial3D.new()
	result.albedo_color = color
	result.roughness = 0.6
	if unshaded:
		result.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	return result


static func sphere(radius: float, segments := 12, rings := 6) -> SphereMesh:
	var mesh := SphereMesh.new()
	mesh.radius = radius
	mesh.height = radius * 2
	mesh.radial_segments = segments
	mesh.rings = rings
	return mesh


static func instance(mesh: Mesh, color: Color, unshaded := true) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	node.mesh = mesh
	node.material_override = material(color, unshaded)
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return node


static func batch(
	mesh: Mesh, capacity: int, bounds: AABB, color: Color, unshaded := true
) -> MultiMeshInstance3D:
	var node := MultiMeshInstance3D.new()
	var multi := MultiMesh.new()
	multi.transform_format = MultiMesh.TRANSFORM_3D
	multi.mesh = mesh
	multi.instance_count = capacity
	multi.visible_instance_count = 0
	multi.custom_aabb = bounds
	node.multimesh = multi
	node.material_override = material(color, unshaded)
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return node
