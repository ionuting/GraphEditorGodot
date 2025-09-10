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
var viewport_tabs: ViewportTabs

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
var is_3d_panning: bool = false
var rotate_start: Vector2
var pan_start: Vector2
var camera_target: Vector3 = Vector3.ZERO  # Pan target for camera
var navigation_gizmo: Control = null  # Gizmo for 3D navigation

# 2D Camera/Zoom controls
var camera_position: Vector2 = Vector2.ZERO
var zoom_level: float = 1.0
var min_zoom: float = 0.2
var max_zoom: float = 5.0
var is_panning: bool = false


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
	
	# Create viewport tabs
	viewport_tabs = preload("res://ui/ViewportTabs.gd").new()
	add_child(viewport_tabs)
	
	# Connect viewport tabs signals
	viewport_tabs.tab_changed.connect(_on_viewport_tab_changed)
	viewport_tabs.tab_moved.connect(_on_viewport_tab_moved)
	
	# Load saved settings and set initial viewport mode
	call_deferred("_load_viewport_settings")
	call_deferred("_initialize_viewport_mode")
	
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

func _reset_3d_camera():
	# Reset camera angles to default isometric-like view
	camera_angle_h = 0.0
	camera_angle_v = -20.0
	
	# Re-center on scene and set optimal distance
	var scene_center = _calculate_scene_center()
	camera_target = scene_center
	camera_pivot.global_position = scene_center
	
	var scene_bounds = _calculate_scene_bounds()
	if scene_bounds > 0:
		camera_distance = max(scene_bounds * 1.5, 10.0)
	else:
		camera_distance = 10.0
	
	_update_3d_camera_position()
	print("📷 3D Camera Reset - Centered on building")

func _zoom_3d_to_mouse(mouse_pos: Vector2, zoom_factor: float):
	"""
	Zoom către poziția mouse-ului în 3D
	"""
	var old_distance = camera_distance
	var zoom_speed = camera_distance * 0.1
	
	if zoom_factor < 1.0:  # Zoom in
		camera_distance = max(3.0, camera_distance * zoom_factor)
	else:  # Zoom out
		camera_distance = min(50.0, camera_distance * zoom_factor)
	
	# Calculate world position under mouse for zoom target
	var viewport = get_viewport()
	if viewport and camera_3d:
		var camera_world_pos = camera_3d.global_position
		var screen_center = viewport.get_visible_rect().size * 0.5
		var mouse_offset = (mouse_pos - screen_center) / screen_center.length()
		
		# Pan target slightly towards mouse position
		var side_vector = camera_pivot.transform.basis.x
		var up_vector = camera_pivot.transform.basis.y
		var pan_amount = (old_distance - camera_distance) * 0.3
		
		camera_target += side_vector * mouse_offset.x * pan_amount
		camera_target += up_vector * -mouse_offset.y * pan_amount
		camera_pivot.global_position = camera_target
	
	_update_3d_camera_position()

func _pan_3d_camera(delta: Vector2):
	"""
	Pan camera în 3D space
	"""
	if not camera_pivot:
		return
	
	var sensitivity = camera_distance * 0.005  # Pan speed scales with distance
	
	# Get camera's right and up vectors
	var right_vector = camera_pivot.transform.basis.x
	var up_vector = camera_pivot.transform.basis.y
	
	# Pan in screen space
	var pan_offset = right_vector * -delta.x * sensitivity + up_vector * delta.y * sensitivity
	camera_target += pan_offset
	camera_pivot.global_position = camera_target
	
	_update_3d_camera_position()

func _is_mouse_over_property_panel(event) -> bool:
	"""
	Check if mouse is over the property panel to avoid zoom interference
	"""
	if not (event is InputEventMouse):
		return false
	
	var property_panel = get_node_or_null("PropertyPanel")  # Adjust path as needed
	if property_panel and property_panel.visible:
		var panel_rect = Rect2(property_panel.global_position, property_panel.size)
		return panel_rect.has_point(event.global_position)
	return false

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

func _calculate_scene_bounds() -> float:
	var min_pos = Vector3(INF, INF, INF)
	var max_pos = Vector3(-INF, -INF, -INF)
	var has_objects = false
	
	# Check all tetris solids
	for solid in tetris_solids:
		if solid and is_instance_valid(solid):
			var pos = solid.global_position
			min_pos = min_pos.min(pos)
			max_pos = max_pos.max(pos)
			has_objects = true
	
	# Check polygon solid
	if polygon_solid and is_instance_valid(polygon_solid):
		var pos = polygon_solid.global_position
		min_pos = min_pos.min(pos)
		max_pos = max_pos.max(pos)
		has_objects = true
	
	if has_objects:
		# Return the maximum dimension of the bounding box
		var size = max_pos - min_pos
		return max(size.x, max(size.y, size.z))
	else:
		return 0.0

func _input(event):
	# Global keyboard shortcuts
	if event is InputEventKey and event.pressed:
		if event.keycode == KEY_F3:  # F3 to toggle between 2D/3D view
			if viewport_tabs:
				var current_tab = viewport_tabs.get_active_tab()
				var next_tab = "3D" if current_tab == "2D" else "2D"
				viewport_tabs.set_active_tab(next_tab)
			return
		elif event.keycode == KEY_R and _is_3d_mode():  # R to reset 3D camera
			_reset_3d_camera()
			return
		elif event.keycode == KEY_1:  # 1 for 2D view
			if viewport_tabs:
				viewport_tabs.set_active_tab("2D")
			return
		elif event.keycode == KEY_2:  # 2 for 3D view
			if viewport_tabs:
				viewport_tabs.set_active_tab("3D")
			return
	
	# Handle input based on current viewport tab
	var current_tab = viewport_tabs.get_active_tab() if viewport_tabs else "2D"
	if current_tab == "3D":
		_handle_3d_camera_input(event)
	else:
		_handle_camera_input(event)

func _handle_3d_camera_input(event):
	# Skip input if over PropertyPanel (fixed UI)
	if _is_mouse_over_property_panel(event):
		return
	
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			# Zoom to mouse position
			_zoom_3d_to_mouse(event.position, 0.9)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			# Zoom to mouse position
			_zoom_3d_to_mouse(event.position, 1.1)
		elif event.button_index == MOUSE_BUTTON_MIDDLE:
			if event.pressed:
				# Middle mouse = Pan
				is_3d_panning = true
				pan_start = event.position
				Input.set_default_cursor_shape(Input.CURSOR_DRAG)
			else:
				is_3d_panning = false
				Input.set_default_cursor_shape(Input.CURSOR_ARROW)
		elif event.button_index == MOUSE_BUTTON_RIGHT:
			if event.pressed:
				# Right mouse = Rotate
				is_3d_rotating = true
				rotate_start = event.position
				Input.set_default_cursor_shape(Input.CURSOR_MOVE)
			else:
				is_3d_rotating = false
				Input.set_default_cursor_shape(Input.CURSOR_ARROW)
	
	elif event is InputEventMouseMotion:
		if is_3d_rotating:
			# Orbital rotation around target
			var delta = event.position - rotate_start
			var sensitivity = 0.3
			camera_angle_h += delta.x * sensitivity
			camera_angle_v += delta.y * sensitivity
			camera_angle_v = clamp(camera_angle_v, -90, 90)
			rotate_start = event.position
			_update_3d_camera_position()
		elif is_3d_panning:
			# Pan the camera target
			var delta = event.position - pan_start
			_pan_3d_camera(delta)
			pan_start = event.position

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
	# Setup the UI container to span the top of the screen
	ui_control.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	ui_control.position = Vector2(0, 0)
	
	# Create background panel for the toolbar
	var background_panel = Panel.new()
	background_panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	
	# Set panel style to dark theme
	var style_box = StyleBoxFlat.new()
	style_box.bg_color = Color(0.1, 0.1, 0.12, 0.9)  # Culoare închisă cu transparență
	style_box.corner_radius_bottom_right = 8
	style_box.corner_radius_bottom_left = 8
	background_panel.add_theme_stylebox_override("panel", style_box)
	
	ui_control.add_child(background_panel)
	
	# Create main horizontal layout
	var main_hbox = HBoxContainer.new()
	main_hbox.add_theme_constant_override("separation", 15)  # Spațiere între secțiuni
	main_hbox.position = Vector2(10, 5)  # Margine interioară
	main_hbox.custom_minimum_size = Vector2(0, 50)  # Înălțime fixă pentru toolbar
	ui_control.add_child(main_hbox)
	
	# Title
	var title = Label.new()
	title.text = "Abstract House Maker"
	title.add_theme_font_size_override("font_size", 18)
	main_hbox.add_child(title)
	
	main_hbox.add_child(VSeparator.new())
	
	# Tetris Shapes Section
	var shapes_section = VBoxContainer.new()
	shapes_section.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	main_hbox.add_child(shapes_section)
	
	var shapes_label = Label.new()
	shapes_label.text = "Shapes"
	shapes_label.add_theme_font_size_override("font_size", 12)
	shapes_section.add_child(shapes_label)
	
	var shapes_hbox = HBoxContainer.new()
	shapes_section.add_child(shapes_hbox)
	
	var btn_rectangle = Button.new()
	btn_rectangle.text = "□"
	btn_rectangle.custom_minimum_size = Vector2(30, 30)
	btn_rectangle.pressed.connect(_on_add_rectangle)
	shapes_hbox.add_child(btn_rectangle)
	
	var btn_l_shape = Button.new()
	btn_l_shape.text = "L"
	btn_l_shape.custom_minimum_size = Vector2(30, 30)
	btn_l_shape.pressed.connect(_on_add_l_shape)
	shapes_hbox.add_child(btn_l_shape)
	
	var btn_t_shape = Button.new()
	btn_t_shape.text = "T"
	btn_t_shape.custom_minimum_size = Vector2(30, 30)
	btn_t_shape.pressed.connect(_on_add_t_shape)
	shapes_hbox.add_child(btn_t_shape)
	
	main_hbox.add_child(VSeparator.new())
	
	# Tools Section
	var tools_section = VBoxContainer.new()
	tools_section.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	main_hbox.add_child(tools_section)
	
	var tools_label = Label.new()
	tools_label.text = "Tools"
	tools_label.add_theme_font_size_override("font_size", 12)
	tools_section.add_child(tools_label)
	
	var tools_hbox = HBoxContainer.new()
	tools_section.add_child(tools_hbox)
	
	var btn_draw_polygon = Button.new()
	btn_draw_polygon.text = "✏️"
	btn_draw_polygon.tooltip_text = "Draw Polygon"
	btn_draw_polygon.custom_minimum_size = Vector2(30, 30)
	btn_draw_polygon.toggle_mode = true
	btn_draw_polygon.toggled.connect(_on_draw_polygon_toggled)
	tools_hbox.add_child(btn_draw_polygon)
	
	var btn_move_mode = Button.new()
	btn_move_mode.text = "↔️"
	btn_move_mode.tooltip_text = "Move Shapes"
	btn_move_mode.custom_minimum_size = Vector2(30, 30)
	btn_move_mode.toggle_mode = true
	btn_move_mode.toggled.connect(_on_move_mode_toggled)
	tools_hbox.add_child(btn_move_mode)
	
	var btn_clear_polygon = Button.new()
	btn_clear_polygon.text = "🗑️"
	btn_clear_polygon.tooltip_text = "Clear Polygon"
	btn_clear_polygon.custom_minimum_size = Vector2(30, 30)
	btn_clear_polygon.pressed.connect(_on_clear_polygon)
	tools_hbox.add_child(btn_clear_polygon)
	
	main_hbox.add_child(VSeparator.new())
	
	# Height Controls
	var height_section = VBoxContainer.new()
	height_section.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	main_hbox.add_child(height_section)
	
	var height_label = Label.new()
	height_label.text = "Height"
	height_label.add_theme_font_size_override("font_size", 12)
	height_section.add_child(height_label)
	
	var height_hbox = HBoxContainer.new()
	height_section.add_child(height_hbox)
	
	var btn_increase_height = Button.new()
	btn_increase_height.text = "⬆️"
	btn_increase_height.tooltip_text = "Increase Height"
	btn_increase_height.custom_minimum_size = Vector2(30, 30)
	btn_increase_height.pressed.connect(func(): polygon_drawer.extrusion_height += 0.5)
	height_hbox.add_child(btn_increase_height)
	
	var btn_decrease_height = Button.new()
	btn_decrease_height.text = "⬇️"
	btn_decrease_height.tooltip_text = "Decrease Height"
	btn_decrease_height.custom_minimum_size = Vector2(30, 30)
	btn_decrease_height.pressed.connect(func(): polygon_drawer.extrusion_height = max(0.5, polygon_drawer.extrusion_height - 0.5))
	height_hbox.add_child(btn_decrease_height)
	
	main_hbox.add_child(VSeparator.new())
	
	# Building Section
	var building_section = VBoxContainer.new()
	building_section.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	main_hbox.add_child(building_section)
	
	var building_label = Label.new()
	building_label.text = "Building"
	building_label.add_theme_font_size_override("font_size", 12)
	building_section.add_child(building_label)
	
	var building_hbox = HBoxContainer.new()
	building_section.add_child(building_hbox)
	
	var btn_add_windows = Button.new()
	btn_add_windows.text = "🪟"
	btn_add_windows.tooltip_text = "Add Windows"
	btn_add_windows.custom_minimum_size = Vector2(30, 30)
	btn_add_windows.pressed.connect(_on_add_windows_to_selected_wall)
	building_hbox.add_child(btn_add_windows)
	
	var btn_add_door = Button.new()
	btn_add_door.text = "🚪"
	btn_add_door.tooltip_text = "Add Door"
	btn_add_door.custom_minimum_size = Vector2(30, 30)
	btn_add_door.pressed.connect(_on_add_door_to_selected_wall)
	building_hbox.add_child(btn_add_door)
	
	var btn_generate_building = Button.new()
	btn_generate_building.text = "🏠"
	btn_generate_building.tooltip_text = "Generate Building"
	btn_generate_building.custom_minimum_size = Vector2(30, 30)
	btn_generate_building.pressed.connect(_on_generate_building)
	building_hbox.add_child(btn_generate_building)
	
	var btn_clear_3d = Button.new()
	btn_clear_3d.text = "🧹"
	btn_clear_3d.tooltip_text = "Clear 3D"
	btn_clear_3d.custom_minimum_size = Vector2(30, 30)
	btn_clear_3d.pressed.connect(_on_clear_3d)
	building_hbox.add_child(btn_clear_3d)
	
	main_hbox.add_child(VSeparator.new())
	
	# Advanced Section
	var advanced_section = VBoxContainer.new()
	advanced_section.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	main_hbox.add_child(advanced_section)
	
	var advanced_label = Label.new()
	advanced_label.text = "Advanced"
	advanced_label.add_theme_font_size_override("font_size", 12)
	advanced_section.add_child(advanced_label)
	
	var advanced_hbox = HBoxContainer.new()
	advanced_section.add_child(advanced_hbox)
	
	var btn_create_tetris = Button.new()
	btn_create_tetris.text = "🧩"
	btn_create_tetris.tooltip_text = "Create Tetris Solids"
	btn_create_tetris.custom_minimum_size = Vector2(30, 30)
	btn_create_tetris.pressed.connect(_on_create_tetris_solids)
	advanced_hbox.add_child(btn_create_tetris)
	
	var btn_apply_cut = Button.new()
	btn_apply_cut.text = "✂️"
	btn_apply_cut.tooltip_text = "Cut with Rooms"
	btn_apply_cut.custom_minimum_size = Vector2(30, 30)
	btn_apply_cut.pressed.connect(_on_apply_csg_cut)
	advanced_hbox.add_child(btn_apply_cut)
	
	var btn_test_csg = Button.new()
	btn_test_csg.text = "🔍"
	btn_test_csg.tooltip_text = "Test CSG Result"
	btn_test_csg.custom_minimum_size = Vector2(30, 30)
	btn_test_csg.pressed.connect(_on_test_csg_result)
	advanced_hbox.add_child(btn_test_csg)
	
	var btn_build_complete = Button.new()
	btn_build_complete.text = "🏗️"
	btn_build_complete.tooltip_text = "Build Complete Structure"
	btn_build_complete.custom_minimum_size = Vector2(30, 30)
	btn_build_complete.pressed.connect(_on_build_complete_structure)
	advanced_hbox.add_child(btn_build_complete)
	
	main_hbox.add_child(VSeparator.new())
	
	# Analysis Section
	var analysis_section = VBoxContainer.new()
	analysis_section.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	main_hbox.add_child(analysis_section)
	
	var analysis_label = Label.new()
	analysis_label.text = "Analysis"
	analysis_label.add_theme_font_size_override("font_size", 12)
	analysis_section.add_child(analysis_label)
	
	var analysis_hbox = HBoxContainer.new()
	analysis_section.add_child(analysis_hbox)
	
	var btn_validate_all = Button.new()
	btn_validate_all.text = "✅"
	btn_validate_all.tooltip_text = "Validate All Shapes"
	btn_validate_all.custom_minimum_size = Vector2(30, 30)
	btn_validate_all.pressed.connect(_on_validate_all_shapes)
	analysis_hbox.add_child(btn_validate_all)
	
	var btn_show_statistics = Button.new()
	btn_show_statistics.text = "📊"
	btn_show_statistics.tooltip_text = "Show Statistics"
	btn_show_statistics.custom_minimum_size = Vector2(30, 30)
	btn_show_statistics.pressed.connect(_on_show_statistics)
	analysis_hbox.add_child(btn_show_statistics)
	
	# Utility Buttons
	main_hbox.add_child(VSeparator.new())
	
	var utils_section = VBoxContainer.new()
	utils_section.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	main_hbox.add_child(utils_section)
	
	var utils_label = Label.new()
	utils_label.text = "Utilities"
	utils_label.add_theme_font_size_override("font_size", 12)
	utils_section.add_child(utils_label)
	
	var utils_hbox = HBoxContainer.new()
	utils_section.add_child(utils_hbox)
	
	var btn_export_shapes = Button.new()
	btn_export_shapes.text = "💾"
	btn_export_shapes.tooltip_text = "Export Shapes"
	btn_export_shapes.custom_minimum_size = Vector2(30, 30)
	btn_export_shapes.pressed.connect(_on_export_shapes)
	utils_hbox.add_child(btn_export_shapes)
	
	var btn_clear_all = Button.new()
	btn_clear_all.text = "🧨"
	btn_clear_all.tooltip_text = "Clear All"
	btn_clear_all.custom_minimum_size = Vector2(30, 30)
	btn_clear_all.pressed.connect(_on_clear_all)
	utils_hbox.add_child(btn_clear_all)
	
	var btn_reset_view = Button.new()
	btn_reset_view.text = "🔄"
	btn_reset_view.tooltip_text = "Reset View"
	btn_reset_view.custom_minimum_size = Vector2(30, 30)
	btn_reset_view.pressed.connect(_on_reset_view)
	utils_hbox.add_child(btn_reset_view)
	
	# Floating space-filler to push viewport tabs to the right
	var spacer = Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	main_hbox.add_child(spacer)
	
	# Add viewport tabs container - pushed to the right side of the toolbar
	var tabs_container = HBoxContainer.new()
	tabs_container.size_flags_horizontal = Control.SIZE_SHRINK_END
	main_hbox.add_child(tabs_container)
	
	var tabs_label = Label.new()
	tabs_label.text = "View:"
	tabs_label.add_theme_font_size_override("font_size", 12)
	tabs_container.add_child(tabs_label)
	
	var btn_2d_view = Button.new()
	btn_2d_view.text = "2D"
	btn_2d_view.custom_minimum_size = Vector2(40, 30)
	btn_2d_view.pressed.connect(func(): viewport_tabs.set_active_tab("2D"))
	tabs_container.add_child(btn_2d_view)
	
	var btn_3d_view = Button.new()
	btn_3d_view.text = "3D"
	btn_3d_view.custom_minimum_size = Vector2(40, 30)
	btn_3d_view.pressed.connect(func(): viewport_tabs.set_active_tab("3D"))
	tabs_container.add_child(btn_3d_view)
	
	# Adjust UI control height to fit the toolbar
	ui_control.custom_minimum_size.y = 60
	
	# Move property panel below the toolbar
	call_deferred("_adjust_property_panel_position")

# Helper function to adjust property panel position below the toolbar
func _adjust_property_panel_position():
	if property_panel:
		var toolbar_height = ui_control.custom_minimum_size.y
		property_panel.position.y += toolbar_height

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
	"""Legacy function - now uses viewport tabs system"""
	if viewport_tabs:
		viewport_tabs.set_active_tab("3D" if pressed else "2D")
	else:
		# Fallback to direct mode switching
		is_3d_view_mode = pressed
		if pressed:
			_switch_to_3d_view()
		else:
			_switch_to_2d_view()

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
	if _is_3d_mode():
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

# Window and Door functions
func _on_add_windows_to_selected_wall():
	"""Add windows to the selected wall/shape"""
	if selected_shape:
		selected_shape.has_window = true
		selected_shape.window_width = 1.0
		selected_shape.window_height = 1.0
		selected_shape.window_sill = 0.8
		selected_shape.shape_changed.emit()
		
		# Update property panel if open
		if property_panel and property_panel.current_shape == selected_shape:
			property_panel.refresh_properties()
		
		print("✓ Added window to shape: ", selected_shape.unique_id)
	else:
		print("⚠️ No shape selected for adding window")

func _on_add_door_to_selected_wall():
	"""Add door to the selected wall/shape"""
	if selected_shape:
		selected_shape.has_door = true
		selected_shape.door_width = 0.9
		selected_shape.door_height = 2.0
		selected_shape.door_sill = 0.0
		selected_shape.shape_changed.emit()
		
		# Update property panel if open
		if property_panel and property_panel.current_shape == selected_shape:
			property_panel.refresh_properties()
		
		print("✓ Added door to shape: ", selected_shape.unique_id)
	else:
		print("⚠️ No shape selected for adding door")
		
func _on_generate_building():
	"""
	Execută întregul workflow de generare a clădirii într-o singură operație:
	1. Generează formele camerelor (tetris solids)
	2. Generează solidul din polilinie (shell-ul clădirii)
	3. Execută operațiunile booleene pentru ferestre și uși
	4. Afișează rezultatul final în scena 3D
	"""
	print("🏗️ Executare workflow complet de generare a clădirii...")
	
	# Pasul 1: Curățăm obiectele 3D existente
	_on_clear_3d()
	
	# Pasul 2: Generăm formele camerelor (tetris solids)
	print("Pasul 1: Generarea formelor camerelor...")
	_on_create_tetris_solids()
	if tetris_solids.size() == 0:
		print("⚠️ Nu s-au putut genera forme Tetris! Verificați shape-urile 2D.")
		return
	print("✅ Generate ", tetris_solids.size(), " forme de camere")
	
	# Pasul 3: Generăm solidul din polilinie (shell-ul clădirii)
	print("Pasul 2: Generarea shell-ului clădirii din polilinie...")
	_on_create_polygon_solid()
	if not polygon_solid:
		print("⚠️ Nu s-a putut genera shell-ul clădirii! Verificați poligonul exterior.")
		return
	print("✅ Generat shell-ul clădirii")
	
	# Pasul 4: Colectăm toate shape-urile și aplicăm operațiile booleene
	print("Pasul 3: Aplicarea operațiilor booleene pentru ferestre și uși...")
	var tetris_shapes = _get_all_tetris_shapes()
	if tetris_shapes.size() == 0:
		print("⚠️ Nu s-au găsit shape-uri pentru operațiile booleene!")
		return
	
	# Pregătim datele pentru operațiile booleene
	var outer_vertices = polygon_drawer.get_offset_polygon()
	var outer_height = polygon_drawer.extrusion_height
	
	# Sincronizăm proprietățile din PropertyPanel/ShapeManager
	_sync_shape_properties_from_manager(tetris_shapes)
	
	# Executăm operațiile booleene și creăm clădirea finală
	var complete_building = solid_factory.create_complete_building_with_windows_doors(
		outer_vertices, 
		outer_height, 
		tetris_shapes
	)
	
	# Adăugăm rezultatul la scenă
	if complete_building:
		solid_container.add_child(complete_building)
		complete_building.position = Vector3.ZERO
		
		# Ascundem shape-urile originale pentru claritate
		if polygon_solid:
			polygon_solid.visible = false
		for tetris_solid in tetris_solids:
			tetris_solid.visible = false
		
		print("✅ Clădire completă generată cu succes!")
	else:
		print("❌ Eroare la generarea clădirii complete")
	
	# Pasul 5: Comutăm la vizualizarea 3D pentru a vedea rezultatul
	if not _is_3d_mode():
		_switch_to_3d_view()
	
	print("🎉 Workflow de generare complet finalizat!")
	
func _on_clear_3d():
	"""Clear all 3D objects"""
	print("🧹 Clearing 3D view...")
	
	# Clear all children from solid container
	for child in solid_container.get_children():
		child.queue_free()
	
	# Clear all children from polygon container
	for child in polygon_container.get_children():
		child.queue_free()
	
	# Reset arrays
	tetris_solids.clear()
	polygon_solid = null
	
	print("✓ 3D view cleared")

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

# ========================================
# 3D NAVIGATION GIZMO & PRESET VIEWS
# ========================================

func _create_navigation_gizmo():
	"""
	Creează gizmo-ul de navigare 3D cu preset views
	"""
	if navigation_gizmo:
		_remove_navigation_gizmo()
	
	# Create camera controls container - OPAQUE BLACK OVERLAY
	navigation_gizmo = Control.new()
	navigation_gizmo.name = "CameraControls"
	navigation_gizmo.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	navigation_gizmo.size = Vector2(320, 180)  # Match PropertyPanel width
	navigation_gizmo.position = Vector2(-330, 620)  # Below PropertyPanel (10px gap)
	navigation_gizmo.mouse_filter = Control.MOUSE_FILTER_STOP
	navigation_gizmo.z_index = 100  # High z-index for overlay
	
	# OPAQUE BLACK background panel
	var panel = Panel.new()
	panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	
	# Create opaque black style
	var panel_style = StyleBoxFlat.new()
	panel_style.bg_color = Color(0.0, 0.0, 0.0, 1.0)  # Pure black, fully opaque
	panel_style.set_border_width_all(2)
	panel_style.border_color = Color(0.2, 0.2, 0.2, 1.0)  # Dark gray border
	panel_style.set_corner_radius_all(8)
	panel_style.shadow_color = Color(0.0, 0.0, 0.0, 0.5)  # Black shadow
	panel_style.shadow_size = 10
	panel_style.shadow_offset = Vector2(2, 2)
	panel.add_theme_stylebox_override("panel", panel_style)
	navigation_gizmo.add_child(panel)
	
	# Main VBox layout
	var main_vbox = VBoxContainer.new()
	main_vbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT, Control.PRESET_MODE_MINSIZE, 10)
	navigation_gizmo.add_child(main_vbox)
	
	# Configure black theme for all controls
	_setup_camera_controls_black_theme(navigation_gizmo)
	
	# Title
	var title = Label.new()
	title.text = "🎬 3D Camera Controls"
	title.add_theme_font_size_override("font_size", 14)
	title.add_theme_color_override("font_color", Color.WHITE)  # White text
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	main_vbox.add_child(title)
	
	# Separator
	var separator = HSeparator.new()
	var separator_style = StyleBoxFlat.new()
	separator_style.bg_color = Color(0.3, 0.3, 0.3, 1.0)  # Gray line
	separator.add_theme_stylebox_override("separator", separator_style)
	main_vbox.add_child(separator)
	
	# Preset Views section
	var views_label = Label.new()
	views_label.text = "📐 Preset Views:"
	views_label.add_theme_font_size_override("font_size", 12)
	views_label.add_theme_color_override("font_color", Color.WHITE)  # White text
	main_vbox.add_child(views_label)
	
	# Create preset view buttons in a grid
	var grid_container = GridContainer.new()
	grid_container.columns = 4
	grid_container.add_theme_constant_override("h_separation", 5)
	grid_container.add_theme_constant_override("v_separation", 5)
	main_vbox.add_child(grid_container)
	
	var button_size = Vector2(70, 25)
	var button_positions = [
		{"name": "Top", "angles": Vector2(0, -90)},
		{"name": "Front", "angles": Vector2(0, 0)},
		{"name": "Right", "angles": Vector2(90, 0)},
		{"name": "Back", "angles": Vector2(180, 0)},
		{"name": "Left", "angles": Vector2(-90, 0)},
		{"name": "Bottom", "angles": Vector2(0, 90)},
		{"name": "ISO", "angles": Vector2(45, -30)},
		{"name": "Reset", "angles": Vector2(0, -20)}
	]
	
	for preset in button_positions:
		var btn = Button.new()
		btn.text = preset.name
		btn.custom_minimum_size = button_size
		btn.add_theme_font_size_override("font_size", 10)
		btn.add_theme_color_override("font_color", Color.WHITE)  # White text
		
		# Black button theme
		var btn_normal = StyleBoxFlat.new()
		btn_normal.bg_color = Color(0.2, 0.2, 0.2, 1.0)
		btn_normal.border_color = Color(0.4, 0.4, 0.4, 1.0)
		btn_normal.set_border_width_all(1)
		btn_normal.set_corner_radius_all(4)
		btn.add_theme_stylebox_override("normal", btn_normal)
		
		var btn_hover = StyleBoxFlat.new()
		btn_hover.bg_color = Color(0.3, 0.3, 0.3, 1.0)
		btn_hover.border_color = Color(0.5, 0.5, 0.5, 1.0)
		btn_hover.set_border_width_all(1)
		btn_hover.set_corner_radius_all(4)
		btn.add_theme_stylebox_override("hover", btn_hover)
		
		var btn_pressed = StyleBoxFlat.new()
		btn_pressed.bg_color = Color(0.1, 0.4, 0.6, 1.0)  # Blue when pressed
		btn_pressed.border_color = Color(0.2, 0.5, 0.7, 1.0)
		btn_pressed.set_border_width_all(1)
		btn_pressed.set_corner_radius_all(4)
		btn.add_theme_stylebox_override("pressed", btn_pressed)
		
		btn.pressed.connect(_on_preset_view_selected.bind(preset.name, preset.angles))
		grid_container.add_child(btn)
	
	# Separator
	var separator2 = HSeparator.new()
	var separator2_style = StyleBoxFlat.new()
	separator2_style.bg_color = Color(0.3, 0.3, 0.3, 1.0)  # Gray line
	separator2.add_theme_stylebox_override("separator", separator2_style)
	main_vbox.add_child(separator2)
	
	# Controls instructions
	var controls_label = Label.new()
	controls_label.text = "🎮 Controls:"
	controls_label.add_theme_font_size_override("font_size", 12)
	controls_label.add_theme_color_override("font_color", Color.WHITE)  # White text
	main_vbox.add_child(controls_label)
	
	var instructions = RichTextLabel.new()
	instructions.fit_content = true
	instructions.custom_minimum_size.y = 60
	instructions.bbcode_enabled = true
	instructions.add_theme_color_override("default_color", Color.WHITE)  # White text
	instructions.add_theme_color_override("font_color", Color.WHITE)
	
	# Black background for instructions
	var instructions_style = StyleBoxFlat.new()
	instructions_style.bg_color = Color(0.05, 0.05, 0.05, 1.0)  # Very dark background
	instructions_style.set_corner_radius_all(4)
	instructions.add_theme_stylebox_override("normal", instructions_style)
	
	instructions.text = "[font_size=10][color=white]• [b]Right Click + Drag[/b]: Rotate
• [b]Middle Click + Drag[/b]: Pan
• [b]Mouse Wheel[/b]: Zoom to cursor
• [b]F3[/b]: Toggle 2D/3D
• [b]R[/b]: Reset camera[/color][/font_size]"
	main_vbox.add_child(instructions)
	
	# Add camera controls to scene
	add_child(navigation_gizmo)
	print("🎬 3D Camera controls created in top-right corner")

func _remove_navigation_gizmo():
	"""
	Elimină controalele camerei 3D
	"""
	if navigation_gizmo:
		navigation_gizmo.queue_free()
		navigation_gizmo = null
		print("🎬 3D Camera controls removed")

func _on_preset_view_selected(view_name: String, angles: Vector2):
	"""
	Handler pentru preset views
	"""
	print("🎯 Setting camera to ", view_name, " view")
	
	if view_name == "Reset":
		_reset_3d_camera()
		return
	
	# Set camera angles
	camera_angle_h = angles.x
	camera_angle_v = angles.y
	
	# Special handling for top/bottom views
	if view_name == "Top":
		camera_angle_v = -89.0  # Almost straight down
	elif view_name == "Bottom":
		camera_angle_v = 89.0   # Almost straight up
	
	# Update camera position
	_update_3d_camera_position()
	
	# Animate transition (optional)
	var tween = get_tree().create_tween()
	tween.set_ease(Tween.EASE_OUT)
	tween.set_trans(Tween.TRANS_CUBIC)
	
	print("📷 Camera set to ", view_name, " view (", angles, ")")

# Viewport tabs management
func _on_viewport_tab_changed(tab_name: String):
	"""Handle viewport tab switching"""
	print("🔄 Switching to viewport: ", tab_name)
	
	if tab_name == "2D":
		_switch_to_2d_view()
	elif tab_name == "3D":
		_switch_to_3d_view()
	
	# Save current tab preference
	viewport_tabs.save_tab_settings()

func _on_viewport_tab_moved(tab_name: String, new_position: Vector2):
	"""Handle viewport tab being moved"""
	print("📋 Tab '", tab_name, "' moved to: ", new_position)
	viewport_tabs.save_tab_settings()

func _switch_to_2d_view():
	"""Switch to 2D design view"""
	is_3d_view_mode = false
	
	# Show 2D canvas elements
	if canvas_layer:
		canvas_layer.visible = true
		# Restore full opacity to 2D elements
		for child in canvas_layer.get_children():
			if "modulate" in child:
				child.modulate.a = 1.0
	if shape_layer:
		shape_layer.visible = true
		if "modulate" in shape_layer:
			shape_layer.modulate.a = 1.0  # Restore full opacity
	if polygon_drawer:
		polygon_drawer.visible = true
	
	# Hide 3D elements
	if solid_container:
		solid_container.visible = false
	if camera_3d:
		camera_3d.current = false
	if navigation_gizmo:
		navigation_gizmo.visible = false
	
	print("📐 Switched to 2D Design view")

func _switch_to_3d_view():
	"""Switch to 3D visualization view"""
	is_3d_view_mode = true
	
	# Hide 2D canvas elements (but keep some for reference)
	if canvas_layer:
		# Make 2D elements semi-transparent by modulating their children
		for child in canvas_layer.get_children():
			if "modulate" in child:
				child.modulate.a = 0.3
	if shape_layer and "modulate" in shape_layer:
		shape_layer.modulate.a = 0.3
	
	# Show 3D elements
	if solid_container:
		solid_container.visible = true
	if camera_3d:
		camera_3d.current = true
	if navigation_gizmo:
		navigation_gizmo.visible = true
	
	# Update 3D view - regenerate building if shapes exist
	_update_3d_building_display()
	
	print("🏠 Switched to 3D Visualization view")

func _load_viewport_settings():
	"""Load viewport tab settings"""
	if viewport_tabs:
		viewport_tabs.load_tab_settings()

func _is_3d_mode() -> bool:
	"""Check if currently in 3D mode"""
	if viewport_tabs:
		return viewport_tabs.get_active_tab() == "3D"
	return is_3d_view_mode  # Fallback to old variable

func _initialize_viewport_mode():
	"""Initialize viewport mode based on active tab"""
	if viewport_tabs:
		var active_tab = viewport_tabs.get_active_tab()
		_on_viewport_tab_changed(active_tab)

func _update_3d_building_display():
	"""Update 3D building display when switching to 3D view"""
	# Check if we have shapes to display
	var tetris_shapes = _get_all_tetris_shapes()
	var outer_vertices = []
	
	if polygon_drawer:
		outer_vertices = polygon_drawer.get_offset_polygon()
	
	# Only regenerate if we have valid data
	if tetris_shapes.size() > 0 and outer_vertices.size() >= 3:
		print("🔄 Updating 3D building display...")
		_on_apply_csg_cut()  # Use existing building generation logic
	else:
		print("📐 No valid shapes to display in 3D mode")

# Setup black theme for camera controls
func _setup_camera_controls_black_theme(control_node: Control):
	# Main container black background
	var panel_style = StyleBoxFlat.new()
	panel_style.bg_color = Color(0.0, 0.0, 0.0, 0.9)  # Semi-transparent black
	panel_style.set_corner_radius_all(8)
	panel_style.shadow_color = Color(0.0, 0.0, 0.0, 0.5)
	panel_style.shadow_offset = Vector2(2, 2)
	panel_style.shadow_size = 4
	panel_style.set_border_width_all(1)
	panel_style.border_color = Color(0.3, 0.3, 0.3, 1.0)
	
	control_node.add_theme_stylebox_override("panel", panel_style)
