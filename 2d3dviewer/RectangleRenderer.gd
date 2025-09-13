# RectangleRenderer.gd
# Clasă pentru desenarea dreptunghiurilor și punctelor de grip
class_name RectangleRenderer

extends RefCounted

# Culori și stiluri
const RECT_COLOR = Color(0, 0.7, 1, 0.5)
const SELECTED_RECT_COLOR = Color(1, 0.7, 0, 0.7)
const GRIP_COLOR = Color(1, 1, 1, 1.0)
const GRIP_HOVER_COLOR = Color(1, 1, 0, 1.0)
const GRIP_SIZE = 8.0
const SNAP_POINT_COLOR = Color(1.0, 1.0, 0.0, 0.6)  # galben semi-transparent pentru puncte snap
const SNAP_POINT_SIZE = 3.0

static func draw_rectangle(canvas: CanvasItem, rect: Rectangle2D, zoom: float, world_to_screen_func: Callable):
	# Calculează pozițiile ecran pentru colțurile dreptunghiului
	var top_left_screen = world_to_screen_func.call(rect.position)
	var bottom_right_screen = world_to_screen_func.call(rect.position + rect.size)
	var screen_size = bottom_right_screen - top_left_screen
	
	# Desenează dreptunghiul principal
	var color = SELECTED_RECT_COLOR if rect.is_selected else RECT_COLOR
	canvas.draw_rect(Rect2(top_left_screen, screen_size), color, true)
	
	# Desenează conturul
	canvas.draw_rect(Rect2(top_left_screen, screen_size), color.darkened(0.3), false, 2.0)

# Desenează punctele de snap pentru toate dreptunghiurile (pentru feedback vizual)
static func draw_all_snap_points(canvas: CanvasItem, rectangle_manager: RefCounted, world_to_screen_func: Callable):
	var snap_points = rectangle_manager.get_snap_points()
	
	for snap_point in snap_points:
		var screen_point = world_to_screen_func.call(snap_point)
		canvas.draw_circle(screen_point, SNAP_POINT_SIZE, SNAP_POINT_COLOR)
		canvas.draw_circle(screen_point, SNAP_POINT_SIZE, Color.WHITE, false, 1.0)  # contur alb

static func draw_grip_points(canvas: CanvasItem, rect: Rectangle2D, zoom: float, world_to_screen_func: Callable, hovered_grip: Rectangle2D.GripPoint = -1, alpha: float = 1.0):
	# Pentru move mode, desenează grip-uri chiar dacă dreptunghiul nu e selectat
	var should_draw = rect.is_selected or alpha < 1.0
	
	if not should_draw:
		return
		
	var grip_points = rect.get_grip_points()
	
	for grip_type in grip_points:
		var world_pos = grip_points[grip_type]
		var screen_pos = world_to_screen_func.call(world_pos)
		var grip_size = GRIP_SIZE  # Grip-urile rămân de aceeași dimensiune pe ecran
		
		var base_color = GRIP_HOVER_COLOR if grip_type == hovered_grip else GRIP_COLOR
		var color = Color(base_color.r, base_color.g, base_color.b, base_color.a * alpha)
		
		# Desenează grip-ul ca un pătrat cu border
		var grip_rect = Rect2(screen_pos - Vector2(grip_size/2, grip_size/2), Vector2(grip_size, grip_size))
		
		# Fundal grip
		canvas.draw_rect(grip_rect, color, true)
		
		# Border negru mai gros cu alpha
		var border_color = Color(0, 0, 0, alpha)
		canvas.draw_rect(grip_rect, border_color, false, 2.0)
		
		# Punct central pentru vizibilitate
		canvas.draw_circle(screen_pos, 2.0, Color.BLACK)

static func draw_snap_indicators(canvas: CanvasItem, snap_points: Array, zoom: float, world_to_screen_func: Callable):
	# Desenează indicatori pentru punctele de snap disponibile
	for snap_point in snap_points:
		var screen_pos = world_to_screen_func.call(snap_point)
		var size = 4.0
		canvas.draw_circle(screen_pos, size, Color(1, 0, 1, 0.8))