extends RefCounted
class_name AutoValidator

# Sistem de validare automată pentru forme TetrisShape2D

static var validation_enabled: bool = true
static var auto_fix_enabled: bool = false

signal validation_completed(results: Dictionary)
signal auto_fix_applied(shape: TetrisShape2D, fixes: Array[String])

static func validate_shape_realtime(shape: TetrisShape2D) -> Dictionary:
	"""Validare în timp real pentru o formă specifică"""
	if not validation_enabled or not shape:
		return {"is_valid": true, "warnings": [], "errors": []}
	
	var PropertyValidator = preload("res://PropertyValidator.gd")
	return PropertyValidator.validate_all_parameters(shape)

static func validate_all_shapes_in_manager(shape_manager: ShapeManager) -> Dictionary:
	"""Validare pentru toate formele din manager"""
	var results = {
		"total_validated": 0,
		"valid_shapes": 0,
		"invalid_shapes": 0,
		"total_warnings": 0,
		"total_errors": 0,
		"shape_results": {}
	}
	
	var shapes = shape_manager.get_all_shapes()
	
	for shape in shapes:
		var validation = validate_shape_realtime(shape)
		results.shape_results[shape.unique_id] = validation
		results.total_validated += 1
		
		if validation.is_valid:
			results.valid_shapes += 1
		else:
			results.invalid_shapes += 1
		
		results.total_warnings += validation.warnings.size()
		results.total_errors += validation.errors.size()
	
	return results

static func auto_fix_shape_issues(shape: TetrisShape2D) -> Array[String]:
	"""Tentativă de reparare automată a problemelor unei forme"""
	if not auto_fix_enabled or not shape:
		return []
	
	var applied_fixes: Array[String] = []
	var PropertyValidator = preload("res://PropertyValidator.gd")
	
	# Verifică dimensiunile minime
	var dimensions = shape.get_current_dimensions()
	var min_size = Vector2(50, 50)
	
	if dimensions.x < min_size.x:
		shape.set_dimensions(Vector2(min_size.x, dimensions.y))
		applied_fixes.append("Fixed minimum width to %.0f" % min_size.x)
	
	if dimensions.y < min_size.y:
		shape.set_dimensions(Vector2(dimensions.x, min_size.y))
		applied_fixes.append("Fixed minimum height to %.0f" % min_size.y)
	
	# Verifică și repară suprapunerile fereastră-ușă
	if shape.has_window and shape.has_door:
		var window_controller = shape.window_controller
		var door_controller = shape.door_controller
		
		if window_controller and door_controller:
			if window_controller.side_angle == door_controller.side_angle:
				# Mută fereastra pe o latură diferită
				var available_sides = [0, 90, 180, 270]
				available_sides.erase(door_controller.side_angle)
				
				if available_sides.size() > 0:
					window_controller.side_angle = available_sides[0]
					applied_fixes.append("Moved window to side %d° to avoid overlap" % available_sides[0])
	
	# Verifică limitele elementelor
	if shape.has_window and shape.window_controller:
		var fixes = _fix_element_bounds(shape.window_controller, shape.get_current_dimensions(), "window")
		applied_fixes.append_array(fixes)
	
	if shape.has_door and shape.door_controller:
		var fixes = _fix_element_bounds(shape.door_controller, shape.get_current_dimensions(), "door")
		applied_fixes.append_array(fixes)
	
	# Ajustează offset-ul interior să nu fie negativ
	if shape.interior_offset < 0:
		shape.set_interior_offset(0)
		applied_fixes.append("Fixed negative interior offset")
	
	return applied_fixes

static func _fix_element_bounds(controller, shape_size: Vector2, element_type: String) -> Array[String]:
	var fixes: Array[String] = []
	
	if not controller or not controller.has_element:
		return fixes
	
	var PropertyValidator = preload("res://PropertyValidator.gd")
	var side_length = PropertyValidator._get_side_length_for_angle(controller.side_angle, shape_size)
	var half_width = controller.width * 0.5
	var max_offset = (side_length * 0.5) - half_width
	
	# Fix lateral offset bounds
	if controller.offset < -max_offset:
		controller.offset = -max_offset
		fixes.append("Fixed %s left boundary (offset: %.1f)" % [element_type, controller.offset])
	
	if controller.offset > max_offset:
		controller.offset = max_offset
		fixes.append("Fixed %s right boundary (offset: %.1f)" % [element_type, controller.offset])
	
	# Fix element size if too large for shape
	var max_width = side_length * 0.8
	if controller.width > max_width:
		controller.width = max_width
		fixes.append("Reduced %s width to %.1f" % [element_type, controller.width])
	
	# Fix vertical positioning for doors
	if element_type == "door":
		if controller.h_offset < 0:
			controller.h_offset = 0
			fixes.append("Fixed door floor level (h_offset: 0)")
		
		if controller.h_offset + controller.length > shape_size.y:
			controller.length = shape_size.y - controller.h_offset
			fixes.append("Reduced door height to fit shape (length: %.1f)" % controller.length)
	
	return fixes

static func get_validation_recommendations(shape: TetrisShape2D) -> Dictionary:
	"""Obține recomandări pentru îmbunătățirea unei forme"""
	if not shape:
		return {"recommendations": [], "priority_fixes": []}
	
	var recommendations: Array[String] = []
	var priority_fixes: Array[String] = []
	
	var PropertyValidator = preload("res://PropertyValidator.gd")
	var validation = PropertyValidator.validate_all_parameters(shape)
	var dimensions = shape.get_current_dimensions()
	
	# Recomandări pentru dimensiuni
	if dimensions.x < 100 or dimensions.y < 100:
		recommendations.append("Consider increasing shape size for better usability")
	
	# Recomandări pentru ferestre
	if shape.has_window and shape.window_controller:
		var window_recommendations = PropertyValidator.get_recommended_values(
			PropertyValidator.WindowDoorController.ElementType.WINDOW, 
			dimensions
		)
		
		if abs(shape.window_controller.width - window_recommendations.width) > 20:
			recommendations.append("Window width could be closer to %.0f for optimal proportions" % window_recommendations.width)
		
		if abs(shape.window_controller.h_offset - window_recommendations.h_offset) > 30:
			recommendations.append("Window height position could be around %.0f for standard placement" % window_recommendations.h_offset)
	
	# Recomandări pentru uși
	if shape.has_door and shape.door_controller:
		var door_recommendations = PropertyValidator.get_recommended_values(
			PropertyValidator.WindowDoorController.ElementType.DOOR, 
			dimensions
		)
		
		if abs(shape.door_controller.width - door_recommendations.width) > 15:
			recommendations.append("Door width could be closer to %.0f for standard size" % door_recommendations.width)
		
		if shape.door_controller.h_offset != 0:
			priority_fixes.append("Doors should typically have h_offset = 0 to reach floor level")
	
	# Verificări pentru offset interior
	if shape.interior_offset > dimensions.x * 0.3 or shape.interior_offset > dimensions.y * 0.3:
		recommendations.append("Interior offset seems too large relative to shape size")
	
	# Verificări pentru suprapuneri
	if not validation.is_valid and validation.errors.size() > 0:
		for error in validation.errors:
			if "overlap" in error.to_lower():
				priority_fixes.append("Fix element overlap: " + error)
	
	return {
		"recommendations": recommendations,
		"priority_fixes": priority_fixes
	}

static func create_validation_report(validation_results: Dictionary) -> String:
	"""Creează un raport text pentru rezultatele validării"""
	var report = "=== VALIDATION REPORT ===\n\n"
	
	report += "Total Shapes: %d\n" % validation_results.get("total_validated", 0)
	report += "Valid Shapes: %d\n" % validation_results.get("valid_shapes", 0)
	report += "Invalid Shapes: %d\n" % validation_results.get("invalid_shapes", 0)
	report += "Total Warnings: %d\n" % validation_results.get("total_warnings", 0)
	report += "Total Errors: %d\n" % validation_results.get("total_errors", 0)
	
	report += "\n=== DETAILED RESULTS ===\n"
	
	var shape_results = validation_results.get("shape_results", {})
	for shape_id in shape_results:
		var result = shape_results[shape_id]
		report += "\nShape ID: %s\n" % shape_id
		report += "  Status: %s\n" % ("VALID" if result.is_valid else "INVALID")
		
		if result.warnings.size() > 0:
			report += "  Warnings:\n"
			for warning in result.warnings:
				report += "    - %s\n" % warning
		
		if result.errors.size() > 0:
			report += "  Errors:\n"
			for error in result.errors:
				report += "    - %s\n" % error
	
	return report

static func setup_realtime_validation(shape: TetrisShape2D, property_panel: PropertyPanel):
	"""Configurează validarea în timp real pentru o formă"""
	if not shape or not property_panel:
		return
	
	# Connect to property changes
	if not property_panel.property_changed.is_connected(_on_property_changed_validate):
		property_panel.property_changed.connect(func(property_name: String, value): _on_property_changed_validate(property_name, value, shape, property_panel))

static func _on_property_changed_validate(property_name: String, value, shape: TetrisShape2D, property_panel: PropertyPanel):
	"""Handler pentru schimbările de proprietăți cu validare automată"""
	if not validation_enabled:
		return
	
	# Validare cu întârziere pentru a evita spam-ul
	await Engine.get_main_loop().process_frame
	
	var validation_results = validate_shape_realtime(shape)
	
	# Update validation display in property panel
	if property_panel.has_method("_validate_shape"):
		property_panel._validate_shape()
	
	# Apply auto-fixes if enabled and there are errors
	if auto_fix_enabled and not validation_results.is_valid:
		var fixes = auto_fix_shape_issues(shape)
		if fixes.size() > 0:
			print("Auto-fixes applied to shape %s: %s" % [shape.unique_id, str(fixes)])
			# Update UI after fixes
			if property_panel.has_method("_update_ui_from_shape"):
				property_panel._update_ui_from_shape()

static func validate_shape_compatibility(shape1: TetrisShape2D, shape2: TetrisShape2D) -> Dictionary:
	"""Verifică compatibilitatea între două forme (pentru îmbinare, etc.)"""
	var result = {
		"compatible": true,
		"issues": [],
		"suggestions": []
	}
	
	if not shape1 or not shape2:
		result.compatible = false
		result.issues.append("One or both shapes are invalid")
		return result
	
	# Verifică dimensiuni similare
	var size1 = shape1.get_current_dimensions()
	var size2 = shape2.get_current_dimensions()
	var size_diff = abs(size1.length() - size2.length())
	
	if size_diff > 100:
		result.suggestions.append("Shapes have very different sizes (%.1f vs %.1f)" % [size1.length(), size2.length()])
	
	# Verifică tipurile
	if shape1.shape_type != shape2.shape_type:
		result.suggestions.append("Shapes are different types (%s vs %s)" % [shape1.shape_type, shape2.shape_type])
	
	# Verifică suprapunerea pozițională
	var distance = shape1.position.distance_to(shape2.position)
	var min_distance = (size1.length() + size2.length()) * 0.25
	
	if distance < min_distance:
		result.issues.append("Shapes are too close together (distance: %.1f)" % distance)
		result.compatible = false
	
	return result

static func set_validation_enabled(enabled: bool):
	validation_enabled = enabled
	print("Validation %s" % ("enabled" if enabled else "disabled"))

static func set_auto_fix_enabled(enabled: bool):
	auto_fix_enabled = enabled
	print("Auto-fix %s" % ("enabled" if enabled else "disabled"))

static func get_validation_settings() -> Dictionary:
	return {
		"validation_enabled": validation_enabled,
		"auto_fix_enabled": auto_fix_enabled
	}
