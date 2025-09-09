extends Node2D

class_name TetrisShape2D

# Variabile interne pentru geometrie și stare
var base_vertices: Array[Vector2] = []
var offset_vertices: Array[Vector2] = []
var is_selected: bool = false
var is_being_dragged: bool = false
var drag_offset: Vector2 = Vector2.ZERO
var selected_vertex_index: int = -1
var control_point_radius: float = 8.0
var snap_distance: float = 25.0
var is_whole_shape_dragging: bool = false

@export var shape_type: String = "rectangle" : set = set_shape_type
@export var shape_size: Vector2 = Vector2(300, 300) : set = set_shape_size
@export var interior_offset: float = 12.5 : set = set_interior_offset
@export var extrusion_height: float = 255 # Înălțimea extruziunii conturului camerei (pereții solizi)

# Controlere pentru feronerie și uși
@export_group("Windows")
@export var has_window: bool = true : set = set_has_window
@export var window_style: String = "standard" : set = set_window_style
@export var window_side: int = 0 : set = set_window_side # 0, 90, 180, 270
@export var window_offset: float = 0.0 : set = set_window_offset
@export var window_n_offset: float = 0.0 : set = set_window_n_offset
@export var window_z_offset: float = 0.0 : set = set_window_z_offset
@export var window_width: float = 45.0 : set = set_window_width # width = latura mică în plan (2D outline)
@export var window_length: float = 120.0 : set = set_window_length # length = latura mare în plan (2D outline)
var window_height: float = 120.0 # height = înălțimea extruziunii cutbox-ului pe Z (vertical) - default proper height
var window_sill: float = 90.0 # sill = translația cutbox-ului pe Z pentru ridicare/coborâre - proper default sill height

@export_group("Doors") 
@export var has_door: bool = true : set = set_has_door
@export var door_style: String = "standard" : set = set_door_style
@export var door_side: int = 90 : set = set_door_side # 0, 90, 180, 270
@export var door_offset: float = 0.0 : set = set_door_offset
@export var door_n_offset: float = 0.0 : set = set_door_n_offset
@export var door_z_offset: float = 0.0 : set = set_door_z_offset
@export var door_width: float = 45.0 : set = set_door_width # width = latura mică în plan (2D outline)
@export var door_length: float = 90.0 : set = set_door_length # length = latura mare în plan (2D outline)
var door_height: float = 210.0 # height = înălțimea extruziunii cutbox-ului pe Z (vertical) - default proper height
var door_sill: float = 0.0 # sill = translația cutbox-ului pe Z pentru ridicare/coborâre

var unique_id: String = ""
var room_name: String = "Room"
var central_color: Color = Color.LIGHT_GRAY

# Controlere pentru feronerie și uși
var window_controller: WindowDoorController
var door_controller: WindowDoorController

signal shape_changed
signal shape_selected

func _ready():
	# Generează un ID unic la instanțiere
	if unique_id == "":
		unique_id = str(self.get_instance_id())
	_setup_controllers()
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

# Serializare proprietăți shape în JSON
func to_dict() -> Dictionary:
	# Organizează proprietățile în sub-dicționare pentru o structură mai curată
	var window_properties = {
		"has_window": has_window,
		"style": window_style,
		"side": window_side,
		"offset": window_offset,
		"n_offset": window_n_offset,
		"z_offset": window_z_offset,
		"width": window_width,
		"length": window_length,
		"height": window_height,
		"sill": window_sill
	}
	
	var door_properties = {
		"has_door": has_door,
		"style": door_style,
		"side": door_side,
		"offset": door_offset,
		"n_offset": door_n_offset,
		"z_offset": door_z_offset,
		"width": door_width,
		"length": door_length,
		"height": door_height,
		"sill": door_sill
	}
	
	return {
		"unique_id": unique_id,
		"shape_type": shape_type,
		"shape_size": {"x": shape_size.x, "y": shape_size.y},
		"interior_offset": interior_offset,
		"extrusion_height": extrusion_height,
		"window": window_properties,
		"door": door_properties,
		"room_name": room_name,
		"central_color": {"r": central_color.r, "g": central_color.g, "b": central_color.b, "a": central_color.a},
		"position": {"x": position.x, "y": position.y},
		# Adaugă informații geometrice calculate
		"geometry": get_geometry_info()
	}

# Setters și getters pentru height și sill
func set_window_height(value: float):
	window_height = value
	shape_changed.emit()

func get_window_height() -> float:
	return window_height

func set_window_sill(value: float):
	window_sill = value
	shape_changed.emit()

func get_window_sill() -> float:
	return window_sill

func set_door_height(value: float):
	door_height = value
	shape_changed.emit()

func get_door_height() -> float:
	return door_height

func set_door_sill(value: float):
	door_sill = value
	shape_changed.emit()

func get_door_sill() -> float:
	return door_sill

# Funcții pentru accesarea proprietăților organizate
func get_window_properties() -> Dictionary:
	"""Returnează toate proprietățile ferestrei ca dicționar"""
	return {
		"has_window": has_window,
		"style": window_style,
		"side": window_side,
		"offset": window_offset,
		"n_offset": window_n_offset,
		"z_offset": window_z_offset,
		"width": window_width,
		"length": window_length,
		"height": window_height,
		"sill": window_sill
	}

func get_door_properties() -> Dictionary:
	"""Returnează toate proprietățile ușii ca dicționar"""
	return {
		"has_door": has_door,
		"style": door_style,
		"side": door_side,
		"offset": door_offset,
		"n_offset": door_n_offset,
		"z_offset": door_z_offset,
		"width": door_width,
		"length": door_length,
		"height": door_height,
		"sill": door_sill
	}

# Funcție de debug pentru a afișa structura organizată
func debug_print_organized_properties():
	print("📋 Structured Properties:")
	print("  Window: ", get_window_properties())
	print("  Door: ", get_door_properties())
	print("  JSON Export: ", to_dict())

# Setters pentru room_name și central_color
func set_room_name(value: String):
	room_name = value

func set_central_color(value: Color):
	central_color = value
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

func from_dict(data: Dictionary):
	"""Deserializare din dicționar JSON cu suport pentru format nou și vechi"""
	if data.has("unique_id"):
		unique_id = data["unique_id"]
	if data.has("shape_type"):
		set_shape_type(data["shape_type"])
	if data.has("shape_size"):
		var size_data = data["shape_size"]
		if size_data is Vector2:
			set_shape_size(size_data)
		elif size_data is Dictionary and size_data.has("x") and size_data.has("y"):
			set_shape_size(Vector2(size_data.x, size_data.y))
		elif size_data is String:
			# Try to parse string representation like "(300, 250)"
			var cleaned = size_data.strip_edges().replace("(", "").replace(")", "")
			var parts = cleaned.split(",")
			if parts.size() == 2:
				set_shape_size(Vector2(float(parts[0].strip_edges()), float(parts[1].strip_edges())))
	if data.has("interior_offset"):
		set_interior_offset(data["interior_offset"])
	if data.has("extrusion_height"):
		extrusion_height = data["extrusion_height"]
	
	# Citește proprietățile window din sub-dicționar sau format vechi
	if data.has("window"):
		var window_props = data["window"]
		if window_props.has("has_window"):
			set_has_window(window_props["has_window"])
		if window_props.has("style"):
			set_window_style(window_props["style"])
		if window_props.has("side"):
			set_window_side(window_props["side"])
		if window_props.has("offset"):
			set_window_offset(window_props["offset"])
		if window_props.has("n_offset"):
			set_window_n_offset(window_props["n_offset"])
		if window_props.has("z_offset"):
			set_window_z_offset(window_props["z_offset"])
		if window_props.has("width"):
			set_window_width(window_props["width"])
		if window_props.has("length"):
			set_window_length(window_props["length"])
		if window_props.has("height"):
			window_height = window_props["height"]
		if window_props.has("sill"):
			window_sill = window_props["sill"]
	
	# Citește proprietățile door din sub-dicționar sau format vechi
	if data.has("door"):
		var door_props = data["door"]
		if door_props.has("has_door"):
			set_has_door(door_props["has_door"])
		if door_props.has("style"):
			set_door_style(door_props["style"])
		if door_props.has("side"):
			set_door_side(door_props["side"])
		if door_props.has("offset"):
			set_door_offset(door_props["offset"])
		if door_props.has("n_offset"):
			set_door_n_offset(door_props["n_offset"])
		if door_props.has("z_offset"):
			set_door_z_offset(door_props["z_offset"])
		if door_props.has("width"):
			set_door_width(door_props["width"])
		if door_props.has("length"):
			set_door_length(door_props["length"])
		if door_props.has("height"):
			door_height = door_props["height"]
		if door_props.has("sill"):
			door_sill = door_props["sill"]
	
	if data.has("room_name"):
		room_name = data["room_name"]
	if data.has("central_color"):
		var color_data = data["central_color"]
		if color_data is Color:
			central_color = color_data
		elif color_data is Dictionary and color_data.has("r") and color_data.has("g") and color_data.has("b"):
			central_color = Color(color_data.r, color_data.g, color_data.b, color_data.get("a", 1.0))
		elif color_data is String:
			# Try to parse hex color or named color
			central_color = Color(color_data) if color_data != "" else Color.WHITE
	if data.has("position"):
		var pos_data = data["position"]
		if pos_data is Vector2:
			position = pos_data
		elif pos_data is Dictionary and pos_data.has("x") and pos_data.has("y"):
			position = Vector2(pos_data.x, pos_data.y)
		elif pos_data is String:
			# Try to parse string representation like "(x, y)"
			var pos_str = pos_data.strip_edges().replace("(", "").replace(")", "")
			var coords = pos_str.split(",")
			if coords.size() == 2:
				position = Vector2(coords[0].to_float(), coords[1].to_float())
	
	# Suport pentru formatul vechi (proprietăți directe în dicționarul principal)
	# Acestea se aplică doar dacă nu există sub-dicționarele window/door
	if not data.has("window"):
		if data.has("has_window"):
			set_has_window(data["has_window"])
		if data.has("window_style"):
			set_window_style(data["window_style"])
		if data.has("window_side"):
			set_window_side(data["window_side"])
		if data.has("window_offset"):
			set_window_offset(data["window_offset"])
		if data.has("window_n_offset"):
			set_window_n_offset(data["window_n_offset"])
		if data.has("window_z_offset"):
			set_window_z_offset(data["window_z_offset"])
		if data.has("window_width"):
			set_window_width(data["window_width"])
		if data.has("window_length"):
			set_window_length(data["window_length"])
		if data.has("window_height"):
			window_height = data["window_height"]
		if data.has("window_sill"):
			window_sill = data["window_sill"]
	
	if not data.has("door"):
		if data.has("has_door"):
			set_has_door(data["has_door"])
		if data.has("door_style"):
			set_door_style(data["door_style"])
		if data.has("door_side"):
			set_door_side(data["door_side"])
		if data.has("door_offset"):
			set_door_offset(data["door_offset"])
		if data.has("door_n_offset"):
			set_door_n_offset(data["door_n_offset"])
		if data.has("door_z_offset"):
			set_door_z_offset(data["door_z_offset"])
		if data.has("door_width"):
			set_door_width(data["door_width"])
		if data.has("door_length"):
			set_door_length(data["door_length"])
		if data.has("door_height"):
			door_height = data["door_height"]
		if data.has("door_sill"):
			door_sill = data["door_sill"]
	
	# Notă: Geometria se recalculează automat când shape-ul se actualizează
	queue_redraw()

func _setup_controllers():
	# Inițializează controllerele
	window_controller = WindowDoorController.new(WindowDoorController.ElementType.WINDOW)
	door_controller = WindowDoorController.new(WindowDoorController.ElementType.DOOR)
	
	# Sincronizează valorile inițiale
	_sync_window_controller()
	_sync_door_controller()

func _draw():
	# Desenează forma umplută
	if base_vertices.size() > 2:
		# Fill forma (central_color)
		var fill_color = central_color
		if is_selected:
			fill_color = Color(1.0, 1.0, 0.8, 0.7)
		draw_colored_polygon(PackedVector2Array(base_vertices), fill_color)
		# Adaugă label cu numele formei în centru
		var font = ThemeDB.fallback_font
		var center = Vector2(0, 0)
		for v in base_vertices:
			center += v
		center /= base_vertices.size()
		var text = room_name
		var text_size = font.get_string_size(text)
		var text_pos = center - text_size / 2
		draw_string(font, text_pos, text, HORIZONTAL_ALIGNMENT_CENTER, -1, 18, Color.WHITE)
		
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
	
	# Desenează feroneriile și ușile
	_draw_windows_and_doors()
	
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

func _draw_windows_and_doors():
	if base_vertices.size() < 4:
		return
	var font = ThemeDB.fallback_font
	# Desenează fereastra
	if window_controller and window_controller.has_element:
		var window_vertices = window_controller.generate_element_vertices(base_vertices)
		if window_vertices.size() > 0:
			# Fill fereastră (albastru deschis)
			draw_colored_polygon(PackedVector2Array(window_vertices), Color(0.6, 0.8, 1.0, 0.8))
			# Contur fereastră
			draw_polyline(window_vertices + [window_vertices[0]], Color.BLUE, 3.0)
			
			# Adaugă text indicator
			var window_pos = window_controller.calculate_position_on_rectangle(base_vertices)
			if not window_pos.is_empty():
				draw_string(font, window_pos.position - Vector2(15, -5), "W", HORIZONTAL_ALIGNMENT_CENTER, -1, 12, Color.DARK_BLUE)
	
	# Desenează ușa
	if door_controller and door_controller.has_element:
		var door_vertices = door_controller.generate_element_vertices(base_vertices)
		if door_vertices.size() > 0:
			# Fill ușă (maro)
			draw_colored_polygon(PackedVector2Array(door_vertices), Color(0.6, 0.4, 0.2, 0.8))
			# Contur ușă
			draw_polyline(door_vertices + [door_vertices[0]], Color(0.4, 0.2, 0.1), 3.0)
			
			# Adaugă text indicator
			var door_pos = door_controller.calculate_position_on_rectangle(base_vertices)
			if not door_pos.is_empty():
				draw_string(font, door_pos.position - Vector2(8, -5), "D", HORIZONTAL_ALIGNMENT_CENTER, -1, 12, Color(0.4, 0.2, 0.1))

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
	# Permite selecția și mutarea formei indiferent de move mode
		
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
		if is_whole_shape_dragging:
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

# Setters pentru feronerie
func set_has_window(value: bool):
	has_window = value
	if window_controller:
		window_controller.has_element = value
	queue_redraw()

func set_window_style(value: String):
	window_style = value
	if window_controller:
		window_controller.style = value
	queue_redraw()

func set_window_side(value: int):
	if value in [0, 90, 180, 270]:
		window_side = value
		if window_controller:
			window_controller.side_angle = value
		queue_redraw()

func set_window_offset(value: float):
	window_offset = value
	if window_controller:
		window_controller.offset = value
	queue_redraw()

func set_window_n_offset(value: float):
	window_n_offset = value

func set_window_z_offset(value: float):
	window_z_offset = value

func set_window_width(value: float):
	window_width = max(10.0, value)
	if window_controller:
		window_controller.width = window_width
	queue_redraw()

func set_window_length(value: float):
	window_length = max(10.0, value)
	if window_controller:
		window_controller.length = window_length
	queue_redraw()

# Setters pentru uși
func set_has_door(value: bool):
	has_door = value
	if door_controller:
		door_controller.has_element = value
	queue_redraw()

func set_door_style(value: String):
	door_style = value
	if door_controller:
		door_controller.style = value
	queue_redraw()

func set_door_side(value: int):
	if value in [0, 90, 180, 270]:
		door_side = value
		if door_controller:
			door_controller.side_angle = value
		queue_redraw()

func set_door_offset(value: float):
	door_offset = value
	if door_controller:
		door_controller.offset = value
	queue_redraw()

func set_door_n_offset(value: float):
	door_n_offset = value

func set_door_z_offset(value: float):
	door_z_offset = value

func set_door_width(value: float):
	door_width = max(10.0, value)
	if door_controller:
		door_controller.width = door_width
	queue_redraw()

func set_door_length(value: float):
	door_length = max(10.0, value)
	if door_controller:
		door_controller.length = door_length
	queue_redraw()

func _sync_window_controller():
	if not window_controller:
		return
	window_controller.has_element = has_window
	window_controller.style = window_style
	window_controller.side_angle = window_side
	window_controller.offset = window_offset
	window_controller.width = window_width
	window_controller.length = window_length

func _sync_door_controller():
	if not door_controller:
		return
	door_controller.has_element = has_door
	door_controller.style = door_style
	door_controller.side_angle = door_side
	door_controller.offset = door_offset
	door_controller.width = door_width
	door_controller.length = door_length

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

# Funcții helper pentru validare
func validate_window_parameters() -> Array[String]:
	if window_controller:
		return window_controller.validate_parameters()
	return []

func validate_door_parameters() -> Array[String]:
	if door_controller:
		return door_controller.validate_parameters()
	return []

func get_window_style_options() -> Array[String]:
	if window_controller:
		return window_controller.get_style_options()
	return []

func get_door_style_options() -> Array[String]:
	if door_controller:
		return door_controller.get_style_options()
	return []

# ===== CALCUL GEOMETRIC - ARIA ȘI PERIMETRUL =====

func calculate_area() -> float:
	"""Calculează aria formei folosind algoritmul Shoelace (Gauss) - în metri pătrați"""
	if base_vertices.size() < 3:
		return 0.0
	
	var area = 0.0
	var n = base_vertices.size()
	
	for i in range(n):
		var j = (i + 1) % n
		area += base_vertices[i].x * base_vertices[j].y
		area -= base_vertices[j].x * base_vertices[i].y
	
	# Convertește din px² în m² (împarte la 10000)
	return abs(area) / 2.0 / 10000.0

func calculate_perimeter() -> float:
	"""Calculează perimetrul formei - în metri"""
	if base_vertices.size() < 2:
		return 0.0
	
	var perimeter = 0.0
	var n = base_vertices.size()
	
	for i in range(n):
		var j = (i + 1) % n
		perimeter += base_vertices[i].distance_to(base_vertices[j])
	
	# Convertește din px în m (împarte la 100)
	return perimeter / 100.0

func calculate_interior_area() -> float:
	"""Calculează aria interioară (cu offset-ul) - în metri pătrați"""
	if offset_vertices.size() < 3:
		return 0.0
	
	var area = 0.0
	var n = offset_vertices.size()
	
	for i in range(n):
		var j = (i + 1) % n
		area += offset_vertices[i].x * offset_vertices[j].y
		area -= offset_vertices[j].x * offset_vertices[i].y
	
	# Convertește din px² în m² (împarte la 10000)
	return abs(area) / 2.0 / 10000.0

func calculate_interior_perimeter() -> float:
	"""Calculează perimetrul interior (cu offset-ul) - în metri"""
	if offset_vertices.size() < 2:
		return 0.0
	
	var perimeter = 0.0
	var n = offset_vertices.size()
	
	for i in range(n):
		var j = (i + 1) % n
		perimeter += offset_vertices[i].distance_to(offset_vertices[j])
	
	# Convertește din px în m (împarte la 100)
	return perimeter / 100.0

func calculate_wall_area() -> float:
	"""Calculează aria pereților (diferența dintre exterior și interior)"""
	return calculate_area() - calculate_interior_area()

func get_geometry_info() -> Dictionary:
	"""Returnează toate informațiile geometrice calculate în metri"""
	# Calculează aria ferestrelor și ușilor în m²
	var total_window_area = 0.0
	var total_door_area = 0.0
	
	# Calculează aria ferestrei dacă există
	if has_window and window_controller:
		var window_area_px2 = window_controller.width * window_controller.length
		total_window_area = window_area_px2 / 10000.0  # Conversie din px² în m²
	
	# Calculează aria ușii dacă există
	if has_door and door_controller:
		var door_area_px2 = door_controller.width * door_controller.length
		total_door_area = door_area_px2 / 10000.0  # Conversie din px² în m²
	
	# Calculează aria camerei: perimetru * înălțime - arii ferestre/uși
	var perimeter_m = calculate_perimeter()
	var room_area = perimeter_m * (extrusion_height / 100.0)  # extrusion_height în metri
	room_area -= (total_window_area + total_door_area)
	
	var result = {
		"exterior_area": calculate_area(),
		"exterior_perimeter": perimeter_m,
		"interior_area": calculate_interior_area(), 
		"interior_perimeter": calculate_interior_perimeter(),
		"room_area": room_area,
		"area_unit": "m²",
		"perimeter_unit": "m"
	}
	
	if total_window_area > 0:
		result["window_area"] = total_window_area
	if total_door_area > 0:
		result["door_area"] = total_door_area
	
	return result
