extends Node3D

func _ready():
	# Poligon original cu 6 colțuri
	var footprint = PackedVector2Array([
		Vector2(0,0),
		Vector2(2,0),
		Vector2(3,1),
		Vector2(2.5,3),
		Vector2(1,2.5),
		Vector2(0,1)
	])
	
	# Offset interior 0.125
	var inner_polygons = Geometry2D.offset_polygon(footprint, -0.125)
	
	# Material pentru volumul final
	var mat = StandardMaterial3D.new()
	mat.albedo_color = Color(0.2, 0.6, 0.8)
	
	# Creăm un CSGCombiner3D ca root
	var combiner = CSGCombiner3D.new()
	combiner.operation = CSGShape3D.OPERATION_UNION
	add_child(combiner)
	
	# 1. Volumul exterior (poligonul original extrudat)
	var outer_volume = CSGPolygon3D.new()
	outer_volume.polygon = footprint
	outer_volume.depth = 2.55
	outer_volume.operation = CSGShape3D.OPERATION_UNION
	outer_volume.position = Vector3(0, 0, 2.55/2)
	outer_volume.material = mat
	combiner.add_child(outer_volume)
	
	# 2. Volumul interior (pentru tăiere) - doar dacă există
	if inner_polygons.size() > 0:
		var inner_poly = inner_polygons[0]
		
		var inner_volume = CSGPolygon3D.new()
		inner_volume.polygon = inner_poly
		inner_volume.depth = 2.55 + 0.01  # Puțin mai înalt pentru tăiere completă
		inner_volume.operation = CSGShape3D.OPERATION_SUBTRACTION
		inner_volume.position = Vector3(0, 0, 2.55/2)
		combiner.add_child(inner_volume)
	else:
		print("Offset-ul a fost prea mare - nu se poate crea volumul interior")
