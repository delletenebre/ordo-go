extends RefCounted
## One connected, softly bevelled flame silhouette with a forked crown.
static var meshes: Dictionary = {}

static func build(width: float, height: float) -> ArrayMesh:
	var key := Vector2(width,height)
	if meshes.has(key): return meshes[key]
	var outline := PackedVector2Array([
		Vector2(0,.02),Vector2(-.28,.055),Vector2(-.46,.18),Vector2(-.50,.36),
		Vector2(-.43,.53),Vector2(-.30,.66),Vector2(-.25,.84),
		Vector2(-.15,.68),Vector2(-.13,.55),Vector2(-.035,.68),
		Vector2(.055,.86),Vector2(.025,1.0),Vector2(.21,.88),
		Vector2(.31,.71),Vector2(.28,.53),Vector2(.37,.61),
		Vector2(.42,.73),Vector2(.51,.52),Vector2(.50,.32),
		Vector2(.40,.15),Vector2(.24,.055)])
	var contour := PackedVector2Array()
	# Retain the three pointed tips; round the broad base and the flame folds.
	for i in outline.size():
		var prev: Vector2=outline[posmod(i-1,outline.size())]
		var point: Vector2=outline[i]
		var next: Vector2=outline[(i+1)%outline.size()]
		if i in [6,11,16]:
			contour.append(point)
		else:
			var before := point.lerp(prev,.24)
			var after := point.lerp(next,.24)
			for step in 4:
				var t:=float(step)/3.0
				contour.append(before.lerp(point,t).lerp(point.lerp(after,t),t))
	var triangles := Geometry2D.triangulate_polygon(contour)
	var surface := SurfaceTool.new(); surface.begin(Mesh.PRIMITIVE_TRIANGLES); surface.set_smooth_group(0)
	const SUBDIVISIONS := 6
	for side in [-1.0,1.0]:
		for triangle in range(0,triangles.size(),3):
			var a: Vector2=contour[triangles[triangle]]
			var b: Vector2=contour[triangles[triangle+1]]
			var c: Vector2=contour[triangles[triangle+2]]
			for row in SUBDIVISIONS:
				for col in range(SUBDIVISIONS-row):
					var cells := [[Vector2i(row,col),Vector2i(row+1,col),Vector2i(row,col+1)]]
					if col<SUBDIVISIONS-row-1:
						cells.append([Vector2i(row+1,col),Vector2i(row+1,col+1),Vector2i(row,col+1)])
					for cell in cells:
						if side<0: cell.reverse()
						for index in cell:
							var point: Vector2=a+(b-a)*float(index.x)/SUBDIVISIONS+(c-a)*float(index.y)/SUBDIVISIONS
							var distance := 1.0
							for edge in contour.size():
								distance=minf(distance,point.distance_to(Geometry2D.get_closest_point_to_segment(point,contour[edge],contour[(edge+1)%contour.size()])))
							var depth: float=sin(clampf(distance/.16,0,1)*PI*.5)*width*.13*float(side)
							surface.set_uv(Vector2(point.x+.5,point.y))
							surface.add_vertex(Vector3(point.x*width,point.y*height,depth))
	surface.index(); surface.generate_normals()
	var mesh := surface.commit()
	meshes[key]=mesh
	return mesh
