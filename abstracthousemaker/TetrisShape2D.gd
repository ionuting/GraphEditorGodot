extends Node2D
class_name TetrisShape2D

@export var shape_type: String = "rectangle" : set = set_shape_type
@export var shape_size: Vector2 = Vector2(100, 100) : set = set_shape_size
@export var interior_offset: float = 12.5 : set = set_interior_offset
@export var extrusion_height: float = 255

var base_vertices: Array[Vector2] = []
var offset_vertices: Array[Vector2] = []
var is_selected: bool = false
var is_being_dragged: bool = false
var drag_offset: Vector2
var selected_vertex_index: int = -1
var control_point_radius: float = 8.0
var snap_distance: float = 25.0
var is_whole_shape_dragging: bool = false

signal shape_changed
signal shape_selected

func _ready():
	_update_shape()
	queue_redraw()

func set_shape_type(value: String):
	shape_type = value
	_update_shape()
	queue_redraw()

func set_shape_size(value: Vector2):
	shape_size = value
	_update_shape()
	queue_redraw()

func set_interior_offset(value: float):
	interior_offset = value
	_update_shape()
	queue_redraw()

func _update_shape():
	_generate_base_vertices()
	_update_offset_from_base()
	shape_changed.emit()

func _generate_base_vertices():
	match shape_type:
		"rectangle":
			# Asigurăm orientarea corectă pentru CSG (counter-clockwise)
			base_vertices = [
				Vector2(0, 0),
				Vector2(0, shape_size.y),
				Vector2(shape_size.x, shape_size.y),
				Vector2(shape_size.x, 0)
			]
		"L":
			# L shape cu dimensiuni reglabile
			var unit_x = shape_size.x / 2
			var unit_y = shape_size.y / 2
			base_vertices = [
				Vector2(0, 0),
				Vector2(unit_x, 0),
				Vector2(unit_x, unit_y),
				Vector2(shape_size.x, unit_y),
				Vector2(shape_size.x, shape_size.y),
				Vector2(0, shape_size.y)
			]
		"T":
			# T shape cu dimensiuni reglabile
			var unit_x = shape_size.x / 3
			var unit_y = shape_size.y / 2
			base_vertices = [
				Vector2(0, 0),
				Vector2(shape_size.x, 0),
				Vector2(shape_size.x, unit_y),
				Vector2(2 * unit_x, unit_y),
				Vector2(2 * unit_x, shape_size.y),
				Vector2(unit_x, shape_size.y),
				Vector2(unit_x, unit_y),
				Vector2(0, unit_y)
			]

func _draw():
	# Desenează forma umplută
	if base_vertices.size() > 2:
		# Fill forma (gri deschis)
		var fill_color = Color.LIGHT_GRAY
		if is_selected:
			fill_color = Color(1.0, 1.0, 0.8, 0.7)  # galben deschis semi-transparent
		draw_colored_polygon(PackedVector2Array(base_vertices), fill_color)
		
		# Contur exterior
		var outline_color = Color.YELLOW if is_selected else Color.RED
		var outline_width = 4.0 if is_selected else 3.0
		draw_polyline(base_vertices + [base_vertices[0]], outline_color, outline_width)
	
	# Desenează conturul interior offsetat
	if offset_vertices.size() > 2:
		# Fill offset (albastru deschis)
		draw_colored_polygon(PackedVector2Array(offset_vertices), Color(0.5, 0.7, 1.0, 0.5))
		# Contur offset
		draw_polyline(offset_vertices + [offset_vertices[0]], Color.BLUE, 2.0)
	
	# Desenează snap lines dacă forma e selectată
	if is_selected:
		_draw_snap_lines()
	
	# Desenează toate punctele ca drag points
	for i in range(base_vertices.size()):
		var vertex = base_vertices[i]
		var color = Color.GREEN
		var radius = control_point_radius
		
		# Evidentiază punctul selectat
		if i == selected_vertex_index:
			color = Color.YELLOW
			radius = control_point_radius * 1.3
		
		# Desenează punct cu contur pentru drag
		draw_circle(vertex, radius, color)
		draw_circle(vertex, radius, Color.DARK_GREEN, false, 2.0)
		
		# Adaugă indicator că punctul e draggable
		draw_circle(vertex, radius - 2, Color.WHITE, false, 1.0)

func _apply_interior_offset(poly: Array[Vector2], offset: float) -> Array[Vector2]:
	if poly.size() < 3 or offset <= 0:
		return poly
	
	var new_poly: Array[Vector2] = []
	var n = poly.size()
	
	for i in range(n):
		var prev = poly[(i - 1 + n) % n]
		var curr = poly[i]
		var next = poly[(i + 1) % n]
		
		# Calculează vectorii de margine
		var edge1 = (curr - prev).normalized()
		var edge2 = (next - curr).normalized()
		
		# Calculează normalele (perpendiculare pe margini, înspre interior)
		# Pentru un poligon orientat counter-clockwise, normala interior e la dreapta marginii
		var normal1 = Vector2(edge1.y, -edge1.x)  # Normala spre interior
		var normal2 = Vector2(edge2.y, -edge2.x)  # Normala spre interior
		
		# Calculează direcția bisectoarei
		var bisector = (normal1 + normal2).normalized()
		
		# Tratează cazul degenerat când normalele sunt opuse
		if bisector.length_squared() < 0.001:
			bisector = normal1
		
		# Calculează distanța de offset de-a lungul bisectoarei
		var cos_half_angle = bisector.dot(normal1)
		if abs(cos_half_angle) > 0.001:
			var offset_distance = offset / cos_half_angle
			new_poly.append(curr + bisector * offset_distance)
		else:
			new_poly.append(curr + normal1 * offset)
	
	return new_poly

func get_snap_points() -> Array[Vector2]:
	var world_points: Array[Vector2] = []
	for vertex in base_vertices:
		world_points.append(global_transform * vertex)
	return world_points

func get_offset_vertices_world() -> Array[Vector2]:
	var world_vertices: Array[Vector2] = []
	for vertex in offset_vertices:
		world_vertices.append(global_transform * vertex)
	return world_vertices

func _input(event):
	if not _is_move_mode_enabled():
		return
		
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				var local_mouse = to_local(get_global_mouse_position())
				
				# Verifică dacă s-a făcut click pe un punct de control
				selected_vertex_index = _get_vertex_at_position(local_mouse)
				
				if selected_vertex_index >= 0:
					# Click pe un punct de control
					is_being_dragged = true
					is_whole_shape_dragging = false
					is_selected = true
					queue_redraw()
					shape_selected.emit()
				elif _is_point_in_shape(local_mouse):
					# Click în interiorul formei - mutare întreaga formă
					is_being_dragged = true
					is_whole_shape_dragging = true
					is_selected = true
					selected_vertex_index = -1
					drag_offset = global_position - get_global_mouse_position()
					queue_redraw()
					shape_selected.emit()
				else:
					# Click în afara formei - deseleccionează
					is_selected = false
					selected_vertex_index = -1
					queue_redraw()
			else:
				is_being_dragged = false
				selected_vertex_index = -1
	
	elif event is InputEventMouseMotion and is_being_dragged:
		if selected_vertex_index >= 0 and not is_whole_shape_dragging:
			# Mutare punct de control individual cu snap
			var mouse_global = get_global_mouse_position()
			var snapped_pos = _apply_snap_to_point(mouse_global)
			var local_mouse = to_local(snapped_pos)
			base_vertices[selected_vertex_index] = local_mouse
			_update_offset_from_base()
			_update_shape_size_from_vertices()
			queue_redraw()
			shape_changed.emit()
		elif is_whole_shape_dragging:
			# Mutare întreaga formă cu snap
			var target_pos = get_global_mouse_position() + drag_offset
			var snapped_pos = _apply_snap_to_point(target_pos)
			global_position = snapped_pos

func _get_vertex_at_position(pos: Vector2) -> int:
	for i in range(base_vertices.size()):
		if pos.distance_to(base_vertices[i]) <= control_point_radius:
			return i
	return -1

func _update_offset_from_base():
	offset_vertices = _apply_interior_offset(base_vertices, interior_offset)

func _draw_snap_lines():
	if not is_being_dragged or selected_vertex_index < 0:
		return
	
	var current_vertex = global_transform * base_vertices[selected_vertex_index]
	var other_shapes = get_tree().get_nodes_in_group("tetris_shapes")
	
	for shape in other_shapes:
		if shape == self:
			continue
			
		var snap_points = shape.get_snap_points()
		for snap_point in snap_points:
			var distance = current_vertex.distance_to(snap_point)
			if distance < snap_distance * 2:  # Show snap lines in larger radius
				var local_start = to_local(current_vertex)
				var local_end = to_local(snap_point)
				
				# Vertical snap line
				if abs(current_vertex.x - snap_point.x) < snap_distance:
					draw_line(Vector2(local_end.x, local_start.y - 50), Vector2(local_end.x, local_start.y + 50), Color.MAGENTA, 1.0)
				
				# Horizontal snap line
				if abs(current_vertex.y - snap_point.y) < snap_distance:
					draw_line(Vector2(local_start.x - 50, local_end.y), Vector2(local_start.x + 50, local_end.y), Color.MAGENTA, 1.0)
				
				# Direct snap line to point
				if distance < snap_distance:
					draw_line(local_start, local_end, Color.CYAN, 2.0)

func _is_point_in_shape(point: Vector2) -> bool:
	if base_vertices.size() < 3:
		return false
	
	# Simple point in polygon test
	var inside = false
	var j = base_vertices.size() - 1
	
	for i in range(base_vertices.size()):
		var vi = base_vertices[i]
		var vj = base_vertices[j]
		
		if ((vi.y > point.y) != (vj.y > point.y)) and (point.x < (vj.x - vi.x) * (point.y - vi.y) / (vj.y - vi.y) + vi.x):
			inside = !inside
		j = i
	
	return inside

func set_selected(selected: bool):
	is_selected = selected
	if not selected:
		selected_vertex_index = -1
	queue_redraw()

func _is_move_mode_enabled() -> bool:
	# Găsește Main node și verifică move_mode_enabled
	var main_node = get_tree().get_first_node_in_group("main")
	if main_node:
		return main_node.get("move_mode_enabled")
	else:
		# Fallback - caută prin părinte
		var current = self
		while current:
			if current.has_method("_on_move_mode_toggled"):
				return current.get("move_mode_enabled")
			current = current.get_parent()
	return false

func _apply_snap_to_point(global_pos: Vector2) -> Vector2:
	var other_shapes = get_tree().get_nodes_in_group("tetris_shapes")
	var best_snap_pos = global_pos
	var min_distance = snap_distance
	
	# Pentru mutarea întregii forme, snap la oricare dintre punctele sale către punctele altor forme
	if is_whole_shape_dragging:
		# Calculează punctele curente ale formei la noua poziție
		var potential_position = global_pos
		var offset_from_current = potential_position - global_position
		
		for shape in other_shapes:
			if shape == self:
				continue
				
			var other_snap_points = shape.get_snap_points()
			var my_snap_points = get_snap_points()
			
			# Verifica snap pentru fiecare punct al formei curente către punctele altor forme
			for my_point in my_snap_points:
				var my_point_new_pos = my_point + offset_from_current
				
				for other_point in other_snap_points:
					var distance = my_point_new_pos.distance_to(other_point)
					if distance < min_distance:
						min_distance = distance
						# Calculează poziția globală necesară pentru această aliniere
						var adjustment = other_point - my_point_new_pos
						best_snap_pos = potential_position + adjustment
	else:
		# Pentru mutarea punctelor individuale
		for shape in other_shapes:
			if shape == self:
				continue
				
			var snap_points = shape.get_snap_points()
			for snap_point in snap_points:
				var distance = global_pos.distance_to(snap_point)
				if distance < min_distance:
					min_distance = distance
					best_snap_pos = snap_point
	
	return best_snap_pos

func _update_shape_size_from_vertices():
	if shape_type == "rectangle" and base_vertices.size() >= 4:
		# Pentru rectangle, calculează dimensiunea din vertices
		var min_pos = base_vertices[0]
		var max_pos = base_vertices[0]
		
		for vertex in base_vertices:
			min_pos.x = min(min_pos.x, vertex.x)
			min_pos.y = min(min_pos.y, vertex.y)
			max_pos.x = max(max_pos.x, vertex.x)
			max_pos.y = max(max_pos.y, vertex.y)
		
		var new_size = max_pos - min_pos
		if new_size.x > 10 and new_size.y > 10:  # Minimum size
			shape_size = new_size

func get_current_dimensions() -> Vector2:
	if shape_type == "rectangle":
		return shape_size
	else:
		# Pentru alte forme, calculează bounding box
		if base_vertices.size() == 0:
			return Vector2.ZERO
		
		var min_pos = base_vertices[0]
		var max_pos = base_vertices[0]
		
		for vertex in base_vertices:
			min_pos.x = min(min_pos.x, vertex.x)
			min_pos.y = min(min_pos.y, vertex.y)
			max_pos.x = max(max_pos.x, vertex.x)
			max_pos.y = max(max_pos.y, vertex.y)
		
		return max_pos - min_pos

func set_dimensions(new_size: Vector2):
	if new_size.x > 10 and new_size.y > 10:
		shape_size = new_size
		_update_shape()
