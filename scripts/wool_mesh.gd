class_name OrdoWoolMesh
extends RefCounted

static func token(radius: float) -> ArrayMesh:
	# One opaque padded body. No intersecting cylinder, dome or label planes.
	var profile := [Vector2(0,0.05),Vector2(radius*0.78,0.05),Vector2(radius*0.98,0.065),Vector2(radius*1.06,0.10),Vector2(radius*1.08,0.15),Vector2(radius*1.04,0.21),Vector2(radius*0.90,0.24),Vector2(radius*0.82,0.20),Vector2(radius*0.74,0.215),Vector2(radius*0.55,0.245),Vector2(radius*0.26,0.258),Vector2(0,0.26)]
	var tool := SurfaceTool.new(); tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	for ring in range(profile.size() - 1):
		for i in 80:
			for corner in [Vector2(i, ring), Vector2(i + 1, ring), Vector2(i + 1, ring + 1), Vector2(i, ring), Vector2(i + 1, ring + 1), Vector2(i, ring + 1)]:
				var a: float = corner.x * TAU / 80.0
				var point: Vector2 = profile[int(corner.y)]
				var r := point.x * (1.0 + sin(a * 5.0) * 0.008 + sin(a * 11.0) * 0.004)
				tool.set_uv(Vector2(corner.x / 80.0, float(corner.y) / (profile.size() - 1)))
				tool.add_vertex(Vector3(cos(a) * r, point.y, sin(a) * r))
	tool.generate_normals(); return tool.commit()

static func thread_path(parent: Node3D, points: PackedVector3Array, width: float, material: Material) -> MultiMeshInstance3D:
	var mesh := CapsuleMesh.new(); mesh.radius = width; mesh.height = 1.0; mesh.radial_segments = 8; mesh.rings = 2
	var mm := MultiMesh.new(); mm.transform_format = MultiMesh.TRANSFORM_3D; mm.mesh = mesh; mm.instance_count = points.size() - 1
	for i in range(points.size() - 1):
		var delta := points[i + 1] - points[i]
		var direction := delta.normalized()
		var helper := Vector3.UP if absf(direction.dot(Vector3.UP)) < 0.99 else Vector3.FORWARD
		var x := helper.cross(direction).normalized()
		var basis := Basis(x, direction * (delta.length() + width * 0.65), x.cross(direction))
		mm.set_instance_transform(i, Transform3D(basis, (points[i] + points[i + 1]) * 0.5))
	var node := MultiMeshInstance3D.new(); node.multimesh = mm; node.material_override = material; parent.add_child(node)
	return node

static func emblem(parent: Node3D, slot: int, material: Material) -> void:
	var points := PackedVector3Array()
	var count: int = [3, 6, 4, 48][slot]
	var r: float = [0.205, 0.19, 0.20, 0.165][slot]
	for i in count + 1:
		var a: float = TAU * i / count - PI / 2
		points.append(Vector3(cos(a) * r, 0.451, sin(a) * r))
	var mesh := thread_path(parent, points, 0.019, material); mesh.name = "Emblem"

static func seam(parent: Node3D, radius: float, material: Material) -> void:
	var points := PackedVector3Array()
	for i in 101:
		var a := TAU * i / 100.0
		points.append(Vector3(cos(a) * radius, 0.34, sin(a) * radius))
	thread_path(parent, points, 0.012, material).name = "Seam"
	for i in 32:
		var a := TAU * i / 32.0
		var p := Vector3(cos(a) * radius, 0.35, sin(a) * radius)
		var along := Vector3(-sin(a), 0, cos(a)) * 0.016
		thread_path(parent, PackedVector3Array([p - along + Vector3(0, -0.018, 0), p + along + Vector3(0, 0.018, 0)]), 0.009, material)
