class_name OrdoMouthMesh
extends RefCounted
static var rim_mesh:ArrayMesh
static func rim()->ArrayMesh:
	if rim_mesh!=null:return rim_mesh
	var surface:=SurfaceTool.new();surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in 48:
		for j in 8:
			for corner in [Vector2i(i,j),Vector2i(i+1,j+1),Vector2i(i+1,j),Vector2i(i,j),Vector2i(i,j+1),Vector2i(i+1,j+1)]:
				var u:=Vector2(float(corner.x)/48.0,float(corner.y)/8.0)
				surface.set_uv(u);surface.set_normal(Vector3.FORWARD)
				surface.add_vertex(Vector3(cos(u.x*TAU),sin(u.x*TAU),sin(u.y*TAU)*.1))
	rim_mesh=surface.commit();return rim_mesh
