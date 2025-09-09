extends Node2D

@export var shape_type: String = "rectangle"
@export var interior_offset: float = 0.125
var vertices: Array[Vector2] = []

func _ready():
	_update_vertices()
	# Force redraw after the node is active in the scene
	call_deferred("queue_redraw")

func _update_vertices():
	match shape_type:
		"rectangle":
			vertices = [Vector2(0,0), Vector2(1,0), Vector2(1,1), Vector2(0,1)]
		"L":
			vertices = [Vector2(0,0), Vector2(2,0), Vector2(2,1), Vector2(1,1), Vector2(1,2), Vector2(0,2)]
		"T":
			vertices = [Vector2(0,0), Vector2(3,0), Vector2(3,1), Vector2(2,1), Vector2(2,2), Vector2(1,2), Vector2(1,1), Vector2(0,1)]
	vertices = apply_offset(vertices, interior_offset)  # Folosim offset pozitiv pentru interior
	call_deferred("queue_redraw")  # redraw

func _draw():
	if vertices.size() > 1:
		draw_polyline(vertices + [vertices[0]], Color.RED, 2)

func apply_offset(poly: Array[Vector2], offset: float) -> Array[Vector2]:
	if poly.size() < 3:
		return poly
	
	var new_poly: Array[Vector2] = []
	var n = poly.size()
	
	for i in range(n):
		var prev = poly[(i - 1 + n) % n]
		var curr = poly[i]
		var next = poly[(i + 1) % n]
		
		# Calculate edge vectors
		var edge1 = (curr - prev).normalized()
		var edge2 = (next - curr).normalized()
		
		# Calculate normal vectors (perpendicular to edges, pointing inward for positive offset)
		var normal1 = Vector2(edge1.y, -edge1.x)  # Schimbat pentru a pointa spre interior
		var normal2 = Vector2(edge2.y, -edge2.x)  # Schimbat pentru a pointa spre interior
		
		# Calculate bisector direction
		var bisector = (normal1 + normal2).normalized()
		
		# Handle degenerate case where normals are opposite
		if bisector.length_squared() < 0.001:
			bisector = normal1
		
		# Calculate offset distance along bisector
		var cos_half_angle = bisector.dot(normal1)
		if abs(cos_half_angle) > 0.001:
			var offset_distance = offset / cos_half_angle
			new_poly.append(curr + bisector * offset_distance)
		else:
			new_poly.append(curr + normal1 * offset)
	
	return new_poly
