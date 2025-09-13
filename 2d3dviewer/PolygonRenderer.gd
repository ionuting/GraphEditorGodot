# PolygonRenderer.gd
# Clasă pentru desenarea poligoanalor
class_name PolygonRenderer

extends RefCounted

# Culori
const POLYGON_COLOR = Color(0.0, 1.0, 0.0, 0.3)  # verde semi-transparent
const POLYGON_OUTLINE_COLOR = Color.GREEN
const OFFSET_POLYGON_COLOR = Color(0.0, 1.0, 1.0, 0.3)  # cyan semi-transparent
const OFFSET_OUTLINE_COLOR = Color.CYAN
const POINT_COLOR = Color.YELLOW
const FIRST_POINT_COLOR = Color.RED
const LAST_POINT_COLOR = Color.ORANGE
const SELECTED_COLOR = Color(1.0, 0.7, 0.0, 0.5)  # portocaliu pentru selecție
const PREVIEW_LINE_COLOR = Color(0.0, 1.0, 0.0, 0.5)  # verde semi-transparent pentru preview
const CONTROL_POINT_COLOR = Color.WHITE
const CONTROL_POINT_HOVER_COLOR = Color.YELLOW
const CONTROL_POINT_SIZE = 6.0
const MIDPOINT_COLOR = Color.CYAN
const CENTER_POINT_COLOR = Color.MAGENTA
const SNAP_POINT_COLOR = Color(1.0, 1.0, 0.0, 0.6)  # galben semi-transparent pentru puncte snap
const SNAP_POINT_SIZE = 3.0

static func draw_polygon(canvas: CanvasItem, polygon: PolygonDrawer2D, world_to_screen_func: Callable, is_drawing: bool = false, preview_pos: Vector2 = Vector2.ZERO):
	if polygon.points.size() < 2:
		return
	
	# Convertește punctele la coordonate ecran
	var screen_points: PackedVector2Array = PackedVector2Array()
	for point in polygon.points:
		screen_points.append(world_to_screen_func.call(point))
	
	# Desenează poligonul principal
	if polygon.is_closed and polygon.points.size() > 2:
		# Poligon închis - desenează fill și contur complet
		var color = SELECTED_COLOR if polygon.is_selected else POLYGON_COLOR
		canvas.draw_colored_polygon(screen_points, color)
		
		# Contur
		var outline_color = POLYGON_OUTLINE_COLOR.darkened(0.2) if polygon.is_selected else POLYGON_OUTLINE_COLOR
		var closed_points = screen_points
		closed_points.append(screen_points[0])  # închide poligonul
		canvas.draw_polyline(closed_points, outline_color, 2.0)
	else:
		# Poligon în curs de desenare - doar linia
		canvas.draw_polyline(screen_points, POLYGON_OUTLINE_COLOR, 2.0)
		
		# Linie de preview de la ultimul punct la poziția mouse-ului
		if is_drawing and polygon.points.size() > 0 and preview_pos != Vector2.ZERO:
			var last_screen = world_to_screen_func.call(polygon.points[-1])
			var preview_screen = world_to_screen_func.call(preview_pos)
			canvas.draw_line(last_screen, preview_screen, PREVIEW_LINE_COLOR, 2.0)
	
	# Desenează poligonul offsetat dacă există
	if polygon.offset_points.size() > 2 and polygon.is_closed:
		var offset_screen_points: PackedVector2Array = PackedVector2Array()
		for point in polygon.offset_points:
			offset_screen_points.append(world_to_screen_func.call(point))
		
		# Fill offset
		canvas.draw_colored_polygon(offset_screen_points, OFFSET_POLYGON_COLOR)
		
		# Contur offset
		var closed_offset_points = offset_screen_points
		closed_offset_points.append(offset_screen_points[0])
		canvas.draw_polyline(closed_offset_points, OFFSET_OUTLINE_COLOR, 2.0)
	
	# Desenează punctele (doar în modul desenare)
	if is_drawing:
		draw_polygon_points(canvas, polygon, world_to_screen_func)
	
	# Desenează punctele de control pentru poligoanele selectate
	if polygon.is_selected and polygon.is_closed:
		draw_control_points(canvas, polygon, world_to_screen_func)

static func draw_polygon_points(canvas: CanvasItem, polygon: PolygonDrawer2D, world_to_screen_func: Callable):
	for i in range(polygon.points.size()):
		var point = polygon.points[i]
		var screen_point = world_to_screen_func.call(point)
		var color = POINT_COLOR
		var radius = 4.0
		
		if i == 0:
			# Primul punct - evidențiat și pulsează când poligonul poate fi închis
			color = FIRST_POINT_COLOR
			if polygon.points.size() > 2:
				# Pulsează pentru a indica că poate fi închis
				var pulse = sin(Time.get_ticks_msec() / 200.0) * 0.3 + 0.7
				color = Color(1.0, pulse, pulse)
				radius = 6.0
		elif i == polygon.points.size() - 1 and not polygon.is_closed:
			color = LAST_POINT_COLOR  # ultimul punct în portocaliu
		
		canvas.draw_circle(screen_point, radius, color)
		canvas.draw_circle(screen_point, radius, Color.WHITE, false, 1.0)  # contur alb

static func draw_control_points(canvas: CanvasItem, polygon: PolygonDrawer2D, world_to_screen_func: Callable, polygon_manager = null):
	if not polygon.is_selected or not polygon.is_closed:
		return
	
	var control_points = polygon.get_control_points()
	var num_original_points = polygon.points.size()
	
	for i in range(control_points.size()):
		var point = control_points[i]
		var screen_point = world_to_screen_func.call(point)
		var color = CONTROL_POINT_COLOR
		var radius = CONTROL_POINT_SIZE
		
		# Determină tipul punctului și culoarea
		if i < num_original_points:
			# Puncte originale (vârfurile) - albe, acestea sunt editabile
			color = CONTROL_POINT_COLOR
		elif i < num_original_points * 2:
			# Puncte de mijloc - cyan
			color = MIDPOINT_COLOR
			radius = CONTROL_POINT_SIZE * 0.8
		else:
			# Punctul central - magenta
			color = CENTER_POINT_COLOR
			radius = CONTROL_POINT_SIZE * 1.2
		
		# Verifică dacă punctul este în hover sau drag (doar pentru punctele editabile - vârfurile)
		if polygon_manager and i < num_original_points:
			if polygon_manager.hovered_control_point.distance_to(point) < 0.01:
				# Punct în hover - mărește și evidențiază
				color = Color.YELLOW
				radius = CONTROL_POINT_SIZE * 1.3
			elif polygon_manager.is_dragging_control_point and polygon_manager.dragging_control_point.distance_to(point) < 0.01:
				# Punct în drag - evidențiază cu verde
				color = Color.GREEN
				radius = CONTROL_POINT_SIZE * 1.2
		
		# Desenează punctul de control
		canvas.draw_circle(screen_point, radius, color)
		canvas.draw_circle(screen_point, radius, Color.BLACK, false, 1.0)  # contur negru

static func draw_selection_outline(canvas: CanvasItem, polygon: PolygonDrawer2D, world_to_screen_func: Callable):
	if not polygon.is_selected or polygon.points.size() < 2:
		return
	
	# Desenează contur de selecție mai gros
	var screen_points: PackedVector2Array = PackedVector2Array()
	for point in polygon.points:
		screen_points.append(world_to_screen_func.call(point))
	
	if polygon.is_closed and polygon.points.size() > 2:
		var closed_points = screen_points
		closed_points.append(screen_points[0])
		canvas.draw_polyline(closed_points, Color.YELLOW, 3.0)
	else:
		canvas.draw_polyline(screen_points, Color.YELLOW, 3.0)

# Desenează punctele de control cu suport pentru hover și drag
static func draw_control_points_with_manager(canvas: CanvasItem, polygon: PolygonDrawer2D, world_to_screen_func: Callable, polygon_manager):
	if not polygon.is_selected or not polygon.is_closed:
		return
	
	var control_points = polygon.get_control_points()
	var num_original_points = polygon.points.size()
	
	for i in range(control_points.size()):
		var point = control_points[i]
		var screen_point = world_to_screen_func.call(point)
		var color = CONTROL_POINT_COLOR
		var radius = CONTROL_POINT_SIZE
		
		# Determină tipul punctului și culoarea
		if i < num_original_points:
			# Puncte originale (vârfurile) - albe, acestea sunt editabile
			color = CONTROL_POINT_COLOR
			
			# Verifică hover și drag pentru punctele editabile
			if polygon_manager.hovered_control_point.distance_to(point) < 0.01:
				color = Color.YELLOW
				radius = CONTROL_POINT_SIZE * 1.3
			elif polygon_manager.is_dragging_control_point and polygon_manager.dragging_control_point.distance_to(point) < 0.01:
				color = Color.GREEN
				radius = CONTROL_POINT_SIZE * 1.2
				
		elif i < num_original_points * 2:
			# Puncte de mijloc - cyan (nu sunt editabile pentru moment)
			color = MIDPOINT_COLOR
			radius = CONTROL_POINT_SIZE * 0.8
		else:
			# Punctul central - magenta (nu este editabil pentru moment)
			color = CENTER_POINT_COLOR
			radius = CONTROL_POINT_SIZE * 1.2
		
		# Desenează punctul de control
		canvas.draw_circle(screen_point, radius, color)
		canvas.draw_circle(screen_point, radius, Color.BLACK, false, 1.0)  # contur negru

# Desenează punctele de snap pentru toate poligoanele (pentru feedback vizual în timpul desenării)
static func draw_all_snap_points(canvas: CanvasItem, polygon_manager: RefCounted, world_to_screen_func: Callable):
	var snap_points = polygon_manager.get_snap_points()
	
	for snap_point in snap_points:
		var screen_point = world_to_screen_func.call(snap_point)
		canvas.draw_circle(screen_point, SNAP_POINT_SIZE, SNAP_POINT_COLOR)
		canvas.draw_circle(screen_point, SNAP_POINT_SIZE, Color.WHITE, false, 1.0)  # contur alb