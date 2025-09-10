extends Control
class_name PropertyPanel

# Panou pentru proprietățile formelor TetrisShape2D
signal property_changed(property_name: String, value)
signal panel_closed
signal shape_color_change_requested(shape: TetrisShape2D)
signal shape_delete_requested(shape: TetrisShape2D)
signal rebuild_building_requested

var current_shape: TetrisShape2D = null
var is_updating_ui: bool = false

# Dragging system variables
var is_dragging: bool = false
var drag_start_position: Vector2
var drag_offset: Vector2
var drag_header: Control

# Panel state
var is_minimized: bool = false
var normal_size: Vector2 = Vector2(320, 600)
var minimized_size: Vector2 = Vector2(320, 35)

# Referințe către controalele UI
var ui_room_name: LineEdit
var ui_central_color: ColorPickerButton
var ui_width: SpinBox
var ui_height: SpinBox
var ui_extrusion_height: SpinBox
var ui_interior_offset: SpinBox

# Controale pentru ferestre
var ui_has_window: CheckBox
var ui_window_style: OptionButton
var ui_window_side: OptionButton
var ui_window_offset: SpinBox
var ui_window_n_offset: SpinBox
var ui_window_z_offset: SpinBox
var ui_window_width: SpinBox
var ui_window_length: SpinBox
var ui_window_height: SpinBox
var ui_window_sill: SpinBox

# Controale pentru uși
var ui_has_door: CheckBox
var ui_door_style: OptionButton
var ui_door_side: OptionButton
var ui_door_offset: SpinBox
var ui_door_n_offset: SpinBox
var ui_door_z_offset: SpinBox
var ui_door_width: SpinBox
var ui_door_length: SpinBox
var ui_door_height: SpinBox
var ui_door_sill: SpinBox

# Afișaj geometrie
var geometry_display: RichTextLabel
var validation_display: RichTextLabel

func _ready():
	_setup_panel_style()
	_setup_black_theme()
	_create_ui()
	_load_panel_settings()

func _load_panel_settings():
	# Load saved position if available
	if FileAccess.file_exists("user://property_panel_settings.json"):
		var file = FileAccess.open("user://property_panel_settings.json", FileAccess.READ)
		if file:
			var json = JSON.new()
			var parse_result = json.parse(file.get_as_text())
			file.close()
			
			if parse_result == OK:
				var settings = json.data
				if settings.has("position"):
					position = Vector2(settings.position.x, settings.position.y)
				if settings.has("is_minimized"):
					# Apply minimized state after UI is created
					call_deferred("_apply_minimized_state", settings.is_minimized)
				print("🔄 Property panel settings loaded")

func _save_panel_settings():
	var settings = {
		"position": {"x": position.x, "y": position.y},
		"is_minimized": is_minimized
	}
	
	var file = FileAccess.open("user://property_panel_settings.json", FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(settings))
		file.close()
		print("💾 Property panel settings saved")

func _setup_panel_style():
	# Setup panel appearance - DRAGGABLE OPAQUE BLACK OVERLAY
	size = Vector2(320, 600)  # Fixed size
	# Position will be set after viewport is ready or loaded from settings
	call_deferred("_set_initial_position")
	custom_minimum_size = Vector2(320, 600)
	set_h_size_flags(Control.SIZE_SHRINK_CENTER)  # Don't expand horizontally
	set_v_size_flags(Control.SIZE_SHRINK_CENTER)  # Don't expand vertically
	mouse_filter = Control.MOUSE_FILTER_STOP  # Accept mouse events for dragging
	visible = false
	z_index = 100  # High z-index for overlay
	
	# Enable dragging
	_setup_dragging_system()

func _set_initial_position():
	# Set default position at top-right if no saved position
	if position == Vector2.ZERO:
		var viewport_size = get_viewport().size
		position = Vector2(viewport_size.x - 330, 10)

func _setup_dragging_system():
	# The drag header will be created in _create_draggable_header()
	# This function sets up the main panel for input handling
	gui_input.connect(_on_panel_input)

func _on_panel_input(event: InputEvent):
	# Only handle dragging in header area (top 35 pixels)
	var local_mouse_pos = get_local_mouse_position()
	var is_in_header = local_mouse_pos.y >= 0 and local_mouse_pos.y <= 35
	
	if event is InputEventMouseButton:
		print("🖱️ Mouse event in panel - in header: ", is_in_header, " pos: ", local_mouse_pos)
		if is_in_header:
			var mouse_event = event as InputEventMouseButton
			if mouse_event.button_index == MOUSE_BUTTON_LEFT:
				if mouse_event.pressed:
					# Start dragging
					is_dragging = true
					drag_start_position = global_position
					drag_offset = get_global_mouse_position() - global_position
					print("🖱️ Started dragging property panel")
				else:
					# Stop dragging
					is_dragging = false
					_save_panel_settings()  # Save position when dragging stops
					print("🖱️ Stopped dragging property panel")
	
	elif event is InputEventMouseMotion and is_dragging:
		# Update position while dragging
		var new_position = get_global_mouse_position() - drag_offset
		
		# Constrain to viewport bounds
		var viewport_size = get_viewport().size
		new_position.x = clamp(new_position.x, 0, viewport_size.x - size.x)
		new_position.y = clamp(new_position.y, 0, viewport_size.y - size.y)
		
		global_position = new_position

func _create_draggable_header():
	# Visual header background
	var header_bg = Panel.new()
	header_bg.size = Vector2(320, 35)
	header_bg.position = Vector2(0, 0)
	header_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE  # Let events pass through
	
	# Header style - darker than main panel
	var header_style = StyleBoxFlat.new()
	header_style.bg_color = Color(0.1, 0.1, 0.1, 1.0)  # Darker gray
	header_style.set_border_width_all(1)
	header_style.border_color = Color(0.4, 0.4, 0.4, 1.0)
	header_style.set_corner_radius_all(8)
	header_bg.add_theme_stylebox_override("panel", header_style)
	add_child(header_bg)
	
	# Title in header
	var title = Label.new()
	title.text = "🏠 Shape Properties [Drag to move]"
	title.add_theme_font_size_override("font_size", 14)
	title.add_theme_color_override("font_color", Color.WHITE)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	title.position = Vector2(5, 0)
	title.size = Vector2(270, 35)  # Leave space for minimize button
	title.mouse_filter = Control.MOUSE_FILTER_IGNORE  # Let events pass through
	add_child(title)
	
	# Minimize/Maximize button
	var minimize_btn = Button.new()
	minimize_btn.text = "−"  # Minus sign
	minimize_btn.size = Vector2(30, 25)
	minimize_btn.position = Vector2(285, 5)
	minimize_btn.add_theme_font_size_override("font_size", 16)
	minimize_btn.add_theme_color_override("font_color", Color.WHITE)
	minimize_btn.pressed.connect(_on_minimize_pressed)
	minimize_btn.mouse_filter = Control.MOUSE_FILTER_STOP  # Button should capture clicks
	_apply_control_theme(minimize_btn)
	add_child(minimize_btn)

func _on_minimize_pressed():
	print("🔘 Minimize button pressed - current state: ", is_minimized)
	is_minimized = !is_minimized
	
	if is_minimized:
		# Minimize - show only header
		size = minimized_size
		# Hide scroll container
		for child in get_children():
			if child is ScrollContainer:
				child.visible = false
		print("📦 Property panel minimized")
	else:
		# Maximize - show full panel
		size = normal_size
		# Show scroll container
		for child in get_children():
			if child is ScrollContainer:
				child.visible = true
				# Adjust scroll container size to new panel size
				child.size = Vector2(320, size.y - 35)
		print("📋 Property panel maximized")
	
	# Update minimize button text - find it more specifically
	for child in get_children():
		if child is Button and child.position.x > 280:  # Minimize button is positioned at x=285
			child.text = "□" if is_minimized else "−"
			break
	
	# Save settings
	_save_panel_settings()

func _apply_minimized_state(should_minimize: bool):
	if should_minimize != is_minimized:
		_on_minimize_pressed()

	# OPAQUE BLACK background style
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.0, 0.0, 0.0, 1.0)  # Pure black, fully opaque
	style.set_border_width_all(2)
	style.border_color = Color(0.2, 0.2, 0.2, 1.0)  # Dark gray border
	style.set_corner_radius_all(8)
	style.shadow_color = Color(0.0, 0.0, 0.0, 0.5)  # Black shadow
	style.shadow_size = 10
	style.shadow_offset = Vector2(2, 2)
	add_theme_stylebox_override("panel", style)

func _setup_black_theme():
	"""
	Configurare temă pentru fundal negru - text alb și controale vizibile
	"""
	# Text color - white on black
	add_theme_color_override("font_color", Color.WHITE)
	
	# Labels
	add_theme_color_override("font_color", Color.WHITE)
	
	# LineEdit style
	var lineedit_style = StyleBoxFlat.new()
	lineedit_style.bg_color = Color(0.1, 0.1, 0.1, 1.0)  # Very dark gray
	lineedit_style.border_color = Color(0.3, 0.3, 0.3, 1.0)
	lineedit_style.set_border_width_all(1)
	lineedit_style.set_corner_radius_all(4)
	add_theme_stylebox_override("normal", lineedit_style)
	
	# Button style
	var button_style = StyleBoxFlat.new()
	button_style.bg_color = Color(0.2, 0.2, 0.2, 1.0)  # Dark gray
	button_style.border_color = Color(0.4, 0.4, 0.4, 1.0)
	button_style.set_border_width_all(1)
	button_style.set_corner_radius_all(4)
	add_theme_stylebox_override("normal", button_style)
	
	var button_hover_style = StyleBoxFlat.new()
	button_hover_style.bg_color = Color(0.3, 0.3, 0.3, 1.0)  # Lighter on hover
	button_hover_style.border_color = Color(0.5, 0.5, 0.5, 1.0)
	button_hover_style.set_border_width_all(1)
	button_hover_style.set_corner_radius_all(4)
	add_theme_stylebox_override("hover", button_hover_style)
	
	print("🎨 Black theme configured for PropertyPanel")

# Helper function to create foldable sections
func _create_foldable_section(parent: VBoxContainer, title_text: String, is_expanded: bool = true) -> VBoxContainer:
	var section_vbox = VBoxContainer.new()
	parent.add_child(section_vbox)
	
	# Header button for folding/unfolding
	var header_button = Button.new()
	header_button.text = ("▼ " if is_expanded else "▶ ") + title_text
	header_button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	header_button.add_theme_font_size_override("font_size", 14)
	header_button.add_theme_color_override("font_color", Color.WHITE)
	
	# Header button style
	var header_style = StyleBoxFlat.new()
	header_style.bg_color = Color(0.15, 0.15, 0.15, 1.0)  # Darker gray
	header_style.border_color = Color(0.4, 0.4, 0.4, 1.0)
	header_style.set_border_width_all(1)
	header_style.set_corner_radius_all(4)
	header_button.add_theme_stylebox_override("normal", header_style)
	
	var header_hover_style = StyleBoxFlat.new()
	header_hover_style.bg_color = Color(0.25, 0.25, 0.25, 1.0)  # Lighter on hover
	header_hover_style.border_color = Color(0.5, 0.5, 0.5, 1.0)
	header_hover_style.set_border_width_all(1)
	header_hover_style.set_corner_radius_all(4)
	header_button.add_theme_stylebox_override("hover", header_hover_style)
	
	section_vbox.add_child(header_button)
	
	# Content container
	var content_container = VBoxContainer.new()
	content_container.visible = is_expanded
	section_vbox.add_child(content_container)
	
	# Connect fold/unfold functionality
	header_button.pressed.connect(func():
		content_container.visible = !content_container.visible
		header_button.text = ("▼ " if content_container.visible else "▶ ") + title_text
	)
	
	return content_container

func _create_ui():
	# Create draggable header with title
	_create_draggable_header()
	
	# Main scroll container (below header)
	var scroll = ScrollContainer.new()
	scroll.position = Vector2(0, 35)  # Below header
	scroll.size = Vector2(320, 565)  # Remaining height (600 - 35)
	scroll.mouse_filter = Control.MOUSE_FILTER_PASS  # Allow scrolling
	add_child(scroll)
	
	var main_vbox = VBoxContainer.new()
	main_vbox.set_h_size_flags(Control.SIZE_EXPAND_FILL)
	scroll.add_child(main_vbox)
	
	var title_separator = HSeparator.new()
	_apply_separator_theme(title_separator)
	main_vbox.add_child(title_separator)
	
	# Basic properties (expanded by default)
	var basic_section = _create_foldable_section(main_vbox, "🏠 Basic Properties", true)
	_create_basic_properties(basic_section)
	
	# Window properties (collapsed by default)
	var window_section = _create_foldable_section(main_vbox, "🪟 Window Properties", false)
	_create_window_properties(window_section)
	
	# Door properties (collapsed by default)
	var door_section = _create_foldable_section(main_vbox, "🚪 Door Properties", false)
	_create_door_properties(door_section)
	
	# Geometry display (collapsed by default)
	var geometry_section = _create_foldable_section(main_vbox, "📐 Geometry Info", false)
	_create_geometry_display(geometry_section)
	
	# Validation display (expanded for important info)
	var validation_section = _create_foldable_section(main_vbox, "✓ Validation", true)
	_create_validation_display(validation_section)
	
	# CSG Priority control (collapsed - advanced)
	var csg_section = _create_foldable_section(main_vbox, "⚙️ Advanced CSG", false)
	_create_csg_priority_control(csg_section)
	
	# Action buttons (always visible)
	var actions_section = _create_foldable_section(main_vbox, "🔧 Actions", true)
	_create_action_buttons(actions_section)

# Helper to apply separator theme
func _apply_separator_theme(separator: HSeparator):
	var separator_style = StyleBoxFlat.new()
	separator_style.bg_color = Color(0.3, 0.3, 0.3, 1.0)  # Gray line
	separator.add_theme_stylebox_override("separator", separator_style)

# Apply black theme to individual controls
func _apply_control_theme(control: Control):
	# Apply white text color to all controls
	control.add_theme_color_override("font_color", Color.WHITE)
	
	if control is Label:
		control.add_theme_color_override("font_color", Color.WHITE)
	elif control is LineEdit:
		var lineedit_style = StyleBoxFlat.new()
		lineedit_style.bg_color = Color(0.1, 0.1, 0.1, 1.0)
		lineedit_style.border_color = Color(0.3, 0.3, 0.3, 1.0)
		lineedit_style.set_border_width_all(1)
		lineedit_style.set_corner_radius_all(4)
		control.add_theme_stylebox_override("normal", lineedit_style)
		control.add_theme_color_override("font_color", Color.WHITE)
	elif control is SpinBox:
		var spinbox_style = StyleBoxFlat.new()
		spinbox_style.bg_color = Color(0.15, 0.15, 0.15, 1.0)
		spinbox_style.border_color = Color(0.3, 0.3, 0.3, 1.0)
		spinbox_style.set_border_width_all(1)
		spinbox_style.set_corner_radius_all(4)
		control.add_theme_stylebox_override("normal", spinbox_style)
		control.add_theme_color_override("font_color", Color.WHITE)
	elif control is CheckBox:
		control.add_theme_color_override("font_color", Color.WHITE)
		var checkbox_style = StyleBoxFlat.new()
		checkbox_style.bg_color = Color(0.15, 0.15, 0.15, 1.0)
		checkbox_style.border_color = Color(0.4, 0.4, 0.4, 1.0)
		checkbox_style.set_border_width_all(1)
		checkbox_style.set_corner_radius_all(2)
		control.add_theme_stylebox_override("normal", checkbox_style)
	elif control is OptionButton:
		var option_style = StyleBoxFlat.new()
		option_style.bg_color = Color(0.15, 0.15, 0.15, 1.0)
		option_style.border_color = Color(0.3, 0.3, 0.3, 1.0)
		option_style.set_border_width_all(1)
		option_style.set_corner_radius_all(4)
		control.add_theme_stylebox_override("normal", option_style)
		control.add_theme_color_override("font_color", Color.WHITE)
	elif control is Button:
		var button_style = StyleBoxFlat.new()
		button_style.bg_color = Color(0.3, 0.3, 0.3, 1.0)
		button_style.border_color = Color(0.4, 0.4, 0.4, 1.0)
		button_style.set_border_width_all(1)
		button_style.set_corner_radius_all(4)
		control.add_theme_stylebox_override("normal", button_style)
		
		var button_hover_style = StyleBoxFlat.new()
		button_hover_style.bg_color = Color(0.4, 0.4, 0.4, 1.0)
		button_hover_style.border_color = Color(0.5, 0.5, 0.5, 1.0)
		button_hover_style.set_border_width_all(1)
		button_hover_style.set_corner_radius_all(4)
		control.add_theme_stylebox_override("hover", button_hover_style)
		
		control.add_theme_color_override("font_color", Color.WHITE)
	elif control is RichTextLabel:
		var rtl_style = StyleBoxFlat.new()
		rtl_style.bg_color = Color(0.05, 0.05, 0.05, 1.0)
		rtl_style.border_color = Color(0.2, 0.2, 0.2, 1.0)
		rtl_style.set_border_width_all(1)
		rtl_style.set_corner_radius_all(4)
		control.add_theme_stylebox_override("normal", rtl_style)
		control.add_theme_color_override("default_color", Color.WHITE)
		control.add_theme_color_override("font_color", Color.WHITE)

func _create_basic_properties(parent: VBoxContainer):
	var group_label = Label.new()
	group_label.text = "Basic Properties"
	group_label.add_theme_font_size_override("font_size", 14)
	parent.add_child(group_label)
	
	# Room name
	var name_container = HBoxContainer.new()
	parent.add_child(name_container)
	var name_label = Label.new()
	name_label.text = "Name:"
	name_label.custom_minimum_size.x = 80
	_apply_control_theme(name_label)
	name_container.add_child(name_label)
	ui_room_name = LineEdit.new()
	ui_room_name.text_changed.connect(_on_room_name_changed)
	_apply_control_theme(ui_room_name)
	name_container.add_child(ui_room_name)
	
	# Central color
	var color_container = HBoxContainer.new()
	parent.add_child(color_container)
	var color_label = Label.new()
	color_label.text = "Color:"
	color_label.custom_minimum_size.x = 80
	_apply_control_theme(color_label)
	color_container.add_child(color_label)
	ui_central_color = ColorPickerButton.new()
	ui_central_color.color_changed.connect(_on_central_color_changed)
	color_container.add_child(ui_central_color)
	
	# Dimensions
	_create_dimension_control(parent, "Width:", "ui_width", 50, 1000, 10, 300, _on_width_changed)
	_create_dimension_control(parent, "Height:", "ui_height", 50, 1000, 10, 300, _on_height_changed)
	_create_dimension_control(parent, "Extrusion:", "ui_extrusion_height", 10, 1000, 5, 255, _on_extrusion_height_changed)
	_create_dimension_control(parent, "Interior Offset:", "ui_interior_offset", 0, 50, 0.5, 12.5, _on_interior_offset_changed)

func _create_dimension_control(parent: VBoxContainer, label_text: String, control_name: String, min_val: float, max_val: float, step_val: float, default_val: float, callback: Callable):
	var container = HBoxContainer.new()
	parent.add_child(container)
	
	var label = Label.new()
	label.text = label_text
	label.custom_minimum_size.x = 80
	_apply_control_theme(label)
	container.add_child(label)
	
	var spinbox = SpinBox.new()
	spinbox.min_value = min_val
	spinbox.max_value = max_val
	spinbox.step = step_val
	spinbox.value = default_val
	spinbox.value_changed.connect(callback)
	_apply_control_theme(spinbox)
	container.add_child(spinbox)
	
	# Assign to appropriate variable
	match control_name:
		"ui_width": ui_width = spinbox
		"ui_height": ui_height = spinbox
		"ui_extrusion_height": ui_extrusion_height = spinbox
		"ui_interior_offset": ui_interior_offset = spinbox

func _create_window_properties(parent: VBoxContainer):
	var group_label = Label.new()
	group_label.text = "Window Settings"
	group_label.add_theme_font_size_override("font_size", 14)
	_apply_control_theme(group_label)
	parent.add_child(group_label)
	
	# Has window checkbox
	ui_has_window = CheckBox.new()
	ui_has_window.text = "Has Window"
	ui_has_window.toggled.connect(_on_has_window_changed)
	_apply_control_theme(ui_has_window)
	parent.add_child(ui_has_window)
	
	# Window style
	_create_option_control(parent, "Style:", "ui_window_style", ["standard", "sliding", "casement", "bay"], _on_window_style_changed)
	
	# Window side
	_create_option_control(parent, "Side:", "ui_window_side", ["Bottom (0°)", "Right (90°)", "Top (180°)", "Left (270°)"], _on_window_side_changed)
	
	# Window parameters
	_create_window_spinbox_controls(parent)

func _create_window_spinbox_controls(parent: VBoxContainer):
	_create_spinbox_control(parent, "Offset:", "ui_window_offset", -200, 200, 5, 0, _on_window_offset_changed)
	_create_spinbox_control(parent, "N Offset:", "ui_window_n_offset", -1000, 1000, 5, 0, _on_window_n_offset_changed)
	_create_spinbox_control(parent, "Z Offset:", "ui_window_z_offset", -500, 500, 5, 0, _on_window_z_offset_changed)
	_create_spinbox_control(parent, "Width (2D):", "ui_window_width", 20, 500, 5, 45, _on_window_width_changed)
	_create_spinbox_control(parent, "Length (2D):", "ui_window_length", 20, 300, 5, 120, _on_window_length_changed)
	_create_spinbox_control(parent, "Height (3D Cut):", "ui_window_height", 10, 500, 1, 120, _on_window_height_changed)
	_create_spinbox_control(parent, "Sill (Z-Trans):", "ui_window_sill", 0, 200, 1, 90, _on_window_sill_changed)

func _create_door_properties(parent: VBoxContainer):
	var group_label = Label.new()
	group_label.text = "Door Settings"
	group_label.add_theme_font_size_override("font_size", 14)
	_apply_control_theme(group_label)
	parent.add_child(group_label)
	
	# Has door checkbox
	ui_has_door = CheckBox.new()
	ui_has_door.text = "Has Door"
	ui_has_door.toggled.connect(_on_has_door_changed)
	_apply_control_theme(ui_has_door)
	parent.add_child(ui_has_door)
	
	# Door style
	_create_option_control(parent, "Style:", "ui_door_style", ["standard", "sliding", "double", "french"], _on_door_style_changed)
	
	# Door side
	_create_option_control(parent, "Side:", "ui_door_side", ["Bottom (0°)", "Right (90°)", "Top (180°)", "Left (270°)"], _on_door_side_changed)
	
	# Door parameters
	_create_door_spinbox_controls(parent)

func _create_door_spinbox_controls(parent: VBoxContainer):
	_create_spinbox_control(parent, "Offset:", "ui_door_offset", -200, 200, 5, 0, _on_door_offset_changed)
	_create_spinbox_control(parent, "N Offset:", "ui_door_n_offset", -1000, 1000, 5, 0, _on_door_n_offset_changed)
	_create_spinbox_control(parent, "Z Offset:", "ui_door_z_offset", -500, 500, 5, 0, _on_door_z_offset_changed)
	_create_spinbox_control(parent, "Width (2D):", "ui_door_width", 20, 500, 5, 45, _on_door_width_changed)
	_create_spinbox_control(parent, "Length (2D):", "ui_door_length", 20, 300, 5, 90, _on_door_length_changed)
	_create_spinbox_control(parent, "Height (3D Cut):", "ui_door_height", 10, 500, 1, 210, _on_door_height_changed)
	_create_spinbox_control(parent, "Sill (Z-Trans):", "ui_door_sill", 0, 200, 1, 0, _on_door_sill_changed)

func _create_option_control(parent: VBoxContainer, label_text: String, control_name: String, options: Array[String], callback: Callable):
	var container = HBoxContainer.new()
	parent.add_child(container)
	
	var label = Label.new()
	label.text = label_text
	label.custom_minimum_size.x = 80
	_apply_control_theme(label)
	container.add_child(label)
	
	var option_button = OptionButton.new()
	for option in options:
		option_button.add_item(option)
	option_button.item_selected.connect(callback)
	_apply_control_theme(option_button)
	container.add_child(option_button)
	
	# Assign to appropriate variable
	match control_name:
		"ui_window_style": ui_window_style = option_button
		"ui_window_side": ui_window_side = option_button
		"ui_door_style": ui_door_style = option_button
		"ui_door_side": ui_door_side = option_button

func _create_spinbox_control(parent: VBoxContainer, label_text: String, control_name: String, min_val: float, max_val: float, step_val: float, default_val: float, callback: Callable):
	var container = HBoxContainer.new()
	parent.add_child(container)
	
	var label = Label.new()
	label.text = label_text
	label.custom_minimum_size.x = 80
	_apply_control_theme(label)
	container.add_child(label)
	
	var spinbox = SpinBox.new()
	spinbox.min_value = min_val
	spinbox.max_value = max_val
	spinbox.step = step_val
	spinbox.value = default_val
	spinbox.value_changed.connect(callback)
	_apply_control_theme(spinbox)
	container.add_child(spinbox)
	
	# Assign to appropriate variable
	match control_name:
		"ui_window_offset": ui_window_offset = spinbox
		"ui_window_n_offset": ui_window_n_offset = spinbox
		"ui_window_z_offset": ui_window_z_offset = spinbox
		"ui_window_width": ui_window_width = spinbox
		"ui_window_length": ui_window_length = spinbox
		"ui_window_height": ui_window_height = spinbox
		"ui_window_sill": ui_window_sill = spinbox
		"ui_door_offset": ui_door_offset = spinbox
		"ui_door_n_offset": ui_door_n_offset = spinbox
		"ui_door_z_offset": ui_door_z_offset = spinbox
		"ui_door_width": ui_door_width = spinbox
		"ui_door_length": ui_door_length = spinbox
		"ui_door_height": ui_door_height = spinbox
		"ui_door_sill": ui_door_sill = spinbox

func _create_geometry_display(parent: VBoxContainer):
	var group_label = Label.new()
	group_label.text = "Geometry Info"
	group_label.add_theme_font_size_override("font_size", 14)
	_apply_control_theme(group_label)
	parent.add_child(group_label)
	
	geometry_display = RichTextLabel.new()
	geometry_display.custom_minimum_size.y = 150
	geometry_display.bbcode_enabled = true
	_apply_control_theme(geometry_display)
	parent.add_child(geometry_display)
	
	var refresh_button = Button.new()
	refresh_button.text = "Refresh Geometry"
	refresh_button.pressed.connect(_update_geometry_display)
	_apply_control_theme(refresh_button)
	parent.add_child(refresh_button)

func _create_validation_display(parent: VBoxContainer):
	var group_label = Label.new()
	group_label.text = "Validation"
	group_label.add_theme_font_size_override("font_size", 14)
	_apply_control_theme(group_label)
	parent.add_child(group_label)
	
	validation_display = RichTextLabel.new()
	validation_display.custom_minimum_size.y = 100
	validation_display.bbcode_enabled = true
	_apply_control_theme(validation_display)
	parent.add_child(validation_display)

func _create_action_buttons(parent: VBoxContainer):
	# First row - Action buttons
	var action_container = HBoxContainer.new()
	parent.add_child(action_container)
	
	var change_color_button = Button.new()
	change_color_button.text = "Random Color"
	change_color_button.pressed.connect(_on_random_color_pressed)
	_apply_control_theme(change_color_button)
	action_container.add_child(change_color_button)
	
	var delete_button = Button.new()
	delete_button.text = "Delete Shape"
	delete_button.pressed.connect(_on_delete_shape_pressed)
	delete_button.modulate = Color.LIGHT_CORAL  # Red tint for delete button
	_apply_control_theme(delete_button)
	action_container.add_child(delete_button)
	
	# Second row - Control buttons  
	var button_container = HBoxContainer.new()
	parent.add_child(button_container)
	
	var apply_button = Button.new()
	apply_button.text = "Apply Changes"
	apply_button.pressed.connect(_apply_all_changes)
	_apply_control_theme(apply_button)
	button_container.add_child(apply_button)
	
	var close_button = Button.new()
	close_button.text = "Close"
	close_button.pressed.connect(_on_close_pressed)
	_apply_control_theme(close_button)
	button_container.add_child(close_button)

func set_shape(shape: TetrisShape2D):
	current_shape = shape
	if shape:
		_update_ui_from_shape()
		_update_geometry_display()
		_validate_shape()
		show()
	else:
		hide()

func _update_ui_from_shape():
	if not current_shape:
		return
	
	is_updating_ui = true
	
	# Basic properties
	ui_room_name.text = current_shape.room_name
	ui_central_color.color = current_shape.central_color
	
	var dimensions = current_shape.get_current_dimensions()
	ui_width.value = dimensions.x
	ui_height.value = dimensions.y
	ui_extrusion_height.value = current_shape.extrusion_height
	ui_interior_offset.value = current_shape.interior_offset
	
	# Window properties
	ui_has_window.button_pressed = current_shape.has_window
	_set_option_by_text(ui_window_style, current_shape.window_style)
	_set_option_by_side_angle(ui_window_side, current_shape.window_side)
	
	ui_window_offset.value = current_shape.window_offset
	ui_window_n_offset.value = current_shape.window_n_offset
	ui_window_z_offset.value = current_shape.window_z_offset
	ui_window_width.value = current_shape.window_width
	ui_window_length.value = current_shape.window_length
	ui_window_height.value = current_shape.window_height
	ui_window_sill.value = current_shape.window_sill
	
	# Door properties
	ui_has_door.button_pressed = current_shape.has_door
	_set_option_by_text(ui_door_style, current_shape.door_style)
	_set_option_by_side_angle(ui_door_side, current_shape.door_side)
	
	ui_door_offset.value = current_shape.door_offset
	ui_door_n_offset.value = current_shape.door_n_offset
	ui_door_z_offset.value = current_shape.door_z_offset
	ui_door_width.value = current_shape.door_width
	ui_door_length.value = current_shape.door_length
	ui_door_height.value = current_shape.door_height
	ui_door_sill.value = current_shape.door_sill
	
	is_updating_ui = false

func _set_option_by_text(option_button: OptionButton, text: String):
	for i in range(option_button.get_item_count()):
		if option_button.get_item_text(i) == text:
			option_button.selected = i
			return

func _set_option_by_side_angle(option_button: OptionButton, angle: int):
	var index = 0
	match angle:
		0: index = 0    # Bottom
		90: index = 1   # Right
		180: index = 2  # Top
		270: index = 3  # Left
	option_button.selected = index

func _update_geometry_display():
	if not current_shape or not geometry_display:
		return
	
	var geometry_info = current_shape.get_geometry_info()
	var text = "[b]Geometry Information:[/b]\n"
	text += "• Exterior Area: %.2f %s\n" % [geometry_info.exterior_area, geometry_info.area_unit]
	text += "• Interior Area: %.2f %s\n" % [geometry_info.interior_area, geometry_info.area_unit]
	text += "• Wall Area: %.2f %s\n" % [geometry_info.exterior_area - geometry_info.interior_area, geometry_info.area_unit]
	text += "• Perimeter: %.2f %s\n" % [geometry_info.exterior_perimeter, geometry_info.perimeter_unit]
	
	if geometry_info.has("room_area"):
		text += "• Room Surface: %.2f %s\n" % [geometry_info.room_area, geometry_info.area_unit]
	
	if geometry_info.has("window_area"):
		text += "• Window Area: %.2f %s\n" % [geometry_info.window_area, geometry_info.area_unit]
	
	if geometry_info.has("door_area"):
		text += "• Door Area: %.2f %s\n" % [geometry_info.door_area, geometry_info.area_unit]
	
	geometry_display.text = text

func _validate_shape():
	if not current_shape or not validation_display:
		return
	
	var PropertyValidator = preload("res://PropertyValidator.gd")
	var validation_result = PropertyValidator.validate_all_parameters(current_shape)
	
	var text = "[b]Validation Results:[/b]\n"
	
	if validation_result.is_valid:
		text += "[color=green]✓ All parameters are valid[/color]\n"
	else:
		text += "[color=red]✗ Validation failed[/color]\n"
	
	if validation_result.warnings.size() > 0:
		text += "\n[b]Warnings:[/b]\n"
		for warning in validation_result.warnings:
			text += "[color=orange]⚠ %s[/color]\n" % warning
	
	if validation_result.errors.size() > 0:
		text += "\n[b]Errors:[/b]\n"
		for error in validation_result.errors:
			text += "[color=red]✗ %s[/color]\n" % error
	
	validation_display.text = text

func _apply_all_changes():
	if not current_shape or is_updating_ui:
		return
	
	# Apply all changes to the shape
	current_shape.set_room_name(ui_room_name.text)
	current_shape.set_central_color(ui_central_color.color)
	
	var new_size = Vector2(ui_width.value, ui_height.value)
	current_shape.set_dimensions(new_size)
	current_shape.extrusion_height = ui_extrusion_height.value
	current_shape.set_interior_offset(ui_interior_offset.value)
	
	# Window properties
	current_shape.set_has_window(ui_has_window.button_pressed)
	current_shape.set_window_style(ui_window_style.get_item_text(ui_window_style.selected))
	current_shape.set_window_side(_get_angle_from_side_index(ui_window_side.selected))
	current_shape.set_window_offset(ui_window_offset.value)
	current_shape.set_window_n_offset(ui_window_n_offset.value)
	current_shape.set_window_z_offset(ui_window_z_offset.value)
	current_shape.set_window_width(ui_window_width.value)
	current_shape.set_window_length(ui_window_length.value)
	current_shape.set_window_height(ui_window_height.value)
	current_shape.set_window_sill(ui_window_sill.value)
	
	# Door properties
	current_shape.set_has_door(ui_has_door.button_pressed)
	current_shape.set_door_style(ui_door_style.get_item_text(ui_door_style.selected))
	current_shape.set_door_side(_get_angle_from_side_index(ui_door_side.selected))
	current_shape.set_door_offset(ui_door_offset.value)
	current_shape.set_door_n_offset(ui_door_n_offset.value)
	current_shape.set_door_z_offset(ui_door_z_offset.value)
	current_shape.set_door_width(ui_door_width.value)
	current_shape.set_door_length(ui_door_length.value)
	current_shape.set_door_height(ui_door_height.value)
	current_shape.set_door_sill(ui_door_sill.value)
	
	# Update displays
	_update_geometry_display()
	_validate_shape()
	
	# Emit signal that properties changed
	property_changed.emit("all", null)

func _get_angle_from_side_index(index: int) -> int:
	match index:
		0: return 0    # Bottom
		1: return 90   # Right
		2: return 180  # Top
		3: return 270  # Left
		_: return 0

# Event handlers
func _on_room_name_changed(new_text: String):
	if current_shape and not is_updating_ui:
		current_shape.set_room_name(new_text)
		property_changed.emit("room_name", new_text)

func _on_central_color_changed(color: Color):
	if current_shape and not is_updating_ui:
		current_shape.set_central_color(color)
		property_changed.emit("central_color", color)

func _on_width_changed(value: float):
	if current_shape and not is_updating_ui:
		var new_size = Vector2(value, current_shape.get_current_dimensions().y)
		current_shape.set_dimensions(new_size)
		_update_geometry_display()
		_validate_shape()
		property_changed.emit("width", value)

func _on_height_changed(value: float):
	if current_shape and not is_updating_ui:
		var new_size = Vector2(current_shape.get_current_dimensions().x, value)
		current_shape.set_dimensions(new_size)
		_update_geometry_display()
		_validate_shape()
		property_changed.emit("height", value)

func _on_extrusion_height_changed(value: float):
	if current_shape and not is_updating_ui:
		current_shape.extrusion_height = value
		_update_geometry_display()
		property_changed.emit("extrusion_height", value)

func _on_interior_offset_changed(value: float):
	if current_shape and not is_updating_ui:
		current_shape.set_interior_offset(value)
		_update_geometry_display()
		property_changed.emit("interior_offset", value)

# Window event handlers
func _on_has_window_changed(pressed: bool):
	if current_shape and not is_updating_ui:
		current_shape.set_has_window(pressed)
		_validate_shape()
		property_changed.emit("has_window", pressed)

func _on_window_style_changed(index: int):
	if current_shape and not is_updating_ui:
		current_shape.set_window_style(ui_window_style.get_item_text(index))
		property_changed.emit("window_style", ui_window_style.get_item_text(index))

func _on_window_side_changed(index: int):
	if current_shape and not is_updating_ui:
		current_shape.set_window_side(_get_angle_from_side_index(index))
		_validate_shape()
		property_changed.emit("window_side", _get_angle_from_side_index(index))

func _on_window_offset_changed(value: float):
	if current_shape and not is_updating_ui:
		current_shape.set_window_offset(value)
		_validate_shape()
		property_changed.emit("window_offset", value)

func _on_window_n_offset_changed(value: float):
	if current_shape and not is_updating_ui:
		current_shape.set_window_n_offset(value)
		property_changed.emit("window_n_offset", value)

func _on_window_z_offset_changed(value: float):
	if current_shape and not is_updating_ui:
		current_shape.set_window_z_offset(value)
		property_changed.emit("window_z_offset", value)

func _on_window_width_changed(value: float):
	if current_shape and not is_updating_ui:
		current_shape.set_window_width(value)
		_update_geometry_display()
		_validate_shape()
		property_changed.emit("window_width", value)

func _on_window_length_changed(value: float):
	if current_shape and not is_updating_ui:
		current_shape.set_window_length(value)
		_update_geometry_display()
		_validate_shape()
		property_changed.emit("window_length", value)

func _on_window_height_changed(value: float):
	if current_shape and not is_updating_ui:
		current_shape.set_window_height(value)
		_update_geometry_display()
		property_changed.emit("window_height", value)

func _on_window_sill_changed(value: float):
	if current_shape and not is_updating_ui:
		current_shape.set_window_sill(value)
		property_changed.emit("window_sill", value)

# Door event handlers
func _on_has_door_changed(pressed: bool):
	if current_shape and not is_updating_ui:
		current_shape.set_has_door(pressed)
		_validate_shape()
		property_changed.emit("has_door", pressed)

func _on_door_style_changed(index: int):
	if current_shape and not is_updating_ui:
		current_shape.set_door_style(ui_door_style.get_item_text(index))
		property_changed.emit("door_style", ui_door_style.get_item_text(index))

func _on_door_side_changed(index: int):
	if current_shape and not is_updating_ui:
		current_shape.set_door_side(_get_angle_from_side_index(index))
		_validate_shape()
		property_changed.emit("door_side", _get_angle_from_side_index(index))

func _on_door_offset_changed(value: float):
	if current_shape and not is_updating_ui:
		current_shape.set_door_offset(value)
		_validate_shape()
		property_changed.emit("door_offset", value)

func _on_door_n_offset_changed(value: float):
	if current_shape and not is_updating_ui:
		current_shape.set_door_n_offset(value)
		property_changed.emit("door_n_offset", value)

func _on_door_z_offset_changed(value: float):
	if current_shape and not is_updating_ui:
		current_shape.set_door_z_offset(value)
		property_changed.emit("door_z_offset", value)

func _on_door_width_changed(value: float):
	if current_shape and not is_updating_ui:
		current_shape.set_door_width(value)
		_update_geometry_display()
		_validate_shape()
		property_changed.emit("door_width", value)

func _on_door_length_changed(value: float):
	if current_shape and not is_updating_ui:
		current_shape.set_door_length(value)
		_update_geometry_display()
		_validate_shape()
		property_changed.emit("door_length", value)

func _on_door_height_changed(value: float):
	if current_shape and not is_updating_ui:
		current_shape.set_door_height(value)
		_update_geometry_display()
		property_changed.emit("door_height", value)

func _on_door_sill_changed(value: float):
	if current_shape and not is_updating_ui:
		current_shape.set_door_sill(value)
		property_changed.emit("door_sill", value)

func _on_close_pressed():
	hide()
	panel_closed.emit()

func _on_random_color_pressed():
	if current_shape:
		# Generate a random color
		var new_color = Color(
			randf(),  # Red component (0.0 to 1.0)
			randf(),  # Green component (0.0 to 1.0) 
			randf(),  # Blue component (0.0 to 1.0)
			1.0       # Alpha (fully opaque)
		)
		
		# Update the shape color
		current_shape.set_central_color(new_color)
		
		# Update UI to reflect the change
		if ui_central_color:
			is_updating_ui = true
			ui_central_color.color = new_color
			is_updating_ui = false
		
		# Emit signals
		property_changed.emit("central_color", new_color)
		shape_color_change_requested.emit(current_shape)

func _on_delete_shape_pressed():
	if current_shape:
		# Confirm deletion with user
		var confirmation = true  # For now, direct deletion. Could add confirmation dialog later
		
		if confirmation:
			shape_delete_requested.emit(current_shape)
			# Hide panel since shape will be deleted
			hide()
			panel_closed.emit()

# ========================================
# CONTROLUL PRIORITĂȚILOR CSG (AVANSAT)
# ========================================

func _create_csg_priority_control(parent: VBoxContainer):
	"""
	Creează controalele pentru prioritățile CSG (pentru dezvoltatori avansați)
	"""
	var group_label = Label.new()
	group_label.text = "CSG Priority Control (Advanced)"
	group_label.add_theme_font_size_override("font_size", 12)
	group_label.add_theme_color_override("font_color", Color.ORANGE)
	_apply_control_theme(group_label)  # Apply after setting orange color
	group_label.add_theme_color_override("font_color", Color.ORANGE)  # Re-apply orange
	parent.add_child(group_label)
	
	# Buton pentru afișarea ordinii priorităților
	var show_order_button = Button.new()
	show_order_button.text = "Show Priority Order"
	show_order_button.pressed.connect(_on_show_priority_order_pressed)
	_apply_control_theme(show_order_button)
	parent.add_child(show_order_button)
	
	# Controale pentru ajustarea priorităților
	var priority_container = VBoxContainer.new()
	parent.add_child(priority_container)
	
	# Label explicativ
	var info_label = Label.new()
	info_label.text = "💡 Lower values = executed first\n📋 Higher values = higher priority in conflicts"
	info_label.add_theme_font_size_override("font_size", 10)
	info_label.add_theme_color_override("font_color", Color.GRAY)
	info_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_apply_control_theme(info_label)
	info_label.add_theme_color_override("font_color", Color.GRAY)  # Re-apply gray
	priority_container.add_child(info_label)
	
	# Separator
	priority_container.add_child(HSeparator.new())
	
	# Priorități principale (doar citire pentru moment)
	_create_priority_display_item(priority_container, "Outer Walls:", "1.0")
	_create_priority_display_item(priority_container, "Room Cutters:", "2.0")
	_create_priority_display_item(priority_container, "Window Cutboxes:", "3.0")
	_create_priority_display_item(priority_container, "Door Cutboxes:", "3.1")
	_create_priority_display_item(priority_container, "Window Visuals:", "4.0")
	_create_priority_display_item(priority_container, "Door Visuals:", "4.1")
	
	# Buton pentru rebuild cu priorități
	var rebuild_button = Button.new()
	rebuild_button.text = "Rebuild with Current Priorities"
	rebuild_button.pressed.connect(_on_rebuild_with_priorities_pressed)
	priority_container.add_child(rebuild_button)

func _create_priority_display_item(parent: VBoxContainer, label_text: String, value_text: String):
	"""
	Creează un item de afișare pentru o prioritate
	"""
	var container = HBoxContainer.new()
	parent.add_child(container)
	
	var label = Label.new()
	label.text = label_text
	label.add_theme_font_size_override("font_size", 10)
	label.set_h_size_flags(Control.SIZE_EXPAND_FILL)
	container.add_child(label)
	
	var value_label = Label.new()
	value_label.text = value_text
	value_label.add_theme_font_size_override("font_size", 10)
	value_label.add_theme_color_override("font_color", Color.CYAN)
	value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	container.add_child(value_label)

# Callback pentru afișarea ordinii priorităților
func _on_show_priority_order_pressed():
	"""
	Afișează ordinea priorităților în consolă
	"""
	print("🔧 PropertyPanel: Requesting priority order display...")
	
	# Caută SolidFactory în scenă
	var solid_factory = _find_solid_factory()
	if solid_factory:
		solid_factory.print_priority_order()
	else:
		print("❌ SolidFactory not found in scene")

# Callback pentru rebuild cu priorități
func _on_rebuild_with_priorities_pressed():
	"""
	Declanșează un rebuild al clădirii cu prioritățile curente
	"""
	print("🔧 PropertyPanel: Requesting rebuild with current priorities...")
	
	# Emit un signal pentru a informa Main că trebuie să reconstruiască
	# (Signal-ul va fi adăugat la PropertyPanel)
	if has_signal("rebuild_building_requested"):
		emit_signal("rebuild_building_requested")
	else:
		print("💡 Note: Add 'rebuild_building_requested' signal to PropertyPanel for full functionality")

# Helper pentru găsirea SolidFactory în scenă
func _find_solid_factory() -> SolidFactory:
	"""
	Caută SolidFactory în scenă
	"""
	var main_node = get_tree().get_first_node_in_group("main")
	if main_node and main_node.has_method("get_solid_factory"):
		return main_node.get_solid_factory()
	
	# Căutare alternativă în copiii scenei
	return _search_for_solid_factory(get_tree().root)

func _search_for_solid_factory(node: Node) -> SolidFactory:
	"""
	Caută recursiv SolidFactory în scenă
	"""
	if node is SolidFactory:
		return node
	
	for child in node.get_children():
		var result = _search_for_solid_factory(child)
		if result:
			return result
	
	return null
