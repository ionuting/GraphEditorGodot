extends Node2D

var radius = 25.0  # Raza cercului
var is_selected = false  # Starea de selecție pentru mutare
var is_dragging = false  # Starea de drag
var is_selected_for_connection = false  # Starea de selecție pentru conexiune
var type = "Node"  # Tipul nodului (Input, Output, Process)
var obj_name = "Node"  # Numele nodului
var id = 0  # ID unic pentru nod

signal circle_selected_for_connection(node)  # Semnal pentru conexiune
signal circle_selected_for_properties(node)  # Semnal pentru proprietăți

func _ready():
	set_process_input(true)

func _draw():
	# Schimbă culoarea în funcție de stare
	var color = Color.RED if is_selected else (Color.YELLOW if is_selected_for_connection else Color.GREEN)
	draw_circle(Vector2.ZERO, radius, color)

func _input(event):
	# Găsește Camera2D
	var camera = get_node("/root/Main/Camera2D")
	if camera == null:
		push_error("Camera2D nu a fost găsit! Verifică ierarhia scenei.")
		return
	
	var mouse_pos = get_global_mouse_position()
	
	# Calculează distanța dintre mouse și centrul cercului (în coordonate globale)
	var distance = mouse_pos.distance_to(global_position)
	
	# Detectează dacă mouse-ul este peste cerc
	var is_mouse_over = distance <= radius * camera.zoom.x
	
	# Clic stânga pentru selecție și mutare sau conexiune
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			if is_mouse_over:
				var main_node = get_node("/root/Main")
				if main_node and main_node.is_connect_mode_active():
					is_selected_for_connection = true
					emit_signal("circle_selected_for_connection", self)
					print("Cerc selectat pentru conexiune:", name)  # Debug
					queue_redraw()
				else:
					is_selected = true
					is_dragging = true
					emit_signal("circle_selected_for_properties", self)
					queue_redraw()
		else:
			is_selected = false
			is_dragging = false
			queue_redraw()
	
	# Mută cercul dacă este în modul drag
	if event is InputEventMouseMotion and is_dragging:
		global_position = mouse_pos
		queue_redraw()
		var main_node = get_node("/root/Main")
		if main_node:
			main_node.update_connections()

func reset_connection_selection():
	is_selected_for_connection = false
	queue_redraw()
