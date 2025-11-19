extends Node2D

# Load UUID generator
const UUIDGenerator = preload("res://UUIDGenerator.gd")

var size = 30.0  # Dimensiunea pătratului (lățime/înălțime)
var is_selected = false  # Starea de selecție pentru mutare
var is_dragging = false  # Starea de drag
var is_selected_for_connection = false  # Starea de selecție pentru conexiune
var type = "room"  # Tipul nodului (room, shell, cell)
var obj_name = "room0"  # Numele nodului (default type+index)
var id = 0  # ID unic pentru nod (legacy, kept for compatibility)

# Extensible node_info dictionary with mandatory and custom properties
# Mandatory properties: uuid, type, index, layer, visible
var node_info = {
	"uuid": "",  # Unique identifier (generated automatically)
	"type": "room",  # Node type
	"index": 0,  # Node index
	"layer": "architectural",  # Layer assignment
	"visible": true,  # Visibility flag
	"name": "Room",  # Display name
	"description": "",  # Room description
	"connected_nodes": [],  # Lista de noduri conectate în ordine
	"properties": {}  # Additional custom properties storage
}

signal circle_selected_for_connection(node)  # Semnal pentru conexiune (compatibil cu cercurile)
signal circle_selected_for_properties(node)  # Semnal pentru proprietăți

func _ready():
	set_process_input(true)
	set_process(true)
	
	# Generate UUID if not already set
	if node_info["uuid"] == "" or node_info["uuid"] == null:
		node_info["uuid"] = UUIDGenerator.generate_uuid()
	
	# Sincronizează node_info cu proprietățile curente ale nodului
	node_info["name"] = str(type) + str(id)
	node_info["index"] = id
	node_info["type"] = type
	node_info["visible"] = visible
	
	# Ensure layer is set
	if not node_info.has("layer") or node_info["layer"] == "":
		node_info["layer"] = "architectural"
	
	# Ensure properties dict exists
	if not node_info.has("properties"):
		node_info["properties"] = {}
	
	# Keep obj_name consistent
	obj_name = node_info["name"]
	
	# Update visibility based on layer
	_update_layer_visibility()

func _process(_delta):
	# Continuously check layer visibility
	_update_layer_visibility()

func _update_layer_visibility():
	if has_node("/root/LayerManager"):
		var layer_mgr = get_node("/root/LayerManager")
		var node_layer = node_info.get("layer", "architectural")
		visible = layer_mgr.is_layer_visible(node_layer)

func _draw():
	var size_val = 50.0
	var color_val = Color(0, 1, 0, 1)
	var line_width = 2.0
	
	if node_info.has("size"):
		size_val = float(node_info["size"])
	if node_info.has("color"):
		var c = node_info["color"]
		if typeof(c) == TYPE_COLOR:
			color_val = c
		elif typeof(c) == TYPE_STRING:
			color_val = Color(c) if c.is_valid_html_color() else Color(0, 1, 0, 1)
	
	# Highlight dacă este selectat pentru proprietăți (normal selection)
	if is_selected:
		line_width = 4.0
		color_val = Color(1, 0.5, 0, 1)  # Portocaliu pentru selecție normală
	
	# Highlight dacă este selectat pentru conexiune
	if is_selected_for_connection:
		line_width = 4.0
		color_val = Color(1, 1, 0, 1)  # Galben pentru conexiune
	
	# Highlight dacă este în modul Room multi-select (prioritate maximă)
	if get_parent() and get_parent().has_method("get_room_source_node"):
		if get_parent().get_room_source_node() == self:
			line_width = 5.0
			color_val = Color(1, 0.5, 0, 1)  # Portocaliu pentru Room activ
	
	draw_rect(Rect2(-size_val / 2, -size_val / 2, size_val, size_val), color_val, false, line_width)

func _input(event):
	# Găsește Camera2D
	var camera = get_node("/root/Main/Camera2D")
	if camera == null:
		push_error("Camera2D nu a fost găsit! Verifică ierarhia scenei.")
		return
	
	var mouse_pos = get_global_mouse_position()
	
	# Calculează dacă mouse-ul este peste pătrat (în coordonate globale)
	# Dublează zona de selecție pentru click mai ușor
	var selection_size = size * 2.0  # Dublează zona de selecție
	var rect = Rect2(global_position - Vector2(selection_size / 2, selection_size / 2) / camera.zoom, Vector2(selection_size, selection_size) / camera.zoom)
	var is_mouse_over = rect.has_point(mouse_pos)
	
	# Clic stânga pentru selecție și mutare sau conexiune
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			if is_mouse_over:
				var main_node = get_node("/root/Main")
				if main_node and main_node.is_connect_mode_active():
					# Only emit the event; selection state is handled centrally in main_scene.gd
					emit_signal("circle_selected_for_connection", self)
					print("Pătrat selectat pentru conexiune:", name)  # Debug
					queue_redraw()
				else:
					# Do not set is_selected locally; main_scene.gd will set it when handling the signal
					is_dragging = true
					emit_signal("circle_selected_for_properties", self)
					queue_redraw()
		else:
			# Nu resetăm is_selected când eliberăm mouse-ul, doar is_dragging
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

func reset_selection():
	is_selected = false
	queue_redraw()
