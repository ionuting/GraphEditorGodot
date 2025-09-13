# PolygonDrawer2D.gd
# Clasă pentru desenarea poligoanalor în sistemul CAD 2D
class_name PolygonDrawer2D

extends RefCounted

# Proprietăți poligon
var points: Array[Vector2] = []
var offset_points: Array[Vector2] = []
var is_closed: bool = false
var exterior_offset: float = 0.25
var extrusion_height: float = 250.0
var unique_id: String = ""
var is_selected: bool = false

# Configurare desenare
var snap_distance: float = 20.0
var double_click_threshold_ms: int = 300
var last_click_time_ms: int = 0

# Culori
const POLYGON_COLOR = Color(0.0, 1.0, 0.0, 0.3)  # verde semi-transparent
const POLYGON_OUTLINE_COLOR = Color.GREEN
const OFFSET_POLYGON_COLOR = Color(0.0, 1.0, 1.0, 0.3)  # cyan semi-transparent
const OFFSET_OUTLINE_COLOR = Color.CYAN
const POINT_COLOR = Color.YELLOW
const FIRST_POINT_COLOR = Color.RED
const LAST_POINT_COLOR = Color.ORANGE
const SELECTED_COLOR = Color(1.0, 0.7, 0.0, 0.5)  # portocaliu pentru selecție

func _init():
	if unique_id == "":
		unique_id = str(randi())

# Adaugă un punct la poligon
func add_point(world_pos: Vector2) -> bool:
	if is_closed:
		return false
		
	var current_time_ms = Time.get_ticks_msec()
	var time_since_last_ms = current_time_ms - last_click_time_ms
	
	# Verifică double-click sau click aproape de primul punct pentru închidere
	if points.size() > 2:
		if (time_since_last_ms < double_click_threshold_ms) or (world_pos.distance_to(points[0]) < 0.5):
			# Închide poligonul
			is_closed = true
			_update_offset()
			return true
	
	points.append(world_pos)
	_update_offset()
	last_click_time_ms = current_time_ms
	return false

# Închide forțat poligonul
func close_polygon():
	if points.size() > 2 and not is_closed:
		is_closed = true
		_update_offset()

# Verifică dacă un punct este în interiorul poligonului
func contains_point(world_pos: Vector2) -> bool:
	if points.size() < 3 or not is_closed:
		return false
	
	var inside = false
	var j = points.size() - 1
	
	for i in range(points.size()):
		if ((points[i].y > world_pos.y) != (points[j].y > world_pos.y)) and \
		   (world_pos.x < points[i].x + (points[j].x - points[i].x) * (world_pos.y - points[i].y) / (points[j].y - points[i].y)):
			inside = not inside
		j = i
	
	return inside

# Mută poligonul la o nouă poziție
func move_to(new_center: Vector2):
	if points.is_empty():
		return
		
	var current_center = get_center()
	var delta = new_center - current_center
	
	for i in range(points.size()):
		points[i] += delta
	
	_update_offset()

# Obține centrul poligonului
func get_center() -> Vector2:
	if points.is_empty():
		return Vector2.ZERO
		
	var center = Vector2.ZERO
	for point in points:
		center += point
	return center / points.size()

# Obține toate punctele de control (puncte originale + mijlocuri + centru)
func get_control_points() -> Array[Vector2]:
	var control_points: Array[Vector2] = []
	
	if not is_closed or points.size() < 3:
		return control_points
	
	# Adaugă punctele originale
	for point in points:
		control_points.append(point)
	
	# Adaugă punctele de mijloc ale liniilor
	for i in range(points.size()):
		var current = points[i]
		var next = points[(i + 1) % points.size()]
		var midpoint = (current + next) * 0.5
		control_points.append(midpoint)
	
	# Adaugă centrul poligonului
	control_points.append(get_center())
	
	return control_points

# Obține toate punctele de pe poliliniile poligonului pentru snap
func get_all_line_points(step_size: float = 0.125) -> Array[Vector2]:
	var line_points: Array[Vector2] = []
	
	if points.size() < 2:
		return line_points
	
	# Procesează fiecare linie a poligonului
	for i in range(points.size()):
		if not is_closed and i == points.size() - 1:
			continue  # Pentru poligoane deschise, nu procesează ultima linie inexistentă
		
		var current = points[i]
		var next = points[(i + 1) % points.size()]
		
		# Adaugă punctul curent
		line_points.append(current)
		
		# Adaugă puncte intermediare pe linie
		var line_vector = next - current
		var line_length = line_vector.length()
		
		if line_length > step_size:
			var steps = int(line_length / step_size)
			for step in range(1, steps):  # Nu include capetele (deja adăugate)
				var t = float(step) / float(steps)
				var point_on_line = current + line_vector * t
				line_points.append(point_on_line)
	
	return line_points

# Verifică dacă un punct este aproape de un punct de control
func get_control_point_at_position(world_pos: Vector2, tolerance: float = 0.1) -> Vector2:
	var control_points = get_control_points()
	
	for control_point in control_points:
		if world_pos.distance_to(control_point) <= tolerance:
			return control_point
	
	return Vector2.ZERO  # Returnează Vector2.ZERO dacă nu găsește nimic

# Obține boundingbox-ul poligonului
func get_bounds() -> Rect2:
	if points.is_empty():
		return Rect2()
		
	var min_pos = points[0]
	var max_pos = points[0]
	
	for point in points:
		min_pos = min_pos.min(point)
		max_pos = max_pos.max(point)
	
	return Rect2(min_pos, max_pos - min_pos)

# Curăță poligonul
func clear():
	points.clear()
	offset_points.clear()
	is_closed = false

# Actualizează punctele offsetate
func _update_offset():
	if points.size() > 2 and is_closed:
		offset_points = _apply_exterior_offset(points, exterior_offset)
	else:
		offset_points.clear()

# Aplică offset exterior poligonului
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

# Funcții pentru salvare/încărcare
func to_dict() -> Dictionary:
	var data = {
		"type": "polygon",
		"unique_id": unique_id,
		"points": _vector2_array_to_dict(points),
		"offset_points": _vector2_array_to_dict(offset_points),
		"is_closed": is_closed,
		"exterior_offset": exterior_offset,
		"extrusion_height": extrusion_height,
		"is_selected": is_selected
	}
	return data

func from_dict(data: Dictionary) -> void:
	if data.has("unique_id"):
		unique_id = data.unique_id
	
	if data.has("points") and data.points is Array:
		points = _dict_to_vector2_array(data.points)
	
	if data.has("is_closed"):
		is_closed = data.is_closed
	
	if data.has("exterior_offset"):
		exterior_offset = data.exterior_offset
	
	if data.has("extrusion_height"):
		extrusion_height = data.extrusion_height
	
	if data.has("is_selected"):
		is_selected = data.is_selected
	
	# Încărcăm offset_points direct dacă există
	if data.has("offset_points") and data.offset_points is Array:
		offset_points = _dict_to_vector2_array(data.offset_points)
	else:
		# Dacă nu există, le calculăm
		_update_offset()

# Ajutor pentru conversia Vector2[] la Array de dicționare
func _vector2_array_to_dict(vec_array: Array[Vector2]) -> Array:
	var result = []
	for vec in vec_array:
		result.append({"x": vec.x, "y": vec.y})
	return result

# Ajutor pentru conversia Array de dicționare la Vector2[]
func _dict_to_vector2_array(dict_array: Array) -> Array[Vector2]:
	var result: Array[Vector2] = []
	for dict in dict_array:
		if dict is Dictionary and dict.has("x") and dict.has("y"):
			result.append(Vector2(dict.x, dict.y))
	return result