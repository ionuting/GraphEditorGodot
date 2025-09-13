# WindowPropertiesPanel.gd
# Dedicated properties panel for Window objects
class_name WindowPropertiesPanel

extends Panel

signal properties_applied(properties: Dictionary)

var length_spin: SpinBox
var width_spin: SpinBox
var insert_offset_spin: SpinBox
var translation_x_spin: SpinBox
var rotation_spin: SpinBox
var sill_spin: SpinBox
var cut_priority_spin: SpinBox
var name_line: LineEdit
var material_line: LineEdit


func _init():
	size = Vector2(320, 380)
	position = Vector2(60, 150)
	var style_box = StyleBoxFlat.new()
	style_box.bg_color = Color(0.15, 0.15, 0.15, 0.95)
	add_theme_stylebox_override("panel", style_box)
	_create_ui()

func _create_ui():
	var vb = VBoxContainer.new()
	vb.custom_minimum_size = Vector2(300,360)
	add_child(vb)

	var title = Label.new()
	title.text = "Window Properties"
	title.add_theme_font_size_override("font_size", 16)
	title.add_theme_color_override("font_color", Color.WHITE)
	vb.add_child(title)

	vb.add_child(HSeparator.new())

	# length
	var l_h = HBoxContainer.new()
	vb.add_child(l_h)
	var l_lbl = Label.new()
	l_lbl.text = "Length:"
	l_lbl.custom_minimum_size.x = 100
	l_lbl.add_theme_color_override("font_color", Color.WHITE)
	l_h.add_child(l_lbl)
	length_spin = SpinBox.new()
	length_spin.min_value = 0.01
	length_spin.max_value = 1000.0
	length_spin.step = 0.01
	length_spin.value = 1.2
	l_h.add_child(length_spin)

	# width
	var w_h = HBoxContainer.new()
	vb.add_child(w_h)
	var w_lbl = Label.new()
	w_lbl.text = "Width:"
	w_lbl.custom_minimum_size.x = 100
	w_lbl.add_theme_color_override("font_color", Color.WHITE)
	w_h.add_child(w_lbl)
	width_spin = SpinBox.new()
	width_spin.min_value = 0.01
	width_spin.max_value = 1000.0
	width_spin.step = 0.01
	width_spin.value = 0.25
	w_h.add_child(width_spin)

	# insert offset
	var io_h = HBoxContainer.new()
	vb.add_child(io_h)
	var io_lbl = Label.new()
	io_lbl.text = "Insert Offset:"
	io_lbl.custom_minimum_size.x = 100
	io_lbl.add_theme_color_override("font_color", Color.WHITE)
	io_h.add_child(io_lbl)
	insert_offset_spin = SpinBox.new()
	insert_offset_spin.min_value = -100.0
	insert_offset_spin.max_value = 100.0
	insert_offset_spin.step = 0.001
	insert_offset_spin.value = 1.25
	io_h.add_child(insert_offset_spin)

	# translation_x
	var tx_h = HBoxContainer.new()
	vb.add_child(tx_h)
	var tx_lbl = Label.new()
	tx_lbl.text = "Translation X:"
	tx_lbl.custom_minimum_size.x = 100
	tx_lbl.add_theme_color_override("font_color", Color.WHITE)
	tx_h.add_child(tx_lbl)
	translation_x_spin = SpinBox.new()
	translation_x_spin.min_value = -10000.0
	translation_x_spin.max_value = 10000.0
	translation_x_spin.step = 0.001
	translation_x_spin.value = 0.0
	tx_h.add_child(translation_x_spin)

	# rotation
	var r_h = HBoxContainer.new()
	vb.add_child(r_h)
	var r_lbl = Label.new()
	r_lbl.text = "Rotation (deg):"
	r_lbl.custom_minimum_size.x = 100
	r_lbl.add_theme_color_override("font_color", Color.WHITE)
	r_h.add_child(r_lbl)
	rotation_spin = SpinBox.new()
	rotation_spin.min_value = -360.0
	rotation_spin.max_value = 360.0
	rotation_spin.step = 0.1
	rotation_spin.value = 0.0
	r_h.add_child(rotation_spin)

	# sill
	var s_h = HBoxContainer.new()
	vb.add_child(s_h)
	var s_lbl = Label.new()
	s_lbl.text = "Sill:"
	s_lbl.custom_minimum_size.x = 100
	s_lbl.add_theme_color_override("font_color", Color.WHITE)
	s_h.add_child(s_lbl)
	sill_spin = SpinBox.new()
	sill_spin.min_value = 0.0
	sill_spin.max_value = 1000.0
	sill_spin.step = 0.001
	sill_spin.value = 0.90
	s_h.add_child(sill_spin)

	# cut priority
	var cp_h = HBoxContainer.new()
	vb.add_child(cp_h)
	var cp_lbl = Label.new()
	cp_lbl.text = "Cut Priority:"
	cp_lbl.custom_minimum_size.x = 100
	cp_lbl.add_theme_color_override("font_color", Color.WHITE)
	cp_h.add_child(cp_lbl)
	cut_priority_spin = SpinBox.new()
	cut_priority_spin.min_value = -100
	cut_priority_spin.max_value = 100
	cut_priority_spin.step = 1
	cut_priority_spin.value = 10
	cp_h.add_child(cut_priority_spin)

	# name
	var n_h = HBoxContainer.new()
	vb.add_child(n_h)
	var n_lbl = Label.new()
	n_lbl.text = "Name:"
	n_lbl.custom_minimum_size.x = 100
	n_lbl.add_theme_color_override("font_color", Color.WHITE)
	n_h.add_child(n_lbl)
	name_line = LineEdit.new()
	name_line.text = "Window"
	n_h.add_child(name_line)

	# material
	var m_h = HBoxContainer.new()
	vb.add_child(m_h)
	var m_lbl = Label.new()
	m_lbl.text = "Material:"
	m_lbl.custom_minimum_size.x = 100
	m_lbl.add_theme_color_override("font_color", Color.WHITE)
	m_h.add_child(m_lbl)
	material_line = LineEdit.new()
	material_line.text = ""
	m_h.add_child(material_line)

	# is exterior
	var ex_h = HBoxContainer.new()
	vb.add_child(ex_h)
	var ex_lbl = Label.new()
	ex_lbl.text = "Is Exterior:"
	ex_lbl.custom_minimum_size.x = 100
	ex_lbl.add_theme_color_override("font_color", Color.WHITE)
	ex_h.add_child(ex_lbl)



	vb.add_child(HSeparator.new())

	var btn_h = HBoxContainer.new()
	vb.add_child(btn_h)
	var save_btn = Button.new()
	save_btn.text = "Save"
	save_btn.pressed.connect(_on_save_pressed)
	btn_h.add_child(save_btn)
	var close_btn = Button.new()
	close_btn.text = "Close"
	close_btn.pressed.connect(_on_close_pressed)
	btn_h.add_child(close_btn)

func _on_close_pressed():
	visible = false

func _on_save_pressed():
	var props = {
		"length": length_spin.value,
		"width": width_spin.value,
		"insert_offset": insert_offset_spin.value,
		"translation_x": translation_x_spin.value,
		"rotation_deg": rotation_spin.value,
		"sill": sill_spin.value,
		"cut_priority": int(cut_priority_spin.value),
		"name": name_line.text,
		"material": material_line.text,

		"type": "Window"
	}
	emit_signal("properties_applied", props)

func set_window_properties(w):
	if not w:
		return
	length_spin.value = w.length
	width_spin.value = w.width
	insert_offset_spin.value = w.insert_offset
	translation_x_spin.value = w.translation_x
	rotation_spin.value = w.rotation_deg
	sill_spin.value = w.sill
	cut_priority_spin.value = int(w.cut_priority)
	name_line.text = w.name
	material_line.text = w.material
