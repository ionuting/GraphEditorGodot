class_name WallManager

extends RefCounted

class Wall:
	# control points (where grips sit)
	var ctrl_start: Vector2
	var ctrl_end: Vector2
	# geometry width and offsets from control points along the line direction
	var width: float = 0.25
	var start_offset: float = 0.125
	var end_offset: float = -0.125
	var id: int = 0
	var is_selected: bool = false

	func get_center():
		return (ctrl_start + ctrl_end) * 0.5

	func geom_start():
		var dir = (ctrl_end - ctrl_start)
		if dir.length() == 0:
			return ctrl_start
		dir = dir.normalized()
		return ctrl_start + dir * start_offset

	func geom_end():
		var dir = (ctrl_end - ctrl_start)
		if dir.length() == 0:
			return ctrl_end
		dir = dir.normalized()
		return ctrl_end + dir * end_offset

	func get_bounds() -> Rect2:
 		# Compute bounds from geometry start/end (offset-applied)
		var gs = geom_start()
		var ge = geom_end()
		var dir = (ge - gs)
		if dir.length() == 0:
			var perp = Vector2(0, 1)
		else:
			dir = dir.normalized()
		var perp = Vector2(-dir.y, dir.x)
		var p1 = gs + perp * (width * 0.5)
		var p2 = gs - perp * (width * 0.5)
		var p3 = ge + perp * (width * 0.5)
		var p4 = ge - perp * (width * 0.5)
		var xs = [p1.x, p2.x, p3.x, p4.x]
		var ys = [p1.y, p2.y, p3.y, p4.y]
		var min_x = xs.min()
		var min_y = ys.min()
		var max_x = xs.max()
		var max_y = ys.max()
		return Rect2(Vector2(min_x, min_y), Vector2(max_x - min_x, max_y - min_y))

var walls: Array[Wall] = []
var selected_wall: Wall = null
var drawing_wall: bool = false
var is_dragging: bool = false
var dragging_wall: Wall = null
var dragging_grip: int = -1 # 0=start, 1=end, 2=center
var hovered_grip: int = -1
var hovered_wall: Wall = null
var next_id: int = 1

const SNAP_DISTANCE = 10.0

func add_wall(start: Vector2, end: Vector2, width: float = 0.25) -> Wall:
	var w = Wall.new()
	w.ctrl_start = start
	w.ctrl_end = end
	w.width = width
	# default offsets already set on Wall class (start_offset=0.125, end_offset=-0.125)
	w.id = next_id
	next_id += 1
	walls.append(w)
	return w

func remove_wall(w: Wall):
	if selected_wall == w:
		selected_wall = null
	walls.erase(w)

func select_wall(w: Wall):
	if selected_wall:
		selected_wall.is_selected = false
	selected_wall = w
	if w:
		w.is_selected = true

func get_wall_at_position(world_pos: Vector2) -> Wall:
	# Check bounding boxes with small tolerance
	for i in range(walls.size() - 1, -1, -1):
		var w = walls[i]
		var bounds = w.get_bounds()
		if bounds.has_point(world_pos):
			return w
	return null

func get_grip_points(w: Wall) -> Dictionary:
	# Returns grip points: 0=start, 1=end, 2=center
	var center = w.get_center()
	return {0: w.ctrl_start, 1: w.ctrl_end, 2: center}

func get_grip_at_position(world_pos: Vector2, snap_distance_screen: float = SNAP_DISTANCE, world_to_screen_func: Callable = Callable()) -> Dictionary:
	var result = {"wall": null, "grip": -1}
	var min_dist = INF
	var screen_pos = world_pos
	if world_to_screen_func and world_to_screen_func.is_valid():
		screen_pos = world_to_screen_func.call(world_pos)
	for w in walls:
		var grips = get_grip_points(w)
		for grip_idx in grips.keys():
			var gp = grips[grip_idx]
			var gp_screen = gp
			if world_to_screen_func and world_to_screen_func.is_valid():
				gp_screen = world_to_screen_func.call(gp)
			var d = screen_pos.distance_to(gp_screen)
			if d <= snap_distance_screen and d < min_dist:
				min_dist = d
				result["wall"] = w
				result["grip"] = grip_idx
	return result

func start_drag_grip(w: Wall, grip_idx: int, world_pos: Vector2):
	dragging_wall = w
	dragging_grip = grip_idx
	is_dragging = true
	select_wall(w)

func update_drag(world_pos: Vector2, external_snap_points: Array[Vector2] = [], world_to_screen_func: Callable = Callable(), snap_pixels: float = 10.0):
	if not is_dragging or not dragging_wall:
		return
	# snap world_pos to external points via rectangle_manager helper left to caller
	if dragging_grip == 0:
		dragging_wall.ctrl_start = world_pos
	elif dragging_grip == 1:
		dragging_wall.ctrl_end = world_pos
	elif dragging_grip == 2:
		# move whole wall keeping vector
		var center = dragging_wall.get_center()
		var delta = world_pos - center
		dragging_wall.ctrl_start += delta
		dragging_wall.ctrl_end += delta

func to_dict(w: Wall) -> Dictionary:
	return {
		"id": w.id,
		"ctrl_start": w.ctrl_start,
		"ctrl_end": w.ctrl_end,
		"geom_start": w.geom_start(),
		"geom_end": w.geom_end(),
		"width": w.width,
		"start_offset": w.start_offset,
		"end_offset": w.end_offset
	}

func end_drag():
	is_dragging = false
	dragging_wall = null
	dragging_grip = -1

func update_hover_grip(world_pos: Vector2, world_to_screen_func: Callable = Callable()):
	var info = get_grip_at_position(world_pos, SNAP_DISTANCE, world_to_screen_func)
	if info["wall"]:
		hovered_grip = info["grip"]
		hovered_wall = info["wall"]
	else:
		hovered_grip = -1
		hovered_wall = null

func get_snap_points(external_snap_points: Array[Vector2] = []) -> Array[Vector2]:
	var pts: Array[Vector2] = []
	for w in walls:
		pts.append(w.ctrl_start)
		pts.append(w.ctrl_end)
	for p in external_snap_points:
		pts.append(p)
	return pts

func translate_selected(dx: float, dy: float) -> bool:
	if not selected_wall:
		return false
	selected_wall.ctrl_start += Vector2(dx, dy)
	selected_wall.ctrl_end += Vector2(dx, dy)
	return true

func delete_selected() -> bool:
	if selected_wall:
		walls.erase(selected_wall)
		selected_wall = null
		return true
	return false
