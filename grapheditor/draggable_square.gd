extends Node2D

var size = 30.0  # Dimensiunea pătratului (lățime/înălțime)
var is_selected = false  # Starea de selecție pentru mutare
var is_dragging = false  # Starea de drag
var is_selected_for_connection = false  # Starea de selecție pentru conexiune
var type = "Process"  # Tipul nodului (Input, Output, Process)
var obj_name = "Square"  # Numele nodului
var id = 0  # ID unic pentru nod

signal circle_selected_for_connection(node)  # Semnal pentru conexiune (compatibil cu cercurile)
signal circle_selected_for_properties(node)  # Semnal pentru proprietăți

func _ready():
	set_process_input(true)

func _draw():
	# Schimbă culoarea în funcție de stare
	var color = Color.RED if is_selected else (Color.YELLOW if is_selected_for_connection else Color.SKY_BLUE)
	var rect = Rect2(Vector2(-size / 2, -size / 2), Vector2(size, size))
	draw_rect(rect, color, true)

func _input(event):
	# Găsește Camera2D
	var camera = get_node("/root/Main/Camera2D")
	if camera == null:
		push_error("Camera2D nu a fost găsit! Verifică ierarhia scenei.")
		return
	
	var mouse_pos = get_global_mouse_position()
	
	# Calculează dacă mouse-ul este peste pătrat (în coordonate globale)
	var rect = Rect2(global_position - Vector2(size / 2, size / 2) / camera.zoom, Vector2(size, size) / camera.zoom)
	var is_mouse_over = rect.has_point(mouse_pos)
	
	# Clic stânga pentru selecție și mutare sau conexiune
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			if is_mouse_over:
				var main_node = get_node("/root/Main")
				if main_node and main_node.is_connect_mode_active():
					is_selected_for_connection = true
					emit_signal("circle_selected_for_connection", self)
					print("Pătrat selectat pentru conexiune:", name)  # Debug
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
	
	# Mută pătratul dacă este în modul drag
	if event is InputEventMouseMotion and is_dragging:
		global_position = mouse_pos
		queue_redraw()
		var main_node = get_node("/root/Main")
		if main_node:
			main_node.update_connections()

func reset_connection_selection():
	is_selected_for_connection = false
	queue_redraw()
