extends RefCounted
class_name ShapeManager

# Manager pentru forme TetrisShape2D cu persistență JSON

static var instance: ShapeManager = null
var shapes: Array[TetrisShape2D] = []
var shape_properties: Dictionary = {}
var save_path: String = "user://shapes.json"

signal shape_added(shape: TetrisShape2D)
signal shape_removed(shape: TetrisShape2D)
signal shape_modified(shape: TetrisShape2D)
signal shapes_loaded()

static func get_instance() -> ShapeManager:
	if not instance:
		instance = ShapeManager.new()
	return instance

func _init():
	if not instance:
		instance = self

func add_shape(shape: TetrisShape2D):
	if shape and shape not in shapes:
		shapes.append(shape)
		shape_properties[shape.unique_id] = shape.to_dict()
		
		# Connect shape signals
		if not shape.shape_changed.is_connected(_on_shape_changed):
			shape.shape_changed.connect(_on_shape_changed.bind(shape))
		
		shape_added.emit(shape)
		save_shapes()

func remove_shape(shape: TetrisShape2D):
	if shape in shapes:
		shapes.erase(shape)
		shape_properties.erase(shape.unique_id)
		
		# Disconnect signals
		if shape.shape_changed.is_connected(_on_shape_changed):
			shape.shape_changed.disconnect(_on_shape_changed)
		
		shape_removed.emit(shape)
		save_shapes()

func get_shape_by_id(unique_id: String) -> TetrisShape2D:
	for shape in shapes:
		if shape.unique_id == unique_id:
			return shape
	return null

func get_all_shapes() -> Array[TetrisShape2D]:
	return shapes.duplicate()

func get_shapes_count() -> int:
	return shapes.size()

func clear_all_shapes():
	var shapes_copy = shapes.duplicate()
	for shape in shapes_copy:
		remove_shape(shape)

func _on_shape_changed(shape: TetrisShape2D):
	if shape in shapes:
		shape_properties[shape.unique_id] = shape.to_dict()
		shape_modified.emit(shape)
		save_shapes()

func save_shapes():
	var data = shape_properties.duplicate()
	var json_text = JSON.stringify(data, "\t")
	var file = FileAccess.open(save_path, FileAccess.WRITE)
	if file:
		file.store_string(json_text)
		file.close()
		print("✓ Saved ", shapes.size(), " shapes to ", save_path)
	else:
		print("✗ Failed to save shapes to ", save_path)

func load_shapes() -> Array[Dictionary]:
	var file = FileAccess.open(save_path, FileAccess.READ)
	if not file:
		print("No saved shapes file found at ", save_path)
		return []
	
	var json_text = file.get_as_text()
	file.close()
	
	var json = JSON.new()
	var parse_result = json.parse(json_text)
	
	if parse_result != OK:
		print("✗ Failed to parse JSON from ", save_path)
		return []
	
	var data = json.data
	if not data is Dictionary:
		print("✗ Invalid JSON data format in ", save_path)
		return []
	
	var loaded_shapes: Array[Dictionary] = []
	for shape_id in data:
		var shape_data = data[shape_id]
		if shape_data is Dictionary:
			loaded_shapes.append(shape_data)
	
	print("✓ Loaded ", loaded_shapes.size(), " shapes from ", save_path)
	shapes_loaded.emit()
	return loaded_shapes

func create_shape_from_data(shape_data: Dictionary, parent_node: Node) -> TetrisShape2D:
	var TetrisShape2D_class = preload("res://TetrisShape2D.gd")
	var shape = TetrisShape2D_class.new()
	
	# Set basic properties first
	if shape_data.has("position"):
		var pos_data = shape_data.position
		if pos_data is Vector2:
			shape.position = pos_data
		elif pos_data is Dictionary and pos_data.has("x") and pos_data.has("y"):
			shape.position = Vector2(pos_data.x, pos_data.y)
		elif pos_data is String:
			# Try to parse string representation like "(x, y)"
			var pos_str = pos_data.strip_edges().replace("(", "").replace(")", "")
			var coords = pos_str.split(",")
			if coords.size() == 2:
				shape.position = Vector2(coords[0].to_float(), coords[1].to_float())
	
	if shape_data.has("shape_type"):
		shape.shape_type = shape_data.shape_type
	
	# Use from_dict to restore all properties
	shape.from_dict(shape_data)
	
	# Add to scene
	parent_node.add_child(shape)
	shape.add_to_group("tetris_shapes")
	
	# Add to manager
	add_shape(shape)
	
	return shape

func validate_all_shapes() -> Dictionary:
	var PropertyValidator = preload("res://PropertyValidator.gd")
	var results = {
		"total_shapes": shapes.size(),
		"valid_shapes": 0,
		"invalid_shapes": 0,
		"shapes_with_warnings": 0,
		"validation_details": {}
	}
	
	for shape in shapes:
		var validation = PropertyValidator.validate_all_parameters(shape)
		results.validation_details[shape.unique_id] = validation
		
		if validation.is_valid:
			results.valid_shapes += 1
		else:
			results.invalid_shapes += 1
		
		if validation.warnings.size() > 0:
			results.shapes_with_warnings += 1
	
	return results

func get_geometry_summary() -> Dictionary:
	var summary = {
		"total_area": 0.0,
		"total_perimeter": 0.0,
		"total_window_area": 0.0,
		"total_door_area": 0.0,
		"shapes_with_windows": 0,
		"shapes_with_doors": 0
	}
	
	for shape in shapes:
		var geometry = shape.get_geometry_info()
		summary.total_area += geometry.get("interior_area", 0.0)
		summary.total_perimeter += geometry.get("exterior_perimeter", 0.0)
		
		if geometry.has("window_area"):
			summary.total_window_area += geometry.window_area
			summary.shapes_with_windows += 1
		
		if geometry.has("door_area"):
			summary.total_door_area += geometry.door_area
			summary.shapes_with_doors += 1
	
	return summary

func export_shapes_to_json(file_path: String) -> bool:
	var export_data = {
		"timestamp": Time.get_datetime_string_from_system(),
		"version": "1.0",
		"shape_count": shapes.size(),
		"shapes": shape_properties.duplicate()
	}
	
	var json_text = JSON.stringify(export_data, "\t")
	var file = FileAccess.open(file_path, FileAccess.WRITE)
	if file:
		file.store_string(json_text)
		file.close()
		print("✓ Exported shapes to ", file_path)
		return true
	else:
		print("✗ Failed to export shapes to ", file_path)
		return false

func import_shapes_from_json(file_path: String, parent_node: Node) -> int:
	var file = FileAccess.open(file_path, FileAccess.READ)
	if not file:
		print("✗ Cannot open file: ", file_path)
		return 0
	
	var json_text = file.get_as_text()
	file.close()
	
	var json = JSON.new()
	var parse_result = json.parse(json_text)
	
	if parse_result != OK:
		print("✗ Failed to parse JSON from ", file_path)
		return 0
	
	var data = json.data
	if not data is Dictionary:
		print("✗ Invalid JSON data format")
		return 0
	
	var imported_count = 0
	var shapes_data = data.get("shapes", {})
	
	for shape_id in shapes_data:
		var shape_data = shapes_data[shape_id]
		if shape_data is Dictionary:
			create_shape_from_data(shape_data, parent_node)
			imported_count += 1
	
	print("✓ Imported ", imported_count, " shapes from ", file_path)
	return imported_count

func auto_arrange_shapes(container_size: Vector2):
	"""Automatically arrange shapes in a grid pattern"""
	if shapes.size() == 0:
		return
	
	var cols = int(ceil(sqrt(shapes.size())))
	var rows = int(ceil(float(shapes.size()) / cols))
	
	var cell_width = container_size.x / cols
	var cell_height = container_size.y / rows
	
	for i in range(shapes.size()):
		var row = i / cols
		var col = i % cols
		
		var x = col * cell_width + cell_width * 0.5
		var y = row * cell_height + cell_height * 0.5
		
		shapes[i].position = Vector2(x, y)

func find_shapes_by_property(property_name: String, value) -> Array[TetrisShape2D]:
	var found_shapes: Array[TetrisShape2D] = []
	
	for shape in shapes:
		var shape_dict = shape.to_dict()
		if shape_dict.has(property_name) and shape_dict[property_name] == value:
			found_shapes.append(shape)
	
	return found_shapes

func get_shapes_statistics() -> Dictionary:
	var stats = {
		"total_count": shapes.size(),
		"by_type": {},
		"by_room_name": {},
		"with_windows": 0,
		"with_doors": 0,
		"average_area": 0.0,
		"total_area": 0.0
	}
	
	var total_area = 0.0
	
	for shape in shapes:
		# Count by type
		var shape_type = shape.shape_type
		if not stats.by_type.has(shape_type):
			stats.by_type[shape_type] = 0
		stats.by_type[shape_type] += 1
		
		# Count by room name
		var room_name = shape.room_name
		if not stats.by_room_name.has(room_name):
			stats.by_room_name[room_name] = 0
		stats.by_room_name[room_name] += 1
		
		# Count windows and doors
		if shape.has_window:
			stats.with_windows += 1
		if shape.has_door:
			stats.with_doors += 1
		
		# Calculate area
		var geometry = shape.get_geometry_info()
		var area = geometry.get("interior_area", 0.0)
		total_area += area
	
	stats.total_area = total_area
	stats.average_area = total_area / max(shapes.size(), 1)
	
	return stats
