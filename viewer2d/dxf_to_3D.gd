extends Node3D

func _ready():
	var path = "res://out.json"
	if not FileAccess.file_exists(path):
		push_error("Fișierul nu există: %s" % path)
		return

	var json_str = FileAccess.get_file_as_string(path).strip_edges(true, true)
	var data = JSON.parse_string(json_str)
	if data == null:
		push_error("Eroare la parsarea JSON-ului.")
		return

	if typeof(data) == TYPE_ARRAY:
		for entity in data:
			match entity.type:
				"LWPOLYLINE":
					var poly = create_polygon(entity.points, entity.closed)
					add_child(poly)
				"CIRCLE":
					var circle = create_circle(entity.center, entity.radius)
					add_child(circle)


# Creează un CSGPolygon3D din puncte
func create_polygon(points: Array, closed: bool) -> CSGPolygon3D:
	var arr: PackedVector2Array = []
	for p in points:
		arr.append(Vector2(p[0], p[1]))
	if closed:
		arr.append(Vector2(points[0][0], points[0][1]))

	var csg = CSGPolygon3D.new()
	csg.polygon = arr       # aici merge array direct, nu Curve2D
	csg.mode = CSGPolygon3D.MODE_DEPTH
	csg.depth = 1.0
	return csg


# Creează un cerc aproximat cu poligon regulat
func create_circle(center: Array, radius: float, segments: int = 32) -> CSGPolygon3D:
	var arr: PackedVector2Array = []
	for i in range(segments):
		var angle = (TAU / segments) * i
		var x = center[0] + cos(angle) * radius
		var y = center[1] + sin(angle) * radius
		arr.append(Vector2(x, y))
	arr.append(arr[0]) # închide cercul

	var csg = CSGPolygon3D.new()
	csg.polygon = arr
	csg.mode = CSGPolygon3D.MODE_DEPTH
	csg.depth = 1.0
	return csg
