extends RefCounted
class_name UIHelper

# Utilități pentru crearea și managementul elementelor UI

static func create_labeled_spinbox(parent: Control, label_text: String, min_val: float, max_val: float, step_val: float, default_val: float, callback: Callable = Callable()) -> SpinBox:
	"""Creează un SpinBox cu etichetă"""
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
	
	if callback.is_valid():
		spinbox.value_changed.connect(callback)
	
	container.add_child(spinbox)
	return spinbox

static func create_labeled_option_button(parent: Control, label_text: String, options: Array[String], callback: Callable = Callable()) -> OptionButton:
	"""Creează un OptionButton cu etichetă"""
	var container = HBoxContainer.new()
	parent.add_child(container)
	
	var label = Label.new()
	label.text = label_text
	label.custom_minimum_size.x = 80
	container.add_child(label)
	
	var option_button = OptionButton.new()
	for option in options:
		option_button.add_item(option)
	
	if callback.is_valid():
		option_button.item_selected.connect(callback)
	
	container.add_child(option_button)
	return option_button

static func create_labeled_checkbox(parent: Control, label_text: String, default_checked: bool = false, callback: Callable = Callable()) -> CheckBox:
	"""Creează un CheckBox cu etichetă"""
	var checkbox = CheckBox.new()
	checkbox.text = label_text
	checkbox.button_pressed = default_checked
	
	if callback.is_valid():
		checkbox.toggled.connect(callback)
	
	parent.add_child(checkbox)
	return checkbox

static func create_section_header(parent: Control, header_text: String, font_size: int = 14):
	"""Creează un header de secțiune"""
	var label = Label.new()
	label.text = header_text
	label.add_theme_font_size_override("font_size", font_size)
	parent.add_child(label)
	
	var separator = HSeparator.new()
	parent.add_child(separator)

static func create_info_display(parent: Control, title: String, content: String = "", min_height: float = 100.0) -> RichTextLabel:
	"""Creează un display pentru informații"""
	var group_label = Label.new()
	group_label.text = title
	group_label.add_theme_font_size_override("font_size", 14)
	parent.add_child(group_label)
	
	var text_display = RichTextLabel.new()
	text_display.custom_minimum_size.y = min_height
	text_display.bbcode_enabled = true
	text_display.text = content
	parent.add_child(text_display)
	
	return text_display

static func create_button_row(parent: Control, buttons_data: Array[Dictionary]) -> Array[Button]:
	"""Creează o linie de butoane
	buttons_data format: [{"text": "Button Text", "callback": callable}, ...]
	"""
	var container = HBoxContainer.new()
	parent.add_child(container)
	
	var created_buttons: Array[Button] = []
	
	for button_data in buttons_data:
		var button = Button.new()
		button.text = button_data.get("text", "Button")
		
		if button_data.has("callback") and button_data.callback is Callable:
			button.pressed.connect(button_data.callback)
		
		container.add_child(button)
		created_buttons.append(button)
	
	return created_buttons

static func create_color_picker_labeled(parent: Control, label_text: String, default_color: Color = Color.WHITE, callback: Callable = Callable()) -> ColorPickerButton:
	"""Creează un ColorPickerButton cu etichetă"""
	var container = HBoxContainer.new()
	parent.add_child(container)
	
	var label = Label.new()
	label.text = label_text
	label.custom_minimum_size.x = 80
	container.add_child(label)
	
	var color_picker = ColorPickerButton.new()
	color_picker.color = default_color
	
	if callback.is_valid():
		color_picker.color_changed.connect(callback)
	
	container.add_child(color_picker)
	return color_picker

static func create_line_edit_labeled(parent: Control, label_text: String, default_text: String = "", callback: Callable = Callable()) -> LineEdit:
	"""Creează un LineEdit cu etichetă"""
	var container = HBoxContainer.new()
	parent.add_child(container)
	
	var label = Label.new()
	label.text = label_text
	label.custom_minimum_size.x = 80
	container.add_child(label)
	
	var line_edit = LineEdit.new()
	line_edit.text = default_text
	
	if callback.is_valid():
		line_edit.text_changed.connect(callback)
	
	container.add_child(line_edit)
	return line_edit

static func apply_dark_theme(control: Control):
	"""Aplică o temă întunecată unui control"""
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.15, 0.15, 0.15, 0.95)
	style.set_border_width_all(1)
	style.border_color = Color(0.3, 0.3, 0.3)
	style.set_corner_radius_all(4)
	
	control.add_theme_stylebox_override("panel", style)

static func format_validation_text(validation_result: Dictionary) -> String:
	"""Formatează rezultatele validării pentru afișare"""
	var text = ""
	
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
	
	return text

static func format_geometry_text(geometry_info: Dictionary) -> String:
	"""Formatează informațiile geometrice pentru afișare"""
	var text = "[b]Geometry Information:[/b]\n"
	
	if geometry_info.has("exterior_area"):
		text += "• Exterior Area: %.2f %s\n" % [geometry_info.exterior_area, geometry_info.get("area_unit", "units²")]
	
	if geometry_info.has("interior_area"):
		text += "• Interior Area: %.2f %s\n" % [geometry_info.interior_area, geometry_info.get("area_unit", "units²")]
		
		if geometry_info.has("exterior_area"):
			var wall_area = geometry_info.exterior_area - geometry_info.interior_area
			text += "• Wall Area: %.2f %s\n" % [wall_area, geometry_info.get("area_unit", "units²")]
	
	if geometry_info.has("exterior_perimeter"):
		text += "• Perimeter: %.2f %s\n" % [geometry_info.exterior_perimeter, geometry_info.get("perimeter_unit", "units")]
	
	if geometry_info.has("room_area"):
		text += "• Room Surface: %.2f %s\n" % [geometry_info.room_area, geometry_info.get("area_unit", "units²")]
	
	if geometry_info.has("window_area"):
		text += "• Window Area: %.2f %s\n" % [geometry_info.window_area, geometry_info.get("area_unit", "units²")]
	
	if geometry_info.has("door_area"):
		text += "• Door Area: %.2f %s\n" % [geometry_info.door_area, geometry_info.get("area_unit", "units²")]
	
	return text

static func create_collapsible_section(parent: Control, title: String, content_container_class = VBoxContainer) -> Dictionary:
	"""Creează o secțiune pliabilă
	Returns: {"header": Button, "container": Container, "content": Container}
	"""
	var header_button = Button.new()
	header_button.text = "▼ " + title
	header_button.flat = true
	header_button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	parent.add_child(header_button)
	
	var content_container = content_container_class.new()
	parent.add_child(content_container)
	
	var is_collapsed = false
	
	var toggle_collapse = func():
		is_collapsed = !is_collapsed
		content_container.visible = !is_collapsed
		header_button.text = ("▶ " if is_collapsed else "▼ ") + title
	
	header_button.pressed.connect(toggle_collapse)
	
	return {
		"header": header_button,
		"container": content_container,
		"content": content_container,
		"toggle": toggle_collapse
	}

static func show_tooltip(control: Control, text: String):
	"""Afișează un tooltip pentru un control"""
	control.tooltip_text = text

static func animate_control_highlight(control: Control, duration: float = 0.5):
	"""Animează evidențierea unui control"""
	var tween = control.create_tween()
	var original_modulate = control.modulate
	
	tween.tween_property(control, "modulate", Color.YELLOW, duration * 0.5)
	tween.tween_property(control, "modulate", original_modulate, duration * 0.5)

static func create_progress_bar(parent: Control, label_text: String = "") -> Dictionary:
	"""Creează o bară de progres cu etichetă opțională
	Returns: {"label": Label, "progress": ProgressBar}
	"""
	var result = {"label": null, "progress": null}
	
	if label_text != "":
		var label = Label.new()
		label.text = label_text
		parent.add_child(label)
		result.label = label
	
	var progress_bar = ProgressBar.new()
	progress_bar.min_value = 0
	progress_bar.max_value = 100
	progress_bar.value = 0
	parent.add_child(progress_bar)
	result.progress = progress_bar
	
	return result

static func batch_set_minimum_size(controls: Array, size: Vector2):
	"""Setează dimensiunea minimă pentru o listă de controale"""
	for control in controls:
		if control is Control:
			control.custom_minimum_size = size

static func find_control_by_name(parent: Control, name: String) -> Control:
	"""Găsește un control după nume în ierarhia de copii"""
	if parent.name == name:
		return parent
	
	for child in parent.get_children():
		if child is Control:
			var found = find_control_by_name(child, name)
			if found:
				return found
	
	return null
