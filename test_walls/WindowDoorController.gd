extends ResourcePreloader
class_name WindowDoorController

# Tipuri de elemente
enum ElementType {
	WINDOW,
	DOOR
}

# Stiluri disponibile
enum WindowStyle {
	STANDARD,
	SLIDING,
	CASEMENT,
	BAY
}

enum DoorStyle {
	STANDARD,
	SLIDING,
	DOUBLE,
	FRENCH
}

# Clasa pentru definirea unui element (ușă sau fereastră)
@export var element_type: ElementType = ElementType.WINDOW
@export var has_element: bool = true
@export var style: String = "standard"
@export var side_angle: int = 0  # 0, 90, 180, 270 grade
@export var offset: float = 0.0  # offset lateral de la centrul laturii
@export var h_offset: float = 90.0  # offset vertical (90 pentru ferestre, 0 pentru uși)
@export var width: float = 100.0  # lățimea elementului
@export var length: float = 150.0  # înălțimea elementului

func _init(type: ElementType = ElementType.WINDOW):
	element_type = type
	if type == ElementType.DOOR:
		h_offset = 0.0
		length = 90.0
	else:
		h_offset = 0.0
		length = 120.0

func get_style_options() -> Array[String]:
	if element_type == ElementType.WINDOW:
		return ["standard", "sliding", "casement", "bay"]
	else:
		return ["standard", "sliding", "double", "french"]

func get_valid_angles() -> Array[int]:
	return [0, 90, 180, 270]

func is_angle_valid(angle: int) -> bool:
	return angle in get_valid_angles()

# Calculează poziția și orientarea elementului pe latura specificată
func calculate_position_on_rectangle(rect_vertices: Array[Vector2]) -> Dictionary:
	if rect_vertices.size() != 4 or not has_element:
		return {}
	
	# Determină latura bazată pe unghi
	var side_index = _get_side_index_from_angle(side_angle)
	if side_index < 0:
		return {}
	
	# Obține punctele laturii
	var start_point = rect_vertices[side_index]
	var end_point = rect_vertices[(side_index + 1) % 4]
	
	# Calculează centrul laturii
	var side_center = (start_point + end_point) * 0.5
	
	# Calculează direcția laturii și normala
	var side_direction = (end_point - start_point).normalized()
	var side_normal = Vector2(-side_direction.y, side_direction.x)  # Normal către interior
	
	# Aplică offset lateral
	var element_center = side_center + side_direction * offset
	
	# Aplică offset vertical (normal la latură)
	element_center += side_normal * h_offset
	
	# Calculează rotația elementului (perpendicular pe latură)
	var element_rotation = atan2(side_direction.y, side_direction.x) + PI/2
	
	return {
		"position": element_center,
		"rotation": element_rotation,
		"side_direction": side_direction,
		"side_normal": side_normal,
		"side_index": side_index
	}

func _get_side_index_from_angle(angle: int) -> int:
	# Mapează unghiul la indicele laturii
	# 0° = latura de jos (0->1), 90° = latura din dreapta (1->2), 
	# 180° = latura de sus (2->3), 270° = latura din stânga (3->0)
	match angle:
		0: return 0    # Jos
		90: return 1   # Dreapta  
		180: return 2  # Sus
		270: return 3  # Stânga
		_: return -1

# Generează vertices pentru elementul (ușă/fereastră) pentru desenare
func generate_element_vertices(rect_vertices: Array[Vector2]) -> Array[Vector2]:
	var pos_data = calculate_position_on_rectangle(rect_vertices)
	if pos_data.is_empty():
		return []
	
	var center = pos_data.position as Vector2
	var rotation = pos_data.rotation as float
	
	# Creează vertices locale pentru element
	var half_width = width * 0.5
	var half_length = length * 0.5
	
	var local_vertices = [
		Vector2(-half_width, -half_length),
		Vector2(half_width, -half_length),
		Vector2(half_width, half_length),
		Vector2(-half_width, half_length)
	]
	
	# Rotește și translatează vertices
	var transformed_vertices: Array[Vector2] = []
	for vertex in local_vertices:
		var rotated = Vector2(
			vertex.x * cos(rotation) - vertex.y * sin(rotation),
			vertex.x * sin(rotation) + vertex.y * cos(rotation)
		)
		transformed_vertices.append(center + rotated)
	
	return transformed_vertices

# Validează parametrii
func validate_parameters() -> Array[String]:
	var errors: Array[String] = []
	
	if not is_angle_valid(side_angle):
		errors.append("Unghiul trebuie să fie 0, 90, 180 sau 270 grade")
	
	if width <= 0:
		errors.append("Lățimea trebuie să fie mai mare ca 0")
	
	if length <= 0:
		errors.append("Lungimea trebuie să fie mai mare ca 0")
	
	if not (style in get_style_options()):
		errors.append("Stil invalid pentru tipul de element selectat")
	
	return errors
