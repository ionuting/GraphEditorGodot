extends Node

## LayerManager - Singleton for managing graph layers
## Handles layer creation, visibility, colors, and persistence
## Default layers: structural, architectural, mep, furniture

# Layer data structure: {name: String, visible: bool, color: Color}
var layers = {}
var layer_order = []  # Maintains display order

# Default layer definitions
const DEFAULT_LAYERS = {
	"structural": {"visible": true, "color": Color(0.8, 0.2, 0.2, 1.0)},  # Red
	"architectural": {"visible": true, "color": Color(0.2, 0.8, 0.2, 1.0)},  # Green
	"mep": {"visible": true, "color": Color(0.2, 0.2, 0.8, 1.0)},  # Blue
	"furniture": {"visible": true, "color": Color(0.8, 0.8, 0.2, 1.0)},  # Yellow
	"connections": {"visible": true, "color": Color(0.0, 0.8, 0.0, 1.0)}  # Green for connections
}

# Signals for layer changes
signal layer_added(layer_name: String)
signal layer_removed(layer_name: String)
signal layer_visibility_changed(layer_name: String, visible: bool)
signal layer_color_changed(layer_name: String, color: Color)
signal layers_loaded()

func _ready():
	_initialize_default_layers()
	_load_layers_from_file()
	print("LayerManager initialized with layers: ", layers.keys())

# Initialize default layers
func _initialize_default_layers():
	for layer_name in DEFAULT_LAYERS.keys():
		if not layers.has(layer_name):
			layers[layer_name] = DEFAULT_LAYERS[layer_name].duplicate()
			layer_order.append(layer_name)

# Add a new layer
func add_layer(layer_name: String, color: Color = Color.WHITE, visible: bool = true) -> bool:
	if layers.has(layer_name):
		push_error("Layer already exists: " + layer_name)
		return false
	
	layers[layer_name] = {
		"visible": visible,
		"color": color
	}
	layer_order.append(layer_name)
	
	emit_signal("layer_added", layer_name)
	_save_layers_to_file()
	print("Layer added: ", layer_name)
	return true

# Remove a layer (cannot remove default layers)
func remove_layer(layer_name: String) -> bool:
	if DEFAULT_LAYERS.has(layer_name):
		push_error("Cannot remove default layer: " + layer_name)
		return false
	
	if not layers.has(layer_name):
		push_error("Layer does not exist: " + layer_name)
		return false
	
	layers.erase(layer_name)
	layer_order.erase(layer_name)
	
	emit_signal("layer_removed", layer_name)
	_save_layers_to_file()
	print("Layer removed: ", layer_name)
	return true

# Toggle layer visibility
func toggle_visibility(layer_name: String) -> bool:
	if not layers.has(layer_name):
		push_error("Layer does not exist: " + layer_name)
		return false
	
	layers[layer_name]["visible"] = not layers[layer_name]["visible"]
	emit_signal("layer_visibility_changed", layer_name, layers[layer_name]["visible"])
	_save_layers_to_file()
	print("Layer visibility toggled: ", layer_name, " -> ", layers[layer_name]["visible"])
	return true

# Set layer visibility explicitly
func set_layer_visibility(layer_name: String, visible: bool) -> bool:
	if not layers.has(layer_name):
		push_error("Layer does not exist: " + layer_name)
		return false
	
	if layers[layer_name]["visible"] == visible:
		return true  # No change needed
	
	layers[layer_name]["visible"] = visible
	emit_signal("layer_visibility_changed", layer_name, visible)
	_save_layers_to_file()
	print("Layer visibility set: ", layer_name, " -> ", visible)
	return true

# Set layer color
func set_layer_color(layer_name: String, color: Color) -> bool:
	if not layers.has(layer_name):
		push_error("Layer does not exist: " + layer_name)
		return false
	
	layers[layer_name]["color"] = color
	emit_signal("layer_color_changed", layer_name, color)
	_save_layers_to_file()
	print("Layer color changed: ", layer_name, " -> ", color)
	return true

# Check if layer is visible
func is_layer_visible(layer_name: String) -> bool:
	if not layers.has(layer_name):
		return true  # Default to visible if layer doesn't exist
	return layers[layer_name]["visible"]

# Get layer color
func get_layer_color(layer_name: String) -> Color:
	if not layers.has(layer_name):
		return Color.WHITE
	return layers[layer_name]["color"]

# Get all visible layers
func get_visible_layers() -> Array:
	var visible = []
	for layer_name in layer_order:
		if layers[layer_name]["visible"]:
			visible.append(layer_name)
	return visible

# Get all layer names in order
func get_all_layers() -> Array:
	return layer_order.duplicate()

# Get layer data
func get_layer_data(layer_name: String) -> Dictionary:
	if not layers.has(layer_name):
		return {}
	return layers[layer_name].duplicate()

# Check if layer exists
func has_layer(layer_name: String) -> bool:
	return layers.has(layer_name)

# Save layers to file
func _save_layers_to_file():
	var file_path = "user://layers.json"
	
	# Convert Color objects to hex strings for JSON serialization
	var layers_for_save = {}
	for layer_name in layers.keys():
		var layer_data = layers[layer_name].duplicate()
		if layer_data.has("color") and typeof(layer_data["color"]) == TYPE_COLOR:
			layer_data["color"] = layer_data["color"].to_html()
		layers_for_save[layer_name] = layer_data
	
	var save_data = {
		"layers": layers_for_save,
		"layer_order": layer_order,
		"version": "1.0"
	}
	
	var file = FileAccess.open(file_path, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(save_data, "  "))
		file.close()
		print("Layers saved to: ", file_path)
	else:
		push_error("Failed to save layers to: " + file_path)

# Load layers from file
func _load_layers_from_file():
	var file_path = "user://layers.json"
	if not FileAccess.file_exists(file_path):
		print("No saved layers file found, using defaults")
		return
	
	var file = FileAccess.open(file_path, FileAccess.READ)
	if not file:
		push_error("Failed to open layers file: " + file_path)
		return
	
	var json_text = file.get_as_text()
	file.close()
	
	var json = JSON.new()
	if json.parse(json_text) != OK:
		push_error("Failed to parse layers JSON: " + json.get_error_message())
		return
	
	var data = json.data
	if typeof(data) != TYPE_DICTIONARY:
		push_error("Invalid layers data format")
		return
	
	if data.has("layers"):
		# Merge loaded layers with defaults (preserve defaults)
		for layer_name in data["layers"].keys():
			var layer_data = data["layers"][layer_name]
			# Convert color if it's stored as string (hex format)
			if layer_data.has("color") and typeof(layer_data["color"]) == TYPE_STRING:
				var color_str = layer_data["color"]
				# Check if it's a valid hex color
				if color_str.is_valid_html_color():
					layer_data["color"] = Color(color_str)
				else:
					# Fallback to white if invalid
					layer_data["color"] = Color.WHITE
					push_warning("Invalid color format for layer " + layer_name + ": " + color_str)
			layers[layer_name] = layer_data
	
	if data.has("layer_order"):
		# Rebuild layer_order, ensuring defaults come first
		var new_order = []
		for default_layer in DEFAULT_LAYERS.keys():
			if default_layer not in new_order:
				new_order.append(default_layer)
		for layer_name in data["layer_order"]:
			if layer_name not in new_order and layers.has(layer_name):
				new_order.append(layer_name)
		layer_order = new_order
	
	emit_signal("layers_loaded")
	print("Layers loaded from: ", file_path)

# Export layers data for graph save
func export_layers_data() -> Dictionary:
	return {
		"layers": layers.duplicate(true),
		"layer_order": layer_order.duplicate()
	}

# Import layers data from graph load
func import_layers_data(data: Dictionary):
	if not data.has("layers") or not data.has("layer_order"):
		return
	
	# Clear non-default layers
	for layer_name in layers.keys():
		if not DEFAULT_LAYERS.has(layer_name):
			layers.erase(layer_name)
	
	# Import layers
	for layer_name in data["layers"].keys():
		var layer_data = data["layers"][layer_name]
		# Convert color if needed (hex format)
		if layer_data.has("color") and typeof(layer_data["color"]) == TYPE_STRING:
			var color_str = layer_data["color"]
			if color_str.is_valid_html_color():
				layer_data["color"] = Color(color_str)
			else:
				layer_data["color"] = Color.WHITE
				push_warning("Invalid color format for layer " + layer_name + ": " + color_str)
		layers[layer_name] = layer_data
	
	# Import order
	layer_order = data["layer_order"].duplicate()
	
	emit_signal("layers_loaded")
	print("Layers imported from graph data")
