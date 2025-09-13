# PolygonManager.gd
# Clasă pentru gestionarea poligoanalor (selecție, mutare, snap)
class_name PolygonManager

extends RefCounted

# Colecția de poligoane
var polygons: Array[PolygonDrawer2D] = []
var selected_polygon: PolygonDrawer2D = null
var current_drawing_polygon: PolygonDrawer2D = null
var is_drawing_mode: bool = false

# Drag & drop pentru poligoane întregi
var is_dragging: bool = false
var dragging_polygon: PolygonDrawer2D = null
var drag_start_pos: Vector2
var drag_offset: Vector2

# Control points (grip points pentru punctele individuale ale poligoanelor)
var hovered_control_point: Vector2 = Vector2.ZERO
var dragging_control_point: Vector2 = Vector2.ZERO
var is_dragging_control_point: bool = false
var dragging_control_polygon: PolygonDrawer2D = null
var control_drag_start_pos: Vector2 = Vector2.ZERO

# Constante pentru snap
const SNAP_DISTANCE = 10.0  # pixeli pe ecran

# Adaugă un nou poligon și începe desenarea
func start_drawing_polygon() -> PolygonDrawer2D:
	var polygon = PolygonDrawer2D.new()
	current_drawing_polygon = polygon
	is_drawing_mode = true
	return polygon

# Finalizează desenarea curentă
func finish_drawing():
	if current_drawing_polygon and current_drawing_polygon.points.size() > 2:
		if not current_drawing_polygon.is_closed:
			current_drawing_polygon.close_polygon()
		polygons.append(current_drawing_polygon)
		select_polygon(current_drawing_polygon)
	
	current_drawing_polygon = null
	is_drawing_mode = false

# Anulează desenarea curentă
func cancel_drawing():
	current_drawing_polygon = null
	is_drawing_mode = false

# Adaugă punct la poligonul curent în desenare
func add_point_to_current(world_pos: Vector2) -> bool:
	if not current_drawing_polygon:
		return false
	
	var polygon_closed = current_drawing_polygon.add_point(world_pos)
	if polygon_closed:
		# Poligonul s-a închis automat
		polygons.append(current_drawing_polygon)
		select_polygon(current_drawing_polygon)
		current_drawing_polygon = null
		is_drawing_mode = false
		return true
	
	return false

# Găsește poligonul la o anumită poziție
func get_polygon_at_position(world_pos: Vector2) -> PolygonDrawer2D:
	# Verifică în ordine inversă (ultimele desenate au prioritate)
	for i in range(polygons.size() - 1, -1, -1):
		var polygon = polygons[i]
		if polygon.contains_point(world_pos):
			return polygon
	return null

# Găsește punctul de control la o anumită poziție
func get_control_point_at_position(world_pos: Vector2, tolerance: float = 0.15) -> Dictionary:
	# Returnează un dicționar cu polygon și punctul de control găsit
	for polygon in polygons:
		if not polygon.is_selected or not polygon.is_closed:
			continue
		
		var control_point = polygon.get_control_point_at_position(world_pos, tolerance)
		if control_point != Vector2.ZERO:
			return {"polygon": polygon, "control_point": control_point}
	
	return {}

# Verifică hover peste punctele de control
func update_hover_control_point(world_pos: Vector2, tolerance: float = 0.15):
	hovered_control_point = Vector2.ZERO
	
	var control_info = get_control_point_at_position(world_pos, tolerance)
	if not control_info.is_empty():
		hovered_control_point = control_info.control_point

# Începe drag pentru un punct de control
func start_drag_control_point(world_pos: Vector2, tolerance: float = 0.15) -> bool:
	var control_info = get_control_point_at_position(world_pos, tolerance)
	if control_info.is_empty():
		return false
	
	is_dragging_control_point = true
	dragging_control_point = control_info.control_point
	dragging_control_polygon = control_info.polygon
	control_drag_start_pos = world_pos
	
	return true

# Actualizează poziția punctului de control în timpul drag-ului
func update_control_point_drag(world_pos: Vector2, external_snap_points: Array[Vector2] = []):
	if not is_dragging_control_point or not dragging_control_polygon:
		return
	
	# Exclude punctul curent din snap pentru a evita snap la el însuși
	var filtered_snap_points: Array[Vector2] = []
	for snap_point in external_snap_points:
		if snap_point.distance_to(dragging_control_point) > 0.1:  # Exclude punctul curent
			filtered_snap_points.append(snap_point)
	
	# Aplică snap la poziția nouă
	var snapped_pos = get_snapped_position(world_pos, filtered_snap_points)
	
	# Actualizează punctul în poligon (pentru punctele originale)
	for i in range(dragging_control_polygon.points.size()):
		if dragging_control_polygon.points[i].distance_to(dragging_control_point) < 0.01:
			dragging_control_polygon.points[i] = snapped_pos
			dragging_control_point = snapped_pos
			dragging_control_polygon._update_offset()
			break

# Finalizează drag-ul punctului de control
func finish_control_point_drag():
	is_dragging_control_point = false
	dragging_control_point = Vector2.ZERO
	dragging_control_polygon = null

# Selectează un poligon
func select_polygon(polygon: PolygonDrawer2D):
	# Deselectează poligonul anterior
	if selected_polygon:
		selected_polygon.is_selected = false
	
	selected_polygon = polygon
	if polygon:
		polygon.is_selected = true

# Începe operația de drag pentru un poligon
func start_drag_polygon(polygon: PolygonDrawer2D, world_pos: Vector2):
	if not polygon:
		return
	
	is_dragging = true
	dragging_polygon = polygon
	drag_start_pos = world_pos
	drag_offset = polygon.get_center() - world_pos

# Actualizează poziția în timpul drag-ului
func update_drag(world_pos: Vector2, external_snap_points: Array[Vector2] = []):
	if not is_dragging or not dragging_polygon:
		return
	
	var new_pos = world_pos + drag_offset
	var snap_pos = get_snapped_position(new_pos, external_snap_points)
	dragging_polygon.move_to(snap_pos)

# Finalizează operația de drag
func finish_drag():
	is_dragging = false
	dragging_polygon = null

# Returnează poziția cu snap aplicat
func get_snapped_position(world_pos: Vector2, external_snap_points: Array[Vector2] = []) -> Vector2:
	# Încearcă snap la punctele altor poligoane + puncte externe
	var snap_points = get_snap_points()
	for point in external_snap_points:
		snap_points.append(point)
	
	var snapped_pos = try_snap_to_points(world_pos, snap_points, 1.0, Callable())
	
	# Dacă nu s-a făcut snap la puncte, încearcă snap la grid
	if snapped_pos == world_pos:
		return snap_to_grid(world_pos)
	else:
		return snapped_pos

# Snap la grid
func snap_to_grid(world_pos: Vector2, grid_size: float = 0.25) -> Vector2:
	return Vector2(
		round(world_pos.x / grid_size) * grid_size,
		round(world_pos.y / grid_size) * grid_size
	)

# Returnează toate punctele de snap disponibile pentru TOATE poligoanele
func get_snap_points() -> Array[Vector2]:
	var snap_points: Array[Vector2] = []
	
	for polygon in polygons:
		if polygon == dragging_polygon:
			continue  # Nu face snap la propriile puncte
		
		# ÎNTOTDEAUNA adaugă punctele de snap pentru toate poligoanele (nu doar cele selectate)
		
		# 1. Puncte originale (colțurile poligonului)
		for point in polygon.points:
			snap_points.append(point)
		
		# 2. Mijlocurile liniilor
		for i in range(polygon.points.size()):
			if not polygon.is_closed and i == polygon.points.size() - 1:
				continue  # Pentru poligoane deschise, nu procesează ultima linie inexistentă
			
			var current = polygon.points[i]
			var next = polygon.points[(i + 1) % polygon.points.size()]
			var midpoint = (current + next) * 0.5
			snap_points.append(midpoint)
		
		# 3. Centrul poligonului (doar pentru poligoane închise)
		if polygon.is_closed:
			snap_points.append(polygon.get_center())
		
		# 4. Puncte intermediare pe linii pentru snap precis (la fiecare 0.125 unități)
		var line_points = polygon.get_all_line_points(0.125)
		for point in line_points:
			snap_points.append(point)
		
		# 5. Puncte pe poligonul offsetat dacă există
		if polygon.offset_points.size() > 0:
			# Colțurile offsetate
			for point in polygon.offset_points:
				snap_points.append(point)
			
			# Mijlocurile liniilor offsetate
			for i in range(polygon.offset_points.size()):
				var current = polygon.offset_points[i]
				var next = polygon.offset_points[(i + 1) % polygon.offset_points.size()]
				var midpoint = (current + next) * 0.5
				snap_points.append(midpoint)
				
				# Puncte intermediare pe liniile offsetate
				var line_vector = next - current
				var line_length = line_vector.length()
				var step_size = 0.125
				
				if line_length > step_size:
					var steps = int(line_length / step_size)
					for step in range(1, steps):
						var t = float(step) / float(steps)
						var point_on_line = current + line_vector * t
						snap_points.append(point_on_line)
	
	return snap_points

# Încearcă snap la o listă de puncte
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
		# Convertim toleranța din pixeli în unități world
		var screen_pos = world_to_screen_func.call(world_pos)
		for snap_point in snap_points:
			var snap_screen = world_to_screen_func.call(snap_point)
			var screen_distance = screen_pos.distance_to(snap_screen)
			if screen_distance <= SNAP_DISTANCE and screen_distance < closest_distance:
				closest_distance = screen_distance
				closest_point = snap_point
	
	return closest_point

# Șterge poligonul selectat
func delete_selected():
	if selected_polygon:
		polygons.erase(selected_polygon)
		selected_polygon = null

# Translate selected polygon by dx, dy (moves polygon center)
func translate_selected(dx: float, dy: float) -> bool:
	if not selected_polygon:
		return false
	var new_center = selected_polygon.get_center() + Vector2(dx, dy)
	selected_polygon.move_to(new_center)
	print("Polygon translated by (%.3f, %.3f) -> new center: (%.3f, %.3f)" % [dx, dy, new_center.x, new_center.y])
	return true

# Șterge toate poligoanele
func clear_all():
	polygons.clear()
	selected_polygon = null
	current_drawing_polygon = null
	is_drawing_mode = false
	is_dragging = false
	dragging_polygon = null

# Funcții pentru salvare/încărcare
func to_dict() -> Dictionary:
	var polygons_data = []
	for polygon in polygons:
		polygons_data.append(polygon.to_dict())
	
	return {
		"polygons": polygons_data,
		"selected_id": selected_polygon.unique_id if selected_polygon else "",
		"is_drawing_mode": is_drawing_mode
	}

func from_dict(data: Dictionary):
	clear_all()
	
	if data.has("polygons") and data.polygons is Array:
		for polygon_data in data.polygons:
			var polygon = PolygonDrawer2D.new()
			polygon.from_dict(polygon_data)
			polygons.append(polygon)
			
			# Restaurează selecția
			if data.has("selected_id") and polygon.unique_id == data.selected_id:
				select_polygon(polygon)
