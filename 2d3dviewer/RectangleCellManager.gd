# RectangleCellManager.gd
# Manager pentru gestionarea RectangleCell-urilor
class_name RectangleCellManager

extends RefCounted

# Colecția de cell-uri
var cells: Array[RectangleCell] = []
var selected_cell: RectangleCell = null

# Proprietăți pentru noul cell (configurabile din UI)
var default_width: float = 5.0
var default_height: float = 5.0
var default_offset: float = 0.0
var default_name: String = "Cell"
var default_type: String = "Standard"
var next_index: int = 1
# Extended defaults
var default_height_3d: float = 0.0
var default_sill: float = 0.0
var default_translation_x: float = 0.0
var default_translation_y: float = 0.0
var default_cut_priority: int = 0
var default_material: String = ""
var default_is_exterior: bool = false

# Drag & drop
var dragging_cell: RectangleCell = null
var is_dragging: bool = false
var drag_offset: Vector2 = Vector2.ZERO
var hovered_grip: Vector2 = Vector2.ZERO

# Constante pentru snap
const SNAP_TOLERANCE = 0.125  # Toleranța pentru snap în unități world
const SNAP_DISTANCE = 10.0  # toleranța snap în pixeli (pentru screen-space)
# Debugging
var debug_snapping: bool = false

# Adaugă un nou cell la poziția specificată
func add_cell(position: Vector2) -> RectangleCell:
	var cell = RectangleCell.new(position, default_width, default_height)
	
	# Setează proprietățile
	cell.set_offset(default_offset)
	cell.set_properties(
		default_name + "_" + str(next_index).pad_zeros(3),
		default_type,
		next_index
	)
	
	cells.append(cell)
	next_index += 1
	
	print("Cell adăugat: %s" % cell._to_string())
	return cell

# Găsește cell-ul la o poziție specificată
func get_cell_at_position(world_pos: Vector2) -> RectangleCell:
	# Caută în ordine inversă pentru a selecta cell-ul de deasupra
	for i in range(cells.size() - 1, -1, -1):
		var cell = cells[i]
		if cell.contains_point(world_pos):
			return cell
	return null

# Selectează un cell
func select_cell(cell: RectangleCell):
	# Deselectează cell-ul anterior
	if selected_cell:
		selected_cell.is_selected = false
	
	# Selectează noul cell
	selected_cell = cell
	if selected_cell:
		selected_cell.is_selected = true

# Începe drag pentru un cell
func start_drag_cell(cell: RectangleCell, world_pos: Vector2):
	dragging_cell = cell
	is_dragging = true
	drag_offset = world_pos - cell.position

# Actualizează drag-ul cu snap (poate folosi world->screen pentru snap în pixeli)
func update_drag(world_pos: Vector2, external_snap_points: Array[Vector2] = [], world_to_screen_func: Callable = Callable(), snap_pixel_tolerance: float = 10.0):
	if not is_dragging or not dragging_cell:
		return

	# Calculează poziția dorită (în world)
	var target_pos = world_pos - drag_offset

	# Aplică snap (dacă se primește world_to_screen_func folosește distanță în pixeli)
	var snapped_pos = get_snapped_position(target_pos, external_snap_points, world_to_screen_func, snap_pixel_tolerance)

	# Actualizează poziția cell-ului
	dragging_cell.move_to(snapped_pos)

# Finalizează drag-ul
func end_drag():
	dragging_cell = null
	is_dragging = false
	drag_offset = Vector2.ZERO

# Obține poziție cu snap
func get_snapped_position(world_pos: Vector2, external_snap_points: Array[Vector2] = [], world_to_screen_func: Callable = Callable(), snap_pixel_tolerance: float = SNAP_DISTANCE) -> Vector2:
	# Colectează punctele de snap din toate cell-urile
	var snap_points: Array[Vector2] = get_snap_points()

	# Adaugă punctele externe
	for point in external_snap_points:
		snap_points.append(point)

	# Exclude punctele cell-ului care se mută (comparare în world)
	if dragging_cell:
		var cell_points = dragging_cell.get_all_grip_points()
		snap_points = snap_points.filter(func(point):
			for cell_point in cell_points:
				if point.distance_to(cell_point) < 0.01:
					return false
			return true
		)

	# Folosim același mecanism ca PolygonManager: try_snap_to_points cu fallback la grid
	var snapped_pos = try_snap_to_points(world_pos, snap_points, SNAP_TOLERANCE, world_to_screen_func)
	if snapped_pos == world_pos:
		return snap_to_grid(world_pos)
	else:
		return snapped_pos

# Încearcă snap la o listă de puncte (funcție similară cu PolygonManager.try_snap_to_points)
func try_snap_to_points(world_pos: Vector2, snap_points: Array[Vector2], snap_tolerance: float, world_to_screen_func: Callable) -> Vector2:
	var closest_distance = INF
	var closest_point = world_pos

	# Dacă nu avem funcția de conversie, folosim toleranța direct în world
	if not world_to_screen_func.is_valid():
		for snap_point in snap_points:
			var distance = world_pos.distance_to(snap_point)
			if distance <= snap_tolerance and distance < closest_distance:
				closest_distance = distance
				closest_point = snap_point
	else:
		# Convertim toleranța din pixeli în unități world (folosim SNAP_DISTANCE ca limită în pixeli)
		var screen_pos = world_to_screen_func.call(world_pos)
		for snap_point in snap_points:
			var snap_screen = world_to_screen_func.call(snap_point)
			var screen_distance = screen_pos.distance_to(snap_screen)
			if screen_distance <= SNAP_DISTANCE and screen_distance < closest_distance:
				closest_distance = screen_distance
				closest_point = snap_point

	return closest_point

# Snap la grid (fallback) — folosim grid_size 0.25 pentru consistență cu PolygonManager
func snap_to_grid(world_pos: Vector2, grid_size: float = 0.25) -> Vector2:
	return Vector2(
		round(world_pos.x / grid_size) * grid_size,
		round(world_pos.y / grid_size) * grid_size
	)

# Obține toate punctele de snap din cell-uri
func get_snap_points() -> Array[Vector2]:
	var snap_points: Array[Vector2] = []
	
	for cell in cells:
		var cell_points = cell.get_all_grip_points()
		for point in cell_points:
			snap_points.append(point)
	
	return snap_points

# Actualizează hover grip
func update_hover_grip(world_pos: Vector2):
	hovered_grip = Vector2.ZERO
	
	if not selected_cell:
		return
	
	# Verifică grip points din dreptunghiul principal
	var main_grips = selected_cell.get_main_grip_points()
	for grip_type in main_grips:
		var grip_pos = main_grips[grip_type]
		if world_pos.distance_to(grip_pos) <= 0.15:  # Toleranță pentru hover
			hovered_grip = grip_pos
			return
	
	# Verifică grip points din dreptunghiul cu offset
	var offset_grips = selected_cell.get_offset_grip_points()
	for grip_type in offset_grips:
		var grip_pos = offset_grips[grip_type]
		if world_pos.distance_to(grip_pos) <= 0.15:
			hovered_grip = grip_pos
			return

# Setează proprietățile default pentru noi cell-uri
func set_default_properties(width: float, height: float, offset_x: float, offset_y: float, name: String, type: String):
	default_width = max(0.1, width)
	default_height = max(0.1, height)
	default_offset = offset_x
	default_name = name
	default_type = type

# Actualizează proprietățile cell-ului selectat
func update_selected_cell_properties(width: float, height: float, offset_x: float, offset_y: float, name: String, type: String, index: int):
	if not selected_cell:
		return false
	
	selected_cell.set_dimensions(width, height)
	selected_cell.set_offset(offset_x)
	selected_cell.set_properties(name, type, index)
	
	print("Cell actualizat: %s" % selected_cell._to_string())
	return true

# Șterge cell-ul selectat
func delete_selected_cell():
	if selected_cell:
		cells.erase(selected_cell)
		selected_cell = null
		return true
	return false

# Translate the selected cell by dx, dy (world units)
func translate_selected(dx: float, dy: float) -> bool:
	if not selected_cell:
		return false
	var new_pos = selected_cell.position + Vector2(dx, dy)
	selected_cell.move_to(new_pos)
	print("Cell translated by (%.3f, %.3f) -> new pos: (%.3f, %.3f)" % [dx, dy, new_pos.x, new_pos.y])
	return true

# Backwards-compatible name used by viewer
func delete_selected() -> bool:
	return delete_selected_cell()

# Obține informații despre toate cell-urile
func get_cells_info() -> Array[Dictionary]:
	var info_array: Array[Dictionary] = []
	for cell in cells:
		info_array.append(cell.get_info())
	return info_array

# Găsește cell după ID unic
func get_cell_by_id(unique_id: String) -> RectangleCell:
	for cell in cells:
		if cell.unique_id == unique_id:
			return cell
	return null

# Curăță toate cell-urile
func clear_all():
	cells.clear()
	selected_cell = null
	next_index = 1

# Returnează proprietățile default ca Dictionary
func get_default_properties() -> Dictionary:
	return {
		"width": default_width,
		"height": default_height,
		"offset": default_offset,
		"name": default_name,
		"type": default_type,
		"index": next_index
	}

# Setează proprietățile default din Dictionary
func set_default_properties_from_dict(properties: Dictionary):
	default_width = max(0.1, properties.get("width", 1.0))
	default_height = max(0.1, properties.get("height", 1.0))
	default_offset = properties.get("offset", 0.0)
	default_name = properties.get("name", "Cell")
	default_type = properties.get("type", "Standard")
	if properties.has("index"):
		next_index = properties.get("index", 1)

# Actualizează proprietățile cell-ului selectat din Dictionary
func update_selected_cell_properties_from_dict(properties: Dictionary) -> bool:
	if not selected_cell:
		return false
	
	var width = max(0.1, properties.get("width", selected_cell.width))
	var height = max(0.1, properties.get("height", selected_cell.height))
	var offset = properties.get("offset", selected_cell.offset)
	var name = properties.get("name", selected_cell.cell_name)
	var type = properties.get("type", selected_cell.cell_type)
	var index = properties.get("index", selected_cell.cell_index)

	# Extended properties
	var height_3d = properties.get("height_3d", selected_cell.height_3d if selected_cell else 0.0)
	var sill = properties.get("sill", selected_cell.sill if selected_cell else 0.0)
	var translation_x = properties.get("translation_x", selected_cell.translation_x if selected_cell else 0.0)
	var translation_y = properties.get("translation_y", selected_cell.translation_y if selected_cell else 0.0)
	var cut_priority = properties.get("cut_priority", selected_cell.cut_priority if selected_cell else 0)
	var material = properties.get("material", selected_cell.material if selected_cell else "")
	var is_exterior = properties.get("is_exterior", selected_cell.is_exterior if selected_cell else false)
	
	selected_cell.set_dimensions(width, height)
	selected_cell.set_offset(offset)
	selected_cell.set_properties(name, type, index)

	# Apply extended properties directly on the cell
	selected_cell.height_3d = height_3d
	selected_cell.sill = sill
	selected_cell.translation_x = translation_x
	selected_cell.translation_y = translation_y
	selected_cell.cut_priority = int(cut_priority)
	selected_cell.material = str(material)
	selected_cell.is_exterior = bool(is_exterior)
	
	print("Cell actualizat: %s" % selected_cell._to_string())
	return true
