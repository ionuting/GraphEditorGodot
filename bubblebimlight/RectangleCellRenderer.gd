# RectangleCellRenderer.gd
# Renderer pentru RectangleCell cu ambele dreptunghiuri vizibile
class_name RectangleCellRenderer

extends RefCounted

# Culori pentru dreptunghiul principal

# Culori foarte vizibile pentru dreptunghiuri
const MAIN_FILL_COLOR = Color(0.0, 1.0, 0.0, 1.0)  # Verde deschis, opac
const MAIN_OUTLINE_COLOR = Color(1.0, 1.0, 0.0, 1.0)  # Galben, opac
const MAIN_SELECTED_COLOR = Color(1.0, 0.5, 0.0, 1.0)  # Portocaliu, opac

# Culori pentru dreptunghiul cu offset
const OFFSET_FILL_COLOR = Color(0.0, 0.8, 1.0, 1.0)  # Cyan deschis, opac
const OFFSET_OUTLINE_COLOR = Color(1.0, 0.0, 1.0, 1.0)  # Magenta, opac
const OFFSET_SELECTED_COLOR = Color(1.0, 0.0, 0.0, 1.0)  # Roșu, opac

# Culori pentru grip points
const GRIP_COLOR = Color.WHITE
const GRIP_HOVER_COLOR = Color.YELLOW
const GRIP_SIZE = 8.0

# Culori pentru snap points
const SNAP_POINT_COLOR = Color.CYAN
const SNAP_POINT_SIZE = 3.0

# Desenează un RectangleCell complet
static func draw_rectangle_cell(canvas: CanvasItem, cell: RectangleCell, zoom: float, world_to_screen_func: Callable):
	if not cell:
		return
	
	# Desenează dreptunghiul principal
	draw_main_rectangle(canvas, cell, zoom, world_to_screen_func)
	
	# Desenează dreptunghiul cu offset (doar dacă offset-ul nu este zero)
	if cell.offset != 0.0:
		draw_offset_rectangle(canvas, cell, zoom, world_to_screen_func)
	
	# Eticheta este dezactivată

# Desenează dreptunghiul principal
static func draw_main_rectangle(canvas: CanvasItem, cell: RectangleCell, zoom: float, world_to_screen_func: Callable):
	var rect = cell.get_main_rectangle()
	var grid_unit_size = 50.0 # must match CADViewer2D_Fixed.GRID_UNIT_SIZE
	var top_left_screen = world_to_screen_func.call(rect.position)
	var bottom_right_screen = world_to_screen_func.call(rect.position + rect.size)
	var screen_size = bottom_right_screen - top_left_screen
	var screen_rect = Rect2(top_left_screen, screen_size)
	
	# Culoare de fundal
	var fill_color = MAIN_SELECTED_COLOR if cell.is_selected else MAIN_FILL_COLOR
	canvas.draw_rect(screen_rect, fill_color, true)
	
	# Contur
	var outline_color = MAIN_OUTLINE_COLOR
	canvas.draw_rect(screen_rect, outline_color, false, 2.0)

# Desenează dreptunghiul cu offset
static func draw_offset_rectangle(canvas: CanvasItem, cell: RectangleCell, zoom: float, world_to_screen_func: Callable):
	var rect = cell.get_offset_rectangle()
	var grid_unit_size = 50.0 # must match CADViewer2D_Fixed.GRID_UNIT_SIZE
	var top_left_screen = world_to_screen_func.call(rect.position)
	var bottom_right_screen = world_to_screen_func.call(rect.position + rect.size)
	var screen_size = bottom_right_screen - top_left_screen
	var screen_rect = Rect2(top_left_screen, screen_size)
	
	# Culoare de fundal
	var fill_color = OFFSET_SELECTED_COLOR if cell.is_selected else OFFSET_FILL_COLOR
	canvas.draw_rect(screen_rect, fill_color, true)
	
	# Contur
	var outline_color = OFFSET_OUTLINE_COLOR
	canvas.draw_rect(screen_rect, outline_color, false, 2.0)
	
	# Linie de conectare între centrele dreptunghiurilor
	var main_center = world_to_screen_func.call(cell.get_main_rectangle().get_center())
	var offset_center = world_to_screen_func.call(rect.get_center())
	canvas.draw_line(main_center, offset_center, Color.GRAY, 1.0)

# Desenează eticheta cu informații
static func draw_cell_label(canvas: CanvasItem, cell: RectangleCell, world_to_screen_func: Callable):
	var main_rect = cell.get_main_rectangle()
	var label_pos = world_to_screen_func.call(main_rect.position + Vector2(0, -0.2))
	
	var label_text = "%s [%s] #%d" % [cell.cell_name, cell.cell_type, cell.cell_index]
	
	# Font implicit (poate fi îmbunătățit)
	var font = ThemeDB.fallback_font
	var font_size = 10
	
	# Fundal pentru text
	var text_size = font.get_string_size(label_text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size)
	var bg_rect = Rect2(label_pos - Vector2(2, text_size.y + 2), text_size + Vector2(4, 4))
	canvas.draw_rect(bg_rect, Color(0, 0, 0, 0.7), true)
	
	# Text
	canvas.draw_string(font, label_pos, label_text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, Color.WHITE)

# Desenează grip points pentru ambele dreptunghiuri
static func draw_grip_points(canvas: CanvasItem, cell: RectangleCell, zoom: float, world_to_screen_func: Callable, hovered_grip: Vector2 = Vector2.ZERO, alpha: float = 1.0):
	if not cell.is_selected and alpha >= 1.0:
		return
	
	# Grip points pentru dreptunghiul principal
	draw_grip_points_for_rectangle(canvas, cell.get_main_grip_points(), world_to_screen_func, hovered_grip, alpha, MAIN_OUTLINE_COLOR, zoom)
	
	# Grip points pentru dreptunghiul cu offset (dacă există)
	if cell.offset != 0.0:
		draw_grip_points_for_rectangle(canvas, cell.get_offset_grip_points(), world_to_screen_func, hovered_grip, alpha, OFFSET_OUTLINE_COLOR, zoom)

# Helper pentru desenarea grip points
static func draw_grip_points_for_rectangle(canvas: CanvasItem, grip_points: Dictionary, world_to_screen_func: Callable, hovered_grip: Vector2, alpha: float, base_color: Color, zoom: float):
	for grip_type in grip_points:
		var world_pos = grip_points[grip_type]
		var screen_pos = world_to_screen_func.call(world_pos)
		
		var is_hovered = hovered_grip.distance_to(world_pos) < 0.1
		var color = GRIP_HOVER_COLOR if is_hovered else GRIP_COLOR
		color = Color(color.r, color.g, color.b, color.a * alpha)
		
		# Desenează grip-ul ca un pătrat, scalat cu zoom
		var scaled_grip_size = GRIP_SIZE * zoom
		var grip_rect = Rect2(screen_pos - Vector2(scaled_grip_size/2, scaled_grip_size/2), Vector2(scaled_grip_size, scaled_grip_size))
		
		# Fundal grip
		canvas.draw_rect(grip_rect, color, true)
		
		# Border cu culoarea dreptunghiului
		var border_color = Color(base_color.r, base_color.g, base_color.b, alpha)
		canvas.draw_rect(grip_rect, border_color, false, 2.0)

# Desenează toate punctele de snap pentru cell-uri
static func draw_all_snap_points(canvas: CanvasItem, cell_manager, world_to_screen_func: Callable):
	if not cell_manager:
		return
		
	var snap_points = cell_manager.get_snap_points()
	
	for snap_point in snap_points:
		var screen_point = world_to_screen_func.call(snap_point)
		canvas.draw_circle(screen_point, SNAP_POINT_SIZE, SNAP_POINT_COLOR)
		canvas.draw_circle(screen_point, SNAP_POINT_SIZE, Color.WHITE, false, 1.0)  # contur alb
