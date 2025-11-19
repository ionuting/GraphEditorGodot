extends Node

# Load UUID generator and JSON Schema Exporter
const UUIDGenerator = preload("res://UUIDGenerator.gd")
const JSONSchemaExporter = preload("res://JSONSchemaExporter.gd")

# --- UI references (onready)
@onready var ui_circles_container = $CirclesContainer
@onready var ui_button = $CanvasLayer/MainHBox/LeftPanel/AddCircleButton
@onready var ui_square_button = $CanvasLayer/MainHBox/LeftPanel/AddSquareButton
@onready var ui_icon_button = $CanvasLayer/MainHBox/LeftPanel/AddIconButton
@onready var ui_door_button = $CanvasLayer/MainHBox/LeftPanel/AddDoorButton
@onready var ui_interax_button = $CanvasLayer/MainHBox/LeftPanel/AddInteraxButton
@onready var ui_level_config_button = $CanvasLayer/MainHBox/LeftPanel/LevelConfigButton
@onready var ui_view_3d_button = $CanvasLayer/MainHBox/LeftPanel/View3DButton
@onready var ui_viewport_container = $CanvasLayer/SubViewportContainer
@onready var ui_connections = $Connections
@onready var ui_connect_mode_button = $CanvasLayer/MainHBox/LeftPanel/ConnectModeButton
@onready var ui_camera = $Camera2D
@onready var ui_file_dialog = $CanvasLayer/FileDialog
@onready var ui_save_button = $CanvasLayer/MainHBox/LeftPanel/SaveButton
@onready var ui_load_button = $CanvasLayer/MainHBox/LeftPanel/LoadButton
@onready var ui_background = $Background
@onready var ui_properties_panel = $CanvasLayer/MainHBox/RightPanel/PropertiesPanel
@onready var ui_export_graphml_button = $CanvasLayer/MainHBox/LeftPanel/ExportGraphMLButton
@onready var ui_export_schema_button = $CanvasLayer/MainHBox/LeftPanel/ExportSchemaButton
@onready var ui_undo_button = $CanvasLayer/MainHBox/LeftPanel/UndoButton
@onready var ui_redo_button = $CanvasLayer/MainHBox/LeftPanel/RedoButton
@onready var ui_multi_select_label = $CanvasLayer/MainHBox/LeftPanel/MultiSelectLabel
@onready var ui_multi_select_cancel_button = $CanvasLayer/MainHBox/LeftPanel/CancelMultiSelectButton
@onready var ui_layer_panel = $CanvasLayer/MainHBox/RightPanel/LayersScroll/LayersVBox
@onready var ui_add_layer_button = $CanvasLayer/MainHBox/RightPanel/AddLayerButton

# --- Scenes (preloads) (names match usages below)
var circle_scene = preload("res://Circle.tscn")
var square_scene = preload("res://Square.tscn")
var icon_scene = preload("res://Icon.tscn")
var door_scene = preload("res://Door.tscn")
var interax_scene = preload("res://Interax.tscn")

# --- State variables
var connect_mode = false
var selected_circle = null
var selected_connection = null
# Attach mode variables
var attach_to_midpoint_mode = false
var attach_target_connection = null
# Nou: sistem simplu pentru editarea coordonatelor Interax
var interax_coordinates_data = {"x_values": [1.0, 2.0, 3.0], "y_values": [1.0, 2.0, 3.0]}
var ui_interax_editor = null
# Nou: sistem pentru configurarea nivelurilor proiectului
var level_config_data = {
	"project_name": "Proiect Nou",
	"levels": [
		{"name": "Fundații", "bottom_level": -1.75, "level_height": 1.75, "top_level": 0.00},
		{"name": "Parter", "bottom_level": 0.00, "level_height": 2.80, "top_level": 2.80},
		{"name": "Etaj 1", "bottom_level": 2.80, "level_height": 2.80, "top_level": 5.60},
		{"name": "Etaj 2", "bottom_level": 5.60, "level_height": 2.80, "top_level": 8.40}
	]
}
var ui_level_editor = null
# Nou: stare pentru multi-select al nodurilor Room cu meniu contextual
var room_multi_select_mode = false
var room_source_node = null
var room_connected_nodes = []
var room_connection_type = "" # "nodes" sau "windows_doors"
var room_context_menu = null

# --- State ---
var connections_list = []
var selected_for_properties = null
var is_panning = false
var pan_start_pos = Vector2.ZERO
var next_id = 0
var is_save_mode = false
var is_graphml_export_mode = false
var is_graphml_load_mode = false
var is_schema_export_mode = false
var is_schema_import_mode = false
var undo_stack = []
var redo_stack = []
var _undo_disabled = false

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

	# Set initial visibility for multi-select UI
	if ui_multi_select_label:
		ui_multi_select_label.visible = false
	if ui_multi_select_cancel_button:
		ui_multi_select_cancel_button.visible = false


# --- Export GraphML-like JSON ---
func _on_export_graphml_button_pressed():
	is_graphml_export_mode = true
	ui_file_dialog.file_mode = FileDialog.FILE_MODE_SAVE_FILE
	ui_file_dialog.title = "Export GraphML JSON"
	ui_file_dialog.current_file = "graph.graphml.json"
	ui_file_dialog.show()


# Runtime references to dynamic NodeInfo UI controls (created at runtime)
var ui_nodeinfo_index_label = null
var ui_nodeinfo_type_option = null
var ui_nodeinfo_has_column = null
var ui_nodeinfo_column_type = null

func _ready():
	# Ensure LayerManager is available
	if not has_node("/root/LayerManager"):
		push_error("LayerManager singleton not found! Check project.godot autoload settings.")
	
	_init_ui()
	_setup_layer_panel()
	_build_properties_panel()
	_connect_signals()
	_create_initial_circle()
	_hide_panels()
	_load_interax_coordinates_from_json()
	_load_level_config_from_json()
	if ui_properties_panel and ui_properties_panel.has_method("connect"):
		var p = ui_properties_panel
		if p.has_method("build_from_node"):
			p.connect("property_changed", Callable(self, "_on_panel_property_changed"))
# Setup the Layer Panel UI (now in Main.tscn)
func _setup_layer_panel():
	# Connect to LayerManager signals
	if has_node("/root/LayerManager"):
		var layer_mgr = get_node("/root/LayerManager")
		layer_mgr.layer_added.connect(_on_layer_added)
		layer_mgr.layer_removed.connect(_on_layer_removed)
		layer_mgr.layer_visibility_changed.connect(_on_layer_visibility_changed)
		layer_mgr.layers_loaded.connect(_refresh_layer_panel)
	
	# Connect add layer button
	if ui_add_layer_button:
		ui_add_layer_button.pressed.connect(_on_add_layer_pressed)
	
	# Populate with existing layers
	_refresh_layer_panel()
	print("Layer panel setup complete")

# Refresh the layer panel with current layers
func _refresh_layer_panel():
	if ui_layer_panel == null:
		return
	
	# Clear existing items
	for child in ui_layer_panel.get_children():
		child.queue_free()
	
	# Add layer items
	if has_node("/root/LayerManager"):
		var layer_mgr = get_node("/root/LayerManager")
		for layer_name in layer_mgr.get_all_layers():
			var layer_data = layer_mgr.get_layer_data(layer_name)
			_add_layer_item(layer_name, layer_data)

# Add a single layer item to the panel
func _add_layer_item(layer_name: String, layer_data: Dictionary):
	if ui_layer_panel == null:
		return
	
	var hbox = HBoxContainer.new()
	hbox.name = "Layer_" + layer_name
	
	# Visibility checkbox
	var checkbox = CheckBox.new()
	checkbox.button_pressed = layer_data.get("visible", true)
	checkbox.toggled.connect(_on_layer_checkbox_toggled.bind(layer_name))
	hbox.add_child(checkbox)
	
	# Color indicator
	var color_rect = ColorRect.new()
	color_rect.custom_minimum_size = Vector2(16, 16)
	color_rect.color = layer_data.get("color", Color.WHITE)
	hbox.add_child(color_rect)
	
	# Layer name label
	var label = Label.new()
	label.text = layer_name
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox.add_child(label)
	
	ui_layer_panel.add_child(hbox)

# Handle layer checkbox toggle
func _on_layer_checkbox_toggled(pressed: bool, layer_name: String):
	if has_node("/root/LayerManager"):
		var layer_mgr = get_node("/root/LayerManager")
		layer_mgr.set_layer_visibility(layer_name, pressed)
		_update_nodes_visibility()

# Handle add layer button
func _on_add_layer_pressed():
	_show_add_layer_dialog()

# Show dialog to add a new layer
func _show_add_layer_dialog():
	var dialog = Window.new()
	dialog.title = "Add New Layer"
	dialog.size = Vector2i(300, 150)
	dialog.position = Vector2i(200, 200)
	
	var vbox = VBoxContainer.new()
	dialog.add_child(vbox)
	vbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	vbox.add_theme_constant_override("separation", 10)
	
	# Layer name
	var name_label = Label.new()
	name_label.text = "Layer Name:"
	vbox.add_child(name_label)
	
	var name_edit = LineEdit.new()
	name_edit.name = "LayerNameEdit"
	name_edit.placeholder_text = "e.g., electrical, plumbing"
	vbox.add_child(name_edit)
	
	# Layer color
	var color_label = Label.new()
	color_label.text = "Layer Color:"
	vbox.add_child(color_label)
	
	var color_picker = ColorPickerButton.new()
	color_picker.name = "LayerColorPicker"
	color_picker.color = Color(randf(), randf(), randf(), 1.0)
	vbox.add_child(color_picker)
	
	# Buttons
	var button_box = HBoxContainer.new()
	vbox.add_child(button_box)
	
	var add_btn = Button.new()
	add_btn.text = "Add"
	add_btn.pressed.connect(_on_add_layer_confirmed.bind(dialog))
	button_box.add_child(add_btn)
	
	var cancel_btn = Button.new()
	cancel_btn.text = "Cancel"
	cancel_btn.pressed.connect(func(): dialog.queue_free())
	button_box.add_child(cancel_btn)
	
	get_tree().root.add_child(dialog)
	dialog.popup_centered()

# Handle add layer confirmation
func _on_add_layer_confirmed(dialog: Window):
	var name_edit = dialog.find_child("LayerNameEdit", true, false)
	var color_picker = dialog.find_child("LayerColorPicker", true, false)
	
	if name_edit == null or color_picker == null:
		print("Error: Could not find dialog controls")
		dialog.queue_free()
		return
	
	var layer_name = name_edit.text.strip_edges()
	var layer_color = color_picker.color
	
	if layer_name == "":
		print("Error: Layer name cannot be empty")
		return
	
	if has_node("/root/LayerManager"):
		var layer_mgr = get_node("/root/LayerManager")
		if layer_mgr.add_layer(layer_name, layer_color, true):
			print("Layer added: ", layer_name)
	
	dialog.queue_free()

# Handle layer added signal
func _on_layer_added(layer_name: String):
	_refresh_layer_panel()

# Handle layer removed signal
func _on_layer_removed(layer_name: String):
	_refresh_layer_panel()

# Handle layer visibility changed signal
func _on_layer_visibility_changed(layer_name: String, visible: bool):
	_update_nodes_visibility()
	print("Layer visibility changed: ", layer_name, " -> ", visible)

# Update visibility of all nodes based on their layer
func _update_nodes_visibility():
	if not has_node("/root/LayerManager"):
		return
	
	var layer_mgr = get_node("/root/LayerManager")
	for node in ui_circles_container.get_children():
		if node.has_method("get") and node.get("node_info") != null:
			var node_layer = node.node_info.get("layer", "structural")
			var should_be_visible = layer_mgr.is_layer_visible(node_layer)
			node.visible = should_be_visible
	update_connections()

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
	ui_level_config_button.pressed.connect(_on_level_config_button_pressed)
	ui_view_3d_button.pressed.connect(_on_view_3d_button_pressed)
	ui_connect_mode_button.toggled.connect(_on_connect_mode_toggled)
	# name/distances editing is handled by PropertiesPanel.gd now
	
	# Connection signals - verify they are connected
	print("DEBUG: Connecting connection_selected signal from ui_connections")
	if ui_connections:
		ui_connections.connection_selected.connect(_on_connection_selected)
		ui_connections.midpoint_selected_for_connection.connect(_on_midpoint_selected_for_connection)
		print("DEBUG: Signals connected successfully")
	else:
		push_error("ui_connections is null! Cannot connect signals!")



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
	# Nu mai conectăm semnalele pentru nodurile Interax - folosim editorul separat
	return n

func _add_node_random(scene, node_type: String, name_prefix: String):
	var pos = ui_camera.offset + Vector2(randi_range(-300, 300), randi_range(-200, 200)) / ui_camera.zoom
	var node_name = name_prefix + str(ui_circles_container.get_child_count() + 1)
	return _add_node(scene, pos, node_type, node_name)

func _input(event):
	# ESC anulează orice comandă și deselectează
	if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		# Cancel attach mode first if active
		if attach_to_midpoint_mode:
			_cancel_attach_mode()
			get_viewport().set_input_as_handled()
			return
		
		_deselect_all()
		if room_multi_select_mode:
			_cancel_room_multi_select()
		get_viewport().set_input_as_handled()
		return
	
	# Click stânga - verifică dacă este pe UI sau pe canvas
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		if not connect_mode and not room_multi_select_mode:
			# Verifică dacă click-ul este în zona UI (panourile fixe)
			if _is_click_on_ui_panel(event.position):
				return  # Nu deselecta dacă click-ul este pe UI
			
			# Verifică dacă s-a dat click pe vreun nod
			var clicked_on_node = false
			for node in ui_circles_container.get_children():
				if _is_mouse_over_node(node, event.position):
					clicked_on_node = true
					break
			
			# Dacă nu s-a dat click pe niciun nod și nu e pe UI, deselectează
			# FIX: Check if a connection is selected before deselecting everything
			# This prevents the race condition where clicking on a connection midpoint
			# would select the connection (handled by connections.gd), but then
			# main_scene.gd would immediately deselect it because the click wasn't on a node
			if not clicked_on_node and selected_connection == null:
				_deselect_all()
	
	# Handle zoom - only if mouse is NOT over UI panels
	if event is InputEventMouseButton and event.button_index in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN]:
		var mouse_pos = get_viewport().get_mouse_position()
		
		# Check if mouse is over UI panels - if so, don't zoom
		if _is_mouse_over_ui_panels(mouse_pos):
			return  # Let UI panels handle scroll
		
		# Only zoom if mouse is in canvas area
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			ui_camera.zoom *= 1.1
			ui_camera.zoom = ui_camera.zoom.clamp(Vector2(0.5, 0.5), Vector2(2.0, 2.0))
			update_scene()
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			ui_camera.zoom /= 1.1
			ui_camera.zoom = ui_camera.zoom.clamp(Vector2(0.5, 0.5), Vector2(2.0, 2.0))
			update_scene()
	
	# Click dreapta - prioritate pentru meniul Room în modul conexiune
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT:
		if event.pressed:
			# Verifică dacă trebuie să gestionăm Room menu sau multi-select
			var handled = false
			if room_multi_select_mode:
				# Dacă suntem în modul multi-select, finalizează
				_finish_room_multi_select()
				get_viewport().set_input_as_handled()
				handled = true
			elif connect_mode:
				# Verifică dacă s-a dat click pe un Room pentru meniu
				for node in ui_circles_container.get_children():
					if node.get_script() == null:
						continue
					var script_path = node.get_script().resource_path
					var is_room_node = script_path.ends_with("draggable_square.gd") and node.type == "Room"
					if is_room_node and _is_mouse_over_node(node, event.position):
						_create_room_context_menu(node, event.position)
						get_viewport().set_input_as_handled()
						handled = true
						break
			
			# Dacă nu s-a gestionat pentru Room, folosește pentru panning
			if not handled:
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
				# Record removed connections for undo
				var removed_conns = []
				for conn in connections_list:
					if conn[0] == node_to_delete or conn[1] == node_to_delete:
						removed_conns.append(conn)
				if removed_conns.size() > 0:
					_push_undo({"action": "remove_connections", "connections": removed_conns})
				# Remove connections for deleted node
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
				remove_connection(selected_connection)
				selected_connection = null
				ui_connections.selected_connection = null
				ui_connections.queue_redraw()
				update_connections()
				update_properties_panel()
				print("Conexiune ștearsă")

# Creează meniul contextual pentru nodurile Room
func _create_room_context_menu(room_node: Node, mouse_position: Vector2):
	if room_context_menu:
		room_context_menu.queue_free()
	
	room_context_menu = PopupMenu.new()
	room_context_menu.name = "RoomContextMenu"
	
	# Adaugă opțiunile de conectare
	room_context_menu.add_item("Connect Nodes", 0)
	room_context_menu.add_item("Connect Windows/Doors", 1)
	
	# Conectează semnalul pentru selecție
	room_context_menu.id_pressed.connect(_on_room_context_menu_selected.bind(room_node))
	
	# Adaugă meniul la CanvasLayer
	$CanvasLayer.add_child(room_context_menu)
	
	# Afișează meniul la poziția mouse-ului
	room_context_menu.position = mouse_position
	room_context_menu.popup()

# Gestionează selecția din meniul contextual Room
func _on_room_context_menu_selected(room_node: Node, id: int):
	match id:
		0: # Connect Nodes
			_start_room_multi_select(room_node, "nodes")
		1: # Connect Windows/Doors
			_start_room_multi_select(room_node, "windows_doors")
	
	# Șterge meniul după utilizare
	if room_context_menu:
		room_context_menu.queue_free()
		room_context_menu = null

# Inițiază modul Room multi-select cu tipul specificat
func _start_room_multi_select(room_node: Node, connection_type: String):
	room_multi_select_mode = true
	room_source_node = room_node
	room_connection_type = connection_type
	room_connected_nodes.clear()
	
	# Resetează selecția anterioară pentru conexiuni
	for c in ui_circles_container.get_children():
		if c.has_method("reset_connection_selection"):
			c.reset_connection_selection()
	
	# IMPORTANT: Resetează selected_circle pentru a preveni logica normală de conexiuni
	if selected_circle != null:
		selected_circle = null
	
	# Marchează nodul Room ca selectat permanent
	room_node.is_selected_for_connection = true
	room_node.queue_redraw()

	# Show UI indicator and cancel button
	if ui_multi_select_label:
		ui_multi_select_label.visible = true
	if ui_multi_select_cancel_button:
		ui_multi_select_cancel_button.visible = true
	

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
	if is_schema_export_mode:
		if not final_path.ends_with(".json"):
			final_path = final_path + ".json"
		_export_schema_to_path(final_path)
		is_schema_export_mode = false
		return
	if is_schema_import_mode:
		_import_schema_from_path(final_path)
		is_schema_import_mode = false
		return
	if is_graphml_export_mode:
		if not final_path.ends_with(".json"):
			final_path = final_path + ".json"
		_export_graphml_to_path(final_path)
		is_graphml_export_mode = false
		return
	if is_graphml_load_mode:
		_load_graphml_from_path(final_path)
		is_graphml_load_mode = false
		return
	if is_save_mode and not final_path.ends_with(".json"):
		final_path = final_path + ".json"
	if is_save_mode:
		save_graph(final_path)
	else:
		load_graph(final_path)

# Încarcă structură GraphML-like JSON din calea dată
func _load_graphml_from_path(file_path: String):
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
	var graphml_data = json.data
	if typeof(graphml_data) != TYPE_DICTIONARY or not graphml_data.has("nodes") or not graphml_data.has("edges"):
		push_error("Format JSON invalid: lipsesc 'nodes' sau 'edges'")
		return
	# Șterge nodurile existente și conexiunile
	for node in ui_circles_container.get_children():
		node.queue_free()
	connections_list.clear()
	# Nu mai gestionăm noduri Interax în scenă
	next_id = 0
	var id_map = {}
	# Creează nodurile
	for node_data in graphml_data["nodes"]:
		var new_node
		var node_shape = "Circle"
		var node_type = "Circle"
		if node_data.has("node_shape"):
			node_shape = node_data["node_shape"]
		else:
			if node_data.has("type"):
				node_type = node_data["type"]
			elif node_data.has("properties") and node_data["properties"].has("type"):
				node_type = node_data["properties"]["type"]
			node_shape = node_type.capitalize()
			var scene_name = "Circle.tscn"
			if node_data.has("scene"):
				scene_name = node_data["scene"]
			match scene_name:
				"Circle.tscn":
					new_node = circle_scene.instantiate()
				"Square.tscn":
					new_node = square_scene.instantiate()
				"Icon.tscn":
					new_node = icon_scene.instantiate()
				"Door.tscn":
					new_node = door_scene.instantiate()
				"Interax.tscn":
					# Nu mai creăm noduri Interax în scenă - se ignoră
					continue
				_:
					new_node = circle_scene.instantiate()
		# Folosește poziție implicită/random dacă nu există pos_x/pos_y
		var pos_x = 100 + next_id * 30
		var pos_y = 100 + next_id * 30
		if node_data.has("pos_x") and node_data.has("pos_y"):
			pos_x = node_data["pos_x"]
			pos_y = node_data["pos_y"]
		new_node.global_position = Vector2(pos_x, pos_y)
		new_node.type = node_type
		new_node.id = next_id
		# Setează node_info dacă există
		var ni = node_data.get("properties", null)
		if ni != null:
			new_node.node_info = ni
			new_node.node_info["index"] = new_node.id
			if new_node.node_info.has("name"):
				new_node.obj_name = new_node.node_info["name"]
		id_map[node_data["id"]] = new_node
		next_id += 1
		ui_circles_container.add_child(new_node)
		new_node.circle_selected_for_connection.connect(_on_circle_selected_for_connection)
		new_node.circle_selected_for_properties.connect(_on_circle_selected_for_properties)
		# Nu mai gestionăm noduri Interax în scenă
	# Creează muchiile
	for edge in graphml_data["edges"]:
		var src = id_map.get(edge["source"], null)
		var dst = id_map.get(edge["target"], null)
		if src and dst:
			var label = edge.get("label", edge.get("properties", {}).get("label", "Edge" + str(connections_list.size() + 1)))
			var typ = edge.get("type", edge.get("properties", {}).get("type", "Process"))
			var conn_uuid = edge.get("uuid", "")
			var properties = edge.get("properties", {})
			
			# Load midpoint
			var midpoint = Vector2.ZERO
			if edge.has("midpoint"):
				var mp = edge["midpoint"]
				if typeof(mp) == TYPE_DICTIONARY:
					midpoint = Vector2(mp.get("x", 0.0), mp.get("y", 0.0))
			
			# Load layer
			var layer = edge.get("layer", "connections")
			
			# Load attached nodes
			var attached_nodes = edge.get("attached_nodes", [])
			
			# Generate UUID if missing
			if conn_uuid == "":
				conn_uuid = UUIDGenerator.generate_uuid()
			
			# Create connection with all data
			var conn = [src, dst, label, typ, conn_uuid, properties, midpoint, layer, attached_nodes]
			connections_list.append(conn)
			print("GraphML connection restored: ", label, " UUID:", conn_uuid)
	if ui_connections != null:
		ui_connections.update_connections(connections_list)
		ui_connections.queue_redraw()
	update_scene()
	print("GraphML-like JSON loaded din: ", file_path)

# Exportă structura GraphML-like la calea dată
func _export_graphml_to_path(file_path: String):
	var export_data = {
		"nodes": [],
		"edges": []
	}
	var node_id_map = {}
	var id_counter = 0
	for node in ui_circles_container.get_children():
		if "node_info" in node:
			var node_info = node.node_info.duplicate()
			var node_id = id_counter
			node_id_map[node] = node_id
			id_counter += 1
			var script_path = ""
			if node.get_script() != null:
				script_path = node.get_script().resource_path
				var node_type = script_path.get_file().replace(".gd", "")
				var node_shape = node_type.replace("draggable_", "").capitalize()
				var scene_name = "Circle.tscn"
				if node_shape == "Circle" or node_shape == "Process":
					scene_name = "Circle.tscn"
				elif node_shape == "Room" or node_shape == "Square":
					scene_name = "Square.tscn"
				elif node_shape == "Window" or node_shape == "Icon":
					scene_name = "Icon.tscn"
				elif node_shape == "Door":
					scene_name = "Door.tscn"
				elif node_shape == "Interax":
					scene_name = "Interax.tscn"
				export_data["nodes"].append({
					"id": node_id,
					"type": node_info.get("type", "unknown"),
					"properties": node_info,
					"pos_x": node.global_position.x,
					"pos_y": node.global_position.y,
					"node_shape": node_shape,
					"scene": scene_name
				})
	for conn in connections_list:
		var src = conn[0]
		var dst = conn[1]
		if node_id_map.has(src) and node_id_map.has(dst):
			var label = conn[2] if conn.size() > 2 else ""
			var type = conn[3] if conn.size() > 3 else "Process"
			var uuid = conn[4] if conn.size() > 4 else ""
			var properties = conn[5] if conn.size() > 5 else {}
			var midpoint = conn[6] if conn.size() > 6 else Vector2.ZERO
			var layer = conn[7] if conn.size() > 7 else "connections"
			var attached_nodes = conn[8] if conn.size() > 8 else []
			
			export_data["edges"].append({
				"source": node_id_map[src],
				"target": node_id_map[dst],
				"label": label,
				"type": type,
				"uuid": uuid,
				"properties": properties,
				"midpoint": {"x": midpoint.x, "y": midpoint.y},
				"layer": layer,
				"attached_nodes": attached_nodes
			})
	var file = FileAccess.open(file_path, FileAccess.WRITE)
	file.store_string(JSON.stringify(export_data, "  "))
	file.close()
	print("Exported GraphML-like JSON to " + file_path)

# --- Export JSON Schema ---
func _on_export_schema_button_pressed():
	is_schema_export_mode = true
	ui_file_dialog.file_mode = FileDialog.FILE_MODE_SAVE_FILE
	ui_file_dialog.title = "Export JSON Schema"
	ui_file_dialog.current_file = "graph_schema.json"
	ui_file_dialog.show()

func _export_schema_to_path(file_path: String):
	# Get project name from level config
	var project_name = level_config_data.get("project_name", "Untitled Project")
	
	# Export schema using JSONSchemaExporter
	var schema = JSONSchemaExporter.export_schema(
		ui_circles_container,
		connections_list,
		project_name,
		interax_coordinates_data
	)
	
	# Export to file
	var success = JSONSchemaExporter.export_to_file(schema, file_path)
	
	if success:
		print("JSON Schema exported successfully to: ", file_path)
		_show_export_confirmation(file_path)
	else:
		push_error("Failed to export JSON Schema to: ", file_path)
		_show_export_error()

func _import_schema_from_path(file_path: String):
	# Import schema using JSONSchemaExporter
	var schema = JSONSchemaExporter.import_from_file(file_path)
	
	if schema.is_empty():
		push_error("Failed to import JSON Schema from: ", file_path)
		_show_import_error()
		return
	
	# TODO: Implement full schema import logic
	# This would involve:
	# 1. Clear existing nodes and connections
	# 2. Recreate nodes from schema
	# 3. Recreate connections from schema
	# 4. Update layers from schema
	# 5. Update coordinate sets from schema
	
	print("JSON Schema import not yet fully implemented")
	print("Schema loaded with ", schema["nodes"].size(), " nodes and ", schema["relationships"].size(), " relationships")

func _show_export_confirmation(file_path: String):
	var dialog = AcceptDialog.new()
	dialog.title = "Export Successful"
	dialog.dialog_text = "JSON Schema exported successfully to:\n" + file_path
	dialog.ok_button_text = "OK"
	get_tree().root.add_child(dialog)
	dialog.popup_centered()
	dialog.confirmed.connect(func(): dialog.queue_free())

func _show_export_error():
	var dialog = AcceptDialog.new()
	dialog.title = "Export Failed"
	dialog.dialog_text = "Failed to export JSON Schema. Check console for errors."
	dialog.ok_button_text = "OK"
	get_tree().root.add_child(dialog)
	dialog.popup_centered()
	dialog.confirmed.connect(func(): dialog.queue_free())

func _show_import_error():
	var dialog = AcceptDialog.new()
	dialog.title = "Import Failed"
	dialog.dialog_text = "Failed to import JSON Schema. Check console for errors."
	dialog.ok_button_text = "OK"
	get_tree().root.add_child(dialog)
	dialog.popup_centered()
	dialog.confirmed.connect(func(): dialog.queue_free())

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
	# Inițializează node_info cu câmpul connected_nodes pentru nodurile Room
	if "node_info" in new_square:
		if new_square.node_info == null:
			new_square.node_info = {}
		new_square.node_info["connected_nodes"] = []
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
	# Comută vizibilitatea editorului de coordonate Interax
	if ui_interax_editor == null:
		_create_interax_coordinate_editor()
	else:
		ui_interax_editor.visible = !ui_interax_editor.visible
	print("Editor coordonate Interax comutat. Vizibil:", ui_interax_editor.visible if ui_interax_editor else false)

# Creează editorul de coordonate Interax ca un panel editabil
func _create_interax_coordinate_editor():
	# Creează panelul principal
	ui_interax_editor = Panel.new()
	ui_interax_editor.name = "InteraxEditor"
	ui_interax_editor.size = Vector2(400, 300)
	ui_interax_editor.position = Vector2(50, 50)
	
	# Container vertical principal
	var vbox = VBoxContainer.new()
	ui_interax_editor.add_child(vbox)
	
	# Titlu
	var title = Label.new()
	title.text = "Editor Coordonate Interax"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(title)
	
	# Container pentru coordonatele X
	var x_container = VBoxContainer.new()
	vbox.add_child(x_container)
	
	var x_label = Label.new()
	x_label.text = "Coordonate X:"
	x_container.add_child(x_label)
	
	var x_grid = GridContainer.new()
	x_grid.columns = 4
	x_container.add_child(x_grid)
	
	# Adaugă câmpuri pentru coordonatele X
	for i in range(interax_coordinates_data["x_values"].size()):
		var x_edit = LineEdit.new()
		x_edit.text = str(interax_coordinates_data["x_values"][i])
		x_edit.name = "x_coord_" + str(i)
		x_edit.text_changed.connect(_on_coordinate_changed.bind("x", i))
		x_grid.add_child(x_edit)
	
	# Container pentru coordonatele Y
	var y_container = VBoxContainer.new()
	vbox.add_child(y_container)
	
	var y_label = Label.new()
	y_label.text = "Coordonate Y:"
	y_container.add_child(y_label)
	
	var y_grid = GridContainer.new()
	y_grid.columns = 4
	y_container.add_child(y_grid)
	
	# Adaugă câmpuri pentru coordonatele Y
	for i in range(interax_coordinates_data["y_values"].size()):
		var y_edit = LineEdit.new()
		y_edit.text = str(interax_coordinates_data["y_values"][i])
		y_edit.name = "y_coord_" + str(i)
		y_edit.text_changed.connect(_on_coordinate_changed.bind("y", i))
		y_grid.add_child(y_edit)
	
	# Butoane pentru adăugare/ștergere coordonate
	var button_container = HBoxContainer.new()
	vbox.add_child(button_container)
	
	var add_x_button = Button.new()
	add_x_button.text = "Adaugă X"
	add_x_button.pressed.connect(_add_coordinate.bind("x"))
	button_container.add_child(add_x_button)
	
	var remove_x_button = Button.new()
	remove_x_button.text = "Șterge X"
	remove_x_button.pressed.connect(_remove_coordinate.bind("x"))
	button_container.add_child(remove_x_button)
	
	var add_y_button = Button.new()
	add_y_button.text = "Adaugă Y"
	add_y_button.pressed.connect(_add_coordinate.bind("y"))
	button_container.add_child(add_y_button)
	
	var remove_y_button = Button.new()
	remove_y_button.text = "Șterge Y"
	remove_y_button.pressed.connect(_remove_coordinate.bind("y"))
	button_container.add_child(remove_y_button)
	
	# Buton pentru închidere
	var close_button = Button.new()
	close_button.text = "Închide"
	close_button.pressed.connect(_close_interax_editor)
	vbox.add_child(close_button)
	
	# Adaugă panelul la scena principală
	$CanvasLayer.add_child(ui_interax_editor)
	
	# Setează pozițiile și dimensiunile relative
	vbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	vbox.add_theme_constant_override("separation", 10)
	
	print("Editor coordonate Interax creat cu valorile:", interax_coordinates_data)

# Gestionează modificarea valorilor coordonatelor
func _on_coordinate_changed(coord_type: String, index: int, new_value: String):
	if new_value.is_valid_float():
		var value = float(new_value)
		if coord_type == "x":
			interax_coordinates_data["x_values"][index] = value
		elif coord_type == "y":
			interax_coordinates_data["y_values"][index] = value
		_save_interax_coordinates_to_json()
		print("Coordonată ", coord_type, "[", index, "] schimbată la:", value)

# Adaugă o nouă coordonată
func _add_coordinate(coord_type: String):
	if coord_type == "x":
		interax_coordinates_data["x_values"].append(1.0)
	elif coord_type == "y":
		interax_coordinates_data["y_values"].append(1.0)
	_refresh_interax_editor()
	_save_interax_coordinates_to_json()
	print("Adăugată coordonată nouă pentru:", coord_type)

# Șterge ultima coordonată
func _remove_coordinate(coord_type: String):
	if coord_type == "x" and interax_coordinates_data["x_values"].size() > 1:
		interax_coordinates_data["x_values"].pop_back()
	elif coord_type == "y" and interax_coordinates_data["y_values"].size() > 1:
		interax_coordinates_data["y_values"].pop_back()
	_refresh_interax_editor()
	_save_interax_coordinates_to_json()
	print("Șters ultima coordonată pentru:", coord_type)

# Închide editorul de coordonate
func _close_interax_editor():
	if ui_interax_editor:
		ui_interax_editor.visible = false
	print("Editor coordonate Interax închis")

# Reîmprospătează editorul după modificări
func _refresh_interax_editor():
	if ui_interax_editor:
		ui_interax_editor.queue_free()
		ui_interax_editor = null
		_create_interax_coordinate_editor()

# Salvează coordonatele în fișierul JSON
func _save_interax_coordinates_to_json():
	var file_path = "user://interax_coordinates.json"
	var file = FileAccess.open(file_path, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(interax_coordinates_data, "  "))
		file.close()
		print("Coordonate Interax salvate în:", file_path)
	else:
		push_error("Nu s-au putut salva coordonatele în:", file_path)

# Încarcă coordonatele din fișierul JSON
func _load_interax_coordinates_from_json():
	var file_path = "user://interax_coordinates.json"
	if FileAccess.file_exists(file_path):
		var file = FileAccess.open(file_path, FileAccess.READ)
		if file:
			var json_text = file.get_as_text()
			file.close()
			var json = JSON.new()
			if json.parse(json_text) == OK:
				interax_coordinates_data = json.data
				print("Coordonate Interax încărcate din:", file_path)
			else:
				push_error("Eroare la parsarea JSON:", json.get_error_message())
		else:
			push_error("Nu s-a putut citi fișierul:", file_path)
	else:
		print("Fișierul de coordonate nu există, se vor folosi valorile implicite")

func _on_level_config_button_pressed():
	# Comută vizibilitatea editorului de configurare nivele
	if ui_level_editor == null:
		_create_level_config_editor()
	else:
		ui_level_editor.visible = !ui_level_editor.visible
	print("Editor configurare nivele comutat. Vizibil:", ui_level_editor.visible if ui_level_editor else false)

# Creează editorul de configurare nivele ca un panel editabil
func _create_level_config_editor():
	# Creează panelul principal
	ui_level_editor = Panel.new()
	ui_level_editor.name = "LevelConfigEditor"
	ui_level_editor.size = Vector2(600, 400)
	ui_level_editor.position = Vector2(100, 100)
	
	# Container vertical principal
	var vbox = VBoxContainer.new()
	ui_level_editor.add_child(vbox)
	
	# Titlu
	var title = Label.new()
	title.text = "Configurare Nivele Proiect"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(title)
	
	# Container pentru numele proiectului
	var project_container = HBoxContainer.new()
	vbox.add_child(project_container)
	
	var project_label = Label.new()
	project_label.text = "Nume Proiect:"
	project_label.custom_minimum_size.x = 120
	project_container.add_child(project_label)
	
	var project_edit = LineEdit.new()
	project_edit.text = level_config_data["project_name"]
	project_edit.name = "project_name_edit"
	project_edit.custom_minimum_size.x = 300  # Câmp mai lung pentru numele proiectului
	project_edit.text_changed.connect(_on_project_name_changed)
	project_container.add_child(project_edit)
	
	# Separator
	var sep = HSeparator.new()
	vbox.add_child(sep)
	
	# Label pentru nivele
	var levels_label = Label.new()
	levels_label.text = "Nivele:"
	vbox.add_child(levels_label)
	
	# ScrollContainer pentru nivele
	var scroll = ScrollContainer.new()
	scroll.custom_minimum_size.y = 200
	vbox.add_child(scroll)
	
	# Container pentru grid-ul de nivele
	var levels_vbox = VBoxContainer.new()
	scroll.add_child(levels_vbox)
	
	# Header pentru tabel
	var header = HBoxContainer.new()
	levels_vbox.add_child(header)
	
	var name_header = Label.new()
	name_header.text = "Nume Nivel"
	name_header.custom_minimum_size.x = 120
	header.add_child(name_header)
	
	var bottom_header = Label.new()
	bottom_header.text = "Bottom Level"
	bottom_header.custom_minimum_size.x = 100
	header.add_child(bottom_header)
	
	var height_header = Label.new()
	height_header.text = "Level Height"
	height_header.custom_minimum_size.x = 100
	header.add_child(height_header)
	
	var top_header = Label.new()
	top_header.text = "Top Level"
	top_header.custom_minimum_size.x = 100
	header.add_child(top_header)
	
	var action_header = Label.new()
	action_header.text = "Acțiuni"
	action_header.custom_minimum_size.x = 80
	header.add_child(action_header)
	
	# Adaugă câmpurile pentru fiecare nivel
	for i in range(level_config_data["levels"].size()):
		var level = level_config_data["levels"][i]
		var level_row = HBoxContainer.new()
		levels_vbox.add_child(level_row)
		
		# Numele nivelului
		var name_edit = LineEdit.new()
		name_edit.text = level["name"]
		name_edit.custom_minimum_size.x = 120
		name_edit.name = "level_name_" + str(i)
		name_edit.text_changed.connect(_on_level_field_changed.bind(i, "name"))
		level_row.add_child(name_edit)
		
		# Bottom level (LineEdit pentru valori float)
		var bottom_edit = LineEdit.new()
		bottom_edit.text = "%.2f" % level["bottom_level"]
		bottom_edit.custom_minimum_size.x = 100
		bottom_edit.name = "level_bottom_" + str(i)
		bottom_edit.placeholder_text = "0.00"
		bottom_edit.text_changed.connect(func(text): _on_level_float_changed(text, i, "bottom_level"))
		level_row.add_child(bottom_edit)
		
		# Level height (LineEdit pentru valori float)
		var height_edit = LineEdit.new()
		height_edit.text = "%.2f" % level["level_height"]
		height_edit.custom_minimum_size.x = 100
		height_edit.name = "level_height_" + str(i)
		height_edit.placeholder_text = "2.80"
		height_edit.text_changed.connect(func(text): _on_level_float_changed(text, i, "level_height"))
		level_row.add_child(height_edit)
		
		# Top level (calculat automat)
		var top_label = Label.new()
		top_label.text = "%.2f" % level["top_level"]  # Afișează cu 2 zecimale
		top_label.custom_minimum_size.x = 100
		top_label.name = "level_top_" + str(i)
		level_row.add_child(top_label)
		
		# Buton pentru ștergere
		var delete_button = Button.new()
		delete_button.text = "Șterge"
		delete_button.custom_minimum_size.x = 80
		delete_button.pressed.connect(_remove_level.bind(i))
		level_row.add_child(delete_button)
	
	# Butoane pentru acțiuni
	var button_container = HBoxContainer.new()
	vbox.add_child(button_container)
	
	var add_button = Button.new()
	add_button.text = "Adaugă Nivel"
	add_button.pressed.connect(_add_level)
	button_container.add_child(add_button)
	
	var save_button = Button.new()
	save_button.text = "Salvează"
	save_button.pressed.connect(_save_level_config_manual)
	button_container.add_child(save_button)
	
	var close_button = Button.new()
	close_button.text = "Închide"
	close_button.pressed.connect(_close_level_editor)
	button_container.add_child(close_button)
	
	# Adaugă panelul la scena principală
	$CanvasLayer.add_child(ui_level_editor)
	
	# Setează pozițiile și dimensiunile relative
	vbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	vbox.add_theme_constant_override("separation", 5)
	
	print("Editor configurare nivele creat cu datele:", level_config_data)
	
	# Forțează recalcularea tuturor valorilor top_level pentru a fi sigur că sunt corecte
	# Facem acest lucru după ce UI-ul este complet construit
	call_deferred("_recalculate_all_top_levels")

# Gestionează modificarea numelui proiectului
func _on_project_name_changed(new_name: String):
	level_config_data["project_name"] = new_name
	print("Nume proiect schimbat la:", new_name)

# Gestionează modificarea câmpurilor text ale nivelelor
func _on_level_field_changed(level_index: int, field: String, new_value: String):
	if level_index < level_config_data["levels"].size():
		level_config_data["levels"][level_index][field] = new_value
		print("Nivel [", level_index, "] ", field, " schimbat la:", new_value)

# Gestionează modificarea valorilor numerice ale nivelelor
func _on_level_value_changed(level_index: int, field: String, new_value: float):
	if level_index < level_config_data["levels"].size():
		level_config_data["levels"][level_index][field] = new_value
		# Calculează top level automat
		if field == "bottom_level" or field == "level_height":
			var level = level_config_data["levels"][level_index]
			level["top_level"] = level["bottom_level"] + level["level_height"]
			# Actualizează label-ul top level în UI cu format cu 2 zecimale
			if ui_level_editor:
				var top_label = ui_level_editor.find_child("level_top_" + str(level_index))
				if top_label:
					top_label.text = "%.2f" % level["top_level"]
		print("Nivel [", level_index, "] ", field, " schimbat la:", new_value)

# Adaugă un nivel nou
func _add_level():
	var new_level = {
		"name": "Nivel Nou",
		"bottom_level": 0.00,
		"level_height": 2.80,
		"top_level": 2.80
	}
	level_config_data["levels"].append(new_level)
	_refresh_level_editor()
	print("Adăugat nivel nou")

# Șterge un nivel
func _remove_level(level_index: int):
	if level_config_data["levels"].size() > 1 and level_index < level_config_data["levels"].size():
		level_config_data["levels"].remove_at(level_index)
		_refresh_level_editor()
		print("Șters nivelul cu indexul:", level_index)

# Închide editorul de nivele
func _close_level_editor():
	if ui_level_editor:
		ui_level_editor.visible = false
	print("Editor configurare nivele închis")

# Reîmprospătează editorul după modificări
func _refresh_level_editor():
	if ui_level_editor:
		ui_level_editor.queue_free()
		ui_level_editor = null
		_create_level_config_editor()

# Salvează configurarea nivelelor în fișierul JSON
func _save_level_config_to_json():
	var file_path = "user://level_config.json"
	var file = FileAccess.open(file_path, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(level_config_data, "  "))
		file.close()
		print("Configurare nivele salvată în:", file_path)
	else:
		push_error("Nu s-a putut salva configurarea nivelelor în:", file_path)

# Recalculează toate valorile top_level și actualizează afișajul
func _recalculate_all_top_levels():
	for i in range(level_config_data["levels"].size()):
		var level = level_config_data["levels"][i]
		level["top_level"] = level["bottom_level"] + level["level_height"]
		_update_top_level_display(i)
	print("Recalculate toate valorile top_level")

# Salvează manual configurarea nivelelor (folosită de butonul Salvează)
func _save_level_config_manual():
	# Recalculează toate valorile top_level înainte de salvare
	_recalculate_all_top_levels()
	_save_level_config_to_json()
	print("Configurația nivelurilor a fost salvată manual!")

# Gestionează modificările valorilor float din câmpurile LineEdit
func _on_level_float_changed(text: String, level_index: int, field_type: String):
	var float_value = text.to_float()
	
	if level_index < level_config_data["levels"].size():
		var level = level_config_data["levels"][level_index]
		
		if field_type == "bottom_level":
			level["bottom_level"] = float_value
			level["top_level"] = level["bottom_level"] + level["level_height"]
		elif field_type == "level_height":
			level["level_height"] = float_value
			level["top_level"] = level["bottom_level"] + level["level_height"]
		
		# Actualizează imediat afișajul top_level în UI
		_update_top_level_display(level_index)
		
		print("Actualizat nivel ", level_index, " ", field_type, " la valoarea: ", float_value, " (top_level: ", level["top_level"], ")")

# Funcție auxiliară pentru a actualiza afișajul top_level în UI
func _update_top_level_display(level_index: int):
	if ui_level_editor and level_index < level_config_data["levels"].size():
		var level = level_config_data["levels"][level_index]
		# Caută label-ul folosind find_child cu opțiuni mai flexibile
		var top_label = ui_level_editor.find_child("level_top_" + str(level_index), true, false)
		if top_label:
			top_label.text = "%.2f" % level["top_level"]
			print("Actualizat afișaj top_level pentru nivelul ", level_index, ": ", level["top_level"])
		else:
			print("Nu s-a găsit label-ul level_top_" + str(level_index) + " în UI")
			# Debug: afișează toate label-urile disponibile
			_debug_print_all_labels()

# Funcție auxiliară pentru debug - afișează toate label-urile din editor
func _debug_print_all_labels():
	if ui_level_editor:
		print("=== Debug: Label-uri în UI ===")
		_print_children_recursive(ui_level_editor, 0)
	else:
		print("ui_level_editor este null")

# Funcție recursivă pentru a afișa toți copiii unui nod
func _print_children_recursive(node: Node, depth: int):
	var indent = ""
	for i in range(depth):
		indent += "  "
	print(indent + node.name + " (" + str(node.get_class()) + ")")
	for child in node.get_children():
		_print_children_recursive(child, depth + 1)

# Încarcă configurarea nivelelor din fișierul JSON
func _load_level_config_from_json():
	var file_path = "user://level_config.json"
	if FileAccess.file_exists(file_path):
		var file = FileAccess.open(file_path, FileAccess.READ)
		if file:
			var json_text = file.get_as_text()
			file.close()
			var json = JSON.new()
			if json.parse(json_text) == OK:
				level_config_data = json.data
				# Recalculează top level pentru toate nivelurile pentru a fi sigur că sunt corecte
				for level in level_config_data["levels"]:
					level["top_level"] = level["bottom_level"] + level["level_height"]
				print("Configurare nivele încărcată din:", file_path)
			else:
				push_error("Eroare la parsarea JSON:", json.get_error_message())
		else:
			push_error("Nu s-a putut citi fișierul:", file_path)
	else:
		print("Fișierul de configurare nivele nu există, se vor folosi valorile implicite")
		# Asigură-te că valorile implicite au top level calculat corect
		for level in level_config_data["levels"]:
			level["top_level"] = level["bottom_level"] + level["level_height"]

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
	
	
	# PRIORITATE 1: Dacă suntem în modul Room multi-select
	if room_multi_select_mode:
		# Resetează selected_circle pentru a preveni logica normală
		if selected_circle != null:
			if selected_circle.has_method("reset_connection_selection"):
				selected_circle.reset_connection_selection()
			selected_circle = null
		
		# Ignoră re-click pe nodul Room sursă
		if node == room_source_node:
			return
		
		# Adaugă nodul la lista de noduri conectate la Room
		if node not in room_connected_nodes:
			room_connected_nodes.append(node)
			node.is_selected_for_connection = true
			node.queue_redraw()
		else:
			return  # IMPORTANT: Return aici pentru a nu continua cu logica normală
	
	# PRIORITATE 2: Verifică dacă este nod de tip Room (click normal pe Room fără meniu)
	var is_room_node = script_path.ends_with("draggable_square.gd") and node.type == "Room"
	if is_room_node:
		# Pentru nodurile Room, nu facem nimic la click normal - așteptăm click dreapta pentru meniu
		return
	
	# PRIORITATE 3: Logica standard pentru conexiuni normale (non-Room)
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
			var new_connection = create_connection(selected_circle, node, "Edge" + str(connections_list.size() + 1), "Process")
			print("Conexiune adăugată:", selected_circle.obj_name, "->", node.obj_name, "cu name:", new_connection[2], "și type:", new_connection[3])
			if ui_connections != null:
				ui_connections.update_connections(connections_list)
		# Reset visual selection for connection since it was completed
		if selected_circle != null and selected_circle.has_method("reset_connection_selection"):
			selected_circle.reset_connection_selection()
		if node != null and node.has_method("reset_connection_selection"):
			node.reset_connection_selection()
		selected_circle = null

func _on_circle_selected_for_properties(node):
	if node.get_script() == null:
		push_error("Nodul selectat pentru proprietăți nu are script atașat: ", node)
		return
	var script_path = node.get_script().resource_path
	if not (script_path.ends_with("Circle.gd") or script_path.ends_with("draggable_square.gd") or script_path.ends_with("draggable_icon.gd") or script_path.ends_with("draggable_door.gd") or script_path.ends_with("interax.gd")):
		push_error("Nodul selectat are un script neașteptat: ", script_path, " Node:", node)
		return
	
	# Check if we're in attach mode
	if attach_to_midpoint_mode and attach_target_connection:
		_attach_node_to_connection(node, attach_target_connection)
		_cancel_attach_mode()
		return
	
	# Resetează selecția pentru toate nodurile și marchează node ca selectat
	for n in ui_circles_container.get_children():
		if n != node and n.has_method("reset_selection"):
			n.reset_selection()
	# Mark current node as selected (visual)
	if node:
		node.is_selected = true
		node.queue_redraw()
	
	selected_for_properties = node
	selected_connection = null
	ui_connections.selected_connection = null
	ui_connections.queue_redraw()
	update_properties_panel()

func _on_connection_selected(connection):
	print("DEBUG main_scene.gd: _on_connection_selected() called!")
	print("DEBUG: Connection data: ", connection)
	
	# Deselect any selected nodes first
	for n in ui_circles_container.get_children():
		if n.has_method("reset_selection"):
			n.reset_selection()
	
	selected_connection = connection
	selected_for_properties = null
	print("DEBUG: selected_connection set to: ", selected_connection)
	print("DEBUG: selected_for_properties set to null")
	
	# FIX #1: Sync selected_connection to ui_connections and trigger visual update
	if ui_connections:
		ui_connections.selected_connection = connection
		ui_connections.queue_redraw()
		print("DEBUG: ui_connections.selected_connection synced and redraw called")
	
	# Open PropertiesPanel with connection properties
	print("DEBUG: Calling update_properties_panel()")
	update_properties_panel()
	print("Conexiune selectată:", connection[0].obj_name, "->", connection[1].obj_name)

# Handle midpoint selection in connect mode (midpoint acts as a connection node)
func _on_midpoint_selected_for_connection(connection, midpoint_position):
	# Midpoint acts as a virtual node for connections
	# If no node is selected yet, select this midpoint as source
	if selected_circle == null:
		# Store the connection as the "selected node" for connection
		selected_circle = connection
		print("Midpoint selected as source for connection: ", connection[2] if connection.size() > 2 else "Unknown")
		ui_connections.queue_redraw()
	else:
		# If a node is already selected, create connection from that node to this midpoint
		# This means attaching the node to the connection's midpoint
		if typeof(selected_circle) == TYPE_ARRAY:
			# selected_circle is a connection - can't connect connection to connection
			print("Cannot connect connection to connection")
			selected_circle = null
			return
		
		# Attach the selected node to this connection's midpoint
		_attach_node_to_connection(selected_circle, connection)
		print("Node ", selected_circle.obj_name, " attached to midpoint of connection: ", connection[2] if connection.size() > 2 else "Unknown")
		
		# Reset selection
		if selected_circle.has_method("reset_connection_selection"):
			selected_circle.reset_connection_selection()
		selected_circle = null
		ui_connections.queue_redraw()

# Funcțiile vechi Interax au fost eliminate - acum se folosește editorul de coordonate simplu

func update_properties_panel():
	print("DEBUG update_properties_panel: selected_for_properties = ", selected_for_properties)
	print("DEBUG update_properties_panel: selected_connection = ", selected_connection)
	
	if selected_for_properties != null:
		print("DEBUG: Opening panel for node properties")
		ui_properties_panel.visible = true
		# Basic properties
		# Basic properties are handled by PropertiesPanel.gd
		# type selection removed

		# Delegate building the detailed properties to the PropertiesPanel script if present
		if ui_properties_panel and ui_properties_panel.has_method("build_from_node"):
			ui_properties_panel.build_from_node(selected_for_properties)

	elif selected_connection != null:
		print("DEBUG: Opening panel for connection properties")
		print("DEBUG: ui_properties_panel = ", ui_properties_panel)
		print("DEBUG: ui_connections = ", ui_connections)
		print("DEBUG: selected_connection = ", selected_connection)
		print("DEBUG: selected_connection.node_info = ", "N/A (connection is array)")
		ui_properties_panel.visible = true
		print("DEBUG: Panel visibility set to true")
		# connection properties: delegate to PropertiesPanel by passing the connections node
		if ui_properties_panel and ui_properties_panel.has_method("build_from_node"):
			print("DEBUG: Calling build_from_node with ui_connections (the connections.gd script)")
			print("DEBUG: ui_connections type = ", typeof(ui_connections))
			print("DEBUG: ui_connections has node_info? ", ui_connections.has_method("get") and "node_info" in ui_connections)
			ui_properties_panel.build_from_node(ui_connections)
			print("DEBUG: build_from_node completed")
		else:
			print("DEBUG: PropertiesPanel or build_from_node method not found!")
	else:
		print("DEBUG: Hiding panel (no selection)")
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
	elif key == "index":
		# Actualizează indexul și redesenează nodul
		if node.has_method("queue_redraw"):
			node.queue_redraw()
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

# Undo/Redo helpers
func _push_undo(action: Dictionary):
	if _undo_disabled:
		return
	undo_stack.append(action)
	# Clear redo when new action is performed
	redo_stack.clear()

func create_connection(src, dst, label, typ, push_undo := true):
	# Generate UUID for the connection
	var conn_uuid = UUIDGenerator.generate_uuid()
	
	# Get layer from source node or use default
	var conn_layer = "connections"
	if src.has_method("get") and src.get("node_info") != null:
		conn_layer = src.node_info.get("layer", "connections")
	
	# Connection structure: [from_node, to_node, label, type, uuid, properties, midpoint_offset, layer, attached_nodes]
	# Note: midpoint_offset (index 6) is Vector2.ZERO by default, meaning midpoint is at curve center
	# When user drags midpoint, this stores the offset from the default curve position
	var conn = [
		src,                    # 0: from_node
		dst,                    # 1: to_node
		label,                  # 2: label
		typ,                    # 3: type
		conn_uuid,              # 4: uuid
		{                       # 5: properties (extensible dict)
			"has_wall": true,
			"wall_type": "",
			"has_beam": false,
			"beam_type": ""
		},
		Vector2.ZERO,           # 6: midpoint_offset (offset from curve center, not absolute position)
		conn_layer,             # 7: layer
		[]                      # 8: attached_nodes (array of UUIDs)
	]
	connections_list.append(conn)
	update_connections()
	if push_undo:
		_push_undo({"action": "add_connections", "connections": [conn]})
	print("Connection created with UUID: ", conn_uuid, " on layer: ", conn_layer)
	return conn

func remove_connection(conn, push_undo := true):
	if conn in connections_list:
		connections_list.erase(conn)
		update_connections()
		if push_undo:
			_push_undo({"action": "remove_connections", "connections": [conn]})

# Attach a node to a connection's midpoint
func attach_node_to_connection(node, connection):
	if connection.size() < 9:
		# Extend array to include attached_nodes
		while connection.size() < 9:
			if connection.size() == 6:
				connection.append(Vector2.ZERO)  # midpoint
			elif connection.size() == 7:
				connection.append("connections")  # layer
			elif connection.size() == 8:
				connection.append([])  # attached_nodes
	
	var node_uuid = node.node_info.get("uuid", "")
	if node_uuid == "":
		push_error("Cannot attach node without UUID")
		return false
	
	var attached_nodes = connection[8]
	if node_uuid not in attached_nodes:
		attached_nodes.append(node_uuid)
		update_connections()
		print("Node ", node.obj_name, " attached to connection")
		return true
	return false

# Detach a node from a connection's midpoint
func detach_node_from_connection(node, connection):
	if connection.size() < 9:
		return false
	
	var node_uuid = node.node_info.get("uuid", "")
	var attached_nodes = connection[8]
	
	if node_uuid in attached_nodes:
		attached_nodes.erase(node_uuid)
		update_connections()
		print("Node ", node.obj_name, " detached from connection")
		return true
	return false

# Helper function to deselect all nodes
func _deselect_all():
	for n in ui_circles_container.get_children():
		if n.has_method("reset_selection"):
			n.reset_selection()
	selected_for_properties = null
	selected_connection = null
	if ui_properties_panel:
		ui_properties_panel.visible = false
	if ui_connections:
		ui_connections.selected_connection = null
		ui_connections.queue_redraw()

# Helper function to check if click is on UI panels
func _is_click_on_ui_panel(screen_pos: Vector2) -> bool:
	# Check if click is on fixed UI panels
	
	# Left Panel (0-200px)
	if screen_pos.x <= 200:
		return true
	
	# Right Panel (last 300px)
	var viewport_width = get_viewport().get_visible_rect().size.x
	if screen_pos.x >= viewport_width - 300:
		return true
	
	return false

# Helper function to check if mouse is over UI panels (for scroll/zoom prevention)
func _is_mouse_over_ui_panels(mouse_pos: Vector2) -> bool:
	var viewport_width = get_viewport().get_visible_rect().size.x
	
	# Left Panel (0-200px)
	if mouse_pos.x <= 200:
		return true
	
	# Right Panel (last 300px)
	if mouse_pos.x >= viewport_width - 300:
		return true
	
	return false

# Helper function pentru a verifica dacă mouse-ul este peste un nod
func _is_mouse_over_node(node: Node2D, _screen_pos: Vector2) -> bool:
	if node == null or ui_camera == null:
		return false
	
	# Convertește poziția ecranului în poziție globală din scenă
	var world_pos = ui_camera.get_global_mouse_position()
	
	# Verifică tipul nodului și folosește zona de selecție corespunzătoare
	var script_path = ""
	if node.get_script() != null:
		script_path = node.get_script().resource_path
	
	if script_path.ends_with("Circle.gd"):
		# Pentru Circle, verifică distanța față de centru
		var distance = world_pos.distance_to(node.global_position)
		return distance <= node.radius * ui_camera.zoom.x
	elif script_path.ends_with("draggable_square.gd"):
		# Pentru Square/Room, folosește zona dublată de selecție
		var selection_size = node.size * 2.0
		var rect = Rect2(node.global_position - Vector2(selection_size / 2, selection_size / 2), Vector2(selection_size, selection_size))
		return rect.has_point(world_pos)
	elif script_path.ends_with("draggable_icon.gd") or script_path.ends_with("draggable_door.gd"):
		# Pentru Icon/Door, folosește zona pătrată
		var rect = Rect2(node.global_position - Vector2(node.size / 2, node.size / 2), Vector2(node.size, node.size))
		return rect.has_point(world_pos)
	
	return false

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
		
		# Extract connection data: [from_node, to_node, label, type, uuid, properties, midpoint, layer, attached_nodes]
		var label = connection[2] if connection.size() > 2 else ""
		var type = connection[3] if connection.size() > 3 else "Process"
		var uuid = connection[4] if connection.size() > 4 else ""
		var properties = connection[5] if connection.size() > 5 else {}
		var midpoint = connection[6] if connection.size() > 6 else Vector2.ZERO
		var layer = connection[7] if connection.size() > 7 else "connections"
		var attached_nodes = connection[8] if connection.size() > 8 else []
		
		var edge_data = {
			"source": connection[0].id,
			"target": connection[1].id,
			"label": label,
			"type": type.to_lower(),
			"uuid": uuid,
			"properties": properties,
			"midpoint": {"x": midpoint.x, "y": midpoint.y},
			"layer": layer,
			"attached_nodes": attached_nodes
		}
		graph_data["edges"].append(edge_data)
	
	var file = FileAccess.open(file_path, FileAccess.WRITE)
	if file == null:
		push_error("Eroare la deschiderea fișierului pentru scriere: ", file_path)
		return
	file.store_string(JSON.stringify(graph_data, "  ", false))
	file.close()
	print("Graf salvat în: ", file_path)

func _on_undo_pressed():
	if undo_stack.empty():
		print("Undo stack empty")
		return
	var action = undo_stack.pop_back()
	_undo_disabled = true
	match action["action"]:
		"add_connections":
			for c in action["connections"]:
				if c in connections_list:
					connections_list.erase(c)
			update_connections()
		"remove_connections":
			for c in action["connections"]:
				if c not in connections_list:
					connections_list.append(c)
			update_connections()
		_:
			print("Unknown undo action:", action)
	_undo_disabled = false
	redo_stack.append(action)

func _on_redo_pressed():
	if redo_stack.empty():
		print("Redo stack empty")
		return
	var action = redo_stack.pop_back()
	_undo_disabled = true
	match action["action"]:
		"add_connections":
			for c in action["connections"]:
				if c not in connections_list:
					connections_list.append(c)
			update_connections()
		"remove_connections":
			for c in action["connections"]:
				if c in connections_list:
					connections_list.erase(c)
			update_connections()
		_:
			print("Unknown redo action:", action)
	_undo_disabled = false
	undo_stack.append(action)

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
	
	# Șterge nodurile existente
	for node in ui_circles_container.get_children():
		node.queue_free()
	connections_list.clear()
	# Nu mai gestionăm noduri Interax în scenă
	
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
				# Nu mai creăm noduri Interax în scenă - se ignoră
				print("Ignor nod Interax din JSON, se folosește editorul separat")
				continue
			_:
				push_error("Tip de nod necunoscut: ", node_shape)
				continue
		
		var pos_x = 100 + next_id * 30
		var pos_y = 100 + next_id * 30
		if node_data.has("pos_x") and node_data.has("pos_y"):
			pos_x = node_data["pos_x"]
			pos_y = node_data["pos_y"]
		new_node.global_position = Vector2(pos_x, pos_y)
		new_node.type = node_data["type"].capitalize()
		if node_data.has("label"):
			new_node.obj_name = node_data["label"]
		elif node_data.has("node_info") and node_data["node_info"].has("name"):
			new_node.obj_name = node_data["node_info"]["name"]
		elif node_data.has("properties") and node_data["properties"].has("name"):
			new_node.obj_name = node_data["properties"]["name"]
		else:
			new_node.obj_name = "Node" + str(next_id)
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
		# Nu mai procesăm noduri Interax în scenă
		id_map[node_data["id"]] = new_node
		next_id += 1
		ui_circles_container.add_child(new_node)
		new_node.circle_selected_for_connection.connect(_on_circle_selected_for_connection)
		new_node.circle_selected_for_properties.connect(_on_circle_selected_for_properties)
		# Nu mai conectez semnalele pentru nodurile Interax - folosim editorul separat
	
	# Creează conexiunile din JSON
	for edge_data in graph_data["edges"]:
		var source_node = id_map.get(edge_data["source"])
		var target_node = id_map.get(edge_data["target"])
		if source_node and target_node:
			var obj_name = edge_data.get("label", "Edge" + str(connections_list.size() + 1))
			var type = edge_data.get("type", "Process").capitalize()
			var conn_uuid = edge_data.get("uuid", "")
			var properties = edge_data.get("properties", {})
			
			# Load midpoint
			var midpoint = Vector2.ZERO
			if edge_data.has("midpoint"):
				var mp = edge_data["midpoint"]
				if typeof(mp) == TYPE_DICTIONARY:
					midpoint = Vector2(mp.get("x", 0.0), mp.get("y", 0.0))
				elif typeof(mp) == TYPE_VECTOR2:
					midpoint = mp
			
			# Load layer
			var layer = edge_data.get("layer", "connections")
			
			# Load attached nodes
			var attached_nodes = edge_data.get("attached_nodes", [])
			
			# If no UUID exists, generate one
			if conn_uuid == "":
				conn_uuid = UUIDGenerator.generate_uuid()
			
			# Create connection with all data: [from, to, label, type, uuid, properties, midpoint, layer, attached_nodes]
			var conn = [source_node, target_node, obj_name, type, conn_uuid, properties, midpoint, layer, attached_nodes]
			connections_list.append(conn)
			print("Conexiune restaurată:", source_node.obj_name, "->", target_node.obj_name, " UUID:", conn_uuid, " Layer:", layer)
		else:
			push_error("Conexiune invalidă: nod sursă sau țintă lipsă pentru ", edge_data)
	
	# Actualizează conexiunile vizuale
	if ui_connections != null:
		ui_connections.update_connections(connections_list)
		ui_connections.queue_redraw()
	update_scene()
	print("Graf încărcat din: ", file_path)

# Funcții helper pentru acces la starea Room multi-select
func get_room_source_node():
	return room_source_node

func get_selected_circle():
	return selected_circle

# Anulează modul de multi-select pentru Room
func _cancel_room_multi_select():
	room_multi_select_mode = false
	room_source_node = null
	room_connected_nodes.clear()
	room_connection_type = ""
	# Resetează starea de selecție vizuală pentru toate nodurile
	for node in ui_circles_container.get_children():
		if node.has_method("reset_connection_selection"):
			node.reset_connection_selection()
	print("Room multi-select anulat")

	# Hide UI indicator and cancel button
	if ui_multi_select_label:
		ui_multi_select_label.visible = false
	if ui_multi_select_cancel_button:
		ui_multi_select_cancel_button.visible = false

# Finalizează modul de multi-select pentru Room
func _finish_room_multi_select():
	if room_source_node != null and room_connected_nodes.size() > 0:
		# Salvează nodurile conectate în node_info al nodului Room sursă
		if room_source_node.has_method("get") and "node_info" in room_source_node:
			if room_source_node.node_info == null:
				room_source_node.node_info = {}
			
			var connected_node_ids = []
			for connected_node in room_connected_nodes:
				connected_node_ids.append(connected_node.id)
			
			# Salvează în funcție de tipul de conectare
			if room_connection_type == "nodes":
				room_source_node.node_info["connected_nodes"] = connected_node_ids
			elif room_connection_type == "windows_doors":
				room_source_node.node_info["connected_windows_doors"] = connected_node_ids
			
			# Creează conexiuni vizuale cu etichete diferite
			# Create connections but do not individually push undo; gather them then push a single undo action
			var created_conns = []
			for connected_node in room_connected_nodes:
				var connection_label = ""
				if room_connection_type == "nodes":
					connection_label = "Room_Node_" + str(connections_list.size() + 1)
				else:
					connection_label = "Room_WinDoor_" + str(connections_list.size() + 1)
				
				var new_connection = create_connection(room_source_node, connected_node, connection_label, "Process")
				# create_connection already pushed individual undo; replace that with a single batch undo
				# Remove last undo entry pushed and instead record all created connections
				if not undo_stack.empty() and undo_stack[-1]["action"] == "add_connections":
					undo_stack.pop_back()
				created_conns.append(new_connection)
			if created_conns.size() > 0:
				_push_undo({"action": "add_connections", "connections": created_conns})
			
			print("Room multi-select finalizat: ", room_source_node.obj_name, " conectat cu ", room_connected_nodes.size(), " ", room_connection_type)
			update_connections()
	# Resetează starea
	room_multi_select_mode = false
	room_source_node = null
	room_connected_nodes.clear()
	room_connection_type = ""
	# Resetează starea vizuală
	for node in ui_circles_container.get_children():
		if node.has_method("reset_connection_selection"):
			node.reset_connection_selection()

	# Hide UI indicator and cancel button
	if ui_multi_select_label:
		ui_multi_select_label.visible = false
	if ui_multi_select_cancel_button:
		ui_multi_select_cancel_button.visible = false

# Activate attach mode for a connection
func _activate_attach_mode(connection: Array):
	attach_to_midpoint_mode = true
	attach_target_connection = connection
	_update_attach_mode_ui()
	print("Attach mode activated. Click on a node (Window/Door) to attach it to the midpoint.")

# Cancel attach mode
func _cancel_attach_mode():
	attach_to_midpoint_mode = false
	attach_target_connection = null
	_update_attach_mode_ui()
	print("Attach mode cancelled")

# Update UI to show/hide attach mode indicator
func _update_attach_mode_ui():
	# Find or create attach mode label
	var attach_label = $CanvasLayer.get_node_or_null("AttachModeLabel")
	
	if attach_to_midpoint_mode:
		if attach_label == null:
			attach_label = Label.new()
			attach_label.name = "AttachModeLabel"
			attach_label.text = "ATTACH MODE: Click on a node to attach to midpoint"
			attach_label.position = Vector2(400, 10)
			attach_label.add_theme_color_override("font_color", Color.YELLOW)
			attach_label.add_theme_font_size_override("font_size", 16)
			$CanvasLayer.add_child(attach_label)
		attach_label.visible = true
	else:
		if attach_label:
			attach_label.visible = false

# Attach a node to a connection's midpoint
func _attach_node_to_connection(node, connection):
	var node_uuid = node.node_info.get("uuid", "")
	if node_uuid == "":
		push_error("Node doesn't have UUID!")
		return
	
	# Ensure connection[8] exists (attached_nodes array)
	if connection.size() < 9:
		while connection.size() < 9:
			if connection.size() == 6:
				connection.append(Vector2.ZERO)  # midpoint offset
			elif connection.size() == 7:
				connection.append("connections")  # layer
			elif connection.size() == 8:
				connection.append([])  # attached_nodes
	
	# Add UUID if not already attached
	var attached_nodes = connection[8]
	if node_uuid not in attached_nodes:
		attached_nodes.append(node_uuid)
		update_connections()
		print("Node ", node.obj_name, " (UUID: ", node_uuid, ") attached to connection midpoint")
	else:
		print("Node ", node.obj_name, " is already attached to this connection")
