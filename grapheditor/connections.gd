extends Node2D

var connections = []
var selected_connection = null

signal connection_selected(connection)

# Dictionar meta pentru conexiuni (folosit de PropertiesPanel)
var connection_info = {
	"has_wall": true,
	"wall_type": "",
	"has_beam": true,
	"beam_type": "",
	"offset_start": 0.125,
	"offset_end": -0.125
}

# Alias so PropertiesPanel can read connection metadata via the same `node_info` name used for nodes
var node_info = connection_info

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
		var start_pos = connection[0].global_position
		var end_pos = connection[1].global_position
		var color = Color.RED if connection == selected_connection else Color.GREEN
		var control_offset = Vector2(50, 0)  # Pentru curbă Bezier
		draw_polyline(
			curve_points(start_pos, end_pos, control_offset),
			color,
			2.0
		)

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
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		var mouse_pos = get_global_mouse_position()
		var closest_connection = null
		var min_distance = 10.0  # Distanța maximă pentru selecție (pixeli)
		
		for connection in connections:
			var start_pos = connection[0].global_position
			var end_pos = connection[1].global_position
			var control_offset = Vector2(50, 0)
			var points = curve_points(start_pos, end_pos, control_offset)
			
			# Verifică distanța de la mouse la curbă
			for i in range(points.size() - 1):
				var p1 = points[i]
				var p2 = points[i + 1]
				var distance = point_to_segment_distance(mouse_pos, p1, p2)
				if distance < min_distance:
					min_distance = distance
					closest_connection = connection
		
		if closest_connection:
			selected_connection = closest_connection
			emit_signal("connection_selected", selected_connection)
			queue_redraw()

func point_to_segment_distance(point: Vector2, seg_start: Vector2, seg_end: Vector2) -> float:
	var l2 = seg_start.distance_squared_to(seg_end)
	if l2 == 0.0:
		return point.distance_to(seg_start)
	var t = max(0, min(1, point.distance_to(seg_start) / l2))
	var projection = seg_start + t * (seg_end - seg_start)
	return point.distance_to(projection)
