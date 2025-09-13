# Rectangle2D.gd
# Clasă pentru reprezentarea unui dreptunghi 2D cu funcționalități complete
class_name Rectangle2D

extends RefCounted

# Proprietăți dreptunghi
var position: Vector2
var size: Vector2
var is_selected: bool = false
var id: int

# Puncte de grip (relative la poziția dreptunghiului)
enum GripPoint {
	CENTER,
	TOP_LEFT,
	TOP_CENTER, 
	TOP_RIGHT,
	CENTER_LEFT,
	CENTER_RIGHT,
	BOTTOM_LEFT,
	BOTTOM_CENTER,
	BOTTOM_RIGHT
}

func _init(pos: Vector2, rect_size: Vector2, rect_id: int = 0):
	position = pos
	size = rect_size
	id = rect_id

# Returnează toate punctele de grip în coordonate world
func get_grip_points() -> Dictionary:
	var points = {}
	var half_size = size * 0.5
	
	points[GripPoint.CENTER] = position + half_size
	points[GripPoint.TOP_LEFT] = position
	points[GripPoint.TOP_CENTER] = position + Vector2(half_size.x, 0)
	points[GripPoint.TOP_RIGHT] = position + Vector2(size.x, 0)
	points[GripPoint.CENTER_LEFT] = position + Vector2(0, half_size.y)
	points[GripPoint.CENTER_RIGHT] = position + Vector2(size.x, half_size.y)
	points[GripPoint.BOTTOM_LEFT] = position + Vector2(0, size.y)
	points[GripPoint.BOTTOM_CENTER] = position + Vector2(half_size.x, size.y)
	points[GripPoint.BOTTOM_RIGHT] = position + size
	
	return points

# Verifică dacă un punct este în interiorul dreptunghiului
func contains_point(point: Vector2) -> bool:
	var inside = point.x >= position.x and point.x <= position.x + size.x and \
		         point.y >= position.y and point.y <= position.y + size.y
	print("Verificare punct %s în dreptunghi pos=%s size=%s: %s" % [point, position, size, inside])
	return inside

# Returnează cel mai apropiat punct de grip de un punct dat
func get_closest_grip_point(point: Vector2) -> GripPoint:
	var grip_points = get_grip_points()
	var closest_point = GripPoint.CENTER
	var min_distance = INF
	
	for grip_type in grip_points:
		var grip_pos = grip_points[grip_type]
		var distance = point.distance_to(grip_pos)
		if distance < min_distance:
			min_distance = distance
			closest_point = grip_type
	
	return closest_point

# Mută dreptunghiul la o poziție nouă
func move_to(new_position: Vector2):
	position = new_position

# Redimensionează dreptunghiul prin modificarea unui punct de grip
func resize_by_grip(grip_point: GripPoint, new_grip_pos: Vector2):
	match grip_point:
		GripPoint.TOP_LEFT:
			var old_bottom_right = position + size
			position = new_grip_pos
			size = old_bottom_right - position
		GripPoint.TOP_RIGHT:
			var old_bottom_left = position + Vector2(0, size.y)
			size.x = new_grip_pos.x - position.x
			var new_height = old_bottom_left.y - new_grip_pos.y
			position.y = new_grip_pos.y
			size.y = new_height
		GripPoint.BOTTOM_LEFT:
			var old_top_right = position + Vector2(size.x, 0)
			var new_width = old_top_right.x - new_grip_pos.x
			position.x = new_grip_pos.x
			size.x = new_width
			size.y = new_grip_pos.y - position.y
		GripPoint.BOTTOM_RIGHT:
			size = new_grip_pos - position
		GripPoint.CENTER:
			var half_size = size * 0.5
			position = new_grip_pos - half_size
		# Pentru punctele de mijloc, modifică doar o dimensiune
		GripPoint.TOP_CENTER:
			var old_bottom = position.y + size.y
			position.y = new_grip_pos.y
			size.y = old_bottom - position.y
		GripPoint.BOTTOM_CENTER:
			size.y = new_grip_pos.y - position.y
		GripPoint.CENTER_LEFT:
			var old_right = position.x + size.x
			position.x = new_grip_pos.x
			size.x = old_right - position.x
		GripPoint.CENTER_RIGHT:
			size.x = new_grip_pos.x - position.x
	
	# Asigură-te că dimensiunea rămâne pozitivă
	if size.x < 0:
		position.x += size.x
		size.x = -size.x
	if size.y < 0:
		position.y += size.y
		size.y = -size.y

# Returnează bounds-urile dreptunghiului
func get_bounds() -> Rect2:
	return Rect2(position, size)