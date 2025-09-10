extends Node3D
class_name SolidFactory

# ========================================
# CONSTANTE PENTRU IERARHIA OPERAȚIILOR BOOLEENE
# ========================================
# Ordinea crescătoare determină prioritatea operațiilor CSG
# Valorile mai mari sunt procesate mai târziu și au prioritate mai mare

# Structuri de bază
const PRIORITY_OUTER_WALLS: float = 1.0      # Pereții exteriori (prima operație UNION)
const PRIORITY_ROOM_CUTTERS: float = 2.0     # Tăieturile pentru camere (SUBTRACTION)

# Deschideri în pereți  
const PRIORITY_WINDOW_CUTBOXES: float = 3.0  # Cutbox-urile pentru ferestre (SUBTRACTION)
const PRIORITY_DOOR_CUTBOXES: float = 3.1    # Cutbox-urile pentru uși (SUBTRACTION)

# Elemente vizuale (nu afectează structura)
const PRIORITY_WINDOW_VISUALS: float = 4.0   # Solidele vizuale ale ferestrelor (UNION)
const PRIORITY_DOOR_VISUALS: float = 4.1     # Solidele vizuale ale ușilor (UNION)
const PRIORITY_ROOM_VISUALS: float = 4.5     # Camerele transparente (vizualizare)

# Elemente suplimentare (extensibilitate viitoare)
const PRIORITY_STAIRS: float = 5.0           # Scări (UNION)
const PRIORITY_BALCONIES: float = 5.5        # Balcoane (UNION)
const PRIORITY_DECORATIVE: float = 6.0       # Elemente decorative (UNION)

# Structură pentru definirea operațiilor CSG cu prioritate
class CSGOperation:
	var node: CSGShape3D
	var priority: float
	var operation_type: CSGShape3D.Operation
	var name: String
	
	func _init(n: CSGShape3D, p: float, op: CSGShape3D.Operation, nm: String = ""):
		node = n
		priority = p
		operation_type = op
		name = nm

# Array global pentru colectarea tuturor operațiilor
var csg_operations: Array[CSGOperation] = []

# Funcție pentru adăugarea unei operații CSG cu prioritate
func add_csg_operation(node: CSGShape3D, priority: float, operation: CSGShape3D.Operation, name: String = ""):
	"""
	Adaugă o operație CSG în lista de priorități
	"""
	var csg_op = CSGOperation.new(node, priority, operation, name)
	csg_operations.append(csg_op)
	print("🔧 Added CSG operation: ", name, " (priority: ", priority, ")")

# Funcție pentru aplicarea operațiilor în ordinea priorităților
func apply_csg_operations_by_priority(container: CSGCombiner3D):
	"""
	Aplică toate operațiile CSG în ordinea priorităților
	"""
	# Sortează operațiile după prioritate (crescător)
	csg_operations.sort_custom(func(a, b): return a.priority < b.priority)
	
	print("📋 Applying ", csg_operations.size(), " CSG operations in priority order:")
	
	for i in range(csg_operations.size()):
		var op = csg_operations[i]
		
		# Setează tipul operației
		op.node.operation = op.operation_type
		
		# Asigură-te că node-ul nu are parent
		_ensure_no_parent(op.node)
		
		# Setează proprietăți importante pentru CSG
		if op.node is CSGShape3D:
			op.node.use_collision = false  # Evită conflicte de coliziune
			op.node.visible = true
		
		# Adaugă în container
		container.add_child(op.node)
		
		print("  ", i+1, ". ", op.name, " (", op.priority, ") - ", _operation_to_string(op.operation_type), 
			  " | Children: ", op.node.get_child_count(), " | Visible: ", op.node.visible)
	
	# Curăță lista pentru următoarea utilizare
	csg_operations.clear()
	
	# Force update pentru CSG cu debug
	print("🔧 Forcing CSG updates...")
	container._update_shape()
	
	# Debug: verifică starea finală
	print("📊 Final CSG container state:")
	print("  • Total children: ", container.get_child_count())
	print("  • Container operation: ", _operation_to_string(container.operation))
	print("  • Container visible: ", container.visible)
	print("  • Container use_collision: ", container.use_collision)
	
	print("✅ All CSG operations applied successfully")

# Helper pentru convertirea operațiilor la string
func _operation_to_string(operation: CSGShape3D.Operation) -> String:
	match operation:
		CSGShape3D.OPERATION_UNION: return "UNION"
		CSGShape3D.OPERATION_SUBTRACTION: return "SUBTRACTION"
		CSGShape3D.OPERATION_INTERSECTION: return "INTERSECTION"
		_: return "UNKNOWN"

# ========================================
# VARIABILE RUNTIME PENTRU PRIORITĂȚI (OPȚIONALE)
# ========================================
# Pentru configurări avansate, acestea pot înlocui constantele

var runtime_priority_outer_walls: float = PRIORITY_OUTER_WALLS
var runtime_priority_room_cutters: float = PRIORITY_ROOM_CUTTERS
var runtime_priority_window_cutboxes: float = PRIORITY_WINDOW_CUTBOXES
var runtime_priority_door_cutboxes: float = PRIORITY_DOOR_CUTBOXES
var runtime_priority_window_visuals: float = PRIORITY_WINDOW_VISUALS
var runtime_priority_door_visuals: float = PRIORITY_DOOR_VISUALS
var runtime_priority_room_visuals: float = PRIORITY_ROOM_VISUALS
var runtime_priority_stairs: float = PRIORITY_STAIRS
var runtime_priority_balconies: float = PRIORITY_BALCONIES
var runtime_priority_decorative: float = PRIORITY_DECORATIVE

var use_runtime_priorities: bool = false  # Flag pentru activarea priorităților personalizate

# ========================================
# FUNCȚII UTILITARE PENTRU CONFIGURAREA PRIORITĂȚILOR
# ========================================

# Setează prioritățile personalizate (pentru dezvoltare avansată)
func set_custom_priorities(priorities: Dictionary):
	"""
	Permite configurarea priorităților din exterior
	Exemplu: set_custom_priorities({"windows": 2.5, "doors": 2.6})
	"""
	use_runtime_priorities = true
	
	for key in priorities.keys():
		var value = priorities[key]
		match key:
			"outer_walls": runtime_priority_outer_walls = value
			"rooms": runtime_priority_room_cutters = value
			"windows": runtime_priority_window_cutboxes = value
			"doors": runtime_priority_door_cutboxes = value
			"window_visuals": runtime_priority_window_visuals = value
			"door_visuals": runtime_priority_door_visuals = value
			"room_visuals": runtime_priority_room_visuals = value
			"stairs": runtime_priority_stairs = value
			"balconies": runtime_priority_balconies = value
			"decorative": runtime_priority_decorative = value
		print("🔧 Custom priority set: ", key, " = ", value)
	
	print("✅ Runtime priorities activated")

# Helper pentru obținerea priorităților actuale (const sau runtime)
func get_priority_outer_walls() -> float:
	return runtime_priority_outer_walls if use_runtime_priorities else PRIORITY_OUTER_WALLS

func get_priority_room_cutters() -> float:
	return runtime_priority_room_cutters if use_runtime_priorities else PRIORITY_ROOM_CUTTERS

func get_priority_window_cutboxes() -> float:
	return runtime_priority_window_cutboxes if use_runtime_priorities else PRIORITY_WINDOW_CUTBOXES

func get_priority_door_cutboxes() -> float:
	return runtime_priority_door_cutboxes if use_runtime_priorities else PRIORITY_DOOR_CUTBOXES

func get_priority_window_visuals() -> float:
	return runtime_priority_window_visuals if use_runtime_priorities else PRIORITY_WINDOW_VISUALS

func get_priority_door_visuals() -> float:
	return runtime_priority_door_visuals if use_runtime_priorities else PRIORITY_DOOR_VISUALS

func get_priority_room_visuals() -> float:
	return runtime_priority_room_visuals if use_runtime_priorities else PRIORITY_ROOM_VISUALS

# Resetează la prioritățile default
func reset_to_default_priorities():
	"""
	Resetează la prioritățile constante default
	"""
	use_runtime_priorities = false
	print("✅ Priorities reset to default constants")

# Obține informații despre prioritățile curente
func get_priority_info() -> Dictionary:
	"""
	Returnează un dicționar cu toate prioritățile curente
	"""
	return {
		"outer_walls": PRIORITY_OUTER_WALLS,
		"room_cutters": PRIORITY_ROOM_CUTTERS,
		"window_cutboxes": PRIORITY_WINDOW_CUTBOXES,
		"door_cutboxes": PRIORITY_DOOR_CUTBOXES,
		"window_visuals": PRIORITY_WINDOW_VISUALS,
		"door_visuals": PRIORITY_DOOR_VISUALS,
		"room_visuals": PRIORITY_ROOM_VISUALS,
		"stairs": PRIORITY_STAIRS,
		"balconies": PRIORITY_BALCONIES,
		"decorative": PRIORITY_DECORATIVE
	}

# Afișează informații despre ordinea operațiilor
func print_priority_order():
	"""
	Afișează ordinea curentă a priorităților pentru debugging
	"""
	var priorities = get_priority_info()
	var sorted_keys = priorities.keys()
	sorted_keys.sort_custom(func(a, b): return priorities[a] < priorities[b])
	
	print("📋 Current CSG Operation Priority Order:")
	for i in range(sorted_keys.size()):
		var key = sorted_keys[i]
		print("  ", i+1, ". ", key, " (", priorities[key], ")")
		
	print("💡 Lower numbers execute first, higher numbers have priority in conflicts")

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
			# Camerele - transparente cu albastru cian pentru vizualizare
			material.albedo_color = Color(0.0, 1.0, 1.0, 0.3)  # Albastru cian transparent
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

func _ensure_no_parent(node: Node):
	if node.get_parent():
		node.get_parent().remove_child(node)

# Funcție de test pentru CSG simplu
func create_simple_csg_test() -> CSGCombiner3D:
	"""
	Creează un test simplu CSG pentru a verifica dacă boolean operations funcționează
	"""
	print("🧪 Creating simple CSG test...")
	
	var test_combiner = CSGCombiner3D.new()
	test_combiner.operation = CSGShape3D.OPERATION_UNION
	test_combiner.name = "CSGTest"
	
	# Creează un cub de bază
	var base_box = CSGBox3D.new()
	base_box.size = Vector3(100, 100, 50)
	base_box.operation = CSGShape3D.OPERATION_UNION
	base_box.material_override = _create_material_for_type("outer_wall")
	base_box.name = "BaseBox"
	
	# Creează un cub pentru tăiere
	var cutter_box = CSGBox3D.new()
	cutter_box.size = Vector3(50, 50, 60)
	cutter_box.position = Vector3(0, 0, 0)
	cutter_box.operation = CSGShape3D.OPERATION_SUBTRACTION
	cutter_box.name = "CutterBox"
	
	test_combiner.add_child(base_box)
	test_combiner.add_child(cutter_box)
	
	test_combiner._update_shape()
	
	print("✅ Simple CSG test created: Base box - Cutter box")
	return test_combiner

# ========================================
# LOGICA 3D PENTRU FERESTRE ȘI UȘI
# ========================================

# Creează cutbox pentru fereastră din outline 2D + height + sill
func create_window_cutbox(tetris_shape: TetrisShape2D) -> CSGPolygon3D:
	"""
	Creează cutbox-ul pentru fereastră conform logicii:
	- Outline 2D (width x length) = vederea din plan
	- Height = înălțimea extruziunii pe Z
	- Sill = translația pe Z (ridicare/coborâre)
	"""
	if not tetris_shape.has_window or tetris_shape.window_height <= 0:
		return null
	
	# Calculează poziția și dimensiunile outline-ului 2D
	var window_outline = _calculate_window_outline_2d(tetris_shape)
	if window_outline.size() < 4:
		return null
	
	# Creează cutbox-ul CSG
	var cutbox = CSGPolygon3D.new()
	cutbox.polygon = PackedVector2Array(window_outline)
	cutbox.depth = tetris_shape.window_height
	cutbox.operation = CSGShape3D.OPERATION_SUBTRACTION
	
	# Poziționarea: outline 2D + translația Z pentru sill
	var cutbox_position = _calculate_window_position_3d(tetris_shape)
	cutbox.position = cutbox_position
	
	# Material invizibil pentru tăiere
	cutbox.material_override = null
	cutbox.visible = false
	
	print("🔲 Created window cutbox at: ", cutbox_position, " size: ", tetris_shape.window_width, "x", tetris_shape.window_length, "x", tetris_shape.window_height, " (shape: ", tetris_shape.room_name, ")")
	print("🔲 Window cutbox HEIGHT (depth): ", tetris_shape.window_height)
	
	return cutbox

# Creează cutbox pentru ușă din outline 2D + height + sill
func create_door_cutbox(tetris_shape: TetrisShape2D) -> CSGPolygon3D:
	"""
	Creează cutbox-ul pentru ușă conform logicii:
	- Outline 2D (width x length) = vederea din plan
	- Height = înălțimea extruziunii pe Z
	- Sill = translația pe Z (ridicare/coborâre)
	"""
	if not tetris_shape.has_door or tetris_shape.door_height <= 0:
		return null
	
	# Calculează poziția și dimensiunile outline-ului 2D
	var door_outline = _calculate_door_outline_2d(tetris_shape)
	if door_outline.size() < 4:
		return null
	
	# Creează cutbox-ul CSG
	var cutbox = CSGPolygon3D.new()
	cutbox.polygon = PackedVector2Array(door_outline)
	cutbox.depth = tetris_shape.door_height
	cutbox.operation = CSGShape3D.OPERATION_SUBTRACTION
	
	# Poziționarea: outline 2D + translația Z pentru sill
	var cutbox_position = _calculate_door_position_3d(tetris_shape)
	cutbox.position = cutbox_position
	
	# Material invizibil pentru tăiere
	cutbox.material_override = null
	cutbox.visible = false
	
	print("🔲 Created door cutbox at: ", cutbox_position, " size: ", tetris_shape.door_width, "x", tetris_shape.door_length, "x", tetris_shape.door_height, " (shape: ", tetris_shape.room_name, ")")
	print("🔲 Door cutbox HEIGHT (depth): ", tetris_shape.door_height)
	
	return cutbox

# Calculează outline-ul 2D al ferestrei în coordonatele locale ale shape-ului
func _calculate_window_outline_2d(tetris_shape: TetrisShape2D) -> Array[Vector2]:
	"""
	Calculează rectangulul outline 2D al ferestrei în coordonate globale bazat pe:
	- window_side (orientarea: 0°, 90°, 180°, 270°)
	- window_offset (deplasarea pe latura selectată)
	- window_width, window_length (dimensiunile cutbox-ului)
	- pozițiile shape-ului în coordonatele globale
	"""
	var outline: Array[Vector2] = []
	
	# Dimensiuni cutbox (inversate: width devine length și vice versa)
	var w = tetris_shape.window_width
	var l = tetris_shape.window_length
	
	# Calculează centrul și orientarea pe latura specificată (în coordonate locale)
	var center_pos = _get_window_center_on_side(tetris_shape)
	var angle_rad = deg_to_rad(tetris_shape.window_side)
	
	# Creează rectangle rotit și poziționat
	var half_w = w * 0.5
	var half_l = l * 0.5
	
	# Punctele locale (înainte de rotație)
	var local_points = [
		Vector2(-half_w, -half_l),
		Vector2(half_w, -half_l),
		Vector2(half_w, half_l),
		Vector2(-half_w, half_l)
	]
	
	# Aplică rotația și translația + poziția globală a shape-ului
	for point in local_points:
		var rotated = Vector2(
			point.x * cos(angle_rad) - point.y * sin(angle_rad),
			point.x * sin(angle_rad) + point.y * cos(angle_rad)
		)
		# Adaugă poziția shape-ului pentru coordonate globale
		var global_point = center_pos + rotated + tetris_shape.position
		outline.append(global_point)
	
	print("🔧 Window outline global coords for ", tetris_shape.room_name, ": ", outline)
	return outline

# Calculează outline-ul 2D al ușii în coordonate globale
func _calculate_door_outline_2d(tetris_shape: TetrisShape2D) -> Array[Vector2]:
	"""
	Calculează rectangulul outline 2D al ușii în coordonate globale bazat pe:
	- door_side (orientarea: 0°, 90°, 180°, 270°)
	- door_offset (deplasarea pe latura selectată)
	- door_width, door_length (dimensiunile cutbox-ului)
	- pozițiile shape-ului în coordonatele globale
	"""
	var outline: Array[Vector2] = []
	
	# Dimensiuni cutbox (inversate: width devine length și vice versa)
	var w = tetris_shape.door_width
	var l = tetris_shape.door_length
	
	# Calculează centrul și orientarea pe latura specificată (în coordonate locale)
	var center_pos = _get_door_center_on_side(tetris_shape)
	var angle_rad = deg_to_rad(tetris_shape.door_side)
	
	# Creează rectangle rotit și poziționat
	var half_w = w * 0.5
	var half_l = l * 0.5
	
	# Punctele locale (înainte de rotație)
	var local_points = [
		Vector2(-half_w, -half_l),
		Vector2(half_w, -half_l),
		Vector2(half_w, half_l),
		Vector2(-half_w, half_l)
	]
	
	# Aplică rotația și translația + poziția globală a shape-ului
	for point in local_points:
		var rotated = Vector2(
			point.x * cos(angle_rad) - point.y * sin(angle_rad),
			point.x * sin(angle_rad) + point.y * cos(angle_rad)
		)
		# Adaugă poziția shape-ului pentru coordonate globale
		var global_point = center_pos + rotated + tetris_shape.position
		outline.append(global_point)
	
	print("🔧 Door outline global coords for ", tetris_shape.room_name, ": ", outline)
	return outline

# Helper pentru calcularea bounds-urilor shape-ului
func _get_shape_bounds(tetris_shape: TetrisShape2D) -> Rect2:
	"""
	Calculează bounding box-ul shape-ului din vertices
	"""
	if tetris_shape.base_vertices.size() == 0:
		return Rect2()
	
	var min_pos = Vector2(INF, INF)
	var max_pos = Vector2(-INF, -INF)
	
	for vertex in tetris_shape.base_vertices:
		min_pos.x = min(min_pos.x, vertex.x)
		min_pos.y = min(min_pos.y, vertex.y)
		max_pos.x = max(max_pos.x, vertex.x)
		max_pos.y = max(max_pos.y, vertex.y)
	
	return Rect2(min_pos, max_pos - min_pos)

# Calculează poziția centrului ferestrei pe latura specificată
func _get_window_center_on_side(tetris_shape: TetrisShape2D) -> Vector2:
	"""
	Calculează poziția centrului ferestrei pe latura shape-ului specificată
	FOLOSIND EXACT ACEEAȘI LOGICĂ CA WindowDoorController
	"""
	if tetris_shape.base_vertices.size() != 4:
		return Vector2.ZERO
	
	# Folosește aceleași vertices ca în 2D
	var rect_vertices = tetris_shape.base_vertices
	var side_index = _get_side_index_from_angle(tetris_shape.window_side)
	if side_index < 0:
		return Vector2.ZERO
	
	# Obține punctele laturii (exact ca în WindowDoorController)
	var start_point = rect_vertices[side_index]
	var end_point = rect_vertices[(side_index + 1) % 4]
	
	# Calculează centrul laturii
	var side_center = (start_point + end_point) * 0.5
	
	# Calculează direcția laturii 
	var side_direction = (end_point - start_point).normalized()
	
	# Aplică offset lateral pe direcția laturii (ca în 2D)
	var element_center = side_center + side_direction * tetris_shape.window_offset
	
	return element_center

# Calculează poziția centrului ușii pe latura specificată
func _get_door_center_on_side(tetris_shape: TetrisShape2D) -> Vector2:
	"""
	Calculează poziția centrului ușii pe latura shape-ului specificată
	FOLOSIND EXACT ACEEAȘI LOGICĂ CA WindowDoorController
	"""
	if tetris_shape.base_vertices.size() != 4:
		return Vector2.ZERO
	
	# Folosește aceleași vertices ca în 2D
	var rect_vertices = tetris_shape.base_vertices
	var side_index = _get_side_index_from_angle(tetris_shape.door_side)
	if side_index < 0:
		return Vector2.ZERO
	
	# Obține punctele laturii (exact ca în WindowDoorController)
	var start_point = rect_vertices[side_index]
	var end_point = rect_vertices[(side_index + 1) % 4]
	
	# Calculează centrul laturii
	var side_center = (start_point + end_point) * 0.5
	
	# Calculează direcția laturii 
	var side_direction = (end_point - start_point).normalized()
	
	# Aplică offset lateral pe direcția laturii (ca în 2D)
	var element_center = side_center + side_direction * tetris_shape.door_offset
	
	return element_center

# Helper function pentru maparea unghiurilor la indicii de laturi
func _get_side_index_from_angle(angle: int) -> int:
	"""
	Mapează unghiul la indicele laturii (IDENTIC cu WindowDoorController)
	0° = latura de jos (0->1), 90° = latura din dreapta (1->2), 
	180° = latura de sus (2->3), 270° = latura din stânga (3->0)
	"""
	match angle:
		0: return 0    # Jos
		90: return 1   # Dreapta  
		180: return 2  # Sus
		270: return 3  # Stânga
		_: return -1

# Calculează poziția 3D a cutbox-ului ferestrei (incluzând sill)
func _calculate_window_position_3d(tetris_shape: TetrisShape2D) -> Vector3:
	"""
	Calculează poziția 3D finală a cutbox-ului ferestrei:
	- X, Y din outline 2D + poziția shape-ului
	- Z din sill (translația verticală)
	"""
	var pos_2d = tetris_shape.position
	var z_offset = tetris_shape.window_sill + (tetris_shape.window_height * 0.5)
	
	return Vector3(pos_2d.x, pos_2d.y, z_offset)

# Calculează poziția 3D a cutbox-ului ușii (incluzând sill)
func _calculate_door_position_3d(tetris_shape: TetrisShape2D) -> Vector3:
	"""
	Calculează poziția 3D finală a cutbox-ului ușii:
	- X, Y din outline 2D + poziția shape-ului
	- Z din sill (translația verticală)
	"""
	var pos_2d = tetris_shape.position
	var z_offset = tetris_shape.door_sill + (tetris_shape.door_height * 0.5)
	
	return Vector3(pos_2d.x, pos_2d.y, z_offset)

# Aplică toate cutbox-urile (ferestre + uși) pe un CSG combiner
func apply_windows_doors_cutboxes(csg_combiner: CSGCombiner3D, tetris_shapes: Array) -> void:
	"""
	Aplică toate cutbox-urile de ferestre și uși pe un CSG combiner existent
	pentru a tăia pereții cu golurile necesare
	"""
	for tetris_shape in tetris_shapes:
		if tetris_shape is TetrisShape2D:
			# Adaugă cutbox fereastră dacă există
			var window_cutbox = create_window_cutbox(tetris_shape)
			if window_cutbox:
				_ensure_no_parent(window_cutbox)
				csg_combiner.add_child(window_cutbox)
				print("Applied window cutbox for shape: ", tetris_shape.room_name)
			
			# Adaugă cutbox ușă dacă există
			var door_cutbox = create_door_cutbox(tetris_shape)
			if door_cutbox:
				_ensure_no_parent(door_cutbox)
				csg_combiner.add_child(door_cutbox)
				print("Applied door cutbox for shape: ", tetris_shape.room_name)

# Versiune cu priorități pentru cutbox-urile de ferestre și uși
func add_windows_doors_cutboxes_with_priority(tetris_shapes: Array) -> void:
	"""
	Adaugă cutbox-urile pentru ferestre și uși în sistemul de priorități
	"""
	var window_count = 0
	var door_count = 0
	
	for tetris_shape in tetris_shapes:
		if tetris_shape is TetrisShape2D:
			# Solidul fereastră ca CUTTER cu prioritate 3.0
			if tetris_shape.has_window and tetris_shape.window_height > 0:
				var window_solid = create_window_solid(tetris_shape)
				if window_solid:
					# SETĂM ca SUBTRACTION pentru tăiere
					window_solid.operation = CSGShape3D.OPERATION_SUBTRACTION
					window_solid.name = "WindowCutter_" + (tetris_shape.room_name if tetris_shape.room_name else str(window_count))
					add_csg_operation(window_solid, get_priority_window_cutboxes(), CSGShape3D.OPERATION_SUBTRACTION, 
									"Window Cutter: " + (tetris_shape.room_name if tetris_shape.room_name else str(window_count)))
					window_count += 1
			
			# Solidul ușă ca CUTTER cu prioritate 3.1
			if tetris_shape.has_door and tetris_shape.door_height > 0:
				var door_solid = create_door_solid(tetris_shape)
				if door_solid:
					# SETĂM ca SUBTRACTION pentru tăiere
					door_solid.operation = CSGShape3D.OPERATION_SUBTRACTION
					door_solid.name = "DoorCutter_" + (tetris_shape.room_name if tetris_shape.room_name else str(door_count))
					add_csg_operation(door_solid, get_priority_door_cutboxes(), CSGShape3D.OPERATION_SUBTRACTION, 
									"Door Cutter: " + (tetris_shape.room_name if tetris_shape.room_name else str(door_count)))
					door_count += 1
	
	print("📋 Prepared ", window_count, " window cutters and ", door_count, " door cutters for priority processing")

# ========================================
# SOLIDE VIZUALE PENTRU FERESTRE ȘI UȘI
# ========================================

# Creează solidul vizual al unei ferestre folosind exact outline-ul 2D din top view
func create_window_solid(tetris_shape: TetrisShape2D) -> CSGPolygon3D:
	"""
	Creează solidul vizual al ferestrei folosind exact outline-ul 2D din top view
	și îl extrudează pe Z conform parametrilor
	"""
	if not tetris_shape.has_window or tetris_shape.window_height <= 0:
		return null
	
	# Calculează outline-ul 2D EXACT al ferestrei din top view
	var window_outline = _calculate_window_outline_2d(tetris_shape)
	if window_outline.size() < 4:
		print("❌ Window outline invalid for: ", tetris_shape.room_name)
		return null
	
	print("🔧 Creating window solid with outline: ", window_outline.size(), " points")
	print("🔧 Window dimensions: width=", tetris_shape.window_width, " length=", tetris_shape.window_length, " HEIGHT=", tetris_shape.window_height, " sill=", tetris_shape.window_sill)
	for i in range(window_outline.size()):
		print("  Point ", i, ": ", window_outline[i])
	
	# Creează solidul ferestrei (pentru partea vizuală = UNION, pentru tăiere se setează separat)
	var window_solid = CSGPolygon3D.new()
	window_solid.polygon = PackedVector2Array(window_outline)
	window_solid.depth = tetris_shape.window_height  # Înălțimea exactă
	window_solid.operation = CSGShape3D.OPERATION_UNION  # UNION pentru vizual (operația finală se setează la adăugarea în CSG)
	
	# Poziționare 3D: outline-ul 2D e deja în coordonate globale,
	# doar setăm translația pe Z conform sill-ului
	var z_position = tetris_shape.window_sill + (tetris_shape.window_height * 0.5)
	window_solid.position = Vector3(0, 0, z_position)
	
	# Material transparent pentru fereastră (sticlă) - albastru cian cu 50% transparență
	var glass_material = StandardMaterial3D.new()
	glass_material.albedo_color = Color(0.0, 1.0, 1.0, 0.5)  # Albastru cian cu 50% transparență
	glass_material.flags_transparent = true
	glass_material.blend_mode = BaseMaterial3D.BLEND_MODE_MIX
	glass_material.metallic = 0.1
	glass_material.roughness = 0.0  # Foarte lucios ca sticla
	glass_material.rim = 1.0
	glass_material.rim_tint = 0.5
	window_solid.material_override = glass_material
	
	window_solid.name = "Window_" + (tetris_shape.room_name if tetris_shape.room_name else "Unknown")
	
	print("✅ Created window solid for: ", tetris_shape.room_name, 
		  " at position: ", window_solid.position, 
		  " with height: ", tetris_shape.window_height,
		  " sill: ", tetris_shape.window_sill)
	
	return window_solid

# Creează solidul vizual al unei uși folosind exact outline-ul 2D din top view
func create_door_solid(tetris_shape: TetrisShape2D) -> CSGPolygon3D:
	"""
	Creează solidul vizual al ușii folosind exact outline-ul 2D din top view
	și îl extrudează pe Z conform parametrilor
	"""
	if not tetris_shape.has_door or tetris_shape.door_height <= 0:
		return null
	
	# Calculează outline-ul 2D EXACT al ușii din top view
	var door_outline = _calculate_door_outline_2d(tetris_shape)
	if door_outline.size() < 4:
		print("❌ Door outline invalid for: ", tetris_shape.room_name)
		return null
	
	print("🔧 Creating door solid with outline: ", door_outline.size(), " points")
	print("🔧 Door dimensions: width=", tetris_shape.door_width, " length=", tetris_shape.door_length, " HEIGHT=", tetris_shape.door_height, " sill=", tetris_shape.door_sill)
	for i in range(door_outline.size()):
		print("  Point ", i, ": ", door_outline[i])
	
	# Creează solidul ușii (pentru partea vizuală = UNION, pentru tăiere se setează separat)
	var door_solid = CSGPolygon3D.new()
	door_solid.polygon = PackedVector2Array(door_outline)
	door_solid.depth = tetris_shape.door_height  # Înălțimea exactă
	door_solid.operation = CSGShape3D.OPERATION_UNION  # UNION pentru vizual (operația finală se setează la adăugarea în CSG)
	
	# Poziționare 3D: outline-ul 2D e deja în coordonate globale,
	# doar setăm translația pe Z conform sill-ului
	var z_position = tetris_shape.door_sill + (tetris_shape.door_height * 0.5)
	door_solid.position = Vector3(0, 0, z_position)
	
	# Material pentru ușă - albastru cian cu 50% transparență
	var door_material = StandardMaterial3D.new()
	door_material.albedo_color = Color(0.0, 1.0, 1.0, 0.5)  # Albastru cian cu 50% transparență
	door_material.flags_transparent = true
	door_material.blend_mode = BaseMaterial3D.BLEND_MODE_MIX
	door_material.metallic = 0.2
	door_material.roughness = 0.3  # Mai puțin rugos pentru aspect modern
	door_solid.material_override = door_material
	
	door_solid.name = "Door_" + (tetris_shape.room_name if tetris_shape.room_name else "Unknown")
	
	print("✅ Created door solid for: ", tetris_shape.room_name, 
		  " at position: ", door_solid.position, 
		  " with height: ", tetris_shape.door_height,
		  " sill: ", tetris_shape.door_sill)
	
	return door_solid

# Creează toate solidele vizuale pentru ferestre și uși
func create_windows_doors_solids(tetris_shapes: Array) -> Node3D:
	"""
	Creează un container cu toate solidele vizuale ale ferestrelor și ușilor
	"""
	var container = Node3D.new()
	container.name = "WindowsDoorsContainer"
	
	var window_count = 0
	var door_count = 0
	
	for tetris_shape in tetris_shapes:
		if tetris_shape is TetrisShape2D:
			# Adaugă solidul ferestrei dacă există
			var window_solid = create_window_solid(tetris_shape)
			if window_solid:
				_ensure_no_parent(window_solid)
				container.add_child(window_solid)
				window_count += 1
			
			# Adaugă solidul ușii dacă există
			var door_solid = create_door_solid(tetris_shape)
			if door_solid:
				_ensure_no_parent(door_solid)
				container.add_child(door_solid)
				door_count += 1
	
	print("✅ Created ", window_count, " window solids and ", door_count, " door solids")
	
	return container

# Versiune cu sistemul de priorități pentru solidele vizuale
func create_windows_doors_solids_with_priority(tetris_shapes: Array) -> Node3D:
	"""
	Creează solidele vizuale folosind sistemul de priorități CSG
	"""
	var container = CSGCombiner3D.new()
	container.name = "WindowsDoorsVisualsContainer"
	container.operation = CSGShape3D.OPERATION_UNION
	
	print("🎨 Creating visual solids with priority system...")
	
	# Curăță lista de operații
	csg_operations.clear()
	
	var window_count = 0
	var door_count = 0
	
	print("🔍 Analyzing ", tetris_shapes.size(), " shapes for windows and doors...")
	
	for tetris_shape in tetris_shapes:
		if tetris_shape is TetrisShape2D:
			print("  Shape: ", tetris_shape.room_name, 
				  " | Has window: ", tetris_shape.has_window, 
				  " (height: ", tetris_shape.window_height, ")",
				  " | Has door: ", tetris_shape.has_door,
				  " (height: ", tetris_shape.door_height, ")")
			
			# Solidul vizual al ferestrei (prioritate 4.0)
			if tetris_shape.has_window and tetris_shape.window_height > 0:
				var window_solid = create_window_solid(tetris_shape)
				if window_solid:
					window_solid.name = "WindowVisual_" + (tetris_shape.room_name if tetris_shape.room_name else str(window_count))
					add_csg_operation(window_solid, get_priority_window_visuals(), CSGShape3D.OPERATION_UNION, 
									"Window Visual: " + (tetris_shape.room_name if tetris_shape.room_name else str(window_count)))
					window_count += 1
			
			# Solidul vizual al ușii (prioritate 4.1)
			if tetris_shape.has_door and tetris_shape.door_height > 0:
				var door_solid = create_door_solid(tetris_shape)
				if door_solid:
					door_solid.name = "DoorVisual_" + (tetris_shape.room_name if tetris_shape.room_name else str(door_count))
					add_csg_operation(door_solid, get_priority_door_visuals(), CSGShape3D.OPERATION_UNION, 
									"Door Visual: " + (tetris_shape.room_name if tetris_shape.room_name else str(door_count)))
					door_count += 1
	
	# Aplică operațiile în ordinea priorităților
	if csg_operations.size() > 0:
		apply_csg_operations_by_priority(container)
		print("✅ Created ", window_count, " window visuals and ", door_count, " door visuals with priority system")
		return container
	else:
		print("ℹ️ No visual elements to create")
		container.queue_free()
		return null

# ========================================
# FUNCȚIILE PRINCIPALE ACTUALIZATE
# ========================================

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
	
	# 2. Adăugăm fiecare cameră ca operație de subtracție - folosind offset_vertices pentru interior corect
	for tetris_shape in tetris_shapes:
		if tetris_shape is TetrisShape2D:
			# Folosește offset_vertices pentru camerele interioare, nu base_vertices
			var interior_vertices = tetris_shape.offset_vertices if tetris_shape.offset_vertices.size() > 0 else tetris_shape.base_vertices
			var using_offset = tetris_shape.offset_vertices.size() > 0
			print("Legacy room cutter for '", tetris_shape.room_name, "': using ", ("offset_vertices" if using_offset else "base_vertices"), " (", interior_vertices.size(), " vertices)")
			var room = create_extruded_shape(interior_vertices, outer_height + 0.01, "camera_volume")
			room.operation = CSGShape3D.OPERATION_SUBTRACTION
			room.transform = Transform3D(Basis(), Vector3(tetris_shape.position.x, tetris_shape.position.y, outer_height/2))
			combiner.add_child(room)
			print("Added room cutter at: ", room.transform.origin)
	
	# 3. Aplică cutbox-urile pentru ferestre și uși
	print("Applying windows and doors cutboxes...")
	apply_windows_doors_cutboxes(combiner, tetris_shapes)
	
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

# Versiune cu sistem de priorități pentru operațiile CSG
func create_walls_with_windows_doors(outer_vertices: Array[Vector2], height: float, tetris_shapes: Array) -> CSGCombiner3D:
	"""
	Creează pereții cu găuri pentru camere, ferestre și uși folosind sistemul de priorități
	"""
	var csg_combiner = CSGCombiner3D.new()
	csg_combiner.operation = CSGShape3D.OPERATION_UNION  # UNION pentru a combina toate operațiile
	csg_combiner.use_collision = true
	csg_combiner.calculate_tangents = true  # Pentru materiale corecte
	csg_combiner.name = "WallsWithWindowsDoors"
	
	print("🏗️ Building walls with priority-based CSG operations...")
	
	# Curăță lista de operații pentru această construcție
	csg_operations.clear()
	
	# 1. PRIORITATE 1.0: Pereții exteriori (baza structurală)
	var wall_material = StandardMaterial3D.new()
	wall_material.albedo_color = Color(0.8, 0.7, 0.6, 1.0)
	wall_material.metallic = 0.1
	wall_material.roughness = 0.7
	wall_material.flags_transparent = false
	
	var outer_walls = CSGPolygon3D.new()
	outer_walls.polygon = PackedVector2Array(outer_vertices)
	outer_walls.depth = height
	outer_walls.material_override = wall_material
	outer_walls.position = Vector3(0, 0, height/2)
	outer_walls.name = "OuterWalls"
	
	add_csg_operation(outer_walls, get_priority_outer_walls(), CSGShape3D.OPERATION_UNION, "Outer Walls")
	
	# 2. PRIORITATE 2.0: Tăieturile pentru camere - folosind offset_vertices pentru interior corect
	var room_count = 0
	for tetris_shape in tetris_shapes:
		if tetris_shape is TetrisShape2D:
			# Folosește offset_vertices pentru camerele interioare, nu base_vertices
			var interior_vertices = tetris_shape.offset_vertices if tetris_shape.offset_vertices.size() > 0 else tetris_shape.base_vertices
			var using_offset = tetris_shape.offset_vertices.size() > 0
			print("Room cutter for '", tetris_shape.room_name, "': using ", ("offset_vertices" if using_offset else "base_vertices"), " (", interior_vertices.size(), " vertices)")
			var room_cutter = create_extruded_shape(interior_vertices, height + 0.01, "camera_volume")
			room_cutter.position = Vector3(tetris_shape.position.x, tetris_shape.position.y, height/2)
			room_cutter.visible = false
			room_cutter.name = "RoomCutter_" + (tetris_shape.room_name if tetris_shape.room_name else str(room_count))
			
			add_csg_operation(room_cutter, get_priority_room_cutters(), CSGShape3D.OPERATION_SUBTRACTION, 
							"Room Cutter: " + (tetris_shape.room_name if tetris_shape.room_name else str(room_count)))
			room_count += 1
	
	# 3. PRIORITATE 3.0-3.1: Cutbox-urile pentru ferestre și uși
	add_windows_doors_cutboxes_with_priority(tetris_shapes)
	
	# 4. Aplică toate operațiile în ordinea priorităților
	apply_csg_operations_by_priority(csg_combiner)
	
	# 5. Force multiple CSG updates pentru a asigura procesarea corectă
	csg_combiner._update_shape()
	
	# 6. Setează vizibilitatea și proprietățile finale
	csg_combiner.visible = true
	
	print("🏗️ Final CSG combiner created with ", csg_combiner.get_child_count(), " child operations")
	
	return csg_combiner

# Creează camerele transparente pentru vizualizare
func create_transparent_rooms(room_solids: Array[MeshInstance3D]) -> Node3D:
	var rooms_container = Node3D.new()
	
	# Material transparent pentru camere - albastru cian cu transparență
	var room_material = StandardMaterial3D.new()
	room_material.albedo_color = Color(0.0, 1.0, 1.0, 0.3)  # Albastru cian cu 30% transparență (mai subtil)
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
	return create_box_with_rooms(polygon_vertices, polygon_height, tetris_solids)

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

	csg_combiner._update_shape()

	return csg_combiner

func free_temporary_node(node: Node):
	if node and node.get_parent():
		node.queue_free()

# ========================================
# FUNCȚIE DEMO PENTRU TESTARE COMPLETĂ
# ========================================

func create_complete_building_with_windows_doors(outer_vertices: Array[Vector2], outer_height: float, tetris_shapes: Array) -> Node3D:
	"""
	Funcția principală care creează o clădire completă cu sistem de priorități CSG:
	1. Pereții exteriori (prioritate 1.0)
	2. Camerele tăiate din pereți (prioritate 2.0)
	3. Ferestrele și ușile tăiate din pereți (prioritate 3.0-3.1)
	4. Solidele vizuale pentru ferestre și uși (prioritate 4.0-4.1)
	5. Camerele transparente pentru vizualizare (prioritate 4.5)
	"""
	var building_container = Node3D.new()
	building_container.name = "CompleteBuilding"
	
	print("🏗️ Creating complete building with priority-based CSG system")
	print("🏗️ Building parameters: ", tetris_shapes.size(), " rooms, height: ", outer_height, "m")
	
	# 1. STRUCTURA PRINCIPALĂ: Pereți + tăieturi (prioritate 1.0-3.1)
	var main_structure = create_walls_with_windows_doors(outer_vertices, outer_height, tetris_shapes)
	main_structure.name = "MainStructure"
	building_container.add_child(main_structure)
	print("✅ Main structure created with priority-based CSG operations")
	
	# 2. SOLIDELE VIZUALE: Ferestre și uși cu priorități (prioritate 4.0-4.1)
	var windows_doors_visuals = create_windows_doors_solids_with_priority(tetris_shapes)
	if windows_doors_visuals:
		windows_doors_visuals.name = "WindowsDoorsVisuals"
		building_container.add_child(windows_doors_visuals)
		print("✅ Visual windows and doors added with priority system")

	# 3. VIZUALIZARE: Camere transparente (prioritate 4.5)
	var show_transparent_rooms = true  # Poate fi controlat din exterior
	if show_transparent_rooms:
		var transparent_rooms = create_transparent_rooms_from_shapes(tetris_shapes, outer_height)
		if transparent_rooms:
			transparent_rooms.name = "TransparentRooms"
			building_container.add_child(transparent_rooms)
			print("✅ Transparent room visualization added")
	
	# 4. Statistici finale
	var total_windows = 0
	var total_doors = 0
	for shape in tetris_shapes:
		if shape is TetrisShape2D:
			if shape.has_window and shape.window_height > 0:
				total_windows += 1
			if shape.has_door and shape.door_height > 0:
				total_doors += 1
	
	print("📊 Building statistics:")
	print("   • Rooms: ", tetris_shapes.size())
	print("   • Windows: ", total_windows)
	print("   • Doors: ", total_doors)
	print("🎉 Complete building ready!")
	
	return building_container

# Helper pentru camere transparente din TetrisShape2D
func create_transparent_rooms_from_shapes(tetris_shapes: Array, height: float) -> Node3D:
	"""
	Creează camerele transparente din TetrisShape2D pentru vizualizare
	"""
	var rooms_container = Node3D.new()
	
	# Material transparent pentru camere - albastru cian cu transparență
	var room_material = StandardMaterial3D.new()
	room_material.albedo_color = Color(0.0, 1.0, 1.0, 0.2)  # Albastru cian cu 20% transparență (foarte subtil)
	room_material.flags_transparent = true
	room_material.blend_mode = BaseMaterial3D.BLEND_MODE_MIX
	room_material.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_OPAQUE_ONLY
	room_material.metallic = 0.0
	room_material.roughness = 0.9
	room_material.cull_mode = BaseMaterial3D.CULL_DISABLED  # Vizibil din ambele părți
	
	# Adaugă fiecare cameră ca CSG transparent - folosind offset_vertices pentru interior corect
	for i in range(tetris_shapes.size()):
		var tetris_shape = tetris_shapes[i]
		if tetris_shape is TetrisShape2D:
			# Folosește offset_vertices pentru camerele interioare, nu base_vertices
			var interior_vertices = tetris_shape.offset_vertices if tetris_shape.offset_vertices.size() > 0 else tetris_shape.base_vertices
			var using_offset = tetris_shape.offset_vertices.size() > 0
			print("Transparent room for '", tetris_shape.room_name, "': using ", ("offset_vertices" if using_offset else "base_vertices"), " (", interior_vertices.size(), " vertices)")
			var transparent_room = create_extruded_shape(interior_vertices, height * 0.95, "camera_volume")
			transparent_room.position = Vector3(tetris_shape.position.x, tetris_shape.position.y, height/2)
			transparent_room.material_override = room_material
			transparent_room.name = "Room_" + (tetris_shape.room_name if tetris_shape.room_name else str(i))
			
			rooms_container.add_child(transparent_room)
			print("Added transparent room: ", transparent_room.name, " at: ", transparent_room.position)
	
	return rooms_container
