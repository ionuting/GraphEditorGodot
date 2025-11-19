extends Node2D

# Load UUID generator
const UUIDGenerator = preload("res://UUIDGenerator.gd")

var connections = []
var selected_connection = null
var dragging_midpoint = false
var dragged_connection = null
var midpoint_drag_offset = Vector2.ZERO

signal connection_selected(connection)
signal midpoint_selected_for_connection(connection, midpoint_position)

# Connection metadata - used when a connection is selected
# This represents the currently selected connection's properties
var connection_info = {
	"uuid": "",  # UUID of selected connection
	"type": "Process",  # Connection type
	"from_uuid": "",  # Source node UUID
	"to_uuid": "",  # Target node UUID
	"label": "",  # Connection label/name
	"layer": "connections",  # Layer for visibility control
	"has_wall": true,
	"wall_type": "",
	"has_beam": true,
	"beam_type": "",
	"offset_start": 0.125,
	"offset_end": -0.125,
	"midpoint": Vector2.ZERO,  # Custom midpoint position
	"attached_nodes": [],  # Array of UUIDs for attached nodes (windows, doors)
	"properties": {}  # Extensible properties dictionary
}

# Alias so PropertiesPanel can read connection metadata via the same `node_info` name used for nodes
var node_info: Dictionary:
	get:
		print("DEBUG connections.gd: node_info getter called, returning: ", connection_info)
		return connection_info

func _ready():
	# Ensure defaults are synced (keeps shape similar to Circle.gd pattern)
	connection_info["has_wall"] = bool(connection_info.get("has_wall", true))
	connection_info["wall_type"] = str(connection_info.get("wall_type", ""))
	connection_info["has_beam"] = bool(connection_info.get("has_beam", true))
	connection_info["beam_type"] = str(connection_info.get("beam_type", ""))
	connection_info["offset_start"] = float(connection_info.get("offset_start", 0.125))
	connection_info["offset_end"] = float(connection_info.get("offset_end", -0.125))

func update_connections(new_connections):
	connections = new_connections
	queue_redraw()

func _draw():
	for connection in connections:
		# Check layer visibility
		var conn_layer = _get_connection_layer(connection)
		if not _is_layer_visible(conn_layer):
			continue
		
		var start_pos = connection[0].global_position
		var end_pos = connection[1].global_position
		
		# Get color from layer (green by default for connections layer)
		var layer_color = _get_layer_color(conn_layer)
		var color = Color.RED if connection == selected_connection else layer_color
		var control_offset = Vector2(50, 0)  # Pentru curbă Bezier
		
		# Draw connection line with layer color
		draw_polyline(
			curve_points(start_pos, end_pos, control_offset),
			color,
			2.0
		)
		
		# Draw midpoint (visible circle)
		var midpoint = _calculate_midpoint(connection)
		var midpoint_color = Color.YELLOW if connection == selected_connection else Color.WHITE
		var midpoint_radius = 8.0 if connection == selected_connection else 6.0
		draw_circle(midpoint, midpoint_radius, midpoint_color)
		draw_arc(midpoint, midpoint_radius, 0, TAU, 32, Color.BLACK, 1.0)
		
		# Draw attached nodes connections
		var attached_nodes = _get_attached_nodes(connection)
		for attached_uuid in attached_nodes:
			var attached_node = _find_node_by_uuid(attached_uuid)
			if attached_node and attached_node.visible:
				draw_line(midpoint, attached_node.global_position, Color.CYAN, 1.5, true)
				# Draw small circle at attachment point
				draw_circle(attached_node.global_position, 4.0, Color.CYAN)

func curve_points(start: Vector2, end: Vector2, control_offset: Vector2) -> Array:
	var points = []
	var steps = 20
	for i in range(steps + 1):
		var t = float(i) / steps
		var point = lerp(
			lerp(start, start + control_offset, t),
			lerp(end - control_offset, end, t),
			t
		)
		points.append(point)
	return points

func _input(event):
	# Check if we're in connect mode
	var main_scene = get_tree().root.get_node_or_null("Main")
	var in_connect_mode = false
	if main_scene and main_scene.has_method("is_connect_mode_active"):
		in_connect_mode = main_scene.is_connect_mode_active()
	
	print("DEBUG connections.gd: Connect mode status: ", in_connect_mode)
	
	# Handle mouse button press for selection
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		print("DEBUG connections.gd: Mouse click detected")
		var mouse_pos = get_global_mouse_position()
		print("DEBUG connections.gd: Mouse position: ", mouse_pos)
		print("DEBUG connections.gd: in_connect_mode = ", in_connect_mode)
		
		# Check if clicking on a midpoint (priority check)
		for connection in connections:
			var conn_layer = _get_connection_layer(connection)
			if not _is_layer_visible(conn_layer):
				continue
			
			var midpoint = _calculate_midpoint(connection)
			var distance = mouse_pos.distance_to(midpoint)
			print("DEBUG connections.gd: Distance to midpoint: ", distance)
			if distance < 15.0:
				print("DEBUG connections.gd: Midpoint clicked! Connect mode: ", in_connect_mode)
				
				if in_connect_mode:
					# In connect mode, midpoint acts as a connection node for attaching nodes
					emit_signal("midpoint_selected_for_connection", connection, midpoint)
					print("Midpoint selected for connection in connect mode (node attachment)")
				else:
					# NOT in connect mode, select connection for properties editing
					selected_connection = connection
					# FIX #2: Ensure connection_info is populated BEFORE signal is emitted
					_update_connection_info(connection)
					print("DEBUG: connection_info populated before signal emission")
					print("DEBUG: Emitting connection_selected signal")
					emit_signal("connection_selected", selected_connection)
					print("DEBUG: Connection selected via midpoint click for properties")
				
				queue_redraw()
				print("DEBUG: queue_redraw() called")
				return
		
		# If not on midpoint and not in connect mode, check if clicking on connection line
		if not in_connect_mode:
			print("DEBUG connections.gd: Checking line click (not in connect mode)")
			var closest_connection = null
			var min_distance = 10.0
			
			for connection in connections:
				var conn_layer = _get_connection_layer(connection)
				if not _is_layer_visible(conn_layer):
					continue
				
				var start_pos = connection[0].global_position
				var end_pos = connection[1].global_position
				var control_offset = Vector2(50, 0)
				var points = curve_points(start_pos, end_pos, control_offset)
				
				for i in range(points.size() - 1):
					var p1 = points[i]
					var p2 = points[i + 1]
					var distance = point_to_segment_distance(mouse_pos, p1, p2)
					if distance < min_distance:
						min_distance = distance
						closest_connection = connection
			
			print("DEBUG connections.gd: Min distance to line: ", min_distance)
			if closest_connection:
				print("DEBUG connections.gd: Line clicked!")
				selected_connection = closest_connection
				# FIX #2: Ensure connection_info is populated BEFORE signal is emitted
				_update_connection_info(closest_connection)
				print("DEBUG: connection_info populated before signal emission")
				emit_signal("connection_selected", selected_connection)
				print("Connection selected via line click")
				queue_redraw()
	
	# Handle right-click for context menu
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
		var mouse_pos = get_global_mouse_position()
		
		# Check if right-clicking on a connection
		for connection in connections:
			var conn_layer = _get_connection_layer(connection)
			if not _is_layer_visible(conn_layer):
				continue
			
			var midpoint = _calculate_midpoint(connection)
			if mouse_pos.distance_to(midpoint) < 15.0:
				_show_connection_context_menu(connection, event.position)
				return
			
			# Check line
			var start_pos = connection[0].global_position
			var end_pos = connection[1].global_position
			var control_offset = Vector2(50, 0)
			var points = curve_points(start_pos, end_pos, control_offset)
			
			for i in range(points.size() - 1):
				var p1 = points[i]
				var p2 = points[i + 1]
				var distance = point_to_segment_distance(mouse_pos, p1, p2)
				if distance < 10.0:
					_show_connection_context_menu(connection, event.position)
					return

func point_to_segment_distance(point: Vector2, seg_start: Vector2, seg_end: Vector2) -> float:
	var l2 = seg_start.distance_squared_to(seg_end)
	if l2 == 0.0:
		return point.distance_to(seg_start)
	var t = max(0, min(1, point.distance_to(seg_start) / l2))
	var projection = seg_start + t * (seg_end - seg_start)
	return point.distance_to(projection)

# Update connection_info when a connection is selected
func _update_connection_info(connection: Array):
	if connection.size() < 4:
		return
	
	# Connection structure: [from_node, to_node, label, type, uuid, properties, midpoint, layer, attached_nodes]
	var from_node = connection[0]
	var to_node = connection[1]
	var label = connection[2] if connection.size() > 2 else ""
	var type = connection[3] if connection.size() > 3 else "Process"
	var uuid = connection[4] if connection.size() > 4 else ""
	var props = connection[5] if connection.size() > 5 else {}
	var midpoint = connection[6] if connection.size() > 6 else Vector2.ZERO
	var layer = connection[7] if connection.size() > 7 else "connections"
	var attached = connection[8] if connection.size() > 8 else []
	
	# Get UUIDs from nodes
	var from_uuid = ""
	var to_uuid = ""
	if from_node.has_method("get") and from_node.get("node_info") != null:
		from_uuid = from_node.node_info.get("uuid", "")
	if to_node.has_method("get") and to_node.get("node_info") != null:
		to_uuid = to_node.node_info.get("uuid", "")
	
	# Update connection_info
	connection_info["uuid"] = uuid
	connection_info["type"] = type
	connection_info["from_uuid"] = from_uuid
	connection_info["to_uuid"] = to_uuid
	connection_info["label"] = label
	connection_info["layer"] = layer
	connection_info["midpoint"] = midpoint
	connection_info["attached_nodes"] = attached if typeof(attached) == TYPE_ARRAY else []
	
	# Merge properties
	if typeof(props) == TYPE_DICTIONARY:
		for key in props.keys():
			connection_info[key] = props[key]
		# Update the properties dict
		connection_info["properties"] = props.duplicate()
	
	print("Connection info updated: ", connection_info["uuid"], " from ", from_uuid, " to ", to_uuid)

# Helper functions for connection management

func _calculate_midpoint(connection: Array) -> Vector2:
	if connection.size() < 2:
		return Vector2.ZERO
	
	# Calculate midpoint on Bezier curve at t=0.5
	# Midpoint is ALWAYS at the center of the curve (not draggable)
	var from_pos = connection[0].global_position
	var to_pos = connection[1].global_position
	var control_offset = Vector2(50, 0)
	
	# Bezier cubic formula at t=0.5
	var t = 0.5
	var p0 = from_pos
	var p1 = from_pos + control_offset
	var p2 = to_pos - control_offset
	var p3 = to_pos
	
	# Calculate point on curve: B(t) = (1-t)³P0 + 3(1-t)²tP1 + 3(1-t)t²P2 + t³P3
	var midpoint = pow(1-t, 3) * p0 + 3 * pow(1-t, 2) * t * p1 + 3 * (1-t) * pow(t, 2) * p2 + pow(t, 3) * p3
	
	# Midpoint is FIXED at curve center - no offset applied
	# This makes it behave like a connection node that stays on the line
	return midpoint

func _set_connection_midpoint(connection: Array, offset: Vector2):
	# Ensure connection array has enough elements
	if connection.size() < 9:
		while connection.size() < 9:
			if connection.size() == 4:
				connection.append("")  # uuid
			elif connection.size() == 5:
				connection.append({})  # properties
			elif connection.size() == 6:
				connection.append(Vector2.ZERO)  # midpoint offset
			elif connection.size() == 7:
				connection.append("connections")  # layer
			elif connection.size() == 8:
				connection.append([])  # attached_nodes
	
	# Store offset (relative to curve position, not absolute)
	connection[6] = offset
	print("Midpoint offset set to: ", offset, " for connection: ", connection[2] if connection.size() > 2 else "Unknown")

func _get_connection_layer(connection: Array) -> String:
	if connection.size() > 7:
		return connection[7]
	return "connections"

func _get_attached_nodes(connection: Array) -> Array:
	if connection.size() > 8 and typeof(connection[8]) == TYPE_ARRAY:
		return connection[8]
	return []

func _is_layer_visible(layer_name: String) -> bool:
	if has_node("/root/LayerManager"):
		var layer_mgr = get_node("/root/LayerManager")
		return layer_mgr.is_layer_visible(layer_name)
	return true

func _get_layer_color(layer_name: String) -> Color:
	if has_node("/root/LayerManager"):
		var layer_mgr = get_node("/root/LayerManager")
		return layer_mgr.get_layer_color(layer_name)
	return Color.GREEN  # Default fallback color

func _find_node_by_uuid(uuid: String) -> Node:
	# Get main scene to access nodes container
	var main_scene = get_tree().root.get_node_or_null("Main")
	if main_scene == null:
		return null
	
	var circles_container = main_scene.get_node_or_null("CirclesContainer")
	if circles_container == null:
		return null
	
	for node in circles_container.get_children():
		if node.has_method("get") and node.get("node_info") != null:
			if node.node_info.get("uuid", "") == uuid:
				return node
	
	return null

func _show_connection_context_menu(connection: Array, screen_pos: Vector2):
	var popup = PopupMenu.new()
	popup.name = "ConnectionContextMenu"
	popup.add_item("Delete Connection", 0)
	popup.add_separator()
	popup.add_item("Attach Node to Midpoint", 1)
	
	popup.id_pressed.connect(func(id):
		match id:
			0:  # Delete
				_delete_connection(connection)
			1:  # Attach node
				_start_attach_mode(connection)
		popup.queue_free()
	)
	
	get_tree().root.add_child(popup)
	popup.position = screen_pos
	popup.popup()

func _delete_connection(connection: Array):
	if connection in connections:
		connections.erase(connection)
		if selected_connection == connection:
			selected_connection = null
		queue_redraw()
		print("Connection deleted via context menu")

func _start_attach_mode(connection: Array):
	# Get main scene and activate attach mode
	var main_scene = get_tree().root.get_node_or_null("Main")
	if main_scene and main_scene.has_method("_activate_attach_mode"):
		main_scene._activate_attach_mode(connection)
		print("Attach mode activated for connection: ", connection[2] if connection.size() > 2 else "Unknown")
	else:
		push_error("Cannot activate attach mode: main_scene not found or method missing")
