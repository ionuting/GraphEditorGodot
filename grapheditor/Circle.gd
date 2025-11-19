extends Node2D

# Load UUID generator
const UUIDGenerator = preload("res://UUIDGenerator.gd")

var radius = 25.0  # Raza cercului
var is_selected = false  # Starea de selecție pentru mutare
var is_dragging = false  # Starea de drag
var is_selected_for_connection = false  # Starea de selecție pentru conexiune
var type = "Node"  # Tipul nodului (Input, Output, Process)
var obj_name = "Node"  # Numele nodului
var id = 0  # ID unic pentru nod (legacy, kept for compatibility)

# Extensible node_info dictionary with mandatory and custom properties
# Mandatory properties: uuid, type, index, layer, visible
# Custom properties can be added dynamically via PropertiesPanel
var node_info = {
	"uuid": "",  # Unique identifier (generated automatically)
	"type": "ax",  # Node type
	"index": 0,  # Node index
	"layer": "structural",  # Layer assignment
	"visible": true,  # Visibility flag
	"name": "Node",  # Display name
	"has_column": true,  # Example custom property
	"column_type": "2525",  # Example custom property
	"properties": {}  # Additional custom properties storage
}

signal circle_selected_for_connection(node)  # Semnal pentru conexiune
signal circle_selected_for_properties(node)  # Semnal pentru proprietăți

func _ready():
	set_process_input(true)
	set_process(true)
	
	# Generate UUID if not already set
	if node_info["uuid"] == "" or node_info["uuid"] == null:
		node_info["uuid"] = UUIDGenerator.generate_uuid()
	
	# Sincronizează node_info cu proprietățile curente ale nodului
	node_info["name"] = obj_name
	node_info["index"] = id
	node_info["type"] = type
	node_info["visible"] = visible
	
	# Ensure layer is set
	if not node_info.has("layer") or node_info["layer"] == "":
		node_info["layer"] = "structural"
	
	# Ensure properties dict exists
	if not node_info.has("properties"):
		node_info["properties"] = {}
	
	# Update visibility based on layer
	_update_layer_visibility()

func _process(_delta):
	# Continuously check layer visibility
	_update_layer_visibility()

func _update_layer_visibility():
	if has_node("/root/LayerManager"):
		var layer_mgr = get_node("/root/LayerManager")
		var node_layer = node_info.get("layer", "structural")
		visible = layer_mgr.is_layer_visible(node_layer)

func _draw():
	# Schimbă culoarea în funcție de stare
	var color = Color.RED if is_selected else (Color.YELLOW if is_selected_for_connection else Color.GREEN)
	draw_circle(Vector2.ZERO, radius, color)
	
	# Desenează eticheta cu indexul nodului - folosește node_info["index"] dacă există
	var index_value = node_info.get("index", id)
	var index_text = str(index_value)
	var font = ThemeDB.fallback_font
	var font_size = 14
	var text_size = font.get_string_size(index_text, HORIZONTAL_ALIGNMENT_CENTER, -1, font_size)
	var text_pos = Vector2(-text_size.x / 2, text_size.y / 4)
	draw_string(font, text_pos, index_text, HORIZONTAL_ALIGNMENT_CENTER, -1, font_size, Color.WHITE)

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
					# Only emit the event; selection state is managed centrally by main_scene.gd
					emit_signal("circle_selected_for_connection", self)
					print("Cerc selectat pentru conexiune:", name)  # Debug
					queue_redraw()
				else:
					# Node shouldn't set selection state directly; main_scene will set is_selected when handling this signal
					is_dragging = true
					emit_signal("circle_selected_for_properties", self)
					queue_redraw()
		else:
			# Nu resetăm is_selected când eliberăm mouse-ul, doar is_dragging
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

func reset_selection():
	is_selected = false
	queue_redraw()
