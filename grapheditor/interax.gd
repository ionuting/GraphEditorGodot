extends Node2D

var obj_name = "Interax"
var type = "Process"
var id = 0
var is_selected_for_connection = false
var distances = [[0.0, 4.5, 6.5, 10.0], [1.0]]  # [x_distances, y_distances]
var is_dragging = false
var drag_start_pos = Vector2.ZERO

signal circle_selected_for_connection(node)
signal circle_selected_for_properties(node)
signal execute_pressed(node)
signal close_pressed(node)

# Table popup runtime state
var _table_popup: PopupPanel = null
var _table_rows := [] # array of dictionaries {no_label, x_edit, y_edit, z_edit}

func _ready():
	# Verifică nodurile necesare
	if not has_node("ExecuteButton"):
		push_error("ExecuteButton nu a fost găsit în Interax!")
		return
	if not has_node("XDistancesEdit") or not has_node("YDistancesEdit"):
		push_error("XDistancesEdit sau YDistancesEdit nu a fost găsit în Interax!")
		return
	# Conectează semnalele
	$ExecuteButton.pressed.connect(_on_execute_pressed)
	# parse on text submit so partial typing doesn't get reset mid-edit
	if $XDistancesEdit.has_method("text_submitted"):
		$XDistancesEdit.text_submitted.connect(_on_x_distances_changed)
	else:
		$XDistancesEdit.text_changed.connect(_on_x_distances_changed)
	if $YDistancesEdit.has_method("text_submitted"):
		$YDistancesEdit.text_submitted.connect(_on_y_distances_changed)
	else:
		$YDistancesEdit.text_changed.connect(_on_y_distances_changed)
	if has_node("CloseButton"):
		$CloseButton.pressed.connect(_on_close_pressed)
	# Setează Mouse Filter și Editable
	if has_node("Background"):
		$Background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if has_node("XLabel"):
		$XLabel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if has_node("YLabel"):
		$YLabel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if has_node("XDistancesEdit"):
		$XDistancesEdit.mouse_filter = Control.MOUSE_FILTER_STOP
		$XDistancesEdit.editable = true
		$XDistancesEdit.context_menu_enabled = true
		$XDistancesEdit.visible = false
	if has_node("YDistancesEdit"):
		$YDistancesEdit.mouse_filter = Control.MOUSE_FILTER_STOP
		$YDistancesEdit.editable = true
		$YDistancesEdit.context_menu_enabled = true
		$YDistancesEdit.visible = false
	update_labels()
	# Log pentru depanare
	print("Ierarhie Interax:", get_children())
	print("ExecuteButton conectat:", $ExecuteButton.pressed.is_connected(_on_execute_pressed))
	print("XDistancesEdit conectat:", $XDistancesEdit.text_changed.is_connected(_on_x_distances_changed))
	print("YDistancesEdit conectat:", $YDistancesEdit.text_changed.is_connected(_on_y_distances_changed))


	# build table popup UI for editing rows
	_build_table_popup()

func _draw():
	if is_selected_for_connection:
		draw_rect(Rect2(-200, -100, 400, 200), Color.BLUE, false, 2.0)

func _input(event):
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		var local_pos = to_local(event.position)
		var rect = Rect2(-200, -100, 400, 200)
		var main_scene = get_tree().root.get_node("MainScene") if get_tree().root.has_node("MainScene") else null
		var is_connect_mode = main_scene.is_connect_mode_active() if main_scene else false
		# Verifică dacă clic-ul este în afara LineEdit-urilor
		var is_over_line_edit = false
		if $XDistancesEdit.get_rect().has_point(local_pos) or $YDistancesEdit.get_rect().has_point(local_pos):
			is_over_line_edit = true
		print("Mouse pos:", local_pos, "In rect:", rect.has_point(local_pos), "Connect mode:", is_connect_mode, "Over LineEdit:", is_over_line_edit)
		if rect.has_point(local_pos) and not is_over_line_edit:
			if event.pressed:
				if is_connect_mode:
					emit_signal("circle_selected_for_connection", self)
				else:
					emit_signal("circle_selected_for_properties", self)
					is_dragging = true
					drag_start_pos = event.position
					print("Începe drag pentru Interax:", obj_name, "la poziția:", global_position)
			else:
				is_dragging = false
				print("Oprește drag pentru Interax:", obj_name)
			get_tree().set_input_as_handled()
	
	if event is InputEventMouseMotion and is_dragging:
		var camera = get_parent().get_node("Camera2D") if get_parent().has_node("Camera2D") else null
		if camera:
			var delta = (event.position - drag_start_pos) / camera.zoom
			global_position += delta
			drag_start_pos = event.position
			get_parent().update_scene()
			print("Mutare Interax:", obj_name, "la:", global_position, "Delta:", delta)
			get_tree().set_input_as_handled()
		else:
			push_error("Camera2D nu a fost găsită în părinte!")

func _on_execute_pressed():
	print("ExecuteButton apăsat pentru Interax:", obj_name)
	emit_signal("execute_pressed", self)

func _on_close_pressed():
	print("CloseButton apăsat pentru Interax:", obj_name)
	emit_signal("close_pressed", self)

func _on_x_distances_changed(new_text):
	print("XDistancesEdit input brut:", new_text)
	var cleaned_text = new_text.replace("[", "").replace("]", "").strip_edges()
	var values = cleaned_text.split(",", false)
	var new_distances = []
	for val in values:
		val = val.strip_edges()
		if val.is_valid_float():
			var num = float(val)
			if num >= 0.0:
				new_distances.append(num)
			else:
				print("Valoare invalidă (negativă) în distanțe x:", val)
		else:
			print("Valoare invalidă în distanțe x:", val)
	if new_distances.size() > 0:
		distances[0] = new_distances
		update_labels()
		print("Distanțe x actualizate pentru Interax:", obj_name, distances[0])
	else:
		$XDistancesEdit.text = str(distances[0]).replace("[", "").replace("]", "")
		print("Format invalid pentru distanțe x:", new_text)

func _on_y_distances_changed(new_text):
	print("YDistancesEdit input brut:", new_text)
	var cleaned_text = new_text.replace("[", "").replace("]", "").strip_edges()
	var values = cleaned_text.split(",", false)
	var new_distances = []
	for val in values:
		val = val.strip_edges()
		if val.is_valid_float():
			var num = float(val)
			if num >= 0.0:
				new_distances.append(num)
			else:
				print("Valoare invalidă (negativă) în distanțe y:", val)
		else:
			print("Valoare invalidă în distanțe y:", val)
	if new_distances.size() > 0:
		distances[1] = new_distances
		update_labels()
		print("Distanțe y actualizate pentru Interax:", obj_name, distances[1])
	else:
		$YDistancesEdit.text = str(distances[1]).replace("[", "").replace("]", "")
		print("Format invalid pentru distanțe y:", new_text)

func update_labels():
	if has_node("XDistancesEdit") and has_node("YDistancesEdit"):
		$XDistancesEdit.text = str(distances[0]).replace("[", "").replace("]", "")
		$YDistancesEdit.text = str(distances[1]).replace("[", "").replace("]", "")

func reset_connection_selection():
	is_selected_for_connection = false
	queue_redraw()


### Popup table builders / handlers
func _build_table_popup():
	# create a PopupPanel with a VBoxContainer and header + ScrollContainer table
	_table_popup = PopupPanel.new()
	_table_popup.name = "DistancesTablePopup"
	var vbox = VBoxContainer.new()
	vbox.name = "VBoxContainer"
	_table_popup.add_child(vbox)

	# header HBox with title and buttons
	var header = HBoxContainer.new()
	var title = Label.new()
	title.text = "Edit Distances Table"
	title.custom_minimum_size = Vector2(200, 0)
	header.add_child(title)
	header.add_spacer(0)
	var add_btn = Button.new()
	add_btn.text = "Add Row"
	add_btn.connect("pressed", Callable(self, "_on_add_row_pressed"))
	header.add_child(add_btn)
	var save_btn = Button.new()
	save_btn.text = "Save"
	save_btn.connect("pressed", Callable(self, "_on_save_table_pressed"))
	header.add_child(save_btn)
	var close_btn = Button.new()
	close_btn.text = "Close"
	close_btn.connect("pressed", Callable(self, "_on_close_table_pressed"))
	header.add_child(close_btn)
	vbox.add_child(header)

	# column labels
	var cols = HBoxContainer.new()
	for col_name in ["no", "x", "y", "z"]:
		var lbl = Label.new()
		lbl.text = col_name
		lbl.custom_minimum_size = Vector2(80, 0)
		cols.add_child(lbl)
	vbox.add_child(cols)

	# scrollcontainer for rows
	var scroll = ScrollContainer.new()
	scroll.name = "ScrollContainer"
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.custom_minimum_size = Vector2(400, 200)
	var rows_v = VBoxContainer.new()
	rows_v.name = "Rows"
	scroll.add_child(rows_v)
	vbox.add_child(scroll)

	add_child(_table_popup)
	_table_popup.popup_centered()
	_populate_table_from_distances()

func _populate_table_from_distances():
	if not _table_popup:
		return
	var rows_v = _table_popup.get_node("VBoxContainer/ScrollContainer/Rows") if _table_popup.has_node("VBoxContainer/ScrollContainer/Rows") else null
	if not rows_v:
		# try to find by traversing
		for child in _table_popup.get_children():
			if child is VBoxContainer:
				for sc in child.get_children():
					if sc is ScrollContainer:
						rows_v = sc.get_node("Rows") if sc.has_node("Rows") else null
	if not rows_v:
		push_error("Rows container not found in popup")
		return
	# clear existing
	for c in rows_v.get_children():
		c.queue_free()
	_table_rows.clear()

	# build from distances; ensure distances_table exists
	if not has_meta("distances_table"):
		set_meta("distances_table", [])
	var table = get_meta("distances_table")
	# fallback: if table empty but distances present, build rows from distances arrays
	if table.size() == 0 and distances.size() >= 2:
		# try to align elements; use max length of inner lists
		var max_rows = max(distances[0].size(), distances[1].size())
		for i in range(max_rows):
			var x = distances[0][i] if i < distances[0].size() else 0.0
			var y = distances[1][i] if i < distances[1].size() else 0.0
			table.append({"x": x, "y": y, "z": 0.0})
		set_meta("distances_table", table)

	for i in range(table.size()):
		var row = table[i]
		_add_table_row(i + 1, float(row.get("x", 0.0)), float(row.get("y", 0.0)), float(row.get("z", 0.0)))

func _add_table_row(no: int, x_val: float, y_val: float, z_val: float):
	if not _table_popup:
		return
	var rows_v = _table_popup.get_node("VBoxContainer/ScrollContainer/Rows") if _table_popup.has_node("VBoxContainer/ScrollContainer/Rows") else null
	if not rows_v:
		# traverse to find
		for child in _table_popup.get_children():
			if child is VBoxContainer:
				for sc in child.get_children():
					if sc is ScrollContainer:
						rows_v = sc.get_node("Rows") if sc.has_node("Rows") else null
	if not rows_v:
		push_error("Rows container not found for adding row")
		return

	var h = HBoxContainer.new()
	var no_lbl = Label.new()
	no_lbl.text = str(no)
	no_lbl.custom_minimum_size = Vector2(40, 0)
	h.add_child(no_lbl)

	var x_edit = LineEdit.new()
	x_edit.text = str(x_val)
	x_edit.custom_minimum_size = Vector2(80, 0)
	h.add_child(x_edit)

	var y_edit = LineEdit.new()
	y_edit.text = str(y_val)
	y_edit.custom_minimum_size = Vector2(80, 0)
	h.add_child(y_edit)

	var z_edit = LineEdit.new()
	z_edit.text = str(z_val)
	z_edit.custom_minimum_size = Vector2(80, 0)
	h.add_child(z_edit)

	rows_v.add_child(h)
	_table_rows.append({"no_label": no_lbl, "x_edit": x_edit, "y_edit": y_edit, "z_edit": z_edit})

func _on_add_row_pressed():
	var next_no = _table_rows.size() + 1
	_add_table_row(next_no, 0.0, 0.0, 0.0)

func _on_save_table_pressed():
	# validate and write back into meta and distances arrays
	var table = []
	for r in _table_rows:
		var xs = r.x_edit.text.strip_edges()
		var ys = r.y_edit.text.strip_edges()
		var zs = r.z_edit.text.strip_edges()
		var valid = true
		var xv = 0.0
		var yv = 0.0
		var zv = 0.0
		if xs.is_valid_float():
			xv = float(xs)
		else:
			valid = false
		if ys.is_valid_float():
			yv = float(ys)
		else:
			valid = false
		if zs.is_valid_float():
			zv = float(zs)
		else:
			valid = false
		if not valid:
			push_error("Invalid numeric value in table row; save aborted")
			return
		table.append({"x": xv, "y": yv, "z": zv})

	set_meta("distances_table", table)
	# also sync into distances two arrays for backward compatibility
	var xs_list = []
	var ys_list = []
	for row in table:
		xs_list.append(row.x)
		ys_list.append(row.y)
	distances = [xs_list, ys_list]
	update_labels()
	_on_close_table_pressed()

func _on_close_table_pressed():
	if _table_popup:
		_table_popup.hide()
		_table_popup.queue_free()
		_table_popup = null
		_table_rows.clear()
