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
	$XDistancesEdit.text_changed.connect(_on_x_distances_changed)
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
	if has_node("YDistancesEdit"):
		$YDistancesEdit.mouse_filter = Control.MOUSE_FILTER_STOP
		$YDistancesEdit.editable = true
		$YDistancesEdit.context_menu_enabled = true
	update_labels()
	# Log pentru depanare
	print("Ierarhie Interax:", get_children())
	print("ExecuteButton conectat:", $ExecuteButton.pressed.is_connected(_on_execute_pressed))
	print("XDistancesEdit conectat:", $XDistancesEdit.text_changed.is_connected(_on_x_distances_changed))
	print("YDistancesEdit conectat:", $YDistancesEdit.text_changed.is_connected(_on_y_distances_changed))

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
