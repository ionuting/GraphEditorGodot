# RectangleCell.gd
# Clasă pentru dreptunghiuri configurabile cu offset și proprietăți extinse
class_name RectangleCell

extends RefCounted

# Proprietăți configurabile
var cell_name: String = "Cell_001"
var cell_type: String = "Standard"
var cell_index: int = 1

# Dimensiuni configurabile
var width: float = 1.0
var height: float = 1.0

# Offset simetric (pozitiv=interior, negativ=exterior)
var offset: float = 0.0

# Extended properties for ArchiCAD-like panel
var height_3d: float = 0.0 # extrude height for 3D
var sill: float = 0.0
var translation_x: float = 0.0
var translation_y: float = 0.0
var cut_priority: int = 0
var material: String = ""
var is_exterior: bool = false

# Poziție și stare
var position: Vector2 = Vector2.ZERO
var is_selected: bool = false

# ID unic pentru identificare
var unique_id: String = ""

func _init(pos: Vector2 = Vector2.ZERO, w: float = 1.0, h: float = 1.0):
	position = pos
	width = w
	height = h
	unique_id = generate_unique_id()

# Generează un ID unic
func generate_unique_id() -> String:
	return "cell_" + str(Time.get_ticks_msec()) + "_" + str(randi() % 1000)

# Obține dreptunghiul principal
func get_main_rectangle() -> Rect2:
	return Rect2(position - Vector2(width/2, height/2), Vector2(width, height))

# Obține dreptunghiul cu offset
func get_offset_rectangle() -> Rect2:
	var off = round(offset * 1000) / 1000.0
	# Prevent negative or zero sizes by clamping to a small positive epsilon
	var new_width = max(0.001, width - 2.0 * off)
	var new_height = max(0.001, height - 2.0 * off)
	var center = position
	return Rect2(center - Vector2(new_width * 0.5, new_height * 0.5), Vector2(new_width, new_height))

# Verifică dacă un punct este în interiorul cell-ului (oricare dintre dreptunghiuri)
func contains_point(point: Vector2) -> bool:
	return get_main_rectangle().has_point(point) or get_offset_rectangle().has_point(point)

# Obține punctele grip pentru dreptunghiul principal
func get_main_grip_points() -> Dictionary:
	var rect = get_main_rectangle()
	var center = rect.get_center()
	
	return {
		Rectangle2D.GripPoint.TOP_LEFT: rect.position,
		Rectangle2D.GripPoint.TOP_CENTER: Vector2(center.x, rect.position.y),
		Rectangle2D.GripPoint.TOP_RIGHT: Vector2(rect.position.x + rect.size.x, rect.position.y),
		Rectangle2D.GripPoint.CENTER_LEFT: Vector2(rect.position.x, center.y),
		Rectangle2D.GripPoint.CENTER: center,
		Rectangle2D.GripPoint.CENTER_RIGHT: Vector2(rect.position.x + rect.size.x, center.y),
		Rectangle2D.GripPoint.BOTTOM_LEFT: Vector2(rect.position.x, rect.position.y + rect.size.y),
		Rectangle2D.GripPoint.BOTTOM_CENTER: Vector2(center.x, rect.position.y + rect.size.y),
		Rectangle2D.GripPoint.BOTTOM_RIGHT: rect.position + rect.size
	}

# Obține punctele grip pentru dreptunghiul cu offset
func get_offset_grip_points() -> Dictionary:
	var rect = get_offset_rectangle()
	var center = rect.get_center()
	
	return {
		Rectangle2D.GripPoint.TOP_LEFT: rect.position,
		Rectangle2D.GripPoint.TOP_CENTER: Vector2(center.x, rect.position.y),
		Rectangle2D.GripPoint.TOP_RIGHT: Vector2(rect.position.x + rect.size.x, rect.position.y),
		Rectangle2D.GripPoint.CENTER_LEFT: Vector2(rect.position.x, center.y),
		Rectangle2D.GripPoint.CENTER: center,
		Rectangle2D.GripPoint.CENTER_RIGHT: Vector2(rect.position.x + rect.size.x, center.y),
		Rectangle2D.GripPoint.BOTTOM_LEFT: Vector2(rect.position.x, rect.position.y + rect.size.y),
		Rectangle2D.GripPoint.BOTTOM_CENTER: Vector2(center.x, rect.position.y + rect.size.y),
		Rectangle2D.GripPoint.BOTTOM_RIGHT: rect.position + rect.size
	}

# Obține toate punctele grip (pentru snap)
func get_all_grip_points() -> Array[Vector2]:
	var points: Array[Vector2] = []
	
	# Puncte din dreptunghiul principal
	for grip_point in get_main_grip_points().values():
		points.append(grip_point)
	
	# Puncte din dreptunghiul cu offset
	for grip_point in get_offset_grip_points().values():
		points.append(grip_point)
	
	return points

# Mută cell-ul la o nouă poziție
func move_to(new_position: Vector2):
	position = new_position

# Actualizează dimensiunile
func set_dimensions(new_width: float, new_height: float):
	width = max(0.1, new_width)  # Dimensiune minimă
	height = max(0.1, new_height)

# Actualizează offset-ul
func set_offset(new_offset: float):
	# Store rounded offset. Do not automatically clamp here to half-dimensions
	# to allow the UI to present values; callers may clamp prior to rendering as needed.
	# We still normalize precision to avoid floating noise.
	offset = round(new_offset * 1000) / 1000.0

# Actualizează proprietățile
func set_properties(name: String, type: String, index: int):
	cell_name = name
	cell_type = type
	cell_index = index
	# Note: extended properties can be set via explicit setters or from_dict methods

# Obține informații complete despre cell
func get_info() -> Dictionary:
	return {
		"unique_id": unique_id,
		"name": cell_name,
		"type": cell_type,
		"index": cell_index,
		"position": position,
		"dimensions": Vector2(width, height),
		"offset": offset,
		"is_selected": is_selected
	}

# Convertește la string pentru debugging
func _to_string() -> String:
	return "RectangleCell[%s]: %s (%.2fx%.2f) at (%.2f,%.2f) offset(%.3f)" % [
		unique_id, cell_name, width, height, position.x, position.y, offset
	]
