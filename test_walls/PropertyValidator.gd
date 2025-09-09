extends RefCounted
class_name PropertyValidator

# Validatorul pentru proprietăți ale formelor și elementelor acestora

static func validate_angle(angle: int) -> bool:
	return angle in [0, 90, 180, 270]

static func validate_positive_float(value: float, min_value: float = 0.0) -> bool:
	return value >= min_value

static func validate_dimensions(size: Vector2, min_size: Vector2 = Vector2(10, 10)) -> bool:
	return size.x >= min_size.x and size.y >= min_size.y

static func validate_offset_range(offset: float, max_range: float = 1000.0) -> bool:
	return abs(offset) <= max_range

static func validate_window_parameters(window_controller: WindowDoorController, shape_size: Vector2) -> Dictionary:
	var result = {
		"is_valid": true,
		"warnings": [],
		"errors": []
	}
	
	if not window_controller or not window_controller.has_element:
		return result
	
	# Verifică dimensiunile ferestrei versus forma
	if window_controller.width > shape_size.x * 0.8:
		result.warnings.append("Fereastra este prea lată față de formă")
	
	if window_controller.height > shape_size.y * 0.8:
		result.warnings.append("Fereastra este prea înaltă față de formă")
	
	# Verifică dacă offset-ul lateral nu scoate fereastra din formă
	var half_width = window_controller.width * 0.5
	var side_length = _get_side_length_for_angle(window_controller.side_angle, shape_size)
	var max_offset = (side_length * 0.5) - half_width
	
	if abs(window_controller.offset) > max_offset:
		result.errors.append("Offset-ul lateral scoate fereastra în afara formei")
		result.is_valid = false
	
	# Verifică poziționarea pe latura corectă
	if not validate_angle(window_controller.side_angle):
		result.errors.append("Unghiul trebuie să fie 0, 90, 180 sau 270 grade")
		result.is_valid = false
	
	return result

static func validate_door_parameters(door_controller: WindowDoorController, shape_size: Vector2) -> Dictionary:
	var result = {
		"is_valid": true,
		"warnings": [],
		"errors": []
	}
	
	if not door_controller or not door_controller.has_element:
		return result
	
	# Verifică dimensiunile ușii versus forma
	if door_controller.width > shape_size.x * 0.9:
		result.warnings.append("Ușa este prea lată față de formă")
	
	if door_controller.height > shape_size.y:
		result.errors.append("Ușa este prea înaltă pentru formă")
		result.is_valid = false
	
	# Verifică dacă offset-ul lateral nu scoate ușa din formă
	var half_width = door_controller.width * 0.5
	var side_length = _get_side_length_for_angle(door_controller.side_angle, shape_size)
	var max_offset = (side_length * 0.5) - half_width
	
	if abs(door_controller.offset) > max_offset:
		result.errors.append("Offset-ul lateral scoate ușa în afara formei")
		result.is_valid = false
	
	# Pentru uși, h_offset trebuie să permită ușii să ajungă la "podea"
	if door_controller.h_offset > 0:
		result.warnings.append("Ușile de obicei au h_offset = 0 pentru a ajunge la podea")
	
	# Verifică poziționarea pe latura corectă
	if not validate_angle(door_controller.side_angle):
		result.errors.append("Unghiul trebuie să fie 0, 90, 180 sau 270 grade")
		result.is_valid = false
	
	return result

static func _get_side_length_for_angle(angle: int, shape_size: Vector2) -> float:
	match angle:
		0, 180: # Jos/Sus
			return shape_size.x
		90, 270: # Dreapta/Stânga
			return shape_size.y
		_:
			return 0.0

static func validate_element_overlap(window_controller: WindowDoorController, door_controller: WindowDoorController, shape_size: Vector2) -> Dictionary:
	var result = {
		"is_valid": true,
		"warnings": [],
		"errors": []
	}
	
	# Verifică doar dacă ambele elemente există și sunt pe aceeași latură
	if not (window_controller and window_controller.has_element and door_controller and door_controller.has_element):
		return result
	
	if window_controller.side_angle != door_controller.side_angle:
		return result  # Pe laturi diferite, nu se suprapun
	
	# Calculează pozițiile pe latură
	var window_start = window_controller.offset - (window_controller.width * 0.5)
	var window_end = window_controller.offset + (window_controller.width * 0.5)
	var door_start = door_controller.offset - (door_controller.width * 0.5)
	var door_end = door_controller.offset + (door_controller.width * 0.5)
	
	# Verifică suprapunerea
	var overlap = not (window_end < door_start or door_end < window_start)
	
	if overlap:
		result.warnings.append("Fereastra și ușa se suprapun pe aceeași latură")
	
	# Verifică și suprapunerea verticală (h_offset)
	if overlap:
		var window_v_start = window_controller.h_offset - (window_controller.height * 0.5)
		var window_v_end = window_controller.h_offset + (window_controller.height * 0.5)
		var door_v_start = door_controller.h_offset
		var door_v_end = door_controller.h_offset + door_controller.height
		
		var v_overlap = not (window_v_end < door_v_start or door_v_end < window_v_start)
		
		if v_overlap:
			result.errors.append("Fereastra și ușa se suprapun complet")
			result.is_valid = false
	
	return result

static func validate_element_within_bounds(controller: WindowDoorController, shape_size: Vector2) -> Dictionary:
	var result = {
		"is_valid": true,
		"warnings": [],
		"errors": []
	}
	
	if not controller or not controller.has_element:
		return result
	
	var side_length = _get_side_length_for_angle(controller.side_angle, shape_size)
	var half_width = controller.width * 0.5
	
	# Verifică limitele laterale
	var min_pos = controller.offset - half_width
	var max_pos = controller.offset + half_width
	var side_half_length = side_length * 0.5
	
	if min_pos < -side_half_length:
		result.errors.append("Elementul depășește marginea stângă a laturii")
		result.is_valid = false
	
	if max_pos > side_half_length:
		result.errors.append("Elementul depășește marginea dreaptă a laturii")
		result.is_valid = false
	
	# Pentru offset vertical, verifică limitele în funcție de tipul elementului
	if controller.element_type == WindowDoorController.ElementType.DOOR:
		# Ușile ar trebui să ajungă la "podea" (h_offset = 0)
		if controller.h_offset < 0:
			result.warnings.append("Ușa este sub nivelul podelei")
		
		if controller.h_offset + controller.height > shape_size.y:
			result.errors.append("Ușa depășește înălțimea formei")
			result.is_valid = false
	else:
		# Ferestrele pot avea offset pozitiv sau negativ
		var window_bottom = controller.h_offset - (controller.height * 0.5)
		var window_top = controller.h_offset + (controller.height * 0.5)
		
		if window_bottom < 0:
			result.warnings.append("Fereastra coboară sub nivelul podelei")
		
		if window_top > shape_size.y:
			result.warnings.append("Fereastra depășește înălțimea formei")
	
	return result

static func get_recommended_values(element_type: WindowDoorController.ElementType, shape_size: Vector2) -> Dictionary:
	var recommendations = {}
	
	if element_type == WindowDoorController.ElementType.WINDOW:
		recommendations = {
			"width": min(shape_size.x * 0.3, 120.0),
			"height": min(shape_size.y * 0.4, 100.0),
			"h_offset": shape_size.y * 0.6,
			"offset": 0.0,
			"style": "standard"
		}
	else: # DOOR
		recommendations = {
			"width": min(shape_size.x * 0.25, 90.0),
			"height": min(shape_size.y * 0.9, 200.0),
			"h_offset": 0.0,
			"offset": 0.0,
			"style": "standard"
		}
	
	return recommendations

static func auto_adjust_conflicting_elements(window_controller: WindowDoorController, door_controller: WindowDoorController, shape_size: Vector2):
	# Ajustează automat elementele care intră în conflict
	if not (window_controller and window_controller.has_element and door_controller and door_controller.has_element):
		return
	
	# Dacă sunt pe aceeași latură și se suprapun
	if window_controller.side_angle == door_controller.side_angle:
		var overlap_check = validate_element_overlap(window_controller, door_controller, shape_size)
		
		if not overlap_check.is_valid:
			# Mută fereastra pe o latură diferită
			var available_sides = [0, 90, 180, 270]
			available_sides.erase(door_controller.side_angle)
			
			if available_sides.size() > 0:
				window_controller.side_angle = available_sides[0]
				print("Fereastra a fost mutată automat pe latura ", available_sides[0], "° pentru a evita suprapunerea cu ușa")

static func validate_all_parameters(shape: TetrisShape2D) -> Dictionary:
	var result = {
		"is_valid": true,
		"warnings": [],
		"errors": [],
		"window_validation": {},
		"door_validation": {},
		"overlap_validation": {}
	}
	
	if not shape:
		result.errors.append("Forma nu este validă")
		result.is_valid = false
		return result
	
	var shape_size = shape.get_current_dimensions()
	
	# Validează dimensiunile formei
	if not validate_dimensions(shape_size):
		result.errors.append("Dimensiunile formei sunt prea mici")
		result.is_valid = false
	
	# Validează fereastra
	if shape.window_controller:
		result.window_validation = validate_window_parameters(shape.window_controller, shape_size)
		if not result.window_validation.is_valid:
			result.is_valid = false
		result.errors.append_array(result.window_validation.errors)
		result.warnings.append_array(result.window_validation.warnings)
		
		# Validează limitele ferestrei
		var window_bounds = validate_element_within_bounds(shape.window_controller, shape_size)
		if not window_bounds.is_valid:
			result.is_valid = false
		result.errors.append_array(window_bounds.errors)
		result.warnings.append_array(window_bounds.warnings)
	
	# Validează ușa
	if shape.door_controller:
		result.door_validation = validate_door_parameters(shape.door_controller, shape_size)
		if not result.door_validation.is_valid:
			result.is_valid = false
		result.errors.append_array(result.door_validation.errors)
		result.warnings.append_array(result.door_validation.warnings)
		
		# Validează limitele ușii
		var door_bounds = validate_element_within_bounds(shape.door_controller, shape_size)
		if not door_bounds.is_valid:
			result.is_valid = false
		result.errors.append_array(door_bounds.errors)
		result.warnings.append_array(door_bounds.warnings)
	
	# Validează suprapunerea
	if shape.window_controller and shape.door_controller:
		result.overlap_validation = validate_element_overlap(shape.window_controller, shape.door_controller, shape_size)
		if not result.overlap_validation.is_valid:
			result.is_valid = false
		result.errors.append_array(result.overlap_validation.errors)
		result.warnings.append_array(result.overlap_validation.warnings)
	
	return result
