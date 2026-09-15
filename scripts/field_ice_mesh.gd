extends RefCounted
## A single irregular ice sheet; the actor version is an open surface coating.
static var meshes: Dictionary = {}
static func build(ground: bool = true) -> ArrayMesh:
	if meshes.has(ground): return meshes[ground]
	var surface := SurfaceTool.new(); surface.begin(Mesh.PRIMITIVE_TRIANGLES); surface.set_smooth_group(0)
	const SEGMENTS := 80
	const RINGS := 16
	for ring in RINGS:
		for side in SEGMENTS:
			for corner in [Vector2i(side,ring),Vector2i(side+1,ring+1),Vector2i(side+1,ring),Vector2i(side,ring),Vector2i(side,ring+1),Vector2i(side+1,ring+1)]:
				var angle:=float(corner.x)/SEGMENTS*TAU
				var t:=float(corner.y)/RINGS
				var radial:=t if ground else lerpf(.62,1.055,t)
				var irregular:=1.0+sin(angle*3.0+.3)*.055+sin(angle*7.0)*.022+sin(angle*13.0+1.1)*.009
				var y:=.05+.58*(1.0-smoothstep(.52,1.0,t)) if ground else .50+sin(t*PI)*.025
				y+=sin(angle*5.0+t*8.0)*.017*t
				var point:=Vector3(cos(angle)*radial*irregular,y,sin(angle)*radial*irregular*(.84 if ground else 1.0))
				surface.set_uv(Vector2(float(corner.x)/SEGMENTS,t))
				surface.add_vertex(point)
	surface.index(); surface.generate_normals()
	var mesh:=surface.commit(); meshes[ground]=mesh; return mesh
