extends GraphEdit

var origin_dot: Control
var grid_overlay: Control

func _ready():
	# Setări inițiale pentru a semăna cu AutoCAD
	setup_autocad_style()
	
	# Creează overlay-ul pentru grid și origine
	create_grid_overlay()
	
	# Conectează signalele
	scroll_offset_changed.connect(_on_view_changed)
	
	# Poziția inițială - centrul ecranului ca origine
	center_origin()

func setup_autocad_style():
	# Culoare de fundal închisă (ca AutoCAD)
	modulate = Color(1.0, 1.0, 1.0)
	add_theme_color_override("background", Color(1.0, 1.0, 0.5))

	
	# Dezactivează grid-ul implicit dacă vrei să faci unul personalizat
	show_grid = false

func create_grid_overlay():
	# Creează un control pentru desenarea grid-ului și originii
	grid_overlay = Control.new()
	grid_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	grid_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(grid_overlay)
	grid_overlay.draw.connect(_draw_autocad_grid)

func center_origin():
	# Centrează originea în mijlocul ecranului
	var center = size / 2
	scroll_offset = -center / zoom

func _draw_autocad_grid():
	if not grid_overlay:
		return
		
	var viewport_size = grid_overlay.size
	
	# Calculează originea în coordonate de ecran
	var origin_screen = world_to_screen(Vector2.ZERO)
	
	# Desenează axele principale
	draw_main_axes(origin_screen, viewport_size)
	
	# Desenează grid-ul
	draw_grid_lines(origin_screen, viewport_size)
	
	# Desenează originea
	draw_origin_marker(origin_screen)

func draw_main_axes(origin_screen: Vector2, viewport_size: Vector2):
	var axis_color = Color.RED
	var axis_width = 2.0
	
	# Axa X (orizontală)
	grid_overlay.draw_line(
		Vector2(0, origin_screen.y),
		Vector2(viewport_size.x, origin_screen.y),
		axis_color, axis_width
	)
	
	# Axa Y (verticală) - ATENȚIE: în Godot Y crește în jos
	grid_overlay.draw_line(
		Vector2(origin_screen.x, 0),
		Vector2(origin_screen.x, viewport_size.y),
		axis_color, axis_width
	)

func draw_grid_lines(origin_screen: Vector2, viewport_size: Vector2):
	var grid_size = 50.0 * zoom  # Dimensiunea grid-ului adaptată la zoom
	var grid_color = Color.GRAY
	grid_color.a = 0.3
	
	# Linii verticale (paralele cu axa Y)
	var start_x = fmod(origin_screen.x, grid_size)
	var x = start_x
	while x < viewport_size.x:
		grid_overlay.draw_line(
			Vector2(x, 0),
			Vector2(x, viewport_size.y),
			grid_color, 1.0
		)
		x += grid_size
	
	x = start_x - grid_size
	while x > 0:
		grid_overlay.draw_line(
			Vector2(x, 0),
			Vector2(x, viewport_size.y),
			grid_color, 1.0
		)
		x -= grid_size
	
	# Linii orizontale (paralele cu axa X)
	var start_y = fmod(origin_screen.y, grid_size)
	var y = start_y
	while y < viewport_size.y:
		grid_overlay.draw_line(
			Vector2(0, y),
			Vector2(viewport_size.x, y),
			grid_color, 1.0
		)
		y += grid_size
		
	y = start_y - grid_size
	while y > 0:
		grid_overlay.draw_line(
			Vector2(0, y),
			Vector2(viewport_size.x, y),
			grid_color, 1.0
		)
		y -= grid_size

func draw_origin_marker(origin_screen: Vector2):
	# Desenează un cerc roșu la origine
	grid_overlay.draw_circle(origin_screen, 8.0, Color.RED)
	grid_overlay.draw_circle(origin_screen, 6.0, Color.BLACK)
	grid_overlay.draw_circle(origin_screen, 4.0, Color.RED)
	
	# Adaugă eticheta (0,0)
	var font = ThemeDB.fallback_font
	var font_size = 12
	grid_overlay.draw_string(
		font,
		origin_screen + Vector2(10, -10),
		"(0,0)",
		HORIZONTAL_ALIGNMENT_LEFT,
		-1,
		font_size,
		Color.WHITE
	)

# Funcții de conversie între sistemele de coordonate
func world_to_screen(world_pos: Vector2) -> Vector2:
	# Convertește din coordonate "AutoCAD" în coordonate de ecran Godot
	# În AutoCAD: Y pozitiv = în sus
	# În Godot: Y pozitiv = în jos
	var autocad_pos = Vector2(world_pos.x, -world_pos.y)  # Inversează Y
	return autocad_pos * zoom - scroll_offset

func screen_to_world(screen_pos: Vector2) -> Vector2:
	# Convertește din coordonate de ecran în coordonate "AutoCAD"
	var world_pos = (screen_pos + scroll_offset) / zoom
	return Vector2(world_pos.x, -world_pos.y)  # Inversează Y înapoi

func _on_view_changed(_offset: Vector2):
	if grid_overlay:
		grid_overlay.queue_redraw()

# Funcții utile pentru lucrul cu coordonate AutoCAD
func add_node_at_autocad_position(node: GraphNode, autocad_pos: Vector2):
	# Adaugă un node la o poziție AutoCAD
	node.position_offset = world_to_autocad_node_position(autocad_pos)
	add_child(node)

func world_to_autocad_node_position(autocad_pos: Vector2) -> Vector2:
	# Pentru GraphNode-uri, trebuie să convertim diferit
	# GraphNode folosește position_offset care e în coordonate "world"
	return Vector2(autocad_pos.x, -autocad_pos.y)

# Input handling pentru a afișa coordonatele cursorului
func _gui_input(event):
	if event is InputEventMouseMotion:
		var world_pos = screen_to_world(event.position)
		# Aici poți afișa coordonatele undeva în UI
		print("Cursor: (%.2f, %.2f)" % [world_pos.x, world_pos.y])

# Funcție pentru a reseta view-ul la origine
func reset_to_origin():
	center_origin()
	_on_view_changed(scroll_offset)

# Adaugă aceste funcții la clasa de mai sus

func zoom_to_fit_content():
	# Găsește toate node-urile și centrează view-ul
	var nodes = get_children().filter(func(child): return child is GraphNode)
	if nodes.is_empty():
		center_origin()
		return
		
	var min_pos = Vector2(INF, INF)
	var max_pos = Vector2(-INF, -INF)
	
	for node in nodes:
		var pos = node.position_offset
		min_pos = min_pos.min(pos)
		max_pos = max_pos.max(pos + node.size)
	
	var content_center = (min_pos + max_pos) / 2
	var content_size = max_pos - min_pos
	
	# Calculează zoom-ul necesar
	var zoom_x = size.x / (content_size.x + 200)
	var zoom_y = size.y / (content_size.y + 200)
	zoom = min(zoom_x, zoom_y, 2.0)  # Limitează zoom-ul maxim
	
	# Centrează conținutul
	scroll_offset = content_center * zoom - size / 2

func get_cursor_autocad_coordinates() -> Vector2:
	var mouse_pos = get_local_mouse_position()
	return screen_to_world(mouse_pos)
