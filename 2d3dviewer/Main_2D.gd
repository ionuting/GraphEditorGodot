extends GraphEdit

var origin_dot: Control
var grid_overlay: Control
var rectangle_manager: RectangleManager
var polygon_manager: PolygonManager
var cell_manager: RectangleCellManager

var placing_rect = false

func _ready():
	# Inițializează managerii
	rectangle_manager = RectangleManager.new()
	polygon_manager = PolygonManager.new()
	cell_manager = RectangleCellManager.new()

	# Input handling pentru dreptunghiuri interactive - pe grid_overlay
func _on_grid_input(event):
	print("Grid input primit: %s" % event.get_class())
	
	# Verifică dacă click-ul este pe zona butonului
	if event is InputEventMouseButton:
		var btn = get_node_or_null("AddRectButton")
		if btn and btn.get_rect().has_point(event.position):
			print("Click pe buton - ignorat")
			return
	
	var world_pos = screen_to_world(event.position)
	
	if event is InputEventMouseMotion:
		handle_mouse_motion(world_pos)
	elif event is InputEventMouseButton:
		print("Mouse button event: button=%d, pressed=%s" % [event.button_index, event.pressed])
		handle_mouse_button(event, world_pos)= RectangleManager.new()
	
	# Setări inițiale pentru a semăna cu AutoCAD
	setup_autocad_style()
	
	# Creează overlay-ul pentru grid și origine
	create_grid_overlay()
	
	# Conectează signalele
	scroll_offset_changed.connect(_on_view_changed)
	
	# Poziția inițială - centrul ecranului ca origine
	center_origin()

	# Conectează butonul pentru adăugare dreptunghi
	var btn = get_node_or_null("AddRectButton")
	if btn:
		btn.pressed.connect(_on_add_rect_button_pressed)
		print("Buton conectat cu succes!")
	else:
		print("EROARE: Nu s-a găsit butonul AddRectButton")

	# Folosim gui_input pe grid_overlay pentru a procesa evenimente

	# Creează dreptunghiul 2D la apăsarea butonului
func _on_add_rect_button_pressed():
	print("Buton apăsat! Activez modul de plasare dreptunghi...")
	placing_rect = true
	print("placing_rect setat la: %s" % placing_rect)

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
	# Grid_overlay interceptează evenimente pentru dreptunghiuri
	grid_overlay.mouse_filter = Control.MOUSE_FILTER_PASS
	add_child(grid_overlay)
	grid_overlay.draw.connect(_draw_autocad_grid)
	# Conectăm gui_input pe grid_overlay
	grid_overlay.gui_input.connect(_on_grid_input)

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

	# Desenează dreptunghiurile folosind noul sistem
	draw_rectangles()

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
	# SCARA: 50 pixeli = 1 unitate AutoCAD
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

# Input handling pentru dreptunghiuri interactive - folosește _unhandled_input
func _unhandled_input(event):
	print("_unhandled_input apelat cu event: %s" % event.get_class())
	# Procesează doar evenimentele care nu au fost consumate de UI (ex: butoane)
	if not (event is InputEventMouseButton or event is InputEventMouseMotion):
		print("Event ignorat - nu este mouse")
		return
		
	print("Unhandled event primit: %s" % event.get_class())
	var world_pos = screen_to_world(event.position)
	
	if event is InputEventMouseMotion:
		handle_mouse_motion(world_pos)
	elif event is InputEventMouseButton:
		print("Mouse button event: button=%d, pressed=%s" % [event.button_index, event.pressed])
		handle_mouse_button(event, world_pos)
		# Consumă evenimentul pentru a preveni procesarea suplimentară
		get_viewport().set_input_as_handled()

func handle_mouse_motion(world_pos: Vector2):
	# Actualizează hover grip
	rectangle_manager.update_hover_grip(world_pos, zoom, world_to_screen)
	
	# Dacă tragem ceva, actualizează
	if rectangle_manager.dragging_rectangle:
		# Include snap points from polygons and cells while dragging rectangles
		var polygon_snap_points = polygon_manager.get_snap_points()
		var cell_snap_points = cell_manager.get_snap_points()
		var all_snap_points = polygon_snap_points + cell_snap_points
		rectangle_manager.update_drag(world_pos, all_snap_points)
		if grid_overlay:
			grid_overlay.queue_redraw()

func handle_mouse_button(event: InputEventMouseButton, world_pos: Vector2):
	if event.button_index != MOUSE_BUTTON_LEFT:
		return
		
	if event.pressed:
		handle_mouse_press(world_pos)
	else:
		handle_mouse_release(world_pos)

func handle_mouse_press(world_pos: Vector2):
	print("Handle mouse press - placing_rect: %s" % placing_rect)
	if placing_rect:
		# Aplica snap la punctele disponibile (poligoane, cell-uri, alte dreptunghiuri)
		var polygon_snap_points = polygon_manager.get_snap_points()
		var cell_snap_points = cell_manager.get_snap_points()
		var rectangle_snap_points = rectangle_manager.get_snap_points()
		var all_snap_points = polygon_snap_points + cell_snap_points + rectangle_snap_points
		var snapped_pos = rectangle_manager.get_snapped_position(world_pos, all_snap_points)

		# Plasează un dreptunghi nou la poziția cu snap
		placing_rect = false
		var rect = rectangle_manager.add_rectangle(snapped_pos, Vector2(0.25, 0.25))
		print("Dreptunghi desenat la coordonate AutoCAD cu snap: (%.3f, %.3f)" % [snapped_pos.x, snapped_pos.y])
		print("Total dreptunghiuri: %d" % rectangle_manager.rectangles.size())
		if grid_overlay:
			grid_overlay.queue_redraw()
		return
	
	# Verifică dacă se apasă pe un grip - doar selectează dreptunghiul, nu redimensionează
	var grip_info = rectangle_manager.get_grip_at_position(world_pos, zoom, world_to_screen)
	if grip_info.rectangle and grip_info.grip != -1:
		rectangle_manager.select_rectangle(grip_info.rectangle)
		print("Grip selectat: %s pe dreptunghiul %d" % [Rectangle2D.GripPoint.keys()[grip_info.grip], grip_info.rectangle.id])
		if grid_overlay:
			grid_overlay.queue_redraw()
		return
	
	# Verifică dacă se apasă pe un dreptunghi
	print("Verificare click pe dreptunghi la poziția world: %s" % world_pos)
	var rect = rectangle_manager.get_rectangle_at_position(world_pos)
	if rect:
		print("Dreptunghi găsit, începe drag")
		rectangle_manager.start_drag_rectangle(rect, world_pos)
	else:
		print("Niciun dreptunghi găsit, deselectează toate")
		# Deselectează toate
		rectangle_manager.select_rectangle(null)
	
	if grid_overlay:
		grid_overlay.queue_redraw()

func handle_mouse_release(world_pos: Vector2):
	if rectangle_manager.dragging_rectangle:
		rectangle_manager.end_drag()
		if grid_overlay:
			grid_overlay.queue_redraw()

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

# Desenează toate dreptunghiurile cu noul sistem
func draw_rectangles():
	if not rectangle_manager:
		return
		
	# Desenează dreptunghiurile
	for rect in rectangle_manager.rectangles:
		RectangleRenderer.draw_rectangle(grid_overlay, rect, zoom, world_to_screen)
	
	# Desenează grip-urile pentru dreptunghiul selectat
	if rectangle_manager.selected_rectangle:
		RectangleRenderer.draw_grip_points(
			grid_overlay, 
			rectangle_manager.selected_rectangle, 
			zoom, 
			world_to_screen,
			rectangle_manager.hovered_grip
		)
	
	# Desenează indicatorii de snap (dacă se trage ceva)
	if rectangle_manager.dragging_rectangle:
		var snap_points = rectangle_manager.get_snap_points()
		RectangleRenderer.draw_snap_indicators(grid_overlay, snap_points, zoom, world_to_screen)
