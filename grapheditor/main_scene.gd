extends Node

@onready var circles_container = $CirclesContainer
@onready var button = $CanvasLayer/AddCircleButton
@onready var square_button = $CanvasLayer/AddSquareButton
@onready var icon_button = $CanvasLayer/AddIconButton
@onready var door_button = $CanvasLayer/AddDoorButton
@onready var interax_button = $CanvasLayer/AddInteraxButton
@onready var view_3d_button = $CanvasLayer/View3DButton
@onready var viewport_container = $CanvasLayer/SubViewportContainer
@onready var connections = $Connections
@onready var connect_mode_button = $CanvasLayer/ConnectModeButton
@onready var camera = $Camera2D
@onready var file_dialog = $CanvasLayer/FileDialog
@onready var save_button = $CanvasLayer/SaveButton
@onready var load_button = $CanvasLayer/LoadButton
@onready var background = $Background
@onready var properties_panel = $CanvasLayer/PropertiesPanel
@onready var type_option_button = $CanvasLayer/PropertiesPanel/TypeOptionButton
@onready var name_line_edit = $CanvasLayer/PropertiesPanel/NameLineEdit
@onready var distances_line_edit = $CanvasLayer/PropertiesPanel/DistancesLineEdit

var circle_scene = preload("res://Circle.tscn")
var square_scene = preload("res://Square.tscn")
var icon_scene = preload("res://Icon.tscn")
var door_scene = preload("res://Door.tscn")
var interax_scene = preload("res://Interax.tscn")
var connections_list = []
var selected_circle = null
var selected_for_properties = null
var selected_connection = null
var connect_mode = false
var is_panning = false
var pan_start_pos = Vector2.ZERO
var next_id = 0
var is_save_mode = false
var interax_node = null  # Referință la nodul Interax unic

func _ready():
	# Verifică dacă nodurile sunt găsite
	if button == null:
		push_error("Butonul 'AddCircleButton' nu a fost găsit!")
		return
	if save_button == null:
		push_error("Butonul 'SaveButton' nu a fost găsit!")
		return
	if load_button == null:
		push_error("Butonul 'LoadButton' nu a fost găsit!")
		return
	if file_dialog == null:
		push_error("FileDialog nu a fost găsit!")
		return
	if square_button == null:
		push_error("Butonul 'AddSquareButton' nu a fost găsit!")
		return
	if icon_button == null:
		push_error("Butonul 'AddIconButton' nu a fost găsit!")
		return
	if door_button == null:
		push_error("Butonul 'AddDoorButton' nu a fost găsit!")
		return
	if interax_button == null:
		push_error("Butonul 'AddInteraxButton' nu a fost găsit!")
		return
	if view_3d_button == null:
		push_error("Butonul 'View3DButton' nu a fost găsit!")
		return
	if viewport_container == null:
		push_error("SubViewportContainer nu a fost găsit!")
		return
	if circles_container == null:
		push_error("CirclesContainer nu a fost găsit!")
		return
	if connections == null:
		push_error("Connections nu a fost găsit! Verifică ierarhia scenei.")
		return
	if connect_mode_button == null:
		push_error("ConnectModeButton nu a fost găsit!")
		return
	if camera == null:
		push_error("Camera2D nu a fost găsit!")
		return
	if background == null:
		push_error("Background nu a fost găsit!")
		return
	if properties_panel == null:
		push_error("PropertiesPanel nu a fost găsit!")
		return
	if type_option_button == null:
		push_error("TypeOptionButton nu a fost găsit!")
		return
	if name_line_edit == null:
		push_error("NameLineEdit nu a fost găsit!")
		return
	if distances_line_edit == null:
		push_error("DistancesLineEdit nu a fost găsit!")
		return
	
	# Configurează FileDialog pentru a filtra doar fișiere .json
	file_dialog.filters = ["*.json ; JSON Files"]
	file_dialog.access = FileDialog.ACCESS_FILESYSTEM
	
	# Conectează semnalele
	save_button.pressed.connect(_on_save_button_pressed)
	load_button.pressed.connect(_on_load_button_pressed)
	file_dialog.file_selected.connect(_on_file_dialog_file_selected)
	button.pressed.connect(_on_button_pressed)
	square_button.pressed.connect(_on_square_button_pressed)
	icon_button.pressed.connect(_on_icon_button_pressed)
	door_button.pressed.connect(_on_door_button_pressed)
	interax_button.pressed.connect(_on_interax_button_pressed)
	view_3d_button.pressed.connect(_on_view_3d_button_pressed)
	connect_mode_button.toggled.connect(_on_connect_mode_toggled)
	type_option_button.item_selected.connect(_on_type_selected)
	name_line_edit.text_changed.connect(_on_name_changed)
	distances_line_edit.text_changed.connect(_on_distances_changed)
	connections.connection_selected.connect(_on_connection_selected)
	
	# Inițializează opțiunile pentru TypeOptionButton
	type_option_button.add_item("Input", 0)
	type_option_button.add_item("Output", 1)
	type_option_button.add_item("Process", 2)
	
	# Creează un cerc inițial
	var initial_circle = circle_scene.instantiate()
	initial_circle.global_position = Vector2(100, 100)
	initial_circle.type = "Input"
	initial_circle.obj_name = "Node1"
	initial_circle.id = next_id
	next_id += 1
	circles_container.add_child(initial_circle)
	
	# Conectează semnalele pentru noduri
	for node in circles_container.get_children():
		node.circle_selected_for_connection.connect(_on_circle_selected_for_connection)
		node.circle_selected_for_properties.connect(_on_circle_selected_for_properties)
		if node.get_script() and node.get_script().resource_path.ends_with("interax.gd"):
			node.execute_pressed.connect(_on_interax_execute_pressed)
			node.close_pressed.connect(_on_interax_close_pressed)
	
	# Depanare: Loghează scripturile nodurilor
	for node in circles_container.get_children():
		var script = node.get_script()
		print("Node:", node, "Script:", script.resource_path if script else "No script")
	
	# Ascunde panoul de proprietăți, scena 3D și dialogul de fișiere inițial
	properties_panel.visible = false
	viewport_container.visible = false
	file_dialog.visible = false

func _input(event):
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			camera.zoom *= 1.1
			camera.zoom = camera.zoom.clamp(Vector2(0.5, 0.5), Vector2(2.0, 2.0))
			update_scene()
		if event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			camera.zoom /= 1.1
			camera.zoom = camera.zoom.clamp(Vector2(0.5, 0.5), Vector2(2.0, 2.0))
			update_scene()
	
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT:
		if event.pressed:
			is_panning = true
			pan_start_pos = event.position
		else:
			is_panning = false
	
	if event is InputEventMouseMotion and is_panning:
		var delta = (event.position - pan_start_pos) / camera.zoom
		camera.offset -= delta
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
					connections.selected_connection = null
					connections.queue_redraw()
				update_connections()
				update_properties_panel()
				print("Nod șters:", node_to_delete.obj_name)
			elif selected_connection != null:
				connections_list.erase(selected_connection)
				selected_connection = null
				connections.selected_connection = null
				connections.queue_redraw()
				update_connections()
				update_properties_panel()
				print("Conexiune ștearsă")

func _on_save_button_pressed():
	is_save_mode = true
	file_dialog.file_mode = FileDialog.FILE_MODE_SAVE_FILE
	file_dialog.title = "Save Graph"
	file_dialog.current_file = "graph.json"
	file_dialog.show()

func _on_load_button_pressed():
	is_save_mode = false
	file_dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILE
	file_dialog.title = "Load Graph"
	file_dialog.current_file = ""
	file_dialog.show()

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
	new_circle.global_position = camera.offset + Vector2(randi_range(-300, 300), randi_range(-200, 200)) / camera.zoom
	new_circle.type = "Process"
	new_circle.obj_name = "Node" + str(circles_container.get_child_count() + 1)
	new_circle.id = next_id
	next_id += 1
	circles_container.add_child(new_circle)
	new_circle.circle_selected_for_connection.connect(_on_circle_selected_for_connection)
	new_circle.circle_selected_for_properties.connect(_on_circle_selected_for_properties)
	if connections != null:
		connections.update_connections(connections_list)

func _on_square_button_pressed():
	var new_square = square_scene.instantiate()
	new_square.global_position = camera.offset + Vector2(randi_range(-300, 300), randi_range(-200, 200)) / camera.zoom
	new_square.type = "Process"
	new_square.obj_name = "Square" + str(circles_container.get_child_count() + 1)
	new_square.id = next_id
	next_id += 1
	circles_container.add_child(new_square)
	new_square.circle_selected_for_connection.connect(_on_circle_selected_for_connection)
	new_square.circle_selected_for_properties.connect(_on_circle_selected_for_properties)
	if connections != null:
		connections.update_connections(connections_list)

func _on_icon_button_pressed():
	var new_icon = icon_scene.instantiate()
	new_icon.global_position = camera.offset + Vector2(randi_range(-300, 300), randi_range(-200, 200)) / camera.zoom
	new_icon.type = "Process"
	new_icon.obj_name = "Icon" + str(circles_container.get_child_count() + 1)
	new_icon.id = next_id
	next_id += 1
	circles_container.add_child(new_icon)
	new_icon.circle_selected_for_connection.connect(_on_circle_selected_for_connection)
	new_icon.circle_selected_for_properties.connect(_on_circle_selected_for_properties)
	if connections != null:
		connections.update_connections(connections_list)

func _on_door_button_pressed():
	var new_door = door_scene.instantiate()
	new_door.global_position = camera.offset + Vector2(randi_range(-300, 300), randi_range(-200, 200)) / camera.zoom
	new_door.type = "Process"
	new_door.obj_name = "Door" + str(circles_container.get_child_count() + 1)
	new_door.id = next_id
	next_id += 1
	circles_container.add_child(new_door)
	new_door.circle_selected_for_connection.connect(_on_circle_selected_for_connection)
	new_door.circle_selected_for_properties.connect(_on_circle_selected_for_properties)
	if connections != null:
		connections.update_connections(connections_list)

func _on_interax_button_pressed():
	if interax_node == null:
		# Creează un nou nod Interax
		var new_interax = interax_scene.instantiate()
		new_interax.global_position = camera.offset + Vector2(randi_range(-300, 300), randi_range(-200, 200)) / camera.zoom
		new_interax.type = "Process"
		new_interax.obj_name = "Interax"
		new_interax.id = next_id
		#new_interax.distances = [[1.0], [1.0]]
		next_id += 1
		circles_container.add_child(new_interax)
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
	if connections != null:
		connections.update_connections(connections_list)

func _on_view_3d_button_pressed():
	viewport_container.visible = !viewport_container.visible

func _on_connect_mode_toggled(toggled_on):
	connect_mode = toggled_on
	if not toggled_on:
		selected_circle = null
		for node in circles_container.get_children():
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
		for c in circles_container.get_children():
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
			if connections != null:
				connections.update_connections(connections_list)
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
	connections.selected_connection = null
	connections.queue_redraw()
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
	if not circles_container:
		push_error("circles_container nu este găsit!")
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
			new_square.type = "Process"
			new_square.obj_name = "Square_" + str(x_sum) + "_" + str(y_sum)
			new_square.id = next_id
			next_id += 1
			circles_container.add_child(new_square)
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
		connections.selected_connection = null
		connections.queue_redraw()
	update_connections()
	update_properties_panel()
	print("Nod Interax șters:", node.obj_name)

func update_properties_panel():
	if selected_for_properties != null:
		properties_panel.visible = true
		name_line_edit.text = selected_for_properties.obj_name
		distances_line_edit.visible = selected_for_properties.get_script().resource_path.ends_with("interax.gd")
		if distances_line_edit.visible:
			var distances = selected_for_properties.distances
			distances_line_edit.text = "x:" + str(distances[0]).replace("[", "").replace("]", "") + "; y:" + str(distances[1]).replace("[", "").replace("]", "")
		else:
			distances_line_edit.text = ""
		match selected_for_properties.type:
			"Input":
				type_option_button.select(0)
			"Output":
				type_option_button.select(1)
			"Process":
				type_option_button.select(2)
			_:
				type_option_button.select(-1)
	elif selected_connection != null:
		properties_panel.visible = true
		name_line_edit.text = selected_connection[2]
		distances_line_edit.visible = false
		distances_line_edit.text = ""
		match selected_connection[3]:
			"Input":
				type_option_button.select(0)
			"Output":
				type_option_button.select(1)
			"Process":
				type_option_button.select(2)
			_:
				type_option_button.select(-1)
	else:
		properties_panel.visible = false
		name_line_edit.text = ""
		distances_line_edit.text = ""
		type_option_button.select(-1)

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

func _on_name_changed(new_text):
	if selected_for_properties != null:
		selected_for_properties.obj_name = new_text
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
			distances_line_edit.text = "x:" + str(distances[0]).replace("[", "").replace("]", "") + "; y:" + str(distances[1]).replace("[", "").replace("]", "")
			print("Format invalid pentru distanțe:", new_text)

func update_connections():
	if connections != null:
		connections.update_connections(connections_list)
		print("Connections list:", connections_list)
	if background != null:
		background.queue_redraw()

func update_scene():
	update_connections()

func save_graph(file_path: String):
	var graph_data = {
		"nodes": [],
		"edges": [],
		"version": "1.0",
		"timestamp": Time.get_datetime_string_from_system()
	}
	
	for node in circles_container.get_children():
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
	for node in circles_container.get_children():
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
		if node_shape == "Interax":
			#new_node.distances = node_data.get("distances", [[1.0], [1.0]])
			new_node.update_labels()
			interax_node = new_node
		id_map[node_data["id"]] = new_node
		next_id += 1
		circles_container.add_child(new_node)
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
	if connections != null:
		connections.update_connections(connections_list)
		connections.queue_redraw()
	update_scene()
	print("Graf încărcat din: ", file_path)
