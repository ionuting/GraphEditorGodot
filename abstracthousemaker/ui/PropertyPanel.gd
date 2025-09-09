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
	_create_ui()

func _setup_panel_style():
	# Setup panel appearance - fixed to right side regardless of screen resize
	set_anchors_and_offsets_preset(Control.PRESET_RIGHT_WIDE)
	size = Vector2(320, 0)  # Width fixed, height will stretch
	position = Vector2(-330, 10)
	set_offsets_preset(Control.PRESET_RIGHT_WIDE, Control.PRESET_MODE_KEEP_SIZE, 10)
	custom_minimum_size = Vector2(320, 600)
	visible = false
	
	# Background style
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.15, 0.15, 0.15, 0.95)
	style.set_border_width_all(2)
	style.border_color = Color(0.3, 0.3, 0.3)
	style.set_corner_radius_all(8)
	add_theme_stylebox_override("panel", style)

func _create_ui():
	# Main scroll container
	var scroll = ScrollContainer.new()
	scroll.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	scroll.set_offsets_preset(Control.PRESET_FULL_RECT, Control.PRESET_MODE_MINSIZE, 10)
	add_child(scroll)
	
	var main_vbox = VBoxContainer.new()
	main_vbox.set_h_size_flags(Control.SIZE_EXPAND_FILL)
	scroll.add_child(main_vbox)
	
	# Title
	var title = Label.new()
	title.text = "Shape Properties"
	title.add_theme_font_size_override("font_size", 16)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	main_vbox.add_child(title)
	
	main_vbox.add_child(HSeparator.new())
	
	# Basic properties
	_create_basic_properties(main_vbox)
	main_vbox.add_child(HSeparator.new())
	
	# Window properties
	_create_window_properties(main_vbox)
	main_vbox.add_child(HSeparator.new())
	
	# Door properties
	_create_door_properties(main_vbox)
	main_vbox.add_child(HSeparator.new())
	
	# Geometry display
	_create_geometry_display(main_vbox)
	main_vbox.add_child(HSeparator.new())
	
	# Validation display
	_create_validation_display(main_vbox)
	main_vbox.add_child(HSeparator.new())
	
	# CSG Priority control (advanced)
	_create_csg_priority_control(main_vbox)
	main_vbox.add_child(HSeparator.new())
	
	# Action buttons
	_create_action_buttons(main_vbox)

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
	name_container.add_child(name_label)
	ui_room_name = LineEdit.new()
	ui_room_name.text_changed.connect(_on_room_name_changed)
	name_container.add_child(ui_room_name)
	
	# Central color
	var color_container = HBoxContainer.new()
	parent.add_child(color_container)
	var color_label = Label.new()
	color_label.text = "Color:"
	color_label.custom_minimum_size.x = 80
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
	container.add_child(label)
	
	var spinbox = SpinBox.new()
	spinbox.min_value = min_val
	spinbox.max_value = max_val
	spinbox.step = step_val
	spinbox.value = default_val
	spinbox.value_changed.connect(callback)
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
	parent.add_child(group_label)
	
	# Has window checkbox
	ui_has_window = CheckBox.new()
	ui_has_window.text = "Has Window"
	ui_has_window.toggled.connect(_on_has_window_changed)
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
	parent.add_child(group_label)
	
	# Has door checkbox
	ui_has_door = CheckBox.new()
	ui_has_door.text = "Has Door"
	ui_has_door.toggled.connect(_on_has_door_changed)
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
	container.add_child(label)
	
	var option_button = OptionButton.new()
	for option in options:
		option_button.add_item(option)
	option_button.item_selected.connect(callback)
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
	container.add_child(label)
	
	var spinbox = SpinBox.new()
	spinbox.min_value = min_val
	spinbox.max_value = max_val
	spinbox.step = step_val
	spinbox.value = default_val
	spinbox.value_changed.connect(callback)
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
	parent.add_child(group_label)
	
	geometry_display = RichTextLabel.new()
	geometry_display.custom_minimum_size.y = 150
	geometry_display.bbcode_enabled = true
	parent.add_child(geometry_display)
	
	var refresh_button = Button.new()
	refresh_button.text = "Refresh Geometry"
	refresh_button.pressed.connect(_update_geometry_display)
	parent.add_child(refresh_button)

func _create_validation_display(parent: VBoxContainer):
	var group_label = Label.new()
	group_label.text = "Validation"
	group_label.add_theme_font_size_override("font_size", 14)
	parent.add_child(group_label)
	
	validation_display = RichTextLabel.new()
	validation_display.custom_minimum_size.y = 100
	validation_display.bbcode_enabled = true
	parent.add_child(validation_display)

func _create_action_buttons(parent: VBoxContainer):
	# First row - Action buttons
	var action_container = HBoxContainer.new()
	parent.add_child(action_container)
	
	var change_color_button = Button.new()
	change_color_button.text = "Random Color"
	change_color_button.pressed.connect(_on_random_color_pressed)
	action_container.add_child(change_color_button)
	
	var delete_button = Button.new()
	delete_button.text = "Delete Shape"
	delete_button.pressed.connect(_on_delete_shape_pressed)
	delete_button.modulate = Color.LIGHT_CORAL  # Red tint for delete button
	action_container.add_child(delete_button)
	
	# Second row - Control buttons  
	var button_container = HBoxContainer.new()
	parent.add_child(button_container)
	
	var apply_button = Button.new()
	apply_button.text = "Apply Changes"
	apply_button.pressed.connect(_apply_all_changes)
	button_container.add_child(apply_button)
	
	var close_button = Button.new()
	close_button.text = "Close"
	close_button.pressed.connect(_on_close_pressed)
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
	parent.add_child(group_label)
	
	# Buton pentru afișarea ordinii priorităților
	var show_order_button = Button.new()
	show_order_button.text = "Show Priority Order"
	show_order_button.pressed.connect(_on_show_priority_order_pressed)
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
