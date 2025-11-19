extends Node

## JSONSchemaExporter - Complete Graph Database Export System
## Exports entire graph database to JSON Schema format
## Includes: project info, coordinate sets, layers, nodes, relationships

# Load dependencies
const UUIDGenerator = preload("res://UUIDGenerator.gd")

## Export complete graph database to JSON Schema
## @param nodes_container: Node containing all graph nodes
## @param connections_list: Array of connections [from, to, label, type, uuid, properties]
## @param project_name: Name of the project
## @param interax_data: Dictionary with x_values and y_values arrays
## @return Dictionary with complete schema
static func export_schema(
	nodes_container: Node,
	connections_list: Array,
	project_name: String = "Untitled Project",
	interax_data: Dictionary = {}
) -> Dictionary:
	
	var schema = {
		"schema_version": "1.0",
		"project_info": _build_project_info(project_name),
		"coordinate_sets": _build_coordinate_sets(interax_data),
		"layers": _build_layers(),
		"nodes": _build_nodes(nodes_container),
		"relationships": _build_relationships(connections_list, nodes_container)
	}
	
	print("JSON Schema export completed: ", schema["nodes"].size(), " nodes, ", schema["relationships"].size(), " relationships")
	return schema

## Build project information section
static func _build_project_info(project_name: String) -> Dictionary:
	var now = Time.get_datetime_dict_from_system()
	var timestamp = "%04d-%02d-%02dT%02d:%02d:%02d" % [
		now.year, now.month, now.day,
		now.hour, now.minute, now.second
	]
	
	return {
		"name": project_name,
		"created": timestamp,
		"modified": timestamp,
		"version": "1.0"
	}

## Build coordinate sets from Interax data
static func _build_coordinate_sets(interax_data: Dictionary) -> Dictionary:
	var coord_sets = {
		"interax": {
			"x_values": [],
			"y_values": [],
			"z_values": []
		}
	}
	
	# Extract coordinate values from interax_data
	if interax_data.has("x_values") and typeof(interax_data["x_values"]) == TYPE_ARRAY:
		coord_sets["interax"]["x_values"] = interax_data["x_values"].duplicate()
	
	if interax_data.has("y_values") and typeof(interax_data["y_values"]) == TYPE_ARRAY:
		coord_sets["interax"]["y_values"] = interax_data["y_values"].duplicate()
	
	# Z values can be added later if needed
	coord_sets["interax"]["z_values"] = []
	
	return coord_sets

## Build layers section from LayerManager
static func _build_layers() -> Array:
	var layers_array = []
	
	# Check if LayerManager singleton exists
	if not Engine.has_singleton("LayerManager"):
		var layer_mgr_path = "/root/LayerManager"
		var tree = Engine.get_main_loop() as SceneTree
		if tree and tree.root.has_node(layer_mgr_path):
			var layer_mgr = tree.root.get_node(layer_mgr_path)
			if layer_mgr:
				var all_layers = layer_mgr.get_all_layers()
				for layer_name in all_layers:
					var layer_data = layer_mgr.get_layer_data(layer_name)
					var color = layer_data.get("color", Color.WHITE)
					layers_array.append({
						"name": layer_name,
						"visible": layer_data.get("visible", true),
						"color": "#%02X%02X%02X" % [
							int(color.r * 255),
							int(color.g * 255),
							int(color.b * 255)
						]
					})
	
	# If no layers found, add default structural layer
	if layers_array.is_empty():
		layers_array.append({
			"name": "structural",
			"visible": true,
			"color": "#FF5722"
		})
	
	return layers_array

## Build nodes section from nodes container
static func _build_nodes(nodes_container: Node) -> Array:
	var nodes_array = []
	
	if nodes_container == null:
		push_error("JSONSchemaExporter: nodes_container is null")
		return nodes_array
	
	for node in nodes_container.get_children():
		var node_data = _extract_node_data(node)
		if node_data != null:
			nodes_array.append(node_data)
	
	return nodes_array

## Extract data from a single node
static func _extract_node_data(node: Node) -> Dictionary:
	if node == null:
		return {}
	
	# Get node script to determine type
	var script_path = ""
	if node.get_script() != null:
		script_path = node.get_script().resource_path
	
	# Determine node type from script
	var node_type = "unknown"
	if script_path.ends_with("Circle.gd"):
		node_type = "structural_node"
	elif script_path.ends_with("draggable_square.gd"):
		node_type = "room"
	elif script_path.ends_with("draggable_icon.gd"):
		node_type = "window"
	elif script_path.ends_with("draggable_door.gd"):
		node_type = "door"
	elif script_path.ends_with("interax.gd"):
		node_type = "interax"
	
	# Get or generate UUID
	var uuid = ""
	var node_info = null
	if node.has_method("get"):
		node_info = node.get("node_info")
	
	if node_info != null and typeof(node_info) == TYPE_DICTIONARY:
		uuid = node_info.get("uuid", "")
	
	# Generate UUID if not present
	if uuid == "":
		uuid = UUIDGenerator.generate_uuid()
		# Store it back to node_info if possible
		if node_info != null:
			node_info["uuid"] = uuid
	
	# Get layer information
	var layer = "structural"
	if node_info != null and node_info.has("layer"):
		layer = node_info["layer"]
	
	# Get visibility
	var visible = node.visible if "visible" in node else true
	
	# Get position
	var position = {"x": 0.0, "y": 0.0}
	if "global_position" in node:
		position = {
			"x": node.global_position.x,
			"y": node.global_position.y
		}
	
	# Build properties from node_info
	var properties = {}
	if node_info != null and typeof(node_info) == TYPE_DICTIONARY:
		properties = node_info.duplicate()
	
	# Add basic node properties
	if "obj_name" in node:
		properties["name"] = node.obj_name
	if "type" in node:
		properties["element_type"] = node.type
	if "id" in node:
		properties["index"] = node.id
	
	# Build final node data
	var node_data = {
		"uuid": uuid,
		"type": node_type,
		"index": node.get("id") if "id" in node else 0,
		"layer": layer,
		"visible": visible,
		"position": position,
		"properties": properties
	}
	
	return node_data

## Build relationships section from connections list
static func _build_relationships(connections_list: Array, nodes_container: Node) -> Array:
	var relationships_array = []
	
	if connections_list == null:
		return relationships_array
	
	for connection in connections_list:
		var rel_data = _extract_relationship_data(connection)
		if rel_data != null and not rel_data.is_empty():
			relationships_array.append(rel_data)
	
	return relationships_array

## Extract data from a single connection
static func _extract_relationship_data(connection: Array) -> Dictionary:
	if connection == null or connection.size() < 2:
		return {}
	
	# Connection structure: [from_node, to_node, label, type, uuid, properties]
	var from_node = connection[0]
	var to_node = connection[1]
	var label = connection[2] if connection.size() > 2 else ""
	var rel_type = connection[3] if connection.size() > 3 else "connects"
	var uuid = connection[4] if connection.size() > 4 else ""
	var properties = connection[5] if connection.size() > 5 else {}
	
	# Generate UUID if not present
	if uuid == "":
		uuid = UUIDGenerator.generate_uuid()
	
	# Get UUIDs from nodes
	var from_uuid = _get_node_uuid(from_node)
	var to_uuid = _get_node_uuid(to_node)
	
	# Build properties dictionary
	var rel_properties = {}
	if typeof(properties) == TYPE_DICTIONARY:
		rel_properties = properties.duplicate()
	
	# Add label to properties if present
	if label != "":
		rel_properties["label"] = label
	
	# Build relationship data
	var rel_data = {
		"uuid": uuid,
		"from_uuid": from_uuid,
		"to_uuid": to_uuid,
		"type": rel_type.to_lower(),
		"properties": rel_properties
	}
	
	return rel_data

## Get UUID from a node, generating one if needed
static func _get_node_uuid(node: Node) -> String:
	if node == null:
		return ""
	
	var node_info = null
	if node.has_method("get"):
		node_info = node.get("node_info")
	
	if node_info != null and typeof(node_info) == TYPE_DICTIONARY:
		var uuid = node_info.get("uuid", "")
		if uuid != "":
			return uuid
		
		# Generate and store UUID
		uuid = UUIDGenerator.generate_uuid()
		node_info["uuid"] = uuid
		return uuid
	
	# Fallback: generate UUID but can't store it
	return UUIDGenerator.generate_uuid()

## Validate schema before export
static func validate_schema(schema: Dictionary) -> bool:
	# Check required top-level keys
	var required_keys = ["schema_version", "project_info", "coordinate_sets", "layers", "nodes", "relationships"]
	for key in required_keys:
		if not schema.has(key):
			push_error("JSONSchemaExporter: Missing required key: " + key)
			return false
	
	# Validate project_info
	if not schema["project_info"].has("name"):
		push_error("JSONSchemaExporter: project_info missing 'name'")
		return false
	
	# Validate nodes array
	if typeof(schema["nodes"]) != TYPE_ARRAY:
		push_error("JSONSchemaExporter: 'nodes' must be an array")
		return false
	
	# Validate relationships array
	if typeof(schema["relationships"]) != TYPE_ARRAY:
		push_error("JSONSchemaExporter: 'relationships' must be an array")
		return false
	
	# Validate each node has required fields
	for node in schema["nodes"]:
		if not node.has("uuid") or not node.has("type"):
			push_error("JSONSchemaExporter: Node missing uuid or type")
			return false
	
	# Validate each relationship has required fields
	for rel in schema["relationships"]:
		if not rel.has("uuid") or not rel.has("from_uuid") or not rel.has("to_uuid"):
			push_error("JSONSchemaExporter: Relationship missing required fields")
			return false
	
	print("JSONSchemaExporter: Schema validation passed")
	return true

## Export schema to file
static func export_to_file(schema: Dictionary, file_path: String) -> bool:
	# Validate schema first
	if not validate_schema(schema):
		push_error("JSONSchemaExporter: Schema validation failed")
		return false
	
	# Ensure file has .json extension
	if not file_path.ends_with(".json"):
		file_path += ".json"
	
	# Open file for writing
	var file = FileAccess.open(file_path, FileAccess.WRITE)
	if file == null:
		push_error("JSONSchemaExporter: Failed to open file for writing: " + file_path)
		return false
	
	# Write JSON with pretty formatting
	var json_string = JSON.stringify(schema, "  ")
	file.store_string(json_string)
	file.close()
	
	print("JSONSchemaExporter: Schema exported successfully to: ", file_path)
	return true

## Import schema from file
static func import_from_file(file_path: String) -> Dictionary:
	if not FileAccess.file_exists(file_path):
		push_error("JSONSchemaExporter: File does not exist: " + file_path)
		return {}
	
	var file = FileAccess.open(file_path, FileAccess.READ)
	if file == null:
		push_error("JSONSchemaExporter: Failed to open file for reading: " + file_path)
		return {}
	
	var json_text = file.get_as_text()
	file.close()
	
	var json = JSON.new()
	var error = json.parse(json_text)
	if error != OK:
		push_error("JSONSchemaExporter: JSON parse error: " + json.get_error_message())
		return {}
	
	var schema = json.data
	if typeof(schema) != TYPE_DICTIONARY:
		push_error("JSONSchemaExporter: Invalid schema format")
		return {}
	
	# Validate imported schema
	if not validate_schema(schema):
		push_error("JSONSchemaExporter: Imported schema validation failed")
		return {}
	
	print("JSONSchemaExporter: Schema imported successfully from: ", file_path)
	return schema