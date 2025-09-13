extends Node

class_name WindowRenderer

static func draw_window(canvas: CanvasItem, w, world_to_screen_func: Callable = Callable()):
	var pts = w.get_world_rect_polygon()
	var screen_pts = []
	for p in pts:
		var sp = p
		if world_to_screen_func and world_to_screen_func.is_valid():
			sp = world_to_screen_func.call(p)
		screen_pts.append(sp)
	if canvas:
		canvas.draw_colored_polygon(screen_pts, Color(0.8, 0.9, 1.0, 0.9))
		canvas.draw_polyline(screen_pts + [screen_pts[0]], Color(0.2, 0.2, 0.6), 2.0)
		# Draw a double-window symbol: two vertical panes inside
		var a = screen_pts[0]
		var b = screen_pts[1]
		var c = screen_pts[2]
		var d = screen_pts[3]
		# compute mid-top/mid-bottom as average of top edge and bottom edge
		var top_mid = (a + b) * 0.5
		var bottom_mid = (d + c) * 0.5
		# vertical divider
		canvas.draw_line(top_mid, bottom_mid, Color(0.1, 0.1, 0.4), 2.0)
		# decorative sash lines
		canvas.draw_line(a.lerp(top_mid, 0.25), d.lerp(bottom_mid, 0.25), Color(0.1, 0.1, 0.4), 1.0)
		canvas.draw_line(b.lerp(top_mid, 0.25), c.lerp(bottom_mid, 0.25), Color(0.1, 0.1, 0.4), 1.0)

	# Draw grips if selected or hovered
	var grips = []
	if w.is_selected:
		var g = w.get_world_rect_polygon() # reuse polygon computing
		# compute grip positions using same math as manager (best-effort)
		var center = w.get_local_rect_center()
		var insert_p = w.insert_point
		var top_mid = (pts[0] + pts[1]) * 0.5
		var bottom_mid = (pts[3] + pts[2]) * 0.5
		var dir = (bottom_mid - top_mid).normalized()
		var handle_offset = max(w.length, w.width) * 0.5 + 0.2
		var rot_handle = top_mid - dir * handle_offset
		grips = [insert_p, center, rot_handle]
		for gp in grips:
			var sp = gp
			if world_to_screen_func and world_to_screen_func.is_valid():
				sp = world_to_screen_func.call(gp)
			canvas.draw_circle(sp, 6.0, Color(0.9, 0.2, 0.2))
			canvas.draw_circle(sp, 5.0, Color(1,1,1))
