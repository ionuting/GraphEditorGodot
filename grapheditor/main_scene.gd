extends Node

# --- UI references (onready)
@onready var ui_circles_container = $CirclesContainer
@onready var ui_button = $CanvasLayer/AddCircleButton
@onready var ui_square_button = $CanvasLayer/AddSquareButton
@onready var ui_icon_button = $CanvasLayer/AddIconButton
@onready var ui_door_button = $CanvasLayer/AddDoorButton
@onready var ui_interax_button = $CanvasLayer/AddInteraxButton
@onready var ui_view_3d_button = $CanvasLayer/View3DButton
@onready var ui_viewport_container = $CanvasLayer/SubViewportContainer
@onready var ui_connections = $Connections
@onready var ui_connect_mode_button = $CanvasLayer/ConnectModeButton
@onready var ui_camera = $Camera2D
@onready var ui_file_dialog = $CanvasLayer/FileDialog
@onready var ui_save_button = $CanvasLayer/SaveButton
@onready var ui_load_button = $CanvasLayer/LoadButton
@onready var ui_background = $Background
@onready var ui_properties_panel = $CanvasLayer/PropertiesPanel
# name/distances controls moved into PropertiesPanel.gd

# --- Scenes (preloads) (names match usages below)
var circle_scene = preload("res://Circle.tscn")
var square_scene = preload("res://Square.tscn")
var icon_scene = preload("res://Icon.tscn")
var door_scene = preload("res://Door.tscn")
var interax_scene = preload("res://Interax.tscn")

# --- State ---
var connections_list = []
var selected_circle = null
var selected_for_properties = null
var selected_connection = null
var connect_mode = false
var is_panning = false
var pan_start_pos = Vector2.ZERO
var next_id = 0
var is_save_mode = false
var interax_node = null  # single Interax node reference

func _init_ui():
	# Initialize basic UI defaults and random seed
	if Engine.has_singleton("RandomNumberGenerator"):
		randomize()
	else:
		randomize()

	if ui_properties_panel:
		ui_properties_panel.visible = false
	if ui_viewport_container:
		ui_viewport_container.visible = false
	if ui_file_dialog:
		ui_file_dialog.access = FileDialog.ACCESS_FILESYSTEM
		ui_file_dialog.filters = ["*.json ; JSON Files"]
	if ui_connect_mode_button:
		if ui_connect_mode_button.has_method("set_pressed"):
			ui_connect_mode_button.set_pressed(false)
		else:
			ui_connect_mode_button.pressed = false


# Runtime references to dynamic NodeInfo UI controls (created at runtime)
var ui_nodeinfo_index_label = null
var ui_nodeinfo_type_option = null
var ui_nodeinfo_has_column = null
var ui_nodeinfo_column_type = null

func _ready():
	_init_ui()
	_build_properties_panel()
	_connect_signals()
	_create_initial_circle()
	_hide_panels()

	# If the PropertiesPanel has our new script, connect its signal
	if ui_properties_panel and ui_properties_panel.has_method("connect"):
		# connect when the panel script emits changes
		if ui_properties_panel.has_method("connect"):
			# avoid double-connecting
			var p = ui_properties_panel
			if p.has_method("build_from_node"):
				p.connect("property_changed", Callable(self, "_on_panel_property_changed"))


## Build dynamic controls for node_info inside the PropertiesPanel
func _build_properties_panel():
	# If a dedicated PropertiesPanel script exists, let it manage the UI entirely
	if ui_properties_panel == null:
		return
	if ui_properties_panel.has_method("build_from_node"):
		return
	# Create Index label
	if not ui_properties_panel.has_node("NodeInfoIndexLabel"):
		var lbl = Label.new()
		lbl.name = "NodeInfoIndexLabel"
		lbl.text = "Index:"
		ui_properties_panel.add_child(lbl)
	ui_nodeinfo_index_label = ui_properties_panel.get_node("NodeInfoIndexLabel")

	# Create node_info type option (ax / nonax)
	if not ui_properties_panel.has_node("NodeInfoTypeOption"):
		var opt = OptionButton.new()
		opt.name = "NodeInfoTypeOption"
		opt.add_item("ax", 0)
		opt.add_item("nonax", 1)
		ui_properties_panel.add_child(opt)
	ui_nodeinfo_type_option = ui_properties_panel.get_node("NodeInfoTypeOption")

	# Create Has Column checkbox
	if not ui_properties_panel.has_node("NodeInfoHasColumn"):
		var chk = CheckBox.new()
		chk.name = "NodeInfoHasColumn"
		chk.text = "Has Column"
		ui_properties_panel.add_child(chk)
	ui_nodeinfo_has_column = ui_properties_panel.get_node("NodeInfoHasColumn")

	# Create Column Type line edit
	if not ui_properties_panel.has_node("NodeInfoColumnTypeLineEdit"):
		var col = LineEdit.new()
		col.name = "NodeInfoColumnTypeLineEdit"
		col.placeholder_text = "Column type"
		ui_properties_panel.add_child(col)
	ui_nodeinfo_column_type = ui_properties_panel.get_node("NodeInfoColumnTypeLineEdit")

	# Connect signals for node_info controls
	if ui_nodeinfo_type_option:
		ui_nodeinfo_type_option.item_selected.connect(_on_nodeinfo_type_selected)
	if ui_nodeinfo_has_column:
		ui_nodeinfo_has_column.toggled.connect(_on_nodeinfo_has_column_toggled)
	if ui_nodeinfo_column_type:
		ui_nodeinfo_column_type.text_changed.connect(_on_nodeinfo_column_type_changed)
	ui_file_dialog.filters = ["*.json ; JSON Files"]
	ui_file_dialog.access = FileDialog.ACCESS_FILESYSTEM

func _connect_signals():
	ui_save_button.pressed.connect(_on_save_button_pressed)
	ui_load_button.pressed.connect(_on_load_button_pressed)
	ui_file_dialog.file_selected.connect(_on_file_dialog_file_selected)
	ui_button.pressed.connect(_on_button_pressed)
	ui_square_button.pressed.connect(_on_square_button_pressed)
	ui_icon_button.pressed.connect(_on_icon_button_pressed)
	ui_door_button.pressed.connect(_on_door_button_pressed)
	ui_interax_button.pressed.connect(_on_interax_button_pressed)
	ui_view_3d_button.pressed.connect(_on_view_3d_button_pressed)
	ui_connect_mode_button.toggled.connect(_on_connect_mode_toggled)
	# name/distances editing is handled by PropertiesPanel.gd now
	ui_connections.connection_selected.connect(_on_connection_selected)



func _create_initial_circle():
	var initial = circle_scene.instantiate()
	initial.global_position = Vector2(100, 100)
	initial.type = "Node"
	initial.obj_name = "Node1"
	initial.id = next_id
	next_id += 1
	ui_circles_container.add_child(initial)
	initial.circle_selected_for_connection.connect(_on_circle_selected_for_connection)
	initial.circle_selected_for_properties.connect(_on_circle_selected_for_properties)

func _hide_panels():
	ui_properties_panel.visible = false
	ui_viewport_container.visible = false
	ui_file_dialog.visible = false


## Node creation helpers
func _add_node(scene, position: Vector2, node_type: String, node_name: String):
	var n = scene.instantiate()
	n.global_position = position
	n.type = node_type
	n.obj_name = node_name
	n.id = next_id
	next_id += 1
	ui_circles_container.add_child(n)
	n.circle_selected_for_connection.connect(_on_circle_selected_for_connection)
	n.circle_selected_for_properties.connect(_on_circle_selected_for_properties)
	if n.get_script() and n.get_script().resource_path.ends_with("interax.gd"):
		n.execute_pressed.connect(_on_interax_execute_pressed)
		n.close_pressed.connect(_on_interax_close_pressed)
	return n

func _add_node_random(scene, node_type: String, name_prefix: String):
	var pos = ui_camera.offset + Vector2(randi_range(-300, 300), randi_range(-200, 200)) / ui_camera.zoom
	var node_name = name_prefix + str(ui_circles_container.get_child_count() + 1)
	return _add_node(scene, pos, node_type, node_name)

func _input(event):
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			ui_camera.zoom *= 1.1
			ui_camera.zoom = ui_camera.zoom.clamp(Vector2(0.5, 0.5), Vector2(2.0, 2.0))
			update_scene()
		if event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			ui_camera.zoom /= 1.1
			ui_camera.zoom = ui_camera.zoom.clamp(Vector2(0.5, 0.5), Vector2(2.0, 2.0))
			update_scene()
	
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT:
		if event.pressed:
			is_panning = true
			pan_start_pos = event.position
		else:
			is_panning = false
	
	if event is InputEventMouseMotion and is_panning:
		var delta = (event.position - pan_start_pos) / ui_camera.zoom
		ui_camera.offset -= delta
		pan_start_pos = event.position
		update_scene()
	
	# Gestionarea ștergerii cu tasta Delete
	if event is InputEventKey and event.pressed and event.keycode == KEY_DELETE:
		if not connect_mode:
			if selected_for_properties != null:
				var node_to_delete = selected_for_properties
				selected_for_properties = null
				if node_to_delete.get_script() and node_to_delete.get_script().resource_path.ends_with("interax.gd"):
					interax_node = null  # Resetează referința la nodul Interax
				connections_list = connections_list.filter(func(conn): return conn[0] != node_to_delete and conn[1] != node_to_delete)
				node_to_delete.queue_free()
				if selected_connection:
					selected_connection = null
					ui_connections.selected_connection = null
					ui_connections.queue_redraw()
				update_connections()
				update_properties_panel()
				print("Nod șters:", node_to_delete.obj_name)
			elif selected_connection != null:
				connections_list.erase(selected_connection)
				selected_connection = null
				ui_connections.selected_connection = null
				ui_connections.queue_redraw()
				update_connections()
				update_properties_panel()
				print("Conexiune ștearsă")

func _on_save_button_pressed():
	is_save_mode = true
	ui_file_dialog.file_mode = FileDialog.FILE_MODE_SAVE_FILE
	ui_file_dialog.title = "Save Graph"
	ui_file_dialog.current_file = "graph.json"
	ui_file_dialog.show()

func _on_load_button_pressed():
	is_save_mode = false
	ui_file_dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILE
	ui_file_dialog.title = "Load Graph"
	ui_file_dialog.current_file = ""
	ui_file_dialog.show()

func _on_file_dialog_file_selected(path: String):
	var final_path = path
	if is_save_mode and not final_path.ends_with(".json"):
		final_path = final_path + ".json"
	if is_save_mode:
		save_graph(final_path)
	else:
		load_graph(final_path)

func _on_button_pressed():
	var new_circle = circle_scene.instantiate()
	new_circle.global_position = ui_camera.offset + Vector2(randi_range(-300, 300), randi_range(-200, 200)) / ui_camera.zoom
	new_circle.type = "Process"
	new_circle.obj_name = "Node" + str(ui_circles_container.get_child_count() + 1)
	new_circle.id = next_id
	next_id += 1
	ui_circles_container.add_child(new_circle)
	new_circle.circle_selected_for_connection.connect(_on_circle_selected_for_connection)
	new_circle.circle_selected_for_properties.connect(_on_circle_selected_for_properties)
	if ui_connections != null:
		ui_connections.update_connections(connections_list)

func _on_square_button_pressed():
	var new_square = square_scene.instantiate()
	new_square.global_position = ui_camera.offset + Vector2(randi_range(-300, 300), randi_range(-200, 200)) / ui_camera.zoom
	new_square.type = "Room"
	new_square.obj_name = "Square" + str(ui_circles_container.get_child_count() + 1)
	new_square.id = next_id
	next_id += 1
	ui_circles_container.add_child(new_square)
	new_square.circle_selected_for_connection.connect(_on_circle_selected_for_connection)
	new_square.circle_selected_for_properties.connect(_on_circle_selected_for_properties)
	if ui_connections != null:
		ui_connections.update_connections(connections_list)

func _on_icon_button_pressed():
	var new_icon = icon_scene.instantiate()
	new_icon.global_position = ui_camera.offset + Vector2(randi_range(-300, 300), randi_range(-200, 200)) / ui_camera.zoom
	new_icon.type = "Window"
	new_icon.obj_name = "Icon" + str(ui_circles_container.get_child_count() + 1)
	new_icon.id = next_id
	next_id += 1
	ui_circles_container.add_child(new_icon)
	new_icon.circle_selected_for_connection.connect(_on_circle_selected_for_connection)
	new_icon.circle_selected_for_properties.connect(_on_circle_selected_for_properties)
	if ui_connections != null:
		ui_connections.update_connections(connections_list)

func _on_door_button_pressed():
	var new_door = door_scene.instantiate()
	new_door.global_position = ui_camera.offset + Vector2(randi_range(-300, 300), randi_range(-200, 200)) / ui_camera.zoom
	new_door.type = "Door"
	new_door.obj_name = "Door" + str(ui_circles_container.get_child_count() + 1)
	new_door.id = next_id
	next_id += 1
	ui_circles_container.add_child(new_door)
	new_door.circle_selected_for_connection.connect(_on_circle_selected_for_connection)
	new_door.circle_selected_for_properties.connect(_on_circle_selected_for_properties)
	if ui_connections != null:
		ui_connections.update_connections(connections_list)

func _on_interax_button_pressed():
	if interax_node == null:
		# Creează un nou nod Interax
		var new_interax = interax_scene.instantiate()
		new_interax.global_position = ui_camera.offset + Vector2(randi_range(-300, 300), randi_range(-200, 200)) / ui_camera.zoom
		new_interax.type = "Node"
		new_interax.obj_name = "Interax"
		new_interax.id = next_id
		#new_interax.distances = [[1.0], [1.0]]
		next_id += 1
		ui_circles_container.add_child(new_interax)
		new_interax.circle_selected_for_connection.connect(_on_circle_selected_for_connection)
		new_interax.circle_selected_for_properties.connect(_on_circle_selected_for_properties)
		new_interax.execute_pressed.connect(_on_interax_execute_pressed)
		new_interax.close_pressed.connect(_on_interax_close_pressed)
		interax_node = new_interax
		print("Interax creat:", new_interax.obj_name, "ID:", new_interax.id)
	else:
		# Comută vizibilitatea nodului Interax existent
		interax_node.visible = !interax_node.visible
		print("Interax vizibilitate comutată:", interax_node.obj_name, "Visible:", interax_node.visible)
	if ui_connections != null:
		ui_connections.update_connections(connections_list)

func _on_view_3d_button_pressed():
	ui_viewport_container.visible = !ui_viewport_container.visible

func _on_connect_mode_toggled(toggled_on):
	connect_mode = toggled_on
	if not toggled_on:
		selected_circle = null
		for node in ui_circles_container.get_children():
			node.reset_connection_selection()

func is_connect_mode_active():
	return connect_mode

func _on_circle_selected_for_connection(node):
	if not connect_mode:
		return
	if node.get_script() == null:
		push_error("Nodul selectat nu are script atașat: ", node)
		return
	var script_path = node.get_script().resource_path
	if not (script_path.ends_with("Circle.gd") or script_path.ends_with("draggable_square.gd") or script_path.ends_with("draggable_icon.gd") or script_path.ends_with("draggable_door.gd") or script_path.ends_with("interax.gd")):
		push_error("Nodul selectat are un script neașteptat: ", script_path, " Node:", node)
		return
	if selected_circle == null:
		for c in ui_circles_container.get_children():
			c.reset_connection_selection()
		selected_circle = node
		node.is_selected_for_connection = true
		node.queue_redraw()
	else:
		if selected_circle != node:
			if node.get_script() == null:
				push_error("Nodul țintă nu are script atașat: ", node)
				return
			if not (script_path.ends_with("Circle.gd") or script_path.ends_with("draggable_square.gd") or script_path.ends_with("draggable_icon.gd") or script_path.ends_with("draggable_door.gd") or script_path.ends_with("interax.gd")):
				push_error("Nodul țintă are un script neașteptat: ", script_path, " Node:", node)
				return
			node.is_selected_for_connection = true
			node.queue_redraw()
			var new_connection = [selected_circle, node, "Edge" + str(connections_list.size() + 1), "Process"]
			connections_list.append(new_connection)
			print("Conexiune adăugată:", selected_circle.obj_name, "->", node.obj_name, "cu name:", new_connection[2], "și type:", new_connection[3])
			if ui_connections != null:
				ui_connections.update_connections(connections_list)
		selected_circle = null

func _on_circle_selected_for_properties(node):
	if node.get_script() == null:
		push_error("Nodul selectat pentru proprietăți nu are script atașat: ", node)
		return
	var script_path = node.get_script().resource_path
	if not (script_path.ends_with("Circle.gd") or script_path.ends_with("draggable_square.gd") or script_path.ends_with("draggable_icon.gd") or script_path.ends_with("draggable_door.gd") or script_path.ends_with("interax.gd")):
		push_error("Nodul selectat are un script neașteptat: ", script_path, " Node:", node)
		return
	selected_for_properties = node
	selected_connection = null
	ui_connections.selected_connection = null
	ui_connections.queue_redraw()
	update_properties_panel()

func _on_connection_selected(connection):
	selected_connection = connection
	selected_for_properties = null
	update_properties_panel()
	print("Conexiune selectată:", connection[0].obj_name, "->", connection[1].obj_name)

func _on_interax_execute_pressed(node):
	print("execute_pressed primit pentru Interax:", node.obj_name, "Distanțe:", node.distances)
	if not square_scene:
		push_error("square_scene nu este încărcat!")
		return
	if not ui_circles_container:
		push_error("ui_circles_container nu este găsit!")
		return
	var origin = Vector2(50, 600)  # Stânga jos
	var x_distances = node.distances[0]
	var y_distances = node.distances[1]
	var x_sum = 0.0
	var scale = 100.0  # Scalare: 1.0 unitate = 100 pixeli
	
	for x in x_distances:
		var y_sum = 0.0
		for y in y_distances:
			var new_square = square_scene.instantiate()
			new_square.global_position = origin + Vector2(x_sum * scale, -y_sum * scale)
			new_square.type = "Room"
			new_square.obj_name = "Square_" + str(x_sum) + "_" + str(y_sum)
			new_square.id = next_id
			next_id += 1
			ui_circles_container.add_child(new_square)
			new_square.circle_selected_for_connection.connect(_on_circle_selected_for_connection)
			new_square.circle_selected_for_properties.connect(_on_circle_selected_for_properties)
			print("Rectangle generat:", new_square.obj_name, "la:", new_square.global_position)
			y_sum += y
		x_sum += x
	print("Noduri Rectangle generate pentru Interax:", node.obj_name)

func _on_interax_close_pressed(node):
	if selected_for_properties == node:
		selected_for_properties = null
	if node == interax_node:
		interax_node = null  # Resetează referința la nodul Interax
	connections_list = connections_list.filter(func(conn): return conn[0] != node and conn[1] != node)
	node.queue_free()
	if selected_connection:
		selected_connection = null
		ui_connections.selected_connection = null
		ui_connections.queue_redraw()
	update_connections()
	update_properties_panel()
	print("Nod Interax șters:", node.obj_name)

func update_properties_panel():
	if selected_for_properties != null:
		ui_properties_panel.visible = true
		# Basic properties
		# Basic properties are handled by PropertiesPanel.gd
		# type selection removed

		# Delegate building the detailed properties to the PropertiesPanel script if present
		if ui_properties_panel and ui_properties_panel.has_method("build_from_node"):
			ui_properties_panel.build_from_node(selected_for_properties)

	elif selected_connection != null:
		ui_properties_panel.visible = true
		# connection properties: delegate to PropertiesPanel by passing the connections node
		if ui_properties_panel and ui_properties_panel.has_method("build_from_node"):
			# the PropertiesPanel expects a node that exposes `node_info`; `Connections` now aliases that
			ui_properties_panel.build_from_node(ui_connections)
	else:
		ui_properties_panel.visible = false
		# type selection removed

func _on_type_selected(index):
	if selected_for_properties != null:
		match index:
			0:
				selected_for_properties.type = "Input"
			1:
				selected_for_properties.type = "Output"
			2:
				selected_for_properties.type = "Process"
	elif selected_connection != null:
		var type = ["Input", "Output", "Process"][index]
		selected_connection[3] = type
		print("Tip conexiune actualizat:", selected_connection[0].obj_name, "->", selected_connection[1].obj_name, "la:", type)

func _on_nodeinfo_type_selected(index):
	# index 0 -> ax, 1 -> nonax
	if selected_for_properties != null and selected_for_properties.has_method("get"):
		var ni = selected_for_properties.get("node_info")
		if ni != null:
			ni["type"] = "ax" if index == 0 else "nonax"
			update_properties_panel()

func _on_panel_property_changed(node, key, value):
	# Persist changes from the PropertiesPanel script into the scene and UI
	if node == null:
		return
	# node_info updates are already written by the panel; ensure any special fields sync
	if key == "name":
		node.obj_name = value
	elif key == "distances":
		node.distances = value
		if node.has_method("update_labels"):
			node.update_labels()
	# After any change, redraw connections and refresh UI
	update_connections()
	update_properties_panel()

func _on_nodeinfo_has_column_toggled(pressed: bool):
	if selected_for_properties != null and selected_for_properties.has_method("get"):
		var ni = selected_for_properties.get("node_info")
		if ni != null:
			ni["has_column"] = pressed
			if not pressed:
				ni["column_type"] = ""
			if ui_nodeinfo_column_type:
				ui_nodeinfo_column_type.visible = pressed
			update_properties_panel()

func _on_nodeinfo_column_type_changed(new_text: String):
	if selected_for_properties != null and selected_for_properties.has_method("get"):
		var ni = selected_for_properties.get("node_info")
		if ni != null:
			ni["column_type"] = new_text
			update_properties_panel()

func _on_name_changed(new_text):
	if selected_for_properties != null:
		selected_for_properties.obj_name = new_text
		# also update node_info.name when present
		if selected_for_properties.has_method("get"):
			var ni = selected_for_properties.get("node_info")
			if ni != null:
				ni["name"] = new_text
	elif selected_connection != null:
		selected_connection[2] = new_text
		print("Nume conexiune actualizat:", selected_connection[0].obj_name, "->", selected_connection[1].obj_name, "la:", new_text)

func _on_distances_changed(new_text):
	if selected_for_properties != null and selected_for_properties.get_script().resource_path.ends_with("interax.gd"):
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
			selected_for_properties.distances = distances
			selected_for_properties.update_labels()
			print("Distanțe actualizate pentru Interax:", selected_for_properties.obj_name, distances)
		else:
			distances = selected_for_properties.distances
			# distances UI moved to PropertiesPanel; just log and keep existing values
			print("Format invalid pentru distanțe:", new_text)

func update_connections():
	if ui_connections != null:
		ui_connections.update_connections(connections_list)
		print("Connections list:", connections_list)
	if ui_background != null:
		ui_background.queue_redraw()

func update_scene():
	update_connections()

func save_graph(file_path: String):
	var graph_data = {
		"nodes": [],
		"edges": [],
		"version": "1.0",
		"timestamp": Time.get_datetime_string_from_system()
	}
	
	for node in ui_circles_container.get_children():
		if node.get_script() == null:
			push_error("Nodul nu are script atașat: ", node)
			continue
		var script_path = node.get_script().resource_path
		if not (script_path.ends_with("Circle.gd") or script_path.ends_with("draggable_square.gd") or script_path.ends_with("draggable_icon.gd") or script_path.ends_with("draggable_door.gd") or script_path.ends_with("interax.gd")):
			push_error("Nodul are un script neașteptat: ", script_path, " Node:", node)
			continue
		var node_type = node.get_script().resource_path.get_file().replace(".gd", "")
		var node_shape = node_type.replace("draggable_", "").capitalize()
		var node_data = {
			"id": node.id,
			"type": node.type.to_lower(),
			"label": node.obj_name,
			"pos_x": node.global_position.x,
			"pos_y": node.global_position.y,
			"node_shape": node_shape,
			"visible": node.visible
		}
		if node_shape == "Interax":
			node_data["distances"] = node.distances
		# persist node_info when present
		var ni = null
		if node.has_method("get"):
			ni = node.get("node_info")
		if ni != null:
			node_data["node_info"] = ni
		graph_data["nodes"].append(node_data)
	
	for connection in connections_list:
		if connection[0].get_script() == null or connection[1].get_script() == null:
			push_error("Conexiune invalidă: unul dintre noduri nu are script atașat: ", connection)
			continue
		var source_script = connection[0].get_script().resource_path
		var target_script = connection[1].get_script().resource_path
		if not (source_script.ends_with("Circle.gd") or source_script.ends_with("draggable_square.gd") or source_script.ends_with("draggable_icon.gd") or source_script.ends_with("draggable_door.gd") or source_script.ends_with("interax.gd")):
			push_error("Nod sursă are un script neașteptat: ", source_script, " Node:", connection[0])
			continue
		if not (target_script.ends_with("Circle.gd") or target_script.ends_with("draggable_square.gd") or target_script.ends_with("draggable_icon.gd") or target_script.ends_with("draggable_door.gd") or target_script.ends_with("interax.gd")):
			push_error("Nod țintă are un script neașteptat: ", target_script, " Node:", connection[1])
			continue
		var edge_data = {
			"source": connection[0].id,
			"target": connection[1].id,
			"label": connection[2],
			"type": connection[3].to_lower()
		}
		graph_data["edges"].append(edge_data)
	
	var file = FileAccess.open(file_path, FileAccess.WRITE)
	if file == null:
		push_error("Eroare la deschiderea fișierului pentru scriere: ", file_path)
		return
	file.store_string(JSON.stringify(graph_data, "  ", false))
	file.close()
	print("Graf salvat în: ", file_path)

func load_graph(file_path: String):
	if not FileAccess.file_exists(file_path):
		push_error("Fișierul nu există: ", file_path)
		return
	
	var file = FileAccess.open(file_path, FileAccess.READ)
	if file == null:
		push_error("Eroare la deschiderea fișierului pentru citire: ", file_path)
		return
	var json_text = file.get_as_text()
	file.close()
	
	var json = JSON.new()
	var error = json.parse(json_text)
	if error != OK:
		push_error("Eroare la parsarea JSON: ", json.get_error_message())
		return
	
	var graph_data = json.data
	if typeof(graph_data) != TYPE_DICTIONARY or not graph_data.has("nodes") or not graph_data.has("edges"):
		push_error("Format JSON invalid: lipsesc 'nodes' sau 'edges'")
		return
	
	# Șterge nodurile existente și resetează interax_node
	for node in ui_circles_container.get_children():
		node.queue_free()
	connections_list.clear()
	interax_node = null
	
	# Resetare ID și hartă pentru ID-urile originale
	next_id = 0
	var id_map = {}
	
	# Creează nodurile din JSON
	for node_data in graph_data["nodes"]:
		var new_node
		var node_shape = node_data.get("node_shape", "Circle").replace("Draggable ", "").replace("draggable_", "").capitalize()
		match node_shape:
			"Circle":
				new_node = circle_scene.instantiate()
			"Square":
				new_node = square_scene.instantiate()
			"Icon":
				new_node = icon_scene.instantiate()
			"Door":
				new_node = door_scene.instantiate()
			"Interax":
				if interax_node != null:
					print("Ignor nod Interax suplimentar din JSON, deoarece Interax este unic")
					continue
				new_node = interax_scene.instantiate()
			_:
				push_error("Tip de nod necunoscut: ", node_shape)
				continue
		
		new_node.global_position = Vector2(node_data["pos_x"], node_data["pos_y"])
		new_node.type = node_data["type"].capitalize()
		new_node.obj_name = node_data["label"]
		new_node.id = next_id
		new_node.visible = node_data.get("visible", true)
		# Restore node_info if saved; ensure index aligns with assigned id
		var saved_ni = node_data.get("node_info", null)
		if saved_ni != null:
			new_node.node_info = saved_ni
			new_node.node_info["index"] = new_node.id
			# Prefer saved name if present
			if new_node.node_info.has("name"):
				new_node.obj_name = new_node.node_info["name"]
		if node_shape == "Interax":
			#new_node.distances = node_data.get("distances", [[1.0], [1.0]])
			new_node.update_labels()
			interax_node = new_node
		id_map[node_data["id"]] = new_node
		next_id += 1
		ui_circles_container.add_child(new_node)
		new_node.circle_selected_for_connection.connect(_on_circle_selected_for_connection)
		new_node.circle_selected_for_properties.connect(_on_circle_selected_for_properties)
		if node_shape == "Interax":
			new_node.execute_pressed.connect(_on_interax_execute_pressed)
			new_node.close_pressed.connect(_on_interax_close_pressed)
	
	# Creează conexiunile din JSON
	for edge_data in graph_data["edges"]:
		var source_node = id_map.get(edge_data["source"])
		var target_node = id_map.get(edge_data["target"])
		if source_node and target_node:
			var obj_name = edge_data.get("label", "Edge" + str(connections_list.size() + 1))
			var type = edge_data.get("type", "Process").capitalize()
			connections_list.append([source_node, target_node, obj_name, type])
			print("Conexiune restaurată:", source_node.obj_name, "->", target_node.obj_name, "cu name:", obj_name, "și type:", type)
		else:
			push_error("Conexiune invalidă: nod sursă sau țintă lipsă pentru ", edge_data)
	
	# Actualizează conexiunile vizuale
	if ui_connections != null:
		ui_connections.update_connections(connections_list)
		ui_connections.queue_redraw()
	update_scene()
	print("Graf încărcat din: ", file_path)
