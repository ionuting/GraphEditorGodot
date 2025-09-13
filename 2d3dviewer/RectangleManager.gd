# RectangleManager.gd
# Clasă pentru gestionarea dreptunghiurilor (selecție, mutare, snap)
class_name RectangleManager

extends RefCounted

var rectangles: Array[Rectangle2D] = []
var selected_rectangle: Rectangle2D = null
var dragging_rectangle: Rectangle2D = null
var dragging_grip: Rectangle2D.GripPoint = -1
var drag_offset: Vector2 = Vector2.ZERO
var hovered_grip: Rectangle2D.GripPoint = -1
var next_id: int = 0

# Constante pentru snap
const SNAP_DISTANCE = 10.0  # pixeli pe ecran

# Adaugă un dreptunghi nou
func add_rectangle(pos: Vector2, size: Vector2) -> Rectangle2D:
	var rect = Rectangle2D.new(pos, size, next_id)
	next_id += 1
	rectangles.append(rect)
	return rect

# Elimină un dreptunghi
func remove_rectangle(rect: Rectangle2D):
	if selected_rectangle == rect:
		selected_rectangle = null
	if dragging_rectangle == rect:
		dragging_rectangle = null
	rectangles.erase(rect)

# Găsește dreptunghiul la o poziție dată (cel mai din față)
func get_rectangle_at_position(world_pos: Vector2) -> Rectangle2D:
	print("Căutare dreptunghi la poziția %s în %d dreptunghiuri" % [world_pos, rectangles.size()])
	# Parcurge în ordine inversă pentru a găsi cel mai din față
	for i in range(rectangles.size() - 1, -1, -1):
		var rect = rectangles[i]
		if rect.contains_point(world_pos):
			print("Găsit dreptunghi %d la poziția %s" % [rect.id, world_pos])
			return rect
	print("Niciun dreptunghi găsit la poziția %s" % world_pos)
	return null

# Găsește cel mai apropiat punct de grip de la toate dreptunghiurile
func get_grip_at_position(world_pos: Vector2, zoom: float, world_to_screen_func: Callable) -> Dictionary:
	var result = {"rectangle": null, "grip": -1}
	var min_distance = INF
	var screen_pos = world_to_screen_func.call(world_pos)
	
	for rect in rectangles:
		if not rect.is_selected:
			continue
			
		var grip_points = rect.get_grip_points()
		for grip_type in grip_points:
			var grip_world_pos = grip_points[grip_type]
			var grip_screen_pos = world_to_screen_func.call(grip_world_pos)
			var distance = screen_pos.distance_to(grip_screen_pos)
			
			# Verifică dacă este în raza de grip
			if distance <= RectangleRenderer.GRIP_SIZE and distance < min_distance:
				min_distance = distance
				result.rectangle = rect
				result.grip = grip_type
	
	return result

# Selectează un dreptunghi
func select_rectangle(rect: Rectangle2D):
	if selected_rectangle:
		selected_rectangle.is_selected = false
	selected_rectangle = rect
	if rect:
		rect.is_selected = true

# Începe să tragă un dreptunghi
func start_drag_rectangle(rect: Rectangle2D, world_pos: Vector2):
	dragging_rectangle = rect
	drag_offset = world_pos - rect.position
	select_rectangle(rect)

# Începe să tragă un grip - nu mai e folosită pentru redimensionare
func start_drag_grip(rect: Rectangle2D, grip: Rectangle2D.GripPoint):
	# Grip-urile sunt doar pentru selecție și snap, nu pentru redimensionare
	pass

# Actualizează drag-ul
func update_drag(world_pos: Vector2, external_snap_points: Array[Vector2] = []):
	if not dragging_rectangle:
		return
		
	# Doar mută dreptunghiul întreg - grip-urile nu redimensionează
	var new_pos = world_pos - drag_offset
	var snap_pos = get_snapped_position(new_pos, external_snap_points)
	dragging_rectangle.move_to(snap_pos)

# Termină drag-ul
func end_drag():
	dragging_rectangle = null
	dragging_grip = -1
	drag_offset = Vector2.ZERO

# Actualizează grip-ul hover
func update_hover_grip(world_pos: Vector2, zoom: float, world_to_screen_func: Callable):
	var grip_info = get_grip_at_position(world_pos, zoom, world_to_screen_func)
	hovered_grip = grip_info.grip if grip_info.rectangle else -1

# Returnează poziția cu snap aplicat
func get_snapped_position(world_pos: Vector2, external_snap_points: Array[Vector2] = []) -> Vector2:
	# Încearcă snap la punctele de grip ale altor dreptunghiuri + puncte externe
	var snap_points = get_snap_points(external_snap_points)
	var snapped_pos = try_snap_to_points(world_pos, snap_points, 1.0, Callable())
	
	# Dacă nu s-a făcut snap la puncte, încearcă snap la grid
	if snapped_pos == world_pos:
		return snap_to_grid(world_pos)
	else:
		return snapped_pos

# Snap la grid (exemplu simplu)
func snap_to_grid(world_pos: Vector2, grid_size: float = 0.25) -> Vector2:
	return Vector2(
		round(world_pos.x / grid_size) * grid_size,
		round(world_pos.y / grid_size) * grid_size
	)

# Returnează toate punctele de snap disponibile
func get_snap_points(external_snap_points: Array[Vector2] = []) -> Array[Vector2]:
	var snap_points: Array[Vector2] = []
	
	# Adaugă punctele de grip de la toate dreptunghiurile
	for rect in rectangles:
		if rect == dragging_rectangle:
			continue
		var grip_points = rect.get_grip_points()
		for grip_pos in grip_points.values():
			snap_points.append(grip_pos)
	
	# Adaugă punctele externe (de la poligoane sau alte surse)
	for point in external_snap_points:
		snap_points.append(point)
	
	return snap_points

# Verifică dacă se poate face snap la un punct
func try_snap_to_points(world_pos: Vector2, snap_points: Array[Vector2], zoom: float, world_to_screen_func: Callable) -> Vector2:
	# Simplificat - snap direct în coordonate world pentru distanță fixă
	var snap_distance_world = SNAP_DISTANCE / (50.0 * zoom)  # Convertește la coordonate world
	
	for snap_point in snap_points:
		var distance = world_pos.distance_to(snap_point)
		if distance <= snap_distance_world:
			return snap_point
	
	return world_pos


# Translate selected rectangle by dx, dy
func translate_selected(dx: float, dy: float) -> bool:
	if not selected_rectangle:
		return false
	var new_pos = selected_rectangle.position + Vector2(dx, dy)
	selected_rectangle.move_to(new_pos)
	print("Rectangle translated by (%.3f, %.3f) -> new pos: (%.3f, %.3f)" % [dx, dy, new_pos.x, new_pos.y])
	return true

# Delete selected rectangle (backwards-compatible API)
func delete_selected() -> bool:
	if selected_rectangle:
		rectangles.erase(selected_rectangle)
		selected_rectangle = null
		return true
	return false