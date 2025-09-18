# SnapGridPanel.gd
extends Control

signal grid_updated(x_dimensions: Array, y_dimensions: Array)
signal panel_closed

@onready var x_input: TextEdit
@onready var y_input: TextEdit
@onready var preview_label: Label

var cad_viewer: Node3D
var current_grid_nodes: Array = []

func _ready():
	_setup_ui()
	_setup_default_values()

func _setup_ui():
	# Configurare panel principal
	custom_minimum_size = Vector2(400, 500)
	add_theme_color_override("bg_color", Color(0.2, 0.2, 0.2, 0.95))
	
	# Container principal
	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 10)
	add_child(vbox)
	
	# Titlu
	var title = Label.new()
	title.text = "Snap Grid Generator"
	title.add_theme_font_size_override("font_size", 18)
	title.add_theme_color_override("font_color", Color.WHITE)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(title)
	
	# Separator
	var separator1 = HSeparator.new()
	vbox.add_child(separator1)
	
	# X Dimensions
	var x_container = _create_dimension_input("X Dimensions (comma separated):", "x_input")
	vbox.add_child(x_container)
	
	# Y Dimensions  
	var y_container = _create_dimension_input("Y Dimensions (comma separated):", "y_input")
	vbox.add_child(y_container)
	
	# Preview section
	var preview_container = VBoxContainer.new()
	vbox.add_child(preview_container)
	
	var preview_title = Label.new()
	preview_title.text = "Grid Preview:"
	preview_title.add_theme_color_override("font_color", Color.WHITE)
	preview_container.add_child(preview_title)
	
	preview_label = Label.new()
	preview_label.add_theme_color_override("font_color", Color.YELLOW)
	preview_label.add_theme_font_size_override("font_size", 10)
	preview_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	preview_container.add_child(preview_label)
	
	# Separator
	var separator2 = HSeparator.new()
	vbox.add_child(separator2)
	
	# Buttons
	var button_container = HBoxContainer.new()
	button_container.add_theme_constant_override("separation", 10)
	vbox.add_child(button_container)
	
	var update_btn = Button.new()
	update_btn.text = "Update Grid"
	update_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	update_btn.pressed.connect(_on_update_pressed)
	button_container.add_child(update_btn)
	
	var clear_btn = Button.new()
	clear_btn.text = "Clear Grid"
	clear_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	clear_btn.pressed.connect(_on_clear_pressed)
	button_container.add_child(clear_btn)
	
	var close_btn = Button.new()
	close_btn.text = "Close"
	close_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	close_btn.pressed.connect(_on_close_pressed)
	button_container.add_child(close_btn)
	
	# Auto-update când se schimbă textul
	x_input.text_changed.connect(_on_text_changed)
	y_input.text_changed.connect(_on_text_changed)

func _create_dimension_input(label_text: String, input_name: String) -> VBoxContainer:
	var container = VBoxContainer.new()
	
	var label = Label.new()
	label.text = label_text
	label.add_theme_color_override("font_color", Color.WHITE)
	container.add_child(label)
	
	var text_edit = TextEdit.new()
	text_edit.custom_minimum_size = Vector2(0, 80)
	text_edit.placeholder_text = "Ex: 0.0, 1.5, 3.0, 4.5, 6.0"
	text_edit.name = input_name
	container.add_child(text_edit)
	
	# Asignare referințe
	if input_name == "x_input":
		x_input = text_edit
	elif input_name == "y_input":
		y_input = text_edit
		
	return container

func _setup_default_values():
	x_input.text = "0.0, 3.0, 6.0, 9.0"
	y_input.text = "0.0, 2.5, 5.0, 7.5"
	_update_preview()

func set_cad_viewer(viewer: Node3D):
	cad_viewer = viewer

func _on_text_changed():
	_update_preview()

func _update_preview():
	var x_dims = _parse_dimensions(x_input.text)
	var y_dims = _parse_dimensions(y_input.text)
	
	var preview_text = "Grid Points: %d x %d = %d points\n" % [x_dims.size(), y_dims.size(), x_dims.size() * y_dims.size()]
	preview_text += "X Range: %.2f to %.2f\n" % [x_dims.min(), x_dims.max()] if x_dims.size() > 0 else "X: Invalid\n"
	preview_text += "Y Range: %.2f to %.2f" % [y_dims.min(), y_dims.max()] if y_dims.size() > 0 else "Y: Invalid"
	
	preview_label.text = preview_text

func _parse_dimensions(text: String) -> Array[float]:
	var dimensions: Array[float] = []
	var parts = text.split(",")
	
	for part in parts:
		var trimmed = part.strip_edges()
		if trimmed.length() > 0:
			var value = trimmed.to_float()
			dimensions.append(value)
	
	return dimensions

func _on_update_pressed():
	var x_dims = _parse_dimensions(x_input.text)
	var y_dims = _parse_dimensions(y_input.text)
	
	if x_dims.size() == 0 or y_dims.size() == 0:
		_show_error("Invalid dimensions! Please enter valid float numbers separated by commas.")
		return
	
	_generate_snap_grid(x_dims, y_dims)
	grid_updated.emit(x_dims, y_dims)

func _on_clear_pressed():
	_clear_current_grid()

func _on_close_pressed():
	panel_closed.emit()
	queue_free()

func _show_error(message: String):
	# Creează un popup simplu pentru erori
	var popup = AcceptDialog.new()
	popup.dialog_text = message
	popup.title = "Error"
	get_tree().root.add_child(popup)
	popup.popup_centered()
	popup.confirmed.connect(popup.queue_free)

func _generate_snap_grid(x_dimensions: Array[float], y_dimensions: Array[float]):
	if not cad_viewer:
		print("No CAD viewer reference!")
		return
		
	_clear_current_grid()
	
	# Obține cota Z de la viewer
	var drawing_z = 0.0
	if cad_viewer.has_method("get_drawing_plane_z"):
		drawing_z = cad_viewer.get_drawing_plane_z()
	elif "drawing_plane_z" in cad_viewer:
		drawing_z = cad_viewer.drawing_plane_z
	
	# Generează punctele snapable
	for x in x_dimensions:
		for y in y_dimensions:
			var point_pos = Vector3(x, y, drawing_z)
			_create_snap_point(point_pos)

func _create_snap_point(position: Vector3):
	# Creează un marker vizual mic pentru punctul snap
	var marker = MeshInstance3D.new()
	var sphere = SphereMesh.new()
	sphere.radius = 0.05
	sphere.radial_segments = 8
	sphere.rings = 4
	marker.mesh = sphere
	
	# Material pentru punctele snap
	var material = StandardMaterial3D.new()
	material.albedo_color = Color.CYAN
	material.emission_enabled = true
	material.emission = Color.CYAN * 0.3
	material.flags_unshaded = true
	marker.material_override = material
	
	marker.transform.origin = position
	marker.name = "SnapPoint_%.2f_%.2f" % [position.x, position.y]
	
	cad_viewer.add_child(marker)
	current_grid_nodes.append(marker)

func _clear_current_grid():
	for node in current_grid_nodes:
		if is_instance_valid(node):
			node.queue_free()
	current_grid_nodes.clear()

# Funcție pentru verificarea snap-ului
func get_snap_point_at(world_pos: Vector3, snap_distance: float = 0.5) -> Vector3:
	var closest_point = world_pos
	var min_distance = snap_distance
	
	for node in current_grid_nodes:
		if is_instance_valid(node):
			var distance = world_pos.distance_to(node.transform.origin)
			if distance < min_distance:
				min_distance = distance
				closest_point = node.transform.origin
	
	return closest_point

func has_snap_points() -> bool:
	return current_grid_nodes.size() > 0
