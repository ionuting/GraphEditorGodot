extends Control

## PropertiesPanel - Advanced property editor with add/remove functionality
## Supports extensible properties for nodes and relationships
## Mandatory properties (uuid, type, index, layer, visible) cannot be deleted

signal property_changed(node, key, value)
signal property_added(node, key, value, value_type)
signal property_removed(node, key)

# Mandatory properties that cannot be deleted
const MANDATORY_PROPERTIES = ["uuid", "type", "index", "layer", "visible"]

# Property type definitions
enum PropertyType {
	STRING,
	NUMBER,
	BOOL,
	COLOR
}

var grid = null
var scroll_container = null
var current_node_or_connection = null
var _dragging := false
var _drag_offset := Vector2.ZERO
var _header_height := 26
var add_property_dialog = null

func _ready():
	_ensure_grid()
	# Ensure the panel is properly sized
	custom_minimum_size = Vector2(280, 400)
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	# Asigură-te că panoul consumă input-ul (nu propagă la canvas)
	mouse_filter = Control.MOUSE_FILTER_STOP
	
	# Ensure ScrollContainer also consumes input
	if scroll_container:
		scroll_container.mouse_filter = Control.MOUSE_FILTER_STOP

func _ensure_grid():
	# Modern panel background
	var panel_style = StyleBoxFlat.new()
	panel_style.bg_color = Color(0.15, 0.15, 0.18, 1.0)  # Dark modern background
	panel_style.border_color = Color(0.3, 0.3, 0.35, 1.0)
	panel_style.border_width_left = 2
	panel_style.border_width_right = 2
	panel_style.border_width_top = 2
	panel_style.border_width_bottom = 2
	panel_style.corner_radius_top_left = 8
	panel_style.corner_radius_top_right = 8
	panel_style.corner_radius_bottom_left = 8
	panel_style.corner_radius_bottom_right = 8
	add_theme_stylebox_override("panel", panel_style)
	
	# Create a modern header if missing
	if not has_node("HeaderLabel"):
		var header = Panel.new()
		header.name = "HeaderLabel"
		header.custom_minimum_size = Vector2(0, _header_height)
		
		# Modern header style
		var header_style = StyleBoxFlat.new()
		header_style.bg_color = Color(0.2, 0.4, 0.6, 1.0)  # Blue header
		header_style.corner_radius_top_left = 8
		header_style.corner_radius_top_right = 8
		header.add_theme_stylebox_override("panel", header_style)
		
		# Header label
		var label = Label.new()
		label.text = "PROPERTIES"
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		label.add_theme_font_size_override("font_size", 16)
		label.add_theme_color_override("font_color", Color.WHITE)
		label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		header.add_child(label)
		
		add_child(header)
		move_child(header, 0)  # Ensure it's at the top

	# Create a ScrollContainer + GridContainer if missing
	var sc: ScrollContainer = get_node_or_null("ScrollContainer")
	if sc == null:
		sc = ScrollContainer.new()
		sc.name = "ScrollContainer"
		add_child(sc)
		sc.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		sc.offset_top = _header_height
		sc.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		sc.size_flags_vertical = Control.SIZE_EXPAND_FILL
		# Ensure ScrollContainer consumes mouse input
		sc.mouse_filter = Control.MOUSE_FILTER_STOP

	scroll_container = sc
	grid = sc.get_node_or_null("PropertiesGrid")
	if grid == null:
		grid = GridContainer.new()
		grid.name = "PropertiesGrid"
		grid.columns = 2
		grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		grid.size_flags_vertical = Control.SIZE_EXPAND_FILL
		grid.add_theme_constant_override("h_separation", 12)  # More spacing
		grid.add_theme_constant_override("v_separation", 8)   # More spacing
		sc.add_child(grid)
	
	return grid

func _on_header_gui_input(event):
	# Handle header mouse events to drag the whole panel around.
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			_dragging = true
			# store offset between mouse and panel global position
			_drag_offset = get_viewport().get_mouse_position() - global_position
			# ensure we're on top
			if get_parent() != null:
				get_parent().move_child(self, max(0, get_parent().get_child_count() - 1))
		elif event.button_index == MOUSE_BUTTON_LEFT and not event.pressed:
			_dragging = false
	elif event is InputEventMouseMotion and _dragging:
		var desired = get_viewport().get_mouse_position() - _drag_offset
		# optionally clamp inside parent rect
		if get_parent():
			var parent_rect = Rect2(get_parent().global_position, get_parent().size)
			var clamped = desired
			clamped.x = clamp(clamped.x, parent_rect.position.x, parent_rect.position.x + max(0, parent_rect.size.x - size.x))
			clamped.y = clamp(clamped.y, parent_rect.position.y, parent_rect.position.y + max(0, parent_rect.size.y - size.y))
			global_position = clamped
		else:
			global_position = desired

func _clear_grid():
	if grid == null:
		_ensure_grid()
	for c in grid.get_children():
		c.queue_free()

func build_from_node(node_or_connection):
	print("DEBUG PropertiesPanel.build_from_node() called with: ", node_or_connection)
	_ensure_grid()
	_clear_grid()
	current_node_or_connection = node_or_connection
	
	# FIX #3: Add defensive check for null node_or_connection
	if node_or_connection == null:
		print("PropertiesPanel: node_or_connection is null")
		return

	print("DEBUG PropertiesPanel: Attempting to access node_info property...")
	var info = node_or_connection.node_info
	print("DEBUG PropertiesPanel: node_info retrieved: ", info)
	
	# FIX #3: Add defensive check for null or empty info
	if info == null:
		print("PropertiesPanel: node_info is null for node: ", node_or_connection)
		return
	
	if typeof(info) != TYPE_DICTIONARY:
		print("PropertiesPanel: ERROR - node_info is not a dictionary! Type: ", typeof(info), " Value: ", info)
		return
	
	if info.is_empty():
		print("PropertiesPanel: WARNING - node_info is empty for node: ", node_or_connection)
		return

	print("PropertiesPanel: Building UI for node with ", info.keys().size(), " properties")
	print("DEBUG PropertiesPanel: info.keys() = ", info.keys())

	# Build UI for each key in node_info
	for key in info.keys():
		# Skip the nested properties dict - we'll handle it separately
		if key == "properties":
			continue
			
		var value = info[key]
		_add_property_row(key, value, key in MANDATORY_PROPERTIES)
	
	# Add properties from the nested properties dict
	if info.has("properties") and typeof(info["properties"]) == TYPE_DICTIONARY:
		for key in info["properties"].keys():
			var value = info["properties"][key]
			_add_property_row(key, value, false)
	
	# Add "Add Property" button at the end
	_add_new_property_button()
	
	print("PropertiesPanel: UI built with ", grid.get_child_count(), " controls")

# Helper function to add a property row with optional delete button
func _add_property_row(key: String, value, is_mandatory: bool):
	var label = Label.new()
	label.text = key.capitalize() + ":"
	label.add_theme_font_size_override("font_size", 13)
	
	# Color code mandatory properties
	if is_mandatory:
		label.add_theme_color_override("font_color", Color(1.0, 0.8, 0.2, 1.0))  # Yellow for mandatory
	else:
		label.add_theme_color_override("font_color", Color(0.9, 0.9, 0.9, 1.0))  # Light gray
	
	grid.add_child(label)
	
	# Create container for value control and delete button
	var hbox = HBoxContainer.new()
	hbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox.add_theme_constant_override("separation", 4)
	
	# Special handling for connected_nodes (array)
	if key == "connected_nodes" and typeof(value) == TYPE_ARRAY:
		var text_edit = TextEdit.new()
		text_edit.text = "\n".join(value.map(func(v): return str(v)))
		text_edit.custom_minimum_size = Vector2(0, 100)
		text_edit.editable = false  # Read-only for connected_nodes
		text_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_style_text_edit(text_edit)
		hbox.add_child(text_edit)
	# Handle different value types
	elif typeof(value) == TYPE_STRING:
		var line_edit = LineEdit.new()
		line_edit.text = value
		line_edit.placeholder_text = "Enter " + key.to_lower()
		line_edit.text_changed.connect(_on_property_text_changed.bind(key))
		line_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_style_line_edit(line_edit)
		hbox.add_child(line_edit)
	elif typeof(value) == TYPE_FLOAT or typeof(value) == TYPE_INT:
		var line_edit = LineEdit.new()
		line_edit.text = str(value)
		line_edit.placeholder_text = "Number"
		line_edit.text_changed.connect(_on_property_number_text_changed.bind(key))
		line_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		line_edit.custom_minimum_size = Vector2(100, 28)
		_style_line_edit(line_edit)
		hbox.add_child(line_edit)
	elif typeof(value) == TYPE_BOOL:
		var check_box = CheckBox.new()
		check_box.button_pressed = value
		check_box.toggled.connect(_on_property_bool_changed.bind(key))
		hbox.add_child(check_box)
	elif typeof(value) == TYPE_COLOR:
		var color_picker = ColorPickerButton.new()
		color_picker.color = value
		color_picker.custom_minimum_size = Vector2(60, 28)
		color_picker.color_changed.connect(_on_property_color_changed.bind(key))
		hbox.add_child(color_picker)
	elif typeof(value) == TYPE_ARRAY or typeof(value) == TYPE_DICTIONARY:
		var fallback_label = Label.new()
		fallback_label.text = JSON.stringify(value)
		fallback_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		fallback_label.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7, 1.0))
		hbox.add_child(fallback_label)
	else:
		var fallback_label = Label.new()
		fallback_label.text = str(value)
		fallback_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		fallback_label.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7, 1.0))
		hbox.add_child(fallback_label)
	
	# Add delete button if not mandatory
	if not is_mandatory:
		var delete_btn = Button.new()
		delete_btn.text = "✕"
		delete_btn.custom_minimum_size = Vector2(32, 28)
		delete_btn.pressed.connect(_on_delete_property.bind(key))
		_style_delete_button(delete_btn)
		hbox.add_child(delete_btn)
	
	grid.add_child(hbox)

# Modern styling helper functions
func _style_line_edit(line_edit: LineEdit):
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.2, 0.2, 0.23, 1.0)
	style.border_color = Color(0.4, 0.4, 0.45, 1.0)
	style.border_width_left = 1
	style.border_width_right = 1
	style.border_width_top = 1
	style.border_width_bottom = 1
	style.corner_radius_top_left = 4
	style.corner_radius_top_right = 4
	style.corner_radius_bottom_left = 4
	style.corner_radius_bottom_right = 4
	style.content_margin_left = 6
	style.content_margin_right = 6
	line_edit.add_theme_stylebox_override("normal", style)
	line_edit.add_theme_color_override("font_color", Color(0.95, 0.95, 0.95, 1.0))
	line_edit.add_theme_color_override("font_placeholder_color", Color(0.5, 0.5, 0.5, 1.0))

func _style_text_edit(text_edit: TextEdit):
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.2, 0.2, 0.23, 1.0)
	style.border_color = Color(0.4, 0.4, 0.45, 1.0)
	style.border_width_left = 1
	style.border_width_right = 1
	style.border_width_top = 1
	style.border_width_bottom = 1
	style.corner_radius_top_left = 4
	style.corner_radius_top_right = 4
	style.corner_radius_bottom_left = 4
	style.corner_radius_bottom_right = 4
	text_edit.add_theme_stylebox_override("normal", style)
	text_edit.add_theme_color_override("font_color", Color(0.95, 0.95, 0.95, 1.0))

func _style_spin_box(spin_box: SpinBox):
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.2, 0.2, 0.23, 1.0)
	style.border_color = Color(0.4, 0.4, 0.45, 1.0)
	style.border_width_left = 1
	style.border_width_right = 1
	style.border_width_top = 1
	style.border_width_bottom = 1
	style.corner_radius_top_left = 4
	style.corner_radius_top_right = 4
	style.corner_radius_bottom_left = 4
	style.corner_radius_bottom_right = 4
	var line_edit = spin_box.get_line_edit()
	if line_edit:
		line_edit.add_theme_stylebox_override("normal", style)
		line_edit.add_theme_color_override("font_color", Color(0.95, 0.95, 0.95, 1.0))

func _style_delete_button(button: Button):
	var style_normal = StyleBoxFlat.new()
	style_normal.bg_color = Color(0.8, 0.2, 0.2, 0.8)
	style_normal.corner_radius_top_left = 4
	style_normal.corner_radius_top_right = 4
	style_normal.corner_radius_bottom_left = 4
	style_normal.corner_radius_bottom_right = 4
	
	var style_hover = StyleBoxFlat.new()
	style_hover.bg_color = Color(1.0, 0.3, 0.3, 1.0)
	style_hover.corner_radius_top_left = 4
	style_hover.corner_radius_top_right = 4
	style_hover.corner_radius_bottom_left = 4
	style_hover.corner_radius_bottom_right = 4
	
	button.add_theme_stylebox_override("normal", style_normal)
	button.add_theme_stylebox_override("hover", style_hover)
	button.add_theme_stylebox_override("pressed", style_hover)
	button.add_theme_color_override("font_color", Color.WHITE)
	button.add_theme_font_size_override("font_size", 14)

# Add "Add Property" button
func _add_new_property_button():
	var spacer = Control.new()
	spacer.custom_minimum_size = Vector2(0, 16)
	grid.add_child(spacer)
	grid.add_child(Control.new())  # Empty cell for alignment
	
	var add_btn = Button.new()
	add_btn.text = "+ Add Property"
	add_btn.custom_minimum_size = Vector2(0, 32)
	add_btn.pressed.connect(_show_add_property_dialog)
	
	# Style the add button
	var style_normal = StyleBoxFlat.new()
	style_normal.bg_color = Color(0.2, 0.6, 0.3, 0.8)
	style_normal.corner_radius_top_left = 4
	style_normal.corner_radius_top_right = 4
	style_normal.corner_radius_bottom_left = 4
	style_normal.corner_radius_bottom_right = 4
	
	var style_hover = StyleBoxFlat.new()
	style_hover.bg_color = Color(0.3, 0.7, 0.4, 1.0)
	style_hover.corner_radius_top_left = 4
	style_hover.corner_radius_top_right = 4
	style_hover.corner_radius_bottom_left = 4
	style_hover.corner_radius_bottom_right = 4
	
	add_btn.add_theme_stylebox_override("normal", style_normal)
	add_btn.add_theme_stylebox_override("hover", style_hover)
	add_btn.add_theme_stylebox_override("pressed", style_hover)
	add_btn.add_theme_color_override("font_color", Color.WHITE)
	add_btn.add_theme_font_size_override("font_size", 14)
	
	grid.add_child(Label.new())  # Empty cell
	grid.add_child(add_btn)

func _on_name_changed(new_text: String, node):
	if node == null:
		return
	node.obj_name = new_text
	# Also sync into node_info if present
	if node.has_method("get"):
		var ni = node.get("node_info")
		if ni != null:
			ni["name"] = new_text
	emit_signal("property_changed", node, "name", new_text)

func _on_index_changed(new_text: String, node):
	if node == null:
		return
	var num = null
	if new_text.is_valid_int():
		num = int(new_text)
	elif new_text.is_valid_float():
		num = int(float(new_text))
	else:
		return
	# update node and node_info if present
	if node.has_method("set"):
		# try to write into node_info if available
		if node.has_method("get"):
			var ni = node.get("node_info")
			if ni != null and typeof(ni) == TYPE_DICTIONARY:
				ni["index"] = num
	# also attempt direct assignment if property exists
	if node.has_method("set") and node.has_meta("index"):
		node.set("index", num)
	emit_signal("property_changed", node, "index", num)

func _on_distances_changed(new_text: String, node):
	# Delegate parsing back to node (similar logic as in main_scene)
	if node == null:
		return
	# Reuse existing parser logic lightly
	var distances = [[0.0], [0.0]]
	var cleaned_text = new_text.replace("[", "").replace("]", "").strip_edges()
	var parts = cleaned_text.split(";")
	for part in parts:
		part = part.strip_edges()
		if part.begins_with("x:"):
			var x_str = part.replace("x:", "").strip_edges()
			var x_values = x_str.split(",")
			distances[0] = []
			for val in x_values:
				val = val.strip_edges()
				if val.is_valid_float():
					var num = float(val)
					if num >= 0.0:
						distances[0].append(num)
		elif part.begins_with("y:"):
			var y_str = part.replace("y:", "").strip_edges()
			var y_values = y_str.split(",")
			distances[1] = []
			for val in y_values:
				val = val.strip_edges()
				if val.is_valid_float():
					var num = float(val)
					if num >= 0.0:
						distances[1].append(num)
	if distances[0].size() > 0 and distances[1].size() > 0:
		node.distances = distances
		if node.has_method("update_labels"):
			node.update_labels()
	emit_signal("property_changed", node, "distances", distances)

func _on_prop_toggled(pressed: bool, node, key):
	if node == null:
		return
	if node.has_method("get"):
		var ni = node.get("node_info")
		if ni != null:
			ni[key] = pressed
	emit_signal("property_changed", node, key, pressed)

func _on_prop_text_changed(new_text: String, node, key):
	if node == null:
		return
	if node.has_method("get"):
		var ni = node.get("node_info")
		if ni != null:
			ni[key] = new_text
	emit_signal("property_changed", node, key, new_text)

func _on_prop_number_changed(new_text: String, node, key):
	if node == null:
		return
	var num = null
	if new_text.is_valid_int():
		num = int(new_text)
	elif new_text.is_valid_float():
		num = float(new_text)
	else:
		return
	if node.has_method("get"):
		var ni = node.get("node_info")
		if ni != null:
			ni[key] = num
	emit_signal("property_changed", node, key, num)

func _on_edit_dict_pressed(_node, key):
	# Placeholder: could open a popup to edit nested dictionaries/arrays
	print("Edit nested dict/array not implemented for:", key)

func _on_prop_type_selected(index: int, node, key, choices):
	if node == null:
		return
	var chosen = choices[index]
	if node.has_method("get"):
		var ni = node.get("node_info")
		if ni != null and typeof(ni) == TYPE_DICTIONARY:
			ni[key] = chosen
	emit_signal("property_changed", node, key, chosen)

func _on_property_text_changed(new_text: String, key: String):
	if current_node_or_connection != null:
		_on_prop_text_changed(new_text, current_node_or_connection, key)

func _on_property_number_text_changed(new_text: String, key: String):
	if current_node_or_connection == null:
		return
	
	# Validate number
	var num_value = null
	if new_text.is_valid_int():
		num_value = int(new_text)
	elif new_text.is_valid_float():
		num_value = float(new_text)
	else:
		return  # Invalid number, don't update
	
	# Update node_info
	if current_node_or_connection.has_method("get"):
		var ni = current_node_or_connection.get("node_info")
		if ni != null:
			# Check if property is in nested properties dict
			if ni.has("properties") and ni["properties"].has(key):
				ni["properties"][key] = num_value
			else:
				ni[key] = num_value
	
	emit_signal("property_changed", current_node_or_connection, key, num_value)
	
	# If index changed, redraw the node
	if key == "index" and current_node_or_connection.has_method("queue_redraw"):
		current_node_or_connection.queue_redraw()

func _on_property_value_changed(new_value: float, key: String):
	if current_node_or_connection != null:
		_on_prop_number_changed(str(new_value), current_node_or_connection, key)
		# Dacă indexul s-a schimbat, redesenează nodul
		if key == "index" and current_node_or_connection.has_method("queue_redraw"):
			current_node_or_connection.queue_redraw()

func _on_property_color_changed(new_color: Color, key: String):
	if current_node_or_connection != null and current_node_or_connection.has_method("get"):
		var ni = current_node_or_connection.get("node_info")
		if ni != null:
			# Check if property is in nested properties dict
			if ni.has("properties") and ni["properties"].has(key):
				ni["properties"][key] = new_color
			else:
				ni[key] = new_color
		emit_signal("property_changed", current_node_or_connection, key, new_color)

func _on_property_bool_changed(pressed: bool, key: String):
	if current_node_or_connection != null and current_node_or_connection.has_method("get"):
		var ni = current_node_or_connection.get("node_info")
		if ni != null:
			# Check if property is in nested properties dict
			if ni.has("properties") and ni["properties"].has(key):
				ni["properties"][key] = pressed
			else:
				ni[key] = pressed
		emit_signal("property_changed", current_node_or_connection, key, pressed)

func _on_delete_property(key: String):
	if current_node_or_connection == null:
		return
	
	# Don't allow deleting mandatory properties
	if key in MANDATORY_PROPERTIES:
		print("Cannot delete mandatory property: ", key)
		return
	
	var ni = current_node_or_connection.node_info
	if ni == null:
		return
	
	# Remove from nested properties dict if present
	if ni.has("properties") and ni["properties"].has(key):
		ni["properties"].erase(key)
	# Otherwise remove from main dict
	elif ni.has(key):
		ni.erase(key)
	
	emit_signal("property_removed", current_node_or_connection, key)
	
	# Rebuild the panel
	build_from_node(current_node_or_connection)
	print("Property deleted: ", key)

func _show_add_property_dialog():
	if add_property_dialog != null:
		add_property_dialog.queue_free()
	
	# Create dialog
	add_property_dialog = Window.new()
	add_property_dialog.title = "Add Custom Property"
	add_property_dialog.size = Vector2i(400, 250)
	add_property_dialog.position = Vector2i(100, 100)
	
	var vbox = VBoxContainer.new()
	add_property_dialog.add_child(vbox)
	vbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	vbox.add_theme_constant_override("separation", 10)
	
	# Property name
	var name_label = Label.new()
	name_label.text = "Property Name:"
	vbox.add_child(name_label)
	
	var name_edit = LineEdit.new()
	name_edit.name = "PropertyNameEdit"
	name_edit.placeholder_text = "e.g., material, cost, area"
	vbox.add_child(name_edit)
	
	# Property type
	var type_label = Label.new()
	type_label.text = "Property Type:"
	vbox.add_child(type_label)
	
	var type_option = OptionButton.new()
	type_option.name = "PropertyTypeOption"
	type_option.add_item("String", PropertyType.STRING)
	type_option.add_item("Number", PropertyType.NUMBER)
	type_option.add_item("Boolean", PropertyType.BOOL)
	type_option.add_item("Color", PropertyType.COLOR)
	vbox.add_child(type_option)
	
	# Default value
	var value_label = Label.new()
	value_label.text = "Default Value:"
	vbox.add_child(value_label)
	
	var value_edit = LineEdit.new()
	value_edit.name = "PropertyValueEdit"
	value_edit.placeholder_text = "Enter default value"
	vbox.add_child(value_edit)
	
	# Buttons
	var button_box = HBoxContainer.new()
	vbox.add_child(button_box)
	
	var add_btn = Button.new()
	add_btn.text = "Add"
	add_btn.pressed.connect(_on_add_property_confirmed.bind(add_property_dialog))
	button_box.add_child(add_btn)
	
	var cancel_btn = Button.new()
	cancel_btn.text = "Cancel"
	cancel_btn.pressed.connect(func(): add_property_dialog.queue_free())
	button_box.add_child(cancel_btn)
	
	# Add to scene and show
	get_tree().root.add_child(add_property_dialog)
	add_property_dialog.popup_centered()

func _on_add_property_confirmed(dialog: Window):
	var name_edit = dialog.find_child("PropertyNameEdit", true, false)
	var type_option = dialog.find_child("PropertyTypeOption", true, false)
	var value_edit = dialog.find_child("PropertyValueEdit", true, false)
	
	if name_edit == null or type_option == null or value_edit == null:
		print("Error: Could not find dialog controls")
		dialog.queue_free()
		return
	
	var prop_name = name_edit.text.strip_edges()
	var prop_type = type_option.get_selected_id()
	var prop_value_str = value_edit.text.strip_edges()
	
	# Validate property name
	if prop_name == "":
		print("Error: Property name cannot be empty")
		return
	
	# Check if property already exists
	var ni = current_node_or_connection.node_info
	if ni.has(prop_name) or (ni.has("properties") and ni["properties"].has(prop_name)):
		print("Error: Property already exists: ", prop_name)
		return
	
	# Convert value based on type
	var prop_value
	match prop_type:
		PropertyType.STRING:
			prop_value = prop_value_str
		PropertyType.NUMBER:
			if prop_value_str.is_valid_float():
				prop_value = float(prop_value_str)
			else:
				prop_value = 0.0
		PropertyType.BOOL:
			prop_value = prop_value_str.to_lower() in ["true", "1", "yes"]
		PropertyType.COLOR:
			if prop_value_str.is_valid_html_color():
				prop_value = Color(prop_value_str)
			else:
				prop_value = Color.WHITE
	
	# Add to nested properties dict
	if not ni.has("properties"):
		ni["properties"] = {}
	ni["properties"][prop_name] = prop_value
	
	emit_signal("property_added", current_node_or_connection, prop_name, prop_value, prop_type)
	
	# Rebuild panel
	build_from_node(current_node_or_connection)
	
	print("Property added: ", prop_name, " = ", prop_value)
	dialog.queue_free()
