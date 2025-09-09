extends Node2D
class_name PolygonDrawer2D

@export var exterior_offset: float = 12.5 : set = set_exterior_offset
@export var extrusion_height: float = 250
@export var snap_distance: float = 20.0

var points: Array[Vector2] = []
var offset_points: Array[Vector2] = []
var is_drawing_enabled: bool = false
var is_polygon_closed: bool = false
var last_click_time_ms: int = 0
var double_click_threshold_ms: int = 300

signal polygon_changed

func _ready():
	queue_redraw()

func set_exterior_offset(value: float):
	exterior_offset = value
	_update_offset()
	queue_redraw()

func _unhandled_input(event):
	if not is_drawing_enabled:
		return
		
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			if is_polygon_closed:
				return  # Nu mai adăuga puncte dacă poligonul e închis
				
			var current_time_ms = Time.get_ticks_msec()
			var time_since_last_ms = current_time_ms - last_click_time_ms
			
			var mouse_pos = get_global_mouse_position()
			var snapped_pos = _try_snap_to_shapes(mouse_pos)
			var local_pos = to_local(snapped_pos)
			
			# Verifică double-click sau click aproape de primul punct pentru închidere
			if points.size() > 2:
				if (time_since_last_ms < double_click_threshold_ms) or (local_pos.distance_to(points[0]) < 15.0):
					# Închide poligonul
					is_polygon_closed = true
					_update_offset()
					queue_redraw()
					polygon_changed.emit()
					return
			
			points.append(local_pos)
			_update_offset()
			queue_redraw()
			last_click_time_ms = current_time_ms
			
		elif event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
			# Click dreapta pentru a închide poligonul
			if points.size() > 2 and not is_polygon_closed:
				is_polygon_closed = true
				_update_offset()
				queue_redraw()
				polygon_changed.emit()

func set_drawing_enabled(enabled: bool):
	is_drawing_enabled = enabled
	if not enabled:
		is_polygon_closed = false

func _draw():
	if points.size() > 1:
		# Desenează poligonul de bază (verde)
		if is_polygon_closed and points.size() > 2:
			# Poligon închis - desenează fill și contur complet
			draw_colored_polygon(PackedVector2Array(points), Color(0.0, 1.0, 0.0, 0.3))  # verde semi-transparent
			draw_polyline(points + [points[0]], Color.GREEN, 2.0)
		else:
			# Poligon în curs de desenare - doar linia
			draw_polyline(points, Color.GREEN, 2.0)
			# Linie de la ultimul punct la mouse pentru preview
			if is_drawing_enabled and points.size() > 0:
				var mouse_local = to_local(get_global_mouse_position())
				draw_line(points[-1], mouse_local, Color(0.0, 1.0, 0.0, 0.5), 1.0)
	
	if offset_points.size() > 2 and is_polygon_closed:
		# Desenează poligonul offsetat (cyan) doar când e închis
		draw_colored_polygon(PackedVector2Array(offset_points), Color(0.0, 1.0, 1.0, 0.3))  # cyan semi-transparent
		draw_polyline(offset_points + [offset_points[0]], Color.CYAN, 2.0)
	
	# Desenează punctele
	if is_drawing_enabled:
		for i in range(points.size()):
			var point = points[i]
			var color = Color.YELLOW
			var radius = 4.0
			
			if i == 0:
				# Primul punct - evidențiat și pulsează când poligonul poate fi închis
				color = Color.RED
				if points.size() > 2:
					# Pulsează pentru a indica că poate fi închis
					var pulse = sin(Time.get_ticks_msec() / 200.0) * 0.3 + 0.7
					color = Color(1.0, pulse, pulse)
					radius = 6.0
			elif i == points.size() - 1 and not is_polygon_closed:
				color = Color.ORANGE  # ultimul punct în portocaliu
			
			draw_circle(point, radius, color)
			draw_circle(point, radius, Color.WHITE, false, 1.0)  # contur alb
	
	# Desenează preview line de la ultimul punct la mouse
	if is_drawing_enabled and points.size() > 0 and not is_polygon_closed:
		var mouse_local = to_local(get_global_mouse_position())
		draw_line(points[-1], mouse_local, Color(0.0, 1.0, 0.0, 0.5), 2.0)

func _update_offset():
	if points.size() > 2:
		offset_points = _apply_exterior_offset(points, exterior_offset)

func _apply_exterior_offset(poly: Array[Vector2], offset: float) -> Array[Vector2]:
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
		
		# Calculează normalele (perpendiculare pe margini, înspre exterior)
		var normal1 = Vector2(-edge1.y, edge1.x)
		var normal2 = Vector2(-edge2.y, edge2.x)
		
		# Calculează direcția bisectoarei
		var bisector = (normal1 + normal2).normalized()
		
		# Tratează cazul degenerat
		if bisector.length_squared() < 0.001:
			bisector = normal1
		
		# Calculează distanța de offset
		var cos_half_angle = bisector.dot(normal1)
		if abs(cos_half_angle) > 0.001:
			var offset_distance = offset / cos_half_angle
			new_poly.append(curr + bisector * offset_distance)
		else:
			new_poly.append(curr + normal1 * offset)
	
	return new_poly

func _try_snap_to_shapes(mouse_pos: Vector2) -> Vector2:
	var shapes = get_tree().get_nodes_in_group("tetris_shapes")
	
	for shape in shapes:
		if shape.has_method("get_snap_points"):
			var snap_points = shape.get_snap_points()
			for snap_point in snap_points:
				if mouse_pos.distance_to(snap_point) < snap_distance:
					return snap_point
	
	return mouse_pos

func clear_polygon():
	points.clear()
	offset_points.clear()
	is_polygon_closed = false
	queue_redraw()

func get_offset_polygon_world() -> Array[Vector2]:
	var world_points: Array[Vector2] = []
	for point in offset_points:
		world_points.append(global_transform * point)
	return world_points

func get_offset_polygon() -> Array:
	return offset_points
