extends GraphEdit

var node_count = 0
var save_path = "user://bubble_graph_save.json"
var connecting_from = null

func _ready():
	# Enable built-in features
	snapping_enabled = true
	snapping_distance = 20
	zoom_min = 0.5
	zoom_max = 2.0
	
	# Connect signals
	connect("connection_request", Callable(self, "_on_connection_request"))
	connect("disconnection_request", Callable(self, "_on_disconnection_request"))
	
	# Load saved graph
	load_graph()

func _gui_input(event):
	# Create node on left click
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		var local_pos = get_local_mouse_position() + scroll_offset
		if not is_over_node(local_pos):
			create_node(local_pos)
			accept_event()
	
	# Delete node on right click
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
		var local_pos = get_local_mouse_position() + scroll_offset
		var node = get_node_at_position(local_pos)
		if node:
			delete_node(node)
			accept_event()
	
	# Save graph on Ctrl+S
	if event is InputEventKey and event.pressed and event.keycode == KEY_S and event.ctrl_pressed:
		save_graph()
		accept_event()

func create_node(pos: Vector2):
	node_count += 1
	var node = GraphNode.new()
	node.title = "Node " + str(node_count)
	node.name = "Node" + str(node_count)
	
	# Add a dummy slot to enable connections
	var label = Label.new()
	label.text = node.title
	node.add_child(label)
	node.set_slot(0, true, 0, Color(1, 1, 1), true, 0, Color(1, 1, 1))
	
	# Set size and position
	node.size = Vector2(100, 60)
	node.position_offset = pos
	
	# Apply custom style for bubble appearance
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.2, 0.6, 1, 0.8)
	style.border_color = Color(1, 1, 1)
	style.border_width_top = 2
	style.border_width_bottom = 2
	style.border_width_left = 2
	style.border_width_right = 2
	style.corner_radius_top_left = 50
	style.corner_radius_top_right = 50
	style.corner_radius_bottom_left = 50
	style.corner_radius_bottom_right = 50
	node.add_theme_stylebox_override("frame", style)
	
	add_child(node)

func delete_node(node: GraphNode):
	# Remove all connections involving this node
	for conn in get_connection_list():
		if conn.from == node.name or conn.to == node.name:
			disconnect_node(conn.from, conn.from_port, conn.to, conn.to_port)
	node.queue_free()

func get_node_at_position(pos: Vector2) -> GraphNode:
	for node in get_children():
		if node is GraphNode:
			var rect = Rect2(node.position_offset, node.size)
			if rect.has_point(pos):
				return node
	return null

func is_over_node(pos: Vector2) -> bool:
	return get_node_at_position(pos) != null

func _on_connection_request(from_node: String, from_port: int, to_node: String, to_port: int):
	connect_node(from_node, from_port, to_node, to_port)

func _on_disconnection_request(from_node: String, from_port: int, to_node: String, to_port: int):
	disconnect_node(from_node, from_port, to_node, to_port)

func save_graph():
	var data = {
		"nodes": [],
		"edges": []
	}
	for node in get_children():
		if node is GraphNode:
			data["nodes"].append({
				"name": node.name,
				"title": node.title,
				"position": [node.position_offset.x, node.position_offset.y]
			})
	for conn in get_connection_list():
		data["edges"].append({
			"from": conn.from,
			"from_port": conn.from_port,
			"to": conn.to,
			"to_port": conn.to_port
		})
	
	var file = FileAccess.open(save_path, FileAccess.WRITE)
	file.store_string(JSON.stringify(data, "", false))
	file.close()

func load_graph():
	if FileAccess.file_exists(save_path):
		var file = FileAccess.open(save_path, FileAccess.READ)
		var data = JSON.parse_string(file.get_as_text())
		file.close()
		
		# Clear existing nodes and connections
		clear_connections()
		for node in get_children():
			if node is GraphNode:
				node.queue_free()
		
		# Create nodes
		node_count = 0
		for node_data in data["nodes"]:
			node_count = max(node_count, int(node_data["name"].replace("Node", "")))
			create_node(Vector2(node_data["position"][0], node_data["position"][1]))
			var node = get_node("Node" + str(node_count))
			node.title = node_data["title"]
		
		# Create edges
		for edge in data["edges"]:
			connect_node(edge["from"], edge["from_port"], edge["to"], edge["to_port"])
