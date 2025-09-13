# RectangleCellPropertiesPanel.gd
# Panou de proprietăți pentru configurarea RectangleCell
class_name RectangleCellPropertiesPanel

extends Panel

# Semnal pentru aplicarea proprietăților
signal properties_applied(properties: Dictionary)

# Referința la cell manager
var cell_manager: RectangleCellManager
var cad_viewer: Control

# Controale UI
var width_spinbox: SpinBox
var height_spinbox: SpinBox
var offset_spinbox: SpinBox
var name_line_edit: LineEdit
var type_option_button: OptionButton
var index_spinbox: SpinBox

# Extended controls
var height_3d_spin: SpinBox
var sill_spin: SpinBox
var translation_x_spin: SpinBox
var translation_y_spin: SpinBox
var cut_priority_spin: SpinBox
var material_line: LineEdit
var is_exterior_check: CheckBox

# Butoane
var apply_default_button: Button
var apply_selected_button: Button
var close_button: Button

# Flag pentru a preveni actualizările recursive
var updating_ui: bool = false

func _init():
	# Setează proprietățile panoului
	size = Vector2(300, 400)
	position = Vector2(50, 150)
	
	# Stil pentru panou
	var style_box = StyleBoxFlat.new()
	style_box.bg_color = Color(0.2, 0.2, 0.2, 0.95)
	style_box.border_width_left = 2
	style_box.border_width_right = 2
	style_box.border_width_top = 2
	style_box.border_width_bottom = 2
	style_box.border_color = Color(0.5, 0.5, 0.5, 1.0)
	add_theme_stylebox_override("panel", style_box)
	
	_create_ui()

func _create_ui():
	# Container principal
	var vbox = VBoxContainer.new()
	vbox.position = Vector2(10, 10)
	vbox.size = Vector2(280, 380)
	add_child(vbox)
	
	# Titlu
	var title_label = Label.new()
	title_label.text = "Rectangle Cell Properties"
	title_label.add_theme_font_size_override("font_size", 16)
	title_label.add_theme_color_override("font_color", Color.WHITE)
	vbox.add_child(title_label)
	
	# Separator
	var separator1 = HSeparator.new()
	vbox.add_child(separator1)
	
	# Secțiunea Dimensiuni
	_create_dimensions_section(vbox)
	
	# Separator
	var separator2 = HSeparator.new()
	vbox.add_child(separator2)
	
	# Secțiunea Offset
	_create_offset_section(vbox)
	
	# Separator
	var separator3 = HSeparator.new()
	vbox.add_child(separator3)
	
	# Secțiunea Proprietăți
	_create_properties_section(vbox)
	
	# Separator
	var separator4 = HSeparator.new()
	vbox.add_child(separator4)
	
	# Butoane
	_create_buttons_section(vbox)

func _create_dimensions_section(parent: VBoxContainer):
	var dim_label = Label.new()
	dim_label.text = "Dimensiuni"
	dim_label.add_theme_color_override("font_color", Color.CYAN)
	parent.add_child(dim_label)
	
	# Width
	var width_container = HBoxContainer.new()
	parent.add_child(width_container)
	
	var width_label = Label.new()
	width_label.text = "Lățime:"
	width_label.custom_minimum_size.x = 80
	width_label.add_theme_color_override("font_color", Color.WHITE)
	width_container.add_child(width_label)
	
	width_spinbox = SpinBox.new()
	width_spinbox.min_value = 0.1
	width_spinbox.max_value = 100.0
	width_spinbox.step = 0.1
	width_spinbox.value = 1.0
	width_spinbox.custom_minimum_size.x = 100
	width_spinbox.value_changed.connect(_on_width_changed)
	width_container.add_child(width_spinbox)
	
	# Height
	var height_container = HBoxContainer.new()
	parent.add_child(height_container)
	
	var height_label = Label.new()
	height_label.text = "Înălțime:"
	height_label.custom_minimum_size.x = 80
	height_label.add_theme_color_override("font_color", Color.WHITE)
	height_container.add_child(height_label)
	
	height_spinbox = SpinBox.new()
	height_spinbox.min_value = 0.1
	height_spinbox.max_value = 100.0
	height_spinbox.step = 0.1
	height_spinbox.value = 1.0
	height_spinbox.custom_minimum_size.x = 100
	height_spinbox.value_changed.connect(_on_height_changed)
	height_container.add_child(height_spinbox)

func _create_offset_section(parent: VBoxContainer):
	var offset_label = Label.new()
	offset_label.text = "Offset"
	offset_label.add_theme_color_override("font_color", Color.YELLOW)
	parent.add_child(offset_label)

	var offset_container = HBoxContainer.new()
	parent.add_child(offset_container)

	var offset_label2 = Label.new()
	offset_label2.text = "Offset:"
	offset_label2.custom_minimum_size.x = 80
	offset_label2.add_theme_color_override("font_color", Color.WHITE)
	offset_container.add_child(offset_label2)

	offset_spinbox = SpinBox.new()
	offset_spinbox.min_value = -50.0
	offset_spinbox.max_value = 50.0
	offset_spinbox.step = 0.001
	offset_spinbox.value = 0.0
	offset_spinbox.custom_minimum_size.x = 100
	offset_spinbox.allow_greater = true
	offset_spinbox.allow_lesser = true
	offset_spinbox.value_changed.connect(_on_offset_changed)
	offset_container.add_child(offset_spinbox)

func _create_properties_section(parent: VBoxContainer):
	var props_label = Label.new()
	props_label.text = "Proprietăți"
	props_label.add_theme_color_override("font_color", Color.GREEN)
	parent.add_child(props_label)
	
	# Nume
	var name_container = HBoxContainer.new()
	parent.add_child(name_container)
	
	var name_label = Label.new()
	name_label.text = "Nume:"
	name_label.custom_minimum_size.x = 80
	name_label.add_theme_color_override("font_color", Color.WHITE)
	name_container.add_child(name_label)
	
	name_line_edit = LineEdit.new()
	name_line_edit.text = "Cell"
	name_line_edit.custom_minimum_size.x = 150
	name_line_edit.text_changed.connect(_on_name_changed)
	name_container.add_child(name_line_edit)
	
	# Tip
	var type_container = HBoxContainer.new()
	parent.add_child(type_container)
	
	var type_label = Label.new()
	type_label.text = "Tip:"
	type_label.custom_minimum_size.x = 80
	type_label.add_theme_color_override("font_color", Color.WHITE)
	type_container.add_child(type_label)
	
	type_option_button = OptionButton.new()
	type_option_button.add_item("Standard")
	type_option_button.add_item("Special")
	type_option_button.add_item("Custom")
	type_option_button.add_item("Temporary")
	# Add Window type so the same panel can be reused for windows
	type_option_button.add_item("Window")
	type_option_button.custom_minimum_size.x = 150
	type_option_button.item_selected.connect(_on_type_changed)
	type_container.add_child(type_option_button)
	
	# Index
	var index_container = HBoxContainer.new()
	parent.add_child(index_container)
	
	var index_label = Label.new()
	index_label.text = "Index:"
	index_label.custom_minimum_size.x = 80
	index_label.add_theme_color_override("font_color", Color.WHITE)
	index_container.add_child(index_label)
	
	index_spinbox = SpinBox.new()
	index_spinbox.min_value = 1
	index_spinbox.max_value = 9999
	index_spinbox.step = 1
	index_spinbox.value = 1
	index_spinbox.custom_minimum_size.x = 100
	index_spinbox.value_changed.connect(_on_index_changed)
	index_container.add_child(index_spinbox)

	# Extended ArchiCAD-like properties
	# 3D Height
	var h3d_container = HBoxContainer.new()
	parent.add_child(h3d_container)
	var h3d_label = Label.new()
	h3d_label.text = "3D Height:"
	h3d_label.custom_minimum_size.x = 80
	h3d_label.add_theme_color_override("font_color", Color.WHITE)
	h3d_container.add_child(h3d_label)
	height_3d_spin = SpinBox.new()
	height_3d_spin.min_value = 0.0
	height_3d_spin.max_value = 1000.0
	height_3d_spin.step = 0.001
	height_3d_spin.value = 0.0
	height_3d_spin.custom_minimum_size.x = 100
	h3d_container.add_child(height_3d_spin)

	# Sill
	var sill_container = HBoxContainer.new()
	parent.add_child(sill_container)
	var sill_label = Label.new()
	sill_label.text = "Sill:"
	sill_label.custom_minimum_size.x = 80
	sill_label.add_theme_color_override("font_color", Color.WHITE)
	sill_container.add_child(sill_label)
	sill_spin = SpinBox.new()
	sill_spin.min_value = 0.0
	sill_spin.max_value = 1000.0
	sill_spin.step = 0.001
	sill_spin.value = 0.0
	sill_spin.custom_minimum_size.x = 100
	sill_container.add_child(sill_spin)

	# Insert offset (for windows)
	var insert_off_container = HBoxContainer.new()
	parent.add_child(insert_off_container)
	var insert_off_label = Label.new()
	insert_off_label.text = "Insert Offset:"
	insert_off_label.custom_minimum_size.x = 80
	insert_off_label.add_theme_color_override("font_color", Color.WHITE)
	insert_off_container.add_child(insert_off_label)
	var insert_offset_spin = SpinBox.new()
	insert_offset_spin.min_value = -100.0
	insert_offset_spin.max_value = 100.0
	insert_offset_spin.step = 0.001
	insert_offset_spin.value = 1.25
	insert_offset_spin.custom_minimum_size.x = 100
	insert_off_container.add_child(insert_offset_spin)

	# Rotation (degrees)
	var rot_container = HBoxContainer.new()
	parent.add_child(rot_container)
	var rot_label = Label.new()
	rot_label.text = "Rotation (deg):"
	rot_label.custom_minimum_size.x = 80
	rot_label.add_theme_color_override("font_color", Color.WHITE)
	rot_container.add_child(rot_label)
	var rotation_spin = SpinBox.new()
	rotation_spin.min_value = -360.0
	rotation_spin.max_value = 360.0
	rotation_spin.step = 0.1
	rotation_spin.value = 0.0
	rotation_spin.custom_minimum_size.x = 100
	rot_container.add_child(rotation_spin)

	# Translation X/Y
	var trans_container = HBoxContainer.new()
	parent.add_child(trans_container)
	var trans_label = Label.new()
	trans_label.text = "Translation X:"
	trans_label.custom_minimum_size.x = 80
	trans_label.add_theme_color_override("font_color", Color.WHITE)
	trans_container.add_child(trans_label)
	translation_x_spin = SpinBox.new()
	translation_x_spin.min_value = -10000.0
	translation_x_spin.max_value = 10000.0
	translation_x_spin.step = 0.001
	translation_x_spin.value = 0.0
	translation_x_spin.custom_minimum_size.x = 80
	trans_container.add_child(translation_x_spin)
	var trans_label_y = Label.new()
	trans_label_y.text = " Y:"
	trans_container.add_child(trans_label_y)
	translation_y_spin = SpinBox.new()
	translation_y_spin.min_value = -10000.0
	translation_y_spin.max_value = 10000.0
	translation_y_spin.step = 0.001
	translation_y_spin.value = 0.0
	translation_y_spin.custom_minimum_size.x = 80
	trans_container.add_child(translation_y_spin)

	# Cut priority
	var cut_container = HBoxContainer.new()
	parent.add_child(cut_container)
	var cut_label = Label.new()
	cut_label.text = "Cut Priority:"
	cut_label.custom_minimum_size.x = 80
	cut_label.add_theme_color_override("font_color", Color.WHITE)
	cut_container.add_child(cut_label)
	cut_priority_spin = SpinBox.new()
	cut_priority_spin.min_value = -100
	cut_priority_spin.max_value = 100
	cut_priority_spin.step = 1
	cut_priority_spin.value = 0
	cut_priority_spin.custom_minimum_size.x = 100
	cut_container.add_child(cut_priority_spin)

	# Material
	var material_container = HBoxContainer.new()
	parent.add_child(material_container)
	var material_label = Label.new()
	material_label.text = "Material:"
	material_label.custom_minimum_size.x = 80
	material_label.add_theme_color_override("font_color", Color.WHITE)
	material_container.add_child(material_label)
	material_line = LineEdit.new()
	material_line.text = ""
	material_line.custom_minimum_size.x = 150
	material_container.add_child(material_line)

	# Is exterior
	var exterior_container = HBoxContainer.new()
	parent.add_child(exterior_container)
	var exterior_label = Label.new()
	exterior_label.text = "Is Exterior:"
	exterior_label.custom_minimum_size.x = 80
	exterior_label.add_theme_color_override("font_color", Color.WHITE)
	exterior_container.add_child(exterior_label)
	is_exterior_check = CheckBox.new()
	is_exterior_check.set_pressed(false)
	exterior_container.add_child(is_exterior_check)

func _create_buttons_section(parent: VBoxContainer):
	var buttons_container = HBoxContainer.new()
	parent.add_child(buttons_container)
	
	# Buton Apply Default
	
	# Buton Apply Selected
	
	# Spacer
	var spacer = Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	buttons_container.add_child(spacer)
	
	# Buton Close
	close_button = Button.new()
	close_button.text = "Close"
	close_button.custom_minimum_size.x = 60
	close_button.pressed.connect(_on_close_pressed)
	buttons_container.add_child(close_button)
	
	# Save button
	var save_button = Button.new()
	save_button.text = "Save"
	save_button.disabled = false
	save_button.pressed.connect(_on_save_pressed)
	buttons_container.add_child(save_button)

func _on_save_pressed():
	# Apasă pe Save pentru a salva modificările la cell-ul selectat
	var properties = {
		"width": width_spinbox.value,
		"height": height_spinbox.value,
		"offset": offset_spinbox.value,
		"name": name_line_edit.text,
		"type": type_option_button.get_item_text(type_option_button.selected),
		"index": int(index_spinbox.value)
	}

	# Extended properties
	properties["height_3d"] = height_3d_spin.value
	properties["sill"] = sill_spin.value
	properties["translation_x"] = translation_x_spin.value
	properties["translation_y"] = translation_y_spin.value
	properties["cut_priority"] = int(cut_priority_spin.value)
	properties["material"] = material_line.text
	properties["is_exterior"] = is_exterior_check.pressed

	

	properties_applied.emit(properties)

func _on_close_pressed():
	# Închide panoul fără a salva modificările
	self.visible = false

# Event handlers pentru controalele UI
func _on_width_changed(value: float):
	if updating_ui:
		return
	_update_values()

func _on_height_changed(value: float):
	if updating_ui:
		return
	_update_values()

func _on_offset_changed(value: float):
	if updating_ui:
		return
	_update_values()

func _on_name_changed(new_text: String):
	if updating_ui:
		return
	_update_values()

func _on_type_changed(index: int):
	if updating_ui:
		return
	_update_values()

func _on_index_changed(value: float):
	if updating_ui:
		return
	_update_values()

func _update_values():
	# Actualizează valorile în timp real când se schimbă controalele
	if cell_manager and cad_viewer:
		cad_viewer.update_info_display()
		cad_viewer.queue_redraw()

func _on_apply_default_pressed():
	if not cell_manager:
		return
	
	var type_text = type_option_button.get_item_text(type_option_button.selected)
	
	cell_manager.set_default_properties(
		width_spinbox.value,
		height_spinbox.value,
		offset_spinbox.value,
		offset_spinbox.value,
		name_line_edit.text,
		type_text
	)
	
	print("Proprietăți default actualizate pentru noi cell-uri")

func _on_apply_selected_pressed():
	if not cell_manager or not cell_manager.selected_cell:
		return

	var type_text = type_option_button.get_item_text(type_option_button.selected)

	# RectangleCellManager expects signature: (width, height, offset_x, offset_y, name, type, index)
	var success = cell_manager.update_selected_cell_properties(
		width_spinbox.value,
		height_spinbox.value,
		offset_spinbox.value,
		offset_spinbox.value,
		name_line_edit.text,
		type_text,
		int(index_spinbox.value)
	)

	if success:
		print("Cell selectat actualizat cu succes")
		if cad_viewer:
			cad_viewer.update_info_display()
			cad_viewer.queue_redraw()
	else:
		print("Nu există cell selectat pentru actualizare")


# Actualizează UI-ul cu valorile default sau cu cell-ul selectat
func update_ui():
	updating_ui = true
	if cell_manager.selected_cell:
		var cell = cell_manager.selected_cell
		width_spinbox.value = cell.width
		height_spinbox.value = cell.height
		offset_spinbox.value = cell.offset
		name_line_edit.text = cell.cell_name
		index_spinbox.value = cell.cell_index
		# extended
		height_3d_spin.value = cell.height_3d
		sill_spin.value = cell.sill
		translation_x_spin.value = cell.translation_x
		translation_y_spin.value = cell.translation_y
		cut_priority_spin.value = cell.cut_priority
		material_line.text = cell.material
		is_exterior_check.set_pressed(bool(cell.is_exterior))
		var type_index = 0
		match cell.cell_type:
			"Standard": type_index = 0
			"Special": type_index = 1
			"Custom": type_index = 2
			"Temporary": type_index = 3
		type_option_button.selected = type_index
	else:
		width_spinbox.value = cell_manager.default_width
		height_spinbox.value = cell_manager.default_height
		offset_spinbox.value = cell_manager.default_offset
		name_line_edit.text = cell_manager.default_name
		# extended defaults
		height_3d_spin.value = cell_manager.default_height_3d
		sill_spin.value = cell_manager.default_sill
		translation_x_spin.value = cell_manager.default_translation_x
		translation_y_spin.value = cell_manager.default_translation_y
		cut_priority_spin.value = cell_manager.default_cut_priority
		material_line.text = cell_manager.default_material
		is_exterior_check.set_pressed(bool(cell_manager.default_is_exterior))
		index_spinbox.value = cell_manager.next_index
		var type_index = 0
		match cell_manager.default_type:
			"Standard": type_index = 0
			"Special": type_index = 1
			"Custom": type_index = 2
			"Temporary": type_index = 3
		type_option_button.selected = type_index
	updating_ui = false

# Setează proprietățile unui cell specific
func set_cell_properties(cell: RectangleCell):
	if not cell:
		return
		
	updating_ui = true
	
	width_spinbox.value = cell.width
	height_spinbox.value = cell.height
	offset_spinbox.value = cell.offset
	name_line_edit.text = cell.cell_name
	index_spinbox.value = cell.index
	
	# Setează tipul
	var type_index = 0
	match cell.cell_type:
		"Standard": type_index = 0
		"Special": type_index = 1
		"Custom": type_index = 2
		"Temporary": type_index = 3
	type_option_button.selected = type_index
	
	# (butonul Save este mereu activ)
	
	updating_ui = false

# Setează proprietățile default
func set_default_properties(properties: Dictionary):
	updating_ui = true
	
	width_spinbox.value = properties.get("width", 1.0)
	height_spinbox.value = properties.get("height", 1.0) 
	# Support both new single 'offset' or legacy 'offset_x'/'offset_y' keys
	if properties.has("offset"):
		offset_spinbox.value = properties.get("offset", 0.0)
	else:
		offset_spinbox.value = properties.get("offset_x", properties.get("offset_y", 0.0))
	name_line_edit.text = properties.get("name", "Cell")
	index_spinbox.value = properties.get("index", 1)
	
	# Setează tipul
	var type_index = 0
	var type_str = properties.get("type", "Standard")
	match type_str:
		"Standard": type_index = 0
		"Special": type_index = 1
		"Custom": type_index = 2
		"Temporary": type_index = 3
		"Window": type_index = 4
	type_option_button.selected = type_index
	
	# (butonul Save este mereu activ)
	
	updating_ui = false
	

# Curăță selecția
func clear_selection():
	updating_ui = true
	
	# (butonul Save este mereu activ)
	
	updating_ui = false
