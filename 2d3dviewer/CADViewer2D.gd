# CADViewer2D.gd
# Viewer CAD 2D modern folosind Node2D și Camera2D
extends Control

@onready var viewport_container: SubViewport
@onready var camera_2d: Camera2D
@onready var grid_renderer: Node2D

@onready var ui_overlay: Control

var rectangle_manager: RectangleManager
var placing_rect = false

# Constante pentru grid și coordonate
const GRID_UNIT_SIZE = 50.0  # 50 pixeli = 1 unitate AutoCAD
const MIN_ZOOM = 0.1
const MAX_ZOOM = 10.0

func _ready():
	setup_viewport()
	setup_camera()
	setup_ui()
	
	# Inițializează managerul de dreptunghiuri
	rectangle_manager = RectangleManager.new()
	
	# Conectează butonul
	connect_add_rect_button()
	
	# Conectează semnalul de redimensionare
	resized.connect(_on_resized)
	
	# Forțează redraw inițial
	call_deferred("initial_redraw")

func setup_viewport():
	# Creează SubViewport pentru conținutul 2D
	viewport_container = SubViewport.new()
	# SubViewport nu are anchors - setăm dimensiunea manual
	viewport_container.size = size
	viewport_container.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(viewport_container)
	
	# Creează scena 2D principală
	var main_2d = Node2D.new()
	main_2d.name = "Main2D"
	viewport_container.add_child(main_2d)
	
	# Camera2D
	camera_2d = Camera2D.new()
	camera_2d.name = "Camera2D"
	main_2d.add_child(camera_2d)
	
	# Grid renderer
	var cad_renderer_script = load("res://CADRenderer.gd")
	grid_renderer = cad_renderer_script.new()
	grid_renderer.name = "GridRenderer"
	main_2d.add_child(grid_renderer)
	grid_renderer.set_cad_viewer(self)

func setup_camera():
	# Setări inițiale pentru camera
	camera_2d.position = Vector2.ZERO
	camera_2d.zoom = Vector2.ONE
	camera_2d.enabled = true

func setup_ui():
	# Overlay pentru UI (butoane, etc.)
	ui_overlay = Control.new()
	ui_overlay.name = "UIOverlay"
	ui_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	ui_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(ui_overlay)
	
	# Adaugă butonul
	create_add_rect_button()

func create_add_rect_button():
	var btn = Button.new()
	btn.text = "Adaugă dreptunghi 0.25x0.25"
	btn.position = Vector2(20, 20)
	btn.size = Vector2(200, 40)
	btn.name = "AddRectButton"
	ui_overlay.add_child(btn)

func connect_add_rect_button():
	var btn = ui_overlay.get_node_or_null("AddRectButton")
	if btn:
		btn.pressed.connect(_on_add_rect_button_pressed)
		print("Buton conectat cu succes!")
	else:
		print("EROARE: Nu s-a găsit butonul AddRectButton")

func _on_add_rect_button_pressed():
	print("Buton apăsat! Activez modul de plasare dreptunghi...")
	placing_rect = true

func _input(event):
	if not (event is InputEventMouseButton or event is InputEventMouseMotion):
		return
		
	# Obține poziția mouse-ului din eveniment
	var mouse_pos: Vector2
	if event is InputEventMouseButton:
		mouse_pos = event.position
	elif event is InputEventMouseMotion:
		mouse_pos = event.position
	else:
		return
	
	# Convertește poziția relativă la acest Control
	var local_pos = get_global_rect().position
	var viewport_pos = mouse_pos - local_pos
	var world_pos = screen_to_world(viewport_pos)
	
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			handle_mouse_press(world_pos)
		else:
			handle_mouse_release(world_pos)
	elif event is InputEventMouseMotion:
		handle_mouse_motion(world_pos)
	elif event is InputEventMouseButton:
		handle_zoom(event)

func handle_mouse_press(world_pos: Vector2):
	print("Mouse press la world pos: %s" % world_pos)
	
	if placing_rect:
		# Plasează un dreptunghi nou
		placing_rect = false
		var rect = rectangle_manager.add_rectangle(world_pos, Vector2(0.25, 0.25))
		print("Dreptunghi desenat la coordonate: (%.2f, %.2f)" % [world_pos.x, world_pos.y])
		print("Total dreptunghiuri: %d" % rectangle_manager.rectangles.size())
		grid_renderer.request_redraw()
		return
	
	# Verifică selecție dreptunghi
	var rect = rectangle_manager.get_rectangle_at_position(world_pos)
	if rect:
		rectangle_manager.start_drag_rectangle(rect, world_pos)
		print("Dreptunghi selectat pentru mutare")
	else:
		rectangle_manager.select_rectangle(null)
		print("Deselectare toate dreptunghiuri")
	
	grid_renderer.request_redraw()

func handle_mouse_release(world_pos: Vector2):
	if rectangle_manager.dragging_rectangle:
		rectangle_manager.end_drag()
		grid_renderer.request_redraw()

func handle_mouse_motion(world_pos: Vector2):
	# Actualizează hover grip
	rectangle_manager.update_hover_grip(world_pos, camera_2d.zoom.x, screen_to_world_callable())
	
	# Actualizează drag
	if rectangle_manager.dragging_rectangle:
		rectangle_manager.update_drag(world_pos)
		grid_renderer.request_redraw()

func handle_zoom(event: InputEventMouseButton):
	if event.button_index == MOUSE_BUTTON_WHEEL_UP:
		zoom_in()
	elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
		zoom_out()

func zoom_in():
	var new_zoom = camera_2d.zoom * 1.2
	if new_zoom.x <= MAX_ZOOM:
		camera_2d.zoom = new_zoom
		grid_renderer.request_redraw()

func zoom_out():
	var new_zoom = camera_2d.zoom * 0.8
	if new_zoom.x >= MIN_ZOOM:
		camera_2d.zoom = new_zoom
		grid_renderer.request_redraw()

# Funcții de conversie coordonate
func screen_to_world(screen_pos: Vector2) -> Vector2:
	# Convertește din coordonate de ecran la coordonate world
	var camera_pos = camera_2d.global_position
	var zoom = camera_2d.zoom.x
	return (screen_pos - viewport_container.size * 0.5) / zoom + camera_pos

func world_to_screen(world_pos: Vector2) -> Vector2:
	# Convertește din coordonate world la coordonate de ecran
	var camera_pos = camera_2d.global_position
	var zoom = camera_2d.zoom.x
	return (world_pos - camera_pos) * zoom + viewport_container.size * 0.5

func screen_to_world_callable() -> Callable:
	return Callable(self, "world_to_screen")

# Desenare grid și forme (apelată din CADRenderer)
func _draw_grid_and_shapes_internal(renderer: CanvasItem):
	print("_draw_grid_and_shapes_internal apelat cu renderer: ", renderer)
	draw_grid(renderer)
	draw_axes(renderer)
	draw_origin(renderer)
	draw_rectangles(renderer)
	print("Desenare completă!")

func draw_grid(renderer: CanvasItem):
	var viewport_size = viewport_container.size
	var camera_pos = camera_2d.global_position
	var zoom = camera_2d.zoom.x
	
	# Calculează grid-ul vizibil
	var grid_size = GRID_UNIT_SIZE * zoom
	var grid_color = Color.GRAY
	grid_color.a = 0.3
	
	# Limitele vizibile în coordonate world
	var top_left = screen_to_world(Vector2.ZERO)
	var bottom_right = screen_to_world(viewport_size)
	
	# Linii verticale
	var start_x = floor(top_left.x)
	var end_x = ceil(bottom_right.x)
	for x in range(int(start_x), int(end_x) + 1):
		var screen_x = world_to_screen(Vector2(x, 0)).x
		renderer.draw_line(
			Vector2(screen_x, 0),
			Vector2(screen_x, viewport_size.y),
			grid_color, 1.0
		)
	
	# Linii orizontale
	var start_y = floor(top_left.y)
	var end_y = ceil(bottom_right.y)
	for y in range(int(start_y), int(end_y) + 1):
		var screen_y = world_to_screen(Vector2(0, y)).y
		renderer.draw_line(
			Vector2(0, screen_y),
			Vector2(viewport_size.x, screen_y),
			grid_color, 1.0
		)

func draw_axes(renderer: CanvasItem):
	print("draw_axes apelat cu viewport_size: ", viewport_container.size)
	var viewport_size = viewport_container.size
	var origin_screen = world_to_screen(Vector2.ZERO)
	var axis_color = Color.RED
	var axis_width = 2.0
	
	print("Origin screen: ", origin_screen)
	
	# Axa X
	renderer.draw_line(
		Vector2(0, origin_screen.y),
		Vector2(viewport_size.x, origin_screen.y),
		axis_color, axis_width
	)
	
	# Axa Y
	renderer.draw_line(
		Vector2(origin_screen.x, 0),
		Vector2(origin_screen.x, viewport_size.y),
		axis_color, axis_width
	)

func draw_origin(renderer: CanvasItem):
	var origin_screen = world_to_screen(Vector2.ZERO)
	
	# Cerc la origine
	renderer.draw_circle(origin_screen, 8.0, Color.RED)
	renderer.draw_circle(origin_screen, 6.0, Color.BLACK)
	renderer.draw_circle(origin_screen, 4.0, Color.RED)
	
	# Eticheta (0,0)
	var font = ThemeDB.fallback_font
	renderer.draw_string(
		font,
		origin_screen + Vector2(10, -10),
		"(0,0)",
		HORIZONTAL_ALIGNMENT_LEFT,
		-1,
		12,
		Color.WHITE
	)

func draw_rectangles(renderer: CanvasItem):
	if not rectangle_manager:
		return
		
	var zoom = camera_2d.zoom.x
	
	# Desenează dreptunghiurile
	for rect in rectangle_manager.rectangles:
		RectangleRenderer.draw_rectangle(renderer, rect, zoom, screen_to_world_callable())
	
	# Desenează grip-urile
	if rectangle_manager.selected_rectangle:
		RectangleRenderer.draw_grip_points(
			renderer,
			rectangle_manager.selected_rectangle,
			zoom,
			screen_to_world_callable(),
			rectangle_manager.hovered_grip
		)

# Funcții utile pentru navigare
func center_on_origin():
	camera_2d.position = Vector2.ZERO
	grid_renderer.request_redraw()

func fit_rectangles():
	if rectangle_manager.rectangles.is_empty():
		center_on_origin()
		return
	
	# Calculează bounds pentru toate dreptunghiurile
	var min_pos = Vector2(INF, INF)
	var max_pos = Vector2(-INF, -INF)
	
	for rect in rectangle_manager.rectangles:
		var rect_bounds = rect.get_bounds()
		min_pos = min_pos.min(rect_bounds.position)
		max_pos = max_pos.max(rect_bounds.position + rect_bounds.size)
	
	# Centrează camera pe conținut
	var center = (min_pos + max_pos) * 0.5
	camera_2d.position = center
	
	# Ajustează zoom pentru a încadra tot conținutul
	var content_size = max_pos - min_pos
	var viewport_size = viewport_container.size
	var zoom_x = viewport_size.x / (content_size.x * GRID_UNIT_SIZE + 100)
	var zoom_y = viewport_size.y / (content_size.y * GRID_UNIT_SIZE + 100)
	var new_zoom = min(zoom_x, zoom_y, MAX_ZOOM)
	camera_2d.zoom = Vector2(new_zoom, new_zoom)
	
	grid_renderer.request_redraw()

func _on_resized():
	# Actualizează dimensiunea viewport-ului când fereastra se redimensionează
	if viewport_container:
		viewport_container.size = size
		if grid_renderer:
			grid_renderer.request_redraw()

func initial_redraw():
	# Forțează primul redraw după inițializare
	if grid_renderer:
		print("Forțez redraw inițial...")
		grid_renderer.request_redraw()
