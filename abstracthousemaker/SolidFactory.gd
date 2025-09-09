extends Node3D
class_name SolidFactory

# Funcție pentru crearea materialului în funcție de tip
func _create_material_for_type(shape_type: String) -> StandardMaterial3D:
	var material = StandardMaterial3D.new()
	
	match shape_type:
		"outer_wall":
			# Pereții cutiei - material solid opac
			material.albedo_color = Color(0.8, 0.7, 0.6, 1.0)  # Bej/maro deschis
			material.metallic = 0.1
			material.roughness = 0.7
			material.flags_transparent = false
		"camera_volume":
			# Camerele - transparente 50% pentru vizualizare
			material.albedo_color = Color(0.3, 0.5, 1.0, 0.5)  # Albastru transparent
			material.flags_transparent = true
			material.blend_mode = BaseMaterial3D.BLEND_MODE_MIX
			material.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_OPAQUE_ONLY
			material.metallic = 0.0
			material.roughness = 0.9
		"rectangle", "L", "T":
			# Tetris shapes pentru tăiere - vor fi făcute invizibile în CSG
			material.albedo_color = Color(0.3, 0.5, 1.0, 1.0)
			material.flags_transparent = false
		_:
			# Default
			material.albedo_color = Color(0.7, 0.7, 0.7, 1.0)
			material.flags_transparent = false
	
	material.shading_mode = BaseMaterial3D.SHADING_MODE_PER_PIXEL
	return material

# Funcție principală pentru crearea formelor CSG
func create_extruded_shape(vertices: Array[Vector2], height: float, shape_type: String = "") -> CSGPolygon3D:
	if vertices.size() < 3:
		return null
	
	var csg_polygon = CSGPolygon3D.new()
	csg_polygon.polygon = PackedVector2Array(vertices)
	csg_polygon.depth = height
	csg_polygon.material = _create_material_for_type(shape_type)
	
	return csg_polygon
	
	return csg_polygon	# Material pe tipuri
	var material = StandardMaterial3D.new()
	
	match shape_type:
		"outer_wall":
			# Pereții cutiei - material solid opac
			material.albedo_color = Color(0.8, 0.7, 0.6, 1.0)  # Bej/maro deschis
			material.metallic = 0.1
			material.roughness = 0.7
			material.flags_transparent = false
		"camera_volume":
			# Camerele - transparente 50% pentru vizualizare
			material.albedo_color = Color(0.3, 0.5, 1.0, 0.5)  # Albastru transparent
			material.flags_transparent = true
			material.blend_mode = BaseMaterial3D.BLEND_MODE_MIX
			material.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_OPAQUE_ONLY
			material.metallic = 0.0
			material.roughness = 0.9
		"rectangle", "L", "T":
			# Tetris shapes pentru tăiere - vor fi făcute invizibile în CSG
			material.albedo_color = Color(0.3, 0.5, 1.0, 1.0)
			material.flags_transparent = false
		_:
			# Default
			material.albedo_color = Color(0.7, 0.7, 0.7, 1.0)
			material.flags_transparent = false
	
	material.shading_mode = BaseMaterial3D.SHADING_MODE_PER_PIXEL
	csg_polygon.material = material
	
	return csg_polygon

func _ensure_no_parent(node: Node):
	if node.get_parent():
		node.get_parent().remove_child(node)

# FUNCȚIA PRINCIPALĂ: Creează cutia cu camere
func create_box_with_rooms(outer_polygon_vertices: Array[Vector2], outer_height: float, tetris_shapes: Array) -> Node3D:
	var container = Node3D.new()
	container.name = "BoxWithRooms"
	
	print("Creating box with ", tetris_shapes.size(), " rooms")
	
	# Creăm un CSGCombiner3D pentru operații booleene
	var combiner = CSGCombiner3D.new()
	combiner.operation = CSGShape3D.OPERATION_SUBTRACTION
	container.add_child(combiner)
	
	# 1. Volumul exterior (poligonul extrudat)
	var outer_volume = create_extruded_shape(outer_polygon_vertices, outer_height, "outer_wall")
	outer_volume.operation = CSGShape3D.OPERATION_UNION
	outer_volume.position = Vector3(0, 0, outer_height/2)
	combiner.add_child(outer_volume)
	
	# 2. Adăugăm fiecare cameră ca operație de subtracție
	for tetris_shape in tetris_shapes:
		if tetris_shape is TetrisShape2D:
			var room = create_extruded_shape(tetris_shape.base_vertices, outer_height + 0.01, "camera_volume")
			room.operation = CSGShape3D.OPERATION_SUBTRACTION
			room.transform = Transform3D(Basis(), Vector3(tetris_shape.position.x, tetris_shape.position.y, outer_height/2))
			combiner.add_child(room)
			print("Added room cutter at: ", room.transform.origin)
	
	# Force update pentru operațiile CSG
	combiner._update_shape()
	
	return container

# Creează pereții cutiei cu găurile tăiate de camere
func create_walls_with_holes(outer_vertices: Array[Vector2], height: float, room_solids: Array[MeshInstance3D]) -> CSGCombiner3D:
	var csg_combiner = CSGCombiner3D.new()
	csg_combiner.operation = CSGShape3D.OPERATION_SUBTRACTION
	csg_combiner.use_collision = true
	
	# Material pentru pereți
	var wall_material = StandardMaterial3D.new()
	wall_material.albedo_color = Color(0.8, 0.7, 0.6, 1.0)  # Bej/maro
	wall_material.metallic = 0.1
	wall_material.roughness = 0.7
	wall_material.flags_transparent = false
	
	# BAZA: Volumul exterior solid (pereții cutiei)
	var outer_walls = CSGPolygon3D.new()
	outer_walls.polygon = PackedVector2Array(outer_vertices)
	outer_walls.depth = height
	outer_walls.operation = CSGShape3D.OPERATION_UNION
	outer_walls.material_override = wall_material
	csg_combiner.add_child(outer_walls)
	
	print("Added outer walls with ", outer_vertices.size(), " vertices, height: ", height)
	
	# TĂIETORI: Fiecare cameră Tetris (invizibilă în rezultatul final)
	for i in range(room_solids.size()):
		var room_solid = room_solids[i]
		var csg_cutter = CSGMesh3D.new()
		csg_cutter.mesh = room_solid.mesh.duplicate()
		csg_cutter.operation = CSGShape3D.OPERATION_SUBTRACTION
		csg_cutter.transform = room_solid.transform
		
		# Face tăietorul invizibil (doar pentru geometrie)
		csg_cutter.material_override = null
		csg_cutter.visible = false
		
		csg_combiner.add_child(csg_cutter)
		print("Added room cutter ", i, " at: ", csg_cutter.transform.origin)
	
	# Force CSG update
	#await get_tree().process_frame
	csg_combiner._update_shape()
	
	return csg_combiner

# Creează camerele transparente pentru vizualizare
func create_transparent_rooms(room_solids: Array[MeshInstance3D]) -> Node3D:
	var rooms_container = Node3D.new()
	
	# Material transparent pentru camere
	var room_material = StandardMaterial3D.new()
	room_material.albedo_color = Color(0.3, 0.5, 1.0, 0.5)  # Albastru transparent 50%
	room_material.flags_transparent = true
	room_material.blend_mode = BaseMaterial3D.BLEND_MODE_MIX
	room_material.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_OPAQUE_ONLY
	room_material.metallic = 0.0
	room_material.roughness = 0.9
	room_material.cull_mode = BaseMaterial3D.CULL_DISABLED  # Vizibil din ambele părți
	
	# Adaugă fiecare cameră ca MeshInstance3D transparent
	for i in range(room_solids.size()):
		var room_solid = room_solids[i]
		var transparent_room = MeshInstance3D.new()
		transparent_room.mesh = room_solid.mesh.duplicate()
		transparent_room.transform = room_solid.transform
		transparent_room.material_override = room_material
		transparent_room.name = "Room_" + str(i)
		
		rooms_container.add_child(transparent_room)
		print("Added transparent room ", i, " at: ", transparent_room.transform.origin)
	
	return rooms_container

# Versiune simplificată pentru cazuri simple
func create_simple_box_with_rooms(outer_vertices: Array[Vector2], outer_height: float, tetris_solids: Array[MeshInstance3D]) -> CSGCombiner3D:
	"""
	Versiune mai simplă - doar CSG-ul cu tăierea, fără camerele transparente separate
	"""
	var csg_combiner = CSGCombiner3D.new()
	csg_combiner.operation = CSGShape3D.OPERATION_SUBTRACTION
	csg_combiner.use_collision = true
	
	# Material pentru rezultatul final
	var final_material = StandardMaterial3D.new()
	final_material.albedo_color = Color(0.8, 0.7, 0.6, 1.0)
	final_material.metallic = 0.1
	final_material.roughness = 0.7
	
	# Volumul de bază
	var outer_volume = CSGPolygon3D.new()
	outer_volume.polygon = PackedVector2Array(outer_vertices)
	outer_volume.depth = outer_height
	outer_volume.operation = CSGShape3D.OPERATION_UNION
	outer_volume.material_override = final_material
	csg_combiner.add_child(outer_volume)
	
	# Tăietoriii
	for tetris_solid in tetris_solids:
		var csg_cutter = CSGMesh3D.new()
		csg_cutter.mesh = tetris_solid.mesh.duplicate()
		csg_cutter.operation = CSGShape3D.OPERATION_SUBTRACTION
		csg_cutter.transform = tetris_solid.transform
		csg_cutter.visible = false  # Invizibil
		csg_combiner.add_child(csg_cutter)
	
	await get_tree().process_frame
	csg_combiner._update_shape()
	
	return csg_combiner

# Funcție helper pentru a crea solid Tetris cu tipul corect de material
func create_tetris_room_shape(vertices: Array[Vector2], height: float) -> CSGPolygon3D:
	"""
	Creează o formă CSG pentru cameră
	"""
	return create_extruded_shape(vertices, height, "camera_volume")

# Funcție helper pentru pereți exteriori
func create_outer_wall_shape(vertices: Array[Vector2], height: float) -> CSGPolygon3D:
	"""
	Creează forma CSG pentru pereții exteriori
	"""
	return create_extruded_shape(vertices, height, "outer_wall")

# Funcție de debug pentru a verifica poziționarea
func debug_room_positions(outer_vertices: Array[Vector2], room_solids: Array[MeshInstance3D]) -> void:
	print("=== DEBUG ROOM POSITIONS ===")
	
	# Bounding box al poligonului exterior
	var outer_min = Vector2(INF, INF)
	var outer_max = Vector2(-INF, -INF)
	for vertex in outer_vertices:
		outer_min.x = min(outer_min.x, vertex.x)
		outer_min.y = min(outer_min.y, vertex.y)
		outer_max.x = max(outer_max.x, vertex.x)
		outer_max.y = max(outer_max.y, vertex.y)
	
	print("Outer polygon bounds: ", outer_min, " to ", outer_max)
	
	# Verifică fiecare cameră
	for i in range(room_solids.size()):
		var room = room_solids[i]
		var pos = room.transform.origin
		print("Room ", i, " position: ", pos)
		
		if pos.x >= outer_min.x and pos.x <= outer_max.x and pos.y >= outer_min.y and pos.y <= outer_max.y:
			print("  -> INSIDE outer bounds ✓")
		else:
			print("  -> OUTSIDE outer bounds ✗")

# Legacy functions pentru compatibilitate
func create_polygon_minus_tetris(polygon_solid: CSGPolygon3D, tetris_solids: Array[CSGPolygon3D]) -> CSGCombiner3D:
	# Creăm un CSGCombiner3D pentru operații booleene
	var combiner = CSGCombiner3D.new()
	combiner.operation = CSGShape3D.OPERATION_SUBTRACTION
	
	# Volumul exterior
	var outer_volume = CSGPolygon3D.new()
	outer_volume.polygon = polygon_solid.polygon
	outer_volume.depth = polygon_solid.depth
	outer_volume.operation = CSGShape3D.OPERATION_UNION
	outer_volume.transform = polygon_solid.transform
	outer_volume.material = polygon_solid.material
	combiner.add_child(outer_volume)
	
	# Adăugăm fiecare solid Tetris ca operație de subtracție
	for tetris_solid in tetris_solids:
		var inner_volume = CSGPolygon3D.new()
		inner_volume.polygon = tetris_solid.polygon
		inner_volume.depth = tetris_solid.depth + 0.01  # Putin mai înalt pentru tăiere completă
		inner_volume.operation = CSGShape3D.OPERATION_SUBTRACTION
		inner_volume.transform = tetris_solid.transform
		inner_volume.material = tetris_solid.material
		combiner.add_child(inner_volume)
	
	# Forțăm actualizarea CSG
	combiner._update_shape()
	
	return combiner

func create_extruded_polygon_with_tetris_cut(polygon_vertices: Array[Vector2], polygon_height: float, tetris_solids: Array[MeshInstance3D]) -> Node3D:
	return await create_box_with_rooms(polygon_vertices, polygon_height, tetris_solids)

# Helper functions pentru extragerea datelor din mesh-uri existente
func extract_vertices_from_mesh(mesh: ArrayMesh) -> Array[Vector2]:
	# Implementare simplificată - ar trebui adaptată la structura ta de mesh
	var vertices: Array[Vector2] = []
	if mesh and mesh.get_surface_count() > 0:
		var arrays = mesh.surface_get_arrays(0)
		var verts_3d = arrays[Mesh.ARRAY_VERTEX] as PackedVector3Array
		for i in range(verts_3d.size() / 2):  # Doar jumătate (bottom vertices)
			vertices.append(Vector2(verts_3d[i].x, verts_3d[i].y))
	return vertices

func extract_height_from_mesh(mesh: ArrayMesh) -> float:
	# Implementare simplificată
	if mesh and mesh.get_surface_count() > 0:
		var arrays = mesh.surface_get_arrays(0)
		var verts_3d = arrays[Mesh.ARRAY_VERTEX] as PackedVector3Array
		if verts_3d.size() > 0:
			var max_z = -INF
			var min_z = INF
			for vert in verts_3d:
				max_z = max(max_z, vert.z)
				min_z = min(min_z, vert.z)
			return max_z - min_z
	return 1.0

func create_csg_subtract(base_mesh: MeshInstance3D, cutter_vertices: Array[Vector2], cutter_height: float) -> CSGCombiner3D:
	var csg_combiner = CSGCombiner3D.new()
	csg_combiner.operation = CSGShape3D.OPERATION_SUBTRACTION

	var csg_mesh = CSGMesh3D.new()
	csg_mesh.mesh = base_mesh.mesh
	_ensure_no_parent(csg_mesh)
	csg_combiner.add_child(csg_mesh)

	var csg_polygon = CSGPolygon3D.new()
	csg_polygon.polygon = PackedVector2Array(cutter_vertices)
	csg_polygon.depth = cutter_height
	csg_polygon.operation = CSGShape3D.OPERATION_SUBTRACTION
	_ensure_no_parent(csg_polygon)
	csg_combiner.add_child(csg_polygon)

	await get_tree().process_frame
	csg_combiner._update_shape()

	return csg_combiner

func free_temporary_node(node: Node):
	if node and node.get_parent():
		node.queue_free()
