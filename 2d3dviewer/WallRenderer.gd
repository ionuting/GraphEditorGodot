extends Node

class_name WallRenderer

static func draw_wall_line(canvas: CanvasItem, start: Vector2, end: Vector2, color: Color = Color(0.8, 0.8, 0.2), width: float = 2.0, world_to_screen_func: Callable = Callable()):
	var s = start
	var e = end
	if world_to_screen_func and world_to_screen_func.is_valid():
		s = world_to_screen_func.call(start)
		e = world_to_screen_func.call(end)
	if canvas:
		canvas.draw_line(s, e, color, width)

static func draw_wall_rect(canvas: CanvasItem, wall, world_to_screen_func: Callable = Callable() ):
	# Use wall control points and offsets to compute geometry
	var gs = wall.geom_start()
	var ge = wall.geom_end()
	var dir = (ge - gs)
	if dir.length() == 0:
		dir = Vector2(1, 0)
	else:
		dir = dir.normalized()
	var perp = Vector2(-dir.y, dir.x)
	var p1 = gs + perp * (wall.width * 0.5)
	var p2 = gs - perp * (wall.width * 0.5)
	var p3 = ge + perp * (wall.width * 0.5)
	var p4 = ge - perp * (wall.width * 0.5)
	var pts = [p1, p3, p4, p2]
	var screen_pts = []
	for p in pts:
		var sp = p
		if world_to_screen_func and world_to_screen_func.is_valid():
			sp = world_to_screen_func.call(p)
		screen_pts.append(sp)
	# Draw filled polygon (approximate with polyline)
	if canvas:
		canvas.draw_colored_polygon(screen_pts, Color(0.6, 0.6, 0.6))
		canvas.draw_polyline(screen_pts + [screen_pts[0]], Color(1, 1, 1), 2.0)

static func draw_grip_points(canvas: CanvasItem, wall, world_to_screen_func: Callable, hovered_grip: int = -1, alpha: float = 1.0):
	var grips = [wall.ctrl_start, wall.ctrl_end, wall.get_center()]
	for i in range(grips.size()):
		var p = grips[i]
		var sp = p
		if world_to_screen_func and world_to_screen_func.is_valid():
			sp = world_to_screen_func.call(p)
		var size = 6.0
		var color = Color(0.2, 0.7, 0.2, alpha)
		if i == hovered_grip:
			color = Color(1, 0.4, 0.2, alpha)
			size = 8.0
		if canvas:
			canvas.draw_circle(sp, size, color)
