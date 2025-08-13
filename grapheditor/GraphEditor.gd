extends Node2D

# Data structures
var nodes = []
var edges = []
var selected_node = null
var dragging_node = null
var connecting_node = null
var mouse_offset = Vector2.ZERO
var node_radius = 30.0
var camera: Camera2D
var save_path = "user://graph_save.json"

# UI state
var is_panning = false
var pan_start_pos = Vector2.ZERO

func _ready():
	# Initialize camera
	camera = Camera2D.new()
	camera.position = Vector2(500, 300) # Center of viewport
	camera.zoom = Vector2(1, 1)
	add_child(camera)
	camera.make_current()
	
	# Load saved graph if exists
	load_graph()

func _process(_delta):
	queue_redraw() # Trigger redraw to show edges and node highlights

func _unhandled_input(event):
	# Create node on left click
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		if not is_over_node(event.position):
			create_node(event.position / camera.zoom + camera.position)
	
	# Delete node on right click
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
		var node = get_node_at_position(event.position)
		if node:
			delete_node(node)
	
	# Start/end edge connection
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		var node = get_node_at_position(event.position)
		if event.pressed and node:
			if connecting_node and connecting_node != node:
				create_edge(connecting_node, node)
				connecting_node = null
			else:
				connecting_node = node
		elif not event.pressed:
			connecting_node = null
	
	# Zoom with mouse wheel
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			camera.zoom *= 1.1
		if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			camera.zoom /= 1.1
		camera.zoom = clamp(camera.zoom, Vector2(0.5, 0.5), Vector2(2, 2))
	
	# Pan with middle mouse button
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_MIDDLE:
		if event.pressed:
			is_panning = true
			pan_start_pos = event.position
		else:
			is_panning = false
	
	if event is InputEventMouseMotion and is_panning:
		var delta = (pan_start_pos - event.position) / camera.zoom
		camera.position += delta
		pan_start_pos = event.position
	
	# Drag node
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		var node = get_node_at_position(event.position)
		if event.pressed and node:
			dragging_node = node
			mouse_offset = (event.position / camera.zoom + camera.position) - node.position
		if not event.pressed:
			dragging_node = null
	
	if event is InputEventMouseMotion and dragging_node:
		dragging_node.position = (event.position / camera.zoom + camera.position) - mouse_offset
	
	# Save graph on Ctrl+S
	if event is InputEventKey and event.pressed and event.keycode == KEY_S and event.ctrl_pressed:
		save_graph()

func _draw():
	# Draw edges
	for edge in edges:
		var start = (edge[0].position - camera.position) * camera.zoom
		var end = (edge[1].position - camera.position) * camera.zoom
		draw_line(start, end, Color(1, 1, 1), 2.0)
	
	# Draw temporary edge while connecting
	if connecting_node:
		var start = (connecting_node.position - camera.position) * camera.zoom
		var end = (get_global_mouse_position() / camera.zoom + camera.position - camera.position) * camera.zoom
		draw_line(start, end, Color(0.5, 0.5, 0.5), 1.0)

func create_node(pos: Vector2):
	var node = Node2D.new()
	node.position = pos
	# Add a label for the node name
	var label = Label.new()
	label.text = "Node " + str(nodes.size() + 1)
	label.position = Vector2(-20, -10)
	node.add_child(label)
	# Add a script to the node for custom drawing
	node.set_script(preload("res://BubbleNode.gd"))
	nodes.append(node)
	add_child(node)
	queue_redraw()

func delete_node(node):
	nodes.erase(node)
	var new_edges = []
	for edge in edges:
		if edge[0] != node and edge[1] != node:
			new_edges.append(edge)
	edges = new_edges
	node.queue_free()
	queue_redraw()

func create_edge(from_node, to_node):
	edges.append([from_node, to_node])
	queue_redraw()

func get_node_at_position(pos: Vector2) -> Node2D:
	var world_pos = pos / camera.zoom + camera.position
	for node in nodes:
		if node.position.distance_to(world_pos) < node_radius / camera.zoom.x:
			return node
	return null

func is_over_node(pos: Vector2) -> bool:
	return get_node_at_position(pos) != null

func save_graph():
	var data = {
		"nodes": [],
		"edges": []
	}
	for node in nodes:
		data["nodes"].append({"position": [node.position.x, node.position.y], "label": node.get_child(0).text})
	for edge in edges:
		var from_idx = nodes.find(edge[0])
		var to_idx = nodes.find(edge[1])
		data["edges"].append([from_idx, to_idx])
	
	var file = FileAccess.open(save_path, FileAccess.WRITE)
	file.store_string(JSON.stringify(data, "", false))
	file.close()

func load_graph():
	if FileAccess.file_exists(save_path):
		var file = FileAccess.open(save_path, FileAccess.READ)
		var json = JSON.new()
		if json.parse(file.get_as_text()) == OK:
			var data = json.data
			# Clear existing nodes and edges
			for node in nodes:
				node.queue_free()
			nodes.clear()
			edges.clear()
			
			# Create nodes
			for node_data in data["nodes"]:
				create_node(Vector2(node_data["position"][0], node_data["position"][1]))
				nodes[-1].get_child(0).text = node_data["label"]
			
			# Create edges
			for edge_data in data["edges"]:
				if edge_data[0] < nodes.size() and edge_data[1] < nodes.size():
					create_edge(nodes[edge_data[0]], nodes[edge_data[1]])
		else:
			print("Error parsing JSON: ", json.get_error_message())
		file.close()
