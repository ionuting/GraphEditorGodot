extends Node2D


func _on_window_z_offset_changed(value: float):
	if current_selected_shape:
		current_selected_shape.set_window_z_offset(value)

func _on_door_n_offset_changed(value: float):
	if current_selected_shape:
		current_selected_shape.set_door_n_offset(value)

func _on_door_z_offset_changed(value: float):
	if current_selected_shape:
		current_selected_shape.set_door_z_offset(value)


@export var move_mode_enabled: bool = false : set = set_move_mode_enabled
@export var shape_count: int = 1 : set = set_shape_count



# Dicționar global pentru proprietăți shape
var shape_properties: Dictionary = {}

# Array cu toate formele
var shapes: Array = []

# Panoul de proprietăți pentru shape selectat
var ui_panel: Control = null

# Flag pentru a preveni callback-urile în timpul actualizării UI
var is_updating_ui: bool = false

# Shape-ul selectat
var current_selected_shape: TetrisShape2D = null

# Referințe la controalele UI pentru acces direct
var ui_room_name: LineEdit
var ui_central_color: ColorPickerButton
var ui_width: SpinBox
var ui_length: SpinBox
var ui_has_window: CheckBox
var ui_window_style: OptionButton
var ui_has_door: CheckBox
var ui_door_style: OptionButton

signal shape_selection_changed(shape: TetrisShape2D)

func _ready():
	add_to_group("main")
	_create_ui()
	
	# Debug: verifică shape-urile existente ÎNAINTE de a crea altele noi
	print("🔍 DEBUG: Verifică shape-urile EXISTENTE în scenă la început:")
	var existing_shapes = get_children().filter(func(child): return child is TetrisShape2D)
	print("  Găsite ", existing_shapes.size(), " shape-uri existente")
	for i in range(existing_shapes.size()):
		var shape = existing_shapes[i]
		print("  Shape existent [", i, "]: ID=", shape.unique_id, ", pos=", shape.position, ", size=", shape.shape_size)
		shapes.append(shape)  # Adaugă-le în array-ul nostru
		shape.shape_selected.connect(_on_shape_selected.bind(shape))
	
	print("🔍 DEBUG: Creez shape-urile inițiale...")
	_create_initial_shapes()
	print("🔍 DEBUG: După creare, am ", shapes.size(), " shape-uri în total")
	_debug_all_shapes()
	_fix_out_of_bounds_shapes()

func _fix_out_of_bounds_shapes():
	print("🔧 DEBUG: Verifică și repară shape-urile în afara cadrului:")
	var screen_size = get_viewport().get_visible_rect().size
	print("  Mărimea ecranului: ", screen_size)
	
	for i in range(shapes.size()):
		var shape = shapes[i]
		var pos = shape.position
		var needs_fix = false
		var new_pos = pos
		
		if pos.x < 0 or pos.x > screen_size.x:
			new_pos.x = 200 + i * 150
			needs_fix = true
		if pos.y < 0 or pos.y > screen_size.y:
			new_pos.y = 200 + i * 100  
			needs_fix = true
			
		if needs_fix:
			print("  Shape ", shape.unique_id, " repozitionat din ", pos, " în ", new_pos)
			shape.position = new_pos

func _debug_all_shapes():
	print("📋 DEBUG: Lista completă a shape-urilor:")
	for i in range(shapes.size()):
		var shape = shapes[i]
		print("  Shape [", i, "]: ID=", shape.unique_id, ", pos=", shape.position, ", size=", shape.shape_size)
		
	# Verifică și shape-urile din scenă care nu sunt în array-ul nostru
	var scene_shapes = get_children().filter(func(child): return child is TetrisShape2D)
	print("📋 DEBUG: Shape-uri găsite direct în scenă: ", scene_shapes.size())
	for i in range(scene_shapes.size()):
		var shape = scene_shapes[i]
		print("  Scene Shape [", i, "]: ID=", shape.unique_id, ", pos=", shape.position, ", size=", shape.shape_size)

func _create_initial_shapes():
	print("🔍 DEBUG: shape_count = ", shape_count)
	for i in range(shape_count):
		var pos = Vector2(100 + i * 150, 100 + i * 50)
		print("🔍 DEBUG: Creez shape ", i, " la poziția ", pos)
		_add_new_shape(pos)

func _add_new_shape(pos: Vector2 = Vector2.ZERO):
	var new_shape = preload("res://TetrisShape2D.gd").new()
	new_shape.position = pos
	print("🔍 DEBUG: Shape nou creat cu ID ", new_shape.unique_id, " la poziția ", pos)
	new_shape.shape_changed.connect(_on_shape_changed)
	new_shape.shape_selected.connect(_on_shape_selected.bind(new_shape))
	add_child(new_shape)
	new_shape.add_to_group("tetris_shapes")
	shapes.append(new_shape)
	# Adaugă proprietăți în dicționar
	shape_properties[new_shape.unique_id] = new_shape.to_dict()
	_save_shapes_to_json()
	return new_shape

func _create_ui():
	# Creează UI panel pentru controlul parametrilor
	ui_panel = Control.new()
	ui_panel.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	var viewport_height = get_viewport_rect().size.y
	ui_panel.size = Vector2(300, 900)
	ui_panel.position = Vector2(10, 0)
	ui_panel.visible = false # Ascuns la pornire
	# Fundal închis
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.12, 0.12, 0.12, 0.95)
	style.set_border_width_all(2)
	style.border_color = Color(0.25, 0.25, 0.25)
	ui_panel.add_theme_stylebox_override("panel", style)
	add_child(ui_panel)
	# Mutare cu mouse-ul
	ui_panel.mouse_filter = Control.MOUSE_FILTER_PASS
	ui_panel.connect("gui_input", Callable(self, "_on_ui_panel_gui_input"))
	# Creează scroll container pentru UI
	var scroll = ScrollContainer.new()
	scroll.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	ui_panel.add_child(scroll)
	var vbox = VBoxContainer.new()
	scroll.add_child(vbox)
	# Toggle pentru move mode
	var move_toggle = CheckBox.new()
	move_toggle.text = "Move Mode"
	move_toggle.button_pressed = move_mode_enabled
	move_toggle.toggled.connect(_on_move_mode_toggled)
	vbox.add_child(move_toggle)
	# Separator
	vbox.add_child(HSeparator.new())
	# Label pentru formă selectată
	var selected_label = Label.new()
	selected_label.text = "No Shape Selected"
	selected_label.name = "SelectedLabel"
	vbox.add_child(selected_label)
	# Separator
	vbox.add_child(HSeparator.new())
	# Controluri pentru dimensiuni
	_create_dimension_controls(vbox)
	# Separator
	vbox.add_child(HSeparator.new())
	# Controluri pentru feronerie
	_create_window_controls(vbox)
	# Separator
	vbox.add_child(HSeparator.new())
	# Controluri pentru uși
	_create_door_controls(vbox)
	# Separator
	vbox.add_child(HSeparator.new())
	# Controluri pentru geometrie (aria și perimetrul)
	_create_geometry_controls(vbox)
	# Separator
	vbox.add_child(HSeparator.new())
	# Adaugă Room Name și Central Color
	var name_hbox = HBoxContainer.new()
	var name_label = Label.new()
	name_label.text = "Room Name:"
	name_label.custom_minimum_size.x = 80
	name_hbox.add_child(name_label)
	var name_lineedit = LineEdit.new()
	name_lineedit.name = "RoomNameLineEdit"
	name_lineedit.text = "Room"
	ui_room_name = name_lineedit  # Salvează referința
	name_lineedit.text_changed.connect(func(value):
		if is_updating_ui:
			return
		if current_selected_shape:
			current_selected_shape.set_room_name(value)
			# Actualizează dicționarul JSON
			shape_properties[current_selected_shape.unique_id] = current_selected_shape.to_dict()
			_save_shapes_to_json()
	)
	name_hbox.add_child(name_lineedit)
	vbox.add_child(name_hbox)

	var color_hbox = HBoxContainer.new()
	var color_label = Label.new()
	color_label.text = "Central Color:"
	color_label.custom_minimum_size.x = 80
	color_hbox.add_child(color_label)
	var color_picker = ColorPickerButton.new()
	color_picker.name = "CentralColorPicker"
	color_picker.color = Color.LIGHT_GRAY
	ui_central_color = color_picker  # Salvează referința
	color_picker.color_changed.connect(func(value):
		if is_updating_ui:
			return
		if current_selected_shape:
			current_selected_shape.set_central_color(value)
			# Actualizează dicționarul JSON
			shape_properties[current_selected_shape.unique_id] = current_selected_shape.to_dict()
			_save_shapes_to_json()
	)
	color_hbox.add_child(color_picker)
	vbox.add_child(color_hbox)
	# Buton pentru adăugare formă nouă
	vbox.add_child(HSeparator.new())
	var add_button = Button.new()
	add_button.text = "Add New Shape"
	add_button.pressed.connect(_on_add_shape_pressed)
	vbox.add_child(add_button)
	# Buton pentru actualizare proprietăți formă selectată
	var update_button = Button.new()
	update_button.text = "Update Properties"
	update_button.pressed.connect(_on_update_properties_pressed)
	vbox.add_child(update_button)
	# Buton pentru închidere panou
	var close_button = Button.new()
	close_button.text = "Close"
	close_button.pressed.connect(_on_close_panel_pressed)
	vbox.add_child(close_button)
# Ascunde panoul de proprietăți
func _on_close_panel_pressed():
	if ui_panel:
		ui_panel.visible = false
# Actualizează proprietățile formei selectate cu valorile din UI
func _on_update_properties_pressed():
	if not current_selected_shape or not ui_panel:
		return

	# Dimensiuni
	var width_spinbox = ui_panel.find_child("WidthSpinBox")
	var length_spinbox = ui_panel.find_child("HeightSpinBox")
	if width_spinbox and length_spinbox:
		current_selected_shape.set_shape_size(Vector2(width_spinbox.value, length_spinbox.value))

	# Feronerie
	var has_window_check = ui_panel.find_child("HasWindowCheck")
	var window_style = ui_panel.find_child("WindowStyleOption")
	var window_side = ui_panel.find_child("WindowSideOption")
	var window_offset = ui_panel.find_child("WindowOffsetSpinBox")
	var window_n_offset = ui_panel.find_child("WindowNOffsetSpinBox")
	var window_z_offset = ui_panel.find_child("WindowZOffsetSpinBox")
	var window_width = ui_panel.find_child("WindowWidthSpinBox")
	var window_length = ui_panel.find_child("WindowLengthSpinBox")
	var window_height = ui_panel.find_child("WindowHeightPropertySpinBox")
	var window_sill = ui_panel.find_child("WindowSillSpinBox")
	if has_window_check:
		current_selected_shape.set_has_window(has_window_check.button_pressed)
	if window_style:
		var styles = current_selected_shape.get_window_style_options()
		if window_style.selected < styles.size():
			current_selected_shape.set_window_style(styles[window_style.selected])
	if window_side:
		var angles = [0, 90, 180, 270]
		if window_side.selected < angles.size():
			current_selected_shape.set_window_side(angles[window_side.selected])
	if window_offset:
		current_selected_shape.set_window_offset(window_offset.value)
	if window_n_offset:
		current_selected_shape.set_window_n_offset(window_n_offset.value)
	if window_z_offset:
		current_selected_shape.set_window_z_offset(window_z_offset.value)
	if window_width:
		current_selected_shape.set_window_width(window_width.value)
	if window_length:
		current_selected_shape.set_window_length(window_length.value)
	if window_height:
		current_selected_shape.set_window_height(window_height.value)
	if window_sill:
		current_selected_shape.set_window_sill(window_sill.value)

	# Uși
	var has_door_check = ui_panel.find_child("HasDoorCheck")
	var door_style = ui_panel.find_child("DoorStyleOption")
	var door_side = ui_panel.find_child("DoorSideOption")
	var door_offset = ui_panel.find_child("DoorOffsetSpinBox")
	var door_n_offset = ui_panel.find_child("DoorNOffsetSpinBox")
	var door_z_offset = ui_panel.find_child("DoorZOffsetSpinBox")
	var door_width = ui_panel.find_child("DoorWidthSpinBox")
	var door_length = ui_panel.find_child("DoorLengthSpinBox")
	var door_height = ui_panel.find_child("DoorHeightPropertySpinBox")
	var door_sill = ui_panel.find_child("DoorSillSpinBox")
	if has_door_check:
		current_selected_shape.set_has_door(has_door_check.button_pressed)
	if door_style:
		var styles = current_selected_shape.get_door_style_options()
		if door_style.selected < styles.size():
			current_selected_shape.set_door_style(styles[door_style.selected])
	if door_side:
		var angles = [0, 90, 180, 270]
		if door_side.selected < angles.size():
			current_selected_shape.set_door_side(angles[door_side.selected])
	if door_offset:
		current_selected_shape.set_door_offset(door_offset.value)
	if door_n_offset:
		current_selected_shape.set_door_n_offset(door_n_offset.value)
	if door_z_offset:
		current_selected_shape.set_door_z_offset(door_z_offset.value)
	if door_width:
		current_selected_shape.set_door_width(door_width.value)
	if door_length:
		current_selected_shape.set_door_length(door_length.value)
	if door_height:
		current_selected_shape.set_door_height(door_height.value)
	if door_sill:
		current_selected_shape.set_door_sill(door_sill.value)

	# Actualizează proprietățile shape în dicționar și salvează JSON
	shape_properties[current_selected_shape.unique_id] = current_selected_shape.to_dict()
	_save_shapes_to_json()

	# Actualizează label-ul de selecție
	var selected_label = ui_panel.find_child("SelectedLabel")
	if selected_label:
		selected_label.text = "Shape Selected: " + str(current_selected_shape.unique_id)
# Serializare și salvare shapes în JSON
func _save_shapes_to_json():
	var data = shape_properties.duplicate()
	var json_text = JSON.stringify(data)
	var file = FileAccess.open("user://shapes.json", FileAccess.WRITE)
	if file:
		file.store_string(json_text)
		file.close()

# Încărcare shapes din JSON
func _load_shapes_from_json():
	var file = FileAccess.open("user://shapes.json", FileAccess.READ)
	if file:
		var json_text = file.get_as_text()
		file.close()
		var json = JSON.new()
		var result = json.parse(json_text)
		if result == OK:
			var data = json.data
			shape_properties = data

func _create_dimension_controls(parent: VBoxContainer):
	var group_label = Label.new()
	group_label.text = "Shape Dimensions"
	group_label.add_theme_font_size_override("font_size", 14)
	parent.add_child(group_label)
	
	# Width control
	var width_hbox = HBoxContainer.new()
	parent.add_child(width_hbox)
	
	var width_label = Label.new()
	width_label.text = "Width:"
	width_label.custom_minimum_size.x = 80
	width_hbox.add_child(width_label)
	
	var width_spinbox = SpinBox.new()
	width_spinbox.min_value = 50
	width_spinbox.max_value = 1000
	width_spinbox.step = 10
	width_spinbox.value = 300
	width_spinbox.name = "WidthSpinBox"
	ui_width = width_spinbox  # Salvează referința
	width_spinbox.value_changed.connect(_on_width_changed)
	width_hbox.add_child(width_spinbox)
	
	# Height control
	var length_hbox = HBoxContainer.new()
	parent.add_child(length_hbox)
	
	var length_label = Label.new()
	length_label.text = "Height:"
	length_label.custom_minimum_size.x = 80
	length_hbox.add_child(length_label)
	
	var length_spinbox = SpinBox.new()
	length_spinbox.min_value = 50
	length_spinbox.max_value = 1000
	length_spinbox.step = 10
	length_spinbox.value = 300
	length_spinbox.name = "HeightSpinBox"
	ui_length = length_spinbox  # Salvează referința
	length_spinbox.value_changed.connect(_on_length_changed)
	length_hbox.add_child(length_spinbox)

func _create_window_controls(parent: VBoxContainer):
	var group_label = Label.new()
	group_label.text = "Window Settings"
	group_label.add_theme_font_size_override("font_size", 14)
	parent.add_child(group_label)
	
	# Has Window checkbox
	var has_window_check = CheckBox.new()
	has_window_check.text = "Has Window"
	has_window_check.button_pressed = true
	has_window_check.name = "HasWindowCheck"
	has_window_check.toggled.connect(_on_window_has_changed)
	parent.add_child(has_window_check)
	
	# Window Style
	var style_hbox = HBoxContainer.new()
	parent.add_child(style_hbox)
	
	var style_label = Label.new()
	style_label.text = "Style:"
	style_label.custom_minimum_size.x = 80
	style_hbox.add_child(style_label)
	
	var style_option = OptionButton.new()
	style_option.add_item("standard")
	style_option.add_item("sliding")
	style_option.add_item("casement")
	style_option.add_item("bay")
	style_option.name = "WindowStyleOption"
	style_option.item_selected.connect(_on_window_style_changed)
	style_hbox.add_child(style_option)
	
	# Window Side
	var side_hbox = HBoxContainer.new()
	parent.add_child(side_hbox)
	
	var side_label = Label.new()
	side_label.text = "Side:"
	side_label.custom_minimum_size.x = 80
	side_hbox.add_child(side_label)
	
	var side_option = OptionButton.new()
	side_option.add_item("Bottom (0°)")
	side_option.add_item("Right (90°)")
	side_option.add_item("Top (180°)")
	side_option.add_item("Left (270°)")
	side_option.name = "WindowSideOption"
	side_option.item_selected.connect(_on_window_side_changed)
	side_hbox.add_child(side_option)
	
	# Window Offset
	var offset_hbox = HBoxContainer.new()
	parent.add_child(offset_hbox)
	
	var offset_label = Label.new()
	offset_label.text = "Offset:"
	offset_label.custom_minimum_size.x = 80
	offset_hbox.add_child(offset_label)
	
	var offset_spinbox = SpinBox.new()
	offset_spinbox.min_value = -200
	offset_spinbox.max_value = 200
	offset_spinbox.step = 5
	offset_spinbox.value = 0
	offset_spinbox.name = "WindowOffsetSpinBox"
	offset_spinbox.value_changed.connect(_on_window_offset_changed)
	offset_hbox.add_child(offset_spinbox)

	# Window N_Offset
	var n_offset_hbox = HBoxContainer.new()
	parent.add_child(n_offset_hbox)
	var n_offset_label = Label.new()
	n_offset_label.text = "N Offset:"
	n_offset_label.custom_minimum_size.x = 80
	n_offset_hbox.add_child(n_offset_label)
	var n_offset_spinbox = SpinBox.new()
	n_offset_spinbox.min_value = -1000
	n_offset_spinbox.max_value = 1000
	n_offset_spinbox.step = 5
	n_offset_spinbox.value = 0
	n_offset_spinbox.name = "WindowNOffsetSpinBox"
	n_offset_spinbox.value_changed.connect(_on_window_n_offset_changed)
	n_offset_hbox.add_child(n_offset_spinbox)
	
	# Window Dimensions
	var w_width_hbox = HBoxContainer.new()
	parent.add_child(w_width_hbox)
	
	var w_width_label = Label.new()
	w_width_label.text = "W Width:"
	w_width_label.custom_minimum_size.x = 35
	w_width_hbox.add_child(w_width_label)
	
	var w_width_spinbox = SpinBox.new()
	w_width_spinbox.min_value = 20
	w_width_spinbox.max_value = 500
	w_width_spinbox.step = 5
	w_width_spinbox.value = 35
	w_width_spinbox.name = "WindowWidthSpinBox"
	w_width_spinbox.value_changed.connect(_on_window_width_changed)
	w_width_hbox.add_child(w_width_spinbox)
	
	var w_length_hbox = HBoxContainer.new()
	parent.add_child(w_length_hbox)
	
	var w_length_label = Label.new()
	w_length_label.text = "W Lenght:"
	w_length_label.custom_minimum_size.x = 30
	w_length_hbox.add_child(w_length_label)
	
	var w_length_spinbox = SpinBox.new()
	w_length_spinbox.min_value = 20
	w_length_spinbox.max_value = 300
	w_length_spinbox.step = 5
	w_length_spinbox.value = 120
	w_length_spinbox.name = "WindowLengthSpinBox"
	w_length_spinbox.value_changed.connect(_on_window_length_changed)
	w_length_hbox.add_child(w_length_spinbox)

	# Window Height
	var height_hbox = HBoxContainer.new()
	parent.add_child(height_hbox)
	
	var height_label = Label.new()
	height_label.text = "Height:"
	height_label.custom_minimum_size.x = 80
	height_hbox.add_child(height_label)
	
	var height_spinbox = SpinBox.new()
	height_spinbox.min_value = 10
	height_spinbox.max_value = 500
	height_spinbox.step = 1
	height_spinbox.value = 0
	height_spinbox.name = "WindowHeightPropertySpinBox"
	height_spinbox.value_changed.connect(func(value):
		if current_selected_shape:
			current_selected_shape.set_window_height(value)
	)
	height_hbox.add_child(height_spinbox)
	parent.add_child(height_hbox)

	# Window Sill
	var sill_hbox = HBoxContainer.new()
	parent.add_child(sill_hbox)
	var sill_label = Label.new()
	sill_label.text = "Sill:"
	sill_label.custom_minimum_size.x = 80
	sill_hbox.add_child(sill_label)
	var sill_spinbox = SpinBox.new()
	sill_spinbox.min_value = 0
	sill_spinbox.max_value = 200
	sill_spinbox.step = 1
	sill_spinbox.value = 0
	sill_spinbox.name = "WindowSillSpinBox"
	sill_spinbox.value_changed.connect(func(value):
		if current_selected_shape:
			current_selected_shape.set_window_sill(value)
	)
	sill_hbox.add_child(sill_spinbox)
	parent.add_child(sill_hbox)
	
func _create_door_controls(parent: VBoxContainer):
	var group_label = Label.new()
	group_label.text = "Door Settings"
	group_label.add_theme_font_size_override("font_size", 14)
	parent.add_child(group_label)
	
	# Has Door checkbox
	var has_door_check = CheckBox.new()
	has_door_check.text = "Has Door"
	has_door_check.button_pressed = true
	has_door_check.name = "HasDoorCheck"
	has_door_check.toggled.connect(_on_door_has_changed)
	parent.add_child(has_door_check)
	
	# Door Style
	var style_hbox = HBoxContainer.new()
	parent.add_child(style_hbox)
	
	var style_label = Label.new()
	style_label.text = "Style:"
	style_label.custom_minimum_size.x = 80
	style_hbox.add_child(style_label)
	
	var style_option = OptionButton.new()
	style_option.add_item("standard")
	style_option.add_item("sliding")
	style_option.add_item("double")
	style_option.add_item("french")
	style_option.name = "DoorStyleOption"
	style_option.item_selected.connect(_on_door_style_changed)
	style_hbox.add_child(style_option)
	
	# Door Side
	var side_hbox = HBoxContainer.new()
	parent.add_child(side_hbox)
	
	var side_label = Label.new()
	side_label.text = "Side:"
	side_label.custom_minimum_size.x = 80
	side_hbox.add_child(side_label)
	
	var side_option = OptionButton.new()
	side_option.add_item("Bottom (0°)")
	side_option.add_item("Right (90°)")
	side_option.add_item("Top (180°)")
	side_option.add_item("Left (270°)")
	side_option.selected = 1  # Default to Right (90°)
	side_option.name = "DoorSideOption"
	side_option.item_selected.connect(_on_door_side_changed)
	side_hbox.add_child(side_option)
	
	# Door Offset
	var offset_hbox = HBoxContainer.new()
	parent.add_child(offset_hbox)
	
	var offset_label = Label.new()
	offset_label.text = "Offset:"
	offset_label.custom_minimum_size.x = 80
	offset_hbox.add_child(offset_label)
	
	var offset_spinbox = SpinBox.new()
	offset_spinbox.min_value = -200
	offset_spinbox.max_value = 200
	offset_spinbox.step = 5
	offset_spinbox.value = 0
	offset_spinbox.name = "DoorOffsetSpinBox"
	offset_spinbox.value_changed.connect(_on_door_offset_changed)
	offset_hbox.add_child(offset_spinbox)
	
	# Door N_Offset
	var door_n_offset_hbox = HBoxContainer.new()
	parent.add_child(door_n_offset_hbox)
	var door_n_offset_label = Label.new()
	door_n_offset_label.text = "N Offset:"
	door_n_offset_label.custom_minimum_size.x = 80
	door_n_offset_hbox.add_child(door_n_offset_label)
	var door_n_offset_spinbox = SpinBox.new()
	door_n_offset_spinbox.min_value = -100
	door_n_offset_spinbox.max_value = 200
	door_n_offset_spinbox.step = 5
	door_n_offset_spinbox.value = 0
	door_n_offset_spinbox.name = "DoorNOffsetSpinBox"
	door_n_offset_spinbox.value_changed.connect(_on_door_n_offset_changed)
	door_n_offset_hbox.add_child(door_n_offset_spinbox)
	
	# Door Dimensions
	var d_width_hbox = HBoxContainer.new()
	parent.add_child(d_width_hbox)
	
	var d_width_label = Label.new()
	d_width_label.text = "D Width:"
	d_width_label.custom_minimum_size.x = 80
	d_width_hbox.add_child(d_width_label)
	
	var d_width_spinbox = SpinBox.new()
	d_width_spinbox.min_value = 20
	d_width_spinbox.max_value = 300
	d_width_spinbox.step = 5
	d_width_spinbox.value = 90
	d_width_spinbox.name = "DoorWidthSpinBox"
	d_width_spinbox.value_changed.connect(_on_door_width_changed)
	d_width_hbox.add_child(d_width_spinbox)
	
	var d_length_hbox = HBoxContainer.new()
	parent.add_child(d_length_hbox)
	
	var d_length_label = Label.new()
	d_length_label.text = "D Length:"
	d_length_label.custom_minimum_size.x = 80
	d_length_hbox.add_child(d_length_label)
	
	var d_length_spinbox = SpinBox.new()
	d_length_spinbox.min_value = 20
	d_length_spinbox.max_value = 400
	d_length_spinbox.step = 5
	d_length_spinbox.value = 90
	d_length_spinbox.name = "DoorLengthSpinBox"
	d_length_spinbox.value_changed.connect(_on_door_length_changed)
	d_length_hbox.add_child(d_length_spinbox)

	# Door Height
	var height_hbox = HBoxContainer.new()
	parent.add_child(height_hbox)
	
	var height_label = Label.new()
	height_label.text = "Height:"
	height_label.custom_minimum_size.x = 80
	height_hbox.add_child(height_label)
	
	var height_spinbox = SpinBox.new()
	height_spinbox.min_value = 10
	height_spinbox.max_value = 500
	height_spinbox.step = 1
	height_spinbox.value = 0
	height_spinbox.name = "DoorHeightPropertySpinBox"
	height_spinbox.value_changed.connect(func(value):
		if current_selected_shape:
			current_selected_shape.set_door_height(value)
	)
	height_hbox.add_child(height_spinbox)
	parent.add_child(height_hbox)

	# Door Sill
	var sill_hbox = HBoxContainer.new()
	parent.add_child(sill_hbox)
	var sill_label = Label.new()
	sill_label.text = "Sill:"
	sill_label.custom_minimum_size.x = 80
	sill_hbox.add_child(sill_label)
	var sill_spinbox = SpinBox.new()
	sill_spinbox.min_value = 0
	sill_spinbox.max_value = 200
	sill_spinbox.step = 1
	sill_spinbox.value = 0
	sill_spinbox.name = "DoorSillSpinBox"
	sill_spinbox.value_changed.connect(func(value):
		if current_selected_shape:
			current_selected_shape.set_door_sill(value)
	)
	sill_hbox.add_child(sill_spinbox)
	parent.add_child(sill_hbox)

func _create_geometry_controls(parent: VBoxContainer):
	# Grup pentru informații geometrice
	var group_label = Label.new()
	group_label.text = "📐 Geometric Info"
	group_label.add_theme_font_size_override("font_size", 14)
	parent.add_child(group_label)
	
	# Container pentru informațiile geometrice
	var geom_vbox = VBoxContainer.new()
	
	# Aria exterioară
	var area_hbox = HBoxContainer.new()
	var area_label = Label.new()
	area_label.text = "Area:"
	area_label.custom_minimum_size.x = 80
	area_hbox.add_child(area_label)
	var area_value_label = Label.new()
	area_value_label.name = "AreaValueLabel"
	area_value_label.text = "0 m²"
	area_hbox.add_child(area_value_label)
	geom_vbox.add_child(area_hbox)
	
	# Perimetrul
	var perimeter_hbox = HBoxContainer.new()
	var perimeter_label = Label.new()
	perimeter_label.text = "Perimeter:"
	perimeter_label.custom_minimum_size.x = 80
	perimeter_hbox.add_child(perimeter_label)
	var perimeter_value_label = Label.new()
	perimeter_value_label.name = "PerimeterValueLabel"
	perimeter_value_label.text = "0 m"
	perimeter_hbox.add_child(perimeter_value_label)
	geom_vbox.add_child(perimeter_hbox)
	
	# Aria camerei (perimetru * înălțime - ferestre/uși)
	var room_area_hbox = HBoxContainer.new()
	var room_area_label = Label.new()
	room_area_label.text = "Room Area:"
	room_area_label.custom_minimum_size.x = 80
	room_area_hbox.add_child(room_area_label)
	var room_area_value_label = Label.new()
	room_area_value_label.name = "RoomAreaValueLabel"
	room_area_value_label.text = "0 m²"
	room_area_hbox.add_child(room_area_value_label)
	geom_vbox.add_child(room_area_hbox)
	
	# Aria ferestrelor (dacă există)
	var window_area_hbox = HBoxContainer.new()
	var window_area_label = Label.new()
	window_area_label.text = "Windows:"
	window_area_label.custom_minimum_size.x = 80
	window_area_hbox.add_child(window_area_label)
	var window_area_value_label = Label.new()
	window_area_value_label.name = "WindowAreaValueLabel"
	window_area_value_label.text = "0 m²"
	window_area_hbox.add_child(window_area_value_label)
	geom_vbox.add_child(window_area_hbox)
	
	# Aria ușilor (dacă există)
	var door_area_hbox = HBoxContainer.new()
	var door_area_label = Label.new()
	door_area_label.text = "Doors:"
	door_area_label.custom_minimum_size.x = 80
	door_area_hbox.add_child(door_area_label)
	var door_area_value_label = Label.new()
	door_area_value_label.name = "DoorAreaValueLabel"
	door_area_value_label.text = "0 m²"
	door_area_hbox.add_child(door_area_value_label)
	geom_vbox.add_child(door_area_hbox)
	
	# Buton pentru refresh calculul
	var refresh_button = Button.new()
	refresh_button.text = "♻️ Update Geometry"
	refresh_button.pressed.connect(_on_refresh_geometry_pressed)
	geom_vbox.add_child(refresh_button)
	
	# Separator
	geom_vbox.add_child(HSeparator.new())
	
	# Buton pentru ștergerea shape-ului
	var delete_button = Button.new()
	delete_button.text = "🗑️ Delete Shape"
	delete_button.modulate = Color.LIGHT_CORAL  # Culoare roșiatică
	delete_button.pressed.connect(_delete_selected_shape)
	geom_vbox.add_child(delete_button)
	
	parent.add_child(geom_vbox)

# Callbacks pentru setteri
func set_move_mode_enabled(value: bool):
	move_mode_enabled = value

func set_shape_count(value: int):
	if value != shape_count:
		shape_count = max(1, value)
		if is_inside_tree():
			_update_shape_count()

func _update_shape_count():
	# Ajustează numărul de forme
	while shapes.size() < shape_count:
		_add_new_shape(Vector2(100 + shapes.size() * 150, 100))
	
	while shapes.size() > shape_count:
		var shape_to_remove = shapes.pop_back()
		shape_to_remove.queue_free()

# Callbacks pentru UI
func _on_move_mode_toggled(pressed: bool):
	move_mode_enabled = pressed

func _on_add_shape_pressed():
	var new_pos = Vector2(100 + shapes.size() * 150, 100)
	var new_shape = _add_new_shape(new_pos)
	_select_shape(new_shape)

func _on_shape_selected(shape: TetrisShape2D):
	print("🔸 DEBUG: Shape selectat - ID: ", shape.unique_id)
	print("🔸 DEBUG: Proprietăți shape din to_dict():")
	var shape_dict = shape.to_dict()
	for key in shape_dict.keys():
		print("  ", key, " = ", shape_dict[key])
	
	_select_shape(shape)
	if ui_panel:
		ui_panel.visible = true
	# Actualizează dicționarul cu proprietățile curente ale shape-ului
	shape_properties[shape.unique_id] = shape.to_dict()
	print("🔸 DEBUG: Dicționar actualizat pentru ID ", shape.unique_id)
	_update_ui_for_selected_shape()

func _on_shape_changed():
	# Actualizează dicționarul când se schimbă forma
	if current_selected_shape:
		shape_properties[current_selected_shape.unique_id] = current_selected_shape.to_dict()
		_update_geometry_display()  # Actualizează și afișajul geometric
		_save_shapes_to_json()  # Salvează schimbările
		print("📝 DEBUG: Dicționar actualizat pentru shape ID: ", current_selected_shape.unique_id)

func _update_ui_for_selected_shape():
	if not current_selected_shape or not ui_panel:
		print("❌ DEBUG: Nu pot actualiza UI - current_selected_shape sau ui_panel lipsa")
		return
	
	print("🔧 DEBUG: Actualizez UI pentru shape ID: ", current_selected_shape.unique_id)
	print("🔧 DEBUG: ui_panel este de tip: ", ui_panel.get_class())
	print("🔧 DEBUG: ui_panel are ", ui_panel.get_child_count(), " copii")
	
	# Debug: listează toți copiii UI panel-ului
	print("🔧 DEBUG: Copiii ui_panel:")
	_debug_print_children(ui_panel, 0)
	
	# Setează flag-ul pentru a preveni callback-urile
	is_updating_ui = true
	
	# Citește proprietățile din dicționar JSON
	var props = shape_properties.get(current_selected_shape.unique_id, {})
	
	# Extrage sub-dicționarele pentru window și door
	var window_props = props.get("window", {})
	var door_props = props.get("door", {})
	
	print("🔧 DEBUG: Proprietăți citite din dicționar:")
	print("  Main properties: ", props.keys())
	print("  Window properties: ", window_props.keys())
	print("  Door properties: ", door_props.keys())
	
	# Room Name și Central Color - folosește referințe directe
	if ui_room_name:
		var room_name_val = props.get("room_name", "Room")
		ui_room_name.text = room_name_val
		print("🔧 DEBUG: Setez Room Name = ", room_name_val)
	else:
		print("❌ DEBUG: ui_room_name este null")
	
	if ui_central_color:
		var color_val = props.get("central_color", Color.LIGHT_GRAY)
		ui_central_color.color = color_val
		print("🔧 DEBUG: Setez Central Color = ", color_val)
	else:
		print("❌ DEBUG: ui_central_color este null")
	
	# Dimensiuni - folosește referințe directe
	if ui_width:
		var width_val = props.get("shape_size", Vector2(300, 300)).x
		ui_width.value = width_val
		print("🔧 DEBUG: Setez Width = ", width_val)
	else:
		print("❌ DEBUG: ui_width este null")
	if ui_length:
		var length_val = props.get("shape_size", Vector2(300, 300)).y
		ui_length.value = length_val
		print("🔧 DEBUG: Setez Length = ", length_val)
	else:
		print("❌ DEBUG: ui_length este null")
		
	# Window - folosește căutare recursivă
	var has_window_check = ui_panel.find_child("HasWindowCheck", true, false)
	if has_window_check:
		var has_window_val = props.get("has_window", true)
		has_window_check.button_pressed = has_window_val
		print("🔧 DEBUG: Setez Has Window = ", has_window_val)
	else:
		print("❌ DEBUG: Nu găsesc HasWindowCheck")
	
	var window_style = ui_panel.find_child("WindowStyleOption", true, false)
	if window_style:
		var styles = current_selected_shape.get_window_style_options()
		var style_val = props.get("window_style", "standard")
		var style_index = styles.find(style_val)
		window_style.selected = style_index
		print("🔧 DEBUG: Setez Window Style = ", style_val, " (index ", style_index, ")")
	else:
		print("❌ DEBUG: Nu găsesc WindowStyleOption")
		
	var window_side = _find_ui_control("WindowSideOption")
	if window_side:
		var angles = [0, 90, 180, 270]
		window_side.selected = angles.find(props.get("window_side", 0))
		print("🔧 DEBUG: Setez Window Side = ", props.get("window_side", 0))
	else:
		print("❌ DEBUG: Nu găsesc WindowSideOption")
		
	var window_offset = ui_panel.find_child("WindowOffsetSpinBox")
	if window_offset:
		window_offset.value = props.get("window_offset", 0.0)
		
	var window_n_offset = ui_panel.find_child("WindowNOffsetSpinBox")
	if window_n_offset:
		window_n_offset.value = props.get("window_n_offset", 0.0)
		
	var window_z_offset = ui_panel.find_child("WindowZOffsetSpinBox")  
	if window_z_offset:
		window_z_offset.value = props.get("window_z_offset", 0.0)
		
	var window_width = ui_panel.find_child("WindowWidthSpinBox")
	if window_width:
		# Citește din sub-dicționar window sau format vechi
		var width_val = window_props.get("width", props.get("window_width", 45.0))
		window_width.value = width_val
		
	var window_length = ui_panel.find_child("WindowLengthSpinBox")
	if window_length:
		var length_val = window_props.get("length", props.get("window_length", 120.0))
		window_length.value = length_val
		
	var window_height = ui_panel.find_child("WindowHeightPropertySpinBox")
	if window_height:
		# Citește height din sub-dicționarul window
		var height_val = window_props.get("height", props.get("window_height", 0.0))
		window_height.value = height_val
		
	var window_sill = ui_panel.find_child("WindowSillSpinBox")
	if window_sill:
		# Citește sill din sub-dicționarul window
		var sill_val = window_props.get("sill", props.get("window_sill", 0.0))
		window_sill.value = sill_val
		
	# Door - citește din sub-dicționarul door cu compatibilitate pentru formatul vechi
	var has_door_check = ui_panel.find_child("HasDoorCheck")
	if has_door_check:
		var has_door_val = door_props.get("has_door", props.get("has_door", true))
		has_door_check.button_pressed = has_door_val
		
	var door_style = ui_panel.find_child("DoorStyleOption")
	if door_style:
		var styles = current_selected_shape.get_door_style_options()
		var style_val = door_props.get("style", props.get("door_style", "standard"))
		door_style.selected = styles.find(style_val)
		
	var door_side = ui_panel.find_child("DoorSideOption")
	if door_side:
		var angles = [0, 90, 180, 270]
		var side_val = door_props.get("side", props.get("door_side", 90))
		door_side.selected = angles.find(side_val)
		
	var door_offset = ui_panel.find_child("DoorOffsetSpinBox")
	if door_offset:
		var offset_val = door_props.get("offset", props.get("door_offset", 0.0))
		door_offset.value = offset_val
		
	var door_n_offset = ui_panel.find_child("DoorNOffsetSpinBox")
	if door_n_offset:
		var n_offset_val = door_props.get("n_offset", props.get("door_n_offset", 0.0))
		door_n_offset.value = n_offset_val
		
	var door_z_offset = ui_panel.find_child("DoorZOffsetSpinBox")
	if door_z_offset:
		var z_offset_val = door_props.get("z_offset", props.get("door_z_offset", 0.0))
		door_z_offset.value = z_offset_val
		
	var door_width = ui_panel.find_child("DoorWidthSpinBox")
	if door_width:
		var width_val = door_props.get("width", props.get("door_width", 45.0))
		door_width.value = width_val
		
	var door_length = ui_panel.find_child("DoorLengthSpinBox")
	if door_length:
		var length_val = door_props.get("length", props.get("door_length", 90.0))
		door_length.value = length_val
		
	var door_height = ui_panel.find_child("DoorHeightPropertySpinBox")
	if door_height:
		# Citește height din sub-dicționarul door
		var height_val = door_props.get("height", props.get("door_height", 0.0))
		door_height.value = height_val
		
	var door_sill = _find_ui_control("DoorSillSpinBox")
	if door_sill:
		# Citește sill din sub-dicționarul door
		var door_sill_val = door_props.get("sill", props.get("door_sill", 0.0))
		door_sill.value = door_sill_val
		print("🔧 DEBUG: Setez Door Sill = ", door_sill_val)
	else:
		print("❌ DEBUG: Nu găsesc DoorSillSpinBox")
	
	# Resetează flag-ul după actualizarea UI-ului
	is_updating_ui = false
	# Actualizează informațiile geometrice
	_update_geometry_display()
	
	print("✅ DEBUG: UI actualizat complet pentru shape ID: ", current_selected_shape.unique_id)

func _debug_print_children(node: Node, indent_level: int):
	var indent = ""
	for i in range(indent_level):
		indent += "  "
	
	print(indent, "- ", node.get_class(), " (name: '", node.name, "')")
	
	for child in node.get_children():
		_debug_print_children(child, indent_level + 1)

func _find_ui_control(name: String) -> Node:
	"""Helper function pentru găsirea controalelor UI cu căutare recursivă"""
	if not ui_panel:
		return null
	return ui_panel.find_child(name, true, false)

func _update_geometry_display():
	if not current_selected_shape or not ui_panel:
		return
		
	var geom_info = current_selected_shape.get_geometry_info()
	
	var area_label = _find_ui_control("AreaValueLabel")
	if area_label:
		area_label.text = "%.1f %s" % [geom_info.exterior_area, geom_info.area_unit]
		
	var perimeter_label = _find_ui_control("PerimeterValueLabel")  
	if perimeter_label:
		perimeter_label.text = "%.1f %s" % [geom_info.exterior_perimeter, geom_info.perimeter_unit]
		
	var room_area_label = _find_ui_control("RoomAreaValueLabel")
	if room_area_label:
		room_area_label.text = "%.1f %s" % [geom_info.room_area, geom_info.area_unit]
	
	# Afișează ariile ferestrelor și ușilor dacă există
	if geom_info.has("window_area") and geom_info.window_area > 0:
		var window_area_label = _find_ui_control("WindowAreaValueLabel")
		if window_area_label:
			window_area_label.text = "%.1f %s" % [geom_info.window_area, geom_info.area_unit]
	
	if geom_info.has("door_area") and geom_info.door_area > 0:
		var door_area_label = _find_ui_control("DoorAreaValueLabel")
		if door_area_label:
			door_area_label.text = "%.1f %s" % [geom_info.door_area, geom_info.area_unit]

func _on_refresh_geometry_pressed():
	if current_selected_shape:
		_update_geometry_display()
		print("📐 Geometrie actualizată pentru shape ID: ", current_selected_shape.unique_id)

func _delete_selected_shape():
	if not current_selected_shape:
		print("⚠️ Niciun shape selectat pentru ștergere")
		return
	
	# Protecție: nu șterge ultimul shape
	if shapes.size() <= 1:
		print("⚠️ Nu pot șterge ultimul shape! Trebuie să rămână cel puțin unul.")
		return
	
	var shape_to_delete = current_selected_shape
	var shape_id = shape_to_delete.unique_id
	
	print("🗑️ Șterg shape ID: ", shape_id)
	
	# Elimină shape-ul din array-ul shapes
	var shape_index = shapes.find(shape_to_delete)
	if shape_index != -1:
		shapes.erase(shape_to_delete)
		print("✅ Shape eliminat din array la indexul: ", shape_index)
	
	# Elimină din dicționarul proprietăților
	if shape_properties.has(shape_id):
		shape_properties.erase(shape_id)
		print("✅ Proprietăți eliminate din dicționar pentru ID: ", shape_id)
	
	# Elimină din scena Godot
	if shape_to_delete.get_parent():
		shape_to_delete.get_parent().remove_child(shape_to_delete)
	shape_to_delete.queue_free()
	print("✅ Shape eliminat din scenă și marcat pentru ștergere")
	
	# Resetează selecția
	current_selected_shape = null
	
	# Ascunde panoul de proprietăți
	if ui_panel:
		ui_panel.visible = false
	
	# Actualizează label-ul de selecție
	var selected_label = _find_ui_control("SelectedLabel")
	if selected_label:
		selected_label.text = "No Shape Selected"
	
	# Salvează schimbările
	_save_shapes_to_json()
	
	print("🎯 Ștergere completă! Rămas cu ", shapes.size(), " shape-uri")

# Asigură apelarea _update_ui_for_selected_shape din _select_shape și _on_shape_selected
func _select_shape(shape: TetrisShape2D):
	# Deselecționează toate formele
	for s in shapes:
		s.set_selected(false)

	current_selected_shape = shape
	if shape:
		shape.set_selected(true)
		_update_ui_for_selected_shape()

	shape_selection_changed.emit(shape)

# Callbacks pentru schimbări în UI - Feronerie

func _on_window_style_changed(index: int):
	if is_updating_ui:
		return
	if current_selected_shape:
		var styles = current_selected_shape.get_window_style_options()
		if index < styles.size():
			current_selected_shape.set_window_style(styles[index])

func _on_window_side_changed(index: int):
	if current_selected_shape:
		var angles = [0, 90, 180, 270]
		if index < angles.size():
			current_selected_shape.set_window_side(angles[index])

func _on_window_offset_changed(value: float):
	if current_selected_shape:
		current_selected_shape.set_window_offset(value)

func _on_window_n_offset_changed(value: float):
	if current_selected_shape:
		current_selected_shape.set_window_n_offset(value)

func _on_window_width_changed(value: float):
	if current_selected_shape:
		current_selected_shape.set_window_width(value)

func _on_window_length_changed(value: float):
	if current_selected_shape:
		current_selected_shape.set_window_length(value)

func _on_window_height_changed(value: float):
	if current_selected_shape:
		current_selected_shape.set_window_height(value)

func _on_window_sill_changed(value: float):
	if current_selected_shape:
		current_selected_shape.set_window_sill(value)

# Callbacks pentru schimbări în UI - Uși
func _on_door_has_changed(pressed: bool):
	if is_updating_ui:
		return
	if current_selected_shape:
		current_selected_shape.set_has_door(pressed)

func _on_door_style_changed(index: int):
	if is_updating_ui:
		return
	if current_selected_shape:
		var styles = current_selected_shape.get_door_style_options()
		if index < styles.size():
			current_selected_shape.set_door_style(styles[index])

func _on_door_side_changed(index: int):
	if current_selected_shape:
		var angles = [0, 90, 180, 270]
		if index < angles.size():
			current_selected_shape.set_door_side(angles[index])

func _on_door_offset_changed(value: float):
	if current_selected_shape:
		current_selected_shape.set_door_offset(value)

func _on_door_h_offset_changed(value: float):
	if current_selected_shape:
		current_selected_shape.set_door_h_offset(value)

func _on_door_width_changed(value: float):
	if current_selected_shape:
		current_selected_shape.set_door_width(value)

func _on_door_length_changed(value: float):
	if current_selected_shape:
		current_selected_shape.set_door_length(value)

func _input(event):
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		# Verifică dacă click-ul a fost pe o formă
		var clicked_on_shape = false
		for shape in shapes:
			if shape.is_selected:
				clicked_on_shape = true
				break
		# Nu deselecta automat când apare panoul, doar dacă click-ul e clar în afara formelor și panoul nu e vizibil
		if not clicked_on_shape and not ui_panel.visible:
			_select_shape(null)
			var selected_label = ui_panel.find_child("SelectedLabel")
			if selected_label:
				selected_label.text = "No Shape Selected"
	
	# Detectează tasta Delete pentru ștergerea shape-ului selectat
	elif event is InputEventKey and event.pressed:
		if event.keycode == KEY_DELETE:
			_delete_selected_shape()

func _on_width_changed(value: float):
	if is_updating_ui:
		print("🚫 DEBUG: _on_width_changed blocat - is_updating_ui = true")
		return
	print("📝 DEBUG: _on_width_changed apelat cu value = ", value)
	if current_selected_shape:
		current_selected_shape.set_shape_size(Vector2(value, current_selected_shape.shape_size.y))
		# Actualizează dicționarul JSON
		shape_properties[current_selected_shape.unique_id] = current_selected_shape.to_dict()
		_save_shapes_to_json()

func _on_length_changed(value: float):
	if is_updating_ui:
		return
	if current_selected_shape:
		current_selected_shape.set_shape_size(Vector2(current_selected_shape.shape_size.x, value))
		# Actualizează dicționarul JSON
		shape_properties[current_selected_shape.unique_id] = current_selected_shape.to_dict()
		_save_shapes_to_json()

func _on_window_has_changed(pressed: bool):
	if is_updating_ui:
		return
	if current_selected_shape:
		current_selected_shape.set_has_window(pressed)
		# Actualizează dicționarul JSON
		shape_properties[current_selected_shape.unique_id] = current_selected_shape.to_dict()
		_save_shapes_to_json()
