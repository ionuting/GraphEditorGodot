extends Node3D

@onready var shape_layer = $CanvasLayer/ShapeLayer
@onready var polygon_drawer = $CanvasLayer/PolygonDrawer2D
@onready var solid_container = $SolidContainer
@onready var polygon_container = $PolygonContainer
@onready var ui_control = $Control
@onready var canvas_layer = $CanvasLayer

var solid_factory: SolidFactory
var tetris_solids: Array[CSGPolygon3D] = []
var polygon_solid: CSGPolygon3D
var selected_shape: TetrisShape2D = null

# New modular components
var shape_manager: ShapeManager
var property_panel: PropertyPanel

# Legacy properties panel variables (replaced by modular PropertyPanel)
var properties_panel: Control = null
var width_spinbox: SpinBox = null
var height_spinbox: SpinBox = null
var extrusion_spinbox: SpinBox = null
var properties_visible: bool = false

# Mode controls
var draw_polygon_enabled: bool = false
var move_mode_enabled: bool = false
var is_3d_view_mode: bool = false

# 3D Camera controls
var camera_3d: Camera3D = null
var camera_pivot: Node3D = null
var camera_distance: float = 10.0
var camera_angle_h: float = 0.0
var camera_angle_v: float = -20.0
var is_3d_rotating: bool = false
var rotate_start: Vector2

# 2D Camera/Zoom controls
var camera_position: Vector2 = Vector2.ZERO
var zoom_level: float = 1.0
var min_zoom: float = 0.2
var max_zoom: float = 5.0
var is_panning: bool = false
var pan_start: Vector2

func _ready():
	# Add to group for easy access
	add_to_group("main")
	
	# Create SolidFactory instance
	solid_factory = SolidFactory.new()
	add_child(solid_factory)
	
	# Setup modular components
	_setup_modular_components()
	
	# Setup 3D camera
	_setup_3d_camera()
	
	# Setup UI
	setup_ui()
	
	# Connect signals
	if polygon_drawer:
		polygon_drawer.polygon_changed.connect(_on_polygon_changed)
	
	# Setup camera transform
	_update_camera_transform()
	
	# Load existing shapes
	_load_existing_shapes()

func _setup_modular_components():
	# Create shape manager
	shape_manager = ShapeManager.get_instance()
	
	# Connect shape manager signals
	shape_manager.shape_added.connect(_on_shape_added)
	shape_manager.shape_removed.connect(_on_shape_removed)
	shape_manager.shape_modified.connect(_on_shape_modified)
	
	# Create property panel
	property_panel = preload("res://ui/PropertyPanel.gd").new()
	add_child(property_panel)
	
	# Connect property panel signals
	property_panel.property_changed.connect(_on_property_changed)
	property_panel.panel_closed.connect(_on_property_panel_closed)
	property_panel.shape_color_change_requested.connect(_on_shape_color_changed)
	property_panel.shape_delete_requested.connect(_on_shape_delete_requested)
	property_panel.rebuild_building_requested.connect(_on_rebuild_building_requested)
	
	print("✓ Modular components initialized")

func _load_existing_shapes():
	var loaded_shapes_data = shape_manager.load_shapes()
	
	for shape_data in loaded_shapes_data:
		var shape = shape_manager.create_shape_from_data(shape_data, shape_layer)
		shape.shape_selected.connect(_on_shape_selected.bind(shape))

func _setup_3d_camera():
	# Create camera pivot point
	camera_pivot = Node3D.new()
	camera_pivot.name = "CameraPivot"
	add_child(camera_pivot)
	
	# Create 3D camera
	camera_3d = Camera3D.new()
	camera_3d.name = "Camera3D"
	camera_pivot.add_child(camera_3d)
	
	# Position camera
	camera_3d.position = Vector3(0, 0, camera_distance)
	camera_3d.look_at_from_position(Vector3(0, 0, camera_distance), Vector3.ZERO, Vector3.UP)
	
	# Initially disabled (2D mode)
	camera_3d.current = false
	
	# Add lighting for better 3D visualization
	var light = DirectionalLight3D.new()
	light.name = "DirectionalLight3D"
	add_child(light)
	light.position = Vector3(5, 10, 5)
	light.look_at_from_position(Vector3(5, 10, 5), Vector3.ZERO, Vector3.UP)
	light.light_energy = 1.0
	
	# Add ambient light
	var env = Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.1, 0.1, 0.15)
	env.ambient_light_color = Color(0.3, 0.3, 0.4)
	env.ambient_light_energy = 0.3
	camera_3d.environment = env
	
	# Position pivot at center of scene
	_update_3d_camera_position()

func _update_3d_camera_position():
	if not camera_pivot or not camera_3d:
		return
		
	# Update pivot rotation based on angles
	camera_pivot.rotation_degrees = Vector3(camera_angle_v, camera_angle_h, 0)
	
	# Update camera distance
	camera_3d.position = Vector3(0, 0, camera_distance)
	camera_3d.look_at(Vector3.ZERO, Vector3.UP)

func _calculate_scene_center() -> Vector3:
	var center = Vector3.ZERO
	var count = 0
	
	# Calculate center of all tetris solids
	for solid in tetris_solids:
		if solid and is_instance_valid(solid):
			center += solid.global_position
			count += 1
	
	# Add polygon solid if exists
	if polygon_solid and is_instance_valid(polygon_solid):
		center += polygon_solid.global_position
		count += 1
	
	if count > 0:
		return center / count
	else:
		return Vector3.ZERO

func _input(event):
	if is_3d_view_mode:
		_handle_3d_camera_input(event)
	else:
		_handle_camera_input(event)

func _handle_3d_camera_input(event):
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			camera_distance = max(3.0, camera_distance - 1.0)
			_update_3d_camera_position()
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			camera_distance = min(50.0, camera_distance + 1.0)
			_update_3d_camera_position()
		elif event.button_index == MOUSE_BUTTON_MIDDLE:
			if event.pressed:
				is_3d_rotating = true
				rotate_start = event.position
			else:
				is_3d_rotating = false
		elif event.button_index == MOUSE_BUTTON_RIGHT:
			if event.pressed:
				is_3d_rotating = true
				rotate_start = event.position
			else:
				is_3d_rotating = false
	
	elif event is InputEventMouseMotion and is_3d_rotating:
		var delta = event.position - rotate_start
		camera_angle_h += delta.x * 0.5
		camera_angle_v += delta.y * 0.5
		camera_angle_v = clamp(camera_angle_v, -90, 90)
		rotate_start = event.position
		_update_3d_camera_position()

func _handle_camera_input(event):
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			_zoom_at_point(event.position, 1.1)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_zoom_at_point(event.position, 0.9)
		elif event.button_index == MOUSE_BUTTON_MIDDLE:
			if event.pressed:
				is_panning = true
				pan_start = event.position
			else:
				is_panning = false
	
	elif event is InputEventMouseMotion and is_panning:
		var delta = event.position - pan_start
		camera_position -= delta / zoom_level
		pan_start = event.position
		_update_camera_transform()

func _zoom_at_point(point: Vector2, zoom_factor: float):
	var old_zoom = zoom_level
	zoom_level = clamp(zoom_level * zoom_factor, min_zoom, max_zoom)
	
	if zoom_level != old_zoom:
		# Adjust camera position to zoom at the mouse point
		var screen_center = Vector2(get_viewport().size) / 2
		var offset_from_center = (point - screen_center) / old_zoom
		camera_position += offset_from_center * (1.0 - zoom_level / old_zoom)
		_update_camera_transform()

func _update_camera_transform():
	if canvas_layer:
		canvas_layer.transform = Transform2D.IDENTITY
		canvas_layer.transform = canvas_layer.transform.scaled(Vector2(zoom_level, zoom_level))
		canvas_layer.transform.origin = camera_position * zoom_level + Vector2(get_viewport().size) / 2

func setup_ui():
	# Setup the UI container
	ui_control.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	ui_control.position = Vector2(10, 10)
	ui_control.size = Vector2(300, 600)
	
	# Create main VBox
	var main_vbox = VBoxContainer.new()
	ui_control.add_child(main_vbox)
	
	# Title
	var title = Label.new()
	title.text = "Abstract House Maker"
	title.add_theme_font_size_override("font_size", 18)
	main_vbox.add_child(title)
	
	main_vbox.add_child(HSeparator.new())
	
	# Tetris Shapes Section
	var shapes_label = Label.new()
	shapes_label.text = "Forme Tetris:"
	shapes_label.add_theme_font_size_override("font_size", 14)
	main_vbox.add_child(shapes_label)
	
	var shapes_hbox = HBoxContainer.new()
	main_vbox.add_child(shapes_hbox)
	
	var btn_rectangle = Button.new()
	btn_rectangle.text = "□"
	btn_rectangle.custom_minimum_size = Vector2(40, 40)
	btn_rectangle.pressed.connect(_on_add_rectangle)
	shapes_hbox.add_child(btn_rectangle)
	
	var btn_l_shape = Button.new()
	btn_l_shape.text = "L"
	btn_l_shape.custom_minimum_size = Vector2(40, 40)
	btn_l_shape.pressed.connect(_on_add_l_shape)
	shapes_hbox.add_child(btn_l_shape)
	
	var btn_t_shape = Button.new()
	btn_t_shape.text = "T"
	btn_t_shape.custom_minimum_size = Vector2(40, 40)
	btn_t_shape.pressed.connect(_on_add_t_shape)
	shapes_hbox.add_child(btn_t_shape)
	
	main_vbox.add_child(HSeparator.new())
	
	# Polygon Section
	var polygon_label = Label.new()
	polygon_label.text = "Poligon (Click stânga = adaugă punct, Click dreapta = închide):"
	polygon_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	main_vbox.add_child(polygon_label)
	
	var btn_clear_polygon = Button.new()
	btn_clear_polygon.text = "Șterge Poligon"
	btn_clear_polygon.pressed.connect(_on_clear_polygon)
	main_vbox.add_child(btn_clear_polygon)
	
	# Toggle buttons for modes
	var btn_draw_polygon = Button.new()
	btn_draw_polygon.text = "🖊️ Desenează Poligon"
	btn_draw_polygon.toggle_mode = true
	btn_draw_polygon.toggled.connect(_on_draw_polygon_toggled)
	main_vbox.add_child(btn_draw_polygon)
	
	var btn_move_mode = Button.new()
	btn_move_mode.text = "↔️ Mutare Forme"
	btn_move_mode.toggle_mode = true
	btn_move_mode.toggled.connect(_on_move_mode_toggled)
	main_vbox.add_child(btn_move_mode)
	
	main_vbox.add_child(HSeparator.new())
	
	# View Mode Toggle
	var btn_toggle_3d = Button.new()
	btn_toggle_3d.text = "🎬 Vedere 3D"
	btn_toggle_3d.toggle_mode = true
	btn_toggle_3d.toggled.connect(_on_toggle_3d_view)
	main_vbox.add_child(btn_toggle_3d)
	
	main_vbox.add_child(HSeparator.new())
	
	# 3D Operations Section
	var operations_label = Label.new()
	operations_label.text = "Operații 3D:"
	operations_label.add_theme_font_size_override("font_size", 14)
	main_vbox.add_child(operations_label)
	
	var btn_create_tetris = Button.new()
	btn_create_tetris.text = "Creează Solide Tetris"
	btn_create_tetris.pressed.connect(_on_create_tetris_solids)
	main_vbox.add_child(btn_create_tetris)
	
	var btn_create_polygon = Button.new()
	btn_create_polygon.text = "Creează Solid Poligon"
	btn_create_polygon.pressed.connect(_on_create_polygon_solid)
	main_vbox.add_child(btn_create_polygon)
	
	var btn_apply_cut = Button.new()
	btn_apply_cut.text = "Taie Contur cu Camere"
	btn_apply_cut.pressed.connect(_on_apply_csg_cut)
	main_vbox.add_child(btn_apply_cut)
	
	var btn_test_csg = Button.new()
	btn_test_csg.text = "🔍 Test CSG Result"
	btn_test_csg.pressed.connect(_on_test_csg_result)
	main_vbox.add_child(btn_test_csg)
	
	var btn_build_complete = Button.new()
	btn_build_complete.text = "🏗️ Build with Windows & Doors"
	btn_build_complete.pressed.connect(_on_build_complete_structure)
	main_vbox.add_child(btn_build_complete)
	
	main_vbox.add_child(HSeparator.new())
	
	# Shape Management Section
	var management_label = Label.new()
	management_label.text = "Shape Management:"
	management_label.add_theme_font_size_override("font_size", 14)
	main_vbox.add_child(management_label)
	
	var btn_validate_all = Button.new()
	btn_validate_all.text = "🔍 Validate All Shapes"
	btn_validate_all.pressed.connect(_on_validate_all_shapes)
	main_vbox.add_child(btn_validate_all)
	
	var btn_show_statistics = Button.new()
	btn_show_statistics.text = "📊 Show Statistics"
	btn_show_statistics.pressed.connect(_on_show_statistics)
	main_vbox.add_child(btn_show_statistics)
	
	var btn_export_shapes = Button.new()
	btn_export_shapes.text = "💾 Export Shapes"
	btn_export_shapes.pressed.connect(_on_export_shapes)
	main_vbox.add_child(btn_export_shapes)
	
	var btn_clear_all = Button.new()
	btn_clear_all.text = "Șterge Tot"
	btn_clear_all.pressed.connect(_on_clear_all)
	main_vbox.add_child(btn_clear_all)
	
	var btn_reset_view = Button.new()
	btn_reset_view.text = "🔍 Reset View"
	btn_reset_view.pressed.connect(_on_reset_view)
	main_vbox.add_child(btn_reset_view)
	
	main_vbox.add_child(HSeparator.new())
	
	# Instructions
	var instructions = Label.new()
	instructions.text = "Instrucțiuni:\n• Adaugă forme tetris cu butoanele\n• Toggle 'Desenează Poligon' pentru a desena\n• Toggle 'Mutare Forme' pentru editare:\n  - Click pe puncte verzi = mutare punct individual\n  - Click în formă = mutare întreaga formă\n  - Click în afară = deselecționează\n  - PANOUL PROPRIETĂȚI apare la click pe formă\n• Toggle 'Vedere 3D' pentru viewer 3D:\n  - Click dreapta + drag = rotește camera\n  - Mouse wheel = zoom în/out\n• Operații 3D:\n  - Solidele interioare (albastre) taie solidul exterior (verde)\n  - Rezultatul CSG este orange cu găuri\n• Mouse wheel = zoom (2D)\n• Mouse mijloc + drag = pan (2D)\n• Click dreapta închide poligonul"
	instructions.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	instructions.custom_minimum_size.y = 280
	main_vbox.add_child(instructions)

func _on_add_rectangle():
	_add_tetris_shape("rectangle", Vector2(400, 300))

func _on_add_l_shape():
	_add_tetris_shape("L", Vector2(600, 300))

func _on_add_t_shape():
	_add_tetris_shape("T", Vector2(800, 300))

func _add_tetris_shape(type: String, pos: Vector2):
	var TetrisShape2D = load("res://TetrisShape2D.gd")
	var shape = TetrisShape2D.new()
	shape.shape_type = type
	shape.position = pos
	shape.add_to_group("tetris_shapes")
	
	# Connect selection signal
	shape.shape_selected.connect(_on_shape_selected.bind(shape))
	
	shape_layer.add_child(shape)
	
	# Add to shape manager
	shape_manager.add_shape(shape)

func _on_shape_selected(shape: TetrisShape2D):
	# Deselect all other shapes
	for other_shape in shape_layer.get_children():
		if other_shape != shape and other_shape.has_method("set_selected"):
			other_shape.set_selected(false)
	
	# Set current selected shape and show property panel
	selected_shape = shape
	if property_panel:
		property_panel.set_shape(shape)
		
		# Setup realtime validation
		var AutoValidator = preload("res://ui/AutoValidator.gd")
		AutoValidator.setup_realtime_validation(shape, property_panel)

func _on_clear_polygon():
	if polygon_drawer:
		polygon_drawer.clear_polygon()

func _on_draw_polygon_toggled(pressed: bool):
	draw_polygon_enabled = pressed
	if polygon_drawer:
		polygon_drawer.set_drawing_enabled(pressed)
	
	# Disable move mode when polygon drawing is enabled
	if pressed:
		move_mode_enabled = false
		_deselect_all_shapes()

func _on_move_mode_toggled(pressed: bool):
	move_mode_enabled = pressed
	
	# Disable polygon drawing when move mode is enabled
	if pressed:
		draw_polygon_enabled = false
		if polygon_drawer:
			polygon_drawer.set_drawing_enabled(false)
	else:
		_deselect_all_shapes()

func _on_toggle_3d_view(pressed: bool):
	is_3d_view_mode = pressed
	
	if pressed:
		# Switch to 3D view
		if camera_3d:
			camera_3d.current = true
		canvas_layer.visible = false
		# Center camera on scene
		var scene_center = _calculate_scene_center()
		camera_pivot.global_position = scene_center
		_update_3d_camera_position()
		print("Switched to 3D view - Use right mouse button to rotate, wheel to zoom")
	else:
		# Switch to 2D view
		if camera_3d:
			camera_3d.current = false
		canvas_layer.visible = true
		print("Switched to 2D view")

func _deselect_all_shapes():
	for shape in shape_layer.get_children():
		if shape.has_method("set_selected"):
			shape.set_selected(false)

func _on_polygon_changed():
	print("Polygon changed - ready for 3D operations")

func _on_create_tetris_solids():
	# Clear existing tetris solids
	for solid in tetris_solids:
		solid.queue_free()
	tetris_solids.clear()
	
	# Create new solids from shapes
	for shape in shape_layer.get_children():
		if shape.has_method("get_offset_vertices_world"):
			# Get vertices relative to shape position (local coordinates)
			var vertices: Array[Vector2] = []
			for vertex in shape.offset_vertices:
				vertices.append(vertex)
			
			var shape_type = shape.get("shape_type") if shape.has_method("get") else ""
			var solid = solid_factory.create_extruded_shape(vertices, shape.extrusion_height, shape_type)
			if solid:
				# Add to scene first, then set position
				solid_container.add_child(solid)
				solid.position = Vector3(shape.position.x, shape.position.y, shape.extrusion_height/2)
				tetris_solids.append(solid)
				print("Created tetris solid at: ", solid.position)

	# Assign `cell` property to Tetris solids
	for tetris_solid in tetris_solids:
		tetris_solid.set_meta("cell", true)
		print("Assigned 'cell' property to Tetris solid: ", tetris_solid.name)

func _on_create_polygon_solid():
	# Clear existing polygon solid
	if polygon_solid:
		polygon_solid.queue_free()
	
	if polygon_drawer and polygon_drawer.offset_points.size() > 2:
		# Use local coordinates and set position explicitly
		var vertices = polygon_drawer.offset_points
		polygon_solid = solid_factory.create_extruded_shape(vertices, polygon_drawer.extrusion_height, "outer_wall")
		if polygon_solid:
			# Add to scene first, then set position
			polygon_container.add_child(polygon_solid)
			polygon_solid.position = Vector3(0, 0, polygon_drawer.extrusion_height/2)
			print("Created polygon solid at: ", polygon_solid.position)

	# Assign `shell` property to the polyline-generated shape
	if polygon_solid:
		polygon_solid.set_meta("shell", true)
		print("Assigned 'shell' property to polyline-generated shape: ", polygon_solid.name)

func _on_apply_csg_cut():
	if not polygon_solid or tetris_solids.size() == 0:
		print("Trebuie să creezi atât solidele tetris cât și solidul poligon!")
		return
	
	# Create complete building with windows and doors using new SolidFactory logic
	var outer_vertices = polygon_drawer.get_offset_polygon()
	var outer_height = polygon_drawer.extrusion_height
	var tetris_shapes = _get_all_tetris_shapes()
	
	# Validare vertices
	if outer_vertices.size() < 3:
		print("⚠️ Poligonul exterior trebuie să aibă cel puțin 3 vertices!")
		return
	
	print("🏗️ Creating complete building with ", tetris_shapes.size(), " rooms")
	print("🏗️ Outer vertices: ", outer_vertices.size())
	print("🏗️ Building height: ", outer_height)
	
	# Sincronizează proprietățile din PropertyPanel/JSON înapoi în obiectele TetrisShape2D
	_sync_shape_properties_from_manager(tetris_shapes)
	
	var csg_result = solid_factory.create_complete_building_with_windows_doors(outer_vertices, outer_height, tetris_shapes)
	
	# Ensure the CSG result is not already in the scene tree
	if csg_result.get_parent():
		csg_result.get_parent().remove_child(csg_result)
	
	# Add to scene and position
	solid_container.add_child(csg_result)
	csg_result.position = Vector3.ZERO
	
	print("✅ Complete building with windows and doors added to scene at: ", csg_result.position)
	
	# Hide original shapes
	polygon_solid.visible = false
	for tetris_solid in tetris_solids:
		tetris_solid.visible = false
	
	print("Poligon exterior tăiat de ", tetris_solids.size(), " camere tetris")

func _get_all_tetris_shapes() -> Array:
	"""
	Colectează toate shape-urile TetrisShape2D din scenă pentru a le trimite la SolidFactory
	"""
	var shapes: Array = []
	
	# Caută în copiii direcți ai scenei
	for child in get_children():
		if child is TetrisShape2D:
			shapes.append(child)
	
	# Caută și în shape_layer dacă există
	if shape_layer:
		for child in shape_layer.get_children():
			if child is TetrisShape2D:
				shapes.append(child)
	
	print("📊 Found ", shapes.size(), " TetrisShape2D objects in scene")
	
	# Debug info pentru fiecare shape
	for i in range(shapes.size()):
		var shape = shapes[i]
		var has_win = shape.has_window and shape.window_height > 0
		var has_door = shape.has_door and shape.door_height > 0
		print("  • Shape ", i, ": ", shape.room_name, " | Window: ", has_win, " | Door: ", has_door)
	
	return shapes

func _on_build_complete_structure():
	"""
	Funcție dedicată pentru testarea noii funcționalități cu ferestre și uși
	"""
	if not polygon_solid:
		print("⚠️ Trebuie să creezi mai întâi solidul poligon!")
		return
		
	var tetris_shapes = _get_all_tetris_shapes()
	if tetris_shapes.size() == 0:
		print("⚠️ Trebuie să existe cel puțin o formă Tetris în scenă!")
		return
	
	# Curăță rezultatele anterioare
	_clear_solid_container()
	
	# Creează structura completă cu ferestre și uși
	var outer_vertices = polygon_drawer.get_offset_polygon()
	var outer_height = polygon_drawer.extrusion_height
	
	# Validare vertices
	if outer_vertices.size() < 3:
		print("⚠️ Poligonul exterior trebuie să aibă cel puțin 3 vertices!")
		return
	
	print("🏗️ Building complete structure...")
	print("   • Outer polygon vertices: ", outer_vertices.size())
	print("   • Building height: ", outer_height, "m")
	print("   • Tetris shapes: ", tetris_shapes.size())
	
	# Sincronizează proprietățile din PropertyPanel/JSON înapoi în obiectele TetrisShape2D
	_sync_shape_properties_from_manager(tetris_shapes)
	
	var complete_building = solid_factory.create_complete_building_with_windows_doors(
		outer_vertices, 
		outer_height, 
		tetris_shapes
	)
	
	if complete_building:
		solid_container.add_child(complete_building)
		complete_building.position = Vector3.ZERO
		
		# Ascunde shape-urile originale pentru claritate
		if polygon_solid:
			polygon_solid.visible = false
		for tetris_solid in tetris_solids:
			tetris_solid.visible = false
		
		print("✅ Complete building created successfully!")
		print("🎯 Switch to 3D view to see windows and doors!")
	else:
		print("❌ Failed to create complete building")

func _clear_solid_container():
	"""Helper pentru curățarea containerului de solide"""
	for child in solid_container.get_children():
		child.queue_free()

func _on_test_csg_result():
	var csg_nodes = solid_container.get_children().filter(func(node): return node is CSGCombiner3D)
	print("Found ", csg_nodes.size(), " CSG nodes in solid container")
	
	for i in range(csg_nodes.size()):
		var csg_node = csg_nodes[i]
		print("CSG Node ", i, ":")
		print("  - Children: ", csg_node.get_children().size())
		print("  - Position: ", csg_node.global_position)
		print("  - Visible: ", csg_node.visible)
		print("  - Operation: ", csg_node.operation)
		
		for j in range(csg_node.get_children().size()):
			var child = csg_node.get_children()[j]
			if child is CSGMesh3D:
				print("    Child ", j, " (CSGMesh3D): operation=", child.operation, " pos=", child.global_position)

func _on_clear_all():
	# Clear all shapes using shape manager
	shape_manager.clear_all_shapes()
	
	# Clear shapes from scene
	for child in shape_layer.get_children():
		child.queue_free()
	
	# Clear polygon
	_on_clear_polygon()
	
	# Clear 3D objects
	for child in solid_container.get_children():
		child.queue_free()
	
	for child in polygon_container.get_children():
		child.queue_free()
	
	tetris_solids.clear()
	polygon_solid = null
	selected_shape = null
	
	# Hide property panel
	if property_panel:
		property_panel.set_shape(null)

# Legacy functions - replaced by PropertyPanel module
func _on_width_changed(value: float):
	# Handled by PropertyPanel
	pass

func _on_height_changed(value: float):
	# Handled by PropertyPanel
	pass

func _on_extrusion_changed(value: float):
	# Handled by PropertyPanel
	pass

func _on_close_properties():
	# Handled by PropertyPanel
	pass

func _show_properties_panel(shape: TetrisShape2D):
	# Handled by PropertyPanel
	pass

func _on_reset_view():
	if is_3d_view_mode:
		# Reset 3D camera
		camera_distance = 10.0
		camera_angle_h = 0.0
		camera_angle_v = -20.0
		_update_3d_camera_position()
	else:
		# Reset 2D camera
		camera_position = Vector2.ZERO
		zoom_level = 1.0
		_update_camera_transform()

# Shape Manager Signal Handlers
func _on_shape_added(shape: TetrisShape2D):
	print("✓ Shape added: ", shape.unique_id)

func _on_shape_removed(shape: TetrisShape2D):
	print("✓ Shape removed: ", shape.unique_id)
	if selected_shape == shape:
		selected_shape = null
		if property_panel:
			property_panel.set_shape(null)

func _on_shape_modified(shape: TetrisShape2D):
	print("✓ Shape modified: ", shape.unique_id)

# Property Panel Signal Handlers
func _on_property_changed(property_name: String, value):
	print("Property changed: %s = %s" % [property_name, str(value)])
	
	# Apply the property change to the currently selected shape
	if selected_shape:
		# Update the shape property
		match property_name:
			"width":
				var current_dim = selected_shape.get_current_dimensions()
				selected_shape.set_dimensions(Vector2(value, current_dim.y))
			"height":
				var current_dim = selected_shape.get_current_dimensions()
				selected_shape.set_dimensions(Vector2(current_dim.x, value))
			"extrusion_height":
				selected_shape.extrusion_height = value
			"interior_offset":
				selected_shape.interior_offset = value
			"room_name":
				selected_shape.room_name = value
			"central_color":
				selected_shape.central_color = value
			"has_window":
				selected_shape.has_window = value
			"window_style":
				selected_shape.window_style = value
			"window_side":
				selected_shape.window_side = value
			"window_offset":
				selected_shape.window_offset = value
			"window_n_offset":
				selected_shape.window_n_offset = value
			"window_z_offset":
				selected_shape.window_z_offset = value
			"window_width":
				selected_shape.window_width = value
			"window_length":
				selected_shape.window_length = value
			"window_height":
				selected_shape.window_height = value
			"window_sill":
				selected_shape.window_sill = value
			"has_door":
				selected_shape.has_door = value
			"door_style":
				selected_shape.door_style = value
			"door_side":
				selected_shape.door_side = value
			"door_offset":
				selected_shape.door_offset = value
			"door_n_offset":
				selected_shape.door_n_offset = value
			"door_z_offset":
				selected_shape.door_z_offset = value
			"door_width":
				selected_shape.door_width = value
			"door_length":
				selected_shape.door_length = value
			"door_height":
				selected_shape.door_height = value
			"door_sill":
				selected_shape.door_sill = value
		
		# Mark the shape as modified and trigger the signal
		# This will update the ShapeManager with the new properties
		selected_shape.shape_changed.emit()
		
		print("✅ Applied property change to shape ", selected_shape.unique_id)

func _on_property_panel_closed():
	if selected_shape:
		selected_shape.set_selected(false)
	selected_shape = null

# New Management Functions
func _on_validate_all_shapes():
	var AutoValidator = preload("res://ui/AutoValidator.gd")
	var results = AutoValidator.validate_all_shapes_in_manager(shape_manager)
	
	print("\n=== VALIDATION RESULTS ===")
	print("Total shapes: ", results.total_validated)
	print("Valid shapes: ", results.valid_shapes)
	print("Invalid shapes: ", results.invalid_shapes)
	print("Total warnings: ", results.total_warnings)
	print("Total errors: ", results.total_errors)
	
	if results.invalid_shapes > 0:
		print("\nShapes with errors:")
		for shape_id in results.shape_results:
			var result = results.shape_results[shape_id]
			if not result.is_valid:
				print("  - %s: %s" % [shape_id, str(result.errors)])

func _on_show_statistics():
	var stats = shape_manager.get_shapes_statistics()
	var geometry = shape_manager.get_geometry_summary()
	
	print("\n=== SHAPE STATISTICS ===")
	print("Total shapes: ", stats.total_count)
	print("Shapes by type: ", stats.by_type)
	print("Shapes with windows: ", stats.with_windows)
	print("Shapes with doors: ", stats.with_doors)
	print("Total area: %.2f" % stats.total_area)
	print("Average area: %.2f" % stats.average_area)
	print("\n=== GEOMETRY SUMMARY ===")
	print("Total interior area: %.2f" % geometry.total_area)
	print("Total perimeter: %.2f" % geometry.total_perimeter)
	print("Total window area: %.2f" % geometry.total_window_area)
	print("Total door area: %.2f" % geometry.total_door_area)

func _on_export_shapes():
	var timestamp = Time.get_datetime_string_from_system().replace(":", "-").replace(" ", "_")
	var export_path = "user://shapes_export_%s.json" % timestamp
	
	if shape_manager.export_shapes_to_json(export_path):
		print("✓ Shapes exported to: ", export_path)
	else:
		print("✗ Failed to export shapes")

func _create_properties_panel():
	# Legacy function - now handled by modular PropertyPanel
	pass

# Function to list all 3D objects in the scene after operations
func list_3d_objects_in_scene():
	print("Listing 3D objects in the scene:")
	for child in get_tree().get_current_scene().get_children():
		if child is MeshInstance3D or child is CSGMesh3D:
			print("Object: ", child.name, ", Type: ", child.get_class(), ", Position: ", child.global_transform.origin)

func _on_shape_color_changed(shape: TetrisShape2D):
	"""Handle shape color change requests from PropertyPanel"""
	if shape and shape == selected_shape:
		print("✓ Shape color changed: ", shape.room_name, " -> ", shape.central_color)
		
		# Update the shape visually if needed
		shape.queue_redraw()
		
		# Save changes through ShapeManager
		if shape_manager:
			shape_manager.save_shapes()
			print("✓ Shape color changes saved")

func _on_shape_delete_requested(shape: TetrisShape2D):
	"""Handle shape deletion requests from PropertyPanel"""
	if shape:
		print("🗑️ Deleting shape: ", shape.room_name if shape.room_name else "Unnamed")
		
		# Remove from ShapeManager
		if shape_manager:
			shape_manager.remove_shape(shape)
			shape_manager.save_shapes()
		
		# Remove from scene
		if shape.get_parent():
			shape.get_parent().remove_child(shape)
		shape.queue_free()
		
		# Clear selection
		if shape == selected_shape:
			selected_shape = null
			_deselect_all_shapes()
		
		print("✓ Shape deleted successfully")

# ========================================
# CSG PRIORITY SYSTEM SUPPORT
# ========================================

# Getter pentru SolidFactory (folosit de PropertyPanel)
func get_solid_factory() -> SolidFactory:
	"""Returnează instanța SolidFactory pentru acces extern"""
	return solid_factory

# Handler pentru rebuild cu priorități
func _on_rebuild_building_requested():
	"""Reconstruiește clădirea folosind sistemul de priorități CSG"""
	print("🔧 Rebuilding complete structure with current CSG priorities...")
	
	# Afișează prioritățile curente
	if solid_factory:
		solid_factory.print_priority_order()
	
	# Reconstruiește structura completă
	_on_build_complete_structure()
	
	print("✅ Building rebuilt with priority system")

# Test CSG functionality
func _test_csg_functionality():
	"""Testează funcționalitatea CSG cu un exemplu simplu"""
	print("🧪 Testing CSG functionality...")
	
	if solid_factory:
		var test_csg = solid_factory.create_simple_csg_test()
		if test_csg:
			solid_container.add_child(test_csg)
			test_csg.position = Vector3(500, 0, 0)  # Pozitionează separat
			print("✅ CSG test added to scene at position: ", test_csg.position)
		else:
			print("❌ Failed to create CSG test")

func _sync_shape_properties_from_manager(tetris_shapes: Array):
	"""
	Sincronizează proprietățile din ShapeManager/PropertyPanel înapoi în obiectele TetrisShape2D
	înainte de a le trimite la SolidFactory pentru generarea 3D
	"""
	var shape_manager = ShapeManager.get_instance()
	
	print("🔄 SYNC: Starting shape properties synchronization for ", tetris_shapes.size(), " shapes...")
	print("🔄 SYNC: ShapeManager has ", shape_manager.shape_properties.size(), " saved properties")
	
	for shape in tetris_shapes:
		if shape is TetrisShape2D:
			var shape_id = shape.unique_id
			if shape_manager.shape_properties.has(shape_id):
				var saved_properties = shape_manager.shape_properties[shape_id]
				print("🔄 SYNC: Syncing properties for shape ", shape_id)
				
				# Debug: valorile ÎNAINTE de sincronizare
				print("  📥 BEFORE sync:")
				print("    - window_offset: ", shape.window_offset, " -> ", saved_properties.get("window_offset", "N/A"))
				print("    - door_offset: ", shape.door_offset, " -> ", saved_properties.get("door_offset", "N/A"))
				print("    - window_side: ", shape.window_side, " -> ", saved_properties.get("window_side", "N/A"))
				print("    - door_side: ", shape.door_side, " -> ", saved_properties.get("door_side", "N/A"))
				
				# Aplicăm proprietățile salvate înapoi în obiect folosind from_dict
				shape.from_dict(saved_properties)
				
				# Debug: valorile DUPĂ sincronizare
				print("  📤 AFTER sync:")
				print("    - window_offset: ", shape.window_offset)
				print("    - door_offset: ", shape.door_offset)
				print("    - window_side: ", shape.window_side)
				print("    - door_side: ", shape.door_side)
				print("    - window_height: ", shape.window_height)
				print("    - door_height: ", shape.door_height)
			else:
				print("⚠️ No saved properties found for shape ", shape_id)
	
	print("✅ Shape properties sync completed")
